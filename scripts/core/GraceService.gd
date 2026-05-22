class_name GraceService
extends RefCounted

const GraceOptionData = preload("res://data/GraceOptionData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")

const PICK_CARD := "__pick_card__"
const MAX_FLASKS := 5

var _options: Array = []


func load_from_registry(registry: DataRegistry) -> void:
	_options.clear()
	for opt_id in registry.all_grace_option_ids():
		var opt := registry.get_grace_option(str(opt_id)) as GraceOptionData
		if opt != null:
			_options.append(opt)


func is_eligible(option: GraceOptionData, run: RunState) -> bool:
	match option.effect:
		"remove_card":
			return run.deck.size() > 5
		"add_card":
			if option.card_id.is_empty():
				return false
			return run.souls >= option.soul_cost and not run.deck.has(option.card_id)
		"max_flasks":
			return run.max_flasks < MAX_FLASKS
		_:
			return true


func roll_options(run: RunState, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = []
	for opt in _options:
		if is_eligible(opt as GraceOptionData, run):
			pool.append(opt)
	pool.shuffle()
	var picked: Array = pool.slice(0, mini(count, pool.size()))

	var has_heal := false
	for opt in picked:
		if str((opt as GraceOptionData).effect) == "heal_percent":
			has_heal = true
			break
	if not has_heal:
		var rest_opt: GraceOptionData = _find_by_id("rest")
		if rest_opt != null and is_eligible(rest_opt, run):
			if picked.is_empty():
				picked.append(rest_opt)
			else:
				picked[picked.size() - 1] = rest_opt

	return picked


func apply(option: GraceOptionData, run: RunState) -> String:
	match option.effect:
		"heal_percent":
			var heal: int = int(ceil(float(run.max_hp) * float(option.effect_value) / 100.0))
			run.hp = mini(run.max_hp, run.hp + heal)
			run.flasks = run.max_flasks
			return "你回复 %d 生命，圣杯瓶已补满。" % heal
		"max_hp":
			run.max_hp += option.effect_value
			run.hp += option.effect_value
			return "最大生命提升 %d，当前 %d/%d。" % [option.effect_value, run.hp, run.max_hp]
		"max_flasks":
			run.max_flasks = mini(MAX_FLASKS, run.max_flasks + option.effect_value)
			run.flasks = run.max_flasks
			return "圣杯瓶上限现为 %d。" % run.max_flasks
		"remove_card":
			return PICK_CARD
		"clear_debuffs":
			run.player_rot = 0
			run.player_bleed = 0
			run.player_vulnerable = 0
			return "腐败、出血与易伤已净化。"
		"add_card":
			run.souls -= option.soul_cost
			run.deck.append(option.card_id)
			return "消耗 %d 卢恩，《命定之死》已加入牌组。" % option.soul_cost
		_:
			return "赐福回响，却无事发生。"


func _find_by_id(option_id: String) -> GraceOptionData:
	for opt in _options:
		var g := opt as GraceOptionData
		if g != null and g.id == option_id:
			return g
	return null
