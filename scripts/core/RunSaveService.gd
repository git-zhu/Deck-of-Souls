class_name RunSaveService
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RunRewardFlow = preload("res://scripts/core/RunRewardFlow.gd")

const SAVE_PATH := "user://run_save.json"
const SAVE_VERSION := 1

# Matches Main.GameScreen: MAP=2, COMBAT=3, REWARD=4
const SCREEN_MAP := 2
const SCREEN_COMBAT := 3
const SCREEN_REWARD := 4


static func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data: Variant = _read_json()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return int(d.get("save_version", 0)) == SAVE_VERSION and _is_restorable_screen(int(d.get("screen", -1)))


static func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("run_save.json")


static func save_snapshot(main: Node) -> bool:
	var screen: int = int(main.get("screen"))
	if not _is_restorable_screen(screen):
		return false
	var run_state: RunState = main.get("run_state")
	if run_state == null:
		return false
	var snap := {
		"save_version": SAVE_VERSION,
		"screen": screen,
		"run": run_to_dict(run_state),
		"combat": {},
		"reward": {},
		"log_lines": _string_array_from(main.get("log_lines")),
	}
	if screen == SCREEN_COMBAT:
		var combat: CombatController = main.get("combat")
		if combat != null:
			snap["combat"] = combat_to_dict(combat)
	if screen == SCREEN_REWARD:
		var reward_flow: RunRewardFlow = main.get("reward_flow")
		if reward_flow != null:
			snap["reward"] = reward_flow.export_reward_state()
	return _write_json(snap)


static func load_snapshot(main: Node) -> bool:
	var data: Variant = _read_json()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if int(d.get("save_version", 0)) != SAVE_VERSION:
		return false
	var screen: int = int(d.get("screen", -1))
	if not _is_restorable_screen(screen):
		delete_save()
		return false
	var run_state: RunState = main.get("run_state")
	if run_state == null:
		return false
	run_from_dict(run_state, d.get("run", {}))
	var rng: RandomNumberGenerator = main.get("rng")
	if rng != null:
		rng.seed = run_state.run_seed
	var log_src: Variant = d.get("log_lines", [])
	if log_src is Array:
		main.set("log_lines", _string_array_from(log_src))
	main.set("screen", screen)
	match screen:
		SCREEN_MAP:
			main.get("run_flow").show_map()
		SCREEN_COMBAT:
			var combat: CombatController = main.get("combat")
			if combat != null:
				combat_from_dict(combat, d.get("combat", {}))
			main.call("_render_combat")
		SCREEN_REWARD:
			var reward_flow: RunRewardFlow = main.get("reward_flow")
			if reward_flow != null:
				reward_flow.restore_reward_state(d.get("reward", {}))
		_:
			return false
	return true


static func run_to_dict(run: RunState) -> Dictionary:
	return {
		"run_seed": run.run_seed,
		"origin_id": run.origin_id,
		"hp": run.hp,
		"max_hp": run.max_hp,
		"flasks": run.flasks,
		"max_flasks": run.max_flasks,
		"souls": run.souls,
		"floor_index": run.floor_index,
		"deck": run.deck.duplicate(),
		"draw_pile": run.draw_pile.duplicate(),
		"hand": run.hand.duplicate(),
		"discard_pile": run.discard_pile.duplicate(),
		"exhaust_pile": run.exhaust_pile.duplicate(),
		"player_rot": run.player_rot,
		"player_bleed": run.player_bleed,
		"player_vulnerable": run.player_vulnerable,
		"player_strength": run.player_strength,
		"relics": run.relics.duplicate(),
		"memory_stones": run.memory_stones,
		"weapons": run.weapons.duplicate(),
		"attrs": run.attrs.duplicate(),
		"attr_levels": run.attr_levels.duplicate(),
		"smithing_stones": run.smithing_stones.duplicate(),
		"upgraded_cards": run.upgraded_cards.duplicate(),
		"ng_plus": run.ng_plus,
		"vow_level": run.vow_level,
		"challenge_flags": run.challenge_flags.duplicate(),
	}


static func run_from_dict(run: RunState, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	run.run_seed = int(d.get("run_seed", 0))
	run.origin_id = str(d.get("origin_id", "vagabond"))
	run.hp = int(d.get("hp", run.max_hp))
	run.max_hp = int(d.get("max_hp", run.hp))
	run.flasks = int(d.get("flasks", 0))
	run.max_flasks = int(d.get("max_flasks", run.flasks))
	run.souls = int(d.get("souls", 0))
	run.floor_index = int(d.get("floor_index", 0))
	run.deck = _string_array_from(d.get("deck", []))
	run.draw_pile = _string_array_from(d.get("draw_pile", []))
	run.hand = _string_array_from(d.get("hand", []))
	run.discard_pile = _string_array_from(d.get("discard_pile", []))
	run.exhaust_pile = _string_array_from(d.get("exhaust_pile", []))
	run.player_rot = int(d.get("player_rot", 0))
	run.player_bleed = int(d.get("player_bleed", 0))
	run.player_vulnerable = int(d.get("player_vulnerable", 0))
	run.player_strength = int(d.get("player_strength", 0))
	run.relics = _string_array_from(d.get("relics", []))
	run.memory_stones = int(d.get("memory_stones", 0))
	run.weapons = _string_array_from(d.get("weapons", run.weapons))
	var attrs_data: Variant = d.get("attrs", {})
	if typeof(attrs_data) == TYPE_DICTIONARY:
		for k in run.attrs:
			if (attrs_data as Dictionary).has(k):
				run.attrs[k] = int((attrs_data as Dictionary)[k])
	var levels_data: Variant = d.get("attr_levels", {})
	if typeof(levels_data) == TYPE_DICTIONARY:
		for k in run.attr_levels:
			if (levels_data as Dictionary).has(k):
				run.attr_levels[k] = int((levels_data as Dictionary)[k])
	var stones_data: Variant = d.get("smithing_stones", [])
	if typeof(stones_data) == TYPE_ARRAY:
		for i in range(mini(3, (stones_data as Array).size())):
			run.smithing_stones[i] = int((stones_data as Array)[i])
	run.ng_plus = int(d.get("ng_plus", 0))
	run.vow_level = int(d.get("vow_level", 0))
	run.challenge_flags = _string_array_from(d.get("challenge_flags", []))
	run.upgraded_cards = _string_array_from(d.get("upgraded_cards", []))


static func combat_to_dict(combat: CombatController) -> Dictionary:
	var enemies_data: Array = []
	for e in combat.enemies:
		enemies_data.append(e.duplicate(true))
	return {
		"enemies": enemies_data,
		"target_index": combat.target_index,
		"ember": combat.ember,
		"max_ember": combat.max_ember,
		"block": combat.block,
		"combat_over": combat.combat_over,
	}


static func combat_from_dict(combat: CombatController, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	combat.enemies.clear()
	var enemies_data: Variant = d.get("enemies", [])
	if typeof(enemies_data) == TYPE_ARRAY:
		for e in enemies_data:
			if typeof(e) == TYPE_DICTIONARY:
				combat.enemies.append((e as Dictionary).duplicate(true))
	# 向后兼容旧存档：单敌人（enemy 字典）
	if combat.enemies.is_empty():
		var old_enemy: Variant = d.get("enemy", {})
		if typeof(old_enemy) == TYPE_DICTIONARY:
			combat.enemies.append((old_enemy as Dictionary).duplicate(true))
	combat.target_index = int(d.get("target_index", 0))
	combat.ember = int(d.get("ember", combat.max_ember))
	combat.max_ember = int(d.get("max_ember", 3))
	combat.block = int(d.get("block", 0))
	combat.combat_over = bool(d.get("combat_over", false))
	combat.break_choice = {}  # 破绽选择不落存档：加载后安全侧结算（破绽关闭）
	for e in combat.enemies:
		if bool((e as Dictionary).get("break_open", false)):
			(e as Dictionary)["break_open"] = false
			(e as Dictionary)["stance_now"] = int((e as Dictionary).get("stance_max", 1))


static func _is_restorable_screen(screen: int) -> bool:
	return screen == SCREEN_MAP or screen == SCREEN_COMBAT or screen == SCREEN_REWARD


static func _string_array_from(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


static func _read_json() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _write_json(obj: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(obj))
	return true
