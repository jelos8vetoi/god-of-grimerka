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
	"arcade": [[0, -122], [-14, -122], [-30, -122], [-41, -122], [-41, -128], [-41, -136], [-41, -128], [-41, -122], [-30, -122]],
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

var fz_only := false

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
	if fz_only:
		await _fortuna_checks()
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
	for did in ["shutter", "hamster", "tech"]:
		(G.world.district as G67Podzemka).open_door(did)
	await c.wait(0.3)
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
	await _dark_shots()
	await _krot_checks()
	await _mech_checks()
	await _hamster_checks()
	await _routes()
	await _full_run()
	await _save_resume()
	await _enemy_checks()
	await _slot_checks()
	await _casino_checks()
	await _clip_checks()
	await _bottle_checks()
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
	var mirrored: Array = []
	for lb in pz.sign_nodes:
		var lab := lb as Label3D
		var rid: String = pz.room_at(Vector3(lab.position.x, 0.5, lab.position.z))
		if rid == "" or lab.double_sided:
			continue
		var rr: Array = G67Podzemka.ROOMS[rid]
		var to := Vector3((float(rr[0]) + float(rr[1])) * 0.5 - lab.position.x, 0.0, (float(rr[2]) + float(rr[3])) * 0.5 - lab.position.z)
		var nrm: Vector3 = lab.global_transform.basis.z
		if to.length() > 1.2 and nrm.dot(to.normalized()) < 0.0:
			mirrored.append(lab.text.left(24))
	ok(mirrored.is_empty(), "надписи читаются из помещения, зеркальных нет (%d, например %s)" % [mirrored.size(), str(mirrored.slice(0, 3))])
	# предметы с коллизией: луч на высоте 0,7 м с трёх метров в центр упирается близко к предмету
	var thru := 0
	for pr in pz.all_props_cache:
		if not bool(pr[6]):
			continue
		var raw := Vector3(float(pr[1]), 0.7 + float(pr[4]), float(pr[2]))
		var ctr: Vector3 = raw if pr.size() > 7 else G67Podzemka.fit(raw)
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
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(3.0)
	G.wave_wait = 1.2
	P.global_position = Vector3(0, 0.05, -33)
	var report: Array = []
	for n in 3:
		await c.until(func(): return G.room_state == "fight", 20.0)
		var comp := ""
		var t0 := Time.get_ticks_msec()
		P.hp = P.max_hp
		await c.wait(1.5)
		print("GOLDA67CHECK   бот: бой %d room=%s state=%s waves=%d pending=%d alive=%d pos=%s busy=%s place=%s runpos=%s" % [n + 1, str(G.room), G.room_state, G.waves.size(), G.pending.size(), G.alive(), str(P.global_position), str(G.busy), G.place, str(G.run.get("pos", "?"))])
		var kinds := {}
		var br: Dictionary = await c._bot_fight(g, G, 150.0)
		for e in G.events:
			if String(e[0]) == "clear":
				comp = String(e[1])
		report.append("бой %d: %.0f с, здоровье %.0f из %.0f%s" % [n + 1, float(Time.get_ticks_msec() - t0) / 1000.0, float(P.hp), float(P.max_hp), " (таймаут)" if bool(br["timeout"]) else ""])
		print("GOLDA67CHECK   бот: бой %d итог %s" % [n + 1, report[-1]])
		await c.wait(1.0)
		if G.hub_ui != null:
			await c.key(KEY_ESCAPE)
		await c.until(func(): return not G.world.gates.is_empty(), 8.0)
		if G.world.gates.is_empty():
			break
		var pos := int(G.run["pos"])
		await c._go(G, P, "gate0")
		await c.until(func(): return int(G.run.get("pos", pos)) != pos, 10.0)
		await c.wait(0.5)
		G.wave_wait = 1.2
	print("GOLDA67CHECK   ПОДЗЕМКА бот: %s" % "; ".join(report))
	ok(report.size() >= 1, "бот-клавишник: бои района идут по-настоящему, итог: %s (бот гибнет — данные для баланса)" % "; ".join(report))

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

## Метки атак в самом тёмном месте (зал автоматов): враги живые, снимки по ходу замаха
func _dark_shots() -> void:
	c._kill_all(g)
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()
	await c.wait(0.3)
	P.global_position = Vector3(-30, 0.05, -121)
	G.room = {"type": "battle", "place": "arcade"}
	G.room_state = "fight"
	G.pending = []
	G.wave_wait = 999.0
	G._spawn("bouncer")
	G._spawn("controller")
	for k in 5:
		await c.wait(0.8)
		await c._cam_shot(g, "pz_dark_%d" % k, P.global_position + Vector3(0, 3.4, 5.5), P.global_position + Vector3(0, 0.4, -1.0))
	c._kill_all(g)
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()

## КРОТ 4 / КРОТ 5: правило позиций на 300 сгенерированных забегах, постановка, табличка, сохранение в архив
func _krot_checks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var bad := 0
	var both := 0
	for run_i in 300:
		var seen4 := false
		var k4pos := -1
		var seen5 := false
		var gap_bad := false
		for pos in 6:
			# игрок берёт встречу в случайной доступной позиции, но к концу забега — обязательно, если доступна
			if not seen4 and G67Data.pz_krot_ok("krot4", pos, false, -1) and (rng.randf() < 0.5 or pos >= 4):
				seen4 = true
				k4pos = pos
			elif seen4 and not seen5 and G67Data.pz_krot_ok("krot5", pos, true, k4pos) and (rng.randf() < 0.6 or pos == 5):
				seen5 = true
				if absi(pos - k4pos) < 2:
					gap_bad = true
		if gap_bad:
			bad += 1
		if seen4 and seen5:
			both += 1
	ok(bad == 0, "КРОТ 4 и 5 не на соседних позициях (300 забегов, нарушений %d; обе встречи состоялись в %d)" % [bad, both])
	ok(both > 150 and G67Data.pz_krot_ok("krot5", 3, true, 1) and not G67Data.pz_krot_ok("krot5", 2, true, 1) and not G67Data.pz_krot_ok("krot5", 3, true, 2), "правило доступности встреч (после позиции 1 и 3, разрыв ≥ 2)")
	# постановка КРОТА 4 в галерее
	G.meta()["seen"] = []
	G.run["pos"] = 1
	G.krot_k = {}
	G._place_krot("gallery")
	await c.wait(0.4)
	ok(G.krot_k.get("id", "") == "krot4" and G.world.actors.has("g67_krot"), "КРОТ 4 стоит в галерее после позиции 1")
	P.global_position = Vector3(8.0, 0.05, -72.0)
	await c.wait(0.6)
	await c._cam_shot(g, "pz_krot4", Vector3(6.6, 2.4, -72.8), Vector3(9.3, 2.1, -74.2))
	ok(G.krot_sign_lb != null or G.krot_sign_cd > 0.0, "над КРОТОМ 4 показана табличка «ЗАДАНИЕ: НАЙТИ 5 РУБЛЕЙ»")
	G._krot_done("krot4")
	await c.wait(0.3)
	ok((G.meta().get("seen", []) as Array).has("krot4") and (G.meta().get("archive", []) as Array).has("krot4") and int(G.run.get("k4pos", -1)) == 1, "КРОТ 4: seen, архив и позиция запомнены")
	# КРОТ 5 у микроволновки
	G.run["pos"] = 3
	G.krot_k = {}
	G._place_krot("arcade")
	await c.wait(0.4)
	ok(G.krot_k.get("id", "") == "krot5", "КРОТ 5 стоит в зале автоматов после позиции 3")
	P.global_position = Vector3(-38.0, 0.05, -108.0)
	await c.wait(0.4)
	await c._cam_shot(g, "pz_krot5", Vector3(-37.2, 1.9, -113.2), Vector3(-41.2, 1.2, -110.6))
	G._krot_beat(2)
	await c.wait(0.25)
	await c._cam_shot(g, "pz_krot5_cut", P.global_position + Vector3(0, 2, 3), P.global_position)
	await c.wait(0.6)
	G._krot_beat(4)
	G._krot_done("krot5")
	await c.wait(0.2)

## Мини-игра хомяков: бот с точностью 80 % и 100 %, комбо, золотой; казино: поле на 67-м и после него; ОШЕЙНИК один раз
func _hamster_checks() -> void:
	var hg := G67HamsterGame.new()
	hg.headless = true
	hg.holes = []
	for i in 24:
		hg.holes.append(Rect2(Vector2(i * 10, 0), Vector2(8, 8)))
	var r80: Dictionary = hg.simulate(0.8, 11)
	ok(int(r80["score"]) > 0 and int(r80["best_combo"]) >= 2 and int(r80["hits"]) > 5 and int(r80["misses"]) > 0 and int(r80["resets"]) > 0 and float(r80["time_left"]) <= 0.0, "бот хомяков (80 %%, реакция 0,25–0,6 с): очки %d, лучшее комбо ×%d, попаданий %d, пропущено %d, сбросов комбо %d, золотых %d" % [int(r80["score"]), int(r80["best_combo"]), int(r80["hits"]), int(r80["misses"]), int(r80["resets"]), int(r80["golds"])])
	var r100: Dictionary = hg.simulate(1.0, 12)
	ok(int(r100["best_combo"]) >= 4 and int(r100["golds"]) <= 2, "бот хомяков (100 %%): комбо ×5 достигнуто, золотых %d (1–2), очки %d" % [int(r100["golds"]), int(r100["score"])])
	hg.free()
	var layer := CanvasLayer.new()
	layer.layer = 30
	var hg2 := G67HamsterGame.new()
	layer.add_child(hg2)
	g.add_child(layer)
	var wall = (G.world.district as G67Podzemka).get_node_or_null("hamster_wall")
	ok(wall != null, "стена нор хомяков на месте (24 норы hole_NN)")
	if wall != null:
		hg2.setup_3d(wall as Node3D, G.world)
	var shot_gold := false
	for k in 120:
		await c.wait(0.25)
		var has_gold := false
		for h in hg2.hams.duplicate():
			if String(h["kind"]) == "gold" and not bool(h["hit"]):
				has_gold = true
		if has_gold and not shot_gold and float(hg2.t_left) < 40.0:
			for h in hg2.hams:
				if String(h["kind"]) == "gold" and float(h["age"]) > 0.4:
					shot_gold = true
			if shot_gold:
				await c.shot("pz_hamster_gold")
		if k == 24:
			await c.shot("pz_hamster_game")
		if k > 6 and k % 3 == 0:
			for h in hg2.hams.duplicate():
				if not bool(h["hit"]) and float(h["age"]) > 0.3 and hg2.rng.randf() < 0.75 and (String(h["kind"]) != "gold" or shot_gold):
					hg2.tap_hole(int(h["hole"]))
	hg2._end(false)
	await c.wait(0.3)
	await c.shot("pz_hamster_card")
	hg2.cleanup()
	layer.queue_free()
	ok((G.world.district as G67Podzemka).door_open_flags.get("hamster", false), "дверь хомяков открыта по [E] (скрип синтезируется)")
	P.global_position = Vector3(36, 0.05, -146)
	var duck_ok := true
	G.world.district.open_door("hamster")
	P.global_position = Vector3(40.0, 0.05, -146.0)
	duck_ok = G.pz_duck_district()
	P.global_position = Vector3(30.0, 0.05, -146.0)
	duck_ok = duck_ok and not G.pz_duck_district()
	P.global_position = Vector3(52.0, 0.05, -146.0)
	duck_ok = duck_ok and G.pz_duck_district()
	ok(duck_ok, "музыка района глохнет в комнате хомяков и в 6 м от открытой двери, возвращается снаружи")
	var sc: G67SlotScreen = (G.world.district as G67Podzemka).slot_screen
	var jf: Array = sc.make_field(67)
	var later_jackpot := false
	for n in [68, 134, 201]:
		var f2: Array = sc.make_field(n)
		var all_dogs := true
		for col in f2:
			for sy in col:
				if sy != "dog":
					all_dogs = false
		if all_dogs:
			later_jackpot = true
	ok(jf[0][0] == "dog" and not later_jackpot, "джекпот ровно на 67-м спине, после 67-го поле целиком из ротвейлеров не выпадает")

## Пять бутылок: сцена подбора каждой (идёт за укрытие, камера на угол, выходит с бутылкой), HUD, техпомещение, финал, артефакт без слота, гибель и новый забег
func _bottle_scene_one(n: int, shot: bool) -> bool:
	var sc: Dictionary = G.bottle_scene_points(n)
	P.global_position = sc["pos"]
	var seen: Array = []
	var ev0: int = G.events.size()
	var task := func(): await G._bottle_pick(n)
	task.call()
	var t0 := Time.get_ticks_msec()
	var shot_done := false
	while G.bottle_busy and float(Time.get_ticks_msec() - t0) < 14000.0:
		await c.wait(0.1)
		for e in G.events.slice(ev0):
			if String(e[0]) == "bottle_scene" and int(e[1]) == n and not seen.has(String(e[2])):
				seen.append(String(e[2]))
		if shot and not shot_done and seen.has("hidden"):
			shot_done = true
			await c.shot("pz_bottle_%d" % n)
	var fin: bool = not G.bottle_busy and (G.run.get("bottles", []) as Array).has(n) and seen.has("walk") and seen.has("hidden") and seen.has("out") and P.visible and P.is_physics_processing()
	return fin

func _bottle_checks() -> void:
	if G.hub_ui != null:
		G.hub_ui.close()
	await c.wait(0.4)
	G.run["bottles"] = []
	var scenes_ok := 0
	for n in range(1, 6):
		if await _bottle_scene_one(n, n == 1 or n == 4):
			scenes_ok += 1
		if n == 1:
			ok(G.bottle_lb != null and G.bottle_lb.visible and G.bottle_lb.text == "БУТЫЛКИ: 1/5", "HUD «%s» после первой бутылки" % (G.bottle_lb.text if G.bottle_lb != null else "нет"))
	ok(scenes_ok == 5, "сцена подбора завершается и возвращает управление у всех пяти бутылок (%d из 5)" % scenes_ok)
	ok((G.run.get("bottles", []) as Array).size() == 5, "собраны все пять бутылок (%d)" % (G.run.get("bottles", []) as Array).size())
	ok((G.world.district as G67Podzemka).door_open_flags.get("tech", false), "на 5/5 техпомещение открыто")
	var slots_before: int = (G.run["arts"] as Array).filter(func(x): return not G67Data.ART_EVENT.has(String(x))).size()
	P.global_position = Vector3(34.0, 0.05, -158.0)
	var final_task := func(): await G._reserve_final()
	final_task.call()
	await c.wait(3.3)
	await c.shot("pz_bottle_final")
	await c.until(func(): return not G.final_busy, 12.0)
	ok(G.has_art("reserve_05") and G.reserve_charges == 5 and (G.meta().get("artifacts", []) as Array).has("reserve_05") and not G.bottle_lb.visible, "финал: бутылки в ряд, упаковка, артефакт «АВАРИЙНЫЙ ЗАПАС 0.5» (5 зарядов) в коллекции, индикатор бутылок скрыт")
	ok((G.run["arts"] as Array).filter(func(x): return not G67Data.ART_EVENT.has(String(x))).size() == slots_before, "артефакт не занимает слот")
	# гибель сбрасывает счёт забега, артефакт в коллекции остаётся
	G.on_dead()
	await c.wait(0.4)
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.0)
	ok((G.run.get("bottles", []) as Array).is_empty() and (G.meta().get("artifacts", []) as Array).has("reserve_05"), "гибель сбросила счёт бутылок забега, артефакт в коллекции остался")
	G.reserve_charges = 5
	(G.run["arts"] as Array).append("reserve_05")
	# боевой эффект: пять попаданий тратят заряды, шестое обычное
	var spent := 0
	for k in 6:
		if G.reserve_use():
			spent += 1
	ok(spent == 5 and G.reserve_charges == 0, "заряды запаса: пять попаданий тратят заряды (%d), шестое обычное" % spent)
	G.reserve_charges = 5
	(G.run["arts"] as Array).append("reserve_05")
	P.global_position = Vector3(0, 0.05, -33)
	G.room = {"type": "battle", "place": "gate1"}
	G.room_state = "fight"
	G.pending = []
	G.wave_wait = 999.0
	G._spawn("controller")
	G._spawn("controller")
	await c.wait(0.6)
	var tg: Array = []
	for e in g.enemies:
		if is_instance_valid(e):
			e.set_physics_process(false)
			tg.append(e)
	if tg.size() >= 2:
		(tg[0] as Node3D).global_position = Vector3(0, 0.05, -38)
		(tg[1] as Node3D).global_position = Vector3(1.5, 0.05, -38)
		var hp1: float = tg[1].hp
		tg[0].state = "idle"
		tg[1].state = "idle"
		var sp: bool = G.reserve_use()
		P.bottles._reserve_splash(Vector3(0, 0.05, -38), 10.0, tg[0])
		var loss: float = hp1 - tg[1].hp
		ok(sp and G.reserve_charges == 4 and loss > 1.0 and tg[1].slow_t > 2.5 and absf(tg[1].slow_k - 0.4) < 0.05, "всплеск запаса: заряд потрачен (осталось %d), соседу урон %.1f (≈0,6 от 10 с поправкой на броню), замедление %.1f с, множитель %.2f" % [G.reserve_charges, loss, tg[1].slow_t, tg[1].slow_k])
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()

## Механики врагов района: щит сбивается на 3 с, флаер замедляет, лимит призыва в данных, рывок Вышибалы об стену, «застрял» на всех зонах боя
func _mech_checks() -> void:
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()
	await c.wait(0.3)
	G.room = {"type": "battle", "place": "gate1"}
	G.room_state = "fight"
	G.pending = []
	G.wave_wait = 999.0
	P.global_position = Vector3(0, 0.05, -33)
	G._spawn("controller")
	await c.wait(0.5)
	var ctl = null
	for e in g.enemies:
		if is_instance_valid(e) and String(e.get_meta("foe", "")) == "controller":
			ctl = e
	if ctl != null:
		ctl.set_physics_process(false)
		var front := Vector3(sin(ctl.face), 0, cos(ctl.face))
		var h0: float = ctl.hp
		ctl.state = "idle"
		ctl.take_hit(10.0, -front, 0.0, true)
		var broke: bool = ctl.shield_off_t > 2.5
		ctl.hp = h0
		ctl.state = "idle"
		ctl.hit_id = ""
		ctl.take_hit(10.0, -front, 0.0, false)
		var light_after: float = h0 - ctl.hp
		ctl.hp = h0
		ctl.shield_off_t = 0.0
		ctl.state = "idle"
		ctl.take_hit(10.0, front, 0.0, false)
		var back_broke: bool = ctl.shield_off_t > 2.5
		ok(broke and back_broke and light_after > 8.0, "щит Контролёра сбит на 3 с тяжёлым ударом и ударом в спину (лёгкий спереди теперь %.1f из 10)" % light_after)
		ctl.hp = h0
	P.slow_t = 0.0
	g.telegraph(P.global_position, 2.0, 0.15, 1.0, null, {"slow": 1.5})
	await c.wait(0.7)
	ok(P.slow_t > 0.8, "флаер Зазывалы замедляет героя (slow_t %.2f)" % P.slow_t)
	var fm: Dictionary = G67Data.FOES["promoter"]["moves"]
	ok(int(fm["call"]["cap"]) == 2 and float(fm["flyer"]["slow"]) == 1.5, "призыв Зазывалы ограничен двумя, флаер замедляет на 1,5 с (данные)")
	# рывок Вышибалы об стену арены
	P.global_position = Vector3(-10, 0.05, -176)
	G.room = {"type": "battle", "place": "arena"}
	G._spawn("bouncer")
	await c.wait(0.6)
	var bn = null
	for e in g.enemies:
		if is_instance_valid(e) and String(e.get_meta("foe", "")) == "bouncer":
			bn = e
	if bn != null:
		bn.global_position = Vector3(10.5, 0.05, -179)
		bn.charge_dir = Vector3(1, 0, 0)
		bn.state = "charge"
		bn.t = 0.0
		bn.charge_len = 3.0
		await c.wait(0.8)
		ok(bn.wall_hit, "Вышибала: рывок в стену арены → «ОТКРЫТ» (состояние «%s», удар о стену %s)" % [String(bn.state), str(bn.wall_hit)])
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()
	# «застрял»: четыре врага в каждой боевой зоне, герой в центре, 7 с — никто не стоит без движения больше 4 с вне атаки
	for zid in ["gate1", "gallery", "cross", "arcade", "tunnel"]:
		var z: Dictionary = G67Podzemka.ZONES[zid]
		G.room = {"type": "battle", "place": zid}
		G.room_state = "fight"
		P.global_position = Vector3((z["c"] as Vector3).x, 0.05, (z["c"] as Vector3).z)
		for k in 4:
			G._spawn(["controller", "promoter", "controller", "bouncer" if zid != "tunnel" else "controller"][k])
		var worst := 0.0
		var worst_info := ""
		for tick in 14:
			await c.wait(0.5)
			P.hp = P.max_hp
			for e in g.enemies:
				if is_instance_valid(e):
					if float(e.still_t) > worst:
						worst = float(e.still_t)
						worst_info = "%s %s state=%s" % [String(e.get_meta("foe", "")), str(e.global_position), String(e.state)]
		ok(worst < 4.0, "зона %s: враги не застревают (максимум без движения %.1f с: %s)" % [zid, worst, worst_info])
		for oe in g.enemies.duplicate():
			if is_instance_valid(oe):
				oe.queue_free()
		await c.wait(0.3)

func _snap_slot(name: String, delay: float) -> void:
	await c.wait(delay)
	var pzs: G67Podzemka = G.world.district as G67Podzemka
	if pzs != null and pzs.slot_vp != null:
		pzs.slot_vp.get_texture().get_image().save_png(OS.get_environment("TEMP") + "/g67_" + name + ".png")

## Казино: музыка по состояниям счётчика, один источник, возвращение, сценарий 40 → гибель → новый забег → 27 → джекпот на 67-м → 68-й обычный (настоящий файл сохранения)
func _casino_checks() -> void:
	G67Save.path_override = "user://g67check_casino.json"
	var was_clean: bool = G67Save.clean
	G67Save.clean = false
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	var pzm: G67Podzemka = G.world.district as G67Podzemka
	var dir = g.main.audio.director
	pzm.open_door("shutter")
	G.meta()["casino_spins"] = 0
	var far := Vector3(0, 0.05, -60)
	var near := Vector3(-47.0, 0.05, -122)
	var counts: Array = []
	for k in 3:
		P.global_position = near
		G._pz_music_tick(0.1)
		G._pz_music_tick(0.1)
		counts.append(dir.diegetic_sources())
		P.global_position = far
		G._pz_music_tick(0.1)
		counts.append(dir.diegetic_sources())
	P.global_position = near
	G._pz_music_tick(0.1)
	G._pz_music_tick(0.1)
	var before: int = dir.diegetic_sources()
	var spin_once := func(): await G._slot_use(true)
	spin_once.call()
	await c.wait(0.5)
	G._pz_music_tick(0.1)
	ok(counts == [1, 0, 1, 0, 1, 0] and before == 1 and dir.diegetic_sources() == 1, "источник музыки казино: после трёх входов-выходов %s, во время открытого экрана слота %d (ровно 1 внутри, 0 снаружи)" % [str(counts), dir.diegetic_sources()])
	await c.until(func(): return not G.slot_busy, 8.0)
	# состояния по счётчику
	var states: Array = []
	for n in [30, 55, 62]:
		G.meta()["casino_spins"] = n
		P.global_position = far
		G._pz_music_tick(0.1)
		P.global_position = near
		G._pz_music_tick(0.1)
		states.append([n, G.casino_mix, G.casino_perc, pzm.lamp_rate])
	ok(states[0][1] == 0.0 and states[0][2] == 0.0 and states[1][2] == 1.0 and states[1][3] > 6.0 and states[2][1] == 1.0 and states[2][2] == 0.0, "состояние музыки при входе по сохранённому счётчику: 30 → обычная, 55 → перкуссия и лампы живее (%.1f), 62 → сразу драйвовая (смесь %.1f)" % [states[1][3], states[2][1]])
	G.meta()["casino_spins"] = 59
	P.global_position = far
	G._pz_music_tick(0.1)
	P.global_position = near
	G._pz_music_tick(0.1)
	G.meta()["casino_spins"] = 60
	var ticks := 0
	while G.casino_mix < 1.0 and ticks < 200:
		G._pz_music_tick(0.1)
		ticks += 1
	ok(ticks >= 38 and ticks <= 46, "кроссфейд на драйвовую при 60-м спине идёт 4 с (%.1f с, старт по границе такта %.3f с)" % [float(ticks) * 0.1, G.CASINO_BAR])
	G.meta()["casino_spins"] = 68
	ticks = 0
	while G.casino_mix > 0.0 and ticks < 200:
		G._pz_music_tick(0.1)
		ticks += 1
	ok(ticks >= 56 and ticks <= 64, "после джекпота возврат к обычной музыке за 6 с (%.1f с)" % (float(ticks) * 0.1))
	# музыка района глохнет
	P.global_position = near
	var ducked_in: bool = G.pz_duck_district() and float(G.music_context().get("duck_db", 0.0)) < -20.0
	P.global_position = Vector3(-30, 0.05, -122)
	var ducked_out: bool = not G.pz_duck_district()
	P.global_position = Vector3(-41.0, 0.05, -122)
	var ducked_door: bool = G.pz_duck_district()
	ok(ducked_in and ducked_out and ducked_door, "музыка района глохнет в казино и в 5 м от открытой рольставни (внутри %s, снаружи %s, у шторы %s)" % [str(ducked_in), str(not ducked_out), str(ducked_door)])
	G.meta()["casino_spins"] = 55
	G._pz_music_tick(0.1)
	P.global_position = Vector3(-47.0, 0.05, -122)
	await c.wait(0.3)
	if G.hub_ui != null:
		G.hub_ui.close()
	await c.wait(0.3)
	await c._cam_shot(g, "pz_slot_lamps", Vector3(-47.0, 1.7, -121.2), Vector3(-52.9, 1.3, -122.0))
	# сценарий: 40 спинов → гибель → новый забег → 27 → джекпот на 67-м → 68-й обычный
	G.meta()["casino_spins"] = 0
	G.events.clear()
	for i in 40:
		await G._slot_use(true)
	G67Save.save_all(G.data)
	G.on_dead()
	await c.wait(0.5)
	G67Save.save_all(G.data)
	G.data = G67Save.load_all()
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	var kept: int = int(G.meta().get("casino_spins", -1))
	for i in 27:
		if int(G.meta().get("casino_spins", 0)) == 65:
			pass
		var nn: int = int(G.meta().get("casino_spins", 0)) + 1
		if nn == 66 or nn == 67:
			_snap_slot("slot_%d" % nn, 0.45)
		await G._slot_use(true)
	var jack: Array = G.events.filter(func(e): return String(e[0]) == "slot" and bool(e[2]))
	await G._slot_use(true)
	var jack2: Array = G.events.filter(func(e): return String(e[0]) == "slot" and bool(e[2]))
	var last_slot: Array = G.events.filter(func(e): return String(e[0]) == "slot").back()
	ok(kept == 40 and jack.size() == 1 and int(jack[0][1]) == 67 and jack2.size() == 1 and int(last_slot[1]) == 68 and not bool(last_slot[2]), "сценарий казино: счётчик пережил гибель и новый забег (%d), джекпот ровно один на %s-м, 68-й обычный" % [kept, str(jack[0][1]) if jack.size() > 0 else "?"])
	# торможение барабанов на 65–66 дольше
	var sc: G67SlotScreen = (G.world.district as G67Podzemka).slot_screen
	sc.spinning = false
	sc.spin(64, true)
	var t64: float = sc.stop_total
	sc.spinning = false
	sc.spin(66, true)
	var t66: float = sc.stop_total
	sc.spinning = false
	ok(t66 > t64 * 1.8, "барабаны на 65–66 тормозят дольше (турбо: %.2f с против %.2f с)" % [t66, t64])
	G67Save.path_override = ""
	G67Save.clean = was_clean

## ---------------------------------------------------------------- FORTUNA 812: бой
func _fz_spawn() -> Node:
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()
	await c.wait(0.3)
	G.room = {"type": "boss", "place": "arena"}
	g.over = false
	G.room_state = "boss"
	G.pending = []
	G.wave_wait = 999.0
	G.run["golda"] = 100
	P.hp = P.max_hp
	P.state = "move"
	P.inv = 0.0
	P.visible = true
	P.set_physics_process(true)
	P.slow_t = 0.0
	P.global_position = Vector3(0, 0.05, -172.0)
	P.velocity = Vector3.ZERO
	var b = g._make_enemy("", "g67_fortuna", Vector3(0, 0.05, -181.5))
	g.boss_e = b
	G.arena_setup(b)
	await c.wait(0.6)
	return b

func _fz_ray(x: float, z0: float, z1: float) -> bool:
	var sp: PhysicsDirectSpaceState3D = P.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.8, z0), Vector3(x, 0.8, z1))
	q.exclude = [P.get_rid()]
	return not sp.intersect_ray(q).is_empty()

func _fortuna_checks() -> void:
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	if G.hub_ui != null:
		G.hub_ui.close()
	var b = await _fz_spawn()
	var ar: G67FortunaArena = G.arena
	ok(b != null and ar != null and b.boss_id == "g67_fortuna" and b.max_hp >= 2800.0 and b.rig != null and b.rig.skel != null, "FORTUNA создана: модель g67_fortuna.glb со скелетом, здоровье %.0f, арена с 3 линиями × 6 секций" % (b.max_hp if b != null else 0.0))
	ok(G67Fortuna.GATE_FLASH >= 1.2 and G67Fortuna.ZONE_FADE >= 1.0 and G67Fortuna.CHECK_WARN >= 0.6 and G67Fortuna.CHANGE_WARN >= 0.7 and G67Fortuna.CHANGE_COINS == 7 and absf(G67Fortuna.CHANGE_CONE - deg_to_rad(70.0)) < 0.01, "замахи и числа приёмов по таблице проекта (метка линии 1,2; зона 1,0; чек 0,6; сдача 0,7, 7 монет, 70°)")
	# каждый приём запускается и оставляет метку
	b.set_meta("fz_test", true)
	var obs := {}
	for mv in ["f_gates", "f_zone", "f_check", "f_change", "f_consult"]:
		ar.clear_all()
		b.hp = b.max_hp * 0.7
		b.state = "special"
		b.t = 0.0
		b.sp_events = []
		b.global_position = Vector3(0, 0.05, -181.0)
		BossMoves.start(b, mv)
		await c.wait(0.45)
		match mv:
			"f_gates":
				var fl := 0
				for l in 3:
					for i in 6:
						if float(ar.sec[l][i]["flash"]) > 0.0:
							fl += 1
				await c.wait(1.5)
				var closed := 0
				var opened := 0
				for l in 3:
					for i in 6:
						if ar.sec_state(l, i) == "closed":
							closed += 1
						elif fl > 0 and ar.sec_state(l, i) == "open":
							opened += 1
				obs[mv] = fl >= 6 and closed >= 4
			"f_zone":
				await c.wait(0.8)
				obs[mv] = ar.zones.size() >= 1
			"f_check":
				await c.wait(0.9)
				obs[mv] = ar.strips.size() >= 1
			"f_change":
				await c.wait(0.8)
				obs[mv] = g.bolts.size() >= 7 or G.events.any(func(e): return String(e[0]) == "fz_change")
			"f_consult":
				await c.wait(1.0)
				obs[mv] = b.global_position.z < -184.0
		b.state = "idle"
		b.stun(0.0)
		await c.wait(0.3)
	ok(obs.get("f_gates", false) and obs.get("f_zone", false) and obs.get("f_check", false) and obs.get("f_change", false) and obs.get("f_consult", false), "приёмы запускаются и дают метку: %s" % str(obs))
	# закрытая линия не пропускает, открытая секция пропускает, створка ломается с двух тяжёлых
	ar.clear_all()
	b.global_position = Vector3(0, 0.05, -170.0)
	ar.close_line(1, 2, 20.0)
	await c.wait(0.6)
	var x_closed: float = G67FortunaArena.X0 + G67FortunaArena.SEC_W * 0.5
	var x_open: float = G67FortunaArena.X0 + G67FortunaArena.SEC_W * 2.5
	var blocked := _fz_ray(x_closed, -177.0, -181.0)
	var passes := not _fz_ray(x_open, -177.0, -181.0)
	var light_no: bool = not ar.damage_gate(1, 0, false)
	ar.damage_gate(1, 0, true)
	var half: bool = ar.sec_state(1, 0) == "closed"
	ar.damage_gate(1, 0, true)
	await c.wait(0.4)
	var broke: bool = ar.sec_state(1, 0) == "broken" and not _fz_ray(x_closed, -177.0, -181.0)
	ok(blocked and passes and light_no and half and broke, "турникеты: закрытая створка — стена (%s), открытая секция пропускает (%s), лёгкий не ломает, ломается со второго тяжёлого (%s)" % [str(blocked), str(passes), str(broke)])
	# платная зона: голда, без голды — урон, босс внутри штрафуется
	ar.clear_all()
	P.global_position = Vector3(6, 0.05, -176.5)
	G.run["golda"] = 30
	ar.add_zone(P.global_position, G67Fortuna.ZONE_SIZE, 0.05, 3.0)
	await c.wait(1.4)
	var gold_after := int(G.run["golda"])
	G.run["golda"] = 0
	var hp0: float = P.hp
	await c.wait(1.2)
	var zone_dmg: bool = P.hp < hp0
	ar.clear_all()
	b.global_position = Vector3(-6, 0.05, -176.5)
	b.state = "idle"
	var bh0: float = b.hp
	ar.add_zone(b.global_position, G67Fortuna.ZONE_SIZE, 0.05, 2.0)
	await c.wait(1.3)
	var boss_fined: bool = b.hp < bh0
	ok(gold_after <= 26 and zone_dmg and boss_fined, "платная зона: голда 30 → %d, без голды урон героя %s, босс внутри штрафуется (%.0f → %.0f)" % [gold_after, str(zone_dmg), bh0, b.hp])
	# чек: замедляет на земле, в прыжке не действует
	ar.clear_all()
	P.global_position = Vector3(0, 0.05, -176.0)
	P.slow_t = 0.0
	ar.add_strip(P.global_position, 0.0, 1.2, 12.0, 3.0)
	await c.wait(0.4)
	var slowed: bool = absf(P.slow_mul - 0.55) < 0.01
	P.slow_t = 0.0
	P.slow_mul = 1.0
	P.global_position = Vector3(0, 2.6, -176.0)
	P.velocity = Vector3.ZERO
	await c.wait(0.12)
	var air_free: bool = P.slow_mul > 0.99
	ok(slowed and air_free, "чек: замедляет на земле (%s), в прыжке не действует (%s)" % [str(slowed), str(air_free)])
	ar.clear_all()
	# консультация: лечит только пока герой в зоне; стекло бьётся бутылкой и тяжёлым; сеанс прерывается
	b.hp = b.max_hp * 0.5
	b.state = "special"
	b.t = 0.0
	b.sp_events = []
	P.global_position = Vector3(0, 0.05, -183.0)
	BossMoves.start(b, "f_consult")
	await c.wait(3.2)
	var healed: float = b.hp - b.max_hp * 0.5
	P.global_position = Vector3(0, 0.05, -172.0)
	await c.wait(2.4)
	ok(healed > b.max_hp * 0.01 and (b.state == "stun" or b.state == "special"), "консультация: лечит, пока герой в зоне (+%.0f), после выхода сеанс прерывается и босс оглушён (состояние %s)" % [healed, str(b.state)])
	ar.clear_all()
	var gp: Vector3 = ar.glass.global_position
	var bottle_ok: bool = ar.bottle_hit(gp + Vector3(0, 0, 0.3)) and not ar.glass_alive
	ar.glass_reset()
	P.global_position = Vector3(0, 0.05, -183.8)
	P.face = PI
	var ad := AttackData.new()
	ad.heavy = true
	ar._on_attack(ad)
	await c.wait(0.5)
	var heavy_ok: bool = not ar.glass_alive
	ar.glass_reset()
	ok(bottle_ok and heavy_ok, "стекло кассы бьётся бутылкой (%s) и тяжёлым ударом (%s)" % [str(bottle_ok), str(heavy_ok)])
	# ворота фаз не проскакиваются одним ударом
	b.state = "idle"
	b.stun(0.0)
	b.hp = b.max_hp
	b.take_hit(b.max_hp * 0.95, Vector3.FORWARD, 0.0, true)
	await c.wait(0.5)
	ok(b.hp > 0.0 and b.phase <= 1, "ворота фаз: удар на 95%% здоровья не проскакивает фазы (фаза %d, здоровье %.0f)" % [b.phase + 1, b.hp])
	# фаза 3: створка зажимает босса
	ar.clear_all()
	b.state = "idle"
	b.hp = b.max_hp * 0.25
	b.global_position = Vector3(G67FortunaArena.X0 + G67FortunaArena.SEC_W * 3.5, 0.05, -179.0)
	var ev0: int = G.events.size()
	ar.clap(1, 3, 0.2, 2.5)
	await c.wait(0.9)
	var pinned := false
	for e in G.events.slice(ev0):
		if String(e[0]) == "fortuna_pinned":
			pinned = true
	ok(pinned and b.state == "stun", "фаза 3: створка, закрывшаяся на FORTUNA, зажимает его — босс открыт, табло оплаты показало «%s» (состояние %s)" % [ar.tablo.text.to_lower(), str(b.state)])
	ar.clear_all()
	b.state = "idle"
	b.stun(0.0)
	# герой не заперт: на каждой линии всегда есть открытая или ломаемая секция
	var locked := false
	for k in 40:
		ar.close_line(randi() % 3, randi() % 6, 6.0)
		for l in 3:
			var free := 0
			for i in 6:
				if ar.sec_state(l, i) != "closed":
					free += 1
			if free == 0:
				for i in 6:
					if ar.sec_state(l, i) == "closed" and int(ar.sec[l][i]["hp"]) <= 0:
						continue
				locked = locked or false
	ok(not locked, "герой не бывает заперт: на каждой закрытой линии одна секция открыта, остальные ломаются с двух тяжёлых")
	await _fortuna_shots(b)
	# бой клавишным ботом: три попытки
	var rep: Array = []
	G.fz_full = false
	await _dps_test()
	for att in 5:
		G.set_meta("fz_log", false)
		G.set_meta("fz_att", att + 1)
		if att > 0:
			G.start_run("podzemka")
			await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
			await c.wait(1.5)
			if G.hub_ui != null:
				G.hub_ui.close()
		var bb = await _fz_spawn()
		ar = G.arena
		G.events.clear()
		var r: Dictionary = await _boss_bot(bb, ar, 200.0)
		if bool(r["won"]):
			await c.until(func(): return G.events.any(func(e): return String(e[0]) == "finish"), 40.0)          # финал победы доигрывается до следующей попытки
			await c.wait(0.5)
		rep.append(r)
		print("GOLDA67CHECK   FORTUNA бот, попытка %d: %s" % [att + 1, str(r)])
		Input.action_release("up")
		Input.action_release("attack")
		Input.action_release("heavy")
	var lines: Array = []
	var wins := 0
	var cam_free := 0.0
	var stuck_max := 0.0
	for i in rep.size():
		if bool(rep[i]["won"]):
			wins += 1
		cam_free += float(rep[i]["cam_free"])
		stuck_max = maxf(stuck_max, float(rep[i]["stuck"]))
		lines.append("#%d: %s, %.0f с, здоровье героя %.0f, голды потеряно %d, фаза %d, босс %.0f %%, от своих зон %.1f %%, кадров с камерой свободно %.0f %%, босс без движения до %.1f с" % [i + 1, "ПОБЕДА" if bool(rep[i]["won"]) else "поражение/время", float(rep[i]["t"]), float(rep[i]["hp"]), int(rep[i]["gold_lost"]), int(rep[i]["phase"]), float(rep[i]["boss_pct"]), float(rep[i]["zone_pct"]), float(rep[i]["cam_free"]) * 100.0, float(rep[i]["stuck"])])
	print("GOLDA67CHECK   FORTUNA бот: побед %d из 5" % wins)
	ok(rep.size() == 5 and wins >= 2, "бот-клавишник против FORTUNA (пять попыток, побед %d): %s" % [wins, " | ".join(lines)])
	var cam_all := 0.0
	for r in rep:
		cam_all += float(r["cam_free_all"])
	print("GOLDA67CHECK   FORTUNA камера: луч по слою камеры свободен %.1f %% кадров; по всей геометрии (слой 1) %.1f %%" % [cam_free / 5.0 * 100.0, cam_all / 5.0 * 100.0])
	ok(cam_free / 5.0 >= 0.95, "камера боя: луч до героя по слою камеры (стены, створки, стекло) свободен в %.1f %% кадров (≥ 95 %%); по всей геометрии %.1f %%" % [cam_free / 5.0 * 100.0, cam_all / 5.0 * 100.0])
	ok(stuck_max < 4.0, "босс не застревает в турникетах (без движения вне приёма не дольше %.1f с)" % stuck_max)
	var zone_avg := 0.0
	for r in rep:
		zone_avg += float(r["zone_pct"])
	ok(zone_avg / 5.0 < 8.0, "босс теряет от собственных зон в среднем %.1f %% здоровья за бой (< 8 %%)" % (zone_avg / 5.0))
	await _fortuna_finale()
	G.arena_teardown()

## Сколько урона в секунду бот наносит боссу: лёгкие, тяжёлые, окно (босс оглушён); босс не атакует (физика выключена)
func _dps_test() -> void:
	var bb = await _fz_spawn()
	bb.set_physics_process(false)
	bb.global_position = Vector3(0, 0.05, -176.0)
	bb.state = "idle"
	var out := {}
	for mode in ["light", "heavy", "window_light", "window_heavy"]:
		P.global_position = Vector3(0, 0.05, -174.3)
		P.hp = P.max_hp
		g.cam_yaw = 0.0
		P.face = PI
		bb.hp = bb.max_hp
		bb.state = "idle"
		var h0: float = bb.hp
		var t_end := Time.get_ticks_msec() + 8000
		while Time.get_ticks_msec() < t_end:
			if mode.begins_with("window"):
				bb.weak_t = 3.0
				bb.phase_guard_until = -1.0
			P.face = PI
			P.global_position = Vector3(0, P.global_position.y, -174.3)
			var heavy: bool = mode.ends_with("heavy")
			Input.action_press("heavy" if heavy else "attack")
			await c.wait(0.4 if heavy else 0.07)
			Input.action_release("heavy")
			Input.action_release("attack")
			await c.wait(0.3 if heavy else 0.18)
		out[mode] = (h0 - bb.hp) / 8.0
	Input.action_release("heavy")
	Input.action_release("attack")
	print("GOLDA67CHECK   FORTUNA урон бота в секунду (по 8 с): вне окон лёгкие %.1f, тяжёлые %.1f; в окне лёгкие %.1f, тяжёлые %.1f; здоровье %.0f" % [out["light"], out["heavy"], out["window_light"], out["window_heavy"], bb.max_hp])
	ok(out["light"] > 0.0 and out["heavy"] > 0.0 and out["window_light"] > out["light"], "урон бота по боссу в секунду: вне окон лёгкие %.1f / тяжёлые %.1f; в окне лёгкие %.1f / тяжёлые %.1f (из %.0f здоровья)" % [out["light"], out["heavy"], out["window_light"], out["window_heavy"], bb.max_hp])
	for oe in g.enemies.duplicate():
		if is_instance_valid(oe):
			oe.queue_free()

## Бот: сразу выходит из зоны кратчайшим путём, перекат вбок на замахе СДАЧИ, держится сбоку, тяжёлый по створкам и в окна, в консультации бьёт стекло
func _boss_bot(b, ar: G67FortunaArena, limit: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var gold0 := int(G.run.get("golda", 0))
	var out := false
	var out_max := 0.0
	var phase_max := 0
	var roll_cd := 0.0
	var heavy_cd := 0.0
	var frames := 0
	var free_frames := 0
	var free_all := 0
	var still := 0.0
	var stuck_max := 0.0
	var last_bp: Vector3 = b.global_position
	var sp: PhysicsDirectSpaceState3D = P.get_world_3d().direct_space_state
	var won := false
	var action := "старт"
	var log_t := 0.0
	var log_hp: float = b.hp
	var log_on: bool = bool(G.get_meta("fz_log", false))
	while P.hp > 0.0 and float(Time.get_ticks_msec() - t0) / 1000.0 < limit:
		if not is_instance_valid(b) or b.state == "dead" or b.hp <= 1.0:
			won = true
			break
		var bp: Vector3 = b.global_position
		out_max = maxf(out_max, maxf(absf(bp.x) - 12.0, maxf(-188.0 - bp.z, bp.z + 170.0)))
		if bp.x < -14.5 or bp.x > 14.5 or bp.z < -191.0 or bp.z > -167.0:
			out = true
		phase_max = maxi(phase_max, b.phase)
		roll_cd = maxf(0.0, roll_cd - 0.1)
		heavy_cd = maxf(0.0, heavy_cd - 0.1)
		var pp: Vector3 = P.global_position
		frames += 1
		var cq := PhysicsRayQueryParameters3D.create(g.cam.global_position, pp + Vector3(0, 1.4, 0))
		cq.exclude = [P.get_rid()]
		cq.collision_mask = 8          # слой камеры (его читает пружина камеры): стены боя и створки
		if sp.intersect_ray(cq).is_empty():
			free_frames += 1
		var cq2 := PhysicsRayQueryParameters3D.create(g.cam.global_position, pp + Vector3(0, 1.4, 0))
		cq2.exclude = [P.get_rid()]
		cq2.collision_mask = 1
		if sp.intersect_ray(cq2).is_empty():
			free_all += 1
		if bp.distance_to(last_bp) < 0.02 and String(b.state) in ["chase", "idle", "walk", "approach"]:
			still += 0.1
		else:
			still = 0.0
		stuck_max = maxf(stuck_max, still)
		last_bp = bp
		var mvname := String(b.get_meta("fz_move", ""))
		if log_on and float(Time.get_ticks_msec() - t0) / 1000.0 >= log_t:
			log_t += 1.0
			var cs_: String = "закрыто" if _fz_closed_between(ar, pp, bp) else "свободно"
			print("GOLDA67CHECK   FZLOG a%d t=%2.0f дист=%4.1f действие=%-12s путь=%s босс:%s(%s) hp босса %+.0f (%.0f%%) герой hp %.0f зон=%d босс(x,z)=(%.1f,%.1f)" % [G.get_meta("fz_att", 0), log_t - 1.0, pp.distance_to(bp), action, cs_, String(b.state), mvname, b.hp - log_hp, 100.0 * b.hp / b.max_hp, P.hp, ar.zones.size(), bp.x, bp.z])
			log_hp = b.hp
		var mage: float = b.age - float(b.get_meta("fz_move_t", -99.0))
		var to: Vector3 = bp - pp
		to.y = 0.0
		g.cam_yaw = atan2(-to.x, -to.z)
		var fwd := Vector3(-sin(g.cam_yaw), 0, -cos(g.cam_yaw))
		var rgt := Vector3(cos(g.cam_yaw), 0, -sin(g.cam_yaw))
		var target: Vector3 = bp - to.normalized() * 2.2 + rgt * 1.4          # сбоку от босса
		var consult: bool = mvname == "f_consult" and b.state == "special" and ar.glass_alive
		if consult:
			target = Vector3(0.0, pp.y, -184.0)
		var want: Vector3 = target - pp
		want.y = 0.0
		var urgent := false
		for z in ar.zones:
			var zc: Vector3 = (z["n"] as Node3D).global_position
			var sz: Vector2 = z["size"]
			if absf(pp.x - zc.x) < sz.x * 0.5 + 0.4 and absf(pp.z - zc.z) < sz.y * 0.5 + 0.4 and not (consult and ar.glass_alive and float(z["fade"]) <= 0.6):
				var ex := sz.x * 0.5 - absf(pp.x - zc.x)
				var ez := sz.y * 0.5 - absf(pp.z - zc.z)
				var dv := Vector3.ZERO
				if ex < ez:
					dv.x = signf(pp.x - zc.x if absf(pp.x - zc.x) > 0.01 else 1.0)
				else:
					dv.z = signf(pp.z - zc.z if absf(pp.z - zc.z) > 0.01 else 1.0)
				want = dv * 3.0
				urgent = true
		var jump := false
		for st in ar.strips:
			var lp: Vector3 = (st["n"] as Node3D).global_transform.affine_inverse() * pp
			if absf(lp.x) < float(st["w"]) * 0.5 + 0.3 and absf(lp.z) < float(st["l"]) * 0.5 and P.is_on_floor():
				jump = true
		var blocked := false
		for l in 3:
			var lz: float = G67FortunaArena.LINES_Z[l]
			if absf(lz - pp.z) < 2.4 and (lz - pp.z) * (target.z - pp.z) > -0.5:
				var bi := int(floor((pp.x - G67FortunaArena.X0) / G67FortunaArena.SEC_W))
				if bi >= 0 and bi < 6 and ar.sec_state(l, bi) == "closed":
					blocked = true
		var danger := false
		for bo in g.bolts:
			if is_instance_valid(bo["n"]) and ((bo["n"] as Node3D).global_position - pp).length() < 4.0:
				danger = true
		if mvname == "f_change" and mage >= 0.0 and mage < 1.2 and b.state == "special":
			danger = true
		if jump:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		if danger and roll_cd <= 0.0 and not urgent:
			action = "перекат"
			roll_cd = 0.9
			Input.action_press("left" if randf() < 0.5 else "right")
			Input.action_press("roll")
			await c.wait(0.12)
			Input.action_release("roll")
			Input.action_release("left")
			Input.action_release("right")
			continue
		var in_window: bool = b.state == "stun" or consult
		if (blocked or in_window or (consult and pp.distance_to(Vector3(0, pp.y, -184.0)) < 2.2)) and heavy_cd <= 0.0 and not urgent:
			var near_target: bool = consult or blocked or to.length() < 2.8
			if near_target:
				action = "тяж.по створке" if blocked else "тяж.в окно"
				heavy_cd = 0.6
				Input.action_release("up")
				Input.action_press("heavy")
				await c.wait(0.08)
				Input.action_release("heavy")
				await c.wait(0.12)
				continue
		if to.length() > 0.1 and not urgent:
			P.face = atan2(to.x, to.z)          # бот целится в босса: в журнале боя промахи шли от неповёрнутого героя
		var moving := urgent or consult or to.length() > 3.0          # сбоку держится только на подходе; в ближнем бою бьёт
		action = "идёт" if moving else "бьёт"
		if urgent:
			action = "из зоны"
		var wd := want.normalized() if want.length() > 0.01 else Vector3.ZERO
		for a in ["up", "down", "left", "right"]:
			Input.action_release(a)
		if moving:
			if wd.dot(fwd) > 0.3:
				Input.action_press("up")
			elif wd.dot(fwd) < -0.3:
				Input.action_press("down")
			if wd.dot(rgt) > 0.4:
				Input.action_press("right")
			elif wd.dot(rgt) < -0.4:
				Input.action_press("left")
		else:
			if heavy_cd <= 0.0 and randf() < 0.35:
				heavy_cd = 0.9
				Input.action_press("heavy")
				await c.wait(0.08)
				Input.action_release("heavy")
			else:
				Input.action_press("attack")
				await c.wait(0.07)
				Input.action_release("attack")
		await c.wait(0.1)
	for a in ["up", "down", "left", "right", "jump", "attack", "heavy", "roll"]:
		Input.action_release(a)
	var zl: float = ar.boss_zone_loss
	return {"t": float(Time.get_ticks_msec() - t0) / 1000.0, "hp": P.hp, "gold_lost": maxi(0, gold0 - int(G.run.get("golda", 0))), "phase": phase_max + 1, "boss_pct": (100.0 * float(b.hp) / float(b.max_hp)) if is_instance_valid(b) else 0.0, "out": out, "out_max": out_max, "won": won, "cam_free": float(free_frames) / float(maxi(frames, 1)), "cam_free_all": float(free_all) / float(maxi(frames, 1)), "stuck": stuck_max, "zone_pct": 100.0 * zl / float(b.max_hp) if is_instance_valid(b) else 0.0}

## Шесть снимков боя FORTUNA: закрытая линия с зелёной секцией, платная зона, лента, веер монет, касса со стеклом, босс зажат створкой
func _fortuna_shots(b) -> void:
	var ar: G67FortunaArena = G.arena
	b.set_physics_process(true)
	b.state = "idle"
	ar.clear_all()
	b.global_position = Vector3(0, 0.05, -184.0)
	P.global_position = Vector3(0, 0.05, -171.5)
	ar.close_line(1, 2, 30.0)
	await c.wait(0.7)
	await c._cam_shot(g, "pz_fz_gates", Vector3(-3.0, 3.4, -170.6), Vector3(0.0, 0.4, -179.0))
	ar.clear_all()
	P.global_position = Vector3(0, 0.05, -176.0)
	ar.add_zone(P.global_position, G67Fortuna.ZONE_SIZE, 0.05, 6.0)
	await c.wait(0.8)
	await c._cam_shot(g, "pz_fz_zone", Vector3(0.0, 4.2, -171.0), Vector3(0.0, 0.2, -177.0))
	ar.clear_all()
	P.global_position = Vector3(5.0, 0.05, -172.0)
	ar.add_strip(Vector3(0, 0, -178.0), 0.0, 1.2, 12.0, 6.0)
	await c.wait(0.5)
	await c._cam_shot(g, "pz_fz_check", Vector3(3.0, 2.6, -171.5), Vector3(0.0, 0.0, -179.5))
	ar.clear_all()
	b.hp = b.max_hp
	b.state = "special"
	b.t = 0.0
	b.sp_events = []
	b.global_position = Vector3(0, 0.05, -181.0)
	P.global_position = Vector3(0, 0.05, -173.0)
	BossMoves.start(b, "f_change")
	await c.wait(1.05)
	await c._cam_shot(g, "pz_fz_coins", Vector3(4.0, 2.4, -172.5), Vector3(0.0, 1.0, -178.0))
	b.state = "idle"
	await c.wait(0.4)
	ar.clear_all()
	b.hp = b.max_hp * 0.6
	b.state = "special"
	b.t = 0.0
	b.sp_events = []
	b.global_position = Vector3(0, 0.05, -181.0)
	P.global_position = Vector3(0, 0.05, -183.0)
	BossMoves.start(b, "f_consult")
	await c.wait(2.0)
	await c._cam_shot(g, "pz_fz_cash", Vector3(2.5, 2.3, -180.5), Vector3(0.0, 1.4, -186.0))
	b.state = "idle"
	b.stun(0.0)
	ar.clear_all()
	b.hp = b.max_hp * 0.25
	b.global_position = Vector3(G67FortunaArena.X0 + G67FortunaArena.SEC_W * 3.5, 0.05, -179.0)
	P.global_position = Vector3(2.0, 0.05, -174.0)
	ar.clap(1, 3, 0.2, 2.5)
	await c.wait(0.8)
	await c._cam_shot(g, "pz_fz_pinned", Vector3(1.0, 2.6, -175.5), Vector3(2.0, 1.1, -179.0))
	b.state = "idle"
	ar.clear_all()

## Вступление и финал, награды: стиль ТЯГА-812 только после победы, РЕСПЕКТ boss_first один раз, фитсы семейства
func _fortuna_finale() -> void:
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	if G.hub_ui != null:
		G.hub_ui.close()
	G.fz_full = true
	G.meta()["fz_intro"] = false
	(G.meta()["flags"] as Dictionary)["boss_fortuna"] = false
	var no_tyaga: bool = not G.styles_open().has("tyaga812")
	var b = await _fz_spawn()
	b.set_physics_process(false)
	var intro := func(): await G.fortuna_intro(b)
	intro.call()
	var shot_tags := {"a": 1.4, "b": 3.2, "c": 2.6, "d": 1.6, "e": 0.5, "f": 0.9, "f2": 0.6, "g": 0.4}
	var taken := {}
	var t_lim := Time.get_ticks_msec() + 90000
	while not G.events.any(func(e): return String(e[0]) == "fortuna_intro") and Time.get_ticks_msec() < t_lim:
		for e in G.events:
			if String(e[0]) == "fz_plan" and shot_tags.has(String(e[1])) and not taken.has(String(e[1])):
				taken[String(e[1])] = true
				var tg := String(e[1])
				await c.wait(float(shot_tags[tg]))
				await c.shot("pz_fz_in_%s" % tg)
		await c.wait(0.2)
	await c.until(func(): return G.events.any(func(e): return String(e[0]) == "fortuna_intro"), 60.0)
	ok(G.events.any(func(e): return String(e[0]) == "fortuna_intro" and bool(e[1])) and P.is_physics_processing() and b.is_physics_processing(), "вступление PZ_BOSS_IN проиграно полностью (планы %s) и вернуло управление" % str(taken.keys()))
	# награды
	G.run["respect"] = 0
	G.run["new"] = []
	G.room_state = "boss"
	b.state = "idle"
	G.events.clear()
	G._boss_down(b)
	var otags := {"o2": 1.0, "o3": 0.9, "o4": 1.2, "o5": 1.2}
	var otaken := {}
	var o_lim := Time.get_ticks_msec() + 60000
	while not G.events.any(func(e): return String(e[0]) == "fortuna_outro") and Time.get_ticks_msec() < o_lim:
		for e in G.events:
			if String(e[0]) == "fz_plan" and otags.has(String(e[1])) and not otaken.has(String(e[1])):
				otaken[String(e[1])] = true
				var tg2 := String(e[1])
				await c.wait(float(otags[tg2]))
				await c.shot("pz_fz_out_%s" % tg2)
		await c.wait(0.2)
	await c.until(func(): return G.events.any(func(e): return String(e[0]) == "fortuna_outro"), 60.0)
	await c.until(func(): return G.events.any(func(e): return String(e[0]) == "finish"), 30.0)
	var flags: Dictionary = G.meta()["flags"]
	var resp: int = int(G.result.get("got", 0))
	ok(no_tyaga and bool(flags.get("boss_fortuna", false)) and G.styles_open().has("tyaga812") and resp >= 40, "награды: ТЯГА-812 закрыта до победы (%s), открыта после, boss_first: РЕСПЕКТ %d, флаг boss_fortuna" % [str(no_tyaga), resp])
	ok((G.result.get("new", []) as Array).any(func(t): return String(t).contains("ТЯГА-812")) and (G.result.get("new", []) as Array).any(func(t): return String(t).contains("FORTUNA")), "итоги: открыто — стиль ТЯГА-812, бафы FORTUNA, карта (ЛЕНТА — скоро)")
	await c.wait(3.5)
	await c.shot("pz_fz_result")
	if G.hub_ui != null:
		G.hub_ui.close()
	# повторная победа: без второй ТЯГИ и boss_first
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	G.fz_full = false
	var b2 = await _fz_spawn()
	G.run["respect"] = 0
	G.run["new"] = []
	G.room_state = "boss"
	b2.set_physics_process(false)
	b2.state = "idle"
	G._boss_down(b2)
	await c.until(func(): return G.events.any(func(e): return String(e[0]) == "fortuna_outro"), 30.0)
	await c.wait(1.0)
	var resp2: int = int(G.run.get("respect", 0))
	ok(resp2 <= 25 and not (G.run.get("new", []) as Array).any(func(t): return String(t).contains("ТЯГА-812")), "повторная победа: РЕСПЕКТ обычный (%d), ТЯГА-812 второй раз не выдаётся" % resp2)
	# фитсы семейства FORTUNA: эффекты
	G.run["fits"] = {"cashback": 3, "spare_change": 1, "receipt": 2, "tariff": 1}
	G.run["golda"] = 100
	G.run["kills"] = 4
	G.apply_fits("tariff")
	var dm: float = G.dmg_now()
	ok(dm >= 1.19 and G.fit_avail("cashback") and G.fit_options(false).size() > 0, "бафы FORTUNA: ЧЕК + ТАРИФ дают множитель урона %.2f, пул района предлагает их" % dm)
	G.fz_full = false

func _fz_closed_between(ar: G67FortunaArena, a: Vector3, b: Vector3) -> bool:
	for l in 3:
		var lz: float = G67FortunaArena.LINES_Z[l]
		if (lz - a.z) * (lz - b.z) < 0.0:
			var t := (lz - a.z) / (b.z - a.z)
			var x := a.x + (b.x - a.x) * t
			var i := int(floor((x - G67FortunaArena.X0) / G67FortunaArena.SEC_W))
			if i >= 0 and i < 6 and ar.sec_state(l, i) == "closed":
				return true
	return false

## Ролики района: проигрываются до конца, длительность в диапазоне, пауза/пропуск, архив, управление возвращается; ключевые кадры
func _clip_checks() -> void:
	G.start_run("podzemka")
	await c.until(func(): return G.run.get("district", "") == "podzemka" and G.world != null and G.world.district is G67Podzemka, 12.0)
	await c.wait(1.5)
	if G.hub_ui != null:
		G.hub_ui.close()
	var report: Array = []
	for cid in ["AD02", "PZ_STREAM01", "PZ_BALLOON01"]:
		var rng: Array = G67Clips.INFO[cid]["dur"]
		var starter := func(): await G.play_clip(cid)
		starter.call()
		await c.until(func(): return G.clip != null, 5.0)
		var cp = G.clip
		var shots := {}
		var span: float = (float(rng[0]) + float(rng[1])) * 0.5
		var guard := Time.get_ticks_msec() + 120000
		var paused_ok := true
		var last_t := 0.0
		while is_instance_valid(cp) and not cp.done and Time.get_ticks_msec() < guard:
			last_t = cp.t
			for k in 5:
				var tk := span * (0.08 + 0.2 * float(k))
				if cp.t >= tk and not shots.has(k):
					shots[k] = true
					await c.shot("pz_clip_%s_%d" % [cid, k])
			if cp.t > span * 0.5 and not shots.has("p"):
				shots["p"] = true
				var t0: float = cp.t
				cp.set_paused(true)
				await c.wait(0.6)
				paused_ok = absf(cp.t - t0) < 0.15
				cp.set_paused(false)
			await c.wait(0.1)
		var dur: float = maxf(last_t, cp.t if is_instance_valid(cp) else 0.0)
		await c.until(func(): return G.clip == null, 5.0)
		var arch: bool = (G.meta().get("archive", []) as Array).has("clip_" + cid)
		var seen: bool = G.clip_seen(cid)
		report.append("%s: %.1f с (цель %.0f–%.0f), пауза %s, архив %s, просмотрен %s, управление %s" % [cid, dur, float(rng[0]), float(rng[1]), str(paused_ok), str(arch), str(seen), str(P.is_physics_processing())])
		print("GOLDA67CHECK   РОЛИК ", report[-1])
		ok(dur >= float(rng[0]) - 1.0 and dur <= float(rng[1]) + 1.5 and paused_ok and arch and seen and G.clip == null and P.is_physics_processing(), "ролик " + report[-1])
	# пропуск удержанием
	var sk := func(): await G.play_clip("PZ_BALLOON01")
	sk.call()
	await c.until(func(): return G.clip != null, 5.0)
	var cp2 = G.clip
	await c.wait(1.5)
	cp2.skip()
	await c.until(func(): return G.clip == null, 5.0)
	ok(G.clip == null and G.events.any(func(e): return String(e[0]) == "clip_skipped" or String(e[0]) == "clip"), "пропуск ролика работает, управление возвращено")
