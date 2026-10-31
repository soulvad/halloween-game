# Halloween Hackathon — "ВІДПУСТИ" (3D ghost game jam prototype)

Godot 4.7.2 (standard build, **GDScript only**, no C#). Engine lives in `engine/` (portable, `_sc_` = editor settings stay in this folder; `.gdignore` hides it from the project).
Old cooking prototype is backed up in `_archive_cooking/` (ignored by Godot).

## Run
- Editor: `editor.bat` · Game: `play.bat`
- Smoke test (headless, must print `ALL TESTS OK`; if it hangs, an `assert` failed — read the output):
  `engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- After editing scripts, run the smoke test. Update it when gameplay rules change.

## Game loop — «Підземелля старого міста»
Story: `docs/comic_script.md` (comic script) + the team's story doc. Тиміш, a servant boy walled up by count Auersberg, forgot who he was. Linear, **no resources, no enemies, no way to lose, one (good) ending**. The ghost floats through every inner wall; only the outer walls stop it.
- **Memories → powers.** A cyan glint (`MEMORY`, only the next one in order is visible) → `E` → memory comic → power: 1 Пташка → Подих (candles), 2 Сімнадцятий → Поштовх і звук (noise objects, push the plan), 3 Лист → Письмо (mirror), 4 Ключ → Сила рук (door, knock), 5 Ім'я на стіні (your name, ritual key).
- **Stages** (`GameState.Stage`, driven in `game.gd._process`, visitors react in `visitor.gd`):
  1. HAUNT «Помітьте мене»: candle on/off and noises → archaeologists (Олена, Тарас) within 12 m come to check. With Письмо write ДОПОМОЖІТЬ on the mirror while one is within 7 m → they call the priest.
  2. PRIEST_COMING (15 s) → LURE «Знайдіть мою кімнату»: archaeologists work at their camp table; push the plan (witness) → they head for the bricked wall, but the door (closed, blocks people + navmesh) stops them. Memory 4 → open the door → knock 3 quick + pause + 1 with an archaeologist within 2 m.
  3. DIG (12 s) → EVIDENCE: everyone in your room; show 3 things (witness), then memory 5 appears → RITUAL: the priest prays 20 s, hold `E` in the circle 2.5 s → finale comic → end screen.
- **Comics** (`scenes/comic.tscn`): two pages in the artist's 6-panel layout. «prologue» plays on the first game start (`GameState.intro_seen`); «memories» panel A–E reveals on memory 1–5, F after the ritual (finale); the same page sits in the J/Tab book. Art/voice/models/textures drop in by file name, see `docs/assets.md`. `game.comic(id)`; the smoke test sets `comics_enabled = false`.
- First person: mouse look, walk 3.5, Shift sprint 6. `Esc` pause, `M` map, `J`/Tab quest + hints book.

## Files
- `scripts/game_state.gd` — autoload `GameState`: phase, `stage` + `set_stage()` + `goal()`, `memories`/`remember(id)`/`name_known()`, `powers`/`has_power()` (`POWERS`, `POWER_NAMES`, `POWER_HELP`, `MEMORY_POWER`, `MEMORY_TITLES`), story flags `mirror_written`, `plan_moved`, `wall_knocked`, `dig`, `evidence`, `ritual`, `release_ready()`, `haunt(pos, power)` (→ `haunted`). Signals `memory_found`, `power_gained`, `stage_changed`, `said` (`say()`, `think()`), `hint_unlocked`, `finished`. Book hints `HINTS` + `hint(id)`.
- `scripts/station.gd` — `@tool` interactive object, `kind`: MEMORY (`memory_id`), CANDLE (`lit`), HAUNT, MIRROR, PLAN, DOOR (`open`, people-only blocker, calls `game.rebake_nav()`), KNOCK (rhythm), EVIDENCE, CIRCLE; `need` = power required. `title()` / `can_use()` / `interact(player)`; `witness()` = an archaeologist close enough.
- `scripts/comic.gd` + `scripts/comic_data.gd` + `scenes/comic.tscn` — comic player: `play(id)` → `finished`, pauses the tree; data per id: pages → panels (`text`, `who`, `art`, `voice`, `time`). Test: `tests/comic_test.tscn` prints `COMIC OK`.
- `scripts/visitor.gd` — archaeologist (ARCH) / priest (PRIEST, hidden until `arrive()`); navmesh walking via `NavigationAgent3D`, behaviour per stage; finds `Markers/*` and `Level/Rubble` through `owner`.
- `scripts/wall.gd` — `@tool` box from `size` (or `art/models/<node name>` via `visual()` / `model()`, textures via `textured()`); `solid_from` 1 = outer wall (blocks the ghost), 2–3 = inner wall / furniture (people + navmesh only); `people_only` = layer 7 (the bricked wall `Level/Rubble`). `box()`, `holy_glow()`.
- `scripts/player.gd` — first-person ghost: `Head/Camera3D`, aim `RayCast3D` (layer 4) then `Reach` fallback, `E`; collision mask 1.
- `scripts/game.gd` — navmesh bake (`_bake_nav()`, `rebake_nav()`), stage transitions, comics (`comic(id)`), `_open_room()`, release hold (`at_release()`, `hold`, `_release()`).
- `scripts/hud.gd` — all in-game UI built in code with `scripts/ui.gd` (HUD with powers row + memories counter, goal panel, map, pause, book, end screen); owns `Esc` / `M` / `J`.
- `scenes/game.tscn` — **generated** by `python tools/gen_dungeon.py scenes/game.tscn` (rooms as 0.25 m grid rectangles + doors → wall segments, furniture, stations, lights, `Markers` (Entrance, Camp, RoomCenter, dig sites), visitors, player). Edit the generator, not the scene. Keep passages/doors ≥ 1.75 m wide or the navmesh (agent radius 0.5) closes them.
- `scripts/model_rig.gd` — character wrapper (`art/models/Olena|Taras|Priest.tscn`): hides parts, swaps the skin, maps states `idle/walk/run/work/pray` to clips (`act(state)`, called by `visitor.gd`), attaches head/hand items to bones.
- Assets (`docs/assets.md`, sources and licences in `docs/credits.md`): `art/models/<Name>.tscn` wrappers fit KayKit/Kenney models from `art/models/src/` to the box sizes (origin bottom centre, front −Z); a child named `On` shows only in the "on" state (lit candle, written mirror, shown evidence). Never add a model named `Wall` (it would replace every `WallN`). Station sounds `audio/sfx/<Name>.ogg` (same name lookup as models, `station.sound()`), ambience `audio/ambient/*.ogg` (`AMBIENT` in `game.gd`), fonts `fonts/*.ttf` (`UI.FONT_FILES`, system font fallback).
- `tools/painter/` (`paint.bat`) — hand-drawn texture painter.
- `scripts/walk_rig.gd` — legacy, unused.

## Collision layers
1 always solid · 2 solid from L2 · 3 solid from L3 · 4 (8) stations (aim) · 5 (16) visitors · 6 (32) invisible floor, navmesh bake only · 7 (64) people-only (rubble). Visual layers: 2 world labels (minimap culls), 3 own ghost body (FP camera culls), 4 ceiling (minimap culls). Visitors mask 1–3 + 7.

## Conventions
- Walls/stations/visitors build their own mesh + shape in code: add a node with the script and set exports (`size`, `solid_from`, `kind`, `title_text`, `min_level`, `color`) in the inspector.
- Scripts reach the box helper via `const Wall = preload("res://scripts/wall.gd")` (no `class_name`: headless runs don't build the class cache).
- UI text is Ukrainian.
- Art is placeholder boxes; swap meshes without touching logic.

## TODO (agreed, not built yet)
- Fly-over intro after the prologue comic: top-down camera along a path over the dungeon, showing the main features (archaeologists, memory glints, the bricked wall). Skippable.
- Comic voice-over: record lines + per-panel timings (`time` / `voice` in the comic data), then drop the temporary on-screen texts.
