extends Control

enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }

const CARD_W := 132.0
const CARD_H := 178.0
const STARTER_DECK := [
	"longsword", "longsword", "longsword",
	"heater_shield", "heater_shield", "heater_shield",
	"halberd", "crimson_flask"
]

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const AshService = preload("res://scripts/core/AshService.gd")
const CardData = preload("res://data/CardData.gd")
const RelicData = preload("res://data/RelicData.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")
const TitleScreenView = preload("res://scripts/ui/TitleScreenView.gd")
const OriginScreenView = preload("res://scripts/ui/OriginScreenView.gd")
const MapScreenView = preload("res://scripts/ui/MapScreenView.gd")
const DeckPopupView = preload("res://scripts/ui/DeckPopupView.gd")
const EndScreenView = preload("res://scripts/ui/EndScreenView.gd")
const RunRewardFlow = preload("res://scripts/core/RunRewardFlow.gd")

var rng := RandomNumberGenerator.new()
var screen := GameScreen.TITLE
var registry: DataRegistry
var run_state: RunState
var combat: CombatController
var map_gen := MapGenerator.new()
var grace_service := GraceService.new()
var merchant_service := MerchantService.new()
var ash_service := AshService.new()
var relic_service := RelicService.new()
var event_service := EventService.new()
var rewards: Array[String] = []
var reward_flow: RunRewardFlow

var deck: Array[String]:
	get:
		return run_state.deck if run_state != null else []
	set(value):
		if run_state != null:
			run_state.deck = value

var hp: int:
	get:
		return run_state.hp if run_state != null else 0
	set(value):
		if run_state != null:
			run_state.hp = value

var root: MarginContainer
var title_layer: Control
var map_layer: Control
var combat_layer: Control
var reward_layer: Control
var end_layer: Control
var header: HBoxContainer
var log_box: RichTextLabel
var hand_row: HBoxContainer
var enemy_panel: PanelContainer
var player_panel: PanelContainer
var end_turn_button: Button
var flask_button: Button
var deck_button: Button

func _ready() -> void:
	rng.randomize()
	registry = DataRegistry.new()
	registry.load_all()
	grace_service.load_from_registry(registry)
	merchant_service.load_from_registry(registry)
	run_state = RunState.new()
	combat = CombatController.new(run_state, registry, rng)
	combat.log_message.connect(_log)
	combat.combat_changed.connect(_on_combat_changed)
	combat.combat_ended.connect(_on_combat_ended)
	reward_flow = RunRewardFlow.new(self)
	_build_ui()
	_show_title()


func _on_combat_changed() -> void:
	if screen == GameScreen.COMBAT:
		_render_combat()


func _on_combat_ended(kind: String) -> void:
	match kind:
		"reward":
			reward_flow.show_card_rewards(reward_flow.finish_combat_rewards)
		"elite_reward":
			reward_flow.show_card_rewards(reward_flow.show_post_combat_relic_rewards)
		"act_clear":
			reward_flow.show_act_clear(reward_flow.show_post_combat_relic_rewards)
		"run_victory":
			_show_victory()
		"defeat":
			_show_game_over()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 22)
	root.add_theme_constant_override("margin_right", 22)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	root.add_child(stack)

	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	title_layer = _new_layer(stack)
	map_layer = _new_layer(stack)
	combat_layer = _new_layer(stack)
	reward_layer = _new_layer(stack)
	end_layer = _new_layer(stack)

	_setup_theme()


func _setup_theme() -> void:
	GameTheme.apply_theme(self)


func _new_layer(parent: Control) -> Control:
	var layer := Control.new()
	layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(layer)
	return layer


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _hide_layers() -> void:
	for layer in [title_layer, map_layer, combat_layer, reward_layer, end_layer]:
		layer.visible = false
	_clear(header)


func _present_reward_layer(root: Control) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_layer.add_child(root)


func _show_title() -> void:
	screen = GameScreen.TITLE
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	title_layer.add_child(TitleScreenView.build(_show_origin))


func _show_origin() -> void:
	screen = GameScreen.ORIGIN
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	_build_header()
	title_layer.add_child(OriginScreenView.build(registry, _start_run))


func _start_run(origin_id: String = "vagabond") -> void:
	var seed := randi()
	rng.seed = seed
	var origin := registry.get_origin(origin_id)
	if origin == null:
		origin = registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, seed)
	log_lines.clear()
	_log("出身：%s。装备：%s。" % [origin.name, origin.equipment])
	_show_map()


func _show_map() -> void:
	screen = GameScreen.MAP
	_hide_layers()
	map_layer.visible = true
	_clear(map_layer)
	_build_header()
	var act := registry.get_act(run_state.act_index())
	var options := map_gen.options_for_floor(run_state, registry, rng)
	map_layer.add_child(MapScreenView.build(act, run_state, options, _choose_map_option))


func _choose_map_option(option: Dictionary) -> void:
	GameAudio.play(self, "ui_click")
	match str(option.get("kind", "")):
		"combat":
			_begin_combat(registry.pick_named_enemy(rng, str(option.get("enemy", "")), false, false))
		"elite":
			_begin_combat(registry.pick_named_enemy(rng, str(option.get("enemy", "")), true, false))
		"boss":
			_begin_combat(registry.pick_named_enemy(rng, str(option.get("enemy", "")), false, true))
		"grace":
			_visit_grace()
		"merchant":
			_visit_merchant()
		"event":
			_visit_event(str(option.get("event_id", "")))


func _visit_event(event_id: String) -> void:
	var event := registry.get_event(event_id) as MapEventData
	if event == null:
		push_error("Unknown map event: %s" % event_id)
		run_state.advance_floor()
		_show_map()
		return
	_show_event(event)


func _show_event(event: MapEventData) -> void:
	_present_reward_layer(
		RewardLayerViews.build_event_screen(
			event,
			func(ch): return event_service.is_choice_eligible(ch, run_state, registry),
			func(ch): _on_event_choice(ch, event)
		)
	)


func _on_event_choice(choice: MapEventChoiceData, event: MapEventData) -> void:
	var summary := event_service.apply(choice, run_state, registry, rng)
	if summary == EventService.PICK_CARD:
		var min_size: int = choice.min_deck_size if choice.min_deck_size > 0 else 6
		reward_flow.show_remove_card_picker(
			event.title,
			"选择要从牌组中移除的一张牌。（牌组需多于 %d 张）" % min_size,
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				_show_event_result(event.title, "已从牌组移除《%s》。" % card_name)
		)
	else:
		var follow_id := str(choice.follow_event_id).strip_edges()
		if follow_id != "":
			var next_event := registry.get_event(follow_id) as MapEventData
			if next_event != null:
				_show_event(next_event)
				return
		_show_event_result(event.title, summary)


func _show_event_result(title_text: String, body_text: String) -> void:
	_present_reward_layer(
		RewardLayerViews.build_centered_continue(
			title_text,
			body_text,
			"继续",
			_advance_floor_and_show_map
		)
	)


func _advance_floor_and_show_map() -> void:
	run_state.advance_floor()
	_show_map()


func _visit_merchant() -> void:
	reward_flow.visit_merchant()


func _test_merchant_buy(offer_id: String) -> void:
	reward_flow.test_merchant_buy(offer_id)


func _visit_grace() -> void:
	reward_flow.visit_grace()


func _test_grace_pick(option_id: String) -> void:
	reward_flow.test_grace_pick(option_id)


func _begin_combat(template: Dictionary) -> void:
	screen = GameScreen.COMBAT
	_log_reset()
	combat.start_combat(template)
	_render_combat()


func _render_combat() -> void:
	_hide_layers()
	combat_layer.visible = true
	_clear(combat_layer)
	_build_header()
	var refs := CombatHudView.build(
		run_state,
		combat,
		registry,
		_log_text(),
		CARD_W,
		CARD_H,
		_play_card,
		combat.use_flask,
		combat.end_player_turn
	)
	combat_layer.add_child(refs.root)
	player_panel = refs.player_panel
	enemy_panel = refs.enemy_panel
	log_box = refs.log_box
	hand_row = refs.hand_row
	flask_button = refs.flask_button
	end_turn_button = refs.end_turn_button


func _build_header() -> void:
	deck_button = RunHeaderView.build(
		header,
		run_state,
		registry,
		screen == GameScreen.COMBAT,
		_show_deck_view
	)


func _show_deck_view() -> void:
	DeckPopupView.show(self, run_state.deck, registry)


func _play_card(index: int) -> void:
	GameAudio.play(self, "ui_click")
	combat.play_card(index)


func _show_game_over() -> void:
	GameAudio.play(self, "defeat")
	screen = GameScreen.GAME_OVER
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(EndScreenView.build_game_over(_start_run))


func _show_victory() -> void:
	GameAudio.play(self, "victory")
	screen = GameScreen.VICTORY
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(
		EndScreenView.build_victory(run_state.souls, run_state.deck.size(), _start_run)
	)


var log_lines: Array[String] = []


func _log_reset() -> void:
	log_lines.clear()


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > GameTheme.MAX_LOG_LINES:
		log_lines.pop_front()


func _log_text() -> String:
	var out := ""
	for line in log_lines:
		var safe := line.replace("[", "[[]").replace("]", "[]]")
		out += "[color=#d9ccb3]%s[/color]\n" % safe
	return out
