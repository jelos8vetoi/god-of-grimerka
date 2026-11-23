## Проверки района 2 «ПОДЗЕМКА» (этап 1): запускается из golda67check ключом `--g67-pz` (checks.cjs: podzemka).
## Мир строится, герой проходит ногами все помещения, нет дыр наружу, маршруты по гарантиям, забег доходит до итогов,
## спуск закрыт до победы над Мишей, сохранение района переживает выход, замер длин и кадра.
class_name PodzemkaCheck
extends RefCounted

var perf_only := false
var c            # golda67check
var g
var G: Golda67
var P

## хребет и ветки: списки путевых точек (x, z)
const RIDGE := [[0, 2], [0, -8], [0, -20], [0, -35], [0, -52], [0, -79], [0, -100], [0, -122], [0, -140], [0, -160], [0, -168], [0, -179]]
const BRANCHES := {
	"arcade": [[0, -122], [-14, -122], [-30, -122], [-41, -128], [-41, -136], [-41, -128], [-30, -122]],
	"casino": [[-30, -122], [-46, -122], [-50, -122]],
	"staff": [[0, -145], [-13, -145], [-20, -145]],
	"tunnel_loop": [[0, -122], [14, -122], [38, -122], [42, -135], [42, -148], [42, -168], [20, -168], [10, -168], [8, -164], [8, -150]],
	"hamster": [[42, -146], [46, -146], [55, -146]],
	"tech": [[42, -160], [37, -160], [34, -160]],
	"alley": [[0, -48], [-8, -48], [-12, -49], [-12, -55], [-12, -100], [-8, -104], [0, -104]],
}

func ok(cond: bool, text: String) -> void:
	c.ok(cond, "ПОДЗЕМКА: " + text)

func _hero_y_ok() -> bool:
	return P.global_position.y > -6.5 and P.global_position.y < 9.0

## Идти к точке (x, z) клавишей «вперёд» с поворотом камеры; false — застрял или выпал
func _walk(tx: float, tz: float, sprint := false, tol := 1.1) -> bool:
	var stuck_t := 0.0
	var last: Vector3 = P.global_position
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		var to: Vector3 = Vector3(tx, 0, tz) - Vector3(P.global_position.x, 0, P.global_position.z)
		if to.length() < tol:
			Input.action_release("up")
			Input.action_release("sprint")
			return true
		if not _hero_y_ok():
			Input.action_release("up")
			return false
		g.cam_yaw = atan2(-to.x, -to.z)
		c._kill_all(g)
		G.pending = []
		G.wave_wait = 999.0
		if G.world.bounds != null:
			G.world.open_bounds()
		Input.action_press("up")
		if sprint:
			Input.action_press("sprint")
		await c.get_tree().create_timer(0.1, true, false, true).timeout
		if P.global_position.distance_to(last) < 0.25:
			stuck_t += 0.1
			if stuck_t > 3.0:
				Input.action_release("up")
				Input.action_release("sprint")
				return false
		else:
			stuck_t = 0.0
			last = P.global_position
	Input.action_release("up")
	return false

func _path_len(pts: Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += Vector2(float(pts[i][0]) - float(pts[i - 1][0]), float(pts[i][1]) - float(pts[i - 1][1])).length()
	return l

func run(g_, G_: Golda67) -> void:
	g = g_
	G = G_
	P = g.player
	# ---- до победы над Мишей спуск закрыт
	await c._go(G, P, "exit")
	await c.until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	c._kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await c.wait(1.0)
	ok(G.world.yard != null and G.world.district == G.world.yard, "двор: world.district совпадает с yard")
	var pt := G.point("descent")
	ok(not pt.is_empty(), "во дворе есть точка спуска")
	G.use("descent")
	await c.wait(0.4)
	ok(G.run.get("district", "") == "dvor" and G.place == "run", "до boss_misha спуск закрыт, забег двора идёт")
	# ---- спуск после победы над Мишей
	G.meta()["flags"]["boss_misha"] = true
	G.room_state = "open"
	G.use("descent")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 10.0)
	await c.wait(1.0)
	ok(G.run.get("district", "") == "podzemka" and G.world.district is G67Podzemka and G.world.yard == null, "спуск начинает забег района 2: мир подземки, yard = null")
	var pz: G67Podzemka = G.world.district
	ok(pz.wall_count > 60, "помещения построены: %d помещений, %d стен" % [G67Podzemka.ROOMS.size(), pz.wall_count])
	ok(G67Podzemka.ZONES.size() == 8 and G67District.is_podzemka(), "зон боя %d, район подземки активен" % G67Podzemka.ZONES.size())
	ok(P.global_position.distance_to(G67Podzemka.STAIRS_TOP) < 1.5, "герой наверху лестницы (%s)" % str(P.global_position))
	c._kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	G.world.open_bounds()
	await c.wait(0.5)
	if perf_only:
		await _perf()
		return
	# ---- лучи: нет дыр наружу
	var space: PhysicsDirectSpaceState3D = pz.get_world_3d().direct_space_state
	var holes := 0
	for id in G67Podzemka.ROOMS:
		var r: Array = G67Podzemka.ROOMS[id]
		if id == "stairs_shaft":
			continue
		var ctr := Vector3((float(r[0]) + float(r[1])) * 0.5, float(r[4]) + 1.2, (float(r[2]) + float(r[3])) * 0.5)
		for k in 16:
			var a := float(k) / 16.0 * TAU
			var q := PhysicsRayQueryParameters3D.create(ctr, ctr + Vector3(cos(a), 0, sin(a)) * 250.0)
			if space.intersect_ray(q).is_empty():
				holes += 1
				print("GOLDA67CHECK   ПОДЗЕМКА: дыра: помещение %s, направление %d" % [id, k])
		for dv in [Vector3.UP, Vector3.DOWN]:
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(ctr, ctr + dv * 30.0)).is_empty():
				holes += 1
	ok(holes == 0, "лучи из центров %d помещений (16 направлений + вверх/вниз) упираются в коллизию, дыр: %d" % [G67Podzemka.ROOMS.size(), holes])
	await _decor_checks(pz, space)
	# ---- хребет ногами
	var t0 := Time.get_ticks_msec()
	var ridge_ok := true
	for i in range(1, RIDGE.size()):
		if not await _walk(float(RIDGE[i][0]), float(RIDGE[i][1])):
			ridge_ok = false
			print("GOLDA67CHECK   ПОДЗЕМКА: застрял у точки %s, позиция %s" % [str(RIDGE[i]), str(P.global_position)])
			break
	var walk_s := float(Time.get_ticks_msec() - t0) / 1000.0
	ok(ridge_ok, "хребет 1→2→3→4→9→10 пройден ногами за %.0f с (длина %.0f м)" % [walk_s, _path_len(RIDGE)])
	# повторно бегом
	P.global_position = G67Podzemka.STAIRS_TOP
	P.velocity = Vector3.ZERO
	await c.wait(0.3)
	t0 = Time.get_ticks_msec()
	var run_ok := true
	for i in range(1, RIDGE.size()):
		if not await _walk(float(RIDGE[i][0]), float(RIDGE[i][1]), true):
			run_ok = false
			break
	ok(run_ok, "хребет бегом за %.0f с" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	var total := _path_len(RIDGE)
	for nm in BRANCHES:
		var br: Array = BRANCHES[nm]
		var start: Array = br[0]
		P.global_position = Vector3(float(start[0]), 0.05, float(start[1]))
		P.velocity = Vector3.ZERO
		await c.wait(0.2)
		var good := true
		for i in range(1, br.size()):
			if not await _walk(float(br[i][0]), float(br[i][1]), false, 0.5):
				good = false
				print("GOLDA67CHECK   ПОДЗЕМКА: ветка %s: застрял у %s, позиция %s" % [nm, str(br[i]), str(P.global_position)])
				break
		total += _path_len(br)
		ok(good, "ветка «%s» пройдена ногами (%.0f м)" % [nm, _path_len(br)])
	print("GOLDA67CHECK   ПОДЗЕМКА длина хребта %.0f м, хребет + ветки %.0f м, шагом %.0f с" % [_path_len(RIDGE), total, walk_s])
	await _shots()
	await _enemy_shots()
	await _routes()
	await _full_run()
	await _save_resume()
	await _enemy_checks()
	await _slot_checks()
	await _bot_battles()

## --pz-perfzones: средний и 1 % low кадр по зонам боя (6 с после прогрева 3 с)
func _perf() -> void:
	for zid in G67Podzemka.ZONES:
		var z: Dictionary = G67Podzemka.ZONES[zid]
		var ctr: Vector3 = z["c"]
		P.global_position = Vector3(ctr.x, 0.05, ctr.z)
		P.velocity = Vector3.ZERO
		await c.wait(3.0)
		var ft: Array = []
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 6000:
			var a := Time.get_ticks_usec()
			await c.get_tree().process_frame
			ft.append(float(Time.get_ticks_usec() - a) / 1000.0)
		ft.sort()
		var mean := 0.0
		for v in ft:
			mean += float(v)
		mean /= float(ft.size())
		var worst: Array = ft.slice(int(float(ft.size()) * 0.99))
		var w := 0.0
		for v in worst:
			w += float(v)
		w /= maxf(1.0, float(worst.size()))
		print("GOLDA67CHECK   PZPERF %s: средний %.1f FPS, 1%% худших %.1f FPS" % [zid, 1000.0 / mean, 1000.0 / maxf(w, 0.01)])

func _shots() -> void:
	P.global_position = Vector3(0, 0.05, -300)
	var V := [
		["pz_stairs", Vector3(0, 7.5, 4.5), Vector3(0, 1.0, -14)], ["pz_gate1", Vector3(0, 1.9, -28), Vector3(0, 1.2, -40)],
		["pz_gallery", Vector3(0, 1.8, -48), Vector3(0, 1.8, -105)], ["pz_kiosk_shawarma", Vector3(0.2, 1.6, -54.6), Vector3(-4.6, 1.3, -54.0)],
		["pz_kiosk_socks", Vector3(0.2, 1.6, -66.4), Vector3(-4.5, 1.3, -66.0)], ["pz_kiosk_keys", Vector3(-0.4, 1.6, -54.6), Vector3(4.4, 1.2, -54.0)], ["pz_cross", Vector3(0, 2.2, -112), Vector3(0, 1.5, -131)],
		["pz_arcade", Vector3(-16.6, 2.0, -123.0), Vector3(-31.0, 1.2, -118.0)], ["pz_tunnel", Vector3(14, 1.7, -122), Vector3(36, 1.5, -122)],
		["pz_hamster_door", Vector3(37.5, 1.7, -144.0), Vector3(44.0, 1.8, -146.0)], ["pz_hamster_city", Vector3(47.0, 1.9, -141.5), Vector3(51.5, 1.9, -152.5)],
		["pz_casino_door", Vector3(-30.0, 1.7, -126.5), Vector3(-43.5, 1.5, -129.0)], ["pz_slot_3m", Vector3(-49.6, 1.5, -122.0), Vector3(-52.5, 1.15, -122.0)],
		["pz_slot_1m", Vector3(-51.55, 1.3, -122.0), Vector3(-52.55, 1.15, -122.0)], ["pz_dog", Vector3(-45.5, 1.0, -121.0), Vector3(-48.0, 0.5, -121.0)], ["pz_dog34", Vector3(-46.5, 1.2, -118.8), Vector3(-48.0, 0.5, -121.0)], ["pz_spit", Vector3(-0.6, 1.7, -54.6), Vector3(-3.9, 1.6, -54.6)],
		["pz_cash", Vector3(0, 2.4, -138), Vector3(0, 2.5, -160)], ["pz_arena", Vector3(0, 3.0, -172), Vector3(0, 1.5, -186)],
		["pz_staff", Vector3(-15.0, 1.7, -145.0), Vector3(-24.0, 1.2, -145.0)],
	]
	for v in V:
		await c._cam_shot(g, String(v[0]), v[1], v[2])

## 200 маршрутов района 2: гарантии как во дворе
func _routes() -> void:
	var saved_run: Dictionary = G.run.duplicate(true)
	var bad := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for n in 200:
		G.run = {"district": "podzemka", "tpl": n % 3, "stages": []}
		G.meta()["runs"] = n
		var battles := 0
		var fit := false
		var good := true
		for pos in 6:
			var opts: Array = G.route_options(pos)
			if opts.is_empty():
				good = false
				break
			var o: Dictionary = opts[rng.randi() % opts.size()]
			var t := String(o["type"])
			if t in ["battle", "elite"]:
				battles += 1
			if t in ["fit", "elite"]:
				fit = true
			if t == "kiosk" and pos != 3:
				good = false
			if pos == 5 and t != "boss":
				good = false
			if not G67District.has_zone(String(o["place"])):
				good = false
			(G.run["stages"] as Array).append([t, String(o["place"]), ""])
		if not (good and battles >= 2 and battles <= 3 and fit):
			bad += 1
	G.run = saved_run
	ok(bad == 0, "200 маршрутов района 2 удовлетворяют гарантиям (нарушений %d)" % bad)

## Забег района быстрым способом: бои зачищаются, награды берутся, босс убирается
func _full_run() -> void:
	var P2 = P
	await G.enter_hub()
	G.meta()["flags"]["boss_misha"] = true
	G.sel_district = "podzemka"
	await c._go(G, P2, "exit")
	await c.until(func(): return G.place == "run" and G.room_state == "fight", 10.0)
	var stages: Array = []
	for step in 8:
		if G.room_state == "boss":
			break
		if G.room_state == "fight":
			await c._clear_room(g, G, 60.0)
		if String(G.room.get("type", "")) == "elite":
			await c.until(func(): return not G.point("elite_fit").is_empty(), 4.0)
			await c._go(G, P2, "elite_fit")
		await c.until(func(): return G.hub_ui != null or not G.world.gates.is_empty(), 6.0)
		await c.wait(0.5)
		if G.hub_ui != null and G.hub_ui.kind == "fit":
			var fo: Array = G.fit_options(String(G.room.get("type", "")) == "elite")
			if not fo.is_empty():
				G.take_fit(String(fo[0]))
			await c.wait(0.3)
		if G.hub_ui != null:
			await c.key(KEY_ESCAPE)
			await c.until(func(): return G.hub_ui == null, 2.0)
		stages.append(String(G.room.get("type", "")) + "@" + String(G.room.get("place", "")))
		if G.world.gates.is_empty():
			await c.wait(1.0)
		if G.world.gates.is_empty():
			print("GOLDA67CHECK   ПОДЗЕМКА: нет дверей после этапа %s: состояние %s, экран %s" % [str(G.room), G.room_state, str(G.hub_ui.kind) if G.hub_ui != null else "-"])
			break
		var pos := int(G.run["pos"])
		await c._go(G, P2, "gate0")
		await c.until(func(): return int(G.run["pos"]) != pos, 8.0)
		await c.wait(0.3)
	ok(G.room_state == "boss" and G.run.get("district", "") == "podzemka", "забег района дошёл до босса (%s)" % ", ".join(stages))
	await c.wait(1.0)
	var bs = g.boss_e
	print("GOLDA67CHECK   ПОДЗЕМКА босс: %s жив=%s состояние=%s" % [str(bs), str(bs != null and is_instance_valid(bs) and bs.alive()), G.room_state])
	for k in 12:
		if g.boss_e != null and is_instance_valid(g.boss_e) and g.boss_e.alive():
			g.boss_e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
		c._kill_all(g)
		await c.wait(0.5)
		if G.room_state != "boss":
			break
	await c.until(func(): return bool((G.meta().get("flags", {}) as Dictionary).get("boss_fortuna", false)) or G.place == "hub", 20.0)
	await c.wait(1.0)
	ok(bool((G.meta().get("flags", {}) as Dictionary).get("boss_fortuna", false)), "победа над боссом-заглушкой ставит boss_fortuna")

## сохранение района 2: выход в подъезд и продолжение
func _save_resume() -> void:
	await G.enter_hub()
	G.sel_district = "podzemka"
	await c._go(G, P, "exit")
	await c.until(func(): return G.place == "run" and G.room_state == "fight", 10.0)
	c._kill_all(g)
	await c._clear_room(g, G, 40.0)
	await c.wait(0.8)
	if G.hub_ui != null:
		await c.key(KEY_ESCAPE)
	G._save_run("open")
	var pos0 := int(G.run.get("pos", 0))
	await G.enter_hub()
	ok(G.place == "hub", "подъезд после выхода из подземки")
	await G.resume_run()
	await c.wait(1.0)
	ok(G.run.get("district", "") == "podzemka" and G.world.district is G67Podzemka and int(G.run.get("pos", -1)) == pos0, "продолжение забега района 2 (позиция %d → %d)" % [pos0, int(G.run.get("pos", -1))])

## Оформление: надписи, модели, коллизия предметов, ширина проходов, свободные точки входа и стойки
func _decor_checks(pz: G67Podzemka, space: PhysicsDirectSpaceState3D) -> void:
	ok(pz.use_modules, "модули Blender загружены (use_modules)")
	ok(pz.missing.is_empty(), "все модели на месте (нет: %s)" % ", ".join(pz.missing.slice(0, 6)))
	var have := {}
	for ch in pz.find_children("*", "Label3D", true, false):
		have[String((ch as Label3D).text)] = true
	var lost: Array = []
	for sg in G67Podzemka.SIGNS:
		if not have.has(String(sg[0])):
			lost.append(String(sg[0]))
	ok(lost.is_empty(), "надписи раздела 7 на месте (%d из %d, нет: %s)" % [G67Podzemka.SIGNS.size() - lost.size(), G67Podzemka.SIGNS.size(), str(lost.slice(0, 3))])
	# предметы с коллизией: луч на высоте 0,7 м с трёх метров в центр упирается близко к предмету
	var thru := 0
	for pr in G67Podzemka.PROPS:
		if not bool(pr[6]):
			continue
		var ctr := G67Podzemka.fit(Vector3(float(pr[1]), 0.7 + float(pr[4]), float(pr[2])))
		var hit_any := false
		for dv in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var q := PhysicsRayQueryParameters3D.create(ctr + dv * 3.0, ctr)
			var h := space.intersect_ray(q)
			if not h.is_empty() and (h["position"] as Vector3).distance_to(ctr) < 2.4:
				hit_any = true
		if not hit_any:
			thru += 1
			print("GOLDA67CHECK   ПОДЗЕМКА: предмет без коллизии: %s (%.1f; %.1f)" % [String(pr[0]), float(pr[1]), float(pr[2])])
	ok(thru == 0, "герой не проходит сквозь ларьки, автоматы, турникеты и колонны (без коллизии: %d)" % thru)
	# ширина проходов вдоль хребта: свободный поперечник ≥ 2 м
	var narrow := 0
	for i in range(1, RIDGE.size()):
		var p0 := Vector3(float(RIDGE[i - 1][0]), 0.9, float(RIDGE[i - 1][1]))
		var p1 := Vector3(float(RIDGE[i][0]), 0.9, float(RIDGE[i][1]))
		var dirv := (p1 - p0).normalized()
		var side := Vector3(-dirv.z, 0, dirv.x)
		var steps := int((p1 - p0).length() / 4.0)
		for k in range(1, steps + 1):
			var pt := p0 + dirv * 4.0 * float(k)
			if pt.y < 0.0:
				continue
			var span := 0.0
			for sd in [side, -side]:
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(pt, pt + sd * 6.0))
				span += (h["position"] as Vector3).distance_to(pt) if not h.is_empty() else 6.0
			if span < 2.0:
				narrow += 1
	ok(narrow == 0, "проходы хребта не уже 2 м после расстановки предметов (узких мест: %d)" % narrow)
	# точки входа врагов и стойки этапов свободны от коллизии
	var blocked := 0
	for zid in G67Podzemka.ZONES:
		var z: Dictionary = G67Podzemka.ZONES[zid]
		var pts: Array = []
		for sp in z.get("spawns", []):
			pts.append(sp[0])
		pts.append(G67World.gate_spot({"type": "battle", "place": zid})["pos"])
		for p in pts:
			var qp := PhysicsShapeQueryParameters3D.new()
			var sh := SphereShape3D.new()
			sh.radius = 0.4
			qp.shape = sh
			qp.transform = Transform3D(Basis(), Vector3(float(p.x), 0.9, float(p.z)))
			if not space.intersect_shape(qp, 1).is_empty():
				blocked += 1
				print("GOLDA67CHECK   ПОДЗЕМКА: занята точка зоны %s: %s" % [zid, str(p)])
	ok(blocked == 0, "точки входа врагов и стойки этапов свободны (занято: %d)" % blocked)

## Враги района: щит Контролёра гасит лёгкий удар спереди, не гасит тяжёлый и тыльный; параметры; метки и призыв заданы данными
func _enemy_checks() -> void:
	P.global_position = Vector3(0, 0.05, -30)
	G.room = {"type": "battle", "place": "gate1"}
	G.room_state = "fight"
	var cnt0: int = g.enemies.size()
	G._spawn("controller")
	G._spawn("promoter")
	G._spawn("bouncer")
	await c.wait(0.5)
	var ctl = null
	var prm = null
	var bnc = null
	for e in g.enemies:
		if not is_instance_valid(e):
			continue
		match String(e.get_meta("foe", "")):
			"controller": ctl = e
			"promoter": prm = e
			"bouncer": bnc = e
	ok(ctl != null and prm != null and bnc != null, "враги района появляются (Контролёр, Зазывала, Вышибала)")
	if ctl == null or prm == null or bnc == null:
		return
	ok(absf(ctl.max_hp - 150.0 * float(g.diff_hp)) < 1.0 or ctl.max_hp > 100.0, "Контролёр: здоровье %.0f" % ctl.max_hp)
	ok(bnc.max_hp > 400.0, "Вышибала: здоровье %.0f" % bnc.max_hp)
	ok(prm.has_meta("moves") and (prm.get_meta("moves") as Dictionary).has("flyer") and (prm.get_meta("moves") as Dictionary).has("call"), "Зазывала: приёмы «флаер» и «призыв» заданы")
	ctl.state = "idle"
	ctl.set_physics_process(false)
	var front := Vector3(sin(ctl.face), 0, cos(ctl.face))
	var h0: float = ctl.hp
	ctl.take_hit(10.0, -front, 0.0, false)
	var light_front: float = h0 - ctl.hp
	ctl.hp = h0
	ctl.take_hit(10.0, -front, 0.0, true)
	var heavy_front: float = h0 - ctl.hp
	ctl.hp = h0
	ctl.take_hit(10.0, front, 0.0, false)
	var light_back: float = h0 - ctl.hp
	ctl.hp = h0
	ok(light_front < light_back * 0.5 and heavy_front > light_back * 0.8, "щит Контролёра: лёгкий спереди %.1f, тяжёлый спереди %.1f, лёгкий в спину %.1f" % [light_front, heavy_front, light_back])
	c._kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await c.wait(0.5)

## Бот-клавишник проходит первые два боя района
func _bot_battles() -> void:
	await G.enter_hub()
	G.meta()["flags"]["boss_misha"] = true
	G.sel_district = "podzemka"
	await c._go(G, P, "exit")
	await c.until(func(): return G.place == "run", 10.0)
	P.global_position = Vector3(0, 0.05, -33)
	var report: Array = []
	for n in 2:
		await c.until(func(): return G.room_state == "fight", 15.0)
		var t0 := Time.get_ticks_msec()
		P.hp = P.max_hp
		await c.until(func(): return g.enemies.size() > 0, 8.0)
		var br: Dictionary = await c._bot_fight(g, G, 150.0)
		report.append("бой %d: %.0f с, здоровье %.0f из %.0f%s" % [n + 1, float(Time.get_ticks_msec() - t0) / 1000.0, float(P.hp), float(P.max_hp), " (таймаут)" if bool(br["timeout"]) else ""])
		await c.wait(0.8)
		if G.hub_ui != null:
			await c.key(KEY_ESCAPE)
		await c.until(func(): return not G.world.gates.is_empty(), 6.0)
		if G.world.gates.is_empty():
			break
		var pos := int(G.run["pos"])
		await c._go(G, P, "gate0")
		await c.until(func(): return int(G.run["pos"]) != pos, 8.0)
	print("GOLDA67CHECK   ПОДЗЕМКА бот: %s" % "; ".join(report))
	ok(report.size() >= 1, "бот-клавишник: сыграно боёв района %d, итог: %s" % [report.size(), "; ".join(report)])

## Слот: правила поля и снимки экрана (в покое, вращение, джекпот)
func _slot_checks() -> void:
	var pz: G67Podzemka = G.world.district as G67Podzemka
	if pz == null or pz.slot_screen == null:
		ok(false, "экран слота создан")
		return
	var sc: G67SlotScreen = pz.slot_screen
	var bad := 0
	var wins := 0
	for n in range(1, 67):
		for k in 20:
			var f: Array = sc.make_field(n)
			var dogs := 0
			for col in f:
				for sy in col:
					if sy == "dog":
						dogs += 1
			if dogs > 4:
				bad += 1
			if int(sc.pays(f)["gold"]) > 0:
				wins += 1
	ok(bad == 0, "до 67-го спина не больше 4 ротвейлеров в поле (нарушений %d, мелких выплат %d из 1320)" % [bad, wins])
	var jf: Array = sc.make_field(67)
	var alld := true
	for col in jf:
		for sy in col:
			if sy != "dog":
				alld = false
	ok(alld and jf.size() == 5, "67-й спин: все 15 ячеек — ротвейлеры")
	var out := OS.get_environment("TEMP") + "/g67_slot_"
	sc.get_viewport().get_texture().get_image().save_png(out + "rest.png")
	sc.field = [["a", "k", "a"], ["dog", "dog2", "dog"], ["house", "paw", "house"], ["dog", "dog2", "dog"], ["a", "k", "a"]]
	sc._show_field()
	await c.wait(0.3)
	sc.get_viewport().get_texture().get_image().save_png(out + "ref.png")
	sc.spin(1, false)
	await c.wait(0.25)
	sc.get_viewport().get_texture().get_image().save_png(out + "spin.png")
	await c.until(func(): return not sc.spinning, 8.0)
	print("GOLDA67CHECK   слот: спин 1 завершён: ", not sc.spinning)
	sc.spin(67, true)
	await c.until(func(): return not sc.spinning, 8.0)
	print("GOLDA67CHECK   слот: спин 67 завершён: ", not sc.spinning)
	await c.wait(0.6)
	sc.get_viewport().get_texture().get_image().save_png(out + "jackpot.png")
	ok(true, "снимки слота: " + out + "{rest,spin,jackpot}.png")

## Снимки врагов в игре: стойка, атака, гибель (клипы PzC*/PzP*/PzB*)
func _enemy_shots() -> void:
	var spec := [["controller", "PzCStance", "PzCStrike", "PzCDeath"], ["promoter", "PzPStance", "PzPThrow", "PzPDeath"], ["bouncer", "PzBStance", "PzBOver", "PzBDeath"]]
	for sp in spec:
		c._kill_all(g)
		for oe in g.enemies.duplicate():
			if is_instance_valid(oe):
				oe.queue_free()
		await c.wait(0.3)
		G.room = {"type": "battle", "place": "gate1"}
		G.room_state = "fight"
		G.pending = []
		G.wave_wait = 999.0
		G._spawn(String(sp[0]))
		await c.wait(0.4)
		var en = null
		for e in g.enemies:
			if is_instance_valid(e) and String(e.get_meta("foe", "")) == String(sp[0]):
				en = e
		if en == null:
			ok(false, "снимок врага %s: враг не появился" % sp[0])
			continue
		en.set_physics_process(false)
		en.global_position = Vector3(0, 0.05, -34)
		en.rotation.y = PI
		en.face = PI
		var h: float = float(en.height)
		var camp := Vector3(0.0, h * 0.62, -34.0 + h * 2.1)
		var tgt := Vector3(0.0, h * 0.5, -34.0)
		for k in 3:
			en.rig.play(String(sp[1 + k]), 0.05)
			en.rig.flash(0.0)
			await c.wait(0.45 if k < 2 else 1.9)
			await c._cam_shot(g, "pz_foe_%s_%d" % [sp[0], k], camp, tgt)
		ok(en.rig.has_clip(String(sp[1])) and en.rig.has_clip(String(sp[2])) and en.rig.has_clip(String(sp[3])), "враг %s: клипы стойки, атаки и гибели есть, рост %.2f" % [sp[0], h])
	c._kill_all(g)
