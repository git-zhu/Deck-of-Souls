class_name DropZone
extends Control
## 战斗投放目标区：接收从手牌拖来的卡（DragCard payload）。
## 未来多敌人：每个敌人一个 DropZone，target_id = 敌人 id；当前单敌人 target_id = ""。

var target_id := ""
var on_drop_card: Callable  # func(card_index: int, target_id: String)

var _highlight := false


func setup(p_target_id: String, p_on_drop: Callable) -> void:
	target_id = p_target_id
	on_drop_card = p_on_drop


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return d.has("card_index")


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	var idx := int(d.get("card_index", -1))
	if idx >= 0 and on_drop_card.is_valid():
		on_drop_card.call(idx, target_id)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_highlight = true
			queue_redraw()
		NOTIFICATION_DRAG_END:
			_highlight = false
			queue_redraw()


func _draw() -> void:
	if not _highlight:
		return
	# 拖拽悬停高亮：金色虚线框
	var r := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.88, 0.75, 0.4, 0.12)
	style.border_color = Color(0.95, 0.85, 0.55, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	draw_style_box(style, r)
