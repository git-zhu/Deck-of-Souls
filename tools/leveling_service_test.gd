extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const LevelingService = preload("res://scripts/core/LevelingService.gd")

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond")
	run.reset_for_origin(origin, 42)

	# 1) 出身属性加载
	if run.attr("vigor") != 15 or run.attr("strength") != 14:
		_fail("vagabond attrs wrong: %s" % str(run.attrs))
		return
	print("origin attrs OK:", run.attrs)

	# 2) 升级成本曲线
	var costs: Array = []
	for i in range(12):
		costs.append(LevelingService.attr_upgrade_cost(i))
	print("cost curve:", costs)
	# 曲线：0:20 1:30 2:40 3:50 4:60 5:60 6:80 7:100 8:120 9:140 10:160 11:200
	if costs[0] != 20 or costs[4] != 60 or costs[6] != 80 or costs[11] != 200:
		_fail("cost curve wrong")
		return
	print("cost curve OK")

	# 3) 属性升级（成本按加点次数：首次 20 卢恩）
	run.souls = 100
	var max_hp_before: int = run.max_hp
	var r1: Dictionary = LevelingService.apply_attr_upgrade(run, "vigor")
	if not bool(r1.get("ok", false)):
		_fail("vigor upgrade should succeed: %s" % str(r1))
		return
	if run.attr("vigor") != 16 or run.max_hp != max_hp_before + 2 or run.attr_upgrade_level("vigor") != 1:
		_fail("vigor upgrade effects wrong")
		return
	print("vigor upgrade OK (max_hp %d -> %d, souls %d)" % [max_hp_before, run.max_hp, run.souls])

	# 4) 卢恩不足拒绝（第三次升级要 40 卢恩，只剩 80-20=80 够第2次，第3次40也够...测试设低）
	run.souls = 5
	var r2: Dictionary = LevelingService.apply_attr_upgrade(run, "strength")
	if bool(r2.get("ok", false)):
		_fail("should fail with low souls")
		return
	print("low souls rejected OK")

	# 5) 锻造石升级成本文本
	var text := LevelingService.weapon_upgrade_cost_text(3)
	print("weapon +3 cost:", text)
	if not text.contains("2级锻造石"):
		_fail("weapon cost text wrong")
		return
	print("weapon cost text OK")

	print("leveling_service_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
