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
	assert(is_equal_approx(width, 440 if root.size.y >= root.size.x else 900), "Mobile logical width")
	for button in [farm.dock_barn_btn, farm.dock_active_seed_btn, farm.dock_tool_btn, farm.dock_market_btn]:
		_assert_fits(button, width)
		assert(button.size.y >= 48, "Touch target height")
	_assert_fits(farm.resources_container, width)
	_assert_fits(farm.barn_btn, width)
	_assert_fits(farm.workshop_btn, width)
	_assert_fits(farm.dev_unlock_btn, width)
	_assert_fits(farm.mode_switcher_bar, width)
	_assert_fits(farm.mode_plant_btn, width)
	_assert_fits(farm.mode_tools_btn, width)
	assert(farm.mode_plant_btn.size.y >= 48, "Mode plant button touch target height")
	assert(farm.mode_tools_btn.size.y >= 48, "Mode tools button touch target height")
	
	# Mobile mode swap interaction & grass protection tests
	var state = root.get_node("GameState")
	assert(state.active_mode == "plant", "Mobile starts in planting mode")
	state.coins = 200
	for t in state.sector_tiles["1,1"]:
		if t.get("type") == "preparing":
			t["type"] = "grass"
	var initial_coins: int = state.coins
	state.sector_tiles["1,1"][8] = {"type": "grass"}
	farm._on_plot_clicked(8)
	assert(state.coins == initial_coins, "Planting mode protects grass from accidental hoeing")
	assert(state.sector_tiles["1,1"][8]["type"] == "grass", "Grass tile remains grass in planting mode")
	
	farm.mode_tools_btn.pressed.emit()
	assert(state.active_mode == "tools", "Mode tools button switches to tools mode")
	farm._on_plot_clicked(8)
	assert(state.coins < initial_coins, "Tools mode hoes grass and spends coins")
	assert(state.sector_tiles["1,1"][8]["type"] == "preparing", "Grass becomes preparing soil in tools mode")
	
	farm.dock_active_seed_btn.pressed.emit()
	assert(state.active_mode == "plant", "Dock seed button switches to plant mode")
	assert(farm.seed_modal == null or not farm.seed_modal.visible, "First tap swaps mode without opening modal")
	farm.dock_active_seed_btn.pressed.emit()
	assert(farm.seed_modal != null and farm.seed_modal.visible, "Second tap opens seed modal")
	farm._close_farm_menus()
	
	farm.dock_tool_btn.pressed.emit()
	assert(state.active_mode == "tools", "Dock tool button switches to tools mode")
	assert(farm.tool_menu == null or not farm.tool_menu.visible, "First tap swaps mode without opening menu")
	farm.dock_tool_btn.pressed.emit()
	assert(farm.tool_menu != null and farm.tool_menu.visible, "Second tap opens tool menu")
	farm._close_farm_menus()

	for open_modal in [farm._open_seed_modal, farm._open_market_modal, farm._open_barn_modal, farm._open_tool_menu, farm._open_workshop_blueprint_modal]:
		open_modal.call()
		await process_frame
		await process_frame
		var modal = farm.tool_menu if farm.tool_menu.visible else (farm.seed_modal if farm.seed_modal.visible else (farm.market_modal if farm.market_modal.visible else (farm.barn_modal if farm.barn_modal.visible else farm.workshop_blueprint_modal)))
		for child in modal.get_children():
			if child is PanelContainer:
				_assert_fits(child, width)
		if farm.tool_menu.visible:
			_assert_fits(farm.tool_menu.upgrade_button, width)
			assert(farm.tool_menu.upgrade_button.get_global_rect().end.y <= farm.get_viewport_rect().size.y, "Upgrade footer stays visible")
			farm.tool_menu._show_confirmation(false)
			await process_frame
			await process_frame
			_assert_fits(farm.tool_menu.confirmation_action, width)
			assert(farm.tool_menu.confirmation_action.get_global_rect().end.y <= farm.get_viewport_rect().size.y, "Restart confirmation fits screen")
			farm.tool_menu.confirmation.visible = false
		farm._close_farm_menus()
	farm._start_placement_mode("workshop")
	await process_frame
	await process_frame
	_assert_fits(farm.placement_hud_banner, width)
	assert(farm.placement_confirm_btn.size.y >= 48, "Placement confirm touch target height")
	farm._stop_placement_mode()
	print("PASS: mobile HUD, touch targets, mode switcher, and menus fit phone width")
	quit()

