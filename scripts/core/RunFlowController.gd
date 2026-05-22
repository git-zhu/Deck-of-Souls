class_name RunFlowController
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const ActData = preload("res://data/ActData.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const MapScreenView = preload("res://scripts/ui/MapScreenView.gd")
const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")

var host: Node


func _init(main_host: Node) -> void:
	host = main_host


func show_map() -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var map_gen = host.get("map_gen")
	var act: ActData = registry.get_act(run_state.act_index()) as ActData
	var options: Array = map_gen.options_for_floor(run_state, registry, rng)
	host.call(
		"_enter_map_layer",
		MapScreenView.build(act, run_state, options, choose_map_option)
	)


func choose_map_option(option: Dictionary) -> void:
	GameAudio.play(host, "ui_click")
	var registry = host.get("registry")
	var rng = host.get("rng")
	match str(option.get("kind", "")):
		"combat":
			begin_combat(
				registry.pick_named_enemy(rng, str(option.get("enemy", "")), false, false)
			)
		"elite":
			begin_combat(
				registry.pick_named_enemy(rng, str(option.get("enemy", "")), true, false)
			)
		"boss":
			begin_combat(
				registry.pick_named_enemy(rng, str(option.get("enemy", "")), false, true)
			)
		"grace":
			host.get("reward_flow").visit_grace()
		"merchant":
			host.get("reward_flow").visit_merchant()
		"event":
			visit_event(str(option.get("event_id", "")))


func visit_event(event_id: String) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var event := registry.get_event(event_id) as MapEventData
	if event == null:
		push_error("Unknown map event: %s" % event_id)
		run_state.advance_floor()
		show_map()
		return
	show_event(event)


func show_event(event: MapEventData) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var event_service = host.get("event_service")
	host.get("reward_flow").set_event_export(event.id)
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_event_screen(
			event,
			func(ch): return event_service.is_choice_eligible(ch, run_state, registry),
			func(ch): on_event_choice(ch, event)
		)
	)


func on_event_choice(choice: MapEventChoiceData, event: MapEventData) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var event_service = host.get("event_service")
	var reward_flow = host.get("reward_flow")
	var summary: String = event_service.apply(choice, run_state, registry, rng)
	if summary == EventService.PICK_CARD:
		var min_size: int = choice.min_deck_size if choice.min_deck_size > 0 else 6
		reward_flow.show_remove_card_picker(
			event.title,
			"选择要从牌组中移除的一张牌。（牌组需多于 %d 张）" % min_size,
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				show_event_result(event.title, "已从牌组移除《%s》。" % card_name)
		)
	else:
		var follow_id := str(choice.follow_event_id).strip_edges()
		if follow_id != "":
			var next_event := registry.get_event(follow_id) as MapEventData
			if next_event != null:
				show_event(next_event)
				return
		show_event_result(event.title, summary)


func show_event_result(title_text: String, body_text: String) -> void:
	host.get("reward_flow").set_grace_result_export(title_text, body_text)
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_centered_continue(
			title_text,
			body_text,
			"继续",
			advance_floor_and_show_map
		)
	)


func advance_floor_and_show_map() -> void:
	host.get("run_state").advance_floor()
	show_map()


func begin_combat(template: Dictionary) -> void:
	host.call("_begin_combat", template)


func on_combat_ended(kind: String) -> void:
	var reward_flow = host.get("reward_flow")
	match kind:
		"reward":
			reward_flow.show_card_rewards(reward_flow.finish_combat_rewards)
		"elite_reward":
			reward_flow.show_card_rewards(reward_flow.show_post_combat_relic_rewards)
		"act_clear":
			reward_flow.show_act_clear(reward_flow.show_post_combat_relic_rewards)
		"run_victory":
			host.call("_show_victory")
		"defeat":
			host.call("_show_game_over")
