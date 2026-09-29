extends Control
## Original code-native EatAll art. All geometry is derived from board coordinates.
var level: Dictionary = {}
var state: Dictionary = {}
var body_override: Array = []
var mood: String = "normal"
var cell: float = 32.0
var origin: Vector2 = Vector2.ZERO
const INK = Color("4d2543")
const CORAL = Color("ff785e")
const CREAM = Color("fff0d1")

func set_data(new_level: Dictionary, new_state: Dictionary) -> void:
	level = new_level
	state = new_state
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _point(p: Variant) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell

func _box(rect: Rect2, color: Color, radius: float, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	draw_style_box(style, rect)

func _circle(p: Vector2, radius: float, color: Color) -> void:
	draw_circle(p, radius, color, true, -1.0, radius >= 1.0)

func _draw() -> void:
	if level.is_empty():
		return
	var columns := int(level.get("width", 9))
	var rows := int(level.get("height", 12))
	cell = minf((size.x - 16.0) / maxf(columns, 1), (size.y - 16.0) / maxf(rows, 1))
	if cell <= 0.0:
		return
	origin = (size - Vector2(columns, rows) * cell) * 0.5
	_box(Rect2(origin - Vector2.ONE * 5.0, Vector2(columns, rows) * cell + Vector2.ONE * 10.0), Color("fff5df"), 14)
	for y in range(rows):
		for x in range(columns):
			_circle(_point(Vector2i(x, y)), maxf(0.7, cell * 0.019), Color("e6ddc5"))
	for tile in level.get("terrain", []):
		_waffle(_point(tile))
	if level.has("exit"):
		_exit(_point(level["exit"]), state.get("fruit", level.get("fruit", [])).is_empty())
	for spike in level.get("hazards", []):
		_spikes(_point(spike))
	var snake: Array = body_override if not body_override.is_empty() else state.get("body", level.get("body", []))
	_body(snake)
	# Fruit is not terrain. Keep its complete silhouette visible even during a fall.
	for food in state.get("fruit", level.get("fruit", [])):
		_food(_point(food))

func _waffle(p: Vector2) -> void:
	var r := Rect2(p - Vector2.ONE * cell * 0.49, Vector2.ONE * cell * 0.98)
	_box(r, Color("ac673f"), cell * 0.10)
	_box(Rect2(r.position, Vector2(r.size.x, r.size.y - cell * 0.10)), Color("efb16a"), cell * 0.10)
	draw_line(r.position + Vector2(cell * 0.12, cell * 0.10), r.position + Vector2(cell * 0.86, cell * 0.10), Color("ffe0a1"), maxf(1, cell * 0.065), true)
	for yy in range(2):
		for xx in range(2):
			var inset := p + Vector2(-0.31 + xx * 0.35, -0.26 + yy * 0.35) * cell
			_box(Rect2(inset, Vector2.ONE * cell * 0.25), Color("cf8b51"), cell * 0.045)
			draw_line(inset + Vector2(0, cell * 0.25), inset + Vector2.ONE * cell * 0.25, Color("f8c880"), maxf(1, cell * 0.035), true)

func _food(p: Vector2) -> void:
	_circle(p + Vector2(0, cell * 0.07), cell * 0.25, Color(0.30, 0.15, 0.26, 0.12))
	_box(Rect2(p - Vector2.ONE * cell * 0.24, Vector2.ONE * cell * 0.48), Color("fffdf2"), cell * 0.10, Color("77516a"), maxi(1, int(cell * 0.035)))
	draw_line(p + Vector2(-0.11, -0.12) * cell, p + Vector2(0.08, -0.12) * cell, Color.WHITE, maxf(2, cell * 0.045), true)
	draw_line(p + Vector2(-0.07, 0.08) * cell, p + Vector2(0.04, 0.12) * cell, Color("e5959a"), maxf(2, cell * 0.07), true)
	_circle(p + Vector2(0.11, -0.02) * cell, cell * 0.025, Color("eccbad"))

func _spikes(p: Vector2) -> void:
	_box(Rect2(p + Vector2(-0.46, 0.30) * cell, Vector2(0.92, 0.16) * cell), INK, cell * 0.04)
	for i in range(3):
		var x := -0.43 + float(i) * 0.30
		var poly := PackedVector2Array([p + Vector2(x, 0.33) * cell, p + Vector2(x + 0.14, -0.34) * cell, p + Vector2(x + 0.28, 0.33) * cell])
		draw_colored_polygon(poly, Color("795777"))
		draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2]]), INK, maxf(1.5, cell * 0.04), true)
		draw_line(poly[1] + Vector2(0, cell * 0.13), poly[1] + Vector2(cell * 0.055, cell * 0.30), Color("bd9abd"), maxf(1, cell * 0.035), true)

func _exit(p: Vector2, opened: bool) -> void:
	if opened:
		_circle(p, cell * 0.47, Color(0.47, 0.73, 0.48, 0.18))
		draw_arc(p + Vector2(0, -0.11) * cell, cell * 0.30, PI, TAU, 20, INK, maxf(2, cell * 0.07), true)
		_box(Rect2(p + Vector2(-0.32, -0.16) * cell, Vector2(0.64, 0.28) * cell), Color("694651"), cell * 0.06)
	else:
		_box(Rect2(p + Vector2(-0.39, -0.12) * cell, Vector2(0.78, 0.16) * cell), Color("b87d4f"), cell * 0.04, INK, 1)
	_box(Rect2(p + Vector2(-0.36, 0.01) * cell, Vector2(0.72, 0.36) * cell), Color("d5a065"), cell * 0.07, INK, maxi(1, int(cell * 0.035)))
	for i in range(3):
		var x := -0.24 + i * 0.23
		draw_line(p + Vector2(x, 0.05) * cell, p + Vector2(x, 0.32) * cell, Color("b27a50"), maxf(1, cell * 0.035), true)
	draw_line(p + Vector2(-0.3, 0.19) * cell, p + Vector2(0.3, 0.19) * cell, Color("f2c58c"), maxf(1, cell * 0.035), true)
	if opened:
		var arrow := PackedVector2Array([p + Vector2(-0.08, -0.34) * cell, p + Vector2(0.08, -0.34) * cell, p + Vector2(0.08, -0.22) * cell, p + Vector2(0.17, -0.22) * cell, p + Vector2(0, -0.07) * cell, p + Vector2(-0.17, -0.22) * cell, p + Vector2(-0.08, -0.22) * cell])
		draw_colored_polygon(arrow, CREAM)
	else:
		draw_arc(p + Vector2(0, 0.04) * cell, cell * 0.08, PI, TAU, 12, INK, maxf(2, cell * 0.04), true)
		_box(Rect2(p + Vector2(-0.10, 0.03) * cell, Vector2(0.20, 0.17) * cell), CREAM, cell * 0.03, INK, 1)

func _body(snake: Array) -> void:
	if snake.is_empty():
		return
	var points := PackedVector2Array()
	for part in snake:
		points.append(_point(part))
	# Rounded orthogonal strokes preserve continuous joins without separate sprite seams.
	for i in range(points.size() - 1, 0, -1):
		var width := cell * (0.40 if i == points.size() - 1 else 0.69)
		draw_line(points[i], points[i - 1], INK, width + cell * 0.07, true)
		_circle(points[i], width * 0.5 + cell * 0.035, INK)
	for i in range(points.size() - 1, 0, -1):
		var width := cell * (0.40 if i == points.size() - 1 else 0.69)
		draw_line(points[i], points[i - 1], CORAL, width, true)
		_circle(points[i], width * 0.5, CORAL)
		if i < points.size() - 1:
			draw_line(points[i] + Vector2(-0.11, 0.12) * cell, points[i] + Vector2(0.10, 0.12) * cell, CREAM, cell * 0.14, true)
			_circle(points[i] + Vector2(-0.12, -0.13) * cell, cell * 0.046, Color("ffad87"))
	var direction := Vector2.RIGHT
	if points.size() > 1:
		direction = (points[0] - points[1]).normalized()
	_head(points[0], direction.angle())

func _head(p: Vector2, angle: float) -> void:
	# Pixel geometry keeps anti-alias feather width independent of the board scale.
	if absf(angle) > 2.8:
		draw_set_transform(p, 0.0, Vector2(-1.0, 1.0))
	else:
		draw_set_transform(p, angle, Vector2.ONE)
	_circle(Vector2.ZERO, 0.43 * cell, INK)
	_circle(Vector2(0.005, -0.015) * cell, 0.395 * cell, CORAL)
	_circle(Vector2(0.21, 0.19) * cell, 0.18 * cell, Color("ffae8b"))
	# Two little purple eyebrow horns create a recognizable silhouette.
	var horn_a := PackedVector2Array([Vector2(-0.22, -0.32) * cell, Vector2(-0.19, -0.49) * cell, Vector2(-0.01, -0.37) * cell])
	var horn_b := PackedVector2Array([Vector2(0.05, -0.35) * cell, Vector2(0.18, -0.46) * cell, Vector2(0.23, -0.26) * cell])
	for horn in [horn_a, horn_b]:
		draw_colored_polygon(horn, INK)
		draw_polyline(PackedVector2Array([horn[0], horn[1], horn[2], horn[0]]), INK, 1.0, true)
	var lost: bool = state.get("status", "playing") == "lost" or mood == "surprised"
	for eye_y in [-0.18, 0.07]:
		var eye := Vector2(0.16, eye_y) * cell
		_circle(eye, 0.135 * cell, INK)
		_circle(eye, 0.107 * cell, CREAM)
		_circle(eye + Vector2(0.04, 0) * cell, (0.035 if lost else 0.049) * cell, INK)
		_circle(eye + Vector2(0.052, -0.019) * cell, 0.014 * cell, Color.WHITE)
	if lost:
		_circle(Vector2(0.20, 0.27) * cell, 0.07 * cell, INK)
	else:
		draw_arc(Vector2(0.10, 0.17) * cell, 0.16 * cell, 0.05, 1.8, 14, INK, maxf(1.0, 0.035 * cell), true)
		draw_line(Vector2(0.22, 0.20) * cell, Vector2(0.24, 0.25) * cell, CREAM, maxf(1.0, 0.055 * cell), true)
	draw_set_transform(Vector2.ZERO)
