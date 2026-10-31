extends RefCounted
## Comic pages (texts from docs/comic_script.md). Drawn by scripts/comic_page.gd, played by scripts/comic.gd.
##
## Drop-in assets, found by file name (no code changes; placeholders while a file is missing):
##   art   res://art/comic/<page>/<letter>.png   one PNG per panel, full-page size, transparent outside the panel
##                                               (layers stack); any resolution, page aspect comes from the image
##         res://art/comic/<page>/frame.png     optional borders/gutters layer, drawn on top
##   voice res://audio/comic/<page>/<letter>.ogg (or .wav / .mp3) — plays when the panel appears; the comic
##                                               auto-advances after its length + 0.4 s
## Panel keys: text — subtitle (shown only while GameState.subtitles; temporary until voice-over), who — speaker
## ("" = narrator), note — what the panel shows (on the placeholder), time — optional, > 0 = auto-advance after
## that many seconds (overrides the voice length).
## Panel shapes: LAYOUTS below, normalized 0..1 of the page; edit here to match the artist's final frame.

## Artist's 6-panel page: A top-left, B tall right (diagonal edge), C under A, bottom row D E F. aspect = width / height.
const LAYOUTS := {
	"page6": {"aspect": 0.72, "shapes": {
		"A": [Vector2(0, 0), Vector2(0.405, 0), Vector2(0.508, 0.32), Vector2(0, 0.32)],
		"B": [Vector2(0.435, 0), Vector2(1, 0), Vector2(1, 0.68), Vector2(0.655, 0.68)],
		"C": [Vector2(0, 0.34), Vector2(0.515, 0.34), Vector2(0.625, 0.68), Vector2(0, 0.68)],
		"D": [Vector2(0, 0.7), Vector2(0.3, 0.7), Vector2(0.3, 1), Vector2(0, 1)],
		"E": [Vector2(0.32, 0.7), Vector2(0.68, 0.7), Vector2(0.68, 1), Vector2(0.32, 1)],
		"F": [Vector2(0.7, 0.7), Vector2(1, 0.7), Vector2(1, 1), Vector2(0.7, 1)],
	}},
}

## page id -> {layout, panels: letter -> panel}; panels in reading order.
const PAGES := {
	"prologue": {"layout": "page6", "panels": {
		"A": {"note": "Маєток на пагорбі вночі", "who": "",
			"text": "Колись над старим містом височів маєток графа Ауерсберга."},
		"B": {"note": "Розріз: бал нагорі, слуги в підземеллі", "who": "",
			"text": "Нагорі гриміла музика, граф жив у розкоші. А під його ногами, у підземеллі, жили ті, хто йому служив. Без імен, без світла, без права на скаргу."},
		"C": {"note": "Хлопець у камері зі свічкою", "who": "",
			"text": "Серед слуг був хлопець. Він вірив, що одного дня знову побачить сонце."},
		"D": {"note": "Та сама камера, порожня, дим", "who": "",
			"text": "Але одного разу він так і не піднявся нагору. Підземелля забрало його назавжди."},
		"E": {"note": "Маєток у вогні, потім руїни", "who": "",
			"text": "Минули роки. Маєток згорів, місто забуло його назву, а вхід у підземелля засипала земля."},
		"F": {"note": "Археологи спускаються, привид дивиться на світло", "who": "",
			"text": "— Обережно, сходинки старі…\n— Воно ціле… Неймовірно!\nУперше за двісті років сюди хтось прийшов. Може, вони допоможуть йому згадати…"},
	}},
	# A–E = memories 1–5, F = finale.
	"memories": {"layout": "page6", "panels": {
		"A": {"note": "Спогад 1 · Пташка", "who": "Тиміш",
			"text": "Я вирізав пташку з вербової гілки для сестри. Коли люди графа забрали нас за мамин борг, Ганнуся плакала всю дорогу, і я свистів, щоб вона сміялася. Мою сестру звали Ганнуся."},
		"B": {"note": "Спогад 2 · Сімнадцятий", "who": "Тиміш",
			"text": "Тут нас кликали тільки номерами. Я був Сімнадцятий. Вночі ми з Ганнусею стукали через стіну: три удари і один — «я тут». Так ми знали, що обоє живі."},
		"C": {"note": "Спогад 3 · Лист від матері", "who": "Тиміш",
			"text": "Ми не вміли читати, тож тримали мамин лист, як святиню. Стара куховарка Явдоха вчила мене літер вуглинкою на столі, поки я не прочитав: «Тримайтеся одне одного». Я вмію писати."},
		"D": {"note": "Спогад 4 · Ключ від хвіртки", "who": "Тиміш",
			"text": "Пан почав дивитися на неї. Тієї ночі я вкрав ключ, і ми бігли через сад. Сторож, собаки… «Біжи до мами. Не озирайся». А сам схопив ліхтар і побіг назад, щоб вони бачили тільки мене."},
		"E": {"note": "Спогад 5 · Ім'я на стіні", "who": "Тиміш",
			"text": "Мене впіймали до світанку. Я не сказав, куди вона пішла. Останнє, що я бачив, — усмішку пана в щілині між цеглинами. Я дряпав цвяхом, щоб хоч хтось знав. Тиміш. Мене звати Тиміш Ковальчук."},
		"F": {"note": "Фінал · Тиміш у світлі, вдома", "who": "Тиміш",
			"text": "Вона добігла. Вона жила. Я обіцяв собі, що знову побачу сонце. Тиміш Ковальчук. Нарешті вдома."},
	}},
}
