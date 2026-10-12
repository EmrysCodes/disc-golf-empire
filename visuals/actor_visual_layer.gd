# Additive visual layer for golfers, discs, flight trails, and AI thoughts.
# Parent under GolferManager; does not own gameplay state.
extends Node2D

const GolferActorScript = preload("res://visuals/golfer_actor.gd")
const DiscActorScript = preload("res://visuals/disc_actor.gd")
const FlightTrailScript = preload("res://visuals/flight_trail.gd")
const ThoughtBubbleScript = preload("res://visuals/thought_bubble.gd")
const SpriteKitScript = preload("res://visuals/sprite_kit.gd")

const TRAIL_POOL_SIZE := 8
const BUBBLE_POOL_SIZE := 12

var actors_root: Node2D
var trails_root: Node2D
var bubbles_root: Node2D
var golfer_actors: Dictionary = {} # id -> GolferActor
var disc_actors: Dictionary = {} # id -> DiscActor
var trail_pool: Array = []
var active_trails: Dictionary = {} # id -> FlightTrail
var bubble_pool: Array = []
var active_bubbles: Dictionary = {} # id -> ThoughtBubble
var fading_trails: Array = []
var property_manager


func setup(property_ref) -> void:
	property_manager = property_ref
	name = "ActorVisualLayer"
	z_index = 0
	y_sort_enabled = true
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	actors_root.y_sort_enabled = true
	add_child(actors_root)
	trails_root = Node2D.new()
	trails_root.name = "Trails"
	# Above ground foliage band, under thought bubbles; readable over grass.
	trails_root.z_as_relative = false
	trails_root.z_index = 6
	add_child(trails_root)
	bubbles_root = Node2D.new()
	bubbles_root.name = "ThoughtBubbles"
	bubbles_root.z_index = 40
	add_child(bubbles_root)
	SpriteKitScript.ensure_ready()
	for i in range(TRAIL_POOL_SIZE):
		var trail = FlightTrailScript.new()
		trail.setup_pooled()
		trails_root.add_child(trail)
		trail_pool.append(trail)
	for i in range(BUBBLE_POOL_SIZE):
		var bubble = ThoughtBubbleScript.new()
		bubble.setup_pooled()
		bubbles_root.add_child(bubble)
		bubble_pool.append(bubble)


func sync_visitor(
	visitor: Dictionary,
	person: Dictionary,
	body_world: Vector2,
	facing_x: float,
	putting: bool = false,
	shot_progress: float = -1.0
) -> void:
	var id: int = int(visitor["id"])
	var stage: String = str(visitor["stage"])
	if stage in ["driving_in", "driving_out"]:
		_hide_visitor(id)
		return
	var actor = _ensure_golfer(id, person)
	actor.set_visible_actor(true)
	actor.set_world_pose(body_world, facing_x)
	actor.play_for_stage(stage, str(visitor.get("shot_style", "")), putting, shot_progress)
	var disc = _ensure_disc(id)
	if stage in ["throwing", "standstill", "run_up", "disc_flying", "waiting_group", "waiting_group_lie", "walking_group_lie", "walking_to_lie", "walking_to_basket"]:
		if stage == "disc_flying":
			var duration: float = maxf(0.01, float(visitor.get("flight_duration", 1.0)))
			var progress: float = clampf(float(visitor.get("flight_elapsed", 0.0)) / duration, 0.0, 1.0)
			var disc_local: Vector2 = _flight_visual(visitor)
			var ground_local: Vector2 = _flight_ground(visitor, progress)
			var disc_world: Vector2 = property_manager.property_local_to_world(disc_local)
			var ground_world: Vector2 = property_manager.property_local_to_world(ground_local)
			var heading: Vector2 = _flight_heading(visitor, progress)
			disc.set_flight(disc_world, ground_world, progress, heading)
			# Trail follows the curved ground track (readable vs white design path + altitude).
			var trail_world: Vector2 = ground_world + Vector2(0.0, -4.0) + (disc_world - ground_world) * 0.35
			_append_trail(id, trail_world)
		else:
			var lie_world: Vector2 = property_manager.property_local_to_world(visitor["disc_position"])
			disc.set_lie(lie_world)
	else:
		disc.hide_disc()
	if active_bubbles.has(id):
		active_bubbles[id].follow(body_world)


func begin_flight_trail(visitor: Dictionary) -> void:
	var id: int = int(visitor["id"])
	_release_trail(id, false)
	var trail = _acquire_trail()
	if trail == null:
		return
	var start_local: Vector2 = visitor["flight_start"]
	var start_world: Vector2 = property_manager.property_local_to_world(start_local)
	trail.begin_trail(id, start_world)
	active_trails[id] = trail


func end_flight_trail(visitor: Dictionary) -> void:
	_release_trail(int(visitor["id"]), true)


func set_thought(visitor: Dictionary, text: String, seconds: float = 2.4) -> void:
	if text.is_empty():
		return
	var id: int = int(visitor["id"])
	var bubble
	if active_bubbles.has(id):
		bubble = active_bubbles[id]
	else:
		bubble = _acquire_bubble()
		if bubble == null:
			return
		active_bubbles[id] = bubble
	bubble.show_thought(id, text, seconds)
	var local: Vector2 = visitor.get("position", Vector2.ZERO)
	if property_manager != null:
		bubble.follow(property_manager.property_local_to_world(local))


func tick(delta: float) -> void:
	var finished_bubbles: Array = []
	for id in active_bubbles.keys():
		var bubble = active_bubbles[id]
		if bubble.tick(delta):
			finished_bubbles.append(id)
			bubble_pool.append(bubble)
	for id in finished_bubbles:
		active_bubbles.erase(id)
	var still_fading: Array = []
	for trail_value in fading_trails:
		var trail = trail_value
		if trail.tick(delta):
			trail_pool.append(trail)
		else:
			still_fading.append(trail)
	fading_trails = still_fading


func prune_to_visitors(visitor_ids: Dictionary) -> void:
	var remove_g: Array = []
	for id in golfer_actors.keys():
		if not visitor_ids.has(id):
			remove_g.append(id)
	for id in remove_g:
		_free_golfer(id)
	var remove_d: Array = []
	for id in disc_actors.keys():
		if not visitor_ids.has(id):
			remove_d.append(id)
	for id in remove_d:
		_free_disc(id)
	for id in active_trails.keys():
		if not visitor_ids.has(id):
			_release_trail(id, false)
	var drop_bubbles: Array = []
	for id in active_bubbles.keys():
		if not visitor_ids.has(id):
			drop_bubbles.append(id)
	for id in drop_bubbles:
		var bubble = active_bubbles[id]
		bubble.reset_pool()
		bubble_pool.append(bubble)
		active_bubbles.erase(id)


func _ensure_golfer(id: int, person: Dictionary):
	if golfer_actors.has(id):
		return golfer_actors[id]
	var actor = GolferActorScript.new()
	var appearance: int = int(person.get("appearance", 0))
	var palette := [
		Color("5e9ec7"), Color("d59c64"), Color("b46d9b"),
		Color("81b36c"), Color("cf8d72"), Color("847dc2")
	]
	var shirt: Color = palette[appearance % palette.size()]
	actor.setup(id, shirt, appearance)
	actors_root.add_child(actor)
	golfer_actors[id] = actor
	return actor


func _ensure_disc(id: int):
	if disc_actors.has(id):
		return disc_actors[id]
	var disc = DiscActorScript.new()
	disc.setup()
	actors_root.add_child(disc)
	disc_actors[id] = disc
	return disc


func _hide_visitor(id: int) -> void:
	if golfer_actors.has(id):
		golfer_actors[id].set_visible_actor(false)
	if disc_actors.has(id):
		disc_actors[id].hide_disc()


func _free_golfer(id: int) -> void:
	if not golfer_actors.has(id):
		return
	var actor = golfer_actors[id]
	golfer_actors.erase(id)
	actor.queue_free()


func _free_disc(id: int) -> void:
	if not disc_actors.has(id):
		return
	var disc = disc_actors[id]
	disc_actors.erase(id)
	disc.queue_free()


func _acquire_trail():
	if trail_pool.is_empty():
		if not fading_trails.is_empty():
			var recycled = fading_trails.pop_front()
			recycled.reset_pool()
			return recycled
		return null
	return trail_pool.pop_back()


func _acquire_bubble():
	if bubble_pool.is_empty():
		var steal_id := -1
		var lowest := INF
		for id in active_bubbles.keys():
			var b = active_bubbles[id]
			if b.ttl < lowest:
				lowest = b.ttl
				steal_id = id
		if steal_id >= 0:
			var stolen = active_bubbles[steal_id]
			active_bubbles.erase(steal_id)
			stolen.reset_pool()
			return stolen
		return null
	return bubble_pool.pop_back()


func _append_trail(id: int, world: Vector2) -> void:
	if not active_trails.has(id):
		return
	active_trails[id].append_world(world)


func _release_trail(id: int, fade: bool) -> void:
	if not active_trails.has(id):
		return
	var trail = active_trails[id]
	active_trails.erase(id)
	if fade:
		trail.start_fade()
		fading_trails.append(trail)
	else:
		trail.reset_pool()
		trail_pool.append(trail)


func _flight_visual(visitor: Dictionary) -> Vector2:
	var parent = get_parent()
	if parent != null and parent.has_method("get_flight_visual"):
		return parent.get_flight_visual(visitor)
	var duration: float = maxf(0.01, float(visitor.get("flight_duration", 1.0)))
	var t: float = clampf(float(visitor.get("flight_elapsed", 0.0)) / duration, 0.0, 1.0)
	var start: Vector2 = visitor["flight_start"]
	var finish: Vector2 = visitor["flight_end"]
	var ground: Vector2 = _flight_ground(visitor, t)
	var arc: float = sin(PI * t) * minf(105.0, 18.0 + start.distance_to(finish) * 0.26)
	return ground + Vector2(0.0, -arc)


func _flight_ground(visitor: Dictionary, t: float) -> Vector2:
	var start: Vector2 = visitor["flight_start"]
	var finish: Vector2 = visitor["flight_end"]
	var curve: float = float(visitor.get("flight_curve", 0.0))
	var turn: float = float(visitor.get("flight_turn", 0.0))
	var fade: float = float(visitor.get("flight_fade", 0.0))
	var parent = get_parent()
	if parent != null and parent.has_method("get_flight_ground_point"):
		return parent.get_flight_ground_point(start, finish, t, curve, turn, fade)
	return start.lerp(finish, t)


func _flight_heading(visitor: Dictionary, t: float) -> Vector2:
	var t0: float = clampf(t - 0.04, 0.0, 1.0)
	var t1: float = clampf(t + 0.04, 0.0, 1.0)
	var a: Vector2 = _flight_ground(visitor, t0)
	var b: Vector2 = _flight_ground(visitor, t1)
	var delta: Vector2 = b - a
	if delta.length_squared() < 0.001:
		delta = (visitor["flight_end"] as Vector2) - (visitor["flight_start"] as Vector2)
	return delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT
