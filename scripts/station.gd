@tool
extends StaticBody3D

## Interactive object; the player calls interact(player) when pressing E at it. `need` = power required ("" = none).
## MEMORY: a glint, only the next memory in order is visible. Memory 1 you touch; 2–4 an archaeologist finds, when lured
## there with the power in `need` (candle, noise, writing in the dust); 5 is never shown (game.gd: they read your name).
## CANDLE: lit/out, visitors notice. HAUNT: a noise (or, with need "write", writing in the dust) visitors notice.
## MIRROR: write ДОПОМОЖІТЬ for a witness → they call the priest. PLAN: the estate plan on the camp table (decor; the
## time-lapse finds it). KNOCK: your room's wall, rhythm 3–1 for someone in the room after they read your name.
## EVIDENCE: your things, game.gd has the archaeologists look them over (see()). CIRCLE: hold E after the ritual (game.gd).
## EGG: tells scripts/easter_eggs.gd, no effect on the story.

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")
const Visitor = preload("res://scripts/visitor.gd")
const MirrorGlass = preload("res://scripts/mirror.gd")

enum Kind { MEMORY, CANDLE, HAUNT, MIRROR, PLAN, KNOCK, EVIDENCE, CIRCLE, EGG }

const COOLDOWN := {Kind.CANDLE: 1.5, Kind.HAUNT: 4.0, Kind.EGG: 1.0}
const WITNESS_RANGE := 7.0  ## an archaeologist this close sees what you do
const HEAR_KNOCK := 4.0  ## KNOCK: has to be in your room (not the passage outside)
const FIND_RANGE := 3.0  ## MEMORY 2–4: a lured archaeologist this close finds it
const KNOCK_FAST := 0.7  ## max gap between the first three knocks
const KNOCK_PAUSE := Vector2(0.8, 2.5)  ## the pause before the last knock
const LAYER_STATION := 8  ## layer 4: only the player's aim sees it, the ghost floats through
const LABEL_PX := 0.0012  ## label size up close (UI.world_label)
const HAUNT_LINES := ["*дзень-дзень*", "*скрип*", "*брязкіт*", "*шурхіт*"]

@export var kind := Kind.HAUNT
@export var title_text := "Кайдани"
@export var need := ""  ## power from GameState.POWERS, "" = none
@export var memory_id := 0  ## MEMORY: 1..5
@export var lit := true  ## CANDLE
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)
@export var power := 1.0  ## HAUNT / CANDLE: how far it carries (unease per listener in old builds)

var cooldown := 0.0
var shown := false  ## EVIDENCE
var _knocks: Array[float] = []  ## KNOCK: times of the current attempt
var _mesh: Node3D  ## placeholder box (MeshInstance3D) or the final model from art/models/<node name>
var _label: Label3D
var _light: OmniLight3D
var _flame: MeshInstance3D  ## CANDLE with a final model: there's no box to glow, so this shows it's lit
var _writing: Label3D  ## MIRROR with a final model: no box to redden, the word itself


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = LAYER_STATION
	_label.font = UI.font()
	if kind == Kind.EVIDENCE:
		add_to_group("evidence")
	if kind == Kind.MIRROR:
		add_child(MirrorGlass.new(size))
	_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	if kind == Kind.MEMORY:
		visible = available()
		_mesh.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.08
		var v := finder() if visible and memory_id > 1 else null
		if v:
			v.found()
			GameState.remember(memory_id)
	_label.text = title()
	_label.visible = GameState.show_labels and visible
	if _label.visible:
		UI.world_label(_label, LABEL_PX)
	if kind not in [Kind.MEMORY, Kind.PLAN, Kind.EVIDENCE]:  # ready = solid, not yet = see-through
		if _mesh is GeometryInstance3D:
			_mesh.transparency = 0.0 if can_use() or shown else 0.45


## MEMORY: this is the next memory to find (5 is never a glint: the archaeologists read your name).
func available() -> bool:
	return memory_id != 5 and memory_id not in GameState.memories and GameState.memories.size() >= memory_id - 1


## MEMORY 2–4: an archaeologist lured here with the right power, close enough to find it.
func finder() -> Node3D:
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.kind == Visitor.Kind.ARCH and v.lured_by() == need and _flat(v) < FIND_RANGE:
			return v
	return null


func _flat(n: Node3D) -> float:
	return Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()


func title() -> String:
	if need != "" and not GameState.has_power(need):
		return title_text + " (ще не вмієш)"
	match kind:
		Kind.MEMORY:
			if memory_id == 1:
				return "Спогад: торкнутися"
			return "Щось моє… хай знайдуть живі (%s)" % GameState.POWER_NAMES.get(need, need)
		Kind.CANDLE:
			return "%s: %s" % [title_text, "загасити" if lit else "запалити"]
		Kind.HAUNT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": шуміти")
		Kind.MIRROR:
			if GameState.mirror_written:
				return "ДОПОМОЖІТЬ"
			return title_text + (": написати" if witness() else " (ніхто не побачить)")
		Kind.KNOCK:
			if GameState.wall_knocked or GameState.stage != GameState.Stage.EVIDENCE or not GameState.name_known():
				return title_text
			var dots := "●".repeat(_knocks.size()) + "○".repeat(4 - _knocks.size())
			return "%s: тук-тук-тук … тук  %s%s" % [title_text, dots, "" if witness() else " (поруч нікого)"]
		Kind.EVIDENCE:
			return title_text + (" (побачили)" if shown else "")
		Kind.CIRCLE:
			if GameState.stage != GameState.Stage.RITUAL:
				return title_text
			if GameState.ritual < 1.0:
				return "%s: священник молиться %d%%" % [title_text, int(GameState.ritual * 100)]
			return title_text + ": утримуй E — піти"
	return title_text


## An archaeologist close enough to see it.
func witness() -> bool:
	var r := HEAR_KNOCK if kind == Kind.KNOCK else WITNESS_RANGE
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible and v.kind == Visitor.Kind.ARCH and _flat(v) < r:
			return true
	return false


## E would do something right now (the HUD shows ready / locked).
func can_use() -> bool:
	if (need != "" and not GameState.has_power(need)) or cooldown > 0:
		return false
	match kind:
		Kind.MEMORY:
			return available() and memory_id == 1
		Kind.CANDLE, Kind.HAUNT, Kind.EGG:
			return true
		Kind.MIRROR:
			return not GameState.mirror_written and GameState.stage == GameState.Stage.HAUNT and witness()
		Kind.KNOCK:
			return not GameState.wall_knocked and GameState.stage == GameState.Stage.EVIDENCE and GameState.name_known() and witness()
		Kind.CIRCLE:
			return GameState.release_ready()
	return false


func interact(_p) -> void:
	if not can_use():
		return
	cooldown = COOLDOWN.get(kind, 0.0)
	match kind:
		Kind.MEMORY:
			GameState.remember(memory_id)
		Kind.CANDLE:
			lit = not lit
			GameState.haunt(global_position, power, "breath")
		Kind.HAUNT:
			GameState.say(title_text, "*у пилу проступають літери: ТУТ*" if need == "write" else HAUNT_LINES.pick_random(), UI.ORANGE)
			GameState.haunt(global_position, power, need)
		Kind.MIRROR:
			GameState.mirror_written = true
		Kind.KNOCK:
			_knock()
		Kind.EGG:
			get_tree().call_group("easter_eggs", "touched", name)
		# CIRCLE: holding E is handled by game.gd
	_refresh()


## EVIDENCE: the archaeologists have looked it over (game.gd).
func see() -> void:
	shown = true
	GameState.evidence += 1
	_refresh()


## One knock; three quick ones, a pause, one more = the code «я тут».
func _knock() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _knocks.is_empty():
		var gap := now - _knocks[-1]
		var ok := gap <= KNOCK_FAST if _knocks.size() < 3 else gap >= KNOCK_PAUSE.x and gap <= KNOCK_PAUSE.y
		if not ok:
			_knocks.clear()
	_knocks.append(now)
	GameState.say(title_text, "*тук*", UI.ORANGE)
	if _knocks.size() == 4:
		_knocks.clear()
		GameState.wall_knocked = true


func _refresh() -> void:
	if Engine.is_editor_hint() or not _mesh:
		return
	match kind:
		Kind.CANDLE:
			_light.visible = lit
			if _flame:
				_flame.visible = lit
			if _mat():
				_mat().emission_enabled = lit
		Kind.MIRROR:
			if GameState.mirror_written and _mat():
				_mat().albedo_color = Color(0.55, 0.1, 0.1)
			elif GameState.mirror_written and not _writing:
				_writing = Label3D.new()
				_writing.text = "ДОПОМОЖІТЬ"
				_writing.font = UI.font()
				_writing.font_size = 64
				_writing.pixel_size = 0.002
				_writing.modulate = Color(0.75, 0.08, 0.08)
				_writing.position.x = -size.x / 2 - 0.02  # the side facing the room
				_writing.rotation.y = -PI / 2
				add_child(_writing)
		Kind.EVIDENCE:
			if shown and _mat():
				_mat().albedo_color = UI.GOLD


## The placeholder box's material (null when a final model replaced it).
func _mat() -> StandardMaterial3D:
	return (_mesh.mesh.material as StandardMaterial3D) if _mesh is MeshInstance3D else null


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if not c.owner:
			c.free()
	_mesh = Wall.visual(name, size, color)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	add_child(shape)
	if kind in [Kind.MEMORY, Kind.CANDLE]:
		var m := _mat()
		if m:
			m.emission = color
			m.emission_energy_multiplier = 2.0
			m.emission_enabled = true
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.omni_range = 3.0 if kind == Kind.CANDLE else 2.0
		_light.light_energy = 1.2
		_light.position.y = size.y / 2 + 0.1
		add_child(_light)
		if kind == Kind.CANDLE and not m:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = color
			var drop := SphereMesh.new()
			drop.radius = 0.03
			drop.height = 0.1
			drop.material = mat
			_flame = MeshInstance3D.new()
			_flame.mesh = drop
			_flame.position.y = size.y / 2 + 0.04
			add_child(_flame)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.visibility_range_end = 6.0  ## first person: only nearby things are labelled
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = LABEL_PX
	_label.fixed_size = true  ## no giant letters next to the camera; UI.world_label shrinks it further off
	_label.position.y = size.y / 2 + 0.4
	_label.text = title_text
	_label.layers = 2  ## the minimap camera culls labels
	_label.modulate = {Kind.MEMORY: UI.CYAN, Kind.HAUNT: UI.ORANGE, Kind.CANDLE: UI.GOLD, Kind.EVIDENCE: UI.GOLD, Kind.CIRCLE: UI.MOM}.get(kind, UI.PAPER)
	add_child(_label)
