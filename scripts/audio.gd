extends Node
## Small synthesized one-shots: no external media or runtime downloads.

var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = DisplayServer.get_name() == "headless"
	var recipes := {
		"swing": [430.0, 110.0, 0.12, 0.3],
		"hit": [160.0, 45.0, 0.14, 0.65],
		"hurt": [220.0, 60.0, 0.24, 0.35],
		"jump": [210.0, 620.0, 0.12, 0.0],
		"spell": [680.0, 120.0, 0.32, 0.22],
		"heal": [360.0, 900.0, 0.45, 0.0],
		"slam": [85.0, 22.0, 0.35, 0.65],
		"select": [420.0, 680.0, 0.09, 0.0],
		"phase": [110.0, 320.0, 0.8, 0.25],
		"win": [430.0, 860.0, 0.65, 0.0],
	}
	for key in recipes:
		sounds[key] = synthesize(recipes[key])
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)

func play(key: String) -> void:
	if muted or not sounds.has(key) or voices.is_empty():
		return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = sounds[key]
	voice.play()

func toggle_mute() -> bool:
	muted = not muted
	if muted:
		for voice in voices:
			voice.stop()
	return muted

func synthesize(recipe: Array) -> AudioStreamWAV:
	var rate := 22050
	var count := int(recipe[2] * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in count:
		var t := float(i) / count
		var frequency := lerpf(recipe[0], recipe[1], t)
		phase += TAU * frequency / rate
		var envelope := minf(t * 45.0, 1.0) * pow(1.0 - t, 2.0)
		var sample: float = (sin(phase) * (1.0 - recipe[3]) + rng.randf_range(-1, 1) * recipe[3]) * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 23000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
