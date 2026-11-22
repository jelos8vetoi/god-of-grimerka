## Поведение жителя двора поверх G67Life (он отвечает за позы и голову): расписание мест и ходьба по прямым без навигационной
## сетки (маршрут проверяется капсулой), короткие действия, реплики-пузыри, отход от боя, обход героя. Дальше 38 м не работает.
class_name G67Resident
extends Node

const FAR := 38.0
const MARGIN := 1.2

var rig: Rig
var life: G67Life
var body: StaticBody3D
var yard
var golda
var id := ""
var places: Array = []              # [{pos, yaw, base, alts, act, act_clip, act_len, hide}]
var cur := 0
var state := "stay"                 # stay / walk / act / yield / flee
var path: Array = []
var dest := 0
var next_move := 40.0
var act_t := 0.0
var yield_t := 0.0
var speed := 1.05
var idle_t := 8.0
var near_cd := 0.0
var run_cd := 0.0
var flee_from := false
var log: Array = []                 # события для проверок
var rng := RandomNumberGenerator.new()
var stuck_t := 0.0
var last_pos := Vector3.ZERO

static func attach(yd, r: Rig, lf: G67Life, bd: StaticBody3D, rid: String, pl: Array, seed_v: int) -> G67Resident:
	var R := G67Resident.new()
	R.yard = yd
	R.rig = r
	R.life = lf
	R.body = bd
	R.id = rid
	R.places = pl
	R.rng.seed = seed_v
	R.next_move = R.rng.randf_range(15.0, 45.0)
	R.idle_t = R.rng.randf_range(6.0, 14.0)
	R.last_pos = r.position
	r.add_child(R)
	return R

func _g():
	if golda == null:
		var pl = yard.hero
		if pl != null and is_instance_valid(pl):
			golda = pl.game.golda
	return golda

func _hero() -> Node3D:
	return yard.hero if yard != null and yard.hero != null and is_instance_valid(yard.hero) else null

func _clear(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var d := b - a
	d.y = 0.0
	if d.length() < 0.05:
		return true
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.collision_mask = 1
	q.exclude = [body.get_rid()] if body != null else []
	q.transform = Transform3D(Basis(), Vector3(a.x, 0.95, a.z))
	q.motion = d
	var r: Array = space.cast_motion(q)
	return r.size() < 2 or float(r[0]) > 0.995

func _busy_scene() -> bool:
	var g = _g()
	return g == null or g.clip != null or g.talk_on or g.scene_t >= 0.0 or g.ev_cam or g.ev_busy or g.game.mode == "dlg"

func _physics_process(dt: float) -> void:
	var g = _g()
	var h := _hero()
	if g == null or h == null or g.place != "run" or g.game.get_tree().paused:
		return
	var tp: Dictionary = g.point("talk_" + id)
	if not tp.is_empty():
		tp["pos"] = rig.global_position
	var dist: float = rig.global_position.distance_to(h.global_position)
	if dist > FAR:
		return
	near_cd = maxf(0.0, near_cd - dt)
	run_cd = maxf(0.0, run_cd - dt)
	var fighting: bool = g.room_state == "fight" or g.room_state == "boss"
	var arena: Vector3 = g.game.arena_c
	var fight_d: float = Vector2(rig.global_position.x - arena.x, rig.global_position.z - arena.z).length()
	if fighting and g.room_state == "fight" and fight_d < float(G67LifeData.REACT["fight_near"]) and not flee_from and state != "flee":
		_start_flee(arena, g)
	elif not fighting and flee_from:
		flee_from = false
		if state == "flee":
			state = "stay"
		_go(cur, 0.0)
	if g.room_state == "boss":
		return
	match state:
		"stay":
			if life != null:
				life.watcher = h
			_stay_tick(dt, dist, h, g)
		"walk", "flee":
			_walk_tick(dt, h)
		"yield":
			yield_t -= dt
			if h.global_position.distance_to(rig.global_position) > 1.6 or yield_t <= 0.0:
				state = "walk"
		"act":
			act_t -= dt
			if act_t <= 0.0:
				_end_act()

func _stay_tick(dt: float, dist: float, h: Node3D, g) -> void:
	if g.room_state == "fight" or _busy_scene():
		return
	next_move -= dt
	idle_t -= dt
	var bk: G67Barks = g.barks_get()
	if dist < 2.5 and near_cd <= 0.0:
		near_cd = 25.0
		bk.say(rig, bk.pick(id + "_near", G67LifeData.BARKS[id]["near"]))
	elif h is CharacterBody3D and dist < 3.0 and run_cd <= 0.0 and (h as CharacterBody3D).velocity.length() > 6.5:
		run_cd = 30.0
		bk.say(rig, bk.pick(id + "_run", G67LifeData.BARKS[id]["run"]))
	elif idle_t <= 0.0 and dist > 4.0 and dist < 10.0:
		var gap: Array = G67LifeData.REACT["bark_gap"]
		idle_t = rng.randf_range(float(gap[0]), float(gap[1]))
		var pool: Array = (G67LifeData.BARKS[id]["idle"] as Array).duplicate()
		if G67Yard.secret_tag:
			pool.append_array(G67LifeData.BARKS[id]["win"])
		bk.say(rig, bk.pick(id + "_idle", pool))
	if next_move <= 0.0 and places.size() > 1:
		next_move = rng.randf_range(40.0, 90.0)
		var tries := 0
		while tries < 6:
			var k := (cur + 1 + rng.randi() % (places.size() - 1)) % places.size()
			var pp: Vector3 = places[k]["pos"]
			if _clear(rig.position, pp) and pp.distance_to(h.global_position) > 1.6:
				_go(k, 1.0)
				return
			tries += 1

func _go(k: int, spd: float) -> void:
	var p: Dictionary = places[k]
	dest = k
	path = [p["pos"]]
	state = "walk"
	if spd > 0.0:
		speed = spd * rng.randf_range(0.9, 1.15)
	rig.visible = true
	if life != null:
		life.stage("NWalkBag" if String(life.base) == "NBag" else "NWalk", 0.3)
	log.append(["go", k])

func _start_flee(arena: Vector3, g) -> void:
	flee_from = true
	var away := Vector3(rig.global_position.x - arena.x, 0.0, rig.global_position.z - arena.z)
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	var safe := rig.global_position + away.normalized() * 6.0
	if not _clear(rig.position, safe):
		safe = rig.position
	path = [safe]
	state = "flee"
	speed = 1.9
	log.append(["flee"])
	var bk: G67Barks = g.barks_get()
	if id == "g67_npc_ushanka":
		bk.say(rig, bk.pick(id + "_fight", G67LifeData.BARKS[id]["fight"]), {"fight": true})
		if life != null:
			life.stage("Idle", 0.3)
		state = "stay"
		path = []
		return
	bk.say(rig, bk.pick(id + "_fight", G67LifeData.BARKS[id]["fight"]), {"fight": true})
	if life != null:
		life.stage("NWalk", 0.3)

func _walk_tick(dt: float, h: Node3D) -> void:
	if path.is_empty():
		_arrive()
		return
	var tgt: Vector3 = path[0]
	var to := Vector3(tgt.x - rig.position.x, 0.0, tgt.z - rig.position.z)
	if to.length() < 0.15:
		path.pop_front()
		if path.is_empty():
			_arrive()
		return
	var hp: Vector3 = h.global_position
	var rel := Vector3(hp.x - rig.position.x, 0.0, hp.z - rig.position.z)
	if rel.length() < MARGIN and rel.normalized().dot(to.normalized()) > 0.3 and state == "walk":
		state = "yield"
		yield_t = 5.0
		if life != null:
			life.stage("Idle", 0.3)
		return
	if state == "yield":
		return
	var dir := to.normalized()
	var step := minf(to.length(), speed * dt)
	var np := rig.position + dir * step
	rig.position = np
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-6.0 * dt))
	if rig.position.distance_to(last_pos) < 0.01 * dt:
		stuck_t += dt
	else:
		stuck_t = 0.0
	last_pos = rig.position

func _arrive() -> void:
	if state == "flee":
		state = "stay"
		if life != null:
			life.stage("Idle", 0.3)
			life.watcher = _hero()
		return
	cur = dest
	var p: Dictionary = places[cur]
	rig.rotation.y = float(p["yaw"])
	state = "stay"
	if life != null:
		life.base = String(p["base"])
		life.alts = p.get("alts", [])
		life.resume()
	if p.has("act"):
		_begin_act(p)
	log.append(["arrive", cur])

func _begin_act(p: Dictionary) -> void:
	state = "act"
	act_t = float(p.get("act_len", 4.0))
	if bool(p.get("hide", false)):
		rig.visible = false
	elif life != null and p.has("act_clip"):
		life.stage(String(p["act_clip"]), 0.3)
	if String(p["act"]) == "feed" and yard != null:
		yard.feed_near(rig.global_position + rig.global_transform.basis.z * 1.2)
	log.append(["act", String(p["act"])])

func _end_act() -> void:
	rig.visible = true
	state = "stay"
	var p: Dictionary = places[cur]
	if life != null:
		life.base = String(p["base"])
		life.resume()

## Подойти к точке, постоять и вернуться на своё место (школьник показывает телефон)
func visit(pos: Vector3, dur: float) -> void:
	if state != "stay":
		return
	places.append({"pos": Vector3(pos.x, rig.position.y, pos.z), "yaw": rig.rotation.y, "base": "NFilm", "alts": ["NPoint"], "act": "visit", "act_clip": "NPoint", "act_len": dur})
	var back := cur
	_go(places.size() - 1, 1.2)
	next_move = dur + 25.0
	get_tree().create_timer(dur + 12.0).timeout.connect(func():
		if is_instance_valid(self) and places.size() > back and state == "stay":
			_go(back, 1.0))

## Нажатие [E]: реплика по кругу (после победы над Мишей добавляются win)
func use() -> void:
	var g = _g()
	if g == null:
		return
	var bk: G67Barks = g.barks_get()
	var pool: Array = (G67LifeData.BARKS[id]["use"] as Array).duplicate()
	if G67Yard.secret_tag:
		pool.append_array(G67LifeData.BARKS[id]["win"])
	bk.say(rig, bk.pick(id + "_use", pool), {"force": true, "dur": 5.0})
