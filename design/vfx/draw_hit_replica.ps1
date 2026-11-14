# Textures for the replica of the first punch hit in Venomec's "Mumen Rider Combo" (YouTube 3R5WsLDp2f4,
# 2.28 s to 2.65 s). All white on transparent: the alpha is the brightness, the game tints them.
#   hit_needle.png  one tapered spike, tip to the right (spikes, beam lines, sparks, black speed lines)
#   hit_dome.png    the soft shock bubble: a bright rim, a faint streaked inside
#   hit_floor.png   the floor shock ring: two thin rings and a band of short radial dashes
#   hit_arc.png     one thin arc of a circle, tapered at both ends
#   hit_crown.png   the floor crown of a step or landing: thin rings and spikes pointing outward
#   hit_circle.png  a circle outline with a thinner one inside (the heavy hit's ring)
#   hit_ribbon.png  the ribbon a swing leaves (a Trail texture): a bright tip edge and thinning streaks
#   hit_star.png    a four-point glint
#   hit_blade.png   one blade of the star in its own colours (white-hot middle, neon green, deep green edge),
#                   standing on the image's centre, for camera-facing particles turned by Rotation
#   hit_dust.png    the dust a hit blasts out along the floor: soft streaks fanning from an empty middle
#   hit_wisp.png    a FLIPBOOK, 4 x 4: thin flame-like tongues rising and fraying
#   hit_smoke.png   a FLIPBOOK, 1024 x 1024, 4 x 4 frames: one puff billowing out and fraying into wisps
#                   (ParticleEmitter.FlipbookLayout Grid4x4, FlipbookMode OneShot)
# Run: powershell -ExecutionPolicy Bypass -File design/vfx/draw_hit_replica.ps1
# Writes design/vfx/out/hit_*.png and hit_preview.png (all four on a mid-tone background).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class HitTex {
    static double Sat(double x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }
    static double Smooth(double a, double b, double x) { double t = Sat((x - a) / (b - a)); return t * t * (3 - 2 * t); }
    static double Hash(int n) { double s = Math.Sin(n * 12.9898 + 4.1414) * 43758.5453; return s - Math.Floor(s); }

    public delegate double Shade(double u, double v); // u, v in -1..1, v down

    public static void Save(string path, int size, Shade shade) {
        using (Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb)) {
            BitmapData data = bmp.LockBits(new Rectangle(0, 0, size, size), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] px = new byte[size * size * 4];
            for (int y = 0; y < size; y++) {
                for (int x = 0; x < size; x++) {
                    double u = (x + 0.5) / size * 2 - 1, v = (y + 0.5) / size * 2 - 1;
                    int i = (y * size + x) * 4;
                    px[i] = 255; px[i + 1] = 255; px[i + 2] = 255;
                    px[i + 3] = (byte)Math.Round(Sat(shade(u, v)) * 255);
                }
            }
            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    // A spike lying along the image's width, flying to the right (a VelocityParallel particle's width
    // runs along the way it flies): a rounded base at the left, then straight sides down to a true
    // point at the right. Hard-edged, with only a thin halo that stops short of the tip, so the point
    // stays sharp at any size.
    public static double Needle(double u, double v) {
        double t = (u + 0.97) / 1.94;                      // 0 at the base, 1 at the tip
        if (t <= 0 || t >= 1) return 0;
        double w = 0.12 * (t < 0.1 ? Math.Sqrt(t / 0.1) : (1 - t) / 0.9);
        double d = Math.Abs(v);
        double core = Sat((w - d) / 0.006) * (0.72 + 0.28 * Sat(1 - d / Math.Max(w, 0.001)));
        double halo = 0.22 * Math.Exp(-Math.Pow(Math.Max(d - w, 0) / 0.03, 2)) * Smooth(0.0, 0.08, t) * Smooth(0.8, 0.5, t);
        return Math.Max(core, halo);
    }
    // The shock bubble: a soft rim, a faint inside smeared outward in streaks.
    public static double Dome(double u, double v) {
        double r = Math.Sqrt(u * u + v * v), a = Math.Atan2(v, u);
        double streak = 0.55 + 0.25 * Math.Sin(a * 7 + 1.3) + 0.2 * Math.Sin(a * 17 + 4.1) + 0.12 * Math.Sin(a * 31 + 0.4);
        double rim = 0.75 * Math.Exp(-Math.Pow((r - 0.76) / 0.085, 2)) * (0.75 + 0.25 * streak);
        double inside = 0.22 * Smooth(0.15, 0.7, r) * Smooth(0.86, 0.7, r) * streak;
        return (rim + inside) * Smooth(0.99, 0.86, r);
    }

    // The floor ring: two thin rings, then a band of short radial dashes of uneven length.
    public static double Floor(double u, double v) {
        double r = Math.Sqrt(u * u + v * v), a = Math.Atan2(v, u);
        double rings = 0.9 * Math.Exp(-Math.Pow((r - 0.44) / 0.011, 2)) + 0.6 * Math.Exp(-Math.Pow((r - 0.56) / 0.008, 2));
        int count = 64;
        double f = (a + Math.PI) / (2 * Math.PI) * count;
        int k = (int)Math.Floor(f) % count;
        double across = Math.Abs(f - Math.Floor(f) - 0.5) * 2;   // 0 on the dash's middle line, 1 between dashes
        double dash = 0;
        if (Hash(k) > 0.22) {
            double from = 0.62 + 0.10 * Hash(k + 100), to = 0.82 + 0.15 * Hash(k + 200);
            double half = 0.30 + 0.25 * Hash(k + 300);
            double along = Smooth(from, from + 0.04, r) * Smooth(to, to - 0.07, r);
            dash = along * Smooth(half, half * 0.35, across) * (0.45 + 0.55 * Hash(k + 400));
        }
        return Math.Max(rings, dash) * Smooth(0.995, 0.95, r);
    }

    // One thin arc, 150 degrees of a circle, thickest in the middle.
    public static double Arc(double u, double v) {
        double r = Math.Sqrt(u * u + v * v), a = Math.Atan2(-v, u);   // 0 = right, counter-clockwise
        double span = 75 * Math.PI / 180, mid = Math.PI / 2;
        double off = Math.Abs(a - mid);
        if (off >= span) return 0;
        double taper = Math.Pow(1 - off / span, 0.8);
        double w = 0.016 * taper + 0.002;
        double d = Math.Abs(r - 0.9);
        double core = Math.Pow(Sat(1 - d / w), 0.8);
        double glow = 0.3 * Math.Exp(-Math.Pow(d / (w * 2.5 + 0.01), 2)) * taper;
        return Math.Max(core, glow);
    }

    // The floor crown of a step or landing: two thin rings, a soft band, and spikes pointing outward.
    public static double Crown(double u, double v) {
        double r = Math.Sqrt(u * u + v * v), a = Math.Atan2(v, u);
        double rings = 0.8 * Math.Exp(-Math.Pow((r - 0.26) / 0.010, 2)) + 0.55 * Math.Exp(-Math.Pow((r - 0.35) / 0.008, 2));
        double band = 0.4 * Math.Exp(-Math.Pow((r - 0.5) / 0.12, 2));
        int count = 34;
        double f = (a + Math.PI) / (2 * Math.PI) * count;
        int k = (int)Math.Floor(f) % count;
        double across = Math.Abs(f - Math.Floor(f) - 0.5) * 2;
        double tip = 0.62 + 0.36 * Hash(k + 700), from = 0.42;
        double spike = 0;
        if (r > from - 0.04 && r < tip) {
            double along = (r - from) / (tip - from);             // 0 at the base, 1 at the tip
            double half = 0.85 * (1 - Sat(along));                // narrows to nothing at the tip
            spike = 0.8 * Smooth(half, 0, across) * Math.Pow(1 - Sat(along), 0.6) * Smooth(from - 0.04, from + 0.04, r) * (0.5 + 0.5 * Hash(k + 800));
        }
        return Math.Max(Math.Max(rings, band), spike) * Smooth(0.995, 0.95, r);
    }

    // A circle outline with a thinner one inside it.
    public static double Circle(double u, double v) {
        double r = Math.Sqrt(u * u + v * v);
        double outer = Math.Max(Math.Pow(Sat(1 - Math.Abs(r - 0.86) / 0.022), 0.8), 0.3 * Math.Exp(-Math.Pow((r - 0.86) / 0.06, 2)));
        double inner = 0.7 * Math.Exp(-Math.Pow((r - 0.70) / 0.008, 2));
        return Math.Max(outer, inner);
    }

    // ---- The smoke flipbook: 16 frames (4 x 4) of one puff that billows out and frays into wisps. ----
    static double H3(int x, int y, int z) {
        unchecked {
            uint h = (uint)(x * 374761393 + y * 668265263 + z * 1274126177);
            h = (h ^ (h >> 13)) * 1274126177u;
            h ^= h >> 16;
            return (h & 0xFFFFFF) / 16777215.0;
        }
    }
    static double Noise3(double x, double y, double z) {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y), zi = (int)Math.Floor(z);
        double fx = x - xi, fy = y - yi, fz = z - zi;
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy); fz = fz * fz * (3 - 2 * fz);
        double a = H3(xi, yi, zi) + (H3(xi + 1, yi, zi) - H3(xi, yi, zi)) * fx;
        double b = H3(xi, yi + 1, zi) + (H3(xi + 1, yi + 1, zi) - H3(xi, yi + 1, zi)) * fx;
        double c = H3(xi, yi, zi + 1) + (H3(xi + 1, yi, zi + 1) - H3(xi, yi, zi + 1)) * fx;
        double d = H3(xi, yi + 1, zi + 1) + (H3(xi + 1, yi + 1, zi + 1) - H3(xi, yi + 1, zi + 1)) * fx;
        double ab = a + (b - a) * fy, cd = c + (d - c) * fy;
        return ab + (cd - ab) * fz;
    }
    static double Fbm(double x, double y, double z) {
        double sum = 0, amp = 0.5, total = 0;
        for (int o = 0; o < 4; o++) { sum += amp * Noise3(x, y, z); total += amp; x *= 2.03; y *= 2.03; z *= 2.03; amp *= 0.5; }
        return sum / total;
    }
    public static double Smoke(double u, double v) {
        // Which of the 16 cells, and where in it (-1..1).
        double gx = (u + 1) * 2, gy = (v + 1) * 2;
        int cx = Math.Min(3, (int)gx), cy = Math.Min(3, (int)gy);
        double lu = (gx - cx) * 2 - 1, lv = (gy - cy) * 2 - 1;
        double t = (cy * 4 + cx) / 15.0;
        double r = Math.Sqrt(lu * lu + lv * lv);
        // The shape is pushed about by a slower noise, so its edge curls instead of staying round.
        double wx = Fbm(lu * 1.3 + 3.1, lv * 1.3 + 7.7, t * 0.9) - 0.5;
        double wy = Fbm(lu * 1.3 + 11.4, lv * 1.3 + 1.9, t * 0.9 + 4.0) - 0.5;
        double px = lu + wx * (0.5 + 0.5 * t), py = lv + wy * (0.5 + 0.5 * t);
        double n = Fbm(px * 2.4, py * 2.4 - t * 0.8, t * 1.2 + 9.0);
        double ridge = 1 - Math.Abs(2 * Fbm(px * 4.6 + 2.0, py * 4.6 - t * 1.1, t * 1.5 + 3.0) - 1);   // thin filaments
        n = 0.62 * n + 0.38 * ridge * (0.4 + 0.6 * t);
        double reach = 0.66 + 0.22 * t;                                  // it swells
        double body = Smooth(reach, reach * 0.3, Math.Sqrt(px * px + py * py));
        double worn = 0.16 + 0.40 * t;                                   // and is eaten away into wisps
        double dense = Sat((n + body * 0.42 * (1 - t) - worn) / 0.16);
        double fadeOut = 1 - 0.6 * t * t;
        return dense * body * fadeOut * Smooth(0.9, 0.7, r);             // clear border round each cell
    }

    // The ribbon a swing leaves (for a Trail, stretched along it): u runs along the swing, v across it.
    // A bright edge at the top (the tip of the fist or foot), then streaks thinning out toward the body.
    public static double Ribbon(double u, double v) {
        double across = (v + 1) / 2;                                       // 0 at the tip edge, 1 at the body edge
        double edge = Math.Exp(-Math.Pow(across / 0.05, 2));
        double body = 0.5 * Math.Pow(1 - across, 1.4);
        double streak = 1 - Math.Abs(2 * Fbm(u * 0.8 + 4.0, across * 26.0, 1.7) - 1);   // long thin lines along u
        streak = Math.Pow(streak, 2.2);
        double fine = Fbm(u * 2.0 + 9.0, across * 60.0, 5.3);
        double a = edge + body * (0.25 + 0.95 * streak) * (0.7 + 0.6 * fine);
        return a * Smooth(1.0, 0.9, across);
    }

    // A four-point glint: long thin arms up, down, left and right, and a soft round middle.
    public static double Star(double u, double v) {
        double au = Math.Abs(u), av = Math.Abs(v);
        double arms = Sat(1 - (Math.Sqrt(au) + Math.Sqrt(av)) / 0.98);
        double core = Math.Pow(arms, 0.9) * 2.2;
        double r = Math.Sqrt(u * u + v * v);
        double glow = 0.35 * Math.Exp(-Math.Pow(r / 0.22, 2));
        return Math.Max(core, glow) * Smooth(0.98, 0.8, Math.Max(au, av));
    }

    // The dust a hit blasts out along the floor: soft streaks fanning out from an empty middle, of
    // uneven reach, brightest just outside the middle. Blurred on purpose: dust, not drawn lines.
    public static double Dust(double u, double v) {
        double r = Math.Sqrt(u * u + v * v), a = Math.Atan2(v, u);
        double cx = Math.Cos(a), sy = Math.Sin(a);
        double n1 = Fbm(cx * 1.6 + 5.0, sy * 1.6 + 5.0, 1.3);
        double n2 = Fbm(cx * 5.0 + 9.0, sy * 5.0 + 9.0, 4.1);
        double n3 = Fbm(cx * 13.0 + 2.0, sy * 13.0 + 2.0, 7.7);
        double streak = Sat((0.45 * n1 + 0.33 * n2 + 0.22 * n3 - 0.36) / 0.26);
        double reach = 0.62 + 0.36 * n1;
        double radial = Smooth(0.16, 0.34, r) * Math.Pow(1 - Smooth(0.4, reach, r), 1.3);
        double grain = 0.75 + 0.5 * Fbm(u * 9.0, v * 9.0, 3.3);
        return (0.95 * streak * radial * grain + 0.14 * radial) * Smooth(0.99, 0.9, r);
    }

    // ---- The wisp flipbook: 16 frames (4 x 4) of thin flame-like tongues rising and fraying. ----
    public static double Wisp(double u, double v) {
        double gx = (u + 1) * 2, gy = (v + 1) * 2;
        int cx = Math.Min(3, (int)gx), cy = Math.Min(3, (int)gy);
        double lu = (gx - cx) * 2 - 1, lv = (gy - cy) * 2 - 1;
        double t = (cy * 4 + cx) / 15.0;
        double up = (1 - lv) / 2;                                           // 0 at the bottom of the cell, 1 at the top
        double sway = (Fbm(lu * 1.4 + 2.0, lv * 1.2 + t * 1.6, t * 0.8) - 0.5) * (0.25 + 0.6 * up);
        double x = lu + sway;
        double width = 0.62 * Math.Pow(1 - 0.7 * up, 0.8) * (0.75 + 0.25 * t);
        double column = Smooth(width, width * 0.15, Math.Abs(x));
        double tongues = 1 - Math.Abs(2 * Fbm(x * 5.2 + 7.0, lv * 0.9 + t * 2.8, 2.0 + t * 0.6) - 1);   // filaments, scrolling up
        tongues = Math.Pow(tongues, 9.0);                                 // only the thin crest of each ridge
        double worn = 0.12 + 0.2 * t + 0.22 * up;
        double dense = Sat((tongues * 1.2 + 0.16 * (1 - up) * (1 - t) - worn) / 0.3);
        return dense * column * (1 - 0.5 * t * t) * Smooth(0.93, 0.74, Math.Abs(lv)) * Smooth(0.93, 0.78, Math.Abs(lu));
    }

    // ---- Coloured textures (the colours are baked in, so the emitter's Color stays white) ----
    public delegate void Paint(double u, double v, double[] rgba);   // rgba each 0..1

    public static void SaveColour(string path, int size, Paint paint) {
        using (Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb)) {
            BitmapData data = bmp.LockBits(new Rectangle(0, 0, size, size), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] px = new byte[size * size * 4];
            double[] c = new double[4];
            for (int y = 0; y < size; y++) {
                for (int x = 0; x < size; x++) {
                    double u = (x + 0.5) / size * 2 - 1, v = (y + 0.5) / size * 2 - 1;
                    c[0] = c[1] = c[2] = c[3] = 0;
                    paint(u, v, c);
                    int i = (y * size + x) * 4;
                    px[i] = (byte)Math.Round(Sat(c[2]) * 255);        // blue
                    px[i + 1] = (byte)Math.Round(Sat(c[1]) * 255);    // green
                    px[i + 2] = (byte)Math.Round(Sat(c[0]) * 255);    // red
                    px[i + 3] = (byte)Math.Round(Sat(c[3]) * 255);
                }
            }
            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    // One blade of the star, standing on the image's CENTRE and pointing up, so a camera-facing
    // particle given any Rotation turns about the blade's base, and many of them at one point make a
    // star. Shaded the way the reference's spikes are: white-hot down the middle (less of it toward
    // the point), neon green, a deeper green edge. Hard-edged, a true point.
    public static void Blade(double u, double v, double[] c) {
        double t = -v / 0.97;                                 // 0 at the base (the centre), 1 at the point
        if (t <= -0.02 || t >= 1) return;
        double w = t < 0 ? 0.06 : 0.11 * (t < 0.07 ? 0.55 + 0.45 * Math.Sqrt(t / 0.07) : (1 - t) / 0.93);
        double d = Math.Abs(u);
        double a = Sat((w - d) / 0.005) * Smooth(-0.02, 0.0, t);
        if (a <= 0) return;
        double q = d / Math.Max(w, 0.0001);                   // 0 on the middle line, 1 at the edge
        double hot = 0.46 * (1 - 0.55 * t);                   // how wide the white is, narrowing to the point
        double white = Smooth(hot, hot * 0.45, q);
        double deep = Smooth(0.62, 0.95, q);
        double r = 0.22 + 0.78 * white, g = 1.0, b = 0.30 + 0.70 * white;      // neon green up to white
        r = r * (1 - 0.72 * deep); g = g * (1 - 0.42 * deep); b = b * (1 - 0.6 * deep);   // down to deep green
        c[0] = r; c[1] = g; c[2] = b; c[3] = a;
    }

    public static void All(string dir) {
        SaveColour(dir + "\\hit_blade.png", 512, Blade);
        Save(dir + "\\hit_dust.png", 512, Dust);
        Save(dir + "\\hit_wisp.png", 1024, Wisp);
        Save(dir + "\\hit_ribbon.png", 512, Ribbon);
        Save(dir + "\\hit_star.png", 256, Star);
        Save(dir + "\\hit_smoke.png", 1024, Smoke);
        Save(dir + "\\hit_crown.png", 512, Crown);
        Save(dir + "\\hit_circle.png", 256, Circle);
        Save(dir + "\\hit_needle.png", 512, Needle);
        Save(dir + "\\hit_dome.png", 256, Dome);
        Save(dir + "\\hit_floor.png", 512, Floor);
        Save(dir + "\\hit_arc.png", 256, Arc);
    }
}
'@

$outDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $outDir | Out-Null
[HitTex]::All($outDir)

# The preview: all four on a mid-tone background (white on transparent looks empty in a viewer).
$names = 'hit_needle', 'hit_dome', 'hit_floor', 'hit_arc', 'hit_crown', 'hit_circle', 'hit_ribbon', 'hit_star'
$sheet = New-Object System.Drawing.Bitmap 2080, 280
$canvas = [System.Drawing.Graphics]::FromImage($sheet)
$canvas.Clear([System.Drawing.Color]::FromArgb(255, 40, 60, 90))
$canvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($index = 0; $index -lt $names.Count; $index++) {
	$image = [System.Drawing.Image]::FromFile((Join-Path $outDir ($names[$index] + '.png')))
	$canvas.DrawImage($image, 10 + $index * 260, 12, 256, 256)
	$image.Dispose()
}
$canvas.Dispose()
$sheet.Save((Join-Path $outDir 'hit_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
'done'
# The flipbook on the same background, half size, to look at.
$book = [System.Drawing.Image]::FromFile((Join-Path $outDir 'hit_smoke.png'))
$bookSheet = New-Object System.Drawing.Bitmap 768, 768
$bookCanvas = [System.Drawing.Graphics]::FromImage($bookSheet)
$bookCanvas.Clear([System.Drawing.Color]::FromArgb(255, 40, 60, 90))
$bookCanvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$bookCanvas.DrawImage($book, 0, 0, 768, 768)
$bookCanvas.Dispose(); $book.Dispose()
$bookSheet.Save((Join-Path $outDir 'hit_smoke_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bookSheet.Dispose()