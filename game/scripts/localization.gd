extends RefCounted
## Offline UI text. Language preference and screen refresh belong to main/progress.
const SUPPORTED_LOCALES := ["zh_CN", "zh_TW", "en"]
const CATALOG_PATH := "res://data/translations.json"
static var _catalog: Dictionary = {}
static var _loaded := false
static var _reported_missing: Dictionary = {}

static func normalize_locale(raw: String) -> String:
	var parts := raw.strip_edges().replace("-", "_").to_lower().split("_", false)
	if parts.is_empty() or parts[0] != "zh":
		return "en"
	# An explicit script takes precedence over a conflicting region.
	if parts.has("hant"):
		return "zh_TW"
	if parts.has("hans"):
		return "zh_CN"
	for region in ["tw", "hk", "mo"]:
		if parts.has(region):
			return "zh_TW"
	return "zh_CN"

static func system_locale() -> String:
	return normalize_locale(OS.get_locale())

static func language_name(code: String) -> String:
	match normalize_locale(code):
		"zh_CN": return "简体中文"
		"zh_TW": return "繁體中文"
	return "English"

static func _load_catalog() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		push_error("Invalid local translation catalog: " + CATALOG_PATH)
		return
	_catalog = parsed

static func text(key: String, locale: String = "", args: Array = []) -> String:
	_load_catalog()
	var code := system_locale() if locale.is_empty() else normalize_locale(locale)
	var entries: Dictionary = _catalog.get(code, {})
	var value: String
	if entries.has(key):
		value = str(entries[key])
	else:
		var missing := code + "/" + key
		if not _reported_missing.has(missing):
			_reported_missing[missing] = true
			push_warning("Missing local translation: " + missing)
		var fallback: Dictionary = _catalog.get("zh_CN", {})
		value = str(fallback.get(key, key))
	return value if args.is_empty() else value % args

static func level_title(id: int, locale: String = "") -> String:
	return text("level.%02d.title" % id, locale)

static func level_hint(id: int, locale: String = "") -> String:
	return text("level.%02d.hint" % id, locale)
