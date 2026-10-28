class_name CleanZone
extends RefCounted
## Ein Bereich mit eigenem Schmutz und eigenem Fortschritt (z.B. ein Saal).
## Gesperrte Zonen haben Türen, die beim Freischalten (Upgrade mit unlocks_zone) verschwinden.

var id := ""
var display_name := ""
var bounds := Rect2(-1e6, -1e6, 2e6, 2e6)   # Grundfläche (x, z); die erste Zone umfasst alles übrige
var mess: CleanMessField
var complete_bonus := 0
var value_mult := 1.0                        # Münzen pro Flocke in dieser Zone
var unlocked := true
var door_nodes: Array[Node] = []             # Türen, Schilder ... verschwinden beim Freischalten
var layers: Array[CleanMessField] = []       # Zusatz-Schichten wie Bücher oder Spinnweben (zählen zum Prozentwert)
var pickups: Array[CleanPickup] = []         # herumliegende Dinge, die zurück an ihren Platz gehören
var spawn := Vector3.INF                     # Ankunftspunkt beim Reisen über die Karte (INF = Mitte)
var spawn_yaw := 0.0


func spawn_point() -> Vector3:
	if spawn != Vector3.INF:
		return spawn
	return Vector3(bounds.get_center().x, 0.05, bounds.get_center().y)


## Fortschritt über alle Schichten zusammen (jede Flocke zählt gleich).
func progress_percent() -> float:
	var all := 0
	var left := 0
	for m in all_messes():
		all += m.total
		left += m.remaining
	if all == 0:
		return 100.0
	return 100.0 * float(all - left) / float(all)


## Alle Schmutzfelder der Zone: Hauptschicht und Zusatz-Schichten.
func all_messes() -> Array[CleanMessField]:
	var list: Array[CleanMessField] = [mess]
	list.append_array(layers)
	return list


func contains(p: Vector3) -> bool:
	return bounds.has_point(Vector2(p.x, p.z))
