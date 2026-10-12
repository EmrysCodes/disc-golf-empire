class_name CourseManager
extends Node


# ==================================================
# COURSE SETTINGS
# ==================================================

const TOTAL_HOLES := 9

# One property grid cell represents 15 real-world feet.
# Previous prototype used 10 feet.
const FEET_PER_CELL := 15.0


# ==================================================
# COURSE DATA
# ==================================================

var holes: Array = []

var selected_hole := 0


# ==================================================
# STARTUP
# ==================================================

func _ready() -> void:
	create_course()


# ==================================================
# CREATE COURSE
# ==================================================

func create_course() -> void:

	holes.clear()

	for i in range(TOTAL_HOLES):

		holes.append({
			"tee": Vector2(-1, -1),
			"basket": Vector2(-1, -1),
			"path_points": []
		})


# ==================================================
# STARTER LAYOUT (property-local coords, same as CourseBuilder)
# ==================================================

func generate_starter_layout(property_manager) -> void:
	# Seed a playable 6-hole starter so guests can arrive without manual build.
	# Leaves holes 6–8 empty for player expansion. Does not touch tree_records.
	if property_manager == null:
		return
	if has_any_complete_hole():
		return
	var size: Vector2 = property_manager.get_property_size_pixels()
	# Fractions of property size — west/center fairways, away from east facilities.
	# Distances ~90–210 ft at FEET_PER_CELL / CELL_SIZE.
	var specs: Array = [
		# hole, tee_fx, tee_fy, basket_fx, basket_fy, mid_fx, mid_fy (mid < 0 skips dogleg)
		# Spread across west/center clearings — avoid tunneling every hole through dense brush.
		[0, 0.14, 0.82, 0.18, 0.52, -1.0, -1.0],
		[1, 0.34, 0.80, 0.55, 0.58, 0.42, 0.68],
		[2, 0.62, 0.76, 0.48, 0.46, 0.64, 0.58],
		[3, 0.12, 0.44, 0.40, 0.30, 0.22, 0.34],
		[4, 0.58, 0.36, 0.26, 0.16, 0.46, 0.20],
		[5, 0.22, 0.18, 0.58, 0.12, 0.40, 0.10],
	]
	for spec_value in specs:
		var spec: Array = spec_value
		var hole_index: int = int(spec[0])
		var tee_local: Vector2 = Vector2(size.x * float(spec[1]), size.y * float(spec[2]))
		var basket_local: Vector2 = Vector2(size.x * float(spec[3]), size.y * float(spec[4]))
		tee_local = _nudge_off_water(property_manager, tee_local)
		basket_local = _nudge_off_water(property_manager, basket_local)
		set_tee(hole_index, tee_local)
		set_basket(hole_index, basket_local)
		clear_path_points(hole_index)
		var mid_local := Vector2(-1, -1)
		if float(spec[5]) >= 0.0:
			mid_local = Vector2(size.x * float(spec[5]), size.y * float(spec[6]))
			mid_local = _nudge_off_water(property_manager, mid_local)
			add_path_point(hole_index, mid_local)
		# Open a playable fairway corridor (grass + tree clear) without changing tree schema.
		if property_manager.has_method("clear_fairway_corridor"):
			property_manager.clear_fairway_corridor(tee_local, basket_local, 56.0, mid_local)


func has_any_complete_hole() -> bool:
	for i in range(holes.size()):
		if is_hole_complete(i):
			return true
	return false


func _nudge_off_water(property_manager, local_pos: Vector2) -> Vector2:
	var cell: Vector2i = property_manager.world_to_cell(
		property_manager.property_local_to_world(local_pos)
	)
	if cell.x < 0 or cell.y < 0:
		return local_pos
	if cell.y >= property_manager.terrain.size():
		return local_pos
	if cell.x >= property_manager.terrain[cell.y].size():
		return local_pos
	if int(property_manager.terrain[cell.y][cell.x]) != property_manager.WATER:
		return local_pos
	# Step toward property center until clear or give up.
	var center: Vector2 = property_manager.get_property_local_center()
	var point: Vector2 = local_pos
	for _i in range(8):
		point = point.lerp(center, 0.18)
		var c2: Vector2i = property_manager.world_to_cell(
			property_manager.property_local_to_world(point)
		)
		if c2.y >= 0 and c2.y < property_manager.terrain.size() and c2.x >= 0 and c2.x < property_manager.terrain[c2.y].size():
			if int(property_manager.terrain[c2.y][c2.x]) != property_manager.WATER:
				return point
	return local_pos


# ==================================================
# GET HOLE
# ==================================================

func get_hole(hole_index: int) -> Dictionary:

	if not is_valid_hole_index(hole_index):
		return {}

	return holes[hole_index]


# ==================================================
# SET TEE
# ==================================================

func set_tee(
	hole_index: int,
	world_position: Vector2
) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	hole["tee"] = world_position

	holes[hole_index] = hole


# ==================================================
# SET BASKET
# ==================================================

func set_basket(
	hole_index: int,
	world_position: Vector2
) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	hole["basket"] = world_position

	holes[hole_index] = hole


# ==================================================
# REMOVE TEE
# ==================================================

func remove_tee(hole_index: int) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	hole["tee"] = Vector2(-1, -1)

	# A path cannot exist without both endpoints.
	hole["path_points"] = []

	holes[hole_index] = hole


# ==================================================
# REMOVE BASKET
# ==================================================

func remove_basket(hole_index: int) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	hole["basket"] = Vector2(-1, -1)

	# A path cannot exist without both endpoints.
	hole["path_points"] = []

	holes[hole_index] = hole


# ==================================================
# ADD PATH POINT
# ==================================================

func add_path_point(
	hole_index: int,
	world_position: Vector2
) -> int:

	if not is_valid_hole_index(hole_index):
		return -1

	var hole: Dictionary = holes[hole_index]

	var points: Array = hole["path_points"]

	points.append(world_position)

	hole["path_points"] = points

	holes[hole_index] = hole

	return points.size() - 1


# ==================================================
# INSERT PATH POINT
# ==================================================

func insert_path_point(
	hole_index: int,
	point_index: int,
	world_position: Vector2
) -> int:

	if not is_valid_hole_index(hole_index):
		return -1

	var hole: Dictionary = holes[hole_index]

	var points: Array = hole["path_points"]

	point_index = clamp(
		point_index,
		0,
		points.size()
	)

	points.insert(
		point_index,
		world_position
	)

	hole["path_points"] = points

	holes[hole_index] = hole

	return point_index


# ==================================================
# MOVE PATH POINT
# ==================================================

func move_path_point(
	hole_index: int,
	point_index: int,
	world_position: Vector2
) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	var points: Array = hole["path_points"]

	if point_index < 0:
		return

	if point_index >= points.size():
		return

	points[point_index] = world_position

	hole["path_points"] = points

	holes[hole_index] = hole


# ==================================================
# REMOVE PATH POINT
# ==================================================

func remove_path_point(
	hole_index: int,
	point_index: int
) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	var points: Array = hole["path_points"]

	if point_index < 0:
		return

	if point_index >= points.size():
		return

	points.remove_at(point_index)

	hole["path_points"] = points

	holes[hole_index] = hole


# ==================================================
# CLEAR PATH POINTS
# ==================================================

func clear_path_points(hole_index: int) -> void:

	if not is_valid_hole_index(hole_index):
		return

	var hole: Dictionary = holes[hole_index]

	hole["path_points"] = []

	holes[hole_index] = hole


# ==================================================
# HOLE COMPLETE?
# ==================================================

func is_hole_complete(hole_index: int) -> bool:

	if not is_valid_hole_index(hole_index):
		return false

	var hole: Dictionary = holes[hole_index]

	var tee: Vector2 = hole["tee"]
	var basket: Vector2 = hole["basket"]

	return (
		tee.x >= 0
		and basket.x >= 0
	)


# ==================================================
# HOLE DISTANCE
# ==================================================

func calculate_hole_distance(
	hole_index: int,
	cell_size: float
) -> int:

	if not is_hole_complete(hole_index):
		return 0

	var hole: Dictionary = holes[hole_index]

	var tee: Vector2 = hole["tee"]
	var basket: Vector2 = hole["basket"]

	var pixel_distance := tee.distance_to(
		basket
	)

	var cell_distance := (
		pixel_distance
		/ cell_size
	)

	return int(
		round(
			cell_distance
			* FEET_PER_CELL
		)
	)


# ==================================================
# PAR
# ==================================================

func calculate_par(distance_feet: int) -> int:

	if distance_feet < 400:
		return 3

	if distance_feet < 700:
		return 4

	return 5


# ==================================================
# COMPLETED HOLE COUNT
# ==================================================

func get_completed_hole_count() -> int:

	var completed := 0

	for i in range(holes.size()):

		if is_hole_complete(i):
			completed += 1

	return completed


# ==================================================
# TOTAL COURSE DISTANCE
# ==================================================

func get_total_course_distance(
	cell_size: float
) -> int:

	var total := 0

	for i in range(holes.size()):

		total += calculate_hole_distance(
			i,
			cell_size
		)

	return total


# ==================================================
# TOTAL COURSE PAR
# ==================================================

func get_total_course_par(
	cell_size: float
) -> int:

	var total := 0

	for i in range(holes.size()):

		if not is_hole_complete(i):
			continue

		var distance := calculate_hole_distance(
			i,
			cell_size
		)

		total += calculate_par(
			distance
		)

	return total


# ==================================================
# PREVIOUS HOLE
# ==================================================

func select_previous_hole() -> void:

	if selected_hole > 0:
		selected_hole -= 1


# ==================================================
# NEXT HOLE
# ==================================================

func select_next_hole() -> void:

	if selected_hole < TOTAL_HOLES - 1:
		selected_hole += 1


# ==================================================
# SET SELECTED HOLE
# ==================================================

func set_selected_hole(
	hole_index: int
) -> void:

	selected_hole = clamp(
		hole_index,
		0,
		TOTAL_HOLES - 1
	)


# ==================================================
# VALIDATE HOLE INDEX
# ==================================================

func is_valid_hole_index(
	hole_index: int
) -> bool:

	return (
		hole_index >= 0
		and hole_index < holes.size()
	)