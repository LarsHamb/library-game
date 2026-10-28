# Bibliothek entstauben

Ein 3D-Spiel für den PC (Godot 4.7): Du stehst in einer riesigen, verstaubten Bibliothek
und machst sie sauber. Erst per Hand mit dem Staubwedel, später immer schneller.

## Was schon geht

- Ein Saal: der **Große Lesesaal** mit Regalreihen, Lesetischen und einer riesigen Bücherwand
- Ein Werkzeug: der **Staubwedel** (linke Maustaste gedrückt halten)
- Rund 30.000 Staubflocken auf Boden, Regalböden und Tischen. Dicker Staub braucht mehrere Durchgänge
- **Leitern** an jedem Regal, um auch an die oberen (besonders staubigen) Böden zu kommen
- Fortschritt in Prozent, **Münzen** pro Flocke (dicke Flocken bringen mehr), Boni bei 25 / 50 / 75 % und für den sauberen Saal
- Ein Upgrade in 8 Stufen: Der Wedel wird größer und kräftiger
- **Staub-Radar**: lässt den restlichen Staub kurz gelb leuchten
- Geräusche (per Code erzeugt), fliegende Münzen, Pause-Menü mit Maus-Empfindlichkeit und Lautstärke

## Spielen

1. Godot 4.7 starten, im Projektmanager auf **Importieren** klicken.
2. Die Datei `project.godot` in diesem Ordner auswählen und **Importieren & Bearbeiten**.
3. Oben rechts auf ▶ (oder **F5**) drücken.
4. Im Menü auf **Spielen** klicken.

| Taste | Aktion |
|---|---|
| WASD / Pfeiltasten | laufen |
| Maus | umschauen |
| Shift | rennen |
| Leertaste | springen |
| Linke Maustaste (halten) | wedeln |
| An einer Leiter: W / S | hoch- und runterklettern (Leertaste: abspringen) |
| U oder E | Upgrade kaufen |
| R | Staub-Radar |
| Esc | Menü / Pause |

## Aufbau

Die Welt wird komplett im Code erzeugt, damit man alles an einer Stelle anpassen kann.

- `scripts/main.gd` – baut den Saal, hält Münzen, Fortschritt und Upgrade. Alle Zahlen (Kosten, Radius, Boni) stehen oben als Konstanten.
- `scripts/dust_field.gd` – der Staub als ein MultiMesh, mit Raster für schnelles Finden der Flocken
- `scripts/player.gd` – Ego-Perspektive, Wedel, Zielring und Staubwolke
- `scripts/hud.gd` – Anzeige und Pause-Menü (Einstellungen landen in `user://settings.cfg`)
- `scripts/sfx.gd` – alle Geräusche, per Code erzeugt

## Ideen für die nächsten Schritte

- Staubsauger als zweites Werkzeug, später Bücher-Roboter auf Schienen, die automatisch putzen
- Versteckte seltene Bücher im Staub, die neue Upgrades freischalten
- Weitere Säle, die sich nach und nach öffnen; Speichern des Spielstands; Geräusche
