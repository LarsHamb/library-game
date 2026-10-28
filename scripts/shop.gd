extends CanvasLayer
## Upgrade-Laden: alle Upgrades mit Stufe, Wirkung und Preis, dazu die gefundenen seltenen Bücher.
## Öffnet mit U, pausiert das Spiel solange.

signal buy_requested(id: String)

const Upgrades := preload("res://scripts/upgrades.gd")

var _coins_label: Label
var _rows: VBoxContainer
var _books_label: Label
var _close_button: Button


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	style.border_color = Color(0.75, 0.58, 0.3)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label(head, 32, "Upgrade-Laden")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins_label = _label(head, 26, "")
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)

	box.add_child(HSeparator.new())
	_label(box, 22, "Seltene Bücher")
	_books_label = _label(box, 16, "")

	_close_button = Button.new()
	_close_button.text = "Zurück zum Putzen (U)"
	_close_button.custom_minimum_size = Vector2(0, 44)
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.pressed.connect(close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_shop")):
		close()
		get_viewport().set_input_as_handled()


func open(coins: int, levels: Dictionary, books_found: Array[String], vacuum_from_book: bool) -> void:
	refresh(coins, levels, books_found, vacuum_from_book)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	_close_button.release_focus()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh(coins: int, levels: Dictionary, books_found: Array[String], vacuum_from_book: bool) -> void:
	_coins_label.text = "%d Münzen" % coins
	for child in _rows.get_children():
		child.queue_free()
	for u: Dictionary in Upgrades.UPGRADES:
		var id: String = u["id"]
		var level: int = levels.get(id, 0)
		var max_level: int = u["max"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_rows.add_child(row)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var level_text := "Stufe %d / %d" % [level, max_level] if max_level > 1 else ""
		_label(text, 20, "%s   %s" % [u["name"], level_text])
		var info := _label(text, 15, u["info"])
		info.modulate = Color(1, 1, 1, 0.75)

		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 40)
		button.add_theme_font_size_override("font_size", 18)
		if id == "vacuum" and vacuum_from_book:
			button.text = "Durch Buch frei"
			button.disabled = true
		elif level >= max_level:
			button.text = "Maximal"
			button.disabled = true
		else:
			var price := Upgrades.cost(u, level)
			button.text = "Kaufen: %d" % price
			button.disabled = coins < price
			button.pressed.connect(func() -> void: buy_requested.emit(id))
		row.add_child(button)

	var lines: Array[String] = []
	for b: Dictionary in Upgrades.BOOKS:
		if books_found.has(b["id"]):
			lines.append("Gefunden: %s  (%s)" % [b["name"], b["perk"]])
		else:
			lines.append("???  Noch irgendwo unter dem Staub versteckt")
	_books_label.text = "\n".join(lines)


func _label(parent: Control, font_size: int, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
