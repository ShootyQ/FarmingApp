extends SceneTree

var failures = 0
func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func run():
	var data = root.get_node("GameData")
	var state = root.get_node("GameState")
	check(data.farm_coordinates.size() == 400 and data.farm_indices.size() == 400, "Every meadow diamond has a unique address")
	for i in range(400):
		check(data.get_farm_index(data.farm_coordinates[i]) == i, "Coordinate roundtrip")
	for i in range(16):
		check(data.farm_coordinates[i] == Vector2i(i % 4, i / 4), "Legacy tile index stays in place")
	check(data.get_farm_index(Vector2i(-9, 0)) == -1 and data.get_farm_index(Vector2i(12, 0)) == -1, "Meadow boundary")
	state._generate_sector_tiles("1,1")
	var original: Array = state.sector_tiles["1,1"].slice(0, 16).duplicate(true)
	var obstacles = ["weed", "small_wood", "small_rock", "hardwood_stump", "granite_boulder", "ancient_relic_mound"]
	for i in range(obstacles.size()):
		original[i + 1] = state._create_obstacle_tile(obstacles[i])
		original[i + 1]["variant"] = 1
	original[7] = {"type": "soil", "state": "ready", "crop": "wheat", "is_mutated": false, "plant_time": 1, "grow_duration": 5}
	var legacy = {"coins": 100, "wood": 12, "stone": 7, "relics": 1, "tool_tier": 0, "current_sector": "1,1",
		"unlocked_sectors": ["1,1"], "sector_tiles": {"1,1": original},
		"seed_inventory": {"wheat": 3}, "barn_inventory": []}
	var file = FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.load_game()
	var expected: Array = JSON.parse_string(JSON.stringify(original))
	check(state.sector_tiles["1,1"].size() == 400, "Old farm expanded")
	for i in range(16):
		check(state.sector_tiles["1,1"][i] == expected[i], "Original farm preserved")
	for i in range(16, 400):
		check(state.sector_tiles["1,1"][i] == {"type": "grass"}, "New meadow is clear grass")
	check(state.coins == 100 and state.wood == 12 and state.stone == 7 and state.tool_tier == 0, "Expansion never charges or changes resources")
	check(typeof(state.sector_tiles["1,1"][2]["variant"]) == TYPE_FLOAT, "Fixture reproduces JSON variant decimals")
	var farm = load("res://scenes/main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	await process_frame
	check(farm.plot_nodes.size() == 400, "Every diamond has a rendered interactive plot")
	for i in range(obstacles.size()):
		var sprite = farm.plot_nodes[i + 1].get_node("ObjectSprite")
		check(sprite.visible and sprite.texture != null, "Saved obstacle is visible: " + obstacles[i])
		if i == 0:
			check(sprite.texture == farm.tex_weeds[1], "Saved weeds pick correct variant")
		elif i == 1 or i == 3:
			check(sprite.texture == farm.tex_logs[1], "Saved wood picks correct variant")
		elif i == 2 or i == 4:
			check(sprite.texture == farm.tex_rocks[1], "Saved rocks pick correct variant")
	# Real screen-to-diamond input path on a tile outside the old 4x4 area.
	var coordinate = Vector2i(4, 1)
	var idx: int = data.get_farm_index(coordinate)
	var position_on_farm = Vector2((coordinate.x - coordinate.y) * 80, -60 + (coordinate.x + coordinate.y) * 40)
	var screen: Vector2 = farm.plots_root.get_global_transform_with_canvas() * position_on_farm
	farm._handle_isometric_click(screen)
	check(state.sector_tiles["1,1"][idx]["type"] == "soil" and state.coins == 95, "Tap outer grass tills for five coins")
	check(farm.plot_nodes[idx].get_node("Soil").visible, "Tilled outer soil appears immediately")
	check(farm.tool_effects.active.has(idx), "Outer tile gets hoe animation")
	farm._handle_isometric_click(screen)
	check(state.sector_tiles["1,1"][idx].get("state") == "growing" and state.seed_inventory["wheat"] == 2, "Outer soil supports planting")
	state.sector_tiles["1,1"][idx]["plant_time"] = Time.get_unix_time_from_system() - 10
	state.sector_tiles["1,1"][idx]["is_mutated"] = false
	state.update_crop_timers()
	check(state.sector_tiles["1,1"][idx]["state"] == "ready", "Outer crops grow")
	farm._handle_isometric_click(screen)
	check(state.sector_tiles["1,1"][idx]["state"] == "empty" and state.barn_inventory[0]["count"] == 1, "Outer crops harvest to barn")
	# Tilling at both meadow corners, then a save roundtrip.
	for corner in [Vector2i(-8, -8), Vector2i(11, 11)]:
		var corner_idx: int = data.get_farm_index(corner)
		state.interact_with_tile("1,1", corner_idx)
		check(state.sector_tiles["1,1"][corner_idx]["type"] == "soil", "Meadow corner tills")
	state.save_game()
	state.load_game()
	check(state.sector_tiles["1,1"][idx]["state"] == "empty" and state.coins == 85, "Outer farm persists without duplicate charges")
	check(state.sector_tiles["1,1"][data.get_farm_index(Vector2i(-8,-8))]["type"] == "soil", "Corner soil persists")
	state._generate_sector_tiles("1,0")
	check(state.sector_tiles["1,0"].size() == 400, "New sectors also have full playable meadow")
	print("PASS: saved obstacles, full meadow interaction, old-save migration, outer crop lifecycle and persistence" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
