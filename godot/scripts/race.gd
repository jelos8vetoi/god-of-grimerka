## VACUUM RACING — менеджер гонки (самостоятельное игровое состояние: main.race; сюжет, опыт и сохранение кампании
## здесь не участвуют). Строит трассу (race_track.gd), ставит участников (race_rider.gd) на старт, ведёт
## последовательность «облёт → 3-2-1-ЖМИ → гонка → финиш → результаты», считает контрольные точки и круги
## (неправильный порядок не засчитывается), места, предметы, ловушки, толкотню гонщиков, возврат упавших,
## догоняющий механизм ботов, рекорды (race_save.gd). Камера — своя, HUD — race_hud.gd.
##
## Кто управляет участником, гонке всё равно: ввод приходит как RaceInput (игрок, бот или сеть). Всё, что
## решает исход (движение, круги, предметы, случайность), считает только «власть» — authority: офлайн это сама
## игра, в сетевой гонке — хост (race_net.gd); клиент тогда показывает присланные снимки.
class_name Race
extends Node3D

signal state_changed(s: String)

var main
var cfg := {}                  # {track, laps, mode: single/time/online, level, rider, name, seed}
var track: RaceTrack
var riders: Array = []         # RaceRider
var local: RaceRider           # кем играет этот компьютер
var cam: Camera3D
var hud                        # RaceHud
var fx
var state := "intro"           # intro / countdown / race / done / results
var st := 0.0                  # время в состоянии
var t := 0.0                   # часы гонки (с «ЖМИ»)
var go := false
var laps := 3
var rng := RandomNumberGenerator.new()
var boxes: Array = []          # [{pos, node, t}]
var hazards: Array = []        # [{kind, pos, r, life, owner, hits, hit, node}]
var tethers: Array = []        # [{from, to, t}]
var obstacles: Array = []
var order: Array = []          # финишировавшие по порядку
var results: Array = []        # [{rider, title, time, best, est}]
var sound_on := true
var authority := true
var net                        # race_net.gd в сетевой гонке
var paused := false
var autopilot: RaceAI          # после финиша игрока ведёт бот
var bump_cd := {}
var trauma := 0.0
var cam_fov := 70.0
var look_back := false
var dust_vis := 0.0            # игрок в облаке пыли (HUD)
var new_record := ""
var stats := {"frames": 0, "slow": 0}
var cam_snap := false

func setup(m, c: Dictionary) -> void:
	main = m
	cfg = c
	laps = int(cfg.get("laps", 3))
	rng.seed = int(cfg.get("seed", Time.get_ticks_usec()))
	authority = String(cfg.get("mode", "single")) != "online" or bool(cfg.get("host", true))
	sound_on = main == null or main.testing() == "" or main.audiolog
	track = RaceTrack.new()
	add_child(track)
	track.build(String(cfg.get("track", "tomsk_dust")))
	obstacles = track.obstacle_pts
	fx = preload("res://scripts/fx.gd").new()
	add_child(fx)
	_spawn_riders()
	_spawn_boxes()
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	hud = RaceHud.new()
	hud.race = self
	add_child(hud)
	_set_state("intro")

## участники: игрок (или игроки по сети) и боты; в заезде на время — один игрок
func _spawn_riders() -> void:
	var list: Array = cfg.get("riders", [])
	if list.is_empty():
		list.append({"id": String(cfg.get("rider", "pahan")), "kind": "local", "name": String(cfg.get("name", "ПАХАН")), "peer": 1})
		if String(cfg.get("mode", "single")) == "single":
			for k in RaceData.RIVALS.size():
				list.append({"id": RaceData.RIVALS[k], "kind": "bot", "peer": 1})
	for k in list.size():
		var d: Dictionary = list[k]
		var r := RaceRider.new()
		add_child(r)
		r.setup(self, String(d["id"]), k, String(d["kind"]), k < 3 or String(d["kind"]) == "local")
		if d.has("name"):
			r.title = String(d["name"])
		r.peer = int(d.get("peer", 1))
		r.place(track.grid(k))
		r.proj = track.project(r.global_position, {})
		r.s = float(r.proj["s"])
		r.prev_s = r.s
		r.next_gate = 0
		if r.kind == "bot":
			var ai := RaceAI.new()
			ai.setup(r, self, String(cfg.get("level", "normal")), rng.randi())
			r.ai = ai
		if r.kind == "local":
			local = r
		riders.append(r)

func _spawn_boxes() -> void:
	if String(cfg.get("mode", "single")) == "time":
		return                                   # заезд на время — чистая езда, без предметов
	for p in track.boxes:
		var n := Node3D.new()
		n.position = p
		add_child(n)
		if RaceProps.spawn("item_box", n, Vector3(0, -0.5, 0), 0.0, 0.95, false) != null:
			boxes.append({"pos": p, "node": n, "t": 0.0})
			continue
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.9)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.95, 0.97, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.15, 0.15)
		mat.emission_energy_multiplier = 0.6
		mi.material_override = mat
		n.add_child(mi)
		var q := Label3D.new()
		q.text = "?"
		q.font_size = 96
		q.pixel_size = 0.008
		q.modulate = Color(0.85, 0.08, 0.1)
		q.outline_size = 10
		q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		q.no_depth_test = false
		n.add_child(q)
		boxes.append({"pos": p, "node": n, "t": 0.0})

func _set_state(s: String) -> void:
	state = s
	st = 0.0
	state_changed.emit(s)

# ---------------- шаг ----------------
func _physics_process(dt: float) -> void:
	if paused:
		return
	st += dt
	match state:
		"intro":
			if st >= 2.4:
				_set_state("countdown")
				hud.countdown(3)
				_beep(0.9)
		"countdown":
			var left := 3 - int(st)
			if left != hud.count_shown and left >= 1:
				hud.countdown(left)
				_beep(0.9)
			if st >= 3.0:
				go = true
				t = 0.0
				for r in riders:
					r.lap_t0 = 0.0
				_set_state("race")
				hud.countdown(0)
				_beep(1.5)
				if main != null:
					main.sfx("sfx_rage", -6.0, 1.3)
		"race", "done":
			t += dt
	if not authority:
		return                                  # клиент: всё считает хост
	for r in riders:
		var inp: RaceInput = _input_of(r, dt)
		r.simulate(inp, dt, go and not (r.finished and r != local and r.kind != "bot"))
		if go and inp.item:
			use_item(r)
	_bumps()
	for r in riders:
		_progress(r, dt)
	_boxes_tick(dt)
	_hazards_tick(dt)
	_tethers_tick(dt)
	_pads_tick()
	_rank()
	_catchup(dt)
	if state == "done":
		var all_done := riders.all(func(r): return r.finished or r.disconnected)
		if all_done or st > 25.0:
			_results()

func _input_of(r: RaceRider, dt: float) -> RaceInput:
	if r.has_meta("auto"):
		return r.get_meta("auto")                # проверка задаёт ввод сама
	if r.kind == "local":
		if r.finished:
			if autopilot == null:
				autopilot = RaceAI.new()
				autopilot.setup(r, self, "easy", 7)
			return autopilot.think(dt)
		if r.ai != null:
			return r.ai.think(dt)                # бот за игрока (проверки)
		look_back = Input.is_action_pressed("race_look_back")
		return RaceInput.from_actions(float(RaceSave.v("steer")), Input.is_action_just_pressed("race_jump"), Input.is_action_just_pressed("race_item"))
	if r.kind == "bot" and r.ai != null:
		return r.ai.think(dt)
	if r.kind == "remote":
		var inp: RaceInput = r.net_input
		r.net_input = _sticky(inp)
		return inp
	return RaceInput.new()

## одноразовые нажатия (прыжок, предмет) из сетевого ввода срабатывают один раз
func _sticky(inp: RaceInput) -> RaceInput:
	var c := RaceInput.new()
	c.throttle = inp.throttle
	c.brake = inp.brake
	c.steer = inp.steer
	c.drift = inp.drift
	c.boost = inp.boost
	c.look_back = inp.look_back
	return c

## толкотня: близкие гонщики расталкиваются, быстрый теряет немного скорости
func _bumps() -> void:
	var R: float = float(RaceData.PHYS["bump"])
	for a in riders.size():
		for b in range(a + 1, riders.size()):
			var ra: RaceRider = riders[a]
			var rb: RaceRider = riders[b]
			if ra.disconnected or rb.disconnected:
				continue
			var d := rb.global_position - ra.global_position
			d.y *= 2.0
			var ln := d.length()
			if ln < R and ln > 0.001:
				var n := Vector3(d.x, 0, d.z).normalized()
				var over := R - ln
				ra.side_v -= n * float(RaceData.PHYS["bump_push"]) * (0.4 + over)
				rb.side_v += n * float(RaceData.PHYS["bump_push"]) * (0.4 + over)
				var key := "%d_%d" % [a, b]
				if Time.get_ticks_msec() - int(bump_cd.get(key, -9999)) > 500:
					bump_cd[key] = Time.get_ticks_msec()
					if ra.speed > rb.speed:
						ra.speed *= 0.9
					else:
						rb.speed *= 0.9
					ra.ev("bump", rb.slot)
					rb.ev("bump", ra.slot)

# ---------------- круги и контрольные точки ----------------
func _wrap(x: float) -> float:
	return fposmod(x + track.L * 0.5, track.L) - track.L * 0.5

func _progress(r: RaceRider, dt: float) -> void:
	if r.disconnected:
		return
	r.proj = track.project(r.global_position, r.proj)
	r.prev_s = r.s
	r.s = float(r.proj["s"])
	r.lat = float(r.proj["lat"])
	r.half = float(r.proj["half"])
	r.on_short = bool(r.proj["short"])
	# контрольная точка: пересёк её линию вперёд, по дороге, и именно ту, что ждали
	var g: Dictionary = track.gates[r.next_gate]
	var d0 := _wrap(r.prev_s - float(g["s"]))
	var d1 := _wrap(r.s - float(g["s"]))
	if d0 < 0.0 and d1 >= 0.0 and d1 - d0 < 30.0 and absf(r.lat) < r.half + RaceTrack.SHOULDER + 2.0 and not r.finished:
		_pass_gate(r)
	# сколько пройдено — для мест (дальше пропущенной контрольной точки путь не засчитывается)
	var rel := track.from_start(r.s)
	if not r.get_meta("armed", false):
		rel = rel - track.L if rel > track.L * 0.5 else rel        # ещё до стартовой черты
	elif r.next_gate == 0:
		if rel < track.L * 0.5:
			rel = track.L                                           # все точки пройдены, финиш вот-вот
	else:
		rel = minf(rel, track.from_start(float(track.gates[r.next_gate]["s"])) + 1.0)
	r.dist = r.lap * track.L + rel
	# против движения
	if absf(r.speed) > 3.0 and r.vdir.dot(r.proj["tan"]) * signf(r.speed) < -0.45:
		r.wrong_t += dt
	else:
		r.wrong_t = maxf(0.0, r.wrong_t - dt * 2.0)
	# упал в канаву или застрял
	if r.global_position.y < -0.6 and not r.has_meta("fell"):
		r.set_meta("fell", true)
		r.ev("fall", 0)
	if r.global_position.y < RaceTrack.KILL_Y:
		r.remove_meta("fell")
		respawn(r)
	elif go and absf(r.speed) < 1.0 and r.spin_t <= 0.0 and not r.finished:
		r.stuck_t += dt
		if r.stuck_t > float(RaceData.PHYS["stuck"]):
			respawn(r)
	else:
		r.stuck_t = 0.0

func _pass_gate(r: RaceRider) -> void:
	var k := r.next_gate
	if k == 0:
		if not r.get_meta("armed", false):
			r.set_meta("armed", true)           # старт: первое пересечение финишной черты — круг 1 начался
			r.lap_t0 = t
		else:
			r.lap += 1
			var lt := t - r.lap_t0
			r.lap_times.append(lt)
			r.lap_t0 = t
			if r.best_lap <= 0.0 or lt < r.best_lap:
				r.best_lap = lt
			r.ev("lap", r.lap)
			if r.lap >= laps:
				_finish(r)
	r.last_gate = k
	r.next_gate = (k + 1) % track.gates.size()
	r.ev("gate", k)

func _finish(r: RaceRider) -> void:
	r.finished = true
	r.finish_t = t
	order.append(r)
	r.ev("finish", order.size())
	if r == local or (local == null and order.size() == 1):
		if state == "race":
			_set_state("done")

## упавшего или застрявшего — на последнюю пройденную контрольную точку
func respawn(r: RaceRider) -> void:
	var k := r.last_gate if r.get_meta("armed", false) else 0
	var xf := track.respawn(k)
	if not r.get_meta("armed", false):
		xf = track.grid(r.slot)
	r.place(xf)
	r.proj = track.project(r.global_position, {})
	r.s = float(r.proj["s"])
	r.prev_s = r.s
	r.stuck_t = 0.0
	r.wrong_t = 0.0
	if r == local:
		cam_snap = true                          # камера сразу за спину, а не выплывает из-под земли
	r.ev("respawn", k)

# ---------------- места, догоняющий механизм ----------------
func _rank() -> void:
	var list := riders.duplicate()
	list.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished
		if a.finished and b.finished:
			return a.finish_t < b.finish_t
		return a.dist > b.dist)
	for k in list.size():
		(list[k] as RaceRider).rank = k + 1

func _catchup(dt: float) -> void:
	if String(cfg.get("mode", "single")) != "single" or local == null:
		return
	var C := RaceData.CATCHUP
	for r in riders:
		if r.kind != "bot":
			continue
		var gap: float = r.dist - local.dist
		var want := 1.0
		if gap > float(C["ahead"]):
			want = float(C["down"])
		elif gap < -float(C["behind"]):
			want = float(C["up"])
		r.pace = move_toward(r.pace, want, dt * 0.05)

# ---------------- предметы ----------------
func _boxes_tick(dt: float) -> void:
	for b in boxes:
		var n: Node3D = b["node"]
		if float(b["t"]) > 0.0:
			b["t"] = float(b["t"]) - dt
			if float(b["t"]) <= 0.0:
				n.visible = true
				n.scale = Vector3.ONE * 0.2
				n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			continue
		n.rotation.y += dt * 1.6
		n.position.y = (b["pos"] as Vector3).y + sin(t * 3.0 + n.position.x) * 0.12
		for r in riders:
			if r.disconnected:
				continue
			if r.global_position.distance_to(b["pos"] as Vector3) < 1.7:
				b["t"] = RaceData.BOX_RESPAWN
				n.visible = false
				if r.item == "" and not r.finished:
					r.item = roll_item(r)
					r.ev("item_get", r.item)
				else:
					r.ev("box_break", 0)
				break

## предмет из коробки: решает только власть (хост), по месту гонщика
func roll_item(r: RaceRider) -> String:
	var n := riders.size()
	var bucket := 1
	if r.rank <= 2 or n <= 2:
		bucket = 0
	elif r.rank >= n - 1:
		bucket = 2
	if n == 1:
		bucket = 1
	var odds: Dictionary = RaceData.ITEM_ODDS[bucket]
	var sum := 0
	for k in odds:
		sum += int(odds[k])
	var x := rng.randi_range(1, sum)
	for k in RaceData.ITEM_IDS:
		x -= int(odds[k])
		if x <= 0:
			return k
	return "turbo_balloon"

## ближайший соперник впереди в конусе
func find_target(r: RaceRider, rng_m: float, cone: float) -> RaceRider:
	var best: RaceRider = null
	var bd := rng_m
	for o in riders:
		if o == r or o.finished or o.disconnected:
			continue
		var d: Vector3 = o.global_position - r.global_position
		var ln := d.length()
		if ln < bd and ln > 0.5 and r.fwd().dot(d / ln) > cone:
			bd = ln
			best = o
	return best

func rider_behind(r: RaceRider, rng_m: float) -> RaceRider:
	for o in riders:
		if o == r or o.finished or o.disconnected:
			continue
		var d: Vector3 = o.global_position - r.global_position
		if d.length() < rng_m and r.fwd().dot(d.normalized()) < -0.4:
			return o
	return null

func use_item(r: RaceRider) -> void:
	if r.item == "" or r.item_cd > 0.0 or not go or r.finished or r.spin_t > 0.0:
		return
	var id := r.item
	var I: Dictionary = RaceData.ITEMS[id]
	r.item = ""
	r.item_cd = RaceData.ITEM_CD
	r.ev("item_use", id)
	match id:
		"turbo_balloon":
			r.item_boost_t = float(I["t"])
		"filter":
			r.shield_t = float(I["t"])
		"dust_bomb", "soap":
			var p: Vector3 = r.global_position - r.fwd() * float(I["back"])
			p.y = r.global_position.y
			_hazard(id, p, float(I["r"]), float(I["life"]), r)
		"super_suck":
			var tg := find_target(r, float(I["range"]), float(I["cone"]))
			if tg != null:
				tethers.append({"from": r, "to": tg, "t": float(I["t"])})
				if tg.hit_by(id):
					tg.add_slow("suck", float(I["slow"]), float(I["t"]))
					tg.ev("hit", id)
			else:
				r.ev("miss", id)
		"air_blast":
			var tg2 := find_target(r, float(I["range"]), float(I["cone"]))
			if tg2 != null and tg2.hit_by(id):
				var side: Vector3 = (tg2.global_position - r.global_position)
				var right := r.fwd().cross(Vector3.UP)
				var sgn := signf(side.dot(right)) if absf(side.dot(right)) > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0)
				tg2.side_v += right * sgn * float(I["push"])
				tg2.add_slow("blast", float(I["slow"]), float(I["t"]))
				tg2.ev("hit", id)
			elif tg2 == null:
				r.ev("miss", id)

func _hazard(kind: String, p: Vector3, rad: float, life: float, owner: RaceRider) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	if kind == "soap":
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = 0.04
		mi.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.75)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic = 0.3
		mat.roughness = 0.05
		mi.material_override = mat
		mi.position.y = 0.03
		n.add_child(mi)
	hazards.append({"kind": kind, "pos": p, "r": rad, "life": life, "owner": owner, "hits": 0, "hit": {}, "node": n, "age": 0.0})

func _hazards_tick(dt: float) -> void:
	for h in hazards.duplicate():
		h["life"] = float(h["life"]) - dt
		h["age"] = float(h["age"]) + dt
		var n: Node3D = h["node"]
		if h["kind"] == "dust" or h["kind"] == "dust_bomb":
			if fmod(float(h["age"]), 0.25) < dt:
				fx.dust(h["pos"] as Vector3 + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5)), 4, Color(0.62, 0.57, 0.5, 0.8), 1.4, 0.3)
		for r in riders:
			if r.disconnected or (h["hit"] as Dictionary).has(r.slot):
				continue
			if r == h["owner"] and float(h["age"]) < 1.2:
				continue
			var d: Vector3 = r.global_position - (h["pos"] as Vector3)
			d.y = 0.0
			if d.length() < float(h["r"]) + 0.4:
				(h["hit"] as Dictionary)[r.slot] = true
				var id: String = h["kind"]
				if id == "soap":
					if r.spin_out(float(RaceData.ITEMS["soap"]["spin"]), id):
						h["hits"] = int(h["hits"]) + 1
				elif r.hit_by(id):
					r.add_slow("dust", float(RaceData.ITEMS["dust_bomb"]["slow"]), float(RaceData.ITEMS["dust_bomb"]["t"]))
					r.ev("hit", id)
		if float(h["life"]) <= 0.0 or int(h["hits"]) >= int(RaceData.ITEMS["soap"]["hits"]):
			hazards.erase(h)
			if is_instance_valid(n):
				n.queue_free()

func _tethers_tick(dt: float) -> void:
	for r in riders:
		r.pull_v = Vector3.ZERO
	for th in tethers.duplicate():
		th["t"] = float(th["t"]) - dt
		var a: RaceRider = th["from"]
		var b: RaceRider = th["to"]
		if float(th["t"]) <= 0.0 or not is_instance_valid(a) or not is_instance_valid(b):
			tethers.erase(th)
			continue
		var d := b.global_position - a.global_position
		d.y = 0.0
		a.pull_v = d.normalized() * float(RaceData.ITEMS["super_suck"]["pull"])

func _pads_tick() -> void:
	for p in track.pads:
		for r in riders:
			if r.global_position.distance_to(p["pos"] as Vector3) < 2.4 and r.boost_t < 0.5:
				r.boost_t = 0.8
				r.ev("pad", 0)

# ---------------- результаты ----------------
func _results() -> void:
	if state == "results":
		return
	results = []
	var fin := order.duplicate()
	var rest := riders.filter(func(r): return not r.finished)
	rest.sort_custom(func(a, b): return a.dist > b.dist)
	for r in fin:
		results.append({"rider": r, "title": r.title, "time": r.finish_t, "best": r.best_lap, "est": false, "dc": r.disconnected})
	for r in rest:
		# не доехал: время по средней скорости до конца — помечено «~»
		var left: float = laps * track.L - r.dist
		var avg: float = maxf(4.0, r.dist / maxf(1.0, t))
		results.append({"rider": r, "title": r.title, "time": t + left / avg, "best": r.best_lap, "est": true, "dc": r.disconnected})
	new_record = ""
	if local != null and local.finished and (main == null or main.racecheck == ""):
		var mode := String(cfg.get("mode", "single"))
		var tid := String(cfg.get("track", "tomsk_dust"))
		if mode != "online":
			if RaceSave.record(tid, mode, local.finish_t):
				new_record = "time"
			if local.best_lap > 0.0 and RaceSave.record(tid, "lap", local.best_lap):
				new_record = "lap" if new_record == "" else new_record + "+lap"
	_set_state("results")
	hud.show_results()

func standings() -> Array:
	var list := riders.duplicate()
	list.sort_custom(func(a, b): return a.rank < b.rank)
	return list

# ---------------- события участников: эффекты, звук, HUD ----------------
func on_rider_event(r: RaceRider, k: String, v) -> void:
	var p: Vector3 = r.global_position
	var me: bool = r == local
	match k:
		"drift_lvl":
			fx.sparks(p - r.fwd() * 0.5 + Vector3(0, 0.15, 0), Vector3.UP, 6 + 4 * int(v), _drift_col(int(v)), 0.6, 60.0)
			if me:
				_sfx("sfx_charge", -10.0, 0.9 + 0.2 * int(v))
		"drift_boost":
			fx.dust(p - r.fwd() * 0.6 + Vector3(0, 0.1, 0), 6 + 3 * int(v), fx.DUST, 0.9)
			fx.flash(p - r.fwd() * 0.8 + Vector3(0, 0.4, 0), 0.6 + 0.2 * int(v), _drift_col(int(v)), "star_08", 0.12)
			if me:
				_sfx("sfx_swing_heavy", -6.0, 1.3)
				shake(0.12)
		"jump":
			if me:
				_sfx("sfx_roll", -8.0, 1.4)
		"ramp":
			if me:
				_sfx("sfx_swing", -5.0, 0.8)
		"land":
			fx.dust(p + Vector3(0, 0.1, 0), 8, fx.DUST, 1.0)
			if me:
				_sfx("sfx_thud", -6.0, 1.1)
				shake(clampf(float(v) * 0.5, 0.15, 0.45))
		"wall":
			fx.sparks(p + r.fwd() * 0.7 + Vector3(0, 0.5, 0), -r.fwd(), 10, Color(1.0, 0.8, 0.45), 0.8, 50.0)
			if me or r.global_position.distance_to(cam.global_position) < 12.0:
				_sfx("sfx_clang", -6.0 if me else -14.0, 0.9)
			if me:
				shake(clampf(float(v), 0.2, 0.6))
		"bump":
			if me:
				_sfx("sfx_thud", -8.0, 1.3)
				shake(0.2)
		"item_get":
			fx.ring(p + Vector3(0, 1.0, 0), 1.2, (RaceData.ITEMS[String(v)]["col"] as Color), 0.25)
			if me:
				_sfx("sfx_spawn", -6.0, 1.4)
				hud.item_got(String(v))
		"box_break":
			fx.ring(p + Vector3(0, 1.0, 0), 0.8, Color(1, 1, 1), 0.2)
		"item_use":
			_item_fx(r, String(v))
			hud.feed("%s: %s" % [r.title, String(RaceData.ITEMS[String(v)]["name"])], r == local)
		"hit":
			fx.hit(p + Vector3(0, 0.8, 0), -r.fwd(), 1, (RaceData.ITEMS[String(v)]["col"] as Color))
			if me:
				shake(0.35)
				_sfx("sfx_hit", -4.0, 1.0)
				if String(v) == "dust_bomb":
					dust_vis = 1.0
			hud.feed("%s попал под %s" % [r.title, String(RaceData.ITEMS[String(v)]["name"])], me)
		"spin":
			fx.poof(p + Vector3(0, 0.3, 0), 1.6, Color(0.85, 0.95, 1.0))
			if me:
				_sfx("sfx_scrape", -4.0, 1.2)
				shake(0.3)
			hud.feed("%s поскользнулся на мыле" % r.title, me)
		"blocked":
			fx.shield(p + Vector3(0, 0.9, 0), r.fwd(), Color(0.6, 1.0, 0.7), 1.5)
			hud.feed("%s: ФИЛЬТР спас" % r.title, me)
			if me:
				_sfx("sfx_parry", -6.0, 1.0)
		"fall":
			fx.dust(p + Vector3(0, 0.2, 0), 14, Color(0.6, 0.75, 0.85, 0.8), 1.4, 0.2)      # всплеск
			if me:
				_sfx("sfx_wave", -4.0, 0.7)
		"respawn":
			fx.poof(p + Vector3(0, 0.5, 0), 1.2, Color(1, 1, 1))
			if me:
				hud.flash_text("ВОЗВРАТ НА ТРАССУ")
		"lap":
			if me:
				var final := int(v) == laps - 1
				hud.flash_text("ПОСЛЕДНИЙ КРУГ!" if final else "КРУГ %d / %d" % [int(v) + 1, laps])
				_sfx("sfx_wave", -6.0, 1.2)
		"finish":
			fx.flash(p + Vector3(0, 1.2, 0), 2.0, Color(1, 1, 1), "star_08", 0.3)
			if me:
				hud.flash_text("ФИНИШ! %d МЕСТО" % r.rank if String(cfg.get("mode", "single")) != "time" else "ФИНИШ!")
				_sfx("sfx_boom", -4.0, 1.1)
		"pad":
			if me:
				_sfx("sfx_charge", -8.0, 1.6)
		"miss":
			if me:
				hud.feed("%s — мимо, впереди никого" % String(RaceData.ITEMS[String(v)]["name"]), true)

func _drift_col(lv: int) -> Color:
	return [Color(1, 1, 1), Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.2), Color(0.95, 0.15, 0.3)][clampi(lv, 0, 3)]

func _item_fx(r: RaceRider, id: String) -> void:
	var p: Vector3 = r.global_position + Vector3(0, 0.7, 0)
	var col: Color = RaceData.ITEMS[id]["col"]
	match id:
		"turbo_balloon":
			fx.flash(p - r.fwd() * 0.9, 1.4, col, "star_08", 0.2)
			fx.streaks(p, -r.fwd(), 10, col)
			_sfx("sfx_rage", -6.0, 1.5, r)
		"dust_bomb":
			fx.dust(p - r.fwd() * 2.5, 22, Color(0.62, 0.57, 0.5, 0.9), 1.8, 0.4)
			_sfx("sfx_boom", -8.0, 1.4, r)
		"super_suck":
			fx.twirl(p + r.fwd() * 1.2, 1.4, col, 0.5)
			_sfx("sfx_charge", -6.0, 0.7, r)
		"soap":
			fx.poof(p - r.fwd() * 2.0, 1.2, col)
			_sfx("sfx_glass", -10.0, 1.6, r)
		"filter":
			fx.shield(p, r.fwd(), col, 1.6)
			_sfx("sfx_block", -6.0, 1.2, r)
		"air_blast":
			fx.streaks(p + r.fwd() * 1.0, r.fwd(), 14, col)
			fx.ring(p + r.fwd() * 1.5, 1.6, col, 0.25)
			_sfx("sfx_wave", -6.0, 1.4, r)

func _sfx(name: String, vol := 0.0, pitch := 1.0, who: RaceRider = null) -> void:
	if not sound_on or main == null:
		return
	if who != null and who != local and local != null:
		var d: float = who.global_position.distance_to(local.global_position)
		if d > 40.0:
			return
		vol -= d * 0.4
	main.sfx(name, vol, pitch)

func _beep(pitch: float) -> void:
	_sfx("sfx_ui", -2.0, pitch)

func shake(a: float) -> void:
	trauma = minf(1.0, trauma + a * float(Opts.v("shake")))

# ---------------- камера ----------------
func _process(dt: float) -> void:
	if cam == null:
		return
	if go and Engine.time_scale == 1.0 and not paused:
		stats["frames"] += 1                      # кадры экрана (для проверки: доля медленных, дольше 1/30 с)
		if dt > 1.0 / 30.0:
			stats["slow"] += 1
	var who: RaceRider = local if local != null else (riders[0] if not riders.is_empty() else null)
	if who == null:
		return
	var vt: Transform3D = who.smooth.global_transform
	var pos := vt.origin
	var h: float = vt.basis.get_euler().y
	var f := Vector3(sin(h), 0, cos(h))
	if state == "intro":
		# облёт: камера идёт сбоку-спереди за спину гонщика
		var k := clampf(st / 2.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var side := f.cross(Vector3.UP)
		var from := pos + f * 7.0 + side * 4.0 + Vector3(0, 1.6, 0)
		var to := pos - f * 5.6 + Vector3(0, 2.3, 0)
		cam.global_position = from.lerp(to, e)
		cam.look_at(pos + Vector3(0, 0.9, 0) + f * (2.5 * e), Vector3.UP)
		cam.fov = 60.0 + 10.0 * e
		return
	var spd: float = absf(who.speed)
	var air: bool = who.air_t > 0.1
	var dist_c := 5.4 + spd * 0.075 + (0.9 if air else 0.0)
	var height := 2.3 + (0.5 if air else 0.0)
	var dir := -f
	if look_back and who == local and state in ["race", "done"]:
		dir = f
	var want := pos + dir * dist_c + Vector3(0, height, 0)
	# не сквозь стены: луч от гонщика к камере
	var space := get_world_3d().direct_space_state
	var head := pos + Vector3(0, 1.3, 0)
	var q := PhysicsRayQueryParameters3D.create(head, want, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = (hit["position"] as Vector3) + (head - want).normalized() * 0.4
	cam.global_position = want if cam_snap else cam.global_position.lerp(want, 1.0 - exp(-7.0 * dt))
	cam_snap = false
	var look := pos + Vector3(0, 1.0, 0) + (f * 3.0 if dir == -f else -f * 3.0)
	cam.look_at(look, Vector3.UP)
	# наклон в заносе, тряска, угол обзора от скорости
	var roll := (-who.drift_dir * 0.07 if who.drifting else 0.0)
	trauma = maxf(0.0, trauma - dt * 1.6)
	var sh := trauma * trauma
	cam.rotate_object_local(Vector3.FORWARD, roll + sin(Time.get_ticks_msec() * 0.031) * 0.03 * sh)
	cam.position += Vector3(sin(Time.get_ticks_msec() * 0.047), sin(Time.get_ticks_msec() * 0.059), 0) * 0.25 * sh
	cam_fov = lerpf(cam_fov, 68.0 + spd * 0.45 + (6.0 if who.boosting() else 0.0), 1.0 - exp(-4.0 * dt))
	cam.fov = cam_fov
	dust_vis = maxf(0.0, dust_vis - dt * 0.5)

# ---------------- пауза и выход ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and state != "results":
		set_paused(not paused)
		get_viewport().set_input_as_handled()

func set_paused(on: bool) -> void:
	if net != null:
		on = false                               # сетевая гонка не останавливается
	paused = on
	hud.show_pause(on)
	for r in riders:
		if r.engine != null:
			r.engine.stream_paused = on

func restart() -> void:
	if main != null:
		main.start_race(cfg)

func quit(to_race_menu: bool) -> void:
	if main != null:
		main.end_race(to_race_menu)
