class_name MapScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const ActData = preload("res://data/ActData.gd")

const FRAGMENT_COST := 50


static func build(
	act: ActData,
	run_state: RunState,
	options: Array,
	on_option: Callable,
	on_fragment: Callable = Callable()
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

	# 地图碎片（法环式探图）：花卢恩预览下一层的路
	if run_state.next_floor_preview.size() > 0:
		wrap.add_child(_fragment_row(run_state, on_fragment))

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


static func _fragment_row(run_state: RunState, on_fragment: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if run_state.map_fragment_revealed:
		var hint := Label.new()
		var lines: Array[String] = []
		for opt_var in run_state.next_floor_preview:
			var opt: Dictionary = opt_var
			lines.append(str(opt.get("title", "?")))
		hint.text = "地图碎片（下一层）：" + " ｜ ".join(lines)
		hint.add_theme_color_override("font_color", GameTheme.GOLD)
		row.add_child(hint)
		return row
	var btn := Button.new()
	btn.text = "购买地图碎片（%d 卢恩）——预览下一层的路" % FRAGMENT_COST
	btn.disabled = run_state.souls < FRAGMENT_COST
	btn.pressed.connect(func():
		if run_state.souls < FRAGMENT_COST:
			return
		run_state.souls -= FRAGMENT_COST
		run_state.map_fragment_revealed = true
		if on_fragment.is_valid():
			on_fragment.call()
	)
	row.add_child(btn)
	return row
