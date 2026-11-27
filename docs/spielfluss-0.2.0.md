# Spielfluss in Coast Dojo 0.2.0

Die Messung simuliert je 40 Runden im Duell und im Dreikampf mit einem stillstehenden menschlichen Spieler. Die Zeit läuft ab Freigabe des Kampfes. Der Vorspann kommt im Spiel hinzu. Im Dreikampf kann ein CPU-Kämpfer die Runde durch Treffer gegen den anderen CPU-Kämpfer gewinnen. Die Trefferzeit dort zählt nur Runden, in denen der Mensch getroffen wurde.

| Messwert | 0.1.0 | 0.2.0 |
| --- | ---: | ---: |
| Duell bis zum ersten CPU-Treffer, Median | 1,10 s | 2,30 s |
| Duell bis zum Rundenende, Median | 3,63 s | 7,58 s |
| Dreikampf bis zum Rundenende, Median | 5,12 s | 11,40 s |
| Größter horizontaler Positionswechsel pro Physikschritt, Duell | 9,00 px | 1,35 px |
| Größter horizontaler Positionswechsel pro Physikschritt, Dreikampf | 15,50 px | 2,77 px |

## Ursachen und Änderungen

- Ein Treffer versetzte die Figur im selben Frame um acht interne Pixel und setzte eine springende Figur sofort auf Bodenniveau. Jetzt läuft der Rückstoß über zwölf Frames. Die Figur fällt aus ihrer tatsächlichen Höhe zu Boden und richtet sich sichtbar wieder auf.
- Die Kollisionskorrektur verschob überlappende Figuren sofort. Im Dreikampf konnten sich mehrere Korrekturen in einem Frame addieren. Jetzt wird die Korrektur pro Kämpfer auf 1,5 interne Pixel je Physikschritt begrenzt. Die Darstellung interpoliert zwischen den beiden letzten Positionen.
- Die CPU prüfte ihre nächste Aktion alle 14 Frames und konnte einen gerade aufstehenden Gegner erneut angreifen. Jetzt hält sie vor dem ersten Angriff kurz Abstand, legt nach Angriffen Pausen ein und wartet, bis der Gegner wieder angreifbar ist. Nach dem Aufstehen hat der Kämpfer rund ein Drittel einer Sekunde Trefferschutz.
- Der Vorwärtsgang wurde von 120 auf 81 interne Pixel pro Sekunde reduziert. Der Fauststoß trifft nach 13 statt sieben Frames. Längere Tritte haben ebenfalls mehr Vorlauf. Der Rundenstart zeigt länger an, wann die Steuerung freigegeben wird. Das Ergebnis zeigt die Kampfpunkte aller Kämpfer.

## Grafik

Die beiden Runway-Spriteblätter liefern 22 Posen, darunter vier Gehbilder, Spezialtritte und eine Fallfolge. Das Spiel nutzt einen transparenten Sprite-Atlas mit weißem, rotem und blauem Gi. Für die Wasserreflexionen gibt es einen 24-Bilder-Loop. Die Spielversion zeichnet pro Frame einen Ausschnitt eines kleinen PNG-Atlas. Die GIF-Vorschau zeigt die komplette Arena.
