// Verwittertes Holz (Planken, Pfähle, Treibholz): Maserung entlang der lokalen y- oder x-Achse, ausgebleicht.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 light_wood : source_color = vec3(0.62, 0.52, 0.4);
uniform vec3 dark_wood : source_color = vec3(0.33, 0.25, 0.18);
uniform vec3 paint : source_color = vec3(1.0, 1.0, 1.0);
uniform float paint_amount = 0.0;    // 0 = rohes Holz, 1 = gestrichen (mit abgeplatzter Farbe)
uniform float plank_width = 0.0;     // > 0: Plankenfugen alle plank_width Meter
uniform bool grain_along_x = false;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 g = grain_along_x ? lp.zx + vec2(lp.y, 0.0) : lp.xy + vec2(lp.z, 0.0);
	if (grain_along_x) { g = vec2(lp.z + lp.y * 0.7, lp.x); }
	float rings = cc_fbm(vec2(g.x * 18.0, g.y * 1.5));
	float streak = sin(g.x * 90.0 + rings * 9.0) * 0.5 + 0.5;
	vec3 col = mix(dark_wood, light_wood, smoothstep(0.2, 0.8, rings * 0.7 + streak * 0.3));
	float seam = 0.0;
	if (plank_width > 0.0) {
		float s = fract((grain_along_x ? lp.z : lp.x) / plank_width);
		seam = 1.0 - smoothstep(0.0, 0.04, min(s, 1.0 - s));
	}
	float chip = smoothstep(0.45, 0.55, cc_fbm(g * vec2(6.0, 3.0) + 11.0));
	col = mix(col, paint * (0.85 + 0.15 * streak), paint_amount * chip);
	col *= 1.0 - seam * 0.55;
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
