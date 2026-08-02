# Audiokonzept: Musik, MIDI, Jingles und Soundeffekte

Status: Arbeitsgrundlage für Prototyp und spätere Audio-Produktion  
Geltungsbereich: musikalische Richtung, Asset-Auswahl, Lizenzen und
Produktionsregeln  
Technische Architektur und Schnittstellen: siehe
[ARCHITECTURE.md](ARCHITECTURE.md)  
Gameplay, HUD und Ergebnisabläufe: siehe [GAMEPLAY.md](GAMEPLAY.md)

## 1. Zielbild

Beide Spiele erhalten eine gemeinsame akustische Identität, ohne gleich zu
klingen:

- Sokoban bleibt ruhig, klar und wenig ermüdend.
- Das Höhlenspiel klingt rhythmischer, räumlicher und bei Gefahr zunehmend
  angespannt.
- Ein kleines gemeinsames Leitmotiv verbindet Menü, beide Spiele und Jingles.
- Kurze musikalische Rückmeldungen machen wichtige Ereignisse verständlich,
  ohne die Hintergrundmusik ständig zu unterbrechen.

Audio illustriert den bereits berechneten Spielzustand. Musik, Jingles oder
Soundeffekte beeinflussen niemals Regeln, Eingaben, Ticks oder Replays.

## 2. Audiokategorien

### 2.1 Hintergrundmusik

Längere, nahtlos wiederholbare Stücke für:

- Hauptmenü,
- Sokoban-Level,
- Höhlen-Level,
- Ergebnis- oder Abspannzustände.

Die Musik soll auch nach mehreren Minuten nicht anstrengend werden. Deutliche
Melodien werden sparsam eingesetzt; kurze Loops benötigen genügend Variation,
damit ihre Wiederholung nicht sofort auffällt.

### 2.2 Musikalische Jingles und Stinger

Kurze tonale Motive für fachlich wichtige Ereignisse:

- Kiste erreicht ein Ziel,
- erforderliche Diamantenzahl erreicht,
- Ausgang öffnet sich,
- Level abgeschlossen,
- neuer Bestwert,
- Tod oder Zeitablauf.

Jingles verwenden möglichst Tonmaterial aus dem gemeinsamen Leitmotiv. Dadurch
wirken sie wie Bestandteile des Soundtracks statt wie beliebige Signaltöne.

### 2.3 Spiel-Soundeffekte

Nicht zwingend tonale Rückmeldungen für:

- Schritt und Bewegung,
- blockierte Bewegung,
- Kiste oder Fels wird geschoben,
- Fels oder Diamant fällt und landet,
- Erde wird entfernt,
- Diamant wird eingesammelt,
- Gegnerbewegung,
- Explosion.

Häufig wiederholte Aktionen benötigen mehrere leicht unterschiedliche Varianten
oder kleine kontrollierte Änderungen von Tonhöhe und Lautstärke.

### 2.4 UI-Sounds

Kurze, zurückhaltende Klänge für:

- Auswahl und Bestätigung,
- Zurück und Abbrechen,
- Pause und Fortsetzen,
- nicht verfügbare Aktion.

UI-Sounds sind von fachlichen Spielereignissen getrennt.

## 3. Musikalische Richtung

### 3.1 Gemeinsames Leitmotiv

Ein Motiv aus drei bis fünf Tönen bildet die wiedererkennbare Klammer:

- langsam und weich im Sokoban-Modus,
- rhythmisch oder arpeggiert im Höhlenspiel,
- verkürzt als Ziel-, Diamant- und Abschlussjingle,
- reduziert als Menüklang.

Das Motiv wird eigenständig komponiert. Ein provisorisches CC0-Stück muss es noch
nicht enthalten.

### 3.2 Sokoban

Vorgesehener Charakter:

- ruhig, konzentriert und freundlich,
- ungefähr 70–90 BPM,
- weiche Mallets, dezenter Bass, leichte Flächen,
- wenig oder keine dominante Percussion,
- Loops von ungefähr 45–90 Sekunden,
- keine musikalische Bestrafung für längeres Nachdenken.

Eine blockierte Bewegung erhält höchstens einen sehr kurzen trockenen Effekt,
keinen negativen Jingle. Das Erreichen eines Ziels darf deutlich, aber nicht
triumphal klingen.

### 3.3 Höhlenspiel

Vorgesehener Charakter:

- reduzierter Retro-Synth- oder Chiptune-Klang,
- pulsierender Bass und kurze Arpeggios,
- metallische oder geräuschhafte Percussion,
- ausreichend Raum für Fall-, Diamant- und Explosionsgeräusche,
- zusätzliche Spannungsschicht bei knapp werdender Zeit,
- harmonische Aufhellung, sobald der Ausgang geöffnet ist.

Zeitdruck wird vorzugsweise durch eine musikalische Schicht oder veränderte
Instrumentation vermittelt, nicht durch einen Warnpiepser in jedem Tick.

## 4. Vorläufige Asset-Auswahl

Alle Kandidaten müssen vor Aufnahme ins Repository noch einmal heruntergeladen,
angehört und mit ihrer konkreten Quelldatei dokumentiert werden.

### 4.0 Aktueller Sokoban-Playtest

- Rolle: provisorisches Sokoban-Thema
- Titel: Puzzling
- Autor: Ruskerdax
- Format: MP3, ungefähr 120 Sekunden
- Lizenz: CC0 1.0 Universal / Public Domain
- Quelle: <https://opengameart.org/content/puzzling>
- Lokaler Nachweis: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- Status: technisch eingebunden; musikalische Playtest-Abnahme offen

### 4.1 Vorgemerkt

#### Cave Music

- Rolle: provisorisches Höhlenthema
- Autor: hornpipe2
- Format: MIDI
- Lizenz: CC0
- Quelle: <https://opengameart.org/content/cave-music>
- Bewertung: bereits als passend vorgemerkt

#### 15 Melodic RPG Chiptunes

- Rolle: Kandidatenpool für Menü, Sokoban, Höhle und Game Over
- Autor: Aureolus_Omicron
- Formate: MIDI und OGG
- Lizenz: CC0
- Quelle: <https://opengameart.org/content/15-melodic-rpg-chiptunes>
- Interessante Startpunkte: Title Screen, Dungeon, Shrine of Mysteries und
  Game Over

#### Win Jingle

- Rolle: provisorischer Levelabschluss
- Autor: Fupi
- Formate: MIDI, OGG und WAV-Varianten
- Lizenz: CC0
- Quelle: <https://opengameart.org/node/114596>

### 4.2 Weitere Hörkandidaten

#### Cave Wonder und Tinkering Cave

- Rolle: alternative Höhlen-Loops
- Autor: tapatilorenzo
- Formate auf der Asset-Seite: MP3 plus editierbare BeepBox-Quelle
- Lizenz: CC0
- Quelle:
  <https://opengameart.org/content/2-midi-cave-songs-cave-wonder-tinkering-cave>
- Hinweis: Der Seitentitel nennt MIDI, die angebotenen Downloads sind derzeit
  jedoch MP3-Dateien. Vor Verwendung wird die tatsächlich verfügbare Quelldatei
  geprüft.

## 5. Vorgesehene Ereignis-Jingles

| Ereignis | Richtung | Ungefähre Dauer |
| --- | --- | ---: |
| Kiste erreicht Ziel | heller Zweiklang oder kurzer Motivteil | 200–350 ms |
| Kiste verlässt Ziel | sehr dezenter absteigender Ton | 150–250 ms |
| Diamant eingesammelt | heller Einzelton; begrenzte Tonhöhenfolge möglich | 100–250 ms |
| Erforderliche Diamanten erreicht | deutliches Drei- bis Vierton-Arpeggio | 600–1.000 ms |
| Ausgang öffnet sich | eigener öffnender Stinger | 700–1.200 ms |
| Spieler stirbt | kurzer absteigender, leicht rauer Akkord | 500–1.000 ms |
| Zeit abgelaufen | klarer terminaler Stinger | 600–1.200 ms |
| Level abgeschlossen | vollständige kleine Kadenz | 1–2 s |
| Neuer Bestwert | Zusatzmotiv nach dem Abschluss | 500–1.000 ms |

Das Einsammeln vieler Diamanten darf Tonhöhen innerhalb einer festen Skala
variieren. Die Folge wird begrenzt und kehrt anschließend kontrolliert zurück,
damit lange Serien nicht immer höher und schriller werden.

## 6. Mixing und Wiedergaberegeln

Es gibt vier logisch getrennte Busse:

1. Musik,
2. Jingles,
3. Spiel-Soundeffekte,
4. UI-Sounds.

Musik und Effekte/Jingles erhalten mindestens getrennte Lautstärkeregler. Ein
späterer eigener UI-Regler ist optional.

Wichtige Jingles dürfen die Musik kurz um ungefähr 3–5 dB absenken. Kleine
Sammel- oder Zielklänge lösen kein starkes Ducking aus. Musik wird nicht bei jedem
gewöhnlichen Spielereignis unterbrochen.

Für häufige oder flächige Ereignisse gelten Voice-Limits:

- gleichartige Effekte werden innerhalb eines kurzen Fensters zusammengefasst
  oder begrenzt,
- Explosionen erhalten Vorrang vor unwichtigen Schritten,
- ein Hard-Resync spielt keine aufgestauten Ereignisse nach,
- Pause oder Fokusverlust darf keine hängenden Stimmen hinterlassen.

Die exakten Pegel werden nach Gehör und mit Lautheitsmessung festgelegt. Kein
einzelner Effekt darf den Gesamtmix unerwartet übersteuern.

## 7. MIDI-Strategie

### 7.1 Empfehlung für den ersten Prototyp

MIDI dient als editierbare Produktionsquelle. Die ausgelieferte App verwendet
zunächst vorgerenderte, nahtlos loopbare Audiodateien. Vorteile:

- gleicher Klang auf allen unterstützten Macs,
- kein mitzuliefernder General-MIDI-SoundFont,
- einfachere Loop-, Lautheits- und Qualitätssicherung,
- geringe Laufzeitkomplexität.

Das Quell-MIDI und die Information über das zum Rendern verwendete Instrument
bleiben im Produktionsarchiv. Nur eindeutig lizenzierte Renderings gelangen in
die App.

### 7.2 Spätere adaptive Wiedergabe

Für adaptive Musik sind drei Wege möglich:

1. MIDI-Tracks zur Laufzeit mit einem eigenen oder eindeutig lizenzierten
   Instrumentensatz abspielen.
2. Mehrere vorgerenderte, taktgenaue Musikschichten synchron überblenden.
3. Einen kleinen eigenen Chiptune-Synth aus Oszillatoren und Rauschen verwenden.

Die zweite Variante ist der risikoärmste Einstieg in adaptive Musik. Die dritte
Variante bietet langfristig die stärkste eigene Identität und benötigt keine
fremden Instrument-Samples.

Adaptive Übergänge erfolgen bei musikalisch sinnvollen Grenzen, normalerweise
am nächsten Takt. Unmittelbare Ereignisse wie Tod oder Explosion dürfen dagegen
sofort erklingen.

## 8. Lizenzstrategie

### 8.1 Bevorzugte Lizenzen

Bevorzugt wird CC0. CC BY ist möglich, wenn die Namensnennung zuverlässig
umgesetzt wird. Assets mit `NC`, unklarer Herkunft oder unbestimmtem
„royalty-free“-Hinweis werden nicht verwendet.

CC BY-SA und andere Share-Alike-Lizenzen werden nur nach einer bewussten Prüfung
der Folgen für Bearbeitungen und Distribution aufgenommen.

### 8.2 Drei getrennte Rechteebenen

Bei MIDI werden getrennt geprüft:

1. Komposition und Arrangement,
2. MIDI-Datei beziehungsweise konkrete Bearbeitung,
3. Instrument-Samples, SoundFont oder gerenderte Aufnahme.

Eine gemeinfreie Komposition macht eine moderne Einspielung oder einen SoundFont
nicht automatisch frei. Ebenso erlaubt eine freie MIDI-Datei nicht automatisch
das Bündeln eines beliebigen General-MIDI-SoundFonts.

### 8.3 Asset-Nachweis

Für jedes fremde Audio-Asset werden festgehalten:

- interne Asset-ID,
- Titel und Autor,
- ursprüngliche Quell-URL,
- Lizenzbezeichnung und lokale Kopie des Lizenztexts,
- Download-Datum,
- Hash der unveränderten Quelldatei,
- vorgenommene Bearbeitungen,
- Lizenz und Herkunft aller zum Rendern verwendeten Samples oder SoundFonts.

Vor Veröffentlichung entsteht daraus `THIRD_PARTY_NOTICES.md`. Auch CC0-Urheber
werden nach Möglichkeit freiwillig genannt.

## 9. Vorgesehene Ressourcenstruktur

```text
MacGameApp/Resources/Audio/
├── Music/
├── Jingles/
├── Effects/
├── UI/
└── Licenses/
```

Produktionsquellen wie MIDI-Projekte oder unbearbeitete Mehrspurdateien können
außerhalb des App-Bundles in einem eigenen `AudioSources/`-Ordner liegen. Große
Quelldateien werden erst dann ins Repository aufgenommen, wenn die
Versionsverwaltungsstrategie dafür entschieden ist.

## 10. Audio-Meilenstein für den ersten spielbaren Prototyp

Der Audio-Prototyp ist ausreichend, wenn:

- ein provisorischer Sokoban-Loop und ein Höhlen-Loop eingebunden sind,
- `Cave Music` als erster Höhlenkandidat praktisch getestet wurde,
- Ziel, Diamant, Ausgang, Tod und Levelabschluss unterscheidbare Rückmeldungen
  besitzen,
- der Levelabschluss einen kurzen Jingle verwendet,
- Musik und Effekte/Jingles getrennt regelbar und stumm schaltbar sind,
- Pause, Neustart, Undo, Redo und Hard-Resync keine alten Klänge nachspielen,
- Herkunft und Lizenz jedes fremden Assets lokal dokumentiert sind.

## 11. Nächste Audio-Schritte

1. Die vorgemerkten CC0-Kandidaten in einheitlicher Lautstärke probehören.
2. Einen ruhigen Sokoban-Platzhalter auswählen.
3. Vier eigene Mini-Jingles für Ziel, Diamant, Ausgang und Tod skizzieren.
4. Das gemeinsame Leitmotiv festlegen.
5. Loop-Punkte, Pegel und Dateiformat im App-Prototyp testen.
6. Erst danach über Live-MIDI, Musikschichten oder einen eigenen Chiptune-Synth
   entscheiden.
