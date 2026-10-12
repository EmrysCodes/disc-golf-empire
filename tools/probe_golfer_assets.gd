#!/usr/bin/env -S godot --headless --script
extends SceneTree

const SpriteKit = preload("res://visuals/sprite_kit.gd")

func _init() -> void:
	SpriteKit.ensure_ready()
	print("USE_ASSET_GOLFERS=", SpriteKit.USE_ASSET_GOLFERS)
	print("using_asset_golfers=", SpriteKit.using_asset_golfers())
	print("using_asset_discs=", SpriteKit.using_asset_discs())
	print("sheet0_exists=", ResourceLoader.exists("res://art/golfers/variant_0_sheet.png"))
	var frames: SpriteFrames = SpriteKit.golfer_frames(0, Color(0.2, 0.6, 0.7))
	print("anims=", frames.get_animation_names())
	for anim in ["idle", "walk", "throw"]:
		print("  ", anim, " frames=", frames.get_frame_count(anim))
		var tex: Texture2D = frames.get_frame_texture(anim, 0)
		if tex:
			print("    tex=", tex.get_class(), " size=", tex.get_size())
			if tex is AtlasTexture:
				var at := tex as AtlasTexture
				print("    atlas_region=", at.region, " atlas=", at.atlas)
	quit(0)
