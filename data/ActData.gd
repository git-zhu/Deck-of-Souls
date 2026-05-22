class_name ActData
extends Resource

const MapNodeData = preload("res://data/MapNodeData.gd")

@export var id: String = ""
@export var title: String = ""
@export var subtitle_template: String = "第 %d 段 / 4。%s"
@export var flavor: String = ""
@export var combat_enemies: Array[String] = []
@export var elite_enemies: Array[String] = []
@export var fixed_nodes: Array[MapNodeData] = []
@export var act_boss_name: String = ""
@export var act_boss_title: String = ""
@export var act_boss_body: String = ""
@export var is_final_act: bool = false
