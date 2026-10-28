// Felsen: Kugeln werden mit Rauschen zu Brocken verformt. Grau-braun, unten nass und mit Algen und Seepocken.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 stone : source_color = vec3(0.47, 0.44, 0.41);
uniform vec3 stone_dark : source_color = vec3(0.26, 0.24, 0.23);
uniform vec3 algae : source_color = vec3(0.2, 0.3, 0.12);
uniform float bump = 0.35;
uniform float seed = 0.0;
uniform float wet_line = 0.35;

varying vec3 wp;
varying vec3 opos;

float lump(vec3 p) {
	return cc_fbm(p.xy * 1.3 + seed) * 0.5 + cc_fbm(p.yz * 1.3 + seed * 1.7) * 0.5;
}

void vertex() {
	vec3 dir = normalize(VERTEX);
	float n = lump(dir * 2.0);
	VERTEX += NORMAL * (n - 0.5) * bump * 2.0;
	// abgeflachte Unterseite
	VERTEX.y = max(VERTEX.y, -0.35);
	opos = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wn = normalize(cross(dFdx(wp), dFdy(wp)));
	vec3 vn = normalize((VIEW_MATRIX * vec4(-wn, 0.0)).xyz);
	if (dot(vn, NORMAL) < 0.0) { vn = -vn; }
	NORMAL = normalize(mix(NORMAL, vn, 0.65));
	float n = cc_fbm(wp.xz * 2.0 + wp.y * 1.3) * 0.6 + cc_fbm(wp.xy * 3.0) * 0.4;
	float cracks = smoothstep(0.02, 0.0, abs(cc_noise(wp.xz * 3.0 + wp.y * 2.0) - 0.5) - 0.01);
	vec3 col = mix(stone_dark, stone, smoothstep(0.25, 0.75, n));
	col *= 1.0 - cracks * 0.4;
	float low = 1.0 - smoothstep(wet_line - 0.1, wet_line + 0.15, wp.y + n * 0.2);
	col = mix(col, col * 0.55, low * 0.7);
	col = mix(col, algae, low * smoothstep(0.45, 0.7, cc_fbm(wp.xz * 4.0)) * 0.8);
	// Seepocken
	float barn = step(0.88, cc_noise(wp.xz * 22.0 + wp.y * 9.0)) * low;
	col = mix(col, vec3(0.85, 0.83, 0.76), barn * 0.8);
	// oben etwas heller, von der Sonne ausgebleicht
	col *= 0.9 + 0.2 * clamp(wn.y, 0.0, 1.0);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.35, low);
}
