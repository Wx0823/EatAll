extends SceneTree
const OUTPUT:="res://../production/qa/v0.5.2/screenshots/"
var app:Control
var failures:=0
func _initialize()->void:call_deferred("capture")
func capture()->void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/button-alignment-capture-%d.json"%OS.get_process_id()
	root.add_child(app)
	app.audio.enabled=false
	for locale in ["zh_CN","zh_TW","en"]:
		app._show_home()
		app._set_language(locale)
		app._close_overlay()
		await shot(locale+"-01-home.png")
		await pressed_shot(app.content.get_node("Start"),locale+"-01a-home-pressed.png")
		app._show_home()
		app._settings()
		await shot(locale+"-02-settings.png")
		app._language_settings()
		await shot(locale+"-03-picker.png")
		await pressed_shot(app.overlay.get_node("Panel/LocaleEn"),locale+"-03a-picker-pressed.png")
		app._set_language(locale)
		app._close_overlay()
		app.progress.completed=[0,1,2,3]
		app.show_levels()
		await shot(locale+"-04-levels.png")
		app.start_level(11)
		await shot(locale+"-05-game.png")
		app.pause_game()
		await shot(locale+"-06-pause.png")
		app._close_overlay()
		app.skip_animations=true
		app.start_level(0)
		for direction in [Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.RIGHT]:app.try_move(direction)
		check(app.state.status=="won","Actual L1 win "+locale)
		await shot(locale+"-07-win.png")
		app.start_level(6)
		app.try_move(Vector2i.RIGHT)
		app.try_move(Vector2i.RIGHT)
		check(app.state.status=="lost","Actual L7 failure "+locale)
		await shot(locale+"-08-failure-ui.png")
	root.size=Vector2i(390,700)
	root.content_scale_size=Vector2i(390,700)
	app._show_home()
	app._set_language("en")
	app._close_overlay()
	await shot("en-09-short-home.png")
	app._settings()
	await shot("en-10-short-settings.png")
	app._language_settings()
	await shot("en-11-short-picker.png")
	app._close_overlay()
	app.start_level(11)
	await shot("en-12-short-game.png")
	app.pause_game()
	await shot("en-13-short-pause.png")
	print("BUTTON_ALIGNMENT_CAPTURE failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func shot(name:String)->void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	verify_bounds(app.content)
	verify_bounds(app.overlay)
	var path:=ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"Screenshot save")
	print("CAPTURE ",name)
func check(ok:bool,note:String)->void:
	if not ok:
		failures+=1
		push_error(note)

func verify_bounds(node:Node)->void:
	if node is Label or node is Button:
		var rect:Rect2=node.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(rect),"Visible control stays on screen: "+str(node.name))
		if node is Button:
			var inner:Vector2=node.size-node.get_theme_stylebox("normal").get_minimum_size()
			var measured:Vector2=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size"))
			check(measured.x<=inner.x+1 and measured.y<=inner.y+1,"Button text fits themed surface: "+str(node.name))
	for child in node.get_children():verify_bounds(child)
func pressed_shot(button:Button,file:String)->void:
	var center:Vector2=button.get_global_rect().get_center()
	touch(center,true)
	check(button.button_pressed,"Native touch visibly depresses button")
	await shot(file)
	touch(center,false)
	await process_frame
func touch(point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=root.get_screen_transform()*point
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
