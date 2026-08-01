# BoulderDash

Native macOS-App mit zwei Rasterspielen (Sokoban-artig und Boulder-Dash-artig)
auf einer gemeinsamen, deterministischen Engine.

Produktname: **SokoBoulder** (Target/Modul: `MacGameApp`)

Siehe [ARCHITECTURE.md](ARCHITECTURE.md), [GAMEPLAY.md](GAMEPLAY.md) und
[AUDIO.md](AUDIO.md).

## Voraussetzungen

- macOS
- Xcode 26.6
- Swift 6.3.3
- Deployment-Target: macOS 14.0

## GameCore testen

Das UI-freie Package liegt unter `Packages/GameCore`:

```bash
cd Packages/GameCore
swift test
```

Es gibt keine GitHub-CI; Tests laufen lokal auf der festgelegten Toolchain.

## Mac-App bauen (Phase-2-Smoke)

```bash
xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  build
```

Session-/Revisionsvertrag (ohne SpriteKit):

```bash
xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  test
```

Die App importiert das lokale Package `GameCore`. Bundle-Identifier:
`com.sokoboulder.app` (Tests: `com.sokoboulder.app.tests`).

## Verteilung

Das Auslieferungsziel ist eine macOS-`.dmg` (siehe
`docs/adr/0002-dmg-distribution.md`). Packaging folgt in späteren Phasen.

## Projektstand

Phase 1 (Sokoban-Kern) ist abgenommen. Phase 2 (spielbare Mac-App) ist in Arbeit:
Schritte 1–9 (Tutorial-Hinweise, Levelwechsel, Outcome Level 3) sind umgesetzt.
Phase-2-Abnahme und Feinschliff folgen.
