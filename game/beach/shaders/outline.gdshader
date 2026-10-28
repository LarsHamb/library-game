// Comic-Umrisse als Bildschirm-Effekt: dunkle Linien, wo die Tiefe springt (Kanten vor dem Hintergrund)
// oder die Flächen stark abknicken. Liegt als bildschirmfüllendes Rechteck über allem.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec3 line_color : source_color = vec3(0.08, 0.07, 0.1);
uniform float thickness = 1.8;          // Pixel
uniform float depth_threshold = 0.06;   // relativer Tiefensprung
uniform float normal_threshold = 0.55;  // 1 − cos(Knickwinkel)
uniform float fade_near = 24.0;         // ab hier werden Linien blasser …
uniform float fade_far = 80.0;          // … und hier verschwinden sie
uniform float water_level = -0.16;      // unter Wasser keine Linien (das Wasser schreibt keine Tiefe)

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	float c = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	// weiter weg dünnere Linien, sonst werden kleine Teile zu schwarzen Punkten
	vec2 px = mix(thickness, 1.0, smoothstep(6.0, fade_near, c)) / VIEWPORT_SIZE;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float depth_edge = 0.0;
	float normal_edge = 0.0;
	vec3 n = normal_at(SCREEN_UV);
	for (int i = 0; i < 4; i++) {
		float d = lin_depth(SCREEN_UV + offs[i], INV_PROJECTION_MATRIX);
		// nur die vordere Seite der Kante zeichnet die Linie
		depth_edge = max(depth_edge, (d - c) / max(c, 0.001));
		normal_edge = max(normal_edge, 1.0 - dot(n, normal_at(SCREEN_UV + offs[i])));
	}
	float edge = max(step(depth_threshold, depth_edge), step(normal_threshold, normal_edge) * step(c, 60.0));
	edge *= mix(1.0, 0.55, smoothstep(6.0, fade_near, c)) * (1.0 - smoothstep(fade_near, fade_far, c));
	// Weltposition des Pixels: unter dem Meeresspiegel liegt Wasser darüber
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	edge *= smoothstep(water_level - 0.12, water_level, world.y);
	ALBEDO = line_color;
	ALPHA = edge;
}
