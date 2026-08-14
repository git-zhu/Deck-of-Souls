class_name WeaponData
extends Resource
## 武器数据（艾尔登法环风格装备 + 杀戮尖塔构筑加成）。
## 武器提供战斗加成：基础攻击、姿态伤害、可选战技钩子。

@export_group("Basic")
@export var id: String = ""
@export var name: String = ""
@export var kind: String = "武器"   # 武器/弓/法杖/印记/盾牌
@export var desc: String = ""

@export_group("Combat Bonus")
@export var attack_bonus: int = 0        # 每张攻击卡伤害 +N
@export var stance_bonus: int = 0        # 每张卡姿态削减 +N
@export var block_bonus: int = 0         # 护甲获得 +N
@export var draw_bonus: int = 0          # 每回合多抽 N 张
@export var effect_hook: String = ""     # 战技钩子（如 "giant_cleave"）

@export_group("Upgrade")
@export var level: int = 0               # 武器等级 0-10（锻造石升级）

@export_group("Class")
@export var origins: Array[String] = []  # 限制出身（空 = 无限制）
