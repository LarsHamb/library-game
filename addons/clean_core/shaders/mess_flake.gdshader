// Schmutzflocke: weicher, ausgefranster Fleck. Farbe und Dichte kommen aus Rauschen in Weltkoordinaten,
// dadurch verschmelzen überlappende Flocken zu einer zusammenhängenden Staubschicht.
// Die Instanzfarbe (COLOR) liefert Grundfarbe und Deckkraft (dünner werdender Staub, Radar-Leuchten).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform float cloud_scale = 1.3;     // große Wolken (hellere/dunklere Bereiche)
uniform float grain_scale = 55.0;    // feine Körnung
uniform float fluff = 0.6;           // wie unregelmäßig der Rand ist
uniform float layer_alpha = 0.5;     // Deckkraft einer einzelnen Flocke

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = world_pos.xz;
	float cloud = cc_fbm(wp * cloud_scale);
	float detail = cc_fbm(wp * 9.0);
	float grain = cc_noise(wp * grain_scale);
	float speck = cc_noise(wp * 140.0);
	// Weicher, großer Fleck: viele überlappen sich zu einer Schicht, deren Dichte das Rauschen bestimmt
	float r = length(UV - 0.5) * 2.0;
	float edge = pow(clamp(1.0 - r * r, 0.0, 1.0), 1.5) * (0.7 + fluff * (detail - 0.5));
	ALPHA = clamp(COLOR.a * layer_alpha * edge * (0.35 + 0.9 * cloud), 0.0, 1.0);
	ALBEDO = COLOR.rgb * (0.85 + 0.25 * cloud) * (0.9 + 0.15 * grain) * (speck > 0.93 ? 0.6 : 1.0);
	ROUGHNESS = 1.0;
}
