class_name EnemyData
extends Resource

const MoveData = preload("res://data/MoveData.gd")

@export_group("Basic")
@export var name: String
@export var portrait: Texture2D
@export var max_hp: int = 30
@export var stance: int = 10
@export var souls: int = 10

@export_group("Classification")
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var duel_only: bool = false  # I7：仅作为特定决斗对手，不进遭遇池/平衡表

@export_group("Boss Flags")
@export var is_act_boss: bool = false
@export var is_run_boss: bool = false

@export_group("Moves")
@export var moves: Array[MoveData] = []

@export_group("Phase 2")
@export var phase2_hp_percent: int = 0       # >0 时：血量首次跌破该百分比进入二阶段
@export var phase2_moves: Array[MoveData] = []
@export var phase2_text: String = ""
