extends SceneTree

const TitleScreenView = preload("res://scripts/ui/TitleScreenView.gd")
const EndScreenView = preload("res://scripts/ui/EndScreenView.gd")
const OriginScreenView = preload("res://scripts/ui/OriginScreenView.gd")
const MapScreenView = preload("res://scripts/ui/MapScreenView.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")


func _initialize() -> void:
	var title := TitleScreenView.build(false, Callable(), Callable(), Callable())
	if not _tree_has_button_text(title, "开始游戏"):
		_fail("title screen missing start button")
		return
	if not _tree_has_button_text(title, "继续游戏"):
		_fail("title screen missing continue button")
		return
	if not _tree_has_button_text(title, "退出游戏"):
		_fail("title screen missing quit button")
		return
	title.queue_free()

	var game_over := EndScreenView.build_game_over(func(): pass)
	if not _tree_has_button_text(game_over, "重新开始"):
		_fail("game over screen missing retry button")
		return
	game_over.queue_free()

	var victory := EndScreenView.build_victory(99, 12, func(): pass)
	if not _tree_has_button_text(victory, "再开一局"):
		_fail("victory screen missing retry button")
		return
	victory.queue_free()

	var registry := DataRegistry.new()
	registry.load_all()
	var origin_root := OriginScreenView.build(registry, func(_id: String): pass)
	if not _tree_has_button_text(origin_root, "以此出身开始"):
		_fail("origin screen missing pick button")
		return
	origin_root.queue_free()

	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, 1)
	var act := registry.get_act(0)
	var map_root := MapScreenView.build(act, run_state, [], func(_opt: Dictionary): pass)
	if map_root.get_child_count() < 2:
		_fail("map screen missing title/description")
		return
	map_root.queue_free()

	var header := HBoxContainer.new()
	var header_refs := RunHeaderView.build(
		header, run_state, registry, Callable(), Callable()
	)
	if header_refs.get("menu") == null:
		_fail("run header missing menu button")
		return
	var menu_btn: Button = header_refs["menu"] as Button
	if menu_btn.text != "☰":
		_fail("run header menu button should be ☰")
		return
	header.queue_free()

	print("flow_screen_test: OK")
	quit()


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
