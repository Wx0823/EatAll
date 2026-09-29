extends SceneTree
const OUTPUT := "res://../production/qa/v0.2/screenshots/"
const Board = preload("res://scripts/board_renderer.gd")
var app: Control
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(480, 854)
	root.content_scale_size = Vector2i(480, 854)
	app = load("res://main.tscn").instantiate()
	app.save_path = "user://qa/visual-v2-review.json"
	app.qa_mode = true
	app.skip_animations = true
	root.add_child(app)
	app.audio.enabled = false
	app.progress.completed = []
	app._show_home()
	await shot("06-home-revised.png")
	app.start_level(5)
	await shot("07-level06-revised.png")
	app.start_level(11)
	await shot("08-level12-revised.png")
	app.start_level(6)
	assert(app.try_move(Vector2i.RIGHT))
	assert(app.try_move(Vector2i.UP))
	assert(app.state.fruit.is_empty() and app.state.status == "playing")
	await shot("09-level07-exit-open.png")
	app.start_level(6)
	assert(app.try_move(Vector2i.RIGHT))
	assert(app.try_move(Vector2i.RIGHT))
	assert(app.state.status == "lost")
	await shot("10-level07-failure-panel.png")
	app._close_overlay() # QA-only: reveal the same lost state beneath terminal overlay.
	await shot("11-level07-failure-board.png")
	app.start_level(11)
	app.skip_animations = false
	await process_frame
	assert(app.try_move(Vector2i.RIGHT))
	for frame in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
		if not app.busy:
			push_error("Expected moving frame, not settled substitute")
			quit(1)
			return
		save_shot("12-moving-frame-%02d.png" % frame)
	app.skip_animations = true
	app.start_level(11)
	root.size = Vector2i(390, 700)
	root.content_scale_size = Vector2i(390, 700)
	await shot("13-short-screen-revised.png")
	root.size = Vector2i(480, 854)
	root.content_scale_size = Vector2i(480, 854)
	app._show_home()
	app.content.visible = false
	var fixture := Control.new()
	fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(fixture)
	var backdrop := ColorRect.new()
	backdrop.color = Color("fff0d1")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture.add_child(backdrop)
	var label := Label.new()
	label.text = "ART FIXTURE / NOT A PLAYABLE LEVEL\nFour directions and continuous L / U curves"
	label.position = Vector2(18, 14)
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color("4d2543")
	fixture.add_child(label)
	var poses := [
		[Vector2i(3,2),Vector2i(2,2),Vector2i(1,2),Vector2i(1,3)],
		[Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(3,3)],
		[Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),Vector2i(3,2)],
		[Vector2i(3,3),Vector2i(3,2),Vector2i(3,1),Vector2i(2,1),Vector2i(1,1),Vector2i(1,2)]
	]
	for index in range(4):
		var board := Board.new()
		fixture.add_child(board)
		board.position = Vector2(10 + (index % 2)*235, 95+(index/2)*330)
		board.size = Vector2(225,315)
		board.set_data({"width":5,"height":5,"terrain":[],"hazards":[]}, {"body":poses[index],"fruit":[],"status":"playing"})
	await shot("14-four-directions-art-fixture.png")
	app.queue_free()
	await process_frame
	quit(0)
func shot(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	save_shot(filename)
func save_shot(filename: String) -> void:
	var output: String = ProjectSettings.globalize_path(OUTPUT + filename)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("CAPTURE ", output)
