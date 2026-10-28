class_name CleanCollectibleDef
extends Resource
## Ein verstecktes Sammelobjekt (z.B. ein seltenes Buch). Gibt beim Finden einen dauerhaften Bonus.
##
## Wirkung:  wert = (basis + add) * mult   – oder schaltet ein Werkzeug frei.

@export var id := ""
@export var display_name := ""
@export var perk_text := ""
@export var stat := ""
@export var add := 0.0
@export var mult := 1.0
@export var unlock_tool := ""


static func make(p_id: String, p_name: String, p_perk: String, p_stat := "", p_add := 0.0, p_mult := 1.0, p_unlock := "") -> CleanCollectibleDef:
	var c := CleanCollectibleDef.new()
	c.id = p_id
	c.display_name = p_name
	c.perk_text = p_perk
	c.stat = p_stat
	c.add = p_add
	c.mult = p_mult
	c.unlock_tool = p_unlock
	return c
