class_name BeachSifter
extends CleanBot
## Siebmaschine: kleiner Traktor, der eine Bahn am Strand hin und her fährt.
## Hinter ihm dreht sich eine Siebtrommel, die allen Müll aus dem Sand holt.
## Das Modell kommt vom Spiel (Kindknoten "Wheel*" und "Drum" drehen sich).

const BASE_SPEED := 1.1      # m/s
const BASE_POWER := 5.0
const RADIUS := 0.85
const SIEVE_BACK := 1.0      # so weit hinter der Mitte liegt die Trommel
const TURN_TIME := 1.6

var lane_from := Vector3.ZERO
var lane_to := Vector3.ZERO

var _t := 0.0
var _dir := 1.0
var _turning := 0.0
var _trail: CPUParticles3D


func _ready() -> void:
	if model == null:
		model = Node3D.new()
	add_child(model)
	_t = randf()
	_dir = 1.0 if randf() < 0.5 else -1.0
	_trail = CPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 1.0
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_trail.emission_box_extents = Vector3(0.5, 0.05, 0.1)
	_trail.direction = Vector3.UP
	_trail.spread = 35.0
	_trail.initial_velocity_min = 0.4
	_trail.initial_velocity_max = 1.0
	_trail.gravity = Vector3(0, -3.0, 0)
	_trail.color = Color(0.93, 0.83, 0.64, 0.8)
	_trail.mesh = CleanPlayer.make_particle_quad(0.05)
	_trail.position = Vector3(0, 0.25, SIEVE_BACK + 0.3)
	add_child(_trail)
	_place()


func _process(delta: float) -> void:
	var length := maxf(0.01, lane_from.distance_to(lane_to))
	var speed := BASE_SPEED * speed_mult
	if _turning > 0.0:
		_turning -= delta * speed_mult
		var k := clampf(1.0 - _turning / TURN_TIME, 0.0, 1.0)
		var old_dir := (lane_to - lane_from).normalized() * -_dir   # _dir zeigt schon in die neue Richtung
		var yaw_old := atan2(-old_dir.x, -old_dir.z)
		rotation.y = yaw_old + PI * k * k * (3.0 - 2.0 * k)
		_trail.emitting = false
		return
	_t += _dir * speed * delta / length
	if _t >= 1.0 or _t <= 0.0:
		_t = clampf(_t, 0.0, 1.0)
		_dir = -_dir
		_turning = TURN_TIME
	_place()
	_trail.emitting = true
	var sieve := global_position + global_basis.z * SIEVE_BACK
	sieve.y = 0.02
	clean(sieve, RADIUS, BASE_POWER, delta)
	for layer in layers:
		clean(sieve + Vector3.UP * 0.04, RADIUS, BASE_POWER, delta, layer)
	for child in model.get_children():
		if child.name.begins_with("Wheel"):
			(child as Node3D).rotate_object_local(Vector3.RIGHT, -delta * speed * 3.2)
		elif child.name.begins_with("Drum"):
			(child as Node3D).rotate_object_local(Vector3.RIGHT, delta * 5.0)


func _place() -> void:
	position = lane_from.lerp(lane_to, _t)
	var along := (lane_to - lane_from).normalized() * _dir
	rotation.y = atan2(-along.x, -along.z)   # Modell schaut nach -z
