extends Node3D
## Baut den Lesesaal auf und hält den Spielstand: Fortschritt, Münzen und Wedel-Upgrade.

const DustField := preload("res://scripts/dust_field.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

# --- Raum ---
const ZONE_NAME := "Großer Lesesaal"
const HALL_SIZE := Vector2(22.0, 28.0)   # Breite (x) und Länge (z) in Metern
const WALL_HEIGHT := 7.0

# --- Regale ---
const CASE_WIDTH := 3.5
const CASE_DEPTH := 0.55
const CASE_HEIGHT := 3.0
const CASE_BOARDS := [0.1, 0.6, 1.1, 1.6, 2.1, 2.6]
const DUSTY_BOARDS := 3   # nur die unteren drei Böden sind von unten erreichbar
const ROW_Z := [-10.0, -5.5, -1.0, 3.5]
const COLUMN_X := [-7.0, -3.5, 3.5, 7.0]
const BOOK_COLORS := [
	Color(0.55, 0.12, 0.1), Color(0.15, 0.3, 0.18), Color(0.12, 0.2, 0.4),
	Color(0.45, 0.3, 0.12), Color(0.3, 0.12, 0.3), Color(0.6, 0.48, 0.25),
	Color(0.2, 0.18, 0.16), Color(0.5, 0.2, 0.08),
]

# --- Wirtschaft ---
const COINS_PER_FLAKE := 1
const UPGRADE_BASE_COST := 60
const UPGRADE_COST_FACTOR := 1.7
const BASE_RADIUS := 0.45
const RADIUS_PER_LEVEL := 0.25
const TOOL_NAMES := [
	"Staubwedel", "Flauschwedel", "Großer Flauschwedel", "Federbesen", "Breitbesen",
	"Riesenwedel", "Wedel XXL", "Turbowedel", "Wedel des Oberbibliothekars",
]
const MILESTONES := {25: 250, 50: 500, 75: 1000}   # Prozent -> Bonus-Münzen
const COMPLETE_AT := 98.0   # ab hier wird der Rest automatisch weggepustet
const COMPLETE_BONUS := 2000

var coins := 0
var upgrade_level := 0
var zone_done := false

var dust: DustField
var player: Player
var hud: Hud

var _milestones_hit: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _world_body: StaticBody3D
var _book_transforms: Array[Transform3D] = []
var _book_colors := PackedColorArray()
var _mats := {}


func _ready() -> void:
	_rng.seed = 7
	_setup_input()
	_setup_environment()

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
	dust.flakes_removed.connect(_on_flakes_removed)
	_add_air_motes(hx)

	player = Player.new()
	player.position = Vector3(0, 0.05, 12.0)
	player.dust_field = dust
	add_child(player)
	player.set_clean_radius(_radius_for(upgrade_level))

	hud = Hud.new()
	add_child(hud)
	_refresh_hud()
	hud.toast("Willkommen im %s! Halte die linke Maustaste gedrückt, um Staub zu wedeln." % ZONE_NAME, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("buy_upgrade"):
		_try_buy_upgrade()


# ---------------------------------------------------------------- Spielstand

func _on_flakes_removed(count: int) -> void:
	coins += count * COINS_PER_FLAKE
	var percent := dust.progress_percent()
	for m: int in MILESTONES:
		if percent >= m and not _milestones_hit.has(m):
			_milestones_hit.append(m)
			coins += MILESTONES[m]
			hud.toast("%d %% geschafft! Bonus: +%d Münzen" % [m, MILESTONES[m]])
	if not zone_done and percent >= COMPLETE_AT:
		zone_done = true
		coins += COMPLETE_BONUS
		dust.clear_all()   # ruft diese Funktion erneut auf, zone_done verhindert eine Schleife
		hud.toast("Der %s glänzt! Der letzte Staub fliegt davon.\nZonen-Bonus: +%d Münzen" % [ZONE_NAME, COMPLETE_BONUS], 6.0)
	_refresh_hud()


func _try_buy_upgrade() -> void:
	if upgrade_level >= TOOL_NAMES.size() - 1:
		hud.toast("Dein Wedel ist schon so groß wie er nur sein kann!")
		return
	var cost := _upgrade_cost()
	if coins < cost:
		hud.toast("Dir fehlen noch %d Münzen für das Upgrade." % (cost - coins))
		return
	coins -= cost
	upgrade_level += 1
	player.set_clean_radius(_radius_for(upgrade_level))
	player.set_tool_level(upgrade_level)
	hud.toast("Neues Werkzeug: %s!" % TOOL_NAMES[upgrade_level])
	_refresh_hud()


func _upgrade_cost() -> int:
	return roundi(UPGRADE_BASE_COST * pow(UPGRADE_COST_FACTOR, upgrade_level))


func _radius_for(level: int) -> float:
	return BASE_RADIUS + RADIUS_PER_LEVEL * level


func _refresh_hud() -> void:
	var next_cost := -1 if upgrade_level >= TOOL_NAMES.size() - 1 else _upgrade_cost()
	hud.set_values(ZONE_NAME, dust.progress_percent(), coins, TOOL_NAMES[upgrade_level],
		upgrade_level, _radius_for(upgrade_level), next_cost)


# ---------------------------------------------------------------- Eingabe

func _setup_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("buy_upgrade", [KEY_U, KEY_E])
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
			dust.add_area(Vector3(cx, top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)),
				Vector2(inner - 0.04, strip), 0.075, 0.42)


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
