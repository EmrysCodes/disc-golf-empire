#!/usr/bin/env -S godot --headless --script
extends SceneTree

func _init() -> void:
	var sk = load("res://visuals/sprite_kit.gd")
	sk.ensure_ready()
	print("ASSET_GOLFERS=", sk.using_asset_golfers())
	print("ASSET_DISCS=", sk.using_asset_discs())
	var frames = sk.golfer_frames(0, Color.WHITE)
	for a in ["idle", "walk", "prepare", "run_up", "throw", "putt"]:
		print(
			"ANIM_", a,
			" frames=", frames.get_frame_count(a),
			" fps=", frames.get_animation_speed(a),
			" loop=", frames.get_animation_loop(a)
		)
	quit()
