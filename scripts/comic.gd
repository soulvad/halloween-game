extends CanvasLayer
## Comic player over the game. Two pages (scripts/comic_data.gd), drawn by scripts/comic_page.gd:
##   "prologue"  — two prologue pages, panels A..F appear one by one on each
##   "memory_N"  — that memory's own page, panel by panel; with no such page yet, the memories sheet: found memories
##                 (GameState.memories) shown, others locked, panel N (A..E) reveals
##   "finale"    — its own page, panel by panel
## Usage: var c = preload("res://scenes/comic.tscn").instantiate(); add_child(c); c.play("memory_2"); await c.finished
## E / Space / Enter / click = next panel (finish after the last one), Esc = skip all.

signal finished

const UI = preload("res://scripts/ui.gd")
const Data = preload("res://scripts/comic_data.gd")
const ComicPage = preload("res://scripts/comic_page.gd")
const SCREEN := Vector2(1920, 1080)  # base resolution (stretch mode canvas_items)
const MARGIN := 40.0
const MEMORY_LETTERS := "ABCDE"
const VOICE_TAIL := 0.4  # pause after a voice line before auto-advance

var _order: Array[String] = []  # letters to reveal, one per step
var _step := -1
var _auto := 0.0  # seconds left until auto-advance, 0 = wait for input
var _done := false
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE

var page: Control  # ComicPage
var _sub: PanelContainer
var _who: Label
var _text: Label
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	var root := UI.backdrop(Color("08060B"))
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind the comic gets clicks
	add_child(root)
	page = ComicPage.new()
	page.position = Vector2(MARGIN, MARGIN)
	page.size = SCREEN - Vector2(MARGIN, MARGIN) * 2
	add_child(page)
	_sub = UI.panel(UI.PAPER, 20, 7, 22)
	var col := UI.vbox(6)
	_who = UI.label("", 18, UI.LABEL, "body", 900, true)
	_text = UI.label("", 26, UI.INK, "body", 700)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_who)
	col.add_child(_text)
	_sub.add_child(col)
	_sub.visible = false
	add_child(_sub)
	var hint := UI.label("E — далі · Esc — пропустити", 18, UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size = Vector2(500, 30)
	hint.position = SCREEN - Vector2(500 + MARGIN, 30 + 12)
	add_child(hint)
	add_child(_voice)


func play(id: String) -> void:
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var n := id.trim_prefix("memory_").to_int() if id.begins_with("memory_") else 0
	if id == "prologue" or Data.PAGES.has(id):
		page.show_locked = false
		_open(id)
	elif n >= 1 and n <= MEMORY_LETTERS.length():
		page.setup("memories")
		for i in MEMORY_LETTERS.length():
			page.set_panel_state(MEMORY_LETTERS[i], i + 1 in GameState.memories and i + 1 != n)
		_order = [MEMORY_LETTERS[n - 1]]
	else:
		_finish.call_deferred()  # deferred: the caller has not reached `await finished` yet
		return
	# Subtitles in the right margin of the page.
	var r: Rect2 = page.page_rect()
	_sub.position = page.position + Vector2(r.end.x + MARGIN, r.size.y * 0.55)
	_text.custom_minimum_size.x = maxf(300, SCREEN.x - _sub.position.x - MARGIN - 44)  # 44 = panel padding
	_show(0)


func _input(event: InputEvent) -> void:
	if _done or _order.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == KEY_ESCAPE:
			_finish()
		elif key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			advance()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _auto > 0.0:
		_auto -= delta
		if _auto <= 0.0:
			advance()


## Next panel, or finish after the last one.
func advance() -> void:
	if _done:
		return
	if _step < _order.size() - 1:
		_show(_step + 1)
	elif Data.PAGES[page.page_id].has("next"):
		_open(Data.PAGES[page.page_id].next)
		_show(0)
	else:
		_finish()


## Turn to a page that plays all its panels.
func _open(id: String) -> void:
	page.setup(id)
	_order.assign(Data.PAGES[id].panels.keys())
	_step = -1


func _show(i: int) -> void:
	_step = i
	var letter := _order[i]
	page.reveal(letter)
	var p: Dictionary = Data.PAGES[page.page_id].panels[letter]
	var text: String = p.get("text", "")
	_sub.visible = text != "" and GameState.subtitles
	_who.text = p.get("who", "")
	_who.visible = _who.text != ""
	_text.text = text
	_sub.reset_size()  # shrink back after a longer line

	_voice.stop()
	_auto = 0.0
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/comic/%s/%s.%s" % [page.page_id, letter, ext]
		if ResourceLoader.exists(path):
			_voice.stream = load(path)
			_voice.play()
			_auto = _voice.stream.get_length() + VOICE_TAIL
			break
	if p.get("time", 0.0) > 0.0:
		_auto = p.time


func _finish() -> void:
	if _done:
		return
	_done = true
	_voice.stop()
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	finished.emit()
	queue_free()
