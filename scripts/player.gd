extends CharacterBody3D

## Ghost: floats (no gravity, no legs), WASD move, E interact, Q fade.
## Collision mask follows the visibility level: walls with solid_from > level are passed through.

const Wall = preload("res://scripts/wall.gd")

const SPEED := 6.0
const ALPHA := [0.0, 0.25, 0.55, 0.9]  ## body opacity per visibility level
const FADE_ALPHA := 0.1

var held := ""  ## memento name or ""
var held_color := Color.WHITE
var _held_visual: Node3D
var _t := 0.0

@onready var body: MeshInstance3D = $Body
@onready var hand: Node3D = $Hand
@onready var reach: Area3D = $Reach


func _ready() -> void:
	add_to_group("player")
	GameState.player = self
	GameState.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0, input.y)
	velocity = dir * SPEED
	move_and_slide()
	if dir:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12 * delta)


func _process(delta: float) -> void:
	_t += delta
	body.position.y = 1.1 + sin(_t * 2.5) * 0.12


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var s = target_station()
		if s:
			s.interact(self)
	elif event.is_action_pressed("fade"):
		GameState.fade()


## Nearest interactable body inside the Reach area, or null.
func target_station():
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
		_held_visual = Wall.box(Vector3(0.3, 0.3, 0.3), color)
		hand.add_child(_held_visual)


func _on_visibility_changed() -> void:
	var fading := GameState.is_fading()
	collision_mask = 1 if fading else (1 << GameState.level) - 1
	body.transparency = 1.0 - (FADE_ALPHA if fading else ALPHA[GameState.level])
