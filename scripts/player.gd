extends CharacterBody3D

## Ghost, first person: mouse look, WASD float (no gravity), Shift sprint, E interact.
## Collides only with layer 1 (outer walls): floats through inner walls, furniture, doors and the bricked wall.
## Passing through: the screen fades into a cyan-rimmed dark veil as the eye nears a wall's surface, the view widens a
## little, and a ghost left inside a wall with no input drifts out by the nearest face (never stuck in the dark).
## Pushing into an outer wall frosts the screen edges instead.

const Wall = preload("res://scripts/wall.gd")

const WALK := 3.5
const SPRINT := 6.0
const ACCEL := 7.0  ## soft start/stop, the ghost glides
const MOUSE_SENS := 0.0022
const EYE := 1.55
const BOB := 0.04  ## gentle float of the view
## Flying: the view swells up and down and rocks a little, stronger with speed, and leans into a strafe.
const FLY_BOB := 0.075  ## m at walking speed
const FLY_SIDE := 0.025  ## m
const FLY_ROLL := 0.022  ## rad
const FLY_PITCH := 0.009  ## rad
const FLY_LEAN := 0.028  ## rad at walking speed, sideways
const FLY_RATE := 3.4  ## rad/s of the swell at walking speed
const FLY_EASE := 2.5  ## how quickly it fades in and out, per second
const LAYER_SELF := 4  ## visual layer 3: the own body, hidden from the first-person camera
const PHASE_MASK := 2 | 4 | 64  ## inner walls, furniture, bricked wall / closed doors: what the ghost floats through
const PHASE_NEAR := 0.45  ## the veil starts this far (m) from a wall's surface
const PHASE_DRIFT := 3.0  ## m/s out of a wall when no key is held
const FOV := 75.0
const PHASE_FOV := 9.0  ## extra degrees deep inside a wall

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
var _exit_dir := Vector3.ZERO  ## shortest way out of the wall the eye is in
var _drift := Vector3.ZERO  ## locked while inside a wall
var _edge := 0.0
var _edge_told := false
var _probe := SphereShape3D.new()
var _veil: ShaderMaterial

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
	body.transparency = 0.6
	camera.near = 0.05  # less wall slicing at the surface
	_probe.radius = PHASE_NEAR
	var layer := CanvasLayer.new()
	layer.layer = -1  # over the 3D view, under the HUD
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ShaderMaterial.new()
	_veil.shader = load("res://scripts/phase.gdshader")
	rect.material = _veil
	layer.add_child(rect)
	add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	sprinting = Input.is_action_pressed("sprint") and dir != Vector3.ZERO
	var want := dir * (SPRINT if sprinting else WALK)
	var depth := wall_depth()
	_phase_target = clampf(1.0 - depth / PHASE_NEAR, 0.0, 1.0)
	if depth >= 0.0:
		_drift = Vector3.ZERO
	elif _drift == Vector3.ZERO:  # just went in: keep going the way you came (walls touch back to back), else out the nearest side
		var flat := Vector3(velocity.x, 0, velocity.z)
		_drift = flat.normalized() if flat.length() > 0.5 else _exit_dir
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
	head.position.y = EYE + sin(_t * 1.6) * BOB + sin(_fly_t) * FLY_BOB * flight
	body.position.y = 1.1 + sin(_t * 1.6) * 0.08
	phase = move_toward(phase, _phase_target, delta * 6.0)
	_veil.set_shader_parameter("amount", phase)
	_veil.set_shader_parameter("edge", _edge)
	camera.fov = FOV + PHASE_FOV * phase


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
			s.interact(self)


## Rock the view while flying. The camera, not the head: the head's pitch is the mouse look.
func _sway(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / WALK
	flight = lerpf(flight, speed, minf(FLY_EASE * delta, 1))
	_fly_t += delta * FLY_RATE * (0.6 + 0.4 * flight)  # by its own clock: changing speed never jumps the phase
	var side := velocity.dot(global_basis.x) / WALK
	_lean = lerpf(_lean, side, minf(FLY_EASE * delta, 1))
	head.position.x = cos(_fly_t * 0.5) * FLY_SIDE * flight
	camera.rotation.z = sin(_fly_t * 0.5) * FLY_ROLL * flight - _lean * FLY_LEAN
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

