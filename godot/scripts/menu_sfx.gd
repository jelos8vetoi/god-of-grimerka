## Звуки главного меню: синтезируются один раз при запуске (файлов нет) и идут на шину SFX, подложка — на Ambient.
## main.ui(вид, высота) — один звук; Menu держит подложку (bed) пока открыто. Свои плееры: звуки меню не отбирают
## общий пул боя и не накладываются — один и тот же звук не чаще раза в GAP_MS, лишнее пропускается.
## Звуки: hover — наведение мышью, move — шаг по списку, confirm — выбор, back — назад, open / close — экран
## открылся / закрылся, card — смена карточки режима, value — изменилась настройка, deny — нельзя, launch — запуск игры.
class_name MenuSfx
extends Node

const RATE := 32000
const GAP_MS := 45
# громкость каждого звука, дБ (подобрана на слух под заглавный трек на -6 дБ)
const LEVEL := {
	"hover": -14.0, "move": -9.0, "confirm": -5.0, "back": -8.0, "open": -9.0, "close": -10.0,
	"card": -8.0, "value": -10.0, "deny": -9.0, "launch": -3.0,
}
const BED_DB := -21.0

var streams := {}
var bed_stream: AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
var last := {}
var count := {}               # сколько раз прозвучал каждый звук (для проверок)
var cursor := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	streams["hover"] = _wav(_hover(rng))
	streams["move"] = _wav(_move(rng))
	streams["confirm"] = _wav(_confirm(rng))
	streams["back"] = _wav(_back(rng))
	streams["open"] = _wav(_rip(rng, 0.34, 380.0, 3400.0))
	streams["close"] = _wav(_rip(rng, 0.24, 3000.0, 420.0))
	streams["card"] = _wav(_card(rng))
	streams["value"] = _wav(_value(rng))
	streams["deny"] = _wav(_deny())
	streams["launch"] = _wav(_launch(rng))
	bed_stream = _wav(_bed(rng), true)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(kind: String, pitch := 1.0) -> void:
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
	if p == null:                      # все заняты — перебиваем самый старый, а не копим
		p = players[cursor]
		cursor = (cursor + 1) % players.size()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"   # шины заводит audio.gd — позже нас
	p.stream = streams[kind]
	p.volume_db = float(LEVEL[kind])
	p.pitch_scale = pitch * randf_range(0.98, 1.02)
	p.play()

## Подложка меню: тихий треск винила и комнатный гул по кругу (Ambient). Плеер принадлежит меню и уходит вместе с ним.
func make_bed(owner_node: Node) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = bed_stream
	p.bus = "Ambient" if AudioServer.get_bus_index("Ambient") >= 0 else "Master"
	p.volume_db = -60.0
	owner_node.add_child(p)
	p.play()
	p.create_tween().tween_property(p, "volume_db", BED_DB, 1.6)
	return p

# ---------------- синтез ----------------
func _wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

## нормализация к пику и короткие края (без щелчков)
func _fin(b: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	@warning_ignore("integer_division")
	var edge := mini(48, b.size() / 4)
	for i in b.size():
		var g := k
		if i < 8:
			g *= float(i) / 8.0
		if i > b.size() - edge:
			g *= float(b.size() - i) / float(edge)
		b[i] *= g
	return b

## наведение: короткий «тик» стеклянного звона и щелчок бумаги
func _hover(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.05)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
		b[i] = sin(TAU * 3100.0 * t) * exp(-t * 95.0) * 0.7 + lp * exp(-t * 600.0) * 0.6
	return _fin(b, 0.7)

## шаг по списку: щелчок ниже и плотнее, с лёгким спадом высоты
func _move(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.09)
	var hp := 0.0
	var prev := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		hp = 0.86 * (hp + n - prev)
		prev = n
		ph += TAU * lerpf(1500.0, 1050.0, minf(t / 0.05, 1.0)) / RATE
		b[i] = sin(ph) * exp(-t * 55.0) * 0.8 + hp * exp(-t * 320.0) * 0.5 + sin(ph * 0.5) * exp(-t * 80.0) * 0.3
	return _fin(b, 0.85)

## выбор: удар (бочка + хлопок) и светлый аккорд сверху
func _confirm(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.42)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (45.0 + 110.0 * exp(-t * 34.0)) / RATE
		var kick := sin(ph) * exp(-t * 11.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var clap := lp * exp(-t * 38.0) * 0.55
		var ping := (sin(TAU * 880.0 * t) + sin(TAU * 1318.5 * t) * 0.7 + sin(TAU * 1760.0 * t) * 0.35) * exp(-t * 9.0) * 0.22
		b[i] = tanh((kick * 1.1 + clap + ping) * 1.4)
	return _fin(b, 0.92)

## назад: тон уходит вниз, под ним короткий выдох шума
func _back(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.22)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(980.0, 260.0, minf(t / 0.16, 1.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		b[i] = sin(ph) * exp(-t * 16.0) * 0.7 + lp * sin(PI * minf(t / 0.2, 1.0)) * 0.45
	return _fin(b, 0.8)

## экран открылся / закрылся: рвётся бумага — шум через полосовой фильтр с бегущей частотой
func _rip(rng: RandomNumberGenerator, sec: float, f0: float, f1: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lo := 0.0
	var band := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / sec
		var f := lerpf(f0, f1, u * u * (3.0 - 2.0 * u))
		var a := clampf(TAU * f / RATE, 0.0, 0.95)
		var n := rng.randf_range(-1.0, 1.0) * (0.6 + 0.4 * float(rng.randf() < 0.18))   # волокна — рывками
		lo += (n - lo) * a
		band += (lo - band) * a * 0.5
		b[i] = (lo - band) * sin(PI * u) * (0.6 + 0.4 * sin(PI * minf(u * 3.0, 1.0)))
	return _fin(b, 0.75)

## смена карточки: короткий свист воздуха и тихий стук внизу
func _card(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.2)
	var lo := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 0.2
		var a := clampf(TAU * lerpf(600.0, 2600.0, u) / RATE, 0.0, 0.9)
		lo += (rng.randf_range(-1.0, 1.0) - lo) * a
		ph += TAU * (70.0 + 60.0 * exp(-t * 40.0)) / RATE
		b[i] = lo * sin(PI * u) * 0.55 + sin(ph) * exp(-t * 30.0) * 0.6
	return _fin(b, 0.8)

## значение настройки: двойной щелчок
func _value(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.07)
	for i in b.size():
		var t := float(i) / RATE
		var t2 := maxf(t - 0.028, 0.0)
		var n := rng.randf_range(-1.0, 1.0) * 0.25
		b[i] = (sin(TAU * 1900.0 * t) + n) * exp(-t * 170.0) + (sin(TAU * 2500.0 * t2) + n) * exp(-t2 * 170.0) * float(t >= 0.028) * 0.8
	return _fin(b, 0.7)

## нельзя: два глухих жужжащих толчка
func _deny() -> PackedFloat32Array:
	var b := _buf(0.24)
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-fmod(t, 0.11) * 30.0) * float(t < 0.21)
		var sq := signf(sin(TAU * 140.0 * t)) * 0.5 + sin(TAU * 70.0 * t) * 0.5
		b[i] = sq * env * 0.6
	return _fin(b, 0.7)

## запуск игры: тяжёлый удар, раскат с хвостом и плёнка, которая тормозит вниз
func _launch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(1.5)
	var ph := 0.0
	var ph2 := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (32.0 + 120.0 * exp(-t * 18.0)) / RATE
		var boom := sin(ph) * exp(-t * 3.2)
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * lerpf(0.6, 0.05, minf(t / 0.8, 1.0))
		lp2 += (lp - lp2) * 0.3
		var crash := lp2 * exp(-t * 4.0) * 0.8 + n * exp(-t * 30.0) * 0.35
		ph2 += TAU * 220.0 * maxf(0.05, 1.0 - t / 1.1) / RATE      # тон тормозит, как плёнка
		var tape := (sin(ph2) + sin(ph2 * 1.5) * 0.5) * exp(-t * 1.6) * 0.18
		b[i] = tanh((boom * 1.3 + crash + tape) * 1.5)
	return _fin(b, 0.95)

## подложка: 6 с по кругу — редкий треск винила, шипение и тихий гул 50 Гц (ровно 300 периодов — круг без шва)
func _bed(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(6.0)
	var hiss := 0.0
	var pop := 0.0
	var pop_lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		hiss += (rng.randf_range(-1.0, 1.0) - hiss) * 0.12
		if rng.randf() < 0.0009:
			pop = rng.randf_range(-1.0, 1.0) * rng.randf_range(0.4, 1.0)
		pop *= 0.82
		pop_lp += (pop - pop_lp) * 0.55
		var hum := sin(TAU * 50.0 * t) * 0.10 + sin(TAU * 100.0 * t) * 0.05
		b[i] = hiss * 0.16 + pop_lp * 0.9 + hum
	return _fin(b, 0.6)
