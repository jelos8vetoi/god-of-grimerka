## Звук приквела «ГОЛДА 67»: всё синтезируется при первом обращении (файлов нет), по образцу MLSound.
## Вызов: G67Sound.play(owner_node, вид, позиция?) — позиция даёт AudioStreamPlayer3D, без неё — обычный плеер на шине SFX.
## Виды: coin, stash, shawarma, fit, artifact, respect, lever, drum, tray, click, entry, relay, chain, siren, water, bucket, alarm, dog, pigeon,
## doorbell, door, steps_up, step_snow, step_asphalt, step_ice, step_concrete, step_stairs; петли фона: loop_hub, loop_dvor.
class_name G67Sound
extends RefCounted

const RATE := 22050
# вид → [длительность, громкость дБ, шина, петля]
const KINDS := {
	"coin": [0.35, -6.0, "SFX", false], "stash": [0.5, -5.0, "SFX", false], "shawarma": [0.3, -6.0, "SFX", false], "fit": [0.6, -6.0, "SFX", false],
	"artifact": [0.8, -5.0, "SFX", false], "respect": [0.7, -6.0, "SFX", false], "lever": [0.5, -5.0, "SFX", false], "drum": [0.15, -9.0, "SFX", false],
	"tray": [0.3, -5.0, "SFX", false], "click": [0.12, -6.0, "SFX", false], "entry": [0.5, -8.0, "SFX", false], "relay": [0.25, -6.0, "SFX", false],
	"chain": [0.5, -7.0, "SFX", false], "siren": [0.8, -9.0, "SFX", false], "water": [0.7, -6.0, "SFX", false], "bucket": [0.4, -6.0, "SFX", false],
	"alarm": [1.2, -14.0, "SFX", false], "dog": [0.45, -14.0, "SFX", false], "pigeon": [0.6, -16.0, "SFX", false], "doorbell": [0.9, -14.0, "SFX", false],
	"door": [0.35, -12.0, "SFX", false], "steps_up": [0.9, -16.0, "SFX", false], "step_snow": [0.22, -14.0, "SFX", false], "step_asphalt": [0.14, -15.0, "SFX", false],
	"step_ice": [0.2, -15.0, "SFX", false], "step_concrete": [0.14, -15.0, "SFX", false], "step_stairs": [0.16, -14.0, "SFX", false],
	"jingle": [3.4, -8.0, "SFX", false],
	"hit_cut": [0.28, -6.0, "SFX", false],
	"intercom_beep": [0.5, -8.0, "SFX", false], "radio_jingle": [1.6, -14.0, "SFX", false], "crash": [0.9, -4.0, "SFX", false],
	"snow_slide": [1.1, -7.0, "SFX", false], "lamp_crackle": [0.5, -9.0, "SFX", false], "car_alarm": [3.0, -10.0, "SFX", false],
	"counter_click": [0.12, -10.0, "SFX", false], "swing_creak": [1.2, -16.0, "SFX", false], "carpet_beat": [0.5, -5.0, "SFX", false],
	"cough": [0.6, -9.0, "SFX", false], "door_slam": [0.6, -4.0, "SFX", false], "vacuum": [2.0, -9.0, "SFX", false],
	"mic_move": [0.5, -8.0, "SFX", false], "tap": [0.1, -9.0, "SFX", false], "loop_studio": [5.0, -30.0, "Ambient", true],
	"loop_hub": [6.0, -26.0, "Ambient", true], "loop_dvor": [8.0, -24.0, "Ambient", true],
}
static var _cache := {}

static func kinds() -> Array:
	return KINDS.keys()

static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var spec: Array = KINDS[kind]
	var n := int(float(spec[0]) * RATE)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / float(spec[0])
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.2
		lp2 += (noise - lp2) * 0.02
		var x := 0.0
		match kind:
			"coin": x = (sin(TAU * 1760.0 * t) + 0.5 * sin(TAU * 2640.0 * t)) * exp(-t * 9.0) * 0.5
			"stash": x = (sin(TAU * 1320.0 * t) + sin(TAU * 1980.0 * (t - 0.08)) * (1.0 if t > 0.08 else 0.0)) * exp(-t * 6.0) * 0.4
			"shawarma": x = lp * exp(-t * 14.0) * 0.9 + sin(TAU * 220.0 * t) * exp(-t * 10.0) * 0.3
			"fit": x = (sin(TAU * 660.0 * t) + sin(TAU * 990.0 * t) * 0.6) * exp(-t * 4.0) * 0.4
			"artifact": x = (sin(TAU * (440.0 + 400.0 * u) * t) + sin(TAU * 1320.0 * t) * 0.4) * exp(-t * 3.0) * 0.4
			"respect": x = (sin(TAU * 392.0 * t) * (1.0 if t < 0.2 else 0.0) + sin(TAU * 523.0 * t) * (1.0 if t >= 0.2 and t < 0.4 else 0.0) + sin(TAU * 659.0 * t) * (1.0 if t >= 0.4 else 0.0)) * (1.0 - u) * 0.45
			"lever": x = (lp * 0.5 + sin(TAU * 110.0 * t) * 0.5) * exp(-pow((t - 0.15) * 14.0, 2.0)) * 0.9 + noise * exp(-t * 30.0) * 0.4
			"drum": x = sin(TAU * (900.0 - 500.0 * u) * t) * exp(-t * 25.0) * 0.5 + noise * exp(-t * 60.0) * 0.2
			"tray": x = sin(TAU * 150.0 * t) * exp(-t * 18.0) * 0.8 + noise * exp(-t * 80.0) * 0.4
			"click": x = noise * exp(-t * 120.0) * 0.8 + sin(TAU * 1500.0 * t) * exp(-t * 80.0) * 0.3
			"entry": x = sin(TAU * (900.0 + 1400.0 * u) * t + 3.0 * sin(TAU * 7.0 * t)) * sin(PI * u) * 0.5
			"relay": x = noise * exp(-t * 90.0) * 0.7 + sin(TAU * 90.0 * t) * exp(-t * 30.0) * 0.5
			"chain": x = (lp * (0.5 + 0.5 * sin(TAU * 38.0 * t))) * (1.0 - u) * 0.8 + sin(TAU * 2400.0 * t) * exp(-t * 20.0) * 0.1
			"siren": x = sin(TAU * (700.0 + 500.0 * sin(TAU * 1.6 * t)) * t) * 0.35
			"water": x = lp * (sin(PI * u)) * 0.9 + sin(TAU * (400.0 + 600.0 * u) * t) * exp(-t * 6.0) * 0.1
			"bucket": x = (sin(TAU * 260.0 * t) + sin(TAU * 410.0 * t) * 0.5) * exp(-t * 12.0) * 0.5 + noise * exp(-t * 60.0) * 0.2
			"alarm": x = sin(TAU * (1100.0 if int(t * 5.0) % 2 == 0 else 800.0) * t) * 0.3 * (1.0 - u * 0.4)
			"dog": x = (sin(TAU * (320.0 - 120.0 * u) * t) * 0.6 + lp * 0.4) * exp(-pow((fmod(t, 0.22) - 0.05) * 14.0, 2.0)) * 0.7
			"pigeon": x = (sin(TAU * (240.0 + 30.0 * sin(TAU * 4.0 * t)) * t) * 0.4 + lp * 0.1) * sin(PI * u) * (0.6 + 0.4 * sin(TAU * 9.0 * t))
			"doorbell": x = (sin(TAU * 740.0 * t) * (1.0 if t < 0.4 else 0.0) + sin(TAU * 587.0 * t) * (1.0 if t >= 0.4 else 0.0)) * exp(-fmod(t, 0.4) * 5.0) * 0.45
			"door": x = sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.8 + lp * exp(-t * 25.0) * 0.5
			"steps_up": x = (lp2 * 6.0) * exp(-fmod(t, 0.3) * 20.0) * 0.6 * (1.0 - u)
			"step_snow": x = (noise - lp) * exp(-t * 14.0) * 0.5 + lp2 * 3.0 * exp(-t * 18.0)
			"step_asphalt": x = lp * exp(-t * 40.0) * 0.8 + sin(TAU * 120.0 * t) * exp(-t * 30.0) * 0.3
			"step_ice": x = (noise - lp) * exp(-t * 22.0) * 0.4 + sin(TAU * 2200.0 * t) * exp(-t * 35.0) * 0.15
			"step_concrete": x = lp * exp(-t * 50.0) * 0.7 + sin(TAU * 150.0 * t) * exp(-t * 35.0) * 0.4
			"step_stairs": x = lp * exp(-t * 45.0) * 0.6 + sin(TAU * 180.0 * t) * exp(-t * 28.0) * 0.4
			"mic_move": x = lp * (0.4 + 0.6 * sin(PI * u)) * 0.8 + sin(TAU * 90.0 * t) * 0.15 * sin(PI * u)
			"tap": x = sin(TAU * 220.0 * t) * exp(-t * 55.0) * 0.8 + noise * exp(-t * 120.0) * 0.3
			"loop_studio": x = sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 120.0 * t) * 0.12 + lp2 * 2.0
			"hit_cut": x = sin(TAU * (160.0 - 90.0 * u) * t) * exp(-t * 14.0) * 0.8 + noise * exp(-t * 60.0) * 0.5
			"intercom_beep": x = (sin(TAU * 1760.0 * t) * (1.0 if t < 0.12 else 0.0) + sin(TAU * 1320.0 * t) * (1.0 if t > 0.2 and t < 0.32 else 0.0)) * 0.5
			"radio_jingle": x = (sin(TAU * [392.0, 494.0, 587.0, 494.0, 440.0, 523.0, 392.0, 330.0][int(t * 5.0) % 8] * t) * 0.35 + lp * 0.1) * (0.6 + 0.4 * sin(TAU * 50.0 * t))
			"crash": x = noise * exp(-t * 7.0) * 0.8 + sin(TAU * 70.0 * t) * exp(-t * 6.0) * 0.7 + sin(TAU * 2200.0 * t) * exp(-pow((t - 0.22) * 18.0, 2.0)) * 0.4
			"snow_slide": x = lp * (sin(PI * u) * 0.8) + lp2 * 2.0 * exp(-pow((u - 0.8) * 8.0, 2.0)) + sin(TAU * 60.0 * t) * exp(-pow((u - 0.82) * 14.0, 2.0)) * 0.9
			"lamp_crackle": x = noise * (1.0 if int(t * 40.0) % 3 != 0 else 0.1) * exp(-t * 6.0) * 0.6 + sin(TAU * 100.0 * t) * 0.15 * exp(-t * 4.0)
			"car_alarm": x = sin(TAU * (900.0 + 600.0 * (1.0 if int(t * 6.0) % 2 == 0 else 0.0)) * t) * 0.28 * (1.0 if int(t * 3.0) % 2 == 0 else 0.35)
			"counter_click": x = noise * exp(-t * 140.0) * 0.8 + sin(TAU * 2000.0 * t) * exp(-t * 90.0) * 0.3
			"swing_creak": x = sin(TAU * (520.0 + 120.0 * sin(TAU * 3.0 * t)) * t) * 0.18 * sin(PI * u) + lp * 0.05
			"carpet_beat": x = sin(TAU * 90.0 * t) * exp(-t * 14.0) * 0.8 + lp * exp(-t * 10.0) * 0.5
			"cough": x = lp * (exp(-pow((t - 0.12) * 18.0, 2.0)) + exp(-pow((t - 0.32) * 18.0, 2.0))) * 0.8
			"door_slam": x = sin(TAU * 110.0 * t) * exp(-t * 16.0) * 0.8 + noise * exp(-t * 40.0) * 0.5
			"vacuum": x = (lp * 0.5 + sin(TAU * (90.0 + 80.0 * sin(PI * u)) * t) * 0.5) * exp(-pow((u - 0.45) * 2.5, 2.0)) * 0.7
			"jingle": x = (sin(TAU * [523.0, 659.0, 784.0, 1047.0][int(t * 8.0) % 4] * t) * 0.5 + sin(TAU * 262.0 * t) * 0.25 * (1.0 if int(t * 4.0) % 2 == 0 else 0.2)) * 0.6
			"loop_hub": x = (sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.2 + lp2 * 3.0) * 0.5
			"loop_dvor": x = lp2 * 10.0 * (0.7 + 0.3 * sin(TAU * 0.25 * t)) + sin(TAU * 38.0 * t) * 0.1
		if bool(spec[3]):
			x *= minf(1.0, minf(t, float(spec[0]) - t) / 0.4 + 0.0)          # края петли сходятся в тишину
		var v := int(clampf(x, -1.0, 1.0) * 30000.0)
		buf.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = buf
	if bool(spec[3]):
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	_cache[kind] = w
	return w

static func peak(kind: String) -> float:
	var w := stream(kind)
	var p := 0.0
	for i in range(0, w.data.size() - 1, 2):
		p = maxf(p, absf(float(w.data.decode_s16(i)) / 32768.0))
	return p

## Один звук: без позиции — плоский плеер, с позицией — трёхмерный; удаляется сам
static func play(owner: Node, kind: String, at := Vector3.INF, pitch := 1.0) -> void:
	if not KINDS.has(kind) or owner == null or not owner.is_inside_tree():
		return
	var spec: Array = KINDS[kind]
	var bus := String(spec[2]) if AudioServer.get_bus_index(String(spec[2])) >= 0 else "Master"
	if at == Vector3.INF:
		var p := AudioStreamPlayer.new()
		p.stream = stream(kind)
		p.bus = bus
		p.volume_db = float(spec[1])
		p.pitch_scale = pitch * randf_range(0.97, 1.03)
		owner.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream(kind)
		p3.bus = bus
		p3.volume_db = float(spec[1])
		p3.pitch_scale = pitch * randf_range(0.97, 1.03)
		p3.position = at
		owner.add_child(p3)
		p3.play()
		p3.finished.connect(p3.queue_free)
