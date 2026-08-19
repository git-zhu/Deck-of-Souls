class_name OriginData
extends Resource

@export_group("Basic")
@export var id: String
@export var name: String
@export var level: int = 1
@export var max_hp: int = 60
@export var flasks: int = 2

@export_group("Display")
@export var stats: String
@export var equipment: String
@export var note: String
@export var portrait: Texture2D

@export_group("Attributes")
@export var attr_vigor: int = 10
@export var attr_strength: int = 10
@export var attr_dexterity: int = 10
@export var attr_mind: int = 10
@export var attr_faith: int = 10

@export_group("Gameplay")
@export var deck: Array[String] = []
@export var weapons: Array[String] = []
