# ADR 0003: Auflösungsunabhängige Brett-Skalierung

Status: Accepted
Datum: 2026-08-02

## Kontext

Phase 3.4 verlangt eine verbindliche Skalierungsentscheidung für das Spielfeld.
Architekturabschnitt 23 ließ zwei Alternativen offen:

1. Pixel-Art mit ganzzahliger Tile-Skalierung
2. Auflösungsunabhängiger Shape-/Vektor-Stil

Das Spielfenster auf macOS ist frei skalierbar. Ganzzahlige Pixel-Stufen würden
häufig große Letterbox-Ränder, sprunghafte Größenwechsel oder ein unnötig
kleines Spielfeld erzeugen.

## Entscheidung

Für Phase 3.4 und den Standard-Renderer gilt Stil **B**:

- Tiles bleiben **quadratisch**; die Brettproportion `width × height` ist konstant.
- Die Tile-Kantenlänge passt sich **stufenlos** an die verfügbare Board-Fläche an
  (Letterboxing statt Verzerrung).
- Darstellung erfolgt über **prozedurale Shapes und Symbole**, nicht über
  pixelgebundene Texture-Atlanten.
- Auf Retina-Displays werden Linien und Konturen so positioniert, dass sie
  möglichst **scharf** bleiben (ganzzahlige Point-Ausrichtung der Brettorigin
  und Kanten, wo sinnvoll).
- **Keine Gameplay-Geometrie** darf außerhalb des sichtbaren Board-Bereichs
  liegen; HUD und Overlays belegen getrennte Layoutflächen.

Pixel-Art mit kontinuierlicher Größe und `.nearest`-Filter ist ein eigenes
Rendering-Profil ([ADR 0004](0004-pixel-rendering-profile.md)). Der Vektorvertrag
dieses ADR gilt für Themes ohne Pixel-Profil (Fallback `theme.standard`); das
Produkt-Default seit Phase 3.8 ist ein Pixel-Theme (`theme.dungeon`).

## Alternativen

1. **Ganzzahlige Pixel-Skalierung** – verworfen für den Standardpfad, weil
   Fenstergrößen auf macOS selten exakte Vielfache der Basis-Tilegröße treffen.
2. **Nicht-quadratische Tiles / Streckung** – verworfen, weil Rasterregeln und
   Lesbarkeit von Formsymbolen darunter leiden.

## Folgen

- `GridGeometry` bleibt der alleinige Ort für Modell→SpriteKit-Umrechnung und
  Letterboxing.
- Theme-JSONs liefern Farben, Konturen und Symbole; die Laufzeit-`tileSize`
  kommt aus `GridGeometry` (beide Profile stufenlos).
- Pixel-Art-Themes nutzen ADR 0004 (`pixelNearest` + Texture-Keys). Der
  Vektorvertrag bleibt für den Fallback-/Dev-Pfad gültig; Settings-Default ist
  `theme.dungeon`.
