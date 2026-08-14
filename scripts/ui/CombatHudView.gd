class_name CombatHudView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const CombatHudRefs = preload("res://scripts/ui/CombatHudRefs.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardData = preload("res://data/CardData.gd")

const PLAYER_PANEL_BG := Color("#2a241b")
const ENEMY_PANEL_BG := Color("#2b1d1b")


static func build(
	run_state: RunState,
	combat: CombatController,
	registry: DataRegistry,
	log_bbcode: String,
	card_w: float,
	card_h: float,
	on_play_card: Callable,
	on_flask: Callable,
	on_end_turn: Callable
) -> CombatHudRefs:
	var refs := CombatHudRefs.new()

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	refs.root = main

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	main.add_child(field)

	refs.player_panel = UiBuilders.fighter_panel(
		"褪色者",
		run_state.hp,
		run_state.max_hp,
		combat.block,
		"腐败 %d  出血 %d  易伤 %d" % [
			run_state.player_rot, run_state.player_bleed, run_state.player_vulnerable
		],
		PLAYER_PANEL_BG
	)
	refs.player_panel.custom_minimum_size = Vector2(250, 0)
	field.add_child(refs.player_panel)

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
	var intent_kind := str(combat.enemy_intent.get("kind", ""))
	intent.add_theme_color_override("font_color", GameTheme.intent_color(intent_kind))
	center.add_child(intent)

	refs.log_box = RichTextLabel.new()
	refs.log_box.bbcode_enabled = true
	refs.log_box.fit_content = false
	refs.log_box.scroll_following = true
	refs.log_box.custom_minimum_size = Vector2(270, 170)
	refs.log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	refs.log_box.text = log_bbcode
	center.add_child(refs.log_box)

	refs.enemy_panel = UiBuilders.fighter_panel(
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
		ENEMY_PANEL_BG,
		int(combat.enemy.stance_now),
		int(combat.enemy.stance_max)
	)
	refs.enemy_panel.custom_minimum_size = Vector2(280, 0)
	field.add_child(refs.enemy_panel)

	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation", 18)
	main.add_child(piles)
	piles.add_child(UiBuilders.small_stat("抽牌 %d" % run_state.draw_pile.size()))
	piles.add_child(UiBuilders.small_stat("弃牌 %d" % run_state.discard_pile.size()))
	piles.add_child(UiBuilders.small_stat("消耗 %d" % run_state.exhaust_pile.size()))
	piles.add_child(UiBuilders.small_stat("集中 %d/%d" % [combat.ember, combat.max_ember]))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	main.add_child(actions)

	refs.flask_button = Button.new()
	refs.flask_button.text = "圣杯瓶 (%d)" % run_state.flasks
	refs.flask_button.disabled = run_state.flasks <= 0 or run_state.hp >= run_state.max_hp
	refs.flask_button.pressed.connect(on_flask)
	actions.add_child(refs.flask_button)

	refs.end_turn_button = Button.new()
	refs.end_turn_button.text = "结束回合"
	refs.end_turn_button.pressed.connect(on_end_turn)
	actions.add_child(refs.end_turn_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, card_h + 18)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(hand_scroll)
	# 鼠标滚轮横向滚动手牌（PC 便捷操作）
	hand_scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				hand_scroll.scroll_horizontal += int(mb.factor * 90.0) * (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
				hand_scroll.accept_event()
		# 触屏滑动：拖动手牌横向滚动（手机端便捷操作）
		elif ev is InputEventScreenDrag:
			hand_scroll.scroll_horizontal -= int((ev as InputEventScreenDrag).relative.x)
			hand_scroll.accept_event()
	)

	refs.hand_row = HBoxContainer.new()
	refs.hand_row.add_theme_constant_override("separation", 10)
	refs.hand_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_scroll.add_child(refs.hand_row)

	for i in range(run_state.hand.size()):
		var card_id: String = run_state.hand[i]
		var card_data: CardData = registry.get_card(card_id)
		if card_data != null:
			refs.hand_row.add_child(
				UiBuilders.card_button(
					card_data,
					i,
					combat,
					card_w,
					card_h,
					on_play_card.bind(i)
				)
			)

	return refs
