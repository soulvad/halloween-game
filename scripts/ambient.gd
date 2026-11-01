extends Node3D
## Dungeon ambience, doesn't touch the story. Two quiet loops everywhere (air, a deep drone), water dripping in two
## rooms, a crackle by every lit candle and, now and then, a sound somewhere near the ghost. Files: audio/ambient/.
## Pauses with the tree during comics and menus, fades out at the end. Added by game.gd.
## «Голос спогаду»: every memory 1–4 not yet found calls from its station every 8–12 s, heard through walls
## (no occlusion), until GameState.memory_found fires for it. Files: audio/memory/memory_<id>.ogg|wav.

const Fx = preload("res://scripts/fx.gd")
const DIR := "res://audio/ambient/"
const BED := {"air": -8.0, "deep": -10.0}  ## looped everywhere: file → volume dB
const DRIPS: Array[Vector3] = [Vector3(-13, 1, -6), Vector3(8, 1, 7)]
const DRIP_DB := -2.0
const DRIP_REACH := 12.0
const CANDLE_DB := -6.0
const CANDLE_REACH := 4.0
const ONE_SHOTS := ["moan", "whisper", "creak", "rumble", "stones"]
const ONE_SHOT_DB := -3.0
const ONE_SHOT_REACH := 16.0
const NEAR := 6.0  ## a one-shot sounds this far from the ghost, up to FAR
const FAR := 10.0
const WAIT_MIN := 25.0  ## seconds between one-shots
const WAIT_MAX := 60.0
const FADE_OUT := 3.0
const MEMORY_DIR := "res://audio/memory/"
## memory id → [ambient file, pitch] while audio/memory/ has no own file: whistle, tag on shackles, paper, keys
const MEMORY_FALLBACK := {1: ["whisper", 1.5], 2: ["creak", 1.8], 3: ["stones", 0.8], 4: ["creak", 2.6]}
const MEMORY_DB := -8.0
const MEMORY_REACH := 25.0
const CALL_MIN := 8.0  ## seconds between a memory's calls
const CALL_MAX := 12.0

var next_in := 20.0  ## seconds until the next one-shot (the test shortens it)
var last := ""  ## the last one-shot, never twice in a row
var _bed: Array[AudioStreamPlayer] = []
var _candles := {}  ## station → its crackle
var _shot: AudioStreamPlayer3D
var _callers := {}  ## memory id → its calling player, until remembered


func _ready() -> void:
	for sound in BED:
		var p := AudioStreamPlayer.new()
		p.stream = _stream(sound, true)
		p.volume_db = BED[sound] + Fx.MIX_DB
		p.autoplay = true
		add_child(p)
		_bed.append(p)
	for at in DRIPS:
		var p := _emitter(_stream("drips", true), DRIP_DB, DRIP_REACH)
		p.position = at
		p.autoplay = true
	for s in get_parent().get_node("Stations").get_children():
		if s.kind == s.Kind.CANDLE:
			var p := _emitter(_stream("candle", true), CANDLE_DB, CANDLE_REACH)
			p.position = s.global_position
			_candles[s] = p
		# key off memory_id only: the rework shows memory sites before they can be touched
		elif s.kind == s.Kind.MEMORY and s.memory_id in MEMORY_FALLBACK and s.memory_id not in GameState.memories:
			_callers[s.memory_id] = _caller(s.memory_id, s.global_position)
	_shot = _emitter(null, ONE_SHOT_DB, ONE_SHOT_REACH)
	GameState.finished.connect(_on_finished)
	GameState.memory_found.connect(_on_memory_found)


func _process(delta: float) -> void:
	for s in _candles:
		if _candles[s].playing != s.lit:
			_candles[s].playing = s.lit
	if GameState.phase != GameState.Phase.PLAY or GameState.player == null:
		return
	next_in -= delta
	if next_in <= 0 and not _shot.playing:
		next_in = randf_range(WAIT_MIN, WAIT_MAX)
		_play_one_shot(GameState.player.global_position)


func _play_one_shot(ghost: Vector3) -> void:
	var sound: String = ONE_SHOTS.filter(func(n): return n != last).pick_random()
	last = sound
	_shot.stream = _stream(sound, false)
	_shot.position = ghost + Vector3(randf_range(NEAR, FAR), 0, 0).rotated(Vector3.UP, randf() * TAU)
	_shot.play()


func _caller(id: int, at: Vector3) -> AudioStreamPlayer3D:
	var p := _emitter(null, MEMORY_DB, MEMORY_REACH)
	p.position = at
	for ext in ["ogg", "wav"]:
		var path := "%smemory_%d.%s" % [MEMORY_DIR, id, ext]
		if ResourceLoader.exists(path):
			p.stream = load(path)
	if p.stream == null:
		p.stream = _stream(MEMORY_FALLBACK[id][0], false)
		p.pitch_scale = MEMORY_FALLBACK[id][1]
	var t := Timer.new()
	t.wait_time = randf_range(CALL_MIN, CALL_MAX)
	t.autostart = true
	t.timeout.connect(func():
		p.play()
		t.wait_time = randf_range(CALL_MIN, CALL_MAX))
	p.add_child(t)
	return p


func _on_memory_found(id: int) -> void:
	if _callers.has(id):
		_callers[id].queue_free()
		_callers.erase(id)


func _on_finished(_won: bool) -> void:
	var tw := create_tween().set_parallel()
	for p in find_children("*", "AudioStreamPlayer", false, false) + find_children("*", "AudioStreamPlayer3D", false, false):
		tw.tween_property(p, "volume_db", -60.0, FADE_OUT)


func _stream(sound: String, loop: bool) -> AudioStream:
	var s: AudioStream = load("%s%s.ogg" % [DIR, sound])
	s.loop = loop
	return s


func _emitter(stream: AudioStream, db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = reach
	p.unit_size = reach / 3.0
	Fx.tame(p)
	add_child(p)
	return p
