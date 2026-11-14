extends Node2D

var active: Dictionary = {}

func play(tile_idx: int, at_position: Vector2, tool_id: String, tier: int, feedback: String):
	# Repeated taps restart the cosmetic effect, never queue extra game actions.
	_clear_tile(tile_idx)
	var effect = Node2D.new()
	effect.position = at_position
	add_child(effect)
	var tool = Sprite2D.new()
	tool.texture = load(GameData.get_tool_icon_path(tool_id, tier))
	tool.offset = Vector2(0, -40)
	tool.scale = Vector2(0.8, 0.8)
	tool.position = Vector2(16, -12)
	tool.rotation_degrees = -55 if tool_id == "axe" else -35
	effect.add_child(tool)
	var text = Label.new()
	text.text = feedback
	text.position = Vector2(-80, -122)
	text.size = Vector2(160, 32)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color("fff0a6"))
	text.add_theme_color_override("font_shadow_color", Color("302014"))
	text.add_theme_constant_override("shadow_offset_x", 2)
	text.add_theme_constant_override("shadow_offset_y", 2)
	effect.add_child(text)
	var tween = create_tween().bind_node(effect)
	active[tile_idx] = {"node": effect, "tween": tween}
	if tool_id == "hoe":
		tween.tween_property(tool, "position", Vector2(0, 14), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(tool, "rotation_degrees", 20.0, 0.14)
		tween.tween_property(tool, "position", Vector2(-18, -6), 0.16)
	else:
		tween.tween_property(tool, "rotation_degrees", 50.0 if tool_id == "axe" else 35.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(tool, "rotation_degrees", 10.0, 0.12)
	tween.tween_property(effect, "modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(text, "position:y", -145.0, 0.28)
	tween.finished.connect(func():
		active.erase(tile_idx)
		effect.queue_free()
	)

func _clear_tile(tile_idx: int):
	if active.has(tile_idx):
		active[tile_idx]["tween"].kill()
		active[tile_idx]["node"].queue_free()
		active.erase(tile_idx)

func clear():
	for tile_idx in active.keys():
		_clear_tile(tile_idx)
