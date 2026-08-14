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
var menu_button: Button
var pause_overlay: Control

func _ready() -> void:
	rng.randomize()
	# 正式 UI：隐藏调试构建的窗口标题 (DEBUG) 后缀
	get_window().title = "老头牌：褪色者的牌局"
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
var _bg_current: String = ""


func _build_ui() -> void:
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.texture = _load_bg("bg_elden")
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

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


func _load_bg(kind: String) -> Texture2D:
	match kind:
		"combat":
			return load("res://assets/bg_combat.svg") as Texture2D
		_:
			return load("res://assets/bg_elden.svg") as Texture2D


func _show_bg(kind: String) -> void:
	if bg_rect == null or kind == _bg_current:
		return
	bg_rect.texture = _load_bg(kind)
	_bg_current = kind


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
	_hide_layers()
	_show_bg("bg_elden")
	title_layer.visible = true
	_clear(title_layer)
	_build_header()
	title_layer.add_child(OriginScreenView.build(registry, _start_run))
	_animate_layer(title_layer)
	_focus_first_button(title_layer)


func _start_run(origin_id: String = "vagabond") -> void:
	var seed := randi()
	rng.seed = seed
	var origin := registry.get_origin(origin_id)
	if origin == null:
		origin = registry.get_origin("vagabond")
	run_state.reset_for_origin(origin, seed)
	RunSaveService.delete_save()
	log_lines.clear()
	_log("出身：%s。装备：%s。" % [origin.name, origin.equipment])
	run_flow.show_map()


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
	combat.start_combat(template)
	_render_combat()
	_maybe_autosave()


func _end_player_turn() -> void:
	combat.end_player_turn()
	_maybe_autosave()


func _render_combat() -> void:
	_hide_layers()
	_show_bg("combat")
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
		_end_player_turn
	)
	combat_layer.add_child(refs.root)
	player_panel = refs.player_panel
	enemy_panel = refs.enemy_panel
	log_box = refs.log_box
	hand_row = refs.hand_row
	flask_button = refs.flask_button
	end_turn_button = refs.end_turn_button
	_animate_layer(combat_layer)
	_focus_first_button(combat_layer)


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
	DeckPopupView.show(self, run_state.deck, registry)


func _play_card(index: int) -> void:
	GameAudio.play(self, "ui_click")
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
	RunSaveService.delete_save()
	GameAudio.play(self, "victory")
	screen = GameScreen.VICTORY
	_hide_layers()
	_show_bg("bg_elden")
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(
		EndScreenView.build_victory(run_state.souls, run_state.deck.size(), _start_run)
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
