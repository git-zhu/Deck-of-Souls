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

	var cards := _find_drag_cards(refs.hand_row)
	if cards.is_empty():
		_fail("no DragCard")
		return
	var c: DragCard = cards[0]

	# 检查所有子节点的 mouse_filter 是否为 IGNORE（统一 hitbox；根 Button 本身应为 STOP）
	var offenders := _find_stop_filters(c, true)
	if not offenders.is_empty():
		_fail("card children with MOUSE_FILTER_STOP: %s" % str(offenders))
		return
	print("all card children mouse_filter=IGNORE OK (root Button STOP expected)")

	# 悬停触发（整卡统一）
	c.mouse_entered.emit()
	await create_timer(0.2).timeout
	if c.scale.x < 1.2:
		_fail("hover not triggered")
		return
	print("hover lift OK (scale=%.2f)" % c.scale.x)
	c.mouse_exited.emit()
	await create_timer(0.2).timeout

	# 点击出牌仍正常
	var before: int = run_state.hand.size()
	c.emit_signal("pressed")
	await process_frame
	if run_state.hand.size() != before - 1:
		_fail("click-to-play broken")
		return
	print("click-to-play OK")

	refs.root.queue_free()
	for i in 5:
		await process_frame
	print("hitbox_test: OK")
	quit()

func _find_stop_filters(node: Node, skip_root: bool) -> Array:
	var out: Array = []
	if node is Control:
		var c := node as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not skip_root:
			out.append("%s/%s" % [c.name, c.get_class()])
	for child in node.get_children():
		var found: Array = _find_stop_filters(child, false)
		for f in found:
			out.append(f)
	return out

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
