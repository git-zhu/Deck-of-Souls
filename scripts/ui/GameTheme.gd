class_name GameTheme
extends RefCounted

const BG := Color("#16130f")
const PANEL := Color("#242018")
const BORDER := Color("#4f4535")
const GOLD := Color("#e0c06c")
const ORIGIN_ACCENT := Color("#c9a227")  # 出生卡统一琥珀金边框
const TITLE_GOLD := Color("#e2bd65")
const BODY_MUTED := Color("#c8bca5")
const RELIC_HOOK := Color("#9ec9e8")
const TEXT := Color("#e8ddc7")
const TEXT_MUTED := Color("#d8ccb4")
const LOG_TEXT := Color("#d9ccb3")

const MAX_LOG_LINES := 12


const FONT_XL := 40      # 大标题
const FONT_LG := 26      # 标题
const FONT_MD := 17      # 正文/按钮
const FONT_SM := 14      # 辅助
const FONT_XS := 12      # 卡面/小标签

const BTN_BG := Color("#2a2418")
const BTN_BG_HOVER := Color("#3a2f1c")
const BTN_BG_PRESSED := Color("#201a10")
const BTN_BORDER := Color("#6b5a33")
const BTN_BORDER_HOVER := Color("#e0c06c")


static func apply_theme(root: Control) -> void:
	var theme := Theme.new()
	theme.set_font_size("font_size", "Label", FONT_MD)
	theme.set_font_size("font_size", "Button", FONT_MD)
	theme.set_font_size("font_size", "RichTextLabel", FONT_MD)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", Color("#f0e5cd"))
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("#e0c06c"))

	# 全局按钮四态：暗金描边 + 阴影 + 圆角（法环石碑质感）
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = BTN_BG
	btn_normal.border_color = BTN_BORDER
	btn_normal.set_border_width_all(1)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.shadow_color = Color(0, 0, 0, 0.35)
	btn_normal.shadow_size = 3
	btn_normal.shadow_offset = Vector2(0, 2)
	btn_normal.content_margin_left = 14
	btn_normal.content_margin_right = 14
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = BTN_BG_HOVER
	btn_hover.border_color = BTN_BORDER_HOVER
	btn_hover.set_border_width_all(2)
	btn_hover.shadow_size = 5
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = BTN_BG_PRESSED
	btn_pressed.border_color = GOLD.darkened(0.2)
	btn_pressed.shadow_size = 1
	btn_pressed.shadow_offset = Vector2(0, 0)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color("#1a1712")
	btn_disabled.border_color = Color("#3a342a")
	theme.set_stylebox("disabled", "Button", btn_disabled)

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


# 卡牌四类语义（cardType）：主边框高亮色 + 左上角小标签
static func card_type_meta(card_type: String) -> Dictionary:
	match card_type:
		"combat":
			return {"label": "战斗", "color": Color("#d64545")}
		"explore":
			return {"label": "探索", "color": Color("#5ab86a")}
		"event":
			return {"label": "事件", "color": Color("#4a7eb0")}
		"shop":
			return {"label": "商店", "color": Color("#c9a227")}
		_:
			return {"label": "路标", "color": BORDER}


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

# 意图图标：已改为 UiBuilders.intent_banner 中的自绘几何图形（IntentIcon），
# 本函数保留签名并返回空字符串，避免旧调用方依赖 unicode 字符。
static func intent_icon(_kind: String) -> String:
	return ""


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
