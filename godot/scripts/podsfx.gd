## Тихие звуки физического iPod и EarPods: синтезируются при запуске (файлов нет), идут на шину SFX —
## мимо Bass Boost и реверберации музыки. Звук привязан к событию анимации (pod.gd вызывает play при переходе фазы).
## Накопления нет: три плеера на всё, один и тот же звук не чаще раза в 70 мс, громкость каждого задана заранее.
class_name PodSfx
extends Node

const RATE := 22050
const GAP_MS := 70
# звук: [громкость дБ, высота]
const LEVEL := {
	"cloth": [-27.0, 1.0],     # шорох ткани у кармана
	"grip": [-24.0, 1.0],      # корпус ложится в ладонь
	"slide": [-28.0, 1.0],     # iPod выходит из кармана / входит в него
	"bud_touch": [-27.0, 1.0], # пластик вкладыша в пальцах
	"bud_seat": [-23.0, 1.0],  # вкладыш сел в ухо
	"bud_out": [-25.0, 1.0],   # вкладыш вынули
	"cable": [-31.0, 1.0],     # провод скользнул по ткани
}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var last := {}
var count := {}              # сколько раз прозвучал каждый звук (для проверки)
var cursor := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	streams["cloth"] = _noise(rng, 0.22, 900.0, 3800.0, 0.05, 0.32)
	streams["slide"] = _noise(rng, 0.13, 1600.0, 6000.0, 0.02, 0.5)
	streams["cable"] = _noise(rng, 0.09, 2500.0, 7000.0, 0.01, 0.4)
	streams["grip"] = _knock(rng, 0.05, 170.0, 1300.0, 0.55)
	streams["bud_touch"] = _knock(rng, 0.025, 2600.0, 5200.0, 0.3)
	streams["bud_seat"] = _knock(rng, 0.045, 640.0, 1500.0, 0.45)
	streams["bud_out"] = _sweep(0.06, 380.0, 760.0)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		players.append(p)

func play(kind: String) -> void:
	if not streams.has(kind):
		return
	var now := GameClock.ms()
	if now - int(last.get(kind, -1000)) < GAP_MS:
		return
	last[kind] = now
	count[kind] = int(count.get(kind, 0)) + 1
	var p: AudioStreamPlayer = null
	for i in players.size():
		var c := players[(cursor + i) % players.size()]
		if not c.playing:
			p = c
			cursor = (cursor + i + 1) % players.size()
			break
	if p == null:
		return                  # все заняты: лучше пропустить, чем наслоить
	p.stream = streams[kind]
	p.volume_db = float(LEVEL[kind][0])
	p.pitch_scale = float(LEVEL[kind][1]) * randf_range(0.97, 1.03)
	p.play()

## Шорох: белый шум через полосовой фильтр (fa…fb Гц), мягкая атака и спад.
func _noise(rng: RandomNumberGenerator, sec: float, fa: float, fb: float, attack: float, amp: float) -> AudioStreamWAV:
	var n := int(sec * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	var ka := exp(-TAU * fa / RATE)
	var kb := 1.0 - exp(-TAU * fb / RATE)
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		hp = ka * (hp + x - prev)
		prev = x
		lp += (hp - lp) * kb
		var env := minf(1.0, t / attack) * pow(1.0 - t / sec, 2.0)
		# неровная громкость — так шуршит ткань, а не ровный шум
		env *= 0.6 + 0.4 * sin(t * 61.0 + sin(t * 23.0) * 2.0)
		out[i] = lp * env * amp
	return _wav(out)

## Глухой стук: затухающий тон и короткий щелчок шума поверх.
func _knock(rng: RandomNumberGenerator, sec: float, tone: float, click: float, amp: float) -> AudioStreamWAV:
	var n := int(sec * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var kc := 1.0 - exp(-TAU * click / RATE)
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * kc
		var body := sin(TAU * tone * t) * exp(-t * 70.0)
		var tick := lp * exp(-t * 400.0) * 0.6
		out[i] = (body + tick) * (1.0 - exp(-t * 3000.0)) * amp
	return _wav(out)

## Мягкий «чпок» без резкости: тон скользит вверх и быстро гаснет.
func _sweep(sec: float, f0: float, f1: float) -> AudioStreamWAV:
	var n := int(sec * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / sec) / RATE
		out[i] = sin(ph) * (1.0 - exp(-t * 900.0)) * exp(-t * 60.0) * 0.4
	return _wav(out)

func _wav(v: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(v.size() * 2)
	for i in v.size():
		bytes.encode_s16(i * 2, clampi(int(v[i] * 32767.0), -32768, 32767))
	s.data = bytes
	return s
