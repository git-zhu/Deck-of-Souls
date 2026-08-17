class_name RunHeaderView
extends RefCounted

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")


static func build(
	header: Control,
	run_state: RunState,
	registry: DataRegistry,
	_on_deck_view: Callable,
	on_pause_menu: Callable
) -> Dictionary:
	for child in header.get_children():
		child.queue_free()

	# ── 左：玩家资源（生命 / 圣杯瓶 / 卢恩 / 牌组…）Flex 水平垂直居中，间距统一 12 ──
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.grow_horizontal = Control.GROW_DIRECTION_END
	header.add_child(left)

	left.add_child(UiBuilders.header_chip(
		"res://assets/external/kenney_icons/suit_hearts.png",
		"生命 %d/%d" % [run_state.hp, run_state.max_hp], "生命"
	))
	left.add_child(UiBuilders.header_chip(
		"res://assets/icon_flask.png",
		"圣杯瓶 %d/%d" % [run_state.flasks, run_state.max_flasks], "圣杯瓶"
	))
	left.add_child(UiBuilders.header_chip(
		"res://assets/icon_soul.png",
		"卢恩 %d" % run_state.souls, "卢恩"
	))
	if run_state.relics.size() > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_diamonds.png",
			"护符 %d" % run_state.relics.size(), "护符"
		))
	if run_state.memory_stones > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/dice_skull.png",
			"记忆石 %d/%d" % [run_state.memory_stones, RunState.MAX_MEMORY_STONES], "记忆石"
		))
	# I4/I6/I8 仪式状态芯片：大卢恩 / 引火 / 癫火
	var inert_runes := 0
	var active_runes := 0
	for rk in run_state.great_runes.keys():
		if str(run_state.great_runes[rk]) == "":
			inert_runes += 1
		elif str(run_state.great_runes[rk]) not in ["refused"]:
			active_runes += 1
	if inert_runes > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_diamonds.png",
			"大卢恩 %d（待朝圣）" % inert_runes, "大卢恩"
		))
	elif active_runes > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_diamonds.png",
			"大卢恩 %d（已激活）" % active_runes, "大卢恩"
		))
	if run_state.kindling != "":
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_hearts.png", "灭裂之火", "献祭"
		))
	if run_state.frenzied_flame:
		left.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_hearts.png", "癫火", "禁忌"
		))
	left.add_child(UiBuilders.header_chip(
		"res://assets/external/kenney_icons/cards_stack.png",
		"牌组 %d" % run_state.deck.size(), "牌组"
	))

	# ── 中：场景名称/进度（完美居中，如「宁姆格福踏标 · 1/4」） ──
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(center)
	var act := registry.get_act(run_state.act_index())
	var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
	var center_chip: PanelContainer
	if act != null:
		center_chip = UiBuilders.header_chip(
			"",
			"%s · %d/%d" % [act.title, local_step, RunState.FLOORS_PER_ACT],
			"进度"
		)
	else:
		center_chip = UiBuilders.header_chip(
			"",
			"层数 %d/%d" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS],
			"进度"
		)
	_center_title_font(center_chip)
	center.add_child(center_chip)

	# ── 右：【查看牌组】 + 菜单 ──
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	header.add_child(right)

	var deck_button := Button.new()
	deck_button.text = "查看牌组"
	deck_button.custom_minimum_size = Vector2(118, 34)
	deck_button.pressed.connect(_on_deck_view)
	right.add_child(deck_button)

	var menu_button := Button.new()
	menu_button.text = "☰"
	menu_button.tooltip_text = "选项"
	menu_button.custom_minimum_size = Vector2(40, 34)
	menu_button.pressed.connect(on_pause_menu)
	right.add_child(menu_button)

	return {"deck": deck_button, "menu": menu_button}


static func _center_title_font(chip: PanelContainer) -> void:
	# 中央进度标题用展示字体（书法体），左右信息 chip 保持默认字体
	var title_font := GameTheme.display_font()
	if title_font == null:
		return
	_apply_font_to_labels(chip, title_font)


static func _apply_font_to_labels(node: Node, font: Font) -> void:
	# 运行时动态树 find_children 不可靠，手动递归
	if node is Label:
		(node as Label).add_theme_font_override("font", font)
		(node as Label).add_theme_font_size_override("font_size", 17)
	for child in node.get_children():
		_apply_font_to_labels(child, font)
