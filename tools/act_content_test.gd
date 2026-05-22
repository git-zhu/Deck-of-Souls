extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const MapEncounterData = preload("res://data/MapEncounterData.gd")
const OriginData = preload("res://data/OriginData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var gen := MapGenerator.new()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for act_index in range(RunState.ACT_COUNT):
		var act := registry.get_act(act_index)
		if act == null:
			push_error("missing act %d" % act_index)
			quit(1)
			return
		if act.reward_cards.is_empty():
			push_error("act %s has empty reward_cards" % act.id)
			quit(1)
			return
		if act.combat_encounters.is_empty():
			push_error("act %s has empty combat_encounters" % act.id)
			quit(1)
			return
		if act.event_ids.size() < 2:
			push_error("act %s expected >= 2 event_ids" % act.id)
			quit(1)
			return
		for event_id in act.event_ids:
			if registry.get_event(str(event_id)) == null:
				push_error("unknown event %s on act %s" % [event_id, act.id])
				quit(1)
				return

		for enc in act.combat_encounters:
			var encounter := enc as MapEncounterData
			if encounter == null or encounter.enemy_name.is_empty():
				push_error("invalid combat encounter on act %s" % act.id)
				quit(1)
				return
			if registry.template_by_name(encounter.enemy_name).is_empty():
				push_error("unknown enemy %s on act %s" % [encounter.enemy_name, act.id])
				quit(1)
				return

		run.floor_index = act_index * RunState.FLOORS_PER_ACT
		var opts := gen.options_for_floor(run, registry, rng)
		if opts.size() != 3:
			push_error("act %s floor 0 expected 3 options, got %d" % [act.id, opts.size()])
			quit(1)
			return

	var combat := CombatController.new(run, registry, rng)
	var limgrave := registry.get_act(0)
	var rewards := combat.roll_rewards(limgrave)
	if rewards.is_empty():
		push_error("limgrave roll_rewards empty")
		quit(1)
		return
	for card_id in rewards:
		if not limgrave.reward_cards.has(card_id):
			push_error("reward %s not in limgrave pool" % card_id)
			quit(1)
			return

	var liurnia := registry.get_act(2)
	if liurnia.fixed_nodes.size() < 3:
		push_error("liurnia expected grace+merchant fixed nodes")
		quit(1)
		return
	var has_merchant := false
	for node in liurnia.fixed_nodes:
		if str(node.kind) == "merchant":
			has_merchant = true
	if not has_merchant:
		push_error("liurnia missing merchant node")
		quit(1)
		return

	print("Act content test passed")
	quit()
