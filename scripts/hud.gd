extends CanvasLayer
## Anzeige: Fortschritt der Zone, Münzen, Upgrade, Steuerung und kurze Meldungen.

var _zone_label: Label
var _progress: ProgressBar
var _coins_label: Label
var _upgrade_label: Label
var _toast: Label
var _toast_tween: Tween
var _start_overlay: Control


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Oben mittig: Zone und Fortschrittsbalken
	var top := _panel(root)
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
	_coins_label = _label(root, 30)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_anchor(_coins_label, 1.0, 0.0, 1.0, 0.0, -360, 20, -24, 64)

	# Unten rechts: Upgrade
	var up := _panel(root)
	_anchor(up, 1.0, 1.0, 1.0, 1.0, -440, -130, -20, -20)
	_upgrade_label = _label(up, 18)
	_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Unten links: Steuerung
	var help := _label(root, 15)
	help.text = "WASD laufen · Shift rennen · Leertaste springen\nLinke Maustaste halten: wedeln\nU oder E: Upgrade kaufen · Esc: Maus freigeben"
	help.modulate = Color(1, 1, 1, 0.75)
	_anchor(help, 0.0, 1.0, 0.0, 1.0, 20, -90, 520, -20)

	# Fadenkreuz
	var cross := ColorRect.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.color = Color(1, 1, 1, 0.8)
	_anchor(cross, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)
	root.add_child(cross)

	# Meldungen unter der Bildmitte
	_toast = _label(root, 26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	_anchor(_toast, 0.15, 0.62, 0.85, 0.62, 0, 0, 0, 90)

	# Startbildschirm, solange die Maus nicht gefangen ist
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var title := _label(overlay, 48)
	title.text = "Bibliothek entstauben\n\n[ Klicken zum Spielen ]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_overlay = overlay


func _process(_delta: float) -> void:
	_start_overlay.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


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


func toast(message: String, duration := 2.5) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


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
