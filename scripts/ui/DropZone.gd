class_name DropZone
extends Control
## 战斗投放目标区：接收从手牌拖来的卡（DragCard payload）。
## 每个敌人一个 DropZone（target_id = enemy_i），舞台中央一个 DropZone（target_id = ""）。

const GameTheme = preload("res://scripts/ui/GameTheme.gd")

var target_id := ""
var on_drop_card: Callable  # func(card_index: int, target_id: String)

enum State { IDLE, VALID, INVALID }
var _state := State.IDLE


func setup(p_target_id: String, p_on_drop: Callable) -> void:
	target_id = p_target_id
	on_drop_card = p_on_drop


func _accepts_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return d.has("card_index")


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _accepts_data(data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	var idx := int(d.get("card_index", -1))
	if idx >= 0 and on_drop_card.is_valid():
		on_drop_card.call(idx, target_id)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var data: Variant = get_viewport().gui_get_drag_data()
			_state = State.VALID if _accepts_data(data) else State.INVALID
			queue_redraw()
		NOTIFICATION_DRAG_END:
			_state = State.IDLE
			queue_redraw()


func _draw() -> void:
	match _state:
		State.IDLE:
			return
		State.VALID:
			_draw_valid()
		State.INVALID:
			_draw_invalid()


func _draw_valid() -> void:
	var r := Rect2(Vector2.ZERO, size)

	# 金色外发光
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0, 0, 0, 0)
	glow.border_color = Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.35)
	glow.set_border_width_all(5)
	glow.set_corner_radius_all(10)
	draw_style_box(glow, r.grow(4))

	# 金色描边 + 微弱填充
	var border := StyleBoxFlat.new()
	border.bg_color = Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.1)
	border.border_color = Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.95)
	border.set_border_width_all(3)
	border.set_corner_radius_all(8)
	draw_style_box(border, r)


func _draw_invalid() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# 暗化遮罩，提示不可投放
	draw_rect(r, Color(0.06, 0.05, 0.04, 0.45))

	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = Color(0.65, 0.25, 0.25, 0.85)
	border.set_border_width_all(3)
	border.set_corner_radius_all(8)
	draw_style_box(border, r)
