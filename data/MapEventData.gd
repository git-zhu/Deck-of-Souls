class_name MapEventData
extends Resource

const MapEventChoiceData = preload("res://data/MapEventChoiceData.gd")

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var required_flag: String = ""  # I7：仅当 run.event_flags 持有时此事件才出现
@export var choices: Array[MapEventChoiceData] = []
