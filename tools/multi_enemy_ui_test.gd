extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const DropZone = preload("res://scripts/ui/DropZone.gd")

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
	var group := registry.resolve_group("kaguth_raiders")  # 亚人首领 + 2 亚人
	combat.start_combat(group)

	# 记录投放的目标
	var dropped_targets: Array = []
	var refs := CombatHudView.build(
		run_state, combat, registry, "日志",
		110.0, 142.0,
		func(i: int, target: String) -> void:
			dropped_targets.append(target)
			combat.set_target(int(target.trim_prefix("enemy_")) if target.begins_with("enemy_") else combat.target_index)
			combat.play_card(i),
		combat.use_flask, combat.end_player_turn
	)
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.add_child(refs.root)
	for i in 5:
		await process_frame

	# 1) 多敌人 HUD：3 个敌人面板
	var enemy_panels := _count_enemy_huds(refs.root)
	print("enemy HUD panels found:", enemy_panels)
	if enemy_panels < 3:
		_fail("expected >= 3 enemy HUD panels, got %d" % enemy_panels)
		return
	print("multi-enemy HUD OK (%d panels)" % enemy_panels)

	# 2) DropZone 数量 = 敌人数（每个敌人一个目标区）
	var zones := _count_drop_zones(refs.root)
	if zones < 3:
		_fail("expected >= 3 DropZones, got %d" % zones)
		return
	print("multi-enemy DropZones OK (%d)" % zones)

	# 3) 拖到敌人 2 → 指定目标打出
	var target2_zone := _find_zone_by_target(refs.root, "enemy_2")
	if target2_zone == null:
		_fail("no DropZone for enemy_2")
		return
	var before := run_state.hand.size()
	target2_zone._drop_data(Vector2.ZERO, {"card_index": 0, "target_id": "enemy_2"})
	if run_state.hand.size() != before - 1:
		_fail("drop to enemy_2 did not play card")
		return
	if not dropped_targets.has("enemy_2"):
		_fail("target enemy_2 not forwarded, got %s" % str(dropped_targets))
		return
	if combat.target_index != 2:
		_fail("combat target should be 2 after drop")
		return
	print("drop-to-specific-enemy OK (target=enemy_2)")

	# 4) 结束回合：敌人轮流行动
	var hp_before: int = run_state.hp
	combat.end_player_turn()
	if run_state.hp < hp_before:
		print("enemy turns dealt damage (hp %d -> %d)" % [hp_before, run_state.hp])
	else:
		print("enemy turns (no damage this round)")

	refs.root.queue_free()
	for i in 5:
		await process_frame
	print("multi_enemy_ui_test: OK")
	quit()

func _count_enemy_huds(node: Node) -> int:
	var count := 0
	if node is PanelContainer and node.size.x >= 150 and node.size.y >= 50:
		count += 1
	for child in node.get_children():
		count += _count_enemy_huds(child)
	return count

func _count_drop_zones(node: Node) -> int:
	var count := 0
	if node is DropZone:
		count += 1
	for child in node.get_children():
		count += _count_drop_zones(child)
	return count

func _find_zone_by_target(node: Node, target: String) -> DropZone:
	if node is DropZone:
		var z := node as DropZone
		if z.target_id == target:
			return z
	for child in node.get_children():
		var found := _find_zone_by_target(child, target)
		if found != null:
			return found
	return null

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
