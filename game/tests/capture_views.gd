extends SceneTree
const OUTPUT := "res://../production/qa/v0.1/screenshots/"
var app: Control
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(480, 854)
	root.content_scale_size = Vector2i(480, 854)
	app = load("res://main.tscn").instantiate()
	app.save_path = "user://qa/visual.json"
	app.qa_mode = true
	app.skip_animations = true
	root.add_child(app)
	app.audio.enabled = false
	app.progress.completed = []
	app._show_home()
	await shot("01-home.png")
	app.start_level(5)
	await shot("02-level06.png")
	app.start_level(11)
	await shot("03-level12.png")
	var dirs := {"R":Vector2i.RIGHT,"L":Vector2i.LEFT,"U":Vector2i.UP,"D":Vector2i.DOWN}
	for letter in app.levels[11].solution:
		if not app.try_move(dirs[letter]):
			push_error("Capture witness blocked")
			quit(1)
			return
	assert(app.state.status == "won")
	await shot("04-complete.png")
	app.start_level(11)
	root.size = Vector2i(390, 700)
	root.content_scale_size = Vector2i(390, 700)
	await shot("05-short-screen.png")
	app.queue_free()
	await process_frame
	quit(0)
func shot(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path(OUTPUT + filename)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error: int = root.get_texture().get_image().save_png(output)
	assert(error == OK)
	print("CAPTURE ", output)
