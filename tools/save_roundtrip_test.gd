extends SceneTree

const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunSaveService = preload("res://scripts/core/RunSaveService.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var origin := registry.get_origin("vagabond")
	if origin == null:
		_fail("vagabond origin missing")
		return

	var run := RunState.new()
	run.reset_for_origin(origin, 42)
	run.floor_index = 2
	run.deck.append("heal")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat := CombatController.new(run, registry, rng)
	combat.enemies = [{
		"id": "test",
		"name": "Test",
		"hp": 5,
		"max_hp": 10,
		"stance": 0,
		"stance_max": 0,
		"stance_now": 0,
		"block": 0,
		"rot": 0,
		"bleed": 0,
		"vulnerable": 0,
		"strength": 0,
		"_intent": {"name": "slash", "damage": 6},
	}]
	combat.ember = 2
	combat.combat_over = false

	var run_dict := RunSaveService.run_to_dict(run)
	var run2 := RunState.new()
	RunSaveService.run_from_dict(run2, run_dict)
	if run2.floor_index != 2:
		_fail("floor_index roundtrip expected 2 got %d" % run2.floor_index)
		return
	if not run2.deck.has("heal"):
		_fail("deck roundtrip missing heal")
		return

	var combat_dict := RunSaveService.combat_to_dict(combat)
	var combat2 := CombatController.new(run2, registry, rng)
	RunSaveService.combat_from_dict(combat2, combat_dict)
	if int(combat2.enemy.get("hp", 0)) != 5:
		_fail("enemy hp roundtrip expected 5 got %s" % str(combat2.enemy.get("hp")))
		return
	if combat2.ember != 2:
		_fail("ember roundtrip expected 2 got %d" % combat2.ember)
		return

	print("save_roundtrip_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
