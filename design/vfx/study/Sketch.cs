// Sketch drawing kit (C# 5, compiled with ImgLab.cs): rough marker strokes, rough outlines, hatching,
// scribbles, swirl lines, four-point stars, scribble smears and a pencil render of a tone image.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

public static class Sk
{
    // A marker stroke along a polyline: resampled every 4 px, overshoot at both ends, a slow wobble
    // across it, tapered ends, filled as one variable-width polygon.
    public static void Stroke(Graphics g, PointF[] pts, float width, Color col, Random rnd, float wobble, float taperLen, float overshoot)
    {
        StrokeP(g, pts, width, col, rnd, wobble, taperLen, overshoot, 0f, 0f);
    }

    // As Stroke, plus pressure (width varies by +-pressure along the stroke) and gaps (a chance of one or two
    // short breaks, where the pen skipped).
    public static void StrokeP(Graphics g, PointF[] pts, float width, Color col, Random rnd, float wobble, float taperLen, float overshoot, float pressure, float gapChance)
    {
        if (pts.Length < 2) return;
        var P = new List<PointF>();
        // overshoot
        var a0 = pts[0]; var a1 = pts[1]; var z0 = pts[pts.Length - 1]; var z1 = pts[pts.Length - 2];
        float l0 = Len(a0, a1), lz = Len(z0, z1);
        var start = l0 > 0 ? new PointF(a0.X + (a0.X - a1.X) / l0 * overshoot, a0.Y + (a0.Y - a1.Y) / l0 * overshoot) : a0;
        var end = lz > 0 ? new PointF(z0.X + (z0.X - z1.X) / lz * overshoot, z0.Y + (z0.Y - z1.Y) / lz * overshoot) : z0;
        var src = new List<PointF>(); src.Add(start); src.AddRange(pts); src.Add(end);
        for (int i = 0; i < src.Count - 1; i++)
        {
            float d = Len(src[i], src[i + 1]); int m = Math.Max(1, (int)(d / 4));
            for (int j = 0; j < m; j++) P.Add(new PointF(src[i].X + (src[i + 1].X - src[i].X) * j / m, src[i].Y + (src[i + 1].Y - src[i].Y) * j / m));
        }
        P.Add(src[src.Count - 1]);
        int n = P.Count; if (n < 2) return;
        float total = 0; var s = new float[n]; for (int i = 1; i < n; i++) { total += Len(P[i - 1], P[i]); s[i] = total; }
        double p1 = rnd.NextDouble() * 6.28, p2 = rnd.NextDouble() * 6.28, f1 = 1.0 / (40 + rnd.NextDouble() * 50), f2 = 1.0 / (12 + rnd.NextDouble() * 10);
        double q1 = rnd.NextDouble() * 6.28, q2 = rnd.NextDouble() * 6.28, fq = 1.0 / (25 + rnd.NextDouble() * 30);
        var gaps = new List<float[]>();
        if (gapChance > 0 && total > 60)
        {
            int ng = rnd.NextDouble() < gapChance ? (rnd.NextDouble() < 0.3 ? 2 : 1) : 0;
            for (int k = 0; k < ng; k++) { float gs = total * (0.15f + 0.7f * (float)rnd.NextDouble()); gaps.Add(new float[] { gs, gs + 5 + (float)rnd.NextDouble() * 14 }); }
        }
        var left = new PointF[n]; var right = new PointF[n];
        for (int i = 0; i < n; i++)
        {
            var A = P[Math.Max(0, i - 1)]; var B = P[Math.Min(n - 1, i + 1)];
            float tx = B.X - A.X, ty = B.Y - A.Y, tl = (float)Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-4f) { tx = 1; ty = 0; tl = 1; }
            float nx = -ty / tl, ny = tx / tl;
            float off = (float)(wobble * (0.65 * Math.Sin(s[i] * f1 + p1) + 0.35 * Math.Sin(s[i] * f2 + p2)));
            float tp = taperLen > 0 ? Math.Min(1f, Math.Min(s[i], total - s[i]) / taperLen) : 1f;
            float w = width * (0.25f + 0.75f * (float)Math.Pow(Math.Max(0, tp), 0.6)) / 2f;
            if (pressure > 0) w *= Math.Max(0.15f, 1f + pressure * (float)(0.6 * Math.Sin(s[i] * fq + q1) + 0.4 * Math.Sin(s[i] * fq * 2.7 + q2)));
            foreach (var gp in gaps) if (s[i] >= gp[0] && s[i] <= gp[1]) w = 0;
            float cx = P[i].X + nx * off, cy = P[i].Y + ny * off;
            left[i] = new PointF(cx + nx * w, cy + ny * w); right[n - 1 - i] = new PointF(cx - nx * w, cy - ny * w);
        }
        var poly = new PointF[2 * n]; Array.Copy(left, poly, n); Array.Copy(right, 0, poly, n, n);
        foreach (var q in poly) if (float.IsNaN(q.X) || float.IsNaN(q.Y) || float.IsInfinity(q.X) || float.IsInfinity(q.Y)) return;
        using (var b = new SolidBrush(col)) g.FillPolygon(b, poly);
    }

    static float Len(PointF a, PointF b) { return (float)Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y)); }

    // A hand-drawn edge from a to b: bowed slightly, ends overshooting (or stopping short) at random,
    // drawn `passes` times (the first full weight, the rest thin and a little off), pressure and breaks.
    public static void SketchEdge(Graphics g, PointF a, PointF b, float width, Color col, Random rnd, int passes, float bowFrac, float jitter)
    {
        float len = Len(a, b); if (len < 1) return;
        float ux = (b.X - a.X) / len, uy = (b.Y - a.Y) / len, nx = -uy, ny = ux;
        for (int pass = 0; pass < passes; pass++)
        {
            float bow = (float)(rnd.NextDouble() - 0.5) * 2 * bowFrac * len;
            float os0 = -5 + (float)rnd.NextDouble() * 24, os1 = -5 + (float)rnd.NextDouble() * 24;
            float off = pass == 0 ? 0 : (float)(rnd.NextDouble() - 0.5) * 2 * (2 + width * 0.45f);
            var sx = a.X - ux * os0; var sy = a.Y - uy * os0; var ex = b.X + ux * os1; var ey = b.Y + uy * os1;
            var pts = new PointF[11];
            for (int k = 0; k <= 10; k++)
            {
                float t = k / 10f, side = bow * 4 * t * (1 - t) + off;
                float jx = (float)(rnd.NextDouble() - 0.5) * jitter, jy = (float)(rnd.NextDouble() - 0.5) * jitter;
                pts[k] = new PointF(sx + (ex - sx) * t + nx * side + jx, sy + (ey - sy) * t + ny * side + jy);
            }
            float w = pass == 0 ? width : width * (0.3f + 0.25f * (float)rnd.NextDouble());
            StrokeP(g, pts, w, col, rnd, 1.2f, 14, 0, 0.35f, pass == 0 ? 0.15f : 0.5f);
        }
    }

    public static void SketchPoly(Graphics g, PointF[] poly, float width, Color col, Random rnd, int passes, float bowFrac, float jitter)
    {
        for (int i = 0; i < poly.Length; i++) SketchEdge(g, poly[i], poly[(i + 1) % poly.Length], width, col, rnd, passes, bowFrac, jitter);
    }

    // A filled shape with wobbly, slightly bowed edges (for ink fills that aren't ruler-straight).
    public static PointF[] WobblePoly(PointF[] poly, Random rnd, float bowFrac, float jitter)
    {
        var res = new List<PointF>();
        for (int i = 0; i < poly.Length; i++)
        {
            var a = poly[i]; var b = poly[(i + 1) % poly.Length]; float len = Len(a, b); if (len < 1) continue;
            float nx = -(b.Y - a.Y) / len, ny = (b.X - a.X) / len, bow = (float)(rnd.NextDouble() - 0.5) * 2 * bowFrac * len;
            for (int k = 0; k < 14; k++)
            {
                float t = k / 14f, side = bow * 4 * t * (1 - t) + (float)(rnd.NextDouble() - 0.5) * jitter;
                res.Add(new PointF(a.X + (b.X - a.X) * t + nx * side, a.Y + (b.Y - a.Y) * t + ny * side));
            }
        }
        return res.ToArray();
    }

    // Every vertex moved by up to +-amt (the drawing boils from frame to frame).
    public static PointF[] Jitter(PointF[] poly, Random rnd, float amt)
    {
        var o = new PointF[poly.Length];
        for (int i = 0; i < poly.Length; i++) o[i] = new PointF(poly[i].X + (float)(rnd.NextDouble() - 0.5) * 2 * amt, poly[i].Y + (float)(rnd.NextDouble() - 0.5) * 2 * amt);
        return o;
    }

    // Quick pencil hatching in a convex shape: parallel lines (each group at its own slight angle) joined
    // into zigzags of 3-6 lines, ends trimmed or overshooting the outline at random.
    public static void HandHatch(Graphics g, PointF[] poly, float angleDeg, float spacing, float width, Color col, Random rnd, float trim)
    {
        float cx = 0, cy = 0; foreach (var p in poly) { cx += p.X; cy += p.Y; } cx /= poly.Length; cy /= poly.Length;
        float R = 0; foreach (var p in poly) R = Math.Max(R, Len(p, new PointF(cx, cy)));
        float o = -R;
        while (o < R)
        {
            int group = 3 + rnd.Next(4);
            double a = (angleDeg + (rnd.NextDouble() - 0.5) * 10) * Math.PI / 180;
            float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
            var pts = new List<PointF>(); bool fwd = true;
            for (int k = 0; k < group && o < R; k++, o += spacing * (0.75f + 0.5f * (float)rnd.NextDouble()))
            {
                float px = cx + nx * o, py = cy + ny * o, t0, t1;
                if (!Span(poly, cx, cy, px, py, ux, uy, out t0, out t1)) continue;
                t0 += -trim * 0.5f + (float)rnd.NextDouble() * trim * 1.5f; t1 -= -trim * 0.5f + (float)rnd.NextDouble() * trim * 1.5f;
                if (t1 - t0 < 6) continue;
                var A = new PointF(px + ux * t0, py + uy * t0); var B = new PointF(px + ux * t1, py + uy * t1);
                if (fwd) { pts.Add(A); pts.Add(B); } else { pts.Add(B); pts.Add(A); }
                fwd = !fwd;
            }
            if (pts.Count >= 2) StrokeP(g, pts.ToArray(), width * (0.7f + 0.6f * (float)rnd.NextDouble()), col, rnd, 1.0f, 8, 0, 0.3f, 0.2f);
        }
    }

    // Where the line p + u t lies inside a convex polygon (Cyrus-Beck); false if it misses.
    public static bool Span(PointF[] poly, float cx, float cy, float px, float py, float ux, float uy, out float t0, out float t1)
    {
        t0 = -1e6f; t1 = 1e6f;
        for (int i = 0; i < poly.Length; i++)
        {
            var a = poly[i]; var b = poly[(i + 1) % poly.Length];
            float nx = -(b.Y - a.Y), ny = b.X - a.X;
            if (nx * (cx - a.X) + ny * (cy - a.Y) < 0) { nx = -nx; ny = -ny; }
            float num = nx * (px - a.X) + ny * (py - a.Y), den = nx * ux + ny * uy;
            if (Math.Abs(den) < 1e-6f) { if (num < 0) return false; continue; }
            float t = -num / den;
            if (den > 0) t0 = Math.Max(t0, t); else t1 = Math.Min(t1, t);
        }
        return t1 > t0;
    }

    public static PointF[] Line(float x0, float y0, float x1, float y1) { return new PointF[] { new PointF(x0, y0), new PointF(x1, y1) }; }

    // Rough outline: every edge its own stroke with overshoot; `passes` times, each slightly off.
    public static void RoughPoly(Graphics g, PointF[] poly, float width, Color col, Random rnd, int passes, float jitter)
    {
        for (int pass = 0; pass < passes; pass++)
            for (int i = 0; i < poly.Length; i++)
            {
                var a = poly[i]; var b = poly[(i + 1) % poly.Length];
                float jx = (float)(rnd.NextDouble() - 0.5) * jitter, jy = (float)(rnd.NextDouble() - 0.5) * jitter;
                Stroke(g, new PointF[] { new PointF(a.X + jx, a.Y + jy), new PointF(b.X - jx, b.Y + jy) }, width * (pass == 0 ? 1f : 0.55f), col, rnd, 1.5f, 10, 4 + (float)rnd.NextDouble() * 10);
            }
    }

    // Hatching clipped to a polygon: strokes at angle, `spacing` apart, broken into random lengths.
    public static void Hatch(Graphics g, PointF[] poly, float angleDeg, float spacing, float width, Color col, Random rnd, float minLen, float maxLen)
    {
        float x0 = float.MaxValue, y0 = float.MaxValue, x1 = float.MinValue, y1 = float.MinValue;
        foreach (var p in poly) { x0 = Math.Min(x0, p.X); y0 = Math.Min(y0, p.Y); x1 = Math.Max(x1, p.X); y1 = Math.Max(y1, p.Y); }
        var path = new GraphicsPath(); path.AddPolygon(poly);
        g.SetClip(path, CombineMode.Replace);
        double a = angleDeg * Math.PI / 180; float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
        float cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, R = (float)Math.Sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) / 2 + 20;
        for (float o = -R; o <= R; o += spacing * (0.7f + 0.6f * (float)rnd.NextDouble()))
        {
            float t = -R;
            while (t < R)
            {
                float L = minLen + (float)rnd.NextDouble() * (maxLen - minLen);
                float px = cx + nx * o + ux * t, py = cy + ny * o + uy * t;
                Stroke(g, Line(px, py, px + ux * L, py + uy * L), width * (0.7f + 0.6f * (float)rnd.NextDouble()), col, rnd, 1.2f, L * 0.3f, 0);
                t += L + (float)rnd.NextDouble() * maxLen * 0.4f;
            }
        }
        g.ResetClip();
    }

    // Scribble streaks: each a zigzag going back and forth along the angle.
    public static void Scribbles(Graphics g, RectangleF area, float angleDeg, int count, float minLen, float maxLen, float width, Color col, Random rnd, float zigAmp, int zigs)
    {
        double a = angleDeg * Math.PI / 180; float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
        for (int k = 0; k < count; k++)
        {
            float px = area.X + (float)rnd.NextDouble() * area.Width, py = area.Y + (float)rnd.NextDouble() * area.Height;
            float L = minLen + (float)rnd.NextDouble() * (maxLen - minLen);
            int z = Math.Max(1, zigs + rnd.Next(-1, 2));
            var pts = new List<PointF>();
            for (int i = 0; i <= z; i++)
            {
                float along = (i % 2 == 0) ? 0 : L; along += (float)(rnd.NextDouble() - 0.5) * L * 0.2f;
                float side = zigAmp * i / Math.Max(1, z) + (float)(rnd.NextDouble() - 0.5) * zigAmp * 0.3f;
                pts.Add(new PointF(px + ux * along + nx * side, py + uy * along + ny * side));
            }
            StrokeP(g, pts.ToArray(), width * (0.6f + 0.8f * (float)rnd.NextDouble()), col, rnd, 1.5f, 12, 0, 0.4f, 0.3f);
        }
    }

    // Swirl speed lines: arcs round (cx, cy), the radius drifting along each arc.
    public static void Swirl(Graphics g, float cx, float cy, int count, float r0, float r1, float width, Color col, Random rnd, float squash)
    {
        for (int k = 0; k < count; k++)
        {
            float r = r0 + (float)rnd.NextDouble() * (r1 - r0);
            double st = rnd.NextDouble() * Math.PI * 2, sweep = (0.3 + rnd.NextDouble() * 1.0) * (rnd.Next(2) == 0 ? 1 : -1);
            float drift = (float)(rnd.NextDouble() - 0.5) * 0.25f;
            var pts = new List<PointF>();
            for (int i = 0; i <= 24; i++)
            {
                double t = st + sweep * i / 24.0; float rr = r * (1 + drift * i / 24f);
                pts.Add(new PointF(cx + rr * (float)Math.Cos(t), cy + rr * squash * (float)Math.Sin(t)));
            }
            StrokeP(g, pts.ToArray(), width * (0.5f + (float)rnd.NextDouble()), col, rnd, 2.5f, 40, 0, 0.45f, 0.6f);
        }
    }

    // Four-point star: long sharp spikes, concave sides; spikes of different lengths.
    public static void Star(Graphics g, float cx, float cy, float rLong, float rShort, float angleDeg, Color col, Random rnd)
    {
        var path = new GraphicsPath(); var tips = new PointF[4];
        for (int i = 0; i < 4; i++)
        {
            double a = (angleDeg + 90 * i) * Math.PI / 180; float r = rLong * (i % 2 == 0 ? 1f : 0.62f) * (0.85f + 0.3f * (float)rnd.NextDouble());
            tips[i] = new PointF(cx + r * (float)Math.Cos(a), cy + r * (float)Math.Sin(a));
        }
        path.StartFigure();
        for (int i = 0; i < 4; i++)
        {
            var a = tips[i]; var b = tips[(i + 1) % 4];
            double mid = (angleDeg + 90 * i + 45) * Math.PI / 180;
            var m = new PointF(cx + rShort * (float)Math.Cos(mid), cy + rShort * (float)Math.Sin(mid));
            path.AddBezier(a, new PointF((a.X + m.X * 3) / 4, (a.Y + m.Y * 3) / 4), new PointF((b.X + m.X * 3) / 4, (b.Y + m.Y * 3) / 4), b);
        }
        path.CloseFigure();
        using (var br = new SolidBrush(col)) g.FillPath(br, path);
    }

    // Scribble smear of a shape: zigzag streaks along the angle wherever the mask is dark, shifted along it.
    public static void Smear(Graphics g, Img mask, float angleDeg, int count, float minLen, float maxLen, float width, Color col, Random rnd, float shift, float zigAmp)
    {
        double a = angleDeg * Math.PI / 180; float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
        int tries = 0, made = 0;
        while (made < count && tries < count * 40)
        {
            tries++;
            int x = rnd.Next(mask.W), y = rnd.Next(mask.H);
            if (mask.L(y * mask.W + x) > 0.5f) continue;
            float L = minLen + (float)rnd.NextDouble() * (maxLen - minLen);
            float sh = shift * (float)rnd.NextDouble();
            float px = x - ux * L * 0.5f + ux * sh, py = y - uy * L * 0.5f + uy * sh;
            var pts = new List<PointF>(); int z = 3 + rnd.Next(3);
            for (int i = 0; i <= z; i++) { float along = (i % 2 == 0) ? 0 : L; float side = zigAmp * ((float)i / z - 0.5f); pts.Add(new PointF(px + ux * along + nx * side, py + uy * along + ny * side)); }
            Stroke(g, pts.ToArray(), width * (0.6f + 0.8f * (float)rnd.NextDouble()), col, rnd, 1.0f, 10, 0);
            made++;
        }
    }

    // Pencil render of a tone image (0 = dark) round (cx, cy): graphite strokes running outward from the
    // centre, their density and darkness following the tone; scribbled fill where it is near black;
    // a paper colour with grain under it. Returns the drawing (paper-coloured where untouched).
    public static Bitmap Pencil(Img tone, float cx, float cy, int count, int seed, float lenMin, float lenMax, float angJitterDeg)
    {
        var rnd = new Random(seed);
        var bmp = new Bitmap(tone.W, tone.H);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.FromArgb(244, 239, 231));
            for (int k = 0; k < count; k++)
            {
                int x = rnd.Next(tone.W), y = rnd.Next(tone.H);
                float d = 1 - tone.L(y * tone.W + x);
                if (rnd.NextDouble() > Math.Pow(Math.Max(0, d), 1.8)) continue;
                double ang = Math.Atan2(y - cy, x - cx) + (rnd.NextDouble() - 0.5) * angJitterDeg * Math.PI / 90;
                float L = (lenMin + (float)rnd.NextDouble() * (lenMax - lenMin)) * (0.6f + 0.8f * d);
                float ux = (float)Math.Cos(ang), uy = (float)Math.Sin(ang);
                int alpha = (int)Math.Min(255, 35 + 175 * d * d * (0.7 + 0.5 * rnd.NextDouble()));
                int v = (int)(80 - 60 * d);
                var col = Color.FromArgb(alpha, v, v, v + 4);
                float w = 0.8f + 1.6f * d * (float)rnd.NextDouble();
                if (d > 0.88f && rnd.NextDouble() < 0.45)
                {   // near black: a short scribble back and forth across the stroke
                    var pts = new List<PointF>(); float nx = -uy, ny = ux; int z = 4 + rnd.Next(4);
                    for (int i = 0; i <= z; i++) { float along = (i % 2 == 0) ? 0 : L; float side = 14f * i / z; pts.Add(new PointF(x + ux * along + nx * side, y + uy * along + ny * side)); }
                    Stroke(g, pts.ToArray(), w * 1.6f, Color.FromArgb(alpha, 18, 18, 22), rnd, 0.8f, 6, 0);
                }
                else Stroke(g, Line(x - ux * L / 2, y - uy * L / 2, x + ux * L / 2, y + uy * L / 2), w, col, rnd, 1.0f, L * 0.35f, 0);
            }
        }
        return bmp;
    }
}
