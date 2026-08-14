class_name CardEffectStep
extends Resource

enum Kind {
	DAMAGE,
	DAMAGE_ALL,          # AOE：对全体存活敌人造成伤害
	APPLY_ALL_VULN,      # AOE：对全体敌人施加易伤
	APPLY_ALL_ROT,       # AOE：对全体敌人施加腐败
	APPLY_ALL_BLEED,     # AOE：对全体敌人施加出血
	GAIN_BLOCK,
	HEAL,
	DRAW,
	APPLY_BLEED,
	APPLY_ROT_ON_ENEMY,
	APPLY_VULN_ON_ENEMY,
	GAIN_STRENGTH,
}

@export var kind: Kind = Kind.DAMAGE
@export var value: int = 0
@export var stance: int = 0
@export var hits: int = 1
