extends CharacterBody3D
## Capsule player: WASD move, E interact with the nearest station in front.

const SPEED := 7.0
const GRAVITY := 20.0
const CART_CAPACITY_VISUAL := 36

var held := ""  ## item id, "plate", or "" for empty hands
var plate: Array = []  ## ingredients when held == "plate"
var _held_visual: Node3D

@onready var hand: Node3D = $Hand
@onready var cart: Node3D = $Cart
@onready var cart_items: Node3D = $Cart/Items
@onready var reach: Area3D = $Reach


func _ready() -> void:
	GameState.cart_changed.connect(_on_cart_changed)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0, input.y)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if dir:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var s = target_station()
		if s:
			s.interact(self)


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


func set_held(item: String, items: Array = []) -> void:
	held = item
	plate = items.duplicate() if item == "plate" else []
	if _held_visual:
		_held_visual.queue_free()
	_held_visual = GameState.make_visual(held, plate)
	hand.add_child(_held_visual)


func _on_cart_changed(item: String) -> void:
	var n := cart_items.get_child_count()
	if n >= CART_CAPACITY_VISUAL:
		return
	var v := GameState.make_visual(item)
	v.scale = Vector3.ONE * 0.45
	v.position = Vector3((n % 4 - 1.5) * 0.18, floori(n / 12.0) * 0.16, (n / 4 % 3 - 1) * 0.18)
	cart_items.add_child(v)
