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
	deck.assign(origin.deck)


func can_gain_memory_stone() -> bool:
	return memory_stones < MAX_MEMORY_STONES


func player_hand_draw(extra_from_relics: int = 0) -> int:
	return BASE_HAND_DRAW + memory_stones + extra_from_relics
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
