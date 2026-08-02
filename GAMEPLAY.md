# Gameplay- und Spielerlebniskonzept

Status: Arbeitsgrundlage für Onboarding, Spielfluss und Bedienbarkeit  
Geltungsbereich: Spielerlebnis beider Spiele, HUD, Kamera, Feedback,
Barrierefreiheit und Playtests  
Technische Architektur und Schnittstellen: siehe
[ARCHITECTURE.md](ARCHITECTURE.md)  
Musik, MIDI, Jingles und Soundeffekte: siehe [AUDIO.md](AUDIO.md)

## 1. Zielbild

Beide Spiele sollen unmittelbar verständlich, schnell bedienbar und angenehm
wiederholbar sein:

- Der Spieler gelangt ohne lange Einführung in das erste Level.
- Jede Eingabe liefert sofort erkennbares Feedback.
- Fehler lassen sich bei Sokoban bequem korrigieren.
- Tod und Neustart im Höhlenspiel sind fair, verständlich und schnell.
- Wichtige Informationen sind gleichzeitig visuell und, sofern sinnvoll,
  akustisch wahrnehmbar.
- Animation, Musik oder UI-Übergänge verzögern niemals die autoritative
  Simulation.
- Tastaturbedienung ist vollständig; Gamecontroller bleiben eine zusätzliche
  Eingabemöglichkeit.

Sokoban belohnt ruhiges Nachdenken. Das Höhlenspiel erzeugt kontrollierten
Zeitdruck. Beide Spiele teilen Navigation, Ergebnisdarstellung, Einstellungen
und eine gemeinsame visuelle sowie akustische Identität.

## 2. Leitende Erlebnisprinzipien

### 2.1 Schnell ins Spiel

Der erste Start führt nach einer sehr kurzen Spielauswahl direkt in ein
Tutorial-Level. Es gibt keine verpflichtende lange Erklärung und keinen
unüberspringbaren Vorspann.

### 2.2 Eine neue Regel zur gleichen Zeit

Tutorial-Level führen Mechaniken einzeln ein. Text erklärt nur, was nicht
zuverlässig durch den Levelaufbau vermittelt werden kann.

### 2.3 Sofortige, eindeutige Rückmeldung

Bewegung, Blockade, Ziel, Diamant, Ausgang, Tod und Abschluss unterscheiden sich
visuell und akustisch. Farbe ist nie der einzige Informationsträger.

### 2.4 Schnelle Wiederholung

Undo, Redo, Neustart und „Noch einmal“ sind kurze, vorhersehbare Aktionen. Ein
Neustart verlangt im normalen Spiel keinen Bestätigungsdialog.

### 2.5 Keine Überraschung durch Präsentation

Das Modell entscheidet sofort. Die Präsentation darf das sichtbare Ergebnis kurz
ausspielen, aber weder Eingaben rückwirkend verändern noch den nächsten
autoritativen Zustand bestimmen.

## 3. Gemeinsamer Spielfluss

```text
App-Start
   ↓
Hauptmenü
   ↓
Spiel- und Levelauswahl
   ↓
Level-Einführung / Ready
   ↓
Spiel läuft ◄────► Pause
   ↓
Abschluss- oder Todespräsentation
   ↓
Ergebnisaktionen: Weiter · Noch einmal · Undo · Levelauswahl
```

### 3.1 Level-Einführung

Vor jedem Level werden höchstens folgende Informationen gezeigt:

- Levelname oder Nummer,
- ein kurzer Zielhinweis,
- bei Höhlen: benötigte Diamanten und Zeitlimit,
- eine neue Steuerungs- oder Regelhilfe, falls dieses Level eine Mechanik
  erstmals einführt.

Die Einführung ist überspringbar. Ein erstmalig gezeigter Lernhinweis wartet auf
eine bewusste Eingabe und verschwindet nicht nach einem Zeitlimit. Wiederholte
Versuche zeigen ihn verkürzt oder gar nicht, sofern der Spieler ihn nicht erneut
anfordert.

### 3.2 Pause

Pause stoppt die Höhlensimulation vollständig. Der Pausenbildschirm bietet:

- Fortsetzen,
- Neustart,
- Einstellungen,
- Levelauswahl,
- Steuerungsübersicht.

Fensterdeaktivierung und System-Sleep pausieren automatisch. Beim Fortsetzen
werden keine alten Eingaben übernommen.

### 3.3 Ergebnisaktionen

Jeder terminale Zustand bietet vollständig per Tastatur erreichbare Aktionen:

| Zustand | Primäraktion | Weitere Aktionen |
| --- | --- | --- |
| Sokoban abgeschlossen | Nächstes Level | Noch einmal, Undo, Levelauswahl |
| Höhle abgeschlossen | Nächstes Level | Noch einmal, Levelauswahl |
| Höhlenspiel verloren | Noch einmal | Levelauswahl |

Die zuletzt beziehungsweise sinnvollste Aktion erhält den initialen Fokus.

## 4. Onboarding und Tutorial-Level

### 4.1 Gemeinsame Regeln

- Hinweise erscheinen kontextuell und sind überspringbar.
- Ein bereits verstandener Hinweis wird nicht in jedem Level wiederholt.
- Das Spiel zeigt Tasten passend zur zuletzt verwendeten Eingabemethode.
- Tutorial-Hinweise blockieren die Simulation nur vor dem eigentlichen Start.
- Alle Hinweise bleiben manuell in einer Steuerungs- oder Hilfeansicht
  erreichbar.

### 4.2 Sokoban-Einstieg

Empfohlene Reihenfolge:

1. freie Spielerbewegung,
2. genau eine Kiste in gerader Linie schieben,
3. Kiste auf ein Ziel stellen,
4. Kiste kann nicht gezogen werden,
5. Kisten blockieren einander,
6. Undo und Redo,
7. einfacher sicherer Deadlock.

Die ersten Level sollen durch ihre Geometrie lehren. Ein Textfenster erklärt nur
kurz, dass Kisten ausschließlich geschoben werden können.

### 4.3 Höhlenspiel-Einstieg

Empfohlene Reihenfolge:

1. Bewegung und Erde entfernen,
2. Diamanten sammeln,
3. Ausgang öffnen und erreichen,
4. ruhender und fallender Fels,
5. Fels horizontal schieben,
6. seitliches Abrollen,
7. Zeitlimit,
8. erster Gegner,
9. Explosion und Kettenreaktion.

Kein Tutorial-Level führt zwei potenziell tödliche neue Mechaniken gleichzeitig
ein.

## 5. Sokoban-Spielerlebnis

### 5.1 Bedienung

Standardbefehle:

- Pfeiltasten oder WASD: bewegen,
- `Command-Z` sowie optional `Z`: Undo,
- `Shift-Command-Z`: Redo,
- `R`: sofort neu starten,
- `Escape`: Pause beziehungsweise zurück,
- Menübefehle spiegeln alle Aktionen mit sichtbaren Tastaturkürzeln.

Ein erfolgreicher Zug wird logisch sofort ausgeführt. Animationen dürfen schnelle
Folgeeingaben nicht sperren.

### 5.2 HUD

Das Sokoban-HUD zeigt mindestens:

- Levelname oder Nummer,
- Zugzahl,
- Anzahl der Schübe,
- belegte Ziele im Verhältnis zur Gesamtzahl,
- Verfügbarkeit von Undo und Redo.

Zugzahl und Schubzahl werden getrennt erfasst. Eine reine Spielerbewegung erhöht
nur die Zugzahl; das Versetzen einer Kiste erhöht zusätzlich die Schubzahl.

### 5.3 Undo und Redo

Undo und Redo sind Kernbestandteile des Spielerlebnisses:

- Jeder verändernde Zug erzeugt einen Undo-Schritt.
- Blockierte Bewegungen erzeugen keinen Verlaufsschritt.
- Undo verschiebt den aktuellen Zustand in den Redo-Verlauf.
- Redo stellt den zuletzt rückgängig gemachten Zustand wieder her.
- Ein neuer verändernder Zug nach Undo verwirft den Redo-Verlauf.
- Neustart und Levelwechsel leeren beide Verläufe.
- Nach einem Levelabschluss darf Undo den Spieler zurück ins laufende Level
  bringen.
- Undo und Redo verwenden einen visuellen Hard-Resync und spielen keine
  historischen Jingles rückwärts oder erneut ab.

### 5.4 Deadlock-Unterstützung

Version 1 verspricht keinen Solver und keine allgemeine Deadlock-Erkennung.
Erkannt werden ausschließlich mathematisch sichere statische Fälle, zum
Beispiel eine Kiste auf einem Nicht-Zielfeld in einer unbeweglichen Ecke oder
an einer toten Wandreihe.

Ausgelieferte Level werden strenger behandelt als laufende Partien: Der
Content-Loader lehnt bereits beim Start statisch tote Kistenpositionen ab. Eine
bekannte Lösung pro Kampagnenlevel bleibt zusätzlich Bestandteil der Tests.

Ein Schub auf ein solches garantiert totes Feld wird als blockiert behandelt
und mit einem kurzen Hinweis erklärt. Alte gespeicherte Läufe werden beim Laden
bis vor den verursachenden Schub zurückgespult. Ist der Deadlock bereits in
einen kompaktierten Checkpoint eingegangen, startet das Level neu.

Unsichere oder strategische Sackgassen bleiben gültige Spielzustände und werden
nicht als Fehler behauptet.

### 5.5 Levelabschluss

Der letzte Zug wird sichtbar beendet und erhält seinen Abschlussjingle. Danach
erscheint das Ergebnis mit:

- Zug- und Schubzahl,
- bisherigen Bestwerten,
- Kennzeichnung eines neuen Bestwerts,
- Weiter, Noch einmal, Undo und Levelauswahl.

Eine bereits freigeschaltete Fortschrittsstufe wird durch Undo nach dem Abschluss
nicht zurückgenommen.

### 5.6 Automatische Wiederaufnahme

Ein laufendes Sokoban-Level wird automatisch gesichert:

- Level-ID und Inhalts-Hash,
- aktueller Zustand,
- Undo- und Redo-Verlauf beziehungsweise rekonstruierbare Befehlshistorie,
- Zug- und Schubzähler.

Beim nächsten App-Start kann der Spieler direkt fortsetzen oder das Level neu
beginnen. Inkompatible oder beschädigte Daten verhindern den App-Start nicht.

## 6. Höhlenspiel-Spielerlebnis

### 6.1 Ready-State

Ein Höhlenlevel beginnt nicht sofort mit laufender Gravitation.

Im Ready-State:

- ist die Höhle bereits sichtbar,
- zeigt das HUD Ziel, Diamantbedarf und Zeitlimit,
- laufen keine Simulationsticks,
- werden gehaltene Eingaben noch nicht aus einer vorherigen Ansicht übernommen.

Die erste gültige Bewegungs- oder Warteingabe startet die Timing-Epoche und wird
dem ersten Simulationstick zugeordnet. Alternativ kann ein kurzer, überspringbarer
Countdown als Einstellung oder spätere Präsentationsvariante angeboten werden.

### 6.2 HUD

Das Höhlen-HUD zeigt mindestens:

- gesammelte und benötigte Diamanten,
- verbleibende Zeit,
- Punktestand,
- klaren Zustand des Ausgangs.

Zusätzliche Werte wie Leben oder Bonus werden erst angezeigt, wenn die
entsprechenden Regeln existieren.

### 6.3 Kamera

Die Kamera folgt nicht bei jedem einzelnen Rasterschritt exakt dem Spieler.
Stattdessen verwendet sie:

- eine ruhige Safe Zone um die Spielerposition,
- sanftes Nachführen außerhalb dieser Zone,
- einen kleinen Blickvorsprung in die zuletzt aktive Bewegungsrichtung,
- harte Begrenzung an den Levelrändern,
- sofortige Positionierung ohne Fluganimation bei Neustart oder Hard-Resync.

Die Einstellung „Bewegung reduzieren“ verkleinert oder entfernt weiches
Nachführen, Kamera-Look-ahead, Shake und starke Zoombewegungen.

Gefahren dürfen nicht allein deshalb unfair werden, weil sie knapp außerhalb des
sichtbaren Ausschnitts liegen. Leveldesign und Kamera werden gemeinsam
playgetestet.

### 6.4 Lesbarkeit und Fairness

- Ruhende und fallende Felsen sind klar unterscheidbar.
- Diamanten unterscheiden sich durch Form und Bewegung von Felsen, nicht nur
  durch Farbe.
- Erde, begehbarer Raum, Wand und Ausgang besitzen eindeutige Silhouetten.
- Der geöffnete Ausgang wird sichtbar hervorgehoben und akustisch angekündigt.
- Bei knapper Zeit erfolgen visuelle und akustische Warnung, ohne jeden Tick
  störend zu markieren.
- Gegner zeigen ihre Bewegungsrichtung oder ihr lokales Verhalten ausreichend
  deutlich.
- Tödliche Kettenreaktionen bleiben nach Möglichkeit visuell nachvollziehbar.

### 6.5 Tod

Beim Tod wird die Simulation sofort terminal. Die Präsentation zeigt anschließend
kurz und überspringbar:

- Todesort und verursachendes Objekt beziehungsweise Explosion,
- einen kleinen Freeze oder eine verlangsamte Abschlussbewegung,
- den Todes-Stinger,
- danach sofort die Aktion „Noch einmal“.

Ein Tastendruck, der den Tod verursacht oder unmittelbar davor gepuffert wurde,
darf nicht versehentlich den Ergebnisdialog bestätigen oder den Neustart auslösen.

### 6.6 Schneller Neustart

„Noch einmal“ beziehungsweise `R` startet dasselbe Level ohne
Bestätigungsdialog, erneuten langen Einführungstext oder unnötige Ladeansicht.
Die Höhle kehrt in den Ready-State zurück.

Eine laufende Höhlenpartie wird in Version 1 nicht über einen App-Neustart hinweg
fortgesetzt. Gespeichert werden Levelauswahl und Bestleistungen; beim Wiederöffnen
beginnt die Höhle im Ready-State neu.

## 7. Präsentation terminaler Zustände

Autoritativer Spielstatus und sichtbare Ergebnispräsentation sind getrennt:

```text
running
   ↓ fachliches Ergebnis
terminalPresenting
   ↓ kurze, überspringbare Animation/Jingle
terminalAwaitingChoice
```

Während `terminalPresenting`:

- akzeptiert die Session keine normalen Spielzüge,
- darf die Präsentation übersprungen werden,
- bleiben Pause-, Menü- und Fensterbefehle verfügbar,
- wird noch keine versehentliche Eingabe als Ergebnisaktion übernommen.

Die Präsentation besitzt eine feste kurze Maximaldauer und wartet nicht auf eine
Rückbestätigung von Renderer oder AudioDirector. Bei „Bewegung reduzieren“ wird
sie verkürzt oder durch eine Überblendung ersetzt.

## 8. Steuerung und Eingabegeräte

### 8.1 Tastatur

Die Tastatur ist auf macOS immer vollständig unterstützt. Aktionen verwenden
komfortable Einzeltasten, ohne systemübliche Kurzbefehle umzudeuten.

Die Spielmenüs besitzen zusätzlich eine app-eigene Navigation, die unabhängig
von der macOS-Einstellung „Full Keyboard Access“ funktioniert:

| Kontext | Hoch/Runter | Links/Rechts | Return/Leertaste | Escape |
| --- | --- | --- | --- | --- |
| Aktionsmenü | Auswahl bewegen | Auswahl bewegen | markierte Aktion | zurück |
| Levelauswahl | Level bewegen | Level bewegen | Level öffnen | Übersicht |
| Einstellungen | Zeile bewegen | Slider ändern | Toggle/Aktion | zurück |
| Ergebnis | Aktion bewegen | Aktion bewegen | markierte Aktion | Levelauswahl |

Deaktivierte Aktionen werden übersprungen. Die Markierung bleibt jederzeit
sichtbar und darf nicht hinter der SpriteKit-Ansicht verschwinden.

Alle gameplayrelevanten Tasten können später neu belegt werden. Nicht erlaubte
Konflikte werden verständlich angezeigt. Menübefehle und Hilfe zeigen die
tatsächlich aktive Belegung.

### 8.2 Gamecontroller

Gamecontroller sind optional. Bei Verbindung:

- wird das Gerät automatisch erkannt,
- wechseln Hinweise auf passende Controller-Symbole,
- D-Pad und linker Stick steuern Bewegung,
- Menüs folgen den üblichen Bestätigen-/Zurück-Konventionen,
- die Tastatur bleibt jederzeit als Fallback aktiv.

### 8.3 Fokus und Eingabeschutz

- Fokusverlust leert gehaltene Richtungen und Press-Latch.
- UI-Tastendrücke werden nicht nach Schließen eines Overlays als Spielbewegung
  wiederverwendet.
- Der Start-, Todes- und Abschluss-Tastendruck wird nicht doppelt interpretiert.
- Ein Wechsel des Eingabegeräts erfordert keinen manuellen Moduswechsel.

## 9. Barrierefreiheit

### 9.1 Wahrnehmbarkeit

- Keine wichtige Information wird ausschließlich durch Farbe oder Audio
  vermittelt.
- Audio-Jingles besitzen sichtbare Entsprechungen.
- Visuelle Warnungen besitzen, soweit sinnvoll, akustische Entsprechungen.
- Text, HUD und Fokusmarkierungen bleiben bei verschiedenen Fenstergrößen gut
  lesbar.
- Ein kontrastreiches Theme wird vorgesehen.

### 9.2 Bewegung und Blinken

Die App berücksichtigt die Systemeinstellung „Bewegung reduzieren“ und bietet
zusätzlich eigene Optionen für:

- Bildschirmerschütterung,
- Kameranachlauf,
- starke Partikel,
- blinkende oder schnell pulsierende Effekte.

Gefährliche Zustände dürfen auch ohne Blinken eindeutig erkennbar sein.

### 9.3 Vollständige Tastaturbedienung

Hauptmenü, Levelauswahl, Einstellungen, Pause und Ergebnisdialoge sind durch die
App selbst vollständig per Tastatur erreichbar; Full Keyboard Access ist keine
Voraussetzung. Der sichtbare Fokus verschwindet nicht hinter der
SpriteKit-Ansicht.

### 9.4 Zugängliche Rasterbeschreibung

Der erste Meilenstein benötigt keine zellenweise VoiceOver-Navigation. Er bietet
aber eine kompakte Beschreibung mit:

- Spielmodus und Level,
- Spielerposition,
- Ziel- beziehungsweise Diamantfortschritt,
- verbleibender Zeit,
- aktuellem Ergebniszustand.

## 10. Feedback und Audio

Die fachliche Zuordnung konkreter Musik, Jingles und Effekte steht in
[AUDIO.md](AUDIO.md). Für das Gameplay gelten:

- gewöhnliche Rückmeldungen bleiben kurz und überlagern die Musik nicht unnötig,
- Levelabschluss, Ausgang und Tod sind akustisch klar unterscheidbar,
- Audioausfall oder Stummschaltung beeinträchtigen keine Information oder
  Bedienung,
- Undo, Redo, Neustart und Hard-Resync spielen keine historischen Ereignisse
  erneut ab,
- viele gleichzeitige Höhlenereignisse werden akustisch priorisiert und begrenzt.

## 11. Fortschritt und Motivation

- Abgeschlossene Level bleiben dauerhaft freigeschaltet.
- Bestwerte werden pro Level, Inhalts-Hash und Regelversion gespeichert.
- Sokoban vergleicht mindestens Zug- und Schubzahl.
- Das Höhlenspiel vergleicht Punktestand und bei Bedarf Restzeit.
- Ein neuer Bestwert wird sichtbar und akustisch gewürdigt.
- Der Spieler kann bereits abgeschlossene Level jederzeit erneut spielen.
- Die Levelauswahl zeigt Fortschritt, ohne unbekannte Mechaniken unnötig zu
  verraten.

Sterne, tägliche Aufgaben, Online-Bestenlisten oder künstliche
Fortschrittswährungen sind kein Ziel der ersten Version.

## 12. Leveldesign und Schwierigkeitskurve

### 12.1 Sokoban

- Frühe Level sind kurz und besitzen wenige Kisten.
- Keine Kiste startet auf einem statisch toten Feld; das wird beim Laden geprüft.
- Schwierigkeit entsteht zuerst durch Positionierung, später durch Reihenfolge.
- Lange Laufwege ohne Entscheidung werden vermieden.
- Eindeutige Deadlock-Fallen werden vor komplexen Kombinationen eingeführt.
- Ein Level darf schwer sein, aber sein Ziel und seine Regeln müssen klar bleiben.

### 12.2 Höhlenspiel

- Sichere Startbereiche ermöglichen Orientierung.
- Neue Gefahren werden zunächst einzeln und mit ausreichend Reaktionsraum gezeigt.
- Zufällige oder nicht telegraphierte Tode werden vermieden.
- Zeitlimits werden nach Playtests gesetzt, nicht nur rechnerisch geschätzt.
- Kameraausschnitt und Levelgeometrie dürfen notwendige Information nicht
  verstecken.
- Schwierigkeit steigt über Regelkombinationen, nicht lediglich über immer
  knappere Zeit.

## 13. Playtest-Strategie

### 13.1 Beobachtungsfragen

- Versteht ein neuer Spieler das erste Level ohne externe Erklärung?
- Wird erkannt, dass Kisten nicht gezogen werden können?
- Finden Spieler Undo, Redo und Neustart?
- Können Spieler bei deaktiviertem Full Keyboard Access jede Menüaktion mit
  Pfeiltasten, Return/Leertaste und Escape erreichen?
- Ist die Todesursache im Höhlenspiel verständlich?
- Wird der geöffnete Ausgang schnell gefunden?
- Fühlt sich die Kamera ruhig und trotzdem hilfreich an?
- Werden schnelle Richtungstaps zuverlässig umgesetzt?
- Ist die Zeitwarnung wahrnehmbar, aber nicht störend?
- Werden Musikloops oder häufige Effekte nach zehn Minuten ermüdend?
- Welche Level führen zu Neustart, Undo oder Abbruch?

### 13.2 Messbare Qualitätsziele

- Vom App-Start bis zur ersten möglichen Bewegung sind nur wenige Interaktionen
  erforderlich.
- Neustart und Undo fühlen sich unmittelbar an.
- Kein Testspieler stirbt vor dem ersten steuerbaren Tick eines neu geladenen
  Höhlenlevels.
- Ergebnisaktionen sind ohne Maus erreichbar.
- Ein stummgeschalteter Spieler erkennt Bewegung, Blockade, Schub, Zielzustand
  und Abschluss weiterhin eindeutig.
- Ein Hard-Resync erzeugt weder Doppelanimation noch doppelten Jingle.
- Verschiedene Renderframeraten verändern weder Eingaben noch Ergebnis.

Lokale Diagnosewerte dürfen für interne Playtests protokolliert werden. Eine
Übertragung von Telemetrie ist kein Ziel der ersten Version.

## 14. Meilensteine

### 14.1 Erster Sokoban-Prototyp

- Drei spielbare Tutorial-Level,
- Zug- und Schubzähler,
- Undo, Redo und Neustart,
- sichtbarer Zielzustand,
- Abschlusspräsentation mit Tastaturaktionen,
- automatische Wiederaufnahme eines laufenden Levels,
- reduzierte Bewegung und getrennte Audio-Lautstärken.

### 14.2 Erstes Höhlenlevel

- Ready-State vor Tick 1,
- klare Diamant-, Zeit- und Ausgangsanzeige,
- ruhige Kamera-Safe-Zone,
- verständliche Fall-, Sammel- und Todesrückmeldung,
- schneller Neustart zurück in Ready,
- Höhlenmusik und zentrale Ereignis-Jingles,
- visuelle Alternativen für alle Audiohinweise.

## 15. Referenzen

- Apple Human Interface Guidelines, Designing for games:
  <https://developer.apple.com/design/human-interface-guidelines/designing-for-games/>
- Apple Human Interface Guidelines, Game controls:
  <https://developer.apple.com/design/human-interface-guidelines/game-controls>
- Apple Human Interface Guidelines, Accessibility:
  <https://developer.apple.com/design/human-interface-guidelines/accessibility/>
