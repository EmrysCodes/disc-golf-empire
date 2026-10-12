# Art attribution — Disc Golf Empire

Third-party assets vendored under `art/`. Prefer CC0 / public-domain packs so commercial use does not require per-screen credits; attribution is still recorded here and under `art/licenses/`.

## Active player-facing golfers

| | |
|--|--|
| **Source** | Procedural `ImageTexture` frames in `visuals/sprite_kit.gd` |
| **License** | Same as the game repository |
| **Use** | Default AnimatedSprite2D idle / walk / prepare / run-up / throw / putt |

Kenney Toon Characters were **tried and rejected** for player-facing golfers (too chibi). They are **not** shipped. A more realistic free pack remains a follow-up; until then procedural is the default (`USE_ASSET_GOLFERS := false`).

## Kenney — Foliage Sprites (trees)

| | |
|--|--|
| **Source** | [kenney.nl](https://kenney.nl) — Foliage Sprites |
| **License** | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| **Installed** | `art/trees/kenney_foliage/` (cropped + resized; greyscale tinted green at draw) |
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

## Candidates evaluated (not shipped as golfers)

| Pack | License | Why not used |
|------|---------|--------------|
| Kenney Toon Characters Pack 1 | CC0 | Rejected — too chibi / cartoon for desired look |
| LPC Character Bases (OGA) | Mixed CC-BY / CC-BY-SA | Headless bases; attribution stack; not wired this pass |
| Tiny Questers Warrior (itch) | Free commercial (credit optional) | Itch direct download blocked in env; follow-up |
| Battle Heroes 40 (itch) | CC0 | Itch direct download blocked; side-view RPG style TBD |
| Kenney Top-down Survivor | typically CC0/CC-BY | Strict top-down shooter layers; wrong camera language for current 2.5D |

## Notes

- Kenney CC0 allows personal, educational, and **commercial** use; crediting Kenney / kenney.nl is appreciated but **not mandatory**.
- Simulation schemas (`tree_records`, Update 43) are unchanged; art is presentation-only.
