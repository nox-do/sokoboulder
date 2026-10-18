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

## Screenshots

### Sokoban

![Sokoban-Level mit Kisten und leuchtenden Zielmarkierungen](docs/images/sokoboulder-sokoban.png)

### Höhle

![Höhlen-Level mit Erde, Felsen und Diamanten](docs/images/sokoboulder-cave.png)

## Projektstand

Sokoban und der Höhlen-Demopfad sind spielbar. Die gemeinsame Plattform für
Level-Manifeste, Fortschritt, Einstellungen, Themes, Audio und Replay-Grundlagen
ist umgesetzt. Aktuell offen sind vor allem Playtests, Cave-Sand, weiteres
Polishing. Universal-App, ZIP-/DMG-Packaging und GitHub-Workflows sind
eingerichtet.

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

Stilprüfung und beide Tests gemeinsam: `./scripts/test.sh`. GitHub Actions führt
sie bei Pull Requests und Pushes auf `main` ebenfalls aus.

Swift-Code formatieren beziehungsweise nur prüfen:

```bash
./scripts/format.sh
./scripts/lint.sh
```

Dafür verwenden wir das in Xcode enthaltene `swift-format`, konfiguriert über
`.swift-format` (vier Leerzeichen, 120 Zeichen Zeilenlänge). Es ist keine weitere
Installation nötig. Die Skripte prüfen App, Tests, GameCore und das Swift-Skript
für Release-Grafiken; Build-Verzeichnisse und lokale Experimente bleiben außen vor.
Der Stilcheck läuft auch vor Tests und Release-Builds in CI.
Details und Xcode-Bedienung: [Entwicklung](docs/DEVELOPMENT.md).

Release-Pakete für Apple Silicon und Intel bauen:

```bash
./scripts/package-macos.sh 0.1.0
```

ZIP mit direkt startbarer `SokoBoulder.app`, DMG und Prüfsummen liegen danach
unter `dist/0.1.0/`. Ein Push von `v0.1.0` erzeugt nach erfolgreichen Tests einen
GitHub-Release-Entwurf mit diesen Dateien; manuelle Workflow-Läufe liefern
Downloads als Actions-Artefakte. Details: [Release-Anleitung](docs/RELEASING.md).

Bundle-Identifier: `com.sokoboulder.app` (Tests:
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

Auslieferungsformate sind eine Universal-App im ZIP und eine DMG für macOS 14+.
Die App ist lokal ad-hoc signiert. Apple-Developer-Signierung und
Notarisierung sind bewusst nicht vorgesehen. Beim ersten Download kann macOS eine manuelle
Freigabe verlangen. Installation und Release-Ablauf: [docs/RELEASING.md](docs/RELEASING.md).

Für den eigenen Quellcode ist noch keine Projektlizenz festgelegt. Die
Drittanbieter-Assets unterliegen den jeweils in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dokumentierten Lizenzen.
