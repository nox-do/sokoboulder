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

## Phase 2 (Spielbare Mac-App) – in Arbeit

### Preflight-Entscheidungen (fest)

- SDK: aktuell installiertes macOS-SDK
- Deployment-Target: macOS 14.0 (`MACOSX_DEPLOYMENT_TARGET = 14.0`, Package `platforms: [.macOS(.v14)]`)
- Distribution: signierte/notarisierte `.dmg` (Umsetzung erst Phase 6)
- Target/Modul/Scheme: `MacGameApp`
- Öffentlicher Produktname: **SokoBoulder**
- Bundle-Identifier: **noch festlegen** (vor Persistenz/Signierung)
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
7. [ ] AudioDirector klein, aber vertragstreu
8. [ ] `SokobanRunFileV1` + Wiederaufnahme (nach Bundle-ID)
9. [ ] Drei Tutorial-Level nach GAMEPLAY.md

### Preflight-Notizen

- Bundle-Identifier vorerst provisorisch: `dev.local.SokoBoulder` (vor Persistenz ersetzen)
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

### Bewusst nicht in Phase 2

- gemeinsames `GameRules`-Protokoll
- JSON-Levelsystem (Phase 3)
- generischer Event-Bus
- Animation als Eingabesperre
- Zustandskopie in SpriteKit-Nodes
- Asset-/Audiopolishing vor Hard-Resync
- `ObservableObject` pro Tile/Entity (Session-weit ok)
- eigene Hold-Wiederholung unabhängig von macOS-Repeat

## Später

- Phase 3+: JSON, Fortschritt, Themes, Cave, …
- Phase 6: Signierung / Notarisierung / DMG
- Bei ersten externen Swift-Package-Abhängigkeiten: prüfen, ob
  `Package.resolved` für reproduzierbare App-/DMG-Builds eingecheckt werden soll
  (derzeit ignoriert, weil keine Abhängigkeiten existieren)
