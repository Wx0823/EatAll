extends Button
## Google brand surface is deliberately independent from the game's pastry skin.
const LOGO = preload("res://assets/google/g-logo.png")
const GOOGLE_FONT = preload("res://assets/google/GoogleSans.ttf")
const CJK_FONT = preload("res://assets/NotoSansSC.ttf")

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = LOGO
	expand_icon = true
	add_theme_constant_override("icon_max_width", 20)
	add_theme_constant_override("h_separation", 10)
	var typeface := FontVariation.new()
	typeface.base_font = GOOGLE_FONT
	typeface.variation_opentype = {2003265652:500.0}
	var cjk_medium := FontVariation.new()
	cjk_medium.base_font = CJK_FONT
	cjk_medium.variation_opentype = {2003265652:500.0}
	typeface.fallbacks = [cjk_medium]
	add_theme_font_override("font", typeface)
	add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE if state not in ["hover", "pressed"] else Color("f2f2f2")
		style.border_color = Color("747775")
		style.set_border_width_all(1 if state != "focus" else 2)
		style.set_corner_radius_all(24)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		add_theme_stylebox_override(state, style)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color_key, Color("1f1f1f"))
	add_theme_color_override("icon_disabled_color", Color.WHITE)
