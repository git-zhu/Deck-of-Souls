extends SceneTree

const RunSaveService = preload("res://scripts/core/RunSaveService.gd")


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Control = scene.instantiate() as Control
	root.add_child(main)
	await process_frame

	main.call("_start_run", "vagabond")
	await process_frame
	if not RunSaveService.save_snapshot(main):
		_fail("save_snapshot failed on MAP")
		return

	main.queue_free()
	await process_frame

	var main2: Control = scene.instantiate() as Control
	root.add_child(main2)
	await process_frame

	if not RunSaveService.load_snapshot(main2):
		_fail("load_snapshot failed")
		return
	await process_frame

	if int(main2.get("screen")) != 2:
		_fail("expected MAP after load, got %s" % str(main2.get("screen")))
		return

	var floor_index: int = main2.get("run_state").floor_index
	if floor_index != 0:
		_fail("expected floor 0 after load, got %d" % floor_index)
		return

	RunSaveService.delete_save()
	main2.queue_free()
	await process_frame
	print("save_load_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
