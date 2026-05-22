extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const RunState = preload("res://scripts/core/RunState.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var gen := MapGenerator.new()
	var run := RunState.new()
	var rng := RandomNumberGenerator.new()
	run.floor_index = 0
	var normal_opts := gen.options_for_floor(run, registry, rng)
	if normal_opts.size() != 3:
		push_error("floor 0 expected 3 options, got %d" % normal_opts.size())
		quit(1)
		return
	for opt in normal_opts:
		if not opt.has("title") or str(opt.get("title", "")).is_empty():
			push_error("map option missing title")
			quit(1)
			return

	for floor in [3, 7, 11]:
		run.floor_index = floor
		var opts := gen.options_for_floor(run, registry, rng)
		if opts.size() != 1:
			push_error("floor %d expected 1 boss option, got %d" % [floor, opts.size()])
			quit(1)
			return
		if str(opts[0].get("kind")) != "boss":
			push_error("floor %d not boss kind" % floor)
			quit(1)
			return
	print("Map generator test passed")
	quit()
