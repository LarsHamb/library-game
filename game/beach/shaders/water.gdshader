// Meer: Wellen im Vertex-Shader, Farbe nach Wassertiefe (türkis im Flachen, tiefblau draußen),
// Lichtbrechung über den Bildschirminhalt (Tiefe aus der Geländeformel), Schaumsaum am Strand und Schaumkronen.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_toon;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"
#include "res://game/beach/shaders/ground.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.25, 0.85, 0.8);
uniform vec3 mid_color : source_color = vec3(0.05, 0.6, 0.72);
uniform vec3 deep : source_color = vec3(0.02, 0.32, 0.6);
uniform vec3 foam_color : source_color = vec3(0.96, 0.98, 0.98);
uniform float shore_z = 9.0;

varying vec3 wp;
varying float crest;

// Summe mehrerer Wellen, die zum Strand (−z) laufen. Gibt Höhe zurück, grad = Ableitung nach x/z.
float waves(vec2 p, float t, out vec2 grad) {
	float amp_k = smoothstep(shore_z - 1.0, shore_z + 25.0, p.y);
	float h = 0.0;
	grad = vec2(0.0);
	vec4 dirs[4] = vec4[](vec4(0.08, -1.0, 0.55, 0.16), vec4(-0.35, -0.94, 0.9, 0.08),
		vec4(0.5, -0.86, 1.4, 0.05), vec4(-0.1, -1.0, 2.3, 0.025));
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i].xy);
		float k = dirs[i].z;
		float a = dirs[i].w * (0.25 + 0.75 * amp_k);
		float ph = dot(d, p) * k + t * sqrt(9.8 * k);
		h += a * sin(ph);
		grad += a * k * cos(ph) * d;
	}
	return h;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g;
	float h = waves(w.xz, TIME, g);
	// Tide: das Wasser läuft langsam den Strand hoch und wieder runter
	h += 0.05 * sin(TIME * 0.45);
	VERTEX.y += h;
	crest = h;
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
	wp = w + vec3(0.0, h, 0.0);
}

void fragment() {
	// feine, wandernde Kräuselung
	vec2 p = wp.xz;
	float e = 0.05;
	float t = TIME;
	float r0 = cc_fbm(p * 1.7 + vec2(0.0, t * 0.35)) + cc_fbm(p * 3.1 - vec2(t * 0.2, t * 0.4));
	float rx = cc_fbm((p + vec2(e, 0.0)) * 1.7 + vec2(0.0, t * 0.35)) + cc_fbm((p + vec2(e, 0.0)) * 3.1 - vec2(t * 0.2, t * 0.4));
	float rz = cc_fbm((p + vec2(0.0, e)) * 1.7 + vec2(0.0, t * 0.35)) + cc_fbm((p + vec2(0.0, e)) * 3.1 - vec2(t * 0.2, t * 0.4));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wn = normalize(wn + vec3(-(rx - r0) / e, 0.0, -(rz - r0) / e) * 0.06);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Wassertiefe unter diesem Punkt aus der Geländeformel (der Tiefenpuffer ist mit MSAA nicht verlässlich)
	float column = max(wp.y - ground_h(wp.xz), 0.0);
	vec3 view_dir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	float dist_behind = column / max(-view_dir.y, 0.08);

	// Comic: klare Farbstufen statt weichem Verlauf
	vec3 water = mix(shallow, mid_color, step(0.45, column));
	water = mix(water, deep, step(2.2, column + 0.6 * (cc_fbm(p * 0.05) - 0.5)));
	// Lichtbrechung: der Grund schimmert durch, verzerrt durch die Wellen
	vec2 refr_uv = SCREEN_UV + wn.xz * 0.025 * clamp(column, 0.0, 1.0);
	vec3 below = textureLod(screen_tex, refr_uv, 1.0).rgb;
	float clarity = exp(-dist_behind * 0.9);
	vec3 tint = mix(vec3(1.0), shallow * 1.2, 0.5);

	// Schaum: am Strand, wo das Wasser flach wird, und auf den Wellenkämmen
	float n1 = cc_fbm(p * 2.2 + vec2(t * 0.15, -t * 0.3));
	float n2 = cc_noise(p * 9.0 - vec2(0.0, t * 0.8));
	float shore_foam = 1.0 - step(0.06 + 0.12 * n1, column);
	float lines = step(0.82, sin(column * 14.0 - t * 2.2 + n1 * 4.0) * 0.5 + 0.5) * (1.0 - step(0.4, column));
	float crest_foam = step(0.18, crest + n1 * 0.08) * step(0.62, n2 + n1 * 0.4);
	// glitzernde Sonnenflecken als kleine weiße Striche
	float glint = step(0.93, cc_noise(p * vec2(1.5, 6.0) + vec2(t * 0.3, -t * 0.6))) * step(0.5, column);
	float foam = clamp(max(max(shore_foam, lines), max(crest_foam, glint * 0.8)), 0.0, 1.0);

	float opacity = 1.0 - clarity;
	ALBEDO = mix(water * opacity, foam_color, foam);
	EMISSION = below * tint * clarity * (1.0 - foam) * 0.9;
	ROUGHNESS = mix(0.15, 0.9, foam);
	SPECULAR = 0.55;
	// weicher Übergang am Ufer, damit keine harte Kante entsteht
	ALPHA = clamp(column * 25.0, 0.0, 1.0);
}
