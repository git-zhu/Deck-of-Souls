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
	# 难度行（周目/誓约/誓言挑战）使用 OptionButton，排除后剩下的才是出身选择按钮
	var pick_buttons: Array[Button] = []
	for b in buttons:
		if not (b is OptionButton):
			pick_buttons.append(b)
	if pick_buttons.size() < 6:
		push_error("Origin screen should have >= 6 pick buttons, got %d" % pick_buttons.size())
		quit(1)
		return
	pick_buttons[0].emit_signal("pressed")
	await process_frame
	if picked[0] == "":
		push_error("Origin pick button did not fire callback")
		quit(1)
		return
	# 出生卡统一琥珀金边框（替代暗金 9-slice）
	var card := _first_panel_container(ui)
	if card != null:
		var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null or sb.border_color != Color("#c9a227"):
			push_error("origin card border should be amber #c9a227")
			quit(1)
			return
		if sb.bg_color != Color("#242018"):
			push_error("origin card bg should stay dark panel color")
			quit(1)
			return
	print("origin_screen_test passed (picked %s, %d buttons)" % [picked[0], buttons.size()])
	quit()


func _first_panel_container(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node
	for child in node.get_children():
		var found := _first_panel_container(child)
		if found != null:
			return found
	return null


func _find_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_buttons(child))
	return out
