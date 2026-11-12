extends Control

# FarmingApp: Layered Meadow Grid & 1970s UI Controller

@onready var coins_label = $Margin/VBox/TopBar/Resources/Coins
@onready var wood_label = $Margin/VBox/TopBar/Resources/Wood
@onready var stone_label = $Margin/VBox/TopBar/Resources/Stone
@onready var relics_label = $Margin/VBox/TopBar/Resources/Relics
@onready var sector_title = $Margin/VBox/TopBar/SectorInfo/SectorTitle
@onready var status_banner = $Margin/VBox/StatusBanner

@onready var tile_grid = $Margin/VBox/GridContainer
@onready var seed_bar = $Margin/VBox/BottomControls/SeedBar
@onready var tool_btn = $Margin/VBox/BottomControls/ToolUpgradeBtn
@onready var map_modal = $MapModal
@onready var map_grid = $MapModal/Panel/VBox/MapGrid

var grass_textures: Array[Texture2D] = []
var tile_controls: Array[Control] = []

func _ready():
	_load_grass_textures()
	_setup_grid_cells()
	_setup_seed_buttons()
	_setup_map_buttons()
	
	GameState.state_updated.connect(_refresh_ui)
	GameState.tile_updated.connect(_on_tile_updated)
	GameState.message_broadcast.connect(_show_message)
	
	tool_btn.pressed.connect(_on_tool_upgrade_pressed)
	$Margin/VBox/TopBar/SectorInfo/MapBtn.pressed.connect(func(): map_modal.visible = true)
	$MapModal/Panel/VBox/CloseMapBtn.pressed.connect(func(): map_modal.visible = false)
	
	_select_crop("wheat")
	_refresh_ui()

func _process(_delta: float):
	GameState.update_crop_timers()
	_update_active_crop_labels()

func _load_grass_textures():
	grass_textures.clear()
	for i in range(8):
		var path = "res://assets/tiles/grass_%d.png" % i
		if ResourceLoader.exists(path):
			grass_textures.append(load(path))

func _get_grass_for_cell(idx: int) -> Texture2D:
	if grass_textures.is_empty():
		return null
	# Organic pseudo-random variation per tile
	var seed_val = (idx * 3 + (idx / 4) * 5) % grass_textures.size()
	return grass_textures[seed_val]

func _setup_grid_cells():
	tile_controls.clear()
	for child in tile_grid.get_children():
		child.queue_free()
	
	for i in range(16):
		var cell_root = Control.new()
		cell_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell_root.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Layer 0: Grass Meadow Background
		var grass_tex = TextureRect.new()
		grass_tex.name = "GrassBG"
		grass_tex.texture = _get_grass_for_cell(i)
		grass_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grass_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		grass_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		grass_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_root.add_child(grass_tex)
		
		# Layer 1: Tilled Soil Bed (Only visible if tilled soil)
		var soil_bed = ColorRect.new()
		soil_bed.name = "SoilBed"
		soil_bed.color = Color(0.24, 0.16, 0.11, 0.90) # Rich dark umber loam
		soil_bed.set_anchors_preset(Control.PRESET_FULL_RECT)
		soil_bed.offset_left = 6
		soil_bed.offset_top = 6
		soil_bed.offset_right = -6
		soil_bed.offset_bottom = -6
		soil_bed.visible = false
		soil_bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_root.add_child(soil_bed)
		
		# Layer 2: Interactive Touch Button & Badge
		var btn = Button.new()
		btn.name = "CellButton"
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.add_theme_font_size_override("font_size", 15)
		
		var idx = i
		btn.pressed.connect(func(): _on_tile_clicked(idx))
		cell_root.add_child(btn)
		
		tile_grid.add_child(cell_root)
		tile_controls.append(cell_root)

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
	_show_message("Selected seed: %s (Cost: %dc)" % [c["name"], c["cost"]], false)

func _on_tile_clicked(idx: int):
	GameState.interact_with_tile(GameState.current_sector_coord, idx)
	_render_cell(idx)

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
	sector_title.text = "%s (%s)" % [s_info.get("name", "Meadow"), GameState.current_sector_coord]
	
	var cur_tool = GameState.get_tool_info()
	if GameState.tool_tier < GameData.TOOL_TIERS.size() - 1:
		var next_tool = GameData.TOOL_TIERS[GameState.tool_tier + 1]
		tool_btn.text = "%s\nUpgrade: %dc %dw %ds" % [cur_tool["name"], next_tool["cost_coins"], next_tool["cost_wood"], next_tool["cost_stone"]]
	else:
		tool_btn.text = "%s\n(Max Tier)" % cur_tool["name"]
	
	for i in range(16):
		_render_cell(i)
	
	_refresh_map_grid()

func _render_cell(idx: int):
	if idx >= tile_controls.size():
		return
	var cell = tile_controls[idx]
	var soil_bed = cell.get_node("SoilBed") as ColorRect
	var btn = cell.get_node("CellButton") as Button
	
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	if idx >= tiles.size():
		soil_bed.visible = false
		btn.text = ""
		return
	
	var tile = tiles[idx]
	var type = tile.get("type", "grass")
	
	match type:
		"grass":
			# Pure clean meadow grass! No soil bed.
			soil_bed.visible = false
			btn.text = "" # Clean meadow, tap to till
			btn.modulate = Color.WHITE
		
		"obstacle":
			# Obstacle sits directly on top of the grass meadow
			soil_bed.visible = false
			var obs = GameData.OBSTACLES[tile["obstacle_id"]]
			btn.text = "[%s]\n%d taps" % [obs["name"], tile["taps_left"]]
			if obs["required_tool_tier"] > GameState.tool_tier:
				btn.modulate = Color(1.0, 0.45, 0.45) # Warning red
			else:
				btn.modulate = Color(1.0, 0.95, 0.75) # Warm parchment
		
		"soil":
			# Tilled soil bed overlays the grass
			soil_bed.visible = true
			var state = tile.get("state", "empty")
			if state == "empty":
				btn.text = "Tilled Soil\n[Plant %s]" % GameState.selected_crop.capitalize()
				btn.modulate = Color(0.9, 0.85, 0.75)
			elif state == "ready":
				var crop = GameData.CROPS[tile["crop"]]
				var is_mut = tile.get("is_mutated", false)
				if is_mut:
					btn.text = "**%s**\nHARVEST! (+%dc)" % [crop["mutated_name"].to_upper(), crop["mutated_reward"]]
					btn.modulate = Color(1.0, 0.88, 0.2) # Radiant gold
				else:
					btn.text = "%s\nHARVEST! (+%dc)" % [crop["name"].to_upper(), crop["reward"]]
					btn.modulate = Color(1.0, 1.0, 0.5) # Ripe yellow
			elif state == "growing":
				var crop = GameData.CROPS[tile["crop"]]
				btn.text = "%s (Growing)" % crop["name"]
				btn.modulate = Color(0.7, 0.95, 0.7)

func _update_active_crop_labels():
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	var now = Time.get_unix_time_from_system()
	for i in range(tiles.size()):
		var tile = tiles[i]
		if tile.get("type") == "soil" and tile.get("state") == "growing":
			var crop = GameData.CROPS[tile["crop"]]
			var elapsed = now - tile.get("plant_time", now)
			var remain = max(0.0, tile.get("grow_duration", 0.0) - elapsed)
			var btn = tile_controls[i].get_node("CellButton") as Button
			if remain > 0:
				btn.text = "%s\n%ds left" % [crop["name"], ceil(remain)]
			else:
				tile["state"] = "ready"
				_render_cell(i)

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
		_render_cell(tile_idx)

func _show_message(text: String, is_reward: bool):
	status_banner.text = text
	status_banner.modulate = Color(1.0, 0.92, 0.3) if is_reward else Color(1.0, 1.0, 1.0)
