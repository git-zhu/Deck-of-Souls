class_name RelicData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var body: String = ""
@export var hook: String = ""
@export var value: int = 0
@export var value2: int = 0  # 双重效果护符的次级数值（如 ember_and_rot 的腐败量）
@export var exclusive: bool = false  # 专属护符：不进常规抽取池（大卢恩/铃珠等，I4/I9）
