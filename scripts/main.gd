extends Control

# FarmingApp: Authentic 2:1 Isometric FarmVille Engine
# Interlocking 2:1 Grass & Plowed Soil Diamonds in 1970s National Park Olive Palette

const ISO_W = 160.0
const ISO_H = 80.0
const MIN_ZOOM = 0.6
const MAX_ZOOM = 3.0
const TAP_SLOP = 10.0

@onready var world_container = $WorldViewport/World
@onready var plots_root = $WorldViewport/World/Plots
@onready var camera = $WorldViewport/World/Camera2D

@onready var resources_container = $HUD/Margin/VBox/TopBar/Resources
var coins_label: Label
var wood_label: Label
var stone_label: Label
var relics_label: Label
@onready var sector_title = $HUD/Margin/VBox/TopBar/SectorInfo/SectorTitle
@onready var status_banner = $HUD/Margin/VBox/StatusBanner

@onready var bottom_controls = $HUD/Margin/VBox/BottomControls
@onready var map_modal = $HUD/MapModal
@onready var map_grid = $HUD/MapModal/Panel/VBox/MapGrid

# Gardener's Dock Controls
var dock_barn_btn: Button
var dock_barn_title: Label
var dock_barn_sub: Label
var dock_barn_icon: TextureRect

var dock_active_seed_btn: Button
var dock_seed_title: Label
var dock_seed_sub: Label
var dock_seed_icon: TextureRect

var dock_tool_btn: Button
var dock_tool_title: Label
var dock_tool_sub: Label
var dock_tool_icon: TextureRect

var dock_market_btn: Button
var dock_market_title: Label
var dock_market_sub: Label
var dock_market_icon: TextureRect

# Dock Illustrated Icon Textures
var tex_dock_barn = preload("res://assets/ui/dock_icon_barn.png")
var tex_dock_seed = preload("res://assets/ui/dock_icon_seed.png")
var tex_dock_tools = preload("res://assets/ui/dock_icon_tools.png")
var tex_dock_market = preload("res://assets/ui/dock_icon_market.png")

# Top HUD Resource Icons
var tex_res_coin = preload("res://assets/ui/res_icon_coin.png")
var tex_res_wood = preload("res://assets/ui/res_icon_wood.png")
var tex_res_stone = preload("res://assets/ui/res_icon_stone.png")
var tex_res_relic = preload("res://assets/ui/res_icon_relic.png")

# Seed Pouch Modal & Market Modal
var seed_modal: Control
var seed_modal_items_vbox: VBoxContainer
var seed_modal_balance_label: Label

var market_modal: Control
var market_items_vbox: VBoxContainer
var market_balance_label: Label
var market_empty_label: Label

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

# Crop Growth Stages
# Wheat
var tex_wheat_sprout = preload("res://assets/objects/wheat_sprout.png")
var tex_wheat_growing = preload("res://assets/objects/wheat_growing.png")
var tex_wheat_heading = preload("res://assets/objects/wheat_heading.png")
var tex_wheat_mature = preload("res://assets/objects/wheat_mature.png")
var tex_wheat_legendary = preload("res://assets/objects/wheat_legendary.png")

# Carrot
var tex_carrot_sprout = preload("res://assets/objects/carrot_sprout.png")
var tex_carrot_growing = preload("res://assets/objects/carrot_growing.png")
var tex_carrot_mature = preload("res://assets/objects/carrot_mature.png")
var tex_carrot_crystal = preload("res://assets/objects/carrot_crystal.png")

# Strawberry
var tex_strawberry_sprout = preload("res://assets/objects/strawberry_sprout.png")
var tex_strawberry_flowering = preload("res://assets/objects/strawberry_flowering.png")
var tex_strawberry_mature = preload("res://assets/objects/strawberry_mature.png")
var tex_strawberry_jeweled = preload("res://assets/objects/strawberry_jeweled.png")

# Pumpkin
var tex_pumpkin_sprout = preload("res://assets/objects/pumpkin_sprout.png")
var tex_pumpkin_vine = preload("res://assets/objects/pumpkin_vine.png")
var tex_pumpkin_mature = preload("res://assets/objects/pumpkin_mature.png")
var tex_pumpkin_haunted = preload("res://assets/objects/pumpkin_haunted.png")

# Barn & Storage
var tex_barn = preload("res://assets/objects/barn.png")
var tex_barn_interior = preload("res://assets/ui/barn_interior.png")
var barn_modal: Control
var barn_slots_container: GridContainer
var barn_title_label: Label
var barn_detail_label: Label
var barn_btn: Button

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
var total_drag_dist: float = 0.0
var touch_points: Dictionary = {}
var touch_start: Vector2 = Vector2.ZERO
var touch_moved: bool = false
var touch_was_multitouch: bool = false
var zoom_reset_btn: Button

func _ready():
	_build_isometric_grid()
	_setup_gardener_dock()
	_setup_resource_bar()
	_setup_zoom_controls()
	_build_seed_modal()
	_build_market_modal()
	_build_barn_modal()
	_setup_map_buttons()
	
	GameState.state_updated.connect(_refresh_ui)
	GameState.tile_updated.connect(_on_tile_updated)
	GameState.message_broadcast.connect(_show_message)
	GameState.barn_opened.connect(_open_barn_modal)
	GameState.barn_updated.connect(_refresh_barn_modal)
	GameState.barn_updated.connect(_refresh_market_modal)
	
	var make_wood_small_sb = func() -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.14, 0.09, 0.90)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.65, 0.50, 0.30, 0.85)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		return sb
		
	var map_btn = $HUD/Margin/VBox/TopBar/SectorInfo/MapBtn
	map_btn.add_theme_stylebox_override("normal", make_wood_small_sb.call())
	map_btn.pressed.connect(func(): map_modal.visible = true)
	$HUD/MapModal/Panel/VBox/CloseMapBtn.pressed.connect(func(): map_modal.visible = false)
	
	barn_btn = Button.new()
	barn_btn.text = "Barn (0/10)"
	barn_btn.add_theme_stylebox_override("normal", make_wood_small_sb.call())
	barn_btn.pressed.connect(_open_barn_modal)
	$HUD/Margin/VBox/TopBar/SectorInfo.add_child(barn_btn)
	
	_select_crop("wheat")
	_refresh_ui()

func _process(_delta: float):
	GameState.update_crop_timers()
	_update_active_crop_labels()

func _farm_modal_open() -> bool:
	return map_modal.visible or (seed_modal and seed_modal.visible) or (market_modal and market_modal.visible) or (barn_modal and barn_modal.visible)

func _input(event: InputEvent):
	# Finish tracked touches even when released over a HUD button.
	if event is InputEventScreenTouch and not event.pressed and touch_points.has(event.index):
		var tapped = not event.canceled and not touch_moved and not touch_was_multitouch and not _farm_modal_open()
		touch_points.erase(event.index)
		if tapped:
			_handle_isometric_click(event.position)
		if touch_points.is_empty():
			touch_was_multitouch = false
			touch_moved = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		if _farm_modal_open():
			touch_points.clear()
			return
		var old_center = _touch_center()
		var old_distance = _touch_distance()
		var previous: Vector2 = touch_points[event.index]
		touch_points[event.index] = event.position
		if touch_points.size() >= 2:
			var new_center = _touch_center()
			if old_distance > 1.0:
				_zoom_at(camera.zoom.x * _touch_distance() / old_distance, old_center)
			camera.position -= (new_center - old_center) / camera.zoom
		else:
			if event.position.distance_to(touch_start) > TAP_SLOP:
				touch_moved = true
			if touch_moved or touch_was_multitouch:
				camera.position -= (event.position - previous) / camera.zoom
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if _farm_modal_open():
		is_dragging = false
		return
	if event is InputEventScreenTouch and event.pressed:
		if touch_points.is_empty():
			touch_start = event.position
			touch_moved = false
			touch_was_multitouch = false
		touch_points[event.index] = event.position
		if touch_points.size() > 1:
			touch_was_multitouch = true
		is_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_zoom_at(camera.zoom.x * event.factor, event.position)
	elif event is InputEventMouseButton:
		# Touch is handled above; ignore its synthetic mouse events.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				total_drag_dist = 0.0
				drag_start_mouse = event.position
				drag_start_cam = camera.position
			else:
				if is_dragging and total_drag_dist < TAP_SLOP:
					_handle_isometric_click(event.position)
				is_dragging = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(camera.zoom.x * 1.1, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(camera.zoom.x / 1.1, event.position)
	elif event is InputEventMouseMotion and is_dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging = false
			return
		total_drag_dist = maxf(total_drag_dist, event.position.distance_to(drag_start_mouse))
		camera.position = drag_start_cam + (drag_start_mouse - event.position) / camera.zoom

func _touch_center() -> Vector2:
	var center = Vector2.ZERO
	for point in touch_points.values():
		center += point
	return center / touch_points.size()

func _touch_distance() -> float:
	var points = touch_points.values()
	return points[0].distance_to(points[1]) if points.size() >= 2 else 0.0

func _zoom_at(value: float, screen_position: Vector2):
	var old_zoom: float = camera.zoom.x
	var new_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	var offset = screen_position - get_viewport_rect().size * 0.5
	camera.position += offset * (1.0 / old_zoom - 1.0 / new_zoom)
	camera.zoom = Vector2.ONE * new_zoom
	zoom_reset_btn.text = "%d%% Reset" % roundi(new_zoom * 100.0)

func _setup_zoom_controls():
	var controls = HBoxContainer.new()
	controls.name = "ZoomControls"
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.add_theme_constant_override("separation", 8)
	$HUD/Margin/VBox.add_child(controls)
	$HUD/Margin/VBox.move_child(controls, 2)
	for caption in ["−", "100% Reset", "+"]:
		var button = Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(64, 56)
		button.add_theme_font_size_override("font_size", 22)
		controls.add_child(button)
		if caption == "100% Reset":
			zoom_reset_btn = button
			button.pressed.connect(func():
				camera.position = Vector2.ZERO
				_zoom_at(1.0, get_viewport_rect().size * 0.5)
			)
		else:
			var factor = 1.2 if caption == "+" else 1.0 / 1.2
			button.pressed.connect(func(): _zoom_at(camera.zoom.x * factor, get_viewport_rect().size * 0.5))

func _handle_isometric_click(screen_position: Vector2):
	var local_pos = plots_root.get_global_transform_with_canvas().affine_inverse() * screen_position
	var origin_x = 0.0
	var origin_y = -60.0
	
	var dx = local_pos.x - origin_x
	var dy = local_pos.y - origin_y
	
	# Pure 2:1 isometric diamond inversion formula (exact diamond hit-test, zero neighbor overlap)
	var gx = int(floor((dx / ISO_W) + (dy / ISO_H) + 0.5))
	var gy = int(floor((dy / ISO_H) - (dx / ISO_W) + 0.5))
	
	if gx >= 0 and gx < 4 and gy >= 0 and gy < 4:
		var idx = gy * 4 + gx
		_on_plot_clicked(idx)

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
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(100, 24)
		badge.position = Vector2(-50, -48)
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		node.add_child(badge)
		
		plots_root.add_child(node)
		plot_nodes.append(node)

func _format_number(val: int) -> String:
	var s = str(val)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			res = "," + res
	return res

func _setup_resource_bar():
	for child in resources_container.get_children():
		child.queue_free()
		
	resources_container.alignment = BoxContainer.ALIGNMENT_END
	resources_container.add_theme_constant_override("separation", 10)
	
	var create_res_badge = func(icon_tex: Texture2D, border_col: Color, text_col: Color) -> Label:
		var pill = PanelContainer.new()
		pill.custom_minimum_size = Vector2(0, 36)
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.12, 0.08, 0.92)
		sb.set_border_width_all(2)
		sb.border_color = border_col
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 8
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		pill.add_theme_stylebox_override("panel", sb)
		
		var h = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 8)
		pill.add_child(h)
		
		var ic = TextureRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = icon_tex
		h.add_child(ic)
		
		var val_lbl = Label.new()
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.add_theme_color_override("font_color", text_col)
		val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		val_lbl.add_theme_constant_override("shadow_offset_x", 1)
		val_lbl.add_theme_constant_override("shadow_offset_y", 1)
		h.add_child(val_lbl)
		
		resources_container.add_child(pill)
		return val_lbl

	coins_label = create_res_badge.call(tex_res_coin, Color(0.95, 0.80, 0.30, 0.9), Color(1.0, 0.92, 0.65, 1.0))
	wood_label = create_res_badge.call(tex_res_wood, Color(0.70, 0.50, 0.28, 0.85), Color(0.96, 0.90, 0.82, 1.0))
	stone_label = create_res_badge.call(tex_res_stone, Color(0.65, 0.62, 0.55, 0.85), Color(0.90, 0.90, 0.88, 1.0))
	relics_label = create_res_badge.call(tex_res_relic, Color(0.75, 0.55, 0.95, 0.9), Color(0.92, 0.85, 1.0, 1.0))

func _setup_gardener_dock():
	for child in bottom_controls.get_children():
		child.queue_free()
	
	bottom_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_controls.add_theme_constant_override("separation", 14)
	
	var make_wood_sb = func(bg: Color, border: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_border_width_all(2)
		sb.border_color = border
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		return sb
		
	var normal_wood = make_wood_sb.call(Color(0.20, 0.13, 0.08, 0.94), Color(0.60, 0.45, 0.25, 0.85))
	var hover_wood = make_wood_sb.call(Color(0.28, 0.18, 0.11, 0.98), Color(0.95, 0.80, 0.35, 1.0))
	var active_gold = make_wood_sb.call(Color(0.24, 0.15, 0.08, 0.96), Color(1.0, 0.82, 0.25, 1.0))
	
	var build_dock_button_content = func(btn: Button, icon_tex: Texture2D) -> Dictionary:
		var inner = HBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.anchors_preset = Control.PRESET_FULL_RECT
		inner.offset_left = 10
		inner.offset_right = -10
		inner.offset_top = 4
		inner.offset_bottom = -4
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 10)
		btn.add_child(inner)
		
		var icon_rect = TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.custom_minimum_size = Vector2(38, 38)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon_tex
		inner.add_child(icon_rect)
		
		var text_vbox = VBoxContainer.new()
		text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		text_vbox.add_theme_constant_override("separation", 1)
		inner.add_child(text_vbox)
		
		var title_lbl = Label.new()
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
		title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		title_lbl.add_theme_constant_override("shadow_offset_x", 1)
		title_lbl.add_theme_constant_override("shadow_offset_y", 1)
		text_vbox.add_child(title_lbl)
		
		var sub_lbl = Label.new()
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.95))
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		sub_lbl.add_theme_constant_override("shadow_offset_x", 1)
		sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
		text_vbox.add_child(sub_lbl)
		
		return {"icon": icon_rect, "title": title_lbl, "sub": sub_lbl}
	
	# 1. Barn Storage Shortcut Button
	dock_barn_btn = Button.new()
	dock_barn_btn.custom_minimum_size = Vector2(165, 58)
	dock_barn_btn.text = ""
	dock_barn_btn.add_theme_stylebox_override("normal", normal_wood)
	dock_barn_btn.add_theme_stylebox_override("hover", hover_wood)
	dock_barn_btn.add_theme_stylebox_override("pressed", hover_wood)
	dock_barn_btn.pressed.connect(_open_barn_modal)
	var b_parts = build_dock_button_content.call(dock_barn_btn, tex_dock_barn)
	dock_barn_icon = b_parts["icon"]
	dock_barn_title = b_parts["title"]
	dock_barn_sub = b_parts["sub"]
	dock_barn_title.text = "Red Barn"
	dock_barn_sub.text = "Storage (0/10)"
	bottom_controls.add_child(dock_barn_btn)
	
	# 2. Active Seed Pill (Click to open Seed Pouch Drawer)
	dock_active_seed_btn = Button.new()
	dock_active_seed_btn.custom_minimum_size = Vector2(230, 58)
	dock_active_seed_btn.text = ""
	dock_active_seed_btn.add_theme_stylebox_override("normal", active_gold)
	dock_active_seed_btn.add_theme_stylebox_override("hover", hover_wood)
	dock_active_seed_btn.add_theme_stylebox_override("pressed", hover_wood)
	dock_active_seed_btn.pressed.connect(_open_seed_modal)
	var s_parts = build_dock_button_content.call(dock_active_seed_btn, tex_dock_seed)
	dock_seed_icon = s_parts["icon"]
	dock_seed_title = s_parts["title"]
	dock_seed_sub = s_parts["sub"]
	dock_seed_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 1.0))
	dock_seed_title.text = "Active Seed"
	dock_seed_sub.text = "Wheat (10c) [v]"
	bottom_controls.add_child(dock_active_seed_btn)
	
	# 3. Tool Bench Button
	dock_tool_btn = Button.new()
	dock_tool_btn.custom_minimum_size = Vector2(195, 58)
	dock_tool_btn.text = ""
	dock_tool_btn.add_theme_stylebox_override("normal", normal_wood)
	dock_tool_btn.add_theme_stylebox_override("hover", hover_wood)
	dock_tool_btn.add_theme_stylebox_override("pressed", hover_wood)
	dock_tool_btn.pressed.connect(_on_tool_upgrade_pressed)
	var t_parts = build_dock_button_content.call(dock_tool_btn, tex_dock_tools)
	dock_tool_icon = t_parts["icon"]
	dock_tool_title = t_parts["title"]
	dock_tool_sub = t_parts["sub"]
	dock_tool_title.text = "Wooden Tools"
	dock_tool_sub.text = "Up: 200c 20w 20s"
	bottom_controls.add_child(dock_tool_btn)
	
	# 4. Market / Farm Stand Button
	dock_market_btn = Button.new()
	dock_market_btn.custom_minimum_size = Vector2(165, 58)
	dock_market_btn.text = ""
	var market_sb = make_wood_sb.call(Color(0.14, 0.22, 0.12, 0.94), Color(0.45, 0.75, 0.35, 0.85))
	var market_hover = make_wood_sb.call(Color(0.18, 0.28, 0.15, 0.98), Color(0.70, 1.0, 0.50, 1.0))
	dock_market_btn.add_theme_stylebox_override("normal", market_sb)
	dock_market_btn.add_theme_stylebox_override("hover", market_hover)
	dock_market_btn.add_theme_stylebox_override("pressed", market_hover)
	dock_market_btn.pressed.connect(_open_market_modal)
	var m_parts = build_dock_button_content.call(dock_market_btn, tex_dock_market)
	dock_market_icon = m_parts["icon"]
	dock_market_title = m_parts["title"]
	dock_market_sub = m_parts["sub"]
	dock_market_title.text = "Town Market"
	dock_market_sub.text = "Sell Harvest"
	bottom_controls.add_child(dock_market_btn)

func _select_crop(crop_id: String):
	GameState.selected_crop = crop_id
	var c = GameData.CROPS[crop_id]
	var count = GameState.get_seed_count(crop_id)
	_show_message("Equipped %s seeds (%d ready in pouch)" % [c["name"], count], false)
	_refresh_gardener_dock()
	if seed_modal and seed_modal.visible:
		_refresh_seed_modal()

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

func _refresh_gardener_dock():
	if dock_barn_sub:
		var used = GameState.get_barn_used_slots()
		dock_barn_sub.text = "Storage (%d/10)" % used
		
	if dock_seed_title and dock_seed_sub:
		var c = GameData.CROPS.get(GameState.selected_crop, {})
		var count = GameState.get_seed_count(GameState.selected_crop)
		dock_seed_title.text = "Seed: %s" % c.get("name", "Wheat")
		if count > 0:
			dock_seed_sub.text = "%d in Pouch • [Change]" % count
			dock_seed_sub.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.95))
		else:
			dock_seed_sub.text = "0 in Pouch • [Buy Seeds]"
			dock_seed_sub.add_theme_color_override("font_color", Color(1.0, 0.50, 0.40, 1.0))
			
		var item_info = GameData.get_item_info(GameState.selected_crop)
		if dock_seed_icon:
			if item_info.get("icon", "") != "":
				dock_seed_icon.texture = load(item_info["icon"])
			else:
				dock_seed_icon.texture = tex_dock_seed
		
	if dock_tool_title and dock_tool_sub:
		var cur_tool = GameState.get_tool_info()
		dock_tool_title.text = cur_tool.get("name", "Tools")
		if GameState.tool_tier < GameData.TOOL_TIERS.size() - 1:
			var next_tool = GameData.TOOL_TIERS[GameState.tool_tier + 1]
			dock_tool_sub.text = "Up: %dc %dw %ds" % [next_tool["cost_coins"], next_tool["cost_wood"], next_tool["cost_stone"]]
		else:
			dock_tool_sub.text = "Max Tier"

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
	if coins_label:
		coins_label.text = _format_number(GameState.coins)
	if wood_label:
		wood_label.text = _format_number(GameState.wood)
	if stone_label:
		stone_label.text = _format_number(GameState.stone)
	if relics_label:
		relics_label.text = _format_number(GameState.relics)
	
	var s_info = GameData.SECTORS.get(GameState.current_sector_coord, {})
	sector_title.text = "%s (%s)" % [s_info.get("name", "Farm"), GameState.current_sector_coord]
	
	if barn_btn:
		barn_btn.text = "Barn (%d/10)" % GameState.get_barn_used_slots()
		
	_refresh_gardener_dock()
	
	if seed_modal and seed_modal.visible:
		_refresh_seed_modal()
		
	if market_modal and market_modal.visible:
		_refresh_market_modal()
	
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
		"barn":
			soil_sprite.visible = false
			obj_sprite.visible = true
			obj_sprite.texture = tex_barn
			obj_sprite.scale = Vector2(0.90, 0.90)
			obj_sprite.offset = Vector2(0, -96)
			obj_sprite.modulate = Color.WHITE
			badge.position = Vector2(-70, -145)
			badge.text = "Red Barn [Storage]"
			badge.modulate = Color(1.0, 0.92, 0.65, 1.0)
		
		"grass":
			soil_sprite.visible = false
			obj_sprite.visible = false
			badge.text = "" # Clean 70s meadow tile
		
		"obstacle":
			var s = (ISO_W / 256.0) * 1.002
			soil_sprite.visible = false
			obj_sprite.visible = true
			obj_sprite.scale = Vector2(s, s)
			obj_sprite.offset = Vector2(0, -22)
			badge.position = Vector2(-50, -56)
			
			var obs = GameData.OBSTACLES[tile["obstacle_id"]]
			var seed_hash = abs((idx * 37) ^ (GameState.current_sector_coord.hash() * 19))
			
			match tile["obstacle_id"]:
				"weed":
					var w_idx = abs(tile.get("variant", seed_hash)) % tex_weeds.size()
					obj_sprite.texture = tex_weeds[w_idx]
				"small_wood", "hardwood_stump":
					var l_idx = abs(tile.get("variant", seed_hash)) % tex_logs.size()
					obj_sprite.texture = tex_logs[l_idx]
				"small_rock", "granite_boulder":
					var r_idx = abs(tile.get("variant", seed_hash)) % tex_rocks.size()
					obj_sprite.texture = tex_rocks[r_idx]
				_:
					obj_sprite.texture = tex_weeds[0]
			
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
				
				# All growing stages use authentic 256x256 growth sprites centered in the middle of the diamond
				obj_sprite.offset = Vector2(0, -96)
				obj_sprite.scale = Vector2(0.60, 0.60)
				badge.position = Vector2(-50, -90)
				
				match crop_id:
					"wheat":
						if pct < 0.33:
							obj_sprite.texture = tex_wheat_sprout
						elif pct < 0.66:
							obj_sprite.texture = tex_wheat_growing
						else:
							obj_sprite.texture = tex_wheat_heading
					"carrot":
						if pct < 0.5:
							obj_sprite.texture = tex_carrot_sprout
						else:
							obj_sprite.texture = tex_carrot_growing
					"strawberry":
						if pct < 0.5:
							obj_sprite.texture = tex_strawberry_sprout
						else:
							obj_sprite.texture = tex_strawberry_flowering
					"pumpkin":
						if pct < 0.5:
							obj_sprite.texture = tex_pumpkin_sprout
						else:
							obj_sprite.texture = tex_pumpkin_vine
					_:
						obj_sprite.texture = tex_wheat_sprout
				
				obj_sprite.modulate = Color.WHITE
				var remain = max(0.0, total - elapsed)
				badge.text = "%ds" % ceil(remain)
				badge.modulate = Color(0.9, 1.0, 0.7, 1.0)
			
			elif state == "ready":
				obj_sprite.visible = true
				obj_sprite.offset = Vector2(0, -96)
				obj_sprite.scale = Vector2(0.60, 0.60)
				badge.position = Vector2(-50, -112)
				
				var crop_id = tile.get("crop", "wheat")
				var is_mut = tile.get("is_mutated", false)
				var c_data = GameData.CROPS.get(crop_id, {})
				
				match crop_id:
					"wheat":
						if is_mut:
							obj_sprite.texture = tex_wheat_legendary
							badge.text = "[GOLDEN!] (+%dc)" % c_data.get("mutated_reward", 100)
							badge.modulate = Color(1.0, 0.88, 0.2, 1.0)
						else:
							obj_sprite.texture = tex_wheat_mature
							badge.text = "HARVEST! (+%dc)" % c_data.get("reward", 25)
							badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					"carrot":
						if is_mut:
							obj_sprite.texture = tex_carrot_crystal
							badge.text = "[CRYSTAL!] (+%dc)" % c_data.get("mutated_reward", 250)
							badge.modulate = Color(0.4, 0.9, 1.0, 1.0)
						else:
							obj_sprite.texture = tex_carrot_mature
							badge.text = "HARVEST! (+%dc)" % c_data.get("reward", 65)
							badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					"strawberry":
						if is_mut:
							obj_sprite.texture = tex_strawberry_jeweled
							badge.text = "[JEWELED!] (+%dc)" % c_data.get("mutated_reward", 600)
							badge.modulate = Color(1.0, 0.4, 0.8, 1.0)
						else:
							obj_sprite.texture = tex_strawberry_mature
							badge.text = "HARVEST! (+%dc)" % c_data.get("reward", 160)
							badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					"pumpkin":
						if is_mut:
							obj_sprite.texture = tex_pumpkin_haunted
							badge.text = "[HAUNTED!] (+%dc)" % c_data.get("mutated_reward", 1800)
							badge.modulate = Color(0.7, 0.4, 1.0, 1.0)
						else:
							obj_sprite.texture = tex_pumpkin_mature
							badge.text = "HARVEST! (+%dc)" % c_data.get("reward", 450)
							badge.modulate = Color(1.0, 1.0, 0.4, 1.0)
					_:
						obj_sprite.texture = tex_wheat_mature
						badge.text = "HARVEST!"
						badge.modulate = Color.WHITE
				
				obj_sprite.modulate = Color.WHITE

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
				match crop_id:
					"wheat":
						if pct < 0.33:
							if obj_sprite.texture != tex_wheat_sprout:
								obj_sprite.texture = tex_wheat_sprout
						elif pct < 0.66:
							if obj_sprite.texture != tex_wheat_growing:
								obj_sprite.texture = tex_wheat_growing
						else:
							if obj_sprite.texture != tex_wheat_heading:
								obj_sprite.texture = tex_wheat_heading
					"carrot":
						if pct < 0.5:
							if obj_sprite.texture != tex_carrot_sprout:
								obj_sprite.texture = tex_carrot_sprout
						else:
							if obj_sprite.texture != tex_carrot_growing:
								obj_sprite.texture = tex_carrot_growing
					"strawberry":
						if pct < 0.5:
							if obj_sprite.texture != tex_strawberry_sprout:
								obj_sprite.texture = tex_strawberry_sprout
						else:
							if obj_sprite.texture != tex_strawberry_flowering:
								obj_sprite.texture = tex_strawberry_flowering
					"pumpkin":
						if pct < 0.5:
							if obj_sprite.texture != tex_pumpkin_sprout:
								obj_sprite.texture = tex_pumpkin_sprout
						else:
							if obj_sprite.texture != tex_pumpkin_vine:
								obj_sprite.texture = tex_pumpkin_vine

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

# Barn Storage UI Modal (10 slots, stacks of 10 max)
func _build_barn_modal():
	barn_modal = Control.new()
	barn_modal.name = "BarnModal"
	barn_modal.visible = false
	$HUD.add_child(barn_modal)
	barn_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Dimmed dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.70)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			barn_modal.visible = false
	)
	barn_modal.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Barn Interior Card / TextureRect (Explicitly centered in viewport)
	var frame = TextureRect.new()
	frame.texture = tex_barn_interior
	frame.custom_minimum_size = Vector2(860, 640)
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -430.0
	frame.offset_right = 430.0
	frame.offset_top = -320.0
	frame.offset_bottom = 320.0
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	barn_modal.add_child(frame)
	
	# Close button (top right)
	var close_btn = Button.new()
	close_btn.text = " [X] Close "
	close_btn.position = Vector2(740, 24)
	close_btn.custom_minimum_size = Vector2(90, 36)
	close_btn.pressed.connect(func(): barn_modal.visible = false)
	frame.add_child(close_btn)
	
	# Title Banner
	barn_title_label = Label.new()
	barn_title_label.position = Vector2(100, 28)
	barn_title_label.size = Vector2(660, 36)
	barn_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barn_title_label.text = "RED BARN STORAGE (0 / 10 Slots)"
	barn_title_label.add_theme_font_size_override("font_size", 22)
	barn_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	barn_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	barn_title_label.add_theme_constant_override("shadow_offset_x", 2)
	barn_title_label.add_theme_constant_override("shadow_offset_y", 2)
	frame.add_child(barn_title_label)
	
	# Subtitle / Hint
	var sub_label = Label.new()
	sub_label.position = Vector2(100, 66)
	sub_label.size = Vector2(660, 24)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.text = "Harvested crops automatically store here • Up to 10 items per stack"
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.9))
	sub_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sub_label.add_theme_constant_override("shadow_offset_x", 1)
	sub_label.add_theme_constant_override("shadow_offset_y", 1)
	frame.add_child(sub_label)
	
	# Grid Container (5 cols x 2 rows = 10 slots) positioned in the central counter
	barn_slots_container = GridContainer.new()
	barn_slots_container.columns = 5
	barn_slots_container.position = Vector2(150, 230)
	barn_slots_container.size = Vector2(560, 220)
	barn_slots_container.add_theme_constant_override("h_separation", 16)
	barn_slots_container.add_theme_constant_override("v_separation", 16)
	frame.add_child(barn_slots_container)
	
	for i in range(10):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(96, 96)
		slot_btn.name = "Slot_%d" % i
		slot_btn.clip_contents = true
		
		# Inset panel styling
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.07, 0.88)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.65, 0.48, 0.22, 0.75)
		sb.set_corner_radius_all(8)
		slot_btn.add_theme_stylebox_override("normal", sb)
		
		var sb_h = sb.duplicate()
		sb_h.border_color = Color(1.0, 0.85, 0.35, 1.0)
		sb_h.bg_color = Color(0.24, 0.16, 0.10, 0.95)
		slot_btn.add_theme_stylebox_override("hover", sb_h)
		slot_btn.add_theme_stylebox_override("pressed", sb_h)
		
		# Icon (Crisp, large, centered)
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(68, 68)
		icon.position = Vector2(14, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(icon)
		
		# Item Name (Top)
		var name_lbl = Label.new()
		name_lbl.name = "ItemName"
		name_lbl.size = Vector2(96, 20)
		name_lbl.position = Vector2(0, 4)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75, 0.95))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(name_lbl)
		
		# Count badge (bottom right)
		var count_lbl = Label.new()
		count_lbl.name = "CountBadge"
		count_lbl.size = Vector2(90, 22)
		count_lbl.position = Vector2(0, 70)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
		count_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		count_lbl.add_theme_constant_override("shadow_offset_x", 1)
		count_lbl.add_theme_constant_override("shadow_offset_y", 1)
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(count_lbl)
		
		var slot_idx = i
		slot_btn.pressed.connect(func(): _on_barn_slot_clicked(slot_idx))
		barn_slots_container.add_child(slot_btn)
		
	# Item detail inspection box (bottom)
	barn_detail_label = Label.new()
	barn_detail_label.position = Vector2(100, 475)
	barn_detail_label.size = Vector2(660, 48)
	barn_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barn_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	barn_detail_label.text = "Click any item to inspect details"
	barn_detail_label.add_theme_font_size_override("font_size", 14)
	barn_detail_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.8, 1.0))
	barn_detail_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	barn_detail_label.add_theme_constant_override("shadow_offset_x", 1)
	barn_detail_label.add_theme_constant_override("shadow_offset_y", 1)
	frame.add_child(barn_detail_label)

func _open_barn_modal():
	if seed_modal:
		seed_modal.visible = false
	if market_modal:
		market_modal.visible = false
	barn_modal.visible = true
	_refresh_barn_modal()

func _refresh_barn_modal():
	if not barn_modal or not barn_slots_container:
		return
	var count = GameState.get_barn_used_slots()
	barn_title_label.text = "RED BARN STORAGE (%d / 10 Slots)" % count
	
	for i in range(10):
		var btn = barn_slots_container.get_child(i) as Button
		var icon = btn.get_node("Icon") as TextureRect
		var name_lbl = btn.get_node("ItemName") as Label
		var count_lbl = btn.get_node("CountBadge") as Label
		
		if i < GameState.barn_inventory.size():
			var item = GameState.barn_inventory[i]
			var info = GameData.get_item_info(item["id"])
			name_lbl.text = item.get("name", "Crop")
			count_lbl.text = "x%d" % item.get("count", 1)
			if info.get("icon", "") != "":
				icon.texture = load(info["icon"])
				icon.visible = true
			else:
				icon.visible = false
			name_lbl.visible = true
			count_lbl.visible = true
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75, 0.95))
		else:
			count_lbl.text = ""
			icon.visible = false
			name_lbl.text = "[ Empty ]"
			name_lbl.visible = true
			name_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.5))

func _on_barn_slot_clicked(slot_idx: int):
	if slot_idx < GameState.barn_inventory.size():
		var item = GameState.barn_inventory[slot_idx]
		var info = GameData.get_item_info(item["id"])
		barn_detail_label.text = "%s (x%d in stock) • Sell Value: %dc each\n\"%s\"" % [
			info["name"], item["count"], info["sell_value"], info["desc"]
		]
	else:
		barn_detail_label.text = "Empty Storage Slot (%d of 10) • Harvested crops are stored here automatically!" % (slot_idx + 1)

# Seed Pouch & Nursery Merchant Modal
func _build_seed_modal():
	seed_modal = Control.new()
	seed_modal.name = "SeedModal"
	seed_modal.visible = false
	$HUD.add_child(seed_modal)
	seed_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Dimmed dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			seed_modal.visible = false
	)
	seed_modal.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Seed Merchant Card Panel (Explicitly centered in viewport)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 500)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380.0
	panel.offset_right = 380.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.18, 0.12, 0.08, 0.98)
	psb.set_border_width_all(3)
	psb.border_color = Color(0.95, 0.80, 0.35, 1.0)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 22
	psb.content_margin_right = 22
	psb.content_margin_top = 18
	psb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", psb)
	seed_modal.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Top bar: Title & Close
	var top_h = HBoxContainer.new()
	vbox.add_child(top_h)
	
	var title = Label.new()
	title.text = "SEED POUCH & NURSERY MERCHANT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55, 1.0))
	top_h.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = " [X] Close "
	close_btn.pressed.connect(func(): seed_modal.visible = false)
	top_h.add_child(close_btn)
	
	# Subtitle / Coins info
	var sub_h = HBoxContainer.new()
	vbox.add_child(sub_h)
	
	var sub = Label.new()
	sub.text = "Equip seeds for planting, or buy new seed packets with gold coins."
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.9))
	sub_h.add_child(sub)
	
	seed_modal_balance_label = Label.new()
	seed_modal_balance_label.text = "Your Coins: %dc" % GameState.coins
	seed_modal_balance_label.add_theme_font_size_override("font_size", 15)
	seed_modal_balance_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	sub_h.add_child(seed_modal_balance_label)
	
	# Scrollable container for seed cards
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	vbox.add_child(scroll)
	
	seed_modal_items_vbox = VBoxContainer.new()
	seed_modal_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_modal_items_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(seed_modal_items_vbox)

func _open_seed_modal():
	if market_modal:
		market_modal.visible = false
	if barn_modal:
		barn_modal.visible = false
	seed_modal.visible = true
	_refresh_seed_modal()

func _refresh_seed_modal():
	if not seed_modal or not seed_modal_items_vbox:
		return
		
	seed_modal_balance_label.text = "Your Coins: %dc" % GameState.coins
	
	for child in seed_modal_items_vbox.get_children():
		child.queue_free()
		
	for crop_id in GameData.CROPS:
		var c = GameData.CROPS[crop_id]
		var item_info = GameData.get_item_info(crop_id)
		var seed_count = GameState.get_seed_count(crop_id)
		var is_equipped = (GameState.selected_crop == crop_id)
		
		var row = PanelContainer.new()
		var r_sb = StyleBoxFlat.new()
		if is_equipped:
			r_sb.bg_color = Color(0.28, 0.20, 0.10, 0.95)
			r_sb.set_border_width_all(2)
			r_sb.border_color = Color(1.0, 0.85, 0.30, 1.0)
		else:
			r_sb.bg_color = Color(0.22, 0.14, 0.08, 0.92)
			r_sb.set_border_width_all(1)
			r_sb.border_color = Color(0.50, 0.38, 0.22, 0.7)
		r_sb.set_corner_radius_all(10)
		r_sb.content_margin_left = 14
		r_sb.content_margin_right = 14
		r_sb.content_margin_top = 8
		r_sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", r_sb)
		
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 14)
		row.add_child(rh)
		
		# 1. Crop Icon
		var ic = TextureRect.new()
		ic.custom_minimum_size = Vector2(48, 48)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if item_info.get("icon", "") != "":
			ic.texture = load(item_info["icon"])
		rh.add_child(ic)
		
		# 2. Crop Details VBox
		var info_v = VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.alignment = BoxContainer.ALIGNMENT_CENTER
		info_v.add_theme_constant_override("separation", 2)
		rh.add_child(info_v)
		
		var title_h = HBoxContainer.new()
		title_h.add_theme_constant_override("separation", 8)
		info_v.add_child(title_h)
		
		var name_lbl = Label.new()
		name_lbl.text = c["name"]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
		title_h.add_child(name_lbl)
		
		if is_equipped:
			var eq_tag = Label.new()
			eq_tag.text = "[EQUIPPED]"
			eq_tag.add_theme_font_size_override("font_size", 12)
			eq_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
			title_h.add_child(eq_tag)
			
		var stats_lbl = Label.new()
		stats_lbl.text = "Grow: %ds • Harvest: +%dc • Unit Cost: %dc" % [int(c["grow_time"]), c["reward"], c["cost"]]
		stats_lbl.add_theme_font_size_override("font_size", 12)
		stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.9))
		info_v.add_child(stats_lbl)
		
		var stock_lbl = Label.new()
		if seed_count > 0:
			stock_lbl.text = "In Pouch: %d seeds ready to plant" % seed_count
			stock_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.60, 1.0))
		else:
			stock_lbl.text = "Out of seeds! (Buy packets to the right)"
			stock_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
		stock_lbl.add_theme_font_size_override("font_size", 12)
		info_v.add_child(stock_lbl)
		
		# 3. Actions HBox (Equip, Buy 1, Buy 5)
		var acts_h = HBoxContainer.new()
		acts_h.alignment = BoxContainer.ALIGNMENT_CENTER
		acts_h.add_theme_constant_override("separation", 8)
		rh.add_child(acts_h)
		
		# Equip Button
		var eq_btn = Button.new()
		eq_btn.custom_minimum_size = Vector2(96, 38)
		if is_equipped:
			eq_btn.text = "Equipped"
			eq_btn.disabled = true
		else:
			eq_btn.text = "Equip Seed"
			var cid_equip = crop_id
			eq_btn.pressed.connect(func():
				_select_crop(cid_equip)
				_refresh_seed_modal()
			)
		acts_h.add_child(eq_btn)
		
		# Buy 1x Button
		var buy1_btn = Button.new()
		buy1_btn.custom_minimum_size = Vector2(90, 38)
		buy1_btn.text = "+1 (%dc)" % c["cost"]
		var cid_b1 = crop_id
		buy1_btn.pressed.connect(func():
			GameState.buy_seeds(cid_b1, 1)
			_refresh_seed_modal()
		)
		acts_h.add_child(buy1_btn)
		
		# Buy 5x Button
		var buy5_btn = Button.new()
		buy5_btn.custom_minimum_size = Vector2(96, 38)
		buy5_btn.text = "+5 (%dc)" % (c["cost"] * 5)
		var cid_b5 = crop_id
		buy5_btn.pressed.connect(func():
			GameState.buy_seeds(cid_b5, 5)
			_refresh_seed_modal()
		)
		acts_h.add_child(buy5_btn)
		
		seed_modal_items_vbox.add_child(row)

# Town Market & Farm Stand Modal (Selling crops from the Barn)
func _build_market_modal():
	market_modal = Control.new()
	market_modal.name = "MarketModal"
	market_modal.visible = false
	$HUD.add_child(market_modal)
	market_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Dimmed overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			market_modal.visible = false
	)
	market_modal.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Market Stall Panel (Explicitly centered in viewport)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 500)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370.0
	panel.offset_right = 370.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.18, 0.12, 0.08, 0.98)
	psb.set_border_width_all(3)
	psb.border_color = Color(0.85, 0.65, 0.25, 1.0)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 24
	psb.content_margin_right = 24
	psb.content_margin_top = 18
	psb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", psb)
	market_modal.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Top bar of modal: Title & Close
	var top_h = HBoxContainer.new()
	vbox.add_child(top_h)
	
	var title = Label.new()
	title.text = "TOWN MARKET & FARM STAND"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60, 1.0))
	top_h.add_child(title)
	
	var buy_seeds_btn = Button.new()
	buy_seeds_btn.text = " Buy Seeds... "
	buy_seeds_btn.pressed.connect(func(): _open_seed_modal())
	top_h.add_child(buy_seeds_btn)
	
	var close_btn = Button.new()
	close_btn.text = " [X] Close "
	close_btn.pressed.connect(func(): market_modal.visible = false)
	top_h.add_child(close_btn)
	
	# Subtitle / Balance
	var sub_h = HBoxContainer.new()
	vbox.add_child(sub_h)
	
	var sub = Label.new()
	sub.text = "Sell your harvested crops from the Barn for gold coins!"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.9))
	sub_h.add_child(sub)
	
	market_balance_label = Label.new()
	market_balance_label.text = "Your Coins: %dc" % GameState.coins
	market_balance_label.add_theme_font_size_override("font_size", 15)
	market_balance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	sub_h.add_child(market_balance_label)
	
	# Scroll area for items stored in Barn
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	market_items_vbox = VBoxContainer.new()
	market_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_items_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(market_items_vbox)
	
	market_empty_label = Label.new()
	market_empty_label.text = "Your Barn has no crops yet!\nGrow and harvest crops on your farm to store and sell them here."
	market_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	market_empty_label.custom_minimum_size = Vector2(0, 180)
	market_empty_label.add_theme_font_size_override("font_size", 15)
	market_empty_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.7))
	market_items_vbox.add_child(market_empty_label)
	
	# Bottom Action Bar: Sell All
	var bottom_h = HBoxContainer.new()
	bottom_h.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom_h)
	
	var sell_all_btn = Button.new()
	sell_all_btn.name = "SellAllBtn"
	sell_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_all_btn.custom_minimum_size = Vector2(0, 44)
	sell_all_btn.text = "Sell Entire Barn Harvest"
	sell_all_btn.add_theme_font_size_override("font_size", 14)
	
	var sb_green = StyleBoxFlat.new()
	sb_green.bg_color = Color(0.18, 0.35, 0.16, 0.95)
	sb_green.set_border_width_all(2)
	sb_green.border_color = Color(0.60, 0.95, 0.45, 0.9)
	sb_green.set_corner_radius_all(8)
	sell_all_btn.add_theme_stylebox_override("normal", sb_green)
	
	var sb_gh = sb_green.duplicate()
	sb_gh.bg_color = Color(0.24, 0.45, 0.20, 1.0)
	sb_gh.border_color = Color(0.80, 1.0, 0.60, 1.0)
	sell_all_btn.add_theme_stylebox_override("hover", sb_gh)
	sell_all_btn.add_theme_stylebox_override("pressed", sb_gh)
	sell_all_btn.pressed.connect(_on_market_sell_all_pressed)
	bottom_h.add_child(sell_all_btn)

func _open_market_modal():
	if seed_modal:
		seed_modal.visible = false
	if barn_modal:
		barn_modal.visible = false
	market_modal.visible = true
	_refresh_market_modal()

func _refresh_market_modal():
	if not market_modal or not market_items_vbox:
		return
		
	market_balance_label.text = "Your Coins: %dc" % GameState.coins
	
	# Clear previous rows (except empty label)
	for child in market_items_vbox.get_children():
		if child != market_empty_label:
			child.queue_free()
			
	var has_items = GameState.barn_inventory.size() > 0
	market_empty_label.visible = not has_items
	
	for i in range(GameState.barn_inventory.size()):
		var slot = GameState.barn_inventory[i]
		var item_info = GameData.get_item_info(slot["id"])
		var count = slot["count"]
		var unit_price = item_info.get("sell_value", 10)
		var total_price = unit_price * count
		
		var row = PanelContainer.new()
		var rsb = StyleBoxFlat.new()
		rsb.bg_color = Color(0.24, 0.17, 0.11, 0.92)
		rsb.set_border_width_all(1)
		rsb.border_color = Color(0.55, 0.42, 0.25, 0.6)
		rsb.set_corner_radius_all(8)
		rsb.content_margin_left = 12
		rsb.content_margin_right = 12
		rsb.content_margin_top = 8
		rsb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", rsb)
		
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 14)
		row.add_child(rh)
		
		# Icon
		var ic = TextureRect.new()
		ic.custom_minimum_size = Vector2(44, 44)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if item_info.get("icon", "") != "":
			ic.texture = load(item_info["icon"])
		rh.add_child(ic)
		
		# Name & Count
		var name_v = VBoxContainer.new()
		name_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(name_v)
		
		var nl = Label.new()
		nl.text = "%s (x%d in Barn)" % [item_info["name"], count]
		nl.add_theme_font_size_override("font_size", 14)
		nl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
		name_v.add_child(nl)
		
		var pl = Label.new()
		pl.text = "Value: +%dc each • Total: +%dc" % [unit_price, total_price]
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 0.95))
		name_v.add_child(pl)
		
		# Sell 1 Button
		var s1 = Button.new()
		s1.text = " Sell 1 (+%dc) " % unit_price
		var slot_idx = i
		s1.pressed.connect(func():
			GameState.sell_from_barn(slot_idx, 1)
			_refresh_market_modal()
		)
		rh.add_child(s1)
		
		# Sell All Button
		var sa = Button.new()
		sa.text = " Sell All (+%dc) " % total_price
		sa.pressed.connect(func():
			GameState.sell_from_barn(slot_idx, count)
			_refresh_market_modal()
		)
		rh.add_child(sa)
		
		market_items_vbox.add_child(row)

func _on_market_sell_all_pressed():
	GameState.sell_all_from_barn()
	_refresh_market_modal()
