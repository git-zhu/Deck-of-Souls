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
const TargetingLine = preload("res://scripts/ui/TargetingLine.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")


# 拖拽投放回调：把拖来的卡打到目标敌人（target_id = "enemy_0/enemy_1..."；"" = 默认选中目标）
static func _make_drop_handler(on_play_card: Callable) -> Callable:
	return func(card_index: int, target_id: String) -> void:
		on_play_card.call(card_index, target_id)


static func _enemy_names_text(combat: CombatController) -> String:
	if combat.enemies.size() == 1:
		return str(combat.enemies[0].get("name", ""))
	var names: Array = []
	for e in combat.enemies:
		names.append(str(e.get("name", "")))
	return "、".join(names)


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

	# 拖拽瞄准线覆盖层（全屏，z 最高）
	var aim_line := TargetingLine.new()
	aim_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(aim_line)
	aim_line.move_to_front()

	# ── 顶行（最优布局）：玩家 HUD（左） + 意图横幅（中） + 敌人 HUD（右），并排居中拉近操作 ──
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
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

	# 意图横幅内联到顶行中央（不单独占行）
	var intent_panel := UiBuilders.intent_banner(
		str(combat.enemy_intent.get("kind", "")),
		combat.intent_text()
	)
	intent_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_row.add_child(intent_panel)
	var intent_kind := str(combat.enemy_intent.get("kind", ""))
	if intent_kind in ["attack", "attack_block", "attack_rot"]:
		var pulse := intent_panel.create_tween().set_loops()
		pulse.tween_property(intent_panel, "modulate", Color(1, 1, 1, 0.82), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(intent_panel, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		intent_panel.tree_exiting.connect(func() -> void:
			if pulse != null and pulse.is_valid():
				pulse.kill()
		)

	# 敌人区：多敌人紧凑 HUD（每个含 DropZone 目标投放 + 瞄准线锚点）
	var enemy_area := HBoxContainer.new()
	enemy_area.add_theme_constant_override("separation", 10)
	enemy_area.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_row.add_child(enemy_area)

	for ei in range(combat.enemies.size()):
		var e: Dictionary = combat.enemies[ei]
		var is_target := ei == combat.target_index
		var e_panel := UiBuilders.compact_fighter_hud(
			str(e.name),
			int(e.hp),
			int(e.max_hp),
			int(e.block),
			{
				"rot": int(e.rot),
				"bleed": int(e.bleed),
				"vulnerable": int(e.vulnerable),
				"strength": int(e.strength),
				"stance": int(e.stance_now),
			},
			ENEMY_PANEL_BG,
			true,
			int(e.stance_now),
			int(e.stance_max)
		)
		e_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if is_target:
			e_panel.modulate = Color(1.06, 1.0, 0.85, 1.0)
		enemy_area.add_child(e_panel)
		# 每个敌人一个投放目标（target_id = "enemy_i"，供 Main 指定目标出牌）
		var zone := DropZone.new()
		zone.setup("enemy_%d" % ei, _make_drop_handler(on_play_card))
		zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		e_panel.add_child(zone)
		zone.move_to_front()
		if ei == 0:
			refs.enemy_panel = e_panel
		# 注册瞄准线锚点（敌人 HUD 中心，布局后刷新坐标）
		aim_line.zone_centers["enemy_%d" % ei] = {"center": Vector2.ZERO, "radius": 70.0}

	# ── 中区：日志（贴左）+ 战斗舞台（占其余），玩家/敌人关系居中呈现 ──
	var mid_area := HBoxContainer.new()
	mid_area.add_theme_constant_override("separation", 12)
	mid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_area.custom_minimum_size = Vector2(0, 150)
	main.add_child(mid_area)

	# 日志贴左（用户方案）：竖排窄条，低视觉权重
	var log_left := VBoxContainer.new()
	log_left.custom_minimum_size = Vector2(200, 0)
	log_left.add_theme_constant_override("separation", 4)
	mid_area.add_child(log_left)
	var log_toggle := Button.new()
	log_toggle.text = "日志 ▾"
	log_toggle.flat = true
	log_toggle.custom_minimum_size = Vector2(64, 24)
	log_toggle.tooltip_text = "展开 / 折叠战斗日志"
	log_left.add_child(log_toggle)
	refs.log_box = RichTextLabel.new()
	refs.log_box.bbcode_enabled = true
	refs.log_box.fit_content = false
	refs.log_box.scroll_following = true
	refs.log_box.scroll_active = false
	refs.log_box.custom_minimum_size = Vector2(200, 0)
	refs.log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	refs.log_box.add_theme_font_size_override("normal_font_size", 13)
	refs.log_box.add_theme_color_override("default_color", Color(0.72, 0.68, 0.6, 0.8))
	refs.log_box.text = log_bbcode
	log_left.add_child(refs.log_box)

	# 战斗舞台（收窄，占中区剩余）
	var stage_wrap := Control.new()
	stage_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_area.add_child(stage_wrap)
	var stage_frame := GildedFrame.new()
	stage_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage_frame)
	var stage := UiBuilders.combat_stage("褪色者", _enemy_names_text(combat))
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage)

	# 战斗区域投放目标（拖到舞台中央也可出牌）
	var stage_zone := DropZone.new()
	stage_zone.setup("", _make_drop_handler(on_play_card))
	stage_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(stage_zone)
	stage_zone.move_to_front()

	# ── 资源 HUD：回合数 + 能量球 + 抽/弃/耗 chip 行 ──
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 10)
	resource_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(resource_row)

	var turn: int = main.get_meta("combat_turn", 0) + 1
	resource_row.add_child(UiBuilders.turn_label(turn))
	main.set_meta("combat_turn", turn)

	var orb := UiBuilders.energy_orb(combat.ember, combat.max_ember)
	resource_row.add_child(orb)
	# 能量不足时脉动提示（弱，不影响操作）
	if combat.ember < combat.max_ember:
		var orb_pulse := orb.create_tween().set_loops()
		orb_pulse.tween_property(orb, "modulate", Color(1, 1, 1, 0.75), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb_pulse.tween_property(orb, "modulate", Color(1, 1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb.tree_exiting.connect(func() -> void:
			if orb_pulse != null and orb_pulse.is_valid():
				orb_pulse.kill()
		)

	resource_row.add_child(UiBuilders.resource_chip("抽牌", str(run_state.draw_pile.size())))
	resource_row.add_child(UiBuilders.resource_chip("弃牌", str(run_state.discard_pile.size())))
	resource_row.add_child(UiBuilders.resource_chip("消耗", str(run_state.exhaust_pile.size())))

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
	hand_scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				hand_scroll.scroll_horizontal += int(mb.factor * 90.0) * (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
				hand_scroll.accept_event()
		elif ev is InputEventScreenDrag:
			hand_scroll.scroll_horizontal -= int((ev as InputEventScreenDrag).relative.x)
			hand_scroll.accept_event()
	)

	refs.hand_row = HBoxContainer.new()
	refs.hand_row.add_theme_constant_override("separation", 10)
	refs.hand_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_scroll.add_child(refs.hand_row)

	# 手牌卡：连接拖拽信号到瞄准线
	for i in range(run_state.hand.size()):
		var card_id: String = run_state.hand[i]
		var card_data: CardData = registry.get_card(card_id)
		if card_data != null:
			var card_btn := UiBuilders.card_button(
				card_data,
				i,
				combat,
				card_w,
				card_h,
				on_play_card.bind(i)
			)
			refs.hand_row.add_child(card_btn)
			if card_btn is DragCard:
				var dc := card_btn as DragCard
				dc.drag_started.connect(func(_idx: int, from_g: Vector2) -> void:
					aim_line.begin(from_g)
				)
				dc.drag_ended.connect(func() -> void:
					aim_line.end()
				)

	refs.end_turn_button = UiBuilders.end_turn_button(combat.combat_over, on_end_turn)
	refs.end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(refs.end_turn_button)

	# 中区日志折叠开关（展开/收起日志列宽）
	refs.log_box.set_meta("log_expanded", true)
	log_toggle.pressed.connect(func() -> void:
		var expanded: bool = refs.log_box.get_meta("log_expanded", false)
		expanded = not expanded
		refs.log_box.set_meta("log_expanded", expanded)
		log_toggle.text = "日志 ▾" if expanded else "日志 ▸"
		refs.log_box.scroll_active = expanded
		log_left.custom_minimum_size.x = 200.0 if expanded else 24.0
		refs.log_box.visible = expanded
	)

	# 布局完成后刷新瞄准线锚点（敌人 HUD 实际全局坐标）
	_refresh_aim_anchors(aim_line, enemy_area)

	return refs


static func _refresh_aim_anchors(aim_line: TargetingLine, enemy_area: HBoxContainer) -> void:
	# 布局后敌人面板有实际坐标；此处立即读取（build 返回前 children 已在树中）
	for child in enemy_area.get_children():
		var zone := child as PanelContainer
		if zone == null:
			continue
		for sub in zone.get_children():
			if sub is DropZone:
				var dz := sub as DropZone
				if aim_line.zone_centers.has(dz.target_id):
					var center := zone.get_global_rect().get_center()
					(aim_line.zone_centers[dz.target_id] as Dictionary)["center"] = center
				break
