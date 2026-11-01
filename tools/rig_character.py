"""Rigs and animates a static character model (ComfyUI / Hunyuan GLB) for the game: scales it to `height`, turns it to
face -Y, optionally projects a clean front picture onto the face, builds a simple armature with auto weights and bakes
procedural clips. `ghost` (Тиміш): idle, fly, reach, look, release, floating. `walker` (people): idle, walk.
Textures are capped at 2048 for the web build. By Ostap (make_tymish.py), generalised.

blender -b -P tools/rig_character.py -- <source.glb> <out.glb> <name> <height> <ghost|walker> [front.png] [save.blend] [flip]
`flip` turns the model around when the toes-vs-ankles guess of its facing is wrong (Taras).
In the game: Tymish 1.52 ghost, Priest 1.78 walker (sources in art/comfy-models/).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
FLIP = "flip" in args
args = [a for a in args if a != "flip"]
SOURCE, OUT = [os.path.abspath(a) for a in args[:2]]
NAME, HEIGHT, STYLE = args[2], float(args[3]), args[4]
FRONT = os.path.abspath(args[5]) if len(args) > 5 and args[5] else None
SAVE_BLEND = os.path.abspath(args[6]) if len(args) > 6 else None
FPS = 30
TEXTURE = 2048
NORMAL_TEXTURE = 2048
FACES = 40000
FLOAT = 0.12 if STYLE == "ghost" else 0.0
HEAD_FROM = 0.78
HEAD_FADE = 0.03
FACING_FROM = 0.25
FACING_FULL = 0.65
FIT_STEP = 4

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SOURCE)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
select_only(meshes)
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = NAME
body.data.name = NAME
body.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def points():
    return [v.co.copy() for v in body.data.vertices]


def move(matrix):
    body.data.transform(matrix)
    body.data.update()


pts = points()
low = min(p.z for p in pts)
high = max(p.z for p in pts)
k = HEIGHT / (high - low)
cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
move(Matrix.Scale(k, 4) @ Matrix.Translation((-cx, -cy, -low)))
H = HEIGHT


def mean(vs):
    n = max(len(vs), 1)
    return Vector((sum(v.x for v in vs) / n, sum(v.y for v in vs) / n, sum(v.z for v in vs) / n))


def slab(z0, z1, side=0):
    return [p for p in points() if z0 * H <= p.z < z1 * H and (side == 0 or p.x * side > 0)]


def facing():
    toes = mean(slab(0.0, 0.025))
    ankles = mean(slab(0.05, 0.08))
    return -1 if toes.y < ankles.y else 1


if (facing() > 0) != FLIP:
    move(Matrix.Rotation(math.pi, 4, "Z"))
print("facing fixed, forward is -Y")

if FACES and len(body.data.polygons) > FACES:
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = FACES / len(body.data.polygons)
    select_only([body])
    bpy.ops.object.modifier_apply(modifier=dec.name)
print("faces", len(body.data.polygons))


def texture_of(mat, socket):
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    stack = [bsdf.inputs[socket]]
    while stack:
        s = stack.pop()
        for link in s.links:
            n = link.from_node
            if n.type == "TEX_IMAGE":
                return n.image
            stack += list(n.inputs)
    return None


def pixels(image):
    w, h = image.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(buf)
    return buf.reshape(h, w, 4)[::-1]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def silhouette(width, height):
    cam_data = bpy.data.cameras.new("Fit")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = H * 1.1
    cam = bpy.data.objects.new("Fit", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -10, H / 2)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    path = os.path.join(bpy.app.tempdir, "tymish_fit.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    shot = bpy.data.images.load(path)
    alpha = pixels(shot)[:, :, 3]
    bpy.data.images.remove(shot)
    bpy.data.objects.remove(cam)
    return alpha, cam_data.ortho_scale / height


def fit(model, front):
    target = model > 0.5
    source = front > 0.5
    hi, wi = source.shape
    rows_m = np.where(target.any(1))[0]
    rows_i = np.where(source.any(1))[0]
    s = (rows_m[-1] - rows_m[0]) / (rows_i[-1] - rows_i[0])
    tx = np.argwhere(target)[:, 1].mean() - s * np.argwhere(source)[:, 1].mean()
    ty = rows_m[0] - s * rows_i[0]
    head_rows = int((rows_m[-1] - rows_m[0]) * 0.25)
    vv, uu = np.mgrid[max(rows_m[0] - 10, 0):rows_m[0] + head_rows:FIT_STEP, 0:target.shape[1]:FIT_STEP]
    want = target[vv, uu]

    def score(s, tx, ty):
        iy = np.round((vv - ty) / s).astype(int)
        ix = np.round((uu - tx) / s).astype(int)
        ok = (iy >= 0) & (iy < hi) & (ix >= 0) & (ix < wi)
        got = np.zeros_like(want)
        got[ok] = source[iy[ok], ix[ok]]
        return (got & want).sum() / max((got | want).sum(), 1)

    best = (score(s, tx, ty), s, tx, ty)
    for span_s, span_t in ((0.08, 30.0), (0.025, 10.0), (0.008, 3.0)):
        _, s0, tx0, ty0 = best
        for s1 in np.linspace(s0 - span_s, s0 + span_s, 7):
            for tx1 in np.linspace(tx0 - span_t, tx0 + span_t, 7):
                for ty1 in np.linspace(ty0 - span_t, ty0 + span_t, 7):
                    best = max(best, (score(s1, tx1, ty1), s1, tx1, ty1))
    print("face fit IoU %.3f scale %.4f offset %.1f %.1f" % best)
    return best[1:]


def project_front(base):
    front = bpy.data.images.load(FRONT)
    front.alpha_mode = "STRAIGHT"
    wi, hi = front.size
    px = pixels(front)
    if px[0, 0, 3] > 0.5 and px[-1, -1, 3] > 0.5:
        px[:, :, 3] = 1.0 - px[:, :, 3]
        front.pixels.foreach_set(px[::-1].ravel())
        front.update()
    model, pixel_size = silhouette(wi, hi)
    s, tx, ty = fit(model, px[:, :, 3])

    mesh = body.data
    count = len(mesh.vertices)
    co = np.empty(count * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(count, 3)
    nor = np.empty(count * 3, dtype=np.float32)
    mesh.vertices.foreach_get("normal", nor)
    nor = nor.reshape(count, 3)
    u = wi / 2 + co[:, 0] / pixel_size
    v = hi / 2 - (co[:, 2] - H / 2) / pixel_size
    ix = (u - tx) / s
    iy = (v - ty) / s
    vert_uv = np.stack([ix / wi, 1.0 - iy / hi], axis=1)
    weight = smoothstep(FACING_FROM, FACING_FULL, -nor[:, 1]) * smoothstep(HEAD_FROM * H, (HEAD_FROM + HEAD_FADE) * H, co[:, 2])

    main_uv = mesh.uv_layers[0]
    front_uv = mesh.uv_layers.new(name="Front")
    loop_vert = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vert)
    front_uv.data.foreach_set("uv", vert_uv[loop_vert].ravel())
    mask = mesh.attributes.new("FrontMask", "FLOAT", "POINT")
    mask.data.foreach_set("value", weight.astype(np.float32))
    mesh.uv_layers.active = main_uv
    main_uv.active_render = True

    mat = bpy.data.materials.new("Bake")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    def textured(image, uv_name, clip=False):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        if clip:
            tex.extension = "CLIP"
        uv = nodes.new("ShaderNodeUVMap")
        uv.uv_map = uv_name
        links.new(uv.outputs["UV"], tex.inputs["Vector"])
        return tex

    old_tex = textured(base, main_uv.name)
    front_tex = textured(front, "Front", clip=True)
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "FrontMask"
    fac = nodes.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    links.new(attr.outputs["Fac"], fac.inputs[0])
    links.new(front_tex.outputs["Alpha"], fac.inputs[1])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    port = {s.identifier: s for s in mix.inputs}
    links.new(fac.outputs["Value"], port["Factor_Float"])
    links.new(old_tex.outputs["Color"], port["A_Color"])
    links.new(front_tex.outputs["Color"], port["B_Color"])
    glow = nodes.new("ShaderNodeEmission")
    links.new(next(o for o in mix.outputs if o.identifier == "Result_Color"), glow.inputs["Color"])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(glow.outputs["Emission"], out.inputs["Surface"])
    baked = bpy.data.images.new(NAME + "Base", TEXTURE, TEXTURE)
    target = nodes.new("ShaderNodeTexImage")
    target.image = baked
    nodes.active = target

    kept = list(mesh.materials)
    mesh.materials.clear()
    mesh.materials.append(mat)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.bake.margin = 16
    select_only([body])
    bpy.ops.object.bake(type="EMIT")
    baked.pack()
    mesh.materials.clear()
    for m in kept:
        mesh.materials.append(m)
    mesh.uv_layers.remove(mesh.uv_layers["Front"])
    mesh.attributes.remove(mesh.attributes["FrontMask"])
    bpy.data.materials.remove(mat)
    print("face projected, %d of %d vertices from the front image" % (int((weight > 0.5).sum()), count))
    return baked


old = body.data.materials[0]
normal = texture_of(old, "Normal")
base = project_front(texture_of(old, "Base Color")) if FRONT else texture_of(old, "Base Color")


def arm_line(side):
    pts = points()
    tip_x = max(p.x * side for p in pts)
    tip = mean([p for p in pts if p.x * side > tip_x - 0.015 * H])
    start = 0.17 * H
    centres = []
    steps = 8
    for i in range(steps):
        a = start + (tip_x - start) * i / steps
        b = start + (tip_x - start) * (i + 1) / steps
        band = [p for p in pts if a <= p.x * side < b and p.z > 0.45 * H]
        if band:
            centres.append(mean(band))
    return tip, centres


def leg_point(z, side):
    return mean(slab(z - 0.015, z + 0.015, side))


def toe(side):
    foot = [p for p in slab(0.0, 0.03, side)]
    front = min(p.y for p in foot)
    return mean([p for p in foot if p.y < front + 0.02 * H])


joints = {}
spine_y = mean(slab(0.50, 0.56)).y
for name, z in (("hips", 0.50), ("spine", 0.58), ("chest", 0.68), ("neck", 0.80), ("head", 0.855)):
    c = mean(slab(z - 0.01, z + 0.01))
    joints[name] = Vector((0, c.y if name in ("neck", "head") else spine_y, z * H))
joints["top"] = Vector((0, joints["head"].y, H))
joints["neck"].y = (joints["chest"].y + joints["head"].y) / 2

for tag, side in (("L", 1), ("R", -1)):
    tip, centres = arm_line(side)
    first, last = centres[0], centres[-1]
    direction = (last - first).normalized()
    shoulder = first - direction * ((first.x * side - 0.115 * H) / max(abs(direction.x), 1e-3))
    hand_len = 0.105 * H
    wrist = tip - (tip - shoulder).normalized() * hand_len
    elbow = shoulder.lerp(wrist, 0.5)
    near = [c for c in centres if abs((c - elbow).length) < 0.06 * H]
    if near:
        elbow = mean(near)
    joints["clavicle." + tag] = Vector((0.03 * H * side, joints["chest"].y, 0.79 * H))
    joints["shoulder." + tag] = shoulder
    joints["elbow." + tag] = elbow
    joints["wrist." + tag] = wrist
    joints["tip." + tag] = tip
    knee = leg_point(0.28, side)
    ankle = leg_point(0.06, side)
    thigh = leg_point(0.42, side)
    hip = Vector((thigh.x * 0.85, spine_y, 0.49 * H))
    joints["hip." + tag] = hip
    joints["knee." + tag] = Vector((knee.x, knee.y, 0.28 * H))
    joints["ankle." + tag] = Vector((ankle.x, ankle.y + 0.01 * H, 0.055 * H))
    t = toe(side)
    joints["toe." + tag] = Vector((t.x, t.y, 0.015 * H))

for name, p in sorted(joints.items()):
    print("%-12s %6.3f %6.3f %6.3f" % (name, p.x, p.y, p.z))

arm_data = bpy.data.armatures.new(NAME + "Rig")
rig = bpy.data.objects.new(NAME + "Rig", arm_data)
scene.collection.objects.link(rig)
select_only([rig])
bpy.ops.object.mode_set(mode="EDIT")
bones = {}


def bone(name, head, tail, parent=None, connect=False, deform=True):
    b = arm_data.edit_bones.new(name)
    b.head = head
    b.tail = tail
    b.use_deform = deform
    if parent:
        b.parent = bones[parent]
        b.use_connect = connect
    bones[name] = b
    return b


j = joints
bone("Root", Vector((0, 0, 0)), Vector((0, 0.25, 0)), deform=False)
bone("Hips", j["hips"], j["spine"], "Root")
bone("Spine", j["spine"], j["chest"], "Hips", True)
bone("Chest", j["chest"], j["neck"], "Spine", True)
bone("Neck", j["neck"], j["head"], "Chest", True)
bone("Head", j["head"], j["top"], "Neck", True)
for tag in ("L", "R"):
    bone("Shoulder." + tag, j["clavicle." + tag], j["shoulder." + tag], "Chest")
    bone("UpperArm." + tag, j["shoulder." + tag], j["elbow." + tag], "Shoulder." + tag, True)
    bone("ForeArm." + tag, j["elbow." + tag], j["wrist." + tag], "UpperArm." + tag, True)
    bone("Hand." + tag, j["wrist." + tag], j["tip." + tag], "ForeArm." + tag, True)
    bone("Thigh." + tag, j["hip." + tag], j["knee." + tag], "Hips")
    bone("Shin." + tag, j["knee." + tag], j["ankle." + tag], "Thigh." + tag, True)
    bone("Foot." + tag, j["ankle." + tag], j["toe." + tag], "Shin." + tag, True)
for b in arm_data.edit_bones:
    b.roll = 0
bpy.ops.armature.calculate_roll(type="GLOBAL_POS_Y")
bpy.ops.object.mode_set(mode="OBJECT")

proxy = body.copy()
proxy.data = body.data.copy()
proxy.name = "Proxy"
scene.collection.objects.link(proxy)
for m in list(proxy.modifiers):
    proxy.modifiers.remove(m)
proxy.data.remesh_voxel_size = 0.008
select_only([proxy])
bpy.ops.object.voxel_remesh()
select_only([proxy, rig], rig)
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
weighted = sum(1 for v in proxy.data.vertices if v.groups)
print("proxy weighted", weighted, "of", len(proxy.data.vertices))

for g in proxy.vertex_groups:
    body.vertex_groups.new(name=g.name)
transfer = body.modifiers.new("Weights", "DATA_TRANSFER")
transfer.object = proxy
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "POLYINTERP_NEAREST"
transfer.layers_vgroup_select_src = "ALL"
transfer.layers_vgroup_select_dst = "NAME"
select_only([body])
bpy.ops.object.modifier_apply(modifier=transfer.name)
bpy.data.objects.remove(proxy)

select_only([body])
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
empty = sum(1 for v in body.data.vertices if not v.groups)
print("body unweighted", empty)
body.parent = rig
body.modifiers.new("Armature", "ARMATURE").object = rig


skin = bpy.data.materials.new(NAME)
skin.use_nodes = True
nodes = skin.node_tree.nodes
links = skin.node_tree.links
bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.85
for image, size in ((base, TEXTURE), (normal, NORMAL_TEXTURE)):
    if image and image.size[0] > size:
        image.scale(size, size)
        image.pack()
tex = nodes.new("ShaderNodeTexImage")
tex.image = base
links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
if normal:
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = normal
    ntex.image.colorspace_settings.name = "Non-Color"
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
body.data.materials.clear()
body.data.materials.append(skin)
for p in body.data.polygons:
    p.use_smooth = True

rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"


def pose(name, rot=(0, 0, 0), offset=(0, 0, 0)):
    pb = rig.pose.bones[name]
    rest = pb.bone.matrix_local
    h = rest.to_translation()
    m = Matrix.Translation(Vector(offset)) @ Matrix.Translation(h) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Translation(-h)
    pb.matrix_basis = rest.inverted() @ m @ rest


def side_rot(tag, x=0.0, y=0.0, z=0.0):
    s = 1 if tag == "L" else -1
    return (x, y * s, z * s)


def wave(t, phase=0.0, n=1):
    return math.sin(n * t + phase)


def relaxed(t, tag, lower=0.32, sway=0.04, phase=0.0):
    pose("UpperArm." + tag, side_rot(tag, 0.06 + sway * wave(t, phase), lower + sway * 0.6 * wave(t, phase + 1.0)))
    pose("ForeArm." + tag, side_rot(tag, -0.25 - 0.05 * wave(t, phase + 0.6), 0.05))
    pose("Hand." + tag, side_rot(tag, -0.1, 0.1 + 0.08 * wave(t, phase + 1.2)))


def dangling(t, tag, back=0.0, bend=0.12, point=0.45, phase=0.0):
    pose("Thigh." + tag, side_rot(tag, back - 0.05 * wave(t, phase), 0.0, 0.02))
    pose("Shin." + tag, side_rot(tag, bend + 0.06 * wave(t, phase + 0.8)))
    pose("Foot." + tag, side_rot(tag, point + 0.05 * wave(t, phase + 1.4)))


def idle(t):
    pose("Root", offset=(0, 0, FLOAT + 0.03 * wave(t)))
    pose("Hips", (0.02 * wave(t, 0.4), 0, 0.02 * wave(t, 2.0, 1)))
    pose("Spine", (0.015 * wave(t, 1.6, 2), 0, 0))
    pose("Chest", (0.02 * wave(t, 1.8, 2), 0, 0))
    pose("Neck", (0.04, 0, 0))
    pose("Head", (0.06 + 0.03 * wave(t, 2.4), 0.04 * wave(t, 0.7), 0.03 * wave(t, 3.0)))
    relaxed(t, "L", phase=0.0)
    relaxed(t, "R", phase=1.7)
    dangling(t, "L", phase=0.3)
    dangling(t, "R", back=0.06, bend=0.2, phase=2.1)


def fly(t):
    pose("Root", offset=(0, 0, FLOAT + 0.025 * wave(t, 0, 2)))
    pose("Hips", (0.32, 0.03 * wave(t), 0))
    pose("Spine", (-0.04, 0, 0.03 * wave(t, 0.5)))
    pose("Chest", (-0.08 + 0.02 * wave(t, 1.0, 2), 0, 0))
    pose("Neck", (-0.1, 0, 0))
    pose("Head", (-0.12, 0.03 * wave(t, 1.5), 0))
    for tag, ph in (("L", 0.0), ("R", 1.2)):
        pose("UpperArm." + tag, side_rot(tag, -0.55 + 0.06 * wave(t, ph), 0.5))
        pose("ForeArm." + tag, side_rot(tag, -0.15 + 0.05 * wave(t, ph + 0.7), 0.05))
        pose("Hand." + tag, side_rot(tag, -0.25 + 0.1 * wave(t, ph + 1.3), 0.1))
    dangling(t, "L", back=0.35, bend=0.55, point=0.7, phase=0.0)
    dangling(t, "R", back=0.5, bend=0.75, point=0.8, phase=1.9)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def reach(t):
    u = t / math.tau
    k = smooth(u / 0.35) * (1 - smooth((u - 0.7) / 0.3))
    idle(t)
    pose("Chest", (0.06 * k, 0, 0.12 * k))
    pose("Head", (0.08 + 0.06 * k, 0, 0.05 * k))
    pose("UpperArm.R", side_rot("R", -1.25 * k + 0.06 * (1 - k), 0.32 * (1 - k) - 0.1 * k))
    pose("ForeArm.R", side_rot("R", -0.25 * (1 - k) - 0.1 * k, 0.05))
    pose("Hand.R", side_rot("R", 0.25 * k - 0.1 * (1 - k), 0.1))


def look(t):
    u = t / math.tau
    turn = 0.6 * math.sin(math.tau * u) * smooth(u / 0.15) * (1 - smooth((u - 0.85) / 0.15))
    idle(t)
    pose("Chest", (0.02, 0, turn * 0.3))
    pose("Neck", (0.04, 0, turn * 0.3))
    pose("Head", (0.03 + 0.08 * abs(turn), 0.03 * turn, turn * 0.5))


def release(t):
    u = t / math.tau
    k = smooth(u / 0.6)
    pose("Root", offset=(0, 0, FLOAT + 0.35 * smooth(u)))
    pose("Hips", (0, 0, 0))
    pose("Spine", (-0.05 * k, 0, 0))
    pose("Chest", (-0.15 * k, 0, 0))
    pose("Neck", (-0.15 * k, 0, 0))
    pose("Head", (0.06 * (1 - k) - 0.35 * k, 0, 0))
    for tag in ("L", "R"):
        pose("UpperArm." + tag, side_rot(tag, -0.15 * k, 0.32 * (1 - k) - 0.55 * k))
        pose("ForeArm." + tag, side_rot(tag, -0.25 * (1 - k) - 0.05 * k, 0.05))
        pose("Hand." + tag, side_rot(tag, -0.1, 0.1 - 0.2 * k))
        dangling(t, tag, back=0.02, bend=0.12 + 0.1 * k, point=0.45 + 0.2 * k)


def stand(t):
    pose("Root", offset=(0, 0, 0.004 * wave(t, 0, 2)))
    pose("Spine", (0.01 * wave(t, 1.6), 0, 0))
    pose("Chest", (0.015 * wave(t, 1.8), 0, 0))
    pose("Head", (0.02 * wave(t, 2.4), 0.03 * wave(t, 0.7), 0))
    relaxed(t, "L", sway=0.02, phase=0.0)
    relaxed(t, "R", sway=0.02, phase=1.7)


STRIDE = 0.42  # rad of thigh swing each way: ~0.7 m steps at 1.6 m/s with a 26-frame cycle (visitor.gd SPEED)


def walk(t):
    pose("Root", offset=(0, 0, 0.025 * abs(wave(t)) - 0.02))
    pose("Hips", (0, 0, 0.06 * wave(t)))
    pose("Chest", (-0.03, 0, -0.08 * wave(t)))
    pose("Head", (0.02, 0, 0.04 * wave(t)))
    for tag, ph in (("L", 0.0), ("R", math.pi)):
        swing = wave(t, ph)  # +1 = this leg back
        pose("Thigh." + tag, side_rot(tag, STRIDE * swing))
        pose("Shin." + tag, side_rot(tag, 0.05 + 0.55 * max(0.0, wave(t, ph - 0.9))))  # knee bends as the leg comes through
        pose("Foot." + tag, side_rot(tag, -0.15 * swing))
        pose("UpperArm." + tag, side_rot(tag, -0.35 * swing, 0.32))  # arms against the legs
        pose("ForeArm." + tag, side_rot(tag, -0.3 + 0.1 * swing, 0.05))
        pose("Hand." + tag, side_rot(tag, -0.1, 0.1))


if STYLE == "ghost":
    CLIPS = {"idle": (idle, 120), "fly": (fly, 60), "reach": (reach, 48), "look": (look, 120), "release": (release, 90)}
else:
    CLIPS = {"idle": (stand, 120), "walk": (walk, 26)}

for clip, (fn, length) in CLIPS.items():
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(length + 1):
        scene.frame_set(frame)
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        fn(math.tau * frame / length)
        for pb in rig.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    print("clip", clip, length, "frames")
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)

rig.rotation_mode = "XYZ"
rig.rotation_euler = (0, 0, math.pi)

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=SAVE_BLEND)

select_only([rig, body], rig)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_cameras=False, export_lights=False, export_image_format="JPEG", export_image_quality=90)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "kB")
