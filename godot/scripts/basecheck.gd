## Проверка основы боевых анимаций (этап 0): -- --basecheck=<папка>, запускать с --resolution 1280x720.
## Удары в прыжке (своё начало цепочки), уклонения вбок и назад, удар в блок, вариация покоя — за обоих героев.
## В конце — «BASECHECK ok» или «BASECHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var started := false
var frame_n := 0

func _ready() -> void:
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
	print(("BASE ok: " if c else "BASE ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm))

func tap(a: String) -> void:
	await get_tree().physics_frame
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}

func stage(hero := "pahan") -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	if P.hero != hero:
		game.swap_heroes()
	await frames(2)
	game.tag.reset()
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.hp = P.max_hp
	P.auto_input = {}
	P.combat.interrupt()
	game.buddy.global_position = Vector3(-9, 0.05, 10)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await frames(50)          # смена героя и её анимация должны закончиться

func foe(at := Vector3(0, 0, -2.2)):
	var e = game._make_enemy("bot", "", P.global_position + at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = 9999.0
	e.hp = 9999.0
	return e

func to_style(key: String) -> void:
	await tap(key)
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 150:
		await get_tree().physics_frame
		n += 1
	await frames(50)

func until_free(max_frames := 300) -> void:
	var n := 0
	while not P.state in ["move", "tyaga"] and n < max_frames:
		await get_tree().physics_frame
		n += 1

## уклонение с вводом движения; возвращает [вид, клип, смещение, повернулся ли, кувыркался ли]
func dodge(mv: Vector2) -> Array:
	for en in game.enemies:              # враг всегда прямо перед героем: он успевает подойти, пока герой уклоняется
		if is_instance_valid(en) and en.alive():
			en.global_position = P.global_position + Vector3(0, 0, -2.2)
			en.kb = Vector3.ZERO
	await frames(2)
	var p0: Vector3 = P.global_position
	var f0: float = P.face
	P.auto_input = {"roll": "press", "move": mv}
	await get_tree().physics_frame
	P.auto_input = {"move": mv}
	await frames(10)
	var clip: String = P.rig.cur
	var flip: float = abs(P.spin.rotation.x)
	var turned: bool = abs(angle_difference(P.face, atan2(P.roll_dir.x, P.roll_dir.z))) < 0.3      # развернулся в сторону уклонения (кувырок) или остался лицом к врагу
	await frames(8)
	flip = max(flip, abs(P.spin.rotation.x))
	var n := 0
	while P.state == "roll" and n < 90:
		await get_tree().physics_frame
		n += 1
	P.auto_input = {}
	var d: Vector3 = P.global_position - p0
	var res := [P.roll_kind, clip, d, turned, flip > 0.3]
	P.global_position = p0
	P.face = f0
	await frames(30)
	return res

func _run() -> void:
	# ================= 1. удары в прыжке =================
	await stage()
	var e = foe()
	await frames(4)
	await tap("attack")
	await frames(3)
	var ground_id: String = P.combat.cur.id if P.combat.cur != null else ""
	await until_free()
	await frames(20)
	await tap("jump")
	await frames(12)
	var y0: float = P.global_position.y
	e.global_position = P.global_position + Vector3(0, 0, -2.0)
	e.global_position.y = 0.05
	await tap("attack")
	await frames(3)
	var air_id: String = P.combat.cur.id if P.combat.cur != null else ""
	var airborne: bool = not P.is_on_floor()
	await frames(8)
	await shot("01_air_light.png")
	var n := 0
	while not P.combat.in_combo_window() and P.state == "attack" and n < 120:
		await get_tree().physics_frame
		n += 1
	var hang: bool = not P.is_on_floor()
	await tap("heavy")
	await frames(4)
	var slam_id: String = P.combat.cur.id if P.combat.cur != null else ""
	await frames(10)
	await shot("02_air_slam.png")
	await until_free()
	ok(ground_id == "vz_light1" and air_id == "vz_air_light" and airborne and y0 > 0.5 and hang and slam_id == "vz_air_slam", "Пахан: с земли ЛКМ — %s, в прыжке ЛКМ — %s (герой в воздухе на %.1f м и не падает до окна комбо), затем ПКМ — %s" % [ground_id, air_id, y0, slam_id])
	await stage("madk1d")
	e = foe()
	await frames(4)
	await tap("jump")
	await frames(12)
	await tap("attack")
	await frames(3)
	ok(P.combat.cur != null and P.state == "attack", "madk1d: у его стилей своего начала в прыжке пока нет — в воздухе идёт обычная цепочка (%s), ничего не ломается" % (P.combat.cur.id if P.combat.cur != null else "—"))
	await until_free()
	# ================= 2. уклонения =================
	for hero in ["pahan", "madk1d"]:
		await stage(hero)
		var no_foe: Array = await dodge(Vector2(1, 0))
		ok(no_foe[0] == "f" and no_foe[3] and no_foe[4], "%s без врагов: уклонение вбок — обычный кувырок с разворотом (%s)" % [hero, no_foe[1]])
		e = foe()
		await frames(6)
		var side_r: Array = await dodge(Vector2(1, 0))
		var side_l: Array = await dodge(Vector2(-1, 0))
		var backw: Array = await dodge(Vector2(0, -1))
		var fwd: Array = await dodge(Vector2(0, 1))
		ok(side_r[0] in ["l", "r"] and side_l[0] in ["l", "r"] and side_r[0] != side_l[0] and String(side_r[1]).begins_with("Dodge") and not side_r[3] and not side_r[4] and (side_r[2] as Vector3).x > 1.5 and (side_l[2] as Vector3).x < -1.5, "%s в бою: вбок — шаг-уклонение (%s / %s), на %.1f и %.1f м, лицом к врагу, без кувырка" % [hero, side_r[1], side_l[1], (side_r[2] as Vector3).x, (side_l[2] as Vector3).x])
		ok(backw[0] == "b" and String(backw[1]).begins_with("DodgeB") and not backw[3] and not backw[4] and (backw[2] as Vector3).z > 1.5, "%s в бою: назад — отскок (%s) на %.1f м, лицом к врагу (вид %s, повернулся %s, кувырок %s)" % [hero, backw[1], (backw[2] as Vector3).z, backw[0], backw[3], backw[4]])
		ok(fwd[0] == "f" and fwd[4], "%s в бою: вперёд — кувырок (%s)" % [hero, fwd[1]])
		if hero == "pahan":
			await shot("03_dodge_side.png")
	await stage("pahan")
	await to_style("style2")
	e = foe()
	await frames(6)
	var bare: Array = await dodge(Vector2(1, 0))
	ok(String(bare[1]).ends_with("Bare"), "Пахан с водярой: уклонение вбок берёт клип без балона (%s)" % bare[1])
	# точное уклонение работает и в шаге вбок
	await stage("pahan")
	e = foe()
	await frames(6)
	P.inv = 0.0
	P.auto_input = {"roll": "press", "move": Vector2(1, 0)}
	await get_tree().physics_frame
	P.auto_input = {"move": Vector2(1, 0)}
	await frames(4)
	var hp0: float = P.hp
	P.take_damage(20.0, e.global_position, e)
	var dodged: bool = P.hp == hp0 and P.perfect
	P.auto_input = {}
	await until_free()
	P.inv = 9999.0
	ok(dodged, "шаг вбок тоже уклонение: удар в начале шага не проходит и засчитывается как точное уклонение")
	# ================= 3. удар в блок =================
	for hero in ["pahan", "madk1d"]:
		await stage(hero)
		e = foe()
		await frames(6)
		P.auto_input = {"block": "hold"}
		await frames(30)                       # дольше окна парирования
		P.inv = 0.0
		var h0: float = P.hp
		P.take_damage(10.0, e.global_position, e)
		await frames(3)
		var c1: String = P.rig.cur
		var lost1: float = h0 - P.hp
		await frames(40)
		var back_to: String = P.rig.cur
		P.inv = 0.0
		h0 = P.hp
		P.take_damage(25.0, e.global_position, e)
		await frames(3)
		var c2: String = P.rig.cur
		if hero == "pahan":
			await shot("04_block_heavy.png")
		var lost2: float = h0 - P.hp
		P.auto_input = {}
		P.inv = 9999.0
		await frames(40)
		ok(c1.begins_with("BlockHit") and c2.begins_with("BlockHeavy") and back_to.begins_with("Block") and not back_to.begins_with("BlockH") and abs(lost1 - 2.0) < 0.01 and abs(lost2 - 5.0) < 0.01 and P.state in ["move", "block"], "%s: удар в блок виден — лёгкий %s (−%.0f), тяжёлый %s (−%.0f), между ними возврат в %s" % [hero, c1, lost1, c2, lost2, back_to])
	# ================= 4. вариация покоя =================
	await stage("pahan")
	await to_style("style1")
	P.idle_var_t = 0.0
	P.idle_var_next = 0.6
	await frames(70)
	var var_clip: String = P.rig.cur
	await shot("05_idle_var.png")
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(12)
	var moved_clip: String = P.rig.cur
	P.auto_input = {}
	await frames(30)
	ok(var_clip == "IdleVar" and moved_clip != "IdleVar", "Пахан с балоном от безделья осматривает оружие (%s); движение сразу прерывает (%s)" % [var_clip, moved_clip])
	e = foe(Vector3(0, 0, -5.0))
	P.idle_var_t = 0.0
	P.idle_var_next = 0.5
	await frames(70)
	ok(P.rig.cur != "IdleVar", "рядом враг — вариации покоя нет (%s)" % P.rig.cur)
	print("BASECHECK ok" if fails == 0 else "BASECHECK ОШИБОК: %d" % fails)
	get_tree().quit()
