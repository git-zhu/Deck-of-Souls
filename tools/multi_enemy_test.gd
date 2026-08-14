extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 1) 群怪模板（3 只野狼）
	var group := registry.resolve_group("wolf_pack")
	if group.is_empty() or int(group.get("enemies", []).size()) != 3:
		_fail("wolf_pack should resolve to 3 enemies")
		return
	var combat := CombatController.new(run_state, registry, rng)
	combat.start_combat(group)
	if combat.enemies.size() != 3:
		_fail("combat should have 3 enemies, got %d" % combat.enemies.size())
		return
	if combat.alive_count() != 3:
		_fail("3 enemies should be alive")
		return
	print("multi-enemy start OK: %d enemies" % combat.enemies.size())

	# 2) 目标选择
	combat.set_target(1)
	if combat.target_index != 1:
		_fail("target_index not set")
		return
	print("target selection OK (idx=1)")

	# 3) 对选中目标造成伤害（击杀目标1）
	combat.deal_enemy_damage(999, 999)
	if int(combat.enemies[1].hp) != 0:
		_fail("target 1 should be dead")
		return
	if combat.alive_count() != 2:
		_fail("expected 2 alive after killing one, got %d" % combat.alive_count())
		return
	print("targeted damage OK (1 dead, %d alive)" % combat.alive_count())

	# 4) 击杀全部 → 战斗结束
	combat.deal_enemy_damage(999, 999, 0)
	combat.deal_enemy_damage(999, 999, 2)
	combat.check_combat_end()
	if not combat.combat_over:
		_fail("combat should be over when all dead")
		return
	print("all-dead combat end OK")

	# 5) 单敌人兼容
	var single := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	var combat2 := CombatController.new(run_state, registry, rng)
	combat2.start_combat(single)
	if combat2.enemies.size() != 1:
		_fail("single enemy should have 1 in enemies array")
		return
	if combat2.enemy.get("name", "") != "葛瑞克士兵":
		_fail("enemy getter should return the single enemy")
		return
	print("single-enemy compat OK")

	print("multi_enemy_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
