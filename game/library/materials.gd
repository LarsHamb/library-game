extends RefCounted
## Alle Materialien der Bibliothek. Holz, Wände, Boden und Marmor sind prozedurale Shader
## (game/library/shaders), es werden keine Texturdateien gebraucht.

const PARQUET := preload("res://game/library/shaders/parquet.gdshader")
const WOOD := preload("res://game/library/shaders/wood.gdshader")
const WALL := preload("res://game/library/shaders/wall.gdshader")
const MARBLE := preload("res://game/library/shaders/marble.gdshader")
const BOOK := preload("res://game/library/shaders/book.gdshader")


static func make(key: String) -> Material:
	match key:
		"floor":
			return _shader(PARQUET, {})
		"floor_archive":
			return _shader(PARQUET, {"wood_light": Color(0.36, 0.24, 0.15), "wood_dark": Color(0.18, 0.11, 0.06), "plank_width": 0.15})
		"floor_dome":
			return _shader(MARBLE, {"base_color": Color(0.86, 0.82, 0.74), "vein_color": Color(0.6, 0.5, 0.4)})
		"wall":
			return _shader(WALL, {})
		"archive_wall":
			return _shader(WALL, {"plaster": Color(0.46, 0.42, 0.37), "panel_wood": Color(0.17, 0.1, 0.05)})
		"dome_wall":
			return _shader(WALL, {"plaster": Color(0.82, 0.76, 0.66), "panel_wood": Color(0.33, 0.2, 0.1), "wainscot_height": 1.6})
		"ceiling":
			return _shader(WOOD, {"wood_light": Color(0.24, 0.14, 0.07), "wood_dark": Color(0.11, 0.06, 0.03)})
		"shelf":
			return _shader(WOOD, {"wood_light": Color(0.42, 0.25, 0.12), "wood_dark": Color(0.2, 0.11, 0.05), "roughness_base": 0.5})
		"table":
			return _shader(WOOD, {"wood_light": Color(0.48, 0.29, 0.14), "wood_dark": Color(0.25, 0.14, 0.06), "roughness_base": 0.3})
		"cabinet":
			return _shader(WOOD, {"wood_light": Color(0.36, 0.2, 0.1), "wood_dark": Color(0.17, 0.09, 0.04), "roughness_base": 0.4})
		"door":
			return _shader(WOOD, {"wood_light": Color(0.33, 0.18, 0.09), "wood_dark": Color(0.16, 0.08, 0.04), "roughness_base": 0.45})
		"marble":
			return _shader(MARBLE, {})
		"book":
			return _shader(BOOK, {})
	return null


## Einfache Metall-Materialien (Messing, Stahl ...).
static func metal(color: Color, roughness := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.9
	m.roughness = roughness
	return m


## Leuchtendes Material (Lampenschirme, Fenster).
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _shader(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m
