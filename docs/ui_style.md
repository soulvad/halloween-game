# «Сімнадцятий» — візуальний стиль UI «Стара олія»

Інтерфейс у дусі 1840-х: романтичний олійний живопис, стара шкіра в позолочених рамах, дубові дошки з латунню, пергамент, книжковий шрифт. Жодної векторної чи мультяшної графіки: усі зображення згенеровані в ComfyUI (Z-Image Turbo, локально).

- Дизайн-дошка: `docs/ui/design_board.html` (відкрий у браузері).
- Скриншоти: `docs/ui/after/` (зараз), `docs/ui/after_cartoon/` (мультяшна версія), `docs/ui/before/` (перша версія). Мультяшні ілюстрації: `docs/ui/concepts/`. Перший референс: `docs/ui/reference.png`.
- Оновити скриншоти: `engine/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1600x900 res://tools/ui_shots/ui_shots.tscn -- C:/шлях/до/теки`

## Зображення (`art/ui/`)
| Файл | Де |
|---|---|
| `menu.jpg` | головне меню: маєток графа вночі |
| `crypt.jpg` | пауза, «Як грати», налаштування: склепіння, свічки, світло крізь замуровану стіну |
| `dawn.jpg` | фінал: світанок, хата, Тиміш іде додому |
| `card9.png` | 9-slice картки: шкіра в позолоченій рамі, поле 27 px (`UI.framed()`, будь-яка `UI.panel(UI.CARD)`) |
| `plank9.png` | 9-slice кнопки: дубова дошка з латунними кутиками, поля 24 × 18 px (`UI.plank()`) |
| `parchment.jpg` | записки й бульбашки (`UI.parchment()`) |
| `leather.jpg` | тло для дизайн-дошки |

`UI.picture(name, dim)` бере `art/ui/<name>.jpg`; якщо файлу немає — шейдерне нічне небо.

## Палітра (`scripts/ui.gd`)
| Токен | Колір | Де |
|---|---|---|
| `INK` / `NIGHT` / `NIGHT2` | `#140B0C` / `#1B1116` / `#2A1A20` | тіні, фон, сторінки |
| `CARD_HI` | `#3A2629` | другорядні плашки |
| `EDGE` | `#A07A3C` | латунні обідки |
| `GOLD` | `#E0B060` | заголовки розділів, текст головних кнопок |
| `PUMPKIN` | `#D2782A` | клавіша E, мітки |
| `NEON` | `#D26A9E` | привид, ритуал |
| `PAPER` | `#EBDDC3` | пергаментний текст |
| `MUTED` / `LABEL` / `DIM` | `#BFA88A` / `#A88F6E` / `#8C7A64` | другорядний текст |
| `CYAN` / `GREEN` | `#A8DCD8` / `#A8C070` | спогади / виконано |

## Шрифти (`fonts/`, OFL, з кирилицею)
- **Oranienbaum** — назви екранів (`UI.title`).
- **Old Standard TT** Regular / Bold — увесь текст і кнопки (Bold від ваги 700).
- **Bad Script** — голос привида, напис на дзеркалі.

## Світ гри
У `tools/gen_dungeon.py`: приглушений сливовий ambient і туман, тепле bloom-сяйво свічок, слабкі рожеві «привидні» вогні (`Lights/Neon*`), гарбузи-ліхтарі (`Decor/Pumpkin*`).

## Згенерувати ще
ComfyUI → шаблон `image_z_image_turbo_int8`, текстовий енкодер `qwen_3_4b_fp4_mixed`. До опису додавати: «antique dark romantic oil painting, 19th century gothic Romanticism, old master technique, visible brush strokes, aged yellowed varnish, fine craquelure, muted palette of deep aubergine violet, umber brown, tarnished gold and ember orange, no text».
