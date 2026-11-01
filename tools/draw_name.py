"""The name scratched into the wall with a nail, as in the memory 5 comic: python tools/draw_name.py

Writes art/textures/name_scratch.png: ТИМІШ in straight capital strokes, each gone over two or three times, a pale
groove with a dark chipped edge. The Memory5 station shows it on the wall and reveals it left to right while an
archaeologist reads it (station.gd `scratch()`, paint.gdshader with gloss 0).
"""
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = "art/textures/name_scratch.png"
W, H = 1900, 520
LH = 340  # letter height, px
GROOVE = np.array([0.88, 0.87, 0.9])  # fresh stone shows pale in the scratch, like the tally marks
RIM = np.array([0.05, 0.04, 0.05])
random.seed(5)

# letters as strokes in a 0..1 box (x right, y down) and their width
LETTERS = [
    ([((0, 0), (1, 0)), ((0.5, 0), (0.5, 1))], 0.75),  # Т
    ([((0, 0), (0, 1)), ((0, 1), (1, 0)), ((1, 0), (1, 1))], 0.7),  # И
    ([((0, 1), (0, 0)), ((0, 0), (0.5, 0.65)), ((0.5, 0.65), (1, 0)), ((1, 0), (1, 1))], 0.85),  # М
    ([((0.5, 0), (0.5, 1))], 0.25),  # І
    ([((0, 0), (0, 1)), ((0, 1), (1, 1)), ((0.5, 0), (0.5, 1)), ((1, 0), (1, 1))], 0.85),  # Ш
]


def scratch(d, a, b, width):
    """One nail stroke: a slightly wobbly line, overshooting its ends a little."""
    a, b = np.array(a, float), np.array(b, float)
    v = b - a
    a = a - v * random.uniform(0.0, 0.06)
    b = b + v * random.uniform(0.0, 0.08)
    n = 8
    pts = [tuple(a + (b - a) * i / n + np.random.normal(0, 1.6, 2)) for i in range(n + 1)]
    d.line(pts, fill=255, width=width, joint="curve")


mask = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(mask)
x = 90.0
for strokes, wid in LETTERS:
    lw = LH * wid
    y0 = 90 - (x - 90) * 0.04 + random.uniform(-10, 10)  # the line climbs a little to the right
    skew = random.uniform(-0.06, 0.04)
    for (p, q) in strokes:
        pa = (x + p[0] * lw + (1 - p[1]) * skew * LH, y0 + p[1] * LH)
        pb = (x + q[0] * lw + (1 - q[1]) * skew * LH, y0 + q[1] * LH)
        for _ in range(random.randint(2, 3)):  # gone over again and again
            off = np.random.normal(0, 2.5, 2)
            scratch(d, pa + off, pb + off, random.randint(9, 14))
    x += lw + 130

m = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
grown = np.asarray(mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2)), dtype=np.float32) / 255.0
rim = np.clip(np.roll(np.roll(grown, 3, axis=0), 2, axis=1) - m, 0, 1)  # shadow along the lower edge of the scratch
chips = (np.random.default_rng(6).random((H, W)) > 0.6).astype(np.float32)
rim *= 0.6 + 0.4 * np.asarray(Image.fromarray((chips * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)),
                             dtype=np.float32) / 255.0
alpha = np.clip(m * 0.9 + rim * 0.75, 0, 1)
rgb = (GROOVE[None, None, :] * m[..., None] + RIM[None, None, :] * rim[..., None]) / np.maximum(m + rim, 1e-3)[..., None]
img = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), alpha]) * 255).astype(np.uint8), "RGBA")
box = img.getbbox()
img.crop((max(0, box[0] - 20), max(0, box[1] - 20), min(W, box[2] + 20), min(H, box[3] + 20))).save(OUT)
print("wrote", OUT, img.crop(box).size)
