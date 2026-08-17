extends SceneTree
## A2 姿态崩解决策点：破绽 → 处决/防反二选一 + 格挡反击/重击蓄力两张新卡

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

	# 1) 新卡已注册并入池
	if registry.get_card("guard_counter") == null or registry.get_card("heavy_charge") == null:
		_fail("新卡未注册")
		return
	var limgrave := registry.get_act(0)
	if not limgrave.reward_cards.has("guard_counter"):
		_fail("guard_counter 未入宁姆格福池")
		return
	print("new cards registered OK")

	# 2) 破防 → break_open（不立即回满姿态）
	var wolf := registry.template_by_name("野狼")
	var combat := CombatController.new(run_state, registry, rng)
	combat.start_combat(wolf)
	var e: Dictionary = combat.enemies[0]
	var hp_before: int = int(e.hp)
	var broke: bool = combat.deal_enemy_damage(0, 99)  # 直接打空姿态
	if not broke:
		_fail("姿态应崩解")
		return
	if not bool(e.get("break_open", false)):
		_fail("崩解后应进入 break_open")
		return
	if int(e.get("stance_now", 0)) != 0:
		_fail("破绽期间姿态应保持 0")
		return
	if int(e.get("vulnerable", 0)) < 1:
		_fail("崩解应附加易伤")
		return
	print("break open OK")

	# 3) 破绽期间命中 → 触发处决/防反选择
	combat.deal_enemy_damage(10, 0)
	if combat.break_choice.is_empty():
		_fail("破绽命中应触发 break_choice")
		return
	var exec_v: int = int(combat.break_choice.get("exec", 0))
	var parry_v: int = int(combat.break_choice.get("parry", 0))
	if exec_v <= 8 or parry_v <= 4:
		_fail("处决/防反数值异常：%d / %d" % [exec_v, parry_v])
		return
	if bool(e.get("break_open", false)):
		_fail("触发选择后破绽应被消耗")
		return
	if int(e.get("stance_now", 0)) != int(e.get("stance_max", 0)):
		_fail("触发选择后姿态应回满")
		return
	print("break choice offered OK (exec=%d parry=%d)" % [exec_v, parry_v])

	# 4) 选择期间行动被锁
	var turn_before: int = combat.turn
	combat.end_player_turn()
	if combat.turn != turn_before:
		_fail("等待选择时不应能结束回合")
		return
	combat.use_flask()
	print("action gate OK")

	# 5) 处决结算
	var hp_after_hit: int = int(e.hp)
	combat.apply_break_choice("execute")
	if not combat.break_choice.is_empty():
		_fail("选择后 break_choice 应清空")
		return
	if int(e.hp) != maxi(0, hp_after_hit - exec_v):
		_fail("处决伤害未生效")
		return
	print("execute OK (%d dmg)" % exec_v)

	# 6) 防反结算（新战斗）
	var combat2 := CombatController.new(run_state, registry, rng)
	combat2.start_combat(registry.template_by_name("野狼"))
	combat2.deal_enemy_damage(0, 99)
	combat2.deal_enemy_damage(10, 0)
	var parry2: int = int(combat2.break_choice.get("parry", 0))
	var ember_before: int = combat2.ember
	combat2.apply_break_choice("parry")
	if combat2.block != parry2:
		_fail("防反应获得 %d 护甲，实际 %d" % [parry2, combat2.block])
		return
	if combat2.ember != ember_before + 1:
		_fail("防反应返还 1 集中")
		return
	print("parry OK")

	# 7) 格挡反击：护甲 8 + 姿态削减 6
	var combat3 := CombatController.new(run_state, registry, rng)
	combat3.start_combat(registry.template_by_name("野狼"))
	var e3: Dictionary = combat3.enemies[0]
	var stance_before: int = int(e3.stance_now)
	combat3.run.hand = ["guard_counter"]
	combat3.play_card(0)
	if combat3.block < 8:
		_fail("格挡反击应至少 8 护甲")
		return
	if stance_before - int(e3.stance_now) != 6:
		_fail("格挡反击应削减 6 姿态")
		return
	print("guard_counter OK")

	# 8) 重击蓄力：下回合姿态伤害翻倍
	var combat4 := CombatController.new(run_state, registry, rng)
	combat4.start_combat(registry.template_by_name("野狼"))
	combat4.run.hand = ["heavy_charge"]
	combat4.play_card(0)
	if not combat4.stance_mult_next_turn:
		_fail("重击蓄力应标记下回合翻倍")
		return
	var base_stance_dmg: int = combat4.calculate_stance_damage(3)
	combat4.end_player_turn()  # 敌人行动 → 新回合 → buff 生效
	if not combat4.stance_active_buff:
		_fail("新回合应激活姿态翻倍")
		return
	if combat4.calculate_stance_damage(3) != base_stance_dmg * 2:
		_fail("姿态伤害应翻倍")
		return
	print("heavy_charge OK")

	print("stance_break_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
