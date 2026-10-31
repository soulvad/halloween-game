extends RefCounted

const Paint = preload("res://scripts/paint_box.gd")

const INK := Color("17110E")
const PAPER := Color("E9DCC3")
const NIGHT := Color("1B130F")
const NIGHT2 := Color("2B1F18")
const STONE := Color("4A3A30")
const GOLD := Color("F2A93B")
const CHARGE := Color("FFD58A")
const CYAN := Color("9BD8F0")
const GHOST_INK := Color("2F5F86")
const MOM := Color("FFF3D6")
const RED := Color("8E3B2A")
const GREEN := Color("FFD58A")
const ORANGE := Color("F2A93B")
const LILAC := Color("C9B593")
const GREY := Color("A8967C")
const MUTED := Color("5A4636")
const LABEL := Color("6B5A4C")
const DIM := Color("C9B593")
const SHADE := Color(0.09, 0.067, 0.055, 0.9)
const LEVEL_COLORS := [Color.WHITE, CYAN, GOLD, MOM]
const LABEL_NEAR := 2.0

const ICONS_DIR := "res://art/ui/icons/%s.png"
const TITLES_DIR := "res://art/ui/titles/title_%s_%s.png"
const TEXTURES_DIR := "res://art/ui/textures/%s.png"
const FONT_DIR := "res://fonts/%s.ttf"
const ICON_FILES := {
	"ghost": ["power_ghost_ink", "power_ghost_on"],
	"bolt": ["power_ghost_ink", "power_ghost_on"],
	"moon": ["power_ghost_ink", "power_ghost_on"],
	"hand": ["hand_ink", "power_hands_locked"],
	"lock": ["lock", "lock"],
	"warn": ["lock", "lock"],
	"candle": ["marker_candle_lit", "marker_candle_lit"],
	"map": ["book", "book"],
	"book": ["book", "book"],
	"eye": ["marker_memory", "marker_memory"],
	"memory": ["marker_memory", "marker_memory"],
	"search": ["marker_archaeologist", "marker_archaeologist"],
	"speaker": ["marker_noise", "marker_noise"],
	"check": ["step_done", "step_done_light"],
	"done": ["step_done", "step_done_light"],
	"current": ["step_current", "step_current"],
	"later": ["step_later", "step_later_light"],
	"check_on": ["check_on", "check_on"],
	"check_off": ["check_off", "check_off"],
	"knob": ["slider_knob", "slider_knob"],
	"knob_small": ["slider_knob_48", "slider_knob_48"],
	"pointer": ["pointer_arrow", "pointer_arrow"],
}
const POWER_ICONS := {"breath": "breath", "sound": "push_sound", "write": "writing", "hands": "hands"}

static var _fonts := {}
static var _blank: Texture2D


static func font(kind := "body", weight := 800) -> Font:
	var key := "%s%d" % [kind, weight]
	if not _fonts.has(key):
		var file := "Kurale-Regular"
		match kind:
			"display":
				file = "OldStandard-Bold"
			"italic":
				file = "OldStandard-Italic"
			"hand":
				file = "MarckScript-Regular"
			_:
				if weight >= 900:
					file = "OldStandard-Bold"
		var f := FontVariation.new()
		f.base_font = load(FONT_DIR % file)
		if file == "Kurale-Regular" and weight >= 700:
			f.variation_embolden = 0.35
		_fonts[key] = f
	return _fonts[key]


static func world_label(l: Label3D, px: float) -> void:
	var cam := l.get_viewport().get_camera_3d()
	if cam:
		l.pixel_size = px * minf(1.0, LABEL_NEAR / maxf(cam.global_position.distance_to(l.global_position), 0.01))


static func style(bg: Color, radius := 26, border := 5, shadow := 0, border_color := INK, drop := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	if shadow > 0 or drop > 0:
		s.shadow_color = INK
		s.shadow_size = 1
		s.shadow_offset = Vector2(shadow, shadow) if shadow > 0 else Vector2(0, drop)
	s.anti_aliasing = true
	return s


static func box(kind: String, bg := PAPER, pad := -1.0) -> StyleBoxTexture:
	return Paint.new().paint(kind, bg, pad)


static func panel(bg := PAPER, radius := 26, _shadow := 7, pad := 20, _border := 5, _border_color := INK, kind := "") -> PanelContainer:
	if kind == "":
		kind = "pill" if radius >= 999 else ("card" if pad >= 16 else "plate")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(kind, bg, pad))
	return p


static func text_on(s: StyleBox, fg: Color) -> Color:
	var look: String = s.get("look") if s.get("look") != null else ""
	if look == "pill_ghost":
		return CYAN
	if look in ["tag_warn", "plate_stone", "card_stone", "wash_ink"]:
		return MOM if look == "tag_warn" else PAPER
	return INK if fg.get_luminance() > 0.5 else fg


static func label(text: String, size := 20, color := INK, kind := "body", weight := 800, upper := false) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = upper
	var ls := LabelSettings.new()
	ls.font = font(kind, weight)
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	return l


static func title(text: String, size := 110, color := PAPER) -> Label:
	var l := label(text, size, color, "display", 900)
	var ls := l.label_settings
	ls.outline_size = maxi(3, int(size * 0.05))
	ls.outline_color = INK
	ls.shadow_size = ls.outline_size
	ls.shadow_color = Color(INK, 0.6)
	ls.shadow_offset = Vector2(0, maxf(2, size * 0.05))
	return l


static func painted_title(slug: String, height := 120.0, tone := "light") -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(TITLES_DIR % [slug, tone])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_size: Vector2 = t.texture.get_size()
	t.custom_minimum_size = Vector2(tex_size.x * height / tex_size.y, height)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func button(text: String, kind := "primary", hint := "", _icon_name := "", size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	var base := "button_primary_" if kind == "primary" else "button_paper_"
	var boxes := {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := box(base + state)
		s.content_margin_left = 26
		s.content_margin_right = 104 if hint != "" else 26
		s.content_margin_top = 12
		s.content_margin_bottom = 16
		boxes[state] = s
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("hover_pressed", boxes.pressed)
	b.add_theme_stylebox_override("focus", boxes.hover)
	b.add_theme_font_override("font", font("display", 900))
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", LABEL)
	if hint != "":
		var c := chip(hint)
		b.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	return b


static func chip(text: String, bg := PAPER, fg := INK, size := 16, _border := 3) -> PanelContainer:
	var p := PanelContainer.new()
	var s = box("chip", bg)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 7 if str(s.look).begins_with("key") else 3
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, maxi(size, 15), text_on(s, fg), "body", 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func pill(text: String, bg: Color, size := 17, icon_name := "") -> PanelContainer:
	var p := PanelContainer.new()
	var s := box("pill", bg)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var fg := text_on(s, INK)
	var row := hbox(8)
	if icon_name != "":
		row.add_child(icon(icon_name, size + 8, fg))
	row.add_child(label(text, maxi(size, 16), fg, "body", 900, true))
	p.add_child(row)
	return p


static func action_tile(key: String, icon_name: String, bg: Color, caption: String) -> VBoxContainer:
	var col := vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var tile := PanelContainer.new()
	var ts = box("tile", bg, 0)
	tile.add_theme_stylebox_override("panel", ts)
	tile.custom_minimum_size = Vector2(92, 92)
	var ic := icon(icon_name, 56, PAPER if ts.is_dark() else INK)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(ic)
	var badge := chip(key)
	tile.add_child(badge)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(tile)
	var cap := panel(Color(INK, 0.8), 8, 0, 0, 0, INK, "plate")
	var cs := cap.get_theme_stylebox("panel")
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 2
	cs.content_margin_bottom = 4
	cap.add_child(label(caption, 17, PAPER, "body", 800))
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cap)
	return col


static func icon_texture(name: String, _size := 28, color := INK) -> Texture2D:
	var file := name
	if ICON_FILES.has(name):
		file = ICON_FILES[name][1 if color.get_luminance() > 0.5 else 0]
	var path := ICONS_DIR % file
	if ResourceLoader.exists(path):
		return load(path)
	if _blank == null:
		_blank = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	return _blank


static func power_icon(power: String, state := "on") -> Texture2D:
	return load(ICONS_DIR % ("power_%s_%s" % [POWER_ICONS.get(power, power), state]))


static func icon(name: String, size := 28, color := INK) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name, size, color)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func hbox(sep := 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep := 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func rule(color := INK, _thickness := 4) -> Control:
	var r := Panel.new()
	r.add_theme_stylebox_override("panel", box("rule", color))
	r.custom_minimum_size = Vector2(0, 8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func backdrop(color := NIGHT) -> Control:
	if color.a < 0.99:
		var r := ColorRect.new()
		r.color = color
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		return r
	var t := TextureRect.new()
	t.texture = load(TEXTURES_DIR % ("stone" if color.get_luminance() < Paint.DARK_LUMINANCE else "paper"))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	return t


static func vignette(tint: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5));\n\tCOLOR = vec4(tint.rgb, tint.a * smoothstep(0.32, 0.72, d));\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	r.material = m
	return r
