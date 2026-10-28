# Bibliothek entstauben

Ein 3D-Spiel für den PC (Godot 4.7): Du stehst in einer riesigen, verstaubten Bibliothek
und machst sie sauber. Erst per Hand mit dem Staubwedel, später immer schneller.

## Was schon geht

- Drei Säle: der **Große Lesesaal**, das **Kartenarchiv** (rußiger Staub, 1,5× Münzen) und der **Kuppelsaal** (Goldstaub, 2,5× Münzen). Die Nebensäle öffnet man im Upgrade-Laden
- Ein Werkzeug: der **Staubwedel** (linke Maustaste gedrückt halten)
- Rund 30.000 Staubflocken auf Boden, Regalböden und Tischen. Dicker Staub braucht mehrere Durchgänge
- **Leitern** an jedem Regal, um auch an die oberen (besonders staubigen) Böden zu kommen
- Fortschritt in Prozent, **Münzen** pro Flocke (dicke Flocken bringen mehr), Boni bei 25 / 50 / 75 % und für den sauberen Saal
- **Upgrade-Laden** (U) mit 7 Upgrades: Radius, Kraft, Reichweite, Tempo, Münzwert, Radar-Akku, Staubsauger
- **Staubsauger** als zweites Werkzeug: schmal, stark, weit (Taste 1/2 oder Mausrad)
- **7 seltene Bücher** unter dem Staub versteckt, jedes mit dauerhaftem Bonus. Sie glitzern leicht, das Radar zeigt sie mit Lichtsäulen
- **Roboter**: Regal-Roboter fahren auf Schienen vor den Regalen und putzen alle Böden, Saug-Drohnen fliegen über die Regale und suchen selbst Staub. Dazu Upgrades für Tempo und Putzkraft aller Roboter
- **Tempo-Anzeige**: Flocken pro Minute
- **Spinnweben** unter den Decken von Lesesaal und Kartenarchiv: gehen nur mit dem **Spinnwebenbesen** (Upgrade) weg und bringen viele Münzen
- **Staub legt sich neu**, sobald Roboter laufen, damit sie dauerhaft Arbeit haben. Während das Spiel aus ist, verdienen die Roboter weiter (bis zu 8 Stunden)
- **Karte** (M): alle Säle mit Fortschritt, Klick auf einen offenen Saal bringt dich dorthin
- **Speichern**: automatisch alle 30 Sekunden, beim Öffnen des Menüs und beim Beenden. „Neues Spiel“ im Menü
- **Staub-Radar**: lässt den restlichen Staub kurz gelb leuchten
- Geräusche (per Code erzeugt), ruhige Hintergrundmusik, fliegende Münzen
- **Grafik**: weicher Staub, prozedurale Holz-, Parkett-, Wand- und Marmor-Shader, Kronleuchter, Rundbogenfenster mit Lichtkegeln im Dunst, Lesetische mit Bankierslampen
- **Startmenü** mit Kamerafahrt durch den Lesesaal, Einstellungen für Maus, Lautstärke, Musik und Grafikstufe (Niedrig / Mittel / Hoch)

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
| 1 / 2 / 3 oder Mausrad | Werkzeug wechseln |
| U oder Tab | Upgrade-Laden |
| R | Staub-Radar |
| M | Karte (Klick auf einen Saal: dorthin gehen) |
| Esc | Menü / Pause |
| F1 | Steuerungshilfe ein/aus |

## Aufbau

Das Projekt ist zweigeteilt, damit man den Kern für weitere Putzspiele wiederverwenden kann:

- `addons/clean_core/` – der wiederverwendbare Kern: Schmutz, Spielfigur, Werkzeuge, Upgrades, Münzen, Sammelobjekte, Radar, Anzeige, Upgrade-Laden, Geräusche, Speichern. Siehe [addons/clean_core/README.md](addons/clean_core/README.md).
- `game/library/` – nur das Bibliotheks-Thema:
  - `library_config.gd` – Texte, Werkzeuge, Upgrades und seltene Bücher als Liste. Hier dreht man an der Balance.
  - `library_game.gd` – baut den Lesesaal, die Werkzeug-Modelle und versteckt die Bücher.

Die Welt wird komplett im Code erzeugt. Spielstand: `user://bibliothek_spielstand.json`, Einstellungen: `user://settings.cfg`
(unter Windows in `%APPDATA%\Godot\app_userdata\Bibliothek entstauben`).

## Als Windows-Programm (.exe) exportieren

1. Einmalig die Export-Vorlagen installieren: im Editor **Editor → Export-Vorlagen verwalten → Herunterladen und installieren**.
2. **Projekt → Exportieren**, Vorlage **Windows** auswählen, **Projekt exportieren**.
3. Das Spiel liegt danach als eine einzige Datei in `build/Bibliothek entstauben.exe`. Der Ordner `build/` ist im Repo schon angelegt (Godot legt ihn nicht selbst an).

Ohne Editor geht es auch auf der Kommandozeile: `godot --headless --path . --export-release "Windows"`

## Werkzeuge

- **Foto-Rundgang**: `godot --path . -- --screenshots` macht Bilder vom Menü, vom Laden und von festen Kamerapunkten und speichert sie in `screenshots/`.
- **Musik neu erzeugen**: `python3 tools/make_music.py` (braucht numpy und ffmpeg) schreibt `game/library/audio/musik.ogg`.
