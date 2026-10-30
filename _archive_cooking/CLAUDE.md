# Halloween Hackathon — 3D game jam prototype

Godot 4.7.2 (standard build, **GDScript only**, no C#). Engine lives in `engine/` (portable, `_sc_` = editor settings stay in this folder; `.gdignore` hides it from the project).

## Run
- Editor: `editor.bat` · Game: `play.bat`
- Smoke test (headless, must print `ALL TESTS OK`; if it hangs, an `assert` failed — read the output):
  `engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- After editing scripts, run the smoke test. Update it when gameplay rules change.

## Game loop
1. **SHOP** (60s): capsule player runs between shelves/stands, `E` at a shelf adds the item to the cart.
2. **BREAK** (3s): "time's up", red `KitchenDoor` is removed.
3. **COOK** (150s): Overcooked-style. Shelves now hand out items from the cart. Board = chop (press E 5×), Stove = cooks meat in 4s, burns at 12s. Take plate → collect ready ingredients → Serve window. Orders spawn every 15s (max 3).
4. **END**: score + "В меню" button. `Esc` returns to menu anytime.

## Files
- `scripts/game_state.gd` — autoload `GameState`: phase, cart, orders, score, item tables (`CHOP`, `COOK`, `PLATEABLE`, `RECIPES`, `NAMES`, `COLORS`), placeholder visuals `make_visual()`. **Add new ingredients/recipes here.**
- `scripts/station.gd` — every interactive object; `kind` enum: SHELF, COUNTER, BOARD, STOVE, PLATES, SERVE, TRASH. One `interact(player)` entry point.
- `scripts/player.gd` — movement (WASD/arrows), `E`/Space interact via `Reach` Area3D, `held` + `plate`, cart visuals.
- `scripts/game.gd` — phase timers, orders spawning, camera follow, HUD.
- `scenes/main_menu.tscn`, `scenes/game.tscn` (level: `Level`, `Store`, `Kitchen`, `KitchenDoor`, `Player`, `Camera3D`, `HUD`), `scenes/player.tscn`.

## Conventions
- Items are plain strings (`"tomato"`, `"tomato_chopped"`, `"meat_cooked"`); a plate is `"plate"` + an `Array` of items.
- New station = duplicate an existing one in `game.tscn` (StaticBody3D with `Mesh`, `Shape`, `Label` children + `station.gd`), set `kind`/`item_type`/`size`.
- UI text is Ukrainian.
- Art is placeholder boxes; swap meshes in the scenes without touching logic.
