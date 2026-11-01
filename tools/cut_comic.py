"""Cuts a finished comic page into the drop-in layers scripts/comic_page.gd stacks: A..F.png, each the full page with
only that panel opaque, and frame.png, the page with the panels cut out. Prints the shapes for LAYOUTS in comic_data.gd.
Also lays the whole memory pages out on the art/comic/memories sheet the book and the finale show (GRID).

python tools/cut_comic.py <folder with the artist's pages> art/comic
"""
import os
import sys

from PIL import Image, ImageDraw

SS = 3  # mask supersampling, smooth diagonal edges
# art/comic/<page>: source file, panels in reading order as polygons in source pixels
PAGES = {
    "prologue": ("photo_3_2026-10-31_13-35-39.jpg", [
        [(30, 20), (375, 20), (548, 512), (30, 512)],
        [(398, 18), (1036, 18), (1036, 987), (712, 987)],
        [(30, 528), (553, 528), (697, 985), (30, 985)],
        [(28, 1005), (378, 1005), (378, 1450), (28, 1450)],
        [(395, 1005), (698, 1005), (698, 1450), (395, 1450)],
        [(716, 1005), (1036, 1005), (1036, 1450), (716, 1450)],
    ]),
    "prologue2": ("photo_5_2026-10-31_13-35-39.jpg", [
        [(30, 18), (375, 18), (550, 500), (30, 500)],
        [(395, 18), (1032, 18), (1032, 930), (705, 930)],
        [(30, 516), (555, 516), (688, 928), (30, 928)],
        [(30, 946), (358, 946), (308, 1455), (30, 1455)],
        [(372, 946), (672, 946), (672, 1455), (322, 1455)],
        [(688, 946), (1036, 946), (1036, 1455), (688, 1455)],
    ]),
    "memory_1": ("спогад/photo_1_2026-10-31_14-08-33.jpg", [
        [(27, 20), (440, 20), (585, 697), (27, 632)],
        [(460, 20), (1032, 20), (1032, 755), (605, 700)],
        [(27, 648), (1032, 775), (1032, 1456), (27, 1456)],
    ]),
    "memory_2": ("спогад/photo_2_2026-10-31_14-08-33.jpg", [
        [(25, 18), (1034, 18), (1034, 225), (25, 408)],
        [(25, 428), (1034, 243), (1034, 1015), (25, 893)],
        [(25, 915), (1034, 1033), (1034, 1455), (25, 1455)],
    ]),
    "memory_3": ("спогад/photo_3_2026-10-31_14-08-33.jpg", [
        [(25, 20), (1034, 20), (1034, 212), (25, 363)],
        [(25, 378), (1034, 228), (1034, 880), (25, 797)],
        [(25, 815), (1034, 897), (1034, 1458), (25, 1458)],
    ]),
    "memory_4": ("спогад/photo_2026-10-31_21-37-13.jpg", [
        [(24, 16), (1037, 15), (1037, 236), (24, 380)],
        [(24, 391), (1037, 247), (1037, 678), (24, 708)],
        [(24, 717), (1037, 687), (1037, 1046), (24, 992)],
        [(24, 1005), (571, 1033), (424, 1463), (24, 1463)],
        [(584, 1033), (1037, 1057), (1037, 1463), (436, 1463)],
    ]),
    "memory_5": ("спогад/photo_4_2026-10-31_14-08-33.jpg", [
        [(28, 20), (1034, 20), (1034, 313), (28, 475)],
        [(28, 492), (513, 412), (603, 815), (28, 888)],
        [(530, 408), (1034, 325), (1034, 757), (620, 810)],
        [(28, 908), (1034, 772), (1034, 1458), (28, 1458)],
    ]),
    "finale": ("фінал/finale.jpg", [
        [(28, 16), (375, 16), (555, 519), (28, 519)],
        [(391, 16), (1039, 16), (1039, 519), (569, 519)],
        [(28, 524), (554, 524), (689, 967), (28, 967)],
        [(570, 524), (1039, 524), (1039, 967), (704, 967)],
        [(28, 976), (584, 976), (504, 1452), (28, 1452)],
        [(598, 976), (1039, 976), (1039, 1452), (518, 1452)],
    ]),
}
# art/comic/memories: 3 × 2 sheet of whole pages; letter -> page.
GRID = {"A": "memory_1", "B": "memory_2", "C": "memory_3", "D": "memory_4", "E": "memory_5", "F": "finale"}
CELL = (530, 744)
GAP = 20


def mask(size, polys):
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    draw = ImageDraw.Draw(big)
    for p in polys:
        draw.polygon([(x * SS, y * SS) for x, y in p], fill=255)
    return big.resize(size, Image.LANCZOS)


src, out = sys.argv[1:3]
for page, (file, panels) in PAGES.items():
    if not os.path.exists(os.path.join(src, file)):
        continue  # cut only the pages whose source is in the folder, keep the rest as they are
    img = Image.open(os.path.join(src, file)).convert("RGBA")
    os.makedirs(os.path.join(out, page), exist_ok=True)
    w, h = img.size
    print(f'"{page}": {{"aspect": {w / h:.3f}, "shapes": {{')
    for letter, poly in zip("ABCD" if len(panels) == 4 else "ABCDEF", panels):
        layer = img.copy()
        layer.putalpha(mask(img.size, [poly]))
        layer.save(os.path.join(out, page, letter + ".png"))
        pts = ", ".join(f"Vector2({x / w:.3f}, {y / h:.3f})" for x, y in poly)
        print(f'\t"{letter}": [{pts}],')
    print("}},")
    frame = img.copy()
    frame.putalpha(mask(img.size, panels).point(lambda a: 255 - a))
    frame.save(os.path.join(out, page, "frame.png"))

sheet = (CELL[0] * 3 + GAP * 4, CELL[1] * 2 + GAP * 3)
os.makedirs(os.path.join(out, "memories"), exist_ok=True)
for letter, page in GRID.items():
    if not os.path.exists(os.path.join(src, PAGES[page][0])):
        continue
    i = "ABCDEF".index(letter)
    at = (GAP + (i % 3) * (CELL[0] + GAP), GAP + (i // 3) * (CELL[1] + GAP))
    layer = Image.new("RGBA", sheet, (0, 0, 0, 0))
    layer.paste(Image.open(os.path.join(src, PAGES[page][0])).convert("RGBA").resize(CELL, Image.LANCZOS), at)
    layer.save(os.path.join(out, "memories", letter + ".png"))
