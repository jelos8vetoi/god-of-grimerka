## Проверка Tag Team (этап 10): -- --tagcheck=<папка>, запускать с --resolution 1280x720.
## Настоящая глава и оба героя. Проверяет: смену героя и отдельное здоровье, паузу между сменами, смену в ударе,
## в воздухе, после уклонения, при низком здоровье и запрет под ударом; командные приёмы; помощь напарника;
## выбывание одного героя, возвращение и гибель обоих; поведение напарника; командное добивание; сохранение; босса.
## Печатает «TAG ok / ОШИБКА», в конце — «TAGCHECK ok» или «TAGCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var T: TagTeam
var B
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
	print(("TAG ok: " if c else "TAG ОШИБКА: ") + msg)
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
	T = game.tag
	B = game.buddy
	if P.hero != hero:
		game.swap_heroes()
	await frames(2)
	T.reset()
	T.auto_assist = false
	T.events = []
	B.events = []
	B.foe = null
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
	B.global_position = Vector3(3.0, 0.05, 6.0)
	B.target = B.global_position
	B.wait = 999.0
	await frames(8)

func foe(kind := "bot", dist := 2.2, hp := 9999.0):
	var e = game._make_enemy(kind, "", P.global_position + Vector3(0, 0, -dist))
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

func last() -> String:
	return String(T.events[T.events.size() - 1][0]) if T.events.size() > 0 else ""

## ударить и нажать Tab, когда удар уже попал
func hit_then_tag(action: String) -> void:
	await tap(action)
	var n := 0
	while not (P.state == "attack" and P.combat.hit_i > 0) and n < 120:
		await get_tree().physics_frame
		n += 1
	await tap("tag")
	await frames(3)

func _run() -> void:
	if OS.get_cmdline_user_args().has("--ai"):
		await _ai_trace()
		return
	# ================= 1. обычная смена, здоровье каждого =================
	await stage()
	var pa: Vector3 = P.global_position
	var ba: Vector3 = B.global_position
	P.inv = 0.0
	P.hp = 100.0
	await frames(2)
	P.take_damage(40.0, P.global_position + Vector3(0, 0, -2))
	await frames(40)
	P.inv = 9999.0
	ok(abs(P.hp - 60.0) < 0.01 and abs(float(T.grey["pahan"]) - 20.0) < 0.01, "Пахан получил 40 урона: здоровье %.0f, восстановимо %.0f" % [P.hp, T.grey["pahan"]])
	await tap("tag")
	await frames(3)
	ok(P.hero == "madk1d" and abs(P.hp - 100.0) < 0.01 and B.look == "pahan" and P.global_position.distance_to(ba) < 0.6 and B.global_position.distance_to(pa) < 0.6, "Tab: управляем madk1d (здоровье %.0f), Пахан стал напарником (%s), герои на местах друг друга (игрок в %.1f м от места напарника, напарник в %.1f м от места игрока)" % [P.hp, B.look, P.global_position.distance_to(ba), B.global_position.distance_to(pa)])
	await shot("01_tag_plain.png")
	await tap("tag")
	await frames(2)
	ok(P.hero == "madk1d" and last() == "blocked", "сразу второй Tab не срабатывает: пауза между сменами (%s)" % str(T.events[T.events.size() - 1]))
	await frames(int(TagTeam.TAG_CD * 60.0) + 200)
	var ph: float = float(T.hp["pahan"])
	ok(ph > 68.0 and ph <= 80.01 and float(T.grey["pahan"]) < 12.0, "пока Пахан отдыхает напарником, восстанавливается только «серое» здоровье: %.0f (не выше 80)" % ph)
	await tap("tag")
	await frames(3)
	ok(P.hero == "pahan" and abs(P.hp - ph) < 1.5 and abs(float(T.hp["madk1d"]) - 100.0) < 0.01, "Tab обратно: у Пахана его здоровье (%.0f), у madk1d своё (100)" % P.hp)
	# стиль каждого сохраняется
	await stage()
	await tap("style2")
	await frames(70)
	await tap("tag")
	await frames(8)
	await tap("style3")
	await frames(80)
	await frames(int(TagTeam.TAG_CD * 60.0))
	await tap("tag")
	await frames(8)
	ok(P.hero == "pahan" and P.style.id == "bottles" and P.heroes["madk1d"]["style"] == "breaker", "стиль каждого героя сохраняется: Пахан — %s, madk1d — %s" % [P.style.id, P.heroes["madk1d"]["style"]])
	# ================= 2. командные приёмы по Tab =================
	await stage()
	var e = foe()
	await frames(4)
	var h0: float = e.hp
	await hit_then_tag("attack")
	await shot("02_tag_attack.png")
	ok(last() == "attack" and P.hero == "madk1d" and P.global_position.distance_to(e.global_position) < 2.4 and h0 - e.hp >= 18.0 and P.state == "move" and T.bonus() > 1.0, "Tab после лёгкого попадания — TAG ATTACK: madk1d у цели, урон %.0f, следующий удар усилен" % (h0 - e.hp))
	await stage()
	e = foe()
	await frames(4)
	await hit_then_tag("heavy")
	await frames(4)
	await shot("03_double_impact.png")
	ok(last() == "double" and e.react in ["knockback", "heavy_stagger", "stagger"], "Tab после тяжёлого попадания — DOUBLE IMPACT: враг — %s" % e.react)
	await stage()
	e = foe()
	await frames(4)
	await tap("attack")
	var n := 0
	while not (P.state == "attack" and P.combat.hit_i > 0) and n < 120:
		await get_tree().physics_frame
		n += 1
	e.take_hit(1.0, Vector3(0, 0, -1), 1.0, true, 7.0)       # цель уже в воздухе
	await tap("tag")
	await frames(8)
	await shot("04_tag_launcher.png")
	ok(last() == "launcher" and e.state == "air" and (P.velocity.y > 0.5 or P.global_position.y > 0.4), "Tab, когда цель в воздухе, — TAG LAUNCHER: враг в воздухе, герой взлетел (%.1f м)" % P.global_position.y)
	await stage()
	e = foe()
	await frames(4)
	P.combat.open("parry", 0.6)
	h0 = e.hp
	await tap("tag")
	await frames(3)
	ok(last() == "counter" and h0 - e.hp > 20.0 and P.combat.clock <= float(P.combat.windows.get("parry", -9.0)), "Tab сразу после парирования — TAG COUNTER: урон %.0f, окно ответа перешло вошедшему герою" % (h0 - e.hp))
	await tap("tag")
	await frames(60)
	await tap("tag")
	await frames(2)
	ok(last() == "blocked" and P.hero == "madk1d", "после командного приёма пауза длиннее: через секунду Tab ещё не работает")
	# ================= 3. особые случаи смены =================
	await stage()
	await tap("jump")
	await frames(14)
	var in_air: bool = not P.is_on_floor()
	await tap("tag")
	await frames(3)
	ok(in_air and P.hero == "madk1d" and last() == "tag", "смена в воздухе (в прыжке) работает")
	await stage()
	P.auto_input = {"roll": "press", "move": Vector2(1, 0)}
	await get_tree().physics_frame
	P.auto_input = {}
	await frames(6)
	await tap("tag")
	await frames(2)
	var mid_roll: bool = last() == "blocked" and P.hero == "pahan"
	n = 0
	while P.state == "roll" and n < 90:
		await get_tree().physics_frame
		n += 1
	e = foe()
	await frames(2)
	await tap("tag")
	await frames(3)
	ok(mid_roll and P.hero == "madk1d" and last() == "counter", "в середине уклонения сменить нельзя, сразу после него — можно, и это TAG COUNTER (%s)" % last())
	await stage()
	P.inv = 0.0
	P.take_damage(10.0, P.global_position + Vector3(0, 0, -2))
	await frames(2)
	await tap("tag")
	await frames(2)
	ok(P.state == "hurt" or last() == "blocked", "под ударом (героя бьют) смена не срабатывает: %s" % str(T.events[T.events.size() - 1]))
	ok(P.hero == "pahan", "герой остался прежним — сменой от удара не уйти")
	await stage()
	P.hp = 5.0
	await frames(2)
	await tap("tag")
	await frames(3)
	ok(P.hero == "madk1d" and P.hp > 99.0 and float(T.hp["pahan"]) < 6.0, "смена при низком здоровье: madk1d цел (%.0f), у Пахана осталось %.0f" % [P.hp, T.hp["pahan"]])
	# ================= 4. помощь напарника [T] =================
	await stage()
	e = foe()
	await frames(4)
	h0 = e.hp
	await tap("assist")
	await frames(4)
	await shot("05_cross_attack.png")
	ok(last() == "cross" and P.hero == "pahan" and h0 - e.hp >= 16.0 and B.global_position.distance_to(e.global_position) < 2.5, "T — CROSS ATTACK: напарник у цели, урон %.0f, герой не сменился" % (h0 - e.hp))
	await tap("assist")
	await frames(2)
	ok(last() == "assist_blocked", "помощь напарника на перезарядке")
	await stage()
	e = foe()
	await frames(4)
	e.take_hit(1.0, Vector3(0, 0, -1), 1.0, true, 8.0)
	await frames(10)
	await tap("assist")
	await frames(6)
	await shot("06_air_partner.png")
	ok(last() == "air" and e.state == "air", "T по цели в воздухе — AIR PARTNER COMBO: враг остаётся в воздухе")
	# ================= 5. поведение напарника =================
	await stage()
	T.auto_assist = true
	T.auto_t = 0.2
	var e1 = foe("bot", 2.2, 5.0)
	var e2 = game._make_enemy("bot", "", P.global_position + Vector3(2.5, 0, -2.0))
	e2.cool = 999.0
	e2.state = "chase"
	e2.max_hp = 5.0
	e2.hp = 5.0
	n = 0
	while B.events.filter(func(x): return x[0] == "hit").size() < 2 and n < 900:
		e1.cool = 999.0
		e2.cool = 999.0
		await get_tree().physics_frame
		n += 1
	var hits: int = B.events.filter(func(x): return x[0] == "hit").size()
	ok(hits >= 2 and e1.alive() and e2.alive() and min(e1.hp, e2.hp) >= 1.0, "напарник сам бьёт врагов рядом (%d удара за %.1f с), но не добивает: у врагов осталось %.0f и %.0f" % [hits, n / 60.0, e1.hp, e2.hp])
	T.auto_assist = false
	B.foe = null
	B.dodge_cd = 0.0
	var e3 = game._make_enemy("bot", "", B.global_position + Vector3(1.2, 0, 0))
	await frames(70)
	e3.global_position = B.global_position + Vector3(1.2, 0, 0)
	e3.state = "wind"
	e3.t = 0.0
	var b0: Vector3 = B.global_position
	await frames(50)
	ok(B.events.any(func(x): return x[0] == "dodge") and B.global_position.distance_to(b0) > 1.0, "напарник отходит от замаха врага (%.1f м)" % B.global_position.distance_to(b0))
	await stage()
	await tap("tag")
	await frames(4)
	T.auto_assist = true
	T.auto_t = 0.2
	e1 = foe("bot", 2.2, 50.0)
	n = 0
	while not B.events.any(func(x): return x[0] == "hit") and n < 600:
		e1.cool = 999.0
		await get_tree().physics_frame
		n += 1
	ok(B.look == "pahan" and B.events.any(func(x): return x[0] == "hit"), "после смены напарником стал Пахан — и тоже помогает в бою")
	# ================= 6. выбывание и возвращение =================
	await stage()
	P.inv = 0.0
	var spot: Vector3 = P.global_position
	P.take_damage(999.0, P.global_position + Vector3(0, 0, -2))
	await frames(6)
	await shot("07_hero_down.png")
	ok(not game.over and P.hero == "madk1d" and P.state != "dead" and T.down["pahan"] and B.ko and B.look == "pahan" and B.global_position.distance_to(spot) < 1.0, "Пахан выбыл: бой продолжается за madk1d, Пахан лежит на месте гибели (over %s, герой %s, состояние %s, выбыл %s, лежит %s, в %.1f м от места)" % [game.over, P.hero, P.state, T.down["pahan"], B.ko, B.global_position.distance_to(spot)])
	P.inv = 9999.0
	await frames(100)
	await tap("tag")
	await frames(2)
	ok(P.hero == "madk1d" and last() == "blocked", "пока напарник выбыл, сменить героя нельзя")
	T.revive_t["pahan"] = 0.1
	await frames(30)
	ok(not T.down["pahan"] and not B.ko and abs(float(T.hp["pahan"]) - P.max_hp * 0.3) < 1.0, "Пахан вернулся с 30 %% здоровья (%.0f)" % T.hp["pahan"])
	await tap("tag")
	await frames(4)
	ok(P.hero == "pahan" and P.hp < P.max_hp * 0.35, "после возвращения им снова можно играть (%.0f)" % P.hp)
	await stage()
	P.inv = 0.0
	P.take_damage(999.0, P.global_position + Vector3(0, 0, -2))
	await frames(100)
	P.inv = 0.0
	P.take_damage(999.0, P.global_position + Vector3(0, 0, -2))
	await frames(3)
	ok(game.over and P.state == "dead", "выбыли оба героя — поражение")
	await frames(200)
	# ================= 7. командное добивание и босс =================
	await stage()
	e = foe("bot", 2.2, 100.0)
	await frames(4)
	e.hp = 30.0
	e.stun(3.0)
	await tap("heat")
	n = 0
	await frames(3)
	while P.state == "exec" and n < 200:
		await get_tree().physics_frame
		n += 1
	ok(T.events.any(func(x): return x[0] == "finisher") and not e.alive(), "добивание рядом с напарником — TEAM FINISHER")
	await stage()
	var boss = game._make_enemy("bot", "courier", P.global_position + Vector3(0, 0, -3.0))
	await frames(70)
	boss.cool = 999.0
	boss.stagger(boss.poise + 1.0)
	await frames(2)
	var w0: float = boss.weak_t
	var bh: float = boss.hp
	await tap("assist")
	await frames(3)
	ok(boss.weak_t > w0 and bh - boss.hp > 30.0 and boss.alive(), "босс «ОТКРЫТ»: помощь напарника бьёт сильнее (%.0f) и продлевает окно (TEAM BREAK)" % (bh - boss.hp))
	# ================= 8. сохранение =================
	await stage()
	await tap("style3")
	await frames(80)
	await tap("tag")
	await frames(6)
	await tap("style2")
	await frames(80)
	T.hp["pahan"] = 42.0
	P.hp = 77.0
	await frames(2)
	T.auto_assist = false
	var saved: Dictionary = JSON.parse_string(JSON.stringify(T.save_data()))
	await stage()
	T.auto_assist = true
	T.load_data(saved)
	await frames(4)
	ok(P.hero == "madk1d" and P.style.id == "guitar" and P.heroes["pahan"]["style"] == "tyaga812" and abs(P.hp - 77.0) < 0.5 and abs(float(T.hp["pahan"]) - 42.0) < 3.5 and not T.auto_assist, "сохранение и загрузка: герой %s, стили %s / %s, здоровье %.0f и %.0f, настройка напарника сохранена" % [P.hero, P.style.id, P.heroes["pahan"]["style"], P.hp, T.hp["pahan"]])
	print("TAGCHECK ok" if fails == 0 else "TAGCHECK ОШИБОК: %d" % fails)
	get_tree().quit()

## -- --tagcheck=<папка> --ai: только поведение напарника, с построчным следом раз в полсекунды
func _ai_trace() -> void:
	await stage()
	T.auto_assist = true
	T.auto_t = 0.2
	var e1 = foe("bot", 2.2, 5.0)
	var e2 = game._make_enemy("bot", "", P.global_position + Vector3(2.5, 0, -2.0))
	e2.max_hp = 5.0
	e2.hp = 5.0
	for n in 600:
		e1.cool = 999.0
		e2.cool = 999.0
		await get_tree().physics_frame
		if n % 30 == 0:
			print("AI %d foe %s ft %.1f auto %.1f B %s tgt %s wait %.1f say %.1f anim %s ev %d e2 %s st %s dodge %.1f" % [n, B.foe != null, B.foe_t, T.auto_t, B.global_position, B.target, B.wait, B.say_t, B.anim.state, B.events.size(), e2.global_position, e2.state, B.dodge_cd])
	get_tree().quit()
