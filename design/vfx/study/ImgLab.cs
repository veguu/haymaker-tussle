// Image lab for the impact-frame reference study (C# 5, compiled by PowerShell 5.1 Add-Type).
// Load/save, measurements (tones, vanishing point, stroke widths, edge softness) and the
// recreation primitives (zoom blur, directional blur, gradient maps, grain, side by side).
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public class Img
{
    public int W, H;
    public float[] R, G, B;

    public Img(int w, int h)
    {
        W = w; H = h;
        R = new float[w * h]; G = new float[w * h]; B = new float[w * h];
    }

    public static Img FromBitmap(Bitmap src)
    {
        var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) { g.Clear(Color.White); g.DrawImage(src, 0, 0, src.Width, src.Height); }
        var img = new Img(bmp.Width, bmp.Height);
        var data = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var bytes = new byte[data.Stride * bmp.Height];
        Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
        int stride = data.Stride;
        bmp.UnlockBits(data);
        bmp.Dispose();
        for (int y = 0; y < img.H; y++)
            for (int x = 0; x < img.W; x++)
            {
                int o = y * stride + x * 4, i = y * img.W + x;
                img.B[i] = bytes[o] / 255f; img.G[i] = bytes[o + 1] / 255f; img.R[i] = bytes[o + 2] / 255f;
            }
        return img;
    }

    public static Img Load(string path) { using (var b = new Bitmap(path)) return FromBitmap(b); }

    public static Img Solid(int w, int h, float r, float g, float b)
    {
        var img = new Img(w, h);
        for (int i = 0; i < w * h; i++) { img.R[i] = r; img.G[i] = g; img.B[i] = b; }
        return img;
    }

    static byte Q(float v) { int n = (int)Math.Round(v * 255f); return (byte)(n < 0 ? 0 : n > 255 ? 255 : n); }

    public Bitmap ToBitmap()
    {
        var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        var data = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        var bytes = new byte[data.Stride * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * data.Stride + x * 4, i = y * W + x;
                bytes[o] = Q(B[i]); bytes[o + 1] = Q(G[i]); bytes[o + 2] = Q(R[i]); bytes[o + 3] = 255;
            }
        Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
        bmp.UnlockBits(data);
        return bmp;
    }

    public void Save(string path) { using (var b = ToBitmap()) b.Save(path, ImageFormat.Png); }

    public Img Resize(int w, int h)
    {
        using (var b = ToBitmap())
        using (var d = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(d))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(b, 0, 0, w, h);
            }
            return FromBitmap(d);
        }
    }

    public Img Crop(int x0, int y0, int w, int h)
    {
        var o = new Img(w, h);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int sx = Math.Min(W - 1, Math.Max(0, x0 + x)), sy = Math.Min(H - 1, Math.Max(0, y0 + y));
                int i = y * w + x, j = sy * W + sx;
                o.R[i] = R[j]; o.G[i] = G[j]; o.B[i] = B[j];
            }
        return o;
    }

    public Img Clone()
    {
        var o = new Img(W, H);
        Array.Copy(R, o.R, R.Length); Array.Copy(G, o.G, G.Length); Array.Copy(B, o.B, B.Length);
        return o;
    }

    public float L(int i) { return 0.299f * R[i] + 0.587f * G[i] + 0.114f * B[i]; }

    public float[] Lum()
    {
        var l = new float[W * H];
        for (int i = 0; i < l.Length; i++) l[i] = L(i);
        return l;
    }

    public void Sample(float x, float y, out float r, out float g, out float b)
    {
        if (x < 0) x = 0; if (y < 0) y = 0;
        if (x > W - 1.001f) x = W - 1.001f; if (y > H - 1.001f) y = H - 1.001f;
        int x0 = (int)x, y0 = (int)y;
        float fx = x - x0, fy = y - y0;
        int i00 = y0 * W + x0, i10 = i00 + 1, i01 = i00 + W, i11 = i01 + 1;
        float w00 = (1 - fx) * (1 - fy), w10 = fx * (1 - fy), w01 = (1 - fx) * fy, w11 = fx * fy;
        r = R[i00] * w00 + R[i10] * w10 + R[i01] * w01 + R[i11] * w11;
        g = G[i00] * w00 + G[i10] * w10 + G[i01] * w01 + G[i11] * w11;
        b = B[i00] * w00 + B[i10] * w10 + B[i01] * w01 + B[i11] * w11;
    }

    public float SampleL(float x, float y)
    {
        float r, g, b; Sample(x, y, out r, out g, out b);
        return 0.299f * r + 0.587f * g + 0.114f * b;
    }
}

public static class Lab
{
    // ---------- measurements ----------

    static void Hsv(float r, float g, float b, out float h, out float s, out float v)
    {
        float mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
        v = mx; s = mx <= 0 ? 0 : (mx - mn) / mx; h = 0;
        float d = mx - mn;
        if (d <= 1e-5f) return;
        if (mx == r) h = 60f * (((g - b) / d) % 6f);
        else if (mx == g) h = 60f * ((b - r) / d + 2f);
        else h = 60f * ((r - g) / d + 4f);
        if (h < 0) h += 360f;
    }

    // Tone histogram (10 bins), black/white/mid shares, mean colour and the tinted pixels' hue.
    public static string Stats(string path, int x0, int y0, int x1, int y1)
    {
        var img = Img.Load(path);
        if (x1 <= 0) x1 = img.W; if (y1 <= 0) y1 = img.H;
        var bins = new int[10];
        int n = 0, black = 0, white = 0, tinted = 0;
        double mr = 0, mg = 0, mb = 0, hx = 0, hy = 0, ts = 0;
        for (int y = y0; y < y1; y++)
            for (int x = x0; x < x1; x++)
            {
                int i = y * img.W + x; float l = img.L(i);
                bins[Math.Min(9, (int)(l * 10f))]++; n++;
                if (l < 0.15f) black++; if (l > 0.85f) white++;
                mr += img.R[i]; mg += img.G[i]; mb += img.B[i];
                float h, s, v; Hsv(img.R[i], img.G[i], img.B[i], out h, out s, out v);
                if (s > 0.15f && v > 0.2f) { tinted++; hx += Math.Cos(h * Math.PI / 180) * s; hy += Math.Sin(h * Math.PI / 180) * s; ts += s; }
            }
        var sb = new StringBuilder();
        sb.AppendFormat("size {0}x{1} region {2},{3}-{4},{5}\n", img.W, img.H, x0, y0, x1, y1);
        sb.Append("lum bins (0..1 in tenths, %): ");
        for (int b = 0; b < 10; b++) sb.AppendFormat("{0:0.0} ", 100.0 * bins[b] / n);
        sb.AppendFormat("\nblack(<.15) {0:0.0}%  white(>.85) {1:0.0}%  mid {2:0.0}%\n", 100.0 * black / n, 100.0 * white / n, 100.0 * (n - black - white) / n);
        sb.AppendFormat("mean rgb {0:0} {1:0} {2:0}\n", 255 * mr / n, 255 * mg / n, 255 * mb / n);
        double hue = Math.Atan2(hy, hx) * 180 / Math.PI; if (hue < 0) hue += 360;
        sb.AppendFormat("tinted(s>.15) {0:0.0}%  mean hue {1:0}  mean sat {2:0.00}\n", 100.0 * tinted / n, hue, tinted > 0 ? ts / tinted : 0);
        return sb.ToString();
    }

    // The colour ramp: mean RGB of the pixels in each of 16 luminance bins (a gradient map read back).
    public static string Ramp(string path, int x0, int y0, int x1, int y1)
    {
        var img = Img.Load(path);
        if (x1 <= 0) x1 = img.W; if (y1 <= 0) y1 = img.H;
        var n = new int[16]; var r = new double[16]; var g = new double[16]; var b = new double[16];
        for (int y = y0; y < y1; y++)
            for (int x = x0; x < x1; x++)
            {
                int i = y * img.W + x; int k = Math.Min(15, (int)(img.L(i) * 16));
                n[k]++; r[k] += img.R[i]; g[k] += img.G[i]; b[k] += img.B[i];
            }
        var sb = new StringBuilder();
        for (int k = 0; k < 16; k++)
            if (n[k] > 0) sb.AppendFormat("lum {0:0.00}-{1:0.00}: {2,6} px  rgb {3:0} {4:0} {5:0}\n", k / 16.0, (k + 1) / 16.0, n[k], 255 * r[k] / n[k], 255 * g[k] / n[k], 255 * b[k] / n[k]);
        return sb.ToString();
    }

    // Brightest and darkest typical colours (median of top/bottom 5% by luminance).
    public static string Extremes(string path)
    {
        var img = Img.Load(path);
        var idx = new List<int>();
        for (int i = 0; i < img.W * img.H; i++) idx.Add(i);
        var lum = img.Lum();
        idx.Sort((a, b) => lum[a].CompareTo(lum[b]));
        int k = idx.Count / 20;
        Func<int, int, string> avg = (from, to) =>
        {
            double r = 0, g = 0, b = 0; int c = 0;
            for (int j = from; j < to; j++) { int i = idx[j]; r += img.R[i]; g += img.G[i]; b += img.B[i]; c++; }
            return string.Format("{0:0} {1:0} {2:0}", 255 * r / c, 255 * g / c, 255 * b / c);
        };
        return "darkest 5% rgb " + avg(0, k) + "\nbrightest 5% rgb " + avg(idx.Count - k, idx.Count) +
               "\nmedian band rgb " + avg(idx.Count / 2 - k / 2, idx.Count / 2 + k / 2) + "\n";
    }

    // Where the streaks converge. Gradients across a radial streak point tangentially, so the
    // best centre minimises the magnitude-weighted mean of cos^2(gradient, radial). Random = 0.5.
    // Also reports the global orientation coherence (1 = all strokes parallel: directional blur).
    public static string Vanish(string path, int x0, int y0, int x1, int y1)
    {
        var full = Img.Load(path);
        if (x1 <= 0) x1 = full.W; if (y1 <= 0) y1 = full.H;
        var src = full.Crop(x0, y0, x1 - x0, y1 - y0);
        float scale = 320f / src.W;
        var img = src.Resize(320, Math.Max(8, (int)(src.H * scale)));
        var l = img.Lum();
        int W = img.W, H = img.H;
        var px = new List<float>(); var py = new List<float>(); var gx = new List<float>(); var gy = new List<float>(); var gm = new List<float>();
        double jxx = 0, jyy = 0, jxy = 0;
        for (int y = 1; y < H - 1; y++)
            for (int x = 1; x < W - 1; x++)
            {
                Func<int, int, float> L = (a, b) => l[(y + b) * W + (x + a)];
                float sx = (L(1, -1) + 2 * L(1, 0) + L(1, 1)) - (L(-1, -1) + 2 * L(-1, 0) + L(-1, 1));
                float sy = (L(-1, 1) + 2 * L(0, 1) + L(1, 1)) - (L(-1, -1) + 2 * L(0, -1) + L(1, -1));
                float m = (float)Math.Sqrt(sx * sx + sy * sy);
                jxx += sx * sx; jyy += sy * sy; jxy += sx * sy;
                if (m > 0.25f) { px.Add(x); py.Add(y); gx.Add(sx / m); gy.Add(sy / m); gm.Add(m); }
            }
        double bestS = 9, bx = 0, by = 0;
        Func<double, double, double> score = (cx, cy) =>
        {
            double s = 0, ws = 0;
            for (int k = 0; k < px.Count; k++)
            {
                double rx = px[k] - cx, ry = py[k] - cy, rl = Math.Sqrt(rx * rx + ry * ry);
                if (rl < 4) continue;
                double c = (rx * gx[k] + ry * gy[k]) / rl;
                s += gm[k] * c * c; ws += gm[k];
            }
            return ws > 0 ? s / ws : 1;
        };
        for (int cy = -H; cy <= 2 * H; cy += 4)
            for (int cx = -W; cx <= 2 * W; cx += 4)
            {
                double s = score(cx, cy);
                if (s < bestS) { bestS = s; bx = cx; by = cy; }
            }
        for (double cy = by - 4; cy <= by + 4; cy += 1)
            for (double cx = bx - 4; cx <= bx + 4; cx += 1)
            {
                double s = score(cx, cy);
                if (s < bestS) { bestS = s; bx = cx; by = cy; }
            }
        double coh = Math.Sqrt((jxx - jyy) * (jxx - jyy) + 4 * jxy * jxy) / (jxx + jyy);
        double ang = 0.5 * Math.Atan2(2 * jxy, jxx - jyy) * 180 / Math.PI; // gradient direction
        return string.Format("edges {0}  vanishing point ({1:0}, {2:0}) in full-size px, score {3:0.000} (0.5 = random)\n" +
                             "score at region centre {4:0.000}\norientation coherence {5:0.00}, strokes run at {6:0} deg\n",
            px.Count, x0 + bx / scale, y0 + by / scale, bestS, score(W / 2.0, H / 2.0), coh, ang + 90);
    }

    // Walk circles round (cx, cy): dark runs (lum < t) as arc lengths in px, and how soft the
    // dark/light edges are (px between lum 0.2 and 0.8 at each crossing).
    public static string Rings(string path, float cx, float cy, string radii, float t)
    {
        var img = Img.Load(path);
        var sb = new StringBuilder();
        foreach (var rs in radii.Split(','))
        {
            float r = float.Parse(rs, System.Globalization.CultureInfo.InvariantCulture);
            int n = Math.Max(90, (int)(2 * Math.PI * r));
            var v = new List<float>(); int inside = 0;
            for (int k = 0; k < n; k++)
            {
                double a = 2 * Math.PI * k / n;
                float x = cx + (float)(r * Math.Cos(a)), y = cy + (float)(r * Math.Sin(a));
                if (x < 0 || y < 0 || x > img.W - 1 || y > img.H - 1) { v.Add(-1); continue; }
                inside++; v.Add(img.SampleL(x, y));
            }
            var runs = new List<float>(); int cur = 0; bool started = false; int darkN = 0;
            var soft = new List<int>();
            for (int k = 0; k < n; k++)
            {
                float s = v[k];
                if (s < 0) { cur = 0; started = false; continue; }
                if (s < t) { darkN++; cur++; }
                else { if (cur > 0 && started) runs.Add(cur * (float)(2 * Math.PI * r / n)); cur = 0; started = true; }
                if (s < 0) continue;
            }
            for (int k = 1; k < n - 1; k++)
            {
                if (v[k] < 0 || v[k - 1] < 0) continue;
                bool up = v[k - 1] < 0.5f && v[k] >= 0.5f, down = v[k - 1] >= 0.5f && v[k] < 0.5f;
                if (!up && !down) continue;
                int a = k, b = k;
                while (a > 0 && v[a - 1] >= 0 && v[a - 1] > 0.2f && v[a - 1] < 0.8f && k - a < 40) a--;
                while (b < n - 1 && v[b + 1] >= 0 && v[b + 1] > 0.2f && v[b + 1] < 0.8f && b - k < 40) b++;
                soft.Add(b - a + 1);
            }
            runs.Sort(); soft.Sort();
            sb.AppendFormat("r={0}: in-image {1:0}%  dark {2:0}%  dark runs {3}  median {4:0.0}px  p90 {5:0.0}px  max {6:0.0}px  edge softness median {7}px p90 {8}px\n",
                r, 100.0 * inside / n, inside > 0 ? 100.0 * darkN / inside : 0, runs.Count,
                runs.Count > 0 ? runs[runs.Count / 2] : 0, runs.Count > 0 ? runs[runs.Count * 9 / 10] : 0, runs.Count > 0 ? runs[runs.Count - 1] : 0,
                soft.Count > 0 ? soft[soft.Count / 2] : 0, soft.Count > 0 ? soft[soft.Count * 9 / 10] : 0);
        }
        return sb.ToString();
    }

    // Along rays from (cx, cy): lengths of dark and light streak segments (complete runs only).
    public static string Rays(string path, float cx, float cy, int nAngles, float r0, float t)
    {
        var img = Img.Load(path);
        var dark = new List<int>(); var light = new List<int>();
        for (int k = 0; k < nAngles; k++)
        {
            double a = 2 * Math.PI * k / nAngles;
            float dx = (float)Math.Cos(a), dy = (float)Math.Sin(a);
            int run = 0; int state = -1; bool first = true;
            for (float r = r0; ; r += 1)
            {
                float x = cx + dx * r, y = cy + dy * r;
                if (x < 0 || y < 0 || x > img.W - 1 || y > img.H - 1) break;
                int s = img.SampleL(x, y) < t ? 1 : 0;
                if (s == state) { run++; continue; }
                if (state >= 0 && !first) (state == 1 ? dark : light).Add(run);
                if (state >= 0) first = false;
                state = s; run = 1;
            }
        }
        dark.Sort(); light.Sort();
        Func<List<int>, string> d = (L) => L.Count == 0 ? "none" : string.Format("n {0} median {1} p75 {2} p90 {3} max {4}", L.Count, L[L.Count / 2], L[L.Count * 3 / 4], L[L.Count * 9 / 10], L[L.Count - 1]);
        return "dark segments: " + d(dark) + "\nlight segments: " + d(light) + "\n";
    }

    // ---------- recreation primitives ----------

    // Zoom blur toward (cx, cy): averages samples along the line to the centre, scale 1 .. 1-amount.
    // amountMap (optional, per angle bucket) multiplies the amount: ragged streak lengths.
    public static Img Zoom(Img src, float cx, float cy, float amount, int samples, float[] amountByAngle)
    {
        var o = new Img(src.W, src.H);
        int nb = amountByAngle == null ? 0 : amountByAngle.Length;
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float a = amount;
                if (nb > 0)
                {
                    double ang = Math.Atan2(y - cy, x - cx) / (2 * Math.PI) + 0.5;
                    double f = ang * nb; int i0 = ((int)Math.Floor(f)) % nb; int i1 = (i0 + 1) % nb; double fr = f - Math.Floor(f);
                    a *= (float)(amountByAngle[i0] * (1 - fr) + amountByAngle[i1] * fr);
                }
                float sr = 0, sg = 0, sb = 0;
                for (int k = 0; k < samples; k++)
                {
                    float s = 1f - a * k / (samples - 1f);
                    float r, g, b; src.Sample(cx + (x - cx) * s, cy + (y - cy) * s, out r, out g, out b);
                    sr += r; sg += g; sb += b;
                }
                int i = y * src.W + x;
                o.R[i] = sr / samples; o.G[i] = sg / samples; o.B[i] = sb / samples;
            }
        return o;
    }

    // Straight motion blur of length len (px) along angle deg, centred.
    public static Img Directional(Img src, float deg, float len, int samples)
    {
        var o = new Img(src.W, src.H);
        float dx = (float)Math.Cos(deg * Math.PI / 180), dy = (float)Math.Sin(deg * Math.PI / 180);
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float sr = 0, sg = 0, sb = 0;
                for (int k = 0; k < samples; k++)
                {
                    float d = len * (k / (samples - 1f) - 0.5f);
                    float r, g, b; src.Sample(x + dx * d, y + dy * d, out r, out g, out b);
                    sr += r; sg += g; sb += b;
                }
                int i = y * src.W + x;
                o.R[i] = sr / samples; o.G[i] = sg / samples; o.B[i] = sb / samples;
            }
        return o;
    }

    // Spin (rotational) blur round (cx, cy) through deg degrees.
    public static Img Spin(Img src, float cx, float cy, float deg, int samples)
    {
        var o = new Img(src.W, src.H);
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float sr = 0, sg = 0, sb = 0;
                for (int k = 0; k < samples; k++)
                {
                    double a = deg * Math.PI / 180 * (k / (samples - 1.0) - 0.5);
                    double c = Math.Cos(a), s = Math.Sin(a);
                    float rx = x - cx, ry = y - cy;
                    float r, g, b; src.Sample(cx + (float)(rx * c - ry * s), cy + (float)(rx * s + ry * c), out r, out g, out b);
                    sr += r; sg += g; sb += b;
                }
                int i = y * src.W + x;
                o.R[i] = sr / samples; o.G[i] = sg / samples; o.B[i] = sb / samples;
            }
        return o;
    }

    // Separable box blur, radius px (3 passes ~ gaussian).
    public static Img Soften(Img src, int radius)
    {
        var o = src.Clone();
        for (int pass = 0; pass < 3; pass++)
        {
            o = Box(o, radius, true);
            o = Box(o, radius, false);
        }
        return o;
    }

    static Img Box(Img s, int r, bool horiz)
    {
        var o = new Img(s.W, s.H);
        int n = 2 * r + 1;
        for (int a = 0; a < (horiz ? s.H : s.W); a++)
        {
            float tr = 0, tg = 0, tb = 0;
            int len = horiz ? s.W : s.H;
            Func<int, int> I = (k) => { k = Math.Max(0, Math.Min(len - 1, k)); return horiz ? a * s.W + k : k * s.W + a; };
            for (int k = -r; k <= r; k++) { int i = I(k); tr += s.R[i]; tg += s.G[i]; tb += s.B[i]; }
            for (int k = 0; k < len; k++)
            {
                int i = I(k);
                o.R[i] = tr / n; o.G[i] = tg / n; o.B[i] = tb / n;
                int ia = I(k + r + 1), ib = I(k - r);
                tr += s.R[ia] - s.R[ib]; tg += s.G[ia] - s.G[ib]; tb += s.B[ia] - s.B[ib];
            }
        }
        return o;
    }

    // Gradient map on luminance. stops: "pos:r,g,b;pos:r,g,b;..." with pos 0..1 and rgb 0..255.
    public static Img GradientMap(Img src, string stops)
    {
        var ps = new List<float>(); var cs = new List<float[]>();
        foreach (var st in stops.Split(';'))
        {
            var kv = st.Split(':'); var c = kv[1].Split(',');
            ps.Add(float.Parse(kv[0], System.Globalization.CultureInfo.InvariantCulture));
            cs.Add(new float[] { float.Parse(c[0]) / 255f, float.Parse(c[1]) / 255f, float.Parse(c[2]) / 255f });
        }
        var o = new Img(src.W, src.H);
        for (int i = 0; i < src.W * src.H; i++)
        {
            float l = src.L(i);
            int k = 0;
            while (k < ps.Count - 1 && l > ps[k + 1]) k++;
            float[] c0 = cs[k], c1 = cs[Math.Min(k + 1, ps.Count - 1)];
            float f = k + 1 < ps.Count ? (l - ps[k]) / Math.Max(1e-5f, ps[k + 1] - ps[k]) : 0;
            if (l <= ps[0]) { f = 0; c1 = c0; }
            f = Math.Max(0, Math.Min(1, f));
            o.R[i] = c0[0] + (c1[0] - c0[0]) * f; o.G[i] = c0[1] + (c1[1] - c0[1]) * f; o.B[i] = c0[2] + (c1[2] - c0[2]) * f;
        }
        return o;
    }

    // Luminance-only levels: (l - lo) / (hi - lo), gamma, clamp. Writes grey.
    public static Img Levels(Img src, float lo, float hi, float gamma)
    {
        var o = new Img(src.W, src.H);
        for (int i = 0; i < src.W * src.H; i++)
        {
            float l = (src.L(i) - lo) / (hi - lo);
            l = Math.Max(0, Math.Min(1, l));
            l = (float)Math.Pow(l, gamma);
            o.R[i] = o.G[i] = o.B[i] = l;
        }
        return o;
    }

    // Value noise in [-amp, amp] added to luminance; cell = feature size in px; stretch along the
    // ray to (cx, cy) when radial > 0 (streaky grain like a zoom-blurred texture).
    public static void Grain(Img img, float amp, float cell, int seed)
    {
        var rnd = new Random(seed);
        int gw = (int)(img.W / cell) + 3, gh = (int)(img.H / cell) + 3;
        var g = new float[gw * gh];
        for (int i = 0; i < g.Length; i++) g[i] = (float)(rnd.NextDouble() * 2 - 1);
        for (int y = 0; y < img.H; y++)
            for (int x = 0; x < img.W; x++)
            {
                float fx = x / cell, fy = y / cell; int x0 = (int)fx, y0 = (int)fy; float tx = fx - x0, ty = fy - y0;
                tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty);
                float v = g[y0 * gw + x0] * (1 - tx) * (1 - ty) + g[y0 * gw + x0 + 1] * tx * (1 - ty) + g[(y0 + 1) * gw + x0] * (1 - tx) * ty + g[(y0 + 1) * gw + x0 + 1] * tx * ty;
                int i = y * img.W + x;
                img.R[i] += v * amp; img.G[i] += v * amp; img.B[i] += v * amp;
            }
    }

    // a over b where mask (luminance of m) is dark: out = lerp(b, a, 1 - mask). Used to stamp.
    public static Img Multiply(Img a, Img b)
    {
        var o = new Img(a.W, a.H);
        for (int i = 0; i < a.W * a.H; i++) { o.R[i] = a.R[i] * b.R[i]; o.G[i] = a.G[i] * b.G[i]; o.B[i] = a.B[i] * b.B[i]; }
        return o;
    }

    public static Img Mix(Img a, Img b, float t)
    {
        var o = new Img(a.W, a.H);
        for (int i = 0; i < a.W * a.H; i++) { o.R[i] = a.R[i] + (b.R[i] - a.R[i]) * t; o.G[i] = a.G[i] + (b.G[i] - a.G[i]) * t; o.B[i] = a.B[i] + (b.B[i] - a.B[i]) * t; }
        return o;
    }

    // Fine angular / coarse radial noise round (cx, cy): the kind of busy detail that a zoom blur
    // turns into speed lines. Each angular bin (random width) is split into radial cells that grow
    // with distance; each cell is dark (0) with probability density, else white.
    public static Img PolarNoise(int w, int h, float cx, float cy, int angBins, float radCell, float density, float spread, int seed)
    {
        var rnd = new Random(seed);
        var edges = new double[angBins + 1]; double acc = 0;
        var widths = new double[angBins];
        for (int k = 0; k < angBins; k++) { widths[k] = 0.3 + rnd.NextDouble() * 1.4; acc += widths[k]; }
        edges[0] = 0; for (int k = 0; k < angBins; k++) edges[k + 1] = edges[k] + widths[k] / acc;
        var seeds = new int[angBins]; for (int k = 0; k < angBins; k++) seeds[k] = rnd.Next();
        var pbin = new double[angBins];
        for (int k = 0; k < angBins; k++) pbin[k] = Math.Max(0, Math.Min(1, density + (rnd.NextDouble() - 0.5) * 2 * spread));
        var o = new Img(w, h);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                double a = Math.Atan2(y - cy, x - cx) / (2 * Math.PI) + 0.5;
                int lo = 0, hi = angBins;
                while (hi - lo > 1) { int mid = (lo + hi) / 2; if (edges[mid] <= a) lo = mid; else hi = mid; }
                double r = Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
                int cell = (int)Math.Floor(Math.Log(1 + r / 20.0) / radCell);
                int hsh = seeds[lo] ^ (cell * 73856093);
                double v = new Random(hsh).NextDouble();
                float c = v < pbin[lo] ? 0f : 1f;
                int i = y * w + x; o.R[i] = o.G[i] = o.B[i] = c;
            }
        return o;
    }

    // Darken: per-channel minimum.
    public static Img Min(Img a, Img b)
    {
        var o = new Img(a.W, a.H);
        for (int i = 0; i < a.W * a.H; i++) { o.R[i] = Math.Min(a.R[i], b.R[i]); o.G[i] = Math.Min(a.G[i], b.G[i]); o.B[i] = Math.Min(a.B[i], b.B[i]); }
        return o;
    }

    // fg where the mask is white, bg where it is black (mask luminance as the weight).
    public static Img MaskMix(Img bg, Img fg, Img mask)
    {
        var o = new Img(bg.W, bg.H);
        for (int i = 0; i < bg.W * bg.H; i++)
        {
            float t = mask.L(i);
            o.R[i] = bg.R[i] + (fg.R[i] - bg.R[i]) * t; o.G[i] = bg.G[i] + (fg.G[i] - bg.G[i]) * t; o.B[i] = bg.B[i] + (fg.B[i] - bg.B[i]) * t;
        }
        return o;
    }

    // Zoom blur sampling OUTWARD (scale 1 .. 1+amount): streaks grow inward from each feature,
    // so busy detail far out becomes lines that taper to points toward the centre.
    public static Img ZoomOut(Img src, float cx, float cy, float amount, int samples)
    {
        var o = new Img(src.W, src.H);
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float sr = 0, sg = 0, sb = 0; int n = 0;
                for (int k = 0; k < samples; k++)
                {
                    float s = 1f + amount * k / (samples - 1f);
                    float px = cx + (x - cx) * s, py = cy + (y - cy) * s;
                    if (px < 0 || py < 0 || px > src.W - 1 || py > src.H - 1) break;
                    float r, g, b; src.Sample(px, py, out r, out g, out b);
                    sr += r; sg += g; sb += b; n++;
                }
                int i = y * src.W + x;
                if (n == 0) { o.R[i] = src.R[i]; o.G[i] = src.G[i]; o.B[i] = src.B[i]; continue; }
                o.R[i] = sr / n; o.G[i] = sg / n; o.B[i] = sb / n;
            }
        return o;
    }

    // Radial trail: every dark speck drags a full-strength line toward (cx, cy), lightening by
    // `fade` over the trail's length (scale 1 .. 1+amount outward). Lines stay sharp and thin out
    // toward the centre because their angle stays fixed: needles from small debris.
    public static Img Trail(Img src, float cx, float cy, float amount, int samples, float fade)
    {
        var o = new Img(src.W, src.H);
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float best = 2f;
                for (int k = 0; k < samples; k++)
                {
                    float t = k / (samples - 1f);
                    float s = 1f + amount * t;
                    float px = cx + (x - cx) * s, py = cy + (y - cy) * s;
                    if (px < 0 || py < 0 || px > src.W - 1 || py > src.H - 1) break;
                    float v = src.SampleL(px, py) + fade * t;
                    if (v < best) best = v;
                }
                int i = y * src.W + x;
                float l = Math.Min(1f, best);
                o.R[i] = o.G[i] = o.B[i] = l;
            }
        return o;
    }

    // Contrast by distance from (cx, cy): k = kPeak between rPeak0 and rPeak1, easing to kOut at the
    // centre and beyond; inside rHot it is pushed toward white by up to hotAmt (the hot centre).
    public static Img RadialShape(Img src, float cx, float cy, float rPeak0, float rPeak1, float kPeak, float kOut, float rHot, float hotAmt)
    {
        var o = new Img(src.W, src.H);
        float fall = rPeak1 - rPeak0;
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                int i = y * src.W + x;
                float r = (float)Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
                float k;
                if (r < rPeak0) k = kOut + (kPeak - kOut) * (r / rPeak0);
                else if (r <= rPeak1) k = kPeak;
                else k = kPeak + (kOut - kPeak) * Math.Min(1f, (r - rPeak1) / fall);
                float l = 0.5f + (src.L(i) - 0.5f) * k;
                if (r < rHot) l += hotAmt * (1f - r / rHot);
                o.R[i] = o.G[i] = o.B[i] = l;
            }
        return o;
    }

    // The edge of a black-on-white mask as a line: black where the softened mask is between lo and hi.
    public static Img OutlineBand(Img mask, int soft, float lo, float hi)
    {
        var s = Soften(mask, soft);
        var o = new Img(mask.W, mask.H);
        for (int i = 0; i < mask.W * mask.H; i++)
        {
            float l = s.L(i);
            float v = (l > lo && l < hi) ? 0f : 1f;
            o.R[i] = o.G[i] = o.B[i] = v;
        }
        return o;
    }

    // ---------- line analysis ----------

    // Zhang-Suen thinning of the dark strokes (lum < thr) to 1 px centrelines. Returns 1 = skeleton.
    public static byte[] SkeletonBits(Img src, float thr)
    {
        int W = src.W, H = src.H; var b = new byte[W * H];
        for (int i = 0; i < W * H; i++) b[i] = (byte)(src.L(i) < thr ? 1 : 0);
        for (int x = 0; x < W; x++) { b[x] = 0; b[(H - 1) * W + x] = 0; }
        for (int y = 0; y < H; y++) { b[y * W] = 0; b[y * W + W - 1] = 0; }
        var del = new List<int>(); bool changed = true;
        while (changed)
        {
            changed = false;
            for (int pass = 0; pass < 2; pass++)
            {
                del.Clear();
                for (int y = 1; y < H - 1; y++)
                    for (int x = 1; x < W - 1; x++)
                    {
                        int i = y * W + x; if (b[i] == 0) continue;
                        int p2 = b[i - W], p3 = b[i - W + 1], p4 = b[i + 1], p5 = b[i + W + 1], p6 = b[i + W], p7 = b[i + W - 1], p8 = b[i - 1], p9 = b[i - W - 1];
                        int B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9; if (B < 2 || B > 6) continue;
                        int A = (p2 == 0 && p3 == 1 ? 1 : 0) + (p3 == 0 && p4 == 1 ? 1 : 0) + (p4 == 0 && p5 == 1 ? 1 : 0) + (p5 == 0 && p6 == 1 ? 1 : 0)
                              + (p6 == 0 && p7 == 1 ? 1 : 0) + (p7 == 0 && p8 == 1 ? 1 : 0) + (p8 == 0 && p9 == 1 ? 1 : 0) + (p9 == 0 && p2 == 1 ? 1 : 0);
                        if (A != 1) continue;
                        if (pass == 0) { if (p2 * p4 * p6 != 0 || p4 * p6 * p8 != 0) continue; }
                        else { if (p2 * p4 * p8 != 0 || p2 * p6 * p8 != 0) continue; }
                        del.Add(i);
                    }
                foreach (int d in del) b[d] = 0;
                if (del.Count > 0) changed = true;
            }
        }
        return b;
    }

    static readonly int[] NX = { 1, 1, 0, -1, -1, -1, 0, 1 };
    static readonly int[] NY = { 0, 1, 1, 1, 0, -1, -1, -1 };

    // Splits a skeleton into curves between end points and junctions, keeps those >= minLen px,
    // fits each with a circle (centre, radius, rms) and a straight line (angle, rms), writes a
    // report and an overlay (each curve coloured and numbered over the faded source).
    public static string TraceCurves(Img src, float thr, int minLen, string overlayPath, string pointsPath)
    {
        return TraceBits(src, SkeletonBits(src, thr), minLen, overlayPath, pointsPath);
    }

    // Centrelines of dark strokes of ANY darkness: blur, then the Hessian's larger eigenvalue (positive
    // across a dark valley) above thr, thinned to its crest (non-maximum suppression across the line).
    public static byte[] RidgeBits(Img src, int blur, float thr)
    {
        int W = src.W, H = src.H;
        var L = Soften(src, blur).Lum();
        var lam = new float[W * H]; var ex = new float[W * H]; var ey = new float[W * H];
        for (int y = 1; y < H - 1; y++)
            for (int x = 1; x < W - 1; x++)
            {
                int i = y * W + x;
                double hxx = L[i - 1] - 2 * L[i] + L[i + 1], hyy = L[i - W] - 2 * L[i] + L[i + W];
                double hxy = (L[i + W + 1] - L[i + W - 1] - L[i - W + 1] + L[i - W - 1]) / 4;
                double tr = (hxx + hyy) / 2, d = Math.Sqrt((hxx - hyy) * (hxx - hyy) / 4 + hxy * hxy), l1 = tr + d;
                lam[i] = (float)Math.Max(0, l1);
                double vx = hxy, vy = l1 - hxx; if (Math.Abs(vx) + Math.Abs(vy) < 1e-12) { vx = l1 - hyy; vy = hxy; }
                double n = Math.Sqrt(vx * vx + vy * vy); if (n < 1e-12) { vx = 1; vy = 0; n = 1; }
                ex[i] = (float)(vx / n); ey[i] = (float)(vy / n);
            }
        var b = new byte[W * H];
        for (int y = 2; y < H - 2; y++)
            for (int x = 2; x < W - 2; x++)
            {
                int i = y * W + x; if (lam[i] < thr) continue;
                int ax = (int)Math.Round(x + ex[i]), ay = (int)Math.Round(y + ey[i]), bx = (int)Math.Round(x - ex[i]), by = (int)Math.Round(y - ey[i]);
                if (lam[i] >= lam[ay * W + ax] && lam[i] >= lam[by * W + bx]) b[i] = 1;
            }
        return ThinBits(b, W, H);
    }

    public static byte[] ThinBits(byte[] src, int W, int H)
    {
        var img = new Img(W, H);
        for (int i = 0; i < W * H; i++) img.R[i] = img.G[i] = img.B[i] = src[i] == 1 ? 0f : 1f;
        return SkeletonBits(img, 0.5f);
    }

    public static string TraceRidges(Img src, int blur, float thr, int minLen, string overlayPath, string pointsPath)
    {
        return TraceBits(src, RidgeBits(src, blur, thr), minLen, overlayPath, pointsPath);
    }

    // Across-stroke measurement at (x, y) with unit normal (nx, ny): the core darkness and the width
    // between the points where the luminance climbs halfway back to the local background.
    static void Stroke(float[] L, int W, int H, double x, double y, double nx, double ny, out double width, out double core)
    {
        Func<double, double, double> at = (px, py) => { int ix = (int)Math.Round(px), iy = (int)Math.Round(py); if (ix < 0 || iy < 0 || ix >= W || iy >= H) return 1.0; return L[iy * W + ix]; };
        core = 2; for (int t = -3; t <= 3; t++) core = Math.Min(core, at(x + nx * t, y + ny * t));
        double bg = 0; for (int t = -45; t <= 45; t++) bg = Math.Max(bg, at(x + nx * t, y + ny * t));
        double half = (bg + core) / 2; int a = 0, c = 0;
        while (a < 45 && at(x + nx * (a + 1), y + ny * (a + 1)) < half) a++;
        while (c < 45 && at(x - nx * (c + 1), y - ny * (c + 1)) < half) c++;
        width = a + c + 1;
    }

    public static string TraceBits(Img src, byte[] b, int minLen, string overlayPath, string pointsPath)
    {
        int W = src.W, H = src.H;
        var Lsrc = src.Lum();
        Func<int, int> deg = (i) => { int x = i % W, y = i / W, n = 0; for (int k = 0; k < 8; k++) { int xx = x + NX[k], yy = y + NY[k]; if (xx >= 0 && yy >= 0 && xx < W && yy < H && b[yy * W + xx] == 1) n++; } return n; };
        var node = new bool[W * H];
        for (int i = 0; i < W * H; i++) if (b[i] == 1) { int d = deg(i); if (d != 2) node[i] = true; }
        var used = new bool[W * H];
        var paths = new List<List<int>>();
        // walk from every node along each unused branch
        for (int s = 0; s < W * H; s++)
        {
            if (b[s] == 0 || !node[s]) continue;
            int sx = s % W, sy = s / W;
            for (int k = 0; k < 8; k++)
            {
                int xx = sx + NX[k], yy = sy + NY[k]; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
                int n = yy * W + xx; if (b[n] == 0 || used[n]) continue;
                var path = new List<int> { s, n }; int prev = s, cur = n;
                while (!node[cur])
                {
                    used[cur] = true; int next = -1; int cx0 = cur % W, cy0 = cur / W;
                    for (int q = 0; q < 8; q++)
                    {
                        int x2 = cx0 + NX[q], y2 = cy0 + NY[q]; if (x2 < 0 || y2 < 0 || x2 >= W || y2 >= H) continue;
                        int m = y2 * W + x2; if (b[m] == 0 || m == prev || (used[m] && !node[m])) continue;
                        if (path.Count > 2 && m == path[path.Count - 3]) continue;
                        next = m; break;
                    }
                    if (next < 0) break;
                    path.Add(next); prev = cur; cur = next;
                }
                if (path.Count >= minLen) paths.Add(path);
            }
        }
        paths.Sort((p, q) => q.Count.CompareTo(p.Count));
        var sb = new StringBuilder(); var pts = new StringBuilder();
        var rnd = new Random(1);
        using (var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp))
            using (var srcB = src.ToBitmap())
            using (var f = new Font("Segoe UI", 10, FontStyle.Bold))
            {
                var cm = new ColorMatrix(); cm.Matrix33 = 0.28f; var ia = new ImageAttributes(); ia.SetColorMatrix(cm);
                g.Clear(Color.White);
                g.DrawImage(srcB, new Rectangle(0, 0, W, H), 0, 0, W, H, GraphicsUnit.Pixel, ia);
                for (int pi = 0; pi < paths.Count; pi++)
                {
                    var p = paths[pi]; int n = p.Count;
                    var col = Color.FromArgb(255, rnd.Next(30, 220), rnd.Next(30, 220), rnd.Next(30, 220));
                    using (var br = new SolidBrush(col)) foreach (int i in p) g.FillRectangle(br, i % W - 1, i / W - 1, 3, 3);
                    int mid = p[n / 2];
                    g.DrawString(pi.ToString(), f, Brushes.Black, mid % W + 3, mid / W + 3);
                    g.DrawString(pi.ToString(), f, new SolidBrush(col), mid % W + 2, mid / W + 2);
                    // fits
                    double sx = 0, sy = 0; foreach (int i in p) { sx += i % W; sy += i / W; } double mx = sx / n, my = sy / n;
                    double sxx = 0, syy = 0, sxy = 0; foreach (int i in p) { double dx = i % W - mx, dy = i / W - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy; }
                    double ang = 0.5 * Math.Atan2(2 * sxy, sxx - syy); double ux = Math.Cos(ang), uy = Math.Sin(ang);
                    double lrms = 0; foreach (int i in p) { double dx = i % W - mx, dy = i / W - my; double d = -dx * uy + dy * ux; lrms += d * d; } lrms = Math.Sqrt(lrms / n);
                    // Kasa circle fit on centred coords
                    double Suu = 0, Svv = 0, Suv = 0, Suuu = 0, Svvv = 0, Suvv = 0, Svuu = 0;
                    foreach (int i in p) { double u = i % W - mx, v = i / W - my; Suu += u * u; Svv += v * v; Suv += u * v; Suuu += u * u * u; Svvv += v * v * v; Suvv += u * v * v; Svuu += v * u * u; }
                    double det = Suu * Svv - Suv * Suv; double ccx = mx, ccy = my, rr = 0, crms = 0;
                    if (Math.Abs(det) > 1e-6)
                    {
                        double bu = 0.5 * (Suuu + Suvv), bv = 0.5 * (Svvv + Svuu);
                        double uc = (bu * Svv - bv * Suv) / det, vc = (bv * Suu - bu * Suv) / det;
                        ccx = uc + mx; ccy = vc + my; rr = Math.Sqrt(uc * uc + vc * vc + (Suu + Svv) / n);
                        foreach (int i in p) { double d = Math.Sqrt(Math.Pow(i % W - ccx, 2) + Math.Pow(i / W - ccy, 2)) - rr; crms += d * d; }
                        crms = Math.Sqrt(crms / n);
                    }
                    int a0 = p[0], a1 = p[n - 1];
                    // which way does it bend: signed turn from start->mid->end
                    double t1x = mid % W - a0 % W, t1y = mid / W - a0 / W, t2x = a1 % W - mid % W, t2y = a1 / W - mid / W;
                    double turn = Math.Atan2(t1x * t2y - t1y * t2x, t1x * t2x + t1y * t2y) * 180 / Math.PI;
                    sb.AppendFormat("#{0,-3} len {1,4}  ({2},{3}) -> ({4},{5}) mid ({6},{7})  line {8:0}deg rms {9:0.0}  circle c=({10:0},{11:0}) r={12:0} rms {13:0.0}  turn {14:0}deg\n",
                        pi, n, a0 % W, a0 / W, a1 % W, a1 / W, mid % W, mid / W, ang * 180 / Math.PI, lrms, ccx, ccy, rr, crms, turn);
                    // every ~6 px: x, y, stroke width, core darkness (measured across the local normal)
                    pts.AppendFormat("#{0}:", pi);
                    for (int k = 0; k < n; k += 6)
                    {
                        int k0 = Math.Max(0, k - 4), k1 = Math.Min(n - 1, k + 4);
                        double tx = p[k1] % W - p[k0] % W, ty = p[k1] / W - p[k0] / W, tl = Math.Sqrt(tx * tx + ty * ty); if (tl < 1e-9) continue;
                        double sw, sc; Stroke(Lsrc, W, H, p[k] % W, p[k] / W, -ty / tl, tx / tl, out sw, out sc);
                        pts.AppendFormat(" {0},{1},{2:0},{3:0.00}", p[k] % W, p[k] / W, sw, sc);
                    }
                    pts.Append("\n");
                }
            }
            bmp.Save(overlayPath, ImageFormat.Png);
        }
        System.IO.File.WriteAllText(pointsPath, pts.ToString());
        return string.Format("{0} curves >= {1} px\n", paths.Count, minLen) + sb.ToString();
    }

    // Outlines of the dark regions (lum < thr) with at least minArea px, as polygons: the outer boundary
    // traced pixel by pixel (Moore neighbourhood), kept every `step` boundary pixels. One line per region:
    // "area: x,y x,y ...".
    public static string DarkOutlines(Img src, float thr, int minArea, int step)
    {
        int W = src.W, H = src.H; var on = new bool[W * H];
        for (int i = 0; i < W * H; i++) on[i] = src.L(i) < thr;
        var lab = new int[W * H]; int nl = 0; var sb = new StringBuilder();
        var q = new Stack<int>();
        for (int s = 0; s < W * H; s++)
        {
            if (!on[s] || lab[s] != 0) continue;
            nl++; int area = 0; q.Push(s); lab[s] = nl;
            while (q.Count > 0)
            {
                int i = q.Pop(); area++; int x = i % W, y = i / W;
                for (int k = 0; k < 8; k++)
                {
                    int xx = x + NX[k], yy = y + NY[k]; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
                    int j = yy * W + xx; if (on[j] && lab[j] == 0) { lab[j] = nl; q.Push(j); }
                }
            }
            if (area < minArea) continue;
            // s is the first pixel in raster order: its west neighbour is outside. Moore tracing.
            int[] dx = { -1, -1, 0, 1, 1, 1, 0, -1 }, dy = { 0, -1, -1, -1, 0, 1, 1, 1 };   // W, NW, N, NE, E, SE, S, SW
            Func<int, int, bool> inside = (x, y) => x >= 0 && y >= 0 && x < W && y < H && lab[y * W + x] == nl;
            // neighbours run clockwise on screen; after a move in direction d the search starts one step
            // past the pixel we came from, (d + 5) % 8. Start as if we had arrived moving east.
            int cx = s % W, cy = s / W, dir = 4; var bx = new List<int>(); var by = new List<int>();
            int sx0 = cx, sy0 = cy; int guard = 0;
            do
            {
                bx.Add(cx); by.Add(cy);
                int start = (dir + 5) % 8; bool moved = false;
                for (int t = 0; t < 8; t++)
                {
                    int d = (start + t) % 8; int nx = cx + dx[d], ny = cy + dy[d];
                    if (inside(nx, ny)) { cx = nx; cy = ny; dir = d; moved = true; break; }
                }
                if (!moved) break;
                guard++;
            } while ((cx != sx0 || cy != sy0) && guard < 200000);
            sb.AppendFormat("{0}:", area);
            for (int k = 0; k < bx.Count; k += step) sb.AppendFormat(" {0},{1}", bx[k], by[k]);
            sb.Append("\n");
        }
        return sb.ToString();
    }

    // ---------- fitting a dented globe + camera to traced lines ----------
    // Params p: 0 CamX, 1 CamY, 2 CamZ, 3 LookZ, 4 Roll(deg), 5 Focal, 6 Rb, 7 Depth, 8 FunnelW.
    // The impact (pole) is at the origin, the ball's centre at (0,0,Rb), the funnel pulls +z.
    // The point (0,0,fistZ) is anchored at (ax, ay) on screen, as in recreate_ref3d.ps1.
    public class GlobeFit
    {
        public double[] P; public double FistZ = 0.6, Ax = 601, Ay = 395, AMaxDeg = 85;
        public List<double[]> RefPts = new List<double[]>();   // x, y, tx, ty, family (0 spoke, 1 ring), line id
        public List<string> RefNames = new List<string>();
        double[] f = new double[3], r = new double[3], u = new double[3]; double ox, oy;

        void Basis()
        {
            double cx = P[0], cy = P[1], cz = P[2];
            double fx = -cx, fy = -cy, fz = P[3] - cz; double l = Math.Sqrt(fx * fx + fy * fy + fz * fz); f[0] = fx / l; f[1] = fy / l; f[2] = fz / l;
            double rx = f[2], ry = 0, rz = -f[0]; l = Math.Sqrt(rx * rx + rz * rz); rx /= l; rz /= l;     // cross(up, f)
            double ux = f[1] * rz - f[2] * ry, uy = f[2] * rx - f[0] * rz, uz = f[0] * ry - f[1] * rx;  // cross(f, r)
            double a = P[4] * Math.PI / 180, ca = Math.Cos(a), sa = Math.Sin(a);
            r[0] = rx * ca + ux * sa; r[1] = ry * ca + uy * sa; r[2] = rz * ca + uz * sa;
            u[0] = -rx * sa + ux * ca; u[1] = -ry * sa + uy * ca; u[2] = -rz * sa + uz * ca;
            double[] q = Cam(0, 0, FistZ);
            ox = Ax - P[5] * q[0] / q[2]; oy = Ay + P[5] * q[1] / q[2];
        }
        double[] Cam(double x, double y, double z)
        {
            double vx = x - P[0], vy = y - P[1], vz = z - P[2];
            return new double[] { vx * r[0] + vy * r[1] + vz * r[2], vx * u[0] + vy * u[1] + vz * u[2], vx * f[0] + vy * f[1] + vz * f[2] };
        }
        public double[] Surf(double a, double ph)
        {
            double Rb = P[6]; double sa = Math.Sin(a);
            double x = Rb * sa * Math.Cos(ph), y = Rb * sa * Math.Sin(ph), z = Rb * (1 - Math.Cos(a));
            double dz = P[7] * Math.Exp(-(x * x + y * y) / (P[8] * P[8]));
            return new double[] { x, y, z + dz, dz };
        }
        // screen x, y, depth, visible(1/0)
        public double[] Screen(double a, double ph)
        {
            var s = Surf(a, ph); var c = Cam(s[0], s[1], s[2]);
            if (c[2] < 0.05) return new double[] { 0, 0, c[2], 0 };
            double sx = ox + P[5] * c[0] / c[2], sy = oy - P[5] * c[1] / c[2];
            // front-facing on the undented ball, or inside the funnel
            double nx = s[0], ny = s[1], nz = s[2] - s[3] - P[6];
            double vis = (nx * (P[0] - s[0]) + ny * (P[1] - s[1]) + nz * (P[2] - s[2])) > 0 || s[3] > 0.15 ? 1 : 0;
            return new double[] { sx, sy, c[2], vis };
        }
        public Dictionary<int, List<double>> Where = new Dictionary<int, List<double>>();
        // For each traced line: where it lies on the globe (median polar angle a and azimuth, degrees).
        public string Places()
        {
            string rep; Where.Clear(); Cost(out rep);
            var sb = new StringBuilder();
            foreach (var kv in Where)
            {
                var a = new List<double>(); var ph = new List<double>();
                for (int i = 0; i < kv.Value.Count; i += 2) { a.Add(kv.Value[i] * 180 / Math.PI); ph.Add(kv.Value[i + 1] * 180 / Math.PI); }
                a.Sort(); ph.Sort();
                sb.AppendFormat("{0,-5} a {1,5:0.0} deg (range {2:0.0}-{3:0.0})   azimuth {4,6:0.0} deg (range {5:0.0}-{6:0.0})\n",
                    RefNames[kv.Key], a[a.Count / 2], a[0], a[a.Count - 1], ph[ph.Count / 2], ph[0], ph[ph.Count - 1]);
            }
            return sb.ToString();
        }
        public double Cost(out string report)
        {
            Basis();
            int NA = 110, NP = 180; double aMax = AMaxDeg * Math.PI / 180, da = 0.004, dp = 0.004;
            // bucket samples: cell 16 px
            var buckets = new Dictionary<long, List<double[]>>();
            for (int i = 1; i <= NA; i++)
            {
                double a = aMax * Math.Pow(i / (double)NA, 1.6);
                for (int j = 0; j < NP; j++)
                {
                    double ph = 2 * Math.PI * j / NP; var s = Screen(a, ph); if (s[3] < 0.5) continue;
                    if (s[0] < -50 || s[1] < -50 || s[0] > 1330 || s[1] > 770) continue;
                    var sp = Screen(a, ph + dp); var sm = Screen(a, ph - dp); var ap = Screen(a + da, ph); var am = Screen(Math.Max(1e-4, a - da), ph);
                    double rx = sp[0] - sm[0], ry = sp[1] - sm[1], mx = ap[0] - am[0], my = ap[1] - am[1];
                    double rl = Math.Sqrt(rx * rx + ry * ry), ml = Math.Sqrt(mx * mx + my * my); if (rl < 1e-9 || ml < 1e-9) continue;
                    long key = ((long)Math.Floor(s[0] / 16) << 20) ^ (long)(Math.Floor(s[1] / 16) + 1000);
                    List<double[]> lst; if (!buckets.TryGetValue(key, out lst)) { lst = new List<double[]>(); buckets[key] = lst; }
                    lst.Add(new double[] { s[0], s[1], rx / rl, ry / rl, mx / ml, my / ml, a, ph });
                }
            }
            double total = 0; int n = 0; var per = new Dictionary<int, double[]>();
            foreach (var q in RefPts)
            {
                double best = 1e18; double[] bs = null;
                long bx = (long)Math.Floor(q[0] / 16), by = (long)Math.Floor(q[1] / 16);
                for (long ix = bx - 3; ix <= bx + 3; ix++) for (long iy = by - 3; iy <= by + 3; iy++)
                    {
                        List<double[]> lst; if (!buckets.TryGetValue((ix << 20) ^ (iy + 1000), out lst)) continue;
                        foreach (var s in lst) { double d = (s[0] - q[0]) * (s[0] - q[0]) + (s[1] - q[1]) * (s[1] - q[1]); if (d < best) { best = d; bs = s; } }
                    }
                if (bs != null) { List<double> la; if (!Where.TryGetValue((int)q[5], out la)) { la = new List<double>(); Where[(int)q[5]] = la; } la.Add(bs[6]); la.Add(bs[7]); }
                double err;
                if (bs == null) err = 1.0;                                     // no surface under this line
                else
                {
                    double dx = q[4] < 0.5 ? bs[4] : bs[2], dy = q[4] < 0.5 ? bs[5] : bs[3];
                    double dot = q[2] * dx + q[3] * dy; err = 1 - dot * dot;    // sin^2 of the angle
                }
                total += err; n++;
                double[] acc; if (!per.TryGetValue((int)q[5], out acc)) { acc = new double[2]; per[(int)q[5]] = acc; }
                acc[0] += err; acc[1] += 1;
            }
            var sb = new StringBuilder();
            foreach (var kv in per) sb.AppendFormat("  {0,-5} mean angle error {1,5:0.0} deg\n", RefNames[kv.Key], Math.Asin(Math.Sqrt(Math.Min(1, kv.Value[0] / kv.Value[1]))) * 180 / Math.PI);
            report = sb.ToString();
            return total / Math.Max(1, n);
        }
        // Coordinate descent with shrinking steps from the start params.
        public string Fit(double[] steps, int rounds)
        {
            string rep; double best = Cost(out rep); var log = new StringBuilder();
            log.AppendFormat("start cost {0:0.0000}\n", best);
            var st = (double[])steps.Clone();
            for (int round = 0; round < rounds; round++)
            {
                bool improved = false;
                for (int k = 0; k < P.Length; k++)
                {
                    if (st[k] == 0) continue;
                    foreach (double sgn in new double[] { 1, -1 })
                    {
                        double keep = P[k]; P[k] = keep + sgn * st[k];
                        if (P[5] < 150 || P[6] < 2 || P[8] < 0.3 || P[7] < 0) { P[k] = keep; continue; }
                        double c = Cost(out rep);
                        if (c < best - 1e-6) { best = c; improved = true; break; }
                        P[k] = keep;
                    }
                }
                if (!improved) { for (int k = 0; k < st.Length; k++) st[k] *= 0.5; }
            }
            Cost(out rep);
            log.AppendFormat("end cost {0:0.0000}  (mean angle error {1:0.0} deg)\nparams:", best, Math.Asin(Math.Sqrt(best)) * 180 / Math.PI);
            string[] names = { "CamX", "CamY", "CamZ", "LookZ", "Roll", "Focal", "Rb", "Depth", "FunnelW" };
            for (int k = 0; k < P.Length; k++) log.AppendFormat(" {0}={1:0.###}", names[k], P[k]);
            log.Append("\n").Append(rep);
            return log.ToString();
        }
    }

    // Value noise laid out in (angle, ln distance) round (cx, cy): blobs already stretched outward.
    // angCells cells round the circle; radCell = cell size in ln(1 + r/10).
    public static void PolarGrain(Img img, float cx, float cy, float amp, int angCells, float radCell, int seed)
    {
        PolarGrainShift(img, cx, cy, amp, angCells, radCell, seed, 0f);
    }

    // As PolarGrain, the pattern pushed outward by `shift` cells (in ln distance): animating shift makes the
    // blobs fly outward, faster the further out they are.
    public static void PolarGrainShift(Img img, float cx, float cy, float amp, int angCells, float radCell, int seed, float shift)
    {
        var rnd = new Random(seed); int rc = 80; var g = new float[angCells * rc];
        for (int i = 0; i < g.Length; i++) g[i] = (float)(rnd.NextDouble() * 2 - 1);
        for (int y = 0; y < img.H; y++)
            for (int x = 0; x < img.W; x++)
            {
                double a = (Math.Atan2(y - cy, x - cx) + Math.PI) / (2 * Math.PI) * angCells;
                double r = Math.Max(0, Math.Log(1 + Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / 10) / radCell - shift);
                int ia = (int)Math.Floor(a); double ta = a - ia; int ir = Math.Min(rc - 2, (int)Math.Floor(r)); double tr = Math.Min(1, r - ir);
                ta = ta * ta * (3 - 2 * ta); tr = tr * tr * (3 - 2 * tr);
                int a0 = ((ia % angCells) + angCells) % angCells, a1 = (a0 + 1) % angCells;
                double v = g[ir * angCells + a0] * (1 - ta) * (1 - tr) + g[ir * angCells + a1] * ta * (1 - tr) + g[(ir + 1) * angCells + a0] * (1 - ta) * tr + g[(ir + 1) * angCells + a1] * ta * tr;
                int i = y * img.W + x; float d = (float)(v * amp);
                img.R[i] += d; img.G[i] += d; img.B[i] += d;
            }
    }

    // Outward zoom blur whose sample path twists as it goes out (twist radians per unit of scale):
    // streaks that bend slightly, like a brushed burst.
    public static Img ZoomOutTwist(Img src, float cx, float cy, float amount, float twist, int samples)
    {
        var o = new Img(src.W, src.H);
        for (int y = 0; y < src.H; y++)
            for (int x = 0; x < src.W; x++)
            {
                float sr = 0, sg = 0, sb = 0; int n = 0; float dx = x - cx, dy = y - cy;
                for (int k = 0; k < samples; k++)
                {
                    float s = 1f + amount * k / (samples - 1f); double a = twist * (s - 1f);
                    float c = (float)Math.Cos(a), sn = (float)Math.Sin(a);
                    float px = cx + (dx * c - dy * sn) * s, py = cy + (dx * sn + dy * c) * s;
                    if (px < 0 || py < 0 || px > src.W - 1 || py > src.H - 1) break;
                    float r, g, b; src.Sample(px, py, out r, out g, out b);
                    sr += r; sg += g; sb += b; n++;
                }
                int i = y * src.W + x;
                if (n == 0) { o.R[i] = src.R[i]; o.G[i] = src.G[i]; o.B[i] = src.B[i]; continue; }
                o.R[i] = sr / n; o.G[i] = sg / n; o.B[i] = sb / n;
            }
        return o;
    }

    // Side by side at a common height with labels, and a crude similarity readout.
    public static string Side(string aPath, string bPath, string outPath, int height, string la, string lb)
    {
        var a = Img.Load(aPath); var b = Img.Load(bPath);
        int wa = a.W * height / a.H, wb = b.W * height / b.H;
        var ra = a.Resize(wa, height); var rb = b.Resize(wb, height);
        using (var canvas = new Bitmap(wa + wb + 12, height + 28, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(canvas))
            using (var ba = ra.ToBitmap())
            using (var bb = rb.ToBitmap())
            using (var f = new Font("Segoe UI", 11, FontStyle.Bold))
            {
                g.Clear(Color.FromArgb(40, 40, 44));
                g.DrawImage(ba, 0, 28); g.DrawImage(bb, wa + 12, 28);
                g.DrawString(la, f, Brushes.White, 6, 5); g.DrawString(lb, f, Brushes.White, wa + 18, 5);
            }
            canvas.Save(outPath, ImageFormat.Png);
        }
        // similarity on luminance at 160 px wide
        var sa = a.Resize(160, 160 * a.H / a.W); var sb2 = b.Resize(sa.W, sa.H);
        double diff = 0; var ha = new double[10]; var hb = new double[10];
        for (int i = 0; i < sa.W * sa.H; i++)
        {
            float x = sa.L(i), y = sb2.L(i); diff += Math.Abs(x - y);
            ha[Math.Min(9, (int)(x * 10))]++; hb[Math.Min(9, (int)(y * 10))]++;
        }
        double hd = 0; for (int k = 0; k < 10; k++) hd += Math.Abs(ha[k] - hb[k]);
        int n = sa.W * sa.H;
        return string.Format("mean |dlum| {0:0.000}  histogram L1 {1:0.000} (0 = same tones, 2 = opposite)\n", diff / n, hd / n);
    }
}
