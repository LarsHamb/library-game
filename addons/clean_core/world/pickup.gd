class_name CleanPickup
extends StaticBody3D
## Etwas, das herumliegt und an seinen Platz zurück gehört (z.B. ein Buch auf dem Boden).
## Anklicken (oder E) im Reichweite: es fliegt in einem Bogen an target und bleibt dort stehen.
## Liegt auf Kollisionsebene 2: der Putz-Strahl trifft es, die Spielfigur läuft aber nicht dagegen.

signal collected(pickup: CleanPickup)

const FLY_TIME := 0.7

var id := ""
var zone: CleanZone
var coins := 50
var target := Transform3D()   # Platz, an den es zurück gehört (Welt-Koordinaten)
var model: Node3D
var done := false


## model wird so übernommen, wie es ist; from = wo es herumliegt.
static func create(p_id: String, p_model: Node3D, from: Transform3D, p_target: Transform3D, size: Vector3) -> CleanPickup:
	var p := CleanPickup.new()
	p.id = p_id
	p.model = p_model
	p.target = p_target
	p.transform = from
	p.collision_layer = 2
	p.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3.ONE * 0.06   # etwas größer, damit man es leicht trifft
	shape.shape = box
	p.add_child(shape)
	p.add_child(p_model)
	return p


func collect() -> void:
	if done:
		return
	done = true
	collision_layer = 0
	var start := global_transform
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		var e := k * k * (3.0 - 2.0 * k)
		var t := start.interpolate_with(target, e)
		t.origin += Vector3.UP * sin(PI * k) * 0.6
		global_transform = t, 0.0, 1.0, FLY_TIME)
	tween.tween_callback(func() -> void: collected.emit(self))


## Sofort am Ziel (beim Laden eines Spielstands).
func place_at_target() -> void:
	done = true
	collision_layer = 0
	global_transform = target
