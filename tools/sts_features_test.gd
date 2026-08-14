extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, 42)
	# 给玩家一些状态验证图标化
	run_state.player_rot = 3
	run_state.player_bleed = 4
	run_state.player_vulnerable = 2
	run_state.player_strength = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)
	var template := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	combat.start_combat(template)

	var refs := CombatHudView.build(
		run_state, combat, registry, "日志",
		110.0, 142.0,
		func(i: int) -> void: combat.play_card(i),
		combat.use_flask, combat.end_player_turn
	)
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.add_child(refs.root)
	for i in 5:
		await process_frame

	# 1) 回合标签
	if not _tree_has_label_prefix(refs.root, "回合"):
		_fail("missing turn label")
		return
	print("turn label OK")

	# 2) 能量球（大数字）
	var orb_found := _has_energy_orb(refs.root)
	if not orb_found:
		_fail("missing energy orb")
		return
	print("energy orb OK")

	# 3) 状态图标 chip 机制（status_chip 支持图标参数；护甲 chip 应含 TextureRect）
	var chip_icons := _count_small_texture_rects(refs.root)
	if chip_icons < 1:
		_fail("status chips should contain small TextureRect icons, got %d" % chip_icons)
		return
	print("status chip icons OK (%d small TextureRects)" % chip_icons)

	# 4) 卡牌悬停放大（DragCard 有 z_index 提升逻辑）
	var cards := _find_drag_cards(refs.hand_row)
	if cards.size() == 0:
		_fail("no hand cards")
		return
	var c: DragCard = cards[0]
	c.mouse_entered.emit()
	await create_timer(0.25).timeout
	if c.scale.x < 1.3:
		_fail("hover lift scale not applied, got %.2f" % c.scale.x)
		return
	if c.z_index < 10:
		_fail("hover lift z_index not raised")
		return
	c.mouse_exited.emit()
	await create_timer(0.25).timeout
	print("card hover lift OK (scale %.2f -> restoring)" % c.scale.x)

	refs.root.queue_free()
	for i in 5:
		await process_frame
	print("sts_features_test: OK")
	quit()

func _tree_has_label_prefix(node: Node, prefix: String) -> bool:
	if node is Label and (node as Label).text.begins_with(prefix):
		return true
	for child in node.get_children():
		if _tree_has_label_prefix(child, prefix):
			return true
	return false

func _has_energy_orb(node: Node) -> bool:
	# 能量球：PanelContainer 内有大字号数字 + "/ N"
	for child in node.get_children():
		var c := child as Control
		if c != null and c.size.x >= 40 and c.size.x <= 80 and c.size.y >= 40 and c.size.y <= 80:
			return true
		if _has_energy_orb(child):
			return true
	return false

func _count_small_texture_rects(node: Node) -> int:
	# 计数 ≤20px 的 TextureRect（状态 chip 图标 / 能量图标等）
	var count := 0
	if node is TextureRect:
		var tr := node as TextureRect
		if tr.size.x > 0.0 and tr.size.x <= 22.0 and tr.size.y > 0.0 and tr.size.y <= 22.0:
			count += 1
	for child in node.get_children():
		count += _count_small_texture_rects(child)
	return count

func _find_drag_cards(node: Node) -> Array:
	var out: Array = []
	if node is DragCard:
		out.append(node)
	for child in node.get_children():
		var found: Array = _find_drag_cards(child)
		for c in found:
			out.append(c)
	return out

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
