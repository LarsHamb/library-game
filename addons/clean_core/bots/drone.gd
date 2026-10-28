class_name CleanDrone
extends CleanBot
## Fliegt über allem und sucht sich selbst schmutzige Stellen am Boden (und auf niedrigen Möbeln).
## Über dem Ziel senkt sie einen Saugstrahl ab und putzt.

const BASE_SPEED := 2.0      # m/s
const BASE_POWER := 4.0
const RADIUS := 0.7

var altitude := 3.6          # Flughöhe, über den Regalen
var max_target_height := 1.0 # nur Schmutz bis zu dieser Höhe anfliegen

var messes: Array[CleanMessField] = []   # alle Schmutzfelder, die die Drohne anfliegen darf
var _target := Vector3.INF
var _target_mess: CleanMessField
var _rotors: Array[Node3D] = []
var _beam: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _search_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	if model == null:
		model = _default_model()
	add_child(model)
	for child in model.get_children():
		if child.name.begins_with("Rotor"):
			_rotors.append(child)
	_beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = RADIUS
	cone.height = 1.0
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(0.5, 0.85, 1.0, 0.18)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = beam_mat
	_beam.mesh = cone
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	position.y = altitude


func _default_model() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.18
	body_mesh.bottom_radius = 0.22
	body_mesh.height = 0.12
	body_mesh.material = simple_mat(Color(0.9, 0.9, 0.92))
	body.mesh = body_mesh
	root.add_child(body)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.06
	eye_mesh.height = 0.12
	eye_mesh.material = simple_mat(Color(0.3, 0.8, 1.0), true)
	eye.mesh = eye_mesh
	eye.position.y = -0.07
	root.add_child(eye)
	for i in 4:
		var angle := TAU * i / 4.0 + PI * 0.25
		var arm_pos := Vector3(cos(angle), 0, sin(angle)) * 0.3
		var rotor := MeshInstance3D.new()
		var rotor_mesh := BoxMesh.new()
		rotor_mesh.size = Vector3(0.28, 0.01, 0.04)
		rotor_mesh.material = simple_mat(Color(0.2, 0.2, 0.22))
		rotor.mesh = rotor_mesh
		rotor.position = arm_pos + Vector3.UP * 0.08
		rotor.name = "Rotor%d" % i
		root.add_child(rotor)
	return root


func _find_target() -> void:
	_target = Vector3.INF
	var best_d := INF
	var fields: Array[CleanMessField] = messes.duplicate()
	if fields.is_empty() and mess:
		fields.append(mess)
	for field in fields:
		if field == null:
			continue
		var p := field.find_mess_near(global_position, max_target_height, _rng)
		if p.is_finite() and p.distance_squared_to(global_position) < best_d:
			best_d = p.distance_squared_to(global_position)
			_target = p
			_target_mess = field


func _process(delta: float) -> void:
	for r in _rotors:
		r.rotate_y(delta * 40.0)
	model.position.y = sin(Time.get_ticks_msec() * 0.003 + position.x) * 0.05

	if not _target.is_finite():
		_search_timer -= delta
		_beam.visible = false
		if _search_timer <= 0.0:
			_search_timer = 1.0
			_find_target()
		return

	var flat_target := Vector3(_target.x, altitude, _target.z)
	var to_target := flat_target - global_position
	var dist := to_target.length()
	var step := BASE_SPEED * speed_mult * delta
	if dist > 0.05:
		global_position += to_target / dist * minf(step, dist)
		model.rotation.z = lerpf(model.rotation.z, -0.15, delta * 4.0)
	if dist < 0.6:
		# Über dem Ziel: absaugen, bis dort nichts mehr ist
		var below := Vector3(global_position.x, _target.y, global_position.z)
		_beam.visible = true
		var h := altitude - _target.y
		_beam.global_position = below + Vector3.UP * h * 0.5
		_beam.scale = Vector3(1.0, h, 1.0)
		if clean(below, RADIUS, BASE_POWER, delta, _target_mess) == 0:
			_target = Vector3.INF
	else:
		_beam.visible = false
