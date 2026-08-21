extends SceneTree

const CombatHudView = preload("res://scripts/ui/CombatHudView.gd")


func _initialize() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(300, 200)
	panel.size = Vector2(100, 100)
	get_root().add_child(panel)

	await process_frame
	var base := panel.position

	# 测试 1：顺序震动，每次结束后下一次
	for i in range(10):
		CombatHudView._shake_panel(panel, 8.0, 0.18)
		await create_timer(0.35).timeout
		print("sequential shake ", i, ": ", panel.position)

	var diff1 := panel.position - base
	print("sequential base=", base, " final=", panel.position, " diff=", diff1)
	if diff1.length() >= 1.0:
		push_error("sequential drift too large: " + str(diff1))
		quit()

	# 测试 2：连续触发（旧 tween 未结束时新震动开始），不应导致位置漂移
	for i in range(10):
		CombatHudView._shake_panel(panel, 8.0, 0.18)
		await create_timer(0.05).timeout
		print("overlapping shake ", i, ": ", panel.position)
	await create_timer(0.5).timeout

	var diff2 := panel.position - base
	print("overlapping base=", base, " final=", panel.position, " diff=", diff2)
	if diff2.length() < 1.0:
		print("shake drift test: OK")
	else:
		push_error("overlapping drift too large: " + str(diff2))
	quit()
