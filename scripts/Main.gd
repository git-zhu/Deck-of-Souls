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
const GraceService = preload("res://scripts/core/GraceService.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")
const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const AshService = preload("res://scripts/core/AshService.gd")
const OriginData = preload("res://data/OriginData.gd")
const CardData = preload("res://data/CardData.gd")
const RelicData = preload("res://data/RelicData.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")
const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")

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
var _merchant_stock: Array = []
var _merchant_sold: Array[bool] = []
var _merchant_status: String = ""
var _merchant_cost_percent: int = 100

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
	_build_ui()
	_show_title()


func _on_combat_changed() -> void:
	if screen == GameScreen.COMBAT:
		_render_combat()


func _on_combat_ended(kind: String) -> void:
	match kind:
		"reward":
			_show_card_rewards(_finish_combat_rewards)
		"elite_reward":
			_show_card_rewards(_show_post_combat_relic_rewards)
		"act_clear":
			_show_act_clear(_show_post_combat_relic_rewards)
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
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	title_layer.add_child(box)

	var title := Label.new()
	title.text = "破碎法环：褪色者牌局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#e6c56d"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "从候王礼拜堂醒来，在宁姆格福的赐福之间改写牌组。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)

	var start := Button.new()
	start.text = "选择出身"
	start.custom_minimum_size = Vector2(240, 54)
	start.pressed.connect(_show_origin)
	box.add_child(start)

	var hint := Label.new()
	hint.text = "参考本体初始职业、武器、战灰、魔法、祷告与敌人设计。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#b9ac94"))
	box.add_child(hint)


func _show_origin() -> void:
	screen = GameScreen.ORIGIN
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	title_layer.add_child(wrap)

	var title := Label.new()
	title.text = "选择出身"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "出身只决定开局属性与装备。就像本体一样，之后的牌组会在交界地中改变。"
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(grid)

	for id in registry.all_origin_ids():
		grid.add_child(_origin_card(str(id)))


func _origin_card(origin_id: String) -> PanelContainer:
	var origin: OriginData = registry.get_origin(origin_id)
	var panel := UiBuilders.panel(GameTheme.PANEL)
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var name := Label.new()
	name.text = "%s  Lv.%d" % [origin.name, origin.level]
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var stats := Label.new()
	stats.text = origin.stats
	stats.add_theme_color_override("font_color", Color("#d8ccb4"))
	v.add_child(stats)

	var gear := Label.new()
	gear.text = origin.equipment
	gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gear)

	var note := Label.new()
	note.text = origin.note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("font_color", Color("#b9ac94"))
	v.add_child(note)

	var pick := Button.new()
	pick.text = "以此出身开始"
	pick.custom_minimum_size = Vector2(0, 42)
	pick.pressed.connect(func(): _start_run(origin_id))
	v.add_child(pick)
	return panel


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

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 16)
	map_layer.add_child(wrap)

	var act := registry.get_act(run_state.act_index())
	var title := Label.new()
	title.text = act.title if act != null else "褪色者路标"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	if act != null:
		var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
		desc.text = act.subtitle_template % [local_step, act.flavor]
	else:
		desc.text = "第 %d 层 / %d。" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS]
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	var options := map_gen.options_for_floor(run_state, registry, rng)
	for option in options:
		choices.add_child(_map_choice_card(option))


func _map_choice_card(option: Dictionary) -> PanelContainer:
	return UiBuilders.map_choice_card(option, func(): _choose_map_option(option))


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
		_show_remove_card_picker(
			event.title,
			"选择要从牌组中移除的一张牌。（牌组需多于 %d 张）" % min_size,
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				_show_event_result(event.title, "已从牌组移除《%s》。" % card_name)
		)
	else:
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
	var act := registry.get_act(run_state.act_index())
	var offer_ids: Array = []
	_merchant_cost_percent = 100
	if act != null:
		offer_ids = act.merchant_offer_ids
		_merchant_cost_percent = act.merchant_cost_percent
	_merchant_stock = merchant_service.roll_stock(run_state, registry, rng, 3, offer_ids)
	_merchant_sold.clear()
	for _i in _merchant_stock.size():
		_merchant_sold.append(false)
	_merchant_status = ""
	_show_merchant()


func _test_merchant_buy(offer_id: String) -> void:
	var offer := registry.get_merchant_offer(offer_id)
	if offer == null:
		push_error("Unknown merchant offer: %s" % offer_id)
		return
	var result: Dictionary = merchant_service.purchase(
		offer, run_state, registry, rng, _merchant_cost_percent
	)
	if not bool(result.get("ok", false)):
		push_error("Merchant purchase failed: %s" % str(result.get("message", "")))
		return
	if bool(result.get("pick_card", false)):
		push_error("Merchant offer %s requires card picker" % offer_id)
		return


func _show_merchant() -> void:
	_present_reward_layer(
		RewardLayerViews.build_merchant_screen(
			_merchant_stock,
			_merchant_sold,
			run_state.souls,
			_merchant_status,
			_merchant_cost_percent,
			merchant_service,
			run_state,
			_on_merchant_buy,
			_leave_merchant
		)
	)


func _on_merchant_buy(offer: MerchantOfferData, slot_index: int) -> void:
	if slot_index < _merchant_sold.size() and _merchant_sold[slot_index]:
		return
	var result: Dictionary = merchant_service.purchase(
		offer, run_state, registry, rng, _merchant_cost_percent
	)
	if not bool(result.get("ok", false)):
		_merchant_status = str(result.get("message", ""))
		_show_merchant()
		return
	var paid: int = int(result.get("paid_cost", offer.soul_cost))
	_merchant_sold[slot_index] = true
	if bool(result.get("pick_ash_replace", false)):
		_start_ash_replace_flow(
			func(removed_id: String, new_id: String):
				var old_c: CardData = registry.get_card(removed_id)
				var new_c: CardData = registry.get_card(new_id)
				var old_name := old_c.name if old_c != null else removed_id
				var new_name := new_c.name if new_c != null else new_id
				_merchant_status = "花费 %d 卢恩，《%s》已被战灰《%s》覆盖。" % [
					paid, old_name, new_name
				]
				_show_merchant()
		)
	elif bool(result.get("pick_card", false)):
		_show_remove_card_picker(
			"整理行囊",
			"选择要从牌组中移除的一张牌。",
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				_merchant_status = "花费 %d 卢恩，已从牌组移除《%s》。" % [paid, card_name]
				_show_merchant()
		)
	else:
		_merchant_status = str(result.get("message", ""))
		_show_merchant()


func _leave_merchant() -> void:
	run_state.advance_floor()
	_show_map()


func _visit_grace() -> void:
	var options := grace_service.roll_options(run_state, rng, 3)
	_show_grace_rest(options)


func _test_grace_pick(option_id: String) -> void:
	var option := registry.get_grace_option(option_id)
	if option == null:
		push_error("Unknown grace option: %s" % option_id)
		return
	var summary := grace_service.apply(option, run_state)
	if summary == GraceService.PICK_CARD:
		push_error("Grace pick %s requires card selection UI" % option_id)
		return
	run_state.advance_floor()


func _show_grace_rest(options: Array) -> void:
	_present_reward_layer(RewardLayerViews.build_grace_rest(options, _on_grace_option_picked))


func _on_grace_option_picked(option: GraceOptionData) -> void:
	var summary := grace_service.apply(option, run_state)
	if summary == GraceService.PICK_CARD:
		_show_remove_card_picker(
			"遗忘仪式",
			"选择要从牌组中移除的一张牌。",
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				_show_grace_result("遗忘仪式", "已从牌组移除《%s》。" % card_name)
		)
	elif summary == GraceService.PICK_ASH_REPLACE:
		_start_ash_replace_flow(
			func(removed_id: String, new_id: String):
				var old_c: CardData = registry.get_card(removed_id)
				var new_c: CardData = registry.get_card(new_id)
				var old_name := old_c.name if old_c != null else removed_id
				var new_name := new_c.name if new_c != null else new_id
				_show_grace_result(
					"战灰传授",
					"《%s》已被战灰《%s》覆盖。" % [old_name, new_name]
				)
		)
	else:
		_show_grace_result(option.title, summary)


func _show_grace_result(title_text: String, body_text: String) -> void:
	_present_reward_layer(
		RewardLayerViews.build_centered_continue(
			title_text,
			body_text,
			"继续",
			_advance_floor_and_show_map
		)
	)


func _start_ash_replace_flow(on_done: Callable) -> void:
	_show_remove_card_picker(
		"战灰替换",
		"选择要被战灰覆盖的牌。",
		_on_ash_card_picked_for_replace.bind(on_done),
		false
	)


func _on_ash_card_picked_for_replace(removed_id: String, on_done: Callable) -> void:
	var options: Array = ash_service.roll_ash_cards(registry, rng, 3)
	_show_ash_replace_picker(removed_id, options, on_done)


func _show_ash_replace_picker(removed_id: String, card_ids: Array, on_done: Callable) -> void:
	_present_reward_layer(
		RewardLayerViews.build_ash_picker(
			"战灰传授",
			"从下列战灰中选择一张，覆盖你选定的牌。",
			card_ids,
			registry,
			removed_id,
			run_state,
			on_done
		)
	)


func _show_remove_card_picker(
	title_text: String,
	hint_text: String,
	on_removed: Callable,
	remove_immediately: bool = true
) -> void:
	_present_reward_layer(
		RewardLayerViews.build_deck_picker(
			title_text,
			hint_text,
			_card_counts(run_state.deck),
			registry,
			run_state,
			on_removed,
			remove_immediately
		)
	)


func _show_message_end(title_text: String, body_text: String) -> void:
	_present_reward_layer(
		RewardLayerViews.build_centered_continue(title_text, body_text, "继续", _show_map)
	)


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
	var counts := _card_counts(run_state.deck)
	var popup := AcceptDialog.new()
	popup.title = "牌组"
	popup.ok_button_text = "关闭"
	popup.min_size = Vector2i(660, 520)
	add_child(popup)

	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 12)
	body.add_theme_constant_override("margin_right", 12)
	body.add_theme_constant_override("margin_top", 10)
	body.add_theme_constant_override("margin_bottom", 6)
	body.custom_minimum_size = Vector2(620, 440)
	popup.add_child(body)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(outer)

	var summary := Label.new()
	summary.text = "共 %d 张（%d 种）" % [run_state.deck.size(), counts.size()]
	summary.add_theme_font_size_override("font_size", 17)
	summary.add_theme_color_override("font_color", Color("#d8ccb4"))
	outer.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(596, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if counts.is_empty():
		var empty := Label.new()
		empty.text = "牌组为空。"
		empty.add_theme_color_override("font_color", Color("#9a8f78"))
		list.add_child(empty)
	else:
		var ids: Array = counts.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ca: CardData = registry.get_card(a)
			var cb: CardData = registry.get_card(b)
			return ca.name < cb.name if ca != null and cb != null else str(a) < str(b)
		)
		for id in ids:
			var card: CardData = registry.get_card(str(id))
			if card == null:
				continue
			list.add_child(UiBuilders.deck_summary_row(card, int(counts[id])))

	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)


func _card_counts(card_ids: Array[String]) -> Dictionary:
	var counts := {}
	for id in card_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _play_card(index: int) -> void:
	GameAudio.play(self, "ui_click")
	combat.play_card(index)


func _finish_combat_rewards() -> void:
	run_state.advance_floor()
	_show_map()


func _show_post_combat_relic_rewards() -> void:
	var offers: Array = relic_service.roll_relic_offers(run_state, registry, rng, 3)
	if offers.is_empty():
		_finish_combat_rewards()
	else:
		_show_relic_rewards(offers, _finish_combat_rewards)


func _show_act_clear(on_done: Callable) -> void:
	run_state.hp = run_state.max_hp
	run_state.flasks = run_state.max_flasks
	var act := registry.get_act(run_state.act_index())
	rewards = combat.roll_rewards(act)
	var act_title := act.title if act != null else "幕间休整"
	_present_reward_layer(
		RewardLayerViews.build_card_rewards(
			"%s · 幕末" % act_title,
			"雾门后的金光回满生命与圣杯瓶。选一张牌带走，然后挑选护符。",
			rewards,
			registry,
			func(card_id: String):
				run_state.deck.append(card_id)
				on_done.call(),
			on_done,
			"不取牌，继续"
		)
	)


func _show_card_rewards(on_done: Callable) -> void:
	var act := registry.get_act(run_state.act_index())
	rewards = combat.roll_rewards(act)
	_present_reward_layer(
		RewardLayerViews.build_card_rewards(
			"战利品",
			"选择一张牌加入牌组，或放弃卡牌奖励。",
			rewards,
			registry,
			func(card_id: String):
				run_state.deck.append(card_id)
				on_done.call(),
			on_done
		)
	)


func _show_relic_rewards(relic_ids: Array, on_done: Callable) -> void:
	_present_reward_layer(
		RewardLayerViews.build_relic_rewards(
			relic_ids, registry, relic_service, run_state, on_done
		)
	)


func _show_game_over() -> void:
	GameAudio.play(self, "defeat")
	screen = GameScreen.GAME_OVER
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	end_layer.add_child(box)
	var title := Label.new()
	title.text = "你死了"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("#b94b50"))
	box.add_child(title)
	var body := Label.new()
	body.text = "卢恩散落在冷石上。下一次，也许能多走一步。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var retry := Button.new()
	retry.text = "重新开始"
	retry.custom_minimum_size = Vector2(220, 50)
	retry.pressed.connect(_start_run)
	box.add_child(retry)


func _show_victory() -> void:
	GameAudio.play(self, "victory")
	screen = GameScreen.VICTORY
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	end_layer.add_child(box)
	var title := Label.new()
	title.text = "传说暂时闭环"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#e6c56d"))
	box.add_child(title)
	var body := Label.new()
	body.text = "接肢贵族倒下。你带着 %d 卢恩和 %d 张牌离开雾门。" % [run_state.souls, run_state.deck.size()]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var retry := Button.new()
	retry.text = "再开一局"
	retry.custom_minimum_size = Vector2(220, 50)
	retry.pressed.connect(_start_run)
	box.add_child(retry)


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
