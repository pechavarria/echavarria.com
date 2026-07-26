using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Text;

public static class LogoAlpha2 {
  // Background test: bright AND achromatic. This catches a baked "fake
  // transparency" checkerboard (white 255 + gray ~192 squares) as one region,
  // while the crest's golds and navies are chromatic or dark and survive.
  static bool IsBg(byte[] buf, int i, int minBright, int maxChroma) {
    byte b = buf[i], g = buf[i + 1], r = buf[i + 2];
    int mn = Math.Min(r, Math.Min(g, b));
    int mx = Math.Max(r, Math.Max(g, b));
    return mn >= minBright && (mx - mn) <= maxChroma;
  }

  public static string Run(string src, string dst, int targetWidth, int keepUnder,
                           int minBright, int maxChroma) {
    using (var orig = new Bitmap(src)) {
      int w = targetWidth;
      int h = (int)Math.Round(orig.Height * (double)targetWidth / orig.Width);
      var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
      using (var gr = Graphics.FromImage(bmp)) {
        gr.InterpolationMode = InterpolationMode.HighQualityBicubic;
        gr.PixelOffsetMode = PixelOffsetMode.HighQuality;
        gr.Clear(Color.White);
        gr.DrawImage(orig, new Rectangle(0, 0, w, h));
      }
      var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      int stride = data.Stride;
      byte[] buf = new byte[stride * h];
      Marshal.Copy(data.Scan0, buf, 0, buf.Length);

      int[] label = new int[w * h];
      var area = new List<int>(); area.Add(0);
      var touches = new List<bool>(); touches.Add(false);
      // Count of mid-gray pixels per region. A baked checkerboard pocket is
      // ~half gray squares; real white artwork detail is uniformly white with
      // only a thin anti-aliased rim, so the ratio separates them cleanly.
      var grayish = new List<int>(); grayish.Add(0);
      var q = new Queue<int>();

      for (int start = 0; start < w * h; start++) {
        if (label[start] != 0) continue;
        int sx = start % w, sy = start / w;
        if (!IsBg(buf, sy * stride + sx * 4, minBright, maxChroma)) continue;
        int id = area.Count; area.Add(0); touches.Add(false); grayish.Add(0);
        label[start] = id; q.Enqueue(start);
        int cnt = 0, gray = 0; bool tb = false;
        while (q.Count > 0) {
          int p = q.Dequeue(); cnt++;
          int px = p % w, py = p / w;
          if (buf[py * stride + px * 4 + 1] <= 216) gray++;
          if (px == 0 || py == 0 || px == w - 1 || py == h - 1) tb = true;
          int[] nb = { px > 0 ? p - 1 : -1, px < w - 1 ? p + 1 : -1, py > 0 ? p - w : -1, py < h - 1 ? p + w : -1 };
          foreach (int n in nb) {
            if (n < 0 || label[n] != 0) continue;
            int nx = n % w, ny = n / w;
            if (!IsBg(buf, ny * stride + nx * 4, minBright, maxChroma)) continue;
            label[n] = id; q.Enqueue(n);
          }
        }
        area[id] = cnt; touches[id] = tb; grayish[id] = gray;
      }

      // A region is background if it reaches the border, is too big to be
      // artwork detail, or is checkerboard-textured.
      Func<int, bool> isBackground = id =>
        id != 0 && (touches[id] || area[id] > keepUnder
                    || (double)grayish[id] / area[id] > 0.22);

      var sb = new StringBuilder();
      var idx = new List<int>();
      for (int i = 1; i < area.Count; i++) idx.Add(i);
      idx.Sort((a, b) => area[b].CompareTo(area[a]));
      int cleared = 0, kept = 0, byTexture = 0;
      foreach (int id in idx) {
        if (isBackground(id)) {
          cleared++;
          if (!touches[id] && area[id] <= keepUnder) byTexture++;
        } else kept++;
      }
      sb.Append("regions=" + idx.Count + " cleared=" + cleared
                + " (checkerboard-textured=" + byTexture + ") kept=" + kept + " | ");

      int minX = w, minY = h, maxX = -1, maxY = -1;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int p = y * w + x, i = y * stride + x * 4;
          int id = label[p];
          byte a;
          if (isBackground(id)) a = 0;
          else {
            bool onEdge = false;
            int[] nb = { x > 0 ? p - 1 : -1, x < w - 1 ? p + 1 : -1, y > 0 ? p - w : -1, y < h - 1 ? p + w : -1 };
            foreach (int n in nb) {
              if (n >= 0 && isBackground(label[n])) onEdge = true;
            }
            byte bb = buf[i], gg = buf[i + 1], rr = buf[i + 2];
            int mn = Math.Min(rr, Math.Min(gg, bb));
            int mx = Math.Max(rr, Math.Max(gg, bb));
            // Feather only colourless near-background pixels on the boundary.
            if (onEdge && mn >= 150 && (mx - mn) <= 40) {
              a = (byte)Math.Max(0, 255 - (mn - 150) * 255 / (minBright - 150));
            } else a = 255;
          }
          buf[i + 3] = a;
          if (a > 8) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
        }
      }
      Marshal.Copy(buf, 0, data.Scan0, buf.Length);
      bmp.UnlockBits(data);
      minX = Math.Max(0, minX - 1); minY = Math.Max(0, minY - 1);
      maxX = Math.Min(w - 1, maxX + 1); maxY = Math.Min(h - 1, maxY + 1);
      using (var outBmp = bmp.Clone(new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1), PixelFormat.Format32bppArgb)) {
        outBmp.Save(dst, ImageFormat.Png);
        sb.Append("out " + outBmp.Width + "x" + outBmp.Height);
      }
      bmp.Dispose();
      return sb.ToString();
    }
  }

  public static void Composite(string src, string dst, int r, int g, int b) {
    using (var img = Image.FromFile(src))
    using (var bmp = new Bitmap(img.Width, img.Height))
    using (var gr = Graphics.FromImage(bmp)) {
      gr.Clear(Color.FromArgb(r, g, b));
      gr.DrawImage(img, 0, 0, img.Width, img.Height);
      bmp.Save(dst, ImageFormat.Png);
    }
  }
}
