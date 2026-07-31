# ADR 0001: Keine GitHub-CI; lokale `swift test`-Abnahme

Status: Accepted  
Datum: 2026-07-31

## Kontext

Phase 0 verlangt einen reproduzierbaren `swift test`-Lauf auf einem festgelegten
Swift-6-Toolchainstand. Eine automatisierte GitHub-Actions-Pipeline ist für
dieses Projekt nicht gewünscht.

## Entscheidung

- Es gibt **keine** GitHub-CI und kein `.github/workflows`-Setup.
- Abnahme und Regression erfolgen lokal mit dem dokumentierten Befehl
  `cd Packages/GameCore && swift test`.
- Ziel-Toolchain: Swift 6.3.x / Xcode 26.6 auf dem Entwicklungs-Mac.

## Alternativen

1. **GitHub Actions** – verworfen auf ausdrückliche Projektentscheidung.
2. **Xcode Cloud** – derzeit nicht eingerichtet; für den UI-freien Kern nicht nötig.
3. **Nur ad-hoc Tests ohne dokumentierten Befehl** – verworfen, weil die
   Abnahme von Phase 0 einen festen Testbefehl braucht.

## Folgen

- Kein Remote-CI-Gate für Pull Requests.
- Toolchainstand und Testbefehl bleiben in README und ARCHITECTURE festgehalten.
- Spätere Build-/DMG-Prüfungen folgen lokal bzw. im Distributionsprozess, nicht
  über GitHub Actions.
