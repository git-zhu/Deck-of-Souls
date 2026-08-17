class_name OriginScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const OriginData = preload("res://data/OriginData.gd")

const NOTE_MUTED := Color("#b9ac94")

const VOW_DESCRIPTIONS: Array[String] = [
	"不立誓约。",
	"誓约Ⅰ 破损的瓶：初始圣杯瓶 −1。",
	"誓约Ⅱ 无恩之地：赐福休憩治疗减半。",
	"誓约Ⅲ 鲜血契约：敌人伤害再 +10%，卢恩再 +30%。",
	"誓约Ⅳ 苦行者：每回合抽牌 −1。",
	"誓约Ⅴ 死荫：最大生命 −20%。",
]

const CHALLENGE_DESCRIPTIONS: Array[String] = [
	"无誓言挑战。",
	"誓言：无瓶（开局 0 圣杯瓶，全靠自己）。",
	"誓言：强敌（敌人生命 +50%）。",
]


static func build(
	registry: DataRegistry,
	on_pick_origin: Callable,
	profile: Dictionary = {},
	on_difficulty_changed: Callable = Callable()
) -> Control:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "选择出身"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GameTheme.TITLE_GOLD)
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "出身只决定开局属性与装备。就像本体一样，之后的牌组会在交界地中改变。"
	desc.add_theme_color_override("font_color", GameTheme.BODY_MUTED)
	wrap.add_child(desc)

	# 周目 / 誓约 / 誓言挑战（周目与誓约通关后逐步解锁，挑战始终可选）
	var max_ng: int = int(profile.get("max_ng_unlocked", 0))
	var max_vow: int = int(profile.get("max_vow_unlocked", 0))
	wrap.add_child(_difficulty_row(max_ng, max_vow, on_difficulty_changed))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(grid)

	for id in registry.all_origin_ids():
		grid.add_child(origin_card(registry.get_origin(str(id)), str(id), on_pick_origin))

	return wrap


static func _difficulty_row(max_ng: int, max_vow: int, on_changed: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var ng_label := Label.new()
	ng_label.text = "周目"
	ng_label.add_theme_color_override("font_color", GameTheme.GOLD)
	row.add_child(ng_label)
	var ng_options := OptionButton.new()
	ng_options.add_item("正常", 0)
	for i in range(1, max_ng + 1):
		ng_options.add_item("NG+%d（敌强 卢恩丰）" % i, i)
	ng_options.select(0)
	row.add_child(ng_options)

	var vow_label := Label.new()
	vow_label.text = "誓约"
	vow_label.add_theme_color_override("font_color", GameTheme.GOLD)
	row.add_child(vow_label)
	var vow_options := OptionButton.new()
	for i in range(0, max_vow + 1):
		vow_options.add_item(VOW_DESCRIPTIONS[clampi(i, 0, VOW_DESCRIPTIONS.size() - 1)], i)
	vow_options.select(0)
	row.add_child(vow_options)

	var challenge_label := Label.new()
	challenge_label.text = "誓言挑战"
	challenge_label.add_theme_color_override("font_color", GameTheme.GOLD)
	row.add_child(challenge_label)
	var challenge_options := OptionButton.new()
	for i in range(0, CHALLENGE_DESCRIPTIONS.size()):
		challenge_options.add_item(CHALLENGE_DESCRIPTIONS[i], i)
	challenge_options.select(0)
	row.add_child(challenge_options)

	var emit := func() -> void:
		if on_changed.is_valid():
			on_changed.call(ng_options.selected, vow_options.selected, challenge_options.selected)
	ng_options.item_selected.connect(func(_idx: int) -> void: emit.call())
	vow_options.item_selected.connect(func(_idx: int) -> void: emit.call())
	challenge_options.item_selected.connect(func(_idx: int) -> void: emit.call())
	return row


static func origin_card(origin: OriginData, origin_id: String, on_pick: Callable) -> PanelContainer:
	# 统一琥珀金边框（替代暗金 9-slice 描边）：圆角 / 黑底 / 内边距与原面板一致
	var panel := PanelContainer.new()
	var origin_style := StyleBoxFlat.new()
	origin_style.bg_color = GameTheme.PANEL
	origin_style.border_color = GameTheme.ORIGIN_ACCENT
	origin_style.set_border_width_all(2)
	origin_style.corner_radius_top_left = 10
	origin_style.corner_radius_top_right = 10
	origin_style.corner_radius_bottom_left = 10
	origin_style.corner_radius_bottom_right = 10
	origin_style.content_margin_left = 14
	origin_style.content_margin_right = 14
	origin_style.content_margin_top = 14
	origin_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", origin_style)
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var name := Label.new()
	name.text = "%s  Lv.%d" % [origin.name, origin.level]
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name)

	var stats := Label.new()
	stats.text = origin.stats
	stats.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(stats)

	var gear := Label.new()
	gear.text = origin.equipment
	gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gear)

	var note := Label.new()
	note.text = origin.note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("font_color", NOTE_MUTED)
	v.add_child(note)

	var pick := Button.new()
	pick.text = "以此出身开始"
	pick.custom_minimum_size = Vector2(0, 42)
	pick.pressed.connect(on_pick.bind(origin_id))
	v.add_child(pick)
	UiBuilders.attach_hover_anim(panel, 1.02)
	return panel
