class_name TargetingLine
extends Control
## 杀戮尖塔式瞄准线：拖拽手牌时从卡牌起点到鼠标/目标画虚线+箭头。
## 全屏叠加层（z 高），由 CombatHudView 创建；DragCard 拖拽时激活。

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const CardData = preload("res://data/CardData.gd")

var active := false
var from_pos := Vector2.ZERO    # 卡牌起点（全局坐标）
var to_pos := Vector2.ZERO      # 当前鼠标/目标（全局坐标）
var target_valid := false       # 是否悬停在可投放目标上
var target_center := Vector2.ZERO
var _line_color := Color(0.95, 0.85, 0.55, 0.9)
var _valid_color := Color(0.9, 0.6, 0.3, 1.0)

# 各敌人 DropZone 注册（target_id -> 全局中心），由 CombatHudView 填充
var zone_centers: Dictionary = {}

var _preview_card: CardData = null
var _preview_box: PanelContainer
var _preview_label: Label


func _ready() -> void:
	_preview_box = PanelContainer.new()
	_preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.82)
	style.border_color = GameTheme.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_preview_box.add_theme_stylebox_override("panel", style)

	_preview_label = Label.new()
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.add_theme_font_size_override("font_size", 13)
	_preview_label.add_theme_color_override("font_color", GameTheme.GOLD)
	_preview_box.add_child(_preview_label)
	add_child(_preview_box)
	_preview_box.visible = false


func set_card_preview(card: CardData) -> void:
	_preview_card = card
	_update_preview_text()


func begin(from_global: Vector2) -> void:
	active = true
	from_pos = from_global
	to_pos = from_global
	target_valid = false
	_update_preview_text()
	queue_redraw()


func update_to(mouse_global: Vector2) -> void:
	if not active:
		return
	to_pos = mouse_global
	# 检测鼠标是否在某敌人 DropZone 内 → 吸附到该敌人中心
	target_valid = false
	for tid in zone_centers:
		var zc: Dictionary = zone_centers[tid]
		if (mouse_global - (zc.get("center", Vector2.ZERO) as Vector2)).length() < float(zc.get("radius", 60.0)):
			target_valid = true
			target_center = zc.get("center", Vector2.ZERO) as Vector2
			to_pos = target_center
			break
	_update_preview_position()
	queue_redraw()


func end() -> void:
	active = false
	_preview_box.visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	# 拖拽中持续跟随鼠标
	if active:
		update_to(get_global_mouse_position())


func _draw() -> void:
	if not active:
		return
	var color := _valid_color if target_valid else _line_color
	var target := to_pos if target_valid else to_pos
	# 虚线（分段绘制）
	var dir := target - from_pos
	var len := dir.length()
	if len < 8.0:
		return
	var seg := 14.0
	var gap := 8.0
	var t := 0.0
	while t < len:
		var a := from_pos + dir.normalized() * t
		var b := from_pos + dir.normalized() * minf(t + seg, len)
		draw_line(a, b, color, 2.5, true)
		t += seg + gap
	# 箭头
	var arrow_dir := dir.normalized()
	var perp := Vector2(-arrow_dir.y, arrow_dir.x)
	var tip := target
	var base := target - arrow_dir * 14.0
	var wing := 7.0
	draw_line(tip, base + perp * wing, color, 2.5, true)
	draw_line(tip, base - perp * wing, color, 2.5, true)
	# 终点光环（命中目标时）
	if target_valid:
		draw_arc(target, 22.0, 0, TAU, 24, _valid_color, 2.0, true)


func _update_preview_text() -> void:
	if _preview_label == null:
		return
	if _preview_card == null:
		_preview_label.text = ""
		return
	var txt := UiBuilders.extract_keywords(_preview_card.text)
	if txt.length() > 28:
		txt = txt.substr(0, 28) + "…"
	_preview_label.text = txt


func _update_preview_position() -> void:
	if _preview_box == null or _preview_label == null:
		return
	if _preview_card == null:
		_preview_box.visible = false
		return

	_preview_box.visible = true
	var box_size := _preview_box.get_combined_minimum_size()
	_preview_box.size = box_size

	var pos := to_pos + Vector2(0, 30)
	pos.x -= box_size.x * 0.5
	var vp := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, vp.x - box_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - box_size.y - 8.0)
	_preview_box.position = pos
