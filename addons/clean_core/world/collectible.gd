class_name CleanCollectible
extends Node3D
## Ein Sammelobjekt, das irgendwo unter dem Schmutz liegt.
## Man sieht es erst, wenn man darüber putzt. Bis dahin verraten es nur kleine Glitzer-Funken.
## Das Modell liefert das Spiel (set_model), sonst gibt es einen goldenen Würfel.

var def: CleanCollectibleDef
var found := false
var _model: Node3D

var _beam: MeshInstance3D


func _ready() -> void:
	if _model == null:
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.3)
		box.material = mat
		cube.mesh = box
		set_model(cube)

	# Glitzern: alle paar Sekunden ein paar goldene Funken
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 3
	sparkle.lifetime = 2.5
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.12
	sparkle.direction = Vector3.UP
	sparkle.spread = 20.0
	sparkle.initial_velocity_min = 0.05
	sparkle.initial_velocity_max = 0.15
	sparkle.gravity = Vector3.ZERO
	sparkle.color = Color(1.0, 0.85, 0.35, 0.9)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = smat
	sparkle.mesh = mesh
	sparkle.name = "Sparkle"
	add_child(sparkle)

	# Lichtsäule fürs Staub-Radar
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.12
	cyl.height = 6.0
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.8, 0.3, 0.35)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cyl.material = bmat
	_beam.mesh = cyl
	_beam.position.y = 3.0
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


## Modell des Objekts (Ursprung = Unterseite). Ist bis zum Finden unsichtbar.
func set_model(model: Node3D) -> void:
	_model = model
	_model.visible = false
	add_child(_model)


func show_beam(on: bool) -> void:
	_beam.visible = on and not found


## Objekt taucht auf, schwebt drehend hoch und verschwindet.
func reveal() -> void:
	found = true
	_beam.visible = false
	get_node("Sparkle").emitting = false
	_model.visible = true
	var tween := create_tween()
	tween.tween_property(_model, "position:y", 1.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_model, "rotation:y", _model.rotation.y + TAU * 2.0, 1.2)
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)
