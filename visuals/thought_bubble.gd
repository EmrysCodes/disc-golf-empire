# Floating AI thought bubble — pooled, follows a world anchor.
extends Node2D

const DEFAULT_TTL := 2.4
# Clear of 80×96 sheet golfers (~body at -26 + scale) so text is not clipped.
const OFFSET := Vector2(0, -52)

var panel: PanelContainer
var label: Label
var ttl: float = 0.0
var owner_id: int = -1
var in_use: bool = false


func setup_pooled() -> void:
	z_as_relative = false
	z_index = 20
	visible = false
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.90, 0.94)
	style.border_color = Color(0.32, 0.42, 0.30, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.12, 0.14, 0.10, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.16, 0.20, 0.14, 1.0))
	panel.add_child(label)


func show_thought(id: int, text: String, seconds: float = DEFAULT_TTL) -> void:
	owner_id = id
	in_use = true
	ttl = seconds
	label.text = text
	visible = true
	modulate = Color.WHITE
	panel.reset_size()
	var size: Vector2 = panel.get_combined_minimum_size()
	panel.position = OFFSET + Vector2(-size.x * 0.5, -size.y)


func follow(world: Vector2) -> void:
	position = world
	z_index = int(clamp(world.y * 0.1 + 30.0, -1000.0, 1000.0))


func tick(delta: float) -> bool:
	if not in_use:
		return false
	ttl -= delta
	if ttl <= 0.45:
		modulate.a = clampf(ttl / 0.45, 0.0, 1.0)
	if ttl <= 0.0:
		reset_pool()
		return true
	return false


func reset_pool() -> void:
	in_use = false
	owner_id = -1
	ttl = 0.0
	label.text = ""
	visible = false
	modulate = Color.WHITE
