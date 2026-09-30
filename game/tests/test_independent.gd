extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("QA FAIL: " + label)

func points(raw: Array) -> Array[Vector2i]:
	var converted: Array[Vector2i] = []
	for p in raw:
		converted.append(Vector2i(p[0], p[1]))
	return converted

func fixture(body: Array, ground: Array, fruit: Array = [], spikes: Array = [], gate := Vector2i(7, 1)) -> Dictionary:
	return {"id": 999, "width": 8, "height": 8, "body": points(body), "terrain": points(ground), "fruit": points(fruit), "hazards": points(spikes), "exit": gate}

func same(a: Dictionary, b: Dictionary) -> bool:
	return a.body == b.body and a.fruit == b.fruit and a.status == b.status and a.moves == b.moves and a.get("growth_pending",0) == b.get("growth_pending",0)

func _initialize() -> void:
	var floor_cells := []
	for x in range(8):
		floor_cells.append([x, 5])
	var level := fixture([[2, 4], [1, 4], [0, 4]], floor_cells, [[3, 4]], [], Vector2i(5, 4))
	var initial: Dictionary = Rules.initial_state(level)
	var saved: Dictionary = initial.duplicate(true)
	for direction in [Vector2i.LEFT, Vector2i.DOWN, Vector2i.ZERO, Vector2i(1, 1), Vector2i(2, 0)]:
		var bad: Dictionary = Rules.step(level, initial, direction)
		check(not bad.valid and same(bad.state, saved), "invalid/reverse/wall preserves state " + str(direction))
		check(bad.frames.is_empty(), "invalid has no animation " + str(direction))
	var grow: Dictionary = Rules.step(level, initial, Vector2i.RIGHT)
	check(grow.valid and grow.ate and grow.state.body == points([[3,4],[2,4],[1,4],[0,4]]), "one fruit adds exactly one retained tail")
	check(grow.state.fruit.is_empty() and grow.state.moves == 1, "growth consumes one fruit and counts one action")
	check(same(initial, saved), "step does not mutate caller snapshot")
	grow.state.body[0] = Vector2i(6, 6)
	check(same(initial, saved), "returned body does not alias caller")
	check(grow.frames[0].body[0] == Vector2i(3,4), "frame body does not alias returned body")
	var fresh: Dictionary = Rules.initial_state(level)
	fresh.fruit.clear()
	check(level.fruit.size() == 1, "initial state does not alias level fruit")

	# Old-tail exception is a bent body, not a forbidden 180-degree reverse.
	var loop := fixture([[2,3],[2,2],[1,2],[1,3]], [[1,4],[2,4]])
	var tail: Dictionary = Rules.step(loop, Rules.initial_state(loop), Vector2i.LEFT)
	check(tail.valid and tail.state.body == points([[1,3],[2,3],[2,2],[1,2]]), "vacated old tail is enterable")
	var overlapped: Dictionary = Rules.initial_state(loop)
	overlapped.fruit = points([[1,3]]) # Reachable kind of runtime overlap after a fall, not a valid initial map.
	var blocked_tail: Dictionary = Rules.step(loop, overlapped, Vector2i.LEFT)
	check(not blocked_tail.valid and same(blocked_tail.state, overlapped), "growth preserves old tail and rejects occupied target")
	var two := fixture([[2,4],[1,4]], floor_cells)
	check(not Rules.step(two, Rules.initial_state(two), Vector2i.LEFT).valid, "two-cell old tail still cannot reverse")

	var bridge := fixture([[4,3],[3,3],[2,3],[1,3]], [[2,4]])
	var held: Dictionary = Rules.step(bridge, Rules.initial_state(bridge), Vector2i.RIGHT)
	check(held.fell == 0 and held.state.body[-1] == Vector2i(2,3), "tail alone supports whole body")
	var released: Dictionary = Rules.step(bridge, held.state, Vector2i.RIGHT)
	check(released.state.status == "lost" and released.fell > 0, "leaving final external support falls through bottom")

	var falling := fixture([[2,2],[1,2],[0,2]], [[0,3],[3,6]], [[3,3],[3,5]], [], Vector2i(7,1))
	var fall: Dictionary = Rules.step(falling, Rules.initial_state(falling), Vector2i.RIGHT)
	check(fall.fell == 3 and fall.state.body[0] == Vector2i(3,5), "gravity falls whole body to actual terrain")
	check(fall.state.fruit.is_empty() and fall.state.body.size() == 3 and fall.state.growth_pending == 2 and fall.ate, "fall passing and landing on fruit eats twice without reshaping the rigid body")
	check(fall.frames.size() == 4, "animation includes active step and each single-cell fall")
	check(fall.frames[0].body[0] == Vector2i(3,2) and fall.frames[1].body[0] == Vector2i(3,3), "intermediate frames preserve distinct positions")
	var caller: Dictionary = Rules.initial_state(falling)
	var before_fall: Dictionary = caller.duplicate(true)
	Rules.step(falling, caller, Vector2i.RIGHT)
	check(same(caller, before_fall), "multi-fall leaves full undo source intact")

	var side := fixture([[2,2],[1,2],[0,2]], [[0,3],[4,2],[4,3],[4,4],[3,6]])
	var side_result: Dictionary = Rules.step(side, Rules.initial_state(side), Vector2i.RIGHT)
	check(side_result.fell == 3, "side-wall contact does not support")
	var spike := fixture([[2,2],[1,2],[0,2]], [[0,3],[3,6]], [], [[2,4]])
	var hit: Dictionary = Rules.step(spike, Rules.initial_state(spike), Vector2i.RIGHT)
	check(hit.state.status == "lost" and hit.fell == 2 and hit.state.body[1] == Vector2i(2,4), "middle body spike hit stops fall at first contact")
	var exit_path := fixture([[2,2],[1,2],[0,2]], [[0,3],[3,6]], [], [], Vector2i(3,3))
	var passed: Dictionary = Rules.step(exit_path, Rules.initial_state(exit_path), Vector2i.RIGHT)
	check(passed.state.status == "playing" and passed.state.body[0] == Vector2i(3,5), "passing open exit in fall does not win or support")
	var exit_landing := exit_path.duplicate(true)
	exit_landing.exit = Vector2i(3,5)
	check(Rules.step(exit_landing, Rules.initial_state(exit_landing), Vector2i.RIGHT).state.status == "won", "settled head with no fruit wins")
	exit_landing.fruit = points([[6,1]])
	check(Rules.step(exit_landing, Rules.initial_state(exit_landing), Vector2i.RIGHT).state.status == "playing", "remaining fruit keeps exit locked")
	var tail_exit := fixture([[2,4],[1,4],[0,4]], floor_cells, [], [], Vector2i(1,4))
	check(Rules.step(tail_exit, Rules.initial_state(tail_exit), Vector2i.RIGHT).state.status == "playing", "tail in open exit does not win")
	var danger_exit := fixture([[2,2],[1,2],[0,2]], [[0,3],[3,5]], [], [[2,4]], Vector2i(3,4))
	check(Rules.step(danger_exit, Rules.initial_state(danger_exit), Vector2i.RIGHT).state.status == "lost", "body danger outranks head exit")
	var edge := fixture([[7,4],[6,4]], floor_cells)
	var outside: Dictionary = Rules.step(edge, Rules.initial_state(edge), Vector2i.RIGHT)
	check(outside.valid and outside.state.status == "lost" and outside.fell == 0, "leaving side boundary fails immediately")
	for terminal in ["won", "lost"]:
		var ended: Dictionary = saved.duplicate(true)
		ended.status = terminal
		var refused: Dictionary = Rules.step(level, ended, Vector2i.RIGHT)
		check(not refused.valid and same(refused.state, ended), "terminal blocks input " + terminal)

	# Validator uses invalid authoring data; runtime-overlap fixtures above deliberately bypass it.
	check(Rules.validate_level(level).is_empty(), "legal independent map validates")
	var invalid := level.duplicate(true)
	invalid.fruit.append(invalid.fruit[0])
	check(not Rules.validate_level(invalid).is_empty(), "duplicate food map rejected")
	invalid = level.duplicate(true)
	invalid.terrain.clear()
	check(not Rules.validate_level(invalid).is_empty(), "unsupported spawn rejected")
	invalid = level.duplicate(true)
	invalid.body[1] = Vector2i(6,1)
	check(not Rules.validate_level(invalid).is_empty(), "disconnected body rejected")

	var levels: Array = Rules.load_levels()
	check(levels.size() == 12, "exactly twelve shipped maps")
	var ids := {}
	var directions := {"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}
	for shipped in levels:
		check(not ids.has(shipped.id), "unique level ID " + str(shipped.id))
		ids[shipped.id] = true
		check(Rules.validate_level(shipped).is_empty(), "authoring constraints level " + str(shipped.id))
		var state: Dictionary = Rules.initial_state(shipped)
		var start: Dictionary = state.duplicate(true)
		var food_count: int = state.fruit.size()
		var length: int = state.body.size()
		var steps := 0
		for letter in shipped.solution:
			check(directions.has(letter), "solution alphabet level " + str(shipped.id))
			if not directions.has(letter):
				break
			var prior: Dictionary = state.duplicate(true)
			var transition: Dictionary = Rules.step(shipped, state, directions[letter])
			steps += 1
			check(transition.valid, "solution valid level %d step %d" % [shipped.id, steps])
			check(same(state, prior), "replay source immutable level %d step %d" % [shipped.id, steps])
			state = transition.state
			check(state.body.size() + state.growth_pending == length + food_count - state.fruit.size(), "earned length conservation level %d step %d" % [shipped.id, steps])
			check(state.status != "lost", "solution survives level %d step %d" % [shipped.id, steps])
		check(state.status == "won" and state.fruit.is_empty() and state.body[0] == shipped.exit, "complete win level " + str(shipped.id))
		check(same(Rules.initial_state(shipped), start), "replay leaves level data unchanged " + str(shipped.id))
		print("QA_LEVEL id=%d steps=%d status=%s" % [shipped.id, steps, state.status])
	print("INDEPENDENT_QA checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		print("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
