extends Node
## Autoload: the dungeon story. A servant boy (Тиміш) was walled up in the count's dungeon and forgot who he was.
## Linear, no resources, no way to lose. Memories give powers; with them the ghost steers the living:
## HAUNT «Помітьте мене»: touch memory 1; memories 2–4 an archaeologist finds when lured there with the previous power
## (candle, noise, writing in the dust); write ДОПОМОЖІТЬ on the mirror → PRIEST_COMING → SEARCH (time-lapse cutscene:
## they search, find the plan, clear the collapsed wall) → EVIDENCE: they look over your room and read your name
## (memory 5), you knock 3–1 → RITUAL: the priest prays, hold E in the circle → finale.

signal finished(won: bool)
signal said(who: String, text: String, color: Color)  ## subtitles (HUD)
signal hint_unlocked(id: String)  ## a new page in the book (HUD)
signal stage_changed(stage: int)
signal haunted(pos: Vector3, power: float, by: String)  ## a noise / light change made with power `by`; visitors in earshot react
signal memory_found(id: int)  ## game.gd plays the memory comic, HUD updates
signal power_gained(power: String)

enum Phase { PLAY, END }
## HAUNT = «Помітьте мене», SEARCH = the time-lapse cutscene, EVIDENCE = your room.
enum Stage { HAUNT, PRIEST_COMING, SEARCH, EVIDENCE, RITUAL }

const MEMORY_COUNT := 5
const POWERS := ["breath", "sound", "write", "hands"]
const POWER_NAMES := {"breath": "Подих", "sound": "Поштовх і звук", "write": "Письмо", "hands": "Сила рук"}
const POWER_HELP := {
	"breath": "гасити й запалювати свічки",
	"sound": "брязкати металом, штовхати дрібні речі",
	"write": "писати слова на пилу й склі",
	"hands": "стукати в стіну",
}
const MEMORY_POWER := {1: "breath", 2: "sound", 3: "write", 4: "hands"}  ## memory 5 gives your name, no power
const MEMORY_TITLES := {1: "Пташка", 2: "Сімнадцятий", 3: "Лист від матері", 4: "Ключ від хвіртки", 5: "Ім'я на стіні"}
const GHOST_COLOR := Color("9BF6FF")
## Book hints, unlocked once per round by hint(id). Add new ones here and call hint() where they happen.
const HINTS := {
	"start": "Ти нічого не пам'ятаєш. Шукай мерехтіння в темряві й торкнися його (E) — так повертаються спогади.",
	"memory": "Кожен спогад повертає силу. Подивись, що нового ти вмієш.",
	"find": "Наступну твою річ ти бачиш, але взяти не можеш — її мають знайти живі. Приведи туди археолога силою, яку щойно згадав.",
	"haunt": "Археологи йдуть на звук і на світло, що змінилося. Так їх і ведеш — крок за кроком.",
	"mirror": "Руки знову слухаються. Приведи археолога до запиленого дзеркала й напиши на ньому (E).",
	"priest": "Археологи кличуть священника. Він прийде до входу.",
	"search": "Минають години: люди обшукують підземелля.",
	"evidence": "Вони в твоїй кімнаті. Дай їм усе роздивитися.",
	"knock": "Простукай стіну так, як ви стукали з Ганнусею: три удари, пауза, один (E E E … E). Хтось має бути в кімнаті.",
	"ritual": "Священник молиться в колі. Коли закінчить — стань у коло й утримуй E.",
}

var phase := Phase.PLAY
var won := false
var stage := Stage.HAUNT
var memories: Array[int] = []  ## memory ids found, in order
var powers: Array[String] = []
var mirror_written := false
var evidence := 0  ## EVIDENCE: things in your room the archaeologists have looked at
var wall_knocked := false  ## EVIDENCE: the code 3–1 knocked for someone in your room
var ritual := 0.0  ## RITUAL progress 0..1
var intro_seen := false  ## prologue comic shown this session (not reset between rounds)
# Stats for the end screen.
var elapsed := 0.0
var haunts := 0  ## noises / light changes made
var hints: Array[String] = []  ## unlocked hint ids, oldest first
var player: Node3D  ## set by the player on spawn

# Settings (session only, not reset between rounds). shortcut: not saved to disk; add ConfigFile if needed.
var show_labels := true  ## labels above items and people
var subtitles := true


func reset() -> void:
	phase = Phase.PLAY
	won = false
	stage = Stage.HAUNT
	memories.clear()
	powers.clear()
	mirror_written = false
	evidence = 0
	wall_knocked = false
	ritual = 0.0
	elapsed = 0.0
	haunts = 0
	hints.clear()


func _process(delta: float) -> void:
	if phase == Phase.PLAY:
		elapsed += delta


func has_power(p: String) -> bool:
	return p in powers


func name_known() -> bool:
	return 5 in memories


## Touching a memory glint: remember it. game.gd shows the comic on memory_found, then calls gain() with its power.
func remember(id: int) -> void:
	if id in memories:
		return
	memories.append(id)
	memory_found.emit(id)
	hint("memory")
	if id < 4:
		hint("find")


## The memory's power, once its comic is over (game.gd _on_memory_found).
func gain(p: String) -> void:
	if p == "" or p in powers:
		return
	powers.append(p)
	power_gained.emit(p)
	if p == "hands":  # the mirror opens with the last power (station.gd _mirror_ready)
		hint("mirror")


func set_stage(s: Stage) -> void:
	if s == stage:
		return
	stage = s
	stage_changed.emit(s)
	hint(["haunt", "priest", "search", "evidence", "ritual"][s])


## The whole story as goal steps, in order: [{text, done}]. The first not-done step is the active one;
## the book shows done + active and locks the rest.
func goal_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for st in [
		["Холодно й темно… Там щось мерехтить. Може, воно моє?", memories.size() >= 1],
		["Там лежить щось моє, але я не можу його взяти. Хай знайдуть живі — посвічу їм", memories.size() >= 2],
		["Ще одна моя річ… Треба, щоб вони почули, де вона", memories.size() >= 3],
		["Остання річ схована в комірчині. Вони мають прочитати, де шукати", memories.size() >= 4],
		["Мене ніхто не чує. Треба попросити про допомогу так, щоб побачили", mirror_written],
		["Вони кличуть когось на допомогу…", stage > Stage.PRIEST_COMING],
		["Вони шукають. Минають години…", stage > Stage.SEARCH],
		["Вони в моїй кімнаті. Хай побачать усе", name_known()],
		["Я тут. Дай їм знак, як колись Ганнусі", wall_knocked],
		["Священник молиться за мене", ritual >= 1.0],
		["Стань у коло й утримуй E — час іти", won],
	]:
		steps.append({"text": st[0], "done": st[1]})
	return steps


## The active goal line.
func goal() -> String:
	for st in goal_steps():
		if not st.done:
			return st.text
	return "Ти вільний"


## A noise or light change at `pos`, made with power `by`; visitors in earshot react (visitor.gd).
func haunt(pos: Vector3, power := 1.0, by := "") -> void:
	haunts += 1
	haunted.emit(pos, power, by)


## The ritual is done: hold E in the circle to leave (game.gd).
func release_ready() -> bool:
	return stage == Stage.RITUAL and ritual >= 1.0


## Unlock a book hint once per round; returns true the first time.
func hint(id: String) -> bool:
	if id in hints or not HINTS.has(id):
		return false
	hints.append(id)
	hint_unlocked.emit(id)
	return true


func say(who: String, text: String, color := Color.WHITE) -> void:
	said.emit(who, text, color)


## The ghost's own line.
func think(text: String) -> void:
	say("Ти", text, GHOST_COLOR)


func finish(did_win: bool) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	won = did_win
	finished.emit(did_win)

