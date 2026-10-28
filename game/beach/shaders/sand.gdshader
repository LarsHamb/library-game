// Sandboden: Farbe aus Rauschen, feine Körnung, vom Wind gezeichnete Rippeln,
// dunkler, glatter Nasssand am Spülsaum. Das Gelände wird im Shader verformt (ground.gdshaderinc).
shader_type spatial;
render_mode diffuse_burley;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"
#include "res://game/beach/shaders/ground.gdshaderinc"

uniform vec3 sand_dry : source_color = vec3(0.86, 0.74, 0.56);
uniform vec3 sand_light : source_color = vec3(0.96, 0.88, 0.71);
uniform vec3 sand_wet : source_color = vec3(0.6, 0.5, 0.37);
uniform float water_level = -0.12;

varying vec3 wp;
varying vec3 wn;

float ripple(vec2 q, float scale) {
	return sin((q.x * 0.5 + q.y * 7.0) * scale + cc_fbm(q * 0.3) * 8.0);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = ground_h(w.xz);
	VERTEX.y += h;
	float e = 0.25;
	wn = normalize(vec3(ground_h(w.xz - vec2(e, 0.0)) - ground_h(w.xz + vec2(e, 0.0)), 2.0 * e,
		ground_h(w.xz - vec2(0.0, e)) - ground_h(w.xz + vec2(0.0, e))));
	NORMAL = wn;
	wp = w + vec3(0.0, h, 0.0);
}

void fragment() {
	vec2 p = wp.xz;
	float big = cc_fbm(p * 0.07);
	float mid = cc_fbm(p * 0.55 + 3.0);
	float grain = cc_noise(p * 95.0);
	vec3 col = mix(sand_dry, sand_light, smoothstep(0.25, 0.75, big));
	col *= (0.93 + 0.12 * mid) * (0.94 + 0.09 * grain);
	// kleine dunkle Körner und helle Muschelsplitter
	float speck = cc_noise(p * 48.0 + 7.0);
	col = mix(col, vec3(0.42, 0.36, 0.3), step(0.955, speck) * 0.55);
	col = mix(col, vec3(1.0, 0.97, 0.92), step(0.965, cc_noise(p * 31.0 - 5.0)) * 0.6);

	// Nasser Sand: unterhalb der Spülsaum-Linie, die mit den Wellen leicht vor- und zurückläuft
	// (bleibt unter der Höhe 0 des flachen Strands, der Fluthöchststand liegt knapp darunter)
	float swash = water_level + 0.05 + 0.03 * sin(TIME * 0.45) + 0.015 * cc_fbm(p * 0.4);
	float wet = 1.0 - smoothstep(swash - 0.02, swash + 0.02, wp.y);
	// davor ein breiter, feuchter Streifen mit unregelmäßigem Rand
	float damp = smoothstep(SHORE_Z - 2.8, SHORE_Z + 0.4, wp.z + (cc_fbm(p * 0.25) - 0.5) * 2.5);
	wet = max(wet, damp * 0.32);
	col = mix(col, sand_wet * (0.9 + 0.2 * mid), wet);

	// Rippeln: auf den Dünen größer, im Nassen glattgespült
	float dune = 1.0 - smoothstep(DUNE_Z - 4.0, DUNE_Z, wp.z);
	float scale = mix(1.0, 0.45, dune);
	float amp = mix(0.018, 0.06, dune) * (1.0 - wet * 0.9) * smoothstep(0.25, 0.75, mid + 0.2 * big);
	float e = 0.02;
	float dx = (ripple(p + vec2(e, 0.0), scale) - ripple(p - vec2(e, 0.0), scale)) / (2.0 * e);
	float dz = (ripple(p + vec2(0.0, e), scale) - ripple(p - vec2(0.0, e), scale)) / (2.0 * e);
	vec3 n = normalize(wn + vec3(-dx * amp, 0.0, -dz * amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Rippel-Täler etwas dunkler
	col *= 0.98 + 0.025 * ripple(p, scale) * (1.0 - wet);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.3, wet * wet);
	SPECULAR = mix(0.25, 0.55, wet * wet);
}
