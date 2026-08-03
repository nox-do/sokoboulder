# ADR 0004: Pixel-Rendering-Profil für Themes

Status: Accepted
Datum: 2026-08-03
Aktualisiert: 2026-08-03 (Hygiene: Profilname `pixelNearest`, Produkt-Default Dungeon)

## Kontext

[ADR 0003](0003-resolution-independent-board-scaling.md) legt den Vektor-/Shape-Pfad
auf stufenlose Skalierung fest. Phase 3.8 ergänzt Pixel-Art-Themes
(Dungeon-Mix + Kenney). Produkt-Default ist `theme.dungeon`; der Vektorpfad
(`theme.standard`) bleibt Code-Fallback und DEBUG-Dev-Switch.

## Entscheidung

Themes tragen ein optionales Rendering-Profil (Schema V1, additiv):

1. **`vectorContinuous`** (Default im Schema, wenn `rendering` fehlt) — Verhalten nach ADR 0003.
2. **`pixelNearest`** — gleiche stufenlose `tileSize`-Formel wie Vektor (Fenster
   füllen / Aspect-Letterbox); Texturen mit `.nearest`-Filter; Entity-Inset 0;
   Brett-Strokes/Symbole aus.

Frühere Integer-Schritte (`baseTilePoints`-Vielfache / `maxIntegerScale`) und der
Entwurfsname `pixelInteger` wurden verworfen bzw. umbenannt: kontinuierliche Größe +
Nearest-Neighbor (etwas weichere Pixel an Bruchteilen, Brett füllt den Platz).
Der Loader akzeptiert `pixelInteger` weiterhin als Alias beim Dekodieren.

`GridGeometry` bleibt die einzige Koordinatenquelle. Verzweigung über das Profil
(Texturen / Inset / Feedback), nicht über hardcodierte Theme-IDs.
`baseTilePoints` / `maxIntegerScale` bleiben im Schema (Authoring / Abwärtskompatibilität),
steuern die Scale aber nicht mehr.

## Alternativen

1. **Vektor als Settings-Default behalten** — verworfen zugunsten des Pixel-Looks;
   Vektor bleibt Fallback bei Catalog-/Texturfehlern und via Dev-Switch.
2. **SchemaVersion 2** — verworfen; optionales `rendering` in V1 reicht.
3. **Integer-Scale beibehalten** — verworfen nach Playtest (zu viel Letterbox).

## Folgen

- `theme.standard` ohne `rendering` bleibt Code-Fallback / Dev-Switch (kein Manifest-Eintrag).
- `theme.dungeon` (Settings-Default) und `theme.kenney` sind wählbar; fehlende
  Texturen → Theme entfällt / Fallback Standard, Catalog bleibt ladbar.
- Push-/Celebration-Feedback darf nicht allein auf Solid-Color-Fills beruhen.
