extends CharacterBody3D

## Ghost, first person: mouse look, WASD float (no gravity), Shift sprint, E interact.
## Collides only with layer 1 (outer walls): floats through inner walls, furniture, doors and the bricked wall.
## Passing through: the screen fades into a cyan-rimmed dark veil as the eye nears a wall's surface, the view widens a
## little, and a ghost left inside a wall with no input drifts out to open floor (never stuck in the dark).
## Pushing into an outer wall frosts the screen edges instead.
## Aim: the station under the crosshair glows at the rim (cyan = E does something now, dim = not yet); E sends a cyan wisp to it.

const Wall = preload("res://scripts/wall.gd")
const Fx = preload("res://scripts/fx.gd")

const WALK := 3.5
const SPRINT := 6.0
const ACCEL := 7.0  ## soft start/stop, the ghost glides
const MOUSE_SENS := 0.0022
const EYE := 1.55
const BOB := 0.04  ## gentle float of the view
## Flying: the view swells up and down and rocks a little, stronger with speed, and leans into a strafe.
const FLY_BOB := 0.075  ## m at walking speed
const FLY_SPRINT_BOB := 0.07  ## m added on top of the bob at full sprint
const FLY_SIDE := 0.01  ## m, no stronger on a sprint
const FLY_ROLL := 0.009  ## rad, no stronger on a sprint
const FLY_PITCH := 0.009  ## rad
const FLY_LEAN := 0.012  ## rad at walking speed, sideways
const FLY_RATE := 3.4  ## rad/s of the swell at walking speed
const FLY_EASE := 2.5  ## how quickly it fades in and out, per second
const CLOUD: Array[Vector4] = [
	Vector4(0, 0.58, 0, 0.2), Vector4(-0.13, 0.66, 0.02, 0.1), Vector4(0.12, 0.68, -0.02, 0.1),
	Vector4(0, 0.2, 0, 0.27), Vector4(-0.25, 0.28, 0, 0.15), Vector4(0.25, 0.28, 0, 0.15),
	Vector4(-0.34, 0.03, 0.03, 0.12), Vector4(0.34, 0.03, 0.03, 0.12),
	Vector4(0, -0.15, 0, 0.26), Vector4(-0.16, -0.34, 0.02, 0.17), Vector4(0.15, -0.36, -0.02, 0.17), Vector4(0, -0.54, 0, 0.13),
]
const CLOUD_SOFT := 1.5  ## the puffs are larger than the shape: their rims fade out
const LAYER_SELF := 4  ## visual layer 3: the own body, hidden from the first-person camera
const PHASE_MASK := 2 | 4 | 64  ## inner walls, furniture, bricked wall / closed doors: what the ghost floats through
const PHASE_NEAR := 0.45  ## the veil starts this far (m) from a wall's surface
const PHASE_DRIFT := 3.0  ## m/s out of a wall when no key is held
const DRIFT_AHEAD := 2.0  ## m: open floor this close along its heading and a drifting ghost keeps going that way
const FOV := 75.0
const PHASE_FOV := 9.0  ## extra degrees deep inside a wall
const AIM_ON := Color(0.66, 0.86, 0.85, 1.0)  ## rim on a station E can use (UI.CYAN)
const AIM_OFF := Color(0.55, 0.48, 0.4, 0.45)  ## ...and on one it can't yet
const WISP_TIME := 0.2  ## s, the E wisp out to the target and gone

var held := ""  ## memento name or ""
var held_color := Color.WHITE
var sprinting := false
var flight := 0.0  ## 0 hovering .. 1 walking speed .. SPRINT / WALK sprinting, smoothed
var _fly_t := 0.0
var _lean := 0.0
var _held_visual: Node3D
var _t := 0.0
var phase := 0.0  ## 0 clear .. 1 deep inside a wall (smoothed; the HUD and tests read it)
var _phase_target := 0.0
var hollow := false  ## in a space dug in the rock that only it sees (turtles' room, easter_eggs.gd): no veil, no drift
var _exit_dir := Vector3.ZERO  ## shortest way out of the wall the eye is in
var _drift := Vector3.ZERO  ## locked while inside a wall
var _edge := 0.0
var _edge_told := false
var _probe := SphereShape3D.new()
var _veil: ShaderMaterial
var _veil_rect: ColorRect  ## hidden while clear: the shader copies the whole screen
var _travel := 0.0  ## m flown inside walls: the stone in the veil rushes past (phase.gdshader)
var _aim_mat := ShaderMaterial.new()
var _aimed: Node3D  ## the station wearing the rim

@onready var body: MeshInstance3D = $Body
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/Aim
@onready var hand: Node3D = $Head/Camera3D/Hand
@onready var reach: Area3D = $Reach


func _ready() -> void:
	add_to_group("player")
	GameState.player = self
	body.layers = LAYER_SELF
	camera.cull_mask = 0xFFFFF & ~LAYER_SELF
	collision_mask = 1
	_build_cloud()
	show_body(false)
	camera.near = 0.05  # less wall slicing at the surface
	_probe.radius = PHASE_NEAR
	_aim_mat.shader = load("res://scripts/aim.gdshader")
	var layer := CanvasLayer.new()
	layer.layer = -1  # over the 3D view, under the HUD
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ShaderMaterial.new()
	_veil.shader = load("res://scripts/phase.gdshader")
	rect.material = _veil
	_veil_rect = rect
	layer.add_child(rect)
	add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	sprinting = Input.is_action_pressed("sprint") and dir != Vector3.ZERO
	var want := dir * (SPRINT if sprinting else WALK)
	var depth := PHASE_NEAR if hollow else wall_depth()
	_phase_target = clampf(1.0 - depth / PHASE_NEAR, 0.0, 1.0)
	if depth >= 0.0 or dir != Vector3.ZERO:
		_drift = Vector3.ZERO
	elif _drift == Vector3.ZERO:  # let go: keep going the way you came (rooms are a thin wall apart), else out the nearest side
		var flat := Vector3(velocity.x, 0, velocity.z)
		_drift = _out_of_rock(flat.normalized() if flat.length() > 0.5 else _exit_dir)
	if depth < 0.0 and dir == Vector3.ZERO:
		want = _drift * PHASE_DRIFT
	velocity = velocity.lerp(want, minf(ACCEL * delta, 1))
	move_and_slide()
	var pushing := false
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		pushing = pushing or (dir != Vector3.ZERO and dir.normalized().dot(n) < -0.5)
	_edge = move_toward(_edge, 1.0 if pushing else 0.0, delta * (4.0 if pushing else 2.0))
	if pushing and not _edge_told:
		_edge_told = true
		GameState.think("Далі не пускає… Тут кінчається підземелля.")


## Deep in the rock that heading may only lead to the next block or the outer wall: take the shortest way to open floor.
func _out_of_rock(heading: Vector3) -> Vector3:
	var at := Vector2(global_position.x, global_position.z)
	var open: Array = get_parent().get_meta("rooms", {}).values() + get_parent().get_meta("doors", [])
	var way := Vector2(heading.x, heading.z)
	var best := Vector2.INF
	for r: Rect2 in open:
		if r.has_point(at):  # furniture in a room, not rock
			return heading
		for d in range(1, int(DRIFT_AHEAD / 0.25) + 1):
			if r.has_point(at + way * d * 0.25):
				return heading
		var nearest := at.clamp(r.position, r.end)
		if nearest.distance_to(at) < best.distance_to(at):
			best = nearest
	return heading if open.is_empty() else Vector3(best.x - at.x, 0, best.y - at.y).normalized()


## Signed distance (m) from the eye to the nearest wall it floats through: < 0 inside, PHASE_NEAR if none near.
## Also sets `_exit_dir` (world, flat) to the nearest face when inside.
func wall_depth() -> float:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis(), camera.global_position)
	q.collision_mask = PHASE_MASK
	var best := PHASE_NEAR
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var body: CollisionObject3D = hit.collider
		var cs = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
		if not (cs is CollisionShape3D and cs.shape is BoxShape3D):
			continue
		var half: Vector3 = cs.shape.size / 2
		var local: Vector3 = cs.global_transform.affine_inverse() * camera.global_position
		var d3 := local.abs() - half
		var d := Vector3(maxf(d3.x, 0), maxf(d3.y, 0), maxf(d3.z, 0)).length() + minf(maxf(d3.x, maxf(d3.y, d3.z)), 0.0)
		if d < best:
			best = d
			if d < 0:  # out through the closest side face (never up or down)
				var out := Vector3(signf(local.x), 0, 0) if d3.x > d3.z else Vector3(0, 0, signf(local.z))
				_exit_dir = (cs.global_transform.basis * out * Vector3(1, 0, 1)).normalized()
	return best


func _process(delta: float) -> void:
	_t += delta
	_sway(delta)
	var sprint_part := clampf((flight - 1.0) / (SPRINT / WALK - 1.0), 0, 1)
	head.position.y = EYE + sin(_t * 1.6) * BOB + sin(_fly_t) * (FLY_BOB * flight + FLY_SPRINT_BOB * sprint_part)
	body.position.y = 1.1 + sin(_t * 1.6) * 0.08
	phase = move_toward(phase, _phase_target, delta * 6.0)
	_veil.set_shader_parameter("amount", phase)
	_veil.set_shader_parameter("edge", _edge)
	_veil_rect.visible = phase > 0.001 or _edge > 0.001
	if phase > 0.0:
		_travel += Vector2(velocity.x, velocity.z).length() * delta
		_veil.set_shader_parameter("travel", _travel)
	camera.fov = FOV + PHASE_FOV * phase
	_aim()


## Rim the station under the aim: an overlay on every mesh it has (placeholder box or imported model).
func _aim() -> void:
	var t = target_station() if camera.current else null
	if t != _aimed:
		if is_instance_valid(_aimed):
			_overlay(_aimed, null)
		_aimed = t
		if t:
			_overlay(t, _aim_mat)
	if t:
		_aim_mat.set_shader_parameter("color", AIM_ON if t.can_use() else AIM_OFF)


func _overlay(n: Node, mat: Material) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = mat


## Mouse look before the GUI: with the mouse captured the cursor sits mid-screen, and a HUD control under it
## (the E card over a station) would swallow the motion and freeze the view.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.3, 1.3)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # click back into the game (e.g. after alt-tab)
	elif event.is_action_pressed("interact"):
		var s = target_station()
		if s:
			if s.can_use():
				_wisp(s.global_position)
			s.interact(self)


## A thin cyan streak from just under the eye out to `to`, gone in WISP_TIME, with a whoosh.
func _wisp(to: Vector3) -> void:
	var from := camera.global_position - camera.global_basis.y * 0.25 + -camera.global_basis.z * 0.3
	var d := to - from
	if d.length() < 0.2:
		return
	var root := Node3D.new()
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = AIM_ON
	box.material = mat
	streak.mesh = box
	streak.position.z = -0.5  # the box grows forward from the root
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(streak)
	get_parent().add_child(root)
	root.look_at_from_position(from, to, Vector3.FORWARD if absf(d.normalized().y) > 0.99 else Vector3.UP)
	root.scale = Vector3(1, 1, 0.01)
	var tw := root.create_tween()
	tw.tween_property(root, "scale:z", d.length(), WISP_TIME * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color.BLACK, WISP_TIME * 0.5)  # additive: black = gone
	tw.tween_callback(root.queue_free)
	Fx.sound_ui(get_tree(), "whoosh", -6.0)


## The ghost as others would see it, shown only in the guide: in play nothing shows you, not even a mirror.
func show_body(on: bool) -> void:
	body.visible = on


## A pale grey-blue cloud in the shape of the boy: puffs for the head, shoulders, chest and a trailing hem.
func _build_cloud() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/cloud.gdshader")
	body.mesh = null
	for puff: Vector4 in CLOUD:  # x, y, z, radius
		var mesh := SphereMesh.new()
		mesh.radius = puff.w * CLOUD_SOFT
		mesh.height = puff.w * CLOUD_SOFT * 2
		mesh.radial_segments = 16
		mesh.rings = 8
		mesh.material = mat
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.layers = LAYER_SELF
		m.position = Vector3(puff.x, puff.y, puff.z)
		body.add_child(m)


## Rock the view while flying. The camera, not the head: the head's pitch is the mouse look.
func _sway(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / WALK
	flight = lerpf(flight, speed, minf(FLY_EASE * delta, 1))
	_fly_t += delta * FLY_RATE * (0.6 + 0.4 * flight)  # by its own clock: changing speed never jumps the phase
	var side := velocity.dot(global_basis.x) / WALK
	_lean = lerpf(_lean, side, minf(FLY_EASE * delta, 1))
	var rock := minf(flight, 1.0)
	head.position.x = cos(_fly_t * 0.5) * FLY_SIDE * rock
	camera.rotation.z = sin(_fly_t * 0.5) * FLY_ROLL * rock - _lean * FLY_LEAN
	camera.rotation.x = cos(_fly_t) * FLY_PITCH * flight


## What the crosshair points at, else the nearest interactable in front (Reach), else null.
func target_station():
	var hit = ray.get_collider() if ray.is_colliding() else null
	if hit and hit.has_method("interact"):
		return hit
	var best = null
	var best_d := INF
	for b in reach.get_overlapping_bodies():
		var d := reach.global_position.distance_to(b.global_position)
		if b.has_method("interact") and d < best_d:
			best = b
			best_d = d
	return best


func set_held(item: String, color := Color.WHITE) -> void:
	held = item
	held_color = color
	if _held_visual:
		_held_visual.queue_free()
		_held_visual = null
	if item != "":
		_held_visual = Wall.box(Vector3(0.18, 0.18, 0.18), color)
		hand.add_child(_held_visual)

