extends SceneTree

func _initialize():
	call_deferred("_run")

func _assert_fits(control: Control, width: float):
	assert(control.get_global_rect().end.x <= width + 1, "%s overflows: %s" % [control.name, control.get_global_rect()])
	assert(control.get_global_rect().position.x >= -1, "%s starts outside viewport" % control.name)

func _run():
	var farm = load("res://scenes/main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	await process_frame
	assert(farm.mobile_ui, "Run with -- --mobile-ui")
	var width = farm.get_viewport_rect().size.x
	assert(is_equal_approx(width, 440), "Phone logical width")
	for button in [farm.dock_barn_btn, farm.dock_active_seed_btn, farm.dock_tool_btn, farm.dock_market_btn]:
		_assert_fits(button, width)
		assert(button.size.y >= 48, "Touch target height")
	_assert_fits(farm.resources_container, width)
	_assert_fits(farm.barn_btn, width)
	for open_modal in [farm._open_seed_modal, farm._open_market_modal, farm._open_barn_modal]:
		open_modal.call()
		await process_frame
		await process_frame
		var modal = farm.seed_modal if farm.seed_modal.visible else (farm.market_modal if farm.market_modal.visible else farm.barn_modal)
		for child in modal.get_children():
			if child is PanelContainer:
				_assert_fits(child, width)
		farm.seed_modal.visible = false
		farm.market_modal.visible = false
		farm.barn_modal.visible = false
	print("PASS: mobile HUD, touch targets, and menus fit phone width")
	quit()
