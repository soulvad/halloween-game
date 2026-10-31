# Cellar floor of the 1800s: irregular stone flags of different sizes set in packed earth, worn and uneven.
# Writes a tileable art/textures/floor.png (albedo) + floor_normal.png (wall.gd textured() picks the normal map up).
# One tile = 4 m in game (uv scale 0.25). Run: python tools/draw_floor.py
import numpy as np
from PIL import Image

N = 1024
GRID = 10  # seeds on a jittered 10 x 10 grid: flags 0.3–0.6 m, no clumps of slivers
rng = np.random.default_rng(1832)


def noise(cells, seed):  # tileable value noise, 0..1
    g = np.random.default_rng(seed).random((cells, cells))
    t = np.linspace(0, cells, N, endpoint=False)
    i = t.astype(int); f = t - i; f = f * f * (3 - 2 * f)
    j = (i + 1) % cells
    a = g[i][:, i] * (1 - f)[None, :] + g[i][:, j] * f[None, :]
    b = g[j][:, i] * (1 - f)[None, :] + g[j][:, j] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def fbm(seed, base=4, octaves=5):
    return sum(noise(base * 2 ** o, seed + o) / 2 ** o for o in range(octaves)) / (2 - 2 ** (1 - octaves))


# warped coordinates so the stone edges wobble instead of running straight
yy, xx = np.mgrid[0:N, 0:N].astype(float)
wx = xx + (fbm(11, 8) - 0.5) * 40
wy = yy + (fbm(12, 8) - 0.5) * 40
cell = N / GRID
pts = np.array([((i + 0.5 + rng.uniform(-0.38, 0.38)) * cell, (j + 0.5 + rng.uniform(-0.38, 0.38)) * cell)
                for i in range(GRID) for j in range(GRID)])
STONES = len(pts)
d1 = np.full((N, N), 1e9); d2 = np.full((N, N), 1e9); idx = np.zeros((N, N), int)
for k, (px, py) in enumerate(pts):  # nearest two seeds, wrapping around the tile
    dx = np.abs(wx - px); dx = np.minimum(dx, N - dx)
    dy = np.abs(wy - py); dy = np.minimum(dy, N - dy)
    d = np.hypot(dx, dy)
    closer = d < d1
    d2 = np.where(closer, d1, np.minimum(d2, d))
    idx = np.where(closer, k, idx)
    d1 = np.where(closer, d, d1)
edge = d2 - d1  # 0 on the joint between two stones

gap = 6 + 12 * fbm(13, 6) ** 2  # joint width in px, uneven
joint = np.clip(1 - edge / gap, 0, 1)
stone_h = rng.random(STONES)[idx] * 0.5  # every flag sits at its own height
dome = np.clip(edge / 60, 0, 1) ** 0.5  # rounded, worn edges
grain = fbm(14, 16, 4)
height = (stone_h + 0.6 * dome + 0.15 * grain) * (1 - joint) + 0.08 * grain * joint
height += 0.25 * fbm(15, 2, 3)  # the whole floor sags here and there

# colour: grey-brown flags, each a little different, earth in the joints, dark damp patches, worn light tops
warm = rng.random(STONES)  # one stone type, each flag a bit lighter / darker, warmer / greyer
tint = np.array([0.40, 0.37, 0.33])[None] * (0.8 + 0.35 * rng.random(STONES))[:, None]
tint = tint * (1 - 0.12 * warm[:, None]) + 0.12 * warm[:, None] * np.array([0.42, 0.34, 0.26])[None]
pits = np.clip((fbm(18, 48, 2) - 0.68) * 3, 0, 1)
col = tint[idx] * (0.72 + 0.4 * grain[..., None]) * (1 - 0.35 * pits[..., None])
col *= (0.85 + 0.25 * dome)[..., None]
earth = np.array([0.24, 0.19, 0.14]) * (0.7 + 0.6 * fbm(16, 12, 3))[..., None]
col = col * (1 - joint[..., None]) + earth * joint[..., None]
damp = np.clip((fbm(17, 3, 4) - 0.55) * 4, 0, 1)
col *= (1 - 0.35 * damp)[..., None]
col = np.clip(col * 255 * 1.15, 0, 255).astype(np.uint8)
Image.fromarray(col).save("art/textures/floor.png")

# normal map from the height (tileable gradients), OpenGL convention (Godot)
s = 6.0
gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * s
gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * s
n = np.stack([-gx, gy, np.ones_like(gx)], -1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save("art/textures/floor_normal.png")
print("wrote art/textures/floor.png, floor_normal.png")
