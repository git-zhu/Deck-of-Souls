extends SceneTree

const TargetingLine = preload("res://scripts/ui/TargetingLine.gd")

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var line := TargetingLine.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(line)

	# 1) 未激活时不绘制
	if line.active:
		_fail("should be inactive initially")
		return
	print("inactive OK")

	# 2) 激活
	line.begin(Vector2(100, 600))
	if not line.active:
		_fail("should be active after begin")
		return
	print("begin OK")

	# 3) 注册敌人锚点并测试吸附
	line.zone_centers["enemy_0"] = {"center": Vector2(900, 200), "radius": 70.0}
	line.update_to(Vector2(910, 210))  # 在 enemy_0 锚点内
	if not line.target_valid:
		_fail("should snap to enemy_0 when mouse near it")
		return
	if line.to_pos != Vector2(900, 200):
		_fail("should snap to enemy center, got %s" % str(line.to_pos))
		return
	print("snap to enemy OK:", line.to_pos)

	# 4) 远离目标时不吸附
	line.update_to(Vector2(400, 400))
	if line.target_valid:
		_fail("should NOT be valid far from enemies")
		return
	print("no snap far OK")

	# 5) 结束
	line.end()
	if line.active:
		_fail("should be inactive after end")
		return
	print("end OK")

	line.queue_free()
	await process_frame
	print("targeting_line_test: OK")
	quit()

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
