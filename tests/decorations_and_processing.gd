extends SceneTree

var failures: int = 0

func _initialize():
	call_deferred("run")

func _assert(cond: bool, msg: String):
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)

func run():
	var game_state = root.get_node("GameState")
	var game_data = root.get_node("GameData")
	
	_test_pricing_and_recipes(game_data)
	_test_decoration_crafting_and_placement(game_state, game_data)
	_test_stone_well_growth_boost(game_state, game_data)
	_test_mill_processing_and_timers(game_state, game_data)
	_test_bakery_baking_and_timers(game_state, game_data)
	await _test_ui_modals_and_placement_mode(game_state, game_data)
	
	if failures > 0:
		printerr("Tests finished with %d failures" % failures)
		quit(1)
	else:
		print("PASS: decorations placement, stone well boost, mill & bakery production, 5m/10m timers, and flour/bread economy")
		quit(0)

func _test_pricing_and_recipes(game_data):
	var wheat_value = game_data.CROPS["wheat"]["reward"]
	var flour_info = game_data.get_item_info("flour")
	var bread_info = game_data.get_item_info("bread")
	
	_assert(flour_info["sell_value"] == wheat_value, "Flour sell value (%d) must match wheat reward (%d)" % [flour_info["sell_value"], wheat_value])
	_assert(bread_info["sell_value"] >= wheat_value * 10, "Bread sell value (%d) must be at least 10x wheat value (%d)" % [bread_info["sell_value"], wheat_value * 10])
	_assert(bread_info["sell_value"] == 150, "Bread sell value is 150c (12.5x wheat)")
	
	_assert(game_data.CRAFTING_RECIPES.has("mill"), "CRAFTING_RECIPES must contain 'mill'")
	_assert(game_data.CRAFTING_RECIPES.has("bakery"), "CRAFTING_RECIPES must contain 'bakery'")
	_assert(game_data.CRAFTING_RECIPES.has("wooden_fence"), "CRAFTING_RECIPES must contain 'wooden_fence'")
	_assert(game_data.CRAFTING_RECIPES.has("stone_well"), "CRAFTING_RECIPES must contain 'stone_well'")
	_assert(game_data.CRAFTING_RECIPES.has("lantern_post"), "CRAFTING_RECIPES must contain 'lantern_post'")
	_assert(game_data.CRAFTING_RECIPES.has("planter_box"), "CRAFTING_RECIPES must contain 'planter_box'")

func _test_decoration_crafting_and_placement(game_state, game_data):
	game_state.start_new_farm()
	game_state.workshop_unlocked = true
	game_state.wood = 500
	game_state.stone = 500
	game_state.coins = 2000
	
	var crafted = game_state.craft_recipe("wooden_fence")
	_assert(crafted, "Crafting wooden fence must succeed")
	_assert(game_state.get_barn_item_count("wooden_fence") >= 2, "Wooden fence yields 2 sections")
	
	# Clear tile (3, 0) so it's grass ready for placement
	var idx = game_data.get_farm_index(Vector2i(3, 0))
	game_state.sector_tiles["1,1"][idx] = {"type": "grass"}
	
	var can_place = game_state.can_place_decoration("wooden_fence", "1,1", 3, 0)
	_assert(can_place, "can_place_decoration must be true for clear plot")
	
	var placed = game_state.place_decoration("wooden_fence", "1,1", 3, 0)
	_assert(placed, "place_decoration must succeed")
	
	var tile = game_state.sector_tiles["1,1"][idx]
	_assert(tile.get("type") == "decoration", "Tile must have type 'decoration'")
	_assert(tile.get("item_id") == "wooden_fence", "Tile must have item_id 'wooden_fence'")
	
	var barn_before = game_state.get_barn_item_count("wooden_fence")
	game_state.interact_with_tile("1,1", idx, "tools")
	var barn_after = game_state.get_barn_item_count("wooden_fence")
	_assert(barn_after == barn_before + 1, "Picking up decoration in tools mode returns it to Barn")
	_assert(game_state.sector_tiles["1,1"][idx].get("type") == "grass", "Tile becomes grass after picking up decoration")

func _test_stone_well_growth_boost(game_state, game_data):
	game_state.wood = 500
	game_state.stone = 500
	game_state.coins = 2000
	
	game_state.craft_recipe("stone_well")
	_assert(game_state.get_barn_item_count("stone_well") >= 1, "Stone well crafted into Barn")
	
	# Clear tile (2, 0) to grass so stone well can be placed
	var well_idx = game_data.get_farm_index(Vector2i(2, 0))
	game_state.sector_tiles["1,1"][well_idx] = {"type": "grass"}
	
	var placed = game_state.place_decoration("stone_well", "1,1", 2, 0)
	_assert(placed, "Stone well placed at gx=2, gy=0")
	
	var plot_idx = game_data.get_farm_index(Vector2i(2, 1))
	game_state.sector_tiles["1,1"][plot_idx] = {
		"type": "soil",
		"state": "empty",
		"crop": "",
		"is_mutated": false,
		"plant_time": 0.0,
		"grow_duration": 0.0
	}
	
	game_state.selected_crop = "wheat"
	game_state.seed_inventory["wheat"] = 5
	game_state.interact_with_tile("1,1", plot_idx, "plant")
	
	var planted_tile = game_state.sector_tiles["1,1"][plot_idx]
	_assert(planted_tile["state"] == "growing", "Wheat should be planted and growing")
	var normal_duration = float(game_data.CROPS["wheat"]["grow_time"]) # 30s
	var expected_boosted = roundf(normal_duration * 0.85) # 26s
	_assert(planted_tile["grow_duration"] == expected_boosted, "Adjacent stone well gives +15%% grow speed (expected %d, got %d)" % [expected_boosted, planted_tile["grow_duration"]])

func _test_mill_processing_and_timers(game_state, game_data):
	game_state.wood = 500
	game_state.stone = 500
	game_state.coins = 2000
	
	var crafted = game_state.craft_recipe("mill")
	_assert(crafted, "Windmill crafted")
	_assert(game_state.buildings["mill"]["unlocked"], "Windmill is unlocked")
	
	var can_place = game_state.can_place_building("mill", "1,1", -2, 0)
	_assert(can_place, "Windmill can be placed at (-2, 0)")
	var placed = game_state.place_building("mill", "1,1", -2, 0)
	_assert(placed, "Windmill placed successfully")
	_assert(game_state.buildings["mill"]["placed"], "Windmill marked placed")
	
	game_state.add_to_barn("wheat", 2)
	_assert(game_state.get_barn_item_count("wheat") >= 2, "Barn has wheat")
	
	var started = game_state.start_milling()
	_assert(started, "start_milling() succeeded")
	_assert(game_state.buildings["mill"]["is_processing"], "Mill is processing")
	_assert(game_state.buildings["mill"]["process_duration"] == 300.0, "Milling timer is 5 minutes (300 seconds)")
	
	var start_time = float(game_state.buildings["mill"]["process_started_at"])
	game_state.update_crop_timers(start_time + 299.0)
	_assert(game_state.buildings["mill"]["is_processing"], "Mill still processing at 299s")
	_assert(game_state.buildings["mill"]["output_ready"] == 0, "No flour ready yet")
	
	game_state.update_crop_timers(start_time + 301.0)
	_assert(not game_state.buildings["mill"]["is_processing"], "Mill finished processing at 301s")
	_assert(game_state.buildings["mill"]["output_ready"] == 1, "1 flour ready for collection")
	
	var collected = game_state.collect_milled_flour()
	_assert(collected == 1, "Collected 1 flour")
	_assert(game_state.get_barn_item_count("flour") >= 1, "Flour stored in Barn")
	_assert(game_state.buildings["mill"]["output_ready"] == 0, "output_ready reset to 0")

func _test_bakery_baking_and_timers(game_state, game_data):
	game_state.wood = 500
	game_state.stone = 500
	game_state.coins = 2000
	game_state.add_to_barn("cut_stone", 10)
	game_state.add_to_barn("timber_plank", 10)
	
	var crafted = game_state.craft_recipe("bakery")
	_assert(crafted, "Bakery crafted")
	_assert(game_state.buildings["bakery"]["unlocked"], "Bakery is unlocked")
	
	var can_place = game_state.can_place_building("bakery", "1,1", -2, 2)
	_assert(can_place, "Bakery can be placed at (-2, 2)")
	var placed = game_state.place_building("bakery", "1,1", -2, 2)
	_assert(placed, "Bakery placed successfully")
	_assert(game_state.buildings["bakery"]["placed"], "Bakery marked placed")
	
	_assert(game_state.get_barn_item_count("flour") >= 1, "Barn has flour ready to bake")
	
	var started = game_state.start_baking()
	_assert(started, "start_baking() succeeded")
	_assert(game_state.buildings["bakery"]["is_processing"], "Bakery is baking")
	_assert(game_state.buildings["bakery"]["process_duration"] == 600.0, "Baking timer is 10 minutes (600 seconds)")
	
	var start_time = float(game_state.buildings["bakery"]["process_started_at"])
	game_state.update_crop_timers(start_time + 599.0)
	_assert(game_state.buildings["bakery"]["is_processing"], "Bakery still processing at 599s")
	_assert(game_state.buildings["bakery"]["output_ready"] == 0, "No bread ready yet")
	
	game_state.update_crop_timers(start_time + 601.0)
	_assert(not game_state.buildings["bakery"]["is_processing"], "Bakery finished processing at 601s")
	_assert(game_state.buildings["bakery"]["output_ready"] == 1, "1 bread ready for collection")
	
	var collected = game_state.collect_baked_bread()
	_assert(collected == 1, "Collected 1 bread")
	_assert(game_state.get_barn_item_count("bread") >= 1, "Bread stored in Barn")
	
	var coins_before = game_state.coins
	var bread_slot_idx = -1
	for i in range(game_state.barn_inventory.size()):
		if game_state.barn_inventory[i]["id"] == "bread":
			bread_slot_idx = i
			break
	_assert(bread_slot_idx >= 0, "Found bread slot in Barn")
	game_state.sell_from_barn(bread_slot_idx, 1)
	var coins_after = game_state.coins
	_assert(coins_after - coins_before == 150, "Sold bread for 150 coins (+150c)")

func _test_ui_modals_and_placement_mode(game_state, game_data):
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	_assert(main_scene.mill_modal != null, "Mill modal must exist")
	_assert(main_scene.bakery_modal != null, "Bakery modal must exist")
	_assert(main_scene.mill_action_btn.custom_minimum_size.y >= 48, "Mill action button touch height >= 48px")
	_assert(main_scene.bakery_action_btn.custom_minimum_size.y >= 48, "Bakery action button touch height >= 48px")
	_assert(main_scene.barn_place_btn != null, "Barn place in world button must exist")
	
	main_scene._open_mill_modal()
	_assert(main_scene.mill_modal.visible, "Mill modal opened")
	_assert(main_scene._farm_modal_open(), "_farm_modal_open() true when mill modal is open")
	
	main_scene._open_bakery_modal()
	_assert(main_scene.bakery_modal.visible, "Bakery modal opened")
	_assert(not main_scene.mill_modal.visible, "Opening bakery modal closes mill modal")
	
	main_scene._start_placement_mode("wooden_fence")
	_assert(main_scene.is_placing_building, "Placement mode active")
	_assert(main_scene.placing_building_id == "wooden_fence", "Placing wooden fence")
	main_scene._stop_placement_mode()
	_assert(not main_scene.is_placing_building, "Placement mode stopped")
	
	# Test green placement alignment under 2x2 building
	main_scene._start_placement_mode("workshop")
	var ghost_spr = main_scene.placement_ghost_node.get_node("GhostSprite") as Sprite2D
	var tex_h = ghost_spr.texture.get_height()
	var bot_world = (tex_h * 0.5 + ghost_spr.offset.y) * ghost_spr.scale.y
	_assert(bot_world >= 95.0 and bot_world <= 115.0, "Workshop ghost sprite sits directly on 2x2 diamond base (bot_world=%f, expected 95-115)" % bot_world)
	main_scene._stop_placement_mode()
	
	# Test barn click hitboxes:
	# Barn placed at (0, 0) spans (0, 0), (1, 0), (0, 1), (1, 1).
	# The two squares in front of the barn are (0, 2) and (1, 2).
	var barn_pos = main_scene._grid_to_local_pos(0, 0)
	var front_sq1 = main_scene._grid_to_local_pos(0, 2)
	var front_sq2 = main_scene._grid_to_local_pos(1, 2)
	
	# Clicking barn roof or footprint should hit barn
	var hit_roof = main_scene._get_building_at_local_pos(barn_pos + Vector2(0, -60))
	_assert(hit_roof == "barn", "Click on barn roof chooses barn")
	var hit_footprint = main_scene._get_building_at_local_pos(barn_pos + Vector2(0, 30))
	_assert(hit_footprint == "barn", "Click on barn footprint chooses barn")
	
	# Clicking the two squares in front of the barn must NOT hit barn
	var hit_front1 = main_scene._get_building_at_local_pos(front_sq1)
	_assert(hit_front1 == "", "Square in front of barn (0, 2) does not choose barn (got '%s')" % hit_front1)
	var hit_front2 = main_scene._get_building_at_local_pos(front_sq2)
	_assert(hit_front2 == "", "Square in front of barn (1, 2) does not choose barn (got '%s')" % hit_front2)
	
	# When clicking in front of the barn on (0, 2), barn modal must NOT open
	main_scene.barn_modal.visible = false
	var screen_pt = main_scene.plots_root.get_global_transform_with_canvas() * front_sq1
	main_scene._handle_isometric_click(screen_pt)
	_assert(not main_scene.barn_modal.visible, "Tapping green square in front of barn does not open Barn modal")
	
	main_scene.queue_free()
