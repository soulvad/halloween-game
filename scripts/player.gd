extends CharacterBody3D

## Ghost, first person: mouse look, WASD float (no gravity), Shift sprint, E interact.
## Collides only with layer 1 (outer walls): floats through inner walls, furniture, doors and the bricked wall.

const Wall = preload("res://scripts/wall.gd")

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
const LAYER_SELF := 4  ## visual layer 3: the own body, hidden from the first-person camera

var held := ""  ## memento name or ""
var held_color := Color.WHITE
var sprinting := false
var flight := 0.0  ## 0 hovering .. 1 walking speed .. SPRINT / WALK sprinting, smoothed
var _fly_t := 0.0
var _lean := 0.0
var _held_visual: Node3D
var _t := 0.0

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
	body.transparency = 0.6  ## a faint glow on the minimap
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	sprinting = Input.is_action_pressed("sprint") and dir != Vector3.ZERO
	var want := dir * (SPRINT if sprinting else WALK)
	velocity = velocity.lerp(want, minf(ACCEL * delta, 1))
	move_and_slide()


func _process(delta: float) -> void:
	_t += delta
	_sway(delta)
	var sprint_part := clampf((flight - 1.0) / (SPRINT / WALK - 1.0), 0, 1)
	head.position.y = EYE + sin(_t * 1.6) * BOB + sin(_fly_t) * (FLY_BOB * flight + FLY_SPRINT_BOB * sprint_part)
	body.position.y = 1.1 + sin(_t * 1.6) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.3, 1.3)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
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

