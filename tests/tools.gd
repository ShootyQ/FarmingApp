extends SceneTree

var failures = 0
var uses: Array = []

func _initialize():
	call_deferred("_run")

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _run():
	var state = root.get_node("GameState")
	var data = root.get_node("GameData")
	state.tool_used.connect(func(coord, idx, tool): uses.append([coord, idx, tool]))
	state.current_sector_coord = "1,1"
	state.unlocked_sectors.assign(["1,1", "1,0"])
	# All obstacle kinds choose the intended tool, but only successful hits emit.
	for obstacle_id in data.OBSTACLES:
		var obstacle: Dictionary = data.OBSTACLES[obstacle_id]
		state.tool_tier = obstacle["required_tool_tier"]
		state.sector_tiles["1,1"] = [state._create_obstacle_tile(obstacle_id)]
		var tile: Dictionary = state.sector_tiles["1,1"][0]
		check(data.get_tool_for_tile(tile) == data.OBSTACLE_TOOLS[obstacle_id], "Tool mapping: " + obstacle_id)
		var old_count = uses.size()
		state.interact_with_tile("1,1", 0)
		check(uses.size() == old_count + 1, "One success signal: " + obstacle_id)
		check(uses.back() == ["1,1", 0, data.OBSTACLE_TOOLS[obstacle_id]], "Correct signal target")
		if obstacle["required_tool_tier"] > 0:
			state.tool_tier = 0
			state.sector_tiles["1,1"] = [state._create_obstacle_tile(obstacle_id)]
			var before: Dictionary = state.sector_tiles["1,1"][0].duplicate(true)
			old_count = uses.size()
			var coins_before: int = state.coins
			state.interact_with_tile("1,1", 0)
			check(state.sector_tiles["1,1"][0] == before, "Locked target remains intact")
			check(uses.size() == old_count and state.coins == coins_before, "Blocked hit has no success/reward")
	# Existing damage and final rewards; hitting the cleared tile cannot repeat rewards.
	for tier in range(4):
		state.tool_tier = tier
		state.coins = 100
		state.wood = 0
		state.sector_tiles["1,1"] = [state._create_obstacle_tile("small_wood")]
		var old_count = uses.size()
		state.interact_with_tile("1,1", 0)
		if tier < 2:
			check(state.wood == 0, "First wooden/copper hit grants no partial reward")
			check(state.sector_tiles["1,1"][0]["taps_left"] == 1, "Basic damage is one")
			state.interact_with_tile("1,1", 0)
		check(state.sector_tiles["1,1"][0]["type"] == "soil", "Clearing makes soil")
		check(state.wood == 2 and state.coins == 105, "Clearing grants drops exactly once")
		var count_after_clear = uses.size()
		state.seed_inventory["wheat"] = 2
		state.selected_crop = "wheat"
		state.interact_with_tile("1,1", 0)
		check(state.wood == 2 and state.coins == 105 and uses.size() == count_after_clear, "Planting cannot replay tool/drop")
		check(count_after_clear - old_count == (2 if tier < 2 else 1), "Tier clearing speed")
	# Tilling keeps its existing price and has no effect on unaffordable attempts.
	state.sector_tiles["1,1"] = [{"type": "grass"}]
	state.coins = 4
	var count_before = uses.size()
	state.interact_with_tile("1,1", 0)
	check(state.coins == 4 and state.sector_tiles["1,1"][0]["type"] == "grass" and uses.size() == count_before, "Unaffordable tilling")
	state.coins = 5
	state.interact_with_tile("1,1", 0)
	check(state.coins == 0 and state.sector_tiles["1,1"][0]["type"] == "soil", "Tilling costs five")
	check(uses.back()[2] == "hoe" and uses.size() == count_before + 1, "Tilling emits hoe")
	# Sequential shared purchases use the unchanged prices and never charge on failure.
	state.tool_tier = 0
	state.coins = 0
	state.wood = 0
	state.stone = 0
	check(not state.upgrade_tool() and state.tool_tier == 0, "Unaffordable upgrade")
	for tier in range(1, 4):
		var price: Dictionary = data.TOOL_TIERS[tier]
		state.coins = price["cost_coins"]
		state.wood = price["cost_wood"]
		state.stone = price["cost_stone"]
		check(state.upgrade_tool(), "Affordable shared upgrade")
		check(state.tool_tier == tier and state.coins == 0 and state.wood == 0 and state.stone == 0, "Exact shared upgrade charge")
	check(not state.upgrade_tool() and state.tool_tier == 3, "Golden is final")
	# A legacy save contains just the shared tool_tier, with the existing inventory schema.
	var legacy = {"tool_tier": 2, "coins": 321, "wood": 45, "stone": 67, "relics": 8,
		"current_sector": "1,1", "unlocked_sectors": ["1,1", "1,0"],
		"sector_tiles": {"1,1": [{"type": "barn"}, {"type": "grass"}]}, "seed_inventory": {"wheat": 7},
		"barn_inventory": [{"id": "wheat", "name": "Wheat", "count": 3}]}
	var file = FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.load_game()
	check(state.tool_tier == 2 and state.coins == 321 and state.wood == 45 and state.stone == 67 and state.relics == 8, "Legacy tier/resources preserved")
	check(state.seed_inventory["wheat"] == 7 and state.barn_inventory[0]["count"] == 3 and state.is_sector_unlocked("1,0"), "Legacy inventory/land preserved")
	check(state.sector_tiles["1,1"][1]["type"] == "grass", "Legacy farm preserved")
	state.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	check(saved["tool_tier"] == 2 and not saved.has("tools"), "Save schema remains compatible")
	# Menu behavior and cosmetic effects in the actual scene.
	state._generate_sector_tiles("1,1")
	var farm = load("res://scenes/main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	await process_frame
	var coins_before: int = state.coins
	farm.dock_tool_btn.pressed.emit()
	check(farm.tool_menu.visible and farm._farm_modal_open(), "Dock opens blocking tools menu")
	check(state.coins == coins_before and state.tool_tier == 2, "Opening menu cannot buy upgrade")
	check(farm.tool_menu.upgrade_button.disabled and "Need" in farm.tool_menu.missing_label.text, "Missing resources shown")
	state.coins = 3000
	state.wood = 150
	state.stone = 150
	state.state_updated.emit()
	check(not farm.tool_menu.upgrade_button.disabled, "Affordable button enabled")
	farm.tool_menu.upgrade_button.pressed.emit()
	check(state.tool_tier == 3 and farm.tool_menu.upgrade_button.disabled and farm.tool_menu.upgrade_button.text == "Fully upgraded", "Upgrade refreshes menu")
	farm._open_seed_modal()
	check(not farm.tool_menu.visible and farm.seed_modal.visible, "Competing menus close")
	farm._open_tool_menu()
	check(not farm.seed_modal.visible, "Tools closes competing menu")
	farm._close_farm_menus()
	for tool_id in data.TOOLS:
		for tier in range(4):
			check(load(data.get_tool_icon_path(tool_id, tier)) is Texture2D, "Every illustrated tier icon imports")
		farm.tool_effects.play(0, Vector2.ZERO, tool_id, 0, "Test")
	check(farm.tool_effects.active.size() == 1, "Rapid effects replace, never queue")
	state.current_sector_coord = "1,0"
	farm._refresh_ui()
	check(farm.tool_effects.active.is_empty(), "Sector change cancels effects")
	farm.tool_effects.play(0, Vector2.ZERO, "axe", 3, "Test")
	await create_timer(0.8).timeout
	check(farm.tool_effects.active.is_empty(), "Effects clean up after animation")
	print("PASS: tools, restrictions, prices, shared upgrades, legacy saves, menu and effect lifecycle" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
