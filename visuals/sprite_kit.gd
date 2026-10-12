# Runtime procedural sprite sheets for golfers + discs.
# Prefer AnimatedSprite2D / Sprite2D over stick-figure _draw.
extends RefCounted

const GOLFER_W := 32
const GOLFER_H := 40
const DISC_SIZE := 16
const SHADOW_W := 28
const SHADOW_H := 12

static var _frames_by_palette: Dictionary = {}
static var _disc_texture: Texture2D
static var _shadow_texture: Texture2D
static var _ready := false


static func ensure_ready() -> void:
	if _ready:
		return
	_disc_texture = _make_disc_texture()
	_shadow_texture = _make_shadow_texture()
	_ready = true


static func golfer_frames(palette_index: int, shirt: Color) -> SpriteFrames:
	ensure_ready()
	var key := "%d_%s" % [palette_index, shirt.to_html(false)]
	if _frames_by_palette.has(key):
		return _frames_by_palette[key]
	var frames := SpriteFrames.new()
	_add_anim(frames, "idle", _build_golfer_strip(shirt, "idle", 4), 5.0, true)
	_add_anim(frames, "walk", _build_golfer_strip(shirt, "walk", 6), 9.0, true)
	_add_anim(frames, "throw", _build_golfer_strip(shirt, "throw", 5), 10.0, false)
	_add_anim(frames, "putt", _build_golfer_strip(shirt, "putt", 4), 8.0, false)
	_frames_by_palette[key] = frames
	return frames


static func disc_texture() -> Texture2D:
	ensure_ready()
	return _disc_texture


static func shadow_texture() -> Texture2D:
	ensure_ready()
	return _shadow_texture


static func _add_anim(frames: SpriteFrames, anim_name: String, textures: Array, fps: float, loop: bool) -> void:
	if frames.has_animation(anim_name):
		frames.remove_animation(anim_name)
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for tex in textures:
		frames.add_frame(anim_name, tex)


static func _build_golfer_strip(shirt: Color, anim: String, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		var t: float = float(i) / float(maxi(count - 1, 1))
		out.append(_make_golfer_frame(shirt, anim, t, i))
	return out


static func _make_golfer_frame(shirt: Color, anim: String, t: float, frame_i: int) -> Texture2D:
	var img := Image.create(GOLFER_W, GOLFER_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := GOLFER_W * 0.5
	var foot_y := GOLFER_H - 4.0
	var bob := 0.0
	var lean := 0.0
	var arm_swing := 0.0
	var disc_hold := true
	match anim:
		"idle":
			bob = sin(t * TAU) * 0.6
			arm_swing = sin(t * TAU) * 1.2
		"walk":
			bob = absf(sin(t * PI)) * 1.8
			arm_swing = sin(t * TAU) * 4.0
			lean = sin(t * TAU) * 0.8
		"throw":
			lean = lerpf(-3.0, 5.0, t)
			arm_swing = lerpf(-8.0, 10.0, t)
			disc_hold = t < 0.72
			bob = lerpf(0.0, -1.5, t)
		"putt":
			lean = lerpf(-1.0, 2.0, t)
			arm_swing = lerpf(-2.0, 5.0, t)
			disc_hold = t < 0.55
			bob = -0.4
	var body_x := cx + lean
	var body_y := foot_y - 14.0 + bob
	var leg_phase := sin(float(frame_i) * 1.2) if anim == "walk" else 0.0
	_fill_ellipse(img, body_x - 3.0 + leg_phase, foot_y - 1.0, 2.2, 1.4, Color(0.18, 0.16, 0.14, 0.95))
	_fill_ellipse(img, body_x + 3.0 - leg_phase, foot_y - 1.0, 2.2, 1.4, Color(0.18, 0.16, 0.14, 0.95))
	_fill_rect_soft(img, int(body_x - 2.5), int(body_y + 2.0), 5, 10, shirt.darkened(0.35))
	_fill_ellipse(img, body_x, body_y, 6.2, 7.4, shirt.darkened(0.12))
	_fill_ellipse(img, body_x - 1.2, body_y - 0.8, 4.4, 5.6, shirt)
	_fill_ellipse(img, body_x + 2.4, body_y + 0.6, 2.0, 4.5, shirt.darkened(0.28))
	var arm_y := body_y - 1.0
	_fill_ellipse(img, body_x - 6.0 - arm_swing * 0.15, arm_y + 2.0, 2.0, 3.2, Color("efc49d").darkened(0.08))
	_fill_ellipse(img, body_x + 6.5 + arm_swing * 0.35, arm_y - arm_swing * 0.1, 2.2, 3.4, Color("efc49d"))
	_fill_ellipse(img, body_x - 0.2, body_y - 10.0, 4.2, 4.4, Color("efc49d"))
	_fill_ellipse(img, body_x - 1.0, body_y - 11.2, 1.8, 1.4, Color(0.95, 0.88, 0.78, 0.55))
	_fill_ellipse(img, body_x - 0.2, body_y - 13.2, 4.6, 1.6, shirt.darkened(0.2))
	_fill_ellipse(img, body_x - 0.2, body_y - 14.2, 3.2, 1.5, shirt.lightened(0.08))
	if disc_hold:
		var dx := body_x + 7.5 + arm_swing * 0.4
		var dy := arm_y - 1.0 - arm_swing * 0.15
		_fill_ellipse(img, dx, dy, 3.4, 1.6, Color(0.98, 0.83, 0.23, 1.0))
		_fill_ellipse(img, dx - 0.4, dy - 0.3, 1.6, 0.7, Color(1.0, 0.93, 0.55, 0.85))
	return ImageTexture.create_from_image(img)


static func _make_disc_texture() -> Texture2D:
	var img := Image.create(DISC_SIZE, DISC_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := DISC_SIZE * 0.5
	_fill_ellipse(img, c + 0.6, c + 0.8, 6.2, 3.2, Color(0, 0, 0, 0.22))
	_fill_ellipse(img, c, c, 6.0, 2.8, Color(0.96, 0.78, 0.18, 1.0))
	_fill_ellipse(img, c - 0.6, c - 0.5, 3.4, 1.4, Color(1.0, 0.92, 0.45, 0.9))
	_stroke_ellipse(img, c, c, 6.0, 2.8, Color(0.25, 0.22, 0.12, 0.85))
	return ImageTexture.create_from_image(img)


static func _make_shadow_texture() -> Texture2D:
	var img := Image.create(SHADOW_W, SHADOW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, SHADOW_W * 0.5, SHADOW_H * 0.5, 11.0, 4.2, Color(0, 0, 0, 0.28))
	_fill_ellipse(img, SHADOW_W * 0.5, SHADOW_H * 0.5, 7.5, 2.8, Color(0, 0, 0, 0.18))
	return ImageTexture.create_from_image(img)


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(cx - rx - 1.0)))
	var y0 := maxi(0, int(floor(cy - ry - 1.0)))
	var x1 := mini(w - 1, int(ceil(cx + rx + 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + ry + 1.0)))
	var rx2 := maxf(0.001, rx * rx)
	var ry2 := maxf(0.001, ry * ry)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx)
			var dy := (float(y) + 0.5 - cy)
			if (dx * dx) / rx2 + (dy * dy) / ry2 <= 1.0:
				img.set_pixel(x, y, color)


static func _stroke_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(cx - rx - 1.0)))
	var y0 := maxi(0, int(floor(cy - ry - 1.0)))
	var x1 := mini(w - 1, int(ceil(cx + rx + 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + ry + 1.0)))
	var rx2 := maxf(0.001, rx * rx)
	var ry2 := maxf(0.001, ry * ry)
	var outer := 1.18
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx)
			var dy := (float(y) + 0.5 - cy)
			var n := (dx * dx) / rx2 + (dy * dy) / ry2
			if n <= outer and n >= 0.82:
				img.set_pixel(x, y, color)


static func _fill_rect_soft(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	for yy in range(maxi(0, y), mini(ih, y + h)):
		for xx in range(maxi(0, x), mini(iw, x + w)):
			img.set_pixel(xx, yy, color)
