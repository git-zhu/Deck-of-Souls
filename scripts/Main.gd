extends Control

enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }

const CARD_W := 110.0
const CARD_H := 142.0
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
const AshService = preload("res://scripts/core/AshService.gd")
const CardData = preload("res://data/CardData.gd")
const RelicData = preload("res://data/RelicData.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const EventService = preload("res://scripts/core/EventService.gd")
const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")
const FloatingText = preload("res://scripts/ui/FloatingText.gd")
const TitleScreenView = preload("res://scripts/ui/TitleScreenView.gd")
const OriginScreenView = preload("res://scripts/ui/OriginScreenView.gd")
const DeckPopupView = preload("res://scripts/ui/DeckPopupView.gd")
const EndScreenView = preload("res://scripts/ui/EndScreenView.gd")
const RunRewardFlow = preload("res://scripts/core/RunRewardFlow.gd")
const RunFlowController = preload("res://scripts/core/RunFlowController.gd")
const RunSaveService = preload("res://scripts/core/RunSaveService.gd")
const RunPauseMenuView = preload("res://scripts/ui/RunPauseMenuView.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")

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
var run_flow: RunFlowController
var pending_ng: int = 0    # 出身屏选择的周目
var pending_vow: int = 0   # 出身屏选择的誓约等级
var pending_challenge: int = 0  # 出身屏选择的誓言挑战（0 无 / 1 无瓶 / 2 强敌）

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
var header: Control
var log_box: RichTextLabel
var hand_row: HBoxContainer
var enemy_panel: PanelContainer
var player_panel: PanelContainer
var end_turn_button: Button
var flask_button: Button
var deck_button: Button
var menu_button: Button
var pause_overlay: Control
# 战斗反馈：上一帧血量快照（血条过渡用）+ 上一回合数（回合横幅用）
var _last_hp_snapshot: Dictionary = {}
var _prev_turn: int = 0

func _ready() -> void:
	rng.randomize()
	# 正式 UI：隐藏调试构建的窗口标题 (DEBUG) 后缀
	get_window().title = "Deck of Souls"
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
	run_flow = RunFlowController.new(self)
	_build_ui()
	_show_title()


func _on_combat_changed() -> void:
	if screen == GameScreen.COMBAT:
		_render_combat()


func _on_combat_ended(kind: String) -> void:
	run_flow.on_combat_ended(kind)


var bg_rect: TextureRect
var vignette_rect: TextureRect
var _bg_current: String = ""


func _build_ui() -> void:
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.texture = _load_bg("bg_elden")
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	# 暗角微光叠加层（标题/地图/结算屏氛围）
	vignette_rect = TextureRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vignette_rect.texture = load("res://assets/bg_title_vignette.png") as Texture2D
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.visible = true
	add_child(vignette_rect)

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

	header = Control.new()
	header.custom_minimum_size = Vector2(0, 46)
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


func _load_bg(kind: String) -> Texture2D:
	match kind:
		"combat":
			return load("res://assets/bg_combat.svg") as Texture2D
		_:
			return load("res://assets/bg_elden.svg") as Texture2D


func _show_ai_overlay(kind: String) -> void:
	# AI 生成背景（tiny-sd）作为氛围叠加层：战斗用城堡废墟图，其余用暗角微光
	if vignette_rect == null:
		return
	match kind:
		"combat":
			vignette_rect.texture = load("res://assets/bg_ai_castle.png") as Texture2D
			vignette_rect.modulate = Color(1, 1, 1, 0.5)
		_:
			vignette_rect.texture = load("res://assets/bg_title_vignette.png") as Texture2D
			vignette_rect.modulate = Color(1, 1, 1, 1)


func _show_bg(kind: String) -> void:
	if bg_rect == null or kind == _bg_current:
		return
	bg_rect.texture = _load_bg(kind)
	_bg_current = kind
	if kind != "combat" and vignette_rect != null:
		vignette_rect.texture = load("res://assets/bg_title_vignette.png") as Texture2D
		vignette_rect.modulate = Color(1, 1, 1, 1)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


var _active_tween: Tween


func _focus_first_button(layer: Control) -> void:
	var btn := _first_button(layer)
	if btn != null:
		btn.grab_focus()


func _first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _first_button(child)
		if found != null:
			return found
	return null


func _animate_layer(layer: Control) -> void:
	# 屏幕切换：淡入 + 轻微上浮（120ms），贴近法环"雾门"过渡感
	if layer.has_meta("_anim_tween"):
		var prev: Tween = layer.get_meta("_anim_tween") as Tween
		if prev != null and prev.is_valid():
			prev.kill()
	layer.modulate = Color(1, 1, 1, 0)
	layer.position = Vector2(0, 14)
	var tw := layer.create_tween()
	layer.set_meta("_anim_tween", tw)
	tw.set_parallel(true)
	tw.tween_property(layer, "modulate", Color(1, 1, 1, 1), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(layer, "position", Vector2(0, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 层被释放时自动终止动画，避免 headless 快速切换下 CanvasItem 泄漏
	layer.tree_exiting.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
	)


func _hide_layers() -> void:
	_hide_pause_menu()
	for layer in [title_layer, map_layer, combat_layer, reward_layer, end_layer]:
		layer.visible = false
	_clear(header)


func _present_reward_layer(root: Control) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	_show_bg("bg_elden")
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_layer.add_child(root)
	_animate_layer(reward_layer)
	_maybe_autosave()


func _maybe_autosave() -> void:
	if screen in [GameScreen.MAP, GameScreen.COMBAT, GameScreen.REWARD]:
		RunSaveService.save_snapshot(self)


func _show_title() -> void:
	_hide_pause_menu()
	screen = GameScreen.TITLE
	_hide_layers()
	_show_bg("bg_elden")
	title_layer.visible = true
	_clear(title_layer)
	var has_save := RunSaveService.has_save()
	title_layer.add_child(
		TitleScreenView.build(has_save, _on_title_new_game, _on_title_continue, _on_title_quit)
	)
	_animate_layer(title_layer)


func _on_title_new_game() -> void:
	if RunSaveService.has_save():
		var dlg := AcceptDialog.new()
		dlg.title = "放弃当前进度？"
		dlg.dialog_text = "开始新游戏将覆盖现有存档。"
		dlg.confirmed.connect(func():
			dlg.queue_free()
			_show_origin()
		)
		dlg.canceled.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_show_origin()


func _on_title_continue() -> void:
	if not RunSaveService.load_snapshot(self):
		_show_title()


func _on_title_quit() -> void:
	_maybe_autosave()
	get_tree().quit()


func _show_origin() -> void:
	screen = GameScreen.ORIGIN
	pending_ng = 0
	pending_vow = 0
	pending_challenge = 0
	_hide_layers()
	_show_bg("bg_elden")
	title_layer.visible = true
	_clear(title_layer)
	_build_header()
	title_layer.add_child(
		OriginScreenView.build(registry, _start_run, ProfileService.load_profile(), _on_difficulty_changed)
	)
	_animate_layer(title_layer)
	_focus_first_button(title_layer)


func _on_difficulty_changed(ng_level: int, vow_level: int, challenge_level: int = 0) -> void:
	pending_ng = ng_level
	pending_vow = vow_level
	pending_challenge = challenge_level


func _start_run(origin_id: String = "vagabond") -> void:
	var seed := randi()
	rng.seed = seed
	var origin := registry.get_origin(origin_id)
	if origin == null:
		origin = registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, seed)
	run_state.ng_plus = pending_ng
	run_state.vow_level = pending_vow
	ProfileService.apply_vow_start(run_state)
	# 誓言挑战
	match pending_challenge:
		1:
			run_state.challenge_flags.append("no_flask")
			run_state.max_flasks = 0
			run_state.flasks = 0
			_log("誓言挑战「无瓶」：你不会得到任何圣杯瓶。")
		2:
			run_state.challenge_flags.append("strong_foe")
			_log("誓言挑战「强敌」：敌人生命 +50%。")
	RunSaveService.delete_save()
	log_lines.clear()
	_log("出身：%s。装备：%s。" % [origin.name, origin.equipment])
	if pending_ng > 0:
		_log("第 %d 周目（NG+%d）：敌人更强，卢恩更丰。" % [pending_ng + 1, pending_ng])
	if pending_vow > 0:
		_log("誓约 %d 级已立。代价与荣耀同在。" % pending_vow)
	# 记忆祝福链：携带卡（消耗 50 记忆）→ 起始护符（记忆 ≥100）→ 地图
	_start_blessings(int(ProfileService.load_profile().get("memory", 0)))


func _start_blessings(mem: int) -> void:
	if mem >= 50:
		var card_ids := _roll_memory_cards(3)
		if card_ids.size() > 0:
			_log("记忆低语：选择一张牌随身携带（消耗 50 记忆）。")
			reward_flow.show_memory_card_choice(card_ids, func(): _maybe_relic_blessing(mem))
			return
	_maybe_relic_blessing(mem)


func _maybe_relic_blessing(mem: int) -> void:
	if mem >= 100:
		var offers := relic_service.roll_relic_offers(run_state, registry, rng, 3)
		if offers.size() > 0:
			_log("记忆低语：选择一枚护符作为旅途的开端。")
			reward_flow.show_relic_rewards(offers, run_flow.show_map)
			return
	run_flow.show_map()


func _roll_memory_cards(count: int) -> Array[String]:
	var pool: Array[String] = []
	for cid in registry.all_card_ids():
		var c := registry.get_card(str(cid))
		if c != null and c.rarity != "starter":
			pool.append(str(cid))
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size())) as Array[String]


func _show_map() -> void:
	run_flow.show_map()


func _enter_map_layer(content: Control) -> void:
	screen = GameScreen.MAP
	_hide_layers()
	_show_bg("bg_elden")
	map_layer.visible = true
	_clear(map_layer)
	_build_header()
	map_layer.add_child(content)
	_animate_layer(map_layer)
	_focus_first_button(map_layer)
	_maybe_autosave()


func _choose_map_option(option: Dictionary) -> void:
	run_flow.choose_map_option(option)


func _advance_floor_and_show_map() -> void:
	run_flow.advance_floor_and_show_map()


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
	_last_hp_snapshot = {}
	_prev_turn = 0
	combat.start_combat(template)
	_render_combat()
	_maybe_autosave()


func _end_player_turn() -> void:
	combat.end_player_turn()
	_maybe_autosave()


func _render_combat() -> void:
	_hide_layers()
	_show_bg("combat")
	_show_ai_overlay("combat")
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
		_end_player_turn,
		_last_hp_snapshot,
		_show_pile
	)
	combat_layer.add_child(refs.root)
	if not combat.break_choice.is_empty():
		combat_layer.add_child(_break_choice_overlay())
	player_panel = refs.player_panel
	enemy_panel = refs.enemy_panel
	log_box = refs.log_box
	hand_row = refs.hand_row
	flask_button = refs.flask_button
	end_turn_button = refs.end_turn_button
	_last_hp_snapshot = _snapshot_hp()
	_spawn_fx_next_frame(refs)
	_animate_layer(combat_layer)
	_focus_first_button(combat_layer)


func _break_choice_overlay() -> Control:
	# 姿态崩解决策浮层：处决（追加伤害）vs 防反（护甲 + 集中）
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1d1812")
	style.border_color = Color("#ffd24a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(360, 0)
	panel.add_child(col)
	var title := Label.new()
	title.text = "姿态崩解——破绽就在眼前"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ffd24a"))
	col.add_child(title)
	var exec_v: int = int(combat.break_choice.get("exec", 0))
	var parry_v: int = int(combat.break_choice.get("parry", 0))
	var exec_btn := Button.new()
	exec_btn.text = "处决 · 追加 %d 点要害伤害" % exec_v
	exec_btn.custom_minimum_size = Vector2(0, 42)
	exec_btn.pressed.connect(func():
		GameAudio.play(self, "ui_click")
		combat.apply_break_choice("execute")
		_maybe_autosave()
	)
	col.add_child(exec_btn)
	var parry_btn := Button.new()
	parry_btn.text = "防反 · 获得 %d 护甲，集中 +1" % parry_v
	parry_btn.custom_minimum_size = Vector2(0, 42)
	parry_btn.pressed.connect(func():
		GameAudio.play(self, "ui_click")
		combat.apply_break_choice("parry")
		_maybe_autosave()
	)
	col.add_child(parry_btn)
	exec_btn.grab_focus()
	return overlay


func _snapshot_hp() -> Dictionary:
	var snap := {}
	if run_state == null or combat == null:
		return snap
	snap["player"] = run_state.hp
	for ei in range(combat.enemies.size()):
		snap["enemy_%d" % ei] = int(combat.enemies[ei].get("hp", 0))
	return snap


func _spawn_fx_next_frame(refs: CombatHudRefs) -> void:
	# 等一帧布局完成（面板有真实坐标）再生成飘字；层已切换则放弃
	await get_tree().process_frame
	if not is_instance_valid(refs.root) or refs.root.get_parent() == null:
		return
	_consume_combat_fx(refs)


func _consume_combat_fx(refs: CombatHudRefs) -> void:
	var events := combat.consume_fx_events()
	for ev in events:
		var kind: String = str(ev.get("kind", ""))
		var target: String = str(ev.get("target", ""))
		var value: int = int(ev.get("value", 0))
		if value <= 0:
			continue
		var host := _fx_host(refs, target) as Control
		if host == null:
			continue
		var at: Vector2 = host.global_position + Vector2(host.size.x * 0.5, 12)
		match kind:
			"damage":
				var col := Color("#ff6a58") if target == "player" else Color("#ffd27a")
				FloatingText.spawn(combat_layer, "-%d" % value, at, col, 24)
			"block_hit":
				FloatingText.spawn(combat_layer, "格挡 %d" % value, at + Vector2(0, 22), Color("#8fd9de"), 16)
			"block_gain":
				FloatingText.spawn(combat_layer, "+%d 护甲" % value, at, Color("#8fd9de"), 18)
			"heal":
				FloatingText.spawn(combat_layer, "+%d" % value, at, Color("#8ade9a"), 22)
	# 回合推进横幅（首回合不弹；战斗已结束时不弹）
	if combat.turn > _prev_turn and _prev_turn > 0 and not combat.combat_over:
		FloatingText.spawn_banner(combat_layer, "回合 %d" % combat.turn)
	_prev_turn = combat.turn


func _fx_host(refs: CombatHudRefs, target: String) -> Control:
	if target == "player":
		return refs.player_panel
	if target.begins_with("enemy_"):
		var idx := int(target.trim_prefix("enemy_"))
		return refs.enemy_panels.get(idx, null)
	return null


func _build_header() -> void:
	var refs := RunHeaderView.build(
		header,
		run_state,
		registry,
		_show_deck_view,
		_show_pause_menu
	)
	deck_button = refs["deck"]
	menu_button = refs["menu"]


func _show_pause_menu() -> void:
	if pause_overlay != null:
		return
	pause_overlay = RunPauseMenuView.build(
		_hide_pause_menu,
		_on_pause_return_title,
		_on_pause_abandon_run
	)
	add_child(pause_overlay)


func _hide_pause_menu() -> void:
	if pause_overlay == null:
		return
	pause_overlay.queue_free()
	pause_overlay = null


func _on_pause_return_title() -> void:
	_maybe_autosave()
	_hide_pause_menu()
	_show_title()


func _on_pause_abandon_run() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "放弃当前进度？"
	dlg.dialog_text = "放弃后本局存档将删除，无法继续。"
	dlg.confirmed.connect(func():
		dlg.queue_free()
		RunSaveService.delete_save()
		_hide_pause_menu()
		_show_title()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _show_deck_view() -> void:
	DeckPopupView.show(self, run_state.deck, registry, "牌组", run_state.upgraded_cards)


func _show_pile(which: String) -> void:
	# 战斗中查看抽牌/弃牌/消耗堆（点击底角牌堆徽标）
	match which:
		"draw":
			DeckPopupView.show(self, run_state.draw_pile, registry, "抽牌堆", run_state.upgraded_cards)
		"discard":
			DeckPopupView.show(self, run_state.discard_pile, registry, "弃牌堆", run_state.upgraded_cards)
		"exhaust":
			DeckPopupView.show(self, run_state.exhaust_pile, registry, "消耗堆", run_state.upgraded_cards)


func _play_card(index: int, target_id: String = "") -> void:
	GameAudio.play(self, "ui_click")
	# 多敌人目标：拖拽到指定敌人时设置目标；"" = 保持当前选中目标
	if target_id != "" and target_id.begins_with("enemy_"):
		var ti := int(target_id.trim_prefix("enemy_"))
		combat.set_target(ti)
	var card_id := run_state.hand[index] if index < run_state.hand.size() else ""
	combat.play_card(index)
	# 战斗飘字：打出的牌名浮现在敌人面板上方
	if card_id != "" and enemy_panel != null:
		var card := registry.get_card(card_id)
		if card != null:
			FloatingText.spawn(
				combat_layer,
				card.name,
				enemy_panel.global_position + Vector2(enemy_panel.size.x * 0.5, 8),
				card.tone.lightened(0.3)
			)


func _unhandled_input(event: InputEvent) -> void:
	# PC 快捷键（可重映射）：数字键打牌 / F 圣杯瓶 / 空格结束回合 / D 牌组 / Esc 暂停
	if event is InputEventKey and event.pressed and not event.echo:
		if screen == GameScreen.COMBAT and not combat.combat_over:
			# 1-9 打出手牌（序号 = 手牌索引）
			for i in range(9):
				if InputMap.action_has_event("play_card_%d" % (i + 1), event):
					if i < run_state.hand.size():
						_play_card(i)
					accept_event()
					return
			if InputMap.action_has_event("use_flask", event):
				combat.use_flask()
				_maybe_autosave()
				accept_event()
				return
			if InputMap.action_has_event("end_turn", event):
				_end_player_turn()
				accept_event()
				return
		if InputMap.action_has_event("show_deck", event):
			_show_deck_view()
			accept_event()
			return
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			if pause_overlay != null:
				_hide_pause_menu()
			elif screen in [GameScreen.MAP, GameScreen.COMBAT, GameScreen.REWARD]:
				_show_pause_menu()
			accept_event()
			return


func _show_game_over() -> void:
	ProfileService.record_death(run_state.souls_earned, run_state.floor_index, run_state.origin_id)
	RunSaveService.delete_save()
	GameAudio.play(self, "defeat")
	screen = GameScreen.GAME_OVER
	_hide_layers()
	_show_bg("bg_elden")
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(EndScreenView.build_game_over(_show_origin))
	_animate_layer(end_layer)


func _show_victory() -> void:
	ProfileService.record_victory(run_state.ng_plus, run_state.vow_level, run_state.challenge_flags)
	RunSaveService.delete_save()
	GameAudio.play(self, "victory")
	screen = GameScreen.VICTORY
	_hide_layers()
	_show_bg("bg_elden")
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(
		EndScreenView.build_victory(run_state.souls, run_state.deck.size(), _show_origin, run_state.challenge_flags)
	)
	_animate_layer(end_layer)


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
