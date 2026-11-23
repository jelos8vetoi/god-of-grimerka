## ИИ обычных врагов поверх FSM enemy.gd (chase → wind → strike → recover): какие приёмы есть у каждого типа,
## какой выбрать сейчас (полезность: дистанция, перезарядка, здоровье, поведение игрока из PlayerRead), какую роль
## держать в группе (attack — бьёт, flank — заходит сбоку, hold — держит дистанцию, guard — прикрывает слабого,
## ranged — стрелок), и честность: у каждого приёма есть замах с меткой той же формы, что и зона удара
## (enemy._tell_start → tell_of), после сильных приёмов — окно отдыха (rec), два ближних удара не приходят
## в одно мгновение (stagger_wind), ближних атакующих не больше двух (game.melee_attackers).
## Приём — строка данных: новый удар моба добавляется в MOVES, а не кодом в enemy.gd.
class_name EnemyAI

## Общие ручки сложности (все в одном месте). Здоровье мобов — game.diff_hp (enemy._ready).
const TUNE := {
	"dmg": 1.0,          # множитель урона приёмов мобов
	"cool": 1.0,         # множитель пауз между приёмами
	"low_hp": 0.35,      # «мало здоровья» — доля
	"flank_deg": 80.0,   # угол захода сбоку
	"hold_r": 5.0,       # радиус ожидания у тех, кому не досталось права атаковать
	"tokens": 2,         # ближних атакующих одновременно (как game.melee_attackers)
	"gap": 0.3,          # минимум секунд между ударами двух разных врагов по герою
	"summon_cap": 3,     # призванных одним фермером одновременно
}

## Поля приёма:
##   act — что делает: melee (сектор), lunge (рывок + сектор), slam (круг вокруг себя), charge (разбег по полосе),
##         feint (ложный замах → then), shoot (снаряды), zone (круг на земле у героя), ring (волна от себя),
##         blink (перемещение), clones (двойники), summon, buff, ritual (защита), repel (отталкивающая волна + отход)
##   w — вес выбора, cd — перезарядка приёма, min/max — дистанция до героя, wind — замах, rec — отдых после,
##   dmg — множитель урона типа, r — дальность/радиус, half — половина угла сектора, lane — полуширина полосы,
##   then — следующий приём связки (замах короче — wind второго приёма), cond — условие: low (мало здоровья),
##   block (герой держит блок), idle (герой стоит без ударов), spam (герой повторяет один удар), close (герой вплотную),
##   behind (враг за спиной героя), ally (рядом союзник того же типа), weak_ally (рядом союзник-стрелок/фермер)
const MOVES := {
	"bot": {
		"jab": {"act": "melee", "w": 3.0, "max": 2.6, "wind": 0.55, "rec": 0.55, "dmg": 1.0, "r": 2.1, "half": 1.1},
		"double": {"act": "melee", "w": 2.0, "cd": 3.0, "max": 2.6, "wind": 0.5, "rec": 0.1, "dmg": 0.7, "r": 2.1, "half": 1.1, "then": "double2"},
		"double2": {"act": "melee", "w": 0.0, "wind": 0.32, "rec": 0.7, "dmg": 0.7, "r": 2.2, "half": 1.1},
		"delay": {"act": "melee", "w": 1.2, "cd": 5.0, "max": 2.6, "wind": 1.0, "rec": 0.6, "dmg": 1.1, "r": 2.2, "half": 1.0},
		"pair": {"act": "lunge", "w": 2.5, "cd": 6.0, "min": 1.5, "max": 4.0, "cond": "ally", "wind": 0.6, "rec": 0.8, "dmg": 1.0, "r": 2.1, "dash": 1.6, "half": 0.9},
		"haymaker": {"act": "melee", "w": 0.8, "cd": 9.0, "max": 2.6, "wind": 1.15, "rec": 1.2, "dmg": 2.0, "r": 2.4, "half": 1.3, "heavy": true},
		"breaker": {"act": "melee", "w": 4.0, "cd": 7.0, "max": 2.6, "cond": "block", "wind": 0.9, "rec": 1.0, "dmg": 1.6, "r": 2.3, "half": 1.2, "heavy": true},
	},
	"clipper": {
		"cut": {"act": "lunge", "w": 2.0, "max": 3.4, "wind": 0.4, "rec": 0.45, "dmg": 1.0, "r": 2.2, "dash": 1.2, "half": 1.1},
		"flurry": {"act": "melee", "w": 2.5, "cd": 4.0, "max": 2.8, "wind": 0.38, "rec": 0.05, "dmg": 0.55, "r": 2.3, "half": 1.2, "then": "flurry2"},
		"flurry2": {"act": "melee", "w": 0.0, "wind": 0.28, "rec": 0.05, "dmg": 0.55, "r": 2.3, "half": 1.2, "then": "flurry3"},
		"flurry3": {"act": "lunge", "w": 0.0, "wind": 0.42, "rec": 0.95, "dmg": 0.9, "r": 2.3, "dash": 1.4, "half": 1.0, "title": "РАЗРЕЗ"},
		"diagonal": {"act": "lunge", "w": 2.0, "cd": 5.0, "min": 3.0, "max": 6.5, "wind": 0.5, "rec": 0.8, "dmg": 1.2, "r": 2.0, "dash": 4.0, "half": 0.7},
		"feint": {"act": "feint", "w": 1.4, "cd": 7.0, "max": 3.0, "wind": 0.5, "rec": 0.0, "then": "feint_real"},
		"feint_real": {"act": "lunge", "w": 0.0, "wind": 0.36, "rec": 0.8, "dmg": 1.1, "r": 2.2, "dash": 1.0, "half": 1.2},
		"counter": {"act": "melee", "w": 5.0, "cd": 6.0, "max": 2.8, "cond": "idle", "wind": 0.3, "rec": 0.7, "dmg": 1.0, "r": 2.3, "half": 1.3, "title": "КОНТРА"},
		"dance": {"act": "blink", "w": 1.0, "cd": 8.0, "min": 2.0, "max": 7.0, "wind": 0.35, "rec": 0.0, "to": "side", "then": "cut"},
	},
	"hater": {
		"bolt": {"act": "shoot", "w": 2.0, "min": 3.0, "wind": 0.7, "rec": 0.6, "dmg": 1.0, "n": 1, "speed": 9.0, "r": 11.0, "lane": 0.5},
		"fan": {"act": "shoot", "w": 1.6, "cd": 5.0, "min": 3.0, "wind": 0.8, "rec": 0.9, "dmg": 0.7, "n": 5, "spread": 0.24, "speed": 9.0, "r": 10.0, "half": 0.55},
		"burst": {"act": "shoot", "w": 1.4, "cd": 6.0, "min": 3.0, "wind": 0.7, "rec": 1.0, "dmg": 0.6, "n": 3, "seq": 0.28, "speed": 10.0, "r": 11.0, "lane": 0.5},
		"slowbolt": {"act": "shoot", "w": 1.0, "cd": 8.0, "min": 3.0, "wind": 0.75, "rec": 0.8, "dmg": 0.5, "n": 1, "speed": 7.0, "slow": 2.0, "r": 11.0, "lane": 0.5, "col": [0.4, 0.75, 1.0]},
		"lead": {"act": "shoot", "w": 1.2, "cd": 5.0, "min": 4.0, "wind": 0.7, "rec": 0.7, "dmg": 1.0, "n": 1, "speed": 11.0, "lead": 0.45, "r": 11.0, "lane": 0.6},
		"deny": {"act": "zone", "w": 1.0, "cd": 9.0, "min": 4.0, "wind": 0.6, "rec": 0.8, "dmg": 1.1, "zr": 2.4, "delay": 1.1, "title": "ДИЗЛАЙК"},
		"repel": {"act": "repel", "w": 6.0, "cd": 6.0, "max": 3.0, "cond": "close", "wind": 0.45, "rec": 0.3, "dmg": 0.8, "r": 3.4},
	},
	"troll": {
		"punch": {"act": "melee", "w": 2.0, "max": 3.2, "wind": 0.95, "rec": 1.1, "dmg": 1.0, "r": 2.9, "half": 1.0},
		"slam": {"act": "slam", "w": 2.0, "cd": 4.0, "max": 3.4, "wind": 1.0, "rec": 1.3, "dmg": 1.0, "r": 3.2},
		"spin": {"act": "slam", "w": 1.2, "cd": 7.0, "max": 3.2, "wind": 1.1, "rec": 1.5, "dmg": 0.8, "r": 3.6, "title": "КРУГОМ"},
		"ram": {"act": "charge", "w": 1.5, "cd": 8.0, "min": 4.0, "max": 12.0, "wind": 0.9, "rec": 1.4, "dmg": 1.0, "r": 9.0, "lane": 1.3, "speed": 11.0, "title": "ТАРАН"},
		"double": {"act": "slam", "w": 1.0, "cd": 9.0, "max": 3.2, "wind": 1.0, "rec": 0.2, "dmg": 0.75, "r": 3.0, "then": "double2"},
		"double2": {"act": "slam", "w": 0.0, "wind": 0.65, "rec": 1.6, "dmg": 0.75, "r": 3.4},
		"quake": {"act": "ring", "w": 1.2, "cd": 9.0, "max": 6.0, "wind": 1.1, "rec": 1.4, "dmg": 0.9, "r": 8.0, "dur": 1.1, "title": "ВОЛНА"},
		"rampage": {"act": "slam", "w": 4.0, "cd": 14.0, "cond": "low", "max": 4.0, "wind": 1.3, "rec": 0.2, "dmg": 0.9, "r": 3.6, "then": "rampage2", "title": "БЕШЕНСТВО"},
		"rampage2": {"act": "ring", "w": 0.0, "wind": 0.7, "rec": 2.0, "dmg": 0.8, "r": 9.0, "dur": 1.2},
	},
	"ghost": {
		"touch": {"act": "melee", "w": 2.0, "max": 2.4, "wind": 0.5, "rec": 0.6, "dmg": 1.0, "r": 2.3, "half": 1.1},
		"behind": {"act": "blink", "w": 2.5, "cd": 5.0, "min": 2.5, "wind": 0.45, "rec": 0.0, "to": "behind", "then": "back_strike"},
		"back_strike": {"act": "melee", "w": 0.0, "wind": 0.55, "rec": 0.8, "dmg": 1.2, "r": 2.4, "half": 1.2, "title": "СО СПИНЫ"},
		"hop": {"act": "blink", "w": 1.4, "cd": 6.0, "wind": 0.35, "rec": 0.0, "to": "side", "then": "hop2"},
		"hop2": {"act": "blink", "w": 0.0, "wind": 0.35, "rec": 0.0, "to": "front", "then": "touch"},
		"vanish": {"act": "blink", "w": 1.0, "cd": 9.0, "wind": 0.6, "rec": 0.0, "to": "far", "hide": 0.8, "then": "back_strike"},
		"mirror": {"act": "clones", "w": 1.2, "cd": 12.0, "wind": 0.7, "rec": 0.6, "n": 2, "title": "КОПИИ"},
	},
	"lawyer": {
		"homing": {"act": "shoot", "w": 2.0, "min": 3.0, "wind": 0.8, "rec": 0.9, "dmg": 1.0, "n": 1, "speed": 6.0, "homing": 1.6, "r": 12.0, "lane": 0.6},
		"drift": {"act": "shoot", "w": 1.4, "cd": 6.0, "min": 3.0, "wind": 0.8, "rec": 1.0, "dmg": 0.7, "n": 3, "spread": 0.7, "speed": 4.0, "homing": 0.8, "r": 12.0, "half": 0.75},
		"sides": {"act": "shoot", "w": 1.2, "cd": 8.0, "min": 3.0, "wind": 0.9, "rec": 1.0, "dmg": 0.7, "n": 2, "from_sides": true, "speed": 7.0, "homing": 1.0, "r": 12.0, "lane": 0.6},
		"cage": {"act": "zone", "w": 1.0, "cd": 11.0, "min": 3.0, "wind": 0.8, "rec": 1.0, "dmg": 0.9, "zr": 1.6, "delay": 1.25, "cage": 6, "title": "ПОСТАНОВЛЕНИЕ"},
		"precise": {"act": "shoot", "w": 0.9, "cd": 12.0, "min": 4.0, "wind": 1.2, "rec": 1.4, "dmg": 1.7, "n": 1, "speed": 13.0, "homing": 3.0, "r": 12.0, "lane": 0.6, "title": "ИСК", "col": [1.0, 0.85, 0.35]},
		"repel": {"act": "repel", "w": 5.0, "cd": 7.0, "max": 3.0, "cond": "close", "wind": 0.5, "rec": 0.3, "dmg": 0.7, "r": 3.2},
	},
	"mod": {
		"punch": {"act": "melee", "w": 2.0, "max": 2.4, "wind": 0.5, "rec": 0.6, "dmg": 1.0, "r": 2.2, "half": 1.1},
		"bash": {"act": "lunge", "w": 1.6, "cd": 4.0, "max": 3.0, "wind": 0.55, "rec": 0.8, "dmg": 1.1, "r": 2.0, "dash": 1.0, "half": 0.9, "title": "ЩИТОМ"},
		"rush": {"act": "charge", "w": 1.2, "cd": 8.0, "min": 3.5, "max": 10.0, "wind": 0.8, "rec": 1.2, "dmg": 1.0, "r": 7.0, "lane": 1.0, "speed": 9.5, "title": "БАН"},
		"riposte": {"act": "melee", "w": 0.0, "wind": 0.3, "rec": 0.8, "dmg": 1.2, "r": 2.3, "half": 1.2, "title": "ОТВЕТ"},
		"wall": {"act": "ritual", "w": 3.0, "cd": 10.0, "max": 6.0, "cond": "spam", "wind": 0.4, "rec": 0.2, "ward": 2.5, "title": "СТОЙКА"},
		"pin": {"act": "lunge", "w": 3.0, "cd": 7.0, "max": 4.0, "cond": "ally", "wind": 0.6, "rec": 0.9, "dmg": 1.0, "r": 2.0, "dash": 2.0, "half": 0.8, "title": "ЗАЖАЛ"},
	},
	"farmer": {
		"summon": {"act": "summon", "w": 2.0, "cd": 6.0, "wind": 1.0, "rec": 0.8, "kinds": ["bot", "bot"], "n": 2},
		"summon_mix": {"act": "summon", "w": 1.2, "cd": 10.0, "wind": 1.1, "rec": 0.8, "kinds": ["clipper", "bot"], "n": 2},
		"buff": {"act": "buff", "w": 1.4, "cd": 9.0, "cond": "ally", "wind": 0.8, "rec": 0.6, "r": 9.0, "title": "НАКРУТКА"},
		"ritual": {"act": "ritual", "w": 1.0, "cd": 12.0, "wind": 0.6, "rec": 0.4, "ward": 3.0, "allies": true, "title": "РИТУАЛ"},
		"field": {"act": "zone", "w": 1.0, "cd": 7.0, "min": 3.0, "wind": 0.7, "rec": 0.8, "dmg": 1.0, "zr": 2.2, "delay": 1.0, "n": 3, "dmg_abs": 11.0},
		"scare": {"act": "repel", "w": 6.0, "cd": 8.0, "max": 3.5, "cond": "close", "wind": 0.45, "rec": 0.2, "dmg": 0.0, "dmg_abs": 9.0, "r": 3.6, "spawn": "bot", "title": "ПУГАЛО"},
	},
}

# ---------------- выбор приёма ----------------
## Приём по полезности: вес × годность дистанции × условия; перезарядки — в e.move_cd. {} — пока ничего.
static func pick(e, dist: float) -> Dictionary:
	var table: Dictionary = (e.get_meta("moves") as Dictionary) if e.has_meta("moves") else MOVES.get(String(e.kind), {})
	if table.is_empty():
		return {}
	var r = e.game.read
	var best := ""
	var bs := 0.0
	for id in table:
		var m: Dictionary = table[id]
		var w: float = float(m.get("w", 1.0))
		if w <= 0.0 or float(e.move_cd.get(id, 0.0)) > e.age:
			continue
		if dist < float(m.get("min", 0.0)) or dist > float(m.get("max", 99.0)):
			continue
		if m.has("cond") and not cond(e, String(m["cond"]), r, dist):
			continue
		var s: float = w * randf_range(0.6, 1.4)
		if m.has("cond"):
			s *= 1.5                     # обстановка подходит — этот приём и нужен
		if s > bs:
			bs = s
			best = id
	if best == "":
		return {}
	return with_id(table[best], best)

static func with_id(m: Dictionary, id: String) -> Dictionary:
	var c := m.duplicate()
	c["id"] = id
	return c

static func move_of(e, id: String) -> Dictionary:
	var table: Dictionary = MOVES.get(String(e.kind), {})
	return with_id(table[id], id) if table.has(id) else {}

static func cond(e, c: String, r, dist: float) -> bool:
	var p = e.game.player
	match c:
		"low":
			return e.hp < e.max_hp * float(TUNE["low_hp"])
		"block":
			return r != null and float(r.block_streak) > 0.9
		"idle":
			return r != null and float(r.idle_front) > 1.3 and dist < 3.0
		"spam":
			return r != null and int(r.same_hits) >= 4
		"close":
			return dist < 3.2
		"behind":
			var fw := Vector3(sin(p.face), 0, cos(p.face))
			return fw.dot((e.global_position - p.global_position).normalized()) < -0.3
		"ally":
			for o in e.game.enemies:
				if o != e and is_instance_valid(o) and o.alive() and o.boss_id == "" and o.global_position.distance_to(p.global_position) < 5.0 and o.kind != "farmer":
					return true
			return false
	return false

## Форма метки для приёма: [радиус, половина угла, полуширина полосы]; пусто — у приёма своя метка (зона, волна) или нет удара
static func tell_of(_e, m: Dictionary) -> Array:
	match String(m["act"]):
		"melee", "feint":
			return [float(m.get("r", 2.2)), float(m.get("half", 1.1)), 0.0]
		"lunge":
			return [float(m.get("r", 2.2)) + float(m.get("dash", 0.0)), float(m.get("half", 1.0)), 0.0]
		"slam", "repel", "ring":
			return [float(m.get("r", 3.0)), PI, 0.0]
		"charge":
			return [float(m.get("r", 9.0)), 0.0, float(m.get("lane", 1.2))]
		"shoot":
			if m.has("half"):
				return [float(m.get("r", 10.0)), float(m["half"]), 0.0]
			if bool(m.get("from_sides", false)):
				return []
			return [float(m.get("r", 10.0)), 0.0, float(m.get("lane", 0.5))]
		"summon", "ritual", "buff":
			return [3.0 if String(m["act"]) == "summon" else 2.0, PI, 0.0]
	return []

# ---------------- удар ----------------
## Удар в конце замаха. Возвращает следующий приём связки или {}.
static func strike(e, m: Dictionary, dist: float, dir: Vector3) -> Dictionary:
	var g = e.game
	var p = g.player
	var dmg: float = float(m.get("dmg_abs", float(e.cfg["dmg"]) * float(m.get("dmg", 1.0)))) * float(TUNE["dmg"]) * (1.25 if e.buff_t > 0.0 else 1.0)
	var fw := Vector3(sin(e.face), 0, cos(e.face))
	var col: Color = VfxProfiles.enemy_motif(e)["main"]
	if m.has("title"):
		g.popup(e.global_position + Vector3(0, e.height + 0.5, 0), String(m["title"]), col.lightened(0.3))
	match String(m["act"]):
		"melee":
			g.main.sfx("sfx_slash" if e.kind == "clipper" else ("sfx_swing_heavy" if m.get("heavy", false) else "sfx_swing"), -6.0)
			if dist < float(m["r"]) and fw.angle_to(dir) < float(m.get("half", 1.1)):
				p.take_damage(dmg, e.global_position, e)
		"lunge":
			var dash: float = float(m.get("dash", 1.0))
			var reach: float = float(m["r"]) + dash
			g.main.sfx("sfx_slash" if e.kind == "clipper" else "sfx_swing", -5.0)
			e.kb = fw * dash * 9.0           # рывок виден: враг проезжает вперёд
			e.kb_hit = false
			if dist < reach and fw.angle_to(dir) < float(m.get("half", 1.0)):
				p.take_damage(dmg, e.global_position, e)
		"slam", "repel":
			g.shake(0.35 if String(m["act"]) == "slam" else 0.15)
			if String(m["act"]) == "slam":
				g.fx.slam(e.global_position, clampf(float(m["r"]) / 2.6, 0.8, 1.5), col)
				g.main.sfx("sfx_boom", -3.0)
			else:
				g.fx.ground_ring(e.global_position, 0.4, float(m["r"]), Color(col.r, col.g, col.b, 0.7), 0.3)
				g.main.sfx("sfx_cast", -5.0, 1.3)
			if dist < float(m["r"]) and dmg > 0.0:
				p.take_damage(dmg, e.global_position, e)
			if String(m["act"]) == "repel":
				p.velocity += dir * 7.0
				if m.has("spawn") and summoned_alive(e) < int(TUNE["summon_cap"]):
					_summon(e, [String(m["spawn"])], 1, e.global_position + dir * 1.6)
				blink(e, "away")
		"charge":
			e.charge_dir = fw
			e.charge_dmg = dmg
			e.charge_r = float(m.get("lane", 1.2)) + 0.3
			e.charge_len = float(m.get("r", 9.0)) / float(m.get("speed", 11.0))
			e.charge_v = float(m.get("speed", 11.0))
			e.state = "charge"
			e.t = 0.0
			g.main.sfx("sfx_swing_heavy", -2.0)
		"feint":
			g.popup(e.global_position + Vector3(0, e.height + 0.4, 0), "?", Color(1, 1, 1))
		"shoot":
			_shoot(e, m, dmg, dir)
		"zone":
			var at: Vector3 = p.global_position + p.velocity * float(m.get("lead", 0.35))
			if int(m.get("cage", 0)) > 0:
				var nn: int = int(m["cage"])
				var gap := randi() % nn
				for i in nn:
					if i == gap:
						continue                 # выход из клетки — один, видно какой
					var a := TAU * i / nn
					g.telegraph(p.global_position + Vector3(sin(a), 0, cos(a)) * 2.4, float(m["zr"]), float(m["delay"]), dmg, e, {"col": col})
			else:
				for i in int(m.get("n", 1)):
					var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
					var tx := {"col": col}
					if m.has("slow"):
						tx["slow"] = float(m["slow"])
					g.telegraph(Vector3(at.x, 0, at.z) + off, float(m["zr"]), float(m["delay"]) + i * 0.15, dmg, e, tx)
			g.main.sfx("sfx_cast", -6.0)
		"ring":
			g.fx.slam(e.global_position, 1.2, col)
			g.shake(0.4)
			g.expanding_ring(e.global_position, float(m.get("r", 8.0)), float(m.get("dur", 1.1)), dmg, e)
			g.main.sfx("sfx_boom", -2.0, 0.8)
		"blink":
			blink(e, String(m.get("to", "side")), float(m.get("hide", 0.0)))
		"clones":
			for i in int(m.get("n", 2)):
				var a := randf() * TAU
				var at2: Vector3 = p.global_position + Vector3(sin(a), 0, cos(a)) * 4.0
				if g.in_arena(at2, 1.0):
					var c = g._make_enemy("phantom", "", Vector3(at2.x, 0.05, at2.z))
					if c == null:
						break
					e.spawned.append(c)
					g.fx.poof(at2, 1.0, col)
			blink(e, "side")
		"summon":
			if summoned_alive(e) < int(m.get("cap", TUNE["summon_cap"])):
				_summon(e, m.get("kinds", ["bot"]), int(m.get("n", 1)), Vector3.INF)
		"buff":
			for o in g.enemies:
				if o != e and is_instance_valid(o) and o.alive() and o.boss_id == "" and o.global_position.distance_to(e.global_position) < float(m.get("r", 9.0)):
					o.buff_t = 6.0
					g.fx.twinkle(o.global_position + Vector3(0, o.height * 0.7, 0), 8, col, 0.6)
			g.main.sfx("sfx_cast", -4.0, 1.2)
		"ritual":
			e.ward_t = float(m.get("ward", 2.5))
			if bool(m.get("allies", false)):
				for o in e.spawned:
					if is_instance_valid(o) and o.alive():
						o.ward_t = 2.0
			g.main.sfx("sfx_cast", -4.0, 0.7)
	var nxt: String = String(m.get("then", ""))
	if nxt != "" and e.alive() and e.state in ["wind", "recover", "chase"]:
		return move_of(e, nxt)
	return {}

## Снаряды: веер, очередь, упреждение, с боков, медленные с поворотом, замедляющий
static func _shoot(e, m: Dictionary, dmg: float, dir: Vector3) -> void:
	var g = e.game
	var p = g.player
	var from: Vector3 = e.global_position + Vector3(0, e.height * 0.75, 0) + dir * 0.6
	var cl: Array = m.get("col", [])
	var col: Color = Color(cl[0], cl[1], cl[2]) if cl.size() == 3 else VfxProfiles.enemy_motif(e)["main"]
	var n: int = int(m.get("n", 1))
	var speed: float = float(m.get("speed", 9.0))
	var extra := {"turn": float(m.get("homing", 0.0)), "slow": float(m.get("slow", 0.0))}
	var homing: bool = float(m.get("homing", 0.0)) > 0.0
	g.main.sfx("sfx_cast", -6.0)
	g.fx.muzzle(from, col)
	for i in n:
		var aim: Vector3 = dir
		if m.has("lead"):
			var to: Vector3 = p.global_position + p.velocity * float(m["lead"]) - e.global_position
			to.y = 0
			aim = to.normalized() if to.length() > 0.1 else dir
		var start := from
		if bool(m.get("from_sides", false)):
			var side := dir.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
			start = p.global_position + side * 6.0 + Vector3(0, 1.0, 0)
			aim = -side
			g.telegraph(Vector3(start.x, 0, start.z), 0.7, 0.6, 0.0, e, {"col": col})   # видно, откуда прилетит
		if m.has("spread"):
			aim = aim.rotated(Vector3.UP, (i - (n - 1) * 0.5) * float(m["spread"]))
		if m.has("seq") and i > 0:
			var st := start
			var am := aim
			e.get_tree().create_timer(i * float(m["seq"]), false).timeout.connect(func():
				if is_instance_valid(e) and e.alive():
					g.spawn_bolt(st, am * speed, dmg, e, homing, col, extra))
		else:
			g.spawn_bolt(start, aim * speed, dmg, e, homing, col, extra)

## Перемещение: behind — за спину героя, side — сбоку, front — перед ним, far — подальше, away — от героя
static func blink(e, to: String, hide := 0.0) -> void:
	var g = e.game
	var p = g.player
	var pp: Vector3 = p.global_position
	var fw := Vector3(sin(p.face), 0, cos(p.face))
	var col: Color = VfxProfiles.enemy_motif(e)["main"]
	var at: Vector3 = e.global_position
	match to:
		"behind":
			at = pp - fw * 2.2
		"side":
			at = pp + fw.cross(Vector3.UP).normalized() * (2.6 if randf() < 0.5 else -2.6)
		"front":
			at = pp + fw * 2.2
		"far":
			var a := randf() * TAU
			at = pp + Vector3(sin(a), 0, cos(a)) * 6.5
		"away":
			var d: Vector3 = e.global_position - pp
			d.y = 0
			at = e.global_position + (d.normalized() if d.length() > 0.1 else Vector3.FORWARD) * 4.0
	if not g.in_arena(at, 1.0):
		at = pp + (e.global_position - pp).normalized() * 3.0
		if not g.in_hall:      # запасная точка тоже может оказаться за краем зоны: зажимаем в прямоугольник арены
			at.x = g.arena_c.x + clampf(at.x - g.arena_c.x, -(g.arena_h.x - 1.2), g.arena_h.x - 1.2)
			at.z = g.arena_c.z + clampf(at.z - g.arena_c.z, -(g.arena_h.y - 1.2), g.arena_h.y - 1.2)
	at.y = e.global_position.y
	g.fx.poof(e.global_position, e.height / 1.7, col)
	e.global_position = at
	g.fx.twirl(at, 2.4, col, 0.4, "twirl_03")
	g.main.sfx("sfx_cast", -9.0, 1.5)
	var d2: Vector3 = pp - at
	e.face = atan2(d2.x, d2.z)
	if hide > 0.0:
		e.hide_t = hide

static func summoned_alive(e) -> int:
	e.spawned = e.spawned.filter(func(o): return is_instance_valid(o) and o.state != "dead")
	return e.spawned.size()

static func _summon(e, kinds: Array, n: int, at: Vector3) -> void:
	var g = e.game
	var col: Color = VfxProfiles.enemy_motif(e)["main"]
	g.fx.portal(e.global_position, 4.2, Color(col.r, col.g, col.b, 0.8), 0.9, "magic_02")
	g.main.sfx("sfx_cast", -6.0, 0.7)
	for i in n:
		if summoned_alive(e) >= int(TUNE["summon_cap"]) or g.enemies.size() > 20:
			return
		var pos: Vector3 = at if at != Vector3.INF else e.global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		if not g.in_arena(pos, 1.0):
			pos = e.global_position
		var o = g._make_enemy(String(kinds[i % kinds.size()]), "", Vector3(pos.x, 0.05, pos.z))
		if o == null:
			return
		o.summoned_by = e
		e.spawned.append(o)

# ---------------- группа ----------------
## Роли раз в 0,2 с (game._update_fight): двое ближних — attack, остальные — flank / hold; MOD прикрывает
## стрелка или фермера; стрелки держат дистанцию и не встают рядом с тяжёлым ближним.
static func squad(g) -> void:
	var p = g.player
	var melee: Array = []
	var weak: Array = []
	for e in g.enemies:
		if not is_instance_valid(e) or not e.alive() or e.boss_id != "":
			continue
		if e.cfg.has("ranged") or e.cfg.has("summoner"):
			e.role = "ranged"
			weak.append(e)
		else:
			melee.append(e)
	melee.sort_custom(func(a, b): return a.global_position.distance_squared_to(p.global_position) < b.global_position.distance_squared_to(p.global_position))
	var tokens: int = int(TUNE["tokens"])
	var side := 1.0
	var rest := 0
	for e in melee:
		if e.kind == "mod" and not weak.is_empty():
			var ally = weak[0]
			e.role = "guard"
			e.guard_of = ally
			continue
		if tokens > 0:
			e.role = "attack"
			tokens -= 1
		else:
			# без права атаковать: через одного — заходят с флангов (с разных сторон) и ждут на дистанции
			e.role = "flank" if rest % 2 == 0 else "hold"
			if e.role == "flank":
				e.flank_side = side
				side = -side
			rest += 1

## Куда идти в погоне (вместо прямо на героя): по роли. Возвращает направление (не нормированное — длина = сила).
static func steer(e, dist: float, dir: Vector3) -> Vector3:
	var g = e.game
	var p = g.player
	var pp: Vector3 = p.global_position
	var want := Vector3.ZERO
	match String(e.role):
		"flank":
			var from_p: Vector3 = (e.global_position - pp)
			from_p.y = 0
			var side_dir: Vector3 = from_p.normalized().rotated(Vector3.UP, deg_to_rad(float(TUNE["flank_deg"])) * float(e.flank_side))
			var target: Vector3 = pp + side_dir * float(e.cfg["range"]) * 1.2
			want = target - e.global_position
		"hold":
			var hr: float = float(TUNE["hold_r"])
			if dist < hr - 0.8:
				want = -dir
			elif dist > hr + 0.8:
				want = dir
			else:
				want = dir.cross(Vector3.UP) * float(e.flank_side) * 0.5      # кружит вокруг, ждёт очереди
		"guard":
			if is_instance_valid(e.guard_of) and e.guard_of.alive():
				var ally: Vector3 = e.guard_of.global_position
				var cover: Vector3 = ally + (pp - ally).normalized() * 1.9
				want = cover - e.global_position
				if dist < float(e.cfg["range"]) * 1.1:
					want = dir * 0.3                 # герой рядом — встречает щитом
			else:
				e.role = "attack"
				want = dir
		"ranged":
			var keep: float = float(e.cfg.get("keep", 7.0))
			if dist > keep + 1.5:
				want = dir
			elif dist < keep - 1.5:
				want = -dir
			else:
				want = dir.cross(Vector3.UP) * float(e.flank_side) * 0.4
			for o in g.enemies:
				if o != e and is_instance_valid(o) and o.alive() and (o.kind == "troll" or o.boss_id != "") and o.global_position.distance_to(e.global_position) < 3.5:
					var aw: Vector3 = e.global_position - o.global_position
					aw.y = 0
					want += aw.normalized() * 0.8       # не стоит под тяжёлым ближним
		_:
			if dist > float(e.cfg["range"]) * 0.85:
				want = dir
	want.y = 0
	return want.normalized() if want.length() > 1.0 else want

## Можно ли сейчас начинать атаку (роль и общий лимит ближних)
static func may_attack(e, dist: float) -> bool:
	if e.cfg.has("ranged") or e.cfg.has("summoner"):
		return true
	if e.role in ["hold"]:
		return false
	if e.role == "flank" and dist > float(e.cfg["range"]) * 1.6:
		return false
	return e.game.melee_attackers() < int(TUNE["tokens"])

## Честность: удар этого врага не придёт в одно мгновение с ударом другого — замах удлиняется
static func stagger_wind(e, w: float) -> float:
	# моменты ударов остальных — по порядку: сдвиг только вперёд, поэтому одного прохода хватает
	var ends: Array = []
	for o in e.game.enemies:
		if o == e or not is_instance_valid(o) or o.state != "wind" or o.boss_id != "":
			continue
		ends.append(float(o.cfg["wind"]) - float(o.t))
	ends.sort()
	var mine: float = w
	var gap: float = float(TUNE["gap"])
	for left in ends:
		if absf(float(left) - mine) < gap:
			mine = float(left) + gap + 0.05
	return mine
