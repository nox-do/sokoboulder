# ADR 0006: GitHub-CI und Universal-App als ZIP und DMG

Status: Accepted

Datum: 2026-10-18

Ersetzt: [ADR 0001](0001-ci-swift-test.md); ergänzt [ADR 0002](0002-dmg-distribution.md)

## Kontext

Das Repo soll auf Wunsch des Maintainers einen Build-Workflow und direkt
verwendbare Downloads über GitHub Releases erhalten. `praxis_flow` dient mit
manuellem/Tag-Auslöser, Versionsprüfung und separaten Release-Artefakten als
Vorbild. SokoBoulder braucht als native Swift-App keine Electron-Laufzeit.

## Entscheidung

- Gemeinsame lokale Skripte für GameCore-/App-Tests und Release-Packaging.
- GitHub Actions mit macOS 26 und Xcode 26.6; Tests für PRs und `main`.
- Release-Build als Universal-App (`arm64`, `x86_64`) ab macOS 14.
- DMG mit Programme-Verknüpfung, großen Symbolen und sichtbaren Hinweisen für
  Direktstart und Installation; portables App-ZIP. Lizenzen liegen im App-Bundle.
- Versionsprüfung, Signatur-/Architekturprüfung, DMG-Verifikation und SHA-256.
- Manuelle Packaging-Läufe liefern Workflow-Artefakte. `vMAJOR.MINOR.PATCH`-Tags
  erzeugen nach Tests einen GitHub-Release-Entwurf; Veröffentlichung erfolgt
  nach Review im GitHub-UI. Bereits veröffentlichte Assets werden nicht ersetzt.
- Ausschließlich lokale Ad-hoc-Signatur ohne Apple-Secrets, Zertifikate oder
  Apple-Developer-Konto. Developer-ID-Signierung, Notarisierung und Stapling sind
  auf ausdrückliche Maintainer-Entscheidung vom 2026-10-18 nicht vorgesehen.
  Eine manuelle Gatekeeper-Freigabe beim ersten Download wird akzeptiert.

## Folgen

ADR 0001s Verzicht auf GitHub-CI gilt nicht mehr. Ein ZIP ergänzt das primäre DMG,
um die App auch direkt entpacken und starten zu können. Ein pkg-Installer ist
für diese einzelne App unnötig. Die öffentliche Auslieferung benötigt weiterhin
Tests auf frischen Systemen; Cross-Compilation allein testet keinen Intel-Mac.
Bedienung und Grenzen stehen in [RELEASING.md](../RELEASING.md).
