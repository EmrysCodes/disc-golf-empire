#!/usr/bin/env -S godot --headless --script
# Update 43 smoke check: shared tree records stay in lockstep with mirrors
# and match visual/collision radius bases.
extends SceneTree


func _initialize() -> void:
	var pm := PropertyManager.new()
	root.add_child(pm)
	# Wait one frame so _ready / generate_property runs.
	await process_frame
	var ok := true
	if pm.tree_records.size() == 0:
		push_error("No property tree records generated")
		ok = false
	if pm.tree_records.size() != pm.trees.size() or pm.trees.size() != pm.tree_sizes.size():
		push_error(
			"Property tree array mismatch records=%d trees=%d sizes=%d"
			% [pm.tree_records.size(), pm.trees.size(), pm.tree_sizes.size()]
		)
		ok = false
	if pm.world_tree_records.size() != pm.world_trees.size() or pm.world_trees.size() != pm.world_tree_sizes.size():
		push_error(
			"World tree array mismatch records=%d trees=%d sizes=%d"
			% [pm.world_tree_records.size(), pm.world_trees.size(), pm.world_tree_sizes.size()]
		)
		ok = false
	var sample_count: int = mini(12, pm.tree_records.size())
	for i in range(sample_count):
		var record: Dictionary = pm.tree_records[i]
		if record["position"] != pm.trees[i]:
			push_error("Position mirror mismatch at %d" % i)
			ok = false
		if not is_equal_approx(float(record["scale"]), float(pm.tree_sizes[i])):
			push_error("Scale mirror mismatch at %d" % i)
			ok = false
		var scale: float = float(record["scale"])
		if not is_equal_approx(float(record["trunk_radius_px"]), 4.0 * scale):
			push_error("Trunk radius mismatch at %d" % i)
			ok = false
		if not is_equal_approx(float(record["crown_radius_px"]), 18.0 * scale):
			push_error("Crown radius mismatch at %d" % i)
			ok = false
		var height: float = float(record["height_feet"])
		if height < 28.0 or height > 70.0:
			push_error("Height out of range at %d: %s" % [i, height])
			ok = false
		if not is_equal_approx(float(record["crown_base_ratio"]), 0.35):
			push_error("Crown base ratio mismatch at %d" % i)
			ok = false
	# Remove mid-list and confirm lockstep.
	if pm.tree_records.size() > 3:
		var mid: int = pm.tree_records.size() / 2
		if not pm.remove_property_tree(mid):
			push_error("remove_property_tree failed")
			ok = false
		elif (
			pm.tree_records.size() != pm.trees.size()
			or pm.trees.size() != pm.tree_sizes.size()
		):
			push_error("Arrays diverged after remove_property_tree")
			ok = false
	if ok:
		print(
			"UPDATE_43_OK property_trees=%d world_trees=%d"
			% [pm.tree_records.size(), pm.world_tree_records.size()]
		)
		quit(0)
	else:
		print("UPDATE_43_FAIL")
		quit(1)
