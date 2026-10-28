extends CanvasLayer
## Anzeige: Fortschritt der Zone, Münzen, Upgrade, Steuerung, Meldungen und das Pause-Menü.
## Läuft auch während der Pause weiter (process_mode = ALWAYS).

signal settings_changed(mouse_sensitivity: float, volume: float)

const SETTINGS_PATH := "user://settings.cfg"

var mouse_sensitivity := 0.0025
var volume := 0.8

var _zone_label: Label
var _progress: ProgressBar
var _coins_label: Label
var _upgrade_label: Label
var _radar_label: Label
var _toast: Label
var _toast_tween: Tween
var _coins_tween: Tween
var _menu: Control
var _menu_button: Button
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Oben mittig: Zone und Fortschrittsbalken
	var top := _panel(_root)
	_anchor(top, 0.5, 0.0, 0.5, 0.0, -280, 16, 280, 90)
	var top_box := VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_box)
	_zone_label = _label(top_box, 22)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.78, 0.35)
	fill.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("fill", fill)
	top_box.add_child(_progress)

	# Oben rechts: Münzen
	_coins_label = _label(_root, 30)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_anchor(_coins_label, 1.0, 0.0, 1.0, 0.0, -360, 20, -24, 64)

	# Unten rechts: Upgrade und Radar
	var up := _panel(_root)
	_anchor(up, 1.0, 1.0, 1.0, 1.0, -440, -160, -20, -20)
	var up_box := VBoxContainer.new()
	up_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(up_box)
	_upgrade_label = _label(up_box, 18)
	_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radar_label = _label(up_box, 16)
	_radar_label.modulate = Color(1, 1, 1, 0.85)

	# Unten links: Steuerung
	var help := _label(_root, 15)
	help.text = "WASD laufen · Shift rennen · Leertaste springen\nLinke Maustaste halten: wedeln · An Leitern: W hoch, S runter\nU: Upgrade · R: Staub-Radar · Esc: Menü"
	help.modulate = Color(1, 1, 1, 0.75)
	_anchor(help, 0.0, 1.0, 0.0, 1.0, 20, -90, 620, -20)

	# Fadenkreuz
	var cross := ColorRect.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.color = Color(1, 1, 1, 0.8)
	_anchor(cross, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)
	_root.add_child(cross)

	# Meldungen unter der Bildmitte
	_toast = _label(_root, 26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	_anchor(_toast, 0.15, 0.62, 0.85, 0.62, 0, 0, 0, 90)

	_build_menu()
	open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Fenster verliert den Fokus (Alt+Tab) -> Spiel pausieren
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _menu and not _menu.visible:
		open_menu()


func open_menu() -> void:
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_button.grab_focus()


func close_menu() -> void:
	_menu.visible = false
	_menu_button.text = "Weiter"
	_menu_button.release_focus()   # sonst löst die Leertaste den Knopf statt Springen aus
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_values(zone: String, percent: float, coins: int, tool_name: String, level: int, radius: float, next_cost: int) -> void:
	_zone_label.text = "%s – %.1f %% entstaubt" % [zone, percent]
	_progress.value = percent
	_coins_label.text = "%s Münzen" % _format_number(coins)
	var text := "Werkzeug: %s (Stufe %d)\nWedel-Radius: %.2f m\n" % [tool_name, level + 1, radius]
	if next_cost < 0:
		text += "Maximale Stufe erreicht!"
	elif coins >= next_cost:
		text += "[U] Upgrade kaufen: %s Münzen" % _format_number(next_cost)
	else:
		text += "Nächstes Upgrade: %s Münzen" % _format_number(next_cost)
	_upgrade_label.text = text


func set_radar(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_radar_label.text = "[R] Staub-Radar bereit"
	else:
		_radar_label.text = "Staub-Radar lädt … %d s" % ceili(seconds_left)


func toast(message: String, duration := 2.5) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


## "+12" fliegt vom Fadenkreuz zum Münzzähler, der dann kurz hüpft.
func coin_popup(amount: int) -> void:
	var pop := _label(_root, 24)
	pop.text = "+%d" % amount
	pop.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	var screen := _root.get_viewport_rect().size
	var start := screen * 0.5 + Vector2(randf_range(-20.0, 20.0), -40.0)
	pop.position = start
	var target := _coins_label.global_position + Vector2(_coins_label.size.x - 60.0, 4.0)
	var tween := create_tween()
	tween.tween_property(pop, "position", start + Vector2(0, -30), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pop, "position", target, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(pop, "modulate:a", 0.3, 0.45)
	tween.tween_callback(pop.queue_free)
	tween.tween_callback(_bump_coins)


func _bump_coins() -> void:
	_coins_label.pivot_offset = _coins_label.size * Vector2(1.0, 0.5)
	if _coins_tween:
		_coins_tween.kill()
	_coins_label.scale = Vector2.ONE * 1.18
	_coins_tween = create_tween()
	_coins_tween.tween_property(_coins_label, "scale", Vector2.ONE, 0.2)


# ---------------------------------------------------------------- Pause-Menü

func _build_menu() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	_menu = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := _label(box, 48)
	title.text = "Bibliothek entstauben"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_menu_button = _button(box, "Spielen")
	_menu_button.pressed.connect(close_menu)

	var sens_label := _label(box, 18)
	var sens := _slider(box, 0.0005, 0.006, mouse_sensitivity)
	var vol_label := _label(box, 18)
	var vol := _slider(box, 0.0, 1.0, volume)
	var update_labels := func() -> void:
		sens_label.text = "Maus-Empfindlichkeit: %d %%" % roundi(mouse_sensitivity / 0.0025 * 100.0)
		vol_label.text = "Lautstärke: %d %%" % roundi(volume * 100.0)
	update_labels.call()
	sens.value_changed.connect(func(v: float) -> void:
		mouse_sensitivity = v
		update_labels.call()
		_apply_settings())
	vol.value_changed.connect(func(v: float) -> void:
		volume = v
		update_labels.call()
		_apply_settings())

	var quit := _button(box, "Beenden")
	quit.pressed.connect(func() -> void: get_tree().quit())
	_apply_settings.call_deferred()


func _apply_settings() -> void:
	settings_changed.emit(mouse_sensitivity, volume)
	var cfg := ConfigFile.new()
	cfg.set_value("steuerung", "maus", mouse_sensitivity)
	cfg.set_value("audio", "lautstaerke", volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("steuerung", "maus", mouse_sensitivity)
		volume = cfg.get_value("audio", "lautstaerke", volume)


# ---------------------------------------------------------------- Bausteine

func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	parent.add_child(b)
	return b


func _slider(parent: Control, min_value: float, max_value: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = (max_value - min_value) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	parent.add_child(s)
	return s


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.03, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	parent.add_child(label)
	return label


static func _anchor(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


static func _format_number(n: int) -> String:
	# 12345 -> "12.345"
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
