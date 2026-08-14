class_name CombatController
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardEffectResolver = preload("res://scripts/core/CardEffectResolver.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const ActData = preload("res://data/ActData.gd")
const CardData = preload("res://data/CardData.gd")
const WeaponService = preload("res://scripts/core/WeaponService.gd")

signal combat_changed
signal combat_ended(kind: String)
signal log_message(text: String)

var run: RunState
var registry: DataRegistry
var rng: RandomNumberGenerator

# 多敌人：所有在场敌人实例；enemy / enemy_intent 为 getter，指向当前选中目标
var enemies: Array = []
var target_index: int = 0
var combat_over: bool = false
var ember: int = 3
var max_ember: int = 3
var block: int = 0
var relic_service := RelicService.new()
var weapon_service := WeaponService.new()

# ── 兼容 getter：enemy = 选中目标（默认第一个存活敌人）──
var enemy: Dictionary:
	get:
		return _current_enemy()
var enemy_intent: Dictionary:
	get:
		return _current_enemy().get("_intent", {})


func _current_enemy() -> Dictionary:
	if enemies.is_empty():
		return {}
	var idx := target_index
	if idx < 0 or idx >= enemies.size():
		idx = 0
	var e: Dictionary = enemies[idx]
	# 若选中目标已死，回退到第一个存活敌人
	if int(e.get("hp", 0)) <= 0:
		for i in range(enemies.size()):
			var cand: Dictionary = enemies[i]
			if int(cand.get("hp", 0)) > 0:
				target_index = i
				return cand
	return e


func alive_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if int(e.get("hp", 0)) > 0:
			out.append(e)
	return out


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if int(e.get("hp", 0)) > 0:
			n += 1
	return n


func set_target(index: int) -> void:
	if index >= 0 and index < enemies.size():
		target_index = index


func _init(p_run: RunState, p_registry: DataRegistry, p_rng: RandomNumberGenerator) -> void:
	run = p_run
	registry = p_registry
	rng = p_rng
	weapon_service.load_from_registry(registry)


func combat_log(text: String) -> void:
	log_message.emit(text)


# 法环式卡牌伤害：基础值 + 属性补正，再 × 武器等级倍率
func calculate_card_damage(card: CardData, base_value: int) -> int:
	var attr_bonus := _attr_bonus_for_card(card)
	var raw := base_value + attr_bonus
	raw += weapon_service.total_attack_bonus(run)
	var mult := weapon_service.weapon_multiplier(run)
	return maxi(0, int(round(float(raw) * mult)))


# 属性补正：物理卡=力量(+0.5灵巧)；魔法=集中；祷告=信仰
func _attr_bonus_for_card(card: CardData) -> int:
	match str(card.type):
		"魔法":
			return run.attr("mind")
		"祷告":
			return run.attr("faith")
		"武器", "战灰", "传说", "壶":
			return run.attr("strength") + int(run.attr("dexterity") * 0.5)
		_:
			return 0


# 姿态伤害：基础 + 灵巧补正 + 武器姿态加成
func calculate_stance_damage(base_stance: int) -> int:
	return base_stance + int(run.attr("dexterity") * 0.5) + weapon_service.total_stance_bonus(run)


func start_combat(template: Dictionary) -> void:
	combat_over = false
	block = 0
	run.player_rot = 0
	run.player_bleed = 0
	run.player_vulnerable = 0
	run.player_strength = 0
	# 支持多敌人：template.enemies（Array[Dictionary]）或单敌人（整模板即一个敌人）
	enemies.clear()
	var raw_list: Array = template.get("enemies", [])
	if raw_list.is_empty():
		raw_list = [template]
	var act := registry.get_act(run.act_index())
	var hp_percent: int = act.enemy_hp_percent if act != null else 100
	# 模板级标记（精英群/群怪）：传播到成员，供战斗结束判定
	var group_elite: bool = bool(template.get("elite", false))
	var group_boss: bool = bool(template.get("boss", false))
	var group_act_boss: bool = bool(template.get("is_act_boss", false))
	var group_run_boss: bool = bool(template.get("is_run_boss", false))
	for raw in raw_list:
		var e: Dictionary = (raw as Dictionary).duplicate(true)
		if act != null and hp_percent != 100:
			var scaled := int(round(float(e.max_hp) * hp_percent / 100.0))
			e.max_hp = maxi(1, scaled)
		e.hp = e.max_hp
		e.block = 0
		e.rot = 0
		e.bleed = 0
		e.vulnerable = 0
		e.strength = 0
		e.stance_max = e.stance
		e.stance_now = e.stance
		# 群怪标记传播（单个敌人模板本身带标记时保留）
		if group_elite:
			e["elite"] = true
		if group_boss:
			e["boss"] = true
		if group_act_boss:
			e["is_act_boss"] = true
		if group_run_boss:
			e["is_run_boss"] = true
		e["_intent"] = {}
		enemies.append(e)
	target_index = 0
	run.draw_pile.assign(run.deck)
	run.draw_pile.shuffle()
	run.hand.clear()
	run.discard_pile.clear()
	run.exhaust_pile.clear()
	relic_service.apply_combat_start(run, registry, self)
	if enemies.size() == 1:
		combat_log("你踏入雾中。%s 举起武器。" % enemies[0].name)
	else:
		var names: Array = []
		for e in enemies:
			names.append(str(e.name))
		combat_log("你踏入雾中。%s 拦住了去路。" % "、".join(names))
	_choose_all_intents()
	start_player_turn()


func start_player_turn() -> void:
	ember = max_ember
	block = 0
	apply_player_start_status()
	var draw_count: int = run.player_hand_draw(relic_service.combat_extra_draw(run, registry))
	draw_cards(draw_count)
	combat_changed.emit()


func apply_player_start_status() -> void:
	if run.player_rot > 0:
		take_player_damage(run.player_rot, true)
		combat_log("腐败在血管中开花：你受到 %d 点伤害。" % run.player_rot)
		run.player_rot = max(0, run.player_rot - 1)
	if run.player_bleed >= 10:
		run.player_bleed -= 10
		var burst: int = max(8, int(run.max_hp * 0.16))
		take_player_damage(burst, true)
		combat_log("出血爆发，你受到 %d 点伤害。" % burst)
	if run.player_vulnerable > 0:
		run.player_vulnerable -= 1


func play_card(index: int) -> void:
	if index < 0 or index >= run.hand.size() or combat_over:
		return
	var card_id := run.hand[index]
	var card := registry.get_card(card_id)
	if card == null:
		return
	if card.cost > ember:
		combat_log("集中不足。")
		combat_changed.emit()
		return
	ember -= card.cost
	run.hand.remove_at(index)
	combat_log("你打出《%s》。" % card.name)
	var resolver := CardEffectResolver.new(self)
	var exhaust: bool = resolver.resolve(card)
	if exhaust:
		run.exhaust_pile.append(card_id)
	else:
		run.discard_pile.append(card_id)
	check_combat_end()
	combat_changed.emit()


func deal_enemy_damage(amount: int, stance_damage: int, target_idx: int = -1) -> bool:
	# 对指定目标（-1 = 当前选中目标）造成伤害与姿态削减
	var e := _target_dict(target_idx)
	if e.is_empty() or int(e.get("hp", 0)) <= 0:
		return false
	var final: int = amount
	if int(e.get("vulnerable", 0)) > 0:
		final = int(ceil(final * 1.5))
	if int(e.get("stance_now", 0)) <= 0:
		final = int(ceil(final * 1.35))
	var blocked: int = mini(int(e.get("block", 0)), final)
	e.block = int(e.get("block", 0)) - blocked
	final -= blocked
	e.hp = maxi(0, int(e.get("hp", 0)) - final)
	e.stance_now = int(e.get("stance_now", 0)) - stance_damage
	combat_log("对%s造成 %d 伤害，削减 %d 姿态。" % [e.name, final, stance_damage])
	var broke: bool = false
	if int(e.get("stance_now", 0)) <= 0:
		broke = true
		e.vulnerable = int(e.get("vulnerable", 0)) + 1
		e.stance_now = e.stance_max
		combat_log("%s 姿态崩解，短暂露出破绽。" % e.name)
	check_enemy_death(target_idx)
	return broke


func apply_enemy_bleed(value: int, target_idx: int = -1) -> void:
	var e := _target_dict(target_idx)
	if e.is_empty() or int(e.get("hp", 0)) <= 0:
		return
	e.bleed = int(e.get("bleed", 0)) + value
	combat_log("%s 出血积累 +%d。" % [e.name, value])
	if int(e.get("bleed", 0)) >= 10:
		e.bleed = int(e.get("bleed", 0)) - 10
		var burst: int = maxi(8, int(e.get("max_hp", 1) * 0.16))
		e.hp = maxi(0, int(e.get("hp", 0)) - burst)
		combat_log("%s 出血爆发，追加 %d 点伤害。" % [e.name, burst])
		check_enemy_death(target_idx)


func _target_dict(target_idx: int) -> Dictionary:
	# -1 → 当前选中目标；否则按索引取敌人
	if target_idx >= 0 and target_idx < enemies.size():
		return enemies[target_idx]
	return _current_enemy()


func gain_block(value: int) -> void:
	block += value
	combat_log("获得 %d 护甲。" % value)


func heal_player(value: int) -> void:
	var recovered: int = mini(run.max_hp - run.hp, value)
	run.hp += recovered
	combat_log("回复 %d 生命。" % recovered)


func use_flask() -> void:
	if run.flasks <= 0 or run.hp >= run.max_hp:
		return
	run.flasks -= 1
	heal_player(18)
	combat_changed.emit()


func draw_cards(count: int) -> void:
	for _i in range(count):
		if run.draw_pile.is_empty():
			if run.discard_pile.is_empty():
				return
			run.draw_pile.assign(run.discard_pile)
			run.discard_pile.clear()
			run.draw_pile.shuffle()
			combat_log("弃牌堆化为新的抽牌堆。")
		run.hand.append(run.draw_pile.pop_back())


func end_player_turn() -> void:
	if combat_over:
		return
	run.discard_pile.append_array(run.hand)
	run.hand.clear()
	enemy_turn()


func enemy_turn() -> void:
	# 每个存活敌人依次行动
	for e in enemies:
		if int(e.get("hp", 0)) <= 0:
			continue
		e.block = 0
		if int(e.get("rot", 0)) > 0:
			e.hp = maxi(0, int(e.get("hp", 0)) - int(e.get("rot", 0)))
			combat_log("腐败啃食 %s：%d 点伤害。" % [e.name, e.rot])
			e.rot = maxi(0, int(e.get("rot", 0)) - 1)
		if int(e.get("bleed", 0)) >= 10:
			e.bleed = int(e.get("bleed", 0)) - 10
			var burst: int = maxi(8, int(e.get("max_hp", 1) * 0.16))
			e.hp = maxi(0, int(e.get("hp", 0)) - burst)
			combat_log("%s 出血爆发，受到 %d 点伤害。" % [e.name, burst])
		if int(e.get("hp", 0)) <= 0:
			continue
		var intent: Dictionary = e.get("_intent", {})
		_execute_enemy_action(e, intent)
		if run.hp <= 0:
			combat_ended.emit("defeat")
			return
	# 全部敌人行动后重新选意图，进入玩家回合
	if combat_over:
		return
	_choose_all_intents()
	start_player_turn()


func _execute_enemy_action(e: Dictionary, intent: Dictionary) -> void:
	match str(intent.get("kind", "")):
		"attack":
			_enemy_attack(e, int(intent.value), int(intent.get("hits", 1)))
		"attack_block":
			e.block = int(e.get("block", 0)) + int(intent.block)
			combat_log("%s 获得 %d 护甲。" % [e.name, intent.block])
			_enemy_attack(e, int(intent.value), 1)
		"debuff":
			run.player_vulnerable += int(intent.vulnerable)
			combat_log("%s 施加 %d 易伤。" % [e.name, intent.vulnerable])
		"buff":
			e.strength = int(e.get("strength", 0)) + int(intent.strength)
			combat_log("%s 力量 +%d。" % [e.name, intent.strength])
		"rot":
			run.player_rot += int(intent.value)
			combat_log("你积累 %d 腐败。" % intent.value)
		"attack_rot":
			_enemy_attack(e, int(intent.value), 1)
			run.player_rot += int(intent.rot)
			combat_log("你积累 %d 腐败。" % intent.rot)


func _enemy_attack(e: Dictionary, value: int, hits: int) -> void:
	for _i in range(hits):
		var amount: int = value + int(e.get("strength", 0))
		if run.player_vulnerable > 0:
			amount = int(ceil(amount * 1.5))
		var absorbed: int = mini(block, amount)
		block -= absorbed
		amount -= absorbed
		take_player_damage(amount, false)
		combat_log("%s 造成 %d 点伤害。" % [e.name, amount])


func take_player_damage(amount: int, ignores_block: bool) -> void:
	var final: int = amount
	if not ignores_block:
		var absorbed: int = mini(block, final)
		block -= absorbed
		final -= absorbed
	run.hp = maxi(0, run.hp - final)


func choose_enemy_intent() -> void:
	# 兼容单敌调用：为选中目标选意图
	var e := _current_enemy()
	if not e.is_empty():
		_choose_one_intent(e)


func _choose_all_intents() -> void:
	for e in enemies:
		if int(e.get("hp", 0)) > 0:
			_choose_one_intent(e)


func _choose_one_intent(e: Dictionary) -> void:
	var moves: Array = e.get("moves", [])
	if moves.is_empty():
		e["_intent"] = {"kind": "attack", "value": 6, "hits": 1, "text": "攻击"}
		return
	e["_intent"] = moves[rng.randi_range(0, moves.size() - 1)].duplicate(true)


func intent_text() -> String:
	var label: String = str(enemy_intent.get("text", "凝视"))
	match enemy_intent.get("kind", ""):
		"attack":
			return "%s，攻击 %d x%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.get("hits", 1)]
		"attack_block":
			return "%s，攻击 %d，护甲 %d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.block]
		"debuff":
			return "%s，施加易伤 %d" % [label, enemy_intent.vulnerable]
		"buff":
			return "%s，力量 +%d" % [label, enemy_intent.strength]
		"rot":
			return "%s，腐败 +%d" % [label, enemy_intent.value]
		"attack_rot":
			return "%s，攻击 %d，腐败 +%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.rot]
	return label


func check_enemy_death(target_idx: int = -1) -> void:
	# 检查指定敌人是否死亡（奖励合并到全部死亡时结算）
	var e := _target_dict(target_idx)
	if e.is_empty():
		return
	if int(e.get("hp", 0)) <= 0 and not bool(e.get("_dead_awarded", false)):
		e["_dead_awarded"] = true
		var soul_gain: int = int(e.souls) + relic_service.combat_souls_bonus(run, registry)
		run.souls += soul_gain
		combat_log("%s 倒下。你获得 %d 卢恩。" % [e.name, soul_gain])


func check_combat_end() -> void:
	# 所有敌人死亡 → 战斗结束（奖励已逐个结算，此处发结束事件）
	if combat_over:
		return
	if alive_count() > 0:
		return
	combat_over = true
	# 以首个敌人（或任意）判定结束类型
	var first: Dictionary = enemies[0] if not enemies.is_empty() else {}
	if bool(first.get("is_run_boss", false)):
		combat_ended.emit("run_victory")
	elif bool(first.get("is_act_boss", false)):
		combat_ended.emit("act_clear")
	elif bool(first.get("elite", false)):
		combat_ended.emit("elite_reward")
	else:
		combat_ended.emit("reward")


func roll_rewards(act: ActData = null) -> Array[String]:
	var pool: Array[String] = []
	if act != null:
		for card_id in act.reward_cards:
			var card := registry.get_card(str(card_id)) as CardData
			if card != null and card.rarity != "starter":
				pool.append(str(card_id))
	if pool.size() < 3:
		pool = _global_non_starter_card_pool()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size())) as Array[String]


func _global_non_starter_card_pool() -> Array[String]:
	var pool: Array[String] = []
	for id in registry.all_card_ids():
		var card := registry.get_card(id) as CardData
		if card != null and card.rarity != "starter":
			pool.append(str(id))
	return pool
