extends SceneTree
# Deterministic cadence/state tests. This is not a device latency or FPS benchmark.
var app: Control
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.qa_mode = true
	app.save_path = "user://qa/motion-review.json"
	root.add_child(app)
	app.set_process(false)
	app.audio.enabled = false
	app.skip_animations = false
	var terrain: Array = []
	for x in range(40): terrain.append(Vector2i(x,6))
	app.levels.append({"id":99,"title":"QA corridor","hint":"isolated timing fixture","width":40,"height":8,"body":[Vector2i(2,5),Vector2i(1,5),Vector2i(0,5)],"terrain":terrain,"fruit":[Vector2i(35,4)],"hazards":[],"exit":Vector2i(38,5)})
	var times := cadence(0.01,200)
	print("CADENCE dt=0.01 accepted starts seconds=", times)
	if OS.get_cmdline_user_args().has("--baseline"):
		app.queue_free()
		quit(0)
		return
	check(times.size() >= 12, "Held input should start at least 12 moves within two seconds")
	for i in range(1,times.size()):
		var gap: float = times[i]-times[i-1]
		check(gap >= 0.15 and gap <= 0.18, "Held cadence must stay near 160 ms; got %.3f" % gap)
	var sixty := cadence(1.0/60.0,120)
	print("CADENCE dt=1/60 accepted starts seconds=", sixty)
	for i in range(1,sixty.size()):
		check(sixty[i]-sixty[i-1] <= 0.184, "60 Hz cadence must not add an animation-length pause")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	check(app.state.moves == 1 and app.busy, "Press must begin one accepted move immediately")
	app._process(0.04)
	check(not app.board.body_override.is_empty(), "Animation must expose intermediate render positions")
	if not app.board.body_override.is_empty():
		var x: float = app.board.body_override[0].x
		check(x > 2.0 and x < 3.0, "Moving head must be between source and destination")
	app._on_direction(Vector2i.ZERO)
	ticks(60)
	check(app.state.moves == 1 and not app.busy, "Short tap completes exactly one move and stops")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	ticks(4)
	app._on_direction(Vector2i.UP)
	var boundary := 0.0
	for i in range(30):
		app._process(0.01)
		if app.state.moves == 2:
			boundary = 0.05 + i*0.01
			break
	check(boundary >= 0.05 and boundary <= 0.18, "Turn must start at current animation boundary without repeat delay")
	check(app.state.body[0].x == 3 and app.state.body[0].y == 4, "Queued turn must apply UP, not another RIGHT")
	app._on_direction(Vector2i.ZERO)
	ticks(30)
	check(app.state.moves == 2, "Release after accepted turn prevents future moves")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	ticks(3)
	app._on_direction(Vector2i.UP)
	app._on_direction(Vector2i.ZERO)
	ticks(60)
	check(app.state.moves == 1 and app.state.body[0] == Vector2i(3,5), "Release cancels unexecuted turn")
	fresh()
	var original: Dictionary = app.state.duplicate(true)
	app._on_direction(Vector2i.DOWN)
	ticks(100)
	check(app.state == original and app.history.is_empty(), "Terrain-blocked held input must not create state/history changes")
	app._on_direction(Vector2i.LEFT)
	ticks(20)
	check(app.state == original, "Reverse neck input stays invalid")
	app._on_direction(Vector2i.RIGHT)
	check(app.state.moves == 1, "New valid direction immediately recovers from blocked input")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	app._process(3.0)
	check(app.state.moves <= 2, "A long frame may start at most one additional grid move; no catch-up burst")
	app._on_direction(Vector2i.ZERO)
	ticks(30)
	var settled: int = app.state.moves
	ticks(30)
	check(app.state.moves == settled, "No latent catch-up actions after long-frame release")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	ticks(3)
	var committed: Dictionary = app.state.duplicate(true)
	app.pause_game()
	check(app.paused and not app.busy and app.state == committed, "Pause settles rendering without undoing committed logic")
	ticks(100)
	check(app.state == committed, "Paused updates never accept movement")
	app._close_overlay()
	ticks(50)
	check(app.state == committed, "Resume cannot inherit held input")
	app.undo()
	check(app.state.moves == 0 and app.history.is_empty() and app.state.body[0] == Vector2i(2,5), "Undo restores complete pre-move snapshot")
	app._on_direction(Vector2i.RIGHT)
	ticks(3)
	app.undo()
	ticks(60)
	check(app.state.moves == 0 and not app.busy, "Undo during movement cancels visuals and queued repeats")
	app._on_direction(Vector2i.RIGHT)
	ticks(3)
	app.restart_level()
	ticks(80)
	check(app.state.moves == 0 and app.history.is_empty() and not app.busy, "Restart clears movement, history and held input")
	app._on_direction(Vector2i.RIGHT)
	ticks(3)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ticks(50)
	check(app.paused and app.state.moves == 1, "Focus loss settles one move and pauses without repeats")
	app.start_level(6)
	app.set_process(false)
	app._on_direction(Vector2i.RIGHT)
	app._on_direction(Vector2i.ZERO)
	ticks(20)
	app._on_direction(Vector2i.RIGHT)
	app._on_direction(Vector2i.ZERO)
	ticks(18)
	check(app.state.status == "lost" and app.terminal_delay > 0, "Failure must expose reaction before modal")
	check(app.overlay.get_child_count() == 0 and not app.stick.enabled, "Terminal reaction interval disables input without modal")
	check(not app.try_move(Vector2i.UP), "Terminal reaction cannot accept movement")
	app.undo()
	ticks(80)
	check(app.state.status == "playing" and app.state.moves == 1 and app.overlay.get_child_count() == 0, "Undo during terminal delay must cancel stale failure modal")
	check(app.board._particles.is_empty() and app.board._reaction_time.is_empty(), "Undo clears transient reactions")
	app.start_level(6)
	app.set_process(false)
	app._on_direction(Vector2i.RIGHT)
	app._on_direction(Vector2i.ZERO)
	ticks(20)
	app._on_direction(Vector2i.RIGHT)
	app._on_direction(Vector2i.ZERO)
	ticks(18)
	app.restart_level()
	ticks(80)
	check(app.state.moves == 0 and app.overlay.get_child_count() == 0, "Restart during terminal delay cannot show stale modal")
	app.start_level(0)
	app.set_process(false)
	app._on_direction(Vector2i.RIGHT)
	ticks(51)
	check(app.state.status == "won" and app.terminal_delay > 0, "Winning reaction must precede modal")
	ticks(60)
	check(app.overlay.get_node_or_null("Panel") != null and app.state.moves == 3, "Win modal eventually opens without repeat leakage")
	app.start_level(5)
	app.set_process(false)
	for direction in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP, Vector2i.RIGHT]:
		app._on_direction(direction)
		app._on_direction(Vector2i.ZERO)
		ticks(30)
	app._on_direction(Vector2i.DOWN)
	app._on_direction(Vector2i.ZERO)
	app._process(0.16)
	var heights: Array = [app.board.body_override[0].y]
	for i in range(4):
		app._process(0.04)
		heights.append(app.board.body_override[0].y)
	print("FALL head y at 40ms spacing=",heights)
	for i in range(2,heights.size()):
		check(heights[i]-heights[i-1] > heights[i-1]-heights[i-2], "Fall velocity must increase across visual grid boundaries")
	var fallen_shape: Array = app.board.body_override
	for i in range(1,fallen_shape.size()):
		var relative: Vector2 = fallen_shape[i]-fallen_shape[0]
		var expected: Vector2 = Vector2(app.state.body[i]-app.state.body[0])
		check(relative.distance_to(expected) < 0.001, "Gravity must translate all body segments as one shape")
	ticks(30)
	check(app.state.status == "won" and not app.busy, "Multi-row fall settles at correct terminal cell")
	var land_found := false
	for particle in app.board._particles:
		if particle.kind == "land":
			land_found = true
			var center: Vector2 = particle.center
			var under := Vector2i(floori(center.x),floori(center.y))+Vector2i.DOWN
			check(app.levels[5].terrain.has(under), "Landing dust must sit immediately above actual supporting terrain")
	check(land_found, "Landing scenario must have visible dust particles")
	app.start_level(0)
	app.set_process(false)
	app._on_direction(Vector2i.RIGHT)
	app._on_direction(Vector2i.ZERO)
	ticks(17)
	app.pause_game()
	var reaction_before: Dictionary = app.board._reaction_time.duplicate(true)
	check(not app.board.is_processing(), "Pause disables renderer animation process")
	for i in range(6): await process_frame
	check(app.board._reaction_time == reaction_before, "Paused real tree frames must not advance renderer reactions")
	app._close_overlay()
	check(app.board.is_processing(), "Resume re-enables renderer animations")
	for i in range(6): await process_frame
	check(app.board._reaction_time != reaction_before, "Resumed real tree frames advance renderer reactions")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	ticks(15)
	var before_boundary: float = app.board.body_override[0].x
	app._process(0.01)
	check(app.state.moves == 2, "Next continuous move starts at prior move boundary")
	app._process(0.01)
	var after_boundary: float = app.board.body_override[0].x if not app.board.body_override.is_empty() else app.state.body[0].x
	check(absf((3.0-before_boundary)-(after_boundary-3.0)) < 0.002, "Constant held speed must match on both sides of grid boundary")
	app._on_direction(Vector2i.ZERO)
	print("MOTION REVIEW checks=",checks," failures=",failures)
	app.queue_free()
	quit(0 if failures == 0 else 1)
func cadence(dt: float, count: int) -> Array:
	fresh()
	app._on_direction(Vector2i.RIGHT)
	var times: Array = [0.0]
	var prior: int = app.state.moves
	for tick in range(1,count+1):
		app._process(dt)
		if app.state.moves != prior:
			times.append(snappedf(tick * dt,0.0001))
			prior = app.state.moves
	return times
func fresh() -> void:
	app.start_level(app.levels.size()-1)
	app.set_process(false)
func ticks(count: int) -> void:
	for i in range(count): app._process(0.01)
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
