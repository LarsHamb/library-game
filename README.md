# Bibliothek entstauben

Ein 3D-Spiel für den PC (Godot 4.7): Du stehst in einer riesigen, verstaubten Bibliothek
und machst sie sauber. Erst per Hand mit dem Staubwedel, später immer schneller.

## Prototyp 1 – was schon geht

- Ein Saal: der **Große Lesesaal** mit Regalreihen, Lesetischen und einer riesigen Bücherwand
- Ein Werkzeug: der **Staubwedel** (linke Maustaste gedrückt halten)
- Rund 20.000 Staubflocken auf Boden, Regalböden und Tischen, die beim Wedeln verpuffen
- Fortschritt in Prozent, **Münzen** pro Flocke, Boni bei 25 / 50 / 75 % und für den sauberen Saal
- Ein Upgrade in 8 Stufen: Der Wedel wird größer und putzt eine breitere Fläche

## Spielen

1. Godot 4.7 starten, im Projektmanager auf **Importieren** klicken.
2. Die Datei `project.godot` in diesem Ordner auswählen und **Importieren & Bearbeiten**.
3. Oben rechts auf ▶ (oder **F5**) drücken.
4. Ins Bild klicken, damit die Maus gefangen wird.

| Taste | Aktion |
|---|---|
| WASD / Pfeiltasten | laufen |
| Maus | umschauen |
| Shift | rennen |
| Leertaste | springen |
| Linke Maustaste (halten) | wedeln |
| U oder E | Upgrade kaufen |
| Esc | Maus freigeben |

## Aufbau

Die Welt wird komplett im Code erzeugt, damit man alles an einer Stelle anpassen kann.

- `scripts/main.gd` – baut den Saal, hält Münzen, Fortschritt und Upgrade. Alle Zahlen (Kosten, Radius, Boni) stehen oben als Konstanten.
- `scripts/dust_field.gd` – der Staub als ein MultiMesh, mit Raster für schnelles Finden der Flocken
- `scripts/player.gd` – Ego-Perspektive, Wedel, Zielring und Staubwolke
- `scripts/hud.gd` – Anzeige

## Ideen für die nächsten Schritte

- Leiter als Upgrade, um an die oberen Regalböden zu kommen
- Staubsauger als zweites Werkzeug, später Bücher-Roboter auf Schienen, die automatisch putzen
- Versteckte seltene Bücher im Staub, die neue Upgrades freischalten
- Weitere Säle, die sich nach und nach öffnen; Speichern des Spielstands; Geräusche
