using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

public static class MakeIcon {
  static GraphicsPath Rounded(RectangleF r, float rad) {
    var p = new GraphicsPath();
    float d = rad * 2;
    p.AddArc(r.X, r.Y, d, d, 180, 90);
    p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
    p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
    p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
    p.CloseFigure();
    return p;
  }

  public static string Png(string dst, int size) {
    using (var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.Clear(Color.Transparent);

      float s = size / 100f;
      var full = new RectangleF(0, 0, size, size);

      using (var body = Rounded(full, 21 * s))
      using (var fill = new SolidBrush(ColorTranslator.FromHtml("#0b1120")))
        g.FillPath(fill, body);

      // gold gradient reused for the hairline and the letter
      using (var gold = new LinearGradientBrush(
                 new PointF(0, 0), new PointF(0, size),
                 ColorTranslator.FromHtml("#f6e3ad"),
                 ColorTranslator.FromHtml("#a87f2c"))) {
        var blend = new ColorBlend(3);
        blend.Colors = new[] {
          ColorTranslator.FromHtml("#f6e3ad"),
          ColorTranslator.FromHtml("#d8ae55"),
          ColorTranslator.FromHtml("#a87f2c")
        };
        blend.Positions = new[] { 0f, .45f, 1f };
        gold.InterpolationColors = blend;

        var innerRect = new RectangleF(5.5f * s, 5.5f * s, 89 * s, 89 * s);
        using (var inner = Rounded(innerRect, 16.5f * s))
        using (var pen = new Pen(gold, 3.5f * s))
          g.DrawPath(pen, inner);

        // Georgia is present on Windows; fall back if it ever is not.
        FontFamily fam;
        try { fam = new FontFamily("Georgia"); } catch { fam = FontFamily.GenericSerif; }
        using (fam)
        using (var font = new Font(fam, 62 * s, FontStyle.Bold, GraphicsUnit.Pixel))
        using (var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center }) {
          // nudge up slightly: glyph optical centre sits below the em box centre
          g.DrawString("E", font, gold, new RectangleF(0, -2 * s, size, size), fmt);
        }
      }

      bmp.Save(dst, ImageFormat.Png);
      return size + "x" + size;
    }
  }

  // Minimal ICO container wrapping a PNG payload (supported Vista onward).
  public static string Ico(string pngPath, string dst) {
    byte[] png = File.ReadAllBytes(pngPath);
    using (var fs = new FileStream(dst, FileMode.Create))
    using (var w = new BinaryWriter(fs)) {
      w.Write((short)0);            // reserved
      w.Write((short)1);            // type: icon
      w.Write((short)1);            // image count
      w.Write((byte)32);            // width  (32px)
      w.Write((byte)32);            // height
      w.Write((byte)0);             // palette size
      w.Write((byte)0);             // reserved
      w.Write((short)1);            // colour planes
      w.Write((short)32);           // bits per pixel
      w.Write(png.Length);          // payload bytes
      w.Write(22);                  // payload offset
      w.Write(png);
    }
    return new FileInfo(dst).Length + " bytes";
  }
}
