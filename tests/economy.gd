extends SceneTree

var failures = 0
func _initialize():
	call_deferred("run")
func check(condition: bool, message: String):
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func count_kind(state, kind: String) -> int:
	var count = 0
	for tile in state.sector_tiles["1,1"]:
		if tile.get("type") == "obstacle" and tile.get("obstacle_id") == kind:
			count += 1
	return count
func grass_index(state, excluded: Array = []) -> int:
	for i in range(state.sector_tiles["1,1"].size()):
		if i not in excluded and state.sector_tiles["1,1"][i].get("type") == "grass":
			return i
	return -1

func run():
	var state = root.get_node("GameState")
	var data = root.get_node("GameData")
	check(state.start_new_farm(), "Atomic new-farm save succeeds")
	check(state.coins == 150 and state.wood == 10 and state.stone == 5 and state.seed_inventory == {"wheat":8,"carrot":0,"strawberry":0,"pumpkin":0}, "Fresh-start economy")
	check(count_kind(state,"small_wood") == 4 and count_kind(state,"small_rock") == 4, "Guaranteed starting materials")
	check(state.get_next_plot_cost() == 25 and state.get_preparation_limit() == 2, "Starter land pricing and capacity")
	check(data.format_time(300) == "5:00" and data.format_time(29.1) == "0:30", "Readable countdowns")
	var specs = {"wheat":[8,12,30], "carrot":[20,34,90], "strawberry":[45,78,180], "pumpkin":[90,150,300]}
	for crop in specs:
		var definition: Dictionary = data.CROPS[crop]
		check(definition["cost"] == specs[crop][0] and definition["reward"] == specs[crop][1] and definition["grow_time"] == specs[crop][2], "Crop economics: " + crop)
		check(is_equal_approx(definition["mutation_chance"], 0.05), "Five percent mutations")
		check(data.get_item_info(crop)["sell_value"] == definition["reward"] and data.get_item_info(data.RARE_CROP_ITEMS[crop])["sell_value"] == 2 * definition["reward"], "Single-source normal and rare prices")
	var first: int = grass_index(state)
	var second: int = grass_index(state,[first])
	var third: int = grass_index(state,[first,second])
	state.interact_with_tile("1,1",first)
	state.interact_with_tile("1,1",second)
	check(state.coins == 90 and state.get_preparation_count() == 2 and state.get_next_plot_cost() == 45, "First plots cost 25 and 35")
	state.interact_with_tile("1,1",first)
	state.interact_with_tile("1,1",third)
	check(state.coins == 90 and state.sector_tiles["1,1"][third]["type"] == "grass", "Repeat and full-capacity taps never charge")
	state._generate_sector_tiles("1,0")
	state.unlocked_sectors.append("1,0")
	state.interact_with_tile("1,0",16)
	check(state.coins == 90 and state.sector_tiles["1,0"][16]["type"] == "grass", "Slots are shared across sectors")
	var started: float = state.sector_tiles["1,1"][first]["prepare_started_at"]
	state.coins = 1000
	state.wood = 20
	state.stone = 20
	check(state.upgrade_tool() and state.get_preparation_limit() == 3, "Copper unlocks a third slot")
	check(state.sector_tiles["1,1"][first]["prepare_started_at"] == started and state.sector_tiles["1,1"][first]["prepare_duration"] == 300, "Upgrade never resets or accelerates running jobs")
	state.coins = 100
	state.interact_with_tile("1,1",third)
	check(state.coins == 55 and state.get_preparation_count() == 3, "New slot usable immediately")
	state.sector_tiles["1,1"][first]["prepare_started_at"] -= 301
	check(state.save_game(), "Preparation saves")
	state.load_game()
	check(state.sector_tiles["1,1"][first]["type"] == "soil" and state.get_preparation_count() == 2 and state.coins == 55, "Offline completion frees slots without charging")
	for tier in range(4):
		state.tool_tier = tier
		check(state.get_preparation_limit() == tier + 2 and state.get_tool_info()["damage"] == [1,1,2,3][tier], "Tier slots and damage")
	state.tool_tier = 0
	state.coins = 0
	var unfunded: int = grass_index(state)
	state.interact_with_tile("1,1",unfunded)
	check(state.coins == 0 and state.sector_tiles["1,1"][unfunded]["type"] == "grass", "Insufficient funds never start jobs")
	# Existing crop durations are saved per tile; future plants use the new table.
	for crop in specs:
		for rare in [false,true]:
			state.tiles_become_soil(state.sector_tiles["1,1"][5])
			state.seed_inventory[crop] = 1
			state.selected_crop = crop
			state.barn_inventory = []
			state.interact_with_tile("1,1",5)
			check(state.sector_tiles["1,1"][5]["grow_duration"] == specs[crop][2], "New crop duration")
			state.sector_tiles["1,1"][5]["is_mutated"] = rare
			state.sector_tiles["1,1"][5]["plant_time"] -= specs[crop][2] + 1
			state.update_crop_timers()
			state.interact_with_tile("1,1",5)
			var before: int = state.coins
			check(state.sell_all_from_barn() == specs[crop][1] * (2 if rare else 1), "Actual normal/rare market payout")
			check(state.coins == before + specs[crop][1] * (2 if rare else 1) and state.sector_tiles["1,1"][5]["state"] == "empty", "Harvest leaves permanent soil")
	state.sector_tiles["1,1"][5].merge({"state":"growing","crop":"wheat","is_mutated":false,"plant_time":Time.get_unix_time_from_system()-6,"grow_duration":5},true)
	state.save_game()
	state.load_game()
	check(state.sector_tiles["1,1"][5]["state"] == "ready" and state.sector_tiles["1,1"][5]["grow_duration"] == 5, "Legacy five-second crop finishes unchanged")
	# Respawns respect caps, timestamps, and occupied land, including offline catch-up.
	var tiles: Array = []
	for i in range(400): tiles.append({"type":"grass"})
	tiles[0] = {"type":"barn"}
	tiles[5] = {"type":"soil","state":"empty"}
	tiles[6] = {"type":"soil","state":"growing","crop":"wheat","plant_time":Time.get_unix_time_from_system(),"grow_duration":100000}
	tiles[7] = {"type":"preparing","prepare_started_at":Time.get_unix_time_from_system(),"prepare_duration":100000}
	state.sector_tiles = {"1,1":tiles}
	var now = Time.get_unix_time_from_system()
	state.resource_last_tick = {"1,1": now-120}
	state.update_crop_timers(now)
	check(count_kind(state,"small_wood") == 1 and count_kind(state,"small_rock") == 1, "One resource of each type per two minutes")
	state.update_crop_timers(now)
	check(count_kind(state,"small_wood") == 1, "Repeated ticks cannot duplicate resources")
	state.update_crop_timers(now+86400)
	check(count_kind(state,"small_wood") == 4 and count_kind(state,"small_rock") == 4, "Offline resources capped at four each")
	check(tiles[0]["type"] == "barn" and tiles[5]["type"] == "soil" and tiles[6]["type"] == "soil" and tiles[7]["type"] == "preparing", "Respawns protect buildings, soil, crops, and jobs")
	for i in range(1,400): tiles[i] = {"type":"soil","state":"empty"}
	state.resource_last_tick = {"1,1":now-1200}
	state.update_crop_timers(now)
	tiles[1] = {"type":"grass"}
	state.update_crop_timers(now+1)
	check(tiles[1]["type"] == "grass", "Full land cannot bank extra spawns")
	# Resource clearing supplies a recovery route even with no coins or seeds.
	state.coins = 0
	state.sector_tiles["1,1"][1] = state._create_obstacle_tile("small_wood")
	state.sector_tiles["1,1"][2] = state._create_obstacle_tile("small_rock")
	for _i in range(2): state.interact_with_tile("1,1",1)
	for _i in range(3): state.interact_with_tile("1,1",2)
	check(state.coins == 10 and state.sector_tiles["1,1"][1]["type"] == "grass", "Clearing earns recovery coins but never free soil")
	check(state.buy_seeds("wheat",1) and state.coins == 2, "Recovery income buys a seed")
	# Confirmed restart/restore and safe failure paths.
	state.coins = 2497
	state.tool_tier = 2
	state.barn_inventory = [{"id":"wheat","name":"Wheat","count":3}]
	state.sector_tiles["1,1"][1] = {"type":"preparing","prepare_started_at":now,"prepare_duration":300}
	state.resource_last_tick["1,1"] = now
	check(state.save_game() and state.start_new_farm(), "Restart backs up before writing a fresh farm")
	check(state.coins == 150 and state.tool_tier == 0 and state.get_preparation_count() == 0 and state.seed_inventory["wheat"] == 8, "Confirmed restart resets only to the new starter package")
	check(state.restore_previous_farm(), "Backup restores")
	check(state.coins == 2497 and state.tool_tier == 2 and state.barn_inventory[0]["count"] == 3 and absf(float(state.sector_tiles["1,1"][1]["prepare_started_at"]) - now) < 0.001, "Restore preserves wealth, inventory and job timestamps")
	var failed_script = GDScript.new()
	failed_script.source_code = 'extends "res://scripts/game_state.gd"\nfunc _write_save_data(path: String, data: Dictionary) -> bool:\n\tif path == BACKUP_PATH: return false\n\treturn super._write_save_data(path, data)\n'
	check(failed_script.reload() == OK, "Backup-failure fixture compiles after autoload")
	var failed = failed_script.new()
	root.add_child(failed)
	check(not failed.start_new_farm() and failed.coins == 2497 and failed.tool_tier == 2, "Backup failure aborts restart")
	failed.queue_free()
	var failed_save_script = GDScript.new()
	failed_save_script.source_code = 'extends "res://scripts/game_state.gd"\nfunc save_game() -> bool:\n\treturn false\n'
	check(failed_save_script.reload() == OK, "Save-failure fixture compiles")
	var failed_save = failed_save_script.new()
	root.add_child(failed_save)
	check(not failed_save.start_new_farm() and failed_save.coins == 2497 and failed_save.tool_tier == 2, "Fresh-save failure restores in-memory farm")
	failed_save.queue_free()
	var file = FileAccess.open(state.BACKUP_PATH,FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	check(not state.restore_previous_farm() and state.coins == 2497, "Invalid backup never replaces current farm")
	var farm = load("res://scenes/main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	await process_frame
	farm._open_tool_menu()
	farm.tool_menu._show_confirmation(false)
	check(farm.tool_menu.confirmation.visible and state.coins == 2497, "Opening confirmation is harmless")
	farm.tool_menu.confirmation.find_child("Cancel",true,false).pressed.emit()
	check(not farm.tool_menu.confirmation.visible and state.coins == 2497, "Cancel keeps current farm")
	farm.tool_menu._show_confirmation(false)
	farm.tool_menu.confirmation_action.pressed.emit()
	check(state.coins == 150 and not farm.tool_menu.visible and farm.rendered_tool_tier == 0, "Confirmed UI restart refreshes the whole farm")
	print("PASS: economy, preparation, offline timers, resources, pricing, legacy growth, restart and restore" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
