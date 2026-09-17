# SokoBoulder

SokoBoulder ist eine native macOS-App mit zwei Rasterspielen auf einer
gemeinsamen, deterministischen Swift-Engine:

- **Sokoban:** rundenbasierte Schiebepuzzles mit Undo/Redo, automatischer
  Wiederaufnahme und einer Kampagne aus drei Tutorials plus 90 Leveln.
- **Höhle:** ein Boulder-Dash-artiges Echtzeitspiel mit Gravitation, Diamanten,
  Kamera, Gegnern, Explosionen, magischer Wand und Amöbe.

SwiftUI bildet App-Shell und Overlays, SpriteKit rendert die Spielfelder und
AVFAudio spielt Musik und Effekte. Die Regeln liegen unabhängig von UI und
Rendering im lokalen Swift-Package `GameCore`.

## Projektstand

Sokoban und der Höhlen-Demopfad sind spielbar. Die gemeinsame Plattform für
Level-Manifeste, Fortschritt, Einstellungen, Themes, Audio und Replay-Grundlagen
ist umgesetzt. Aktuell offen sind vor allem Playtests, Cave-Sand, weiteres
Polishing sowie Signierung, Notarisierung und DMG-Verteilung.

Die detaillierte Änderungs- und Aufgabenübersicht steht in [todo.md](todo.md).

## Voraussetzungen

- macOS 14.0 oder neuer
- Xcode 26.6
- Swift 6.3.3

## Bauen und testen

Das UI-freie `GameCore`-Package testen:

```bash
cd Packages/GameCore
swift test
```

Die macOS-App samt Integrationstests testen:

```bash
xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  test
```

Nur die App bauen:

```bash
xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  build
```

Es gibt derzeit keine GitHub-CI; die Tests laufen lokal auf der festgelegten
Toolchain. Bundle-Identifier: `com.sokoboulder.app` (Tests:
`com.sokoboulder.app.tests`).

## Steuerung

| Taste | Aktion |
| --- | --- |
| Pfeiltasten oder WASD | Bewegen |
| Leertaste | In der Höhle einen Tick warten; in Menüs bestätigen |
| ⌘Z oder Z | Sokoban: Undo |
| ⇧⌘Z | Sokoban: Redo |
| M | Sokoban: Ziel unter dem Spieler orange markieren/Markierung entfernen |
| R oder ⌘R | Level neu starten |
| Escape | Pause beziehungsweise zurück |
| Return oder Leertaste | Markierte Menüaktion ausführen |

Der Zielmarker ist eine reine Darstellungshilfe: Er verändert weder Regeln noch
Spielstand und wird beim Levelwechsel zurückgesetzt.

## Dokumentation

- [ARCHITECTURE.md](ARCHITECTURE.md): Module, Zustands- und Simulationsverträge
- [GAMEPLAY.md](GAMEPLAY.md): Bedienung, Spielfluss und Barrierefreiheit
- [AUDIO.md](AUDIO.md): Musik, Effekte, Audio-Mapping und Lizenzstrategie
- [docs/adr](docs/adr): Architekturentscheidungen
- [docs/plans](docs/plans): Feature- und Regelpläne
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): Herkunft und Lizenzen
  eingebundener Assets

## Verteilung und Lizenz

Das geplante Auslieferungsformat ist eine signierte und notarisierte macOS-DMG;
Packaging und Release-Automation folgen in einer späteren Phase.

Für den eigenen Quellcode ist noch keine Projektlizenz festgelegt. Die
Drittanbieter-Assets unterliegen den jeweils in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dokumentierten Lizenzen.
