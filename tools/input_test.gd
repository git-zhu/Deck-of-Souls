extends SceneTree

# 验证 PC 快捷键：数字键打牌 / F 圣杯瓶 / 空格结束回合 / D 牌组 / Esc 暂停。
# 通过直接构造 InputEventKey 并调用 Main._unhandled_input 驱动。

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Control = scene.instantiate() as Control
	root.add_child(main)
	await process_frame

	# 进入战斗
	main.call("_start_run", "vagabond")
	await process_frame
	main.call("_choose_map_option", {"kind": "combat", "enemy": "葛瑞克士兵"})
	await process_frame
	if int(main.get("screen")) != 3:
		_fail("expected COMBAT screen")
		return

	var combat: Object = main.get("combat")
	var hand_size_before: int = (main.get("run_state").hand as Array).size()
	if hand_size_before == 0:
		_fail("hand empty at combat start")
		return

	# 1) 数字键 1 打出第 1 张手牌
	var key1 := InputEventKey.new()
	key1.keycode = KEY_1
	key1.physical_keycode = KEY_1
	key1.pressed = true
	main.call("_unhandled_input", key1)
	await process_frame
	if int(combat.get("combat_over")):
		_fail("combat should not be over after one card")
		return

	# 2) F 圣杯瓶（确保低血可触发；直接设低 HP）
	main.get("run_state").set("hp", 5)
	var flasks_before: int = main.get("run_state").flasks
	var key_f := InputEventKey.new()
	key_f.keycode = KEY_F
	key_f.physical_keycode = KEY_F
	key_f.pressed = true
	main.call("_unhandled_input", key_f)
	await process_frame
	if int(main.get("run_state").flasks) != flasks_before - 1:
		_fail("F key did not use flask")
		return

	# 3) 空格结束回合
	var key_space := InputEventKey.new()
	key_space.keycode = KEY_SPACE
	key_space.physical_keycode = KEY_SPACE
	key_space.pressed = true
	main.call("_unhandled_input", key_space)
	await process_frame

	# 4) D 查看牌组（弹出 AcceptDialog）
	var key_d := InputEventKey.new()
	key_d.keycode = KEY_D
	key_d.physical_keycode = KEY_D
	key_d.pressed = true
	main.call("_unhandled_input", key_d)
	await process_frame

	# 5) Esc 暂停菜单
	var key_esc := InputEventKey.new()
	key_esc.keycode = KEY_ESCAPE
	key_esc.physical_keycode = KEY_ESCAPE
	key_esc.pressed = true
	main.call("_unhandled_input", key_esc)
	await process_frame
	if main.get("pause_overlay") == null:
		_fail("Esc did not open pause menu")
		return
	# 再按 Esc 关闭
	main.call("_unhandled_input", key_esc)
	await process_frame
	if main.get("pause_overlay") != null:
		_fail("Esc did not close pause menu")
		return

	main.queue_free()
	await process_frame
	print("input_test: OK (keyboard shortcuts verified)")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
