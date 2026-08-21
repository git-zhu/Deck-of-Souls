extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)
	var group := registry.resolve_group("kaguth_raiders")
	combat.start_combat(group)

	# 模拟受伤后的重新渲染：prev_hp > cur_hp 触发重击震动
	var prev_hp := {"player": run_state.hp + 20}
	for i in range(combat.enemies.size()):
		var enemy: Dictionary = combat.enemies[i]
		prev_hp["enemy_%d" % i] = enemy.hp + 12

	var refs := CombatHudView.build(
		run_state, combat, registry, "日志",
		110.0, 142.0,
		func(_i, _t): pass,
		combat.use_flask, combat.end_player_turn,
		prev_hp
	)

	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.add_child(refs.root)

	# 等待进入树 + process_frame + 震动完成
	for i in 30:
		await process_frame

	# 收集敌人 wrapper 的最终位置
	var positions: Array[float] = []
	for eid in refs.enemy_panels:
		var panel: PanelContainer = refs.enemy_panels[eid]
		if panel == null or not panel.has_meta("_shake_wrapper"):
			continue
		var wrapper: Control = panel.get_meta("_shake_wrapper") as Control
		positions.append(wrapper.position.x)
		print("enemy %s wrapper pos=%s size=%s" % [eid, str(wrapper.position), str(wrapper.size)])

	if positions.size() < 3:
		_fail("expected 3 enemy wrappers, got %d" % positions.size())
		return

	# 检查是否重叠：任意两个面板 x 差值应大于 10
	positions.sort()
	for i in range(1, positions.size()):
		var diff := positions[i] - positions[i - 1]
		print("enemy x diff: %f" % diff)
		if diff < 10.0:
			_fail("enemy panels overlap: diff=%f" % diff)
			return

	# 检查玩家面板位置是否合理
	if refs.player_panel != null and refs.player_panel.has_meta("_shake_wrapper"):
		var pw: Control = refs.player_panel.get_meta("_shake_wrapper") as Control
		print("player wrapper pos=%s" % str(pw.position))
		if pw.position.x < 0 or pw.position.y < 0:
			_fail("player wrapper has negative position: %s" % str(pw.position))
			return

	print("panel_overlap_test: OK")
	quit(0)

func _fail(msg: String) -> void:
	push_error(msg)
	print("panel_overlap_test: FAILED - " + msg)
	quit(1)
