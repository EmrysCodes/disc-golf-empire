# Pooled Line2D trail that follows a disc in flight, then fades out.
extends Line2D

const MAX_POINTS := 64
const FADE_SECONDS := 0.7
const ACTIVE_WIDTH := 6.5
# Distinct from the authored white hole path so live throws read clearly.
const ACTIVE_COLOR := Color(1.0, 0.42, 0.08, 0.92)

var active: bool = false
var fading: bool = false
var fade_left: float = 0.0
var owner_id: int = -1


func setup_pooled() -> void:
	width = ACTIVE_WIDTH
	default_color = ACTIVE_COLOR
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = true
	z_as_relative = false
	z_index = 6
	visible = false
	clear_points()


func begin_trail(id: int, start_world: Vector2) -> void:
	owner_id = id
	active = true
	fading = false
	fade_left = 0.0
	default_color = ACTIVE_COLOR
	modulate = Color.WHITE
	clear_points()
	add_point(start_world)
	visible = true


func append_world(point: Vector2) -> void:
	if not active or fading:
		return
	if get_point_count() > 0 and get_point_position(get_point_count() - 1).distance_to(point) < 2.0:
		return
	add_point(point)
	while get_point_count() > MAX_POINTS:
		remove_point(0)


func start_fade() -> void:
	if not active and not visible:
		return
	active = false
	fading = true
	fade_left = FADE_SECONDS


func tick(delta: float) -> bool:
	if fading:
		fade_left = maxf(0.0, fade_left - delta)
		var t: float = 1.0 - (fade_left / FADE_SECONDS)
		modulate.a = lerpf(1.0, 0.0, t)
		width = lerpf(ACTIVE_WIDTH, 1.2, t)
		if fade_left <= 0.0:
			reset_pool()
			return true
	return false


func reset_pool() -> void:
	active = false
	fading = false
	fade_left = 0.0
	owner_id = -1
	clear_points()
	modulate = Color.WHITE
	width = ACTIVE_WIDTH
	visible = false
