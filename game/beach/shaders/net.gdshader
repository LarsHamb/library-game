// Geisternetz: verheddertes Fischernetz mit Rautenmuster und ausgefranstem Rand.
// Instanzfarbe vom Kern: Grundfarbe, Deckkraft (wird beim Schneiden dünner) und Radar-Gelb.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// leicht gewellt, wie über etwas gelegt
	VERTEX.y += 0.03 * sin(VERTEX.x * 9.0) * cos(VERTEX.z * 7.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p * vec2(1.0, 1.35)) + 0.3 * (cc_fbm(UV * 3.0 + wp.xz * 0.5) - 0.5);
	// ausgefranster Rand und Löcher
	if (r > 0.42 || cc_fbm(UV * 5.0 + wp.zx) < 0.28) {
		discard;
	}
	vec2 q = wp.xz * 9.0 + vec2(cc_fbm(wp.xz * 2.0), cc_fbm(wp.zx * 2.0)) * 1.5;
	vec2 g = abs(fract(vec2(q.x + q.y, q.x - q.y)) - 0.5);
	float line = 1.0 - smoothstep(0.06, 0.12, min(g.x, g.y));
	// dichtere, verknotete Stellen
	float clump = smoothstep(0.55, 0.75, cc_fbm(wp.xz * 3.0 + 7.0));
	float mask = max(line, clump * step(0.5, cc_noise(wp.xz * 40.0)));
	if (mask < 0.5 || COLOR.a < cc_noise(wp.xz * 31.0) * 0.6) {
		discard;
	}
	// Müll-Radar: der Kern färbt die Instanz gelb (1, 0.85, 0.2)
	float radar = step(0.97, COLOR.r) * (1.0 - step(0.3, COLOR.b));
	ALBEDO = COLOR.rgb * (0.75 + 0.35 * cc_noise(wp.xz * 20.0));
	EMISSION = vec3(1.0, 0.8, 0.15) * radar * 1.5;
	ROUGHNESS = 0.8;
}
