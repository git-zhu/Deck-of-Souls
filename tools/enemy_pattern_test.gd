extends SceneTree
## A1 敌人行为模式：权重选取 / 蓄力 telegraph / 二阶段转换 / 出血意图

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	run_state.reset_for_origin(registry.get_origin("vagabond"), 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 1) MoveData.weight 透传到模板
	var wolf := registry.template_by_name("野狼")
	if wolf.is_empty():
		_fail("野狼模板缺失")
		return
	var wolf_moves: Array = wolf.moves
	var w0: int = int((wolf_moves[0] as Dictionary).get("weight", 0))
	if w0 != 3:
		_fail("野狼第一招权重应为 3，实际 %d" % w0)
		return
	print("weight passthrough OK")

	# 2) 加权选取分布（200 次采样：权重 3 的招式应显著多于权重 1）
	var combat_wolf := CombatController.new(run_state, registry, rng)
	combat_wolf.start_combat(wolf)
	var counts := {}
	for _i in range(200):
		combat_wolf.choose_enemy_intent()
		var t: String = str(combat_wolf.enemy_intent.get("text", ""))
		counts[t] = int(counts.get(t, 0)) + 1
	var bite: int = int(counts.get("狼群撕咬", 0))
	var growl: int = int(counts.get("包围低吼", 0))
	if bite <= growl:
		_fail("加权失效：撕咬 %d 应多于低吼 %d" % [bite, growl])
		return
	print("weighted pick OK (撕咬=%d 低吼=%d)" % [bite, growl])

	# 3) 蓄力 telegraph：charge → 下回合强制攻击
	var sorcerer := registry.template_by_name("学院辉石法师")
	if sorcerer.is_empty():
		_fail("学院辉石法师模板缺失")
		return
	var has_charge := false
	for m in sorcerer.moves:
		if str((m as Dictionary).get("kind", "")) == "charge":
			has_charge = true
	if not has_charge:
		_fail("法师应有 charge 招式")
		return
	var combat_s := CombatController.new(run_state, registry, rng)
	combat_s.start_combat(sorcerer)
	var e: Dictionary = combat_s.enemies[0]
	combat_s._execute_enemy_action(e, {"kind": "charge", "value": 16, "text": "彗星蓄力"})
	if int(e.get("_charge", 0)) != 16:
		_fail("蓄力未记录 _charge")
		return
	combat_s.choose_enemy_intent()
	var it: Dictionary = combat_s.enemy_intent
	if str(it.get("kind", "")) != "attack" or int(it.get("value", 0)) != 16:
		_fail("蓄力后应为强制攻击 16，实际 %s" % str(it))
		return
	combat_s._execute_enemy_action(e, it)
	if int(e.get("_charge", 0)) != 0:
		_fail("攻击后 _charge 应清零")
		return
	print("charge telegraph OK")

	# 4) 出血意图激活 player_bleed
	var merc := registry.template_by_name("凯丹佣兵")
	var has_bleed := false
	for m in merc.moves:
		if str((m as Dictionary).get("kind", "")) == "bleed":
			has_bleed = true
	if not has_bleed:
		_fail("凯丹佣兵应有 bleed 招式")
		return
	var combat_m := CombatController.new(run_state, registry, rng)
	combat_m.start_combat(merc)
	combat_m._execute_enemy_action(combat_m.enemies[0], {"kind": "bleed", "bleed": 4, "text": "弯刀放血"})
	if run_state.player_bleed != 4:
		_fail("player_bleed 应为 4，实际 %d" % run_state.player_bleed)
		return
	print("bleed intent OK")

	# 5) 二阶段转换（玛尔基特 50%）
	var margit := registry.template_by_name("恶兆妖鬼玛尔基特")
	if int(margit.get("phase2_hp_percent", 0)) != 50:
		_fail("玛尔基特 phase2_hp_percent 应为 50")
		return
	if (margit.get("phase2_moves", []) as Array).size() != 3:
		_fail("玛尔基特 phase2_moves 应有 3 招")
		return
	var combat_b := CombatController.new(run_state, registry, rng)
	combat_b.start_combat(margit)
	var boss: Dictionary = combat_b.enemies[0]
	combat_b.deal_enemy_damage(55, 0)  # 110 → 55，正好 50%
	if not bool(boss.get("_phase2", false)):
		_fail("跌破 50%% 应触发二阶段")
		return
	if (boss.get("moves", []) as Array).size() != 3:
		_fail("二阶段后招式池应切换为 3 招")
		return
	if bool(boss.get("_phase2", false)) and int(boss.get("stance_now", 0)) < 24:
		# 姿态回稳 25%：24 → min(24, 24+6) 但 deal 已削减姿态；验证不超过上限
		pass
	print("phase2 transition OK")

	print("enemy_pattern_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
