class_name CleanShop
extends CanvasLayer
## Upgrade-Laden: alle Upgrades mit Stufe, Wirkung und Preis, dazu die gefundenen Sammelobjekte.
## Öffnet mit U, pausiert das Spiel solange. Alles kommt aus dem Spielstand (CleanGameState).

signal buy_requested(id: String)

var state: CleanGameState
var _books_title: Label
var _coins_label: Label
var _rows: VBoxContainer
var _books_label: Label
var _close_button: Button
var _title_font: Font


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_title_font = CleanTheme.title_font(state.config)
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.01, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.theme = CleanTheme.build(state.config)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label(head, 34, "Upgrade-Laden", true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", state.config.ui_accent_color.lightened(0.25))
	_coins_label = _label(head, 28, "", true)
	_coins_label.add_theme_color_override("font_color", state.config.ui_accent_color.lightened(0.3))
	box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	box.add_child(HSeparator.new())
	_books_title = _label(box, 22, "", true)
	_books_label = _label(box, 16, "")

	_close_button = Button.new()
	_close_button.text = "Zurück (U)"
	_close_button.custom_minimum_size = Vector2(0, 44)
	_close_button.add_theme_font_size_override("font_size", 20)
	if _title_font:
		_close_button.add_theme_font_override("font", _title_font)
	_close_button.pressed.connect(close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_shop")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	_close_button.release_focus()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	var config := state.config
	_coins_label.text = "%s %s" % [CleanHud._format_number(state.coins), config.currency_name]
	for child in _rows.get_children():
		child.queue_free()
	var odd := false
	for u in config.upgrades:
		var level := state.level(u.id)
		# Jede Zeile auf einer eigenen, abwechselnd getönten Leiste
		var strip := PanelContainer.new()
		var strip_style := StyleBoxFlat.new()
		strip_style.bg_color = Color(1, 0.9, 0.7, 0.06 if odd else 0.025)
		strip_style.set_corner_radius_all(6)
		strip_style.set_content_margin_all(8)
		strip.add_theme_stylebox_override("panel", strip_style)
		_rows.add_child(strip)
		odd = not odd
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		strip.add_child(row)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var level_text := "Stufe %d / %d" % [level, u.max_level] if u.max_level > 1 else ""
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 14)
		text.add_child(name_row)
		_label(name_row, 20, u.display_name)
		if level_text != "":
			var level_label := _label(name_row, 15, level_text)
			level_label.add_theme_color_override("font_color", config.ui_accent_color)
			level_label.size_flags_vertical = Control.SIZE_SHRINK_END
		var info := _label(text, 15, u.info)
		info.modulate = Color(1, 1, 1, 0.7)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 40)
		button.add_theme_font_size_override("font_size", 18)
		match state.buy_block_reason(u):
			"found":
				button.text = "Schon gefunden"
				button.disabled = true
			"max":
				button.text = "Maximal" if u.max_level > 1 else "Gekauft"
				button.disabled = true
			var reason:
				button.text = "Kaufen: %s" % CleanHud._format_number(u.cost(level))
				button.disabled = reason == "coins"
				var id := u.id
				button.pressed.connect(func() -> void: buy_requested.emit(id))
		row.add_child(button)

	_books_title.text = config.collectible_group_name
	_books_title.visible = not config.collectibles.is_empty()
	var lines: Array[String] = []
	for c in config.collectibles:
		if state.has_found(c.id):
			lines.append("Gefunden: %s  (%s)" % [c.display_name, c.perk_text])
		else:
			lines.append("???  Noch irgendwo versteckt")
	_books_label.text = "\n".join(lines)


func _label(parent: Control, font_size: int, text: String, title := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if title and _title_font:
		label.add_theme_font_override("font", _title_font)
	parent.add_child(label)
	return label
