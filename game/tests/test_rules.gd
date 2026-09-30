extends SceneTree
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
const DIRECTIONS = {"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func fixture(body: Array, terrain: Array, fruit: Array = [], target := Vector2i(6, 5), hazards: Array = []) -> Dictionary:
	return {"id": 99, "width": 8, "height": 9, "terrain": terrain, "body": body, "fruit": fruit, "exit": target, "hazards": hazards}

func _initialize() -> void:
	var levels := Rules.load_levels()
	check(levels.size() == 12, "12 levels loaded")
	for level in levels:
		check(Rules.validate_level(level).is_empty(), "level %s contract: %s" % [level.id, Rules.validate_level(level)])
		var state := Rules.initial_state(level)
		var steps := 0
		var fall := 0
		for letter in level.solution:
			var before := state.duplicate(true)
			var result := Rules.step(level, state, DIRECTIONS[letter])
			check(state == before, "step never mutates caller")
			check(result.valid, "level %s valid solution step %s" % [level.id, steps])
			check(not result.frames.is_empty(), "valid step includes animation frames")
			check(result.frames[-1] == result.state, "final frame equals committed state")
			state = result.state
			fall += result.fell
			steps += 1
		check(state.status == "won", "level %s solved" % level.id)
		check(state.fruit.is_empty(), "win requires all fruit")
		print("REPLAY EA-%02d: WON, moves=%d, fallen_cells=%d, solution=%s" % [level.id, steps, fall, level.solution])
	var one: Dictionary = levels[0]
	for candidate in [{"index":10,"path":"UURURRRDRUULLLLLDL"},{"index":11,"path":"RRRRDLLULDDLL"}]:
		var replay := Rules.initial_state(levels[candidate.index])
		var valid := true
		for letter in candidate.path:
			var transition := Rules.step(levels[candidate.index], replay, DIRECTIONS[letter])
			valid = valid and transition.valid and transition.state.status != "lost"
			replay = transition.state
		check(valid and replay.status == "won", "EA-R0.2 new falling-food route wins level %d" % (candidate.index+1))
	var start := Rules.initial_state(one)
	var reverse := Rules.step(one, start, Vector2i.LEFT)
	check(not reverse.valid and reverse.reason == "reverse" and reverse.state == start, "reverse is inert")
	var wall := Rules.step(one, start, Vector2i.DOWN)
	check(not wall.valid and wall.reason == "wall", "terrain blocks")
	check(not Rules.step(one, start, Vector2i(1, 1)).valid, "no diagonals")
	var grow := Rules.step(one, start, Vector2i.RIGHT)
	check(grow.ate and grow.state.body.size() == start.body.size() + 1, "fruit grows one")
	var saved := start.duplicate(true)
	grow.state.body[0] = Vector2i(99, 99)
	check(start == saved, "deep result isolation")
	var ring := fixture([Vector2i(2,3),Vector2i(2,4),Vector2i(1,4),Vector2i(1,3)], [Vector2i(1,5),Vector2i(2,5)])
	check(Rules.step(ring, Rules.initial_state(ring), Vector2i.LEFT).valid, "vacating tail permits entry")
	ring.fruit = [Vector2i(1,3)]
	check(not Rules.step(ring, Rules.initial_state(ring), Vector2i.LEFT).valid, "growth retains tail collision")
	var tail := fixture([Vector2i(3,4),Vector2i(2,4),Vector2i(1,4)], [Vector2i(2,5)])
	check(Rules.step(tail, Rules.initial_state(tail), Vector2i.RIGHT).fell == 0, "only tail supports whole body")
	var falling := fixture([Vector2i(2,2),Vector2i(1,2),Vector2i(0,2)], [Vector2i(0,3),Vector2i(1,7),Vector2i(2,7),Vector2i(3,7)], [Vector2i(3,4)])
	var drop := Rules.step(falling, Rules.initial_state(falling), Vector2i.RIGHT)
	check(drop.fell == 4 and drop.state.fruit.is_empty() and drop.ate and drop.state.growth_pending == 1, "falling head consumes crossed fruit and earns one segment")
	falling.hazards = [Vector2i(1,4)]
	drop = Rules.step(falling, Rules.initial_state(falling), Vector2i.RIGHT)
	check(drop.state.status == "lost" and drop.reason == "spike" and drop.fell == 2, "tail hits spike during fall")
	falling.hazards = []
	falling.fruit = []
	falling.exit = Vector2i(3,4)
	drop = Rules.step(falling, Rules.initial_state(falling), Vector2i.RIGHT)
	check(drop.state.status == "playing", "passing exit while falling does not win")
	falling.terrain = [Vector2i(0,3)]
	drop = Rules.step(falling, Rules.initial_state(falling), Vector2i.RIGHT)
	check(drop.state.status == "lost" and drop.reason == "boundary", "unsupported body falls out")
	check(not Rules.step(falling, drop.state, Vector2i.RIGHT).valid, "terminal state locked")
	print("RULES RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
