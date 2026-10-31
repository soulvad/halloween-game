extends Node3D
## Easter eggs, none of them touch the story. Hidden in the rock between rooms, where only a ghost can go; a coloured
## light leaking through the wall is the clue. Cat: E on the pedestal (no text on purpose), the cat rises, spins until
## its track ends, freezes; E again, it spins again. Skeleton: E on the bones, it dances. Rat: runs from you along ROUTE, through a hole in a
## wall; the turtles' pizza room behind it exists only if you pass through that wall. Phone: an air-raid alert on
## Тарас's phone once. Stations of Kind.EGG call touched(). Everything is on visual layer 2, so the minimap and the
## guide tour don't give the eggs away.
## Art drops in by name: art/models/Pedestal, Cat, Rat, Skeleton, Bones, Turtle, Pizza; sound: audio/eggs (egg_audio.gd).
## Skeleton.glb is built by tools/make_skeleton.py and carries its own dance.

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")
const EggAudio = preload("res://scripts/egg_audio.gd")

const EGGS := ["cat", "skeleton", "phone", "turtles"]
const LAYER_HIDDEN := 2  ## the first-person camera sees it, the minimap and the tour cull it
const LINE_GAP := 3.5  ## seconds between subtitle lines (a new one replaces the old)
const ARCH_COLOR := Color("8BEA4E")
const CAT_SPIN := 7.0
const CAT_DELAY := 2.0  ## seconds from E until the cat starts spinning
const CAT_TOP := 0.8  ## the pedestal's height
const DANCE_TIME := 5.0  ## the length of audio/eggs/skeleton.ogg
const BONES_LABEL := 0.15  ## label height over the top of the pile (stations use 0.4)
const ROUTE: Array[Vector3] = [Vector3(0, 0, -2), Vector3(0, 0, 1.1), Vector3(-4, 0, 0.9), Vector3(-8.2, 0, 0.9), Vector3(-10, 0, 0.9)]
const RAT_SPEED := 5.5
const RAT_SCARE := 3.0
const ROOM := Rect2(-14.3, -0.6, 5.5, 4.2)  ## turtles' room (x, z): shares the west wall of R3L, the rat hole is in it
const WALL_INNER := -8.5  ## x of that wall's face on the R3L side
const ROOM_H := 3.0
const ROOM_NEAR := 4.0
const TURTLE_MASKS := [Color("D8352A"), Color("2A63D8"), Color("E8842A"), Color("8A3AC8")]
const PHONE_NEAR := 9.0

var found: Array[String] = []
var phone_at := 150.0  ## play seconds before the phone may ring (the test shortens it)
var dancing := 0.0  ## seconds of the skeleton's dance left
var rat_i := 0  ## ROUTE point the rat runs to / sits at
var _rat_running := false
var _rat: Node3D
var _rat_sound: AudioStreamPlayer3D
var cat_wait := -1.0  ## seconds until the cat spins, < 0 = not counting
var cat_spin := 0.0  ## seconds of spinning left (the track's length)
var _pedestal: Node3D  ## the station
var _cat: Node3D
var _cat_body: Node3D
var _cat_cover: Node3D
var _cat_sound: AudioStreamPlayer3D
var _skeleton: Node3D
var _limbs: Array[Node3D] = []  ## arm, arm, leg, leg pivots (a final model has none: it wiggles whole)
var _dance_anim: AnimationPlayer  ## the model's own dance, if it has one: one loop = EggAudio.BAR
var _music: AudioStreamPlayer3D
var _bones: Node3D  ## the station
var _turtles: Array[Node3D] = []
var _room: Node3D
var _room_center: Vector3
var _ghost_x := INF  ## last frame's x, to tell how the ghost got into the room
var _t := 0.0


func _ready() -> void:
	add_to_group("easter_eggs")
	_pedestal = get_parent().get_node("Stations/Pedestal")
	_bones = get_parent().get_node("Stations/Bones")
	_build_cat()
	_build_skeleton()
	_build_rat()
	_build_room()
	_hide_from_map(self)
	if Wall.model("Bones") == null:
		_build_pile()
	_bones._label.position.y = _bones.size.y / 2 + BONES_LABEL  # the pile is flat: keep its label close to it
	_hide_from_map(_bones)
	_hide_from_map(_pedestal)


func _process(delta: float) -> void:
	_t += delta
	_run_cat(delta)
	var ghost := GameState.player
	if ghost == null or GameState.phase != GameState.Phase.PLAY:
		return
	_dance(delta)
	_run_rat(ghost.global_position, delta)
	_update_room(ghost.global_position)
	for i in _turtles.size():
		_turtles[i].position.y = absf(sin(_t * 3.0 + i)) * 0.06  # chewing
	_ring_phone(ghost.global_position)


## A station of Kind.EGG was used (station.gd).
func touched(station_name: String) -> void:
	match station_name:
		"Pedestal":
			_open_pedestal()
		"Bones":
			_start_dance()


func _found(id: String, lines: Array) -> void:
	if id in found:
		return
	found.append(id)
	_say(lines + [["Пасхалка", "%d з %d" % [found.size(), EGGS.size()], UI.GOLD]])


func _say(lines: Array) -> void:
	for l in lines:
		if GameState.phase != GameState.Phase.PLAY:
			return
		GameState.say(l[0], l[1], l[2])
		await get_tree().create_timer(LINE_GAP, false).timeout


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# --- cat ---

func _build_cat() -> void:
	_cat = Node3D.new()
	_cat.position = Vector3(_pedestal.global_position.x, 0, _pedestal.global_position.z)
	add_child(_cat)
	_cat_cover = Node3D.new()  # what's on the pedestal? a heap of rags
	_cat_cover.position.y = CAT_TOP
	_cat.add_child(_cat_cover)
	var rag := Color(0.2, 0.17, 0.16)
	_part(_cat_cover, Vector3(0.5, 0.2, 0.46), rag, Vector3(0, 0.1, 0))
	_part(_cat_cover, Vector3(0.3, 0.16, 0.34), rag.lightened(0.08), Vector3(0.05, 0.27, -0.03))
	_cat_body = Node3D.new()
	_cat_body.position.y = CAT_TOP - 0.55
	_cat_body.visible = false
	_cat.add_child(_cat_body)
	if not _final_art(_cat_body, "Cat"):
		var fur := Color(0.85, 0.55, 0.25)
		_part(_cat_body, Vector3(0.28, 0.24, 0.5), fur, Vector3(0, 0.14, 0))
		_part(_cat_body, Vector3(0.26, 0.24, 0.24), fur, Vector3(0, 0.34, -0.26))
		_part(_cat_body, Vector3(0.07, 0.1, 0.05), fur, Vector3(-0.08, 0.5, -0.26))
		_part(_cat_body, Vector3(0.07, 0.1, 0.05), fur, Vector3(0.08, 0.5, -0.26))
		_part(_cat_body, Vector3(0.05, 0.05, 0.02), Color.BLACK, Vector3(-0.06, 0.38, -0.39))
		_part(_cat_body, Vector3(0.05, 0.05, 0.02), Color.BLACK, Vector3(0.06, 0.38, -0.39))
		_part(_cat_body, Vector3(0.05, 0.05, 0.36), fur, Vector3(0, 0.22, 0.4))
	_glow(_cat, Color(1, 0.7, 0.3), 4.5, 1.0)
	_cat_sound = _sound(_cat, "cat", 11.0)


## First E: the rags slide off, the cat rises, CAT_DELAY later it spins to its track. Every next E spins it again.
func _open_pedestal() -> void:
	if _cat_body.visible:
		if cat_wait < 0 and cat_spin <= 0:  # not while it is still spinning
			cat_wait = 0.0
		return
	_pedestal.shown = true  # stays solid, no "can't use" fade
	cat_wait = CAT_DELAY
	_cat_body.visible = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cat_body, "position:y", CAT_TOP, 0.9)
	tw.tween_property(_cat_cover, "position", Vector3(0.75, 0.0, 0.1), 0.5)
	tw.tween_property(_cat_cover, "rotation:z", -1.2, 0.5)


func _run_cat(delta: float) -> void:
	if cat_wait >= 0:
		cat_wait -= delta
		if cat_wait < 0:
			cat_spin = _cat_sound.stream.get_length()
			_cat_sound.play()
			_found("cat", [["Ти", "Кіт?.. Живий кіт?.. І чому він крутиться?", GameState.GHOST_COLOR]])
	elif cat_spin > 0:
		cat_spin -= delta
		_cat_body.rotation.y += CAT_SPIN * delta  # when it ends the cat just stays as it is
		if cat_spin <= 0:
			_cat_sound.stop()  # track and spin end together, ready for the next E


# --- skeleton ---

func _build_skeleton() -> void:
	_skeleton = Node3D.new()
	_skeleton.position = Vector3(_bones.global_position.x, 0, _bones.global_position.z)
	_skeleton.visible = false
	add_child(_skeleton)
	if not _final_art(_skeleton, "Skeleton"):
		var bone := Color(0.88, 0.85, 0.72)
		_part(_skeleton, Vector3(0.3, 0.3, 0.3), bone, Vector3(0, 1.55, 0))
		_part(_skeleton, Vector3(0.08, 0.08, 0.02), Color.BLACK, Vector3(-0.07, 1.58, -0.16))
		_part(_skeleton, Vector3(0.08, 0.08, 0.02), Color.BLACK, Vector3(0.07, 1.58, -0.16))
		_part(_skeleton, Vector3(0.1, 0.55, 0.1), bone, Vector3(0, 1.1, 0))
		for y in [1.28, 1.14, 1.0]:
			_part(_skeleton, Vector3(0.42, 0.05, 0.2), bone, Vector3(0, y, 0))
		_part(_skeleton, Vector3(0.34, 0.1, 0.16), bone, Vector3(0, 0.78, 0))
		for side in [-1, 1]:
			_limb(Vector3(0.26 * side, 1.3, 0), 0.55)
		for side in [-1, 1]:
			_limb(Vector3(0.12 * side, 0.74, 0), 0.72)
	var players := _skeleton.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_dance_anim = players[0]
		_dance_anim.assigned_animation = _dance_anim.get_animation_list()[0]
	var glow := _glow(self, Color(0.7, 0.4, 1), 4.5, 1.2)  # not on the skeleton: stays on while the bones lie still
	glow.position = _skeleton.position + Vector3(0, 1.7, 0)
	_music = _sound(self, "skeleton", 18.0)
	_music.position = _skeleton.position


## Placeholder pile in place of the station's box: a skull on scattered bones.
func _build_pile() -> void:
	_bones._mesh.visible = false
	var bone := Color(0.88, 0.85, 0.72)
	for b in [[0.6, 0.1, 0.5], [-0.18, -0.2, 2.1], [0.2, -0.08, -0.9], [-0.05, 0.22, 0.2], [0.26, 0.2, 1.3]]:
		var stick := _part(_bones, Vector3(0.07, 0.07, 0.62), bone, Vector3(b[0], -0.06, b[1]))
		stick.rotation.y = b[2]
	var skull := _part(_bones, Vector3(0.22, 0.2, 0.24), bone, Vector3(-0.12, 0.03, 0))
	skull.rotation.y = 0.5
	_part(skull, Vector3(0.05, 0.05, 0.02), Color.BLACK, Vector3(-0.05, 0.02, -0.12))
	_part(skull, Vector3(0.05, 0.05, 0.02), Color.BLACK, Vector3(0.05, 0.02, -0.12))


func _limb(pivot: Vector3, length: float) -> void:
	var p := Node3D.new()
	p.position = pivot
	_part(p, Vector3(0.07, length, 0.07), Color(0.88, 0.85, 0.72), Vector3(0, -length / 2, 0))
	_skeleton.add_child(p)
	_limbs.append(p)


func _start_dance() -> void:
	dancing = DANCE_TIME
	_skeleton.visible = true
	_skeleton.scale = Vector3(1, 0.1, 1)
	create_tween().tween_property(_skeleton, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_music.play()
	_bones.visible = false
	_bones.collision_layer = 0
	_found("skeleton", [["Ти", "Ні, це не мої кістки. Але ритм у них є.", GameState.GHOST_COLOR]])


func _dance(delta: float) -> void:
	if dancing <= 0:
		return
	dancing -= delta
	if _dance_anim:  # driven by the time since the music started, so it can't drift off the beat
		var loop := fmod(DANCE_TIME - dancing, EggAudio.BAR) / EggAudio.BAR
		_dance_anim.seek(loop * _dance_anim.get_animation(_dance_anim.assigned_animation).length, true)
	else:
		var beat := _t * TAU / (EggAudio.BEAT * 2.0)
		_skeleton.rotation.y = sin(beat * 0.5) * 0.7
		_skeleton.rotation.z = sin(beat) * 0.1
		for i in _limbs.size():
			var swing := sin(beat + PI * i)
			_limbs[i].rotation.z = swing * (1.8 if i < 2 else 0.4)
	if dancing <= 0:
		_music.stop()
		_skeleton.visible = false
		_bones.visible = true
		_bones.collision_layer = _bones.LAYER_STATION


# --- rat and the turtles' room ---

func _build_rat() -> void:
	_rat = Node3D.new()
	_rat.position = ROUTE[0]
	add_child(_rat)
	if not _final_art(_rat, "Rat"):
		var fur := Color(0.62, 0.58, 0.55)  # light, or it is lost on the dark floor
		_part(_rat, Vector3(0.14, 0.12, 0.3), fur, Vector3(0, 0.08, 0))
		_part(_rat, Vector3(0.09, 0.09, 0.12), fur, Vector3(0, 0.09, -0.19))
		_part(_rat, Vector3(0.025, 0.025, 0.3), Color(0.75, 0.55, 0.55), Vector3(0, 0.05, 0.3))
	_rat_sound = _sound(_rat, "rat", 12.0)


func _run_rat(ghost: Vector3, delta: float) -> void:
	if _rat_running:
		var next := _rat.position.move_toward(ROUTE[rat_i], RAT_SPEED * delta)
		var way := ROUTE[rat_i] - _rat.position
		if way.length() > 0.01:
			_rat.rotation.y = atan2(-way.x, -way.z)
		_rat.position = next
		_rat_running = next.distance_to(ROUTE[rat_i]) > 0.01
	elif rat_i < ROUTE.size() - 1 and _flat(ghost, _rat.position) < RAT_SCARE:
		rat_i += 1
		_rat_running = true
		_rat_sound.play()
	if _rat.position.x < ROOM.end.x:  # past the hole it lives in the room
		_rat.visible = _room.visible


## The room exists only for a ghost who came through the wall with the hole; from anywhere else it isn't there.
func _update_room(ghost: Vector3) -> void:
	var zone := Rect2(ROOM.position, Vector2(WALL_INNER - ROOM.position.x, ROOM.size.y))
	if not zone.has_point(Vector2(ghost.x, ghost.z)):
		_room.visible = false
	elif _ghost_x >= WALL_INNER:
		_room.visible = true
	_ghost_x = ghost.x
	if _room.visible and _flat(ghost, _room_center) < ROOM_NEAR:
		_found("turtles", [["Зелений", "Чуваче, ти ж привид. Тобі піца не положена.", ARCH_COLOR],
			["Ти", "…А що таке піца?", GameState.GHOST_COLOR]])


func _build_room() -> void:
	var hole := _part(self, Vector3(0.34, 0.32, 0.5), Color(0.01, 0.01, 0.01), Vector3(-8.65, 0.16, ROUTE[3].z))
	hole.name = "RatHole"  # not in the room: it shows from the R3L side
	var room := Node3D.new()
	room.visible = false
	add_child(room)
	_room = room
	var c := ROOM.get_center()
	_room_center = Vector3(c.x, 0, c.y)
	var brick := Color(0.3, 0.2, 0.17)
	var t := 0.2
	_part(room, Vector3(ROOM.size.x, ROOM_H, t), brick, Vector3(c.x, ROOM_H / 2, ROOM.position.y - t / 2))
	_part(room, Vector3(ROOM.size.x, ROOM_H, t), brick, Vector3(c.x, ROOM_H / 2, ROOM.end.y + t / 2))
	_part(room, Vector3(t, ROOM_H, ROOM.size.y + t * 2), brick, Vector3(ROOM.position.x - t / 2, ROOM_H / 2, c.y))
	_part(room, Vector3(1.0, 0.45, 1.0), Color(0.42, 0.28, 0.16), _room_center + Vector3(0, 0.225, 0))
	var pizza := Node3D.new()
	pizza.position = _room_center + Vector3(0, 0.45, 0)
	room.add_child(pizza)
	if not _final_art(pizza, "Pizza"):
		_disc(pizza, 0.42, 0.04, Color(0.92, 0.68, 0.25), Vector3(0, 0.02, 0))
		for i in 6:
			var a := i * TAU / 6.0
			_disc(pizza, 0.06, 0.012, Color(0.72, 0.13, 0.08), Vector3(cos(a) * 0.26, 0.045, sin(a) * 0.26))
	for i in TURTLE_MASKS.size():
		var a: float = i * TAU / TURTLE_MASKS.size() + PI / 4.0
		var seat := Node3D.new()  # bobs in _process; its parent keeps the place and the turn to the pizza
		var holder := Node3D.new()
		holder.position = _room_center + Vector3(cos(a), 0, sin(a)) * 1.05
		holder.rotation.y = atan2(cos(a), sin(a))
		room.add_child(holder)
		holder.add_child(seat)
		_turtles.append(seat)
		if not _final_art(seat, "Turtle"):
			_build_turtle(seat, TURTLE_MASKS[i])
	var light := _glow(room, Color(1, 0.72, 0.42), 6.5, 1.5)
	light.position = _room_center + Vector3(0, 2.3, 0)


## Faces -Z like the models do.
func _build_turtle(root: Node3D, mask: Color) -> void:
	var skin := Color(0.36, 0.62, 0.22)
	_part(root, Vector3(0.5, 0.65, 0.34), skin, Vector3(0, 0.62, 0))
	_part(root, Vector3(0.56, 0.7, 0.14), Color(0.3, 0.2, 0.08), Vector3(0, 0.64, 0.22))  # shell
	_part(root, Vector3(0.36, 0.34, 0.34), skin, Vector3(0, 1.12, 0))
	_part(root, Vector3(0.38, 0.09, 0.36), mask, Vector3(0, 1.16, 0))
	for side in [-1, 1]:
		_part(root, Vector3(0.16, 0.34, 0.2), skin, Vector3(0.16 * side, 0.17, 0))
		_part(root, Vector3(0.12, 0.12, 0.42), skin, Vector3(0.31 * side, 0.72, -0.2))


# --- air-raid alert: only a phone notification, a real siren in a game isn't funny here ---

func _ring_phone(ghost: Vector3) -> void:
	if "phone" in found or GameState.elapsed < phone_at or GameState.stage not in [GameState.Stage.HAUNT, GameState.Stage.LURE]:
		return
	var taras := get_parent().get_node_or_null("Visitors/Taras") as Node3D
	if taras == null or _flat(ghost, taras.global_position) > PHONE_NEAR:
		return
	_sound(taras, "phone", 12.0).play()
	_found("phone", [["Телефон Тараса", "Повітряна тривога. Прямуйте до найближчого укриття.", UI.ORANGE],
		["Тарас", "Олено, нам кудись іти?", ARCH_COLOR],
		["Олена", "Тарасе. Ми в підземеллі.", ARCH_COLOR],
		["Ти", "Зате тут завжди є вільні місця.", GameState.GHOST_COLOR]])


# --- helpers ---

## Put art/models/<model_name> under `parent`; false = no such file, build a placeholder.
func _final_art(parent: Node3D, model_name: String) -> bool:
	var ps := Wall.model(model_name)
	if ps == null:
		return false
	parent.add_child(ps.instantiate())
	return true


func _part(parent: Node3D, s: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var m := Wall.box(s, c)
	m.position = pos
	parent.add_child(m)
	return m


func _disc(parent: Node3D, radius: float, h: float, c: Color, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = h
	cyl.material = mat
	var m := MeshInstance3D.new()
	m.mesh = cyl
	m.position = pos
	parent.add_child(m)


func _glow(parent: Node3D, c: Color, reach: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = reach
	l.light_energy = energy
	l.position.y = 1.7
	parent.add_child(l)
	return l


func _sound(parent: Node3D, sound: String, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = EggAudio.stream(sound)
	p.max_distance = reach
	p.unit_size = reach / 3.0
	parent.add_child(p)
	return p


func _hide_from_map(n: Node) -> void:
	if n is VisualInstance3D and not n is Light3D:
		n.layers = LAYER_HIDDEN
	for c in n.get_children():
		_hide_from_map(c)
