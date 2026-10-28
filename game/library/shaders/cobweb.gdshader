// Spinnennetz für Flocken unter der Decke: Speichen und eine Spirale, zum Rand hin ausgefranst.
// Instanzfarbe (COLOR) gibt Farbe und Deckkraft (dünner werdend beim Putzen, Radar-Leuchten).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform float spokes = 11.0;
uniform float turns = 9.0;
uniform float thread = 0.035;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Speichen leicht unregelmäßig
	float wobble = cc_noise(vec2(a * 3.0, r * 4.0)) * 0.25;
	float spoke = abs(fract((a / 6.2831853) * spokes + wobble) - 0.5) * 2.0;
	float spoke_line = 1.0 - smoothstep(0.0, thread * 1.6 / max(r, 0.08), spoke);
	// Spirale: Abstand zwischen den Ringen, zwischen den Speichen leicht durchhängend
	float sag = 0.04 * sin(fract((a / 6.2831853) * spokes) * 3.14159);
	float ring = abs(fract((r + sag) * turns + a / 6.2831853) - 0.5) * 2.0;
	float ring_line = (1.0 - smoothstep(0.0, thread * turns * 0.6, ring)) * step(0.08, r);
	float web = max(spoke_line * 0.8, ring_line);
	// Ausgefranster Rand und ein paar gerissene Stellen
	float torn = step(0.28, cc_noise(p * 5.0 + COLOR.r * 20.0));
	float edge = 1.0 - smoothstep(0.75, 1.0, r + 0.15 * cc_noise(p * 3.0));
	ALPHA = clamp(web * edge * torn * COLOR.a * 0.85, 0.0, 1.0);
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.08;
	ROUGHNESS = 0.9;
}
