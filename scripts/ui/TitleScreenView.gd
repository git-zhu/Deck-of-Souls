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
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	# ── Logo 区：英文主标题 + 中文副标题 + 暗金分隔线 ──
	var title := Label.new()
	title.text = "DECK OF SOULS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameTheme.FONT_XL + 16)
	title.add_theme_color_override("font_color", TITLE_GLOW)
	title.add_theme_color_override("font_shadow_color", Color(0.9, 0.75, 0.4, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_font_override("font", GameTheme.display_font())
	top.add_child(title)
	# 标题呼吸微光（法环赐福氛围）
	var title_pulse := title.create_tween().set_loops()
	title_pulse.tween_property(title, "modulate", Color(1, 1, 1, 0.82), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_pulse.tween_property(title, "modulate", Color(1, 1, 1, 1), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var divider := TextureRect.new()
	divider.texture = load("res://assets/divider_gold.svg") as Texture2D
	divider.custom_minimum_size = Vector2(420, 28)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(divider)

	# ── 菜单按钮 ──
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(menu)

	var new_btn := _menu_button("新游戏" if has_save else "开始游戏")
	new_btn.pressed.connect(on_new_game)
	menu.add_child(new_btn)

	var continue_btn := _menu_button("继续游戏")
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.modulate = Color(0.55, 0.55, 0.55, 1.0)
	continue_btn.pressed.connect(on_continue)
	menu.add_child(continue_btn)

	var quit_btn := _menu_button("退出游戏")
	quit_btn.pressed.connect(on_quit)
	menu.add_child(quit_btn)

	return root


static func _menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(260, 58)
	btn.add_theme_font_size_override("font_size", GameTheme.FONT_MD + 2)

	# 石碑按钮：暗褐底 + 暗金描边 + 底部阴影
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#211d15")
	normal.border_color = Color("#6b5a33")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2f2819")
	hover.border_color = GameTheme.GOLD
	hover.set_border_width_all(2)
	hover.shadow_size = 6
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#17140e")
	pressed.border_color = GameTheme.GOLD.darkened(0.25)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(0, 0)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#181510")
	disabled.border_color = Color("#3a342a")
	btn.add_theme_stylebox_override("disabled", disabled)

	UiBuilders.attach_hover_anim(btn, 1.03)
	return btn
