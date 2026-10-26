"""Draws theme/wallpapers/festival-<name>.jpg, one dark picture per calendar festival.

The launcher shows festival-<name>.jpg through that festival's window (14 days either side, 3/1 for national
days, Christmas and New Year). Every picture stays dark (the clock, greeting and tiles sit on top), with the
motif kept to the edges and the top, away from the dock in the middle.
Run: python -I theme/make_festival_wallpapers.py [name ...]
"""
import math
import os
import random
import shutil
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1920, 1080
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "wallpapers")
REPO_DUSSEHRA = os.path.join(HERE, "wallpapers", "festival-dussehra.jpg")  # CleanYourTV themes/dussehra (MIT)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky(top, mid, bottom):
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        col.putpixel((0, y), lerp(top, mid, t / 0.6) if t < 0.6 else lerp(mid, bottom, (t - 0.6) / 0.4))
    return col.resize((W, H))


def glow(points, blur):
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for x, y, r, c in points:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def add(img, layer):
    return ImageChops.add(img, layer)


def bokeh(img, rnd, colours, n=34, top=0.7, strength=0.45):
    pts = [(rnd.randint(0, W), rnd.randint(0, int(H * top)), rnd.randint(18, 60),
            lerp((0, 0, 0), rnd.choice(colours), strength)) for _ in range(n)]
    return add(img, glow(pts, 22))


def string_lights(img, colours, y0=70, sag=46, loops=5):
    lights, dots = [], []
    for i in range(loops * 14 + 1):
        u = i / (loops * 14)
        x = 120 + u * (W - 240)
        y = y0 + sag * math.sin(math.pi * ((u * loops) % 1))
        c = colours[i % len(colours)]
        lights.append((x, y, 16, lerp((0, 0, 0), c, 0.55)))
        dots.append((x, y, 4, c))
    img = add(img, glow(lights, 12))
    return add(img, glow(dots, 1.2))


def diyas(img, x0, y0, n=5, gap=120):
    d = ImageDraw.Draw(img)
    flames, cores = [], []
    for k in range(n):
        cx, cy = x0 + k * gap, y0 - (k % 2) * 14
        d.pieslice((cx - 42, cy - 30, cx + 42, cy + 30), 0, 180, fill=(120, 52, 22))
        d.arc((cx - 42, cy - 30, cx + 42, cy + 30), 0, 180, fill=(190, 96, 40), width=3)
        flames.append((cx, cy - 18, 46, (150, 80, 18)))
        cores.append((cx, cy - 20, 9, (255, 214, 120)))
    img = add(img, glow(flames, 26))
    return add(img, glow(cores, 2.5))


def marigold_garland(img, rnd, y0=40, loops=4):
    pts = []
    for i in range(loops * 26 + 1):
        u = i / (loops * 26)
        x = 60 + u * (W - 120)
        y = y0 + 70 * math.sin(math.pi * ((u * loops) % 1))
        pts.append((x, y, 13, rnd.choice([(150, 70, 8), (160, 95, 10), (140, 40, 10)])))
    return add(img, glow(pts, 3))


# ---- one scene per festival --------------------------------------------------------------------------------

def diwali(rnd):
    img = sky((10, 6, 22), (34, 10, 24), (58, 18, 14))
    img = bokeh(img, rnd, [(200, 110, 25), (240, 150, 45)])
    img = string_lights(img, [(255, 196, 92), (255, 150, 70), (255, 222, 140)])
    img = diyas(img, 150, H - 120)
    d = ImageDraw.Draw(img)
    rx, ry = W - 260, H - 230
    for r in (150, 118, 86):
        d.ellipse((rx - r, ry - r, rx + r, ry + r), outline=(64, 30, 26), width=2)
    for a in range(0, 360, 30):
        x, y = rx + 118 * math.cos(math.radians(a)), ry + 118 * math.sin(math.radians(a))
        d.ellipse((x - 10, y - 10, x + 10, y + 10), outline=(84, 40, 26), width=2)
    return img


def holi(rnd):
    img = sky((12, 6, 20), (22, 8, 26), (26, 10, 22))
    colours = [(200, 40, 120), (230, 170, 30), (40, 170, 90), (50, 110, 220), (150, 60, 200)]
    clouds = []
    for corner in [(0, 0), (W, 0), (0, H), (W, H), (W * 0.5, 0)]:
        c = rnd.choice(colours)
        for _ in range(16):
            clouds.append((corner[0] + rnd.randint(-380, 380), corner[1] + rnd.randint(-260, 260),
                           rnd.randint(60, 170), lerp((0, 0, 0), c, 0.5)))
    img = add(img, glow(clouds, 60))
    specks = [(rnd.randint(0, W), rnd.randint(0, H), rnd.randint(2, 5), lerp((0, 0, 0), rnd.choice(colours), 0.8))
              for _ in range(260)]
    return add(img, glow(specks, 1.5))


def lohri(rnd):
    img = sky((8, 6, 16), (24, 10, 12), (60, 22, 8))
    fire = [(260 + rnd.randint(-90, 90), H - 110 - rnd.randint(0, 200), rnd.randint(40, 90),
             rnd.choice([(170, 70, 10), (200, 110, 20), (140, 40, 10)])) for _ in range(40)]
    img = add(img, glow(fire, 30))
    sparks = [(260 + rnd.randint(-260, 260), H - 300 - rnd.randint(0, 600), rnd.randint(2, 4), (255, 180, 80))
              for _ in range(120)]
    img = add(img, glow(sparks, 1.2))
    d = ImageDraw.Draw(img)
    for k in range(6):
        a = math.radians(-60 + k * 24)
        d.line((260 - 160 * math.cos(a), H - 40, 260 + 160 * math.cos(a), H - 120 - 60 * math.sin(a)),
               fill=(40, 20, 12), width=10)
    return img


def sankranti(rnd):
    img = sky((8, 18, 40), (20, 40, 70), (60, 50, 40))
    img = bokeh(img, rnd, [(80, 120, 180)], n=18, strength=0.3)
    d = ImageDraw.Draw(img)
    kites = [(1500, 230, 70, (200, 60, 60)), (1720, 420, 55, (230, 170, 40)), (1250, 150, 45, (60, 160, 120)),
             (300, 260, 50, (170, 80, 200)), (520, 120, 38, (230, 120, 40))]
    for x, y, s, c in kites:
        poly = [(x, y - s), (x + s * 0.8, y), (x, y + s * 1.1), (x - s * 0.8, y)]
        d.polygon(poly, fill=lerp((0, 0, 0), c, 0.75))
        d.line((x, y - s, x, y + s * 1.1), fill=lerp((0, 0, 0), c, 0.4), width=2)
        d.line((x - s * 0.8, y, x + s * 0.8, y), fill=lerp((0, 0, 0), c, 0.4), width=2)
        tail = [(x + 8 * math.sin(t / 6), y + s * 1.1 + t * 3) for t in range(0, 40)]
        d.line(tail, fill=lerp((0, 0, 0), c, 0.6), width=2)
        d.line((x, y + s * 1.1, x - 300, H), fill=(70, 70, 80), width=1)
    return img


def tricolour(rnd):
    img = sky((6, 8, 18), (10, 14, 26), (14, 18, 26))
    bands = [((180, 90, 20), -120), ((150, 150, 150), 0), ((20, 110, 40), 120)]
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for c, off in bands:
        pts = [(x, 180 + off + 60 * math.sin(x / 260)) for x in range(-20, W + 40, 20)]
        d.line(pts, fill=c, width=70)
    img = add(img, layer.filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * 0.55)))
    d = ImageDraw.Draw(img)
    cx, cy, r = W - 230, H - 230, 110
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(30, 40, 110), width=4)
    for k in range(24):
        a = math.radians(k * 15)
        d.line((cx, cy, cx + r * math.cos(a), cy + r * math.sin(a)), fill=(30, 40, 110), width=2)
    return img


def rakhi(rnd):
    img = sky((16, 6, 18), (30, 8, 28), (40, 12, 22))
    img = bokeh(img, rnd, [(220, 80, 140), (240, 170, 60)])
    d = ImageDraw.Draw(img)
    pts = [(x, 300 + 40 * math.sin(x / 180)) for x in range(0, W + 20, 20)]
    d.line(pts, fill=(150, 40, 70), width=8)
    d.line([(x, y + 10) for x, y in pts], fill=(170, 120, 30), width=3)
    cx, cy = W - 380, 300 + 40 * math.sin((W - 380) / 180)
    petals = [(cx + 70 * math.cos(math.radians(a)), cy + 70 * math.sin(math.radians(a)), 42, (150, 50, 90))
              for a in range(0, 360, 45)]
    img = add(img, glow(petals, 4))
    return add(img, glow([(cx, cy, 40, (200, 150, 40)), (cx, cy, 14, (255, 220, 120))], 3))


def janmashtami(rnd):
    img = sky((4, 10, 24), (8, 22, 40), (10, 30, 40))
    img = bokeh(img, rnd, [(40, 140, 160), (60, 90, 180)], n=24, strength=0.35)
    for k, (x, y, a) in enumerate([(W - 180, 260, -25), (W - 330, 200, -10), (180, 300, 25)]):
        layer = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(layer)
        dx, dy = math.sin(math.radians(a)), math.cos(math.radians(a))
        d.line((x, y, x + dx * 600, y + dy * 600), fill=(30, 80, 50), width=3)
        for t in range(12, 300, 9):
            for side in (-1, 1):
                px, py = x + dx * t, y + dy * t
                d.line((px, py, px + side * dy * 60 - dx * 20, py - side * dx * 60 - dy * 20), fill=(20, 70, 60), width=2)
        d.ellipse((x - 40, y - 55, x + 40, y + 55), fill=(20, 90, 80))
        d.ellipse((x - 26, y - 36, x + 26, y + 36), fill=(30, 50, 140))
        d.ellipse((x - 13, y - 18, x + 13, y + 18), fill=(12, 20, 60))
        img = add(img, layer.filter(ImageFilter.GaussianBlur(1.2)))
    return img


def ganesh(rnd):
    img = sky((16, 8, 10), (34, 14, 10), (50, 22, 10))
    img = marigold_garland(img, rnd)
    img = bokeh(img, rnd, [(200, 120, 30), (220, 90, 20)], n=26, strength=0.35)
    return diyas(img, W - 650, H - 120)


def navratri(rnd):
    img = sky((18, 4, 14), (34, 6, 20), (44, 10, 14))
    img = string_lights(img, [(255, 90, 90), (255, 200, 80), (120, 220, 120), (110, 160, 255), (230, 120, 255)])
    d = ImageDraw.Draw(img)
    for cx, cy in [(240, H - 260), (W - 260, H - 260)]:
        for a in (35, -35):
            r = math.radians(a)
            x1, y1 = cx - 170 * math.sin(r), cy - 170 * math.cos(r)
            x2, y2 = cx + 170 * math.sin(r), cy + 170 * math.cos(r)
            d.line((x1, y1, x2, y2), fill=(130, 60, 20), width=14)
            for t in (0.2, 0.5, 0.8):
                px, py = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
                d.line((px - 10 * math.cos(r), py + 10 * math.sin(r), px + 10 * math.cos(r), py - 10 * math.sin(r)),
                       fill=(200, 150, 40), width=6)
    return bokeh(img, rnd, [(200, 60, 120), (220, 160, 40)], n=20, strength=0.3)


def karwachauth(rnd):
    img = sky((6, 6, 18), (14, 10, 30), (30, 10, 24))
    cx, cy = W - 360, 290
    img = add(img, glow([(cx, cy, 230, (60, 55, 40))], 70))
    img = add(img, glow([(cx, cy, 120, (215, 205, 170))], 3))
    d = ImageDraw.Draw(img)
    d.ellipse((cx - 175, cy - 175, cx + 175, cy + 175), outline=(140, 90, 40), width=6)
    for k in range(0, 360, 12):
        x, y = cx + 160 * math.cos(math.radians(k)), cy + 160 * math.sin(math.radians(k))
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(150, 100, 50))
    stars = [(rnd.randint(0, W), rnd.randint(0, int(H * 0.6)), rnd.randint(1, 2), (180, 180, 200)) for _ in range(160)]
    img = add(img, glow(stars, 0.8))
    return diyas(img, 160, H - 120, n=3)


def gurpurab(rnd):
    img = sky((10, 8, 18), (26, 18, 20), (44, 30, 14))
    img = bokeh(img, rnd, [(220, 170, 60)], n=30, strength=0.4)
    for row, y in enumerate((H - 110, H - 200)):
        img = diyas(img, 120 + row * 60, y, n=6, gap=110)
    return string_lights(img, [(255, 210, 120), (255, 180, 80)], y0=60, sag=30)


def christmas(rnd):
    img = sky((4, 10, 20), (8, 20, 28), (14, 26, 26))
    img = string_lights(img, [(255, 80, 80), (110, 220, 120), (255, 210, 100), (120, 170, 255)])
    d = ImageDraw.Draw(img)
    cx, base = W - 280, H - 90
    for k in range(4):
        w, top = 260 - k * 55, base - 120 - k * 110
        d.polygon([(cx - w / 2, top + 150), (cx + w / 2, top + 150), (cx, top)], fill=(14, 60, 36))
    d.rectangle((cx - 20, base - 30, cx + 20, base + 10), fill=(60, 34, 18))
    img = add(img, glow([(cx, base - 470, 14, (255, 220, 120))], 4))
    snow = [(rnd.randint(0, W), rnd.randint(0, H), rnd.randint(2, 4), (150, 160, 170)) for _ in range(220)]
    return add(img, glow(snow, 1.3))


def newyear(rnd):
    img = sky((4, 4, 16), (10, 8, 26), (18, 12, 30))
    for cx, cy, c in [(300, 260, (230, 170, 60)), (W - 360, 220, (150, 120, 255)), (W * 0.55, 140, (120, 220, 200)),
                      (W - 200, 560, (255, 110, 150))]:
        sparks = []
        for k in range(48):
            a = math.radians(k * 7.5)
            for t in (0.4, 0.7, 1.0):
                r = 150 * t
                sparks.append((cx + r * math.cos(a), cy + r * math.sin(a), 3 if t < 1 else 4, lerp((0, 0, 0), c, t)))
        img = add(img, glow(sparks, 1.5))
        img = add(img, glow([(cx, cy, 120, lerp((0, 0, 0), c, 0.18))], 50))
    return img


SCENES = {
    "diwali": diwali, "holi": holi, "lohri": lohri, "sankranti": sankranti, "republic": tricolour,
    "independence": tricolour, "rakhi": rakhi, "janmashtami": janmashtami, "ganesh": ganesh,
    "navratri": navratri, "karwachauth": karwachauth, "gurpurab": gurpurab, "christmas": christmas,
    "newyear": newyear,
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names or list(SCENES) + ["dussehra"]:
        path = os.path.join(OUT, f"festival-{name}.jpg")
        if name == "dussehra":
            # CleanYourTV's own Dussehra picture (MIT), shipped as it is; nothing to draw.
            continue
        img = SCENES[name](random.Random(name))
        img.save(path, "JPEG", quality=86, optimize=True, progressive=True)
        print(path, os.path.getsize(path))


if __name__ == "__main__":
    main(sys.argv[1:])
