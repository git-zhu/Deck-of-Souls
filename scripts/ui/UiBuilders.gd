class_name UiBuilders
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const CardData = preload("res://data/CardData.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")
const IntentIcon = preload("res://scripts/ui/IntentIcon.gd")


static func attach_hover_anim(ctrl: Control, scale: float = 1.03) -> void:
	# 悬停反馈：轻微放大（PC 鼠标悬停 / 手机长按通用）
	ctrl.mouse_entered.connect(func() -> void:
		if ctrl.has_meta("_hover_tween"):
			var t: Tween = ctrl.get_meta("_hover_tween")
			if t.is_valid():
				t.kill()
		var tw := ctrl.create_tween()
		ctrl.set_meta("_hover_tween", tw)
		tw.tween_property(ctrl, "scale", Vector2(scale, scale), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	ctrl.mouse_exited.connect(func() -> void:
		if ctrl.has_meta("_hover_tween"):
			var t: Tween = ctrl.get_meta("_hover_tween")
			if t.is_valid():
				t.kill()
		var tw := ctrl.create_tween()
		ctrl.set_meta("_hover_tween", tw)
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)


static func panel(bg: Color, border: Color = GameTheme.BORDER, border_width: int = 1) -> PanelContainer:
	var panel_node := PanelContainer.new()
	# 9-slice 暗金面板底（角部固定、边缘拉伸；bg/border 参数仅作 fallback 底色）
	var tex_style := StyleBoxTexture.new()
	tex_style.texture = load("res://assets/panel_9slice.png") as Texture2D
	tex_style.texture_margin_left = 24
	tex_style.texture_margin_right = 24
	tex_style.texture_margin_top = 24
	tex_style.texture_margin_bottom = 24
	tex_style.content_margin_left = 14
	tex_style.content_margin_right = 14
	tex_style.content_margin_top = 14
	tex_style.content_margin_bottom = 14
	tex_style.draw_center = true
	panel_node.add_theme_stylebox_override("panel", tex_style)
	return panel_node


static func header_chip(icon_path: String, value_text: String, tooltip: String = "") -> PanelContainer:
	# 顶栏统计 chip：图标 + 数值，面板包裹（与战斗页风格统一）
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.07, 0.75)
	style.border_color = GameTheme.BTN_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	if tooltip != "":
		chip.tooltip_text = tooltip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	if icon_path != "":
		var icon_tex := load(icon_path) as Texture2D
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", GameTheme.FONT_SM)
	value.add_theme_color_override("font_color", GameTheme.TEXT)
	row.add_child(value)
	return chip


static func small_stat(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	label.add_theme_font_size_override("font_size", 18)
	return label


static func map_choice_card(option: Dictionary, on_press: Callable) -> PanelContainer:
	var kind := str(option.get("kind", ""))
	var card_type := str(option.get("cardType", kind))
	var meta := GameTheme.card_type_meta(card_type)
	# 主边框按 cardType 高亮（替代原暗金 9-slice 描边）：
	# 圆角 / 黑色底图 / 内边距与旧面板保持一致，仅边框与左上角标签变色
	var panel_node := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = GameTheme.PANEL
	card_style.border_color = meta.color
	card_style.set_border_width_all(2)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	panel_node.add_theme_stylebox_override("panel", card_style)
	panel_node.custom_minimum_size = Vector2(0, 330)
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel_node.add_child(v)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	v.add_child(badge_row)

	var badge := Label.new()
	badge.text = meta.label
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", meta.color)
	badge_row.add_child(badge)

	var name := Label.new()
	name.text = str(option.get("title", ""))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 28)
	name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name)

	var body := Label.new()
	body.text = str(option.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	btn.text = "介入" if kind == "event" else "踏入"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(on_press)
	v.add_child(btn)
	attach_hover_anim(panel_node)
	return panel_node


static func fighter_panel(
	n: String,
	cur_hp: int,
	full_hp: int,
	cur_block: int,
	status: String,
	bg: Color,
	stance_now: int = -1,
	stance_max: int = -1
) -> PanelContainer:
	var border := GameTheme.BORDER
	var border_width := 1
	if stance_max > 0 and float(stance_now) / float(stance_max) <= 0.25:
		border = GameTheme.GOLD
		border_width = 2

	var panel_node := panel(bg, border, border_width)
	panel_node.custom_minimum_size = Vector2(260, 0)
	panel_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel_node.add_child(v)

	var name := Label.new()
	name.text = n
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e4c06d"))
	v.add_child(name)

	var hp_label := Label.new()
	hp_label.text = "生命 %d / %d" % [cur_hp, full_hp]
	hp_label.add_theme_font_size_override("font_size", 22)
	v.add_child(hp_label)

	var bar := ProgressBar.new()
	bar.max_value = full_hp
	bar.value = cur_hp
	bar.custom_minimum_size = Vector2(0, 22)
	v.add_child(bar)

	var block_label := Label.new()
	block_label.text = "护甲 %d" % cur_block
	v.add_child(block_label)

	var status_label := Label.new()
	status_label.text = status
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(status_label)
	return panel_node


static func rarity_meta(rarity: String) -> Dictionary:
	# 卡牌稀有度语义：starter/common 不叠加额外边框（保持类型色常规边框），
	# uncommon/rare/legendary 用稀有度语义色强调边框（border_only=true）。
	match rarity:
		"uncommon":
			return {"label": "罕见", "color": Color("#5ab86a"), "border_only": true, "border_width": 3}
		"rare":
			return {"label": "稀有", "color": Color("#5b9bd5"), "border_only": true, "border_width": 3}
		"legendary":
			return {"label": "传说", "color": Color("#c0392b"), "border_only": true, "border_width": 3}
		"starter":
			return {"label": "起始", "color": Color("#9a8f7a"), "border_only": false, "border_width": 2}
		_:
			return {"label": "普通", "color": Color("#b9a37b"), "border_only": false, "border_width": 2}


static func card_button(
	card: CardData,
	index: int,
	combat: CombatController,
	card_w: float,
	card_h: float,
	on_play: Callable
) -> Button:
	var accent := GameTheme.card_type_color(card.type)
	var unplayable: bool = card.cost > combat.ember or combat.combat_over

	# 可拖拽手牌（DragCard）：拖到敌人/战斗区域打出；点击同样可打出
	var button := DragCard.new()
	button.setup(index, on_play)
	button.custom_minimum_size = Vector2(card_w, card_h)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = ""
	button.tooltip_text = "%s（快捷键 %d）" % [card.text, index + 1] if index < 9 else card.text
	button.disabled = unplayable
	if unplayable:
		button.modulate = GameTheme.card_disabled_modulate()

	# 稀有度边框：uncommon/rare/legendary 以稀有度语义色强调，starter/common 保持类型色常规边框
	var rarity_meta_dict := rarity_meta(card.rarity)
	var border_color := accent.lightened(0.15)
	var border_width := 2
	if rarity_meta_dict.get("border_only", false):
		border_color = rarity_meta_dict.color
		border_width = int(rarity_meta_dict.border_width)

	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.6)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.border_color = border_color.lightened(0.4)
	hover_style.shadow_size = 9
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = accent.darkened(0.7)
	button.add_theme_stylebox_override("pressed", pressed_style)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.border_color = GameTheme.BORDER
	disabled_style.bg_color = Color("#1c1a16")
	button.add_theme_stylebox_override("disabled", disabled_style)

	var v_margin := MarginContainer.new()
	v_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_margin.add_theme_constant_override("margin_left", 6)
	v_margin.add_theme_constant_override("margin_right", 6)
	v_margin.add_theme_constant_override("margin_top", 5)
	v_margin.add_theme_constant_override("margin_bottom", 5)
	v_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(v_margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_margin.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)

	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(24, 24)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_style := StyleBoxFlat.new()
	cost_style.bg_color = Color("#16130f")
	cost_style.border_color = GameTheme.GOLD
	cost_style.set_border_width_all(2)
	cost_style.corner_radius_top_left = 12
	cost_style.corner_radius_top_right = 12
	cost_style.corner_radius_bottom_left = 12
	cost_style.corner_radius_bottom_right = 12
	cost_badge.add_theme_stylebox_override("panel", cost_style)
	var cost_label := Label.new()
	cost_label.text = str(card.cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_label.add_theme_color_override("font_color", GameTheme.GOLD)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_child(cost_label)
	top.add_child(cost_badge)

	var name_label := Label.new()
	name_label.text = card.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("#f0e5cd"))
	top.add_child(name_label)

	if index < 9:
		var hotkey := Label.new()
		hotkey.text = str(index + 1)
		hotkey.add_theme_font_size_override("font_size", 12)
		hotkey.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		top.add_child(hotkey)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "%s  ·  集中 %d" % [card.type, card.cost]
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", accent.lightened(0.3))
	type_row.add_child(type_label)

	# 稀有度标签：卡面小标签（起始/普通/罕见/稀有/传说）
	var rarity_tag := Label.new()
	rarity_tag.text = str(rarity_meta_dict.label)
	rarity_tag.add_theme_font_size_override("font_size", 11)
	rarity_tag.add_theme_color_override("font_color", rarity_meta_dict.color)
	type_row.add_child(rarity_tag)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)

	var effect := RichTextLabel.new()
	effect.bbcode_enabled = true
	effect.fit_content = false
	effect.scroll_active = false
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.text = "[font_size=12]%s[/font_size]" % emphasize_numbers(card.text)
	v.add_child(effect)

	# 金色符文边框：9-slice TextureRect 覆盖层（Button 的 frame 样式不渲染，须用子节点）
	var frame := TextureRect.new()
	frame.texture = load("res://assets/card_frame_9slice.png") as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 0
	frame.offset_right = 0
	frame.offset_top = 0
	frame.offset_bottom = 0
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_child(frame)
	frame.move_to_front()

	button.pressed.connect(on_play)
	# 注意：悬停放大由 DragCard 自带的 StS lift 处理（此处不再 attach_hover_anim 避免冲突）
	return button


# ---------- 战斗 UI 重构（游戏化） ----------

static func _num_regex() -> RegEx:
	var r := RegEx.new()
	r.compile("\\d+")
	return r


static func _intent_icon_path(kind: String) -> String:
	match kind:
		"attack", "attack_block", "attack_rot":
			return "res://assets/external/kenney_icons/sword.png"
		"block":
			return "res://assets/external/kenney_icons/shield.png"
		"buff", "strength":
			return "res://assets/external/kenney_icons/arrow_right.png"
		"debuff", "rot":
			return "res://assets/external/kenney_icons/skull.png"
		_:
			return "res://assets/external/kenney_icons/shield.png"


static func emphasize_numbers(text: String) -> String:
	# 卡牌效果文本中高亮数字（数值优先原则）
	var r := _num_regex()
	var replaced := r.sub(text, "[color=#f0cf6a]$0[/color]", true)
	return replaced


static func compact_fighter_hud(
	name_text: String,
	cur_hp: int,
	full_hp: int,
	cur_block: int,
	statuses: Dictionary,
	bg: Color,
	is_enemy: bool = false,
	stance_now: int = -1,
	stance_max: int = -1
) -> PanelContainer:
	# 紧凑 HUD：名字 + 大号 HP + 细血条 + 状态 chip，取代大型面板
	var border := GameTheme.BORDER
	var border_width := 1
	if stance_max > 0 and float(stance_now) / float(stance_max) <= 0.25:
		border = GameTheme.GOLD
		border_width = 2

	# 紧凑 9-slice 面板：content margin 6px（默认 14px 会导致 HUD 过高）
	var panel_node := PanelContainer.new()
	var pstyle := StyleBoxTexture.new()
	pstyle.texture = load("res://assets/panel_9slice.png") as Texture2D
	pstyle.texture_margin_left = 24
	pstyle.texture_margin_right = 24
	pstyle.texture_margin_top = 24
	pstyle.texture_margin_bottom = 24
	pstyle.content_margin_left = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_top = 6
	pstyle.content_margin_bottom = 6
	if border_width >= 2:
		pstyle.modulate_color = border
	panel_node.add_theme_stylebox_override("panel", pstyle)
	panel_node.custom_minimum_size = Vector2(228, 0)
	panel_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel_node.add_child(v)

	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var name := Label.new()
	name.text = name_text
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", Color("#e4c06d"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name)
	var hp_label := Label.new()
	hp_label.text = "%d / %d" % [cur_hp, full_hp]
	hp_label.add_theme_font_size_override("font_size", 19)
	hp_label.add_theme_color_override("font_color", Color("#ffffff"))
	name_row.add_child(hp_label)

	var bar := ProgressBar.new()
	bar.max_value = full_hp
	bar.value = cur_hp
	bar.custom_minimum_size = Vector2(0, 9)
	bar.show_percentage = false
	v.add_child(bar)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	v.add_child(chips)
	if cur_block > 0:
		chips.add_child(status_chip("护甲 %d" % cur_block, GameTheme.CARD_DEFENSE, "res://assets/external/kenney_icons/shield.png"))
	for key in statuses:
		var val: int = int(statuses[key])
		if val <= 0:
			continue
		match str(key):
			"rot":
				chips.add_child(status_chip("腐败 %d" % val, GameTheme.status_color("rot"), "res://assets/external/kenney_icons/fire.png"))
			"bleed":
				chips.add_child(status_chip("出血 %d" % val, GameTheme.status_color("bleed"), "res://assets/external/kenney_icons/sword.png"))
			"vulnerable":
				chips.add_child(status_chip("易伤 %d" % val, GameTheme.status_color("vulnerable"), "res://assets/external/kenney_icons/skull.png"))
			"strength":
				chips.add_child(status_chip("力量 %d" % val, GameTheme.status_color("strength"), "res://assets/external/kenney_icons/arrow_right.png"))
			"stance":
				chips.add_child(status_chip("姿态 %d/%d" % [val, stance_max], GameTheme.status_color("stance"), "res://assets/external/kenney_icons/suit_diamonds.png"))
	return panel_node


static func status_chip(text: String, color: Color, icon_path: String = "") -> PanelContainer:
	# 状态 chip：图标（若有）+ 数值，StS 式 buff/debuff 视觉
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	chip.add_child(row)

	if icon_path != "":
		var icon_tex := load(icon_path) as Texture2D
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(14, 14)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.modulate = color.lightened(0.4)
			row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	row.add_child(label)
	return chip


static func intent_banner(intent_kind: String, intent_text: String) -> PanelContainer:
	# 敌人意图：高优先级视觉元素（语义色描边 + 图标 + 大字号，紧凑高度）
	var accent := GameTheme.intent_color(intent_kind)
	var panel_node := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("#1d1812")
	pstyle.border_color = accent.lightened(0.2)
	pstyle.set_border_width_all(2)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.shadow_color = accent.darkened(0.3)
	pstyle.shadow_size = 8
	pstyle.content_margin_left = 16
	pstyle.content_margin_right = 16
	pstyle.content_margin_top = 8
	pstyle.content_margin_bottom = 8
	panel_node.add_theme_stylebox_override("panel", pstyle)
	panel_node.custom_minimum_size = Vector2(0, 52)
	panel_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_node.add_child(row)

	var tag := Label.new()
	tag.text = "敌方意图"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	row.add_child(tag)

	# 意图图标：固定 24px 的 Kenney PNG（语义色调色；不用 IntentIcon 自绘避免双重显示）
	var icon_path := _intent_icon_path(intent_kind)
	var tex := load(icon_path) as Texture2D
	if tex != null:
		var tex_icon := TextureRect.new()
		tex_icon.texture = tex
		tex_icon.custom_minimum_size = Vector2(24, 24)
		tex_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_icon.modulate = accent
		tex_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tex_icon)

	var action := Label.new()
	action.text = intent_text
	action.add_theme_font_size_override("font_size", 24)
	action.add_theme_color_override("font_color", accent.lightened(0.25))
	row.add_child(action)
	return panel_node


static func combat_stage(player_name: String, enemy_name: String) -> Control:
	# 中央战斗区域视觉主体：玩家 ←→ 敌人，镀金框内
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	row.add_child(_fighter_token(player_name, Color("#3d6e9e"), "P"))
	var vs := Label.new()
	vs.text = "⚔"
	vs.add_theme_font_size_override("font_size", 44)
	vs.add_theme_color_override("font_color", GameTheme.GOLD)
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(vs)
	row.add_child(_fighter_token(enemy_name, Color("#9e3d3d"), "E"))
	return stage


static func _fighter_token(name_text: String, color: Color, initial: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size = Vector2(150, 0)

	var circle := PanelContainer.new()
	circle.custom_minimum_size = Vector2(96, 96)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6)
	style.border_color = color.lightened(0.2)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48
	circle.add_theme_stylebox_override("panel", style)
	var initial_label := Label.new()
	initial_label.text = initial
	initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_label.add_theme_font_size_override("font_size", 44)
	initial_label.add_theme_color_override("font_color", Color("#ffffff"))
	circle.add_child(initial_label)
	col.add_child(circle)

	var name := Label.new()
	name.text = name_text
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", GameTheme.TEXT)
	col.add_child(name)
	return col


static func energy_orb(ember: int, max_ember: int) -> PanelContainer:
	# StS 式能量球：金色圆环 + 大号能量数值，强调核心资源
	var orb := PanelContainer.new()
	orb.custom_minimum_size = Vector2(52, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3a2d10")
	style.border_color = GameTheme.GOLD
	style.set_border_width_all(3)
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.corner_radius_bottom_left = 26
	style.corner_radius_bottom_right = 26
	style.shadow_color = Color(0.88, 0.75, 0.4, 0.3)
	style.shadow_size = 6
	orb.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	orb.add_child(v)
	var num := Label.new()
	num.text = str(ember)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 26)
	num.add_theme_color_override("font_color", GameTheme.GOLD.lightened(0.2))
	v.add_child(num)
	var cap := Label.new()
	cap.text = "/ %d" % max_ember
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(cap)
	return orb


static func turn_label(turn: int) -> Label:
	# StS 式回合数标签（顶部）
	var label := Label.new()
	label.text = "回合 %d" % turn
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func resource_chip(label_text: String, value_text: String) -> PanelContainer:
	# 资源 HUD：紧凑图标 + 数值 chip
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1c1812")
	style.border_color = GameTheme.BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", GameTheme.GOLD)
	row.add_child(value)
	return chip


static func flask_button(flasks: int, disabled: bool, on_press: Callable) -> Button:
	# 圣杯瓶：独立治疗按钮（绿调 + 图标）
	var btn := Button.new()
	btn.text = "圣杯瓶 ×%d" % flasks
	btn.custom_minimum_size = Vector2(132, 54)
	btn.add_theme_icon_override("icon", load("res://assets/icon_flask.png"))
	btn.disabled = disabled
	btn.tooltip_text = "回复 18 生命（F）"
	btn.pressed.connect(on_press)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1f3a24")
	style.border_color = GameTheme.CARD_HEAL.darkened(0.2)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2a4a2e")
	hover.border_color = GameTheme.CARD_HEAL
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#16301c")
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color("#241f1a")
	disabled_style.border_color = GameTheme.BORDER
	btn.add_theme_stylebox_override("disabled", disabled_style)
	return btn


static func end_turn_button(disabled: bool, on_press: Callable) -> Button:
	# 结束回合：主 CTA（金色，右下固定，hover/disabled/快捷键提示）
	var btn := Button.new()
	btn.text = "结束回合  [E]"
	btn.custom_minimum_size = Vector2(170, 54)
	btn.disabled = disabled
	btn.tooltip_text = "结束当前回合（空格 / E）"
	btn.pressed.connect(on_press)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3a2d10")
	style.border_color = GameTheme.GOLD
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.88, 0.75, 0.4, 0.25)
	style.shadow_size = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#4a3a15")
	hover.border_color = Color("#f5d877")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#2e240d")
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color("#241f1a")
	disabled_style.border_color = GameTheme.BORDER
	disabled_style.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", disabled_style)
	return btn


static func deck_summary_row(card: CardData, count: int, text_width: float = 520.0) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242018")
	style.border_color = card.tone.darkened(0.1)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(h)

	var badge := Label.new()
	badge.text = "×%d" % count
	badge.custom_minimum_size = Vector2(40, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", GameTheme.GOLD)
	h.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)

	var title := Label.new()
	title.text = "%s  ·  %s  ·  集中 %d" % [card.name, card.type, card.cost]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", card.tone.lightened(0.25))
	info.add_child(title)

	var desc := Label.new()
	desc.text = card.text
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size.x = text_width
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	info.add_child(desc)

	return row
