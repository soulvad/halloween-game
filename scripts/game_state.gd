extends Node
## Autoload: ghost state (visibility level, spirit charge, fade) + the dungeon story (stages, unease, dig, evidence, ritual).
## Charge is fuel: the altar (your bones) needs a threshold, every level above 1 burns charge each second.
## Story: a servant died in the count's dungeon and can't leave. Archaeologists come. Haunt them until they call
## a priest, lure everyone to your sealed room, they dig through the rubble, see the evidence, the priest holds
## a ritual, and at level 3 you hold E in the circle to leave. Linear, no way to lose.

signal visibility_changed  ## level changed or fade started/ended
signal banished  ## knocked out at level 1: back to the spawn
signal finished(won: bool)
signal said(who: String, text: String, color: Color)  ## subtitles (HUD)
signal altar_requested  ## E at the altar: the HUD opens the altar modal, which calls level_up()
signal hint_unlocked(id: String)  ## a new page in the book (HUD)
signal stage_changed(stage: int)
signal haunted(pos: Vector3, power: float)  ## a haunt object made noise; visitors in earshot react

enum Phase { PLAY, END }
## HAUNT: scare the archaeologists (unease) · PRIEST_COMING: they called him · LURE: lead the group to the rubble
## DIG: they clear it · EVIDENCE: show them your room · RITUAL: the priest frees you (then hold E in the circle).
enum Stage { HAUNT, PRIEST_COMING, LURE, DIG, EVIDENCE, RITUAL }

const MAX_LEVEL := 3
const MAX_CHARGE := 10.0
const LEVEL_REQ := { 2: 4.0, 3: 8.0 }  ## charge needed at the altar (not spent)
const UPKEEP := [0.0, 0.0, 0.05, 0.25]  ## charge per second by level; at 0 the level drops
const FADE_COST := 2.0
const FADE_TIME := 4.0
const HIT_GRACE := 2.0  ## after a knock: nothing hurts
const HOLY_DRAIN := 2.0  ## charge per second on holy ground (the priest's aura)
const UNEASE_TO_CALL := 8.0  ## archaeologists call the priest at this much unease
const EVIDENCE_NEEDED := 3
const LEVEL_NAMES := ["", "Тінь", "Відлуння", "Присутність"]
const HURT_SHOW := 0.3  ## seconds the HUD shows "hurt" after the last drain
const GHOST_COLOR := Color("9BF6FF")
## Goal line per stage (HUD goal panel, book).
const STAGE_GOALS := [
	"Налякай археологів: шуми предметами поруч із ними",
	"Археологи кличуть священника — зачекай біля входу",
	"Заведи всіх до завалу: шуми предметами, і вони підуть на звук",
	"Археологи розкопують завал до твоєї кімнати",
	"Покажи їм докази: підсвіти речі у своїй кімнаті (рівень 2)",
	"Священник проводить ритуал. Стань Присутністю й утримуй E у колі",
]
## Book hints, unlocked once per round by hint(id). Add new ones here and call hint() where they happen.
const HINTS := {
	"start": "Спіритичні речі (фіолетові) дають заряд: E біля них, потім вони відпочивають. Твої кістки — вівтар: там піднімаєш видимість.",
	"haunt": "Помаранчеві речі можна змусити шуміти (E, 1 заряд). Люди поруч чують і йдуть подивитися — так їх і ведеш.",
	"holy": "Святе світло пече навіть тінь: тримайся трохи осторонь священника.",
	"level2": "Тепер люди можуть тебе побачити — це лякає їх ще більше. Важкі речі (ґрати, скриня) шумлять сильніше.",
	"sprint": "Shift — спринт: швидше, але витрачає заряд.",
	"knock": "Заряд упав до нуля: ти слабшаєш на рівень. На першому рівні тебе відкине до твоїх кісток.",
	"priest": "Священник іде! Його світло пече — не підлітай впритул. Він ходить за археологами.",
	"lure": "Веди групу: шуми предметами все ближче до завалу у верхньому правому коридорі. Біля завалу — «Стук за завалом».",
	"dig": "Археологи розкопують завал. Ще трохи — і вони побачать твою кімнату.",
	"evidence": "Підсвіти докази (E, рівень 2), коли люди поруч: кайдани, дні на стіні, миска з ім'ям.",
	"level3": "Ти Присутність: тебе бачать усі. Тільки так ритуал може тебе відпустити.",
	"ritual": "Ритуал завершено. Стань у коло й утримуй E — і ти нарешті підеш.",
}

var phase := Phase.PLAY
var level := 1
var charge := 0.0
var fade_left := 0.0  ## > 0: nobody sees the ghost, it passes every inner wall
var grace := 0.0
var won := false
var hurt := 0.0  ## > 0: just lost charge to `hurt_by`
var hurt_by := ""  ## "holy" (or "hunter" from the old house level)
var stage := Stage.HAUNT
var unease := 0.0  ## HAUNT: grows when visitors hear haunts / see the ghost
var lure_pos := Vector3.INF  ## last haunt the group should walk to (LURE)
var dig := 0.0  ## DIG progress 0..1
var evidence := 0  ## pieces of evidence shown
var ritual := 0.0  ## RITUAL progress 0..1
# Stats for the end screen.
var elapsed := 0.0
var gathered := 0.0  ## charge ever gained
var haunts := 0  ## noises made
var peak_level := 1
var hints: Array[String] = []  ## unlocked hint ids, oldest first
var player: Node3D  ## set by the player on spawn

# Settings (session only, not reset between rounds). shortcut: not saved to disk; add ConfigFile if needed.
var show_labels := true  ## labels above items and people
var subtitles := true


func reset() -> void:
	phase = Phase.PLAY
	level = 1
	charge = 0.0
	fade_left = 0.0
	grace = 0.0
	won = false
	hurt = 0.0
	hurt_by = ""
	stage = Stage.HAUNT
	unease = 0.0
	lure_pos = Vector3.INF
	dig = 0.0
	evidence = 0
	ritual = 0.0
	elapsed = 0.0
	gathered = 0.0
	haunts = 0
	peak_level = 1
	hints.clear()
	visibility_changed.emit()


func _process(delta: float) -> void:
	grace = maxf(grace - delta, 0)
	hurt = maxf(hurt - delta, 0)
	if phase == Phase.PLAY:
		elapsed += delta
	if fade_left > 0:
		fade_left -= delta
		if fade_left <= 0:
			visibility_changed.emit()
	if phase == Phase.PLAY and level > 1:
		charge -= UPKEEP[level] * delta
		if charge <= 0:
			charge = 0.0
			set_level(level - 1)


func is_fading() -> bool:
	return fade_left > 0


## Someone with this sight level notices the ghost right now.
func visible_to(sees_from: int) -> bool:
	return not is_fading() and level >= sees_from


func add_charge(v: float) -> void:
	var before := charge
	charge = clampf(charge + v, 0, MAX_CHARGE)
	gathered += maxf(charge - before, 0)


func set_stage(s: Stage) -> void:
	if s == stage:
		return
	stage = s
	stage_changed.emit(s)
	hint(["haunt", "priest", "lure", "dig", "evidence", "ritual"][s])


func goal() -> String:
	if stage == Stage.RITUAL and ritual >= 1.0 and level < MAX_LEVEL:
		return "Ритуал готовий — стань Присутністю (рівень 3) і утримуй E у колі"
	return STAGE_GOALS[stage]


## A haunt object made noise at `pos`; visitors in earshot react (visitor.gd).
func haunt(pos: Vector3, power: float) -> void:
	haunts += 1
	lure_pos = pos
	haunted.emit(pos, power)


## The ritual is done and the ghost is fully visible: hold E in the circle to leave (game.gd).
func release_ready() -> bool:
	return stage == Stage.RITUAL and ritual >= 1.0 and level >= MAX_LEVEL


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


func can_level_up() -> bool:
	return level < MAX_LEVEL and charge >= LEVEL_REQ[level + 1]


func level_up() -> bool:
	if not can_level_up():
		return false
	set_level(level + 1)
	return true


func set_level(l: int) -> void:
	level = clampi(l, 1, MAX_LEVEL)
	peak_level = maxi(peak_level, level)
	if level >= 2:
		hint("level%d" % level)
		hint("sprint")
	visibility_changed.emit()


## Spend charge to turn invisible for a while (holy ground still burns).
func fade(time := FADE_TIME, cost := FADE_COST) -> bool:
	if is_fading() or charge < cost:
		return false
	charge -= cost
	fade_left = time
	visibility_changed.emit()
	return true


## Holy ground. Empty charge = lose a level (at level 1: banished to spawn).
func drain(v: float, by := "holy") -> void:
	if grace > 0 or phase != Phase.PLAY:
		return
	charge -= v
	hurt = HURT_SHOW
	hurt_by = by
	if by == "holy":
		hint("holy")
	if charge > 0:
		return
	charge = 0.0
	grace = HIT_GRACE
	fade_left = HIT_GRACE
	hint("knock")
	if level == 1:
		banished.emit()
	set_level(level - 1)


## Holy ground around `pos` (the priest) burns the ghost inside `radius`.
func burn_near(pos: Vector3, radius: float, delta: float) -> void:
	if player and Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() < radius:
		drain(HOLY_DRAIN * delta, "holy")


func finish(did_win: bool) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	won = did_win
	finished.emit(did_win)
