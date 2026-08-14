extends SceneTree

const GameAudio = preload("res://scripts/ui/GameAudio.gd")

const EXPECTED := {
	"ui_click": "res://audio/ui_click.ogg",
	"victory": "res://audio/victory.ogg",
	"defeat": "res://audio/defeat.ogg",
}


func _initialize() -> void:
	var missing: Array[String] = []
	var not_stream: Array[String] = []
	for id in EXPECTED:
		var path: String = EXPECTED[id]
		if not ResourceLoader.exists(path):
			missing.append(path)
			continue
		var stream := load(path)
		if stream == null or not (stream is AudioStream):
			not_stream.append(path)

	if not missing.is_empty():
		push_error("Missing audio assets: %s" % str(missing))
		quit(1)
		return
	if not not_stream.is_empty():
		push_error("Audio assets not AudioStream: %s" % str(not_stream))
		quit(1)
		return

	# GameAudio.play must be a no-op when the resource is absent, and play when present.
	var probe := Node.new()
	root.add_child(probe)
	GameAudio.play(probe, "ui_click")
	GameAudio.play(probe, "does_not_exist")
	GameAudio.play(null, "ui_click")
	await process_frame
	probe.queue_free()
	await process_frame

	print("audio_path_test passed (%d assets)" % EXPECTED.size())
	quit()
