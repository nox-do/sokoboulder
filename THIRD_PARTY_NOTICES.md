# Third-Party Notices

## `audio.music.sokoban.puzzling`

- Title: `Puzzling`
- Author: Ruskerdax
- Source: <https://opengameart.org/content/puzzling>
- Original file: `ruskerdax_-_puzzling.mp3`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-02
- SHA-256 of the unchanged source file:
  `30e0b3fb95445181250ae9a5c1a6932cb49cbfffaa6d8f06d7360fe88b601f98`
- Changes: renamed to `sokoban-puzzling.mp3`; audio data otherwise unchanged.
- Settings ID: `music.sokoban.puzzling` (default)

Attribution is not required by CC0. The author and source are listed voluntarily.

## `audio.music.sokoban.prelude`

- Title: `Prelude (Story)` / original: `Вступление (История) (1)`
- Author: Alexandr Zhelanov
- Source: <https://opengameart.org/content/old-music>
- Original file: `Вступление (История) (1).mp3`
- License: **CC-BY 3.0**
- Local license: `MacGameApp/Resources/Audio/Licenses/CC-BY-3.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged source file:
  `45df4b87916ba36defb3605db77827864997830e0a9f41c9c59be387d2eeffdf`
- Changes: renamed to `sokoban-prelude.mp3`; audio data otherwise unchanged.
- Settings ID: `music.sokoban.prelude`
- Attribution (required): Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov

## `audio.music.cave.wonder`

- Title: `Cave Wonder`
- Author: tapatilorenzo
- Source: <https://opengameart.org/content/2-midi-cave-songs-cave-wonder-tinkering-cave>
- Original file: `9_cave_wonder.mp3`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged source file:
  `20223315c82ee5cf47736366ff0aabcdaf0a09110c8b25250430ac08ea5b89fe`
- Changes: renamed to `cave-wonder.mp3`; audio data otherwise unchanged.
- Settings ID: `music.cave.wonder` (cave default)

Attribution is not required by CC0. The author and source are listed voluntarily.

## `audio.music.cave.tinkering`

- Title: `Tinkering Cave`
- Author: tapatilorenzo
- Source: <https://opengameart.org/content/2-midi-cave-songs-cave-wonder-tinkering-cave>
- Original file: `10_tinkering_cave.mp3`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged source file:
  `c69d063a35128ab22503c541b7877814aab847a71145cad8e47c63ae3f6296c1`
- Changes: renamed to `cave-tinkering.mp3`; audio data otherwise unchanged.
- Settings ID: `music.cave.tinkering`

Attribution is not required by CC0. The author and source are listed voluntarily.

## Shared cue vocabulary (`AudioCue`)

Gameplay effects use shared cue IDs. Themes map each cue to a WAV under
`Audio/Effects/shared/`, `Audio/Effects/sokoban/`, or `Audio/Effects/boulderDash/`
(or `null` for procedural fallback).

| Cue | Typical use |
| --- | --- |
| `movementStep` | Player step |
| `movementBlocked` | Blocked move |
| `objectPushed` | Crate / boulder push |
| `objectLanded` | Falling object lands |
| `collectiblePickedUp` | Goal enter / diamond |
| `objectiveCompleted` | Level complete jingle |
| `exitOpened` | Cave exit opens |
| `playerDied` | Cave death |
| `timeExpired` | Cave time out |
| `goalLeft` | Sokoban crate leaves goal |

## `audio.effect.sokoban.movementStep` / `cratePushed`

- Pack: 51 UI sound effects (buttons, switches and clicks)
- Author: Kenney Vleugels (Kenney.nl)
- Source: <https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks>
- Original archive: `UI_SFX_Set.zip`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged archive:
  `66026b9e39859b85964dbb3ee7a2d1fc46a6a406bb3e97c8b0defee0e25fb369`
- Extracted files (audio data unchanged; renamed for the bundle):
  - `click2.wav` → `Audio/Effects/sokoban/movementStep.wav`
  - `switch12.wav` → `Audio/Effects/sokoban/cratePushed.wav`

Attribution is not required by CC0. Kenney.nl is listed voluntarily.

## `audio.effect.sokoban.crateOnGoal` / `goalLeft`

- Pack: UI Sound Effects (Button Clicks, User Feedback, Notifications)
- Author: Robin Lamb
- Source: <https://opengameart.org/content/ui-sound-effects-button-clicks-user-feedback-notifications>
- Original archive: `ui_wav.zip`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged archive:
  `8e4e23dd4ec501776dab1428c5f1e405b5065e296518feb04816f2892d163053`
- Extracted files (audio data processed to mono 44.1 kHz/16‑bit, Peak ≈ −3 dBFS):
  - `ui_wav/Ding.wav` → `Audio/Effects/sokoban/crateOnGoal.wav`
    (leicht tiefer, Lowpass, weicherer Fade — bestätigender)
  - `ui_wav/dum.wav` → `Audio/Effects/sokoban/goalLeft.wav`

Attribution is not required by CC0. The author and source are listed voluntarily.

## `audio.effect.shared.levelCompleted`

- Title: Win sound effect
- Author: Listener
- Source: <https://opengameart.org/content/win-sound-effect>
- Original file: `Win sound.wav`
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged source file:
  `e4bb5377bf9490ca9bc5bc4d3d957f1ec74b930450d8ad578d15fe1c4f319caf`
- Changes: moved to shared path for Sokoban + Cave `objectiveCompleted` →
  `Audio/Effects/shared/levelCompleted.wav`

Attribution is not required by CC0. The author and source are listed voluntarily.

## `audio.effect.shared.movementStep`

- Pack: Different steps on wood, stone, leaves, gravel and mud
- Author: TinyWorlds
- Source: <https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud>
- Original archive: `[kdd]DifferentSteps.zip` (SHA-256
  `987d072b7deaa65177e005ddd8185f2351be7c9a76cd7575dea560549c39b33b`)
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- Changes: `gravel.ogg` → WAV, trimmed to ~70 ms → `Audio/Effects/shared/movementStep.wav`

## `audio.effect.shared.movementBlocked`

- Title: Menu Selection Click
- Author: NenadSimic
- Source: <https://opengameart.org/content/menu-selection-click>
- Original file: `Menu Selection Click.wav` (SHA-256
  `aa10d400e97a59aa8fc1f8bc88b24c7d888ede9bd9e457b340ad659a045b440a`)
- License: **CC-BY 3.0**
- Local license: `MacGameApp/Resources/Audio/Licenses/CC-BY-3.0.txt`
- Downloaded: 2026-08-03
- Changes: pitched down (~0.85×), trimmed to ~80 ms, mono →
  `Audio/Effects/shared/movementBlocked.wav`
- Attribution (required): NenadSimic,
  https://opengameart.org/content/menu-selection-click

## `audio.effect.shared.objectPushed` / `boulderDash.boulderPushed`

- Title: Push Stone Boulder (Yo Frankie!)
- Author: Blender Foundation (submitted by Lamoot)
- Source: <https://opengameart.org/content/push-stone-boulder-yo-frankie>
- Original file: `sfx_push_boulder.flac` (SHA-256
  `a16e64c90ce0faeaefe6d7e4afa647489f92202f6de8863597eadf512a168173`)
- License: **CC-BY 3.0**
- Local license: `MacGameApp/Resources/Audio/Licenses/CC-BY-3.0.txt`
- Downloaded: 2026-08-03
- Changes: FLAC → WAV mono 44.1 kHz/16‑bit; Peak ≈ −3 dBFS; getrimmt.
  - Fels (`shared/objectPushed.wav`, `boulderDash/boulderPushed.wav`):
    Pitch ≈ 0.78×, Soft-Sat, Lowpass — tiefer/rauer.
  - Kiste (`sokoban/cratePushed.wav`): Pitch ≈ 1.15×, Highpass — trockener/holziger.
- Attribution (required): © Blender Foundation | apricot.blender.org

## `audio.effect.shared.collectiblePickedUp` / `boulderDash.diamondCollected`

- Pack: 10 8bit coin sounds
- Author: Luke.RUSTLTD
- Source: <https://opengameart.org/content/10-8bit-coin-sounds>
- Original archive: `coin_sounds.zip` (SHA-256
  `11be4d249389fa61523702140b205046bd13774c8a37e84f156fb44421129921`)
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- Changes: `coin7.wav` → mono 44.1 kHz/16‑bit, Peak ≈ −3 dBFS; Pitch ≈ 1.22× + Highpass
  (heller/gläserner) → `shared/collectiblePickedUp.wav` /
  `boulderDash/diamondCollected.wav`

## `audio.effect.shared.playerDied`

- Title: retro dead/destroyed/damaged sound
- Author: Prinsu-Kun
- Source: <https://opengameart.org/content/retro-deaddestroyeddamaged-sound>
- Original file: `dead.wav` (SHA-256
  `2434e8a8e5c2ead6de0bb22ecc57c072ff15ab3508d8bbb9aa4e892cfaac17a3`)
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- Changes: trimmed to ~850 ms → `Audio/Effects/shared/playerDied.wav`

## `audio.effect.shared.objectLanded` / `exitOpened` / `timeExpired`

- Pack: 512 Sound Effects (8-bit style)
- Author: Juhani Junkala
- Source: <https://opengameart.org/content/512-sound-effects-8-bit-style>
- Original archive:
  `The Essential Retro Video Game Sound Effects Collection [512 sounds].zip`
  (SHA-256 `6d4519229c6e2c9e09502cd4967940052f68664140549a467615b56bdfd1d031`)
- License: CC0 1.0 Universal / Public Domain
- Local license: `MacGameApp/Resources/Audio/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- Extracted / trimmed:
  - `sfx_sounds_impact1.wav` → `Audio/Effects/shared/objectLanded.wav`
  - `sfx_sounds_powerup1.wav` → `Audio/Effects/shared/exitOpened.wav`
  - `sfx_sounds_negative1.wav` → `Audio/Effects/shared/timeExpired.wav`

Attribution is not required by CC0. The author and source are listed voluntarily.

## `audio.jingle.sokoban.levelCompleted` (legacy note)

Previously lived under `Audio/Jingles/sokoban-level-completed.wav`, then
`Audio/Effects/sokoban/levelCompleted.wav`. Now
`Audio/Effects/shared/levelCompleted.wav` (same Listener CC0 asset as above).

## `theme.dungeon` board textures (mixed pack)

### Floor — Seamless Cobblestone (HellGate)

- Source: <https://opengameart.org/content/seamless-cobblestone-texture>
- Original archive: `cobblestone.zip`
- License: CC0 1.0
- Local license: `MacGameApp/Resources/Textures/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged archive:
  `2f28bf1016e94338e05d5f85d5e40703bc620e02f1059cb7fa43d7ecbf73619f`
- Changes: cropped/scaled `diffuse.png` to `Textures/dungeon/floor.png` (64×64).

### Wall — Stone texture (phaelax)

- Source: <https://opengameart.org/content/stone-texture-bump>
- Original preview file used: `stone2.jpg` (512×512 diffuse)
- License: **CC-BY-SA 3.0**
- Local license: `MacGameApp/Resources/Textures/Licenses/CC-BY-SA-3.0.txt`
- Downloaded: 2026-08-03
-   SHA-256 of `stone2.jpg`:
  `318794ff636cf7070a2024609599aa16d80abf46fb22dd0857e3f17a717acd55`
- Changes: cropped/scaled + slight darken → `Textures/dungeon/wall.png` (64×64).
- Attribution: phaelax / OpenGameArt. ShareAlike applies to this derived wall tile.

### Player (renegreg)

- Source: <https://opengameart.org/content/player>
- Original file: `Player.psd`
- License: **CC-BY 3.0** (chosen from the offered multi-license)
- Local license: `MacGameApp/Resources/Textures/Licenses/CC-BY-3.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged PSD:
  `097aeb328bfa41e3bb6b73c39fbb2a3b7fa575c819a9c3225cf01031ce980fbd`
- Changes: rasterized, fitted to 64×64 with transparency → `Textures/dungeon/player.png`.
- Attribution: renegreg.

### Crate — [2D] Wooden Box (Cpt_Flash)

- Source: <https://opengameart.org/content/2d-wooden-box>
- Original file: `RTS_Crate.png`
- License: CC0 1.0
- Local license: `MacGameApp/Resources/Textures/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256:
  `f7e9954c728f1677f4ba3073cb8e6609e3a2f51bf4ec30946f43b6f0307fcef0`
- Changes: fitted to 64×64 → `Textures/dungeon/crate.png`; also composited onto goal
  for `crate-on-goal.png`.

### Goal marker — glow circle (oglsdl)

- Source: <https://opengameart.org/content/glow-circle>
- Original file: `glowCircle.png`
- License: CC0 1.0
- Local license: `MacGameApp/Resources/Textures/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256:
  `3d8869a5c7ae379745a0822d61a83da7790cecdd9d64103e13caf15a7b05eb20`
- Changes: fitted, recolored cyan, alpha reduced, composited onto floor →
  `Textures/dungeon/goal.png`.

Display scale: continuous fit (same as vector) with `.nearest` texture filtering.

## `theme.kenney` board textures

- Pack: Sokoban (100+ tiles)
- Author: Kenney Vleugels (Kenney.nl)
- Source: <https://opengameart.org/content/sokoban-100-tiles>
- Original archive: `kenney_sokobanPack.zip`
- License: CC0 1.0
- Local license: `MacGameApp/Resources/Textures/Licenses/CC0-1.0.txt`
- Downloaded: 2026-08-03
- SHA-256 of the unchanged archive:
  `d8cc8af649a5e21d87a9f30a8a616fe2c0e94e68c80cdfe0df8ca72ec0f208ac`
- Extracted (Default size 64×64, renamed into `Textures/kenney/`):
  - `Ground/ground_06.png` → `floor.png`
  - `Blocks/block_06.png` → `wall.png`
  - `Crates/crate_02.png` → `crate.png`
  - `Crates/crate_05.png` → `crate-on-goal.png`
  - `Player/player_05.png` → `player.png`
  - Goal: `Environment/environment_05.png` composited onto ground → `goal.png`

Attribution is not required by CC0. Kenney.nl is listed voluntarily.

## Sokoban campaign levels (`sokoban.campaign.001`–`090`)

- Pack: Still Yet Another Sokoban (default 90)
- Source note in import file: Public Domain
- Local import: `Downloads/sokoban_levels_001-090.txt` (2026-08-03)
- Changes: German titles kept; levels ordered by annotated difficulty
  (`schwer`), then crate count / map size; renumbered to
  `sokoban.campaign.001`…`090` after the three tutorials.
