class_name MoveData
extends Resource

@export var kind: String = "attack"
@export var value: int = 5
@export var text: String
@export var hits: int = 1
@export var block: int = 0
@export var vulnerable: int = 0
@export var strength: int = 0
@export var rot: int = 0
@export var bleed: int = 0        # kind="bleed"：对玩家施加的出血值
@export var weight: int = 1       # 招式选取权重（魂式可背板：权重即个性）
