class_name DeckPopupView
extends RefCounted

const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const DeckUtils = preload("res://scripts/ui/DeckUtils.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardData = preload("res://data/CardData.gd")

const EMPTY_MUTED := Color("#9a8f78")
const SUMMARY_MUTED := Color("#d8ccb4")


static func show(parent: Node, deck: Array, registry: DataRegistry, title: String = "牌组") -> void:
	var counts := DeckUtils.card_counts(deck)
	var popup := AcceptDialog.new()
	popup.title = title
	popup.ok_button_text = "关闭"
	popup.min_size = Vector2i(660, 520)
	parent.add_child(popup)

	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 12)
	body.add_theme_constant_override("margin_right", 12)
	body.add_theme_constant_override("margin_top", 10)
	body.add_theme_constant_override("margin_bottom", 6)
	body.custom_minimum_size = Vector2(620, 440)
	popup.add_child(body)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(outer)

	var summary := Label.new()
	summary.text = "共 %d 张（%d 种）" % [deck.size(), counts.size()]
	summary.add_theme_font_size_override("font_size", 17)
	summary.add_theme_color_override("font_color", SUMMARY_MUTED)
	outer.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(596, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if counts.is_empty():
		var empty := Label.new()
		empty.text = "牌组为空。"
		empty.add_theme_color_override("font_color", EMPTY_MUTED)
		list.add_child(empty)
	else:
		var ids: Array = counts.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ca: CardData = registry.get_card(a)
			var cb: CardData = registry.get_card(b)
			return ca.name < cb.name if ca != null and cb != null else str(a) < str(b)
		)
		for id in ids:
			var card: CardData = registry.get_card(str(id))
			if card != null:
				list.add_child(UiBuilders.deck_summary_row(card, int(counts[id])))

	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)
