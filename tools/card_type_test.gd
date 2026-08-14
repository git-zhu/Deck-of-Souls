extends SceneTree

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")


func _initialize() -> void:
	# 1. card_type_meta：四类标签 + 颜色
	var expect := {
		"combat": "战斗", "explore": "探索", "event": "事件", "shop": "商店",
	}
	for ct in expect:
		var m := GameTheme.card_type_meta(ct)
		if str(m.get("label", "")) != expect[ct]:
			_fail("card_type_meta(%s) label" % ct)
			return
		if not m.get("color", Color.BLACK) is Color:
			_fail("card_type_meta(%s) color" % ct)
			return

	# 2. map_choice_card：标签文本 + 主边框颜色随 cardType 切换
	var cases: Array = [
		[{"cardType": "combat", "title": "T", "body": "B"}, "战斗", Color("#d64545")],
		[{"cardType": "explore", "title": "T", "body": "B"}, "探索", Color("#5ab86a")],
		[{"cardType": "event", "title": "T", "body": "B"}, "事件", Color("#4a7eb0")],
		[{"cardType": "shop", "title": "T", "body": "B"}, "商店", Color("#c9a227")],
	]
	for c in cases:
		var card := UiBuilders.map_choice_card(c[0], func(): pass)
		if not _tree_has_label_text(card, str(c[1])):
			_fail("badge text %s" % str(c[1]))
			return
		var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null or sb.border_color != c[2]:
			_fail("border color for %s" % str((c[0] as Dictionary).get("cardType")))
			return
		if sb.bg_color != GameTheme.PANEL:
			_fail("card black bg for %s" % str((c[0] as Dictionary).get("cardType")))
			return
		card.queue_free()

	# 3. 兼容：无 cardType 时回退到 kind（combat → 战斗）
	var fb := UiBuilders.map_choice_card({"kind": "combat", "title": "T", "body": "B"}, func(): pass)
	if not _tree_has_label_text(fb, "战斗"):
		_fail("fallback kind badge")
		return
	fb.queue_free()

	print("card_type_test: OK")
	quit()


func _tree_has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _tree_has_label_text(child, text):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
