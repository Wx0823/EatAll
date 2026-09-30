extends Control

const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board_renderer.gd")
const Stick = preload("res://scripts/virtual_stick.gd")
const Progress = preload("res://scripts/progress.gd")
const Sounds = preload("res://scripts/sfx.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const MEADOW = preload("res://assets/art-v2/meadow.png")
const HOME_MONSTER = preload("res://assets/art-v2/home-monster.png")
const INK := Color("4d2543")
const CORAL := Color("f87961")
const CREAM := Color("fff3da")
const MINT := Color("dfe9d6")
const MOVE_SECONDS := 0.16
const FALL_ACCELERATION := 160.0 # Grid cells / second²; one continuous fall.
const MAX_FRAME_CARRY := 0.08 # Long stalls never fast-forward extra grid actions.

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
var repeat_clock := MOVE_SECONDS
var repeat_blocked := false
var pending_turn := false
var animation_frames: Array = []
var animation_from: Dictionary = {}
var animation_time := 0.0
var animation_index := 0
var animation_ate := false
var animation_eat_fired := false
var animation_fall_started := false
var animation_continuous := false
var status_time := 0.0
var fail_reason := ""
var terminal_delay := 0.0

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
	if OS.is_debug_build() and FileAccess.file_exists("user://qa/frame-probe.enabled"):
		var probe := preload("res://scripts/frame_probe.gd").new()
		probe.game = self
		add_child(probe)

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
	b.add_theme_stylebox_override("normal", UiSkin.button(fill))
	b.add_theme_stylebox_override("hover", UiSkin.button(fill.lightened(0.05)))
	b.add_theme_stylebox_override("pressed", UiSkin.button(fill.darkened(0.07), true))
	b.add_theme_stylebox_override("disabled", UiSkin.button(Color("e7e0d2"), false, true))
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
	repeat_clock = MOVE_SECONDS
	repeat_blocked = false
	if is_instance_valid(stick):
		stick.reset()

func _close_overlay() -> void:
	_clear(overlay)
	paused = false
	if is_instance_valid(stick):
		stick.enabled = mode == "play" and state.get("status", "") == "playing"
	if is_instance_valid(board):
		board.set_process(true)
	_reset_input()

func _show_home() -> void:
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "home"
	board = null
	stick = null
	var caption := _label(content, "P I C N I C   M O N S T E R", 13, INK, true)
	caption.name = "Caption"
	var title := _label(content, "吃吃吃", 61, INK, true)
	title.add_theme_color_override("font_outline_color", Color("fff1ce"))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_shadow_color", Color(0.31,0.15,0.22,0.18))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.name = "Title"
	var subtitle := _label(content, "EAT ALL", 26, Color("d96b4c"), true)
	subtitle.add_theme_color_override("font_outline_color", Color("fff1ce"))
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.name = "Subtitle"
	var hero := TextureRect.new()
	hero.texture = HOME_MONSTER
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.name = "Hero"
	content.add_child(hero)
	var line := _label(content, "一口点心，一场小冒险。", 18, INK, true)
	line.add_theme_color_override("font_outline_color", Color("fff3da"))
	line.add_theme_constant_override("outline_size", 5)
	line.name = "Tagline"
	var start := _button(content, "开始野餐   →" if progress.completed.is_empty() else "继续野餐   →", start_level.bind(_next_level()), CORAL, 22)
	start.name = "Start"
	var select := _button(content, "选择关卡", show_levels, CREAM)
	select.name = "Select"
	var settings := _button(content, "设置", _settings, MINT, 16)
	settings.name = "Settings"
	var foot := _label(content, "烘焙野餐  ·  12 道小谜题", 13, INK, true)
	foot.add_theme_color_override("font_outline_color", CREAM)
	foot.add_theme_constant_override("outline_size", 4)
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
	var tag := _label(content, "烘焙野餐    /    %02d" % (index + 1), 12, Color("95717e"))
	tag.name = "Tag"
	var title := _label(content, levels[index].title, 24)
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
		_rect(content.get_node("Caption"), 20, top+20, w-40, 27)
		_rect(content.get_node("Title"), 20, top+56, w-40, 86)
		_rect(content.get_node("Subtitle"), 20, top+136, w-40, 39)
		_rect(content.get_node("Hero"), 18, top+184, w-36, maxf(168, h-top-bottom-434))
		_rect(content.get_node("Tagline"), 20, h-bottom-248, w-40, 42)
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
		_rect(content.get_node("Tag"), 26, top, w-104, 18)
		_rect(content.get_node("Title"), 26, top+19, w-111, 34)
		_rect(content.get_node("Pause"), w-74, top+4, 48, 46)
		_rect(counter, 27, top+60, w*0.64, 25)
		_rect(step_label, w*0.71, top+60, w*0.20, 25)
		_rect(board, 12, top+101, w-24, maxf(170, h-top-bottom-305))
		_rect(hint_label, 26, h-bottom-193, w-52, 39)
		var control_w := minf(160.0, (w-70.0)*0.5)
		var action_w := minf(192.0, (w-70.0)*0.5)
		var stick_x := 22.0 if not progress.left_handed else w-22-control_w
		var actions_x := w-26-action_w if not progress.left_handed else 26.0
		_rect(stick, stick_x, h-bottom-149, control_w, 134)
		_rect(undo_button, actions_x, h-bottom-134, action_w, 52)
		_rect(content.get_node("Restart"), actions_x, h-bottom-69, action_w, 43)
		_rect(content.get_node("ControlTip"), stick_x-6, h-bottom-16, control_w+12, 23)
	if overlay.get_child_count() > 0:
		var panel: Control = overlay.get_node_or_null("Panel")
		if panel:
			panel.position = Vector2((w-panel.size.x)*0.5, maxf(top+10, (h-panel.size.y)*0.5))

func _update_hud() -> void:
	if not is_instance_valid(counter) or mode != "play":
		return
	var total: int = levels[level_index].fruit.size()
	counter.text = "点心  %d / %d%s" % [total-state.fruit.size(), total, "  ·  出口已打开" if state.fruit.is_empty() else ""]
	counter.add_theme_font_size_override("font_size", 14 if state.fruit.is_empty() else 16)
	step_label.text = "%d 步" % state.moves
	undo_button.disabled = history.is_empty()

func _on_direction(d: Vector2i) -> void:
	held = d
	repeat_clock = MOVE_SECONDS
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
		board.react("blocked", d)
		audio.play("blocked")
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
	animation_ate = result.ate
	animation_eat_fired = false
	animation_fall_started = false
	animation_continuous = held != Vector2i.ZERO
	repeat_clock = MOVE_SECONDS
	busy = true
	board.motion_active = true
	board.facing_direction = d
	board.react("move", d)
	if animation_ate:
		board.anticipate_food(d, Vector2(animation_frames[0].body[0]))
	audio.play("move")
	_update_hud()
	if skip_animations:
		if animation_ate:
			board.react("eat", d)
		_finish_animation()
	return true

func _process(delta: float) -> void:
	if mode != "play" or paused:
		return
	if terminal_delay > 0:
		terminal_delay -= delta
		if terminal_delay <= 0:
			_end_panel(state.status == "won")
		return
	if status_time > 0:
		status_time -= delta
		if status_time <= 0 and state.status == "playing":
			hint_label.text = levels[level_index].hint
	# Repeat time is measured from the accepted input, including its animation.
	# Never replay missed ticks after a stall or a long gravity round.
	if held != Vector2i.ZERO:
		repeat_clock -= delta
	var carry := 0.0
	if busy:
		var round_duration := MOVE_SECONDS + sqrt(2.0 * (animation_frames.size()-1) / FALL_ACCELERATION)
		animation_time += delta
		_advance_animation()
		if busy:
			return
		if delta <= MAX_FRAME_CARRY:
			carry = clampf(animation_time - round_duration, 0.0, MAX_FRAME_CARRY)
	if state.get("status", "") == "playing" and held != Vector2i.ZERO and not repeat_blocked:
		var accepted := false
		if pending_turn:
			pending_turn = false
			accepted = try_move(held)
		elif repeat_clock <= 0:
			accepted = try_move(held)
		if accepted and busy and carry > 0:
			# Keep fractional frame time in the next visual step. Never execute a
			# second logical action here, even if an entire frame was missed.
			animation_time = carry
			repeat_clock -= carry
			_advance_animation()

func _advance_animation() -> void:
	var moved: Dictionary = animation_frames[0]
	var fall_rows := animation_frames.size() - 1
	var fall_seconds := sqrt(2.0 * fall_rows / FALL_ACCELERATION)
	var positions: Array = []
	if animation_time < MOVE_SECONDS:
		var t := clampf(animation_time / MOVE_SECONDS, 0.0, 1.0)
		# Held input has constant speed across cell boundaries. Programmatic
		# single steps use a short ease-out; releases never cancel an accepted step.
		var blend := t if animation_continuous else 1.0 - pow(1.0 - t, 2.0)
		for i in moved.body.size():
			var from := Vector2(animation_from.body[mini(i, animation_from.body.size()-1)])
			positions.append(from.lerp(Vector2(moved.body[i]), blend))
		board.set_data(levels[level_index], moved if t >= 0.75 else animation_from)
		if animation_ate and t >= 0.75 and not animation_eat_fired:
			animation_eat_fired = true
			board.react("eat", board.facing_direction)
			audio.play("eat")
	else:
		if animation_ate and not animation_eat_fired:
			animation_eat_fired = true
			board.react("eat", board.facing_direction)
			audio.play("eat")
		if fall_rows > 0:
			if not animation_fall_started:
				animation_fall_started = true
				board.react("fall")
			var elapsed := minf(animation_time - MOVE_SECONDS, fall_seconds)
			var drop := minf(fall_rows, 0.5 * FALL_ACCELERATION * elapsed * elapsed)
			animation_index = mini(int(drop), fall_rows)
			for part in moved.body:
				positions.append(Vector2(part) + Vector2(0, drop))
			board.set_data(levels[level_index], animation_frames[animation_index])
		if animation_time >= MOVE_SECONDS + fall_seconds:
			if fall_rows > 0 and state.status != "lost":
				board.body_override = []
				board.set_data(levels[level_index], state)
				board.react("land")
				audio.play("land")
			_finish_animation()
			return
	board.body_override = positions
	board.queue_redraw()

func _cancel_animation() -> void:
	busy = false
	terminal_delay = 0.0
	animation_frames.clear()
	if is_instance_valid(board):
		board.body_override = []
		board.motion_active = false

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
			board.react("won")
			if not progress.completed.has(level_index):
				progress.completed.append(level_index)
				progress.completed.sort()
			save_failed = not Progress.save_data(save_path, progress)
			audio.play("won")
			if skip_animations: _end_panel(true)
			else: terminal_delay = 0.42
		else:
			board.react("lost")
			audio.play("lost")
			if skip_animations: _end_panel(false)
			else: terminal_delay = 0.42

func undo() -> void:
	if history.is_empty() or mode != "play":
		return
	_cancel_animation()
	_close_overlay()
	state = history.pop_back().duplicate(true)
	board.mood = "normal"
	board.clear_reactions()
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
	board.set_process(false)
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
	var factor := maxf(size.x / MEADOW.get_width(), size.y / MEADOW.get_height())
	var bg_size := MEADOW.get_size() * factor
	draw_texture_rect(MEADOW, Rect2((size-bg_size)*0.5, bg_size), false)
	if mode == "play" or mode == "select":
		var header := _style(Color(1.0,0.957,0.843,0.94), Color("cfa47b"), 19, true)
		draw_style_box(header, Rect2(15, 14, size.x-30, 103 if mode == "play" else 119))
	if mode == "play":
		var tray := _style(Color(1.0,0.951,0.834,0.94), Color("d4b390"), 29, true)
		draw_style_box(tray, Rect2(9, size.y-180, size.x-18, 190))
		var hint := _style(Color(1.0,0.97,0.86,0.88), Color.TRANSPARENT, 13)
		draw_style_box(hint, Rect2(21, size.y-216, size.x-42, 42))
