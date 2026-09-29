extends RefCounted
## Small reusable nine-patch skins; the illustrated world/characters use authored PNGs.
static var cache: Dictionary = {}

static func button(fill: Color, pressed: bool = false, disabled: bool = false) -> StyleBoxTexture:
	var key := "%s/%s/%s" % [fill.to_html(), pressed, disabled]
	if cache.has(key):
		return cache[key]
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var p := Vector2(x + 0.5, y + 0.5)
			var q := (p - Vector2(48, 45)).abs() - Vector2(28, 25)
			var distance := Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0) - 13
			var alpha := clampf(0.6-distance, 0, 1)
			var col := Color.TRANSPARENT
			if alpha > 0:
				var lighting := 0.08 - float(y)/96.0 * 0.16
				var grain := (fmod(sin(x*12.9898+y*78.233)*43758.5453, 1.0)) * 0.008
				col = fill.lightened(lighting+grain) if lighting+grain >= 0 else fill.darkened(-lighting-grain)
				if distance > -2.0:
					col = fill.darkened(0.24 if not disabled else 0.12)
				elif distance > -4.0 and y < 48:
					col = fill.lightened(0.40)
				elif y > 79 and not pressed:
					col = fill.darkened(0.20)
				col.a = alpha
			else:
				var sq := (p-Vector2(48, 49)).abs()-Vector2(28,25)
				var sd := Vector2(maxf(sq.x,0), maxf(sq.y,0)).length()+minf(maxf(sq.x,sq.y),0)-13
				col = Color(0.25,0.16,0.12, clampf((3-sd)/6,0,1)*0.19 if not disabled else 0)
			img.set_pixel(x,y,col)
	var skin := StyleBoxTexture.new()
	skin.texture = ImageTexture.create_from_image(img)
	for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(edge, 26)
		skin.set_expand_margin(edge, 7)
		skin.set_content_margin(edge, 9)
	cache[key] = skin
	return skin
