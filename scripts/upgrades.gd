extends RefCounted
## Alle Upgrades und seltenen Bücher an einer Stelle.
## Zahlen hier ändern = Spiel-Balance ändern. Die Wirkung steht in main.gd (_apply_stats).

const UPGRADES := [
	{"id": "radius", "name": "Größerer Wedel", "info": "+0,25 m Radius", "base": 100, "factor": 1.8, "max": 8},
	{"id": "power", "name": "Kräftigere Federn", "info": "+25 % Putzkraft", "base": 80, "factor": 1.7, "max": 10},
	{"id": "reach", "name": "Teleskop-Stiel", "info": "+0,6 m Reichweite", "base": 150, "factor": 2.0, "max": 5},
	{"id": "speed", "name": "Leise Sohlen", "info": "+12 % Laufen und Klettern", "base": 120, "factor": 1.9, "max": 5},
	{"id": "value", "name": "Staubhändler", "info": "+25 % Münzen pro Flocke", "base": 300, "factor": 2.1, "max": 6},
	{"id": "radar", "name": "Radar-Akku", "info": "Radar lädt 3,5 s schneller", "base": 200, "factor": 2.0, "max": 4},
	{"id": "vacuum", "name": "Staubsauger", "info": "Zweites Werkzeug: schmaler, aber 3× so stark und mit mehr Reichweite", "base": 2500, "factor": 1.0, "max": 1},
]

const BOOKS := [
	{"id": "janitor", "name": "Handbuch des Hausmeisters", "perk": "+50 % Putzkraft"},
	{"id": "winds", "name": "Atlas der Staubwinde", "perk": "+0,3 m Radius für alle Werkzeuge"},
	{"id": "gold", "name": "Chronik des Goldes", "perk": "+50 % Münzen"},
	{"id": "feet", "name": "Von leichten Füßen", "perk": "+25 % Laufen und Klettern"},
	{"id": "vacuum_plan", "name": "Bauplan: Staubsauger", "perk": "Schaltet den Staubsauger frei"},
]


static func cost(upgrade: Dictionary, level: int) -> int:
	return roundi(upgrade["base"] * pow(upgrade["factor"], level))


static func book_by_id(id: String) -> Dictionary:
	for b: Dictionary in BOOKS:
		if b["id"] == id:
			return b
	return {}
