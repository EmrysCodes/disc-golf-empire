# Disc Golf Empire - Update 43: shared tree records for visuals + collision.
# Update 42 altitude/crown/trunk collision retained; dimensions come from
# PropertyManager tree_records (no position-hash get_tree_dimensions).
# Based on the working Update 30 arrival/check-in/navigation system.
extends Node2D

signal visitor_arrived(person_id: int)
signal visitor_departed(person_id: int)

const MAX_VISITORS := 8
const MAX_GROUP_SIZE := 4
const GROUP_ASSEMBLY_SECONDS := 8.0
const PARTNER_WAIT_SECONDS := 1.5
const TEE_PREPARE_SECONDS := 2.2
const BETWEEN_SHOTS_SECONDS := 1.0
const CHECKIN_SECONDS := 2.0
const FEEDBACK_SECONDS := 3.0
const WALK_SPEED := 19.0
const CAR_SPEED := 95.0
const PARK_SECONDS := 2.0
const SPAWN_INTERVAL := 14.0
const THROW_INTERVAL := 1.6
const MAX_STROKES := 12
const FEET_PER_PIXEL := 15.0 / 32.0
const PUTT_RANGE_PIXELS := 42.0
# Gameplay-scale putting: 8 px is about 3.75 feet.
# Shot-planning candidate angles are relative to the intended fairway line.
const SHOT_CANDIDATE_ANGLES := [0.0, -12.0, 12.0, -25.0, 25.0, -40.0, 40.0, -60.0, 60.0, -85.0, 85.0]
const SHOT_CANDIDATE_POWERS := [1.0, 0.72, 0.46, 0.28]
const RECOVERY_MIN_ADVANCE := 18.0
const TAP_IN_RANGE_PIXELS := 8.0
const CLOSE_PUTT_RANGE_PIXELS := 22.0
const STANDSTILL_BASE_FEET := 95.0
const STANDSTILL_MIN_FEET := 55.0
const STANDSTILL_MAX_FEET := 140.0
# Long enough for Kenney throw/putt strips to play through (not a one-frame blink).
const STANDSTILL_SECONDS := 0.72
const RUNUP_SECONDS := 1.15
const GROUP_WAIT_RADIUS := 25.0
const TEE_QUEUE_BACK := 56.0
const TEE_QUEUE_LATERAL := 96.0
const TEE_QUEUE_DEPTH := 38.0
const CHECKIN_SLOT_SPACING := 44.0
const BASKET_WAIT_RADIUS := 36.0
const GROUP_WAIT_SPACING := 20.0
const FLIGHT_MIN_SECONDS := 0.65
const FLIGHT_MAX_SECONDS := 2.3
# ~38 ft apex at FEET_PER_PIXEL. Update 43 keeps this arc: tall trees (up to
# ~70 ft) are not clearable by height alone — players must miss crown laterally.
# See PropertyManager tree-record comments for the design decision.
const FLIGHT_ARC_PIXELS := 82.0
# Presentation-only lift so longer flights read with clearer arcs; collision
# still uses the FLIGHT_ARC_PIXELS estimate in find_curved_tree_contact.
const VISUAL_ARC_SCALE := 1.28
const FLIGHT_SHADOW_ALPHA := 0.26
const FLIGHT_DISC_RADIUS := 4.0
const SAVE_PATH := "user://dge_people_v1.json"
const FIRST_NAMES := ["Ethan", "Morgan", "Avery", "Taylor", "Riley", "Jordan", "Casey", "Alex", "Jamie", "Quinn", "Parker", "Rowan", "Sam", "Cameron"]
const LAST_NAMES := ["Brooks", "Reed", "Morgan", "Walker", "Parker", "Bennett", "Hayes", "Rivera", "Turner", "Ellis", "Stone", "Miller"]
const SKILLS := ["power", "accuracy", "putting", "control", "course_iq", "composure"]
const PALETTE := [Color("5e9ec7"), Color("d59c64"), Color("b46d9b"), Color("81b36c"), Color("cf8d72"), Color("847dc2")]
const ActorVisualLayerScript = preload("res://visuals/actor_visual_layer.gd")
# 2.5D presentation: screen-up (−Y) = altitude; actors y-sorted by world Y.
const USE_SPRITE_ACTORS := true

var property_manager
var course_manager
var path_manager
var navigation_manager
var people: Dictionary = {}
var visitors: Array = []
var next_person_id: int = 1
var next_membership_number: int = 10001
var spawn_timer: float = 2.0
var next_group_id: int = 1
var last_feedback: String = ""
# One active throw per twosome; tracks whose turn it is on the current hole.
var group_turns: Dictionary = {}
# One active group per hole; queued groups may wait at the tee.
var hole_owners: Dictionary = {}
var group_sizes: Dictionary = {}
# All gameplay destinations use PROPERTY-LOCAL coordinates.
var course_locations: Dictionary = {}
const DEBUG_DESTINATIONS := false
var render_timer: float = 0.0
var visual_time: float = 0.0
var visual_positions: Dictionary = {}
const VISUAL_FOLLOW_RATE := 11.0
var rng := RandomNumberGenerator.new()
var profile_layer: CanvasLayer
var profile_panel: PanelContainer
var profile_label: Label
var selected_id: int = -1
var visual_layer: Node2D

func setup(property_ref, course_ref, path_ref) -> void:
	property_manager = property_ref
	course_manager = course_ref
	path_manager = path_ref
	# Reuse the grounds crew's obstacle-aware, path-preferring navigation.
	navigation_manager = get_parent().get_node_or_null("JobManager")
	z_index = 4
	y_sort_enabled = true
	rng.randomize()
	load_people()
	build_profile()
	if USE_SPRITE_ACTORS:
		visual_layer = ActorVisualLayerScript.new()
		add_child(visual_layer)
		visual_layer.setup(property_manager)
	for arg in OS.get_cmdline_user_args():
		if str(arg).find("demo_visuals") >= 0:
			call_deferred("_boot_demo_visuals")
			break
	set_process(true)


func _boot_demo_visuals() -> void:
	# Anim showcase: walk → prepare → run-up/throw → disc flight (readable time scale).
	spawn_timer = 0.05
	Engine.time_scale = 1.35
	if completed_holes().is_empty() and course_manager != null and property_manager != null:
		if course_manager.has_method("generate_starter_layout"):
			course_manager.generate_starter_layout(property_manager)
		refresh_course_locations()
		if get_parent() != null and get_parent().has_node("CourseRenderer"):
			var renderer = get_parent().get_node("CourseRenderer")
			if renderer.has_method("refresh"):
				renderer.refresh()
			elif "redraw_requested" in renderer:
				renderer.redraw_requested = true
	await get_tree().create_timer(0.25).timeout
	spawn_visitor()
	var focus_world: Vector2 = Vector2.ZERO
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		var holes: Array = visitor["holes"]
		if holes.is_empty():
			continue
		var hole_index: int = int(holes[0])
		visitor["checked_in"] = true
		visitor["tee_ready"] = true
		visitor["disc_position"] = hole_local(hole_index, "tee")
		visitor["car_position"] = visitor["parking_slot"]
		hole_owners[hole_index] = int(visitor["group_id"])
		group_turns[int(visitor["group_id"])] = int(get_group_members(visitor)[0]["id"])
	# Beat 1 — walk toward tee so walk cycle is visible.
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		var holes: Array = visitor["holes"]
		if holes.is_empty():
			continue
		var hole_index: int = int(holes[0])
		var tee_slot: Vector2 = get_tee_queue_slot(hole_index, visitor, tee_queue_rank_for(visitor, hole_index))
		var start_pos: Vector2 = tee_slot + Vector2(-70.0 - float(int(visitor["id"]) % 3) * 18.0, 28.0)
		visitor["position"] = start_pos
		visual_positions[int(visitor["id"])] = start_pos
		visitor["stage"] = "walking_to_tee"
		visitor["wait"] = 0.0
		set_destination(visitor, tee_slot)
		set_thought(visitor, "Walking to tee")
		focus_world = property_manager.property_local_to_world(tee_slot)
	var camera = get_parent().get_node_or_null("CameraController")
	if camera != null and focus_world != Vector2.ZERO:
		camera.position = focus_world
		camera.zoom = Vector2(1.55, 1.55)
	await get_tree().create_timer(1.35).timeout
	# Beat 2 — thrower prepares on pad; partners idle in spaced queue.
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		var holes: Array = visitor["holes"]
		if holes.is_empty():
			continue
		var hole_index: int = int(holes[0])
		if int(visitor["id"]) == get_group_turn(visitor):
			visitor["stage"] = "throwing"
			visitor["active_thrower"] = true
			visitor["wait"] = 1.1
			visitor["position"] = get_tee_throw_stance(hole_index)
			set_thought(visitor, "Tee's ours")
		else:
			visitor["stage"] = "waiting_group"
			visitor["active_thrower"] = false
			visitor["wait"] = 0.0
			visitor["position"] = get_tee_queue_slot(hole_index, visitor, 0)
			set_thought(visitor, "Waiting my turn")
		visual_positions[int(visitor["id"])] = visitor["position"]
	await get_tree().create_timer(1.2).timeout
	# Beat 3 — natural run-up → throw → disc_flying (do not skip anim wait).
	for visitor_value in visitors:
		var shooter: Dictionary = visitor_value
		if str(shooter["stage"]) != "throwing":
			continue
		if int(shooter["id"]) != get_group_turn(shooter):
			continue
		shooter["tee_ready"] = true
		shooter["shot_style"] = "Run-up"
		shooter["stage"] = "run_up"
		shooter["shot_animation_total"] = RUNUP_SECONDS
		shooter["wait"] = RUNUP_SECONDS
		set_thought(shooter, "Run-up…")
		break
	queue_redraw()

func get_entrance_local() -> Vector2:
	# Roadside entrance is the outermost point of the property's connected driveway.
	if property_manager.property_driveway_points.size() > 0:
		var points: Array = property_manager.property_driveway_points
		return property_manager.world_to_property_local(points[0])
	return property_manager.get_property_local_center()

func get_parking_local() -> Vector2:
	var facility: Dictionary = property_manager.get_starter_facility("starter_parking")
	if not facility.is_empty():
		return property_manager.world_to_property_local(facility["position"])
	if property_manager.property_driveway_points.size() > 0:
		var points: Array = property_manager.property_driveway_points
		return property_manager.world_to_property_local(points[points.size() - 1])
	return property_manager.get_property_local_center()

func get_checkin_local() -> Vector2:
	# Starter office position is world-space; golfer destinations are property-local.
	var office: Dictionary = property_manager.get_starter_facility("starter_office")
	if not office.is_empty():
		var office_local: Vector2 = property_manager.world_to_property_local(office["position"])
		# Stand just outside the office entrance rather than inside its footprint.
		var office_size: Vector2 = office.get("size", Vector2(52.0, 64.0))
		return clamp_to_property(office_local + Vector2(office_size.x * 0.5 + 10.0, 0.0))
	return get_parking_local()


func group_member_rank(visitor: Dictionary) -> int:
	var members: Array = get_group_members(visitor)
	for i in range(members.size()):
		if int(members[i]["id"]) == int(visitor["id"]):
			return i
	return 0


func get_checkin_slot(visitor: Dictionary) -> Vector2:
	# Fan along the office frontage so groups never share one pixel.
	var base: Vector2 = get_checkin_local()
	var rank: int = group_member_rank(visitor)
	var group_shift: float = float(int(visitor["group_id"]) % 5) * 10.0
	var lateral: float = (float(rank) - 1.5) * CHECKIN_SLOT_SPACING + group_shift
	return clamp_to_property(base + Vector2(0.0, lateral))


func get_tee_approach(hole_index: int) -> Vector2:
	var tee: Vector2 = hole_local(hole_index, "tee")
	var basket: Vector2 = hole_local(hole_index, "basket")
	var away: Vector2 = (tee - basket).normalized()
	if away.length_squared() < 0.001:
		away = Vector2.DOWN
	return away


func get_tee_queue_slot(hole_index: int, visitor: Dictionary, queue_rank: int = 0) -> Vector2:
	var tee: Vector2 = hole_local(hole_index, "tee")
	var away: Vector2 = get_tee_approach(hole_index)
	var side: Vector2 = Vector2(-away.y, away.x)
	var rank: int = group_member_rank(visitor)
	var members_n: int = maxi(1, get_group_members(visitor).size())
	var center: float = (float(members_n) - 1.0) * 0.5
	# Diagonal fan: wide lateral + staggered depth so large sprites don't overlap.
	var back: float = TEE_QUEUE_BACK + float(queue_rank) * 40.0 + float(rank) * TEE_QUEUE_DEPTH
	var lateral: float = (float(rank) - center) * TEE_QUEUE_LATERAL
	return clamp_to_property(tee + away * back + side * lateral)


func get_tee_throw_stance(hole_index: int) -> Vector2:
	var tee: Vector2 = hole_local(hole_index, "tee")
	return clamp_to_property(tee + get_tee_approach(hole_index) * 10.0)


func get_basket_wait_slot(hole_index: int, visitor: Dictionary) -> Vector2:
	var basket: Vector2 = hole_local(hole_index, "basket")
	var tee: Vector2 = hole_local(hole_index, "tee")
	var away: Vector2 = (basket - tee).normalized()
	if away.length_squared() < 0.001:
		away = Vector2.UP
	var side: Vector2 = Vector2(-away.y, away.x)
	var rank: int = group_member_rank(visitor)
	var sign: float = -1.0 if rank % 2 == 0 else 1.0
	var ring: float = BASKET_WAIT_RADIUS + float(int(rank / 2)) * 12.0
	return clamp_to_property(basket + away * 14.0 + side * sign * ring)


func tee_queue_rank_for(visitor: Dictionary, hole_index: int) -> int:
	var owner: int = int(hole_owners.get(hole_index, -1))
	if owner == -1 or owner == int(visitor["group_id"]):
		return 0
	var seen: Dictionary = {}
	var order: Array = []
	for value in visitors:
		var other: Dictionary = value
		if int(other["holes"][int(other["hole_cursor"])]) != hole_index:
			continue
		if str(other["stage"]) not in ["walking_to_tee", "waiting_at_tee"]:
			continue
		var gid: int = int(other["group_id"])
		if seen.has(gid):
			continue
		seen[gid] = true
		order.append(gid)
	var idx: int = order.find(int(visitor["group_id"]))
	return maxi(1, idx)


func get_parking_slot(slot_index: int) -> Vector2:
	# Eight compact parking positions arranged in two rows.
	var center: Vector2 = get_parking_local()
	var facility: Dictionary = property_manager.get_starter_facility("starter_parking")
	var size: Vector2 = facility.get("size", Vector2(140.0, 120.0))
	var column: int = slot_index % 4
	var row: int = int(slot_index / 4)
	return center + Vector2(
		(float(column) - 1.5) * size.x * 0.22,
		(-0.23 if row == 0 else 0.23) * size.y
	)


func occupied_parking_slots() -> Dictionary:
	var used: Dictionary = {}
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		used[int(visitor.get("slot_index", -1))] = true
	return used


func get_group_members(visitor: Dictionary) -> Array:
	var result: Array = []
	for value in visitors:
		var member: Dictionary = value
		if int(member["group_id"]) == int(visitor["group_id"]):
			result.append(member)
	result.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return result

func group_all_at_stage(visitor: Dictionary, required_stage: String) -> bool:
	var members: Array = get_group_members(visitor)
	if members.size() != int(group_sizes.get(int(visitor["group_id"]), 0)):
		return false
	for member in members:
		if str(member["stage"]) != required_stage:
			return false
	return true

func group_ready_for_tee(visitor: Dictionary) -> bool:
	return group_all_at_stage(visitor, "waiting_at_tee")

func get_group_turn(visitor: Dictionary) -> int:
	var group_id: int = int(visitor["group_id"])
	if not group_turns.has(group_id):
		var members: Array = get_group_members(visitor)
		group_turns[group_id] = int(members[0]["id"]) if not members.is_empty() else int(visitor["id"])
	return int(group_turns[group_id])

func may_throw(visitor: Dictionary) -> bool:
	var hole_index: int = int(visitor["holes"][int(visitor["hole_cursor"])])
	if int(hole_owners.get(hole_index, -1)) != int(visitor["group_id"]):
		return false
	var members: Array = get_group_members(visitor)
	for member in members:
		if str(member["stage"]) == "disc_flying":
			return false
	if int(visitor["strokes"]) == 0:
		for member in members:
			if not bool(member.get("tee_ready", false)):
				return false
		return get_group_turn(visitor) == int(visitor["id"])
	return bool(visitor.get("lie_ready", false)) and bool(visitor.get("active_thrower", false))

func finish_throw_turn(visitor: Dictionary) -> void:
	var members: Array = get_group_members(visitor)
	for index in range(members.size()):
		if int(members[index]["id"]) == int(visitor["id"]):
			group_turns[int(visitor["group_id"])] = int(members[(index + 1) % members.size()]["id"])
			return

func coordinate_group_lies() -> void:
	var visited: Dictionary = {}
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		var gid: int = int(visitor["group_id"])
		if visited.has(gid):
			continue
		visited[gid] = true
		var members: Array = get_group_members(visitor)
		if members.size() != int(group_sizes.get(gid, 0)):
			continue
		var all_ready: bool = true
		var any_remaining: bool = false
		for member in members:
			if int(member["hole_cursor"]) != int(visitor["hole_cursor"]):
				all_ready = false
			if str(member["stage"]) not in ["waiting_group", "waiting_at_basket"]:
				all_ready = false
			if int(member["strokes"]) == 0:
				all_ready = false
			if str(member["stage"]) != "waiting_at_basket":
				any_remaining = true
		if not all_ready or not any_remaining:
			continue
		var hole_index: int = int(visitor["holes"][int(visitor["hole_cursor"])])
		var basket: Vector2 = hole_local(hole_index, "basket")
		var shooter: Dictionary = {}
		var farthest: float = -1.0
		for member in members:
			if str(member["stage"]) == "waiting_at_basket":
				continue
			var distance: float = (member["disc_position"] as Vector2).distance_to(basket)
			if distance > farthest:
				farthest = distance
				shooter = member
		if shooter.is_empty():
			continue
		set_thought(shooter, "Away throws first")
		var lie: Vector2 = shooter["disc_position"]
		var away: Vector2 = (lie - basket).normalized()
		if away.length_squared() < 0.001:
			away = Vector2.DOWN
		var side: Vector2 = Vector2(-away.y, away.x)
		var waiting_index: int = 0
		for member in members:
			if str(member["stage"]) == "waiting_at_basket":
				continue
			var is_shooter: bool = int(member["id"]) == int(shooter["id"])
			member["lie_ready"] = false
			member["active_thrower"] = is_shooter
			member["stage"] = "walking_group_lie"
			var destination: Vector2 = lie
			if not is_shooter:
				var sign: float = -1.0 if waiting_index % 2 == 0 else 1.0
				var rank: int = int(waiting_index / 2)
				var angle: float = deg_to_rad(28.0 + float(rank) * 15.0)
				destination += (away * cos(angle) + side * sin(angle) * sign) * (GROUP_WAIT_RADIUS + float(rank) * GROUP_WAIT_SPACING)
				waiting_index += 1
				set_thought(member, "Walk to the lie")
			set_destination(member, destination)

func group_ready_for_next_hole(visitor: Dictionary) -> bool:
	return group_all_at_stage(visitor, "waiting_at_basket")

func move_group_to_next_hole(visitor: Dictionary) -> void:
	if not group_ready_for_next_hole(visitor):
		return
	var members: Array = get_group_members(visitor)
	var cursor: int = int(visitor["hole_cursor"])
	var completed_hole: int = int(visitor["holes"][cursor])
	if int(hole_owners.get(completed_hole, -1)) == int(visitor["group_id"]):
		hole_owners.erase(completed_hole)
	group_turns.erase(int(visitor["group_id"]))
	var latest_holes: Array = completed_holes()
	refresh_course_locations()
	for member in members:
		var itinerary: Array = member["holes"]
		for candidate in latest_holes:
			if not itinerary.has(candidate):
				itinerary.append(candidate)
		itinerary.sort()
		member["holes"] = itinerary
		member["tee_ready"] = false
		member["strokes"] = 0
		member["hole_cursor"] = cursor + 1
		if cursor + 1 < itinerary.size():
			var next_hole: int = int(itinerary[cursor + 1])
			member["stage"] = "walking_to_tee"
			set_destination(member, get_tee_queue_slot(next_hole, member, tee_queue_rank_for(member, next_hole)))
		else:
			member["stage"] = "feedback"
			member["wait"] = FEEDBACK_SECONDS
			record_round(member)

func record_round(visitor: Dictionary) -> void:
	if bool(visitor.get("round_recorded", false)):
		return
	visitor["round_recorded"] = true
	var person: Dictionary = people[int(visitor["id"])]
	person["visits"] = int(person["visits"]) + 1
	var scores: Dictionary = visitor["round_scores"]
	var total_strokes: int = 0
	var total_par: int = 0
	for result_value in scores.values():
		var result: Dictionary = result_value
		total_strokes += int(result["strokes"])
		total_par += int(result["par"])
	var feedback: String = "Enjoyed playing %d available holes with my group." % scores.size()
	if float(visitor["off_path"]) > float(visitor["walked"]) * 0.55:
		feedback = "Fun round with my group, but the walking routes need improvement."
	person["feedback"].append(feedback)
	person["history"].append({"holes": scores.size(), "scores": scores.duplicate(true), "strokes": total_strokes, "par": total_par, "feedback": feedback})
	last_feedback = "%s: %s" % [str(person["name"]), feedback]
	save_people()


func get_driveway_route(to_parking: bool, parking_slot: Vector2) -> Array:
	var route: Array = []
	for world_point in property_manager.property_driveway_points:
		route.append(property_manager.world_to_property_local(world_point))
	if not to_parking:
		route.reverse()
		route.push_front(parking_slot)
	else:
		route.append(parking_slot)
	return route

func refresh_course_locations() -> void:
	# CourseManager stores tee and basket coordinates in property-local space.
	# Never convert these a second time.
	course_locations.clear()
	course_locations["entrance"] = get_entrance_local()
	course_locations["parking"] = get_parking_local()
	course_locations["checkin"] = get_checkin_local()
	for i in range(course_manager.holes.size()):
		if not course_manager.is_hole_complete(i):
			continue
		var hole: Dictionary = course_manager.get_hole(i)
		course_locations[i] = {
			"tee": hole["tee"],
			"basket": hole["basket"],
			"path_points": hole.get("path_points", [])
		}


func completed_holes() -> Array:
	var result: Array = []
	for i in range(course_manager.holes.size()):
		if course_manager.is_hole_complete(i):
			result.append(i)
	return result

func make_person() -> Dictionary:
	var person_id: int = next_person_id
	next_person_id += 1
	var registered: bool = rng.randf() < 0.28
	var professional: bool = registered and rng.randf() < 0.09
	var skills: Dictionary = {}
	for skill in SKILLS:
		var baseline: int = 57 if registered else 43
		skills[skill] = clampi(baseline + rng.randi_range(-22, 22) + (19 if professional else 0), 10, 99)
	var number: int = -1
	if registered:
		number = next_membership_number
		next_membership_number += 1
	var person: Dictionary = {
		"id": person_id,
		"name": "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]],
		"age": rng.randi_range(16, 69),
		"handedness": "Left" if rng.randf() < 0.12 else "Right",
		"personality": ["Patient", "Competitive", "Curious", "Social", "Methodical"][rng.randi_range(0, 4)],
		"appearance": rng.randi_range(0, PALETTE.size() - 1),
		"skills": skills,
		"membership_number": number,
		"classification": "Professional" if professional else ("Amateur" if registered else "Recreational"),
		"visits": 0,
		"holes_visited": 0,
		"feedback": [],
		"history": []
	}
	people[person_id] = person
	save_people()
	return person

func spawn_visitor() -> void:
	# Admit a group of 1-4 with capacity for eight visitors total.
	refresh_course_locations()
	var holes: Array = completed_holes()
	if holes.is_empty() or visitors.size() >= MAX_VISITORS:
		return
	var used: Dictionary = occupied_parking_slots()
	var available: Array = []
	for slot_index in range(MAX_VISITORS):
		if not used.has(slot_index):
			available.append(slot_index)
	if available.is_empty():
		return
	var group_size: int = mini(rng.randi_range(1, MAX_GROUP_SIZE), available.size())
	var group_id: int = next_group_id
	next_group_id += 1
	group_sizes[group_id] = group_size
	var group: Array = []
	for index in range(group_size):
		var person: Dictionary = make_person()
		var start: Vector2 = get_entrance_local()
		var slot_index: int = int(available[index])
		var slot: Vector2 = get_parking_slot(slot_index)
		var visitor: Dictionary = {
			"id": int(person["id"]), "position": start,
			"state": "arriving", "holes": holes.duplicate(),
			"hole_cursor": 0, "stage": "driving_in",
			"group_id": group_id, "partner_id": -1, "slot_index": slot_index,
			"parking_slot": slot, "car_position": start,
			"route": get_driveway_route(true, slot), "route_index": 0,
			"wait": float(index) * 1.7, "walked": 0.0, "off_path": 0.0,
			"route_distance": 0.0, "strokes": 0, "round_scores": {},
			"disc_position": start, "last_throw": "", "throw_wait": 0.0,
			"round_recorded": false, "destination": slot, "destination_kind": "parking",
			"tee_ready": false, "shot_pause": 0.0, "checked_in": false,
			"flight_start": start, "flight_end": start, "flight_elapsed": 0.0,
			"flight_duration": 0.0, "flight_sunk": false,
			"flight_curve": 0.0, "flight_turn": 0.0, "flight_fade": 0.0,
			"shot_style": "Standstill", "shot_animation_total": 0.0,
			"lie_ready": false, "active_thrower": false
		}
		group.append(visitor)
	for visitor in group:
		visitors.append(visitor)
		visitor_arrived.emit(int(visitor["id"]))


func hole_local(index: int, which: String) -> Vector2:
	# Single source of truth: all cached hole locations are property-local.
	if not course_locations.has(index):
		refresh_course_locations()
	if course_locations.has(index):
		return course_locations[index].get(which, Vector2.ZERO)
	return Vector2.ZERO

func _process(delta: float) -> void:
	if property_manager == null:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		spawn_visitor()
	# Process a snapshot because visitors can depart during this frame.
	for value in visitors.duplicate():
		var visitor: Dictionary = value
		if not visitors.has(visitor):
			continue
		if float(visitor["wait"]) > 0.0:
			visitor["wait"] = maxf(0.0, float(visitor["wait"]) - delta)
			continue
		var stage: String = str(visitor["stage"])
		match stage:
			"driving_in", "driving_out":
				if advance_vehicle(visitor, delta):
					advance_stage(visitor)
			"waiting_partner":
				set_thought(visitor, "Waiting on partner")
				visitor["stage"] = "walking_to_checkin"
				set_destination(visitor, get_checkin_slot(visitor))
			"waiting_at_checkin":
				if group_all_at_stage(visitor, "waiting_at_checkin"):
					for member in get_group_members(visitor):
						member["checked_in"] = true
						member["stage"] = "walking_to_tee"
						set_thought(member, "Checked in — to the tee")
						var first_hole: int = int(member["holes"][0])
						set_destination(member, get_tee_queue_slot(first_hole, member, tee_queue_rank_for(member, first_hole)))
			"waiting_at_tee":
				if bool(visitor.get("checked_in", false)) and group_ready_for_tee(visitor):
					var hole_index: int = int(visitor["holes"][int(visitor["hole_cursor"])])
					var owner: int = int(hole_owners.get(hole_index, -1))
					if owner == -1 or owner == int(visitor["group_id"]):
						hole_owners[hole_index] = int(visitor["group_id"])
						var turn_id: int = get_group_turn(visitor)
						for member in get_group_members(visitor):
							member["tee_ready"] = true
							member["disc_position"] = hole_local(hole_index, "tee")
							if int(member["id"]) == turn_id:
								member["stage"] = "throwing"
								member["wait"] = TEE_PREPARE_SECONDS
								member["position"] = get_tee_throw_stance(hole_index)
								member["active_thrower"] = true
								set_thought(member, "Tee's ours")
							else:
								# Stay in a spaced queue — never share the thrower's pad.
								member["stage"] = "waiting_group"
								member["active_thrower"] = false
								member["lie_ready"] = false
								member["position"] = get_tee_queue_slot(hole_index, member, 0)
								set_thought(member, "Waiting my turn", 1.8)
							visual_positions[int(member["id"])] = member["position"]
					else:
						# Keep queued groups spaced behind the active group.
						var qrank: int = tee_queue_rank_for(visitor, hole_index)
						var spaced: Vector2 = get_tee_queue_slot(hole_index, visitor, qrank)
						if visitor["position"].distance_to(spaced) > 8.0:
							set_destination(visitor, spaced)
						set_thought(visitor, "Tee queue…")
			"waiting_group":
				# Tee-order promotion: next thrower leaves the spaced queue for the pad.
				if int(visitor["strokes"]) == 0 and bool(visitor.get("tee_ready", false)):
					if get_group_turn(visitor) == int(visitor["id"]) and may_throw(visitor):
						var promote_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
						visitor["stage"] = "throwing"
						visitor["active_thrower"] = true
						visitor["position"] = get_tee_throw_stance(promote_hole)
						visual_positions[int(visitor["id"])] = visitor["position"]
						visitor["wait"] = BETWEEN_SHOTS_SECONDS
						set_thought(visitor, "My tee")
					else:
						var hold_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
						var hold_slot: Vector2 = get_tee_queue_slot(hold_hole, visitor, tee_queue_rank_for(visitor, hold_hole))
						visitor["position"] = hold_slot
						visual_positions[int(visitor["id"])] = hold_slot
			"waiting_group_lie":
				var members: Array = get_group_members(visitor)
				var all_arrived: bool = true
				for member in members:
					if str(member["stage"]) not in ["waiting_group_lie", "waiting_at_basket"]:
						all_arrived = false
				if all_arrived:
					for member in members:
						if str(member["stage"]) == "waiting_at_basket":
							continue
						member["stage"] = "throwing" if bool(member.get("active_thrower", false)) else "waiting_group"
						member["lie_ready"] = bool(member.get("active_thrower", false))
						member["wait"] = BETWEEN_SHOTS_SECONDS
						if bool(member.get("active_thrower", false)):
							set_thought(member, "My lie")
						else:
							set_thought(member, "Give them room")
			"waiting_at_basket":
				if group_ready_for_next_hole(visitor):
					move_group_to_next_hole(visitor)
			"feedback":
				visitor["stage"] = "walking_to_car"
				set_destination(visitor, visitor["parking_slot"])
			"navigation_blocked":
				# Don't wander: retry the actual current objective.
				set_thought(visitor, "Path blocked — rerouting")
				visitor["wait"] = 4.0
				if int(visitor["hole_cursor"]) >= visitor["holes"].size():
					visitor["stage"] = "walking_to_car"
					set_destination(visitor, visitor["parking_slot"])
				elif str(visitor.get("blocked_goal", "")) == "basket":
					visitor["stage"] = "walking_to_basket"
					set_destination(visitor, get_basket_wait_slot(int(visitor["holes"][int(visitor["hole_cursor"])]), visitor))
				elif str(visitor.get("blocked_goal", "")) == "lie":
					visitor["stage"] = "walking_to_lie"
					set_destination(visitor, visitor["disc_position"])
				else:
					var retry_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
					visitor["stage"] = "walking_to_tee"
					set_destination(visitor, get_tee_queue_slot(retry_hole, visitor, tee_queue_rank_for(visitor, retry_hole)))
			"throwing":
				if may_throw(visitor):
					var hole_index: int = int(visitor["holes"][int(visitor["hole_cursor"])])
					# Active thrower stands on the pad, not in the queue pile.
					visitor["position"] = get_tee_throw_stance(hole_index) if int(visitor["strokes"]) == 0 else visitor["position"]
					if int(visitor["strokes"]) == 0:
						visual_positions[int(visitor["id"])] = visitor["position"]
					var distance_feet: float = (visitor["disc_position"] as Vector2).distance_to(hole_local(hole_index, "basket")) * FEET_PER_PIXEL
					var golfer: Dictionary = people[int(visitor["id"])]
					var skills: Dictionary = golfer["skills"]
					var standstill_range: float = clampf(STANDSTILL_BASE_FEET + (float(skills["control"]) - 50.0) * 0.5, STANDSTILL_MIN_FEET, STANDSTILL_MAX_FEET)
					var standstill: bool = distance_feet <= standstill_range
					visitor["shot_style"] = "Standstill" if standstill else "Run-up"
					visitor["stage"] = "standstill" if standstill else "run_up"
					visitor["shot_animation_total"] = STANDSTILL_SECONDS if standstill else RUNUP_SECONDS
					visitor["wait"] = float(visitor["shot_animation_total"])
					var remain_px: float = (visitor["disc_position"] as Vector2).distance_to(hole_local(hole_index, "basket"))
					if remain_px <= PUTT_RANGE_PIXELS:
						set_thought(visitor, "Putting…")
					elif standstill:
						set_thought(visitor, "Standstill…")
					else:
						set_thought(visitor, "Run-up…")
				else:
					# Hold non-throwers in their queue slots instead of stacking on the pad.
					if int(visitor["strokes"]) == 0:
						var wait_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
						var slot: Vector2 = get_tee_queue_slot(wait_hole, visitor, tee_queue_rank_for(visitor, wait_hole))
						if visitor["position"].distance_to(slot) > 10.0:
							visitor["position"] = slot
							visual_positions[int(visitor["id"])] = slot
					set_thought(visitor, "Clear the fairway…", 1.2)
			"standstill", "run_up":
				perform_throw(visitor)
				finish_throw_turn(visitor)
			"disc_flying":
				visitor["flight_elapsed"] = minf(float(visitor["flight_duration"]), float(visitor["flight_elapsed"]) + delta)
				if float(visitor["flight_elapsed"]) >= float(visitor["flight_duration"]):
					complete_flight(visitor)
			"parking":
				advance_stage(visitor)
			"walking_to_checkin", "walking_to_tee", "walking_to_lie", "walking_group_lie", "walking_to_basket", "walking_to_car":
				# Never freeze navigation because partners are too far apart.
				# Synchronization happens at check-in, tees, and baskets.
				if advance_visitor(visitor, delta):
					advance_stage(visitor)
	coordinate_group_lies()
	visual_time += delta
	update_visual_positions(delta)
	sync_actor_visuals(delta)
	render_timer += delta
	if render_timer >= 1.0 / 30.0:
		render_timer = 0.0
		queue_redraw()


func clamp_to_property(point: Vector2) -> Vector2:
	var size: Vector2 = property_manager.get_property_size_pixels()
	var inset: float = property_manager.CELL_SIZE * 0.6
	return Vector2(clampf(point.x, inset, size.x - inset), clampf(point.y, inset, size.y - inset))

func route_on_property(start: Vector2, finish: Vector2) -> Array:
	var safe_finish: Vector2 = clamp_to_property(finish)
	if start.distance_to(safe_finish) <= 1.0:
		return [safe_finish]
	# Built paths guide walking between facilities and holes. They do not
	# constrain shots or the final approach to a player's lie.
	if path_manager != null:
		return route_via_walkways(start, safe_finish)
	return [safe_finish]


func get_intended_shot_target(hole_index: int, lie: Vector2, basket: Vector2, reach: float, course_iq: float, control: float) -> Vector2:
	# A waypoint is guidance, not a target that must be hit repeatedly.
	# Project the lie onto the authored route, then look FORWARD along it.
	var hole: Dictionary = course_manager.get_hole(hole_index)
	var points: Array = [hole["tee"]]
	for point_value in hole.get("path_points", []):
		if point_value is Vector2 and (points[-1] as Vector2).distance_to(point_value) > 2.0:
			points.append(point_value)
	if (points[-1] as Vector2).distance_to(basket) > 2.0:
		points.append(basket)
	if points.size() < 2:
		return basket
	var cumulative: Array = [0.0]
	for i in range(points.size() - 1):
		cumulative.append(float(cumulative[-1]) + (points[i + 1] as Vector2).distance_to(points[i]))
	var total: float = float(cumulative[-1])
	var nearest_progress: float = 0.0
	var nearest_distance: float = INF
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var finish: Vector2 = points[i + 1]
		var line: Vector2 = finish - start
		var fraction: float = clampf((lie - start).dot(line) / maxf(line.length_squared(), 0.001), 0.0, 1.0)
		var distance: float = lie.distance_squared_to(start.lerp(finish, fraction))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_progress = float(cumulative[i]) + line.length() * fraction
	# Look ahead far enough to prevent tiny repeated throws at a waypoint.
	# More confident players can plan farther along the intended fairway.
	var lookahead: float = maxf(65.0, reach * lerpf(0.48, 0.86, clampf((course_iq + control) / 200.0, 0.0, 1.0)))
	var desired_progress: float = minf(total, nearest_progress + lookahead)
	for i in range(points.size() - 1):
		if desired_progress <= float(cumulative[i + 1]) or i == points.size() - 2:
			var leg: float = float(cumulative[i + 1]) - float(cumulative[i])
			var fraction: float = clampf((desired_progress - float(cumulative[i])) / maxf(leg, 0.001), 0.0, 1.0)
			var target: Vector2 = (points[i] as Vector2).lerp(points[i + 1], fraction)
			# If the player landed off the line, don't repeatedly throw
			# sideways to the same nearby point; advance toward the basket.
			if target.distance_to(lie) < 24.0 and lie.distance_to(basket) > 42.0:
				return basket
			return target
	return basket


func plan_obstacle_aware_shot(visitor: Dictionary, lie: Vector2, basket: Vector2, intended: Vector2, reach: float, course_iq: float, control: float) -> Vector2:
	# Evaluate *possible* throws, not a single waypoint. The designer's
	# route supplies the preferred heading; tree clearance decides safety.
	var preferred: Vector2 = (intended - lie).normalized()
	if preferred.length_squared() < 0.001:
		preferred = (basket - lie).normalized()
	if preferred.length_squared() < 0.001:
		return basket
	var remaining: float = lie.distance_to(basket)
	var previous_hit: bool = str(visitor.get("last_throw", "")) == "Tree hit"
	var old_target: Vector2 = visitor.get("last_shot_target", lie)
	var best_target: Vector2 = intended
	var best_score: float = -INF
	var aggression: float = clampf((course_iq * 0.65 + control * 0.35) / 100.0, 0.0, 1.0)
	for angle_value in SHOT_CANDIDATE_ANGLES:
		var angle: float = float(angle_value)
		var direction: Vector2 = preferred.rotated(deg_to_rad(angle))
		for power_value in SHOT_CANDIDATE_POWERS:
			var fraction: float = float(power_value)
			var length: float = minf(reach * fraction, maxf(remaining * 1.3, 45.0))
			var candidate: Vector2 = clamp_to_property(lie + direction * length)
			var distance: float = lie.distance_to(candidate)
			if distance < RECOVERY_MIN_ADVANCE:
				continue
			var estimated_height: float = minf(FLIGHT_ARC_PIXELS, 14.0 + distance * 0.19)
			# Same shared contact sampler as throws (straight planning line;
			# release shape is unknown at plan time).
			var collision: Dictionary = find_curved_tree_contact(
				lie, candidate, estimated_height, 0.0, 0.0, 0.0
			)
			var hit_fraction: float = float(collision.get("fraction", 1.0))
			var safe_distance: float = distance * hit_fraction
			# Favor progress along the designer's intended fairway, while
			# rewarding a clear line and penalizing a blocked aggressive shot.
			var progress: float = (candidate - lie).dot(preferred)
			var basket_gain: float = remaining - candidate.distance_to(basket)
			var score: float = progress * 0.48 + basket_gain * 0.28
			score += safe_distance * 0.20
			score -= absf(angle) * lerpf(0.28, 0.12, aggression)
			if not collision.is_empty():
				score -= 125.0 + (distance - safe_distance) * 0.75
			# Avoid selecting the same failed line after a tree hit.
			if previous_hit and candidate.distance_to(old_target) < 32.0:
				score -= 180.0
			# A recovery pitch-out can be sideways but should never be
			# preferred over an equally safe forward fairway shot.
			if basket_gain < -25.0:
				score -= 50.0
			if score > best_score:
				best_score = score
				best_target = candidate
	# If all candidates are poor, still select the least-bad route;
	# the actual throw and collision system remain authoritative.
	if previous_hit:
		set_thought(visitor, "Pitch out")
	elif best_target.distance_to(intended) > 28.0:
		set_thought(visitor, "Safer line")
	elif absf((best_target - lie).angle_to(preferred)) > deg_to_rad(18.0):
		set_thought(visitor, "Gap left…")
	else:
		set_thought(visitor, "Aim the fairway", 1.6)
	return best_target


func set_destination(visitor: Dictionary, destination: Vector2) -> void:
	var safe_destination: Vector2 = clamp_to_property(destination)
	visitor["destination"] = safe_destination
	visitor["destination_kind"] = str(visitor.get("stage", ""))
	var stage: String = str(visitor.get("stage", ""))
	var route: Array = route_on_property(visitor["position"], safe_destination) if stage in ["walking_to_tee", "walking_to_checkin", "walking_to_car"] else [safe_destination]
	if route.is_empty():
		# No traversable route: remain in place instead of walking into nowhere.
		visitor["blocked_goal"] = ("basket" if str(visitor["stage"]) == "walking_to_basket" else ("lie" if str(visitor["stage"]) == "walking_to_lie" else "tee"))
		visitor["stage"] = "navigation_blocked"
		visitor["route"] = []
		visitor["route_index"] = 0
		visitor["wait"] = 3.0
		return
	visitor["route"] = route
	visitor["route_index"] = 0
	visitor["route_distance"] = 0.0

func route_via_walkways(start: Vector2, finish: Vector2) -> Array:
	# Build a small connected graph from completed trail segments. Junctions
	# inserted by PathManager become shared graph vertices.
	var nodes: Array = []
	var edges: Dictionary = {}
	var index_by_key: Dictionary = {}
	for trail_value in path_manager.get_completed_trails():
		var trail: Dictionary = trail_value
		var previous: int = -1
		for point_value in trail["points"]:
			var point: Vector2 = point_value
			var key: Vector2i = Vector2i(roundi(point.x * 2.0), roundi(point.y * 2.0))
			if not index_by_key.has(key):
				index_by_key[key] = nodes.size()
				nodes.append(point)
				edges[nodes.size() - 1] = []
			var current: int = int(index_by_key[key])
			if previous >= 0 and previous != current:
				var cost: float = (nodes[previous] as Vector2).distance_to(point)
				edges[previous].append({"to": current, "cost": cost})
				edges[current].append({"to": previous, "cost": cost})
			previous = current
	if nodes.is_empty():
		return [finish]
	# Use the closest walkable trail entry/exit; avoid absurd detours.
	var entry: int = 0
	var exit_node: int = 0
	for n in range(nodes.size()):
		if (nodes[n] as Vector2).distance_to(start) < (nodes[entry] as Vector2).distance_to(start):
			entry = n
		if (nodes[n] as Vector2).distance_to(finish) < (nodes[exit_node] as Vector2).distance_to(finish):
			exit_node = n
	var dist: Dictionary = {entry: 0.0}
	var prev: Dictionary = {}
	var open_nodes: Array = [entry]
	while not open_nodes.is_empty():
		var best: int = 0
		for j in range(1, open_nodes.size()):
			if float(dist[open_nodes[j]]) < float(dist[open_nodes[best]]):
				best = j
		var current: int = int(open_nodes[best])
		open_nodes.remove_at(best)
		if current == exit_node:
			break
		for edge_value in edges[current]:
			var edge: Dictionary = edge_value
			var other: int = int(edge["to"])
			var candidate: float = float(dist[current]) + float(edge["cost"])
			if not dist.has(other) or candidate < float(dist[other]):
				dist[other] = candidate
				prev[other] = current
				if not open_nodes.has(other):
					open_nodes.append(other)
	if not dist.has(exit_node):
		return [finish]
	var total: float = start.distance_to(nodes[entry]) + float(dist[exit_node]) + (nodes[exit_node] as Vector2).distance_to(finish)
	if total > start.distance_to(finish) * 2.5 + 90.0:
		return [finish]
	var indexes: Array = [exit_node]
	var cursor: int = exit_node
	while cursor != entry and prev.has(cursor):
		cursor = int(prev[cursor])
		indexes.push_front(cursor)
	var route: Array = []
	for index_value in indexes:
		route.append(nodes[int(index_value)])
	route.append(finish)
	return route

func advance_vehicle(visitor: Dictionary, delta: float) -> bool:
	var route: Array = visitor["route"]
	var index: int = int(visitor["route_index"])
	if index >= route.size():
		return true
	var target: Vector2 = route[index]
	var current: Vector2 = visitor["position"]
	visitor["position"] = current.move_toward(target, CAR_SPEED * delta)
	visitor["car_position"] = visitor["position"]
	if visitor["position"].distance_to(target) <= 0.1:
		visitor["route_index"] = index + 1
	return int(visitor["route_index"]) >= route.size()

func advance_visitor(visitor: Dictionary, delta: float) -> bool:
	var route: Array = visitor["route"]
	var index: int = int(visitor["route_index"])
	if index >= route.size():
		return false
	var target: Vector2 = route[index]
	var current: Vector2 = visitor["position"]
	var distance: float = current.distance_to(target)
	var travel: float = minf(distance, WALK_SPEED * delta)
	if distance > 0.01:
		visitor["position"] = current.move_toward(target, travel)
	visitor["walked"] = float(visitor["walked"]) + travel
	if route.size() == 1 or index == 0 or index == route.size() - 1:
		visitor["off_path"] = float(visitor["off_path"]) + travel
	if distance <= WALK_SPEED * delta + 0.01:
		visitor["route_index"] = index + 1
	return int(visitor["route_index"]) >= route.size()

# Distances are property-local pixels; 32 px represents 15 real feet.
# A recreational player's drive typically travels farther than the old 24-264 px range.
# This is a gameplay approximation, not a full aerodynamic physics simulation.
# Tree height / crown / trunk come from PropertyManager.tree_records (Update 43).
func tree_intersects_disc(tree_record: Dictionary, disc_ground: Vector2, altitude_pixels: float) -> bool:
	if tree_record.is_empty():
		return false
	var tree: Vector2 = tree_record["position"]
	var height_pixels: float = float(tree_record["height_feet"]) / FEET_PER_PIXEL
	# The crown spans the upper (1 - crown_base_ratio) of the tree; trunk below.
	var crown_base_ratio: float = float(tree_record.get("crown_base_ratio", 0.35))
	var crown_base: float = height_pixels * crown_base_ratio
	var lateral: float = tree.distance_to(disc_ground)
	if altitude_pixels <= height_pixels and altitude_pixels >= crown_base:
		return lateral <= float(tree_record["crown_radius_px"])
	if altitude_pixels < crown_base:
		return lateral <= float(tree_record["trunk_radius_px"])
	return false


func get_flight_ground_point(start: Vector2, finish: Vector2, t: float, curve: float, turn: float, fade: float) -> Vector2:
	var heading: Vector2 = (finish - start).normalized()
	var side: Vector2 = Vector2(-heading.y, heading.x)
	var envelope: float = sin(PI * t)
	var offset: float = curve * envelope + turn * envelope * (1.0 - t) + fade * envelope * t
	return start.lerp(finish, t) + side * offset


func find_tree_contact(start: Vector2, finish: Vector2, flight_height: float) -> Dictionary:
	return find_curved_tree_contact(start, finish, flight_height, 0.0, 0.0, 0.0)


func find_curved_tree_contact(start: Vector2, finish: Vector2, height: float, curve: float, turn: float, fade: float) -> Dictionary:
	if start.distance_squared_to(finish) < 0.01:
		return {}
	if property_manager == null:
		return {}
	# Sample densely enough to avoid tunneling through narrow trunks.
	var steps: int = maxi(24, int(ceilf(start.distance_to(finish) / 4.0)))
	var previous: Vector2 = start
	var records: Array = property_manager.tree_records
	for step in range(1, steps + 1):
		var t: float = float(step) / float(steps)
		var current: Vector2 = get_flight_ground_point(start, finish, t, curve, turn, fade)
		var altitude_pixels: float = sin(PI * t) * height
		for record_value in records:
			var tree_record: Dictionary = record_value
			if tree_intersects_disc(tree_record, current, altitude_pixels):
				return {
					"fraction": t,
					"point": previous,
					"tree": tree_record["position"],
				}
		previous = current
	return {}


func perform_throw(visitor: Dictionary) -> void:
	var holes: Array = visitor["holes"]
	var hole_number: int = int(holes[int(visitor["hole_cursor"])])
	if not course_manager.is_hole_complete(hole_number):
		finish_hole(visitor)
		return
	var person: Dictionary = people[int(visitor["id"])]
	var skills: Dictionary = person["skills"]
	var basket: Vector2 = hole_local(hole_number, "basket")
	var lie: Vector2 = visitor["disc_position"]
	var remaining: float = lie.distance_to(basket)
	var putting: bool = remaining <= PUTT_RANGE_PIXELS
	var accuracy: float = float(skills["putting"] if putting else skills["accuracy"])
	var control: float = float(skills["control"])
	var power: float = float(skills["power"])
	var skill_factor: float = clampf((accuracy + control) / 200.0, 0.1, 1.0)
	# A typical 40-60 power golfer reaches roughly 190-255 feet on a full drive.
	# Higher-power players can reach 300+ feet; approaches scale down near the pin.
	var drive_feet: float = 120.0 + power * 2.15
	var max_reach: float = drive_feet / FEET_PER_PIXEL
	var reach: float = max_reach if not putting else (18.0 + accuracy * 0.36)
	var power_variation: float = lerpf(0.66, 0.92, control / 100.0)
	var course_iq: float = float(skills.get("course_iq", 50))
	var intended: Vector2 = basket if putting else get_intended_shot_target(hole_number, lie, basket, reach, course_iq, control)
	var shot_target: Vector2 = intended if putting else plan_obstacle_aware_shot(visitor, lie, basket, intended, reach, course_iq, control)
	var target_distance: float = lie.distance_to(shot_target)
	var forward: float = minf(target_distance, reach * rng.randf_range(power_variation, 1.05))
	# Never spend full strokes nudging a few pixels toward a path node.
	if not putting and remaining > 55.0 and forward < 28.0:
		shot_target = plan_obstacle_aware_shot(visitor, lie, basket, basket, reach, course_iq, control)
		target_distance = lie.distance_to(shot_target)
		forward = minf(target_distance, reach * rng.randf_range(power_variation, 1.05))
	# Aim toward the selected fairway waypoint, with a skill-based
	# angular release error. Accuracy reduces the angle; control reduces
	# power variation. Flight shape will be a separate later update.
	var direction: Vector2 = (shot_target - lie).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	var max_error_degrees: float = (2.0 if putting else 17.0) * (1.0 - skill_factor) + 0.5
	var release_error: float = deg_to_rad(rng.randf_range(-max_error_degrees, max_error_degrees))
	var aimed_direction: Vector2 = direction.rotated(release_error)
	var nominal_landing: Vector2 = clamp_to_property(lie + aimed_direction * forward)
	# Shot shape is now part of the resulting landing position, rather
	# than a decorative curve that always ends at the nominal target.
	var hand_sign: float = -1.0 if str(person["handedness"]) == "Left" else 1.0
	var shape_choice: int = rng.randi_range(0, 2)
	var release_shape: float = [-1.0, 0.0, 1.0][shape_choice]
	var execution: float = (1.0 - skill_factor) * rng.randf_range(-0.65, 0.65)
	var scale: float = minf(1.0, lie.distance_to(nominal_landing) / 350.0)
	var curve: float = (release_shape + execution) * 75.0 * scale * hand_sign
	var turn: float = -43.0 * scale * hand_sign
	var fade: float = 52.0 * scale * hand_sign
	var landing: Vector2 = nominal_landing
	if not putting:
		var heading: Vector2 = (nominal_landing - lie).normalized()
		var sideways: Vector2 = Vector2(-heading.y, heading.x)
		# A portion of the release shape and late fade survives to ground.
		# Cap sideways drift so this remains playable at the current scale.
		var drift: float = clampf(curve * 0.22 + turn * 0.12 + fade * 0.48, -55.0, 55.0)
		landing = clamp_to_property(nominal_landing + sideways * drift)
	# Check trees against the curved trajectory, not a straight chord.
	var estimated_height: float = minf(FLIGHT_ARC_PIXELS, 14.0 + lie.distance_to(landing) * 0.19)
	var contact: Dictionary = {} if putting else find_curved_tree_contact(lie, landing, estimated_height, curve, turn, fade)
	if not contact.is_empty():
		landing = clamp_to_property(contact["point"])
	if navigation_manager != null:
		var landing_cell: Vector2i = property_manager.world_to_cell(landing)
		var blocked: Dictionary = navigation_manager.build_navigation_blocked_cells(landing_cell, landing_cell)
		if blocked.has(landing_cell):
			var nearby: Vector2i = navigation_manager.find_nearest_walkable_cell(landing_cell, blocked)
			if nearby.x >= 0:
				landing = property_manager.cell_to_world_center(nearby)
	var sunk: bool = false
	if putting:
		# Do not repeatedly miss from directly beneath the basket.
		# Within tap-in range, resolve the stroke as holed out.
		if remaining <= TAP_IN_RANGE_PIXELS:
			sunk = true
		else:
			var distance_ratio: float = clampf((remaining - TAP_IN_RANGE_PIXELS) / (PUTT_RANGE_PIXELS - TAP_IN_RANGE_PIXELS), 0.0, 1.0)
			var skill_ratio: float = clampf(accuracy / 100.0, 0.0, 1.0)
			var putt_chance: float = lerpf(0.96, 0.28 + 0.45 * skill_ratio, distance_ratio)
			if remaining <= CLOSE_PUTT_RANGE_PIXELS:
				putt_chance = maxf(putt_chance, 0.82)
			sunk = rng.randf() < putt_chance
		if not sunk:
			# Missed putts should finish close to the basket, rather
			# than leave a disc almost stationary on the same lie.
			var miss_direction: Vector2 = (landing - basket).normalized()
			if miss_direction.length_squared() < 0.001:
				miss_direction = Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			var miss_distance: float = rng.randf_range(4.0, 12.0 if remaining > CLOSE_PUTT_RANGE_PIXELS else 7.0)
			landing = clamp_to_property(basket + miss_direction * miss_distance)
	elif shot_target.distance_to(basket) < 0.1 and remaining <= reach and skill_factor > 0.85:
		sunk = rng.randf() < 0.015
	if sunk:
		landing = basket
	visitor["strokes"] = int(visitor["strokes"]) + 1
	visitor["last_shot_target"] = shot_target
	visitor["last_throw"] = "Tree hit" if not contact.is_empty() else ("Putt" if putting else ("Drive" if int(visitor["strokes"]) == 1 else "Approach"))
	# On contact the disc stops at the impact point; do not keep a
	# pronounced sideways arc that could visually pass through the tree.
	var contact_scale: float = 0.0 if not contact.is_empty() else 1.0
	visitor["flight_curve"] = 0.0 if putting else curve * contact_scale
	visitor["flight_turn"] = 0.0 if putting else turn * contact_scale
	visitor["flight_fade"] = 0.0 if putting else fade * contact_scale
	visitor["flight_start"] = lie
	visitor["flight_end"] = landing
	visitor["flight_elapsed"] = 0.0
	var travel: float = lie.distance_to(landing)
	visitor["flight_duration"] = clampf(0.5 + travel / 360.0, FLIGHT_MIN_SECONDS, FLIGHT_MAX_SECONDS)
	visitor["flight_sunk"] = sunk or int(visitor["strokes"]) >= MAX_STROKES
	visitor["stage"] = "disc_flying"
	visitor["flight_putting"] = putting
	if not contact.is_empty():
		set_thought(visitor, "Tree!")
	elif putting:
		set_thought(visitor, "Putting…")
	elif int(visitor["strokes"]) == 1:
		set_thought(visitor, "Drive")
	else:
		set_thought(visitor, "Approach")
	if visual_layer != null and visual_layer.has_method("begin_flight_trail"):
		visual_layer.begin_flight_trail(visitor)
	if selected_id == int(visitor["id"]) and profile_panel.visible:
		show_profile(selected_id)


func complete_flight(visitor: Dictionary) -> void:
	var landing: Vector2 = visitor["flight_end"]
	var basket: Vector2 = hole_local(int(visitor["holes"][int(visitor["hole_cursor"])]), "basket")
	if visual_layer != null and visual_layer.has_method("end_flight_trail"):
		visual_layer.end_flight_trail(visitor)
	if bool(visitor["flight_sunk"]):
		visitor["disc_position"] = basket
		set_thought(visitor, "In the basket!")
		# A player who holes out stays behind the next outstanding lie.
		# Do not send them walking past the partner's disc to the basket.
		finish_hole(visitor)
	else:
		visitor["disc_position"] = landing
		visitor["stage"] = "waiting_group"
		visitor["wait"] = THROW_INTERVAL
		if str(visitor.get("last_throw", "")) == "Tree hit":
			set_thought(visitor, "Recovery…")
		else:
			set_thought(visitor, "Lie marked")
		for member in get_group_members(visitor):
			if int(member["id"]) != int(visitor["id"]) and int(member["strokes"]) > 0 and str(member["stage"]) == "throwing":
				member["stage"] = "waiting_group"


func get_flight_visual(visitor: Dictionary) -> Vector2:
	var duration: float = maxf(0.01, float(visitor.get("flight_duration", 1.0)))
	var t: float = clampf(float(visitor.get("flight_elapsed", 0.0)) / duration, 0.0, 1.0)
	var start: Vector2 = visitor["flight_start"]
	var finish: Vector2 = visitor["flight_end"]
	var ground: Vector2 = get_flight_ground_point(start, finish, t, float(visitor.get("flight_curve", 0.0)), float(visitor.get("flight_turn", 0.0)), float(visitor.get("flight_fade", 0.0)))
	# Visual arc only — collision height stays on FLIGHT_ARC_PIXELS estimate.
	var arc: float = sin(PI * t) * minf(FLIGHT_ARC_PIXELS * VISUAL_ARC_SCALE, 18.0 + start.distance_to(finish) * 0.26)
	return ground + Vector2(0.0, -arc)


func finish_hole(visitor: Dictionary) -> void:
	var holes: Array = visitor["holes"]
	var cursor: int = int(visitor["hole_cursor"])
	if cursor >= holes.size():
		return
	var hole_index: int = int(holes[cursor])
	var person: Dictionary = people[int(visitor["id"])]
	var strokes: int = int(visitor["strokes"])
	var par: int = course_manager.calculate_par(course_manager.calculate_hole_distance(hole_index, property_manager.CELL_SIZE))
	visitor["round_scores"][str(hole_index + 1)] = {"strokes": strokes, "par": par}
	person["holes_visited"] = int(person["holes_visited"]) + 1
	visitor["stage"] = "waiting_at_basket"
	var wait_slot: Vector2 = get_basket_wait_slot(hole_index, visitor)
	visitor["position"] = wait_slot
	visual_positions[int(visitor["id"])] = wait_slot
	var relative: int = strokes - par
	if relative <= -1:
		set_thought(visitor, "Under par!")
	elif relative == 0:
		set_thought(visitor, "Hole complete — par")
	else:
		set_thought(visitor, "Hole complete")


func advance_stage(visitor: Dictionary) -> void:
	var holes: Array = visitor["holes"]
	var cursor: int = int(visitor["hole_cursor"])
	var stage: String = str(visitor["stage"])
	match stage:
		"driving_in":
			visitor["stage"] = "parking"
			visitor["wait"] = PARK_SECONDS
			visitor["position"] = visitor["parking_slot"]
			visitor["car_position"] = visitor["parking_slot"]
		"parking":
			visitor["stage"] = "waiting_partner"
		"walking_to_checkin":
			visitor["stage"] = "waiting_at_checkin"
			visitor["wait"] = CHECKIN_SECONDS
		"walking_to_tee":
			visitor["stage"] = "waiting_at_tee"
		"walking_group_lie":
			visitor["stage"] = "waiting_group_lie"
		"walking_to_lie":
			visitor["stage"] = "throwing"
			visitor["wait"] = BETWEEN_SHOTS_SECONDS
		"walking_to_basket":
			finish_hole(visitor)
		"walking_to_car":
			visitor["stage"] = "driving_out"
			visitor["position"] = visitor["parking_slot"]
			visitor["car_position"] = visitor["parking_slot"]
			visitor["route"] = get_driveway_route(false, visitor["parking_slot"])
			visitor["route_index"] = 0
		"driving_out":
			if not bool(visitor.get("round_recorded", false)):
				record_round(visitor)
			visitors.erase(visitor)
			if get_group_members(visitor).is_empty():
				group_turns.erase(int(visitor["group_id"]))
				group_sizes.erase(int(visitor["group_id"]))
			visitor_departed.emit(int(visitor["id"]))
			save_people()


func update_visual_positions(delta: float) -> void:
	# Display-only smoothing: never alter gameplay positions or objectives.
	var active: Dictionary = {}
	for value in visitors:
		var visitor: Dictionary = value
		var id: int = int(visitor["id"])
		active[id] = true
		var target: Vector2 = visitor["position"]
		if not visual_positions.has(id):
			visual_positions[id] = target
		else:
			var previous: Vector2 = visual_positions[id]
			visual_positions[id] = previous.lerp(target, 1.0 - exp(-VISUAL_FOLLOW_RATE * delta))
	for id in visual_positions.keys():
		if not active.has(id):
			visual_positions.erase(id)


func set_thought(visitor: Dictionary, text: String, seconds: float = 2.1) -> void:
	# Real AI decision chatter only — skip repeats while the same thought is live.
	if text.is_empty() or visual_layer == null:
		return
	if str(visitor.get("thought_text", "")) == text and float(visitor.get("thought_ttl", 0.0)) > 0.35:
		return
	visitor["thought_text"] = text
	visitor["thought_ttl"] = seconds
	if visual_layer.has_method("set_thought"):
		visual_layer.set_thought(visitor, text, seconds)


func sync_actor_visuals(delta: float) -> void:
	if visual_layer == null or property_manager == null:
		return
	var live: Dictionary = {}
	for value in visitors:
		var visitor: Dictionary = value
		var id: int = int(visitor["id"])
		live[id] = true
		if float(visitor.get("thought_ttl", 0.0)) > 0.0:
			visitor["thought_ttl"] = maxf(0.0, float(visitor["thought_ttl"]) - delta)
		var person: Dictionary = people[id]
		var stage: String = str(visitor["stage"])
		var local_position: Vector2 = visual_positions.get(id, visitor["position"])
		var world: Vector2 = property_manager.property_local_to_world(local_position)
		var moving: bool = stage.begins_with("walking_")
		var bob: float = sin(visual_time * 11.0 + float(id)) * 1.1 if moving else 0.0
		var body: Vector2 = world + Vector2(0.0, bob)
		var facing_x: float = 1.0
		if visitor.has("destination"):
			facing_x = (visitor["destination"] as Vector2 - local_position).x
		var shot_progress: float = -1.0
		if stage in ["run_up", "standstill", "throwing", "disc_flying"]:
			var current_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
			var basket: Vector2 = hole_local(current_hole, "basket")
			var lie: Vector2 = visitor["disc_position"]
			var heading: Vector2 = (basket - lie).normalized()
			if heading.length_squared() < 0.01:
				heading = Vector2.RIGHT
			facing_x = heading.x
			var anim_total: float = maxf(0.01, float(visitor.get("shot_animation_total", 1.0)))
			shot_progress = 1.0 - clampf(float(visitor["wait"]) / anim_total, 0.0, 1.0)
			if stage == "run_up":
				body += heading * (-16.0 * (1.0 - shot_progress))
				body += Vector2(0.0, sin(shot_progress * PI * 5.0) * 1.6)
			elif stage == "standstill":
				body += heading * (-2.5 + shot_progress * 2.5)
		var putting: bool = bool(visitor.get("flight_putting", false))
		if stage in ["throwing", "standstill", "run_up"] and int(visitor["hole_cursor"]) < visitor["holes"].size():
			var hole_i: int = int(visitor["holes"][int(visitor["hole_cursor"])])
			putting = (visitor["disc_position"] as Vector2).distance_to(hole_local(hole_i, "basket")) <= PUTT_RANGE_PIXELS
		visual_layer.sync_visitor(visitor, person, body, facing_x, putting, shot_progress)
	visual_layer.prune_to_visitors(live)
	visual_layer.tick(delta)


func get_activity_label(stage: String) -> String:
	match stage:
		"parking": return "Parking"
		"waiting_partner": return "Waiting"
		"walking_to_checkin": return "Check-in"
		"waiting_at_checkin": return "Checking in"
		"walking_to_tee": return "To tee"
		"waiting_at_tee": return "Tee queue"
		"throwing": return "Preparing"
		"run_up": return "Run-up"
		"standstill": return "Standstill"
		"waiting_group": return "Waiting for lie"
		"waiting_group_lie": return "At lie"
		"walking_group_lie": return "Walking as group"
		"disc_flying": return "Disc flying"
		"walking_to_lie": return "Retrieving"
		"walking_to_basket": return "Finishing"
		"waiting_at_basket": return "Hole complete"
		"feedback": return "Reviewing"
		"walking_to_car": return "Leaving"
	return ""


func _draw() -> void:
	if property_manager == null:
		return
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		var id: int = int(visitor["id"])
		var person: Dictionary = people[id]
		var stage: String = str(visitor["stage"])
		var local_position: Vector2 = visual_positions.get(id, visitor["position"])
		var world: Vector2 = property_manager.property_local_to_world(local_position)
		var color: Color = PALETTE[int(person["appearance"]) % PALETTE.size()]
		var car_local: Vector2 = visitor.get("car_position", visitor["position"])
		var car_world: Vector2 = property_manager.property_local_to_world(car_local)
		var car_color: Color = color.darkened(0.25)
		# Cars remain parked while their owners play.
		draw_rect(Rect2(car_world - Vector2(10.0, 5.0), Vector2(20.0, 10.0)), Color(0, 0, 0, 0.25), true)
		draw_rect(Rect2(car_world - Vector2(9.0, 7.0), Vector2(18.0, 11.0)), car_color, true)
		draw_rect(Rect2(car_world - Vector2(2.0, 6.0), Vector2(7.0, 9.0)), Color(0.55, 0.75, 0.84, 0.95), true)
		if stage in ["driving_in", "driving_out"]:
			continue
		if DEBUG_DESTINATIONS and visitor.has("destination"):
			var goal_world: Vector2 = property_manager.property_local_to_world(visitor["destination"])
			draw_line(world, goal_world, Color(1.0, 0.8, 0.15, 0.8), 2.0)
			draw_circle(goal_world, 7.0, Color(1.0, 0.8, 0.15, 0.8))
		# Sprite actors + thought bubbles own body/disc/labels when enabled.
		if USE_SPRITE_ACTORS and visual_layer != null:
			if selected_id == id:
				var sel_local: Vector2 = visual_positions.get(id, visitor["position"])
				var sel_world: Vector2 = property_manager.property_local_to_world(sel_local)
				draw_arc(sel_world + Vector2(0, -6), 14.0, 0.0, TAU, 20, Color.WHITE, 1.8)
			continue
		var moving: bool = stage.begins_with("walking_")
		var bob: float = sin(visual_time * 11.0 + float(id)) * 1.1 if moving else 0.0
		var body: Vector2 = world + Vector2(0.0, bob)
		if stage in ["run_up", "standstill"]:
			var current_hole: int = int(visitor["holes"][int(visitor["hole_cursor"])])
			var basket: Vector2 = hole_local(current_hole, "basket")
			var lie: Vector2 = visitor["disc_position"]
			var heading: Vector2 = (basket - lie).normalized()
			if heading.length_squared() < 0.01:
				heading = Vector2.RIGHT
			var total: float = maxf(0.01, float(visitor.get("shot_animation_total", 1.0)))
			var progress: float = 1.0 - clampf(float(visitor["wait"]) / total, 0.0, 1.0)
			if stage == "run_up":
				body += heading * (-16.0 * (1.0 - progress))
				body += Vector2(0.0, sin(progress * PI * 5.0) * 1.6)
			else:
				body += heading * (-2.5 + progress * 2.5)
		draw_ellipse_shadow(body)
		# Fallback stick silhouette if sprite layer is disabled.
		draw_line(body + Vector2(0, -1), body + Vector2(0, 5), color.darkened(0.28), 5.0)
		draw_circle(body + Vector2(0, -2), 5.5, color)
		draw_circle(body + Vector2(0, -9), 4.0, Color("efc49d"))
		if stage in ["throwing", "standstill", "run_up", "disc_flying", "waiting_group", "waiting_group_lie", "walking_group_lie", "walking_to_lie", "walking_to_basket"]:
			var disc_local: Vector2 = get_flight_visual(visitor) if stage == "disc_flying" else visitor["disc_position"]
			var disc_world: Vector2 = property_manager.property_local_to_world(disc_local)
			if stage == "disc_flying":
				var duration: float = maxf(0.01, float(visitor["flight_duration"]))
				var progress: float = clampf(float(visitor["flight_elapsed"]) / duration, 0.0, 1.0)
				var ground_local: Vector2 = get_flight_ground_point(visitor["flight_start"], visitor["flight_end"], progress, float(visitor.get("flight_curve", 0.0)), float(visitor.get("flight_turn", 0.0)), float(visitor.get("flight_fade", 0.0)))
				var ground_world: Vector2 = property_manager.property_local_to_world(ground_local)
				draw_circle(ground_world + Vector2(2, 2), 4.0, Color(0, 0, 0, FLIGHT_SHADOW_ALPHA))
				draw_circle(disc_world, 7.0, Color(1.0, 0.87, 0.32, 0.18))
			else:
				draw_circle(disc_world + Vector2(1, 2), 4.5, Color(0, 0, 0, 0.24))
			draw_circle(disc_world, FLIGHT_DISC_RADIUS, Color(0.98, 0.83, 0.23, 1.0))
			draw_arc(disc_world, 5.5, 0.0, TAU, 12, Color(0.13, 0.16, 0.12, 0.8), 1.0)
		if stage in ["waiting_partner", "waiting_at_checkin", "waiting_at_tee", "throwing", "disc_flying", "waiting_at_basket"]:
			var label_text: String = get_activity_label(stage)
			var font: Font = ThemeDB.fallback_font
			var font_size: int = 11
			var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var label_position: Vector2 = body + Vector2(-width * 0.5, -20)
			draw_string_outline(font, label_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.07, 0.11, 0.09, 0.9))
			draw_string(font, label_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		if selected_id == id:
			draw_arc(body, 10.0, 0.0, TAU, 16, Color.WHITE, 1.8)


func draw_ellipse_shadow(at: Vector2) -> void:
	# Lightweight elliptical ground shadow (no extra sprites or assets).
	draw_set_transform(at + Vector2(2, 6), 0.0, Vector2(1.25, 0.55))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.23))
	draw_set_transform(Vector2.ZERO)


func select_at(world_point: Vector2) -> bool:
	if property_manager == null:
		return false
	for visitor_value in visitors:
		var visitor: Dictionary = visitor_value
		if str(visitor["stage"]) in ["driving_in", "driving_out"]:
			continue
		var world: Vector2 = property_manager.property_local_to_world(visitor["position"])
		if world.distance_to(world_point) < 22.0:
			selected_id = int(visitor["id"])
			show_profile(selected_id)
			queue_redraw()
			return true
	return false

func build_profile() -> void:
	profile_layer = CanvasLayer.new()
	profile_layer.layer = 21
	add_child(profile_layer)
	profile_panel = PanelContainer.new()
	profile_panel.visible = false
	profile_panel.position = Vector2(220, 105)
	profile_panel.custom_minimum_size = Vector2(320, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.97, 0.95, 0.90, 1.0)
	panel_style.border_color = Color(0.40, 0.60, 0.40, 0.42)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 12
	panel_style.shadow_color = Color(0.18, 0.22, 0.16, 0.28)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 3)
	profile_panel.add_theme_stylebox_override("panel", panel_style)
	profile_layer.add_child(profile_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	profile_panel.add_child(layout)
	var title := PanelContainer.new()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.26, 0.46, 0.30, 1.0)
	title_style.border_width_top = 2
	title_style.border_width_bottom = 1
	title_style.border_color = Color(0.58, 0.72, 0.54, 1.0)
	title_style.corner_radius_top_left = 14
	title_style.corner_radius_top_right = 14
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	title_style.content_margin_left = 12
	title_style.content_margin_right = 8
	title_style.content_margin_top = 8
	title_style.content_margin_bottom = 8
	title.add_theme_stylebox_override("panel", title_style)
	layout.add_child(title)
	var title_row := HBoxContainer.new()
	title.add_child(title_row)
	var title_label := Label.new()
	title_label.text = "  Guest profile"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94, 1.0))
	title_row.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(64, 32)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94, 1.0))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.40, 0.60, 0.40, 0.85)
	close_style.border_color = Color(0.58, 0.72, 0.54, 1.0)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(10)
	close_style.content_margin_left = 8
	close_style.content_margin_right = 8
	close_style.content_margin_top = 4
	close_style.content_margin_bottom = 4
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_style)
	close_button.pressed.connect(func(): profile_panel.hide())
	title_row.add_child(close_button)
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 6)
	body.add_theme_constant_override("margin_bottom", 4)
	layout.add_child(body)
	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_label.add_theme_font_size_override("font_size", 13)
	profile_label.add_theme_color_override("font_color", Color(0.16, 0.20, 0.16, 1.0))
	body.add_child(profile_label)

func show_profile(person_id: int) -> void:
	if not people.has(person_id):
		return
	var person: Dictionary = people[person_id]
	var membership: String = "Unregistered" if int(person["membership_number"]) < 0 else "WDGA #%d" % int(person["membership_number"])
	var skills: Dictionary = person["skills"]
	profile_label.text = "%s  •  Age %d\n%s  •  %s\n%s-handed  •  %s\n\nPower %d   Accuracy %d\nPutting %d   Control %d\nCourse IQ %d   Composure %d\n\nVisits: %d   Holes visited: %d" % [str(person["name"]), int(person["age"]), membership, str(person["classification"]), str(person["handedness"]), str(person["personality"]), int(skills["power"]), int(skills["accuracy"]), int(skills["putting"]), int(skills["control"]), int(skills["course_iq"]), int(skills["composure"]), int(person["visits"]), int(person["holes_visited"])]
	for visitor_value in visitors:
		var active: Dictionary = visitor_value
		if int(active["id"]) == person_id and str(active["stage"]) in ["throwing", "standstill", "run_up", "disc_flying", "waiting_group", "waiting_group_lie", "walking_group_lie", "walking_to_lie", "walking_to_basket"]:
			profile_label.text += "\n\nHole %d | Strokes: %d\n%s" % [int(active["holes"][int(active["hole_cursor"])]) + 1, int(active["strokes"]), str(active["last_throw"])]
			break
	if not person["history"].is_empty():
		var last_round: Dictionary = person["history"][-1]
		if last_round.has("strokes"):
			profile_label.text += "\nLast round: %d strokes / Par %d" % [int(last_round["strokes"]), int(last_round["par"])]
	if not person["feedback"].is_empty():
		profile_label.text += "\n\nLast feedback: " + str(person["feedback"][-1])
	profile_panel.show()

func save_people() -> void:
	var records: Array = []
	for person in people.values():
		records.append(person)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"next_id": next_person_id, "next_membership": next_membership_number, "people": records}))

func load_people() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	next_person_id = int(parsed.get("next_id", 1))
	next_membership_number = int(parsed.get("next_membership", 10001))
	for value in parsed.get("people", []):
		if value is Dictionary:
			people[int(value.get("id", -1))] = value
