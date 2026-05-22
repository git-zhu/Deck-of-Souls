class_name RunHeaderView
extends RefCounted

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")


static func build(
	header: HBoxContainer,
	run_state: RunState,
	registry: DataRegistry,
	is_combat_screen: bool,
	on_deck_view: Callable
) -> Button:
	for child in header.get_children():
		child.queue_free()

	header.add_child(UiBuilders.small_stat("生命 %d/%d" % [run_state.hp, run_state.max_hp]))
	header.add_child(UiBuilders.small_stat("圣杯瓶 %d/%d" % [run_state.flasks, run_state.max_flasks]))
	header.add_child(UiBuilders.small_stat("卢恩 %d" % run_state.souls))
	if run_state.relics.size() > 0:
		header.add_child(UiBuilders.small_stat("护符 %d" % run_state.relics.size()))
	if run_state.memory_stones > 0:
		header.add_child(
			UiBuilders.small_stat("记忆石 %d/%d" % [run_state.memory_stones, RunState.MAX_MEMORY_STONES])
		)
	header.add_child(UiBuilders.small_stat("牌组 %d" % run_state.deck.size()))
	if is_combat_screen:
		header.add_child(
			UiBuilders.small_stat(
				"抽牌 %d  弃牌 %d" % [run_state.draw_pile.size(), run_state.discard_pile.size()]
			)
		)

	var act := registry.get_act(run_state.act_index())
	var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
	if act != null:
		header.add_child(
			UiBuilders.small_stat(
				"%s · %d/%d · 层 %d/%d" % [
					act.title,
					local_step,
					RunState.FLOORS_PER_ACT,
					run_state.floor_index + 1,
					RunState.TOTAL_FLOORS,
				]
			)
		)
	else:
		header.add_child(
			UiBuilders.small_stat("层数 %d/%d" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS])
		)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var deck_button := Button.new()
	deck_button.text = "查看牌组"
	deck_button.custom_minimum_size = Vector2(118, 34)
	deck_button.pressed.connect(on_deck_view)
	header.add_child(deck_button)
	return deck_button
