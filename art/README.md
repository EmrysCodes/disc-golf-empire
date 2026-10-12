# Art layout — Disc Golf Empire (2.5D overhaul)

## Projection

- Gameplay stays in property-local 2D; presentation converts via `property_local_to_world`.
- **Screen-up (−Y) = altitude** (disc arc, tree crown lift).
- **Depth sort key** = world `y` (lower on screen draws in front) via `y_sort_enabled` on `ActorVisualLayer`.
- Not a Camera2D isometric transform — sprites + shadows carry the lean.

## Folders

| Path | Role |
|------|------|
| `art/golfers/kenney_toon/` | Kenney Toon HD poses (4 variants) → SpriteFrames |
| `art/discs/` | Custom disc spin / lie PNGs |
| `art/trees/kenney_foliage/` | Mobile-sized foliage crowns for trees |
| `art/terrain/kenney_tiny_town/` | Optional path / grass tile cues |
| `art/licenses/` | Upstream license text copies |
| `art/ATTRIBUTION.md` | Sources + license summary |
| `visuals/` | Runtime Sprite2D / AnimatedSprite2D pipeline + pools |

`visuals/sprite_kit.gd` loads PNG assets when present and falls back to procedural frames otherwise.
