class_name IntentIcon
extends Control
## 敌人意图图标：自绘几何图形（替代 unicode 字符，避免字体渲染问题）。
## 攻击 = 红色向上三角 / 护甲 = 青色盾形 / 增益 = 紫色菱形（上尖） / 减益 = 绿色菱形（下尖）。

const COLOR_ATTACK := Color("#e07a6a")
const COLOR_BLOCK := Color("#4fc3c9")
const COLOR_BUFF := Color("#b08ce0")
const COLOR_DEBUFF := Color("#7ab87a")

var kind: String = ""


func setup(p_kind: String) -> void:
	kind = p_kind
	queue_redraw()


func _draw() -> void:
	if kind.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var center := get_rect().get_center()
	# 半径取控件 35%（原 46% 导致图形顶点/描边超出控件边界）
	var r := minf(size.x, size.y) * 0.35
	match kind:
		"attack", "attack_block", "attack_rot":
			_draw_triangle(center, r, COLOR_ATTACK)
		"block":
			_draw_shield(center, r, COLOR_BLOCK)
		"buff", "strength":
			_draw_diamond(center, r, COLOR_BUFF, false)
		"debuff", "rot":
			_draw_diamond(center, r, COLOR_DEBUFF, true)
		_:
			_draw_diamond(center, r, COLOR_BLOCK, false)


func _draw_triangle(center: Vector2, r: float, color: Color) -> void:
	# 攻击：红色向上三角形
	var pts := PackedVector2Array([
		center + Vector2(0.0, -r * 1.05),
		center + Vector2(r * 0.95, r * 0.8),
		center + Vector2(-r * 0.95, r * 0.8),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), color.lightened(0.35), 2.0)


func _draw_shield(center: Vector2, r: float, color: Color) -> void:
	# 护甲：青色盾形（顶部圆拱 + 两侧收向底部尖角）
	var pts := PackedVector2Array()
	var dome_steps := 10
	for i in range(dome_steps + 1):
		var t := float(i) / float(dome_steps)
		var ang := PI * (1.0 - t)  # PI（左）→ 0（右）
		pts.append(center + Vector2(cos(ang) * r * 0.92, -sin(ang) * r * 0.5))
	pts.append(center + Vector2(r * 0.58, r * 0.3))
	pts.append(center + Vector2(0.0, r * 1.05))  # 底部尖角
	pts.append(center + Vector2(-r * 0.58, r * 0.3))
	draw_colored_polygon(pts, color)
	draw_polyline(pts, color.lightened(0.35), 2.0)


func _draw_diamond(center: Vector2, r: float, color: Color, inverted: bool) -> void:
	# 增益/减益：菱形（增益上尖，减益下尖）
	var dir := -1.0 if inverted else 1.0
	var pts := PackedVector2Array([
		center + Vector2(0.0, -r * 1.0 * dir),
		center + Vector2(r * 0.85, 0.0),
		center + Vector2(0.0, r * 1.0 * dir),
		center + Vector2(-r * 0.85, 0.0),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), color.lightened(0.35), 2.0)
