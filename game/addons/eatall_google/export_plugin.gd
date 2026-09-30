@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	export_plugin = GoogleExport.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)

class GoogleExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "EatAllGoogle"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not ProjectSettings.get_setting("eatall_google/enabled", false):
			return PackedStringArray()
		return PackedStringArray(["res://addons/eatall_google/bin/EatAllGoogle.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not ProjectSettings.get_setting("eatall_google/enabled", false):
			return PackedStringArray()
		return PackedStringArray(["com.google.android.gms:play-services-games-v2:22.1.0"])
