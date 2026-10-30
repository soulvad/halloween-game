@tool
extends StaticBody3D

## Interactive object; the player calls interact(player) when pressing E at it.
## SPIRIT gives charge, ALTAR (your bones) asks the HUD to open the altar modal, HAUNT makes a noise visitors hear,
## EVIDENCE is revealed to the archaeologists in your room, CIRCLE is where you hold E after the ritual (game.gd).

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")
const Visitor = preload("res://scripts/visitor.gd")

## MEMENTO, LOVED, CANDLE belonged to the old house level; kept only so the enum values stay stable.
enum Kind { SPIRIT, ALTAR, MEMENTO, LOVED, CANDLE, HAUNT, EVIDENCE, CIRCLE }

const SPIRIT_CHARGE := 1.0
const SPIRIT_COOLDOWN := 12.0
const HAUNT_COST := 1.0
const HAUNT_COOLDOWN := 6.0
const WITNESS_RANGE := 7.0  ## EVIDENCE: an archaeologist this close sees it revealed
const LAYER_STATION := 8  ## layer 4: only the player's aim sees it, the ghost floats through
const HAUNT_LINES := ["*дзень-дзень*", "*скрип*", "*брязкіт*", "*стук-стук*", "*шурхіт*"]

@export var kind := Kind.SPIRIT
@export var title_text := "Дзеркало"
@export_range(1, 3) var min_level := 1  ## visibility level needed to use it
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)
@export var power := 1.0  ## HAUNT: how loud (unease per listener)

var cooldown := 0.0  ## SPIRIT, HAUNT
var shown := false  ## EVIDENCE
var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = LAYER_STATION
	_label.font = UI.font()
	if kind == Kind.EVIDENCE:
		add_to_group("evidence")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	_label.text = title()
	_label.visible = GameState.show_labels
	var dim := GameState.level < min_level or cooldown > 0
	if kind == Kind.CIRCLE:
		dim = GameState.stage != GameState.Stage.RITUAL
	_mesh.transparency = 0.6 if dim else 0.0


func title() -> String:
	match kind:
		Kind.CIRCLE:
			if GameState.stage != GameState.Stage.RITUAL:
				return title_text + " (ще не час)"
			if GameState.ritual < 1.0:
				return "%s: священник молиться %d%%" % [title_text, int(GameState.ritual * 100)]
			if GameState.level < GameState.MAX_LEVEL:
				return title_text + ": стань Присутністю (рівень 3)"
			return title_text + ": утримуй E — піти"
		Kind.EVIDENCE:
			if shown:
				return title_text + " (побачили)"
	if GameState.level < min_level:
		return "%s (рівень %d)" % [title_text, min_level]
	match kind:
		Kind.SPIRIT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": зарядитися")
		Kind.ALTAR:
			if GameState.level >= GameState.MAX_LEVEL:
				return title_text
			return "%s: рівень %d (треба %d заряду)" % [title_text, GameState.level + 1, GameState.LEVEL_REQ[GameState.level + 1]]
		Kind.HAUNT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": шуміти")
		Kind.EVIDENCE:
			if GameState.stage != GameState.Stage.EVIDENCE:
				return title_text + " (ніхто не бачить)"
			return title_text + (": підсвітити" if witness() else " (поруч нікого)")
	return title_text


## An archaeologist close enough to see this evidence revealed.
func witness() -> bool:
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible and v.kind == Visitor.Kind.ARCH and v.global_position.distance_to(global_position) < WITNESS_RANGE:
			return true
	return false


## E would do something right now (the HUD shows ready / locked).
func can_use() -> bool:
	match kind:
		Kind.CIRCLE:
			return GameState.release_ready()
		Kind.EVIDENCE:
			return not shown and GameState.level >= min_level and GameState.stage == GameState.Stage.EVIDENCE and witness()
	if GameState.level < min_level:
		return false
	match kind:
		Kind.SPIRIT:
			return cooldown <= 0 and GameState.charge < GameState.MAX_CHARGE
		Kind.ALTAR:
			return GameState.level < GameState.MAX_LEVEL
		Kind.HAUNT:
			return cooldown <= 0 and GameState.charge >= HAUNT_COST
	return false


func interact(_p) -> void:
	if not can_use():
		return
	match kind:
		Kind.SPIRIT:
			GameState.add_charge(SPIRIT_CHARGE)
			cooldown = SPIRIT_COOLDOWN
		Kind.ALTAR:
			GameState.altar_requested.emit()
		Kind.HAUNT:
			GameState.charge -= HAUNT_COST
			cooldown = HAUNT_COOLDOWN
			GameState.say(title_text, HAUNT_LINES.pick_random(), UI.ORANGE)
			GameState.haunt(global_position, power)
		Kind.EVIDENCE:
			shown = true
			_mesh.transparency = 0.0
			(_mesh.mesh.material as StandardMaterial3D).albedo_color = UI.GOLD
			GameState.evidence += 1
		# CIRCLE: holding E is handled by game.gd


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
	_label.visibility_range_end = 10.0  ## first person: only nearby things are labelled
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.004
	_label.position.y = size.y / 2 + 0.4
	_label.text = title_text
	_label.layers = 2  ## the minimap camera culls labels
	_label.modulate = {Kind.SPIRIT: UI.CHARGE, Kind.ALTAR: UI.CHARGE, Kind.HAUNT: UI.ORANGE, Kind.EVIDENCE: UI.GOLD, Kind.CIRCLE: UI.MOM}.get(kind, UI.PAPER)
	add_child(_label)
