extends RefCounted

static func defaults() -> Dictionary:
	return {"version": 1, "completed": [], "left_handed": false, "sound": true}

static func _parse(path: String, count: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1 or not data.get("completed") is Array:
		return {}
	var clean := defaults()
	for value in data.completed:
		if not (value is float or value is int) or float(value) != float(int(value)):
			return {}
		var n := int(value)
		if n < 0 or n >= count:
			return {}
		if not clean.completed.has(n):
			clean.completed.append(n)
	clean.completed.sort()
	clean.left_handed = data.get("left_handed", false) == true
	clean.sound = data.get("sound", true) == true
	return clean

static func load_data(path: String, count: int) -> Dictionary:
	var primary := _parse(path, count)
	if not primary.is_empty():
		return {"data": primary, "recovered": false}
	var backup := _parse(path + ".bak", count)
	if not backup.is_empty():
		return {"data": backup, "recovered": true}
	return {"data": defaults(), "recovered": FileAccess.file_exists(path)}

static func save_data(path: String, data: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var parent := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return false
	var temp := absolute + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	var backup := absolute + ".bak"
	if FileAccess.file_exists(absolute):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return false
		if DirAccess.rename_absolute(absolute, backup) != OK:
			return false
	if DirAccess.rename_absolute(temp, absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		return false
	return true
