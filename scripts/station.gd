@tool
extends StaticBody3D

## Interactive object; the player calls interact(player) when pressing E next to it.
## SPIRIT gives charge, ALTAR raises visibility, MEMENTO is picked up, DOOR opens, LOVED is the goal.

const Wall = preload("res://scripts/wall.gd")

enum Kind { SPIRIT, ALTAR, MEMENTO, DOOR, LOVED }

const SPIRIT_CHARGE := 1.0
const SPIRIT_COOLDOWN := 8.0
const LAYER_STATION := 8  ## layer 4: only the player's Reach sees it, the ghost floats through
const LAYER_SOLID := 1

@export var kind := Kind.SPIRIT
@export var title_text := "Свічка"
@export_range(1, 3) var min_level := 1  ## visibility level needed to use it
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)

var cooldown := 0.0  ## SPIRIT
var used := false  ## MEMENTO taken / DOOR open
var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	_update_layer()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	_label.text = title()
	_mesh.transparency = 0.6 if GameState.level < min_level or cooldown > 0 or used else 0.0


func title() -> String:
	if GameState.level < min_level:
		return "%s (рівень %d)" % [title_text, min_level]
	match kind:
		Kind.SPIRIT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": зарядитися")
		Kind.ALTAR:
			if GameState.level >= GameState.MAX_LEVEL:
				return title_text
			return "%s: рівень %d за %d заряду" % [title_text, GameState.level + 1, GameState.LEVEL_COST[GameState.level + 1]]
		Kind.DOOR:
			return title_text + (": зачинити" if used else ": відчинити")
		Kind.LOVED:
			return title_text + ": відпустити"
	return title_text


func interact(p) -> void:
	if GameState.level < min_level:
		return
	match kind:
		Kind.SPIRIT:
			if cooldown <= 0 and GameState.charge < GameState.MAX_CHARGE:
				GameState.add_charge(SPIRIT_CHARGE)
				cooldown = SPIRIT_COOLDOWN
		Kind.ALTAR:
			GameState.level_up()
		Kind.MEMENTO:
			if p.held == "":
				p.set_held(title_text, color)
				queue_free()
		Kind.DOOR:
			used = not used
			_update_layer()
		Kind.LOVED:
			if p.held != "":
				GameState.finish(true)


func _update_layer() -> void:
	collision_layer = LAYER_STATION | (LAYER_SOLID if kind == Kind.DOOR and not used else 0)


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if not c.owner:
			c.free()
	_mesh = Wall.box(size, color)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	add_child(shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.006
	_label.position.y = size.y / 2 + 0.4
	_label.text = title_text
	add_child(_label)
