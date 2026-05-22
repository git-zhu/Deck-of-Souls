class_name RunPauseMenuView
extends RefCounted

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const GameTheme = preload("res://scripts/ui/GameTheme.gd")


static func build(
	on_resume: Callable,
	on_return_title: Callable,
	on_abandon_run: Callable
) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiBuilders.panel(GameTheme.PANEL, GameTheme.BORDER, 2)
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(_action_button("继续游戏", on_resume))
	box.add_child(_action_button("返回标题", on_return_title))
	box.add_child(_action_button("放弃本局", on_abandon_run))

	return root


static func _action_button(label_text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(280, 48)
	btn.pressed.connect(on_press)
	return btn
