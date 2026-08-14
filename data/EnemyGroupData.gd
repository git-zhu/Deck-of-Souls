class_name EnemyGroupData
extends Resource
## 群怪遭遇模板：一组敌人（法环群怪设计）。
## 每个敌人以 EnemyData 名引用（如 "geirik_soldier"），start_combat 会解析为多个敌人实例。

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var enemy_names: Array[String] = []
