extends Node
## Autoload: the dungeon story. A servant boy (Тиміш) was walled up in the count's dungeon and forgot who he was.
## Linear, no resources, no way to lose. Memories (touch a glint) give powers; with them the ghost steers the living:
## HAUNT «Помітьте мене»: memories 1–3, noises/candles lead archaeologists, write ДОПОМОЖІТЬ on the mirror →
## PRIEST_COMING → LURE «Знайдіть мою кімнату»: push the plan, memory 4 (hands), open the door, knock 3–1 on the wall →
## DIG → EVIDENCE: show your things, memory 5 (your name) → RITUAL: the priest prays, hold E in the circle → finale.

signal finished(won: bool)
signal said(who: String, text: String, color: Color)  ## subtitles (HUD)
signal hint_unlocked(id: String)  ## a new page in the book (HUD)
signal stage_changed(stage: int)
signal haunted(pos: Vector3, power: float)  ## a noise / light change; visitors in earshot react
signal memory_found(id: int)  ## game.gd plays the memory comic, HUD updates
signal power_gained(power: String)

enum Phase { PLAY, END }
## Stage names kept from the first dungeon draft: HAUNT = «Помітьте мене», LURE = «Знайдіть мою кімнату», EVIDENCE = your room.
enum Stage { HAUNT, PRIEST_COMING, LURE, DIG, EVIDENCE, RITUAL }

const EVIDENCE_NEEDED := 3
const MEMORY_COUNT := 5
const POWERS := ["breath", "sound", "write", "hands"]
const POWER_NAMES := {"breath": "Подих", "sound": "Поштовх і звук", "write": "Письмо", "hands": "Сила рук"}
const POWER_HELP := {
	"breath": "гасити й запалювати свічки",
	"sound": "брязкати металом, штовхати дрібні речі",
	"write": "писати слова на пилу й склі",
	"hands": "відчиняти двері, стукати в стіну",
}
const MEMORY_POWER := {1: "breath", 2: "sound", 3: "write", 4: "hands"}  ## memory 5 gives your name, no power
const MEMORY_TITLES := {1: "Пташка", 2: "Сімнадцятий", 3: "Лист від матері", 4: "Ключ від хвіртки", 5: "Ім'я на стіні"}
const GHOST_COLOR := Color("9BF6FF")
## Book hints, unlocked once per round by hint(id). Add new ones here and call hint() where they happen.
const HINTS := {
	"start": "Ти нічого не пам'ятаєш. Шукай мерехтіння в темряві й торкайся їх (E) — так повертаються спогади.",
	"memory": "Кожен спогад повертає силу. Подивись, що нового ти вмієш.",
	"haunt": "Археологи йдуть на звук і на світло, що змінилося. Так їх і ведеш — крок за кроком.",
	"mirror": "Ти вмієш писати. Приведи археолога до запиленого дзеркала й напиши на ньому (E).",
	"priest": "Археологи кличуть священника. Він прийде до входу й ходитиме за ними.",
	"lure": "На столі археологів лежить план маєтку. Зсунь його (E) — хай побачать, що однієї кімнати на плані бракує.",
	"door": "Двері до твого коридору зачинені. Сила рук відчиняє двері.",
	"knock": "Простукай стіну так, як ви стукали з Ганнусею: три удари, пауза, один (E E E … E). Хтось має бути поруч.",
	"dig": "Археологи розбирають стіну. Ще трохи — і вони побачать твою кімнату.",
	"evidence": "Покажи їм свої речі (E), коли вони поруч: кайдани, подряпини-дні, миску. І торкнися напису на стіні.",
	"ritual": "Священник молиться в колі. Коли закінчить — стань у коло й утримуй E.",
}

var phase := Phase.PLAY
var won := false
var stage := Stage.HAUNT
var memories: Array[int] = []  ## memory ids found, in order
var powers: Array[String] = []
var mirror_written := false
var plan_moved := false  ## LURE: the plan on the archaeologists' table shows the missing room
var wall_knocked := false  ## LURE: the code 3–1 knocked on the bricked wall for a witness
var dig := 0.0  ## DIG progress 0..1
var evidence := 0  ## pieces of evidence shown
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
	plan_moved = false
	wall_knocked = false
	dig = 0.0
	evidence = 0
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


## Touching a memory glint: remember it, gain its power. game.gd shows the comic on memory_found.
func remember(id: int) -> void:
	if id in memories:
		return
	memories.append(id)
	var p: String = MEMORY_POWER.get(id, "")
	if p != "" and p not in powers:
		powers.append(p)
		power_gained.emit(p)
	memory_found.emit(id)
	hint("memory")
	if p == "write":
		hint("mirror")


func set_stage(s: Stage) -> void:
	if s == stage:
		return
	stage = s
	stage_changed.emit(s)
	hint(["haunt", "priest", "lure", "dig", "evidence", "ritual"][s])


## The whole story as goal steps, in order: [{text, done}]. The first not-done step is the active one;
## the book shows done + active and locks the rest.
func goal_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for st in [
		["Ти нічого не пам'ятаєш. Знайди мерехтіння в темряві й торкнися його", memories.size() >= 1],
		["Шукай ще спогади. Свічки й шум приводять археологів", has_power("write")],
		["Приведи археолога до дзеркала й напиши на ньому", mirror_written],
		["Археологи кличуть священника — зачекай", stage > Stage.PRIEST_COMING],
		["Зсунь план на столі археологів — покажи, де твоя кімната", plan_moved],
		["Двері зачинені. Знайди ще один спогад", has_power("hands")],
		["Відчини двері й простукай стіну: три удари, пауза, один", wall_knocked],
		["Археологи розбирають стіну до твоєї кімнати", stage > Stage.DIG],
		["Покажи їм свої речі (%d/%d)" % [evidence, EVIDENCE_NEEDED], evidence >= EVIDENCE_NEEDED],
		["Торкнися напису на стіні", name_known()],
		["Священник проводить ритуал", ritual >= 1.0],
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


## A noise or light change at `pos`; visitors in earshot react (visitor.gd).
func haunt(pos: Vector3, power := 1.0) -> void:
	haunts += 1
	haunted.emit(pos, power)


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

