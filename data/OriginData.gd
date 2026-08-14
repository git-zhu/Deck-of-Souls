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

@export_group("Gameplay")
@export var deck: Array[String] = []
@export var weapons: Array[String] = []
