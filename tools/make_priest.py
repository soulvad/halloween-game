"""Builds art/models/Priest.glb: Monk by CDmir (CC0, opengameart.org/content/monk), robe dyed black, with a kamilavka,
a beard and a gold cross added, and a `walk` keyed here on the rig's controllers next to the model's own `idle`.

blender -b --disable-autoexec MONK_1.blend --python tools/make_priest.py -- art/models/Priest.glb
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1:][0])
FPS = 30
LOOP = 36  # frames per two steps
STRIDE = 0.2  # m, how far a foot goes forward and back under the robe
HEIGHT = 1.8  # m, without the hat

scene = bpy.context.scene
scene.render.fps = FPS
rig = bpy.data.objects["Armature"]
for o in list(bpy.data.objects):
    if o.type == "LIGHT":
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]


def dyed(image, name, value, tint=(1.0, 1.0, 1.0)):
    """A smaller copy of the texture, desaturated and darkened: from brown wool to black."""
    out = image.copy()
    out.name = name
    out.scale(512, 512)
    px = list(out.pixels)
    for i in range(0, len(px), 4):
        lum = 0.3 * px[i] + 0.59 * px[i + 1] + 0.11 * px[i + 2]
        for c in range(3):
            px[i + c] = lum * value * tint[c]
    out.pixels = px
    out.update()
    out.pack()
    return out


def shrunk(image, name):
    out = image.copy()
    out.name = name
    out.scale(512, 512)
    out.update()
    out.pack()
    return out


def textured(name, image, rough=0.85):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf = nodes["Principled BSDF"]
    mat.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def solid(name, color, rough=0.8, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return mat


images = bpy.data.images
new_mats = {
    "Monk-Body": textured("Robe", dyed(images["monk-tuc-body"], "robe", 0.28, (0.95, 0.95, 1.05))),
    "Monk-Head": textured("Skin", shrunk(images["monk-tuc-head"], "skin")),
    "Hair": textured("Hair", dyed(images["hair-skin.png"], "hair", 0.75)),
}
for o in meshes:
    for slot in o.material_slots:
        slot.material = new_mats[slot.material.name]


# --- clothes, in rest pose coordinates ---

rig.animation_data_create()
rig.animation_data.action = None
rig.data.pose_position = "REST"
bpy.context.view_layer.update()


def world(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def add_part(name, bone, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.parent = rig
    ob.vertex_groups.new(name=bone).add(list(range(len(verts))), 1.0, "REPLACE")
    ob.modifiers.new("Armature", "ARMATURE").object = rig


def ring(cx, cy, z, r, sides=14):
    return [(cx + r * math.cos(i * math.tau / sides), cy + r * math.sin(i * math.tau / sides), z) for i in range(sides)]


def tube(rings):
    n = len(rings[0])
    verts = [v for r in rings for v in r]
    faces = [(a * n + (i + 1) % n, a * n + i, (a + 1) * n + i, (a + 1) * n + (i + 1) % n) for a in range(len(rings) - 1) for i in range(n)]
    return verts, faces + [tuple(range(n)), tuple(len(verts) - 1 - i for i in range(n))]


head = world(bpy.data.objects["Head"]) + world(bpy.data.objects["Hair"])
top = max(p.z for p in head)
upper = [p for p in head if p.z > top - 0.14]
cx = sum(p.x for p in upper) / len(upper)
cy = (max(p.y for p in upper) + min(p.y for p in upper)) / 2
r = (max(p.x for p in upper) - min(p.x for p in upper)) / 2
face = [p for p in head if top - 0.32 < p.z < top - 0.08]
nose_y = min(p.y for p in face)
print("head top", round(top, 2), "radius", round(r, 3), "centre", round(cx, 3), round(cy, 3), "nose", round(nose_y, 3))

cloth = solid("Kamilavka", (0.008, 0.008, 0.012, 1))
v, f = tube([ring(cx, cy, top + 0.075, r * 1.13), ring(cx, cy, top - 0.055, r * 1.03)])
add_part("Kamilavka", "Head", v, f, cloth)

beard = solid("Beard", (0.28, 0.27, 0.26, 1), 1.0)
jaw, tip = top - 0.215, top - 0.40
y = nose_y + 0.03
w = r * 0.72
back = y + 0.1
v = [(cx - w, y + 0.02, jaw), (cx - w * 0.45, y - 0.012, jaw + 0.025), (cx + w * 0.45, y - 0.012, jaw + 0.025), (cx + w, y + 0.02, jaw),
     (cx + w, back, jaw), (cx - w, back, jaw), (cx - w * 0.55, y - 0.005, tip + 0.08), (cx + w * 0.55, y - 0.005, tip + 0.08), (cx, y + 0.02, tip), (cx, back, tip + 0.1)]
f = [(0, 1, 6), (1, 2, 7, 6), (2, 3, 7), (6, 7, 8), (3, 4, 9, 7), (5, 0, 6, 9), (7, 9, 8), (9, 6, 8), (0, 5, 4, 3, 2, 1)]
add_part("Beard", "Head", v, f, beard)

body = world(bpy.data.objects["Body"])
chest = [p for p in body if 1.33 < p.z < 1.38 and abs(p.x) < 0.05]
front = min(p.y for p in chest) - 0.012
gold = solid("Cross", (1.0, 0.72, 0.22, 1), 0.35, 0.6)
a, b = 0.012, 0.075
v, f = [], []
for x0, x1, z0, z1 in ((-a, a, -b * 1.25, b), (-b * 0.72, b * 0.72, b * 0.2, b * 0.2 + 2 * a)):
    n = len(v)
    v += [(x, front - d, 1.34 + z) for d in (0, 0.012) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
    f += [tuple(n + i for i in q) for q in ((4, 5, 6, 7), (1, 0, 3, 2), (5, 1, 2, 6), (0, 4, 7, 3), (7, 6, 2, 3), (0, 1, 5, 4))]
add_part("Cross", "Spine1", v, f, gold)
rig.data.pose_position = "POSE"


# --- walk ---

stand_pose = {}
stand = bpy.data.actions["Stand"]
rig.animation_data.action = stand
scene.frame_set(0)
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
bpy.context.view_layer.update()
scene.frame_set(0)
for pb in rig.pose.bones:
    stand_pose[pb.name] = pb.matrix_basis.copy()

walk = bpy.data.actions.new("walk")
rig.animation_data.action = walk


def key(name, offset=(0, 0, 0), rot=(0, 0, 0)):
    """On top of the standing pose: offset and rotation about the bone's head in armature axes (+x his left, -y front, +z up)."""
    pb = rig.pose.bones[name]
    rest = pb.bone.matrix_local
    h = rest.to_translation()
    m = Matrix.Translation(Vector(offset)) @ Matrix.Translation(h) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Translation(-h)
    pb.matrix_basis = stand_pose[name] @ (rest.inverted() @ m @ rest)
    pb.keyframe_insert("location")
    pb.keyframe_insert("rotation_quaternion")
    pb.keyframe_insert("scale")


moved = ("IK-Foot_L", "IK-Foot_R", "IK-Hand_L", "IK-Hand_R", "IK-Spine1", "IK-Head", "Root")
for frame in range(LOOP + 1):
    scene.frame_set(frame)
    t = math.tau * frame / LOOP
    swing = math.sin(t)  # + his left foot goes forward
    for name, pb in rig.pose.bones.items():
        if name not in moved:
            pb.matrix_basis = stand_pose[name]
            pb.keyframe_insert("location")
            pb.keyframe_insert("rotation_quaternion")
            pb.keyframe_insert("scale")
    for side, sign in (("L", 1), ("R", -1)):
        phase = t * 1 + (0 if sign > 0 else math.pi)
        forward = math.sin(phase)
        lift = max(0.0, math.cos(phase)) ** 2 * 0.07  # the foot coming forward is off the floor
        key("IK-Foot_%s" % side, (-sign * 0.03, -forward * STRIDE, lift))
        key("IK-Hand_%s" % side, (0, forward * 0.09, abs(forward) * 0.015))  # the opposite arm goes forward
    key("IK-Spine1", (math.sin(t) * 0.012, 0, -abs(math.cos(t)) * 0.012), (0.03, 0, -swing * 0.06))
    key("IK-Head", (0, 0, 0), (0, 0, swing * 0.03))
    key("Root", (0, 0, -abs(math.cos(t)) * 0.015))

idle = bpy.data.actions["Idle.000"]
idle.name = "idle"
for a in list(bpy.data.actions):
    if a.name in ("idle", "walk"):
        a.use_fake_user = True
    else:
        bpy.data.actions.remove(a)
print("clips", [(a.name, tuple(a.frame_range)) for a in bpy.data.actions])
rig.animation_data.action = None
for t in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(t)

# real size, feet on the floor, faces -Z in the game
rig.data.pose_position = "REST"
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
pts = [p for o in meshes for p in world(o)]
low, high = min(p.z for p in pts), max(p.z for p in pts)
k = HEIGHT / (high - low)
rig.rotation_mode = "XYZ"
rig.rotation_euler = (0, 0, math.pi)
rig.scale = (k, k, k)
rig.location = (0, 0, -low * k)
rig.data.pose_position = "POSE"

bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(o.type in ("MESH", "ARMATURE"))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_cameras=False, export_lights=False, export_image_format="JPEG", export_image_quality=85)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "kB")
