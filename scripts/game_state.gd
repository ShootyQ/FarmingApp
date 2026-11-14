extends Node

# Central Game State & Persistence Singleton
# Handles inventory, tool tiers, sectors, tiles, and offline growth

signal state_updated
signal tile_updated(sector_coord: String, tile_idx: int)
signal message_broadcast(text: String, is_reward: bool)
signal barn_opened
signal barn_updated
signal farm_replaced
signal tool_used(sector_coord: String, tile_idx: int, tool_id: String)

var coins: int = 150
var wood: int = 10
var stone: int = 5
var relics: int = 0

var tool_tier: int = 0
var selected_crop: String = "wheat"
var current_sector_coord: String = "1,1"

# Seed Inventory / Seed Pouch (Stock of seeds held by player)
var seed_inventory: Dictionary = {
	"wheat": 8,
	"carrot": 0,
	"strawberry": 0,
	"pumpkin": 0
}

# Barn Storage: 10 spaces, stack size up to 10
const BARN_SLOTS_MAX: int = 10
const BARN_STACK_MAX: int = 10
var barn_inventory: Array = []

# Unlocked sectors list
var unlocked_sectors: Array[String] = ["1,1"]

# Sector tiles: original 16 plots first, followed by the surrounding meadow.
var sector_tiles: Dictionary = {}

var resource_last_tick: Dictionary = {}
const BACKUP_PATH = "user://farm_save_backup.json"
const SAVE_PATH = "user://farm_save.json"

func _ready():
	load_game()

func get_tool_info() -> Dictionary:
	return GameData.TOOL_TIERS[tool_tier]

func can_upgrade_tool() -> bool:
	if tool_tier >= GameData.TOOL_TIERS.size() - 1:
		return false
	var next_tool = GameData.TOOL_TIERS[tool_tier + 1]
	return coins >= next_tool["cost_coins"] and wood >= next_tool["cost_wood"] and stone >= next_tool["cost_stone"]

func upgrade_tool() -> bool:
	if not can_upgrade_tool():
		return false
	var next_tool = GameData.TOOL_TIERS[tool_tier + 1]
	coins -= next_tool["cost_coins"]
	wood -= next_tool["cost_wood"]
	stone -= next_tool["cost_stone"]
	tool_tier += 1
	message_broadcast.emit("Upgraded to %s!" % next_tool["name"], true)
	save_game()
	state_updated.emit()
	return true

func is_sector_unlocked(coord: String) -> bool:
	return coord in unlocked_sectors

func is_sector_adjacent_to_unlocked(coord: String) -> bool:
	var parts = coord.split(",")
	var x = int(parts[0])
	var y = int(parts[1])
	
	var neighbors = [
		"%d,%d" % [x + 1, y],
		"%d,%d" % [x - 1, y],
		"%d,%d" % [x, y + 1],
		"%d,%d" % [x, y - 1]
	]
	
	for n in neighbors:
		if n in unlocked_sectors:
			return true
	return false

func unlock_sector(coord: String) -> bool:
	if is_sector_unlocked(coord):
		return false
	if not is_sector_adjacent_to_unlocked(coord):
		message_broadcast.emit("Must unlock an adjacent sector first!", false)
		return false
	
	var sector_data = GameData.SECTORS.get(coord, {})
	var cost = sector_data.get("cost", 999999)
	if coins < cost:
		message_broadcast.emit("Not enough coins! Need %d c" % cost, false)
		return false
	
	coins -= cost
	unlocked_sectors.append(coord)
	_generate_sector_tiles(coord)
	message_broadcast.emit(" Unlocked %s!" % sector_data.get("name", "New Land"), true)
	save_game()
	state_updated.emit()
	return true

func _generate_sector_tiles(coord: String):
	var tiles: Array = []
	var is_homestead = coord == "1,1"
	var supply = ["small_wood", "small_wood", "small_wood", "small_wood", "small_rock", "small_rock", "small_rock", "small_rock", "weed", "hardwood_stump", "granite_boulder"]
	var supply_idx = 0
	for i in range(16):
		var tile: Dictionary = {}
		if is_homestead and i in [5, 6, 9, 10]:
			tiles_become_soil(tile)
		elif is_homestead and i == 0:
			tile = {"type": "barn"}
		else:
			var kind: String = supply[supply_idx] if supply_idx < supply.size() else ["weed", "hardwood_stump", "granite_boulder", "ancient_relic_mound"].pick_random()
			tile = _create_obstacle_tile(kind)
			supply_idx += 1
		tiles.append(tile)
	sector_tiles[coord] = tiles
	resource_last_tick[coord] = Time.get_unix_time_from_system()
	_ensure_meadow_tiles(coord)

func _ensure_meadow_tiles(coord: String):
	# Expansion adds clear grass without replacing any saved tile.
	var tiles: Array = sector_tiles[coord]
	while tiles.size() < GameData.MEADOW_TILE_COUNT:
		tiles.append({"type": "grass"})

func _create_obstacle_tile(obs_id: String) -> Dictionary:
	var data = GameData.OBSTACLES[obs_id]
	return {
		"type": "obstacle",
		"obstacle_id": obs_id,
		"taps_left": data["taps_max"],
		"variant": randi() % 4
	}

# Context-sensitive interaction with a tile
func interact_with_tile(sector_coord: String, tile_idx: int):
	update_crop_timers()
	if not is_sector_unlocked(sector_coord):
		return
	
	var tiles = sector_tiles.get(sector_coord, [])
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	
	var tile = tiles[tile_idx]
	var tile_type = tile.get("type", "grass")
	var tool_id = GameData.get_tool_for_tile(tile)
	var used_tool = false
	
	match tile_type:
		"obstacle":
			used_tool = _handle_tap_obstacle(sector_coord, tile_idx, tile)
		"soil":
			_handle_tap_soil(sector_coord, tile_idx, tile)
		"grass":
			used_tool = _handle_tap_grass(sector_coord, tile_idx, tile)
		"preparing":
			message_broadcast.emit("Preparing soil: %s remaining" % GameData.format_time(float(tile["prepare_started_at"]) + float(tile["prepare_duration"]) - Time.get_unix_time_from_system()), false)
		"barn":
			barn_opened.emit()
	
	tile_updated.emit(sector_coord, tile_idx)
	if used_tool:
		tool_used.emit(sector_coord, tile_idx, tool_id)
	state_updated.emit()
	save_game()

func _handle_tap_obstacle(sector_coord: String, tile_idx: int, tile: Dictionary) -> bool:
	var obs_id = tile["obstacle_id"]
	var data = GameData.OBSTACLES[obs_id]
	
	# Check required tool tier
	if tool_tier < data["required_tool_tier"]:
		var req_tier_name = GameData.TOOL_TIERS[data["required_tool_tier"]]["name"]
		message_broadcast.emit("Requires %s to clear!" % req_tier_name, false)
		return false
	
	# Clearing strength follows the shared toolkit tier.
	var damage: int = get_tool_info()["damage"]
	tile["taps_left"] = max(0, tile["taps_left"] - damage)
	
	if tile["taps_left"] > 0:
		message_broadcast.emit("Chipping away at %s... (%d taps left)" % [data["name"], ceili(float(tile["taps_left"]) / damage)], false)
	else:
		# Obstacle cleared! Give drops
		var drop_text = "Cleared %s! " % data["name"]
		for res in data["drops"]:
			var amount = data["drops"][res]
			match res:
				"coins": coins += amount; drop_text += "+%dc " % amount
				"wood": wood += amount; drop_text += "+%d " % amount
				"stone": stone += amount; drop_text += "+%d " % amount
				"relics": relics += amount; drop_text += "+%d " % amount
		
		# Check relic chance
		var relic_bonus = 1.5 if tool_tier >= 3 else 1.0
		if randf() < (data["relic_chance"] * relic_bonus):
			relics += 1
			drop_text += " [Found Rare Relic!]"
		
		# Clearing grants materials; preparing new land is a separate investment.
		tile.clear()
		tile["type"] = "grass"
		message_broadcast.emit(drop_text, true)
	return true

func tiles_become_soil(tile: Dictionary):
	tile.clear()
	tile["type"] = "soil"
	tile["state"] = "empty"
	tile["crop"] = ""
	tile["is_mutated"] = false
	tile["plant_time"] = 0.0
	tile["grow_duration"] = 0.0

func get_preparation_count() -> int:
	var count = 0
	for tiles in sector_tiles.values():
		for tile in tiles:
			if tile.get("type") == "preparing":
				count += 1
	return count

func get_preparation_limit() -> int:
	return int(get_tool_info()["preparation_slots"])

func get_next_plot_cost() -> int:
	var count = 0
	for tiles in sector_tiles.values():
		for tile in tiles:
			if tile.get("type") in ["soil", "preparing"]:
				count += 1
	return 25 + 10 * maxi(0, count - 4)

func _handle_tap_grass(_sector_coord: String, _tile_idx: int, tile: Dictionary) -> bool:
	if get_preparation_count() >= get_preparation_limit():
		message_broadcast.emit("All %d preparation slots are busy. Wait for a plot to finish." % get_preparation_limit(), false)
		return false
	var cost = get_next_plot_cost()
	if coins < cost:
		message_broadcast.emit("Need %d coins to prepare this plot." % cost, false)
		return false
	coins -= cost
	tile.clear()
	tile.merge({"type": "preparing", "prepare_started_at": Time.get_unix_time_from_system(), "prepare_duration": GameData.PREPARATION_SECONDS})
	message_broadcast.emit("Preparing soil — 5:00 (-%d coins)" % cost, true)
	return true

func _handle_tap_soil(sector_coord: String, tile_idx: int, tile: Dictionary):
	var state = tile["state"]
	
	if state == "empty":
		# Plant selected seed from seed inventory
		var crop_data = GameData.CROPS.get(selected_crop, {})
		var crop_name = crop_data.get("name", "Crop")
		var seed_count = get_seed_count(selected_crop)
		if seed_count > 0:
			seed_inventory[selected_crop] -= 1
			tile["state"] = "growing"
			tile["crop"] = selected_crop
			tile["plant_time"] = Time.get_unix_time_from_system()
			tile["grow_duration"] = crop_data["grow_time"]
			tile["is_mutated"] = (randf() < crop_data["mutation_chance"])
			message_broadcast.emit("Planted %s! (%d seeds remaining in pouch)" % [crop_name, seed_inventory[selected_crop]], true)
			tile_updated.emit(sector_coord, tile_idx)
			state_updated.emit()
			save_game()
		else:
			message_broadcast.emit("Out of %s seeds! Click Active Seed on dock to buy more." % crop_name, false)
			
	elif state == "ready":
		# Harvest crop directly into Barn storage (no direct coins)
		var is_mutated = tile.get("is_mutated", false)
		var item_id = tile["crop"]
		if is_mutated:
			match tile["crop"]:
				"wheat": item_id = "golden_wheat"
				"carrot": item_id = "crystal_carrot"
				"strawberry": item_id = "jeweled_berry"
				"pumpkin": item_id = "haunted_pumpkin"
		
		var item_info = GameData.get_item_info(item_id)
		
		# Attempt to store in Barn (10 slots max, 10 per stack)
		var added = add_to_barn(item_id, 1)
		if not added:
			message_broadcast.emit("Barn is full! (10/10 slots). Click the Barn to inspect.", false)
			return
			
		if is_mutated:
			message_broadcast.emit("LEGENDARY HARVEST! Stored %s in Barn!" % item_info["name"], true)
		else:
			message_broadcast.emit("Harvested %s! Stored in Barn." % item_info["name"], true)
		
		# Reset soil to empty
		tile["state"] = "empty"
		tile["crop"] = ""
		tile["is_mutated"] = false
		tile["plant_time"] = 0.0
		tile["grow_duration"] = 0.0
		
	elif state == "growing":
		var now = Time.get_unix_time_from_system()
		var elapsed = now - tile["plant_time"]
		var remaining = max(0.0, tile["grow_duration"] - elapsed)
		message_broadcast.emit("Crop is growing... %s left" % GameData.format_time(remaining), false)

# One-second UI ticks and input both settle jobs against absolute saved timestamps.
func update_crop_timers(now: float = -1.0):
	if now < 0:
		now = Time.get_unix_time_from_system()
	var changed = false
	for coord in sector_tiles:
		var tiles: Array = sector_tiles[coord]
		for i in range(tiles.size()):
			var tile: Dictionary = tiles[i]
			if tile.get("type") == "preparing" and now >= float(tile["prepare_started_at"]) + float(tile["prepare_duration"]):
				tiles_become_soil(tile)
				tile_updated.emit(coord, i)
				changed = true
			elif tile.get("type") == "soil" and tile.get("state") == "growing":
				if now - float(tile["plant_time"]) >= float(tile["grow_duration"]):
					tile["state"] = "ready"
					tile_updated.emit(coord, i)
					changed = true
		changed = _replenish_resources(coord, now) or changed
	if changed:
		save_game()
		state_updated.emit()

func _replenish_resources(coord: String, now: float) -> bool:
	if not is_sector_unlocked(coord):
		return false
	if not resource_last_tick.has(coord):
		resource_last_tick[coord] = now
		return false
	var ticks = floori((now - float(resource_last_tick[coord])) / GameData.RESOURCE_INTERVAL)
	if ticks <= 0:
		return false
	resource_last_tick[coord] = float(resource_last_tick[coord]) + ticks * GameData.RESOURCE_INTERVAL
	var tiles: Array = sector_tiles[coord]
	var available: Array[int] = []
	var counts = {"small_wood": 0, "small_rock": 0}
	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		if tile.get("type") == "grass":
			available.append(i)
		elif tile.get("type") == "obstacle" and counts.has(tile.get("obstacle_id", "")):
			counts[tile["obstacle_id"]] += 1
	available.sort_custom(func(a, b): return GameData.farm_coordinates[a].length_squared() < GameData.farm_coordinates[b].length_squared())
	for kind in counts:
		var amount = mini(mini(ticks, GameData.RESOURCE_CAP - int(counts[kind])), available.size())
		for _i in range(maxi(0, amount)):
			var idx: int = available.pop_front()
			tiles[idx] = _create_obstacle_tile(kind)
			tile_updated.emit(coord, idx)
	# Persist the consumed tick even if the grass is full; never bank extra spawns.
	return true

# Persistence
func get_save_data() -> Dictionary:
	return {
		"economy_version": 2,
		"resource_last_tick": resource_last_tick,
		"coins": coins,
		"wood": wood,
		"stone": stone,
		"relics": relics,
		"tool_tier": tool_tier,
		"current_sector": current_sector_coord,
		"unlocked_sectors": unlocked_sectors,
		"sector_tiles": sector_tiles,
		"barn_inventory": barn_inventory,
		"seed_inventory": seed_inventory,
		"save_time": Time.get_unix_time_from_system()
	}
func _write_save_data(path: String, data: Dictionary) -> bool:
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var success = file.get_error() == OK
	file.close()
	if not success or typeof(JSON.parse_string(FileAccess.get_file_as_string(temporary))) != TYPE_DICTIONARY:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK

func save_game() -> bool:
	return _write_save_data(SAVE_PATH, get_save_data())

func has_farm_backup() -> bool:
	return FileAccess.file_exists(BACKUP_PATH)

func start_new_farm() -> bool:
	update_crop_timers()
	var previous: Dictionary = get_save_data().duplicate(true)
	if not _write_save_data(BACKUP_PATH, previous):
		message_broadcast.emit("Could not back up your farm. Nothing was reset.", false)
		return false
	coins = 150
	wood = 10
	stone = 5
	relics = 0
	tool_tier = 0
	selected_crop = "wheat"
	current_sector_coord = "1,1"
	unlocked_sectors.assign(["1,1"])
	sector_tiles = {}
	resource_last_tick = {}
	barn_inventory = []
	seed_inventory = {"wheat": 8, "carrot": 0, "strawberry": 0, "pumpkin": 0}
	_generate_sector_tiles("1,1")
	if not save_game():
		_apply_save_data(previous)
		message_broadcast.emit("Could not save the new farm. Your original farm is still active.", false)
		return false
	farm_replaced.emit()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("New farm ready! Your previous farm is backed up on this device.", true)
	return true

func _valid_backup(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for key in ["coins", "wood", "stone", "relics", "tool_tier"]:
		if typeof(data.get(key)) not in [TYPE_INT, TYPE_FLOAT] or float(data[key]) < 0:
			return false
	if int(data["tool_tier"]) >= GameData.TOOL_TIERS.size():
		return false
	if typeof(data.get("sector_tiles")) != TYPE_DICTIONARY or typeof(data.get("seed_inventory")) != TYPE_DICTIONARY or typeof(data.get("barn_inventory")) != TYPE_ARRAY or typeof(data.get("unlocked_sectors")) != TYPE_ARRAY:
		return false
	if not data["sector_tiles"].has("1,1"):
		return false
	for tiles in data["sector_tiles"].values():
		if typeof(tiles) != TYPE_ARRAY or tiles.size() < 16:
			return false
		for tile in tiles:
			if typeof(tile) != TYPE_DICTIONARY or tile.get("type", "") not in ["soil", "grass", "obstacle", "barn", "preparing"]:
				return false
	return true

func restore_previous_farm() -> bool:
	var parser = JSON.new()
	var parsed_ok = parser.parse(FileAccess.get_file_as_string(BACKUP_PATH)) == OK
	var data = parser.data if parsed_ok else null
	if not _valid_backup(data):
		message_broadcast.emit("The previous farm backup could not be read. Nothing changed.", false)
		return false
	if not _write_save_data(SAVE_PATH, data):
		message_broadcast.emit("Could not restore the backup. Your current farm is unchanged.", false)
		return false
	load_game()
	farm_replaced.emit()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("Previous farm restored.", true)
	return true

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		# First time setup
		_generate_sector_tiles("1,1")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_generate_sector_tiles("1,1")
		return
	
	var json_str = file.get_as_text()
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		_generate_sector_tiles("1,1")
		return
	
	_apply_save_data(parsed)

func _apply_save_data(parsed: Dictionary):
	resource_last_tick = parsed.get("resource_last_tick", {}).duplicate(true)
	coins = parsed.get("coins", 150)
	wood = parsed.get("wood", 10)
	stone = parsed.get("stone", 5)
	relics = parsed.get("relics", 0)
	tool_tier = parsed.get("tool_tier", 0)
	current_sector_coord = parsed.get("current_sector", "1,1")
	
	var loaded_unlocked = parsed.get("unlocked_sectors", ["1,1"])
	unlocked_sectors.clear()
	for s in loaded_unlocked:
		unlocked_sectors.append(str(s))
	
	sector_tiles = parsed.get("sector_tiles", {})
	if not "1,1" in sector_tiles:
		_generate_sector_tiles("1,1")
	
	for coord in sector_tiles:
		_ensure_meadow_tiles(coord)
		if not resource_last_tick.has(coord):
			resource_last_tick[coord] = Time.get_unix_time_from_system()

	# Load barn storage
	barn_inventory = parsed.get("barn_inventory", [])
	
	# Load seed inventory
	var loaded_seeds = parsed.get("seed_inventory", {})
	if typeof(loaded_seeds) == TYPE_DICTIONARY and loaded_seeds.size() > 0:
		seed_inventory = loaded_seeds
	else:
		seed_inventory = {"wheat": 10, "carrot": 5, "strawberry": 2, "pumpkin": 0}
	for cid in GameData.CROPS:
		if not cid in seed_inventory:
			seed_inventory[cid] = 0
	
	# Ensure Homestead tile 0 is always the Red Barn
	var h_tiles = sector_tiles.get("1,1", [])
	if h_tiles.size() > 0:
		h_tiles[0] = {"type": "barn"}
	
	# Calculate offline crop growth
	update_crop_timers()

# Seed Inventory Helpers
func get_seed_count(crop_id: String) -> int:
	return int(seed_inventory.get(crop_id, 0))

func buy_seeds(crop_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not crop_id in GameData.CROPS:
		return false
	var c = GameData.CROPS[crop_id]
	var unit_cost = c.get("cost", 10)
	var total_cost = unit_cost * amount
	if coins >= total_cost:
		coins -= total_cost
		seed_inventory[crop_id] = get_seed_count(crop_id) + amount
		save_game()
		state_updated.emit()
		message_broadcast.emit("Bought %dx %s Seeds for %dc!" % [amount, c.get("name", "Crop"), total_cost], true)
		return true
	else:
		message_broadcast.emit("Need %dc to buy %dx %s Seeds!" % [total_cost, amount, c.get("name", "Crop")], false)
		return false

# Barn Inventory Management (10 slots, stack of 10 max)
func add_to_barn(item_id: String, amount: int = 1) -> bool:
	var item_info = GameData.get_item_info(item_id)
	var remaining = amount
	
	# Pass 1: Try stacking into existing slots
	for slot in barn_inventory:
		if slot.get("id") == item_id and slot.get("count", 0) < BARN_STACK_MAX:
			var can_add = min(remaining, BARN_STACK_MAX - slot["count"])
			slot["count"] += can_add
			remaining -= can_add
			if remaining <= 0:
				save_game()
				barn_updated.emit()
				return true
				
	# Pass 2: Fill empty slots if barn has fewer than 10 slots
	while remaining > 0 and barn_inventory.size() < BARN_SLOTS_MAX:
		var take = min(remaining, BARN_STACK_MAX)
		barn_inventory.append({
			"id": item_id,
			"name": item_info.get("name", item_id.capitalize()),
			"count": take,
			"sell_value": item_info.get("sell_value", 10),
			"icon": item_info.get("icon", ""),
			"desc": item_info.get("desc", "")
		})
		remaining -= take
		
	save_game()
	barn_updated.emit()
	return remaining == 0

func get_barn_used_slots() -> int:
	return barn_inventory.size()

# Selling items from Barn to Market / Vendor
func sell_from_barn(slot_idx: int, amount: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= barn_inventory.size():
		return false
	var slot = barn_inventory[slot_idx]
	var count = slot.get("count", 0)
	var sell_amount = min(amount, count)
	if sell_amount <= 0:
		return false
		
	var item_info = GameData.get_item_info(slot["id"])
	var unit_price = item_info.get("sell_value", 10)
	var total_payout = unit_price * sell_amount
	
	coins += total_payout
	slot["count"] -= sell_amount
	
	if slot["count"] <= 0:
		barn_inventory.remove_at(slot_idx)
		
	save_game()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("Sold %d %s for +%dc!" % [sell_amount, item_info["name"], total_payout], true)
	return true

func sell_all_from_barn() -> int:
	var total_payout = 0
	var total_items = 0
	for slot in barn_inventory:
		var item_info = GameData.get_item_info(slot["id"])
		var unit_price = item_info.get("sell_value", 10)
		total_payout += unit_price * slot["count"]
		total_items += slot["count"]
	
	if total_payout == 0:
		message_broadcast.emit("No crops in the Barn to sell!", false)
		return 0
		
	coins += total_payout
	barn_inventory.clear()
	save_game()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("Sold entire barn harvest (%d items) for +%dc!" % [total_items, total_payout], true)
	return total_payout
