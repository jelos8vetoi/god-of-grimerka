## «ГОЛДА 67», новый ДВОР: территории врагов и встречи (этап A редизайна).
## Враги стоят в районе с начала забега («на посту»), а не выходят волной из воздуха. Встреча — конечный автомат:
##   post → noticed (ступень 1: заметили) → warned (ступень 2: один идёт навстречу) → fight (ступень 3: бой)
##   fight → cleared (победа: сумка с добычей) | post (первый побег: награды нет, группа осталась) | gone (второй побег: группа ушла)
## Отступление — только ногами: дальше FLEE метров от центра территории. Победа после побега даёт половину сумки и без бафа.
## Состояние каждой встречи живёт в run["enc"][id] и уходит в сохранение забега вместе с run — отдельного сохранения нет.
## Сама драка — прежняя: враги, жетоны атаки, приёмы — enemy.gd и EnemyAI; зона game.set_arena держит врагов у их территории.
## Новые встречи — строкой в TURFS. Координаты — план района (X — восток, Y — север).
class_name G67Turf
extends RefCounted

const R_NOTICE := 13.0        # ступень 1: заметили
const R_WARN := 8.0           # ступень 2: предупредили
const R_FIGHT := 4.0          # ступень 3: бой
const CALM := 19.0            # отошёл до боя — успокоились
const WARN_T := 2.6           # сколько длится предупреждение
const LEASH := 18.0           # полуразмер зоны, дальше которой враги не идут
const FLEE := 30.0            # дальше — бой брошен
const ENTRY_MIN := 13.0       # подкрепление выходит не ближе этого к герою

## type: battle | elite | ambush (награда и волны — по типу, G67Data); wave — номер позиции для G67Data.waves_for;
## must — обязательная для выхода к Мише; posts — где стоят; from — откуда приходит подкрепление; say — реплики ступеней 1 и 2.
const TURFS := [
	{"id": "garages_home", "name": "ГАРАЖИ У ДОМА", "type": "battle", "wave": 0, "must": true, "c": [-46.5, -93.0],
		"posts": [[-46.6, -96.0], [-45.4, -93.4], [-47.6, -90.8]], "from": [[-45.5, -72.0], [-58.0, -74.6]],
		"say": ["Шестёрка: «О. Гляди, кто вылез».", "Шестёрка: «Слышь, с шестьдесят седьмого. Тут проезд платный»."]},
	{"id": "gsk_stove", "name": "ГСК, ВТОРОЙ ПРОЕЗД", "type": "battle", "wave": 1, "must": false, "c": [-106.0, 33.5],
		"posts": [[-104.0, 33.0], [-106.2, 35.2], [-108.0, 32.4], [-105.6, 31.4]], "from": [[-132.0, 33.5], [-80.0, 33.5]],
		"say": ["Шестёрка: «Тихо. Идёт кто-то».", "Шестёрка: «Э, друг. Ты гаражом не ошибся?»"]},
	{"id": "ambush_towers", "name": "ПРОХОД МЕЖДУ БАШНЯМИ", "type": "ambush", "wave": 5, "must": false, "skip_warn": true, "c": [6.0, 78.0],
		"posts": [[4.4, 77.0], [7.8, 77.6], [13.0, 74.2], [14.6, 75.6]], "from": [[-20.0, 88.0], [34.0, 88.0]],
		"say": ["Шестёрка: «Братан, закурить не будет?»", ""]},
	{"id": "elite_sofa", "name": "ГАРАЖНЫЙ ДВОР У БАШЕН", "type": "elite", "wave": 2, "must": true, "skip_warn": true, "c": [112.0, 28.0],
		"posts": [[114.0, 27.6], [110.6, 29.4], [117.2, 29.4]], "from": [[100.0, 34.0], [128.0, 33.0]],
		"say": ["Смотрящий: «Подойди».", ""]},
]

var g                       # Golda67
var game
var world                   # G67World
var encs: Array = []
var active: Dictionary = {}
var log: Array = []         # события для проверок: [вид, id, …]

static func v3(a: Array) -> Vector3:
	return G67Dvor2.to3(float(a[0]), float(a[1]), 0.05)

func setup(gg) -> void:
	g = gg
	game = gg.game
	world = gg.world
	if not g.run.has("enc"):
		g.run["enc"] = {}
	encs = []
	active = {}
	for d_v in TURFS:
		var d: Dictionary = d_v
		var sv: Dictionary = (g.run["enc"] as Dictionary).get(String(d["id"]), {})
		var e := {"d": d, "id": String(d["id"]), "c": v3(d["c"]), "state": String(sv.get("s", "post")), "flees": int(sv.get("f", 0)), "foes": [], "wave_i": 0, "pending": [],
			"t": 0.0, "cd": 0.0, "wait": 0.0, "lead": null, "said": 0, "bag": {}}
		encs.append(e)
		if String(e["state"]) == "post":
			_post(e)
		elif String(e["state"]) == "cleared" and int(sv.get("bag", 0)) > 0:
			_drop_bag(e, int(sv["bag"]), bool(sv.get("fit", false)))

func enc(id: String) -> Dictionary:
	for e in encs:
		if String(e["id"]) == id:
			return e
	return {}

func _keep(e: Dictionary) -> void:
	var sv: Dictionary = (g.run["enc"] as Dictionary).get(String(e["id"]), {})
	var st := String(e["state"])
	sv["s"] = st if st in ["cleared", "gone"] else "post"         # бой и ступени в сохранение не идут: после загрузки группа снова на посту
	sv["f"] = int(e["flees"])
	var b: Dictionary = e["bag"]
	sv["bag"] = int(b.get("gold", 0)) if not b.is_empty() else 0
	sv["fit"] = bool(b.get("fit", false)) if not b.is_empty() else false
	(g.run["enc"] as Dictionary)[String(e["id"])] = sv

func waves(e: Dictionary) -> Array:
	var d: Dictionary = e["d"]
	return G67Data.waves_for(g.district(), "elite" if String(d["type"]) == "elite" else "battle", int(d["wave"]))

func _alive(e: Dictionary) -> int:
	var n := 0
	for f in e["foes"]:
		if is_instance_valid(f) and f.state != "dead":
			n += 1
	return n

func left() -> int:
	if active.is_empty():
		return 0
	return _alive(active) + (active["pending"] as Array).size()

## Первая волна встаёт на посты: стоят, не нападают, смотрят друг на друга
func _post(e: Dictionary) -> void:
	_free_foes(e)
	var d: Dictionary = e["d"]
	var posts: Array = d["posts"]
	var w: Array = waves(e)
	var i := 0
	for grp in w[0]:
		for k in int(grp[1]):
			var pos := v3(posts[i % posts.size()]) + (Vector3(0.9, 0, 0.6) * float(i / posts.size()))
			var f = g._make_foe(String(grp[0]), pos, true)
			f.post = true
			var c: Vector3 = e["c"]
			f.face = atan2(c.x - pos.x, c.z - pos.z) + (0.5 if i % 2 == 0 else -0.5)
			(e["foes"] as Array).append(f)
			i += 1
	e["wave_i"] = 0
	e["pending"] = []
	e["lead"] = null
	e["state"] = "post"
	e["t"] = 0.0

func _free_foes(e: Dictionary) -> void:
	for f in e["foes"]:
		if is_instance_valid(f):
			game.enemies.erase(f)
			f.queue_free()
	e["foes"] = []

func _hurt(e: Dictionary) -> bool:
	for f in e["foes"]:
		if not is_instance_valid(f) or f.state == "dead" or f.hp < f.max_hp - 0.01:
			return true
	return false

func _say(e: Dictionary, i: int) -> void:
	var lines: Array = e["d"]["say"]
	if i < lines.size() and String(lines[i]) != "" and int(e["said"]) <= i:
		e["said"] = i + 1
		game.toast(String(lines[i]))

func _face_all(e: Dictionary, pp: Vector3) -> void:
	for f in e["foes"]:
		if is_instance_valid(f) and f.post and f.state != "dead":
			f.face = lerp_angle(f.face, atan2(pp.x - f.global_position.x, pp.z - f.global_position.z), 0.12)

func tick(dt: float) -> void:
	if g.busy or game.over or g.room_state in ["boss", "over"]:
		return
	var pp: Vector3 = game.player.global_position
	for e in encs:
		var st := String(e["state"])
		if st in ["cleared", "gone"]:
			continue
		var c: Vector3 = e["c"]
		var d := Vector2(pp.x - c.x, pp.z - c.z).length()
		e["t"] = float(e["t"]) + dt
		match st:
			"post":
				if not active.is_empty():
					continue
				if _hurt(e):
					_fight(e)
				elif d < R_NOTICE:
					e["state"] = "noticed"
					e["t"] = 0.0
					e["said"] = 0
					_say(e, 0)
					G67Sound.play(g, "entry", c)
					log.append(["noticed", String(e["id"])])
			"noticed":
				_face_all(e, pp)
				if _hurt(e):
					_fight(e)
				elif d > CALM:
					e["state"] = "post"
					log.append(["calm", String(e["id"])])
				elif bool(e["d"].get("skip_warn", false)):
					if float(e["t"]) > 0.9 or d < R_WARN:
						_fight(e)
				elif d < R_WARN or float(e["t"]) > 4.0:
					_warn(e)
			"warned":
				_face_all(e, pp)
				var lead = e["lead"]
				var close: bool = is_instance_valid(lead) and lead.global_position.distance_to(pp) < 3.2
				if _hurt(e) or close or d < R_FIGHT or float(e["t"]) > WARN_T:
					_fight(e)
				elif d > CALM:
					if is_instance_valid(lead):
						lead.post = true
					e["lead"] = null
					e["state"] = "post"
					log.append(["calm", String(e["id"])])
			"fight":
				_fight_tick(e, dt, d)

## Ступень 2: один из группы идёт навстречу — понятно, что сейчас начнётся
func _warn(e: Dictionary) -> void:
	e["state"] = "warned"
	e["t"] = 0.0
	_say(e, 1)
	for f in e["foes"]:
		if is_instance_valid(f) and f.state != "dead":
			f.post = false
			f.cool = maxf(f.cool, 1.6)          # идёт, но не бьёт с ходу
			e["lead"] = f
			break
	log.append(["warned", String(e["id"])])

## Ступень 3: бой. Вход защищён от повтора — из любого состояния сюда попадают один раз за попытку.
func _fight(e: Dictionary) -> void:
	if String(e["state"]) == "fight" or not active.is_empty():
		return
	e["state"] = "fight"
	e["t"] = 0.0
	e["cd"] = 0.0
	e["wait"] = 1.2
	active = e
	for f in e["foes"]:
		if is_instance_valid(f):
			f.post = false
	var d: Dictionary = e["d"]
	game.set_arena(e["c"], Vector2(LEASH, LEASH))
	g.room = {"type": String(d["type"]), "place": String(e["id"])}
	g.room_state = "fight"
	g.wind_used = false
	g.fin_room = 0.0
	game.banner(String(d["name"]), String(G67Data.ROOM_NAMES[String(d["type"])]) + (" · вторая попытка: награда вдвое меньше" if int(e["flees"]) > 0 else ""),
		G67Data.ROOM_COLOR[String(d["type"])], 2.2)
	game.main.sfx("sfx_wave", -8.0)
	g.events.append(["room", String(d["type"])])
	g._save_run("fight")
	log.append(["fight", String(e["id"])])

func _fight_tick(e: Dictionary, dt: float, d: float) -> void:
	if d > FLEE:
		_flee(e)
		return
	e["cd"] = maxf(0.0, float(e["cd"]) - dt)
	var pend: Array = e["pending"]
	if not pend.is_empty():
		if _alive(e) < G67Data.FOES_ALIVE_MAX and float(e["cd"]) <= 0.0:
			var f = g._make_foe(String(pend.pop_front()), _entry(e), false)
			(e["foes"] as Array).append(f)
			e["cd"] = randf_range(0.8, 1.4)
		return
	if _alive(e) > 0:
		return
	e["wait"] = float(e["wait"]) - dt
	if float(e["wait"]) > 0.0:
		return
	e["wave_i"] = int(e["wave_i"]) + 1
	var w: Array = waves(e)
	if int(e["wave_i"]) >= w.size():
		_cleared(e)
		return
	for grp in w[int(e["wave_i"])]:
		for k in int(grp[1]):
			pend.append(String(grp[0]))
	pend.shuffle()
	e["wait"] = 1.2
	game.toast("Подкрепление: %d / %d" % [int(e["wave_i"]) + 1, w.size()])
	game.main.sfx("sfx_wave", -8.0)

## Откуда приходит подкрепление: названная точка территории, самая дальняя от героя (не ближе ENTRY_MIN, если такая есть)
func _entry(e: Dictionary) -> Vector3:
	var pp: Vector3 = game.player.global_position
	var best := Vector3.INF
	var bd := -1.0
	for q in e["d"]["from"]:
		var p := v3(q)
		var dd := p.distance_to(pp)
		if dd > bd:
			bd = dd
			best = p
	return best

func _cleared(e: Dictionary) -> void:
	var d: Dictionary = e["d"]
	var type := String(d["type"])
	e["state"] = "cleared"
	active = {}
	game.reset_arena()
	g.room_state = "open"
	var spooked: bool = int(e["flees"]) > 0
	var base: float = float(G67Data.ROOM_GOLDA["elite" if type == "elite" else "battle"]) * (1.5 if type == "ambush" else 1.0)
	var gold := int(round(base * (0.5 if spooked else 1.0)))
	_drop_bag(e, gold, type == "elite" and not spooked)
	var c: Vector3 = e["c"]
	if G67Data.STAGE_HEAL.has(type) and not spooked:
		g._drop_wrap(float(G67Data.STAGE_HEAL[type]), c + Vector3(1.6, 0.0, 1.2), 0.0)
	g._add_respect("elite" if type == "elite" else "battle", int(G67Data.RESPECT["elite" if type == "elite" else "room"]))
	g.run["rooms"] = int(g.run["rooms"]) + 1
	g.run["pos"] = int(g.run.get("pos", 0)) + 1
	(g.run["stages"] as Array).append([type, String(e["id"]), ""])
	g.events.append(["clear", type])
	game.banner("ЧИСТО", "обыщи сумку" + (" · половина награды" if spooked else ""), Color(1, 0.85, 0.3), 2.0)
	_keep(e)
	g._save_run("open")
	log.append(["cleared", String(e["id"]), gold])

## Бой брошен: награды нет. Первый раз группа возвращается на посты, второй — уходит совсем.
func _flee(e: Dictionary) -> void:
	e["flees"] = int(e["flees"]) + 1
	active = {}
	game.reset_arena()
	g.room_state = "open"
	g.room = {}
	_free_foes(e)
	e["pending"] = []
	if int(e["flees"]) >= 2:
		e["state"] = "gone"
		game.toast("Группа ушла с района. Награды не будет.")
	else:
		_post(e)
		game.toast("Ушёл от драки — награды нет. Они ещё там: вторая попытка даст половину.")
	g.events.append(["flee", String(e["id"]), int(e["flees"])])
	_keep(e)
	g._save_run("open")
	log.append(["flee", String(e["id"]), int(e["flees"])])

# ------------------------------------------------------------------ сумка с добычей
func _drop_bag(e: Dictionary, gold: int, fit: bool) -> void:
	if not (e["bag"] as Dictionary).is_empty():
		return
	var c: Vector3 = e["c"]
	var node: Node3D = null
	if world.dvor != null:
		node = world.dvor.put("loot_bag" if world.dvor.man.has("loot_bag") else "trashbag", c.x, -c.z, float(int(c.x * 7.0) % 360), 1.0 if world.dvor.man.has("loot_bag") else 1.5)
	var pid := "bag_" + String(e["id"])
	world._point(pid, "СУМКА", "обыскать", c)
	e["bag"] = {"node": node, "gold": gold, "fit": fit, "pid": pid}
	_keep(e)

## Обыскать сумку: награда выдаётся один раз — сумка и точка исчезают раньше, чем начисляется голда
func take_bag(pid: String) -> int:
	for e in encs:
		var b: Dictionary = e["bag"]
		if b.is_empty() or String(b.get("pid", "")) != pid:
			continue
		var gold := int(b["gold"])
		var fit: bool = bool(b["fit"])
		if is_instance_valid(b.get("node")):
			(b["node"] as Node).queue_free()
		world.points = world.points.filter(func(pt): return String(pt["id"]) != pid)
		e["bag"] = {}
		_keep(e)
		var got: int = g.add_golda(gold)
		game.toast("В сумке: %d голды" % got)
		game.main.ui("confirm")
		g.events.append(["bag", String(e["id"]), got])
		log.append(["bag", String(e["id"]), got])
		g._save_run("open")
		if fit:
			g._offer_fit(true)
		return got
	return 0

# ------------------------------------------------------------------ ритм забега
func _state_n(states: Array, must_only := false) -> int:
	var n := 0
	for e in encs:
		if String(e["state"]) in states and (not must_only or bool(e["d"]["must"])):
			n += 1
	return n

## Можно ли к Мише: каждая обязательная встреча пройдена; ушедшую обязательную заменяет любая другая пройденная.
## Если заменить нечем (все остальные тоже пройдены или ушли) — путь всё равно открыт: побегом забег не блокируется.
func need_done() -> bool:
	var owed := 0
	var spare := 0
	var open := 0
	for e in encs:
		var st := String(e["state"])
		var must: bool = bool(e["d"]["must"])
		if st == "gone" and must:
			owed += 1
		elif st == "cleared" and not must:
			spare += 1
		elif not st in ["cleared", "gone"]:
			if must:
				return false
			open += 1
	return owed <= spare or open == 0

## Куда идти: строка для HUD (значков и лучей в мире нет)
func objective() -> String:
	if not active.is_empty():
		return "врагов: %d · уйти можно ногами, но без награды" % left()
	for e in encs:
		if not (e["bag"] as Dictionary).is_empty():
			return "СУМКА: %s" % String(e["d"]["name"])
	if need_done():
		return "КОРОБКА МИШИ ОТКРЫТА — на север, между башнями"
	for e in encs:
		if bool(e["d"]["must"]) and not String(e["state"]) in ["cleared", "gone"]:
			return "ДАЛЬШЕ: %s%s" % [String(e["d"]["name"]), " (вторая попытка)" if int(e["flees"]) > 0 else ""]
	for e in encs:
		if not String(e["state"]) in ["cleared", "gone"]:
			return "ДОЛГ ЗА ПОБЕГ: %s" % String(e["d"]["name"])
	return ""
