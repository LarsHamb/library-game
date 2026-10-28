// Bücher als MultiMesh: Instanzfarbe = Einband. Buchrücken bekommen Goldbänder und ein Titelfeld,
// die Oberseite zeigt helle Seiten.
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;       // Würfel von -0.5 bis 0.5, pro Buch gestreckt
	local_normal = NORMAL;
}

void fragment() {
	vec3 cover = COLOR.rgb;
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
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
}
