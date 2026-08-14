class_name RunHeaderView
extends RefCounted

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")


static func build(
	header: HBoxContainer,
	run_state: RunState,
	registry: DataRegistry,
	_on_deck_view: Callable,
	on_pause_menu: Callable
) -> Dictionary:
	for child in header.get_children():
		child.queue_free()

	# 图标化顶栏统计（与战斗页风格统一）
	header.add_child(UiBuilders.header_chip(
		"res://assets/external/kenney_icons/suit_hearts.png",
		"生命 %d/%d" % [run_state.hp, run_state.max_hp], "生命"
	))
	header.add_child(UiBuilders.header_chip(
		"res://assets/icon_flask.png",
		"圣杯瓶 %d/%d" % [run_state.flasks, run_state.max_flasks], "圣杯瓶"
	))
	header.add_child(UiBuilders.header_chip(
		"res://assets/icon_soul.png",
		"卢恩 %d" % run_state.souls, "卢恩"
	))
	if run_state.relics.size() > 0:
		header.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/suit_diamonds.png",
			"护符 %d" % run_state.relics.size(), "护符"
		))
	if run_state.memory_stones > 0:
		header.add_child(UiBuilders.header_chip(
			"res://assets/external/kenney_icons/dice_skull.png",
			"记忆石 %d/%d" % [run_state.memory_stones, RunState.MAX_MEMORY_STONES], "记忆石"
		))
	header.add_child(UiBuilders.header_chip(
		"res://assets/external/kenney_icons/cards_stack.png",
		"牌组 %d" % run_state.deck.size(), "牌组"
	))

	var act := registry.get_act(run_state.act_index())
	var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
	if act != null:
		header.add_child(UiBuilders.header_chip(
			"",
			"%s · %d/%d · 层 %d/%d" % [
				act.title,
				local_step,
				RunState.FLOORS_PER_ACT,
				run_state.floor_index + 1,
				RunState.TOTAL_FLOORS,
			],
			"进度"
		))
	else:
		header.add_child(UiBuilders.header_chip(
			"",
			"层数 %d/%d" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS],
			"进度"
		))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	header.add_child(actions)

	var deck_button := Button.new()
	deck_button.text = "查看牌组"
	deck_button.custom_minimum_size = Vector2(118, 34)
	deck_button.pressed.connect(_on_deck_view)
	actions.add_child(deck_button)

	var menu_button := Button.new()
	menu_button.text = "☰"
	menu_button.tooltip_text = "选项"
	menu_button.custom_minimum_size = Vector2(40, 34)
	menu_button.pressed.connect(on_pause_menu)
	actions.add_child(menu_button)

	return {"deck": deck_button, "menu": menu_button}
