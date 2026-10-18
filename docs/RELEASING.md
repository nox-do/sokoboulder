# macOS-Builds und GitHub Releases

## Lokal

Voraussetzungen: macOS mit Xcode 26.6 / Swift 6.3.3 sowie Python 3 mit `venv`
und `pip`. Für das Finder-Layout installiert der erste Packaging-Lauf die in
`scripts/dmg/requirements.txt` festgelegten Build-Abhängigkeiten in
`build/packaging-venv` (Internetzugriff nötig). Für die fertige App reicht
macOS 14; Xcode oder andere Laufzeitpakete sind dort nicht erforderlich.

```bash
./scripts/test.sh
./scripts/package-macos.sh 0.1.0
```

Das Packaging baut in Release-Konfiguration mit `arm64` und `x86_64`.
Es prüft beide Architekturen, Bundle-Version, Buildnummer, App-Signatur und DMG.
Die Tests laufen separat und müssen vor einem Release erfolgreich sein.
`BUILD_NUMBER=42 ./scripts/package-macos.sh 0.1.0` setzt eine eigene Buildnummer
(Standard: 1). Bestehende Ausgabeordner werden nicht überschrieben. Fehlgeschlagene
Builds veröffentlichen keine Teilergebnisse; temporäre Packaging-Dateien werden
entfernt. Test-Builds liegen unter `build/`, Release-Dateien unter `dist/`;
beide sind vom Git-Tracking ausgeschlossen.

Ergebnis in `dist/0.1.0/`:

| Datei | Verwendung |
| --- | --- |
| `SokoBoulder-0.1.0-macos-universal.dmg` | Öffnen, App doppelklicken oder nach „Programme“ ziehen |
| `SokoBoulder-0.1.0-macos-universal.zip` | Entpacken, `SokoBoulder.app` direkt starten |
| `START-HERE.txt` | Installation, Systemanforderungen und erster Start |
| `SHA256SUMS.txt` | SHA-256-Prüfsummen aller drei Dateien |

Prüfsummen im Ausgabeordner mit `shasum -a 256 -c SHA256SUMS.txt` prüfen.
Drittanbieter-Lizenzen liegen innerhalb der App unter
`Contents/Resources/Legal/THIRD_PARTY_NOTICES.md`; die MIT-Projektlizenz liegt
daneben als `LICENSE`. Beide bleiben beim Kopieren erhalten.
Das DMG zeigt nur die App und die Programme-Verknüpfung: Ein Hintergrund erklärt
den direkten Start per Doppelklick und das optionale Installieren per Ziehen.
Fenstergröße, Symbolansicht und Positionen werden als `.DS_Store` direkt im Image
gespeichert; der Build steuert dafür keine Finder-Fenster. Das Spielsymbol nutzt
den bereits im Spiel enthaltenen, attribuierten Saphir. Die eingecheckten
Hintergrund-/Icon-PNGs lassen sich mit
`swift scripts/generate-release-artwork.swift` regenerieren.
Der interne Target-/Executable-Name `MacGameApp` bleibt bestehen; das ausgelieferte
Bundle heißt `SokoBoulder.app`.

## GitHub Actions

- **Build and test:** Pull Requests, Pushes auf `main` sowie manuell. Führt
  zuerst den Swift-Stilcheck, dann GameCore-Tests und die App-Integrationstests aus.
- **Package macOS release:** manuell mit einer Version wie `0.1.0` oder durch
  Push eines Tags wie `v0.1.0`. Führt zuerst dieselben Tests aus, baut dann
  Universal-ZIP und DMG. Die Downloads sind 30 Tage als Workflow-Artefakt verfügbar.
- Nur ein **Tag-Push** erzeugt zusätzlich einen **Release-Entwurf** mit allen
  vier Dateien. Der Entwurf wird anschließend in GitHub geprüft und veröffentlicht.
  Ein erneuter Lauf aktualisiert nur Entwürfe; bereits veröffentlichte Releases
  werden nicht überschrieben. Der manuelle Workflow erzeugt weder Tag noch Release.

Versionen folgen strikt `MAJOR.MINOR.PATCH` ohne führende Nullen; Vorabversionen
mit Suffix werden derzeit nicht unterstützt. Die Tag-/Eingabeversion setzt die
Bundle-Version; die Workflow-Laufnummer setzt die Buildnummer. CI verwendet
`macos-26` und explizit `/Applications/Xcode_26.6.app` (Runner-Inventar:
[GitHub](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)).
Wenn GitHub diese Toolchain entfernt, muss der Pfad bewusst aktualisiert werden.

Beispiel nach Review und Commit der Änderungen:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Die Release-Erstellung nutzt den eingebauten `GITHUB_TOKEN`; nur der separate
Job für Release-Entwürfe erhält `contents: write`. Es sind keine eigenen Tokens
oder Apple-Secrets erforderlich. Die YAML-Dateien müssen zuerst auf GitHub
vorliegen; ein lokaler Build löst keinen Upload aus.

## Signierung und erster Start

Die App wird ausschließlich lokal **ad-hoc signiert**. Damit lässt sich ein Universal-Bundle
ohne Apple-Zertifikat bauen und seine Integrität prüfen. Es bestätigt keine
Entwickleridentität und ersetzt keine Notarisierung.

macOS kann heruntergeladene Apps beim ersten Start blockieren. Bei einer
vertrauenswürdigen Quelle nach dem ersten Startversuch unter
**Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** freigeben.
Siehe [Apples Hinweise zum sicheren Öffnen von Apps](https://support.apple.com/de-de/102445).
Das DMG umgeht Gatekeeper nicht.

Developer-ID-Signierung, Apple-Notarisierung und Stapling sind auf Entscheidung
des Maintainers vom 2026-10-18 bewusst nicht vorgesehen. Es werden weder ein
Apple-Developer-Konto noch Zertifikate oder Apple-Zugangsdaten eingerichtet.
Die lokale Ad-hoc-Signatur benötigt nichts davon; die manuelle Freigabe beim
ersten Download wird als Teil dieses Distributionswegs akzeptiert.

Vor Veröffentlichung: ZIP und DMG auf einem frischen Mac testen, beide Spiele
mit Audio öffnen und macOS 14 sowie Intel separat prüfen. Der Universal-Build
prüft die Intel-Binärdatei, führt sie auf dem ARM-Runner aber nicht aus.
Eigener Quellcode und eigene Dokumentation stehen unter der [MIT-Lizenz](../LICENSE).
Asset-Lizenzen bleiben davon unberührt und stehen in `THIRD_PARTY_NOTICES.md`.
