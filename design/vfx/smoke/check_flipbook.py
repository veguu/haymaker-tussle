"""Checks a 4 x 4 particle flipbook by numbers. Plain Python + numpy (Blender's interpreter), ffmpeg to read PNGs.

  python design/vfx/smoke/check_flipbook.py [new.png] [old.png]

Defaults: design/vfx/smoke/out/smoke_poof.png beside design/vfx/out/hit_smoke.png (the sheet in the game now).
Prints the same numbers for each sheet, then PASS/FAIL lines for the first (the new one).
"""
import glob
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
GRID, CELL, BORDER = 4, 256, 6
SOFT = os.environ.get("SMOKE_LOOK", "soft") == "soft"  # "toon" checks the flat-tone look instead


def ffmpeg():
    found = glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages",
                                   "yt-dlp.FFmpeg*", "*", "bin", "ffmpeg.exe"))
    return found[0] if found else "ffmpeg"


def load(path):
    """RGBA floats 0-1, rows top-down."""
    probe = subprocess.run([ffmpeg(), "-hide_banner", "-i", path], capture_output=True, text=True).stderr
    size = next(part for line in probe.splitlines() if "Video:" in line for part in line.replace(",", " ").split()
                if "x" in part and part.replace("x", "").isdigit())
    width, height = (int(v) for v in size.split("x"))
    raw = subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4).astype(np.float32) / 255.0


def cells(image):
    return [image[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] for r in range(GRID) for c in range(GRID)]


def perimeter(mask):
    inner = mask[1:-1, 1:-1] & mask[:-2, 1:-1] & mask[2:, 1:-1] & mask[1:-1, :-2] & mask[1:-1, 2:]
    return int(mask[1:-1, 1:-1].sum() - inner.sum())


def measure(path):
    image = load(path)
    out = dict(path=path, size=image.shape[:2])
    if image.shape[0] != GRID * CELL or image.shape[1] != GRID * CELL:
        return out
    rows = []
    last_mask = None
    for cell in cells(image):
        rgb, alpha = cell[..., :3], cell[..., 3]
        solid = alpha > 0.5
        border = np.concatenate([alpha[:BORDER].ravel(), alpha[-BORDER:].ravel(), alpha[:, :BORDER].ravel(), alpha[:, -BORDER:].ravel()])
        seen = alpha > 0
        grey = float(np.abs(rgb[..., 0] - rgb[..., 1])[seen].max(initial=0) + np.abs(rgb[..., 1] - rgb[..., 2])[seen].max(initial=0))
        ys, xs = np.nonzero(solid)
        # soft smoke fades by going see-through, so its "coverage" is how much smoke there is (the mean alpha), not
        # how many pixels are over half solid (that drops off a cliff when the whole puff passes 50 % together)
        row = dict(coverage=float(alpha.mean() if SOFT else solid.mean()) * 100, border=float(border.max()), grey=grey)
        if len(xs):
            row["extent"] = max(xs.max() - xs.min() + 1, ys.max() - ys.min() + 1) / CELL * 100
            row["centre"] = (float(xs.mean() - (CELL - 1) / 2), float(ys.mean() - (CELL - 1) / 2))
        else:
            row["extent"], row["centre"] = 0.0, (0.0, 0.0)
        # tones: the luminance of fully opaque pixels, in 16 bins; a toon look puts nearly all of them in a few bins
        inside = alpha > 0.98
        lum = rgb.mean(axis=2)[inside]
        if lum.size:
            hist = np.histogram(lum, bins=16, range=(0, 1))[0] / lum.size
            row["tones"] = int((hist > 0.03).sum())
            row["top3"] = float(np.sort(hist)[-3:].sum()) * 100
        else:
            row["tones"], row["top3"] = 0, 0.0
        # edge: partly transparent pixels per pixel of outline = how wide the soft edge is
        soft = (alpha > 0.02) & (alpha < 0.98)
        edge = perimeter(solid)
        row["edge"] = float(soft.sum()) / edge if edge else 0.0
        # fringe: the straight colour of partly transparent pixels against the opaque tones
        part = (alpha > 0.1) & (alpha < 0.9)
        if part.any() and lum.size:
            edge_lum = rgb.mean(axis=2)[part]
            row["fringe_dark"] = float(lum.min() - edge_lum.min())
            row["fringe_bright"] = float(edge_lum.max() - lum.max())
        else:
            row["fringe_dark"] = row["fringe_bright"] = 0.0
        visible = alpha > 0.03
        row["darkest"] = float(rgb.mean(axis=2)[visible].min()) if visible.any() else 1.0
        if last_mask is not None:
            # how much of the SMALLER of the two shapes lies inside the other: a puff that only grows or shrinks in
            # place scores 100; one whose lobes hop somewhere else scores low. (Plain overlap-over-union punished a
            # clump for shrinking.)
            smaller = min(solid.sum(), last_mask.sum())
            row["overlap"] = float((solid & last_mask).sum()) / smaller * 100 if smaller else 100.0
        last_mask = solid
        rows.append(row)
    out["rows"] = rows
    return out


def show(result, label):
    print(f"\n{label}: {os.path.relpath(result['path'], PROJECT)}  size {result['size'][1]} x {result['size'][0]}")
    rows = result.get("rows")
    if not rows:
        print("  not a 1024 x 1024 sheet")
        return
    line = lambda key, spec: " ".join(spec.format(r[key]) for r in rows)  # noqa: E731
    print("  coverage %      :", line("coverage", "{:5.1f}"))
    print("  widest extent % :", line("extent", "{:5.1f}"))
    print("  centre off x px :", " ".join(f"{r['centre'][0]:5.1f}" for r in rows))
    print("  centre off y px :", " ".join(f"{r['centre'][1]:5.1f}" for r in rows))
    print("  border alpha max:", line("border", "{:5.2f}"))
    print("  tones (bins>3%) :", line("tones", "{:5d}"))
    print("  in top 3 bins % :", line("top3", "{:5.0f}"))
    print("  edge width px   :", line("edge", "{:5.1f}"))
    print("  overlap w/ last :", "  --- " + " ".join(f"{r['overlap']:5.0f}" for r in rows[1:]))
    print(f"  not grey (max)  : {max(r['grey'] for r in rows):.4f}   fringe darker than the tones by {max(r['fringe_dark'] for r in rows):.3f}, "
          f"brighter by {max(r['fringe_bright'] for r in rows):.3f}")


def verdict(result):
    rows = result.get("rows")
    checks = {"1024 x 1024, 4 x 4": rows is not None}
    if rows:
        coverage = [r["coverage"] for r in rows]
        # the first step is the POP (the owner: "Pop in 2 frames"): it is meant to jump, so it is not counted
        steps = [abs(b - a) for a, b in zip(coverage[1:], coverage[2:])]
        full = [r for r in rows if r["coverage"] > 5 and r["extent"] > 0]
        checks.update({
            f"every cell's {BORDER} px border is clear": max(r["border"] for r in rows) == 0,
            "greyscale (R = G = B)": max(r["grey"] for r in rows) < 0.005,
            "biggest frame spans about 70 % of the cell (62-78)": 62 <= max(r["extent"] for r in rows) <= 78,
            "last frame nearly empty (5 % or less)": coverage[-1] <= 5,
            "no coverage jump over 12 points between frames": max(steps) <= 12,
            # The puff may RISE as it dies (its lobes hollow into arches on their upper sides) but must never drop
            # (the owner: "the smoke burst shouldnt drop"): sideways within 12 px, never more than 6 px lower than it
            # started, and at most 50 px higher.
            "centre: within 12 px sideways, never drops, rises 50 px at most": all(
                abs(r["centre"][0]) <= 12 and r["centre"][1] - full[0]["centre"][1] <= 6 and r["centre"][1] >= -50
                for r in full if r["coverage"] > 10  # a nearly gone frame's "centre" is whichever wisp is left
            ),
            # 85 %, not 97: at 256 px the anti-aliased lines between two flat tones are 5-10 % of a small shape
        })
        if SOFT:
            # the owner's second pick ("Soft like the reference"): no flat tones; a soft edge, but not the old blur
            # (measured while the puff is mostly solid: a fading patch is all "edge" by this measure)
            # the first half only: once the puff is fading, every pixel is partly see-through and counts as "edge"
            checks["soft edge: 3-30 px (frames 1-8, before the fade)"] = all(3 <= r["edge"] <= 30 for r in rows[:8])
        else:
            checks["flat tones: 4 or fewer, 85 % in the top three"] = all(r["tones"] <= 4 and r["top3"] >= 85 for r in full)
            checks["clean edge: 1-3 px"] = all(1 <= r["edge"] <= 3 for r in full)
        checks.update({
            "lobes don't jump: 60 % overlap with the frame before": min(r["overlap"] for r in full[2:]) >= 60,
        })
        if SOFT:
            # soft smoke has no flat tones to compare an edge with: no visible pixel may be darker than light grey
            checks["no dark fringe: every visible pixel 0.6 or lighter"] = min(r["darkest"] for r in rows) >= 0.6
        else:
            checks["no fringe: edge pixels within 0.02 of the tones"] = max(max(r["fringe_dark"], r["fringe_bright"]) for r in rows) <= 0.02
        checks.update({
        })
    for name, ok in checks.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    return all(checks.values())


if __name__ == "__main__":
    new = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "smoke_poof.png")
    old = sys.argv[2] if len(sys.argv) > 2 else os.path.join(PROJECT, "design", "vfx", "out", "hit_smoke.png")
    old_result, new_result = measure(old), measure(new)
    show(old_result, "OLD")
    verdict(old_result)
    show(new_result, "NEW")
    sys.exit(0 if verdict(new_result) else 1)
