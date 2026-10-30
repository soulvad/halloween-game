extends Node
## Autoload: ghost state (visibility level, spirit charge, fade) + round phase.

signal visibility_changed  ## level changed or fade started/ended
signal finished(won: bool)

enum Phase { PLAY, END }

const ROUND_TIME := 300.0  ## seconds until midnight
const MAX_LEVEL := 3
const MAX_CHARGE := 10.0
const LEVEL_COST := { 2: 4.0, 3: 6.0 }  ## charge spent at the altar to reach this level
const FADE_COST := 2.0
const FADE_TIME := 4.0
const HIT_GRACE := 2.0  ## free fade after a hunter knocks a level off
const LEVEL_NAMES := ["", "Тінь", "Відлуння", "Присутність"]

var phase := Phase.PLAY
var level := 1
var charge := 0.0
var fade_left := 0.0  ## > 0: nobody sees the ghost, it passes every inner wall
var won := false


func reset() -> void:
	phase = Phase.PLAY
	level = 1
	charge = 0.0
	fade_left = 0.0
	won = false
	visibility_changed.emit()


func _process(delta: float) -> void:
	if fade_left > 0:
		fade_left -= delta
		if fade_left <= 0:
			visibility_changed.emit()


func is_fading() -> bool:
	return fade_left > 0


## Someone with this sight level notices the ghost right now.
func visible_to(sees_from: int) -> bool:
	return not is_fading() and level >= sees_from


func add_charge(v: float) -> void:
	charge = clampf(charge + v, 0, MAX_CHARGE)


func can_level_up() -> bool:
	return level < MAX_LEVEL and charge >= LEVEL_COST[level + 1]


func level_up() -> bool:
	if not can_level_up():
		return false
	charge -= LEVEL_COST[level + 1]
	set_level(level + 1)
	return true


func set_level(l: int) -> void:
	level = clampi(l, 1, MAX_LEVEL)
	visibility_changed.emit()


## Spend charge to turn invisible for a while (escape from hunters).
func fade(time := FADE_TIME, cost := FADE_COST) -> bool:
	if is_fading() or charge < cost:
		return false
	charge -= cost
	fade_left = time
	visibility_changed.emit()
	return true


## Hunter touch. Empty charge = lose a level and get a short free fade.
func drain(v: float) -> void:
	charge -= v
	if charge > 0:
		return
	charge = 0.0
	fade_left = HIT_GRACE
	set_level(level - 1)


func finish(did_win: bool) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	won = did_win
	finished.emit(did_win)
