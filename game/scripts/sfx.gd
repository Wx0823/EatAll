extends Node
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var sounds: Dictionary = {}

func _ready() -> void:
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -16
		add_child(player)
		voices.append(player)
	for name in ["move", "eat", "undo", "lost", "won", "tap"]:
		sounds[name] = _make(name)

func _make(kind: String) -> AudioStreamWAV:
	var duration := 0.09
	var base := 390.0
	match kind:
		"eat": base = 640; duration = 0.18
		"undo": base = 430; duration = 0.15
		"lost": base = 240; duration = 0.27
		"won": base = 520; duration = 0.50
		"tap": base = 480; duration = 0.07
	var bytes := PackedByteArray()
	var rate := 22050
	var count := int(duration * rate)
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var freq := base
		if kind == "eat": freq *= 1.0 + t * 3.5
		if kind == "undo" or kind == "lost": freq *= 1.0 - t * 1.8
		if kind == "won": freq *= [1.0, 1.25, 1.5, 2.0][mini(int(t * 8), 3)]
		phase += TAU * freq / rate
		var envelope := minf(t * 120, 1.0) * pow(1.0 - float(i) / count, 1.8)
		bytes.encode_s16(i * 2, int(sin(phase) * envelope * 12000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func play(kind: String) -> void:
	if not enabled or voices.is_empty() or not sounds.has(kind):
		return
	var player := voices[next_voice % voices.size()]
	next_voice += 1
	player.stream = sounds[kind]
	player.play()
