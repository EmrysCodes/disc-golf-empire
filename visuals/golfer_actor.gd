# Per-visitor visual: shadow + AnimatedSprite2D with depth sort by world Y.
extends Node2D

const SpriteKitScript = preload("res://visuals/sprite_kit.gd")

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_THROW := "throw"
const ANIM_PUTT := "putt"

var visitor_id: int = -1
var shadow: Sprite2D
var body: AnimatedSprite2D
var _current_anim: String = ""


func setup(id: int, shirt: Color, palette_index: int) -> void:
	visitor_id = id
	z_as_relative = false
	shadow = Sprite2D.new()
	shadow.texture = SpriteKitScript.shadow_texture()
	shadow.centered = true
	shadow.position = Vector2(2, 8)
	shadow.modulate = Color(1, 1, 1, 0.9)
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.centered = true
	body.position = Vector2(0, -10)
	body.scale = Vector2(1.85, 1.85)
	body.sprite_frames = SpriteKitScript.golfer_frames(palette_index, shirt)
	body.play(ANIM_IDLE)
	_current_anim = ANIM_IDLE
	add_child(body)
	shadow.scale = Vector2(1.35, 1.35)
	shadow.position = Vector2(3, 12)


func set_world_pose(world: Vector2, facing_x: float = 1.0) -> void:
	position = world
	z_index = int(clamp(world.y * 0.1, -1000.0, 1000.0))
	if facing_x < -0.15:
		body.flip_h = true
	elif facing_x > 0.15:
		body.flip_h = false


func play_for_stage(stage: String, shot_style: String = "", putting: bool = false) -> void:
	var desired := ANIM_IDLE
	if stage.begins_with("walking_") or stage in ["driving_in", "driving_out"]:
		desired = ANIM_WALK
	elif stage == "run_up":
		desired = ANIM_THROW
	elif stage == "standstill":
		desired = ANIM_PUTT if putting else ANIM_THROW
	elif stage == "throwing":
		desired = ANIM_IDLE
	elif stage == "disc_flying":
		var hold := ANIM_PUTT if putting else ANIM_THROW
		if body.sprite_frames and body.sprite_frames.has_animation(hold):
			if _current_anim != hold:
				body.play(hold)
				_current_anim = hold
			body.frame = maxi(0, body.sprite_frames.get_frame_count(hold) - 1)
			body.pause()
			return
	if desired == _current_anim and body.is_playing():
		return
	if body.sprite_frames and body.sprite_frames.has_animation(desired):
		body.play(desired)
		_current_anim = desired


func set_visible_actor(show_actor: bool) -> void:
	visible = show_actor
