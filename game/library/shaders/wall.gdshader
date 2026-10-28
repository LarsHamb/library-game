// Wand: unten dunkle Holzvertäfelung mit Feldern, darüber ein Zierband und Putz.
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 plaster : source_color = vec3(0.62, 0.52, 0.40);
uniform vec3 panel_wood : source_color = vec3(0.24, 0.13, 0.07);
uniform float wainscot_height = 1.3;
uniform float panel_width = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	float y = world_pos.y;
	vec3 c;
	float rough;
	if (y < wainscot_height) {
		float grain = cc_fbm(vec2(u * 30.0, y * 3.0));
		c = panel_wood * mix(0.8, 1.2, grain);
		// Felder: heller Rahmen, vertiefte Füllung
		float fu = fract(u / panel_width);
		float fy = y / wainscot_height;
		float inset = step(0.08, fu) * step(fu, 0.92) * step(0.15, fy) * step(fy, 0.85);
		c *= mix(1.15, 0.85, inset);
		rough = 0.45;
	} else if (y < wainscot_height + 0.12) {
		c = panel_wood * 1.3;   // Zierleiste
		rough = 0.35;
	} else {
		float n = cc_fbm(vec2(u, y) * 3.0);
		float fine = cc_noise(vec2(u, y) * 60.0);
		c = plaster * mix(0.85, 1.05, n) * mix(0.95, 1.02, fine);
		rough = 0.95;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
}
