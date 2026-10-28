// Höhe des Geländes: flacher Strand, hinten Dünen, vorne fällt der Sand ins Meer ab.
// Dieselbe Formel steht in beach_game.gd (ground_height), damit Gras und Palmen auf dem Boden stehen.

const float SHORE_Z = 8.0;      // ab hier fällt der Strand ab
const float DUNE_Z = -16.5;     // ab hier beginnen die Dünen

float ground_h(vec2 p) {
	float h = -max(p.y - SHORE_Z, 0.0) * 0.13;
	h = max(h, -4.0);
	float d = 1.0 - smoothstep(DUNE_Z - 9.0, DUNE_Z, p.y);
	float hills = 3.0 + 1.2 * sin(p.x * 0.11 + 1.3) + 0.8 * sin(p.x * 0.27 + p.y * 0.2);
	return h + d * hills;
}
