class_name CleanBot
extends Node3D
## Grundlage für alles, was von selbst putzt. Unterklassen bewegen sich und rufen clean() auf.
## Tempo und Putzkraft kommen aus den Werten "bot_speed" und "bot_power" (Upgrades).

var mess: CleanMessField
var layers: Array[CleanMessField] = []   # weitere Schichten der Zone, die Roboter putzen dürfen (z.B. Bücher)
var speed_mult := 1.0
var power_mult := 1.0
var model: Node3D


## Modell setzen, bevor der Roboter in die Szene kommt. Ohne Modell baut die Unterklasse ein einfaches.
func set_model(p_model: Node3D) -> void:
	model = p_model


func clean(point: Vector3, radius: float, power_per_second: float, delta: float, field: CleanMessField = null) -> int:
	if field == null:
		field = mess
	if field == null:
		return 0
	return field.clean_at(point, radius, power_per_second * power_mult * delta)


static func simple_mat(color: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	return m
