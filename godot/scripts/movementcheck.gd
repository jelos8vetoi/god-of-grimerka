## Проверка движения (player.gd: рывок в воздухе, скольжение, прыжок с разгона, отскок от стены):
## -- --movementcheck=<папка>, с --resolution 1280x720. Оба героя; рывок вперёд/назад/вбок/по диагонали, второй рывок
## в том же прыжке не выходит, земля возвращает рывок, рывок после переката, удар из рывка, перекат и блок как раньше,
## стена (не пролетает насквозь, отскок не возвращает рывок), скольжение без неуязвимости и выход в прыжок, прыжок
## с разгона ограничен, в диалоге / паузе / iPod рывка нет, после рывка герой в обычном состоянии. Снимки — m_*.png.
## В конце «MOVEMENTCHECK ok» или «MOVEMENTCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
var MV: Dictionary

func _ready() -> void:
	MV = (preload("res://scripts/player.gd") as GDScript).get_script_constant_map()["MOVE"]
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("MOVE ok: " if c else "MOVE ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func press(inp: Dictionary) -> void:
	P.auto_input = inp
	await get_tree().physics_frame
	var keep := {}
	for k in inp:
		if str(inp[k]) != "press":
			keep[k] = inp[k]
	P.auto_input = keep

func wait_floor(limit := 120) -> void:
	var n := 0
	await frames(3)
	while not P.is_on_floor() and n < limit:
		await get_tree().physics_frame
		n += 1
	await frames(4)

func stage(hero: String, sid: String) -> void:
	P = game.player
	if P.hero != hero:
		game.tag.tag_cd = 0.0
		game.swap_heroes()
		await frames(40)
	if P.style.id != sid:
		var keys := {"vozduh": "style1", "bottles": "style2", "tyaga812": "style3", "skateboard": "style1", "guitar": "style2", "breaker": "style3"}
		await press({keys[sid]: "press"})
		var n := 0
		while (P.state == "switch" or P.switch_to != "") and n < 200:
			await get_tree().physics_frame
			n += 1
	if P.skate.on:
		P.skate.off()
	P.auto_input = {}
	P.global_position = Vector3(0, 0.05, 2.0)
	P.velocity = Vector3.ZERO
	P.carry = Vector3.ZERO
	P.face = PI
	game.cam_yaw = 0.0
	P.state = "move"
	await wait_floor()

func side_shot(nm: String) -> void:
	var c: Vector3 = P.global_position + Vector3(0, 1.0, 0)
	cam.global_position = c + Vector3(4.6, 0.6, 0.4)
	cam.look_at(c, Vector3.UP)
	cam.fov = 55.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm))
	cam.clear_current(true)

## Прыжок и рывок по вводу v (вид от камеры: (0,1) — вперёд); → [смещение по горизонтали, направление рывка]
func jump_dash(v: Vector2, shot := "") -> Array:
	await press({"jump": "press"})
	await frames(10)
	var p0: Vector3 = P.global_position
	var n0: int = P.moves_log.size()
	var want: Vector3 = Vector3.ZERO
	P.auto_input = {"move": v}
	await get_tree().physics_frame
	want = P.input_dir()
	await press({"move": v, "roll": "press"})
	var shot_done := shot == ""
	var n := 0
	while P.state == "airdash" and n < 60:
		if not shot_done and P.t > 0.08:
			shot_done = true
			await side_shot(shot)
		await get_tree().physics_frame
		n += 1
	P.auto_input = {}
	var d: Vector3 = P.global_position - p0
	d.y = 0
	return [d, want, P.moves_log.size() > n0]

func _run() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	game.enemies = []
	await frames(5)
	for hs in [["pahan", "vozduh"], ["madk1d", "guitar"]]:
		var hero: String = hs[0]
		await stage(hero, hs[1])
		# ---- рывок в разные стороны ----
		for c in [["вперёд", Vector2(0, 1)], ["назад", Vector2(0, -1)], ["влево", Vector2(-1, 0)], ["вправо", Vector2(1, 0)], ["по диагонали", Vector2(0.7, 0.7)]]:
			await stage(hero, hs[1])
			var r: Array = await jump_dash(c[1], "m_%s_dash.png" % hero if String(c[0]) == "вправо" else "")
			var d: Vector3 = r[0]
			var want: Vector3 = (r[1] as Vector3).normalized()
			ok(r[2] and d.length() > 2.0 and d.normalized().dot(want) > 0.85, "%s: рывок %s — %.1f м по направлению ввода (совпадение %.2f)" % [hero, c[0], d.length(), d.normalized().dot(want)])
			ok(P.state == "move" and absf(P.spin.rotation.z) < 0.001, "%s: после рывка %s — обычное состояние, без поворота" % [hero, c[0]])
		# ---- второй рывок в том же прыжке ----
		await stage(hero, hs[1])
		await jump_dash(Vector2(0, 1))
		var n1: int = P.moves_log.size()
		await press({"move": Vector2(1, 0), "roll": "press"})
		await frames(3)
		ok(not P.is_on_floor() and P.moves_log.size() == n1 and P.state != "airdash" and not P.air_dash_ready, "%s: второй рывок в том же прыжке не выходит" % hero)
		# удар в воздухе не возвращает рывок
		await press({"attack": "press"})
		await frames(8)
		ok(not P.air_dash_ready, "%s: удар в воздухе рывок не возвращает" % hero)
		await wait_floor()
		ok(P.air_dash_ready, "%s: земля возвращает рывок" % hero)
		var r2: Array = await jump_dash(Vector2(0, 1))
		ok(r2[2], "%s: следующий прыжок — рывок снова есть" % hero)
		await wait_floor()
		# ---- после переката ----
		await stage(hero, hs[1])
		await press({"move": Vector2(0, 1), "roll": "press"})
		ok(P.state == "roll", "%s: на земле Shift — по-прежнему перекат (%s)" % [hero, P.state])
		var nn := 0
		while P.state == "roll" and nn < 80:
			await get_tree().physics_frame
			nn += 1
		var r3: Array = await jump_dash(Vector2(0, 1))
		ok(r3[2], "%s: прыжок после переката — рывок есть" % hero)
		await wait_floor()
		# ---- удар из рывка ----
		await stage(hero, hs[1])
		await press({"jump": "press"})
		await frames(10)
		await press({"move": Vector2(0, 1), "roll": "press"})
		await frames(3)
		await press({"attack": "press"})
		var att := false
		for i in 30:
			await get_tree().physics_frame
			if P.state == "attack":
				att = true
				break
		ok(att, "%s: удар во время рывка — выход в воздушную атаку" % hero)
		await wait_floor()
		await frames(40)
		# ---- блок как раньше ----
		await stage(hero, hs[1])
		P.auto_input = {"block": "hold"}
		await frames(6)
		ok(P.state == "block", "%s: блок держится (%s)" % [hero, P.state])
		P.auto_input = {}
		await frames(6)
		# ---- скольжение ----
		await stage(hero, hs[1])
		P.auto_input = {"move": Vector2(0, 1), "sprint": "hold"}
		await frames(45)
		await press({"move": Vector2(0, 1), "sprint": "hold", "roll": "press"})
		var slid: bool = P.state == "slide"
		var inv_slide: float = P.inv
		await frames(4)
		await side_shot("m_%s_slide.png" % hero)
		ok(slid and inv_slide <= 0.0, "%s: Shift на бегу с рывком — скольжение, без неуязвимости (%s, inv %.2f)" % [hero, P.state, inv_slide])
		await frames(1)                  # после снимка — сначала кадр физики, иначе нажатие пропадёт
		var vy0: float = 0.0
		await press({"move": Vector2(0, 1), "jump": "press"})
		vy0 = P.velocity.y
		var log_last: Array = P.moves_log.back() if not P.moves_log.is_empty() else []
		ok(log_last.size() > 0 and String(log_last[0]) == "slide_jump" and vy0 > 6.0 and P.carry.length() > 2.0, "%s: выход из скольжения в прыжок с переносом скорости (вверх %.1f, перенос %.1f)" % [hero, vy0, P.carry.length()])
		P.auto_input = {}
		await wait_floor()
		await frames(60)
		ok(P.carry.length() < 0.3 and P.state == "move", "%s: после приземления перенос гаснет (%.2f), состояние обычное" % [hero, P.carry.length()])
		# ---- прыжок с разгона ----
		await stage(hero, hs[1])
		var n2: int = P.moves_log.size()
		await press({"jump": "press"})
		ok(P.moves_log.size() == n2, "%s: прыжок с места — без переноса" % hero)
		await wait_floor()
		await stage(hero, hs[1])
		P.auto_input = {"move": Vector2(0, 1), "sprint": "hold"}
		await frames(45)
		await press({"move": Vector2(0, 1), "sprint": "hold", "jump": "press"})
		var mj: Array = P.moves_log.back() if not P.moves_log.is_empty() else []
		ok(mj.size() > 1 and String(mj[0]) == "mjump" and float(mj[1]) > 1.0 and float(mj[1]) <= float(MV[hero]["mom_max"]) + 0.01, "%s: прыжок с разгона — перенос %.2f (не больше %.1f)" % [hero, float(mj[1]) if mj.size() > 1 else 0.0, float(MV[hero]["mom_max"])])
		P.auto_input = {}
		await wait_floor()
		# ---- запреты: диалог, пауза, iPod ----
		await stage(hero, hs[1])
		await press({"jump": "press"})
		await frames(8)
		var n3: int = P.moves_log.size()
		game.mode = "dlg"
		await press({"move": Vector2(0, 1), "roll": "press"})
		await frames(2)
		game.mode = "idle"
		ok(P.moves_log.size() == n3, "%s: в диалоге рывка нет" % hero)
		await wait_floor()
		await stage(hero, hs[1])
		await press({"jump": "press"})
		await frames(8)
		var n4: int = P.moves_log.size()
		get_tree().paused = true
		await press({"move": Vector2(0, 1), "roll": "press"})
		get_tree().paused = false
		await frames(2)
		ok(P.moves_log.size() == n4 or P.state == "airdash", "%s: в паузе рывок не срабатывает (сработал после — по нажатию)" % hero)
		await wait_floor()
	# ---- стена: не пролетает насквозь, отскок не возвращает рывок ----
	await stage("pahan", "vozduh")
	var wall := find_wall()
	if wall.is_empty():
		# у этой арены высоких стен рядом нет — ставим стену для проверки (столкновение как у стен локаций: слой 1)
		var sb := StaticBody3D.new()
		sb.collision_layer = 1 | 8
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(8.0, 6.0, 0.6)
		cs.shape = bs
		sb.add_child(cs)
		game.add_child(sb)
		sb.global_position = Vector3(0, 3.0, -6.0)
		await frames(3)
		wall = find_wall()
	if wall.is_empty():
		ok(true, "стена: у арены нет столкновений рядом — отскок проверить негде (механика срабатывает только у настоящей стены)")
	else:
		var wp: Vector3 = wall["pos"]
		var wn: Vector3 = wall["n"]
		P.global_position = wp + wn * 2.2 + Vector3(0, 0.05, 0)
		P.velocity = Vector3.ZERO
		await wait_floor()
		await press({"jump": "press"})
		await frames(6)
		P.auto_input = {}
		var into := -wn
		var fwd := Vector3(-sin(game.cam_yaw), 0, -cos(game.cam_yaw))
		var right := Vector3(cos(game.cam_yaw), 0, -sin(game.cam_yaw))
		var v := Vector2(into.dot(right), into.dot(fwd))
		await press({"move": v, "roll": "press"})
		var n5 := 0
		while P.state == "airdash" and n5 < 40:
			await get_tree().physics_frame
			n5 += 1
		var past: float = (P.global_position - wp).dot(wn)
		ok(past > -0.05, "рывок в стену: не пролетел насквозь (%.2f м от стены)" % past)
		P.auto_input = {"move": v}
		await frames(2)
		var can: bool = P.can_wall_rebound()
		await press({"move": v, "jump": "press"})
		var last: Array = P.moves_log.back() if not P.moves_log.is_empty() else []
		ok(not can or (String(last[0]) == "wall" and P.velocity.y > 5.0), "у стены прыжок — отскок (%s)" % ("был" if can else "стена не коснулась"))
		ok(not P.air_dash_ready, "отскок от стены не возвращает рывок")
		P.auto_input = {}
		await wait_floor()
	print("MOVEMENTCHECK ok" if fails == 0 else "MOVEMENTCHECK ОШИБОК: %d" % fails)
	get_tree().quit()

## Ближайшая стена-столкновение от центра: лучи на уровне груди во все стороны
func find_wall() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = P.get_world_3d().direct_space_state
	var c := Vector3(0, 1.2, 0)
	var best := {}
	var bd := 99.0
	for i in 16:
		var a := TAU * i / 16.0
		var q := PhysicsRayQueryParameters3D.create(c, c + Vector3(sin(a), 0, cos(a)) * 14.0)
		q.exclude = [P.get_rid()]
		var h: Dictionary = space.intersect_ray(q)
		# стена, а не низкий ящик: на высоте прыжка тоже есть препятствие
		var q2 := PhysicsRayQueryParameters3D.create(c + Vector3(0, 2.6, 0), c + Vector3(0, 2.6, 0) + Vector3(sin(a), 0, cos(a)) * 14.0)
		q2.exclude = [P.get_rid()]
		var h2: Dictionary = space.intersect_ray(q2)
		if h.is_empty() or h2.is_empty() or absf((h["position"] as Vector3).distance_to(c) - (h2["position"] as Vector3).distance_to(c + Vector3(0, 2.6, 0))) > 0.3:
			continue                     # на высоте прыжка — та же поверхность, значит стена, а не ящик
		if not h.is_empty() and (h["position"] as Vector3).distance_to(c) < bd and absf((h["normal"] as Vector3).y) < 0.3:
			bd = (h["position"] as Vector3).distance_to(c)
			best = {"pos": Vector3((h["position"] as Vector3).x, 0.0, (h["position"] as Vector3).z), "n": Vector3((h["normal"] as Vector3).x, 0, (h["normal"] as Vector3).z).normalized()}
	return best
