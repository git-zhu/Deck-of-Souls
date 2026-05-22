extends SceneTree

const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Control = scene.instantiate() as Control
	root.add_child(main)
	await process_frame

	main.call("_start_run", "vagabond")
	await process_frame

	main.call("_build_header")
	await process_frame

	if not _tree_has_menu_button(main.get("header") as Node):
		_fail("header missing ☰ menu button")
		return

	main.call("_show_pause_menu")
	await process_frame

	var overlay: Node = main.get("pause_overlay")
	if overlay == null:
		_fail("pause overlay not created")
		return
	if not _tree_has_button_text(overlay, "继续游戏"):
		_fail("pause menu missing 继续游戏")
		return
	if not _tree_has_button_text(overlay, "返回标题"):
		_fail("pause menu missing 返回标题")
		return
	if not _tree_has_button_text(overlay, "放弃本局"):
		_fail("pause menu missing 放弃本局")
		return

	main.call("_hide_pause_menu")
	await process_frame
	if main.get("pause_overlay") != null:
		_fail("pause overlay not cleared")
		return

	main.queue_free()
	await process_frame
	print("pause_menu_test: OK")
	quit()


func _tree_has_menu_button(node: Node) -> bool:
	if node == null:
		return false
	if node is Button:
		var btn := node as Button
		if btn.text == "☰" or btn.tooltip_text == "选项":
			return true
	for child in node.get_children():
		if _tree_has_menu_button(child):
			return true
	return false


func _tree_has_button_text(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text:
		return true
	for child in node.get_children():
		if _tree_has_button_text(child, text):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
