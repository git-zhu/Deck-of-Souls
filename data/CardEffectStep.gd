class_name CardEffectStep
extends Resource

enum Kind {
	DAMAGE,
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
