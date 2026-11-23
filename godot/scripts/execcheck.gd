## Проверка реакций врагов и добиваний (этап 09): -- --execcheck=<папка>, запускать с --resolution 1280x720.
## Настоящая глава, оба героя, все восемь типов обычных врагов и босс первой главы. Проверяет:
## реакцию каждого типа на пять видов удара (лёгкий, тяжёлый, подброс, подсечка, отброс), добивания шести стилей,
## варианты по обстановке (воздух, парирование, уклонение), запрет добивания боссов и их окно «ОТКРЫТ».
## Печатает таблицу реакций и «EXEC ok / ОШИБКА», в конце — «EXECCHECK ok» или «EXECCHECK ОШИБОК: n».
extends Node

const KINDS8 := ["bot", "clipper", "hater", "troll", "ghost", "lawyer", "mod", "farmer"]

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
	print(("EXEC ok: " if c else "EXEC ОШИБКА: ") + msg)
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

func to_style(key: String) -> void:
	await tap(key)
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 120:
		await get_tree().physics_frame
		n += 1
	await frames(6)

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
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.swag = 0.0
	P.hp = P.max_hp
	P.auto_input = {}
	P.combat.interrupt()
	game.buddy.global_position = Vector3(-8, 0.05, 9)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await frames(8)

## враг перед героем, смирный
func foe(kind: String, dist := 2.2):
	var e = game._make_enemy(kind, "", P.global_position + Vector3(0, 0, -dist))
	e.state = "chase"
	e.cool = 999.0
	return e

func hit(e, stagger: float, heavy: bool, launch := 0.0, knock := 3.0, react := "", dmg := 1.0) -> void:
	var h := HitInfo.new()
	h.damage = dmg
	h.stagger = stagger
	h.dir = Vector3(0, 0, -1)
	h.knockback = knock
	h.launch = launch
	h.heavy = heavy
	h.power = 1 if heavy else 0
	h.react = react
	h.source = P
	h.pos = e.global_position + Vector3(0, 1, 0)
	e.take_hit_info(h)

func calm(e) -> void:
	var n := 0
	while e.state != "chase" and n < 400:
		e.cool = 999.0
		await get_tree().physics_frame
		n += 1
	e.cool = 999.0
	e.poise = e.poise_max
	e.hp = e.max_hp
	e.global_position = P.global_position + Vector3(0, 0.0, -2.2)
	e.kb = Vector3.ZERO
	await frames(3)

func run_exec(max_frames := 200) -> float:
	var n := 0
	while P.state == "exec" and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n / 60.0

func _run() -> void:
	await stage()
	# ================= 1. реакции восьми типов =================
	var table := {}
	for kind in KINDS8:
		var e = foe(kind)
		e.max_hp = 9999.0
		e.hp = 9999.0
		await frames(4)
		var row := {}
		# лёгкий
		hit(e, 10.0, false)
		row["light"] = e.react
		await calm(e)
		# тяжёлый
		hit(e, 35.0, true)
		row["heavy"] = e.react
		row["heavy_state"] = e.react_state()
		await calm(e)
		# подброс
		hit(e, 20.0, true, 7.0)
		await frames(6)
		row["launch"] = e.react
		row["launch_y"] = e.global_position.y
		await calm(e)
		# подсечка
		hit(e, 35.0, false, 0.0, 3.0, "knockdown")
		row["sweep"] = e.react
		await frames(40)
		row["sweep_state"] = e.state
		await calm(e)
		# отброс
		var z0: float = e.global_position.z
		hit(e, 20.0, true, 0.0, 14.0)
		row["blast"] = e.react
		await frames(45)
		row["blast_m"] = abs(e.global_position.z - z0)
		await calm(e)
		table[kind] = row
		print("EXEC реакции %-8s лёгкий %-6s тяжёлый %-14s подброс %-9s (%.1f м)  подсечка %-14s отброс %-10s (%.1f м)" % [kind, row["light"], row["heavy"], row["launch"], row["launch_y"], row["sweep"], row["blast"], row["blast_m"]])
		e.queue_free()
		game.enemies.erase(e)
		await frames(2)
	ok(table["bot"]["light"] == "hit" and table["bot"]["heavy"] == "heavy_stagger" and table["bot"]["launch"] == "airborne" and table["bot"]["sweep"] == "knockdown" and table["bot"]["blast"] == "knockback", "бот: пять ударов — пять разных реакций")
	ok(table["troll"]["light"] == "none" and table["troll"]["launch"] != "airborne" and float(table["troll"]["launch_y"]) < 0.3 and table["troll"]["sweep"] != "knockdown" and table["troll"]["blast"] != "knockback", "тролль: лёгкий удар не замечает, не подбрасывается, не падает и не отлетает (%s / %s / %s)" % [table["troll"]["launch"], table["troll"]["sweep"], table["troll"]["blast"]])
	ok(table["mod"]["light"] == "none" and table["mod"]["heavy"] in ["stagger", "heavy_stagger"], "модератор в броне: лёгкий удар не сбивает, тяжёлый — %s" % table["mod"]["heavy"])
	ok(table["ghost"]["sweep"] == "heavy_stagger" and table["ghost"]["launch"] == "airborne", "призрак: с ног не сбить (подсечка даёт %s), но подбрасывается" % table["ghost"]["sweep"])
	ok(float(table["hater"]["blast_m"]) > float(table["bot"]["blast_m"]) and float(table["bot"]["blast_m"]) > float(table["mod"]["blast_m"]) and float(table["mod"]["blast_m"]) > float(table["troll"]["blast_m"]), "отброс по массе: хейтер %.1f м > бот %.1f > модератор %.1f > тролль %.1f" % [table["hater"]["blast_m"], table["bot"]["blast_m"], table["mod"]["blast_m"], table["troll"]["blast_m"]])
	var same := true
	for kind in ["clipper", "hater", "lawyer", "farmer"]:
		if table[kind]["light"] != "hit" or table[kind]["sweep"] != "knockdown" or table[kind]["launch"] != "airborne":
			same = false
	ok(same and table["bot"]["heavy_state"] in ["HEAVY_STAGGER", "STAGGER"], "обычные враги (клиппер, хейтер, юрист, накрутчик) реагируют предсказуемо одинаково")
	# ================= 2. готовность к добиванию =================
	var e1 = foe("bot")
	await frames(4)
	ok(not e1.exec_ready() and e1.react_state() == "NORMAL", "целый враг: добить нельзя (%s)" % e1.react_state())
	await tap("heat")
	await frames(3)
	ok(P.state != "exec", "E у целого врага добивания не запускает")
	e1.hp = e1.max_hp * 0.3
	ok(not e1.exec_ready(), "30 % здоровья, но стоит на ногах — ещё нельзя")
	e1.stun(3.0)
	await frames(3)
	ok(e1.exec_ready() and e1.react_state() == "EXECUTION_READY", "30 %% и оглушён — можно добить (%s)" % e1.react_state())
	await frames(8)
	await shot("01_ready_mark.png")
	e1.queue_free()
	game.enemies.erase(e1)
	# ================= 3. добивания шести стилей =================
	var plan := [["pahan", "style1", "vozduh"], ["pahan", "style2", "bottles"], ["pahan", "style3", "tyaga812"], ["madk1d", "style1", "skateboard"], ["madk1d", "style2", "guitar"], ["madk1d", "style3", "breaker"]]
	var n := 1
	for row in plan:
		await stage(row[0])
		await to_style(row[1])
		await frames(20)
		game.buddy.global_position = Vector3(-9, 0.05, 10)
		game.buddy.target = game.buddy.global_position
		game.buddy.wait = 999.0
		game.cam_yaw = 1.1          # камера сбоку: видно и героя, и врага
		var e = foe("bot")
		await frames(30)
		e.hp = e.max_hp * 0.3
		e.stun(3.0)
		var sw: float = P.swag
		P.execution.events = []
		await tap("heat")
		await frames(2)
		var began: bool = P.state == "exec"
		var data: Dictionary = Execution.SETS[row[2]]
		# три кадра: начало, перед последним ударом, сразу после него
		var f0 := Engine.get_physics_frames()
		var last_at: float = float(data["beats"][data["beats"].size() - 1][0])
		n += 1
		await frames(8)
		await shot("%02d_exec_%s_a.png" % [n, row[2]])
		while P.state == "exec" and P.execution.t / P.execution.dur < last_at - 0.1:
			await get_tree().physics_frame
		await shot("%02d_exec_%s_b.png" % [n, row[2]])
		while P.state == "exec" and P.execution.beat_i < data["beats"].size():
			await get_tree().physics_frame
		await frames(3)
		await shot("%02d_exec_%s_c.png" % [n, row[2]])
		await run_exec()
		var sec: float = (Engine.get_physics_frames() - f0) / 60.0
		await frames(4)
		ok(P.style.id == row[2] and began and not e.alive() and e.executed and sec < 1.3 and P.swag > sw and P.state in ["move", "tyaga"], "%s — «%s»: враг добит за %.2f с, СВЭГ +%.0f, управление вернулось (%s)" % [row[2], data["title"], sec, P.swag - sw, P.state])
	# ================= 4. обстановка: воздух, парирование, уклонение =================
	await stage("pahan")
	await to_style("style1")
	var ea = foe("bot")
	await frames(4)
	ea.hp = ea.max_hp * 0.3
	hit(ea, 5.0, true, 8.0)
	await frames(10)
	P.execution.events = []
	await tap("heat")
	await frames(14)
	await shot("08_air_finisher.png")
	await run_exec()
	ok(P.execution.events.size() > 0 and P.execution.events[0][1] == "air" and not ea.alive(), "враг в воздухе — AIR FINISHER: %s" % str(P.execution.events))
	for c in [["parry", "parry"], ["perfect", "dodge"]]:
		await stage("pahan")
		var ep = foe("bot")
		await frames(4)
		ep.hp = ep.max_hp * 0.55
		ok(not ep.exec_ready(), "55 % здоровья на ногах: обычным способом не добить")
		P.combat.windows.clear()      # окно прошлого случая ещё открыто — оно бы и сработало
		P.combat.open(c[0], 0.6)
		P.execution.events = []
		await tap("heat")
		await frames(3)
		var went: bool = P.state == "exec"
		var sec2: float = await run_exec()
		ok(went and P.execution.events[0][1] == c[1] and not ep.alive() and sec2 < 0.85, "сразу после %s — %s за %.2f с" % ["парирования" if c[0] == "parry" else "уклонения", Execution.CTX[c[1]]["title"], sec2])
	# ================= 5. все восемь типов добиваются =================
	await stage("pahan")
	var done8 := 0
	for kind in KINDS8:
		var e = foe(kind)
		await frames(4)
		e.hp = e.max_hp * 0.3
		e.stun(3.0)
		await tap("heat")
		await frames(2)
		await run_exec()
		await frames(6)
		if not e.alive() and e.executed:
			done8 += 1
		else:
			print("EXEC не добит: %s (%s)" % [kind, e.state])
		P.global_position = Vector3(0, 0.05, 4.0)
		P.face = PI
		await frames(4)
	ok(done8 == 8, "добиваются все восемь типов обычных врагов (%d из 8)" % done8)
	# ================= 6. босс: добить нельзя, есть окно =================
	await stage("pahan")
	var b = game._make_enemy("bot", "courier", P.global_position + Vector3(0, 0, -3.0))
	await frames(70)
	b.hp = b.max_hp * 0.05
	b.cool = 999.0
	var pm: float = b.poise_max
	ok(not b.exec_ready() and not b.exec_ready(true), "босс при 5 % здоровья: добивание недоступно")
	b.stun(2.0)
	await tap("heat")
	await frames(3)
	ok(P.state != "exec" and b.alive(), "E рядом с оглушённым боссом добивания не запускает")
	var n2 := 0
	while b.state in ["stun", "special", "spawn"] and n2 < 400:
		await get_tree().physics_frame
		n2 += 1
	b.cool = 999.0
	b.stagger(b.poise + 1.0)
	await frames(2)
	var hp0: float = b.hp
	hit(b, 0.0, false, 0.0, 0.0, "", 10.0)
	await shot("09_boss_open.png")
	ok(b.state == "stun" and b.weak_t > 0.0 and b.poise_max > pm and abs((hp0 - b.hp) - 13.0) < 0.01, "босс: срыв равновесия открывает окно «ОТКРЫТ» (урон ×1,3: %.0f), равновесие стало крепче (%.0f → %.0f)" % [hp0 - b.hp, pm, b.poise_max])
	hit(b, 20.0, true, 8.0, 14.0, "knockdown", 1.0)
	await frames(6)
	ok(b.state != "air" and b.state != "down" and b.global_position.y < 0.4, "босса не подбросить и не сбить с ног (%s)" % b.state)
	print("EXECCHECK ok" if fails == 0 else "EXECCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
