class_name MapScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const ActData = preload("res://data/ActData.gd")


static func build(
	act: ActData,
	run_state: RunState,
	options: Array,
	on_option: Callable
) -> Control:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = act.title if act != null else "褪色者路标"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GameTheme.TITLE_GOLD)
	wrap.add_child(title)

	var desc := Label.new()
	if act != null:
		var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
		desc.text = act.subtitle_template % [local_step, act.flavor]
	else:
		desc.text = "第 %d 层 / %d。" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS]
	desc.add_theme_color_override("font_color", GameTheme.BODY_MUTED)
	wrap.add_child(desc)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	for option in options:
		var opt: Dictionary = option
		choices.add_child(
			UiBuilders.map_choice_card(opt, on_option.bind(opt))
		)

	return wrap
