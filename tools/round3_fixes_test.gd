extends SceneTree
## 第三轮评审修正：M1 武器等级管道 / M2 钩子卡成长 / M3+M12 二阶段数据
## M4 打断不重选蓄力 / M5 先手按实际伤害 / M7 护符数值回数据 / M10 碎片定价 / M11 小圆盾

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const WeaponService = preload("res://scripts/core/WeaponService.gd")
const RunSaveService = preload("res://scripts/core/RunSaveService.gd")
const MapScreenView = preload("res://scripts/ui/MapScreenView.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()

	# ── M1 武器等级：RunState 为唯一事实来源，存档往返 + 新局清零 ──
	var run_a := RunState.new()
	run_a.reset_for_origin(registry.get_origin("samurai"), 1)
	run_a.weapon_levels["uchigatana_w"] = 3
	var ws := WeaponService.new()
	ws.load_from_registry(registry)
	if ws.max_weapon_level(run_a) != 3:
		_fail("M1: max_weapon_level 应读 run.weapon_levels")
		return
	var saved: Dictionary = RunSaveService.run_to_dict(run_a)
	var run_b := RunState.new()
	run_b.reset_for_origin(registry.get_origin("samurai"), 2)
	RunSaveService.run_from_dict(run_b, saved)
	if int(run_b.weapon_levels.get("uchigatana_w", 0)) != 3:
		_fail("M1: 存档往返应保留武器等级")
		return
	var run_c := RunState.new()
	run_c.reset_for_origin(registry.get_origin("samurai"), 3)
	if not run_c.weapon_levels.is_empty():
		_fail("M1: 新局武器等级应清零（杜绝串档）")
		return
	# 共享资源不得再被修改
	var shared_weapon := registry.get_weapon("uchigatana_w")
	if shared_weapon.level != 0:
		_fail("M1: 共享 WeaponData 资源不应携带局内等级")
		return
	print("M1 weapon level pipeline OK")

	# ── M2 钩子卡随武器等级成长（club 走 hook）──
	var dmg_lv0 := _club_hit(registry, 0)
	var dmg_lv5 := _club_hit(registry, 5)
	if dmg_lv5 <= dmg_lv0:
		_fail("M2: 钩子卡伤害应随武器等级成长（lv0=%d lv5=%d）" % [dmg_lv0, dmg_lv5])
		return
	print("M2 hook scaling OK (%d -> %d)" % [dmg_lv0, dmg_lv5])

	# ── M3 接肢贵族：二阶段提前 + 第一阶段有稳定直伤 ──
	var scion: Dictionary = registry.template_by_name("接肢贵族")
	if int(scion.get("phase2_hp_percent", 0)) != 65:
		_fail("M3: 接肢贵族二阶段应为 65%%")
		return
	var scion_has_attack_rot := false
	for m in scion.get("moves", []):
		if str((m as Dictionary).get("kind")) == "attack_rot":
			scion_has_attack_rot = true
	if not scion_has_attack_rot:
		_fail("M3: 接肢贵族第一阶段应有 attack_rot 稳定直伤")
		return
	print("M3 scion escalation OK")

	# ── M12 熔炉骑士 / 守墓斗士 获得二阶段池（NG+ 新鲜感）──
	for ename in ["熔炉骑士", "守墓斗士"]:
		var e: Dictionary = registry.template_by_name(ename)
		if (e.get("phase2_moves", []) as Array).size() != 3 or int(e.get("phase2_hp_percent", 0)) != 50:
			_fail("M12: %s 应有 50%% 二阶段与 3 个招式" % ename)
			return
	print("M12 elite phase2 OK")

	# ── M4 打断后的重选不再立刻蓄力 ──
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 910
	var run4 := RunState.new()
	run4.reset_for_origin(registry.get_origin("wretch"), 910)
	var combat4 := CombatController.new(run4, registry, rng4)
	combat4.start_combat(registry.template_by_name("大树守卫"))
	var g: Dictionary = combat4.enemies[0]
	g["_charge"] = 20
	combat4._choose_one_intent(g)
	if str(g._intent.get("text")) != "蓄力释放":
		_fail("M4 前置：蓄力中意图应为蓄力释放")
		return
	combat4.deal_enemy_damage(0, 999)  # 崩解打断
	if int(g.get("_charge", -1)) != 0 or str(g._intent.get("kind")) == "charge":
		_fail("M4: 打断后重选不应再是蓄力")
		return
	print("M4 interrupt no-recharge OK")

	# ── M5 先手压制只计实际伤害（治疗祷告不算）──
	var rng5 := RandomNumberGenerator.new()
	rng5.seed = 920
	var run5 := RunState.new()
	run5.reset_for_origin(registry.get_origin("prophet"), 920)
	var combat5 := CombatController.new(run5, registry, rng5)
	combat5.start_combat(registry.template_by_name("野狼"))
	combat5.run.hand = ["heal"]
	combat5.ember = 3
	combat5.play_card(0)
	if combat5.first_turn_attacks != 0:
		_fail("M5: 治疗祷告不应计入先手压制")
		return
	var rng5b := RandomNumberGenerator.new()
	rng5b.seed = 921
	var run5b := RunState.new()
	run5b.reset_for_origin(registry.get_origin("prophet"), 921)
	var combat5b := CombatController.new(run5b, registry, rng5b)
	combat5b.start_combat(registry.template_by_name("野狼"))
	combat5b.run.hand = ["longsword"]
	combat5b.ember = 3
	combat5b.play_card(0)
	if combat5b.first_turn_attacks != 1:
		_fail("M5: 造成伤害的卡应计入先手压制")
		return
	print("M5 ambush counts damage only OK")

	# ── M7 护符数值回数据 ──
	var rs := RelicService.new()
	var run7 := RunState.new()
	run7.reset_for_origin(registry.get_origin("wretch"), 930)
	if rs.relic_value(run7, registry, "gold_scarab") != 0:
		_fail("M7: 未持有护符数值应为 0")
		return
	rs.add_relic(run7, registry, "erdtree_gift")
	if rs.relic_value(run7, registry, "erdtree_gift") != 10:
		_fail("M7: relic_value 应读数据")
		return
	var rng7 := RandomNumberGenerator.new()
	rng7.seed = 930
	var combat7 := CombatController.new(run7, registry, rng7)
	var base_stance: int = combat7.calculate_stance_damage(10)
	rs.add_relic(run7, registry, "twohanded_sword_badge")
	var stance_scaled: int = combat7.calculate_stance_damage(10)
	if stance_scaled != int(ceil(float(base_stance) * 1.5)):
		_fail("M7: 双手剑徽章应按 value=50%% 放大姿态（%d -> %d）" % [base_stance, stance_scaled])
		return
	rs.add_relic(run7, registry, "marikas_brand")
	if rs.relic_value2(run7, registry, "marikas_brand") != 2:
		_fail("M7: marikas_brand value2 应为 2")
		return
	print("M7 relic values data-driven OK")

	# ── M10 碎片定价按层递增 ──
	var run10 := RunState.new()
	run10.reset_for_origin(registry.get_origin("wretch"), 940)
	if MapScreenView.fragment_cost(run10) != 30:
		_fail("M10: 第 0 层碎片应为 30 卢恩")
		return
	run10.floor_index = 11
	if MapScreenView.fragment_cost(run10) != 140:
		_fail("M10: 第 11 层碎片应为 140 卢恩")
		return
	print("M10 fragment cost scaling OK")

	# ── M11 小圆盾走统一姿态结算（可独立触发崩解）──
	var rng11 := RandomNumberGenerator.new()
	rng11.seed = 950
	var run11 := RunState.new()
	run11.reset_for_origin(registry.get_origin("warrior"), 950)
	var combat11 := CombatController.new(run11, registry, rng11)
	combat11.start_combat(registry.template_by_name("野狼"))
	var wolf: Dictionary = combat11.enemies[0]
	wolf.stance_now = 4
	wolf["_intent"] = {"kind": "attack", "value": 5, "hits": 1, "text": "扑咬"}
	combat11.run.hand = ["buckler"]
	combat11.ember = 3
	combat11.play_card(0)
	if not bool(wolf.get("break_open", false)):
		_fail("M11: 小圆盾削姿态应走统一结算并触发崩解")
		return
	print("M11 buckler unified stance OK")

	print("round3_fixes_test: OK")
	quit()


func _club_hit(registry: DataRegistry, weapon_level: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var run := RunState.new()
	run.reset_for_origin(registry.get_origin("wretch"), 77)
	if weapon_level > 0:
		run.weapon_levels["club_w"] = weapon_level
	var combat := CombatController.new(run, registry, rng)
	combat.start_combat(registry.template_by_name("野狼"))
	var hp0: int = int(combat.enemies[0].hp)
	var idx := -1
	for i in range(combat.run.hand.size()):
		if str(combat.run.hand[i]) == "club":
			idx = i
			break
	if idx < 0:
		return -1
	combat.play_card(idx)
	return hp0 - int(combat.enemies[0].hp)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
