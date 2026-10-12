# Disc sprite + ground shadow for lies and in-flight arcs.
extends Node2D

const SpriteKitScript = preload("res://visuals/sprite_kit.gd")

var shadow: Sprite2D
var disc: AnimatedSprite2D


func setup() -> void:
	z_as_relative = false
	shadow = Sprite2D.new()
	shadow.texture = SpriteKitScript.shadow_texture()
	shadow.centered = true
	shadow.scale = Vector2(0.45, 0.45)
	shadow.modulate = Color(1, 1, 1, 0.85)
	add_child(shadow)
	disc = AnimatedSprite2D.new()
	disc.sprite_frames = SpriteKitScript.disc_frames()
	disc.centered = true
	disc.scale = Vector2(1.6, 1.6)
	disc.play("lie")
	add_child(disc)


func set_lie(world: Vector2) -> void:
	visible = true
	position = world
	z_index = int(clamp(world.y * 0.1 + 1.0, -1000.0, 1000.0))
	disc.position = Vector2.ZERO
	shadow.position = Vector2(1, 2)
	shadow.modulate.a = 0.55
	shadow.scale = Vector2(0.45, 0.45)
	disc.rotation = 0.0
	disc.scale = Vector2(1.55, 1.55)
	if disc.animation != "lie":
		disc.play("lie")


func set_flight(disc_world: Vector2, ground_world: Vector2, progress: float, heading: Vector2 = Vector2.RIGHT) -> void:
	visible = true
	position = ground_world
	z_index = int(clamp(ground_world.y * 0.1 + 2.0, -1000.0, 1000.0))
	disc.position = disc_world - ground_world
	shadow.position = Vector2(2, 2)
	var lift := clampf(disc_world.distance_to(ground_world) / 90.0, 0.0, 1.0)
	shadow.modulate.a = lerpf(0.55, 0.18, lift)
	shadow.scale = Vector2(0.45, 0.45) * lerpf(1.0, 1.45, lift)
	# Align plate to flight direction; AnimatedSprite spin reads as rotation.
	var dir: Vector2 = heading
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	disc.rotation = dir.angle()
	var bank := 1.0 + 0.22 * sin(progress * PI)
	disc.scale = Vector2(1.55 * bank, 1.35 / bank) * lerpf(1.0, 1.18, sin(progress * PI))
	if disc.animation != "spin" or not disc.is_playing():
		disc.play("spin")


func hide_disc() -> void:
	visible = false
