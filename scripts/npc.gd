extends CharacterBody3D

## Living person, wanders around its spawn point. Walls always block it.
## GOOD: the first time it notices the ghost it believes in it and gives charge.
## HUNTER: exists from `active_from`, chases a visible ghost, its touch drains charge.

const Wall = preload("res://scripts/wall.gd")

enum Kind { GOOD, HUNTER }

const SPEED := [2.0, 4.2]  ## by kind; the ghost (6) is faster
const SIGHT := 6.0
const TOUCH := 1.3
const WANDER := 3.0
const BELIEF_CHARGE := 2.0
const DRAIN := 2.0  ## charge per second while touching
const LAYER_NPC := 16
const WALLS := 7  ## layers 1-3

@export var kind := Kind.GOOD
@export var title_text := "Сусідка"
@export_range(1, 3) var sees_from := 2
@export_range(1, 3) var active_from := 1
@export var color := Color(0.9, 0.75, 0.55)

var believes := false
var _home: Vector3
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _label: Label3D


func _ready() -> void:
	_home = global_position
	collision_layer = LAYER_NPC
	collision_mask = WALLS
	var m := Wall.box(Vector3(0.6, 1.7, 0.6), color)
	m.position.y = 0.85
	add_child(m)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.radius = 0.35
	shape.position.y = 0.9
	add_child(shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.006
	_label.position.y = 2.1
	add_child(_label)
	GameState.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	var on := GameState.level >= active_from
	visible = on
	set_physics_process(on)


func player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


# shortcut: no line-of-sight check, people see through walls within SIGHT; add a raycast if it feels unfair.
func sees_player() -> bool:
	var p := player()
	return p != null and GameState.visible_to(sees_from) and _flat_dist(p) < SIGHT


func _physics_process(delta: float) -> void:
	var sees := sees_player()
	var target := _home + _wander
	if sees and kind == Kind.GOOD and not believes:
		believes = true
		GameState.add_charge(BELIEF_CHARGE)
	if sees and kind == Kind.HUNTER:
		target = player().global_position
	else:
		_wander_t -= delta
		if _wander_t <= 0:
			_wander = Vector3(randf_range(-WANDER, WANDER), 0, randf_range(-WANDER, WANDER))
			_wander_t = randf_range(2, 4)
	var to := target - global_position
	to.y = 0
	velocity = to.normalized() * SPEED[kind] if to.length() > 0.3 else Vector3.ZERO
	move_and_slide()
	if sees and kind == Kind.HUNTER and _flat_dist(player()) < TOUCH:
		GameState.drain(DRAIN * delta)
	_label.text = _label_text(sees)


func _label_text(sees: bool) -> String:
	if kind == Kind.HUNTER:
		return "Мисливець: бачу тебе!" if sees else title_text
	return title_text + (" (вірить)" if believes else "")


func _flat_dist(n: Node3D) -> float:
	return Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
