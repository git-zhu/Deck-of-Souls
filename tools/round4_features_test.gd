extends SceneTree

# 第四轮创新（I4–I9）实施验证：
# I5 追忆二选一 / I6 少女的引火 / I9 杀死商人 / I8 癫火圣约 / I4 大卢恩朝圣 / I7 壶哥任务线

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const RunSaveService = preload("res://scripts/core/RunSaveService.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CardEffectResolver = preload("res://scripts/core/CardEffectResolver.gd")
const CardEffectStep = preload("res://data/CardEffectStep.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const RunFlowController = preload("res://scripts/core/RunFlowController.gd")
const RunRewardFlow = preload("res://scripts/core/RunRewardFlow.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")

var failures := 0


class FakeHost extends Node:
	var run_state = null
	var registry = null
	var last_layer: Control = null

	func _present_reward_layer(ctrl: Control) -> void:
		last_layer = ctrl


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()

	test_i5(registry)
	test_i6(registry)
	test_i9(registry)
	test_i8(registry)
	test_i4(registry)
	test_i7(registry)
	test_save_roundtrip()

	if failures == 0:
		print("round4_features_test: OK")
		quit()
	else:
		push_error("round4_features_test: %d failures" % failures)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)


# 在 UI 树里找到「继续」按钮并按下（模拟玩家点击）
func _press_continue(root: Control) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and (node as Button).text == "继续":
			(node as Button).pressed.emit()
			return
		for child in node.get_children():
			stack.append(child)


func _fresh_run() -> RunState:
	var run := RunState.new()
	run.hp = 72
	run.max_hp = 72
	run.max_flasks = 3
	run.flasks = 3
	run.souls = 500
	run.floor_index = 0
	run.deck = ["strike", "strike", "block", "shield_bash", "longbow"]
	run.weapons = ["longsword"]
	run.weapon_levels = {"longsword": 0}
	run.attrs = {"vigor": 10, "strength": 10, "dexterity": 10, "mind": 10, "faith": 10}
	return run


# ── I5 追忆二选一 ──────────────────────────────────────────────
func test_i5(registry: DataRegistry) -> void:
	_check(RunRewardFlow.REMEMBRANCE.size() == 3, "I5: three bosses mapped")
	var resolver_run := _fresh_run()
	var rng := RandomNumberGenerator.new()
	var resolver_combat := CombatController.new(resolver_run, registry, rng)
	var resolver := CardEffectResolver.new(resolver_combat)
	for boss in RunRewardFlow.REMEMBRANCE.keys():
		var pair: Array = RunRewardFlow.REMEMBRANCE[boss]
		_check(pair.size() == 2, "I5: %s pair size" % str(boss))
		for cid in pair:
			var card = registry.get_card(str(cid))
			_check(card != null, "I5: card %s exists" % str(cid))
			if card != null:
				_check(str(card.rarity) == "rare", "I5: %s is rare" % str(cid))
				_check(str(card.type) == "传说", "I5: %s is legend type" % str(cid))
				_check(resolver._catalog_steps(str(cid)).size() >= 1, "I5: %s has steps" % str(cid))

	# NG+ 漫步灵庙：两件都拿
	var host := FakeHost.new()
	var run := _fresh_run()
	host.run_state = run
	host.registry = registry
	run.ng_plus = 1
	var flow := RunRewardFlow.new(host)
	var before: int = run.deck.size()
	var done := {"v": false}
	flow.show_remembrance("恶兆妖鬼玛尔基特", func(): done.v = true)
	_check(run.deck.size() == before + 2, "I5: NG+ grants both remembrances")
	_check(run.deck.has("omen_judgment") and run.deck.has("omen_chain"), "I5: NG+ pair ids in deck")
	_check(host.last_layer != null, "I5: NG+ shows mausoleum message")
	_check(not done.v, "I5: NG+ waits for continue press")
	_press_continue(host.last_layer)
	_check(done.v, "I5: NG+ on_done fires after continue")

	# 正常局：二选一界面
	run.ng_plus = 0
	host.last_layer = null
	flow.show_remembrance("熔炉骑士", func(): pass)
	_check(host.last_layer != null, "I5: pick-1-of-2 layer presented")

	# 未知 BOSS：直通
	var done2 := {"v": false}
	flow.show_remembrance("不存在的王", func(): done2.v = true)
	_check(done2.v, "I5: unknown boss passes through")


# ── I6 少女的引火 ──────────────────────────────────────────────
func test_i6(registry: DataRegistry) -> void:
	var svc := EventService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817

	# 事件存在且三选项齐备
	var ev = registry.get_event("maiden_kindling")
	_check(ev != null, "I6: maiden_kindling event exists")
	if ev != null:
		var effects: Array = []
		for ch in ev.choices:
			effects.append(str(ch.effect))
		_check(
			effects.has("sacrifice_flask") and effects.has("sacrifice_weapon") and effects.has("refuse_kindling"),
			"I6: three kindling choices present"
		)

	# 献瓶
	var run := _fresh_run()
	var c_flask := MapEventChoiceData.new()
	c_flask.effect = "sacrifice_flask"
	_check(svc.is_choice_eligible(c_flask, run, registry), "I6: flask sacrifice eligible")
	svc.apply(c_flask, run, registry, rng)
	_check(run.max_flasks == 2, "I6: max_flasks -1")
	_check(run.kindling == "flask", "I6: kindling flag flask")
	run.max_flasks = 1
	_check(not svc.is_choice_eligible(c_flask, run, registry), "I6: no double flask sacrifice")

	# 献武器：拿走锻造最深的
	var run2 := _fresh_run()
	run2.weapons = ["longsword", "dagger"]
	run2.weapon_levels = {"longsword": 3, "dagger": 1}
	var c_wpn := MapEventChoiceData.new()
	c_wpn.effect = "sacrifice_weapon"
	svc.apply(c_wpn, run2, registry, rng)
	_check(run2.weapons == ["dagger"], "I6: most-forged weapon removed")
	_check(not run2.weapon_levels.has("longsword"), "I6: weapon level removed")
	_check(run2.deck.has("sacrificed_blade"), "I6: sacrificed_blade added")
	_check(run2.kindling == "weapon", "I6: kindling flag weapon")

	# 拒绝：不留下任何标记
	var run3 := _fresh_run()
	var c_refuse := MapEventChoiceData.new()
	c_refuse.effect = "refuse_kindling"
	svc.apply(c_refuse, run3, registry, rng)
	_check(run3.kindling == "", "I6: refusal leaves kindling empty")

	# 战斗：终局之敌 −15% 最大生命
	var boss_template: Dictionary = registry.template_by_name("接肢贵族")
	_check(not boss_template.is_empty(), "I6: run boss template exists")
	var base_hp: int = int(boss_template.get("max_hp", 0))
	var run4 := _fresh_run()
	run4.kindling = "flask"
	var combat := CombatController.new(run4, registry, RandomNumberGenerator.new())
	combat.start_combat(boss_template)
	var expect_hp: int = maxi(1, int(round(float(base_hp) * 0.85)))
	_check(
		int(combat.enemies[0].max_hp) == expect_hp,
		"I6: run boss hp -15%% (%d -> %d)" % [base_hp, int(combat.enemies[0].max_hp)]
	)

	# 战斗：献瓶出伤 +10%
	var run5 := _fresh_run()
	run5.kindling = "flask"
	var combat5 := CombatController.new(run5, registry, RandomNumberGenerator.new())
	combat5.start_combat(registry.template_by_name("野狼"))
	var hp0: int = int(combat5.enemies[0].hp)
	combat5.deal_enemy_damage(10, 0, 0)
	_check(hp0 - int(combat5.enemies[0].hp) == 11, "I6: outgoing damage +10%% (10 -> 11)")

	# 强制注入：第 11 层（index 10）覆盖全部选项
	var host := FakeHost.new()
	var run6 := _fresh_run()
	host.run_state = run6
	host.registry = registry
	var flowc := RunFlowController.new(host)
	var opts: Array = [{"kind": "combat"}, {"kind": "grace"}]
	run6.floor_index = 10
	flowc._inject_kindling_event(run6, registry, opts)
	_check(opts.size() == 1 and str(opts[0].get("event_id")) == "maiden_kindling", "I6: forced kindling injection")
	var opts2: Array = [{"kind": "combat"}]
	run6.kindling = "flask"
	flowc._inject_kindling_event(run6, registry, opts2)
	_check(opts2.size() == 1 and str(opts2[0].get("kind")) == "combat", "I6: no re-injection after sacrifice")


# ── I9 杀死商人 ──────────────────────────────────────────────
func test_i9(registry: DataRegistry) -> void:
	var mg := MapGenerator.new()
	var act = registry.get_act(0)
	var run_killer := _fresh_run()
	run_killer.merchant_killed = true
	_check(mg._weight_for_kind(act, "merchant", run_killer) == 0, "I9: merchant nodes gone after kill")
	var run_normal := _fresh_run()
	_check(
		mg._weight_for_kind(act, "merchant", run_normal) == int(act.map_weight_merchant),
		"I9: merchant weight unchanged otherwise"
	)

	var ms := MerchantService.new()
	ms.load_from_registry(registry)
	var offer_ids: Array = registry.all_merchant_offer_ids()
	_check(offer_ids.size() > 0, "I9: offers exist")
	var offer = registry.get_merchant_offer(str(offer_ids[0]))
	_check(ms.effective_cost(offer, 0) == 0, "I9: free seize cost 0")
	_check(ms.effective_cost(offer, 100) == int(offer.soul_cost), "I9: normal cost intact")

	var kb = registry.get_relic("kale_bellbearing")
	_check(kb != null, "I9: bell bearing relic exists")
	if kb != null:
		_check(bool(kb.exclusive), "I9: bell bearing exclusive")


# ── I8 癫火圣约 ──────────────────────────────────────────────
func test_i8(registry: DataRegistry) -> void:
	var svc := EventService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var ev = registry.get_event("three_fingers_chapel")
	_check(ev != null, "I8: chapel event exists")

	var run := _fresh_run()
	var ch := MapEventChoiceData.new()
	ch.effect = "frenzied_flame"
	_check(svc.is_choice_eligible(ch, run, registry), "I8: eligible before accepting")
	var summary: String = svc.apply(ch, run, registry, rng)
	_check(run.frenzied_flame, "I8: frenzy flag set")
	_check(run.challenge_flags.has("frenzied_lord"), "I8: challenge flag recorded")
	var has_frenzy_card := false
	for cid in EventService.FRENZY_CARDS:
		if run.deck.has(cid):
			has_frenzy_card = true
	_check(has_frenzy_card, "I8: frenzy card granted")
	_check(not svc.is_choice_eligible(ch, run, registry), "I8: irreversible (no second accept)")

	# 每回合能量 +1
	var combat := CombatController.new(run, registry, RandomNumberGenerator.new())
	combat.start_combat(registry.template_by_name("野狼"))
	combat.start_player_turn()
	_check(combat.ember == combat.max_ember + 1, "I8: ember +1 each turn")

	# 出伤 +25%
	var hp0: int = int(combat.enemies[0].hp)
	combat.deal_enemy_damage(8, 0, 0)
	_check(hp0 - int(combat.enemies[0].hp) == 10, "I8: outgoing +25%% (8 -> 10)")

	# 受伤 +25%
	var hp1: int = run.hp
	combat.take_player_damage(8, true)
	_check(hp1 - run.hp == 10, "I8: incoming +25%% (8 -> 10)")

	# 自伤不致死
	run.hp = 3
	var step := CardEffectStep.new()
	step.kind = CardEffectStep.Kind.SELF_DAMAGE
	step.value = 6
	var resolver := CardEffectResolver.new(combat)
	resolver._apply_step(step)
	_check(run.hp == 1, "I8: self damage floor at 1 hp")

	# 赐福治疗减半
	var opt := GraceOptionData.new()
	opt.effect = "heal_percent"
	opt.effect_value = 50
	var run_a := _fresh_run()
	run_a.hp = 10
	var run_b := _fresh_run()
	run_b.hp = 10
	run_b.frenzied_flame = true
	GraceService.new().apply(opt, run_a)
	GraceService.new().apply(opt, run_b)
	_check((run_a.hp - 10) == 2 * (run_b.hp - 10), "I8: grace heal halved (36 vs 18)")

	# 奖励池注入：多轮抽取至少出现一次癫火卡
	var run_c := _fresh_run()
	run_c.frenzied_flame = true
	var saw_frenzy := false
	for i in 60:
		var rc := CombatController.new(run_c, registry, rng)
		var rewards := rc.roll_rewards(registry.get_act(0))
		for rid in rewards:
			if EventService.FRENZY_CARDS.has(rid):
				saw_frenzy = true
		if saw_frenzy:
			break
	_check(saw_frenzy, "I8: frenzy cards enter reward pool")

	# 四张癫火卡数据齐备（祷告/传说 + 自伤步骤）
	var resolver_run := _fresh_run()
	var resolver_combat := CombatController.new(resolver_run, registry, RandomNumberGenerator.new())
	var resolver2 := CardEffectResolver.new(resolver_combat)
	for cid in EventService.FRENZY_CARDS:
		var card = registry.get_card(cid)
		_check(card != null, "I8: card %s exists" % cid)
		var steps := resolver2._catalog_steps(cid)
		var has_self := false
		for st in steps:
			if int((st as CardEffectStep).kind) == int(CardEffectStep.Kind.SELF_DAMAGE):
				has_self = true
		_check(has_self, "I8: %s has self damage" % cid)


# ── I4 大卢恩朝圣 ──────────────────────────────────────────────
func test_i4(registry: DataRegistry) -> void:
	var host := FakeHost.new()
	var run := _fresh_run()
	host.run_state = run
	host.registry = registry
	var flowc := RunFlowController.new(host)

	# 授卢恩：三幕各一枚；第三幕自动激活（风味）
	run.floor_index = 3
	flowc._grant_great_rune()
	_check(run.great_runes.has("rune_margit") and str(run.great_runes["rune_margit"]) == "", "I4: margit rune inert")
	run.floor_index = 7
	flowc._grant_great_rune()
	_check(run.great_runes.has("rune_crucible") and str(run.great_runes["rune_crucible"]) == "", "I4: crucible rune inert")
	run.floor_index = 11
	flowc._grant_great_rune()
	_check(str(run.great_runes.get("rune_scion", "")) == "innate", "I4: scion rune innate")
	var count_before: int = run.great_runes.size()
	flowc._grant_great_rune()
	_check(run.great_runes.size() == count_before, "I4: no duplicate grant")

	# 神授塔注入：仅首层且仅未激活
	var opts: Array = [{"kind": "combat"}]
	run.floor_index = 4
	flowc._inject_divine_tower(run, registry, opts)
	_check(opts.size() == 2 and str(opts[1].get("kind")) == "divine_tower", "I4: tower injected floor 4")
	var opts2: Array = [{"kind": "combat"}]
	run.floor_index = 5
	flowc._inject_divine_tower(run, registry, opts2)
	_check(opts2.size() == 1, "I4: no tower on other floors")
	var opts3: Array = [{"kind": "combat"}]
	run.floor_index = 4
	run.great_runes["rune_margit"] = "rune_margit_might"
	flowc._inject_divine_tower(run, registry, opts3)
	_check(opts3.size() == 1, "I4: no tower after activation")

	# 激活形态数据：两条卢恩 × 两种形态，全部 exclusive
	var flowr := RunRewardFlow.new(host)
	_check(flowr.RUNE_ACTIVATIONS.size() == 2, "I4: two runes activatable")
	for rk in flowr.RUNE_ACTIVATIONS.keys():
		for rid in (flowr.RUNE_ACTIVATIONS[rk] as Array):
			var relic = registry.get_relic(str(rid))
			_check(relic != null, "I4: rune relic %s exists" % str(rid))
			if relic != null:
				_check(bool(relic.exclusive), "I4: %s exclusive" % str(rid))

	# 专属护符不进常规池
	var rs := RelicService.new()
	var run_b := _fresh_run()
	var pool := rs._unowned_relic_pool(run_b, registry)
	for relic in pool:
		_check(not bool(relic.exclusive), "I4: exclusive relic leaked into pool")

	# 姿态百分比卢恩：stance_percent_total 汇总
	var run_c := _fresh_run()
	run_c.relics = ["rune_crucible_stance"]
	_check(rs.stance_percent_total(run_c, registry) == 20, "I4: stance_percent sums")

	# 战斗姿态伤害 +20%
	var combat_plain := CombatController.new(_fresh_run(), registry, RandomNumberGenerator.new())
	combat_plain.start_combat(registry.template_by_name("野狼"))
	var base_stance_dmg: int = combat_plain.calculate_stance_damage(10)
	var run_d := _fresh_run()
	run_d.relics = ["rune_crucible_stance"]
	var combat_rune := CombatController.new(run_d, registry, RandomNumberGenerator.new())
	combat_rune.start_combat(registry.template_by_name("野狼"))
	var rune_stance_dmg: int = combat_rune.calculate_stance_damage(10)
	_check(
		rune_stance_dmg == int(ceil(float(base_stance_dmg) * 1.2)),
		"I4: stance dmg +20%% (%d -> %d)" % [base_stance_dmg, rune_stance_dmg]
	)

	# 恶兆之力：获得时全属性 +2
	var run_e := _fresh_run()
	var vigor_before: int = int(run_e.attrs["vigor"])
	var hp_before: int = run_e.max_hp
	rs.add_relic(run_e, registry, "rune_margit_might")
	var all_plus_two := true
	for key in run_e.attrs.keys():
		if int(run_e.attrs[key]) != vigor_before + 2:
			all_plus_two = false
	_check(all_plus_two, "I4: all attrs +2 on acquire")
	_check(run_e.max_hp == hp_before + 4, "I4: vigor hp bump (+4)")
	_check(rs.has_relic(run_e, "rune_margit_might"), "I4: rune relic added")


# ── I7 壶哥任务线 ──────────────────────────────────────────────
func test_i7(registry: DataRegistry) -> void:
	var svc := EventService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# 事件链数据
	var stage1 = registry.get_event("jar_in_hole")
	var stage2 = registry.get_event("jar_trial")
	var stage3 = registry.get_event("jar_farewell")
	_check(stage1 != null, "I7: stage1 exists")
	_check(stage2 != null and str(stage2.required_flag) == "jar_freed", "I7: stage2 gated by jar_freed")
	_check(stage3 != null and str(stage3.required_flag) == "jar_duel_won", "I7: stage3 gated by jar_duel_won")

	# set_flag 生效
	var run := _fresh_run()
	var souls_before: int = run.souls
	var ch := MapEventChoiceData.new()
	ch.effect = "gain_souls"
	ch.effect_value = 10
	ch.set_flag = "jar_freed"
	svc.apply(ch, run, registry, rng)
	_check(run.event_flags.has("jar_freed"), "I7: set_flag appends")
	_check(run.souls == souls_before + 10, "I7: effect still applies")
	var flags_before: int = run.event_flags.size()
	svc.apply(ch, run, registry, rng)
	_check(run.event_flags.size() == flags_before, "I7: flag not duplicated")

	# 切磋路由标记
	var duel_choice := MapEventChoiceData.new()
	duel_choice.effect = "duel_jar"
	_check(svc.apply(duel_choice, run, registry, rng) == EventService.DUEL_JAR, "I7: duel marker")

	# 地图门控：无旗标时 jar_trial 绝不出现；有旗标时可能出现
	var mg := MapGenerator.new()
	var run_gated := _fresh_run()
	run_gated.floor_index = 4  # 第二幕首层
	for i in 200:
		for opt in mg.options_for_floor(run_gated, registry, rng):
			_check(str(opt.get("event_id")) != "jar_trial", "I7: gated event leaked")
	run_gated.event_flags.append("jar_freed")
	var saw_trial := false
	for i in 400:
		for opt in mg.options_for_floor(run_gated, registry, rng):
			if str(opt.get("event_id")) == "jar_trial":
				saw_trial = true
		if saw_trial:
			break
	_check(saw_trial, "I7: jar_trial appears once un-gated")

	# 决斗对手：duel_only，不进遭遇池
	var jar_template: Dictionary = registry.template_by_name("战壶亚历山大")
	_check(not jar_template.is_empty(), "I7: jar template exists")
	_check(bool(jar_template.get("duel_only", false)), "I7: jar duel_only")
	for i in 100:
		var picked: Dictionary = registry.pick_enemy(rng, true, false)
		_check(str(picked.get("name")) != "战壶亚历山大", "I7: jar leaked into elite pool")

	# 赠礼：壶之碎片护符 + 巨壶之拳卡
	var ps = registry.get_relic("pot_shard")
	_check(ps != null and bool(ps.exclusive), "I7: pot_shard exclusive")
	if ps != null:
		_check(str(ps.hook) == "combat_start_block" and int(ps.value) == 3, "I7: pot_shard +3 block")
	var fist = registry.get_card("giant_jar_fist")
	_check(fist != null, "I7: giant_jar_fist card exists")


# ── 存档往返：新增旗标全部持久化 ──────────────────────────────
func test_save_roundtrip() -> void:
	var run := _fresh_run()
	run.kindling = "flask"
	run.frenzied_flame = true
	run.merchant_killed = true
	run.great_runes = {"rune_margit": "rune_margit_might", "rune_crucible": ""}
	run.event_flags = ["jar_freed", "jar_duel_won"]

	var data := RunSaveService.run_to_dict(run)
	var loaded := RunState.new()
	RunSaveService.run_from_dict(loaded, data)

	_check(loaded.kindling == "flask", "save: kindling")
	_check(loaded.frenzied_flame, "save: frenzied_flame")
	_check(loaded.merchant_killed, "save: merchant_killed")
	_check(loaded.great_runes.size() == 2, "save: great_runes count")
	_check(str(loaded.great_runes.get("rune_margit")) == "rune_margit_might", "save: activated rune value")
	_check(loaded.great_runes.has("rune_crucible") and str(loaded.great_runes["rune_crucible"]) == "", "save: inert rune kept")
	_check(loaded.event_flags.size() == 2 and loaded.event_flags.has("jar_freed"), "save: event_flags")
