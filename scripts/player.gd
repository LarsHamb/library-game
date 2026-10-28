extends CharacterBody3D
## Spielfigur in Ego-Perspektive mit Staubwedel.
## Linke Maustaste gedrückt halten = wedeln. Der Ring zeigt, wo und wie breit gewedelt wird.
## An Leitern: nach vorne laufen = hochklettern, rückwärts = runter, Leertaste = abspringen.
## Zwei Werkzeuge: Staubwedel (breit) und Staubsauger (schmal, stark, weit). Wechsel mit 1/2 oder Mausrad.

signal swept(point: Vector3, radius: float)   # jedes Bild, in dem geputzt wird (für versteckte Bücher)
signal tool_changed(tool: int)

enum Tool { DUSTER, VACUUM }

const DustField := preload("res://scripts/dust_field.gd")

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CLIMB_SPEED := 2.2
const JUMP_VELOCITY := 4.2
const EYE_HEIGHT := 1.65
const DUSTER_REST := Vector3(-1.22, 0.0, -0.21)   # Wedel zeigt schräg nach vorne oben
const DUSTER_POS := Vector3(0.32, -0.3, -0.5)

var dust_field: DustField
var mouse_sensitivity := 0.0025
var tool := Tool.DUSTER
var vacuum_unlocked := false
var clean_radius := 0.45
var clean_power := 6.0      # Staubmenge pro Sekunde in der Ringmitte
var reach := 3.2
var speed_mult := 1.0
var cleaning_dust := false  # wird gerade wirklich Staub erwischt? (für Geräusch)

# Werte des Wedels; der Staubsauger leitet seine davon ab
var _base_radius := 0.45
var _base_power := 6.0
var _base_reach := 3.2

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _ring: MeshInstance3D
var _puff: CPUParticles3D
var _duster: Node3D
var _duster_head: MeshInstance3D
var _vacuum: Node3D
var _cleaning := false
var _swing_time := 0.0
var _bob_time := 0.0
var _puff_timer := 0.0
var _ladders: Array[Dictionary] = []   # Leitern, an denen man gerade steht


func _ready() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)

	_head = Node3D.new()
	_head.position.y = EYE_HEIGHT
	add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.05
	_head.add_child(_camera)
	_camera.make_current()

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -reach)
	_ray.add_exception(self)
	_camera.add_child(_ray)

	_build_duster()
	_build_vacuum()
	_build_ring()
	_build_puff()
	_apply_tool()


## Werte vom Spielstand (Upgrades, Bücher). Gelten für den Wedel, der Sauger rechnet um.
func set_stats(radius: float, power: float, tool_reach: float, speed: float) -> void:
	_base_radius = radius
	_base_power = power
	_base_reach = tool_reach
	speed_mult = speed
	_apply_tool()


func select_tool(new_tool: Tool) -> void:
	if new_tool == Tool.VACUUM and not vacuum_unlocked:
		return
	if new_tool == tool:
		return
	tool = new_tool
	_apply_tool()
	tool_changed.emit(tool)


func is_cleaning_held() -> bool:
	return _cleaning


func _apply_tool() -> void:
	if tool == Tool.VACUUM:
		clean_radius = _base_radius * 0.6
		clean_power = _base_power * 3.0
		reach = _base_reach * 1.4
	else:
		clean_radius = _base_radius
		clean_power = _base_power
		reach = _base_reach
	if _ray:
		_ray.target_position = Vector3(0, 0, -reach)
	if _puff:
		_puff.emission_sphere_radius = clean_radius * 0.6
	if _duster:
		_duster.visible = tool == Tool.DUSTER
		_vacuum.visible = tool == Tool.VACUUM


## Der Wedel-Kopf wird mit jeder Upgrade-Stufe sichtbar größer.
func set_tool_level(level: int) -> void:
	var s := 1.0 + level * 0.15
	_duster_head.scale = Vector3(s, s * 1.5, s)


## Wird von der Leiter aufgerufen. {"facing": zeigt vom Regal weg, "top": höchste Fußhöhe}
func enter_ladder(ladder: Dictionary) -> void:
	_ladders.append(ladder)


func exit_ladder(ladder: Dictionary) -> void:
	_ladders.erase(ladder)


func is_climbing() -> bool:
	return not _ladders.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_head.rotate_x(-motion.relative.y * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x, -1.45, 1.45)
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN:
			select_tool(Tool.VACUUM if tool == Tool.DUSTER else Tool.DUSTER)
	elif event.is_action_pressed("tool_1"):
		select_tool(Tool.DUSTER)
	elif event.is_action_pressed("tool_2"):
		select_tool(Tool.VACUUM)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED) * speed_mult

	if is_climbing():
		_climb(input)
		speed = WALK_SPEED * 0.5 * speed_mult
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()

	_update_cleaning(delta)


func _climb(input: Vector2) -> void:
	var ladder: Dictionary = _ladders.back()
	var facing: Vector3 = ladder["facing"]
	var top: float = ladder["top"]
	var forward := -global_basis.z
	if Input.is_action_just_pressed("jump"):
		# Abspringen: weg von der Leiter
		_ladders.clear()
		velocity = facing * 3.0 + Vector3.UP * 2.0
		return
	var climb := 0.0
	if input.y < -0.1 and forward.dot(-facing) > 0.2:
		climb = 1.0
	elif input.y > 0.1:
		climb = -1.0
	velocity.y = climb * CLIMB_SPEED * speed_mult
	if global_position.y >= top and velocity.y > 0.0:
		velocity.y = 0.0


func _process(delta: float) -> void:
	# Wedel schwingt beim Putzen hin und her, sonst ruht er.
	if _cleaning and tool == Tool.VACUUM:
		# Sauger brummt: kleines Zittern statt Schwingen
		_vacuum.position = Vector3(0.28, -0.32, -0.45) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	elif _cleaning:
		_swing_time += delta * 16.0
		_duster.rotation = DUSTER_REST + Vector3(sin(_swing_time * 0.5) * 0.2, 0.0, sin(_swing_time) * 0.45)
		_duster.position = DUSTER_POS + Vector3(sin(_swing_time) * 0.04, absf(cos(_swing_time)) * 0.02, 0.0)
	else:
		_duster.rotation = _duster.rotation.lerp(DUSTER_REST, minf(1.0, delta * 10.0))
		_duster.position = _duster.position.lerp(DUSTER_POS, minf(1.0, delta * 10.0))

	# Leichtes Kopfwippen beim Laufen, feines Zittern beim Putzen
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector2.ZERO
	if is_on_floor() and ground_speed > 0.5:
		_bob_time += delta * ground_speed * 2.4
		bob = Vector2(cos(_bob_time * 0.5) * 0.02, sin(_bob_time) * 0.035)
	if cleaning_dust:
		bob += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.004
	_camera.h_offset = lerpf(_camera.h_offset, bob.x, minf(1.0, delta * 12.0))
	_camera.v_offset = lerpf(_camera.v_offset, bob.y, minf(1.0, delta * 12.0))


func _update_cleaning(delta: float) -> void:
	_cleaning = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("clean")
	cleaning_dust = false
	_puff_timer -= delta

	if not _ray.is_colliding():
		_ring.visible = false
		_puff.emitting = _puff_timer > 0.0
		return

	var point := _ray.get_collision_point()
	var normal := _ray.get_collision_normal()
	_ring.visible = true
	_ring.global_transform = Transform3D(_basis_from_normal(normal).scaled(Vector3.ONE * clean_radius), point + normal * 0.03)

	if _cleaning:
		swept.emit(point, clean_radius)
	if _cleaning and dust_field and dust_field.clean_at(point, clean_radius, clean_power * delta) > 0:
		cleaning_dust = true
		_puff.global_position = point
		_puff_timer = 0.15
		if tool == Tool.VACUUM:
			# Staub fliegt zur Düse statt hoch
			var to_me := (_camera.global_position - point).normalized()
			_puff.direction = to_me
			_puff.gravity = to_me * 9.0
			_puff.color = Color(0.6, 0.56, 0.5, 0.7)
		else:
			_puff.direction = Vector3.UP
			_puff.gravity = Vector3(0, -0.4, 0)
			_puff.color = Color(0.78, 0.73, 0.65, 0.6)
	_puff.emitting = _puff_timer > 0.0


static func _basis_from_normal(n: Vector3) -> Basis:
	var helper := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := n.cross(helper).normalized()
	var z := x.cross(n).normalized()
	return Basis(x, n, z)


func _build_duster() -> void:
	_duster = Node3D.new()
	_duster.position = DUSTER_POS
	_duster.rotation = DUSTER_REST
	_camera.add_child(_duster)

	var handle := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.016
	stick.height = 0.42
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.15)
	stick.material = wood
	handle.mesh = stick
	_duster.add_child(handle)

	_duster_head = MeshInstance3D.new()
	var fluff := SphereMesh.new()
	fluff.radius = 0.07
	fluff.height = 0.14
	var feathers := StandardMaterial3D.new()
	feathers.albedo_color = Color(0.93, 0.62, 0.72)
	feathers.roughness = 1.0
	fluff.material = feathers
	_duster_head.mesh = fluff
	_duster_head.position.y = 0.28
	_duster.add_child(_duster_head)
	set_tool_level(0)


func _build_vacuum() -> void:
	_vacuum = Node3D.new()
	_vacuum.position = Vector3(0.28, -0.32, -0.45)
	_vacuum.rotation = Vector3(-1.35, 0.0, -0.1)
	_vacuum.visible = false
	_camera.add_child(_vacuum)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.15, 0.12)
	red.metallic = 0.3
	red.roughness = 0.4
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.7, 0.72)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06
	body_mesh.height = 0.22
	body_mesh.material = red
	body.mesh = body_mesh
	_vacuum.add_child(body)
	var tube := MeshInstance3D.new()
	var tube_mesh := CylinderMesh.new()
	tube_mesh.top_radius = 0.018
	tube_mesh.bottom_radius = 0.018
	tube_mesh.height = 0.4
	tube_mesh.material = steel
	tube.mesh = tube_mesh
	tube.position.y = 0.3
	_vacuum.add_child(tube)
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := BoxMesh.new()
	nozzle_mesh.size = Vector3(0.12, 0.03, 0.05)
	nozzle_mesh.material = red
	nozzle.mesh = nozzle_mesh
	nozzle.position.y = 0.51
	_vacuum.add_child(nozzle)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.top_level = true
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.7, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = mat
	_ring.mesh = torus
	add_child(_ring)


func _build_puff() -> void:
	_puff = CPUParticles3D.new()
	_puff.top_level = true
	_puff.emitting = false
	_puff.amount = 60
	_puff.lifetime = 0.9
	_puff.local_coords = false
	_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puff.direction = Vector3.UP
	_puff.spread = 70.0
	_puff.initial_velocity_min = 0.3
	_puff.initial_velocity_max = 1.0
	_puff.gravity = Vector3(0, -0.4, 0)
	_puff.damping_min = 0.5
	_puff.damping_max = 1.0
	_puff.scale_amount_min = 0.6
	_puff.scale_amount_max = 1.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	_puff.scale_amount_curve = shrink
	_puff.color = Color(0.78, 0.73, 0.65, 0.6)
	_puff.mesh = make_particle_quad(0.07)
	add_child(_puff)


## Kleines, immer zur Kamera gedrehtes Viereck für Staubpartikel.
static func make_particle_quad(size: float) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad
