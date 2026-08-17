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
const ProfileService = preload("res://scripts/core/ProfileService.gd")
const RunState = preload("res://scripts/core/RunState.gd")

var host: Node
var pending_tower_rune: String = ""  # I4：神授塔试炼进行中（记录待激活卢恩）
var pending_jar_duel: bool = false   # I7：壶哥切磋进行中


func _init(main_host: Node) -> void:
	host = main_host


func show_map() -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var map_gen = host.get("map_gen")
	var act: ActData = registry.get_act(run_state.act_index()) as ActData
	var options: Array = map_gen.options_for_floor(run_state, registry, rng)
	_inject_kindling_event(run_state, registry, options)
	_inject_divine_tower(run_state, registry, options)
	_inject_echo_event(run_state, registry, options)
	_build_next_floor_preview(run_state, registry, map_gen)
	host.call(
		"_enter_map_layer",
		MapScreenView.build(act, run_state, options, choose_map_option, show_map)
	)


# I6 少女的引火：第 11 层（终局前夜）强制献祭事件，覆盖全部选项
func _inject_kindling_event(run_state, registry, options: Array) -> void:
	if run_state.floor_index != 10 or str(run_state.kindling) != "":
		return
	var ev: MapEventData = registry.get_event("maiden_kindling") as MapEventData
	if ev == null:
		return
	options.clear()
	options.append({
		"kind": "event",
		"cardType": "event",
		"event_id": "maiden_kindling",
		"title": ev.title,
		"body": ev.body,
	})


# I4 大卢恩朝圣：击败幕末 BOSS 后，下一幕首层出现神授塔（试炼 → 二选一激活）
func _inject_divine_tower(run_state, registry, options: Array) -> void:
	if run_state.floor_index != 4 and run_state.floor_index != 8:
		return
	var rune_id := "rune_margit" if run_state.floor_index == 4 else "rune_crucible"
	if not run_state.great_runes.has(rune_id):
		return
	if str(run_state.great_runes.get(rune_id)) != "":
		return  # 已激活/已拒绝：朝圣只出现一次
	options.append({
		"kind": "divine_tower",
		"cardType": "explore",
		"rune_id": rune_id,
		"title": "神授塔",
		"body": "高塔刺进云层，你体内的大卢恩微微发烫——它需要在这里被激活。（试炼：精英守卫，错过不再）",
	})


# 死亡回响：上一局死在本层 → 注入「上一局的痕迹」事件
func _inject_echo_event(run_state, registry, options: Array) -> void:
	var profile := ProfileService.load_profile()
	var echo_var: Variant = profile.get("echo", {})
	var echo: Dictionary = echo_var if typeof(echo_var) == TYPE_DICTIONARY else {}
	if echo.is_empty() or int(echo.get("floor", -1)) != run_state.floor_index:
		return
	if int(echo.get("souls", 0)) <= 0:
		return
	var ev: MapEventData = registry.get_event("echo_of_last_run") as MapEventData
	if ev == null:
		return
	options.push_front({
		"kind": "event",
		"cardType": "event",
		"event_id": "echo_of_last_run",
		"title": ev.title,
		"body": ev.body,
	})


# 地图碎片：用独立种子生成下一层选项快照（不扰动主 RNG）
func _build_next_floor_preview(run_state, registry, map_gen) -> void:
	if run_state.floor_index + 1 >= RunState.TOTAL_FLOORS:
		run_state.next_floor_preview = []
		return
	var preview_rng := RandomNumberGenerator.new()
	preview_rng.seed = run_state.run_seed + (run_state.floor_index + 1) * 7919
	var original_floor: int = run_state.floor_index
	run_state.floor_index = original_floor + 1
	run_state.next_floor_preview = map_gen.options_for_floor(run_state, registry, preview_rng)
	run_state.floor_index = original_floor


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
		"divine_tower":
			# I4：神授塔试炼——精英守卫，胜利后二选一激活大卢恩
			pending_tower_rune = str(option.get("rune_id", ""))
			var guardian := "狮子混种" if pending_tower_rune == "rune_margit" else "守墓斗士"
			begin_combat(registry.pick_named_enemy(rng, guardian, true, false))


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
			"选择要从牌组中移除的一张牌。（牌组需多于 %d 张）" % min_size,			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				show_event_result(event.title, "已从牌组移除《%s》。" % card_name)
		)
	elif summary == EventService.DUEL_JAR:
		# I7 壶哥切磋：进入真刀真枪的战斗（败北即出局，战壶从不放水）
		pending_jar_duel = true
		begin_combat(registry.pick_named_enemy(rng, "战壶亚历山大", true, false))
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
	# I4 神授塔试炼胜利：跳过常规奖励，直接进入大卢恩激活
	if kind in ["reward", "elite_reward"] and pending_tower_rune != "":
		var rune_id := pending_tower_rune
		pending_tower_rune = ""
		reward_flow.show_rune_activation(rune_id, reward_flow.finish_combat_rewards)
		return
	# I7 壶哥切磋胜利：赠壶之碎片，不走常规卡牌奖励
	if kind in ["reward", "elite_reward"] and pending_jar_duel:
		pending_jar_duel = false
		var run_state = host.get("run_state")
		host.get("relic_service").add_relic(run_state, host.get("registry"), "pot_shard")
		if not run_state.event_flags.has("jar_duel_won"):
			run_state.event_flags.append("jar_duel_won")
		reward_flow.show_grace_result(
			"战壶的认可",
			"亚历山大把你举起来晃了晃，又轻轻放下。『够硬！』——护符《壶之碎片》加入了行囊。"
		)
		return
	match kind:
		"reward":
			reward_flow.show_card_rewards(reward_flow.finish_combat_rewards)
		"elite_reward":
			reward_flow.show_card_rewards(reward_flow.show_post_combat_relic_rewards)
		"act_clear":
			# I4：先授卢恩（未激活），再走追忆/幕末流程
			_grant_great_rune()
			# I5：追忆二选一 → 幕末卡牌 → 护符
			reward_flow.show_remembrance(
				_last_boss_name(),
				reward_flow.show_act_clear.bind(reward_flow.show_post_combat_relic_rewards)
			)
		"run_victory":
			_grant_great_rune()
			# I5：终局追忆 → 胜利结算
			reward_flow.show_remembrance(_last_boss_name(), func(): host.call("_show_victory"))
		"defeat":
			host.call("_show_game_over")


# I4：击败幕末 BOSS 授予该幕大卢恩（第三幕的卢恩无需激活——你即是神授塔）
func _grant_great_rune() -> void:
	var run_state = host.get("run_state")
	var rune_id := ""
	match run_state.act_index():
		0:
			rune_id = "rune_margit"
		1:
			rune_id = "rune_crucible"
		2:
			rune_id = "rune_scion"
	if rune_id == "" or run_state.great_runes.has(rune_id):
		return
	run_state.great_runes[rune_id] = "" if rune_id != "rune_scion" else "innate"


func _last_boss_name() -> String:
	var combat = host.get("combat")
	if combat != null and not combat.enemies.is_empty():
		return str(combat.enemies[0].name)
	return ""
