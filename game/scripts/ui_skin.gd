extends RefCounted
## Authored baked-picnic sprites. Loads and nine-patch resources are cached once.
static var cache: Dictionary = {}
static var _textures: Dictionary = {}
const BUTTON_ATLAS := "res://assets/ui-v5/baked-buttons-atlas.png"
const DPAD_ATLAS := "res://assets/ui-v5/dpad-keys-atlas.png"
const BUTTON_SOURCE_SIZE := Vector2(1254,1254)
# Shared row bounds preserve the normal/pressed face-height difference.
const ROW_Y := [120.0,375.0,635.0,905.0]
const COLUMN_X := [14.0,426.0,830.0]

static func button(fill: Color, pressed: bool = false, disabled: bool = false) -> StyleBoxTexture:
	return _button_skin(_palette(fill),2 if disabled else (1 if pressed else 0),false)

static func panel(kind: String = "cream") -> StyleBoxTexture:
	if kind == "badge":
		if not cache.has("badge"):
			var small := _button_skin(2,0,true).duplicate() as StyleBoxTexture
			small.set_texture_margin(SIDE_LEFT,12)
			small.set_texture_margin(SIDE_RIGHT,12)
			small.set_texture_margin(SIDE_TOP,6)
			small.set_texture_margin(SIDE_BOTTOM,8)
			small.set_content_margin(SIDE_LEFT,10)
			small.set_content_margin(SIDE_RIGHT,10)
			small.set_content_margin(SIDE_TOP,3)
			small.set_content_margin(SIDE_BOTTOM,5)
			cache["badge"] = small
		return cache["badge"]
	var row := 0
	if kind in ["mint","controls"]:
		row = 2
	elif kind == "coral":
		row = 1
	elif kind == "plum":
		row = 3
	return _button_skin(row,0,true)

static func dpad_key(pressed: bool = false, disabled: bool = false) -> StyleBoxTexture:
	var state := 2 if disabled else (1 if pressed else 0)
	var key := "dpad/%d" % state
	if cache.has(key):
		return cache[key]
	var texture := _texture(DPAD_ATLAS)
	var ratio := texture.get_size() / Vector2(2172,724)
	var skin := StyleBoxTexture.new()
	skin.texture = texture
	skin.region_rect = Rect2(Vector2([76.0,768.0,1442.0][state],94)*ratio,Vector2(656,514)*ratio)
	for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(edge,0)
	skin.set_texture_margin(SIDE_BOTTOM,23)
	skin.set_content_margin(SIDE_LEFT,5)
	skin.set_content_margin(SIDE_RIGHT,5)
	# Center symbols on the raised face, keeping the same text space and press travel.
	skin.set_content_margin(SIDE_TOP,6 if state == 1 else 2)
	skin.set_content_margin(SIDE_BOTTOM,12 if state == 1 else 16)
	cache[key] = skin
	return skin

static func _palette(fill: Color) -> int:
	if fill.r < 0.62 and fill.b > fill.g:
		return 3
	if fill.r - fill.g > 0.22 and fill.r > 0.70:
		return 1
	if fill.g - fill.r > 0.016:
		return 2
	return 0

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]

static func _button_skin(row: int,state: int,as_panel: bool) -> StyleBoxTexture:
	var key := "button/%d/%d/%s" % [row,state,as_panel]
	if cache.has(key):
		return cache[key]
	var texture := _texture(BUTTON_ATLAS)
	var ratio := texture.get_size() / BUTTON_SOURCE_SIZE
	var skin := StyleBoxTexture.new()
	skin.texture = texture
	skin.region_rect = Rect2(Vector2(COLUMN_X[state],ROW_Y[row])*ratio,Vector2(410,208)*ratio)
	skin.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.set_texture_margin(SIDE_LEFT,22)
	skin.set_texture_margin(SIDE_RIGHT,22)
	skin.set_texture_margin(SIDE_TOP,16)
	skin.set_texture_margin(SIDE_BOTTOM,24)
	skin.set_content_margin(SIDE_LEFT,18 if as_panel else 12)
	skin.set_content_margin(SIDE_RIGHT,18 if as_panel else 12)
	# The baked sidewall is below the face. Move text up 7px without shrinking its area.
	skin.set_content_margin(SIDE_TOP,16 if as_panel else (5 if state == 1 else 1))
	skin.set_content_margin(SIDE_BOTTOM,20 if as_panel else (17 if state == 1 else 21))
	cache[key] = skin
	return skin
