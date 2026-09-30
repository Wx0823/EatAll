extends SceneTree
const OUTPUT := "res://../production/qa/v0.6.0/screenshots/"
var app: Control
var failures := 0
var captures := 0
var test_path := ""

class NativePendingStub extends RefCounted:
	func is_configured() -> bool: return true
	func sign_in() -> void: pass
	func sign_out() -> void: pass

func _initialize() -> void:
	call_deferred("capture")

func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error("LOGIN CAPTURE: " + note)

func capture() -> void:
	test_path = "user://qa/login-capture-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_msec()]
	root.size = Vector2i(480,854)
	root.content_scale_size = Vector2i(480,854)
	app = load("res://main.tscn").instantiate()
	app.qa_mode = true
	app.save_path = test_path
	app.auth_path = test_path + ".auth"
	root.add_child(app)
	app.audio.enabled = false
	for viewport in [Vector2i(480,854),Vector2i(390,700)]:
		root.size = viewport
		root.content_scale_size = viewport
		for locale in ["zh_CN","zh_TW","en"]:
			app.auth.sign_out()
			app._set_language(locale)
			app._close_overlay()
			var prefix: String = locale + "-" + str(viewport.x)
			await shot(prefix + "-01-login.png")
			app.auth.sign_in_google()
			await process_frame
			check(app.mode == "login" and not app.auth.is_authenticated(), "Unavailable Google stays on login")
			await shot(prefix + "-02-google-unavailable.png")
			app._close_overlay()
			if viewport.x == 390:
				app.auth.native = NativePendingStub.new()
				app.auth.sign_in_google()
				await shot(prefix + "-02b-google-pending-stub.png")
				app._close_overlay()
				app.auth.native = null
			app.auth.login_guest()
			await shot(prefix + "-03-lobby.png")
			if viewport.x == 480 and locale == "zh_CN":
				var before: Image = root.get_texture().get_image()
				await create_timer(0.55).timeout
				await shot(prefix + "-03b-idle.png")
				var after: Image = root.get_texture().get_image()
				check(before.get_data() != after.get_data(), "Actual rendered lobby changes during idle")
			app._settings()
			await shot(prefix + "-04-settings.png")
			app._close_overlay()
			app.content.get_node("Account").pressed.emit()
			await process_frame
			await shot(prefix + "-04b-account.png")
			app._close_overlay()
			app.show_levels()
			await shot(prefix + "-05-levels.png")
			check(app.content.get_node_or_null("Footer") == null, "Level selection hint removed")
	print("LOGIN_CAPTURE captures=%d failures=%d" % [captures,failures])
	app.queue_free()
	await process_frame
	for base in [test_path,test_path+".auth"]:
		for suffix in ["",".bak",".tmp"]:
			var path: String = base + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures == 0 else 1)

func shot(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	verify_bounds(app.content)
	verify_bounds(app.overlay)
	var path := ProjectSettings.globalize_path(OUTPUT + filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path) == OK, "Screenshot saved")
	captures += 1
	print("CAPTURE " + filename)

func verify_bounds(node: Node) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(rect), "Visible UI stays on screen: " + str(node.name))
		if node is Button and not node.text.is_empty():
			var inner: Vector2 = node.size - node.get_theme_stylebox("normal").get_minimum_size()
			var measured: Vector2 = node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size"))
			check(measured.x <= inner.x+1 and measured.y <= inner.y+1,"Button text fits surface: " + str(node.name))
	for child in node.get_children(): verify_bounds(child)
