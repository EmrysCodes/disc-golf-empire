#!/usr/bin/env python3
"""
Disc Golf Empire — isometric 2.5D golfer sprite sheets.

Modeled on celestial-clash `tools/gen_iso_characters.py`:
hand-authored volumetric plates (shaded ellipsoids + limbs), packed into
per-variant animation sheets for Godot AnimatedSprite2D.

Sheet layout (80×96 cells, 8 columns × 6 rows):
  row 0 idle     (6 frames used)
  row 1 walk     (8)
  row 2 prepare  (4)
  row 3 run_up   (6)
  row 4 throw    (6)
  row 5 putt     (5)

Usage:
  python3 tools/gen_golfer_sprites.py
"""
from __future__ import annotations

import math
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "golfers"
PREVIEW = ROOT / "art" / "golfers" / "_preview_montage.png"

FW, FH = 80, 96
COLS = 8
ANIM_ROWS = (
    ("idle", 6),
    ("walk", 8),
    ("prepare", 4),
    ("run_up", 6),
    ("throw", 6),
    ("putt", 5),
)

VARIANTS = [
    {
        "id": 0,
        "shirt": (46, 152, 154),
        "shorts": (198, 170, 112),
        "shoes": (38, 40, 44),
        "skin": (234, 190, 152),
        "hair": (52, 34, 24),
        "cap": (30, 112, 114),
        "accent": (255, 212, 72),
    },
    {
        "id": 1,
        "shirt": (218, 88, 76),
        "shorts": (44, 60, 96),
        "shoes": (30, 32, 38),
        "skin": (198, 144, 110),
        "hair": (30, 22, 18),
        "cap": (38, 50, 82),
        "accent": (242, 222, 82),
    },
    {
        "id": 2,
        "shirt": (60, 122, 74),
        "shorts": (92, 98, 104),
        "shoes": (50, 42, 34),
        "skin": (246, 212, 178),
        "hair": (96, 58, 30),
        "cap": (50, 100, 60),
        "accent": (255, 204, 64),
    },
    {
        "id": 3,
        "shirt": (212, 168, 50),
        "shorts": (80, 100, 60),
        "shoes": (42, 38, 32),
        "skin": (172, 120, 90),
        "hair": (20, 16, 14),
        "cap": (50, 50, 44),
        "accent": (255, 232, 92),
    },
]


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def C(rgb, f: float = 1.0, a: int = 255):
    return tuple(max(0, min(255, int(c * f))) for c in rgb[:3]) + (a,)


def composite(base: Image.Image, layer: Image.Image) -> Image.Image:
    return Image.alpha_composite(base, layer)


def soft(img: Image.Image, box, fill, blur: float = 1.0) -> Image.Image:
    layer = blank(*img.size)
    ImageDraw.Draw(layer).ellipse(box, fill=fill)
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return composite(img, layer)


def oval(img: Image.Image, cx, cy, rx, ry, color, hi: float = 1.15, lo: float = 0.55) -> Image.Image:
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=C(color, lo))
    d.ellipse(
        [cx - rx * 0.88, cy - ry * 0.88, cx + rx * 0.72, cy + ry * 0.72],
        fill=C(color, 0.88),
    )
    d.ellipse(
        [
            cx - rx * 0.55 - rx * 0.18,
            cy - ry * 0.55 - ry * 0.22,
            cx + rx * 0.28,
            cy + ry * 0.12,
        ],
        fill=C(color, hi, 200),
    )
    d.arc(
        [cx - rx, cy - ry, cx + rx, cy + ry],
        210,
        330,
        fill=C(color, hi + 0.1, 130),
        width=2,
    )
    return composite(img, layer)


def poly(img: Image.Image, pts, color) -> Image.Image:
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=C(color, 1.0))
    if len(pts) >= 3:
        d.line([pts[0], pts[1]], fill=C(color, 1.2, 180), width=2)
    return composite(img, layer)


def limb(img: Image.Image, x0, y0, x1, y1, r, color, joint: float = 0.55) -> Image.Image:
    """Tapered limb with soft ends — less 'stick joint' than raw circles."""
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.line([(x0, y0), (x1, y1)], fill=C(color, 0.58), width=int(r * 2.35))
    d.line([(x0, y0), (x1, y1)], fill=C(color, 0.95), width=max(2, int(r * 1.45)))
    # soft highlight stroke
    mx, my = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    d.line(
        [(x0 * 0.7 + mx * 0.3, y0 * 0.7 + my * 0.3), (x1 * 0.7 + mx * 0.3, y1 * 0.7 + my * 0.3)],
        fill=C(color, 1.18, 120),
        width=max(1, int(r * 0.55)),
    )
    jr = r * joint
    for x, y in ((x0, y0), (x1, y1)):
        d.ellipse([x - jr, y - jr, x + jr, y + jr], fill=C(color, 0.92))
        d.ellipse(
            [x - jr * 0.4, y - jr * 0.5, x + jr * 0.15, y + jr * 0.1],
            fill=C(color, 1.15, 110),
        )
    return composite(img, layer)


def plate(img: Image.Image, pts, color) -> Image.Image:
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=C(color, 0.78))
    if len(pts) >= 3:
        d.line([pts[0], pts[1]], fill=C(color, 1.22, 200), width=2)
        d.line([pts[0], pts[-1]], fill=C(color, 1.08, 140), width=1)
    d.polygon(pts, outline=C(color, 0.4, 180))
    return composite(img, layer)


def silhouette_outline(img: Image.Image, color=(18, 16, 14, 160)) -> Image.Image:
    """Dark fringe around opaque pixels for readable course contrast."""
    alpha = img.split()[-1]
    dilated = alpha.filter(ImageFilter.MaxFilter(3))
    fringe = ImageChops_subtract(dilated, alpha)
    outline = blank(*img.size)
    outline.paste(color, mask=fringe)
    return composite(outline, img)


def ImageChops_subtract(a: Image.Image, b: Image.Image) -> Image.Image:
    from PIL import ImageChops

    return ImageChops.subtract(a, b)


def shadow(img: Image.Image, cx, cy, rx=16, ry=5.5) -> Image.Image:
    return soft(img, [cx - rx, cy - ry, cx + rx, cy + ry], (0, 0, 0, 100), 1.8)


def face(img: Image.Image, cx, cy, skin, eye=(38, 44, 58)) -> Image.Image:
    img = oval(img, cx, cy, 7.6, 8.2, skin, hi=1.2, lo=0.58)
    d = ImageDraw.Draw(img)
    d.arc([cx - 6, cy - 4, cx - 1, cy + 1], 200, 340, fill=C(skin, 0.55, 180), width=1)
    d.arc([cx + 1, cy - 4, cx + 6, cy + 1], 200, 340, fill=C(skin, 0.55, 180), width=1)
    d.ellipse([cx - 3.6, cy - 1.4, cx - 0.8, cy + 1.1], fill=(250, 250, 255, 235))
    d.ellipse([cx + 1.0, cy - 1.4, cx + 3.8, cy + 1.1], fill=(250, 250, 255, 235))
    d.ellipse([cx - 2.9, cy - 0.7, cx - 1.4, cy + 0.5], fill=eye + (255,))
    d.ellipse([cx + 1.7, cy - 0.7, cx + 3.2, cy + 0.5], fill=eye + (255,))
    d.ellipse([cx - 5, cy + 1.5, cx - 2.5, cy + 3.5], fill=C(skin, 0.85, 60))
    d.ellipse([cx + 2.5, cy + 1.5, cx + 5, cy + 3.5], fill=C(skin, 0.85, 60))
    return img


def disc(img: Image.Image, cx, cy, accent, squash: float = 1.0, tilt: float = 0.0) -> Image.Image:
    """Flat disc golf disc (top-down oval) — never a vertical 'gun' prop."""
    rx = 7.0 * squash
    ry = 2.35 / max(0.75, squash * 0.85)
    # slight perspective tilt just shifts vertical squash
    ry *= 1.0 + abs(tilt) * 0.08
    img = oval(img, cx + 0.4, cy + 0.55, rx + 0.35, ry + 0.28, (22, 18, 10), hi=0.7, lo=0.38)
    img = oval(img, cx, cy, rx, ry, accent, hi=1.28, lo=0.68)
    img = oval(img, cx - 1.1, cy - 0.45, 2.8, 0.95, C(accent, 1.35)[:3], hi=1.2, lo=0.9)
    layer = blank(*img.size)
    ImageDraw.Draw(layer).arc(
        [cx - rx, cy - ry, cx + rx, cy + ry],
        15,
        200,
        fill=C(accent, 0.5, 150),
        width=1,
    )
    return composite(img, layer)


def pose_params(anim: str, frame: int, count: int):
    t = float(frame) / float(max(count - 1, 1))
    bob = lean = arm = stride = crouch = 0.0
    hold_disc = True
    release = 0.0
    if anim == "idle":
        phase = frame / float(count) * math.tau
        bob = math.sin(phase) * 1.1
        arm = math.sin(phase) * 1.4
        stride = math.sin(phase) * 0.8
    elif anim == "walk":
        phase = frame / float(count) * math.tau
        bob = abs(math.sin(phase)) * 2.2
        arm = math.sin(phase) * 6.5
        lean = math.sin(phase) * 1.0
        stride = math.sin(phase) * 7.0
    elif anim == "prepare":
        bob = math.sin(t * math.tau) * 0.4
        lean = -1.5 - t * 1.8
        arm = -2.0 - t * 5.0
        crouch = 1.6 + t * 1.0
        stride = -1.2
    elif anim == "run_up":
        phase = t * math.tau * 1.25
        bob = abs(math.sin(phase)) * 2.4
        lean = -3.5 + t * 6.5
        arm = -6.0 + t * 10.0
        stride = math.sin(phase) * 7.5
        hold_disc = t < 0.9
        release = max(0.0, (t - 0.78) / 0.22)
    elif anim == "throw":
        lean = -2.5 + t * 9.0
        arm = -8.0 + t * 20.0
        bob = -t * 1.8
        stride = -2.0 + t * 6.0
        hold_disc = t < 0.62
        release = max(0.0, (t - 0.45) / 0.55)
        crouch = max(0.0, 1.2 - t * 1.4)
    elif anim == "putt":
        lean = -0.8 + t * 3.2
        arm = -2.0 + t * 8.0
        bob = -0.6
        crouch = 2.4 - t * 1.4
        hold_disc = t < 0.48
        release = max(0.0, (t - 0.35) / 0.65)
        stride = -0.6 + t * 1.6
    return bob, lean, arm, stride, crouch, hold_disc, release


def draw_golfer(v: dict, anim: str, frame: int, count: int) -> Image.Image:
    """Adult 2.5D golfer facing camera-right. Shadow is runtime-only (not baked)."""
    img = blank(FW, FH)
    cx = FW // 2
    foot = int(FH * 0.90)
    bob, lean, arm, stride, crouch, hold_disc, release = pose_params(anim, frame, count)
    t = float(frame) / float(max(count - 1, 1))
    # Hip / torso anchor — longer legs, smaller head than v1 sheets.
    cy = foot - 6 + bob + crouch
    bx = cx + lean * 0.85

    shirt = v["shirt"]
    shorts = v["shorts"]
    shoes = v["shoes"]
    skin = v["skin"]
    hair = v["hair"]
    cap = v["cap"]
    accent = v["accent"]

    # Legs (longer stride path)
    lx0, ly0 = bx - 4.5, cy + 2
    rx0, ry0 = bx + 4.5, cy + 2
    lx1 = bx - 8 + stride * 0.55
    rx1 = bx + 9 - stride * 0.55
    ly1 = foot - 1
    ry1 = foot - 1
    img = limb(img, lx0, ly0, lx1, ly1, 3.8, C(shorts, 0.82)[:3], joint=0.4)
    img = limb(img, rx0, ry0, rx1, ry1, 3.8, shorts, joint=0.4)
    img = oval(img, lx1, ly1 + 1.5, 5.6, 2.8, shoes, hi=1.05, lo=0.48)
    img = oval(img, rx1, ry1 + 1.5, 5.6, 2.8, shoes, hi=1.05, lo=0.48)

    # Hips — soft oval, not a boxy “bag” plate over the legs
    img = oval(img, bx, cy + 3, 9.5, 7.0, shorts, hi=1.08, lo=0.55)
    img = oval(img, bx, cy + 1, 7.5, 5.0, C(shorts, 1.1)[:3], hi=1.1, lo=0.85)

    # Torso
    img = oval(img, bx, cy - 16, 11.0, 14.5, shirt, hi=1.14, lo=0.52)
    img = oval(img, bx - 10, cy - 14, 4.0, 4.8, C(shirt, 0.9)[:3], hi=1.05, lo=0.55)
    img = oval(img, bx + 10, cy - 15, 4.0, 4.8, C(shirt, 1.0)[:3], hi=1.1, lo=0.55)
    img = plate(
        img,
        [
            (bx - 5, cy - 28),
            (bx + 5, cy - 29),
            (bx + 3.5, cy - 19),
            (bx - 3.5, cy - 18),
        ],
        C(shirt, 1.16)[:3],
    )
    img = oval(img, bx - 2, cy - 18, 3.6, 5.2, C(shirt, 1.2)[:3], hi=1.08, lo=0.92)

    # Trailing (non-throw) arm — hangs / counter-swings, never holds the disc
    back_ax = bx - 10 - arm * 0.08
    back_ay = cy - 14
    back_hx = bx - 13 - arm * 0.2
    back_hy = cy + 2 + abs(arm) * 0.05
    img = limb(img, back_ax, back_ay, back_hx, back_hy, 3.4, skin, joint=0.38)

    # Head — slightly smaller; cap brim toward camera (forward), not sideways gun-sight
    hx, hy = bx + 0.5, cy - 34
    img = oval(img, hx - 0.4, hy - 1.5, 8.2, 5.5, hair, hi=1.05, lo=0.48)
    img = face(img, hx, hy + 1.2, skin)
    img = oval(img, hx, hy - 1.5, 7.8, 4.8, C(cap, 0.95)[:3], hi=1.05, lo=0.6)
    img = oval(img, hx, hy - 4.0, 7.2, 3.0, C(cap, 1.08)[:3], hi=1.18, lo=0.62)
    # Forward brim (toward viewer / down-screen) reads as a 2.5D cap, not a side-view visor
    img = poly(
        img,
        [
            (hx - 6, hy + 0.5),
            (hx + 6, hy - 0.2),
            (hx + 7, hy + 3.5),
            (hx - 7, hy + 4.0),
        ],
        C(cap, 0.78)[:3],
    )
    img = oval(img, hx, hy - 5.8, 1.4, 1.1, C(cap, 1.25)[:3], hi=1.1, lo=0.9)

    # Throwing arm + disc placement by stage (backhand language)
    throw_sx = bx + 9
    throw_sy = cy - 15
    disc_x = bx + 8
    disc_y = cy - 8
    throw_ex, throw_ey = disc_x, disc_y

    if anim in ("idle", "walk"):
        # Disc cradled at hip/waist — flat oval, elbow soft
        throw_ex = bx + 9 + arm * 0.08
        throw_ey = cy - 6 + abs(arm) * 0.04
        disc_x, disc_y = throw_ex + 1.5, throw_ey + 1.0
    elif anim == "prepare":
        # Reach-back across body (backhand)
        throw_ex = bx - 2 - t * 6
        throw_ey = cy - 8 - t * 2
        disc_x, disc_y = throw_ex - 1, throw_ey + 0.5
    elif anim == "run_up":
        throw_ex = bx + 2 + arm * 0.25
        throw_ey = cy - 10 - arm * 0.08
        if release > 0.1:
            throw_ex = bx + 10 + release * 12
            throw_ey = cy - 14 - release * 6
        disc_x, disc_y = throw_ex + 2, throw_ey
    elif anim == "throw":
        # Pull-through: reach-back → whip forward; disc leaves mid-sequence
        if t < 0.35:
            throw_ex = bx - 4 - (0.35 - t) * 8
            throw_ey = cy - 9
        else:
            throw_ex = bx + 6 + (t - 0.35) * 22
            throw_ey = cy - 12 - (t - 0.35) * 8
        disc_x, disc_y = throw_ex + 2.5, throw_ey
    elif anim == "putt":
        throw_ex = bx + 6 + arm * 0.2
        throw_ey = cy - 5 - arm * 0.1 + crouch * 0.15
        disc_x, disc_y = throw_ex + 1.5, throw_ey + 0.5

    img = limb(img, throw_sx, throw_sy, throw_ex, throw_ey, 3.5, skin, joint=0.38)

    if hold_disc:
        img = disc(img, disc_x, disc_y, accent, squash=1.05, tilt=lean * 0.02)
    elif release > 0.25 and anim in ("throw", "run_up", "putt"):
        # Soft release glint near the empty hand — not a second prop
        img = soft(
            img,
            [throw_ex - 4, throw_ey - 6, throw_ex + 10, throw_ey + 4],
            (*accent[:3], int(55 + release * 40)),
            2.0,
        )

    img = silhouette_outline(img)
    return img


def make_import_sidecar(png_path: Path) -> None:
    rel = "res://" + str(png_path.relative_to(ROOT)).replace("\\", "/")
    digest = uuid.uuid5(uuid.NAMESPACE_URL, rel).hex
    uid = "uid://" + digest[:13]
    dest = f"res://.godot/imported/{png_path.name}-{digest[:32]}.ctex"
    text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{rel}"
dest_files=["{dest}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    png_path.with_suffix(".png.import").write_text(text)


def sheet_variant(v: dict) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = len(ANIM_ROWS)
    sheet = blank(FW * COLS, FH * rows)
    for row, (anim, count) in enumerate(ANIM_ROWS):
        for col in range(count):
            fr = draw_golfer(v, anim, col, count)
            fr = ImageEnhance.Sharpness(fr).enhance(1.1)
            sheet.paste(fr, (col * FW, row * FH), fr)
    out = OUT / f"variant_{v['id']}_sheet.png"
    sheet.save(out)
    make_import_sidecar(out)
    idle = draw_golfer(v, "idle", 0, 6)
    idle = ImageEnhance.Sharpness(idle).enhance(1.12)
    master = OUT / f"variant_{v['id']}_idle.png"
    idle.save(master)
    make_import_sidecar(master)
    print(f"  variant {v['id']} → {out.name} ({sheet.size[0]}×{sheet.size[1]})")
    return out


def montage(paths: list[Path]) -> None:
    """Idle + mid-throw contact sheet (no baked shadows on cells)."""
    cell_w, cell_h = FW * 2 + 12, FH + 12
    m = Image.new("RGBA", (cell_w * 2, cell_h * 2), (34, 52, 40, 255))
    for i, p in enumerate(paths):
        sheet = Image.open(p).convert("RGBA")
        idle = sheet.crop((0, 0, FW, FH))
        # Mid throw (frame 2) still holds the disc flat at the hip/hand.
        throw = sheet.crop((2 * FW, 4 * FH, 3 * FW, 5 * FH))
        x = (i % 2) * cell_w + 6
        y = (i // 2) * cell_h + 6
        m.paste(idle, (x, y), idle)
        m.paste(throw, (x + FW + 6, y), throw)
    m.save(PREVIEW)
    print(f"  preview → {PREVIEW.name}")


def main() -> None:
    print("Generating disc-golfer 2.5D sprite sheets (celestial-clash pipeline)…")
    # Drop preview from git noise if regenerating
    paths = [sheet_variant(v) for v in VARIANTS]
    montage(paths)
    print("Done.")


if __name__ == "__main__":
    main()
