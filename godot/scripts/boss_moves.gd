## Новые приёмы боссов поверх данных фаз из story.json: EXTRA[босс][фаза] дописывается к boss["phases"] при появлении
## (enemy._setup_boss), так что фазы те же, а выбор шире. Приём идёт в состоянии "special" (enemy.gd: события по времени
## _at, босс открыт для ударов, оглушение срывает приём) и собран из того, что уже есть в game.gd: круги на земле
## с задержкой (telegraph — у каждого видно, сколько осталось), волны (expanding_ring), лучи (sweep), «всё, кроме круга»
## (wipe), снаряды (spawn_bolt), посылки по дуге (lob), рывок (состояние charge), призыв (_make_enemy).
## Каждый опасный удар — с меткой и задержкой не меньше MIN_WARN; «ложные» зоны — серые и безвредные (видно, что ложные).
## Адаптация (adapt): по фактам PlayerRead — долго в воздухе, бьёт со спины, держит блок, всё время вплотную или издалека —
## босс иногда (CHANCE, не чаще раза в COUNTER_CD) выбирает приём против этого. Тоже с меткой, без чтения нажатий.
class_name BossMoves

const MIN_WARN := 0.6        # самое короткое предупреждение у круга на земле, с
const CHANCE := 0.35
const COUNTER_CD := 6.0
const FAKE := Color(0.62, 0.62, 0.66)

const EXTRA := {
	"courier": [["parcel_seek"], ["decoy", "parcel_ring"], ["express", "parcel_ring"]],
	"golem": [["double_slam"], ["rockfall_lanes", "ram"], ["quake_chain", "rockfall_lanes", "ram"]],
	"hype": [["dash_strike"], ["beam_cross", "beat_drop"], ["encore", "dash_strike", "beam_cross"]],
	"dislike": [["toxic_fan"], ["pool_trail", "leap_poison"], ["toxic_rain", "leap_poison", "pool_trail"]],
	"major": [["stamp_line"], ["cage", "fake_seal"], ["collapse", "stamp_line", "cage"]],
	"strike": [["chain_bolt"], ["volt_dash", "storm_grid"], ["thunder_combo", "volt_dash", "storm_grid"]],
	"botlord": [["guard_bots"], ["attack_bots", "overclock"], ["mine_bots", "overclock", "attack_bots"]],
	"ghostv": [["mirror_dash"], ["swap", "mirror_dash"], ["true_one", "swap", "mirror_dash"]],
	"g67_misha": G67Misha.MOVES,      # приквел «ГОЛДА 67»: захват, защитная стойка, зацеп цепи (golda67/g67_misha.gd)
	"algo": [["grid_lines"], ["beam_cross", "grid_lines"], ["glitch_wipe", "grid_lines"], ["final_compile", "glitch_wipe", "beam_cross"]],
}
const TITLES := {
	"parcel_seek": "ПОГОНЯ", "decoy": "ПРИМАНКА", "parcel_ring": "СО ВСЕХ СТОРОН", "express": "ЭКСПРЕСС-ДОСТАВКА",
	"double_slam": "ДВЕ РУКИ", "rockfall_lanes": "ОБВАЛ", "ram": "ТАРАН", "quake_chain": "РАЗЛОМ",
	"dash_strike": "ФИТ", "beam_cross": "КРЕСТ", "beat_drop": "БИТ", "encore": "ЭНКОР",
	"toxic_fan": "ТОКСИК", "pool_trail": "ЖИЖА", "leap_poison": "ПРЫЖОК В ЖИЖУ", "toxic_rain": "ЛИВЕНЬ",
	"stamp_line": "РЕЕСТР", "cage": "ОГРАНИЧЕНИЕ", "fake_seal": "ПОДДЕЛКА", "collapse": "ОБРУШЕНИЕ",
	"chain_bolt": "ЦЕПЬ", "volt_dash": "РАЗРЯД", "storm_grid": "ГРОЗА", "thunder_combo": "УДАЛЕНИЕ",
	"guard_bots": "ОХРАНА", "attack_bots": "НАЛЁТ", "overclock": "РАЗГОН", "mine_bots": "МИНЫ",
	"mirror_dash": "ОТРАЖЕНИЕ", "swap": "ПОДМЕНА", "true_one": "КТО НАСТОЯЩИЙ?",
	"grid_lines": "СЕТКА", "glitch_wipe": "СБОЙ", "final_compile": "КОМПИЛЯЦИЯ",
	"m_grab": "ЗАХВАТ", "m_guard": "ЗАЩИТНАЯ СТОЙКА", "m_hook": "ЗАЦЕП ЦЕПИ",
	"anti_air": "НЕ ВЗЛЕТИШЬ", "turn_strike": "РАЗВОРОТ", "guard_break": "ПРОБИТИЕ", "close_burst": "НЕ ПОДХОДИ", "far_punish": "ДОСТАНУ",
}

static func is_new(move: String) -> bool:
	return TITLES.has(move)

## Фазы босса с новыми приёмами (копия: данные story.json не меняются)
static func phases_for(boss_id: String, base: Array) -> Array:
	var out: Array = []
	var ex: Array = EXTRA.get(boss_id, [])
	for i in base.size():
		var ph: Array = (base[i] as Array).duplicate()
		if i < ex.size():
			ph.append_array(ex[i])
		out.append(ph)
	return out

## Приём против поведения игрока или "" — честно: по фактам прошлого, с замахом и меткой
static func adapt(e) -> String:
	var r = e.game.read
	if r == null or e.age < float(e.counter_at):
		return ""
	var want := ""
	if float(r.air) > 0.35:
		want = "anti_air"
	elif float(r.behind) > 0.5:
		want = "turn_strike"
	elif float(r.block_streak) > 1.2:
		want = "guard_break"
	elif float(r.close) > 0.75:
		want = "close_burst"
	elif float(r.close) < 0.15:
		want = "far_punish"
	if want == "" or randf() > CHANCE:
		return ""
	e.counter_at = e.age + COUNTER_CD
	return want

## Куда метить: туда, где герой окажется, со сдвигом в сторону, куда он любит уклоняться
static func lead(e, sec: float) -> Vector3:
	var p = e.game.player
	var at: Vector3 = p.global_position + p.velocity * sec
	var r = e.game.read
	if r != null:
		var side: String = r.dodge_side()
		if side != "":
			var left := Vector3(cos(p.face), 0, -sin(p.face))
			at += left * (1.2 if side == "l" else -1.2)
	at.y = 0.0
	return at

static func _arena(g, at: Vector3) -> Vector3:
	var limx: float = float(g.arena_h.x) - 1.2
	var limz: float = float(g.arena_h.y) - 1.2
	return Vector3(g.arena_c.x + clampf(at.x - g.arena_c.x, -limx, limx), 0.0, g.arena_c.z + clampf(at.z - g.arena_c.z, -limz, limz))

## Запустить приём. Длительность — sp_dur босса; всё, что бьёт, — с меткой.
static func start(e, move: String) -> void:
	e.record_ability(move)
	var g = e.game
	var P = g.player
	var dmg := float(e.cfg["dmg"])
	var col: Color = e.cfg["tint"]
	e.state = "special"
	e.t = 0.0
	e.ring.visible = false
	e._tell_end()
	e.sp_events = []
	e.sp_dur = 1.5
	e.sp_lock = false
	var ph: int = e.phase
	match move:
		"m_grab", "m_guard", "m_hook":
			G67Misha.start(e, move)
		# ---------------- LIL DREY ----------------
		"parcel_seek":
			e.rig.play_for("Throw", 0.5, 0.05)
			for i in 3 + ph:
				e._at(0.3 + i * 0.3, func():
					g.spawn_bolt(e.global_position + Vector3(0, e.height * 0.8, 0), Vector3(randf_range(-4, 4), 3.0, randf_range(-4, 4)), dmg * 0.6, e, true, col, {"turn": 1.0}))
			e.sp_dur = 1.0 + (3 + ph) * 0.3
		"decoy":
			var real := lead(e, 0.6)
			var fake: Vector3 = real + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			e._at(0.25, func():
				e.rig.play_for("Throw", 0.42, 0.05)
				g.lob(e.global_position + Vector3(0, e.height * 0.9, 0), fake, 0.9, FAKE)
				g.telegraph(_arena(g, fake), 2.2, 0.9, 0.0, e, {"col": FAKE}))
			e._at(0.55, func():
				g.lob(e.global_position + Vector3(0, e.height * 0.9, 0), real, 0.9, col)
				g.telegraph(_arena(g, lead(e, 0.6)), 2.0, 0.95, dmg * 0.9, e))
			e.sp_dur = 1.8
		"parcel_ring":
			var c: Vector3 = P.global_position
			var gap := randi() % 6
			for i in 6:
				if i == gap:
					continue
				var a := TAU * i / 6.0
				var at := _arena(g, c + Vector3(sin(a), 0, cos(a)) * 2.6)
				e._at(0.2 + i * 0.1, func():
					g.lob(e.global_position + Vector3(0, e.height * 0.9, 0), at, 1.0, col)
					g.telegraph(at, 1.7, 1.0, dmg * 0.8, e))
			e.sp_dur = 1.9
		"express":
			e.charge_dir = (P.global_position - e.global_position).normalized()
			e.charge_dir.y = 0
			for i in 5:
				var at: Vector3 = _arena(g, e.global_position + e.charge_dir * (2.0 + i * 1.8))
				e._at(0.1 + i * 0.12, func(): g.telegraph(at, 1.6, 0.9, dmg * 0.8, e))
			e._at(0.4, func(): _charge(e, dmg * 1.1, 13.0, 0.7))
			e.sp_dur = 1.4
		# ---------------- ПЕРВЫЙ КОРОЛЬ ----------------
		"double_slam":
			var fw := Vector3(sin(e.face), 0, cos(e.face))
			e.rig.play_for("Stomp", 1.4, 0.08)
			e._at(0.1, func(): g.telegraph(_arena(g, e.global_position + fw * 2.0), 3.0, 0.8, dmg * 1.1, e))
			e._at(0.5, func(): g.telegraph(_arena(g, e.global_position + fw * 4.2), 3.4, 0.9, dmg * 1.1, e))
			e.sp_dur = 1.6
		"rockfall_lanes":
			var c: Vector3 = P.global_position
			var safe := randi() % 5
			for x in 5:
				if x == safe:
					continue
				for z in 3:
					var at := _arena(g, c + Vector3((x - 2) * 2.2, 0, (z - 1) * 2.4))
					e._at(0.2 + z * 0.15, func(): g.telegraph(at, 1.25, 1.1, dmg * 0.8, e, {"col": col}))
			e.rig.play_for("Stomp", 1.0, 0.08)
			e.sp_dur = 1.8
		"ram":
			e._at(0.55, func(): _charge(e, dmg * 1.3, 14.0, 0.75))
			e.rig.play_for("Stomp", 0.6, 0.08)
			# полоса разбега видна весь замах
			_lane(e, 10.0, 1.6, 0.55)
			e.sp_dur = 1.4
		"quake_chain":
			e.rig.play_for("Stomp", 1.6, 0.08)
			for i in 3:
				e._at(0.5 + i * 0.55, func():
					g.fx.slam(e.global_position, 1.4, col)
					g.shake(0.4)
					g.expanding_ring(e.global_position, 12.0, 1.2, dmg * 0.8, e))
			e._at(1.0, func(): g.telegraph(lead(e, 0.8), 2.4, 1.0, dmg, e))
			e.sp_dur = 2.6
		# ---------------- ЛЕДИ ХАЙП ----------------
		"dash_strike":
			for i in 2 + (1 if ph >= 2 else 0):
				e._at(0.15 + i * 0.85, func():
					e._teleport_near(P.global_position, 3.0)
					g.telegraph(lead(e, 0.5), 1.9, 0.65, dmg * 0.9, e, {"col": col}))
			e.sp_dur = 0.4 + (2 + (1 if ph >= 2 else 0)) * 0.85
		"beam_cross":
			e.rig.play("Point", 0.15)
			var to: Vector3 = P.global_position - e.global_position
			var a0 := atan2(-to.x, -to.z) + 0.6
			var w := 1.1 * (1.0 if randf() < 0.5 else -1.0)
			g.sweep(e, 12.0, 3.6, w, dmg * 0.7, col, a0)
			g.sweep(e, 12.0, 3.6, w, dmg * 0.7, col, a0 + PI * 0.5)
			e.sp_dur = 3.8
		"beat_drop":
			for i in 3 + ph:
				e._at(0.4 + i * 0.5, func():
					g.popup(e.global_position + Vector3(0, e.height + 0.6, 0), "♪", col)
					g.expanding_ring(e.global_position, 10.0, 1.0, dmg * 0.6, e))
			e.sp_dur = 0.6 + (3 + ph) * 0.5 + 0.6
		"encore":
			# ритм и ложная «безопасная» зона: серый круг безвреден, но выглядит как укрытие — укрытие только зелёное
			var safe := _arena(g, P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
			var fake := _arena(g, P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
			g.telegraph(fake, 3.0, 3.0, 0.0, e, {"col": FAKE})
			g.wipe(safe, 3.0, 3.0, dmg * 1.4, e, col)
			for i in 4:
				e._at(0.5 + i * 0.5, func(): g.expanding_ring(e.global_position, 9.0, 0.9, dmg * 0.5, e))
			e.sp_dur = 3.4
		# ---------------- КОРОЛЬ ДИЗЛАЙК ----------------
		"toxic_fan":
			var green := Color(0.5, 0.95, 0.25)
			e._at(0.4, func():
				var d: Vector3 = (lead(e, 0.4) - e.global_position)
				d.y = 0
				d = d.normalized()
				for i in 5:
					g.spawn_bolt(e.global_position + Vector3(0, e.height * 0.7, 0), d.rotated(Vector3.UP, (i - 2) * 0.22) * 8.0, dmg * 0.5, e, false, green, {"slow": 1.5}))
			_lane(e, 9.0, 1.6, 0.4)
			e.sp_dur = 1.0
		"pool_trail":
			var green := Color(0.5, 0.95, 0.25)
			var d: Vector3 = P.global_position - e.global_position
			d.y = 0
			d = d.normalized()
			for i in 5:
				var at := _arena(g, e.global_position + d * (2.0 + i * 1.7))
				e._at(0.2 + i * 0.18, func(): g.telegraph(at, 1.6, 0.8, dmg * 0.6, e, {"pool": 5.0, "col": green}))
			e.sp_dur = 1.6
		"leap_poison":
			var green := Color(0.5, 0.95, 0.25)
			var target := lead(e, 0.6)
			g.telegraph(target, 2.6, 0.8, dmg * 1.2, e)
			var tw: Tween = e.create_tween()
			tw.tween_property(e, "global_position", Vector3(target.x, e.global_position.y, target.z), 0.8).set_trans(Tween.TRANS_QUAD)
			e._at(0.85, func():
				for i in 5:
					var a := TAU * i / 5.0
					g.telegraph(_arena(g, target + Vector3(sin(a), 0, cos(a)) * 3.4), 1.4, 0.7, dmg * 0.5, e, {"pool": 4.0, "col": green}))
			e.sp_dur = 1.9
		"toxic_rain":
			var green := Color(0.5, 0.95, 0.25)
			for i in 8:
				e._at(0.2 + i * 0.22, func():
					var at := _arena(g, lead(e, 0.3) + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)))
					g.lob(e.global_position + Vector3(0, e.height * 0.8, 0), at, 0.8, green, false)
					g.telegraph(at, 1.6, 0.8, dmg * 0.6, e, {"pool": 4.0, "col": green, "chase": 0.5}))
			e.sp_dur = 2.4
		# ---------------- МЕЙДЖОР ----------------
		"stamp_line":
			var d: Vector3 = P.global_position - e.global_position
			d.y = 0
			d = d.normalized()
			for i in 4:
				var at := _arena(g, e.global_position + d * (2.5 + i * 2.2))
				e._at(0.2 + i * 0.3, func():
					e.rig.play_for("Stamp", 0.5, 0.06)
					g.telegraph(at, 2.0, 0.85, dmg * 1.1, e, {"stamp": true, "col": col}))
			e.sp_dur = 2.2
		"cage":
			var c: Vector3 = P.global_position
			var gap := randi() % 8
			for i in 8:
				if i == gap:
					continue
				var a := TAU * i / 8.0
				g.telegraph(_arena(g, c + Vector3(sin(a), 0, cos(a)) * 2.8), 1.5, 1.3, dmg * 0.9, e, {"stamp": true, "col": col})
			e._at(0.9, func(): g.telegraph(_arena(g, c), 1.6, 0.9, dmg, e, {"stamp": true, "col": col}))
			e.sp_dur = 2.0
		"fake_seal":
			for i in 3:
				var at := _arena(g, lead(e, 0.3) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
				var fake := i == 1
				g.telegraph(at, 2.0, 1.0 + i * 0.25, 0.0 if fake else dmg * 1.1, e, {"stamp": not fake, "col": FAKE if fake else col})
			g.spawn_bolt(e.global_position + Vector3(0, e.height * 0.8, 0), Vector3(0, 2, 0), dmg * 0.7, e, true, col, {"turn": 1.4})
			e.sp_dur = 1.8
		"collapse":
			var c: Vector3 = P.global_position
			e._at(0.1, func(): g.telegraph(_arena(g, c), 2.2, 1.0, dmg * 1.2, e, {"stamp": true, "col": col}))
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				e._at(0.6, func(): g.telegraph(_arena(g, c + Vector3(sin(a), 0, cos(a)) * 3.6), 2.0, 1.0, dmg, e, {"stamp": true, "col": col}))
			for i in 8:
				var a := TAU * i / 8.0
				e._at(1.2, func(): g.telegraph(_arena(g, c + Vector3(sin(a), 0, cos(a)) * 6.4), 2.0, 1.0, dmg, e, {"stamp": true, "col": col}))
			e.sp_dur = 2.8
		# ---------------- СЕРЁГА РПЛЮС ----------------
		"chain_bolt":
			var purple := Color(0.72, 0.5, 1.0)
			e.rig.play_for("Summon", 1.6, 0.1)
			for i in 6 + ph:
				e._at(0.3 + i * 0.22, func(): g.telegraph(lead(e, 0.25 + i * 0.05), 1.3, MIN_WARN, dmg * 0.8, e, {"bolt": true, "col": purple}))
			e.sp_dur = 0.6 + (6 + ph) * 0.22 + 0.6
		"volt_dash":
			var purple := Color(0.72, 0.5, 1.0)
			var d: Vector3 = P.global_position - e.global_position
			d.y = 0
			d = d.normalized()
			_lane(e, 10.0, 1.5, 0.5)
			e._at(0.5, func():
				var from: Vector3 = e.global_position
				_charge(e, dmg * 1.1, 14.0, 0.7)
				for i in 5:
					g.telegraph(_arena(g, from + d * (1.5 + i * 1.8)), 1.1, 0.9 + i * 0.05, dmg * 0.6, e, {"bolt": true, "col": purple}))
			e.sp_dur = 1.5
		"storm_grid":
			var purple := Color(0.72, 0.5, 1.0)
			var c: Vector3 = P.global_position
			for wave in 2:
				for x in 3:
					for z in 3:
						if (x + z) % 2 != wave:
							continue
						var at := _arena(g, c + Vector3((x - 1) * 2.6, 0, (z - 1) * 2.6))
						e._at(0.2 + wave * 0.9, func(): g.telegraph(at, 1.3, 0.8, dmg * 0.8, e, {"bolt": true, "col": purple}))
			e.sp_dur = 2.2
		"thunder_combo":
			var purple := Color(0.72, 0.5, 1.0)
			e._at(0.1, func(): e._teleport_near(P.global_position, 2.6))
			e._at(0.3, func(): g.telegraph(_arena(g, e.global_position), float(e.cfg["range"]) + 1.6, 0.8, dmg * 1.2, e, {"col": col}))
			for i in 6:
				var a := TAU * i / 6.0
				e._at(1.2, func(): g.telegraph(_arena(g, e.global_position + Vector3(sin(a), 0, cos(a)) * 4.5), 1.3, 0.7, dmg * 0.7, e, {"bolt": true, "col": purple}))
			e.sp_dur = 2.2
		# ---------------- АНАР АБДУЛАЕВ ----------------
		"guard_bots":
			e._at(0.4, func(): _call(e, ["mod", "mod"], 4.0))
			e.rig.play("Channel", 0.15)
			e.sp_dur = 1.3
		"attack_bots":
			e._at(0.4, func(): _call(e, ["clipper", "bot", "clipper"] if ph >= 2 else ["clipper", "bot"], 5.0))
			e.rig.play("Channel", 0.15)
			e.sp_dur = 1.3
		"overclock":
			e._at(0.3, func():
				for o in g.enemies:
					if o != e and is_instance_valid(o) and o.alive():
						o.buff_t = 7.0
						g.fx.twinkle(o.global_position + Vector3(0, o.height * 0.7, 0), 8, col, 0.6)
				e.ward_t = 2.0)
			e.rig.play("Channel", 0.15)
			e.sp_dur = 1.2
		"mine_bots":
			for i in 4:
				var at := _arena(g, P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
				g.telegraph(at, 2.0, 1.6, dmg, e, {"col": col})
			e._at(0.5, func(): _call(e, ["hater"], 5.0))
			e.sp_dur = 1.8
		# ---------------- DENYA8 ----------------
		"mirror_dash":
			for i in 3:
				e._at(0.1 + i * 0.7, func():
					e._teleport_near(P.global_position, 2.4)
					g.telegraph(lead(e, 0.3), 1.7, MIN_WARN, dmg * 0.8, e, {"col": col}))
			e.sp_dur = 2.4
		"swap":
			e._at(0.3, func():
				var clones: Array = []
				for i in 2:
					var a := randf() * TAU
					var at := _arena(g, P.global_position + Vector3(sin(a), 0, cos(a)) * 4.2)
					var clone = g._make_enemy("clone", "", Vector3(at.x, 0.05, at.z))
					if clone == null:
						break
					clones.append(clone)
					g.fx.poof(at, 1.2, col)
				if clones.is_empty():
					return
				# меняется местами с одной копией: видно по вспышке у обоих
				var c = clones[0]
				var a2: Vector3 = c.global_position
				c.global_position = e.global_position
				g.fx.poof(e.global_position, 1.2, col)
				e.global_position = a2
				g.fx.poof(a2, 1.2, col))
			e.sp_dur = 1.0
		"true_one":
			e._at(0.4, func():
				for i in 3:
					var a := TAU * i / 3.0 + randf()
					var at := _arena(g, P.global_position + Vector3(sin(a), 0, cos(a)) * 4.5)
					var c = g._make_enemy("clone", "", Vector3(at.x, 0.05, at.z))
					if c == null:
						break
					c.cool = 0.4
				e._teleport_near(P.global_position, 4.5))
			e.sp_dur = 1.2
		# ---------------- 9MICE ----------------
		"grid_lines":
			var c: Vector3 = P.global_position
			var horiz := randf() < 0.5
			var gap := randi() % 5
			for row in 3:
				for k in 5:
					if k == gap:
						continue
					var off := Vector3((k - 2) * 2.2, 0, (row - 1) * 3.0) if horiz else Vector3((row - 1) * 3.0, 0, (k - 2) * 2.2)
					var at := _arena(g, c + off)
					e._at(0.2 + row * 0.45, func(): g.telegraph(at, 1.2, 0.8, dmg * 0.8, e, {"col": col}))
			e.sp_dur = 2.2
		"glitch_wipe":
			var s1 := _arena(g, P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
			g.wipe(s1, 3.2, 2.6, dmg * 1.6, e, col)
			e._at(2.7, func():
				var s2 := _arena(g, s1 + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
				g.wipe(s2, 3.0, 2.4, dmg * 1.6, e, col))
			e.sp_dur = 5.4
		"final_compile":
			# кульминация: сетка → лучи крестом → самонаводящиеся → «всё, кроме круга»; между этапами — паузы
			e._at(0.2, func(): start_part(e, "grid_lines"))
			e._at(2.3, func():
				var to: Vector3 = P.global_position - e.global_position
				var a0 := atan2(-to.x, -to.z)
				g.sweep(e, 13.0, 3.0, 1.0, dmg * 0.7, col, a0 + 0.8)
				g.sweep(e, 13.0, 3.0, 1.0, dmg * 0.7, col, a0 + 0.8 + PI))
			e._at(5.6, func():
				for i in 4:
					g.spawn_bolt(e.global_position + Vector3(0, e.height, 0), Vector3(sin(i * 1.57) * 5.0, 2.0, cos(i * 1.57) * 5.0), dmg * 0.6, e, true, col, {"turn": 1.2}))
			e._at(6.4, func(): g.wipe(_arena(g, P.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))), 3.2, 2.8, dmg * 1.8, e, col))
			e.sp_dur = 9.4
		# ---------------- адаптация ----------------
		"anti_air":
			g.telegraph(lead(e, 0.2), 2.2, 0.75, dmg * 0.9, e, {"bolt": true, "col": col})
			e._at(0.4, func(): g.expanding_ring(e.global_position, 9.0, 1.0, dmg * 0.6, e))
			e.sp_dur = 1.2
		"turn_strike":
			g.telegraph(_arena(g, e.global_position), float(e.cfg["range"]) + 2.0, 0.7, dmg * 1.1, e, {"col": col})
			e.sp_dur = 1.1
		"guard_break":
			g.telegraph(lead(e, 0.2), 2.0, 0.75, dmg * 1.3, e, {"col": col, "stamp": e.boss_id == "major"})
			e.sp_dur = 1.1
		"close_burst":
			e._at(0.55, func():
				g.fx.slam(e.global_position, 1.3, col)
				g.expanding_ring(e.global_position, 7.0, 0.8, dmg * 0.9, e))
			g.telegraph(_arena(g, e.global_position), 3.0, 0.55, 0.0, e, {"col": col})
			e.sp_dur = 1.3
		"far_punish":
			for i in 2:
				e._at(0.3 + i * 0.3, func():
					g.spawn_bolt(e.global_position + Vector3(0, e.height * 0.8, 0), Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3)), dmg * 0.7, e, true, col, {"turn": 1.5}))
			e.sp_dur = 1.2
		_:
			e.state = "chase"
			return
	e.sp_events.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	g.popup(e.global_position + Vector3(0, e.height + 0.7, 0), String(TITLES.get(move, move)), col.lightened(0.3))
	e.moves_used[move] = int(e.moves_used.get(move, 0)) + 1

## Часть составного приёма (без смены состояния босса)
static func start_part(e, move: String) -> void:
	var keep_dur: float = e.sp_dur
	var keep_ev: Array = e.sp_events
	start(e, move)
	e.state = "special"
	e.sp_dur = keep_dur
	var added: Array = e.sp_events
	e.sp_events = keep_ev
	for ev in added:
		e.sp_events.append([float(ev[0]) + e.t, ev[1]])
	e.sp_events.sort_custom(func(x, y): return float(x[0]) < float(y[0]))

## Рывок босса по прямой (как charge у story-приёмов, но со своим уроном и скоростью)
static func _charge(e, dmg: float, speed: float, len: float) -> void:
	var p = e.game.player
	var d: Vector3 = p.global_position - e.global_position
	d.y = 0
	e.charge_dir = d.normalized() if d.length() > 0.1 else Vector3(sin(e.face), 0, cos(e.face))
	e.face = atan2(e.charge_dir.x, e.charge_dir.z)
	e.charge_dmg = dmg
	e.charge_v = speed
	e.charge_len = len
	e.charge_r = float(e.cfg["range"]) * 0.7
	e.state = "charge"
	e.t = 0.0
	e.game.main.sfx("sfx_swing_heavy", -2.0)

## Полоса на земле: куда пойдёт рывок или очередь (метка врага, та же, что у мобов)
static func _lane(e, length: float, half_w: float, sec: float) -> void:
	var p = e.game.player
	var d: Vector3 = p.global_position - e.global_position
	e.face = atan2(d.x, d.z)
	e.tell_r = length
	e.tell_half = 0.0
	e.tell_lane = half_w
	e.game.fx.tell_shape(e.tell, e.global_position, e.face, length, 0.0, half_w, 0, e.cfg["tint"])
	e.tell_until = e.age + sec
	e.tell_sec = sec

## Призыв с пределом: у босса не больше 6 своих призванных одновременно, в арене — не больше 14 врагов
static func _call(e, kinds: Array, r: float) -> void:
	var g = e.game
	e.spawned = e.spawned.filter(func(o): return is_instance_valid(o) and o.state != "dead")
	for k in kinds:
		if e.spawned.size() >= 6 or g.enemies.size() >= 14:
			return
		var a := randf() * TAU
		var at := _arena(g, e.global_position + Vector3(sin(a), 0, cos(a)) * r)
		var o = g._make_enemy(String(k), "", Vector3(at.x, 0.05, at.z))
		if o == null:
			return
		o.summoned_by = e
		e.spawned.append(o)
		g.fx.lightning(at, 4.0, e.cfg["tint"])
	g.main.sfx("sfx_cast", -3.0, 0.7)
