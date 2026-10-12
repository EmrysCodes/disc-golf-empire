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
    img = oval(img, cx, cy, 9.0, 9.8, skin, hi=1.2, lo=0.58)
    d = ImageDraw.Draw(img)
    # brows
    d.arc([cx - 7, cy - 5, cx - 1, cy + 1], 200, 340, fill=C(skin, 0.55, 180), width=1)
    d.arc([cx + 1, cy - 5, cx + 7, cy + 1], 200, 340, fill=C(skin, 0.55, 180), width=1)
    d.ellipse([cx - 4.2, cy - 1.6, cx - 0.8, cy + 1.4], fill=(250, 250, 255, 235))
    d.ellipse([cx + 1.2, cy - 1.6, cx + 4.6, cy + 1.4], fill=(250, 250, 255, 235))
    d.ellipse([cx - 3.4, cy - 0.8, cx - 1.5, cy + 0.7], fill=eye + (255,))
    d.ellipse([cx + 2.0, cy - 0.8, cx + 3.9, cy + 0.7], fill=eye + (255,))
    # cheek warmth
    d.ellipse([cx - 6, cy + 2, cx - 3, cy + 4.5], fill=C(skin, 0.85, 70))
    d.ellipse([cx + 3, cy + 2, cx + 6, cy + 4.5], fill=C(skin, 0.85, 70))
    return img


def disc(img: Image.Image, cx, cy, accent, squash: float = 1.0) -> Image.Image:
    rx, ry = 6.4 * squash, 2.6 / max(0.7, squash * 0.9)
    img = oval(img, cx + 0.5, cy + 0.6, rx + 0.4, ry + 0.3, (22, 18, 10), hi=0.75, lo=0.4)
    img = oval(img, cx, cy, rx, ry, accent, hi=1.28, lo=0.68)
    img = oval(img, cx - 1.0, cy - 0.5, 2.6, 1.0, C(accent, 1.35)[:3], hi=1.2, lo=0.9)
    # rim line
    layer = blank(*img.size)
    ImageDraw.Draw(layer).arc(
        [cx - rx, cy - ry, cx + rx, cy + ry],
        20,
        200,
        fill=C(accent, 0.55, 160),
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
        bob = math.sin(phase) * 1.4
        arm = math.sin(phase) * 2.0
        stride = math.sin(phase) * 1.0
    elif anim == "walk":
        phase = frame / float(count) * math.tau
        bob = abs(math.sin(phase)) * 2.8
        arm = math.sin(phase) * 9.0
        lean = math.sin(phase) * 1.4
        stride = math.sin(phase) * 8.0
    elif anim == "prepare":
        bob = math.sin(t * math.tau) * 0.6
        lean = -2.0 - t * 1.5
        arm = -4.0 - t * 4.0
        crouch = 2.0 + t * 1.2
        stride = -1.5
    elif anim == "run_up":
        phase = t * math.tau * 1.35
        bob = abs(math.sin(phase)) * 3.0
        lean = -5.0 + t * 8.5
        arm = -8.5 + t * 14.0
        stride = math.sin(phase) * 8.5
        hold_disc = t < 0.86
        release = max(0.0, (t - 0.72) / 0.28)
    elif anim == "throw":
        lean = -3.5 + t * 11.5
        arm = -12.0 + t * 26.0
        bob = -t * 2.4
        stride = -2.5 + t * 7.5
        hold_disc = t < 0.58
        release = max(0.0, (t - 0.4) / 0.6)
        crouch = max(0.0, 1.5 - t * 1.8)
    elif anim == "putt":
        lean = -1.2 + t * 4.0
        arm = -3.0 + t * 10.5
        bob = -1.0
        crouch = 2.8 - t * 1.6
        hold_disc = t < 0.45
        release = max(0.0, (t - 0.32) / 0.68)
        stride = -0.8 + t * 2.0
    return bob, lean, arm, stride, crouch, hold_disc, release


def draw_golfer(v: dict, anim: str, frame: int, count: int) -> Image.Image:
    img = blank(FW, FH)
    cx = FW // 2
    foot = int(FH * 0.88)
    bob, lean, arm, stride, crouch, hold_disc, release = pose_params(anim, frame, count)
    cy = foot + bob + crouch
    bx = cx + lean

    shirt = v["shirt"]
    shorts = v["shorts"]
    shoes = v["shoes"]
    skin = v["skin"]
    hair = v["hair"]
    cap = v["cap"]
    accent = v["accent"]

    img = shadow(img, bx, foot + 3)

    # Legs
    lx0, ly0 = bx - 5.5, cy - 1
    rx0, ry0 = bx + 5.5, cy - 1
    lx1 = bx - 9 + stride * 0.5
    rx1 = bx + 10 - stride * 0.5
    ly1 = foot - 1
    ry1 = foot - 1
    img = limb(img, lx0, ly0, lx1, ly1, 4.4, C(shorts, 0.82)[:3], joint=0.45)
    img = limb(img, rx0, ry0, rx1, ry1, 4.4, shorts, joint=0.45)
    img = oval(img, lx1, ly1 + 1.8, 6.2, 3.2, shoes, hi=1.05, lo=0.48)
    img = oval(img, rx1, ry1 + 1.8, 6.2, 3.2, shoes, hi=1.05, lo=0.48)
    # sole highlight
    img = oval(img, lx1 - 0.5, ly1 + 0.6, 3.0, 1.0, C(shoes, 1.25)[:3], hi=1.0, lo=0.9)
    img = oval(img, rx1 - 0.5, ry1 + 0.6, 3.0, 1.0, C(shoes, 1.25)[:3], hi=1.0, lo=0.9)

    # Shorts
    img = plate(
        img,
        [
            (bx - 11, cy - 5),
            (bx + 11, cy - 6),
            (bx + 10, cy + 10),
            (bx - 10, cy + 11),
        ],
        C(shorts, 0.95)[:3],
    )
    # hem crease
    img = soft(img, [bx - 8, cy + 4, bx + 8, cy + 10], C(shorts, 0.65, 90), 0.8)

    # Torso volume
    img = oval(img, bx, cy - 19, 12.5, 16.0, shirt, hi=1.14, lo=0.52)
    # sleeve stubs
    img = oval(img, bx - 11, cy - 16, 4.5, 5.5, C(shirt, 0.9)[:3], hi=1.05, lo=0.55)
    img = oval(img, bx + 11, cy - 17, 4.5, 5.5, C(shirt, 1.0)[:3], hi=1.1, lo=0.55)
    # collar
    img = plate(
        img,
        [
            (bx - 6, cy - 32),
            (bx + 6, cy - 33),
            (bx + 4, cy - 22),
            (bx - 4, cy - 21),
        ],
        C(shirt, 1.18)[:3],
    )
    # chest highlight fold
    img = oval(img, bx - 2.5, cy - 21, 4.2, 6.0, C(shirt, 1.22)[:3], hi=1.08, lo=0.92)

    # Back arm
    back_ax = bx - 11 - arm * 0.12
    back_ay = cy - 17
    back_hx = bx - 16 - arm * 0.28
    back_hy = cy - 1 + abs(arm) * 0.06
    img = limb(img, back_ax, back_ay, back_hx, back_hy, 3.8, skin, joint=0.42)

    # Head stack — hair under, face, then cap slightly raised so eyes read
    hx, hy = bx + 0.8, cy - 38
    img = oval(img, hx - 0.5, hy - 2, 9.5, 6.5, hair, hi=1.05, lo=0.48)
    img = face(img, hx, hy + 1.5, skin)
    # Cap crown (sits above eyes)
    img = poly(
        img,
        [
            (hx - 9, hy - 3),
            (hx + 8, hy - 5),
            (hx + 9, hy + 1),
            (hx - 9, hy + 2.5),
        ],
        cap,
    )
    img = oval(img, hx, hy - 4.5, 8.5, 3.6, C(cap, 1.06)[:3], hi=1.18, lo=0.62)
    # Visor toward throw side
    img = poly(
        img,
        [
            (hx + 2, hy - 0.5),
            (hx + 16, hy + 0.5),
            (hx + 15, hy + 3.5),
            (hx + 1, hy + 2.5),
        ],
        C(cap, 0.82)[:3],
    )
    # Cap button
    img = oval(img, hx, hy - 6.5, 1.6, 1.2, C(cap, 1.25)[:3], hi=1.1, lo=0.9)

    # Throw arm
    throw_sx = bx + 11 + arm * 0.04
    throw_sy = cy - 18
    throw_ex = bx + 14 + arm * 0.58
    throw_ey = cy - 12 - arm * 0.24
    if anim in ("throw", "run_up") and release > 0.15:
        throw_ex = bx + 16 + release * 18
        throw_ey = cy - 22 - release * 12
    if anim == "putt":
        throw_ex = bx + 9 + arm * 0.38
        throw_ey = cy - 7 - arm * 0.18 + crouch * 0.25
    if anim == "prepare":
        throw_ex = bx + 7 + arm * 0.22
        throw_ey = cy - 5
    img = limb(img, throw_sx, throw_sy, throw_ex, throw_ey, 3.9, skin, joint=0.42)

    if hold_disc:
        img = disc(img, throw_ex + 4.0, throw_ey - 0.8, accent, squash=1.08)
    elif release > 0.3 and anim in ("throw", "run_up", "putt"):
        img = soft(
            img,
            [throw_ex + 2 - 7, throw_ey - 10, throw_ex + 16, throw_ey + 5],
            (*accent[:3], int(75 + release * 55)),
            2.2,
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
    cell_w, cell_h = FW * 2 + 12, FH + 12
    m = Image.new("RGBA", (cell_w * 2, cell_h * 2), (34, 52, 40, 255))
    for i, p in enumerate(paths):
        sheet = Image.open(p).convert("RGBA")
        idle = sheet.crop((0, 0, FW, FH))
        throw = sheet.crop((3 * FW, 4 * FH, 4 * FW, 5 * FH))
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
