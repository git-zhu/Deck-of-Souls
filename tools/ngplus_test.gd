extends SceneTree
## A3 NG+ 与誓约：档案解锁 / 敌人缩放 / 卢恩加成 / 誓约修饰器

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")


func _initialize() -> void:
	# 清理档案，保证测试独立
	_delete_profile()

	# 1) 胜利解锁 NG+1 与誓约 1
	var p := ProfileService.record_victory(0, 0, [])
	if int(p.get("victories", 0)) != 1:
		_fail("victories 应为 1")
		return
	if int(p.get("max_ng_unlocked", 0)) != 1 or int(p.get("max_vow_unlocked", 0)) != 1:
		_fail("首胜应解锁 NG+1 与誓约 1")
		return
	var p2 := ProfileService.load_profile()
	if int(p2.get("max_ng_unlocked", -1)) != 1:
		_fail("档案持久化失败")
		return
	print("profile unlock OK")

	# 2) NG+ 敌人 HP 缩放（狼 30 × 1.25 = 38）
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	run_state.reset_for_origin(registry.get_origin("vagabond"), 42)
	run_state.ng_plus = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)
	combat.start_combat(registry.template_by_name("野狼"))
	var wolf_hp: int = int(combat.enemies[0].max_hp)
	if wolf_hp != 38:
		_fail("NG+ 狼 HP 应为 38，实际 %d" % wolf_hp)
		return
	print("ng hp scaling OK")

	# 3) 敌人伤害倍率（NG+1=1.15；誓约Ⅲ 再 +0.10）
	if absf(combat.enemy_damage_multiplier() - 1.15) > 0.001:
		_fail("NG+1 伤害倍率应为 1.15")
		return
	run_state.vow_level = 3
	if absf(combat.enemy_damage_multiplier() - 1.25) > 0.001:
		_fail("NG+1+誓约Ⅲ 伤害倍率应为 1.25")
		return
	print("enemy damage mult OK")

	# 4) NG+ 卢恩加成（狼 12 × 1.3 = 16）
	run_state.vow_level = 0
	run_state.souls = 0
	combat.deal_enemy_damage(999, 0)
	if run_state.souls != 16:
		_fail("NG+ 狼卢恩应为 16，实际 %d" % run_state.souls)
		return
	print("ng souls OK")

	# 5) 誓约Ⅰ：破损的瓶（初始瓶 −1）
	var run2 := RunState.new()
	run2.reset_for_origin(registry.get_origin("vagabond"), 7)
	run2.vow_level = 1
	var flasks_before: int = run2.max_flasks
	ProfileService.apply_vow_start(run2)
	if run2.max_flasks != flasks_before - 1 or run2.flasks != run2.max_flasks:
		_fail("誓约Ⅰ应使初始瓶 −1")
		return
	print("vow1 flask OK")

	# 6) 誓约Ⅱ：无恩之地（赐福休憩治疗减半）
	var grace := GraceService.new()
	grace.load_from_registry(registry)
	var rest := registry.get_grace_option("rest")
	if rest == null:
		_fail("rest 赐福选项缺失")
		return
	var run3 := RunState.new()
	run3.reset_for_origin(registry.get_origin("vagabond"), 7)
	run3.max_hp = 100
	run3.hp = 10
	grace.apply(rest, run3)
	var heal_normal: int = run3.hp - 10
	var run4 := RunState.new()
	run4.reset_for_origin(registry.get_origin("vagabond"), 7)
	run4.max_hp = 100
	run4.hp = 10
	run4.vow_level = 2
	grace.apply(rest, run4)
	var heal_vowed: int = run4.hp - 10
	if heal_vowed != maxi(1, heal_normal / 2):
		_fail("誓约Ⅱ治疗应减半：%d vs %d" % [heal_vowed, heal_normal])
		return
	print("vow2 grace OK")

	# 7) reset_for_origin 清零周目/誓约
	run_state.ng_plus = 3
	run_state.vow_level = 2
	run_state.reset_for_origin(registry.get_origin("samurai"), 1)
	if run_state.ng_plus != 0 or run_state.vow_level != 0:
		_fail("新局应清零周目/誓约")
		return
	print("reset OK")

	_delete_profile()
	print("ngplus_test: OK")
	quit()


func _delete_profile() -> void:
	if FileAccess.file_exists(ProfileService.PROFILE_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("profile.json")


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
