extends Node3D
## Baut den Lesesaal auf und hält den Spielstand: Münzen, Upgrades, seltene Bücher,
## Staub-Radar und Speichern/Laden.

const DustField := preload("res://scripts/dust_field.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Shop := preload("res://scripts/shop.gd")
const RareBook := preload("res://scripts/rare_book.gd")
const Upgrades := preload("res://scripts/upgrades.gd")

# --- Raum ---
const ZONE_NAME := "Großer Lesesaal"
const HALL_SIZE := Vector2(22.0, 28.0)   # Breite (x) und Länge (z) in Metern
const WALL_HEIGHT := 7.0

# --- Regale ---
const CASE_WIDTH := 3.5
const CASE_DEPTH := 0.55
const CASE_HEIGHT := 3.0
const CASE_BOARDS := [0.1, 0.6, 1.1, 1.6, 2.1, 2.6]
const DUSTY_BOARDS := 6   # alle Böden; die oberen erreicht man über die Leitern
const UPPER_BOARD_DIRT := 0.3   # oben putzt nie jemand, da liegt mehr Staub
const LADDER_TOP := 1.45        # höchste Fußhöhe auf der Leiter
const ROW_Z := [-10.0, -5.5, -1.0, 3.5]
const COLUMN_X := [-7.0, -3.5, 3.5, 7.0]
const BOOK_COLORS := [
	Color(0.55, 0.12, 0.1), Color(0.15, 0.3, 0.18), Color(0.12, 0.2, 0.4),
	Color(0.45, 0.3, 0.12), Color(0.3, 0.12, 0.3), Color(0.6, 0.48, 0.25),
	Color(0.2, 0.18, 0.16), Color(0.5, 0.2, 0.08),
]

# --- Werte (Upgrades: siehe upgrades.gd) ---
const BASE_RADIUS := 0.45
const BASE_POWER := 6.0          # Staubmenge pro Sekunde in der Ringmitte
const BASE_REACH := 3.2
const DUSTER_NAMES := [
	"Staubwedel", "Flauschwedel", "Großer Flauschwedel", "Federbesen", "Breitbesen",
	"Riesenwedel", "Wedel XXL", "Turbowedel", "Wedel des Oberbibliothekars",
]
const MILESTONES := {25: 500, 50: 1000, 75: 2000}   # Prozent -> Bonus-Münzen
const COMPLETE_AT := 99.5   # ab hier wird der Rest automatisch weggepustet
const COMPLETE_BONUS := 5000
const RADAR_DURATION := 6.0
const RADAR_COOLDOWN := 20.0
const RATE_WINDOW := 30     # Sekunden für die Tempo-Anzeige
const SAVE_PATH := "user://savegame.json"
const AUTOSAVE_SECONDS := 30.0

var coins := 0
var levels := {}                      # Upgrade-ID -> Stufe
var books_found: Array[String] = []
var zone_done := false

var dust: DustField
var player: Player
var hud: Hud
var sfx: Sfx
var shop: Shop

var _milestones_hit: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _world_body: StaticBody3D
var _book_transforms: Array[Transform3D] = []
var _book_colors := PackedColorArray()
var _shelf_spots: Array[Vector3] = []   # mögliche Verstecke für seltene Bücher auf Regalböden
var _rare_books: Array[RareBook] = []
var _mats := {}
var _coin_mult := 1.0
var _radar_max := RADAR_COOLDOWN
var _radar_cooldown := 0.0
var _radar_time := 0.0
var _popup_coins := 0
var _popup_timer := 0.0
var _rate_buckets: Array[int] = []
var _rate_timer := 0.0
var _autosave_timer := AUTOSAVE_SECONDS


func _ready() -> void:
	_rng.seed = 7
	_setup_input()
	_setup_environment()
	sfx = Sfx.new()
	add_child(sfx)

	_world_body = StaticBody3D.new()
	add_child(_world_body)
	dust = DustField.new()
	add_child(dust)

	var no_floor_dust: Array[Rect2] = []
	_build_hall()
	_build_shelves(no_floor_dust)
	_build_tables(no_floor_dust)
	var hx := HALL_SIZE.x * 0.5
	dust.add_area(Vector3.ZERO, HALL_SIZE - Vector2(0.4, 0.4), 0.2, 1.0, no_floor_dust)
	_build_books()
	dust.build()
	_add_air_motes(hx)

	player = Player.new()
	player.position = Vector3(0, 0.05, 12.0)
	player.dust_field = dust
	add_child(player)
	player.swept.connect(_on_swept)
	player.tool_changed.connect(func(_t: int) -> void: _refresh_hud())

	var loaded := _load_game()
	_place_rare_books(no_floor_dust)
	dust.flakes_removed.connect(_on_flakes_removed)
	_apply_stats()
	_rate_buckets.resize(RATE_WINDOW)
	_rate_buckets.fill(0)

	hud = Hud.new()
	hud.settings_changed.connect(_on_settings_changed)
	hud.menu_opened.connect(_save_game)
	hud.quit_requested.connect(_save_and_quit)
	hud.new_game_requested.connect(_new_game)
	add_child(hud)
	shop = Shop.new()
	shop.buy_requested.connect(_buy)
	add_child(shop)
	_refresh_hud()
	if loaded:
		hud.toast("Willkommen zurück im %s!" % ZONE_NAME, 4.0)
	else:
		hud.toast("Willkommen im %s! Halte die linke Maustaste gedrückt, um Staub zu wedeln." % ZONE_NAME, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_shop"):
		shop.open(coins, levels, books_found, _has_book("vacuum_plan"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("radar"):
		_try_radar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()


func _process(delta: float) -> void:
	sfx.set_cleaning(player.is_cleaning_held(), player.cleaning_dust, player.tool == Player.Tool.VACUUM)
	# Münz-Popups sammeln, damit nicht jedes Bild ein eigenes "+1" erscheint
	_popup_timer -= delta
	if _popup_coins > 0 and _popup_timer <= 0.0:
		hud.coin_popup(_popup_coins)
		sfx.coin()
		_popup_coins = 0
		_popup_timer = 0.2
	_radar_cooldown = maxf(0.0, _radar_cooldown - delta)
	hud.set_radar(_radar_cooldown)
	if _radar_time > 0.0:
		_radar_time -= delta
		if _radar_time <= 0.0:
			for book in _rare_books:
				book.show_beam(false)
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
		_save_game()


func _on_settings_changed(mouse_sensitivity: float, volume: float) -> void:
	player.mouse_sensitivity = mouse_sensitivity
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


# ---------------------------------------------------------------- Spielstand

func _on_flakes_removed(count: int, earned: int) -> void:
	_rate_buckets[RATE_WINDOW - 1] += count
	earned = roundi(earned * _coin_mult)
	coins += earned
	_popup_coins += earned
	var percent := dust.progress_percent()
	for m: int in MILESTONES:
		if percent >= m and not _milestones_hit.has(m):
			_milestones_hit.append(m)
			coins += MILESTONES[m]
			hud.toast("%d %% geschafft! Bonus: +%d Münzen" % [m, MILESTONES[m]])
			sfx.jingle()
	if not zone_done and percent >= COMPLETE_AT:
		zone_done = true
		coins += COMPLETE_BONUS
		dust.clear_all()   # ruft diese Funktion erneut auf, zone_done verhindert eine Schleife
		hud.toast("Der %s glänzt! Der letzte Staub fliegt davon.\nZonen-Bonus: +%d Münzen" % [ZONE_NAME, COMPLETE_BONUS], 6.0)
		sfx.jingle()
	_refresh_hud()


func _buy(id: String) -> void:
	var upgrade := _upgrade_by_id(id)
	var level := _lvl(id)
	var max_level: int = upgrade["max"]
	if level >= max_level:
		return
	var price := Upgrades.cost(upgrade, level)
	if coins < price:
		sfx.deny()
		return
	coins -= price
	levels[id] = level + 1
	_apply_stats()
	sfx.upgrade()
	if id == "vacuum":
		player.select_tool(Player.Tool.VACUUM)
		hud.toast("Staubsauger gekauft! Wechsle mit 1 und 2 oder dem Mausrad.", 4.0)
	shop.refresh(coins, levels, books_found, _has_book("vacuum_plan"))
	_refresh_hud()


## Rechnet alle Upgrades und Bücher in Werte für Spieler, Münzen und Radar um.
func _apply_stats() -> void:
	var radius := BASE_RADIUS + 0.25 * _lvl("radius") + (0.3 if _has_book("winds") else 0.0)
	var power := BASE_POWER * (1.0 + 0.25 * _lvl("power")) * (1.5 if _has_book("janitor") else 1.0)
	var reach := BASE_REACH + 0.6 * _lvl("reach")
	var speed := (1.0 + 0.12 * _lvl("speed")) * (1.25 if _has_book("feet") else 1.0)
	player.vacuum_unlocked = _lvl("vacuum") > 0 or _has_book("vacuum_plan")
	player.set_stats(radius, power, reach, speed)
	player.set_tool_level(_lvl("radius"))
	_coin_mult = (1.0 + 0.25 * _lvl("value")) * (1.5 if _has_book("gold") else 1.0)
	_radar_max = RADAR_COOLDOWN - 3.5 * _lvl("radar")


func _lvl(id: String) -> int:
	return levels.get(id, 0)


func _has_book(id: String) -> bool:
	return books_found.has(id)


func _upgrade_by_id(id: String) -> Dictionary:
	for u: Dictionary in Upgrades.UPGRADES:
		if u["id"] == id:
			return u
	return {}


func _affordable_upgrades() -> int:
	var n := 0
	for u: Dictionary in Upgrades.UPGRADES:
		var id: String = u["id"]
		if id == "vacuum" and _has_book("vacuum_plan"):
			continue
		var max_level: int = u["max"]
		if _lvl(id) < max_level and coins >= Upgrades.cost(u, _lvl(id)):
			n += 1
	return n


func _try_radar() -> void:
	if zone_done:
		return
	if _radar_cooldown > 0.0:
		hud.toast("Das Staub-Radar lädt noch %d Sekunden." % ceili(_radar_cooldown))
		sfx.deny()
		return
	_radar_cooldown = _radar_max
	_radar_time = RADAR_DURATION
	dust.highlight(RADAR_DURATION)
	for book in _rare_books:
		book.show_beam(true)
	if _rare_books.any(func(b: RareBook) -> bool: return not b.found):
		hud.toast("Staub-Radar: Der restliche Staub leuchtet gelb.\nGoldene Lichtsäulen zeigen versteckte Bücher!")
	else:
		hud.toast("Staub-Radar: Der restliche Staub leuchtet jetzt gelb.")
	sfx.upgrade()


func _refresh_hud() -> void:
	var tool_text: String = DUSTER_NAMES[mini(_lvl("radius"), DUSTER_NAMES.size() - 1)]
	if player.tool == Player.Tool.VACUUM:
		tool_text = "Staubsauger"
	if player.vacuum_unlocked:
		tool_text += "   [1] Wedel  [2] Sauger"
	hud.set_values(ZONE_NAME, dust.progress_percent(), coins, tool_text,
		_affordable_upgrades(), books_found.size(), Upgrades.BOOKS.size())


# ---------------------------------------------------------------- Seltene Bücher

## Versteckt die noch nicht gefundenen Bücher: drei auf dem Boden, zwei auf hohen Regalböden.
## Die Plätze sind immer gleich, damit sie nach dem Laden noch stimmen.
func _place_rare_books(no_floor_dust: Array[Rect2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector3] = []
	var hx := HALL_SIZE.x * 0.5 - 1.0
	var hz := HALL_SIZE.y * 0.5 - 1.0
	while spots.size() < 3:
		var p := Vector3(rng.randf_range(-hx, hx), 0.0, rng.randf_range(-hz, hz))
		var free := true
		for r in no_floor_dust:
			if r.grow(0.3).has_point(Vector2(p.x, p.z)):
				free = false
		if free and p.distance_to(Vector3(0, 0, 12)) > 4.0:
			spots.append(p)
	var high_spots := _shelf_spots.filter(func(v: Vector3) -> bool: return v.y > 1.5)
	while spots.size() < Upgrades.BOOKS.size():
		spots.append(high_spots[rng.randi() % high_spots.size()])

	for i in Upgrades.BOOKS.size():
		var id: String = Upgrades.BOOKS[i]["id"]
		if _has_book(id):
			continue
		var book := RareBook.new()
		book.book_id = id
		book.position = spots[i]
		add_child(book)
		_rare_books.append(book)


func _on_swept(point: Vector3, radius: float) -> void:
	for book in _rare_books:
		if not book.found and point.distance_to(book.global_position) < radius + 0.1:
			_collect_book(book)


func _collect_book(book: RareBook) -> void:
	book.reveal()
	_rare_books.erase(book)
	books_found.append(book.book_id)
	var info := Upgrades.book_by_id(book.book_id)
	_apply_stats()
	sfx.book_found()
	hud.toast("Seltenes Buch gefunden: »%s«\n%s" % [info["name"], info["perk"]], 5.0)
	if book.book_id == "vacuum_plan":
		player.select_tool(Player.Tool.VACUUM)
	_refresh_hud()
	_save_game()


# ---------------------------------------------------------------- Speichern

func _save_game() -> void:
	var data := {
		"version": 1,
		"coins": coins,
		"levels": levels,
		"books": books_found,
		"milestones": _milestones_hit,
		"zone_done": zone_done,
		"player": [player.position.x, player.position.y, player.position.z, player.rotation.y],
		"tool": player.tool,
		"dust": dust.save_state(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	coins = int(data.get("coins", 0))
	var saved_levels: Dictionary = data.get("levels", {})
	for id: String in saved_levels:
		levels[id] = int(saved_levels[id])
	for id: Variant in data.get("books", []):
		books_found.append(str(id))
	for m: Variant in data.get("milestones", []):
		_milestones_hit.append(int(m))
	zone_done = bool(data.get("zone_done", false))
	var p: Array = data.get("player", [])
	if p.size() == 4:
		player.position = Vector3(p[0], p[1], p[2])
		player.rotation.y = p[3]
	dust.load_state(str(data.get("dust", "")))
	_apply_stats()
	player.select_tool(int(data.get("tool", 0)) as Player.Tool)
	return true


func _save_and_quit() -> void:
	_save_game()
	get_tree().quit()


func _new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Eingabe

func _setup_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("open_shop", [KEY_U, KEY_TAB])
	_add_key_action("tool_1", [KEY_1])
	_add_key_action("tool_2", [KEY_2])
	_add_key_action("radar", [KEY_R])
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


# ---------------------------------------------------------------- Welt

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.75, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.42, 0.33)
	env.fog_density = 0.01
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.5)
	glow.emission_energy_multiplier = 3.0
	for x: float in [-6.0, 0.0, 6.0]:
		for z: float in [-11.0, -3.0, 5.0, 11.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, WALL_HEIGHT - 1.5, z)
			lamp.light_color = Color(1.0, 0.82, 0.6)
			lamp.light_energy = 1.6
			lamp.omni_range = 11.0
			lamp.shadow_enabled = x == 0.0
			add_child(lamp)
			var bulb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			sphere.material = glow
			bulb.mesh = sphere
			bulb.position = lamp.position + Vector3.UP * 0.3
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)
			_box(Vector3(0.02, 1.2, 0.02), Vector3(x, WALL_HEIGHT - 0.6, z), _mat("chain", Color(0.2, 0.18, 0.15)), false)


func _build_hall() -> void:
	var hx := HALL_SIZE.x * 0.5
	var hz := HALL_SIZE.y * 0.5
	_box(Vector3(HALL_SIZE.x, 0.2, HALL_SIZE.y), Vector3(0, -0.1, 0), _floor_mat())
	var wall := _mat("wall", Color(0.5, 0.4, 0.32), 0.95)
	_box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, -hz - 0.15), wall)
	_box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, hz + 0.15), wall)
	_box(Vector3(0.3, WALL_HEIGHT, HALL_SIZE.y), Vector3(-hx - 0.15, WALL_HEIGHT * 0.5, 0), wall)
	_box(Vector3(0.3, WALL_HEIGHT, HALL_SIZE.y), Vector3(hx + 0.15, WALL_HEIGHT * 0.5, 0), wall)
	_box(Vector3(HALL_SIZE.x + 0.6, 0.3, HALL_SIZE.y + 0.6), Vector3(0, WALL_HEIGHT + 0.15, 0),
		_mat("ceiling", Color(0.3, 0.22, 0.16)), false)


func _build_shelves(no_floor_dust: Array[Rect2]) -> void:
	var hx := HALL_SIZE.x * 0.5
	var hz := HALL_SIZE.y * 0.5
	# Doppelregale Rücken an Rücken, in Reihen quer zum Mittelgang
	for z: float in ROW_Z:
		for x: float in COLUMN_X:
			_build_case(x, z - CASE_DEPTH * 0.5, -1.0, CASE_WIDTH, CASE_HEIGHT, CASE_BOARDS, DUSTY_BOARDS)
			_build_case(x, z + CASE_DEPTH * 0.5, 1.0, CASE_WIDTH, CASE_HEIGHT, CASE_BOARDS, DUSTY_BOARDS)
			no_floor_dust.append(Rect2(x - CASE_WIDTH * 0.5 - 0.05, z - CASE_DEPTH - 0.05, CASE_WIDTH + 0.1, CASE_DEPTH * 2.0 + 0.1))
	# Riesiges Wandregal an der Stirnwand – nur Kulisse, damit die Bibliothek gewaltig wirkt
	var tall_boards: Array = []
	var y := 0.1
	while y < WALL_HEIGHT - 0.6:
		tall_boards.append(y)
		y += 0.5
	_build_case(0.0, -hz + CASE_DEPTH * 0.5, 1.0, HALL_SIZE.x - 0.02, WALL_HEIGHT - 0.1, tall_boards, 0)
	no_floor_dust.append(Rect2(-hx, -hz, HALL_SIZE.x, CASE_DEPTH + 0.05))


## Ein Regal. dir = +1 heißt: die offene Seite zeigt nach +z.
func _build_case(cx: float, cz: float, dir: float, width: float, height: float, boards: Array, dusty: int) -> void:
	var d := CASE_DEPTH
	var wood := _mat("shelf", Color(0.36, 0.22, 0.13), 0.7)
	_box(Vector3(width, height, 0.03), Vector3(cx, height * 0.5, cz - dir * (d * 0.5 - 0.015)), wood)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.05, height, d), Vector3(cx + side * (width * 0.5 - 0.025), height * 0.5, cz), wood)
	_box(Vector3(width, 0.05, d), Vector3(cx, height - 0.025, cz), wood)

	var inner := width - 0.1
	var back := cz - dir * (d * 0.5 - 0.03)
	var no_excludes: Array[Rect2] = []
	for i in boards.size():
		var board_y: float = boards[i]
		var top := board_y + 0.02
		var next_y := height
		if i + 1 < boards.size():
			next_y = boards[i + 1]
		var gap := next_y - top - 0.06
		_box(Vector3(inner, 0.04, d), Vector3(cx, board_y, cz), wood)
		_fill_books(cx, back, dir, inner, top, gap)
		# Ein Block als Kollision für die Bücher, damit der Wedel-Strahl daran hängen bleibt
		var block_h := minf(gap, 0.3)
		_add_collider(Vector3(inner, block_h, 0.3), Vector3(cx, top + block_h * 0.5, back + dir * 0.15))
		if i < dusty:
			var strip := d - 0.36
			var extra := UPPER_BOARD_DIRT if board_y > 1.5 else 0.0
			_shelf_spots.append(Vector3(cx + _rng.randf_range(-inner * 0.4, inner * 0.4), top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)))
			dust.add_area(Vector3(cx, top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)),
				Vector2(inner - 0.04, strip), 0.075, 0.42, no_excludes, extra)
	if dusty > 0:
		_build_ladder(cx + _rng.randf_range(-1.0, 1.0), cz + dir * (d * 0.5), dir, height)


## Eine Leiter vor dem Regal. Man klettert, indem man auf das Regal zu läuft.
func _build_ladder(x: float, front_z: float, dir: float, height: float) -> void:
	var metal := _mat("ladder", Color(0.55, 0.42, 0.25), 0.5)
	var z := front_z + dir * 0.12
	for side: float in [-0.25, 0.25]:
		_box(Vector3(0.04, height + 0.1, 0.04), Vector3(x + side, (height + 0.1) * 0.5, z), metal, false)
	var y := 0.3
	while y < height:
		_box(Vector3(0.5, 0.03, 0.03), Vector3(x, y, z), metal, false)
		y += 0.3

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, height + 1.0, 0.7)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(x, (height + 1.0) * 0.5, front_z + dir * 0.35)
	add_child(area)
	var ladder := {"facing": Vector3(0, 0, dir), "top": LADDER_TOP}
	area.body_entered.connect(_on_ladder_body_entered.bind(ladder))
	area.body_exited.connect(_on_ladder_body_exited.bind(ladder))


func _on_ladder_body_entered(body: Node3D, ladder: Dictionary) -> void:
	if body == player:
		player.enter_ladder(ladder)


func _on_ladder_body_exited(body: Node3D, ladder: Dictionary) -> void:
	if body == player:
		player.exit_ladder(ladder)


func _fill_books(cx: float, back: float, dir: float, inner: float, top: float, gap: float) -> void:
	var x := cx - inner * 0.5 + 0.02
	var end := cx + inner * 0.5 - 0.02
	while true:
		var w := _rng.randf_range(0.035, 0.085)
		if x + w > end:
			break
		if _rng.randf() < 0.04:   # hin und wieder eine Lücke
			x += _rng.randf_range(0.05, 0.25)
			continue
		var h := minf(_rng.randf_range(0.24, 0.4), gap)
		var depth := _rng.randf_range(0.2, 0.29)
		_book_transforms.append(Transform3D(Basis().scaled(Vector3(w, h, depth)),
			Vector3(x + w * 0.5, top + h * 0.5, back + dir * depth * 0.5)))
		var color: Color = BOOK_COLORS[_rng.randi() % BOOK_COLORS.size()]
		_book_colors.append(color.darkened(_rng.randf_range(0.0, 0.35)))
		x += w + 0.003


func _build_books() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	var box := BoxMesh.new()
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = _book_transforms.size()
	for i in _book_transforms.size():
		mm.set_instance_transform(i, _book_transforms[i])
		mm.set_instance_color(i, _book_colors[i])
	var books := MultiMeshInstance3D.new()
	books.multimesh = mm
	add_child(books)


func _build_tables(no_floor_dust: Array[Rect2]) -> void:
	var wood := _mat("table", Color(0.42, 0.26, 0.14), 0.6)
	for x: float in [-5.0, 5.0]:
		for z: float in [8.0, 11.5]:
			_box(Vector3(2.6, 0.06, 1.2), Vector3(x, 0.75, z), wood)
			for lx: float in [-1.15, 1.15]:
				for lz: float in [-0.5, 0.5]:
					_box(Vector3(0.08, 0.72, 0.08), Vector3(x + lx, 0.36, z + lz), wood, false)
			dust.add_area(Vector3(x, 0.78, z), Vector2(2.5, 1.1), 0.1, 0.6)
			# Unter dem Tisch kommt man mit dem Wedel nicht hin
			no_floor_dust.append(Rect2(x - 1.35, z - 0.65, 2.7, 1.3))


func _add_air_motes(hx: float) -> void:
	var motes := CPUParticles3D.new()
	motes.amount = 400
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.position = Vector3(0, 3.0, 0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(hx, 3.0, HALL_SIZE.y * 0.5)
	motes.direction = Vector3.UP
	motes.spread = 180.0
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.08
	motes.gravity = Vector3(0, -0.01, 0)
	motes.color = Color(1.0, 0.9, 0.7, 0.35)
	motes.mesh = Player.make_particle_quad(0.025)
	add_child(motes)


# ---------------------------------------------------------------- Helfer

func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh_instance.mesh = box
	mesh_instance.position = pos
	add_child(mesh_instance)
	if collide:
		_add_collider(size, pos)


func _add_collider(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	_world_body.add_child(col)


func _mat(key: String, color: Color, roughness := 0.8) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_mats[key] = m
	return m


func _floor_mat() -> StandardMaterial3D:
	# Gestreiftes Rauschen sieht aus wie Holzmaserung. Glänzt, sobald der Staub weg ist.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.4, 0.24)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.15, 1.0, 2.0)
	m.roughness = 0.35
	return m
