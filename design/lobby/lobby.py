"""The open-air lobby's visible model, built by script in Blender 5.2 with the arenas' painting kit.

Run: blender -b --factory-startup -P lobby.py -- <out folder> [--no-render] [--reuse-textures]

One level platform, 180 x 240 studs, top at height 0, centred on its own origin. Blender +Y points at
the arena (in Roblox that's -Z), so going down the Y axis: the viewing edge (y = +120), the main
lobby, then the walk-in training area (the last 80 studs, y < -40). The strip kept for gamepass
displays runs down the +X side of the main lobby. Numbers match GameConfig.Lobby; change both together.

Kept simpler than the arenas, with three handcrafted materials: pale limestone paving for the lobby,
a flush sea-green canvas mat with a stitched cream border for training, and a honey timber inlay for
the gamepass strip. A painted yellow line runs along the viewing edge, because there's no wall or
railing to show where the floor stops. No labels, arrows or boundary lines: those are only in the plan.

Nothing here collides in Roblox: LobbyService's own floor and invisible walls do that.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import common as C  # noqa: E402
import paint as P  # noqa: E402
import surfaces as S  # noqa: E402

WIDTH, DEPTH = 180.0, 240.0
TRAINING_DEPTH = 80.0
STRIP_WIDTH = 28.0
THICK = 3.0
TILE, PX = 60.0, 1024
HX, HY = WIDTH / 2, DEPTH / 2
TRAIN_Y = -HY + TRAINING_DEPTH  # y below this is training
ARENA_GAP = 170.0 - 0.0  # the viewing edge's distance from the arena's centre (Lobby.ViewEdgeZ)
RISE = 1.0  # the lobby floor above the arena's (Lobby.FloorY - Arena.CenterY)
SUN = (215, 42)

COL = {
    "stone": P.rgb(226, 214, 190),
    "stone_warm": P.rgb(232, 212, 178),
    "stone_cool": P.rgb(214, 212, 200),
    "joint": P.rgb(168, 156, 136),
    "coping": P.rgb(196, 182, 156),
    "mat": P.rgb(84, 156, 142),
    "mat_dark": P.rgb(64, 132, 122),
    "stitch": P.rgb(240, 228, 196),
    "timber": P.rgb(190, 138, 84),
    "timber_dark": P.rgb(150, 104, 62),
    "line": P.rgb(255, 196, 61),
}


def floor_painter(X, Y):
    """Limestone paving in a staggered bond; the canvas training mat; the timber strip; the edge line."""
    # --- paving: 10 x 6 slabs, every other course shifted, each its own tone
    course = np.floor((Y + HY) / 6.0)
    along = (X + HX + 5.0 * (course % 2)) / 10.0
    slab = np.floor(along)
    fx = (along - slab) * 10.0
    fy = (Y + HY) - course * 6.0
    edge = np.minimum(np.minimum(fx, 10.0 - fx), np.minimum(fy, 6.0 - fy))
    h = [P.hash01(800 + k, slab, course) for k in range(3)]
    tone = np.where((h[0] < 0.3)[..., None], COL["stone_warm"], np.where((h[0] < 0.55)[..., None], COL["stone_cool"], COL["stone"]))
    col = tone * (0.95 + 0.08 * h[1])[..., None]
    col = col * (0.97 + 0.05 * P.fbm2(X * 0.35, Y * 0.35, 801, 3))[..., None]
    pits = P.smoothstep(0.82, 0.88, P.vnoise2(X * 3.0, Y * 3.0, 802))
    col = col * (1 - 0.1 * pits)[..., None]
    joint = edge < 0.12
    col = np.where(joint[..., None], COL["joint"], col)
    height = np.where(joint, -0.04, 0.03 * P.smoothstep(0.1, 0.5, edge) - 0.01 * pits)
    rough = np.where(joint, 0.95, 0.82)

    # --- the gamepass strip: honey boards running toward the arena, framed by a darker board
    sx0, sx1 = HX - STRIP_WIDTH + 1.0, HX - 3.0
    sy0, sy1 = TRAIN_Y + 4.0, HY - 6.0
    in_strip = (X > sx0) & (X < sx1) & (Y > sy0) & (Y < sy1)
    board = np.floor((X - sx0) / 4.0)
    bx = (X - sx0) - board * 4.0
    bh = P.hash01(810, board)
    grain = P.fbm2(X * 2.4 + bh * 30, Y * 0.06, 811, 3)
    wood = P.mix(COL["timber_dark"], COL["timber"], 0.45 + 0.55 * bh)[..., :] * (0.9 + 0.18 * grain)[..., None]
    frame = (X < sx0 + 1.2) | (X > sx1 - 1.2) | (Y < sy0 + 1.2) | (Y > sy1 - 1.2)
    wood = np.where(frame[..., None], COL["timber_dark"] * (0.92 + 0.14 * grain)[..., None], wood)
    gap = (np.minimum(bx, 4.0 - bx) < 0.07) & ~frame
    wood = np.where(gap[..., None], COL["timber_dark"] * 0.6, wood)
    col = np.where(in_strip[..., None], wood, col)
    height = np.where(in_strip, np.where(gap, -0.03, 0.02), height)
    rough = np.where(in_strip, 0.7, rough)

    # --- the training mat: woven canvas, flush, with a stitched border
    mx0, mx1, my0, my1 = -HX + 3.0, HX - 3.0, -HY + 3.0, TRAIN_Y
    in_mat = (X > mx0) & (X < mx1) & (Y > my0) & (Y < my1)
    inset = np.minimum(np.minimum(X - mx0, mx1 - X), np.minimum(Y - my0, my1 - Y))
    weave = 0.5 + 0.5 * np.sin(X * math.pi * 2.0) * np.sin(Y * math.pi * 2.0)
    panel = P.hash01(820, np.floor((X - mx0) / 29.0), np.floor((Y - my0) / 25.6))
    mat = P.mix(COL["mat_dark"], COL["mat"], 0.55 + 0.45 * panel)[..., :] * (0.95 + 0.07 * weave)[..., None]
    mat = mat * (0.97 + 0.05 * P.fbm2(X * 0.12, Y * 0.12, 821, 2))[..., None]
    seam = (np.abs(((X - mx0) / 29.0) % 1.0 - 0.5) > 0.495) | (np.abs(((Y - my0) / 25.6) % 1.0 - 0.5) > 0.494)
    mat = np.where(seam[..., None], COL["mat_dark"] * 0.82, mat)
    border = inset < 2.2
    mat = np.where(border[..., None], COL["mat_dark"] * 0.9, mat)
    dash = (np.abs(inset - 1.1) < 0.16) & (((X + Y) % 1.6) < 1.0)
    mat = np.where(dash[..., None], COL["stitch"], mat)
    col = np.where(in_mat[..., None], mat, col)
    height = np.where(in_mat, 0.012 * weave + np.where(dash, 0.02, 0.0), height)
    rough = np.where(in_mat, 0.92, rough)

    # --- coping round the whole platform, and the painted line on the viewing edge
    rim = np.minimum(np.minimum(X + HX, HX - X), np.minimum(Y + HY, HY - Y))
    coping = rim < 2.4
    cs = np.where(np.minimum(X + HX, HX - X) < np.minimum(Y + HY, HY - Y), Y, X)
    cjoint = np.abs((cs / 8.0) % 1.0 - 0.5) > 0.492
    stone = COL["coping"] * (0.95 + 0.08 * P.fbm2(X * 0.5, Y * 0.5, 830, 2))[..., None]
    stone = np.where((cjoint | (np.abs(rim - 2.4) < 0.1))[..., None], COL["joint"], stone)
    col = np.where(coping[..., None], stone, col)
    height = np.where(coping, 0.03, height)
    rough = np.where(coping, 0.85, rough)
    line = (Y > HY - 1.9) & (Y < HY - 0.35)
    worn = P.smoothstep(0.68, 0.74, P.fbm2(X * 0.9, Y * 2.0, 831, 3))
    col = np.where(line[..., None], P.mix(P.fill(X.shape, COL["line"]), stone, 0.6 * worn), col)
    rough = np.where(line, 0.6, rough)
    return col, height, rough


def build_floor(tex):
    objs = []
    nx, ny = int(WIDTH // TILE), int(DEPTH // TILE)
    step = TILE / PX
    for j in range(ny):
        for i in range(nx):
            x0, y0 = -HX + i * TILE, -HY + j * TILE
            name = f"Lobby_Floor_{j}{i}"
            bm = bmesh.new()
            uv = bm.loops.layers.uv.new("UVMap")
            C.box(bm, (x0 + TILE / 2, y0 + TILE / 2, -THICK / 2), (TILE, TILE, THICK))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            for f in bm.faces:
                for loop in f.loops:
                    co = loop.vert.co
                    loop[uv].uv = ((co.x - x0) / TILE, (co.y - y0) / TILE)
            maps = S._cached(tex, name)
            if maps is None:
                xs = x0 + (np.arange(-1, PX + 1) + 0.5) * step
                ys = y0 + (np.arange(-1, PX + 1) + 0.5) * step
                X, Y = np.meshgrid(xs, ys)
                colour, height, rough = floor_painter(X, Y)
                maps = P.save_maps(tex, name, colour, height, rough, px_per_stud=PX / TILE, crop=1)
            objs.append(C.mesh_object(name, bm, S.image_material(name, maps)))
            print("PAINTED", name, flush=True)
    return objs


def build_underside():
    """A plain stepped stone base, tapering in, so the platform has weight from the arena's side."""
    bm = bmesh.new()
    for k, (inset, top, depth) in enumerate(((2.0, -THICK, 5.0), (10.0, -THICK - 5.0, 7.0), (24.0, -THICK - 12.0, 9.0))):
        C.box(bm, (0, 0, top - depth / 2), (WIDTH - 2 * inset, DEPTH - 2 * inset, depth))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    stone = tuple(float(v) for v in COL["coping"] * 0.86)
    C.mesh_object("Lobby_Base", bm, C.flat_material("Lobby_BaseStone", stone))
    beams = bmesh.new()
    y = -HY + 15.0
    while y < HY:
        C.box(beams, (0, y, -THICK - 2.6), (WIDTH - 1.0, 3.2, 3.2))
        y += 30.0
    bmesh.ops.recalc_face_normals(beams, faces=beams.faces[:])
    timber = tuple(float(v) for v in COL["timber_dark"])
    C.mesh_object("Lobby_Beams", beams, C.flat_material("Lobby_BeamTimber", timber))


def stand_ins():
    """Not exported: the arena where it really is, and a spectator's eye, to check the sightline."""
    bm = bmesh.new()
    C.oval_prism(bm, C.A, C.B, -RISE, -RISE - 4)
    arena = C.mesh_object("StandIn_Arena", bm, C.flat_material("StandIn_Arena", (0.35, 0.6, 0.3)), col="Setup")
    arena.location = (0, HY + ARENA_GAP, 0)
    for k, x in enumerate((-40, 0, 45)):
        bm = bmesh.new()
        C.box(bm, (x, HY + ARENA_GAP - C.B + 30 + k * 25, -RISE + 2.5), (2, 1, 5))
        C.mesh_object(f"StandIn_Fighter{k}", bm, C.flat_material(f"StandIn_F{k}", (0.9, 0.3, 0.2)), col="Setup")


def cameras():
    spawn_y = HY - (312.0 - 170.0)  # Lobby.SpawnZ back from the viewing edge
    return {
        "Top": C.camera("Top", (0, 0, 330), (0, 0.01, 0), 28),
        "Overview": C.camera("Overview", (230, -260, 150), (0, 40, 0), 30),
        "Spawn": C.camera("Spawn", (0, spawn_y - 10, 8.5), (0, HY + ARENA_GAP, -RISE), 30),
        "EdgeLeft": C.camera("EdgeLeft", (-HX + 6, HY - 10, 8.5), (0, HY + ARENA_GAP, -RISE), 30),
        "EdgeRight": C.camera("EdgeRight", (HX - 6, HY - 10, 8.5), (0, HY + ARENA_GAP, -RISE), 30),
        "Training": C.camera("Training", (-60, TRAIN_Y + 34, 12), (10, -HY + 30, 0), 26),
        "Strip": C.camera("Strip", (20, 60, 12), (HX - 14, 20, 0), 26),
    }


def build(out):
    C.reset()
    C.sky_and_sun(*SUN)
    build_floor(os.path.join(out, "textures"))
    build_underside()
    stand_ins()
    C.cloud_layer("Clouds", -120, 260, 900, 8, (30, 60), __import__("random").Random(5), col="Setup", keep_clear=(260, 300))
    return cameras()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = os.path.abspath(args[0] if args and not args[0].startswith("--") else os.path.join(HERE, "out"))
    cams = build(out)
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", S.top_is_flat(("Lobby_Floor_",)))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "lobby.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "lobby", cams):
            print("RENDER", p)
