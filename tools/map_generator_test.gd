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
