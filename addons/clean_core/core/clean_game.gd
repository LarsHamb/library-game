class_name CleanGame
extends Node3D
## Grundgerüst für jedes Putzspiel: Spielfigur, Schmutz, Münzen, Upgrades, Sammelobjekte,
## Radar, Anzeige, Upgrade-Laden, Geräusche und Speichern.
##
## Ein konkretes Spiel erbt davon und füllt nur die "virtuellen" Funktionen unten aus:
##   _create_config()          Texte, Werte, Werkzeuge, Upgrades, Sammelobjekte (Pflicht)
##   _build_world()            Räume, Möbel, Schmutzflächen (Pflicht)
##   _make_tool_visual(tool)   Modell eines Werkzeugs in der Hand (Pflicht)
##   _collectible_spots()      Verstecke für die Sammelobjekte
##   _make_collectible_model(def), _build_environment(), _tool_display_name(tool), _on_stats_applied()
##   _make_bot_model(kind)     Modell für Roboter (sonst einfache Standardmodelle)
##   _title_view()             Kamerafahrt hinter dem Startmenü
##   _screenshot_views()       Kamerapunkte für den Foto-Rundgang (Start mit: godot --path . -- --screenshots)
## _build_environment() setzt `environment`; apply_quality() schaltet darauf je nach Grafikstufe Effekte an und aus.
## Roboter: Upgrades mit spawns_bot = "rail" oder "drone". Schienen legt die Welt mit add_rail() an.
## Zonen: die erste Zone (config.zone_name) gibt es immer; weitere legt _build_world() mit add_zone() an,
## Türen dazu mit add_door(). Freigeschaltet werden sie über Upgrades mit unlocks_zone.
## Zusatz-Schmutz mit eigenem Werkzeug (z.B. Spinnweben): add_mess_layer(). Karte (M): config.zone_bounds setzen.
## Schichten mit Gruppen (add_linked_flake(..., group)) geben config.group_bonus, wenn eine Gruppe sauber ist.
## Herumliegendes zum Zurückstellen: add_pickup().

var config: CleanGameConfig
var state: CleanGameState
var mess: CleanMessField          # Schmutz der ersten Zone
var zones: Array[CleanZone] = []
var current_zone: CleanZone
var player: CleanPlayer
var hud: CleanHud
var sfx: CleanSfx
var shop: CleanShop
var map: CleanMap
var world_body: StaticBody3D   # sammelt alle Kollisionsformen der Welt (siehe box/add_collider)
var environment: Environment   # von _build_environment() gesetzt
var music: AudioStreamPlayer

const RATE_WINDOW := 30        # Sekunden für die Tempo-Anzeige
const AUTOSAVE_SECONDS := 30.0

var _collectibles: Array[CleanCollectible] = []
var _rails: Array[Dictionary] = []   # mögliche Schienen für Schienen-Roboter
var _bots := {}                      # Roboter-Art -> Array der Roboter
var _mats := {}
var _radar_cooldown := 0.0
var _radar_time := 0.0
var _popup_coins := 0
var _popup_timer := 0.0
var _rate_buckets: Array[int] = []
var _rate_timer := 0.0
var _autosave_timer := AUTOSAVE_SECONDS
var _regrow_timer := 10.0
var _wrong_tool_cooldown := 0.0
var _offline_coins := 0
var _offline_minutes := 0
var _group_bonus_sum := 0
var _group_count := 0
var _group_timer := 0.0
var _aimed_pickup: CleanPickup


# ================================================================ Für das konkrete Spiel

func _create_config() -> CleanGameConfig:
	push_error("CleanGame: _create_config() muss im Spiel überschrieben werden")
	return CleanGameConfig.new()


func _build_world() -> void:
	push_error("CleanGame: _build_world() muss im Spiel überschrieben werden")


func _make_tool_visual(_tool: CleanTool) -> Node3D:
	return Node3D.new()


## Ein Versteck pro Sammelobjekt, in derselben Reihenfolge wie config.collectibles.
## Muss bei jedem Start gleich sein, damit Spielstände passen.
func _collectible_spots() -> Array[Vector3]:
	return []


func _make_collectible_model(_def: CleanCollectibleDef) -> Node3D:
	return null


func _make_bot_model(_kind: String) -> Node3D:
	return null


## Erzeugt Roboter Nummer index der Art kind. Eigene Arten: überschreiben und sonst super() aufrufen.
func _spawn_bot(kind: String, index: int) -> CleanBot:
	match kind:
		"rail":
			if index >= _rails.size():
				return null
			var rail: Dictionary = _rails[index]
			var bot := CleanRailBot.new()
			bot.rail_from = rail["from"]
			bot.rail_to = rail["to"]
			bot.heights.assign(rail["heights"])
			bot.facing = rail["facing"]
			return bot
		"drone":
			var drone := CleanDrone.new()
			drone.messes = _open_messes()
			drone.position = config.player_start + Vector3(index * 0.8 - 2.0, 0, -2.0)
			return drone
	return null


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	environment = env


## Langsame Kamerafahrt hinter dem Startmenü: {"from": Vector3, "to": Vector3, "look": Vector3}. Leer = keine.
func _title_view() -> Dictionary:
	return {}


## Kamerapunkte für den Foto-Rundgang: je {"name": "lesesaal", "pos": Vector3, "look": Vector3}.
func _screenshot_views() -> Array[Dictionary]:
	return [{"name": "start", "pos": config.player_start + Vector3(0, 1.7, 0), "look": config.player_start + Vector3(0, 1.5, -5)}]


func _tool_display_name(tool: CleanTool) -> String:
	return tool.display_name


## Wird nach jeder Änderung an Upgrades/Sammelobjekten aufgerufen.
func _on_stats_applied() -> void:
	pass


# ================================================================ Ablauf

func _ready() -> void:
	config = _create_config()
	state = CleanGameState.new(config)
	_setup_input()
	_build_environment()
	sfx = CleanSfx.new()
	add_child(sfx)

	world_body = StaticBody3D.new()
	add_child(world_body)
	var main_zone := add_zone("main", config.zone_name, Rect2(-1e6, -1e6, 2e6, 2e6), config.complete_bonus)
	main_zone.spawn = config.player_start
	main_zone.spawn_yaw = config.player_start_yaw
	mess = main_zone.mess
	current_zone = main_zone
	_build_world()
	for z in zones:
		for m in z.all_messes():
			m.build()
	# Nächste Schienen zuerst, damit die ersten Roboter in Sichtweite landen
	_rails.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["from"] as Vector3).distance_to(config.player_start) < (b["from"] as Vector3).distance_to(config.player_start))

	player = CleanPlayer.new()
	player.position = config.player_start
	player.rotation.y = config.player_start_yaw
	add_child(player)
	for t in config.tools:
		player.add_tool(t, _make_tool_visual(t))
	player.swept.connect(_on_swept)
	player.tool_changed.connect(func(_t: CleanTool) -> void: _refresh_hud())
	player.wrong_tool.connect(_on_wrong_tool)

	var loaded := _load_game()
	for z in zones:
		for p in z.pickups:
			if state.returned.has(p.id):
				p.place_at_target()
	_place_collectibles()
	for z in zones:
		for m in z.all_messes():
			m.flakes_removed.connect(_on_flakes_removed.bind(z))
			m.group_cleaned.connect(_on_group_cleaned.bind(z))
	apply_stats()
	_rate_buckets.resize(RATE_WINDOW)
	_rate_buckets.fill(0)

	hud = CleanHud.new()
	hud.config = config
	hud.settings_changed.connect(_on_settings_changed)
	hud.menu_opened.connect(save_game)
	hud.quit_requested.connect(_save_and_quit)
	hud.new_game_requested.connect(_new_game)
	hud.quality_changed.connect(apply_quality)
	hud.menu_opened.connect(_update_menu_info)
	_start_music()
	hud.music_changed.connect(func(v: float) -> void:
		if music:
			music.volume_db = linear_to_db(maxf(v * 0.6, 0.0001)))
	add_child(hud)
	_start_title_camera()
	shop = CleanShop.new()
	shop.state = state
	shop.buy_requested.connect(_buy)
	add_child(shop)
	map = CleanMap.new()
	map.game = self
	map.travel_requested.connect(travel_to)
	add_child(map)
	shop.visibility_changed.connect(func() -> void: hud.set_hud_visible(not shop.visible))
	map.visibility_changed.connect(func() -> void: hud.set_hud_visible(not map.visible))
	_refresh_hud()
	# Begrüßung erst, wenn das Startmenü zu ist – vorher läge sie unter dem Menü
	var welcome := ""
	if loaded and _offline_coins > 0:
		welcome = "Willkommen zurück! Deine Roboter haben in %s\n%d %s verdient." % [_duration_text(_offline_minutes), _offline_coins, config.currency_name]
	elif loaded:
		welcome = "Willkommen zurück!"
	else:
		welcome = config.welcome_text
	if welcome != "":
		hud.menu_closed.connect(func() -> void: hud.toast(welcome, 5.0), CONNECT_ONE_SHOT)
	if OS.get_cmdline_user_args().has("--screenshots") or OS.get_cmdline_args().has("--screenshots"):
		_screenshot_tour.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_shop"):
		shop.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("radar"):
		_try_radar()
	elif event.is_action_pressed("open_map") and config.zone_bounds.has_area():
		map.open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and state:
		save_game()


func _process(delta: float) -> void:
	sfx.set_cleaning(player.is_cleaning_held(), player.cleaning_mess, player.tool != null and player.tool.style == CleanTool.Style.SUCK)
	# Münz-Popups sammeln, damit nicht jedes Bild ein eigenes "+1" erscheint
	_popup_timer -= delta
	if _popup_coins > 0 and _popup_timer <= 0.0:
		# Nur eigenes Putzen klingelt; was Roboter verdienen, kommt leise dazu
		if player.cleaning_mess:
			hud.coin_popup(_popup_coins)
			sfx.coin()
		_popup_coins = 0
		_popup_timer = 0.2
	var here := zone_at(player.global_position)
	if here != current_zone:
		current_zone = here
		_refresh_hud()
	_radar_cooldown = maxf(0.0, _radar_cooldown - delta)
	hud.set_radar(_radar_cooldown)
	if _radar_time > 0.0:
		_radar_time -= delta
		if _radar_time <= 0.0:
			for c in _collectibles:
				c.show_beam(false)
	# Tempo: Flocken der letzten 30 Sekunden, hochgerechnet auf eine Minute
	_rate_timer += delta
	if _rate_timer >= 1.0:
		_rate_timer -= 1.0
		_rate_buckets.pop_front()
		_rate_buckets.append(0)
		var sum := 0
		for n in _rate_buckets:
			sum += n
		hud.set_rate(roundi(sum * 60.0 / RATE_WINDOW), overall_percent())
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()
	_wrong_tool_cooldown = maxf(0.0, _wrong_tool_cooldown - delta)
	_update_pickup_aim()
	# Gruppen-Boni sammeln, damit ein Roboter, der fünf Regalböden auf einmal schafft, nur eine Meldung auslöst
	if _group_count > 0:
		_group_timer -= delta
		if _group_timer <= 0.0:
			var text := "%s blitzblank! +%d %s" % [config.group_name, _group_bonus_sum, config.currency_name]
			if _group_count > 1:
				text = "%d× %s blitzblank! +%d %s" % [_group_count, config.group_name, _group_bonus_sum, config.currency_name]
			hud.toast(text, 2.5)
			_group_count = 0
			_group_bonus_sum = 0
	# Staub legt sich neu, sobald Roboter da sind, damit sie dauerhaft Arbeit haben
	_regrow_timer -= delta
	if _regrow_timer <= 0.0:
		_regrow_timer = 10.0
		if bot_count() > 0:
			for z in zones:
				if z.unlocked:
					for m in z.all_messes():
						if m.required_tool == "":   # Spinnweben o.ä. wachsen nicht nach
							m.regrow(roundi(m.total * config.regrow_per_minute / 6.0))
			_refresh_hud()


func _on_settings_changed(mouse_sensitivity: float, volume: float) -> void:
	player.mouse_sensitivity = mouse_sensitivity
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


## Grafikstufe: 0 niedrig, 1 mittel, 2 hoch. Schaltet teure Effekte und Schatten an und aus.
func apply_quality(level: int) -> void:
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][level] as Viewport.MSAA
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if level == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.77 if level == 0 else 1.0
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	if environment:
		environment.ssao_enabled = level >= 1
		environment.ssil_enabled = level >= 2
		environment.ssr_enabled = level >= 2
		environment.sdfgi_enabled = level >= 2
		environment.volumetric_fog_enabled = level >= 1
		environment.glow_enabled = true
	# Schatten: auf "niedrig" nur noch das Hauptlicht; was einmal Schatten hatte, merkt sich das per Meta
	for light: Node in find_children("*", "Light3D", true, false):
		var l := light as Light3D
		if not l.has_meta("clean_shadow"):
			l.set_meta("clean_shadow", l.shadow_enabled)
		var wanted: bool = l.get_meta("clean_shadow")
		l.shadow_enabled = wanted and (level >= 1 or l is DirectionalLight3D)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][level] as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][level] as RenderingServer.ShadowQuality)


# ================================================================ Foto-Rundgang

## Macht Bildschirmfotos vom Menü, der Anzeige, dem Laden und allen _screenshot_views()
## und beendet dann das Spiel. Bilder landen in res://screenshots (nur beim Start aus dem Projektordner).
func _screenshot_tour() -> void:
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)   # Godot soll die Fotos nicht importieren
	await _tour_wait(2.0)
	_tour_shot(dir, "00_menue")
	hud.close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _tour_wait(1.5)
	_tour_shot(dir, "01_spiel")
	shop.open()
	await _tour_wait(0.6)
	_tour_shot(dir, "02_laden")
	shop.close()
	if config.zone_bounds.has_area():
		map.open()
		await _tour_wait(0.6)
		_tour_shot(dir, "02_karte")
		map.close()
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	hud.visible = false
	var i := 3
	for view in _screenshot_views():
		cam.global_position = view["pos"]
		cam.look_at(view["look"])
		await _tour_wait(1.2)
		_tour_shot(dir, "%02d_%s" % [i, view["name"]])
		i += 1
	print("Fotos gespeichert in ", dir)
	get_tree().quit()


func _start_music() -> void:
	if config.music_file == "" or not ResourceLoader.exists(config.music_file):
		return
	var stream: AudioStream = load(config.music_file)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.play()


## Solange das Startmenü offen ist, gleitet eine Kamera langsam durch die Welt.
func _start_title_camera() -> void:
	var view := _title_view()
	if view.is_empty():
		return
	var from: Vector3 = view["from"]
	var to: Vector3 = view["to"]
	var look: Vector3 = view["look"]
	var player_cam := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cam)
	cam.make_current()
	var move := func(k: float) -> void:
		cam.global_position = from.lerp(to, k)
		cam.look_at(look)
	move.call(0.0)
	var tween := cam.create_tween().set_loops()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(move, 0.0, 1.0, 40.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(move, 1.0, 0.0, 40.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hud.menu_closed.connect(func() -> void:
		if player_cam:
			player_cam.make_current()
		cam.queue_free(), CONNECT_ONE_SHOT)


func _update_menu_info() -> void:
	var text := "%s: %.1f %% sauber" % [config.zone_name, zones[0].progress_percent()]
	if zones.size() > 1:
		text = "Gesamt: %.1f %% sauber" % overall_percent()
	if not config.collectibles.is_empty():
		text += "   ·   %s: %d / %d" % [config.collectible_group_name, state.found.size(), config.collectibles.size()]
	hud.set_menu_info(text)


func _tour_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _tour_shot(dir: String, file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file_name + ".png"))


# ================================================================ Spielstand

func _on_flakes_removed(count: int, earned: int, zone: CleanZone) -> void:
	_rate_buckets[RATE_WINDOW - 1] += count
	earned = roundi(earned * state.stat("coin_mult") * zone.value_mult)
	state.coins += earned
	_popup_coins += earned
	var percent := zone.progress_percent()
	for m: int in config.milestones:
		var key := "%s:%d" % [zone.id, m]
		if percent >= m and not state.milestones_hit.has(key):
			state.milestones_hit.append(key)
			var bonus: int = config.milestones[m]
			state.coins += bonus
			hud.toast("%s: %d %% geschafft! Bonus: +%d %s" % [zone.display_name, m, bonus, config.currency_name])
			sfx.jingle()
	if not state.zones_done.has(zone.id) and percent >= config.complete_at:
		state.zones_done.append(zone.id)
		state.coins += zone.complete_bonus
		for m in zone.all_messes():
			if m.required_tool == "":
				m.clear_all()   # ruft diese Funktion erneut auf, zones_done verhindert eine Schleife
		hud.toast("%s ist blitzsauber! Der letzte Rest fliegt davon.\nBonus: +%d %s" % [zone.display_name, zone.complete_bonus, config.currency_name], 6.0)
		sfx.jingle()
	_refresh_hud()


func _buy(id: String) -> void:
	if not state.try_buy(id):
		sfx.deny()
		return
	apply_stats()
	sfx.upgrade()
	var u := state.upgrade(id)
	if u.unlock_tool != "":
		player.select_tool_by_id(u.unlock_tool)
		hud.toast("%s freigeschaltet! Wechsle mit den Zifferntasten oder dem Mausrad." % u.display_name, 4.0)
	if u.unlocks_zone != "":
		hud.toast("Die Tür ist offen: %s!" % u.display_name, 4.0)
		sfx.jingle()
	shop.refresh()
	_refresh_hud()


## Rechnet alle Upgrades und Sammelobjekte in Werte für Spielfigur und Radar um.
func apply_stats() -> void:
	for t in config.tools:
		player.set_unlocked(t, state.is_tool_unlocked(t))
	_apply_zone_locks()
	player.set_stats(state.stat("radius"), state.stat("power"), state.stat("reach"), state.stat("speed"))
	_sync_bots()
	_on_stats_applied()


## So viele Roboter wie gekauft, alle mit aktuellem Tempo und aktueller Kraft.
func _sync_bots() -> void:
	for u in config.upgrades:
		if u.spawns_bot == "":
			continue
		var list: Array = _bots.get(u.spawns_bot, [])
		_bots[u.spawns_bot] = list
		while list.size() < state.level(u.id):
			var bot := _spawn_bot(u.spawns_bot, list.size())
			if bot == null:
				break
			var bot_zone := zone_at(bot.rail_from if bot is CleanRailBot else bot.position)
			bot.mess = bot_zone.mess
			for layer in bot_zone.layers:
				if layer.required_tool == "":
					bot.layers.append(layer)
			if bot is CleanDrone:
				(bot as CleanDrone).messes = _open_messes()
			var model := _make_bot_model(u.spawns_bot)
			if model:
				bot.set_model(model)
			add_child(bot)
			list.append(bot)
	for kind: String in _bots:
		for bot: CleanBot in _bots[kind]:
			bot.speed_mult = state.stat("bot_speed")
			bot.power_mult = state.stat("bot_power")
			if bot is CleanDrone:
				(bot as CleanDrone).messes = _open_messes()


func all_bots() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for kind: String in _bots:
		for bot: Node3D in _bots[kind]:
			list.append(bot)
	return list


func bot_count() -> int:
	var n := 0
	for kind: String in _bots:
		n += (_bots[kind] as Array).size()
	return n


func _try_radar() -> void:
	if _radar_cooldown > 0.0:
		hud.toast("Das Radar lädt noch %d Sekunden." % ceili(_radar_cooldown))
		sfx.deny()
		return
	_radar_cooldown = maxf(3.0, state.stat("radar_cooldown"))
	_radar_time = config.radar_duration
	for m in player.mess_fields:   # alle offenen Schichten, auch Spinnweben
		m.highlight(config.radar_duration)
	for c in _collectibles:
		c.show_beam(true)
	if _collectibles.any(func(c: CleanCollectible) -> bool: return not c.found):
		hud.toast("Radar: Der restliche %s leuchtet gelb.\nGoldene Lichtsäulen zeigen versteckte %s!" % [config.mess_name, config.collectible_group_name])
	else:
		hud.toast("Radar: Der restliche %s leuchtet jetzt gelb." % config.mess_name)
	sfx.upgrade()


func _refresh_hud() -> void:
	var tool_text := _tool_display_name(player.tool) if player.tool else ""
	var keys: Array[String] = []
	for t in config.tools:
		if player.is_unlocked(t):
			keys.append("[%d] %s" % [t.hotkey, t.display_name])
	if keys.size() > 1:
		tool_text += "\n" + "  ".join(keys)
	if bot_count() > 0:
		tool_text += "\nRoboter im Einsatz: %d" % bot_count()
	for layer in current_zone.layers:
		if layer.remaining > 0 and layer.display_name != "":
			tool_text += "\n%s: %d übrig" % [layer.display_name, layer.remaining]
	var loose := 0
	for p in current_zone.pickups:
		if not p.done:
			loose += 1
	if loose > 0:
		tool_text += "\n%s: %d übrig" % [config.pickup_name, loose]
	hud.set_values(current_zone.display_name, current_zone.progress_percent(), state.coins, tool_text, state.affordable_count(), state.found.size())


# ================================================================ Sammelobjekte

func _place_collectibles() -> void:
	var spots := _collectible_spots()
	for i in mini(spots.size(), config.collectibles.size()):
		var def := config.collectibles[i]
		if state.has_found(def.id):
			continue
		var c := CleanCollectible.new()
		c.def = def
		var model := _make_collectible_model(def)
		if model:
			c.set_model(model)
		c.position = spots[i]
		add_child(c)
		_collectibles.append(c)


func _on_swept(point: Vector3, radius: float) -> void:
	for c in _collectibles:
		if not c.found and point.distance_to(c.global_position) < radius + 0.1:
			_collect(c)


func _collect(c: CleanCollectible) -> void:
	c.reveal()
	_collectibles.erase(c)
	state.found.append(c.def.id)
	apply_stats()
	sfx.found_collectible()
	hud.toast("Gefunden: »%s«\n%s" % [c.def.display_name, c.def.perk_text], 5.0)
	if c.def.unlock_tool != "":
		player.select_tool_by_id(c.def.unlock_tool)
	_refresh_hud()
	save_game()


# ================================================================ Speichern

func save_game() -> void:
	var data := state.to_dict()
	data["version"] = 1
	data["player"] = [player.position.x, player.position.y, player.position.z, player.rotation.y]
	data["tool"] = player.tool.id if player.tool else ""
	var mess_states := {}
	for z in zones:
		mess_states[z.id] = z.mess.save_state()
		for k in z.layers.size():
			mess_states["%s:%d" % [z.id, k]] = z.layers[k].save_state()
	data["mess"] = mess_states
	data["saved_at"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(config.save_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_game() -> bool:
	if not FileAccess.file_exists(config.save_file):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config.save_file))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	state.from_dict(data)
	var p: Array = data.get("player", [])
	if p.size() == 4:
		player.position = Vector3(p[0], p[1], p[2])
		player.rotation.y = p[3]
	var saved_mess: Variant = data.get("mess", {})
	if saved_mess is String:   # ältere Spielstände hatten nur eine Zone
		saved_mess = {"main": saved_mess}
	for z in zones:
		z.mess.load_state(str((saved_mess as Dictionary).get(z.id, "")))
		for k in z.layers.size():
			z.layers[k].load_state(str((saved_mess as Dictionary).get("%s:%d" % [z.id, k], "")))
	apply_stats()
	# Offline-Verdienst der Roboter
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at > 0.0 and bot_count() > 0:
		var minutes := clampf((Time.get_unix_time_from_system() - saved_at) / 60.0, 0.0, config.offline_max_hours * 60.0)
		if minutes >= 1.0:
			_offline_minutes = floori(minutes)
			_offline_coins = roundi(minutes * bot_count() * config.offline_coins_per_bot_minute * state.stat("bot_power") * state.stat("coin_mult"))
			state.coins += _offline_coins
	player.select_tool_by_id(str(data.get("tool", "")))
	return true


func _save_and_quit() -> void:
	save_game()
	get_tree().quit()


func _new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config.save_file))
	state = null   # verhindert, dass beim Neuladen noch einmal gespeichert wird
	get_tree().paused = false
	get_tree().reload_current_scene()


# ================================================================ Eingabe

func _setup_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("open_shop", [KEY_U, KEY_TAB])
	_add_key_action("radar", [KEY_R])
	_add_key_action("open_map", [KEY_M])
	_add_key_action("interact", [KEY_E])
	for n in range(1, 10):
		_add_key_action("tool_%d" % n, [KEY_0 + n])
	if not InputMap.has_action("clean"):
		InputMap.add_action("clean")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("clean", click)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)


# ================================================================ Bauhelfer für die Welt

## Quader mit Material, optional mit Kollision.
func box(size: Vector3, pos: Vector3, material: Material, collide := true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = pos
	add_child(mesh_instance)
	if collide:
		add_collider(size, pos)
	return mesh_instance


## Unsichtbare Kollision (z.B. damit der Putz-Strahl an etwas hängen bleibt).
func add_collider(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	world_body.add_child(col)


## Einfaches Material, nach Name zwischengespeichert.
func mat(key: String, color: Color, roughness := 0.8) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_mats[key] = m
	return m


## Neue Zone mit eigenem Schmutzfeld. bounds = Grundfläche (x, z). Danach Schmutz mit zone.mess.add_area() verteilen.
func add_zone(id: String, display_name: String, bounds: Rect2, complete_bonus: int, value_mult := 1.0, color := Color(0.68, 0.64, 0.57)) -> CleanZone:
	var z := CleanZone.new()
	z.id = id
	z.display_name = display_name
	z.bounds = bounds
	z.complete_bonus = complete_bonus
	z.value_mult = value_mult
	z.mess = CleanMessField.new()
	z.mess.base_color = color
	add_child(z.mess)
	zones.append(z)
	return z


## Zusätzlicher Schmutz in einer Zone mit eigenem Aussehen, z.B. Spinnweben, die nur ein bestimmtes
## Werkzeug entfernt. Flocken danach mit layer.add_flake_at() oder layer.add_area() verteilen.
func add_mess_layer(zone: CleanZone, display_name: String, required_tool: String, color: Color, coin_mult: float, shader: Shader = null) -> CleanMessField:
	var layer := CleanMessField.new()
	layer.display_name = display_name
	layer.required_tool = required_tool
	layer.base_color = color
	layer.coin_mult = coin_mult
	layer.flake_shader = shader
	add_child(layer)
	zone.layers.append(layer)
	return layer


## Etwas Herumliegendes, das an seinen Platz zurück gehört. model liegt bei from, gehört nach to.
## size = ungefähre Größe (für das Anklicken). Die id muss bei jedem Start gleich sein (Spielstand).
func add_pickup(id: String, zone: CleanZone, model: Node3D, from: Transform3D, to: Transform3D, size: Vector3, coins := 50) -> CleanPickup:
	var p := CleanPickup.create(id, model, from, to, size)
	p.zone = zone
	p.coins = coins
	p.collected.connect(_on_pickup_returned)
	add_child(p)
	zone.pickups.append(p)
	return p


func _update_pickup_aim() -> void:
	var target := player.aim_target()
	var p := target as CleanPickup
	if p and (p.done or not p.zone.unlocked):
		p = null
	if p != _aimed_pickup:
		_aimed_pickup = p
		hud.set_prompt(config.pickup_prompt if p else "")
	if p and (player.is_cleaning_held() or Input.is_action_just_pressed("interact")):
		p.collect()
		_aimed_pickup = null
		hud.set_prompt("")
		sfx.upgrade()


func _on_pickup_returned(p: CleanPickup) -> void:
	if not state.returned.has(p.id):
		state.returned.append(p.id)
	var earned := roundi(p.coins * p.zone.value_mult * state.stat("coin_mult"))
	state.coins += earned
	hud.coin_popup(earned)
	sfx.coin()
	var left := 0
	for q in p.zone.pickups:
		if not q.done:
			left += 1
	if left == 0:
		hud.toast("Alle %s in %s sind wieder an ihrem Platz!" % [config.pickup_name, p.zone.display_name], 4.0)
		sfx.jingle()
	_refresh_hud()


func _on_group_cleaned(_group: int, zone: CleanZone) -> void:
	var bonus := roundi(config.group_bonus * zone.value_mult * state.stat("coin_mult"))
	state.coins += bonus
	_group_bonus_sum += bonus
	_group_count += 1
	_group_timer = 0.6
	if _group_count == 1:
		sfx.jingle()
	_refresh_hud()


## Bringt die Spielfigur in eine offene Zone (Klick auf der Karte).
func travel_to(zone: CleanZone) -> void:
	player.global_position = zone.spawn_point()
	player.rotation.y = zone.spawn_yaw
	player.velocity = Vector3.ZERO
	sfx.upgrade()
	hud.toast(zone.display_name, 2.0)


func _on_wrong_tool(layer: CleanMessField) -> void:
	if _wrong_tool_cooldown > 0.0:
		return
	_wrong_tool_cooldown = 4.0
	var tool_name := layer.required_tool
	var unlocked := false
	for t in config.tools:
		if t.id == layer.required_tool:
			tool_name = t.display_name
			unlocked = player.is_unlocked(t)
	if unlocked:
		hud.toast("%s gehen nur mit dem %s weg (Taste wechseln)." % [layer.display_name, tool_name], 3.0)
	else:
		hud.toast("%s gehen nur mit dem %s weg.\nDen gibt es im Upgrade-Laden." % [layer.display_name, tool_name], 3.5)


static func _duration_text(minutes: int) -> String:
	if minutes < 60:
		return "%d Minuten" % minutes
	return "%d h %d min" % [minutes / 60, minutes % 60]


## Tür einer gesperrten Zone: fester Quader mit Schild. Verschwindet, sobald die Zone offen ist.
func add_door(zone: CleanZone, size: Vector3, pos: Vector3, material: Material, sign_text: String, sign_pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = size
	door_mesh.material = material
	door.mesh = door_mesh
	body.add_child(door)
	add_child(body)
	zone.door_nodes.append(body)
	var label := Label3D.new()
	label.text = sign_text
	label.position = sign_pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.004
	label.outline_size = 12
	label.modulate = Color(1.0, 0.9, 0.6)
	add_child(label)
	zone.door_nodes.append(label)


## Die Zone, in der ein Punkt liegt (spätere Zonen gehen vor, die erste umfasst den Rest).
func zone_at(p: Vector3) -> CleanZone:
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].contains(p):
			return zones[i]
	return zones[0]


func overall_percent() -> float:
	var total := 0
	var cleaned := 0
	for z in zones:
		for m in z.all_messes():
			total += m.total
			cleaned += m.total - m.remaining
	return 100.0 * cleaned / maxi(total, 1)


func _open_messes() -> Array[CleanMessField]:
	var list: Array[CleanMessField] = []
	for z in zones:
		if z.unlocked:
			list.append(z.mess)
	return list


func _apply_zone_locks() -> void:
	for z in zones:
		z.unlocked = state.is_zone_unlocked(z.id)
		if z.unlocked:
			for n in z.door_nodes:
				n.queue_free()
			z.door_nodes.clear()
	var list: Array[CleanMessField] = []
	for z in zones:
		if z.unlocked:
			list.append_array(z.all_messes())
	player.mess_fields = list


## Schiene für einen Schienen-Roboter: Putzlinie von from bis to (y = Boden), Putzhöhen,
## und die Richtung, in der der Roboter vor der Linie fährt.
func add_rail(from: Vector3, to: Vector3, heights: Array[float], facing: Vector3) -> void:
	_rails.append({"from": from, "to": to, "heights": heights, "facing": facing})


## Kletterbereich. foot_center = Mitte vor der Leiter am Boden, facing zeigt von der Leiter weg.
func add_ladder(foot_center: Vector3, facing: Vector3, height: float, max_feet: float) -> CleanLadder:
	var ladder := CleanLadder.create(foot_center, facing, Vector3(0.8, height + 1.0, 0.7), max_feet)
	add_child(ladder)
	return ladder
