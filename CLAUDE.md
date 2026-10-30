# Halloween Hackathon — "ВІДПУСТИ" (3D ghost game jam prototype)

Godot 4.7.2 (standard build, **GDScript only**, no C#). Engine lives in `engine/` (portable, `_sc_` = editor settings stay in this folder; `.gdignore` hides it from the project).
Old cooking prototype is backed up in `_archive_cooking/` (ignored by Godot).

## Run
- Editor: `editor.bat` · Game: `play.bat`
- Smoke test (headless, must print `ALL TESTS OK`; if it hangs, an `assert` failed — read the output):
  `engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- After editing scripts, run the smoke test. Update it when gameplay rules change.

## Game loop
You are a ghost (floating capsule, no legs) in a house. Every room is reachable from the start; "too early" is shown by holy glow, see-through items labelled "(рівень N)", Mom who "doesn't feel you".
1. **Charge = fuel**: `E` at spirit items (purple) +1, 12s cooldown. Good people who first notice you (L2+) give +2.
2. **Altar**: needs a charge threshold (L2: 4, L3: 8), spends nothing. Each level burns charge per second (`UPKEEP`); at 0 the level drops. So no "charge once and rush".
   - L1 Тінь: nobody sees you, you pass inner walls.
   - L2 Відлуння: good people + hunters see you; room walls (`solid_from 2`) block; you can carry memories, blow out candles.
   - L3 Присутність: everyone sees you, furniture blocks too, more hunters, Mom hears you.
3. **Fade** `Q`/Shift: 2 charge → 4s invisible to people, passes every inner wall. Holy ground still burns.
4. **Dangers**: hunters drain on touch; holy ground (lit candle r=2.5, priest aura r=2) drains 2/s. Empty charge = drop a level + 2s grace; at L1 = banished to spawn.
5. **Priest = timer**: walks `route` (doors + candles), prays 30s at each unlit candle, lights it. All candles lit = loss (~4 min if untouched). Blowing a candle out (L2, 1 charge) buys time until he comes back.
6. **Goal**: carry 3 memories (Лист near a candle, Каблучка by the kitchen hunter, Фото in the burning chapel) to Мама one at a time (L2+), then at L3 `E` "відпустити" = win. `Esc` → menu.

## Files
- `scripts/game_state.gd` — autoload `GameState`: phase, level, charge, upkeep, fade, grace, memories, `drain()`, `burn_near()` (holy ground). Signals `visibility_changed`, `banished`, `finished(won)`. **Tuning numbers live here.**
- `scripts/wall.gd` — `@tool` box wall/furniture from `size`; `solid_from` = level from which it blocks the ghost (collision layer 1/2/3). Passable walls render see-through. `box()`, `holy_glow()` = placeholder visuals.
- `scripts/station.gd` — `@tool` interactive object, `kind`: SPIRIT, ALTAR, MEMENTO, LOVED, CANDLE (`lit`, group `holy_candle`); `min_level` gates use. One `interact(player)` entry point.
- `scripts/npc.gd` — people, `kind` GOOD / HUNTER / PRIEST (`route: Array[NodePath]`), `sees_from`, `active_from`. No line-of-sight or pathfinding: priest routes go through door markers in `Route`.
- `scripts/player.gd` — ghost: WASD, `E` via `Reach` Area3D, `Q` fade, `held`; collision mask follows level.
- `scripts/game.gd` — candle counter (loss), banish → spawn, camera follow, HUD, end screen.
- `scenes/game.tscn` (`Level` walls, `Stations`, `Route` markers, `People`, `Player`, `Camera3D`, `HUD`), `scenes/player.tscn`, `scenes/main_menu.tscn`.
- Layout: NW bedroom (Mom), NE chapel (priest start, 2 lit candles, Фото), SW living room, SE kitchen, hall corridor with the altar + spawn in the south.
- `scripts/walk_rig.gd` — legacy walking box-man rig, unused (ghost has no legs).

## Collision layers
1 always solid · 2 solid from L2 · 3 solid from L3 · 4 (8) stations, seen by `Reach` · 5 (16) NPCs. Player layer 0, mask = levels ≤ current (fade → 1). NPCs mask 1–3.

## Conventions
- Walls/stations/NPCs build their own mesh + shape in code: add a node with the script and set exports (`size`, `solid_from`, `kind`, `title_text`, `min_level`, `color`) in the inspector.
- Scripts reach the box helper via `const Wall = preload("res://scripts/wall.gd")` (no `class_name`: headless runs don't build the class cache).
- UI text is Ukrainian.
- Art is placeholder boxes; swap meshes without touching logic.
