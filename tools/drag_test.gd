extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")
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
	var template := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	combat.start_combat(template)

	# on_play_card = 真实出牌（Main._play_card 的逻辑）
	var refs := CombatHudView.build(
		run_state, combat, registry, "日志",
		110.0, 142.0,
		func(i: int, _target: String = "") -> void: combat.play_card(i),
		combat.use_flask, combat.end_player_turn
	)
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.add_child(refs.root)
	for i in 5:
		await process_frame

	var cards: Array = _find_drag_cards(refs.hand_row)
	if cards.is_empty():
		_fail("no DragCard found")
		return
	var c: DragCard = cards[0]

	# 1) 点击出牌（回退路径）
	var before: int = run_state.hand.size()
	c.emit_signal("pressed")
	await process_frame
	if run_state.hand.size() != before - 1:
		_fail("click-to-play did not consume a card")
		return
	print("click-to-play OK (hand %d -> %d)" % [before, run_state.hand.size()])

	# 2) 拖拽能力：DragCard 具备拖拽所需字段（payload 结构预留多敌人 target_id）
	if c.card_index != 0:
		_fail("DragCard card_index wrong")
		return
	if not c.is_drag_data_supported():
		_fail("DragCard should declare drag data")
		return
	print("drag capability OK (card_index=%d, supports drag)" % c.card_index)

	# 2b) payload 结构验证（不触发 drag preview，避免 headless 泄漏）
	var pd: Dictionary = c.make_drag_payload()
	if not pd.has("card_index") or not pd.has("target_id") or str(pd.get("target_id", "x")) != "":
		_fail("drag payload structure wrong")
		return
	print("drag payload OK:", pd)

	# 3) DropZone 接受/回调
	var zone: DropZone = _find_drop_zone(refs.root)
	if zone == null:
		_fail("no DropZone")
		return
	if not zone._can_drop_data(Vector2.ZERO, {"card_index": 0}):
		_fail("DropZone reject card")
		return
	if zone._can_drop_data(Vector2.ZERO, {"foo": 1}):
		_fail("DropZone accept non-card")
		return
	before = run_state.hand.size()
	zone._drop_data(Vector2.ZERO, {"card_index": 1, "target_id": ""})
	if run_state.hand.size() != before - 1:
		_fail("drop did not play card")
		return
	print("drop-to-zone OK (hand %d -> %d)" % [before, run_state.hand.size()])

	refs.root.queue_free()
	for i in 5:
		await process_frame
	print("drag_test: OK")
	quit()

func _find_drag_cards(node: Node) -> Array:
	var out: Array = []
	if node is DragCard:
		out.append(node)
	for child in node.get_children():
		var found: Array = _find_drag_cards(child)
		for c in found:
			out.append(c)
	return out

func _find_drop_zone(node: Node) -> DropZone:
	if node is DropZone:
		return node as DropZone
	for child in node.get_children():
		var found: DropZone = _find_drop_zone(child)
		if found != null:
			return found
	return null

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
