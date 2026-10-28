class_name CleanMessField
extends MultiMeshInstance3D
## Aller Schmutz einer Zone als ein einziges MultiMesh (Staub, Sand, Ruß ... – nur die Farbe ändert sich).
## So bleiben auch zehntausende Flocken flüssig spielbar.
## Jede Flocke hat eine Schmutzmenge: Dicke Flocken brauchen mehrere Durchgänge und bringen mehr Münzen.

signal flakes_removed(count: int, coins: int)

const CELL_SIZE := 1.0     # Rastergröße für die schnelle Suche nach Flocken
const FADE_TIME := 0.3     # so lange schrumpft eine Flocke, bevor sie weg ist
const FLAKE_SIZE := 0.34   # Grundgröße einer Flocke in Metern
const MIN_DIRT := 1.0      # dünnste Stelle
const MAX_DIRT := 3.0      # dickste Stelle

@export var base_color := Color(0.68, 0.64, 0.57)   # Farbe des Schmutzes
@export var thick_darken := 0.07                     # dicke Stellen werden so viel dunkler
@export var highlight_color := Color(1.0, 0.85, 0.2, 1.0)

var total := 0
var remaining := 0

var _positions := PackedVector3Array()
var _transforms: Array[Transform3D] = []
var _colors := PackedColorArray()
var _alive := PackedByteArray()
var _dirt := PackedFloat32Array()      # aktuelle Staubmenge pro Flocke
var _dirt_max := PackedFloat32Array()  # Staubmenge zu Beginn
var _grid := {}    # Vector3i -> Array der Flocken-Indizes
var _fading := {}  # Index -> vergangene Zeit beim Verschwinden
var _highlight_time := 0.0
var _rng := RandomNumberGenerator.new()
var _thickness := FastNoiseLite.new()


func _init() -> void:
	_rng.seed = 1234
	_thickness.seed = 99
	_thickness.frequency = 0.12
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Verteilt Flocken gleichmäßig (mit etwas Zufall) auf einer waagrechten Fläche.
## extra_dirt hebt die Staubmenge an, z.B. auf hohen Regalböden, wo nie jemand putzt.
func add_area(center: Vector3, size: Vector2, spacing: float, flake_scale := 1.0, excludes: Array[Rect2] = [], extra_dirt := 0.0) -> void:
	var nx := int(size.x / spacing)
	var nz := int(size.y / spacing)
	for ix in nx:
		for iz in nz:
			var p := center + Vector3(
				-size.x * 0.5 + (ix + _rng.randf()) * spacing,
				_rng.randf_range(0.006, 0.016),
				-size.y * 0.5 + (iz + _rng.randf()) * spacing)
			if _is_excluded(p, excludes):
				continue
			# Rauschen sorgt für dicke und dünne Stellen statt gleichmäßigem Grau
			var k := clampf(_thickness.get_noise_3d(p.x, p.y * 3.0, p.z) * 1.4 + 0.45 + extra_dirt, 0.0, 1.0)
			var dirt := lerpf(MIN_DIRT, MAX_DIRT, k)
			var s := flake_scale * _rng.randf_range(0.75, 1.3) * (0.85 + 0.15 * dirt)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, 1.0, s))
			var shade := _rng.randf_range(-0.05, 0.05) - thick_darken * (dirt - 1.0)
			var color := Color(base_color.r + shade, base_color.g + shade, base_color.b + shade, _rng.randf_range(0.8, 0.95))
			_add_flake(Transform3D(basis, p), color, dirt)


## Erzeugt das MultiMesh. Einmal aufrufen, nachdem alle Flächen hinzugefügt wurden.
func build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_flake_mesh()
	mm.instance_count = _transforms.size()
	for i in _transforms.size():
		mm.set_instance_transform(i, _transforms[i])
		mm.set_instance_color(i, _colors[i])
	multimesh = mm
	total = _transforms.size()
	remaining = total


## Wedelt im Umkreis: Jede Flocke verliert Staub (in der Mitte mehr als am Rand).
## Gibt zurück, wie viele Flocken berührt wurden.
func clean_at(point: Vector3, radius: float, amount: float) -> int:
	var min_cell := _cell(point - Vector3.ONE * radius)
	var max_cell := _cell(point + Vector3.ONE * radius)
	var r2 := radius * radius
	var touched := 0
	var removed := 0
	var coins := 0
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				var key := Vector3i(x, y, z)
				if not _grid.has(key):
					continue
				for i: int in _grid[key]:
					if _alive[i] == 0:
						continue
					var d2 := _positions[i].distance_squared_to(point)
					if d2 > r2:
						continue
					touched += 1
					_dirt[i] -= amount * (1.0 - 0.5 * sqrt(d2) / radius)
					if _dirt[i] <= 0.0:
						_alive[i] = 0
						_fading[i] = 0.0
						removed += 1
						coins += roundi(_dirt_max[i])
					else:
						_apply_look(i)
	if removed > 0:
		remaining -= removed
		flakes_removed.emit(removed, coins)
	return touched


## Pustet den Rest der Zone auf einmal weg (z.B. als Belohnung).
func clear_all() -> void:
	var removed := 0
	var coins := 0
	for i in _alive.size():
		if _alive[i] == 1:
			_alive[i] = 0
			_dirt[i] = 0.0
			_fading[i] = -_rng.randf_range(0.0, 1.5)  # negativ = kleine Verzögerung
			removed += 1
			coins += roundi(_dirt_max[i])
	if removed > 0:
		remaining -= removed
		flakes_removed.emit(removed, coins)


## Staub-Radar: Alle übrigen Flocken leuchten eine Weile auf.
func highlight(duration: float) -> void:
	_highlight_time = duration
	for i in _alive.size():
		if _alive[i] == 1:
			_apply_look(i)


## Staubmenge jeder Flocke als Text (für den Spielstand).
func save_state() -> String:
	return Marshalls.raw_to_base64(_dirt.to_byte_array())


## Stellt den Staub aus dem Spielstand wieder her. Passt die Flockenzahl nicht
## (z.B. weil der Saal umgebaut wurde), bleibt der Staub frisch und es kommt false zurück.
func load_state(data: String) -> bool:
	if data.is_empty():
		return false
	var saved := Marshalls.base64_to_raw(data).to_float32_array()
	if saved.size() != total:
		return false
	remaining = 0
	for i in total:
		_dirt[i] = saved[i]
		if saved[i] <= 0.0:
			_alive[i] = 0
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), _positions[i]))
		else:
			_alive[i] = 1
			remaining += 1
			_apply_look(i)
	return true


## Sucht eine Stelle mit Schmutz (für Roboter): prüft zufällige Flocken und nimmt die nächstgelegene.
## Gibt Vector3.INF zurück, wenn nichts gefunden wurde.
func find_mess_near(from: Vector3, max_height: float, rng: RandomNumberGenerator, samples := 40) -> Vector3:
	if remaining == 0:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := INF
	for n in samples:
		var i := rng.randi() % total
		if _alive[i] == 0 or _positions[i].y > max_height:
			continue
		var d := _positions[i].distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = _positions[i]
	return best


func progress_percent() -> float:
	if total == 0:
		return 100.0
	return 100.0 * float(total - remaining) / float(total)


func _process(delta: float) -> void:
	if _highlight_time > 0.0:
		_highlight_time -= delta
		if _highlight_time <= 0.0:
			for i in _alive.size():
				if _alive[i] == 1:
					_apply_look(i)
	if _fading.is_empty():
		return
	for i: int in _fading.keys():
		var t: float = _fading[i] + delta
		if t < 0.0:
			_fading[i] = t
			continue
		var k := t / FADE_TIME
		if k >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), _positions[i]))
			_fading.erase(i)
			continue
		_fading[i] = t
		var base := _transforms[i]
		var s := _look_scale(i) * (1.0 - k)
		multimesh.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3.ONE * s), base.origin + Vector3.UP * k * 0.08))


## Flocke schrumpft und wird blasser, je weniger Staub sie noch hat.
func _apply_look(i: int) -> void:
	var base := _transforms[i]
	multimesh.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3.ONE * _look_scale(i)), base.origin))
	if _highlight_time > 0.0:
		multimesh.set_instance_color(i, highlight_color)
	else:
		var c := _colors[i]
		c.a *= 0.4 + 0.6 * clampf(_dirt[i] / _dirt_max[i], 0.0, 1.0)
		multimesh.set_instance_color(i, c)


func _look_scale(i: int) -> float:
	return 0.5 + 0.5 * clampf(_dirt[i] / _dirt_max[i], 0.0, 1.0)


func _add_flake(t: Transform3D, color: Color, dirt: float) -> void:
	var index := _transforms.size()
	_transforms.append(t)
	_positions.append(t.origin)
	_colors.append(color)
	_alive.append(1)
	_dirt.append(dirt)
	_dirt_max.append(dirt)
	var key := _cell(t.origin)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(index)


func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL_SIZE), floori(p.y / CELL_SIZE), floori(p.z / CELL_SIZE))


func _is_excluded(p: Vector3, excludes: Array[Rect2]) -> bool:
	for r in excludes:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


func _make_flake_mesh() -> Mesh:
	# Weicher, runder Fleck: radialer Verlauf von deckend zu durchsichtig.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var plane := PlaneMesh.new()
	plane.size = Vector2(FLAKE_SIZE, FLAKE_SIZE)
	plane.material = mat
	return plane
