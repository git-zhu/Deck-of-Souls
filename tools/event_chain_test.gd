extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()

	var chains: Array[Dictionary] = [
		{"entry": "limgrave_corpse", "choice": "loot", "follow": "limgrave_corpse_cache"},
		{"entry": "stormveil_armory", "choice": "take_axe", "follow": "stormveil_armory_inner"},
		{"entry": "liurnia_scholar", "choice": "copy", "follow": "liurnia_scholar_reward"},
	]

	for spec in chains:
		var entry_id: String = spec["entry"]
		var choice_id: String = spec["choice"]
		var follow_id: String = spec["follow"]
		var event := registry.get_event(entry_id)
		if event == null:
			_fail("missing entry event %s" % entry_id)
			return
		var choice: MapEventChoiceData = _find_choice(event.choices, choice_id)
		if choice == null:
			_fail("missing choice %s on %s" % [choice_id, entry_id])
			return
		if str(choice.follow_event_id).strip_edges() != follow_id:
			_fail(
				"%s.%s follow_event_id expected %s got %s"
				% [entry_id, choice_id, follow_id, choice.follow_event_id]
			)
			return
		var next := registry.get_event(follow_id)
		if next == null:
			_fail("missing follow event %s" % follow_id)
			return
		for ch in next.choices:
			if str(ch.follow_event_id).strip_edges() != "":
				_fail("follow screen %s must not chain again (%s)" % [follow_id, ch.id])
				return

	for act_index in range(3):
		var act := registry.get_act(act_index)
		if act == null:
			continue
		for follow_only in ["limgrave_corpse_cache", "stormveil_armory_inner", "liurnia_scholar_reward"]:
			if follow_only in act.event_ids:
				_fail("follow event %s must not be in map pool" % follow_only)
				return

	print("event_chain_test: OK")
	quit()


func _find_choice(choices: Array, choice_id: String) -> MapEventChoiceData:
	for ch in choices:
		if ch is MapEventChoiceData and ch.id == choice_id:
			return ch
	return null


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
