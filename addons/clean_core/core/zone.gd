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
var layers: Array[CleanMessField] = []       # Zusatz-Schmutz wie Spinnweben (zählt nicht zum Prozentwert)
var spawn := Vector3.INF                     # Ankunftspunkt beim Reisen über die Karte (INF = Mitte)
var spawn_yaw := 0.0


func spawn_point() -> Vector3:
	if spawn != Vector3.INF:
		return spawn
	return Vector3(bounds.get_center().x, 0.05, bounds.get_center().y)


## Alle Schmutzfelder der Zone: Hauptschicht und Zusatz-Schichten.
func all_messes() -> Array[CleanMessField]:
	var list: Array[CleanMessField] = [mess]
	list.append_array(layers)
	return list


func contains(p: Vector3) -> bool:
	return bounds.has_point(Vector2(p.x, p.z))
