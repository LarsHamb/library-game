extends CleanGame
## Das Bibliotheks-Thema: baut den Großen Lesesaal und die Werkzeug-Modelle.
## Alle Spielregeln (Münzen, Upgrades, Speichern ...) kommen aus addons/clean_core.

const LibraryConfig := preload("res://game/library/library_config.gd")
const Materials := preload("res://game/library/materials.gd")
const COBWEB := preload("res://game/library/shaders/cobweb.gdshader")

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
const FLOOR_SPACING := 0.28     # Abstand der Bodenflocken
const BOOK_COIN_MULT := 2.0     # ein Buch bringt doppelt so viel wie eine Bodenflocke
const BOOK_DUST_MAX_Y := 4.6    # Bücher darüber bleiben sauber (da kommt niemand hin)
const BOOK_SEGMENT := 3.5       # lange Wandregale: alle 3,5 m ein eigener Bonus-Abschnitt
const LOOSE_BOOKS := {"main": 24, "archive": 8, "dome": 8}
# --- Türen zu den Nebensälen (in beiden Seitenwänden) ---
const DOOR_Z := 9.0
const DOOR_W := 3.0
const DOOR_H := 3.5
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
var _book_spots: Array[Vector3] = []     # Stelle am Buchrücken, an der man das Buch putzt
var _book_dirt := PackedFloat32Array()   # 0 = sauber (zu hoch oben), sonst Staubmenge
var _book_group := PackedInt32Array()    # Regalboden (bzw. Abschnitt), für den Bonus
var _book_zone: Array[String] = []
var _book_gaps: Array[Dictionary] = []   # Lücken im Regal: dorthin gehören die verstreuten Bücher
var _zone_id := "main"                   # in welcher Zone gerade gebaut wird
var _group_counter := 0
var _zone_excludes := {}                 # Zone -> Flächen ohne Bodenstaub (dort liegt auch kein Buch herum)
var _shelf_spots: Array[Vector3] = []   # mögliche Verstecke für seltene Bücher auf Regalböden
var _no_floor_dust: Array[Rect2] = []
var _extra_spots: Array[Vector3] = []   # Verstecke für Bücher in den Nebensälen
var _lib_mats := {}


# ================================================================ Anbindung an den Kern

func _create_config() -> CleanGameConfig:
	return LibraryConfig.create()


func _build_world() -> void:
	_rng.seed = 7
	_build_hall()
	_build_shelves(_no_floor_dust)
	_build_tables(_no_floor_dust)
	# Der Boden ist Nebensache: lockerer verteilt als früher, die Bücher bringen das meiste
	mess.add_area(Vector3.ZERO, HALL_SIZE - Vector2(0.4, 0.4), FLOOR_SPACING, 1.15, _no_floor_dust)
	_build_archive()
	_build_dome()
	_build_books()
	_scatter_books()
	_add_air_motes(HALL_SIZE.x * 0.5)
	_build_cobwebs()


func _make_tool_visual(tool: CleanTool) -> Node3D:
	if tool.id == "vacuum":
		return _make_vacuum()
	if tool.id == "web_broom":
		return _make_web_broom()
	return _make_duster()


func _tool_display_name(tool: CleanTool) -> String:
	if tool.id == "duster":
		return DUSTER_NAMES[mini(state.level("radius"), DUSTER_NAMES.size() - 1)]
	return tool.display_name


func _on_stats_applied() -> void:
	player.set_tool_scale("duster", 1.0 + state.level("radius") * 0.15)


## Seltene Bücher stecken zwischen den Regalbüchern: drei auf unteren, zwei auf hohen Regalböden,
## je eines im Kartenarchiv und im Kuppelsaal. Immer dieselben Plätze.
func _collectible_spots() -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector3] = []
	var low_spots := _shelf_spots.filter(func(v: Vector3) -> bool: return v.y < 1.5)
	var high_spots := _shelf_spots.filter(func(v: Vector3) -> bool: return v.y > 1.5)
	while spots.size() < 3:
		var p: Vector3 = low_spots[rng.randi() % low_spots.size()]
		if not spots.has(p):
			spots.append(p)
	while spots.size() < 5:
		var p: Vector3 = high_spots[rng.randi() % high_spots.size()]
		if not spots.has(p):
			spots.append(p)
	spots.append_array(_extra_spots)   # Buch 6 im Kartenarchiv, Buch 7 im Kuppelsaal
	return spots


func _make_collectible_model(_def: CleanCollectibleDef) -> Node3D:
	# Ein dickes, altes Buch: roter Einband mit Goldkanten, helle Seiten, leichtes Leuchten
	var book := Node3D.new()
	var cover := Materials.glow(Color(0.5, 0.08, 0.1), 0.25)
	cover.roughness = 0.5
	var gold := Materials.glow(Color(1.0, 0.75, 0.3), 1.2)
	gold.metallic = 0.8
	var pages := mat("collectible_pages", Color(0.93, 0.88, 0.74), 0.9)
	_part(book, _box_mesh(Vector3(0.26, 0.012, 0.19), cover), Vector3(0, 0.006, 0))
	_part(book, _box_mesh(Vector3(0.26, 0.012, 0.19), cover), Vector3(0, 0.064, 0))
	_part(book, _box_mesh(Vector3(0.245, 0.048, 0.18), pages), Vector3(0.006, 0.035, 0))
	_part(book, _box_mesh(Vector3(0.016, 0.07, 0.19), cover), Vector3(-0.122, 0.035, 0))
	for z: float in [-0.06, 0.06]:
		_part(book, _box_mesh(Vector3(0.018, 0.072, 0.012), gold), Vector3(-0.122, 0.035, z))
	_part(book, _box_mesh(Vector3(0.1, 0.002, 0.07), gold), Vector3(0.02, 0.071, 0))
	book.rotation.y = randf() * TAU
	return book


# ================================================================ Werkzeug-Modelle

func _make_duster() -> Node3D:
	var duster := Node3D.new()
	duster.rotation = Vector3(-1.22, 0.0, -0.21)   # schräg nach vorne oben
	var handle := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.011
	stick.bottom_radius = 0.016
	stick.height = 0.42
	stick.material = _lib_mat("table")
	handle.mesh = stick
	duster.add_child(handle)
	var ferrule := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.018
	ring.bottom_radius = 0.014
	ring.height = 0.05
	ring.material = _brass()
	ferrule.mesh = ring
	ferrule.position.y = 0.2
	duster.add_child(ferrule)
	# Federkopf: viele schmale, nach außen geneigte Federn (wird mit den Upgrades größer)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.22
	head.scale = Vector3(1.0, 1.5, 1.0)
	duster.add_child(head)
	var feather_colors := [Color(0.93, 0.62, 0.72), Color(0.85, 0.5, 0.62), Color(0.97, 0.78, 0.82)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		var feather := MeshInstance3D.new()
		var plume := SphereMesh.new()
		plume.radius = 0.022
		plume.height = 0.13
		plume.radial_segments = 8
		plume.rings = 4
		plume.material = mat("duster_feathers_%d" % (i % 3), feather_colors[i % 3], 1.0)
		feather.mesh = plume
		var angle := rng.randf() * TAU
		var tilt := rng.randf_range(0.15, 0.85) if i > 3 else 0.05
		feather.rotation = Vector3(tilt * cos(angle), 0.0, tilt * sin(angle))
		feather.position = feather.basis * Vector3(0, 0.055, 0) + Vector3(cos(angle), 0, sin(angle)) * 0.01
		head.add_child(feather)
	return duster


## Langer Stiel mit runder, flauschiger Bürste – reicht bis unter die Decke.
func _make_web_broom() -> Node3D:
	var broom := Node3D.new()
	broom.rotation = Vector3(-0.95, 0.0, -0.18)   # steiler nach oben als der Wedel
	var pole := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.01
	stick.bottom_radius = 0.013
	stick.height = 0.9
	stick.material = _lib_mat("table")
	pole.mesh = stick
	pole.position.y = 0.25
	broom.add_child(pole)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.72
	head.scale = Vector3(1.0, 1.5, 1.0)
	broom.add_child(head)
	var brush := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.11
	ball.material = mat("web_broom_bristles", Color(0.22, 0.2, 0.18), 1.0)
	brush.mesh = ball
	head.add_child(brush)
	var cap := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.03
	ring.bottom_radius = 0.02
	ring.height = 0.04
	ring.material = _brass()
	cap.mesh = ring
	cap.position.y = -0.05
	head.add_child(cap)
	return broom


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


func _title_view() -> Dictionary:
	return {"from": Vector3(-6.0, 3.2, 13.0), "to": Vector3(6.0, 2.8, 13.0), "look": Vector3(0, 2.0, -6.0)}


## Kamerapunkte für den Foto-Rundgang (godot --path . -- --screenshots).
func _screenshot_views() -> Array[Dictionary]:
	return [
		{"name": "lesesaal", "pos": Vector3(0, 1.7, 12.6), "look": Vector3(0, 2.2, -6)},
		{"name": "von_oben", "pos": Vector3(-2, 6.0, 13.2), "look": Vector3(1, 0.5, -4)},
		{"name": "regalgang", "pos": Vector3(10.2, 1.6, 1.25), "look": Vector3(0, 1.2, 1.25)},
		{"name": "regal_nah", "pos": Vector3(3.2, 1.35, 1.0), "look": Vector3(3.6, 0.9, -0.45)},
		{"name": "boden_staub", "pos": Vector3(0.4, 1.3, 6.5), "look": Vector3(0, 0, 3.0)},
		{"name": "lesetische", "pos": Vector3(-1.8, 2.0, 13.4), "look": Vector3(-5, 0.7, 9.5)},
		{"name": "fenster", "pos": Vector3(6, 2.2, -2.5), "look": Vector3(-11, 4.0, -9.0)},
		{"name": "kartenarchiv", "pos": Vector3(-12.2, 1.7, 13.2), "look": Vector3(-22, 0.8, 3)},
		{"name": "kuppelsaal", "pos": Vector3(12.2, 1.8, 13.2), "look": Vector3(22, 2.5, 2)},
	]


# ================================================================ Lesesaal

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.022, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.68, 0.52)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssil_intensity = 0.8
	env.ssr_max_steps = 48
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Leichter, warmer Dunst im Raum: macht Lichtkegel der Fenster sichtbar
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.95, 0.85, 0.7)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	environment = env

	# Kronleuchter: große im Mittelgang (mit Schatten), kleinere über den Regalreihen
	for z: float in [-11.0, -3.0, 5.0, 11.0]:
		_add_chandelier(Vector3(0.0, WALL_HEIGHT, z), 0.9, 1.9, true)
		for x: float in [-6.5, 6.5]:
			_add_chandelier(Vector3(x, WALL_HEIGHT, z), 0.55, 1.1, false)
	_build_windows()


## Kronleuchter mit Kette, Messingring und Kerzen. top = Aufhängepunkt an der Decke.
func _add_chandelier(top: Vector3, radius: float, energy: float, shadow: bool) -> void:
	var drop := 1.3 + radius * 0.5
	var center := top - Vector3(0, drop, 0)
	box(Vector3(0.025, drop, 0.025), top - Vector3(0, drop * 0.5, 0), _brass(), false)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.035
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 8
	torus.material = _brass()
	ring.mesh = torus
	ring.position = center
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var hub := MeshInstance3D.new()
	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 0.09 + radius * 0.06
	hub_mesh.height = hub_mesh.radius * 2.6
	hub_mesh.material = _brass()
	hub.mesh = hub_mesh
	hub.position = center
	add_child(hub)
	var candles := 8 if radius > 0.7 else 6
	var flame_mat := _lib_mat_glow("flame", Color(1.0, 0.78, 0.45), 6.0)
	var wax := mat("candle_wax", Color(0.95, 0.92, 0.85), 0.6)
	for i in candles:
		var a := TAU * i / candles
		var p := center + Vector3(cos(a), 0, sin(a)) * (radius - 0.0175)
		box(Vector3(radius, 0.015, 0.025), center.lerp(p, 0.5), _brass(), false).rotation.y = -a
		var candle := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.018
		stick.bottom_radius = 0.018
		stick.height = 0.14
		stick.radial_segments = 8
		stick.material = wax
		candle.mesh = stick
		candle.position = p + Vector3(0, 0.08, 0)
		candle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(candle)
		var flame := MeshInstance3D.new()
		var drop_mesh := SphereMesh.new()
		drop_mesh.radius = 0.016
		drop_mesh.height = 0.05
		drop_mesh.radial_segments = 8
		drop_mesh.rings = 4
		drop_mesh.material = flame_mat
		flame.mesh = drop_mesh
		flame.position = p + Vector3(0, 0.175, 0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
	var lamp := OmniLight3D.new()
	lamp.position = center + Vector3(0, 0.25, 0)
	lamp.light_color = Color(1.0, 0.8, 0.56)
	lamp.light_energy = energy
	lamp.omni_range = 12.0 if shadow else 9.0
	lamp.omni_attenuation = 1.2
	lamp.light_volumetric_fog_energy = 0.4
	lamp.shadow_enabled = shadow
	lamp.shadow_blur = 1.5
	add_child(lamp)


## Hohe Rundbogenfenster: in der Stirnwand hinter dem Start und in den Seitenwänden (nur dort,
## wo keine Nebensäle anschließen). Durch jedes fällt ein Lichtkegel schräg in den Saal.
func _build_windows() -> void:
	var hx := HALL_SIZE.x * 0.5
	var hz := HALL_SIZE.y * 0.5
	for x: float in [-7.0, 0.0, 7.0]:
		_add_window(Vector3(x, 0, hz), Vector3(0, 0, -1), x == 0.0)
	for side: float in [-1.0, 1.0]:
		for z: float in [-11.5, -7.75, -4.0]:
			_add_window(Vector3(side * hx, 0, z), Vector3(-side, 0, 0), z == -7.75)


## Ein Fenster in der Wand bei base (Bodenhöhe), inward zeigt in den Raum.
func _add_window(base: Vector3, inward: Vector3, shadow: bool) -> void:
	var width := 1.7
	var sill := 3.4
	var height := 2.4   # bis zum Bogenansatz
	var along := Vector3(inward.z, 0, -inward.x).abs()   # Richtung entlang der Wand
	var face := base + inward * 0.005
	var pane_mat := _lib_mat_glow("window", Color(0.78, 0.86, 1.0), 1.6)
	var frame := _lib_mat("door")
	# Glas: Rechteck plus Halbkreis
	var pane := box(along * width + Vector3.UP * height + inward.abs() * 0.02, face + Vector3.UP * (sill + height * 0.5), pane_mat, false)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = width * 0.5
	disc.bottom_radius = width * 0.5
	disc.height = 0.02
	disc.radial_segments = 32
	disc.material = pane_mat
	arch.mesh = disc
	arch.position = face + Vector3.UP * (sill + height)
	arch.basis = Basis(along, PI * 0.5)   # Zylinderachse zeigt danach in den Raum
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arch)
	# Rahmen, Sprossen und Fensterbank
	var depth := inward * 0.06
	var depth_size := inward.abs() * 0.08
	box(along * (width + 0.2) + Vector3.UP * 0.12 + inward.abs() * 0.22, face + inward * 0.1 + Vector3.UP * (sill - 0.06), frame, false)
	for side: float in [-1.0, 1.0]:
		box(along * 0.1 + Vector3.UP * height + depth_size, face + depth + along * side * (width * 0.5 + 0.03) + Vector3.UP * (sill + height * 0.5), frame, false)
	box(along * 0.05 + Vector3.UP * (height + width * 0.5) + depth_size, face + depth + Vector3.UP * (sill + (height + width * 0.5) * 0.5), frame, false)
	for k in 3:
		box(along * width + Vector3.UP * 0.04 + depth_size, face + depth + Vector3.UP * (sill + height * (k + 1) / 3.0), frame, false)
	# Lichtkegel nach innen und unten
	var sun := SpotLight3D.new()
	add_child(sun)
	sun.global_position = face + inward * 0.3 + Vector3.UP * (sill + height * 0.8)
	sun.look_at(sun.global_position + inward * 1.0 + Vector3.DOWN * 0.75 + along * 0.25)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 5.0
	sun.spot_range = 16.0
	sun.spot_angle = 22.0
	sun.spot_attenuation = 0.8
	sun.light_volumetric_fog_energy = 2.5
	sun.shadow_enabled = shadow


func _build_hall() -> void:
	var hx := HALL_SIZE.x * 0.5
	var hz := HALL_SIZE.y * 0.5
	box(Vector3(HALL_SIZE.x, 0.2, HALL_SIZE.y), Vector3(0, -0.1, 0), _lib_mat("floor"))
	var wall := _lib_mat("wall")
	box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, -hz - 0.15), wall)
	box(Vector3(HALL_SIZE.x, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT * 0.5, hz + 0.15), wall)
	# Seitenwände mit je einer Tür zu einem Nebensaal
	for side: float in [-1.0, 1.0]:
		var x := side * (hx + 0.15)
		var back_len := DOOR_Z - DOOR_W * 0.5 + hz
		var front_len := hz - DOOR_Z - DOOR_W * 0.5
		box(Vector3(0.3, WALL_HEIGHT, back_len), Vector3(x, WALL_HEIGHT * 0.5, -hz + back_len * 0.5), wall)
		box(Vector3(0.3, WALL_HEIGHT, front_len), Vector3(x, WALL_HEIGHT * 0.5, hz - front_len * 0.5), wall)
		box(Vector3(0.3, WALL_HEIGHT - DOOR_H, DOOR_W), Vector3(x, DOOR_H + (WALL_HEIGHT - DOOR_H) * 0.5, DOOR_Z), wall)
	box(Vector3(HALL_SIZE.x + 0.6, 0.3, HALL_SIZE.y + 0.6), Vector3(0, WALL_HEIGHT + 0.15, 0),
		_lib_mat("ceiling"))   # mit Kollision, damit der Besen die Spinnweben an der Decke trifft


# ================================================================ Nebensäle

## Kartenarchiv links: niedrige Decke, Kartenschränke, Globen, rußiger Staub (1,5× Münzen).
func _build_archive() -> void:
	var zone := add_zone("archive", "Kartenarchiv", Rect2(-27.0, -2.0, 16.0, 16.0), 8000, 1.5, Color(0.5, 0.47, 0.44))
	_zone_id = "archive"
	zone.spawn = Vector3(-12.3, 0.05, DOOR_Z)
	zone.spawn_yaw = PI * 0.5   # Blick in den Saal (nach -x)
	var cx := -19.0
	var cz := 6.0
	var size := Vector2(16.0, 16.0)
	var height := 4.5
	_build_room(Vector3(cx, 0, cz), size, height, -1.0, _lib_mat("floor_archive"), _lib_mat("archive_wall"),
		_lib_mat("ceiling"))
	var hx := HALL_SIZE.x * 0.5
	add_door(zone, Vector3(0.2, DOOR_H, DOOR_W), Vector3(-hx - 0.15, DOOR_H * 0.5, DOOR_Z), _lib_mat("door"),
		"Kartenarchiv\n[U] im Upgrade-Laden öffnen", Vector3(-hx + 0.8, DOOR_H + 0.7, DOOR_Z))

	var excludes: Array[Rect2] = []
	var none: Array[Rect2] = []
	var wood := _lib_mat("cabinet")
	var brass := _brass()
	for x: float in [-24.5, -21.0, -17.5, -14.0]:
		for z: float in [0.8, 3.8, 6.4, 11.8]:
			box(Vector3(2.4, 1.1, 1.0), Vector3(x, 0.55, z), wood)
			for y: float in [0.3, 0.6, 0.9]:
				for side: float in [-0.51, 0.51]:
					box(Vector3(2.3, 0.02, 0.02), Vector3(x, y, z + side), brass, false)
			zone.mess.add_area(Vector3(x, 1.1, z), Vector2(2.3, 0.9), 0.1, 0.45, none, 0.2)
			excludes.append(Rect2(x - 1.25, z - 0.55, 2.5, 1.1))
	_extra_spots.append(Vector3(-21.0 + 0.6, 1.1, 11.8))

	var blue := mat("globe", Color(0.32, 0.45, 0.5), 0.45)
	for g: Vector2 in [Vector2(-25.8, 13.0), Vector2(-25.8, -0.8), Vector2(-12.5, -0.8)]:
		box(Vector3(0.08, 0.9, 0.08), Vector3(g.x, 0.45, g.y), brass, false)
		var globe := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		sphere.material = blue
		globe.mesh = sphere
		globe.position = Vector3(g.x, 1.2, g.y)
		add_child(globe)
		# Messing-Meridian und Fuß
		var meridian := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.37
		ring.outer_radius = 0.4
		ring.material = brass
		meridian.mesh = ring
		meridian.position = globe.position
		meridian.rotation = Vector3(0, 0.5, PI * 0.5 - 0.41)
		add_child(meridian)
		var foot := MeshInstance3D.new()
		var foot_mesh := CylinderMesh.new()
		foot_mesh.top_radius = 0.12
		foot_mesh.bottom_radius = 0.28
		foot_mesh.height = 0.12
		foot_mesh.material = wood
		foot.mesh = foot_mesh
		foot.position = Vector3(g.x, 0.06, g.y)
		add_child(foot)
		add_collider(Vector3(0.6, 1.6, 0.6), Vector3(g.x, 0.8, g.y))
		excludes.append(Rect2(g.x - 0.4, g.y - 0.4, 0.8, 0.8))

	# Bücherregale mit Atlanten an den beiden langen Wänden
	var atlas_boards: Array = [0.1, 0.6, 1.1, 1.6, 2.1, 2.6]
	for x: float in [-24.5, -21.0, -17.5, -14.0]:
		_build_case(x, -2.0 + CASE_DEPTH * 0.5, 1.0, CASE_WIDTH - 0.1, 3.1, atlas_boards, 0)
		excludes.append(Rect2(x - CASE_WIDTH * 0.5, -2.0, CASE_WIDTH, CASE_DEPTH + 0.1))
	for x: float in [-24.5, -21.0, -17.5]:
		_build_case(x, 14.0 - CASE_DEPTH * 0.5, -1.0, CASE_WIDTH - 0.1, 3.1, atlas_boards, 0)
		excludes.append(Rect2(x - CASE_WIDTH * 0.5, 14.0 - CASE_DEPTH - 0.1, CASE_WIDTH, CASE_DEPTH + 0.1))
	zone.mess.add_area(Vector3(cx, 0, cz), size - Vector2(0.4, 0.4), FLOOR_SPACING, 1.15, excludes, 0.25)
	_zone_excludes["archive"] = excludes
	for lx: float in [-4.0, 4.0]:
		for lz: float in [-4.0, 4.0]:
			_add_lamp(Vector3(cx + lx, height - 0.6, cz + lz), Color(0.95, 0.85, 0.7), 1.3, 9.0, lx < 0 and lz < 0)


## Kuppelsaal rechts: hohe Glaskuppel, Statuen, ein großer Lesetisch und Goldstaub (2,5× Münzen).
func _build_dome() -> void:
	var zone := add_zone("dome", "Kuppelsaal", Rect2(11.0, -2.0, 18.0, 16.0), 25000, 2.5, Color(0.86, 0.73, 0.42))
	_zone_id = "dome"
	zone.spawn = Vector3(12.3, 0.05, DOOR_Z)
	zone.spawn_yaw = -PI * 0.5
	zone.mess.thick_darken = 0.04
	var cx := 20.0
	var cz := 6.0
	var size := Vector2(18.0, 16.0)
	var height := 10.0
	_build_room(Vector3(cx, 0, cz), size, height, 1.0, _lib_mat("floor_dome"), _lib_mat("dome_wall"),
		mat("dome_ceiling", Color(0.8, 0.76, 0.7), 0.9))
	var hx := HALL_SIZE.x * 0.5
	add_door(zone, Vector3(0.2, DOOR_H, DOOR_W), Vector3(hx + 0.15, DOOR_H * 0.5, DOOR_Z), _lib_mat("door"),
		"Kuppelsaal\n[U] im Upgrade-Laden öffnen", Vector3(hx - 0.8, DOOR_H + 0.7, DOOR_Z))

	# Glaskuppel als leuchtende Scheibe mit kräftigem Licht
	var sky := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 4.0
	disc.bottom_radius = 4.0
	disc.height = 0.05
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.85, 0.92, 1.0)
	glass.emission_energy_multiplier = 2.5
	disc.material = glass
	sky.mesh = disc
	sky.position = Vector3(cx, height - 0.05, cz)
	add_child(sky)
	_add_lamp(Vector3(cx, height - 1.5, cz), Color(0.95, 0.97, 1.0), 3.0, 18.0, true)
	for lx: float in [-6.0, 6.0]:
		_add_lamp(Vector3(cx + lx, 5.0, cz), Color(1.0, 0.85, 0.6), 1.2, 9.0, false)

	var excludes: Array[Rect2] = []
	var none: Array[Rect2] = []
	# Großer Lesetisch in der Mitte
	var wood := _lib_mat("table")
	box(Vector3(3.2, 0.9, 3.2), Vector3(cx, 0.45, cz), wood)
	zone.mess.add_area(Vector3(cx, 0.9, cz), Vector2(3.0, 3.0), 0.1, 0.45, none, 0.1)
	excludes.append(Rect2(cx - 1.7, cz - 1.7, 3.4, 3.4))
	_extra_spots.append(Vector3(cx + 0.9, 0.9, cz - 0.7))

	# Vier Statuen auf Sockeln
	var marble := _lib_mat("marble")
	for p: Vector2 in [Vector2(14.5, 1.0), Vector2(25.5, 1.0), Vector2(14.5, 11.0), Vector2(25.5, 11.0)]:
		box(Vector3(1.0, 1.0, 1.0), Vector3(p.x, 0.5, p.y), marble)
		# Schlichte Büste: Gewand, Schultern, Kopf
		var statue := MeshInstance3D.new()
		var robe := CylinderMesh.new()
		robe.top_radius = 0.2
		robe.bottom_radius = 0.34
		robe.height = 1.2
		robe.material = marble
		statue.mesh = robe
		statue.position = Vector3(p.x, 1.68, p.y)
		add_child(statue)
		var shoulders := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.28
		shoulder_mesh.height = 0.3
		shoulder_mesh.material = marble
		shoulders.mesh = shoulder_mesh
		shoulders.position = Vector3(p.x, 2.3, p.y)
		shoulders.scale = Vector3(1.0, 1.0, 0.7)
		add_child(shoulders)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.13
		head_mesh.height = 0.32
		head_mesh.material = marble
		head.mesh = head_mesh
		head.position = Vector3(p.x, 2.6, p.y)
		add_child(head)
		add_collider(Vector3(0.5, 1.6, 0.5), Vector3(p.x, 1.8, p.y))
		var under_statue: Array[Rect2] = [Rect2(p.x - 0.28, p.y - 0.28, 0.56, 0.56)]
		zone.mess.add_area(Vector3(p.x, 1.0, p.y), Vector2(0.9, 0.9), 0.08, 0.4, under_statue)
		excludes.append(Rect2(p.x - 0.55, p.y - 0.55, 1.1, 1.1))

	# Hohe Bücherwand an der Rückseite (Kulisse)
	var tall_boards: Array = []
	var y := 0.1
	while y < height - 1.0:
		tall_boards.append(y)
		y += 0.5
	_build_case(cx, -2.0 + CASE_DEPTH * 0.5, 1.0, size.x - 0.1, height - 0.6, tall_boards, 0)
	excludes.append(Rect2(cx - size.x * 0.5, -2.0, size.x, CASE_DEPTH + 0.05))

	zone.mess.add_area(Vector3(cx, 0, cz), size - Vector2(0.4, 0.4), FLOOR_SPACING, 1.15, excludes)
	_zone_excludes["dome"] = excludes


## Boden, drei Außenwände und Decke eines Nebensaals. side = -1 links vom Lesesaal, +1 rechts.
func _build_room(center: Vector3, size: Vector2, height: float, side: float, floor_mat: Material, wall: Material, ceiling: Material) -> void:
	box(Vector3(size.x, 0.2, size.y), center + Vector3(0, -0.1, 0), floor_mat)
	box(Vector3(0.3, height, size.y), Vector3(center.x + side * (size.x * 0.5 + 0.15), height * 0.5, center.z), wall)
	box(Vector3(size.x, height, 0.3), Vector3(center.x, height * 0.5, center.z - size.y * 0.5 - 0.15), wall)
	box(Vector3(size.x, height, 0.3), Vector3(center.x, height * 0.5, center.z + size.y * 0.5 + 0.15), wall)
	# Die Decke ragt nur nach außen über, nicht in den Lesesaal hinein
	box(Vector3(size.x + 0.3, 0.3, size.y + 0.6), Vector3(center.x + side * 0.15, height + 0.15, center.z), ceiling)


func _add_lamp(pos: Vector3, color: Color, energy: float, light_range: float, shadow: bool) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = light_range
	lamp.shadow_enabled = shadow
	add_child(lamp)


# ================================================================ Lesesaal

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
	var wood := _lib_mat("shelf")
	box(Vector3(width, height, 0.03), Vector3(cx, height * 0.5, cz - dir * (d * 0.5 - 0.015)), wood)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.05, height, d), Vector3(cx + side * (width * 0.5 - 0.025), height * 0.5, cz), wood)
	box(Vector3(width, 0.05, d), Vector3(cx, height - 0.025, cz), wood)
	# Kranzgesims oben und Sockelleiste unten
	box(Vector3(width + 0.08, 0.07, d + 0.06), Vector3(cx, height + 0.035, cz + dir * 0.03), wood, false)
	box(Vector3(width + 0.12, 0.035, d + 0.1), Vector3(cx, height + 0.087, cz + dir * 0.05), wood, false)
	box(Vector3(width, 0.08, 0.025), Vector3(cx, 0.04, cz + dir * (d * 0.5 - 0.0125)), wood, false)

	var inner := width - 0.1
	var back := cz - dir * (d * 0.5 - 0.03)
	var no_excludes: Array[Rect2] = []
	var strip := d - 0.36
	var strip_z := cz + dir * (d * 0.5 - 0.02 - strip * 0.5)
	var dusty_tops: Array[float] = []
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
			dusty_tops.append(top)
			var extra := UPPER_BOARD_DIRT if board_y > 1.5 else 0.0
			_shelf_spots.append(Vector3(cx + _rng.randf_range(-inner * 0.4, inner * 0.4), top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)))
			mess.add_area(Vector3(cx, top, cz + dir * (d * 0.5 - 0.02 - strip * 0.5)),
				Vector2(inner - 0.04, strip), 0.075, 0.33, no_excludes, extra)
	if dusty > 0:
		_build_ladder(cx + _rng.randf_range(-1.0, 1.0), cz + dir * (d * 0.5), dir, height)
		# Schiene für einen Regal-Roboter (wird erst sichtbar, wenn einer gekauft ist)
		add_rail(Vector3(cx - inner * 0.5 + 0.2, 0, strip_z), Vector3(cx + inner * 0.5 - 0.2, 0, strip_z), dusty_tops, Vector3(0, 0, dir))


## Eine Leiter vor dem Regal. Man klettert, indem man auf das Regal zu läuft.
func _build_ladder(x: float, front_z: float, dir: float, height: float) -> void:
	var metal := _brass()
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
	var start := x
	var board_group := _group_counter
	_group_counter += ceili(inner / BOOK_SEGMENT)
	var dusty := top < BOOK_DUST_MAX_Y
	var extra := UPPER_BOARD_DIRT * 2.0 if top > 1.5 else 0.0   # oben putzt nie jemand
	while true:
		var w := _rng.randf_range(0.035, 0.085)
		if x + w > end:
			break
		if _rng.randf() < 0.04:   # hin und wieder eine Lücke – dort fehlt ein Buch
			var gap_w := _rng.randf_range(0.07, 0.25)
			if x + gap_w <= end and gap > 0.26:
				_book_gaps.append({"x": x + gap_w * 0.5, "w": gap_w, "top": top, "gap": gap, "back": back, "dir": dir, "zone": _zone_id})
			x += gap_w
			continue
		var h := minf(_rng.randf_range(0.24, 0.4), gap)
		var depth := _rng.randf_range(0.2, 0.29)
		_book_transforms.append(Transform3D(Basis().scaled(Vector3(w, h, depth)),
			Vector3(x + w * 0.5, top + h * 0.5, back + dir * depth * 0.5)))
		var color: Color = BOOK_COLORS[_rng.randi() % BOOK_COLORS.size()]
		_book_colors.append(color.darkened(_rng.randf_range(0.0, 0.35)))
		_book_spots.append(Vector3(x + w * 0.5, top + h * 0.5, back + dir * depth))
		_book_dirt.append(_rng.randf_range(1.2, 2.4) + extra if dusty else 0.0)
		_book_group.append(board_group + floori((x - start) / BOOK_SEGMENT))
		_book_zone.append(_zone_id)
		x += w + 0.003


func _build_books() -> void:
	var book_mesh := BoxMesh.new()
	book_mesh.material = _lib_mat("book")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true   # Staub pro Buch (siehe book.gdshader)
	mm.mesh = book_mesh
	mm.instance_count = _book_transforms.size()
	for i in _book_transforms.size():
		mm.set_instance_transform(i, _book_transforms[i])
		mm.set_instance_color(i, _book_colors[i])
	var books := MultiMeshInstance3D.new()
	books.multimesh = mm
	add_child(books)
	# Je Zone eine Schicht "Bücher": jede Flocke ist ein Buch und färbt es über die Instanzdaten grau
	var layers := {}
	for z in zones:
		var layer := add_mess_layer(z, "Staubige Bücher", "", Color(0.6, 0.57, 0.52), BOOK_COIN_MULT)
		layer.linked = mm
		layers[z.id] = layer
	for i in _book_transforms.size():
		if _book_dirt[i] > 0.0:
			(layers[_book_zone[i]] as CleanMessField).add_linked_flake(_book_spots[i], _book_dirt[i], i, _book_group[i])


## Verstreute Bücher: liegen auf dem Boden und gehören in eine Lücke im Regal.
## Anklicken – und sie fliegen an ihren Platz zurück.
func _scatter_books() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	_zone_excludes["main"] = _no_floor_dust
	for z in zones:
		var gaps: Array = _book_gaps.filter(func(g: Dictionary) -> bool: return g["zone"] == z.id and g["top"] < 2.2)
		for i in range(gaps.size() - 1, 0, -1):   # mischen, aber immer gleich
			var j := rng.randi_range(0, i)
			var tmp: Variant = gaps[i]
			gaps[i] = gaps[j]
			gaps[j] = tmp
		var area: Rect2 = config.zone_bounds if z == zones[0] else z.bounds
		area = area.grow(-0.8)
		var excludes: Array = _zone_excludes.get(z.id, [])
		var count := mini(int(LOOSE_BOOKS.get(z.id, 0)), gaps.size())
		for k in count:
			var g: Dictionary = gaps[k]
			var w := clampf(float(g["w"]) * 0.7, 0.035, 0.08)
			var h := minf(rng.randf_range(0.24, 0.36), float(g["gap"]) - 0.02)
			var depth := rng.randf_range(0.2, 0.27)
			var color: Color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
			var model := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(w, h, depth)
			mesh.material = _loose_book_mat(color)
			model.mesh = mesh
			var to := Transform3D(Basis(), Vector3(float(g["x"]), float(g["top"]) + h * 0.5, float(g["back"]) + float(g["dir"]) * depth * 0.5))
			# Freie Stelle auf dem Boden suchen
			var spot := Vector3.INF
			for attempt in 40:
				var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0.0, rng.randf_range(area.position.y, area.end.y))
				var free := p.distance_to(config.player_start) > 2.0
				for r: Rect2 in excludes:
					if r.grow(0.25).has_point(Vector2(p.x, p.z)):
						free = false
				if free:
					spot = p
					break
			if spot == Vector3.INF:
				continue
			var lying := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), PI * 0.5)
			var from := Transform3D(lying, spot + Vector3.UP * (w * 0.5 + 0.002))
			add_pickup("buch_%s_%d" % [z.id, k], z, model, from, to, Vector3(w, h, depth), 60)


func _loose_book_mat(color: Color) -> Material:
	var key := "loose_book_%s" % color.to_html()
	if not _lib_mats.has(key):
		var m := Materials.make("book") as ShaderMaterial
		m.set_shader_parameter("tint", color)
		_lib_mats[key] = m
	return _lib_mats[key]


func _build_tables(no_floor_dust: Array[Rect2]) -> void:
	var wood := _lib_mat("table")
	var leather := mat("table_leather", Color(0.16, 0.24, 0.16), 0.7)
	for x: float in [-5.0, 5.0]:
		for z: float in [8.0, 11.5]:
			box(Vector3(2.6, 0.06, 1.2), Vector3(x, 0.75, z), wood)
			box(Vector3(2.66, 0.08, 1.26), Vector3(x, 0.69, z), wood, false)   # Zarge
			box(Vector3(1.6, 0.004, 0.7), Vector3(x, 0.782, z), leather, false)   # Schreibunterlage
			for lx: float in [-1.15, 1.15]:
				for lz: float in [-0.5, 0.5]:
					box(Vector3(0.09, 0.72, 0.09), Vector3(x + lx, 0.36, z + lz), wood, false)
			_add_desk_lamp(Vector3(x, 0.78, z))
			for cx: float in [-0.65, 0.65]:
				for side: float in [-1.0, 1.0]:
					_add_chair(Vector3(x + cx, 0, z + side * 0.72), side)
			var under_lamp: Array[Rect2] = [Rect2(x - 0.15, z - 0.12, 0.3, 0.24)]
			mess.add_area(Vector3(x, 0.78, z), Vector2(2.5, 1.1), 0.1, 0.45, under_lamp)
			# Unter dem Tisch und den Stühlen kommt man mit dem Wedel nicht hin
			no_floor_dust.append(Rect2(x - 1.35, z - 1.05, 2.7, 2.1))


## Grüne Bankierslampe mit kleinem warmem Licht.
func _add_desk_lamp(pos: Vector3) -> void:
	var brass := _brass()
	var foot := MeshInstance3D.new()
	var foot_mesh := CylinderMesh.new()
	foot_mesh.top_radius = 0.06
	foot_mesh.bottom_radius = 0.08
	foot_mesh.height = 0.03
	foot_mesh.material = brass
	foot.mesh = foot_mesh
	foot.position = pos + Vector3(0, 0.015, 0)
	add_child(foot)
	box(Vector3(0.018, 0.3, 0.018), pos + Vector3(0, 0.17, 0), brass, false)
	var shade := MeshInstance3D.new()
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.075
	shade_mesh.bottom_radius = 0.075
	shade_mesh.height = 0.34
	shade_mesh.material = _lib_mat_glow("lamp_green", Color(0.1, 0.42, 0.22), 0.9)
	shade.mesh = shade_mesh
	shade.position = pos + Vector3(0, 0.33, 0)
	shade.rotation.z = PI * 0.5
	shade.scale = Vector3(0.6, 1.0, 1.0)   # flacher, wie ein halber Zylinder
	add_child(shade)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.24, 0)
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 0.9
	light.omni_range = 2.2
	light.light_volumetric_fog_energy = 0.0
	add_child(light)


## Stuhl mit Lehne. facing = +1: Sitzfläche zeigt nach -z (zum Tisch hin, wenn der Stuhl bei +z steht).
func _add_chair(pos: Vector3, facing: float) -> void:
	var wood := _lib_mat("table")
	var cushion := mat("chair_cushion", Color(0.42, 0.1, 0.09), 0.85)
	box(Vector3(0.46, 0.05, 0.44), pos + Vector3(0, 0.46, 0), wood)
	box(Vector3(0.42, 0.04, 0.4), pos + Vector3(0, 0.505, 0), cushion, false)
	for lx: float in [-0.2, 0.2]:
		for lz: float in [-0.19, 0.19]:
			box(Vector3(0.04, 0.44, 0.04), pos + Vector3(lx, 0.22, lz), wood, false)
	var back_z := facing * 0.2
	for lx: float in [-0.2, 0.2]:
		box(Vector3(0.045, 0.5, 0.045), pos + Vector3(lx, 0.73, back_z), wood, false)
	box(Vector3(0.44, 0.1, 0.035), pos + Vector3(0, 0.93, back_z), wood, false)
	box(Vector3(0.3, 0.3, 0.025), pos + Vector3(0, 0.7, back_z), cushion, false)


## Spinnweben unter der Decke von Lesesaal und Kartenarchiv: in Ecken, an den Wänden und an den
## Aufhängungen der Kronleuchter. Nur der Spinnwebenbesen kommt dran, dafür bringt jede viele Münzen.
func _build_cobwebs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var color := Color(0.86, 0.85, 0.82)
	var hall := add_mess_layer(zones[0], "Spinnweben", "web_broom", color, 20.0, COBWEB)
	var hx := HALL_SIZE.x * 0.5 - 0.5
	var hz := HALL_SIZE.y * 0.5 - 0.5
	var y := WALL_HEIGHT - 0.015
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			hall.add_flake_at(Vector3(sx * hx, y, sz * hz), 2.6, 3.0)
			hall.add_flake_at(Vector3(sx * (hx - 1.1), y, sz * (hz - 0.2)), 1.8, 2.5)
	var z := -hz + 2.0
	while z < hz - 1.5:
		for sx: float in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				hall.add_flake_at(Vector3(sx * hx, y, z + rng.randf_range(-0.6, 0.6)), rng.randf_range(1.5, 2.2), rng.randf_range(1.8, 3.0))
		z += 2.6
	var x := -hx + 2.0
	while x < hx - 1.5:
		for sz: float in [-1.0, 1.0]:
			if rng.randf() < 0.5:
				hall.add_flake_at(Vector3(x + rng.randf_range(-0.6, 0.6), y, sz * hz), rng.randf_range(1.5, 2.2), rng.randf_range(1.8, 3.0))
		x += 2.6
	for cx: float in [-6.5, 0.0, 6.5]:
		for cz: float in [-11.0, -3.0, 5.0, 11.0]:
			if rng.randf() < 0.6:
				hall.add_flake_at(Vector3(cx + rng.randf_range(-0.5, 0.5), y, cz + rng.randf_range(-0.5, 0.5)), 1.6, 2.0)

	var archive_zone: CleanZone = null
	for zz in zones:
		if zz.id == "archive":
			archive_zone = zz
	if archive_zone == null:
		return
	var archive := add_mess_layer(archive_zone, "Spinnweben", "web_broom", color.darkened(0.15), 20.0, COBWEB)
	var ay := 4.5 - 0.015
	var r := archive_zone.bounds.grow(-0.5)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		archive.add_flake_at(Vector3(corner.x, ay, corner.y), 2.4, 3.0)
	for i in 10:
		var on_x := rng.randf() < 0.5
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), r.position.y if rng.randf() < 0.5 else r.end.y)
		if on_x:
			p = Vector2(r.position.x, rng.randf_range(r.position.y, r.end.y))
		archive.add_flake_at(Vector3(p.x, ay, p.y), rng.randf_range(1.4, 2.0), rng.randf_range(1.8, 3.0))


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


## Material aus materials.gd, einmal erzeugt und dann wiederverwendet.
func _lib_mat(key: String) -> Material:
	if not _lib_mats.has(key):
		_lib_mats[key] = Materials.make(key)
	return _lib_mats[key]


func _lib_mat_glow(key: String, color: Color, energy: float) -> StandardMaterial3D:
	if not _lib_mats.has(key):
		_lib_mats[key] = Materials.glow(color, energy)
	return _lib_mats[key]


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	m.material = material
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _brass() -> Material:
	if not _lib_mats.has("brass"):
		_lib_mats["brass"] = Materials.metal(Color(0.78, 0.6, 0.3), 0.35)
	return _lib_mats["brass"]
