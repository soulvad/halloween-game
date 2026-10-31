"""Builds art/models/*.glb from CC0 Poly Pizza models (art/CREDITS.md): people and the rat with `walk`, `idle` clips,
and the static turtle, pizza, bell and mirror, scaled into their boxes. Downloaded files are named as used below.

blender -b --python tools/make_people.py -- art/models <folder with the downloaded .glb files>
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, SRC = [os.path.abspath(a) for a in args[:2]]
DARK = (0.02, 0.02, 0.025, 1)


def bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return Vector(min(p[i] for p in pts) for i in range(3)), Vector(max(p[i] for p in pts) for i in range(3))


def skinned_bounds(meshes):
    """bound_box of skinned glTF meshes is unreliable: measure the evaluated vertices."""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        ev = o.evaluated_get(deps)
        me = ev.to_mesh()
        pts += [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    return Vector(min(p[i] for p in pts) for i in range(3)), Vector(max(p[i] for p in pts) for i in range(3))


def load(source):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, source + ".glb"))
    return [o for o in bpy.data.objects if o.type == "MESH"]


def export(name, animated=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("MESH", "ARMATURE"):
            o.select_set(True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=animated, export_animation_mode="ACTIONS", export_cameras=False, export_lights=False)
    print(name, os.path.getsize(path) // 1024, "kB")


def rigged(name, source, clips, size_axis, size, turn=math.pi, recolor=None):
    """Keep only `clips` {game name: action name part}; size_axis 2 = height, 1 = length, with the feet on the floor."""
    meshes = load(source)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(meshes):  # the importer's display shape for bones is not part of the model
        if not any(m.type == "ARMATURE" for m in o.modifiers):
            print(name, "dropping", o.name)
            meshes.remove(o)
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):
        armature, _, clip = a.name.partition("|")  # "CharacterArmature|Idle_CharacterArmature"
        keep = next((k for k, part in clips.items() if clip == "%s_%s" % (part, armature)), None)
        if keep:
            a.name = keep
            a.use_fake_user = True
        else:
            bpy.data.actions.remove(a)
    print(name, "clips", [a.name for a in bpy.data.actions])
    assert len(bpy.data.actions) == len(clips)
    if rig.animation_data:
        rig.animation_data.action = None
        for t in list(rig.animation_data.nla_tracks):
            rig.animation_data.nla_tracks.remove(t)
    for mat, color in (recolor or {}).items():
        node = bpy.data.materials[mat].node_tree.nodes.get("Principled BSDF")
        node.inputs["Base Color"].default_value = color
    # the root keeps all its children, only its own transform changes
    root = rig
    while root.parent:
        root = root.parent
    rig.data.pose_position = "REST"
    low, high = skinned_bounds(meshes)
    k = size / (high - low)[size_axis]
    root.scale = root.scale * k
    root.rotation_mode = "XYZ"
    root.rotation_euler = (root.rotation_euler.x, root.rotation_euler.y, root.rotation_euler.z + turn)
    low, high = skinned_bounds(meshes)
    root.location += Vector((-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z))
    low, high = skinned_bounds(meshes)
    print(name, "height", round(high.z - low.z, 2), "feet", round(low.z, 3), "length", round(high.y - low.y, 2))
    rig.data.pose_position = "POSE"
    export(name, True)


def static(name, source, box, turn=0.0, stretch=False):
    objs = load(source)
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.data.objects:
        if o.parent is None:
            o.rotation_mode = "XYZ"
            o.rotation_euler.z += turn
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    place(objs, box, stretch)
    export(name)


def place(objs, box, stretch=False):
    low, high = bounds(objs)
    size = high - low
    want = Vector((box[0], box[2], box[1]))
    k = [want[i] / size[i] for i in range(3)]
    if not stretch:
        k = [min(k)] * 3
    for o in objs:
        o.scale = k
        o.location = Vector(o.location[i] * k[i] for i in range(3))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    low, high = bounds(objs)
    for o in objs:
        o.location -= Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)


WALK = {"walk": "Walk", "idle": "Idle"}
rigged("Olena", "AdvW", WALK, 2, 1.68)
rigged("Taras", "AdvM", WALK, 2, 1.78, turn=0.0)  # this one already looks the other way
# the same adventurer in black: gear and clothes dark, beard and gold kept
rigged("Priest", "AdvM", WALK, 2, 1.78, turn=0.0, recolor={"Green": DARK, "Brown": DARK, "Brown2": DARK})
rigged("Rat", "Rat", {"run": "Rat_Run", "idle": "Rat_Idle"}, 1, 0.42)

static("Pizza", "PizzaQ", (0.84, 0.1, 0.84))
static("Bell", "Bell", (0.3, 0.4, 0.3))
static("Mirror", "MirrorI", (0.1, 1.4, 0.9), math.pi / 2, True)

# the turtle only comes in a T-pose and has no rig: bend its arms down by hand
objs = load("Turtle")
bpy.ops.object.select_all(action="SELECT")
for o in bpy.data.objects:
    if o.parent is None:
        o.rotation_mode = "XYZ"
        o.rotation_euler.z += math.pi / 2
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
objs[0].shape_key_clear()  # facial shape keys would override the edited vertices
mesh = objs[0].data
span = max(abs(v.co.x) for v in mesh.vertices)
shoulder = span * 0.3
arm = [v for v in mesh.vertices if abs(v.co.x) > shoulder]
height = sum(v.co.z for v in arm) / len(arm)
for v in arm:
    side = 1 if v.co.x > 0 else -1
    a = math.radians(72) * min((abs(v.co.x) - shoulder) / (span * 0.1), 1.0)
    dx, dz = abs(v.co.x) - shoulder, v.co.z - height
    v.co.x = side * (shoulder + dx * math.cos(a) + dz * math.sin(a))
    v.co.z = height - dx * math.sin(a) + dz * math.cos(a)
mesh.update()
objs[0].data.update()
place(objs, (0.75, 1.3, 0.5))
export("Turtle")
