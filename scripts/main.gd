extends Control

# FarmingApp: Authentic 2:1 Isometric FarmVille Engine
# Interlocking 2:1 Grass & Plowed Soil Diamonds in 1970s National Park Olive Palette

const ISO_W = 160.0
const ISO_H = 80.0

@onready var world_container = $WorldViewport/World
@onready var plots_root = $WorldViewport/World/Plots
@onready var camera = $WorldViewport/World/Camera2D

@onready var coins_label = $HUD/Margin/VBox/TopBar/Resources/Coins
@onready var wood_label = $HUD/Margin/VBox/TopBar/Resources/Wood
@onready var stone_label = $HUD/Margin/VBox/TopBar/Resources/Stone
@onready var relics_label = $HUD/Margin/VBox/TopBar/Resources/Relics
@onready var sector_title = $HUD/Margin/VBox/TopBar/SectorInfo/SectorTitle
@onready var status_banner = $HUD/Margin/VBox/StatusBanner

@onready var seed_bar = $HUD/Margin/VBox/BottomControls/SeedBar
@onready var tool_btn = $HUD/Margin/VBox/BottomControls/ToolUpgradeBtn
@onready var map_modal = $HUD/MapModal
@onready var map_grid = $HUD/MapModal/Panel/VBox/MapGrid

var tex_grass = [
	preload("res://assets/tiles/iso_grass_0.png"),
	preload("res://assets/tiles/iso_grass_1.png"),
	preload("res://assets/tiles/iso_grass_2.png"),
	preload("res://assets/tiles/iso_grass_3.png"),
	preload("res://assets/tiles/iso_grass_4.png"),
	preload("res://assets/tiles/iso_grass_5.png"),
	preload("res://assets/tiles/iso_grass_6.png"),
	preload("res://assets/tiles/iso_grass_7.png")
]
var tex_soil = preload("res://assets/tiles/iso_soil_flat.png")

# Wheat growth stages
var tex_wheat_sprout = preload("res://assets/objects/wheat_sprout.png")
var tex_wheat_growing = preload("res://assets/objects/wheat_growing.png")
var tex_wheat_heading = preload("res://assets/objects/wheat_heading.png")
var tex_wheat_mature = preload("res://assets/objects/wheat_mature.png")
var tex_wheat_legendary = preload("res://assets/objects/wheat_legendary.png")

var tex_carrot = preload("res://assets/objects/carrot_mature.png")
var tex_berry = preload("res://assets/objects/berry_mature.png")

# Obstacle Variations: Weeds (4), Logs (2), Rocks (3)
var tex_weeds = [
	preload("res://assets/objects/weed_0.png"), # Thistle
	preload("res://assets/objects/weed_1.png"), # Tallgrass
	preload("res://assets/objects/weed_2.png"), # Dandelion
	preload("res://assets/objects/weed_3.png")  # Bramble
]
var tex_logs = [
	preload("res://assets/objects/log_0.png"), # Mossy cedar log
	preload("res://assets/objects/log_1.png")  # Weathered hardwood log
]
var tex_rocks = [
	preload("res://assets/objects/rock_0.png"), # Granite field boulder
	preload("res://assets/objects/rock_1.png"), # Limestone rock cluster
	preload("res://assets/objects/rock_2.png")  # River stones & pebbles
]

var plot_nodes: Array[Node2D] = []
var meadow_container: Node2D = null

# Camera drag state
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cam: Vector2 = Vector2.ZERO

func _ready():
	_build_isometric_grid()
	_setup_seed_buttons()
	_setup_map_buttons()
	
	GameState.state_updated.connect(_refresh_ui)
	GameState.tile_updated.connect(_on_tile_updated)
	GameState.message_broadcast.connect(_show_message)
	
	tool_btn.pressed.connect(_on_tool_upgrade_pressed)
	$HUD/Margin/VBox/TopBar/SectorInfo/MapBtn.pressed.connect(func(): map_modal.visible = true)
	$HUD/MapModal/Panel/VBox/CloseMapBtn.pressed.connect(func(): map_modal.visible = false)
	
	_select_crop("wheat")
	_refresh_ui()

func _process(_delta: float):
	GameState.update_crop_timers()
	_update_active_crop_labels()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_mouse = get_viewport().get_mouse_position()
				drag_start_cam = camera.position
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = clamp(camera.zoom * 1.1, Vector2(0.6, 0.6), Vector2(2.0, 2.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = clamp(camera.zoom * 0.9, Vector2(0.6, 0.6), Vector2(2.0, 2.0))
			
	elif event is InputEventMouseMotion and is_dragging:
		var current_mouse = get_viewport().get_mouse_position()
		var diff = (drag_start_mouse - current_mouse) / camera.zoom
		camera.position = drag_start_cam + diff

func _build_isometric_grid():
	plot_nodes.clear()
	for child in plots_root.get_children():
		child.queue_free()
	
	if meadow_container != null and is_instance_valid(meadow_container):
		meadow_container.queue_free()
	
	meadow_container = Node2D.new()
	meadow_container.name = "MeadowGround"
	meadow_container.z_index = 0
	world_container.add_child(meadow_container)
	world_container.move_child(meadow_container, 0)
	
	plots_root.z_index = 10
	
	var origin_x = 0.0
	var origin_y = -60.0
	var empty_style = StyleBoxEmpty.new()
	var s = (ISO_W / 256.0) * 1.002 # Tight seamless 2:1 fit
	
	# 1. Build continuous 20x20 meadow landscape
	var meadow_min = -8
	var meadow_max = 11
	
	for my in range(meadow_min, meadow_max + 1):
		for mx in range(meadow_min, meadow_max + 1):
			var m_iso_x = origin_x + (mx - my) * (ISO_W * 0.5)
			var m_iso_y = origin_y + (mx + my) * (ISO_H * 0.5)
			
			var spr = Sprite2D.new()
			spr.position = Vector2(m_iso_x, m_iso_y)
			spr.scale = Vector2(s, s)
			spr.z_index = 0
			
			# Weighted natural distribution across the 8 grass variants
			var h = abs((mx * 73856093) ^ (my * 19349663) ^ (mx * my * 83492791)) % 100
			var g_idx = 0
			if h < 42:
				g_idx = 0 # Classic lawn with subtle blades
			elif h < 66:
				g_idx = 1 # Grass blade tufts
			elif h < 76:
				g_idx = 2 # Golden buttercups
			elif h < 84:
				g_idx = 3 # Clover clusters
			elif h < 91:
				g_idx = 4 # White wild daisies
			elif h < 95:
				g_idx = 5 # Dandelion puffs
			elif h < 98:
				g_idx = 6 # Sunny morning highlights
			else:
				g_idx = 7 # Mossy pasture
			
			spr.texture = tex_grass[g_idx]
			meadow_container.add_child(spr)
	
	# 2. Build the 16 interactive farm plots (4x4)
	for i in range(16):
		var gx = i % 4
		var gy = i / 4
		
		# 2:1 Isometric formula matching the meadow
		var iso_x = origin_x + (gx - gy) * (ISO_W * 0.5)
		var iso_y = origin_y + (gx + gy) * (ISO_H * 0.5)
		
		var node = Node2D.new()
		node.name = "Plot_%d" % i
		node.position = Vector2(iso_x, iso_y)
		node.z_index = gx + gy # Natural isometric Y-sorting
		
		# Layer 1: Flat Furrowed Soil Diamond (Plowed FarmVille rows)
		var soil_sprite = Sprite2D.new()
		soil_sprite.name = "Soil"
		soil_sprite.texture = tex_soil
		soil_sprite.scale = Vector2(s, s)
		soil_sprite.position = Vector2.ZERO
		soil_sprite.visible = false
		node.add_child(soil_sprite)
		
		# Layer 2: Standing Object Sprite (Tree Stump, Boulder, Crop, Weed)
		var obj_sprite = Sprite2D.new()
		obj_sprite.name = "ObjectSprite"
		obj_sprite.offset = Vector2(0, -32)
		obj_sprite.scale = Vector2(0.60, 0.60)
		obj_sprite.visible = false
		node.add_child(obj_sprite)
		
		# Layer 3: Clean floating status badge
		var badge = Label.new()
		badge.name = "Badge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(100, 24)
		badge.position = Vector2(-50, -48)
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		node.add_child(badge)
		
		# Layer 4: Invisible Touch Area
		var touch_btn = Button.new()
		touch_btn.name = "TouchBtn"
		touch_btn.custom_minimum_size = Vector2(ISO_W, ISO_H)
		touch_btn.position = Vector2(-ISO_W * 0.5, -ISO_H * 0.5)
		touch_btn.add_theme_stylebox_override("normal", empty_style)
		touch_btn.add_theme_stylebox_override("hover", empty_style)
		touch_btn.add_theme_stylebox_override("pressed", empty_style)
		touch_btn.add_theme_stylebox_override("focus", empty_style)
		
		var idx = i
		touch_btn.pressed.connect(func(): _on_plot_clicked(idx))
		node.add_child(touch_btn)
		
		plots_root.add_child(node)
		plot_nodes.append(node)

func _setup_seed_buttons():
	for child in seed_bar.get_children():
		child.queue_free()
	
	var group = ButtonGroup.new()
	for crop_id in GameData.CROPS:
		var c = GameData.CROPS[crop_id]
		var btn = Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.text = "%s\n%dc" % [c["name"], c["cost"]]
		btn.add_theme_font_size_override("font_size", 14)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var id = crop_id
		btn.pressed.connect(func(): _select_crop(id))
		seed_bar.add_child(btn)
		
		if crop_id == GameState.selected_crop:
			btn.button_pressed = true

func _setup_map_buttons():
	for child in map_grid.get_children():
		child.queue_free()
	
	for y in range(3):
		for x in range(3):
			var coord = "%d,%d" % [x, y]
			var btn = Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 14)
			
			btn.pressed.connect(func(): _on_map_sector_clicked(coord))
			map_grid.add_child(btn)

func _select_crop(crop_id: String):
	GameState.selected_crop = crop_id
	var c = GameData.CROPS[crop_id]
	_show_message("Selected: %s (Cost: %dc)" % [c["name"], c["cost"]], false)

func _on_plot_clicked(idx: int):
	GameState.interact_with_tile(GameState.current_sector_coord, idx)
	_render_plot(idx)

func _on_tool_upgrade_pressed():
	if GameState.can_upgrade_tool():
		GameState.upgrade_tool()
	else:
		if GameState.tool_tier >= GameData.TOOL_TIERS.size() - 1:
			_show_message("Maximum tool tier reached!", false)
		else:
			var next = GameData.TOOL_TIERS[GameState.tool_tier + 1]
			_show_message("Need %dc, %dw, %ds for %s!" % [next["cost_coins"], next["cost_wood"], next["cost_stone"], next["name"]], false)

func _on_map_sector_clicked(coord: String):
	if GameState.is_sector_unlocked(coord):
		GameState.current_sector_coord = coord
		map_modal.visible = false
		_refresh_ui()
	else:
		if GameState.is_sector_adjacent_to_unlocked(coord):
			var sector_info = GameData.SECTORS.get(coord, {})
			var cost = sector_info.get("cost", 0)
			if GameState.coins >= cost:
				GameState.unlock_sector(coord)
				GameState.current_sector_coord = coord
				map_modal.visible = false
				_refresh_ui()
			else:
				_show_message("Need %dc to unlock %s!" % [cost, sector_info.get("name", "Land")], false)
		else:
			_show_message("Must unlock an adjacent plot first!", false)

func _refresh_ui():
	coins_label.text = "Coins: %d" % GameState.coins
	wood_label.text = "Wood: %d" % GameState.wood
	stone_label.text = "Stone: %d" % GameState.stone
	relics_label.text = "Relics: %d" % GameState.relics
	
	var s_info = GameData.SECTORS.get(GameState.current_sector_coord, {})
	sector_title.text = "%s (%s)" % [s_info.get("name", "Farm"), GameState.current_sector_coord]
	
	var cur_tool = GameState.get_tool_info()
	if GameState.tool_tier < GameData.TOOL_TIERS.size() - 1:
		var next_tool = GameData.TOOL_TIERS[GameState.tool_tier + 1]
		tool_btn.text = "%s\nUpgrade: %dc %dw %ds" % [cur_tool["name"], next_tool["cost_coins"], next_tool["cost_wood"], next_tool["cost_stone"]]
	else:
		tool_btn.text = "%s\n(Max Tier)" % cur_tool["name"]
	
	for i in range(16):
		_render_plot(i)
	
	_refresh_map_grid()

func _render_plot(idx: int):
	if idx >= plot_nodes.size():
		return
	var node = plot_nodes[idx]
	var soil_sprite = node.get_node("Soil") as Sprite2D
	var obj_sprite = node.get_node("ObjectSprite") as Sprite2D
	var badge = node.get_node("Badge") as Label
	
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	if idx >= tiles.size():
		soil_sprite.visible = false
		obj_sprite.visible = false
		badge.text = ""
		return
	
	var tile = tiles[idx]
	var type = tile.get("type", "grass")
	
	match type:
		"grass":
			soil_sprite.visible = false
			obj_sprite.visible = false
			badge.text = "" # Clean 70s meadow tile
		
		"obstacle":
			soil_sprite.visible = false
			obj_sprite.visible = true
			obj_sprite.scale = Vector2(0.38, 0.38)
			
			var obs = GameData.OBSTACLES[tile["obstacle_id"]]
			var seed_hash = abs((idx * 37) ^ (GameState.current_sector_coord.hash() * 19))
			
			match tile["obstacle_id"]:
				"weed":
					var w_idx = abs(tile.get("variant", seed_hash)) % tex_weeds.size()
					obj_sprite.texture = tex_weeds[w_idx]
					obj_sprite.offset = Vector2(0, -84)
					badge.position = Vector2(-50, -66)
				"small_wood", "hardwood_stump":
					var l_idx = abs(tile.get("variant", seed_hash)) % tex_logs.size()
					obj_sprite.texture = tex_logs[l_idx]
					if l_idx == 0:
						obj_sprite.offset = Vector2(-8, -54)
					else:
						obj_sprite.offset = Vector2(8, -54)
					badge.position = Vector2(-50, -48)
				"small_rock", "granite_boulder":
					var r_idx = abs(tile.get("variant", seed_hash)) % tex_rocks.size()
					obj_sprite.texture = tex_rocks[r_idx]
					if r_idx == 0:
						obj_sprite.offset = Vector2(-2, -80)
					elif r_idx == 1:
						obj_sprite.offset = Vector2(-12, -76)
					else:
						obj_sprite.offset = Vector2(0, -82)
					badge.position = Vector2(-50, -58)
				_:
					obj_sprite.texture = tex_weeds[0]
					obj_sprite.offset = Vector2(0, -84)
					badge.position = Vector2(-50, -66)
			
			badge.text = "%d" % tile["taps_left"]
			if obs["required_tool_tier"] > GameState.tool_tier:
				badge.modulate = Color(1.0, 0.45, 0.45, 1.0)
				obj_sprite.modulate = Color(1.0, 0.6, 0.6)
			else:
				badge.modulate = Color(1.0, 0.95, 0.75, 1.0)
				obj_sprite.modulate = Color.WHITE
		
		"soil":
			soil_sprite.visible = true
			var state = tile.get("state", "empty")
			
			if state == "empty":
				obj_sprite.visible = false
				badge.text = "" # Clean furrowed plot ready for seeds
			
			elif state == "growing":
				obj_sprite.visible = true
				var now = Time.get_unix_time_from_system()
				var elapsed = now - tile.get("plant_time", now)
				var total = max(1.0, tile.get("grow_duration", 1.0))
				var pct = elapsed / total
				var crop_id = tile.get("crop", "wheat")
				
				if crop_id == "wheat":
					obj_sprite.offset = Vector2(0, -96)
					badge.position = Vector2(-50, -90)
					if pct < 0.33:
						obj_sprite.texture = tex_wheat_sprout
					elif pct < 0.66:
						obj_sprite.texture = tex_wheat_growing
					else:
						obj_sprite.texture = tex_wheat_heading
				else:
					obj_sprite.offset = Vector2(0, -32)
					badge.position = Vector2(-50, -48)
					if pct < 0.5:
						obj_sprite.texture = tex_wheat_sprout
					else:
						obj_sprite.texture = tex_wheat_growing
				
				obj_sprite.modulate = Color.WHITE
				var remain = max(0.0, total - elapsed)
				badge.text = "%ds" % ceil(remain)
				badge.modulate = Color(0.9, 1.0, 0.7, 1.0)
			
			elif state == "ready":
				obj_sprite.visible = true
				var crop_id = tile.get("crop", "wheat")
				var is_mut = tile.get("is_mutated", false)
				
				match crop_id:
					"wheat":
						obj_sprite.offset = Vector2(0, -96)
						badge.position = Vector2(-50, -112)
						if is_mut:
							obj_sprite.texture = tex_wheat_legendary
							obj_sprite.modulate = Color.WHITE
							badge.text = "★GOLDEN!★ (+%dc)" % GameData.CROPS[crop_id]["mutated_reward"]
							badge.modulate = Color(1.0, 0.88, 0.2, 1.0)
						else:
							obj_sprite.texture = tex_wheat_mature
							obj_sprite.modulate = Color.WHITE
							badge.text = "HARVEST! (+%dc)" % GameData.CROPS[crop_id]["reward"]
							badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					"carrot":
						obj_sprite.offset = Vector2(0, -32)
						badge.position = Vector2(-50, -48)
						obj_sprite.texture = tex_carrot
						obj_sprite.modulate = Color.WHITE
						badge.text = "HARVEST! (+%dc)" % GameData.CROPS[crop_id]["reward"]
						badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					"strawberry":
						obj_sprite.offset = Vector2(0, -32)
						badge.position = Vector2(-50, -48)
						obj_sprite.texture = tex_berry
						obj_sprite.modulate = Color.WHITE
						badge.text = "HARVEST! (+%dc)" % GameData.CROPS[crop_id]["reward"]
						badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					_:
						obj_sprite.offset = Vector2(0, -96)
						obj_sprite.texture = tex_wheat_mature
						obj_sprite.modulate = Color.WHITE
						badge.text = "HARVEST!"
						badge.modulate = Color.WHITE

func _update_active_crop_labels():
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	var now = Time.get_unix_time_from_system()
	for i in range(tiles.size()):
		var tile = tiles[i]
		if tile.get("type") == "soil" and tile.get("state") == "growing":
			var elapsed = now - tile.get("plant_time", now)
			var total = max(1.0, tile.get("grow_duration", 1.0))
			var remain = max(0.0, total - elapsed)
			if remain <= 0.0:
				tile["state"] = "ready"
				_render_plot(i)
			else:
				var node = plot_nodes[i]
				var badge = node.get_node("Badge") as Label
				badge.text = "%ds" % ceil(remain)
				
				# Update visual growth phase in real time
				var crop_id = tile.get("crop", "wheat")
				var pct = elapsed / total
				var obj_sprite = node.get_node("ObjectSprite") as Sprite2D
				if crop_id == "wheat":
					if pct < 0.33:
						if obj_sprite.texture != tex_wheat_sprout:
							obj_sprite.texture = tex_wheat_sprout
					elif pct < 0.66:
						if obj_sprite.texture != tex_wheat_growing:
							obj_sprite.texture = tex_wheat_growing
					else:
						if obj_sprite.texture != tex_wheat_heading:
							obj_sprite.texture = tex_wheat_heading

func _refresh_map_grid():
	var idx = 0
	for y in range(3):
		for x in range(3):
			var coord = "%d,%d" % [x, y]
			var btn = map_grid.get_child(idx) as Button
			var s_data = GameData.SECTORS.get(coord, {})
			var is_current = (coord == GameState.current_sector_coord)
			
			if GameState.is_sector_unlocked(coord):
				btn.text = "%s%s\n[Visit]" % ["[CURRENT] " if is_current else "", s_data.get("name", "Land")]
				btn.modulate = Color(0.6, 0.9, 0.6) if not is_current else Color(0.4, 1.0, 0.4)
			else:
				var cost = s_data.get("cost", 0)
				var can_unlock = GameState.is_sector_adjacent_to_unlocked(coord)
				if can_unlock:
					btn.text = "[LOCKED] %s\nUnlock: %dc" % [s_data.get("name", "New Plot"), cost]
					btn.modulate = Color(1.0, 0.85, 0.4) if GameState.coins >= cost else Color(0.8, 0.6, 0.4)
				else:
					btn.text = "[LOCKED]\n(Far away)"
					btn.modulate = Color(0.5, 0.5, 0.5)
			idx += 1

func _on_tile_updated(coord: String, tile_idx: int):
	if coord == GameState.current_sector_coord:
		_render_plot(tile_idx)

func _show_message(text: String, is_reward: bool):
	status_banner.text = text
	status_banner.modulate = Color(1.0, 0.92, 0.3) if is_reward else Color(1.0, 1.0, 1.0)
