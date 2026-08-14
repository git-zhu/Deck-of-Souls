class_name GildedFrame
extends Control

# 艾尔登法环风格的"镀金石框"：四角金色符文饰角 + 描边。
# 用法：add_child(GildedFrame.new())，设置 size/anchors 后调用 set_theme_colors()。

const GameTheme = preload("res://scripts/ui/GameTheme.gd")

var gold := GameTheme.GOLD
var gold_dim := GameTheme.GOLD.darkened(0.45)
var edge_color := GameTheme.BORDER
var corner_len := 22.0
var line_w := 2.0
var draw_bg := false
var bg_color := Color(0, 0, 0, 0.25)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_colors(p_gold: Color, p_edge: Color) -> void:
	gold = p_gold
	gold_dim = p_gold.darkened(0.45)
	edge_color = p_edge
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 8 or r.size.y <= 8:
		return
	if draw_bg:
		draw_rect(r, bg_color)
	# outer edge
	var edge := r.grow(-line_w * 0.5)
	draw_rect(edge, edge_color, false, line_w)
	# inner thin line
	var inner := r.grow(-line_w * 2.0)
	draw_rect(inner, gold_dim, false, 1.0)
	# corner ornaments (gold L-shaped runes)
	_draw_corner(r.position + Vector2(line_w, line_w), 1.0)
	_draw_corner(r.position + Vector2(r.size.x - line_w, line_w), -1.0)
	_draw_corner(r.position + Vector2(line_w, r.size.y - line_w), 1.0)
	_draw_corner(r.position + Vector2(r.size.x - line_w, r.size.y - line_w), -1.0)


func _draw_corner(at: Vector2, dir_x: float) -> void:
	var c := at
	var p1 := c + Vector2(corner_len * dir_x, 0)
	var p2 := c + Vector2(0, corner_len)
	draw_line(c, p1, gold, line_w + 0.5)
	draw_line(c, p2, gold, line_w + 0.5)
	# small diamond at the corner
	var d := 3.0
	var diamond := PackedVector2Array([
		c + Vector2(0, -d),
		c + Vector2(d * dir_x, 0),
		c + Vector2(0, d),
		c + Vector2(-d * dir_x, 0),
	])
	draw_colored_polygon(diamond, gold)
