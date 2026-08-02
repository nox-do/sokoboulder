# BoulderDash – Änderungsübersicht

## Phase 0 (Fundament) – abgenommen

- [x] Git-Repository und `.gitignore`
- [x] Lokales Swift-Package `GameCore`
- [x] Verzeichnisstruktur laut ARCHITECTURE.md
- [x] Basisdatentypen `Grid`, `GridPosition`, `Direction`
- [x] Swift-Testing-Ziel
- [x] Lokale `swift test`-Abnahme (keine GitHub-CI)
- [x] Distributionsziel `.dmg` dokumentiert
- [x] Abnahme: `swift test` grün (12 Tests), Rasterzugriff getestet

## Phase 1 (Sokoban-Kern) – abgenommen

Vertragsentscheidungen:
- Parser und Validator getrennt; Regel-Engine nur validierte `SokobanLevel`
- ASCII: `#` Wand, ` ` Boden, `.` Ziel, `$` Kiste, `@` Spieler, `*` Kiste+Ziel, `+` Spieler+Ziel, `-` Void
- Kein pauschales Trimmen (Leerzeichen = Boden); nur finales Zeilenende abschneiden
- Harte Validierung: leer, Zeilenbreite, unbekannte Zeichen, ≠1 Spieler, keine Ziele, Kisten≠Ziele
- Keine Deadlock-/Lösbarkeitsfehler in Phase 1
- `start(level:)` vergibt `playerID` (`EntityID(1)`) und Kisten-IDs ab `2` deterministisch (Rasterreihenfolge)
- Nach `completed`: Eingabe → unverändert, leere Events, `.blocked` (kein `EngineFault`)
- Schub-Eventreihenfolge: `objectPushed` → `entityMoved(player)` → goal-Events → `levelCompleted`
- `SokobanASCIIMap` / `SokobanLevel` / `SokobanState`-Konstruktoren intern; `occupant` nur modul-intern mutierbar
- `start`/`move` prüfen essenzielle Invarianten in allen Builds (`EngineFault`)
- Bereits gelöste Level starten als `.completed`

- [x] Shared Model / Events / Transition / EngineFault
- [x] Sokoban-Zellen, Level, State (`playerID` im State)
- [x] ASCII-Parser + Validator
- [x] SokobanRules
- [x] Unit- und Golden-Tests
- [x] Vertragslücken: interne Konstruktion, Invarianten, initial completed
- [x] P3: `.playing` + `allGoalsCompleted` als Invariantenfehler; move-Doku zu `.failed`
- [x] Abnahme: `swift test` grün, Level lösbar nur in Tests

## Phase 2 (Spielbare Mac-App) – abgenommen

Schritte 1–9 umgesetzt und playtestet. Bewusst ohne Hauptmenü/Spielauswahl;
Audio-Mixer/Settings und CC0-Assets später.

### Preflight-Entscheidungen (fest)

- SDK: aktuell installiertes macOS-SDK
- Deployment-Target: macOS 14.0 (`MACOSX_DEPLOYMENT_TARGET = 14.0`, Package `platforms: [.macOS(.v14)]`)
- Distribution: signierte/notarisierte `.dmg` (Umsetzung erst Phase 6)
- Target/Modul/Scheme: `MacGameApp`
- Öffentlicher Produktname: **SokoBoulder**
- Bundle-Identifier: **`com.sokoboulder.app`** (Tests: `com.sokoboulder.app.tests`)
- Sokoban Key-Repeat: System-Repeats verwerfen (`isARepeat`); keine eigene Hold-Wiederholung in Phase 2
- FIFO-Limit: 2 noch nicht verarbeitete Bewegungsbefehle
- Snapshot: flach, row-major, `(0,0)` links oben; Index `row * width + column`; Länge `width * height`; Helper am Snapshot
- `RenderEntity` nutzt `EntityRef`; Spieler separat; `entities` = Kisten
- `RenderSnapshot` + Mapper in GameCore; `RenderUpdate` / `AudioUpdate` / `GameSession` in MacGameApp/Session
- Signing zunächst automatisch; Distribution später

### Reihenfolge

1. [x] Preflight: Xcode-Projekt, leere SwiftUI-App, GameCore-Abhängigkeit, `xcodebuild`-Smoke
2. [x] `RenderSnapshot` + Mapper (+ Index-Helper), Package-Tests
3. [x] Headless `GameSession` + `RenderUpdate`/`AudioUpdate`, Revisionsvertrag-Tests (ohne SpriteKit)
4. [x] InputMapper (Repeats verwerfen) + Input-Router (Outcome-Gate, Modal) + App-Verdrahtung
5. [x] SpriteKit-Platzhalter (Rechtecke), Hard-Resync, `GridGeometry` + sichtbare Spike-Integration
6. [x] HUD, Abschlussablauf, Undo/Redo/Neustart, Pause-Overlay, macOS-Commands
7. [x] AudioDirector klein, aber vertragstreu
7b. [x] Bundle-ID + `SokobanLevelDescriptor`-Katalog (Vorlauf zu Schritt 8)
8. [x] `SokobanRunFileV1` + Wiederaufnahme
9. [x] Tutorial-UI (Hinweise, Levelwechsel, Abschlussaktion Level 3) — Geometrie/Hashes bereits im Katalog

### Tutorial-/Levelwechsel-Entscheidungen (Schritt 9)

- Kurzes `levelIntro`-Overlay vor dem ersten Zug eines frischen Levels (überspringbar: Return/Space/Escape)
- Wiederaufnahme mitten im Level: kein Intro
- Outcome Level 1–2: Primäraktion „Nächstes Level“ (ersetzt Run-Datei); Level 3: „Tutorial von vorn“
- Keine Levelauswahl-UI in Phase 2
- UI-Texte DE über `AppStringID` / `AppStrings` (i18n-ready Keys, inkl. `tutorialHintID`)
- Hinweis-Texte an klassischen Sokoban-Lehrmomenten: nur schieben, Umweg+Undo/Redo, Kisten blockieren
- Undo/Redo: nur Hinweis in Level 2 (keine erzwingende Geometrie in Phase 2)
- P2-Nachzug: Intro-Audio nach Fokusverlust fortsetzen; Return/Space bestätigt fokussierte Outcome-Aktion; Intro/Outcome-Copy nennt Space
- Pause nach Alt-Tab: `pauseFocusEpoch` + defaultAction setzen Fokus auf „Fortsetzen“ (Return)

### Preflight-Notizen

- Bundle-Identifier: `com.sokoboulder.app`
- `MacGameApp.xcodeproj` am Repo-Root; Quellen unter `MacGameApp/`
- Display-Name: SokoBoulder; Target-Name: MacGameApp
- GameCore `platforms: [.macOS(.v14)]`
- `.gitkeep` unter App-Quellen entfernt (kollidieren mit File-System-Sync-Gruppen)
- Kein `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` am App-Target (nur `@MainActor` an `GameSession`)
- Session-/Revisions-Tests: Target `MacGameAppTests`
- Session-Vertrag nachgeschärft: `.faulted` ohne Render/Audio; produktive Bewegung via `submitMove`; Phase `.created` bis `start()`

### Session-/Input-/Render-Entscheidungen (Schritt 4–5)

- Produktive Bewegung: `submitMove` (enqueue + sync Drain); Queue bleibt Session-Eigentum
- `canAcceptMove` nur `.playing`; `canAcceptSessionCommand` `.playing` | `.outcomePresenting`
- Terminaler Drain: bei `.outcomePresenting` Restqueue verwerfen
- Pause/Fokusverlust: `session.pause()` / `resume()`; Phase `.paused`; Core-Zustand unverändert
- `InputMapper`: zustandslos `NSEvent → GameplayIntent?`; ⌘/⌃/⌥ und `isARepeat` verwerfen
- ⌘Z / ⇧⌘Z bleiben SwiftUI-Commands; Mapper liefert kein Redo über Gameplay-Pfad
- `GameplayInputRouter`: Modal sperrt Input; Outcome-Gate per Key-up; Confirm nur bei frischem Return/Space (keine Repeats, Confirm-Tasten auch im Gameplay getrackt)
- Spike-App: `SokobanPlayController` + `SokobanSpriteView` verdrahten Session, Router und Scene; Demo-Level per Tastatur spielbar
- SpriteKit: FIFO-Animationsqueue (ein Schritt gleichzeitig); Budget 3 → Hard-Resync; Resize/Abort setzt Counter per Generation-Token zurück
- Kein Queue-Drain in `SKScene.update`

### App-Flow-Entscheidungen (Schritt 6)

- `GamePresentationPhase` steuert Overlays; `SessionPhase` steuert Simulationseingaben
- HUD: Level, Züge, Schübe, Goals, Undo/Redo-Verfügbarkeit; Goal-Zähler in `RenderSnapshot`
- Pause-Overlay fokussierbar; Fokusverlust pausiert nur aus `.playing`
- Outcome zweistufig: `outcomeAnimating` (Settle/Timeout/Skip) → `outcomeAwaitingChoice`
- `SokobanBoardScene.whenSettled(revision:)` + festes Timeout (0.45s)
- Skip-Return bestätigt nicht die Ergebnisaktion (`releaseOutcomeLocksPreservingPressedKeys`)
- SwiftUI Commands via `FocusedValues` → dieselben Controller-Methoden
- Fokus: SKView nur initial und beim Wechsel nach `.playing`; Overlay-Keys via Local-Monitor
- Outcome ohne `.defaultAction`; Confirm nur über Router-Gate
- `prepareForNewSession()` vor neuem Session-Bootstrap; In-Session-Restart behält Revisionsstrom

### Audio-Entscheidungen (Schritt 7)

- `AudioDirector` + injizierbares `AudioPlaybackBackend`; Produktion: prozedurale AVFAudio-Töne (keine Fremd-Assets)
- Lifecycle getrennt vom Revisionsvertrag: `interrupt()` / `resumePlayback()` / `reset()`
- Pause/Fokusverlust emittieren kein `AudioUpdate`; Controller ruft Lifecycle direkt
- `.perform` → Cues einmal; `.synchronize` / Vorwärtslücke → `stopAllEffects` + Musik angleichen; Duplikat/veraltet (`<= last`) verwerfen
- Fokusverlust: immer `interrupt()` (auch Outcome); Aktivierung: `resumePlayback()` nur im Outcome (Pause bleibt bis explizitem Resume)
- Schub: nur `cratePushed` (kein zusätzlicher Schritt-Cue)
- Cues: Schritt, blockiert, Schub, Ziel betreten/verlassen, Level abgeschlossen
- Musik: ruhiger synthetischer Loop bei `.playing`; bei `.completed`/`.failed` stoppen
- Spy-Backend-Tests; bestehende Controller-Tests nutzen `NoOpAudioPlaybackBackend`

### Katalog-Entscheidungen (Vorlauf Schritt 8)

- Bundle-ID final: `com.sokoboulder.app`
- `SokobanLevelDescriptor`: id, title, ascii, contentHash (SHA-256), tutorialHintID
- Canonical Hash: ASCII-Map-Zeilen mit `\n` verbunden, kein trailing newline; kein `Hasher`
- Katalog-IDs: `sokoban.tutorial.001`–`003` (spike.demo entfernt)
- Play-Controller startet Katalog-Level 1; Levelwechsel-UI folgt in Schritt 9

### Persistenz-Entscheidungen (Schritt 8)

- GameCore: `SokobanRules.ruleVersion = 1`, semantisches `SokobanCheckpoint` + `checkpoint(from:)` / `restore(level:checkpoint:)` (kein JSON/I/O)
- App-DTO `SokobanRunFileV1` unter `MacGameApp/Persistence/`; Richtungen/Status mit expliziten String-Raw-Values
- Journal + Cursor in `GameSession`; Speichern über `SokobanRunSaveSink`; Schreibgeneration im Persistence-Coordinator/Writer
- Restore ausschließlich per Replay; Undo-/Redo-Stacks aus Zwischenzuständen (`redoStack` so, dass `popLast()` den Zustand direkt nach dem Cursor liefert)
- Kompaktion bei >1000 Befehlen: ältesten Befehl in Checkpoint einrechnen, Undo-Stack mitkürzen
- Pfad: Application Support/SokoBoulder/sokoban-run-v1.json (injizierbar); 256 KiB Limit; atomarer Write; Flush bei Deaktivierung/Beenden
- Fehlende Datei = Erststart; ungültig → `.invalid-<timestamp>` Backup (außer neuer Schemaversion/Lesefehler) + Recovery-Overlay; Schreibfehler nichtterminal
- Abgeschlossener Lauf bleibt speicherbar/undo-fähig bis Restart oder „Nächstes Level“ / „Tutorial von vorn“
- Beenden: `applicationShouldTerminate` → `.terminateLater` + `flush()` enqueued zuerst das gecachte DTO (Generation N), dann `writer.flush()` (kein Sync-Write vor In-flight-Writes)
- Phase 2: einzelnes `Window` (kein `WindowGroup`), eine appweite Persistenz-Instanz
- Nur `schemaVersion > current` unangetastet; ältere Schemas werden quarantänisiert
- Fehlender Application-Support-Pfad → disabled/no-op Store + sichtbare Diagnose (kein stilles Ephemeral)
- Writer: enqueue ersetzt nur `pending`, ein Drain-Worker coalesct und schreibt I/O off-actor

### Bewusst nicht in Phase 2

- gemeinsames `GameRules`-Protokoll
- JSON-Levelsystem (Phase 3)
- generischer Event-Bus
- Animation als Eingabesperre
- Zustandskopie in SpriteKit-Nodes
- Asset-/Audiopolishing vor Hard-Resync
- `ObservableObject` pro Tile/Entity (Session-weit ok)
- eigene Hold-Wiederholung unabhängig von macOS-Repeat
- Lautstärke-/Mute-UI, UI-Sounds, Menü-Audio ohne Revision (später)
- CC0-Bundle-Assets inkl. Lizenznachweis (erst nach Hörprobe laut AUDIO.md)

## Phase 3 (Gemeinsame Plattform) – in Arbeit

Stabilisierung der Plattformverträge (nicht Feature-Sammlung).
Reihenfolge: Inhalt/Identität → Fortschritt/UI → Präsentation/Replay.

### 3.1 Content-Vertrag und Loader – abgenommen

Vertragsentscheidungen:
- Level-JSON V1 ist spielerisch autoritativ: `id`, `game`, `schemaVersion`, Raster, `rules`, String-IDs (`titleID`, optional `goalTextID`/`tutorialHintID`)
- Manifest V1: genau eine Kampagne + Dateipfade + Freischaltreihenfolge; keine doppelten Level-Metadaten
- Bundle behält `Levels/` und `Localization/` (Xcode `explicitFolders`); Pfade relativ zur Resources-Wurzel
- Kein Basename-Fallback bei Ressourcenauflösung (`ContentResourceProvider`)
- `contentHash` = SHA-256 über kanonisch `game` + `schemaVersion` + Zeilen + `rules` (ohne Titel/Assets)
- Striktes JSON: unbekannte Keys und `rules`-Felder abgelehnt; `rules` Pflicht (`{}` in V1)
- Semantik in GameCore (`SokobanLevelJSONCodec`); Bundle-Finden in App (`BundleContentLoader`)
- Level-Titel/Hinweise in `ContentStrings.de.json` (nicht leer); UI-Chrome bleibt in `AppStrings`
- Katalog wird in `SokobanPlayController` injiziert; Load-Fehler → faulted UI statt Crash
- Abnahme: neues Level nur JSON + Manifest + ContentStrings (kein Swift)

Zukunft (nicht blockierend): Bei Schema-Evolution zuerst `schemaVersion` lesen, danach den
passenden Key-Validator anwenden — sonst meldet eine V2-Datei mit neuen Feldern
`unknownKeys` statt `unsupportedSchemaVersion`.

- [x] JSON Level V1 + Manifest V1 + Hashgrenzen
- [x] GameCore Codec/Validierung + Tests
- [x] Bundle-Loader, drei Tutorials als Ressourcen, ContentStrings
- [x] Controller/Restorer auf injizierten Katalog
- [x] GameCore- und App-Tests grün
- [x] Nachzug: Bundle-Ordnerstruktur, eine Kampagne, echte Negativtests, striktes JSON

### 3.2 Fortschritt und Levelnavigation – abgenommen

Vertragsentscheidungen:
- Freischaltung / „jemals abgeschlossen“ an stabiler Level-ID
- Bestwerte an Level-ID + contentHash + ruleVersion (Züge und Schübe getrennt)
- Persistenz bei terminalem Kernübergang; Undo/Restart erlauben erneute Bestwert-Bewertung
- `ProgressFileV1` atomar neben `SokobanRunFileV1`
- Erststart (frisch) → Tutorial 1; nicht frisch → immer Launch-Menü; Fortsetzen restauriert Run
- Neuere Progress-Schemaversion: Original erhalten, Writes disabled
- `firstLevelID` aus Katalog-Reihenfolge; Progress-Diagnosen sichtbar

- [x] ProgressFileV1, Codec, Writer, Fehlerbehandlung
- [x] Abschluss/Rekorde/Unlock verdrahten
- [x] Launch-Menü, Levelauswahl, Fortsetzen
- [x] Tests
- [x] Nachzug P1/P2: Re-complete, Launch vor Restore, V2 read-only, Katalog-Anker, Diagnosen, lastSelected

### Als Nächstes (3.3)

- Gemeinsame Intro-/Hilfe-/Pause-/Ergebnis-UI mit Präsentationsmodellen
- Intro-Wiederholungsregeln (bereits `seenTutorialHintIDs` vorhanden)
- Einstellungen: Bewegung reduzieren, Lautstärken (verbindlich in Phase 3)

### 3.3 Präsentationsplattform und Einstellungen – abgenommen

Vertragsentscheidungen:
- Gemeinsame Präsentationsmodelle (Intro, Hilfe, Pause, Ergebnis, Settings) ohne Sokoban-Regellogik in den Views; Ergebniskennzahlen sind spielneutrale Präsentationszeilen; Controller erzeugt Modelle und verarbeitet Aktionen
- Intro **Variante B** mit Accessibility-Ausnahme:
  - ungesehener Tutorial-Hinweis erscheint; sichtbarer Schließen-Button + Tastatur (Return/Space/Escape)
  - ohne Interaktion Auto-Dismiss nach 5 Sekunden; ID → `seenTutorialHintIDs`
  - bereits gesehener Hinweis wird beim normalen Start übersprungen
  - Restart / „Noch einmal“ zeigen den Hinweis nicht erneut
  - Hilfe zeigt Hinweise weiterhin, ohne Fortschritt zu ändern
  - VoiceOver / assistive Reading (`AssistiveReadingProbe`) verhindert Auto-Dismiss, auch wenn es während des Countdowns aktiviert wird
  - Timer über injizierbaren `DelayedActionScheduler` + Generation; bei inaktiver App pausiert; kein Restore-Intro
- Hilfe und Einstellungen aus Launch-Menü und Pause; Return-Origin erhält Pause-Session
- **Settings (Phase 3.3):** `AppSettingsStore` (injizierbares UserDefaults), Reduce-Motion-App-Toggle, Musik-/Effektlautstärke `0...1`, Mute; live an `AudioDirector` / Backend; effektives Reduce Motion = System **ODER** App-Toggle (nur Präsentation/`SokobanBoardScene.prefersReducedMotion`)
- **Settings (Phase 3.5, später):** Audio-Manifest und Audio-Theme-Mapping wiederverwenden die Settings-Schnittstelle; noch nicht gebaut
- Ergebnis: Undo nur bei `canUndo`; Levelauswahl-Aktion ergänzt; bestehende Fokus-/Confirm-/Double-Key-Verträge bleiben

- [x] Präsentationsmodelle + gemeinsame Overlay-Views
- [x] Intro Variante B (Timer, Generation, A11y-Probe)
- [x] Hilfe / Einstellungen Navigation und Persistenz
- [x] Pause-/Ergebnis-Erweiterung
- [x] Audio-Lautstärken/Mute + Reduce-Motion-Anbindung
- [x] Tests (isolierte Defaults/Scheduler); GameCore + MacGameApp grün
- [x] Nachzug Review: Workspace-NotificationCenter für Reduce Motion; Hilfe/Settings sperren Session-Menübefehle; Mute ohne Loop-Stapel; Hilfe scrollbar

## Später

- Phase 3.4: Theme + Renderer-Härtung
- Phase 3.5: Audio-Manifest + Theme-Mapping (Settings-UI/Persistenz bereits in 3.3)
- Phase 3.6: Replay-Grundlage
- Phase 3.5 (Höhlen-Spike) / Phase 4+: Cave…
- Phase 6: Signierung / Notarisierung / DMG
- Bei ersten externen Swift-Package-Abhängigkeiten: prüfen, ob
  `Package.resolved` für reproduzierbare App-/DMG-Builds eingecheckt werden soll
  (derzeit ignoriert, weil keine Abhängigkeiten existieren)
