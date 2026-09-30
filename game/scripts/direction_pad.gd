extends Control
## Four discrete gamepad keys. The gameplay controller owns repeat timing.
signal direction_changed(direction: Vector2i)

const UiSkin = preload("res://scripts/ui_skin.gd")
const INK := Color("4d2543")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const KEY_NAMES := ["Up", "Right", "Down", "Left"]
const ARROWS := ["▲", "▶", "▼", "◀"]

var direction := Vector2i.ZERO
var touch_id := -1
var mouse_held := false
var buttons: Dictionary = {}
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			reset()
		_update_visuals()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(DIRECTIONS.size()):
		var button := Button.new()
		button.name = KEY_NAMES[index]
		button.text = ARROWS[index]
		button.tooltip_text = ["上", "右", "下", "左"][index]
		# Raw touch/mouse has one owner; GUI emulation must not press a second time.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_disabled_color", Color("a99b92"))
		button.add_theme_color_override("font_shadow_color", Color("fff9e6"))
		button.add_theme_constant_override("shadow_offset_y", 1)
		button.add_theme_stylebox_override("normal", UiSkin.dpad_key())
		button.add_theme_stylebox_override("hover", UiSkin.dpad_key())
		button.add_theme_stylebox_override("pressed", UiSkin.dpad_key(true))
		button.add_theme_stylebox_override("hover_pressed", UiSkin.dpad_key(true))
		button.add_theme_stylebox_override("disabled", UiSkin.dpad_key(false, true))
		buttons[DIRECTIONS[index]] = button
		add_child(button)
	_layout_keys()
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_keys()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset()
	elif what == NOTIFICATION_EXIT_TREE:
		reset()

func _layout_keys() -> void:
	var extent := minf(size.x, size.y)
	var cell := extent / 3.0
	var key_size := Vector2.ONE * cell * 0.94
	var center := size * 0.5
	for key_direction in buttons:
		var button: Button = buttons[key_direction]
		# Keep the label plus skin padding inside narrow portrait keys.
		button.add_theme_font_size_override("font_size", clampi(roundi(extent * 0.12), 20, 24))
		button.position = center + Vector2(key_direction) * cell - key_size * 0.5
		button.size = key_size

func button_center(key_direction: Vector2i) -> Vector2:
	if buttons.has(key_direction):
		return (buttons[key_direction] as Button).get_global_rect().get_center()
	return get_global_rect().get_center()

func reset() -> void:
	touch_id = -1
	mouse_held = false
	_set_direction(Vector2i.ZERO)

func _set_direction(value: Vector2i) -> void:
	if value == direction:
		return
	direction = value
	_update_visuals()
	direction_changed.emit(value)

func _update_visuals() -> void:
	for key_direction in buttons:
		var button: Button = buttons[key_direction]
		button.disabled = not enabled
		button.set_pressed_no_signal(enabled and direction == key_direction)

func _hit_key(point: Vector2) -> Vector2i:
	for key_direction in buttons:
		if (buttons[key_direction] as Button).get_global_rect().has_point(point):
			return key_direction
	return Vector2i.ZERO

func _move_owner(point: Vector2) -> void:
	if not get_global_rect().has_point(point):
		reset()
	else:
		_set_direction(_hit_key(point))

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1 and not mouse_held:
			var hit := _hit_key(event.position)
			if hit != Vector2i.ZERO:
				touch_id = event.index
				_set_direction(hit)
		elif not event.pressed and event.index == touch_id:
			reset()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_move_owner(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and touch_id == -1 and not mouse_held:
			var hit := _hit_key(event.position)
			if hit != Vector2i.ZERO:
				mouse_held = true
				_set_direction(hit)
		elif not event.pressed and mouse_held:
			reset()
	elif event is InputEventMouseMotion and mouse_held:
		_move_owner(event.position)
