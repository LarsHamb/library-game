// Strandhafer und Palmwedel: Blattform per Alpha, wiegt sich im Wind (je höher, desto mehr).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.45, 0.55, 0.25);
uniform vec3 tip_color : source_color = vec3(0.82, 0.78, 0.5);
uniform float sway = 0.12;
uniform bool frond = false;    // Palmwedel: Fiederblätter statt Grashalm

varying float height_k;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = frond ? UV.x : (1.0 - UV.y);
	height_k = k;
	float t = TIME * 1.6 + w.x * 0.35 + w.z * 0.2;
	VERTEX.x += sin(t) * sway * k * k;
	VERTEX.z += cos(t * 0.8) * sway * 0.5 * k * k;
}

void fragment() {
	float alpha = 1.0;
	if (frond) {
		// Fiedern links und rechts der Mittelrippe, zur Spitze kürzer
		float across = abs(UV.y - 0.5) * 2.0;
		float leaflet = fract(UV.x * 28.0);
		float width = (1.0 - UV.x * 0.7) * (0.65 + 0.35 * sin(leaflet * 3.14159));
		alpha = (across < 0.08 || (across < width && leaflet > 0.18)) ? 1.0 : 0.0;
	}
	if (alpha < 0.5) {
		discard;
	}
	vec3 col = mix(base_color, tip_color, height_k * 0.8);
	col *= 0.85 + 0.25 * cc_noise(UV * vec2(40.0, 4.0));
	ALBEDO = col;
	ROUGHNESS = 0.7;
	BACKLIGHT = vec3(0.35, 0.4, 0.15);
}
