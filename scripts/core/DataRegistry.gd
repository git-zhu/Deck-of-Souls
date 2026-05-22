class_name DataRegistry
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const OriginData = preload("res://data/OriginData.gd")
const EnemyData = preload("res://data/EnemyData.gd")
const MoveData = preload("res://data/MoveData.gd")
const ActData = preload("res://data/ActData.gd")

const ACT_ORDER: Array[String] = ["limgrave", "stormveil", "liurnia"]

var cards: Dictionary = {}
var origins: Dictionary = {}
var _enemy_templates: Array = []
var acts: Array = []


func load_all() -> void:
	cards = _load_cards()
	origins = _load_origins()
	_enemy_templates = _load_enemies()
	acts = _load_acts()


func get_card(id: String) -> CardData:
	return cards.get(id) as CardData


func all_card_ids() -> Array:
	return cards.keys()


func get_origin(id: String) -> OriginData:
	return origins.get(id) as OriginData


func all_origin_ids() -> Array:
	return origins.keys()


func enemy_templates() -> Array:
	return _enemy_templates


func template_by_name(enemy_name: String) -> Dictionary:
	for template: Dictionary in _enemy_templates:
		if str(template.get("name", "")) == enemy_name:
			return template.duplicate(true)
	return {}


func pick_enemy(rng: RandomNumberGenerator, elite: bool, boss: bool) -> Dictionary:
	var pool: Array = _enemy_templates.filter(
		func(e: Dictionary) -> bool:
			return bool(e.get("boss", false)) == boss and bool(e.get("elite", false)) == elite
	)
	if pool.is_empty():
		pool = _enemy_templates.filter(
			func(e: Dictionary) -> bool:
				return not bool(e.get("boss", false)) and not bool(e.get("elite", false))
		)
	return pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)


func get_act(index: int) -> ActData:
	if acts.is_empty():
		return null
	var i: int = clampi(index, 0, acts.size() - 1)
	return acts[i] as ActData


func pick_named_enemy(rng: RandomNumberGenerator, enemy_name: String, elite: bool, boss: bool) -> Dictionary:
	var found := template_by_name(enemy_name)
	if not found.is_empty():
		return found
	return pick_enemy(rng, elite, boss)


func _load_cards() -> Dictionary:
	var result := {}
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		push_error("Failed to open data/cards directory")
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not file.begins_with("."):
			var card := load("res://data/cards/%s" % file) as CardData
			if card != null and card.id != "":
				result[card.id] = card
		file = dir.get_next()
	dir.list_dir_end()
	return result


func _load_origins() -> Dictionary:
	var result := {}
	var dir := DirAccess.open("res://data/origins")
	if dir == null:
		push_error("Failed to open data/origins directory")
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not file.begins_with("."):
			var origin := load("res://data/origins/%s" % file) as OriginData
			if origin != null and origin.id != "":
				result[origin.id] = origin
		file = dir.get_next()
	dir.list_dir_end()
	return result


func _enemy_to_dict(template: EnemyData) -> Dictionary:
	var moves: Array = []
	for move: MoveData in template.moves:
		moves.append({
			"kind": move.kind,
			"value": move.value,
			"text": move.text,
			"hits": move.hits,
			"block": move.block,
			"vulnerable": move.vulnerable,
			"strength": move.strength,
			"rot": move.rot,
		})
	return {
		"name": template.name,
		"max_hp": template.max_hp,
		"stance": template.stance,
		"souls": template.souls,
		"boss": template.is_boss,
		"elite": template.is_elite,
		"is_act_boss": template.is_act_boss,
		"is_run_boss": template.is_run_boss,
		"moves": moves,
	}


func _load_acts() -> Array:
	var by_id: Dictionary = {}
	var dir := DirAccess.open("res://data/acts")
	if dir == null:
		push_error("Failed to open data/acts directory")
		return []
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not file.begins_with("."):
			var act := load("res://data/acts/%s" % file) as ActData
			if act != null and act.id != "":
				by_id[act.id] = act
		file = dir.get_next()
	dir.list_dir_end()
	var ordered: Array = []
	for act_id in ACT_ORDER:
		if by_id.has(act_id):
			ordered.append(by_id[act_id])
	return ordered


func _load_enemies() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://data/enemies")
	if dir == null:
		push_error("Failed to open data/enemies directory")
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not file.begins_with("."):
			var enemy_res := load("res://data/enemies/%s" % file) as EnemyData
			if enemy_res != null:
				result.append(_enemy_to_dict(enemy_res))
		file = dir.get_next()
	dir.list_dir_end()
	return result
