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

var tex_sprout = preload("res://assets/objects/sprout.png")
var tex_crop_mid = preload("res://assets/objects/crop_mid.png")
var tex_wheat = preload("res://assets/objects/wheat_mature.png")
var tex_carrot = preload("res://assets/objects/carrot_mature.png")
var tex_berry = preload("res://assets/objects/berry_mature.png")
var tex_stump = preload("res://assets/objects/stump.png")
var tex_boulder = preload("res://assets/objects/boulder.png")
var tex_weed = preload("res://assets/objects/weed.png")

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
	world_container.add_child(meadow_container)
	world_container.move_child(meadow_container, 0)
	
	var origin_x = 0.0
	var origin_y = -60.0
	var empty_style = StyleBoxEmpty.new()
	var s = (ISO_W / 256.0) * 1.004 # 0.4% bleed prevents subpixel gap seams
	
	# 1. Build surrounding continuous meadow (16x16 field)
	for my in range(-6, 10):
		for mx in range(-6, 10):
			if mx >= 0 and mx <= 3 and my >= 0 and my <= 3:
				continue
				
			var m_iso_x = origin_x + (mx - my) * (ISO_W * 0.5)
			var m_iso_y = origin_y + (mx + my) * (ISO_H * 0.5)
			
			var spr = Sprite2D.new()
			spr.position = Vector2(m_iso_x, m_iso_y)
			spr.scale = Vector2(s, s)
			spr.z_index = -50
			
			# Weighted natural distribution across the 8 grass variants
			var h = abs((mx * 73856093) ^ (my * 19349663) ^ (mx * my * 83492791)) % 100
			var g_idx = 0
			if h < 45:
				g_idx = 0 # Plain olive lawn
			elif h < 68:
				g_idx = 1 # Grass blade tufts
			elif h < 78:
				g_idx = 2 # Golden buttercups
			elif h < 86:
				g_idx = 3 # Clover clusters
			elif h < 92:
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
		
		# 2:1 Isometric formula
		var iso_x = origin_x + (gx - gy) * (ISO_W * 0.5)
		var iso_y = origin_y + (gx + gy) * (ISO_H * 0.5)
		
		var node = Node2D.new()
		node.name = "Plot_%d" % i
		node.position = Vector2(iso_x, iso_y)
		node.z_index = gx + gy # Natural isometric Y-sorting
		
		# Layer 0: Seamless 2:1 Grass Diamond (Base of every cell)
		var grass_sprite = Sprite2D.new()
		grass_sprite.name = "Grass"
		var farm_h = abs((gx * 73856093) ^ (gy * 19349663) ^ (gx * gy * 83492791)) % 100
		var g_idx = 0
		if farm_h < 40:
			g_idx = 0
		elif farm_h < 65:
			g_idx = 1
		elif farm_h < 75:
			g_idx = 2
		elif farm_h < 85:
			g_idx = 3
		elif farm_h < 92:
			g_idx = 4
		elif farm_h < 96:
			g_idx = 5
		else:
			g_idx = 6
		grass_sprite.texture = tex_grass[g_idx]
		grass_sprite.scale = Vector2(s, s)
		grass_sprite.position = Vector2.ZERO
		node.add_child(grass_sprite)
		
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
			var obs = GameData.OBSTACLES[tile["obstacle_id"]]
			
			match tile["obstacle_id"]:
				"hardwood_stump":
					obj_sprite.texture = tex_stump
				"granite_boulder":
					obj_sprite.texture = tex_boulder
				"small_rock":
					obj_sprite.texture = tex_boulder
				"small_wood":
					obj_sprite.texture = tex_stump
				_:
					obj_sprite.texture = tex_weed
			
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
				var pct = elapsed / max(1.0, tile.get("grow_duration", 1.0))
				
				if pct < 0.5:
					obj_sprite.texture = tex_sprout
				else:
					obj_sprite.texture = tex_crop_mid
				obj_sprite.modulate = Color.WHITE
				
				var remain = max(0.0, tile.get("grow_duration", 0.0) - elapsed)
				badge.text = "%ds" % ceil(remain)
				badge.modulate = Color(0.9, 1.0, 0.7, 1.0)
			
			elif state == "ready":
				obj_sprite.visible = true
				var crop_id = tile["crop"]
				match crop_id:
					"wheat":
						obj_sprite.texture = tex_wheat
					"carrot":
						obj_sprite.texture = tex_carrot
					"strawberry":
						obj_sprite.texture = tex_berry
					_:
						obj_sprite.texture = tex_wheat
				
				var is_mut = tile.get("is_mutated", false)
				if is_mut:
					obj_sprite.modulate = Color(1.3, 1.15, 0.3)
					badge.text = "GOLDEN! (+%dc)" % GameData.CROPS[crop_id]["mutated_reward"]
					badge.modulate = Color(1.0, 0.88, 0.2, 1.0)
				else:
					obj_sprite.modulate = Color.WHITE
					badge.text = "HARVEST! (+%dc)" % GameData.CROPS[crop_id]["reward"]
					badge.modulate = Color(1.0, 1.0, 0.4, 1.0)

func _update_active_crop_labels():
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	var now = Time.get_unix_time_from_system()
	for i in range(tiles.size()):
		var tile = tiles[i]
		if tile.get("type") == "soil" and tile.get("state") == "growing":
			var elapsed = now - tile.get("plant_time", now)
			var remain = max(0.0, tile.get("grow_duration", 0.0) - elapsed)
			if remain <= 0.0:
				tile["state"] = "ready"
				_render_plot(i)
			else:
				var badge = plot_nodes[i].get_node("Badge") as Label
				badge.text = "%ds" % ceil(remain)

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
