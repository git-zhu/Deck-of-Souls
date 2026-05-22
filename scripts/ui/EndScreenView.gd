class_name EndScreenView
extends RefCounted

const DEFEAT_RED := Color("#b94b50")
const VICTORY_GOLD := Color("#e6c56d")


static func build_game_over(on_retry: Callable) -> Control:
	return _centered_screen(
		"你死了",
		58,
		DEFEAT_RED,
		"卢恩散落在冷石上。下一次，也许能多走一步。",
		"重新开始",
		on_retry
	)


static func build_victory(souls: int, deck_size: int, on_retry: Callable) -> Control:
	return _centered_screen(
		"传说暂时闭环",
		48,
		VICTORY_GOLD,
		"接肢贵族倒下。你带着 %d 卢恩和 %d 张牌离开雾门。" % [souls, deck_size],
		"再开一局",
		on_retry
	)


static func _centered_screen(
	title_text: String,
	title_size: int,
	title_color: Color,
	body_text: String,
	button_text: String,
	on_press: Callable
) -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", title_color)
	box.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)

	var retry := Button.new()
	retry.text = button_text
	retry.custom_minimum_size = Vector2(220, 50)
	retry.pressed.connect(on_press)
	box.add_child(retry)

	return box
