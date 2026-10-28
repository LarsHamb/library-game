// Holz für Möbel und Regale: Maserung läuft auf liegenden Flächen entlang x, auf stehenden nach oben.
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 wood_light : source_color = vec3(0.42, 0.25, 0.13);
uniform vec3 wood_dark : source_color = vec3(0.22, 0.12, 0.06);
uniform float roughness_base = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;   // x = quer zur Maserung, y = entlang der Maserung
	if (n.y > 0.5) {
		uv = vec2(world_pos.z, world_pos.x);
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, world_pos.y);
	} else {
		uv = vec2(world_pos.x, world_pos.y);
	}
	float grain = cc_fbm(vec2(uv.x * 38.0, uv.y * 2.2));
	float rings = 0.5 + 0.5 * sin(uv.x * 70.0 + cc_fbm(vec2(uv.x * 4.0, uv.y * 1.2)) * 10.0);
	float t = clamp(grain * 0.7 + rings * 0.3, 0.0, 1.0);
	ALBEDO = mix(wood_dark, wood_light, t);
	ROUGHNESS = roughness_base + (grain - 0.5) * 0.2;
}
