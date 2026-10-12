# Art attribution — Disc Golf Empire

Third-party assets vendored under `art/`. Prefer CC0 / public-domain packs so commercial use does not require per-screen credits; attribution is still recorded here and under `art/licenses/`.

## Kenney — Toon Characters Pack 1 (golfers)

| | |
|--|--|
| **Source** | [kenney.nl](https://kenney.nl) — Toon Characters Pack 1 |
| **License** | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| **Installed** | `art/golfers/kenney_toon/{male_person,female_person,male_adventurer,female_adventurer}/` (HD pose subset) |
| **License file** | `art/licenses/kenney_toonCharacters1_License.txt` |
| **Use** | Golfer idle / walk / prepare / run-up / throw / putt via `visuals/sprite_kit.gd` SpriteFrames |

No perfect “disc golfer” pack was available; civilian **person** and **adventurer** poses are composed into throw/putt animations (attack / hold / duck / interact / run / walk).

## Kenney — Foliage Sprites (trees)

| | |
|--|--|
| **Source** | [kenney.nl](https://kenney.nl) — Foliage Sprites |
| **License** | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| **Installed** | `art/trees/kenney_foliage/` (cropped + resized for mobile) |
| **License file** | `art/licenses/kenney_foliageSprites_License.txt` |
| **Use** | Property / world tree crowns in `course_renderer.gd` |

## Kenney — Tiny Town (terrain cues)

| | |
|--|--|
| **Source** | [kenney.nl](https://kenney.nl) — Tiny Town |
| **License** | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| **Installed** | `art/terrain/kenney_tiny_town/` (selected grass / path tiles) |
| **License file** | `art/licenses/kenney_tinyTown_License.txt` |
| **Use** | Reserved for fairway / path accents; not required for sim |

## Original project art (discs / basket accent)

| | |
|--|--|
| **Source** | Generated for this project |
| **License** | Same as the game repository |
| **Installed** | `art/discs/disc_spin_*.png`, `disc_lie.png`, `basket_accent.png` |
| **Use** | Disc flight / lie frames in `visuals/sprite_kit.gd` |

## Notes

- Kenney CC0 allows personal, educational, and **commercial** use; crediting Kenney / kenney.nl is appreciated but **not mandatory**.
- Survivor / other CC-BY packs were evaluated and **not** vendored to avoid attribution overhead.
- Simulation schemas (`tree_records`, Update 43) are unchanged; art is presentation-only.
