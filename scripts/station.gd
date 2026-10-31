@tool
extends StaticBody3D

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")
const Visitor = preload("res://scripts/visitor.gd")

enum Kind { MEMORY, CANDLE, HAUNT, MIRROR, PLAN, DOOR, KNOCK, EVIDENCE, CIRCLE }

const COOLDOWN := {Kind.CANDLE: 1.5, Kind.HAUNT: 4.0}
const WITNESS_RANGE := 7.0
const HEAR_KNOCK := 2.0
const KNOCK_FAST := 0.7
const KNOCK_PAUSE := Vector2(0.8, 2.5)
const LAYER_STATION := 8
const LAYER_PEOPLE_ONLY := 64
const HAUNT_LINES := ["*дзень-дзень*", "*скрип*", "*брязкіт*", "*шурхіт*"]
const SFX_DIR := "res://audio/sfx/"
const SFX_EXTENSIONS := ["ogg", "wav", "mp3"]
const SFX_VOLUME_DB := -4.0
const SFX_RANGE := 14.0
const STATE_NODE := "On"

@export var kind := Kind.HAUNT
@export var title_text := "Кайдани"
@export var need := ""
@export var memory_id := 0
@export var lit := true
@export var open := false
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)
@export var power := 1.0

var cooldown := 0.0
var shown := false
var _knocks: Array[float] = []
var _mesh: Node3D
var _label: Label3D
var _light: OmniLight3D
var _block: CollisionShape3D
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = LAYER_STATION
	_label.font = UI.font()
	if kind == Kind.EVIDENCE:
		add_to_group("evidence")
	if kind == Kind.DOOR:
		var b := StaticBody3D.new()
		b.collision_layer = LAYER_PEOPLE_ONLY
		b.collision_mask = 0
		_block = CollisionShape3D.new()
		_block.shape = BoxShape3D.new()
		_block.shape.size = size
		b.add_child(_block)
		add_child(b)
	if kind == Kind.KNOCK:
		Wall.textured(_mat(), "bricked")
	var stream := sound(name)
	if stream:
		_sfx = AudioStreamPlayer3D.new()
		_sfx.stream = stream
		_sfx.volume_db = SFX_VOLUME_DB
		_sfx.max_distance = SFX_RANGE
		add_child(_sfx)
	_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	if kind == Kind.MEMORY:
		visible = available()
		_mesh.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.08
	_label.text = title()
	_label.visible = GameState.show_labels and visible
	if kind == Kind.KNOCK:
		_mesh.visible = GameState.stage < GameState.Stage.EVIDENCE
	if kind not in [Kind.MEMORY, Kind.DOOR]:
		if _mesh is GeometryInstance3D:
			_mesh.transparency = 0.0 if can_use() or shown else 0.45


static func sound(node_name: String) -> AudioStream:
	var first := RegEx.create_from_string("^[A-Z][a-z]+").search(node_name)
	for n in [node_name, first.get_string() if first else node_name]:
		for ext in SFX_EXTENSIONS:
			var path := "%s%s.%s" % [SFX_DIR, n, ext]
			if ResourceLoader.exists(path):
				return load(path)
	return null


func available() -> bool:
	if memory_id in GameState.memories or GameState.memories.size() < memory_id - 1:
		return false
	return memory_id != 5 or (GameState.stage == GameState.Stage.EVIDENCE and GameState.evidence >= GameState.EVIDENCE_NEEDED)


func title() -> String:
	if need != "" and not GameState.has_power(need):
		return title_text + " (ще не вмієш)"
	match kind:
		Kind.MEMORY:
			return "Спогад: торкнутися"
		Kind.CANDLE:
			return "%s: %s" % [title_text, "загасити" if lit else "запалити"]
		Kind.HAUNT:
			return title_text + (" (%d с)" % ceili(cooldown) if cooldown > 0 else ": шуміти")
		Kind.MIRROR:
			if GameState.mirror_written:
				return "ДОПОМОЖІТЬ"
			return title_text + (": написати" if witness() else " (ніхто не побачить)")
		Kind.PLAN:
			if GameState.plan_moved:
				return title_text + " (зсунуто)"
			if GameState.stage != GameState.Stage.LURE:
				return title_text
			return title_text + (": зсунути" if witness() else " (ніхто не побачить)")
		Kind.DOOR:
			return "%s: %s" % [title_text, "зачинити" if open else "відчинити"]
		Kind.KNOCK:
			if GameState.stage != GameState.Stage.LURE or not GameState.plan_moved:
				return title_text
			var dots := "●".repeat(_knocks.size()) + "○".repeat(4 - _knocks.size())
			return "%s: тук-тук-тук … тук  %s%s" % [title_text, dots, "" if witness() else " (поруч нікого)"]
		Kind.EVIDENCE:
			if shown:
				return title_text + " (побачили)"
			if GameState.stage != GameState.Stage.EVIDENCE:
				return title_text
			return title_text + (": показати" if witness() else " (поруч нікого)")
		Kind.CIRCLE:
			if GameState.stage != GameState.Stage.RITUAL:
				return title_text
			if GameState.ritual < 1.0:
				return "%s: священник молиться %d%%" % [title_text, int(GameState.ritual * 100)]
			return title_text + ": утримуй E — піти"
	return title_text


func witness() -> bool:
	var r := HEAR_KNOCK if kind == Kind.KNOCK else WITNESS_RANGE
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible and v.kind == Visitor.Kind.ARCH and v.global_position.distance_to(global_position) < r:
			return true
	return false


func can_use() -> bool:
	if (need != "" and not GameState.has_power(need)) or cooldown > 0:
		return false
	match kind:
		Kind.MEMORY:
			return available()
		Kind.CANDLE, Kind.HAUNT, Kind.DOOR:
			return true
		Kind.MIRROR:
			return not GameState.mirror_written and GameState.stage == GameState.Stage.HAUNT and witness()
		Kind.PLAN:
			return not GameState.plan_moved and GameState.stage == GameState.Stage.LURE and witness()
		Kind.KNOCK:
			return not GameState.wall_knocked and GameState.stage == GameState.Stage.LURE and GameState.plan_moved and witness()
		Kind.EVIDENCE:
			return not shown and GameState.stage == GameState.Stage.EVIDENCE and witness()
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
			GameState.haunt(global_position, power)
		Kind.HAUNT:
			GameState.say(title_text, HAUNT_LINES.pick_random(), UI.ORANGE)
			GameState.haunt(global_position, power)
		Kind.MIRROR:
			GameState.mirror_written = true
		Kind.PLAN:
			GameState.plan_moved = true
			position.x += 0.15
		Kind.DOOR:
			open = not open
			GameState.haunt(global_position, power)
			if owner and owner.has_method("rebake_nav"):
				owner.rebake_nav.call_deferred()
		Kind.KNOCK:
			_knock()
		Kind.EVIDENCE:
			shown = true
			GameState.evidence += 1
	if _sfx:
		_sfx.play()
	_refresh()


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
	var state := _mesh.get_node_or_null(STATE_NODE) as Node3D
	if state:
		state.visible = {Kind.CANDLE: lit, Kind.MIRROR: GameState.mirror_written, Kind.EVIDENCE: shown}.get(kind, false)
	match kind:
		Kind.CANDLE:
			_light.visible = lit
			if _mat():
				_mat().emission_enabled = lit
		Kind.DOOR:
			_block.disabled = open
			_mesh.rotation.y = -1.4 if open else 0.0
			_mesh.position.x = -size.x / 2 if open else 0.0
		Kind.MIRROR:
			if GameState.mirror_written and _mat():
				_mat().albedo_color = Color(0.55, 0.1, 0.1)
		Kind.EVIDENCE:
			if shown and _mat():
				_mat().albedo_color = UI.GOLD


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
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.visibility_range_end = 6.0
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.0012
	_label.fixed_size = true
	_label.position.y = size.y / 2 + 0.4
	_label.text = title_text
	_label.layers = 2
	_label.modulate = {Kind.MEMORY: UI.CYAN, Kind.HAUNT: UI.ORANGE, Kind.CANDLE: UI.GOLD, Kind.EVIDENCE: UI.GOLD, Kind.CIRCLE: UI.MOM}.get(kind, UI.PAPER)
	add_child(_label)
