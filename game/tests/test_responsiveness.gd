extends SceneTree
var app: Control
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.qa_mode = true
	app.save_path = "user://qa/responsiveness.json"
	root.add_child(app)
	app.set_process(false)
	app.audio.enabled = false
	var floor_tiles: Array = []
	for x in range(40): floor_tiles.append(Vector2i(x,6))
	app.levels.append({"id":100,"title":"QA variable frames","hint":"isolated fixture","width":40,"height":8,"body":[Vector2i(2,5),Vector2i(1,5),Vector2i(0,5)],"terrain":floor_tiles,"fruit":[Vector2i(35,4)],"hazards":[],"exit":Vector2i(38,5)})
	app.start_level(app.levels.size()-1)
	app._on_direction(Vector2i.RIGHT)
	var previous := render_head()
	var stamps: Array = []
	var elapsed := 0.0
	var changes := 0
	var deltas := [0.015,0.018,0.011,0.026,0.009,0.021,0.017,0.019,0.008,0.024,0.016]
	for i in range(100):
		var dt: float = deltas[i % deltas.size()]
		var before_moves: int = app.state.moves
		app._process(dt)
		elapsed += dt
		var current := render_head()
		check(current.x >= previous.x-0.0001,"Visible head cannot snap backwards at a new action boundary")
		check(current.x-previous.x <= dt/0.16 + 0.025,"Visible head displacement must be bounded by frame time, not skip a cell")
		if before_moves != app.state.moves:
			changes += 1
			stamps.append([snappedf(elapsed,0.001), current.x, app.state.body[0].x, app.board.body_override.size()])
		check(absf(current.x-(2.0+elapsed/0.16)) < 0.002,"Ordinary variable deltas must retain fractional progress without drift")
		previous = current
	print("VARIABLE_BOUNDARIES [time, rendered x, committed x, override size]=",stamps)
	check(changes >= 8,"Variable frame replay should cross multiple action boundaries")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	app._process(0.14)
	app._on_direction(Vector2i.UP)
	app._process(0.04)
	var turned := render_head()
	check(app.state.moves == 2 and turned.distance_to(Vector2(3.0,4.875)) < 0.002, "Turn must apply carry along new axis in the boundary frame")
	app._on_direction(Vector2i.ZERO)
	app._process(0.20)
	check(app.state.moves == 2 and render_head() == Vector2(3,4), "Release finishes accepted turn and adds no extra step")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	app._process(0.10)
	app._on_direction(Vector2i.UP)
	app._process(0.02)
	app._on_direction(Vector2i.ZERO)
	app._process(0.08)
	check(app.state.moves == 1 and render_head() == Vector2(3,5), "Short flick released before boundary cancels unexecuted direction")
	for gap in [0.081,0.2,0.6,2.0]:
		fresh()
		app._on_direction(Vector2i.RIGHT)
		app._process(0.15)
		app._process(gap)
		check(app.state.moves == 2, "Stalled frame must accept at most one additional logical step")
		check(render_head() == Vector2(3,5), "Stalled frame above carry cap must not jump into catch-up visual step")
		app._on_direction(Vector2i.ZERO)
		app._process(0.5)
		check(app.state.moves == 2, "Released stalled input has no latent catch-up queue")
	fresh()
	app._on_direction(Vector2i.RIGHT)
	app._process(0.15)
	app._process(0.08)
	check(render_head().distance_to(Vector2(3.4375,5)) < 0.002, "Exactly80ms frame is included in source's <= carry limit")
	app.start_level(0)
	app.set_process(false)
	app.board.set_process(false)
	app._on_direction(Vector2i.RIGHT)
	check(app.board.mouth_animation == "opening", "Food-directed step starts mouth anticipation")
	app._process(0.08)
	app.board._process(0.08)
	check(app.board.state.fruit.size()==1 and app.board.mouth_openness > 0.5, "Food stays visible while mouth opens before contact")
	app._process(0.041)
	check(app.board.state.fruit.is_empty() and app.board.mouth_animation == "swallow", "Contact removes world food and starts swallow")
	app._on_direction(Vector2i.ZERO)
	app._process(0.06)
	app.board._process(0.18)
	app.board._process(0.23)
	check(app.board.mouth_animation == "idle" and app.board.mouth_openness == 0, "Swallow and chew settle closed mouth")
	print("RESPONSIVENESS checks=",checks," failures=",failures)
	app.queue_free()
	quit(0 if failures == 0 else 1)
func render_head() -> Vector2:
	return Vector2(app.board.body_override[0]) if not app.board.body_override.is_empty() else Vector2(app.board.state.body[0])
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func fresh() -> void:
	app.start_level(app.levels.size()-1)
	app.set_process(false)
