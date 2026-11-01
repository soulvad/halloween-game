"""«Ту бі контіньюд» card (the meme, spelled in Ukrainian letters) for the end screen, chalk on black: python tools/draw_continued.py

Writes art/ui/to_be_continued.png: a black arrow pointing left with a wobbly chalk outline and the words written in
chalk, and two chalk-outlined slanted triangles after its tail. Transparent around it. hud.gd slides it in on the
end screen.
"""
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "art/ui/to_be_continued.png"
TEXT = "Ту бі контіньюд"
FONT = "fonts/Caveat.ttf"
W, H = 1400, 300
CHALK = (238, 236, 228)
random.seed(11)


def wobble(pts, step=14, amp=1.6):
    """A hand-drawn line through the points: split into short bits, each nudged a little."""
    out = []
    for a, b in zip(pts, pts[1:] + pts[:1]):
        a, b = np.array(a, float), np.array(b, float)
        n = max(2, int(np.linalg.norm(b - a) / step))
        for i in range(n):
            out.append(tuple(a + (b - a) * i / n + np.random.normal(0, amp, 2)))
    return out


img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
cy = H / 2
arrow = [(20, cy), (230, 20), (230, 92), (1010, 92), (1010, 208), (230, 208), (230, 280)]
d.polygon(arrow, fill=(0, 0, 0, 255))
for _ in range(2):  # chalk goes over the outline twice, never quite the same
    line = wobble(arrow)
    d.line(line + line[:1], fill=CHALK + (255,), width=random.randint(5, 7), joint="curve")
# two slanted triangles after the tail
tris = [[(1040, 92), (1150, 92), (1110, 208)], [(1160, 92), (1260, 92), (1180, 208)]]
for t in tris:
    d.polygon(t, fill=(0, 0, 0, 255))
    for _ in range(2):
        line = wobble(t, 10)
        d.line(line + line[:1], fill=CHALK + (255,), width=random.randint(5, 6), joint="curve")
# the words, chalk: the font, roughened
font = ImageFont.truetype(FONT, 104)
words = Image.new("L", (W, H), 0)
tw = font.getlength(TEXT)
ImageDraw.Draw(words).text(((230 + 1010 - tw) / 2 + 10, cy - 64), TEXT, font=font, fill=255)  # centred in the shaft
words = words.filter(ImageFilter.MaxFilter(5))
grain = (np.random.default_rng(3).random((H, W)) > 0.1).astype(np.float32)
a = np.asarray(words, dtype=np.float32) / 255.0 * grain
txt = Image.fromarray((np.dstack([np.full((H, W, 3), CHALK, np.float32) / 255.0, a]) * 255).astype(np.uint8), "RGBA")
img.alpha_composite(txt)
# chalk is never solid: speckle the outlines too
arr = np.asarray(img).astype(np.float32)
white = arr[..., 0] > 200
holes = np.random.default_rng(4).random((H, W)) > 0.85
arr[white & holes, :3] = 0
img = Image.fromarray(arr.astype(np.uint8), "RGBA")
img.crop(img.getbbox()).save(OUT)
print("wrote", OUT, img.getbbox())
