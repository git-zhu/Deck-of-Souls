extends SceneTree
## 阶段 B：流派化奖励 / 规则型护符 / 卡牌升级 / 数值修正

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")
const CardData = preload("res://data/CardData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var rng := RandomNumberGenerator.new()

	# ── B1 流派化奖励：智力倾向 → 至少 1 张魔法卡，共 3 张 ──
	rng.seed = 101
	var run_a := RunState.new()
	run_a.reset_for_origin(registry.get_origin("astrologer"), 101)
	run_a.attrs["mind"] = 30
	var combat_a := CombatController.new(run_a, registry, rng)
	var rewards := combat_a.roll_rewards(registry.get_act(2))  # 利耶尼亚池
	if rewards.size() != 3:
		_fail("奖励应为 3 张，实际 %d" % rewards.size())
		return
	var magic_count := 0
	for cid in rewards:
		var c: CardData = registry.get_card(cid)
		if c != null and str(c.type) == "魔法":
			magic_count += 1
	if magic_count < 1:
		_fail("智力倾向奖励应含魔法卡：%s" % str(rewards))
		return
	print("B1 affinity rewards OK (magic=%d)" % magic_count)

	# ── B2 规则型护符 ──
	rng.seed = 7
	var run_b := RunState.new()
	run_b.reset_for_origin(registry.get_origin("wretch"), 7)
	var relic_service := RelicService.new()

	# 血君主之乐：出血 5 层即爆
	relic_service.add_relic(run_b, registry, "blood_lord_joy")
	var combat_b := CombatController.new(run_b, registry, rng)
	combat_b.start_combat(registry.template_by_name("野狼"))
	var wolf_hp: int = int(combat_b.enemies[0].hp)
	combat_b.apply_enemy_bleed(5)
	var burst: int = maxi(8, int(30 * 0.16))
	if int(combat_b.enemies[0].hp) != maxi(0, wolf_hp - burst):
		_fail("血君主之乐应在 5 层触发出血爆发")
		return
	print("B2 blood_lord_joy OK")

	# 亚兹勒辉石杖：法术卡打出后抽 1
	run_b.relics.erase("blood_lord_joy")
	relic_service.add_relic(run_b, registry, "azurs_staff")
	var combat_c := CombatController.new(run_b, registry, rng)
	combat_c.start_combat(registry.template_by_name("野狼"))
	combat_c.run.hand = ["glintstone_pebble"]
	combat_c.ember = 3
	combat_c.play_card(0)
	if combat_c.run.hand.size() != 1:
		_fail("亚兹勒杖应抽 1 张（手牌回到 1），实际 %d" % combat_c.run.hand.size())
		return
	print("B2 azurs_staff OK")

	# 双手剑徽章：姿态 +50%，护甲 −2
	run_b.relics.erase("azurs_staff")
	relic_service.add_relic(run_b, registry, "twohanded_sword_badge")
	var combat_d := CombatController.new(run_b, registry, rng)
	combat_d.start_combat(registry.template_by_name("野狼"))
	var base_stance: int = 4 + int(run_b.attr("dexterity") * 0.5) + combat_d.weapon_service.total_stance_bonus(run_b)
	if combat_d.calculate_stance_damage(4) != int(ceil(base_stance * 1.5)):
		_fail("双手剑徽章姿态应 +50%%")
		return
	combat_d.gain_block(8)
	if combat_d.block != 6:
		_fail("双手剑徽章护甲应 −2（8→6），实际 %d" % combat_d.block)
		return
	print("B2 twohanded_sword_badge OK")

	# 碎星将军的义肢：处决 +50%
	run_b.relics.erase("twohanded_sword_badge")
	relic_service.add_relic(run_b, registry, "starscourge_prosthesis")
	var combat_e := CombatController.new(run_b, registry, rng)
	combat_e.start_combat(registry.template_by_name("野狼"))
	combat_e.deal_enemy_damage(0, 99)
	combat_e.deal_enemy_damage(10, 0)
	if combat_e.break_choice.is_empty():
		_fail("应触发破绽选择")
		return
	var exec_v: int = int(combat_e.break_choice.get("exec", 0))
	var expected: int = int(ceil(float(int(ceil(10.0 * 1.5 * 1.35))) * 1.2)) + 8
	expected = int(ceil(expected * 1.5))
	if exec_v != expected:
		_fail("碎星义肢处决应为 %d，实际 %d" % [expected, exec_v])
		return
	print("B2 starscourge_prosthesis OK")

	# 玛莉卡的烙印：能量 +1，每回合 +2 腐败（wretch mind=10 → 基础上限 5）
	run_b.relics.erase("starscourge_prosthesis")
	relic_service.add_relic(run_b, registry, "marikas_brand")
	var combat_f := CombatController.new(run_b, registry, rng)
	combat_f.start_combat(registry.template_by_name("野狼"))
	var expect_ember: int = 3 + mini(2, int(run_b.attr("mind") / 3)) + 1
	if combat_f.max_ember != expect_ember:
		_fail("玛莉卡烙印能量上限应为 %d，实际 %d" % [expect_ember, combat_f.max_ember])
		return
	if run_b.player_rot != 2:
		_fail("玛莉卡烙印首回合应积累 2 腐败，实际 %d" % run_b.player_rot)
		return
	print("B2 marikas_brand OK")

	# ── B3 卡牌升级（锻造刻印）──
	rng.seed = 21
	var run_c := RunState.new()
	run_c.reset_for_origin(registry.get_origin("wretch"), 21)
	run_c.smithing_stones[0] = 1
	run_c.souls = 30
	var grace := GraceService.new()
	grace.load_from_registry(registry)
	var forge := registry.get_grace_option("forge_etch")
	if forge == null:
		_fail("forge_etch 赐福选项缺失")
		return
	if not grace.is_eligible(forge, run_c):
		_fail("锻造刻印应可用（有石有卢恩有卡）")
		return
	var res: String = grace.apply(forge, run_c)
	if res != GraceService.PICK_UPGRADE or run_c.smithing_stones[0] != 0 or run_c.souls != 0:
		_fail("锻造刻印应消耗资源并返回选牌流")
		return
	run_c.upgraded_cards.append("glintstone_pebble")
	var combat_g := CombatController.new(run_c, registry, rng)
	combat_g.start_combat(registry.template_by_name("凯丹佣兵"))
	var pebble: CardData = registry.get_card("glintstone_pebble")
	var upgraded_hit: int = combat_g.calculate_card_damage(pebble, 6)  # 4×1.3=6
	var normal_hit: int = combat_g.calculate_card_damage(pebble, 4)
	if upgraded_hit <= normal_hit:
		_fail("升级后伤害应更高")
		return
	var wolf_hp2: int = int(combat_g.enemies[0].hp)
	combat_g.run.hand = ["glintstone_pebble"]
	combat_g.ember = 3
	combat_g.play_card(0)
	var dmg_dealt: int = wolf_hp2 - int(combat_g.enemies[0].hp)
	if dmg_dealt != upgraded_hit * 2:
		_fail("升级辉石魔砾应造成 %d，实际 %d" % [upgraded_hit * 2, dmg_dealt])
		return
	print("B3 card upgrade OK")

	# ── B4 数值修正 ──
	# 集中能量：mind 6 → 能量上限 5（3+2 上限）
	rng.seed = 33
	var run_d := RunState.new()
	run_d.reset_for_origin(registry.get_origin("wretch"), 33)
	run_d.attrs["mind"] = 6
	var combat_h := CombatController.new(run_d, registry, rng)
	combat_h.start_combat(registry.template_by_name("野狼"))
	if combat_h.max_ember != 5:
		_fail("mind 6 应使能量上限 5，实际 %d" % combat_h.max_ember)
		return
	run_d.attrs["mind"] = 12
	combat_h.start_combat(registry.template_by_name("野狼"))
	if combat_h.max_ember != 5:
		_fail("能量上限应 cap 在 5，实际 %d" % combat_h.max_ember)
		return
	print("B4 mind ember OK")

	# 圣杯瓶 25% 缩放
	run_d.max_hp = 100
	run_d.hp = 50
	run_d.flasks = 1
	combat_h.use_flask()
	if run_d.hp != 75:
		_fail("圣杯瓶应回复 25（100×25%%），实际 hp=%d" % run_d.hp)
		return
	print("B4 flask scaling OK")

	# 易伤 cap = 3
	rng.seed = 44
	var run_e := RunState.new()
	run_e.reset_for_origin(registry.get_origin("wretch"), 44)
	var combat_i := CombatController.new(run_e, registry, rng)
	combat_i.start_combat(registry.template_by_name("挖石矿工"))
	combat_i.run.hand = ["black_flame", "black_flame"]
	combat_i.ember = 10
	combat_i.play_card(0)
	combat_i.play_card(0)
	if int(combat_i.enemies[0].get("vulnerable", 0)) != 3:
		_fail("易伤应 cap 在 3，实际 %d" % int(combat_i.enemies[0].get("vulnerable", 0)))
		return
	print("B4 vuln cap OK")

	# 锻造石保底：精英/Boss 必掉
	rng.seed = 55
	var run_f := RunState.new()
	run_f.reset_for_origin(registry.get_origin("wretch"), 55)
	var combat_j := CombatController.new(run_f, registry, rng)
	combat_j.start_combat(registry.template_by_name("大树守卫"))
	combat_j.deal_enemy_damage(999, 0)
	var stones_total: int = run_f.smithing_stones[0] + run_f.smithing_stones[1] + run_f.smithing_stones[2]
	if stones_total != 1:
		_fail("精英战应保底掉 1 颗锻造石，实际 %d" % stones_total)
		return
	print("B4 smithing pity OK")

	# 力量卡文案修正
	var flame: CardData = registry.get_card("flame_grant_me_strength")
	if not flame.text.contains("本场战斗"):
		_fail("火焰力量卡文案应为本场战斗")
		return
	print("B4 text fix OK")

	print("build_depth_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
