extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CardEffectResolver = preload("res://scripts/core/CardEffectResolver.gd")

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 1) AOE 卡牌（腐败吐息 → 全体腐败；辉石流星 → 全体伤害）
	var combat := CombatController.new(run_state, registry, rng)
	var group := registry.resolve_group("wolf_pack")
	combat.start_combat(group)
	var card := registry.get_card("glintstone_stars")
	var resolver := CardEffectResolver.new(combat)
	var before_hp: int = int(combat.enemies[0].hp) + int(combat.enemies[1].hp) + int(combat.enemies[2].hp)
	# 打出 AOE 卡（模拟 resolver 直接结算）
	# glintstone_stars 现在 = 2 次 DAMAGE_ALL 3 伤害
	var hand_size_before: int = run_state.hand.size()
	# 直接把卡放入手牌打出
	run_state.hand.append("glintstone_stars")
	var idx := run_state.hand.size() - 1
	combat.ember = 3
	combat.play_card(idx)
	var after_hp: int = int(combat.enemies[0].hp) + int(combat.enemies[1].hp) + int(combat.enemies[2].hp)
	var dmg: int = before_hp - after_hp
	print("AOE damage dealt to 3 wolves: %d (expected ~12: 2 hits x 3 dmg x... actually per-enemy 2x3=6 each)" % dmg)
	if dmg <= 0:
		_fail("AOE card dealt no damage")
		return
	print("AOE card OK (total %d dmg)" % dmg)

	# 2) 精英群：elite 标记传播 → elite_reward
	var combat2 := CombatController.new(run_state, registry, rng)
	var elite_group := registry.resolve_group("kaguth_raiders", true)
	if not bool(elite_group.get("elite", false)):
		_fail("resolve_group as_elite should set elite=true")
		return
	combat2.start_combat(elite_group)
	if not bool(combat2.enemies[0].get("elite", false)):
		_fail("elite flag should propagate to members")
		return
	print("elite group flag propagation OK")

	# 3) 击杀全部精英群 → elite_reward
	var ended: Array[String] = [""]
	combat2.combat_ended.connect(func(kind: String) -> void: ended[0] = kind)
	for i in range(combat2.enemies.size()):
		combat2.deal_enemy_damage(9999, 9999, i)
	combat2.check_combat_end()
	if ended[0] != "elite_reward":
		_fail("elite group should end with elite_reward, got '%s'" % ended[0])
		return
	print("elite group reward path OK (%s)" % ended[0])

	print("aoe_elite_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
