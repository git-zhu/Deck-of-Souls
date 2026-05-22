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


func roll_relic_offers(
	run: RunState,
	registry: DataRegistry,
	rng: RandomNumberGenerator,
	count: int = 3
) -> Array:
	var pool := _unowned_relic_pool(run, registry)
	pool.shuffle()
	var offers: Array = []
	for i in mini(count, pool.size()):
		offers.append((pool[i] as RelicData).id)
	return offers


func grant_random_relic(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> RelicData:
	var offers := roll_relic_offers(run, registry, rng, 1)
	if offers.is_empty():
		return null
	var relic_id: String = str(offers[0])
	add_relic(run, registry, relic_id)
	return registry.get_relic(relic_id) as RelicData


func hook_summary(relic: RelicData) -> String:
	match relic.hook:
		"combat_strength":
			return "战斗开始：力量 +%d" % relic.value
		"on_acquire_max_hp":
			return "获得时：最大生命 +%d" % relic.value
		"combat_extra_ember":
			return "战斗开始：集中 +%d" % relic.value
		"combat_extra_draw":
			return "每回合多抽 %d 张" % relic.value
		"combat_start_block":
			return "战斗开始：护甲 +%d" % relic.value
		_:
			return relic.hook


func _unowned_relic_pool(run: RunState, registry: DataRegistry) -> Array:
	var pool: Array = []
	for rid in registry.all_relic_ids():
		if has_relic(run, str(rid)):
			continue
		var relic := registry.get_relic(str(rid)) as RelicData
		if relic != null:
			pool.append(relic)
	return pool


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
