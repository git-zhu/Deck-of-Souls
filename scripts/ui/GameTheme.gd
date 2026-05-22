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
