extends Control

var title_label: Label
var tier_label: Label
var upgrade_label: Label
var missing_label: Label
var upgrade_button: Button
var tool_icons: Dictionary = {}
var tool_titles: Dictionary = {}

func setup(mobile: bool):
	name = "ToolMenu"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu_theme = Theme.new()
	menu_theme.default_font_size = 17
	theme = menu_theme
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.74)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			visible = false
	)
	var panel = PanelContainer.new()
	panel.name = "ToolPanel"
	add_child(panel)
	if mobile:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 12
		panel.offset_right = -12
		panel.offset_top = 12
		panel.offset_bottom = -12
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.offset_left = -330
		panel.offset_right = 330
		panel.offset_top = -320
		panel.offset_bottom = 320
	var style = StyleBoxFlat.new()
	style.bg_color = Color("302014")
	style.border_color = Color("e1bd58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	title_label = _label("Farm Tools", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(80, 48)
	close_button.pressed.connect(func(): visible = false)
	header.add_child(close_button)
	# Keep the footer reachable even on short landscape screens.
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	content.add_child(_label("Tools work automatically. Tap wood, rocks, weeds, or grass to use the right tool.", 16))
	tier_label = _label("", 18)
	tier_label.add_theme_color_override("font_color", Color("f3d77b"))
	content.add_child(tier_label)
	for tool_id in GameData.TOOLS:
		var card = PanelContainer.new()
		var card_style = style.duplicate()
		card_style.bg_color = Color("48311c")
		card_style.border_color = Color("876b3b")
		card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)
		content.add_child(card)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		tool_icons[tool_id] = icon
		var details = VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 6)
		row.add_child(details)
		var tool_title = _label("", 20)
		tool_title.add_theme_color_override("font_color", Color("f3d77b"))
		details.add_child(tool_title)
		tool_titles[tool_id] = tool_title
		details.add_child(_label(GameData.TOOLS[tool_id]["purpose"], 16))
		details.add_child(_label(GameData.TOOLS[tool_id]["requirements"], 14))
	upgrade_label = _label("", 16)
	content.add_child(upgrade_label)
	missing_label = _label("", 15)
	missing_label.add_theme_color_override("font_color", Color("ffd29c"))
	column.add_child(missing_label)
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeAllTools"
	upgrade_button.custom_minimum_size.y = 52
	upgrade_button.pressed.connect(func():
		GameState.upgrade_tool()
		refresh()
	)
	column.add_child(upgrade_button)
	refresh()

func _label(text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func refresh():
	var tier: int = GameState.tool_tier
	var material: String = GameData.TOOL_MATERIALS[tier].capitalize()
	tier_label.text = "%s toolkit • All three tools upgrade together" % material
	for tool_id in tool_icons:
		tool_icons[tool_id].texture = load(GameData.get_tool_icon_path(tool_id, tier))
		tool_titles[tool_id].text = "%s %s" % [material, GameData.TOOLS[tool_id]["name"]]
	if tier == GameData.TOOL_TIERS.size() - 1:
		upgrade_label.text = GameData.TOOL_TIERS[tier]["description"]
		missing_label.text = "All three tools are fully upgraded."
		upgrade_button.text = "Fully upgraded"
		upgrade_button.disabled = true
		return
	var next: Dictionary = GameData.TOOL_TIERS[tier + 1]
	upgrade_label.text = "Next: %s\n%s\nCost: %d coins • %d wood • %d stone" % [next["name"], next["description"], next["cost_coins"], next["cost_wood"], next["cost_stone"]]
	var missing: Array[String] = []
	for resource in ["coins", "wood", "stone"]:
		var shortage: int = next["cost_" + resource] - int(GameState.get(resource))
		if shortage > 0:
			missing.append("%d %s" % [shortage, resource])
	missing_label.text = "Need %s" % ", ".join(missing) if not missing.is_empty() else "Ready to upgrade all three tools."
	upgrade_button.text = "Upgrade All Tools"
	upgrade_button.disabled = not GameState.can_upgrade_tool()

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()
