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
