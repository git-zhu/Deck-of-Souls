class_name CombatHudView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const CombatHudRefs = preload("res://scripts/ui/CombatHudRefs.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardData = preload("res://data/CardData.gd")

const PLAYER_PANEL_BG := Color("#1c232b")  # 玩家侧：冷灰蓝
const ENEMY_PANEL_BG := Color("#2b1e1a")   # 敌人侧：暖褐红
const DropZone = preload("res://scripts/ui/DropZone.gd")
const TargetingLine = preload("res://scripts/ui/TargetingLine.gd")
const DragCard = preload("res://scripts/ui/DragCard.gd")


class SelectionOverlay:
	extends Control
	const GameTheme = preload("res://scripts/ui/GameTheme.gd")
	var _t: float = 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0 or size.y <= 0:
			return
		var pulse := 0.75 + 0.25 * sin(_t * 4.0)
		var gold := GameTheme.GOLD
		var r := Rect2(Vector2.ZERO, size)

		# 外发光
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.border_color = Color(gold.r, gold.g, gold.b, 0.35 * pulse)
		glow.set_border_width_all(5)
		glow.set_corner_radius_all(10)
		draw_style_box(glow, r.grow(4))

		# 脉冲金边框
		var border := StyleBoxFlat.new()
		border.bg_color = Color(gold.r, gold.g, gold.b, 0.08 * pulse)
		border.border_color = Color(gold.r, gold.g, gold.b, 0.95 * pulse)
		border.set_border_width_all(3)
		border.set_corner_radius_all(8)
		draw_style_box(border, r)

		# 底部箭头
		var cx := size.x * 0.5
		var by := size.y - 10.0
		var tri := PackedVector2Array([Vector2(cx - 8, by - 8), Vector2(cx + 8, by - 8), Vector2(cx, by)])
		draw_colored_polygon(tri, Color(gold.r, gold.g, gold.b, pulse))


# 拖拽投放回调：把拖来的卡打到目标敌人（target_id = "enemy_0/enemy_1..."；"" = 默认选中目标）
static func _make_drop_handler(on_play_card: Callable) -> Callable:
	return func(card_index: int, target_id: String) -> void:
		on_play_card.call(card_index, target_id)


# 把 PanelContainer 包进一个非容器 Control，震动/缩放只影响 wrapper，
# 不破坏父容器（HBoxContainer/VBoxContainer）自动布局，避免多敌人重叠。
static func _wrap_panel_for_shake(panel: PanelContainer) -> Control:
	if panel == null:
		return null
	var wrapper := Control.new()
	wrapper.custom_minimum_size = panel.custom_minimum_size
	wrapper.size_flags_horizontal = panel.size_flags_horizontal
	wrapper.size_flags_vertical = panel.size_flags_vertical
	panel.custom_minimum_size = Vector2.ZERO
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(panel)
	panel.set_meta("_shake_wrapper", wrapper)
	return wrapper


static func build(
	run_state: RunState,
	combat: CombatController,
	registry: DataRegistry,
	log_bbcode: String,
	card_w: float,
	card_h: float,
	on_play_card: Callable,
	on_flask: Callable,
	on_end_turn: Callable,
	prev_hp: Dictionary = {},
	on_show_pile: Callable = Callable(),
	prev_status_snapshot: Dictionary = {}
) -> CombatHudRefs:
	var refs := CombatHudRefs.new()

	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 0)
	wrapper.add_child(main)

	var fx_layer := Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.top_level = true
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.z_index = 50
	refs.fx_layer = fx_layer
	main.add_child(fx_layer)

	var aim_line := TargetingLine.new()
	aim_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(aim_line)
	aim_line.move_to_front()
	aim_line.z_index = 100

	# 战斗舞台：玩家左 / 敌人右（顶部资源栏已移除，高度归还舞台）
	var stage_wrap := Control.new()
	stage_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_wrap.custom_minimum_size = Vector2(0, 180)
	main.add_child(stage_wrap)

	# 投放区（先添加，z_order 最低）
	var stage_zone := DropZone.new()
	stage_zone.setup("", _make_drop_handler(on_play_card))
	stage_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	stage_wrap.add_child(stage_zone)

	var stage_margin := MarginContainer.new()
	stage_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_margin.add_theme_constant_override("margin_left", 16)
	stage_margin.add_theme_constant_override("margin_right", 16)
	stage_wrap.add_child(stage_margin)

	var stage_root := HBoxContainer.new()
	stage_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_root.add_theme_constant_override("separation", 24)
	stage_root.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_margin.add_child(stage_root)

	# 左侧：玩家紧凑面板
	var player_side := VBoxContainer.new()
	player_side.alignment = BoxContainer.ALIGNMENT_CENTER
	player_side.custom_minimum_size = Vector2(170, 0)
	stage_root.add_child(player_side)

	var player_portrait := _load_portrait(run_state.player_portrait_path)
	refs.player_panel = UiBuilders.battle_entity_panel(
		"褪色者", run_state.hp, run_state.max_hp, combat.block,
		{"rot": run_state.player_rot, "bleed": run_state.player_bleed, "vulnerable": run_state.player_vulnerable, "strength": run_state.player_strength},
		player_portrait, false, -1, -1, {})
	refs.player_panel.custom_minimum_size = Vector2(170, 235)
	var player_wrapper := _wrap_panel_for_shake(refs.player_panel)
	player_side.add_child(player_wrapper)

	# 右侧：敌人区域
	var enemy_area := Control.new()
	enemy_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_root.add_child(enemy_area)

	var enemy_root := VBoxContainer.new()
	enemy_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_root.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_root.add_theme_constant_override("separation", 12)
	enemy_area.add_child(enemy_root)

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 16)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_root.add_child(enemy_row)

	var many := combat.enemies.size() >= 3
	var enemy_base_size := Vector2(160, 225) if many else Vector2(200, 260)

	for ei in range(combat.enemies.size()):
		var e: Dictionary = combat.enemies[ei]
		var is_target := ei == combat.target_index
		var e_intent: Dictionary = e.get("_intent", {})
		var intent := {"kind": str(e_intent.get("kind", "")), "text": combat.intent_text_for(e)}

		var e_panel := UiBuilders.battle_entity_panel(
			str(e.name), int(e.hp), int(e.max_hp), int(e.block),
			{"rot": int(e.rot), "bleed": int(e.bleed), "vulnerable": int(e.vulnerable), "strength": int(e.strength), "stance": int(e.stance_now), "break_open": 1 if bool(e.get("break_open", false)) else 0},
			_load_portrait(e.get("portrait_path", "")), true, int(e.stance_now), int(e.stance_max), intent)
		e_panel.custom_minimum_size = enemy_base_size
		e_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		e_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var e_wrapper := _wrap_panel_for_shake(e_panel)
		enemy_row.add_child(e_wrapper)

		if is_target:
			var sel := SelectionOverlay.new()
			e_panel.add_child(sel)
			sel.move_to_front()
		refs.enemy_panels[ei] = e_panel
		if ei == 0:
			refs.enemy_panel = e_panel

		var zone := DropZone.new()
		zone.setup("enemy_%d" % ei, _make_drop_handler(on_play_card))
		zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		e_panel.add_child(zone)
		zone.move_to_front()

		if intent.kind in ["attack", "attack_block", "attack_rot"]:
			var intent_node = e_panel.get_meta("_intent_banner", null) as Control
			if intent_node != null:
				var pulse := intent_node.create_tween().set_loops()
				pulse.tween_property(intent_node, "modulate", Color(1, 1, 1, 0.82), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				pulse.tween_property(intent_node, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				intent_node.tree_exiting.connect(func() -> void:
					if pulse != null and pulse.is_valid():
						pulse.kill()
				)

		aim_line.zone_centers["enemy_%d" % ei] = {"center": Vector2.ZERO, "radius": minf(enemy_base_size.x, enemy_base_size.y) * 0.38}

	# 手牌 + 底栏
	var bottom_area := VBoxContainer.new()
	bottom_area.add_theme_constant_override("separation", 6)
	bottom_area.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(bottom_area)

	# 可折叠战斗日志：浮在 wrapper 左下角，默认收起，不挤压 main VBox 布局
	var log_panel := PanelContainer.new()
	log_panel.name = "LogPanel"
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	log_panel.offset_left = 16
	log_panel.offset_right = 356
	log_panel.offset_top = -294
	log_panel.offset_bottom = -260
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color("#0d0a08", 0.78)
	log_style.border_color = GameTheme.BORDER
	log_style.set_border_width_all(1)
	log_style.set_corner_radius_all(8)
	log_style.content_margin_left = 10
	log_style.content_margin_right = 10
	log_style.content_margin_top = 6
	log_style.content_margin_bottom = 6
	log_panel.add_theme_stylebox_override("panel", log_style)
	wrapper.add_child(log_panel)

	var log_v := VBoxContainer.new()
	log_v.mouse_filter = Control.MOUSE_FILTER_PASS
	log_v.add_theme_constant_override("separation", 4)
	log_panel.add_child(log_v)

	var log_header := Button.new()
	log_header.text = "战斗日志 ▼"
	log_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	log_header.custom_minimum_size = Vector2(0, 26)
	log_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_header.add_theme_font_size_override("font_size", 12)
	log_header.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	log_header.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	log_header.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	log_header.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	log_header.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	log_v.add_child(log_header)

	refs.log_box = RichTextLabel.new()
	refs.log_box.bbcode_enabled = true
	refs.log_box.text = log_bbcode
	refs.log_box.fit_content = false
	refs.log_box.scroll_active = true
	refs.log_box.scroll_following = true
	refs.log_box.custom_minimum_size = Vector2(0, 92)
	refs.log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	refs.log_box.add_theme_font_size_override("normal_font_size", 13)
	refs.log_box.add_theme_color_override("default_color", GameTheme.TEXT)
	refs.log_box.visible = false
	refs.log_box.mouse_filter = Control.MOUSE_FILTER_PASS
	log_v.add_child(refs.log_box)

	log_panel.set_meta("expanded", false)
	log_header.pressed.connect(func() -> void:
		var expanded: bool = log_panel.get_meta("expanded", false)
		expanded = not expanded
		log_panel.set_meta("expanded", expanded)
		log_header.text = "战斗日志 ▲" if expanded else "战斗日志 ▼"
		refs.log_box.visible = expanded
		var target_top := -400 if expanded else -294
		var tw := log_panel.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(log_panel, "offset_top", target_top, 0.15)
	)

	# 手牌区左右留白：扇形旋转的牌角不贴屏幕边缘
	var hand_margin := MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_left", 24)
	hand_margin.add_theme_constant_override("margin_right", 24)
	bottom_area.add_child(hand_margin)

	var hand_scroll := ScrollContainer.new()
	# 手牌区高度按卡牌高度 + 悬停抬升预留，避免扇形侵入舞台/日志
	hand_scroll.custom_minimum_size = Vector2(0, card_h + int(card_h * 0.22) + 6)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.clip_contents = false
	hand_margin.add_child(hand_scroll)

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
	# 更紧凑的扇形叠放：StS 式约 25-30% 重叠，便于一眼扫视整手
	refs.hand_row.add_theme_constant_override("separation", -32)
	refs.hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	refs.hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refs.hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(refs.hand_row)

	var preview_host := Control.new()
	preview_host.top_level = true
	preview_host.z_index = 60
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_host.visible = false
	main.add_child(preview_host)

	var n_hand: int = run_state.hand.size()
	for i in range(run_state.hand.size()):
		var card_id: String = run_state.hand[i]
		var card_data: CardData = registry.get_card(card_id)
		if card_data != null:
			var card_btn := UiBuilders.card_button(card_data, i, combat, card_w, card_h, on_play_card.bind(i))
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(card_w, card_h)
			# 顶对齐：扇形下沉（position.y）留在手牌区内，不侵入底栏
			slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			refs.hand_row.add_child(slot)
			slot.add_child(card_btn)
			card_btn.size = Vector2(card_w, card_h)
			var t: float = float(i) - float(n_hand - 1) / 2.0
			# 更平缓的扇形：5 张时约 ±8°，降低牌顶侵入上方 UI 的程度
			var step_deg: float = minf(4.0, 24.0 / float(maxi(1, n_hand - 1)))
			card_btn.pivot_offset = Vector2(card_w * 0.5, card_h)
			card_btn.rotation_degrees = t * step_deg
			card_btn.position = Vector2(0.0, 2.5 * t * t)
			card_btn.set_meta("_fan_y", card_btn.position.y)
			_wire_hover_preview_v2(card_btn, card_data, refs.hand_row, preview_host, hand_scroll)
			if card_btn is DragCard:
				var dc := card_btn as DragCard
				dc.drag_started.connect(func(_idx: int, from_g: Vector2) -> void:
					aim_line.begin(from_g)
					aim_line.set_card_preview(card_data))
				dc.drag_ended.connect(func() -> void:
					aim_line.end()
					aim_line.set_card_preview(null))

	# 底部 HUD：左 [抽牌 | 能量球 | 回合 | 圣杯瓶] / 右 [结束回合 | 弃牌 | 消耗]（StS 式四角布局，中央让位手牌）
	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 10)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_area.add_child(bottom_bar)

	var draw_badge := UiBuilders.pile_badge("res://assets/icons/icon_deck.svg", str(run_state.draw_pile.size()), "抽牌", GameTheme.CARD_DEFENSE)
	draw_badge.custom_minimum_size = Vector2(64, 56)
	if on_show_pile.is_valid():
		draw_badge.pressed.connect(on_show_pile.bind("draw"))
	bottom_bar.add_child(draw_badge)

	var orb := UiBuilders.energy_orb(combat.ember, combat.max_ember, combat.turn)
	bottom_bar.add_child(orb)
	if combat.ember <= 0:
		var orb_pulse := orb.create_tween().set_loops()
		orb_pulse.tween_property(orb, "modulate", Color(1, 1, 1, 0.75), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb_pulse.tween_property(orb, "modulate", Color(1, 1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb.tree_exiting.connect(func() -> void:
			if orb_pulse != null and orb_pulse.is_valid():
				orb_pulse.kill()
		)

	refs.flask_button = UiBuilders.flask_button(run_state.flasks, run_state.flasks <= 0 or run_state.hp >= run_state.max_hp, on_flask)
	refs.flask_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_bar.add_child(refs.flask_button)

	var bar_spacer := Control.new()
	bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bar_spacer)

	refs.end_turn_button = UiBuilders.end_turn_button(combat.combat_over, on_end_turn)
	bottom_bar.add_child(refs.end_turn_button)

	var discard_badge := UiBuilders.pile_badge("res://assets/icons/icon_discard.svg", str(run_state.discard_pile.size()), "弃牌", GameTheme.CARD_ATTACK)
	discard_badge.custom_minimum_size = Vector2(64, 56)
	if on_show_pile.is_valid():
		discard_badge.pressed.connect(on_show_pile.bind("discard"))
	bottom_bar.add_child(discard_badge)

	var exhaust_badge := UiBuilders.pile_badge("res://assets/icons/icon_exhaust.svg", str(run_state.exhaust_pile.size()), "消耗", GameTheme.TEXT_MUTED)
	exhaust_badge.custom_minimum_size = Vector2(64, 56)
	if on_show_pile.is_valid():
		exhaust_badge.pressed.connect(on_show_pile.bind("exhaust"))
	bottom_bar.add_child(exhaust_badge)

	_refresh_aim_anchors(aim_line, refs.enemy_panels)
	_animate_hp(refs, refs.player_panel, int(prev_hp.get("player", -1)), run_state.hp, false)
	for ei in refs.enemy_panels:
		if ei < combat.enemies.size():
			var e: Dictionary = combat.enemies[ei]
			_animate_hp(refs, refs.enemy_panels[ei], int(prev_hp.get("enemy_%d" % ei, -1)), int(e.hp), bool(e.get("break_open", false)))

	# 状态飘字（headless 模式下 fx_layer 无 tree，安全跳过）
	if not prev_status_snapshot.is_empty() and refs.fx_layer != null and refs.fx_layer.get_parent() != null:
		_spawn_status_popups(refs, prev_status_snapshot, run_state, combat)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 8)
	main.add_child(bottom_pad)

	refs.root = wrapper
	return refs


static func _wire_hover_preview_v2(card_btn: Button, card: CardData, hand_row: HBoxContainer, host: Control, hand_scroll: ScrollContainer) -> void:
	var base_y: float = card_btn.get_meta("_fan_y", card_btn.position.y)
	var lift_y := base_y - 42.0
	card_btn.mouse_entered.connect(func() -> void:
		_kill_hover_y_tween(card_btn)
		var tw := card_btn.create_tween()
		card_btn.set_meta("_hover_y_tween", tw)
		tw.tween_property(card_btn, "position:y", lift_y, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_show_card_preview_v2(host, card, card_btn, hand_scroll)
		_push_neighbors(card_btn, hand_row, true))
	card_btn.mouse_exited.connect(func() -> void:
		_kill_hover_y_tween(card_btn)
		var tw := card_btn.create_tween()
		card_btn.set_meta("_hover_y_tween", tw)
		tw.tween_property(card_btn, "position:y", base_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		host.visible = false
		_push_neighbors(card_btn, hand_row, false))
	if card_btn is DragCard:
		(card_btn as DragCard).drag_started.connect(func(_idx: int, _from: Vector2) -> void:
			host.visible = false
			_push_neighbors(card_btn, hand_row, false))


static func _show_card_preview_v2(host: Control, card: CardData, source: Control, hand_scroll: ScrollContainer) -> void:
	for child in host.get_children():
		child.queue_free()
	var rarity_dict: Dictionary = UiBuilders.rarity_meta(card.rarity)
	var accent := GameTheme.card_type_color(card.type)
	var border_color: Color = accent.lightened(0.15)
	if rarity_dict.get("border_only", false):
		border_color = rarity_dict.color
	var preview := UiBuilders.card_preview(card, rarity_dict, border_color)
	host.add_child(preview)
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(UiBuilders.PREVIEW_W, UiBuilders.PREVIEW_H)

	var vp := host.get_viewport_rect().size
	var hand_global_y := hand_scroll.global_position.y + hand_scroll.size.y
	var px := (vp.x - UiBuilders.PREVIEW_W) * 0.5
	var py := hand_global_y - UiBuilders.PREVIEW_H - 16.0
	px = clampf(px, 12.0, vp.x - UiBuilders.PREVIEW_W - 12.0)
	py = clampf(py, 8.0, vp.y - UiBuilders.PREVIEW_H - 8.0)
	host.position = Vector2(px, py)
	host.visible = true



static func _kill_hover_y_tween(card_btn: Control) -> void:
	if card_btn.has_meta("_hover_y_tween"):
		var t: Tween = card_btn.get_meta("_hover_y_tween") as Tween
		if t != null and t.is_valid():
			t.kill()


static func _push_neighbors(card_btn: Control, hand_row: HBoxContainer, push: bool) -> void:
	var slot := card_btn.get_parent() as Control
	if slot == null:
		return
	var idx := slot.get_index()
	var push_amount := 22.0
	for di: int in [-1, 1]:
		var ni := idx + di
		if ni < 0 or ni >= hand_row.get_child_count():
			continue
		var neighbor_slot := hand_row.get_child(ni) as Control
		if neighbor_slot == null or neighbor_slot.get_child_count() == 0:
			continue
		var neighbor_card := neighbor_slot.get_child(0) as Control
		if not push and neighbor_card is Button and (neighbor_card as Button).is_hovered():
			continue
		var target_x := float(di) * push_amount if push else 0.0
		_kill_hover_x_tween(neighbor_card)
		var tw := neighbor_card.create_tween()
		neighbor_card.set_meta("_hover_x_tween", tw)
		tw.tween_property(neighbor_card, "position:x", target_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _kill_hover_x_tween(card: Control) -> void:
	if card.has_meta("_hover_x_tween"):
		var t: Tween = card.get_meta("_hover_x_tween") as Tween
		if t != null and t.is_valid():
			t.kill()


static func _find_progress_bar(node: Node) -> ProgressBar:
	if node is ProgressBar:
		return node as ProgressBar
	for child in node.get_children():
		var found := _find_progress_bar(child)
		if found != null:
			return found
	return null


const DAMAGE_TIER_SMALL := 5
const DAMAGE_TIER_HEAVY := 10


static func _animate_hp(refs: CombatHudRefs, panel: PanelContainer, prev: int, cur: int, is_break_open: bool) -> void:
	# 血条过渡动画 + 分层打击反馈：prev < 0 表示无上一帧数据（首次渲染），直接呈现
	if panel == null or prev < 0:
		return
	var bar := _find_progress_bar(panel)
	if bar != null and prev != cur:
		bar.value = prev
		var tw := bar.create_tween()
		tw.tween_property(bar, "value", cur, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		panel.tree_exiting.connect(func() -> void:
			if tw != null and tw.is_valid():
				tw.kill()
		)
	if prev > cur:
		var dmg := prev - cur
		var tier := _damage_tier(dmg, is_break_open)
		match tier:
			"heavy":
				_hit_flash(panel, dmg, is_break_open)
				_shake_panel(panel, 5.5, 0.18)
				_shake_screen(refs, 7.0, 0.22)
				_freeze_panel(panel, 0.08)
				_spawn_damage_particles(refs, panel, dmg, is_break_open)
			"medium":
				_hit_flash(panel, dmg, is_break_open)
				_shake_panel(panel, 4.0, 0.14)
			_:
				# 小伤害：轻微红闪（数字飘字由 Main 侧 fx 事件统一处理）
				_hit_flash(panel, dmg, is_break_open)
	elif prev < cur:
		var healed := cur - prev
		_heal_glow(refs, panel, healed)


static func _damage_tier(dmg: int, is_break_open: bool) -> String:
	if dmg >= DAMAGE_TIER_HEAVY or is_break_open:
		return "heavy"
	if dmg >= DAMAGE_TIER_SMALL:
		return "medium"
	return "small"


static func _hit_flash(panel: PanelContainer, dmg: int = 0, is_break_open: bool = false) -> void:
	var base: Color = panel.modulate
	var tw := panel.create_tween()
	if dmg >= DAMAGE_TIER_HEAVY or is_break_open:
		# 重击 / 崩解：更亮更长的定格红闪
		tw.tween_property(panel, "modulate", Color(1.85, 0.72, 0.62), 0.04)
		tw.chain().tween_interval(0.08)
		tw.tween_property(panel, "modulate", Color(1.35, 0.48, 0.38), 0.12)
		tw.tween_property(panel, "modulate", base, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif dmg >= DAMAGE_TIER_SMALL:
		tw.tween_property(panel, "modulate", Color(1.6, 0.55, 0.45), 0.06)
		tw.tween_property(panel, "modulate", base, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(panel, "modulate", Color(1.35, 0.6, 0.5), 0.06)
		tw.tween_property(panel, "modulate", base, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	panel.tree_exiting.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
	)


static func _heal_glow(refs: CombatHudRefs, panel: PanelContainer, amount: int = 0) -> void:
	var base: Color = panel.modulate
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate", Color(0.75, 1.15, 0.8), 0.12)
	tw.tween_property(panel, "modulate", base, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	panel.tree_exiting.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
	)
	if refs.fx_layer != null and amount > 0:
		var orb_count := mini(4, 1 + amount / 8)
		_spawn_heal_orbs(refs, panel, orb_count)


static func _shake_panel(panel: PanelContainer, amount: float, duration: float) -> void:
	if panel == null:
		return
	# 若 panel 已被包装，则震动 wrapper，避免直接修改容器子节点的 position。
	var target: Control = panel
	if panel.has_meta("_shake_wrapper"):
		var w := panel.get_meta("_shake_wrapper") as Control
		if w != null:
			target = w
	if not is_instance_valid(target):
		return

	# build 返回前节点尚未加入场景树，无法立刻记录正确 base；
	# 延迟到进入树后再执行，避免 base=(0,0) 导致恢复后面板重叠。
	if not target.is_inside_tree():
		if target.has_meta("_shake_pending"):
			return
		target.set_meta("_shake_pending", true)
		var on_enter := func() -> void:
			target.remove_meta("_shake_pending")
			_shake_panel(panel, amount, duration)
		target.tree_entered.connect(on_enter, CONNECT_ONE_SHOT)
		return

	var base_key := "_shake_base_pos"
	var tw_key := "_shake_tween"
	# 首次震动前等待一次 process_frame，确保父容器已完成布局，
	# 否则 base position 会是 (0,0)，恢复后会导致多敌人面板重叠。
	if not target.has_meta(base_key):
		await target.get_tree().process_frame
		if not is_instance_valid(target):
			return
		target.set_meta(base_key, target.position)

	var is_shaking := false
	if target.has_meta(tw_key):
		var active: Tween = target.get_meta(tw_key) as Tween
		is_shaking = active != null and active.is_valid()
	var base: Vector2 = target.get_meta(base_key)
	# 终止旧震动
	if target.has_meta(tw_key):
		var old_tw: Tween = target.get_meta(tw_key) as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
	# 使用线性插值，避免短时长 quint 缓动带来的末端精度误差
	var tw := target.create_tween().set_trans(Tween.TRANS_LINEAR)
	target.set_meta(tw_key, tw)
	var steps := int(max(3.0, duration * 30.0))
	var step_dt := duration / float(steps)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-amount, amount),
			randf_range(-amount, amount)
		)
		tw.tween_property(target, "position", base + offset, step_dt)
	# 最后一步回到基准，并追加回调强制复位，双重保险消除残留漂移
	tw.tween_property(target, "position", base, step_dt)
	tw.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.position = base
	)
	tw.finished.connect(func() -> void:
		if is_instance_valid(target):
			target.position = base
			target.remove_meta(tw_key)
	)
	target.tree_exiting.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
	)


static func _shake_screen(refs: CombatHudRefs, amount: float, duration: float) -> void:
	# 对整个战斗 HUD + 特效层同步施加随机位移，模拟屏幕震动
	if refs.root == null or refs.fx_layer == null:
		return
	var base_key := "_shake_base_pos"
	var tw_key := "_shake_tween"
	var base_root: Vector2
	var base_fx: Vector2
	for node: Node in [refs.root, refs.fx_layer]:
		var ctl := node as Control
		if ctl == null:
			continue
		var is_shaking := ctl.has_meta(tw_key)
		if is_shaking:
			var active: Tween = ctl.get_meta(tw_key) as Tween
			is_shaking = active != null and active.is_valid()
		if not is_shaking:
			ctl.set_meta(base_key, ctl.position)
		if ctl.has_meta(tw_key):
			var old_tw: Tween = ctl.get_meta(tw_key) as Tween
			if old_tw != null and old_tw.is_valid():
				old_tw.kill()
	base_root = refs.root.get_meta(base_key)
	base_fx = refs.fx_layer.get_meta(base_key)
	var steps := int(max(5.0, duration * 45.0))
	var step_dt := duration / float(steps)
	var tw_root := refs.root.create_tween().set_trans(Tween.TRANS_LINEAR)
	var tw_fx := refs.fx_layer.create_tween().set_trans(Tween.TRANS_LINEAR)
	refs.root.set_meta(tw_key, tw_root)
	refs.fx_layer.set_meta(tw_key, tw_fx)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-amount, amount),
			randf_range(-amount, amount)
		)
		tw_root.tween_property(refs.root, "position", base_root + offset, step_dt)
		tw_fx.tween_property(refs.fx_layer, "position", base_fx + offset, step_dt)
	tw_root.tween_property(refs.root, "position", base_root, step_dt)
	tw_fx.tween_property(refs.fx_layer, "position", base_fx, step_dt)
	tw_root.tween_callback(func() -> void:
		if is_instance_valid(refs.root):
			refs.root.position = base_root
	)
	tw_fx.tween_callback(func() -> void:
		if is_instance_valid(refs.fx_layer):
			refs.fx_layer.position = base_fx
	)
	tw_root.finished.connect(func() -> void:
		if is_instance_valid(refs.root):
			refs.root.position = base_root
			refs.root.remove_meta(tw_key)
	)
	tw_fx.finished.connect(func() -> void:
		if is_instance_valid(refs.fx_layer):
			refs.fx_layer.position = base_fx
			refs.fx_layer.remove_meta(tw_key)
	)
	refs.root.tree_exiting.connect(func() -> void:
		if tw_root != null and tw_root.is_valid():
			tw_root.kill()
		if tw_fx != null and tw_fx.is_valid():
			tw_fx.kill()
	)


static func _freeze_panel(panel: PanelContainer, duration: float) -> void:
	# 目标定格：短暂时停感的放大回弹
	if panel == null:
		return
	var target: Control = panel
	if panel.has_meta("_shake_wrapper"):
		var w := panel.get_meta("_shake_wrapper") as Control
		if w != null:
			target = w
	var tw := target.create_tween()
	tw.tween_property(target, "scale", Vector2(1.04, 1.04), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "scale", Vector2.ONE, duration * 0.5).set_delay(duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	target.tree_exiting.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
	)


static func _spawn_damage_particles(refs: CombatHudRefs, panel: Control, dmg: int, is_break_open: bool) -> void:
	# 碎片 / 血迹粒子：用 ColorRect 小方块模拟，无需外部资源
	if refs.fx_layer == null or panel == null:
		return
	if not panel.is_inside_tree() or not refs.fx_layer.is_inside_tree():
		return
	var tree := panel.get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(panel) or panel.get_parent() == null or refs.fx_layer.get_parent() == null:
		return
	var center := panel.global_position + panel.size * 0.5
	var base_color := Color("#c0392b") if is_break_open else GameTheme.DAMAGE_ACCENT
	var count := 12 if is_break_open else mini(8, 3 + dmg / 3)
	var spread := 56.0 if is_break_open else 38.0
	for i in range(count):
		var p := ColorRect.new()
		var shade := base_color.lightened(randf_range(-0.1, 0.25))
		p.color = shade
		var sz := randf_range(3.0, 7.0)
		p.size = Vector2(sz, sz)
		p.global_position = center - p.size * 0.5
		p.rotation = randf() * TAU
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refs.fx_layer.add_child(p)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var dist := randf_range(20.0, spread)
		var dur := randf_range(0.35, 0.75)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", center + dir * dist - p.size * 0.5, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-PI, PI), dur)
		tw.tween_property(p, "modulate:a", 0.0, dur * 0.8).set_delay(dur * 0.2)
		tw.chain().tween_callback(p.queue_free)


static func _spawn_heal_orbs(refs: CombatHudRefs, panel: Control, count: int) -> void:
	# 治疗：向上漂浮的绿色光球，方向 / 颜色与伤害形成双重区分
	if refs.fx_layer == null or panel == null:
		return
	if not panel.is_inside_tree() or not refs.fx_layer.is_inside_tree():
		return
	var tree := panel.get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(panel) or panel.get_parent() == null or refs.fx_layer.get_parent() == null:
		return
	var start := panel.global_position + Vector2(panel.size.x * 0.5, panel.size.y * 0.65)
	for i in range(count):
		var orb := PanelContainer.new()
		orb.size = Vector2(10, 10)
		var style := StyleBoxFlat.new()
		style.bg_color = GameTheme.BUFF_ACCENT.lightened(randf_range(0.05, 0.25))
		style.set_corner_radius_all(5)
		style.shadow_color = Color(GameTheme.BUFF_ACCENT.r, GameTheme.BUFF_ACCENT.g, GameTheme.BUFF_ACCENT.b, 0.45)
		style.shadow_size = 4
		orb.add_theme_stylebox_override("panel", style)
		orb.global_position = start + Vector2(randf_range(-12, 12), randf_range(-6, 6))
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refs.fx_layer.add_child(orb)
		var tw := orb.create_tween()
		tw.set_parallel(true)
		var drift := Vector2(randf_range(-24, 24), -randf_range(48, 78))
		tw.tween_property(orb, "global_position", orb.global_position + drift, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(orb, "modulate:a", 0.0, 1.0).set_delay(0.35)
		tw.chain().tween_callback(orb.queue_free)


static func _spawn_status_popups(refs: CombatHudRefs, prev_snapshot: Dictionary, run_state: RunState, combat: CombatController) -> void:
	# 等布局完成、面板有真实坐标后再生成状态图标飘字
	if refs.fx_layer == null:
		return
	if not refs.fx_layer.is_inside_tree():
		return
	var tree := refs.fx_layer.get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(refs.fx_layer) or refs.fx_layer.get_parent() == null:
		return

	var player_prev: Dictionary = prev_snapshot.get("player", {}) as Dictionary
	# 首次渲染无快照，跳过（避免把初始状态当成“获得”）
	if not player_prev.is_empty():
		var player_cur := {
			"rot": run_state.player_rot,
			"bleed": run_state.player_bleed,
			"vulnerable": run_state.player_vulnerable,
			"strength": run_state.player_strength,
		}
		_compare_status_and_popup(refs, refs.player_panel, player_prev, player_cur)

	for ei in refs.enemy_panels:
		if ei >= combat.enemies.size():
			continue
		var e: Dictionary = combat.enemies[ei]
		var prev: Dictionary = prev_snapshot.get("enemy_%d" % ei, {}) as Dictionary
		if prev.is_empty():
			continue
		var cur := {
			"rot": int(e.rot),
			"bleed": int(e.bleed),
			"vulnerable": int(e.vulnerable),
			"strength": int(e.strength),
			"break_open": 1 if bool(e.get("break_open", false)) else 0,
		}
		_compare_status_and_popup(refs, refs.enemy_panels[ei], prev, cur)


static func _compare_status_and_popup(refs: CombatHudRefs, panel: PanelContainer, prev: Dictionary, cur: Dictionary) -> void:
	if panel == null or refs.fx_layer == null:
		return
	for key in cur:
		var prev_val: int = int(prev.get(key, 0))
		var cur_val: int = int(cur.get(key, 0))
		var delta := cur_val - prev_val
		if delta > 0:
			_spawn_status_popup(refs, panel, str(key), delta)


static func _status_popup_meta(status_id: String) -> Dictionary:
	match status_id:
		"rot":
			return {"name": "腐败", "icon": "res://assets/icons/icon_flame.svg", "color": GameTheme.status_color("rot")}
		"bleed":
			return {"name": "出血", "icon": "res://assets/icons/icon_sword.svg", "color": GameTheme.status_color("bleed")}
		"vulnerable":
			return {"name": "易伤", "icon": "res://assets/icons/icon_skull.svg", "color": GameTheme.status_color("vulnerable")}
		"strength":
			return {"name": "力量", "icon": "res://assets/icons/icon_arrow_right.svg", "color": GameTheme.status_color("strength")}
		"break_open":
			return {"name": "破绽", "icon": "res://assets/icons/icon_sword.svg", "color": GameTheme.GOLD}
		_:
			return {"name": status_id, "icon": "", "color": GameTheme.TEXT_MUTED}


static func _spawn_status_popup(refs: CombatHudRefs, panel: Control, status_id: String, delta: int) -> void:
	if refs.fx_layer == null or panel == null:
		return
	if not is_instance_valid(panel) or panel.get_parent() == null:
		return
	var meta := _status_popup_meta(status_id)
	var color: Color = meta.color
	var is_buff := status_id == "strength"

	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color.lightened(0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	popup.add_theme_stylebox_override("panel", style)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(row)

	var icon_path: String = meta.icon
	if icon_path != "":
		var tex := load(icon_path) as Texture2D
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(12, 12)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.modulate = color.lightened(0.35)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)

	var label := Label.new()
	label.text = "%s +%d" % [meta.name, delta]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	refs.fx_layer.add_child(popup)
	popup.size = popup.get_minimum_size()
	var start := panel.global_position + Vector2(panel.size.x * 0.5 - popup.size.x * 0.5, panel.size.y * 0.15)
	popup.global_position = start

	var tw := popup.create_tween()
	tw.set_parallel(true)
	var rise := -randf_range(38, 58)
	var drift := randf_range(-12, 12) if is_buff else 0.0
	tw.tween_property(popup, "global_position", start + Vector2(drift, rise), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(popup.queue_free)


static func _load_portrait(path: String) -> Texture2D:
	if path == "":
		return null
	var tex := load(path) as Texture2D
	return tex


static func _refresh_aim_anchors(aim_line: TargetingLine, panels: Dictionary) -> void:
	# 布局后敌人面板有实际坐标；此处立即读取（build 返回前 children 已在树中）
	for key in panels:
		var zone := panels[key] as PanelContainer
		if zone == null:
			continue
		for sub in zone.get_children():
			if sub is DropZone:
				var dz := sub as DropZone
				if aim_line.zone_centers.has(dz.target_id):
					var center := zone.get_global_rect().get_center()
					(aim_line.zone_centers[dz.target_id] as Dictionary)["center"] = center
				break