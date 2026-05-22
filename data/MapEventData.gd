class_name MapEventData
extends Resource

const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var choices: Array[MapEventChoiceData] = []
