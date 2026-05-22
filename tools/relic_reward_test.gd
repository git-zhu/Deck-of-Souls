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

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var offers: Array = relics.roll_relic_offers(run, registry, rng, 3)
	if offers.size() < 1 or offers.size() > 3:
		push_error("expected 1-3 offers on fresh run, got %d" % offers.size())
		quit(1)
		return

	var seen: Dictionary = {}
	for rid in offers:
		var id := str(rid)
		if seen.has(id):
			push_error("duplicate offer id %s" % id)
			quit(1)
			return
		seen[id] = true
		if run.relics.has(id):
			push_error("offered owned relic %s" % id)
			quit(1)
			return

	for rid in registry.all_relic_ids():
		relics.add_relic(run, registry, str(rid))

	offers = relics.roll_relic_offers(run, registry, rng, 3)
	if not offers.is_empty():
		push_error("expected empty pool when all relics owned")
		quit(1)
		return

	run.relics.clear()
	relics.add_relic(run, registry, "serpentbone_talisman")
	offers = relics.roll_relic_offers(run, registry, rng, 3)
	for rid in offers:
		if str(rid) == "serpentbone_talisman":
			push_error("owned relic should not be offered")
			quit(1)
			return

	print("Relic reward test passed")
	quit()
