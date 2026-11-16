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
var cam_off := Vector3(4.6, 2.2, 1.6)
var cam_at := Vector3(0, 0.9, -1.2)

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
		cam.global_position = P.global_position + cam_off
		cam.look_at(P.global_position + cam_at)
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
	await get_tree().physics_frame
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}

## перейти на стиль и дождаться конца смены
func to_style(key: String) -> void:
	await tap(key)
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 90:
		await get_tree().physics_frame
		n += 1
	await frames(2)

## дождаться события пылесоса
func tg_event(name: String, max_frames := 240) -> bool:
	var n := 0
	while n < max_frames:
		for ev in P.tyaga.events:
			if ev[0] == name:
				return true
		await get_tree().physics_frame
		n += 1
	return false

## точка модели пылесоса в мире
func tg_point(pt: Vector3) -> Vector3:
	return P.tyaga.unit.global_transform * pt

func bone_pos(key: String) -> Vector3:
	return (P.rig.skel.global_transform * P.rig.skel.get_bone_global_pose(P.rig.bone[key])).origin

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
	if P.style.id != "vozduh" or P.switch_to != "":
		P.switch_to = "vozduh"
		P._finish_switch()
	P.combat.ammo = {}
	P.tyaga.heat = 0.0
	P.tyaga.lock = 0.0
	P.tyaga.events = []
	P.tyaga.mode = "off"
	P.tyaga.unit.visible = false
	P.tyaga._clear_ride()
	P.bottles.hits_log = []
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
	ok(vz.ready and vz.attacks.size() == 13 and Styles.by_id("bottles").ready and Styles.by_id("tyaga812").ready and Styles.of("pahan").size() == 3 and Styles.of("madk1d").size() == 3, "шесть стилей: по три у Пахана и madk1d; VOZDUH готов, атак %d" % vz.attacks.size())
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


	# ================= этап 05: стиль Балон VOZDUH =================
	var fb := []
	var on_fb := func(n: String, _pos: Vector3, _pw: float) -> void: fb.append(n)
	game.feedback_fired.connect(on_fb)
	# ---------- 12. тяжёлый → тяжёлый: удар сверху, затем удар по земле вокруг ----------
	es = await stage(["bot", "clipper", "hater"])
	for e in es:
		e.hp = 99999.0
		e.max_hp = 99999.0
	es[2].global_position = P.global_position + Vector3(0.4, 0, 2.2)      # хейтер за спиной: круговой удар достаёт и его
	var hp_h: float = es[2].hp
	await chain(["heavy", "heavy"])
	await frames(20)
	await shot("04_quake.png")
	await until_free(400)
	ok(log_started == ["vz_overhead", "vz_quake"], "тяжёлый → тяжёлый: %s" % str(log_started))
	ok(es[2].hp < hp_h, "удар по земле бьёт вокруг: враг за спиной получил %.0f" % (hp_h - es[2].hp))
	ok(fb.has("vz_heavy") and fb.has("vz_quake"), "у удара сверху и удара по земле свой отклик (%s)" % str(fb))

	# ---------- 13. подброс → удар в воздухе: на боте, клиппере и хейтере ----------
	for kind in ["bot", "clipper", "hater"]:
		es = await stage([kind])
		es[0].hp = 99999.0
		es[0].max_hp = 99999.0
		await chain(["attack", "attack", "attack"])
		var n3 := 0
		while es[0].state != "air" and n3 < 60:
			await get_tree().physics_frame
			n3 += 1
		var flew: bool = es[0].state == "air"
		var hp_a: float = es[0].hp
		var n4 := 0
		while not P.combat.in_combo_window() and P.state == "attack" and n4 < 200:
			await get_tree().physics_frame
			n4 += 1
		await tap("attack")
		var spiked := false
		for i in 50:
			await get_tree().physics_frame
			if es[0].spiked:
				spiked = true
		if kind == "bot":
			await shot("05_air_spike.png")
		await until_free(400)
		ok(flew and spiked and es[0].hp < hp_a, "%s: подброшен (%s), в воздухе вбит в землю (%s), урон %.0f" % [kind, flew, spiked, hp_a - es[0].hp])

	# ---------- 14. удар после уклонения ----------
	for pair in [["attack", "vz_roll_swing", "attack", "vz_light2"], ["heavy", "vz_roll_launch", "attack", "vz_slam"]]:
		es = await stage(["bot"])
		es[0].hp = 99999.0
		es[0].max_hp = 99999.0
		P.global_position = Vector3(0, 0.05, 6.4)       # перекат вперёд, к врагу
		P.auto_input = {"roll": "press", "move": Vector2(0, 1)}
		await frames(2)
		P.auto_input = {}
		await until_free()
		log_started = []
		await tap(pair[0])
		var first_id: String = log_started[0] if not log_started.is_empty() else ""
		var k0: float = P.combat.k() if P.combat.cur != null else -1.0
		var n5 := 0
		while not P.combat.in_combo_window() and P.state == "attack" and n5 < 200:
			await get_tree().physics_frame
			n5 += 1
		await tap(pair[2])
		await frames(3)
		ok(first_id == pair[1] and k0 > 0.2 and log_started.size() >= 2 and log_started[1] == pair[3], "после уклонения %s → %s с ходу (клип с %.2f), дальше %s: %s" % [pair[0], pair[1], k0, pair[3], str(log_started)])
		await until_free(400)
	es = await stage(["bot"])
	es[0].hp = 99999.0
	await frames(30)                                  # уклонения давно не было
	await tap("attack")
	ok(log_started == ["vz_light1"], "без уклонения — обычный первый удар: %s" % str(log_started))
	await until_free()

	# ---------- 15. замах удара сверху: нажатие — обычный удар, удержание — усиленный ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	var h0: float = es[0].hp
	await tap("heavy")
	await until_free(400)
	var tap_dmg: float = h0 - es[0].hp
	es = await stage(["bot"])              # первый удар отбросил врага: ставим заново
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	h0 = es[0].hp
	P.auto_input = {"heavy": "press"}
	await frames(2)
	P.auto_input = {"heavy": "hold"}
	await frames(30)
	var in_charge: bool = P.state == "charge" and P.rig.cur == "OverheadCharge"
	await shot("06_overhead_charge.png")
	P.auto_input = {}
	await until_free(400)
	var hold_dmg: float = h0 - es[0].hp
	ok(abs(tap_dmg - 60.0) < 0.01 and in_charge and hold_dmg > tap_dmg * 1.25, "удар сверху: нажатие — %.0f урона, удержание секунду (замах над головой) — %.0f" % [tap_dmg, hold_dmg])

	# ---------- 16. вес: равновесие и разный стоп-кадр ----------
	es = await stage(["bot"])
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	es[0].stun_t = 0.0
	es[0].state = "chase"
	es[0].poise = es[0].poise_max
	fb.clear()
	await chain(["attack", "heavy"])
	await until_free(400)
	ok(es[0].poise < es[0].poise_max - 40.0 or es[0].state == "stun", "лёгкий + ГВОЗДЬ снимают больше 40 равновесия из 60 (осталось %.0f, состояние %s)" % [es[0].poise, es[0].state])
	var stops := {}
	for n in ["hit_light", "vz_launcher", "vz_heavy", "vz_slam", "vz_finisher", "vz_quake"]:
		stops[n] = float(Feedback.EVENTS[n]["stop"])
	ok(stops["hit_light"] < stops["vz_launcher"] and stops["vz_launcher"] < stops["vz_heavy"] and stops["vz_heavy"] < stops["vz_finisher"] and stops["vz_finisher"] < stops["vz_slam"] and stops["vz_slam"] < stops["vz_quake"],
		"стоп-кадр растёт с весом удара: лёгкий %.3f < подброс %.3f < тяжёлый %.3f < завершающий %.3f < в землю %.3f < по земле %.3f с" % [stops["hit_light"], stops["vz_launcher"], stops["vz_heavy"], stops["vz_finisher"], stops["vz_slam"], stops["vz_quake"]])
	ok(fb.has("hit_light") and fb.has("vz_finisher"), "в бою сработали разные отклики (%s)" % str(fb))
	game.feedback_fired.disconnect(on_fb)


	# ================= этап 06: стиль «Водяра» =================
	var bt := Styles.by_id("bottles")
	ok(bt.ready and bt.problems().is_empty() and bt.ammo_max == 6, "стиль bottles готов: атак %d, запас %d, восстановление %.1f с" % [bt.attacks.size(), bt.ammo_max, bt.ammo_regen])
	# ---------- 17. смена стиля ----------
	es = await stage([])
	await tap("style2")
	ok(P.state == "switch", "[2]: началась смена стиля (балон уходит за спину)")
	await to_style("style2")
	ok(P.style.id == "bottles" and P.rig.holstered and P.state == "move", "стиль — бутылки, балон в чехле за спиной")
	await frames(6)
	ok(P.bottles.prop_att.visible and P.rig.cur == "BottleIdle", "бутылка в руке, стойка с бутылкой (клип %s)" % P.rig.cur)
	await shot("07_bottle_idle.png")
	ok(game.style_label.text.begins_with("[2] Водяра") and game.style_label.text.count("●") == 6, "HUD: %s" % game.style_label.text)

	# ---------- 18. быстрый бросок по боту, клипперу и хейтеру ----------
	for kind in ["bot", "clipper", "hater"]:
		es = await stage([kind], 7.0)
		await to_style("style2")
		var hp_b: float = es[0].hp
		await tap("attack")
		var flew_n := 0
		var seen_air := false
		while P.bottles.hits_log.is_empty() and flew_n < 90:
			await get_tree().physics_frame
			flew_n += 1
			if not P.bottles.flying.is_empty() and not seen_air:
				seen_air = true
				if kind == "bot":
					await shot("08_bottle_flight.png")
		await frames(2)
		if kind == "bot":
			await shot("09_bottle_splash.png")
		var hit_enemy: bool = not P.bottles.hits_log.is_empty() and P.bottles.hits_log[0]["kind"] == "enemy"
		ok(seen_air and hit_enemy and abs((hp_b - es[0].hp) - 9.0) < 0.01 and es[0].slow_t > 0.0, "%s на 7 м: бутылка летела, попала, урон %.0f, замедлен на %.1f с (×%.2f)" % [kind, hp_b - es[0].hp, es[0].slow_t, es[0].slow_k])
		await until_free()
	ok(abs(P.combat.ammo_of("bottles") - 5.0) < 0.6, "бросок тратит бутылку (осталось %.1f)" % P.combat.ammo_of("bottles"))

	# ---------- 19. мимо: бутылка разбивается об окружение ----------
	es = await stage([])
	await to_style("style2")
	await tap("attack")
	var wn := 0
	while P.bottles.hits_log.is_empty() and wn < 120:
		await get_tree().physics_frame
		wn += 1
	ok(not P.bottles.hits_log.is_empty() and P.bottles.hits_log[0]["kind"] == "world", "без цели бутылка летит вперёд и разбивается о землю (через %d кадров)" % wn)
	await until_free()

	# ---------- 20. усиленный бросок: прицел, оглушение, всплеск ----------
	es = await stage(["bot", "clipper"], 6.0)
	es[1].global_position = es[0].global_position + Vector3(1.5, 0, 0.3)
	await to_style("style2")
	var hp_p: float = es[0].hp
	P.auto_input = {"heavy": "press"}
	await frames(2)
	P.auto_input = {"heavy": "hold"}
	await frames(18)
	var dots_on := 0
	for d in P.bottles.dots:
		if d.visible:
			dots_on += 1
	ok(P.state == "charge" and P.rig.cur == "BottleAim" and dots_on >= 10, "удержание ПКМ: прицел, бутылка занесена, траектория из %d точек" % dots_on)
	await shot("10_bottle_aim.png")
	P.auto_input = {}
	var pn := 0
	while P.bottles.hits_log.is_empty() and pn < 120:
		await get_tree().physics_frame
		pn += 1
	await frames(2)
	var first: Dictionary = P.bottles.hits_log[0] if not P.bottles.hits_log.is_empty() else {}
	var main_e = first.get("enemy", null)
	var other = es[1] if main_e == es[0] else es[0]
	ok(main_e != null and (hp_p - es[0].hp > 16.0 or main_e == es[1]) and main_e.state == "stun", "усиленный: цель оглушена (%s), урон по ней больше обычного" % (main_e.state if main_e != null else "—"))
	ok(other.slow_t > 0.0 and not P.bottles.dots[0].visible, "всплеск намочил соседа (замедлен на %.1f с), прицел убран" % other.slow_t)
	await until_free()

	# ---------- 21. бутылка сбивает слабый замах ----------
	es = await stage(["bot"], 6.0)
	await to_style("style2")
	es[0].stun_t = 0.0
	es[0].state = "wind"
	es[0].t = -5.0                 # долгий замах: успеем попасть
	await tap("attack")
	var qn := 0
	while P.bottles.hits_log.is_empty() and qn < 90:
		es[0].state = "wind" if es[0].state == "wind" else es[0].state
		await get_tree().physics_frame
		qn += 1
	ok(es[0].state != "wind", "враг в замахе: после бутылки замах сбит (состояние %s)" % es[0].state)
	await until_free()

	# ---------- 22. запас: кончается и восстанавливается ----------
	es = await stage(["bot"], 7.0)
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	await to_style("style2")
	var thrown := 0
	P.combat.attack_started.connect(func(_a): thrown += 1, CONNECT_ONE_SHOT)
	log_started = []
	P.auto_input = {"attack": "press"}          # жмём каждый кадр 6 секунд
	await frames(360)                          # физика идёт 60 раз в секунду
	P.auto_input = {}
	await until_free()
	var per6 := log_started.size()
	ok(per6 <= 8 and P.combat.ammo_of("bottles") < 1.5, "спам 6 секунд: брошено %d (запас 6 + восстановление), осталось %.1f — бесконечно не выйдет" % [per6, P.combat.ammo_of("bottles")])
	P.combat.ammo["bottles"] = 0.0
	log_started = []
	await tap("attack")
	await frames(4)
	ok(log_started.is_empty() and P.state == "move", "без бутылок бросок не начинается")
	await frames(200)
	ok(P.combat.ammo_of("bottles") >= 1.0, "через 3,3 с бутылка восстановилась (%.1f)" % P.combat.ammo_of("bottles"))

	# ---------- 23. бросок → балон → тяжёлый ----------
	es = await stage(["bot"], 4.5)
	es[0].hp = 99999.0
	es[0].max_hp = 99999.0
	await to_style("style2")
	log_started = []
	await tap("attack")
	while P.combat.cur != null and P.combat.hit_i == 0:
		await get_tree().physics_frame
	var t_throw: float = P.combat.clock
	await tap("style1")
	var sw: bool = P.state == "switch"
	await frames(4)
	await tap("heavy")                          # нажато во время смены: должно сработать сразу после
	var hn := 0
	while not log_started.has("vz_overhead") and hn < 90:
		await get_tree().physics_frame
		hn += 1
	var gap2: float = P.combat.clock - t_throw
	await frames(12)
	await shot("11_throw_to_balon.png")
	ok(sw and log_started.has("vz_overhead") and P.style.id == "vozduh" and not P.rig.holstered and gap2 < 0.8, "бросок → [1] → ПКМ: смена сразу после вылета бутылки, балон в руке, тяжёлый удар через %.2f с после броска" % gap2)
	await until_free(400)

	# ---------- 24. бросок после уклонения ----------
	es = await stage(["bot"], 8.0)
	es[0].hp = 99999.0
	await to_style("style2")
	P.auto_input = {"roll": "press", "move": Vector2(1, 0)}
	await frames(2)
	P.auto_input = {}
	await until_free()
	log_started = []
	await tap("attack")
	ok(log_started == ["bt_roll"], "после уклонения — бросок с ходу: %s" % str(log_started))
	await until_free()
	ok(bt.attack("bt_quick").damage < vz.attack("vz_light1").damage * 0.5 and bt.attack("bt_power").damage < vz.attack("vz_overhead").damage * 0.5, "баланс: бутылка бьёт слабее половины удара балона (%.0f и %.0f против %.0f и %.0f)" % [bt.attack("bt_quick").damage, bt.attack("bt_power").damage, vz.attack("vz_light1").damage, vz.attack("vz_overhead").damage])
	await stage([])


	# ================= этап 07: ТЯГА-812 =================
	var tg := Styles.by_id("tyaga812")
	ok(tg.ready and tg.problems().is_empty() and tg.attacks.size() == 5, "стиль tyaga812 готов: воздействий %d (притягивание, выстрел, выброс, таран, волчок)" % tg.attacks.size())
	cam_off = Vector3(3.6, 1.9, 2.6)
	cam_at = Vector3(0, 0.8, -0.6)
	# ---------- 25. [3]: пылесос выкатывается, руки на трубе ----------
	es = await stage([])
	await tap("style3")
	await frames(6)
	var rolling: bool = P.tyaga.unit.visible and P.tyaga.unit.position.distance_to(TyagaClips.V_HOLD) > 0.5
	await to_style("style3")
	await frames(40)
	var rh: float = bone_pos("rhand").distance_to(tg_point(TyagaClips.TUBE_HI))
	var lh: float = bone_pos("lhand").distance_to(tg_point(TyagaClips.TUBE_LO))
	ok(rolling and P.style.id == "tyaga812" and P.state == "tyaga" and P.tyaga.mode == "hold" and P.rig.holstered, "[3]: пылесос выкатился из-за спины (не возник на месте), стиль ТЯГА-812, балон за спиной")
	ok(rh < 0.22 and lh < 0.22, "обе руки на трубе: правая в %.2f м от верхнего хвата, левая в %.2f м от нижнего (запястье–кулак ≈ 0,15)" % [rh, lh])
	var wheels: float = P.tyaga.unit.global_position.y - P.global_position.y
	ok(abs(wheels) < 0.03, "пылесос стоит на земле (%.3f м)" % wheels)
	await shot("12_tyaga_hold.png")
	ok(game.style_label.text.begins_with("[3] ТЯГА-812"), "HUD: %s" % game.style_label.text)

	# ---------- 26. MODE 2: притягивание — бот, клиппер, хейтер ----------
	for kind in ["bot", "clipper", "hater"]:
		es = await stage([kind], 5.5)
		await to_style("style3")
		await frames(30)
		var d0: float = es[0].global_position.distance_to(P.global_position)
		var hp_s: float = es[0].hp
		P.auto_input = {"attack": "hold"}
		var min_d := d0
		var mid_d := d0
		for i in 150:
			await get_tree().physics_frame
			min_d = min(min_d, es[0].global_position.distance_to(P.global_position))
			if i == 30:
				mid_d = es[0].global_position.distance_to(P.global_position)
				if kind == "bot":
					await shot("13_tyaga_suck.png")
		var was_caught: bool = P.tyaga.caught.has(es[0].get_instance_id())
		if kind == "bot":
			await shot("14_tyaga_caught.png")
		P.auto_input = {}
		await frames(4)
		ok(mid_d < d0 - 0.8 and mid_d > 1.6 and min_d < 2.4 and was_caught and es[0].hp < hp_s, "%s: тянет постепенно (%.1f → %.1f м через полсекунды → %.1f), пойман у сопла, урон тиками %.0f" % [kind, d0, mid_d, min_d, hp_s - es[0].hp])
	# ограничения: не больше трёх сразу, тяжёлого не берёт, сзади не берёт
	es = await stage(["bot", "bot", "bot", "bot", "bot"], 5.0)
	await to_style("style3")
	await frames(30)
	P.auto_input = {"attack": "hold"}
	var max_pull := 0
	for i in 40:
		await get_tree().physics_frame
		max_pull = max(max_pull, P.tyaga.pulling.size())
	P.auto_input = {}
	ok(max_pull == 3, "из пяти врагов в потоке тянет одновременно не больше трёх (%d)" % max_pull)
	es = await stage(["troll", "bot"], 5.0)
	await to_style("style3")
	await frames(30)
	var troll = es[0] if es[0].kind == "troll" else es[1]
	var small = es[1] if es[0].kind == "troll" else es[0]
	small.global_position = P.global_position + Vector3(0, 0, 4.0)       # за спиной
	var td: float = troll.global_position.distance_to(P.global_position)
	var sd: float = small.global_position.distance_to(P.global_position)
	P.auto_input = {"attack": "hold"}
	await frames(70)
	P.auto_input = {}
	ok(abs(troll.global_position.distance_to(P.global_position) - td) < 0.4 and abs(small.global_position.distance_to(P.global_position) - sd) < 0.4, "тяжёлого тролля поток не сдвигает, врага за спиной не трогает")

	# ---------- 27. MODE 3: воздушный выстрел и выброс по области ----------
	for kind in ["bot", "clipper", "hater"]:
		es = await stage([kind], 3.5)
		await to_style("style3")
		await frames(30)
		var hp_v: float = es[0].hp
		var pos_v: Vector3 = es[0].global_position
		await tap("heavy")
		await frames(4)
		if kind == "bot":
			await shot("15_tyaga_shot.png")
		await frames(30)
		ok(abs((hp_v - es[0].hp) - 14.0) < 0.01 and es[0].global_position.distance_to(pos_v) > 2.0, "%s: воздушный выстрел — урон %.0f, отброшен на %.1f м" % [kind, hp_v - es[0].hp, es[0].global_position.distance_to(pos_v)])
	es = await stage(["bot", "clipper", "hater"], 2.0)
	es[0].global_position = P.global_position + Vector3(2.0, 0, -0.8)
	es[2].global_position = P.global_position + Vector3(-1.6, 0, -1.6)
	await to_style("style3")
	await frames(30)
	var hps := [es[0].hp, es[1].hp, es[2].hp]
	P.auto_input = {"heavy": "press"}
	await frames(2)
	P.auto_input = {"heavy": "hold"}
	await frames(36)
	var charging: bool = P.tyaga.mode == "charge"
	P.auto_input = {}
	await frames(5)
	await shot("16_tyaga_burst.png")
	await frames(20)
	var all3 := true
	for i in 3:
		if abs((hps[i] - es[i].hp) - 30.0) > 0.01:
			all3 = false
	ok(charging and all3 and P.tyaga.heat > 40.0, "выброс по области: заряд удержанием, все трое вокруг сопла получили по 30, нагрев %.0f" % P.tyaga.heat)
	# притянул → выброс: пойманный получает в полтора раза больше
	es = await stage(["bot"], 4.0)
	es[0].hp = 9999.0
	es[0].max_hp = 9999.0
	await to_style("style3")
	await frames(30)
	P.auto_input = {"attack": "hold"}
	var cn := 0
	while not P.tyaga.caught.has(es[0].get_instance_id()) and cn < 200:
		await get_tree().physics_frame
		cn += 1
	var hp_c: float = es[0].hp
	P.auto_input = {"attack": "hold", "heavy": "press"}
	await frames(2)
	P.auto_input = {"heavy": "hold"}
	await frames(24)
	P.auto_input = {}
	await frames(8)
	ok(hp_c - es[0].hp >= 45.0 - 0.01, "притянул → выброс: пойманный получил %.0f (30 × 1,5 и тики)" % (hp_c - es[0].hp))

	# ---------- 28. нагрев ----------
	es = await stage([])
	await to_style("style3")
	await frames(30)
	P.auto_input = {"attack": "hold"}
	var hot_at := -1
	for i in 480:
		await get_tree().physics_frame
		if P.tyaga.lock > 0.0 and hot_at < 0:
			hot_at = i
	var still: bool = P.tyaga.mode != "suck"
	P.auto_input = {}
	ok(hot_at > 300 and hot_at < 420 and still, "притягивание без остановки: перегрев через %.1f с, работа прервана" % (hot_at / 60.0))
	await frames(200)
	ok(P.tyaga.lock <= 0.0 and P.tyaga.heat < 60.0, "остывает сам: через 3,3 с снова работает (нагрев %.0f)" % P.tyaga.heat)

	# ---------- 29. MODE 1: езда ----------
	cam_off = Vector3(4.4, 2.0, 0.6)
	cam_at = Vector3(0, 0.8, 0.0)
	es = await stage([])
	P.global_position = Vector3(0, 0.05, 9.0)
	await to_style("style3")
	await frames(30)
	await tap("heat")
	await frames(12)
	var mid_mount: Vector3 = P.tyaga.unit.position
	await shot("17_tyaga_mount.png")
	await frames(30)
	var seat_w: Vector3 = tg_point(TyagaClips.SEAT)
	var hips_w: Vector3 = bone_pos("hips")
	var rh2: float = bone_pos("rhand").distance_to(tg_point(TyagaClips.TUBE_MID))
	ok(P.tyaga.mode == "ride" and mid_mount.distance_to(TyagaClips.V_HOLD) > 0.05 and mid_mount.distance_to(TyagaClips.V_RIDE) > 0.05, "посадка: пылесос подкатился под героя плавно (в середине он между двумя положениями), режим — езда")
	ok(Vector2(hips_w.x - seat_w.x, hips_w.z - seat_w.z).length() < 0.18 and hips_w.y - seat_w.y > 0.0 and hips_w.y - seat_w.y < 0.28, "герой сидит на корпусе: таз над сиденьем (сбоку %.2f м, выше на %.2f м)" % [Vector2(hips_w.x - seat_w.x, hips_w.z - seat_w.z).length(), hips_w.y - seat_w.y])
	ok(rh2 < 0.22, "правая рука на трубе-рычаге (%.2f м)" % rh2)
	await shot("18_tyaga_seat.png")
	# разгон
	var z0: float = P.global_position.z
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(75)
	var v1: float = P.tyaga.speed
	await shot("19_tyaga_ride.png")
	P.auto_input = {"move": Vector2(0, 1), "sprint": "hold"}
	await frames(40)
	var v2: float = P.tyaga.speed
	ok(v1 > 9.5 and v2 > 13.0 and z0 - P.global_position.z > 9.0 and P.tyaga.heat > 5.0, "разгон до %.1f м/с, с ускорением %.1f м/с (греется: %.0f), проехал %.1f м" % [v1, v2, P.tyaga.heat, z0 - P.global_position.z])
	# руление и занос
	es = await stage([])
	P.global_position = Vector3(-6, 0.05, 8.0)
	await to_style("style3")
	await frames(30)
	await tap("heat")
	await frames(40)
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(60)
	var h_before: float = P.tyaga.heading
	P.auto_input = {"move": Vector2(1, 0)}
	await frames(30)
	var steered: float = abs(angle_difference(h_before, P.tyaga.heading))
	var lean_seen: float = abs(P.body.rotation.z)
	P.auto_input = {"move": Vector2(0, -1), "block": "hold"}
	var slip := 0.0
	for i in 26:
		await get_tree().physics_frame
		slip = max(slip, Vector3(sin(P.tyaga.heading), 0, cos(P.tyaga.heading)).angle_to(P.tyaga.vdir))
		if i == 14:
			await shot("20_tyaga_drift.png")
	ok(steered > 0.9 and lean_seen > 0.05, "руление: нос повернул на %.1f рад за полсекунды, корпус накренился (%.2f рад)" % [steered, lean_seen])
	ok(slip > 0.25, "занос: тело несёт боком — угол между носом и движением до %.2f рад" % slip)
	# разворот на месте
	es = await stage([])
	P.global_position = Vector3(0, 0.05, 8.0)
	await to_style("style3")
	await frames(30)
	await tap("heat")
	await frames(40)
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(60)
	var h_f: float = P.tyaga.heading
	P.auto_input = {"move": Vector2(0, -1), "block": "hold"}
	var flipped: bool = await tg_event("flip", 60)
	await frames(30)
	ok(flipped and abs(abs(angle_difference(h_f, P.tyaga.heading)) - PI) < 0.5, "занос + назад: разворот (нос повернулся на %.2f рад)" % abs(angle_difference(h_f, P.tyaga.heading)))
	# прыжок
	P.auto_input = {"move": Vector2(0, -1)}
	await frames(30)
	P.auto_input = {"move": Vector2(0, -1), "roll": "press"}
	await get_tree().physics_frame
	P.auto_input = {"move": Vector2(0, -1)}
	var top_y := 0.0
	for i in 50:
		await get_tree().physics_frame
		top_y = max(top_y, P.global_position.y)
		if i == 16:
			await shot("21_tyaga_jump.png")
	var landed: bool = await tg_event("land", 60)
	ok(top_y > 0.9 and landed, "прыжок на пылесосе: высота %.1f м, приземление" % top_y)
	# таран и удар с разворота — бот, клиппер, хейтер
	for kind in ["bot", "clipper", "hater"]:
		es = await stage([kind], 9.0)
		P.global_position = Vector3(0, 0.05, 9.0)
		es[0].global_position = Vector3(0, 0.05, 0.0)
		await to_style("style3")
		await frames(30)
		await tap("heat")
		await frames(40)
		var hp_r: float = es[0].hp
		P.auto_input = {"move": Vector2(0, 1)}
		var rammed: bool = await tg_event("ram", 200)
		var v_ram: float = P.tyaga.speed
		if kind == "bot":
			await frames(3)
			await shot("22_tyaga_ram.png")
		await frames(20)
		ok(rammed and hp_r - es[0].hp > 15.0 and es[0].global_position.z < -2.0, "%s: таран на скорости — урон %.0f, отлетел на %.1f м, скорость после %.1f" % [kind, hp_r - es[0].hp, -es[0].global_position.z, v_ram])
	es = await stage(["bot", "clipper"], 9.0)
	P.global_position = Vector3(0, 0.05, 6.0)
	es[0].global_position = Vector3(1.2, 0.05, 4.6)
	es[1].global_position = Vector3(-1.3, 0.05, 5.4)
	await to_style("style3")
	await frames(30)
	await tap("heat")
	await frames(40)
	P.tyaga.events = []
	await tap("attack")
	await frames(10)
	await shot("23_tyaga_spin.png")
	var spun: bool = await tg_event("spin", 60)
	var spin_n := 0
	for ev in P.tyaga.events:
		if ev[0] == "spin":
			spin_n = ev[1]
	ok(spun and spin_n == 2, "удар с разворота на ходу задел обоих врагов по бокам (%d)" % spin_n)
	# сход и сбитие с пылесоса
	await frames(30)
	await tap("heat")
	await frames(40)
	ok(P.tyaga.mode == "hold" and P.tyaga.unit.position.distance_to(TyagaClips.V_HOLD) < 0.05 and abs(P.body.rotation.z) < 0.01, "сход: герой на ногах, пылесос вернулся к руке, крен снят")
	await tap("heat")
	await frames(40)
	P.inv = 0.0
	P.take_damage(5.0, P.global_position + Vector3(0, 0, -2))
	await frames(6)
	ok(P.tyaga.mode == "hold" and P.state in ["hurt", "tyaga"], "удар по герою сбивает с пылесоса (режим %s)" % P.tyaga.mode)
	P.inv = 9999.0
	await frames(40)
	# обратно на балон
	await to_style("style1")
	await frames(30)
	ok(P.style.id == "vozduh" and not P.rig.holstered and not P.tyaga.unit.visible and P.state == "move", "[1]: пылесос откатился и убран, балон в руке")
	cam_off = Vector3(4.6, 2.2, 1.6)
	cam_at = Vector3(0, 0.9, -1.2)
	await stage([])

	print("COMBAT итог: ошибок %d" % fails)
	get_tree().quit()
