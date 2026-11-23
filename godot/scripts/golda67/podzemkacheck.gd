## Проверки района 2 «ПОДЗЕМКА» (этап 1): запускается из golda67check ключом `--g67-pz` (checks.cjs: podzemka).
## Мир строится, герой проходит ногами все помещения, нет дыр наружу, маршруты по гарантиям, забег доходит до итогов,
## спуск закрыт до победы над Мишей, сохранение района переживает выход, замер длин и кадра.
class_name PodzemkaCheck
extends RefCounted

var c            # golda67check
var g
var G: Golda67
var P

## хребет и ветки: списки путевых точек (x, z)
const RIDGE := [[0, 2], [0, -8], [0, -20], [0, -35], [0, -52], [0, -79], [0, -100], [0, -122], [0, -140], [0, -160], [0, -168], [0, -179]]
const BRANCHES := {
	"arcade": [[0, -122], [-14, -122], [-30, -122], [-41, -136], [-30, -122]],
	"casino": [[-30, -122], [-46, -122], [-50, -122]],
	"staff": [[0, -145], [-13, -145], [-20, -145]],
	"tunnel_loop": [[0, -122], [14, -122], [38, -122], [42, -135], [42, -148], [42, -168], [20, -168], [10, -168], [8, -164], [8, -150]],
	"hamster": [[42, -146], [46, -146], [55, -146]],
	"tech": [[42, -160], [37, -160], [34, -160]],
	"alley": [[0, -48], [-7, -48], [-10, -55], [-10, -100], [-7, -104], [0, -104]],
}

func ok(cond: bool, text: String) -> void:
	c.ok(cond, "ПОДЗЕМКА: " + text)

func _hero_y_ok() -> bool:
	return P.global_position.y > -6.5 and P.global_position.y < 9.0

## Идти к точке (x, z) клавишей «вперёд» с поворотом камеры; false — застрял или выпал
func _walk(tx: float, tz: float, sprint := false) -> bool:
	var stuck_t := 0.0
	var last: Vector3 = P.global_position
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		var to: Vector3 = Vector3(tx, 0, tz) - Vector3(P.global_position.x, 0, P.global_position.z)
		if to.length() < 1.1:
			Input.action_release("up")
			Input.action_release("sprint")
			return true
		if not _hero_y_ok():
			Input.action_release("up")
			return false
		g.cam_yaw = atan2(-to.x, -to.z)
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
			var q := PhysicsRayQueryParameters3D.create(ctr, ctr + Vector3(cos(a), 0, sin(a)) * 90.0)
			if space.intersect_ray(q).is_empty():
				holes += 1
		for dv in [Vector3.UP, Vector3.DOWN]:
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(ctr, ctr + dv * 30.0)).is_empty():
				holes += 1
	ok(holes == 0, "лучи из центров %d помещений (16 направлений + вверх/вниз) упираются в коллизию, дыр: %d" % [G67Podzemka.ROOMS.size(), holes])
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
			if not await _walk(float(br[i][0]), float(br[i][1])):
				good = false
				print("GOLDA67CHECK   ПОДЗЕМКА: ветка %s: застрял у %s, позиция %s" % [nm, str(br[i]), str(P.global_position)])
				break
		total += _path_len(br)
		ok(good, "ветка «%s» пройдена ногами (%.0f м)" % [nm, _path_len(br)])
	print("GOLDA67CHECK   ПОДЗЕМКА длина хребта %.0f м, хребет + ветки %.0f м, шагом %.0f с" % [_path_len(RIDGE), total, walk_s])
	await _shots()
	await _routes()
	await _full_run()
	await _save_resume()

func _shots() -> void:
	await c._cam_shot(g, "pz_stairs", Vector3(0, 7.5, 4.5), Vector3(0, 1.0, -14))
	await c._cam_shot(g, "pz_gallery", Vector3(0, 1.8, -48), Vector3(0, 1.8, -105))
	await c._cam_shot(g, "pz_cross", Vector3(0, 2.2, -112), Vector3(0, 1.5, -131))
	await c._cam_shot(g, "pz_tunnel", Vector3(14, 1.7, -122), Vector3(36, 1.5, -122))
	await c._cam_shot(g, "pz_arena", Vector3(0, 3.0, -172), Vector3(0, 1.5, -186))

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
			break
		var pos := int(G.run["pos"])
		await c._go(G, P2, "gate0")
		await c.until(func(): return int(G.run["pos"]) != pos, 8.0)
		await c.wait(0.3)
	ok(G.room_state == "boss" and G.run.get("district", "") == "podzemka", "забег района дошёл до босса (%s)" % ", ".join(stages))
	c._kill_all(g)
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
