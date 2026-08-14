class_name CombatHudView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const CombatHudRefs = preload("res://scripts/ui/CombatHudRefs.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardData = preload("res://data/CardData.gd")

const PLAYER_PANEL_BG := Color("#1d1a15")
const ENEMY_PANEL_BG := Color("#1d1714")


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

	# ── 顶行：玩家 HUD（左） + 敌人 HUD（右） ──
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	main.add_child(top_row)

	refs.player_panel = UiBuilders.compact_fighter_hud(
		"褪色者",
		run_state.hp,
		run_state.max_hp,
		combat.block,
		{
			"rot": run_state.player_rot,
			"bleed": run_state.player_bleed,
			"vulnerable": run_state.player_vulnerable,
			"strength": run_state.player_strength,
		},
		PLAYER_PANEL_BG
	)
	refs.player_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_row.add_child(refs.player_panel)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	refs.enemy_panel = UiBuilders.compact_fighter_hud(
		combat.enemy.name,
		combat.enemy.hp,
		combat.enemy.max_hp,
		int(combat.enemy.block),
		{
			"rot": combat.enemy.rot,
			"bleed": combat.enemy.bleed,
			"vulnerable": combat.enemy.vulnerable,
			"strength": combat.enemy.strength,
			"stance": int(combat.enemy.stance_now),
		},
		ENEMY_PANEL_BG,
		true,
		int(combat.enemy.stance_now),
		int(combat.enemy.stance_max)
	)
	refs.enemy_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_row.add_child(refs.enemy_panel)

	# ── 敌人意图：高优先级视觉元素 ──
	var intent_panel := UiBuilders.intent_banner(
		str(combat.enemy_intent.get("kind", "")),
		combat.intent_text()
	)
	main.add_child(intent_panel)

	# ── 中央战斗区域：玩家 ←→ 敌人 ──
	var stage := UiBuilders.combat_stage("褪色者", combat.enemy.name)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(stage)

	# ── 资源 HUD：紧凑 chip 行 ──
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 8)
	resource_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(resource_row)
	resource_row.add_child(UiBuilders.resource_chip("抽牌", str(run_state.draw_pile.size())))
	resource_row.add_child(UiBuilders.resource_chip("弃牌", str(run_state.discard_pile.size())))
	resource_row.add_child(UiBuilders.resource_chip("消耗", str(run_state.exhaust_pile.size())))
	resource_row.add_child(UiBuilders.resource_chip("集中", "%d/%d" % [combat.ember, combat.max_ember]))

	# ── 底部操作行：圣杯瓶 + 手牌 + 结束回合（主 CTA） ──
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	main.add_child(bottom_row)

	refs.flask_button = UiBuilders.flask_button(
		run_state.flasks,
		run_state.flasks <= 0 or run_state.hp >= run_state.max_hp,
		on_flask
	)
	bottom_row.add_child(refs.flask_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, card_h + 16)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_row.add_child(hand_scroll)
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

	refs.end_turn_button = UiBuilders.end_turn_button(combat.combat_over, on_end_turn)
	bottom_row.add_child(refs.end_turn_button)

	# ── 战斗日志：低视觉权重（细条、弱化） ──
	refs.log_box = RichTextLabel.new()
	refs.log_box.bbcode_enabled = true
	refs.log_box.fit_content = false
	refs.log_box.scroll_following = true
	refs.log_box.scroll_active = false
	refs.log_box.custom_minimum_size = Vector2(0, 44)
	refs.log_box.add_theme_font_size_override("normal_font_size", 13)
	refs.log_box.add_theme_color_override("default_color", Color(0.72, 0.68, 0.6, 0.8))
	refs.log_box.text = log_bbcode
	main.add_child(refs.log_box)

	return refs
