## Проверка Team Hype и Team Overdrive (этап 12): -- --hypecheck=<папка>, запускать с --resolution 1280x720.
## Накопление шкалы и защита от повторов, запреты активации, постановка по долям на обычных врагах,
## варианты по стилям, отмена, правила для босса, сохранение. В конце — «HYPECHECK ok» или «HYPECHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var H: TeamHype
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
	print(("HYPE ok: " if c else "HYPE ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

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
	H = game.hype
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
	P.swag = 0.0
	P.hp = P.max_hp
	P.auto_input = {}
	P.combat.interrupt()
	H.value = 0.0
	H.tired = {}
	H.recent = []
	H.events = []
	H.log_gain = []
	H.idle_t = 0.0
	game.buddy.global_position = Vector3(3.0, 0.05, 6.0)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await frames(8)

func foe(kind := "bot", at := Vector3(0, 0, -2.2), hp := 9999.0):
	var e = game._make_enemy(kind, "", P.global_position + at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

func to_style(key: String) -> void:
	await tap(key)
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 150:
		await get_tree().physics_frame
		n += 1
	await frames(40)

func until_free(max_frames := 300) -> void:
	var n := 0
	while not P.state in ["move", "tyaga"] and n < max_frames:
		await get_tree().physics_frame
		n += 1

func run_od() -> float:
	var n := 0
	while H.on and n < 400:
		await get_tree().physics_frame
		n += 1
	return n / 60.0

func _run() -> void:
	# ================= 1. накопление и повторы =================
	await stage()
	var e = foe()
	await frames(4)
	for i in 4:
		await tap("attack")
		await until_free()
		await frames(12)
	var same: float = H.value
	ok(abs(same - 1.6) < 0.01, "один и тот же удар четыре раза подряд дал шкале %.1f — как один удар" % same)
	await stage()
	e = foe()
	await frames(4)
	for a in ["attack", "attack", "attack"]:
		await tap(a)
		var n := 0
		while not P.combat.in_combo_window() and P.state == "attack" and n < 200:
			await get_tree().physics_frame
			n += 1
	await until_free()
	ok(H.value > same * 2.5, "три разных удара цепочки дали %.1f — разнообразие копит быстрее" % H.value)
	await stage()
	var g1: float = H.gain("parry")
	var g2: float = H.gain("parry")
	var g3: float = H.gain("parry")
	ok(abs(g1 - 8.0) < 0.01 and abs(g2 - 4.0) < 0.01 and abs(g3 - 2.0) < 0.01, "повтор одного источника подряд: %.0f, %.0f, %.0f — каждый раз вдвое меньше" % [g1, g2, g3])
	H.tired["parry"] = [game.clock - TeamHype.FATIGUE - 0.1, 2]
	ok(abs(H.gain("parry") - 8.0) < 0.01, "через %.0f с источник снова даёт полностью" % TeamHype.FATIGUE)
	# источники из боя: Perfect Swap, командный приём, помощь, добивание, уклонение
	await stage()
	e = foe()
	await frames(4)
	await tap("attack")
	var n2 := 0
	while not P.combat.in_combo_window() and n2 < 200:
		await get_tree().physics_frame
		n2 += 1
	await tap("style2")
	await frames(40)
	var got_swap: bool = H.log_gain.any(func(x): return x[0] == "swap")
	await to_style("style1")
	e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 2.2
	await tap("assist")
	await frames(6)
	var got_assist: bool = H.log_gain.any(func(x): return x[0] == "assist")
	game.feedback("perfect_dodge", P.global_position)
	game.feedback("parry", P.global_position)
	e.hp = 20.0
	e.max_hp = 100.0
	e.stun(3.0)
	await tap("heat")
	await frames(90)
	var got_exec: bool = H.log_gain.any(func(x): return x[0] == "execution")
	await stage()
	e = foe()
	await frames(4)
	await tap("attack")
	n2 = 0
	while not (P.state == "attack" and P.combat.hit_i > 0) and n2 < 120:
		await get_tree().physics_frame
		n2 += 1
	await tap("tag")
	await frames(6)
	ok(got_swap and got_assist and got_exec and H.log_gain.any(func(x): return x[0] == "tag"), "шкалу дают Perfect Swap, помощь напарника, добивание и командный приём")
	await stage()
	game.feedback("perfect_dodge", P.global_position)
	game.feedback("parry", P.global_position)
	await frames(2)
	ok(abs(H.value - 14.0) < 0.01, "точное уклонение и парирование: +%.0f" % H.value)
	await stage("madk1d")
	await to_style("style3")
	P.breaker.events.append(["perfect", 4])
	P.skate.events.append(["trick", "kickflip"])
	P.guitar.events.append(["beat", 2])
	await frames(3)
	ok(H.log_gain.any(func(x): return x[0] == "perfect_freeze") and H.log_gain.any(func(x): return x[0] == "trick") and H.log_gain.any(func(x): return x[0] == "beat"), "Perfect Freeze, трюк на доске и попадание в такт тоже копят шкалу: %.1f" % H.value)
	H.value = 50.0
	H.idle_t = TeamHype.DECAY_AFTER + 0.1
	await frames(60)
	ok(H.value < 49.0, "без подпитки шкала тает: 50 → %.1f за секунду" % H.value)
	# ================= 2. запреты =================
	await stage()
	H.value = 60.0
	await tap("overdrive")
	await frames(2)
	ok(not H.on and H.events[H.events.size() - 1] == ["blocked", "hype"], "шкала 60 %: Overdrive не запускается")
	H.value = 100.0
	H.idle_t = 99.0
	await frames(30)
	ok(H.value == 100.0, "полная шкала не тает — её надо потратить")
	P.inv = 0.0
	P.take_damage(5.0, P.global_position + Vector3(0, 0, -2))
	P.inv = 9999.0
	await frames(2)
	await tap("overdrive")
	await frames(2)
	ok(not H.on and P.state == "hurt", "пока героя бьют, Overdrive не запустить (%s)" % str(H.events[H.events.size() - 1]))
	await until_free()
	game.tag.down["madk1d"] = true
	game.tag.revive_t["madk1d"] = 99.0
	await tap("overdrive")
	await frames(2)
	ok(not H.on and H.events[H.events.size() - 1] == ["blocked", "down"], "напарник выбыл — Overdrive недоступен")
	game.tag.down["madk1d"] = false
	# ================= 3. постановка =================
	await stage()
	P.heroes["madk1d"]["style"] = "skateboard"
	var es: Array = []
	for at in [Vector3(0, 0, -2.5), Vector3(2.0, 0, -3.0), Vector3(-2.0, 0, -3.0), Vector3(0.8, 0, -4.2)]:
		es.append(foe("bot", at, 500.0))
	es.append(foe("troll", Vector3(-1.2, 0, -4.6), 500.0))
	await frames(6)
	H.value = 100.0
	var hp0: float = P.hp
	await tap("overdrive")
	await frames(3)
	var went: bool = H.on and P.state == "overdrive"
	var held := 0
	for x in es:
		if x.state == "stun":
			held += 1
	await frames(24)
	await shot("01_overdrive_enter.png")
	P.take_damage(50.0, P.global_position + Vector3(0, 0, -2))        # по героям в постановке не попасть: неуязвимость держит сама постановка
	await frames(36)
	await shot("02_overdrive_move1.png")
	await tap("style2")
	await tap("tag")
	await frames(30)
	await shot("03_overdrive_move2.png")
	while H.on and H.beat_i < 4:
		await get_tree().physics_frame
	await frames(3)
	await shot("04_overdrive_finale.png")
	var sec: float = await run_od()
	await frames(4)
	var dealt := 0.0
	for x in es:
		dealt += 500.0 - max(x.hp, 0.0)
	var moves: Array = H.events.filter(func(x): return x[0] == "move").map(func(x): return x[1])
	ok(went and held == 5 and abs(P.hp - hp0) < 0.01 and P.hero == "pahan" and P.style.id == "vozduh", "Overdrive запущен: пятеро врагов обездвижены, герои неуязвимы, смена стиля и героя в постановке не срабатывает")
	ok(moves == ["vozduh", "skateboard"] and H.events.any(func(x): return x[0] == "finale") and dealt > 5 * 70.0, "по долям: вход → приём Пахана (балон) → приём madk1d (скейт) → финал; всего урона %.0f по пяти врагам" % dealt)
	ok(H.value == 0.0 and P.state == "move" and not H.on, "после постановки шкала пуста, управление вернулось (%s); вся постановка — %.1f с" % [P.state, TeamHype.LEN])
	await tap("overdrive")
	await frames(2)
	ok(not H.on, "второй раз подряд не запустить — шкала потрачена")
	# варианты по стилям
	await stage("madk1d")
	await to_style("style2")
	game.tag.reset()
	P.heroes["pahan"]["style"] = "tyaga812"
	es = [foe("bot", Vector3(3.0, 0, -3.0), 500.0), foe("bot", Vector3(-3.0, 0, -3.0), 500.0)]
	await frames(6)
	var gap0: float = es[0].global_position.distance_to(es[1].global_position)
	H.value = 100.0
	await tap("overdrive")
	while H.on and H.beat_i < 3:
		await get_tree().physics_frame
	await frames(2)
	await shot("05_overdrive_guitar_tyaga.png")
	var gap1: float = es[0].global_position.distance_to(es[1].global_position)
	await run_od()
	moves = H.events.filter(func(x): return x[0] == "move").map(func(x): return x[1])
	ok(moves == ["guitar", "tyaga812"] and gap1 < gap0 * 0.6, "другие стили — другая постановка: %s; «воронка» пылесоса стянула врагов (%.1f м → %.1f м)" % [str(moves), gap0, gap1])
	# отмена
	await stage()
	P.heroes["pahan"]["style"] = "vozduh"
	e = foe("bot", Vector3(0, 0, -2.5), 500.0)
	await frames(4)
	H.value = 100.0
	await tap("overdrive")
	await frames(6)
	await tap("roll")
	await frames(4)
	ok(not H.on and abs(H.value - 60.0) < 0.01 and P.state in ["move", "roll", "tyaga"] and e.hp == 500.0, "отмена уклонением в первые %.1f с: постановка прервана, вернулось 60 %% шкалы (%.0f), враг цел (%.0f), состояние %s" % [TeamHype.CANCEL, H.value, e.hp, P.state])
	await until_free()
	H.value = 100.0
	await tap("overdrive")
	await frames(40)
	await tap("roll")
	await frames(3)
	ok(H.on, "позже отменить нельзя — постановка доигрывается")
	await run_od()
	# ================= 4. босс =================
	await stage()
	var boss = game._make_enemy("bot", "courier", P.global_position + Vector3(0, 0, -3.0))
	await frames(70)
	boss.cool = 999.0
	var b0: float = boss.hp
	H.value = 100.0
	await tap("overdrive")
	await frames(6)
	var boss_free: bool = boss.state != "stun"
	await frames(60)
	await shot("06_overdrive_boss.png")
	await run_od()
	var lost: float = b0 - boss.hp
	ok(boss_free and boss.alive() and lost > 0.0 and lost <= boss.max_hp * TeamHype.BOSS_CAP + 0.5, "босс: не обездвижен, за один Overdrive потерял %.0f — не больше %.0f %% здоровья (%.0f)" % [lost, TeamHype.BOSS_CAP * 100.0, boss.max_hp * TeamHype.BOSS_CAP])
	# ================= 5. сохранение =================
	H.value = 73.0
	var txt := JSON.stringify({"tag": game.tag.save_data(), "hype": H.value})
	H.value = 0.0
	var d: Dictionary = JSON.parse_string(txt)
	H.value = clampf(float(d.get("hype", 0.0)), 0.0, TeamHype.MAX)
	ok(abs(H.value - 73.0) < 0.01, "шкала команды сохраняется (%.0f)" % H.value)
	print("HYPECHECK ok" if fails == 0 else "HYPECHECK ОШИБОК: %d" % fails)
	get_tree().quit()
