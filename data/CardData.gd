class_name CardData
extends Resource

const CardEffectStep = preload("res://data/CardEffectStep.gd")

@export_group("Basic")
@export var id: String
@export var name: String
@export var cost: int = 1
@export var type: String = "武器"

@export_group("Metadata")
@export var rarity: String = "common"
@export var text: String
@export var tone: Color = Color("#b9a37b")

@export_group("Effects")
@export var effects: Array[CardEffectStep] = []
@export var hook_id: String = ""
@export var exhaust_after_play: bool = false
