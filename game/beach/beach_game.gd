extends CleanGame
## Das Strand-Thema: drei Strandabschnitte voller angespültem Müll.
## Erst sammelt man mit der Greifzange Stück für Stück, später erledigen Siebmaschinen,
## Drohnen und Förderbänder die Arbeit. Unter dem Müll liegen Schätze, überall Muscheln.
## Alle Spielregeln (Münzen, Upgrades, Speichern ...) kommen aus addons/clean_core.

const BeachConfig := preload("res://game/beach/beach_config.gd")
const SAND := preload("res://game/beach/shaders/sand.gdshader")
const WATER := preload("res://game/beach/shaders/water.gdshader")
const SKY := preload("res://game/beach/shaders/sky.gdshader")
const ROCK := preload("res://game/beach/shaders/rock.gdshader")
const WOOD := preload("res://game/beach/shaders/wood.gdshader")
const STRIPES := preload("res://game/beach/shaders/stripes.gdshader")
const FOLIAGE := preload("res://game/beach/shaders/foliage.gdshader")
const LITTER_FLAKE := preload("res://game/beach/shaders/litter_flake.gdshader")
const LITTER_ITEM := preload("res://game/beach/shaders/litter_item.gdshader")
const NET := preload("res://game/beach/shaders/net.gdshader")
const SEA_SOUND := "res://game/beach/audio/meer.ogg"

# --- Gelände (gleiche Werte wie in shaders/ground.gdshaderinc) ---
const SHORE_Z := 8.0        # ab hier fällt der Strand zum Wasser ab
const DUNE_Z := -16.5       # ab hier beginnen die Dünen
const WATER_LEVEL := -0.12
const BACK_Z := -16.0       # Dünenzaun: weiter nach hinten geht es nicht
const FRONT_Z := 10.6       # so weit kann man ins Wasser waten
const LITTER_FRONT := 8.6   # bis hierhin liegt Müll
const WEST_END := -50.0
const EAST_END := 52.0
const DIVIDER_X := 22.0     # Felsriegel zwischen den Abschnitten (bei −22 und +22)
const GAP_Z := Vector2(-1.0, 3.0)   # Durchgang im Felsriegel
const BELT_Z := 5.8

const GRABBER_NAMES := [
	"Greifzange", "Lange Greifzange", "Breite Greifzange", "Doppelgreifer", "Profi-Greifer",
	"Riesengreifer", "Greifer XXL", "Turbogreifer", "Greifer der Strandwacht",
]
const ITEM_KINDS := 10
const ITEM_TINTS := [
	[Color(0.8, 0.92, 1.0), Color(0.82, 1.0, 0.85), Color(1, 1, 1)],                    # PET-Flasche
	[Color(0.85, 0.15, 0.12), Color(0.15, 0.35, 0.85), Color(0.2, 0.65, 0.3), Color(0.8, 0.8, 0.82)],   # Dose
	[Color(1, 1, 1), Color(0.45, 0.65, 1.0), Color(1.0, 0.7, 0.8), Color(1.0, 0.95, 0.5)],   # Tüte
	[Color(1.0, 0.4, 0.5), Color(0.3, 0.7, 1.0), Color(1.0, 0.85, 0.2), Color(0.3, 0.85, 0.5)],   # Flipflop
	[Color(1.0, 0.45, 0.1), Color(0.95, 0.15, 0.1), Color(1.0, 0.85, 0.15)],             # Boje
	[Color(0.2, 0.4, 0.85), Color(1.0, 0.8, 0.15), Color(0.85, 0.2, 0.15), Color(0.2, 0.6, 0.35)],   # Kistenteil
	[Color(0.45, 0.28, 0.1), Color(0.2, 0.45, 0.2), Color(0.35, 0.55, 0.45)],             # Glasflasche
	[Color(1, 1, 1)],                                                                   # Reifen
	[Color(1.0, 0.55, 0.15), Color(0.2, 0.45, 0.9), Color(1.0, 0.9, 0.3), Color(0.2, 0.7, 0.6)],   # Seil
	[Color(0.95, 0.2, 0.15), Color(0.2, 0.5, 0.95), Color(0.3, 0.8, 0.35), Color(1.0, 0.85, 0.2)],  # Sandeimer
]

var _rng := RandomNumberGenerator.new()
var _bmats := {}
var _excludes := {}                     # Zonen-ID -> Flächen ohne Müll (unter Häusern, Felsen ...)
var _treasure_spots: Array[Vector3] = []
var _shell_slots: Array[Transform3D] = []
var _lanes: Array[Dictionary] = []      # Bahnen der Siebmaschinen: {from, to, zone}
var _belts: Array[Dictionary] = []      # Plätze der Förderbänder: {from, to, zone}
var _taken := {}                        # belegte Bahnen/Bänder
var _gulls: Array[Dictionary] = []
var _boats: Array[Node3D] = []
var _item_mesh: ArrayMesh
var _group_id := 0
var _sea_player: AudioStreamPlayer


# ================================================================ Anbindung an den Kern

func _create_config() -> CleanGameConfig:
	return BeachConfig.create()


func _build_world() -> void:
	_rng.seed = 2026
	_item_mesh = _build_item_mesh()
	var main_zone := zones[0]
	var rocks := add_zone("rocks", "Felsenbucht", Rect2(WEST_END, BACK_Z, -DIVIDER_X - WEST_END, LITTER_FRONT - BACK_Z), 12000, 1.6)
	rocks.spawn = Vector3(-30.0, 0.05, -6.0)
	rocks.spawn_yaw = PI
	var wreck := add_zone("wreck", "Wrackküste", Rect2(DIVIDER_X, BACK_Z, EAST_END - DIVIDER_X, LITTER_FRONT - BACK_Z), 30000, 2.5)
	wreck.spawn = Vector3(28.0, 0.05, -4.0)
	wreck.spawn_yaw = PI
	for z in zones:
		z.mess.base_color = Color.WHITE
		z.mess.flake_shader = LITTER_FLAKE
		var ex: Array[Rect2] = []
		_excludes[z.id] = ex

	_build_ground()
	_build_sea()
	_build_dune_fence()
	_build_vegetation()
	_build_main_props()
	_build_rocks_zone(rocks)
	_build_wreck_zone(wreck)
	_build_dividers(rocks, wreck)
	_build_boundaries()
	_build_far_scenery()
	_plan_machines()

	# Müll: viel Kleinkram, dazu große Teile, oft in Haufen
	_scatter_litter(main_zone, Rect2(-21.5, -15.6, 43.0, LITTER_FRONT + 15.6), 5200)
	_scatter_litter(rocks, Rect2(WEST_END + 0.5, -15.6, 27.0, LITTER_FRONT + 15.6), 2600)
	_scatter_litter(wreck, Rect2(DIVIDER_X + 0.5, -15.6, 29.0, LITTER_FRONT + 15.6), 2900)
	_scatter_items(main_zone, Rect2(-21.0, -15.0, 42.0, 23.0), 22, 110)
	_scatter_items(rocks, Rect2(-49.0, -15.0, 26.0, 23.0), 14, 60)
	_scatter_items(wreck, Rect2(23.0, -15.0, 28.0, 23.0), 16, 70)
	_build_nets(main_zone, rocks, wreck)
	_scatter_shells(main_zone, rocks, wreck)
	_build_gulls()


func _make_tool_visual(tool: CleanTool) -> Node3D:
	match tool.id:
		"rake":
			return _make_rake()
		"vacuum":
			return _make_vacuum()
		"cutter":
			return _make_cutter()
	return _make_grabber()


func _tool_display_name(tool: CleanTool) -> String:
	if tool.id == "grabber":
		return GRABBER_NAMES[mini(state.level("radius"), GRABBER_NAMES.size() - 1)]
	return tool.display_name


func _on_stats_applied() -> void:
	var s := 1.0 + state.level("radius") * 0.12
	for id: String in ["grabber", "rake", "vacuum", "cutter"]:
		player.set_tool_scale(id, s)
	player.set_particle_color(Color(0.93, 0.84, 0.66, 0.75))
	# So viele Siebmaschinen und Förderbänder, wie in den offenen Abschnitten Platz haben
	var lanes := _free_count(_lanes)
	var belts := _free_count(_belts)
	var changed := false
	for u in config.upgrades:
		if u.spawns_bot == "sifter" and u.max_level != lanes:
			u.max_level = maxi(lanes, state.level(u.id))
			changed = true
		elif u.spawns_bot == "belt" and u.max_level != belts:
			u.max_level = maxi(belts, state.level(u.id))
			changed = true
	if changed and shop and shop.visible:
		shop.refresh()


func _spawn_bot(kind: String, index: int) -> CleanBot:
	match kind:
		"sifter":
			var lane := _take(_lanes)
			if lane.is_empty():
				return null
			var bot := BeachSifter.new()
			bot.lane_from = lane["from"]
			bot.lane_to = lane["to"]
			bot.position = lane["from"]
			return bot
		"belt":
			var spot := _take(_belts)
			if spot.is_empty():
				return null
			var belt := BeachBelt.new()
			belt.belt_from = spot["from"]
			belt.belt_to = spot["to"]
			belt.reach_dir = Vector3.BACK
			belt.position = ((spot["from"] as Vector3) + (spot["to"] as Vector3)) * 0.5
			return belt
		"drone":
			var drone := super(kind, index) as CleanDrone
			drone.altitude = 4.2 + (index % 3) * 0.5
			drone.max_target_height = 0.6
			drone.position = Vector3(-3.0 + index * 1.2, 0.0, -12.0)
			return drone
	return super(kind, index)


func _make_bot_model(kind: String) -> Node3D:
	match kind:
		"sifter":
			return _make_sifter_model()
		"drone":
			return _make_drone_model()
	return null


## Schätze liegen unter Müllhaufen: sechs in der Möwenbucht, je einer in den anderen Abschnitten.
func _collectible_spots() -> Array[Vector3]:
	return _treasure_spots


func _make_collectible_model(def: CleanCollectibleDef) -> Node3D:
	return _make_treasure(def.id)


func _title_view() -> Dictionary:
	return {"from": Vector3(-10.0, 3.4, -9.5), "to": Vector3(10.0, 3.0, -9.5), "look": Vector3(0, 0.4, 8.0)}


func _screenshot_views() -> Array[Dictionary]:
	return [
		{"name": "bucht", "pos": Vector3(0, 1.7, -9.0), "look": Vector3(0, 0.6, 6.0)},
		{"name": "von_oben", "pos": Vector3(-6, 9.0, -15.5), "look": Vector3(2, 0, 3)},
		{"name": "muell_nah", "pos": Vector3(1.0, 1.4, 3.0), "look": Vector3(1.5, 0, 6.5)},
		{"name": "spuelsaum", "pos": Vector3(-6, 1.6, 6.0), "look": Vector3(4, 0.0, 9.5)},
		{"name": "strandkoerbe", "pos": Vector3(-1.5, 1.7, -6.0), "look": Vector3(-12, 0.8, -12.5)},
		{"name": "kiosk", "pos": Vector3(-1.0, 1.6, -9.5), "look": Vector3(-5.0, 1.0, -14.5)},
		{"name": "duenen", "pos": Vector3(3, 1.8, -6.0), "look": Vector3(6, 2.5, -24.0)},
		{"name": "felsenbucht", "pos": Vector3(-24.0, 2.2, 1.0), "look": Vector3(-38, 0.5, -2)},
		{"name": "wrackkueste", "pos": Vector3(25.0, 2.0, 0.0), "look": Vector3(38, 1.0, -9)},
	]


func _ready() -> void:
	super()
	_start_sea_sound()


func _process(delta: float) -> void:
	super(delta)
	var t := Time.get_ticks_msec() * 0.001
	for g in _gulls:
		var node: Node3D = g["node"]
		var a: float = g["phase"] + t * g["speed"]
		var c: Vector3 = g["center"]
		var r: float = g["radius"]
		node.position = c + Vector3(cos(a) * r, sin(a * 0.7) * 0.6, sin(a) * r)
		node.rotation.y = -a - (PI if g["speed"] > 0.0 else 0.0)
		node.rotation.z = 0.25 * signf(g["speed"])
		var flap := sin(t * 7.0 + g["phase"] * 3.0)
		flap = flap if fmod(t + g["phase"], 4.0) < 1.6 else 0.15   # mal flattern, mal gleiten
		(node.get_node("WingL") as Node3D).rotation.z = 0.3 + flap * 0.5
		(node.get_node("WingR") as Node3D).rotation.z = -0.3 - flap * 0.5
	for i in _boats.size():
		var b := _boats[i]
		b.rotation.z = sin(t * 0.8 + i) * 0.05
		b.position.y = sin(t * 0.6 + i * 2.0) * 0.15


func _start_sea_sound() -> void:
	if not ResourceLoader.exists(SEA_SOUND):
		return
	var stream: AudioStreamOggVorbis = load(SEA_SOUND)
	stream.loop = true
	_sea_player = AudioStreamPlayer.new()
	_sea_player.stream = stream
	_sea_player.volume_db = -4.0
	_sea_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sea_player)
	_sea_player.play()


## Höhe des Geländes an (x, z) – dieselbe Formel wie in shaders/ground.gdshaderinc.
static func ground_height(x: float, z: float) -> float:
	var h := maxf(-maxf(z - SHORE_Z, 0.0) * 0.13, -4.0)
	var d := 1.0 - smoothstep(DUNE_Z - 9.0, DUNE_Z, z)
	var hills := 3.0 + 1.2 * sin(x * 0.11 + 1.3) + 0.8 * sin(x * 0.27 + z * 0.2)
	return h + d * hills


# ================================================================ Himmel, Licht, Meer

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.ssil_intensity = 0.5
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Dunst über dem Meer: weit entfernte Dinge werden blasser
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.84, 0.93)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.0
	env.volumetric_fog_density = 0.0015
	env.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	environment = env

	# Nachmittagssonne von rechts über dem Meer
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.72, -0.52, -0.46), Vector3.UP)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 135.0)
	plane.subdivide_width = 300
	plane.subdivide_depth = 170
	var m := ShaderMaterial.new()
	m.shader = SAND
	m.set_shader_parameter("water_level", WATER_LEVEL)
	plane.material = m
	ground.mesh = plane
	ground.position = Vector3(1.0, 0.0, -27.5)   # z −95 … 40
	# Die Verformung passiert im Shader: Sichtbarkeitsgrenzen großzügig setzen
	ground.custom_aabb = AABB(Vector3(-120, -6, -70), Vector3(240, 14, 140))
	add_child(ground)
	# Begehbarer Boden: flach, vorne schräg ins Wasser
	add_collider(Vector3(EAST_END - WEST_END + 4.0, 1.0, SHORE_Z - BACK_Z + 2.0), Vector3((WEST_END + EAST_END) * 0.5, -0.5, (SHORE_Z + BACK_Z) * 0.5 - 1.0))
	var slope := CollisionShape3D.new()
	var slope_box := BoxShape3D.new()
	slope_box.size = Vector3(EAST_END - WEST_END + 4.0, 1.0, 6.0)
	slope.shape = slope_box
	# Oberkante beginnt bei SHORE_Z auf Höhe 0 und fällt wie das Gelände um 0,13 pro Meter
	var angle := atan(0.13)
	slope.rotation.x = angle
	slope.position = Vector3((WEST_END + EAST_END) * 0.5, -(0.5 * cos(angle) + 3.0 * sin(angle)), SHORE_Z - 0.5 * sin(angle) + 3.0 * cos(angle))
	world_body.add_child(slope)


func _build_sea() -> void:
	var m := ShaderMaterial.new()
	m.shader = WATER
	m.set_shader_parameter("shore_z", SHORE_Z + 1.0)
	# nah: fein unterteilt für die Wellen am Strand; fern: grob bis zum Horizont
	for part: Array in [[Vector2(220, 70), Vector3(1, WATER_LEVEL, 40.0), 330, 105], [Vector2(1400, 700), Vector3(1, WATER_LEVEL, 425.0), 120, 60],
			[Vector2(500, 120), Vector3(-450, WATER_LEVEL, 50.0), 40, 12], [Vector2(500, 120), Vector3(452, WATER_LEVEL, 50.0), 40, 12]]:
		var sea := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = part[0]
		plane.subdivide_width = part[2]
		plane.subdivide_depth = part[3]
		plane.material = m
		sea.mesh = plane
		sea.position = part[1]
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sea)


# ================================================================ Möwenbucht

func _build_main_props() -> void:
	var ex: Array[Rect2] = _excludes["main"]
	# Bohlenweg über die Düne zum Strand
	_build_boardwalk(Vector3(0.0, 0.0, -10.5), -30.0)
	ex.append(Rect2(-0.9, -16.0, 1.8, 5.6))
	# Strandkiosk mit Muschelsammlung
	_build_kiosk(Vector3(-5.5, 0.0, -13.6))
	ex.append(Rect2(-8.6, -15.8, 6.2, 3.6))
	# Rettungsturm
	_build_lifeguard_tower(Vector3(11.0, 0.0, -11.5))
	ex.append(Rect2(9.6, -12.9, 2.8, 2.8))
	# Wertstoffstation
	_build_recycling(Vector3(4.5, 0.0, -14.4))
	ex.append(Rect2(2.6, -15.4, 4.0, 1.8))
	# Strandkörbe in zwei lockeren Reihen
	var colors := [Color(0.12, 0.33, 0.7), Color(0.8, 0.15, 0.15), Color(0.1, 0.55, 0.45), Color(0.95, 0.65, 0.1), Color(0.12, 0.33, 0.7), Color(0.8, 0.15, 0.15)]
	var i := 0
	for x: float in [-17.5, -15.0, -12.5, -10.0, 14.0, 16.5, 19.0]:
		var z := -12.6 + (0.5 if i % 2 else 0.0)
		_build_strandkorb(Vector3(x, 0.0, z), _rng.randf_range(-0.3, 0.3), colors[i % colors.size()])   # offene Seite zum Meer
		ex.append(Rect2(x - 0.8, z - 0.7, 1.6, 1.4))
		i += 1
	# Sonnenschirme mit Handtüchern
	for spot: Array in [[Vector3(-14.0, 0, -8.5), Color(0.95, 0.4, 0.1)], [Vector3(16.0, 0, -8.0), Color(0.2, 0.55, 0.85)], [Vector3(6.0, 0, -9.5), Color(0.9, 0.2, 0.35)]]:
		_build_umbrella(spot[0], spot[1])
	# Sandburg
	_build_sandcastle(Vector3(-7.5, 0.0, -6.5))
	ex.append(Rect2(-8.4, -7.4, 1.8, 1.8))
	# Treibholz
	for spot: Vector3 in [Vector3(-3.0, 0, 6.8), Vector3(9.0, 0, 7.3), Vector3(-18.0, 0, 6.2), Vector3(17.0, 0, 2.0)]:
		_build_driftwood(spot, _rng.randf() * TAU, _rng.randf_range(1.4, 2.6))
	# Buhnen: Reihen von Holzpfählen bis ins Meer
	for x: float in [-14.5, 14.5]:
		_build_groyne(x, 4.5, 24.0)
		ex.append(Rect2(x - 0.35, 4.3, 0.7, 6.0))


func _build_boardwalk(foot: Vector3, length: float) -> void:
	var wood := _wood("plank", Color(0.66, 0.55, 0.42), Color(0.4, 0.31, 0.23))
	var steps := int(absf(length) / 0.35)
	for k in steps:
		var z := foot.z - k * 0.35
		var y := maxf(ground_height(foot.x, z), 0.0) + 0.07
		var plank := box(Vector3(1.6, 0.05, 0.3), Vector3(foot.x, y, z), wood, false)
		plank.rotation.y = _rng.randf_range(-0.02, 0.02)
	for side: float in [-0.75, 0.75]:
		for k in int(absf(length) / 2.0):
			var z := foot.z - k * 2.0
			var y := maxf(ground_height(foot.x + side, z), 0.0)
			box(Vector3(0.1, 0.9, 0.1), Vector3(foot.x + side, y + 0.35, z), _wood("post", Color(0.5, 0.42, 0.33), Color(0.3, 0.24, 0.18)), false)
	add_collider(Vector3(1.6, 0.14, 5.6), Vector3(foot.x, 0.0, foot.z - 2.8))


func _build_kiosk(base: Vector3) -> void:
	var walls := _wood("kiosk_wall", Color(0.95, 0.93, 0.88), Color(0.82, 0.78, 0.7), 0.0, 0.12)
	var trim := _wood("kiosk_trim", Color(0.18, 0.45, 0.62), Color(0.1, 0.3, 0.42))
	var roof := _std("kiosk_roof", Color(0.22, 0.32, 0.38), 0.6)
	var w := 5.0
	var d := 3.0
	var h := 2.6
	box(Vector3(w, h, 0.12), base + Vector3(0, h * 0.5, -d * 0.5), walls)
	box(Vector3(0.12, h, d), base + Vector3(-w * 0.5, h * 0.5, 0), walls)
	box(Vector3(0.12, h, d), base + Vector3(w * 0.5, h * 0.5, 0), walls)
	# Vorderseite: Tresen links, Muschelwand rechts
	box(Vector3(2.2, 1.05, 0.12), base + Vector3(-1.4, 0.52, d * 0.5), walls)
	box(Vector3(2.4, 0.08, 0.5), base + Vector3(-1.4, 1.08, d * 0.5 + 0.12), trim, false)
	box(Vector3(w, 0.5, 0.12), base + Vector3(0, h - 0.25, d * 0.5), walls, false)
	box(Vector3(2.6, h - 0.5, 0.12), base + Vector3(1.2, (h - 0.5) * 0.5, d * 0.5), walls)
	box(Vector3(w + 0.8, 0.12, d + 1.0), base + Vector3(0, h + 0.06, 0.2), roof, false)
	for x: float in [-w * 0.5, w * 0.5]:
		box(Vector3(0.14, h, 0.14), base + Vector3(x, h * 0.5, d * 0.5 + 0.02), trim, false)
	# Markise mit Streifen
	var awning := box(Vector3(2.6, 0.04, 1.2), base + Vector3(-1.4, h - 0.45, d * 0.5 + 0.55), _stripes("awning", Color(0.98, 0.97, 0.93), Color(0.15, 0.55, 0.75), 3.0), false)
	awning.rotation.x = -0.35
	# Schild auf dem Dach
	box(Vector3(3.2, 0.6, 0.08), base + Vector3(0, h + 0.42, d * 0.5 - 0.1), _std("sign_board", Color(0.97, 0.96, 0.92), 0.6), false)
	var sign := Label3D.new()
	sign.text = "STRANDKIOSK"
	sign.font = load("res://game/beach/fonts/title.tres")
	sign.font_size = 96
	sign.pixel_size = 0.0048
	sign.modulate = Color(0.1, 0.38, 0.55)
	sign.outline_size = 0
	sign.position = base + Vector3(0, h + 0.42, d * 0.5 - 0.05)
	add_child(sign)
	# Muschelwand: Holzbrett mit Fächern, dahin fliegen die gesammelten Muscheln
	var board_center := base + Vector3(1.2, 1.35, d * 0.5 + 0.1)
	box(Vector3(2.3, 1.6, 0.06), board_center, _wood("shell_board", Color(0.55, 0.38, 0.24), Color(0.36, 0.24, 0.15)), false)
	var label := Label3D.new()
	label.text = "Muschelsammlung"
	label.font = load("res://game/beach/fonts/title.tres")
	label.font_size = 64
	label.pixel_size = 0.0045
	label.modulate = Color(1.0, 0.95, 0.85)
	label.outline_size = 10
	label.outline_modulate = Color(0.2, 0.12, 0.08)
	label.position = board_center + Vector3(0, 0.66, 0.05)
	add_child(label)
	var shelf_mat := _wood("shell_shelf", Color(0.75, 0.6, 0.42), Color(0.5, 0.38, 0.26))
	for row in 4:
		var y := board_center.y + 0.42 - row * 0.32
		box(Vector3(2.15, 0.03, 0.12), Vector3(board_center.x, y - 0.06, board_center.z + 0.08), shelf_mat, false)
		for col in 11:
			var x := board_center.x - 0.95 + col * 0.19
			var t := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(x, y - 0.045, board_center.z + 0.1))
			_shell_slots.append(t)


func _build_lifeguard_tower(base: Vector3) -> void:
	var post := _wood("tower_post", Color(0.92, 0.9, 0.85), Color(0.75, 0.72, 0.66), 0.0)
	for dx: float in [-0.9, 0.9]:
		for dz: float in [-0.9, 0.9]:
			box(Vector3(0.14, 2.4, 0.14), base + Vector3(dx, 1.2, dz), post)
	for dz: float in [-0.9, 0.9]:
		var brace := box(Vector3(0.06, 2.5, 0.08), base + Vector3(0, 1.1, dz), post, false)
		brace.rotation.z = 0.65
	box(Vector3(2.3, 0.12, 2.3), base + Vector3(0, 2.45, 0), _wood("tower_floor", Color(0.62, 0.5, 0.38), Color(0.4, 0.31, 0.23), 0.0, 0.15), false)
	var cabin := _stripes("tower_cabin", Color(0.95, 0.95, 0.93), Color(0.85, 0.12, 0.1), 2.6)
	box(Vector3(1.8, 1.3, 0.08), base + Vector3(0, 3.15, -0.85), cabin, false)
	box(Vector3(0.08, 1.3, 1.8), base + Vector3(-0.88, 3.15, 0), cabin, false)
	box(Vector3(0.08, 1.3, 1.8), base + Vector3(0.88, 3.15, 0), cabin, false)
	box(Vector3(1.8, 0.5, 0.08), base + Vector3(0, 2.75, 0.88), cabin, false)
	var roof := box(Vector3(2.4, 0.08, 2.5), base + Vector3(0, 3.9, 0.05), _std("tower_roof", Color(0.85, 0.15, 0.12), 0.5), false)
	roof.rotation.x = 0.12
	# Leiter
	for k in 8:
		box(Vector3(0.6, 0.04, 0.06), base + Vector3(0, 0.25 + k * 0.29, 1.35 + k * 0.08), post, false)
	# Fahne
	box(Vector3(0.04, 1.6, 0.04), base + Vector3(0.95, 4.6, -0.95), _std("metal", Color(0.75, 0.76, 0.78), 0.3, 0.8), false)
	var flag := box(Vector3(0.6, 0.38, 0.02), base + Vector3(1.27, 5.15, -0.95), _std("flag", Color(0.95, 0.85, 0.1), 0.7), false)
	flag.set_meta("flag", true)
	var cross := box(Vector3(0.36, 0.08, 0.025), base + Vector3(0, 3.35, 0.93), _std("red_cross", Color(0.85, 0.1, 0.1), 0.6), false)
	box(Vector3(0.08, 0.36, 0.025), cross.position, _std("red_cross", Color(0.85, 0.1, 0.1), 0.6), false)


func _build_recycling(base: Vector3) -> void:
	for i in 3:
		var color: Color = [Color(0.95, 0.78, 0.1), Color(0.15, 0.4, 0.8), Color(0.2, 0.55, 0.3)][i]
		var p := base + Vector3((i - 1) * 1.2, 0, 0)
		box(Vector3(1.0, 1.1, 0.9), p + Vector3(0, 0.55, 0), _std("bin_%d" % i, color, 0.5))
		var lid := box(Vector3(1.04, 0.07, 0.94), p + Vector3(0, 1.13, -0.05), _std("bin_lid_%d" % i, color.darkened(0.3), 0.5), false)
		lid.rotation.x = -0.08
		box(Vector3(0.4, 0.4, 0.02), p + Vector3(0, 0.65, 0.46), _std("bin_label", Color(0.96, 0.96, 0.94), 0.6), false)


func _build_strandkorb(base: Vector3, yaw: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	add_child(root)
	var wicker := ShaderMaterial.new()
	wicker.shader = STRIPES
	wicker.set_shader_parameter("color_a", Color(0.85, 0.72, 0.5))
	wicker.set_shader_parameter("weave", 9.0)
	var canvas := _stripes("korb_%s" % color.to_html(), Color(0.97, 0.96, 0.92), color, 7.0)
	var wood := _wood("korb_wood", Color(0.75, 0.6, 0.42), Color(0.5, 0.38, 0.26))
	_mesh(root, _box_mesh(Vector3(1.3, 0.45, 0.8), wicker), Vector3(0, 0.225, 0.05))           # Unterteil
	_mesh(root, _box_mesh(Vector3(1.2, 0.08, 0.6), canvas), Vector3(0, 0.49, 0.1))            # Sitzpolster
	_mesh(root, _box_mesh(Vector3(1.3, 1.1, 0.12), wicker), Vector3(0, 1.0, -0.38))           # Rücken
	for x: float in [-0.62, 0.62]:
		_mesh(root, _box_mesh(Vector3(0.08, 1.15, 0.75), wicker), Vector3(x, 0.98, 0.0))     # Seiten
		_mesh(root, _box_mesh(Vector3(0.1, 0.06, 0.6), wood), Vector3(x, 0.75, 0.15))         # Armlehnen
	var hood := _mesh(root, _box_mesh(Vector3(1.32, 0.08, 0.9), wicker), Vector3(0, 1.6, 0.0))
	hood.rotation.x = 0.25
	_mesh(root, _box_mesh(Vector3(1.16, 0.95, 0.03), canvas), Vector3(0, 1.0, -0.31))         # Stoff innen
	var inner_roof := _mesh(root, _box_mesh(Vector3(1.16, 0.03, 0.75), canvas), Vector3(0, 1.53, 0.02))
	inner_roof.rotation.x = 0.25
	_mesh(root, _box_mesh(Vector3(1.4, 0.05, 0.85), wood), Vector3(0, 0.02, 0.05))            # Kufen
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.35, 1.7, 0.9)
	col.shape = shape
	col.position = base + Vector3(0, 0.85, 0)
	col.rotation.y = yaw
	world_body.add_child(col)


func _build_umbrella(base: Vector3, color: Color) -> void:
	var tilt := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
	var root := Node3D.new()
	root.position = base
	root.rotation = tilt
	add_child(root)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.025
	pole.height = 2.3
	pole.material = _std("umbrella_pole", Color(0.92, 0.92, 0.9), 0.4)
	_mesh(root, pole, Vector3(0, 1.15, 0))
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.03
	canopy.bottom_radius = 1.25
	canopy.height = 0.45
	canopy.radial_segments = 16
	canopy.cap_bottom = false
	var stripes := _stripes("umbrella_%s" % color.to_html(), Color(0.98, 0.97, 0.94), color, 8.0)
	stripes.set_shader_parameter("radial", true)
	canopy.material = stripes
	_mesh(root, canopy, Vector3(0, 2.15, 0))
	# Handtuch
	var towel := box(Vector3(0.9, 0.02, 1.8), base + Vector3(0.6, 0.01, 0.3), _stripes("towel_%s" % color.to_html(), color.lightened(0.3), color, 3.0), false)
	towel.rotation.y = _rng.randf_range(-0.4, 0.4)
	(_excludes["main"] as Array[Rect2]).append(Rect2(base.x - 0.3, base.z - 0.7, 1.8, 2.0))
	add_collider(Vector3(0.1, 2.2, 0.1), base + Vector3(0, 1.1, 0))


func _build_sandcastle(base: Vector3) -> void:
	var sand := _std("castle_sand", Color(0.85, 0.72, 0.52), 1.0)
	var tower := CylinderMesh.new()
	tower.top_radius = 0.22
	tower.bottom_radius = 0.3
	tower.height = 0.45
	tower.material = sand
	var root := Node3D.new()
	root.position = base
	add_child(root)
	_mesh(root, _box_mesh(Vector3(1.1, 0.3, 1.1), sand), Vector3(0, 0.15, 0))
	for c: Vector2 in [Vector2(-0.55, -0.55), Vector2(0.55, -0.55), Vector2(-0.55, 0.55), Vector2(0.55, 0.55)]:
		_mesh(root, tower, Vector3(c.x, 0.22, c.y))
	var keep := CylinderMesh.new()
	keep.top_radius = 0.18
	keep.bottom_radius = 0.28
	keep.height = 0.7
	keep.material = sand
	_mesh(root, keep, Vector3(0, 0.6, 0))
	var flag := _mesh(root, _box_mesh(Vector3(0.18, 0.12, 0.01), _std("flag_red", Color(0.9, 0.15, 0.15), 0.7)), Vector3(0.09, 1.25, 0))
	flag.name = "Flag"
	_mesh(root, _box_mesh(Vector3(0.015, 0.4, 0.015), _std("stick", Color(0.6, 0.5, 0.35), 0.8)), Vector3(0, 1.1, 0))
	add_collider(Vector3(1.4, 0.9, 1.4), base + Vector3(0, 0.45, 0))


func _build_driftwood(base: Vector3, yaw: float, length: float) -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.1
	log_mesh.bottom_radius = 0.14
	log_mesh.height = length
	log_mesh.radial_segments = 10
	log_mesh.material = _wood("driftwood", Color(0.7, 0.6, 0.48), Color(0.45, 0.37, 0.29))
	var log := MeshInstance3D.new()
	log.mesh = log_mesh
	log.position = base + Vector3(0, 0.09, 0)
	log.rotation = Vector3(0, yaw, PI * 0.5 + _rng.randf_range(-0.05, 0.05))
	add_child(log)
	var branch := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.03
	bm.bottom_radius = 0.06
	bm.height = length * 0.4
	bm.material = log_mesh.material
	branch.mesh = bm
	branch.position = base + Vector3(cos(yaw) * length * 0.2, 0.22, -sin(yaw) * length * 0.2)
	branch.rotation = Vector3(0.6, yaw, 0.4)
	add_child(branch)


func _build_groyne(x: float, z_from: float, z_to: float) -> void:
	var post_mat := _wood("groyne", Color(0.42, 0.35, 0.28), Color(0.22, 0.18, 0.14))
	var z := z_from
	var k := 0
	while z < z_to:
		for dx: float in [-0.14, 0.14]:
			var top := 0.55 + 0.18 * sin(k * 1.7 + dx * 9.0) - (z - z_from) * 0.015
			var bottom := ground_height(x, z) - 0.3
			var post := CylinderMesh.new()
			post.top_radius = 0.11
			post.bottom_radius = 0.13
			post.height = top - bottom
			post.radial_segments = 10
			post.material = post_mat
			var m := MeshInstance3D.new()
			m.mesh = post
			m.position = Vector3(x + dx + _rng.randf_range(-0.03, 0.03), (top + bottom) * 0.5, z)
			m.rotation = Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.05, 0.05))
			add_child(m)
		z += 0.28
		k += 1
	add_collider(Vector3(0.6, 2.0, FRONT_Z - z_from + 0.5), Vector3(x, 1.0, (z_from + FRONT_Z) * 0.5))


# ================================================================ Felsenbucht

func _build_rocks_zone(zone: CleanZone) -> void:
	var ex: Array[Rect2] = _excludes["rocks"]
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# Große Brocken hinten und an den Seiten, kleinere verstreut; Bahnen der Maschinen bleiben frei
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var x := r.randf_range(WEST_END + 1.0, -DIVIDER_X - 2.5)
		var z := r.randf_range(BACK_Z + 0.5, 9.0)
		if absf(z - BELT_Z) < 1.6 or (z > -7.0 and z < 7.0 and absf(fmod(z + 7.5, 3.0) - 1.5) > 0.7):
			continue   # Förderband und Bahnen der Siebmaschinen
		var s := r.randf_range(0.5, 1.5) if z > -9.0 else r.randf_range(1.0, 2.2)
		var size := Vector3(s * r.randf_range(1.0, 1.6), s * r.randf_range(0.6, 1.0), s * r.randf_range(0.9, 1.4))
		_rock(Vector3(x, size.y * 0.15, z), size, r.randf() * TAU, r.randi() % 6, true)
		ex.append(Rect2(x - size.x * 0.8, z - size.z * 0.8, size.x * 1.6, size.z * 1.6))
		if s > 1.1:
			_net_spots.append([zone, Vector3(x + size.x * 0.9, 0.04, z + r.randf_range(-0.4, 0.4))])
		placed += 1
	# Gezeitentümpel
	for spot: Vector3 in [Vector3(-44.0, 0, 6.5), Vector3(-36.5, 0, -10.0)]:
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.3
		disc.bottom_radius = 1.3
		disc.height = 0.02
		var water := _std("pool", Color(0.2, 0.45, 0.5, 0.75), 0.05)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.metallic_specular = 0.9
		disc.material = water
		pool.mesh = disc
		pool.position = spot + Vector3(0, 0.012, 0)
		add_child(pool)
		ex.append(Rect2(spot.x - 1.4, spot.z - 1.4, 2.8, 2.8))
		for k in 7:
			var a := TAU * k / 7.0
			_rock(spot + Vector3(cos(a) * 1.45, 0.05, sin(a) * 1.45), Vector3.ONE * r.randf_range(0.25, 0.45), r.randf() * TAU, r.randi() % 6, false)
	for spot: Vector3 in [Vector3(-40.0, 0, 3.0), Vector3(-27.0, 0, -12.0)]:
		_build_driftwood(spot, r.randf() * TAU, r.randf_range(1.8, 3.0))
	# Leuchtturm auf der Landzunge
	_build_lighthouse(Vector3(-60.0, 0.0, 9.0))
	for k in 18:
		var a := r.randf() * TAU
		var d := r.randf_range(3.0, 9.0)
		var s := r.randf_range(1.5, 3.5)
		_rock(Vector3(-60.0 + cos(a) * d, -0.3, 9.0 + sin(a) * d), Vector3(s, s * 0.7, s), r.randf() * TAU, r.randi() % 6, false)


func _build_lighthouse(base: Vector3) -> void:
	var tower := CylinderMesh.new()
	tower.top_radius = 1.0
	tower.bottom_radius = 1.6
	tower.height = 14.0
	var stripes := _stripes("lighthouse", Color(0.97, 0.96, 0.94), Color(0.82, 0.12, 0.1), 0.25)
	tower.material = stripes
	var m := MeshInstance3D.new()
	m.mesh = tower
	m.position = base + Vector3(0, 7.0, 0)
	add_child(m)
	var gallery := CylinderMesh.new()
	gallery.top_radius = 1.5
	gallery.bottom_radius = 1.5
	gallery.height = 0.2
	gallery.material = _std("lh_dark", Color(0.15, 0.17, 0.18), 0.5)
	var g := MeshInstance3D.new()
	g.mesh = gallery
	g.position = base + Vector3(0, 14.1, 0)
	add_child(g)
	var lamp := CylinderMesh.new()
	lamp.top_radius = 0.75
	lamp.bottom_radius = 0.75
	lamp.height = 1.4
	var glow := _std("lh_lamp", Color(1.0, 0.95, 0.7), 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.9, 0.6)
	glow.emission_energy_multiplier = 1.5
	lamp.material = glow
	var l := MeshInstance3D.new()
	l.mesh = lamp
	l.position = base + Vector3(0, 14.9, 0)
	add_child(l)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.1
	cap.bottom_radius = 1.0
	cap.height = 0.9
	cap.material = _std("lh_cap", Color(0.82, 0.12, 0.1), 0.4)
	var c := MeshInstance3D.new()
	c.mesh = cap
	c.position = base + Vector3(0, 16.05, 0)
	add_child(c)


# ================================================================ Wrackküste

func _build_wreck_zone(zone: CleanZone) -> void:
	var ex: Array[Rect2] = _excludes["wreck"]
	var r := RandomNumberGenerator.new()
	r.seed = 91
	var center := Vector3(38.0, 0.0, -11.0)
	var yaw := 0.35
	var root := Node3D.new()
	root.position = center
	root.rotation = Vector3(0, yaw, 0.12)   # liegt leicht schräg im Sand
	add_child(root)
	var hull := _wood("hull", Color(0.42, 0.32, 0.24), Color(0.2, 0.15, 0.11))
	var hull_light := _wood("hull_light", Color(0.55, 0.45, 0.35), Color(0.3, 0.23, 0.17), 0.0, 0.0, true)
	var length := 12.0
	# Kiel
	_mesh(root, _box_mesh(Vector3(length, 0.35, 0.4), hull), Vector3(0, -0.1, 0))
	# Spanten: Bögen aus Teilstücken, einige gebrochen
	var ribs := 11
	for i in ribs:
		var x := -length * 0.5 + 0.6 + i * (length - 1.2) / (ribs - 1)
		var taper := 1.0 - pow(absf(x) / (length * 0.55), 2.0)
		var half_w := 1.1 + 1.3 * taper
		var height := 1.6 + 1.6 * taper
		for side: float in [-1.0, 1.0]:
			if (i * 7 + int(side + 1)) % 5 == 0:
				continue   # weggebrochen
			var segs := 5
			var prev := Vector3(x, 0.0, 0.0)
			for s in segs:
				var a := (s + 1.0) / segs * PI * 0.5
				var p := Vector3(x, height * (1.0 - cos(a)) * 0.9, side * half_w * sin(a))
				if s == segs - 1 and i % 3 == 1:
					break
				var mid := (prev + p) * 0.5
				var seg := _mesh(root, _box_mesh(Vector3(0.18, prev.distance_to(p) + 0.05, 0.16), hull), mid)
				seg.basis = CleanPlayer._basis_from_normal((p - prev).normalized())
				prev = p
	# Beplankung entlang der Spanten: links bis weit hoch, rechts nur unten noch erhalten
	for side: float in [-1.0, 1.0]:
		for a: float in ([0.25, 0.5, 0.75, 1.0, 1.25] if side < 0 else [0.25, 0.5]):
			var w := 2.0
			var hh := 2.6
			var p := Vector3(0, hh * (1.0 - cos(a)) * 0.9, side * w * sin(a))
			var tangent := Vector2(hh * sin(a) * 0.9, side * w * cos(a))
			var plank_len := length * (0.86 - a * 0.22) - absf(sin(a * 7.0)) * 1.5
			var plank := _mesh(root, _box_mesh(Vector3(plank_len, 0.34, 0.06), hull_light), p + Vector3(-0.4 + sin(a * 5.0) * 0.8, 0, 0))
			plank.rotation.x = atan2(tangent.y, tangent.x)
	# Mast, schräg
	var mast := CylinderMesh.new()
	mast.top_radius = 0.1
	mast.bottom_radius = 0.16
	mast.height = 7.0
	mast.material = hull
	var mast_node := _mesh(root, mast, Vector3(1.0, 2.5, 0.6))
	mast_node.rotation = Vector3(0.9, 0.0, -0.35)
	# Kollision grob: der Rumpf als Block
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 2.2, 4.4)
	col.shape = shape
	col.position = center + Vector3(0, 1.1, 0)
	col.rotation.y = yaw
	world_body.add_child(col)
	ex.append(Rect2(center.x - 6.5, center.z - 3.5, 13.0, 7.0))
	# Fässer, Kisten, Anker
	for spot: Vector3 in [Vector3(30.5, 0, -12.5), Vector3(45.0, 0, -6.5), Vector3(33.0, 0, -5.8), Vector3(47.5, 0, -13.0)]:
		_build_barrel(spot, r)
		ex.append(Rect2(spot.x - 0.5, spot.z - 0.5, 1.0, 1.0))
	for spot: Vector3 in [Vector3(29.0, 0, -9.0), Vector3(44.0, 0, -14.5), Vector3(48.5, 0, -3.0)]:
		var crate := box(Vector3(0.8, 0.6, 0.6), spot + Vector3(0, 0.25, 0), _wood("crate", Color(0.62, 0.5, 0.36), Color(0.38, 0.29, 0.2), 0.0, 0.15))
		crate.rotation = Vector3(0, r.randf() * TAU, r.randf_range(-0.2, 0.2))
		ex.append(Rect2(spot.x - 0.6, spot.z - 0.6, 1.2, 1.2))
		_net_spots.append([zone, spot + Vector3(0.9, 0.04, 0.3)])
	_build_anchor(Vector3(26.5, 0.0, 4.0))
	for k in 8:
		_net_spots.append([zone, center + Vector3(r.randf_range(-6.5, 6.5), 0.04, r.randf_range(3.2, 4.2) * (1.0 if k % 2 else -1.0)).rotated(Vector3.UP, 0.0)])
	for spot: Vector3 in [Vector3(41.0, 0, 4.5), Vector3(49.0, 0, 6.5)]:
		_build_driftwood(spot, r.randf() * TAU, r.randf_range(2.0, 3.2))
	# Palmen auf der Düne hinter dem Wrack
	for spot: Vector2 in [Vector2(30.0, -19.5), Vector2(36.0, -21.0), Vector2(44.0, -19.0), Vector2(49.0, -22.0)]:
		_build_palm(Vector3(spot.x, ground_height(spot.x, spot.y) - 0.1, spot.y), r)


func _build_barrel(base: Vector3, r: RandomNumberGenerator) -> void:
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.28
	barrel.bottom_radius = 0.28
	barrel.height = 0.8
	barrel.radial_segments = 14
	barrel.material = _wood("barrel", Color(0.52, 0.36, 0.22), Color(0.3, 0.2, 0.12), 0.0, 0.0, false)
	var m := MeshInstance3D.new()
	m.mesh = barrel
	var lying := r.randf() < 0.5
	m.position = base + Vector3(0, 0.27 if lying else 0.4, 0)
	m.rotation = Vector3(PI * 0.5 if lying else 0.0, r.randf() * TAU, 0)
	add_child(m)
	for y: float in [-0.25, 0.25]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.27
		hoop.outer_radius = 0.3
		hoop.material = _std("rust", Color(0.35, 0.2, 0.12), 0.6, 0.5)
		var h := MeshInstance3D.new()
		h.mesh = hoop
		h.position = Vector3(0, y, 0)
		m.add_child(h)
	add_collider(Vector3(0.7, 0.8, 0.7), base + Vector3(0, 0.4, 0))


func _build_anchor(base: Vector3) -> void:
	var iron := _std("anchor", Color(0.25, 0.2, 0.17), 0.7, 0.6)
	var root := Node3D.new()
	root.position = base + Vector3(0, 0.12, 0)
	root.rotation = Vector3(PI * 0.5, 0.6, 0)
	add_child(root)
	_mesh(root, _box_mesh(Vector3(0.12, 1.6, 0.12), iron), Vector3(0, 0.8, 0))
	_mesh(root, _box_mesh(Vector3(0.9, 0.1, 0.1), iron), Vector3(0, 1.45, 0))
	var arc := TorusMesh.new()
	arc.inner_radius = 0.5
	arc.outer_radius = 0.6
	arc.material = iron
	var a := _mesh(root, arc, Vector3(0, 0.45, 0))
	a.rotation.x = PI * 0.5
	(_excludes["wreck"] as Array[Rect2]).append(Rect2(base.x - 1.0, base.z - 1.0, 2.0, 2.0))


# ================================================================ Grenzen

func _build_dividers(rocks: CleanZone, wreck: CleanZone) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for side: float in [-1.0, 1.0]:
		var x := DIVIDER_X * side
		var z := BACK_Z - 2.0
		while z < 16.0:
			if z > GAP_Z.x - 0.4 and z < GAP_Z.y + 0.4:
				z += 0.6
				continue
			var s := r.randf_range(1.0, 1.9) * (1.3 if z < BACK_Z + 2.0 else 1.0)
			var y := ground_height(x, z) - 0.2
			_rock(Vector3(x + r.randf_range(-0.5, 0.5), y + s * 0.2, z), Vector3(s * 1.2, s * r.randf_range(0.8, 1.2), s), r.randf() * TAU, r.randi() % 6, false)
			z += s * 0.9
		# Wand aus Kollision, mit Lücke für den Durchgang
		add_collider(Vector3(1.6, 4.0, GAP_Z.x - BACK_Z), Vector3(x, 2.0, (BACK_Z + GAP_Z.x) * 0.5))
		add_collider(Vector3(1.6, 4.0, FRONT_Z + 1.0 - GAP_Z.y), Vector3(x, 2.0, (GAP_Z.y + FRONT_Z + 1.0) * 0.5))
		for ex_id: String in ["main", "rocks" if side < 0 else "wreck"]:
			(_excludes[ex_id] as Array[Rect2]).append(Rect2(x - 1.4, BACK_Z, 2.8, 30.0))
	# Sperren aus Treibholz im Durchgang, bis man den Abschnitt kauft
	for pair: Array in [[rocks, -DIVIDER_X, "Felsenbucht\nim Laden freischalten"], [wreck, DIVIDER_X, "Wrackküste\nim Laden freischalten"]]:
		var zone: CleanZone = pair[0]
		var x: float = pair[1]
		var mid := (GAP_Z.x + GAP_Z.y) * 0.5
		var wood := _wood("barrier", Color(0.68, 0.6, 0.5), Color(0.42, 0.36, 0.3))
		add_door(zone, Vector3(0.3, 1.3, GAP_Z.y - GAP_Z.x + 0.6), Vector3(x, 0.65, mid), wood, pair[2], Vector3(x - signf(x) * 0.5, 2.1, mid))
		for k in 3:
			var plank := box(Vector3(0.12, 0.22, GAP_Z.y - GAP_Z.x + 0.9), Vector3(x - signf(x) * 0.2, 0.35 + k * 0.42, mid), wood, false)
			plank.rotation.x = (k - 1) * 0.1
			zone.door_nodes.append(plank)
		var sign := box(Vector3(0.05, 0.6, 1.0), Vector3(x - signf(x) * 0.3, 1.55, mid), _std("sign_red", Color(0.85, 0.2, 0.15), 0.6), false)
		zone.door_nodes.append(sign)


func _build_boundaries() -> void:
	add_collider(Vector3(EAST_END - WEST_END, 6.0, 1.0), Vector3((WEST_END + EAST_END) * 0.5, 3.0, BACK_Z - 0.5))
	add_collider(Vector3(EAST_END - WEST_END, 6.0, 1.0), Vector3((WEST_END + EAST_END) * 0.5, 3.0, FRONT_Z + 0.5))
	add_collider(Vector3(1.0, 6.0, FRONT_Z - BACK_Z), Vector3(WEST_END - 0.5, 3.0, (BACK_Z + FRONT_Z) * 0.5))
	add_collider(Vector3(1.0, 6.0, FRONT_Z - BACK_Z), Vector3(EAST_END + 0.5, 3.0, (BACK_Z + FRONT_Z) * 0.5))
	# Felsen an den äußeren Enden
	var r := RandomNumberGenerator.new()
	r.seed = 6
	for x: float in [WEST_END - 1.0, EAST_END + 1.0]:
		var z := BACK_Z - 3.0
		while z < 15.0:
			var s := r.randf_range(1.4, 2.6)
			_rock(Vector3(x + r.randf_range(-0.8, 0.8), ground_height(x, z) + s * 0.1, z), Vector3(s * 1.3, s, s), r.randf() * TAU, r.randi() % 6, false)
			z += s * 1.0


func _build_dune_fence() -> void:
	# Dünenzaun: dünne Holzstäbe mit Draht, zeigt, wo der Strand endet
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var stake := BoxMesh.new()
	stake.size = Vector3(0.04, 1.0, 0.03)
	stake.material = _wood("fence", Color(0.6, 0.5, 0.38), Color(0.38, 0.3, 0.22))
	mm.mesh = stake
	var xs: Array[float] = []
	var x := WEST_END
	while x < EAST_END:
		if absf(x) > 1.0:   # Lücke für den Bohlenweg
			xs.append(x)
		x += 0.12
	mm.instance_count = xs.size()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in xs.size():
		var h := r.randf_range(0.75, 1.1)
		var b := Basis(Vector3.UP, r.randf() * 0.3).rotated(Vector3.RIGHT, r.randf_range(-0.05, 0.05)).scaled(Vector3(1, h, 1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(xs[i], h * 0.5 - 0.05, BACK_Z - 0.15 + r.randf_range(-0.04, 0.04))))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	add_child(node)
	for y: float in [0.35, 0.7]:
		box(Vector3(EAST_END - WEST_END, 0.01, 0.01), Vector3((WEST_END + EAST_END) * 0.5, y, BACK_Z - 0.13), _std("wire", Color(0.4, 0.4, 0.4), 0.5, 0.7), false)


# ================================================================ Pflanzen, Ferne, Vögel

func _build_vegetation() -> void:
	# Strandhafer auf den Dünen
	var grass := _make_grass_tuft()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = grass
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.08
	var list: Array[Transform3D] = []
	var tries := 0
	while list.size() < 3200 and tries < 30000:
		tries += 1
		var x := r.randf_range(-75.0, 80.0)
		var z := r.randf_range(-48.0, BACK_Z - 0.6)
		if noise.get_noise_2d(x, z) < -0.15 and z < BACK_Z - 3.0:
			continue
		var s := r.randf_range(0.7, 1.4)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.2), s))
		list.append(Transform3D(b, Vector3(x, ground_height(x, z) - 0.05, z)))
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	# Ein paar Palmen auf der Düne
	for spot: Vector2 in [Vector2(-9.0, -21.0), Vector2(-3.5, -24.5), Vector2(8.0, -20.5), Vector2(15.0, -23.0), Vector2(-19.0, -23.0)]:
		_build_palm(Vector3(spot.x, ground_height(spot.x, spot.y) - 0.1, spot.y), r)


func _make_grass_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 8
	for i in 9:
		var a := r.randf() * TAU
		var lean := r.randf_range(0.1, 0.45)
		var h := r.randf_range(0.45, 0.8)
		var w := 0.025
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP)
		var base := dir * r.randf_range(0.0, 0.08)
		var tip := base + dir * lean * h + Vector3.UP * h
		var n := (side.cross(tip - base)).normalized()
		for v: Array in [[base - side * w, Vector2(0, 1)], [base + side * w, Vector2(1, 1)], [tip, Vector2(0.5, 0)]]:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("base_color", Color(0.38, 0.5, 0.22))
	m.set_shader_parameter("tip_color", Color(0.8, 0.76, 0.48))
	m.set_shader_parameter("sway", 0.08)
	mesh.surface_set_material(0, m)
	return mesh


func _build_palm(base: Vector3, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = r.randf() * TAU
	add_child(root)
	var trunk_mat := _wood("palm", Color(0.55, 0.45, 0.33), Color(0.36, 0.28, 0.2))
	var height := r.randf_range(5.5, 7.5)
	var segs := 12
	var bend := r.randf_range(0.6, 1.4)
	var prev := Vector3.ZERO
	for i in segs:
		var k := (i + 1.0) / segs
		var p := Vector3(bend * k * k, height * k, 0)
		var seg := CylinderMesh.new()
		seg.top_radius = 0.16 - 0.05 * k
		seg.bottom_radius = 0.2 - 0.05 * k
		seg.height = prev.distance_to(p) + 0.04
		seg.radial_segments = 10
		seg.material = trunk_mat
		var m := _mesh(root, seg, (prev + p) * 0.5)
		m.basis = CleanPlayer._basis_from_normal((p - prev).normalized())
		prev = p
	var frond_mat := ShaderMaterial.new()
	frond_mat.shader = FOLIAGE
	frond_mat.set_shader_parameter("frond", true)
	frond_mat.set_shader_parameter("base_color", Color(0.2, 0.42, 0.14))
	frond_mat.set_shader_parameter("tip_color", Color(0.45, 0.6, 0.2))
	frond_mat.set_shader_parameter("sway", 0.25)
	var frond := _make_frond_mesh(frond_mat)
	for i in 9:
		var f := MeshInstance3D.new()
		f.mesh = frond
		f.position = prev
		f.rotation = Vector3(0, TAU * i / 9.0 + r.randf_range(-0.2, 0.2), r.randf_range(-0.25, 0.15))
		root.add_child(f)
	for i in 4:
		var nut := SphereMesh.new()
		nut.radius = 0.11
		nut.height = 0.22
		nut.material = _std("coconut", Color(0.3, 0.22, 0.12), 0.7)
		_mesh(root, nut, prev + Vector3(cos(i * 1.6) * 0.18, -0.2, sin(i * 1.6) * 0.18))


## Palmwedel: gebogener Streifen, die Fiedern schneidet der Shader aus.
func _make_frond_mesh(material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var length := 2.8
	var width := 0.9
	for i in segs:
		var k0 := float(i) / segs
		var k1 := float(i + 1) / segs
		var p0 := Vector3(k0 * length, sin(k0 * 2.2) * 0.6 - k0 * k0 * 1.4, 0)
		var p1 := Vector3(k1 * length, sin(k1 * 2.2) * 0.6 - k1 * k1 * 1.4, 0)
		var w0 := width * 0.5 * (1.0 - k0 * 0.6)
		var w1 := width * 0.5 * (1.0 - k1 * 0.6)
		var droop0 := Vector3(0, -0.15 * w0, 0)
		var droop1 := Vector3(0, -0.15 * w1, 0)
		var a := p0 + Vector3(0, 0, -w0) + droop0
		var b := p0 + Vector3(0, 0, w0) + droop0
		var c := p1 + Vector3(0, 0, -w1) + droop1
		var d := p1 + Vector3(0, 0, w1) + droop1
		var n := (b - a).cross(c - a).normalized()
		for v: Array in [[a, Vector2(k0, 0)], [b, Vector2(k0, 1)], [c, Vector2(k1, 0)], [b, Vector2(k0, 1)], [d, Vector2(k1, 1)], [c, Vector2(k1, 0)]]:
			st.set_normal(-n if n.y < 0 else n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _build_far_scenery() -> void:
	# Segelboote am Horizont
	for spot: Array in [[Vector3(35.0, 0, 120.0), 0.4], [Vector3(-55.0, 0, 160.0), -0.6], [Vector3(5.0, 0, 230.0), 1.2]]:
		var boat := Node3D.new()
		var holder := Node3D.new()
		holder.position = spot[0] + Vector3(0, WATER_LEVEL, 0)
		holder.rotation.y = spot[1]
		add_child(holder)
		holder.add_child(boat)
		_mesh(boat, _box_mesh(Vector3(4.0, 0.7, 1.4), _std("boat_hull", Color(0.95, 0.95, 0.93), 0.4)), Vector3(0, 0.2, 0))
		_mesh(boat, _box_mesh(Vector3(0.1, 6.0, 0.1), _std("boat_mast", Color(0.8, 0.8, 0.8), 0.4)), Vector3(0.3, 3.4, 0))
		var sail := PrismMesh.new()
		sail.size = Vector3(3.0, 5.2, 0.04)
		sail.left_to_right = 0.0
		sail.material = _std("sail", Color(1.0, 0.99, 0.96), 0.8)
		_mesh(boat, sail, Vector3(1.85, 3.3, 0))
		_boats.append(boat)


func _build_gulls() -> void:
	var white := _std("gull", Color(0.97, 0.97, 0.96), 0.7)
	var grey := _std("gull_wing", Color(0.62, 0.66, 0.7), 0.7)
	var r := RandomNumberGenerator.new()
	r.seed = 12
	for i in 7:
		var gull := Node3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.06
		body.height = 0.38
		body.material = white
		var b := _mesh(gull, body, Vector3.ZERO)
		b.rotation.x = PI * 0.5
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "WingL" if side < 0 else "WingR"
			gull.add_child(pivot)
			var wing := _mesh(pivot, _box_mesh(Vector3(0.45, 0.012, 0.13), grey), Vector3(side * 0.24, 0, 0.02))
			_mesh(pivot, _box_mesh(Vector3(0.12, 0.014, 0.1), _std("gull_tip", Color(0.15, 0.15, 0.17), 0.7)), Vector3(side * 0.5, 0, 0.03))
			wing.rotation.y = side * 0.1
		add_child(gull)
		var center := Vector3(r.randf_range(-40.0, 40.0), r.randf_range(7.0, 12.0), r.randf_range(-6.0, 22.0))
		_gulls.append({"node": gull, "center": center, "radius": r.randf_range(5.0, 12.0), "speed": r.randf_range(0.12, 0.25) * (1.0 if i % 2 else -1.0), "phase": r.randf() * TAU})


# ================================================================ Maschinen-Plätze

func _plan_machines() -> void:
	for z in [-7.5, -6.0, -4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5]:
		_lanes.append({"from": Vector3(-20.0, 0, z), "to": Vector3(20.0, 0, z), "zone": "main"})
	for z in [-5.5, -2.5, 0.5, 3.5]:
		_lanes.append({"from": Vector3(-47.5, 0, z), "to": Vector3(-25.0, 0, z), "zone": "rocks"})
	for z in [-4.5, -1.5, 1.5, 4.0]:
		_lanes.append({"from": Vector3(25.0, 0, z), "to": Vector3(49.5, 0, z), "zone": "wreck"})
	for seg: Vector2 in [Vector2(-5.0, 5.0), Vector2(-20.0, -10.5), Vector2(9.0, 18.5)]:
		_belts.append({"from": Vector3(seg.x, 0, BELT_Z), "to": Vector3(seg.y, 0, BELT_Z), "zone": "main"})
	_belts.append({"from": Vector3(-46.0, 0, BELT_Z), "to": Vector3(-29.0, 0, BELT_Z), "zone": "rocks"})
	_belts.append({"from": Vector3(26.0, 0, BELT_Z), "to": Vector3(44.0, 0, BELT_Z), "zone": "wreck"})
	for b in _belts:
		var from: Vector3 = b["from"]
		var to: Vector3 = b["to"]
		(_excludes[b["zone"]] as Array[Rect2]).append(Rect2(from.x - 0.3, BELT_Z - 0.4, to.x - from.x + 1.6, 0.8))


func _zone_open(id: String) -> bool:
	for z in zones:
		if z.id == id:
			return z.unlocked
	return false


## Erster freier Platz (Bahn oder Band) in einem offenen Abschnitt; markiert ihn als belegt.
func _take(list: Array[Dictionary]) -> Dictionary:
	for spot in list:
		if not _taken.has(spot) and _zone_open(spot["zone"]):
			_taken[spot] = true
			return spot
	return {}


func _free_count(list: Array[Dictionary]) -> int:
	var n := 0
	for spot in list:
		if _zone_open(spot["zone"]):
			n += 1
	return n


# ================================================================ Müll

func _scatter_litter(zone: CleanZone, rect: Rect2, count: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = hash(zone.id)
	noise.frequency = 0.09
	var r := RandomNumberGenerator.new()
	r.seed = hash(zone.id) + 1
	var ex: Array[Rect2] = _excludes[zone.id]
	var placed := 0
	var tries := count * 8
	while placed < count and tries > 0:
		tries -= 1
		var x := r.randf_range(rect.position.x, rect.end.x)
		var z := r.randf_range(rect.position.y, rect.end.y)
		if _in_any(Vector2(x, z), ex):
			continue
		var c := clampf(noise.get_noise_2d(x, z) * 0.9 + 0.5, 0.0, 1.0)
		# Spülsäume: dort hat die Flut den meisten Müll abgelegt
		var tide := exp(-pow((z - 7.0) / 0.9, 2.0)) + 0.5 * exp(-pow((z - 2.5) / 1.3, 2.0))
		var p := 0.12 + c * c * 1.1 + tide
		if r.randf() * 1.7 > p:
			continue
		var dirt := lerpf(1.0, 3.0, clampf(c + r.randf_range(-0.35, 0.35), 0.0, 1.0))
		zone.mess.add_flake_at(Vector3(x, r.randf_range(0.006, 0.014), z), r.randf_range(0.26, 0.38), dirt)
		placed += 1


## Große Teile als eigene Schicht mit echten 3D-Modellen; Haufen geben einen Bonus, wenn sie ganz weg sind.
func _scatter_items(zone: CleanZone, rect: Rect2, piles: int, singles: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(zone.id) + 2
	var ex: Array[Rect2] = _excludes[zone.id]
	var items: Array[Dictionary] = []
	var centers: Array[Vector3] = []
	var tries := 0
	while centers.size() < piles and tries < 500:
		tries += 1
		var c := Vector3(r.randf_range(rect.position.x + 1.5, rect.end.x - 1.5), 0, r.randf_range(rect.position.y + 1.0, rect.end.y))
		if _in_any(Vector2(c.x, c.z), ex) or centers.any(func(o: Vector3) -> bool: return o.distance_to(c) < 4.0):
			continue
		centers.append(c)
		var group := _group_id
		_group_id += 1
		for k in r.randi_range(5, 9):
			var a := r.randf() * TAU
			var d := sqrt(r.randf()) * 1.2
			var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
			if not _in_any(Vector2(p.x, p.z), ex):
				items.append({"pos": p, "group": group})
	tries = 0
	var single_count := 0
	while single_count < singles and tries < singles * 10:
		tries += 1
		var p := Vector3(r.randf_range(rect.position.x, rect.end.x), 0, r.randf_range(rect.position.y, rect.end.y))
		if _in_any(Vector2(p.x, p.z), ex):
			continue
		items.append({"pos": p, "group": -1})
		single_count += 1
	# Schätze unter den Haufen: sechs in der Möwenbucht, sonst einer
	var wanted := 6 if zone.id == "main" else 1
	for i in mini(wanted, centers.size()):
		_treasure_spots.append(centers[(i * 5 + 2) % centers.size()] + Vector3(0, 0.02, 0))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _item_mesh
	mm.instance_count = items.size()
	var layer := add_mess_layer(zone, "", "", Color.WHITE, 3.0)
	layer.drones_reach = true
	layer.linked = mm
	for i in items.size():
		var p: Vector3 = items[i]["pos"]
		var kind := _pick_item_kind(r)
		var tints: Array = ITEM_TINTS[kind]
		var tint: Color = tints[r.randi() % tints.size()]
		tint.a = kind / 16.0
		var b := Basis(Vector3.UP, r.randf() * TAU).rotated(Vector3.RIGHT, r.randf_range(-0.08, 0.08)).scaled(Vector3.ONE * r.randf_range(0.9, 1.15))
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, -0.01, 0)))
		mm.set_instance_color(i, tint)
		layer.add_linked_flake(p + Vector3(0, 0.05, 0), r.randf_range(3.5, 6.0), i, items[i]["group"])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	add_child(node)


## Häufige Sachen (Flaschen, Dosen, Tüten) öfter, Reifen und Bojen selten.
func _pick_item_kind(r: RandomNumberGenerator) -> int:
	var weights := [5.0, 4.0, 3.0, 2.0, 1.0, 2.0, 2.5, 0.4, 1.5, 1.2]
	var total := 0.0
	for w: float in weights:
		total += w
	var x := r.randf() * total
	for i in weights.size():
		x -= weights[i]
		if x <= 0.0:
			return i
	return 0


## Geisternetze: an den Buhnen, an großen Felsen und rund ums Wrack. Nur mit dem Netzschneider.
var _net_spots: Array = []   # [Zone, Position]

func _build_nets(main_zone: CleanZone, rocks: CleanZone, wreck: CleanZone) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 31
	for x: float in [-14.5, 14.5]:
		for z: float in [5.0, 6.4, 7.8]:
			_net_spots.append([main_zone, Vector3(x + r.randf_range(-1.0, 1.0) + (0.9 if x < 0 else -0.9), 0.04, z)])
	_net_spots.append([main_zone, Vector3(-3.0, 0.04, 7.6)])
	_net_spots.append([main_zone, Vector3(9.0, 0.04, 7.9)])
	var layers := {}
	for pair: Array in [[main_zone, Color(0.15, 0.45, 0.42)], [rocks, Color(0.2, 0.4, 0.55)], [wreck, Color(0.85, 0.42, 0.15)]]:
		var zone: CleanZone = pair[0]
		layers[zone.id] = add_mess_layer(zone, "Geisternetze", "cutter", pair[1], 8.0, NET)
	for spot: Array in _net_spots:
		var zone: CleanZone = spot[0]
		var layer: CleanMessField = layers[zone.id]
		var p: Vector3 = spot[1]
		layer.add_flake_at(p + Vector3(0, r.randf_range(0.0, 0.02), 0), r.randf_range(2.6, 3.6), r.randf_range(2.5, 4.0))


func _scatter_shells(main_zone: CleanZone, rocks: CleanZone, wreck: CleanZone) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 55
	var slot := 0
	for pair: Array in [[main_zone, 24, Rect2(-21.0, -15.0, 42.0, 23.5)], [rocks, 10, Rect2(-49.0, -15.0, 26.0, 23.5)], [wreck, 10, Rect2(23.0, -15.0, 28.0, 23.5)]]:
		var zone: CleanZone = pair[0]
		var rect: Rect2 = pair[2]
		var ex: Array[Rect2] = _excludes[zone.id]
		var n := 0
		var tries := 0
		while n < pair[1] and tries < 400 and slot < _shell_slots.size():
			tries += 1
			var p := Vector3(r.randf_range(rect.position.x, rect.end.x), 0.0, r.randf_range(rect.position.y, rect.end.y))
			if _in_any(Vector2(p.x, p.z), ex):
				continue
			var kind := r.randi() % 3
			var color: Color = [Color(1.0, 0.78, 0.75), Color(0.98, 0.9, 0.78), Color(1.0, 0.65, 0.45), Color(0.85, 0.75, 0.92)][r.randi() % 4]
			var model := _make_shell(kind, color)
			var from := Transform3D(Basis(Vector3.UP, r.randf() * TAU), p)
			add_pickup("shell_%s_%d" % [zone.id, n], zone, model, from, _shell_slots[slot], Vector3(0.14, 0.06, 0.14), 40)
			slot += 1
			n += 1


func _in_any(p: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(p):
			return true
	return false


## Alle Formen des großen Mülls in einem Mesh; UV2.x = Nummer der Form (siehe litter_item.gdshader).
func _build_item_mesh() -> ArrayMesh:
	var parts: Array[Array] = []   # [Mesh, Transform3D, Farbe, Form]
	var lie := Basis(Vector3.BACK, PI * 0.5)   # Zylinder liegen auf der Seite
	# 0 PET-Flasche
	parts.append([_cyl(0.04, 0.04, 0.2), Transform3D(lie, Vector3(0, 0.04, 0)), Color(0.85, 0.93, 0.98), 0])
	parts.append([_cyl(0.015, 0.035, 0.05), Transform3D(lie, Vector3(-0.125, 0.04, 0)), Color(0.85, 0.93, 0.98), 0])
	parts.append([_cyl(0.018, 0.018, 0.022), Transform3D(lie, Vector3(-0.16, 0.04, 0)), Color(0.2, 0.4, 0.9), 0])
	# 1 Dose
	parts.append([_cyl(0.033, 0.033, 0.12), Transform3D(lie, Vector3(0, 0.033, 0)), Color(1, 1, 1), 1])
	parts.append([_cyl(0.03, 0.03, 0.125), Transform3D(lie, Vector3(0, 0.033, 0)), Color(0.85, 0.85, 0.88), 1])
	# 2 Tüte
	parts.append([_sphere(0.15, 0.1), Transform3D(Basis().scaled(Vector3(1.0, 0.35, 0.75)), Vector3(0, 0.025, 0)), Color(1, 1, 1), 2])
	parts.append([_sphere(0.07, 0.07), Transform3D(Basis().scaled(Vector3(1.0, 0.5, 0.8)), Vector3(0.12, 0.03, 0.05)), Color(0.95, 0.95, 0.95), 2])
	# 3 Flipflop
	parts.append([_box_mesh(Vector3(0.27, 0.022, 0.1), null), Transform3D(Basis(), Vector3(0, 0.011, 0)), Color(1, 1, 1), 3])
	parts.append([_box_mesh(Vector3(0.012, 0.035, 0.09), null), Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.03, 0.035, 0.02)), Color(0.15, 0.15, 0.18), 3])
	parts.append([_box_mesh(Vector3(0.012, 0.035, 0.09), null), Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.03, 0.035, -0.02)), Color(0.15, 0.15, 0.18), 3])
	# 4 Boje
	parts.append([_sphere(0.12, 0.24), Transform3D(Basis(), Vector3(0, 0.11, 0)), Color(1, 1, 1), 4])
	parts.append([_cyl(0.025, 0.025, 0.06), Transform3D(Basis(), Vector3(0, 0.24, 0)), Color(0.3, 0.3, 0.32), 4])
	var band := TorusMesh.new()
	band.inner_radius = 0.115
	band.outer_radius = 0.13
	parts.append([band, Transform3D(Basis(), Vector3(0, 0.11, 0)), Color(0.98, 0.98, 0.98), 4])
	# 5 Kistenteil
	parts.append([_box_mesh(Vector3(0.3, 0.1, 0.22), null), Transform3D(Basis(Vector3.BACK, 0.15), Vector3(0, 0.06, 0)), Color(1, 1, 1), 5])
	# 6 Glasflasche
	parts.append([_cyl(0.035, 0.035, 0.18), Transform3D(lie, Vector3(0, 0.035, 0)), Color(1, 1, 1), 6])
	parts.append([_cyl(0.014, 0.03, 0.08), Transform3D(lie, Vector3(-0.13, 0.035, 0)), Color(1, 1, 1), 6])
	# 7 Reifen
	var tire := TorusMesh.new()
	tire.inner_radius = 0.12
	tire.outer_radius = 0.24
	tire.rings = 18
	tire.ring_segments = 8
	parts.append([tire, Transform3D(Basis(), Vector3(0, 0.06, 0)), Color(0.05, 0.05, 0.055), 7])
	# 8 Seilknäuel
	var rope := TorusMesh.new()
	rope.inner_radius = 0.05
	rope.outer_radius = 0.09
	parts.append([rope, Transform3D(Basis(), Vector3(0, 0.02, 0)), Color(1, 1, 1), 8])
	parts.append([rope, Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(0.03, 0.06, 0)), Color(0.9, 0.9, 0.9), 8])
	# 9 Sandeimer
	parts.append([_cyl(0.09, 0.07, 0.15), Transform3D(Basis(Vector3.BACK, 1.3), Vector3(0, 0.08, 0)), Color(1, 1, 1), 9])

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var mesh: PrimitiveMesh = part[0]
		var xf: Transform3D = part[1]
		var arrays := mesh.get_mesh_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var offset := verts.size()
		for i in v.size():
			verts.append(xf * v[i])
			normals.append((xf.basis * n[i]).normalized())
			uvs.append(uv[i])
			uv2s.append(Vector2(part[3], 0))
			colors.append(part[2])
		for i in idx:
			indices.append(offset + i)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = LITTER_ITEM
	result.surface_set_material(0, m)
	return result


# ================================================================ Muscheln und Schätze

func _make_shell(kind: int, color: Color) -> Node3D:
	var root := Node3D.new()
	var shell := ShaderMaterial.new()
	shell.shader = STRIPES
	shell.set_shader_parameter("color_a", color)
	shell.set_shader_parameter("color_b", color.darkened(0.18))
	shell.set_shader_parameter("count", 14.0)
	shell.set_shader_parameter("radial", true)
	shell.set_shader_parameter("roughness", 0.35)
	match kind:
		0:   # Jakobsmuschel: flacher Fächer
			var s := _sphere(0.06, 0.06)
			s.material = shell
			var m := _mesh(root, s, Vector3(0, 0.012, 0))
			m.scale = Vector3(1.0, 0.35, 0.9)
			_mesh(root, _box_mesh(Vector3(0.035, 0.012, 0.02), shell), Vector3(0, 0.008, -0.055))
		1:   # Schnecke: gedrehter Kegel
			var cone := _cyl(0.0, 0.035, 0.11)
			cone.material = shell
			var m := _mesh(root, cone, Vector3(0, 0.03, 0))
			m.rotation = Vector3(0, 0, PI * 0.5 + 0.15)
			var bulb := _sphere(0.036, 0.07)
			bulb.material = shell
			_mesh(root, bulb, Vector3(-0.045, 0.03, 0))
		_:   # Herzmuschel: halbe Kugel
			var s := _sphere(0.045, 0.09)
			s.material = shell
			var m := _mesh(root, s, Vector3(0, 0.0, 0))
			m.scale = Vector3(1.0, 0.6, 0.85)
	return root


func _make_treasure(id: String) -> Node3D:
	var root := Node3D.new()
	var gold := _std("gold", Color(1.0, 0.78, 0.3), 0.25, 1.0)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.25)
	gold.emission_energy_multiplier = 0.35
	var brass := _std("brass", Color(0.85, 0.65, 0.3), 0.3, 0.9)
	match id:
		"bottle":
			var glass := _std("glass", Color(0.4, 0.75, 0.55, 0.55), 0.05)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var b := _cyl(0.06, 0.06, 0.24)
			b.material = glass
			var m := _mesh(root, b, Vector3(0, 0.06, 0))
			m.rotation.z = PI * 0.5
			var neck := _cyl(0.025, 0.05, 0.08)
			neck.material = glass
			var n := _mesh(root, neck, Vector3(-0.16, 0.06, 0))
			n.rotation.z = PI * 0.5
			var paper := _cyl(0.03, 0.03, 0.16)
			paper.material = _std("paper", Color(0.95, 0.9, 0.75), 0.9)
			var p := _mesh(root, paper, Vector3(0, 0.06, 0))
			p.rotation.z = PI * 0.5
			var cork := _cyl(0.024, 0.024, 0.04)
			cork.material = _std("cork", Color(0.6, 0.42, 0.25), 0.9)
			var c := _mesh(root, cork, Vector3(-0.21, 0.06, 0))
			c.rotation.z = PI * 0.5
		"doubloon":
			var coin := _cyl(0.07, 0.07, 0.015)
			coin.material = gold
			var m := _mesh(root, coin, Vector3(0, 0.07, 0))
			m.rotation.x = PI * 0.5
		"compass":
			var body := _cyl(0.07, 0.07, 0.03)
			body.material = brass
			_mesh(root, body, Vector3(0, 0.015, 0))
			var face := _cyl(0.06, 0.06, 0.005)
			face.material = _std("compass_face", Color(0.95, 0.92, 0.82), 0.6)
			_mesh(root, face, Vector3(0, 0.032, 0))
			_mesh(root, _box_mesh(Vector3(0.09, 0.004, 0.012), _std("needle", Color(0.85, 0.1, 0.1), 0.5)), Vector3(0, 0.037, 0))
		"amber":
			var a := _sphere(0.07, 0.1)
			var amber := _std("amber", Color(1.0, 0.55, 0.1, 0.85), 0.15)
			amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			amber.emission_enabled = true
			amber.emission = Color(1.0, 0.5, 0.1)
			amber.emission_energy_multiplier = 0.6
			a.material = amber
			var m := _mesh(root, a, Vector3(0, 0.05, 0))
			m.scale = Vector3(1.0, 0.7, 0.8)
		"blueprint":
			var roll := _cyl(0.035, 0.035, 0.3)
			roll.material = _std("blueprint", Color(0.2, 0.4, 0.85), 0.8)
			var m := _mesh(root, roll, Vector3(0, 0.035, 0))
			m.rotation.z = PI * 0.5
			var band := _cyl(0.037, 0.037, 0.03)
			band.material = _std("band", Color(0.95, 0.9, 0.7), 0.8)
			var b := _mesh(root, band, Vector3(0, 0.035, 0))
			b.rotation.z = PI * 0.5
		"spyglass":
			for k in 3:
				var tube := _cyl(0.035 - k * 0.007, 0.035 - k * 0.007, 0.13)
				tube.material = brass
				var m := _mesh(root, tube, Vector3(-0.12 + k * 0.12, 0.035, 0))
				m.rotation.z = PI * 0.5
		"pearl":
			var half := _sphere(0.08, 0.08)
			half.material = _std("pearl_shell", Color(0.85, 0.82, 0.9), 0.3)
			var m := _mesh(root, half, Vector3(0, 0.01, 0))
			m.scale = Vector3(1.0, 0.35, 0.9)
			var pearl := _sphere(0.03, 0.06)
			var black := _std("black_pearl", Color(0.12, 0.12, 0.16), 0.08, 0.3)
			black.emission_enabled = true
			black.emission = Color(0.3, 0.25, 0.5)
			black.emission_energy_multiplier = 0.4
			pearl.material = black
			_mesh(root, pearl, Vector3(0, 0.05, 0))
		_:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.045
			ring.outer_radius = 0.07
			ring.material = gold
			var m := _mesh(root, ring, Vector3(0, 0.07, 0))
			m.rotation.x = PI * 0.5
			var gem := _sphere(0.025, 0.05)
			var red := _std("gem", Color(0.9, 0.1, 0.15), 0.1)
			red.emission_enabled = true
			red.emission = Color(0.9, 0.1, 0.15)
			red.emission_energy_multiplier = 0.8
			gem.material = red
			_mesh(root, gem, Vector3(0, 0.07, 0))
	return root


# ================================================================ Werkzeuge und Maschinen

func _make_grabber() -> Node3D:
	var tool := Node3D.new()
	tool.rotation = Vector3(-1.25, 0.0, -0.2)
	var alu := _std("alu", Color(0.78, 0.8, 0.82), 0.3, 0.8)
	var orange := _std("grip", Color(1.0, 0.5, 0.1), 0.5)
	var pole := _cyl(0.01, 0.012, 0.48)
	pole.material = alu
	_mesh(tool, pole, Vector3(0, 0.2, 0))
	_mesh(tool, _box_mesh(Vector3(0.03, 0.1, 0.05), orange), Vector3(0, -0.06, 0.015))
	var trigger := _mesh(tool, _box_mesh(Vector3(0.018, 0.06, 0.018), orange), Vector3(0, -0.04, 0.05))
	trigger.rotation.x = 0.3
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.43
	head.scale = Vector3(1.0, 1.5, 1.0)
	tool.add_child(head)
	_mesh(head, _box_mesh(Vector3(0.05, 0.02, 0.03), orange), Vector3(0, 0.0, 0))
	for side: float in [-1.0, 1.0]:
		var jaw := _mesh(head, _box_mesh(Vector3(0.014, 0.07, 0.03), alu), Vector3(side * 0.03, 0.035, 0))
		jaw.rotation.z = side * -0.3
		var pad := _mesh(head, _box_mesh(Vector3(0.02, 0.025, 0.036), orange), Vector3(side * 0.012, 0.07, 0))
		pad.rotation.z = side * 0.3
	return tool


func _make_rake() -> Node3D:
	var tool := Node3D.new()
	tool.rotation = Vector3(-1.1, 0.0, -0.2)
	var wood := _wood("rake_wood", Color(0.75, 0.6, 0.42), Color(0.52, 0.4, 0.28))
	var pole := _cyl(0.012, 0.014, 0.8)
	pole.material = wood
	_mesh(tool, pole, Vector3(0, 0.25, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.65
	head.scale = Vector3(1.0, 1.5, 1.0)
	tool.add_child(head)
	var green := _std("rake_head", Color(0.15, 0.6, 0.45), 0.5)
	_mesh(head, _box_mesh(Vector3(0.3, 0.02, 0.03), green), Vector3(0, 0.0, 0))
	for k in 11:
		_mesh(head, _box_mesh(Vector3(0.008, 0.05, 0.008), green), Vector3(-0.14 + k * 0.028, 0.03, 0.01))
	return tool


func _make_vacuum() -> Node3D:
	var tool := Node3D.new()
	tool.rotation = Vector3(-1.35, 0.0, -0.1)
	var teal := _std("vac_body", Color(0.1, 0.6, 0.65), 0.35)
	var steel := _std("alu", Color(0.78, 0.8, 0.82), 0.3, 0.8)
	var body := CapsuleMesh.new()
	body.radius = 0.06
	body.height = 0.22
	body.material = teal
	_mesh(tool, body, Vector3.ZERO)
	_mesh(tool, _box_mesh(Vector3(0.05, 0.08, 0.05), _std("grip", Color(1.0, 0.5, 0.1), 0.5)), Vector3(0, 0.0, 0.07))
	var tube := _cyl(0.018, 0.018, 0.4)
	tube.material = steel
	_mesh(tool, tube, Vector3(0, 0.3, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.51
	tool.add_child(head)
	_mesh(head, _box_mesh(Vector3(0.14, 0.03, 0.05), teal), Vector3.ZERO)
	return tool


func _make_cutter() -> Node3D:
	var tool := Node3D.new()
	tool.rotation = Vector3(-1.0, 0.0, -0.18)
	var pole := _cyl(0.011, 0.013, 0.85)
	pole.material = _std("cutter_pole", Color(0.2, 0.25, 0.3), 0.5)
	_mesh(tool, pole, Vector3(0, 0.25, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.68
	tool.add_child(head)
	var blade := _std("blade", Color(0.85, 0.87, 0.9), 0.2, 1.0)
	var hook := TorusMesh.new()
	hook.inner_radius = 0.04
	hook.outer_radius = 0.052
	hook.material = blade
	var h := _mesh(head, hook, Vector3(0.035, 0.03, 0))
	h.rotation.x = PI * 0.5
	_mesh(head, _box_mesh(Vector3(0.02, 0.05, 0.02), _std("grip", Color(1.0, 0.5, 0.1), 0.5)), Vector3(0, -0.02, 0))
	return tool


func _make_sifter_model() -> Node3D:
	var root := Node3D.new()
	var body := _std("sifter_body", Color(0.98, 0.55, 0.12), 0.45)
	var dark := _std("sifter_dark", Color(0.15, 0.16, 0.18), 0.6)
	var glass := _std("sifter_glass", Color(0.5, 0.7, 0.8, 0.45), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(root, _box_mesh(Vector3(0.9, 0.45, 1.3), body), Vector3(0, 0.55, -0.1))
	_mesh(root, _box_mesh(Vector3(0.8, 0.12, 0.5), dark), Vector3(0, 0.84, -0.5))
	_mesh(root, _box_mesh(Vector3(0.75, 0.6, 0.65), glass), Vector3(0, 1.1, 0.15))
	_mesh(root, _box_mesh(Vector3(0.82, 0.06, 0.72), body), Vector3(0, 1.43, 0.15))
	var lamp := _sphere(0.06, 0.12)
	lamp.material = CleanBot.simple_mat(Color(1.0, 0.75, 0.1), true)
	_mesh(root, lamp, Vector3(0, 1.52, 0.15))
	for w: Array in [[Vector3(-0.5, 0.3, -0.5), 0.3], [Vector3(0.5, 0.3, -0.5), 0.3], [Vector3(-0.52, 0.4, 0.35), 0.4], [Vector3(0.52, 0.4, 0.35), 0.4]]:
		var wheel := Node3D.new()
		wheel.name = "Wheel%d" % root.get_child_count()
		wheel.position = w[0]
		root.add_child(wheel)
		var tire := _cyl(w[1], w[1], 0.2)
		tire.material = dark
		var t := _mesh(wheel, tire, Vector3.ZERO)
		t.rotation.z = PI * 0.5
		var hub := _cyl(w[1] * 0.45, w[1] * 0.45, 0.21)
		hub.material = _std("hub", Color(0.95, 0.95, 0.92), 0.4)
		var hb := _mesh(wheel, hub, Vector3.ZERO)
		hb.rotation.z = PI * 0.5
	# Siebtrommel hinten (lokal +z)
	_mesh(root, _box_mesh(Vector3(0.08, 0.08, 0.7), dark), Vector3(-0.45, 0.45, 0.85))
	_mesh(root, _box_mesh(Vector3(0.08, 0.08, 0.7), dark), Vector3(0.45, 0.45, 0.85))
	var drum := Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(0, 0.3, 1.05)
	root.add_child(drum)
	var mesh_mat := _std("sieve", Color(0.7, 0.72, 0.75), 0.4, 0.7)
	var cyl := _cyl(0.28, 0.28, 1.6)
	cyl.material = mesh_mat
	var d := _mesh(drum, cyl, Vector3.ZERO)
	d.rotation.z = PI * 0.5
	for k in 6:
		var bar := _mesh(drum, _box_mesh(Vector3(1.62, 0.04, 0.04), dark), Vector3(0, cos(k * TAU / 6) * 0.29, sin(k * TAU / 6) * 0.29))
		bar.rotation.x = k * TAU / 6
	return root


func _make_drone_model() -> Node3D:
	var root := Node3D.new()
	var white := _std("drone_white", Color(0.95, 0.95, 0.94), 0.35)
	var orange := _std("drone_orange", Color(1.0, 0.5, 0.12), 0.4)
	var dark := _std("drone_dark", Color(0.15, 0.16, 0.18), 0.5)
	var body := _cyl(0.2, 0.24, 0.12)
	body.material = white
	_mesh(root, body, Vector3.ZERO)
	var stripe := _cyl(0.245, 0.245, 0.03)
	stripe.material = orange
	_mesh(root, stripe, Vector3(0, -0.03, 0))
	var eye := _sphere(0.06, 0.12)
	eye.material = CleanBot.simple_mat(Color(0.3, 0.85, 1.0), true)
	_mesh(root, eye, Vector3(0, -0.08, 0))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var arm := _mesh(root, _box_mesh(Vector3(0.36, 0.03, 0.04), dark), Vector3(cos(a), 0, sin(a)) * 0.24)
		arm.rotation.y = -a
		var hub := _cyl(0.035, 0.035, 0.06)
		hub.material = dark
		_mesh(root, hub, Vector3(cos(a), 0, sin(a)) * 0.42 + Vector3.UP * 0.03)
		var rotor := _mesh(root, _box_mesh(Vector3(0.32, 0.008, 0.035), _std("rotor", Color(0.25, 0.27, 0.3), 0.4)), Vector3(cos(a), 0, sin(a)) * 0.42 + Vector3.UP * 0.07)
		rotor.name = "Rotor%d" % i
	# Greifer unten
	for side: float in [-1.0, 1.0]:
		var claw := _mesh(root, _box_mesh(Vector3(0.02, 0.14, 0.05), orange), Vector3(side * 0.05, -0.16, 0))
		claw.rotation.z = side * 0.3
	return root


# ================================================================ Bauhelfer

func _rock(pos: Vector3, size: Vector3, yaw: float, seed_index: int, collide: bool) -> void:
	var key := "rock_%d" % seed_index
	if not _bmats.has(key):
		var m := ShaderMaterial.new()
		m.shader = ROCK
		m.set_shader_parameter("seed", seed_index * 3.7)
		m.set_shader_parameter("bump", 0.32)
		_bmats[key] = m
	if not _bmats.has("rock_mesh"):
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 28
		sphere.rings = 14
		_bmats["rock_mesh"] = sphere
	var rock := MeshInstance3D.new()
	rock.mesh = _bmats["rock_mesh"]
	rock.material_override = _bmats[key]
	rock.position = pos
	rock.rotation.y = yaw
	rock.scale = size
	add_child(rock)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size * Vector3(0.85, 1.0, 0.85)
		col.shape = shape
		col.position = pos
		col.rotation.y = yaw
		world_body.add_child(col)


func _wood(key: String, light: Color, dark: Color, paint := 0.0, plank := 0.0, along_x := false) -> ShaderMaterial:
	if _bmats.has(key):
		return _bmats[key]
	var m := ShaderMaterial.new()
	m.shader = WOOD
	m.set_shader_parameter("light_wood", light)
	m.set_shader_parameter("dark_wood", dark)
	m.set_shader_parameter("paint_amount", paint)
	m.set_shader_parameter("plank_width", plank)
	m.set_shader_parameter("grain_along_x", along_x)
	_bmats[key] = m
	return m


func _stripes(key: String, a: Color, b: Color, count: float) -> ShaderMaterial:
	if _bmats.has(key):
		return _bmats[key]
	var m := ShaderMaterial.new()
	m.shader = STRIPES
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("count", count)
	_bmats[key] = m
	return m


func _std(key: String, color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := mat("beach_" + key, color, roughness)
	m.metallic = metallic
	return m


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = material
	return b


func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 14
	c.rings = 1
	return c


func _sphere(radius: float, height: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 14
	s.rings = 7
	return s


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	parent.add_child(m)
	return m
