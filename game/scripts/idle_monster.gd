extends Control
## Lobby-only idle. The gameplay renderer and movement clock remain independent.
const MONSTER = preload("res://assets/art-v2/home-monster.png")
var idle_time := 0.0
var hop_time := 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hop_time = 0.0
		accept_event()

func _process(delta: float) -> void:
	idle_time += minf(delta, 0.05)
	hop_time += delta
	queue_redraw()

func _draw() -> void:
	var breathe := sin(idle_time * TAU / 3.6)
	var hop := sin(minf(hop_time / 0.6, 1.0) * PI) * 25.0 if hop_time < 0.6 else 0.0
	var scale_factor := minf(size.x * 0.94 / MONSTER.get_width(), size.y * 0.86 / MONSTER.get_height())
	var image_size := MONSTER.get_size() * scale_factor * Vector2(1.0-breathe*0.008, 1.0+breathe*0.014)
	var base := Vector2(size.x*0.5, size.y*0.86)
	draw_set_transform(Vector2(base.x, base.y+4), 0.0, Vector2(1, 0.16))
	draw_circle(Vector2.ZERO, image_size.x*0.35-hop*0.3, Color(0.19,0.30,0.11,0.13))
	draw_set_transform(Vector2.ZERO)
	var pos := Vector2((size.x-image_size.x)*0.5 + sin(idle_time*0.9)*2.0, base.y-image_size.y-hop)
	draw_texture_rect(MONSTER, Rect2(pos, image_size), false)
	for i in 5:
		var phase := idle_time*0.5 + i*1.7
		var point := Vector2(size.x*(0.12+i*0.19)+sin(phase)*7, size.y*(0.30+fmod(i*0.17,0.45))+cos(phase)*9)
		draw_circle(point, 1.6, Color(1.0,0.96,0.66,0.22+0.18*sin(phase)))
