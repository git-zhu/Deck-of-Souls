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
const GildedFrame = preload("res://scripts/ui/GildedFrame.gd")
const DropZone = preload("res://scripts/ui/DropZone.gd")


# 拖拽投放回调：把拖来的卡打到目标敌人（target_id 预留多敌人；当前单敌人恒为 ""）
static func _make_drop_handler(on_play_card: Callable) -> Callable:
	return func(card_index: int, target_id: String) -> void:
		on_play_card.call(card_index)


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

	# 敌人投放目标区（接收手牌拖拽；target_id 预留多敌人）
	var enemy_zone := DropZone.new()
	enemy_zone.setup("", _make_drop_handler(on_play_card))
	enemy_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	refs.enemy_panel.add_child(enemy_zone)
	enemy_zone.move_to_front()

	# ── 敌人意图：高优先级视觉元素（攻击意图轻微脉冲强调） ──
	var intent_panel := UiBuilders.intent_banner(
		str(combat.enemy_intent.get("kind", "")),
		combat.intent_text()
	)
	main.add_child(intent_panel)
	var intent_kind := str(combat.enemy_intent.get("kind", ""))
	if intent_kind in ["attack", "attack_block", "attack_rot"]:
		var pulse := intent_panel.create_tween().set_loops()
		pulse.tween_property(intent_panel, "modulate", Color(1, 1, 1, 0.82), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(intent_panel, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		intent_panel.tree_exiting.connect(func() -> void:
			if pulse != null and pulse.is_valid():
				pulse.kill()
		)

	# ── 中央战斗区域：玩家 ←→ 敌人（镀金框 + 主体；有最小高度防止折叠） ──
	var stage_wrap := Control.new()
	stage_wrap.custom_minimum_size = Vector2(0, 150)
	stage_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(stage_wrap)
	var stage_frame := GildedFrame.new()
	stage_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage_frame)
	var stage := UiBuilders.combat_stage("褪色者", combat.enemy.name)
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage)

	# 战斗区域投放目标（拖到舞台中央也可出牌）
	var stage_zone := DropZone.new()
	stage_zone.setup("", _make_drop_handler(on_play_card))
	stage_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage_zone)
	stage_zone.move_to_front()

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
	refs.flask_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(refs.flask_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, card_h + 12)
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
	refs.end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(refs.end_turn_button)

	# ── 战斗日志：低视觉权重（细条、弱化），带折叠/展开开关 ──
	var log_row := HBoxContainer.new()
	log_row.add_theme_constant_override("separation", 8)
	main.add_child(log_row)

	var log_toggle := Button.new()
	log_toggle.text = "日志 ▸"
	log_toggle.flat = true
	log_toggle.custom_minimum_size = Vector2(64, 0)
	log_toggle.tooltip_text = "展开 / 折叠战斗日志"
	log_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	log_row.add_child(log_toggle)

	refs.log_box = RichTextLabel.new()
	refs.log_box.bbcode_enabled = true
	refs.log_box.fit_content = false
	refs.log_box.scroll_following = true
	refs.log_box.scroll_active = false
	refs.log_box.custom_minimum_size = Vector2(0, 36)
	refs.log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refs.log_box.add_theme_font_size_override("normal_font_size", 13)
	refs.log_box.add_theme_color_override("default_color", Color(0.72, 0.68, 0.6, 0.8))
	refs.log_box.text = log_bbcode
	log_row.add_child(refs.log_box)

	# 折叠开关：44px（收拢，隐藏滚动）↔ 140px（展开，启用滚动）
	refs.log_box.set_meta("log_expanded", false)
	log_toggle.pressed.connect(func() -> void:
		var expanded: bool = refs.log_box.get_meta("log_expanded", false)
		expanded = not expanded
		refs.log_box.set_meta("log_expanded", expanded)
		log_toggle.text = "日志 ▾" if expanded else "日志 ▸"
		refs.log_box.scroll_active = expanded
		var target_h := 140.0 if expanded else 44.0
		var tw := refs.log_box.create_tween()
		tw.tween_property(refs.log_box, "custom_minimum_size", Vector2(0, target_h), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

	return refs
