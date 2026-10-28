class_name CleanSfx
extends Node
## Alle Geräusche werden beim Start per Code erzeugt – es braucht keine Audiodateien.
## Später kann man sie einfach gegen echte Aufnahmen tauschen.

const RATE := 22050

var _swish: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _book: AudioStreamPlayer
var _coin: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _upgrade: AudioStreamPlayer
var _deny: AudioStreamPlayer
var _swish_level := 0.0
var _swish_target := 0.0
var _hum_level := 0.0
var _hum_target := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_swish = _player(_make_swish_loop(), -80.0)
	_swish.play()
	_hum = _player(_make_hum_loop(), -80.0)
	_hum.play()
	_book = _player(_make_tones([783.99, 987.77, 1174.66, 1567.98, 1975.53], 0.08, 0.6, 0.5), -6.0)
	_coin = _player(_make_tones([1568.0, 2093.0], 0.045, 0.16, 0.5), -14.0)
	_coin.max_polyphony = 4
	_jingle = _player(_make_tones([523.25, 659.25, 783.99, 1046.5], 0.11, 0.45, 0.6), -8.0)
	_upgrade = _player(_make_sweep(280.0, 1150.0, 0.45), -10.0)
	_deny = _player(_make_tones([233.0, 196.0], 0.09, 0.14, 0.5), -12.0)


## Putzgeräusch: Wedel rauscht nur, wenn er Staub erwischt.
## Der Sauger brummt, solange die Taste gedrückt ist, und wird lauter, wenn er Staub einsaugt.
func set_cleaning(held: bool, hitting_dust: bool, suck: bool) -> void:
	if suck:
		_swish_target = 0.0
		_hum_target = (0.6 if held else 0.0) + (0.4 if hitting_dust else 0.0)
	else:
		_hum_target = 0.0
		_swish_target = 1.0 if hitting_dust else 0.0


func found_collectible() -> void:
	_book.play()


func coin() -> void:
	_coin.pitch_scale = _rng.randf_range(0.94, 1.08)
	_coin.play()


func jingle() -> void:
	_jingle.play()


func upgrade() -> void:
	_upgrade.play()


func deny() -> void:
	_deny.play()


func _process(delta: float) -> void:
	_swish_level = move_toward(_swish_level, _swish_target, delta * (8.0 if _swish_target > _swish_level else 4.0))
	_swish.volume_db = linear_to_db(maxf(_swish_level * 0.55, 0.0001))
	_hum_level = move_toward(_hum_level, _hum_target, delta * 5.0)
	_hum.volume_db = linear_to_db(maxf(_hum_level * 0.35, 0.0001))
	_hum.pitch_scale = 0.9 + _hum_level * 0.15


func _player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# ---------------------------------------------------------------- Klangerzeugung

## Rauschen im Bereich eines Federwedels, in Strichen an- und abschwellend. Eine Sekunde, nahtlos geloopt.
func _make_swish_loop() -> AudioStreamWAV:
	var n := RATE
	var samples := PackedFloat32Array()
	samples.resize(n)
	var fast := 0.0
	var slow := 0.0
	for i in n:
		var white := _rng.randf_range(-1.0, 1.0)
		fast += (white - fast) * 0.35
		slow += (fast - slow) * 0.03
		var t := float(i) / RATE
		var strokes := 0.3 + 0.7 * pow(absf(sin(PI * 4.0 * t)), 2.0)
		samples[i] = (fast - slow) * strokes * 1.6
	return _to_stream(samples, true)


## Motorbrummen mit Luftrauschen für den Staubsauger. Eine Sekunde, nahtlos geloopt.
func _make_hum_loop() -> AudioStreamWAV:
	var n := RATE
	var samples := PackedFloat32Array()
	samples.resize(n)
	var air := 0.0
	for i in n:
		var t := float(i) / RATE
		air += (_rng.randf_range(-1.0, 1.0) - air) * 0.5
		var motor := sin(TAU * 120.0 * t) * 0.35 + sin(TAU * 240.0 * t) * 0.2 + sin(TAU * 360.0 * t) * 0.1
		samples[i] = motor * 0.6 + air * 0.5
	return _to_stream(samples, true)


## Kurze Glöckchen-Töne nacheinander, z.B. für Münzen oder Belohnungen.
func _make_tones(freqs: Array, spacing: float, decay: float, gain: float) -> AudioStreamWAV:
	var length := spacing * (freqs.size() - 1) + decay * 3.0
	var n := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for k in freqs.size():
		var f: float = freqs[k]
		var start := int(k * spacing * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var env := exp(-t / decay) * minf(1.0, t * 400.0)
			samples[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * gain
	return _to_stream(samples)


## Aufsteigender Ton für Upgrades.
func _make_sweep(f_from: float, f_to: float, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := f_from * pow(f_to / f_from, k)
		phase += TAU * f / RATE
		var env := sin(PI * k) * 0.5
		samples[i] = (sin(phase) + 0.25 * sin(phase * 3.0)) * env
	return _to_stream(samples)


func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
