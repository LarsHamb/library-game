extends RefCounted
## Alle Daten der Bibliothek: Texte, Werkzeuge, Upgrades, seltene Bücher.
## Zahlen hier ändern = Spiel-Balance ändern. Die Regeln dahinter stehen im Kern (addons/clean_core).


static func create() -> CleanGameConfig:
	var c := CleanGameConfig.new()
	c.game_title = "Bibliothek entstauben"
	c.zone_name = "Großer Lesesaal"
	c.currency_name = "Münzen"
	c.mess_name = "Staub"
	c.flake_name = "Flocken"
	c.collectible_group_name = "Seltene Bücher"
	c.welcome_text = "Willkommen im Großen Lesesaal! Halte die linke Maustaste gedrückt, um Staub zu wedeln."
	c.player_start = Vector3(0, 0.05, 12.0)
	c.save_file = "user://bibliothek_spielstand.json"
	c.ui_title_font = "res://game/library/fonts/Cinzel.ttf"
	c.ui_body_font = "res://game/library/fonts/Lora.ttf"

	c.tools.assign([
		CleanTool.make("duster", "Staubwedel", 1, CleanTool.Style.SWEEP),
		CleanTool.make("vacuum", "Staubsauger", 2, CleanTool.Style.SUCK, 0.6, 3.0, 1.4, false),
	])

	# make(id, Name, Beschreibung, Preis, Preisfaktor pro Stufe, max. Stufe, Wert, +pro Stufe, ×pro Stufe, Werkzeug)
	c.upgrades.assign([
		CleanUpgrade.make("radius", "Größerer Wedel", "+0,25 m Radius", 100, 1.8, 8, "radius", 0.25),
		CleanUpgrade.make("power", "Kräftigere Federn", "+25 % Putzkraft", 80, 1.7, 10, "power", 0.0, 0.25),
		CleanUpgrade.make("reach", "Teleskop-Stiel", "+0,6 m Reichweite", 150, 2.0, 5, "reach", 0.6),
		CleanUpgrade.make("speed", "Leise Sohlen", "+12 % Laufen und Klettern", 120, 1.9, 5, "speed", 0.0, 0.12),
		CleanUpgrade.make("value", "Staubhändler", "+25 % Münzen pro Flocke", 300, 2.1, 6, "coin_mult", 0.0, 0.25),
		CleanUpgrade.make("radar", "Radar-Akku", "Radar lädt 3,5 s schneller", 200, 2.0, 4, "radar_cooldown", -3.5),
		CleanUpgrade.make("vacuum", "Staubsauger", "Zweites Werkzeug: schmaler, aber 3× so stark und mit mehr Reichweite", 2500, 1.0, 1, "", 0.0, 0.0, "vacuum"),
		# Automatisierung: jede Stufe = ein Roboter mehr
		CleanUpgrade.make_bot("rail_bot", "Regal-Roboter", "Fährt an einem Regal entlang und putzt alle Böden auf einmal", 400, 1.22, 32, "rail"),
		CleanUpgrade.make_bot("drone", "Saug-Drohne", "Fliegt über die Regale und saugt selbst Staub auf Boden und Tischen", 600, 1.5, 8, "drone"),
		CleanUpgrade.make("bot_speed", "Schnellere Motoren", "+20 % Tempo aller Roboter", 500, 1.8, 6, "bot_speed", 0.0, 0.2),
		CleanUpgrade.make("bot_power", "Bessere Bürsten", "+25 % Putzkraft aller Roboter", 500, 1.8, 6, "bot_power", 0.0, 0.25),
		# Neue Säle (Tür in der linken bzw. rechten Wand des Lesesaals)
		CleanUpgrade.make_zone("open_archive", "Kartenarchiv öffnen", "Neuer Saal: Kartenschränke und Globen, rußiger Staub bringt 1,5× Münzen", 8000, "archive"),
		CleanUpgrade.make_zone("open_dome", "Kuppelsaal öffnen", "Neuer Saal unter der Glaskuppel voller Goldstaub: 2,5× Münzen", 40000, "dome"),
	])

	# make(id, Name, Bonus-Text, Wert, +, ×, Werkzeug)
	c.collectibles.assign([
		CleanCollectibleDef.make("janitor", "Handbuch des Hausmeisters", "+50 % Putzkraft", "power", 0.0, 1.5),
		CleanCollectibleDef.make("winds", "Atlas der Staubwinde", "+0,3 m Radius für alle Werkzeuge", "radius", 0.3),
		CleanCollectibleDef.make("gold", "Chronik des Goldes", "+50 % Münzen", "coin_mult", 0.0, 1.5),
		CleanCollectibleDef.make("feet", "Von leichten Füßen", "+25 % Laufen und Klettern", "speed", 0.0, 1.25),
		CleanCollectibleDef.make("vacuum_plan", "Bauplan: Staubsauger", "Schaltet den Staubsauger frei", "", 0.0, 1.0, "vacuum"),
		CleanCollectibleDef.make("hidden_map", "Karte der verborgenen Winkel", "Radar lädt 30 % schneller", "radar_cooldown", 0.0, 0.7),
		CleanCollectibleDef.make("star_catalog", "Sternenkatalog", "+30 % Putzkraft aller Roboter", "bot_power", 0.0, 1.3),
	])
	return c
