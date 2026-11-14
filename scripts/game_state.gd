extends Node

# Central Game State & Persistence Singleton
# Handles inventory, tool tiers, sectors, tiles, and offline growth

signal state_updated
signal tile_updated(sector_coord: String, tile_idx: int)
signal message_broadcast(text: String, is_reward: bool)
signal barn_opened
signal barn_updated

var coins: int = 150
var wood: int = 10
var stone: int = 5
var relics: int = 0

var tool_tier: int = 0
var selected_crop: String = "wheat"
var current_sector_coord: String = "1,1"

# Barn Storage: 10 spaces, stack size up to 10
const BARN_SLOTS_MAX: int = 10
const BARN_STACK_MAX: int = 10
var barn_inventory: Array = []

# Unlocked sectors list
var unlocked_sectors: Array[String] = ["1,1"]

# Sector tiles data: { "1,1": [ {tile_dict}, ... 16 tiles ] }
var sector_tiles: Dictionary = {}

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
	var is_homestead = (coord == "1,1")
	
	for i in range(16): # 4x4 grid
		var tile = {}
		if is_homestead and i in [5, 6, 9, 10]:
			# 4 starter farm soil plots in the middle
			tile = {
				"type": "soil",
				"state": "empty",
				"crop": "",
				"is_mutated": false,
				"plant_time": 0.0,
				"grow_duration": 0.0
			}
		elif is_homestead and i == 0:
			# Red Barn building on the homestead
			tile = {
				"type": "barn"
			}
		else:
			# Random obstacle or clear grass based on sector
			var roll = randf()
			if roll < 0.25:
				tile = {"type": "grass"}
			elif roll < 0.50:
				tile = _create_obstacle_tile("weed")
			elif roll < 0.70:
				tile = _create_obstacle_tile("small_wood")
			elif roll < 0.85:
				tile = _create_obstacle_tile("small_rock")
			elif roll < 0.95:
				tile = _create_obstacle_tile("hardwood_stump" if randf() < 0.5 else "granite_boulder")
			else:
				tile = _create_obstacle_tile("ancient_relic_mound")
		tiles.append(tile)
	
	sector_tiles[coord] = tiles

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
	if not is_sector_unlocked(sector_coord):
		return
	
	var tiles = sector_tiles.get(sector_coord, [])
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	
	var tile = tiles[tile_idx]
	var tile_type = tile.get("type", "grass")
	
	match tile_type:
		"obstacle":
			_handle_tap_obstacle(sector_coord, tile_idx, tile)
		"soil":
			_handle_tap_soil(sector_coord, tile_idx, tile)
		"grass":
			_handle_tap_grass(sector_coord, tile_idx, tile)
		"barn":
			barn_opened.emit()
	
	tile_updated.emit(sector_coord, tile_idx)
	state_updated.emit()
	save_game()

func _handle_tap_obstacle(sector_coord: String, tile_idx: int, tile: Dictionary):
	var obs_id = tile["obstacle_id"]
	var data = GameData.OBSTACLES[obs_id]
	
	# Check required tool tier
	if tool_tier < data["required_tool_tier"]:
		var req_tier_name = GameData.TOOL_TIERS[data["required_tool_tier"]]["name"]
		message_broadcast.emit("Requires %s to clear!" % req_tier_name, false)
		return
	
	# Tap damage: Golden tools clear 2x faster
	var damage = 2 if tool_tier >= 2 else 1
	tile["taps_left"] = max(0, tile["taps_left"] - damage)
	
	if tile["taps_left"] > 0:
		message_broadcast.emit("Chipping away at %s... (%d taps left)" % [data["name"], tile["taps_left"]], false)
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
		
		# Turn tile into tilled soil ready for planting
		tiles_become_soil(tile)
		message_broadcast.emit(drop_text, true)

func tiles_become_soil(tile: Dictionary):
	tile.clear()
	tile["type"] = "soil"
	tile["state"] = "empty"
	tile["crop"] = ""
	tile["is_mutated"] = false
	tile["plant_time"] = 0.0
	tile["grow_duration"] = 0.0

func _handle_tap_grass(sector_coord: String, tile_idx: int, tile: Dictionary):
	# Till grass into farm soil for 5 coins
	var till_cost = 5
	if coins >= till_cost:
		coins -= till_cost
		tiles_become_soil(tile)
		message_broadcast.emit("Tilled fertile soil plot! (-5c)", true)
	else:
		message_broadcast.emit("Need 5 coins to till soil!", false)

func _handle_tap_soil(sector_coord: String, tile_idx: int, tile: Dictionary):
	var state = tile["state"]
	
	if state == "empty":
		# Plant selected seed
		var crop_data = GameData.CROPS.get(selected_crop, {})
		var cost = crop_data.get("cost", 10)
		if coins >= cost:
			coins -= cost
			tile["state"] = "growing"
			tile["crop"] = selected_crop
			tile["plant_time"] = Time.get_unix_time_from_system()
			tile["grow_duration"] = crop_data["grow_time"]
			
			# Check legendary mutation roll at plant time
			tile["is_mutated"] = (randf() < crop_data["mutation_chance"])
			message_broadcast.emit("Planted %s%s!" % [crop_data["emoji"], crop_data["name"]], true)
		else:
			message_broadcast.emit("Not enough coins for seeds! Need %dc" % cost, false)
			
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
		message_broadcast.emit("Crop is growing... (%ds left)" % ceil(remaining), false)

# Update crops growth status across sectors
func update_crop_timers():
	var now = Time.get_unix_time_from_system()
	for coord in sector_tiles:
		var tiles = sector_tiles[coord]
		for i in range(tiles.size()):
			var tile = tiles[i]
			if tile.get("type") == "soil" and tile.get("state") == "growing":
				var elapsed = now - tile.get("plant_time", now)
				if elapsed >= tile.get("grow_duration", 0.0):
					tile["state"] = "ready"
					tile_updated.emit(coord, i)

# Persistence
func save_game():
	var data = {
		"coins": coins,
		"wood": wood,
		"stone": stone,
		"relics": relics,
		"tool_tier": tool_tier,
		"current_sector": current_sector_coord,
		"unlocked_sectors": unlocked_sectors,
		"sector_tiles": sector_tiles,
		"barn_inventory": barn_inventory,
		"save_time": Time.get_unix_time_from_system()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

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
	
	# Load barn storage
	barn_inventory = parsed.get("barn_inventory", [])
	
	# Ensure Homestead tile 0 is always the Red Barn
	var h_tiles = sector_tiles.get("1,1", [])
	if h_tiles.size() > 0:
		h_tiles[0] = {"type": "barn"}
	
	# Calculate offline crop growth
	update_crop_timers()

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
