extends SceneTree


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Control = scene.instantiate() as Control
	root.add_child(main)
	await process_frame

	if main.get("run_flow") == null:
		_fail("Main missing run_flow")
		return

	main.call("_start_run", "vagabond")
	await process_frame
	if int(main.get("screen")) != 2:
		_fail("expected MAP screen after start_run, got %s" % str(main.get("screen")))
		return

	main.call("_choose_map_option", {"kind": "combat", "enemy": "葛瑞克士兵"})
	await process_frame
	if int(main.get("screen")) != 3:
		_fail("expected COMBAT screen after combat option, got %s" % str(main.get("screen")))
		return

	var combat: Object = main.get("combat")
	if combat == null:
		_fail("combat controller missing")
		return
	var enemy: Dictionary = combat.get("enemy")
	if enemy.is_empty():
		_fail("combat enemy not initialized")
		return

	main.queue_free()
	await process_frame
	print("run_flow_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
