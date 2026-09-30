extends SceneTree
const OUTPUT := "res://../production/qa/v0.4/screenshots/"
var app: Control
var failures := 0
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/v04-cache-review.json"
	root.add_child(app)
	app.audio.enabled=false
	app.skip_animations=true
	app.start_level(0)
	await shot("11-cache-food-closed.png")
	var draw_before: int=app.board.static_draw_calls_total
	await frames(12)
	check(app.board.static_draw_calls_total==draw_before,"Idle static layer must reuse draw commands")
	check(app.try_move(Vector2i.RIGHT),"First food step accepted")
	await shot("12-cache-eaten-open.png")
	check(app.board._static_exit_open and app.state.fruit.is_empty(),"Food consumed opens cached exit")
	app.undo()
	await shot("13-cache-undo-restored.png")
	check(not app.board._static_exit_open and app.state.fruit.size()==1,"Undo refreshes closed exit and food")
	app.skip_animations=false
	check(app.try_move(Vector2i.RIGHT),"Pause scenario move accepted")
	await frames(3)
	app.pause_game()
	await frames(3)
	var reaction: Dictionary=app.board._reaction_time.duplicate(true)
	await frames(12)
	check(app.board._reaction_time==reaction and not app.board.is_processing(),"Pause freezes effects despite cache split")
	app._close_overlay()
	await frames(3)
	app.undo()
	app.start_level(11)
	await shot("14-level12-current.png")
	var directions={"R":Vector2i.RIGHT,"L":Vector2i.LEFT,"U":Vector2i.UP,"D":Vector2i.DOWN}
	var index:=0
	for letter in app.levels[11].solution:
		check(app.try_move(directions[letter]),"Level12 witness accepted")
		while app.busy: await process_frame
		if index in [5,9,12]: await shot("15-level12-step-%02d.png" % (index+1))
		index+=1
	check(app.state.status=="won","Long-body real level12 completed")
	app.start_level(11)
	root.size=Vector2i(390,700)
	root.content_scale_size=Vector2i(390,700)
	await shot("16-resize-short.png")
	var short_cell: float=app.board.cell
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	await shot("17-resize-restored.png")
	check(app.board.cell>short_cell,"Resize recalculates renderer geometry and static layer")
	print("CACHE_ART_REVIEW failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func frames(count:int)->void:
	for i in range(count): await process_frame
func shot(name:String)->void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path(OUTPUT+name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"Screenshot saved")
	print("CAPTURE ",name)
func check(ok:bool,note:String)->void:
	if not ok:
		failures+=1
		push_error(note)
