extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const ActData = preload("res://data/ActData.gd")
const MapEncounterData = preload("res://data/MapEncounterData.gd")

const NEW_ENEMIES: Array[String] = ["大树守卫", "狮子混种", "坠星兽"]


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()

	if registry.enemy_templates().size() < 18:
		_fail("expected >= 18 enemies, got %d" % registry.enemy_templates().size())
		return

	for enemy_name in NEW_ENEMIES:
		if registry.template_by_name(enemy_name).is_empty():
			_fail("missing enemy template %s" % enemy_name)
			return

	var seen_in_acts := {}
	for act_index in range(3):
		var act := registry.get_act(act_index) as ActData
		if act == null:
			continue
		for enc in act.combat_encounters + act.elite_encounters:
			var encounter := enc as MapEncounterData
			if encounter == null:
				continue
			seen_in_acts[encounter.enemy_name] = true

	for enemy_name in NEW_ENEMIES:
		if not seen_in_acts.get(enemy_name, false):
			_fail("enemy %s not referenced in any act encounter pool" % enemy_name)
			return

	print("content_pack_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
