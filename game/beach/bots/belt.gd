class_name BeachBelt
extends CleanBot
## Förderband am Spülsaum: ein langes Band parallel zum Wasser. Ein Greifarm fährt daran entlang
## und holt, was die Wellen anspülen. Der Müll fährt auf dem Band in einen Container am Ende.
## position vor add_child auf die Bandmitte setzen (daran erkennt das Spiel die Zone).

const BASE_SPEED := 1.4
const BASE_POWER := 4.0
const RADIUS := 0.75
const ITEMS := 26

var belt_from := Vector3.ZERO   # y = Boden; das Band läuft von from nach to
var belt_to := Vector3.ZERO
var reach_dir := Vector3.BACK   # Richtung zum Wasser: dorthin greift der Arm

var _t := 0.0
var _dir := 1.0
var _arm: Node3D
var _items: MultiMesh
var _phase := 0.0
var _rollers: Array[Node3D] = []


func _ready() -> void:
	var length := belt_from.distance_to(belt_to)
	var along := (belt_to - belt_from).normalized()
	var yaw := atan2(-along.z, along.x)
	var frame := simple_mat(Color(0.25, 0.3, 0.33))
	frame.metallic = 0.6
	var rubber := simple_mat(Color(0.08, 0.08, 0.09))
	rubber.roughness = 0.9
	var accent := simple_mat(Color(0.98, 0.55, 0.12))
	var root := Node3D.new()
	root.position = (belt_from + belt_to) * 0.5 - position   # der Roboter selbst steht in der Bandmitte
	root.rotation.y = yaw
	add_child(root)
	_part(root, Vector3(length, 0.06, 0.62), Vector3(0, 0.62, 0), rubber)
	for side: float in [-0.34, 0.34]:
		_part(root, Vector3(length + 0.1, 0.16, 0.05), Vector3(0, 0.6, side), frame)
	var legs := int(length / 1.6) + 1
	for i in legs + 1:
		var x := -length * 0.5 + length * i / legs
		for side: float in [-0.3, 0.3]:
			_part(root, Vector3(0.05, 0.6, 0.05), Vector3(x, 0.3, side), frame)
		_part(root, Vector3(0.05, 0.05, 0.62), Vector3(x, 0.15, 0), frame)
	for i in int(length / 0.5):
		var roller := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 0.6
		cyl.radial_segments = 8
		cyl.material = frame
		roller.mesh = cyl
		roller.rotation.x = PI * 0.5
		roller.position = Vector3(-length * 0.5 + 0.25 + i * 0.5, 0.56, 0)
		root.add_child(roller)
	# Container am Ende
	var bin := Node3D.new()
	bin.position = Vector3(length * 0.5 + 0.75, 0, 0)
	root.add_child(bin)
	_part(bin, Vector3(1.1, 0.85, 1.0), Vector3(0, 0.43, 0), simple_mat(Color(0.12, 0.45, 0.32)))
	_part(bin, Vector3(1.14, 0.06, 1.04), Vector3(0, 0.88, 0), simple_mat(Color(0.08, 0.32, 0.22)))
	_part(bin, Vector3(0.5, 0.2, 0.02), Vector3(0, 0.55, 0.51), simple_mat(Color(0.95, 0.95, 0.9)))
	# Müllteile auf dem Band
	_items = MultiMesh.new()
	_items.transform_format = MultiMesh.TRANSFORM_3D
	_items.use_colors = true
	var piece := BoxMesh.new()
	piece.size = Vector3(0.14, 0.07, 0.1)
	var piece_mat := StandardMaterial3D.new()
	piece_mat.vertex_color_use_as_albedo = true
	piece_mat.roughness = 0.5
	piece.material = piece_mat
	_items.mesh = piece
	_items.instance_count = ITEMS
	var colors := [Color(0.9, 0.2, 0.15), Color(0.2, 0.5, 0.9), Color(0.95, 0.95, 0.9), Color(0.2, 0.7, 0.35), Color(0.95, 0.8, 0.2)]
	for i in ITEMS:
		_items.set_instance_color(i, colors[i % colors.size()])
	var items_node := MultiMeshInstance3D.new()
	items_node.multimesh = _items
	root.add_child(items_node)
	set_meta("length", length)
	# Greifarm: Wagen auf dem Band, Ausleger zum Wasser, Greifer
	_arm = Node3D.new()
	add_child(_arm)
	_part(_arm, Vector3(0.5, 0.3, 0.75), Vector3(0, 0.82, 0), accent)
	var boom_len := 1.9
	var boom := _part(_arm, Vector3(0.1, 0.1, boom_len), Vector3(0, 1.05, 0), frame)
	boom.position = Vector3(0, 1.05, 0) + reach_dir * boom_len * 0.5
	boom.rotation.y = atan2(reach_dir.x, reach_dir.z)
	var claw := _part(_arm, Vector3(0.3, 0.5, 0.3), reach_dir * boom_len + Vector3(0, 0.75, 0), accent)
	claw.name = "Claw"
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.06
	lamp_mesh.height = 0.12
	lamp_mesh.material = simple_mat(Color(0.3, 1.0, 0.4), true)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 1.05, 0)
	_arm.add_child(lamp)
	_t = randf()


func _process(delta: float) -> void:
	var length: float = get_meta("length", 1.0)
	_t += _dir * BASE_SPEED * speed_mult * delta / maxf(length, 0.01)
	if _t >= 1.0 or _t <= 0.0:
		_t = clampf(_t, 0.0, 1.0)
		_dir = -_dir
	var p := belt_from.lerp(belt_to, _t)
	_arm.position = p - position
	var claw: Node3D = _arm.get_node("Claw")
	claw.position.y = 0.55 + absf(sin(Time.get_ticks_msec() * 0.004)) * 0.3
	for k: float in [0.7, 1.4, 2.1]:
		var point := p + reach_dir * k
		point.y = 0.03
		clean(point, RADIUS, BASE_POWER, delta)
		for layer in layers:
			clean(point + Vector3.UP * 0.04, RADIUS, BASE_POWER, delta, layer)
	# Band läuft Richtung Container
	_phase = fmod(_phase + delta * 0.6 * speed_mult, 1.0)
	for i in ITEMS:
		var u := fmod(float(i) / ITEMS + _phase, 1.0)
		var x := -length * 0.5 + u * length
		var basis := Basis(Vector3.UP, float(i) * 1.7)
		var s := 1.0 if u < 0.97 else (1.0 - u) / 0.03
		_items.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * s), Vector3(x, 0.69, sin(i * 3.1) * 0.15)))


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	m.mesh = box
	m.position = pos
	parent.add_child(m)
	return m
