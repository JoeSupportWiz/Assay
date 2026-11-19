#!/usr/bin/env python3
"""Compose README art from real simulator screenshots + brand assets.
Usage: python3 scripts/readme_art.py   (reads docs/app-screens, writes docs/brand/*-app.png)"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, "docs/app-screens/")
OUT = os.path.join(ROOT, "docs/brand/")
F = "/usr/share/fonts/inter/"
INK, INK2 = (17, 17, 19, 255), (107, 107, 114, 255)

def font(name, size): return ImageFont.truetype(F + name, size)

def fold_mark(h, color=INK):
    """Rasterise brand/svg/symbol.svg (viewBox x17-67, y5.5-77) at height h."""
    s = h / 71.5; w = int(50 * s) + 2
    im = Image.new("RGBA", (w * 4, int(h) * 4 + 4), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    svg = open(os.path.join(ROOT, "brand/svg/symbol.svg")).read()
    for path in re.findall(r'd="([^"]+)"', svg):
        pts, cur, start = [], None, None
        toks = re.findall(r"[MLQVHZ]|-?\d+\.?\d*", path)
        i = 0
        def P(x, y): return ((x - 17) * s * 4, (y - 5.5) * s * 4)
        while i < len(toks):
            c = toks[i]; i += 1
            if c == "M": cur = (float(toks[i]), float(toks[i+1])); i += 2; start = cur; pts.append(P(*cur))
            elif c == "L": cur = (float(toks[i]), float(toks[i+1])); i += 2; pts.append(P(*cur))
            elif c == "V": cur = (cur[0], float(toks[i])); i += 1; pts.append(P(*cur))
            elif c == "H": cur = (float(toks[i]), cur[1]); i += 1; pts.append(P(*cur))
            elif c == "Q":
                cx, cy, x, y = map(float, toks[i:i+4]); i += 4
                for t in [k / 8 for k in range(1, 9)]:
                    bx = (1-t)**2*cur[0] + 2*(1-t)*t*cx + t*t*x; by = (1-t)**2*cur[1] + 2*(1-t)*t*cy + t*t*y
                    pts.append(P(bx, by))
                cur = (x, y)
            elif c == "Z": pass
        d.polygon(pts, fill=color)
    return im.resize((w, int(h) + 1), Image.LANCZOS)

def rounded(im, r):
    m = Image.new("L", im.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, *im.size), r, fill=255)
    out = Image.new("RGBA", im.size); out.paste(im, (0, 0), m); return out

def phone(name, w):
    im = Image.open(S + name + ".png").convert("RGB"); h = int(im.height * w / im.width)
    im = im.resize((w, h), Image.LANCZOS)
    b = int(w * 0.035)
    bez = Image.new("RGBA", (w + 2*b, h + 2*b), (0, 0, 0, 0))
    ImageDraw.Draw(bez).rounded_rectangle((0, 0, w + 2*b - 1, h + 2*b - 1), int(w * 0.17) + b, fill=INK)
    bez.alpha_composite(rounded(im, int(w * 0.17)), (b, b)); return bez

def drop(canvas, im, xy, blur=50, off=36, alpha=80):
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    m = Image.new("RGBA", im.size, (40, 30, 90, 0)); m.putalpha(im.split()[3].point(lambda a: alpha if a else 0))
    sh.paste(m, (xy[0], xy[1] + off), m)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur))); canvas.alpha_composite(im, xy)

def backdrop(W, H):
    bg = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / H; d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip((243, 242, 238), (236, 232, 248))) + (255,))
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
    gd.ellipse((int(W*.5), -int(H*.25), int(W*1.05), int(H*.9)), fill=(220, 209, 255, 190))
    gd.ellipse((int(W*.7), int(H*.45), int(W*1.15), int(H*1.3)), fill=(189, 243, 215, 170))
    gd.ellipse((-int(W*.1), int(H*.6), int(W*.3), int(H*1.4)), fill=(196, 230, 255, 150))
    gd.ellipse((int(W*.25), -int(H*.3), int(W*.5), int(H*.3)), fill=(255, 229, 138, 90))
    bg.alpha_composite(g.filter(ImageFilter.GaussianBlur(int(W * 0.05))))
    return bg

def pill(d, x, y, text, fill, f):
    tw = d.textlength(text, font=f); h = int(f.size * 1.9)
    d.rounded_rectangle((x, y, x + tw + h, y + h), h // 2, fill=fill)
    d.text((x + h / 2, y + h / 2), text, font=f, fill=INK, anchor="lm")
    return x + tw + h + int(f.size * 0.6)

# ---------- Hero ----------
W, H = 3200, 1500
bg = backdrop(W, H); d = ImageDraw.Draw(bg)
mk = fold_mark(170); bg.alpha_composite(mk, (160, 250))
d.text((160 + mk.width + 50, 250 + 85), "Assay", font=font("InterDisplay-ExtraBold.otf", 210), fill=INK, anchor="lm")
d.text((164, 560), "Customise, sign and inspect", font=font("InterDisplay-Bold.otf", 86), fill=INK)
d.text((164, 665), "your iPhone — shown its work.", font=font("InterDisplay-Bold.otf", 86), fill=INK2)
f = font("Inter-Bold.otf", 34); x = 166
for t, c in [("Reversible", (189, 243, 215, 255)), ("Observed", (196, 230, 255, 255)), ("Inferred · 82%", (220, 209, 255, 255)), ("Caution", (255, 229, 138, 255))]:
    x = pill(d, x, 840, t, c, f)
d.text((168, 1000), "Real app · rendered in the iOS Simulator", font=font("Inter-Medium.otf", 34), fill=INK2)
for name, cx, y, w, rot in [("04-lab-light", 2050, 300, 500, 7), ("01-home-dark", 2900, 300, 500, -7), ("01-home-light", 2470, 150, 560, 0)]:
    p = phone(name, w).rotate(rot, resample=Image.BICUBIC, expand=True)
    drop(bg, p, (cx - p.width // 2, y))
bg.convert("RGB").save(OUT + "hero-app.png", optimize=True)

# ---------- Social preview (1280x640 @2x) ----------
W, H = 2560, 1280
bg = backdrop(W, H); d = ImageDraw.Draw(bg)
mk = fold_mark(150); bg.alpha_composite(mk, (150, 330))
d.text((150 + mk.width + 44, 330 + 75), "Assay", font=font("InterDisplay-ExtraBold.otf", 180), fill=INK, anchor="lm")
d.text((154, 600), "Customise, sign and inspect", font=font("InterDisplay-Bold.otf", 72), fill=INK)
d.text((154, 690), "your iPhone — shown its work.", font=font("InterDisplay-Bold.otf", 72), fill=INK2)
for name, cx, y, w, rot in [("01-home-dark", 2250, 230, 440, -6), ("01-home-light", 1830, 150, 480, 0)]:
    p = phone(name, w).rotate(rot, resample=Image.BICUBIC, expand=True); drop(bg, p, (cx - p.width // 2, y))
bg.convert("RGB").save(OUT + "social-preview-app.png", optimize=True)

# ---------- Themes strip ----------
names = ["01-home-light", "01-home-dark", "01-home-millennium", "01-home-pinstripe", "01-home-wallpaper"]
labels = ["Light", "Dark", "Millennium", "Pinstripe", "Wallpaper match"]
w = 500; gap = 70; W = 5 * (w + 36) + 6 * gap; H = 1260
strip = backdrop(W, H); d = ImageDraw.Draw(strip); f = font("InterDisplay-Bold.otf", 46)
for i, n in enumerate(names):
    p = phone(n, w); x = gap + i * (p.width + gap); drop(strip, p, (x, 40), blur=34, off=24, alpha=70)
    d.text((x + p.width / 2, p.height + 110), labels[i], font=f, fill=INK, anchor="mm")
strip.convert("RGB").save(OUT + "themes-app.png", optimize=True)

# ---------- Flow strip: onboarding → home → lab → studio → more ----------
names = ["00-onboarding-light", "01-home-light", "04-lab-light", "03-studio-light", "05-more-dark"]
labels = ["Onboarding", "Home", "Lab · passport", "Studio", "More"]
strip = backdrop(W, H); d = ImageDraw.Draw(strip)
for i, n in enumerate(names):
    p = phone(n, w); x = gap + i * (p.width + gap); drop(strip, p, (x, 40), blur=34, off=24, alpha=70)
    d.text((x + p.width / 2, p.height + 110), labels[i], font=f, fill=INK, anchor="mm")
strip.convert("RGB").save(OUT + "screens-app.png", optimize=True)

# ---------- Design vs built ----------
W, H = 1600, 1520
dv = backdrop(W, H); d = ImageDraw.Draw(dv)
for i, (src, lbl) in enumerate([(os.path.join(ROOT, "docs/screens/01-home-light.png"), "Design"), (S + "01-home-light.png", "Built")]):
    im = Image.open(src).convert("RGB"); w = 620; h = int(im.height * w / im.width)
    im = rounded(im.resize((w, h), Image.LANCZOS), 96); x = 120 + i * (w + 120)
    drop(dv, im, (x, 60), blur=34, off=24, alpha=70)
    d.text((x + w / 2, 60 + h + 80), lbl, font=f, fill=INK, anchor="mm")
dv.convert("RGB").save(OUT + "design-vs-built.png", optimize=True)

for n in ["hero-app", "social-preview-app", "themes-app", "screens-app", "design-vs-built"]:
    p = OUT + n + ".png"; print(n, Image.open(p).size, os.path.getsize(p) // 1024, "KB")
