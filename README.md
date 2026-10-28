# Strandgut

Ein 3D-Spiel für den PC (Godot 4.7): Die Flut hat jede Menge Müll an den Strand gespült, und du räumst auf.
Erst Stück für Stück mit der Greifzange, später mit Siebmaschinen, Drohnen und Förderbändern.
Unter dem Müll tauchen Schätze auf, überall liegen Muscheln.

Das Repo enthält außerdem das erste Spiel mit demselben Kern, **Bibliothek entstauben** (`scenes/main.tscn`, siehe unten).

## Was der Strand kann

- Drei Strandabschnitte: die **Möwenbucht**, die **Felsenbucht** (Geisternetze und Gezeitentümpel, 1,6× Münzen) und die **Wrackküste** mit altem Schiffswrack (2,5× Münzen). Die Durchgänge im Felsriegel öffnet man im Upgrade-Laden
- **Müll**: über 10.000 Teile Kleinmüll (Kronkorken, Kippen, Plastiksplitter, Strohhalme …), dazu große Teile als 3D-Modelle (Flaschen, Dosen, Tüten, Flipflops, Bojen, Reifen …), oft in **Müllhaufen** mit Bonus, wenn ein Haufen ganz weg ist. Am Spülsaum liegt am meisten
- **Müllsack und Container**: Mit der Greifzange hebt man jedes Teil einzeln auf (klicken oder Taste halten). Es landet im Müllsack (Anzeige oben rechts); Münzen gibt es erst, wenn man den Sack an einem Container oder der Wertstoffstation leert – einfach hinlaufen. Der Sack lässt sich im Laden vergrößern. Maschinen bringen ihren Müll selbst weg
- **Werkzeuge**: Greifzange (Start), Strandrechen, Müllsauger und Netzschneider. Geisternetze an Buhnen, Felsen und Wrack gehen nur mit dem Netzschneider weg
- **Maschinen**: Siebmaschinen fahren Bahnen ab und sieben den Sand, Sammeldrohnen suchen selbst Müll, Förderbänder am Spülsaum fangen ab, was die Wellen anspülen. Sobald Maschinen laufen, spült die Flut immer wieder etwas an. Auch während das Spiel aus ist, sammeln sie weiter (bis zu 8 Stunden)
- **8 Schätze** unter Müllhaufen (Flaschenpost, Goldene Dublone, Kompass …), jeder mit dauerhaftem Bonus
- **44 Muscheln** zum Anklicken: sie fliegen in die Muschelsammlung am Strandkiosk
- **Grafik im Comic-Stil**: dunkle Umrisslinien, Toon-Licht mit harten Schattenkanten, kräftige Farben. Meer mit Wellen, Brandung und Schaum, nasser Sand am Spülsaum, Sandrippeln, Himmel mit Wolken, Dünen mit Strandhafer, Palmen, Strandkörbe, Rettungsturm, Leuchtturm, Segelboote und Möwen. Alles prozedural, ohne Texturdateien
- Musik und Meeresrauschen (per Skript erzeugt), Karte (M), Müll-Radar (R), Speichern wie gehabt

## Bibliothek entstauben

Ein 3D-Spiel für den PC (Godot 4.7): Du stehst in einer riesigen, verstaubten Bibliothek
und machst sie sauber. Erst per Hand mit dem Staubwedel, später immer schneller.

### Was die Bibliothek kann

- Drei Säle: der **Große Lesesaal**, das **Kartenarchiv** (rußiger Staub, 1,5× Münzen) und der **Kuppelsaal** (Goldstaub, 2,5× Münzen). Die Nebensäle öffnet man im Upgrade-Laden
- **Die Bücher stehen im Mittelpunkt**: Jedes der rund 15.000 Bücher ist eingestaubt und wird beim Wedeln Stück für Stück wieder farbig. Ist ein ganzer Regalboden blitzblank, gibt es einen Bonus
- **Verstreute Bücher** liegen auf dem Boden: anklicken, und sie fliegen zurück in ihre Lücke im Regal
- Seltene Bücher stecken zwischen den Regalbüchern; der Boden ist nur noch Nebensache
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

Das Projekt startet mit dem Strand. Die Bibliothek startet man im Editor über `scenes/main.tscn` (Rechtsklick → Szene ausführen).

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
| Linke Maustaste (halten) | Müll aufsammeln (Bibliothek: wedeln) |
| An einer Leiter: W / S | hoch- und runterklettern (Leertaste: abspringen) |
| 1 – 4 oder Mausrad | Werkzeug wechseln |
| U oder Tab | Upgrade-Laden |
| R | Müll-Radar (Bibliothek: Staub-Radar) |
| M | Karte (Klick auf einen Abschnitt: dorthin gehen) |
| Esc | Menü / Pause |
| F1 | Steuerungshilfe ein/aus |

## Aufbau

Das Projekt ist zweigeteilt, damit man den Kern für weitere Putzspiele wiederverwenden kann:

- `addons/clean_core/` – der wiederverwendbare Kern: Schmutz, Spielfigur, Werkzeuge, Upgrades, Münzen, Sammelobjekte, Radar, Anzeige, Upgrade-Laden, Geräusche, Speichern. Siehe [addons/clean_core/README.md](addons/clean_core/README.md).
- `game/beach/` – das Strand-Thema:
  - `beach_config.gd` – Texte, Werkzeuge, Upgrades und Schätze. Hier dreht man an der Balance.
  - `beach_game.gd` – baut die drei Strandabschnitte, verteilt Müll, Netze und Muscheln, Werkzeug- und Maschinenmodelle.
  - `bots/` – Siebmaschine und Förderband; `shaders/` – Sand, Meer, Himmel, Felsen, Müll, Netze, Holz, Pflanzen.
- `game/library/` – nur das Bibliotheks-Thema:
  - `library_config.gd` – Texte, Werkzeuge, Upgrades und seltene Bücher als Liste. Hier dreht man an der Balance.
  - `library_game.gd` – baut den Lesesaal, die Werkzeug-Modelle und versteckt die Bücher.

Die Welt wird komplett im Code erzeugt. Spielstand: `user://strand_spielstand.json` (Bibliothek: `user://bibliothek_spielstand.json`),
Einstellungen: `user://settings.cfg` (unter Windows in `%APPDATA%\Godot\app_userdata\Strandgut`).

## Als Windows-Programm (.exe) exportieren

1. Einmalig die Export-Vorlagen installieren: im Editor **Editor → Export-Vorlagen verwalten → Herunterladen und installieren**.
2. **Projekt → Exportieren**, Vorlage **Windows** auswählen, **Projekt exportieren**.
3. Das Spiel liegt danach als eine einzige Datei in `build/Strandgut.exe`. Der Ordner `build/` ist im Repo schon angelegt (Godot legt ihn nicht selbst an).

Ohne Editor geht es auch auf der Kommandozeile: `godot --headless --path . --export-release "Windows"`

## Werkzeuge

- **Foto-Rundgang**: `godot --path . -- --screenshots` macht Bilder vom Menü, vom Laden und von festen Kamerapunkten und speichert sie in `screenshots/`.
- **Musik neu erzeugen**: `python3 tools/make_beach_audio.py` schreibt Musik und Meeresrauschen des Strands nach `game/beach/audio/`, `python3 tools/make_music.py` die Bibliotheksmusik (beide brauchen numpy und ffmpeg).
