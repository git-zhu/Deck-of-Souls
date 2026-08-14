extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const OriginScreenView = preload("res://scripts/ui/OriginScreenView.gd")


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var registry := DataRegistry.new()
	registry.load_all()
	var picked: Array[String] = [""]
	var ui := OriginScreenView.build(registry, func(origin_id: String) -> void: picked[0] = origin_id)
	root.add_child(ui)
	await process_frame
	var buttons := _find_buttons(ui)
	if buttons.size() < 6:
		push_error("Origin screen should have >= 6 pick buttons, got %d" % buttons.size())
		quit(1)
		return
	buttons[0].emit_signal("pressed")
	await process_frame
	if picked[0] == "":
		push_error("Origin pick button did not fire callback")
		quit(1)
		return
	print("origin_screen_test passed (picked %s, %d buttons)" % [picked[0], buttons.size()])
	quit()


func _find_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_buttons(child))
	return out
