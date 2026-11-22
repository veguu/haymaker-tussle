"""The smoke flipbook's preview: the old sheet beside the new one, played the way the game's emitters play it.

  python design/vfx/smoke/preview.py        (plain Python + numpy, ffmpeg to read and write)

Writes to design/vfx/smoke/out/:
  sheets_old_vs_new.png      the two sheets side by side on a dark ground
  smoke_old_vs_new.mp4       60 fps, looped: old on the left, new on the right; the top row over the arena's grass,
                             the bottom row over a pale cream floor
Each panel is ONE particle with the dash dust's own settings (src/client/Fx/DashFx.luau): FlipbookMode OneShot spreads
the 16 frames over the particle's Lifetime (0.35-0.6 s: 0.475 here, about 34 frames a second), Size 0.9 -> 2.2,
Transparency 0.55 -> 1, tint (240, 242, 245), LightEmission 0.3 (0 = painted over the ground, 1 = added to it).
"""
import os
import subprocess

import numpy as np

import check_flipbook as cf

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
OLD = os.path.join(cf.PROJECT, "design", "vfx", "out", "hit_smoke.png")
NEW = os.path.join(OUT, "smoke_poof.png")
LIFETIME = 0.475
SIZE = (0.9, 2.2)
TRANSPARENCY = (0.55, 1.0)
TINT = np.array([240, 242, 245], dtype=np.float32) / 255
LIGHT_EMISSION = 0.3
GROUNDS = {"grass": (90, 132, 70), "cream": (236, 228, 205)}  # the arena's turf (Config/GroundColours); a pale floor (approx.)
PANEL = 480
FPS = 60
LOOPS = 5
GAP = 0.25  # seconds of empty ground between loops


def save(image, path):
    data = (np.clip(image, 0, 1) * 255 + 0.5).astype(np.uint8)
    height, width = data.shape[:2]
    pix = "rgba" if data.shape[2] == 4 else "rgb24"
    subprocess.run([cf.ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", pix,
                    "-s", f"{width}x{height}", "-i", "-", path], input=data.tobytes(), check=True)


def scaled(cell, pixels):
    """A cell resampled to pixels x pixels (nearest: the sheet is already anti-aliased)."""
    index = (np.arange(pixels) * cell.shape[0] / pixels).astype(int)
    return cell[index][:, index]


def panel(cells, ground, share):
    """One particle at `share` of its life (None: no particle) over a ground colour."""
    out = np.empty((PANEL, PANEL, 3), dtype=np.float32)
    out[:] = np.array(ground, dtype=np.float32) / 255
    if share is None:
        return out
    frame = min(int(share * 16), 15)
    size = SIZE[0] + (SIZE[1] - SIZE[0]) * share
    pixels = int(round(PANEL * 0.80 * size / SIZE[1]))  # the full-grown particle's image spans 80 % of the panel
    sprite = scaled(cells[frame], pixels)
    alpha = sprite[..., 3:4] * (1 - (TRANSPARENCY[0] + (TRANSPARENCY[1] - TRANSPARENCY[0]) * share))
    colour = sprite[..., :3] * TINT
    start = (PANEL - pixels) // 2
    under = out[start:start + pixels, start:start + pixels]
    under[:] = under * (1 - alpha * (1 - LIGHT_EMISSION)) + colour * alpha
    return out


def main():
    old, new = cf.load(OLD), cf.load(NEW)
    dark = np.array([0.165, 0.176, 0.2], dtype=np.float32)
    both = np.concatenate([dark * (1 - s[..., 3:4]) + s[..., :3] * s[..., 3:4] for s in (old, new)], axis=1)
    save(both, os.path.join(OUT, "sheets_old_vs_new.png"))
    old_cells, new_cells = cf.cells(old), cf.cells(new)
    one = int(round((LIFETIME + GAP) * FPS))
    frames = []
    for index in range(one):
        t = index / FPS
        share = t / LIFETIME if t < LIFETIME else None
        rows = [np.concatenate([panel(old_cells, ground, share), panel(new_cells, ground, share)], axis=1)
                for ground in GROUNDS.values()]
        frames.append(np.concatenate(rows, axis=0))
    video = np.stack(frames * LOOPS)
    data = (np.clip(video, 0, 1) * 255 + 0.5).astype(np.uint8)
    path = os.path.join(OUT, "smoke_old_vs_new.mp4")
    subprocess.run([cf.ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                    "-s", f"{PANEL * 2}x{PANEL * 2}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "16", path], input=data.tobytes(), check=True)
    # stills of the same panels at four moments, for reading the shapes
    picks = [frames[int(round(s * LIFETIME * FPS))] for s in (0.08, 0.35, 0.6, 0.85)]
    save(np.concatenate(picks, axis=1), os.path.join(OUT, "smoke_old_vs_new_stills.png"))
    print("WROTE", path, f"{len(video)} frames, each loop {LIFETIME} s of particle + {GAP} s of ground")


if __name__ == "__main__":
    main()
