class_name TitleScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")

const HINT_MUTED := Color("#b9ac94")
const TITLE_GLOW := Color("#e6c56d")


static func build(on_start: Callable) -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text = "破碎法环：褪色者牌局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", TITLE_GLOW)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "从候王礼拜堂醒来，在宁姆格福的赐福之间改写牌组。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)

	var start := Button.new()
	start.text = "选择出身"
	start.custom_minimum_size = Vector2(240, 54)
	start.pressed.connect(on_start)
	box.add_child(start)

	var hint := Label.new()
	hint.text = "参考本体初始职业、武器、战灰、魔法、祷告与敌人设计。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", HINT_MUTED)
	box.add_child(hint)

	return box
