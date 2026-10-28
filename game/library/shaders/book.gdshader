// Bücher als MultiMesh: Instanzfarbe = Einband. Buchrücken bekommen Goldbänder und ein Titelfeld,
// die Oberseite zeigt helle Seiten. Instanzdaten (INSTANCE_CUSTOM): r = Staub 0..1, g = Radar-Leuchten.
// Staubige Bücher sind von einer grauen, flusigen Schicht bedeckt, die beim Putzen verschwindet.
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

varying vec3 local_pos;
varying vec3 local_normal;
varying vec2 dust;

uniform vec3 dust_color : source_color = vec3(0.6, 0.57, 0.52);
uniform vec3 tint : source_color = vec3(1.0);   // Einbandfarbe für einzelne Bücher ohne Instanzfarbe

void vertex() {
	local_pos = VERTEX;       // Würfel von -0.5 bis 0.5, pro Buch gestreckt
	local_normal = NORMAL;
	dust = INSTANCE_CUSTOM.rg;
}

void fragment() {
	vec3 cover = COLOR.rgb * tint;
	float leather = cc_fbm(local_pos.xy * vec2(40.0, 25.0) + COLOR.r * 50.0);
	vec3 c = cover * mix(0.75, 1.1, leather);
	float metal = 0.0;
	float rough = 0.6;
	if (abs(local_normal.z) > 0.5) {
		// Buchrücken
		float y = local_pos.y;
		float band = 1.0 - step(0.022, abs(abs(y) - 0.38));
		float label = step(abs(y - 0.06), 0.11) * step(abs(local_pos.x), 0.36);
		float style = step(0.5, fract(COLOR.g * 37.0));   // nur manche Bücher haben ein Titelfeld
		c = mix(c, c * 0.45, label * style);
		c = mix(c, vec3(0.78, 0.6, 0.28), band);
		metal = band * 0.8;
		rough = mix(0.6, 0.3, band);
	} else if (local_normal.y > 0.5) {
		// Oberseite: Seiten mit Einbandrand
		float edge = step(0.4, max(abs(local_pos.x), abs(local_pos.z)));
		float lines = 0.92 + 0.08 * sin(local_pos.z * 300.0);
		c = mix(vec3(0.86, 0.8, 0.66) * lines, c, edge);
	}
	// Staubschicht: fleckig, oben dicker als am Rücken
	float amount = dust.x * (local_normal.y > 0.5 ? 1.25 : 1.0);
	vec2 p = local_pos.xy * vec2(30.0, 18.0) + local_pos.zz * 11.0 + COLOR.b * 40.0;
	float fluff = cc_fbm(p) * 0.7 + cc_noise(p * 6.0) * 0.3;
	float t = amount * 1.3 - (1.0 - fluff) * 0.9;
	float coat = min(smoothstep(0.0, 0.3, t), 0.95);   // 0 bei sauberem Buch, fast deckend bei dickem Staub
	vec3 dusty = mix(dust_color * (0.85 + 0.3 * fluff), vec3(dot(c, vec3(0.33))), 0.15);
	c = mix(c, dusty, coat);
	ALBEDO = c;
	METALLIC = metal * (1.0 - coat);
	ROUGHNESS = mix(rough, 1.0, coat);
	EMISSION = vec3(1.0, 0.8, 0.2) * dust.y * 0.8;
}
