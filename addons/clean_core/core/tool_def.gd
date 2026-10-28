class_name CleanTool
extends Resource
## Ein Putzwerkzeug. Die Werte sind Faktoren auf die Grundwerte des Spielers
## (radius, power, reach), damit Upgrades automatisch für alle Werkzeuge gelten.

## SWEEP: Staub wirbelt hoch, Werkzeug schwingt. SUCK: Staub fliegt zur Düse, Werkzeug brummt.
## PICK: hebt Teil für Teil auf (das nächste im Ring), Taste halten = eins nach dem anderen.
enum Style { SWEEP, SUCK, PICK }

@export var id := ""
@export var display_name := ""
@export var radius_mult := 1.0
@export var power_mult := 1.0
@export var reach_mult := 1.0
@export var style := Style.SWEEP
@export var unlocked_from_start := true
@export var hotkey := 1          # Zifferntaste zum Auswählen


static func make(p_id: String, p_name: String, p_hotkey: int, p_style: Style, p_radius := 1.0, p_power := 1.0, p_reach := 1.0, p_unlocked := true) -> CleanTool:
	var t := CleanTool.new()
	t.id = p_id
	t.display_name = p_name
	t.hotkey = p_hotkey
	t.style = p_style
	t.radius_mult = p_radius
	t.power_mult = p_power
	t.reach_mult = p_reach
	t.unlocked_from_start = p_unlocked
	return t
