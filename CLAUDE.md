# Halloween Hackathon — "ВІДПУСТИ" (3D ghost game jam prototype)

Godot 4.7.2 (standard build, **GDScript only**, no C#). Engine lives in `engine/` (portable, `_sc_` = editor settings stay in this folder; `.gdignore` hides it from the project).
Old cooking prototype is backed up in `_archive_cooking/` (ignored by Godot).

## Run
- Editor: `editor.bat` · Game: `play.bat`
- Smoke test (headless, must print `ALL TESTS OK`; if it hangs, an `assert` failed — read the output):
  `engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- After editing scripts, run the smoke test. Update it when gameplay rules change.

## Game loop
You are a ghost (floating capsule, no legs) in a house; 5 min until midnight.
1. **Charge**: `E` at spirit items (purple boxes) gives +1 charge, 8s cooldown. Good people who first notice you give +2 (belief).
2. **Altar**: spend charge to raise **visibility level** 1→2 (4) → 3 (6).
   - L1 Тінь: nobody sees you, you pass inner walls.
   - L2 Відлуння: good people + hunters see you; walls with `solid_from 2` block; can open doors, pick up the memento.
   - L3 Присутність: everyone sees you, all walls block, the loved one hears you.
3. **Fade** `Q`/Shift: 2 charge → 4s invisible, passes every inner wall.
4. **Hunters** (appear at their `active_from` level) chase a visible ghost; touch drains charge, at 0 you drop a level.
5. **Goal**: bring the memento (Фото, sealed bedroom behind the door) to Мама at level 3 → `E` "відпустити" = win. Midnight = loss. `Esc` → menu.

## Files
- `scripts/game_state.gd` — autoload `GameState`: phase, level, charge, fade, costs/timings. Signals `visibility_changed`, `finished(won)`.
- `scripts/wall.gd` — `@tool` box wall/furniture from `size`; `solid_from` = level from which it blocks the ghost (collision layer 1/2/3). Passable walls render see-through. `box()` = placeholder mesh helper.
- `scripts/station.gd` — `@tool` interactive object, `kind`: SPIRIT, ALTAR, MEMENTO, DOOR, LOVED; `min_level` gates use. One `interact(player)` entry point.
- `scripts/npc.gd` — people, `kind` GOOD / HUNTER, `sees_from`, `active_from`. No line-of-sight yet.
- `scripts/player.gd` — ghost: WASD, `E` via `Reach` Area3D, `Q` fade, `held`; collision mask follows level.
- `scripts/game.gd` — midnight timer, camera follow, HUD, end screen.
- `scenes/game.tscn` (level: `Level` walls, `Stations`, `People`, `Player`, `Camera3D`, `HUD`), `scenes/player.tscn`, `scenes/main_menu.tscn`.
- `scripts/walk_rig.gd` — legacy walking box-man rig, unused (ghost has no legs).

## Collision layers
1 always solid · 2 solid from L2 · 3 solid from L3 · 4 (8) stations, seen by `Reach` · 5 (16) NPCs. Player layer 0, mask = levels ≤ current (fade → 1). NPCs mask 1–3.

## Conventions
- Walls/stations/NPCs build their own mesh + shape in code: add a node with the script and set exports (`size`, `solid_from`, `kind`, `title_text`, `min_level`, `color`) in the inspector.
- Scripts reach the box helper via `const Wall = preload("res://scripts/wall.gd")` (no `class_name`: headless runs don't build the class cache).
- UI text is Ukrainian.
- Art is placeholder boxes; swap meshes without touching logic.
