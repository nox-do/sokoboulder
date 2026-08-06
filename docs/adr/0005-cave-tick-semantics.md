# ADR 0005: Cave Tick Semantics

Status: Accepted  
Datum: 2026-08-03  
Plan: [docs/plans/3.7-cave-tick-semantics.md](../plans/3.7-cave-tick-semantics.md)

## Kontext

Vor Phase 4 muss genau ein Tick-Verfahren festliegen (ARCHITECTURE §7.4 / §8).
Spielerregeln stehen in GAMEPLAY.md §6. Original-Cave-Dateien sind Nicht-Ziel;
wir brauchen reproduzierbare eigene Physik, Replays und Golden-Tests.

Zwei klassische Ansätze:

1. **In-place Cave-Scan** (oben→unten, links→rechts) mit
   `processedTick`/`processedGeneration`, damit Objekte nicht mehrfach laufen —
   originalnah, positionsabhängige Eigenheiten.
2. **Simultane Intents** (Phase A berechnen, B Konflikte, C anwenden) —
   vorhersehbarer für neue Level, Explosions-Queues natürlich.

## Entscheidung

1. **Updateverfahren:** Simultane Intents / Double-Buffer als **einziges**
   Produktverfahren in Phase 4/5. In-place-Scan nur optional später; nicht
   parallel abstrahieren.
2. **Update-once:** Jede zu Tickbeginn vorhandene bewegliche Entität höchstens
   eine Aktion; neu erzeugte Entitäten handeln erst ab dem **nächsten** Tick.
3. **Intent-Berechnungsreihenfolge:** Zeilen oben→unten, Spalten links→rechts.
4. **Rollen:** links vor rechts; nach Roll = `falling`.
5. **Freilegen→Fall:** Im Tick ohne Unterstützung wird `falling` gesetzt; die
   Zellenbewegung folgt im **nächsten** Tick (1-Tick-Lag). Golden #1/#4.
6. **Explosionen:** Queue; Typen `destructive` und `diamondGenerating`.
   Drain **nach jeder Tick-Phase** (Spieler / Gravity / Gegner), nicht erst am
   Tickende; Early-Exit bei terminalem Status. Überlappende Zellen: FIFO,
   letzter Schreiber gewinnt. Stahl und Ausgang (MVP) unzerstörbar.
   Gegner-Intents nur auf geraden Ticks (`tick % 2 == 0`).
7. **Zellkonflikte:** objektbezogen in Golden-Tests; Fallback:
   Explosion > Fall > Spieler > Gegner > Amöbe.
8. **Terminal:** Tod vor Exit-Abschluss; Zeitablauf am Tickende; Tod+Exit → Tod.
9. **Tickrate:** `fixedStep = 0.10` (10 Hz).
10. **Ready:** keine Ticks; erste Absicht → Epoche + Tick 1.
11. **Eingabe Phase 4:** nur `move` und `wait`. Kein Snap, keine
    Schiebeverzögerung (erst nach Playtest + Freigabe).
12. **Digest/Replay:** globale `simulationTick` + Absichten; keine Epochen.

Weltmodell bleibt ARCHITECTURE §6.2 — kein flaches `Tile`-Enum mit Spieler in
der Zelle.

## Alternativen

1. **Sofort In-place-Scan als Default** — verworfen für V1, weil Originalnähe
   kein Ziel ist und Golden-Level sonst Scan-Artefakte tragen müssten.
2. **Beide Verfahren hinter einem Protokoll** — verworfen (Overengineering vor
   Bedarf).
3. **20 Hz Default** — zurückgestellt; 10 Hz zuerst, Playtest darf anheben.

## Folgen

- Phase 3.7 liefert Golden-Konfliktraster und Digest gegen diese Semantik.
- Phase 4 implementiert `CaveRules.tick` genau einmal nach diesem ADR.
- Phase 5.1 (Gegner/Explosionen) folgt denselben Intent-/Queue-Verträgen;
  Amöbe/Magic Wall folgen in 5.2.
- Historische Emulation bleibt bewusst außerhalb des Produktpfads.

## Verankerung

Golden-Tests der Phase 3.7 verankern Punkte 5, 7 und 8. Weicht ein Test eine
Feinheit ab, wird dieses ADR in einem Satz nachgezogen — es entsteht kein
zweites paralleles Verfahren.
