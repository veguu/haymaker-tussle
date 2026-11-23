"""DESIGN BLOCKOUTS for suite maps 2 to 6 (2026-11-21). A design sheet for the owner to pick from: nothing here is
approved, baked, exported or uploaded.

    blender -b --factory-startup -P <map>.py -- <out folder> --dry --no-render

Each map script (quarry.py, steppe.py, saltbasin.py, sundial.py, orchard.py) execs base.py, then this file, adds its
own pieces and calls sketch_run(). That runs base.run() in dry mode (geometry, triangle counts, collision.json, a
<map>_dry.blend) and then a quick EEVEE look: every piece in its flat palette colour, the map's floor painter at 512
px a tile, from three fixed cameras (Over, Fighter, Side), the same for every map so they compare.

Only TOOLS live here (shapes, islands, the render). Every map's signature pieces stay in its own script, so no two
maps share a set piece (owner, 2026-11-20), and nothing here comes from the lobby.
"""
# base.py has already been exec'd into this namespace (A, B, W, oval, course, add, PAL, srgb, chunk, lump, tube, ...)

EYE = 5.5
BUILD = not DRY  # a full build (paint bake, export) rather than the design sheet's quick look


def to_arena(p):
    """A Blender point -> arena-local Roblox [x, y, z] (y up)."""
    p = Vector(p)
    return [round(p.x, 2), round(p.z, 2), round(-p.y, 2)]


def beam_chain(points, widths, colour, texture="Ribbon", speed=1.0, transparency=(0.15, 0.9), light=0.15):
    """Records a camera-facing Beam chain through Blender points (built in Studio by studio_map.py, not exported as
    a mesh): waterfalls, streamers. `widths` per point; `transparency` from the first point to the last."""
    DATA.setdefault("beams", []).append({
        "points": [to_arena(p) for p in points], "widths": [round(float(w), 2) for w in widths],
        "colour": [int(c) for c in colour], "texture": texture, "speed": speed,
        "transparency": [float(transparency[0]), float(transparency[1])], "light": light,
    })


def map_data(near, floor_colour, floor_material, floor_detail=None):
    """What Studio needs to know: the arena's own elements (everything else is far backdrop: no shadows, HT_Far, the
    phone path), the floor collider's colour and material (footsteps, debris colour) and, when given, the floor's
    walkable detail (owner 2026-11-21): {"image": <file in the build folder>, "tile": studs, "transparency": 0..1},
    laid on every floor tile as a Roblox Texture by studio_map.py (its asset id comes from upload_ids.json)."""
    DATA["near"] = list(near)
    DATA["floor"] = {"colour": [int(c) for c in floor_colour], "material": floor_material}
    if floor_detail:
        DATA["floor_detail"] = dict(floor_detail)


def T(*co):
    return Matrix.Translation(co)


def Rz(a):
    return Matrix.Rotation(a, 4, "Z")


def Rx(a):
    return Matrix.Rotation(a, 4, "X")


def Ry(a):
    return Matrix.Rotation(a, 4, "Y")


def facing(x, z, tx, tz):
    """The yaw that turns local -y (a piece's front) toward (tx, tz), arena-local."""
    return math.atan2(tx - x, tz - z)


def at(x, z, y, yaw=0.0):
    """A matrix standing a piece at arena-local (x, z) height y, turned by yaw."""
    return Matrix.Translation(W(x, z, y)) @ Rz(yaw)


def mat_name(key):
    return key.split("_")[-1].capitalize()


def place(element, key, b, matrix=Matrix(), region=""):
    add(element, mat_name(key), key, b, matrix, region=region)


# --- shapes -------------------------------------------------------------------------------------------------------
def bbox(size, bevel=0.35, taper=(1.0, 1.0)):
    """A box from z = 0 up, sized (sx, sy, sz), its top scaled by `taper`, edges bevelled."""
    sx, sy, sz = size
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    for v in b.verts:
        top = v.co.z > 0
        fx, fy = taper if top else (1.0, 1.0)
        v.co = Vector((v.co.x * sx * fx, v.co.y * sy * fy, (v.co.z + 0.5) * sz))
    if bevel > 0:
        bmesh.ops.bevel(b, geom=b.edges[:], offset=min(bevel, 0.3 * min(sx, sy, sz)), segments=1, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(b, faces=b.faces[:])
    return b


def ring_prism(rings, n, close_bottom=True, close_top=True, sx=1.0, sy=1.0):
    """A turned shape: rings = [(radius, height)] bottom to top, n sides (x and y scaled by sx, sy)."""
    bm = bmesh.new()
    loops = [[bm.verts.new((math.cos((i + 0.5) / n * math.tau) * r * sx, math.sin((i + 0.5) / n * math.tau) * r * sy, h)) for i in range(n)] for r, h in rings]
    if close_bottom:
        bm.faces.new(list(reversed(loops[0])))
    if close_top:
        bm.faces.new(loops[-1])
    for lo, hi in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def annulus(r0, r1, h0, h1, n):
    """A flat ring (a deck, or a band round a turned shape)."""
    bm = bmesh.new()
    ang = [(i + 0.5) / n * math.tau for i in range(n)]
    lo0 = [bm.verts.new((math.cos(a) * r0, math.sin(a) * r0, h0)) for a in ang]
    lo1 = [bm.verts.new((math.cos(a) * r1, math.sin(a) * r1, h0)) for a in ang]
    hi0 = [bm.verts.new((math.cos(a) * r0, math.sin(a) * r0, h1)) for a in ang]
    hi1 = [bm.verts.new((math.cos(a) * r1, math.sin(a) * r1, h1)) for a in ang]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((hi0[i], hi1[i], hi1[j], hi0[j]))
        bm.faces.new((lo0[j], lo1[j], lo1[i], lo0[i]))
        bm.faces.new((lo1[i], lo1[j], hi1[j], hi1[i]))
        bm.faces.new((lo0[j], lo0[i], hi0[i], hi0[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def rod(p0, p1, r, sides=6):
    """A straight round bar (rope, spar, pole) between two Blender points."""
    b = bmesh.new()
    tube(b, [p0, p1], [r, r], sides=sides)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return b


def hoop(radius, r, sides=6, n=32, arc=math.tau, start=0.0):
    """A ring (or an arc of one) of round section in the XZ plane, centred at the origin (a wheel, an arch)."""
    pts = [(math.cos(start + arc * i / n) * radius, 0.0, math.sin(start + arc * i / n) * radius) for i in range(n + 1)]
    b = bmesh.new()
    tube(b, pts, [r] * len(pts), sides=sides, caps=(arc < math.tau - 1e-3, arc < math.tau - 1e-3))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return b


def oval_slab(inset_top, inset_bot, h_top, h_bot, n=96, shift=(0.0, 0.0)):
    """A solid under the arena: the oval at `inset_top` and height h_top down to the oval at `inset_bot` and h_bot
    (moved by `shift` studs, arena-local x, z)."""
    bm = bmesh.new()
    top = [bm.verts.new(W(*oval(i / n * math.tau, inset_top)[:2], h_top)) for i in range(n)]
    bot = []
    for i in range(n):
        x, z = oval(i / n * math.tau, inset_bot)[:2]
        bot.append(bm.verts.new(W(x + shift[0], z + shift[1], h_bot)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[i], bot[i], bot[j], top[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def ellipse_slab(rx, rz, h_top, h_bot, n=32, k_bot=1.0, wob=None, shift=(0.0, 0.0)):
    """A solid ellipse slab in local coordinates (x across, y = -z), top at h_top, its bottom scaled by k_bot and
    moved by `shift` (local x, z); `wob(a)` scales the outline at angle a."""
    bm = bmesh.new()
    wob = wob or (lambda a: 1.0)
    top, bot = [], []
    for i in range(n):
        a = i / n * math.tau
        k = wob(a)
        top.append(bm.verts.new((math.cos(a) * rx * k, -math.sin(a) * rz * k, h_top)))
        bot.append(bm.verts.new((math.cos(a) * rx * k * k_bot + shift[0], -math.sin(a) * rz * k * k_bot - shift[1], h_bot)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[i], bot[i], bot[j], top[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


# --- islands: a registry so pieces can stand on whichever island holds them -------------------------------------
ISLES = {}


def isle(name, cx, cz, rx, rz, top, hill=0.0, flat=None, shape=None):
    """Registers a floating island: its centre, semi-axes, edge height `top`, a rise `hill` in the middle, and
    optionally a flat shelf (cx, cz, radius, height) where buildings stand, or `shape(u, v)` -> extra height
    (u, v from -1 to 1 across the island)."""
    ISLES[name] = {"name": name, "cx": cx, "cz": cz, "rx": rx, "rz": rz, "top": top, "hill": hill, "s": sum(map(ord, name)), "flat": flat, "shape": shape}
    return ISLES[name]


def edge_dist(X, Z):
    """Distance in studs from arena-local (X, Z) to the oval's edge, near enough (1 - rho over its gradient)."""
    rho = np.sqrt((X / A) ** 2 + (Z / B) ** 2)
    g = np.sqrt((X / A ** 2) ** 2 + (Z / B ** 2) ** 2) / np.maximum(rho, 1e-6)
    return (1.0 - rho) / np.maximum(g, 1e-6)


def outline(i, a):
    s = i["s"]
    return 1.0 + 0.07 * math.sin(3 * a + s) + 0.04 * math.sin(5 * a + s * 0.7)


def sstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def isle_h(i, x, z):
    u, v = (x - i["cx"]) / i["rx"], (z - i["cz"]) / i["rz"]
    h = i["top"] + i["hill"] * math.exp(-((u / 0.6) ** 2 + (v / 0.6) ** 2)) + 1.2 * math.sin(x / 23.0 + z / 31.0)
    if i.get("shape"):
        h += i["shape"](u, v)
    if i["flat"]:
        fx, fz, fr, fh = i["flat"]
        h += (fh - h) * sstep(fr * 1.25, fr, math.hypot(x - fx, z - fz))
    return h


def H(x, z):
    best = min(ISLES.values(), key=lambda i: ((x - i["cx"]) / i["rx"]) ** 2 + ((z - i["cz"]) / i["rz"]) ** 2)
    return isle_h(best, x, z)


def isle_top(i, key, side_key, side=6.0, n=40, element="Island"):
    """The island's walkable top (a fan of rings following its ground, out to a wobbly edge) and a side band `side`
    studs deep under the edge."""
    cx, cz, rx, rz = i["cx"], i["cz"], i["rx"], i["rz"]
    bm = bmesh.new()
    centre = bm.verts.new(W(cx, cz, isle_h(i, cx, cz)))
    rings = []
    for f in (0.22, 0.45, 0.66, 0.84, 1.0):
        ring = []
        for k in range(n):
            a = k / n * math.tau
            x, z = cx + math.cos(a) * rx * f * outline(i, a), cz + math.sin(a) * rz * f * outline(i, a)
            ring.append(bm.verts.new(W(x, z, isle_h(i, x, z))))
        rings.append(ring)
    for k in range(n):
        bm.faces.new((centre, rings[0][k], rings[0][(k + 1) % n]))
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((r0[k], r1[k], r1[j]))
            bm.faces.new((r0[k], r1[j], r0[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    place(element, key, bm, region=i["name"])
    sb = bmesh.new()
    up, lo = [], []
    for k in range(n):
        a = k / n * math.tau
        o = outline(i, a)
        x, z = cx + math.cos(a) * rx * o, cz + math.sin(a) * rz * o
        up.append(sb.verts.new(W(x, z, isle_h(i, x, z) + 0.2)))
        lo.append(sb.verts.new(W(cx + math.cos(a) * rx * o * 0.98, cz + math.sin(a) * rz * o * 0.98, i["top"] - side)))
    for k in range(n):
        j = (k + 1) % n
        sb.faces.new((up[k], lo[k], lo[j], up[j]))
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces[:])
    place(element, side_key, sb, region=i["name"])


def scatter(i, count, rng, inner=0.0, outer=0.8, avoid=(), gap=20.0):
    """Points on island i (within outer of its size, outside inner), away from `avoid` points and each other."""
    out = []
    tries = 0
    while len(out) < count and tries < count * 40:
        tries += 1
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.uniform(inner * inner, outer * outer))
        x, z = i["cx"] + math.cos(a) * i["rx"] * r, i["cz"] + math.sin(a) * i["rz"] * r
        if any(math.hypot(x - px, z - pz) < gap for px, pz in list(avoid) + out):
            continue
        out.append((x, z))
    return out


def rope_bridge(element, plank_key, rope_key, a, b, sag, region, width=8.0, step=4.0):
    """A plank bridge on two ropes between Blender points a and b, hanging `sag` studs at its middle."""
    a, b = Vector(a), Vector(b)
    n = max(2, int((b - a).length / step))
    d = (b - a)
    side = Vector((-d.y, d.x, 0.0)).normalized() * width / 2
    yaw = math.atan2(d.y, d.x)
    pts = []
    for k in range(n + 1):
        t = k / n
        p = a + d * t + Vector((0, 0, -sag * 4 * t * (1 - t)))
        pts.append(p)
        if 0 < k < n:
            pl = bbox((step * 0.8, width, 0.8), 0.2)
            place(element, plank_key, pl, Matrix.Translation(p) @ Rz(yaw - math.pi / 2 + math.pi / 2), region=region)
    for s in (-1, 1):
        b2 = bmesh.new()
        tube(b2, [p + side * s + Vector((0, 0, 3.0)) for p in pts], [0.45] * len(pts), sides=4)
        place(element, rope_key, b2, region=region)


def ball_tree(x, z, s, rng, leaf_key, bark_key="bark", region="", element="Trees", y=None):
    """A chunky storybook tree for blockouts: a short kinked trunk and two or three faceted canopy masses."""
    y = H(x, z) if y is None else y
    b = bmesh.new()
    tube(b, [(0, 0, -1.0), (0.4 * s, 0, 5.0 * s), (0.6 * s, 0.3 * s, 9.0 * s)], [1.1 * s, 0.85 * s, 0.6 * s], sides=6, rng=rng)
    place(element, bark_key, b, at(x, z, y, rng.uniform(0, 6.28)), region=region)
    for k in range(rng.randint(2, 3)):
        c = lump(5.2 * s * rng.uniform(0.8, 1.1), rng, squash=0.78, jitter=0.14, subdiv=1, flat_bottom=0.4)
        bmesh.ops.triangulate(c, faces=c.faces[:])
        off = (rng.uniform(-3, 3) * s, rng.uniform(-3, 3) * s, (10.0 + k * 3.0) * s)
        place(element, leaf_key, c, at(x, z, y, rng.uniform(0, 6.28)) @ T(*off), region=region)


# --- the look: flat palette colours, the painted floor, three fixed cameras --------------------------------------
def _flat(key):
    name = "D_" + key
    m = bpy.data.materials.get(name)
    if m is None:
        m = C.flat_material(name, tuple(float(c) for c in PAL[key][0]), 0.92)
        if key.startswith("glow"):
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Emission Color"].default_value = (*tuple(float(c) for c in PAL[key][0]), 1)
            bsdf.inputs["Emission Strength"].default_value = 1.5
    return m


def paint_floor(painter, nx=3, nz=2, px=512):
    for _a, _k, obj in REGISTRY:
        if "_Floor_" not in obj.name:
            continue
        ij = obj.name.rsplit("_", 1)[-1]
        i, j = int(ij[0]) - 1, int(ij[1]) - 1
        x0, x1 = -A + i * 2 * A / nx, -A + (i + 1) * 2 * A / nx
        y0, y1 = -B + j * 2 * B / nz, -B + (j + 1) * 2 * B / nz
        u = (np.arange(px) + 0.5) / px
        X = np.broadcast_to(x0 + u[None, :] * (x1 - x0), (px, px))
        Yb = np.broadcast_to((y0 + u * (y1 - y0))[:, None], (px, px))
        col = painter(X, -Yb)
        path = P.save_png(os.path.join(TEX, f"{obj.name}_Design.png"), np.clip(col, 0, 1))
        obj.data.materials.clear()
        obj.data.materials.append(S.image_material(f"{obj.name}_Design", {"colour": path}, roughness=0.95))
        print("FLOOR", obj.name, flush=True)


def floor_swatch(painter, path, size=(1024, 846)):
    """The whole floor from straight above (its oval on sky colour): the sheet's floor panel."""
    w, h = size
    X = np.broadcast_to(np.linspace(-A, A, w)[None, :], (h, w))
    Z = np.broadcast_to(np.linspace(B, -B, h)[:, None], (h, w))  # image rows run bottom (south, +z) to top (north)
    col = painter(X, Z)
    inside_ = (X / A) ** 2 + (Z / B) ** 2 <= 1.0
    bg = np.array([0.30, 0.52, 0.86])
    col = np.where(inside_[..., None], col, bg)
    P.save_png(path, np.clip(col, 0, 1))


def design_cameras():
    return {
        # high over the lobby side: the arena in the lower half, the whole backdrop behind it
        "Over": C.camera("D_Over", W(380, 760, 460), W(-40, -420, -40), lens=24),
        # behind a fighter on the lobby side, looking north across the floor at the backdrop
        "Fighter": C.camera("D_Fighter", W(-30, B * SPAWN_SHARE + 18, EYE + 9), W(20, -60, 0), lens=24),
        # from out in the sky off the sunlit west end, a little under the rim: the edge and the underside
        "Side": C.camera("D_Side", W(-540, 190, -50), W(-40, -170, -80), lens=26),
    }


def proxy_fighters():
    """Render-only stand-ins (never exported, not in REGISTRY): blocky 5-stud fighters in bright shirts in front of
    the Fighter camera, for scale and to check that the fighters stay the brightest thing on screen."""
    col = preview_collection()
    for k, (x, z, shirt) in enumerate(((-18.0, 96.0, (0.85, 0.08, 0.06)), (8.0, 52.0, (0.05, 0.25, 0.9)), (40.0, 0.0, (0.95, 0.75, 0.02)), (-60.0, 20.0, (0.1, 0.7, 0.2)))):
        parts = (((1.0, 1.0, 2.0), (-0.5, 0.0, 0.0), (0.12, 0.2, 0.5)), ((1.0, 1.0, 2.0), (0.5, 0.0, 0.0), (0.12, 0.2, 0.5)),
                 ((2.0, 1.0, 2.0), (0.0, 0.0, 2.0), shirt), ((1.0, 1.0, 2.0), (-1.5, 0.0, 2.0), (1.0, 0.8, 0.55)),
                 ((1.0, 1.0, 2.0), (1.5, 0.0, 2.0), (1.0, 0.8, 0.55)), ((1.2, 1.2, 1.1), (0.0, 0.0, 4.0), (1.0, 0.8, 0.55)))
        for q, (size, off, c) in enumerate(parts):
            b = bbox(size, 0.08)
            me = bpy.data.meshes.new(f"Proxy{k}_{q}")
            b.to_mesh(me)
            b.free()
            ob = bpy.data.objects.new(f"Proxy{k}_{q}", me)
            col.objects.link(ob)
            ob.matrix_world = at(x, z, 0.0, 0.4 * k) @ T(*off)
            ob.data.materials.append(C.flat_material(f"P{k}_{q}", c, 0.6))


def landmark_size(elements):
    """The landmark's bounding box in studs (x, z across, y up), from its meshes (elements = the element names)."""
    lo, hi = [1e9] * 3, [-1e9] * 3
    for asset, _k, o in REGISTRY:
        if asset.split("_")[2] not in elements:
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                lo[i], hi[i] = min(lo[i], w[i]), max(hi[i], w[i])
    if lo[0] > hi[0]:
        return None
    return {"across_x": round(hi[0] - lo[0]), "across_z": round(hi[1] - lo[1]), "height": round(hi[2] - lo[2]), "top_y": round(hi[2])}


def sketch_run(name, builders, painter, sun=(225, 38), nx=3, nz=2, landmark=(), floor_px=512):
    if BUILD:  # the full build: base.run bakes the lobby's paint, paints the floor at 1024 px, exports and renders
        run(name, builders, sun=sun)
        lm = landmark_size(landmark)
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for _, _, o in REGISTRY)
        json.dump({"map": name, "triangles": tris, "meshes": len(REGISTRY), "over_limit": [list(b) for b in check()], "landmark": lm},
                  open(os.path.join(OUT, "build_stats.json"), "w", encoding="utf-8"), indent=1)
        print("BUILD DONE", name, "TRIANGLES", tris, "MESHES", len(REGISTRY), "LANDMARK", lm, flush=True)
        return
    run(name, builders, sun=sun)
    proxy_fighters()
    for _a, key, obj in REGISTRY:
        if "_Floor_" in obj.name:
            continue
        obj.data.materials.clear()
        obj.data.materials.append(_flat(key))
    paint_floor(painter, nx, nz, px=floor_px)
    floor_swatch(painter, os.path.join(OUT, "design_floor.png"))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    C.render_all(OUT, "design", design_cameras(), resolution=(1280, 720))
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for _, _, o in REGISTRY)
    bad = check()
    lm = landmark_size(landmark)
    print("LANDMARK", name, lm, flush=True)
    json.dump({"map": name, "triangles": tris, "meshes": len(REGISTRY), "over_limit": [list(b) for b in bad], "landmark": lm},
              open(os.path.join(OUT, "design_stats.json"), "w", encoding="utf-8"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{name.lower()}_design.blend"))
    print("DESIGN DONE", name, "TRIANGLES", tris, "MESHES", len(REGISTRY), "OVER", len(bad), flush=True)
