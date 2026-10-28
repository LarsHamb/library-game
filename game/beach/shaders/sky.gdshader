// Himmel: Verlauf von tiefblau oben zu hellem Dunst am Horizont, Sonne mit Hof und lockere Schönwetterwolken.
shader_type sky;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.16, 0.42, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.86, 0.94);
uniform vec3 below_color : source_color = vec3(0.2, 0.42, 0.52);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.66, 0.72, 0.82);
uniform float cloud_cover = 0.42;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
	if (h < 0.0) {
		col = mix(horizon_color, below_color, clamp(-h * 3.0, 0.0, 1.0));
	}
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	// Wolken: Rauschen auf einer gedachten Wolkendecke
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.06);
		float c = cc_fbm(uv * 0.55 + vec2(3.0, 1.0));
		c += 0.35 * cc_fbm(uv * 1.9);
		float dens = smoothstep(1.05 - cloud_cover, 1.35 - cloud_cover, c);
		float lit = smoothstep(0.4, 1.2, c - cc_fbm(uv * 0.55 + LIGHT0_DIRECTION.xz * 0.15 + vec2(3.0, 1.0)) * 0.6);
		vec3 cc = mix(cloud_light, cloud_shade, lit * 0.8);
		cc += LIGHT0_COLOR * pow(sd, 6.0) * 0.25;
		col = mix(col, cc, dens * smoothstep(0.0, 0.12, h) * 0.95);
	}
	col += LIGHT0_COLOR * LIGHT0_ENERGY * (pow(sd, 900.0) * 30.0 + pow(sd, 40.0) * 0.18 + pow(sd, 6.0) * 0.08);
	COLOR = col;
}
