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
const PAINT_TEX := "res://art/textures/help_writing.png"
const DUST_PATCH := "res://art/textures/dust_patch.png"
const DUST_WRITING := "res://art/textures/dust_writing.png"
const PAINT_SHADER = preload("res://scripts/paint.gdshader")
const NAME_SCRATCH := "res://art/textures/name_scratch.png"
const NAME_WALL_X := 23.49  ## Memory5: the east wall of your room (gen_dungeon YourRoom x1), just off its face
const NAME_WIDTH := 1.6  ## m
const Fx = preload("res://scripts/fx.gd")

enum Kind { MEMORY, CANDLE, HAUNT, MIRROR, PLAN, KNOCK, EVIDENCE, CIRCLE, EGG }

const LAST_POWER := "hands"  ## MIRROR: memory 4's power, the knock needs it later
const STAND_LID := {"barrel_small": 0.895, "box_small": 0.878}  ## height of the sunken lid inside the rim, of the whole model (else its top)
const COOLDOWN := {Kind.CANDLE: 1.5, Kind.HAUNT: 4.0, Kind.EGG: 1.0}
const WITNESS_RANGE := 7.0  ## an archaeologist this close sees what you do
const HEAR_KNOCK := 4.0  ## KNOCK: has to be in your room (not the passage outside)
const FIND_RANGE := 3.0  ## MEMORY 2–4: a lured archaeologist this close notices it and walks up
const EXAMINE_NEAR := 1.5  ## ...looks at it from this close
const EXAMINE_TIME := 3.0  ## ...for this long before it's found (slower while still walking up)
const KNOCK_BEATS := [0.0, 0.5, 1.0, 2.25]  ## s from the first knock: three quick, a pause, one (hud.gd rings show when)
const KNOCK_TOLERANCE := 0.2  ## a knock may be off by this share of the gap before it; more, or too late = start over
const LAYER_STATION := 8  ## layer 4: only the player's aim sees it, the ghost floats through
const LABEL_PX := 0.0012  ## label size up close (UI.world_label)
const HAUNT_LINES := ["*дзень-дзень*", "*скрип*", "*брязкіт*", "*шурхіт*"]
const HAUNT_SFX := {"Chains": "clank", "DripChain": "clank", "Grate": "clank", "Bell": "bell", "GateBell": "bell", "Jug": "jug"}  ## else clank
const LIGHT_ENERGY := 1.2
const SMOKE := Color(0.55, 0.55, 0.58, 0.7)

@export var kind := Kind.HAUNT
@export var title_text := "Кайдани"
@export var need := ""  ## power from GameState.POWERS, "" = none
@export var memory_id := 0  ## MEMORY: 1..5
@export var lit := true  ## CANDLE
@export var stand := ""  ## CANDLE: the art/decor model it stands on, fitted so that its top meets the candle's foot
@export var stand_turn := 0.0  ## degrees
@export var size := Vector3(0.5, 0.5, 0.5):
	set(v):
		size = v
		_build()
@export var color := Color(0.6, 0.3, 1)
@export var power := 1.0  ## HAUNT / CANDLE: how far it carries (unease per listener in old builds)

var cooldown := 0.0
var shown := false  ## EVIDENCE
var _exam := 0.0  ## MEMORY 2–4: seconds an archaeologist has been looking at it
var _noticed := false  ## MEMORY 2–4: an archaeologist is walking up to it
var _knocks: Array[float] = []  ## KNOCK: times of the current attempt
var knock_misses := 0  ## KNOCK: attempts broken off (hud.gd shakes the dots)
var _mesh: Node3D  ## placeholder box (MeshInstance3D) or the final model from art/models/<node name>
var _label: Label3D
var _light: OmniLight3D
var _stand: Node3D  ## CANDLE: the prop under it
var _flame: MeshInstance3D  ## CANDLE with a final model: there's no box to glow, so this shows it's lit
var _writing: MeshInstance3D  ## HAUNT "write": ТУТ traced through the dust (DUST_WRITING, tools/draw_dust.py); Memory5: your name scratched in the wall (NAME_SCRATCH, tools/draw_name.py)
var _glass: MeshInstance3D  ## MIRROR: the reflecting pane (mirror.gd)
var _paint: MeshInstance3D  ## MIRROR: ДОПОМОЖІТЬ finger-painted on the glass (PAINT_TEX, tools/draw_writing.py)
var _denied := false  ## the ghost already said why E does nothing here (once until it works)
var _gone := 0.0  ## MEMORY 2–4: just found, the glint stays a moment to pop
var _fade: Tween  ## CANDLE: flame going out / flaring up


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = LAYER_STATION
	_label.font = UI.font()
	if kind == Kind.EVIDENCE:
		add_to_group("evidence")
	if kind == Kind.CANDLE:
		add_to_group("candle")  # visitors read `lit` to say what they saw
	if kind == Kind.MIRROR:
		_glass = MirrorGlass.new(size)
		add_child(_glass)
	if kind == Kind.HAUNT and need == "write":
		_dust()
	if kind == Kind.MEMORY and memory_id == 5:
		_name_wall()
	_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	cooldown = maxf(cooldown - delta, 0)
	if kind == Kind.MEMORY:
		_gone = maxf(_gone - delta, 0)
		visible = available() or _gone > 0
		_mesh.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.08
		_examine(delta)
	if kind == Kind.KNOCK and not _knocks.is_empty() and knock_time() > knock_window(_knocks.size()).y:
		_knock_miss()  # waited too long for the next knock
	if kind == Kind.CIRCLE:  # appears with the ritual
		visible = GameState.stage == GameState.Stage.RITUAL
		collision_layer = LAYER_STATION if visible else 0
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


## MEMORY 2–4: a lured archaeologist notices it, walks up, looks a while, then finds it.
func _examine(delta: float) -> void:
	var v := finder() if available() and memory_id > 1 else null
	if not v:
		_exam = 0.0
		_noticed = false
		return
	v.inspect(global_position, not _noticed)
	_noticed = true
	_exam += delta if _flat(v) < EXAMINE_NEAR else delta * 0.3
	if _exam >= EXAMINE_TIME:
		v.found()
		GameState.remember(memory_id)
		_gone = 0.35
		Fx.pop(_mesh, 1.6, 0.35)
		Fx.sound(self, "memory")


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
			return _mirror_ready() and witness()
		Kind.KNOCK:
			return not GameState.wall_knocked and GameState.stage == GameState.Stage.EVIDENCE and GameState.name_known() and witness()
		Kind.CIRCLE:
			return GameState.release_ready()
	return false


func interact(_p) -> void:
	if not can_use():
		_deny()
		return
	_denied = false
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
	_feedback()


## E on something that can't be used yet: a dull tone, and once the ghost's thought why.
func _deny() -> void:
	Fx.sound_ui(get_tree(), "deny")
	if _denied:
		return
	if need != "" and not GameState.has_power(need):
		GameState.think("Я ще не пам'ятаю, як це…")
	elif kind == Kind.MIRROR and not GameState.has_power(LAST_POWER):
		GameState.think("Ще рано кликати на допомогу… Я не все про себе згадав.")
	elif _unseen():
		GameState.think("Ніхто не побачить…")
	else:
		return
	_denied = true


## MIRROR / KNOCK: everything is ready but nobody is near to see it.
func _unseen() -> bool:
	if witness():
		return false
	if kind == Kind.MIRROR:
		return _mirror_ready()
	return kind == Kind.KNOCK and not GameState.wall_knocked and GameState.stage == GameState.Stage.EVIDENCE and GameState.name_known()


## The priest is called only once every memory 1–4 is back: without Сила рук the knock in your room is impossible.
func _mirror_ready() -> bool:
	return not GameState.mirror_written and GameState.stage == GameState.Stage.HAUNT and GameState.has_power(LAST_POWER)


## Right after a use: the sound and what the thing itself does.
func _feedback() -> void:
	match kind:
		Kind.CANDLE:
			_flicker()
		Kind.HAUNT:
			if need == "write":
				Fx.sound(self, "write")
				_letters("ТУТ", 0.9)
			else:
				Fx.sound(self, HAUNT_SFX.get(String(name), "clank"))
				Fx.shake(_mesh)
				Fx.puff(self, global_position + Vector3.UP * size.y / 2)
		Kind.MIRROR:
			Fx.sound(self, "write")
			_paint.set_instance_shader_parameter("reveal", 0.0)
			create_tween().tween_method(func(k: float): _paint.set_instance_shader_parameter("reveal", k), 0.0, 1.0, 1.6)
		Kind.KNOCK:
			Fx.sound(self, "knock")
			var cam: Camera3D = GameState.player.get("camera") if GameState.player else null
			var at := global_position
			if cam:  # dust on the side you knock from
				var to := cam.global_position - at
				at += Vector3(to.x, 0, to.z).normalized() * 0.15
				Fx.kick(cam)
			Fx.puff(self, at, Color(0.75, 0.68, 0.58, 0.8), 10, 0.2)
			if GameState.wall_knocked:
				Fx.flash(get_tree(), Color(0.6, 0.95, 1.0, 0.25), 0.8)
				Fx.sound(self, "chime")


## CANDLE: blown out = the flame shrinks and leans, a wisp of smoke; lit = the light swells in 0.3 s.
func _flicker() -> void:
	if _fade:
		_fade.kill()
	var top := global_position + Vector3.UP * (size.y / 2 + 0.06)
	_light.visible = true
	if _flame:
		_flame.visible = true
	_fade = create_tween().set_parallel()
	if lit:
		Fx.sound(self, "ignite")
		_light.light_energy = 0.0
		_fade.tween_property(_light, "light_energy", LIGHT_ENERGY, 0.3).set_ease(Tween.EASE_OUT)
		if _flame:
			_flame.scale = Vector3.ONE * 0.2
			_flame.rotation.z = 0.0
			_fade.tween_property(_flame, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		Fx.sound(self, "breath")
		Fx.puff(self, top, SMOKE, 10, 0.05)
		_fade.tween_property(_light, "light_energy", 0.0, 0.25)
		if _flame:
			_fade.tween_property(_flame, "scale", Vector3.ONE * 0.1, 0.25)
			_fade.tween_property(_flame, "rotation:z", 0.6, 0.25)
		_fade.chain().tween_callback(_refresh)  # hides light and flame (unless lit again since)


## HAUNT "write": a patch of dust on the floor instead of the placeholder box (kept, invisible, for the aim rim), and the
## finger strokes over it, hidden until written.
func _dust() -> void:
	if _mat():
		_mat().transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat().albedo_color.a = 0.0
	var patch := StandardMaterial3D.new()
	patch.albedo_texture = load(DUST_PATCH)
	patch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch.roughness = 1.0
	add_child(_floor_quad(patch, 1.5, 0.002))
	var strokes := ShaderMaterial.new()
	strokes.shader = PAINT_SHADER
	strokes.set_shader_parameter("tex", load(DUST_WRITING))
	strokes.set_shader_parameter("gloss", 0.0)
	_writing = _floor_quad(strokes, 1.5, 0.004)
	_writing.set_instance_shader_parameter("reveal", 0.0)
	add_child(_writing)


func _floor_quad(mat: Material, scale_: float, lift: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size.x, size.z) * scale_
	q.material = mat
	var m := MeshInstance3D.new()
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = -size.y / 2 + lift  # on the floor
	m.rotation.x = -PI / 2
	return m


## Memory5: the name you scratched with a nail, hidden until an archaeologist reads it (scratch()).
func _name_wall() -> void:
	var tex: Texture2D = load(NAME_SCRATCH)
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("gloss", 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(NAME_WIDTH, NAME_WIDTH * tex.get_height() / tex.get_width())
	q.material = mat
	_writing = MeshInstance3D.new()
	_writing.mesh = q
	_writing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_writing.top_level = true
	_writing.position = Vector3(NAME_WALL_X, global_position.y, global_position.z)
	_writing.rotation.y = -PI / 2  # faces -X, into the room
	_writing.set_instance_shader_parameter("reveal", 0.0)
	get_parent().add_child.call_deferred(_writing)  # not under the station: Memory5 itself is never visible


## Memory5: the name shows up stroke by stroke while they read it (game.gd _look_over).
func scratch(time: float) -> void:
	if _writing:
		_letters("", time)


## The finger traces the word in the dust, left to right.
func _letters(_text: String, time: float) -> void:
	_writing.set_instance_shader_parameter("reveal", 0.0)
	create_tween().tween_method(func(k: float): _writing.set_instance_shader_parameter("reveal", k), 0.0, 1.0, time)


## EVIDENCE: the archaeologists have looked it over (game.gd).
func see() -> void:
	shown = true
	GameState.evidence += 1
	_refresh()


## One knock; three quick ones, a pause, one more = the code «я тут». The first knock starts the beat, every next one
## must land in its window (knock_window()), or the attempt starts over with no knock counted.
func _knock() -> void:
	var now := knock_clock()
	GameState.say(title_text, "*тук*", UI.ORANGE)
	if not _knocks.is_empty():
		var w := knock_window(_knocks.size())
		var at := now - _knocks[0]
		if at < w.x or at > w.y:
			_knock_miss()
			return
	_knocks.append(now)
	if _knocks.size() == KNOCK_BEATS.size():
		_knocks.clear()
		GameState.wall_knocked = true


## KNOCK: when beat i may land, in s from the first knock.
func knock_window(i: int) -> Vector2:
	var gap: float = KNOCK_BEATS[i] - KNOCK_BEATS[i - 1]
	return Vector2(KNOCK_BEATS[i] - gap * KNOCK_TOLERANCE, KNOCK_BEATS[i] + gap * KNOCK_TOLERANCE)


## KNOCK: seconds since the attempt's first knock, -1 with none.
func knock_time() -> float:
	return knock_clock() - _knocks[0] if not _knocks.is_empty() else -1.0


static func knock_clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _knock_miss() -> void:
	_knocks.clear()
	knock_misses += 1


func _refresh() -> void:
	if Engine.is_editor_hint() or not _mesh:
		return
	match kind:
		Kind.CANDLE:
			_light.visible = lit
			if _flame:
				_flame.visible = lit
				_flame.scale = Vector3.ONE
				_flame.rotation.z = 0.0
			if _mat():
				_mat().emission_enabled = lit
		Kind.MIRROR:
			if GameState.mirror_written and _mat():
				_mat().albedo_color = Color(0.55, 0.1, 0.1)
			if GameState.mirror_written and not _paint:
				_paint = MeshInstance3D.new()
				var quad := QuadMesh.new()
				var tex: Texture2D = load(PAINT_TEX)
				var pane: Vector2 = _glass._glass
				quad.size = Vector2(pane.x * 0.98, pane.x * 0.98 * tex.get_height() / tex.get_width())
				var mat := ShaderMaterial.new()
				mat.shader = PAINT_SHADER
				mat.set_shader_parameter("tex", tex)
				quad.material = mat
				_paint.mesh = quad
				_paint.position = Vector3(0, pane.y * 0.12, 0.004)  # on the glass, facing the room, a bit above the middle
				_glass.add_child(_paint)
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
		_light.light_energy = LIGHT_ENERGY
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
	if kind == Kind.CANDLE and stand != "":
		_build_stand()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.visibility_range_end = UI.LABEL_RANGE  ## first person: only nearby things are labelled
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = LABEL_PX
	_label.fixed_size = true  ## no giant letters next to the camera; UI.world_label shrinks it further off
	_label.position.y = size.y / 2 + 0.4
	_label.text = title_text
	_label.layers = 2  ## the minimap camera culls labels
	_label.transparency = 1.0  ## drawn flat by labels.gd: the ink pass mangles 3D text
	_label.add_to_group("world_label")
	_label.modulate = {Kind.MEMORY: UI.CYAN, Kind.HAUNT: UI.ORANGE, Kind.CANDLE: UI.GOLD, Kind.EVIDENCE: UI.GOLD, Kind.CIRCLE: UI.MOM}.get(kind, UI.PAPER)
	add_child(_label)


## The prop under a candle, from the floor up to the candle's foot (a rim may rise around it). Decoration like art/decor: no collision, no shadow.
func _build_stand() -> void:
	var top := position.y - size.y / 2
	_stand = Node3D.new()
	_stand.position.y = -size.y / 2 - top
	_stand.rotation.y = deg_to_rad(stand_turn)
	var n: Node3D = load("res://art/decor/%s.glb" % stand).instantiate()
	var box := Wall.bounds(n)
	var fit: float = top / (box.size.y * STAND_LID.get(stand, 1.0))
	n.scale *= fit
	var c := box.get_center()
	n.position = Vector3(-c.x, -box.position.y, -c.z) * fit
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stand.add_child(n)
	add_child(_stand)
