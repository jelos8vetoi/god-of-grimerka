## Разговоры жителей между собой (G67LifeData.DUOS): реплики по очереди пузырями, жесты у говорящего, слушающий смотрит на него.
## Герой в 5–14 м — идёт; ближе near_r — hush-реплика, оба молчат и смотрят на героя; отошёл — с той же строки.
## Один разговор за раз на зону, повтор не раньше 4 минут, выбор по кругу. В бою и постановках молчат.
class_name G67Duos
extends Node

const NEAR_R := 3.0
const REPEAT := 240.0

var golda
var yard
var clock := 0.0
var done_at := {}                       # id → время конца
var active := {}                        # зона → состояние разговора
var next_try := 4.0
var log: Array = []                     # [время, id, событие] для проверок
var hush_log: Array = []
var order := {}                         # зона → индекс круга

static func make(g, yd) -> G67Duos:
	var D := G67Duos.new()
	D.golda = g
	D.yard = yd
	D.name = "G67Duos"
	return D

func _hero() -> Node3D:
	return golda.game.player

## Участники разговора: роли → узлы
func _who(duo: Dictionary) -> Array:
	var out: Array = []
	for w in duo["who"]:
		var n: Node3D = null
		var s := String(w)
		if s == "walker":
			n = golda.ylife_get().walker_for(duo)
		elif yard.residents.has(s):
			n = yard.residents[s].rig
		elif s.begins_with("queue"):
			var i := int(s.substr(5))
			if i < yard.queue.size():
				n = yard.queue[i]
		elif s.begins_with("fan"):
			var i2 := int(s.substr(3)) - 1
			if i2 >= 0 and i2 < yard.fans.size():
				n = yard.fans[i2]
		elif s.begins_with("gazebo"):
			var i3 := int(s.substr(6)) - 1
			if i3 >= 0 and i3 < yard.gazebo_people.size():
				n = yard.gazebo_people[i3]
		if n == null or not is_instance_valid(n):
			return []
		out.append(n)
	return out

## Кто произносит строку: своя реплика жителя — он; иначе коды по порядку появления
func _assign(duo: Dictionary, who: Array) -> Dictionary:
	var map := {}
	var own := {"BB": "g67_npc_babushka", "TX": "g67_npc_taxi_driver", "US": "g67_npc_ushanka", "SC": "g67_npc_schoolboy"}
	var free_idx: Array = range(who.size())
	for code in own:
		var i: int = (duo["who"] as Array).find(own[code])
		if i >= 0:
			map[code] = i
			free_idx.erase(i)
	var seq: Array = (duo["lines"] as Array) + [duo.get("hush", "")]
	for ln in seq:
		var code := String(ln).get_slice("|", 0)
		if code != "" and not map.has(code) and not free_idx.is_empty():
			map[code] = free_idx.pop_front()
	return map

func _speaker_of(code: String, map: Dictionary, who: Array) -> Node3D:
	return who[int(map.get(code, 0))]

func _life_of(n: Node3D):
	return n.get_meta("life") if n.has_meta("life") else null

func _physics_process(dt: float) -> void:
	if golda == null or yard == null or not is_instance_valid(yard) or golda.place != "run" or golda.game.get_tree().paused:
		return
	clock += dt
	var bk: G67Barks = golda.barks_get()
	if not bk.can_talk(false):
		return
	var hp: Vector3 = _hero().global_position
	for zone in active.keys():
		_tick(zone, dt, hp, bk)
	next_try -= dt
	if next_try > 0.0:
		return
	next_try = 2.0
	for zone in ["gazebo", "parking", "sport", "garages", "playground"]:
		if active.has(zone):
			continue
		_try_start(zone, hp)

func _try_start(zone: String, hp: Vector3) -> void:
	var pool: Array = []
	for d in G67LifeData.DUOS:
		if String(d["zone"]) == zone:
			pool.append(d)
	if pool.is_empty():
		return
	var k := int(order.get(zone, 0))
	for j in pool.size():
		var duo: Dictionary = pool[(k + j) % pool.size()]
		if clock - float(done_at.get(duo["id"], -1000.0)) < REPEAT:
			continue
		var who := _who(duo)
		if who.is_empty():
			continue
		var c := Vector3.ZERO
		for n in who:
			c += (n as Node3D).global_position
		c /= float(who.size())
		var d: float = Vector2(c.x - hp.x, c.z - hp.z).length()
		if d < 5.0 or d > 14.0:
			continue
		var all_stay := true
		for w in duo["who"]:
			if yard.residents.has(String(w)) and (yard.residents[String(w)] as G67Resident).state not in ["stay"]:
				all_stay = false
		if not all_stay:
			continue
		order[zone] = (k + j + 1) % pool.size()
		active[zone] = {"duo": duo, "who": who, "map": _assign(duo, who), "i": 0, "t": 1.0, "hush": false, "said_hush": false}
		log.append([clock, String(duo["id"]), "start"])
		return

func _tick(zone: String, dt: float, hp: Vector3, bk: G67Barks) -> void:
	var st: Dictionary = active[zone]
	var duo: Dictionary = st["duo"]
	var who: Array = st["who"]
	for n in who:
		if not is_instance_valid(n):
			_finish(zone, false)
			return
	var near := false
	var c := Vector3.ZERO
	for n in who:
		var p: Vector3 = (n as Node3D).global_position
		c += p
		if Vector2(p.x - hp.x, p.z - hp.z).length() < NEAR_R:
			near = true
	c /= float(who.size())
	var d: float = Vector2(c.x - hp.x, c.z - hp.z).length()
	if near:
		if not bool(st["hush"]):
			st["hush"] = true
			var hl := String(duo.get("hush", ""))
			for n in who:
				var lf = _life_of(n)
				if lf != null:
					lf.watcher = _hero()
					lf.resume()
			if hl != "" and not bool(st["said_hush"]):
				st["said_hush"] = true
				var sp := _speaker_of(hl.get_slice("|", 0), st["map"], who)
				bk.say(sp, hl, {"force": true, "dur": 3.0})
				hush_log.append([clock, String(duo["id"]), st["i"]])
			log.append([clock, String(duo["id"]), "hush"])
		return
	if bool(st["hush"]):
		st["hush"] = false
		st["said_hush"] = false
		st["t"] = 1.5
		log.append([clock, String(duo["id"]), "resume %d" % int(st["i"])])
	if d > 14.5:
		return                                   # герой ушёл — стоят на этой строке
	if d < 4.0:
		return
	st["t"] = float(st["t"]) - dt
	if float(st["t"]) > 0.0:
		return
	var lines: Array = duo["lines"]
	var i := int(st["i"])
	if i >= lines.size():
		_finish(zone, true)
		return
	var ln := String(lines[i])
	var speaker := _speaker_of(ln.get_slice("|", 0), st["map"], who)
	var dur := clampf(1.6 + (ln.length() - 3) * 0.05, 2.2, 6.0)
	bk.say(speaker, ln, {"force": true, "dur": dur, "far": d > 9.0})
	var sl = _life_of(speaker)
	if sl != null:
		var clip := "NTalk" if (speaker.get_meta("life") as G67Life).base.begins_with("N") else "STalk"
		if (speaker as Rig).has_clip(clip):
			sl.stage(clip, 0.3)
			get_tree().create_timer(dur).timeout.connect(func():
				if is_instance_valid(sl) and is_instance_valid(speaker):
					sl.resume())
	for n in who:
		if n != speaker:
			var ll = _life_of(n)
			if ll != null:
				ll.watcher = speaker
				ll.look_r = 30.0
	st["i"] = i + 1
	st["t"] = dur + randf_range(1.8, 3.0)
	log.append([clock, String(duo["id"]), "line %d" % i])

func _finish(zone: String, ok: bool) -> void:
	var st: Dictionary = active.get(zone, {})
	if st.is_empty():
		return
	var duo: Dictionary = st["duo"]
	if ok:
		done_at[duo["id"]] = clock
	log.append([clock, String(duo["id"]), "end" if ok else "abort"])
	for n in st["who"]:
		if is_instance_valid(n):
			var lf = _life_of(n)
			if lf != null:
				lf.watcher = _hero()
				lf.look_r = 7.0
	golda.ylife_get().release_walker(duo)
	active.erase(zone)

## Принудительно (проверка): начать разговор с id
func start_now(id: String) -> bool:
	for d in G67LifeData.DUOS:
		if String(d["id"]) == id:
			var who := _who(d)
			if who.is_empty():
				return false
			active[String(d["zone"])] = {"duo": d, "who": who, "map": _assign(d, who), "i": 0, "t": 0.2, "hush": false, "said_hush": false}
			log.append([clock, id, "start"])
			return true
	return false
