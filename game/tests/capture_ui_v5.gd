extends SceneTree
const OUTPUT:="res://../production/qa/v0.5/screenshots/"
var app:Control
var failures:=0
func _initialize()->void:call_deferred("capture")
func capture()->void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/ui-v5-capture.json"
	root.add_child(app)
	app.audio.enabled=false
	app.progress.completed=[]
	app._show_home()
	await shot("01-home.png")
	var start:Control=app.content.get_node("Start")
	var start_center:Vector2=start.get_global_rect().get_center()
	touch(start_center,true)
	await shot("02-home-pressed.png")
	touch(start_center,false)
	await process_frame
	await process_frame
	check(app.mode=="play","Native start button click enters game")
	app.start_level(11)
	await shot("03-level12.png")
	app.set_process(false)
	touch(app.stick.button_center(Vector2i.UP),true)
	check(app.stick.direction==Vector2i.UP and app.stick.buttons[Vector2i.UP].button_pressed,"Native key has selected pressed visual")
	await shot("04-up-key-pressed.png")
	touch(app.stick.button_center(Vector2i.UP),false)
	app.pause_game()
	await shot("05-pause.png")
	app._close_overlay()
	app._show_home()
	app._settings()
	await shot("06-settings.png")
	app._close_overlay()
	app.progress.completed=[0,1,2,3]
	app.show_levels()
	await shot("07-level-select.png")
	app.start_level(11)
	root.size=Vector2i(390,700)
	root.content_scale_size=Vector2i(390,700)
	await shot("08-short-screen.png")
	check_key_geometry()
	app.progress.left_handed=true
	app._layout()
	await shot("09-short-right-hand.png")
	check_key_geometry()
	app._show_home()
	app._settings()
	await shot("10-short-settings.png")
	print("UI_V5_CAPTURE failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func touch(point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new()
	event.position=root.get_screen_transform()*point
	event.pressed=pressed
	event.index=0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func check_key_geometry()->void:
	for direction in app.stick.buttons:
		var button:Button=app.stick.buttons[direction]
		check(app.stick.get_global_rect().encloses(button.get_global_rect()),"Actual short-screen key stays inside parent")
		check(button.size.x>=44 and button.size.y>=44,"Actual key target at least44px")
func shot(name:String)->void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"Screenshot save")
	print("CAPTURE ",name)
func check(ok:bool,note:String)->void:
	if not ok:
		failures+=1
		push_error(note)
