"""Draws the HUD's action icons in a chunky Roblox style: thick dark outline, flat base colour, one
shadow tone on the lower right, one soft highlight. Shapes are simple and drawn, not generated, so the
set is consistent and reproducible. Colours follow the user's reference images (2026-11-08); the
mouse keeps the HUD's own colours.

    python draw_icons.py            -> ../../assets/icons/*.png (256 px) and icons_sheet.png
"""
import math
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024  # drawing size; saved at OUT
OUT = 256
OUTLINE = (20, 24, 42, 255)
HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons"))


def blank(mode="L"):
    return Image.new(mode, (S, S), 0)


def shape(fn):
    m = blank()
    fn(ImageDraw.Draw(m))
    return m


def shifted(mask, dx, dy):
    return ImageChops.offset(mask, dx, dy)


def dilate(mask, r):
    # MaxFilter needs an odd size; grow in steps for big radii
    out = mask
    while r > 0:
        step = min(r, 12)
        out = out.filter(ImageFilter.MaxFilter(step * 2 + 1))
        r -= step
    return out


def paint(img, mask, colour):
    layer = Image.new("RGBA", (S, S), colour)
    img.paste(layer, (0, 0), mask)


def part(img, mask, base, shade, light=None, shade_shift=(-34, -34), light_box=None):
    """A filled part: base colour, a shadow crescent on the lower right, an optional highlight."""
    paint(img, mask, base)
    inner = ImageChops.multiply(mask, shifted(mask, *shade_shift))
    crescent = ImageChops.subtract(mask, inner)
    paint(img, crescent, shade)
    if light and light_box:
        x0, y0, x1, y1 = light_box
        box = (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))
        hl = shape(lambda d: d.ellipse(box, fill=255))
        paint(img, ImageChops.multiply(hl, mask), light)


def finish(img, silhouette, name, width=34):
    """Puts the thick outline under everything and saves at OUT px."""
    ring = dilate(silhouette, width)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    paint(out, ring, OUTLINE)
    out.alpha_composite(img)
    out = out.resize((OUT, OUT), Image.LANCZOS)
    out.save(os.path.join(DEST, f"{name}.png"))
    return out


def line(img, points, width, colour=OUTLINE):
    d = ImageDraw.Draw(img)
    d.line(points, fill=colour, width=width, joint="curve")
    for x, y in (points[0], points[-1]):
        d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=colour)


# --- Punch: a fist side-on, punching right: knuckles forward, thumb wrapped across, wrist and
# speed lines trailing left, impact marks at the knuckles. Side-on so it reads as a punch, not a hand.
def fist():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base, shade, light = (255, 196, 61, 255), (226, 138, 34, 255), (255, 233, 150, 255)
    cuff, cuff_shade = (232, 72, 60, 255), (178, 40, 40, 255)
    streak = (255, 244, 214, 255)
    # speed lines behind the fist, tapering to the left
    lines = shape(lambda d: [d.polygon([(40, y), (300, y - t / 2), (300, y + t / 2)], fill=255)
                             for y, t in ((330, 56), (520, 74), (710, 56))])
    wrist = shape(lambda d: d.rounded_rectangle((230, 400, 420, 650), 60, fill=255))
    band = shape(lambda d: d.rounded_rectangle((300, 370, 430, 680), 50, fill=255))
    hand = shape(lambda d: d.rounded_rectangle((380, 270, 760, 780), 140, fill=255))
    fingers = [shape(lambda d, y=y: d.rounded_rectangle((600, y, 880, y + 128), 62, fill=255))
               for y in (270, 398, 526, 654)]
    thumb = shape(lambda d: d.rounded_rectangle((430, 500, 790, 640), 70, fill=255))
    impact = shape(lambda d: [d.polygon(p, fill=255) for p in (
        [(905, 330), (990, 250), (1000, 290), (930, 360)],
        [(925, 505), (1015, 485), (1015, 555), (925, 540)],
        [(905, 710), (930, 680), (1000, 750), (990, 790)])])
    silhouette = lines
    for m in [wrist, band, hand, *fingers, thumb, impact]:
        silhouette = ImageChops.lighter(silhouette, m)
    paint(img, lines, streak)
    paint(img, impact, streak)
    part(img, wrist, shade, (196, 112, 24, 255))
    part(img, band, cuff, cuff_shade, (255, 140, 120, 255), light_box=(320, 400, 380, 520))
    part(img, hand, base, shade, light, light_box=(440, 300, 600, 400))
    for m in fingers:
        part(img, m, base, shade, light, shade_shift=(-28, -28), light_box=None)
    knuckles = shape(lambda d: d.rounded_rectangle((800, 290, 860, 760), 30, fill=255))
    finger_union = fingers[0]
    for m in fingers[1:]:
        finger_union = ImageChops.lighter(finger_union, m)
    paint(img, ImageChops.multiply(knuckles, finger_union), light)
    # finger creases, then the thumb over them
    for y in (398, 526, 654):
        line(img, [(640, y), (850, y)], 18)
    part(img, thumb, base, shade, light, shade_shift=(-26, -26), light_box=(480, 515, 660, 560))
    outline_thumb = ImageChops.subtract(dilate(thumb, 14), thumb)
    paint(img, outline_thumb, OUTLINE)
    return finish(img, silhouette, "punch")


# --- Propel: a dash-smoke trail: puffs sitting on the ground, biggest at the front (right) where the
# runner just left, shrinking to wisps behind, with speed lines over it.
def puff():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base, shade, light = (220, 233, 248, 255), (150, 178, 214, 255), (255, 255, 255, 255)
    ground = 800
    blobs = []
    for cx, r in ((210, 70), (340, 105), (510, 145), (720, 185)):
        blobs.append((cx - r, ground - 2 * r + 20, cx + r, ground + 20))
    masks = [shape(lambda d, b=b: d.ellipse(b, fill=255)) for b in blobs]
    # a flat, swept base joining the puffs, tapering to a wisp at the back
    floor = shape(lambda d: d.polygon([(70, ground - 10), (720, ground - 120), (900, ground - 60),
                                       (880, ground + 20), (120, ground + 20)], fill=255))
    cut = shape(lambda d: d.rectangle((0, ground + 20, S, S), fill=255))
    speed = shape(lambda d: [d.polygon([(x0, y), (x1, y - t / 2), (x1 + 40, y), (x1, y + t / 2)], fill=255)
                             for x0, x1, y, t in ((120, 560, 250, 58), (300, 860, 380, 70), (60, 420, 470, 50))])
    smoke = floor
    for m in masks:
        smoke = ImageChops.lighter(smoke, m)
    smoke = ImageChops.subtract(smoke, cut)
    silhouette = ImageChops.lighter(smoke, speed)
    paint(img, speed, shade)
    part(img, smoke, base, shade, shade_shift=(-40, -40))
    for i, b in enumerate(blobs):
        r = (b[2] - b[0]) / 2
        hl = shape(lambda d, b=b, r=r: d.ellipse((b[0] + r * 0.45, b[1] + r * 0.35,
                                                   b[0] + r * 1.05, b[1] + r * 0.8), fill=255))
        paint(img, ImageChops.multiply(hl, smoke), light)
    # puff edges where they overlap, so it reads as rolling smoke
    d = ImageDraw.Draw(img)
    for b in blobs[1:]:
        d.arc(b, 150, 230, fill=OUTLINE, width=18)
    return finish(img, silhouette, "propel")


# --- Air Kick: a boot kicking up and right, blue cuff, navy body, orange tread sole ---------------
def boot():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    navy, navy_shade, navy_light = (46, 52, 104, 255), (28, 32, 70, 255), (92, 104, 170, 255)
    blue, blue_shade = (70, 122, 222, 255), (44, 84, 168, 255)
    sole, sole_shade = (246, 166, 44, 255), (200, 116, 20, 255)
    angle = -22

    def rot(points):
        cx, cy = 512, 540
        a = math.radians(angle)
        return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a),
                 cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in points]

    shaft = shape(lambda d: d.polygon(rot([(260, 300), (500, 300), (520, 600), (270, 640)]), fill=255))
    foot = shape(lambda d: d.polygon(rot([(270, 560), (700, 520), (840, 560), (880, 640), (860, 700), (280, 720)]), fill=255))
    (ax, ay), (bx, by) = rot([(700, 505), (880, 700)])
    toe = shape(lambda d: d.ellipse((min(ax, bx) - 10, min(ay, by) - 10, max(ax, bx) + 10, max(ay, by) + 10), fill=255))
    body = ImageChops.lighter(ImageChops.lighter(shaft, foot), toe)
    cuff = shape(lambda d: d.polygon(rot([(220, 210), (540, 210), (550, 360), (230, 380)]), fill=255))
    sole_mask = shape(lambda d: d.polygon(rot([(260, 700), (880, 680), (870, 770), (270, 790)]), fill=255))
    silhouette = ImageChops.lighter(ImageChops.lighter(body, cuff), sole_mask)
    part(img, body, navy, navy_shade, navy_light, light_box=tuple(
        v for p in rot([(560, 520), (760, 580)]) for v in p))
    part(img, cuff, blue, blue_shade, (130, 176, 250, 255),
         light_box=tuple(v for p in rot([(260, 225), (520, 260)]) for v in p))
    part(img, sole_mask, sole, sole_shade, (255, 206, 110, 255), shade_shift=(0, -30))
    # tread notches along the sole's bottom
    for x in (380, 500, 620, 740):
        notch = shape(lambda d, x=x: d.polygon(rot([(x, 760), (x + 50, 760), (x + 50, 800), (x, 800)]), fill=255))
        paint(img, ImageChops.multiply(notch, sole_mask), OUTLINE)
    # the line between body and sole, and two laces
    line(img, rot([(270, 705), (870, 685)]), 20)
    for y in (400, 480):
        p = rot([(330, y), (470, y - 20)])
        line(img, p, 34, (237, 227, 194, 255))
    # a toe sparkle
    d = ImageDraw.Draw(img)
    sx, sy = rot([(780, 580)])[0]
    d.polygon([(sx, sy - 40), (sx + 10, sy - 10), (sx + 40, sy), (sx + 10, sy + 10),
               (sx, sy + 40), (sx - 10, sy + 10), (sx - 40, sy), (sx - 10, sy - 10)],
              fill=(255, 255, 255, 255))
    out = finish(img, silhouette, "kick_body")
    # yellow motion slashes behind, outlined too, then save the final icon
    full = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    slashes = shape(lambda d: [d.polygon([(90, 860), (300, 700), (250, 760)], fill=255),
                               d.polygon([(150, 940), (380, 800), (330, 860)], fill=255)])
    paint(full, dilate(slashes, 22), OUTLINE)
    paint(full, slashes, (255, 204, 40, 255))
    big = out.resize((S, S), Image.LANCZOS)
    full.alpha_composite(big)
    full = full.resize((OUT, OUT), Image.LANCZOS)
    full.save(os.path.join(DEST, "kick.png"))
    os.remove(os.path.join(DEST, "kick_body.png"))
    return full


# --- M1: a mouse, the reference's structure (no cable), in the HUD's colours ---------------------
def mouse():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    text, panel, accent = (242, 239, 230, 255), (34, 45, 60, 255), (255, 196, 61, 255)
    d = ImageDraw.Draw(img)
    box = (300, 150, 724, 874)
    d.rounded_rectangle(box, 212, fill=text)  # the outline ring
    inner = (box[0] + 46, box[1] + 46, box[2] - 46, box[3] - 46)
    d.rounded_rectangle(inner, 166, fill=panel)
    # left button lit, clipped to the inner shape
    inner_mask = shape(lambda dd: dd.rounded_rectangle(inner, 166, fill=255))
    left = shape(lambda dd: dd.rectangle((inner[0], inner[1], 512, 470), fill=255))
    paint(img, ImageChops.multiply(inner_mask, left), accent)
    # the split lines
    d.rectangle((489, inner[1], 535, 470), fill=text)
    d.rectangle((inner[0], 450, inner[2], 494), fill=text)
    silhouette = shape(lambda dd: dd.rounded_rectangle(box, 212, fill=255))
    return finish(img, silhouette, "mouse", width=18)


if __name__ == "__main__":
    os.makedirs(DEST, exist_ok=True)
    icons = [fist(), puff(), boot(), mouse()]
    sheet = Image.new("RGBA", (OUT * 4 + 50, OUT + 20), (16, 23, 33, 255))
    for i, icon in enumerate(icons):
        sheet.alpha_composite(icon, (10 + i * (OUT + 10), 10))
    small = Image.new("RGBA", (4 * 34 + 10, 34), (16, 23, 33, 255))
    for i, icon in enumerate(icons):
        small.alpha_composite(icon.resize((24, 24), Image.LANCZOS), (5 + i * 34, 5))
    sheet.save(os.path.join(HERE, "icons_sheet.png"))
    small.resize((small.width * 3, small.height * 3), Image.NEAREST).save(os.path.join(HERE, "icons_small.png"))
    print("wrote", DEST)
