extends Control

# FarmingApp: Main UI & Sector Grid Controller

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

var tile_buttons: Array[Button] = []

func _ready():
	_setup_grid_buttons()
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
	# Refresh growing crop timers in the current sector
	GameState.update_crop_timers()
	_update_active_crop_labels()

func _setup_grid_buttons():
	tile_buttons.clear()
	for child in tile_grid.get_children():
		child.queue_free()
	
	for i in range(16):
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.add_theme_font_size_override("font_size", 16)
		
		var idx = i
		btn.pressed.connect(func(): _on_tile_clicked(idx))
		tile_grid.add_child(btn)
		tile_buttons.append(btn)

func _setup_seed_buttons():
	for child in seed_bar.get_children():
		child.queue_free()
	
	var group = ButtonGroup.new()
	for crop_id in GameData.CROPS:
		var c = GameData.CROPS[crop_id]
		var btn = Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.text = "%s %s\n%d🪙" % [c["emoji"], c["name"], c["cost"]]
		btn.add_theme_font_size_override("font_size", 15)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var id = crop_id
		btn.pressed.connect(func(): _select_crop(id))
		seed_bar.add_child(btn)
		
		if crop_id == GameState.selected_crop:
			btn.button_pressed = true

func _setup_map_buttons():
	for child in map_grid.get_children():
		child.queue_free()
	
	# 3x3 sectors
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
	_show_message("Selected seed: %s %s (Cost: %d🪙)" % [c["emoji"], c["name"], c["cost"]], false)

func _on_tile_clicked(idx: int):
	GameState.interact_with_tile(GameState.current_sector_coord, idx)
	_render_tile(idx)

func _on_tool_upgrade_pressed():
	if GameState.can_upgrade_tool():
		GameState.upgrade_tool()
	else:
		if GameState.tool_tier >= GameData.TOOL_TIERS.size() - 1:
			_show_message("Maximum tool tier reached! 🌟", false)
		else:
			var next = GameData.TOOL_TIERS[GameState.tool_tier + 1]
			_show_message("Need %d🪙, %d🪵, %d🪨 for %s!" % [next["cost_coins"], next["cost_wood"], next["cost_stone"], next["name"]], false)

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
				_show_message("Need %d🪙 to unlock %s!" % [cost, sector_info.get("name", "Land")], false)
		else:
			_show_message("Must unlock an adjacent plot first!", false)

func _refresh_ui():
	coins_label.text = "🪙 %d" % GameState.coins
	wood_label.text = "🪵 %d" % GameState.wood
	stone_label.text = "🪨 %d" % GameState.stone
	relics_label.text = "🏺 %d" % GameState.relics
	
	var s_info = GameData.SECTORS.get(GameState.current_sector_coord, {})
	sector_title.text = "📍 %s (%s)" % [s_info.get("name", "Wilderness"), GameState.current_sector_coord]
	
	# Tool upgrade button text
	var cur_tool = GameState.get_tool_info()
	if GameState.tool_tier < GameData.TOOL_TIERS.size() - 1:
		var next_tool = GameData.TOOL_TIERS[GameState.tool_tier + 1]
		tool_btn.text = "🛠️ %s\nUpgrade: %d🪙 %d🪵 %d🪨" % [cur_tool["name"], next_tool["cost_coins"], next_tool["cost_wood"], next_tool["cost_stone"]]
	else:
		tool_btn.text = "👑 %s\n(Max Tier Reached)" % cur_tool["name"]
	
	# Render all 16 tiles in current sector
	for i in range(16):
		_render_tile(i)
	
	_refresh_map_grid()

func _render_tile(idx: int):
	if idx >= tile_buttons.size():
		return
	var btn = tile_buttons[idx]
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	if idx >= tiles.size():
		btn.text = ""
		btn.modulate = Color.WHITE
		return
	
	var tile = tiles[idx]
	var type = tile.get("type", "grass")
	
	match type:
		"obstacle":
			var obs = GameData.OBSTACLES[tile["obstacle_id"]]
			btn.text = "%s %s\n[%d taps left]" % [obs["emoji"], obs["name"], tile["taps_left"]]
			if obs["required_tool_tier"] > GameState.tool_tier:
				btn.modulate = Color(0.9, 0.4, 0.4) # Reddish if locked
			else:
				btn.modulate = Color(0.85, 0.7, 0.5) # Tan wood/stone
		"grass":
			btn.text = "🌱 Wild Grass\n[Tap to Till (5🪙)]"
			btn.modulate = Color(0.4, 0.75, 0.35)
		"soil":
			var state = tile.get("state", "empty")
			if state == "empty":
				btn.text = "🟫 Tilled Soil\n[Plant %s]" % GameState.selected_crop.capitalize()
				btn.modulate = Color(0.65, 0.5, 0.35)
			elif state == "ready":
				var crop = GameData.CROPS[tile["crop"]]
				var is_mut = tile.get("is_mutated", false)
				if is_mut:
					btn.text = "🌟 %s\nREADY TO HARVEST!\n+%d🪙" % [crop["mutated_name"], crop["mutated_reward"]]
					btn.modulate = Color(1.0, 0.85, 0.1) # Sparkling gold
				else:
					btn.text = "%s %s\nREADY!\n+%d🪙" % [crop["emoji"], crop["name"], crop["reward"]]
					btn.modulate = Color(1.0, 1.0, 0.4) # Bright yellow
			elif state == "growing":
				var crop = GameData.CROPS[tile["crop"]]
				btn.text = "%s Growing...\n[Calculating]" % crop["emoji"]
				btn.modulate = Color(0.5, 0.85, 0.5)

func _update_active_crop_labels():
	var tiles = GameState.sector_tiles.get(GameState.current_sector_coord, [])
	var now = Time.get_unix_time_from_system()
	for i in range(tiles.size()):
		var tile = tiles[i]
		if tile.get("type") == "soil" and tile.get("state") == "growing":
			var crop = GameData.CROPS[tile["crop"]]
			var elapsed = now - tile.get("plant_time", now)
			var remain = max(0.0, tile.get("grow_duration", 0.0) - elapsed)
			if remain > 0:
				tile_buttons[i].text = "%s Growing...\n%ds left" % [crop["emoji"], ceil(remain)]
			else:
				tile["state"] = "ready"
				_render_tile(i)

func _refresh_map_grid():
	var idx = 0
	for y in range(3):
		for x in range(3):
			var coord = "%d,%d" % [x, y]
			var btn = map_grid.get_child(idx) as Button
			var s_data = GameData.SECTORS.get(coord, {})
			var is_current = (coord == GameState.current_sector_coord)
			
			if GameState.is_sector_unlocked(coord):
				btn.text = "%s%s\n[Visit]" % ["📍 " if is_current else "🗺️ ", s_data.get("name", "Land")]
				btn.modulate = Color(0.5, 0.9, 0.5) if not is_current else Color(0.3, 1.0, 0.3)
			else:
				var cost = s_data.get("cost", 0)
				var can_unlock = GameState.is_sector_adjacent_to_unlocked(coord)
				if can_unlock:
					btn.text = "🔒 %s\nUnlock: %d🪙" % [s_data.get("name", "New Plot"), cost]
					btn.modulate = Color(1.0, 0.8, 0.3) if GameState.coins >= cost else Color(0.8, 0.5, 0.3)
				else:
					btn.text = "🔒 Locked\n(Far away)"
					btn.modulate = Color(0.5, 0.5, 0.5)
			idx += 1

func _on_tile_updated(coord: String, tile_idx: int):
	if coord == GameState.current_sector_coord:
		_render_tile(tile_idx)

func _show_message(text: String, is_reward: bool):
	status_banner.text = text
	status_banner.modulate = Color(1.0, 0.9, 0.2) if is_reward else Color(1.0, 1.0, 1.0)
