"""Backdrop props for the arenas ("sights"): a small kit for building low-poly, flat-coloured scenery
from many colours without breaking Roblox's one-material-per-mesh rule, plus the shared props.

A `Kit` holds one bmesh per colour. Props add geometry by colour key; `finish()` turns each colour into
one mesh named <prefix>_<key> with a flat material (the exporter gives those a shared 64 px texture).
`mark()` / `move()` let a prop be built at the origin and then placed, tilted or squashed.

Composition rules the maps follow (vault: "World Composition and Set Dressing", "Level Design
Principles - Flow Sightlines and Landmarks"): one hero sight per direction, different distances (rim
overlook, middle distance, horizon), varied scale, and open sky between them. Nothing here collides.
Sights below the rim line stay hidden from mid-arena and open up as a player nears that edge, so the
landable edge always reads against calm sky or far haze.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import common as C
import paint as P

SKY = (0.62, 0.74, 0.92)  # what distant things lean toward (clear blue, no purple)


def lin(c):
    """sRGB 0-255 -> linear tuple."""
    return tuple(float(v) for v in P.rgb(*c))


def hazed(c, k):
    return tuple(a + (b - a) * k for a, b in zip(c, SKY))


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Kit:
    def __init__(self, prefix, colours, haze=0.0, rough=0.9, glow=0.0):
        # `glow` is a little emission for thin cloth and cloud seen against the light (Blender only:
        # the export carries the colour, and Roblox's ambient light does this job there).
        self.prefix, self.colours, self.haze, self.rough, self.glow = prefix, colours, haze, rough, glow
        self.bms = {}

    def bm(self, key):
        if key not in self.bms:
            if key not in self.colours:
                raise KeyError(f"{self.prefix}: no colour '{key}'")
            self.bms[key] = bmesh.new()
        return self.bms[key]

    def box(self, key, centre, size, rot_z=0.0):
        C.box(self.bm(key), centre, size, rot_z)

    def cyl(self, key, a, b, r, sides=8):
        C.cylinder(self.bm(key), a, b, r, sides)

    def cone(self, key, base, r, h, sides=8):
        C.cone(self.bm(key), base, r, h, sides=sides)

    def mark(self):
        return {k: len(b.verts) for k, b in self.bms.items()}

    def move(self, marks, matrix):
        """Transforms everything added since `marks`."""
        for k, b in self.bms.items():
            for v in list(b.verts)[marks.get(k, 0) :]:
                v.co = matrix @ v.co

    def finish(self):
        objs = []
        for k, b in self.bms.items():
            if not b.verts:
                b.free()
                continue
            mat = C.flat_material(f"{self.prefix}_{k}", hazed(lin(self.colours[k]), self.haze), self.rough, self.glow)
            objs.append(C.mesh_object(f"{self.prefix}_{k}", b, mat))
        self.bms = {}
        return objs


# --- small shapes --------------------------------------------------------------------------------
def tri2(bm, a, b, c):
    """A two-sided triangle (cloth: flags, sails, nets)."""
    bm.faces.new([bm.verts.new(p) for p in (a, b, c)])
    bm.faces.new([bm.verts.new(p) for p in (c, b, a)])


def quad2(bm, a, b, c, d):
    bm.faces.new([bm.verts.new(p) for p in (a, b, c, d)])
    bm.faces.new([bm.verts.new(p) for p in (d, c, b, a)])


def gable(bm, centre, w, d, h, rot_z=0.0):
    """A pitched roof: a triangular prism, ridge along local X, base at centre's height."""
    cx, cy, cz = centre
    c, s = math.cos(rot_z), math.sin(rot_z)

    def at(x, y, z):
        return (cx + x * c - y * s, cy + x * s + y * c, cz + z)

    pts = [at(-w / 2, -d / 2, 0), at(w / 2, -d / 2, 0), at(w / 2, d / 2, 0), at(-w / 2, d / 2, 0), at(-w / 2, 0, h), at(w / 2, 0, h)]
    v = [bm.verts.new(p) for p in pts]
    for f in ((3, 2, 1, 0), (0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)):
        bm.faces.new([v[i] for i in f])


def ring_stack(bm, centre, rings, sides=10, rng=None, jitter=0.1):
    """A faceted column from stacked rings [(radius, z), ...] bottom to top: sea stacks, spires."""
    cx, cy = centre
    loops = []
    for r, z in rings:
        loop = []
        for i in range(sides):
            a = i / sides * math.tau
            j = 1 + (rng.uniform(-jitter, jitter) if rng else 0)
            loop.append(bm.verts.new((cx + r * j * math.cos(a), cy + r * j * math.sin(a), z)))
        loops.append(loop)
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    for lo, hi in zip(loops, loops[1:]):
        for i in range(sides):
            n = (i + 1) % sides
            bm.faces.new((lo[i], lo[n], hi[n], hi[i]))


def strip(bm, pts, width, zfn, lift=0.6, step=20.0):
    """A ribbon laid over terrain along a path (roads, streams). `zfn(x, y)` is the ground height."""
    path = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for i in range(n):
            t = i / n
            path.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    path.append(pts[-1])
    rows = []
    for i, (x, y) in enumerate(path):
        ax, ay = path[min(i + 1, len(path) - 1)]
        bx, by = path[max(i - 1, 0)]
        dx, dy = ax - bx, ay - by
        ln = math.hypot(dx, dy) or 1.0
        px, py = -dy / ln * width / 2, dx / ln * width / 2
        rows.append(
            (bm.verts.new((x + px, y + py, zfn(x + px, y + py) + lift)), bm.verts.new((x - px, y - py, zfn(x - px, y - py) + lift)))
        )
    for (l0, r0), (l1, r1) in zip(rows, rows[1:]):
        bm.faces.new((r0, r1, l1, l0))


# --- props ---------------------------------------------------------------------------------------
def house(kit, pos, w, d, h, rot=0.0, wall="wall", roof="roof", gable_key=None, roof_h=None):
    """Walls and a pitched roof; `gable_key` paints both gable ends (the painted timber ends)."""
    x, y, z = pos
    kit.box(wall, (x, y, z + h / 2), (w, d, h), rot)
    rh = roof_h or d * 0.45
    gable(kit.bm(roof), (x, y, z + h), w + 3, d + 4, rh, rot)
    if gable_key:
        for s in (-1, 1):
            off = s * (w / 2 + 1.7)
            gable(kit.bm(gable_key), (x + off * math.cos(rot), y + off * math.sin(rot), z + h), 0.6, d * 0.85, rh * 0.85, rot)


def tree(kit, at, height, radius, rng, trunk="trunk", canopy="canopy"):
    """A layered-canopy tree (stacked ragged discs)."""
    x, y, z = at
    kit.cyl(trunk, (x, y, z), (x, y, z + height), radius * 0.12, 6)
    C.canopy(kit.bm(canopy), (x, y, z + height * 0.85), radius, layers=3, rng=rng)


def pennants(kit, a, b, keys, n=10, sag=3.0, size=3.0, string="rope"):
    """A sagging line of triangular pennants between two points."""
    a, b = Vector(a), Vector(b)
    d = b - a
    side = Vector((d.x, d.y, 0)).normalized()
    prev = a.copy()
    for i in range(1, n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * 4 * t * (1 - t)
        kit.cyl(string, prev, p, 0.12, 4)
        mid = (prev + p) / 2
        tri2(kit.bm(keys[i % len(keys)]), mid - side * size * 0.5, mid + side * size * 0.5, mid - Vector((0, 0, size * 1.3)))
        prev = p


ENVELOPE = [(0.2, -1.3), (0.42, -1.0), (0.76, -0.52), (0.96, -0.08), (1.0, 0.22), (0.9, 0.56), (0.66, 0.82), (0.32, 0.96)]


def envelope(kit, keys, radius, gores=12):
    """A hot-air balloon's envelope at the origin (crown up), one colour per gore."""
    for g in range(gores):
        a0, a1 = g / gores * math.tau, (g + 1) / gores * math.tau
        bm = kit.bm(keys[g % len(keys)])
        prev = None
        for r, z in ENVELOPE:
            cur = (
                bm.verts.new((radius * r * math.cos(a0), radius * r * math.sin(a0), radius * z)),
                bm.verts.new((radius * r * math.cos(a1), radius * r * math.sin(a1), radius * z)),
            )
            if prev:
                bm.faces.new((prev[0], prev[1], cur[1], cur[0]))
            prev = cur
        bm.faces.new((prev[0], prev[1], bm.verts.new((0, 0, radius))))


def balloon(kit, pos, radius, keys, heading=0.0):
    """A flying balloon: envelope, basket, ropes, burner. Kit needs basket, trim, rope, burner."""
    m = kit.mark()
    envelope(kit, keys, radius)
    b = radius * 0.3
    zb = -radius * 1.95
    kit.box("basket", (0, 0, zb), (b, b, b * 0.8))
    kit.box("trim", (0, 0, zb + b * 0.42), (b * 1.12, b * 1.12, b * 0.14))
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.cyl("rope", (sx * b / 2, sy * b / 2, zb + b * 0.4), (sx * radius * 0.14, sy * radius * 0.14, -radius * 1.3), 0.15 + radius * 0.006, 4)
    kit.box("burner", (0, 0, -radius * 1.5), (b * 0.3, b * 0.3, b * 0.3))
    kit.move(m, Matrix.Translation(pos) @ Matrix.Rotation(heading, 4, "Z"))


def net_rack(kit, centre, width, height, facing, frame="timber", net="net", floats="float"):
    """A fishing net drying on an A-frame rack: the net slopes down toward `facing` (radians)."""
    m = kit.mark()
    hw = width / 2
    for sy in (-1, 1):
        kit.cyl(frame, (-height * 0.22, sy * hw, 0), (0, sy * hw, height), 0.5, 5)
        kit.cyl(frame, (height * 0.22, sy * hw, 0), (0, sy * hw, height), 0.5, 5)
    kit.cyl(frame, (0, -hw - 1, height), (0, hw + 1, height), 0.45, 5)
    reach = height * 0.62
    quad2(kit.bm(net), (0, -hw + 1, height - 0.4), (0, hw - 1, height - 0.4), (reach, hw - 1, 0.6), (reach, -hw + 1, 0.6))
    for i in range(5):
        kit.box(floats, (reach + 0.4, -hw + 2 + i * (width - 4) / 4, 1.0), (1.3, 1.3, 1.3))
    kit.move(m, Matrix.Translation(centre) @ Matrix.Rotation(facing, 4, "Z"))


# --- land ----------------------------------------------------------------------------------------
def height_material(name, stops, z_lo, z_hi, haze=0.0, patch_scale=0.012, linear=False):
    """Colour by height (a ramp from z_lo to z_hi), broken into soft field-like patches."""
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    h = C.math_node(nt, "SUBTRACT", sep.outputs["Z"], value_b=z_lo)
    norm = C.math_node(nt, "DIVIDE", h.outputs[0], value_b=z_hi - z_lo)
    clamp = C.math_node(nt, "MAXIMUM", norm.outputs[0], value_b=0.0)
    r = C.ramp(nt, [(p, hazed(c if linear else lin(c), haze)) for p, c in stops])
    nt.links.new(clamp.outputs[0], r.inputs["Fac"])
    fields = C.node(nt, "ShaderNodeTexVoronoi", Scale=patch_scale)
    nt.links.new(tc.outputs["Object"], fields.inputs["Vector"])
    fs = C.separate(nt, fields.outputs["Color"])
    patch = C.ramp(nt, [(0.0, (0.93, 0.93, 0.93)), (0.5, (1, 1, 1)), (1.0, (1.05, 1.04, 0.95))])
    nt.links.new(fs.outputs["X"], patch.inputs["Fac"])
    out = C.multiply_colours(nt, r.outputs["Color"], patch.outputs["Color"])
    nt.links.new(out.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def rock_material(name, base, haze=0.0, scale=0.02):
    """Painted rock: one colour in broad soft blots (the facets do the chipping)."""
    base = hazed(lin(base), haze)
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    blot = C.node(nt, "ShaderNodeTexNoise", Scale=scale, Detail=3.0)
    nt.links.new(tc.outputs["Object"], blot.inputs["Vector"])
    r = C.ramp(nt, [(0.3, tuple(c * 0.82 for c in base)), (0.5, base), (0.7, tuple(min(c * 1.08, 1) for c in base))])
    nt.links.new(blot.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def terrain(name, fn, xs, ys, mat, keep=None, smooth_shade=False):
    """A height-field mesh over the grid xs x ys, `fn(x, y)` giving the height. `keep(x, y)` (cell
    centres) cuts it to a shape. UVs are laid straight down and marked to be kept by the exporter."""
    bm = bmesh.new()
    grid = [[bm.verts.new((x, y, fn(x, y))) for x in xs] for y in ys]
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            if keep and not keep((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2):
                continue
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    obj = C.mesh_object(name, bm, mat, smooth=smooth_shade)
    me = obj.data
    uv = me.uv_layers.new(name="UVMap")
    x0, x1, y0, y1 = xs[0], xs[-1], ys[0], ys[-1]
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x - x0) / (x1 - x0), (co.y - y0) / (y1 - y0))
    obj["keep_uv"] = True
    return obj


def island(name, centre, rx, ry, depth, rng, top_mat, rock_mat, segs=18, cap=3.0):
    """A floating island: a thin grass cap on a faceted rock cone. Makes <name>Grass and <name>Rock."""
    cx, cy, cz = centre
    out = []
    for suffix, mat, args in (
        ("Grass", top_mat, dict(a=rx, b=ry, z_top=cz, z_bottom=cz - cap, segments=segs, jitter=0.05, rng=rng)),
        ("Rock", rock_mat, dict(a=rx * 0.98, b=ry * 0.97, z_top=cz - cap, z_bottom=cz - depth, segments=max(8, segs * 2 // 3), jitter=0.1, rng=rng, taper=0.2)),
    ):
        bm = bmesh.new()
        C.oval_prism(bm, **args)
        for v in bm.verts:
            v.co.x += cx
            v.co.y += cy
        out.append(C.mesh_object(name + suffix, bm, mat))
    return out


def linspace(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]
