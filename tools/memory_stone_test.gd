extends SceneTree

const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var grace := GraceService.new()
	grace.load_from_registry(registry)
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)

	if run.player_hand_draw() != 5:
		push_error("expected base draw 5, got %d" % run.player_hand_draw())
		quit(1)
		return

	var opt := registry.get_grace_option("memory_stone")
	grace.apply(opt, run)
	if run.memory_stones != 1 or run.player_hand_draw() != 6:
		push_error("after 1 stone expected draw 6, got stones=%d draw=%d" % [
			run.memory_stones,
			run.player_hand_draw(),
		])
		quit(1)
		return

	run.memory_stones = 3
	if run.can_gain_memory_stone():
		push_error("can_gain should be false at 3 stones")
		quit(1)
		return
	if grace.is_eligible(opt, run):
		push_error("memory_stone grace should be ineligible at cap")
		quit(1)
		return

	print("Memory stone test passed")
	quit()
