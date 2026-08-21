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
	on_pause_menu: Callable,
	show_hp_flask: bool = true
) -> Dictionary:
	for child in header.get_children():
		child.queue_free()

	# ── 左：玩家资源（生命 / 圣杯瓶 / 卢恩 / 护符…）Flex 水平垂直居中，间距统一 12 ──
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.grow_horizontal = Control.GROW_DIRECTION_END
	header.add_child(left)

	if show_hp_flask:
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_health.svg",
			"生命 %d/%d" % [run_state.hp, run_state.max_hp], "生命"
		))
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_flask.svg",
			"圣杯瓶 %d/%d" % [run_state.flasks, run_state.max_flasks], "圣杯瓶"
		))
		# 战斗资源与局内成长资源之间的视觉分隔
		var sep := PanelContainer.new()
		sep.custom_minimum_size = Vector2(1, 20)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = GameTheme.BORDER
		sep.add_theme_stylebox_override("panel", sep_style)
		left.add_child(sep)

	# ── 局内成长资源：与右侧「查看牌组」互补，不重复展示牌组数量 ──
	left.add_child(UiBuilders.header_chip(
		"res://assets/icons/icon_soul.svg",
		"卢恩 %d" % run_state.souls, "卢恩"
	))

	if run_state.relics.size() > 0:
		var relic_tooltip := "护符（点击查看详情）："
		for relic_id in run_state.relics:
			var relic := registry.get_relic(relic_id)
			if relic != null:
				relic_tooltip += "\n• %s：%s" % [relic.name, relic.body]
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_relic.svg",
			"护符 %d" % run_state.relics.size(), relic_tooltip
		))
	if run_state.memory_stones > 0:
		var ms_tooltip := "记忆石 %d/%d\n每颗：起始手牌 +1\n当前加成：+%d" % [
			run_state.memory_stones, RunState.MAX_MEMORY_STONES, run_state.memory_stones
		]
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_memory_stone.svg",
			"记忆石 %d/%d" % [run_state.memory_stones, RunState.MAX_MEMORY_STONES], ms_tooltip
		))
	# I4/I6/I8 仪式状态芯片：大卢恩 / 引火 / 癫火
	var inert_runes := 0
	var active_runes := 0
	for rk in run_state.great_runes.keys():
		if str(run_state.great_runes[rk]) == "":
			inert_runes += 1
		elif str(run_state.great_runes[rk]) not in ["refused"]:
			active_runes += 1
	var rune_tooltip := ""
	for rk in run_state.great_runes.keys():
		var state := str(run_state.great_runes[rk])
		var rune := registry.get_relic(rk)
		var rune_name: String = rune.name if rune != null else rk
		if state == "":
			rune_tooltip += "\n• %s：待朝圣激活" % rune_name
		elif state == "refused":
			rune_tooltip += "\n• %s：已拒绝" % rune_name
		else:
			var bound_relic := registry.get_relic(state)
			var effect: String = bound_relic.body if bound_relic != null else ""
			rune_tooltip += "\n• %s：已激活\n  %s" % [rune_name, effect]
	if inert_runes > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_relic.svg",
			"大卢恩 %d（待朝圣）" % inert_runes, "大卢恩" + rune_tooltip
		))
	elif active_runes > 0:
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_relic.svg",
			"大卢恩 %d（已激活）" % active_runes, "大卢恩" + rune_tooltip
		))
	if run_state.kindling != "":
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_flame.svg", "灭裂之火", "献祭"
		))
	if run_state.frenzied_flame:
		left.add_child(UiBuilders.header_chip(
			"res://assets/icons/icon_flame.svg", "癫火", "禁忌"
		))
	# 牌组数量已整合到右侧「查看牌组」按钮，顶栏不再重复展示

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
