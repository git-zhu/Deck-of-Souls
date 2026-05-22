class_name MapGenerator
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapNodeData = preload("res://data/MapNodeData.gd")
const MapEncounterData = preload("res://data/MapEncounterData.gd")


func options_for_floor(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> Array:
	if run.is_act_boss_floor():
		var act := registry.get_act(run.act_index())
		if act == null:
			return []
		return [{
			"kind": "boss",
			"enemy": act.act_boss_name,
			"title": act.act_boss_title,
			"body": act.act_boss_body,
		}]
	var act := registry.get_act(run.act_index())
	if act == null:
		return []
	var pool: Array = []
	for node in act.fixed_nodes:
		pool.append(_node_to_dict(node))
	for enc in act.combat_encounters:
		pool.append(_encounter_to_dict(enc as MapEncounterData, "combat"))
	for enc in act.elite_encounters:
		pool.append(_encounter_to_dict(enc as MapEncounterData, "elite"))
	for event_id in act.event_ids:
		var event := registry.get_event(str(event_id))
		if event != null:
			pool.append({
				"kind": "event",
				"event_id": event.id,
				"title": event.title,
				"body": event.body,
			})
	pool.shuffle()
	return pool.slice(0, 3)


func _node_to_dict(node: MapNodeData) -> Dictionary:
	return {
		"kind": node.kind,
		"title": node.title,
		"body": node.body,
		"enemy": node.enemy_name,
	}


func _encounter_to_dict(enc: MapEncounterData, kind: String) -> Dictionary:
	return {
		"kind": kind,
		"enemy": enc.enemy_name,
		"title": enc.title,
		"body": enc.body,
	}
