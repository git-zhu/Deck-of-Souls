class_name GameAudio
extends RefCounted

const PATHS := {
	"ui_click": "res://audio/ui_click.ogg",
	"victory": "res://audio/victory.ogg",
	"defeat": "res://audio/defeat.ogg",
}


static func play(parent: Node, id: String) -> void:
	if parent == null:
		return
	var path: String = str(PATHS.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
