extends SceneTree
const Progress = preload("res://scripts/progress.gd")
var app: Control
var checks := 0
var failures := 0
var test_path := ""

class NativeStub extends RefCounted:
	signal sign_in_succeeded(subject: String)
	signal sign_in_failed(code: String)
	var starts := 0
	var cancellations := 0
	func is_configured() -> bool: return true
	func sign_in() -> void: starts += 1
	func sign_out() -> void: cancellations += 1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOGIN QA: " + note)

func tap(node: Control) -> void:
	var point: Vector2 = root.get_screen_transform() * node.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.pressed = pressed
		event.index = 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await process_frame
	await process_frame

func launch() -> void:
	app = load("res://main.tscn").instantiate()
	app.qa_mode = true
	app.save_path = test_path
	app.auth_path = test_path + ".auth"
	root.add_child(app)
	app.audio.enabled = false
	await process_frame
	await process_frame

func close_app() -> void:
	app.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(480, 854)
	root.content_scale_size = Vector2i(480, 854)
	test_path = "user://qa/login-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_msec()]
	var baseline := Progress.defaults()
	baseline.completed = [0, 1, 2]
	baseline.language = "en"
	baseline.sound = false
	baseline.left_handed = true
	check(Progress.save_data(test_path, baseline), "Prepare existing progress independently of account")
	await launch()
	check(app.mode == "login" and not app.auth.is_authenticated(), "Existing progress does not bypass first login")
	for name in ["Google", "Guest", "Settings"]:
		check(app.content.get_node_or_null(name) is Button, "Login has usable " + name + " entry")
	app.start_level(0)
	check(app.mode == "login" and not is_instance_valid(app.board), "Unauthenticated direct level entry is guarded")
	app.show_levels()
	check(app.mode == "login", "Unauthenticated level selection is guarded")
	app._show_home()
	check(app.mode == "login", "Unauthenticated lobby entry is guarded")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.mode == "login", "Android back cannot enter lobby before login")
	await tap(app.content.get_node("Settings"))
	check(app.overlay_kind == "settings", "Settings remain available before login")
	check(app.overlay.get_node_or_null("Panel/SignOut") == null, "Logged-out settings do not offer sign-out")
	app._close_overlay()
	await tap(app.content.get_node("Google"))
	await create_timer(0.1).timeout
	check(app.mode == "login" and not app.auth.is_authenticated() and not app.auth.busy, "Unconfigured Google attempt never grants login or stays busy")
	app._close_overlay()
	await tap(app.content.get_node("Guest"))
	check(app.mode == "home" and app.auth.provider == "guest" and app.auth.is_authenticated(), "Native guest tap enters authenticated lobby")
	check(app.progress.completed == [0,1,2] and app.progress.left_handed and app.progress.language == "en", "Guest entry preserves existing local progress and preferences")
	for name in ["Start", "Select", "Settings", "Account"]:
		check(app.content.get_node_or_null(name) is Button, "Lobby has usable " + name + " entry")
	var hero: Control = app.content.get_node("Hero")
	check(hero.is_processing(), "Lobby monster runs its idle animation")
	await tap(app.content.get_node("Select"))
	check(app.mode == "select" and app.content.get_node_or_null("Footer") == null, "Level selection opens without retired hint")
	await tap(app.content.get_node("Back"))
	check(app.mode == "home", "Level selection back returns to lobby")
	await tap(app.content.get_node("Start"))
	check(app.mode == "play" and app.level_index == 3, "Lobby entry starts next incomplete level")
	app._show_home()
	await close_app()
	await launch()
	check(app.mode == "home" and app.auth.provider == "guest", "Guest choice survives application restart")
	var saved_auth := FileAccess.get_file_as_string(test_path + ".auth")
	check(not saved_auth.contains("id_token") and not saved_auth.contains("refresh_token") and not saved_auth.contains("access_token"), "Guest persistence contains no OAuth token fields")
	await tap(app.content.get_node("Account"))
	check(app.overlay_kind == "account" and app.auth.is_authenticated(), "Account review does not sign out immediately")
	await tap(app.overlay.get_node("Panel/Done"))
	check(app.mode == "home" and app.auth.is_authenticated(), "Cancelling account panel preserves session")
	await tap(app.content.get_node("Account"))
	await tap(app.overlay.get_node("Panel/SignOut"))
	check(app.mode == "login" and not app.auth.is_authenticated(), "Account action signs out and returns to login")
	check(Progress.load_data(test_path, 12).data == baseline, "Sign-out does not alter progress or settings")
	await close_app()
	await launch()
	check(app.mode == "login" and not app.auth.is_authenticated(), "Sign-out persists across restart")
	app.auth._google_success("late-sdk-reply")
	check(not app.auth.is_authenticated() and app.mode == "login", "Late Google callback after sign-out cannot reopen lobby")
	await tap(app.content.get_node("Guest"))
	check(app.progress.completed == [0,1,2], "Guest re-entry retains completed levels")
	await close_app()
	var file := FileAccess.open(test_path + ".auth", FileAccess.WRITE)
	file.store_string(JSON.stringify({"provider":"google","subject":"local-forgery","id_token":"not-a-token"}))
	file.close()
	await launch()
	check(not app.auth.is_authenticated() and app.mode == "login", "Unverified Google identity in local preferences is never restored")
	# SDK boundary double: no real account, token verification, or network call.
	var sdk := NativeStub.new()
	app.auth.native = sdk
	sdk.sign_in_succeeded.connect(app.auth._google_success)
	sdk.sign_in_failed.connect(app.auth._google_failure)
	await tap(app.content.get_node("Google"))
	check(app.auth.busy and app.overlay_kind == "auth_pending" and sdk.starts == 1, "Pending SDK attempt displays progress with cancellation")
	check(app.content.get_node("Google").disabled and app.content.get_node("Guest").disabled, "Pending attempt disables duplicate login choices")
	await tap(app.overlay.get_node("Panel/Cancel"))
	check(not app.auth.busy and app.mode == "login" and app.overlay_kind == "" and sdk.cancellations == 1, "Cancel returns to usable login and cancels native request")
	sdk.sign_in_succeeded.emit("cancelled-attempt")
	check(not app.auth.is_authenticated() and app.mode == "login", "Late SDK success after cancel is ignored")
	await tap(app.content.get_node("Guest"))
	check(app.mode == "home" and app.auth.provider == "guest", "Guest remains available after cancelling Google")
	app.auth.sign_out()
	await tap(app.content.get_node("Google"))
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not app.auth.busy and app.overlay_kind == "" and app.mode == "login", "Android back cancels pending request")
	await tap(app.content.get_node("Google"))
	sdk.sign_in_failed.emit("network_error")
	check(not app.auth.busy and app.overlay_kind == "auth_error" and app.mode == "login", "SDK failure removes progress and presents retry error")
	app._close_overlay()
	await tap(app.content.get_node("Google"))
	sdk.sign_in_failed.emit("cancelled")
	check(not app.auth.busy and app.overlay_kind == "" and app.mode == "login", "SDK user dismissal closes progress without an error dialog")
	await tap(app.content.get_node("Google"))
	sdk.sign_in_succeeded.emit("")
	check(not app.auth.is_authenticated() and app.overlay_kind == "auth_error", "Empty verified subject cannot authorize login")
	app._close_overlay()
	await tap(app.content.get_node("Google"))
	sdk.sign_in_succeeded.emit("server-verified-stub-subject")
	check(app.auth.provider == "google" and app.mode == "home" and app.overlay_kind == "" and not app.auth.busy, "SDK success closes progress and enters lobby")
	check(not FileAccess.get_file_as_string(test_path + ".auth").contains("server-verified-stub-subject"), "Google subject is not persisted in local guest preference")
	await close_app()
	for base in [test_path, test_path + ".auth"]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = base + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LOGIN_QA checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
