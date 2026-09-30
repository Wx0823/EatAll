extends Control

const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board_renderer.gd")
const Stick = preload("res://scripts/direction_pad.gd")
const Progress = preload("res://scripts/progress.gd")
const Localization = preload("res://scripts/localization.gd")
const Sounds = preload("res://scripts/sfx.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const MEADOW = preload("res://assets/art-v2/meadow.png")
const HOME_MONSTER = preload("res://assets/art-v2/home-monster.png")
const UNDO_ICON = preload("res://assets/ui-v5/undo.svg")
const FOOD_ATLAS = preload("res://assets/art-v2/gameplay-atlas.png")
const Auth = preload("res://scripts/auth_controller.gd")
const IdleMonster = preload("res://scripts/idle_monster.gd")
const GoogleButton = preload("res://scripts/google_button.gd")
const INK := Color("4d2543")
const CORAL := Color("f87961")
const CREAM := Color("fff3da")
const MINT := Color("dfe9d6")
const MOVE_SECONDS := 0.16
const FALL_ACCELERATION := 160.0 # Grid cells / second²; one continuous fall.
const MAX_FRAME_CARRY := 0.08 # Long stalls never fast-forward extra grid actions.

var save_path := "user://progress.json"
var auth_path := ""
var auth: Node
var auth_error_code := ""
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
var animation_food_events: Array = []
var animation_food_cursor := 0
var animation_food_prepared := false
var animation_fall_started := false
var animation_continuous := false
var fail_reason := ""
var terminal_delay := 0.0
var layout_top := 24.0
var layout_bottom := 20.0
var language := "zh_CN"
var overlay_kind := ""

func _ready() -> void:
	qa_mode = qa_mode or OS.get_cmdline_user_args().has("--qa")
	if qa_mode and save_path == "user://progress.json":
		save_path = "user://qa/ui-progress.json"
	var readable_font := FontVariation.new()
	readable_font.base_font = load("res://assets/NotoSansSC.ttf")
	readable_font.variation_opentype = {2003265652: 700.0} # OpenType 'wght' integer tag.
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
	language = Localization.normalize_locale(progress.language if not progress.language.is_empty() else OS.get_locale())
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
	auth = Auth.new()
	auth.save_path = auth_path if not auth_path.is_empty() else (save_path.get_basename()+"-login.json" if qa_mode else "user://login.json")
	auth.authenticated.connect(_show_home)
	auth.signed_out.connect(_show_login)
	auth.failed.connect(_auth_failed)
	auth.busy_changed.connect(_auth_busy_changed)
	add_child(auth)
	_show_home()
	if OS.is_debug_build() and FileAccess.file_exists("user://qa/frame-probe.enabled"):
		var probe := preload("res://scripts/frame_probe.gd").new()
		probe.game = self
		add_child(probe)

func _label(parent: Node, text: String, font_size: int, color: Color = INK, center: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("base_font_size", font_size)
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
	var icon_key := text in ["Ⅱ", "←"]
	b.add_theme_stylebox_override("normal", UiSkin.dpad_key() if icon_key else UiSkin.button(fill))
	b.add_theme_stylebox_override("hover", UiSkin.dpad_key() if icon_key else UiSkin.button(fill.lightened(0.05)))
	b.add_theme_stylebox_override("pressed", UiSkin.dpad_key(true) if icon_key else UiSkin.button(fill.darkened(0.07), true))
	b.add_theme_stylebox_override("disabled", UiSkin.dpad_key(false, true) if icon_key else UiSkin.button(Color("e7e0d2"), false, true))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("8b7c75"))
	b.add_theme_color_override("font_shadow_color", Color(1.0, 0.97, 0.85, 0.65))
	b.add_theme_constant_override("shadow_offset_y", -1)
	b.add_theme_font_size_override("font_size", font_size)
	b.set_meta("base_font_size", font_size)
	# Finish input dispatch before replacing any Control nodes in the tree.
	b.pressed.connect(func(): action.call_deferred())
	parent.add_child(b)
	return b

func _rect(node: Control, x: float, y: float, w: float, h: float) -> void:
	_fit_text(node, w, h)
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)

func _undo_icon(button: Button, centered_text: bool = false) -> void:
	if centered_text:
		# The glyph stays at the left; the label has the same center as Restart.
		button.draw.connect(func():
			var key := "disabled" if button.disabled else ("pressed" if button.is_pressed() else "normal")
			var skin := button.get_theme_stylebox(key)
			var center_y := (button.size.y + skin.get_content_margin(SIDE_TOP) - skin.get_content_margin(SIDE_BOTTOM)) * 0.5
			button.draw_texture_rect(UNDO_ICON, Rect2(12, center_y-10, 20, 20), false, Color("a99b92") if button.disabled else Color.WHITE)
		)
		return
	button.icon = UNDO_ICON
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)

func _fit_text(node: Control, w: float, h: float) -> void:
	if not (node is Label or node is Button) or not node.has_meta("base_font_size"):
		return
	var font_size := int(node.get_meta("base_font_size"))
	if w <= 0 or h <= 0:
		node.add_theme_font_size_override("font_size", font_size)
		return
	var available := Vector2(w, h)
	if node is Button:
		var skin := node.get_theme_stylebox("normal")
		available -= skin.get_minimum_size()
		if node.icon:
			available.x -= minf(node.icon.get_width(), 20) + node.get_theme_constant("h_separation")
	while font_size > 10:
		var measured: Vector2
		if node is Label and node.autowrap_mode != TextServer.AUTOWRAP_OFF:
			measured = font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size)
		else:
			measured = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if measured.x <= available.x and measured.y <= available.y:
			break
		font_size -= 1
	node.add_theme_font_size_override("font_size", font_size)

func _t(key: String, args: Array = []) -> String:
	return Localization.text(key, language, args)

func _level_title(index: int) -> String:
	if int(levels[index].id) < 1 or int(levels[index].id) > 12:
		return String(levels[index].title) # Isolated QA levels are not shipped chapter text.
	return Localization.level_title(int(levels[index].id), language)

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
	if overlay_kind == "auth_pending" and is_instance_valid(auth) and auth.busy:
		overlay_kind = ""
		auth.sign_out()
		return
	_clear(overlay)
	overlay_kind = ""
	paused = false
	if is_instance_valid(stick):
		stick.enabled = mode == "play" and state.get("status", "") == "playing"
	if is_instance_valid(board):
		board.set_process(true)
	_reset_input()

func _show_home() -> void:
	if not auth.is_authenticated():
		_show_login()
		return
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "home"
	board = null
	stick = null
	var title := _label(content, _t("home.title"), 61, INK, true)
	title.add_theme_color_override("font_outline_color", Color("fff1ce"))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_shadow_color", Color(0.31,0.15,0.22,0.18))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.name = "Title"
	var subtitle := _label(content, _t("home.subtitle"), 26, Color("d96b4c"), true)
	subtitle.add_theme_color_override("font_outline_color", Color("fff1ce"))
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.name = "Subtitle"
	var hero := IdleMonster.new()
	hero.name = "Hero"
	content.add_child(hero)
	var account := _button(content, _t("account."+auth.provider), _account_panel, CREAM, 14)
	account.name = "Account"
	var start := _button(content, _t("lobby.enter"), start_level.bind(_next_level()), CORAL, 22)
	start.name = "Start"
	var select := _button(content, _t("home.levels"), show_levels, CREAM)
	select.name = "Select"
	var settings := _button(content, _t("home.settings"), _settings, MINT, 16)
	settings.name = "Settings"
	_layout()

func _show_login() -> void:
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "login"
	board = null
	stick = null
	var title := _label(content, _t("home.title"), 61, INK, true)
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", CREAM)
	title.add_theme_constant_override("outline_size", 8)
	var subtitle := _label(content, _t("home.subtitle"), 26, Color("d96b4c"), true)
	subtitle.name = "Subtitle"
	subtitle.add_theme_color_override("font_outline_color", CREAM)
	subtitle.add_theme_constant_override("outline_size", 4)
	var hero := TextureRect.new()
	hero.texture = HOME_MONSTER
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.name = "Hero"
	content.add_child(hero)
	var google := GoogleButton.new()
	google.name = "Google"
	google.text = _t("login.google")
	google.pressed.connect(func(): auth.sign_in_google.call_deferred())
	content.add_child(google)
	var guest := _button(content, _t("login.guest"), auth.login_guest, CREAM, 19)
	guest.name = "Guest"
	var settings := _button(content, _t("home.settings"), _settings, MINT, 14)
	settings.name = "Settings"
	_auth_busy_changed()
	_layout()

func _auth_busy_changed() -> void:
	if mode != "login" or not is_instance_valid(content):
		return
	for key in ["Google", "Guest"]:
		var button := content.get_node_or_null(key) as Button
		if button: button.disabled = auth.busy
	if auth.busy:
		var panel := _panel(_t("login.title"), _t("login.pending"), 270)
		overlay_kind = "auth_pending"
		var cancel := _button(panel, _t("login.cancel"), _close_overlay, CREAM)
		cancel.name = "Cancel"
		_rect(cancel, 25, 180, panel.size.x-50, 54)
	elif overlay_kind == "auth_pending":
		_close_overlay()

func _auth_failed(code: String) -> void:
	auth_error_code = code
	var message := "login.unavailable"
	if code == "cancelled":
		return
	if code == "save_failed": message = "login.save_failed"
	elif code != "not_configured": message = "login.retry"
	var panel := _panel(_t("login.title"), _t(message), 270)
	overlay_kind = "auth_error"
	var done := _button(panel, _t("settings.done"), _close_overlay, CORAL)
	done.name = "Done"
	_rect(done, 25, 180, panel.size.x-50, 54)

func _account_panel() -> void:
	if not auth.is_authenticated():
		return
	var panel := _panel(_t("account."+auth.provider), _t("account.local"), 310)
	overlay_kind = "account"
	var signout := _button(panel, _t("account.sign_out"), auth.sign_out, CREAM)
	signout.name = "SignOut"
	_rect(signout, 25, 166, panel.size.x-50, 52)
	var done := _button(panel, _t("settings.done"), _close_overlay, MINT)
	done.name = "Done"
	_rect(done, 25, 231, panel.size.x-50, 52)

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
	if not auth.is_authenticated():
		_show_login()
		return
	_cancel_animation()
	_reset_input()
	_close_overlay()
	_clear(content)
	mode = "select"
	board = null
	stick = null
	var back := _button(content, "←", _show_home)
	back.name = "Back"
	var title := _label(content, _t("levels.title"), 32, INK, true)
	title.name = "Title"
	var sub := _label(content, _t("levels.completed", [progress.completed.size()]), 17, Color("93707b"), true)
	sub.name = "Subtitle"
	for i in levels.size():
		var done: bool = progress.completed.has(i)
		var b := _button(content, "%02d%s" % [i+1, "  ✓" if done else ""], start_level.bind(i), Color("dce7c9") if done else CREAM, 25)
		b.name = "Level%d" % i
		b.disabled = i > _unlocked()
		b.tooltip_text = _level_title(i) if not b.disabled else _t("levels.locked")
	_layout()

func start_level(index: int) -> void:
	if not auth.is_authenticated():
		_show_login()
		return
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
	var tag := _label(content, _t("hud.chapter", [index + 1]), 12, Color("8b5769"))
	tag.name = "Tag"
	var title := _label(content, _level_title(index), 25)
	title.add_theme_color_override("font_shadow_color", Color("fff9e5"))
	title.add_theme_constant_override("shadow_offset_y", -1)
	title.name = "Title"
	var pause := _button(content, "Ⅱ", pause_game, CREAM, 24)
	pause.name = "Pause"
	pause.tooltip_text = _t("hud.pause")
	counter = _label(content, "", 18, INK)
	counter.name = "Counter"
	var food_texture := AtlasTexture.new()
	food_texture.atlas = FOOD_ATLAS
	food_texture.region = Board.SPRITE_RECTS[2]
	food_texture.filter_clip = true
	var food_icon := TextureRect.new()
	food_icon.name = "FoodIcon"
	food_icon.texture = food_texture
	food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(food_icon)
	step_label = _label(content, "", 14, Color("93707b"), true)
	step_label.name = "Moves"
	board = Board.new()
	board.name = "Board"
	board.clip_contents = true
	content.add_child(board)
	board.set_data(levels[index], state)
	stick = Stick.new()
	stick.name = "Stick"
	content.add_child(stick)
	stick.direction_changed.connect(_on_direction)
	_localize_direction_keys()
	undo_button = _button(content, _t("controls.undo"), undo, CREAM, 18)
	_undo_icon(undo_button, true)
	undo_button.name = "Undo"
	var restart := _button(content, _t("controls.restart"), restart_level, Color("e6eddc"), 18)
	restart.name = "Restart"
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
	layout_top = top
	layout_bottom = bottom
	if mode == "login":
		_rect(content.get_node("Title"), 20, top+40, w-40, 86)
		_rect(content.get_node("Subtitle"), 20, top+120, w-40, 39)
		_rect(content.get_node("Hero"), 18, top+171, w-36, maxf(140, h-top-bottom-433))
		_rect(content.get_node("Google"), 60, h-bottom-206, w-120, 48)
		_rect(content.get_node("Guest"), 57, h-bottom-143, w-114, 60)
		_rect(content.get_node("Settings"), (w-120)*0.5, h-bottom-62, 120, 44)
	elif mode == "home":
		_rect(content.get_node("Account"), 28, top+2, 130, 44)
		_rect(content.get_node("Title"), 20, top+56, w-40, 86)
		_rect(content.get_node("Subtitle"), 20, top+136, w-40, 39)
		_rect(content.get_node("Hero"), 18, top+184, w-36, maxf(168, h-top-bottom-434))
		_rect(content.get_node("Start"), 57, h-bottom-194, w-114, 68)
		_rect(content.get_node("Select"), 57, h-bottom-110, (w-130)*0.65, 55)
		_rect(content.get_node("Settings"), 73+(w-130)*0.65, h-bottom-110, (w-130)*0.35, 55)
	elif mode == "select":
		_rect(content.get_node("Back"), 22, top, 52, 48)
		_rect(content.get_node("Title"), 84, top+4, w-168, 42)
		_rect(content.get_node("Subtitle"), 30, top+53, w-60, 28)
		var bw := (w-88)/3.0
		var bh := minf(93, (h-top-bottom-228)/4.0)
		for i in levels.size():
			_rect(content.get_node("Level%d" % i), 28 + (i%3)*(bw+16), top+132+(i/3)*(bh+18), bw, bh)
	elif mode == "play" and is_instance_valid(board):
		_rect(content.get_node("Tag"), 33, top-2, w-118, 18)
		_layout_play_title()
		_rect(content.get_node("Pause"), w-79, top+4, 49, 49)
		_rect(step_label, w*0.73, top+56, w*0.19, 25)
		step_label.add_theme_color_override("font_color", INK)
		_rect(board, 12, top+117, w-24, maxf(160, h-top-bottom-327))
		var control_w := minf(180.0, (w-66.0)*0.5)
		var action_w := minf(180.0, (w-88.0)*0.5)
		var stick_x := 25.0 if not progress.left_handed else w-25-control_w
		var actions_x := w-28-action_w if not progress.left_handed else 28.0
		_rect(stick, stick_x, h-bottom-188, control_w, 180)
		_rect(undo_button, actions_x, h-bottom-166, action_w, 56)
		_rect(content.get_node("Restart"), actions_x, h-bottom-86, action_w, 56)
	if overlay.get_child_count() > 0:
		var panel: Control = overlay.get_node_or_null("Panel")
		if panel:
			panel.position = Vector2((w-panel.size.x)*0.5, maxf(top+10, (h-panel.size.y)*0.5))

func _layout_play_title() -> void:
	if mode != "play" or not is_instance_valid(counter):
		return
	var title: Label = content.get_node("Title")
	var count_width := maxf(34, font.get_string_size(counter.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	var title_width := maxf(24, size.x-124-count_width-44)
	_rect(title, 33, layout_top+18, title_width, 36)
	# Keep the count directly after the rendered title, including narrow English screens.
	var measured := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	title.size.x = ceilf(minf(title_width, measured))
	_rect(counter, title.position.x+title.size.x+12, layout_top+18, count_width, 36)
	_rect(content.get_node("FoodIcon"), counter.position.x+count_width+8, layout_top+24, 24, 24)

func _update_hud(visible_state: Dictionary = {}) -> void:
	if not is_instance_valid(counter) or mode != "play":
		return
	var total: int = levels[level_index].fruit.size()
	var shown := state if visible_state.is_empty() else visible_state
	counter.text = "%d/%d" % [total-shown.fruit.size(), total]
	_layout_play_title()
	step_label.text = _t("hud.moves", [state.moves])
	_fit_text(step_label, step_label.size.x, step_label.size.y)
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
		return false
	history.append(state.duplicate(true))
	animation_from = state.duplicate(true)
	state = result.state
	fail_reason = result.reason
	animation_frames = result.frames
	animation_index = 0
	animation_time = 0.0
	animation_ate = result.active_ate
	animation_eat_fired = false
	animation_food_events = result.eat_events.duplicate(true)
	animation_food_cursor = 0
	animation_food_prepared = false
	animation_fall_started = false
	animation_continuous = held != Vector2i.ZERO
	repeat_clock = MOVE_SECONDS
	busy = true
	board.motion_active = true
	board.facing_direction = d
	board.react("move", d)
	if animation_ate:
		board.anticipate_food(d, Vector2(animation_frames[0].body[0]))
		animation_food_prepared = true
	audio.play("move")
	_update_hud(animation_from)
	if skip_animations:
		animation_time = MOVE_SECONDS + sqrt(2.0 * (animation_frames.size()-1) / FALL_ACCELERATION)
		_update_food_animation()
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
	else:
		if fall_rows > 0:
			if not animation_fall_started:
				animation_fall_started = true
				board.react("fall")
			var elapsed := minf(animation_time - MOVE_SECONDS, fall_seconds)
			var drop := minf(fall_rows, 0.5 * FALL_ACCELERATION * elapsed * elapsed)
			animation_index = mini(int(drop + 0.000001), fall_rows)
			for part in moved.body:
				positions.append(Vector2(part) + Vector2(0, drop))
			board.set_data(levels[level_index], animation_frames[animation_index])
			board.body_override = positions
		_update_food_animation()
		if animation_time >= MOVE_SECONDS + fall_seconds:
			if fall_rows > 0 and state.status != "lost":
				board.body_override = []
				board.set_data(levels[level_index], state)
				board.react("land")
				audio.play("land")
			_finish_animation()
			return
	board.body_override = positions
	_update_food_animation()
	board.queue_redraw()

func _update_food_animation() -> void:
	while animation_food_cursor < animation_food_events.size():
		var event: Dictionary = animation_food_events[animation_food_cursor]
		var contact := MOVE_SECONDS * 0.75 if event.frame == 0 else MOVE_SECONDS + sqrt(2.0 * event.frame / FALL_ACCELERATION)
		if animation_time < contact - 0.10:
			return
		if not animation_food_prepared:
			# Nearby falling food can arrive sooner than one full swallow cycle.
			# Preserve the current cube until the next actual contact, rather than
			# overwriting it with early anticipation for the following cube.
			if board.mouth_animation == "swallow" and animation_time + 0.000001 < contact:
				return
			board.anticipate_food(event.direction, Vector2(event.cell))
			animation_food_prepared = true
		if animation_time + 0.000001 < contact:
			return
		board.react("eat", event.direction)
		audio.play("eat")
		_update_hud(board.state)
		if event.frame == 0:
			animation_eat_fired = true
		animation_food_cursor += 1
		animation_food_prepared = false

func _cancel_animation() -> void:
	busy = false
	terminal_delay = 0.0
	animation_frames.clear()
	animation_food_events.clear()
	animation_food_cursor = 0
	animation_food_prepared = false
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
	panel.add_theme_stylebox_override("panel", UiSkin.panel("cream"))
	overlay.add_child(panel)
	var heading := _label(panel, title, 29, INK, true)
	heading.name = "Heading"
	_rect(heading, 12, 22, panel.size.x-24, 49)
	if not subtitle.is_empty():
		var sub := _label(panel, subtitle, 16, Color("8c6677"), true)
		sub.name = "Description"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rect(sub, 22, 79, panel.size.x-44, 65)
	_layout()
	return panel

func _end_panel(won: bool) -> void:
	var final := level_index == levels.size()-1
	var title := _t("end.final_title" if won and final else ("end.win_title" if won else "end.lose_title"))
	var subtitle := _t("end.final_description" if won and final else ("end.win_description" if won else ("end.boundary_description" if fail_reason == "boundary" else "end.spike_description")))
	if save_failed and won:
		subtitle += "\n" + _t("end.save_failed")
	var panel := _panel(title, subtitle, 370 if save_failed and won else 328)
	overlay_kind = "end"
	var action := show_levels if won and final else (start_level.bind(level_index+1) if won else undo)
	var primary := _button(panel, _t("end.back_levels" if won and final else ("end.next" if won else "end.undo")), action, CORAL, 20)
	if not won:
		_undo_icon(primary)
	primary.name = "Continue"
	_rect(primary, 26, 162, panel.size.x-52, 57)
	var secondary := _button(panel, _t("end.replay" if won else "end.restart"), restart_level, CREAM, 17)
	_rect(secondary, 26, 233, (panel.size.x-66)*0.60, 48)
	var home := _button(panel, _t("end.levels"), show_levels, MINT, 17)
	_rect(home, 40+(panel.size.x-66)*0.60, 233, (panel.size.x-66)*0.40, 48)
	if save_failed and won:
		var retry := _button(panel, _t("end.retry_save"), _retry_save, CREAM, 14)
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
	_show_pause_panel()

func _show_pause_panel() -> void:
	var panel := _panel(_t("pause.title"), "", 248)
	overlay_kind = "pause"
	var resume := _button(panel, _t("pause.resume"), _close_overlay, CORAL, 21)
	resume.name = "Resume"
	_rect(resume, 26, 94, panel.size.x-52, 58)
	var restart := _button(panel, _t("end.restart"), restart_level, CREAM)
	_rect(restart, 26, 170, (panel.size.x-68)*0.6, 49)
	var levels_b := _button(panel, _t("end.levels"), show_levels, MINT)
	_rect(levels_b, 42+(panel.size.x-68)*0.6, 170, (panel.size.x-68)*0.4, 49)

func _settings() -> void:
	var logged_in: bool = auth.is_authenticated()
	var panel := _panel(_t("settings.title"), _t("settings.description"), 502 if logged_in else 437)
	overlay_kind = "settings"
	var hand := _button(panel, _t("settings.hand", [_t("settings.right_hand" if progress.left_handed else "settings.left_hand")]), _toggle_hand, CREAM, 17)
	hand.name = "Hand"
	_rect(hand, 25, 145, panel.size.x-50, 51)
	var sound := _button(panel, _t("settings.sound", [_t("settings.on" if progress.sound else "settings.off")]), _toggle_sound, CREAM, 17)
	sound.name = "Sound"
	_rect(sound, 25, 211, panel.size.x-50, 51)
	var selected_name := _t("settings.follow_system") if progress.language.is_empty() else Localization.language_name(language)
	var language_button := _button(panel, _t("settings.language", [selected_name]), _language_settings, CREAM, 17)
	language_button.name = "Language"
	_rect(language_button, 25, 277, panel.size.x-50, 51)
	if logged_in:
		var signout := _button(panel, _t("account.sign_out"), _account_panel, CREAM, 17)
		signout.name = "SignOut"
		_rect(signout, 25, 343, panel.size.x-50, 51)
	var back := _button(panel, _t("settings.done"), _close_overlay, CORAL)
	back.name = "Done"
	_rect(back, 25, 415 if logged_in else 350, panel.size.x-50, 52)

func _language_settings() -> void:
	var panel := _panel(_t("settings.language_title"), _t("settings.language_description"), 465)
	overlay_kind = "language"
	var options := ["", "zh_CN", "zh_TW", "en"]
	var node_names := ["LocaleSystem", "LocaleZhCN", "LocaleZhTW", "LocaleEn"]
	for i in options.size():
		var locale: String = options[i]
		var selected: bool = progress.language == locale
		var name_text := _t("settings.follow_system") + " · " + Localization.language_name(Localization.system_locale()) if locale.is_empty() else Localization.language_name(locale)
		var option := _button(panel, name_text + ("  ✓" if selected else ""), _choose_language.bind(locale), MINT if selected else CREAM, 17)
		option.name = node_names[i]
		_rect(option, 25, 144+i*57, panel.size.x-50, 48)
	var done := _button(panel, _t("settings.done"), _settings, CORAL)
	done.name = "Done"
	_rect(done, 25, 386, panel.size.x-50, 51)

func _choose_language(locale: String) -> void:
	_set_language(locale)
	_settings()

func _set_language(locale: String) -> bool:
	if not locale.is_empty() and not locale in Localization.SUPPORTED_LOCALES:
		return false
	progress.language = locale
	language = Localization.system_locale() if locale.is_empty() else locale
	save_failed = not Progress.save_data(save_path, progress)
	_refresh_texts()
	return true

func _localize_direction_keys() -> void:
	if not is_instance_valid(stick):
		return
	var keys := {Vector2i.UP:"controls.up", Vector2i.RIGHT:"controls.right", Vector2i.DOWN:"controls.down", Vector2i.LEFT:"controls.left"}
	for direction in keys:
		stick.buttons[direction].tooltip_text = _t(keys[direction])

func _refresh_texts() -> void:
	if not is_instance_valid(content):
		return
	if mode == "login":
		var login_keys := {"Title":"home.title", "Subtitle":"home.subtitle", "Google":"login.google", "Guest":"login.guest", "Settings":"home.settings"}
		for node_name in login_keys:
			content.get_node(node_name).text = _t(login_keys[node_name])
	elif mode == "home":
		var home_keys := {"Title":"home.title", "Subtitle":"home.subtitle", "Start":"lobby.enter", "Select":"home.levels", "Settings":"home.settings", "Account":"account."+auth.provider}
		for name_key in home_keys:
			content.get_node(name_key).text = _t(home_keys[name_key])
	elif mode == "select":
		content.get_node("Title").text = _t("levels.title")
		content.get_node("Subtitle").text = _t("levels.completed", [progress.completed.size()])
		for i in levels.size():
			var button: Button = content.get_node("Level%d" % i)
			button.tooltip_text = _level_title(i) if not button.disabled else _t("levels.locked")
	elif mode == "play":
		content.get_node("Tag").text = _t("hud.chapter", [level_index+1])
		content.get_node("Title").text = _level_title(level_index)
		content.get_node("Pause").tooltip_text = _t("hud.pause")
		undo_button.text = _t("controls.undo")
		content.get_node("Restart").text = _t("controls.restart")
		_localize_direction_keys()
		_update_hud(board.state if busy else {})
	_layout()
	match overlay_kind:
		"settings": _settings()
		"language": _language_settings()
		"pause": _show_pause_panel()
		"end": _end_panel(state.status == "won")
		"account": _account_panel()
		"auth_error": _auth_failed(auth_error_code)
		"auth_pending": _auth_busy_changed()

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
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not progress.is_empty() and progress.get("language", "").is_empty():
		var current := Localization.system_locale()
		if current != language:
			language = current
			_refresh_texts()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_input()
		if mode == "play" and is_instance_valid(content):
			pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if paused: _close_overlay()
		elif mode == "play": pause_game()
		else: _show_home()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _draw() -> void:
	var factor := maxf(size.x / MEADOW.get_width(), size.y / MEADOW.get_height())
	var bg_size := MEADOW.get_size() * factor
	draw_texture_rect(MEADOW, Rect2((size-bg_size)*0.5, bg_size), false)
	if mode == "home":
		draw_style_box(UiSkin.panel("cream"), Rect2(37, size.y-layout_bottom-218, size.x-74, 187))
	elif mode == "login":
		draw_style_box(UiSkin.panel("cream"), Rect2(37, size.y-layout_bottom-228, size.x-74, 163))
	if mode == "play" or mode == "select":
		draw_style_box(UiSkin.panel("cream"), Rect2(15, layout_top-10, size.x-30, 119 if mode == "play" else 123))
	if mode == "play":
		draw_style_box(UiSkin.panel("cream"), Rect2(12, size.y-layout_bottom-200, size.x-24, 214))
