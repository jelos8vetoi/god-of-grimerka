## Team Hype и Team Overdrive (этап 12).
## Team Hype — общая шкала двух героев (0…100). Копится за разнообразную игру: разные удары, удары по врагу в
## воздухе, точное уклонение и парирование, Perfect Swap, командные приёмы и помощь напарника, Freeze, трюки на
## доске, попадания в такт, добивания. Повтор одного и того же ничего не даёт: каждый источник «устаёт»
## (FATIGUE секунд даёт вполовину, затем четверть…), одинаковые удары подряд не считаются. Без подпитки шкала тает.
## Team Overdrive — [G] при полной шкале: короткая (≈3 с) совместная постановка обоих героев:
##   вход → приём стиля активного героя → приём стиля напарника → общий финал → обратно в бой.
## Приёмы зависят от стилей, которые сейчас у героев (MOVES). Герои на это время неуязвимы, обычные враги рядом
## обездвижены. Правила: шкала тратится целиком; нельзя, пока героя бьют, в добивании, в смене стиля, верхом,
## пока напарник выбыл; в первые CANCEL секунды можно отменить уклонением (Shift) — вернётся 60 % шкалы.
## Боссы: не обездвиживаются; за один Overdrive босс теряет не больше BOSS_CAP своего здоровья
## (BOSS_CAP_OPEN, если он «ОТКРЫТ»).
class_name TeamHype
extends Node

signal overdrive_started
signal overdrive_ended(cancelled: bool)

const MAX := 100.0
const FATIGUE := 6.0
const DECAY_AFTER := 7.0
const DECAY := 2.5
const LEN := 3.0
const CANCEL := 0.3
const RANGE := 9.0
const BOSS_CAP := 0.12
const BOSS_CAP_OPEN := 0.18
## сколько даёт каждый источник
const GAIN := {"attack": 1.6, "air": 2.0, "dodge": 6.0, "parry": 8.0, "swap": 7.0, "tag": 9.0, "assist": 6.0, "freeze": 5.0,
	"perfect_freeze": 9.0, "trick": 5.0, "beat": 1.5, "execution": 10.0, "team_finisher": 6.0, "duo": 8.0, "duo_break": 4.0}
## приём стиля в постановке: клип героя, чем кончается и подпись
const MOVES := {
	"vozduh": {"title": "ГУЛ БАЛОНА", "clip": "Smash", "t": 0.6, "fx": "slam"},
	"bottles": {"title": "ЗАЛП", "clip": "BottleThrowHeavy", "t": 0.55, "fx": "splash"},
	"tyaga812": {"title": "ВОРОНКА", "clip": "TyagaSuck", "t": 0.6, "fx": "pull"},
	"skateboard": {"title": "ПРОЕЗД", "clip": "MSpin", "t": 0.55, "fx": "dash"},
	"guitar": {"title": "СОЛО", "clip": "GtStrum", "t": 0.55, "fx": "chord"},
	"breaker": {"title": "ВЕРТУШКА", "clip": "Helicopter", "t": 0.6, "fx": "launch"},
}
const BEATS := [0.35, 0.95, 1.55, 2.3]      # вход, приём героя, приём напарника, финал

var game
var p
var b
var value := 0.0
var idle_t := 0.0
var recent: Array = []            # последние удары: одинаковые подряд не считаются
var tired := {}                   # источник → [когда был, сколько раз подряд]
var seen := {"breaker": 0, "skate": 0, "guitar": 0, "tag": 0}
var on := false
var gain_k := 1.0             # множитель накопления (артефакт «Энергетик» в приквеле)
var t := 0.0
var beat_i := 0
var targets: Array = []
var boss_left := {}               # босс → сколько урона ему ещё можно нанести за этот Overdrive
var center := Vector3.ZERO
var snd: AudioStreamPlayer
var events: Array = []            # для проверок: [что, значение]
var log_gain: Array = []          # [источник, сколько дали]

func setup(g) -> void:
	game = g
	p = g.player
	b = g.buddy
	p.combat.attack_hit.connect(_on_hit)
	game.feedback_fired.connect(_on_feedback)
	p.flow.swapped.connect(func(_from: String, _to: String, perfect: bool) -> void:
		if perfect:
			gain("swap"))
	game.tag.tagged.connect(func(_hero: String, move: String) -> void:
		if move != "":
			gain("tag"))
	p.execution.executed.connect(func(_e, _style: String, _ctx: String) -> void: gain("execution"))
	snd = AudioStreamPlayer.new()
	snd.stream = _synth()
	snd.bus = "SFX"
	snd.volume_db = -3.0
	add_child(snd)

# ---------------- накопление ----------------
## Начислить за источник. Тот же источник снова в течение FATIGUE секунд даёт вдвое меньше, потом вчетверо…
func gain(src: String, mul := 1.0) -> float:
	if on or not GAIN.has(src) or game.madk_locked():
		return 0.0             # приквел до первой концовки: Team Hype закрыт вместе с madk1d
	var now: float = game.clock
	var n := 0
	if tired.has(src) and now - float(tired[src][0]) < FATIGUE:
		n = int(tired[src][1]) + 1
	tired[src] = [now, n]
	var v: float = (float(GAIN[src]) * mul * pow(0.5, n) if src != "attack" and src != "beat" and src != "air" else float(GAIN[src]) * mul) * gain_k
	value = min(MAX, value + v)
	idle_t = 0.0
	log_gain.append([src, v])
	return v

func _on_hit(a: AttackData, n: int) -> void:
	if n <= 0 or on:
		return
	# разнообразие: удар считается, только если его не было среди четырёх последних
	if not recent.has(a.id):
		gain("attack")
		var e = game.tag.target()
		if e != null and e.state == "air":
			gain("air")
	recent.append(a.id)
	if recent.size() > 4:
		recent.pop_front()

func _on_feedback(nm: String, _pos: Vector3, _power: float) -> void:
	if nm == "perfect_dodge":
		gain("dodge")
	elif nm == "parry":
		gain("parry")

## события стилей и команды, которые не шлют сигналов: читаем их журналы
func _poll() -> void:
	var br: Array = p.breaker.events
	while int(seen["breaker"]) < br.size():
		var ev: Array = br[int(seen["breaker"])]
		seen["breaker"] = int(seen["breaker"]) + 1
		if ev[0] == "perfect":
			gain("perfect_freeze")
		elif ev[0] == "freeze" and int(ev[1]) >= 2:
			gain("freeze")
	var sk: Array = p.skate.events
	while int(seen["skate"]) < sk.size():
		var ev2: Array = sk[int(seen["skate"])]
		seen["skate"] = int(seen["skate"]) + 1
		if ev2[0] == "trick":
			gain("trick")
	var gt: Array = p.guitar.events
	while int(seen["guitar"]) < gt.size():
		var ev3: Array = gt[int(seen["guitar"])]
		seen["guitar"] = int(seen["guitar"]) + 1
		if ev3[0] == "beat":
			gain("beat")
	var tg: Array = game.tag.events
	while int(seen["tag"]) < tg.size():
		var ev4: Array = tg[int(seen["tag"])]
		seen["tag"] = int(seen["tag"]) + 1
		if ev4[0] in ["cross", "air"]:
			gain("assist")
		elif ev4[0] == "duo_end":
			gain("duo")
		elif ev4[0] == "duo_break":
			gain("duo_break")
		elif ev4[0] == "duo_finisher":
			gain("team_finisher")
		elif ev4[0] == "finisher":
			gain("team_finisher")
	# журналы чистят проверки — не отстать от них
	for k in seen:
		var arr: Array = {"breaker": br, "skate": sk, "guitar": gt, "tag": tg}[k]
		if int(seen[k]) > arr.size():
			seen[k] = arr.size()

func full() -> bool:
	return value >= MAX

# ---------------- Overdrive ----------------
## Почему сейчас нельзя ("" — можно)
func block() -> String:
	if game.madk_locked():
		return "locked"
	if on:
		return "active"
	if not full():
		return "hype"
	if game.paused_story() or game.over:
		return "story"
	if game.tag.down[game.tag.mate()]:
		return "down"
	if p.switch_to != "":
		return "switch"
	if p.state == "tyaga" and p.tyaga.riding():
		return "riding"
	if not p.state in ["move", "block", "attack", "tyaga"]:
		return p.state
	return ""

func try_start() -> bool:
	var why := block()
	if why != "":
		events.append(["blocked", why])
		if why == "locked":
			game.madk_note()
		if why == "hype" and game.clock - _msg_t > 1.0:
			_msg_t = game.clock
			game.popup(p.global_position + Vector3(0, 2.3, 0), "HYPE %d%%" % int(value), Color(0.75, 0.78, 0.85))
		return false
	_begin()
	return true
var _msg_t := -9.0

func _begin() -> void:
	on = true
	t = 0.0
	beat_i = 0
	value = MAX
	p.combat.interrupt()
	p.state = "overdrive"
	p.t = 0.0
	p.inv = max(p.inv, LEN + 0.6)
	p.spin_off = 0.0
	p.velocity = Vector3.ZERO
	p.anim_hold = LEN
	# кто попадает под раздачу: до шести ближайших врагов
	targets = []
	boss_left = {}
	var list: Array = []
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and e.state != "spawn" and e.global_position.distance_to(p.global_position) < RANGE:
			list.append(e)
	list.sort_custom(func(x, y): return x.global_position.distance_to(p.global_position) < y.global_position.distance_to(p.global_position))
	targets = list.slice(0, 6)
	center = p.global_position + Vector3(sin(p.face), 0, cos(p.face)) * 2.5
	if targets.size() > 0:
		center = Vector3.ZERO
		for e in targets:
			center += e.global_position
		center /= targets.size()
		center.y = 0.05
	for e in targets:
		if e.boss_id != "":
			boss_left[e] = e.max_hp * (BOSS_CAP_OPEN if e.weak_t > 0.0 else BOSS_CAP)
		else:
			e.hold(LEN)
	var to: Vector3 = center - p.global_position
	to.y = 0
	if to.length() > 0.2:
		p.face = atan2(to.x, to.z)
	game.banner("TEAM OVERDRIVE", "%s + %s" % [_move(p.style.id)["title"], _move(_mate_style())["title"]], Color(1.0, 0.86, 0.5))
	game.slowmo(0.25)
	game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.4, 6.0, Color(1.0, 0.86, 0.5, 0.7), 0.5)
	game.fx.ground_ring(b.global_position + Vector3(0, 0.05, 0), 0.4, 6.0, Color(0.5, 0.85, 1.0, 0.7), 0.5)
	p.rig.play_role_for("tag_in", 0.35, 0.06)
	if game.main.testing() == "" or game.main.audiolog:
		snd.play()
	events.append(["start", targets.size()])
	overdrive_started.emit()

func _mate_style() -> String:
	return String(p.heroes[game.tag.mate()]["style"])

func _move(style_id: String) -> Dictionary:
	return MOVES.get(style_id, MOVES["vozduh"])

func active() -> bool:
	return on

## насколько камера в постановке (0…1) — для game.gd: общий план и облёт
func cam_k() -> float:
	if not on:
		return 0.0
	return clampf(min(t / 0.3, (LEN - t) / 0.35), 0.0, 1.0)

func _physics_process(dt: float) -> void:
	if game == null or p == null:
		return
	_poll()
	if not on:
		if game.paused_story() or game.over:
			return
		idle_t += dt
		if idle_t > DECAY_AFTER and value > 0.0 and value < MAX:
			value = max(0.0, value - DECAY * dt)       # полная шкала не тает: её надо потратить
		return
	t += dt
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.inv = max(p.inv, 0.3)
	game.cam_yaw += dt * 0.85                     # камера обходит команду
	if p.state != "overdrive":                     # состояние сбили извне (сюжет, гибель) — выйти
		_end(true)
		return
	# отмена в самом начале — уклонением
	if t < CANCEL and p.pressed("roll"):
		value = MAX * 0.6
		_end(true)
		return
	while beat_i < BEATS.size() and t >= float(BEATS[beat_i]):
		_beat(beat_i)
		beat_i += 1
	if t >= LEN:
		_end(false)

func _alive_targets() -> Array:
	return targets.filter(func(e): return is_instance_valid(e) and e.alive())

## удар постановки по одной цели: боссу — в пределах его лимита
func _hit(e, dmg: float, stagger: float, dir: Vector3, knock: float, launch: float, power: int, measure_id := "team_overdrive", measure_hero := "") -> void:
	if not is_instance_valid(e) or not e.alive():
		return
	if e.boss_id != "":
		# лимит — по реально снятому здоровью: «ОТКРЫТ» (×1,3 в enemy.take_hit_info) его не обходит
		var k: float = 1.3 if e.weak_t > 0.0 else 1.0
		dmg = min(dmg, float(boss_left.get(e, 0.0)) / k)
		if dmg <= 0.0:
			return
		var before: float = e.hp
		game.tag.strike(e, dmg, stagger, dir, knock, launch, power >= 1, power, true, measure_id, measure_hero)
		boss_left[e] = float(boss_left.get(e, 0.0)) - maxf(0.0, before - e.hp)
		return
	game.tag.strike(e, dmg, stagger, dir, knock, launch, power >= 1, power, true, measure_id, measure_hero)

func _beat(i: int) -> void:
	var list := _alive_targets()
	var gold := Color(1.0, 0.86, 0.5)
	match i:
		0:
			# вход: напарник появляется с другой стороны толпы, бьют оба
			var side: Vector3 = center - p.global_position
			side.y = 0
			side = side.normalized() if side.length() > 0.2 else Vector3(sin(p.face), 0, cos(p.face))
			b.blink(center + side * 2.4, -side)
			b.strike_anim("hit", center)
			p.rig.play_role_for("light", 0.4, 0.05)
			for e in list:
				_hit(e, 12.0, 20.0, (e.global_position - p.global_position).normalized(), 1.0, 0.0, 0)
			game.shake(0.15)
		1:
			_style_move(p.style.id, true, list)
		2:
			_style_move(_mate_style(), false, list)
		3:
			# финал: оба бьют вместе
			var m: Dictionary = _move(p.style.id)
			p.rig.play_for(String(m["clip"]), 0.55, 0.05)
			b.strike_anim("heavy", center)
			for e in list:
				var d: Vector3 = e.global_position - center
				d.y = 0
				d = d.normalized() if d.length() > 0.1 else Vector3(sin(p.face), 0, cos(p.face))
				_hit(e, 40.0, 70.0, d, 9.0, 6.0, 2)
			game.fx.slam(center, 1.8, gold)
			game.fx.duo_finale(center + Vector3(0, 1.2, 0), String(p.style.id), String(p.heroes[game.tag.mate()]["style"]), Vector3(sin(p.face), 0, cos(p.face)), 1.7)
			game.fx.ground_ring(center, 0.5, 9.0, Color(1.0, 0.86, 0.5, 0.8), 0.5)
			game.fx.lightning(center, 5.0, Color(0.5, 0.85, 1.0))
			game.hitstop(0.12)
			game.shake(0.45)
			game.punch(0.8, center + Vector3(0, 1.0, 0))
			game.main.sfx("sfx_boom", 0.0, 0.8)
			events.append(["finale", list.size()])

## Приём стиля в постановке: who — активный герой (true) или напарник
func _style_move(style_id: String, mine: bool, list: Array) -> void:
	var actor: String = p.hero if mine else b.look
	var measure_id := "overdrive_" + style_id
	game.measure_use(actor, "team", measure_id)
	var m: Dictionary = _move(style_id)
	var col: Color = Styles.by_id(style_id).color_hot
	var at: Vector3 = p.global_position if mine else b.global_position
	if mine:
		p.rig.play_for(String(m["clip"]), float(m["t"]), 0.05)
	else:
		b.strike_anim("heavy", center)
	game.popup(at + Vector3(0, 2.5, 0), String(m["title"]), col)
	for e in list:
		var d: Vector3 = e.global_position - at
		d.y = 0
		d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
		var hp_at: Vector3 = e.global_position + Vector3(0, e.height * 0.6, 0)
		match String(m["fx"]):
			"slam":
				_hit(e, 16.0, 35.0, d, 2.0, 0.0, 1, measure_id, actor)
			"splash":
				game.fx.sparks(hp_at, Vector3.UP, 10, Color(0.6, 0.85, 1.0), 1.0, 70.0)
				e.slow(3.0)
				_hit(e, 14.0, 20.0, d, 2.0, 0.0, 1, measure_id, actor)
			"pull":
				if e.boss_id == "":
					e.global_position = e.global_position.lerp(Vector3(center.x, e.global_position.y, center.z), 0.75)
				_hit(e, 12.0, 25.0, -d, 0.5, 0.0, 1, measure_id, actor)
			"dash":
				game.fx.sparks(hp_at, d.cross(Vector3.UP), 8, col, 1.2, 25.0)
				_hit(e, 15.0, 30.0, d.cross(Vector3.UP), 3.0, 0.0, 1, measure_id, actor)
			"chord":
				game.fx.lightning(e.global_position, 3.0, col)
				_hit(e, 15.0, 30.0, d, 2.0, 0.0, 1, measure_id, actor)
			"launch":
				_hit(e, 14.0, 20.0, d, 1.0, 6.5, 1, measure_id, actor)
	match String(m["fx"]):
		"slam":
			game.fx.slam(center, 1.2, col)
			game.main.sfx("sfx_boom", -4.0, 1.1)
		"splash":
			game.fx.ground_ring(center, 0.4, 6.0, Color(0.6, 0.85, 1.0, 0.6), 0.4)
			p.bottles._play_splash(center + Vector3(0, 1.0, 0))
		"pull":
			game.fx.ground_ring(center, 6.0, 0.6, Color(0.85, 0.93, 1.0, 0.6), 0.4)
			game.main.sfx("sfx_roll", -3.0, 0.6)
		"dash":
			game.fx.ground_ring(center, 0.4, 5.0, Color(col.r, col.g, col.b, 0.6), 0.3)
			game.main.sfx("sfx_roll", -3.0, 1.4)
		"chord":
			p.guitar.play("chord", -3.0, 1.0)
		"launch":
			game.fx.twinkle(center + Vector3(0, 1.2, 0), 14, col, 1.6)
	game.shake(0.2)
	events.append(["move", style_id])

func _end(cancelled: bool) -> void:
	on = false
	if not cancelled:
		value = 0.0
	tired = {}
	recent = []
	if p.state == "overdrive":
		p.state = "move"
	p.anim_hold = 0.0
	p.inv = max(p.inv, 0.6)
	if cancelled and snd.playing:
		snd.stop()
	events.append(["end", 1 if cancelled else 0])
	overdrive_ended.emit(cancelled)

## Звук постановки: гул, четыре удара по долям и растущий свист к финалу — синтез, как у гитары и пылесоса
func _synth() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * (LEN + 0.6))
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var tt := float(i) / rate
		var s := 0.0
		# гул-основа: две ноты с биением, громче к финалу
		var rise := clampf(tt / float(BEATS[3]), 0.0, 1.0)
		ph += TAU * (55.0 + 27.0 * rise) / rate
		ph2 += TAU * (82.5 + 41.0 * rise * rise) / rate
		s += (sin(ph) * 0.3 + sin(ph2) * 0.18) * (0.35 + 0.65 * rise) * clampf((LEN + 0.5 - tt) / 0.5, 0.0, 1.0)
		# удары по долям
		for j in BEATS.size():
			var dt: float = tt - float(BEATS[j])
			if dt >= 0.0 and dt < 0.5:
				var amp := (1.0 if j == 3 else 0.6) * exp(-dt * (6.0 if j == 3 else 11.0))
				s += sin(TAU * (90.0 - 50.0 * min(dt * 5.0, 1.0)) * dt) * amp
				s += (fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) - 0.5) * amp * 0.5 * exp(-dt * 30.0)
		# свист к финалу
		if tt > 1.2 and tt < float(BEATS[3]):
			var k := (tt - 1.2) / (float(BEATS[3]) - 1.2)
			s += sin(TAU * (300.0 + 900.0 * k * k) * tt) * 0.08 * k
		var v := int(clampf(s * 0.7, -1.0, 1.0) * 32000.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
