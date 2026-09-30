extends SceneTree
const OUTPUT:="res://../production/qa/v0.4.1/screenshots/"
var app:Control
var failures:=0
func _initialize()->void:call_deferred("capture")
func capture()->void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/fall-food-capture.json"
	root.add_child(app)
	app.audio.enabled=false
	app.start_level(11)
	app.set_process(false)
	app.board.set_process(false)
	for direction in [Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.RIGHT]:
		tap_direction(direction)
		advance(0.8)
	check(app.state.moves==4 and app.state.fruit.size()==2,"RRDR setup is actual four moves with one eaten fruit")
	await shot("01-before-fifth-step.png")
	tap_direction(Vector2i.RIGHT)
	var contact:float=0
	for event in app.animation_food_events:
		if event.cell==Vector2i(6,6):contact=0.16+sqrt(2.0*event.frame/160.0)
	check(contact>0,"Fifth-step animation contains actual falling event at6,6")
	advance(contact-0.025)
	check(app.board.state.fruit.has(Vector2i(6,6)),"World fruit remains before actual contact")
	check(app.counter.text.contains("1 / 3"),"HUD does not count food before contact")
	await shot("02-falling-before-contact.png")
	advance(0.035)
	check(not app.board.state.fruit.has(Vector2i(6,6)),"World food removed at fall contact")
	check(app.counter.text.contains("2 / 3"),"HUD counts food at contact")
	check(app.board.mouth_animation=="swallow","Falling contact plays swallow mouth")
	await shot("03-fall-contact-swallow.png")
	advance(0.50)
	check(app.state.fruit.size()==1 and app.state.growth_pending==1,"Settled fall retains one growth unit")
	await shot("04-fall-eaten-settled.png")
	click_control(app.undo_button)
	await process_frame
	await process_frame
	check(app.state.moves==4 and app.state.fruit.size()==2 and app.state.growth_pending==0,"Native undo restores eaten food and pending")
	await shot("05-undo-food-restored.png")
	tap_direction(Vector2i.RIGHT)
	advance(0.8)
	check(app.state.moves==5 and app.state.fruit.size()==1 and app.state.growth_pending==1,"Re-eating after undo happens exactly once")
	await shot("06-re-eat-complete.png")
	print("FALL_FOOD_CAPTURE failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func advance(duration:float)->void:
	var remaining:=duration
	while remaining>0.000001:
		var dt:=minf(remaining,0.01)
		app._process(dt)
		app.board._process(dt)
		remaining-=dt
func tap_direction(direction:Vector2i)->void:
	var position:Vector2=app.stick.button_center(direction)
	touch(position,true)
	touch(position,false)
func click_control(control:Control)->void:
	var position:Vector2=control.global_position+control.size*.5
	touch(position,true)
	touch(position,false)
func touch(position:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=position
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func shot(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"Save screenshot")
	print("CAPTURE ",name," HUD=",app.counter.text," mouth=",app.board.mouth_animation)
func check(ok:bool,note:String)->void:
	if not ok:
		failures+=1
		push_error(note)
