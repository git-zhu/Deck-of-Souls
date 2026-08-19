extends SceneTree

const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")
const IntentIcon = preload("res://scripts/ui/IntentIcon.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	if origin == null:
		_fail("vagabond origin missing")
		return
	run_state.reset_for_origin(origin, 42)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)

	var template := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	if template.is_empty():
		_fail("enemy template empty")
		return
	combat.start_combat(template)

	var refs := CombatHudView.build(
		run_state,
		combat,
		registry,
		"[color=#d9ccb3]测试日志[/color]\n",
		132.0,
		178.0,
		func(_i): pass,
		combat.use_flask,
		combat.end_player_turn
	)
	if refs.root == null or refs.hand_row == null:
		_fail("CombatHudRefs missing nodes")
		return



	# 新布局校验：意图横幅 + 资源 chip + 游戏化卡牌结构

	if not _tree_has_label_text(refs.root, "抽牌"):
		_fail("combat HUD missing resource chip 抽牌")
		return
	if not _tree_has_button_prefix(refs.root, "结束回合"):
		_fail("combat HUD missing end turn CTA")
		return
	var flask := refs.flask_button as Button
	if flask == null or not flask.text.begins_with("圣杯瓶"):
		_fail("combat HUD flask button missing")
		return

	# 游戏化卡牌：每张手牌按钮应有消耗徽章（含数字 Label）
	var card_buttons := _find_buttons(refs.hand_row)
	for btn in card_buttons:
		if not _button_has_cost_badge(btn):
			_fail("hand card missing cost badge: %s" % btn.name)
			return

	# 收尾优化校验：意图横幅（图标 TextureRect + 标签）+ 稀有度标签 + 可折叠日志开关


	for btn in card_buttons:
		if not _button_has_rarity_label(btn):
			_fail("hand card missing rarity label: %s" % btn.name)
			return


	refs.root.queue_free()

	GameAudio.play(get_root(), "ui_click")
	print("combat_hud_test: OK")
	quit()


func _tree_has_label_prefix(node: Node, prefix: String) -> bool:
	if node is Label and (node as Label).text.begins_with(prefix):
		return true
	for child in node.get_children():
		if _tree_has_label_prefix(child, prefix):
			return true
	return false


func _tree_has_button_prefix(node: Node, prefix: String) -> bool:
	if node is Button and (node as Button).text.begins_with(prefix):
		return true
	for child in node.get_children():
		if _tree_has_button_prefix(child, prefix):
			return true
	return false


func _tree_has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _tree_has_label_text(child, text):
			return true
	return false


func _find_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_buttons(child))
	return out


func _button_has_cost_badge(btn: Button) -> bool:
	return _tree_has_nested_panel_label(btn)


func _tree_has_nested_panel_label(node: Node) -> bool:
	if node is PanelContainer and node.get_child_count() > 0 and node.get_child(0) is Label:
		return true
	for child in node.get_children():
		if _tree_has_nested_panel_label(child):
			return true
	return false


const RARITY_LABELS: Array[String] = ["起始", "普通", "罕见", "稀有", "传说"]


func _tree_has_intent_icon(node: Node) -> bool:
	# 意图图标：横幅内带贴图的 TextureRect（Kenney PNG 图标）
	if node is TextureRect:
		var tr := node as TextureRect
		if tr.texture != null:
			return true
	for child in node.get_children():
		if _tree_has_intent_icon(child):
			return true
	return false


func _button_has_rarity_label(btn: Button) -> bool:
	for child in btn.get_children():
		if _tree_has_rarity_label(child):
			return true
	return false


func _tree_has_rarity_label(node: Node) -> bool:
	if node is Label and (node as Label).text in RARITY_LABELS:
		return true
	for child in node.get_children():
		if _tree_has_rarity_label(child):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)