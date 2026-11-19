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
var online := false              # сетевая гонка (race_net.gd)
var hazard_id := 0
var snap_host_t := -1.0          # клиент: время хоста в последнем снимке
var snap_local_t := 0.0          # и когда он пришёл (наши часы)
var net_menu := false            # сетевая гонка: открыт экран выхода (гонка не стоит)
var net_fix := {"hard": 0, "soft": 0.0}   # клиент: сколько раз хост поправил своего гонщика (для проверки)
var local_hist: Array = []       # клиент: где был свой гонщик [наше время, положение] — для сверки со снимками хоста
const PHYSICAL := ["drift_start", "drift_lvl", "drift_boost", "drift_cut", "jump", "ramp", "land", "wall", "trick", "trick_land", "trick_fail", "combo", "draft"]
var missiles: Array = []         # [{s, lat, y, owner, target, life, node}] — ЖЕЛЕЗЯКИ в полёте
var weather: RaceWeather       # погода и случайные ситуации (race_weather.gd)
var cam_snap := false

func setup(m, c: Dictionary) -> void:
	main = m
	cfg = c
	laps = int(cfg.get("laps", 3))
	rng.seed = int(cfg.get("seed", Time.get_ticks_usec()))
	online = String(cfg.get("mode", "single")) == "online"
	authority = not online or bool(cfg.get("host", true))
	sound_on = main == null or main.testing() == "" or main.audiolog
	track = RaceTrack.new()
	add_child(track)
	track.build(String(cfg.get("track", "tomsk_dust")))
	obstacles = track.obstacle_pts
	fx = preload("res://scripts/fx.gd").new()
	add_child(fx)
	_spawn_riders()
	_spawn_boxes()
	weather = RaceWeather.new()
	add_child(weather)
	# в заезде на время случайных ситуаций нет никогда — рекорд должен быть честным, что бы ни пришло в cfg
	weather.setup(self, String(cfg.get("weather", "clear")), bool(cfg.get("happenings", true)) and String(cfg.get("mode", "single")) != "time", rng.randi())
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	hud = RaceHud.new()
	hud.race = self
	add_child(hud)
	if online and main != null and main.race_net != null:
		net = main.race_net
		_set_state("wait")                       # сетевая гонка: ждём, пока трасса загрузится у всех
		hud.flash_text("ЖДЁМ ОСТАЛЬНЫХ…")
		net.race_ready(self)
	else:
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
		if online and not authority and r.kind == "remote":
			r.puppet = true                      # клиент: чужие гонщики — по снимкам хоста
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
	if not authority:
		_client_tick(dt)
		return
	match state:
		"wait":
			pass
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
	for r in riders:
		if r.disconnected:
			continue                             # вышедший по сети стоит, где был (невидим и без столкновений)
		var inp: RaceInput = _input_of(r, dt)
		r.simulate(inp, dt, go and not (r.finished and r != local and r.kind != "bot"))
		if go and inp.item:
			use_item(r)
	_bumps()
	_drafts(dt)
	for r in riders:
		_progress(r, dt)
	_boxes_tick(dt)
	_hazards_tick(dt)
	_missiles_tick(dt)
	_tethers_tick(dt)
	_pads_tick()
	weather.tick(dt)
	_rank()
	_catchup(dt)
	if state == "done":
		var all_done := riders.all(func(r): return r.finished or r.disconnected)
		if all_done or st > 25.0:
			_results()
	if net != null:
		net.host_tick(dt)

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

## воздушный мешок: держишься точно за соперником — через draft_time секунд тянет вперёд и копит турбо
func _drafts(dt: float) -> void:
	var P := RaceData.PHYS
	var rng_m: float = float(P["draft_range"])
	for r in riders:
		if r.disconnected or r.finished or not go:
			r.draft = 0.0
			r.draft_t = 0.0
			continue
		var found := false
		if r.speed > 12.0 and r.air_t < 0.1:
			var f: Vector3 = r.fwd()
			for o in riders:
				if o == r or o.disconnected or o.speed < 8.0:
					continue
				var d: Vector3 = o.global_position - r.global_position
				d.y = 0.0
				var ln := d.length()
				if ln > 2.5 and ln < rng_m and f.dot(d / ln) > float(P["draft_cone"]) and f.dot(o.fwd()) > 0.7:
					found = true
					break
		if found:
			r.draft_t += dt
			if r.draft_t >= float(P["draft_time"]):
				if r.draft <= 0.0:
					r.ev("draft", 1)
				r.draft = move_toward(r.draft, 1.0, dt * 2.5)
		else:
			r.draft_t = maxf(0.0, r.draft_t - dt * 2.0)
			r.draft = move_toward(r.draft, 0.0, dt * 1.6)

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
		if a.disconnected != b.disconnected:
			return b.disconnected
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
		# характер «прибавляет к финишу»: на последнем круге этот соперник едет чуть быстрее (честно — тем же газом)
		if r.ai != null and r.lap >= laps - 1:
			want += float((r.ai.style as Dictionary).get("late_push", 0.0))
		r.pace = move_toward(r.pace, want, dt * 0.05)

# ---------------- предметы ----------------
func _boxes_tick(dt: float) -> void:
	for b in boxes:
		var n: Node3D = b["node"]
		if float(b["t"]) > 0.0:
			b["t"] = float(b["t"]) - dt
			if float(b["t"]) <= 0.0:
				n.visible = true
				if net != null:
					net.send_box(boxes.find(b), true)
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
				if net != null:
					net.send_box(boxes.find(b), false)
				if r.item == "" and not r.finished:
					r.item = weather.box_item(roll_item(r))
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
		"overclock":
			r.overclock_t = float(I["t"])
		"missile":
			_missile(r)
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

## ЖЕЛЕЗЯКА: летит по трассе вперёд от хозяина; видит соперника впереди — наводится на его полосу
func _missile(owner: RaceRider) -> void:
	var I: Dictionary = RaceData.ITEMS["missile"]
	var n := RaceItems.model("missile", 1.3)
	add_child(n)
	n.global_position = owner.global_position + Vector3(0, 0.9, 0) + owner.fwd() * 1.4
	var m := {"s": owner.s + 1.5, "lat": owner.lat, "y": owner.global_position.y + 0.9, "owner": owner, "life": float(I["life"]), "node": n, "target": null, "gone": 0.0}
	m["target"] = _missile_target(m)
	missiles.append(m)

func _missile_target(m: Dictionary) -> RaceRider:
	var best: RaceRider = null
	var bd: float = float(RaceData.ITEMS["missile"]["seek"])
	for o in riders:
		if o == m["owner"] or o.finished or o.disconnected:
			continue
		var ahead := fposmod(o.s - float(m["s"]), track.L)
		if ahead < bd:
			bd = ahead
			best = o
	return best

func _missiles_tick(dt: float) -> void:
	var I: Dictionary = RaceData.ITEMS["missile"]
	for m in missiles.duplicate():
		m["life"] = float(m["life"]) - dt
		m["gone"] = float(m["gone"]) + dt
		var tg: RaceRider = m["target"]
		if tg == null or not is_instance_valid(tg) or tg.finished:
			m["target"] = _missile_target(m)
			tg = m["target"]
		m["s"] = float(m["s"]) + float(I["speed"]) * dt
		if tg != null:
			m["lat"] = move_toward(float(m["lat"]), tg.lat, dt * 14.0)
		var i := track.at_s(float(m["s"]))
		var right: Vector3 = track.T[i].cross(Vector3.UP)
		var p: Vector3 = track.P[i] + right * float(m["lat"])
		p.y = float(m["y"])
		var n: Node3D = m["node"]
		if is_instance_valid(n):
			n.global_position = p
			n.rotation = Vector3(0, atan2(track.T[i].x, track.T[i].z), float(m["gone"]) * 9.0)
			if fmod(float(m["gone"]), 0.06) < dt:
				fx.dust(p - track.T[i] * 0.6, 2, Color(0.35, 0.33, 0.32, 0.8), 0.7, 0.2)
		var hit: RaceRider = null
		for o in riders:
			if o == m["owner"] or o.disconnected or o.finished:
				continue
			var d: Vector3 = o.global_position - p
			d.y *= 0.5
			if d.length() < float(I["r"]):
				hit = o
				break
		if hit != null:
			if hit.spin_out(float(I["spin"]), "missile"):
				hit.speed *= 0.55
				hit.ev("hit", "missile")
			fx.sparks(p, Vector3.UP, 16, Color(1.0, 0.6, 0.25), 1.0, 70.0)
			fx.flash(p, 1.6, Color(1.0, 0.7, 0.3), "star_08", 0.15)
			_sfx("sfx_boom", -4.0, 1.2, hit)
		if hit != null or float(m["life"]) <= 0.0:
			missiles.erase(m)
			if is_instance_valid(n):
				if hit == null:
					fx.poof(p, 0.8, Color(0.5, 0.45, 0.4))
				n.queue_free()

func _hazard(kind: String, p: Vector3, rad: float, life: float, owner: RaceRider) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	if kind == "soap":
		var pd := RaceItems.puddle(rad)
		n.add_child(pd)
		pd.scale = Vector3(0.1, 1.0, 0.1)
		pd.create_tween().tween_property(pd, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif kind == "dust_bomb":
		# мешок падает на дорогу и лопается: дальше — облако (частицы в _hazards_tick)
		var bag := RaceItems.model("dust_bomb", 1.5)
		bag.position = Vector3(0, 0.9, 0)
		n.add_child(bag)
		var tw := bag.create_tween()
		tw.tween_property(bag, "position:y", 0.45, 0.16).set_ease(Tween.EASE_IN)
		tw.tween_property(bag, "scale", Vector3(2.4, 0.5, 2.4), 0.07)
		tw.tween_callback(bag.queue_free)
	hazard_id += 1
	hazards.append({"kind": kind, "pos": p, "r": rad, "life": life, "owner": owner, "hits": 0, "hit": {}, "node": n, "age": 0.0, "id": hazard_id})
	if net != null and authority:
		net.send_hazard(hazard_id, kind, p, rad)

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
			if net != null and authority:
				net.send_hazard_end(int(h["id"]))

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
	if net != null and authority:
		var rows: Array = []
		for row in results:
			rows.append([(row["rider"] as RaceRider).slot, float(row["time"]), float(row["best"]), bool(row["est"]), bool(row["dc"])])
		net.send_results(rows)

func standings() -> Array:
	var list := riders.duplicate()
	list.sort_custom(func(a, b): return a.rank < b.rank)
	return list

# ---------------- события участников: эффекты, звук, HUD ----------------
func on_rider_event(r: RaceRider, k: String, v) -> void:
	if net != null and authority:
		net.send_event(r.slot, k, v)
	elif net != null and not authority and not (k in PHYSICAL):
		return                                   # клиент: решающие события приходят только от хоста (remote_event)
	_show_event(r, k, v)

func _show_event(r: RaceRider, k: String, v) -> void:
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
				hud.flash_text("FINAL LAP" if final else "LAP %d / %d" % [int(v) + 1, laps])
				_sfx("sfx_wave", -6.0, 1.2)
				if final and laps > 1:
					hud.final_lap()
					_sfx("sfx_rage", -8.0, 1.6)
					if main != null and main.audio != null and main.audio.has_method("race_final"):
						main.audio.race_final()
		"trick":
			fx.ring(p + Vector3(0, 0.6, 0), 1.0, Color(1.0, 0.9, 0.4), 0.2)
			if me:
				_sfx("sfx_roll", -6.0, 1.2 + 0.15 * int(v))
		"trick_land":
			fx.flash(p + Vector3(0, 0.5, 0), 1.0 + 0.3 * int(v), Color(1.0, 0.85, 0.3), "star_08", 0.18)
			fx.streaks(p + Vector3(0, 0.6, 0), -r.fwd(), 8 + 4 * int(v), Color(1.0, 0.9, 0.5))
			if me:
				hud.trick_text(["ТРЮК!", "ДВОЙНОЙ ТРЮК!", "ТРОЙНОЙ ТРЮК!"][clampi(int(v) - 1, 0, 2)])
				_sfx("sfx_charge", -5.0, 1.5)
				shake(0.15)
		"trick_fail":
			fx.dust(p + Vector3(0, 0.1, 0), 12, fx.DUST, 1.2)
			if me:
				hud.trick_text("НЕ ДОКРУТИЛ", true)
				_sfx("sfx_scrape", -5.0, 0.9)
				shake(0.35)
		"combo":
			if me:
				hud.combo(int(v))
		"draft":
			if me:
				hud.trick_text("ВОЗДУШНЫЙ МЕШОК")
				_sfx("sfx_wave", -10.0, 1.7)
		"finish":
			fx.flash(p + Vector3(0, 1.2, 0), 2.0, Color(1, 1, 1), "star_08", 0.3)
			if me:
				hud.flash_text("ФИНИШ! %d МЕСТО" % r.rank if String(cfg.get("mode", "single")) != "time" else "ФИНИШ!")
				_sfx("sfx_boom", -4.0, 1.1)
		"pad":
			if me:
				_sfx("sfx_charge", -8.0, 1.6)
		"steam":
			fx.dust(p + Vector3(0, 0.3, 0), 12, Color(0.92, 0.95, 1.0, 0.85), 1.6, 0.1)
			if me:
				_sfx("sfx_boom", -8.0, 1.6)
				shake(0.25)
				hud.flash_text("ПАРОМ ВВЕРХ!")
		"hit_van":
			fx.sparks(p + Vector3(0, 0.8, 0), Vector3.UP, 12, Color(1.0, 0.8, 0.45), 0.9, 60.0)
			if me:
				_sfx("sfx_clang", -2.0, 0.7)
				shake(0.5)
			hud.feed("%s поцеловался с буханкой" % r.title, me)
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
		"overclock":
			fx.ring(p, 1.5, col, 0.3)
			fx.sparks(p, Vector3.UP, 14, col, 0.8, 60.0)
			_sfx("sfx_charge", -4.0, 1.9, r)
		"missile":
			fx.flash(p + r.fwd() * 1.2, 1.2, col, "star_08", 0.15)
			fx.dust(p - r.fwd() * 0.4, 8, Color(0.4, 0.38, 0.36, 0.8), 1.0, 0.3)
			_sfx("sfx_swing_heavy", -4.0, 1.5, r)
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
	if online and not authority:
		_puppets()
		for h in hazards:
			if (h["kind"] == "dust_bomb") and randf() < dt * 4.0:
				fx.dust(h["pos"] as Vector3 + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5)), 4, Color(0.62, 0.57, 0.5, 0.8), 1.4, 0.3)
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
		net_menu = on                            # сетевая гонка не останавливается: только экран выхода
		hud.show_pause(on)
		return
	paused = on
	hud.show_pause(on)
	for r in riders:
		if r.engine != null:
			r.engine.stream_paused = on

func restart() -> void:
	if main != null:
		main.start_race(cfg)

func quit(to_race_menu: bool) -> void:
	if net != null:
		net.race = null
		net.leave_peer()                         # выход из сетевой гонки — выход из лобби, игра снова офлайн
		if main != null:
			main.end_race_online("")
		return
	if main != null:
		main.end_race(to_race_menu)

# ---------------- сетевая гонка ----------------
func rider_of_peer(id: int) -> RaceRider:
	for r in riders:
		if r.peer == id and r.kind != "bot":
			return r
	return null

## хост: все загрузили трассу — облёт и отсчёт
func net_go() -> void:
	if state == "wait":
		_set_state("intro")

## хост: игрок отключился посреди гонки — его пылесос убирается, остальные едут
func peer_left(id: int) -> void:
	var r := rider_of_peer(id)
	if r == null or r.disconnected:
		return
	r.disconnected = true
	r.visible = false
	r.collision_layer = 0
	r.collision_mask = 0
	r.net_input = RaceInput.new()
	r.ev("disconnect", 0)
	hud.feed("%s отключился" % r.title, false)

## клиент: снимок хоста
func apply_snapshot(b: PackedByteArray) -> void:
	if b.size() < 14:
		return
	var n := b.decode_u8(13)
	if b.size() != 14 + n * 29 or n != riders.size():
		return
	var ht := b.decode_float(4)
	var s_code := b.decode_u8(8)
	var nst: String = RaceNet.STATES[clampi(s_code, 0, RaceNet.STATES.size() - 1)]
	if nst != state:
		var was := state
		_set_state(nst)
		if nst == "countdown":
			hud.countdown(3)
			_beep(0.9)
		elif nst == "race" and was != "race":
			go = true
			hud.countdown(0)
			_beep(1.5)
			if main != null:
				main.sfx("sfx_rage", -6.0, 1.3)
	st = b.decode_float(9)
	t = ht
	go = state in ["race", "done"]
	snap_host_t = ht
	snap_local_t = Time.get_ticks_msec() / 1000.0
	var o := 14
	for k in n:
		var r: RaceRider = riders[k]
		var pos := Vector3(b.decode_float(o), b.decode_float(o + 4), b.decode_float(o + 8))
		var h := b.decode_half(o + 12)
		var spd := b.decode_half(o + 14)
		var f := b.decode_u8(o + 16)
		var dl := b.decode_u8(o + 17)
		r.turbo = float(b.decode_u8(o + 18)) / 2.55
		var it := b.decode_u8(o + 19)
		r.item = RaceData.ITEM_IDS[it - 1] if it >= 1 and it <= RaceData.ITEM_IDS.size() else ""
		r.lap = b.decode_u8(o + 20)
		r.next_gate = b.decode_u8(o + 21)
		r.rank = b.decode_u8(o + 22)
		var vh := b.decode_half(o + 23)
		var air := b.decode_half(o + 25)
		r.finished = (f & 64) != 0
		r.shield_t = 1.0 if (f & 16) != 0 else 0.0
		if (f & 128) != 0 and not r.disconnected:
			r.disconnected = true
			r.visible = false
		if r == local:
			# предсказание своего гонщика. Снимок хоста — это где мы были, когда хост учёл наш ввод № seq: сверяем
			# его с нашей же позицией при том вводе (история), а не с текущей — иначе тянуло бы назад на скорость × пинг.
			var hp := _hist_seq(b.decode_u16(o + 27))
			var past: Vector3 = hp[0]
			var err := pos - past
			if OS.get_cmdline_user_args().has("--net-debug") and Engine.get_physics_frames() % 6 == 0:
				print("NETDBG seq=%d host=%s past=%s now=%s err=%.2f host_v=%.1f my_v=%.1f hist=%d" % [b.decode_u16(o + 27), str(pos.snapped(Vector3.ONE * 0.1)), str(past.snapped(Vector3.ONE * 0.1)), str(r.global_position.snapped(Vector3.ONE * 0.1)), err.length(), spd, r.speed, local_hist.size()])
			# Ввод № seq хост мог применить на шаг-другой меньше или больше, чем мы (30 Гц ввода на 60 Гц физики,
			# потерянный пакет) — это доли метра, и тянуть за них назад каждый снимок нельзя: копится отставание.
			# Поправляем только настоящее расхождение (столкновение, предмет, другой путь) — сразу всё, видимый
			# гонщик доезжает плавно (vis_off).
			var tol := 0.6 + absf(r.speed) * 0.05
			if err.length() > 12.0:
				net_fix["hard"] = int(net_fix["hard"]) + 1
				r.global_position = pos
				r.heading = h
				local_hist.clear()
			elif err.length() > tol:
				net_fix["soft"] = float(net_fix["soft"]) + err.length()
				r.global_position += err
				for hh in local_hist:
					hh[1] = (hh[1] as Vector3) + err
				r.vis_off = (r.vis_off - err).limit_length(3.0)
			var dv := spd - float(hp[1])
			if absf(dv) > 2.0:
				r.speed += dv * 0.5
			if (f & 8) != 0 and r.spin_t <= 0.0:
				r.spin_t = 0.6
		else:
			r.speed = spd
			r.drifting = (f & 1) != 0
			r.drift_lvl = dl & 3
			r.drift_dir = 1.0 if (dl & 4) != 0 else -1.0
			r.turbo_on = (f & 32) != 0
			r.boost_t = 0.5 if (f & 2) != 0 and not r.turbo_on else 0.0
			r.spin_t = 0.5 if (f & 8) != 0 else 0.0
			r.air_t = air
			r.vdir = Vector3(sin(vh), 0, cos(vh))
			r.snaps.append([ht, pos, h])
			if r.snaps.size() > 30:
				r.snaps.pop_front()
		o += 29

## клиент, шаг физики: свой гонщик — по своему вводу (сразу отзывается), ввод — хосту
func _client_tick(dt: float) -> void:
	if state in ["race", "done"]:
		t += dt
	if state == "countdown":
		var left := 3 - int(st)
		if left != hud.count_shown and left >= 1:
			hud.countdown(left)
			_beep(0.9)
	if local == null or local.finished or local.disconnected:
		return
	var inp: RaceInput = RaceInput.new() if net_menu else _input_of(local, dt)
	if local.has_meta("auto"):
		inp = local.get_meta("auto")
	net.client_input(inp, dt)
	local.simulate(inp, dt, go)
	local_hist.append([net.seq, local.global_position, local.speed])
	if local_hist.size() > 180:
		local_hist.pop_front()
	local.proj = track.project(local.global_position, local.proj)
	local.prev_s = local.s
	local.s = float(local.proj["s"])               # путь по трассе — для своего HUD и бота за игрока (проверки)
	local.lat = float(local.proj["lat"])
	local.half = float(local.proj["half"])
	local.on_short = bool(local.proj["short"])

## где был свой гонщик, когда отправил ввод № sq (последний шаг с этим номером) — по истории
func _hist_seq(sq: int) -> Array:
	for k in range(local_hist.size() - 1, -1, -1):
		if int(local_hist[k][0]) == sq:
			return [local_hist[k][1], local_hist[k][2]]
	if not local_hist.is_empty():
		return [local_hist[0][1], local_hist[0][2]]
	return [local.global_position, local.speed]

## клиент: куклы между снимками — с задержкой 100 мс, по двум ближайшим снимкам; пропал снимок — по скорости
func _puppets() -> void:
	if snap_host_t < 0.0:
		return
	var now := snap_host_t + (Time.get_ticks_msec() / 1000.0 - snap_local_t) - 0.1
	for r in riders:
		if not r.puppet or r.snaps.is_empty():
			continue
		var a = null
		var c = null
		for sn in r.snaps:
			if float(sn[0]) <= now:
				a = sn
			elif c == null:
				c = sn
		var pos: Vector3
		var h: float
		if a != null and c != null:
			var u := clampf((now - float(a[0])) / maxf(0.001, float(c[0]) - float(a[0])), 0.0, 1.0)
			pos = (a[1] as Vector3).lerp(c[1], u)
			h = lerp_angle(float(a[2]), float(c[2]), u)
		elif a != null:
			var ex := minf(now - float(a[0]), 0.25)          # снимок потерялся: чуть вперёд по скорости
			pos = (a[1] as Vector3) + r.vdir * r.speed * ex
			h = float(a[2])
		else:
			pos = r.snaps[0][1]
			h = float(r.snaps[0][2])
		r.set_snapshot_xf(pos, h)

func remote_event(slot: int, k: String, v) -> void:
	if slot == -1:
		# событие трассы, а не гонщика: случайная ситуация — хост решил, где и какая; строим ту же
		if k == "happening" and weather != null and typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and typeof(v[0]) == TYPE_STRING and typeof(v[1]) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(v[1])):
			weather.start(String(v[0]), float(v[1]), true)
		return
	if slot < 0 or slot >= riders.size():
		return
	var r: RaceRider = riders[slot]
	if r == local and k in PHYSICAL:
		return                                   # свои занос, прыжок и стены клиент уже показал сам
	r.events.append([k, v])
	if k == "item_get" and typeof(v) == TYPE_STRING and RaceData.ITEMS.has(String(v)):
		r.item = String(v)
	if k == "respawn" and r == local:
		cam_snap = true
	if k == "disconnect":
		r.disconnected = true
		r.visible = false
		hud.feed("%s отключился" % r.title, false)
		return
	if (k == "item_use" or k == "item_get" or k == "hit") and not (typeof(v) == TYPE_STRING and RaceData.ITEMS.has(String(v))):
		return
	_show_event(r, k, v)

func remote_hazard(hid: int, kind: String, pos: Vector3, rad: float) -> void:
	_hazard(kind, pos, clampf(rad, 0.5, 6.0), 999.0, null)
	hazards.back()["id"] = hid

func remote_hazard_end(hid: int) -> void:
	for h in hazards.duplicate():
		if int(h.get("id", -1)) == hid:
			hazards.erase(h)
			if is_instance_valid(h["node"]):
				(h["node"] as Node).queue_free()

func remote_box(i: int, on: bool) -> void:
	if i >= 0 and i < boxes.size():
		(boxes[i]["node"] as Node3D).visible = on

func remote_results(rows: Array) -> void:
	results = []
	for row in rows:
		if typeof(row) != TYPE_ARRAY or (row as Array).size() != 5 or typeof(row[0]) != TYPE_INT or int(row[0]) < 0 or int(row[0]) >= riders.size():
			continue
		var r: RaceRider = riders[int(row[0])]
		results.append({"rider": r, "title": r.title, "time": float(row[1]), "best": float(row[2]), "est": bool(row[3]), "dc": bool(row[4])})
	new_record = ""
	_set_state("results")
	hud.show_results()

## все в лобби (хост нажал «В ЛОББИ»)
func quit_to_lobby() -> void:
	if net != null:
		net.race = null
	if main != null:
		main.end_race_online("")
