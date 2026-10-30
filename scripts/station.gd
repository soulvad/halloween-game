@tool
extends StaticBody3D

## Interactive object; the player calls interact(player) when pressing E next to it.
## SPIRIT gives charge, ALTAR raises visibility, MEMENTO is carried to LOVED,
## LOVED takes memories and is the goal, CANDLE is lit by the priest and burns the ghost around it.

const Wall = preload("res://scripts/wall.gd")

enum Kind { SPIRIT, ALTAR, MEMENTO, LOVED, CANDLE }

const SPIRIT_CHARGE := 1.0
const SPIRIT_COOLDOWN := 12.0
const HOLY_RADIUS := 2.5
const BLOW_COST := 1.0
const LAYER_STATION := 8  ## layer 4: only the player's Reach sees it, the ghost floats through

@export var kind := Kind.SPIRIT
@export var title_text := "Дзеркало"
@export_range(1, 3) var min_level := 1  ## visibility level needed to use it
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)
@export var lit := false  ## CANDLE

var cooldown := 0.0  ## SPIRIT
var _mesh: MeshInstance3D
var _label: Label3D
var _holy: Node3D
var _gifts: Node3D  ## LOVED: delivered memories


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = LAYER_STATION
	if kind == Kind.CANDLE:
		add_to_group("holy_candle")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	_label.text = title()
	_mesh.transparency = 0.6 if GameState.level < min_level or cooldown > 0 else 0.0
	if kind == Kind.CANDLE:
		_holy.visible = lit
		if lit:
			GameState.burn_near(global_position, HOLY_RADIUS, delta)


func light() -> void:
	lit = true


func title() -> String:
	match kind:
		Kind.CANDLE:
			if not lit:
				return "Згасла свічка"
			if GameState.level < min_level:
				return title_text + " (обпікає)"
			return "%s: загасити (%d заряд)" % [title_text, BLOW_COST]
		Kind.LOVED:
			if GameState.level < min_level:
				return title_text + " (не відчуває тебе)"
			if GameState.player and GameState.player.held != "":
				return "%s: віддати %s" % [title_text, GameState.player.held]
			if GameState.memories < GameState.MEMORIES_NEEDED:
				return "%s: спогади %d/%d" % [title_text, GameState.memories, GameState.MEMORIES_NEEDED]
			if GameState.level < GameState.MAX_LEVEL:
				return title_text + ": стань видимим (рівень 3)"
			return title_text + ": відпустити"
	if GameState.level < min_level:
		return "%s (рівень %d)" % [title_text, min_level]
	match kind:
		Kind.SPIRIT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": зарядитися")
		Kind.ALTAR:
			if GameState.level >= GameState.MAX_LEVEL:
				return title_text
			return "%s: рівень %d (треба %d заряду)" % [title_text, GameState.level + 1, GameState.LEVEL_REQ[GameState.level + 1]]
		Kind.MEMENTO:
			return title_text + ": взяти"
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
		Kind.LOVED:
			if p.held != "":
				_add_gift(p.held_color)
				GameState.memories += 1
				p.set_held("")
			elif GameState.memories >= GameState.MEMORIES_NEEDED and GameState.level >= GameState.MAX_LEVEL:
				GameState.finish(true)
		Kind.CANDLE:
			if lit and GameState.charge >= BLOW_COST:
				GameState.charge -= BLOW_COST
				lit = false


func _add_gift(c: Color) -> void:
	var b := Wall.box(Vector3(0.25, 0.25, 0.25), c)
	var a := _gifts.get_child_count() * TAU / GameState.MEMORIES_NEEDED
	b.position = Vector3(cos(a), 0, sin(a)) * 0.7
	_gifts.add_child(b)


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
	if kind == Kind.CANDLE:
		_holy = Wall.holy_glow(HOLY_RADIUS)
		_holy.position.y = -size.y / 2
		_holy.visible = lit
		add_child(_holy)
	if kind == Kind.LOVED:
		_gifts = Node3D.new()
		_gifts.position.y = -size.y / 2 + 0.13
		add_child(_gifts)
