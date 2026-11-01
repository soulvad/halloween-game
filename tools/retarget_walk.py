"""Copies a clip (the old CC0 models' `walk`) from one rigged GLB onto another rig and writes the target with it.
Torso bones (hips, spine, chest, neck, head) take the source's rotation relative to its rest pose; limbs are swung to
point the way the source's limbs point (the rigs rest differently: T-pose vs A-pose). Hips bob scaled by leg length, then
the hips are set so the lower foot stands at its rest height.

blender -b -P tools/retarget_walk.py -- <target.glb> <source.glb> <out.glb> [clip=walk] [legs=1.0] [arms=1.0]
The v4 people's skinning folds at the old walk's full swing (re-weighting them by auto weights was worse): damp it.
`legs` < 1 narrows the stride (the priest's robe is skinned to the thighs and flies apart at full swing), `arms` < 1 the arm
swing (Olena's puffed sleeves fold into the chest at full swing).
Used for: art/models/src/woman.glb (Olena, old Olena walk, legs 0.75 arms 0.5) and young_man.glb (Taras, old Taras walk, legs 0.85 arms 0.6) from art/3d-model/fixed/,
art/models/Priest.glb (old Taras walk, legs 0.6) from tools/rig_character.py
(old models: `git show ce8f7d4:art/models/<Name>.glb`).
"""
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
TARGET, SOURCE, OUT = [os.path.abspath(a) for a in args[:3]]
CLIP = args[3] if len(args) > 3 else "walk"
LEGS = float(args[4]) if len(args) > 4 else 1.0
ARMS = float(args[5]) if len(args) > 5 else 1.0
TORSO = ("hips", "spine", "chest", "neck", "head")
# target-ish name -> source bone (old Quaternius-style rig)
# no shoulders: the old rig's clavicles point up, ours sideways; matching them pulls the neck and head along
ALIAS = {"hips": "Hips", "spine": "Abdomen", "chest": "Chest", "neck": "Neck", "head": "Head",
         "upperarm": "UpperArm", "upper_arm": "UpperArm", "forearm": "LowerArm", "hand": "Wrist",
         "thigh": "UpperLeg", "shin": "LowerLeg", "foot": "Foot"}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    return new, next(o for o in new if o.type == "ARMATURE")


src_objs, src = load(SOURCE)
src_actions = set(bpy.data.actions)
tgt_objs, tgt = load(TARGET)
tgt_actions = [a for a in bpy.data.actions if a not in src_actions]
src_action = next(a for a in src_actions if a.name.startswith(CLIP))
src.animation_data_create()
src.animation_data.action = src_action
if getattr(src_action, "slots", None):  # Blender 4.4+: an action plays only through a slot
    src.animation_data.action_slot = src_action.slots[0]
print("actions", [a.name for a in bpy.data.actions], "source clip", src_action.name)


def source_of(name):
    side = name[-2:] if name[-2:] in (".L", ".R") else ""
    base = name[:-2] if side else name
    s = ALIAS.get(base.lower())
    return s + side if s and s + side in src.data.bones else None


def forward(arm):  # toes direction in world: the way the rig faces
    foot = next(b for b in arm.data.bones if b.name.lower().startswith("foot"))
    d = arm.matrix_world.to_3x3() @ (foot.tail_local - foot.head_local)
    return Vector((d.x, d.y, 0)).normalized()


if forward(src).dot(forward(tgt)) < 0:  # face the same way
    src.rotation_mode = "XYZ"
    src.rotation_euler.z += 3.14159265
bpy.context.view_layer.update()


def leg(arm):
    b = next(b for b in arm.data.bones if b.name.lower().startswith(("thigh", "upperleg")))
    return (arm.matrix_world @ b.head_local).z  # world height: the old rigs are rotated and scaled in the file




ratio = leg(tgt) / leg(src)
pairs = [(pb, source_of(pb.name)) for pb in tgt.pose.bones]
pairs = [(pb, s) for pb, s in pairs if s]
depth = lambda pb: len(pb.parent_recursive)
pairs.sort(key=lambda p: depth(p[0]))
print("pairs", [(pb.name, s) for pb, s in pairs], "leg ratio %.2f" % ratio)

feet = [pb for pb in tgt.pose.bones if pb.name.lower().startswith("foot")]
floor = min((tgt.matrix_world @ pb.bone.tail_local).z for pb in feet)
frame_from, frame_to = [int(round(f)) for f in src_action.frame_range]
tgt.animation_data_create()
action = bpy.data.actions.new(CLIP + "_new")
action.use_fake_user = True
tgt.animation_data.action = action
for pb in tgt.pose.bones:
    pb.rotation_mode = "QUATERNION"

for frame in range(frame_from, frame_to + 1):
    scene.frame_set(frame)
    for pb in tgt.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for pb, s in pairs:
        sb = src.pose.bones[s]
        s_pose = src.matrix_world @ sb.matrix
        s_rest = src.matrix_world @ src.data.bones[s].matrix_local
        t_rest = tgt.matrix_world @ tgt.data.bones[pb.name].matrix_local
        now = tgt.matrix_world @ pb.matrix  # with the parents already posed
        base = pb.name.lower().rstrip(".lr").rstrip(".")
        if base in TORSO:
            delta = s_pose.to_quaternion() @ s_rest.to_quaternion().inverted()
            rot = Quaternion().slerp(delta, LEGS) @ t_rest.to_quaternion()  # the narrower stride sways the body less too
        else:
            rest_dir = (t_rest.to_3x3() @ Vector((0, 1, 0))).normalized()
            want = (s_pose.to_3x3() @ Vector((0, 1, 0))).normalized()
            if base in ("thigh", "shin", "foot"):
                want = rest_dir.slerp(want, LEGS)
            else:
                want = rest_dir.slerp(want, ARMS)
            rot = rest_dir.rotation_difference(want) @ t_rest.to_quaternion()
        loc = now.to_translation()
        if pb.parent is None or base == "hips":
            loc = t_rest.to_translation() + (s_pose.to_translation() - s_rest.to_translation()) * ratio
        m = Matrix.Translation(loc) @ rot.to_matrix().to_4x4()
        pb.matrix = tgt.matrix_world.inverted() @ m
        bpy.context.view_layer.update()
    # Stand on the floor: the lower foot at its rest height (the old walk dips the hips for its own IK legs).
    low = min((tgt.matrix_world @ pb.tail).z for pb in feet)
    hips = tgt.pose.bones[pairs[0][0].name]
    m = tgt.matrix_world @ hips.matrix
    m.translation.z += floor - low
    hips.matrix = tgt.matrix_world.inverted() @ m
    bpy.context.view_layer.update()
    for pb in tgt.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame - frame_from)
        pb.keyframe_insert("location", frame=frame - frame_from)
print("clip", CLIP, frame_to - frame_from + 1, "frames")

tgt.animation_data.action = None
for a in list(src_actions) + [a for a in tgt_actions if a.name.startswith(CLIP)]:
    bpy.data.actions.remove(a)  # the source's clips and the target's own old one stay out of the file
action.name = CLIP
for a in bpy.data.actions:  # the importer renamed the target's clips on a clash with the source's (idle.001)
    a.name = a.name.split(".")[0]
for pb in tgt.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
for o in src_objs:
    bpy.data.objects.remove(o)
# A rig turned at object level (rig_character.py turns the priest by pi) loses its mesh binding on re-export: bake it in.
bpy.ops.object.select_all(action="DESELECT")
for o in tgt_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = tgt
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.select_all(action="DESELECT")
for o in tgt_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = tgt
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_cameras=False, export_lights=False, export_image_format="JPEG", export_image_quality=90)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "kB")
