extends SceneTree
var checks:=0
var failures:=0
var app:Control
var pad:Control
func _initialize()->void:call_deferred("run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("DPAD QA: "+note)
func touch(p:Vector2,pressed:bool,index:int=0)->void:
	var e:=InputEventScreenTouch.new()
	e.position=root.get_screen_transform()*p
	e.index=index
	e.pressed=pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func drag(p:Vector2,index:int=0)->void:
	var e:=InputEventScreenDrag.new()
	e.position=root.get_screen_transform()*p
	e.index=index
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func mouse(p:Vector2,pressed:bool,device:int=0)->void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_screen_transform()*p
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=pressed
	e.device=device
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func run()->void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	pad=load("res://scripts/direction_pad.gd").new()
	root.add_child(pad)
	pad.position=Vector2(60,300)
	pad.size=Vector2(240,240)
	await process_frame
	var center:=pad.get_global_rect().get_center()
	for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var p:Vector2=pad.button_center(direction)
		touch(p,true)
		check(pad.direction==direction,"Each native direction key selects exact cardinal "+str(direction))
		check(pad.touch_id==0 and not pad.mouse_held,"Raw touch owns key despite mouse emulation")
		touch(p,false)
		check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Release clears selected key and owner")
	touch(center,true)
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Center is blank and does not capture a touch")
	drag(pad.button_center(Vector2i.UP))
	check(pad.direction==Vector2i.ZERO,"Blank-origin drag cannot acquire a key")
	touch(center,false)
	var corner:=pad.global_position+Vector2(3,3)
	touch(corner,true)
	check(pad.direction==Vector2i.ZERO,"Corner between keys cannot diagonally activate")
	touch(corner,false)
	touch(pad.button_center(Vector2i.RIGHT),true)
	drag(pad.button_center(Vector2i.UP))
	check(pad.direction==Vector2i.UP and pad.touch_id==0,"Owner may slide directly from right to up")
	drag(center)
	check(pad.direction==Vector2i.ZERO and pad.touch_id==0,"Slide into central gap stops command but keeps valid owner")
	drag(pad.global_position-Vector2(40,40))
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Leaving entire pad cancels touch ownership")
	drag(pad.button_center(Vector2i.LEFT))
	check(pad.direction==Vector2i.ZERO,"Canceled outside touch cannot restart by dragging back in")
	touch(center,false)
	touch(pad.button_center(Vector2i.RIGHT),true)
	touch(pad.button_center(Vector2i.UP),true,1)
	drag(pad.button_center(Vector2i.LEFT),1)
	check(pad.direction==Vector2i.RIGHT and pad.touch_id==0,"Second finger cannot steal or redirect first")
	touch(center,false,1)
	check(pad.direction==Vector2i.RIGHT,"Second-finger release cannot release owner")
	touch(center,false)
	mouse(pad.button_center(Vector2i.UP),true,InputEvent.DEVICE_ID_EMULATION)
	check(pad.direction==Vector2i.ZERO and not pad.mouse_held,"Standalone synthetic emulation cannot recapture pad")
	mouse(center,false,InputEvent.DEVICE_ID_EMULATION)
	mouse(pad.button_center(Vector2i.DOWN),true)
	check(pad.direction==Vector2i.DOWN and pad.mouse_held,"Real mouse can press cardinal button")
	mouse(center,false)
	check(pad.direction==Vector2i.ZERO,"Real mouse release clears")
	touch(pad.button_center(Vector2i.RIGHT),true)
	pad.enabled=false
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Disabling resets active input immediately")
	touch(pad.button_center(Vector2i.UP),true)
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Disabled pad ignores new input")
	touch(center,false)
	pad.enabled=true
	for extent in [Vector2(180,180),Vector2(162,180)]:
		pad.size=extent
		await process_frame
		check(pad.buttons.size()==4,"Pad has exactly four real buttons")
		var directions:Array=pad.buttons.keys()
		for i in range(directions.size()):
			var button:Button=pad.buttons[directions[i]]
			var rect:=button.get_global_rect()
			check(pad.get_global_rect().encloses(rect),"Every key fits short-screen parent at "+str(extent))
			check(rect.size.x>=44 and rect.size.y>=44,"Key target stays at least44 logical pixels")
			check(not rect.has_point(pad.get_global_rect().get_center()),"Key rectangle leaves center blank")
			for j in range(i+1,directions.size()):
				check(not rect.intersects(pad.buttons[directions[j]].get_global_rect()),"Actual child key rectangles do not overlap")
	touch(pad.button_center(Vector2i.RIGHT),true)
	pad.hide()
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Hide resets owned touch")
	pad.show()
	touch(center,false)
	touch(pad.button_center(Vector2i.RIGHT),true)
	pad.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(pad.direction==Vector2i.ZERO and pad.touch_id==-1,"Standalone focus loss resets owned touch")
	touch(center,false)
	pad.queue_free()
	await process_frame
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/direction-pad.json"
	root.add_child(app)
	app.audio.enabled=false
	var floor_tiles:Array=[]
	for x in range(30):floor_tiles.append(Vector2i(x,6))
	app.levels.append({"id":999,"title":"Dpad QA","hint":"isolated corridor","width":30,"height":8,"body":[Vector2i(2,5),Vector2i(1,5),Vector2i(0,5)],"terrain":floor_tiles,"fruit":[Vector2i(27,4)],"hazards":[],"exit":Vector2i(28,5)})
	fresh()
	press(Vector2i.RIGHT)
	release()
	ticks(50)
	check(app.state.moves==1,"Native short key tap moves exactly once")
	fresh()
	press(Vector2i.RIGHT)
	ticks(65)
	check(app.state.moves==5,"Native held key repeats at existing160ms cadence")
	release()
	ticks(50)
	check(app.state.moves==5,"Release does not leave queued repeats")
	fresh()
	press(Vector2i.RIGHT)
	ticks(5)
	drag(app.stick.button_center(Vector2i.UP))
	ticks(12)
	check(app.state.moves==2 and app.state.body[0]==Vector2i(3,4),"Sliding between keys turns at action boundary")
	release()
	fresh()
	press(Vector2i.RIGHT)
	app.pause_game()
	check(app.paused and app.held==Vector2i.ZERO and app.stick.touch_id==-1,"Pause clears held key ownership")
	app._close_overlay()
	ticks(50)
	check(app.state.moves==1,"Resume does not replay old key hold")
	press(Vector2i.RIGHT)
	app.undo()
	ticks(50)
	check(app.state.moves==1 and app.held==Vector2i.ZERO,"Undo during held movement clears repeat state")
	press(Vector2i.RIGHT)
	app.restart_level()
	ticks(50)
	check(app.state.moves==0 and app.stick.direction==Vector2i.ZERO,"Restart clears direction and history")
	press(Vector2i.RIGHT)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ticks(50)
	check(app.paused and app.state.moves==1 and app.stick.touch_id==-1,"Focus loss pauses and clears active key")
	print("DIRECTION_PAD_QA checks=",checks," failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func fresh()->void:
	app.start_level(app.levels.size()-1)
	app.set_process(false)
func press(direction:Vector2i)->void:touch(app.stick.button_center(direction),true)
func release()->void:touch(app.stick.get_global_rect().get_center(),false)
func ticks(n:int)->void:
	for i in range(n):app._process(0.01)
