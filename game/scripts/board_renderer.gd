extends Control
## Runtime illustration renderer. Grid geometry remains the source of collision truth.
var level: Dictionary = {}
var state: Dictionary = {}
var body_override: Array = []
var mood: String = "normal"
var cell: float = 32.0
var origin: Vector2 = Vector2.ZERO
var sprites: Array[AtlasTexture] = []
var surprised_face: AtlasTexture
const ATLAS_PATH := "res://assets/art-v2/gameplay-atlas.png"
const SURPRISED_PATH := "res://assets/art-v2/head-surprised.png"
# Measured against the 1536x1024 source at alpha > 40; exclude near-transparent
# painterly glow so a waffle still fills its logical cell. No sprite is resampled.
const SPRITE_RECTS := [
	Rect2(84, 33, 405, 450), Rect2(568, 69, 396, 396),
	Rect2(1103, 100, 340, 368), Rect2(59, 567, 435, 386),
	Rect2(550, 525, 444, 451), Rect2(1040, 600, 456, 362)
]

func set_data(new_level: Dictionary, new_state: Dictionary) -> void:
	level = new_level
	state = new_state
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	_load_sprites()

func _load_sprites() -> void:
	if not ResourceLoader.exists(ATLAS_PATH):
		return
	var atlas := load(ATLAS_PATH) as Texture2D
	for index in range(6):
		var sprite := AtlasTexture.new()
		sprite.atlas = atlas
		sprite.region = SPRITE_RECTS[index]
		sprite.filter_clip = true
		sprites.append(sprite)
	if ResourceLoader.exists(SURPRISED_PATH):
		surprised_face = AtlasTexture.new()
		surprised_face.atlas = load(SURPRISED_PATH) as Texture2D
		# Alpha > 40 bounds measured from the actual 1254x1254 file, with 2px bleed.
		surprised_face.region = Rect2(148, 60, 1021, 1117)
		surprised_face.filter_clip = true

func _point(p: Variant) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell

func _circle(p: Vector2, radius: float, color: Color) -> void:
	draw_circle(p, radius, color, true, -1.0, true)

func _draw() -> void:
	if level.is_empty():
		return
	var columns := int(level.get("width", 9))
	var rows := int(level.get("height", 12))
	cell = minf((size.x - 16.0) / maxf(columns, 1), (size.y - 16.0) / maxf(rows, 1))
	if cell <= 0.0:
		return
	origin = (size - Vector2(columns, rows) * cell) * 0.5
	# Let the illustrated meadow remain visible; faint marks communicate grid spacing.
	for y in range(rows):
		for x in range(columns):
			_circle(_point(Vector2i(x, y)), maxf(0.6, cell * 0.014), Color(0.30, 0.40, 0.23, 0.12))
	for tile in level.get("terrain", []):
		_sprite(1, _point(tile), Vector2.ONE * cell * 1.00)
	if level.has("exit"):
		var opened: bool = state.get("fruit", level.get("fruit", [])).is_empty()
		var exit_point := _point(level["exit"])
		if opened:
			for ring in range(7, 0, -1):
				_circle(exit_point + Vector2(0, cell * 0.10), cell * (0.22 + ring * 0.045), Color(1.0, 0.94, 0.57, 0.025))
		_sprite(4 if opened else 3, exit_point + Vector2(0, 0.02 if opened else 0.055) * cell, Vector2.ONE * cell * 0.96)
	for spike in level.get("hazards", []):
		_sprite(5, _point(spike) + Vector2(0, cell * 0.105), Vector2.ONE * cell * 0.97)
	var snake: Array = body_override if not body_override.is_empty() else state.get("body", level.get("body", []))
	_body(snake)
	if state.get("status", "playing") == "lost":
		for hazard in level.get("hazards", []):
			for segment in state.get("body", []):
				if Vector2(segment).distance_to(Vector2(hazard)) < 0.1:
					_danger_marker(_point(hazard))
					break
	for food in state.get("fruit", level.get("fruit", [])):
		_sprite(2, _point(food), Vector2.ONE * cell * 0.64)

func _sprite(index: int, p: Vector2, bounds: Vector2, flip: bool = false, tint: Color = Color.WHITE) -> void:
	if sprites.size() != 6:
		return
	var sprite := sprites[index]
	if index == 0 and surprised_face != null and (state.get("status", "playing") == "lost" or mood == "sad"):
		sprite = surprised_face
	var scale_factor := minf(bounds.x / sprite.get_width(), bounds.y / sprite.get_height())
	var dimensions := sprite.get_size() * scale_factor
	var rect := Rect2(p - dimensions * 0.5, dimensions)
	if flip:
		rect.size.x = -dimensions.x
	draw_texture_rect(sprite, rect, false, tint)

func _danger_marker(p: Vector2) -> void:
	# Body and hazards can legally overlap only in the final failed snapshot.
	# Four restrained corners keep the underlying dangerous cell discoverable.
	for sign_x in [-1.0, 1.0]:
		for sign_y in [-1.0, 1.0]:
			var corner := p + Vector2(sign_x, sign_y) * cell * 0.46
			var marks := PackedVector2Array([
				corner - Vector2(sign_x * cell * 0.15, 0), corner,
				corner - Vector2(0, sign_y * cell * 0.15)
			])
			draw_polyline(marks, Color(1.0, 0.92, 0.77, 0.80), maxf(2.8, cell * 0.066), true)
			draw_polyline(marks, Color("c65857"), maxf(1.4, cell * 0.035), true)

func _curve(points: PackedVector2Array) -> PackedVector2Array:
	var smooth := PackedVector2Array()
	if points.size() < 3:
		if points.size() < 2:
			return points
		for sample in range(21):
			smooth.append(points[0].lerp(points[1], float(sample) / 20.0))
		return smooth
	smooth.append(points[0])
	for i in range(1, points.size() - 1):
		var a := points[i].lerp(points[i - 1], 0.27)
		var b := points[i].lerp(points[i + 1], 0.27)
		smooth.append(a)
		for step in range(1, 7):
			var t := float(step) / 6.0
			smooth.append(a.lerp(points[i], t).lerp(points[i].lerp(b, t), t))
	smooth.append(points[-1])
	var sampled := PackedVector2Array([smooth[0]])
	for i in range(1, smooth.size()):
		var steps := maxi(1, ceili(smooth[i].distance_to(smooth[i - 1]) / (cell * 0.10)))
		for sample in range(1, steps + 1):
			sampled.append(smooth[i - 1].lerp(smooth[i], float(sample) / steps))
	return sampled

func _tube(path: PackedVector2Array, radius: float, offset: Vector2, color: Color, tail: float = 0.10) -> void:
	if path.size() < 2:
		return
	var lengths: Array[float] = [0.0]
	for i in range(1, path.size()):
		lengths.append(lengths[-1] + path[i].distance_to(path[i - 1]))
	var total := lengths[-1]
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(path.size()):
		var previous := path[maxi(0, i - 1)]
		var following := path[mini(path.size() - 1, i + 1)]
		var tangent := (following - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var tail_factor := clampf((total - lengths[i]) / (cell * 0.45), 0.0, 1.0)
		var wave := sin(lengths[i] / cell * 4.3 + 0.8) * sin(PI * clampf(lengths[i] / maxf(total, 1.0), 0.0, 1.0))
		var belly := radius < cell * 0.18
		var local_radius := lerpf(cell * tail, radius, smoothstep(0.0, 1.0, tail_factor))
		if belly:
			local_radius *= 1.0 + wave * 0.12
		var local_offset := offset * lerpf(0.1, 1.0, tail_factor)
		if belly:
			local_offset += Vector2(wave * 0.007, wave * 0.014) * cell * tail_factor
		var tail_curl := Vector2(0, -0.10 * pow(1.0 - tail_factor, 2.0)) * cell
		left.append(path[i] + local_offset + tail_curl + normal * local_radius)
		right.append(path[i] + local_offset + tail_curl - normal * local_radius)
	var polygon := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		polygon.append(right[i])
	draw_colored_polygon(polygon, color)
	_circle(path[0] + offset, radius, color)
	_circle(path[-1] + offset * 0.1 + Vector2(0, -0.10) * cell, cell * tail, color)
	# A thin antialiased edge gives the contour soft ink without dark pipe outlines.
	polygon.append(polygon[0])
	draw_polyline(polygon, color, 1.0, true)

func _body(snake: Array) -> void:
	if snake.is_empty():
		return
	var points := PackedVector2Array()
	for part in snake:
		points.append(_point(part))
	var path := _curve(points)
	if points.size() > 1:
		# Warm shaded outer contour, coral midtones, broad continuous cream underside.
		_tube(path, cell * 0.367, Vector2(0.02, 0.08) * cell, Color(0.26, 0.20, 0.14, 0.11), 0.09)
		_tube(path, cell * 0.344, Vector2.ZERO, Color("bf604b"), 0.087)
		_tube(path, cell * 0.330, Vector2(0, -0.008) * cell, Color("ef7253"), 0.074)
		for wash in range(8):
			var amount := float(wash + 1) / 8.0
			_tube(path, cell * lerpf(0.330, 0.277, amount), Vector2(-0.020 * amount, lerpf(-0.008, -0.065, amount)) * cell, Color("ef7253").lerp(Color("ff8b60"), amount), lerpf(0.074, 0.054, amount))
		_tube(path, cell * 0.123, Vector2(0.035, 0.186) * cell, Color("ffd9a2"), 0.028)
		_tube(path, cell * 0.108, Vector2(0.044, 0.197) * cell, Color("ffe5b8"), 0.024)
		_tube(path, cell * 0.036, Vector2(-0.046, -0.196) * cell, Color(1, 0.75, 0.54, 0.15), 0.010)
		# Organic freckle groups break the flat fill without repeating a mechanical stripe.
		for i in range(1, points.size()):
			var p := points[i].lerp(points[i - 1], 0.38) if i == points.size() - 1 else points[i]
			var f := float(i)
			var small := 0.76 if i == points.size() - 1 else 1.0
			_oval(p + Vector2(-0.075 + sin(f * 2.1) * 0.045, -0.10) * cell, Vector2(0.065, 0.032) * cell * small, Color("ee805f"), -0.42 + sin(f) * 0.35)
			_oval(p + Vector2(0.10, -0.045) * cell, Vector2(0.036, 0.061) * cell * small, Color("ed805f"), 0.25)
			_oval(p + Vector2(0.06, 0.21) * cell, Vector2(0.041, 0.025) * cell * small, Color("f49b76"), -0.15)
			# Translucent irregular glaze flecks lend the procedural linking surface
			# some of the watercolor variation present in the painted head sprite.
			for fleck in range(9):
				var seed_value := f * 13.7 + float(fleck) * 5.17
				var center := p + Vector2(sin(seed_value) * 0.22, -0.10 + cos(seed_value * 1.31) * 0.13) * cell * small
				var radius := Vector2(0.023 + absf(sin(seed_value * 0.7)) * 0.033, 0.014 + absf(cos(seed_value)) * 0.020) * cell * small
				_oval(center, radius, Color(1.0, 0.75, 0.50, 0.28), seed_value)
	var direction := Vector2.RIGHT
	if points.size() > 1:
		direction = (points[0] - points[1]).normalized()
	# Keep expressive paired eyes upright. Horizontal mirror signals facing direction;
	# vertical intent is supplied by the neck rather than rotating the face sideways.
	_sprite(0, points[0] + Vector2(0, -0.12) * cell, Vector2(1.05, 1.20) * cell, direction.x < -0.2)

func _oval(p: Vector2, dimensions: Vector2, color: Color, rotation: float) -> void:
	var polygon := PackedVector2Array()
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		polygon.append(p + Vector2(cos(a) * dimensions.x, sin(a) * dimensions.y).rotated(rotation))
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, color, 0.6, true)
