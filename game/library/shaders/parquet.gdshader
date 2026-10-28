// Parkettboden aus Dielen, komplett prozedural (Weltkoordinaten, nur für waagrechte Flächen).
shader_type spatial;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 wood_light : source_color = vec3(0.50, 0.31, 0.16);
uniform vec3 wood_dark : source_color = vec3(0.27, 0.15, 0.07);
uniform float plank_width = 0.2;
uniform float plank_length = 1.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float row = floor(p.x / plank_width);
	float shift = cc_hash(vec2(row, 3.7)) * plank_length;
	float col = floor((p.y + shift) / plank_length);
	vec2 id = vec2(row, col);
	vec2 f = vec2(fract(p.x / plank_width), fract((p.y + shift) / plank_length));
	float rnd = cc_hash(id);
	// Maserung: längs der Diele gestreckt, Jahresringe leicht gewellt
	vec2 g = vec2(p.x * 45.0 + rnd * 20.0, p.y * 2.5 + rnd * 7.0);
	float grain = cc_fbm(g);
	float rings = 0.5 + 0.5 * sin(p.x * 90.0 + cc_fbm(vec2(p.x * 6.0, p.y * 1.5) + rnd * 5.0) * 9.0);
	float t = clamp(grain * 0.75 + rings * 0.25 + (rnd - 0.5) * 0.45, 0.0, 1.0);
	vec3 c = mix(wood_dark, wood_light, t);
	// Fugen zwischen den Dielen
	float gap = smoothstep(0.0, 0.035, f.x) * smoothstep(1.0, 0.965, f.x)
		* smoothstep(0.0, 0.006, f.y) * smoothstep(1.0, 0.994, f.y);
	c *= mix(0.3, 1.0, gap);
	ALBEDO = c;
	ROUGHNESS = mix(0.7, 0.28 + grain * 0.15, gap);
	SPECULAR = 0.5;
}
