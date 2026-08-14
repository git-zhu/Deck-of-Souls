class_name DataRegistry
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const OriginData = preload("res://data/OriginData.gd")
const EnemyData = preload("res://data/EnemyData.gd")
const MoveData = preload("res://data/MoveData.gd")
const ActData = preload("res://data/ActData.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")
const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const RelicData = preload("res://data/RelicData.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const EnemyGroupData = preload("res://data/EnemyGroupData.gd")
const DataRegistryPaths = preload("res://scripts/core/DataRegistryPaths.gd")

const ACT_ORDER: Array[String] = ["limgrave", "stormveil", "liurnia"]

var cards: Dictionary = {}
var origins: Dictionary = {}
var _enemy_templates: Array = []
var _enemy_groups: Dictionary = {}
var acts: Array = []
var grace_options: Dictionary = {}
var merchant_offers: Dictionary = {}
var relics: Dictionary = {}
var events: Dictionary = {}


func load_all() -> void:
	cards = _load_cards()
	origins = _load_origins()
	_enemy_templates = _load_enemies()
	_enemy_groups = _load_enemy_groups()
	acts = _load_acts()
	grace_options = _load_grace_options()
	merchant_offers = _load_merchant_offers()
	relics = _load_relics()
	events = _load_events()


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
	# 支持按中文名或文件 id（如 wild_wolf）匹配
	for template: Dictionary in _enemy_templates:
		if str(template.get("name", "")) == enemy_name:
			return template.duplicate(true)
		if str(template.get("file_id", "")) == enemy_name:
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


func get_grace_option(id: String) -> GraceOptionData:
	return grace_options.get(id) as GraceOptionData


func all_grace_option_ids() -> Array:
	return grace_options.keys()


func get_merchant_offer(id: String) -> MerchantOfferData:
	return merchant_offers.get(id) as MerchantOfferData


func all_merchant_offer_ids() -> Array:
	return merchant_offers.keys()


func get_relic(id: String) -> RelicData:
	return relics.get(id) as RelicData


func all_relic_ids() -> Array:
	return relics.keys()


func get_event(id: String) -> MapEventData:
	return events.get(id) as MapEventData


func all_event_ids() -> Array:
	return events.keys()


func pick_named_enemy(rng: RandomNumberGenerator, enemy_name: String, elite: bool, boss: bool) -> Dictionary:
	var found := template_by_name(enemy_name)
	if not found.is_empty():
		return found
	# 群怪：按组名解析为多敌人模板（enemies 数组）
	var group := resolve_group(enemy_name)
	if not group.is_empty():
		return group
	return pick_enemy(rng, elite, boss)


func _load_enemy_groups() -> Dictionary:
	var result := {}
	for group_res in DataRegistryPaths.GROUP_RESOURCES:
		var g := group_res as EnemyGroupData
		if g != null and g.id != "":
			result[g.id] = g
	return result


func group_ids() -> Array:
	return _enemy_groups.keys()


func get_group(id: String) -> EnemyGroupData:
	return _enemy_groups.get(id) as EnemyGroupData


# 解析群怪模板：返回含 enemies 数组的模板（供 CombatController.start_combat 使用）
func resolve_group(group_id: String) -> Dictionary:
	var g := get_group(group_id)
	if g == null or g.enemy_names.is_empty():
		return {}
	var templates: Array = []
	for ename in g.enemy_names:
		var t := template_by_name(str(ename))
		if not t.is_empty():
			templates.append(t)
	if templates.is_empty():
		return {}
	return {
		"group_id": g.id,
		"title": g.title,
		"body": g.body,
		"enemies": templates,
	}


func _load_cards() -> Dictionary:
	var result := {}
	for card in DataRegistryPaths.CARD_RESOURCES:
		var c := card as CardData
		if c != null and c.id != "":
			result[c.id] = c
	return result


func _load_origins() -> Dictionary:
	var result := {}
	for origin in DataRegistryPaths.ORIGIN_RESOURCES:
		var o := origin as OriginData
		if o != null and o.id != "":
			result[o.id] = o
	return result


func _enemy_to_dict(template: EnemyData, res_path: String = "") -> Dictionary:
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
	# file_id 从资源路径推断（如 res://data/enemies/wild_wolf.tres -> wild_wolf）
	var file_id := ""
	if res_path != "":
		file_id = res_path.get_file().get_basename()
	return {
		"file_id": file_id,
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
	for act_res in DataRegistryPaths.ACT_RESOURCES:
		var act := act_res as ActData
		if act != null and act.id != "":
			by_id[act.id] = act
	var ordered: Array = []
	for act_id in ACT_ORDER:
		if by_id.has(act_id):
			ordered.append(by_id[act_id])
	return ordered


func _load_grace_options() -> Dictionary:
	var result := {}
	for opt_res in DataRegistryPaths.GRACE_OPTION_RESOURCES:
		var opt := opt_res as GraceOptionData
		if opt != null and opt.id != "":
			result[opt.id] = opt
	return result


func _load_relics() -> Dictionary:
	var result := {}
	for relic_res in DataRegistryPaths.RELIC_RESOURCES:
		var relic := relic_res as RelicData
		if relic != null and relic.id != "":
			result[relic.id] = relic
	return result


func _load_events() -> Dictionary:
	var result := {}
	for event_res in DataRegistryPaths.EVENT_RESOURCES:
		var event := event_res as MapEventData
		if event != null and event.id != "":
			result[event.id] = event
	return result


func _load_merchant_offers() -> Dictionary:
	var result := {}
	for offer_res in DataRegistryPaths.MERCHANT_OFFER_RESOURCES:
		var offer := offer_res as MerchantOfferData
		if offer != null and offer.id != "":
			result[offer.id] = offer
	return result


func _load_enemies() -> Array:
	var result: Array = []
	for enemy_res in DataRegistryPaths.ENEMY_RESOURCES:
		var enemy := enemy_res as EnemyData
		if enemy != null:
			result.append(_enemy_to_dict(enemy, enemy_res.resource_path))
	return result
