import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

OUT = sys.argv[1]
FONT_DIR = sys.argv[2]
PAGES = sys.argv[3]
ONLY = sys.argv[4] if len(sys.argv) > 4 else "all"

SOOT = (23, 17, 14)
UMBER = (43, 31, 24)
STONE = (74, 58, 48)
PAPER = (233, 220, 195)
PAPER_SHADOW = (201, 181, 147)
FLAME = (242, 169, 59)
FLAME_LIGHT = (255, 213, 138)
FLAME_DEEP = (186, 104, 28)
GHOST = (155, 216, 240)
GHOST_CORE = (155, 246, 255)
GHOST_INK = (52, 108, 148)
RUST = (142, 59, 42)
HOLY = (255, 243, 214)
SCORCH = (124, 84, 52)
LEATHER = (78, 46, 30)
GILT = (184, 140, 76)

BOLD = os.path.join(FONT_DIR, "OldStandard-Bold.ttf")
manifest = {"nine_slice": {}, "icons": {}, "titles": {}, "textures": {}, "images": {}}


def col(c):
    return np.array(c, dtype=np.float32) / 255.0


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t, dtype=np.float32)
    if t.ndim:
        t = t[..., None]
    return a * (1.0 - t) + b * t


def noise(h, w, sigma, seed, stretch=1.0, angle=0.0):
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    u = fx * math.cos(angle) + fy * math.sin(angle)
    v = -fx * math.sin(angle) + fy * math.cos(angle)
    gain = np.exp(-2.0 * math.pi ** 2 * ((u * sigma) ** 2 + (v * sigma * stretch) ** 2))
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * gain))
    field -= field.mean()
    return (field / (field.std() + 1e-9)).astype(np.float32)


def noise1(n, sigma, seed):
    return noise(1, n, sigma, seed)[0]


def over(dst, src):
    da, sa = dst[..., 3:4], src[..., 3:4]
    out_a = sa + da * (1.0 - sa)
    out_rgb = (src[..., :3] * sa + dst[..., :3] * da * (1.0 - sa)) / np.maximum(out_a, 1e-6)
    return np.concatenate([out_rgb, out_a], axis=-1)


def layer(rgb, alpha):
    rgb = np.broadcast_to(rgb, alpha.shape + (3,)).astype(np.float32)
    return np.concatenate([rgb, np.clip(alpha, 0, 1)[..., None]], axis=-1)


def empty(h, w):
    return np.zeros((h, w, 4), np.float32)


def save_rgba(rgba, path, scale_to=None):
    rgba = np.clip(rgba, 0, 1)
    image = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    if scale_to:
        image = image.resize(scale_to, Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def paper_tex(h, w, seed, base=PAPER, shade=PAPER_SHADOW, calm=1.0):
    big = min(h, w)
    mott = 0.6 * noise(h, w, big / 10, seed) + 0.3 * noise(h, w, big / 30, seed + 1) + 0.1 * noise(h, w, 3, seed + 2)
    fibre = noise(h, w, 0.9, seed + 3, 5, 1.2)
    grain = noise(h, w, 0.6, seed + 5)
    flecks = smooth(2.6, 3.4, noise(h, w, 0.9, seed + 7))
    stain = noise(h, w, big / 14, seed + 6)
    blot = smooth(1.6, 2.4, stain) * calm
    ring = np.exp(-((stain - 1.6) / 0.07) ** 2) * calm
    k = np.clip(0.2 + 0.15 * mott * calm + 0.3 * blot + 0.28 * ring + 0.35 * flecks, 0, 1)
    rgb = mix(col(base), col(shade), k)
    rgb = rgb * (1 + 0.016 * fibre + 0.018 * grain)[..., None]
    return np.clip(rgb, 0, 1)


def stone_tex(h, w, seed, light=1.0):
    big = min(h, w)
    mott = 0.65 * noise(h, w, big / 8, seed) + 0.35 * noise(h, w, big / 24, seed + 1)
    s1 = noise(h, w, 1.6, seed + 2, 9, 0.5)
    s2 = noise(h, w, 1.6, seed + 3, 9, 2.2)
    sel = smooth(-0.4, 0.4, noise(h, w, big / 12, seed + 4))
    strokes = s1 * (1 - sel) + s2 * sel
    grain = noise(h, w, 0.6, seed + 5)
    k = 0.4 + 0.15 * mott + 0.045 * strokes
    k = 0.75 * k + 0.25 * (np.round(k * 7) / 7)
    k = np.clip(k * light, 0, 1)
    low = mix(col(SOOT), col(UMBER), np.clip(k / 0.5, 0, 1))
    high = mix(col(UMBER), col(STONE), np.clip((k - 0.5) / 0.5, 0, 1))
    rgb = np.where((k < 0.5)[..., None], low, high)
    return np.clip(rgb * (1 + 0.05 * grain)[..., None], 0, 1)


def leather_tex(h, w, seed):
    big = min(h, w)
    mott = 0.7 * noise(h, w, big / 9, seed) + 0.3 * noise(h, w, big / 28, seed + 1)
    pebble = noise(h, w, 1.3, seed + 2)
    crease = np.exp(-(noise(h, w, big / 18, seed + 3, 3, 0.7) / 0.05) ** 2)
    scuff = smooth(1.2, 2.2, noise(h, w, big / 16, seed + 4, 4, 0.3))
    factor = 1 + 0.16 * mott + 0.07 * pebble - 0.3 * crease + 0.3 * scuff
    return np.clip(col(LEATHER) * factor[..., None], 0, 1)


def amber_tex(h, w, seed):
    big = min(h, w)
    wash = 0.5 + 0.12 * noise(h, w, big / 5, seed) + 0.1 * noise(h, w, 1.4, seed + 1, 10, math.pi / 2 + 0.04)
    rgb = mix(col(FLAME), col(FLAME_LIGHT), np.clip(wash, 0, 1))
    dark = smooth(1.6, 2.6, noise(h, w, big / 5, seed + 2))
    rgb = mix(rgb, col(FLAME_DEEP), dark * 0.25)
    return np.clip(rgb * (1 + 0.03 * noise(h, w, 0.6, seed + 3))[..., None], 0, 1)


def rust_tex(h, w, seed):
    big = min(h, w)
    k = 0.5 + 0.25 * noise(h, w, big / 6, seed) + 0.1 * noise(h, w, 1.2, seed + 1, 8, 0.2)
    rgb = mix(col((104, 40, 28)), col((168, 76, 52)), np.clip(k, 0, 1))
    shine = smooth(1.6, 2.4, noise(h, w, big / 8, seed + 2)) * 0.3
    return np.clip(mix(rgb, col((214, 132, 98)), shine), 0, 1)


def holy_tex(h, w, seed):
    return paper_tex(h, w, seed, HOLY, (238, 218, 178), 0.6)


def ink_tex(h, w, seed):
    k = 0.3 + 0.15 * noise(h, w, min(h, w) / 4, seed) + 0.08 * noise(h, w, 1.4, seed + 1, 12, math.pi / 2 + 0.03)
    return np.clip(mix(col(SOOT), col(UMBER), np.clip(k, 0, 1)), 0, 1)


def map_tex(h, w, seed, cell=32):
    rgb = paper_tex(h, w, seed, (228, 210, 176), PAPER_SHADOW, 0.9)
    yy, xx = np.mgrid[0:h, 0:w]
    wob = 0.6 * noise(h, w, 4, seed + 9)
    gx = np.abs(((xx + wob) % cell) - cell / 2) - (cell / 2 - 0.6)
    gy = np.abs(((yy + wob) % cell) - cell / 2) - (cell / 2 - 0.6)
    line = np.maximum(smooth(-0.6, 0.6, gx), smooth(-0.6, 0.6, gy))
    return mix(rgb, col((150, 118, 84)), line * 0.16)


def paint_tex(h, w, seed, color):
    big = min(h, w)
    k = 1 + 0.07 * noise(h, w, big / 4, seed) + 0.05 * noise(h, w, 1.4, seed + 1, 10, math.pi / 2 + 0.03)
    return np.clip(col(color) * k[..., None], 0, 1)


MATERIALS = {
    "paper": lambda h, w, s: paper_tex(h, w, s, calm=0.7),
    "paper_shadow": lambda h, w, s: paper_tex(h, w, s, PAPER_SHADOW, (176, 156, 122), 0.6),
    "stone": stone_tex,
    "stone_dark": lambda h, w, s: stone_tex(h, w, s, 0.8),
    "leather": leather_tex,
    "amber": amber_tex,
    "amber_dark": lambda h, w, s: amber_tex(h, w, s) * 0.84,
    "rust": rust_tex,
    "holy": holy_tex,
    "ink": ink_tex,
    "map": map_tex,
}


def nine_slice(name, material, period, insets, margins, seed, **o):
    pw, ph = period
    top, bottom, left, right = insets
    mt, mb, ml, mr = margins
    h, w = top + ph + bottom, left + pw + right
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ty = ((yy - top) % ph).astype(int)
    tx = ((xx - left) % pw).astype(int)
    source = MATERIALS[material](ph, pw, seed) if isinstance(material, str) else paint_tex(ph, pw, seed, material)
    rgb = source[ty, tx]
    tint = o.get("tint")
    if tint:
        rgb = mix(rgb, col(tint[0]), tint[1])
    rag_tb, rag_lr = o.get("rag", (2.0, 2.0))

    def edge(n, sigma, seed_off, amp):
        lo = noise1(n, sigma, seed + seed_off)
        hi = noise1(n, 1.6, seed + seed_off + 1)
        return amp * (1 + 0.8 * np.clip(0.85 * lo + 0.15 * hi, -1.25, 1.25))

    off_t = edge(pw, 7, 11, rag_tb)[tx]
    off_b = edge(pw, 7, 13, rag_tb)[tx]
    off_l = edge(ph, 7, 15, rag_lr)[ty]
    off_r = edge(ph, 7, 17, rag_lr)[ty]
    dt0, db0 = yy - mt, (h - 1 - yy) - mb
    dl0, dr0 = xx - ml, (w - 1 - xx) - mr
    dt, db, dl, dr = dt0 - off_t, db0 - off_b, dl0 - off_l, dr0 - off_r
    rng = np.random.default_rng(seed + 40)
    chips = rng.uniform(*o.get("chip", (1.0, 4.0)), 4)
    s2 = math.sqrt(2.0)
    d = np.minimum.reduce([dt, db, dl, dr, (dt + dl) / s2 - chips[0], (dt + dr) / s2 - chips[1],
                           (db + dl) / s2 - chips[2], (db + dr) / s2 - chips[3]])
    d = d + o.get("fray", 0.6) * 0.55 * noise(ph, pw, 1.1, seed + 20)[ty, tx]
    d0 = np.minimum.reduce([dt0, db0, dl0, dr0])
    soft = o.get("soft", 0.75)
    alpha = smooth(-soft, soft, d) * o.get("opacity", 1.0)
    low = noise(ph, pw, max(ph, pw) / 6, seed + 21)[ty, tx]
    if o.get("streak"):
        alpha = alpha * (0.9 + 0.1 * noise(ph, pw, 1.2, seed + 22, 14, math.pi / 2 + 0.02)[ty, tx])
    age = o.get("age")
    if age:
        a_col, a_amt, a_w = age
        amount = np.exp(-np.maximum(d, 0) / a_w) * (0.6 + 0.4 * smooth(-1.5, 1.5, low)) * a_amt
        rgb = mix(rgb, col(a_col), amount)
    if o.get("char"):
        rgb = mix(rgb, col(SOOT), np.exp(-np.maximum(d, 0) / 1.4) * o["char"])
    if o.get("gutter"):
        side, g_w, g_amt = o["gutter"]
        dist = {"right": dr0, "left": dl0}[side]
        rgb = mix(rgb, col(SCORCH), np.exp(-np.maximum(dist, 0) / g_w) * g_amt)
    relief = o.get("relief", 0.0)
    if relief:
        light = np.exp(-np.maximum(dt, 0) / 5) * 0.5 - np.exp(-np.maximum(db, 0) / 5) * 0.6
        rgb = np.clip(rgb * (1 + relief * light)[..., None], 0, 1)
    if o.get("pressed"):
        dim = 0.3 * np.exp(-np.maximum(dt, 0) / 7) + 0.12 * np.exp(-np.maximum(dl, 0) / 7)
        rgb = rgb * (1 - dim)[..., None]
    cap = o.get("cap")
    if cap:
        side, bottom_side = cap
        dface = np.minimum.reduce([dt - side, db - bottom_side, dl - side, dr - side])
        flank = mix(rgb * 0.74, col(SCORCH), 0.25)
        rgb = mix(flank, rgb, smooth(-0.7, 0.7, dface))
        face_line = smooth(-0.7, 0.7, 0.55 - np.abs(dface)) * 0.5
        rgb = mix(rgb, col(SOOT), face_line * smooth(0, 1.5, d))
    rule = o.get("rule")
    if rule:
        for r0, rw, r_col, r_alpha in rule:
            tremble = 0.9 * noise(ph, pw, 3, seed + 30)[ty, tx]
            width = rw * (0.7 + 0.6 * smooth(-1.5, 1.5, noise(ph, pw, 10, seed + 31)[ty, tx]))
            ink = smooth(-0.6, 0.6, width / 2 - np.abs(d0 - r0 - tremble)) * r_alpha
            ink = ink * (0.85 + 0.15 * noise(ph, pw, 0.8, seed + 32)[ty, tx])
            rgb = mix(rgb, col(r_col), ink)
    outline = o.get("outline")
    if outline:
        ow, o_col, o_alpha = outline
        width = ow * (0.75 + 0.5 * smooth(-1.5, 1.5, noise(ph, pw, 8, seed + 33)[ty, tx]))
        if o.get("heavy_bottom"):
            width = width + o["heavy_bottom"] * smooth(-1, 1, -(db - dt))
        ink = smooth(-0.6, 0.6, width - d) * o_alpha
        rgb = mix(rgb, col(o_col), ink)
    if o.get("disabled"):
        grey = (rgb @ np.array([0.3, 0.59, 0.11], np.float32))[..., None]
        rgb = mix(rgb, grey * col((255, 240, 214)), 0.6)
        rgb = mix(rgb, col((150, 132, 112)), 0.25)
        alpha = alpha * 0.82
    canvas = empty(h, w)
    shadow = o.get("shadow")
    if shadow:
        s_amt, s_dy, s_blur = shadow
        sh = ndimage.gaussian_filter(ndimage.shift(alpha, (s_dy, 0), order=1, mode="constant"), s_blur)
        canvas = over(canvas, layer(col(SOOT), sh * s_amt))
    glow = o.get("glow")
    if glow:
        g_col, g_amt, g_r = glow
        halo = np.exp(np.minimum(d, 0) / g_r) * (0.72 + 0.28 * smooth(-1.5, 1.5, low)) * g_amt
        canvas = over(canvas, layer(col(g_col), halo * (1 - alpha)))
    canvas = over(canvas, layer(rgb, alpha))
    path = os.path.join(OUT, "nine", name + ".png")
    save_rgba(canvas, path)
    manifest["nine_slice"][name] = {
        "file": "nine/" + name + ".png", "size": [w, h],
        "insets": {"top": top, "bottom": bottom, "left": left, "right": right},
        "margins": {"top": mt, "bottom": mb, "left": ml, "right": mr},
        "stretch": "tile_fit",
    }


def build_nine():
    ink = (SOOT, 0.86)
    paper_card = dict(rag=(2.2, 2.2), fray=0.8, age=(SCORCH, 0.55, 9), char=0.45,
                      rule=[(10, 2.6, SOOT, 0.82)], shadow=(0.6, 5, 6))
    nine_slice("card_paper", "paper", (128, 128), (56, 62, 56, 56), (14, 20, 14, 14), 101, **paper_card)
    nine_slice("card_paper_small", "paper", (64, 48), (30, 34, 30, 30), (10, 14, 10, 10), 102,
               rag=(1.6, 1.6), fray=0.6, age=(SCORCH, 0.45, 6), char=0.4, rule=[(6.5, 2.0, SOOT, 0.8)], shadow=(0.55, 4, 4))
    nine_slice("card_stone", "stone", (128, 128), (44, 48, 44, 44), (12, 16, 12, 12), 103,
               rag=(1.3, 1.3), fray=0.5, age=(SOOT, 0.6, 10), outline=(2.6, SOOT, 0.95),
               rule=[(8, 1.3, PAPER_SHADOW, 0.32)], shadow=(0.6, 5, 6))
    nine_slice("card_holy", "holy", (128, 128), (60, 66, 60, 60), (18, 24, 18, 18), 104,
               rag=(2.2, 2.2), fray=0.7, age=((214, 176, 118), 0.45, 10), rule=[(11, 2.2, (92, 66, 44), 0.7)],
               glow=(HOLY, 0.5, 9), shadow=(0.35, 6, 7))
    nine_slice("comic_frame", "paper", (128, 128), (60, 66, 60, 60), (16, 22, 16, 16), 105,
               rag=(2.8, 2.8), fray=0.9, age=(SCORCH, 0.5, 12), char=0.5, shadow=(0.65, 6, 8))
    nine_slice("map_sheet", "map", (128, 128), (64, 70, 64, 64), (14, 20, 14, 14), 106,
               rag=(3.2, 3.2), fray=1.0, age=(SCORCH, 0.8, 16), char=0.7,
               rule=[(14, 3.0, (60, 42, 30), 0.85), (22, 1.2, (60, 42, 30), 0.7)], shadow=(0.6, 6, 8))
    nine_slice("map_inset", "map", (64, 64), (16, 18, 16, 16), (4, 6, 4, 4), 107,
               rag=(1.2, 1.2), fray=0.5, age=(SCORCH, 0.6, 5), outline=(1.6, SOOT, 0.9))
    nine_slice("book_cover", "leather", (128, 128), (64, 72, 64, 64), (16, 24, 16, 16), 108,
               rag=(1.4, 1.4), fray=0.5, age=(SOOT, 0.55, 14), outline=(3.0, SOOT, 0.95),
               rule=[(18, 2.0, GILT, 0.75), (23, 1.0, GILT, 0.5)], shadow=(0.7, 8, 10))
    nine_slice("book_page_left", "paper", (128, 128), (40, 46, 40, 72), (6, 10, 6, 0), 109,
               rag=(1.0, 1.0), fray=0.4, age=(SCORCH, 0.35, 8), gutter=("right", 22, 0.55), chip=(0.0, 1.0))
    nine_slice("book_page_right", "paper", (128, 128), (40, 46, 72, 40), (6, 10, 0, 6), 110,
               rag=(1.0, 1.0), fray=0.4, age=(SCORCH, 0.35, 8), gutter=("left", 22, 0.55), chip=(0.0, 1.0))
    nine_slice("wash_ink", "ink", (128, 32), (30, 30, 96, 96), (8, 8, 8, 8), 111,
               rag=(4.0, 10.0), fray=0.4, soft=12, opacity=0.86, streak=True)
    nine_slice("banner_power", "paper", (128, 48), (52, 56, 80, 80), (28, 32, 28, 28), 112,
               rag=(1.8, 7.0), fray=1.4, age=(SCORCH, 0.5, 8), char=0.4, rule=[(9, 1.8, GHOST_INK, 0.7)],
               glow=(GHOST, 0.62, 9), shadow=(0.4, 4, 5))
    tag = dict(rag=(1.1, 1.4), fray=0.5, outline=(2.0, SOOT, 0.92), shadow=(0.5, 2, 2.5))
    nine_slice("tag_goal", "amber", (32, 16), (18, 21, 18, 18), (6, 9, 6, 6), 113, age=(FLAME_DEEP, 0.5, 4), **tag)
    nine_slice("tag_new", "amber", (24, 12), (14, 17, 14, 14), (5, 8, 5, 5), 114, age=(FLAME_DEEP, 0.45, 3), **tag)
    nine_slice("tag_warn", "rust", (24, 12), (14, 17, 14, 14), (5, 8, 5, 5), 115, age=(SOOT, 0.35, 3), **tag)
    nine_slice("pill_paper", "paper", (32, 16), (16, 19, 16, 16), (6, 9, 6, 6), 116,
               rag=(1.0, 1.2), fray=0.5, age=(SCORCH, 0.4, 3), outline=(1.8, SOOT, 0.9), shadow=(0.5, 2, 2.5))
    nine_slice("pill_ghost", "stone_dark", (32, 16), (16, 19, 16, 16), (6, 9, 6, 6), 117,
               rag=(1.0, 1.2), fray=0.5, outline=(1.8, GHOST, 0.85), glow=(GHOST, 0.4, 3.5), shadow=(0.4, 2, 2.5))
    nine_slice("plate_stone", "stone", (32, 16), (16, 19, 16, 16), (5, 8, 5, 5), 118,
               rag=(0.9, 1.0), fray=0.4, age=(SOOT, 0.5, 4), outline=(2.0, SOOT, 0.95),
               rule=[(3.5, 1.0, PAPER_SHADOW, 0.3)], shadow=(0.5, 2, 2.5))
    button = {"insets": (30, 36, 34, 34), "margins": (14, 18, 16, 16), "period": (96, 32)}
    states = {
        "normal": dict(cap=(1.2, 5.0), outline=(2.6, SOOT, 0.92), shadow=(0.55, 4, 4), relief=0.25),
        "hover": dict(cap=(1.2, 5.0), outline=(2.8, SOOT, 0.95), shadow=(0.45, 4, 4), relief=0.3, glow=(FLAME, 0.75, 5.5)),
        "pressed": dict(cap=(2.4, 2.0), outline=(2.6, SOOT, 0.95), shadow=(0.25, 1, 2), pressed=True),
        "disabled": dict(cap=(1.2, 3.0), outline=(2.0, STONE, 0.6), disabled=True),
    }
    for state, extra in states.items():
        nine_slice("button_paper_" + state, "paper_shadow" if state == "pressed" else "paper", button["period"],
                   button["insets"], button["margins"], 120, rag=(1.4, 1.6), fray=0.6, age=(SCORCH, 0.4, 6),
                   tint=(FLAME_LIGHT, 0.14) if state == "hover" else None, **extra)
        nine_slice("button_primary_" + state, "amber_dark" if state == "pressed" else "amber", button["period"],
                   button["insets"], button["margins"], 121, rag=(1.4, 1.6), fray=0.6, age=(FLAME_DEEP, 0.5, 6),
                   **{**extra, "glow": (FLAME_LIGHT, 0.85, 6.5)} if state == "hover" else extra)
    key = {"insets": (18, 24, 18, 18), "margins": (8, 10, 8, 8), "period": (32, 24)}
    key_states = {
        "normal": dict(cap=(1.6, 6.0), outline=(2.2, SOOT, 0.95), shadow=(0.55, 2.5, 2.5), relief=0.2),
        "hover": dict(cap=(1.6, 6.0), outline=(2.4, SOOT, 0.95), shadow=(0.5, 2.5, 2.5), relief=0.25,
                      glow=(FLAME, 0.8, 3.6), tint=(FLAME_LIGHT, 0.18)),
        "pressed": dict(cap=(3.0, 2.4), outline=(2.2, SOOT, 0.95), shadow=(0.2, 1, 1.5), pressed=True),
        "disabled": dict(cap=(1.6, 4.0), outline=(1.8, STONE, 0.6), disabled=True),
    }
    for state, extra in key_states.items():
        nine_slice("key_" + state, "paper_shadow" if state == "pressed" else "paper", key["period"], key["insets"],
                   key["margins"], 130, rag=(0.9, 0.9), fray=0.4, age=(SCORCH, 0.35, 4), chip=(0.5, 2.0), **extra)
    tile = {"insets": (26, 30, 26, 26), "margins": (10, 12, 10, 10), "period": (40, 40)}
    for state, material, extra in [("ready", "amber", {}), ("idle", "stone", {}), ("ritual", "holy", {"glow": (HOLY, 0.7, 6)})]:
        nine_slice("tile_action_" + state, material, tile["period"], tile["insets"], tile["margins"], 140,
                   rag=(1.1, 1.1), fray=0.5, cap=(1.6, 6.0), outline=(2.6, SOOT, 0.95), shadow=(0.55, 3, 3),
                   age=(SOOT if material == "stone" else FLAME_DEEP if material == "amber" else (214, 176, 118), 0.45, 5), **extra)
    power = {"insets": (22, 24, 22, 22), "margins": (12, 14, 12, 12), "period": (24, 24)}
    nine_slice("tile_power_locked", "paper_shadow", power["period"], power["insets"], power["margins"], 150,
               rag=(0.9, 0.9), fray=0.4, pressed=True, outline=(1.8, STONE, 0.7))
    nine_slice("tile_power_on", "stone_dark", power["period"], power["insets"], power["margins"], 151,
               rag=(0.9, 0.9), fray=0.4, outline=(2.0, SOOT, 0.95), rule=[(3.2, 1.5, GHOST, 0.55)], shadow=(0.45, 2, 2.5))
    nine_slice("tile_power_new", "stone_dark", power["period"], power["insets"], power["margins"], 152,
               rag=(0.9, 0.9), fray=0.4, outline=(2.0, SOOT, 0.95), rule=[(3.2, 1.8, GHOST_CORE, 0.8)],
               glow=(FLAME, 0.85, 4.5))
    nine_slice("bar_track", "stone_dark", (64, 8), (16, 18, 16, 16), (6, 8, 6, 6), 160,
               rag=(0.8, 1.2), fray=0.4, pressed=True, outline=(2.0, SOOT, 0.95), shadow=(0.4, 2, 2))
    nine_slice("bar_fill_holy", "holy", (64, 8), (12, 12, 14, 14), (6, 6, 6, 6), 161,
               rag=(0.6, 2.4), fray=0.6, streak=True, glow=(HOLY, 0.7, 3.5))
    nine_slice("bar_fill_flame", "amber", (64, 8), (12, 12, 14, 14), (6, 6, 6, 6), 162,
               rag=(0.6, 2.4), fray=0.6, streak=True, glow=(FLAME, 0.55, 3.0))
    nine_slice("rule_ink", SOOT, (128, 2), (5, 5, 28, 28), (2, 2, 4, 4), 170,
               rag=(0.5, 0.0), fray=0.3, chip=(8.0, 16.0), streak=True, opacity=0.85)
    nine_slice("rule_paper", PAPER_SHADOW, (128, 2), (5, 5, 28, 28), (2, 2, 4, 4), 171,
               rag=(0.5, 0.0), fray=0.3, chip=(8.0, 16.0), streak=True, opacity=0.55)


def build_swatches():
    palette = {"soot": SOOT, "umber": UMBER, "stone": STONE, "paper": PAPER, "paper_shadow": PAPER_SHADOW,
               "flame": FLAME, "flame_light": FLAME_LIGHT, "ghost": GHOST, "ghost_core": GHOST_CORE, "rust": RUST, "holy": HOLY}
    for i, (name, color) in enumerate(palette.items()):
        nine_slice("swatch_" + name, color, (128, 48), (20, 22, 20, 20), (6, 8, 6, 6), 180 + i,
                   rag=(1.8, 3.5), fray=0.6, streak=True, outline=(1.8, SOOT, 0.7), shadow=(0.35, 2, 3))
    for name in list(manifest["nine_slice"]):
        if name.startswith("swatch_"):
            manifest.setdefault("swatches", {})[name] = manifest["nine_slice"].pop(name)


def sdf(mask):
    return (ndimage.distance_transform_edt(mask) - ndimage.distance_transform_edt(~mask)).astype(np.float32)


def poly_mask(points, size=512, wobble=0.0, seed=0):
    image = Image.new("L", (size, size), 0)
    ImageDraw.Draw(image).polygon([tuple(p) for p in points], fill=255)
    m = np.asarray(image).astype(np.float32) / 255.0
    if wobble:
        m = ndimage.gaussian_filter(m, 2.0) + wobble * noise(size, size, 3, seed)
    return m > 0.5


def catmull(points, steps=12):
    pts = np.array(points, np.float32)
    pts = np.vstack([pts[0], pts, pts[-1]])
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for t in np.linspace(0, 1, steps, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-2])
    return np.array(out)


def stroke(points, width, size=512, taper=(0.35, 0.35), seed=0, smooth_path=True, tremble=1.2):
    if smooth_path:
        path = catmull(points)
    else:
        corners = np.array(points, np.float32)
        path = np.vstack([np.linspace(a, b, 24, endpoint=False) for a, b in zip(corners[:-1], corners[1:])] + [corners[-1:]])
    rng = np.random.default_rng(seed)
    path = path + rng.normal(0, tremble * 0.35, path.shape)
    path = ndimage.gaussian_filter1d(path, 1.0, axis=0)
    n = len(path)
    t = np.linspace(0, 1, n)
    press = np.minimum(1, np.minimum(t / max(taper[0], 1e-3), (1 - t) / max(taper[1], 1e-3)))
    press = 0.25 + 0.75 * np.sqrt(np.clip(press, 0, 1))
    press = press * (1 + 0.15 * ndimage.gaussian_filter1d(rng.normal(0, 1, n), 3))
    widths = width * press
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    best = np.full((size, size), -1e9, np.float32)
    for i in range(n - 1):
        x0, y0 = path[i]
        x1, y1 = path[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        pad = max(w0, w1) + 3
        xa, xb = int(max(0, min(x0, x1) - pad)), int(min(size, max(x0, x1) + pad + 1))
        ya, yb = int(max(0, min(y0, y1) - pad)), int(min(size, max(y0, y1) + pad + 1))
        if xa >= xb or ya >= yb:
            continue
        sx, sy = xx[ya:yb, xa:xb], yy[ya:yb, xa:xb]
        dx, dy = x1 - x0, y1 - y0
        length2 = dx * dx + dy * dy + 1e-6
        tt = np.clip(((sx - x0) * dx + (sy - y0) * dy) / length2, 0, 1)
        dist = np.hypot(sx - (x0 + tt * dx), sy - (y0 + tt * dy))
        best[ya:yb, xa:xb] = np.maximum(best[ya:yb, xa:xb], (w0 + (w1 - w0) * tt) / 2 - dist)
    return smooth(-0.8, 0.8, best)


def ink_outline(mask, width, seed, size=512):
    s = sdf(mask)
    w = width * (0.7 + 0.6 * smooth(-1.5, 1.5, noise(size, size, 18, seed)))
    return smooth(-0.8, 0.8, w / 2 - np.abs(s + w * 0.15))


def wash(mask, base, light, seed, size=512, streak_angle=0.6):
    s = sdf(mask)
    k = 0.5 + 0.25 * noise(size, size, 30, seed) + 0.12 * noise(size, size, 2, seed + 1, 8, streak_angle)
    rgb = mix(col(base), col(light), np.clip(k, 0, 1))
    edge = np.exp(-np.maximum(s, 0) / 7)
    rgb = mix(rgb, col(base) * 0.8, edge * 0.35)
    return rgb, smooth(-0.8, 0.8, s)


def glow_of(alpha, color, radius, amount):
    g = ndimage.gaussian_filter(alpha, radius) * amount
    return layer(col(color), np.clip(g, 0, 1))


def wobbly_ring(cx, cy, r, seed, start=-0.3, sweep=6.0, wob=0.04, n=40):
    rng = np.random.default_rng(seed)
    a = np.linspace(start, start + sweep, n)
    rr = r * (1 + wob * ndimage.gaussian_filter1d(rng.normal(0, 1, n), 3) * 3)
    return list(zip(cx + rr * np.cos(a), cy + rr * np.sin(a)))


def save_icon(name, rgba, kind):
    path = os.path.join(OUT, "icons", name + ".png")
    save_rgba(rgba, path, (256, 256) if rgba.shape[0] != 256 else None)
    manifest["icons"][name] = {"file": "icons/" + name + ".png", "size": [256, 256], "kind": kind}


def load_page(page):
    folder = os.path.join(PAGES, page)
    layers = sorted(n for n in os.listdir(folder) if n.endswith(".png"))
    layers = [n for n in layers if n != "frame.png"] + [n for n in layers if n == "frame.png"]
    base = Image.open(os.path.join(folder, layers[0])).convert("RGBA")
    sheet = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for name in layers:
        sheet.alpha_composite(Image.open(os.path.join(folder, name)).convert("RGBA"))
    return np.asarray(sheet.convert("RGB")).astype(np.float32) / 255.0


EMBLEMS = {
    "breath": ("memory_1", (929, 1333), (78, 70), (1029, 1448)),
    "push_sound": ("memory_2", (966, 1388), (70, 66), (1029, 1448)),
    "writing": ("memory_3", (956, 1353), (66, 84), (1029, 1448)),
    "ghost": ("memory_5", (941, 1361), (72, 84), (1029, 1448)),
}


def emblem_alpha(page, center, half, limit):
    image = load_page(page)
    lum = image @ np.array([0.3, 0.59, 0.11], np.float32)
    bg = ndimage.gaussian_filter(ndimage.grey_opening(lum, size=(21, 21)), 10)
    a = np.clip((lum - bg - 0.05) / 0.2, 0, 1)
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = center
    hx, hy = half
    ell = np.sqrt(((xx - cx) / hx) ** 2 + ((yy - cy) / hy) ** 2)
    a = a * smooth(1.08, 0.92, ell)
    a = a * (xx < limit[0]) * (yy < limit[1])
    labels, count = ndimage.label(a > 0.25)
    areas = ndimage.sum(np.ones_like(a), labels, range(1, count + 1))
    keep = np.isin(labels, 1 + np.nonzero(areas >= 60)[0])
    a = a * ndimage.binary_dilation(keep, iterations=2)
    box = 110
    crop = a[int(cy) - box:int(cy) + box, int(cx) - box:int(cx) + box]
    image = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8), "L").resize((236, 236), Image.LANCZOS)
    out = np.zeros((256, 256), np.float32)
    out[10:246, 10:246] = np.asarray(image).astype(np.float32) / 255.0
    return np.clip(out * 1.15, 0, 1)


def hand_alpha():
    size = 512
    palm = poly_mask([(178, 262), (342, 262), (360, 330), (346, 410), (318, 470), (206, 470), (176, 400), (168, 330)], size, 0.06, 5)
    fingers = [((198, 270), (190, 112), 40), ((246, 262), (246, 84), 42), ((294, 268), (304, 104), 40), ((338, 290), (360, 168), 34),
               ((186, 372), (102, 262), 44)]
    mask = palm.copy()
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    for (x0, y0), (x1, y1), wd in fingers:
        dx, dy = x1 - x0, y1 - y0
        t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / (dx * dx + dy * dy), 0, 1)
        dist = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
        mask |= dist < wd / 2
    a = ink_outline(mask, 15, 7, size)
    a = np.maximum(a, stroke([(214, 300), (212, 352)], 10, seed=8, taper=(0.4, 0.4)))
    a = np.maximum(a, stroke([(262, 296), (262, 350)], 10, seed=9, taper=(0.4, 0.4)))
    for i, (r, sweep) in enumerate([(196, 0.8), (226, 0.6)]):
        a = np.maximum(a, stroke(wobbly_ring(256, 290, r, 20 + i, -1.1, sweep, 0.01, 14), 13 - i * 2, seed=21 + i))
        a = np.maximum(a, stroke(wobbly_ring(256, 290, r, 30 + i, math.pi + 0.3, sweep, 0.01, 14), 13 - i * 2, seed=31 + i))
    small = Image.fromarray((a * 255).astype(np.uint8), "L").resize((184, 184), Image.LANCZOS)
    canvas = Image.new("L", (256, 256), 0)
    canvas.paste(small, (36, 30))
    return np.asarray(canvas).astype(np.float32) / 255.0


def emblem_ring(seed):
    a = stroke(wobbly_ring(256, 256, 228, seed, 2.3, 4.2, 0.015, 36), 7, seed=seed + 1, taper=(0.5, 0.5))
    return np.asarray(Image.fromarray((a * 255).astype(np.uint8), "L").resize((256, 256), Image.LANCZOS)).astype(np.float32) / 255.0 * 0.55


def power_states(name, a):
    locked = layer(col((92, 74, 60)), a * 0.7)
    save_icon("power_" + name + "_locked", locked, "power")
    core = mix(col(GHOST), col((232, 252, 255)), np.clip(a, 0, 1) ** 2 * 0.55)
    on = empty(256, 256)
    on = over(on, glow_of(a, GHOST, 10, 0.75))
    on = over(on, glow_of(a, GHOST, 3, 0.6))
    on = over(on, layer(core, a))
    save_icon("power_" + name + "_on", on, "power")
    new = empty(256, 256)
    new = over(new, glow_of(a, FLAME, 26, 0.55))
    new = over(new, glow_of(a, GHOST_CORE, 12, 1.0))
    new = over(new, glow_of(a, GHOST_CORE, 3.5, 0.8))
    new = over(new, layer(mix(col(GHOST_CORE), col((245, 255, 255)), np.clip(a, 0, 1) ** 2 * 0.7), a))
    save_icon("power_" + name + "_new", new, "power")
    save_icon("power_" + name + "_ink", layer(col(SOOT), a), "power")


def build_powers():
    for name, (page, center, half, limit) in EMBLEMS.items():
        a = emblem_alpha(page, center, half, limit)
        if name != "ghost":
            a = np.maximum(a, emblem_ring(sum(map(ord, name))))
        power_states(name, a)
    power_states("hands", np.maximum(hand_alpha(), emblem_ring(77)))


def ink_layer(alpha, seed, color=SOOT):
    return layer(col(color), alpha * (0.88 + 0.12 * noise(512, 512, 1.2, seed)))


def paint(parts):
    canvas = empty(512, 512)
    for part in parts:
        canvas = over(canvas, part)
    return canvas


def blob(cx, cy, r, seed, n=48, amp=0.07):
    rng = np.random.default_rng(seed)
    a = np.linspace(0, 2 * math.pi, n, endpoint=False)
    rr = r * (1 + amp * ndimage.gaussian_filter1d(rng.normal(0, 1, n), 2, mode="wrap") * 2.5)
    return list(zip(cx + rr * np.cos(a), cy + rr * np.sin(a)))


def filled(points, base, light, outline_w, seed, wobble=0.05, line=SOOT):
    mask = poly_mask(points, 512, wobble, seed)
    rgb, alpha = wash(mask, base, light, seed)
    return mask, [layer(rgb, alpha), ink_layer(ink_outline(mask, outline_w, seed + 1), seed + 2, line)]


def build_markers():
    mask, parts = filled([(256, 66), (392, 420), (256, 336), (120, 420)], GHOST_INK, GHOST, 20, 300, 0.05)
    save_icon("marker_you", paint([glow_of(mask.astype(np.float32), GHOST, 18, 0.9)] + parts), "marker")
    ring = stroke(wobbly_ring(256, 256, 176, 310, -0.4, 6.75, 0.09, 44), 22, seed=311, taper=(0.2, 0.3))
    cross = np.maximum(stroke([(176, 176), (256, 250), (336, 338)], 30, seed=312), stroke([(338, 172), (260, 258), (172, 342)], 30, seed=313))
    shape = np.maximum(ring, cross)
    save_icon("marker_your_room", paint([glow_of(shape, GHOST, 16, 1.2), layer(col(GHOST_INK), shape)]), "marker")
    parts = []
    rng = np.random.default_rng(320)
    for i, (cx, cy, r) in enumerate([(200, 300, 76), (318, 312, 70), (262, 214, 64), (150, 380, 46), (360, 392, 50), (270, 396, 54)]):
        pts = blob(cx, cy, r, 321 + i, 7, 0.18)
        m, p = filled(pts, (112, 52, 36), (176, 98, 70), 14, 330 + i, 0.0)
        hatch = np.zeros((512, 512), np.float32)
        for k in range(-3, 4):
            x = cx + k * 16 + rng.uniform(-3, 3)
            hatch = np.maximum(hatch, stroke([(x - 30, cy + 34), (x + 30, cy - 34)], 4, seed=340 + i * 10 + k, smooth_path=False))
        parts += p + [ink_layer(hatch * m * 0.55, 350 + i)]
    save_icon("marker_rubble", paint(parts), "marker")
    mask, parts = filled(blob(256, 256, 130, 360), FLAME_DEEP, FLAME_LIGHT, 22, 361)
    shine = stroke([(206, 196), (236, 176)], 18, seed=362) * 0.7
    save_icon("marker_archaeologist", paint([glow_of(mask.astype(np.float32), FLAME, 22, 0.6)] + parts + [layer(col((255, 240, 205)), shine)]), "marker")
    mask, parts = filled(blob(256, 256, 130, 370), (232, 214, 176), HOLY, 22, 371)
    cross = np.maximum(stroke([(256, 178), (256, 336)], 22, seed=372), stroke([(204, 230), (308, 230)], 22, seed=373))
    save_icon("marker_priest", paint([glow_of(mask.astype(np.float32), HOLY, 30, 1.1)] + parts + [ink_layer(cross, 374)]), "marker")
    star = []
    for i in range(8):
        ang = -math.pi / 2 + i * math.pi / 4
        r = 210 if i % 2 == 0 else 52
        star.append((256 + r * math.cos(ang), 256 + r * math.sin(ang)))
    mask = poly_mask(star, 512, 0.03, 380)
    rgb, alpha = wash(mask, GHOST, (236, 252, 255), 381)
    save_icon("marker_memory", paint([glow_of(mask.astype(np.float32), GHOST_CORE, 30, 1.4), glow_of(mask.astype(np.float32), GHOST, 8, 0.8),
                                      layer(rgb, alpha), ink_layer(ink_outline(mask, 9, 382) * 0.6, 383, GHOST_INK)]), "marker")
    wax = [(206, 268), (306, 262), (312, 446), (200, 450)]
    m_wax, wax_parts = filled(wax, PAPER_SHADOW, PAPER, 16, 390)
    flame = [(256, 70), (300, 150), (304, 206), (282, 244), (256, 252), (228, 244), (208, 206), (214, 150)]
    m_flame, flame_parts = filled(flame, FLAME, FLAME_LIGHT, 12, 391, 0.03, FLAME_DEEP)
    wick = stroke([(256, 262), (258, 238)], 8, seed=392)
    save_icon("marker_candle_lit", paint([glow_of(m_flame.astype(np.float32), FLAME, 44, 1.2)] + wax_parts + [ink_layer(wick, 393)] + flame_parts), "marker")
    smoke = stroke([(258, 236), (240, 190), (272, 140), (246, 92), (264, 56)], 10, seed=394, taper=(0.1, 0.9))
    save_icon("marker_candle_out", paint(wax_parts + [ink_layer(wick, 395), layer(col((150, 140, 130)), smoke * 0.7)]), "marker")
    arcs = np.zeros((512, 512), np.float32)
    for i, r in enumerate([90, 150, 210]):
        arcs = np.maximum(arcs, stroke(wobbly_ring(150, 256, r, 400 + i, -0.75, 1.5, 0.02, 12), 26 - i * 4, seed=410 + i))
    dot = poly_mask(blob(150, 256, 34, 420, 24, 0.1), 512)
    save_icon("marker_noise", paint([ink_layer(np.maximum(arcs, dot.astype(np.float32)), 421)]), "marker")
    arrow = [(256, 450), (400, 250), (310, 262), (318, 70), (194, 70), (202, 262), (112, 250)]
    mask, parts = filled(arrow, FLAME_DEEP, FLAME_LIGHT, 20, 430, 0.04)
    save_icon("pointer_arrow", paint([glow_of(mask.astype(np.float32), FLAME, 20, 0.8)] + parts), "marker")
    shackle = stroke(wobbly_ring(256, 214, 84, 440, math.pi, math.pi, 0.02, 20), 34, seed=441, taper=(0.05, 0.05))
    shackle = np.maximum(shackle, stroke([(172, 214), (172, 262)], 34, seed=442, taper=(0.05, 0.05)))
    shackle = np.maximum(shackle, stroke([(340, 214), (340, 262)], 34, seed=443, taper=(0.05, 0.05)))
    body_mask, body = filled([(140, 252), (372, 248), (380, 440), (132, 444)], RUST, (190, 96, 66), 18, 444)
    hole = poly_mask(blob(256, 330, 22, 445, 16, 0.1), 512) | poly_mask([(246, 336), (266, 336), (272, 392), (240, 392)], 512)
    save_icon("lock", paint([layer(col((96, 88, 82)), shackle), ink_layer(ink_outline(shackle > 0.5, 10, 446), 447)] + body +
                            [ink_layer(hole.astype(np.float32), 448)]), "ui")
    cover = [(132, 108), (370, 96), (392, 412), (150, 426)]
    m_cover, cover_parts = filled(cover, LEATHER, (128, 82, 54), 18, 450)
    pages = stroke([(162, 432), (392, 420)], 16, seed=451, taper=(0.05, 0.05))
    spine = stroke([(170, 116), (186, 420)], 10, seed=452)
    band = stroke([(186, 196), (372, 186)], 8, seed=453)
    save_icon("book", paint([layer(col(PAPER), pages)] + cover_parts + [ink_layer(spine, 454), layer(col(GILT), band)]), "ui")
    hand = hand_alpha()
    save_icon("hand_ink", layer(col(SOOT), hand), "ui")
    tick = stroke([(150, 270), (226, 352), (370, 150)], 34, seed=460, taper=(0.15, 0.5), smooth_path=False)
    save_icon("step_done", paint([ink_layer(tick, 461)]), "ui")
    save_icon("step_done_light", paint([ink_layer(tick, 461, PAPER)]), "ui")
    mask, parts = filled(blob(256, 256, 120, 462), FLAME_DEEP, FLAME_LIGHT, 20, 463)
    save_icon("step_current", paint([glow_of(mask.astype(np.float32), FLAME, 24, 0.9)] + parts), "ui")
    ring = stroke(wobbly_ring(256, 256, 120, 464, 0.2, 6.2, 0.05, 36), 20, seed=465)
    save_icon("step_later", paint([layer(col(STONE), ring * 0.75)]), "ui")
    save_icon("step_later_light", paint([layer(col(PAPER_SHADOW), ring * 0.85)]), "ui")
    box = stroke([(132, 140), (380, 132), (388, 384), (126, 392), (134, 128)], 22, seed=470, taper=(0.05, 0.05), smooth_path=False)
    box_mask = poly_mask([(140, 146), (374, 140), (380, 378), (134, 384)], 512)
    paper_fill = layer(paper_tex(512, 512, 471), box_mask.astype(np.float32))
    save_icon("check_off", paint([paper_fill, ink_layer(box, 472)]), "ui")
    tick = stroke([(170, 262), (240, 336), (400, 110)], 36, seed=473, taper=(0.15, 0.5), smooth_path=False)
    save_icon("check_on", paint([paper_fill, ink_layer(box, 472), layer(col(FLAME_DEEP), tick)]), "ui")
    mask, parts = filled([(256, 96), (330, 230), (340, 320), (300, 392), (256, 408), (212, 392), (172, 320), (182, 230)], FLAME_DEEP, FLAME_LIGHT, 20, 480)
    save_icon("slider_knob", paint([glow_of(mask.astype(np.float32), SOOT, 10, 0.6)] + parts), "ui")
    small = Image.open(os.path.join(OUT, "icons", "slider_knob.png")).resize((48, 48), Image.LANCZOS)
    small.save(os.path.join(OUT, "icons", "slider_knob_48.png"), optimize=True)
    manifest["icons"]["slider_knob_48"] = {"file": "icons/slider_knob_48.png", "size": [48, 48], "kind": "ui"}
    for name, pts in [("arrow_left", [(380, 256), (140, 256)]), ("arrow_right", [(132, 256), (372, 256)]),
                      ("arrow_up", [(256, 380), (256, 140)]), ("arrow_down", [(256, 132), (256, 372)])]:
        (x0, y0), (x1, y1) = pts
        dx, dy = (x1 - x0) / 240, (y1 - y0) / 240
        shaft = stroke(pts, 40, seed=490, taper=(0.1, 0.05), smooth_path=False)
        head_a = stroke([(x1 - dx * 100 - dy * 90, y1 - dy * 100 + dx * 90), (x1, y1)], 40, seed=491, taper=(0.3, 0.05), smooth_path=False)
        head_b = stroke([(x1 - dx * 100 + dy * 90, y1 - dy * 100 - dx * 90), (x1, y1)], 40, seed=492, taper=(0.3, 0.05), smooth_path=False)
        save_icon("glyph_" + name, paint([ink_layer(np.maximum.reduce([shaft, head_a, head_b]), 493)]), "glyph")


def keycap(label, width, height, seed):
    insets, margins = (18, 24, 18, 18), (8, 10, 8, 8)
    period = (width + 16 - 36, height + 18 - 42)
    tmp_name = "_tmp_key"
    nine_slice(tmp_name, "paper", period, insets, margins, seed, rag=(0.9, 0.9), fray=0.4, age=(SCORCH, 0.35, 4),
               chip=(0.5, 2.0), cap=(1.6, 6.0), outline=(2.4, SOOT, 0.95), shadow=(0.55, 2.5, 2.5), relief=0.2)
    path = os.path.join(OUT, "nine", tmp_name + ".png")
    cap = Image.open(path).convert("RGBA")
    os.remove(path)
    del manifest["nine_slice"][tmp_name]
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    ox, oy = (256 - cap.width) // 2, (256 - cap.height) // 2
    canvas.alpha_composite(cap, (ox, oy))
    face_cx, face_cy = 128, oy + 10 + (height - 6) / 2
    if label.startswith("glyph_"):
        glyph = Image.open(os.path.join(OUT, "icons", label + ".png")).resize((int(height * 0.62),) * 2, Image.LANCZOS)
        canvas.alpha_composite(glyph, (int(face_cx - glyph.width / 2), int(face_cy - glyph.height / 2)))
    else:
        size = int(height * (0.62 if len(label) == 1 else 0.36))
        font = ImageFont.truetype(BOLD, size)
        draw = ImageDraw.Draw(canvas)
        draw.text((face_cx, face_cy), label, font=font, fill=SOOT + (240,), anchor="mm")
    return canvas


def build_keys():
    keys = [("e", "E", 150, 150), ("w", "W", 150, 150), ("a", "A", 150, 150), ("s", "S", 150, 150), ("d", "D", 150, 150),
            ("j", "J", 150, 150), ("m", "M", 150, 150), ("q", "Q", 150, 150), ("shift", "Shift", 236, 130),
            ("esc", "Esc", 200, 130), ("tab", "Tab", 200, 130), ("enter", "Enter", 236, 130), ("space", "Пробіл", 240, 120),
            ("left", "glyph_arrow_left", 150, 150), ("right", "glyph_arrow_right", 150, 150),
            ("up", "glyph_arrow_up", 150, 150), ("down", "glyph_arrow_down", 150, 150)]
    for i, (slug, label, width, height) in enumerate(keys):
        image = keycap(label, width, height, 600 + i)
        path = os.path.join(OUT, "icons", "key_" + slug + ".png")
        image.save(path, optimize=True)
        manifest["icons"]["key_" + slug] = {"file": "icons/key_" + slug + ".png", "size": [256, 256], "kind": "key"}


def title(slug, text, size, tone, seed, swash=False, glow=None):
    scale = 2
    font = ImageFont.truetype(BOLD, size * scale)
    rng = np.random.default_rng(seed)
    tracking = 0.03 * size * scale
    widths = [font.getlength(ch) for ch in text]
    pad = int(size * scale * 0.5)
    w = int(sum(widths) + tracking * (len(text) - 1) + pad * 2)
    h = int(size * scale * 1.55 + pad * 2)
    mask = Image.new("L", (w, h), 0)
    x = pad
    base = pad + size * scale * 1.05
    for ch, cw in zip(text, widths):
        if ch.strip():
            glyph = Image.new("L", (int(cw + size * scale), int(size * scale * 2)), 0)
            ImageDraw.Draw(glyph).text((size * scale * 0.5, size * scale * 1.4), ch, font=font, fill=255, anchor="ls")
            glyph = glyph.rotate(rng.uniform(-1.8, 1.8), resample=Image.BICUBIC)
            dy = rng.uniform(-0.025, 0.025) * size * scale
            mask.paste(Image.new("L", glyph.size, 255), (int(x - size * scale * 0.5), int(base - size * scale * 1.4 + dy)), glyph)
        x += cw + tracking
    m = np.asarray(mask).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = noise(h, w, 7 * scale, seed + 1) * 2.0 * scale
    dy = noise(h, w, 7 * scale, seed + 2) * 2.0 * scale
    m = ndimage.map_coordinates(m, [yy + dy, xx + dx], order=1)
    if swash:
        points = [(pad + w * 0.02, base + size * scale * 0.2), (w * 0.3, base + size * scale * 0.3),
                  (w * 0.65, base + size * scale * 0.17), (w - pad - w * 0.02, base + size * scale * 0.24)]
        m = np.maximum(m, swash_stroke(points, size * scale * 0.075, w, h, seed + 3))
    m = ndimage.gaussian_filter(m, 1.1 * scale) + 0.09 * noise(h, w, 0.9, seed + 4)
    alpha = smooth(0.42, 0.58, m)
    inside = ndimage.distance_transform_edt(alpha > 0.5).astype(np.float32)
    dry = noise(h, w, 1.0 * scale, seed + 5, 9, 0.08)
    alpha = alpha * (1 - smooth(1.3, 2.1, dry) * smooth(3 * scale, 7 * scale, inside) * 0.55)
    pool = np.exp(-inside / (2.0 * scale))
    var = noise(h, w, 14 * scale, seed + 6)
    if tone == "ink":
        rgb = col(SOOT) * (1 + 0.5 * var)[..., None] + col((40, 26, 18)) * 0.3
        rgb = rgb * (1 - 0.3 * pool)[..., None]
    else:
        rgb = mix(col(PAPER), col((255, 247, 228)), np.clip(0.4 + 0.25 * var, 0, 1))
        rgb = mix(rgb, col(PAPER_SHADOW), pool * 0.55)
    canvas = empty(h, w)
    if tone == "light":
        sh = ndimage.gaussian_filter(ndimage.shift(alpha, (4 * scale, 2 * scale), order=1), 3 * scale) * 0.85
        canvas = over(canvas, layer(col(SOOT), sh))
    if glow:
        canvas = over(canvas, layer(col(glow[0]), np.clip(ndimage.gaussian_filter(alpha, glow[2] * scale) * glow[1], 0, 1)))
    canvas = over(canvas, layer(np.clip(rgb, 0, 1), alpha))
    ys, xs = np.nonzero(canvas[..., 3] > 0.01)
    margin = 8 * scale
    y0, y1 = max(0, ys.min() - margin), min(h, ys.max() + margin)
    x0, x1 = max(0, xs.min() - margin), min(w, xs.max() + margin)
    canvas = canvas[y0:y1, x0:x1]
    out_size = (int(x1 - x0) // scale, int(y1 - y0) // scale)
    name = "title_" + slug + "_" + tone
    save_rgba(canvas, os.path.join(OUT, "titles", name + ".png"), out_size)
    manifest["titles"][name] = {"file": "titles/" + name + ".png", "size": list(out_size), "text": text}


def swash_stroke(points, width, w, h, seed):
    pts = catmull(points, 40)
    rng = np.random.default_rng(seed)
    n = len(pts)
    t = np.linspace(0, 1, n)
    press = np.clip(np.minimum(t / 0.15, (1 - t) / 0.55), 0, 1) ** 0.6
    widths = width * (0.2 + 0.8 * press) * (1 + 0.1 * ndimage.gaussian_filter1d(rng.normal(0, 1, n), 4))
    image = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(image)
    for (x, y), r in zip(pts, widths / 2):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return np.asarray(image).astype(np.float32) / 255.0


def build_titles():
    items = [("simnadtsiatyi", "Сімнадцятий", 150, True), ("pauza", "Пауза", 112, False), ("karta", "Карта", 96, False),
             ("knyha", "Книга", 96, False), ("nalashtuvannia", "Налаштування", 96, False), ("ty_vilnyi", "Ти вільний", 128, True)]
    for i, (slug, text, size, swash) in enumerate(items):
        title(slug, text, size, "light", 700 + i * 10, swash, (FLAME, 0.35, 22) if slug == "simnadtsiatyi" else None)
        title(slug, text, size, "ink", 705 + i * 10, swash)


def build_textures():
    n = 1024
    items = {"paper": paper_tex(n, n, 900), "paper_aged": paper_tex(n, n, 901, (222, 202, 166), (184, 158, 118), 1.3),
             "stone": stone_tex(n, n, 902), "leather": leather_tex(n, n, 903), "map_paper": map_tex(n, n, 904, 64)}
    for name, rgb in items.items():
        path = os.path.join(OUT, "textures", name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
        manifest["textures"][name] = {"file": "textures/" + name + ".png", "size": [n, n], "seamless": True}


def build_images():
    crops = {"memory_1": ("memory_1", (40, 230, 600, 610)), "memory_2": ("memory_2", (230, 40, 790, 420)),
             "memory_3": ("memory_3", (300, 930, 980, 1390)), "memory_5": ("memory_5", (100, 1040, 1000, 1440))}
    for name, (page, box) in crops.items():
        image = Image.open(os.path.join(PAGES, page + ".png")).convert("RGB").crop(box)
        image.thumbnail((520, 360), Image.LANCZOS)
        path = os.path.join(OUT, "images", "thumb_" + name + ".jpg")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        image.save(path, quality=88)
        manifest["images"]["thumb_" + name] = {"file": "images/thumb_" + name + ".jpg", "size": list(image.size)}


if __name__ == "__main__":
    steps = {"nine": build_nine, "swatches": build_swatches, "powers": build_powers, "markers": build_markers, "keys": build_keys,
             "titles": build_titles, "textures": build_textures, "images": build_images}
    design_only = {"swatches", "images"}
    manifest_path = os.path.join(OUT, "manifest.json")
    if os.path.exists(manifest_path):
        manifest.update(json.load(open(manifest_path, encoding="utf-8")))
    for key, fn in steps.items():
        if ONLY == key or (ONLY == "all" and key not in design_only):
            fn()
            print("done", key)
    os.makedirs(OUT, exist_ok=True)
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
