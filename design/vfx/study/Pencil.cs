// Pencil drawing kit (compiled with ImgLab.cs and Sketch.cs). Everything is 2D drawing technique:
// edges built from several scratchy graphite marks, construction lines, hatching laid along a surface,
// square-to-quad perspective (homography), a pull toward a vanishing point (a dent), graphite on paper.
using System;
using System.Collections.Generic;
using System.Drawing;

public static class Pn
{
    // Graphite of a given strength (0 = barely there, 1 = full pressure).
    public static Color Graphite(float w)
    {
        int a = (int)Math.Max(6, Math.Min(255, 14 + 235 * w));
        return Color.FromArgb(a, 26, 26, 30);
    }

    // One pencil mark along a path: slight wobble, pressure changes, tapered ends, an occasional skip.
    public static void Mark(Graphics g, PointF[] path, float weight, float width, Color tint, Random rnd)
    {
        float w = width * (0.75f + 0.5f * (float)rnd.NextDouble());
        float a = Math.Max(0, Math.Min(1, weight * (0.7f + 0.6f * (float)rnd.NextDouble())));
        var c = tint.A == 0 ? Graphite(a) : Color.FromArgb((int)(Math.Min(255, 14 + 235 * a)), tint.R, tint.G, tint.B);
        Sk.StrokeP(g, path, w, c, rnd, 0.9f, 12, 0, 0.55f, 0.18f);
    }
    public static void Mark(Graphics g, PointF[] path, float weight, float width, Random rnd) { Mark(g, path, weight, width, Color.Empty, rnd); }

    // An edge from a to b built from `strokes` marks: each a little off the line, a little bowed, ends
    // overshooting or stopping short. The first is the firmest.
    public static void Line(Graphics g, PointF a, PointF b, float weight, float width, Random rnd, int strokes, float spread, float overshoot)
    { Line(g, a, b, weight, width, Color.Empty, rnd, strokes, spread, overshoot); }
    public static void Line(Graphics g, PointF a, PointF b, float weight, float width, Color tint, Random rnd, int strokes, float spread, float overshoot)
    {
        float len = D(a, b); if (len < 1) return;
        float ux = (b.X - a.X) / len, uy = (b.Y - a.Y) / len, nx = -uy, ny = ux;
        for (int k = 0; k < strokes; k++)
        {
            float off = (float)(rnd.NextDouble() - 0.5) * 2 * spread;
            float o0 = overshoot * (-0.3f + 1.3f * (float)rnd.NextDouble()), o1 = overshoot * (-0.3f + 1.3f * (float)rnd.NextDouble());
            float bow = (float)(rnd.NextDouble() - 0.5) * len * 0.014f, tilt = (float)(rnd.NextDouble() - 0.5) * spread;
            var pts = new PointF[9];
            for (int i = 0; i <= 8; i++)
            {
                float t = i / 8f, s = -o0 + t * (len + o0 + o1), side = off + tilt * (t - 0.5f) + bow * 4 * t * (1 - t);
                pts[i] = new PointF(a.X + ux * s + nx * side, a.Y + uy * s + ny * side);
            }
            Mark(g, pts, weight * (k == 0 ? 1f : 0.45f + 0.4f * (float)rnd.NextDouble()), width * (k == 0 ? 1f : 0.7f), tint, rnd);
        }
    }

    // A curved edge along a polyline, built the same way: each mark offset, trimmed or broken.
    public static void Path(Graphics g, PointF[] pts, float weight, float width, Random rnd, int strokes, float spread)
    { Path(g, pts, weight, width, Color.Empty, rnd, strokes, spread); }
    public static void Path(Graphics g, PointF[] pts, float weight, float width, Color tint, Random rnd, int strokes, float spread)
    {
        if (pts.Length < 2) return;
        var d = Densify(pts, 6f); int n = d.Length;
        for (int k = 0; k < strokes; k++)
        {
            float off = (float)(rnd.NextDouble() - 0.5) * 2 * spread, drift = (float)(rnd.NextDouble() - 0.5) * spread;
            int i0 = (int)(n * 0.06 * rnd.NextDouble()), i1 = n - 1 - (int)(n * 0.06 * rnd.NextDouble());
            int brk = (n > 40 && rnd.NextDouble() < 0.35) ? i0 + (int)((i1 - i0) * (0.3 + 0.4 * rnd.NextDouble())) : -1;
            var cur = new List<PointF>();
            for (int i = i0; i <= i1; i++)
            {
                var A = d[Math.Max(0, i - 1)]; var B = d[Math.Min(n - 1, i + 1)];
                float tx = B.X - A.X, ty = B.Y - A.Y, tl = (float)Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-4f) continue;
                float side = off + drift * (i - i0) / Math.Max(1f, i1 - i0);
                cur.Add(new PointF(d[i].X - ty / tl * side, d[i].Y + tx / tl * side));
                if (i == brk && cur.Count > 2) { Mark(g, cur.ToArray(), weight * (k == 0 ? 1f : 0.55f), width * (k == 0 ? 1f : 0.7f), tint, rnd); cur.Clear(); i += 2; }
            }
            if (cur.Count > 1) Mark(g, cur.ToArray(), weight * (k == 0 ? 1f : 0.55f), width * (k == 0 ? 1f : 0.7f), tint, rnd);
        }
    }

    // A construction line: faint, single, long.
    public static void Ghost(Graphics g, PointF a, PointF b, float weight, Random rnd) { Mark(g, new PointF[] { a, b }, weight, 1.1f, rnd); }
    public static void Ghost(Graphics g, PointF a, PointF b, float weight, Color tint, Random rnd) { Mark(g, new PointF[] { a, b }, weight, 1.1f, tint, rnd); }

    // Straight hatching in a convex shape: separate marks, ends trimmed or overshooting, angle jittered,
    // the odd mark skipped. `spacing` px between marks.
    public static void Hatch(Graphics g, PointF[] convex, float angleDeg, float spacing, float weight, float width, Color tint, Random rnd, float trim, float jitterDeg)
    {
        float cx = 0, cy = 0; foreach (var p in convex) { cx += p.X; cy += p.Y; } cx /= convex.Length; cy /= convex.Length;
        float R = 0; foreach (var p in convex) R = Math.Max(R, D(p, new PointF(cx, cy)));
        for (float o = -R; o < R; o += spacing * (0.7f + 0.6f * (float)rnd.NextDouble()))
        {
            if (rnd.NextDouble() < 0.06) continue;
            double a = (angleDeg + (rnd.NextDouble() - 0.5) * 2 * jitterDeg) * Math.PI / 180;
            float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
            float px = cx + nx * o, py = cy + ny * o, t0, t1;
            if (!Sk.Span(convex, cx, cy, px, py, ux, uy, out t0, out t1)) continue;
            t0 += trim * (-0.4f + 1.4f * (float)rnd.NextDouble()); t1 -= trim * (-0.4f + 1.4f * (float)rnd.NextDouble());
            if (t1 - t0 < 4) continue;
            Mark(g, new PointF[] { new PointF(px + ux * t0, py + uy * t0), new PointF(px + ux * t1, py + uy * t1) }, weight, width, tint, rnd);
        }
    }
    public static void Hatch(Graphics g, PointF[] convex, float angleDeg, float spacing, float weight, float width, Random rnd, float trim, float jitterDeg)
    { Hatch(g, convex, angleDeg, spacing, weight, width, Color.Empty, rnd, trim, jitterDeg); }

    // ---- perspective in the plane: unit square (0,0) (1,0) (1,1) (0,1) -> a drawn quad (Heckbert) ----
    public static double[] Homography(PointF[] q)
    {
        double x0 = q[0].X, y0 = q[0].Y, x1 = q[1].X, y1 = q[1].Y, x2 = q[2].X, y2 = q[2].Y, x3 = q[3].X, y3 = q[3].Y;
        double dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3, dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
        double gg = 0, hh = 0, den = dx1 * dy2 - dx2 * dy1;
        if (Math.Abs(dx3) > 1e-9 || Math.Abs(dy3) > 1e-9) { gg = (dx3 * dy2 - dx2 * dy3) / den; hh = (dx1 * dy3 - dx3 * dy1) / den; }
        return new double[] { x1 - x0 + gg * x1, x3 - x0 + hh * x3, x0, y1 - y0 + gg * y1, y3 - y0 + hh * y3, y0, gg, hh };
    }
    public static PointF Map(double[] H, double u, double v)
    {
        double w = H[6] * u + H[7] * v + 1;
        return new PointF((float)((H[0] * u + H[1] * v + H[2]) / w), (float)((H[3] * u + H[4] * v + H[5]) / w));
    }
    // A line, circle or ellipse drawn on the plane (in its unit-square coordinates), mapped to the screen.
    public static PointF[] MapLine(double[] H, double u0, double v0, double u1, double v1, int n)
    {
        var o = new PointF[n + 1]; for (int i = 0; i <= n; i++) o[i] = Map(H, u0 + (u1 - u0) * i / n, v0 + (v1 - v0) * i / n); return o;
    }
    public static PointF[] MapEllipse(double[] H, double cu, double cv, double ru, double rv, double a0, double a1, int n)
    {
        var o = new PointF[n + 1];
        for (int i = 0; i <= n; i++) { double t = a0 + (a1 - a0) * i / n; o[i] = Map(H, cu + ru * Math.Cos(t), cv + rv * Math.Sin(t)); }
        return o;
    }

    // ---- the dent: everything near (cx, cy) pulled toward it; lines bow inward, rings close up ----
    public static PointF Pull(PointF p, float cx, float cy, float k, float R)
    {
        float dx = p.X - cx, dy = p.Y - cy, s = 1 - k * (float)Math.Exp(-(dx * dx + dy * dy) / (R * R));
        return new PointF(cx + dx * s, cy + dy * s);
    }
    public static PointF[] PullPath(PointF[] pts, float cx, float cy, float k, float R)
    {
        var d = Densify(pts, 5f); var o = new PointF[d.Length];
        for (int i = 0; i < d.Length; i++) o[i] = Pull(d[i], cx, cy, k, R);
        return o;
    }

    // ---- curvilinear: an arc through a and b bulging by `sag` px (to the left of a->b when positive) ----
    public static PointF[] Arc(PointF a, PointF b, float sag, int n)
    {
        float len = D(a, b); var o = new PointF[n + 1];
        if (Math.Abs(sag) < 0.5f) { for (int i = 0; i <= n; i++) o[i] = new PointF(a.X + (b.X - a.X) * i / n, a.Y + (b.Y - a.Y) * i / n); return o; }
        float mx = (a.X + b.X) / 2, my = (a.Y + b.Y) / 2, nx = -(b.Y - a.Y) / len, ny = (b.X - a.X) / len;
        float h = len / 2, r = (h * h + sag * sag) / (2 * Math.Abs(sag)), dc = r - Math.Abs(sag), sgn = Math.Sign(sag);
        float cx = mx - nx * dc * sgn, cy = my - ny * dc * sgn;
        double t0 = Math.Atan2(a.Y - cy, a.X - cx), t1 = Math.Atan2(b.Y - cy, b.X - cx);
        double mid = Math.Atan2(my + ny * sag - cy, mx + nx * sag - cx);
        // go from t0 to t1 the way that passes the bulge
        double dt = t1 - t0; while (dt > Math.PI) dt -= 2 * Math.PI; while (dt < -Math.PI) dt += 2 * Math.PI;
        double dm = mid - t0; while (dm > Math.PI) dm -= 2 * Math.PI; while (dm < -Math.PI) dm += 2 * Math.PI;
        if (Math.Sign(dm) != Math.Sign(dt) || Math.Abs(dm) > Math.Abs(dt)) dt = dt > 0 ? dt - 2 * Math.PI : dt + 2 * Math.PI;
        for (int i = 0; i <= n; i++) { double t = t0 + dt * i / n; o[i] = new PointF(cx + r * (float)Math.Cos(t), cy + r * (float)Math.Sin(t)); }
        return o;
    }

    public static PointF[] Densify(PointF[] pts, float step)
    {
        var o = new List<PointF>();
        for (int i = 0; i < pts.Length - 1; i++)
        {
            float l = D(pts[i], pts[i + 1]); int m = Math.Max(1, (int)(l / step));
            for (int j = 0; j < m; j++) o.Add(new PointF(pts[i].X + (pts[i + 1].X - pts[i].X) * j / m, pts[i].Y + (pts[i + 1].Y - pts[i].Y) * j / m));
        }
        o.Add(pts[pts.Length - 1]);
        return o.ToArray();
    }

    // Graphite on paper: the drawing's darkness only takes where the paper's tooth catches it; paper colour.
    public static Img Paper(Img drawing, int seed, float tooth)
    {
        var t = Img.Solid(drawing.W, drawing.H, 0.5f, 0.5f, 0.5f);
        Lab.Grain(t, 0.5f, 1.2f, seed); Lab.Grain(t, 0.25f, 3.5f, seed + 1);
        var o = new Img(drawing.W, drawing.H);
        for (int i = 0; i < drawing.W * drawing.H; i++)
        {
            float dark = 1 - drawing.L(i), k = Math.Max(0, Math.Min(1, t.L(i)));
            dark *= (1 - tooth) + tooth * (0.55f + 0.9f * k); dark = Math.Min(1, dark);
            o.R[i] = 0.957f - dark * 0.86f; o.G[i] = 0.937f - dark * 0.84f; o.B[i] = 0.905f - dark * 0.80f;
        }
        return o;
    }

    public static float D(PointF a, PointF b) { return (float)Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y)); }

    // ---- scratchy marks (the user's scratchy references: fast flicks, zigzag hatching past the outline,
    //      loose edges in several partial passes with hooks, looping scribbles for the darkest darks) ----

    // A ribbon along a path: width w0 at the start easing to w1 at the end (pressure, then the lift).
    public static void Ribbon(Graphics g, PointF[] path, float w0, float w1, float pw, Color col)
    {
        var d = Densify(path, 3f); int n = d.Length; if (n < 2) return;
        float total = 0; var s = new float[n]; for (int i = 1; i < n; i++) { total += D(d[i - 1], d[i]); s[i] = total; }
        if (total < 1) return;
        var L = new PointF[n]; var R = new PointF[n];
        for (int i = 0; i < n; i++)
        {
            var A = d[Math.Max(0, i - 1)]; var B = d[Math.Min(n - 1, i + 1)];
            float tx = B.X - A.X, ty = B.Y - A.Y, tl = (float)Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-4f) { tx = 1; ty = 0; tl = 1; }
            float nx = -ty / tl, ny = tx / tl, t = s[i] / total;
            float w = (w0 + (w1 - w0) * (float)Math.Pow(t, pw)) * (0.6f + 0.4f * Math.Min(1f, s[i] / 6f)) / 2f;
            L[i] = new PointF(d[i].X + nx * w, d[i].Y + ny * w); R[n - 1 - i] = new PointF(d[i].X - nx * w, d[i].Y - ny * w);
        }
        var poly = new PointF[2 * n]; Array.Copy(L, poly, n); Array.Copy(R, 0, poly, n, n);
        foreach (var q in poly) if (float.IsNaN(q.X) || float.IsNaN(q.Y) || float.IsInfinity(q.X) || float.IsInfinity(q.Y) || Math.Abs(q.X) > 1e5 || Math.Abs(q.Y) > 1e5) return;
        using (var b = new SolidBrush(col)) g.FillPolygon(b, poly);
    }

    static Color Lead(float weight, Random rnd) { return Graphite(Math.Max(0, Math.Min(1, weight * (0.75f + 0.5f * (float)rnd.NextDouble())))); }

    // A fast flick: firm at the start, bending more and more toward its end (the wrist), lifting to a point.
    public static PointF[] FlickPath(PointF p, double angDeg, float len, float bend)
    {
        double a = angDeg * Math.PI / 180; float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
        var pts = new PointF[10];
        for (int i = 0; i < 10; i++) { float t = i / 9f, side = bend * len * t * t; pts[i] = new PointF(p.X + ux * len * t + nx * side, p.Y + uy * len * t + ny * side); }
        return pts;
    }
    public static void Flick(Graphics g, PointF p, double angDeg, float len, float bend, float weight, float width, Random rnd)
    {
        Ribbon(g, FlickPath(p, angDeg, len, bend), width * (0.8f + 0.4f * (float)rnd.NextDouble()), width * 0.12f, 1.3f, Lead(weight, rnd));
    }

    // Scratchy hatching over a (roughly) convex shape: fast strokes running past the outline by up to `over`
    // px, joined two to `zig` at a time into zigzags (the pen not lifted), each leg slightly bowed.
    public static void Scratch(Graphics g, PointF[] convex, float angleDeg, float spacing, float weight, float width, Random rnd, float over, int zig)
    {
        if (convex.Length < 3) return;
        float cx = 0, cy = 0; foreach (var p in convex) { cx += p.X; cy += p.Y; } cx /= convex.Length; cy /= convex.Length;
        float Rr = 0; foreach (var p in convex) Rr = Math.Max(Rr, D(p, new PointF(cx, cy)));
        var rows = new List<PointF[]>();
        for (float o = -Rr; o < Rr; o += spacing * (0.55f + 0.9f * (float)rnd.NextDouble()))
        {
            double a = (angleDeg + (rnd.NextDouble() - 0.5) * 9) * Math.PI / 180;
            float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
            float px = cx + nx * o, py = cy + ny * o, t0, t1;
            if (!Sk.Span(convex, cx, cy, px, py, ux, uy, out t0, out t1)) continue;
            t0 -= over * (-0.3f + 1.3f * (float)rnd.NextDouble()); t1 += over * (-0.3f + 1.3f * (float)rnd.NextDouble());
            if (t1 - t0 < 5) continue;
            rows.Add(new PointF[] { new PointF(px + ux * t0, py + uy * t0), new PointF(px + ux * t1, py + uy * t1) });
        }
        int i = 0;
        while (i < rows.Count)
        {
            int grp = zig <= 1 ? 1 : 1 + rnd.Next(zig); var path = new List<PointF>(); bool fwd = rnd.Next(2) == 0;
            for (int k = 0; k < grp && i < rows.Count; k++, i++)
            {
                var A = fwd ? rows[i][0] : rows[i][1]; var B = fwd ? rows[i][1] : rows[i][0];
                float ll = Math.Max(1f, D(A, B)), lx = B.X - A.X, ly = B.Y - A.Y, bow = (float)(rnd.NextDouble() - 0.3) * ll * 0.05f;
                path.Add(A); path.Add(new PointF((A.X + B.X) / 2 - ly / ll * bow, (A.Y + B.Y) / 2 + lx / ll * bow)); path.Add(B);
                fwd = !fwd;
            }
            Ribbon(g, path.ToArray(), width * (0.8f + 0.5f * (float)rnd.NextDouble()), width * 0.3f, 1.6f, Lead(weight, rnd));
        }
    }

    // A scribble: the pen circles in small loops while sweeping back and forth across an ellipse (rx along
    // angleDeg, ry across): the darkest darks.
    public static void Scribble(Graphics g, PointF c, float rx, float ry, float angleDeg, int sweeps, float loop, float weight, float width, Random rnd)
    {
        double a = angleDeg * Math.PI / 180; float ux = (float)Math.Cos(a), uy = (float)Math.Sin(a), nx = -uy, ny = ux;
        int n = Math.Max(8, sweeps * 26); var pts = new PointF[n + 1];
        double ph = rnd.NextDouble() * 6.28, f2 = sweeps * (2.6 + rnd.NextDouble());
        for (int i = 0; i <= n; i++)
        {
            double t = (double)i / n;
            float along = rx * (float)Math.Sin(Math.PI * sweeps * t + ph), across = ry * (float)(2 * t - 1);
            float lr = loop * (0.6f + 0.8f * (float)rnd.NextDouble());
            float lx = lr * (float)Math.Cos(2 * Math.PI * f2 * t), ly = lr * 0.8f * (float)Math.Sin(2 * Math.PI * f2 * t);
            pts[i] = new PointF(c.X + ux * along + nx * across + lx, c.Y + uy * along + ny * across + ly);
        }
        Sk.StrokeP(g, pts, width, Lead(weight, rnd), rnd, 0.5f, 8, 0, 0.45f, 0.05f);
    }

    // A loose edge along a path: `passes` scratchy strokes, the first long and firm, the rest shorter, further
    // off and slightly tilted; the ends overshoot and some hook back.
    public static void LoosePath(Graphics g, PointF[] pts, float weight, float width, Random rnd, int passes, float spread)
    {
        var d = Densify(pts, 5f); int n = d.Length; if (n < 2) return;
        for (int k = 0; k < passes; k++)
        {
            float s0 = k == 0 ? 0 : -0.05f + 0.35f * (float)rnd.NextDouble();
            float s1 = k == 0 ? 1 : 0.65f + 0.45f * (float)rnd.NextDouble();
            int i0 = (int)Math.Max(0, Math.Floor(s0 * (n - 1))), i1 = (int)Math.Min(n - 1, Math.Ceiling(s1 * (n - 1)));
            if (i1 - i0 < 1) continue;
            float off = (float)(rnd.NextDouble() - 0.5) * 2 * spread * (k == 0 ? 0.3f : 1f), tilt = (float)(rnd.NextDouble() - 0.5) * spread * 1.6f;
            var path = new List<PointF>();
            for (int i = i0; i <= i1; i++)
            {
                var A = d[Math.Max(0, i - 1)]; var B = d[Math.Min(n - 1, i + 1)];
                float tx = B.X - A.X, ty = B.Y - A.Y, tl = (float)Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-4f) continue;
                float u = (float)(i - i0) / Math.Max(1, i1 - i0), side = off + tilt * (u - 0.5f);
                path.Add(new PointF(d[i].X - ty / tl * side, d[i].Y + tx / tl * side));
            }
            if (path.Count < 2) continue;
            var p0 = path[0]; var p1 = path[1]; float l0 = Math.Max(1e-3f, D(p0, p1)), o0 = 3 + 14 * (float)rnd.NextDouble();
            path.Insert(0, new PointF(p0.X + (p0.X - p1.X) / l0 * o0, p0.Y + (p0.Y - p1.Y) / l0 * o0));
            var z0 = path[path.Count - 1]; var z1 = path[path.Count - 2]; float lz = Math.Max(1e-3f, D(z0, z1)), oz = 3 + 14 * (float)rnd.NextDouble();
            var zE = new PointF(z0.X + (z0.X - z1.X) / lz * oz, z0.Y + (z0.Y - z1.Y) / lz * oz); path.Add(zE);
            if (rnd.NextDouble() < 0.25) { float hx = (z0.X - z1.X) / lz, hy = (z0.Y - z1.Y) / lz; path.Add(new PointF(zE.X - hy * 7 - hx * 4, zE.Y + hx * 7 - hy * 4)); }
            float wd = k == 0 ? width : width * (0.45f + 0.35f * (float)rnd.NextDouble());
            Ribbon(g, path.ToArray(), wd, wd * 0.35f, 2f, Lead(weight * (k == 0 ? 1f : 0.7f), rnd));
        }
    }
    public static void Loose(Graphics g, PointF a, PointF b, float weight, float width, Random rnd, int passes, float spread)
    { LoosePath(g, new PointF[] { a, b }, weight, width, rnd, passes, spread); }

    // A line made only of scratches: short strokes laid along the path, overlapping, each a little off it and
    // tilted, a few doubling back; `passes` layers. Never one continuous stroke: the edge is where the
    // scratches pile up.
    public static void ScratchPath(Graphics g, PointF[] pts, float weight, float width, Random rnd, int passes, float spread, float minLen, float maxLen)
    {
        var d = Densify(pts, 3f); int n = d.Length; if (n < 2) return;
        var s = new float[n]; for (int i = 1; i < n; i++) s[i] = s[i - 1] + D(d[i - 1], d[i]);
        float total = s[n - 1]; if (total < 2) return;
        for (int pass = 0; pass < passes; pass++)
        {
            float pos = -maxLen * 0.3f * (float)rnd.NextDouble();
            while (pos < total)
            {
                float L = minLen + (float)rnd.NextDouble() * (maxLen - minLen);
                float a0 = Math.Max(-6, pos), a1 = Math.Min(total + 10, pos + L);
                if (a1 - a0 > 4)
                {
                    float off = (float)(rnd.NextDouble() - 0.5) * 2 * spread, tilt = (float)(rnd.NextDouble() - 0.5) * spread * 1.4f;
                    var sub = new List<PointF>(); int m = Math.Max(3, (int)((a1 - a0) / 6));
                    for (int k = 0; k <= m; k++)
                    {
                        PointF p, tan; At(d, s, a0 + (a1 - a0) * k / m, out p, out tan);
                        float u = (float)k / m, side = off + tilt * (u - 0.5f);
                        sub.Add(new PointF(p.X - tan.Y * side, p.Y + tan.X * side));
                    }
                    if (rnd.NextDouble() < 0.18 && sub.Count > 3)
                    {   // doubling back: a short return leg just beside the stroke
                        var z = sub[sub.Count - 1]; var y0 = sub[sub.Count - 3]; float lz = Math.Max(1e-3f, D(z, y0)), bx = (y0.X - z.X) / lz, by = (y0.Y - z.Y) / lz;
                        float back = Math.Min(L * 0.5f, 10 + 25 * (float)rnd.NextDouble()), side2 = 2.5f + 2.5f * (float)rnd.NextDouble();
                        sub.Add(new PointF(z.X + bx * back - by * side2, z.Y + by * back + bx * side2));
                    }
                    float wd = width * (0.6f + 0.6f * (float)rnd.NextDouble());
                    Ribbon(g, sub.ToArray(), wd, wd * 0.2f, 1.4f, Lead(weight * (pass == 0 ? 1f : 0.75f), rnd));
                }
                pos += L * (0.5f + 0.35f * (float)rnd.NextDouble());
            }
        }
    }
    static void At(PointF[] d, float[] s, float at, out PointF p, out PointF tan)
    {
        int n = d.Length;
        if (at <= 0) { tan = UnitDir(d[0], d[1]); p = new PointF(d[0].X + tan.X * at, d[0].Y + tan.Y * at); return; }
        if (at >= s[n - 1]) { tan = UnitDir(d[n - 2], d[n - 1]); float e = at - s[n - 1]; p = new PointF(d[n - 1].X + tan.X * e, d[n - 1].Y + tan.Y * e); return; }
        int lo = 0, hi = n - 1; while (hi - lo > 1) { int mid = (lo + hi) / 2; if (s[mid] <= at) lo = mid; else hi = mid; }
        float f = (at - s[lo]) / Math.Max(1e-4f, s[hi] - s[lo]);
        p = new PointF(d[lo].X + (d[hi].X - d[lo].X) * f, d[lo].Y + (d[hi].Y - d[lo].Y) * f); tan = UnitDir(d[lo], d[hi]);
    }
    static PointF UnitDir(PointF a, PointF b) { float l = Math.Max(1e-4f, D(a, b)); return new PointF((b.X - a.X) / l, (b.Y - a.Y) / l); }

    // A tapered stroke: thin at both ends, the pressure a little before the middle (the user's style references:
    // every stroke tapered, none of uniform width).
    public static void Hair(Graphics g, PointF[] path, float width, Color col)
    {
        var d = Densify(path, 3f); int n = d.Length; if (n < 2) return;
        float total = 0; var s = new float[n]; for (int i = 1; i < n; i++) { total += D(d[i - 1], d[i]); s[i] = total; }
        if (total < 1.5f) return;
        var L = new PointF[n]; var R = new PointF[n];
        for (int i = 0; i < n; i++)
        {
            var A = d[Math.Max(0, i - 1)]; var B = d[Math.Min(n - 1, i + 1)];
            float tx = B.X - A.X, ty = B.Y - A.Y, tl = (float)Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-4f) { tx = 1; ty = 0; tl = 1; }
            float nx = -ty / tl, ny = tx / tl, t = s[i] / total;
            float prof = (float)Math.Pow(Math.Sin(Math.PI * Math.Pow(t, 0.85)), 0.7);
            float w = width * (0.1f + 0.9f * prof) / 2f;
            L[i] = new PointF(d[i].X + nx * w, d[i].Y + ny * w); R[n - 1 - i] = new PointF(d[i].X - nx * w, d[i].Y - ny * w);
        }
        var poly = new PointF[2 * n]; Array.Copy(L, poly, n); Array.Copy(R, 0, poly, n, n);
        foreach (var q in poly) if (float.IsNaN(q.X) || float.IsNaN(q.Y) || Math.Abs(q.X) > 1e5 || Math.Abs(q.Y) > 1e5) return;
        using (var b = new SolidBrush(col)) g.FillPolygon(b, poly);
    }

    // Convex hull (monotone chain).
    public static PointF[] Hull(PointF[] pts)
    {
        var p = new List<PointF>(pts); p.Sort((a, b) => a.X != b.X ? a.X.CompareTo(b.X) : a.Y.CompareTo(b.Y));
        if (p.Count < 3) return p.ToArray();
        var h = new List<PointF>();
        Func<PointF, PointF, PointF, float> cr = (o, a, b) => (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X);
        foreach (var q in p) { while (h.Count >= 2 && cr(h[h.Count - 2], h[h.Count - 1], q) <= 0) h.RemoveAt(h.Count - 1); h.Add(q); }
        int lower = h.Count + 1;
        for (int i = p.Count - 2; i >= 0; i--) { var q = p[i]; while (h.Count >= lower && cr(h[h.Count - 2], h[h.Count - 1], q) <= 0) h.RemoveAt(h.Count - 1); h.Add(q); }
        h.RemoveAt(h.Count - 1);
        return h.ToArray();
    }
}
