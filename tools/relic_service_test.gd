extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var relics := RelicService.new()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)
	var before_max: int = run.max_hp

	if not relics.add_relic(run, registry, "crimson_amulet"):
		push_error("failed to add crimson_amulet")
		quit(1)
		return
	if run.max_hp != before_max + 10:
		push_error("on_acquire_max_hp expected +10, got %d" % run.max_hp)
		quit(1)
		return
	if not relics.add_relic(run, registry, "crimson_amulet"):
		push_error("duplicate add should fail")
		quit(1)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var granted := relics.grant_random_relic(run, registry, rng)
	if granted == null:
		push_error("grant_random_relic returned null")
		quit(1)
		return
	if run.relics.size() != 2:
		push_error("expected 2 relics, got %d" % run.relics.size())
		quit(1)
		return

	print("Relic service test passed")
	quit()
