# Disc sprite + ground shadow for lies and in-flight arcs.
extends Node2D

const SpriteKitScript = preload("res://visuals/sprite_kit.gd")

var shadow: Sprite2D
var disc: Sprite2D


func setup() -> void:
	z_as_relative = false
	shadow = Sprite2D.new()
	shadow.texture = SpriteKitScript.shadow_texture()
	shadow.centered = true
	shadow.scale = Vector2(0.45, 0.45)
	shadow.modulate = Color(1, 1, 1, 0.85)
	add_child(shadow)
	disc = Sprite2D.new()
	disc.texture = SpriteKitScript.disc_texture()
	disc.centered = true
	disc.scale = Vector2(1.55, 1.55)
	add_child(disc)


func set_lie(world: Vector2) -> void:
	visible = true
	position = world
	z_index = int(clamp(world.y * 0.1 + 1.0, -1000.0, 1000.0))
	disc.position = Vector2.ZERO
	shadow.position = Vector2(1, 2)
	shadow.modulate.a = 0.55
	disc.rotation = 0.0
	disc.scale = Vector2.ONE


func set_flight(disc_world: Vector2, ground_world: Vector2, progress: float) -> void:
	visible = true
	position = ground_world
	z_index = int(clamp(ground_world.y * 0.1 + 2.0, -1000.0, 1000.0))
	disc.position = disc_world - ground_world
	shadow.position = Vector2(2, 2)
	var lift := clampf(disc_world.distance_to(ground_world) / 80.0, 0.0, 1.0)
	shadow.modulate.a = lerpf(0.55, 0.22, lift)
	shadow.scale = Vector2(0.45, 0.45) * lerpf(1.0, 1.35, lift)
	disc.rotation = progress * TAU * 1.6
	disc.scale = Vector2.ONE * lerpf(1.0, 1.15, sin(progress * PI))


func hide_disc() -> void:
	visible = false
