extends RefCounted

const INK := Color("140B0C")
const PAPER := Color("EBDDC3")
const NIGHT := Color("1B1116")
const NIGHT2 := Color("2A1A20")
const CARD := Color(0.13, 0.075, 0.08, 0.95)
const CARD_HI := Color("3A2629")
const EDGE := Color("A07A3C")
const GLOW := Color(0.9, 0.55, 0.2, 0.3)
const NEON := Color("D26A9E")
const PUMPKIN := Color("D2782A")
const PUMPKIN_DARK := Color("6B3410")
const GOLD := Color("E0B060")
const CHARGE := Color("9C86C8")
const CYAN := Color("A8DCD8")
const MOM := Color("D98AA8")
const RED := Color("B5463C")
const GREEN := Color("A8C070")
const ORANGE := Color("D2782A")
const LILAC := Color("E6D5B8")
const GREY := Color("3A2C2C")
const MUTED := Color("BFA88A")
const LABEL := Color("A88F6E")
const DIM := Color("8C7A64")
const SHADE := Color(0.08, 0.045, 0.05, 0.9)
const TITLE_OUTLINE := Color("1A0E08")
const HORIZON := Color(0.42, 0.18, 0.2)
const HILLS_FAR := Color(0.16, 0.09, 0.1)
const HILLS_NEAR := Color(0.09, 0.05, 0.06)
const LEVEL_COLORS := [Color.WHITE, CYAN, GOLD, MOM]
const MAX_BORDER := 3
const SECONDARY_EDGE := Color("1A0E0A")
const CARD_TEXTURE := "res://art/ui/card9.png"
const CARD_TEXTURE_MARGIN := 27
const PLANK_TEXTURE := "res://art/ui/plank9.png"
const PLANK_MARGIN := Vector2(24, 18)
const PARCHMENT_TEXTURE := "res://art/ui/parchment.jpg"

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

const FONT_FILES := {
	"display": "res://fonts/Oranienbaum.ttf",
	"body": "res://fonts/OldStandard-Regular.ttf",
	"body_bold": "res://fonts/OldStandard-Bold.ttf",
	"hand": "res://fonts/BadScript.ttf",
}
const BOLD_FROM := 700

static var _fonts := {}
static var _icons := {}


static func font(kind := "body", weight := 800) -> Font:
	var key := "%s%d" % [kind, weight]
	if not _fonts.has(key):
		var names := {
			"display": ["Oranienbaum", "Georgia", "Times New Roman"],
			"hand": ["Bad Script", "Segoe Script", "Georgia"],
		}
		var system := SystemFont.new()
		system.font_names = PackedStringArray(names.get(kind, ["Old Standard TT", "Georgia", "Times New Roman"]))
		system.font_weight = weight
		_fonts[key] = system
		var file_kind := "body_bold" if kind == "body" and weight >= BOLD_FROM else kind
		var path: String = FONT_FILES.get(file_kind, FONT_FILES.body)
		if ResourceLoader.exists(path):
			var file := FontVariation.new()
			file.base_font = load(path)
			file.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			file.fallbacks = [system]
			_fonts[key] = file
	return _fonts[key]


static func style(bg: Color, radius := 26, border := 5, shadow := 0, border_color := EDGE, drop := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(mini(border, MAX_BORDER))
	s.border_color = border_color
	if shadow > 0 or drop > 0:
		s.shadow_color = GLOW
		s.shadow_size = 8 + maxi(shadow, drop) * 2
		s.shadow_offset = Vector2(0, maxi(shadow, drop) * 0.6)
	s.anti_aliasing = true
	return s


static func panel(bg := CARD, radius := 26, shadow := 7, pad := 20, border := 5, border_color := EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	if bg == CARD and ResourceLoader.exists(CARD_TEXTURE):
		p.add_theme_stylebox_override("panel", framed(pad))
		return p
	var s := style(bg, radius, border, shadow, border_color)
	s.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", s)
	return p


static func framed(pad := 20) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(CARD_TEXTURE)
	s.set_texture_margin_all(CARD_TEXTURE_MARGIN)
	s.set_content_margin_all(pad + CARD_TEXTURE_MARGIN * 0.6)
	return s


static func parchment(pad := 16) -> StyleBox:
	if not ResourceLoader.exists(PARCHMENT_TEXTURE):
		var flat := style(PAPER, 10, 0)
		flat.set_content_margin_all(pad)
		return flat
	var s := StyleBoxTexture.new()
	s.texture = load(PARCHMENT_TEXTURE)
	s.set_content_margin_all(pad)
	return s


static func plank(tint := Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(PLANK_TEXTURE)
	s.texture_margin_left = PLANK_MARGIN.x
	s.texture_margin_right = PLANK_MARGIN.x
	s.texture_margin_top = PLANK_MARGIN.y
	s.texture_margin_bottom = PLANK_MARGIN.y
	s.modulate_color = tint
	return s


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
	ls.outline_size = maxi(4, int(size * 0.07))
	ls.outline_color = TITLE_OUTLINE
	ls.shadow_size = maxi(6, int(size * 0.12))
	ls.shadow_color = Color(GOLD, 0.35)
	ls.shadow_offset = Vector2(0, maxf(3, size * 0.05))
	return l


static func button(text: String, kind := "primary", hint := "", icon_name := "", size := 30) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	var ghost := kind == "ghost"
	var primary := kind == "primary"
	var fg := GOLD if primary else PAPER
	var normal: StyleBox
	var hover: StyleBox
	var pressed: StyleBox
	var disabled: StyleBox
	if ghost:
		normal = style(Color(INK, 0.35), 10, 2, 0, Color(EDGE, 0.8))
		hover = style(Color(GOLD, 0.12), 10, 2, 0, GOLD)
		pressed = style(Color(GOLD, 0.2), 10, 2, 0, GOLD)
		disabled = style(Color(INK, 0.2), 10, 2, 0, GREY)
	else:
		var base := Color.WHITE if primary else Color(0.62, 0.55, 0.55)
		normal = plank(base)
		hover = plank(base.lightened(0.25))
		pressed = plank(base.darkened(0.25))
		disabled = plank(Color(0.4, 0.38, 0.38))
	for st: StyleBox in [normal, hover, pressed, disabled]:
		st.content_margin_left = 28
		st.content_margin_right = 96 if hint != "" else 28
		st.content_margin_top = 14
		st.content_margin_bottom = 14
	pressed.content_margin_top = 17
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = GOLD
	focus.set_corner_radius_all(8)
	focus.set_expand_margin_all(5)
	focus.shadow_color = Color(GOLD, 0.35)
	focus.shadow_size = 10
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


static func pill(text: String, bg: Color, size := 17, icon_name := "") -> PanelContainer:
	var p := panel(bg, 999, 4, 0, 4)
	var s := p.get_theme_stylebox("panel") as StyleBoxFlat
	s.shadow_color = Color(bg, 0.45)
	s.shadow_offset = Vector2(0, 3)
	s.border_color = bg.darkened(0.35)
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


static func action_tile(key: String, icon_name: String, bg: Color, caption: String) -> VBoxContainer:
	var col := vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var tile := panel(bg, 22, 0, 0)
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_offset = Vector2(0, 4)
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_color = GLOW
	(tile.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 14
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


static func rule(color := Color(EDGE, 0.6), thickness := 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static var _sky_shader: Shader


static func backdrop(color := NIGHT) -> ColorRect:
	return sky(color, 0.0, 0.0)


static func sky(color := NIGHT, moon_size := 0.0, hills := 0.0, moon := Vector2(0.8, 0.2)) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not _sky_shader:
		_sky_shader = load("res://shaders/night_sky.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _sky_shader
	m.set_shader_parameter("top", color.darkened(0.45))
	m.set_shader_parameter("mid", color)
	m.set_shader_parameter("horizon", HORIZON)
	m.set_shader_parameter("far_hills", HILLS_FAR)
	m.set_shader_parameter("near_hills", HILLS_NEAR)
	m.set_shader_parameter("alpha", color.a)
	m.set_shader_parameter("moon", moon)
	m.set_shader_parameter("moon_size", moon_size)
	m.set_shader_parameter("hills", hills)
	r.material = m
	return r


static func picture(art_name: String, dim := 0.0, fallback := NIGHT) -> Control:
	var path := "res://art/ui/%s.jpg" % art_name
	if not ResourceLoader.exists(path):
		return sky(fallback, 0.06, 1.0)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var t := TextureRect.new()
	t.texture = load(path)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(t)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(INK, dim)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	return root


static func side_shade(width := 0.6, strength := 0.8) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(INK, strength))
	g.set_color(1, Color(INK, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_to = Vector2(1, 0)
	var t := TextureRect.new()
	t.texture = tex
	t.anchor_bottom = 1.0
	t.anchor_right = width
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func svg(source: String, width: float) -> TextureRect:
	var img := Image.new()
	var native := float(source.get_slice('width="', 1).get_slice('"', 0))
	img.load_svg_from_string(source, width / maxf(native, 1.0))
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


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
