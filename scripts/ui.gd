extends RefCounted
## Cartoon UI kit from the "ВІДПУСТИ — UI" design (board 15): ink outlines, offset shadows, flat colors, no gradients.
## Usage: const UI = preload("res://scripts/ui.gd"); UI.panel(UI.PAPER), UI.label(...), UI.button(...).
## Base resolution is 1920x1080 (design px = Godot px).

const INK := Color("17111C")
const PAPER := Color("FFFDF8")
const NIGHT := Color("1E1238")
const NIGHT2 := Color("2A1D40")
const GOLD := Color("FFC531")  ## main action, memories
const CHARGE := Color("B48CFF")
const CYAN := Color("9BF6FF")  ## level 1 / fade
const MOM := Color("FF8FB1")  ## level 3 / Mom
const RED := Color("FF4D5E")  ## hunters
const GREEN := Color("8BEA4E")  ## believers, done
const ORANGE := Color("FF7A1A")  ## warnings, focus
const LILAC := Color("EDE6FF")  ## empty slots
const GREY := Color("D9D4E8")  ## disabled
const MUTED := Color("4A3378")  ## secondary text on paper
const LABEL := Color("6B4FA0")  ## small caps labels on paper
const DIM := Color("C9C2E8")  ## secondary text on dark
const SHADE := Color(0.09, 0.067, 0.11, 0.9)  ## dark translucent panels
const LEVEL_COLORS := [Color.WHITE, CYAN, GOLD, MOM]
const LABEL_NEAR := 2.0  ## m: world labels keep their full size up to here, then shrink with distance (world_label)

## Inline stroke icons (24x24 viewBox), drawn in `color` by icon().
const ICONS := {
	"ghost": '<path d="M5 20V10a7 7 0 0 1 14 0v10l-2.5-2-2.3 2-2.2-2-2.2 2-2.3-2Z"/><circle cx="9.5" cy="10" r="1.2" fill="#C"/><circle cx="14.5" cy="10" r="1.2" fill="#C"/>',
	"ghost_dashed": '<path d="M5 20V10a7 7 0 0 1 14 0v10l-2.5-2-2.3 2-2.2-2-2.2 2-2.3-2Z" stroke-dasharray="3 2.5"/>',
	"bolt": '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z" fill="#B48CFF"/>',
	"hand": '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 6.5a1.5 1.5 0 0 1 3 0V12M14 7.5a1.5 1.5 0 0 1 3 0V14a6 6 0 0 1-6 6h-1a6 6 0 0 1-5.2-3L3.4 14a1.5 1.5 0 0 1 2.5-1.6L8 15"/>',
	"play": '<path d="M7 4v16l13-8Z" fill="#C"/>',
	"warn": '<path d="M12 3 2 20h20Z"/><path d="M12 10v4M12 17h.01"/>',
	"moon": '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5Z" fill="#C"/>',
	"candle": '<path d="M9 21V11h6v10Z"/><path d="M12 8c-1.5-1.2-1.5-3 0-5 1.5 2 1.5 3.8 0 5Z" fill="#C"/>',
	"lock": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
	"eye": '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
	"search": '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
	"exit": '<path d="M14 3H6v18h8"/><path d="M10 12h11M17 8l4 4-4 4"/>',
	"sliders": '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7"/>',
	"photo": '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M21 16l-5-5-8 8"/>',
	"heart": '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10Z"/>',
	"map": '<path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3Z"/><path d="M9 3v15M15 6v15"/>',
	"restart": '<path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/>',
	"speaker": '<path d="M4 9v6h4l5 4V5L8 9Z"/><path d="M16.5 8.5a5 5 0 0 1 0 7"/>',
}

static var _fonts := {}
static var _icons := {}


## kind: "display" (titles, Rubik Wet Paint), "body" (Rubik), "hand" (Caveat, ghost thoughts).
# shortcut: SystemFont falls back to Windows fonts (Segoe UI Black / Segoe Print); ship Rubik + Caveat .ttf in res://fonts for exact looks.
static func font(kind := "body", weight := 800) -> Font:
	var key := "%s%d" % [kind, weight]
	if not _fonts.has(key):
		var names := {
			"display": ["Rubik Wet Paint", "Rubik", "Segoe UI Black", "Arial Black"],
			"hand": ["Caveat", "Segoe Print", "Comic Sans MS"],
		}
		var f := SystemFont.new()
		f.font_names = PackedStringArray(names.get(kind, ["Rubik", "Segoe UI", "Arial"]))
		f.font_weight = weight
		_fonts[key] = f
	return _fonts[key]


## Sizes a fixed_size Label3D every frame: `px` (its pixel_size) up to LABEL_NEAR m from the camera, smaller further
## off like the thing it names, so far labels stay small and near ones never grow huge.
static func world_label(l: Label3D, px: float) -> void:
	var cam := l.get_viewport().get_camera_3d()
	if cam:
		l.pixel_size = px * minf(1.0, LABEL_NEAR / maxf(cam.global_position.distance_to(l.global_position), 0.01))


## Flat box: `shadow` = solid offset shadow to the bottom-right; `drop` = shadow straight down (buttons).
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


static func panel(bg := PAPER, radius := 26, shadow := 7, pad := 20, border := 5, border_color := INK) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(bg, radius, border, shadow, border_color)
	s.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", s)
	return p


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


## Big painted title: white fill, thick ink outline, offset ink shadow.
static func title(text: String, size := 110, color := PAPER) -> Label:
	var l := label(text, size, color, "display", 900)
	var ls := l.label_settings
	ls.outline_size = maxi(4, int(size * 0.08))
	ls.outline_color = INK
	ls.shadow_size = ls.outline_size
	ls.shadow_color = INK
	ls.shadow_offset = Vector2.ONE * maxf(3, size * 0.06)
	return l


## kind: "primary" (gold), "secondary" (paper), "ghost" (dark, outlined). `hint` = key chip on the right.
static func button(text: String, kind := "primary", hint := "", icon_name := "", size := 30) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	var ghost := kind == "ghost"
	var bg: Color = {"primary": GOLD, "secondary": PAPER}.get(kind, Color(0, 0, 0, 0))
	var fg := PAPER if ghost else INK
	var normal := style(bg, 22, 4 if ghost else 5, 0, PAPER if ghost else INK, 0 if ghost else 8)
	normal.content_margin_left = 24
	normal.content_margin_right = 96 if hint != "" else 24
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.1) if ghost else bg.lightened(0.18)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.shadow_offset = Vector2(0, 2)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(4)
	focus.border_color = ORANGE
	focus.set_corner_radius_all(26)
	focus.set_expand_margin_all(6)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = GREY
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_font_override("font", font("body", 900))
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", MUTED)
	if icon_name != "":
		b.icon = icon_texture(icon_name, size, fg)
		b.add_theme_constant_override("h_separation", 16)
	if hint != "":
		var c := chip(hint)
		b.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	return b


## Small key / tag chip ("Enter", "E", "Esc").
static func chip(text: String, bg := PAPER, fg := INK, size := 16, border := 3) -> PanelContainer:
	var p := panel(bg, 9, 0, 0, border)
	var s := p.get_theme_stylebox("panel") as StyleBoxFlat
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_child(label(text, size, fg, "body", 900))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Rounded tag with optional icon ("1 · Тінь", "Мисливець · шукає").
static func pill(text: String, bg: Color, size := 17, icon_name := "") -> PanelContainer:
	var p := panel(bg, 999, 4, 0, 4)
	var s := p.get_theme_stylebox("panel") as StyleBoxFlat
	s.shadow_offset = Vector2(4, 4)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	var row := hbox(8)
	if icon_name != "":
		row.add_child(icon(icon_name, size + 3))
	row.add_child(label(text, size, INK, "body", 900, true))
	p.add_child(row)
	return p


## Square key button from the HUD ("E", "Q"): colored tile, key badge, icon, caption under it.
static func action_tile(key: String, icon_name: String, bg: Color, caption: String) -> VBoxContainer:
	var col := vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var tile := panel(bg, 22, 0, 0)
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_offset = Vector2(0, 6)
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_color = INK
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 1
	tile.custom_minimum_size = Vector2(92, 92)
	var ic := icon(icon_name, 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(ic)
	var badge := chip(key, INK, PAPER, 16, 0)
	tile.add_child(badge)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.position = Vector2(-8, -12)
	col.add_child(tile)
	var cap := panel(Color(INK, 0.8), 8, 0, 0, 0)
	(cap.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(cap.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
	cap.add_child(label(caption, 15, PAPER, "body", 800))
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cap)
	return col


static func icon_texture(name: String, size := 28, color := INK) -> Texture2D:
	var key := "%s%d%s" % [name, size, color.to_html()]
	if not _icons.has(key):
		var hex := "#" + color.to_html(false)
		var body: String = ICONS.get(name, "").replace("#C", hex)
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [hex, body]
		var img := Image.new()
		img.load_svg_from_string(svg, size / 24.0)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


static func icon(name: String, size := 28, color := INK) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name, size, color)
	t.custom_minimum_size = Vector2(size, size)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
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


## Ink divider (the design's dashed rule, drawn solid).
static func rule(color := INK, thickness := 4) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Full-rect solid background.
static func backdrop(color := NIGHT) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


## Full-rect edge glow (the design's inset box-shadow): tint at the edges, clear centre.
static func vignette(tint: Color) -> ColorRect:
	var r := backdrop(Color.WHITE)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5));\n\tCOLOR = vec4(tint.rgb, tint.a * smoothstep(0.32, 0.72, d));\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	r.material = m
	return r
