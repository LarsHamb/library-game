// Kleinmüll am Strand als flache Teile: Kronkorken, Kippen, Plastiksplitter, Bonbonpapier, Strohhalme,
// Schnurreste und Styroporkrümel. Jede Instanz bekommt per Zufall eine Form und Farbe.
// Die Instanzfarbe (COLOR) kommt vom Kern: weiß = normal, gelb = Müll-Radar.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

varying float kind;
varying float rnd;
varying vec3 wp;

const vec3 PALETTE[8] = vec3[](vec3(0.85, 0.12, 0.1), vec3(0.1, 0.35, 0.8), vec3(0.95, 0.95, 0.92),
	vec3(0.15, 0.6, 0.3), vec3(0.98, 0.78, 0.1), vec3(0.95, 0.45, 0.1), vec3(0.6, 0.62, 0.66), vec3(0.2, 0.75, 0.8));

void vertex() {
	float id = float(INSTANCE_ID);
	rnd = fract(sin(id * 12.9898) * 43758.5453);
	kind = floor(fract(sin(id * 78.233) * 12345.678) * 7.0);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return max(d.x, d.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	float shape = 1.0;      // < 0 = innen
	vec3 col = PALETTE[int(rnd * 8.0)];
	float shade = 1.0;
	if (kind < 0.5) {            // Kronkorken
		float r = length(p);
		shape = r - 0.16 - 0.012 * sin(atan(p.y, p.x) * 21.0);
		shade = r < 0.11 ? 0.85 : 1.0;
	} else if (kind < 1.5) {     // Zigarettenkippe
		shape = box(p, vec2(0.2, 0.045));
		col = p.x > 0.07 ? vec3(0.85, 0.55, 0.25) : vec3(0.95, 0.93, 0.88);
		shade = p.x < -0.18 ? 0.5 : 1.0;
	} else if (kind < 2.5) {     // Plastiksplitter
		float a = atan(p.y, p.x);
		shape = length(p) - (0.14 + 0.09 * cc_noise(vec2(a * 2.0 + rnd * 20.0, rnd * 9.0)));
		shade = 0.85 + 0.25 * cc_noise(UV * 8.0 + rnd * 4.0);
	} else if (kind < 3.5) {     // Bonbon- oder Riegelpapier, zerknittert
		shape = box(p, vec2(0.21, 0.13)) - 0.03 * cc_noise(UV * 9.0 + rnd);
		col = mix(col, vec3(0.85, 0.86, 0.9), step(0.5, fract(UV.x * 4.0 + rnd)) * 0.7);
		shade = 0.75 + 0.4 * cc_noise(UV * 14.0 + rnd * 7.0);
	} else if (kind < 4.5) {     // Strohhalm
		shape = box(p, vec2(0.28, 0.025));
		col = mix(vec3(0.97), col, step(0.5, fract(p.x * 8.0 + p.y * 3.0)));
	} else if (kind < 5.5) {     // Stück Schnur
		float y = 0.05 * sin(p.x * 22.0 + rnd * 6.0);
		shape = max(abs(p.y - y) - 0.022, abs(p.x) - 0.3);
		col = mix(vec3(0.1, 0.4, 0.75), vec3(0.95, 0.5, 0.1), step(0.5, rnd));
		shade = 0.8 + 0.3 * step(0.5, fract((p.x + p.y) * 30.0));
	} else {                     // Styroporkrümel
		shape = length(p * vec2(1.0, 1.3)) - 0.11 - 0.04 * cc_noise(UV * 12.0 + rnd * 3.0);
		col = vec3(0.97, 0.97, 0.95);
		shade = 0.9 + 0.1 * cc_noise(UV * 40.0);
	}
	if (shape > 0.0) {
		discard;
	}
	// ausgeblichen von Sonne und Salz
	col = mix(col, vec3(0.9, 0.87, 0.8), 0.25 + 0.2 * rnd);
	// Müll-Radar: der Kern färbt die Instanz gelb (1, 0.85, 0.2)
	float radar = step(0.97, COLOR.r) * (1.0 - step(0.3, COLOR.b));
	ALBEDO = col * shade * mix(vec3(1.0), COLOR.rgb, radar);
	EMISSION = vec3(1.0, 0.8, 0.15) * radar * 1.5;
	ROUGHNESS = kind < 0.5 ? 0.35 : 0.6;
	METALLIC = kind < 0.5 ? 0.6 : 0.0;
}
