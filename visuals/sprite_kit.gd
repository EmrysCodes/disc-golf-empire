# Runtime procedural sprite sheets for golfers + discs.
# Prefer AnimatedSprite2D / Sprite2D over stick-figure _draw.
extends RefCounted

const GOLFER_W := 36
const GOLFER_H := 44
const DISC_SIZE := 18
const SHADOW_W := 28
const SHADOW_H := 12

static var _frames_by_palette: Dictionary = {}
static var _disc_frames: SpriteFrames
static var _disc_texture: Texture2D
static var _shadow_texture: Texture2D
static var _ready := false


static func ensure_ready() -> void:
	if _ready:
		return
	_disc_texture = _make_disc_texture(0.0, 1.0)
	_disc_frames = _make_disc_frames()
	_shadow_texture = _make_shadow_texture()
	_ready = true


static func golfer_frames(palette_index: int, shirt: Color) -> SpriteFrames:
	ensure_ready()
	var key := "v2_%d_%s" % [palette_index, shirt.to_html(false)]
	if _frames_by_palette.has(key):
		return _frames_by_palette[key]
	var frames := SpriteFrames.new()
	_add_anim(frames, "idle", _build_golfer_strip(shirt, "idle", 6), 6.0, true)
	_add_anim(frames, "walk", _build_golfer_strip(shirt, "walk", 8), 11.0, true)
	_add_anim(frames, "prepare", _build_golfer_strip(shirt, "prepare", 4), 7.0, true)
	_add_anim(frames, "run_up", _build_golfer_strip(shirt, "run_up", 6), 12.0, false)
	_add_anim(frames, "throw", _build_golfer_strip(shirt, "throw", 6), 12.0, false)
	_add_anim(frames, "putt", _build_golfer_strip(shirt, "putt", 5), 9.0, false)
	_frames_by_palette[key] = frames
	return frames


static func disc_texture() -> Texture2D:
	ensure_ready()
	return _disc_texture


static func disc_frames() -> SpriteFrames:
	ensure_ready()
	return _disc_frames


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
	var foot_y := GOLFER_H - 5.0
	var bob := 0.0
	var lean := 0.0
	var arm_swing := 0.0
	var stride := 0.0
	var disc_hold := true
	var crouch := 0.0
	match anim:
		"idle":
			bob = sin(t * TAU) * 0.8
			arm_swing = sin(t * TAU) * 1.4
			stride = sin(t * TAU) * 0.6
		"walk":
			bob = absf(sin(t * PI)) * 2.2
			arm_swing = sin(t * TAU) * 5.0
			lean = sin(t * TAU) * 1.0
			stride = sin(t * TAU) * 3.2
		"prepare":
			bob = sin(t * TAU) * 0.4
			lean = lerpf(-1.2, -2.0, t)
			arm_swing = lerpf(-3.0, -5.0, t)
			crouch = 1.2
		"run_up":
			bob = absf(sin(t * PI * 2.0)) * 2.4
			lean = lerpf(-4.0, 2.0, t)
			arm_swing = lerpf(-6.0, 4.0, t)
			stride = sin(t * TAU * 1.5) * 4.0
			disc_hold = t < 0.85
		"throw":
			lean = lerpf(-2.5, 6.0, t)
			arm_swing = lerpf(-9.0, 12.0, t)
			disc_hold = t < 0.68
			bob = lerpf(0.0, -2.0, t)
			stride = lerpf(-2.0, 3.0, t)
		"putt":
			lean = lerpf(-0.8, 2.4, t)
			arm_swing = lerpf(-2.5, 6.0, t)
			disc_hold = t < 0.52
			bob = -0.6
			crouch = lerpf(1.5, 0.4, t)
	var body_x := cx + lean
	var body_y := foot_y - 15.0 + bob + crouch
	# Legs with stride for walk/run_up.
	_fill_ellipse(img, body_x - 3.5 - stride * 0.35, foot_y - 1.0, 2.4, 1.5, Color(0.16, 0.14, 0.12, 0.95))
	_fill_ellipse(img, body_x + 3.5 + stride * 0.35, foot_y - 1.0, 2.4, 1.5, Color(0.16, 0.14, 0.12, 0.95))
	_fill_rect_soft(img, int(body_x - 2.8), int(body_y + 2.0), 6, 11, shirt.darkened(0.38))
	# Torso with faux depth (darker right edge).
	_fill_ellipse(img, body_x, body_y, 6.8, 8.0, shirt.darkened(0.14))
	_fill_ellipse(img, body_x - 1.3, body_y - 0.9, 4.8, 6.0, shirt)
	_fill_ellipse(img, body_x + 2.6, body_y + 0.7, 2.2, 4.8, shirt.darkened(0.3))
	var arm_y := body_y - 1.0
	_fill_ellipse(img, body_x - 6.5 - arm_swing * 0.12, arm_y + 2.2, 2.2, 3.4, Color("efc49d").darkened(0.08))
	_fill_ellipse(img, body_x + 7.0 + arm_swing * 0.38, arm_y - arm_swing * 0.12, 2.4, 3.6, Color("efc49d"))
	_fill_ellipse(img, body_x - 0.2, body_y - 11.0, 4.5, 4.6, Color("efc49d"))
	_fill_ellipse(img, body_x - 1.1, body_y - 12.2, 1.9, 1.5, Color(0.95, 0.88, 0.78, 0.55))
	_fill_ellipse(img, body_x - 0.2, body_y - 14.2, 5.0, 1.7, shirt.darkened(0.22))
	_fill_ellipse(img, body_x - 0.2, body_y - 15.2, 3.4, 1.6, shirt.lightened(0.1))
	if disc_hold:
		var dx := body_x + 8.0 + arm_swing * 0.42
		var dy := arm_y - 1.2 - arm_swing * 0.16
		_fill_ellipse(img, dx, dy, 3.6, 1.7, Color(0.98, 0.83, 0.23, 1.0))
		_fill_ellipse(img, dx - 0.4, dy - 0.3, 1.7, 0.75, Color(1.0, 0.93, 0.55, 0.85))
	# Subtle frame index pepper so strips don't look static.
	if frame_i % 2 == 0:
		_fill_ellipse(img, body_x + 1.5, body_y + 3.0, 1.0, 1.4, shirt.darkened(0.18))
	return ImageTexture.create_from_image(img)


static func _make_disc_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var spin: Array = []
	for i in range(8):
		var t: float = float(i) / 8.0
		spin.append(_make_disc_texture(t * TAU, 1.0 + 0.08 * sin(t * TAU)))
	_add_anim(frames, "spin", spin, 16.0, true)
	var lie: Array = [_make_disc_texture(0.0, 1.0)]
	_add_anim(frames, "lie", lie, 1.0, true)
	return frames


static func _make_disc_texture(spin_phase: float = 0.0, squash: float = 1.0) -> Texture2D:
	var img := Image.create(DISC_SIZE, DISC_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := DISC_SIZE * 0.5
	var rx := 6.4 * squash
	var ry := 2.7 / maxf(0.75, squash * 0.85)
	_fill_ellipse(img, c + 0.7, c + 0.9, rx + 0.4, ry + 0.35, Color(0, 0, 0, 0.22))
	_fill_ellipse(img, c, c, rx, ry, Color(0.96, 0.78, 0.18, 1.0))
	# Spin highlight sweeps around the rim.
	var hx := cos(spin_phase) * rx * 0.35
	var hy := sin(spin_phase) * ry * 0.45
	_fill_ellipse(img, c - 0.4 + hx, c - 0.4 + hy, 2.8, 1.1, Color(1.0, 0.94, 0.5, 0.9))
	_stroke_ellipse(img, c, c, rx, ry, Color(0.25, 0.22, 0.12, 0.85))
	# Flight plate stamp
	_fill_ellipse(img, c + cos(spin_phase + 1.2) * 1.5, c + sin(spin_phase + 1.2) * 0.7, 1.2, 0.55, Color(0.85, 0.55, 0.12, 0.7))
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
