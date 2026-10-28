extends MultiMeshInstance3D
## Aller Staub der Zone als ein einziges MultiMesh.
## So bleiben auch zehntausende Staubflocken flüssig spielbar.

signal flakes_removed(count: int)

const CELL_SIZE := 1.0     # Rastergröße für die schnelle Suche nach Flocken
const FADE_TIME := 0.3     # so lange schrumpft eine Flocke, bevor sie weg ist
const FLAKE_SIZE := 0.34   # Grundgröße einer Flocke in Metern

var total := 0
var remaining := 0

var _positions := PackedVector3Array()
var _transforms: Array[Transform3D] = []
var _colors := PackedColorArray()
var _alive := PackedByteArray()
var _grid := {}    # Vector3i -> Array der Flocken-Indizes
var _fading := {}  # Index -> vergangene Zeit beim Verschwinden
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1234
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Verteilt Flocken gleichmäßig (mit etwas Zufall) auf einer waagrechten Fläche.
func add_area(center: Vector3, size: Vector2, spacing: float, flake_scale := 1.0, excludes: Array[Rect2] = []) -> void:
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
			var s := flake_scale * _rng.randf_range(0.75, 1.3)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, 1.0, s))
			var shade := _rng.randf_range(-0.06, 0.06)
			var color := Color(0.66 + shade, 0.62 + shade, 0.55 + shade, _rng.randf_range(0.75, 0.95))
			_add_flake(Transform3D(basis, p), color)


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


## Entfernt alle Flocken im Umkreis und gibt zurück, wie viele es waren.
func clean_at(point: Vector3, radius: float) -> int:
	var r2 := radius * radius
	var min_cell := _cell(point - Vector3.ONE * radius)
	var max_cell := _cell(point + Vector3.ONE * radius)
	var removed := 0
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				var key := Vector3i(x, y, z)
				if not _grid.has(key):
					continue
				for i: int in _grid[key]:
					if _alive[i] == 1 and _positions[i].distance_squared_to(point) <= r2:
						_alive[i] = 0
						_fading[i] = 0.0
						removed += 1
	if removed > 0:
		remaining -= removed
		flakes_removed.emit(removed)
	return removed


## Pustet den Rest der Zone auf einmal weg (z.B. als Belohnung).
func clear_all() -> void:
	var removed := 0
	for i in _alive.size():
		if _alive[i] == 1:
			_alive[i] = 0
			_fading[i] = -_rng.randf_range(0.0, 1.5)  # negativ = kleine Verzögerung
			removed += 1
	if removed > 0:
		remaining -= removed
		flakes_removed.emit(removed)


func progress_percent() -> float:
	if total == 0:
		return 100.0
	return 100.0 * float(total - remaining) / float(total)


func _process(delta: float) -> void:
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
		multimesh.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3.ONE * (1.0 - k)), base.origin + Vector3.UP * k * 0.08))


func _add_flake(t: Transform3D, color: Color) -> void:
	var index := _transforms.size()
	_transforms.append(t)
	_positions.append(t.origin)
	_colors.append(color)
	_alive.append(1)
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
