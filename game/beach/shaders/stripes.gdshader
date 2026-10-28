// Stoff mit Streifen (Strandkörbe, Sonnenschirme, Rettungsturm, Leuchtturm).
// radial = false: waagrechte Streifen entlang der lokalen y-Achse; true: Streifen rund um die y-Achse (Schirm).
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.95, 0.95, 0.92);
uniform vec3 color_b : source_color = vec3(0.15, 0.35, 0.75);
uniform float count = 6.0;      // Streifen pro Meter (bzw. pro Umdrehung bei radial)
uniform bool radial = false;
uniform float roughness = 0.8;
uniform float weave = 0.0;      // > 0: Korbgeflecht statt glattem Stoff

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float s = radial ? (atan(lp.z, lp.x) / 6.28318 + 0.5) * count : lp.y * count;
	vec3 col = mix(color_a, color_b, step(0.5, fract(s)));
	if (weave > 0.0) {
		vec2 w = vec2(lp.x + lp.z, lp.y) * weave;
		float a = step(0.5, fract(w.x)) == step(0.5, fract(w.y)) ? 1.0 : 0.0;
		float ridge = sin(fract(a > 0.5 ? w.x : w.y) * 3.14159);
		col = mix(color_a * 0.55, color_a, ridge);
	}
	col *= 0.92 + 0.12 * cc_noise(lp.xy * 30.0 + lp.z * 13.0);
	ALBEDO = col;
	ROUGHNESS = roughness;
}
