# Triple Kumite

Spielbarer Windows-Prototyp mit Godot 4.5.1. Starte `build/Triple-Kumite-0.4.0.exe`. F11 wechselt zwischen Vollbild und Fenster.

## Turnier

Das Turnier beginnt im Dreikampf in Japan. Nach drei Runden entscheidet die Zahl der Rundensiege. Bei Gleichstand kämpfen die Führenden im Stechen um den nächsten Treffer. Ein menschlicher Sieger kommt nach Marokko und tritt dort in drei weiteren Runden gegen zwei CPU-Kämpfer an. Gewinnt eine CPU in Japan, endet der Lauf. Im Turnier folgen die Kämpfe direkt aufeinander.

Die lokale Besetzung wählst du vor dem Start. Eine Tastatur kann genau einen Platz übernehmen. Mit zwei Gamepads und Tastatur können drei Personen spielen. Bis zu drei Gamepads ohne Tastatur sind ebenfalls möglich. Freie Plätze übernimmt die CPU.

| Gamepad | Aktion |
| --- | --- |
| Linker Stick oder Steuerkreuz | Gehen und ducken |
| A oder RB | Schlag |
| B oder RT | Tritt |
| X oder LT | Sprung oder Rolle |
| LB | Auf der Stelle umdrehen |
| Start | Pause |
| Y | Steuerung anzeigen |
| View / Back am Sandsack | Ausgangsposition wiederherstellen |

Vorne und hinten beziehen sich auf die Blickrichtung. Wähle die Richtung und tippe eine Aktionstaste an. Eine angenommene Bewegung läuft auch nach dem Loslassen zu Ende. Gehaltene Tasten wiederholen keine Attacke. In der Stick-Neutralstellung lösen A, B und X sowie ihre Schulter-/Trigger-Alternativen keine Bewegung aus.

| Stickrichtung | A / RB | B / RT | X / LT |
| --- | --- | --- | --- |
| Neutral | keine Aktion | keine Aktion | keine Aktion |
| Oben | Kopfstoß | hoher Tritt | Sprung auf der Stelle |
| Vorne oben | Schlag zum Kopf | hoher Tritt | Split / Doppelkick |
| Vorne | Fauststoß | Bauchtritt | Sprungtritt nach vorne |
| Vorne unten | geduckter Fauststoß | Schienbeintritt | Vorwärtsrolle |
| Unten | geduckter Fauststoß | Fußfeger | Sprung auf der Stelle |
| Hinten unten | geduckter Fauststoß mit Drehung | Rückwärtsfeger mit Drehung | Rückwärtsrolle |
| Hinten | Fauststoß mit Drehung | Tritt mit Drehung | Rückwärtssalto |
| Hinten oben | Fauststoß mit Drehung | Tritt mit Drehung | Split / Doppelkick |

Die Bodenrollen bewegen die Figur geduckt über den Boden. Hohe Fauststöße gehen darüber hinweg, Fußfeger können treffen. LT und RT lösen ab 55 Prozent aus und werden unter 35 Prozent erneut scharf. Ein kurzer Folgebefehl in den letzten 100 ms einer Bewegung wird gespeichert.

Die Tastatur verwendet WASD, F als bisherige Aktionstaste und E zum Umdrehen. R setzt am Sandsack zurück.

## Training

Vier einzeln anwählbare Zeitdisziplinen steigern Tempo und Wurffrequenz. Die längste Überlebenszeit jeder Disziplin wird lokal gespeichert und im Trainingsmenü angezeigt. Der Zweikampf verwendet die normalen Kampfregeln.

1. **Fässer** rollen von links in die Arena. Oben + X/LT springt darüber, unten + B/RT löst einen Fußfeger aus.
2. **Pfeile** kommen vom Bogenschützen links. Duck dich mit dem Stick nach unten unter hohen Pfeilen und überspringe tiefe mit oben + X/LT.
3. **Teller** fliegen in drei Höhen. Oben + A/RB schlägt hoch, vorne + B/RT trifft die Mitte und unten + B/RT die tiefe Bahn. Der Kämpfer beginnt nach links gewandt.
4. **Granaten** rollen mit brennender Zündschnur heran. Tritt sie mit unten oder vorne + B/RT aus der Nähe weg, bevor sie explodieren.
5. **Zweikampf** ist ein klassischer Einzelkampf gegen die CPU.

## Testen

Hier liegen der Sandsack mit Gamepad-Anzeige, die geführte Manöverfolge, die Ballübung mit und ohne CPU sowie das bisherige Bombentreten. Am Sandsack zeigt **Gamepad-Test** die Stickachsen, LT/RT, die gedrückten Aktionsgruppen und die ausgeführte Bewegung. R oder View/Back bringt dich zurück an den Sandsack.

## Godot-Projekt

```powershell
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/gamepad.gd
godot --path . --script res://tests/ball_render.gd -- --computer
godot --headless --path . --export-release "Windows x64"
```

Die Pixel-Art-Arenen haben intern 640 × 360 Pixel. Japan nutzt einen Wasserloop aus 24 Bildern. Der Kasbah-Hof in Marokko wurde mit ImageGen erzeugt. Die Kämpfer stammen aus 2D-Spriteblättern von Runway. Die beiliegenden OFL-Dateien gehören zu Barlow Condensed und IBM Plex Mono.
