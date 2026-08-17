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
signal break_choice_ready   # 姿态崩解 → 等待玩家选择处决/防反

var run: RunState
var registry: DataRegistry
var rng: RandomNumberGenerator

# 多敌人：所有在场敌人实例；enemy / enemy_intent 为 getter，指向当前选中目标
var enemies: Array = []
var target_index: int = 0
var combat_over: bool = false
var turn: int = 0
var first_turn_attacks: int = 0  # 第 1 回合打出的攻击型卡数（先手压制）
var ambush_used: bool = false
var ember: int = 3
var max_ember: int = 3
var block: int = 0
var relic_service := RelicService.new()
var weapon_service := WeaponService.new()

# 姿态崩解决策：break_open 的敌人被再次命中时，弹出「处决/防反」选择
var break_choice: Dictionary = {}     # {"target": idx, "exec": n, "parry": n}
var stance_mult_next_turn: bool = false  # 重击蓄力：下回合姿态伤害 ×2
var stance_active_buff: bool = false

# FX 事件队列：伤害/治疗/护甲变化即时记录，UI 层在重建后消费（飘字/闪烁）
var fx_events: Array = []
var _play_dealt_damage: bool = false  # M5：本次打出是否造成了实际伤害（先手压制计数用）


func _fx(kind: String, target: String, value: int) -> void:
	fx_events.append({"kind": kind, "target": target, "value": value})


func _enemy_tag(e: Dictionary) -> String:
	return "enemy_%d" % enemies.find(e)


func consume_fx_events() -> Array:
	var out := fx_events.duplicate()
	fx_events.clear()
	return out

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


# 姿态伤害：基础 + 灵巧补正 + 武器姿态加成（重击蓄力 ×2；双手剑徽章 +50%）
func calculate_stance_damage(base_stance: int) -> int:
	var total: int = base_stance + int(run.attr("dexterity") * 0.5) + weapon_service.total_stance_bonus(run)
	if stance_active_buff:
		total *= 2
	var stance_pct: int = relic_service.stance_percent_total(run, registry)
	if stance_pct > 0:
		total = int(ceil(float(total) * (1.0 + float(stance_pct) / 100.0)))
	return total


func start_combat(template: Dictionary) -> void:
	combat_over = false
	block = 0
	break_choice = {}
	stance_mult_next_turn = false
	stance_active_buff = false
	first_turn_attacks = 0
	ambush_used = false
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
	# NG+ 缩放：每级敌人 HP +25%（与幕缩放叠乘）
	hp_percent = int(round(float(hp_percent) * (1.0 + 0.25 * float(run.ng_plus))))
	# 誓言挑战「强敌」：敌人 HP +50%
	if run.challenge_flags.has("strong_foe"):
		hp_percent = int(round(float(hp_percent) * 1.5))
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
		# I6 灭裂之火：献瓶者对终局之敌的斩杀权（最大生命 −15%）
		if run.kindling == "flask" and bool(e.get("is_run_boss", false)):
			e.max_hp = maxi(1, int(round(float(e.max_hp) * 0.85)))
		e.hp = e.max_hp
		e.block = 0
		e.rot = 0
		e.bleed = 0
		e.vulnerable = 0
		e.strength = 0
		e.stance_max = e.stance
		e.stance_now = e.stance
		e["_phase2"] = false
		e["_charge"] = 0
		e["break_open"] = false
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
	# 集中属性：每 3 点 +1 能量上限（最多 +2），并重置护符残留的加成
	max_ember = 3 + mini(2, int(run.attr("mind") / 3))
	ember = max_ember
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
	turn += 1
	ember = max_ember
	# I8 癫火：每回合能量 +1（黄焰让手指停不下来）
	if run.frenzied_flame:
		ember += 1
	block = 0
	stance_active_buff = stance_mult_next_turn
	stance_mult_next_turn = false
	apply_player_start_status()
	var draw_count: int = run.player_hand_draw(relic_service.combat_extra_draw(run, registry))
	# 誓约Ⅳ 苦行者：每回合抽牌 −1
	if run.vow_level >= 4:
		draw_count = maxi(1, draw_count - 1)
	draw_cards(draw_count)
	combat_changed.emit()


func apply_player_start_status() -> void:
	if run.player_rot > 0:
		take_player_damage(run.player_rot, true)
		combat_log("腐败在血管中开花：你受到 %d 点伤害。" % run.player_rot)
		run.player_rot = max(0, run.player_rot - 1)
	if run.player_bleed >= bleed_burst_threshold():
		run.player_bleed -= bleed_burst_threshold()
		var burst: int = max(8, int(run.max_hp * 0.16))
		take_player_damage(burst, true)
		combat_log("出血爆发，你受到 %d 点伤害。" % burst)
	if run.player_vulnerable > 0:
		run.player_vulnerable -= 1
	var brand_rot: int = relic_service.relic_value2(run, registry, "marikas_brand")
	if brand_rot > 0:
		run.player_rot += brand_rot
		combat_log("玛莉卡的烙印渗血：腐败 +%d。" % brand_rot)


func play_card(index: int) -> void:
	if index < 0 or index >= run.hand.size() or combat_over:
		return
	if not break_choice.is_empty():
		return  # 等待处决/防反选择
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
	_play_dealt_damage = false
	var exhaust: bool = resolver.resolve(card)
	# 先手压制：第 1 回合打出"实际造成伤害"的卡才计数（治疗/纯护甲不算，M5）
	if turn == 1 and _play_dealt_damage:
		first_turn_attacks += 1
	if relic_service.has_relic(run, "azurs_staff") and str(card.type) == "魔法":
		draw_cards(1)
		combat_log("亚兹勒的辉石奔流：抽 1 张。")
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
	var was_break_open: bool = bool(e.get("break_open", false))
	var final: int = amount
	# I6 灭裂之火：献瓶的代价换来的伤害 +10%
	if run.kindling == "flask":
		final = int(ceil(final * 1.10))
	# I8 癫火：出伤 +25%（力量的代价在别处结算）
	if run.frenzied_flame:
		final = int(ceil(final * 1.25))
	if int(e.get("vulnerable", 0)) > 0:
		final = int(ceil(final * 1.5))
	if int(e.get("stance_now", 0)) <= 0:
		final = int(ceil(final * 1.35))
	var blocked: int = mini(int(e.get("block", 0)), final)
	e.block = int(e.get("block", 0)) - blocked
	final -= blocked
	e.hp = maxi(0, int(e.get("hp", 0)) - final)
	e.stance_now = int(e.get("stance_now", 0)) - stance_damage
	if final > 0:
		_play_dealt_damage = true
	_check_phase_transition(e)
	if blocked > 0:
		_fx("block_hit", _enemy_tag(e), blocked)
	if final > 0:
		_fx("damage", _enemy_tag(e), final)
	combat_log("对%s造成 %d 伤害，削减 %d 姿态。" % [e.name, final, stance_damage])
	var broke: bool = false
	if was_break_open:
		# 破绽期间命中 → 触发处决/防反选择（消耗破绽）
		_offer_break_resolution(e, final, target_idx)
	elif int(e.get("stance_now", 0)) <= 0:
		broke = true
		e.vulnerable = mini(3, int(e.get("vulnerable", 0)) + 1)
		e["break_open"] = true
		e["stance_now"] = 0
		# 魂式打断：崩解可以打断蓄力重击（S2 设计承诺）
		if int(e.get("_charge", 0)) > 0:
			e["_charge"] = 0
			e["_suppress_charge"] = true  # M4：打断后的重选不许立刻再蓄力
			_choose_one_intent(e)
			combat_log("%s 姿态崩解，蓄力被打断了！" % e.name)
		else:
			combat_log("%s 姿态崩解，露出巨大破绽！" % e.name)
	check_enemy_death(target_idx)
	return broke


# 破绽结算：提供处决/防反二选一（并发破绽自动结算为小额处决）
func _offer_break_resolution(e: Dictionary, trigger_damage: int, target_idx: int) -> void:
	e["break_open"] = false
	e["stance_now"] = int(e.get("stance_max", 1))
	var idx: int = target_idx if target_idx >= 0 else enemies.find(e)
	var exec_bonus: int = int(ceil(trigger_damage * 1.2)) + 8
	var exec_pct: int = relic_service.relic_value(run, registry, "starscourge_prosthesis")
	if exec_pct > 0:
		exec_bonus = int(ceil(float(exec_bonus) * (1.0 + float(exec_pct) / 100.0)))
	var parry_block: int = int(ceil(trigger_damage * 0.5)) + 4
	if break_choice.is_empty():
		break_choice = {"target": idx, "exec": exec_bonus, "parry": parry_block}
		combat_log("破绽坐实！处决，还是防反？")
		break_choice_ready.emit()
	else:
		var auto: int = 6
		e.hp = maxi(0, int(e.get("hp", 0)) - auto)
		_fx("damage", _enemy_tag(e), auto)
		combat_log("破绽溢出：追加处决 %d 伤害。" % auto)
		check_enemy_death(idx)


# 玩家选择：execute 处决 / parry 防反
func apply_break_choice(kind: String) -> void:
	if break_choice.is_empty():
		return
	var choice: Dictionary = break_choice.duplicate()
	break_choice = {}
	var idx: int = int(choice.get("target", 0))
	var e := _target_dict(idx)
	if kind == "execute":
		if not e.is_empty() and int(e.get("hp", 0)) > 0:
			var dmg: int = int(choice.get("exec", 0))
			e.hp = maxi(0, int(e.get("hp", 0)) - dmg)
			_fx("damage", _enemy_tag(e), dmg)
			combat_log("处决！对%s造成 %d 点要害伤害。" % [e.name, dmg])
			_check_phase_transition(e)
			check_enemy_death(idx)
	else:
		gain_block(int(choice.get("parry", 0)))
		ember += 1
		# 防反延续压制：敌人姿态不回满，破绽保留一回合（"先活下来，下回合处决"）
		if not e.is_empty() and int(e.get("hp", 0)) > 0:
			e["break_open"] = true
			e["stance_now"] = 0
			combat_log("防反！%s 踉跄未倒——破绽仍在。" % e.name)
		combat_log("防反稳住架势：护甲上架，集中 +1。")
	check_combat_end()
	combat_changed.emit()


# 出血爆发阈值：血君主之乐 → 5 层即爆（原 10）
func bleed_burst_threshold() -> int:
	if relic_service.has_relic(run, "blood_lord_joy"):
		return 5
	return 10


func apply_enemy_bleed(value: int, target_idx: int = -1) -> void:
	var e := _target_dict(target_idx)
	if e.is_empty() or int(e.get("hp", 0)) <= 0:
		return
	e.bleed = int(e.get("bleed", 0)) + value
	combat_log("%s 出血积累 +%d。" % [e.name, value])
	var threshold: int = bleed_burst_threshold()
	if int(e.get("bleed", 0)) >= threshold:
		e.bleed = int(e.get("bleed", 0)) - threshold
		var burst: int = maxi(8, int(e.get("max_hp", 1) * 0.16))
		e.hp = maxi(0, int(e.get("hp", 0)) - burst)
		_fx("damage", _enemy_tag(e), burst)
		combat_log("%s 出血爆发，追加 %d 点伤害。" % [e.name, burst])
		_check_phase_transition(e)
		check_enemy_death(target_idx)

# 二阶段转换：血量首次跌破 phase2_hp_percent → 换招式池 + 姿态回稳 25%
func _check_phase_transition(e: Dictionary) -> void:
	if bool(e.get("_phase2", false)):
		return
	var threshold: int = int(e.get("phase2_hp_percent", 0))
	if threshold <= 0:
		return
	var hp: int = int(e.get("hp", 0))
	if hp <= 0:
		return
	var max_hp: int = maxi(1, int(e.get("max_hp", 1)))
	if hp * 100 > max_hp * threshold:
		return
	var p2_moves: Array = e.get("phase2_moves", [])
	if p2_moves.is_empty():
		return
	e["_phase2"] = true
	e["moves"] = p2_moves.duplicate(true)
	var stance_max: int = int(e.get("stance_max", 0))
	e["stance_now"] = mini(stance_max, int(e.get("stance_now", 0)) + int(ceil(stance_max * 0.25)))
	var line: String = str(e.get("phase2_text", ""))
	if line == "":
		line = "%s 的气势变了。" % e.name
	combat_log(line)
	_fx("phase2", _enemy_tag(e), 0)


func _target_dict(target_idx: int) -> Dictionary:
	# -1 → 当前选中目标；否则按索引取敌人
	if target_idx >= 0 and target_idx < enemies.size():
		return enemies[target_idx]
	return _current_enemy()


func gain_block(value: int) -> void:
	var final: int = value
	if relic_service.has_relic(run, "twohanded_sword_badge"):
		final = maxi(0, final - 2)  # 双手握剑的人，盾也拿不稳
	block += final
	_fx("block_gain", "player", final)
	combat_log("获得 %d 护甲。" % final)


func heal_player(value: int) -> void:
	var recovered: int = mini(run.max_hp - run.hp, value)
	run.hp += recovered
	if recovered > 0:
		_fx("heal", "player", recovered)
	combat_log("回复 %d 生命。" % recovered)


func use_flask() -> void:
	if run.flasks <= 0 or run.hp >= run.max_hp:
		return
	if not break_choice.is_empty():
		return
	run.flasks -= 1
	# 法环式缩放：回复 25% 最大生命（至少 18）
	heal_player(maxi(18, int(run.max_hp * 0.25)))
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
	if not break_choice.is_empty():
		return
	# 先手压制：普通战第 1 回合打出 ≥3 张攻击卡 → 敌人姿态减半（StS 式 tempo 奖励）
	if turn == 1 and first_turn_attacks >= 3 and not ambush_used and _is_normal_encounter():
		ambush_used = true
		for e in enemies:
			if int(e.get("hp", 0)) > 0:
				e["stance_now"] = int(ceil(float(int(e.get("stance_now", 0))) / 2.0))
		combat_log("先手压制！敌人的姿态被打乱了（姿态减半）。")
	run.discard_pile.append_array(run.hand)
	run.hand.clear()
	enemy_turn()


# 普通遭遇（无精英/Boss）才触发先手压制
func _is_normal_encounter() -> bool:
	for e in enemies:
		if bool(e.get("elite", false)) or bool(e.get("boss", false)):
			return false
	return true


func enemy_turn() -> void:
	# 每个存活敌人依次行动
	for e in enemies:
		if int(e.get("hp", 0)) <= 0:
			continue
		e.block = 0
		if int(e.get("rot", 0)) > 0:
			var rot_dmg: int = int(e.get("rot", 0))
			e.hp = maxi(0, int(e.get("hp", 0)) - rot_dmg)
			_fx("damage", _enemy_tag(e), rot_dmg)
			combat_log("腐败啃食 %s：%d 点伤害。" % [e.name, rot_dmg])
			e.rot = maxi(0, rot_dmg - 1)
			_check_phase_transition(e)
		if int(e.get("bleed", 0)) >= bleed_burst_threshold():
			e.bleed = int(e.get("bleed", 0)) - bleed_burst_threshold()
			var burst: int = maxi(8, int(e.get("max_hp", 1) * 0.16))
			e.hp = maxi(0, int(e.get("hp", 0)) - burst)
			_fx("damage", _enemy_tag(e), burst)
			combat_log("%s 出血爆发，受到 %d 点伤害。" % [e.name, burst])
			_check_phase_transition(e)
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
			e["_charge"] = 0
		"attack_block":
			e.block = int(e.get("block", 0)) + int(intent.block)
			_fx("block_gain", _enemy_tag(e), int(intent.block))
			combat_log("%s 获得 %d 护甲。" % [e.name, intent.block])
			_enemy_attack(e, int(intent.value), 1)
		"debuff":
			run.player_vulnerable = mini(3, run.player_vulnerable + int(intent.vulnerable))
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
		"bleed":
			run.player_bleed += int(intent.get("bleed", 0))
			combat_log("%s 撕开伤口：你积累 %d 出血。" % [e.name, int(intent.get("bleed", 0))])
		"charge":
			e["_charge"] = int(intent.value) + int(e.get("strength", 0))
			combat_log("%s 压低重心蓄力，下一击不会轻。" % e.name)


func _enemy_attack(e: Dictionary, value: int, hits: int) -> void:
	for _i in range(hits):
		var amount: int = int(ceil(float(value + int(e.get("strength", 0))) * enemy_damage_multiplier()))
		if run.player_vulnerable > 0:
			amount = int(ceil(amount * 1.5))
		var absorbed: int = mini(block, amount)
		block -= absorbed
		amount -= absorbed
		if absorbed > 0:
			_fx("block_hit", "player", absorbed)
		take_player_damage(amount, false)
		combat_log("%s 造成 %d 点伤害。" % [e.name, amount])


# NG+ 每级敌人伤害 +15%；誓约Ⅲ（鲜血契约）再 +10%
func enemy_damage_multiplier() -> float:
	var mult := 1.0 + 0.15 * float(run.ng_plus)
	if run.vow_level >= 3:
		mult += 0.10
	return mult


func take_player_damage(amount: int, ignores_block: bool) -> void:
	# I8 癫火：受伤 +25%——承接癫火那天就写好的条款
	var incoming: int = amount
	if run.frenzied_flame:
		incoming = int(ceil(incoming * 1.25))
	var final: int = incoming
	if not ignores_block:
		var absorbed: int = mini(block, final)
		block -= absorbed
		final -= absorbed
	run.hp = maxi(0, run.hp - final)
	if final > 0:
		_fx("damage", "player", final)


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
	# 蓄力优先：上回合蓄力（telegraph），本回合强制释放——玩家有一整回合应对
	if int(e.get("_charge", 0)) > 0:
		e["_intent"] = {"kind": "attack", "value": int(e["_charge"]), "hits": 1, "text": "蓄力释放"}
		return
	var moves: Array = e.get("moves", [])
	# NG+ 新鲜感：混入二阶段招式池（复用已有数据，免费的内容轮换）
	if run.ng_plus > 0 and not bool(e.get("_phase2", false)):
		var p2: Array = e.get("phase2_moves", [])
		if p2.size() > 0:
			moves = moves + p2
	if moves.is_empty():
		e["_intent"] = {"kind": "attack", "value": 6, "hits": 1, "text": "攻击"}
		return
	# M4：打断后重选，剔除蓄力招式一次（打断不被自己立刻撤销）
	if bool(e.get("_suppress_charge", false)):
		e["_suppress_charge"] = false
		var filtered: Array = []
		for m in moves:
			if str((m as Dictionary).get("kind", "")) != "charge":
				filtered.append(m)
		if not filtered.is_empty():
			moves = filtered
	# 魂式可背板：按权重加权选取（权重即敌人个性）
	var total: int = 0
	for m in moves:
		total += maxi(1, int((m as Dictionary).get("weight", 1)))
	var roll: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	var chosen: Dictionary = moves[0]
	for m in moves:
		acc += maxi(1, int((m as Dictionary).get("weight", 1)))
		if roll < acc:
			chosen = m
			break
	e["_intent"] = (chosen as Dictionary).duplicate(true)


func intent_text() -> String:
	return intent_text_for(_current_enemy())


# 任意敌人实例的意图描述（多敌人：每个敌人头顶各自展示）
func intent_text_for(e: Dictionary) -> String:
	var it: Dictionary = e.get("_intent", {})
	var label: String = str(it.get("text", "凝视"))
	var atk: int = int(it.get("value", 0)) + int(e.get("strength", 0))
	match str(it.get("kind", "")):
		"attack":
			return "%s，攻击 %d x%d" % [label, atk, int(it.get("hits", 1))]
		"attack_block":
			return "%s，攻击 %d，护甲 %d" % [label, atk, int(it.get("block", 0))]
		"debuff":
			return "%s，施加易伤 %d" % [label, int(it.get("vulnerable", 0))]
		"buff":
			return "%s，力量 +%d" % [label, int(it.get("strength", 0))]
		"rot":
			return "%s，腐败 +%d" % [label, int(it.get("value", 0))]
		"attack_rot":
			return "%s，攻击 %d，腐败 +%d" % [label, atk, int(it.get("rot", 0))]
		"bleed":
			return "%s，出血 +%d" % [label, int(it.get("bleed", 0))]
		"charge":
			return "%s（蓄力中，下回合重击 %d）" % [label, int(it.get("value", 0)) + int(e.get("strength", 0))]
	return label


func check_enemy_death(target_idx: int = -1) -> void:
	# 检查指定敌人是否死亡（奖励合并到全部死亡时结算）
	var e := _target_dict(target_idx)
	if e.is_empty():
		return
	if int(e.get("hp", 0)) <= 0 and not bool(e.get("_dead_awarded", false)):
		e["_dead_awarded"] = true
		var soul_gain: int = int(e.souls) + relic_service.combat_souls_bonus(run, registry)
		# NG+ 卢恩 +30%/级；誓约Ⅲ（鲜血契约）再 +30%
		soul_gain = int(round(float(soul_gain) * (1.0 + 0.3 * float(run.ng_plus))))
		if run.vow_level >= 3:
			soul_gain = int(round(float(soul_gain) * 1.3))
		var double_chance: int = relic_service.relic_value(run, registry, "erdtree_gift")
		if double_chance > 0 and rng.randf() < float(double_chance) / 100.0:
			soul_gain *= 2
			combat_log("黄金树的落叶格外慷慨：卢恩翻倍！")
		run.souls += soul_gain
		run.souls_earned += soul_gain
		combat_log("%s 倒下。你获得 %d 卢恩。" % [e.name, soul_gain])
		# 锻造石掉落：普通战低概率 1 级石；精英/幕 Boss 更高等级
		_roll_smithing_stone(e)


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


# 锻造石掉落（保底版）：普通战 35% 掉 1 级石；精英必掉（2 级为主）；Boss 必掉（3 级为主）
func _roll_smithing_stone(e: Dictionary) -> void:
	var is_boss: bool = bool(e.get("is_act_boss", false)) or bool(e.get("is_run_boss", false))
	var is_elite: bool = bool(e.get("elite", false))
	var roll: int = rng.randi_range(1, 100)
	if is_boss:
		if roll <= 70:
			run.smithing_stones[2] += 1
			combat_log("你获得 3 级锻造石。")
		else:
			run.smithing_stones[1] += 1
			combat_log("你获得 2 级锻造石。")
	elif is_elite:
		if roll <= 50:
			run.smithing_stones[1] += 1
			combat_log("你获得 2 级锻造石。")
		elif roll <= 65:
			run.smithing_stones[2] += 1
			combat_log("你获得 3 级锻造石。")
		else:
			run.smithing_stones[0] += 1
			combat_log("你获得 1 级锻造石。")
	else:
		if roll <= 35:
			run.smithing_stones[0] += 1
			combat_log("你获得 1 级锻造石。")


func roll_rewards(act: ActData = null) -> Array[String]:
	var pool: Array[String] = []
	if act != null:
		for card_id in act.reward_cards:
			var card := registry.get_card(str(card_id)) as CardData
			if card != null and card.rarity != "starter":
				pool.append(str(card_id))
	if pool.size() < 3:
		pool = _global_non_starter_card_pool()
	# I8 癫火圣约：承约期间，癫火卡游入奖励池
	if run.frenzied_flame:
		for fcid in ["frenzy_flame", "three_fingers", "frenzied_burst", "lord_of_frenzy"]:
			if not pool.has(fcid):
				pool.append(fcid)
	# 流派化：2 张倾向卡 + 1 张异端卡（鼓励转型的意外之喜）
	var affinity_school := _build_affinity_school()
	var affinity_cards: Array[String] = []
	var heretic_cards: Array[String] = []
	for card_id in pool:
		var card := registry.get_card(card_id)
		if card != null and _card_school(card) == affinity_school:
			affinity_cards.append(card_id)
		else:
			heretic_cards.append(card_id)
	affinity_cards.shuffle()
	heretic_cards.shuffle()
	var picked: Array[String] = []
	for card_id in affinity_cards:
		if picked.size() >= 2:
			break
		picked.append(card_id)
	for card_id in heretic_cards:
		if picked.size() >= 3:
			break
		picked.append(card_id)
	# 倾向卡不足 3 张时用全池补齐
	if picked.size() < 3:
		for card_id in pool:
			if picked.size() >= 3:
				break
			if not picked.has(card_id):
				picked.append(card_id)
	picked.shuffle()
	return picked


# 构筑倾向：当前最高属性决定流派（力量/灵巧→物理，集中→魔法，信仰→祷告）
func _build_affinity_school() -> String:
	var physical: int = maxi(run.attr("strength"), run.attr("dexterity"))
	var mind: int = run.attr("mind")
	var faith: int = run.attr("faith")
	if mind >= physical and mind >= faith:
		return "magic"
	if faith >= physical and faith >= mind:
		return "prayer"
	return "physical"


func _card_school(card: CardData) -> String:
	match str(card.type):
		"魔法":
			return "magic"
		"祷告":
			return "prayer"
		_:
			return "physical"


func _global_non_starter_card_pool() -> Array[String]:
	var pool: Array[String] = []
	for id in registry.all_card_ids():
		var card := registry.get_card(id) as CardData
		if card != null and card.rarity != "starter":
			pool.append(str(id))
	return pool
