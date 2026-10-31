extends Node
## Headless: must print AMBIENT OK; if it hangs, an assert failed.

const Ambient = preload("res://scripts/ambient.gd")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	await _frames(3)
	var a = g.get_node("Ambient")
	var stage: int = GameState.stage

	# the loops really are the loops, and they play
	assert(a._bed.size() == Ambient.BED.size())
	for p in a._bed:
		assert(p.playing and p.stream is AudioStreamOggVorbis and p.stream.loop)

	# a crackle only by a lit candle, following its state
	assert(not a._candles.is_empty())
	for s in a._candles:
		assert(a._candles[s].playing == s.lit and a._candles[s].stream.loop)
	var candle = a._candles.keys()[0]
	candle.lit = not candle.lit
	await _frames(2)
	assert(a._candles[candle].playing == candle.lit)

	# one-shots: each file loads and doesn't loop, sounds at a distance, never the same twice in a row
	for sound in Ambient.ONE_SHOTS:
		assert(not a._stream(sound, false).loop)
	assert(not a._shot.playing)
	a.next_in = 0.0
	await _frames(2)
	assert(a._shot.playing and a.last in Ambient.ONE_SHOTS and a.next_in >= Ambient.WAIT_MIN)
	var dist: float = a._shot.position.distance_to(GameState.player.global_position)
	assert(dist >= Ambient.NEAR - 0.5 and dist <= Ambient.FAR + 0.5)
	for i in 20:
		var before: String = a.last
		a._play_one_shot(Vector3.ZERO)
		assert(a.last != before)

	# no effect on the story
	assert(GameState.stage == stage and GameState.haunts == 0)

	# memory calls: one per unfound memory 1–4, through walls, silenced once remembered; none for 5
	assert(not a._callers.has(5))
	var unfound: Array = [1, 2, 3, 4].filter(func(i): return i not in GameState.memories)
	assert(not unfound.is_empty())
	for i in unfound:
		var c: AudioStreamPlayer3D = a._callers[i]
		assert(c.stream != null and c.max_distance == Ambient.MEMORY_REACH)
		var t: Timer = c.get_child(0)
		assert(t.wait_time >= Ambient.CALL_MIN and t.wait_time <= Ambient.CALL_MAX and not t.is_stopped())
	var first: int = unfound[0]
	var caller: AudioStreamPlayer3D = a._callers[first]
	caller.get_child(0).timeout.emit()
	assert(caller.playing)
	GameState.remember(first)
	await _frames(2)
	assert(not a._callers.has(first) and not is_instance_valid(caller))
	for i in unfound.slice(1):
		assert(a._callers.has(i))

	# the end: everything fades away
	a._on_finished(true)
	await get_tree().create_timer(Ambient.FADE_OUT + 0.3).timeout
	assert(is_equal_approx(a._bed[0].volume_db, -60.0))
	g.queue_free()
	await _frames(2)
	print("AMBIENT OK")
	get_tree().quit()
