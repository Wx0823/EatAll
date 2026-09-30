extends SceneTree
# Real-scene native touch replay. --fixed-fps 60 is required; not a performance sample.
const OUTPUT := "res://../production/qa/v0.3/screenshots/"
var app: Control
var failures := 0
var touch_position := Vector2.ZERO
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(480,854)
	root.content_scale_size = Vector2i(480,854)
	app = load("res://main.tscn").instantiate()
	app.qa_mode = true
	app.save_path = "user://qa/motion-capture.json"
	root.add_child(app)
	app.audio.enabled = OS.get_cmdline_user_args().has("--audio")
	app.skip_animations = false
	app.start_level(0)
	await frames(35)
	press(Vector2i.RIGHT)
	await frames(8)
	await shot("01-eat-midmotion.png")
	await frames(23)
	release()
	ensure(app.state.status == "won", "Level1 held touch must win")
	await shot("02-win-reaction.png")
	await frames(36)
	app.start_level(6)
	await frames(15)
	press(Vector2i.RIGHT)
	await frames(22)
	release()
	ensure(app.state.status == "lost", "Level7 RR must lose")
	await shot("03-failure-reaction.png")
	await frames(36)
	var undo_button: Control = app.overlay.get_node("Panel/Continue")
	touch_position = undo_button.global_position + undo_button.size * 0.5
	send_touch(true)
	await frames(2)
	release()
	await frames(13)
	ensure(app.state.status == "playing" and app.state.moves == 1, "Native undo button restores first step")
	await tap(Vector2i.UP,15)
	await shot("04-turn-eat.png")
	press(Vector2i.RIGHT)
	await frames(20)
	release()
	await frames(9)
	await tap(Vector2i.DOWN,25)
	ensure(app.state.status == "won", "Level7 RURRD should win after undo")
	await frames(25)
	app.start_level(5)
	await frames(18)
	await tap(Vector2i.RIGHT,14)
	await tap(Vector2i.RIGHT,14)
	await tap(Vector2i.UP,14)
	await tap(Vector2i.RIGHT,14)
	press(Vector2i.DOWN)
	await frames(2)
	release()
	await frames(15)
	await shot("05-gravity-flight.png")
	await frames(22)
	ensure(app.state.status == "won", "Level6 RRURD should land at exit")
	await shot("06-landing-win.png")
	await frames(40)
	print("MOTION_CAPTURE native touch scenarios completed; failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
func frames(count: int) -> void:
	for i in range(count): await process_frame
func press(direction: Vector2i) -> void:
	touch_position = app.stick.button_center(direction)
	send_touch(true)
func send_touch(pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = touch_position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func release() -> void:
	send_touch(false)
func tap(direction: Vector2i, total_frames: int) -> void:
	press(direction)
	await frames(2)
	release()
	await frames(total_frames-2)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ensure(root.get_texture().get_image().save_png(path)==OK,"Screenshot saved")
	print("CAPTURE ",path)
func ensure(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)
