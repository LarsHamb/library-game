class_name CleanRailBot
extends CleanBot
## Fährt auf einer Schiene hin und her und putzt dabei auf mehreren Höhen gleichzeitig
## (z.B. alle Böden eines Regals). Wie eine kleine Waschanlage auf Rädern.

const BASE_SPEED := 0.5      # m/s
const BASE_POWER := 2.5      # Schmutz pro Sekunde in der Mitte
const RADIUS := 0.35

var rail_from := Vector3.ZERO   # Putzlinie (z.B. Mitte des Staubstreifens), y = Boden
var rail_to := Vector3.ZERO
var heights: Array[float] = []  # Putzhöhen
var facing := Vector3.BACK      # Richtung, in der der Roboter vor der Putzlinie steht
var stand_off := 0.35           # Abstand des Wagens von der Putzlinie

var _t := 0.0
var _dir := 1.0
var _carriage: Node3D


func _ready() -> void:
	var length := rail_from.distance_to(rail_to)
	var along := (rail_to - rail_from).normalized()
	var offset := facing * stand_off

	# Schiene am Boden
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(length + 0.3, 0.03, 0.06)
	rail_mesh.material = simple_mat(Color(0.35, 0.35, 0.38))
	rail.mesh = rail_mesh
	rail.position = (rail_from + rail_to) * 0.5 + offset + Vector3.UP * 0.015
	rail.rotation.y = atan2(-along.z, along.x)
	add_child(rail)

	_carriage = Node3D.new()
	_carriage.rotation.y = atan2(facing.x, facing.z)   # Bürsten (lokal -z) zeigen zum Regal
	add_child(_carriage)
	if model == null:
		model = _default_model()
	_carriage.add_child(model)
	_t = randf()


func _default_model() -> Node3D:
	var root := Node3D.new()
	var top := 0.0
	for h in heights:
		top = maxf(top, h)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.35, 0.15, 0.25)
	base_mesh.material = simple_mat(Color(0.85, 0.6, 0.15))
	base.mesh = base_mesh
	base.position.y = 0.1
	root.add_child(base)
	var mast := MeshInstance3D.new()
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.06, top + 0.3, 0.06)
	mast_mesh.material = simple_mat(Color(0.3, 0.3, 0.32))
	mast.mesh = mast_mesh
	mast.position.y = (top + 0.3) * 0.5
	root.add_child(mast)
	for h in heights:
		var brush := MeshInstance3D.new()
		var brush_mesh := CylinderMesh.new()
		brush_mesh.top_radius = 0.05
		brush_mesh.bottom_radius = 0.05
		brush_mesh.height = 0.3
		brush_mesh.material = simple_mat(Color(0.2, 0.6, 0.9))
		brush.mesh = brush_mesh
		brush.rotation.x = PI * 0.5
		brush.position = Vector3(0, h + 0.08, -0.15)
		brush.name = "Brush"
		root.add_child(brush)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.05
	lamp_mesh.height = 0.1
	lamp_mesh.material = simple_mat(Color(0.3, 1.0, 0.4), true)
	lamp.mesh = lamp_mesh
	lamp.position.y = top + 0.35
	root.add_child(lamp)
	return root


func _process(delta: float) -> void:
	var length := maxf(0.01, rail_from.distance_to(rail_to))
	_t += _dir * BASE_SPEED * speed_mult * delta / length
	if _t >= 1.0:
		_t = 1.0
		_dir = -1.0
	elif _t <= 0.0:
		_t = 0.0
		_dir = 1.0
	var point := rail_from.lerp(rail_to, _t)
	_carriage.position = point + facing * stand_off
	for h in heights:
		clean(Vector3(point.x, h, point.z), RADIUS, BASE_POWER, delta)
	# Bürsten drehen sich
	for child in model.get_children():
		if child.name.begins_with("Brush"):
			(child as Node3D).rotate_object_local(Vector3.UP, delta * 12.0)
