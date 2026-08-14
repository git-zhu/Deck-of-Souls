extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const LevelingService = preload("res://scripts/core/LevelingService.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond")
	run.reset_for_origin(origin, 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run, registry, rng)

	# 1) 商人购买锻造石
	var merchant := MerchantService.new()
	merchant.load_from_registry(registry)
	run.souls = 300
	var offer1 := registry.get_merchant_offer("smithing_stone_1")
	var r1: Dictionary = merchant.purchase(offer1, run, registry, rng)
	if not bool(r1.get("ok", false)):
		_fail("buy smithing stone 1 failed: %s" % str(r1))
		return
	if run.smithing_stones[0] != 1:
		_fail("smithing stone 1 not added")
		return
	print("merchant smithing stone OK:", run.smithing_stones)

	# 2) 给武器升级资源（2 颗 1 级石）
	run.smithing_stones[0] += 1
	var weapon := registry.get_weapon("longsword_w")
	if weapon == null:
		_fail("longsword_w missing")
		return
	if not LevelingService.weapon_can_afford(run, weapon.level):
		_fail("should afford first upgrade")
		return
	var up: Dictionary = LevelingService.apply_weapon_upgrade(run, weapon.level)
	if not bool(up.get("ok", false)):
		_fail("weapon upgrade failed: %s" % str(up))
		return
	weapon.level += 1
	print("weapon upgrade OK: +%d, stones now %s" % [weapon.level, str(run.smithing_stones)])

	# 3) 升级后伤害提升
	var card := registry.get_card("longsword")
	var dmg_before: int = combat.calculate_card_damage(card, 7)  # 武器 lv1
	# 再升一级到 lv2
	run.smithing_stones[0] += 3
	if LevelingService.weapon_can_afford(run, weapon.level):
		var up2: Dictionary = LevelingService.apply_weapon_upgrade(run, weapon.level)
		if bool(up2.get("ok", false)):
			weapon.level += 1
	var dmg_after: int = combat.calculate_card_damage(card, 7)
	if dmg_after <= dmg_before:
		_fail("weapon level should increase damage: %d -> %d" % [dmg_before, dmg_after])
		return
	print("weapon level damage scaling OK: %d -> %d (lv %d)" % [dmg_before, dmg_after, weapon.level])

	# 4) 锻造石掉落（战斗奖励）
	var group := registry.resolve_group("wolf_pack")
	var combat2 := CombatController.new(run, registry, rng)
	combat2.start_combat(group)
	var stones_before: int = run.smithing_stones[0]
	for i in range(combat2.enemies.size()):
		combat2.deal_enemy_damage(9999, 9999, i)
	# 掉落是概率性的，只验证代码不崩溃
	print("post-combat stones:", run.smithing_stones, " (before:", stones_before, ")")

	print("smithing_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
