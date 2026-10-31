extends StyleBoxTexture

const NINE := "res://art/ui/nine/%s.png"
const SLICES := {
	"card_paper": [56, 62, 56, 56, 14, 20, 14, 14],
	"card_paper_small": [30, 34, 30, 30, 10, 14, 10, 10],
	"card_stone": [44, 48, 44, 44, 12, 16, 12, 12],
	"card_holy": [60, 66, 60, 60, 18, 24, 18, 18],
	"comic_frame": [60, 66, 60, 60, 16, 22, 16, 16],
	"map_sheet": [64, 70, 64, 64, 14, 20, 14, 14],
	"map_inset": [16, 18, 16, 16, 4, 6, 4, 4],
	"book_cover": [64, 72, 64, 64, 16, 24, 16, 16],
	"book_page_left": [40, 46, 40, 72, 6, 10, 6, 0],
	"book_page_right": [40, 46, 72, 40, 6, 10, 0, 6],
	"wash_ink": [30, 30, 96, 96, 8, 8, 8, 8],
	"banner_power": [52, 56, 80, 80, 28, 32, 28, 28],
	"tag_goal": [18, 21, 18, 18, 6, 9, 6, 6],
	"tag_new": [14, 17, 14, 14, 5, 8, 5, 5],
	"tag_warn": [14, 17, 14, 14, 5, 8, 5, 5],
	"pill_paper": [16, 19, 16, 16, 6, 9, 6, 6],
	"pill_ghost": [16, 19, 16, 16, 6, 9, 6, 6],
	"plate_stone": [16, 19, 16, 16, 5, 8, 5, 5],
	"button_paper_normal": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_paper_hover": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_paper_pressed": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_paper_disabled": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_primary_normal": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_primary_hover": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_primary_pressed": [30, 36, 34, 34, 14, 18, 16, 16],
	"button_primary_disabled": [30, 36, 34, 34, 14, 18, 16, 16],
	"key_normal": [18, 24, 18, 18, 8, 10, 8, 8],
	"key_hover": [18, 24, 18, 18, 8, 10, 8, 8],
	"key_pressed": [18, 24, 18, 18, 8, 10, 8, 8],
	"key_disabled": [18, 24, 18, 18, 8, 10, 8, 8],
	"tile_action_ready": [26, 30, 26, 26, 10, 12, 10, 10],
	"tile_action_idle": [26, 30, 26, 26, 10, 12, 10, 10],
	"tile_action_ritual": [26, 30, 26, 26, 10, 12, 10, 10],
	"tile_power_locked": [22, 24, 22, 22, 12, 14, 12, 12],
	"tile_power_on": [22, 24, 22, 22, 12, 14, 12, 12],
	"tile_power_new": [22, 24, 22, 22, 12, 14, 12, 12],
	"bar_track": [16, 18, 16, 16, 6, 8, 6, 6],
	"bar_fill_holy": [12, 12, 14, 14, 6, 6, 6, 6],
	"bar_fill_flame": [12, 12, 14, 14, 6, 6, 6, 6],
	"rule_ink": [5, 5, 28, 28, 2, 2, 4, 4],
	"rule_paper": [5, 5, 28, 28, 2, 2, 4, 4],
}
const FAMILIES := {
	"card": {"paper": "card_paper", "dark": "card_stone", "holy": "card_holy", "ghost": "card_stone"},
	"plate": {"paper": "card_paper_small", "dark": "plate_stone", "flame": "tag_goal", "ghost": "pill_ghost",
		"grey": "tile_power_locked", "rust": "tag_warn"},
	"chip": {"paper": "key_normal", "flame": "tag_goal", "ghost": "pill_ghost", "grey": "key_disabled", "rust": "tag_warn"},
	"key": {"paper": "key_normal", "flame": "key_hover", "grey": "key_disabled", "holy": "tile_action_ritual"},
	"pill": {"paper": "pill_paper", "dark": "plate_stone", "flame": "tag_goal", "ghost": "pill_ghost", "rust": "tag_warn"},
	"tile": {"paper": "tile_action_ritual", "flame": "tile_action_ready", "grey": "tile_action_idle", "dark": "tile_action_idle",
		"holy": "tile_action_ritual"},
	"power": {"paper": "tile_power_locked", "flame": "tile_power_on", "ghost": "tile_power_new"},
	"bar": {"paper": "bar_track", "flame": "bar_fill_flame", "holy": "bar_fill_holy"},
	"rule": {"paper": "rule_paper", "dark": "rule_ink"},
	"button": {"paper": "button_paper_normal", "flame": "button_primary_normal", "grey": "button_paper_disabled"},
}
const DARK_LUMINANCE := 0.35

var family := "card"
var look := ""
var bg_color := Color.WHITE: set = _set_bg_color
var border_color := Color.BLACK
var shadow_color := Color.BLACK
var shadow_size := 0
var shadow_offset := Vector2.ZERO


func paint(kind: String, color: Color, pad := -1.0):
	family = kind
	if pad >= 0:
		set_content_margin_all(pad)
	bg_color = color
	return self


func use(name: String) -> void:
	look = name
	if name == "" or not SLICES.has(name):
		texture = null
		return
	texture = load(NINE % name)
	var s: Array = SLICES[name]
	texture_margin_top = s[0]
	texture_margin_bottom = s[1]
	texture_margin_left = s[2]
	texture_margin_right = s[3]
	expand_margin_top = s[4]
	expand_margin_bottom = s[5]
	expand_margin_left = s[6]
	expand_margin_right = s[7]
	axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT


func is_dark() -> bool:
	return look in ["card_stone", "plate_stone", "pill_ghost", "tile_action_idle", "tile_power_on", "tile_power_new", "book_cover", "wash_ink", "bar_track"]


static func role(c: Color) -> String:
	if c.a < 0.05:
		return "clear"
	if c.h > 0.45 and c.h < 0.62 and c.s > 0.15 and c.v > 0.6:
		return "ghost"
	if c.h > 0.02 and c.h < 0.17 and c.s > 0.45 and c.v > 0.75:
		return "flame"
	if (c.h < 0.05 or c.h > 0.95) and c.s > 0.45:
		return "rust"
	if c.get_luminance() < DARK_LUMINANCE:
		return "dark"
	if c.v > 0.97 and c.s < 0.3:
		return "holy"
	if c.s < 0.4 and c.v < 0.85:
		return "grey"
	return "paper"


func _set_bg_color(c: Color) -> void:
	bg_color = c
	if SLICES.has(family):
		use(family)
		return
	var r := role(c)
	var table: Dictionary = FAMILIES.get(family, FAMILIES.card)
	use("" if r == "clear" else table.get(r, table.paper))
