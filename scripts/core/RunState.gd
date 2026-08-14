class_name RunState
extends RefCounted

const OriginData = preload("res://data/OriginData.gd")

const FLOORS_PER_ACT := 4
const ACT_COUNT := 3
const TOTAL_FLOORS := 12
const BASE_HAND_DRAW := 5
const MAX_MEMORY_STONES := 3

var run_seed: int = 0
var origin_id: String = "vagabond"
var hp: int = 72
var max_hp: int = 72
var flasks: int = 2
var max_flasks: int = 2
var souls: int = 0
var floor_index: int = 0
var deck: Array[String] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var player_rot: int = 0
var player_bleed: int = 0
var player_vulnerable: int = 0
var player_strength: int = 0
var relics: Array[String] = []
var memory_stones: int = 0
var weapons: Array[String] = []

# ── 属性加点（法环式）：基础属性 + 升级加点 ──
var attrs := {
	"vigor": 0,       # 生命
	"strength": 0,    # 力量（物理伤害）
	"dexterity": 0,   # 灵巧（姿态伤害）
	"mind": 0,        # 集中（魔法伤害 + 每回合能量）
	"faith": 0,       # 信仰（祷告伤害/治疗）
}
var attr_levels := {
	"vigor": 0,
	"strength": 0,
	"dexterity": 0,
	"mind": 0,
	"faith": 0,
}
var smithing_stones: Array[int] = [0, 0, 0]  # [1级, 2级, 3级] 锻造石


func act_index() -> int:
	return floor_index / FLOORS_PER_ACT


func is_act_boss_floor() -> bool:
	return floor_index % FLOORS_PER_ACT == FLOORS_PER_ACT - 1


func advance_floor() -> void:
	floor_index += 1


func reset_for_origin(origin: OriginData, seed: int) -> void:
	run_seed = seed
	origin_id = origin.id
	max_hp = origin.max_hp
	hp = max_hp
	max_flasks = origin.flasks
	flasks = max_flasks
	souls = 0
	floor_index = 0
	player_rot = 0
	player_bleed = 0
	player_vulnerable = 0
	player_strength = 0
	relics.clear()
	memory_stones = 0
	weapons.assign(origin.weapons)
	attrs = {
		"vigor": origin.attr_vigor,
		"strength": origin.attr_strength,
		"dexterity": origin.attr_dexterity,
		"mind": origin.attr_mind,
		"faith": origin.attr_faith,
	}
	attr_levels = {
		"vigor": 0,
		"strength": 0,
		"dexterity": 0,
		"mind": 0,
		"faith": 0,
	}
	smithing_stones = [0, 0, 0]
	deck.assign(origin.deck)


func can_gain_memory_stone() -> bool:
	return memory_stones < MAX_MEMORY_STONES


func replace_card_in_deck(removed_id: String, new_id: String) -> void:
	var idx := deck.find(removed_id)
	if idx >= 0:
		deck.remove_at(idx)
	deck.append(new_id)


func player_hand_draw(extra_from_relics: int = 0) -> int:
	return BASE_HAND_DRAW + memory_stones + extra_from_relics


func attr(key: String) -> int:
	return int(attrs.get(key, 0))


func upgrade_attr(key: String, cost: int) -> bool:
	if not attrs.has(key) or souls < cost:
		return false
	souls -= cost
	attrs[key] = int(attrs[key]) + 1
	attr_levels[key] = int(attr_levels.get(key, 0)) + 1
	# 生命属性即时生效
	if key == "vigor":
		max_hp += 2
		hp += 2
	return true


func attr_upgrade_level(key: String) -> int:
	return int(attr_levels.get(key, 0))
