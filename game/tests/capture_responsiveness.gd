extends SceneTree
const OUTPUT := "res://../production/qa/v0.4/screenshots/"
var app: Control
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/v04-mouth-capture.json"
	root.add_child(app)
	app.audio.enabled=false
	app.start_level(0)
	app.set_process(false)
	app.board.set_process(false)
	await shot("01-before.png")
	var touch := InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=app.stick.button_center(Vector2i.RIGHT)
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	advance(0.07)
	await shot("02-opening.png")
	advance(0.055)
	await shot("03-swallow-start.png")
	touch.pressed=false
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	advance(0.065)
	await shot("04-closing.png")
	advance(0.15)
	advance(0.23)
	await shot("05-closed.png")
	app.queue_free()
	await process_frame
	quit(0)
func advance(delta:float)->void:
	app._process(delta)
	app.board._process(delta)
func shot(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(root.get_texture().get_image().save_png(path)==OK)
	print("CAPTURE ",name," mouth=",app.board.mouth_animation," openness=",app.board.mouth_openness)
