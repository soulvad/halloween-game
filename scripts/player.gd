extends CharacterBody3D

## Ghost, first person: mouse look, WASD float (no gravity), Shift sprint (burns charge), E interact, Q fade, F scare.
## Collision mask follows the visibility level: walls with solid_from > level are passed through.

const Wall = preload("res://scripts/wall.gd")

const WALK := 3.5
const SPRINT := 6.0  ## faster than a chasing hunter (4.5), slower than nothing else
const SPRINT_COST := 0.4  ## charge per second while sprinting
const ACCEL := 7.0  ## soft start/stop, the ghost glides
const MOUSE_SENS := 0.0022
const EYE := 1.55
const BOB := 0.04  ## gentle float of the view
const ALPHA := [0.0, 0.25, 0.55, 0.9]  ## body opacity per visibility level (seen by others / minimap)
const FADE_ALPHA := 0.1
const LAYER_SELF := 4  ## visual layer 3: the own body, hidden from the first-person camera

var held := ""  ## memento name or ""
var held_color := Color.WHITE
var sprinting := false
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
	GameState.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	sprinting = Input.is_action_pressed("sprint") and dir != Vector3.ZERO and GameState.charge > 0
	if sprinting:
		GameState.charge = maxf(GameState.charge - SPRINT_COST * delta, 0)
	var want := dir * (SPRINT if sprinting else WALK)
	velocity = velocity.lerp(want, minf(ACCEL * delta, 1))
	move_and_slide()


func _process(delta: float) -> void:
	_t += delta
	head.position.y = EYE + sin(_t * 1.6) * BOB
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
	elif event.is_action_pressed("fade"):
		GameState.fade()
	elif event.is_action_pressed("scare"):
		var s = target_station()
		if s and s.has_method("scare"):
			s.scare()


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


func _on_visibility_changed() -> void:
	var fading := GameState.is_fading()
	collision_mask = 1 if fading else (1 << GameState.level) - 1
	body.transparency = 1.0 - (FADE_ALPHA if fading else ALPHA[GameState.level])
