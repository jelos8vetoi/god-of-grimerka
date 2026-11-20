## Звук «5 НОЧЕЙ С ПАХАНОМ» — свой, синтезированный в коде (без чужих записей): гул, вентиляция, электричество,
## реле, монитор, шаги, двери, скрежет, стук в шахте, шёпот, смешок, писк сервера, отключение, рукоятка
## генератора, колокол шести утра и шесть разных криков скримеров. Звуки собираются один раз (кэш) и играют
## через шины audio.gd: SFX, Ambient, Voice, Music.
class_name FNSound

const RATE := 22050
static var _cache := {}
## поправка громкости, дБ, поверх той, что задаёт место вызова: раньше многое звучало на −10…−16 дБ и почти целиком ниже
## 300 Гц — на динамиках ноутбука и в тихих наушниках этого не слышно; теперь у звуков есть «верх», а уровни выровнены
const TRIM := {"cam": 7.0, "static": 6.0, "click": 5.0, "step": 9.0, "step_heavy": 6.0, "door_down": 3.0, "door_up": 4.0,
	"ping": 3.0, "crawl": 7.0, "giggle": 7.0, "heart": 8.0, "whine": 6.0, "babble": 5.0, "fan": 3.0, "hum": 1.0, "buzz": 4.0,
	"crank": 4.0, "clank": 2.0, "vent_bang": 1.0, "power_down": 3.0, "breath": 5.0, "ring": 2.0}

## шина для звука: крики скримеров — отдельная Horror (с ограничителем, через SFX), остальное — как просит вызов
static func bus_for(id: String, want: String) -> String:
	if (id.begins_with("scream_") or id == "sting_lose") and AudioServer.get_bus_index("Horror") >= 0:
		return "Horror"
	return want

## Крики скримеров — готовые многослойные записи (tools/godot-screams.cjs): assets/audio/fn/scream_<кто>_<N>.wav.
## У каждого обитателя несколько вариантов; подряд один и тот же не играет. Нет файлов — старый синтез.
const SCREAM_DIR := "res://assets/audio/fn/"
static var _scream_n := {}
static var _scream_last := {}

static func scream_count(kind: String) -> int:
	if not _scream_n.has(kind):
		var n := 0
		while ResourceLoader.exists("%sscream_%s_%d.wav" % [SCREAM_DIR, kind, n + 1]):
			n += 1
		_scream_n[kind] = n
	return int(_scream_n[kind])

## kind — "balon", "ghost", …; возвращает [поток, номер варианта]
static func scream_pick(kind: String) -> Array:
	var n := scream_count(kind)
	if n <= 0:
		return [get_stream("scream_" + kind), 0]
	var k := randi() % n
	if n > 1 and k == int(_scream_last.get(kind, -1)):
		k = (k + 1 + randi() % (n - 1)) % n
	_scream_last[kind] = k
	return [load("%sscream_%s_%d.wav" % [SCREAM_DIR, kind, k + 1]), k + 1]

static func trim(id: String) -> float:
	return float(TRIM.get(id, 0.0))

static func get_stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s := _make(id)
	_cache[id] = s
	return s

## все звуки заранее — чтобы скример не ждал синтеза
static func warm() -> void:
	for id in ["hum", "fan", "buzz", "whine", "click", "door_down", "door_up", "step", "step_heavy", "clank", "scrape", "crawl",
			"vent_bang", "whisper", "giggle", "ring", "static", "ping", "power_down", "crank", "chime", "babble", "cam",
			"scream_balon", "scream_madk1d", "scream_bot", "scream_clipper", "scream_ghost", "scream_mod", "scream_dark", "scream_pahan", "breath", "heart", "music_box_air",
			"sting_night", "sting_lose", "knock", "drip", "creak", "toy"]:
		get_stream(id)

static func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

## плавные края петли — без щелчка на стыке
static func _loop_fade(b: PackedFloat32Array, sec := 0.05) -> void:
	var n := int(sec * RATE)
	for i in n:
		var k := float(i) / float(n)
		var j := b.size() - n + i
		b[i] = b[i] * k + b[j] * (1.0 - k)

static func _make(id: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"hum":            # низкий гул здания: две близкие ноты биением + дальний шум
			var b := _buf(6.0)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1, 1) - lp) * 0.02
				b[i] = 0.32 * sin(TAU * 41.0 * t) + 0.22 * sin(TAU * 41.5 * t + 1.0) + 0.1 * sin(TAU * 82.3 * t) + lp * 0.5
				# середина: дроссели ламп (120/240/360 Гц, плавают) и сухой воздух — то, что слышно и на маленьких динамиках
				b[i] += (0.07 * sin(TAU * 120.0 * t) + 0.05 * sin(TAU * 240.3 * t + 0.4) + 0.03 * sin(TAU * 361.0 * t)) * (0.75 + 0.25 * sin(TAU * 0.5 * t)) + rng.randf_range(-1, 1) * 0.025
			_loop_fade(b, 0.4)
			return _wav(b, true)
		"fan":            # старая вентиляция: шум с ритмом лопастей
			var b := _buf(4.0)
			var lp := 0.0
			var lp2 := 0.0
			for i in b.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1, 1) - lp) * 0.08
				lp2 += (lp - lp2) * 0.2
				b[i] = lp2 * (0.7 + 0.3 * sin(TAU * 7.5 * t)) * 0.9 + 0.04 * sin(TAU * 120.0 * t)
				b[i] += (lp - lp2) * 0.5 * (0.5 + 0.5 * sin(TAU * 7.5 * t)) + 0.02 * sin(TAU * (640.0 + 30.0 * sin(TAU * 0.2 * t)) * t)   # свист лопастей
			_loop_fade(b, 0.3)
			return _wav(b, true)
		"buzz":           # лампа и фонари: 50 Гц с гармониками и треском
			var b := _buf(3.0)
			for i in b.size():
				var t := float(i) / RATE
				var x := 0.3 * sin(TAU * 100.0 * t) + 0.15 * sin(TAU * 200.0 * t) + 0.08 * signf(sin(TAU * 50.0 * t))
				if rng.randf() < 0.0006:
					x += rng.randf_range(-0.8, 0.8)
				b[i] = x * 0.5
			_loop_fade(b, 0.1)
			return _wav(b, true)
		"whine":          # писк монитора
			var b := _buf(2.0)
			for i in b.size():
				var t := float(i) / RATE
				b[i] = 0.12 * sin(TAU * 7800.0 * t) + 0.03 * rng.randf_range(-1, 1)
			_loop_fade(b, 0.1)
			return _wav(b, true)
		"click":          # реле
			var b := _buf(0.08)
			for i in b.size():
				var e := exp(-float(i) / 120.0)
				b[i] = (rng.randf_range(-1, 1) * 0.7 + sin(float(i) * 0.9) * 0.5) * e
			return _wav(b)
		"cam":            # переключение камеры: щелчок и вспышка помех
			var b := _buf(0.22)
			for i in b.size():
				var t := float(i) / RATE
				b[i] = rng.randf_range(-1, 1) * 0.5 * exp(-t * 18.0) + (0.6 * exp(-float(i) / 90.0) * sin(float(i) * 0.7))
			return _wav(b)
		"door_down", "door_up":   # тяжёлая дверь: гул привода, удар, звон металла
			var b := _buf(1.1)
			var down := id == "door_down"
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var x := 0.0
				if t < 0.32:
					var f := lerpf(70.0, 46.0, t / 0.32) if down else lerpf(46.0, 72.0, t / 0.32)
					x += 0.35 * (fposmod(t * f, 1.0) * 2.0 - 1.0) * (0.6 + 0.4 * sin(TAU * 13.0 * t))
					x += 0.12 * sin(TAU * (lerpf(980.0, 720.0, t / 0.32) if down else lerpf(700.0, 1020.0, t / 0.32)) * t) * smoothstep(0.0, 0.05, t)   # вой привода
				var ht := t - (0.32 if down else 0.3)
				if ht >= 0.0:
					x += (sin(TAU * 52.0 * ht) * 0.9 + rng.randf_range(-1, 1) * 0.6 * exp(-ht * 30.0)) * exp(-ht * 9.0)
					x += (0.22 * sin(TAU * 317.0 * ht) + 0.16 * sin(TAU * 521.0 * ht) + 0.1 * sin(TAU * 853.0 * ht)) * exp(-ht * 4.5) * (1.0 if down else 0.5)
				lp += (x - lp) * 0.5
				b[i] = lp
				if ht >= 0.0 and ht < 0.12:            # засов: короткий звон металла (без фильтра — ему нужен верх)
					b[i] += (0.3 * sin(TAU * 1730.0 * ht) + 0.22 * sin(TAU * 2610.0 * ht) + rng.randf_range(-1, 1) * 0.3) * exp(-ht * 45.0)
			return _wav(b)
		"step", "step_heavy":
			var b := _buf(0.4)
			var hv := id == "step_heavy"
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var x := sin(TAU * (48.0 if hv else 70.0) * t) * exp(-t * (9.0 if hv else 16.0)) * (1.3 if hv else 0.8)
				x += rng.randf_range(-1, 1) * exp(-t * 25.0) * 0.5
				if t > 0.12:
					x += rng.randf_range(-1, 1) * 0.12 * exp(-(t - 0.12) * 14.0)      # шарканье
				lp += (x - lp) * 0.25
				b[i] = lp
				# слышимая часть шага: стук каблука (сухой щелчок) и скрип пола — без них шаг на ноутбуке не слышен
				var n := rng.randf_range(-1, 1)
				b[i] += (n * 0.45 + sin(TAU * (1900.0 if not hv else 1150.0) * t) * 0.3) * exp(-t * (90.0 if not hv else 60.0))
				b[i] += sin(TAU * (170.0 if not hv else 120.0) * t) * exp(-t * 22.0) * 0.5
				if hv and t > 0.05:
					b[i] += 0.08 * sin(TAU * (560.0 + 80.0 * t) * t) * exp(-(t - 0.05) * 9.0)     # половица
			return _wav(b)
		"clank":          # металлический шаг BOT
			var b := _buf(0.6)
			for i in b.size():
				var t := float(i) / RATE
				b[i] = (0.4 * sin(TAU * 211.0 * t) + 0.3 * sin(TAU * 347.0 * t) + 0.25 * sin(TAU * 593.0 * t) + 0.2 * sin(TAU * 1210.0 * t)) * exp(-t * 7.0) \
					+ sin(TAU * 60.0 * t) * exp(-t * 14.0) * 0.8 + rng.randf_range(-1, 1) * exp(-t * 40.0) * 0.4
			return _wav(b)
		"scrape":         # лезвие по стене: сухой скрежет с «зубьями»
			var b := _buf(1.1)
			var bp1 := 0.0
			var bp2 := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var n := rng.randf_range(-1, 1)
				bp1 += (n - bp1) * 0.35
				bp2 += (bp1 - bp2) * 0.35
				var teeth := 0.55 + 0.45 * signf(sin(TAU * (34.0 + 20.0 * t) * t))
				var tone := 0.25 * sin(TAU * (2300.0 + 600.0 * sin(t * 3.0)) * t)
				b[i] = ((bp1 - bp2) * 2.2 * teeth + tone * teeth) * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.85, 1.1, t))
			return _wav(b)
		"crawl":          # ползёт по шахте: царапанье и глухие толчки
			var b := _buf(1.6)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var ph := fposmod(t * 2.6, 1.0)
				var burst := exp(-ph * 9.0)
				lp += (rng.randf_range(-1, 1) - lp) * 0.3
				b[i] = lp * burst * 0.9 + sin(TAU * 90.0 * t) * exp(-ph * 22.0) * 0.4
				b[i] += (0.18 * sin(TAU * 1340.0 * t) + 0.12 * sin(TAU * 2170.0 * t)) * exp(-ph * 14.0) * (0.6 + 0.4 * sin(TAU * 37.0 * t))   # жесть дребезжит
			return _wav(b)
		"vent_bang":      # удар по жести решётки
			var b := _buf(0.9)
			for i in b.size():
				var t := float(i) / RATE
				var x := (0.4 * sin(TAU * 181.0 * t) + 0.35 * sin(TAU * 233.0 * t) + 0.3 * sin(TAU * 412.0 * t) + 0.2 * sin(TAU * 977.0 * t)) * exp(-t * 6.0)
				x += rng.randf_range(-1, 1) * exp(-t * 18.0) * 0.6
				x *= 1.0 + 0.4 * sin(TAU * 31.0 * t)                                     # дребезг
				b[i] = x
			return _wav(b)
		"whisper", "babble":   # шёпот (шум через «гласные») и голос в трубке (бормотание)
			var whisper := id == "whisper"
			var b := _buf(3.0 if whisper else 2.4)
			var f1 := [0.0, 0.0]
			var syl_t := 0.0
			var amp := 0.0
			var fr := 700.0
			for i in b.size():
				var t := float(i) / RATE
				if t >= syl_t:
					syl_t = t + rng.randf_range(0.09, 0.22)
					fr = rng.randf_range(400.0, 1400.0)
				var env := sin(PI * clampf((syl_t - t) / 0.2, 0.0, 1.0))
				amp += (env - amp) * 0.01
				var src: float = rng.randf_range(-1, 1) if whisper else (fposmod(t * rng.randf_range(110.0, 130.0), 1.0) * 2.0 - 1.0) * 0.6 + rng.randf_range(-0.3, 0.3)
				# резонатор (полосовой фильтр) на частоте «гласной»
				var w := TAU * fr / RATE
				var r := 0.97
				var y: float = src * (1.0 - r) + 2.0 * r * cos(w) * f1[0] - r * r * f1[1]
				f1[1] = f1[0]
				f1[0] = y
				b[i] = y * amp * (2.4 if whisper else 1.6)
			return _wav(b)
		"giggle":         # тонкий смешок: короткие писки с дрожью, вниз
			var b := _buf(1.2)
			for i in b.size():
				var t := float(i) / RATE
				var k := fposmod(t * 7.0, 1.0)
				var f := lerpf(900.0, 520.0, t / 1.2) * (1.0 + 0.04 * sin(TAU * 18.0 * t))
				b[i] = sin(TAU * f * t + 2.0 * sin(TAU * f * 0.5 * t)) * exp(-k * 5.0) * 0.4 * (1.0 - t / 1.2)
			return _wav(b)
		"ring":           # телефон
			var b := _buf(2.2)
			for i in b.size():
				var t := float(i) / RATE
				var on := 1.0 if fposmod(t, 1.1) < 0.8 else 0.0
				b[i] = on * 0.35 * (signf(sin(TAU * 420.0 * t)) * 0.5 + sin(TAU * 470.0 * t)) * (0.5 + 0.5 * signf(sin(TAU * 20.0 * t)))
			return _wav(b)
		"static":         # помехи камеры
			var b := _buf(1.5)
			for i in b.size():
				var t := float(i) / RATE
				var x := rng.randf_range(-1, 1) * 0.5
				if rng.randf() < 0.002:
					x *= 3.0
				b[i] = x * (0.8 + 0.2 * sin(TAU * 60.0 * t))
			_loop_fade(b, 0.05)
			return _wav(b, true)
		"ping":           # писк сервера: два коротких
			var b := _buf(0.5)
			for i in b.size():
				var t := float(i) / RATE
				var on := (t < 0.09) or (t > 0.18 and t < 0.27)
				b[i] = (0.35 * signf(sin(TAU * 1250.0 * t)) if on else 0.0)
			return _wav(b)
		"power_down":     # всё гаснет: вой вниз и щелчок
			var b := _buf(2.6)
			for i in b.size():
				var t := float(i) / RATE
				var f := 420.0 * exp(-t * 1.6) + 18.0
				b[i] = (0.45 * sin(TAU * f * t * 0.6) + 0.2 * (fposmod(f * t, 1.0) * 2.0 - 1.0)) * exp(-t * 0.6) + (rng.randf_range(-1, 1) * exp(-t * 40.0))
			return _wav(b)
		"crank":          # рукоятка генератора: трещотка
			var b := _buf(0.25)
			for i in b.size():
				var t := float(i) / RATE
				var k := fposmod(t * 40.0, 1.0)
				b[i] = rng.randf_range(-1, 1) * exp(-k * 14.0) * 0.6 + sin(TAU * 140.0 * t) * exp(-t * 10.0) * 0.3
			return _wav(b)
		"chime":          # шесть утра: свой мотив на «колоколах» (частотная модуляция)
			var notes := [[0.0, 523.25], [0.42, 659.25], [0.84, 587.33], [1.26, 783.99], [1.9, 1046.5], [1.9, 523.25]]
			var b := _buf(4.6)
			for n in notes:
				var st := int(float(n[0]) * RATE)
				for i in range(st, b.size()):
					var t := float(i - st) / RATE
					var f: float = n[1]
					b[i] += sin(TAU * f * t + 2.2 * exp(-t * 2.0) * sin(TAU * f * 1.4 * t)) * exp(-t * 1.3) * 0.22
			return _wav(b)
		"breath":         # тяжёлое дыхание рядом (до скримера в темноте)
			var b := _buf(2.4)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var env := pow(maxf(0.0, sin(PI * fposmod(t / 1.2, 1.0))), 2.0)
				lp += (rng.randf_range(-1, 1) - lp) * 0.12
				b[i] = lp * env * 1.2
			_loop_fade(b, 0.05)
			return _wav(b, true)
		"heart":          # сердце — тише, ближе к концу «последнего шанса»
			var b := _buf(0.9)
			for i in b.size():
				var t := float(i) / RATE
				var a := exp(-t * 18.0) if t < 0.2 else exp(-(t - 0.22) * 16.0) * (1.0 if t >= 0.22 else 0.0) * 0.7
				b[i] = sin(TAU * 52.0 * t) * a + sin(TAU * 104.0 * t) * a * 0.5 + rng.randf_range(-1, 1) * a * a * 0.25
			_loop_fade(b, 0.02)
			return _wav(b, true)
		"music_box_air":  # «последний шанс»: Балон шипит вентилем — неровная мелодия свистом воздуха
			var melody := [0, 3, 7, 6, 3, 0, -2, 0]
			var b := _buf(6.4)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var k := int(t / 0.8) % melody.size()
				var f := 392.0 * pow(2.0, float(melody[k]) / 12.0) * (1.0 + 0.012 * sin(TAU * 5.0 * t))
				var ph := fposmod(t, 0.8) / 0.8
				lp += (rng.randf_range(-1, 1) - lp) * 0.6
				b[i] = (sin(TAU * f * t) * 0.25 + lp * 0.15) * (0.3 + 0.7 * exp(-ph * 2.0)) * (0.6 + 0.4 * sin(TAU * 0.33 * t))
			_loop_fade(b, 0.1)
			return _wav(b, true)
		"sting_night":    # начало ночи: низкий гул нарастает, сверху — неровный колокол (полутон вниз)
			var b := _buf(4.0)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var sw := smoothstep(0.0, 2.2, t) * (1.0 - smoothstep(3.2, 4.0, t))
				lp += (rng.randf_range(-1, 1) - lp) * 0.04
				var drone := (sin(TAU * 55.0 * t) + 0.6 * sin(TAU * 58.3 * t) + 0.3 * sin(TAU * 110.0 * t + 0.7)) * 0.3 + lp * 0.6
				var bt := maxf(t - 1.6, 0.0)
				var bell := (sin(TAU * 622.3 * bt + 1.8 * exp(-bt * 2.0) * sin(TAU * 870.0 * bt)) + 0.6 * sin(TAU * 587.3 * bt)) * exp(-bt * 1.4) * 0.3 * float(t >= 1.6)
				b[i] = drone * sw + bell
			return _wav(b)
		"sting_lose":     # поражение: удар и кластер, который медленно проваливается вниз
			var b := _buf(3.4)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var d := pow(2.0, -t * 0.35)
				lp += (rng.randf_range(-1, 1) - lp) * 0.3
				var cl := 0.0
				for f in [98.0, 103.8, 146.8, 155.6, 196.0]:
					cl += fposmod(f * d * t, 1.0) * 2.0 - 1.0
				b[i] = cl * 0.09 * exp(-t * 0.7) + sin(TAU * (60.0 + 80.0 * exp(-t * 20.0)) * t) * exp(-t * 3.5) * 0.8 + lp * exp(-t * 12.0) * 0.5
			return _wav(b)
		"knock":          # три стука за спиной — по дереву, глухо и чётко
			var b := _buf(1.3)
			for k in 3:
				var st := int((0.08 + k * 0.32) * RATE)
				for i in range(st, mini(b.size(), st + int(0.25 * RATE))):
					var t := float(i - st) / RATE
					b[i] += (sin(TAU * 190.0 * t) * 0.7 + sin(TAU * 420.0 * t) * 0.35 + rng.randf_range(-1, 1) * 0.4 * exp(-t * 80.0)) * exp(-t * 26.0)
			return _wav(b)
		"toy":            # приманка: пищалка игрушки и обрывок мелодии из динамика комнаты (сквозь камеру — тонко)
			var b := _buf(1.6)
			var notes := [784.0, 988.0, 1175.0, 988.0, 1568.0]
			for i in b.size():
				var t := float(i) / RATE
				var k := mini(int(t / 0.22), notes.size() - 1)
				var tt := fposmod(t, 0.22)
				var f: float = notes[k]
				b[i] = (signf(sin(TAU * f * t)) * 0.25 + sin(TAU * f * 2.0 * t) * 0.2) * exp(-tt * 9.0) * float(t < 1.1)
				if t < 0.2:
					b[i] += sin(TAU * (1800.0 - 900.0 * t / 0.2) * t) * 0.4 * (1.0 - t / 0.2)    # писк пищалки
				b[i] += rng.randf_range(-1, 1) * 0.06
			return _wav(b)
		"drip":           # капля в служебке
			var b := _buf(0.5)
			for i in b.size():
				var t := float(i) / RATE
				b[i] = sin(TAU * (1500.0 + 900.0 * exp(-t * 40.0)) * t) * exp(-t * 22.0) * 0.6
			return _wav(b)
		"creak":          # далёкий скрип двери или металла
			var b := _buf(1.4)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var f := 380.0 + 140.0 * sin(TAU * 0.7 * t) + 40.0 * sin(TAU * 11.0 * t)
				lp += ((fposmod(f * t, 1.0) * 2.0 - 1.0) - lp) * 0.2
				b[i] = lp * sin(PI * t / 1.4) * 0.5 * (0.7 + 0.3 * float(rng.randf() < 0.5))
			return _wav(b)
		_:
			if id.begins_with("scream_"):
				return _scream(id.substr(7), rng)
	return _wav(_buf(0.1))

## крики скримеров — у каждого свой
static func _scream(kind: String, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var b := _buf(1.8)
	var lp := 0.0
	var hp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(1.3, 1.8, t))
		var x := 0.0
		var n := rng.randf_range(-1, 1)
		match kind:
			"balon", "dark":       # шип вентиля и низкий рёв с хрипом
				var f := 88.0 + 30.0 * sin(TAU * 3.0 * t) + (40.0 if kind == "dark" else 0.0)
				var saw := fposmod(f * t, 1.0) * 2.0 - 1.0
				lp += (n - lp) * 0.7
				hp = n - lp
				x = saw * 0.7 * (0.6 + 0.4 * sin(TAU * 31.0 * t)) + hp * 0.6 + sin(TAU * f * 2.01 * t) * 0.3
			"madk1d":              # визг со скрежетом колёс доски
				var f := 820.0 + 520.0 * t + 90.0 * sin(TAU * 9.0 * t)
				x = sin(TAU * f * t + 3.0 * sin(TAU * f * 0.51 * t)) * 0.6 + n * 0.4 * (0.5 + 0.5 * signf(sin(TAU * 47.0 * t)))
			"bot":                 # цифровой: ступени тона, «битый» звук
				var step := floorf(t * 22.0)
				var f := 180.0 + fposmod(step * 137.0, 900.0)
				var sq := signf(sin(TAU * f * t))
				x = floorf(sq * 4.0 + n * 2.0) / 4.0 * 0.6 + signf(sin(TAU * 61.0 * t)) * 0.3
			"clipper":             # металл: неровные частоты вверх и свист лезвия в начале
				var g := 1.0 + t * 0.9
				x = (sin(TAU * 610.0 * g * t) * 0.35 + sin(TAU * 977.0 * g * t) * 0.3 + sin(TAU * 1531.0 * g * t) * 0.25) * (0.7 + 0.3 * sin(TAU * 23.0 * t))
				if t < 0.18:
					x += n * (1.0 - t / 0.18) * 0.9
			"ghost":               # шёпот, растущий в крик (вывернутый)
				var sw := clampf(t / 0.9, 0.0, 1.0)
				lp += (n - lp) * (0.08 + sw * 0.5)
				var f := 300.0 + 1500.0 * sw * sw
				x = lp * (1.0 - sw) * 1.6 + sin(TAU * f * t + 4.0 * sin(TAU * 7.0 * t)) * sw * 0.6
				env *= 0.3 + 0.7 * sw
			"pahan":               # его же голос, растянутый вниз и сорванный в визг, с цифровыми рывками
				var f := 140.0 * pow(2.0, sin(TAU * 0.7 * t) * 0.6) * (1.0 + t * 2.5)
				var saw := fposmod(f * t, 1.0) * 2.0 - 1.0
				var stut := 1.0 if fposmod(t * 14.0, 1.0) > 0.18 else 0.0
				lp += (n - lp) * 0.35
				x = (saw * 0.6 + sin(TAU * f * 2.97 * t) * 0.35 + lp * 0.5) * stut + sin(TAU * 38.0 * t) * 0.4
			"mod":                 # модем: быстрые чередующиеся тона и щелчки
				var bit := int(t * 60.0) % 3
				var f: float = [1270.0, 2100.0, 980.0][bit]
				x = sin(TAU * f * t) * 0.5 + (n * 0.5 if fposmod(t * 8.0, 1.0) < 0.2 else 0.0) + signf(sin(TAU * 350.0 * t)) * 0.15
		b[i] = clampf(x * 1.4, -1.0, 1.0) * env
	return _wav(b)
