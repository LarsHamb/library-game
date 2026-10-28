// Großer Müll (Flaschen, Dosen, Tüten, Bojen ...): alle Formen stecken in einem Mesh, jede mit eigener Nummer (UV2.x).
// Die Instanz zeigt nur die Form, deren Nummer in ihrer Farbe (Alpha × 16) steht.
// INSTANCE_CUSTOM kommt vom Kern: r = Restmüll 0..1 (0 = aufgesammelt), g = Müll-Radar.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

varying float glow;
varying vec4 vcol;

void vertex() {
	float want = floor(COLOR.a * 16.0 + 0.5);
	float mine = floor(UV2.x + 0.5);
	float k = INSTANCE_CUSTOM.r;
	if (abs(want - mine) > 0.1 || k <= 0.001) {
		VERTEX = vec3(0.0);
	} else {
		// wird beim Aufsammeln ein wenig kleiner und wackelt
		VERTEX *= 0.7 + 0.3 * k;
	}
	glow = INSTANCE_CUSTOM.g;
	vcol = COLOR;
}

void fragment() {
	vec3 col = vcol.rgb;
	// Sand und Salz liegen auf allem
	float dirt = cc_fbm(UV * 6.0 + vcol.r * 3.0);
	col = mix(col, vec3(0.8, 0.72, 0.58), smoothstep(0.55, 0.8, dirt) * 0.5);
	ALBEDO = mix(col, vec3(1.0, 0.85, 0.2), glow * 0.6);
	EMISSION = vec3(1.0, 0.8, 0.15) * glow * 1.4;
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
}
