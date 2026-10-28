class_name CleanMap
extends CanvasLayer
## Karte aller Zonen (Taste M): Grundrisse mit Fortschritt, gesperrte Zonen grau, die Spielfigur als Pfeil.
## Ein Klick auf eine offene Zone bringt die Figur dorthin (Zonenauswahl).

signal travel_requested(zone: CleanZone)

var game: CleanGame   # vor add_child setzen
var _canvas: Control
var _title_font: Font
var _body_font: Font
var _hover: CleanZone


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title_font = CleanTheme.title_font(game.config)
	var theme := CleanTheme.build(game.config)
	_body_font = theme.default_font if theme.default_font else ThemeDB.fallback_font

	var overlay := ColorRect.new()
	overlay.color = game.config.ui_overlay_color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.theme = theme
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Karte"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", game.config.ui_accent_color.lightened(0.25))
	if _title_font:
		title.add_theme_font_override("font", _title_font)
	box.add_child(title)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(900, 560)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	box.add_child(_canvas)

	var hint := Label.new()
	hint.text = "Klick auf einen offenen %s: dorthin gehen   ·   M oder Esc: schließen" % game.config.zone_word
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_map")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_canvas.queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Zonen mit bekannter Grundfläche (die erste Zone nimmt config.zone_bounds).
func _mapped_zones() -> Array[CleanZone]:
	var list: Array[CleanZone] = []
	for z in game.zones:
		if _rect_of(z).has_area():
			list.append(z)
	return list


func _rect_of(z: CleanZone) -> Rect2:
	if z == game.zones[0]:
		return game.config.zone_bounds
	return z.bounds


## Rechnet Weltkoordinaten (x, z) in Bildpunkte der Karte um.
func _transform() -> Transform2D:
	var world := Rect2()
	var first := true
	for z in _mapped_zones():
		world = _rect_of(z) if first else world.merge(_rect_of(z))
		first = false
	world = world.grow(1.5)
	var area := _canvas.size
	var s := minf(area.x / world.size.x, area.y / world.size.y)
	var offset := (area - world.size * s) * 0.5 - world.position * s
	return Transform2D(0.0, Vector2(s, s), 0.0, offset)


func _draw_map() -> void:
	var zones := _mapped_zones()
	if zones.is_empty():
		_canvas.draw_string(_body_font, Vector2(20, 40), "Für dieses Spiel gibt es keine Karte.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		return
	var xf := _transform()
	var accent := game.config.ui_accent_color
	for z in zones:
		var r := _rect_of(z)
		var rect := Rect2(xf * r.position, r.size * xf.get_scale())
		var percent := z.progress_percent()
		if z.unlocked:
			var base := Color(game.config.ui_panel_color, 0.95)
			var fill := base.lightened(0.04).lerp(base.lightened(0.22), percent / 100.0)
			_canvas.draw_rect(rect, fill)
			# Fortschritt als Balken am unteren Rand
			var bar := Rect2(rect.position + Vector2(10, rect.size.y - 18), Vector2((rect.size.x - 20) * percent / 100.0, 8))
			_canvas.draw_rect(Rect2(bar.position, Vector2(rect.size.x - 20, 8)), Color(0, 0, 0, 0.5))
			_canvas.draw_rect(bar, accent)
		else:
			_canvas.draw_rect(rect, Color(0.12, 0.12, 0.12, 0.9))
		var border := accent.lightened(0.3) if z == _hover and z.unlocked else Color(accent, 0.7)
		_canvas.draw_rect(rect, border, false, 3.0 if z == _hover else 1.5)
		var name_font := _title_font if _title_font else _body_font
		var text_pos := rect.position + Vector2(12, 30)
		_canvas.draw_string(name_font, text_pos, z.display_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 22, game.config.ui_text_color)
		var info := "%.1f %% sauber" % percent if z.unlocked else "Gesperrt\nÖffnen im Upgrade-Laden"
		for extra in z.layers:
			if z.unlocked and extra.remaining > 0 and extra.display_name != "":
				info += "\n%s: %d übrig" % [extra.display_name, extra.remaining]
		var loose := z.pickups.filter(func(pickup: CleanPickup) -> bool: return not pickup.done).size()
		if z.unlocked and loose > 0:
			info += "\n%s: %d übrig" % [game.config.pickup_name, loose]
		var line := 0
		for part in info.split("\n"):
			_canvas.draw_string(_body_font, text_pos + Vector2(0, 26 + line * 20), part, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 16, Color(game.config.ui_text_color, 0.8))
			line += 1
	# Roboter als kleine Punkte, Spielfigur als Pfeil
	for bot: Node3D in game.all_bots():
		_canvas.draw_circle(xf * Vector2(bot.global_position.x, bot.global_position.z), 3.0, Color(0.6, 0.85, 1.0, 0.9))
	var p := game.player.global_position
	var at := xf * Vector2(p.x, p.z)
	var fwd3 := -game.player.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var tip := at + fwd * 14.0
	_canvas.draw_colored_polygon(PackedVector2Array([tip, at - fwd * 7.0 + side * 8.0, at - fwd * 3.0, at - fwd * 7.0 - side * 8.0]), Color(1.0, 0.95, 0.85))


func _zone_under(pos: Vector2) -> CleanZone:
	var world := _transform().affine_inverse() * pos
	var found: CleanZone = null
	for z in _mapped_zones():
		if _rect_of(z).has_point(world):
			found = z   # spätere Zonen gehen vor
	return found


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var z := _zone_under((event as InputEventMouseMotion).position)
		if z != _hover:
			_hover = z
			_canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var z := _zone_under((event as InputEventMouseButton).position)
		if z and z.unlocked:
			close()
			travel_requested.emit(z)
