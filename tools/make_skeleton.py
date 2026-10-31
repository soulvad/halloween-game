"""Builds art/models/Skeleton.glb: fgc_skeleton.blend (Gord Goodwin, CC0, opengameart.org/content/skeleton-with-rig)
plus a dance keyed here on the rig's controllers. One loop = LOOP_FRAMES, the 16 notes of egg_audio.gd's tune.

blender -b --disable-autoexec fgc_skeleton.blend --python tools/make_skeleton.py -- art/models/Skeleton.glb [preview_dir]
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

FPS = 30
LOOP_FRAMES = 96  # 16 notes * 0.2 s * 30 fps
STEP = 12  # frames per dance step (2 notes)
HEIGHT = 1.75  # metres
args = sys.argv[sys.argv.index("--") + 1:]
out = os.path.abspath(args[0])
preview_dir = os.path.abspath(args[1]) if len(args) > 1 else None

scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start = 0
scene.frame_end = LOOP_FRAMES
rig = bpy.data.objects["Manny_Armature"]
rig.data.pose_position = "POSE"
meshes = [o for o in bpy.data.objects if o.type == "MESH"]


def move(name, offset=(0, 0, 0), rot=(0, 0, 0)):
    """Pose a bone: offset and rotation about its head, in armature axes (+x its left, -y front, +z up)."""
    pb = rig.pose.bones[name]
    rest = pb.bone.matrix_local
    head = rest.to_translation()
    m = Matrix.Translation(Vector(offset)) @ Matrix.Translation(head) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Translation(-head)
    pb.rotation_mode = "QUATERNION"
    pb.matrix_basis = rest.inverted() @ m @ rest
    pb.keyframe_insert("location")
    pb.keyframe_insert("rotation_quaternion")
    pb.keyframe_insert("scale")


def pose(f):
    step = math.tau * f / STEP  # one bounce per step
    sway = step / 2  # left-right over two steps
    side = math.sin(sway)
    bounce = math.cos(step)
    # hips drop on the beat and swing to the standing leg
    move("CONTROL_HIPS", (side * 1.6, 0, -1.4 + bounce * 1.1), (0, side * 0.12, side * 0.3))
    move("CONTROL_CHEST", (0, 0, 0), (0.08 + bounce * 0.05, -side * 0.2, -side * 0.45))
    move("HEAD", (0, 0, 0), (math.sin(step) * 0.22, side * 0.2, -side * 0.5))
    move("JAW", (0, 0, 0), ((math.sin(step * 2) * 0.5 + 0.5) * 0.45, 0, 0))
    for s, name in ((1, "L"), (-1, "R")):
        lift = max(0.0, side * s)  # the leg away from the hips kicks up
        move("CONTROL_FOOT." + name, (s * 0.9 + s * lift * 1.5, -lift * 1.5, lift ** 2 * 3.5), (-lift * 0.5, 0, 0))
        move("MCH_kneeTar." + name, (s * 2.0, 0, 0))
        up = 0.5 + 0.5 * side * s  # hand up on the side of the kick
        wave = math.sin(step + (s > 0) * math.pi)
        move("MCH_armIKtar." + name, (s * (1.0 + up * 2.5 + wave * 1.6), -1.5 - up * 2.5, up * 17.5 + bounce * 0.5))


for f in range(LOOP_FRAMES + 1):
    scene.frame_set(f)
    pose(f)
rig.animation_data.action.name = "dance"
scene.frame_set(0)
bpy.context.view_layer.update()

# feet on the floor, real size, faces -Z in Godot like the other models
deps = bpy.context.evaluated_depsgraph_get()
low, high = math.inf, -math.inf
scene.frame_set(0)
rig.data.pose_position = "REST"
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
for o in meshes:
    ev = o.evaluated_get(deps)
    zs = [(ev.matrix_world @ Vector(c)).z for c in ev.bound_box]
    low, high = min(low, *zs), max(high, *zs)
rig.data.pose_position = "POSE"
print("rest height", low, high)
k = HEIGHT / (high - low)
for o in meshes:
    o.parent = rig  # rig is still at the origin, so they keep their place relative to it
rig.rotation_euler = (0, 0, math.pi)
rig.scale = (k, k, k)
rig.location = (0, 0, -low * k)

mat = bpy.data.materials["Material"]
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf is None:
    mat.node_tree.nodes.clear()
    bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    output = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(bsdf.outputs[0], output.inputs[0])
bsdf.inputs["Base Color"].default_value = (0.78, 0.72, 0.55, 1)
bsdf.inputs["Roughness"].default_value = 0.65

for o in bpy.data.objects:
    for m in o.modifiers if o.type == "MESH" else []:
        if m.type == "SUBSURF":
            m.show_viewport = False
            m.show_render = False
    o.select_set(o.type in ("MESH", "ARMATURE"))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
    export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_step=1, export_nla_strips=False, export_yup=True,
    export_morph=False, export_cameras=False, export_lights=False)
print("wrote", out, os.path.getsize(out))

if preview_dir:
    os.makedirs(preview_dir, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 360, 480
    cam = bpy.data.cameras.new("c")
    cam_ob = bpy.data.objects.new("c", cam)
    scene.collection.objects.link(cam_ob)
    cam_ob.location = (0, -5.2, 1.0)  # the model faces -Y after the turn? show it from both by the frame's pose
    cam_ob.rotation_euler = (math.pi / 2, 0, 0)
    cam.lens = 50
    scene.camera = cam_ob
    for f in range(0, 25, 3):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(preview_dir, "f%03d.png" % f)
        bpy.ops.render.render(write_still=True)
