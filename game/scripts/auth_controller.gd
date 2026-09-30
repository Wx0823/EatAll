extends Node
## Device-local guest choice; Google identity is accepted only from the native
## server-verified success signal. Tokens and identities are never written here.
signal authenticated
signal signed_out
signal failed(code: String)
signal busy_changed

var save_path := "user://login.json"
var provider := ""
var subject := ""
var busy := false
var native: Object

func _ready() -> void:
	if Engine.has_singleton("EatAllGoogle"):
		native = Engine.get_singleton("EatAllGoogle")
		native.sign_in_succeeded.connect(_google_success)
		native.sign_in_failed.connect(_google_failure)
	if FileAccess.file_exists(save_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary and saved.get("guest", false) == true:
			provider = "guest"

func is_authenticated() -> bool:
	return provider == "guest" or (provider == "google" and not subject.is_empty())

func login_guest() -> void:
	if busy:
		return
	provider = "guest"
	subject = ""
	_save_guest(true)
	authenticated.emit()

func sign_in_google() -> void:
	if busy:
		return
	if native == null or not native.is_configured():
		failed.emit("not_configured")
		return
	busy = true
	busy_changed.emit()
	native.sign_in()

func _google_success(verified_subject: String) -> void:
	# Ignore late SDK responses after leaving/cancelling a request.
	if not busy:
		return
	if verified_subject.is_empty():
		_google_failure("verification_failed")
		return
	busy = false
	provider = "google"
	subject = verified_subject
	_save_guest(false)
	busy_changed.emit()
	authenticated.emit()

func _google_failure(code: String) -> void:
	if not busy:
		return
	busy = false
	busy_changed.emit()
	failed.emit(code)

func sign_out() -> void:
	busy = false
	provider = ""
	subject = ""
	_save_guest(false)
	if native != null:
		native.sign_out()
	busy_changed.emit()
	signed_out.emit()

func _save_guest(value: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		# A failed preference save must never prevent local play or grant Google access.
		failed.emit("save_failed")
		return
	file.store_string(JSON.stringify({"version":1, "guest":value}))
