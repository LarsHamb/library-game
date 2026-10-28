class_name CleanTheme
extends RefCounted
## Einheitliches Aussehen für Anzeige, Menü und Laden: dunkle, halbtransparente Tafeln mit Goldrand,
## cremefarbene Schrift. Farben und Schriften kommen aus der CleanGameConfig.


static func build(config: CleanGameConfig) -> Theme:
	var t := Theme.new()
	var body := _load_font(config.ui_body_font)
	if body:
		t.default_font = body
	t.default_font_size = 18
	var text := config.ui_text_color
	var accent := config.ui_accent_color
	var bg := config.ui_panel_color

	t.set_color("font_color", "Label", text)
	t.set_color("font_outline_color", "Label", config.ui_outline_color)
	t.set_constant("outline_size", "Label", 5)

	var panel := _box(bg, accent, 2, 10)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 10
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var normal := _box(bg.lightened(0.12), accent.darkened(0.35), 1, 6)
	var hover := _box(bg.lightened(0.22), accent, 2, 6)
	var pressed := _box(accent.darkened(0.25), accent.lightened(0.2), 2, 6)
	var disabled := _box(bg.darkened(0.2), Color(0.4, 0.35, 0.3, 0.5), 1, 6)
	var focus := _box(Color(0, 0, 0, 0), accent.lightened(0.3), 2, 6)
	focus.draw_center = false
	for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
		sb.set_content_margin_all(10)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", accent.lightened(0.4))
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.06, 0.03))
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5, 0.6))
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_color("font_color", "OptionButton", text)

	var bar_bg := _box(Color(0, 0, 0, 0.55), accent.darkened(0.4), 1, 6)
	var bar_fill := _box(accent, accent.lightened(0.3), 1, 6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var slider := _box(Color(0, 0, 0, 0.5), accent.darkened(0.4), 1, 4)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", _box(accent.darkened(0.2), accent, 1, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(accent, accent.lightened(0.3), 1, 4))

	var sep := StyleBoxLine.new()
	sep.color = accent.darkened(0.3)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	var popup := _box(bg, accent, 1, 6)
	popup.set_content_margin_all(8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", text)
	return t


## Tafel für die Anzeige im Spiel: durchsichtiger und mit feinem Rand.
static func hud_panel(config: CleanGameConfig) -> StyleBoxFlat:
	var bg := config.ui_panel_color
	bg.a *= 0.75
	var sb := _box(bg, Color(config.ui_accent_color, 0.55), 1, 8)
	sb.set_content_margin_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


static func title_font(config: CleanGameConfig) -> Font:
	return _load_font(config.ui_title_font)


static func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func _load_font(path: String) -> Font:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
