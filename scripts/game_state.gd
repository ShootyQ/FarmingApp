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
signal workshop_opened
signal workshop_unlocked_signal
signal mill_opened
signal bakery_opened
signal production_updated
signal buildings_updated
signal mode_changed(new_mode: String)

const PLACEABLE_DECORATIONS = ["wooden_fence", "wooden_fence_nw", "stone_well", "lantern_post", "planter_box"]

var coins: int = 150
var wood: int = 10
var stone: int = 5
var relics: int = 0

var tool_tier: int = 0
var selected_crop: String = "wheat"
var current_sector_coord: String = "1,1"
var active_mode: String = "all" # "all", "plant", or "tools"

func set_active_mode(new_mode: String):
	if active_mode == new_mode:
		return
	active_mode = new_mode
	mode_changed.emit(active_mode)
	state_updated.emit()

# Buildings & Placement System (2x2 grid footprints)
# Red Barn starts on Homestead (1,1) at gx=0, gy=0 (occupies tiles 0, 1, 4, 5)
var buildings: Dictionary = {
	"barn": {
		"id": "barn",
		"name": "Red Barn",
		"sector": "1,1",
		"gx": 0,
		"gy": 0,
		"w": 2,
		"h": 2,
		"placed": true
	},
	"workshop": {
		"id": "workshop",
		"name": "Carpenter's Workshop",
		"sector": "1,1",
		"gx": 2,
		"gy": 2,
		"w": 2,
		"h": 2,
		"placed": false
	},
	"mill": {
		"id": "mill",
		"name": "Windmill",
		"sector": "1,1",
		"gx": 0,
		"gy": 0,
		"w": 2,
		"h": 2,
		"placed": false,
		"unlocked": false,
		"is_processing": false,
		"process_started_at": 0.0,
		"process_duration": 300.0, # 5 min
		"output_ready": 0
	},
	"bakery": {
		"id": "bakery",
		"name": "Artisan Bakery",
		"sector": "1,1",
		"gx": 0,
		"gy": 0,
		"w": 2,
		"h": 2,
		"placed": false,
		"unlocked": false,
		"is_processing": false,
		"process_started_at": 0.0,
		"process_duration": 600.0, # 10 min
		"output_ready": 0
	}
}

# 10-Minute Gameplay Unlock for Workshop (600.0 seconds)
var play_time_seconds: float = 0.0
var workshop_unlocked: bool = false
var crafted_recipes: Dictionary = {}

# Seed Inventory / Seed Pouch (Stock of seeds held by player)
var seed_inventory: Dictionary = {
	"wheat": 8,
	"carrot": 0,
	"strawberry": 0,
	"pumpkin": 0
}

# Barn Storage: 10 spaces base (upgradable to 15 in Workshop), stack size up to 10
var barn_slots_max: int = 10
const BARN_STACK_MAX: int = 10
var barn_inventory: Array = []

# Unlocked sectors list
var unlocked_sectors: Array[String] = ["1,1"]

# Sector tiles: original 16 plots first, followed by the surrounding meadow.
var sector_tiles: Dictionary = {}

var resource_last_tick: Dictionary = {}
const BACKUP_PATH = "user://farm_save_backup.json"
const SAVE_PATH = "user://farm_save.json"

var bgm_player: AudioStreamPlayer = null
var music_enabled: bool = true
var music_volume: float = 0.65

func _ready():
	load_game()
	_setup_bgm()

func _setup_bgm():
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BGMPlayer"
		bgm_player.bus = "Master"
		add_child(bgm_player)
		
		var audio_path = "res://assets/audio/golden_field_clarinet.mp3"
		if not ResourceLoader.exists(audio_path):
			audio_path = "res://Golden Field Clarinet.mp3"
		
		if ResourceLoader.exists(audio_path):
			var stream = load(audio_path) as AudioStreamMP3
			if stream:
				stream.loop = true
				bgm_player.stream = stream
				bgm_player.volume_db = linear_to_db(music_volume)
				if music_enabled:
					bgm_player.play()

func toggle_music() -> bool:
	music_enabled = not music_enabled
	if bgm_player:
		if music_enabled:
			if not bgm_player.playing:
				bgm_player.play()
			else:
				bgm_player.stream_paused = false
		else:
			bgm_player.stop()
	save_game()
	state_updated.emit()
	return music_enabled

func set_music_enabled(val: bool):
	if music_enabled == val:
		return
	music_enabled = val
	if bgm_player:
		if music_enabled:
			if not bgm_player.playing:
				bgm_player.play()
			else:
				bgm_player.stream_paused = false
		else:
			bgm_player.stop()
	save_game()
	state_updated.emit()

func ensure_music_playing():
	if music_enabled and bgm_player and not bgm_player.playing:
		bgm_player.play()

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
	var supply = ["small_wood", "small_wood", "small_wood", "small_wood", "small_rock", "small_rock", "small_rock", "small_rock", "weed", "hardwood_stump", "granite_boulder"]
	var supply_idx = 0
	
	for i in range(16): # 4x4 grid (gx = i % 4, gy = i / 4)
		var tile: Dictionary = {}
		if is_homestead and i in [0, 1, 4, 5]:
			# 2x2 Red Barn footprint at top-left corner
			var is_origin = (i == 0)
			tile = {
				"type": "building",
				"building_id": "barn",
				"is_origin": is_origin,
				"origin_idx": 0
			}
		elif is_homestead and i in [6, 7, 10, 11]:
			# 4 starter farm soil plots in a clean 2x2 field adjacent to barn
			tiles_become_soil(tile)
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
func interact_with_tile(sector_coord: String, tile_idx: int, mode_override: String = ""):
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
	var current_mode = mode_override if mode_override != "" else active_mode
	
	match tile_type:
		"building":
			var b_id = tile.get("building_id", "")
			if b_id == "barn":
				barn_opened.emit()
			elif b_id == "workshop":
				workshop_opened.emit()
			elif b_id == "mill":
				mill_opened.emit()
			elif b_id == "bakery":
				bakery_opened.emit()
		"barn":
			barn_opened.emit()
		"workshop":
			workshop_opened.emit()
		"mill":
			mill_opened.emit()
		"bakery":
			bakery_opened.emit()
		"decoration":
			if current_mode == "tools" or current_mode == "all":
				pickup_decoration(sector_coord, tile_idx)
			else:
				var d_info = GameData.get_item_info(tile.get("item_id", ""))
				message_broadcast.emit("%s (Decoration). Switch to Tools mode to pick up." % d_info.get("name", "Decoration"), false)
		"obstacle":
			if current_mode == "tools" or current_mode == "all":
				used_tool = _handle_tap_obstacle(sector_coord, tile_idx, tile)
			else:
				message_broadcast.emit("In Planting mode — switch to Tools to clear obstacles!", false)
		"soil":
			var soil_state = tile.get("state", "empty")
			if soil_state == "ready":
				# Ripe crops can be harvested in either mode
				_handle_tap_soil(sector_coord, tile_idx, tile)
			elif soil_state == "empty":
				if current_mode == "plant" or current_mode == "all":
					_handle_tap_soil(sector_coord, tile_idx, tile)
				else:
					message_broadcast.emit("In Tools mode — tap Planting to sow seeds!", false)
			else:
				_handle_tap_soil(sector_coord, tile_idx, tile)
		"grass":
			if current_mode == "tools" or current_mode == "all":
				used_tool = _handle_tap_grass(sector_coord, tile_idx, tile)
			else:
				# IN PLANTING MODE: PREVENT ACCIDENTAL HOEING!
				message_broadcast.emit("In Planting mode — grass is protected! Tap Tools to till soil.", false)
		"preparing":
			message_broadcast.emit("Preparing soil: %s remaining" % GameData.format_time(float(tile["prepare_started_at"]) + float(tile["prepare_duration"]) - Time.get_unix_time_from_system()), false)
	
	tile_updated.emit(sector_coord, tile_idx)
	if used_tool:
		tool_used.emit(sector_coord, tile_idx, tool_id)
	state_updated.emit()
	save_game()


# Building Placement & Management (2x2 Grid Footprints)
func can_place_building(building_id: String, sector_coord: String, gx: int, gy: int) -> bool:
	if not is_sector_unlocked(sector_coord):
		return false
	if gx < GameData.MEADOW_MIN or gx > GameData.MEADOW_MAX - 1 or gy < GameData.MEADOW_MIN or gy > GameData.MEADOW_MAX - 1:
		return false
	var tiles = sector_tiles.get(sector_coord, [])
	for dy in range(2):
		for dx in range(2):
			var idx = GameData.get_farm_index(Vector2i(gx + dx, gy + dy))
			if idx < 0 or idx >= tiles.size():
				return false
			var tile = tiles[idx]
			var t_type = tile.get("type", "grass")
			if t_type == "building":
				if tile.get("building_id") != building_id:
					return false # Collision with another building
			elif t_type == "grass":
				pass # Valid clear meadow grass
			elif t_type == "soil" and tile.get("state", "empty") == "empty":
				pass # Valid empty tilled soil plot
			else:
				return false # Blocked by obstacle, tree, boulder, or growing crops
	return true

func place_building(building_id: String, sector_coord: String, gx: int, gy: int) -> bool:
	if not can_place_building(building_id, sector_coord, gx, gy):
		return false
	
	# If previously placed, clear old tiles
	var b_data = buildings.get(building_id, {})
	if b_data.get("placed", false):
		var old_sec = b_data.get("sector", "")
		var old_gx = int(b_data.get("gx", 0))
		var old_gy = int(b_data.get("gy", 0))
		var old_tiles = sector_tiles.get(old_sec, [])
		for dy in range(2):
			for dx in range(2):
				var o_idx = GameData.get_farm_index(Vector2i(old_gx + dx, old_gy + dy))
				if o_idx >= 0 and o_idx < old_tiles.size():
					var ot = old_tiles[o_idx]
					if ot.get("type") == "building" and ot.get("building_id") == building_id:
						old_tiles[o_idx] = {"type": "grass"}
						tile_updated.emit(old_sec, o_idx)
	
	# Mark new 2x2 footprint
	var tiles = sector_tiles.get(sector_coord, [])
	var origin_idx = GameData.get_farm_index(Vector2i(gx, gy))
	for dy in range(2):
		for dx in range(2):
			var idx = GameData.get_farm_index(Vector2i(gx + dx, gy + dy))
			if idx >= 0 and idx < tiles.size():
				var is_orig = (dx == 0 and dy == 0)
				tiles[idx] = {
					"type": "building",
					"building_id": building_id,
					"is_origin": is_orig,
					"origin_idx": origin_idx
				}
				tile_updated.emit(sector_coord, idx)
	
	if not buildings.has(building_id):
		buildings[building_id] = {
			"id": building_id,
			"name": building_id.capitalize(),
			"w": 2,
			"h": 2
		}
	buildings[building_id]["placed"] = true
	buildings[building_id]["sector"] = sector_coord
	buildings[building_id]["gx"] = gx
	buildings[building_id]["gy"] = gy
	
	save_game()
	buildings_updated.emit()
	state_updated.emit()
	return true

# Placeable Decorations System (1x1 Footprint on Farm Plots / Meadow)
func can_place_decoration(item_id: String, sector_coord: String, gx: int, gy: int) -> bool:
	if not (item_id in PLACEABLE_DECORATIONS):
		return false
	if not is_sector_unlocked(sector_coord):
		return false
	if gx < GameData.MEADOW_MIN or gx > GameData.MEADOW_MAX or gy < GameData.MEADOW_MIN or gy > GameData.MEADOW_MAX:
		return false
	if get_barn_item_count(item_id) < 1:
		return false
	var idx = GameData.get_farm_index(Vector2i(gx, gy))
	var tiles = sector_tiles.get(sector_coord, [])
	if idx < 0 or idx >= tiles.size():
		return false
	var t = tiles[idx]
	var t_type = t.get("type", "grass")
	
	# Fences sit on the grid line/boundary edge and keep the tile fully usable
	if item_id in ["wooden_fence", "wooden_fence_nw"]:
		if t_type in ["building", "obstacle"]:
			return false
		var dir = "nw_se" if item_id == "wooden_fence_nw" else "sw_ne"
		var fences = t.get("fences", [])
		if dir in fences:
			return false # Already has fence in this direction
		return true
		
	if t_type == "grass":
		return true
	if t_type == "soil" and t.get("state", "empty") == "empty":
		return true
	return false

func place_decoration(item_id: String, sector_coord: String, gx: int, gy: int) -> bool:
	if not can_place_decoration(item_id, sector_coord, gx, gy):
		return false
	var idx = GameData.get_farm_index(Vector2i(gx, gy))
	var tiles = sector_tiles.get(sector_coord, [])
	if not remove_from_barn(item_id, 1):
		return false
	
	if item_id in ["wooden_fence", "wooden_fence_nw"]:
		var dir = "nw_se" if item_id == "wooden_fence_nw" else "sw_ne"
		var t = tiles[idx]
		var fences: Array = t.get("fences", []).duplicate()
		if not (dir in fences):
			fences.append(dir)
		t["fences"] = fences
	else:
		tiles[idx] = {
			"type": "decoration",
			"item_id": item_id,
			"gx": gx,
			"gy": gy
		}
	tile_updated.emit(sector_coord, idx)
	save_game()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("Placed %s on the grid line!" % GameData.get_item_info(item_id)["name"], true)
	return true

func pickup_decoration(sector_coord: String, tile_idx: int) -> bool:
	var tiles = sector_tiles.get(sector_coord, [])
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var tile = tiles[tile_idx]
	
	# If tile has a fence on its edge
	var fences: Array = tile.get("fences", []).duplicate()
	if fences.size() > 0:
		var dir = fences.pop_back()
		tile["fences"] = fences
		var item_id = "wooden_fence_nw" if dir == "nw_se" else "wooden_fence"
		if not add_to_barn(item_id, 1):
			fences.append(dir) # rollback
			tile["fences"] = fences
			message_broadcast.emit("Barn is full! Cannot pick up fence.", false)
			return false
		tile_updated.emit(sector_coord, tile_idx)
		save_game()
		state_updated.emit()
		barn_updated.emit()
		message_broadcast.emit("Picked up %s into Barn!" % GameData.get_item_info(item_id)["name"], true)
		return true
		
	if tile.get("type") != "decoration":
		return false
	var item_id = tile.get("item_id", "")
	if not add_to_barn(item_id, 1):
		message_broadcast.emit("Barn is full! Cannot pick up %s." % GameData.get_item_info(item_id)["name"], false)
		return false
	tile.clear()
	tile["type"] = "grass"
	tile_updated.emit(sector_coord, tile_idx)
	save_game()
	state_updated.emit()
	barn_updated.emit()
	message_broadcast.emit("Picked up %s and returned to Barn." % GameData.get_item_info(item_id)["name"], true)
	return true

func _has_adjacent_stone_well(sector_coord: String, tile_idx: int) -> bool:
	if tile_idx < 0 or tile_idx >= GameData.farm_coordinates.size():
		return false
	var pos = GameData.farm_coordinates[tile_idx]
	var tiles = sector_tiles.get(sector_coord, [])
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n_idx = GameData.get_farm_index(Vector2i(pos.x + dx, pos.y + dy))
			if n_idx >= 0 and n_idx < tiles.size():
				var t = tiles[n_idx]
				if t.get("type") == "decoration" and t.get("item_id") == "stone_well":
					return true
	return false

# Mill & Bakery Production Facilities
func start_milling() -> bool:
	var mill = buildings.get("mill", {})
	if not mill.get("unlocked", false):
		message_broadcast.emit("Craft the Windmill in the Workshop first!", false)
		return false
	if not mill.get("placed", false):
		message_broadcast.emit("Place the Windmill on your farm first!", false)
		return false
	if mill.get("is_processing", false):
		message_broadcast.emit("Windmill is already grinding wheat!", false)
		return false
	if mill.get("output_ready", 0) > 0:
		message_broadcast.emit("Collect the milled flour before grinding more wheat!", false)
		return false
	if get_barn_item_count("wheat") < 1:
		message_broadcast.emit("Need at least 1 Wheat stored in Barn to grind into flour!", false)
		return false
	remove_from_barn("wheat", 1)
	mill["is_processing"] = true
	mill["process_started_at"] = Time.get_unix_time_from_system()
	mill["process_duration"] = 300.0 # 5 min timer
	save_game()
	production_updated.emit()
	state_updated.emit()
	message_broadcast.emit("Started milling wheat! Flour ready in 5:00.", true)
	return true

func collect_milled_flour() -> int:
	var mill = buildings.get("mill", {})
	var amount = int(mill.get("output_ready", 0))
	if amount <= 0:
		message_broadcast.emit("No milled flour ready for collection.", false)
		return 0
	if not add_to_barn("flour", amount):
		message_broadcast.emit("Barn is full! Make space to collect flour.", false)
		return 0
	mill["output_ready"] = 0
	save_game()
	production_updated.emit()
	barn_updated.emit()
	state_updated.emit()
	message_broadcast.emit("Collected %dx Stone-Ground Flour into Barn!" % amount, true)
	return amount

func start_baking() -> bool:
	var bakery = buildings.get("bakery", {})
	if not bakery.get("unlocked", false):
		message_broadcast.emit("Craft the Artisan Bakery in the Workshop first!", false)
		return false
	if not bakery.get("placed", false):
		message_broadcast.emit("Place the Artisan Bakery on your farm first!", false)
		return false
	if bakery.get("is_processing", false):
		message_broadcast.emit("Bakery oven is already baking bread!", false)
		return false
	if bakery.get("output_ready", 0) > 0:
		message_broadcast.emit("Collect the baked bread before baking another loaf!", false)
		return false
	if get_barn_item_count("flour") < 1:
		message_broadcast.emit("Need at least 1 Flour stored in Barn to bake artisan bread!", false)
		return false
	remove_from_barn("flour", 1)
	bakery["is_processing"] = true
	bakery["process_started_at"] = Time.get_unix_time_from_system()
	bakery["process_duration"] = 600.0 # 10 min timer
	save_game()
	production_updated.emit()
	state_updated.emit()
	message_broadcast.emit("Baking bread in the brick oven! Golden loaf ready in 10:00.", true)
	return true

func collect_baked_bread() -> int:
	var bakery = buildings.get("bakery", {})
	var amount = int(bakery.get("output_ready", 0))
	if amount <= 0:
		message_broadcast.emit("No baked bread ready for collection.", false)
		return 0
	if not add_to_barn("bread", amount):
		message_broadcast.emit("Barn is full! Make space to collect bread.", false)
		return 0
	bakery["output_ready"] = 0
	save_game()
	production_updated.emit()
	barn_updated.emit()
	state_updated.emit()
	message_broadcast.emit("Collected %dx Artisan Farmhouse Bread (150c) into Barn!" % amount, true)
	return amount

func can_build_workshop() -> bool:
	if workshop_unlocked:
		return false
	var cost = GameData.WORKSHOP_CONSTRUCTION_COST
	return coins >= cost["coins"] and wood >= cost["wood"] and stone >= cost["stone"]

func build_workshop() -> bool:
	if workshop_unlocked or not can_build_workshop():
		return false
	var cost = GameData.WORKSHOP_CONSTRUCTION_COST
	coins -= cost["coins"]
	wood -= cost["wood"]
	stone -= cost["stone"]
	workshop_unlocked = true
	save_game()
	workshop_unlocked_signal.emit()
	state_updated.emit()
	message_broadcast.emit("Carpenter's Workshop Constructed! Ready to place on your farm!", true)
	return true

func unlock_workshop():
	if workshop_unlocked:
		return
	workshop_unlocked = true
	save_game()
	workshop_unlocked_signal.emit()
	state_updated.emit()
	message_broadcast.emit("Carpenter's Workshop Unlocked! Ready to place on your farm!", true)

# Workshop Crafting System
func can_craft_recipe(recipe_id: String) -> bool:
	var r = GameData.CRAFTING_RECIPES.get(recipe_id, {})
	if r.is_empty():
		return false
	if r.get("is_unique", false) and crafted_recipes.get(recipe_id, 0) > 0:
		return false
	var cost = r.get("cost", {})
	if cost.get("coins", 0) > coins:
		return false
	if cost.get("wood", 0) > wood:
		return false
	if cost.get("stone", 0) > stone:
		return false
	if cost.get("relics", 0) > relics:
		return false
	for item_key in cost:
		if item_key in ["coins", "wood", "stone", "relics"]:
			continue
		var req_count = cost[item_key]
		if get_barn_item_count(item_key) < req_count:
			return false
	return true

func craft_recipe(recipe_id: String) -> bool:
	if not can_craft_recipe(recipe_id):
		var r = GameData.CRAFTING_RECIPES.get(recipe_id, {})
		message_broadcast.emit("Insufficient materials to craft %s!" % r.get("name", "item"), false)
		return false
	
	var r = GameData.CRAFTING_RECIPES[recipe_id]
	var cost = r.get("cost", {})
	coins -= cost.get("coins", 0)
	wood -= cost.get("wood", 0)
	stone -= cost.get("stone", 0)
	relics -= cost.get("relics", 0)
	for item_key in cost:
		if item_key in ["coins", "wood", "stone", "relics"]:
			continue
		remove_from_barn(item_key, cost[item_key])
	
	crafted_recipes[recipe_id] = crafted_recipes.get(recipe_id, 0) + 1
	
	# Apply unique effects
	if recipe_id == "barn_expansion_1":
		barn_slots_max = 15
		message_broadcast.emit("Reinforced Barn Loft built! Storage expanded to 15 slots!", true)
	elif recipe_id == "mill":
		buildings["mill"]["unlocked"] = true
		message_broadcast.emit("Windmill Crafted! Ready to place on your farm!", true)
	elif recipe_id == "bakery":
		buildings["bakery"]["unlocked"] = true
		message_broadcast.emit("Artisan Bakery Crafted! Ready to place on your farm!", true)
	else:
		var yield_item = r.get("yield_item", recipe_id)
		var yield_count = r.get("yield_count", 1)
		add_to_barn(yield_item, yield_count)
		message_broadcast.emit("Crafted %dx %s! Stored safely in Barn." % [yield_count, r.get("name", "Item")], true)
	
	save_game()
	state_updated.emit()
	barn_updated.emit()
	return true

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
	var saved_fences = tile.get("fences", [])
	tile.clear()
	tile["type"] = "soil"
	tile["state"] = "empty"
	tile["crop"] = ""
	tile["is_mutated"] = false
	tile["plant_time"] = 0.0
	tile["grow_duration"] = 0.0
	if saved_fences.size() > 0:
		tile["fences"] = saved_fences

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
	var saved_fences = tile.get("fences", [])
	tile.clear()
	tile.merge({"type": "preparing", "prepare_started_at": Time.get_unix_time_from_system(), "prepare_duration": GameData.PREPARATION_SECONDS})
	if saved_fences.size() > 0:
		tile["fences"] = saved_fences
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
			var duration = float(crop_data["grow_time"])
			var has_well = _has_adjacent_stone_well(sector_coord, tile_idx)
			if has_well:
				duration = roundf(duration * 0.85)
			tile["grow_duration"] = duration
			tile["is_mutated"] = (randf() < crop_data["mutation_chance"])
			if has_well:
				message_broadcast.emit("Planted %s! (Hydrated by Cobblestone Well: +15%% grow speed!)" % crop_name, true)
			else:
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
	for b_id in ["mill", "bakery"]:
		var b = buildings.get(b_id, {})
		if b.get("is_processing", false):
			var started = float(b.get("process_started_at", 0.0))
			var dur = float(b.get("process_duration", 300.0 if b_id == "mill" else 600.0))
			if now >= started + dur:
				b["is_processing"] = false
				b["output_ready"] = int(b.get("output_ready", 0)) + 1
				changed = true
				production_updated.emit()
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
		"buildings": buildings,
		"play_time_seconds": play_time_seconds,
		"workshop_unlocked": workshop_unlocked,
		"barn_slots_max": barn_slots_max,
		"crafted_recipes": crafted_recipes,
		"music_enabled": music_enabled,
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
	buildings = {
		"barn": {"sector": "1,1", "gx": 0, "gy": 0, "w": 2, "h": 2, "placed": true},
		"workshop": {"sector": "1,1", "gx": 2, "gy": 2, "w": 2, "h": 2, "placed": false},
		"mill": {"sector": "1,1", "gx": 0, "gy": 0, "w": 2, "h": 2, "placed": false, "unlocked": false, "is_processing": false, "process_started_at": 0.0, "process_duration": 300.0, "output_ready": 0},
		"bakery": {"sector": "1,1", "gx": 0, "gy": 0, "w": 2, "h": 2, "placed": false, "unlocked": false, "is_processing": false, "process_started_at": 0.0, "process_duration": 600.0, "output_ready": 0}
	}
	workshop_unlocked = false
	play_time_seconds = 0.0
	barn_slots_max = 10
	crafted_recipes = {}
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
			if typeof(tile) != TYPE_DICTIONARY or tile.get("type", "") not in ["soil", "grass", "obstacle", "barn", "building", "preparing", "decoration"]:
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

	# Load barn storage & capacity
	barn_inventory = parsed.get("barn_inventory", [])
	barn_slots_max = parsed.get("barn_slots_max", 10)
	
	# Load workshop & gameplay timer
	play_time_seconds = float(parsed.get("play_time_seconds", 0.0))
	workshop_unlocked = bool(parsed.get("workshop_unlocked", false))
	crafted_recipes = parsed.get("crafted_recipes", {})
	set_music_enabled(bool(parsed.get("music_enabled", true)))
	
	# Load buildings
	if parsed.has("buildings") and typeof(parsed["buildings"]) == TYPE_DICTIONARY:
		buildings = parsed["buildings"]
	
	# Ensure 2x2 Red Barn footprint is marked at its saved coordinates
	var barn_data = buildings.get("barn", {})
	var barn_gx = int(barn_data.get("gx", 0))
	var barn_gy = int(barn_data.get("gy", 0))
	var barn_sec = barn_data.get("sector", "1,1")
	var barn_tiles = sector_tiles.get(barn_sec, [])
	var barn_origin_idx = GameData.get_farm_index(Vector2i(barn_gx, barn_gy))
	if barn_tiles.size() >= 16:
		for dy in range(2):
			for dx in range(2):
				var idx = GameData.get_farm_index(Vector2i(barn_gx + dx, barn_gy + dy))
				if idx >= 0 and idx < barn_tiles.size():
					barn_tiles[idx] = {
						"type": "building",
						"building_id": "barn",
						"is_origin": (dx == 0 and dy == 0),
						"origin_idx": barn_origin_idx
					}
	
	# If workshop was placed, verify its tiles are marked
	var ws_data = buildings.get("workshop", {})
	if ws_data.get("placed", false):
		var ws_sec = ws_data.get("sector", "1,1")
		var ws_gx = int(ws_data.get("gx", 2))
		var ws_gy = int(ws_data.get("gy", 2))
		var ws_tiles = sector_tiles.get(ws_sec, [])
		var ws_origin_idx = GameData.get_farm_index(Vector2i(ws_gx, ws_gy))
		for dy in range(2):
			for dx in range(2):
				var idx = GameData.get_farm_index(Vector2i(ws_gx + dx, ws_gy + dy))
				if idx >= 0 and idx < ws_tiles.size():
					ws_tiles[idx] = {
						"type": "building",
						"building_id": "workshop",
						"is_origin": (dx == 0 and dy == 0),
						"origin_idx": ws_origin_idx
					}
	
	# Ensure mill and bakery default states and tile footprints
	for b_id in ["mill", "bakery"]:
		if not buildings.has(b_id) or typeof(buildings[b_id]) != TYPE_DICTIONARY:
			buildings[b_id] = {
				"id": b_id,
				"name": "Windmill" if b_id == "mill" else "Artisan Bakery",
				"sector": "1,1",
				"gx": 0,
				"gy": 0,
				"w": 2,
				"h": 2,
				"placed": false,
				"unlocked": false,
				"is_processing": false,
				"process_started_at": 0.0,
				"process_duration": 300.0 if b_id == "mill" else 600.0,
				"output_ready": 0
			}
		else:
			if not buildings[b_id].has("unlocked"): buildings[b_id]["unlocked"] = false
			if not buildings[b_id].has("is_processing"): buildings[b_id]["is_processing"] = false
			if not buildings[b_id].has("process_started_at"): buildings[b_id]["process_started_at"] = 0.0
			if not buildings[b_id].has("process_duration"): buildings[b_id]["process_duration"] = 300.0 if b_id == "mill" else 600.0
			if not buildings[b_id].has("output_ready"): buildings[b_id]["output_ready"] = 0
		
		var b_data = buildings[b_id]
		if b_data.get("placed", false):
			var b_sec = b_data.get("sector", "1,1")
			var b_gx = int(b_data.get("gx", 0))
			var b_gy = int(b_data.get("gy", 0))
			var b_tiles = sector_tiles.get(b_sec, [])
			var b_origin_idx = GameData.get_farm_index(Vector2i(b_gx, b_gy))
			for dy in range(2):
				for dx in range(2):
					var idx = GameData.get_farm_index(Vector2i(b_gx + dx, b_gy + dy))
					if idx >= 0 and idx < b_tiles.size():
						b_tiles[idx] = {
							"type": "building",
							"building_id": b_id,
							"is_origin": (dx == 0 and dy == 0),
							"origin_idx": b_origin_idx
						}
	
	# Load seed inventory
	var loaded_seeds = parsed.get("seed_inventory", {})
	if typeof(loaded_seeds) == TYPE_DICTIONARY and loaded_seeds.size() > 0:
		seed_inventory = loaded_seeds
	else:
		seed_inventory = {"wheat": 10, "carrot": 5, "strawberry": 2, "pumpkin": 0}
	for cid in GameData.CROPS:
		if not cid in seed_inventory:
			seed_inventory[cid] = 0
	
	# Migrate legacy fence tiles to edge fences so plots remain usable
	for s_tiles in sector_tiles.values():
		for t in s_tiles:
			if t.get("type") == "decoration" and t.get("item_id") in ["wooden_fence", "wooden_fence_nw"]:
				var f_dir = "nw_se" if t.get("item_id") == "wooden_fence_nw" else "sw_ne"
				t["type"] = "grass"
				t["fences"] = [f_dir]
				t.erase("item_id")
	
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

# Barn Inventory Management
func get_barn_item_count(item_id: String) -> int:
	var total = 0
	for slot in barn_inventory:
		if slot.get("id") == item_id:
			total += int(slot.get("count", 0))
	return total

func remove_from_barn(item_id: String, amount: int) -> bool:
	if get_barn_item_count(item_id) < amount:
		return false
	var remaining = amount
	var i = barn_inventory.size() - 1
	while i >= 0 and remaining > 0:
		var slot = barn_inventory[i]
		if slot.get("id") == item_id:
			var take = min(remaining, slot.get("count", 0))
			slot["count"] -= take
			remaining -= take
			if slot["count"] <= 0:
				barn_inventory.remove_at(i)
		i -= 1
	save_game()
	barn_updated.emit()
	return true

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
				
	# Pass 2: Fill empty slots up to barn_slots_max (10 base, 15 upgraded)
	while remaining > 0 and barn_inventory.size() < barn_slots_max:
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
