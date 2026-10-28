// Kleine Rausch-Funktionen für prozedurale Materialien (keine Texturen nötig).

float cc_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cc_hash(i), cc_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cc_hash(i + vec2(0.0, 1.0)), cc_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float cc_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * cc_noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}
