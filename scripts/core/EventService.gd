class_name EventService
extends RefCounted

const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardData = preload("res://data/CardData.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")

const PICK_CARD := "__event_pick_card__"
const DUEL_JAR := "__duel_jar__"  # I7：壶哥切磋 → RunFlowController 路由进战斗

const FRENZY_CARDS := ["frenzy_flame", "three_fingers", "frenzied_burst", "lord_of_frenzy"]


func _echo_available() -> bool:
	var profile := ProfileService.load_profile()
	var echo_var: Variant = profile.get("echo", {})
	if typeof(echo_var) != TYPE_DICTIONARY:
		return false
	return int((echo_var as Dictionary).get("souls", 0)) > 0


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
		"claim_echo", "offer_echo":
			return _echo_available()
		"gamble_card":
			return run.max_hp > 10
		"curse_card":
			return (
				not choice.card_id.is_empty()
				and registry.get_card(choice.card_id) != null
				and run.max_flasks > 1
			)
		"gain_souls", "max_hp", "nothing", "gamble_souls":
			return true
		"sacrifice_flask":
			return run.max_flasks > 1 and run.kindling == ""
		"sacrifice_weapon":
			return not run.weapons.is_empty() and run.kindling == ""
		"refuse_kindling":
			return run.kindling == ""
		"frenzied_flame":
			return not run.frenzied_flame
		"duel_jar":
			return true
		_:
			return false


func apply(
	choice: MapEventChoiceData,
	run: RunState,
	registry: DataRegistry,
	rng: RandomNumberGenerator
) -> String:
	if run.souls < choice.soul_cost:
		return "卢恩不足，无法做出这一选择。"
	run.souls -= choice.soul_cost
	# I7 事件链旗标：选择可以解锁后续事件（壶哥任务线等）
	var set_flag := str(choice.set_flag).strip_edges()
	if set_flag != "" and not run.event_flags.has(set_flag):
		run.event_flags.append(set_flag)

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
		"claim_echo":
			var echo := ProfileService.claim_echo()
			var gained: int = int(echo.get("souls", 0))
			run.souls += gained
			return "你夺回上一局的回响：%d 卢恩。" % gained
		"offer_echo":
			var echo2 := ProfileService.claim_echo()
			var mem: int = maxi(1, int(echo2.get("souls", 0)) / 20)
			ProfileService.add_memory(mem)
			return "回响献给赐福，凝成 %d 点记忆。" % mem
		"gamble_card":
			if rng.randf() < 0.5:
				var prize := _random_rare_card(registry, rng)
				run.deck.append(prize)
				var c := registry.get_card(prize) as CardData
				var cname := c.name if c != null else prize
				return "赌运眷顾！《%s》加入了你的牌组。" % cname
			else:
				var loss: int = maxi(2, int(ceil(float(run.max_hp) * 0.10)))
				run.max_hp = maxi(10, run.max_hp - loss)
				run.hp = mini(run.hp, run.max_hp)
				return "赌输了，元气受损：最大生命 −%d。" % loss
		"curse_card":
			run.deck.append(choice.card_id)
			run.max_flasks = maxi(1, run.max_flasks - 1)
			run.flasks = mini(run.flasks, run.max_flasks)
			var cc := registry.get_card(choice.card_id) as CardData
			var ccname := cc.name if cc != null else choice.card_id
			return "《%s》加入牌组，但一个圣杯瓶位被永远封闭了。" % ccname
		"gamble_souls":
			if rng.randf() < 0.5:
				run.souls += choice.soul_cost * 2
				return "赌赢了！你赢回 %d 卢恩。" % (choice.soul_cost * 2)
			return "赌输了。卢恩不翼而飞。"
		"nothing":
			return "你未作改变，悄然离开。"
		# ── I6 少女的引火：终局前的不可逆献祭 ──
		"sacrifice_flask":
			run.max_flasks = maxi(1, run.max_flasks - 1)
			run.flasks = mini(run.flasks, run.max_flasks)
			run.kindling = "flask"
			return "你把圣杯瓶投入火焰。瓶熔化了，火却在你血管里点灯——终局之敌生命 −15%，你的伤害 +10%。（此决定不可撤销）"
		"sacrifice_weapon":
			var removed_id := ""
			var best_lv := -1
			for wid in run.weapons:
				var lv: int = int(run.weapon_levels.get(str(wid), 0))
				if lv > best_lv:
					best_lv = lv
					removed_id = str(wid)
			if removed_id == "":
				return "你没有武器可献。火焰沉默着。"
			run.weapons.erase(removed_id)
			run.weapon_levels.erase(removed_id)
			run.deck.append("sacrificed_blade")
			run.kindling = "weapon"
			var wname: String = removed_id
			var w := registry.get_weapon(removed_id)
			if w != null:
				wname = w.name
			return "你把《%s》（+%d）投入火焰。它没有熔化，而是凝成一柄更轻的剑——《献剑》加入了牌组。（此决定不可撤销）" % [wname, best_lv]
		"refuse_kindling":
			return "你向火焰摇头。有些路，要自己完整地走。（以完整之姿直面终局）"
		# ── I8 癫火圣约：不可逆禁忌 ──
		"frenzied_flame":
			run.frenzied_flame = true
			if not run.challenge_flags.has("frenzied_lord"):
				run.challenge_flags.append("frenzied_lord")
			var prize: String = FRENZY_CARDS[rng.randi_range(0, FRENZY_CARDS.size() - 1)]
			run.deck.append(prize)
			var fc := registry.get_card(prize) as CardData
			var fcname := fc.name if fc != null else prize
			return "三指没入你的胸口。黄焰在眼眶里安家：出伤 +25%%、每回合能量 +1；受伤 +25%%、赐福治疗减半。《%s》加入了牌组。这条路，回不了头了。" % fcname
		# ── I7 壶哥切磋：路由进战斗（由 RunFlowController 承接）──
		"duel_jar":
			return DUEL_JAR
		_:
			return "事件结束了，却似乎什么也没发生。"


func _random_rare_card(registry: DataRegistry, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for id in registry.all_card_ids():
		var card := registry.get_card(str(id)) as CardData
		if card != null and card.rarity in ["uncommon", "rare"]:
			pool.append(str(id))
	if pool.is_empty():
		return "great_knife"
	return pool[rng.randi_range(0, pool.size() - 1)]
