extends Control
signal direction_changed(direction: Vector2i)
var direction := Vector2i.ZERO
var knob := Vector2.ZERO
var touch_id := -1
var mouse_held := false
var enabled := true
const INK := Color("4d2543")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	touch_id = -1
	mouse_held = false
	knob = Vector2.ZERO
	_set_direction(Vector2i.ZERO)
	queue_redraw()

func _set_direction(value: Vector2i) -> void:
	if value != direction:
		direction = value
		direction_changed.emit(value)

func _position_input(point: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.43
	var raw := (point - global_position - size * 0.5) / radius
	knob = raw.limit_length(0.62)
	if raw.length() < (0.22 if direction == Vector2i.ZERO else 0.16):
		_set_direction(Vector2i.ZERO)
	else:
		var ax := absf(raw.x)
		var ay := absf(raw.y)
		var next := direction
		if direction == Vector2i.ZERO:
			if absf(ax - ay) > 0.015:
				next = Vector2i(int(signf(raw.x)), 0) if ax > ay else Vector2i(0, int(signf(raw.y)))
		elif direction.x != 0:
			next = Vector2i(0, int(signf(raw.y))) if ay > ax * 1.428 else Vector2i(int(signf(raw.x)), 0)
		else:
			next = Vector2i(int(signf(raw.x)), 0) if ax > ay * 1.428 else Vector2i(0, int(signf(raw.y)))
		_set_direction(next)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	# Buttons use Godot's touch-to-mouse emulation; the stick owns raw touches.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1 and not mouse_held and get_global_rect().has_point(event.position):
			touch_id = event.index
			_position_input(event.position)
		elif not event.pressed and event.index == touch_id:
			reset()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_position_input(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and touch_id == -1 and get_global_rect().has_point(event.position):
			mouse_held = true
			_position_input(event.position)
		elif not event.pressed and mouse_held:
			reset()
	elif event is InputEventMouseMotion and mouse_held:
		_position_input(event.position)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.43
	draw_circle(c + Vector2(0, 5), r + 3, Color("d3b998"))
	draw_circle(c, r, Color("f5e5c9"))
	draw_arc(c, r, 0, TAU, 64, Color("b89682"), 2.5, true)
	draw_arc(c, r - 6, PI, TAU, 36, Color("fff9e8"), 3, true)
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var v := Vector2(d)
		var p := c + v * r * 0.76
		var cross := Vector2(-v.y, v.x)
		draw_colored_polygon(PackedVector2Array([p + v * 7, p - v * 5 + cross * 6, p - v * 5 - cross * 6]), INK if direction == d else Color("b99686"))
	var k := c + knob * r
	draw_circle(k + Vector2(0, 4), r * 0.32, Color("48283d"))
	draw_circle(k, r * 0.32, Color("784864"))
	draw_circle(k + Vector2(-3, -4), r * 0.25, Color("955c77"))
	draw_arc(k, r * 0.32, 0, TAU, 36, INK, 2, true)
