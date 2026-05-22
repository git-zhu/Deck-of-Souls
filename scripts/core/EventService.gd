class_name EventService
extends RefCounted

const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")

const PICK_CARD := "__event_pick_card__"


func is_choice_eligible(
	choice: MapEventChoiceData,
	run: RunState,
	registry: DataRegistry
) -> bool:
	if run.souls < choice.soul_cost:
		return false
	match choice.effect:
		"heal_percent":
			return run.hp < run.max_hp
		"damage_percent":
			var damage: int = int(ceil(float(run.max_hp) * float(choice.effect_value) / 100.0))
			return run.hp > damage
		"lose_souls":
			return run.souls >= choice.soul_cost + choice.effect_value
		"add_card":
			if choice.card_id.is_empty():
				return false
			return registry.get_card(choice.card_id) != null
		"remove_card":
			var min_size: int = choice.min_deck_size if choice.min_deck_size > 0 else 6
			return run.deck.size() > min_size
		"refill_flasks":
			return run.flasks < run.max_flasks
		"gain_souls", "max_hp", "nothing":
			return true
		_:
			return false


func apply(
	choice: MapEventChoiceData,
	run: RunState,
	registry: DataRegistry,
	_rng: RandomNumberGenerator
) -> String:
	if run.souls < choice.soul_cost:
		return "卢恩不足，无法做出这一选择。"
	run.souls -= choice.soul_cost

	match choice.effect:
		"heal_percent":
			var heal: int = int(ceil(float(run.max_hp) * float(choice.effect_value) / 100.0))
			run.hp = mini(run.max_hp, run.hp + heal)
			return "你回复 %d 生命。" % heal
		"damage_percent":
			var damage: int = int(ceil(float(run.max_hp) * float(choice.effect_value) / 100.0))
			run.hp = maxi(1, run.hp - damage)
			return "你失去 %d 生命。" % damage
		"gain_souls":
			run.souls += choice.effect_value
			return "你获得 %d 卢恩。" % choice.effect_value
		"lose_souls":
			run.souls -= choice.effect_value
			return "你失去 %d 卢恩。" % choice.effect_value
		"max_hp":
			run.max_hp += choice.effect_value
			run.hp += choice.effect_value
			return "最大生命提升 %d，当前 %d/%d。" % [choice.effect_value, run.hp, run.max_hp]
		"add_card":
			run.deck.append(choice.card_id)
			var card := registry.get_card(choice.card_id)
			var card_name := card.name if card != null else choice.card_id
			return "《%s》加入了你的牌组。" % card_name
		"remove_card":
			return PICK_CARD
		"refill_flasks":
			run.flasks = run.max_flasks
			return "圣杯瓶已灌满。"
		"nothing":
			return "你未作改变，悄然离开。"
		_:
			return "事件结束了，却似乎什么也没发生。"
