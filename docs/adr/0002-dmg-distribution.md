# ADR 0002: Verteilung als macOS-`.dmg`

Status: Accepted; ergänzt durch [ADR 0006](0006-github-releases.md) (2026-10-18)

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

- DMG-Erzeugung ist umgesetzt. Developer-ID-Signierung und Notarisierung sind
  gemäß ADR 0006 und Maintainer-Entscheidung vom 2026-10-18 nicht vorgesehen.
- Build-Skripte liefern ein DMG-Artefakt. Seit ADR 0006 kommt ein portables
  App-ZIP hinzu; GitHub Actions übernimmt Tests, Packaging und Release-Entwürfe.
