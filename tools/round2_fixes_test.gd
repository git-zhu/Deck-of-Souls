extends SceneTree
## 第二轮评审修正：N1 蓄力打断 / N2 升级卡标识 / N3 防反延续 / N4 souls_earned
## N5 记忆消耗 / N8 NG+招式池 / N9 接肢贵族二阶段 / N6 卡池去重 / N12 誓约Ⅳ/Ⅴ

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const DeckPopupView = preload("res://scripts/ui/DeckPopupView.gd")


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	var registry := DataRegistry.new()
	registry.load_all()
	var rng := RandomNumberGenerator.new()

	# ── N1 蓄力可被姿态打断 ──
	rng.seed = 901
	var run_1 := RunState.new()
	run_1.reset_for_origin(registry.get_origin("wretch"), 901)
	var combat_1 := CombatController.new(run_1, registry, rng)
	combat_1.start_combat(registry.template_by_name("野狼"))
	combat_1.enemies[0]["_charge"] = 20
	combat_1._choose_one_intent(combat_1.enemies[0])
	if str(combat_1.enemies[0]._intent.get("text")) != "蓄力释放":
		_fail("蓄力中敌人意图应为蓄力释放")
		return
	combat_1.deal_enemy_damage(0, 99)  # 姿态一击打崩
	if int(combat_1.enemies[0].get("_charge", -1)) != 0:
		_fail("崩解应清空蓄力")
		return
	if str(combat_1.enemies[0]._intent.get("text")) == "蓄力释放":
		_fail("崩解后意图应重选，不再是蓄力释放")
		return
	print("N1 charge interrupt OK")

	# ── N3 防反延续破绽 ──
	rng.seed = 902
	var run_3 := RunState.new()
	run_3.reset_for_origin(registry.get_origin("wretch"), 902)
	var combat_3 := CombatController.new(run_3, registry, rng)
	combat_3.start_combat(registry.template_by_name("野狼"))
	combat_3.deal_enemy_damage(0, 99)  # 崩解 → break_open
	if not bool(combat_3.enemies[0].get("break_open", false)):
		_fail("首击崩解应进入破绽状态")
		return
	combat_3.deal_enemy_damage(5, 0)  # 破绽期间命中 → 触发处决/防反
	if combat_3.break_choice.is_empty():
		_fail("破绽期间命中应触发处决/防反选择")
		return
	combat_3.apply_break_choice("parry")
	if not bool(combat_3.enemies[0].get("break_open", false)) or int(combat_3.enemies[0].stance_now) != 0:
		_fail("防反后破绽应延续（break_open 且姿态 0）")
		return
	combat_3.deal_enemy_damage(5, 0)  # 再次命中 → 再次触发处决/防反
	if combat_3.break_choice.is_empty():
		_fail("防反延续的破绽被命中应再次触发选择")
		return
	print("N3 parry sustain OK")

	# ── N4 souls_earned ──
	rng.seed = 903
	var run_4 := RunState.new()
	run_4.reset_for_origin(registry.get_origin("wretch"), 903)
	var combat_4 := CombatController.new(run_4, registry, rng)
	combat_4.start_combat(registry.template_by_name("野狼"))
	combat_4.deal_enemy_damage(999, 0)
	if run_4.souls_earned != 12 or run_4.souls != 12:
		_fail("击杀野狼应得 12 卢恩（earned=%d souls=%d）" % [run_4.souls_earned, run_4.souls])
		return
	run_4.souls -= 5  # 花掉余额
	if run_4.souls_earned != 12:
		_fail("消费不应影响 souls_earned")
		return
	print("N4 souls_earned OK")

	# ── N8 NG+ 招式池混入 phase2 ──
	rng.seed = 904
	var run_8 := RunState.new()
	run_8.reset_for_origin(registry.get_origin("wretch"), 904)
	run_8.ng_plus = 1
	var combat_8 := CombatController.new(run_8, registry, rng)
	combat_8.start_combat(registry.template_by_name("恶兆妖鬼玛尔基特"))
	var phase2_texts := ["手杖幻影连击", "黄金锤坠击", "野心之火，烧吧"]
	var saw_phase2 := false
	for _i in range(60):
		combat_8._choose_one_intent(combat_8.enemies[0])
		if phase2_texts.has(str(combat_8.enemies[0]._intent.get("text", ""))):
			saw_phase2 = true
			break
	if not saw_phase2:
		_fail("NG+ 下玛尔基特普通回合应混入二阶段招式")
		return
	# 未触发二阶段文本（_phase2 仍 false）
	if bool(combat_8.enemies[0].get("_phase2", false)):
		_fail("NG+ 混招不应触发正式二阶段状态")
		return
	print("N8 ng+ move pool OK")

	# ── N9 接肢贵族二阶段 ──
	var scion: Dictionary = registry.template_by_name("接肢贵族")
	if int(scion.get("phase2_hp_percent", 0)) != 50 or (scion.get("phase2_moves", []) as Array).size() != 3:
		_fail("接肢贵族应有 50%% 二阶段与 3 个招式")
		return
	print("N9 scion phase2 OK")

	# ── N6 三幕奖励池零重叠 + 新卡存在 ──
	var acts := [registry.get_act(0), registry.get_act(1), registry.get_act(2)]
	for i in range(acts.size()):
		for j in range(i + 1, acts.size()):
			for cid in acts[i].reward_cards:
				if (acts[j].reward_cards as Array).has(cid):
					_fail("奖励池跨幕重叠：%s（幕 %d 与幕 %d）" % [str(cid), i, j])
					return
	for cid in ["twinblade", "storm_blade", "bloody_slash", "comet", "shard_spiral"]:
		if registry.get_card(cid) == null:
			_fail("新卡缺失：%s" % cid)
			return
	print("N6 pool dedupe OK")

	# ── N2 升级卡「＋」标识 ──
	rng.seed = 905
	var run_2 := RunState.new()
	run_2.reset_for_origin(registry.get_origin("wretch"), 905)
	run_2.upgraded_cards.append("glintstone_pebble")
	var combat_2 := CombatController.new(run_2, registry, rng)
	combat_2.start_combat(registry.template_by_name("野狼"))
	var pebble = registry.get_card("glintstone_pebble")
	var btn := UiBuilders.card_button(pebble, 0, combat_2, 110.0, 142.0, func(): pass)
	if not _label_contains(btn, "辉石魔砾＋"):
		_fail("手牌应显示升级卡的「＋」")
		return
	var row := UiBuilders.deck_summary_row(pebble, 1, 520.0, true)
	if not _label_contains(row, "＋"):
		_fail("牌组行应显示升级卡的「＋」")
		return
	print("N2 upgraded display OK")

	# ── N5 记忆消耗 ──
	var p := ProfileService.load_profile()
	p["memory"] = 60
	ProfileService.save_profile(p)
	ProfileService.add_memory(-50)
	if int(ProfileService.load_profile().get("memory", 0)) != 10:
		_fail("记忆消耗 50 后应为 10")
		return
	ProfileService.add_memory(-999)
	if int(ProfileService.load_profile().get("memory", 0)) != 0:
		_fail("记忆不应为负")
		return
	print("N5 memory sink OK")

	# ── N12 誓约Ⅳ/Ⅴ ──
	rng.seed = 906
	var run_v := RunState.new()
	run_v.reset_for_origin(registry.get_origin("vagabond"), 906)
	var base_hp: int = run_v.max_hp
	run_v.vow_level = 5
	ProfileService.apply_vow_start(run_v)
	if run_v.max_hp != maxi(20, int(base_hp * 0.8)):
		_fail("誓约Ⅴ应使最大生命 −20%%")
		return
	var combat_v := CombatController.new(run_v, registry, rng)
	combat_v.start_combat(registry.template_by_name("野狼"))
	if combat_v.run.hand.size() != 4:
		_fail("誓约Ⅳ应使首回合抽 4 张，实际 %d" % combat_v.run.hand.size())
		return
	if ProfileService.MAX_VOW != 5:
		_fail("MAX_VOW 应为 5")
		return
	print("N12 vows IV/V OK")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	print("round2_fixes_test: OK")
	quit()


func _label_contains(root: Control, needle: String) -> bool:
	if root is Label and (root as Label).text.contains(needle):
		return true
	for child in root.get_children():
		if child is Control and _label_contains(child, needle):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
