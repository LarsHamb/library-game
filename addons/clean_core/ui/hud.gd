class_name CleanHud
extends CanvasLayer
## Anzeige: Fortschritt der Zone, Münzen, Upgrade, Steuerung, Meldungen und das Pause-Menü.
## Läuft auch während der Pause weiter (process_mode = ALWAYS).

signal settings_changed(mouse_sensitivity: float, volume: float)
signal quality_changed(level: int)
signal music_changed(volume: float)
signal menu_opened
signal menu_closed
signal quit_requested
signal new_game_requested

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Niedrig", "Mittel", "Hoch"]
const HELP_SECONDS := 25.0   # so lange bleibt die Steuerungshilfe beim Start sichtbar

var config: CleanGameConfig   # vor add_child setzen
var mouse_sensitivity := 0.0025
var volume := 0.8
var music_volume := 0.6
var quality := 1              # 0 niedrig, 1 mittel, 2 hoch

var _zone_label: Label
var _progress: ProgressBar
var _rate_label: Label
var _coins_label: Label
var _carry_box: Control
var _carry_label: Label
var _carry_bar: ProgressBar
var _carry_full := false
var _upgrade_label: Label
var _radar_label: Label
var _toast_panel: PanelContainer
var _toast: Label
var _toast_tween: Tween
var _coins_tween: Tween
var _help: Label
var _prompt: Label
var _help_tween: Tween
var _menu: Control
var _menu_button: Button
var _menu_info: Label
var _root: Control
var _hud_items: Control
var _title_font: Font


## Ring-Fadenkreuz mit Punkt, damit man auf hellem und dunklem Grund sieht, wohin man zielt.
class Crosshair extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 9.0, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 3.5, true)
		draw_arc(c, 9.0, 0.0, TAU, 32, Color(1, 0.96, 0.88, 0.85), 1.5, true)
		draw_circle(c, 1.8, Color(1, 0.96, 0.88, 0.95))


## Münze als Symbol neben dem Münzzähler.
class CoinIcon extends Control:
	var color := Color(0.95, 0.75, 0.3)
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, color.darkened(0.45))
		draw_circle(c + Vector2(-1, -1), r - 2.0, color)
		draw_arc(c, r * 0.62, 0.0, TAU, 24, color.darkened(0.3), 2.0, true)
		draw_arc(c + Vector2(-1, -1), r - 3.0, PI * 1.05, PI * 1.6, 8, color.lightened(0.5), 2.0, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_title_font = CleanTheme.title_font(config)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CleanTheme.build(config)
	add_child(_root)
	# Alles, was beim Spielen eingeblendet ist; verschwindet hinter Menü, Laden und Karte
	_hud_items = Control.new()
	_hud_items.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud_items)

	# Oben mittig: Zone und Fortschrittsbalken
	var top := _panel(_hud_items)
	_anchor(top, 0.5, 0.0, 0.5, 0.0, -290, 14, 290, 118)
	var top_box := VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_constant_override("separation", 6)
	top.add_child(top_box)
	_zone_label = _label(top_box, 24, true)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 14)
	top_box.add_child(_progress)
	_rate_label = _label(top_box, 15)
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate_label.modulate = Color(1, 1, 1, 0.8)

	# Oben rechts: Münzen mit Symbol
	var coins_box := HBoxContainer.new()
	coins_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_box.alignment = BoxContainer.ALIGNMENT_END
	coins_box.add_theme_constant_override("separation", 10)
	_anchor(coins_box, 1.0, 0.0, 1.0, 0.0, -420, 18, -26, 66)
	_hud_items.add_child(coins_box)
	var icon := CoinIcon.new()
	icon.color = config.ui_accent_color.lightened(0.15)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_box.add_child(icon)
	_coins_label = _label(coins_box, 32, true)
	_coins_label.add_theme_color_override("font_color", config.ui_accent_color.lightened(0.3))

	# Darunter: Sack (nur wenn das Spiel einen hat)
	var carry := _panel(_hud_items)
	_anchor(carry, 1.0, 0.0, 1.0, 0.0, -290, 72, -20, 136)
	var carry_box := VBoxContainer.new()
	carry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_box.add_theme_constant_override("separation", 4)
	carry.add_child(carry_box)
	_carry_label = _label(carry_box, 17, true)
	_carry_bar = ProgressBar.new()
	_carry_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_bar.show_percentage = false
	_carry_bar.custom_minimum_size = Vector2(0, 12)
	carry_box.add_child(_carry_bar)
	_carry_box = carry
	carry.visible = false

	# Unten rechts: Werkzeug, Upgrade und Radar
	var up := _panel(_hud_items)
	_anchor(up, 1.0, 1.0, 1.0, 1.0, -440, -150, -20, -20)
	up.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var up_box := VBoxContainer.new()
	up_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(up_box)
	_upgrade_label = _label(up_box, 17)
	_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radar_label = _label(up_box, 16)
	_radar_label.add_theme_color_override("font_color", config.ui_accent_color.lightened(0.2))

	# Unten links: Steuerung (blendet sich nach einer Weile aus, F1 holt sie zurück)
	_help = _label(_hud_items, 15)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_help.text = config.help_text if config.help_text != "" else "WASD laufen · Shift rennen · Leertaste springen · An Leitern: W hoch, S runter\nLinke Maustaste halten: putzen · Ziffern oder Mausrad: Werkzeug wechseln\nU: Upgrade-Laden · R: Radar · M: Karte · Esc: Menü · F1: diese Hilfe"
	_help.modulate = Color(1, 1, 1, 0.8)
	_anchor(_help, 0.0, 1.0, 0.0, 1.0, 22, -112, 760, -14)
	_fade_help(HELP_SECONDS)

	# Fadenkreuz
	var cross := Crosshair.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(cross, 0.5, 0.5, 0.5, 0.5, -14, -14, 14, 14)
	_hud_items.add_child(cross)

	# Hinweis unter dem Fadenkreuz, z.B. "[Klick] zurückstellen"
	_prompt = _label(_hud_items, 18)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", config.ui_accent_color.lightened(0.35))
	_anchor(_prompt, 0.5, 0.5, 0.5, 0.5, -300, 22, 300, 52)

	# Meldungen unter der Bildmitte, auf einer eigenen Tafel
	var toast_holder := CenterContainer.new()
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(toast_holder, 0.15, 0.6, 0.85, 0.6, 0, 0, 0, 120)
	_root.add_child(toast_holder)
	_toast_panel = _panel(toast_holder)
	_toast_panel.custom_minimum_size = Vector2(360, 0)
	_toast_panel.modulate.a = 0.0
	_toast = _label(_toast_panel, 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF

	_build_menu()
	open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		if _help.modulate.a > 0.05:
			_fade_help(0.0)
		else:
			_fade_help(HELP_SECONDS)


## Steuerungshilfe zeigen und nach seconds Sekunden ausblenden (0 = sofort ausblenden).
func _fade_help(seconds: float) -> void:
	if _help_tween:
		_help_tween.kill()
	_help_tween = create_tween()
	if seconds > 0.0:
		_help_tween.tween_property(_help, "modulate:a", 0.8, 0.3)
		_help_tween.tween_interval(seconds)
	_help_tween.tween_property(_help, "modulate:a", 0.0, 1.2)


func _notification(what: int) -> void:
	# Fenster verliert den Fokus (Alt+Tab) -> Spiel pausieren
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _menu and not get_tree().paused:
		open_menu()


func open_menu() -> void:
	menu_opened.emit()
	_menu.visible = true
	_hud_items.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_button.grab_focus()


func close_menu() -> void:
	_menu.visible = false
	_hud_items.visible = true
	_menu_button.text = "Weiter"
	_menu_button.release_focus()   # sonst löst die Leertaste den Knopf statt Springen aus
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_closed.emit()


func set_prompt(text: String) -> void:
	_prompt.text = text


## Anzeige aus- und einblenden, z.B. solange Laden oder Karte offen sind.
func set_hud_visible(on: bool) -> void:
	_hud_items.visible = on and not _menu.visible


## Zeile unter dem Titel, z.B. der Spielstand.
func set_menu_info(text: String) -> void:
	_menu_info.text = text


func set_values(zone_name: String, percent: float, coins: int, tool_text: String, affordable: int, found: int) -> void:
	_zone_label.text = "%s – %.1f %% sauber" % [zone_name, percent]
	_progress.value = percent
	_coins_label.text = _format_number(coins)
	var text := "Werkzeug: %s\n" % tool_text
	if affordable > 0:
		text += "[U] Upgrade-Laden: %d Upgrade%s kaufbar!\n" % [affordable, "" if affordable == 1 else "s"]
	else:
		text += "[U] Upgrade-Laden\n"
	if not config.collectibles.is_empty():
		text += "%s: %d / %d" % [config.collectible_group_name, found, config.collectibles.size()]
	_upgrade_label.text = text


## Füllstand des Sacks; leerer Name = ausblenden. Wird jedes Bild aufgerufen.
func set_carry(carry_name: String, carried: int, capacity: int) -> void:
	_carry_box.visible = carry_name != ""
	if carry_name == "":
		return
	var full := carried >= capacity
	_carry_label.text = ("%s voll! %d / %d" if full else "%s: %d / %d") % [carry_name, carried, capacity]
	_carry_bar.max_value = capacity
	_carry_bar.value = carried
	if full != _carry_full:
		_carry_full = full
		var color := Color(1.0, 0.45, 0.35) if full else config.ui_text_color
		_carry_label.add_theme_color_override("font_color", color)
		_carry_bar.modulate = Color(1.0, 0.55, 0.5) if full else Color.WHITE
		if full:
			_carry_box.pivot_offset = _carry_box.size * 0.5
			var tween := create_tween()
			tween.tween_property(_carry_box, "scale", Vector2.ONE * 1.12, 0.12)
			tween.tween_property(_carry_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func set_rate(flakes_per_minute: int, overall_percent: float) -> void:
	_rate_label.text = "Tempo: %s %s pro Minute · Gesamt: %.1f %%" % [_format_number(flakes_per_minute), config.flake_name, overall_percent]


func set_radar(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_radar_label.text = "[R] %s-Radar bereit" % config.mess_name
	else:
		_radar_label.text = "%s-Radar lädt … %d s" % [config.mess_name, ceili(seconds_left)]


func toast(message: String, duration := 2.5) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_panel.scale = Vector2.ONE * 0.94
	_toast_panel.pivot_offset = _toast_panel.size * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.8)


## "+12" fliegt vom Fadenkreuz zum Münzzähler, der dann kurz hüpft.
func coin_popup(amount: int) -> void:
	var pop := _label(_root, 26, true)
	pop.text = "+%d" % amount
	pop.add_theme_color_override("font_color", config.ui_accent_color.lightened(0.3))
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
	overlay.color = config.ui_overlay_color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	_menu = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 22)
	center.add_child(outer)

	var title := _label(outer, 64, true)
	title.text = config.game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", config.ui_accent_color.lightened(0.25))
	title.add_theme_constant_override("outline_size", 10)
	if config.game_subtitle != "":
		var subtitle := _label(outer, 20)
		subtitle.text = config.game_subtitle
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.modulate = Color(1, 1, 1, 0.85)
	_menu_info = _label(outer, 16)
	_menu_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_info.add_theme_color_override("font_color", config.ui_accent_color)

	var panel := PanelContainer.new()
	outer.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_menu_button = _button(box, "Spielen")
	_menu_button.pressed.connect(close_menu)
	box.add_child(HSeparator.new())

	var sens_label := _label(box, 17)
	var sens := _slider(box, 0.0005, 0.006, mouse_sensitivity)
	var vol_label := _label(box, 17)
	var vol := _slider(box, 0.0, 1.0, volume)
	var music_label := _label(box, 17)
	var music := _slider(box, 0.0, 1.0, music_volume)
	var update_labels := func() -> void:
		sens_label.text = "Maus-Empfindlichkeit: %d %%" % roundi(mouse_sensitivity / 0.0025 * 100.0)
		vol_label.text = "Lautstärke: %d %%" % roundi(volume * 100.0)
		music_label.text = "Musik: %d %%" % roundi(music_volume * 100.0)
	update_labels.call()
	sens.value_changed.connect(func(v: float) -> void:
		mouse_sensitivity = v
		update_labels.call()
		_apply_settings())
	vol.value_changed.connect(func(v: float) -> void:
		volume = v
		update_labels.call()
		_apply_settings())
	music.value_changed.connect(func(v: float) -> void:
		music_volume = v
		update_labels.call()
		_apply_settings())

	var quality_row := HBoxContainer.new()
	box.add_child(quality_row)
	var quality_label := _label(quality_row, 17)
	quality_label.text = "Grafik"
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quality_pick := OptionButton.new()
	for q: String in QUALITY_NAMES:
		quality_pick.add_item(q)
	quality_pick.selected = quality
	quality_pick.custom_minimum_size = Vector2(180, 38)
	quality_pick.item_selected.connect(func(i: int) -> void:
		quality = i
		_apply_settings())
	quality_row.add_child(quality_pick)
	box.add_child(HSeparator.new())

	var new_game := _button(box, "Neues Spiel")
	new_game.pressed.connect(func() -> void:
		if new_game.text == "Neues Spiel":
			new_game.text = "Wirklich? Alles geht verloren!"
		else:
			new_game_requested.emit())
	var quit := _button(box, "Speichern und beenden")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	_apply_settings.call_deferred()


func _apply_settings() -> void:
	settings_changed.emit(mouse_sensitivity, volume)
	quality_changed.emit(quality)
	music_changed.emit(music_volume)
	var cfg := ConfigFile.new()
	cfg.set_value("steuerung", "maus", mouse_sensitivity)
	cfg.set_value("audio", "lautstaerke", volume)
	cfg.set_value("grafik", "qualitaet", quality)
	cfg.set_value("audio", "musik", music_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("steuerung", "maus", mouse_sensitivity)
		volume = cfg.get_value("audio", "lautstaerke", volume)
		music_volume = cfg.get_value("audio", "musik", music_volume)
		quality = clampi(int(cfg.get_value("grafik", "qualitaet", quality)), 0, QUALITY_NAMES.size() - 1)


# ---------------------------------------------------------------- Bausteine

func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	if _title_font:
		b.add_theme_font_override("font", _title_font)
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


## Tafel der Anzeige: etwas durchsichtiger als die Menü-Tafeln, damit sie das Bild nicht verdeckt.
func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := CleanTheme.hud_panel(config)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Control, font_size: int, title := false) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if title and _title_font:
		label.add_theme_font_override("font", _title_font)
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
