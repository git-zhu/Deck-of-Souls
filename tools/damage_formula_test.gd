extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond")
	run.reset_for_origin(origin, 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run, registry, rng)

	var longsword := registry.get_card("longsword")  # 物理武器 7 伤
	# vagabond: strength 14, dexterity 13, mind 9, faith 9

	# 1) 基础伤害：7 + 力量14 + 0.5*灵巧13(6) = 27，武器攻击加成 3（长剑1+戟2） = 30，倍率 1.0
	var dmg := combat.calculate_card_damage(longsword, 7)
	if dmg != 30:
		_fail("base damage wrong: expected 30, got %d" % dmg)
		return
	print("base damage OK:", dmg)

	# 2) 属性加成后升级力量（+5）
	run.souls = 500
	for i in range(5):
		run.attrs["strength"] = int(run.attrs["strength"]) + 1
		run.attr_levels["strength"] = int(run.attr_levels["strength"]) + 1
	dmg = combat.calculate_card_damage(longsword, 7)
	if dmg != 35:
		_fail("strength +5 should give 35, got %d" % dmg)
		return
	print("strength scaling OK:", dmg)

	# 3) 武器等级倍率：+1 级 → ×1.1（35*1.1=38.5 → 39）
	var weapon := registry.get_weapon("longsword_w")
	if weapon == null:
		_fail("longsword_w missing")
		return
	weapon.level = 1
	dmg = combat.calculate_card_damage(longsword, 7)
	if dmg != 39:
		_fail("weapon lv1 should give 35*1.1=39, got %d" % dmg)
		return
	print("weapon level multiplier OK:", dmg)

	print("damage_formula_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
