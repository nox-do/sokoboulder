# ADR 0004: Pixel-Rendering-Profil für optionale Themes

Status: Accepted
Datum: 2026-08-03

## Kontext

[ADR 0003](0003-resolution-independent-board-scaling.md) legt den Standard-Renderer auf
stufenlose Vektor-/Shape-Skalierung fest. Phase 3.8 ergänzt Pixel-Art-Themes
(Dungeon-Mix + Kenney), ohne den Vektorvertrag zu brechen.

## Entscheidung

Themes tragen ein optionales Rendering-Profil (Schema V1, additiv):

1. **`vectorContinuous`** (Default) — Verhalten nach ADR 0003.
2. **`pixelInteger`** — gleiche stufenlose `tileSize`-Formel wie Vektor (Fenster
   füllen / Aspect-Letterbox); Texturen mit `.nearest`-Filter; Entity-Inset 0;
   Brett-Strokes/Symbole aus.

Frühere Integer-Schritte (`baseTilePoints`-Vielfache / `maxIntegerScale`) ließen
zwischen den Stufen große Letterbox-Lücken. Deshalb: kontinuierliche Größe +
Nearest-Neighbor (etwas weichere Pixel an Bruchteilen, Brett füllt den Platz).

`GridGeometry` bleibt die einzige Koordinatenquelle. Verzweigung über das Profil
(Texturen / Inset / Feedback), nicht über hardcodierte Theme-IDs.
`baseTilePoints` / `maxIntegerScale` bleiben im Schema (Authoring / Abwärtskompatibilität),
steuern die Scale aber nicht mehr.

## Alternativen

1. **Pixel als neuer Default** — verworfen; ADR 0003 und Fensterfreiheit bleiben
   Priorität für den Standardpfad.
2. **SchemaVersion 2** — verworfen; optionales `rendering` in V1 reicht.
3. **Integer-Scale beibehalten** — verworfen nach Playtest (zu viel Letterbox).

## Folgen

- `theme.standard` ohne `rendering` bleibt unverändert (Code-Fallback / Dev-Switch).
- `theme.dungeon` (Default) und `theme.kenney` sind in Settings wählbar; fehlende
  Texturen → Theme entfällt / Fallback Standard, Catalog bleibt ladbar.
- Push-/Celebration-Feedback darf nicht allein auf Solid-Color-Fills beruhen.
