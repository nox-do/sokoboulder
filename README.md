# BoulderDash

Native macOS-App mit zwei Rasterspielen (Sokoban-artig und Boulder-Dash-artig)
auf einer gemeinsamen, deterministischen Engine.

Siehe [ARCHITECTURE.md](ARCHITECTURE.md), [GAMEPLAY.md](GAMEPLAY.md) und
[AUDIO.md](AUDIO.md).

## Voraussetzungen

- macOS
- Xcode 26.6
- Swift 6.3.3

## GameCore testen

Das UI-freie Package liegt unter `Packages/GameCore`:

```bash
cd Packages/GameCore
swift test
```

Es gibt keine GitHub-CI; Tests laufen lokal auf der festgelegten Toolchain.

## Verteilung

Das Auslieferungsziel ist eine macOS-`.dmg` (siehe
`docs/adr/0002-dmg-distribution.md`). Packaging folgt in späteren Phasen.

## Projektstand

Phase 0 (Fundament) ist der aktuelle Umsetzungsstand. Das Xcode-App-Target folgt
in Phase 2.
