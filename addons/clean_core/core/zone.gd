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


func contains(p: Vector3) -> bool:
	return bounds.has_point(Vector2(p.x, p.z))
