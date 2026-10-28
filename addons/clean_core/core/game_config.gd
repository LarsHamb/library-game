class_name CleanGameConfig
extends Resource
## Alles, was ein Putzspiel ausmacht, als Daten: Texte, Grundwerte, Werkzeuge, Upgrades, Sammelobjekte.
## Ein neues Spiel = eine neue Config + eine Welt (siehe CleanGame).

@export_group("Texte")
@export var game_title := "Putzspiel"
@export var zone_name := "Zone 1"
@export var currency_name := "Münzen"
@export var mess_name := "Staub"              # "Staub", "Sand", "Schleim" ...
@export var flake_name := "Flocken"           # Einheit für die Tempo-Anzeige
@export var collectible_group_name := "Fundstücke"
@export var welcome_text := ""

@export_group("Grundwerte")
## Grundwerte, auf die Upgrades und Sammelobjekte wirken.
@export var base_stats := {
	"radius": 0.45,          # Meter
	"power": 6.0,            # Schmutzmenge pro Sekunde in der Ringmitte
	"reach": 3.2,            # Meter
	"speed": 1.0,            # Faktor auf Laufen und Klettern
	"coin_mult": 1.0,        # Faktor auf Münzen pro Flocke
	"radar_cooldown": 20.0,  # Sekunden
	"bot_speed": 1.0,        # Faktor auf das Tempo aller Roboter
	"bot_power": 1.0,        # Faktor auf die Putzkraft aller Roboter
}
@export var radar_duration := 6.0
@export var milestones := {25: 500, 50: 1000, 75: 2000}   # Prozent -> Bonus
@export var complete_at := 99.5
@export var complete_bonus := 5000
@export var player_start := Vector3.ZERO
@export var player_start_yaw := 0.0
@export var save_file := "user://savegame.json"

@export_group("Inhalt")
@export var tools: Array[CleanTool] = []
@export var upgrades: Array[CleanUpgrade] = []
@export var collectibles: Array[CleanCollectibleDef] = []
