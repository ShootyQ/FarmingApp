extends SceneTree

func _initialize():
	call_deferred("_run")

func _touch(farm, index: int, position: Vector2, pressed: bool):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	if pressed:
		farm._unhandled_input(event)
	else:
		farm._input(event)

func _drag(farm, index: int, position: Vector2):
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	farm._input(event)

func _run():
	var farm = load("res://scenes/main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	var center = farm.get_viewport_rect().size * 0.5
	farm._zoom_at(100.0, center)
	assert(farm.camera.zoom == Vector2(3.0, 3.0), "Zoom-in limit")
	farm._zoom_at(0.01, center)
	assert(farm.camera.zoom == Vector2(0.6, 0.6), "Zoom-out limit")
	farm._zoom_at(1.0, center)
	_touch(farm, 0, center - Vector2(100, 0), true)
	_touch(farm, 1, center + Vector2(100, 0), true)
	_drag(farm, 1, center + Vector2(200, 0))
	assert(is_equal_approx(farm.camera.zoom.x, 1.5), "Spreading fingers zooms in")
	_drag(farm, 1, center + Vector2(50, 0))
	assert(is_equal_approx(farm.camera.zoom.x, 0.75), "Pinching fingers zooms out")
	_touch(farm, 1, center + Vector2(50, 0), false)
	assert(farm.touch_was_multitouch, "Remaining finger cannot become a tap")
	_touch(farm, 0, center - Vector2(100, 0), false)
	assert(farm.touch_points.is_empty(), "All fingers released")
	assert(not farm.touch_was_multitouch, "Next tap starts fresh")
	var before: Vector2 = farm.camera.position
	_touch(farm, 0, center, true)
	_drag(farm, 0, center + Vector2(80, 0))
	assert(farm.camera.position.x < before.x, "One finger pans the farm")
	assert(farm.touch_moved, "Dragging cannot plant or harvest")
	_touch(farm, 0, center + Vector2(80, 0), false)
	farm.zoom_reset_btn.pressed.emit()
	assert(farm.camera.position == Vector2.ZERO, "Reset recenters")
	assert(farm.camera.zoom == Vector2.ONE, "Reset restores zoom")
	farm.map_modal.visible = true
	_touch(farm, 0, center, true)
	assert(farm.touch_points.is_empty(), "Modal blocks farm gestures")
	print("PASS: camera limits, pinch, pan, tap suppression, reset, modal blocking")
	quit()
