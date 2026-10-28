class_name CleanGameState
extends RefCounted
## Spielstand: Münzen, Upgrade-Stufen, gefundene Sammelobjekte, Meilensteine.
## Rechnet daraus die aktuellen Werte (stats) aus und kann sich als Dictionary speichern.

var config: CleanGameConfig
var coins := 0
var levels := {}                      # Upgrade-ID -> Stufe
var found: Array[String] = []         # IDs gefundener Sammelobjekte
var milestones_hit: Array[String] = []   # "zonen-id:prozent"
var zones_done: Array[String] = []
var returned: Array[String] = []      # IDs zurückgestellter Fundsachen (CleanPickup)
var carried := 0                      # Teile im Sack (siehe Grundwert "capacity")
var carried_coins := 0                # was sie beim Leeren bringen


func _init(p_config: CleanGameConfig) -> void:
	config = p_config


func level(id: String) -> int:
	return levels.get(id, 0)


func has_found(id: String) -> bool:
	return found.has(id)


func upgrade(id: String) -> CleanUpgrade:
	for u in config.upgrades:
		if u.id == id:
			return u
	return null


func collectible(id: String) -> CleanCollectibleDef:
	for c in config.collectibles:
		if c.id == id:
			return c
	return null


## Aktueller Wert eines Stats mit allen Upgrades und Sammelobjekten.
func stat(name: String) -> float:
	var add: float = 0.0
	var upgrade_mult := 1.0
	var collect_mult := 1.0
	for u in config.upgrades:
		if u.stat == name:
			add += u.add_per_level * level(u.id)
			upgrade_mult += u.mult_per_level * level(u.id)
	for c in config.collectibles:
		if c.stat == name and has_found(c.id):
			add += c.add
			collect_mult *= c.mult
	var base: float = config.base_stats.get(name, 0.0)
	return (base + add) * upgrade_mult * collect_mult


## Eine Zone ist offen, wenn kein Upgrade sie freischaltet oder dieses gekauft ist.
func is_zone_unlocked(zone_id: String) -> bool:
	for u in config.upgrades:
		if u.unlocks_zone == zone_id:
			return level(u.id) > 0
	return true


func is_tool_unlocked(tool: CleanTool) -> bool:
	if tool.unlocked_from_start:
		return true
	return unlock_source(tool.id) != ""


## Woher ein Werkzeug freigeschaltet ist: "upgrade", "collectible" oder "" (noch gesperrt).
func unlock_source(tool_id: String) -> String:
	for c in config.collectibles:
		if c.unlock_tool == tool_id and has_found(c.id):
			return "collectible"
	for u in config.upgrades:
		if u.unlock_tool == tool_id and level(u.id) > 0:
			return "upgrade"
	return ""


## Kann dieses Upgrade gerade gekauft werden? Leerer Text = ja, sonst der Grund.
func buy_block_reason(u: CleanUpgrade) -> String:
	if level(u.id) >= u.max_level:
		return "max"
	if u.unlock_tool != "" and unlock_source(u.unlock_tool) == "collectible":
		return "found"
	if coins < u.cost(level(u.id)):
		return "coins"
	return ""


func try_buy(id: String) -> bool:
	var u := upgrade(id)
	if u == null or buy_block_reason(u) != "":
		return false
	coins -= u.cost(level(id))
	levels[id] = level(id) + 1
	return true


func affordable_count() -> int:
	var n := 0
	for u in config.upgrades:
		if buy_block_reason(u) == "":
			n += 1
	return n


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"levels": levels,
		"found": found,
		"milestones": milestones_hit,
		"zones_done": zones_done,
		"returned": returned,
		"carried": carried,
		"carried_coins": carried_coins,
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	carried = int(data.get("carried", 0))
	carried_coins = int(data.get("carried_coins", 0))
	var saved_levels: Dictionary = data.get("levels", {})
	for id: String in saved_levels:
		levels[id] = int(saved_levels[id])
	for id: Variant in data.get("found", []):
		found.append(str(id))
	for m: Variant in data.get("milestones", []):
		# ältere Spielstände kannten nur eine Zone und speicherten nur die Prozentzahl
		milestones_hit.append(str(m) if str(m).contains(":") else "main:%d" % int(m))
	for z: Variant in data.get("zones_done", []):
		zones_done.append(str(z))
	for r: Variant in data.get("returned", []):
		returned.append(str(r))
	if bool(data.get("zone_done", false)):
		zones_done.append("main")
