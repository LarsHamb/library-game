class_name CleanLadder
extends Area3D
## Kletterbereich vor einer Leiter. Das Modell der Leiter baut das Spiel selbst,
## dieser Bereich sorgt nur dafür, dass die Spielfigur klettern kann.

var facing := Vector3.BACK          # zeigt von der Wand/dem Regal weg
var max_feet_height := 1.45         # höher kommen die Füße nicht


## size: Breite, Höhe, Tiefe des Kletterbereichs. position: Mitte am Boden.
static func create(foot_center: Vector3, p_facing: Vector3, size: Vector3, p_max_feet: float) -> CleanLadder:
	var ladder := CleanLadder.new()
	ladder.facing = p_facing
	ladder.max_feet_height = p_max_feet
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	ladder.add_child(shape)
	ladder.position = foot_center
	if absf(p_facing.x) > absf(p_facing.z):
		ladder.rotation.y = PI * 0.5   # Bereich quer zur Blickrichtung ausrichten
	return ladder


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body is CleanPlayer:
			(body as CleanPlayer).enter_ladder(self))
	body_exited.connect(func(body: Node3D) -> void:
		if body is CleanPlayer:
			(body as CleanPlayer).exit_ladder(self))
