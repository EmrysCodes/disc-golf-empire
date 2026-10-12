# Art attribution — Disc Golf Empire

Third-party assets vendored under `art/`. Prefer CC0 / public-domain packs so commercial use does not require per-screen credits; attribution is still recorded here and under `art/licenses/`.

## Active player-facing golfers

| | |
|--|--|
| **Source** | Original pipeline sheets — `tools/gen_golfer_sprites.py` (celestial-clash–style volumetric 2.5D plates) |
| **License** | Same as the game repository |
| **Installed** | `art/golfers/variant_*_sheet.png` (+ idle masters / preview montage) |
| **Use** | Default AnimatedSprite2D idle / walk / prepare / run-up / throw / putt via `visuals/sprite_kit.gd` (`USE_ASSET_GOLFERS := true`) |
| **Regenerate** | `python3 tools/gen_golfer_sprites.py` |

Kenney Toon Characters were **tried and rejected** for player-facing golfers (too chibi). They are **not** shipped. Sheets hold a flat disc (not a side-view prop); ground shadow is runtime-only. Procedural `ImageTexture` strips in `sprite_kit.gd` remain as fallback if sheets are missing or `USE_ASSET_GOLFERS` is flipped off.

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

## Pipeline notes

- Golfer sheets mirror [celestial-clash](https://github.com/EmrysCodes/celestial-clash) `tools/gen_iso_characters.py`: shaded ellipsoids, limbs, outfit plates, per-anim rows packed into PNG sheets.
- Sheet cells are **80×96**; rows = idle, walk, prepare, run_up, throw, putt.
- Simulation schemas (`tree_records`, Update 43) are unchanged; art is presentation-only.

## Notes

- Kenney CC0 allows personal, educational, and **commercial** use; crediting Kenney / kenney.nl is appreciated but **not mandatory**.
