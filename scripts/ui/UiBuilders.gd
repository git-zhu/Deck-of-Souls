class_name UiBuilders
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const CardData = preload("res://data/CardData.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")


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
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel_node.add_theme_stylebox_override("panel", style)
	return panel_node


static func small_stat(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	label.add_theme_font_size_override("font_size", 18)
	return label


static func map_choice_card(option: Dictionary, on_press: Callable) -> PanelContainer:
	var kind := str(option.get("kind", ""))
	var meta := GameTheme.map_kind_meta(kind)
	var panel_node := panel(GameTheme.PANEL, meta.accent, 2)
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
	badge.add_theme_color_override("font_color", meta.accent)
	badge_row.add_child(badge)

	var name := Label.new()
	name.text = str(option.get("title", ""))
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


static func card_button(
	card: CardData,
	index: int,
	combat: CombatController,
	card_w: float,
	card_h: float,
	on_play: Callable
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(card_w, card_h)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 快捷键提示：手牌序号（1-9）显示在卡名旁，PC 上直接按数字键打牌
	if index < 9:
		button.text = "[%d] %s\n%s  集中:%d\n\n%s" % [index + 1, card.name, card.type, card.cost, card.text]
	else:
		button.text = "%s\n%s  集中:%d\n\n%s" % [card.name, card.type, card.cost, card.text]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = "%s\n（快捷键 %d）" % [card.text, index + 1] if index < 9 else card.text
	var unplayable: bool = card.cost > combat.ember or combat.combat_over
	button.disabled = unplayable
	if unplayable:
		button.modulate = GameTheme.card_disabled_modulate()
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = card.tone.darkened(0.45)
	style.border_color = card.tone.lightened(0.2)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(on_play)
	attach_hover_anim(button, 1.06)
	return button


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
