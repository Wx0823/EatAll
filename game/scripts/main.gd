extends Control

const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board_renderer.gd")
const Stick = preload("res://scripts/virtual_stick.gd")
const Progress = preload("res://scripts/progress.gd")
const Sounds = preload("res://scripts/sfx.gd")
const INK := Color("4d2543")
const CORAL := Color("f87961")
const CREAM := Color("fff3da")
const MINT := Color("dfe9d6")

var save_path := "user://progress.json"
var qa_mode := false
var skip_animations := false
var levels: Array = []
var level_index := 0
var state: Dictionary = {}
var history: Array[Dictionary] = []
var progress: Dictionary = {}
var mode := "home"
var paused := false
var busy := false
var save_failed := false
var content: Control
var overlay: Control
var board: Control
var stick: Control
var audio: Node
var counter: Label
var step_label: Label
var hint_label: Label
var undo_button: Button
var font: Font
var held := Vector2i.ZERO
var repeat_clock := 0.35
var repeat_blocked := false
var pending_turn := false
var animation_frames: Array = []
var animation_from: Dictionary = {}
var animation_time := 0.0
var animation_index := 0
var animation_duration := 0.12
var status_time := 0.0
var fail_reason := ""

func _ready() -> void:
	qa_mode = qa_mode or OS.get_cmdline_user_args().has("--qa")
	if qa_mode and save_path == "user://progress.json":
		save_path = "user://qa/ui-progress.json"
	var readable_font := FontVariation.new()
	readable_font.base_font = load("res://assets/NotoSansSC.ttf")
	readable_font.variation_opentype = {2003265652: 600.0} # OpenType 'wght' integer tag.
	font = readable_font
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 17
	self.theme = theme
	levels = Rules.load_levels()
	if levels.is_empty():
		push_error("No valid levels")
		return
	for level in levels:
		var errors: Array = Rules.validate_level(level)
		if not errors.is_empty():
			push_error("Level %s: %s" % [level.id, errors])
	var saved := Progress.load_data(save_path, levels.size())
	progress = saved.data
	save_failed = saved.recovered
	audio = Sounds.new()
	add_child(audio)
	audio.enabled = progress.sound
	content = Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	resized.connect(_layout)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_show_home()

func _style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 18, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	if shadow:
		s.shadow_color = Color(0.25, 0.12, 0.19, 0.14)
		s.shadow_offset = Vector2(0, 5)
		s.shadow_size = 0
	return s

func _label(parent: Node, text: String, font_size: int, color: Color = INK, center: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, fill: Color = CREAM, font_size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _style(fill, INK, 17, true))
	b.add_theme_stylebox_override("hover", _style(fill.lightened(0.06), INK, 17, true))
	b.add_theme_stylebox_override("pressed", _style(fill.darkened(0.08), INK, 17))
	b.add_theme_stylebox_override("disabled", _style(Color("e7e0d2"), Color("c9bcba"), 17))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("aea3a4"))
	b.add_theme_font_size_override("font_size", font_size)
	# Finish input dispatch before replacing any Control nodes in the tree.
	b.pressed.connect(func(): action.call_deferred())
	parent.add_child(b)
	return b

func _rect(node: Control, x: float, y: float, w: float, h: float) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _reset_input() -> void:
	held = Vector2i.ZERO
	pending_turn = false
	repeat_clock = 0.35
	repeat_blocked = false
	if is_instance_valid(stick):
		stick.reset()

func _close_overlay() -> void:
	_clear(overlay)
	paused = false
	if is_instance_valid(stick):
		stick.enabled = mode == "play" and state.get("status", "") == "playing"
	_reset_input()

func _show_home() -> void:
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "home"
	board = null
	stick = null
	var caption := _label(content, "小小点心 · 大大脑洞", 16, Color("87627a"), true)
	caption.name = "Caption"
	var title := _label(content, "吃吃吃", 57, INK, true)
	title.name = "Title"
	var subtitle := _label(content, "EAT ALL", 25, Color("e8745e"), true)
	subtitle.name = "Subtitle"
	var hero := Board.new()
	hero.name = "Hero"
	content.add_child(hero)
	var mock := {"width": 7, "height": 5, "terrain": [Vector2i(1,4),Vector2i(2,4),Vector2i(3,4),Vector2i(4,4),Vector2i(5,4)], "hazards": [], "fruit": [Vector2i(5,1)], "body": [Vector2i(2,1),Vector2i(2,2),Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]}
	hero.set_data(mock, {"body":mock.body, "fruit":mock.fruit, "status":"playing"})
	var line := _label(content, "吃点心，长身体。\n用小聪明，走出每一关。", 20, INK, true)
	line.name = "Tagline"
	var start := _button(content, "开始野餐   →" if progress.completed.is_empty() else "继续野餐   →", start_level.bind(_next_level()), CORAL, 22)
	start.name = "Start"
	var select := _button(content, "选择关卡", show_levels, CREAM)
	select.name = "Select"
	var settings := _button(content, "设置", _settings, MINT, 16)
	settings.name = "Settings"
	var foot := _label(content, "烘焙野餐  /  12 道小谜题", 13, Color("8b7980"), true)
	foot.name = "Footer"
	_layout()

func _next_level() -> int:
	for i in levels.size():
		if not progress.completed.has(i):
			return i
	return 0

func _unlocked() -> int:
	var last := 0
	for i in progress.completed:
		last = maxi(last, int(i) + 1)
	return mini(last, levels.size() - 1)

func show_levels() -> void:
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "select"
	board = null
	stick = null
	var back := _button(content, "←", _show_home)
	back.name = "Back"
	var title := _label(content, "烘焙野餐", 32, INK, true)
	title.name = "Title"
	var sub := _label(content, "%d / 12  已完成" % progress.completed.size(), 17, Color("93707b"), true)
	sub.name = "Subtitle"
	for i in levels.size():
		var done: bool = progress.completed.has(i)
		var b := _button(content, "%02d%s" % [i+1, "  ✓" if done else ""], start_level.bind(i), Color("dce7c9") if done else CREAM, 25)
		b.name = "Level%d" % i
		b.disabled = i > _unlocked()
		b.tooltip_text = levels[i].title if not b.disabled else "完成前一关解锁"
	var note := _label(content, "慢慢想，放心试。每一步都能撤销。", 15, Color("826d78"), true)
	note.name = "Footer"
	_layout()

func start_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	level_index = index
	mode = "play"
	state = Rules.initial_state(levels[index])
	history.clear()
	fail_reason = ""
	var tag := _label(content, "烘焙野餐    /    %02d" % (index + 1), 14, Color("95717e"))
	tag.name = "Tag"
	var title := _label(content, levels[index].title, 28)
	title.name = "Title"
	var pause := _button(content, "Ⅱ", pause_game, CREAM, 24)
	pause.name = "Pause"
	counter = _label(content, "", 19, INK, true)
	counter.name = "Counter"
	step_label = _label(content, "", 14, Color("93707b"), true)
	step_label.name = "Moves"
	board = Board.new()
	board.name = "Board"
	board.clip_contents = true
	content.add_child(board)
	board.set_data(levels[index], state)
	hint_label = _label(content, levels[index].hint, 16, Color("826570"), true)
	hint_label.name = "Hint"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stick = Stick.new()
	stick.name = "Stick"
	content.add_child(stick)
	stick.direction_changed.connect(_on_direction)
	undo_button = _button(content, "↶  撤销", undo, CREAM, 18)
	undo_button.name = "Undo"
	var restart := _button(content, "重开", restart_level, Color("e6eddc"), 16)
	restart.name = "Restart"
	var tip := _label(content, "拨动走一格 · 按住连续走", 12, Color("947d87"), true)
	tip.name = "ControlTip"
	_update_hud()
	_layout()

func _layout() -> void:
	queue_redraw()
	if not is_instance_valid(content):
		return
	var w := size.x
	var h := size.y
	var top := 24.0
	var bottom := 20.0
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.y > 0:
			top = maxf(20.0, safe.position.y * h / screen.y + 12)
			bottom = maxf(16.0, (screen.y - safe.end.y) * h / screen.y + 8)
	if mode == "home":
		_rect(content.get_node("Caption"), 20, top+5, w-40, 27)
		_rect(content.get_node("Title"), 20, top+35, w-40, 86)
		_rect(content.get_node("Subtitle"), 20, top+119, w-40, 39)
		_rect(content.get_node("Hero"), 42, top+161, w-84, maxf(160, h-top-bottom-461))
		_rect(content.get_node("Tagline"), 20, h-bottom-274, w-40, 70)
		_rect(content.get_node("Start"), 54, h-bottom-191, w-108, 62)
		_rect(content.get_node("Select"), 54, h-bottom-113, (w-124)*0.65, 52)
		_rect(content.get_node("Settings"), 70+(w-124)*0.65, h-bottom-113, (w-124)*0.35, 52)
		_rect(content.get_node("Footer"), 20, h-bottom-40, w-40, 25)
	elif mode == "select":
		_rect(content.get_node("Back"), 22, top, 52, 48)
		_rect(content.get_node("Title"), 84, top+12, w-168, 48)
		_rect(content.get_node("Subtitle"), 30, top+71, w-60, 32)
		var bw := (w-88)/3.0
		var bh := minf(93, (h-top-bottom-228)/4.0)
		for i in levels.size():
			_rect(content.get_node("Level%d" % i), 28 + (i%3)*(bw+16), top+132+(i/3)*(bh+18), bw, bh)
		_rect(content.get_node("Footer"), 12, h-bottom-54, w-24, 40)
	elif mode == "play" and is_instance_valid(board):
		_rect(content.get_node("Tag"), 26, top, w-104, 24)
		_rect(content.get_node("Title"), 26, top+29, w-111, 48)
		_rect(content.get_node("Pause"), w-77, top+12, 52, 49)
		_rect(counter, 27, top+93, w*0.60, 31)
		_rect(step_label, w*0.68, top+93, w*0.25, 31)
		_rect(board, 19, top+143, w-38, maxf(170, h-top-bottom-376))
		_rect(hint_label, 26, h-bottom-226, w-52, 58)
		var control_w := minf(180.0, (w-70.0)*0.5)
		var action_w := minf(192.0, (w-70.0)*0.5)
		var stick_x := 22.0 if not progress.left_handed else w-22-control_w
		var actions_x := w-26-action_w if not progress.left_handed else 26.0
		_rect(stick, stick_x, h-bottom-176, control_w, 160)
		_rect(undo_button, actions_x, h-bottom-156, action_w, 58)
		_rect(content.get_node("Restart"), actions_x, h-bottom-84, action_w, 48)
		_rect(content.get_node("ControlTip"), stick_x-5, h-bottom-20, control_w+10, 23)
	if overlay.get_child_count() > 0:
		var panel: Control = overlay.get_node_or_null("Panel")
		if panel:
			panel.position = Vector2((w-panel.size.x)*0.5, maxf(top+10, (h-panel.size.y)*0.5))

func _update_hud() -> void:
	if not is_instance_valid(counter) or mode != "play":
		return
	var total: int = levels[level_index].fruit.size()
	counter.text = "点心  %d / %d%s" % [total-state.fruit.size(), total, "  ·  出口已打开" if state.fruit.is_empty() else ""]
	counter.add_theme_font_size_override("font_size", 16 if state.fruit.is_empty() else 19)
	step_label.text = "%d 步" % state.moves
	undo_button.disabled = history.is_empty()

func _on_direction(d: Vector2i) -> void:
	held = d
	repeat_clock = 0.35
	repeat_blocked = false
	pending_turn = false
	if d == Vector2i.ZERO:
		return
	if busy:
		pending_turn = true
	elif mode == "play" and not paused:
		try_move(d)

func try_move(d: Vector2i) -> bool:
	if mode != "play" or paused or busy or state.get("status", "") != "playing":
		return false
	var result: Dictionary = Rules.step(levels[level_index], state, d)
	if not result.valid:
		repeat_blocked = true
		hint_label.text = "转个方向试试，不能直接掉头。" if result.reason == "reverse" else "这里被挡住啦，换条路试试。"
		status_time = 1.2
		return false
	history.append(state.duplicate(true))
	animation_from = state.duplicate(true)
	state = result.state
	fail_reason = result.reason
	animation_frames = result.frames
	animation_index = 0
	animation_time = 0.0
	busy = true
	audio.play("eat" if result.ate else "move")
	_update_hud()
	if skip_animations:
		_finish_animation()
	return true

func _process(delta: float) -> void:
	if mode != "play" or paused:
		return
	if status_time > 0:
		status_time -= delta
		if status_time <= 0 and state.status == "playing":
			hint_label.text = levels[level_index].hint
	if busy:
		animation_time += delta
		var duration := 0.13 if animation_index == 0 else 0.075
		var t := clampf(animation_time / duration, 0.0, 1.0)
		var current: Dictionary = animation_frames[animation_index]
		var positions: Array = []
		for i in current.body.size():
			var from: Vector2 = Vector2(animation_from.body[mini(i, animation_from.body.size()-1)])
			positions.append(from.lerp(Vector2(current.body[i]), smoothstep(0.0, 1.0, t)))
		board.body_override = positions
		board.set_data(levels[level_index], current)
		if t >= 1.0:
			animation_from = current
			animation_index += 1
			animation_time = 0.0
			if animation_index >= animation_frames.size():
				_finish_animation()
		return
	if state.get("status", "") == "playing" and held != Vector2i.ZERO and not repeat_blocked:
		if pending_turn:
			pending_turn = false
			try_move(held)
			repeat_clock = 0.35
		else:
			repeat_clock -= delta
			if repeat_clock <= 0:
				try_move(held)
				repeat_clock = 0.18

func _cancel_animation() -> void:
	busy = false
	animation_frames.clear()
	if is_instance_valid(board):
		board.body_override = []

func _finish_animation() -> void:
	_cancel_animation()
	if not is_instance_valid(board):
		return
	board.set_data(levels[level_index], state)
	board.mood = "sad" if state.status == "lost" else "normal"
	_update_hud()
	if state.status != "playing":
		_reset_input()
		stick.enabled = false
		if state.status == "won":
			if not progress.completed.has(level_index):
				progress.completed.append(level_index)
				progress.completed.sort()
			save_failed = not Progress.save_data(save_path, progress)
			audio.play("won")
			_end_panel(true)
		else:
			audio.play("lost")
			_end_panel(false)

func undo() -> void:
	if history.is_empty() or mode != "play":
		return
	_cancel_animation()
	_close_overlay()
	state = history.pop_back().duplicate(true)
	board.mood = "normal"
	board.set_data(levels[level_index], state)
	stick.enabled = true
	_reset_input()
	hint_label.text = "回到上一步，换个办法！"
	status_time = 1.2
	_update_hud()
	audio.play("undo")

func restart_level() -> void:
	start_level(level_index)
	audio.play("tap")

func _panel(title: String, subtitle: String, height: float = 322) -> Panel:
	_clear(overlay)
	_reset_input()
	if is_instance_valid(stick):
		stick.enabled = false
	var shade := ColorRect.new()
	shade.color = Color(0.20, 0.11, 0.17, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.size = Vector2(minf(size.x-48, 398), height)
	panel.add_theme_stylebox_override("panel", _style(CREAM, INK, 25, true))
	overlay.add_child(panel)
	var heading := _label(panel, title, 29, INK, true)
	_rect(heading, 12, 22, panel.size.x-24, 49)
	var sub := _label(panel, subtitle, 16, Color("8c6677"), true)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rect(sub, 22, 79, panel.size.x-44, 65)
	_layout()
	return panel

func _end_panel(won: bool) -> void:
	var final := level_index == levels.size()-1
	var title := "野餐圆满！" if won and final else ("吃得漂亮！" if won else "差一点点！")
	var subtitle := "12道小谜题，全部尝过啦。" if won and final else ("点心吃光，成功回到野餐篮。" if won else ("掉出棋盘啦，留住一个支点试试。" if fail_reason == "boundary" else "身体碰到尖刺了，撤销再试一次。"))
	if save_failed and won:
		subtitle += "\n进度暂未保存，可点重试保存。"
	var panel := _panel(title, subtitle, 370 if save_failed and won else 328)
	var action := show_levels if won and final else (start_level.bind(level_index+1) if won else undo)
	var primary := _button(panel, "返回关卡" if won and final else ("下一道点心  →" if won else "↶  撤销一步"), action, CORAL, 20)
	primary.name = "Continue"
	_rect(primary, 26, 162, panel.size.x-52, 57)
	var secondary := _button(panel, "再玩一次" if won else "重新开始", restart_level, CREAM, 17)
	_rect(secondary, 26, 233, (panel.size.x-66)*0.60, 48)
	var home := _button(panel, "选关", show_levels, MINT, 17)
	_rect(home, 40+(panel.size.x-66)*0.60, 233, (panel.size.x-66)*0.40, 48)
	if save_failed and won:
		var retry := _button(panel, "重试保存", _retry_save, CREAM, 14)
		_rect(retry, 26, 300, panel.size.x-52, 43)

func _retry_save() -> void:
	save_failed = not Progress.save_data(save_path, progress)
	_end_panel(true)

func pause_game() -> void:
	if mode != "play" or paused:
		return
	if busy:
		_finish_animation()
	if state.status != "playing":
		return
	paused = true
	var panel := _panel("歇一小口", "棋盘会等你，慢慢想。", 334)
	var resume := _button(panel, "继续游戏", _close_overlay, CORAL, 21)
	resume.name = "Resume"
	_rect(resume, 26, 150, panel.size.x-52, 58)
	var restart := _button(panel, "重新开始", restart_level, CREAM)
	_rect(restart, 26, 225, (panel.size.x-68)*0.6, 49)
	var levels_b := _button(panel, "选关", show_levels, MINT)
	_rect(levels_b, 42+(panel.size.x-68)*0.6, 225, (panel.size.x-68)*0.4, 49)

func _settings() -> void:
	var panel := _panel("小小设置", "放松一点，按自己的习惯来。", 371)
	var hand := _button(panel, "轮盘位置：%s" % ("右手" if progress.left_handed else "左手"), _toggle_hand, CREAM, 17)
	_rect(hand, 25, 145, panel.size.x-50, 51)
	var sound := _button(panel, "音效：%s" % ("开" if progress.sound else "关"), _toggle_sound, CREAM, 17)
	_rect(sound, 25, 211, panel.size.x-50, 51)
	var back := _button(panel, "完成", _close_overlay, CORAL)
	_rect(back, 25, 284, panel.size.x-50, 52)

func _toggle_hand() -> void:
	progress.left_handed = not progress.left_handed
	save_failed = not Progress.save_data(save_path, progress)
	_settings()

func _toggle_sound() -> void:
	progress.sound = not progress.sound
	audio.enabled = progress.sound
	save_failed = not Progress.save_data(save_path, progress)
	_settings()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if paused: _close_overlay()
				elif mode == "play": pause_game()
				else: _show_home()
			KEY_Z: undo()
			KEY_R:
				if mode == "play": restart_level()
	var dir := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W: dir = Vector2i.UP
		KEY_DOWN, KEY_S: dir = Vector2i.DOWN
		KEY_LEFT, KEY_A: dir = Vector2i.LEFT
		KEY_RIGHT, KEY_D: dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		_on_direction(dir if event.pressed else Vector2i.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_input()
		if mode == "play" and is_instance_valid(content):
			pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "play": pause_game()
		else: _show_home()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f8f1df"))
	draw_circle(Vector2(size.x*0.87, 150), 180, Color("e8eddc"))
	draw_circle(Vector2(-25, size.y*0.52), 135, Color("e8eddc"))
	draw_circle(Vector2(size.x+70, size.y+35), 225, Color("e1e8d0"))
	draw_circle(Vector2(-70, size.y+30), 210, Color("f4ddc8"))
	for i in 8:
		var p := Vector2(22 + i*69, size.y-8-(i%3)*11)
		draw_line(p, p-Vector2(4,21), Color("adc4a1"), 3, true)
		draw_circle(p-Vector2(4,24), 6, Color("c2d2b0"))
