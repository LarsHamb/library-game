// Himmel: Verlauf von tiefblau oben zu hellem Dunst am Horizont, Sonne mit Hof und lockere Schönwetterwolken.
shader_type sky;

#include "res://addons/clean_core/shaders/noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.12, 0.45, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.86, 0.94);
uniform vec3 below_color : source_color = vec3(0.2, 0.42, 0.52);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.8, 0.93);
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
		// Comic-Wolken: harte Kante, zwei Farbtöne (beleuchtet / Schattenseite unten)
		float dens = smoothstep(1.12 - cloud_cover, 1.16 - cloud_cover, c);
		float under = cc_fbm(uv * 0.55 + vec2(3.0, 1.0) + vec2(0.0, 0.18));
		float lit = step(1.2 - cloud_cover, under + 0.35 * cc_fbm(uv * 1.9));
		vec3 cc = mix(cloud_shade, cloud_light, lit);
		cc += LIGHT0_COLOR * pow(sd, 6.0) * 0.25;
		col = mix(col, cc, dens * smoothstep(0.0, 0.12, h) * 0.95);
	}
	col += LIGHT0_COLOR * LIGHT0_ENERGY * (step(0.9993, sd) * 6.0 + pow(sd, 40.0) * 0.15 + pow(sd, 6.0) * 0.06);
	COLOR = col;
}
