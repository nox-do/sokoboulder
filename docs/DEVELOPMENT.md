# Entwicklung und Codequalität

## Formatieren und prüfen

```bash
./scripts/format.sh   # Swift-Dateien einheitlich formatieren
./scripts/lint.sh     # Nur prüfen; Fehler führen zu Exit-Code != 0
./scripts/test.sh     # Stilcheck, GameCore-Tests und App-Integrationstests
```

Wir verwenden das mit Xcode 26.6 gelieferte `swift-format` (6.3.0), keine
zusätzliche Homebrew-/npm-Abhängigkeit. `.swift-format` setzt vier Leerzeichen
und eine Zeilenlänge von 120; die übrigen Regeln folgen dieser Toolchain.
`.editorconfig` beschreibt ergänzend Einrückung, Zeilenenden und abschließende
Zeilenumbrüche für Editoren, die EditorConfig unterstützen.

Die Skripte bearbeiten ausschließlich App, App-Tests, GameCore-Quellen/-Tests,
`Package.swift` und das Swift-Skript für Release-Grafiken. Sie durchlaufen weder
`build/` noch SwiftPM-Caches oder `.tmp/`.

`swift-format` übernimmt die Rolle eines Swift-Formatters plus einfacher
Stilprüfungen. Nicht jede gemeldete Regel lässt sich automatisch korrigieren.
Die verbindliche Prüfung erfolgt lokal und in CI über `scripts/test.sh`;
auch der Release-Workflow verwendet diesen Einstiegspunkt.
Dokumentation: [swiftlang/swift-format](https://github.com/swiftlang/swift-format).

## Verwendung mit Xcode

Im Terminal im Repository-Ordner `./scripts/format.sh` ausführen; Xcode übernimmt
die Änderungen an gespeicherten Dateien. Nach der Bearbeitung
`./scripts/test.sh` laufen lassen. Die vorhandene Xcode-Scheme `MacGameApp`
bleibt für Build, Run und Test verwendbar; ein normaler Xcode-Build führt den
Stilcheck nicht automatisch aus.

Optional lässt sich in **Product → Scheme → Edit Scheme → Build → Pre-actions**
eine lokale Run-Script-Aktion mit folgendem Inhalt einrichten. Unter
„Provide build settings from“ das App-Target wählen:

```bash
"${SRCROOT}/scripts/lint.sh"
```

Der Formatter ist absichtlich kein automatischer, Dateien verändernder
Build-Schritt. Er läuft gezielt über `scripts/format.sh`.

## Weitere Werkzeuge

- [SwiftLint](https://github.com/realm/SwiftLint) bietet zusätzliche Regeln für
  typische Codeprobleme und Konventionen und lässt sich in Xcode einbinden.
  Es ist hier derzeit nicht installiert; Stilregeln würden sich mit dem
  vorhandenen Formatter teilweise überschneiden.
- [SwiftFormat von Nick Lockwood](https://github.com/nicklockwood/SwiftFormat)
  ist ein anderer Formatter, einschließlich Xcode-Erweiterung. Er ist kein
  Bestandteil von Apples `swift-format` und wird hier nicht parallel verwendet.
- Für ungenutzten Swift-Code reicht eine Textsuche nicht: Protokolle, dynamische
  Aufrufe und öffentliche GameCore-APIs benötigen eine gesonderte Prüfung.
  Compiler-Warnungen und Tests gehören deshalb zur Abnahme jeder Bereinigung.

## Repo-Bereinigung vom 2026-10-18

- Unbenutzte `ManualClock` entfernt.
- `CaveDemoLevel` und `SokobanTutorialSolutions` in das Test-Target verschoben.
- Unreferenzierte, byte-identische WAV-Kopien `shared/objectPushed.wav` und
  `shared/collectiblePickedUp.wav` entfernt; verwendete BoulderDash-Varianten und
  ihre Lizenzhinweise bleiben erhalten.
- Redundante Initialisierer, unnötige `try`-/Cast-/Catch-Zweige und ungenutzte
  Bindungen bereinigt; veralteten Settings-Kommentar aktualisiert.
- Swift-Bestand einmal formatiert und Stilprüfung in Test-/CI-Einstieg eingebunden.
- Zu breite `!Packages/**`-Ausnahme aus `.gitignore` entfernt. SwiftPM-Ausgaben
  bleiben ignoriert, Package-Quellen bleiben versionierbar.

Absichtlich erhalten: dynamisch geladene Explosionsframes, bestehende
Spielstand-/Settings-Migrationen, Theme-Kompatibilität und Fehler-Fallbacks.
Gleiche Texturen in verschiedenen Themes behalten ihre semantischen Pfade.
Historische Pläne und abgelöste ADRs sind weiterhin als solche dokumentiert.
`.tmp/` enthält lokale Asset-Experimente und Herkunftsmaterial, keine
versionierten Release-Dateien; diese persönlichen Dateien werden nicht als
vermeintlich toter Quellcode gelöscht.
