extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var events := EventService.new()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)
	var rng := RandomNumberGenerator.new()

	var event := registry.get_event("limgrave_corpse")
	if event == null or event.choices.is_empty():
		push_error("limgrave_corpse missing")
		quit(1)
		return

	var loot = event.choices[0]
	if not events.is_choice_eligible(loot, run, registry):
		push_error("loot should be eligible")
		quit(1)
		return

	var before_souls: int = run.souls
	var summary := events.apply(loot, run, registry, rng)
	if run.souls != before_souls + 25:
		push_error("gain_souls expected +25, got %d -> %d" % [before_souls, run.souls])
		quit(1)
		return
	if summary.is_empty():
		push_error("apply returned empty summary")
		quit(1)
		return

	run.souls = 5
	var beggar := registry.get_event("limgrave_beggar")
	var alms = beggar.choices[0]
	if events.is_choice_eligible(alms, run, registry):
		push_error("alms should be disabled when souls < 20")
		quit(1)
		return

	run.deck = ["a", "b", "c", "d", "e"]
	for ch in event.choices:
		if str(ch.effect) == "remove_card":
			if events.is_choice_eligible(ch, run, registry):
				push_error("remove_card should not be eligible at deck size 5")
				quit(1)
				return

	print("Event service test passed")
	quit()
