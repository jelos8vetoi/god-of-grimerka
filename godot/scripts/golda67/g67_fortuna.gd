## Бой FORTUNA 812 («ГОЛДА 67», район ПОДЗЕМКА, PODZEMKA_DESIGN раздел 5): пять приёмов с метками на полу.
##   f_gates   ТУРНИКЕТЫ      — линия мигает 1,2 с, закрывается на 6 с, одна секция открыта (зелёная); фаза 2 — две линии; фаза 3 — хлопки вразнобой
##   f_zone    ПЛАТНАЯ ЗОНА   — 6 × 4 м, проявляется 1,0 с, 8 с: у героя -3 голды / 0,5 с (нет голды — 4 урона); босс внутри теряет 1 %; фаза 2 — зона ползёт 1,5 м/с
##   f_check   ЧЕК            — замах 0,6 с, полоса 1,2 × 12 м на 7 с, замедление; в прыжке не действует; фаза 2 — две полосы крест-накрест
##   f_change  СДАЧА          — 0,7 с, веер из 7 монет конусом 70°, 9 урона за монету; фаза 2 — два веера
##   f_consult КОНСУЛЬТАЦИЯ   — уходит к кассе, стекло, большая зона, лечит 1,5 %/с пока герой в зоне (до 8 с); вышел из зоны / стекло разбито → оглушён 2,5 с
## Запускаются из BossMoves.start (состояние босса "special", события по времени e._at). Арена и её объекты — g67_fortuna_arena.gd (game.golda.arena).
class_name G67Fortuna
extends RefCounted

const MOVES := [[], [], []]
const TITLES := {"f_gates": "ТУРНИКЕТЫ", "f_zone": "ПЛАТНАЯ ЗОНА", "f_check": "ЧЕК", "f_change": "СДАЧА", "f_consult": "КОНСУЛЬТАЦИЯ"}

const GATE_FLASH := 1.2
const GATE_HOLD := 6.0
const ZONE_SIZE := Vector2(6.0, 4.0)
const ZONE_FADE := 1.0
const ZONE_LIVE := 8.0
const ZONE_CREEP := 1.5
const CHECK_WARN := 0.6
const CHECK_W := 1.2
const CHECK_L := 12.0
const CHECK_LIVE := 7.0
const CHANGE_WARN := 0.7
const CHANGE_COINS := 7
const CHANGE_CONE := 1.2217      # 70°
const CHANGE_DMG := 7.0
const CONSULT_MAX := 8.0
const CONSULT_HEAL := 0.015      # доля максимума в секунду
const CONSULT_ZONE := Vector2(10.0, 7.0)
const CONSULT_STUN := 2.5
const CONSULT_HP_GATE := 0.8     # консультация доступна ниже 80 % здоровья
const PIN_OPEN := 2.0
const EXHALE := 1.2                  # «выдох» после ЧЕКА и СДАЧИ: босс пересчитывает на калькуляторе, открыт (окно урона)
const PAUSES := [2.4, 2.0, 1.6]      # пауза между приёмами по фазам, с
const NO_ZONE_FIRST := 8.0           # в первые секунды боя платных зон нет
const CYCLE := ["f_gates", "f_zone", "f_check", "f_change"]

const LINES := {
	"start": "Оплата на месте.", "gates": "Проход закрыт. Временно. Навсегда.", "zone": "С вас за постоять.", "zone2": "Счётчик тикает!",
	"zone_boss": "Тариф для владельца… Кто это придумал?! А. Я.", "check": "Ваш чек. Сохраняйте до конца жизни.", "change": "Сдачи не надо? А я дам!",
	"consult": "Минуточку, у меня консультация.", "glass": "Это было бронированное! По документам!", "phase2": "Вводим повышенный тариф.",
	"phase3": "Что с турникетами?! Они же на гарантии!", "pinned": "Это недопустимо! Это нарушение бизнес-процесса!",
	"broke": "Клиент неплатёжеспособен. Переходим к взысканию.",
}

static func clips() -> Dictionary:
	var en := Callable(Poses, "en")
	var calc: Dictionary = en.call({"spine": {"x": 0.04}, "rarm": {"x": -0.55, "z": -0.15}, "rfa": {"x": -1.3}, "larm": {"x": -0.2, "z": 0.2}, "lfa": {"x": -0.5}, "head": {"x": 0.12}})
	var calc2: Dictionary = en.call({"spine": {"x": 0.06}, "rarm": {"x": -0.6, "z": -0.15}, "rfa": {"x": -1.4}, "larm": {"x": -0.2, "z": 0.2}, "lfa": {"x": -0.5}, "head": {"x": 0.18, "y": 0.1}})
	var tape1: Dictionary = en.call({"spine": {"x": -0.18, "y": 0.35}, "rarm": {"x": -2.2, "z": -0.4}, "rfa": {"x": -0.4}, "larm": {"x": -0.4, "z": 0.3}})
	var tape2: Dictionary = en.call({"spine": {"x": 0.28, "y": -0.4}, "rarm": {"x": -1.2, "z": 0.2}, "rfa": {"x": -0.1}, "larm": {"x": -0.2, "z": 0.3}})
	var coins1: Dictionary = en.call({"spine": {"x": 0.15}, "rarm": {"x": 0.2, "z": -0.9}, "larm": {"x": 0.2, "z": 0.9}, "rfa": {"x": -0.9}, "lfa": {"x": -0.9}})
	var coins2: Dictionary = en.call({"spine": {"x": 0.12}, "rarm": {"x": -0.7, "z": -1.2}, "larm": {"x": -0.7, "z": 1.2}, "rfa": {"x": -0.2}, "lfa": {"x": -0.2}})
	var snap1: Dictionary = en.call({"spine": {"x": -0.1}, "rarm": {"x": -1.6, "z": -0.5}, "rfa": {"x": -1.7}, "head": {"x": -0.1}})
	var snap2: Dictionary = en.call({"spine": {"x": 0.1, "y": 0.2}, "rarm": {"x": -1.1, "z": -1.3}, "rfa": {"x": -0.2}, "larm": {"x": -0.3, "z": 0.4}})
	var point1: Dictionary = en.call({"spine": {"x": 0.3}, "rarm": {"x": -0.2, "z": -0.15}, "rfa": {"x": -0.1}, "head": {"x": 0.3}, "larm": {"x": -0.3, "z": 0.3}})
	var point2: Dictionary = en.call({"spine": {"x": 0.38}, "rarm": {"x": 0.1, "z": -0.1}, "rfa": {"x": -0.05}, "head": {"x": 0.38}, "larm": {"x": -0.3, "z": 0.3}})
	var desk1: Dictionary = en.call({"spine": {"x": 0.1}, "rarm": {"x": -1.0, "z": -0.3}, "larm": {"x": -1.0, "z": 0.3}, "rfa": {"x": -1.0}, "lfa": {"x": -1.0}, "head": {"x": 0.05}})
	var desk2: Dictionary = en.call({"spine": {"x": 0.12}, "rarm": {"x": -1.05, "z": -0.3}, "larm": {"x": -1.0, "z": 0.3}, "rfa": {"x": -1.05}, "lfa": {"x": -1.0}, "head": {"x": 0.1, "y": 0.08}})
	var stun1: Dictionary = en.call({"spine": {"x": 0.35, "z": 0.2}, "head": {"x": 0.45, "z": 0.2}, "rarm": {"x": 0.2, "z": -0.5}, "larm": {"x": 0.15, "z": 0.5}})
	var stun2: Dictionary = en.call({"spine": {"x": 0.4, "z": -0.2}, "head": {"x": 0.5, "z": -0.2}, "rarm": {"x": 0.25, "z": -0.55}, "larm": {"x": 0.2, "z": 0.55}})
	var pin1: Dictionary = en.call({"spine": {"x": 0.2, "z": 0.18}, "rarm": {"x": -1.4, "z": -0.8}, "larm": {"x": -1.2, "z": 0.8}, "rfa": {"x": -0.6}, "lfa": {"x": -0.6}, "head": {"x": 0.1, "y": 0.4}})
	var pin2: Dictionary = en.call({"spine": {"x": 0.25, "z": -0.18}, "rarm": {"x": -1.2, "z": -0.9}, "larm": {"x": -1.4, "z": 0.7}, "rfa": {"x": -0.7}, "lfa": {"x": -0.5}, "head": {"x": 0.1, "y": -0.4}})
	var jacket1: Dictionary = en.call({"spine": {"x": 0.05}, "rarm": {"x": -0.6, "z": -0.5}, "rfa": {"x": -1.6}, "larm": {"x": -0.6, "z": 0.5}, "lfa": {"x": -1.6}, "head": {"x": 0.08}})
	var head1: Dictionary = en.call({"spine": {"x": 0.25}, "rarm": {"x": -2.4, "z": -0.3}, "larm": {"x": -2.4, "z": 0.3}, "rfa": {"x": -1.6}, "lfa": {"x": -1.6}, "head": {"x": 0.3}})
	var sit1: Dictionary = en.call({"spine": {"x": 0.3}, "head": {"x": 0.35}, "rarm": {"x": -0.4, "z": -0.3}, "larm": {"x": -0.4, "z": 0.3}, "rfa": {"x": -1.0}, "lfa": {"x": -1.0}})
	var sit2: Dictionary = en.call({"spine": {"x": 0.34}, "head": {"x": 0.4}, "rarm": {"x": -0.45, "z": -0.3}, "larm": {"x": -0.4, "z": 0.3}, "rfa": {"x": -1.05}, "lfa": {"x": -1.0}})
	return {
		"Idle": {"d": 3.0, "loop": true, "k": [[0.0, calc], [0.5, calc2], [1.0, calc]]},
		"FTape": {"d": 1.0, "k": [[0.0, calc], [0.45, tape1, "out"], [0.6, tape2, "in"], [1.0, calc, "io"]]},
		"FCoins": {"d": 1.0, "k": [[0.0, calc], [0.4, coins1, "out"], [0.7, coins2, "in"], [1.0, calc, "io"]]},
		"FGates": {"d": 1.3, "k": [[0.0, calc], [0.35, snap1, "out"], [0.55, snap2, "in"], [1.0, snap2], [1.3, calc, "io"]]},
		"FZone": {"d": 1.2, "k": [[0.0, calc], [0.3, point1, "out"], [0.6, point2], [1.0, point2], [1.2, calc, "io"]]},
		"FConsult": {"d": 2.4, "loop": true, "k": [[0.0, desk1], [0.5, desk2], [1.0, desk1]]},
		"FStun": {"d": 0.9, "loop": true, "k": [[0.0, stun1], [0.5, stun2], [1.0, stun1]]},
		"FPinned": {"d": 0.4, "loop": true, "k": [[0.0, pin1], [0.5, pin2], [1.0, pin1]]},
		"FPhase": {"d": 1.4, "k": [[0.0, calc], [0.3, jacket1, "out"], [0.9, jacket1], [1.4, calc, "io"]]},
		"FPhase3": {"d": 1.4, "k": [[0.0, calc], [0.3, head1, "out"], [0.9, head1], [1.4, calc, "io"]]},
		"FSit": {"d": 2.6, "loop": true, "k": [[0.0, sit1], [0.5, sit2], [1.0, sit1]]},
	}

## Оглушение на полные sec секунд (обычное stun() у боссов режется до 35 % и закрыто в окне смены фазы)
static func hard_stun(e, sec: float, clip: String) -> void:
	if e.state == "dead":
		return
	e.state = "stun"
	e.t = 0.0
	e.stun_t = sec
	e.ring.visible = false
	e._tell_end()
	e.rig.play_for(clip, sec, 0.06)
	e._update_bar()

## Сигнал карты: короткий писк (синтез)
static func beep() -> AudioStreamWAV:
	var n := int(0.18 * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		d.encode_s16(i * 2, int(sin(TAU * 1250.0 * float(i) / 22050.0) * 0.5 * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w

## Реквизит в руках: калькулятор в левой, кассовая лента через плечо (кодом, на костях Mixamo)
static func attach_props(rig) -> void:
	if rig == null or rig.skel == null:
		return
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_LeftHand"
	rig.skel.add_child(hand)
	var calc := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.1, 0.16, 0.025)
	calc.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.12, 0.12, 0.14)
	calc.material_override = cmat
	hand.add_child(calc)
	calc.position = Vector3(0, 0.08, 0.05)
	var scr := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.08, 0.04, 0.005)
	scr.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.5, 1.0, 0.5)
	smat.emission_enabled = true
	smat.emission = Color(0.4, 1.0, 0.4)
	scr.material_override = smat
	calc.add_child(scr)
	scr.position = Vector3(0, 0.05, 0.015)
	var chest := BoneAttachment3D.new()
	chest.bone_name = "mixamorig_Spine2"
	rig.skel.add_child(chest)
	var tape := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.05, 0.7, 0.012)
	tape.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.95, 0.95, 0.88)
	tape.material_override = tmat
	chest.add_child(tape)
	tape.position = Vector3(0.0, 0.02, 0.0)
	tape.rotation_degrees = Vector3(0, 0, 38)

## Окно «выдох»: через at секунд босс открыт EXHALE секунд (броня снята), над ним «ОТКРЫТ»
static func _exhale(e, at: float) -> void:
	e._at(at, func():
		if not is_instance_valid(e) or e.state != "special":
			return
		e.weak_t = EXHALE
		e.rig.play_for("FPhase", EXHALE, 0.1)
		e.game.popup(e.global_position + Vector3(0, e.height + 0.5, 0), "ОТКРЫТ", Color(1.0, 0.9, 0.3))
		e.game.golda.events.append(["fz_exhale"]))

static func _front(e) -> Vector3:
	return Vector3(sin(e.face), 0, cos(e.face))

static func _aim(e) -> void:
	var d: Vector3 = e.game.player.global_position - e.global_position
	d.y = 0.0
	if d.length() > 0.1:
		e.face = atan2(d.x, d.z)

static func say(e, key: String) -> void:
	e.game.popup(e.global_position + Vector3(0, e.height + 0.7, 0), String(LINES[key]), Color(1.0, 0.92, 0.3))
	e.game.toast(String(LINES[key]))

static func start(e, move: String) -> void:
	var g = e.game
	var G = g.golda
	var ar = G.arena if G != null else null
	e.sp_lock = true
	if ar == null:
		e.sp_dur = 0.6
		return
	ar.boss = e
	_aim(e)
	var ph: int = e.phase
	e.cfg["cool"] = float(PAUSES[clampi(ph, 0, 2)])
	if not e.has_meta("fz_test"):
		move = _pick(e, ar, ph)
		if move == "f_zone" and e.age < NO_ZONE_FIRST:
			move = "f_check"
	elif move == "f_consult" and (e.hp > e.max_hp * CONSULT_HP_GATE or not ar.glass_alive):
		move = "f_change"
	e.set_meta("fz_move", move)
	e.set_meta("fz_move_t", e.age)
	match move:
		"f_gates":
			_gates(e, ar, ph)
		"f_zone":
			_zone(e, ar, ph)
		"f_check":
			_check(e, ar, ph)
		"f_change":
			_change(e, ph)
		"f_consult":
			_consult(e, ar)

## Фаза 1 — строго по кругу ТУРНИКЕТЫ → ЗОНА → ЧЕК → СДАЧА (КОНСУЛЬТАЦИЯ раз в круг ниже 80 %); фазы 2–3 — случайный порядок без повтора подряд
static func _pick(e, ar, ph: int) -> String:
	var last := String(e.get_meta("fz_last", ""))
	var m := ""
	if ph == 0:
		var i := int(e.get_meta("fz_i", 0))
		if i > 0 and i % 4 == 0 and e.hp <= e.max_hp * CONSULT_HP_GATE and ar.glass_alive and not bool(e.get_meta("fz_consulted_%d" % (i / 4), false)):
			e.set_meta("fz_consulted_%d" % (i / 4), true)
			m = "f_consult"
		else:
			m = String(CYCLE[i % 4])
			e.set_meta("fz_i", i + 1)
	else:
		var pool: Array = CYCLE.duplicate()
		if ar.glass_alive:
			pool.append("f_consult")
		pool.erase(last)
		m = String(pool[randi() % pool.size()])
	e.set_meta("fz_last", m)
	return m

static func _gates(e, ar, ph: int) -> void:
	say(e, "gates")
	e.rig.play_for("FGates", 1.3, 0.05)
	if ph >= 2:
		# фаза 3: линии хлопают вразнобой каждые 2–3 с, метка 0,8 с; одна из секций — рядом с боссом
		var n := 5
		for k in n:
			e._at(0.6 + float(k) * 2.4, func():
				var l := randi() % 3
				var i := randi() % 6
				if randf() < 0.45:
					var s: Vector2i = ar.section_at(e.global_position)
					if s.x >= 0:
						l = s.x
						i = s.y
				ar.clap(l, i, 0.8, 2.5))
		e.sp_dur = 0.6 + float(n) * 2.4 + 1.0
		return
	var lines: Array = [randi() % 3]
	if ph >= 1:
		var other := (int(lines[0]) + 1 + randi() % 2) % 3
		lines.append(other)
	for l in lines:
		ar.flash(int(l), GATE_FLASH)
	var open_idx := randi() % 6
	e._at(GATE_FLASH, func():
		for l in lines:
			ar.close_line(int(l), (open_idx + int(l)) % 6, GATE_HOLD))
	e.sp_dur = GATE_FLASH + 1.0

static func _zone(e, ar, ph: int) -> void:
	say(e, "zone" if randf() < 0.5 else "zone2")
	e.rig.play_for("FZone", 1.2, 0.05)
	var at: Vector3 = e.game.player.global_position + e.game.player.velocity * 0.45      # с упреждением по скорости героя
	e._at(0.4, func():
		ar.add_zone(Vector3(clampf(at.x, -9.0, 9.0), 0.0, clampf(at.z, -186.0, -172.0)), ZONE_SIZE, ZONE_FADE, ZONE_LIVE, ZONE_CREEP if ph >= 1 else 0.0)
		e.game.golda.events.append(["fz_zone"]))
	e.sp_dur = 1.4

static func _strip(e, ar, yaw: float) -> void:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var c: Vector3 = e.global_position + f * (CHECK_L * 0.5 + 0.8)
	ar.add_strip(c, yaw, CHECK_W, CHECK_L, CHECK_LIVE)

static func _check(e, ar, ph: int) -> void:
	say(e, "check")
	e.rig.play_for("FTape", 1.0, 0.05)
	var yaw: float = e.face
	e._at(CHECK_WARN, func():
		_strip(e, ar, yaw)
		if ph >= 1:
			_strip(e, ar, yaw + PI * 0.5)
		e.game.golda.events.append(["fz_check"]))
	_exhale(e, 1.0)
	e.sp_dur = 1.0 + EXHALE

static func _change(e, ph: int) -> void:
	say(e, "change")
	e.rig.play_for("FCoins", 1.0, 0.05)
	var g = e.game
	var base: float = e.face
	e._at(CHANGE_WARN, func():
		var offsets: Array = [0.0] if ph < 1 else [-0.45, 0.45]
		for off in offsets:
			for k in CHANGE_COINS:
				var a: float = base + float(off) + (float(k) / float(CHANGE_COINS - 1) - 0.5) * CHANGE_CONE
				var v := Vector3(sin(a), 0, cos(a)) * 9.0
				g.spawn_bolt(e.global_position + Vector3(0, 1.3, 0) + Vector3(sin(a), 0, cos(a)) * 0.6, v, CHANGE_DMG, e, false, Color(1.0, 0.85, 0.2))
				var land: Vector3 = e.global_position + Vector3(sin(a), 0, cos(a)) * (6.0 + randf() * 3.0)
				e.get_tree().create_timer(0.7).timeout.connect(func(): if g.golda != null and g.golda.arena != null: g.golda.arena.coin_drop(land))
		g.golda.events.append(["fz_change", CHANGE_COINS * offsets.size()]))
	_exhale(e, 1.1)
	e.sp_dur = 1.1 + EXHALE

static func _consult(e, ar) -> void:
	say(e, "consult")
	e.rig.play_for("FConsult", CONSULT_MAX + 1.0, 0.1)
	var g = e.game
	var cash: Vector3 = ar.CASH_POS + Vector3(0.0, 0.0, 1.4)
	var zc := Vector3(0.0, 0.0, ar.CASH_POS.z + 3.0)
	var st := {"t": 0.0, "out": 0.0, "done": false}
	e._at(0.5, func():
		e.global_position = Vector3(cash.x, e.global_position.y, cash.z)
		e.face = PI
		ar.add_zone(zc, CONSULT_ZONE, 0.6, CONSULT_MAX + 0.2, 0.0, false)
		g.golda.events.append(["fz_consult"]))
	for k in int(CONSULT_MAX * 2.0):
		e._at(1.1 + float(k) * 0.5, func():
			if st["done"] or not is_instance_valid(e) or e.state != "special":
				return
			var p = g.player
			var inside: bool = absf(p.global_position.x - zc.x) < CONSULT_ZONE.x * 0.5 and absf(p.global_position.z - zc.z) < CONSULT_ZONE.y * 0.5
			if not ar.glass_alive:
				return
			if inside:
				e.hp = minf(e.max_hp, e.hp + e.max_hp * CONSULT_HEAL * 0.5)
				st["out"] = 0.0
			else:
				st["out"] = float(st["out"]) + 0.5
				if float(st["out"]) >= 1.0:
					st["done"] = true
					g.popup(e.global_position + Vector3(0, e.height + 0.4, 0), "СЕАНС ПРЕРВАН", Color(1, 0.8, 0.3))
					hard_stun(e, CONSULT_STUN, "FStun"))
	e.sp_dur = CONSULT_MAX + 1.2
