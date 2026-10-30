extends Node
## Autoload: ghost state (visibility level, spirit charge, fade, memories) + round phase.
## Charge is fuel: the altar needs a threshold, every level above 1 burns charge each second.

signal visibility_changed  ## level changed or fade started/ended
signal banished  ## knocked out at level 1: back to the spawn
signal finished(won: bool)

enum Phase { PLAY, END }

const MAX_LEVEL := 3
const MAX_CHARGE := 10.0
const LEVEL_REQ := { 2: 4.0, 3: 8.0 }  ## charge needed at the altar (not spent)
const UPKEEP := [0.0, 0.0, 0.05, 0.25]  ## charge per second by level; at 0 the level drops
const FADE_COST := 2.0
const FADE_TIME := 4.0
const HIT_GRACE := 2.0  ## after a knock: nothing hurts, hunters lose sight
const HOLY_DRAIN := 2.0  ## charge per second on holy ground
const MEMORIES_NEEDED := 3
const LEVEL_NAMES := ["", "Тінь", "Відлуння", "Присутність"]

var phase := Phase.PLAY
var level := 1
var charge := 0.0
var fade_left := 0.0  ## > 0: nobody sees the ghost, it passes every inner wall
var grace := 0.0
var memories := 0  ## brought to the loved one
var won := false
var player: Node3D  ## set by the player on spawn


func reset() -> void:
	phase = Phase.PLAY
	level = 1
	charge = 0.0
	fade_left = 0.0
	grace = 0.0
	memories = 0
	won = false
	visibility_changed.emit()


func _process(delta: float) -> void:
	grace = maxf(grace - delta, 0)
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
	charge = clampf(charge + v, 0, MAX_CHARGE)


func can_level_up() -> bool:
	return level < MAX_LEVEL and charge >= LEVEL_REQ[level + 1]


func level_up() -> bool:
	if not can_level_up():
		return false
	set_level(level + 1)
	return true


func set_level(l: int) -> void:
	level = clampi(l, 1, MAX_LEVEL)
	visibility_changed.emit()


## Spend charge to turn invisible for a while (escape from hunters; holy ground still burns).
func fade(time := FADE_TIME, cost := FADE_COST) -> bool:
	if is_fading() or charge < cost:
		return false
	charge -= cost
	fade_left = time
	visibility_changed.emit()
	return true


## Hunter touch / holy ground. Empty charge = lose a level (at level 1: banished to spawn).
func drain(v: float) -> void:
	if grace > 0 or phase != Phase.PLAY:
		return
	charge -= v
	if charge > 0:
		return
	charge = 0.0
	grace = HIT_GRACE
	fade_left = HIT_GRACE
	if level == 1:
		banished.emit()
	set_level(level - 1)


## Holy ground around `pos` (lit candle, priest) burns the ghost inside `radius`.
func burn_near(pos: Vector3, radius: float, delta: float) -> void:
	if player and Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() < radius:
		drain(HOLY_DRAIN * delta)


func finish(did_win: bool) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	won = did_win
	finished.emit(did_win)
