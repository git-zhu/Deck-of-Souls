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
var draw_label: Label
var discard_label: Label
var exhaust_label: Label
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
	bg.color = Color("#16130f")
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
	var theme := Theme.new()
	var font_size := 18
	theme.set_font_size("font_size", "Label", font_size)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_font_size("font_size", "RichTextLabel", 16)
	theme.set_color("font_color", "Label", Color("#e8ddc7"))
	theme.set_color("font_color", "Button", Color("#f0e5cd"))
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("#d8b15d"))
	self.theme = theme


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
	var panel := _panel(Color("#242018"))
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
		var card := _map_choice_card(option)
		choices.add_child(card)


func _map_choice_card(option: Dictionary) -> PanelContainer:
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name := Label.new()
	name.text = option.title
	name.add_theme_font_size_override("font_size", 28)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var body := Label.new()
	body.text = option.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	btn.text = "介入" if str(option.get("kind", "")) == "event" else "踏入"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func(): _choose_map_option(option))
	v.add_child(btn)
	return panel


func _choose_map_option(option: Dictionary) -> void:
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
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = event.title
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = event.body
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var choices := VBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 10)
	wrap.add_child(choices)

	for choice in event.choices:
		var ch := choice as MapEventChoiceData
		if ch == null:
			continue
		var btn := Button.new()
		btn.text = ch.label
		if ch.soul_cost > 0:
			btn.text += " · %d 卢恩" % ch.soul_cost
		btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = not event_service.is_choice_eligible(ch, run_state, registry)
		btn.pressed.connect(func(): _on_event_choice(ch, event))
		choices.add_child(btn)


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
				_show_event_result(event.title, "已从牌组移除《%s》。" % card_name),
			true
		)
	else:
		_show_event_result(event.title, summary)


func _show_event_result(title_text: String, body_text: String) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(720, 0)
	box.add_child(body)
	var next := Button.new()
	next.text = "继续"
	next.custom_minimum_size = Vector2(220, 48)
	next.pressed.connect(func():
		run_state.advance_floor()
		_show_map()
	)
	box.add_child(next)


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
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = "商人咖列"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var souls_label := Label.new()
	souls_label.text = "当前卢恩：%d" % run_state.souls
	souls_label.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(souls_label)

	if not _merchant_status.is_empty():
		var status := Label.new()
		status.text = _merchant_status
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_color_override("font_color", Color("#d8ccb4"))
		wrap.add_child(status)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	for slot_index in _merchant_stock.size():
		var offer := _merchant_stock[slot_index] as MerchantOfferData
		choices.add_child(_merchant_offer_card(offer, slot_index))

	var leave := Button.new()
	leave.text = "离开商店"
	leave.custom_minimum_size = Vector2(220, 48)
	leave.pressed.connect(_leave_merchant)
	wrap.add_child(leave)


func _merchant_offer_card(offer: MerchantOfferData, slot_index: int) -> PanelContainer:
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name := Label.new()
	name.text = offer.title
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var body := Label.new()
	body.text = offer.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	var sold: bool = _merchant_sold[slot_index] if slot_index < _merchant_sold.size() else false
	if sold:
		btn.text = "售罄"
		btn.disabled = true
	else:
		var price: int = merchant_service.effective_cost(offer, _merchant_cost_percent)
		btn.text = "购买 · %d 卢恩" % price
		btn.disabled = not merchant_service.can_afford(offer, run_state, _merchant_cost_percent)
		btn.pressed.connect(_on_merchant_buy.bind(offer, slot_index))
	v.add_child(btn)
	return panel


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
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 16)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = "赐福点"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "金色引导在脚下聚拢。选择一项赐福升级，然后继续上路。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	for opt in options:
		choices.add_child(_grace_choice_card(opt as GraceOptionData))


func _grace_choice_card(option: GraceOptionData) -> PanelContainer:
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name := Label.new()
	name.text = option.title
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var body := Label.new()
	body.text = option.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func(): _on_grace_option_picked(option))
	v.add_child(btn)
	return panel


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
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(720, 0)
	box.add_child(body)
	var next := Button.new()
	next.text = "继续"
	next.custom_minimum_size = Vector2(220, 48)
	next.pressed.connect(func():
		run_state.advance_floor()
		_show_map()
	)
	box.add_child(next)


func _start_ash_replace_flow(on_done: Callable) -> void:
	_show_remove_card_picker(
		"战灰替换",
		"选择要被战灰覆盖的牌。",
		func(removed_id: String):
			var options: Array = ash_service.roll_ash_cards(registry, rng, 3)
			_show_ash_replace_picker(removed_id, options, on_done),
		false
	)


func _show_ash_replace_picker(removed_id: String, card_ids: Array, on_done: Callable) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = "战灰传授"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var hint := Label.new()
	hint.text = "从下列战灰中选择一张，覆盖你选定的牌。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(hint)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	wrap.add_child(row)

	for card_id in card_ids:
		var c: CardData = registry.get_card(str(card_id))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(250, 300)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c != null:
			btn.text = "%s\n%s  集中:%d\n稀有度:%s\n\n%s" % [c.name, c.type, c.cost, c.rarity, c.text]
		else:
			btn.text = str(card_id)
		btn.pressed.connect(func():
			var picked := str(card_id)
			run_state.replace_card_in_deck(removed_id, picked)
			on_done.call(removed_id, picked)
		)
		row.add_child(btn)


func _show_remove_card_picker(
	title_text: String,
	hint_text: String,
	on_removed: Callable,
	remove_immediately: bool = true
) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 12)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	wrap.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var counts := _card_counts(run_state.deck)
	for card_id in counts.keys():
		var c: CardData = registry.get_card(str(card_id))
		var label := c.name if c != null else str(card_id)
		var count: int = int(counts[card_id])
		var btn := Button.new()
		btn.text = "%s ×%d" % [label, count]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(func():
			var cid := str(card_id)
			if remove_immediately:
				var idx := run_state.deck.find(cid)
				if idx >= 0:
					run_state.deck.remove_at(idx)
			on_removed.call(cid)
		)
		list.add_child(btn)


func _show_message_end(title_text: String, body_text: String) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(720, 0)
	box.add_child(body)
	var next := Button.new()
	next.text = "继续"
	next.custom_minimum_size = Vector2(220, 48)
	next.pressed.connect(_show_map)
	box.add_child(next)


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

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	combat_layer.add_child(main)

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	main.add_child(field)

	player_panel = _fighter_panel(
		"褪色者",
		run_state.hp,
		run_state.max_hp,
		combat.block,
		"腐败 %d  出血 %d  易伤 %d" % [run_state.player_rot, run_state.player_bleed, run_state.player_vulnerable],
		Color("#2a241b")
	)
	player_panel.custom_minimum_size = Vector2(250, 0)
	field.add_child(player_panel)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(270, 0)
	center.add_theme_constant_override("separation", 8)
	field.add_child(center)
	var intent := Label.new()
	intent.text = "敌方意图：%s" % combat.intent_text()
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent.add_theme_font_size_override("font_size", 23)
	intent.add_theme_color_override("font_color", Color("#e6c56d"))
	center.add_child(intent)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.fit_content = false
	log_box.scroll_following = true
	log_box.custom_minimum_size = Vector2(270, 170)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.text = _log_text()
	center.add_child(log_box)

	enemy_panel = _fighter_panel(
		combat.enemy.name,
		combat.enemy.hp,
		combat.enemy.max_hp,
		int(combat.enemy.block),
		"姿态 %d/%d  腐败 %d  出血 %d  易伤 %d  力量 %d" % [
			combat.enemy.stance_now,
			combat.enemy.stance_max,
			combat.enemy.rot,
			combat.enemy.bleed,
			combat.enemy.vulnerable,
			combat.enemy.strength,
		],
		Color("#2b1d1b")
	)
	enemy_panel.custom_minimum_size = Vector2(280, 0)
	field.add_child(enemy_panel)

	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation", 18)
	main.add_child(piles)
	draw_label = _small_stat("抽牌 %d" % run_state.draw_pile.size())
	discard_label = _small_stat("弃牌 %d" % run_state.discard_pile.size())
	exhaust_label = _small_stat("消耗 %d" % run_state.exhaust_pile.size())
	piles.add_child(draw_label)
	piles.add_child(discard_label)
	piles.add_child(exhaust_label)
	piles.add_child(_small_stat("集中 %d/%d" % [combat.ember, combat.max_ember]))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	main.add_child(actions)
	flask_button = Button.new()
	flask_button.text = "圣杯瓶 (%d)" % run_state.flasks
	flask_button.disabled = run_state.flasks <= 0 or run_state.hp >= run_state.max_hp
	flask_button.pressed.connect(func(): combat.use_flask())
	actions.add_child(flask_button)
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.pressed.connect(func(): combat.end_player_turn())
	actions.add_child(end_turn_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, CARD_H + 18)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(hand_scroll)

	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_scroll.add_child(hand_row)
	for i in range(run_state.hand.size()):
		hand_row.add_child(_card_button(run_state.hand[i], i))


func _build_header() -> void:
	_clear(header)
	header.add_child(_small_stat("生命 %d/%d" % [run_state.hp, run_state.max_hp]))
	header.add_child(_small_stat("圣杯瓶 %d/%d" % [run_state.flasks, run_state.max_flasks]))
	header.add_child(_small_stat("卢恩 %d" % run_state.souls))
	if run_state.relics.size() > 0:
		header.add_child(_small_stat("护符 %d" % run_state.relics.size()))
	if run_state.memory_stones > 0:
		header.add_child(_small_stat("记忆石 %d/%d" % [run_state.memory_stones, RunState.MAX_MEMORY_STONES]))
	header.add_child(_small_stat("牌组 %d" % run_state.deck.size()))
	if screen == GameScreen.COMBAT:
		header.add_child(_small_stat("抽牌 %d  弃牌 %d" % [run_state.draw_pile.size(), run_state.discard_pile.size()]))
	var act := registry.get_act(run_state.act_index())
	var local_step: int = (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
	if act != null:
		header.add_child(_small_stat(
			"%s · %d/%d · 层 %d/%d" % [
				act.title,
				local_step,
				RunState.FLOORS_PER_ACT,
				run_state.floor_index + 1,
				RunState.TOTAL_FLOORS,
			]
		))
	else:
		header.add_child(_small_stat("层数 %d/%d" % [run_state.floor_index + 1, RunState.TOTAL_FLOORS]))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	deck_button = Button.new()
	deck_button.text = "查看牌组"
	deck_button.custom_minimum_size = Vector2(118, 34)
	deck_button.pressed.connect(_show_deck_view)
	header.add_child(deck_button)


func _small_stat(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#d8ccb4"))
	label.add_theme_font_size_override("font_size", 18)
	return label


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
			list.add_child(_deck_card_row(card, int(counts[id])))

	popup.popup_centered()
	popup.close_requested.connect(func(): popup.queue_free())


func _deck_card_row(card: CardData, count: int) -> PanelContainer:
	const ROW_TEXT_WIDTH := 520.0
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242018")
	style.border_color = card.tone.darkened(0.1)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(h)

	var badge := Label.new()
	badge.text = "×%d" % count
	badge.custom_minimum_size = Vector2(40, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color("#e0c06c"))
	h.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)

	var title := Label.new()
	title.text = "%s  ·  %s  ·  集中 %d" % [card.name, card.type, card.cost]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", card.tone.lightened(0.25))
	info.add_child(title)

	var desc := Label.new()
	desc.text = card.text
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size.x = ROW_TEXT_WIDTH
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	info.add_child(desc)

	return row


func _card_counts(card_ids: Array[String]) -> Dictionary:
	var counts := {}
	for id in card_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#4f4535")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _fighter_panel(n: String, cur_hp: int, full_hp: int, cur_block: int, status: String, color: Color) -> PanelContainer:
	var panel := _panel(color)
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var name := Label.new()
	name.text = n
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e4c06d"))
	v.add_child(name)
	var hp_label := Label.new()
	hp_label.text = "生命 %d / %d" % [cur_hp, full_hp]
	hp_label.add_theme_font_size_override("font_size", 22)
	v.add_child(hp_label)
	var bar := ProgressBar.new()
	bar.max_value = full_hp
	bar.value = cur_hp
	bar.custom_minimum_size = Vector2(0, 22)
	v.add_child(bar)
	var block_label := Label.new()
	block_label.text = "护甲 %d" % cur_block
	v.add_child(block_label)
	var status_label := Label.new()
	status_label.text = status
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#c8bca5"))
	v.add_child(status_label)
	return panel


func _card_button(card_id: String, index: int) -> Button:
	var c: CardData = registry.get_card(card_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(CARD_W, CARD_H)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = "%s\n%s  集中:%d\n\n%s" % [c.name, c.type, c.cost, c.text]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = c.text
	button.disabled = c.cost > combat.ember or combat.combat_over
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = c.tone.darkened(0.45)
	style.border_color = c.tone.lightened(0.2)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(func(): combat.play_card(index))
	return button


func _play_card(index: int) -> void:
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
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var act := registry.get_act(run_state.act_index())
	rewards = combat.roll_rewards(act)
	var act_title := act.title if act != null else "幕间休整"

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = "%s · 幕末" % act_title
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var desc := Label.new()
	desc.text = "雾门后的金光回满生命与圣杯瓶。选一张牌带走，然后挑选护符。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for id in rewards:
		row.add_child(_reward_card(id, on_done))

	var skip := Button.new()
	skip.text = "不取牌，继续"
	skip.custom_minimum_size = Vector2(240, 48)
	skip.pressed.connect(on_done)
	box.add_child(skip)


func _show_card_rewards(on_done: Callable) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var act := registry.get_act(run_state.act_index())
	rewards = combat.roll_rewards(act)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = "战利品"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var desc := Label.new()
	desc.text = "选择一张牌加入牌组，或放弃卡牌奖励。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for id in rewards:
		row.add_child(_reward_card(id, on_done))

	var skip := Button.new()
	skip.text = "放弃卡牌奖励"
	skip.custom_minimum_size = Vector2(240, 48)
	skip.pressed.connect(on_done)
	box.add_child(skip)


func _show_relic_rewards(relic_ids: Array, on_done: Callable) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	reward_layer.add_child(wrap)

	var title := Label.new()
	title.text = "护符"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	wrap.add_child(title)

	var hint := Label.new()
	hint.text = "强敌留下的未绑定护符，选一件带走。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(hint)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	wrap.add_child(row)

	for relic_id in relic_ids:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic != null:
			row.add_child(_relic_reward_panel(relic, on_done))

	var skip := Button.new()
	skip.text = "放弃护符"
	skip.custom_minimum_size = Vector2(220, 48)
	skip.pressed.connect(on_done)
	wrap.add_child(skip)


func _relic_reward_panel(relic: RelicData, on_done: Callable) -> PanelContainer:
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var name := Label.new()
	name.text = relic.name
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var body := Label.new()
	body.text = relic.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var hook := Label.new()
	hook.text = relic_service.hook_summary(relic)
	hook.add_theme_color_override("font_color", Color("#9ec9e8"))
	v.add_child(hook)

	var btn := Button.new()
	btn.text = "带走"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func():
		relic_service.add_relic(run_state, registry, relic.id)
		on_done.call()
	)
	v.add_child(btn)
	return panel


func _reward_card(card_id: String, on_done: Callable) -> Button:
	var c: CardData = registry.get_card(card_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 320)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s\n%s  集中:%d\n稀有度:%s\n\n%s" % [c.name, c.type, c.cost, c.rarity, c.text]
	button.pressed.connect(func():
		run_state.deck.append(card_id)
		on_done.call()
	)
	return button


func _show_game_over() -> void:
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
	if log_lines.size() > 9:
		log_lines.pop_front()


func _log_text() -> String:
	var out := ""
	for line in log_lines:
		var safe := line.replace("[", "[[]").replace("]", "[]]")
		out += "[color=#d9ccb3]%s[/color]\n" % safe
	return out
