"""Builds art/models/*.glb from CC0 packs: scales each model into its object's box (docs/assets.md), origin bottom centre.

Sources: KayKit Dungeon Remastered (Kay Lousberg, CC0, github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0),
Simple Cat (opengameart.org/content/simple-cat, CC0), fgc_skeleton.blend (see make_skeleton.py).

blender -b --python tools/make_props.py -- art/models <KayKit Assets/gltf dir> <cat.obj> <fgc_skeleton.blend>
"""
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, KAYKIT, CAT, BONES = [os.path.abspath(a) for a in args[:4]]

# name: (source, box Ш × В × Г in metres, turn about the vertical in degrees, stretch to the box instead of fitting)
PROPS = {
    "CrateR1L": ("crates_stacked", (1.2, 0.9, 1.0), 0, False),
    "CrateR3R": ("box_large", (1.4, 0.9, 1.0), 0, False),
    "TableR1R": ("table_long", (2.2, 0.8, 1.0), 90, True),
    "TableR4R": ("table_long", (2.0, 0.8, 1.2), 90, True),
    "BunksR2L": ("bed_frame", (1.0, 0.7, 2.4), 0, True),
    "BunkYourRoom": ("bed_floor", (1.4, 0.5, 0.9), 90, True),
    "BarrelsR2R": ("barrel_small_stack", (1.2, 1.0, 1.2), 0, False),
    "PlankR3L": ("table_long_broken", (1.0, 0.6, 1.6), 0, True),
    "ShelfR4L": ("shelves", (1.0, 1.6, 0.8), 0, True),
    "StonesRT": ("rubble_large", (1.2, 0.6, 1.0), 0, False),
    "Chest": ("chest", (1.0, 0.6, 0.6), 0, True),
    "Jug": ("bottle_A_brown", (0.4, 0.5, 0.4), 0, False),
    "Pedestal": ("pillar_decorated", (0.7, 0.8, 0.7), 0, True),
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return Vector(min(p[i] for p in pts) for i in range(3)), Vector(max(p[i] for p in pts) for i in range(3))


def roots(objs):
    return [o for o in objs if o.parent is None]


def fit(box, turn=0.0, stretch=False):
    """Everything in the scene into the box: x = Ш, y = Г (front -Y turns to -Z in glTF... the box is the same), z = В."""
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="SELECT")
    for o in roots(bpy.data.objects):
        o.rotation_mode = "XYZ"
        o.rotation_euler.z += math.radians(turn)
    # bake the turn and any parenting, so that non-uniform scale stays along the box's axes
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    low, high = bounds(objs)
    size = high - low
    want = Vector((box[0], box[2], box[1]))
    k = [want[i] / size[i] for i in range(3)]
    if not stretch:
        k = [min(k)] * 3
    for o in objs:
        o.scale = Vector(k)
        o.location = Vector(o.location[i] * k[i] for i in range(3))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    low, high = bounds(objs)
    centre = (low + high) / 2
    for o in objs:
        o.location -= Vector((centre.x, centre.y, low.z))
    for o in bpy.data.objects:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    print("  size", tuple(round(v, 2) for v in bounds(objs)[1] - bounds(objs)[0]))


def export(name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False, export_cameras=False, export_lights=False)
    print(name, os.path.getsize(path))


def kaykit(source):
    for ext in (".glb", ".gltf.glb", ".gltf"):
        path = os.path.join(KAYKIT, source + ext)
        if os.path.exists(path):
            bpy.ops.import_scene.gltf(filepath=path)
            return
    raise FileNotFoundError(source)


for name, (source, box, turn, stretch) in PROPS.items():
    clear()
    kaykit(source)
    fit(box, turn, stretch)
    export(name)

# the door only comes as OBJ, next to the gltf folder
clear()
bpy.ops.wm.obj_import(filepath=os.path.join(os.path.dirname(KAYKIT), "obj", "wall_doorway_door.obj"))
fit((1.75, 2.4, 0.15), 0, True)
export("Door")

# upright grate: a floor grate stood on its edge
clear()
kaykit("floor_tile_grate")
for o in roots(bpy.data.objects):
    o.rotation_mode = "XYZ"
    o.rotation_euler = Euler((0, math.radians(90), 0))
fit((0.2, 1.4, 1.2), 0, True)
export("Grate")

# candle on a stool: the stations hover 0.8 m up, the stool reaches the floor below the origin
clear()
kaykit("candle")
fit((0.12, 0.3, 0.12))
candle = list(bpy.data.objects)
kaykit("stool")
stool = [o for o in bpy.data.objects if o not in candle]
for o in stool:
    o.rotation_mode = "XYZ"
low, high = bounds([o for o in stool if o.type == "MESH"])
k = 0.8 / (high - low).z
for o in stool:
    o.scale = (0.8 / 0.75 * 0.45, 0.8 / 0.75 * 0.45, k)
    o.location = (0, 0, -0.8)
export("Candle")

# the cat, faces -Y in Blender so -Z in the game
clear()
bpy.ops.wm.obj_import(filepath=CAT)
fit((0.32, 0.55, 0.6))
export("Cat")


def bones_scene(parts):
    """Real bones of the skeleton, posed flat: parts = (mesh, x, y, z, rx, ry, rz); length scale as the dancer's."""
    clear()
    bpy.ops.wm.open_mainfile(filepath=BONES, load_ui=False)
    rig = bpy.data.objects["Manny_Armature"]
    rig.data.pose_position = "REST"
    deps = bpy.context.evaluated_depsgraph_get()
    keep = []
    for name, x, y, z, rx, ry, rz in parts:
        src = bpy.data.objects[name]
        for m in src.modifiers:
            if m.type == "SUBSURF":
                m.show_viewport = False
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(src.evaluated_get(deps))
        ob = bpy.data.objects.new(name + "_rest", mesh)
        bpy.context.scene.collection.objects.link(ob)
        ob.matrix_world = src.matrix_world
        keep.append((ob, x, y, z, rx, ry, rz))
    for o in list(bpy.data.objects):
        if not o.name.endswith("_rest"):
            bpy.data.objects.remove(o)
    k = 1.75 / 37.5
    mat = bpy.data.materials["Material"]
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF") or mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    out = next((n for n in mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None) or mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (0.78, 0.72, 0.55, 1)
    bsdf.inputs["Roughness"].default_value = 0.65
    for ob, x, y, z, rx, ry, rz in keep:
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        low, high = bounds([ob])
        centre = (low + high) / 2
        for v in ob.data.vertices:
            v.co -= centre
        ob.data.update()
        ob.scale = (k, k, k)
        ob.rotation_euler = (rx, ry, rz)
        ob.location = (x, y, z)
        ob.select_set(False)


random.seed(17)
# a heap: skull on top of the ribs, the long bones thrown around them
bones_scene([
    ("BONES_RIBCAGE", 0, 0, 0.1, 1.45, 0, 0.4),
    ("BONES_PELVIS", -0.22, 0.18, 0.08, 1.2, 0.3, 2.1),
    ("BONES_HEAD", 0.12, -0.1, 0.25, 0.2, 0.2, 0.5),
    ("BONES_LEG.L", 0.1, 0.2, 0.05, 1.55, 0.1, 1.2),
    ("BONES_LEG.R", -0.05, -0.2, 0.08, 1.5, -0.1, 2.0),
    ("BONES_ARM.L", 0.25, 0.05, 0.1, 1.5, 0, 0.3),
    ("BONES_ARM.R", -0.28, -0.1, 0.06, 1.55, 0, 2.6),
])
fit((0.9, 0.25, 0.7), 0, False)
export("Bones")

bones_scene([
    ("BONES_HEAD", 0.08, 0, 0.14, 0.15, 0, 0.5),
    ("BONES_ARM.L", -0.05, 0.05, 0.05, 1.5, 0, 1.3),
    ("BONES_PELVIS", -0.12, -0.05, 0.05, 1.3, 0.2, 2.0),
])
fit((0.5, 0.4, 0.4), 0, False)
export("Niche")
