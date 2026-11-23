"""Sample pixels of any image ffmpeg can read (this PC has no PIL).
  python.exe px.py <image> x,y[,r] x,y[,r] ...
Prints the mean RGB of the (2r+1) square at each point (r defaults to 3)."""
import subprocess
import sys

import numpy as np


def load(path):
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                            "-of", "csv=p=0", path], capture_output=True, text=True, check=True).stdout.strip().split(",")
    w, h = int(probe[0]), int(probe[1])
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, w, 3)


if __name__ == "__main__":
    img = load(sys.argv[1])
    for spec in sys.argv[2:]:
        parts = [int(v) for v in spec.split(",")]
        x, y = parts[0], parts[1]
        r = parts[2] if len(parts) > 2 else 3
        rgb = img[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(0).round().astype(int)
        print(f"{x},{y}: {tuple(int(v) for v in rgb)}")
