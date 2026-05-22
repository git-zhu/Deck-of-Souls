class_name RewardLayerViews
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const CardData = preload("res://data/CardData.gd")
const RelicData = preload("res://data/RelicData.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")
const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")


static func _full_vbox(separation: int = 14) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", separation)
	return wrap


static func _heading_label(text: String, size: int = 32) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GameTheme.TITLE_GOLD)
	return label


static func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", GameTheme.BODY_MUTED)
	return label


static func choice_offer_card(
	title_text: String,
	body_text: String,
	button_text: String,
	disabled: bool,
	on_press: Callable
) -> PanelContainer:
	var panel := UiBuilders.panel(GameTheme.PANEL)
	panel.custom_minimum_size = Vector2(0, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name := Label.new()
	name.text = title_text
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	btn.text = button_text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.disabled = disabled
	if not disabled:
		btn.pressed.connect(on_press)
	v.add_child(btn)
	return panel


static func build_centered_continue(
	title_text: String,
	body_text: String,
	button_text: String,
	on_continue: Callable
) -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GameTheme.GOLD)
	box.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(720, 0)
	box.add_child(body)

	var next := Button.new()
	next.text = button_text
	next.custom_minimum_size = Vector2(220, 48)
	next.pressed.connect(on_continue)
	box.add_child(next)
	return box


static func card_reward_button(card: CardData, on_press: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 320)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if card != null:
		button.text = "%s\n%s  集中:%d\n稀有度:%s\n\n%s" % [
			card.name, card.type, card.cost, card.rarity, card.text
		]
	else:
		button.text = "未知卡牌"
	button.pressed.connect(on_press)
	return button


static func build_merchant_screen(
	stock: Array,
	sold: Array[bool],
	souls: int,
	status: String,
	cost_percent: int,
	merchant_service: MerchantService,
	run_state: RunState,
	on_buy: Callable,
	on_leave: Callable
) -> Control:
	var wrap := _full_vbox(14)
	wrap.add_child(_heading_label("商人咖列"))
	wrap.add_child(_muted_label("当前卢恩：%d" % souls))

	if not status.is_empty():
		var status_label := _muted_label(status)
		status_label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		wrap.add_child(status_label)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	for slot_index in stock.size():
		var offer := stock[slot_index] as MerchantOfferData
		if offer == null:
			continue
		var is_sold: bool = sold[slot_index] if slot_index < sold.size() else false
		choices.add_child(
			merchant_offer_card(
				offer, slot_index, is_sold, cost_percent,
				merchant_service, run_state, on_buy
			)
		)

	var leave := Button.new()
	leave.text = "离开商店"
	leave.custom_minimum_size = Vector2(220, 48)
	leave.pressed.connect(on_leave)
	wrap.add_child(leave)
	return wrap


static func merchant_offer_card(
	offer: MerchantOfferData,
	slot_index: int,
	sold: bool,
	cost_percent: int,
	merchant_service: MerchantService,
	run_state: RunState,
	on_buy: Callable
) -> PanelContainer:
	var button_text := "售罄"
	var disabled := true
	if not sold:
		var price: int = merchant_service.effective_cost(offer, cost_percent)
		button_text = "购买 · %d 卢恩" % price
		disabled = not merchant_service.can_afford(offer, run_state, cost_percent)
	return choice_offer_card(
		offer.title,
		offer.body,
		button_text,
		disabled,
		on_buy.bind(offer, slot_index) if not sold else Callable()
	)


static func build_grace_rest(options: Array, on_pick: Callable) -> Control:
	var wrap := _full_vbox(16)
	wrap.add_child(_heading_label("赐福点"))
	wrap.add_child(_muted_label("金色引导在脚下聚拢。选择一项赐福升级，然后继续上路。"))

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	for opt in options:
		var option := opt as GraceOptionData
		if option != null:
			choices.add_child(grace_choice_card(option, on_pick))
	return wrap


static func grace_choice_card(option: GraceOptionData, on_pick: Callable) -> PanelContainer:
	return choice_offer_card(
		option.title,
		option.body,
		"选择",
		false,
		on_pick.bind(option)
	)


static func build_event_screen(
	event: MapEventData,
	is_eligible: Callable,
	on_choice: Callable
) -> Control:
	var wrap := _full_vbox(14)
	wrap.add_child(_heading_label(event.title))
	wrap.add_child(_muted_label(event.body))

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
		btn.disabled = not bool(is_eligible.call(ch))
		btn.pressed.connect(on_choice.bind(ch))
		choices.add_child(btn)
	return wrap


static func build_card_rewards(
	screen_title: String,
	desc_text: String,
	card_ids: Array,
	registry: DataRegistry,
	on_pick: Callable,
	on_skip: Callable,
	skip_label: String = "放弃卡牌奖励"
) -> Control:
	var box := _full_vbox(14)

	var title := Label.new()
	title.text = screen_title
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GameTheme.GOLD)
	box.add_child(title)

	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)

	for id in card_ids:
		var c: CardData = registry.get_card(str(id))
		row.add_child(card_reward_button(c, on_pick.bind(str(id))))

	var skip := Button.new()
	skip.text = skip_label
	skip.custom_minimum_size = Vector2(240, 48)
	skip.pressed.connect(on_skip)
	box.add_child(skip)
	return box


static func build_relic_rewards(
	relic_ids: Array,
	registry: DataRegistry,
	relic_service: RelicService,
	run_state: RunState,
	on_done: Callable
) -> Control:
	var wrap := _full_vbox(14)

	var title := Label.new()
	title.text = "护符"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GameTheme.GOLD)
	wrap.add_child(title)
	wrap.add_child(_muted_label("强敌留下的未绑定护符，选一件带走。"))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	wrap.add_child(row)

	for relic_id in relic_ids:
		var relic := registry.get_relic(str(relic_id)) as RelicData
		if relic != null:
			row.add_child(relic_reward_panel(relic, relic_service, run_state, registry, on_done))

	var skip := Button.new()
	skip.text = "放弃护符"
	skip.custom_minimum_size = Vector2(220, 48)
	skip.pressed.connect(on_done)
	wrap.add_child(skip)
	return wrap


static func relic_reward_panel(
	relic: RelicData,
	relic_service: RelicService,
	run_state: RunState,
	registry: DataRegistry,
	on_done: Callable
) -> PanelContainer:
	var panel := UiBuilders.panel(GameTheme.PANEL)
	panel.custom_minimum_size = Vector2(0, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var name := Label.new()
	name.text = relic.name
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name)

	var body := Label.new()
	body.text = relic.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var hook := Label.new()
	hook.text = relic_service.hook_summary(relic)
	hook.add_theme_color_override("font_color", GameTheme.RELIC_HOOK)
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


static func build_deck_picker(
	title_text: String,
	hint_text: String,
	counts: Dictionary,
	registry: DataRegistry,
	run_state: RunState,
	on_removed: Callable,
	remove_immediately: bool = true
) -> Control:
	var wrap := _full_vbox(12)
	wrap.add_child(_heading_label(title_text))
	wrap.add_child(_muted_label(hint_text))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for card_id in counts.keys():
		var c: CardData = registry.get_card(str(card_id))
		var label := c.name if c != null else str(card_id)
		var count: int = int(counts[card_id])
		var btn := Button.new()
		if c != null:
			btn.text = "%s ×%d\n%s  集中:%d\n%s" % [c.name, count, c.type, c.cost, c.text]
		else:
			btn.text = "%s ×%d" % [label, count]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 96)
		btn.pressed.connect(func():
			var cid := str(card_id)
			if remove_immediately:
				var idx := run_state.deck.find(cid)
				if idx >= 0:
					run_state.deck.remove_at(idx)
			on_removed.call(cid)
		)
		list.add_child(btn)
	return wrap


static func build_ash_picker(
	title_text: String,
	hint_text: String,
	card_ids: Array,
	registry: DataRegistry,
	removed_id: String,
	run_state: RunState,
	on_picked: Callable
) -> Control:
	var wrap := _full_vbox(14)
	wrap.add_child(_heading_label(title_text))
	wrap.add_child(_muted_label(hint_text))

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
			on_picked.call(removed_id, picked)
		)
		row.add_child(btn)
	return wrap
