"""Measures the green-screen reference puff (frames cut by ffmpeg into puffB_frames): white mask per frame."""
import glob, os, subprocess, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
ff = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Microsoft", "WinGet", "Packages", "*FFmpeg*", "*", "bin", "ffmpeg.exe"))[0]
W, H = 580, 400
prev = None
print("frame  area_px  bbox_w bbox_h  left top  holes%(of filled hull)  changed_vs_prev%")
for i in range(16, 38):
    path = os.path.join(HERE, "puffB_frames", f"f_{i + 1:02d}.png")
    raw = subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    im = np.frombuffer(raw, dtype=np.uint8).reshape(H, W, 3).astype(int)
    mask = (im[..., 0] > 150) & (im[..., 2] > 150)
    ys, xs = np.nonzero(mask)
    if not len(xs):
        print(i, "empty"); prev = mask; continue
    # filled silhouette: per column and per row span (cheap hull), holes = hull minus mask
    hull = np.zeros_like(mask)
    for x in np.unique(xs):
        col = np.nonzero(mask[:, x])[0]; hull[col.min():col.max() + 1, x] = True
    hull2 = np.zeros_like(mask)
    for y in np.unique(ys):
        row = np.nonzero(mask[y])[0]; hull2[y, row.min():row.max() + 1] = True
    hull &= hull2
    holes = 100 * (1 - mask.sum() / hull.sum())
    ch = 100 * (mask ^ prev).sum() / max(mask.sum(), 1) if prev is not None else 0
    print(f"{i:5d} {mask.sum():8d} {xs.max()-xs.min()+1:6d} {ys.max()-ys.min()+1:6d} {xs.min():5d} {ys.min():4d} {ys.max():4d} {holes:8.1f} {ch:8.1f}")
    prev = mask
