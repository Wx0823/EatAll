extends RefCounted

static func _points(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for point in raw:
		out.append(Vector2i(int(point[0]), int(point[1])))
	return out

static func load_levels() -> Array:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	if not raw is Array:
		push_error("Invalid levels.json")
		return []
	var levels: Array = []
	for entry in raw:
		var level: Dictionary = entry.duplicate(true)
		for key in ["terrain", "hazards", "fruit", "body"]:
			level[key] = _points(level.get(key, []))
		level["exit"] = Vector2i(int(level.exit[0]), int(level.exit[1]))
		level["id"] = int(level.id)
		level["width"] = int(level.width)
		level["height"] = int(level.height)
		levels.append(level)
	return levels

static func initial_state(level: Dictionary) -> Dictionary:
	return {"body": level.body.duplicate(), "fruit": level.fruit.duplicate(), "status": "playing", "moves": 0}

static func _supported(level: Dictionary, body: Array) -> bool:
	for p in body:
		if level.terrain.has(p + Vector2i.DOWN):
			return true
	return false

static func _danger(level: Dictionary, body: Array) -> String:
	for p in body:
		if p.x < 0 or p.y < 0 or p.x >= level.width or p.y >= level.height:
			return "boundary"
		if level.hazards.has(p):
			return "spike"
	return ""

static func step(level: Dictionary, state: Dictionary, direction: Vector2i) -> Dictionary:
	var result := {"valid": false, "state": state.duplicate(true), "frames": [], "ate": false, "fell": 0, "reason": ""}
	if state.status != "playing":
		result.reason = "terminal"
		return result
	if abs(direction.x) + abs(direction.y) != 1:
		result.reason = "direction"
		return result
	var body: Array = state.body.duplicate()
	var target: Vector2i = body[0] + direction
	if body.size() > 1 and target == body[1]:
		result.reason = "reverse"
		return result
	var ate: bool = state.fruit.has(target)
	var occupied := body.duplicate()
	if not ate:
		occupied.pop_back()
	if level.terrain.has(target):
		result.reason = "wall"
		return result
	if occupied.has(target):
		result.reason = "body"
		return result
	var next: Dictionary = state.duplicate(true)
	body.push_front(target)
	if not ate:
		body.pop_back()
	next.body = body
	if ate:
		next.fruit.erase(target)
	next.moves += 1
	result.valid = true
	result.ate = ate
	var danger := _danger(level, body)
	if not danger.is_empty():
		next.status = "lost"
		result.reason = danger
	result.frames.append(next.duplicate(true))
	while next.status == "playing" and not _supported(level, body):
		for i in body.size():
			body[i] += Vector2i.DOWN
		next.body = body
		result.fell += 1
		danger = _danger(level, body)
		if not danger.is_empty():
			next.status = "lost"
			result.reason = danger
		result.frames.append(next.duplicate(true))
	if next.status == "playing" and next.fruit.is_empty() and next.body[0] == level.exit:
		next.status = "won"
	result.state = next
	result.frames[result.frames.size() - 1] = next.duplicate(true)
	return result

static func validate_level(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(level.get("width", 0)) < 1 or int(level.get("height", 0)) < 1:
		errors.append("Map dimensions must be positive")
	if level.get("body", []).size() < 2:
		errors.append("Body must contain at least two cells")
	if level.get("fruit", []).is_empty():
		errors.append("At least one fruit required")
	var occupied := {}
	for key in ["terrain", "hazards", "fruit", "body"]:
		var seen := {}
		for p in level.get(key, []):
			if p.x < 0 or p.y < 0 or p.x >= level.width or p.y >= level.height:
				errors.append(key + " is outside map")
			if seen.has(p):
				errors.append(key + " has duplicate cell")
			seen[p] = true
			if occupied.has(p):
				errors.append(key + " overlaps " + str(occupied[p]))
			occupied[p] = key
	var exit_cell: Vector2i = level.get("exit", Vector2i(-1, -1))
	if exit_cell.x < 0 or exit_cell.y < 0 or exit_cell.x >= level.width or exit_cell.y >= level.height:
		errors.append("Exit is outside map")
	if occupied.has(exit_cell):
		errors.append("Exit overlaps another initial object")
	for i in range(1, level.body.size()):
		var delta: Vector2i = level.body[i] - level.body[i - 1]
		if abs(delta.x) + abs(delta.y) != 1:
			errors.append("Body is disconnected")
	if not _supported(level, level.body):
		errors.append("Initial body is unsupported")
	return errors
