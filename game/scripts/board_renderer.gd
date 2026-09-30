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
var motion_active: bool = false
var facing_direction: Vector2i = Vector2i.ZERO
var _reaction_time: Dictionary = {}
var _particles: Array[Dictionary] = []
var _motion_clock: float = 0.0
var _native_sweep := PackedVector2Array()
var _native_tip := Vector2.ZERO
var _freckle_stamps: Array[AtlasTexture] = []
var _stamp_viewport: SubViewport
var _stamp_output: SubViewport
var mouth_animation: String = "idle"
var mouth_openness: float = 0.0
var _mouth_age: float = 0.0
var _mouth_start_openness: float = 0.0
var _food_source_grid: Vector2 = Vector2.INF
var _mouth_frames: Array[AtlasTexture] = []
var _head_heading: float = 0.0
var _face_flip: bool = false
var _mouth_world: Vector2 = Vector2.ZERO
var draw_calls_total: int = 0
var draw_time_us: int = 0
var draw_sections_us: Dictionary = {}
var static_draw_sections_us: Dictionary = {}
var static_draw_calls_total: int = 0
var static_draw_time_us: int = 0
var _static_painter: Node2D
var _static_dirty: bool = true
var _static_cell: float = -1.0
var _static_origin: Vector2 = Vector2.INF
var _static_exit_open: bool = false
var _body_ribbon: ArrayMesh = ArrayMesh.new()
var _ribbon_path := PackedVector2Array()
var _ribbon_cell: float = -1.0
var _ribbon_eat: float = -1.0
var _grid_mesh: ArrayMesh = ArrayMesh.new()
var _grid_key: Array = []
static var _dot_texture: GradientTexture2D
static var _shared_freckles: Texture2D
const REACTION_LENGTH := {"move":0.16, "eat":0.72, "fall":0.65, "land":0.34, "blocked":0.24, "lost":0.65, "won":1.05}
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
	if level != new_level:
		_static_dirty = true
	level = new_level
	state = new_state
	queue_redraw()

func react(kind: String, direction: Vector2i = Vector2i.ZERO) -> void:
	if not REACTION_LENGTH.has(kind):
		return
	_reaction_time[kind] = 0.0
	if direction != Vector2i.ZERO:
		facing_direction = direction
	if kind == "eat":
		mouth_animation = "swallow"
		_mouth_age = 0.0
		mouth_openness = 1.0
	if kind == "land" or kind == "lost" or kind == "won":
		_reaction_time.erase("fall")
	if kind in ["eat", "land", "won", "lost"]:
		_emit_particles(kind)
	queue_redraw()

func anticipate_food(direction: Vector2i, food_cell: Vector2 = Vector2.INF) -> void:
	facing_direction = direction
	_food_source_grid = food_cell
	if not _food_source_grid.is_finite():
		var body: Array = body_override if not body_override.is_empty() else state.get("body", [])
		if not body.is_empty():
			_food_source_grid = Vector2(body[0]) + Vector2(direction)
	_mouth_start_openness = mouth_openness
	_mouth_age = 0.0
	mouth_animation = "opening"
	queue_redraw()

func clear_reactions() -> void:
	_reaction_time.clear()
	_particles.clear()
	_motion_clock = 0.0
	motion_active = false
	facing_direction = Vector2i.ZERO
	mouth_animation = "idle"
	mouth_openness = 0.0
	_mouth_age = 0.0
	_food_source_grid = Vector2.INF
	_face_flip = false
	_head_heading = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var changed := motion_active or not _reaction_time.is_empty() or not _particles.is_empty() or mouth_animation != "idle"
	_update_mouth(delta)
	if motion_active:
		_motion_clock += delta
	for kind in _reaction_time.keys():
		_reaction_time[kind] += delta
		if _reaction_time[kind] >= REACTION_LENGTH[kind]:
			_reaction_time.erase(kind)
	for index in range(_particles.size() - 1, -1, -1):
		_particles[index].age += delta
		if _particles[index].age >= _particles[index].life:
			_particles.remove_at(index)
	if changed:
		queue_redraw()

func _update_mouth(delta: float) -> void:
	if mouth_animation == "idle":
		return
	_mouth_age += delta
	if mouth_animation == "opening":
		mouth_openness = lerpf(_mouth_start_openness, 1.0, smoothstep(0.0, 0.10, _mouth_age))
		if _mouth_age >= 0.10:
			mouth_animation = "holding"
	elif mouth_animation == "holding":
		mouth_openness = 1.0
		# A cancelled integration must never leave the character stuck open.
		if _mouth_age > 0.45:
			mouth_animation = "idle"
			mouth_openness = 0.0
	elif mouth_animation == "swallow":
		mouth_openness = 1.0 - smoothstep(0.075, 0.175, _mouth_age)
		if _mouth_age >= 0.175:
			mouth_animation = "chew"
			_mouth_age = 0.0
	elif mouth_animation == "chew":
		mouth_openness = absf(sin(_mouth_age / 0.22 * TAU)) * 0.28 * (1.0 - clampf(_mouth_age / 0.22, 0.0, 1.0))
		if _mouth_age >= 0.22:
			mouth_animation = "idle"
			mouth_openness = 0.0
			_food_source_grid = Vector2.INF

func _reaction(kind: String) -> float:
	if not _reaction_time.has(kind):
		return 0.0
	return 1.0 - float(_reaction_time[kind]) / float(REACTION_LENGTH[kind])

func _emit_particles(kind: String) -> void:
	var body: Array = body_override if not body_override.is_empty() else state.get("body", [])
	if body.is_empty():
		return
	var center := Vector2(body[0]) + Vector2(0.5, 0.04)
	if kind == "eat":
		center = Vector2(body[0]) + Vector2(0.28 if facing_direction.x < 0 else 0.72, 0.53)
	elif kind == "land":
		center = Vector2(body[0]) + Vector2(0.5, 0.87)
		for segment in body:
			if level.get("terrain", []).has(Vector2i(segment) + Vector2i.DOWN):
				center = Vector2(segment) + Vector2(0.5, 0.87)
				break
	var count := 12 if kind == "won" else 6
	for index in range(count):
		var phase := float(index) / count
		var velocity := Vector2(cos(phase * TAU) * 0.9, -1.0 - absf(sin(phase * 9.0)) * 1.2)
		var color := Color("ffe8b5")
		if kind == "won":
			color = [Color("ffe8b5"), Color("ef8b69"), Color("8ead73")][index % 3]
			velocity *= 1.4
		elif kind == "lost":
			color = Color("aa7292")
		elif kind == "land":
			velocity *= 0.5
		_particles.append({"center":center,"velocity":velocity,"color":color,"age":0.0,"life":0.9 if kind == "won" else 0.48,"spin":phase * TAU,"kind":kind})
	while _particles.size() > 32:
		_particles.pop_front()

func _draw_particles() -> void:
	for particle in _particles:
		var age: float = particle.age
		var position_grid: Vector2 = particle.center + particle.velocity * age + Vector2(0, age * age * 2.1)
		var color: Color = particle.color
		color.a = minf(1.0, (float(particle.life) - age) * 6.0)
		var p := origin + position_grid * cell
		if particle.kind == "won" or particle.kind == "lost":
			var radius := cell * (0.045 if particle.kind == "won" else 0.035)
			var star := PackedVector2Array()
			for tip in range(8):
				var angle := float(tip) * PI / 4.0 + float(particle.spin) + age * 3.0
				star.append(p + Vector2(cos(angle), sin(angle)) * radius * (1.0 if tip % 2 == 0 else 0.35))
			draw_colored_polygon(star, color)
		else:
			var extent := Vector2.ONE * cell * 0.054
			draw_texture_rect(_dot_texture,Rect2(p-extent*0.5,extent),false,color)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	_load_sprites()
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.68,1.0])
		gradient.colors = PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)])
		_dot_texture = GradientTexture2D.new()
		_dot_texture.width = 16
		_dot_texture.height = 16
		_dot_texture.fill = GradientTexture2D.FILL_RADIAL
		_dot_texture.fill_from = Vector2(0.5,0.5)
		_dot_texture.fill_to = Vector2(1.0,0.5)
		_dot_texture.gradient = gradient
	_make_freckle_stamps()
	_static_painter = Node2D.new()
	_static_painter.show_behind_parent = true
	add_child(_static_painter)
	_static_painter.draw.connect(_paint_static)

func _make_freckle_stamps() -> void:
	if _shared_freckles != null:
		_bind_freckle_stamps(_shared_freckles)
		return
	_stamp_viewport = SubViewport.new()
	_stamp_viewport.size = Vector2i(1024, 256)
	_stamp_viewport.transparent_bg = true
	_stamp_viewport.disable_3d = true
	_stamp_viewport.gui_disable_input = true
	_stamp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stamp_viewport)
	var painter := Node2D.new()
	_stamp_viewport.add_child(painter)
	painter.draw.connect(func(): _paint_freckle_sheet(painter))
	# Viewport targets contain premultiplied alpha. Convert once on the GPU so
	# ordinary texture draws do not multiply soft freckles a second time.
	_stamp_output = SubViewport.new()
	_stamp_output.size = _stamp_viewport.size
	_stamp_output.transparent_bg = true
	_stamp_output.disable_3d = true
	_stamp_output.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stamp_output)
	var copy := Sprite2D.new()
	copy.centered = false
	copy.texture = _stamp_viewport.get_texture()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode blend_disabled; void fragment(){vec4 c=texture(TEXTURE,UV); COLOR=vec4(c.rgb/max(c.a,0.001),c.a);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	copy.material = material
	_stamp_output.add_child(copy)
	_bind_freckle_stamps(_stamp_output.get_texture())
	_finish_freckle_bake()

func _bind_freckle_stamps(texture: Texture2D) -> void:
	_freckle_stamps.clear()
	for index in range(16):
		var stamp := AtlasTexture.new()
		stamp.atlas = texture
		stamp.region = Rect2((index % 8) * 128, (index / 8) * 128, 128, 128)
		stamp.filter_clip = true
		_freckle_stamps.append(stamp)

func _finish_freckle_bake() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	# One first-entry readback; subsequent levels reuse the finished texture.
	var baked := _stamp_output.get_texture().get_image()
	_shared_freckles = ImageTexture.create_from_image(baked)
	_bind_freckle_stamps(_shared_freckles)
	_stamp_output.queue_free()
	_stamp_viewport.queue_free()
	queue_redraw()

func _paint_freckle_sheet(painter: Node2D) -> void:
	for index in range(16):
		var f := float(index + 1)
		var p := Vector2((index % 8) * 128 + 64, (index / 8) * 128 + 64)
		_stamp_oval(painter, p + Vector2(-0.075 + sin(f * 2.1) * 0.045, -0.10) * 128, Vector2(0.065, 0.032) * 128, Color("ee805f"), -0.42 + sin(f) * 0.35)
		_stamp_oval(painter, p + Vector2(0.10, -0.045) * 128, Vector2(0.036, 0.061) * 128, Color("ed805f"), 0.25)
		_stamp_oval(painter, p + Vector2(0.06, 0.21) * 128, Vector2(0.041, 0.025) * 128, Color("f49b76"), -0.15)
		for fleck in range(9):
			var seed_value := f * 13.7 + float(fleck) * 5.17
			var center := p + Vector2(sin(seed_value) * 0.22, -0.10 + cos(seed_value * 1.31) * 0.13) * 128
			var radius := Vector2(0.023 + absf(sin(seed_value * 0.7)) * 0.033, 0.014 + absf(cos(seed_value)) * 0.020) * 128
			_stamp_oval(painter, center, radius, Color(1.0, 0.75, 0.50, 0.28), seed_value)

func _stamp_oval(painter: Node2D, p: Vector2, dimensions: Vector2, color: Color, rotation: float) -> void:
	var radius := minf(dimensions.x, dimensions.y)
	painter.draw_set_transform(p, rotation, dimensions / radius)
	painter.draw_circle(Vector2.ZERO, radius, color, true, -1.0, true)
	painter.draw_set_transform(Vector2.ZERO)

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
	if ResourceLoader.exists("res://assets/art-v4/mouth-atlas.png"):
		var mouths := load("res://assets/art-v4/mouth-atlas.png") as Texture2D
		for frame in range(3):
			var texture := AtlasTexture.new()
			texture.atlas = mouths
			# One shared crop, not independent used_rect normalization: eyes stay registered.
			texture.region = Rect2(frame * 724 + 70, 16, 638, 683)
			texture.filter_clip = true
			_mouth_frames.append(texture)

func _point(p: Variant) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell

func _draw() -> void:
	var draw_started := Time.get_ticks_usec()




	if level.is_empty():
		return
	var columns := int(level.get("width", 9))
	var rows := int(level.get("height", 12))
	cell = minf((size.x - 16.0) / maxf(columns, 1), (size.y - 16.0) / maxf(rows, 1))
	if cell <= 0.0:
		return
	origin = (size - Vector2(columns, rows) * cell) * 0.5
	var section_started := Time.get_ticks_usec()
	var opened: bool = state.get("fruit", level.get("fruit", [])).is_empty()
	if _static_dirty or not is_equal_approx(_static_cell, cell) or _static_origin != origin or _static_exit_open != opened:
		_static_cell = cell
		_static_origin = origin
		_static_exit_open = opened
		_static_dirty = false
		_static_painter.queue_redraw()
	draw_sections_us["static_submit"] = Time.get_ticks_usec() - section_started
	section_started = Time.get_ticks_usec()
	var snake: Array = body_override if not body_override.is_empty() else state.get("body", level.get("body", []))
	_body(snake)
	draw_sections_us["body"] = Time.get_ticks_usec() - section_started
	section_started = Time.get_ticks_usec()
	if state.get("status", "playing") == "lost":
		for hazard in level.get("hazards", []):
			for segment in state.get("body", []):
				if Vector2(segment).distance_to(Vector2(hazard)) < 0.1:
					_danger_marker(_point(hazard))
					break
	for food in state.get("fruit", level.get("fruit", [])):
		_sprite(2, _point(food), Vector2.ONE * cell * 0.64)
	_draw_swallowed_food()
	draw_sections_us["food_hazards"] = Time.get_ticks_usec() - section_started
	section_started = Time.get_ticks_usec()
	_draw_particles()
	draw_sections_us["particles"] = Time.get_ticks_usec() - section_started
	draw_calls_total += 1
	draw_time_us = Time.get_ticks_usec() - draw_started

func _paint_static() -> void:
	if level.is_empty():
		return
	var begun := Time.get_ticks_usec()
	var t := begun
	_draw_static_grid()
	static_draw_sections_us["grid"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	for tile in level.get("terrain", []):
		_static_sprite(1, _point(tile), Vector2.ONE * cell)
	static_draw_sections_us["terrain"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	if level.has("exit"):
		var p := _point(level.exit)
		if _static_exit_open:
			_static_painter.draw_texture_rect(_dot_texture,Rect2(p+Vector2(-0.42,-0.32)*cell,Vector2.ONE*cell*0.84),false,Color(1,0.94,0.57,0.12))
		_static_sprite(4 if _static_exit_open else 3,p + Vector2(0,0.02 if _static_exit_open else 0.055)*cell,Vector2.ONE*cell*0.96)
	static_draw_sections_us["exit"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	for spike in level.get("hazards", []):
		_static_sprite(5, _point(spike) + Vector2(0,0.105)*cell,Vector2.ONE*cell*0.97)
	static_draw_sections_us["hazards"] = Time.get_ticks_usec() - t
	static_draw_time_us = Time.get_ticks_usec() - begun
	static_draw_calls_total += 1

func _draw_static_grid() -> void:
	var key := [level.get("width",9),level.get("height",12),cell,origin]
	if key != _grid_key:
		_grid_key = key
		var vertices := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		var radius := maxf(0.6,cell*0.014)
		for y in range(int(key[1])):
			for x in range(int(key[0])):
				var center := _point(Vector2i(x,y))
				var start := vertices.size()
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					var point: Vector2 = center+corner*radius
					vertices.append(Vector3(point.x,point.y,0))
					uv.append((corner+Vector2.ONE)*0.5)
				indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_INDEX]=indices
		_grid_mesh.clear_surfaces()
		_grid_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_static_painter.draw_mesh(_grid_mesh,_dot_texture,Transform2D.IDENTITY,Color(0.30,0.40,0.23,0.12))

func _static_sprite(index: int,p:Vector2,bounds:Vector2) -> void:
	if sprites.size() != 6:
		return
	var sprite := sprites[index]
	var dimensions := sprite.region.size
	var extent := dimensions * minf(bounds.x / dimensions.x,bounds.y / dimensions.y)
	_static_painter.draw_texture_rect(sprite,Rect2(p-extent*0.5,extent),false)

func _draw_body_ribbon(path: PackedVector2Array) -> void:
	var started := Time.get_ticks_usec()
	var eat_age := float(_reaction_time.get("eat",-1.0))
	if path != _ribbon_path or not is_equal_approx(cell,_ribbon_cell) or not is_equal_approx(eat_age,_ribbon_eat):
		_ribbon_path = path
		_ribbon_cell = cell
		_ribbon_eat = eat_age
		var centers := _native_sweep.duplicate()
		var tail_start := centers[-1]
		var tail_begin := centers.size()-1
		for step in range(1,5):
			var t := float(step)/4.0
			centers.append(tail_start.lerp(_native_tip,t) + Vector2(0,-0.10*t*t)*cell)
		var tip_direction := (centers[-1]-centers[-2]).normalized()
		centers.append(centers[-1]+tip_direction*cell*0.045)
		var widths: Array[float] = [-1.045,-1.0,-0.94,-0.62,0.21,0.34,0.82,0.95,1.0,1.045]
		var colors: Array[Color] = [Color(0.75,0.38,0.29,0),Color("bf604b"),Color("ef7253"),Color("ff8b60"),Color("ff9669"),Color("ffdda9"),Color("ffe5b8"),Color("eeb780"),Color("bf604b"),Color(0.75,0.38,0.29,0)]
		var vertices := PackedVector3Array()
		var vertex_colors := PackedColorArray()
		var indices := PackedInt32Array()
		var total_length := 0.0
		var first_tangent := (centers[1]-centers[0]).normalized()
		var first_normal := Vector2(-first_tangent.y,first_tangent.x)
		var side := -1.0 if first_normal.x + first_normal.y < 0 else 1.0
		for i in range(centers.size()):
			if i > 0:
				total_length += centers[i].distance_to(centers[i-1])
			var tangent := (centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized()
			var normal := Vector2(-tangent.y,tangent.x)*side
			var radius := cell * 0.344
			if i > tail_begin:
				var taper := minf(1.0,float(i-tail_begin)/4.0)
				radius = cell*lerpf(0.344,0.045,smoothstep(0.0,1.0,taper))
			if i == centers.size()-1:
				radius = cell*0.003
			if eat_age >= 0:
				var distance_from_wave := total_length/cell-eat_age*8.0
				radius *= 1.0 + exp(-distance_from_wave*distance_from_wave*6.0)*0.045*_reaction("eat")
			for lane in range(widths.size()):
				var vertex := centers[i]+normal*radius*widths[lane]
				vertices.append(Vector3(vertex.x,vertex.y,0))
				vertex_colors.append(colors[lane])
				if i > 0 and lane > 0:
					var a := (i-1)*widths.size()+lane-1
					var b := i*widths.size()+lane-1
					indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_COLOR]=vertex_colors
		arrays[Mesh.ARRAY_INDEX]=indices
		_body_ribbon.clear_surfaces()
		_body_ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	draw_sections_us["body_geometry"] = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	draw_mesh(_body_ribbon,null)
	draw_sections_us["body_submit"] = Time.get_ticks_usec()-started

func _draw_swallowed_food() -> void:
	if mouth_animation != "swallow" or not _food_source_grid.is_finite() or _mouth_age >= 0.095:
		return
	var t := smoothstep(0.0, 0.095, _mouth_age)
	var center := _point(_food_source_grid).lerp(_mouth_world, t)
	var extent := cell * lerpf(0.64, 0.015, t)
	_sprite(2, center, Vector2.ONE * extent)

func _sprite(index: int, p: Vector2, bounds: Vector2, flip: bool = false, tint: Color = Color.WHITE) -> void:
	if sprites.size() != 6:
		return
	var sprite := sprites[index]
	var surprised: bool = index == 0 and surprised_face != null and (state.get("status", "playing") == "lost" or mood == "sad" or (mouth_animation == "idle" and (_reaction("fall") > 0.0 or _reaction("blocked") > 0.0)))
	var mouth_frame := 0.0
	if index == 0 and _mouth_frames.size() == 3 and not surprised:
		mouth_frame = clampf(mouth_openness * 2.0, 0.0, 2.0)
		sprite = _mouth_frames[int(floor(mouth_frame))]
	if surprised:
		sprite = surprised_face
	var scale_factor := minf(bounds.x / sprite.get_width(), bounds.y / sprite.get_height())
	var dimensions := sprite.get_size() * scale_factor
	var rect := Rect2(p - dimensions * 0.5, dimensions)
	if flip:
		rect.size.x = -dimensions.x
	if index == 0:
		var pose := _head_pose()
		var angle: float = _head_heading + pose.angle
		draw_set_transform(p + pose.offset * cell, angle, pose.scale)
		var anchor := Vector2(-0.08 if flip else 0.08, 0.34) * cell
		_mouth_world = p + pose.offset * cell + (anchor * pose.scale).rotated(angle)
		rect.position -= p
	draw_texture_rect(sprite, rect, false, tint)
	if index == 0 and not surprised and _mouth_frames.size() == 3 and mouth_frame < 2.0:
		var blend: float = mouth_frame - floor(mouth_frame)
		if blend > 0.001:
			draw_texture_rect(_mouth_frames[int(floor(mouth_frame)) + 1], rect, false, Color(1, 1, 1, blend))
	if index == 0:
		draw_set_transform(Vector2.ZERO)

func _head_pose() -> Dictionary:
	var stretch := Vector2.ONE
	var angle := 0.0
	var offset := Vector2.ZERO
	var move := _reaction("move")
	if motion_active:
		angle += sin(_motion_clock * 18.0) * 0.024
	stretch += Vector2(0.065, -0.050) * sin(move * PI)
	angle += float(facing_direction.x) * sin(move * PI) * 0.045
	var eat := _reaction("eat")
	if eat > 0:
		# Mouth frames perform the chewing; this is only a small secondary nod.
		angle += sin((1.0 - eat) * TAU * 2.0) * eat * 0.018
	var fall := _reaction("fall")
	stretch += Vector2(-0.040, 0.055) * minf(fall * 3.0, 1.0)
	var land := _reaction("land")
	var spring := sin((1.0 - land) * TAU * 1.5) * land
	stretch += Vector2(0.105, -0.085) * spring
	offset.y += spring * 0.018
	var blocked := _reaction("blocked")
	offset.x += sin((1.0 - blocked) * TAU * 2.0) * blocked * 0.036
	angle += sin((1.0 - blocked) * TAU * 2.0) * blocked * 0.065
	var won := _reaction("won")
	angle += sin((1.0 - won) * TAU * 2.0) * won * 0.09
	offset.y -= absf(sin((1.0 - won) * TAU * 2.0)) * won * 0.045
	var lost := _reaction("lost")
	angle += sin((1.0 - lost) * TAU * 2.5) * lost * 0.055
	stretch = stretch.clamp(Vector2(0.89, 0.89), Vector2(1.12, 1.12))
	return {"scale":stretch,"angle":angle,"offset":offset}

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
	var distinct := PackedVector2Array()
	for point in points:
		if distinct.is_empty() or point.distance_squared_to(distinct[-1]) > 0.0001:
			distinct.append(point)
	if distinct.size() < 3:
		return distinct
	var smooth := PackedVector2Array([distinct[0]])
	for i in range(1, distinct.size() - 1):
		var incoming := (distinct[i] - distinct[i - 1]).normalized()
		var outgoing := (distinct[i + 1] - distinct[i]).normalized()
		if absf(incoming.cross(outgoing)) < 0.005 and incoming.dot(outgoing) > 0.99:
			continue
		var a := distinct[i].lerp(distinct[i - 1], 0.27)
		var b := distinct[i].lerp(distinct[i + 1], 0.27)
		smooth.append(a)
		for step in range(1, 5):
			var t := float(step) / 4.0
			smooth.append(a.lerp(distinct[i], t).lerp(distinct[i].lerp(b, t), t))
	smooth.append(distinct[-1])
	return smooth

func _prepare_native_sweep(path: PackedVector2Array) -> void:
	_native_sweep = path.duplicate()
	if path.size() < 2:
		return
	_native_tip = path[-1]
	var remaining := cell * 0.45
	while _native_sweep.size() > 1:
		var end := _native_sweep[-1]
		var start := _native_sweep[-2]
		var length := start.distance_to(end)
		if length > remaining:
			_native_sweep[-1] = end.lerp(start, remaining / length)
			break
		remaining -= length
		_native_sweep.remove_at(_native_sweep.size() - 1)

func _body(snake: Array) -> void:
	if snake.is_empty():
		return
	var points := PackedVector2Array()
	for part in snake:
		points.append(_point(part))
	var path := _curve(points)
	_prepare_native_sweep(path)
	if path.size() > 1:
		_draw_body_ribbon(path)
		var spots_started := Time.get_ticks_usec()
		# The original twelve freckles/glaze dabs are baked once into each stamp.
		# One texture call per body cell replaces hundreds of per-frame script calls.
		for i in range(1, points.size()):
			var p := points[i].lerp(points[i - 1], 0.38) if i == points.size() - 1 else points[i]
			var small := 0.76 if i == points.size() - 1 else 1.0
			if not _freckle_stamps.is_empty():
				var extent := Vector2.ONE * cell * small
				draw_texture_rect(_freckle_stamps[(i - 1) % _freckle_stamps.size()], Rect2(p - extent * 0.5, extent), false)
		draw_sections_us["body_spots"] = Time.get_ticks_usec()-spots_started
	var head_started := Time.get_ticks_usec()
	var direction := Vector2.RIGHT
	if points.size() > 1:
		direction = (points[0] - points[1]).normalized()
	if points.size() < 2 and facing_direction != Vector2i.ZERO:
		direction = Vector2(facing_direction)
	if absf(direction.x) > 0.04:
		_face_flip = direction.x < 0.0
	_head_heading = wrapf(direction.angle() - (PI if _face_flip else 0.0), -PI, PI)
	# Head and mouth follow the continuous rendered neck tangent, including UP/DOWN.
	_sprite(0, points[0] + Vector2(0, -0.12).rotated(_head_heading) * cell, Vector2(1.05, 1.20) * cell, _face_flip)
	draw_sections_us["body_head"] = Time.get_ticks_usec()-head_started
