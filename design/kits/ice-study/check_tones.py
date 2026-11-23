"""Step 4, tones: the colours of the ice in a preview frame against reference C's.
  python.exe check_tones.py <empty frame> <frame with the ice> [more frames with the ice ...]
The ice is every pixel that differs from the empty frame. Prints the 5/25/50/75/95th percentiles (by brightness)
beside the reference's, and the share of the picture the ice covers.
"""
import sys

import numpy as np

from px import load

REF = {5: (125, 162, 198), 25: (154, 196, 225), 50: (182, 224, 244), 75: (213, 239, 251), 95: (236, 251, 255)}
empty = load(sys.argv[1]).astype(float)
for path in sys.argv[2:]:
    img = load(path).astype(float)
    mask = np.abs(img - empty).sum(-1) > 24
    ice = img[mask]
    luma = ice @ np.array([0.2126, 0.7152, 0.0722])
    order = np.argsort(luma)
    print(path.replace("\\", "/").split("/")[-2:], "ice covers %.1f %% of the picture" % (100 * mask.mean()))
    for p, ref in REF.items():
        rgb = tuple(int(v) for v in ice[order[int(len(order) * p / 100)]].round())
        print(f"  {p:2d}th  new {rgb}   reference {ref}")
