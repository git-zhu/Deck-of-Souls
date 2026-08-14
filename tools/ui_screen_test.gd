extends SceneTree

const DESIGN_W := 1280.0
const DESIGN_H := 720.0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Control = scene.instantiate() as Control
	root.add_child(main)
	await process_frame

	# 1. Title screen
	main.call("_show_title")
	await process_frame
	if not _tree_has_button_text(main, "开始游戏") and not _tree_has_button_text(main, "新游戏"):
		_fail("title screen missing start button")
		return
	if not _tree_has_button_text(main, "退出游戏"):
		_fail("title screen missing quit button")
		return
	if not _check_bounds(main):
		return

	# 2. Origin screen
	main.call("_show_origin")
	await process_frame
	if not _tree_has_button_text(main, "以此出身开始"):
		_fail("origin screen missing pick button")
		return
	if not _check_bounds(main):
		return

	# 3. Map screen
	main.call("_start_run", "vagabond")
	await process_frame
	if int(main.get("screen")) != 2:
		_fail("expected MAP after start_run, got %s" % str(main.get("screen")))
		return
	if not _tree_has_button_text(main, "踏入") and not _tree_has_button_text(main, "介入"):
		_fail("map screen missing option buttons")
		return
	if not _check_bounds(main):
		return

	# 4. Combat screen
	main.call("_choose_map_option", {"kind": "combat", "enemy": "葛瑞克士兵"})
	await process_frame
	if int(main.get("screen")) != 3:
		_fail("expected COMBAT after combat option, got %s" % str(main.get("screen")))
		return
	if not _tree_has_button_text(main, "结束回合"):
		_fail("combat screen missing end turn button")
		return
	var enemy_panel: Control = main.get("enemy_panel") as Control
	if enemy_panel != null and enemy_panel.global_position.x + enemy_panel.size.x > DESIGN_W + 1.0:
		_fail("enemy panel exceeds 1280 viewport width")
		return
	if not _check_bounds(main):
		return

	# 5. Merchant screen
	main.call("_visit_merchant")
	await process_frame
	if int(main.get("screen")) != 4:
		_fail("expected REWARD after visit_merchant, got %s" % str(main.get("screen")))
		return
	if not _tree_has_button_text(main, "离开商店"):
		_fail("merchant screen missing leave button")
		return
	if not _check_bounds(main):
		return

	# 6. Grace screen
	main.call("_visit_grace")
	await process_frame
	if int(main.get("screen")) != 4:
		_fail("expected REWARD after visit_grace, got %s" % str(main.get("screen")))
		return
	if not _check_bounds(main):
		return

	# 7. Event screen
	main.call("_choose_map_option", {"kind": "event", "event_id": "limgrave_beggar"})
	await process_frame
	if int(main.get("screen")) != 4:
		_fail("expected REWARD after event option, got %s" % str(main.get("screen")))
		return
	if not _check_bounds(main):
		return

	# 8. Game over screen
	main.call("_show_game_over")
	await process_frame
	if not _tree_has_button_text(main, "选择出身"):
		_fail("game over screen missing origin pick button")
		return
	if not _check_bounds(main):
		return

	# 9. Victory screen
	main.call("_show_victory")
	await process_frame
	if not _tree_has_button_text(main, "再开一局"):
		_fail("victory screen missing retry button")
		return
	if not _check_bounds(main):
		return

	# Let the defeat/victory audio players finish before freeing the scene
	# (mirrors real playback; avoids ObjectDB leaks of OGG playback objects).
	for _i in 30:
		var any_playing := false
		for child in main.get_children():
			if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
				any_playing = true
				break
		if not any_playing:
			break
		await create_timer(0.1).timeout
	await create_timer(0.15).timeout

	main.queue_free()
	await process_frame
	print("ui_screen_test: OK (9 screens checked)")
	quit()


func _check_bounds(node: Node) -> bool:
	var rect := root.get_visible_rect()
	var max_w := maxf(rect.size.x, DESIGN_W)
	var max_h := maxf(rect.size.y, DESIGN_H)
	var offenders: Array[String] = []
	_collect_offenders(node, offenders, max_w, max_h)
	if not offenders.is_empty():
		_fail("Controls out of bounds: %s" % str(offenders.slice(0, 5)))
		return false
	return true


func _collect_offenders(node: Node, out: Array[String], max_w: float, max_h: float) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.size.x > 0.0 and c.size.y > 0.0:
			var g := c.global_position
			if g.x < -2.0 or g.y < -2.0 or g.x + c.size.x > max_w + 2.0 or g.y + c.size.y > max_h + 2.0:
				out.append("%s @(%d,%d) %dx%d" % [c.name, int(g.x), int(g.y), int(c.size.x), int(c.size.y)])
	for child in node.get_children():
		_collect_offenders(child, out, max_w, max_h)


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
