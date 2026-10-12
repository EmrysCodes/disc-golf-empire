# Art layout — Disc Golf Empire (2.5D overhaul)

## Projection

- Gameplay stays in property-local 2D; presentation converts via `property_local_to_world`.
- **Screen-up (−Y) = altitude** (disc arc, tree crown lift).
- **Depth sort key** = world `y` (lower on screen draws in front) via `y_sort_enabled` on `ActorVisualLayer`.
- Not a Camera2D isometric transform — sprites + shadows carry the lean.

## Folders

| Path | Role |
|------|------|
| `art/golfers/` | Reserved for authored golfer sheets (idle/walk/throw/putt). |
| `art/discs/` | Reserved for disc / trail accents. |
| `visuals/` | Runtime Sprite2D / AnimatedSprite2D pipeline + pools. |

First vertical uses **procedural `SpriteKit`** (`visuals/sprite_kit.gd`) to build `ImageTexture` frames at runtime so the AnimatedSprite2D path works without binary sheets. Drop PNG atlases here later and point `SpriteKit` at them.
