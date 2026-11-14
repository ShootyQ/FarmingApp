extends Node

# Keep the original 4x4 indices first so existing crops and buildings stay put.
const MEADOW_MIN = -8
const MEADOW_MAX = 11
const MEADOW_TILE_COUNT = 400
var farm_coordinates: Array[Vector2i] = []
var farm_indices: Dictionary = {}

func _init():
	for y in range(4):
		for x in range(4):
			_add_farm_coordinate(Vector2i(x, y))
	for y in range(MEADOW_MIN, MEADOW_MAX + 1):
		for x in range(MEADOW_MIN, MEADOW_MAX + 1):
			if x < 0 or x >= 4 or y < 0 or y >= 4:
				_add_farm_coordinate(Vector2i(x, y))

func _add_farm_coordinate(coordinate: Vector2i):
	farm_indices[coordinate] = farm_coordinates.size()
	farm_coordinates.append(coordinate)

func get_farm_index(coordinate: Vector2i) -> int:
	return farm_indices.get(coordinate, -1)

# Crop Database
# Fast snack crops to long-haul crops
const CROPS = {
	"wheat": {
		"id": "wheat",
		"name": "Wheat",
		"emoji": "",
		"cost": 8,
		"reward": 12,
		"grow_time": 30,
		"mutation_chance": 0.05,
		"mutated_name": "Golden Wheat [Rare]",
		"mutated_reward": 24
	},
	"carrot": {
		"id": "carrot",
		"name": "Carrot",
		"emoji": "",
		"cost": 20,
		"reward": 34,
		"grow_time": 90,
		"mutation_chance": 0.05,
		"mutated_name": "Crystal Carrot [Rare]",
		"mutated_reward": 68
	},
	"strawberry": {
		"id": "strawberry",
		"name": "Strawberry",
		"emoji": "",
		"cost": 45,
		"reward": 78,
		"grow_time": 180,
		"mutation_chance": 0.05,
		"mutated_name": "Jeweled Berry [Rare]",
		"mutated_reward": 156
	},
	"pumpkin": {
		"id": "pumpkin",
		"name": "Pumpkin",
		"emoji": "",
		"cost": 90,
		"reward": 150,
		"grow_time": 300,
		"mutation_chance": 0.05,
		"mutated_name": "Haunted Pumpkin [Legendary]",
		"mutated_reward": 300
	}
}

# Obstacle Database
const OBSTACLES = {
	"weed": {
		"id": "weed",
		"name": "Weeds",
		"emoji": "",
		"taps_max": 1,
		"required_tool_tier": 0,
		"drops": {"coins": 2},
		"relic_chance": 0.01
	},
	"small_wood": {
		"id": "small_wood",
		"name": "Fallen Branch",
		"emoji": "",
		"taps_max": 2,
		"required_tool_tier": 0,
		"drops": {"wood": 2, "coins": 5},
		"relic_chance": 0.02
	},
	"small_rock": {
		"id": "small_rock",
		"name": "Pebble Pile",
		"emoji": "",
		"taps_max": 3,
		"required_tool_tier": 0,
		"drops": {"stone": 2, "coins": 5},
		"relic_chance": 0.03
	},
	"hardwood_stump": {
		"id": "hardwood_stump",
		"name": "Hardwood Stump",
		"emoji": "",
		"taps_max": 6,
		"required_tool_tier": 1, # Copper Axe
		"drops": {"wood": 8, "coins": 20},
		"relic_chance": 0.10
	},
	"granite_boulder": {
		"id": "granite_boulder",
		"name": "Granite Boulder",
		"emoji": "",
		"taps_max": 8,
		"required_tool_tier": 1, # Copper Pickaxe
		"drops": {"stone": 8, "coins": 25},
		"relic_chance": 0.15
	},
	"ancient_relic_mound": {
		"id": "ancient_relic_mound",
		"name": "Mysterious Mound",
		"emoji": "",
		"taps_max": 10,
		"required_tool_tier": 2, # Iron Tools
		"drops": {"stone": 10, "relics": 1, "coins": 100},
		"relic_chance": 1.0
	}
}

# Item Database (Produce & Materials stored in Barn)
const ITEMS = {
	"wheat": {
		"name": "Wheat",
		"icon": "res://assets/icons/icon_wheat.png",
		"desc": "Crisp golden stalks of farm-fresh wheat."
	},
	"golden_wheat": {
		"name": "Golden Wheat [Rare]",
		"icon": "res://assets/icons/icon_golden_wheat.png",
		"desc": "Rare golden-sheaf wheat glowing with sun energy."
	},
	"carrot": {
		"name": "Carrot",
		"icon": "res://assets/icons/icon_carrot.png",
		"desc": "Sweet, crunchy heirloom orange carrot."
	},
	"crystal_carrot": {
		"name": "Crystal Carrot [Rare]",
		"icon": "res://assets/icons/icon_crystal_carrot.png",
		"desc": "A legendary prismatic crystalline root."
	},
	"strawberry": {
		"name": "Strawberry",
		"icon": "res://assets/icons/icon_strawberry.png",
		"desc": "Plump, sun-ripened red garden strawberry."
	},
	"jeweled_berry": {
		"name": "Jeweled Berry [Rare]",
		"icon": "res://assets/icons/icon_jeweled_berry.png",
		"desc": "Glittering ruby gemstone strawberry fit for royalty."
	},
	"pumpkin": {
		"name": "Pumpkin",
		"icon": "res://assets/icons/icon_pumpkin.png",
		"desc": "A hearty, heavy autumn prize pumpkin."
	},
	"haunted_pumpkin": {
		"name": "Haunted Pumpkin [Legendary]",
		"icon": "res://assets/icons/icon_haunted_pumpkin.png",
		"desc": "Spooky glowing purple pumpkin with mysterious essence."
	}
}

func get_item_info(item_id: String) -> Dictionary:
	var info: Dictionary = ITEMS.get(item_id, {"name": item_id.capitalize(), "icon": "", "desc": "Farm produce."}).duplicate()
	info["sell_value"] = 10
	for crop_id in CROPS:
		if item_id == crop_id:
			info["sell_value"] = CROPS[crop_id]["reward"]
		elif item_id == RARE_CROP_ITEMS[crop_id]:
			info["sell_value"] = CROPS[crop_id]["mutated_reward"]
	return info

const RARE_CROP_ITEMS = {"wheat": "golden_wheat", "carrot": "crystal_carrot", "strawberry": "jeweled_berry", "pumpkin": "haunted_pumpkin"}
const PREPARATION_SECONDS = 300.0
const RESOURCE_INTERVAL = 120.0
const RESOURCE_CAP = 4

func format_time(seconds: float) -> String:
	var whole = maxi(0, ceili(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

# Tools share the saved material tier; selection follows the tapped tile.
const TOOL_MATERIALS = ["wooden", "copper", "iron", "golden"]
const TOOLS = {
	"axe": {"name": "Axe", "purpose": "Clears fallen branches and hardwood stumps.", "requirements": "Wooden: branches. Copper: hardwood stumps."},
	"pickaxe": {"name": "Pickaxe", "purpose": "Breaks rocks, boulders, and relic mounds.", "requirements": "Wooden: pebbles. Copper: granite. Iron: relic mounds."},
	"hoe": {"name": "Hoe", "purpose": "Clears weeds and tills grass into planting soil.", "requirements": "Preparation takes 5:00 once; the soil stays farmable."}
}
const OBSTACLE_TOOLS = {
	"weed": "hoe", "small_wood": "axe", "hardwood_stump": "axe",
	"small_rock": "pickaxe", "granite_boulder": "pickaxe", "ancient_relic_mound": "pickaxe"
}

func get_tool_for_tile(tile: Dictionary) -> String:
	if tile.get("type") == "grass":
		return "hoe"
	if tile.get("type") == "obstacle":
		return OBSTACLE_TOOLS.get(tile.get("obstacle_id", ""), "")
	return ""

func get_tool_icon_path(tool_id: String, tier: int) -> String:
	return "res://assets/tools/%s_%s.svg" % [tool_id, TOOL_MATERIALS[clampi(tier, 0, 3)]]

# Tool Tiers
const TOOL_TIERS = [
	{
		"name": "Wooden Tools",
		"preparation_slots": 2,
		"damage": 1,
		"tier": 0,
		"cost_coins": 0,
		"cost_wood": 0,
		"cost_stone": 0,
		"description": "Basic clearing of weeds, twigs, and loose rocks."
	},
	{
		"name": "Copper Tools",
		"preparation_slots": 3,
		"damage": 1,
		"tier": 1,
		"cost_coins": 1000,
		"cost_wood": 20,
		"cost_stone": 20,
		"description": "Can break Hardwood Stumps and Granite Boulders."
	},
	{
		"name": "Iron Tools",
		"preparation_slots": 4,
		"damage": 2,
		"tier": 2,
		"cost_coins": 4000,
		"cost_wood": 60,
		"cost_stone": 60,
		"description": "Unlocks mysterious mounds. Deals 2 damage per clearing tap."
	},
	{
		"name": "Golden Tools",
		"preparation_slots": 5,
		"damage": 3,
		"tier": 3,
		"cost_coins": 16000,
		"cost_wood": 150,
		"cost_stone": 150,
		"description": "Deals 3 damage per clearing tap and +50% rare relic chance."
	}
]

# Sectors Layout (3x3 Map)
# [0,0] Top-Left, [1,1] Center (Starting Homestead)
const SECTORS = {
	"1,1": {
		"id": "1,1",
		"name": "The Homestead",
		"cost": 0,
		"is_start": true,
		"description": "Your starting farm plot with fertile soil and light debris.",
		"landmark": ""
	},
	"1,0": {
		"id": "1,0",
		"name": "Whispering Forest",
		"cost": 1200,
		"is_start": false,
		"description": "Rich in hardwood trees and hidden bird nests.",
		"landmark": "Old Watchtower"
	},
	"2,1": {
		"id": "2,1",
		"name": "Sunlit Valley",
		"cost": 2000,
		"is_start": false,
		"description": "Open expanses with wild berries and fertile farming ground.",
		"landmark": ""
	},
	"1,2": {
		"id": "1,2",
		"name": "Rocky Quarry",
		"cost": 3200,
		"is_start": false,
		"description": "Rich stone deposits and ancient geodes waiting to be unearthed.",
		"landmark": "Cracked Geode Cavern"
	},
	"0,1": {
		"id": "0,1",
		"name": "Ancient Springs",
		"cost": 5000,
		"is_start": false,
		"description": "An abandoned natural spring that boosts nearby crop growth.",
		"landmark": "The Ancient Well"
	},
	"0,0": {
		"id": "0,0",
		"name": "Lost Orchard",
		"cost": 8000,
		"is_start": false,
		"description": "Ancient heirloom trees with rare fruits.",
		"landmark": "Giant Hollow Tree"
	},
	"2,0": {
		"id": "2,0",
		"name": "Forgotten Ruins",
		"cost": 12000,
		"is_start": false,
		"description": "Ancient stone monuments with buried treasures.",
		"landmark": "Mystic Shrine"
	},
	"0,2": {
		"id": "0,2",
		"name": "Canyon River",
		"cost": 18000,
		"is_start": false,
		"description": "Lush riverside rich in gold flecks and clay.",
		"landmark": "Old Watermill"
	},
	"2,2": {
		"id": "2,2",
		"name": "Archeology Dig",
		"cost": 25000,
		"is_start": false,
		"description": "A legendary excavation site bursting with ancient artifacts.",
		"landmark": "Sunken Vault"
	}
}
