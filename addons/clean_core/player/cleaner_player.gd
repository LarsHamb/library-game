class_name CleanPlayer
extends CharacterBody3D
## Spielfigur in Ego-Perspektive mit wechselbaren Putzwerkzeugen.
## Linke Maustaste gedrückt halten = putzen. Der Ring zeigt, wo und wie breit geputzt wird.
## An Leitern (CleanLadder): nach vorne laufen = hochklettern, rückwärts = runter, Leertaste = abspringen.
## Werkzeuge: Zifferntasten oder Mausrad.

signal swept(point: Vector3, radius: float)   # jedes Bild, in dem geputzt wird (für Sammelobjekte)
signal tool_changed(tool: CleanTool)

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CLIMB_SPEED := 2.2
const JUMP_VELOCITY := 4.2
const EYE_HEIGHT := 1.65
const TOOL_POS := Vector3(0.32, -0.3, -0.5)

var mess_field: CleanMessField
var mouse_sensitivity := 0.0025
var tool: CleanTool
var clean_radius := 0.45
var clean_power := 6.0      # Schmutzmenge pro Sekunde in der Ringmitte
var reach := 3.2
var speed_mult := 1.0
var cleaning_mess := false  # wird gerade wirklich Schmutz erwischt? (für Geräusch)

var _tools: Array[CleanTool] = []
var _unlocked := {}         # Werkzeug-ID -> true
var _visuals := {}          # Werkzeug-ID -> Node3D
var _rest := {}             # Werkzeug-ID -> Ruhe-Drehung
var _base_radius := 0.45
var _base_power := 6.0
var _base_reach := 3.2
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _ring: MeshInstance3D
var _puff: CPUParticles3D
var _cleaning := false
var _swing_time := 0.0
var _bob_time := 0.0
var _puff_timer := 0.0
var _ladders: Array[CleanLadder] = []   # Leitern, an denen man gerade steht


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
	_ray.add_exception(self)
	_camera.add_child(_ray)

	_build_ring()
	_build_puff()


## Werkzeug anmelden. visual ist das Modell in der Hand (Ursprung = Griff), es wird an die Kamera gehängt.
func add_tool(def: CleanTool, visual: Node3D) -> void:
	_tools.append(def)
	_visuals[def.id] = visual
	_rest[def.id] = visual.rotation
	visual.position = TOOL_POS
	visual.visible = false
	_camera.add_child(visual)
	if tool == null:
		tool = def
		_apply_tool()


func set_unlocked(def: CleanTool, unlocked: bool) -> void:
	_unlocked[def.id] = unlocked


func is_unlocked(def: CleanTool) -> bool:
	return _unlocked.get(def.id, def.unlocked_from_start)


## Grundwerte vom Spielstand (Upgrades, Sammelobjekte). Das Werkzeug rechnet seine Faktoren drauf.
func set_stats(radius: float, power: float, tool_reach: float, speed: float) -> void:
	_base_radius = radius
	_base_power = power
	_base_reach = tool_reach
	speed_mult = speed
	_apply_tool()


func select_tool(def: CleanTool) -> void:
	if def == null or def == tool or not is_unlocked(def):
		return
	tool = def
	_apply_tool()
	tool_changed.emit(tool)


func select_tool_by_id(id: String) -> void:
	for t in _tools:
		if t.id == id:
			select_tool(t)


## Nächstes freigeschaltetes Werkzeug (Mausrad).
func cycle_tool(step: int) -> void:
	if _tools.is_empty():
		return
	var i := _tools.find(tool)
	for n in _tools.size():
		i = posmod(i + step, _tools.size())
		if is_unlocked(_tools[i]):
			select_tool(_tools[i])
			return


## Größe des Werkzeugkopfs, z.B. mit jeder Upgrade-Stufe größer. Sucht einen Kindknoten namens "Head".
func set_tool_scale(id: String, s: float) -> void:
	var visual: Node3D = _visuals.get(id)
	if visual and visual.has_node("Head"):
		var head: Node3D = visual.get_node("Head")
		head.scale = Vector3(s, s * 1.5, s)


func is_cleaning_held() -> bool:
	return _cleaning


func enter_ladder(ladder: CleanLadder) -> void:
	_ladders.append(ladder)


func exit_ladder(ladder: CleanLadder) -> void:
	_ladders.erase(ladder)


func is_climbing() -> bool:
	return not _ladders.is_empty()


func _apply_tool() -> void:
	if tool == null:
		return
	clean_radius = _base_radius * tool.radius_mult
	clean_power = _base_power * tool.power_mult
	reach = _base_reach * tool.reach_mult
	if _ray:
		_ray.target_position = Vector3(0, 0, -reach)
	if _puff:
		_puff.emission_sphere_radius = clean_radius * 0.6
	for id: String in _visuals:
		var visual: Node3D = _visuals[id]
		visual.visible = id == tool.id


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
		if button == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(-1)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(1)
	else:
		for t in _tools:
			if event.is_action_pressed("tool_%d" % t.hotkey):
				select_tool(t)


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
	var ladder: CleanLadder = _ladders.back()
	var forward := -global_basis.z
	if Input.is_action_just_pressed("jump"):
		# Abspringen: weg von der Leiter
		_ladders.clear()
		velocity = ladder.facing * 3.0 + Vector3.UP * 2.0
		return
	var climb := 0.0
	if input.y < -0.1 and forward.dot(-ladder.facing) > 0.2:
		climb = 1.0
	elif input.y > 0.1:
		climb = -1.0
	velocity.y = climb * CLIMB_SPEED * speed_mult
	if global_position.y >= ladder.max_feet_height and velocity.y > 0.0:
		velocity.y = 0.0


func _process(delta: float) -> void:
	if tool:
		_animate_tool(delta)

	# Leichtes Kopfwippen beim Laufen, feines Zittern beim Putzen
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector2.ZERO
	if is_on_floor() and ground_speed > 0.5:
		_bob_time += delta * ground_speed * 2.4
		bob = Vector2(cos(_bob_time * 0.5) * 0.02, sin(_bob_time) * 0.035)
	if cleaning_mess:
		bob += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.004
	_camera.h_offset = lerpf(_camera.h_offset, bob.x, minf(1.0, delta * 12.0))
	_camera.v_offset = lerpf(_camera.v_offset, bob.y, minf(1.0, delta * 12.0))


func _animate_tool(delta: float) -> void:
	var visual: Node3D = _visuals[tool.id]
	var rest: Vector3 = _rest[tool.id]
	if _cleaning and tool.style == CleanTool.Style.SUCK:
		# Sauger brummt: kleines Zittern statt Schwingen
		visual.position = TOOL_POS + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	elif _cleaning:
		_swing_time += delta * 16.0
		visual.rotation = rest + Vector3(sin(_swing_time * 0.5) * 0.2, 0.0, sin(_swing_time) * 0.45)
		visual.position = TOOL_POS + Vector3(sin(_swing_time) * 0.04, absf(cos(_swing_time)) * 0.02, 0.0)
	else:
		visual.rotation = visual.rotation.lerp(rest, minf(1.0, delta * 10.0))
		visual.position = visual.position.lerp(TOOL_POS, minf(1.0, delta * 10.0))


func _update_cleaning(delta: float) -> void:
	_cleaning = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("clean")
	cleaning_mess = false
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
	if _cleaning and mess_field and mess_field.clean_at(point, clean_radius, clean_power * delta) > 0:
		cleaning_mess = true
		_puff.global_position = point
		_puff_timer = 0.15
		if tool.style == CleanTool.Style.SUCK:
			# Schmutz fliegt zur Düse statt hoch
			var to_me := (_camera.global_position - point).normalized()
			_puff.direction = to_me
			_puff.gravity = to_me * 9.0
		else:
			_puff.direction = Vector3.UP
			_puff.gravity = Vector3(0, -0.4, 0)
	_puff.emitting = _puff_timer > 0.0


static func _basis_from_normal(n: Vector3) -> Basis:
	var helper := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := n.cross(helper).normalized()
	var z := x.cross(n).normalized()
	return Basis(x, n, z)


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


## Partikelfarbe passend zum Schmutz (Staub grau, Sand gelb ...).
func set_particle_color(color: Color) -> void:
	_puff.color = color


## Kleines, immer zur Kamera gedrehtes Viereck für Partikel.
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
