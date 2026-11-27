# Windows-Prototyp

Die bestätigte Vorlage ist ein lokales Karate-Spiel in Godot für Windows. Eine Pixel-Art-Arena wird mit 640 × 360 Bildpunkten gezeichnet und auf 1280 × 720 ausgegeben. Zwei oder drei Kämpfer teilen eine horizontale Kampffläche. Ein bis drei Menschen spielen lokal, freie Plätze übernimmt der Computer.

## Umsetzung

- `scripts/tournament.gd` verwaltet Kampfwertung, Platzierung und die Reihenfolge aus zwei Kämpfen und einer Bonusrunde. `scripts/fighter.gd` löst Eingaben, Bewegungen und Treffer auf. Die Tests prüfen gespiegelte Eingaben, Trefferpunkte, Knockdown und Doppeltritt.
- `scripts/bonus_round.gd` simuliert Schild und Bomben. Die Tests prüfen Abwehr auf beiden Seiten, Ausweichen, Tritte, Explosionen und die Rückkehr zum Kampf.
- `scripts/local_input.gd` übersetzt Tastatur und Gamepads in dieselben acht Richtungen und eine Aktion. Geräte werden den lokalen Plätzen einzeln zugeordnet. Die Tests speisen Eingaben mehrerer Geräte in die tatsächliche Eingabeverarbeitung ein.
- `scripts/game.gd` verbindet Startmenü, lokale Spielerwahl, Kampf, direkt anwählbare Bonusübungen, Pause und Ergebnis. `scripts/arena_view.gd` zeichnet Hintergrund, Kämpfer und Rückmeldungen. Ein Integrationstest startet alle vier Menüeinträge und durchläuft einen Wechsel vom Kampf zur Bonusrunde und zurück.
- Godot exportiert eine Windows-x64-EXE. Die EXE wird separat gestartet. Ein Screenshot des laufenden Spiels dient zur Sichtprüfung der 720p-Ausgabe.

Der Dreikampf verwendet 30 Sekunden oder sechs Kampfpunkte. In beiden Modi gibt es Punkte für Treffer von vorn und hinten. Das Duell verwendet dieselben Kampfregeln. Anzahl und Tempo der Bonusobjekte sind für diesen Prototyp gewählt. Beide Bonusdisziplinen wechseln sich ab und sind über das Menü direkt erreichbar.

## Arenagrafik

Die Datei `assets/arena.png` wurde aus dem Ergebnis des integrierten ImageGen auf 640 × 360 Bildpunkte gebracht. Die Vorgabe lautete wie folgt.

> Create one original full-bleed wide 16:9 background for a 2D retro karate fighting game called Coast Dojo (do not render any letters). Authentic hand-placed 16-bit Amiga-era pixel art, 640x360 aesthetic, hard pixel clusters, no gradients, no painted textures. Empty flat stone courtyard on a Japanese coast at sunset, viewed straight side-on. Background in upper 72 percent: warm amber sun setting over a blue indigo bay, lavender and peach sky, distant islands, a weathered dark red Japanese gate left of center and wind-shaped pine on the far right. The bottom 28 percent is entirely wide, continuous and level stone terrace playable area, dark muted desaturated blue slate, simple tiles with minimal contrast. Fighters will stand at screen y=84 percent, a clear horizontal sightline with strong readability. Sky and water should remain open and atmospheric. No people, no props anywhere on foreground, no letters, no interface, no frame, no border. Wide cinematic 16:9 canvas.
