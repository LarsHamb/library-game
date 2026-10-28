class_name CleanUpgrade
extends Resource
## Ein kaufbares Upgrade mit Stufen. Jede Stufe verändert einen Wert (stat) oder schaltet ein Werkzeug frei.
##
## Wirkung pro Stufe:  wert = (basis + add_per_level * stufe) * (1 + mult_per_level * stufe)

@export var id := ""
@export var display_name := ""
@export_multiline var info := ""
@export var base_cost := 100
@export var cost_factor := 1.8      # jede Stufe kostet so viel mal mehr
@export var max_level := 1
@export var stat := ""              # z.B. "radius", "power", "reach", "speed", "coin_mult", "radar_cooldown"
@export var add_per_level := 0.0
@export var mult_per_level := 0.0
@export var unlock_tool := ""       # Werkzeug-ID, die ab Stufe 1 freigeschaltet ist
@export var spawns_bot := ""        # Roboter-Art ("rail", "drone" ...): jede Stufe = ein Roboter mehr
@export var unlocks_zone := ""      # Zonen-ID, die mit dem Kauf geöffnet wird
@export var category := ""          # Überschrift im Laden (leer = keine); gleiche Kategorien hintereinander anlegen


func cost(level: int) -> int:
	return roundi(base_cost * pow(cost_factor, level))


static func make(p_id: String, p_name: String, p_info: String, p_cost: int, p_factor: float, p_max: int,
		p_stat := "", p_add := 0.0, p_mult := 0.0, p_unlock := "") -> CleanUpgrade:
	var u := CleanUpgrade.new()
	u.id = p_id
	u.display_name = p_name
	u.info = p_info
	u.base_cost = p_cost
	u.cost_factor = p_factor
	u.max_level = p_max
	u.stat = p_stat
	u.add_per_level = p_add
	u.mult_per_level = p_mult
	u.unlock_tool = p_unlock
	return u


## Upgrade, das eine neue Zone öffnet.
static func make_zone(p_id: String, p_name: String, p_info: String, p_cost: int, zone_id: String) -> CleanUpgrade:
	var u := make(p_id, p_name, p_info, p_cost, 1.0, 1)
	u.unlocks_zone = zone_id
	return u


## Upgrade, das pro Stufe einen Roboter der Art kind dazukauft.
static func make_bot(p_id: String, p_name: String, p_info: String, p_cost: int, p_factor: float, p_max: int, kind: String) -> CleanUpgrade:
	var u := make(p_id, p_name, p_info, p_cost, p_factor, p_max)
	u.spawns_bot = kind
	return u
