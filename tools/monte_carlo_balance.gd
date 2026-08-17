extends SceneTree

# Monte Carlo 平衡工具（headless）
# 对每个出身 × 每幕敌人模板模拟多场战斗（贪心策略），输出胜率/平均剩余HP/平均回合。
# 用法: godot4.6 --headless --path . --script tools/monte_carlo_balance.gd
# 可选参数: --sims=N（每场组合模拟次数，默认 200）

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")

var sims := 200


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sims="):
			sims = int(arg.get_slice("=", 1))
			if sims < 20:
				sims = 20

	var registry := DataRegistry.new()
	registry.load_all()
	var origins: Array = registry.all_origin_ids()
	var templates := registry.enemy_templates()

	print("Monte Carlo balance  (sims=%d per cell)" % sims)
	print("")

	# Column header
	var header := "%-10s %-18s %6s %10s %10s %8s %10s" % ["出身", "敌人", "胜率", "均剩余HP", "均回合", "血量比", "胜场"]
	print(header)
	print("-".repeat(header.length()))

	for origin_id in origins:
		var origin := registry.get_origin(origin_id)
		for template: Dictionary in templates:
			var result: Dictionary = _simulate_origin_vs(registry, origin_id, template, origin.max_hp)
			var win_rate: float = 100.0 * float(result.wins) / float(sims)
			var hp_ratio: float = 100.0 * float(result.avg_hp) / float(origin.max_hp)
			print(
				"%-10s %-18s %5.1f%% %9.1f %10.1f %7.1f%% %8d" % [
					origin_id,
					str(template.get("name", "?")),
					win_rate,
					result.avg_hp,
					result.avg_turns,
					hp_ratio,
					result.wins,
				]
			)
	print("")
	print("done")
	quit()


func _simulate_origin_vs(registry: DataRegistry, origin_id: String, template: Dictionary, max_hp: int) -> Dictionary:
	var wins := 0
	var total_hp := 0.0
	var total_turns := 0.0
	for _i in sims:
		var rng := RandomNumberGenerator.new()
		rng.seed = randi()
		var run_state := RunState.new()
		var origin := registry.get_origin(origin_id)
		run_state.reset_for_origin(origin, rng.seed)
		var combat := CombatController.new(run_state, registry, rng)
		# silence the log for speed
		combat.log_message.connect(func(_t: String) -> void: pass)
		combat.start_combat(template.duplicate(true))
		var turns := 0
		var defeated := false
		while not combat.combat_over and turns < 60:
			turns += 1
			_greedy_play(combat, run_state)
			if not combat.break_choice.is_empty():
				combat.apply_break_choice("exec")
			if combat.combat_over:
				break
			combat.end_player_turn()
			if run_state.hp <= 0:
				defeated = true
				break
		if turns >= 60:
			defeated = true
		if not defeated and run_state.hp > 0 and int(combat.enemy.get("hp", 0)) <= 0:
			wins += 1
			total_hp += float(run_state.hp)
			total_turns += float(turns)
	return {
		"wins": wins,
		"avg_hp": total_hp / maxf(1.0, float(wins)),
		"avg_turns": total_turns / maxf(1.0, float(wins)),
	}


# 贪心策略：能斩杀先斩杀；否则按“伤害/费用”优先；敌人即将攻击时优先护甲；低血时用瓶。
func _greedy_play(combat: CombatController, run_state: RunState) -> void:
	var registry: DataRegistry = combat.registry
	var enemy_hp := int(combat.enemy.get("hp", 0))
	while true:
		# 姿态崩解：贪心 bot 一律选择处决
		if not combat.break_choice.is_empty():
			combat.apply_break_choice("exec")
			enemy_hp = int(combat.enemy.get("hp", 0))
			if combat.combat_over:
				break
			continue
		var played := false
		var best_index := -1
		var best_score := -INF
		for i in range(run_state.hand.size()):
			var card_id: String = run_state.hand[i]
			var card := registry.get_card(card_id)
			if card == null or card.cost > combat.ember:
				continue
			var score := _card_score(combat, run_state, card_id, enemy_hp)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index >= 0 and best_score > 0.0:
			combat.play_card(best_index)
			enemy_hp = int(combat.enemy.get("hp", 0))
			played = true
			if combat.combat_over:
				break
		if not played:
			break
	# 低血时使用圣杯瓶
	if run_state.flasks > 0 and run_state.hp <= int(run_state.max_hp * 0.4):
		combat.use_flask()


func _card_score(combat: CombatController, run_state: RunState, card_id: String, enemy_hp: int) -> float:
	var registry: DataRegistry = combat.registry
	var card := registry.get_card(card_id)
	if card == null:
		return 0.0
	var cost := int(card.cost)
	var attack := _estimate_damage(card_id)
	var block := _estimate_block(card_id)
	var heal := _estimate_heal(card_id)
	var draw := _estimate_draw(card_id)
	var score := 0.0
	# 斩杀优先
	if attack > 0 and enemy_hp <= attack:
		score = 10000.0 - float(cost)
		return score
	# 伤害按每点集中计算
	if attack > 0:
		score += attack * 4.0 / maxf(1.0, float(cost))
	# 敌人攻击意图时护甲有价值
	if _enemy_attacking(combat):
		score += block * 2.0 / maxf(1.0, float(cost))
	else:
		score += block * 0.8 / maxf(1.0, float(cost))
	# 低血时治疗有价值
	if run_state.hp <= int(run_state.max_hp * 0.5):
		score += heal * 2.5 / maxf(1.0, float(cost))
	# 抽牌轻度价值
	score += draw * 1.2 / maxf(1.0, float(cost))
	# 净空手牌时有额外奖励的钩子卡（club）
	if card.hook_id == "club" and run_state.hand.is_empty():
		score += 5.0
	return score


func _enemy_attacking(combat: CombatController) -> bool:
	var kind := str(combat.enemy_intent.get("kind", ""))
	return kind in ["attack", "attack_block", "attack_rot"]


func _estimate_damage(card_id: String) -> int:
	match card_id:
		"longsword": return 7
		"halberd": return 13
		"uchigatana": return 6
		"scimitar": return 8
		"great_knife": return 3
		"glintstone_pebble": return 8
		"glintstone_arc": return 10
		"catch_flame": return 9
		"volcano_pot": return 6
		"black_flame": return 12
		"rock_sling": return 6
		"glintstone_stars": return 8
		"hoarfrost_stomp": return 5
		"longbow": return 5
		"club": return 6
		"battle_axe": return 15
		"lions_claw": return 14
		"magic_glintblade": return 11
		"destined_death": return 25
		"crimson_flask": return 0
		"heater_shield": return 0
		"buckler": return 0
		"heal": return 0
		"urgent_heal": return 0
		"assassins_approach": return 0
		"bloodhounds_step": return 0
		"rotten_breath": return 0
		"flame_grant_me_strength": return 0
		_:
			return 0


func _estimate_block(card_id: String) -> int:
	match card_id:
		"heater_shield": return 8
		"buckler": return 5
		"heal": return 3
		"assassins_approach": return 4
		"bloodhounds_step": return 4
		_:
			return 0


func _estimate_heal(card_id: String) -> int:
	match card_id:
		"crimson_flask": return 12
		"heal": return 8
		"urgent_heal": return 5
		_:
			return 0


func _estimate_draw(card_id: String) -> int:
	match card_id:
		"assassins_approach": return 1
		"bloodhounds_step": return 1
		"longbow": return 1
		"lions_claw": return 1
		"urgent_heal": return 1
		_:
			return 0
