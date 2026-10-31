extends Node
## Headless: plays every comic by simulated input, checks panel states, `finished` and that the tree is unpaused after.
## Prints COMIC OK. Windowed with `-- <dir>`: saves a PNG of each comic instead of testing.

const Data = preload("res://scripts/comic_data.gd")
const Comic = preload("res://scenes/comic.tscn")
const IDS := ["prologue", "memory_1", "memory_2", "memory_3", "memory_4", "memory_5", "finale"]


func _ready() -> void:
	var shot := OS.get_cmdline_user_args()
	if not shot.is_empty():
		for id: String in IDS:
			_found(id)
			var c := _start(id)
			for i in 5:
				if id == "prologue":
					c.advance()
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shot[0], id])
			c._finish()
		get_tree().quit()
		return

	for id: String in IDS:
		_found(id)
		var c := _start(id)
		var state := {"done": false}
		c.finished.connect(func(): state.done = true)
		assert(get_tree().paused, "%s: tree not paused" % id)
		var presses := 6 if id == "prologue" else 1
		if id.begins_with("memory_"):
			var n := id.to_int()
			for i in 5:
				var shown: bool = c.page.is_shown("ABCDE"[i])
				assert(shown == (i + 1 < n), "%s: panel %s shown=%s" % [id, "ABCDE"[i], shown])
			assert(not c.page.is_shown("F"))
		if id == "finale":
			for l in "ABCDE":
				assert(c.page.is_shown(l), "finale: %s locked" % l)
		await get_tree().create_timer(0.8).timeout  # reveal tween
		var last: String = c._order[0]
		assert(c.page.is_shown(last), "%s: %s not revealed" % [id, last])
		for i in presses:
			assert(not state.done, "%s: finished early at press %d" % [id, i])
			_key(KEY_E if i % 2 == 0 else KEY_SPACE)
			await get_tree().process_frame
		assert(state.done, "%s: not finished after %d presses" % [id, presses])
		assert(not get_tree().paused, "%s: tree still paused" % id)
		print("  %s ok" % id)

	# Click advances; `time` / voice length auto-advances; Esc skips everything.
	var c := _start("prologue")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	get_viewport().push_input(ev)
	assert(c._step == 1, "click did not advance")
	c._auto = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	assert(c._step == 2, "auto-advance did not fire")
	_key(KEY_ESCAPE)
	assert(c._done and not get_tree().paused, "Esc did not skip")

	# Unknown id finishes on its own (deferred, so `await finished` works).
	c = _start("nope")
	await c.finished
	assert(not get_tree().paused)

	# Book embedding: page without the player.
	var p: Control = preload("res://scripts/comic_page.gd").new()
	p.size = Vector2(400, 300)
	add_child(p)
	p.setup("memories")
	p.set_panel_state("B", true)
	assert(p.is_shown("B") and not p.is_shown("A"))
	assert(is_equal_approx(p.page_rect().size.y, 300.0))
	p.free()

	GameState.memories.clear()
	await get_tree().process_frame
	print("COMIC OK")
	get_tree().quit()


## Memories found before this comic plays (game_state appends the memory before game.gd plays its comic).
func _found(id: String) -> void:
	GameState.memories.clear()
	var n := 5 if id == "finale" else id.to_int() if id.begins_with("memory_") else 0
	for i in n:
		GameState.memories.append(i + 1)


func _start(id: String) -> Node:
	var c := Comic.instantiate()
	add_child(c)
	c.play(id)
	return c


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	get_viewport().push_input(ev)
