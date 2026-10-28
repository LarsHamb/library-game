// Marmor mit feinen Adern.
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.93, 0.91, 0.87);
uniform vec3 vein_color : source_color = vec3(0.55, 0.52, 0.5);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 1.5 + world_pos.y * 0.8;
	float turb = cc_fbm(p * 2.0);
	float vein = pow(1.0 - abs(sin((p.x + p.y) * 3.0 + turb * 9.0)), 12.0);
	ALBEDO = mix(base_color, vein_color, vein * 0.8) * mix(0.95, 1.03, cc_noise(p * 20.0));
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
}
