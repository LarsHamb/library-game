extends RefCounted
## Alle Daten des Strand-Themas: Texte, Werkzeuge, Upgrades, Schätze.
## Zahlen hier ändern = Spiel-Balance ändern. Die Regeln dahinter stehen im Kern (addons/clean_core).


static func create() -> CleanGameConfig:
	var c := CleanGameConfig.new()
	c.game_title = "Strandgut"
	c.game_subtitle = "Ein entspanntes Aufräumspiel am Meer"
	c.zone_name = "Möwenbucht"
	c.zone_word = "Strandabschnitt"
	c.bot_word = "Maschinen"
	c.zone_unlocked_text = "Der Weg ist frei: %s!"
	c.currency_name = "Muschelmünzen"
	c.mess_name = "Müll"
	c.flake_name = "Teile"
	c.collectible_group_name = "Schätze"
	c.group_name = "Müllhaufen"
	c.group_bonus = 60
	c.pickup_name = "Muscheln"
	c.pickup_prompt = "[Klick] Muschel einsammeln"
	c.welcome_text = "Willkommen in der Möwenbucht! Die Flut hat jede Menge Müll angespült.\nLinke Maustaste halten: Müll mit der Greifzange aufsammeln. Muscheln anklicken: einsammeln."
	c.player_start = Vector3(0.0, 0.05, -9.0)
	c.player_start_yaw = PI   # Blick aufs Meer
	c.save_file = "user://strand_spielstand.json"
	c.zone_bounds = Rect2(-22.0, -16.0, 44.0, 25.0)   # Möwenbucht für die Karte
	c.ui_title_font = "res://game/beach/fonts/title.tres"
	c.ui_body_font = "res://game/beach/fonts/body.tres"
	c.ui_text_color = Color(0.98, 0.97, 0.93)
	c.ui_accent_color = Color(1.0, 0.72, 0.36)
	c.ui_panel_color = Color(0.03, 0.2, 0.27, 0.86)
	c.ui_overlay_color = Color(0.0, 0.09, 0.13, 0.62)
	c.ui_outline_color = Color(0.0, 0.1, 0.14, 0.85)
	c.music_file = "res://game/beach/audio/musik.ogg"
	c.regrow_per_minute = 0.005   # die Flut spült immer wieder etwas an
	c.offline_coins_per_bot_minute = 14.0
	c.milestones = {25: 600, 50: 1200, 75: 2500}
	c.complete_bonus = 6000

	c.tools.assign([
		# Greifzange: kleiner Radius, man sammelt Stück für Stück. SUCK = der Müll fliegt zu einem hin
		CleanTool.make("grabber", "Greifzange", 1, CleanTool.Style.SUCK, 0.62, 1.0, 1.0),
		CleanTool.make("rake", "Strandrechen", 2, CleanTool.Style.SWEEP, 1.7, 0.75, 1.05, false),
		CleanTool.make("vacuum", "Müllsauger", 3, CleanTool.Style.SUCK, 0.95, 3.0, 1.5, false),
		# Nur damit lösen sich Geisternetze von Felsen und Buhnen
		CleanTool.make("cutter", "Netzschneider", 4, CleanTool.Style.SWEEP, 1.1, 1.3, 1.5, false),
	])

	# make(id, Name, Beschreibung, Preis, Preisfaktor pro Stufe, max. Stufe, Wert, +pro Stufe, ×pro Stufe, Werkzeug)
	var tools := [
		CleanUpgrade.make("radius", "Breitere Greifer", "+0,22 m Radius für alle Werkzeuge", 100, 1.75, 8, "radius", 0.22),
		CleanUpgrade.make("power", "Fester Griff", "+25 % Sammeltempo", 80, 1.7, 10, "power", 0.0, 0.25),
		CleanUpgrade.make("reach", "Teleskopstiel", "+0,6 m Reichweite", 150, 2.0, 5, "reach", 0.6),
		CleanUpgrade.make("speed", "Strandlatschen", "+12 % Lauftempo", 120, 1.9, 5, "speed", 0.0, 0.12),
		CleanUpgrade.make("value", "Pfandsammler", "+25 % Münzen für jedes Teil", 300, 2.1, 6, "coin_mult", 0.0, 0.25),
		CleanUpgrade.make("radar", "Fernglas", "Müll-Radar lädt 3,5 s schneller", 200, 2.0, 4, "radar_cooldown", -3.5),
		CleanUpgrade.make("rake", "Strandrechen", "Breites Werkzeug: zieht viel Kleinkram auf einmal zusammen", 1200, 1.0, 1, "", 0.0, 0.0, "rake"),
		CleanUpgrade.make("cutter", "Netzschneider", "Nur damit lösen sich Geisternetze von Buhnen und Felsen – jedes Netz bringt viele Münzen", 1500, 1.0, 1, "", 0.0, 0.0, "cutter"),
		CleanUpgrade.make("vacuum", "Müllsauger", "Akku-Sauger: 3× so stark und mit mehr Reichweite", 4000, 1.0, 1, "", 0.0, 0.0, "vacuum"),
	]
	for u: CleanUpgrade in tools:
		u.category = "Ausrüstung"
	# Automatisierung: jede Stufe = eine Maschine mehr. Die Höchststufe passt das Spiel an die offenen Buchten an.
	var machines := [
		CleanUpgrade.make_bot("sifter", "Siebmaschine", "Kleiner Traktor mit Sandsieb: fährt eine Bahn am Strand ab und siebt allen Müll heraus", 600, 1.35, 10, "sifter"),
		CleanUpgrade.make_bot("drone", "Sammeldrohne", "Fliegt über den Strand, sucht selbst Müll und greift ihn von oben", 900, 1.5, 8, "drone"),
		CleanUpgrade.make_bot("belt", "Förderband", "Steht am Spülsaum und fängt ab, was die Wellen anspülen", 1500, 1.6, 4, "belt"),
		CleanUpgrade.make("bot_speed", "Stärkere Motoren", "+20 % Tempo aller Maschinen", 500, 1.8, 6, "bot_speed", 0.0, 0.2),
		CleanUpgrade.make("bot_power", "Feinere Siebe", "+25 % Sammelkraft aller Maschinen", 500, 1.8, 6, "bot_power", 0.0, 0.25),
	]
	for u: CleanUpgrade in machines:
		u.category = "Maschinen"
	var zones := [
		CleanUpgrade.make_zone("open_rocks", "Felsenbucht", "Neuer Strandabschnitt hinter den Felsen: Geisternetze und Treibgut, 1,6× Münzen", 9000, "rocks"),
		CleanUpgrade.make_zone("open_wreck", "Wrackküste", "Ein altes Schiffswrack voller Strandgut: 2,5× Münzen", 45000, "wreck"),
	]
	for u: CleanUpgrade in zones:
		u.category = "Neue Strandabschnitte"
	c.upgrades.assign(tools + machines + zones)

	# make(id, Name, Bonus-Text, Wert, +, ×, Werkzeug)
	c.collectibles.assign([
		CleanCollectibleDef.make("bottle", "Flaschenpost", "Ein Brief voller Strandwissen: +50 % Sammeltempo", "power", 0.0, 1.5),
		CleanCollectibleDef.make("doubloon", "Goldene Dublone", "+50 % Münzen", "coin_mult", 0.0, 1.5),
		CleanCollectibleDef.make("compass", "Kompass des Kapitäns", "+25 % Lauftempo", "speed", 0.0, 1.25),
		CleanCollectibleDef.make("amber", "Großer Bernstein", "+0,3 m Radius für alle Werkzeuge", "radius", 0.3),
		CleanCollectibleDef.make("blueprint", "Bauplan: Müllsauger", "Schaltet den Müllsauger frei", "", 0.0, 1.0, "vacuum"),
		CleanCollectibleDef.make("spyglass", "Messing-Fernrohr", "Radar lädt 30 % schneller", "radar_cooldown", 0.0, 0.7),
		CleanCollectibleDef.make("pearl", "Schwarze Perle", "+30 % Sammelkraft aller Maschinen", "bot_power", 0.0, 1.3),
		CleanCollectibleDef.make("figurehead", "Galionsfigur-Amulett", "+30 % Tempo aller Maschinen", "bot_speed", 0.0, 1.3),
	])
	return c
