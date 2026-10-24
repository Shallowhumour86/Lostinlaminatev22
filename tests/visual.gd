extends SceneTree
var game: Node
var frames: int = 0
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
func _process(_delta: float) -> bool:
	frames += 1
	if frames==3:
		game._choose("new")
		game.enter("hub")
	if frames==20:
		var image := root.get_texture().get_image()
		if image == null: quit(1); return true
		image.save_png("/tmp/lil-concourse.png")
		game.enter("hotel")
		game._title()
	if frames==25:
		root.get_texture().get_image().save_png("/tmp/lil-title.png")
		game.queue_free()
		quit()
	return false
