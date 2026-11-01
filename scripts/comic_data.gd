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
## The finished prologue pages are cut into these layers by tools/cut_comic.py, which also prints their shapes.
## A page with "next" goes straight on to that page when its last panel is done.

## Measured from the artist's pages. aspect = width / height.
const LAYOUTS := {
	"prologue": {"aspect": 0.719, "shapes": {
		"A": [Vector2(0.028, 0.014), Vector2(0.352, 0.014), Vector2(0.515, 0.346), Vector2(0.028, 0.346)],
		"B": [Vector2(0.374, 0.012), Vector2(0.974, 0.012), Vector2(0.974, 0.667), Vector2(0.669, 0.667)],
		"C": [Vector2(0.028, 0.357), Vector2(0.520, 0.357), Vector2(0.655, 0.666), Vector2(0.028, 0.666)],
		"D": [Vector2(0.026, 0.680), Vector2(0.355, 0.680), Vector2(0.355, 0.980), Vector2(0.026, 0.980)],
		"E": [Vector2(0.371, 0.680), Vector2(0.656, 0.680), Vector2(0.656, 0.980), Vector2(0.371, 0.980)],
		"F": [Vector2(0.673, 0.680), Vector2(0.974, 0.680), Vector2(0.974, 0.980), Vector2(0.673, 0.980)],
	}},
	"prologue2": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.028, 0.012), Vector2(0.354, 0.012), Vector2(0.519, 0.336), Vector2(0.028, 0.336)],
		"B": [Vector2(0.373, 0.012), Vector2(0.975, 0.012), Vector2(0.975, 0.626), Vector2(0.666, 0.626)],
		"C": [Vector2(0.028, 0.347), Vector2(0.524, 0.347), Vector2(0.650, 0.624), Vector2(0.028, 0.624)],
		"D": [Vector2(0.028, 0.637), Vector2(0.338, 0.637), Vector2(0.291, 0.979), Vector2(0.028, 0.979)],
		"E": [Vector2(0.351, 0.637), Vector2(0.635, 0.637), Vector2(0.635, 0.979), Vector2(0.304, 0.979)],
		"F": [Vector2(0.650, 0.637), Vector2(0.978, 0.637), Vector2(0.978, 0.979), Vector2(0.650, 0.979)],
	}},
	"memory_1": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.025, 0.013), Vector2(0.415, 0.013), Vector2(0.552, 0.469), Vector2(0.025, 0.425)],
		"B": [Vector2(0.434, 0.013), Vector2(0.975, 0.013), Vector2(0.975, 0.508), Vector2(0.571, 0.471)],
		"C": [Vector2(0.025, 0.436), Vector2(0.975, 0.522), Vector2(0.975, 0.980), Vector2(0.025, 0.980)],
	}},
	"memory_2": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.024, 0.012), Vector2(0.976, 0.012), Vector2(0.976, 0.151), Vector2(0.024, 0.275)],
		"B": [Vector2(0.024, 0.288), Vector2(0.976, 0.164), Vector2(0.976, 0.683), Vector2(0.024, 0.601)],
		"C": [Vector2(0.024, 0.616), Vector2(0.976, 0.695), Vector2(0.976, 0.979), Vector2(0.024, 0.979)],
	}},
	"memory_3": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.024, 0.013), Vector2(0.976, 0.013), Vector2(0.976, 0.143), Vector2(0.024, 0.244)],
		"B": [Vector2(0.024, 0.254), Vector2(0.976, 0.153), Vector2(0.976, 0.592), Vector2(0.024, 0.536)],
		"C": [Vector2(0.024, 0.548), Vector2(0.976, 0.604), Vector2(0.976, 0.981), Vector2(0.024, 0.981)],
	}},
	"memory_4": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.023, 0.011), Vector2(0.979, 0.010), Vector2(0.979, 0.159), Vector2(0.023, 0.256)],
		"B": [Vector2(0.023, 0.263), Vector2(0.979, 0.166), Vector2(0.979, 0.456), Vector2(0.023, 0.476)],
		"C": [Vector2(0.023, 0.483), Vector2(0.979, 0.462), Vector2(0.979, 0.704), Vector2(0.023, 0.668)],
		"D": [Vector2(0.023, 0.676), Vector2(0.539, 0.695), Vector2(0.400, 0.985), Vector2(0.023, 0.985)],
		"E": [Vector2(0.551, 0.695), Vector2(0.979, 0.711), Vector2(0.979, 0.985), Vector2(0.412, 0.985)],
	}},
	"memory_5": {"aspect": 0.713, "shapes": {
		"A": [Vector2(0.026, 0.013), Vector2(0.976, 0.013), Vector2(0.976, 0.211), Vector2(0.026, 0.320)],
		"B": [Vector2(0.026, 0.331), Vector2(0.484, 0.277), Vector2(0.569, 0.548), Vector2(0.026, 0.598)],
		"C": [Vector2(0.500, 0.275), Vector2(0.976, 0.219), Vector2(0.976, 0.509), Vector2(0.585, 0.545)],
		"D": [Vector2(0.026, 0.611), Vector2(0.976, 0.520), Vector2(0.976, 0.981), Vector2(0.026, 0.981)],
	}},
	"finale": {"aspect": 0.720, "shapes": {
		"A": [Vector2(0.026, 0.011), Vector2(0.352, 0.011), Vector2(0.522, 0.351), Vector2(0.026, 0.351)],
		"B": [Vector2(0.367, 0.011), Vector2(0.977, 0.011), Vector2(0.977, 0.351), Vector2(0.535, 0.351)],
		"C": [Vector2(0.026, 0.355), Vector2(0.521, 0.355), Vector2(0.648, 0.654), Vector2(0.026, 0.654)],
		"D": [Vector2(0.536, 0.355), Vector2(0.977, 0.355), Vector2(0.977, 0.654), Vector2(0.662, 0.654)],
		"E": [Vector2(0.026, 0.660), Vector2(0.549, 0.660), Vector2(0.474, 0.982), Vector2(0.026, 0.982)],
		"F": [Vector2(0.562, 0.660), Vector2(0.977, 0.660), Vector2(0.977, 0.982), Vector2(0.487, 0.982)],
	}},
	"memories": {"aspect": 1.079, "shapes": {
		"A": [Vector2(0.012, 0.013), Vector2(0.329, 0.013), Vector2(0.329, 0.494), Vector2(0.012, 0.494)],
		"B": [Vector2(0.341, 0.013), Vector2(0.659, 0.013), Vector2(0.659, 0.494), Vector2(0.341, 0.494)],
		"C": [Vector2(0.671, 0.013), Vector2(0.988, 0.013), Vector2(0.988, 0.494), Vector2(0.671, 0.494)],
		"D": [Vector2(0.012, 0.506), Vector2(0.329, 0.506), Vector2(0.329, 0.987), Vector2(0.012, 0.987)],
		"E": [Vector2(0.341, 0.506), Vector2(0.659, 0.506), Vector2(0.659, 0.987), Vector2(0.341, 0.987)],
		"F": [Vector2(0.671, 0.506), Vector2(0.988, 0.506), Vector2(0.988, 0.987), Vector2(0.671, 0.987)],
	}},
}

## page id -> {layout, panels: letter -> panel}; panels in reading order.
const PAGES := {
	"prologue": {"layout": "prologue", "next": "prologue2", "panels": {
		"A": {"note": "Маєток на пагорбі вночі", "who": "",
			"text": "Колись над старим містом височів маєток графа Ауерсберга."},
		"B": {"note": "Розріз: бал нагорі, підземелля внизу", "who": "",
			"text": "Нагорі гриміла музика, граф жив у розкоші. А під його ногами, у підземеллі, жили ті, хто йому служив."},
		"C": {"note": "Слуги з мішками й наглядач", "who": "",
			"text": "Без імен, без світла, без права на скаргу."},
		"D": {"note": "Хлопець у камері зі свічкою", "who": "",
			"text": "Серед слуг був хлопець."},
		"E": {"note": "Свічка догоряє", "who": "",
			"text": "Він вірив, що одного дня знову побачить сонце."},
		"F": {"note": "Та сама камера, порожня, дим", "who": "",
			"text": "Але одного разу він так і не піднявся нагору. Підземелля забрало його назавжди."},
	}},
	"prologue2": {"layout": "prologue2", "panels": {
		"A": {"note": "Маєток у вогні", "who": "",
			"text": "Минули роки. Маєток згорів."},
		"B": {"note": "Руїни на пагорбі, під землею маленький привид", "who": "",
			"text": "Місто забуло його назву, а вхід у підземелля засипала земля."},
		"C": {"note": "Привид ближче, порожнє обличчя", "who": "", "text": ""},
		"D": {"note": "Пролом у стелі, денне світло", "who": "",
			"text": "Уперше за двісті років сюди хтось прийшов."},
		"E": {"note": "Археолог із ліхтарем", "who": "",
			"text": "— Обережно, сходинки старі…\n— Воно ціле… Неймовірно!"},
		"F": {"note": "Обличчя привида", "who": "",
			"text": "Може, вони допоможуть йому згадати…"},
	}},
	"memory_1": {"layout": "memory_1", "panels": {
		"A": {"note": "Рука привида й пташка", "who": "Тиміш",
			"text": "Я вирізав пташку з вербової гілки для сестри."},
		"B": {"note": "Людей графа забирають дітей", "who": "Тиміш",
			"text": "Коли люди графа забрали нас за мамин борг, Ганнуся плакала всю дорогу…"},
		"C": {"note": "Хлопець свистить, сестра сміється", "who": "Тиміш",
			"text": "…і я свистів, щоб вона сміялася. Мою сестру звали Ганнуся."},
	}},
	"memory_2": {"layout": "memory_2", "panels": {
		"A": {"note": "Бляха «17»", "who": "Тиміш",
			"text": "Тут нас кликали тільки номерами. Я був Сімнадцятий."},
		"B": {"note": "Розбитий келих і наглядач на балу", "who": "Тиміш", "text": ""},
		"C": {"note": "Стук через стіну", "who": "Тиміш",
			"text": "Вночі ми з Ганнусею стукали через стіну: три удари і один — «я тут». Так ми знали, що обоє живі."},
	}},
	"memory_3": {"layout": "memory_3", "panels": {
		"A": {"note": "Лист під каменем", "who": "Тиміш",
			"text": "Ми не вміли читати, тож тримали мамин лист, як святиню."},
		"B": {"note": "Куховарка вчить хлопця літер", "who": "Тиміш",
			"text": "Стара куховарка Явдоха вчила мене літер вуглинкою на столі…"},
		"C": {"note": "Лист у руках", "who": "Тиміш",
			"text": "…поки я не прочитав: «Тримайтеся одне одного». Я вмію писати."},
	}},
	"memory_4": {"layout": "memory_4", "panels": {
		"A": {"note": "Ключ у відкритій скрині", "who": "Тиміш",
			"text": "Тієї ночі я вкрав ключ, і ми бігли через сад."},
		"B": {"note": "Граф на сходах і дівчинка з відром, хлопець за колоною", "who": "Тиміш",
			"text": "Пан почав дивитися на неї."},
		"C": {"note": "Діти біжать до хвіртки, сторож із ліхтарем і собаки", "who": "Тиміш",
			"text": "Сторож, собаки…"},
		"D": {"note": "Хлопець штовхає сестру за хвіртку", "who": "Тиміш",
			"text": "«Біжи до мами. Не озирайся»."},
		"E": {"note": "Хлопець із ліхтарем біжить назад на погоню", "who": "Тиміш",
			"text": "А сам схопив ліхтар і побіг назад, щоб вони бачили тільки мене."},
	}},
	"memory_5": {"layout": "memory_5", "panels": {
		"A": {"note": "Рука привида на подряпинах", "who": "Тиміш",
			"text": "Я дряпав цвяхом, щоб хоч хтось знав."},
		"B": {"note": "Замуровують стіну", "who": "Тиміш",
			"text": "Мене впіймали до світанку. Я не сказав, куди вона пішла."},
		"C": {"note": "Очі в щілині між цеглинами", "who": "Тиміш",
			"text": "Останнє, що я бачив, — усмішку пана в щілині між цеглинами."},
		"D": {"note": "Ім'я на стіні", "who": "Тиміш",
			"text": "Тиміш. Мене звати Тиміш Ковальчук."},
	}},
	"finale": {"layout": "finale", "panels": {
		"A": {"note": "Священник виправляє запис у церковній книзі", "who": "",
			"text": "У старій церковній книзі священник закреслив номер і вписав ім'я."},
		"B": {"note": "Хрест над могилою біля руїн, священник і археологи", "who": "",
			"text": "Тиміша поховали під сонцем, з хрестом і молитвою, як людину."},
		"C": {"note": "Священник показує археологам запис у книзі", "who": "Священник",
			"text": "Ось вона: Ганна Ковальчук. Дожила до сивого волосся, мала дітей і онуків."},
		"D": {"note": "Привид Тиміша усміхається за плечем священника", "who": "Тиміш",
			"text": "Вона добігла. Вона жила."},
		"E": {"note": "Привид у промені світла з пролому", "who": "Тиміш",
			"text": "Я обіцяв собі, що знову побачу сонце."},
		"F": {"note": "Обличчя Тиміша в сонці", "who": "Тиміш",
			"text": "Тиміш Ковальчук. Нарешті вдома."},
	}},
	# The sheet of all memories (book): A–E = memories 1–5, F = finale. Whole pages laid out by tools/cut_comic.py.
	"memories": {"layout": "memories", "panels": {
		"A": {"note": "Спогад 1 · Пташка", "who": "Тиміш", "text": ""},
		"B": {"note": "Спогад 2 · Сімнадцятий", "who": "Тиміш", "text": ""},
		"C": {"note": "Спогад 3 · Лист від матері", "who": "Тиміш", "text": ""},
		"D": {"note": "Спогад 4 · Ключ від хвіртки", "who": "Тиміш", "text": ""},
		"E": {"note": "Спогад 5 · Ім'я на стіні", "who": "Тиміш", "text": ""},
		"F": {"note": "Фінал · Тиміш у світлі, вдома", "who": "Тиміш", "text": ""},
	}},
}
