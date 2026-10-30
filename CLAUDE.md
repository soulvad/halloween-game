# Halloween Hackathon — "ВІДПУСТИ" (3D ghost game jam prototype)

Godot 4.7.2 (standard build, **GDScript only**, no C#). Engine lives in `engine/` (portable, `_sc_` = editor settings stay in this folder; `.gdignore` hides it from the project).
Old cooking prototype is backed up in `_archive_cooking/` (ignored by Godot).

## Run
- Editor: `editor.bat` · Game: `play.bat`
- Smoke test (headless, must print `ALL TESTS OK`; if it hangs, an `assert` failed — read the output):
  `engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- After editing scripts, run the smoke test. Update it when gameplay rules change.

## Game loop — «Підземелля старого міста»
The count tortured his servants in this dungeon; you died in the farthest cell and can't leave. Linear story, **no enemies, no way to lose**. Stages: `GameState.Stage` (driven in `game.gd._process`, visitors react in `visitor.gd`):
1. **HAUNT**: archaeologists (Олена, Тарас, with lanterns) explore dig sites. `E` on a noise object (orange, 1 charge, 6s cooldown) → archaeologists within 12 m go check it, `unease += power`; at L2+ a sighting adds +2 once per level. `unease ≥ 8` → they call the priest.
2. **PRIEST_COMING** (15s): everyone waits at the entrance. **LURE**: the priest (Отець Василь) walks in; archaeologists walk to the last noise they heard, the priest follows. Lead them up the passage with «Стук за завалом».
3. **DIG**: an archaeologist within 3 m of `Level/Rubble` digs (12s); the rubble (people-only, the ghost floats through it) is freed and the navmesh rebaked.
4. **EVIDENCE**: everyone gathers in your room; at L2 `E` on Кайдани / Подряпини / Миска while an archaeologist is within 7 m reveals it (3 needed).
5. **RITUAL**: the priest prays in the circle (20s). Then at L3 **hold `E`** in the circle 2.5s (`game.RELEASE_TIME`) = win.
- Ghost basics: charge from spirit items (`E`, +1, 12s cd), altar = your bones (modal, threshold L2 4 / L3 8, spends nothing), each level burns upkeep, `Q` fade, Shift sprint. The priest's aura (r 1.8, off during the ritual) drains charge: empty = drop a level, at L1 = back to your bones.
- First person: mouse look, walk 3.5, sprint 6. `Esc` pause, `M` map, `J`/Tab quest + hints book.

## Files
- `scripts/game_state.gd` — autoload `GameState`: phase, level, charge, upkeep, fade, grace, story (`stage`, `set_stage()`, `goal()`, `unease`, `haunt(pos, power)` → signal `haunted`, `dig`, `evidence`, `ritual`, `release_ready()`), `drain()`, `burn_near()`. Signals `visibility_changed`, `stage_changed`, `banished`, `finished(won)`, `said` (`say()`, `think()`), `altar_requested`, `hint_unlocked`. Book hints `HINTS` + `hint(id)` (each stage unlocks its hint). **Tuning numbers live here** (story timings in `game.gd`).
- `scripts/station.gd` — `@tool` interactive object, `kind`: SPIRIT, ALTAR, HAUNT (`power`), EVIDENCE (`shown`, `witness()`), CIRCLE (MEMENTO/LOVED/CANDLE are old, unused). `can_use()` + `interact(player)`.
- `scripts/visitor.gd` — archaeologist (ARCH) / priest (PRIEST, hidden until `arrive()`); navmesh walking via `NavigationAgent3D`, behaviour per stage; finds `Markers/*` and `Level/Rubble` through `owner`.
- `scripts/wall.gd` — `@tool` box from `size`; `solid_from` = level from which it blocks the ghost; `people_only` = blocks only people (rubble). `box()`, `holy_glow()`.
- `scripts/player.gd` — first-person ghost: `Head/Camera3D`, aim `RayCast3D` (layer 4) then `Reach` fallback, `E`/`Q`/`F`, collision mask follows level.
- `scripts/game.gd` — navmesh bake (`_bake_nav()`), stage transitions, `_open_room()`, release hold (`at_release()`, `hold`, `_release()`), banish → spawn.
- `scripts/hud.gd` — all in-game UI built in code with `scripts/ui.gd` (HUD, goal panel, altar modal, map, pause, book, end screen); owns `Esc` / `M` / `J`.
- `scenes/game.tscn` — **generated** by `python tools/gen_dungeon.py scenes/game.tscn` (rooms as 0.25 m grid rectangles + doors → wall segments, furniture, stations, lights, `Markers` (Entrance, RoomCenter, dig sites), visitors, player). Edit the generator, not the scene. Keep passages/doors ≥ 1.5 m wide or the navmesh (agent radius 0.5) closes them.
- `tools/painter/` (`paint.bat`) — hand-drawn texture painter.
- `scripts/walk_rig.gd` — legacy, unused.

## Collision layers
1 always solid · 2 solid from L2 · 3 solid from L3 · 4 (8) stations (aim) · 5 (16) visitors · 6 (32) invisible floor, navmesh bake only · 7 (64) people-only (rubble). Visual layers: 2 world labels (minimap culls), 3 own ghost body (FP camera culls), 4 ceiling (minimap culls). Visitors mask 1–3 + 7.

## Conventions
- Walls/stations/visitors build their own mesh + shape in code: add a node with the script and set exports (`size`, `solid_from`, `kind`, `title_text`, `min_level`, `color`) in the inspector.
- Scripts reach the box helper via `const Wall = preload("res://scripts/wall.gd")` (no `class_name`: headless runs don't build the class cache).
- UI text is Ukrainian.
- Art is placeholder boxes; swap meshes without touching logic.
