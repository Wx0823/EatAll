extends Node
## Opt-in debug probe. Enabled only by user://qa/frame-probe.enabled.
## Logs actual process/present counters; no production HUD or player data.
var game: Control
var seconds := 0.0
var frames := 0
var max_delta := 0.0
var draw_ms_total := 0.0
var draw_samples := 0
var last_board: Control
var last_draw_count := 0
var presents := 0
var moving_frames := 0

func _ready() -> void:
	presents = Engine.get_frames_drawn()
	print("EATALL_FRAME_PROBE enabled (opt-in debug)")

func _process(delta: float) -> void:
	seconds += delta
	frames += 1
	max_delta = maxf(max_delta, delta)
	if game.busy: moving_frames += 1
	if is_instance_valid(game.board):
		if last_board != game.board:
			last_board = game.board
			last_draw_count = 0
		if game.board.draw_calls_total != last_draw_count:
			last_draw_count = game.board.draw_calls_total
			draw_ms_total += game.board.draw_time_us / 1000.0
			draw_samples += 1
	if seconds >= 2.0:
		var current_presents := Engine.get_frames_drawn()
		print("EATALL_FRAME_PROBE process_hz=%.1f presents_hz=%.1f max_delta_ms=%.1f board_draw_ms=%.2f draws=%d moving_frames=%d" % [frames/seconds,(current_presents-presents)/seconds,max_delta*1000.0,draw_ms_total/maxi(draw_samples,1),draw_samples,moving_frames])
		if is_instance_valid(game.board) and draw_samples > 0:
			print("EATALL_DRAW_SECTIONS dynamic_us=", game.board.draw_sections_us, " static_us=", game.board.static_draw_sections_us, " static_total_us=", game.board.static_draw_time_us)
		presents = current_presents
		seconds = 0.0
		frames = 0
		max_delta = 0.0
		draw_ms_total = 0.0
		draw_samples = 0
		moving_frames = 0
