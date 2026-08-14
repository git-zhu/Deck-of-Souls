class_name GameTheme
extends RefCounted

const BG := Color("#16130f")
const PANEL := Color("#242018")
const BORDER := Color("#4f4535")
const GOLD := Color("#e0c06c")
const TITLE_GOLD := Color("#e2bd65")
const BODY_MUTED := Color("#c8bca5")
const RELIC_HOOK := Color("#9ec9e8")
const TEXT := Color("#e8ddc7")
const TEXT_MUTED := Color("#d8ccb4")
const LOG_TEXT := Color("#d9ccb3")

const MAX_LOG_LINES := 12


static func apply_theme(root: Control) -> void:
	var theme := Theme.new()
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_font_size("font_size", "RichTextLabel", 16)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", Color("#f0e5cd"))
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("#d8b15d"))
	root.theme = theme


static func map_kind_meta(kind: String) -> Dictionary:
	match kind:
		"combat":
			return {"label": "战斗", "accent": Color("#8b5a3c")}
		"elite":
			return {"label": "精英", "accent": Color("#9b4dca")}
		"boss":
			return {"label": "Boss", "accent": Color("#c0392b")}
		"grace":
			return {"label": "赐福", "accent": Color("#3d8b5a")}
		"merchant":
			return {"label": "商人", "accent": Color("#c9a227")}
		"event":
			return {"label": "事件", "accent": Color("#4a7eb0")}
		_:
			return {"label": "路标", "accent": BORDER}


static func intent_color(kind: String) -> Color:
	match kind:
		"attack", "attack_block", "attack_rot":
			return Color("#e07a6a")
		"block":
			return Color("#e6c56d")
		"buff", "strength":
			return Color("#b08ce0")
		"debuff", "rot":
			return Color("#7ab87a")
		_:
			return Color("#e6c56d")


static func card_disabled_modulate() -> Color:
	return Color(0.55, 0.55, 0.55, 1.0)


# ---- 卡牌语义配色体系（稳定语义，避免随机区分） ----

# 攻击 / 防御 / 技能 / 武器 / 治疗 / 道具
const CARD_ATTACK := Color("#d64545")      # 红色：攻击
const CARD_DEFENSE := Color("#4fc3c9")     # 青色：防御/护甲
const CARD_SKILL := Color("#b06ad4")       # 紫色：战技/技能
const CARD_WEAPON := Color("#d4a13c")      # 金色：武器
const CARD_HEAL := Color("#5ab86a")        # 绿色：治疗/圣杯瓶
const CARD_ITEM := Color("#d47a3c")        # 橙色：壶/道具
const CARD_LEGEND := Color("#c0392b")      # 深红：传说

# 卡牌 type → 语义色
static func card_type_color(type_name: String) -> Color:
	match type_name:
		"武器":
			return CARD_WEAPON
		"盾牌":
			return CARD_DEFENSE
		"战灰":
			return CARD_SKILL
		"魔法":
			return CARD_ATTACK
		"祷告":
			return CARD_HEAL
		"圣杯瓶":
			return CARD_HEAL
		"壶":
			return CARD_ITEM
		"传说":
			return CARD_LEGEND
		_:
			return CARD_WEAPON

# 意图图标（无字体依赖的几何符号）
static func intent_icon(kind: String) -> String:
	match kind:
		"attack":
			return "◆"
		"attack_block":
			return "◈"
		"attack_rot":
			return "▲"
		"block":
			return "◈"
		"buff", "strength":
			return "▲"
		"debuff", "rot":
			return "▼"
		_:
			return "◆"


# 状态 chip 语义色
static func status_color(status_id: String) -> Color:
	match status_id:
		"rot":
			return Color("#7ab87a")
		"bleed":
			return Color("#e07a6a")
		"vulnerable":
			return Color("#e6c56d")
		"strength":
			return Color("#b08ce0")
		"stance":
			return Color("#e6c56d")
		_:
			return TEXT_MUTED
