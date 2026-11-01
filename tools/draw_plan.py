# Draws the estate plan on the archaeologists' table (art/textures/plan.png) as an old architect's drawing:
# aged paper, sepia ink, hatched rock around the carved rooms, room names, scale bar, compass.
# Reads the rooms / doors the generator wrote on scenes/game.tscn. Your room is left off: the plan shows a corridor
# that ends in nothing (the archaeologists notice it). Run: python tools/draw_plan.py
import re
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SCENE = "scenes/game.tscn"
OUT = "art/textures/plan.png"
FONT = "fonts/Caveat.ttf"
W, H = 1800, 1200  # 3:2, the paper is 0.9 x 0.6 m
PX = 41  # px per metre
HIDDEN = {"YourRoom", "BonesRoom", "CatRoom"}
NAMES = {
    "CorridorV": "Сходи", "CorridorH": "Галерея", "FarLeft": "Управитель", "R1L": "Челядь", "R1R": "Комора",
    "R2L": "Нари", "R2R": "Туалетна", "R3L": "Майстерня", "R3R": "Кухня", "R4L": "Льох", "R4R": "Винний погріб",
    "RightTall": "Склеп", "PassageTop": "Прохід",
}
INK = (74, 48, 28)

text = open(SCENE, encoding="utf-8").read()
rect = r"Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)"
rooms = {n: tuple(map(float, r)) for n, *r in re.findall(r'"(\w+)": ' + rect, re.search(r"metadata/rooms = (.*)", text).group(1))}
doors = [tuple(map(float, r)) for r in re.findall(rect, re.search(r"metadata/doors = (.*)", text).group(1))]
shown = {n: r for n, r in rooms.items() if n not in HIDDEN}
x0 = min(r[0] for r in shown.values()); x1 = max(r[0] + r[2] for r in shown.values())
z0 = min(r[1] for r in shown.values()); z1 = max(r[1] + r[3] for r in shown.values())
ox = (W - (x1 - x0) * PX) / 2 - x0 * PX
oz = (H + 90 - (z1 - z0) * PX) / 2 - z0 * PX  # room for the title on top


def px(x, z): return (ox + x * PX, oz + z * PX)


# carved mask (rooms + doors), then the rock band around it
carved = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(carved)
for (x, z, w, h) in list(shown.values()) + doors:
    d.rectangle([px(x, z), px(x + w, z + h)], fill=255)
c = np.array(carved) > 0
band = np.array(carved.filter(ImageFilter.MaxFilter(23))) > 0  # ~0.27 m of wall drawn around the rooms
wall = band & ~c
edge = (np.array(carved.filter(ImageFilter.MaxFilter(5))) > 0) & ~c

# aged paper: warm base, blotches, fibres, darker rim
rng = np.random.default_rng(1847)
yy, xx = np.mgrid[0:H, 0:W]
blot = np.array(Image.fromarray((rng.random((H // 40, W // 40)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)) / 255
fib = rng.random((H, W))
rim = np.clip(((xx / W - 0.5) ** 2 + (yy / H - 0.5) ** 2) * 2.2, 0, 1)
shade = 1 - 0.10 * blot - 0.04 * fib - 0.32 * rim ** 1.6
paper = np.stack([226 * shade, 205 * shade, 160 * shade], -1)

ink = np.zeros((H, W))
hatch = ((xx + yy) % 9 < 2)  # 45° poché in the walls
ink = np.maximum(ink, (wall & hatch) * 0.75)
ink = np.maximum(ink, edge * 1.0)
lines = Image.fromarray((ink * 255).astype(np.uint8))
d = ImageDraw.Draw(lines)
for (x, z, w, h) in doors:  # a door: a gap with a swing arc
    a, b = px(x, z), px(x + w, z + h)
    r = max(b[0] - a[0], b[1] - a[1])
    if w < h:
        d.arc([a[0] - r / 2, a[1] - r, a[0] + r * 1.5, a[1] + r], 270, 360, fill=170, width=2)
    else:
        d.arc([a[0] - r, a[1] - r / 2, a[0] + r, a[1] + r * 1.5], 0, 90, fill=170, width=2)
font = ImageFont.truetype(FONT, 46)
small = ImageFont.truetype(FONT, 34)
for n, (x, z, w, h) in shown.items():
    if n in NAMES:
        cx, cz = px(x + w / 2, z + h / 2)
        if w < h * 0.6:  # tall corridor: write along it
            t = Image.new("L", (int(h * PX), 60), 0)
            ImageDraw.Draw(t).text((t.width / 2, 30), NAMES[n], font=small, fill=230, anchor="mm")
            t = t.rotate(90, expand=True)
            lines.paste(Image.eval(t, lambda v: v), (int(cx - t.width / 2), int(cz - t.height / 2)), t)
        else:
            d.text((cx, cz), NAMES[n], font=font if w > 4 else small, fill=230, anchor="mm")
d.text((W / 2, 70), "План підвалів маєтку графа Ауерсберґа", font=ImageFont.truetype(FONT, 64), fill=255, anchor="mm")
d.text((W / 2, 125), "знято з натури, 1847 р.", font=small, fill=200, anchor="mm")
# scale bar: 3 Viennese fathoms (Klafter, 1.9 m), the unit of a Galician survey of the time
sx, sy, step = 120, H - 80, 1.9 * PX
for i in range(3):
    d.rectangle([sx + i * step, sy, sx + (i + 1) * step, sy + 10], fill=230 if i % 2 == 0 else 0, outline=230, width=2)
d.text((sx, sy - 28), "0", font=small, fill=230, anchor="mm")
d.text((sx + 3 * step + 10, sy + 5), "3 сажні", font=small, fill=230, anchor="lm")
# compass: north points to -Z (up on the sheet)
cx, cy = W - 130, H - 120
d.polygon([(cx, cy - 60), (cx - 14, cy), (cx + 14, cy)], fill=230)
d.polygon([(cx, cy + 60), (cx - 14, cy), (cx + 14, cy)], outline=230, width=2)
d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], outline=230, width=2)
d.text((cx, cy - 82), "Пн", font=small, fill=230, anchor="mm")
d.rectangle([28, 28, W - 28, H - 28], outline=200, width=3)  # sheet border
d.rectangle([40, 40, W - 40, H - 40], outline=120, width=1)

a = np.array(lines.filter(ImageFilter.GaussianBlur(0.7))) / 255 * (0.85 + 0.15 * fib)  # ink soaks into the paper
out = paper * (1 - a[..., None]) + np.array(INK) * a[..., None]
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT)
print("wrote", OUT)
