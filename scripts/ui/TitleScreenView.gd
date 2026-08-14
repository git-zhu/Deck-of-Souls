class_name TitleScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")

const HINT_MUTED := Color("#b9ac94")
const TITLE_GLOW := Color("#e6c56d")


static func build(
	has_save: bool,
	on_new_game: Callable,
	on_continue: Callable,
	on_quit: Callable
) -> Control:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)

	var top := VBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)

	var title := Label.new()
	title.text = "破碎法环：褪色者牌局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameTheme.FONT_XL + 12)
	title.add_theme_color_override("font_color", TITLE_GLOW)
	title.add_theme_color_override("font_shadow_color", Color(0.9, 0.75, 0.4, 0.4))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	top.add_child(title)
	# 标题呼吸微光（法环赐福氛围）
	var title_pulse := title.create_tween().set_loops()
	title_pulse.tween_property(title, "modulate", Color(1, 1, 1, 0.82), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_pulse.tween_property(title, "modulate", Color(1, 1, 1, 1), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var subtitle := Label.new()
	subtitle.text = "从候王礼拜堂醒来，在宁姆格福的赐福之间改写牌组。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	top.add_child(subtitle)

	var hint := Label.new()
	hint.text = "参考本体初始职业、武器、战灰、魔法、祷告与敌人设计。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", HINT_MUTED)
	top.add_child(hint)

	var divider := TextureRect.new()
	divider.texture = load("res://assets/divider_gold.svg") as Texture2D
	divider.custom_minimum_size = Vector2(380, 24)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(divider)

	var bottom := MarginContainer.new()
	bottom.add_theme_constant_override("margin_bottom", 28)
	root.add_child(bottom)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(bar)

	var new_btn := _menu_button("新游戏" if has_save else "开始游戏")
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(on_new_game)
	bar.add_child(new_btn)

	var continue_btn := _menu_button("继续游戏")
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.modulate = Color(0.55, 0.55, 0.55, 1.0)
	continue_btn.pressed.connect(on_continue)
	bar.add_child(continue_btn)

	var quit_btn := _menu_button("退出游戏")
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(on_quit)
	bar.add_child(quit_btn)

	return root


static func _menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 52)
	UiBuilders.attach_hover_anim(btn, 1.04)
	return btn
