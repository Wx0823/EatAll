extends SceneTree
const Main = preload("res://scripts/main.gd")
const Progress = preload("res://scripts/progress.gd")
var checks := 0
var failures: Array[String] = []
var game: Control
var test_path := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("UI QA FAIL: " + label)

func touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * point
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(point: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = root.get_screen_transform() * point
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(button: Control) -> void:
	var p := button.get_global_rect().get_center()
	touch(p, true)
	touch(p, false)

func click(button: Control) -> void:
	var p := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = p
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func same(a: Dictionary, b: Dictionary) -> bool:
	return a.body == b.body and a.fruit == b.fruit and a.status == b.status and a.moves == b.moves

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_path = "user://qa/independent-%d.json" % OS.get_process_id()
	game = Main.new()
	game.qa_mode = true
	game.save_path = test_path
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	check(game.mode == "home", "application opens home")
	check(not quit_on_go_back, "Android back does not auto-quit SceneTree")
	check(game.save_path != "user://progress.json", "isolated save path")
	check(Input.emulate_mouse_from_touch, "project enables native touch-to-button mouse emulation")
	tap(game.content.get_node("Start"))
	await process_frame
	check(game.mode == "play" and game.level_index == 0, "native touch emulation taps Start and routes to first map")
	if game.mode != "play":
		quit(1)
		return
	var center: Vector2 = game.stick.get_global_rect().get_center()
	var start: Dictionary = game.state.duplicate(true)
	touch(center, true)
	check(game.state.moves == 0, "touch within dead zone does not move")
	touch(center, false)
	touch(center + Vector2(40, 40), true)
	check(game.state.moves == 0, "initial diagonal boundary does not choose direction")
	touch(center, false)
	touch(center + Vector2(45,0), true)
	check(game.state.moves == 1 and game.state.body.size() == 4, "native touch enters input chain and grows exactly once")
	check(game.stick.touch_id == 0 and not game.stick.mouse_held, "emulated mouse cannot recapture raw touch stick")
	touch(center + Vector2(0,-45), true, 1)
	check(game.stick.touch_id == 0 and game.held == Vector2i.RIGHT, "second finger cannot steal stick")
	touch(center, false, 1)
	touch(center, false)
	await create_timer(0.55).timeout
	check(game.state.moves == 1 and not game.busy, "release during animation prevents queued repeat")
	tap(game.content.get_node("Undo"))
	await process_frame
	check(same(game.state, start) and game.history.is_empty(), "actual undo button restores body fruit and history")
	touch(center + Vector2(-45,0), true)
	touch(center, false)
	check(same(game.state, start) and game.history.is_empty(), "invalid reverse adds no undo entry")
	game.try_move(Vector2i.RIGHT)
	check(game.busy, "move begins animated round")
	tap(game.content.get_node("Pause"))
	await process_frame
	check(game.paused and not game.busy and game.state.moves == 1, "pause settles animation without rolling back move")
	tap(game.overlay.get_node("Panel/Resume"))
	await process_frame
	check(not game.paused and game.held == Vector2i.ZERO, "resume clears held input")
	await create_timer(0.4).timeout
	check(game.state.moves == 1, "resume does not move spontaneously")
	tap(game.content.get_node("Restart"))
	await process_frame
	check(same(game.state, start) and game.history.is_empty(), "restart button restores initial snapshot")

	# Actual held touch progresses at the runtime repeat cadence and stops at terminal.
	center = game.stick.get_global_rect().get_center()
	touch(center + Vector2(45,0), true)
	await create_timer(1.25).timeout
	check(game.state.status == "won" and game.state.moves == 3 and game.held == Vector2i.ZERO, "held touch repeats then stops on win")
	touch(center, false)

	# A failing round is accepted, then one undo restores the full pre-fall state.
	game.start_level(1)
	game.skip_animations = true
	for d in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT]:
		game.try_move(d)
	var before_loss: Dictionary = game.state.duplicate(true)
	game.try_move(Vector2i.UP)
	check(game.state.status == "lost", "fixture reaches multi-cell fall failure through controller")
	game.undo()
	check(same(game.state, before_loss) and game.state.status == "playing", "failure undo restores entire round")

	game.start_level(0)
	for i in range(3):
		game.try_move(Vector2i.RIGHT)
	check(game.state.status == "won" and game.progress.completed.has(0), "win records completion")
	var loaded: Dictionary = Progress.load_data(test_path, 12)
	check(loaded.data.completed.has(0), "completion reads back from isolated disk save")
	game.show_levels()
	check(not game.content.get_node("Level1").disabled and game.content.get_node("Level2").disabled, "only next level unlocks")
	game.start_level(0)
	for i in range(3):
		game.try_move(Vector2i.RIGHT)
	check(game.progress.completed.count(0) == 1, "repeated completion remains idempotent")

	game.start_level(0)
	game.skip_animations = false
	center = game.stick.get_global_rect().get_center()
	touch(center + Vector2(45,0), true)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and game.held == Vector2i.ZERO and game.stick.touch_id == -1, "focus loss clears touch and pauses")
	game._close_overlay()
	await create_timer(0.4).timeout
	check(game.state.moves == 1, "focus recovery cannot replay held direction")

	# Replay all controller/UI transitions, separately from the direct rules test.
	game.skip_animations = true
	var directions := {"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
	for i in range(game.levels.size()):
		game.start_level(i)
		for letter in game.levels[i].solution:
			check(game.try_move(directions[letter]), "controller route accepted L%d" % (i+1))
		check(game.state.status == "won" and game.overlay.get_node_or_null("Panel/Continue") != null, "controller shows win panel L%d" % (i+1))
	check(game.progress.completed.size() == 12, "full chapter persists all completions")
	loaded = Progress.load_data(test_path, 12)
	check(loaded.data.completed.size() == 12, "full chapter reads back twelve completions")

	# Check actual control rectangles at the reported short-screen width, both handed layouts.
	game.start_level(0)
	game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(390, 700)
	for right_side in [false, true]:
		game.progress.left_handed = right_side
		game._layout()
		var stick_rect: Rect2 = game.stick.get_global_rect()
		var undo_rect: Rect2 = game.content.get_node("Undo").get_global_rect()
		var restart_rect: Rect2 = game.content.get_node("Restart").get_global_rect()
		check(not stick_rect.intersects(undo_rect) and not stick_rect.intersects(restart_rect), "short-screen controls do not overlap hand=" + str(right_side))
		check(game.get_global_rect().encloses(stick_rect) and game.get_global_rect().encloses(undo_rect), "short-screen controls stay within root hand=" + str(right_side))
		check(not game.board.get_global_rect().intersects(stick_rect), "short-screen board avoids thumb zone hand=" + str(right_side))

	# Save module failure/recovery checks use a separate QA file only.
	var data: Dictionary = Progress.defaults()
	data.completed = [0]
	var recovery_path := test_path + ".recovery"
	check(Progress.save_data(recovery_path, data), "save baseline for corruption case")
	data.completed = [0,1]
	check(Progress.save_data(recovery_path, data), "second save establishes backup")
	var file := FileAccess.open(recovery_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered: Dictionary = Progress.load_data(recovery_path, 12)
	check(recovered.recovered and recovered.data.completed == [0], "corrupt primary recovers previous valid backup")
	check(not Progress.save_data(recovery_path + "/child.json", data), "invalid parent path reports save failure")
	for base in [test_path, recovery_path]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = base + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("INDEPENDENT_UI_QA checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		print("FAIL " + failure)
	await create_timer(0.7).timeout # Let real audio callbacks drain after accelerated controller replay.
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
