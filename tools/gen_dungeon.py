# Generates scenes/game.tscn: "Підземелля старого міста" from the user's sketch.
# Carved spaces (rooms, corridors, doors) are rectangles on a 0.25 m grid; walls go on every carved/rock edge.
import sys, math

OUT = sys.argv[1]
G = 0.25
X0, X1, Z0, Z1 = -14.5, 24.0, -13.0, 12.5
H = 3.0  # wall height

def t(x, y, z, rot_y=False):
    b = "0, 0, 1, 0, 1, 0, -1, 0, 0" if rot_y else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return f"Transform3D({b}, {x:g}, {y:g}, {z:g})"
def v3(s): return f"Vector3({s[0]:g}, {s[1]:g}, {s[2]:g})"
def col(c): return f"Color({c[0]:g}, {c[1]:g}, {c[2]:g}, 1)"

# name -> (x0, z0, x1, z1)
rooms = {
    "CorridorV": (-1.25, -7.0, 1.25, 12.0),
    "CorridorH": (-11.5, -7.0, 12.5, -4.75),
    "FarLeft": (-14, -9.5, -12, -2.75),
    "R1L": (-9, -10.5, -1, -7.5), "R1R": (1.75, -10.5, 9.5, -7.5),
    "R2L": (-9, -4.25, -1.75, -1.5), "R2R": (1.75, -4.25, 9.5, -1.0),
    "R3L": (-8.5, -0.5, -1.75, 3.5), "R3R": (1.75, 0, 9.5, 3.75),
    "R4L": (-8, 4.5, -1.75, 9.75), "R4R": (1.75, 4.25, 10, 9.5),
    "RightTall": (13, -9.75, 15.75, -2.75),
    "PassageUp": (10.25, -11.75, 12, -7.0),
    "PassageTop": (10.25, -11.75, 17.5, -10.0),
    "YourRoom": (17.5, -12.5, 23.5, -7.75),
}
doors = [  # >= 1.75 m wide, or the navmesh (agent radius 0.5) closes them
    (-12, -7.0, -11.5, -5.25),  # far left
    (-3.75, -7.5, -2, -7.0), (2.5, -7.5, 4.25, -7.0),  # row 1
    (-3.75, -4.75, -2, -4.25), (2.5, -4.75, 4.25, -4.25),  # row 2
    (-1.75, 0.25, -1.25, 2.0), (1.25, 0.25, 1.75, 2.0),  # row 3
    (-1.75, 6.25, -1.25, 8.0), (1.25, 6.25, 1.75, 8.0),  # row 4
    (12.5, -7.0, 13, -5.25),  # right tall room
]
NX, NZ = round((X1 - X0) / G), round((Z1 - Z0) / G)
grid = [[False] * NZ for _ in range(NX)]
for (a, b, c, d) in list(rooms.values()) + doors:
    for i in range(round((a - X0) / G), round((c - X0) / G)):
        for k in range(round((b - Z0) / G), round((d - Z0) / G)):
            grid[i][k] = True
def carved(i, k): return 0 <= i < NX and 0 <= k < NZ and grid[i][k]

WALL = (0.36, 0.33, 0.38); BOUND = (0.12, 0.1, 0.14); FURN = (0.4, 0.28, 0.18)
walls = []  # (name, (x, z), size, solid_from, color)
T = 0.3
# horizontal edges (between k-1 and k), runs along x
for k in range(NZ + 1):
    for side in (-1, 1):  # -1: rock is at k-1 (north edge of cell k), 1: rock at k (south edge of cell k-1)
        i = 0
        while i < NX:
            cell = k if side == -1 else k - 1
            rock = k - 1 if side == -1 else k
            if carved(i, cell) and not carved(i, rock):
                j = i
                while j < NX and carved(j, cell) and not carved(j, rock):
                    j += 1
                x0, x1 = X0 + i * G - T / 2, X0 + j * G + T / 2
                z = Z0 + k * G + (-T / 2 if side == -1 else T / 2)
                walls.append(((x0 + x1) / 2, z, (x1 - x0, H, T)))
                i = j
            else:
                i += 1
for i in range(NX + 1):
    for side in (-1, 1):
        k = 0
        while k < NZ:
            cell = i if side == -1 else i - 1
            rock = i - 1 if side == -1 else i
            if carved(cell, k) and not carved(rock, k):
                j = k
                while j < NZ and carved(cell, j) and not carved(rock, j):
                    j += 1
                z0, z1 = Z0 + k * G - T / 2, Z0 + j * G + T / 2
                x = X0 + i * G + (-T / 2 if side == -1 else T / 2)
                walls.append((x, (z0 + z1) / 2, (T, H, z1 - z0)))
                k = j
            else:
                k += 1
wall_nodes = [(f"Wall{n}", (x, z), s, 2, WALL) for n, (x, z, s) in enumerate(walls)]
cx, cz, w, d = (X0 + X1) / 2, (Z0 + Z1) / 2, X1 - X0, Z1 - Z0
wall_nodes += [
    ("BoundN", (cx, Z0 - 0.5), (w + 2, H, 1), 1, BOUND), ("BoundS", (cx, Z1 + 0.5), (w + 2, H, 1), 1, BOUND),
    ("BoundW", (X0 - 0.5, cz), (1, H, d + 2), 1, BOUND), ("BoundE", (X1 + 0.5, cz), (1, H, d + 2), 1, BOUND),
]
furniture = [
    ("CrateR1L", (-7.5, -9.6), (1.2, 0.9, 1.0)), ("TableR1R", (7.5, -9.7), (2.2, 0.8, 1.0)),
    ("BunksR2L", (-8.3, -2.9), (1.0, 0.7, 2.4)), ("BarrelsR2R", (8.6, -1.8), (1.2, 1.0, 1.2)),
    ("PlankR3L", (-7.8, 2.6), (1.0, 0.6, 1.6)), ("CrateR3R", (8.5, 3.0), (1.4, 0.9, 1.0)),
    ("ShelfR4L", (-7.5, 9.2), (1.0, 1.6, 0.8)), ("TableR4R", (8.0, 5.2), (2.0, 0.8, 1.2)),
    ("StonesRT", (15.0, -9.0), (1.2, 0.6, 1.0)), ("BunkYourRoom", (18.3, -8.4), (1.4, 0.5, 0.9)),
]
wall_nodes += [(n, p, s, 3, FURN) for n, p, s in furniture]

MEMORY, CANDLE, HAUNT, MIRROR, PLAN, DOOR, KNOCK, EVIDENCE, CIRCLE = range(9)
CYAN = (0.6, 0.95, 1); ORANGE = (1, 0.48, 0.1); DULL = (0.45, 0.4, 0.38); FLAME = (1, 0.75, 0.35)
GLINT = (0.18, 0.18, 0.18); CANDLE_SIZE = (0.12, 0.3, 0.12)
# Rooms in the story: R1L servants' bedroom, CorridorH corridor with shackles, R3R kitchen, R2R mirror room,
# R4R archaeologists' camp, FarLeft steward's closet, PassageUp/Top behind the door, YourRoom behind the bricked wall.
# name, (x, z), kind, title, need, size, color, extra exports (y = height of the base)
stations = [
    ("Memory1", (-8.4, -10.0), MEMORY, "Свистулька-пташка", "", GLINT, CYAN, {"memory_id": 1, "y": 0.9}),
    ("Memory2", (-9.5, -6.7), MEMORY, "Бляха «17»", "", GLINT, CYAN, {"memory_id": 2, "y": 0.6}),
    ("Memory3", (9.1, 3.4), MEMORY, "Лист від матері", "", GLINT, CYAN, {"memory_id": 3, "y": 1.0}),
    ("Memory4", (-13.2, -9.0), MEMORY, "Ключ від хвіртки", "", GLINT, CYAN, {"memory_id": 4, "y": 0.6}),
    ("Memory5", (23.3, -11.6), MEMORY, "Ім'я на стіні", "", GLINT, CYAN, {"memory_id": 5, "y": 1.1}),
    ("Circle", (20.5, -10.0), CIRCLE, "Коло ритуалу", "", (2.4, 0.06, 2.4), (1, 0.56, 0.69), {}),
    ("Shackles", (18.2, -12.1), EVIDENCE, "Кайдани", "", (0.7, 0.4, 0.3), DULL, {}),
    ("Tally", (23.3, -9.6), EVIDENCE, "Подряпини-дні", "", (0.12, 1.2, 1.6), DULL, {}),
    ("Bowl", (21.6, -8.2), EVIDENCE, "Миска", "", (0.5, 0.2, 0.5), DULL, {}),
    ("CandleEntrance", (0.9, 5.5), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "true", "y": 0.8}),
    ("CandleHall", (0.9, -1.0), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "true", "y": 0.8}),
    ("CandleMirror", (5.5, -1.4), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "false", "y": 0.8}),
    ("CandleKitchen", (8.5, 1.0), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "true", "y": 0.8}),
    ("CandleCorridor", (-0.9, -6.8), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "true", "y": 0.8}),
    ("CandleBedroom", (-5.0, -9.9), CANDLE, "Свічка", "breath", CANDLE_SIZE, FLAME, {"lit": "false", "y": 0.8}),
    ("Chains", (-10.5, -6.85), HAUNT, "Кайдани на стіні", "sound", (0.4, 0.9, 0.2), ORANGE, {"power": 1}),
    ("Bell", (-6.0, -6.7), HAUNT, "Дзвоник слуг", "sound", (0.3, 0.4, 0.3), ORANGE, {"power": 1}),
    ("Jug", (6.0, 2.0), HAUNT, "Глиняний глек", "sound", (0.4, 0.5, 0.4), ORANGE, {"power": 1}),
    ("Grate", (-13.6, -4.0), HAUNT, "Іржаві ґрати", "sound", (0.2, 1.4, 1.2), ORANGE, {"power": 1}),
    ("Chest", (-5.0, 8.2), HAUNT, "Стара скриня", "sound", (1.0, 0.6, 0.6), ORANGE, {"power": 1}),
    ("Niche", (15.2, -4.2), HAUNT, "Кістки в ніші", "sound", (0.5, 0.4, 0.4), ORANGE, {"power": 1}),
    ("GateBell", (0.85, 10.0), HAUNT, "Дзвін біля входу", "sound", (0.3, 0.5, 0.3), ORANGE, {"power": 1}),
    ("DripChain", (11.6, -8.6), HAUNT, "Ланцюг у проході", "sound", (0.2, 0.9, 0.2), ORANGE, {"power": 1}),
    ("Mirror", (9.35, -2.6), MIRROR, "Запилене дзеркало", "write", (0.1, 1.4, 0.9), (0.6, 0.65, 0.7), {"y": 0.3}),
    ("Plan", (8.0, 5.2), PLAN, "План маєтку", "sound", (0.9, 0.04, 0.6), (0.85, 0.75, 0.55), {"y": 0.8}),
    ("Door", (11.125, -7.0), DOOR, "Двері", "hands", (1.75, 2.4, 0.15), (0.35, 0.22, 0.12), {}),
    ("Wall", (13.95, -10.875), KNOCK, "Цегляна стіна", "hands", (0.1, 2.0, 1.5), (0.5, 0.3, 0.25), {"y": 0.2}),
]
dig_sites = [(-5, -9), (5.5, -9), (-5, -2.8), (5.5, -2.6), (-5, 1.5), (5.5, 2), (-5, 7), (6, 7),
             (-13, -6), (14.4, -6), (0, 3), (0, -5.9)]
ARCH, PRIEST = 0, 1
visitors = [("Olena", (0, 11.0), ARCH, "Олена", (0.35, 0.55, 0.4)), ("Taras", (0.8, 11.6), ARCH, "Тарас", (0.55, 0.45, 0.3)),
            ("Priest", (0, 11.8), PRIEST, "Отець Василь", (0.12, 0.1, 0.12))]
lights = [((0, 2.4, -5.9), 7), ((0, 2.4, 4), 7), ((-11, 2.4, -6), 6), ((11.1, 2.4, -9), 6), ((-5, 2.4, 7), 6), ((5.5, 2.4, -2.6), 6)]

o = ["""[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/game.gd" id="1_game"]
[ext_resource type="Script" path="res://scripts/wall.gd" id="2_wall"]
[ext_resource type="Script" path="res://scripts/station.gd" id="3_station"]
[ext_resource type="Script" path="res://scripts/visitor.gd" id="4_visitor"]
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="5_player"]
[ext_resource type="Script" path="res://scripts/hud.gd" id="6_hud"]

[sub_resource type="Environment" id="Environment_dungeon"]
background_mode = 1
background_color = Color(0.02, 0.015, 0.03, 1)
ambient_light_source = 2
ambient_light_color = Color(0.3, 0.3, 0.45, 1)
ambient_light_energy = 0.6
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.12, 0.1, 0.18, 1)
fog_density = 0.04

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.2, 0.18, 0.2, 1)

[sub_resource type="PlaneMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector2(%g, %g)

[sub_resource type="StandardMaterial3D" id="Mat_ceiling"]
albedo_color = Color(0.1, 0.09, 0.11, 1)

[sub_resource type="BoxMesh" id="Mesh_ceiling"]
material = SubResource("Mat_ceiling")
size = Vector3(%g, 0.2, %g)

[node name="Game" type="Node3D"]
script = ExtResource("1_game")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_dungeon")

[node name="Level" type="Node3D" parent="."]

[node name="Floor" type="MeshInstance3D" parent="Level"]
transform = %s
mesh = SubResource("Mesh_floor")

[node name="Ceiling" type="MeshInstance3D" parent="Level"]
transform = %s
layers = 8
mesh = SubResource("Mesh_ceiling")
""" % (w, d, w + 2, d + 2, t(cx, 0, cz), t(cx, H + 0.1, cz))]

for name, (x, z), size, solid, c in wall_nodes:
    o.append(f"""[node name="{name}" type="StaticBody3D" parent="Level"]
transform = {t(round(x, 3), size[1] / 2, round(z, 3))}
script = ExtResource("2_wall")
size = {v3([round(v, 3) for v in size])}
solid_from = {solid}
color = {col(c)}
""")
o.append(f"""[node name="Rubble" type="StaticBody3D" parent="Level"]
transform = {t(14.75, 1.3, -10.875)}
script = ExtResource("2_wall")
size = Vector3(1.5, 2.6, 1.75)
solid_from = 3
color = Color(0.3, 0.26, 0.22, 1)
people_only = true
""")
o.append('[node name="Lights" type="Node3D" parent="."]\n')
for n, ((x, y, z), r) in enumerate(lights):
    o.append(f"""[node name="Brazier{n}" type="OmniLight3D" parent="Lights"]
transform = {t(x, y, z)}
light_color = Color(1, 0.62, 0.32, 1)
light_energy = 0.9
omni_range = {r}
""")
o.append(f"""[node name="YourRoomGlow" type="OmniLight3D" parent="Lights"]
transform = {t(20.5, 2.4, -10)}
light_color = Color(0.6, 0.9, 1, 1)
light_energy = 0.6
omni_range = 6.0
""")
o.append('[node name="Stations" type="Node3D" parent="."]\n')
for name, (x, z), kind, title, need, size, c, extra in stations:
    ex = dict(extra)
    y = ex.pop("y", 0)
    lines = "".join(f"{k} = {v}\n" for k, v in ex.items())
    o.append(f"""[node name="{name}" type="StaticBody3D" parent="Stations"]
transform = {t(x, y + size[1] / 2, z)}
script = ExtResource("3_station")
kind = {kind}
title_text = "{title}"
need = "{need}"
size = {v3(size)}
color = {col(c)}
{lines}""")
o.append('[node name="Markers" type="Node3D" parent="."]\n')
o.append(f'[node name="Entrance" type="Marker3D" parent="Markers"]\ntransform = {t(0, 0, 11.4)}\n')
o.append(f'[node name="Camp" type="Marker3D" parent="Markers"]\ntransform = {t(6.5, 0, 6.6)}\n')
o.append(f'[node name="RoomCenter" type="Marker3D" parent="Markers"]\ntransform = {t(20.5, 0, -10)}\n')
for n, (x, z) in enumerate(dig_sites):
    o.append(f'[node name="Site{n}" type="Marker3D" parent="Markers" groups=["dig_site"]]\ntransform = {t(x, 0, z)}\n')
o.append('[node name="Visitors" type="Node3D" parent="."]\n')
for name, (x, z), kind, title, c in visitors:
    o.append(f"""[node name="{name}" type="CharacterBody3D" parent="Visitors"]
transform = {t(x, 0, z)}
script = ExtResource("4_visitor")
kind = {kind}
title_text = "{title}"
color = {col(c)}
""")
o.append(f"""[node name="Player" parent="." instance=ExtResource("5_player")]
transform = {t(20, 0, -9.6, rot_y=True)}

[node name="HUD" type="CanvasLayer" parent="."]
process_mode = 3
script = ExtResource("6_hud")
""")
# carved floor for the 2D map (scripts/map_view.gd): rooms by name + door gaps, as Rect2(x, z, w, d)
r2 = lambda a, b, c, d: f"Rect2({a:g}, {b:g}, {c - a:g}, {d - b:g})"
meta = ('metadata/rooms = {' + ", ".join(f'"{n}": {r2(*r)}' for n, r in rooms.items()) + '}\n'
        + 'metadata/doors = [' + ", ".join(r2(*d) for d in doors) + ']\n')
o[0] = o[0].replace('script = ExtResource("1_game")\n', 'script = ExtResource("1_game")\n' + meta, 1)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(o))
print(len(walls), "wall segments")
