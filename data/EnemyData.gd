class_name EnemyData
extends Resource

const MoveData = preload("res://data/MoveData.gd")

@export_group("Basic")
@export var name: String
@export var max_hp: int = 30
@export var stance: int = 10
@export var souls: int = 10

@export_group("Classification")
@export var is_elite: bool = false
@export var is_boss: bool = false

@export_group("Boss Flags")
@export var is_act_boss: bool = false
@export var is_run_boss: bool = false

@export_group("Moves")
@export var moves: Array[MoveData] = []
