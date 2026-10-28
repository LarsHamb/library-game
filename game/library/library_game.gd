extends CleanGame
## Das Bibliotheks-Thema: baut den Großen Lesesaal und die Werkzeug-Modelle.
## Alle Spielregeln (Münzen, Upgrades, Speichern ...) kommen aus addons/clean_core.

const LibraryConfig := preload("res://game/library/library_config.gd")

# --- Raum ---
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

const DUSTER_NAMES := [
	"Staubwedel", "Flauschwedel", "Großer Flauschwedel", "Federbesen", "Breitbesen",
	"Riesenwedel", "Wedel XXL", "Turbowedel", "Wedel des Oberbibliothekars",
]

var _rng := RandomNumberGenerator.new()
var _book_transforms: Array[Transform3D] = []
var _book_colors := PackedColorArray()
var _shelf_spots: Array[Vector3] = []   # mögliche Verstecke für seltene Bücher auf Regalböden
var _no_floor_dust: Array[Rect2] = []


# ================================================================ Anbindung an den Kern

func _create_config() -> CleanGameConfig:
	return LibraryConfig.create()


func _build_world() -> void:
	_rng.seed = 7
	_build_hall()
	_build_shelves(_no_floor_dust)
	_build_tables(_no_floor_dust)
	mess.add_area(Vector3.ZERO, HALL_SIZE - Vector2(0.4, 0.4), 0.2, 1.0, _no_floor_dust)
	_build_books()
	_add_air_motes(HALL_SIZE.x * 0.5)


func _make_tool_visual(tool: CleanTool) -> Node3D:
	if tool.id == "vacuum":
		return _make_vacuum()
	return _make_duster()


func _tool_display_name(tool: CleanTool) -> String:
	if tool.id == "duster":
		return DUSTER_NAMES[mini(state.level("radius"), DUSTER_NAMES.size() - 1)]
	return tool.display_name


func _on_stats_applied() -> void:
	player.set_tool_scale("duster", 1.0 + state.level("radius") * 0.15)


## Drei Bücher auf dem Boden, zwei auf hohen Regalböden. Immer dieselben Plätze.
func _collectible_spots() -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector3] = []
	var hx := HALL_SIZE.x * 0.5 - 1.0
	var hz := HALL_SIZE.y * 0.5 - 1.0
	while spots.size() < 3:
		var p := Vector3(rng.randf_range(-hx, hx), 0.0, rng.randf_range(-hz, hz))
		var free := true
		for r in _no_floor_dust:
			if r.grow(0.3).has_point(Vector2(p.x, p.z)):
				free = false
		if free and p.distance_to(config.player_start) > 4.0:
			spots.append(p)
	var high_spots := _shelf_spots.filter(func(v: Vector3) -> bool: return v.y > 1.5)
	while spots.size() < config.collectibles.size():
		spots.append(high_spots[rng.randi() % high_spots.size()])
	return spots


func _make_collectible_model(_def: CleanCollectibleDef) -> Node3D:
	var book := MeshInstance3D.new()
	var book_mesh := BoxMesh.new()
	book_mesh.size = Vector3(0.24, 0.05, 0.17)
	var book_mat := StandardMaterial3D.new()
	book_mat.albedo_color = Color(0.45, 0.08, 0.1)
	book_mat.emission_enabled = true
	book_mat.emission = Color(1.0, 0.75, 0.3)
	book_mat.emission_energy_multiplier = 0.6
	book_mesh.material = book_mat
	book.mesh = book_mesh
	book.position.y = 0.025
	book.rotation.y = randf() * TAU
	return book


# ================================================================ Werkzeug-Modelle

func _make_duster() -> Node3D:
	var duster := Node3D.new()
	duster.rotation = Vector3(-1.22, 0.0, -0.21)   # schräg nach vorne oben
	var handle := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.016
	stick.height = 0.42
	stick.material = mat("duster_handle", Color(0.45, 0.28, 0.15))
	handle.mesh = stick
	duster.add_child(handle)
	var head := MeshInstance3D.new()
	head.name = "Head"   # wird mit den Upgrades größer
	var fluff := SphereMesh.new()
	fluff.radius = 0.07
	fluff.height = 0.14
	fluff.material = mat("duster_feathers", Color(0.93, 0.62, 0.72), 1.0)
	head.mesh = fluff
	head.position.y = 0.28
	head.scale = Vector3(1.0, 1.5, 1.0)
	duster.add_child(head)
	return duster


func _make_vacuum() -> Node3D:
	var vacuum := Node3D.new()
	vacuum.rotation = Vector3(-1.35, 0.0, -0.1)
	var red := mat("vacuum_red", Color(0.7, 0.15, 0.12), 0.4)
	var steel := mat("vacuum_steel", Color(0.7, 0.7, 0.72), 0.3)
	steel.metallic = 0.8
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06
	body_mesh.height = 0.22
	body_mesh.material = red
	body.mesh = body_mesh
	vacuum.add_child(body)
	var tube := MeshInstance3D.new()
	var tube_mesh := CylinderMesh.new()
	tube_mesh.top_radius = 0.018
	tube_mesh.bottom_radius = 0.018
	tube_mesh.height = 0.4
	tube_mesh.material = steel
	tube.mesh = tube_mesh
	tube.position.y = 0.3
	vacuum.add_child(tube)
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := BoxMesh.new()
	nozzle_mesh.size = Vector3(0.12, 0.03, 0.05)
	nozzle_mesh.material = red
	nozzle.mesh = nozzle_mesh
	nozzle.position.y = 0.51
	vacuum.add_child(nozzle)
	return vacuum


# ================================================================ Lesesaal

func _build_environment() -> void:
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
			box(Vector3(0.02, 1.2, 0.02), Vector3(x, WALL_HEIGHT - 0.6, z), mat("chain", Color(0.2, 0.18, 0.15)), false)


func _build_hall() -> void:
	var hx := HALL_SIZE.x * 0.5
	var hz := HALL_SIZE.y * 0.5
	box(Vector3(HALL_SIZE.x, 0.2, HALL_SIZE.y), Vector3(0, -0.1, 0), _floormat())
	var wall := mat("wall", Color(0.5, 0.4, 0.32), 0.95)
	box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, -hz - 0.15), wall)
	box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, hz + 0.15), wall)
	box(Vector3(0.3, WALL_HEIGHT, HALL_SIZE.y), Vector3(-hx - 0.15, WALL_HEIGHT * 0.5, 0), wall)
	box(Vector3(0.3, WALL_HEIGHT, HALL_SIZE.y), Vector3(hx + 0.15, WALL_HEIGHT * 0.5, 0), wall)
	box(Vector3(HALL_SIZE.x + 0.6, 0.3, HALL_SIZE.y + 0.6), Vector3(0, WALL_HEIGHT + 0.15, 0),
		mat("ceiling", Color(0.3, 0.22, 0.16)), false)


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
	var wood := mat("shelf", Color(0.36, 0.22, 0.13), 0.7)
	box(Vector3(width, height, 0.03), Vector3(cx, height * 0.5, cz - dir * (d * 0.5 - 0.015)), wood)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.05, height, d), Vector3(cx + side * (width * 0.5 - 0.025), height * 0.5, cz), wood)
	box(Vector3(width, 0.05, d), Vector3(cx, height - 0.025, cz), wood)

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
		box(Vector3(inner, 0.04, d), Vector3(cx, board_y, cz), wood)
		_fill_books(cx, back, dir, inner, top, gap)
		# Ein Block als Kollision für die Bücher, damit der Wedel-Strahl daran hängen bleibt
		var block_h := minf(gap, 0.3)
		add_collider(Vector3(inner, block_h, 0.3), Vector3(cx, top + block_h * 0.5, back + dir * 0.15))
		if i < dusty:
			var strip := d - 0.36
			var extra := UPPER_BOARD_DIRT if board_y > 1.5 else 0.0
			_shelf_spots.append(Vector3(cx + _rng.randf_range(-inner * 0.4, inner * 0.4), top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)))
			mess.add_area(Vector3(cx, top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)),
				Vector2(inner - 0.04, strip), 0.075, 0.42, no_excludes, extra)
	if dusty > 0:
		_build_ladder(cx + _rng.randf_range(-1.0, 1.0), cz + dir * (d * 0.5), dir, height)


## Eine Leiter vor dem Regal. Man klettert, indem man auf das Regal zu läuft.
func _build_ladder(x: float, front_z: float, dir: float, height: float) -> void:
	var metal := mat("ladder", Color(0.55, 0.42, 0.25), 0.5)
	var z := front_z + dir * 0.12
	for side: float in [-0.25, 0.25]:
		box(Vector3(0.04, height + 0.1, 0.04), Vector3(x + side, (height + 0.1) * 0.5, z), metal, false)
	var y := 0.3
	while y < height:
		box(Vector3(0.5, 0.03, 0.03), Vector3(x, y, z), metal, false)
		y += 0.3
	add_ladder(Vector3(x, 0.0, front_z + dir * 0.35), Vector3(0, 0, dir), height, LADDER_TOP)


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
	var book_mat := StandardMaterial3D.new()
	book_mat.vertex_color_use_as_albedo = true
	book_mat.roughness = 0.85
	var book_mesh := BoxMesh.new()
	book_mesh.material = book_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = book_mesh
	mm.instance_count = _book_transforms.size()
	for i in _book_transforms.size():
		mm.set_instance_transform(i, _book_transforms[i])
		mm.set_instance_color(i, _book_colors[i])
	var books := MultiMeshInstance3D.new()
	books.multimesh = mm
	add_child(books)


func _build_tables(no_floor_dust: Array[Rect2]) -> void:
	var wood := mat("table", Color(0.42, 0.26, 0.14), 0.6)
	for x: float in [-5.0, 5.0]:
		for z: float in [8.0, 11.5]:
			box(Vector3(2.6, 0.06, 1.2), Vector3(x, 0.75, z), wood)
			for lx: float in [-1.15, 1.15]:
				for lz: float in [-0.5, 0.5]:
					box(Vector3(0.08, 0.72, 0.08), Vector3(x + lx, 0.36, z + lz), wood, false)
			mess.add_area(Vector3(x, 0.78, z), Vector2(2.5, 1.1), 0.1, 0.6)
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
	motes.mesh = CleanPlayer.make_particle_quad(0.025)
	add_child(motes)


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
