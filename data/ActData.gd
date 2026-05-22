class_name ActData
extends Resource

const MapNodeData = preload("res://data/MapNodeData.gd")
const MapEncounterData = preload("res://data/MapEncounterData.gd")

@export var id: String = ""
@export var title: String = ""
@export var subtitle_template: String = "第 %d 段 / 4。%s"
@export var flavor: String = ""
@export var combat_encounters: Array[MapEncounterData] = []
@export var elite_encounters: Array[MapEncounterData] = []
@export var reward_cards: Array[String] = []
@export var event_ids: Array[String] = []
@export var fixed_nodes: Array[MapNodeData] = []
@export var act_boss_name: String = ""
@export var act_boss_title: String = ""
@export var act_boss_body: String = ""
@export var is_final_act: bool = false
@export var enemy_hp_percent: int = 100

@export_group("Merchant")
@export var merchant_offer_ids: Array[String] = []
@export var merchant_cost_percent: int = 100

@export_group("Map Weights")
@export var map_weight_combat: int = 4
@export var map_weight_elite: int = 2
@export var map_weight_event: int = 2
@export var map_weight_grace: int = 1
@export var map_weight_merchant: int = 1
