class_name RelicService
extends RefCounted

const RelicData = preload("res://data/RelicData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")


func has_relic(run: RunState, relic_id: String) -> bool:
	return run.relics.has(relic_id)


# M7：数值一律回数据读取（未持有返回 0）
func relic_value(run: RunState, registry: DataRegistry, relic_id: String) -> int:
	if not has_relic(run, relic_id):
		return 0
	var relic := registry.get_relic(relic_id) as RelicData
	return relic.value if relic != null else 0


func relic_value2(run: RunState, registry: DataRegistry, relic_id: String) -> int:
	if not has_relic(run, relic_id):
		return 0
	var relic := registry.get_relic(relic_id) as RelicData
	return relic.value2 if relic != null else 0


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
		"combat_souls_bonus":
			return "战斗胜利：额外 +%d 卢恩" % relic.value
		"bleed_threshold_5":
			return "出血 %d 层即触发（原 10）" % relic.value
		"draw_on_magic":
			return "法术卡打出后抽 %d 张" % relic.value
		"stance_up_block_down":
			return "姿态削减 +%d%%，护甲获得 −2" % relic.value
		"souls_double_chance":
			return "拾取卢恩时 %d%% 概率翻倍" % relic.value
		"exec_bonus":
			return "处决伤害 +%d%%" % relic.value
		"ember_and_rot":
			return "能量上限 +%d，每回合积累 %d 腐败" % [relic.value, relic.value2]
		"rune_all_attrs":
			return "获得时：全属性 +%d" % relic.value
		"stance_percent":
			return "姿态削减 +%d%%" % relic.value
		_:
			return relic.hook


func _unowned_relic_pool(run: RunState, registry: DataRegistry) -> Array:
	var pool: Array = []
	for rid in registry.all_relic_ids():
		if has_relic(run, str(rid)):
			continue
		var relic := registry.get_relic(str(rid)) as RelicData
		# I4/I9：专属护符（大卢恩/铃珠）不进常规抽取池
		if relic != null and not relic.exclusive:
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
			"ember_and_rot":
				combat.max_ember += relic.value
				combat.ember += relic.value


func combat_souls_bonus(run: RunState, registry: DataRegistry) -> int:
	var total := 0
	for relic_id in run.relics:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic != null and relic.hook == "combat_souls_bonus":
			total += relic.value
	return total


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
		"rune_all_attrs":
			# I4 玛尔基特大卢恩·恶兆之力：全属性 +value（生命同步补 2 HP/点，与加点规则一致）
			for key in run.attrs.keys():
				run.attrs[key] = int(run.attrs[key]) + relic.value
			run.max_hp += relic.value * 2
			run.hp += relic.value * 2


# I4/M7：姿态类护符的总百分比（双手剑徽章 stance_up_block_down + 大卢恩 stance_percent）
func stance_percent_total(run: RunState, registry: DataRegistry) -> int:
	var total := 0
	for relic_id in run.relics:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic != null and str(relic.hook) in ["stance_up_block_down", "stance_percent"]:
			total += relic.value
	return total
