"""Dust on the floor with a word traced through it by a finger: python tools/draw_dust.py [text]

Writes two layers for the HAUNT station «Пил на підлозі» (station.gd `_dust()`):
  art/textures/dust_patch.png — a soft irregular patch of grey dust (always there)
  art/textures/dust_writing.png — the finger strokes: dark floor showing through, a pale ridge of pushed dust at
                                  their edges; revealed left to right like the mirror paint (paint.gdshader)
"""
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TEXT = sys.argv[1] if len(sys.argv) > 1 else "ТУТ"
FONT = "fonts/Caveat.ttf"
N = 1024
DUST = np.array([0.74, 0.70, 0.63])
FLOOR = np.array([0.16, 0.13, 0.11])
random.seed(3)


def noise(cell, seed):
    r = np.random.default_rng(seed)
    small = r.random((N // cell + 1, N // cell + 1))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)),
                      dtype=np.float32) / 255.0


def grow(a, px):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(px)),
                      dtype=np.float32) / 255.0


def save(rgb, alpha, path):
    out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(path)
    print("wrote", path)


y, x = np.mgrid[0:N, 0:N] / N - 0.5
# the patch: a lumpy blob fading out, denser in clumps, speckled
r = np.sqrt(x * x + y * y) * 2.0 + (noise(128, 1) - 0.5) * 0.5
patch = np.clip((1.0 - r) * 2.2, 0, 1) ** 1.3
clumps = 0.55 + 0.45 * noise(48, 2)
speck = (np.random.default_rng(4).random((N, N)) > 0.985) * 0.35
patch_a = np.clip(patch * clumps * 0.85 + speck * patch, 0, 1)
shade = 0.85 + 0.2 * noise(24, 5)
save(DUST[None, None, :] * shade[..., None], patch_a, "art/textures/dust_patch.png")

# the word, big and uneven, as a finger would trace it
mask = Image.new("L", (N, N), 0)
font = ImageFont.truetype(FONT, 400)
w = font.getlength(TEXT)
d = ImageDraw.Draw(mask)
cx = (N - w) / 2 - 50  # Caveat glyphs sit right of their advance
for ch in TEXT:
    g = Image.new("L", (500, 640), 0)
    ImageDraw.Draw(g).text((30, 20), ch, font=font, fill=255)
    g = g.rotate(random.uniform(-8, 8), resample=Image.BICUBIC)
    mask.paste(255, (int(cx) - 30, int(N / 2 - 290 + random.randint(-15, 15))), g)
    cx += font.getlength(ch)
m = np.asarray(mask.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(4)), dtype=np.float32) / 255.0
m = np.clip((m + (noise(10, 6) - 0.5) * 0.4 - 0.45) * 5.0, 0, 1)
ridge = np.clip(blur(grow(m, 13), 4) - m, 0, 1)  # dust pushed aside at the stroke edges
wiped = m * (0.75 + 0.25 * noise(6, 7))  # a few grains left in the stroke
rgb = FLOOR[None, None, :] * wiped[..., None] + DUST[None, None, :] * 1.08 * ridge[..., None]
alpha = np.clip(wiped * 0.9 + ridge * 0.8, 0, 1) * np.clip(patch * 3.0, 0, 1)
rgb = rgb / np.maximum(wiped + ridge, 1e-3)[..., None]
save(rgb, alpha, "art/textures/dust_writing.png")
