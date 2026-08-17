extends SceneTree
## 阶段 C：地图碎片 / 死亡回响 / 事件强化 / 先手压制 / 誓言挑战

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const MapScreenView = preload("res://scripts/ui/MapScreenView.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")
const EndScreenView = preload("res://scripts/ui/EndScreenView.gd")


func _initialize() -> void:
	# 清理跨局档案，保证测试独立
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	var registry := DataRegistry.new()
	registry.load_all()
	var rng := RandomNumberGenerator.new()

	# ── C1 地图碎片：预览确定性 + 购买 ──
	rng.seed = 501
	var run_m := RunState.new()
	run_m.reset_for_origin(registry.get_origin("vagabond"), 501)
	var map_gen := MapGenerator.new()
	var r1 := RandomNumberGenerator.new()
	r1.seed = run_m.run_seed + (run_m.floor_index + 1) * 7919
	var preview_a: Array = map_gen.options_for_floor(run_m, registry, r1)
	var r2 := RandomNumberGenerator.new()
	r2.seed = run_m.run_seed + (run_m.floor_index + 1) * 7919
	var preview_b: Array = map_gen.options_for_floor(run_m, registry, r2)
	if preview_a.is_empty() or preview_a.size() != preview_b.size():
		_fail("地图碎片预览应确定且非空")
		return
	for i in range(preview_a.size()):
		if str((preview_a[i] as Dictionary).get("title")) != str((preview_b[i] as Dictionary).get("title")):
			_fail("地图碎片预览应可复现")
			return
	run_m.next_floor_preview = preview_a
	run_m.souls = 100
	var frag_called := [false]
	var map_ui := MapScreenView.build(null, run_m, preview_a, func(_opt): pass, func(): frag_called[0] = true)
	var frag_btn := _find_button_with(map_ui, "地图碎片")
	if frag_btn == null or frag_btn.disabled:
		_fail("卢恩足够时应可购买地图碎片")
		return
	frag_btn.pressed.emit()
	if run_m.souls != 50 or not run_m.map_fragment_revealed or not frag_called[0]:
		_fail("购买地图碎片应扣 50 卢恩并触发刷新")
		return
	print("C1 map fragment OK")

	# ── C2 死亡回响（死亡卢恩的一半凝为回响）──
	ProfileService.record_death(124, 3, "vagabond")
	var profile := ProfileService.load_profile()
	if int(profile.get("echo", {}).get("souls", 0)) != 62 or int(profile.get("echo", {}).get("floor", -1)) != 3:
		_fail("死亡应写入回响（62 卢恩 @ 第 3 层）")
		return
	if registry.get_event("echo_of_last_run") == null:
		_fail("echo_of_last_run 事件缺失")
		return
	var event_service := EventService.new()
	var run_e := RunState.new()
	run_e.reset_for_origin(registry.get_origin("vagabond"), 502)
	run_e.souls = 0
	var echo_event := registry.get_event("echo_of_last_run")
	var claim_choice = echo_event.choices[0]
	if not event_service.is_choice_eligible(claim_choice, run_e, registry):
		_fail("有回响时应可夺回")
		return
	var claim_msg: String = event_service.apply(claim_choice, run_e, registry, rng)
	if run_e.souls != 62 or not claim_msg.contains("62"):
		_fail("夺回回响应得 62 卢恩，实际 %d" % run_e.souls)
		return
	# 再次死亡 → 献给赐福换记忆（200/2=100 → 5 记忆）
	ProfileService.record_death(200, 4, "vagabond")
	var offer_choice = echo_event.choices[1]
	var mem_before: int = int(ProfileService.load_profile().get("memory", 0))
	event_service.apply(offer_choice, run_e, registry, rng)
	var mem_after: int = int(ProfileService.load_profile().get("memory", 0))
	if mem_after != mem_before + 5:
		_fail("200 卢恩死亡回响应换 5 记忆，实际 +%d" % (mem_after - mem_before))
		return
	print("C2 death echo OK")

	# ── C3 事件强化 ──
	# 赌徒：赢 → +2×赌注；输 → 赌注消失
	var gamble := registry.get_event("limgrave_gambler")
	if gamble == null:
		_fail("limgrave_gambler 事件缺失")
		return
	var run_g := RunState.new()
	run_g.reset_for_origin(registry.get_origin("vagabond"), 503)
	run_g.souls = 500
	var bet_choice = gamble.choices[0]
	var rg_win := RandomNumberGenerator.new()
	rg_win.randf()  # 预热
	var souls_before: int = run_g.souls
	# 用确定性 rng：连试两种种子覆盖胜负两分支
	var saw_win := false
	var saw_lose := false
	for s in [7, 8, 9, 10, 11, 12]:
		var rt := RandomNumberGenerator.new()
		rt.seed = s
		var run_t := RunState.new()
		run_t.reset_for_origin(registry.get_origin("vagabond"), s)
		run_t.souls = 500
		event_service.apply(bet_choice, run_t, registry, rt)
		if run_t.souls == 500 - 50 + 100:
			saw_win = true
		elif run_t.souls == 500 - 50:
			saw_lose = true
	if not (saw_win and saw_lose):
		_fail("赌徒事件应覆盖胜负两分支")
		return
	# 诅咒祭坛：得命定之死、失 1 瓶位
	var altar := registry.get_event("stormveil_cursed_altar")
	var run_c := RunState.new()
	run_c.reset_for_origin(registry.get_origin("vagabond"), 504)
	var flasks_before: int = run_c.max_flasks
	var deck_before: int = run_c.deck.size()
	event_service.apply(altar.choices[0], run_c, registry, rng)
	if run_c.deck.size() != deck_before + 1 or run_c.max_flasks != flasks_before - 1:
		_fail("诅咒祭坛应加牌并封 1 瓶位")
		return
	# 赌卡：50% 得稀有牌 / 50% 损 10% 最大生命
	var chest := registry.get_event("liurnia_lake_chest")
	var saw_card := false
	var saw_loss := false
	for s in [21, 22, 23, 24, 25, 26, 27, 28]:
		var rt := RandomNumberGenerator.new()
		rt.seed = s
		var run_t := RunState.new()
		run_t.reset_for_origin(registry.get_origin("vagabond"), s)
		var hp_before: int = run_t.max_hp
		var deck_sz: int = run_t.deck.size()
		event_service.apply(chest.choices[0], run_t, registry, rt)
		if run_t.deck.size() == deck_sz + 1:
			saw_card = true
		elif run_t.max_hp == maxi(10, hp_before - maxi(2, int(ceil(hp_before * 0.10)))):
			saw_loss = true
	if not (saw_card and saw_loss):
		_fail("赌卡事件应覆盖得牌与受损两分支")
		return
	print("C3 event gambles OK")

	# ── C4 先手压制 ──
	rng.seed = 601
	var run_a := RunState.new()
	run_a.reset_for_origin(registry.get_origin("wretch"), 601)
	var combat := CombatController.new(run_a, registry, rng)
	combat.start_combat(registry.template_by_name("野狼"))
	combat.run.hand = ["great_knife"]
	combat.ember = 3
	combat.play_card(0)
	if combat.first_turn_attacks != 1:
		_fail("第 1 回合攻击卡应计数，实际 %d" % combat.first_turn_attacks)
		return
	var combat2 := CombatController.new(run_a, registry, rng)
	combat2.start_combat(registry.template_by_name("野狼"))
	combat2.first_turn_attacks = 3
	combat2.end_player_turn()
	if int(combat2.enemies[0].stance_now) != 5:
		_fail("先手压制应使野狼姿态减半（9→5），实际 %d" % int(combat2.enemies[0].stance_now))
		return
	# Boss 战不触发
	var combat3 := CombatController.new(run_a, registry, rng)
	combat3.start_combat(registry.template_by_name("恶兆妖鬼玛尔基特"))
	if combat3._is_normal_encounter():
		_fail("玛尔基特应为非普通遭遇")
		return
	var margit_stance: int = int(combat3.enemies[0].stance_now)
	combat3.first_turn_attacks = 3
	combat3.end_player_turn()
	if int(combat3.enemies[0].stance_now) != margit_stance:
		_fail("Boss 战不应触发先手压制")
		return
	print("C4 ambush pressure OK")

	# ── C5 誓言挑战 ──
	rng.seed = 701
	var run_s := RunState.new()
	run_s.reset_for_origin(registry.get_origin("wretch"), 701)
	run_s.challenge_flags.append("strong_foe")
	var combat4 := CombatController.new(run_s, registry, rng)
	combat4.start_combat(registry.template_by_name("野狼"))
	if int(combat4.enemies[0].max_hp) != 45:
		_fail("强敌挑战野狼应为 45 HP，实际 %d" % int(combat4.enemies[0].max_hp))
		return
	var victory_ui := EndScreenView.build_victory(100, 10, func(): pass, ["no_flask"])
	if not _label_contains(victory_ui, "誓言已践"):
		_fail("胜利界面应展示誓言达成")
		return
	print("C5 vow challenges OK")

	# 清理档案
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	print("souls_features_test: OK")
	quit()


func _find_button_with(root: Control, needle: String) -> Button:
	if root is Button and (root as Button).text.contains(needle):
		return root
	for child in root.get_children():
		if child is Control:
			var found := _find_button_with(child, needle)
			if found != null:
				return found
	return null


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
