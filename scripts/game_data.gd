extends Node

# Crop Database
# Fast snack crops to long-haul crops
const CROPS = {
	"wheat": {
		"id": "wheat",
		"name": "Wheat",
		"emoji": "",
		"cost": 10,
		"reward": 25,
		"grow_time": 5.0, # 5s for testing, easily tuned
		"mutation_chance": 0.05,
		"mutated_name": "Golden Wheat ★",
		"mutated_reward": 100
	},
	"carrot": {
		"id": "carrot",
		"name": "Carrot",
		"emoji": "",
		"cost": 25,
		"reward": 65,
		"grow_time": 15.0,
		"mutation_chance": 0.05,
		"mutated_name": "Crystal Carrot ★",
		"mutated_reward": 250
	},
	"strawberry": {
		"id": "strawberry",
		"name": "Strawberry",
		"emoji": "",
		"cost": 60,
		"reward": 160,
		"grow_time": 45.0,
		"mutation_chance": 0.08,
		"mutated_name": "Jeweled Berry ★",
		"mutated_reward": 600
	},
	"pumpkin": {
		"id": "pumpkin",
		"name": "Pumpkin",
		"emoji": "",
		"cost": 150,
		"reward": 450,
		"grow_time": 120.0,
		"mutation_chance": 0.10,
		"mutated_name": "Haunted Pumpkin ",
		"mutated_reward": 1800
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
		"sell_value": 25,
		"icon": "res://assets/objects/wheat_mature.png",
		"desc": "Crisp golden stalks of farm-fresh wheat."
	},
	"golden_wheat": {
		"name": "Golden Wheat ★",
		"sell_value": 100,
		"icon": "res://assets/objects/wheat_legendary.png",
		"desc": "Rare golden-sheaf wheat glowing with sun energy."
	},
	"carrot": {
		"name": "Carrot",
		"sell_value": 65,
		"icon": "res://assets/objects/carrot_mature.png",
		"desc": "Sweet, crunchy heirloom orange carrot."
	},
	"crystal_carrot": {
		"name": "Crystal Carrot ★",
		"sell_value": 250,
		"icon": "res://assets/objects/carrot_crystal.png",
		"desc": "A legendary prismatic crystalline root."
	},
	"strawberry": {
		"name": "Strawberry",
		"sell_value": 160,
		"icon": "res://assets/objects/strawberry_mature.png",
		"desc": "Plump, sun-ripened red garden strawberry."
	},
	"jeweled_berry": {
		"name": "Jeweled Berry ★",
		"sell_value": 600,
		"icon": "res://assets/objects/strawberry_jeweled.png",
		"desc": "Glittering ruby gemstone strawberry fit for royalty."
	},
	"pumpkin": {
		"name": "Pumpkin",
		"sell_value": 450,
		"icon": "res://assets/objects/pumpkin_mature.png",
		"desc": "A hearty, heavy autumn prize pumpkin."
	},
	"haunted_pumpkin": {
		"name": "Haunted Pumpkin ★",
		"sell_value": 1800,
		"icon": "res://assets/objects/pumpkin_haunted.png",
		"desc": "Spooky glowing purple pumpkin with mysterious essence."
	}
}

func get_item_info(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {
		"name": item_id.capitalize(),
		"sell_value": 10,
		"icon": "",
		"desc": "Farm produce stored safely in the barn."
	})

# Tool Tiers
const TOOL_TIERS = [
	{
		"name": "Wooden Tools",
		"tier": 0,
		"cost_coins": 0,
		"cost_wood": 0,
		"cost_stone": 0,
		"description": "Basic clearing of weeds, twigs, and loose rocks."
	},
	{
		"name": "Copper Tools",
		"tier": 1,
		"cost_coins": 200,
		"cost_wood": 20,
		"cost_stone": 20,
		"description": "Can break Hardwood Stumps and Granite Boulders."
	},
	{
		"name": "Iron Tools",
		"tier": 2,
		"cost_coins": 800,
		"cost_wood": 60,
		"cost_stone": 60,
		"description": "Breaks Mysterious Mounds and ancient ruins. 2x clearing speed!"
	},
	{
		"name": "Golden Tools",
		"tier": 3,
		"cost_coins": 3000,
		"cost_wood": 150,
		"cost_stone": 150,
		"description": "Instant clearing on basic obstacles and +50% rare relic drops!"
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
		"cost": 150,
		"is_start": false,
		"description": "Rich in hardwood trees and hidden bird nests.",
		"landmark": "Old Watchtower"
	},
	"2,1": {
		"id": "2,1",
		"name": "Sunlit Valley",
		"cost": 300,
		"is_start": false,
		"description": "Open expanses with wild berries and fertile farming ground.",
		"landmark": ""
	},
	"1,2": {
		"id": "1,2",
		"name": "Rocky Quarry",
		"cost": 500,
		"is_start": false,
		"description": "Rich stone deposits and ancient geodes waiting to be unearthed.",
		"landmark": "Cracked Geode Cavern"
	},
	"0,1": {
		"id": "0,1",
		"name": "Ancient Springs",
		"cost": 800,
		"is_start": false,
		"description": "An abandoned natural spring that boosts nearby crop growth.",
		"landmark": "The Ancient Well"
	},
	"0,0": {
		"id": "0,0",
		"name": "Lost Orchard",
		"cost": 1500,
		"is_start": false,
		"description": "Ancient heirloom trees with rare fruits.",
		"landmark": "Giant Hollow Tree"
	},
	"2,0": {
		"id": "2,0",
		"name": "Forgotten Ruins",
		"cost": 2200,
		"is_start": false,
		"description": "Ancient stone monuments with buried treasures.",
		"landmark": "Mystic Shrine"
	},
	"0,2": {
		"id": "0,2",
		"name": "Canyon River",
		"cost": 3000,
		"is_start": false,
		"description": "Lush riverside rich in gold flecks and clay.",
		"landmark": "Old Watermill"
	},
	"2,2": {
		"id": "2,2",
		"name": "Archeology Dig",
		"cost": 5000,
		"is_start": false,
		"description": "A legendary excavation site bursting with ancient artifacts.",
		"landmark": "Sunken Vault"
	}
}
