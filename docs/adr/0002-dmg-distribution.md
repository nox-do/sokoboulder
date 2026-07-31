# ADR 0002: Verteilung als macOS-`.dmg`

Status: Accepted  
Datum: 2026-07-31

## Kontext

Das Produkt ist eine native macOS-App. Die Distributionsform muss früh klar sein,
damit Signierung, Notarisierung und Packaging nicht erst kurz vor Veröffentlichung
entschieden werden.

## Entscheidung

- Das Auslieferungsformat ist eine **`.dmg`**.
- App Store, Sparkle-Updates und andere Kanäle sind damit nicht ausgeschlossen,
  aber das primäre Artefakt der ersten Veröffentlichung ist eine Disk-Image-Datei.

## Alternativen

1. **Mac App Store** – eigene Review-, Sandbox- und IAP-Regeln; nicht das erste Ziel.
2. **Nur `.app`-Zip** – einfacher, aber weniger üblich für Desktop-Installer und
   Volume-Branding.
3. **pkg-Installer** – sinnvoll bei Hilfsdiensten; für eine einzelne App unnötig.

## Folgen

- Phase 6 muss Signierung, Notarisierung und DMG-Erzeugung abdecken.
- Build-Skripte und Release-Checklisten zielen auf ein DMG-Artefakt, nicht auf
  GitHub-Release-Automation als Pflicht.
