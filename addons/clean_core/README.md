# clean_core – Baukasten für Putzspiele

Der wiederverwendbare Kern für Spiele nach dem Muster „riesige Fläche sauber machen,
erst per Hand, dann immer schneller“. Hier steht nichts über ein bestimmtes Thema drin.

## Was der Kern kann

| Teil | Datei | Aufgabe |
|---|---|---|
| Spielablauf | `core/clean_game.gd` (`CleanGame`) | Verbindet alles, Münzen, Meilensteine, Radar, Speichern, Tasten |
| Spieldaten | `core/game_config.gd` (`CleanGameConfig`) | Texte, Grundwerte, Werkzeuge, Upgrades, Sammelobjekte |
| Spielstand | `core/game_state.gd` (`CleanGameState`) | Münzen, Stufen, Funde; rechnet Werte aus |
| Upgrade | `core/upgrade_def.gd` (`CleanUpgrade`) | Name, Preis, Stufen, Wirkung auf einen Wert oder Werkzeug-Freischaltung |
| Werkzeug | `core/tool_def.gd` (`CleanTool`) | Faktoren für Radius, Kraft, Reichweite; Stil Wischen oder Saugen |
| Sammelobjekt | `core/collectible_def.gd` (`CleanCollectibleDef`) | Verstecktes Objekt mit dauerhaftem Bonus |
| Schmutz | `world/mess_field.gd` (`CleanMessField`) | Zehntausende Flocken mit Dicke, Radar-Leuchten, Speichern |
| Versteck | `world/collectible.gd` (`CleanCollectible`) | Glitzert unter dem Schmutz, taucht beim Putzen auf |
| Zone | `core/zone.gd` (`CleanZone`) | Saal mit eigenem Schmutz, Fortschritt, Münz-Faktor und Türen |
| Leiter | `world/ladder.gd` (`CleanLadder`) | Kletterbereich |
| Roboter | `bots/bot.gd` (`CleanBot`) | Grundlage für alles, was selbst putzt |
| Schienen-Roboter | `bots/rail_bot.gd` (`CleanRailBot`) | Fährt eine Linie ab und putzt auf mehreren Höhen |
| Drohne | `bots/drone.gd` (`CleanDrone`) | Sucht sich selbst Schmutz und saugt ihn von oben ab |
| Spielfigur | `player/cleaner_player.gd` (`CleanPlayer`) | Ego-Perspektive, Werkzeugwechsel, Putz-Ring, Partikel, Klettern |
| Anzeige | `ui/hud.gd`, `ui/shop.gd` | Fortschritt, Münzen, Tempo, Meldungen, Pause-Menü, Upgrade-Laden |
| Geräusche | `audio/synth_sfx.gd` (`CleanSfx`) | Per Code erzeugt, keine Audiodateien nötig |

## Werte, auf die Upgrades wirken

`radius`, `power`, `reach`, `speed`, `coin_mult`, `radar_cooldown`, `bot_speed`, `bot_power`. Grundwerte stehen in
`CleanGameConfig.base_stats`. Rechnung: `(Grundwert + Summe der Plus-Werte) × (1 + Summe der Prozent-Upgrades) × Faktoren der Sammelobjekte`.

## Ein neues Putzspiel bauen

1. Ordner `game/<thema>/` anlegen.
2. `<thema>_config.gd` mit einer Funktion `create() -> CleanGameConfig`: Texte, Werkzeuge, Upgrades, Sammelobjekte.
   Vorlage: `game/library/library_config.gd`.
3. `<thema>_game.gd` mit `extends CleanGame` und diesen Funktionen:
   - `_create_config()` gibt die Config zurück
   - `_build_world()` baut Räume mit `box()`, `mat()`, `add_collider()`, `add_ladder()` und verteilt Schmutz mit `mess.add_area(...)`
   - `_make_tool_visual(tool)` liefert das Modell jedes Werkzeugs (Kindknoten „Head“ wächst mit `player.set_tool_scale`)
   - optional: `_collectible_spots()`, `_make_collectible_model()`, `_build_environment()`, `_tool_display_name()`, `_on_stats_applied()`
4. In `scenes/main.tscn` das Skript auf `<thema>_game.gd` umstellen.
5. Roboter: Upgrade mit `CleanUpgrade.make_bot(..., "rail")` oder `"drone"`. Jede Stufe kauft einen Roboter.
   Schienen legt `_build_world()` mit `add_rail(from, to, heights, facing)` an; eigene Modelle über `_make_bot_model(kind)`.
6. Weitere Säle: `add_zone(id, name, grundfläche, bonus, münzfaktor, farbe)` in `_build_world()`, Schmutz mit `zone.mess.add_area(...)`,
   Tür mit `add_door(...)`, freischalten über `CleanUpgrade.make_zone(..., zone_id)`.
7. Schmutzfarbe ändern: `mess.base_color = Color(...)` am Anfang von `_build_world()`.
8. Aussehen: in der Config `ui_title_font`, `ui_body_font` und die drei `ui_*_color` setzen; daraus baut `CleanTheme` Menü, Anzeige und Laden.
   `_build_environment()` muss `environment` setzen, damit die Grafikstufe im Menü wirkt (`apply_quality`).
9. Musik: `music_file` in der Config (läuft in Schleife, eigener Regler im Menü). Untertitel fürs Startmenü: `game_subtitle`.
10. Startmenü-Kamerafahrt über `_title_view()`, Foto-Rundgang (`godot --path . -- --screenshots`) über `_screenshot_views()`.

Den Ordner `addons/clean_core` kann man unverändert in ein anderes Godot-4.7-Projekt kopieren.
