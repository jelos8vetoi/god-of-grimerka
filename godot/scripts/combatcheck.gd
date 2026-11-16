## Проверка ядра боя в игре: -- --combatcheck=<папка>, запускать с --fixed-fps 30 --resolution 1280x720.
## Настоящая глава, настоящий Пахан и три типа обычных врагов (бот, клиппер, хейтер). Проверяет:
## данные стилей, попадание и урон, защиту от двойного урона, буфер ввода и окна комбо, ветки комбо,
## переход лёгкий → тяжёлый, отмену перекатом, паузу против спама, перезарядку, равновесие, sweep-попадание.
## Печатает «COMBAT ok / ОШИБКА», в конце — «COMBAT итог: ошибок n». Снимки ключевых моментов — в папку.
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var started := false
var frame_n := 0
var log_hits: Array = []      # [id атаки, сколько целей]
var log_started: Array = []

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 200.0
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return true

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if P != null and is_instance_valid(P):
		cam.global_position = P.global_position + Vector3(4.6, 2.2, 1.6)
		cam.look_at(P.global_position + Vector3(0, 0.9, -1.2))
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("COMBAT ok: " if c else "COMBAT ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

## одно нажатие: один физический кадр
func tap(a: String) -> void:
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	P.auto_input = {}

func stage(kinds: Array, dist := 2.2) -> Array:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	P.hp = P.max_hp
	P.state = "move"
	P.swag = 0.0
	P.rage = 0.0
	P.inv = 0.0
	P.auto_input = {}
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	P.velocity = Vector3.ZERO
	P.combat.interrupt()
	P.combat.clear_buffer()
	P.combat.cooldowns = {}
	P.combat.chain_block = -9.0
	game.cam_yaw = 0.0
	game.buddy.global_position = Vector3(-6, 0.05, 8)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	cam.make_current()
	var list := []
	for i in kinds.size():
		var x := (i - (kinds.size() - 1) * 0.5) * 1.1
		game.spawn_enemy(kinds[i], P.global_position + Vector3(x, 0, -dist))
	await frames(4)
	for e in game.enemies:
		if is_instance_valid(e):
			e.state = "stun"          # стоят смирно: проверяем удары, а не их ИИ
			e.stun_t = 999.0
			e.t = 0.0
			list.append(e)
	P.inv = 9999.0
	if not P.combat.attack_hit.is_connected(_on_hit):
		P.combat.attack_hit.connect(_on_hit)
		P.combat.attack_started.connect(_on_start)
	log_hits = []
	log_started = []
	return list

func _on_hit(a: AttackData, n: int) -> void:
	log_hits.append([a.id, n])

func _on_start(a: AttackData) -> void:
	log_started.append(a.id)

## ждать, пока герой освободится
func until_free(max_frames := 240) -> void:
	var n := 0
	while P.state != "move" and n < max_frames:
		await get_tree().physics_frame
		n += 1

## нажимать действие, как только открывается окно комбо текущей атаки (правильный тайминг)
func chain(actions: Array) -> void:
	await tap(actions[0])
	for i in range(1, actions.size()):
		var n := 0
		while not P.combat.in_combo_window() and P.state in ["attack", "charge"] and n < 200:
			await get_tree().physics_frame
			n += 1
		await tap(actions[i])
		await frames(2)

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	# ---------- 1. данные ----------
	for id in Styles.ORDER:
		var s := Styles.by_id(id)
		var pr := s.problems()
		ok(pr.is_empty(), "стиль %s (%s, %s): данные согласованы%s%s" % [id, s.title, s.owner, "" if s.ready else " — объявлен, атак пока нет", "" if pr.is_empty() else ": " + "; ".join(pr)])
	var vz := Styles.by_id("vozduh")
	ok(vz.ready and vz.attacks.size() == 10 and Styles.of("pahan").size() == 3 and Styles.of("madk1d").size() == 3, "шесть стилей: по три у Пахана и madk1d; VOZDUH готов, атак %d" % vz.attacks.size())
	var clips_ok := true
	await stage([])
	for aid in vz.attacks:
		if not P.rig.has_clip((vz.attacks[aid] as AttackData).clip):
			clips_ok = false
	ok(clips_ok, "у каждой атаки VOZDUH есть клип в риге")

	# ---------- 2. попадание, урон, один удар — один раз ----------
	var es: Array = await stage(["bot", "clipper", "hater"])
	var hp0 := []
	for e in es:
		hp0.append(e.hp)
	await tap("attack")
	ok(P.state == "attack" and P.combat.cur != null and P.combat.cur.id == "vz_light1", "лёгкий удар из стойки: vz_light1, фаза %s" % P.combat.phase())
	var dealt_before := true
	while P.combat.cur != null and P.combat.phase() == "startup":
		for i in es.size():
			if es[i].hp < hp0[i]:
				dealt_before = false
		await get_tree().physics_frame
	ok(dealt_before, "до момента попадания урона нет (замах)")
	await frames(3)
	await shot("01_light_hit.png")
	await until_free()
	var want: float = vz.attack("vz_light1").damage
	var all_once := true
	for i in es.size():
		var lost: float = hp0[i] - es[i].hp
		if abs(lost - want) > 0.01:
			all_once = false
			print("   %s потерял %.1f, ожидалось %.1f" % [es[i].kind, lost, want])
	ok(all_once, "бот, клиппер и хейтер получили по %.0f урона ровно один раз (окно попадания открыто несколько кадров)" % want)
	ok(log_hits.size() == 1 and log_hits[0][1] == 3, "одно событие попадания на три цели (%s)" % str(log_hits))

	# ---------- 3. цепочка лёгких по таймингу ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	await chain(["attack", "attack", "attack", "attack"])
	await until_free()
	ok(log_started == ["vz_light1", "vz_light2", "vz_upper", "vz_slam"], "цепочка лёгких: %s" % str(log_started))

	# ---------- 4. ветки: тяжёлый после 0, 1, 2, 3 лёгких ----------
	var branch := {0: "vz_overhead", 1: "vz_nail", 2: "vz_fullswing", 3: "vz_spin"}
	for n in branch:
		es = await stage(["bot"])
		es[0].hp = 99999.0
		es[0].max_hp = 99999.0
		var acts := []
		for i in n:
			acts.append("attack")
		acts.append("heavy")
		await chain(acts)
		await frames(6)
		P.auto_input = {}              # тяжёлый не держим: заряд полного замаха отпускается сразу
		await until_free(400)
		ok(not log_started.is_empty() and log_started[log_started.size() - 1] == branch[n], "%d лёгких → тяжёлый: %s (%s)" % [n, branch[n], str(log_started)])
	await shot("02_branch.png")

	# ---------- 5. буфер ввода ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	await tap("attack")
	await frames(2)
	await tap("attack")                # нажато в самом начале замаха: слишком рано, буфер (0,3 с) истечёт до окна
	await until_free()
	ok(log_started == ["vz_light1"], "нажатие слишком рано (замах) цепочку не продолжает: %s" % str(log_started))
	es = await stage(["bot"])
	es[0].hp = 99999.0
	await tap("attack")
	var cf: float = P.combat.cur.combo_from
	while P.combat.cur != null and P.combat.k() < cf - 0.2:
		await get_tree().physics_frame
	var early: float = P.combat.k()
	await tap("attack")                # чуть раньше окна: буфер донесёт
	await until_free()
	ok(log_started.size() >= 2 and log_started[1] == "vz_light2", "нажатие чуть раньше окна (на %.2f при окне с %.2f) буфер доносит: %s" % [early, cf, str(log_started)])

	# ---------- 6. отмена перекатом ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	await tap("attack")
	await frames(3)
	await tap("roll")
	ok(P.state == "attack", "в замахе перекат удар не отменяет (фаза %s)" % P.combat.phase())
	while P.combat.cur != null and not P.combat.can_roll_cancel():
		await get_tree().physics_frame
	await tap("roll")
	ok(P.state == "roll" and P.combat.cur == null, "после попадания перекат отменяет удар")
	await until_free()

	# ---------- 7. без спама: оборванная цепочка даёт паузу ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	await tap("attack")
	await until_free()
	var t_end: float = P.combat.clock
	P.auto_input = {"attack": "press"}     # жмём каждый кадр
	var waited := 0
	while P.state != "attack" and waited < 60:
		await get_tree().physics_frame
		waited += 1
	P.auto_input = {}
	var gap: float = P.combat.clock - t_end
	ok(gap >= vz.chain_cd - 0.04 and P.state == "attack", "после оборванной цепочки новый удар — не раньше паузы (%.2f с при паузе %.2f)" % [gap, vz.chain_cd])
	await until_free()

	# ---------- 8. перезарядка атаки ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	var cd_attack: AttackData = vz.attack("vz_overhead").with({"id": "test_cd", "cooldown": 3.0})
	vz.attacks["test_cd"] = cd_attack
	var old_links: Dictionary = vz.links.duplicate(true)
	vz.links[""]["heavy"] = "test_cd"
	await tap("heavy")
	await until_free(400)
	var n1 := log_started.count("test_cd")
	await tap("heavy")
	await frames(4)
	ok(n1 == 1 and P.state == "move" and log_started.count("test_cd") == 1, "атака с перезарядкой второй раз подряд не запускается")
	vz.links = old_links
	vz.attacks.erase("test_cd")

	# ---------- 9. равновесие ----------
	es = await stage(["bot"])
	var bot = es[0]
	bot.hp = 99999.0
	bot.max_hp = 99999.0
	bot.state = "chase"
	bot.stun_t = 0.0
	bot.poise = bot.poise_max
	var broke := false
	for i in 6:
		var h := HitInfo.new()
		h.damage = 1.0
		h.stagger = 14.0
		h.dir = Vector3(0, 0, -1)
		bot.state = "wind" if i >= 3 else "chase"      # в замахе обычный удар раньше не прерывал
		bot.take_hit_info(h)
		if bot.state == "stun":
			broke = true
			ok(i >= 3, "равновесие (60) кончилось на %d-м ударе по 14: враг сбит и оглушён, замах прерван" % (i + 1))
			break
	ok(broke, "равновесие кончается, враг сбит")
	var boss_like = es[0]
	boss_like.poise = 5.0
	boss_like.state = "air"
	ok(not boss_like.stagger(50.0), "в воздухе равновесие не снимается")

	# ---------- 10. sweep: путь оружия задевает цель вне сектора ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	es[0].global_position = P.global_position + Vector3(1.3, 0, -1.0)      # справа-спереди, на пути маха: вне узкого сектора
	var narrow: AttackData = vz.attack("vz_light1").with({"id": "test_sector", "arc": 0.5})
	var sweep: AttackData = narrow.with({"id": "test_sweep", "detect": "sweep", "hit_lead": 0.14})
	P.face = PI
	P.auto_input = {}
	P.start_attack(narrow)
	P.face = PI
	await until_free()
	var by_sector := log_hits.size()
	log_hits = []
	P.start_attack(sweep)
	P.face = PI
	await until_free()
	await shot("03_sweep.png")
	ok(by_sector == 0 and log_hits.size() == 1, "узкий сектор цель сбоку не задел (%d), sweep по пути балона задел (%d)" % [by_sector, log_hits.size()])

	# ---------- 11. Heat-цепочка и заряд ----------
	es = await stage(["bot", "bot"])
	for e in es:
		e.hp = 99999.0
	P.swag = 100.0
	await tap("heat")
	await until_free(400)
	ok(log_started == ["vz_heat_smash", "vz_heat_swing"], "Heat: цепочка стиля %s" % str(log_started))
	es = await stage(["bot"])
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	await chain(["attack", "attack"])
	var n2 := 0
	while not P.combat.in_combo_window() and n2 < 200:
		await get_tree().physics_frame
		n2 += 1
	P.auto_input = {"heavy": "press"}
	await frames(2)
	P.auto_input = {"heavy": "hold"}
	await frames(40)                       # держим больше секунды
	ok(P.state == "charge" or P.combat.charged > 0.5, "полный замах заряжается удержанием (состояние %s)" % P.state)
	await frames(10)
	P.auto_input = {}
	var hp_before: float = es[0].hp
	await until_free(400)
	var lost2: float = hp_before - es[0].hp
	ok(lost2 > vz.attack("vz_fullswing").damage * 1.5, "заряженный удар сильнее обычного: %.0f урона при базе %.0f" % [lost2, vz.attack("vz_fullswing").damage])

	print("COMBAT итог: ошибок %d" % fails)
	get_tree().quit()
