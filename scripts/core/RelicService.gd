class_name RelicService
extends RefCounted

const RelicData = preload("res://data/RelicData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")


func has_relic(run: RunState, relic_id: String) -> bool:
	return run.relics.has(relic_id)


func add_relic(run: RunState, registry: DataRegistry, relic_id: String) -> bool:
	if has_relic(run, relic_id):
		return false
	var relic := registry.get_relic(relic_id)
	if relic == null:
		return false
	run.relics.append(relic_id)
	_apply_on_acquire(run, relic)
	return true


func grant_random_relic(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> RelicData:
	var pool: Array = []
	for rid in registry.all_relic_ids():
		if not has_relic(run, str(rid)):
			var relic := registry.get_relic(str(rid))
			if relic != null:
				pool.append(relic)
	if pool.is_empty():
		return null
	var picked: RelicData = pool[rng.randi_range(0, pool.size() - 1)] as RelicData
	add_relic(run, registry, picked.id)
	return picked


func apply_combat_start(run: RunState, registry: DataRegistry, combat: CombatController) -> void:
	for relic_id in run.relics:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic == null:
			continue
		match relic.hook:
			"combat_strength":
				run.player_strength += relic.value
			"combat_extra_ember":
				combat.max_ember += relic.value
				combat.ember += relic.value
			"combat_start_block":
				combat.block += relic.value


func combat_extra_draw(run: RunState, registry: DataRegistry) -> int:
	var total := 0
	for relic_id in run.relics:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic != null and relic.hook == "combat_extra_draw":
			total += relic.value
	return total


func _apply_on_acquire(run: RunState, relic: RelicData) -> void:
	match relic.hook:
		"on_acquire_max_hp":
			run.max_hp += relic.value
			run.hp += relic.value
