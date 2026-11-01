"""Finger-painted writing for the mirror: python tools/draw_writing.py [text] [out.png]

Thick red paint smeared with fingers: the word in a handwritten font, swollen to finger width, ragged edges,
grooves along the strokes, darker paint pooled at the rims, and drips running down. The station (MIRROR) shows it on a
quad and reveals it left to right (station.gd `_paint()`).
"""
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TEXT = sys.argv[1] if len(sys.argv) > 1 else "ДОПОМОЖІТЬ"
OUT = sys.argv[2] if len(sys.argv) > 2 else "art/textures/help_writing.png"
FONT = "fonts/Caveat.ttf"
W, H = 2048, 640
PAINT = np.array([0.78, 0.06, 0.04])
random.seed(7)
rng = np.random.default_rng(7)


def noise(scale_x, scale_y, seed):
    """Smooth value noise in 0..1, stretched by the scales (px per cell)."""
    r = np.random.default_rng(seed)
    small = r.random((max(2, int(H / scale_y)) + 1, max(2, int(W / scale_x)) + 1))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


# the word, slightly tilted and wobbling letter by letter, as if written by hand on a vertical glass
mask = Image.new("L", (W, H), 0)
font = ImageFont.truetype(FONT, 330)
x = 70
for ch in TEXT:
    glyph = Image.new("L", (400, 520), 0)
    ImageDraw.Draw(glyph).text((40, 40), ch, font=font, fill=255)
    glyph = glyph.rotate(random.uniform(-7, 7), resample=Image.BICUBIC)
    y = 20 + random.randint(-18, 18) + int((x - W / 2) * 0.03)
    mask.paste(255, (x - 40, y), glyph)
    x += int(font.getlength(ch) * 0.92)
# finger width: swell the thin pen strokes, then rag the edge with noise
mask = mask.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(5))
m = np.asarray(mask, dtype=np.float32) / 255.0
m = np.clip((m + (noise(18, 18, 1) - 0.5) * 0.35 - 0.45) * 6.0, 0, 1)

# drips: from low points of the strokes, a thin run down ending in a drop
drip = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(drip)
cols = np.where(m.max(axis=0) > 0.5)[0]
for _ in range(11):
    cx = int(rng.choice(cols))
    rows = np.where(m[:, cx] > 0.5)[0]
    top = int(rows.max())
    length = random.randint(20, 120)
    w = random.uniform(4, 7)
    for i in range(length):
        r = w * (1 - 0.5 * i / length)
        d.ellipse((cx - r, top + i - r, cx + r, top + i + r), fill=255)
    r = w * 1.1
    d.ellipse((cx - r, top + length - r, cx + r, top + length + r * 1.4), fill=255)
dm = np.asarray(drip.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0
a = np.maximum(m, dm)

# paint body: thicker (darker) at the rims, finger grooves as streaks, thin smears where it runs out
inner = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9)).filter(
    ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
rim = np.clip(a - inner, 0, 1)
grooves = 0.6 * noise(70, 9, 2) + 0.4 * noise(14, 30, 4)  # finger lines: long faint streaks, broken up
shade = 0.8 + 0.3 * grooves - 0.4 * rim
thin = noise(25, 25, 3)
alpha = a * np.clip(0.55 + 0.6 * thin + 0.4 * rim, 0, 1)
alpha *= np.clip(0.75 + 0.5 * grooves, 0, 1)
dry = noise(120, 40, 5)  # where the finger ran dry: patchy, see-through
alpha *= np.clip(0.35 + 1.4 * dry, 0, 1)
rgb = PAINT[None, None, :] * shade[..., None]
out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
box = img.getbbox()
img.crop((max(0, box[0] - 24), max(0, box[1] - 24), min(W, box[2] + 24), min(H, box[3] + 24))).save(OUT)
print("wrote", OUT)
