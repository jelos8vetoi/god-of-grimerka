## Электрогитара madk1d (стиль «guitar»): ритм, дисторшн, звуковые волны и звук способностей.
## Удары и связки ведёт ядро боя по данным style_guitar.gd; здесь — то, что делает гитару гитарой:
##   ритм       — такт 0,5 с (120 ударов в минуту). Нажатие удара в такт (±0,09 с) даёт «В ТАКТ»: +20 % урона этому удару,
##                +3 СВЭГа и деление шкалы ритма (до четырёх). Мимо такта — ничего не теряешь: драться можно и без ритма.
##   RIFF CANCEL — F после попадания, не дожидаясь окна комбо: тратит одно деление ритма.
##   FINAL TRACK — доступен при четырёх делениях, тратит все.
##   DISTORTION — E при 40 СВЭГа: 8 с урон ×1,3, удары бьют током.
## Все звуки синтезируются здесь (струна Карплуса — Стронга, перегруз, обратная связь) и играют на шине SFX.
class_name Guitar
extends Node

const BEAT := 0.5
const WINDOW := 0.09
const MAX_BARS := 4
const DIST_TIME := 8.0
const DIST_COST := 40.0

var p
var game
var clock := 0.0
var bars := 0                 # шкала ритма
var bars_t := 0.0             # сколько секунд без попадания в такт
var on_beat := false          # текущий удар нажат в такт
var distortion := 0.0
var sounds := {}
var players: Array = []
var beat_i := -1
var events: Array = []        # для проверок: ["beat", 0], ["chord", n]…
var played: Array = []        # какие звуки играли

func setup(player, g) -> void:
	p = player
	game = g
	sounds = {
		"chord": _string_mix([82.4, 123.5, 164.8], 0.9, 3.0),          # квинта от ми: мощный аккорд с перегрузом
		"airriff": _bend(659.3, 880.0, 0.5),                          # высокая нота с подтяжкой вверх
		"feedback": _squeal(1.0),                                     # заводка: нарастающий свист
		"distortion": _string_mix([55.0, 82.4, 110.0], 1.1, 6.0),     # низкий рык
		"riff": _string_mix([110.0, 164.8], 0.16, 4.0),               # глухой «чаг»
		"final": _string_mix([82.4, 123.5, 164.8, 246.9, 329.6], 1.8, 3.5),
		"tick": _tick(),
	}
	for i in 5:
		var a := AudioStreamPlayer.new()
		a.bus = "SFX"
		add_child(a)
		players.append(a)

func active() -> bool:
	return p.hero == "madk1d" and p.style.id == "guitar"

func play(snd: String, db := -4.0, pitch := 1.0) -> void:
	played.append(snd)
	if game.main.testing() != "" and not game.main.audiolog:
		return
	for a in players:
		if not (a as AudioStreamPlayer).playing:
			a.stream = sounds[snd]
			a.volume_db = db
			a.pitch_scale = pitch
			a.play()
			return

func tick(dt: float) -> void:
	distortion = max(0.0, distortion - dt)
	if not active():
		return
	clock += dt
	bars_t += dt
	if bars_t > 4.0 and bars > 0:
		bars -= 1                      # ритм остывает, если долго не попадать в такт
		bars_t = 2.0
	var bi := int(floor(clock / BEAT))
	if bi != beat_i:
		beat_i = bi
		if p.enemies_near(14.0):
			play("tick", -22.0)        # тихий счёт в бою — по нему можно ловить такт
	if distortion > 0.0 and Engine.get_physics_frames() % 9 == 0:
		game.fx.sparks(p.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.4), randf_range(-0.3, 0.3)), Vector3.UP, 2, Color(0.7, 0.85, 1.0), 0.5, 80.0)

## насколько нажатие далеко от ближайшего такта, с
func beat_offset() -> float:
	var ph := fmod(clock, BEAT)
	return min(ph, BEAT - ph)

## игрок нажал удар: в такт или нет
func on_press() -> void:
	if not active():
		return
	on_beat = beat_offset() <= WINDOW
	if on_beat:
		bars = mini(MAX_BARS, bars + 1)
		bars_t = 0.0
		p.swag = min(100.0, p.swag + 3.0)
		game.popup(p.global_position + Vector3(0, 2.5, 0), "В ТАКТ", Color(0.7, 0.9, 1.0))
		events.append(["beat", bars])

## множитель урона: дисторшн и удар в такт
func bonus() -> float:
	return (1.3 if distortion > 0.0 else 1.0) * (1.2 if on_beat else 1.0)

func spend_riff() -> bool:
	if bars < 1:
		return false
	bars -= 1
	play("riff", -6.0)
	game.popup(p.global_position + Vector3(0, 2.5, 0), "RIFF CANCEL", Color(1.0, 0.9, 0.5))
	events.append(["riff", bars])
	return true

func can_use(a: AttackData) -> bool:
	return int(a.extra.get("bars", 0)) <= bars

## DISTORTION
func distort() -> bool:
	if p.swag < DIST_COST:
		game.popup(p.global_position + Vector3(0, 2.2, 0), "нужно 40 СВЭГа", Color(0.7, 0.75, 0.85))
		return false
	p.swag -= DIST_COST
	distortion = DIST_TIME
	play("distortion", -3.0)
	game.banner("DISTORTION", "урон ×1.3 на 8 секунд", Color(0.7, 0.85, 1.0))
	game.fx.lightning(p.global_position, 3.5, Color(0.7, 0.85, 1.0))
	game.shake(0.4)
	p.rig.play_for("MStrum", 0.5, 0.06)
	p.anim_hold = 0.45
	events.append(["distortion", 0])
	return true

## момент атаки: звук и видимая волна способности
func moment(a: AttackData) -> void:
	var snd := String(a.extra.get("sound", ""))
	if snd != "":
		play(snd, -3.0, 1.0)
	if int(a.extra.get("bars", 0)) > 0:
		bars = 0
	var f := Vector3(sin(p.face), 0, cos(p.face))
	var col := Color(0.7, 0.9, 1.0) if distortion <= 0.0 else Color(1.0, 0.85, 0.4)
	var at: Vector3 = p.global_position + Vector3(0, 1.0, 0)
	match String(a.extra.get("wave", "")):
		"cone":
			# направленная волна: кольца уходят вперёд и растут
			for i in 6:
				game.fx.ring(at + f * (0.9 + i * 1.25), 0.9 + i * 0.55, Color(col.r, col.g, col.b, 0.7 - i * 0.09), 0.22 + i * 0.04)
			game.shake(0.2)
		"ring":
			game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.5, a.reach * 2.0, Color(col.r, col.g, col.b, 0.7), 0.4)
			game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.3, a.reach * 1.3, Color(1, 1, 1, 0.5), 0.3)
			game.fx.ring(at, a.reach * 1.2, Color(col.r, col.g, col.b, 0.5), 0.3)
			game.shake(0.3)
		"up":
			for i in 5:
				game.fx.ring(at + f * (0.8 + i * 0.9) + Vector3(0, 0.5 + i * 0.6, 0), 0.8 + i * 0.3, Color(col.r, col.g, col.b, 0.7 - i * 0.1), 0.2 + i * 0.04)
		"final":
			for i in 4:
				game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.4, a.reach * (1.0 + i * 0.5), Color(col.r, col.g, col.b, 0.75 - i * 0.15), 0.35 + i * 0.1)
			game.fx.lightning(p.global_position, 5.0, col)
			game.shake(0.7)
	if snd != "":
		events.append([snd, 0])

## попадание: в дисторшне удар бьёт током; отметка такта потрачена
func on_hit(a: AttackData, n: int) -> void:
	if not active():
		return
	if distortion > 0.0:
		for e in game.enemies:
			if is_instance_valid(e) and e.alive() and e.global_position.distance_to(p.global_position) < a.reach + 1.0 and e.hit_clock > game.clock - 0.1:
				game.fx.lightning(e.global_position, float(e.height) * 1.2, Color(0.7, 0.85, 1.0))
	on_beat = false

func hud() -> String:
	var pulse := "♪" if beat_offset() <= WINDOW else "·"
	return "%s %s%s%s" % [pulse, "●".repeat(bars), "○".repeat(MAX_BARS - bars), "  DISTORTION %.0f" % distortion if distortion > 0.0 else ""]

# ---------------- синтез ----------------
static func _wav(buf: PackedFloat32Array, rate := 22050) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

## щипок струны (Карплус — Стронг): шумовой импульс в кольцевой задержке с усреднением
static func _pluck(freq: float, sec: float, rate := 22050) -> PackedFloat32Array:
	var n := int(sec * rate)
	var m := maxi(2, int(rate / freq))
	var ring := PackedFloat32Array()
	ring.resize(m)
	var rs := int(freq * 131.0) + 7
	for i in m:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		ring[i] = float(rs % 2000) / 1000.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	var k := 0
	for i in n:
		var nx := (k + 1) % m
		var v := (ring[k] + ring[nx]) * 0.4985
		out[i] = ring[k]
		ring[k] = v
		k = nx
	return out

## несколько струн вместе, с перегрузом (drive) и затуханием
static func _string_mix(freqs: Array, sec: float, drive: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(sec * rate)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for f in freqs:
		var s := _pluck(float(f), sec, rate)
		for i in n:
			mix[i] += s[i] / freqs.size()
	for i in n:
		var t := float(i) / n
		var env: float = min(1.0, i / 60.0) * pow(1.0 - t, 1.3)
		mix[i] = tanh(mix[i] * drive * 2.2) * 0.75 * env
	return _wav(mix, rate)

## высокая нота с подтяжкой от f0 к f1
static func _bend(f0: float, f1: float, sec: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(sec * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, smoothstep(0.0, 0.5, t)) * (1.0 + 0.012 * sin(t * sec * TAU * 6.0))
		ph += TAU * f / rate
		var s := sin(ph) + 0.5 * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)
		out[i] = tanh(s * 1.8) * 0.6 * min(1.0, i / 40.0) * pow(1.0 - t, 0.9)
	return _wav(out, rate)

## обратная связь: свист, который нарастает и уходит вверх
static func _squeal(sec: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(sec * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(520.0, 1900.0, t * t) * (1.0 + 0.02 * sin(t * sec * TAU * 9.0))
		ph += TAU * f / rate
		out[i] = (sin(ph) + 0.3 * sin(ph * 2.01)) * 0.55 * sin(t * PI)
	return _wav(out, rate)

static func _tick() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.05 * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rs := 99
	for i in n:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		out[i] = (float(rs % 2000) / 1000.0 - 1.0) * pow(1.0 - float(i) / n, 3.0) * 0.6
	return _wav(out, rate)
