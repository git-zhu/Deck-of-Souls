class_name MapGenerator
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const ActData = preload("res://data/ActData.gd")
const MapNodeData = preload("res://data/MapNodeData.gd")
const MapEncounterData = preload("res://data/MapEncounterData.gd")
const MapEventData = preload("res://data/MapEventData.gd")


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
	var weighted: Array = []
	for node in act.fixed_nodes:
		var w: int = _weight_for_kind(act, str(node.kind))
		if w > 0:
			weighted.append({"option": _node_to_dict(node), "weight": w})
	for enc in act.combat_encounters:
		var cw: int = act.map_weight_combat
		if cw > 0:
			weighted.append({
				"option": _encounter_to_dict(enc as MapEncounterData, "combat"),
				"weight": cw,
			})
	# 群怪遭遇（法环群怪设计）：按幕主题混入普通战池
	var group_ids := _act_group_pool(act, registry)
	for gid in group_ids:
		weighted.append({
			"option": {
				"kind": "combat",
				"enemy": gid,
				"title": str(registry.get_group(gid).title),
				"body": str(registry.get_group(gid).body),
			},
			"weight": 2,
		})
	for enc in act.elite_encounters:
		var ew: int = act.map_weight_elite
		if ew > 0:
			weighted.append({
				"option": _encounter_to_dict(enc as MapEncounterData, "elite"),
				"weight": ew,
			})
	# 精英群怪：强力群组作为精英遭遇（获胜走 elite_reward 护符奖励）
	var elite_group_ids := _act_elite_group_pool(act, registry)
	for gid in elite_group_ids:
		var g := registry.get_group(gid)
		if g == null:
			continue
		weighted.append({
			"option": {
				"kind": "elite",
				"enemy": gid,
				"title": "精英 · " + str(g.title),
				"body": str(g.body),
			},
			"weight": 1,
		})
	for event_id in act.event_ids:
		var event: MapEventData = registry.get_event(str(event_id)) as MapEventData
		var event_w: int = act.map_weight_event
		if event != null and event_w > 0:
			weighted.append({
				"option": {
					"kind": "event",
					"event_id": event.id,
					"title": event.title,
					"body": event.body,
				},
				"weight": event_w,
			})
	return _pick_weighted(weighted, 3, rng)


func _act_elite_group_pool(act: ActData, registry: DataRegistry) -> Array:
	# 精英群怪：每幕 2-3 组强力组合
	var act_idx := 0
	for i in range(3):
		var a := registry.get_act(i)
		if a != null and a.id == act.id:
			act_idx = i
			break
	match act_idx:
		0:
			return ["kaguth_raiders", "elite_soldier_swarm"]
		1:
			return ["gargoyle_watch", "gravekeeper_party", "rot_incursion"]
		_:
			return ["rot_incursion", "elite_soldier_swarm"]
	return []


func _act_group_pool(act: ActData, registry: DataRegistry) -> Array:
	# 按幕主题挑选群怪（法环：宁姆格福=士兵/野狼，史东薇尔=骑士/法师，利耶尼亚=腐败/学者）
	var act_idx := 0
	for i in range(3):
		var a := registry.get_act(i)
		if a != null and a.id == act.id:
			act_idx = i
			break
	match act_idx:
		0:
			return ["soldier_patrol", "wolf_pack", "kaguth_raiders", "mercenary_duo"]
		1:
			return ["gargoyle_watch", "gravekeeper_party", "academy_scholars", "elite_soldier_swarm"]
		_:
			return ["kindred_of_rot_pair", "rot_incursion", "academy_scholars"]
	return []


func _weight_for_kind(act: ActData, kind: String) -> int:
	match kind:
		"grace":
			return act.map_weight_grace
		"merchant":
			return act.map_weight_merchant
		_:
			return 1


func _pick_weighted(entries: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = entries.duplicate()
	var picked: Array = []
	var picks: int = mini(count, pool.size())
	for _i in range(picks):
		var total: int = 0
		for entry: Dictionary in pool:
			total += int(entry.get("weight", 0))
		if total <= 0:
			break
		var roll: int = rng.randi_range(0, total - 1)
		var acc: int = 0
		var chosen_index: int = 0
		for j in range(pool.size()):
			acc += int((pool[j] as Dictionary).get("weight", 0))
			if roll < acc:
				chosen_index = j
				break
		var chosen: Dictionary = pool[chosen_index] as Dictionary
		picked.append(chosen.get("option", {}))
		pool.remove_at(chosen_index)
	return picked


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
