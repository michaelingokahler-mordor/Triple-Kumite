# Balltest 0.2.2 – Bewegung und Eingabe getrennt geprüft

## 1. Bildausgabe

Der bisherige Balltest 0.2.1 berechnete die Welt korrekt mit 60 Physikschritten pro Sekunde. Diese Zahl sagte nichts über die tatsächlich gezeichneten Bilder aus. Auf diesem Windows-Rechner mit RTX 4070 Laptop GPU und NVIDIA-Treiber 610.62 blockierte die OpenGL-Bildsynchronisation den Ablauf auf etwa 12 Bilder pro Sekunde. Eingaben und Physikschritte wurden zwischen diesen seltenen Bildern verarbeitet.

Gemessen wurden abgeschlossene Zeichenzyklen über `RenderingServer.frame_post_draw`, zusätzlich der Farbwert des Balls im gerenderten Bild. Die Startwartezeit und Ballgeschwindigkeit waren bei allen Vergleichen identisch.

| Kontrollversuch | Bilder in 4,5 s | Median des Bildabstands | 95. Perzentil |
| --- | ---: | ---: | ---: |
| 0.2.1, VSync ein, ohne Bildauslesen | 56 | 81,19 ms | 81,83 ms |
| Arena und Oberfläche ausgeblendet, VSync ein | 56 | 80,85 ms | 83,09 ms |
| VSync ein, zusätzlich 60-FPS-Limit | 56 | 81,25 ms | 83,08 ms |
| VSync aus, 60-FPS-Limit | 271 | 16,66 ms | 17,09 ms |

Das Ausblenden der Darstellung beseitigte die Verzögerung nicht. Das Abschalten von VSync beseitigte sie bei identischer Spiellogik. Damit ist die Synchronisation der Bildausgabe als Auslöser in dieser Umgebung eingegrenzt. Welcher interne Treiber- oder Windows-Mechanismus dafür verantwortlich ist, wurde nicht weiter bestimmt.

Der eigentliche Sichtbarkeitstest las während des kompletten ersten Anflugs jedes gerenderte Bild aus. Vor der Änderung waren es 36 Flugbilder bei rund 83 ms Abstand. Nach alleiniger Änderung der Synchronisation waren es 183 bei rund 16,7 ms. Der Ball fehlte in keinem der ausgelesenen Flugbilder. Die vom Menschen geschätzten zwei bis vier sichtbaren Positionen ließen sich nicht wörtlich reproduzieren; die stark reduzierte Bildrate dagegen schon. Die Messung erfasst den Renderabschluss, nicht die physische Ausgabezeit des Monitors.

`project.godot` setzt jetzt `display/window/vsync/vsync_mode=0` und `application/run/max_fps=60`. Die Physik bleibt bei 60 Hz und die Ballgeschwindigkeit bei 94,8 internen Pixeln pro Sekunde. VSync aus kann je nach Monitor Tearing erzeugen. Die Godot-Dokumentation erläutert diese Abwägung unter [Jitter, Stutter und Input Lag](https://docs.godotengine.org/en/4.5/tutorials/rendering/jitter_stutter.html).

## 2. Controller

Es gab keinen absichtlichen Ein-Sekunden-Takt für den Schild. Zwei andere Eigenschaften waren problematisch:

- Godots Eingabesammlung war aktiv. Sie koppelte die Auslieferung gesammelter Ereignisse an die niedrige Bildrate.
- Der Spielcode übernahm nur den letzten gespeicherten Controllerzustand beim nächsten Physikschritt. Ein kompletter kurzer Richtungsimpuls zwischen zwei Schritten konnte dadurch verloren gehen. Ein Regressionstest mit Drücken und Loslassen vor dem nächsten Physikschritt reproduzierte dies.

Die Ballübung deaktiviert jetzt die Eingabesammlung und übernimmt die Schildausrichtung unmittelbar im Eingabeereignis. Die Simulation bewegt den Ball weiterhin im festen Physikschritt. Bei Rückkehr zum Menü bzw. Wechsel in andere Modi wird die Eingabesammlung wieder eingeschaltet. Die Seite bleibt nach Loslassen erhalten. Die Höhe entspricht dem gehaltenen Steuerkreuz bzw. Stick: Oben, Mitte oder Unten.

Die grafische Prüfung kontrollierte zusätzlich alle sechs Kombinationen aus Seite und Höhe am gezeichneten Schild. Bei deaktivierten Physikschritten reagierten alle sechs korrekt auf eingespeiste Stickereignisse. Von Ereigniseinspeisung bis zum nächsten Bild wurden 16,4–16,8 ms gemessen. Dies misst den Softwarepfad; die Latenz des physischen Controllers, Bluetooth/USB und Monitor kommt hinzu und wurde nicht gemessen. [Godot: Eingabesammlung](https://docs.godotengine.org/en/4.5/classes/class_input.html#class-input-property-use-accumulated-input).

## 3. Drei Ballhöhen

Die geführte Übung verwendet nun gerade Flugbahnen. Ballmitte und Schildmitte liegen exakt auf Y = 257, 273 oder 289 internen Pixeln (Oben, Mitte, Unten). Die frühere sinusförmige Bewegung ist in dieser Übung entfernt, damit horizontale Bewegung und Reaktionszeit isoliert beurteilt werden können. Alle sechs Anflüge sowie falsche benachbarte Schildhöhen sind getestet. Eine spätere Hüpfkurve muss an der Schildposition ebenfalls exakt auf einer dieser drei Höhen ankommen.

## Prüfen

```powershell
godot --headless --path . --script res://tests/smoke.gd
godot --path . --script res://tests/ball_render.gd
godot --headless --path . --export-release "Windows x64" build/Coast-Dojo-Balltest.exe
```

Der zweite Test benötigt Grafik und liest tatsächlich gerenderte Pixel. Er bricht bei weniger als 140 sichtbaren Flugbildern, fehlenden Ballpixeln, einem Bildabstand über 35 ms im 95. Perzentil oder falschen/verzögerten Schildstellungen ab. Er ist bewusst eine Prüfung auf dem Windows-Zielrechner und kein hardwareunabhängiger Unit-Test.

Die aktuelle EXE ist `build/Coast-Dojo-Balltest.exe`. Oben links stehen **BALLTEST 0.2.2** und die gemessene Bildrate. Der nächste Schritt ist die menschliche Gegenprobe mit demselben Controller. Die KI und das Kampftempo wurden in dieser Änderung nicht neu abgestimmt.
