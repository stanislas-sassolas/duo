"""Illustrations originales de Duo : fonds d'accueil (lieux de Paris) et icône
coccinelle. Tout est dessiné ici, sans image extérieure.

Usage : python tools/generate_art.py
Écrit assets/backgrounds/*.png et assets/icon/*.png.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BG_DIR = ROOT / "assets" / "backgrounds"
ICON_DIR = ROOT / "assets" / "icon"
FONT = ROOT / "assets" / "fonts" / "Fraunces.ttf"

W, H = 1080, 1920
S = 2  # sur-échantillonnage pour des bords lisses
SW, SH = W * S, H * S


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def gradient(top, bottom, w=SW, h=SH):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    t0, b0 = hexc(top), hexc(bottom)
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(t0[i] + (b0[i] - t0[i]) * t) for i in range(4))
        for x in range(w):
            px[x, y] = c
    return img


def fast_gradient(stops, w=SW, h=SH):
    """Dégradé vertical à plusieurs couleurs (liste de (position, hex))."""
    col = Image.new("RGBA", (1, h))
    px = col.load()
    for y in range(h):
        t = y / (h - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                k = (t - p0) / (p1 - p0 or 1)
                a, b = hexc(c0), hexc(c1)
                px[0, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(4))
                break
    return col.resize((w, h))


def finish(img, name):
    img = img.resize((W, H), Image.LANCZOS).convert("RGB")
    BG_DIR.mkdir(parents=True, exist_ok=True)
    img.save(BG_DIR / f"{name}.png", optimize=True)


def stars(d, n, area, color="#FFFFFF", seed=1, rmax=5):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = area
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        r = rnd.uniform(1.5, rmax) * S
        d.ellipse((x - r, y - r, x + r, y + r), fill=hexc(color, rnd.randint(120, 230)))


def rooftops(d, base_y, color, seed, height=(160, 420), chimney=True):
    """Silhouette d'immeubles haussmanniens avec toits en zinc."""
    rnd = random.Random(seed)
    x = -40 * S
    while x < SW:
        w = rnd.randint(180, 320) * S
        h = rnd.randint(*height) * S
        top = base_y - h
        d.rectangle((x, top, x + w, SH), fill=color)
        # Toit mansardé
        d.polygon([(x - 6 * S, top), (x + 24 * S, top - 70 * S),
                   (x + w - 24 * S, top - 70 * S), (x + w + 6 * S, top)], fill=color)
        if chimney:
            for _ in range(rnd.randint(1, 3)):
                cx = rnd.randint(x + 40 * S, x + w - 60 * S)
                d.rectangle((cx, top - 120 * S, cx + 26 * S, top - 60 * S), fill=color)
        x += w + rnd.randint(-10, 10) * S


def windows(d, base_y, seed, lit="#FFD98A", n=60, area_h=380):
    rnd = random.Random(seed)
    for _ in range(n):
        x = rnd.randint(0, SW)
        y = base_y - rnd.randint(40, area_h) * S
        if rnd.random() < 0.55:
            d.rectangle((x, y, x + 22 * S, y + 34 * S), fill=hexc(lit, rnd.randint(150, 240)))


def eiffel(d, cx, base_y, height, color):
    """Tour Eiffel simplifiée : pieds, arche, plateformes, flèche."""
    h = height
    half = h * 0.26
    lvl1, lvl2, top = base_y - h * 0.27, base_y - h * 0.55, base_y - h * 0.9
    # Pieds (trapèze) avec arche découpée ensuite
    d.polygon([(cx - half, base_y), (cx - half * 0.36, lvl1), (cx + half * 0.36, lvl1),
               (cx + half, base_y)], fill=color)
    # Corps
    d.polygon([(cx - half * 0.40, lvl1), (cx - half * 0.14, lvl2),
               (cx + half * 0.14, lvl2), (cx + half * 0.40, lvl1)], fill=color)
    d.polygon([(cx - half * 0.15, lvl2), (cx - half * 0.03, top),
               (cx + half * 0.03, top), (cx + half * 0.15, lvl2)], fill=color)
    d.polygon([(cx - half * 0.02, top), (cx, base_y - h), (cx + half * 0.02, top)], fill=color)
    # Plateformes
    d.rectangle((cx - half * 0.48, lvl1 - h * 0.018, cx + half * 0.48, lvl1 + h * 0.012), fill=color)
    d.rectangle((cx - half * 0.2, lvl2 - h * 0.014, cx + half * 0.2, lvl2 + h * 0.008), fill=color)
    return (cx, base_y, half, lvl1)


def eiffel_arch(d, info, sky):
    cx, base_y, half, lvl1 = info
    aw = half * 0.62
    ah = (base_y - lvl1) * 0.62
    d.pieslice((cx - aw, base_y - ah, cx + aw, base_y + ah), 180, 360, fill=sky)


# ---------------------------------------------------------------- scènes

def scene_eiffel():
    img = fast_gradient([(0, "#F6C6B8"), (0.45, "#F7D9C4"), (0.75, "#EBC3CF"), (1, "#C9A9C8")])
    d = ImageDraw.Draw(img)
    # Soleil couchant
    sx, sy, r = SW * 0.3, SH * 0.52, 190 * S
    d.ellipse((sx - r, sy - r, sx + r, sy + r), fill=hexc("#FBE3B8"))
    # Nuages doux
    for cx, cy, s in [(0.72, 0.2, 1.0), (0.2, 0.3, 0.8), (0.8, 0.42, 0.7)]:
        for k in range(4):
            rr = (70 + k * 18) * S * s
            ox = (k - 1.5) * 90 * S * s
            d.ellipse((SW * cx + ox - rr, SH * cy - rr * 0.6, SW * cx + ox + rr, SH * cy + rr * 0.6),
                      fill=hexc("#FFF4EC", 170))
    info = eiffel(d, SW * 0.62, SH * 0.84, SH * 0.62, hexc("#8E6A86"))
    eiffel_arch(d, info, hexc("#E4C0CE"))
    rooftops(d, SH * 0.86, hexc("#A98AA6"), seed=3, height=(80, 220))
    rooftops(d, SH * 0.93, hexc("#8D7090"), seed=5, height=(60, 180))
    # Oiseaux
    for bx, by in [(0.25, 0.22), (0.3, 0.25), (0.36, 0.21)]:
        x, y = SW * bx, SH * by
        d.arc((x - 30 * S, y - 12 * S, x, y + 12 * S), 200, 340, fill=hexc("#8E6A86"), width=5 * S)
        d.arc((x, y - 12 * S, x + 30 * S, y + 12 * S), 200, 340, fill=hexc("#8E6A86"), width=5 * S)
    finish(img, "eiffel")


def scene_bakery():
    img = fast_gradient([(0, "#DDEBF3"), (0.6, "#F3E9DF"), (1, "#F3E9DF")])
    d = ImageDraw.Draw(img)
    # Immeuble crème
    x0, x1 = SW * 0.06, SW * 0.94
    top = SH * 0.12
    d.polygon([(x0 - 20 * S, top), (x0 + 60 * S, top - 150 * S), (x1 - 60 * S, top - 150 * S),
               (x1 + 20 * S, top)], fill=hexc("#8E9BAE"))
    for cx in (0.3, 0.7):
        d.rectangle((SW * cx - 40 * S, top - 110 * S, SW * cx + 40 * S, top - 20 * S), fill=hexc("#F4ECDF"))
    d.rectangle((x0, top, x1, SH), fill=hexc("#F4ECDF"))
    # Fenêtres avec balcons
    for row in range(3):
        y = top + (90 + row * 300) * S
        for col in range(3):
            cx = x0 + (x1 - x0) * (0.18 + col * 0.32)
            d.rectangle((cx - 70 * S, y, cx + 70 * S, y + 190 * S), fill=hexc("#B8C7D6"))
            d.line((cx, y, cx, y + 190 * S), fill=hexc("#F4ECDF"), width=6 * S)
            d.line((cx - 70 * S, y + 80 * S, cx + 70 * S, y + 80 * S), fill=hexc("#F4ECDF"), width=6 * S)
            by = y + 190 * S
            d.rectangle((cx - 95 * S, by, cx + 95 * S, by + 12 * S), fill=hexc("#4A4452"))
            for k in range(9):
                bx = cx - 90 * S + k * 22.5 * S
                d.line((bx, by, bx, by - 55 * S), fill=hexc("#4A4452"), width=4 * S)
            d.line((cx - 95 * S, by - 55 * S, cx + 95 * S, by - 55 * S), fill=hexc("#4A4452"), width=4 * S)
            # Géraniums
            for k in range(5):
                fx = cx - 70 * S + k * 35 * S
                d.ellipse((fx - 14 * S, by - 80 * S, fx + 14 * S, by - 52 * S), fill=hexc("#D9534F"))
    # Devanture
    shop_top = SH * 0.66
    d.rectangle((x0, shop_top, x1, SH), fill=hexc("#6E3A3A"))
    # Enseigne
    d.rectangle((x0 + 40 * S, shop_top + 30 * S, x1 - 40 * S, shop_top + 150 * S), fill=hexc("#F4ECDF"))
    try:
        font = ImageFont.truetype(str(FONT), 88 * S)
        text = "Boulangerie"
        tw = d.textlength(text, font=font)
        d.text(((SW - tw) / 2, shop_top + 42 * S), text, font=font, fill=hexc("#6E3A3A"))
    except OSError:
        pass
    # Auvent rouge à pois noirs (clin d'œil coccinelle)
    aw_top, aw_bot = shop_top + 170 * S, shop_top + 330 * S
    d.rectangle((x0 - 10 * S, aw_top, x1 + 10 * S, aw_bot), fill=hexc("#D62828"))
    n = 9
    for k in range(n):
        sx0 = x0 - 10 * S + k * (x1 - x0 + 20 * S) / n
        sx1 = sx0 + (x1 - x0 + 20 * S) / n
        d.pieslice((sx0, aw_bot - 50 * S, sx1, aw_bot + 50 * S), 0, 180, fill=hexc("#D62828"))
    rnd = random.Random(8)
    for _ in range(26):
        px_ = rnd.uniform(x0, x1)
        py_ = rnd.uniform(aw_top + 20 * S, aw_bot - 10 * S)
        r = rnd.uniform(12, 20) * S
        d.ellipse((px_ - r, py_ - r, px_ + r, py_ + r), fill=hexc("#1E1A1F"))
    # Vitrines avec croissants
    for (vx0, vx1) in [(0.1, 0.44), (0.56, 0.9)]:
        a, b = SW * vx0, SW * vx1
        vt, vb = aw_bot + 80 * S, SH * 0.95
        d.rectangle((a, vt, b, vb), fill=hexc("#F9E7C4"))
        for row in range(3):
            sy = vt + (row + 1) * (vb - vt) / 4
            d.line((a, sy, b, sy), fill=hexc("#C9A578"), width=5 * S)
            for k in range(4):
                cx = a + (k + 0.6) * (b - a) / 4.3
                d.ellipse((cx - 38 * S, sy - 36 * S, cx + 38 * S, sy - 4 * S), fill=hexc("#E0A45A"))
                d.arc((cx - 38 * S, sy - 36 * S, cx + 38 * S, sy - 4 * S), 200, 340,
                      fill=hexc("#B7773A"), width=4 * S)
    # Porte
    d.rectangle((SW * 0.46, aw_bot + 60 * S, SW * 0.54, SH), fill=hexc("#4F2828"))
    # Trottoir
    d.rectangle((0, SH * 0.965, SW, SH), fill=hexc("#C9C1B6"))
    finish(img, "boulangerie")


def scene_rooftops_night():
    img = fast_gradient([(0, "#1E2240"), (0.55, "#3A3564"), (1, "#5E4B78")])
    d = ImageDraw.Draw(img)
    stars(d, 120, (0, 0, SW, SH * 0.6), seed=2)
    # Lune
    mx, my, r = SW * 0.72, SH * 0.18, 120 * S
    glow = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((mx - r * 2, my - r * 2, mx + r * 2, my + r * 2), fill=hexc("#FFF3D6", 60))
    glow = glow.filter(ImageFilter.GaussianBlur(60 * S))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    d.ellipse((mx - r, my - r, mx + r, my + r), fill=hexc("#FFF3D6"))
    # Petite tour Eiffel au loin
    info = eiffel(d, SW * 0.24, SH * 0.72, SH * 0.36, hexc("#2A2548"))
    eiffel_arch(d, info, hexc("#4C4270"))
    d.ellipse((SW * 0.24 - 10 * S, SH * 0.36 - 10 * S, SW * 0.24 + 10 * S, SH * 0.36 + 10 * S),
              fill=hexc("#FFD98A"))
    rooftops(d, SH * 0.78, hexc("#2F2A4F"), seed=11)
    windows(d, SH * 0.78, seed=4)
    rooftops(d, SH * 0.9, hexc("#221E3B"), seed=13, height=(120, 300))
    windows(d, SH * 0.9, seed=6, n=40, area_h=260)
    finish(img, "toits_nuit")


def scene_seine():
    img = fast_gradient([(0, "#CFE3F0"), (0.55, "#F6E6DA"), (0.62, "#9FC2D6"), (1, "#7FA9C2")])
    d = ImageDraw.Draw(img)
    horizon = SH * 0.6
    # Notre-Dame au loin
    nd = hexc("#9A93A8")
    cx = SW * 0.62
    d.rectangle((cx - 190 * S, horizon - 330 * S, cx + 190 * S, horizon), fill=nd)
    for tx in (-190, 70):
        d.rectangle((cx + tx * S, horizon - 520 * S, cx + (tx + 120) * S, horizon), fill=nd)
    d.polygon([(cx - 10 * S, horizon - 330 * S), (cx + 10 * S, horizon - 330 * S),
               (cx, horizon - 620 * S)], fill=nd)
    d.ellipse((cx - 55 * S, horizon - 300 * S, cx + 55 * S, horizon - 190 * S), fill=hexc("#C9C3D4"))
    # Arbres des quais
    rnd = random.Random(9)
    for k in range(9):
        tx = k * SW / 8 + rnd.randint(-30, 30) * S
        tr = rnd.randint(90, 140) * S
        d.ellipse((tx - tr, horizon - tr * 1.6, tx + tr, horizon + 10 * S), fill=hexc("#8FAE8B", 235))
    d.rectangle((0, horizon - 30 * S, SW, horizon + 20 * S), fill=hexc("#D8CFC2"))
    # Pont de pierre
    bt = SH * 0.66
    d.rectangle((0, bt, SW, bt + 70 * S), fill=hexc("#D9CDBB"))
    for k in range(4):
        ax = k * SW / 3.2 - 40 * S
        aw = SW / 3.8
        d.rectangle((ax, bt + 70 * S, ax + aw, bt + 260 * S), fill=hexc("#D9CDBB"))
        d.pieslice((ax + 40 * S, bt + 90 * S, ax + aw - 40 * S, bt + 430 * S), 180, 360,
                   fill=hexc("#8FB6CC"))
    # Reflets
    for k in range(40):
        y = rnd.uniform(bt + 300 * S, SH)
        x = rnd.uniform(0, SW)
        d.line((x, y, x + rnd.randint(40, 120) * S, y), fill=hexc("#E8F1F6", 150), width=4 * S)
    # Petite péniche
    py_ = SH * 0.88
    d.rounded_rectangle((SW * 0.12, py_, SW * 0.52, py_ + 70 * S), radius=30 * S, fill=hexc("#6E3A3A"))
    d.rectangle((SW * 0.2, py_ - 60 * S, SW * 0.4, py_), fill=hexc("#F4ECDF"))
    d.rectangle((SW * 0.2, py_ - 60 * S, SW * 0.4, py_ - 44 * S), fill=hexc("#D62828"))
    finish(img, "seine")


def scene_louvre():
    img = fast_gradient([(0, "#F3D9E2"), (0.5, "#F8EBDD"), (1, "#EADFD2")])
    d = ImageDraw.Draw(img)
    ground = SH * 0.72
    # Palais du Louvre
    pal = hexc("#D8C4AE")
    d.rectangle((0, ground - 420 * S, SW, ground), fill=pal)
    d.rectangle((0, ground - 470 * S, SW, ground - 420 * S), fill=hexc("#8E9BAE"))
    for k in range(14):
        x = k * SW / 13
        d.rectangle((x + 20 * S, ground - 360 * S, x + 70 * S, ground - 230 * S), fill=hexc("#B9A48C"))
        d.rectangle((x + 20 * S, ground - 170 * S, x + 70 * S, ground - 40 * S), fill=hexc("#B9A48C"))
    # Pyramide de verre
    cx, base, half, top = SW * 0.5, ground + 60 * S, 420 * S, ground - 560 * S
    d.polygon([(cx - half, base), (cx, top), (cx + half, base)], fill=hexc("#BFD6E3", 235))
    for k in range(1, 9):
        t = k / 9
        y = top + (base - top) * t
        hw = half * t
        d.line((cx - hw, y, cx + hw, y), fill=hexc("#8FA9BA"), width=3 * S)
    for k in range(-8, 9):
        d.line((cx, top, cx + half * k / 8, base), fill=hexc("#8FA9BA"), width=3 * S)
    # Esplanade et bassins
    d.rectangle((0, base, SW, SH), fill=hexc("#E3D6C6"))
    for bx in (0.08, 0.62):
        d.rounded_rectangle((SW * bx, SH * 0.82, SW * (bx + 0.3), SH * 0.9), radius=20 * S,
                            fill=hexc("#A9C7D8"))
    stars(d, 14, (0, 0, SW, SH * 0.3), color="#FFFFFF", seed=21, rmax=3)
    finish(img, "louvre")


# ---------------------------------------------------------------- Noël

def snow(img, n, seed, max_r=9, blur=False):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rnd = random.Random(seed)
    for _ in range(n):
        x, y = rnd.uniform(0, SW), rnd.uniform(0, SH)
        r = rnd.uniform(2, max_r) * S
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rnd.randint(150, 240)))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(3 * S))
    img.alpha_composite(layer)


def snowy_rooftops(d, base_y, color, seed, height=(160, 420)):
    """Comme rooftops(), avec une couche de neige sur chaque toit."""
    rooftops(d, base_y, color, seed, height)
    rnd = random.Random(seed)
    x = -40 * S
    while x < SW:
        w = rnd.randint(180, 320) * S
        h = rnd.randint(*height) * S
        top = base_y - h
        d.polygon([(x + 12 * S, top - 58 * S), (x + 26 * S, top - 76 * S),
                   (x + w - 26 * S, top - 76 * S), (x + w - 12 * S, top - 58 * S)],
                  fill=hexc("#F4F7FB"))
        if True:  # garde le même tirage aléatoire que rooftops()
            for _ in range(rnd.randint(1, 3)):
                rnd.randint(x + 40 * S, x + w - 60 * S)
        x += w + rnd.randint(-10, 10) * S


def xmas_tree(d, cx, base_y, h, lights_seed):
    green = hexc("#2F6B4F")
    for k in range(3):
        top = base_y - h + k * h * 0.25
        half = h * (0.22 + k * 0.1)
        d.polygon([(cx, top), (cx - half, top + h * 0.38), (cx + half, top + h * 0.38)], fill=green)
    d.rectangle((cx - h * 0.05, base_y - h * 0.05, cx + h * 0.05, base_y + h * 0.05),
                fill=hexc("#6E3A3A"))
    rnd = random.Random(lights_seed)
    for _ in range(int(h / (18 * S))):
        t = rnd.uniform(0.15, 0.95)
        y = base_y - h + t * h
        x = cx + rnd.uniform(-1, 1) * h * 0.3 * t
        r = 6 * S
        d.ellipse((x - r, y - r, x + r, y + r),
                  fill=hexc(rnd.choice(["#FFD98A", "#FF8A8A", "#FFFFFF"])))
    st = 16 * S
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = st if i % 2 == 0 else st * 0.45
        pts.append((cx + rr * math.cos(a), base_y - h - 4 * S + rr * math.sin(a)))
    d.polygon(pts, fill=hexc("#FFD98A"))


def scene_xmas_eiffel():
    img = fast_gradient([(0, "#1B2748"), (0.6, "#33406E"), (1, "#56608F")])
    d = ImageDraw.Draw(img)
    stars(d, 60, (0, 0, SW, SH * 0.5), seed=31)
    info = eiffel(d, SW * 0.5, SH * 0.8, SH * 0.66, hexc("#2A2F55"))
    eiffel_arch(d, info, hexc("#45507F"))
    # Scintillement doré de la tour
    rnd = random.Random(5)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    cx, base_y, h = SW * 0.5, SH * 0.8, SH * 0.66
    for _ in range(420):
        t = rnd.uniform(0.02, 0.97)
        y = base_y - t * h
        half = h * 0.26 * max(0.02, (1 - t) ** 1.6)
        x = cx + rnd.uniform(-1, 1) * half
        r = rnd.uniform(3, 7) * S
        g.ellipse((x - r, y - r, x + r, y + r), fill=hexc("#FFD98A", rnd.randint(150, 255)))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2 * S)))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    snowy_rooftops(d, SH * 0.86, hexc("#2C3158"), seed=41, height=(80, 240))
    windows(d, SH * 0.86, seed=7, n=40, area_h=220)
    d.rectangle((0, SH * 0.93, SW, SH), fill=hexc("#E8EEF6"))
    for x in (0.12, 0.85):
        xmas_tree(d, SW * x, SH * 0.94, 300 * S, lights_seed=int(x * 100))
    snow(img, 260, seed=51, blur=True)
    snow(img, 160, seed=52, max_r=5)
    finish(img, "noel_eiffel")


def scene_xmas_bakery():
    """La boulangerie un soir d'hiver : vitrines dorées, guirlande, neige."""
    scene_bakery()
    img = Image.open(BG_DIR / "boulangerie.png").convert("RGBA").resize((SW, SH))
    img.alpha_composite(Image.new("RGBA", img.size, hexc("#1B2748", 150)))
    x0, x1 = SW * 0.06, SW * 0.94
    shop_top = SH * 0.66
    aw_top, aw_bot = shop_top + 170 * S, shop_top + 330 * S
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    for (vx0, vx1) in [(0.1, 0.44), (0.56, 0.9)]:
        g.rectangle((SW * vx0, aw_bot + 80 * S, SW * vx1, SH * 0.95), fill=hexc("#FFD98A", 120))
    for row in range(3):
        y = SH * 0.12 + (90 + row * 300) * S
        for col in range(3):
            if (row + col) % 2 == 0:
                cx = x0 + (x1 - x0) * (0.18 + col * 0.32)
                g.rectangle((cx - 70 * S, y, cx + 70 * S, y + 190 * S), fill=hexc("#FFD98A", 150))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18 * S)))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0 - 20 * S, aw_top - 26 * S, x1 + 20 * S, aw_top + 10 * S),
                        radius=18 * S, fill=hexc("#F4F7FB"))
    for row in range(3):
        by = SH * 0.12 + (90 + row * 300 + 190) * S - 55 * S
        for col in range(3):
            cx = x0 + (x1 - x0) * (0.18 + col * 0.32)
            d.rounded_rectangle((cx - 100 * S, by - 16 * S, cx + 100 * S, by + 4 * S),
                                radius=8 * S, fill=hexc("#F4F7FB"))
    rnd = random.Random(3)
    for k in range(34):
        t = k / 33
        x = x0 + (x1 - x0) * t
        y = shop_top + 162 * S + math.sin(t * math.pi * 6) * 10 * S
        r = 7 * S
        d.ellipse((x - r, y - r, x + r, y + r),
                  fill=hexc(rnd.choice(["#FFD98A", "#FF8A8A", "#9FE0B0"])))
    wx, wy, wr = SW * 0.5, aw_bot + 200 * S, 52 * S
    d.ellipse((wx - wr, wy - wr, wx + wr, wy + wr), outline=hexc("#2F6B4F"), width=22 * S)
    d.polygon([(wx - 20 * S, wy + wr - 4 * S), (wx, wy + wr + 18 * S),
               (wx + 20 * S, wy + wr - 4 * S)], fill=hexc("#D62828"))
    d.rectangle((0, SH * 0.955, SW, SH), fill=hexc("#E8EEF6"))
    xmas_tree(d, SW * 0.9, SH * 0.96, 230 * S, lights_seed=17)
    snow(img, 240, seed=61, blur=True)
    snow(img, 150, seed=62, max_r=5)
    finish(img, "noel_boulangerie")


def scene_xmas_rooftops():
    img = fast_gradient([(0, "#17203F"), (0.6, "#2E3A66"), (1, "#4E5A88")])
    d = ImageDraw.Draw(img)
    stars(d, 90, (0, 0, SW, SH * 0.55), seed=71)
    mx, my, r = SW * 0.28, SH * 0.16, 100 * S
    d.ellipse((mx - r, my - r, mx + r, my + r), fill=hexc("#F4F7FB"))
    snowy_rooftops(d, SH * 0.74, hexc("#27305A"), seed=81)
    windows(d, SH * 0.74, seed=9, n=55)
    snowy_rooftops(d, SH * 0.88, hexc("#1E2548"), seed=83, height=(140, 320))
    windows(d, SH * 0.88, seed=10, n=35, area_h=280)
    for x, y in [(0.2, 0.8), (0.64, 0.83), (0.86, 0.79)]:
        xmas_tree(d, SW * x, SH * y, 90 * S, lights_seed=int(x * 50))
    d.rectangle((0, SH * 0.95, SW, SH), fill=hexc("#E8EEF6"))
    snow(img, 300, seed=91, blur=True)
    snow(img, 180, seed=92, max_r=5)
    finish(img, "noel_toits")


# ---------------------------------------------------------------- icône

def ladybug(size, bg=None):
    """Coccinelle vue de dessus. bg=None → fond transparent."""
    k = 4
    s = size * k
    img = Image.new("RGBA", (s, s), hexc(bg) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = s / 2, s * 0.54
    r = s * 0.3
    black = hexc("#1E1A1F")
    red = hexc("#D62828")
    # Antennes
    for side in (-1, 1):
        d.line((cx + side * r * 0.12, cy - r * 1.05, cx + side * r * 0.45, cy - r * 1.45),
               fill=black, width=int(s * 0.018))
        e = s * 0.03
        ax, ay = cx + side * r * 0.45, cy - r * 1.45
        d.ellipse((ax - e, ay - e, ax + e, ay + e), fill=black)
    # Tête
    hr = r * 0.48
    d.ellipse((cx - hr, cy - r - hr * 0.9, cx + hr, cy - r + hr * 1.1), fill=black)
    # Corps
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=red)
    # Reflet
    d.ellipse((cx - r * 0.6, cy - r * 0.75, cx - r * 0.2, cy - r * 0.45), fill=hexc("#FFFFFF", 90))
    # Séparation des ailes
    d.line((cx, cy - r, cx, cy + r), fill=black, width=int(s * 0.02))
    # Points
    pr = r * 0.17
    for px_, py_ in [(-0.5, -0.3), (0.5, -0.3), (-0.55, 0.25), (0.55, 0.25),
                     (-0.3, 0.62), (0.3, 0.62)]:
        x, y = cx + px_ * r, cy + py_ * r
        d.ellipse((x - pr, y - pr, x + pr, y + pr), fill=black)
    # Yeux
    for side in (-1, 1):
        ex, ey = cx + side * hr * 0.4, cy - r - hr * 0.15
        er = hr * 0.18
        d.ellipse((ex - er, ey - er, ex + er, ey + er), fill=hexc("#FFFFFF"))
    return img.resize((size, size), Image.LANCZOS)


def icons():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    size = 1024
    # Icône complète : fond rose doux arrondi + coccinelle
    full = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=230, fill=255)
    full.paste(Image.new("RGBA", (size, size), hexc("#FBE3E6")), (0, 0), mask)
    bug = ladybug(int(size * 0.92))
    full.alpha_composite(bug, ((size - bug.width) // 2, (size - bug.height) // 2))
    full.save(ICON_DIR / "icon.png")
    # Premier plan adaptatif (zone sûre ~66 %)
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bug = ladybug(int(size * 0.66))
    fg.alpha_composite(bug, ((size - bug.width) // 2, (size - bug.height) // 2))
    fg.save(ICON_DIR / "icon_foreground.png")
    # Petite icône de notification : silhouette blanche de coccinelle
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for name, px_ in [("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)]:
        big = ladybug(px_ * 8)
        alpha = big.split()[3]
        white = Image.new("RGBA", big.size, (255, 255, 255, 0))
        white.putalpha(alpha)
        # Points et séparation en creux : on retire le noir du corps.
        r, g, b, a = big.split()
        dark = Image.eval(r, lambda v: 255 if v < 80 else 0)
        cut = Image.composite(Image.new("L", big.size, 0), alpha, dark)
        white.putalpha(cut)
        (res / f"drawable-{name}").mkdir(parents=True, exist_ok=True)
        white.resize((px_, px_), Image.LANCZOS).save(res / f"drawable-{name}" / "ic_stat_duo.png")


def main():
    scene_eiffel()
    scene_bakery()
    scene_rooftops_night()
    scene_seine()
    scene_louvre()
    scene_xmas_eiffel()
    scene_xmas_bakery()
    scene_xmas_rooftops()
    icons()
    for f in sorted(BG_DIR.glob("*.png")):
        print(f"{f.name}: {f.stat().st_size // 1024} Ko")


if __name__ == "__main__":
    main()
