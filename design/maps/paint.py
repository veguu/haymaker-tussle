"""Texture painting with numpy for the arenas (runs inside Blender 5.2, which ships numpy).

Why painted maps and not baked node shaders: what ships to Roblox is a texture, so the detail has to be
in the texture at a density that survives the gameplay camera. The fighting surface is cut into 64-stud
tiles, each with its own 1024 colour, normal and roughness map (16 px per stud, up from 4.5), and the
rim is unwrapped as a strip (about 15 px per stud). The painters here work directly in studs, so a
board, a tile or a clover leaf is the same size on every tile and continues across tile seams.

Scenery (beams, cliffs, brick, roof tiles) is painted the same way from a baked position map: each
texel's world position and normal are baked with Cycles, a painter turns them into colour, and baked
ambient occlusion is multiplied in (tinted, so the shadow under the eaves can be warm).

Colours are written in linear and converted to sRGB on save. Normal maps are OpenGL (green up), which
is what glTF and Roblox expect. Roughness goes in the green channel of a glTF metallic-roughness image.
"""
import math
import os

import numpy as np

# --- colour ------------------------------------------------------------------------------------
def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def rgb(r, g, b):
    """A colour picked in sRGB 0-255, returned linear (shape (3,))."""
    return srgb_to_linear(np.array([r, g, b], dtype=np.float64) / 255.0)


def mix(a, b, t):
    """Blend colours (..., 3) or scalars by t (broadcast over the last axis for colours)."""
    t = np.asarray(t)
    if np.ndim(a) and np.shape(a)[-1] == 3 or np.ndim(b) and np.shape(b)[-1] == 3:
        t = t[..., None]
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fill(shape, colour):
    return np.broadcast_to(np.asarray(colour, dtype=np.float64), tuple(shape) + (3,)).copy()


# --- hashing and noise ---------------------------------------------------------------------------
_M32 = np.uint64(0xFFFFFFFF)
_K = np.uint64(0x45D9F3B)
_S16 = np.uint64(16)


def hash01(seed, *ks):
    """A repeatable random number in [0, 1) for each combination of integers (arrays broadcast)."""
    arrays = [np.asarray(k) for k in ks]
    shape = np.broadcast(*arrays).shape if arrays else ()
    h = np.full(shape, (seed * 2654435761 + 0x9E3779B9) & 0xFFFFFFFF, dtype=np.uint64)
    for k in arrays:
        k = np.asarray(np.floor(k) if k.dtype.kind == "f" else k).astype(np.int64).astype(np.uint64) & _M32
        h = ((h ^ k) * _K) & _M32
        h = ((h ^ (h >> _S16)) * _K) & _M32
        h = h ^ (h >> _S16)
    return (h & np.uint64(0xFFFFFF)).astype(np.float64) / 16777216.0


def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def vnoise2(x, y, seed=0):
    xf, yf = np.floor(x), np.floor(y)
    u, v = _fade(x - xf), _fade(y - yf)
    xi, yi = xf.astype(np.int64), yf.astype(np.int64)
    a = hash01(seed, xi, yi)
    b = hash01(seed, xi + 1, yi)
    c = hash01(seed, xi, yi + 1)
    d = hash01(seed, xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm2(x, y, seed=0, octaves=4, gain=0.5):
    total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
    for i in range(octaves):
        total = total + amp * vnoise2(x * f + 17.31 * i, y * f - 9.73 * i, seed + 101 * i)
        norm += amp
        amp *= gain
        f *= 2.03
    return total / norm


def vnoise3(x, y, z, seed=0):
    xf, yf, zf = np.floor(x), np.floor(y), np.floor(z)
    u, v, w = _fade(x - xf), _fade(y - yf), _fade(z - zf)
    xi, yi, zi = xf.astype(np.int64), yf.astype(np.int64), zf.astype(np.int64)
    out = 0.0
    for dx in (0, 1):
        wx = u if dx else 1 - u
        for dy in (0, 1):
            wy = v if dy else 1 - v
            for dz in (0, 1):
                wz = w if dz else 1 - w
                out = out + hash01(seed, xi + dx, yi + dy, zi + dz) * wx * wy * wz
    return out


def fbm3(x, y, z, seed=0, octaves=4, gain=0.5):
    total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
    for i in range(octaves):
        total = total + amp * vnoise3(x * f + 17.31 * i, y * f - 9.73 * i, z * f + 5.1 * i, seed + 101 * i)
        norm += amp
        amp *= gain
        f *= 2.03
    return total / norm


def ridge(n, width):
    """Thin wandering lines where a noise field crosses 0.5 (cracks, veins). 1 on the line."""
    return 1.0 - smoothstep(0.0, width, np.abs(n - 0.5))


# --- maps ----------------------------------------------------------------------------------------
def height_to_normal(height, px_per_stud, strength=1.0):
    """OpenGL tangent-space normal map (rows = v, columns = u) from a height field in studs."""
    gv, gu = np.gradient(height)
    k = px_per_stud * strength
    n = np.stack([-gu * k, -gv * k, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save_png(path, data, colour=True, name=None):
    """Writes an (h, w, 3) array (linear colour, or raw data when colour=False) as an 8-bit PNG."""
    import bpy

    h, w = data.shape[:2]
    rgb_data = linear_to_srgb(data) if colour else np.clip(data, 0.0, 1.0)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., :3] = rgb_data
    img = bpy.data.images.new(name or os.path.basename(path), w, h, alpha=False)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def save_maps(tex_dir, name, colour, height=None, rough=None, px_per_stud=16.0, crop=0, normal_strength=1.0):
    """Saves colour (+ normal from height, + glTF metallic-roughness) for one texture. `crop` trims a
    padding border that was painted only so the normals are right at the edges."""
    os.makedirs(tex_dir, exist_ok=True)
    sl = (slice(crop, -crop), slice(crop, -crop)) if crop else (slice(None), slice(None))
    paths = {"colour": save_png(os.path.join(tex_dir, f"{name}_Color.png"), colour[sl])}
    if height is not None:
        nrm = height_to_normal(height, px_per_stud, normal_strength)[sl]
        paths["normal"] = save_png(os.path.join(tex_dir, f"{name}_Normal.png"), nrm, colour=False)
    if rough is not None:
        r = rough[sl]
        mr = np.stack([np.ones_like(r), r, np.zeros_like(r)], axis=-1)
        paths["mr"] = save_png(os.path.join(tex_dir, f"{name}_MR.png"), mr, colour=False)
    return paths
