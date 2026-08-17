extends SceneTree

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const CardData = preload("res://data/CardData.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")


func _initialize() -> void:
	# 1. 样式映射：武器 → 金，盾牌 → 青（固定，不随机）
	var weapon := GameTheme.card_type_style("武器")
	var shield := GameTheme.card_type_style("盾牌")
	if weapon.accent != GameTheme.CARD_WEAPON or shield.accent != GameTheme.CARD_DEFENSE:
		_fail("card_type_style accent mapping")
		return

	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	run_state.reset_for_origin(registry.get_origin("vagabond"), 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)
	var template := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	combat.start_combat(template)

	# 2. 强制统一尺寸：文本长度差异极大的两张牌必须等大
	var short_card := CardData.new()
	short_card.id = "t_short"
	short_card.name = "剑"
	short_card.cost = 1
	short_card.type = "武器"
	short_card.rarity = "common"
	short_card.text = "造成 3 点伤害。"
	var long_card := CardData.new()
	long_card.id = "t_long"
	long_card.name = "熨斗形盾（长名测试卡牌名称）"
	long_card.cost = 2
	long_card.type = "盾牌"
	long_card.rarity = "starter"
	long_card.text = "获得 12 点护甲。这是一段非常非常长的效果描述文本，用于验证无论内容多长卡牌外框都不会变形。"

	var btn_short := UiBuilders.card_button(short_card, 0, combat, 110.0, 142.0, func(): pass)
	var btn_long := UiBuilders.card_button(long_card, 1, combat, 110.0, 142.0, func(): pass)
	var holder := VBoxContainer.new()
	holder.add_child(btn_short)
	holder.add_child(btn_long)
	root.add_child(holder)
	await process_frame
	if btn_short.size != Vector2(110, 142) or btn_long.size != Vector2(110, 142):
		_fail("card sizes not rigid: short=%s long=%s" % [str(btn_short.size), str(btn_long.size)])
		return
	if btn_short.size != btn_long.size:
		_fail("cards must be identical size")
		return

	# 3. 卡面干净：不得叠加符文边框贴图，也不得有 HSeparator 横线
	var frame := _find_texture_rect(btn_short, "res://assets/card_frame_9slice.png")
	if frame != null:
		_fail("card must not carry the rune frame overlay")
		return
	if _find_hseparator(btn_short) != null or _find_hseparator(btn_long) != null:
		_fail("card must not contain an HSeparator line")
		return

	# 4. 消耗圆环：统一外观（深底 + 金色 2px 圆环 + 金色数字），两卡一致
	var orb_style := _find_cost_orb_style(btn_short)
	var orb_style2 := _find_cost_orb_style(btn_long)
	if orb_style == null or orb_style2 == null:
		_fail("cost orb stylebox missing")
		return
	if orb_style.border_color != GameTheme.GOLD or orb_style.border_width_left != 2:
		_fail("cost orb ring must be uniform gold 2px")
		return
	if orb_style.border_color != orb_style2.border_color or orb_style.border_width_left != orb_style2.border_width_left:
		_fail("cost orb must be identical across cards")
		return

	# 5. 右上角角标：随主题映射（武器 → 深褐底黄字；盾牌 → 深青底白字）
	var badge_short := _find_hotkey_badge(btn_short)
	var badge_long := _find_hotkey_badge(btn_long)
	if badge_short == null or badge_long == null:
		_fail("hotkey badge missing")
		return
	var bs := badge_short.get_theme_stylebox("panel") as StyleBoxFlat
	var bl := badge_long.get_theme_stylebox("panel") as StyleBoxFlat
	if bs.bg_color != GameTheme.card_type_style("武器").badge_bg:
		_fail("weapon badge bg should be dark brown")
		return
	if bl.bg_color != GameTheme.card_type_style("盾牌").badge_bg:
		_fail("shield badge bg should be dark teal")
		return
	if bs.bg_color == bl.bg_color:
		_fail("badge bg must differ per theme")
		return

	holder.queue_free()
	print("hand_card_style_test: OK")
	quit()


func _find_texture_rect(node: Node, tex_path: String) -> TextureRect:
	if node is TextureRect:
		var tr := node as TextureRect
		if tr.texture != null and tr.texture.resource_path == tex_path:
			return tr
	for child in node.get_children():
		var found := _find_texture_rect(child, tex_path)
		if found != null:
			return found
	return null


func _find_margin_container(node: Node) -> MarginContainer:
	if node is MarginContainer:
		return node
	for child in node.get_children():
		var found := _find_margin_container(child)
		if found != null:
			return found
	return null


func _find_hseparator(node: Node) -> HSeparator:
	if node is HSeparator:
		return node
	for child in node.get_children():
		var found := _find_hseparator(child)
		if found != null:
			return found
	return null


func _find_cost_orb_style(btn: Button) -> StyleBoxFlat:
	# 消耗圆环：PanelContainer(24,24) + Label 数字
	for child in btn.get_children():
		var found := _find_orb_inner(child)
		if found != null:
			return found
	return null


func _find_orb_inner(node: Node) -> StyleBoxFlat:
	if node is PanelContainer and (node as PanelContainer).custom_minimum_size == Vector2(24, 24):
		return (node as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	for child in node.get_children():
		var found := _find_orb_inner(child)
		if found != null:
			return found
	return null


func _find_hotkey_badge(btn: Button) -> PanelContainer:
	# 右上角标：PanelContainer(20,20) + Label 数字
	for child in btn.get_children():
		var found := _find_badge_inner(child)
		if found != null:
			return found
	return null


func _find_badge_inner(node: Node) -> PanelContainer:
	if node is PanelContainer and (node as PanelContainer).custom_minimum_size == Vector2(20, 20):
		return node
	for child in node.get_children():
		var found := _find_badge_inner(child)
		if found != null:
			return found
	return null


func _is_after(a: Node, b: Node) -> bool:
	# a 在兄弟顺序上先于 b（先加入 → 绘制在下层）
	if a.get_parent() == null or b.get_parent() == null:
		return false
	if a.get_parent() != b.get_parent():
		return false
	var ai := a.get_index()
	var bi := b.get_index()
	return ai < bi


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
