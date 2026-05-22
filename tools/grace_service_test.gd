extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var grace := GraceService.new()
	grace.load_from_registry(registry)

	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 42)
	var before_max_hp: int = run.max_hp

	var vitality := registry.get_grace_option("vitality")
	if vitality == null:
		push_error("vitality grace option missing")
		quit(1)
		return
	grace.apply(vitality, run)
	if run.max_hp != before_max_hp + 8:
		push_error("vitality expected max_hp +8, got %d -> %d" % [before_max_hp, run.max_hp])
		quit(1)
		return

	run.deck = ["a", "b", "c", "d", "e"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _i in range(20):
		var opts := grace.roll_options(run, rng, 3)
		for opt in opts:
			if str((opt as Object).get("id")) == "purge":
				push_error("purge should not appear when deck size is 5")
				quit(1)
				return

	run.souls = 10
	opts = grace.roll_options(run, rng, 3)
	for opt in opts:
		if str((opt as Object).get("id")) == "destined_death":
			push_error("destined_death should not appear when souls < 45")
			quit(1)
			return

	print("Grace service test passed")
	quit()
