# Per-visitor visual: shadow + AnimatedSprite2D with depth sort by world Y.
extends Node2D

const SpriteKitScript = preload("res://visuals/sprite_kit.gd")

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_PREPARE := "prepare"
const ANIM_RUN_UP := "run_up"
const ANIM_THROW := "throw"
const ANIM_PUTT := "putt"

var visitor_id: int = -1
var shadow: Sprite2D
var body: AnimatedSprite2D
var _current_anim: String = ""
var _held_release := false


func setup(id: int, shirt: Color, palette_index: int) -> void:
	visitor_id = id
	z_as_relative = false
	shadow = Sprite2D.new()
	shadow.texture = SpriteKitScript.shadow_texture()
	shadow.centered = true
	shadow.modulate = Color(1, 1, 1, 0.9)
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.centered = true
	body.sprite_frames = SpriteKitScript.golfer_frames(palette_index, shirt)
	# Pipeline sheets are 80×96; procedural fallback is ~36×44.
	if SpriteKitScript.using_asset_golfers():
		body.position = Vector2(0, -22)
		body.scale = Vector2(0.95, 0.95)
		body.modulate = Color(1, 1, 1)
		shadow.scale = Vector2(1.55, 1.35)
		shadow.position = Vector2(2, 10)
	else:
		body.position = Vector2(0, -12)
		body.scale = Vector2(1.9, 1.9)
		shadow.scale = Vector2(1.4, 1.4)
		shadow.position = Vector2(3, 13)
	body.play(ANIM_IDLE)
	_current_anim = ANIM_IDLE
	_held_release = false
	add_child(body)


func set_world_pose(world: Vector2, facing_x: float = 1.0) -> void:
	position = world
	z_index = int(clamp(world.y * 0.1, -1000.0, 1000.0))
	# Kenney toon sheets face camera-right; flip for leftward movement / throws.
	if facing_x < -0.12:
		body.flip_h = true
	elif facing_x > 0.12:
		body.flip_h = false


func play_for_stage(
	stage: String,
	shot_style: String = "",
	putting: bool = false,
	shot_progress: float = -1.0
) -> void:
	var desired := ANIM_IDLE
	if stage.begins_with("walking_") or stage in ["driving_in", "driving_out"]:
		desired = ANIM_WALK
		_held_release = false
	elif stage == "run_up":
		# Run cycle for most of the wind-up; last ~32% plays the throw release.
		if shot_progress >= 0.68:
			desired = ANIM_THROW
		else:
			desired = ANIM_RUN_UP if body.sprite_frames and body.sprite_frames.has_animation(ANIM_RUN_UP) else ANIM_THROW
		_held_release = false
	elif stage == "standstill":
		desired = ANIM_PUTT if putting else ANIM_THROW
		_held_release = false
	elif stage == "throwing":
		desired = ANIM_PREPARE if body.sprite_frames and body.sprite_frames.has_animation(ANIM_PREPARE) else ANIM_IDLE
		_held_release = false
	elif stage in ["waiting_group", "waiting_group_lie", "waiting_at_tee", "waiting_at_checkin", "waiting_partner", "waiting_at_basket", "parking", "feedback"]:
		desired = ANIM_IDLE
		_held_release = false
	elif stage == "disc_flying":
		_hold_release_pose(putting)
		return
	else:
		desired = ANIM_IDLE
		_held_release = false

	if desired == _current_anim and body.is_playing():
		return
	if body.sprite_frames and body.sprite_frames.has_animation(desired):
		body.play(desired)
		_current_anim = desired
		_held_release = false


func _hold_release_pose(putting: bool) -> void:
	var hold := ANIM_PUTT if putting else ANIM_THROW
	if not body.sprite_frames or not body.sprite_frames.has_animation(hold):
		return
	# First frame of disc_flying: if throw/putt is mid-play, let it finish once.
	if _current_anim == hold and body.is_playing() and not _held_release:
		var last_i: int = maxi(0, body.sprite_frames.get_frame_count(hold) - 1)
		if body.frame >= last_i:
			body.frame = last_i
			body.pause()
			_held_release = true
		return
	if _held_release and _current_anim == hold:
		return
	if _current_anim != hold:
		body.play(hold)
		_current_anim = hold
	var last_frame: int = maxi(0, body.sprite_frames.get_frame_count(hold) - 1)
	body.frame = last_frame
	body.pause()
	_held_release = true


func set_visible_actor(show_actor: bool) -> void:
	visible = show_actor
