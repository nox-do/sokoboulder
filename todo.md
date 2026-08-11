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
- Sokoban Key-Repeat: System-Repeats verwerfen (`isARepeat`); Hold-Wiederholung
  app-seitig (Anlauf ~0.30s, Intervall ~0.16s, letzte gedrückte Richtung)
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
- `InputMapper`: zustandslos `NSEvent → GameplayIntent?`; `isARepeat` verwerfen
- Buchstaben-Shortcuts (Z/R, ⌘Z/⇧⌘Z/⌘R) über `charactersIgnoringModifiers` (QWERTZ-sicher);
  sonst ⌘/⌃/⌥ blockieren. Edit-Menü bleibt für Maus; Tastatur läuft über Local Monitor
- WASD/Pfeile weiter per Hardware-`keyCode`
- `GameplayInputRouter`: Modal sperrt Input; Outcome-Gate per Key-up; Confirm nur bei frischem Return/Space (keine Repeats, Confirm-Tasten auch im Gameplay getrackt)
- Spike-App: `SokobanPlayController` + `SokobanSpriteView` verdrahten Session, Router und Scene; Demo-Level per Tastatur spielbar
- SpriteKit: FIFO-Animationsqueue (ein Schritt gleichzeitig); Budget 3 → Hard-Resync; Resize/Abort setzt Counter per Generation-Token zurück
- Kein Queue-Drain in `SKScene.update`

### App-Flow-Entscheidungen (Schritt 6)

- `GamePresentationPhase` steuert Overlays; `SessionPhase` steuert Simulationseingaben
- HUD: Level, Züge, Schübe, Goals, Undo/Redo-Verfügbarkeit; Goal-Zähler in `RenderSnapshot`
- Pause-Overlay fokussierbar; Fokusverlust pausiert nur aus `.playing`
- Outcome: 1.5s Delay, dann `outcomeAwaitingChoice` (kein Zwischen-Banner)
- `SokobanBoardScene.whenSettled(revision:)` + festes Timeout (0.45s)
- Skip-Return bestätigt nicht die Ergebnisaktion (`releaseOutcomeLocksPreservingPressedKeys`)
- SwiftUI Commands via `FocusedValues` → dieselben Controller-Methoden
- Fokus: SKView nur initial und beim Wechsel nach `.playing`; Overlay-Keys via Local-Monitor
- Outcome ohne `.defaultAction`; Confirm nur über Router-Gate
- `prepareForNewSession()` vor neuem Session-Bootstrap; In-Session-Restart behält Revisionsstrom

### Audio-Entscheidungen (Schritt 7)

- `AudioDirector` + injizierbares `AudioPlaybackBackend`; Effekte prozedural via AVFAudio, Sokoban-Musik als dokumentiertes CC0-Bundle-Asset
- Lifecycle getrennt vom Revisionsvertrag: `interrupt()` / `resumePlayback()` / `reset()`
- Pause/Fokusverlust emittieren kein `AudioUpdate`; Controller ruft Lifecycle direkt
- `.perform` → Cues einmal; `.synchronize` / Vorwärtslücke → `stopAllEffects` + Musik angleichen; Duplikat/veraltet (`<= last`) verwerfen
- Fokusverlust: immer `interrupt()` (auch Outcome); Aktivierung: `resumePlayback()` nur im Outcome (Pause bleibt bis explizitem Resume)
- Schub: nur `cratePushed` (kein zusätzlicher Schritt-Cue)
- Cues: Schritt, blockiert, Schub, Ziel betreten/verlassen, Level abgeschlossen
- Musik: gebündelter CC0-Playtest-Track bei `.playing`; bei `.completed`/`.failed` stoppen
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
- [x] Sokoban Hold-to-move (Anlauf 0.30s / Intervall 0.16s; 2026-08-03)
- Lautstärke-/Mute-UI, UI-Sounds, Menü-Audio ohne Revision (später)
- weitere CC0-Bundle-Assets für Effekte/Jingles; Sokoban-Playtest-Musik samt Lizenznachweis ist bereits eingebunden

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
- Introvertrag:
  - ungesehener Tutorial-Hinweis erscheint; sichtbarer Schließen-Button + Tastatur (Return/Space/Escape)
  - erstmaliger Hinweis wartet ohne Zeitlimit auf eine bewusste Eingabe; ID → `seenTutorialHintIDs`
  - bereits gesehener Hinweis wird beim normalen Start übersprungen
  - Restart / „Noch einmal“ zeigen den Hinweis nicht erneut
  - Hilfe zeigt Hinweise weiterhin, ohne Fortschritt zu ändern
  - kein Restore-Intro
- Hilfe und Einstellungen aus Launch-Menü und Pause; Return-Origin erhält Pause-Session
- **Settings (Phase 3.3):** `AppSettingsStore` (injizierbares UserDefaults), Reduce-Motion-App-Toggle, Musik-/Effektlautstärke `0...1`, Mute; live an `AudioDirector` / Backend; effektives Reduce Motion = System **ODER** App-Toggle (nur Präsentation/`SokobanBoardScene.prefersReducedMotion`)
- **Settings (Phase 3.5, später):** Audio-Manifest und Audio-Theme-Mapping wiederverwenden die Settings-Schnittstelle; noch nicht gebaut
- Ergebnis: Undo nur bei `canUndo`; Levelauswahl-Aktion ergänzt; bestehende Fokus-/Confirm-/Double-Key-Verträge bleiben

- [x] Präsentationsmodelle + gemeinsame Overlay-Views
- [x] Intro mit explizitem Schließen und dauerhaft erreichbarer Hilfe
- [x] Hilfe / Einstellungen Navigation und Persistenz
- [x] Pause-/Ergebnis-Erweiterung
- [x] Audio-Lautstärken/Mute + Reduce-Motion-Anbindung
- [x] Tests (isolierte Defaults/Scheduler); GameCore + MacGameApp grün
- [x] Nachzug Review: Workspace-NotificationCenter für Reduce Motion; Hilfe/Settings sperren Session-Menübefehle; Mute ohne Loop-Stapel; Hilfe scrollbar

### 3.3a Spieler-UX-Nachzug vor Theme-Arbeit – abgenommen

Vertragsentscheidungen:
- App-eigene Pfeiltasten-Navigation für Hauptmenü, Levelauswahl, Pause,
  Einstellungen und Ergebnis; unabhängig von macOS Full Keyboard Access
- Return/Leertaste aktiviert die markierte Aktion, Escape geht konsistent zurück;
  deaktivierte Einträge werden übersprungen
- HUD und SpriteKit-Board besitzen getrennte Layoutbereiche; lange Ergebnis-,
  Settings- und Levelinhalte sind scrollbar
- Renderereignisse erzeugen sichtbare Symbole für Blockade und Zielwechsel;
  Terrain/Bewohner besitzen bereits nichtfarbliche Semantikmarker als Baseline
- Kompakte VoiceOver-Brettbeschreibung mit Level, Spielerposition, Zielen,
  Zügen und Schüben
- Erstmalige Tutorial-Hinweise warten auf explizites Schließen; gesehene Hinweise
  werden weiterhin übersprungen

- [x] Tastatur-Fokuszyklus und Overlay-Verdrahtung
- [x] Sichtbares Ereignisfeedback und Zielzustandsmarker
- [x] HUD-/Board-Trennung und responsive Scrollbereiche
- [x] Zugängliche Brettzusammenfassung
- [x] Introvertrag ohne 5-Sekunden-Auto-Dismiss
- [x] App-Tests grün

### 3.4 Theme und Renderer-Härtung – abgenommen

Vertragsentscheidungen (Spielerentscheidung 2026-08-02):
- **Skalierung B:** auflösungsunabhängiger Shape-/Vektor-Stil (ADR 0003):
  - quadratische Tiles, konstante Brettproportionen
  - stufenlose Anpassung an verfügbare Fläche
  - scharfe Linien auf Retina (ganzzahlige Brettorigin)
  - keine Gameplay-Geometrie außerhalb des sichtbaren Bereichs
  - Pixel-Art = spätere Theme-Variante, kein 3.4-Vertrag
- **Themes:** versioniertes JSON unter `Resources/Themes/`, validiertes Schema,
  vollständiger Code-Fallback; auswählbares Theme: Standard
  (weitere Themes später möglich; Theme-UI nur bei >1 Option)
- Theme-ID in Settings persistieren
- Erststart ohne Settings-Key → Catalog-`defaultThemeID` seeden
- **Assets:** weiterhin prozedurale Shapes/Symbole, keine Texture-PNGs in 3.4
- **Event-Feedback differenziert:**
  - Blockiert: kurzes × / Ablehnung
  - Schub: mechanischer Impuls am Stein (~180 ms)
  - Ziel betreten/verlassen: semantische Symbole
  - Abschluss: kurze Feier (~500 ms; Ziele pulsieren, Erfolgsrahmen) Teil von
    `whenSettled`; nach Settle/Hard-Resync/Undo Zielsnapshot ohne Feier-Reste;
    Outcome-Timeout 1.5 s; Skip → sofort Outcome
  - Keine Eingabeverzögerung bei normalen Zügen
  - Reduce Motion → sofortige Farb-/Kontur-/Symbolzustände
  - Mute entfernt keine visuelle Information
- **UI-Fokus im Theme-Vertrag:** visuelle Tokens inkl. `focusForeground` für
  Brett, HUD und Overlays; Navigation/Fokusreihenfolge/Tastaturverhalten theme-frei
- Theme-Selektor: fokussierbare Zeile mit direkten Mausaktionen pro Theme

Review-Nachzug:
- [x] P1 High-Contrast Fokus-Text (`focusForeground`) — später Theme entfernt
- [x] P1 Theme-Selektor als fokussierbare Zeile + Fokusvertrag getestet
- [x] P1 Abschlussfeier nach Settle/Undo/Hard-Resync zurückgesetzt
- [x] P2 Outcome-Timeout 1.5 s
- [x] P2 Catalog-`defaultThemeID` beim Erststart
- [x] P2 Status: abgenommen (Playtest 2026-08-03)
- [x] Recovery / Fault / Outcome-Animating an Theme-Tokens
- [x] Tutorial 1 in offenen Raum verlegt; Spieler/Kiste/Ziel im Hinweis benannt
- [x] JSON-Content-Gate gegen statisch tote Kisten-Startfelder
- [x] Sichere Laufzeit-Deadlocks blockieren; alte Deadlock-Saves zurückspulen
- [x] High-Contrast-Theme verworfen (nur Standard); Theme-UI nur bei >1 Option

- [x] ADR Skalierungsstil B (`docs/adr/0003-…`)
- [x] Theme-Schema V1 + Loader + Code-Fallback
- [x] Standard-JSON-Theme
- [x] Settings-Umschalter + Persistenz (`themeID`)
- [x] Renderer: Theme-Tokens, Shapes, Zustandsmarker, Resize ohne Flimmern
- [x] Differenziertes Event-Feedback inkl. Abschlussfeier
- [x] SwiftUI-Overlays/HUD an Theme-Tokens
- [x] Tests (MacGameAppTests)
- [x] Manuelles Playtest-Protokoll (Tastatur, Stumm, Graustufen, Reduce Motion)
  — abgenommen 2026-08-03

### 3.4 Playtest-Nachzug (2026-08-02)

- [x] Pause-Hinweis: „Spielzug-Eingabe gesperrt“ entfernt (nur noch „Escape setzt fort“)
- [x] Ergebnis: Escape → Primäraktion (nächstes Level), nicht Levelauswahl — Spielfluss
- [x] Hauptmenü-Button „Spielstand zurücksetzen“ (Run + Progress → Tutorial 1)
- [x] High-Contrast-Theme entfernt; Settings ohne Theme-Picker bei einem Theme
- [x] Live-Resize: kein Stretch während Fensterskalierung (`duringViewResize` + Geometrie-Sync)

### 3.5 Audio-Manifest + Theme-Mapping – abgenommen

Vertragsentscheidungen (Spieler 2026-08-03):
- **Variante B:** gebündelte WAV/OGG/MP3 für Musik + Effekte/Jingles;
  prozedural nur noch Fallback wenn Datei fehlt
- **Zwei Audio-Themes:** `audio.sokoban` und `audio.cave` (unterschiedliche
  Musik und Cues); Selection über Spielmodus, nicht Settings-Picker
- **Kein Laufzeit-MIDI:** OGA-MIDI nur Produktionsquelle; in der App nur
  vorgerenderte Dateien (wie AUDIO.md §7). Fehlende Renderings = Fallback
- **Fehlende Assets blockieren nicht:** still / prozedural; App bleibt spielbar
- Lautstärken/Mute bleiben Settings 3.3; kein eigener Audio-Theme-Picker nötig
- UI-Sounds und Audiopolishing später (nicht 3.5-Abnahme)

Umgesetzt:
- [x] Schema V1 (`Audio/manifest.json`, `Audio/Themes/audio.{sokoban,cave}.json`)
- [x] Loader + Built-in-Fallbacks + strikte JSON-Validierung
- [x] `AudioContext.game` → Theme-Auswahl; `MusicPlaybackState.themeLoop`
- [x] Backend: Theme-Musikpfad + File-Cues (AVAudioPlayer) + Prozedural-Fallback
- [x] Sokoban Cue-WAVs (Kenney / Robin Lamb / Listener) + THIRD_PARTY_NOTICES
- [x] Tests (Phase35 + bestehende Audio-/Controller-Tests)
- [x] Cave-Cue-WAVs (shared/sokoban/boulderDash + OGA; Musik schon vorher)

### 3.6 Replay-Grundlage – abgenommen

Vertragsentscheidungen:
- `ReplayFileV1` in GameCore: levelID, contentHash, ruleVersion, productive
  Sokoban-Befehle, expectedDigest
- `SokobanStateDigest`: kanonischer SHA-256 (kein Swift-`Hasher`)
- `SokobanReplayRunner`: headless; blockierte Befehle werden abgelehnt
- Kein Renderer/Audio; Cave-Tick-Replays folgen später

- [x] Digest + ReplayFileV1 + Runner + Tests (GameCore)
- [ ] Optional später: Fixture-Datei im Bundle / App-Debug-Export

## Als Nächstes

### Phase 3.7 Cave-Tick-Spike / ADR — spielbarer Demo-Pfad

Plan: `docs/plans/3.7-cave-tick-semantics.md`  
ADR: `docs/adr/0005-cave-tick-semantics.md` (Accepted)

- [x] ADR 0005 Accepted
- [x] Cave-Modell + ASCII + `CaveRules.tick` + Digest (GameCore)
- [x] Golden-Konfliktraster + Bugbot-Fixes
- [x] `CaveSession` Ready → Tick 1 + Catch-up + Demo-Level in App
- [x] Spielauswahl „Höhle“ aktiv (Demo)
- [x] Cave-Visual-Fix: kein Sokoban-Pixel-Floor/Wand/Kiste auf Cave;
  Sand≠Tunnel, Fels grau `●`, Wand ohne Muster, Spieler = Sokoban-Sprite
- [ ] Feinschliff Timing-Golden / volles Phase-4-Polishing
- Danach: Kamera, Kampagne, Gegner (Phase 5); Cave-Musik bereits eingebunden

### Spielauswahl-Hülle – umgesetzt (2026-08-03)

Plan: `docs/plans/3.9-game-selection-and-cave-foundation.md`

- [x] Phase `gameSelection`: Sokoban | Höhle (Demo) | Hilfe | Settings
- [x] Boot → Spielauswahl; frisch + Sokoban → Tutorial; sonst Sokoban-Hub
- [x] Escape / Zurück vom Hub zur Spielauswahl
- [x] Escape / „Spielauswahl“ aus Pause (Sokoban + Höhle) → Spielauswahl
- [x] Tests angepasst
- [x] Cave-Gameplay-Spez in GAMEPLAY/ARCHITECTURE + Plan 3.7 / ADR 0005 (2026-08-03)

### Cave-Shell-Hygiene vor Phase 4 (2026-08-03)

- [x] Cave-Outcome: Diamanten/Zeit/Punkte statt Züge/Schübe/Ziele
- [x] Outcome „Spielauswahl“ → Game Selection (kein Sokoban-Levelpicker)
- [x] Cave-Events → bestehende Audio-Cues (procedural bis Cue-WAVs)
- [x] Hilfe mode-aware (Warten statt Undo; keine Sokoban-Tutorials)
- [x] gameSelectionKeyboard-Test + Docs (Plan 3.9 / ARCHITECTURE-Skizze)
- [x] Space-Confirm im Outcome: `.wait`-Mapping nicht mehr vor Confirm abfangen
- [x] Shared AudioCue-Vokabular + OGA-WAVs (shared/sokoban/boulderDash)
- [x] SFX-Normalisierung (−3 dBFS, Mono 44.1 kHz) + Boulder≠Kiste / Diamant≠Ziel
- [x] Cave-Tod: Terminal-Emission spielt Cues (`.perform`); Cave-Outcome-Delay ~1.2s
- [x] Level-Complete: BGM soft-fadet sofort unter dem Jingle (nicht erst mit Overlay)
- [x] Cave-Erfolg / shared Win: `objectiveCompleted` → `shared/levelCompleted.wav`
- [x] Unbenutzte Duplikat-WAV `shared/objectiveCompleted.wav` entfernt
- [x] Drei Demo-Level (`cave.demo.001`–`003`) + Progression „Nächstes Level“
- [x] Cave-Intro/Ready-Karte (Diamanten, Zeit, Hinweis) vor dem ersten Zug
- [x] Cave-JSON + `cave.manifest.json` + ContentStrings (ASCII-Katalog entfernt)
- [x] Cave-Kampagne erweitert: `cave.demo.004`–`033` (alle 14×9, keine Kamera nötig); Titel-Platzhalter „Höhle N“
- [ ] Optional: RenderSnapshot-eigene Cave-HUD-Felder statt Counter-Hack
- [ ] Optional: Step-Varianten / manuelles Pegel-Playtest
- [ ] Optional: echte DE-Titel für `004`–`033` (aktuell Platzhalter)

### Cave-Sand (Planung 2026-08-05) — Regeln fest, Implementierung offen

Plan: `docs/plans/4.1-cave-sand.md` (Rev. Buddeln statt Coexistence)

MVP fest:
- Occupant `:`, Fall + Diagonal-Rutsch (Sand-auf-Sand lawiniert)
- Buddeln entfernt Sand (keine Coexistence); Spieler blockiert Sand immer (kein Kill)
- Sand kein Round Support; Fels liegt bis Sand weg, dann Nachfall
- Nicht schiebbar; Dirt unverändert

- [x] Produktregeln im Plan nachgezogen (2026-08-05)
- [ ] Freigabe Implementierung
- [ ] GAMEPLAY §6 + Objektmatrix
- [ ] GameCore Rules + Golden-Tests
- [ ] Render Dirt ≠ Sand (Abnahme)
- [ ] Lehr-Levels (Fall / Rutsch≠Roll / Buddeln+Fels-auf-Sand)
- Später optional: Slowdown, Schaufel, Ersticken

### Phase 5 — Erweiterte Höhlenregeln (Entscheidungen 2026-08-05)

Plan 5.1: `docs/plans/5.1-enemies-explosions.md`

Scope laut ARCHITECTURE: Gegner, Explosionen/Ketten, Amöbe, Magische Wand,
Leben/Bonus/Polishing (App-Schicht). Sand (4.1) getrennt.

#### 5.1 Gegner + Explosionen — umgesetzt (2026-08-05)

- [x] Firefly (Linkswand) / Butterfly (Rechtswand)
- [x] Explosionen destructive / diamondGenerating + Ketten-Queue
- [x] Stahlwand unzerstörbar; Ausgang MVP unzerstörbar
- [x] Glyphs `F`/`B`, Digest mit Heading, Render-Shapes
- [x] Golden-Tests + Demo-Level `cave.demo.034`
- [x] Docs nachgezogen (ARCHITECTURE §6.2/7.4–7.6, ADR 0005, Plan 5.1)
- [x] Bugfix: Fall-Impakt belegt Gegnerzelle vor Explosion (`entityMoved` konsistent)
- [x] Pixel-Sprites Firefly/Butterfly (AntumDeluge, gelb/blau Tint, 64×64)
- [x] Gegner: klassische BD-Fly-AI (Prefer-Turn; Gegen-Prefer = Pause; 2×2-Orbit ok)
- [x] Bugfix: Seek/Pivot entfernt (Tür-Oszillation in 034)
- [x] Demo 034: Firefly an Deckenecke + Butterfly unten links in der Kammer
- [x] Explosion: Frames neu vom aktuellen OGA-Sheet (512×256, gelb/orange); Runtime-Multiply-Tint entfernt
- [x] Bugfix: Demo-Außenrahmen `#`→`X` (Stahl/Titanium); Explosionen sprengen den Rand nicht mehr (Original-BD)
- [ ] Explosion-Audio-Cue (Tod-Sound reicht vorerst)
- [ ] Playtest Level 034

#### 5.2a Magische Wand — umgesetzt (2026-08-06)

- [x] Terrain `M` + globaler Status dormant/active/expired
- [x] Fall-Morph Fels↔Diamant (2-Zellen-Sprung); Expired/blockiert/Spieler darunter → vernichten
- [x] Unzerstörbar bei Explosion; Default milling 200 Ticks
- [x] Golden-Tests + Demo `cave.demo.035`
- [x] Plan: `docs/plans/5.2-magic-wall.md`

Arcade-Leben (Regeln fest, **Implementierung später** — nicht im ersten Phase-5-Slice):
- Kein Minecraft-HP; klassischer Arcade-Druck (Leben-Pool)
- Leben nur in der **aktuellen Cave-Session** (nicht kampagnenweit persistiert)
- Tod mit Restleben → Leben −1 → Ready/Neustart desselben Levels
- Leben = 0 → Game Over; Outcome/Navigation **wie bisheriger Steintod**
  (`caveFailed` → „Noch einmal“ / Levelauswahl / Spielauswahl)
- Leben in App-/Fortschrittsschicht, nicht in `CaveRules`
- Bis dahin: Tod bleibt wie jetzt (sofort `caveFailed`, unbegrenztes Retry)

Als Nächstes:
- [x] 5.2b Amöbe — seeded PRNG, Demo 036, Plan `docs/plans/5.2b-amoeba.md`
- [ ] Sand (4.1) vor/nach 5.2?
- Später: Startleben-Anzahl (Kandidat: 3) + Bonusleben nach Level

#### 5.2b Amöbe — umgesetzt (2026-08-06)

- [x] Occupant `A`, seeded `DeterministicRNG`, Lag-1 Ersticken/Übergröße
- [x] Fliege-Kontakt-Explosion; Spielertod; explosionszerstörbar
- [x] Golden-Tests + Demo `cave.demo.036` + Docs
- [x] Bugfix: Slow-Timer BD2 (erst bei Wachstumschance); `amoebaMaxCells: 0` immer auto-resolven
- [x] Demo 036: Amöbe nah an Lücke; Max 48 / Slow 400 (nicht vor dem Siegel zu Fels)
- [ ] Pixel-Sprite Amöbe (Shape reicht vorerst)
- [ ] Playtest Level 036

### Phase 4 — Boulder-Dash-Grundspiel (nächster Block)

- [x] Cave-Pixelpack (`Textures/cave/` + `textures.cave`) — Playtest offen
- [x] Kamera-Vertrag dokumentiert (GAMEPLAY §6.4 / ARCHITECTURE §10.3): Fit vs Camera, minTile 32, Safe Zone 60 %, Look-ahead 0,75, kein maxTile
- [x] Kamera implementiert: `GridGeometry` Fit/Camera, `BoardCamera` Safe-Zone/Look-ahead/Smooth, `SokobanBoardScene` verdrahtet — Playtest mit großem Cave-Level offen
- [x] Bugbot-Fixes: Snap hält Soft-Follow bis zum nächsten Spielerzug; Resize ohne Snapshot pannt nicht
- [x] Cave-Demo `004`–`033` durch v3-Pack ersetzt (Tutorials `001`–`003` unverändert; größere Maps für Kamera-Playtest)
- [x] `cave.demo.004` vergrößert/erschwert (24×19, 5 Diamanten, Zeit 1200): Mehrkammer-Maze für Kamera-Playtest; Gegner-Vorlage → Fallstein-Fallen
- [x] `cave.demo.009` Startkessel repariert: ein Fels, freier Schub auf Wandkante, Diamant unter Schacht (war unlösbar durch OO-Patt)
- [x] `cave.demo.010` Schacht-Puzzle: Fels fällt auf Ausgang, muss seitlich auf Wandkante geschoben werden
- [x] `cave.demo.014`: linker Kammer-Fels auf Erde, links frei zum Wegschieben vom Ausgang
- [x] `cave.demo.029`: schwebende Steine mit Erde abgestützt (fielen/rollten in die Start-Spalte und erschlugen)
- Timing-/Replay-Feinschliff; Cue-Pegel/Varianten optional

### Cave-Fortschritt + Levelauswahl (2026-08-04)

- [x] Tutorials (`001`–`003`) immer freigeschaltet; danach Freischaltung per Abschluss
- [x] `ProgressFileV1` Cave-Felder (Unlock/Completed/Bestwerte Score+Restzeit); Legacy-JSON bleibt lesbar
- [x] Cave-Hub + Levelauswahl (Reuse Launch-/Level-Overlays via `shellCampaign`)
- [x] Levelauswahl-Scroll: `minHeight: 0` + Panel-Maxhöhe, Indikatoren, Fokus folgt per `ScrollViewReader`
- [x] Cheat `U` schaltet alle Level der aktiven Kampagne frei
- [x] Outcome/Pause → Cave-Levelauswahl; Boot: frisch → Tutorial 1, sonst Hub
- Mid-run Cave weiterhin nicht persistiert (Ready beim Wiederöffnen)
- [x] Bugbot-Fixes: Cave-Restart setzt Completion-Flag zurück; Hub-Hilfe nutzt `shellCampaign`

### Cave-Grafik-Recherche (OGA, 2026-08-03) — eingebunden 2026-08-04

- [x] Dirt: [Tileable 200×200 dirt](https://opengameart.org/content/tileable-200x200-dirt-texture) (CC-BY 3.0)
- [x] Wand/Spieler: Dungeon-Kopien; Boulder/Steel aus Wand abgeleitet (BY-SA)
- [x] Diamant: Clint Bellanger Sapphire (CC-BY-SA 3.0)
- [x] Tunnel/Exit aus Dirt + Goal-Glow; Pack unter `Textures/cave/`
- [x] Schema V1 additiv `textures.cave`; Renderer nutzt Pack bei `presentsCaveContent`
- [x] Exit-Farben: closed = cyan (lesbar), open = grün (2026-08-04)
- [x] Firefly/Butterfly: [AntumDeluge Butterfly](https://opengameart.org/content/butterfly)
  (CC-BY/OGA-BY 3.0), gelb bzw. blau getint, 64×64 (2026-08-05)

### 3.8 Pixel-Art-Themes – Dungeon (Default) + Kenney, Playtest offen

Plan: `docs/plans/3.8-pixel-art-themes.md` · ADR 0004

Vertrag (aktuell):
- **`theme.dungeon` Default** (Cobble/Stein/Kiste/Glow/Player-Mix; teils CC-BY / BY-SA)
- **`theme.kenney`** zweites Theme (CC0), umschaltbar in Settings
- `theme.standard` nur Code-Fallback / `DevVisualThemeSwitch.forceVectorStandard`
- Schema V1 additiv; Profil **`pixelNearest`** (continuous + `.nearest`; Legacy-Alias `pixelInteger`)
- Notices + lokale Lizenztexte unter `Textures/Licenses/`

Arbeitspakete:
- [x] Zwei Pixel-Themes + Manifest + Settings-Picker
- [x] Unit-/Integrationstests
- [x] Dungeon-Assets: Floor/Wall-Kontrast + Player-Einzel-Frame
- [x] Kenney-Assets: Floor kühl / Wall warm (Pattern gleich)
- [x] Hygiene 2026-08-03: Profil-Rename, Docs/ADR, orphan `theme.standard.json`, `.tmp` gitignore
- [ ] Manueller Playtest / Release-Gate

### Shell-Refactor SokobanPlayController (2026-08-03)

Extraktion leicht→schwer; Controller bleibt Orchestrierung, Views unverändert:

- [x] `PresentationFactory` — Intro/Pause/Help/Settings/Outcome/A11y Mapping
- [x] `OverlayMenuNavigator` — Fokus + Overlay-Commands (resolve → apply)
- [x] `EmissionApplicator` — Scene+Audio paired halten
- [x] `ActivePlaySession` — Sokoban|Cave Adapter; Pause/Resume/HUD-Caps
- [x] `PlayBootstrapCoordinator` + Restore-Messages/ContentChangePolicy
  (Restore-Edge-Cases bleiben im Controller, Entscheidungen/Copy ausgelagert)

Nachzug SoC (2026-08-03, Review-Smells):

- [x] `PlayMetricsPresentation` — HUD/Outcome/A11y eine Metrik-Quelle
- [x] `SettingsFocusID` — Fokus-IDs/Order zentral
- [x] `SettingsAudioBridge` — Settings↔Audio aus dem Play-Controller
- [x] `ActivePlaySession` — Outcome-Delay / Board-Focus-Flags
- [x] `SokobanBoardScene` — Mode nur via `presentsCaveContent` (keine Heuristik)
- [ ] Später: Mode-Facades für Gameplay/Restart-Branches; Scene Visual-Factory

- Playtest der 90 Kampagnen-Level (nach 3 Tutorials freischaltbar)
- Lösbarkeits-Check (one-shot, 2026-08-03): Codec ≠ Solver. Leichtgewicht-Push-Suche
  beweist Tutorials + mind. campaign.001; ab ~002 oft Budget-Timeout (nicht „unlösbar“).
  Test: `GameCoreTests/CampaignSolvabilityOneShotTests.swift` (manuell, kein CI-Gate)
- Pause: Pfeiltasten — Fix: SKView gibt First-Responder beim Verlassen von `.playing` ab (2026-08-03)
- [x] Menü-Tastatur über Local Monitor + Controller (kein SwiftUI onKeyPress/onMoveCommand; 2026-08-03)
- [x] Sokoban ⌘Z/⇧⌘Z/⌘R: InputMapper (`charactersIgnoringModifiers` für QWERTZ) +
  `focusedSceneObject` für Edit-/Game-Menü-Klicks (2026-08-09)
- [x] Kurze Feier-Pause (1.5s Timer) vor Ergebnis-Overlay (2026-08-03)
- Phase 6: Signierung / Notarisierung / DMG
- Bei ersten externen Swift-Package-Abhängigkeiten: prüfen, ob
  `Package.resolved` für reproduzierbare App-/DMG-Builds eingecheckt werden soll
  (derzeit ignoriert, weil keine Abhängigkeiten existieren)

### Content: Sokoban-Kampagne 001–090 – eingebunden

- [x] 90 Level aus SYAS-Pack (Public Domain), Codec-validiert
- [x] Sortierung leicht→schwer (`schwer`, dann Kisten/Größe)
- [x] JSON `sokoban.campaign.001`–`090`, Manifest, DE-Titel
- [x] Alte 20 Kampagnen-Level ersetzt; Catalog-Tests: 93 Level
- [x] Hinweis in `THIRD_PARTY_NOTICES.md`

### Hintergrundmusik-Auswahl (Settings) – 2026-08-03

- [x] Musik-Track-Katalog `Audio/Music/tracks.json` mit Credits pro Song
- [x] Settings-Picker: Puzzling (Default, CC0) + Prelude (CC-BY 3.0)
- [x] Prelude aus [Old Music](https://opengameart.org/content/old-music) (nur dieser Track)
- [x] Attribution in Settings + `THIRD_PARTY_NOTICES.md`
- [x] Persistenz `settings.musicTrackID` + Director-Pfad-Override
- [x] Höhlen-Musik: Cave Wonder (Default) + Tinkering Cave (CC0, tapatilorenzo)
- [x] Settings: getrennte Auswahl Sokoban / Höhle (`sokobanMusicTrackID`, `caveMusicTrackID`)
- [x] `audio.cave` Default-Pfad auf Cave Wonder

### Cave-Sand Vorbereitung (2026-08-11)

- [x] Demo-Level 001–036: Außenrahmen `#` → `X` (Stahlwand)
- [x] Plan `docs/plans/4.1-cave-sand.md` (Sand als fallende Masse; noch nicht implementiert)
