class_name RunState
extends RefCounted

const FLOORS_PER_ACT := 4
const ACT_COUNT := 3
const TOTAL_FLOORS := 12
const MAP_FLOORS_PHASE1 := 6

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
	deck.assign(origin.deck)
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
