// The fist impact frame (design/cutscene-study/15-drawing-techniques-study.md).
// Construction: one perspective for everything, three vanishing points (two on a high horizon, one far below).
// The torso is the measuring box: every point of the head, arms, fist and dent is measured in torso units
// (x right, y up, z back; the torso's half sizes 1, 1, 0.5) along the lines to those vanishing points.
// Pose: the target's Fold clip at the final punch (animations/build_strikes.luau FOLD_KEYS): folded onto the
// fist, both arms flung forward and down past it, the head dropped ~14 deg. The chest caves in round the fist
// (everything drawn in toward the contact, deeper frame by frame); the fist barely moves.
// Style (the user's sketch references: zpicyowl, Kopinski, the ink sketches): no traced outlines. Edges are a
// few thin searching lines, lost on the lit side, with dark accents only where forms overlap or press together.
// Tone is shadow only: lit planes stay paper; shadow shapes are hatched with tapered strokes laid along the
// surface (round the dent they follow its rings), denser toward the darkest spot, a second layer at a small
// angle for the darks. White fills only hide what is behind a nearer form.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

public struct V3
{
    public double X, Y, Z;
    public V3(double x, double y, double z) { X = x; Y = y; Z = z; }
    public static V3 operator +(V3 a, V3 b) { return new V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z); }
    public static V3 operator -(V3 a, V3 b) { return new V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z); }
    public static V3 operator *(V3 a, double k) { return new V3(a.X * k, a.Y * k, a.Z * k); }
    public static double Dot(V3 a, V3 b) { return a.X * b.X + a.Y * b.Y + a.Z * b.Z; }
    public static V3 Cross(V3 a, V3 b) { return new V3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X); }
    public V3 Unit() { double l = Math.Sqrt(Dot(this, this)); return new V3(X / l, Y / l, Z / l); }
}

public class Plunge
{
    // ---- the perspective ----
    static readonly PointF VL0 = new PointF(-2400, -500), VR0 = new PointF(2050, -500), VD0 = new PointF(620, 3600), T00 = new PointF(950, 160);
    static readonly double WX = 0.26 / (2 * 0.74), WZ = 0.27 / 0.73, WD = 0.25 / (2 * 0.75);
    public static double Zs = 1, Zdy = 0;                     // framing: as the earlier frames (the torso's middle the focus)
    public static double HX = 0.06, HY = 0.14;                // the contact on the chest
    public static double FH = 0.32;                            // the fist's half size
    static readonly V3 Light = new V3(0.35, 0.8, -0.5).Unit();

    public static PointF Fr(double x, double y) { return new PointF((float)(640 + (x - 640) * Zs), (float)(360 + (y - 360) * Zs + Zdy)); }
    public static PointF VP(int which) { var p = which == 0 ? VL0 : which == 1 ? VR0 : VD0; return Fr(p.X, p.Y); }
    public static PointF TP(V3 v)
    {
        double dx = v.X + 1, dz = v.Z + 0.5, dd = 1 - v.Y, den = 1 + dx * WX + dd * WD + dz * WZ; if (den < 0.05) den = 0.05;
        return Fr((T00.X + dx * WX * VL0.X + dd * WD * VD0.X + dz * WZ * VR0.X) / den, (T00.Y + dx * WX * VL0.Y + dd * WD * VD0.Y + dz * WZ * VR0.Y) / den);
    }
    // The eye: the one point the construction can't map. A face is seen when it turns toward it.
    public static V3 Eye()
    {
        double[,] m = { { WX * VL0.X, -WD * VD0.X, WZ * VR0.X }, { WX * VL0.Y, -WD * VD0.Y, WZ * VR0.Y }, { WX, -WD, WZ } };
        double[] rhs = { -(T00.X + WX * VL0.X + WD * VD0.X + 0.5 * WZ * VR0.X), -(T00.Y + WX * VL0.Y + WD * VD0.Y + 0.5 * WZ * VR0.Y), -(1 + WX + WD + 0.5 * WZ) };
        double d = Det(m); var r = new double[3];
        for (int c = 0; c < 3; c++) { var mc = (double[,])m.Clone(); for (int k = 0; k < 3; k++) mc[k, c] = rhs[k]; r[c] = Det(mc) / d; }
        return new V3(r[0], r[1], r[2]);
    }
    static double Det(double[,] m) { return m[0, 0] * (m[1, 1] * m[2, 2] - m[1, 2] * m[2, 1]) - m[0, 1] * (m[1, 0] * m[2, 2] - m[1, 2] * m[2, 0]) + m[0, 2] * (m[1, 0] * m[2, 1] - m[1, 1] * m[2, 0]); }
    public static string Info()
    {
        var e = Eye(); var t = new Plunge(); t.eye = e;
        return string.Format("eye {0:0.00} {1:0.00} {2:0.00}; chest seen {3}, side seen {4}, top seen {5}", e.X, e.Y, e.Z,
            t.Seen(new V3(0, 0, -0.5), new V3(0, 0, -1)), t.Seen(new V3(-1, 0, 0), new V3(-1, 0, 0)), t.Seen(new V3(0, 1, 0), new V3(0, 1, 0)));
    }

    // ---- the frame's state ----
    double DD, DW, E; V3 eye; Random rnd; Graphics g;

    // The cave-in: every point of the torso drawn in toward the contact on the page, most near it, so lines
    // bow inward and the rings close up round the fist; it fades toward the back of the torso.
    PointF DP(V3 v)
    {
        var p = TP(v); var c = TP(new V3(HX, HY, -0.5));
        double zf = Math.Exp(-Math.Pow((v.Z + 0.5) / 0.7, 2));
        return Pn.Pull(p, c.X, c.Y, (float)(DD * zf), (float)DW);
    }
    bool Seen(V3 p, V3 n) { return V3.Dot(n, eye - p) > 0; }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }
    static double Clamp01(double x) { return x < 0 ? 0 : x > 1 ? 1 : x; }
    float R01() { return (float)rnd.NextDouble(); }
    static float Ang(PointF a, PointF b) { return (float)(Math.Atan2(b.Y - a.Y, b.X - a.X) * 180 / Math.PI); }
    static PointF Toward(PointF p, PointF vp, float len) { float l = Math.Max(1e-3f, Pn.D(p, vp)); return new PointF(p.X + (vp.X - p.X) / l * len, p.Y + (vp.Y - p.Y) / l * len); }
    PointF[] Line3(V3 a, V3 b, int n, Func<V3, PointF> proj) { var o = new PointF[n + 1]; for (int k = 0; k <= n; k++) o[k] = proj(a + (b - a) * ((double)k / n)); return o; }

    // ---- marks ----
    void Hair(PointF[] path, float width, double weight)
    {
        if (weight < 0.04 || path.Length < 2) return;
        Pn.Hair(g, path, width, Pn.Graphite((float)Math.Min(1, weight)));
    }

    // A searching line: thin tapered strokes, long and overlapping, a little off the path, the weight following
    // weightAt(u) along it (lost where it fades out), `passes` layers, the ends running past.
    void Search(PointF[] pts, Func<double, double> weightAt, float width, int passes)
    {
        var d = Pn.Densify(pts, 4f); int n = d.Length; if (n < 2) return;
        var s = new float[n]; for (int i = 1; i < n; i++) s[i] = s[i - 1] + Pn.D(d[i - 1], d[i]);
        float total = s[n - 1]; if (total < 3) return;
        for (int pass = 0; pass < passes; pass++)
        {
            float pos = -16 * R01();
            while (pos < total)
            {
                float L = 50 + 150 * R01(), a0 = pos, a1 = Math.Min(total + 14 * R01(), pos + L);
                float off = (R01() - 0.5f) * (pass == 0 ? 2.4f : 4.5f), tilt = (R01() - 0.5f) * 3f;
                var sub = new List<PointF>(); int m = Math.Max(3, (int)((a1 - a0) / 6));
                for (int k = 0; k <= m; k++)
                {
                    PointF p, tan; At(d, s, a0 + (a1 - a0) * k / m, out p, out tan);
                    float side = off + tilt * ((float)k / m - 0.5f);
                    sub.Add(new PointF(p.X - tan.Y * side, p.Y + tan.X * side));
                }
                double wgt = weightAt(Clamp01((a0 + a1) / 2 / total)) * (0.75 + 0.5 * R01()) * (pass == 0 ? 1 : 0.7);
                Hair(sub.ToArray(), width * (1.1f + 0.45f * R01()), wgt * 1.3);
                pos += L * (0.75f + 0.35f * R01());
            }
        }
    }
    void Search(PointF[] pts, double weight, float width, int passes) { Search(pts, u => weight, width, passes); }
    static void At(PointF[] d, float[] s, float at, out PointF p, out PointF tan)
    {
        int n = d.Length;
        if (at <= 0) { tan = Unit(d[0], d[1]); p = new PointF(d[0].X + tan.X * at, d[0].Y + tan.Y * at); return; }
        if (at >= s[n - 1]) { tan = Unit(d[n - 2], d[n - 1]); float e = at - s[n - 1]; p = new PointF(d[n - 1].X + tan.X * e, d[n - 1].Y + tan.Y * e); return; }
        int lo = 0, hi = n - 1; while (hi - lo > 1) { int mid = (lo + hi) / 2; if (s[mid] <= at) lo = mid; else hi = mid; }
        float f = (at - s[lo]) / Math.Max(1e-4f, s[hi] - s[lo]);
        p = new PointF(d[lo].X + (d[hi].X - d[lo].X) * f, d[lo].Y + (d[hi].Y - d[lo].Y) * f); tan = Unit(d[lo], d[hi]);
    }
    static PointF Unit(PointF a, PointF b) { float l = Math.Max(1e-4f, Pn.D(a, b)); return new PointF((b.X - a.X) / l, (b.Y - a.Y) / l); }

    // Shadow hatching on a surface given as (u, v) in [0,1]^2: strokes placed where it is dark (more of them,
    // and darker, the darker it is), each laid along the surface's own direction field, then projected; the
    // darkest parts get a second layer turned a little.
    delegate void Field(double u, double v, out double du, out double dv);
    void Shade(Func<double, double, V3> pos, Func<V3, PointF> proj, Func<double, double, double> dark, Field dir, Func<double, double, bool> ok,
               double lenUV, float spacing, float width)
    {
        double area = 0; int G = 8;
        for (int a = 0; a < G; a++) for (int b = 0; b < G; b++)
            {
                var p0 = proj(pos((double)a / G, (double)b / G)); var p1 = proj(pos((a + 1.0) / G, (double)b / G));
                var p2 = proj(pos((a + 1.0) / G, (b + 1.0) / G)); var p3 = proj(pos((double)a / G, (b + 1.0) / G));
                area += Math.Abs((p0.X * p1.Y - p1.X * p0.Y) + (p1.X * p2.Y - p2.X * p1.Y) + (p2.X * p3.Y - p3.X * p2.Y) + (p3.X * p0.Y - p0.X * p3.Y)) / 2;
            }
        var c0 = proj(pos(0.45, 0.5)); var c1 = proj(pos(0.55, 0.5)); var c2 = proj(pos(0.5, 0.45)); var c3 = proj(pos(0.5, 0.55));
        double lenPx = Math.Max(20, lenUV * 10 * (Pn.D(c0, c1) + Pn.D(c2, c3)) / 2);
        int n = (int)Math.Min(20000, area / (spacing * lenPx));
        for (int k = 0; k < n; k++)
        {
            double u = R01(), v = R01();
            if (ok != null && !ok(u, v)) continue;
            double d = dark(u, v); if (d <= 0.02 || R01() > d) continue;
            StrokeAt(pos, proj, dir, ok, u, v, lenUV * (0.6 + 0.8 * R01()), width, d, 0);
            if (d > 0.5 && R01() < (d - 0.5) * 1.6) StrokeAt(pos, proj, dir, ok, u, v, lenUV * (0.5 + 0.6 * R01()), width, d * 0.9, 0.42);
        }
    }
    void StrokeAt(Func<double, double, V3> pos, Func<V3, PointF> proj, Field dir, Func<double, double, bool> ok, double u, double v, double len, float width, double d, double rot)
    {
        var fwd = new List<PointF>(); var back = new List<PointF>();
        double cs = Math.Cos(rot), sn = Math.Sin(rot), bend = (R01() - 0.5) * 0.25;
        for (int side = 0; side < 2; side++)
        {
            double cu = u, cv = v, sg = side == 0 ? 1 : -1;
            for (int k = 0; k < 5; k++)
            {
                double du, dv; dir(cu, cv, out du, out dv);
                double ru = du * cs - dv * sn, rv = du * sn + dv * cs, l = Math.Sqrt(ru * ru + rv * rv); if (l < 1e-9) break;
                ru /= l; rv /= l; double b = bend * k / 5.0; double tu = ru - rv * b, tv = rv + ru * b;
                cu += tu * sg * len / 10; cv += tv * sg * len / 10;
                if (cu < -0.02 || cu > 1.02 || cv < -0.02 || cv > 1.02 || (ok != null && !ok(Clamp01(cu), Clamp01(cv)))) break;
                (side == 0 ? fwd : back).Add(proj(pos(cu, cv)));
            }
        }
        back.Reverse(); back.Add(proj(pos(u, v))); back.AddRange(fwd);
        if (back.Count < 2) return;
        Hair(back.ToArray(), width * (0.75f + 0.5f * R01()), (0.3 + 0.7 * d) * (0.85 + 0.3 * R01()));
    }

    // Hatching in ROWS (Kopinski, zpicyowl): parallel strokes laid along the surface - rows of constant t running
    // along s - evenly spaced on the page. A row's strokes run while the surface is dark enough and stop at the
    // shadow shape's edge (each row at its own threshold, so the edge is ragged); the pen lifts every 40-110 px;
    // light tones get fewer strokes; darker parts also get the rows in between.
    void Rows(Func<double, double, V3> pos, Func<V3, PointF> proj, Func<double, double, double> dark,
              double s0, double s1, double t0, double t1, float spacing, float width)
    {
        double span = 0;
        foreach (double sf in new[] { 0.2, 0.5, 0.8 }) { double s = s0 + (s1 - s0) * sf; span = Math.Max(span, Pn.D(proj(pos(s, t0)), proj(pos(s, t1)))); }
        int rows = Math.Max(2, (int)Math.Ceiling(span / (spacing * 0.5)));
        double rowLen = 0; { double tm = (t0 + t1) / 2; var pp = proj(pos(s0, tm)); for (int k = 1; k <= 24; k++) { var p = proj(pos(s0 + (s1 - s0) * k / 24.0, tm)); rowLen += Pn.D(pp, p); pp = p; } }
        int steps = Math.Max(8, Math.Min(900, (int)(rowLen / 4)));
        for (int r = 0; r <= rows; r++)
        {
            bool extra = (r % 2) == 1;
            double t = t0 + (t1 - t0) * Math.Max(0, Math.Min(1, (r + (R01() - 0.5) * 0.45) / rows));
            double thr = (extra ? 0.56 : 0.1) + 0.1 * R01();
            var cur = new List<PointF>(); double sumD = 0; float curLen = 0, lift = 50 + 90 * R01(), tilt = (R01() - 0.5f) * 0.07f; int skipTo = -1;
            PointF prevRaw = PointF.Empty;
            Action flush = () =>
            {
                if (cur.Count > 1) Hair(cur.ToArray(), width * (0.85f + 0.35f * R01()), (0.32 + 0.68 * sumD / cur.Count) * (0.85 + 0.3 * R01()));
                cur.Clear(); sumD = 0; curLen = 0; lift = 50 + 90 * R01(); tilt = (R01() - 0.5f) * 0.07f;
            };
            for (int k = 0; k <= steps; k++)
            {
                if (k < skipTo) continue;
                double s = s0 + (s1 - s0) * k / steps, d = dark(s, t);
                if (d < thr) { flush(); continue; }
                if (cur.Count == 0 && R01() > Math.Min(1, 0.25 + 1.4 * d)) { skipTo = k + 6 + rnd.Next(14); continue; }   // light tones: fewer strokes
                var raw = proj(pos(s, t));
                if (cur.Count > 0)
                {
                    float seg = Pn.D(prevRaw, raw); curLen += seg;
                    float tx = (raw.X - prevRaw.X) / Math.Max(1e-3f, seg), ty = (raw.Y - prevRaw.Y) / Math.Max(1e-3f, seg), off = tilt * curLen;   // the hand drifts off true
                    cur.Add(new PointF(raw.X - ty * off, raw.Y + tx * off));
                }
                else cur.Add(raw);
                prevRaw = raw; sumD += d;
                if (curLen > lift) { flush(); skipTo = k - 1 - rnd.Next(3); }                                         // the pen lifts; the next stroke overlaps
            }
            flush();
        }
    }

    public static Img Render(int i, int frames, int seed) { return new Plunge().Run(i, frames, seed); }

    Img Run(int i, int frames, int seed)
    {
        rnd = new Random(seed + 31 * i); eye = Eye();
        double t = frames > 1 ? (double)i / (frames - 1) : 1, e = 1 - (1 - t) * (1 - t); E = e;
        double tp = frames > 1 ? Math.Max(0, (double)(i - 1) / (frames - 1)) : 1, ep = 1 - (1 - tp) * (1 - tp);
        DD = 0.5 + 0.47 * e; DW = 210 + 80 * e;                 // the cave-in: deeper than before (0.9 -> 0.97), widening
        var bmp = new Bitmap(1280, 720);
        g = Graphics.FromImage(bmp); g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(Color.White);
        Background(); Construction();
        // the Fold pose, from the contact key toward the soak key
        var right = Arm(1, Lerp(22, 26, e), Lerp(-25, -35, e)); var rightPrev = Arm(1, Lerp(22, 26, ep), Lerp(-25, -35, ep));
        var left = Arm(-1, Lerp(18, 22, e), Lerp(-30, -38, e)); var leftPrev = Arm(-1, Lerp(18, 22, ep), Lerp(-30, -38, ep));
        right.Lag = (rightPrev.Dir - right.Dir) * 0.6; left.Lag = (leftPrev.Dir - left.Dir) * 0.6;   // the middles drag behind
        DrawBox(right, -0.5, 1.5);            // the far arm: wholly behind the torso from here (its front part lands left of the torso)
        Torso();
        Head(Lerp(9, 13.6, e));
        DrawBox(left, -0.5, 1.5);             // the near side: in front of the side face
        Motion(right, rightPrev); Motion(left, leftPrev);
        if (i >= 1 && i <= 4) Impact(i);
        Fist(-0.5 + 0.06 * e);                // the fist barely moves
        g.Dispose();
        return Pn.Paper(Img.FromBitmap(bmp), seed + i, 0.6f);
    }

    // ---- background and construction: a few long light strokes, the lines to the vanishing points ----
    void Background()
    {
        for (int k = 0; k < 26; k++)
        {
            var p = new PointF(-120 + 1500 * R01(), -60 + 840 * R01()); double a = (-24 + (R01() - 0.5) * 16) * Math.PI / 180, L = 120 + 260 * R01();
            Hair(new[] { p, new PointF((float)(p.X + Math.Cos(a) * L * 0.5), (float)(p.Y + Math.Sin(a) * L * 0.5 + (R01() - 0.5) * 8)), new PointF((float)(p.X + Math.Cos(a) * L), (float)(p.Y + Math.Sin(a) * L)) }, 1.3f, 0.14 + 0.14 * R01());
        }
    }
    void Construction()
    {
        foreach (var c in new[] { new V3(1, 1, -0.5), new V3(-1, 1, -0.5), new V3(-1, 1, 0.5), new V3(-1, -1, -0.5), new V3(1, -1, -0.5) })
        {
            var p = TP(c);
            for (int w = 0; w < 3; w++) { var vp = VP(w); Hair(new[] { Toward(p, vp, -200 * R01()), Toward(p, vp, 300 + 400 * R01()) }, 1.1f, 0.1 + 0.05 * R01()); }
        }
    }

    // ---- the torso ----
    // Shadow SHAPES with edges (Kopinski): inside a shape the tone is even, darker toward its darkest spot;
    // the hatching stops at the shape's edge (a little ragged) instead of fading out.
    double ChestDark(double u, double v)
    {
        double x = 1 - 2 * u, y = 1 - 2 * v, rx = x - HX, ry = y - HY, r = Math.Sqrt(rx * rx + ry * ry);
        double box = Math.Max(Math.Abs(rx), Math.Abs(ry));
        if (box < FH * 0.9) return 0;                                                        // under the fist
        double a = Math.Atan2(ry, rx), wall = 0.5 + 0.5 * (0.4 * Math.Cos(a) + 0.916 * Math.Sin(a));
        // the dent: its upper wall faces down, so it is in shadow; its lower wall catches the light
        double rim = FH + 0.3 + 0.2 * E + 0.035 * Math.Sin(a * 5 + 1.3) + 0.025 * Math.Sin(a * 11);
        double dent = 0;
        if (r < rim)
        {
            double shade = wall > 0.44 ? 1 : wall > 0.32 ? (wall - 0.32) / 0.12 : 0, deep = 1 - Clamp01((r - FH) / (rim - FH));
            dent = shade * (0.55 + 0.4 * deep) + (1 - shade) * 0.14 * deep;
        }
        // the fist's cast shadow on the chest: a band down and away from the light
        double sx = -0.4, sy = -0.916, al = rx * sx + ry * sy, ac = -rx * sy + ry * sx, reach = FH + 0.45 + 0.25 * E;
        double cast = al > 0 && al < reach && Math.Abs(ac) < FH * 1.1 ? 0.7 - 0.2 * (al / reach) : 0;
        double contact = box - FH < 0.07 ? 0.95 : 0;                                       // pressed tight round the fist
        return Math.Min(1, Math.Max(Math.Max(dent, cast), contact));
    }
    void ChestDir(double u, double v, out double du, out double dv)
    {
        double x = 1 - 2 * u, y = 1 - 2 * v, rx = x - HX, ry = y - HY, r = Math.Max(1e-6, Math.Sqrt(rx * rx + ry * ry));
        double w = Math.Exp(-Math.Pow(Math.Max(0, r - 0.35) / 0.45, 2));
        double tx = -ry / r, ty = rx / r; if (tx < 0) { tx = -tx; ty = -ty; }                    // round the dent ...
        double hx = tx * w + (1 - w), hy = ty * w;                                              // ... easing to across the chest
        du = -hx / 2; dv = -hy / 2;
    }

    // ---- rounded edges (Roblox parts are slightly rounded) ----
    // A fillet: the quarter-round between face A (outward normal a) and face B (normal b), running along axis k;
    // `inner(n)` is how far the flat part of the face with normal n sits from the centre.
    static V3 FilletPt(V3 c, V3 a, V3 b, V3 k, Func<V3, double> inner, double rb, double qk, double ph)
    { return c + a * inner(a) + b * inner(b) + k * qk + (a * Math.Cos(ph) + b * Math.Sin(ph)) * rb; }
    static V3 FilletN(V3 a, V3 b, double ph) { return a * Math.Cos(ph) + b * Math.Sin(ph); }
    // Where a fillet turns away from the eye: the silhouette angle (face A seen, face B hidden).
    double SilAngle(V3 c, V3 a, V3 b, V3 k, Func<V3, double> inner, double rb, double qk)
    {
        double lo = 0, hi = Math.PI / 2;
        for (int it = 0; it < 18; it++) { double mid = (lo + hi) / 2; if (Seen(FilletPt(c, a, b, k, inner, rb, qk, mid), FilletN(a, b, mid))) lo = mid; else hi = mid; }
        return (lo + hi) / 2;
    }
    static double TorsoDark(V3 n) { return Clamp01((0.32 - V3.Dot(n, Light)) / 0.3) * 0.75; }

    void Torso()
    {
        const double rb = 0.13; double ix = 1 - rb, iy = 1 - rb, iz = 0.5 - rb;
        Func<V3, double> inner = n => Math.Abs(n.X) * ix + Math.Abs(n.Y) * iy + Math.Abs(n.Z) * iz;
        V3 O = new V3(0, 0, 0), PX = new V3(1, 0, 0), NX = new V3(-1, 0, 0), PY = new V3(0, 1, 0), NY = new V3(0, -1, 0), PZ = new V3(0, 0, 1), NZ = new V3(0, 0, -1);
        Func<V3, PointF> dp = DP;
        // the silhouette: six rounded edges where a seen face turns into a hidden one, joined round the corners
        var loopEdges = new[] {   // seen face, hidden face, along, from, to
            new { a = NZ, b = PX, k = PY, q0 = iy, q1 = -iy }, new { a = NZ, b = NY, k = PX, q0 = ix, q1 = -ix },
            new { a = NX, b = NY, k = PZ, q0 = -iz, q1 = iz }, new { a = NX, b = PZ, k = PY, q0 = -iy, q1 = iy },
            new { a = PY, b = PZ, k = PX, q0 = -ix, q1 = ix }, new { a = PY, b = PX, k = PZ, q0 = iz, q1 = -iz } };
        var loop3 = new List<List<V3>>();
        for (int e = 0; e < 6; e++)
        {
            var ed = loopEdges[e]; var run = new List<V3>();
            for (int k = 0; k <= 30; k++) { double q = Lerp(ed.q0, ed.q1, k / 30.0); run.Add(FilletPt(O, ed.a, ed.b, ed.k, inner, rb, q, SilAngle(O, ed.a, ed.b, ed.k, inner, rb, q))); }
            loop3.Add(run);
        }
        var sil = new List<List<PointF>>();
        for (int e = 0; e < 6; e++)
        {
            var cur = loop3[e]; var nxt = loop3[(e + 1) % 6]; var pts = new List<PointF>(); foreach (var p in cur) pts.Add(DP(p));
            V3 p0 = cur[cur.Count - 1], p2 = nxt[0];
            var cc = new V3(Math.Sign(p0.X) * ix, Math.Sign(p0.Y) * iy, Math.Sign(p0.Z) * iz);               // the corner's centre
            var dir = ((p0 - cc) + (p2 - cc)).Unit(); var c1 = cc + dir * (rb * 1.3);
            for (int k = 1; k < 8; k++) { double t = k / 8.0; pts.Add(DP(p0 * ((1 - t) * (1 - t)) + c1 * (2 * t * (1 - t)) + p2 * (t * t))); }
            sil.Add(pts);
        }
        var fill = new List<PointF>(); foreach (var s in sil) fill.AddRange(s);
        g.FillPolygon(Brushes.White, fill.ToArray());
        // the rounded edges' tone: graded across each round, from one face's value to the other's
        var fillets = new[] {
            new { a = NZ, b = NX, k = PY, n = (double)iy }, new { a = NZ, b = PY, k = PX, n = ix }, new { a = NX, b = PY, k = PZ, n = iz },
            new { a = NZ, b = PX, k = PY, n = iy }, new { a = NZ, b = NY, k = PX, n = ix }, new { a = NX, b = NY, k = PZ, n = iz },
            new { a = NX, b = PZ, k = PY, n = iy }, new { a = PY, b = PZ, k = PX, n = ix }, new { a = PY, b = PX, k = PZ, n = iz } };
        foreach (var f in fillets)
        {
            var fa = f.a; var fb = f.b; var fk = f.k; double fn = f.n;
            Rows((s, t) => FilletPt(O, fa, fb, fk, inner, rb, Lerp(-fn - rb * 0.9, fn + rb * 0.9, s), t * Math.PI / 2), dp, (s, t) =>
            {
                var p = FilletPt(O, fa, fb, fk, inner, rb, Lerp(-fn - rb * 0.9, fn + rb * 0.9, s), t * Math.PI / 2); var n = FilletN(fa, fb, t * Math.PI / 2);
                return Seen(p, n) ? TorsoDark(n) : 0;
            }, 0, 1, 0, 1, 4.4f, 1.5f);
        }
        // where two seen faces meet the edge is soft: one light line along the middle of the round
        foreach (var f in new[] { fillets[0], fillets[1], fillets[2] })
            Search(Line3(FilletPt(O, f.a, f.b, f.k, inner, rb, -f.n * 0.92, Math.PI / 4), FilletPt(O, f.a, f.b, f.k, inner, rb, f.n * 0.92, Math.PI / 4), 40, dp), 0.3, 1.4f, 1);
        // shadow shapes, hatched in rows: the dent's shadowed wall in rings round the fist (contour hatching),
        // the fist's cast shadow across the chest, the side face down its height, the head's shadow on the top
        Rows((a, r) => new V3(HX + r * Math.Cos(a), HY + r * Math.Sin(a), -0.5), dp, (a, r) =>
        {
            double x = HX + r * Math.Cos(a), y = HY + r * Math.Sin(a); if (Math.Abs(x) > ix || Math.Abs(y) > iy) return 0;
            return ChestDark((1 - x) / 2, (1 - y) / 2);
        }, 0, 2 * Math.PI, FH * 0.9, 1.1, 4.2f, 1.6f);
        Rows((s, t) => new V3(ix * (1 - 2 * s), iy * (1 - 2 * t), -0.5), dp, (s, t) =>
        {
            double x = ix * (1 - 2 * s), y = iy * (1 - 2 * t), rx = x - HX, ry = y - HY;
            double sx = -0.4, sy = -0.916, al = rx * sx + ry * sy, ac = -rx * sy + ry * sx, reach = FH + 0.45 + 0.25 * E;
            return al > FH * 0.7 && al < reach && Math.Abs(ac) < FH * 1.1 ? 0.68 - 0.2 * (al / reach) : 0;
        }, 0, 1, 0, 1, 4.6f, 1.6f);
        Rows((s, t) => new V3(-1, iy * (1 - 2 * s), iz * (2 * t - 1)), dp, (s, t) => 0.6 + 0.25 * (1 - t) - 0.1 * s, 0, 1, 0, 1, 4.6f, 1.6f);
        Rows((s, t) => new V3(ix * (1 - 2 * s), 1, iz * (2 * t - 1)), dp, (s, t) =>
        {
            double px = ix * (1 - 2 * s), pz = iz * (2 * t - 1);                                  // the head's shadow, swept back and to the right
            double sx = -0.48, sz = 0.69, l2 = sx * sx + sz * sz, tt = Clamp01((px * sx + pz * sz) / l2);
            double dx = px - sx * tt, dz = pz - sz * tt;
            return Math.Sqrt(dx * dx + dz * dz) < 0.62 ? 0.62 : 0;
        }, 0, 1, 0, 1, 4.6f, 1.5f);
        // form lines: a few light cross-contours bending into the dent, and the dent's rings, found on the
        // shadowed upper wall and lost on the lit lower one
        for (int q = 1; q < 6; q++)
        {
            double y = 1 - 2.0 * q / 6;
            Search(Line3(new V3(ix, y * iy, -0.5), new V3(-ix, y * iy, -0.5), 60, dp), uu => 0.22 * Math.Max(0.15, Math.Exp(-Math.Pow((ix * (1 - 2 * uu) - HX) / 0.7, 2))), 1.2f, 1);
        }
        foreach (double rr in new[] { 0.4, 0.47, 0.56, 0.68, 0.84 })
        {
            var pts = new List<PointF>(); var ang = new List<double>();
            for (int k = 0; k <= 120; k++)
            {
                double a = 2 * Math.PI * k / 120, x = HX + rr * Math.Cos(a), y = HY + rr * Math.Sin(a);
                if (Math.Abs(x) > ix || Math.Abs(y) > iy) { RingRun(pts, ang, rr); pts = new List<PointF>(); ang = new List<double>(); continue; }
                pts.Add(DP(new V3(x, y, -0.5))); ang.Add(a);
            }
            RingRun(pts, ang, rr);
        }
        // the silhouette, rounded at the corners: firmer on the shadow side, lighter where it's lit
        double[] silW = { 0.5, 0.5, 0.7, 0.75, 0.38, 0.34 };
        for (int e = 0; e < 6; e++) Search(sil[e].ToArray(), silW[e], 1.65f, 2);
    }
    void RingRun(List<PointF> pts, List<double> ang, double rr)
    {
        if (pts.Count < 3) return;
        var a = ang.ToArray(); int n = a.Length;
        Search(pts.ToArray(), uu =>
        {
            double an = a[Math.Min(n - 1, (int)(uu * (n - 1)))], wall = 0.5 + 0.5 * (0.4 * Math.Cos(an) + 0.916 * Math.Sin(an));
            return (0.15 + 0.75 * wall) * (1.15 - 0.6 * (rr - 0.4));
        }, 1.3f, 1);
    }

    // ---- the head: a Roblox head, a rounded cylinder, dropped forward ----
    void Head(double pitch)
    {
        double pt = pitch * Math.PI / 180;
        V3 up = new V3(0, Math.Cos(pt), -Math.Sin(pt)), fw = new V3(0, -Math.Sin(pt), -Math.Cos(pt)), xr = new V3(1, 0, 0), neck = new V3(0, 1, 0);
        const double R = 0.62, Hh = 1.22, bev = 0.15;
        Func<double, double, double, V3> at = (h, rad, th) => neck + up * h + (xr * Math.Cos(th) + fw * Math.Sin(th)) * rad;
        Func<double, V3> nrm = th => xr * Math.Cos(th) + fw * Math.Sin(th);
        var hull = new List<PointF>();
        for (int k = 0; k < 72; k++) { double th = 2 * Math.PI * k / 72; hull.Add(TP(at(0, R - bev, th))); hull.Add(TP(at(bev, R, th))); hull.Add(TP(at(Hh - bev, R, th))); hull.Add(TP(at(Hh, R - bev, th))); }
        g.FillPolygon(Brushes.White, Pn.Hull(hull.ToArray()));
        // its form shadow: the side away from the light, hatched round the cylinder
        Func<V3, PointF> tp = TP;
        Rows((s, t) => at(bev + (Hh - 2 * bev) * t, R, 2 * Math.PI * s), tp, (s, t) =>
        {
            double th = 2 * Math.PI * s; if (!Seen(at(0.6, R, th), nrm(th))) return 0;
            return Clamp01((0.12 - V3.Dot(nrm(th), Light)) / 0.14) * 0.72 + (t < 0.15 ? 0.2 : 0);
        }, 0, 1, 0, 1, 4.4f, 1.5f);
        // the rims, thin; the chin where it hangs over the chest, dark; the sides where the surface turns away
        Ring(at, nrm, up, 0, R - bev, -1, th => V3.Dot(nrm(th), new V3(0, 0, -1)) > 0.2 ? 0.95 : 0.45, 1.9f);
        Ring(at, nrm, up, bev, R, 0, th => 0.2, 1.2f);
        Ring(at, nrm, up, Hh - bev, R, 0, th => 0.22, 1.2f); Ring(at, nrm, up, Hh, R - bev, 1, th => 0.3, 1.3f);
        bool prev = Seen(at(0.6, R, 0), nrm(0));
        for (int k = 1; k <= 180; k++)
        {
            double th = 2 * Math.PI * k / 180; bool now = Seen(at(0.6, R, th), nrm(th));
            if (now != prev) Search(new[] { TP(at(bev * 0.5, R - bev * 0.4, th)), TP(at(Hh - bev * 0.5, R - bev * 0.4, th)) }, V3.Dot(nrm(th), Light) < 0 ? 0.75 : 0.42, 1.6f, 2);
            prev = now;
        }
    }
    void Ring(Func<double, double, double, V3> at, Func<double, V3> nrm, V3 up, double h, double rad, int lip, Func<double, double> weightAt, float width)
    {
        var run = new List<PointF>(); var ths = new List<double>();
        Action flush = () =>
        {
            if (run.Count > 2) { var a = ths.ToArray(); int n = a.Length; Search(run.ToArray(), uu => weightAt(a[Math.Min(n - 1, (int)(uu * (n - 1)))]), width, 2); }
            run.Clear(); ths.Clear();
        };
        for (int k = 0; k <= 120; k++)
        {
            double th = 2 * Math.PI * k / 120; var n = nrm(th); if (lip != 0) n = (n * 0.6 + up * (0.8 * lip)).Unit();
            var p = at(h, rad, th);
            if (Seen(p, n)) { run.Add(TP(p)); ths.Add(th); } else flush();
        }
        flush();
    }

    // ---- the arms: R6 blocks (1 x 2 x 1) hung from the shoulders, aimed as the Fold clip aims them ----
    class Box { public V3 Pv, Dir, B, C, Lag; }
    Box Arm(int side, double sweep, double lift)
    {
        double s = sweep * Math.PI / 180, l = lift * Math.PI / 180;
        var dir = new V3(side * Math.Sin(s) * Math.Cos(l), Math.Sin(l), -Math.Cos(s) * Math.Cos(l));
        var bx = new V3(1, 0, 0); bx = (bx - dir * V3.Dot(bx, dir)).Unit();
        return new Box { Pv = new V3(side * 1.5, 0.5, 0), Dir = dir, B = bx, C = V3.Cross(dir, bx), Lag = new V3(0, 0, 0) };
    }
    V3 BoxPt(Box b, double s, double eb, double ec) { return b.Pv + b.Dir * s + b.B * eb + b.C * ec + b.Lag * Math.Sin(Math.PI * (s + 0.5) / 2); }
    // A rounded box drawn in marks (Roblox parts are slightly rounded): centre C, unit axes A, half sizes H, edge
    // radius Rb. Axis 0 may be cut to [Lo, Hi] (the part of an arm hidden behind the torso) and bowed by Lag
    // (the arm's middle dragging behind as it swings).
    class RB { public V3 C; public V3[] A; public double[] H; public double Rb, Lo, Hi; public V3 Lag; }
    V3 RS(RB b, double q0, double q1, double q2, double n0, double n1, double n2)
    {
        double a0 = Math.Max(b.Lo, Math.Min(b.Hi, q0 + n0 * b.Rb));
        var p = b.C + b.A[0] * a0 + b.A[1] * (q1 + n1 * b.Rb) + b.A[2] * (q2 + n2 * b.Rb);
        return p + b.Lag * Math.Sin(Math.PI * (a0 + b.H[0]) / (2 * b.H[0]));
    }
    V3 RN(RB b, double n0, double n1, double n2) { return (b.A[0] * n0 + b.A[1] * n1 + b.A[2] * n2).Unit(); }

    void DrawRB(RB b, Func<V3, double> darkN, double silW, float silWidth, bool gap, bool contact)
    {
        double rb = b.Rb; var inner = new[] { b.H[0] - rb, b.H[1] - rb, b.H[2] - rb };
        double lo0 = Math.Max(-inner[0], b.Lo), hi0 = Math.Min(inner[0], b.Hi);
        bool endLo = b.Lo <= -inner[0] + 1e-6, endHi = b.Hi >= inner[0] - 1e-6;
        Func<int, double, double> span = (ax, u) => ax == 0 ? Lerp(lo0, hi0, u) : Lerp(-inner[ax], inner[ax], u);
        // the rounded edges run on through the round corners (rb past the flat faces), so the corners are toned too
        Func<int, double> qmin = ax => ax == 0 ? (endLo ? lo0 - rb * 0.9 : lo0) : -inner[ax] - rb * 0.9;
        Func<int, double> qmax = ax => ax == 0 ? (endHi ? hi0 + rb * 0.9 : hi0) : inner[ax] + rb * 0.9;
        Func<V3, PointF> tp = TP;
        // the outline: the hull of the surface (the box is convex), so its corners come out round
        var pts = new List<PointF>();
        for (int k = 0; k <= 8; k++)
        {
            double q0 = Lerp(lo0, hi0, k / 8.0);
            for (int c = 0; c < 16; c++) { double ph = 2 * Math.PI * c / 16, cn = Math.Cos(ph), sn = Math.Sin(ph); pts.Add(TP(RS(b, q0, Math.Sign(cn) * inner[1], Math.Sign(sn) * inner[2], 0, cn, sn))); }
        }
        foreach (int s0 in new[] { -1, 1 })
        {
            if (s0 > 0 ? !endHi : !endLo) continue;
            double q0 = s0 > 0 ? hi0 : lo0;
            for (int a = 1; a <= 4; a++)
                for (int c = 0; c < 16; c++)
                {
                    double th = Math.PI / 2 * a / 4, ph = 2 * Math.PI * c / 16, cn = Math.Cos(ph), sn = Math.Sin(ph);
                    pts.Add(TP(RS(b, q0, Math.Sign(cn) * inner[1], Math.Sign(sn) * inner[2], s0 * Math.Sin(th), cn * Math.Cos(th), sn * Math.Cos(th))));
                }
        }
        var hull = Pn.Hull(pts.ToArray());
        if (gap) using (var pen = new Pen(Color.White, 18) { LineJoin = LineJoin.Round }) g.DrawPolygon(pen, hull);   // a sliver of paper round it
        g.FillPolygon(Brushes.White, hull);
        // the flat faces, hatched where in shade (rows along the part on its long faces)
        for (int ax = 0; ax < 3; ax++)
            for (int sg = -1; sg <= 1; sg += 2)
            {
                if (ax == 0 && (sg > 0 ? !endHi : !endLo)) continue;
                int sAx = ax == 0 ? 1 : 0, tAx = 3 - ax - sAx, axc = ax, sgc = sg;
                var nn = new double[3]; nn[ax] = sg; var nv = RN(b, nn[0], nn[1], nn[2]);
                Func<double, double, V3> fp = (s, t) =>
                {
                    var q = new double[3]; q[axc] = axc == 0 ? (sgc > 0 ? hi0 : lo0) : sgc * inner[axc]; q[sAx] = span(sAx, s); q[tAx] = span(tAx, t);
                    return RS(b, q[0], q[1], q[2], nn[0], nn[1], nn[2]);
                };
                if (!Seen(fp(0.5, 0.5), nv)) continue;
                double dk = darkN(nv); if (dk > 0.03) Rows(fp, tp, (s, t) => dk, 0, 1, 0, 1, 4.4f, 1.5f);
            }
        // the rounded edges: tone graded across each round; where two seen faces meet, one light line
        for (int i = 0; i < 3; i++)
            for (int j = i + 1; j < 3; j++)
                for (int si = -1; si <= 1; si += 2)
                    for (int sj = -1; sj <= 1; sj += 2)
                    {
                        if (i == 0 && (si > 0 ? !endHi : !endLo)) continue;
                        int k = 3 - i - j, ic = i, jc = j, sic = si, sjc = sj;
                        Func<double, double[]> nrm3 = t => { var n = new double[3]; n[ic] = sic * Math.Cos(t * Math.PI / 2); n[jc] = sjc * Math.Sin(t * Math.PI / 2); return n; };
                        Func<double, double, V3> fp = (s, t) =>
                        {
                            var q = new double[3]; q[ic] = ic == 0 ? (sic > 0 ? hi0 : lo0) : sic * inner[ic]; q[jc] = sjc * inner[jc]; q[k] = Lerp(qmin(k), qmax(k), s);
                            var n = nrm3(t); return RS(b, q[0], q[1], q[2], n[0], n[1], n[2]);
                        };
                        Func<double, V3> fn = t => { var n = nrm3(t); return RN(b, n[0], n[1], n[2]); };
                        bool any = false; for (int q = 0; q <= 4 && !any; q++) any = Seen(fp(0.5, q / 4.0), fn(q / 4.0));
                        if (!any) continue;
                        Rows(fp, tp, (s, t) => Seen(fp(s, t), fn(t)) ? darkN(fn(t)) : 0, 0, 1, 0, 1, 4.4f, 1.5f);
                        if (Seen(fp(0.5, 0), fn(0)) && Seen(fp(0.5, 1), fn(1)))
                            Search(new[] { TP(fp(0.06, 0.5)), TP(fp(0.5, 0.5)), TP(fp(0.94, 0.5)) }, 0.3, 1.4f, 1);
                    }
        // the silhouette, round at the corners
        var loop = new List<PointF>(hull); loop.Add(hull[0]);
        Search(loop.ToArray(), silW, silWidth, 2);
        if (contact && endHi)
        {   // the end pressed into the chest: its rim, dark where it's seen
            var run = new List<PointF>();
            for (int c = 0; c <= 64; c++)
            {
                double ph = 2 * Math.PI * c / 64, cn = Math.Cos(ph), sn = Math.Sin(ph);
                var p = RS(b, hi0, Math.Sign(cn) * inner[1], Math.Sign(sn) * inner[2], 0.5, cn * 0.85, sn * 0.85);
                if (Seen(p, RN(b, 0, cn, sn))) run.Add(TP(p)); else { if (run.Count > 2) Search(run.ToArray(), 1.0, 2.6f, 3); run.Clear(); }
            }
            if (run.Count > 2) Search(run.ToArray(), 1.0, 2.6f, 3);
        }
    }
    void DrawBox(Box bx, double s0, double s1)
    {
        if (s1 - s0 < 0.03) return;
        var r = new RB { C = bx.Pv + bx.Dir * 0.5, A = new[] { bx.Dir, bx.B, bx.C }, H = new[] { 1.0, 0.5, 0.5 }, Rb = 0.12, Lo = s0 - 0.5, Hi = s1 - 0.5, Lag = bx.Lag };
        DrawRB(r, n => Math.Max(0.24, Clamp01((0.3 - V3.Dot(n, Light)) / 0.3) * 0.78), 0.82, 1.9f, false, false);   // on the body's shadow side: never bare paper
    }
    void Motion(Box now, Box prev)
    {
        var h1 = TP(BoxPt(now, 1.1, 0, 0)); var h0 = TP(BoxPt(prev, 1.1, 0, 0)); if (Pn.D(h0, h1) < 1.5) return;
        double a = Math.Atan2(h0.Y - h1.Y, h0.X - h1.X);
        for (int k = 0; k < 5; k++)
        {
            var p = new PointF(h1.X + (R01() - 0.5f) * 70, h1.Y + (R01() - 0.5f) * 70); double L = 50 + 70 * R01();
            Hair(new[] { p, new PointF((float)(p.X + Math.Cos(a) * L), (float)(p.Y + Math.Sin(a) * L)) }, 1.5f, 0.35);
        }
    }

    // ---- the fist: the end of the attacker's arm block, square to the chest, pressed into the dent ----
    void Fist(double zEnd)
    {
        double zn = -1.95, half = (zEnd - zn) / 2;                     // the arm runs on out of the frame
        var r = new RB { C = new V3(HX, HY, (zEnd + zn) / 2), A = new[] { new V3(0, 0, 1), new V3(1, 0, 0), new V3(0, 1, 0) }, H = new[] { half, FH, FH }, Rb = 0.09, Lo = -half + 0.2, Hi = half, Lag = new V3(0, 0, 0) };
        DrawRB(r, n => Clamp01((0.3 - V3.Dot(n, Light)) / 0.25) * 0.72 + 0.1, 0.85, 2.0f, true, true);
    }

    // ---- impact strokes out of the dent's rim ----
    void Impact(int i)
    {
        var c = DP(new V3(HX, HY, -0.5));
        for (int k = 0; k < 14; k++)
        {
            double a = 2 * Math.PI * k / 14 + (R01() - 0.5) * 0.3, x = HX + 0.95 * Math.Cos(a), y = HY + 0.95 * Math.Sin(a);
            if (Math.Abs(x) > 0.98 || Math.Abs(y) > 0.98) continue;
            var p0 = DP(new V3(x, y, -0.5)); double ang = Math.Atan2(p0.Y - c.Y, p0.X - c.X), L = (50 + 80 * R01()) * (1 - 0.15 * i);
            Hair(new[] { p0, new PointF((float)(p0.X + Math.Cos(ang) * L), (float)(p0.Y + Math.Sin(ang) * L)) }, 2.2f, 0.75);
        }
    }
}
