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
## Roboter: Upgrades mit spawns_bot = "rail" oder "drone". Schienen legt die Welt mit add_rail() an.

var config: CleanGameConfig
var state: CleanGameState
var mess: CleanMessField
var player: CleanPlayer
var hud: CleanHud
var sfx: CleanSfx
var shop: CleanShop
var world_body: StaticBody3D   # sammelt alle Kollisionsformen der Welt (siehe box/add_collider)

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
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


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
	mess = CleanMessField.new()
	add_child(mess)
	_build_world()
	mess.build()
	# Nächste Schienen zuerst, damit die ersten Roboter in Sichtweite landen
	_rails.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["from"] as Vector3).distance_to(config.player_start) < (b["from"] as Vector3).distance_to(config.player_start))

	player = CleanPlayer.new()
	player.position = config.player_start
	player.rotation.y = config.player_start_yaw
	player.mess_field = mess
	add_child(player)
	for t in config.tools:
		player.add_tool(t, _make_tool_visual(t))
	player.swept.connect(_on_swept)
	player.tool_changed.connect(func(_t: CleanTool) -> void: _refresh_hud())

	var loaded := _load_game()
	_place_collectibles()
	mess.flakes_removed.connect(_on_flakes_removed)
	apply_stats()
	_rate_buckets.resize(RATE_WINDOW)
	_rate_buckets.fill(0)

	hud = CleanHud.new()
	hud.config = config
	hud.settings_changed.connect(_on_settings_changed)
	hud.menu_opened.connect(save_game)
	hud.quit_requested.connect(_save_and_quit)
	hud.new_game_requested.connect(_new_game)
	add_child(hud)
	shop = CleanShop.new()
	shop.state = state
	shop.buy_requested.connect(_buy)
	add_child(shop)
	_refresh_hud()
	if loaded:
		hud.toast("Willkommen zurück im %s!" % config.zone_name, 4.0)
	elif config.welcome_text != "":
		hud.toast(config.welcome_text, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_shop"):
		shop.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("radar"):
		_try_radar()


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
		hud.set_rate(roundi(sum * 60.0 / RATE_WINDOW))
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()


func _on_settings_changed(mouse_sensitivity: float, volume: float) -> void:
	player.mouse_sensitivity = mouse_sensitivity
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


# ================================================================ Spielstand

func _on_flakes_removed(count: int, earned: int) -> void:
	_rate_buckets[RATE_WINDOW - 1] += count
	earned = roundi(earned * state.stat("coin_mult"))
	state.coins += earned
	_popup_coins += earned
	var percent := mess.progress_percent()
	for m: int in config.milestones:
		if percent >= m and not state.milestones_hit.has(m):
			state.milestones_hit.append(m)
			var bonus: int = config.milestones[m]
			state.coins += bonus
			hud.toast("%d %% geschafft! Bonus: +%d %s" % [m, bonus, config.currency_name])
			sfx.jingle()
	if not state.zone_done and percent >= config.complete_at:
		state.zone_done = true
		state.coins += config.complete_bonus
		mess.clear_all()   # ruft diese Funktion erneut auf, zone_done verhindert eine Schleife
		hud.toast("%s ist blitzsauber! Der letzte Rest fliegt davon.\nBonus: +%d %s" % [config.zone_name, config.complete_bonus, config.currency_name], 6.0)
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
	shop.refresh()
	_refresh_hud()


## Rechnet alle Upgrades und Sammelobjekte in Werte für Spielfigur und Radar um.
func apply_stats() -> void:
	for t in config.tools:
		player.set_unlocked(t, state.is_tool_unlocked(t))
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
			bot.mess = mess
			var model := _make_bot_model(u.spawns_bot)
			if model:
				bot.set_model(model)
			add_child(bot)
			list.append(bot)
	for kind: String in _bots:
		for bot: CleanBot in _bots[kind]:
			bot.speed_mult = state.stat("bot_speed")
			bot.power_mult = state.stat("bot_power")


func bot_count() -> int:
	var n := 0
	for kind: String in _bots:
		n += (_bots[kind] as Array).size()
	return n


func _try_radar() -> void:
	if state.zone_done:
		return
	if _radar_cooldown > 0.0:
		hud.toast("Das Radar lädt noch %d Sekunden." % ceili(_radar_cooldown))
		sfx.deny()
		return
	_radar_cooldown = maxf(3.0, state.stat("radar_cooldown"))
	_radar_time = config.radar_duration
	mess.highlight(config.radar_duration)
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
	hud.set_values(mess.progress_percent(), state.coins, tool_text, state.affordable_count(), state.found.size())


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
	data["mess"] = mess.save_state()
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
	mess.load_state(str(data.get("mess", "")))
	apply_stats()
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


## Schiene für einen Schienen-Roboter: Putzlinie von from bis to (y = Boden), Putzhöhen,
## und die Richtung, in der der Roboter vor der Linie fährt.
func add_rail(from: Vector3, to: Vector3, heights: Array[float], facing: Vector3) -> void:
	_rails.append({"from": from, "to": to, "heights": heights, "facing": facing})


## Kletterbereich. foot_center = Mitte vor der Leiter am Boden, facing zeigt von der Leiter weg.
func add_ladder(foot_center: Vector3, facing: Vector3, height: float, max_feet: float) -> CleanLadder:
	var ladder := CleanLadder.create(foot_center, facing, Vector3(0.8, height + 1.0, 0.7), max_feet)
	add_child(ladder)
	return ladder
