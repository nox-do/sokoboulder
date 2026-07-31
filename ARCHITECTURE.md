# Architekturplan: Rasterspiele für macOS

Status: Unabhängig reviewed und zur Umsetzung empfohlen  
Zielplattform: macOS  
Spiele: Sokoban-artiges Schiebepuzzle und Boulder-Dash-artiges Höhlenspiel  
Technologie: Swift 6, SwiftUI, SpriteKit, Swift Testing

## 1. Zielbild

Das Projekt wird eine native macOS-Anwendung, die zwei eigenständige Spiele auf
einer gemeinsamen, deterministischen Raster-Engine anbietet:

- ein rundenbasiertes Schiebepuzzle, bei dem Objekte nur geschoben werden,
- ein zeitgesteuertes Höhlenspiel mit Gravitation, Sammelobjekten, Gegnern und
  Explosionen.

Die Spiellogik wird vollständig von Darstellung, Eingabegeräten und App-Oberfläche
getrennt. Dadurch kann jede Spielsituation ohne SpriteKit und ohne laufende App
getestet, reproduziert und später für Replays oder einen Level-Editor verwendet
werden.

Ein erster Meilenstein gilt als erreicht, wenn ein kleines Sokoban-Level in einer
nativen macOS-App vollständig spielbar ist, Undo, Redo und Neustart funktionieren
und die Kernregeln durch automatisierte Tests abgesichert sind.

## 2. Ziele und Nicht-Ziele

### 2.1 Ziele

- Gemeinsamer Kern für Raster, Level, Eingaben, Ereignisse und Spielzustände.
- Exakte, reproduzierbare Simulation unabhängig von Bildrate und Animation.
- Kleine, verständliche Module mit gerichteten Abhängigkeiten.
- Tastatursteuerung mit vorbereiteter Abstraktion für Gamecontroller.
- Datengetriebene Level, die ohne Änderungen am Swift-Code ergänzt werden können.
- Schnelle Unit-Tests für Regeln und komplette Levelabläufe.
- Pixelgenaue oder moderne skalierbare Darstellung ohne Einfluss auf Regeln.
- Saubere Erweiterbarkeit für Gegner, Explosionen, Punktestand und Zeitlimit.
- Lokale Speicherung von Einstellungen, Fortschritt und Bestzeiten.
- Möglichkeit für Undo und Redo in Sokoban sowie deterministische Replays in
  beiden Spielen.

### 2.2 Nicht-Ziele der ersten Version

- Online-Multiplayer, Accounts, Cloud-Synchronisierung oder Bestenlisten.
- Prozedurale Levelgenerierung.
- Physiksimulation durch SpriteKit- oder andere Starrkörper-Engines.
- Ein allgemeines Entity-Component-System.
- Ein vollständiger grafischer Level-Editor vor dem ersten spielbaren Prototyp.
- Plattformen außerhalb von macOS.
- Kompatibilität mit Original-Leveldateien oder fremden Spiel-Assets.

## 3. Leitende Architekturentscheidungen

### 3.1 Native Apple-Technologien

Die App verwendet SwiftUI für Fenster, Menüs, Einstellungen und Overlays.
SpriteKit stellt das Spielfeld, Animationen und Partikel dar. AVFAudio übernimmt
Musik, Jingles und Soundeffekte in einem vom Renderer getrennten Audiodienst.
Swift Testing prüft den unabhängigen Kern.

In der ersten Version werden keine externen Laufzeitbibliotheken eingebunden.
Das reduziert Build-Risiken, Versionskonflikte und Wartungsaufwand.

### 3.2 Das Modell ist die einzige Wahrheit

Sprite-Nodes besitzen keinen autoritativen Spielzustand. Eine sichtbare Position
wird immer aus dem Modell abgeleitet. Eine Animation darf niemals selbst
entscheiden, ob eine Bewegung zulässig ist oder welche Zelle anschließend belegt
ist.

### 3.3 Diskrete, deterministische Simulation

Alle Regeln operieren auf ganzzahligen Rasterkoordinaten. Es gibt keine
Gleitkommawerte im Kern. Bei identischem Anfangszustand und derselben Folge von
Eingaben und Ticks entsteht immer derselbe Endzustand.

### 3.4 Gemeinsamkeiten teilen, Regeln getrennt halten

Beide Spiele teilen Infrastruktur, aber keine große Klasse mit zahlreichen
Spielmodus-Abfragen. Sokoban und Boulder Dash erhalten zunächst getrennte
Regelmaschinen. Ein gemeinsames Engine-Protokoll wird erst extrahiert, wenn beide
Implementierungen existieren und einen tatsächlich identischen Vertrag benötigen.

### 3.5 Ereignisse verbinden Logik und Darstellung

Eine Regeloperation liefert den neuen Zustand und fachliche Ereignisse wie
`entityMoved`, `objectFell`, `diamondCollected` oder `levelCompleted`.
Renderer und Audiodienst übersetzen diese Ereignisse unabhängig voneinander in
Animationen beziehungsweise akustische Rückmeldungen.

## 4. Systemkontext

```text
┌─────────────────── macOS-Anwendung ───────────────────┐
│                                                       │
│  SwiftUI Shell                                        │
│  Menü · Levelauswahl · HUD · Einstellungen            │
│                       │                               │
│                       ▼                               │
│  GameSession / Application Layer                      │
│  Lebenszyklus · Eingaben · Tick · Verlauf · Save      │
│          │                 │                 │         │
│          ▼                 ▼                 ▼         │
│  GameCore          SpriteKit Renderer    AudioDirector│
│  Welt · Regeln     Tiles · Animation     Musik · Cues │
│  Events · Replay   Partikel              Effekte      │
│          │                                            │
│          ▼                                            │
│  Level- und Fortschrittsdateien                        │
└───────────────────────────────────────────────────────┘
```

Abhängigkeitsregel:

```text
App/UI ───────► GameSession ───────► GameCore
   │                 │
   │                 ├──────► Renderer
   │                 └──────► AudioDirector
   └────────────────────────► AudioDirector (App-Audiozustand und UI-Cues)

GameCore kennt weder SwiftUI noch SpriteKit, AVFAudio, AppKit oder
Dateisystemdetails. Renderer und AudioDirector kennen einander nicht.
```

## 5. Module und Verantwortlichkeiten

### 5.1 `GameCore`

Lokales Swift-Package ohne UI-Frameworks.

Verantwortlich für:

- Rasterkoordinaten und Richtungen,
- gemeinsame Rastertypen sowie getrennte Weltzustände pro Spiel,
- Leveldefinitionen und Validierung,
- Eingabeabsichten,
- konkrete Sokoban-Regeln,
- konkrete Boulder-Dash-Regeln und feste Simulationsticks,
- fachliche Ereignisse,
- Sieg, Niederlage, Punktestand und verbleibende Zeit,
- Replay-Befehle und stabile Zustandsprojektionen,
- deterministische Zufallsquelle, falls später erforderlich.

Nicht verantwortlich für:

- Tastencodes,
- Animationen oder Sprite-Nodes,
- Fenster und Menüs,
- Dateiauswahldialoge,
- konkrete Speicherorte.

### 5.2 Content Loader

In Version 1 liegt der Resource Loader im App-Target. Er übernimmt:

- Level-Manifeste,
- Leveldateien,
- Metadaten wie Name, Autor, Reihenfolge und Schwierigkeitsgrad,
- Präsentationsmetadaten wie Zieltext- und Tutorial-Hinweis-IDs,
- Tileset- und Theme-Beschreibungen,
- Audio-Manifeste und deren Bundle-Ressourcen.

Die strukturelle Levelvalidierung gehört in `GameCore`; das Auffinden von
Bundle-Ressourcen gehört in den App-Loader. Ein eigenes `GameContent`-Modul wird
erst extrahiert, wenn Tools oder importierte Benutzerlevel denselben Loader
benötigen.

### 5.3 `GameSession`

Anwendungsschicht zwischen UI, Renderer, Audiodienst und Kern.

Verantwortlich für:

- Starten, Pausieren, Fortsetzen und Beenden einer Partie,
- Weiterleitung normalisierter Eingaben,
- alleiniger Besitz von Input-Queue, Accumulator, Revision und Tick-Takt,
- Ausführen und Puffern von Kernereignissen,
- Aufbau unveränderlicher Render-Snapshots und Audio-Kontexte,
- Ready-State des Höhlenspiels,
- Undo, Redo, Neustart und Levelwechsel,
- Fortschritts- und Bestzeiten-Service,
- Unterbrechung bei inaktivem Fenster oder geöffnetem Menü.

`GameSession` läuft auf dem Main Actor und ist die einzige Instanz, die den
laufenden Zustand und die Simulationsuhr verändern darf. Der Kern bleibt synchron
und schnell. Eine Parallelisierung der kleinen Rasterberechnungen ist nicht
vorgesehen.

### 5.4 `GameRenderer`

SpriteKit-basierte Darstellung.

Verantwortlich für:

- Aufbau und Skalierung des Rasterbildes,
- Zuordnung fachlicher Tile- und Entity-Arten zu Texturen,
- Animation von Bewegungen, Fallen, Sammeln und Explosionen,
- Kamera und sichtbaren Höhlenausschnitt,
- visuelles Debug-Overlay,
- Partikel.

Der Renderer darf bei übersprungenen oder abgebrochenen Animationen jederzeit
vollständig aus einem `RenderSnapshot` neu aufgebaut werden.

### 5.5 `GameAudio`

AVFAudio-basierter Anwendungsdienst, dessen Einstiegspunkt `AudioDirector` ist.

Verantwortlich für:

- geordnete Verarbeitung von `AudioUpdate`s,
- Abbildung fachlicher Ereignisse auf Audio-Cues anhand eines Audio-Themes,
- Hintergrundmusik und Übergänge zwischen Musikzuständen,
- getrennte Busse für Musik, Jingles, Spiel- und UI-Effekte,
- Lautstärke, Stummschaltung, Ducking und Voice-Limits,
- Freigabe aller Stimmen bei Pause, Fokusverlust und Levelwechsel.

Nicht verantwortlich für:

- Spielregeln oder Siegbedingungen,
- Fortschreiben des autoritativen Zustands,
- Entscheidung, ob ein fachliches Ereignis stattgefunden hat,
- Blockieren oder Bestätigen von Simulation und Rendering.

Konkrete Musikrichtungen, MIDI-Strategie, Ereigniszuordnungen, Asset-Kandidaten
und Lizenzregeln stehen ausschließlich in [AUDIO.md](AUDIO.md).

### 5.6 `MacGameApp`

SwiftUI-App-Target.

Verantwortlich für:

- Hauptfenster und macOS-Menübefehle,
- Startbildschirm und Spielauswahl,
- Levelauswahl,
- HUD, Pause, Ergebnisdialoge und Einstellungen,
- Fokus und Tastatureingabe,
- Einbettung der SpriteKit-Ansicht,
- Game-Flow-Zustand und begrenzte terminale Präsentationsphase,
- App-Audiozustände außerhalb einer Partie und UI-Cues des AudioDirector,
- App-Lebenszyklus und lokale Speicherorte.

Konkrete Regeln für Onboarding, HUD, Kamera, Ergebnisabläufe, Accessibility und
Playtests stehen in [GAMEPLAY.md](GAMEPLAY.md).

## 6. Domänenmodell

### 6.1 Rasterkoordinaten

```swift
public struct GridPosition: Hashable, Codable, Sendable {
    public let column: Int
    public let row: Int
}

public enum Direction: Hashable, CaseIterable, Codable, Sendable {
    case up, down, left, right
}
```

Konventionen:

- `(0, 0)` ist im Modell links oben.
- Spalten wachsen nach rechts, Zeilen nach unten.
- Die Umrechnung in SpriteKit-Koordinaten erfolgt ausschließlich im Renderer.
- Level besitzen feste Breite und Höhe.
- Zugriff außerhalb des Rasters wird als feste, undurchdringliche Grenze behandelt.

Die Modellkonvention links oben entspricht Text- und JSON-Leveln und vermeidet
vertikale Spiegelungen in Editoren. SpriteKit verwendet eine andere Y-Richtung;
diese Differenz kapselt `GridGeometry`.

### 6.2 Zellschichten

Terrain und bewegliche Inhalte bleiben getrennt, ihre konkreten Typen sind jedoch
spielabhängig. Dadurch können unmögliche Kombinationen wie eine Sokoban-Kiste auf
Boulder-Dash-Erde nicht erst zur Laufzeit entstehen.

```swift
public struct SokobanCell: Equatable, Sendable {
    public let terrain: SokobanTerrain
    public private(set) var occupant: SokobanOccupant?
}

public enum SokobanTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case goal
}

public enum SokobanOccupant: Equatable, Sendable {
    case crate(EntityID)
}

public struct CaveCell: Equatable, Sendable {
    public let terrain: CaveTerrain
    public private(set) var occupant: CaveOccupant?
}

public enum CaveTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case dirt
    case exit(ExitState)
}

public enum CaveOccupant: Equatable, Sendable {
    case boulder(EntityID, motion: FallingState)
    case diamond(EntityID, motion: FallingState)
    case firefly(EntityID, heading: Direction)
    case butterfly(EntityID, heading: Direction)
    case amoeba(EntityID)
}
```

Der Spieler wird nicht zusätzlich als Bewohner im Raster gespeichert. Sokoban
speichert seine Position direkt; das Höhlenspiel verwendet einen expliziten
Lebenszustand:

```swift
public enum CavePlayerState: Equatable, Sendable {
    case alive(at: GridPosition)
    case dead(at: GridPosition)
}
```

`dead(at:)` bewahrt den Einschlags- oder Todesort für Ereignisse und Darstellung,
beansprucht diese Rasterzelle aber nicht. Ein Fels oder anderer Bewohner darf die
Zelle nach dem tödlichen Übergang belegen. Alle Objekte, die bewegt und animiert
werden, erhalten eine während der Partie stabile `EntityID`. Wände und andere
unbewegliche Terrainarten benötigen keine Identität.

Weil der lebende Höhlenspieler nicht in `CaveCell.occupant` liegt, verwenden alle
Bewegungs-, Fall-, Gegner- und Explosionsregeln eine gemeinsame interne
Weltabfrage. Sie unterscheidet mindestens `empty`, `player` und
`occupant(CaveOccupant)` und berücksichtigt Terrain separat. Eine direkte Prüfung
von `cell.occupant == nil` reicht niemals aus, um ein Bewegungsziel als frei zu
klassifizieren. Beim Eintritt eines Bewohners in die Spielerzelle werden Tod,
Bewohnerbewegung und betroffene Ereignisse innerhalb desselben Regelübergangs
atomar erzeugt. `dead(at:)` wird von dieser Belegungsabfrage nicht mehr als
Hindernis behandelt.

Mutation der Zellen bleibt außerhalb des Moduls eingeschränkt. Regeloperationen
ändern Position und Raster atomar und bewahren dadurch die Invarianten
konstruktiv. Falls Gegnerzustände wachsen, werden ihre assoziierten Werte in
separate interne `EntityState`-Strukturen verschoben.

### 6.3 Spielabhängige Weltzustände

```swift
public struct SokobanState: Equatable, Sendable {
    public private(set) var grid: Grid<SokobanCell>
    public private(set) var playerPosition: GridPosition
    public private(set) var status: PlayStatus
    public private(set) var moveCount: Int
    public private(set) var pushCount: Int
}

public struct CaveState: Equatable, Sendable {
    public private(set) var grid: Grid<CaveCell>
    public private(set) var player: CavePlayerState
    public private(set) var status: PlayStatus
    public private(set) var tick: UInt64
    public private(set) var score: Int
    public private(set) var collectedDiamonds: Int
    public let requiredDiamonds: Int
    public private(set) var remainingTicks: Int
    public private(set) var nextEntityID: UInt64
}
```

Die zugehörigen `SokobanLevel`- und `CaveLevel`-Typen sind ebenfalls getrennt.
Gemeinsam bleiben nur Raster, Koordinaten, Richtungen, Diagnosen und später eine
kleine Renderprojektion. An der Session-Grenze hält ein geschlossenes Enum den
aktiven Modus:

```swift
enum RunningGame {
    case sokoban(SokobanRun)
    case cave(CaveRun)
}
```

Gemeinsame Invarianten:

- Jede Zelle enthält höchstens einen Bewohner.
- Das Raster ändert seine Abmessungen während einer Partie nicht.
- Zähler sind nicht negativ.
- Ein abgeschlossenes oder verlorenes Level akzeptiert keine normalen Spielzüge.

Spielerabhängige Invarianten:

- Die Sokoban-Spielerposition liegt immer auf einer begehbaren, nicht belegten
  Zelle.
- `CavePlayerState.alive(at:)` liegt auf einer begehbaren, nicht belegten Zelle.
- `CavePlayerState.dead(at:)` ist nur zusammen mit einem terminalen Status erlaubt;
  sein historischer Todesort darf inzwischen belegt sein.

Spielabhängige Konstruktoren und Validatoren prüfen diese Invarianten beim Laden.
Debug-Builds können sie zusätzlich nach jedem Schritt kontrollieren.

### 6.4 Identitäten

Alle beweglichen Bewohner erhalten stabile, während eines Leveldurchlaufs
vergebene IDs. Diese IDs verbinden Regelereignisse und Sprite-Nodes, sind aber
nicht global oder persistenzübergreifend. Ein Neustart darf IDs neu vergeben,
sofern die Vergabe innerhalb desselben Startzustands deterministisch ist.

`CaveState.nextEntityID` ist die einzige Quelle für IDs neu erzeugter Bewohner.
Die Regel-Engine vergibt den aktuellen Wert und erhöht ihn monoton; IDs werden
innerhalb eines Durchlaufs niemals wiederverwendet. Weil der Zähler Teil des
autoritativen Zustands ist, bleiben Snapshots, Replays, Neustarts und spätere
Undo-Funktionen deterministisch. Die initiale Vergabe erfolgt in kanonischer
Rasterreihenfolge.

`EntityRef` enthält mindestens diese Laufzeit-ID und eine darstellungsrelevante
Objektart. `CellChange` beschreibt bei Flächenwirkungen alte und neue
Renderinhalte einer Position. Damit enthalten Ereignisse genug Information für
eine eindeutige Animation, ohne das vollständige Domänenmodell offenzulegen.

Alle in öffentlichen `Equatable`- oder `Sendable`-Typen gespeicherten Hilfstypen,
darunter `EntityID`, `ExitState` und `FallingState`, deklarieren dieselben
erforderlichen Konformanzen explizit. Die gezeigten Konformanzangaben sind
verbindlicher Teil des Vertrags und werden durch den Build des Packages geprüft.

## 7. Regel-Engine

### 7.1 Konkrete Engines vor gemeinsamer Abstraktion

Phase 1 definiert zunächst konkrete Sokoban-Operationen, Phase 4 konkrete
Höhlenoperationen:

```swift
public struct SokobanRules {
    public func start(level: SokobanLevel) throws -> SokobanState
    public func move(
        _ direction: Direction,
        in state: SokobanState
    ) throws -> Transition<SokobanState>
}

public struct CaveRules {
    public func start(level: CaveLevel) throws -> CaveState
    public func tick(
        input: CaveInput?,
        state: CaveState
    ) throws -> Transition<CaveState>
}

public struct Transition<State: Equatable & Sendable>: Equatable, Sendable {
    public let state: State
    public let events: [GameEvent]
    public let outcome: StepOutcome
}

public enum StepOutcome: Equatable, Sendable {
    case blocked
    case changed
    case terminal(PlayStatus)
}
```

Ein gemeinsames `GameRules`-Protokoll wird erst extrahiert, wenn beide Engines
existieren und die Session dadurch tatsächlich vereinfacht wird. So wird keine
Abstraktion festgeschrieben, die ungültige Spiel-/Zustandskombinationen erlaubt.
`StepOutcome` entscheidet explizit, ob Undo-Historie oder Statistik verändert
werden; dies wird nicht aus Events oder einem Zustandsvergleich erraten.
Die werfenden Übergänge melden einen typisierten `EngineFault`, falls
Vorbedingungen oder essenzielle Nachbedingungen verletzt sind. Abschnitt 16
definiert, wie die Session diesen Fehler behandelt.

### 7.2 Eingaben als Absichten

Der Kern kennt keine Tasten:

```swift
public enum CaveInput: Equatable, Sendable {
    case move(Direction)
    case wait
}
```

Sokoban erhält direkt eine `Direction`; das Höhlenspiel erhält pro Tick höchstens
eine aufgelöste `CaveInput`. Pause, Undo, Neustart oder Menübefehle sind
Session-Befehle und keine Bewegungen innerhalb der simulierten Welt.

### 7.3 Sokoban-Schritt

Reihenfolge einer Bewegung:

1. Nachbarposition in Bewegungsrichtung bestimmen.
2. Wand oder Rastergrenze blockiert die Bewegung.
3. Freies Feld erlaubt eine Spielerbewegung.
4. Bei einer Kiste wird das Feld hinter der Kiste geprüft.
5. Nur ein freies, begehbares Feld erlaubt das Schieben.
6. Kiste und Spieler werden atomar versetzt.
7. Nach einer erfolgreichen Bewegung wird `moveCount`, bei einem Schub zusätzlich
   `pushCount`, erhöht.
8. Betritt oder verlässt eine Kiste ein Ziel, wird das entsprechende fachliche
   Ereignis erzeugt.
9. Nach erfolgreicher Bewegung wird die Siegbedingung geprüft.
10. Ereignisse werden in kausaler Reihenfolge ausgegeben.

Siegbedingung der ersten Version: Jedes Zielfeld ist mit einer Kiste belegt.
Ein Level mit unterschiedlich vielen Kisten und Zielen ist ungültig.

### 7.4 Boulder-Dash-Tick

Boulder Dash verwendet einen festen logischen Takt. Der genaue Zielwert wird
spielgefühlbasiert festgelegt, zunächst beispielsweise zehn Ticks pro Sekunde.

Vor Beginn von Phase 4 wird das ADR **Cave Tick Semantics** verbindlich
abgeschlossen. Es legt anhand von 10–15 kleinen Konfliktrastern fest:

- Traversierungsreihenfolge des Rasters,
- In-place-Aktualisierung oder Berechnung eines getrennten Folgezustands,
- höchstens eine Aktion je zu Tickbeginn vorhandener Entität,
- Verhalten neu entstandener Entitäten im aktuellen Tick,
- sofortige Explosionen oder geordnete Explosions-Queue,
- Konfliktauflösung bei mehreren Wirkungen auf dieselbe Zelle,
- Priorität von Tod, Zeitablauf, Ausgang und Levelabschluss,
- monotone Uhr, Tick-Epochen und Zeitpunkt der Eingabeübernahme,
- Gleichstandsregel für Ereignisse exakt auf Tickgrenzen,
- Behandlung verspäteter Ereignisse sowie Reset bei Pause und Fortsetzen.

Es wird genau ein Verfahren implementiert. Für originalnahes, sequenzielles
Verhalten ist In-place-Aktualisierung mit einer `processedGeneration` pro
beweglicher Entität der bevorzugte Kandidat. Ein Double Buffer bleibt nur dann
eine Alternative, wenn bewusst einfachere, neu definierte Höhlenregeln gewünscht
sind.

Ein Tick besteht konzeptionell aus:

1. höchstens eine gepufferte Spielerabsicht anwenden,
2. bewegliche Zellen in definierter Reihenfolge aktualisieren,
3. Gravitation und seitliches Abrollen berechnen,
4. Gegner nach ihren lokalen Regeln bewegen,
5. Explosionen und resultierende Zellen anwenden,
6. Sammelzähler, Ausgang und Punktestand aktualisieren,
7. Zeit reduzieren,
8. Sieg- und Todeszustand bestimmen.

Die gewählte Semantik ist Teil der versionierten Spielregeln. Ein Objekt darf
innerhalb desselben Ticks nicht versehentlich mehrfach aktualisiert werden.

### 7.5 Gravitation

Grundregeln:

- Felsen und Diamanten fallen in freien Raum.
- Auf geeigneten runden Unterlagen können sie seitlich abrollen.
- Fallende Objekte unterscheiden sich von ruhenden Objekten.
- Ein fallendes Objekt kann Spieler oder Gegner treffen.
- Geschobene Felsen bewegen sich horizontal nur bei freiem Zielfeld.

Der Bewegungszustand `falling` wird explizit modelliert. Nur so kann zuverlässig
unterschieden werden, ob ein direkt über dem Spieler liegender ruhender Fels
gefährlich ist oder ob ein fallender Fels einschlägt.

### 7.6 Gegner und Explosionen

Gegner werden als spätere Ausbaustufe implementiert. Ihre Bewegungsentscheidung
verwendet nur Raster, aktuelle Richtung und lokale Nachbarschaft.

Explosionen sind keine SpriteKit-Partikel mit Spielwirkung, sondern Kernoperationen:

- betroffene 3×3-Zellen bestimmen,
- zerstörbare Inhalte entfernen,
- Folgezustände erzeugen,
- fachliche Ereignisse für nachgelagerte Präsentationsdienste ausgeben.

Partikel illustrieren anschließend nur das bereits berechnete Ergebnis.

## 8. Zeitmodell und Game Loop

### 8.1 Sokoban

Sokoban ist ereignisgetrieben. Eine gültige oder blockierte Eingabe erzeugt genau
einen Regelaufruf. Die Session akzeptiert normalisierte Bewegungsbefehle nach einer
rein logischen FIFO-Regel mit festem Limit; für den ersten Prototyp beträgt dieses
Limit zwei noch nicht verarbeitete Befehle. Da ein Kernschritt synchron ist, wird
die Queue normalerweise sofort geleert.

Der Renderer darf die Eingabeannahme niemals freigeben, sperren oder
zurückbestätigen. Falls Animationen nicht nachkommen, darf er Zwischenanimationen
überspringen oder per Revisionsvertrag hart synchronisieren. Animationsdauer,
Bildrate und die Einstellung „Bewegung reduzieren“ verändern daher nie die
akzeptierte Zugfolge.

### 8.2 Boulder Dash

Der Renderer zeichnet mit der vom System angebotenen Bildrate. Die Simulation
läuft davon getrennt in festen Schritten. `GameSession` besitzt als einzige
`@MainActor`-Instanz Zustand, Input-Queue, Accumulator und Revision. Es gibt genau
einen Loop-Einstieg: `session.advance(to:)`, aufgerufen aus `SKScene.update`.
Der von SpriteKit an `update(_:)` übergebene Zeitwert weckt den Loop nur und wird
nicht als Simulationszeit verwendet. Stattdessen liest die Szene genau einmal
`now` aus derselben injizierten monotonen Uhr, mit der der `InputMapper` seine
Ereignisse stempelt, und übergibt diesen Wert an die Session. Ein paralleler
SwiftUI-Timer ist ausgeschlossen.

Nach dem Laden oder Neustart befindet sich das Höhlenspiel zunächst in `ready`.
In diesem Zustand existiert noch keine laufende Timing-Epoche und
`session.advance(to:)` führt keine Simulationsticks aus. Die erste gültige
Bewegungs- oder Warteabsicht setzt `epochStart` auf ihren monotonen Zeitstempel,
wechselt nach `playing`, bleibt in der Input-Queue und wird Tick 1 zugeordnet.
Pause und Fortsetzen kehren nicht in `ready` zurück; Neustart und Levelwechsel
hingegen schon.

```text
frameDelta begrenzen
Eingaben bis zur Tickgrenze deterministisch übernehmen
bis zu maxCatchUpTicks ausführen
gegebenenfalls übrige Wandzeit verwerfen und Timing-Epoche neu verankern
genau ein RenderUpdate erzeugen
```

Schutzmaßnahmen:

- Delta nach langen Pausen begrenzen.
- Beim inaktiven Fenster automatisch pausieren.
- Pro Renderframe nur eine begrenzte Anzahl Ticks nachholen.
- Kein Tick-Nachholen nach System-Sleep.
- Accumulator, noch nicht konsumierte Live-Envelopes, gehaltene Richtungen und
  Press-Latch bei Pause, Sleep und Fensterdeaktivierung leeren.

`CaveState.tick` ist der globale `simulationTick` des aktuellen Leveldurchlaufs.
Er steigt für jeden tatsächlich ausgeführten Kern-Tick monoton und wird nur bei
Neustart oder neuem Level auf null gesetzt. Davon getrennt besitzt die Session
eine nicht persistierte `TimingEpoch` aus monotonem Startzeitpunkt und dem zu
diesem Zeitpunkt bereits abgeschlossenen `simulationTick`. Für jeden späteren
Tick berechnet sie daraus dessen aktuelle Wandzeitgrenze.

Wenn nach `maxCatchUpTicks` noch Rückstand verbleibt, werden keine unsichtbaren
Simulationsticks übersprungen. Die Session verwirft nur die restliche Wandzeit,
leert den Accumulator und verankert eine neue `TimingEpoch` am aktuellen
Uhrzeitpunkt und am zuletzt tatsächlich ausgeführten `simulationTick`. Noch nicht
aufgelöste Eingabe-Envelopes bleiben zeitlich geordnet; Ereignisse, deren alte
Grenze dadurch in der Vergangenheit liegt, werden nach der Verspätungsregel dem
nächsten offenen Simulationstick zugeordnet. Der Vorgang wird diagnostiziert.
Replays speichern ausschließlich globale Simulationsticknummern und benötigen
keine Timing-Epochen.

Der Kern erhält keine absolute Uhrzeit. Zeitlimits werden als verbleibende
Simulationsticks gespeichert. Renderer und Session sind `@MainActor`; Kernwerte
sind `Sendable`, Kernfunktionen synchron und wertsemantisch. Persistenz-I/O darf
außerhalb des Main Actors laufen, Schreibaufträge werden jedoch nach Revision
seriell geordnet, sodass ein älterer Save keinen neueren überschreiben kann.

### 8.3 Deterministische Zuordnung von Eingaben zu Ticks

Beim Start, Fortsetzen oder kontrollierten Verwerfen von Wandzeitrückstand legt
die Session eine neue `TimingEpoch` fest. Enthält sie den Zeitpunkt `epochStart`
und den bereits abgeschlossenen Tick `epochTick`, ergibt sich für einen globalen
Tick `n > epochTick` seine Grenze ausschließlich aus
`epochStart + (n - epochTick) * fixedStep`.
Der `InputMapper` versieht jedes semantische Key-down/Key-up-Ereignis sofort mit:

- einem Zeitstempel derselben monotonen Uhr,
- einer monoton steigenden Eingabe-Ordnungsnummer.

Live-Envelopes bleiben bis zu ihrer Übernahme durch einen Tick als Zeitstempel und
Ordnungsnummer gespeichert. Eine Eingabe gehört zum ersten noch nicht
abgeschlossenen Tick, dessen Grenze größer oder gleich ihrem Zeitstempel ist. Ein
Ereignis exakt auf einer Grenze gehört damit zum endenden Tick. Ereignisse mit
identischem Zeitstempel werden nach ihrer Ordnungsnummer verarbeitet. Trifft ein
Ereignis verspätet ein oder wurde seine ursprüngliche Wandzeitgrenze durch eine
neue Timing-Epoche verworfen, wird es dem nächsten noch offenen Tick zugeordnet
und als verspätet diagnostiziert; es findet kein Rollback statt.

Erst beim Regelaufruf entsteht aus den bis zu dieser Tickgrenze konsumierten
Envelopes höchstens eine aufgelöste `CaveInput`. Replay-Daten speichern diese
tatsächlich simulierte Absicht zusammen mit dem globalen `simulationTick`, nicht
die ursprünglichen Plattformereignisse oder Timing-Epochen. Catch-up oder eine
andere Renderframerate verändern eine bereits simulierte Zuordnung niemals.
Pause und Fortsetzen eröffnen nach dem Leeren von Input-Queue, Accumulator,
gehaltenen Tasten und Press-Latch eine neue Timing-Epoche. Das ADR
`Cave Tick Semantics` fixiert Uhrtyp, Grenzgleichheit, Überlast- und
Resetverhalten mit Golden-Tests.

## 9. Fachliche Ereignisse

Vorgesehene Ereignisse:

```swift
public enum GameEvent: Equatable, Sendable {
    case movementBlocked(at: GridPosition)
    case entityMoved(EntityRef, from: GridPosition, to: GridPosition)
    case objectPushed(EntityRef, from: GridPosition, to: GridPosition)
    case crateEnteredGoal(EntityRef, at: GridPosition, completed: Int, total: Int)
    case crateLeftGoal(EntityRef, at: GridPosition, completed: Int, total: Int)
    case objectStartedFalling(EntityRef, at: GridPosition)
    case objectLanded(EntityRef, at: GridPosition)
    case diamondCollected(EntityRef, at: GridPosition, total: Int)
    case exitOpened(at: GridPosition)
    case explosion(center: GridPosition, changes: [CellChange])
    case playerDied(at: GridPosition)
    case levelCompleted
    case timeExpired
}
```

An Ereignis beschreibt fachlich, was geschehen ist, nicht wie es angezeigt wird.
Animationstempo und Partikelfarbe gehören in visuelles Theme beziehungsweise
Renderer. Audio-Datei, Instrumentierung und Mixing gehören in Audio-Theme
beziehungsweise AudioDirector; konkrete Vorgaben stehen in
[AUDIO.md](AUDIO.md).

Die Ereignisliste ist geordnet. Tests dürfen sowohl den Endzustand als auch
relevante Ereignisse prüfen.

### 9.1 Revisionsvertrag

Session und Renderer kommunizieren über einen eindeutigen Übergang:

```swift
struct RenderUpdate: Sendable {
    let baseRevision: UInt64
    let targetRevision: UInt64
    let snapshot: RenderSnapshot
    let events: [GameEvent]
    let delivery: RenderDelivery
}

enum RenderDelivery: Sendable {
    case animate
    case hardResync
}
```

- Die Revision ist eine fortlaufende Session-/Renderupdate-Sequenz und nicht die
  Simulationsticknummer.
- Jedes tatsächlich emittierte `RenderUpdate` erhöht die Revision exakt um eins:
  `targetRevision == baseRevision + 1`.
- Ein Zustands-, HUD- oder Event-only-Update wird emittiert und erhöht die
  Revision. Daher erzeugt auch eine blockierte Bewegung mit
  `movementBlocked`-Ereignis eine neue Revision.
- Entstehen weder sichtbare Zustandsänderungen noch Events, wird kein Update
  emittiert und die Revision bleibt unverändert.
- Mehrere Catch-up-Ticks eines einzelnen `advance`-Aufrufs werden zu genau einem
  Update zusammengefasst. Events bleiben tickweise und kausal geordnet; der
  Snapshot enthält ausschließlich den Zustand nach dem letzten Tick.
- Überschreitet die aggregierte Ereignismenge das feste Animationsbudget, liefert
  die Session `hardResync` mit leerer Ereignisliste und dem finalen Snapshot.
- Events beschreiben den Übergang `baseRevision → targetRevision`.
- Der Snapshot ist immer der autoritative Zielzustand.
- Der Renderer animiert Events nur bei `delivery == .animate` und wenn sein
  aktueller Stand `baseRevision` entspricht.
- Bei einer Revisionslücke verwirft er die Animationen und baut direkt aus dem
  Ziel-Snapshot neu auf.
- Nach jeder Animationskette wird gegen den Ziel-Snapshot abgeglichen.
- Undo, Redo, Neustart, Levelwechsel und Reaktivierung des Fensters erzwingen
  einen Hard-Resync.
- Renderupdates bleiben geordnet und werden nicht unbegrenzt gepuffert.

### 9.2 Audiovertrag

Session und AudioDirector kommunizieren über einen eigenen, kleinen Vertrag:

```swift
struct AudioUpdate: Sendable {
    let targetRevision: UInt64
    let context: AudioContext
    let events: [GameEvent]
    let delivery: AudioDelivery
}

enum AudioDelivery: Sendable {
    case perform
    case synchronize
}
```

`AudioContext` ist eine unveränderliche Präsentationsprojektion. Sie enthält nur
die für die Wahl eines Musikzustands erforderlichen Angaben wie Spielmodus,
Level-ID, `PlayStatus` und beim Höhlenspiel relevante Zähler. Sie ist kein
persistierter oder autoritativer Spielzustand.

Für den Vertrag gelten folgende Regeln:

- Zu jedem emittierten `RenderUpdate` erzeugt die Session genau ein
  `AudioUpdate` mit derselben `targetRevision`.
- Bei einer lückenlosen normalen Revision liefert die Session `.perform`; die
  geordneten Events dürfen genau einmal in Audio-Cues übersetzt werden.
- Bei Undo, Redo, Neustart, Levelwechsel, Reaktivierung oder einem Hard-Resync
  liefert sie `.synchronize`. Transiente Spielereignisse werden dann nicht
  nachgespielt; der AudioDirector gleicht nur Musik- und Pausenzustand an den
  `AudioContext` an.
- Erkennt der AudioDirector selbst eine Revisionslücke oder ein Duplikat, ignoriert
  er transiente Events und synchronisiert beziehungsweise verwirft das Duplikat.
- Mehrere Catch-up-Ticks dürfen viele Events enthalten. Ihre Reihenfolge bleibt
  erhalten; Voice-Limits und Zusammenfassung gleichartiger Cues liegen allein im
  AudioDirector.
- App-Audiozustände außerhalb einer laufenden Partie, etwa Hauptmenü und
  Levelauswahl, sowie UI-Cues verwenden einen separaten App-Einstieg und besitzen
  keine Simulationrevision. Beim Übergang in eine Partie übernimmt wieder der
  revisionierte `AudioContext`.
- Audioausgabe bestätigt keine Revision und darf GameSession oder Renderer
  niemals blockieren.

Musik- und Audiozeit sind nicht Teil des deterministischen Simulationstakts.
Replays speichern weder Wiedergabepositionen noch tatsächlich abgespielte Cues.

## 10. Rendering

### 10.1 Szenenaufbau

```text
GameScene
├── cameraNode
├── boardRoot
│   ├── terrainLayer
│   ├── staticObjectLayer
│   ├── dynamicEntityLayer
│   ├── effectLayer
│   └── debugLayer
└── sceneOverlayLayer
```

Terrain kann über `SKTileMapNode` oder gebündelte Sprite-Nodes gezeichnet werden.
Bewegliche Objekte benötigen eigene `SKSpriteNode`s, damit sie eindeutig animiert
werden können.

Ein früher Rendering-Spike vergleicht:

- `SKTileMapNode` für statisches Terrain plus einzelne Nodes für Bewohner,
- einzelne Nodes für alle sichtbaren Zellen.

Für die kleinen Level ist beides performant; Wartbarkeit und Theme-Wechsel sind
wichtiger als Mikrooptimierung.

### 10.2 Snapshots und Synchronisation

Der spielabhängige Zustand wird in eine kleine gemeinsame `RenderSnapshot`-
Projektion aus Terrain-, Entity-, Spieler- und HUD-Daten übersetzt. Der Renderer
kennt dadurch weder `SokobanState` noch `CaveState`. Er hält eine stabile Zuordnung
von Entity-ID zu Sprite-Node und verarbeitet den Revisionsvertrag aus Abschnitt
9.1. Der erste Session-/Render-Spike muss Bewegung, Hard-Resync, Undo und Redo
abdecken, bevor weitere Animationstypen ergänzt werden.

### 10.3 Skalierung

- Logische Tile-Größe ist unabhängig von Pixelgröße.
- Ganzzahlige Skalierung wird für Pixel-Art bevorzugt.
- Bei nicht passendem Fenster entstehen Ränder statt verzerrter Tiles.
- Die Kamera folgt im Boulder-Dash-Modus dem Spieler innerhalb weicher Grenzen.
- Kleine Sokoban-Level werden vollständig sichtbar und zentriert dargestellt.

## 11. Eingabe

`InputMapper` übersetzt Plattformereignisse in semantische Befehle.

Standardbelegung:

- Pfeiltasten und WASD: Bewegung,
- R: Level neu starten,
- Z oder Command-Z: Undo in Sokoban,
- Shift-Command-Z: Redo in Sokoban,
- Escape: Pause beziehungsweise zurück,
- Leertaste: warten, falls ein Spielmodus dies unterstützt.

Die Bewegungswiederholung wird von macOS-Key-Repeat entkoppelt. Für Boulder Dash
merkt sich ein `DirectionalInputState` die aktuell gehaltenen Richtungen in
Drückreihenfolge und zusätzlich einen Press-Latch seit dem letzten
Simulationstick. Synthetische macOS-Key-Repeat-Ereignisse werden verworfen.

Bei der Eingabeauflösung eines Ticks gelten folgende Regeln:

1. Wurde seit dem vorherigen Tick mindestens eine Richtung neu gedrückt, wird die
   zuletzt gedrückte Richtung genau einmal verwendet, selbst wenn sie vor der
   Tickgrenze bereits wieder losgelassen wurde.
2. Andernfalls gilt die zuletzt gedrückte, noch gehaltene Richtung.
3. Wird die aktive Richtung losgelassen, fällt die Auswahl auf die zuletzt
   gedrückte der weiterhin gehaltenen Richtungen zurück.
4. Nach der Tickauflösung wird der Press-Latch geleert; der gehaltene Zustand
   bleibt bestehen.
5. Fokusverlust, Pause, Sleep und Levelwechsel leeren gehaltene Richtungen und
   Press-Latch. Dadurch kann keine Bewegung nach einer Unterbrechung hängenbleiben.

Der Zustand wird ausschließlich aus den zeitgestempelten, geordneten
Input-Envelopes aus Abschnitt 8.3 aktualisiert; ein Renderframe liest niemals
direkt den momentanen Tastaturzustand. Diskrete Befehle wie ein ausdrückliches
`wait` werden separat gepuffert und nach derselben Zeit- und Ordnungsregel genau
einem Tick zugeordnet.

Später kann ein `GameControllerInputAdapter` dieselben semantischen Befehle liefern.

## 12. Level- und Inhaltsformat

### 12.1 Entwicklungsformat

Für frühe Sokoban-Tests werden ASCII-Level unterstützt, weil sie in Tests direkt
lesbar sind:

```text
#######
#  .  #
#  $  #
#  @  #
#######
```

ASCII ist ein Importformat, nicht zwingend das dauerhafte Versandformat.

### 12.2 Kanonisches Format

JSON mit Versionsnummer:

```json
{
  "schemaVersion": 1,
  "id": "sokoban.intro.001",
  "game": "sokoban",
  "title": "Der erste Schritt",
  "width": 7,
  "height": 5,
  "rows": [
    "#######",
    "#  .  #",
    "#  $  #",
    "#  @  #",
    "#######"
  ],
  "rules": {}
}
```

Für Boulder Dash enthält `rules` unter anderem benötigte Diamanten, Zeitlimit,
Werte und optionalen Simulationstakt.

Regeln für Evolution:

- Jede Datei besitzt `schemaVersion`.
- Unbekannte neuere Versionen werden mit verständlicher Diagnose abgelehnt.
- IDs sind stabil und nicht aus Dateinamen abgeleitet.
- Leveldateien enthalten keine Dateisystempfade zu Assets.
- Dekodierung und semantische Validierung sind getrennte Schritte.
- Ein kanonischer Level-Encoder erzeugt stabile Bytes für Inhalts-Hashes.

## 13. Speicherung

### 13.1 Einstellungen

Kleine Einstellungen werden über `AppStorage` beziehungsweise `UserDefaults`
gespeichert:

- Lautstärken,
- gewähltes Theme,
- Eingabebelegung,
- Anzeigeoptionen.

### 13.2 Fortschritt

Fortschritt wird als versionierte JSON-Datei im Application-Support-Verzeichnis
gespeichert:

- abgeschlossene Level,
- beste Zug- und Schubzahl beziehungsweise Zeit,
- höchste Punktzahl,
- zuletzt gewähltes Spiel und Level.

Schreibvorgänge erfolgen atomar. Eine beschädigte Datei verhindert nicht den
App-Start; sie wird gemeldet und kann separat gesichert beziehungsweise ersetzt
werden.

Persistenztypen wie `ProgressFileV1`, `ReplayFileV1` und `SokobanRunFileV1` sind
eigene DTOs. Laufzeitzustände sind kein implizit stabiles Dateiformat.
Bestleistungen werden mit Level-ID, Inhalts-Hash und relevanter Regelversion
verknüpft, damit veränderte Level keine alten Rekorde übernehmen. Bekannte alte
Schemaversionen werden explizit migriert; unbekannte neuere Versionen werden
sicher abgelehnt.

`SokobanRunFileV1` speichert Level-ID, Inhalts-Hash, Regelversion, einen
versionierten `SokobanCheckpointV1`, höchstens 1.000 tatsächlich verändernde
Richtungsbefehle und einen Verlaufscursor. Der Checkpoint beschreibt explizit und
stabil Spielerposition, Entity-ID/Position jeder Kiste, Zähler und Status am
Beginn des erhaltenen Verlaufs; er ist nicht einfach ein codierter
`SokobanState`. Aus Checkpoint, Befehlen und Cursor rekonstruiert die App
deterministisch aktuellen Zustand, Undo und Redo.

Wächst der Verlauf über das Limit, werden die ältesten Befehle in einen neuen
Checkpoint eingerechnet und anschließend entfernt. Damit bleiben Datei und
Undo-Verlauf begrenzt, ohne die Wiederherstellbarkeit zu verlieren. Nach jeder
Laufmutation, einschließlich Zug, Undo, Redo und Neustart, wird ein kleiner,
atomarer und nach Revision geordneter Schreibauftrag erzeugt; mehrere wartende
Aufträge dürfen zusammengefasst werden.

Eine laufende Boulder-Dash-Partie wird in der ersten Version nicht automatisch
fortgesetzt. Beim Wiederöffnen beginnt das zuletzt gewählte Höhlenlevel im
`ready`-Zustand. Ein beschädigter, veralteter oder nicht mehr zum Inhalts-Hash
passender Sokoban-Lauf wird verständlich abgelehnt und kann neu gestartet werden.

## 14. Undo, Redo, Neustart und Replay

### 14.1 Sokoban-Undo und -Redo

Vor jedem neuen Zug mit `StepOutcome.changed` oder `.terminal` legt
`GameSession` den vorherigen `SokobanState` auf den Undo-Stack und leert den
Redo-Stack. Blockierte Eingaben erzeugen keinen Verlaufsschritt. Der initiale
Zustand wird separat für Neustart gehalten.

Undo entfernt den letzten Zustand vom Undo-Stack, legt den aktuellen Zustand auf
den Redo-Stack und stellt den entfernten Zustand her. Redo führt die umgekehrte
Operation aus. Ein neuer verändernder Zug nach Undo verwirft den Redo-Stack.
Neustart und Levelwechsel leeren beide Stacks.

Vollständige Snapshots werden zunächst gegenüber komplexen inversen Befehlen
bevorzugt: Sokoban-Level sind klein, und Korrektheit ist wichtiger als minimale
Speichernutzung. Das gemeinsame Startlimit für Undo und Redo beträgt 1.000
Zustände und kann nach Messung angepasst werden. Beim Abschneiden alter Zustände
wird der persistierte Checkpoint gemäß Abschnitt 13.2 vorgerückt. Undo und Redo
erzeugen in Version 1 keine rückwärts beziehungsweise erneut abgespielten
Animationen, sondern einen Hard-Resync.

### 14.2 Replay

Ein Replay besteht aus:

- Level-ID und Inhalts-Hash,
- konkrete Regelversion und relevante Regelparameter,
- Startparameter beziehungsweise Seed,
- Folge aus tatsächlich simulierten Absichten mit zugehörigen globalen
  Simulationsticknummern.

Für gehaltene Tasten speichert das Replay die pro Tick bereits aufgelöste Richtung,
nicht plattformabhängige Key-Repeat-Ereignisse. Zustandsdigests verwenden niemals
Swifts prozessabhängigen `Hasher`, sondern einen kanonischen Byte-Encoder und ein
festgelegtes, versionsstabiles Hashverfahren.

Replays sind zunächst eine interne Debug-Funktion. Sie helfen, Boulder-Dash-Fehler
als kleine reproduzierbare Dateien festzuhalten.

## 15. Zustandsmodell der App

```text
launching
   ↓
mainMenu ─────► levelSelection
   ▲                   │
   │                   ▼
   │               levelIntro
   │                 │     │
   │       Sokoban   │     │ Höhle
   │                 ▼     ▼
   └────────────── playing  ready
                      ▲       │ erste gültige Absicht
                      └───────┘
                      │
                      ├────────► paused
                      │             │ Fortsetzen
                      ◄─────────────┘
                      │
                      ▼
               outcomePresenting
                  │         │
                  ▼         ▼
              completed   gameOver

completed ── Sokoban Undo/Neustart ──► playing
completed ───── Höhlen-Neustart ─────► ready
gameOver  ───────── Neustart ────────► ready
completed/gameOver ──────────► levelSelection
```

Die Session akzeptiert Befehle nur, wenn sie im aktuellen Zustand sinnvoll sind.
Eine kleine eigene Swift-Enum-Zustandsmaschine reicht für diese wenigen Zustände;
GameplayKit wird dafür nicht eingebunden.

`ready` wird nur für das tickbasierte Höhlenspiel benötigt. Sokoban wechselt aus
`levelIntro` direkt nach `playing`. `outcomePresenting` ist ein
Anwendungszustand; der Kern ist zu diesem Zeitpunkt bereits terminal. Die
Präsentation besitzt eine kurze feste Maximaldauer, kann übersprungen werden und
wartet weder auf Renderer- noch Audio-Rückbestätigung. Eingaben, die den
terminalen Übergang ausgelöst haben, dürfen keine Ergebnisaktion bestätigen.

Die Rückübergänge sind Teil des Vertrags:

- `completed → playing` ist in Sokoban per Undo erlaubt und schließt den
  Ergebnisdialog.
- `completed → playing` ist in Sokoban per Neustart erlaubt.
- `completed → ready` und `gameOver → ready` sind im Höhlenspiel per Neustart
  erlaubt.
- `completed` und `gameOver` können zur Levelauswahl oder ins Hauptmenü wechseln.
- Eine bereits persistierte Freischaltung wird durch Undo nach einem Abschluss
  nicht zurückgenommen. Eine neue Bestleistung wird erst bei einem erneuten
  Abschluss bewertet.

## 16. Fehlerbehandlung und Diagnostik

Validierung erfolgt spielabhängig in zwei Stufen. Strukturelle Fehler verhindern
das Laden:

- fehlender oder mehrfach vorhandener Spieler,
- inkonsistente Zeilenbreiten,
- unbekannte Zeichen,
- fehlende Ziele oder Ausgänge,
- abweichende Anzahl von Kisten und Zielen,
- ungültige Regelwerte.

Editorielle Heuristiken wie offensichtlich tote Kisten oder möglicherweise
unerreichbare Bereiche erzeugen Warnungen, keine harten Ladefehler. Eine allgemeine
Lösbarkeitsprüfung wird nicht versprochen.

Jeder öffentliche Regelübergang prüft in allen Builds die essenziellen
Vorbedingungen und Nachbedingungen und wirft bei einer Verletzung einen typisierten
`EngineFault`. Debug-Builds führen zusätzlich vollständige Invariantenprüfungen
und Assertions aus.

`GameSession` fängt `EngineFault` an der einzigen Übergangsgrenze ab, stoppt den
Loop, leert Input-Queue und Accumulator, verwirft die beschädigte laufende Partie
und kehrt mit einer verständlichen Diagnose in einen sicheren App-Zustand zurück.
Aus dem möglicherweise inkonsistenten Zustand wird kein weiterer Render-Snapshot
erzeugt. Unerwartete Fehler außerhalb dieses Vertrags gelten weiterhin als
Programmierfehler und dürfen in Debug-Builds hart fehlschlagen.

Ein optionales Debug-Overlay zeigt:

- Rasterkoordinaten,
- aktuelle Ticknummer,
- Spielerposition,
- belegte Zellen und Entity-IDs,
- Tickdauer und Anzahl aktiver Nodes.

## 17. Teststrategie

### 17.1 Unit-Tests

Der größte Testanteil liegt in `GameCore`.

Sokoban:

- Bewegung in alle Richtungen,
- Blockade durch Wand und Grenze,
- einzelnes Schieben,
- Blockade bei zwei Kisten,
- Kiste auf und von einem Ziel,
- korrekte Zug- und Schubzähler,
- geordnete `crateEnteredGoal`- und `crateLeftGoal`-Ereignisse,
- Siegbedingung,
- ungültige Level.

Boulder Dash:

- Fallen und Landen,
- seitliches Abrollen in beide Richtungen,
- keine Mehrfachaktualisierung pro Tick,
- Schieben von Felsen,
- Spieler wird von fallendem Objekt getroffen,
- Einsammeln und Öffnen des Ausgangs,
- Zeitablauf,
- Spieler wechselt bei einem Treffer zu `dead(at:)`, während die Todeszelle durch
  den verursachenden Bewohner belegt werden darf,
- jede Bewegung, jeder Fall und jede Explosion erkennt den außerhalb des
  Zellbewohners gespeicherten lebenden Spieler über dieselbe Weltabfrage,
- neu erzeugte Bewohner erhalten monotone, replay-stabile IDs,
- Gegnerbewegung,
- Explosionen an Wänden und Rastergrenzen,
- Kettenreaktionen,
- die im Tick-ADR festgelegte Scan- und Konfliktreihenfolge.

### 17.2 Szenario-Tests

Kleine ASCII-Raster werden mit Eingabe- oder Tickfolgen ausgeführt und mit einem
erwarteten Endraster verglichen. Diese Golden-Szenarien sind lesbare
Regelspezifikationen.

### 17.3 Determinismustests

- Dieselbe Replaydatei erzeugt wiederholt denselben Zustandshash.
- Versionierte Replay-, Fortschritts- und Sokoban-Run-DTOs bewahren ihre
  spezifizierten Felder beim Encode-/Decode-Roundtrip.
- Feste Replay-Fixtures liefern über Prozessstarts denselben Golden-Digest.
- Nach jeder längeren, deterministisch erzeugten Folge legaler Aktionen gelten
  alle Weltinvarianten.

### 17.4 UI- und Integrationstests

Wenige gezielte Tests:

- App startet ins Hauptmenü,
- Level lässt sich öffnen,
- Tasteneingabe erreicht die Session,
- Pause stoppt Boulder-Dash-Ticks,
- ein neu geladenes Höhlenlevel führt im Ready-State keine Ticks aus,
- die erste gültige Höhleneingabe startet die Timing-Epoche und gehört zu Tick 1,
- Abschluss schaltet das nächste Level frei,
- Undo, Redo und Neustart stellen den erwarteten Snapshot wieder her,
- ein neuer Sokoban-Zug nach Undo leert den Redo-Verlauf,
- ein wiederhergestellter `SokobanRunFileV1` rekonstruiert Zustand und
  Verlaufscursor,
- Checkpoint-Kompaktion nach mehr als 1.000 verändernden Zügen rekonstruiert
  denselben aktuellen Zustand und einen begrenzten Verlauf,
- `outcomePresenting` übernimmt die terminal auslösende Eingabe nicht als
  Ergebnisaktion,
- verschiedene Renderframeraten erzeugen dieselbe Tick- und Zustandsfolge,
- Eingaben exakt an Tickgrenzen werden reproduzierbar aufgelöst,
- monotone Zeitstempel, Gleichstände und verspätete Eingaben folgen Abschnitt 8.3,
- Pause, Sleep und Catch-up behandeln Accumulator und Timing-Epoche wie
  spezifiziert, während der globale Simulationstick monoton bleibt,
- verworfener Wandzeitrückstand ordnet alte Live-Envelopes genau einmal dem
  nächsten offenen Tick zu,
- Key-down und Key-up innerhalb desselben Tickintervalls erzeugen genau einen Tap,
- nach Loslassen der zuletzt gedrückten Richtung wird eine ältere weiterhin
  gehaltene Richtung wieder aktiv,
- Fokusverlust leert gehaltene Richtungen und Press-Latch,
- ein Revisionssprung führt zum Hard-Resync statt zu falscher Animation,
- blockierte Event-only-Eingaben erhöhen die Revision exakt einmal,
- mehrere Catch-up-Ticks werden geordnet zu einer Revision zusammengefasst,
- leere `advance`-Aufrufe erzeugen keine Revision,
- jedes Renderupdate besitzt genau ein AudioUpdate derselben Zielrevision,
- ein Audio-Duplikat spielt keinen Cue doppelt,
- Hard-Resync, Undo, Redo und Neustart spielen keine vergangenen Audio-Cues nach,
- Lautstärke, Stummschaltung und ausfallende Audiowiedergabe verändern niemals
  Zustand, Tickfolge oder Replay-Digest.

Zusätzliche Vertrags- und Persistenztests prüfen:

- Events vom alten Renderzustand führen zum Ziel-Snapshot.
- Veraltete oder beschädigte Persistenzdateien werden definiert behandelt.
- Replay-, Fortschritts- und Sokoban-Run-DTOs lassen sich gegen feste
  Fixture-Bytes prüfen.
- Ein älterer asynchroner Save kann keinen neueren Revisionsstand überschreiben.
- Ein veralteter Sokoban-Lauf mit abweichendem Inhalts-Hash wird nicht geladen.
- Replays enthalten globale Simulationsticks und bleiben von Timing-Epochen,
  Pause und verworfener Wandzeit unabhängig.

Pixelgenaue Screenshots sind ergänzend möglich, dürfen aber nicht die Kernregeln
prüfen.

## 18. Performance- und Qualitätsziele

- Flüssige Darstellung bei nativer Bildschirmfrequenz.
- Kern-Tick deutlich unter einem Millisekundenbudget für typische Level.
- Keine Dateizugriffe innerhalb eines Simulationsticks.
- Keine Node-Neuerzeugung pro Frame.
- Keine ungebundenen Event-, Undo-, Redo- oder Replay-Puffer.
- Simulationsergebnis unabhängig von Rechnergeschwindigkeit.
- Start und Levelwechsel ohne wahrnehmbare Wartezeit.

Erst messen, dann optimieren. Die Raster sind klein genug, dass klare
Wertsemantik und vollständige Snapshots zunächst vertretbar sind.

## 19. Barrierefreiheit und Mac-Konventionen

- Alle Aktionen erhalten Menübefehle und sichtbare Tastaturkürzel.
- Bewegung funktioniert ohne Maus.
- Menüs, Levelauswahl, Pause und Ergebnisdialoge unterstützen vollständige
  Tastaturnavigation mit sichtbarem Fokus.
- Farben sind nicht das einzige Unterscheidungsmerkmal.
- Wichtige Audiohinweise besitzen sichtbare Entsprechungen.
- Die Systemeinstellung „Bewegung reduzieren“ wird berücksichtigt; Kamera,
  Animationen, Partikel und Bildschirmerschütterung lassen sich zusätzlich
  reduzieren.
- Ein kontrastreiches Theme ist vorgesehen.
- Lautstärken für Musik und Effekte sind separat regelbar.
- Fenstergröße und Vollbild werden unterstützt.
- Overlays und Menüs verwenden SwiftUI, damit VoiceOver sinnvolle Elemente erhält.

Das eigentliche Raster erhält später eine kompakte zugängliche Beschreibung des
Spielstatus; eine vollständige zellenweise VoiceOver-Navigation ist kein Ziel des
ersten Meilensteins.

## 20. Vorgesehene Projektstruktur

```text
BoulderDash/
├── ARCHITECTURE.md
├── AUDIO.md
├── GAMEPLAY.md
├── README.md
├── todo.md
├── docs/
│   └── adr/
├── Packages/
│   └── GameCore/
│       ├── Package.swift
│       ├── Sources/
│       │   └── GameCore/
│       │       ├── Grid/
│       │       ├── Model/
│       │       ├── Rules/
│       │       │   ├── Sokoban/
│       │       │   └── BoulderDash/
│       │       ├── Events/
│       │       ├── Level/
│       │       └── Replay/
│       └── Tests/
│           └── GameCoreTests/
├── MacGameApp/
│   ├── App/
│   ├── Session/
│   ├── Views/
│   ├── Rendering/
│   ├── Audio/
│   ├── Input/
│   ├── Persistence/
│   └── Resources/
│       ├── Levels/
│       ├── Themes/
│       ├── Textures/
│       └── Audio/
```

Der Name des App-Targets und ein eigener Produktname werden vor Veröffentlichung
festgelegt. Die Arbeitsstruktur ist nicht an den aktuellen Ordnernamen gebunden.
Ein eigenständiges `LevelValidator`-Tool kommt erst hinzu, wenn Validierung
tatsächlich außerhalb von Tests und App benötigt wird.

## 21. Umsetzungsphasen

### Phase 0: Fundament

- Git-Repository und `.gitignore` anlegen.
- Lokales Swift-Package `GameCore` erstellen.
- Basisdatentypen `Grid`, `GridPosition`, `Direction` implementieren.
- Swift-Testing-Ziel einrichten.
- Lokalen, dokumentierten `swift test`-Befehl für `GameCore` festlegen
  (keine GitHub-CI; siehe `docs/adr/0001-ci-swift-test.md`).
- Nur Entscheidungen mit echten Alternativen und Folgekosten als ADR unter
  `docs/adr/` dokumentieren.
- Distributionsziel `.dmg` festhalten (siehe `docs/adr/0002-dmg-distribution.md`).

Abnahme:

- `swift test` läuft ohne Xcode-GUI (`cd Packages/GameCore && swift test`)
  auf Swift 6.3.x / Xcode 26.6.
- Rasterzugriff und Koordinaten sind getestet.

### Phase 1: Sokoban-Kern

- ASCII-Parser und Levelvalidierung.
- Sokoban-Bewegung und Kistenschieben.
- Zug- und Schubzähler sowie Zielereignisse.
- Siegbedingung und explizite `StepOutcome`s.
- Drei Testlevel.
- Golden-Szenario-Tests.

Abnahme:

- Ein vollständiges Level kann ausschließlich in Tests gelöst werden.
- Jede Regeloperation ist deterministisch.

### Phase 2: Spielbare Mac-App

- Vollständiges Xcode-/SDK-/Signierungs-Preflight durchführen.
- Xcode-App-Projekt mit SwiftUI.
- SpriteKit-Szene und Rasterdarstellung.
- Tastatureingabe und `@MainActor`-Session.
- Revisionsvertrag mit Bewegung, Hard-Resync, Undo und Redo als kleinen Spike
  umsetzen.
- `AudioDirector` und den Audiovertrag mit einem Musikloop und wenigen
  provisorischen Cues umsetzen.
- HUD, Pause, Undo, Redo, Neustart und terminale Ergebnispräsentation.
- `SokobanRunFileV1` und automatische Wiederaufnahme umsetzen.
- Drei Tutorial-Level nach [GAMEPLAY.md](GAMEPLAY.md) spielbar machen.
- Provisorische eigene oder gemäß [AUDIO.md](AUDIO.md) dokumentierte Assets.
- Einen dokumentierten lokalen `xcodebuild`-Build- oder Test-Smoke ergänzen.

Abnahme:

- Sokoban ist mit drei Leveln vollständig per Tastatur spielbar.
- Fenstergrößenänderung beschädigt den Zustand nicht.
- App-Target baut und startet mit dem festgelegten macOS-Deployment-Target.
- Der dokumentierte lokale `xcodebuild`-Smoke läuft mit dem festgelegten Xcode.
- Ein künstlicher Revisionssprung synchronisiert korrekt auf den Ziel-Snapshot.
- Blockierte Event-only-Züge und leere Updates folgen exakt Abschnitt 9.1.
- AudioUpdate und RenderUpdate verwenden dieselbe Zielrevision.
- Undo, Redo, Neustart und Hard-Resync spielen keine alten Jingles oder Effekte
  nach.
- Zug- und Schubzahl werden getrennt angezeigt.
- Ein laufendes Sokoban-Level lässt sich mit Undo- und Redo-Verlauf
  wiederherstellen.
- Die Abschlusspräsentation ist überspringbar und übernimmt den letzten
  Spielzug nicht als UI-Bestätigung.
- Sokoban akzeptiert dieselbe Zugfolge unabhängig von Animationsdauer und
  „Bewegung reduzieren“.

### Phase 3: Gemeinsame Plattform

- JSON-Level und Manifest.
- Fortschrittsspeicherung.
- Theme- und Texture-Mapping.
- Audio-Manifest und Audio-Theme-Mapping.
- Gemeinsame Levelintro-, Hilfe- und Ergebnisansichten nach
  [GAMEPLAY.md](GAMEPLAY.md).
- Render-Snapshots und Eventanimationen härten.
- Replay-Grundlage.

Abnahme:

- Neue Level benötigen keine Codeänderung.
- Renderer kann jederzeit aus einem Snapshot neu aufgebaut werden.

### Phase 3.5: Höhlenregel-Spike

- ADR `Cave Tick Semantics` anhand konkurrierender Beispielsituationen entscheiden.
- 10–15 Golden-Konfliktraster für Scanrichtung, Update-once und Explosionen bauen.
- Exakte Tickrate, Eingabeabtastung und Catch-up-Regel festlegen.
- Globale Simulationsticks, Timing-Epochen und Überlast-Rebasierung festlegen.
- Ready-State und Übergang der ersten Eingabe zu Tick 1 festlegen.
- Kleinen Replay-Digest ohne Renderer nachweisen.

Abnahme:

- Das ADR entscheidet genau ein Updateverfahren und alle Punkte aus Abschnitt 7.4.
- Identische Eingabe-/Tickfolgen liefern feste Golden-Digests.
- Tickgrenzen, Gleichstände, verspätete Inputs und neue Tick-Epochen sind durch
  Golden-Tests festgelegt.
- Kurze Taps, Richtungs-Fallback, Fokusverlust und verworfener Wandzeitrückstand
  sind durch Golden-Tests festgelegt.
- Im Ready-State läuft kein Tick; die erste gültige Absicht wird genau einmal in
  Tick 1 simuliert.
- Replays enthalten ausschließlich globale Simulationsticks; Timing-Epochen
  beeinflussen ihren Digest nicht.
- Keine offene Regelentscheidung blockiert die Implementierung von Phase 4.

### Phase 4: Boulder-Dash-Grundspiel

- Fester Simulationstakt.
- Erde, Felsen, Diamanten und Ausgang.
- Fallen, Rollen, Schieben, Sammeln und Tod.
- Kamera für größere Höhlen.
- Zeitlimit und Punktestand.
- Ready-State, Kamera-Safe-Zone und schnelle Todes-/Neustartfolge.

Abnahme:

- Ein handgebautes Boulder-Dash-Level ist vom Start bis zum Ausgang spielbar.
- Ein Replay liefert immer denselben Endzustand.
- Vor der ersten gültigen Eingabe verändert sich das Höhlenlevel nicht.
- Neustart führt ohne alte Eingaben in den Ready-State zurück.
- Tod wechselt atomar zu `CavePlayerState.dead`, ohne die Todeszelle zu reservieren.
- Die zentrale Weltbelegungsabfrage verhindert, dass eine Höhlenregel den lebenden
  Spieler als leere Zelle behandelt.
- Der initiale `nextEntityID`-Wert ist kanonisch und replay-stabil.

### Phase 5: Erweiterte Höhlenregeln

- Glühwürmchen und Schmetterlinge.
- Explosionen und Diamantentstehung.
- Amöben und weitere besondere Tiles.
- Leben, Levelreihenfolge und Bonuswertung.
- Polishing von Animation und Schwierigkeit.
- Audiopolishing nach den Vorgaben aus [AUDIO.md](AUDIO.md).

Abnahme:

- Regel-Suite deckt Kollisionen und Kettenreaktionen ab.
- Mehrere vollständige Höhlen sind stabil spielbar.
- Während der Simulation erzeugte Bewohner erhalten monotone, nicht
  wiederverwendete IDs.

### Phase 6: Inhalt und Veröffentlichung

- Eigene visuelle Identität und eigener Produktname.
- Weitere Level und Schwierigkeitskurve.
- Gameplay- und Accessibility-Playtests gemäß [GAMEPLAY.md](GAMEPLAY.md).
- Bedienungshilfen und Einstellungen vervollständigen.
- Performance-, Speicher- und UI-Tests.
- Audio-Asset- und Lizenznachweise aus [AUDIO.md](AUDIO.md) vollständig prüfen.
- Signierung, Sandbox und DMG-Erzeugung für die lokale `.dmg`-Verteilung.

## 22. Risiken und Gegenmaßnahmen

### Risiko: Boulder-Dash-Regeln hängen ungewollt von Scan-Reihenfolge ab

Gegenmaßnahme: Reihenfolge als Teil der Spezifikation behandeln, kleine
Konfliktszenarien testen und Replays mit Zustandshashes verwenden.

### Risiko: Zu frühe Vereinheitlichung erzeugt komplizierte Abstraktionen

Gegenmaßnahme: Erst Sokoban vollständig umsetzen; gemeinsame Protokolle nur aus
konkreten Anforderungen beider Spiele ableiten.

### Risiko: Animation und Modell laufen auseinander

Gegenmaßnahme: Modell autoritativ halten, Events nur als Hinweise verwenden und
regelmäßige Snapshot-Synchronisation ermöglichen.

### Risiko: Audio-Cues werden nach Resync doppelt oder verspätet abgespielt

Gegenmaßnahme: AudioUpdate an die Sessionrevision koppeln, Duplikate verwerfen
und bei `.synchronize` ausschließlich den Hintergrundzustand abgleichen.

### Risiko: Tastaturwiederholung verändert Spielverhalten

Gegenmaßnahme: physische Tastenzustände normalisieren und Simulationsschritte
nicht direkt an AppKit-Key-Repeat koppeln.

### Risiko: Leveldaten werden mit wachsendem Funktionsumfang instabil

Gegenmaßnahme: versioniertes Schema, zentrale Validierung und Fixtures für jede
unterstützte Version.

### Risiko: Originalnähe kollidiert mit eigener Produktidentität

Gegenmaßnahme: Mechaniken technisch nachbilden, aber eigene Namen, Level, Grafik,
Audio und Präsentation entwickeln.

## 23. Architekturentscheidungen vor der jeweils betroffenen Implementierung

Bereits empfohlen:

1. SwiftUI plus SpriteKit statt externer Engine.
2. Lokales Swift-Package für den UI-freien Kern.
3. Eigene diskrete Simulation statt SpriteKit-Physik.
4. Sokoban als erster vertikaler Prototyp.
5. Vollständige Snapshots für erstes Undo und Redo.
6. ASCII für Tests, versioniertes JSON für Inhalte.

In frühen Spikes zu entscheiden:

1. `SKTileMapNode` oder vollständig eigene Node-Schichten.
2. In-place mit Marker oder Double Buffer für Boulder-Dash-Ticks; verbindlich in
   Phase 3.5 und nicht als doppelte Abstraktion.
3. Exakte Tickrate und Eingabepufferung des Höhlenspiels.
4. Minimale unterstützte macOS-Version.
5. Pixel-Art mit ganzzahliger Skalierung oder auflösungsunabhängiger Stil.

Bereits entschieden (siehe `docs/adr/`):

1. Keine GitHub-CI; lokale `swift test`-Abnahme.
2. Primäres Auslieferungsformat ist eine `.dmg`.

## 24. Definition of Done für den ersten vertikalen Prototyp

Der erste Prototyp ist fertig, wenn:

- die App nativ auf dem Entwicklungs-Mac startet,
- ein Sokoban-Level aus einer Ressourcendatei geladen wird,
- Spielerbewegung und Kistenschieben korrekt funktionieren,
- ungültige Bewegungen den Zustand nicht verändern,
- Zug- und Schubzahl getrennt sichtbar sind,
- Undo, Redo, Neustart und Levelabschluss bedienbar sind,
- ein laufendes Sokoban-Level automatisch wiederaufgenommen werden kann,
- der letzte Zug vor dem Ergebnisdialog sichtbar abgeschlossen wird,
- Modell und Regeln keine SpriteKit- oder SwiftUI-Imports besitzen,
- Kernregeln automatisiert getestet sind,
- das Fenster frei skaliert werden kann,
- temporäre eigene Assets verwendet werden,
- Build und Tests mit kurzen Befehlen dokumentiert sind.

## 25. Unmittelbar nächster technischer Schritt

Nach Freigabe dieses Plans wird nur Phase 0 und der kleinste Teil von Phase 1
umgesetzt:

1. `GameCore` als lokales Swift-Package anlegen,
2. `Grid`, `GridPosition` und `Direction` implementieren,
3. ASCII-Sokoban-Level dekodieren,
4. genau eine Schieberegel mit Tests implementieren,
5. erst danach das App-Target und Rendering ergänzen.

So validiert das Projekt zuerst die schwer rückgängig zu machende Grenze zwischen
Spielmodell und Darstellung, bevor Zeit in Grafik oder Werkzeuge fließt.

## 26. Reviewprotokoll

Der Entwurf wurde nach seiner ersten Fassung unabhängig und kritisch auf
Modulgrenzen, Determinismus, Tick-Semantik, Swift-Concurrency, Renderingvertrag,
Undo/Replay, Persistenz, Tests, Phasen und Overengineering geprüft.

Ergebnis:

- keine P0-Blocker,
- Freigabe für Phase 0 und Phase 1,
- getrennte `SokobanState`-/`CaveState`-Modelle statt eines unsicheren
  Universalzustands,
- verbindlicher Revisionsvertrag zwischen Session und Renderer,
- genau eine `@MainActor`-Session als Eigentümerin von Zustand und Spieluhr,
- eigenes Tick-Semantik-ADR als Voraussetzung für das Höhlenspiel,
- Undo in der Session statt in der Regel-Engine,
- versionierte Persistenz-DTOs statt Laufzeitmodelle als Dateiformat,
- zusätzliche Vertrags-, Catch-up-, Revisions- und Golden-Digest-Tests,
- Verschiebung optionaler Module und Tools bis ein realer Bedarf entsteht.

Die positive Grundbewertung blieb unverändert: SwiftUI plus SpriteKit, ein
UI-freier synchroner Kern, diskrete ganzzahlige Regeln, Sokoban als erster
vertikaler Prototyp und keine Drittanbieter-Laufzeitbibliotheken sind für das
Projekt angemessen.

Ein weiterer fokussierter Review fand danach zusätzliche Vertragslücken. Diese
Fassung enthält deshalb außerdem:

- `CavePlayerState.alive/dead` mit klarer Belegung der Todeszelle,
- `nextEntityID` als deterministischen Bestandteil des Höhlenzustands,
- exakte Regeln für Revisionssteigerung und Catch-up-Aggregation,
- monotone Input-Zeitstempel, Tick-Epochen und Grenzgleichheit,
- eine rendererunabhängige Sokoban-Eingabequeue,
- werfende, validierte Regelübergänge mit ausführbarer Release-Fehlerbehandlung,
- bereinigte Aussagen zu Engine-Protokoll, Undo-Zuständigkeit und
  Persistenz-Roundtrips.

Ein anschließender Umsetzungsreview schloss weitere konkrete Lücken:

- globale, replay-stabile Simulationsticks wurden von neu verankerbaren
  Wandzeit-Epochen getrennt,
- `SKScene.update` wurde auf einen reinen Loop-Wecker reduziert; Simulation und
  Eingaben verwenden dieselbe injizierte monotone Uhr,
- Catch-up-Überlast besitzt nun eine definierte Rebasierungs- und
  Verspätungsregel,
- kurze Richtungstaps, mehrere gehaltene Richtungen und Fokusverlust besitzen
  eine vollständige Auflösungsregel,
- der außerhalb des Rasters gespeicherte Höhlenspieler wird über eine zentrale
  Weltbelegungsabfrage in allen Kollisionen berücksichtigt,
- die Swift-Vertragsbeispiele deklarieren alle für `Equatable` und `Sendable`
  erforderlichen Konformanzen,
- terminale App-Zustände besitzen definierte Übergänge für Undo, Neustart und
  Levelauswahl,
- lokale Test- und Build-Smokes sind ab Phase 0 beziehungsweise Phase 2 Teil
  der Abnahme; eine GitHub-CI ist nicht vorgesehen,
- das Auslieferungsziel ist eine signierte/notariserte `.dmg`.

Das Audio-Thema wurde anschließend aus dem Architekturplan herausgelöst:

- [AUDIO.md](AUDIO.md) hält Musikrichtung, MIDI-Strategie, Jingles, Asset-Kandidaten,
  Mixing- und Lizenzregeln fest,
- `ARCHITECTURE.md` definiert nur noch AudioDirector, AudioUpdate,
  Revisionsverhalten und Modulgrenzen,
- Renderer und AudioDirector sind unabhängige Präsentationsdienste,
- Hard-Resync, Undo, Redo und Neustart spielen keine historischen Audio-Cues
  nach.

Das Spielerlebnis wurde danach in [GAMEPLAY.md](GAMEPLAY.md) konkretisiert:

- Tutorialfolge, HUD, Kamera, Ergebnisabläufe und Playtests liegen außerhalb des
  Architekturplans,
- die Architektur ergänzt nur die notwendigen Verträge für Ready-State,
  terminale Präsentation, Undo/Redo und Sokoban-Wiederaufnahme,
- Sokoban speichert eine rekonstruierbare Befehlshistorie mit Verlaufscursor,
- die erste Höhleneingabe startet Tick 1; vorher läuft keine Simulation,
- terminal auslösende Eingaben können keine Ergebnisaktion versehentlich
  bestätigen.

Die neuen Findings ändern nicht die Freigabe von Phase 0 und Phase 1; die
betroffenen Höhlen-, Session- und Renderverträge müssen entsprechend ihren
Phasenabnahmen implementiert werden.
