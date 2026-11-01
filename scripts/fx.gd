extends RefCounted
## Feedback kit: a sound at a thing, shake / pop tweens, a dust puff, a screen flash, a camera kick.
## Static, reach it like the box helper: `const Fx = preload("res://scripts/fx.gd")`, then `Fx.sound(self, "clank")`.
## Sounds are `audio/sfx/<name>.ogg` (credits in audio/CREDITS.md); a missing file stays silent.
## Names: breath, ignite, clank, bell, jug, write, knock, whoosh, chime, deny, memory, dust.

const SFX_DIR := "res://audio/sfx/"
const HEAR := 22.0  ## m: 3D sounds fade out by here
const FLASH_LAYER := 90  ## over the HUD, under the pause menu
const MIX_DB := -3.0  ## every game sound sits this far under its own level; the master slider stays at 100 %
const NEAR_DB := -2.0  ## 3D sounds stop growing this far under their level, so the source itself doesn't blast

static var _cache := {}


static func stream(sfx: String) -> AudioStream:
	if not _cache.has(sfx):
		var path := SFX_DIR + sfx + ".ogg"
		_cache[sfx] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sfx]


## A one-shot sound from `at` (pitch jittered so repeats don't sound canned). Returns the player or null.
static func sound(at: Node3D, sfx: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var s := stream(sfx)
	if s == null or not at.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.max_distance = HEAR
	p.unit_size = 4.0
	tame(p)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	at.get_tree().root.add_child(p)
	p.global_position = at.global_position
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A one-shot sound with no position (UI, the ghost's own).
static func sound_ui(tree: SceneTree, sfx: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var s := stream(sfx)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db + MIX_DB
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A 3D player's level under the mix, and no near-field boost: Godot gets up to +3 dB louder inside `unit_size`, which
## made sounds harsh right at the source while they were fine from afar. Call after setting volume_db.
static func tame(p: AudioStreamPlayer3D) -> AudioStreamPlayer3D:
	p.volume_db += MIX_DB
	p.max_db = p.volume_db + NEAR_DB
	return p


## Wobble a Node3D around its rest rotation, dying out over `time`.
static func shake(n: Node3D, strength := 0.12, time := 0.45) -> void:
	var rest := n.rotation
	var t := n.create_tween()
	var steps := 6
	for i in steps:
		var k := strength * (1.0 - float(i) / steps) * (1.0 if i % 2 == 0 else -1.0)
		t.tween_property(n, "rotation", rest + Vector3(k * 0.6, 0, k), time / steps)
	t.tween_property(n, "rotation", rest, time / steps)


## Swell and settle (Node3D or Control).
static func pop(n: Node, amount := 1.25, time := 0.3) -> void:
	var rest = n.scale
	var t := n.create_tween()
	t.tween_property(n, "scale", rest * amount, time * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", rest, time * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short burst of dust (or smoke, or sparks with another colour) at `pos`, freed when done.
static func puff(parent: Node, pos: Vector3, color := Color(0.75, 0.68, 0.58, 0.8), amount := 18, spread := 0.25) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Full-screen tint that fades out.
static func flash(tree: SceneTree, color := Color(0.6, 0.95, 1.0, 0.45), time := 0.5) -> void:
	var layer := CanvasLayer.new()
	layer.layer = FLASH_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	tree.root.add_child(layer)
	var t := r.create_tween()
	t.tween_property(r, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)
	t.tween_callback(layer.queue_free)


## Nudge a camera's view and let it spring back (knocks, impacts).
static func kick(cam: Camera3D, amount := 0.03, time := 0.18) -> void:
	var t := cam.create_tween()
	t.tween_property(cam, "v_offset", -amount, time * 0.3)
	t.tween_property(cam, "v_offset", 0.0, time * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
