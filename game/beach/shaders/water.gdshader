// Meer: Wellen im Vertex-Shader, Farbe nach Wassertiefe (türkis im Flachen, tiefblau draußen),
// Lichtbrechung über den Bildschirminhalt (Tiefe aus der Geländeformel), Schaumsaum am Strand und Schaumkronen.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"
#include "res://game/beach/shaders/ground.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.3, 0.8, 0.74);
uniform vec3 mid_color : source_color = vec3(0.07, 0.5, 0.6);
uniform vec3 deep : source_color = vec3(0.02, 0.2, 0.36);
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

	vec3 water = mix(shallow, mid_color, smoothstep(0.0, 1.2, column));
	water = mix(water, deep, smoothstep(1.0, 4.5, column));
	// Lichtbrechung: der Grund schimmert durch, verzerrt durch die Wellen
	vec2 refr_uv = SCREEN_UV + wn.xz * 0.025 * clamp(column, 0.0, 1.0);
	vec3 below = textureLod(screen_tex, refr_uv, 1.0).rgb;
	float clarity = exp(-dist_behind * 0.9);
	vec3 tint = mix(vec3(1.0), shallow * 1.2, 0.5);

	// Schaum: am Strand, wo das Wasser flach wird, und auf den Wellenkämmen
	float n1 = cc_fbm(p * 2.2 + vec2(t * 0.15, -t * 0.3));
	float n2 = cc_noise(p * 9.0 - vec2(0.0, t * 0.8));
	float shore_foam = 1.0 - smoothstep(0.0, 0.08 + 0.18 * n1, column);
	float lines = smoothstep(0.55, 0.9, sin(column * 18.0 - t * 2.2 + n1 * 4.0) * 0.5 + 0.5) * (1.0 - smoothstep(0.05, 0.45, column));
	float crest_foam = smoothstep(0.12, 0.22, crest + n1 * 0.08) * smoothstep(0.45, 0.8, n2 + n1 * 0.4);
	float foam = clamp(max(shore_foam * smoothstep(0.3, 0.6, n2 + 0.3), lines * 0.8) + crest_foam * 0.7, 0.0, 1.0);

	float opacity = 1.0 - clarity;
	ALBEDO = mix(water * opacity, foam_color, foam);
	EMISSION = below * tint * clarity * (1.0 - foam) * 0.9;
	ROUGHNESS = mix(0.04, 0.8, foam);
	SPECULAR = 0.55;
	// weicher Übergang am Ufer, damit keine harte Kante entsteht
	ALPHA = clamp(column * 25.0, 0.0, 1.0);
}
