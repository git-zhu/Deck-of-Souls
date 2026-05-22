extends SceneTree

const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const GameAudio = preload("res://scripts/ui/GameAudio.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var origin := registry.get_origin("vagabond")
	if origin == null:
		_fail("vagabond origin missing")
		return
	run_state.reset_for_origin(origin, 42)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)

	var template := registry.pick_named_enemy(rng, "葛瑞克士兵", false, false)
	if template.is_empty():
		_fail("enemy template empty")
		return
	combat.start_combat(template)

	var refs := CombatHudView.build(
		run_state,
		combat,
		registry,
		"[color=#d9ccb3]测试日志[/color]\n",
		132.0,
		178.0,
		func(_i): pass,
		combat.use_flask,
		combat.end_player_turn
	)
	if refs.root == null or refs.hand_row == null or refs.log_box == null:
		_fail("CombatHudRefs missing nodes")
		return
	if not _tree_has_label_prefix(refs.root, "敌方意图"):
		_fail("combat HUD missing intent label")
		return
	if refs.log_box.text.is_empty():
		_fail("combat HUD log_box empty")
		return
	refs.root.queue_free()

	GameAudio.play(get_root(), "ui_click")
	print("combat_hud_test: OK")
	quit()


func _tree_has_label_prefix(node: Node, prefix: String) -> bool:
	if node is Label and (node as Label).text.begins_with(prefix):
		return true
	for child in node.get_children():
		if _tree_has_label_prefix(child, prefix):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
