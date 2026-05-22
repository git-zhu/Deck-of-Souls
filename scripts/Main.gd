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
	_hide_pause_menu()
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
	_maybe_autosave()


func _maybe_autosave() -> void:
	if screen in [GameScreen.MAP, GameScreen.COMBAT, GameScreen.REWARD]:
		RunSaveService.save_snapshot(self)


func _show_title() -> void:
	_hide_pause_menu()
	screen = GameScreen.TITLE
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	var has_save := RunSaveService.has_save()
	title_layer.add_child(
		TitleScreenView.build(has_save, _on_title_new_game, _on_title_continue, _on_title_quit)
	)


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
	title_layer.visible = true
	_clear(title_layer)
	_build_header()
	title_layer.add_child(OriginScreenView.build(registry, _start_run))


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
	map_layer.visible = true
	_clear(map_layer)
	_build_header()
	map_layer.add_child(content)
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
	combat.play_card(index)


func _show_game_over() -> void:
	RunSaveService.delete_save()
	GameAudio.play(self, "defeat")
	screen = GameScreen.GAME_OVER
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(EndScreenView.build_game_over(_show_origin))


func _show_victory() -> void:
	RunSaveService.delete_save()
	GameAudio.play(self, "victory")
	screen = GameScreen.VICTORY
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	end_layer.add_child(
		EndScreenView.build_victory(run_state.souls, run_state.deck.size(), _start_run)
	)


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
