extends SceneTree

const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")
const RunHeaderView = preload("res://scripts/ui/RunHeaderView.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	run_state.reset_for_origin(registry.get_origin("vagabond"), 42)
	run_state.relics.append("ember_and_rot")
	run_state.memory_stones = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run_state, registry, rng)
	var template := registry.pick_named_enemy(rng, "学院辉石法师", false, false)
	combat.start_combat(template)

	var win := get_root()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(host)

	var header := Control.new()
	header.set_anchors_preset(Control.PRESET_FULL_RECT)
	header.custom_minimum_size = Vector2(1280, 48)
	host.add_child(header)
	RunHeaderView.build(header, run_state, registry, func() -> void: pass, func() -> void: pass, false)

	var body := Control.new()
	body.position = Vector2(0, 48)
	body.size = Vector2(1280, 672)
	host.add_child(body)
	var refs := CombatHudView.build(
		run_state, combat, registry, "",
		120.0, 142.0,
		func(_i, _t = "") -> void: pass,
		combat.use_flask,
		combat.end_player_turn
	)
	body.add_child(refs.root)

	await process_frame
	await process_frame
	await process_frame
	var img := win.get_texture().get_image()
	img.save_png("res://tools/_combat_shot.png")
	print("combat screenshot saved")
	quit()
