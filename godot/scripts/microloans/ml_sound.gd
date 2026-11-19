## Звук «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: синтезируется один раз при запуске мини-игры (файлов нет), без чужих записей.
## Интерфейс — шина UI (идёт в SFX), предметы и комната — SFX, голос Пахана — Voice. Музыка и фон комнаты — audio.gd
## (набор loc_ml и amb_ml, слои по напряжению — MicroloansRoot.music_layers / bed_set).
## Вызов: root.snd.play(вид, высота). Один и тот же звук не чаще раза в GAP_MS; лишнее перебивает самый старый плеер.
## Виды: move, ok, back, tab, open, close, notify, alert, ring (петля: ring_on / ring_off), money, coins, bills, pay,
## stamp, loan, calc, keys, buy, stress, phase, sigh, hm, cheer, fail, tick, whoosh, drop, zap, clean.
class_name MLSound
extends Node

const RATE := 32000
const GAP_MS := 40
# [громкость дБ, шина]
const LEVEL := {
	"move": [-12.0, "UI"], "ok": [-7.0, "UI"], "back": [-9.0, "UI"], "tab": [-9.0, "UI"], "open": [-10.0, "UI"], "close": [-11.0, "UI"],
	"notify": [-6.0, "UI"], "alert": [-4.0, "UI"], "ring": [-6.0, "SFX"], "money": [-4.0, "SFX"], "coins": [-7.0, "SFX"],
	"bills": [-8.0, "SFX"], "pay": [-5.0, "SFX"], "stamp": [-4.0, "SFX"], "loan": [-6.0, "SFX"], "calc": [-10.0, "SFX"],
	"keys": [-11.0, "SFX"], "buy": [-5.0, "SFX"], "stress": [-6.0, "SFX"], "phase": [-5.0, "SFX"], "sigh": [-6.0, "Voice"],
	"hm": [-7.0, "Voice"], "cheer": [-5.0, "Voice"], "fail": [-6.0, "SFX"], "tick": [-14.0, "UI"], "whoosh": [-9.0, "SFX"],
	"drop": [-8.0, "SFX"], "zap": [-8.0, "SFX"], "clean": [-9.0, "SFX"],
}

static var _cache := {}
var players: Array[AudioStreamPlayer] = []
var ring_p: AudioStreamPlayer
var last := {}
var count := {}               # сколько раз прозвучал каждый звук (для проверки)
var cursor := 0
var muted := false            # проверки без --audiolog: не шуметь

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	warm()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	ring_p = AudioStreamPlayer.new()
	ring_p.stream = _cache["ring"]
	add_child(ring_p)

static func _bus(b: String) -> String:
	if AudioServer.get_bus_index(b) >= 0:
		return b
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

func play(kind: String, pitch := 1.0) -> void:
	if not LEVEL.has(kind):
		return
	count[kind] = int(count.get(kind, 0)) + 1
	if muted:
		return
	var now := Time.get_ticks_msec()
	if now - int(last.get(kind, -1000)) < GAP_MS:
		return
	last[kind] = now
	var p: AudioStreamPlayer = null
	for i in players.size():
		var c := players[(cursor + i) % players.size()]
		if not c.playing:
			p = c
			cursor = (cursor + i + 1) % players.size()
			break
	if p == null:
		p = players[cursor]
		cursor = (cursor + 1) % players.size()
	p.stream = _cache[kind]
	p.bus = _bus(String(LEVEL[kind][1]))
	p.volume_db = float(LEVEL[kind][0])
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()

## звонок коллектора: звенит, пока не ответили
func ring_on() -> void:
	count["ring"] = int(count.get("ring", 0)) + 1
	if muted or ring_p.playing:
		return
	ring_p.bus = _bus("SFX")
	ring_p.volume_db = float(LEVEL["ring"][0])
	ring_p.play()

func ring_off() -> void:
	ring_p.stop()

# ---------------- синтез ----------------
static func warm() -> void:
	if not _cache.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	_cache["move"] = _wav(_click(rng, 0.05, 2400.0, 0.5))
	_cache["tick"] = _wav(_click(rng, 0.03, 3600.0, 0.3))
	_cache["ok"] = _wav(_ok(rng))
	_cache["back"] = _wav(_sweep(0.16, 900.0, 380.0, 0.6))
	_cache["tab"] = _wav(_paper(rng, 0.14, 2600.0))
	_cache["open"] = _wav(_paper(rng, 0.26, 1800.0))
	_cache["close"] = _wav(_paper(rng, 0.2, 1200.0))
	_cache["notify"] = _wav(_chime([1568.0, 2093.0], 0.09, 0.5))
	_cache["alert"] = _wav(_alert())
	_cache["ring"] = _wav(_ring(), true)
	_cache["money"] = _wav(_register(rng))
	_cache["coins"] = _wav(_coins(rng, 6))
	_cache["bills"] = _wav(_bills(rng))
	_cache["pay"] = _wav(_pay(rng))
	_cache["stamp"] = _wav(_stamp(rng))
	_cache["loan"] = _wav(_loan(rng))
	_cache["calc"] = _wav(_calc())
	_cache["keys"] = _wav(_keys(rng))
	_cache["buy"] = _wav(_buy(rng))
	_cache["stress"] = _wav(_stress())
	_cache["phase"] = _wav(_phase(rng))
	_cache["sigh"] = _wav(_voice(rng, 0.9, 150.0, 110.0, [700.0, 1100.0], true))
	_cache["hm"] = _wav(_voice(rng, 0.45, 120.0, 135.0, [500.0, 900.0], false))
	_cache["cheer"] = _wav(_voice(rng, 0.6, 170.0, 230.0, [800.0, 1300.0], false))
	_cache["fail"] = _wav(_sweep(0.4, 320.0, 120.0, 0.7, true))
	_cache["whoosh"] = _wav(_whoosh(rng, 0.3))
	_cache["drop"] = _wav(_drop(rng))
	_cache["zap"] = _wav(_zap(rng))
	_cache["clean"] = _wav(_chime([1318.5, 1760.0, 2637.0], 0.06, 0.4))

static func _wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := 0.85 / m
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	var edge := mini(64, b.size() / 4)
	for i in b.size():
		var g := k
		if not loop:
			if i < 6:
				g *= float(i) / 6.0
			if i > b.size() - edge:
				g *= float(b.size() - i) / float(edge)
		bytes.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w

static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

static func _click(rng: RandomNumberGenerator, sec: float, f: float, nz: float) -> PackedFloat32Array:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * f * t) * exp(-t * 110.0) + rng.randf_range(-1, 1) * nz * exp(-t * 500.0)
	return b

static func _ok(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.22)
	for i in b.size():
		var t := float(i) / RATE
		var t2 := maxf(t - 0.06, 0.0)
		b[i] = sin(TAU * 880.0 * t) * exp(-t * 30.0) * 0.6 + sin(TAU * 1318.5 * t2) * exp(-t2 * 22.0) * float(t >= 0.06) * 0.6 + rng.randf_range(-1, 1) * exp(-t * 400.0) * 0.3
	return b

static func _sweep(sec: float, f0: float, f1: float, v: float, buzz := false) -> PackedFloat32Array:
	var b := _buf(sec)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / sec) / RATE
		var w := sin(ph) if not buzz else (signf(sin(ph)) * 0.5 + sin(ph) * 0.5)
		b[i] = w * v * exp(-t * (8.0 if buzz else 14.0))
	return b

## бумага: шорох листа (шум в полосе вокруг f) с рывками волокон
static func _paper(rng: RandomNumberGenerator, sec: float, f: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lo := 0.0
	var band := 0.0
	var a := clampf(TAU * f / RATE, 0.0, 0.9)
	for i in b.size():
		var t := float(i) / RATE
		var u := t / sec
		lo += (rng.randf_range(-1, 1) * (0.5 + 0.5 * float(rng.randf() < 0.25)) - lo) * a
		band += (lo - band) * a * 0.4
		b[i] = (lo - band) * sin(PI * u) * (0.7 + 0.3 * sin(TAU * 23.0 * t))
	return b

static func _chime(notes: Array, gap: float, sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	for k in notes.size():
		var st := int(gap * k * RATE)
		var f: float = notes[k]
		for i in range(st, b.size()):
			var t := float(i - st) / RATE
			b[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-t * 11.0) * 0.5
	return b

## просрочка: два резких тона вниз и короткое жужжание вибро
static func _alert() -> PackedFloat32Array:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		var f := 1180.0 if t < 0.14 else 830.0
		var on := float(t < 0.12 or (t > 0.16 and t < 0.3))
		b[i] = (signf(sin(TAU * f * t)) * 0.3 + sin(TAU * f * t) * 0.4) * on + sin(TAU * 170.0 * t) * float(t > 0.32) * exp(-(t - 0.32) * 8.0) * 0.5 * (0.5 + 0.5 * signf(sin(TAU * 30.0 * t)))
	return b

## звонок: старый смартфон, две ноты трелью (петля 1,6 с)
static func _ring() -> PackedFloat32Array:
	var b := _buf(1.6)
	for i in b.size():
		var t := float(i) / RATE
		var on := float(t < 1.0)
		var f := 1320.0 if fposmod(t, 0.1) < 0.05 else 990.0
		b[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.15) * on * (0.8 + 0.2 * sin(TAU * 6.0 * t))
	return b

## касса: звонок колокольчика, ящик выезжает, монеты
static func _register(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2637.0 * t) + 0.5 * sin(TAU * 3951.0 * t)) * exp(-t * 7.0) * 0.45
		var t2 := t - 0.12
		if t2 > 0.0 and t2 < 0.15:
			b[i] += rng.randf_range(-1, 1) * 0.35 * sin(PI * t2 / 0.15) + sin(TAU * 140.0 * t2) * 0.3 * exp(-t2 * 20.0)
	var c := _coins(rng, 4)
	for i in mini(c.size(), b.size() - int(0.25 * RATE)):
		b[i + int(0.25 * RATE)] += c[i] * 0.6
	return b

static func _coins(rng: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var b := _buf(0.6)
	for k in n:
		var st := int(rng.randf_range(0.0, 0.32) * RATE)
		var f := rng.randf_range(3200.0, 5200.0)
		for i in range(st, mini(b.size(), st + int(0.2 * RATE))):
			var t := float(i - st) / RATE
			b[i] += (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.48 * t)) * exp(-t * 28.0) * 0.3
	return b

## пересчёт купюр: быстрые шлепки бумаги
static func _bills(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.55)
	for k in 6:
		var st := int(k * 0.08 * RATE)
		var lo := 0.0
		for i in range(st, mini(b.size(), st + int(0.06 * RATE))):
			var t := float(i - st) / RATE
			lo += (rng.randf_range(-1, 1) - lo) * 0.6
			b[i] += lo * exp(-t * 60.0) * 0.8
	return b

## оплата: пищит терминал, затем «принято»
static func _pay(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 2000.0 * t) * float(t < 0.08) * 0.4
		var t2 := t - 0.18
		if t2 > 0.0:
			b[i] += (sin(TAU * 1046.5 * t2) + sin(TAU * 1568.0 * t2) * 0.7) * exp(-t2 * 7.0) * 0.4
	var bl := _bills(rng)
	for i in mini(bl.size(), b.size()):
		b[i] += bl[i] * 0.25
	return b

## печать «ЗАКРЫТО»: глухой удар по столу
static func _stamp(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.45)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (90.0 + 80.0 * exp(-t * 40.0)) * t) * exp(-t * 14.0) + rng.randf_range(-1, 1) * exp(-t * 70.0) * 0.7 + sin(TAU * 640.0 * t) * exp(-t * 30.0) * 0.3
	return b

## новый займ: «дзынь» перевода и шуршание договора
static func _loan(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _chime([1975.5, 2489.0, 2960.0], 0.07, 0.6)
	var p := _paper(rng, 0.3, 2000.0)
	for i in p.size():
		b[i + int(0.2 * RATE)] += p[i] * 0.6
	return b

static func _calc() -> PackedFloat32Array:
	var b := _buf(0.42)
	for k in 4:
		var st := int(k * 0.09 * RATE)
		var f: float = [2093.0, 2349.0, 2637.0, 3136.0][k]
		for i in range(st, mini(b.size(), st + int(0.05 * RATE))):
			var t := float(i - st) / RATE
			b[i] += signf(sin(TAU * f * t)) * 0.3 * exp(-t * 30.0)
	return b

## клавиатура ноутбука: очередь мягких щелчков
static func _keys(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.6)
	var at := 0.0
	while at < 0.52:
		var st := int(at * RATE)
		var f := rng.randf_range(1800.0, 3200.0)
		for i in range(st, mini(b.size(), st + int(0.03 * RATE))):
			var t := float(i - st) / RATE
			b[i] += (rng.randf_range(-1, 1) * 0.5 + sin(TAU * f * t) * 0.4) * exp(-t * 220.0)
		at += rng.randf_range(0.05, 0.11)
	return b

## покупка: пакет шуршит и короткий мажорный «дзынь»
static func _buy(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _chime([1046.5, 1318.5, 1568.0, 2093.0], 0.05, 0.6)
	var c := _coins(rng, 3)
	for i in mini(c.size(), b.size()):
		b[i] += c[i] * 0.4
	return b

## стресс растёт: двойной удар сердца и низкий нарастающий тон
static func _stress() -> PackedFloat32Array:
	var b := _buf(0.8)
	for i in b.size():
		var t := float(i) / RATE
		var a := exp(-t * 18.0) + exp(-maxf(t - 0.24, 0.0) * 16.0) * float(t >= 0.24) * 0.7
		b[i] = sin(TAU * 58.0 * t) * a + sin(TAU * 116.0 * t) * a * 0.5 + sin(TAU * (220.0 + 60.0 * t) * t) * smoothstep(0.0, 0.8, t) * 0.12
	return b

## смена фазы дня: воздух проходит и колокольчик
static func _phase(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _whoosh(rng, 0.7)
	var c := _chime([784.0, 1174.7], 0.12, 0.7)
	for i in c.size():
		b[i] += c[i] * 0.7
	return b

static func _whoosh(rng: RandomNumberGenerator, sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lo := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / sec
		lo += (rng.randf_range(-1, 1) - lo) * clampf(TAU * lerpf(500.0, 3000.0, sin(PI * u)) / RATE, 0.0, 0.9)
		b[i] = lo * sin(PI * u)
	return b

static func _drop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (140.0 + 120.0 * exp(-t * 30.0)) * t) * exp(-t * 16.0) + rng.randf_range(-1, 1) * exp(-t * 60.0) * 0.5
	return b

static func _zap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.3)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (rng.randf_range(-1, 1) * 0.6 + signf(sin(TAU * 60.0 * t)) * 0.3) * exp(-t * 12.0) * (0.5 + 0.5 * float(rng.randf() < 0.6))
	return b

## голос Пахана без слов: вздох (шум через «гласную»), «хм», радостное «о!» — резонатор на шуме и на пиле
static func _voice(rng: RandomNumberGenerator, sec: float, f0: float, f1: float, formants: Array, breathy: bool) -> PackedFloat32Array:
	var b := _buf(sec)
	var y := [[0.0, 0.0], [0.0, 0.0]]
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / sec
		ph += lerpf(f0, f1, u) / RATE
		var src: float = rng.randf_range(-1, 1) if breathy else (fposmod(ph, 1.0) * 2.0 - 1.0) * 0.7 + rng.randf_range(-1, 1) * 0.15
		var out := 0.0
		for k in 2:
			var w := TAU * float(formants[k]) * (1.0 - 0.15 * u) / RATE
			var r := 0.985
			var v: float = src * (1.0 - r) + 2.0 * r * cos(w) * y[k][0] - r * r * y[k][1]
			y[k][1] = y[k][0]
			y[k][0] = v
			out += v
		b[i] = out * sin(PI * u)
	return b
