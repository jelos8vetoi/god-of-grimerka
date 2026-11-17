## Проверка дуэт-атаки на [T] (duo.gd): -- --duocheck=<папка>, запускать с --resolution 1280x720.
## Все девять пар стилей в обе стороны (Пахан ведёт — madk1d помогает, и наоборот), воздушная версия,
## DUO FINISHER, слом равновесия и растущее сопротивление, босс, буфер во время удара, «нет цели»,
## смена героя посреди дуэта. Снимки — своей камерой сбоку, когда в кадре оба героя и цель.
## В конце — «DUOCHECK ok» или «DUOCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var T
var B
var D
var started := false
var frame_n := 0
const KEYS := {"vozduh": "style1", "bottles": "style2", "tyaga812": "style3", "skateboard": "style1", "guitar": "style2", "breaker": "style3"}

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
	print(("DUO ok: " if c else "DUO ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func tap(a: String) -> void:
	await get_tree().physics_frame
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}

## кадр сбоку: герой, напарник и цель
func close(name: String, e) -> void:
	var c: Vector3 = (P.global_position + B.global_position + (e.global_position if is_instance_valid(e) else P.global_position)) / 3.0
	var d: Vector3 = (e.global_position - P.global_position) if is_instance_valid(e) else Vector3(0, 0, -1)
	d.y = 0
	d = d.normalized() if d.length() > 0.05 else Vector3(0, 0, -1)
	var sd := d.cross(Vector3.UP)
	cam.global_position = c + sd * 5.2 + Vector3(0, 2.0, 0) - d * 1.0
	cam.look_at(c + Vector3(0, 0.9, 0), Vector3.UP)
	cam.fov = 55.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	cam.clear_current(true)

func wait_switch() -> void:
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 200:
		await get_tree().physics_frame
		n += 1

## сцена: ведёт hero со стилем mine, у напарника выбран стиль mate_s
func stage(hero: String, mine: String, mate_s: String) -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	T = game.tag
	B = game.buddy
	D = T.duo
	if P.hero != hero:
		game.swap_heroes()
	await frames(2)
	T.reset()
	T.auto_assist = false
	T.events = []
	D.events = []
	B.foe = null
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	if P.skate.on:
		P.skate.off()
	P.state = "move"
	P.inv = 9999.0
	P.swag = 0.0
	P.hp = P.max_hp
	P.auto_input = {}
	P.combat.interrupt()
	await wait_switch()
	if P.style.id != mine:
		await tap(KEYS[mine])
		await wait_switch()
	P.heroes[T.mate()]["style"] = mate_s
	B.global_position = Vector3(2.5, 0.05, 5.0)
	B.target = B.global_position
	B.wait = 999.0
	T.assist_cd = 0.0
	await frames(30)
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	await frames(4)

func foe(dist := 5.5, hp := 9999.0, kind := "bot"):
	var e = game._make_enemy(kind, "", P.global_position + Vector3(0, 0, -dist))
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

func has_ev(tag_s: String) -> bool:
	for x in D.events:
		if String(x[0]) == tag_s:
			return true
	return false

func ev(tag_s: String) -> Array:
	for x in D.events:
		if String(x[0]) == tag_s:
			return x
	return []

## провести дуэт до конца: снимок в момент продолжения
var near_b := 9.0
func run_duo(e, shot_name := "") -> void:
	near_b = 9.0
	await tap("assist")
	var n := 0
	var shot_done := shot_name == ""
	while (D.active() or D.buf_t > -9.0) and n < 300:
		await get_tree().physics_frame
		n += 1
		if D.phase == "follow" and is_instance_valid(e):
			near_b = min(near_b, Vector2(B.global_position.x - e.global_position.x, B.global_position.z - e.global_position.z).length())
		if not shot_done and D.phase == "follow" and D.t > 0.12:
			shot_done = true
			await close(shot_name, e)
	await frames(30)

## подбросить врага (для сцен, где подброс стилем не главное)
func launch(e, v := 9.0) -> void:
	var hl := HitInfo.new()
	hl.damage = 1.0
	hl.launch = v
	hl.dir = Vector3(0, 0, -1)
	e.take_hit_info(hl)

## ЛКМ, затем в окне связки ПКМ — подброс стилем
func style_launch(e) -> bool:
	await tap("attack")
	var n := 0
	while not P.combat.in_combo_window() and P.state == "attack" and n < 120:
		await get_tree().physics_frame
		n += 1
	await tap("heavy")
	n = 0
	while e.state != "air" and n < 90:
		await get_tree().physics_frame
		n += 1
	return e.state == "air"

## Tab по подсказке AIR TAG; вернуть [подсказка была, где она была относительно цели]
var air_gap := 99.0
func air_tag_run(e, shot_name := "") -> Array:
	var n := 0
	while not T.hint.visible and n < 40:
		await get_tree().physics_frame
		n += 1
	var seen: bool = T.hint.visible
	var kind: String = T.hint_kind
	var off: float = T.hint.global_position.distance_to(e.global_position) if is_instance_valid(e) else 99.0
	await tap("tag")
	n = 0
	air_gap = 99.0
	var shot_done := shot_name == ""
	while D.active() and n < 240:
		await get_tree().physics_frame
		n += 1
		if D.phase == "follow" and is_instance_valid(e):
			air_gap = min(air_gap, P.global_position.distance_to(e.global_position))
		if not shot_done and D.phase == "follow" and D.t > 0.05:
			shot_done = true
			await close(shot_name, e)
	return [seen, kind, off]

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	# ================= 1. девять пар в обе стороны =================
	var pairs_ok := 0
	var shots := 0
	for ps in ["vozduh", "bottles", "tyaga812"]:
		for ms in ["skateboard", "guitar", "breaker"]:
			for lead in ["pahan", "madk1d"]:
				var mine: String = ps if lead == "pahan" else ms
				var mate_s: String = ms if lead == "pahan" else ps
				await stage(lead, mine, mate_s)
				var e = foe()
				await frames(4)
				var hp0: float = e.hp
				var name := ""
				if shots < 18:
					name = "c_%s_%s_%s.png" % [lead, ps, ms]
					shots += 1
				await run_duo(e, name)
				var st: Array = ev("start")
				var en: Array = ev("end")
				var good: bool = st.size() > 0 and String(st[1]) == ps + "|" + ms and String(st[2]) == lead and en.size() > 0 and hp0 - e.hp > 25.0 and near_b < 2.0 and P.state != "charge" and not B.duo_on and P.state != "duo" and not D.active()
				if good:
					pairs_ok += 1
				ok(good, "%s ведёт (%s), напарник — %s: %s → концовка %s, урон %.0f, сбит: %s, напарник у цели (%.1f м), оба свободны (герой «%s»)" % [lead, mine, mate_s, str(st.slice(1, 4)), str(en.slice(1, 3)), hp0 - e.hp, str(has_ev("break")), near_b, P.state])
	ok(pairs_ok == 18, "все 18 сочетаний (9 пар × 2 стороны) прошли: %d" % pairs_ok)
	# ================= 2. в воздухе =================
	for row in [["pahan", "vozduh", "breaker"], ["madk1d", "skateboard", "bottles"], ["madk1d", "breaker", "tyaga812"]]:
		await stage(row[0], row[1], row[2])
		var ea = foe(3.5)
		await frames(4)
		var hl := HitInfo.new()
		hl.damage = 1.0
		hl.launch = 9.0
		hl.dir = Vector3(0, 0, -1)
		ea.take_hit_info(hl)
		await frames(6)
		var ah: float = ea.hp
		await run_duo(ea, "c_air_%s_%s.png" % [row[0], row[1]])
		var sa: Array = ev("start")
		ok(sa.size() > 3 and String(sa[3]) == "air" and has_ev("end") and ah - ea.hp > 20.0, "в воздухе: %s (%s) с напарником-%s — воздушная версия %s, урон %.0f" % [row[0], row[1], row[2], str(sa.slice(1, 4)), ah - ea.hp])
	# ================= 3. DUO FINISHER =================
	await stage("pahan", "vozduh", "breaker")
	var ef = foe(3.0, 60.0)
	await frames(4)
	ef.hp = 8.0
	ef.stun(3.0)
	await frames(2)
	await run_duo(ef, "c_finisher.png")
	await frames(90)
	ok(has_ev("finisher") and not ef.alive(), "враг «готов» — [T] дал DUO FINISHER (%s), враг добит: %s" % [str(ev("finisher")), str(not ef.alive())])
	# ================= 4. равновесие: слом и растущее сопротивление =================
	await stage("madk1d", "guitar", "vozduh")
	var es = foe(3.0)
	await frames(4)
	var pm0: float = es.poise_max
	await run_duo(es)
	var broke: bool = has_ev("break")
	var pm1: float = es.poise_max
	T.assist_cd = 0.0
	D.events = []
	await run_duo(es)
	ok(broke and pm1 > pm0 and es.break_n >= 1, "дуэт сбивает врага (СБИТ), после слома сбить труднее: равновесие %.0f → %.0f (сломов подряд %d)" % [pm0, es.poise_max, es.break_n])
	await frames(int(6.0 * 60))
	ok(es.break_n == 0 and abs(es.poise_max - pm0) < 0.5, "давно не сбивали — сопротивление спало (%.0f)" % es.poise_max)
	# ================= 5. босс =================
	await stage("pahan", "vozduh", "skateboard")
	var bid: String = String((game.story["BOSS"] as Dictionary).keys()[0])
	var eb = game._make_enemy("bot", bid, P.global_position + Vector3(0, 0, -5.0))
	eb.cool = 999.0
	await frames(90)
	eb.cool = 999.0
	var bh: float = eb.hp
	await run_duo(eb, "c_boss.png")
	ok(not has_ev("break") and has_ev("end") and bh - eb.hp > 0.0 and not B.duo_on, "босс: дуэт бьёт (урон %.0f), но с одного раза его не сбить; всё вернулось в бой" % (bh - eb.hp))
	if is_instance_valid(eb):
		eb.queue_free()
	# ================= 6. нет цели =================
	await stage("pahan", "vozduh", "guitar")
	await tap("assist")
	await frames(4)
	ok(has_ev("none") and T.assist_cd == 0.0 and not D.active(), "без врага — «нет цели», перезарядка не потрачена (%.1f)" % T.assist_cd)
	# ================= 7. буфер во время удара =================
	await stage("madk1d", "breaker", "bottles")
	var ebf = foe(2.0)
	ebf.stun(9.0)
	await frames(4)
	await tap("attack")
	await frames(3)
	await tap("assist")
	var buffered: bool = has_ev("buffer")
	var n := 0
	while not has_ev("start") and n < 90:
		await get_tree().physics_frame
		n += 1
	var started2: bool = has_ev("start")
	n = 0
	while D.active() and n < 300:
		await get_tree().physics_frame
		n += 1
	await frames(20)
	ok(buffered and started2 and has_ev("end"), "[T] посреди удара запомнился и сработал в окне связки (через %d кадров)" % n)
	# ================= 8. смена героя посреди дуэта =================
	await stage("pahan", "bottles", "skateboard")
	var ew = foe(5.5)
	await frames(4)
	await tap("assist")
	await frames(3)
	var blocked: String = T.tag_block()
	game.swap_heroes()        # даже напрямую (не через Tab) — постановка должна безопасно оборваться
	await frames(10)
	ok(blocked == "duo" and has_ev("abort") and not D.active() and not B.duo_on and P.state != "duo", "во время дуэта Tab заблокирован («%s»); смена героя напрямую — дуэт оборван безопасно (%s), никто не завис" % [blocked, str(ev("abort"))])
	if is_instance_valid(ew):
		ew.queue_free()
	# ================= 9. AIR TAG =================
	# Пахан подбрасывает балоном — madk1d продолжает каждым из трёх стилей
	for ms in ["skateboard", "guitar", "breaker"]:
		await stage("pahan", "vozduh", ms)
		var ea = foe(2.0)
		ea.stun(9.0)
		await frames(4)
		var up: bool = await style_launch(ea)
		var hp0: float = ea.hp
		var r: Array = await air_tag_run(ea, "c_airtag_pahan_%s.png" % ms)
		var reach_gap: float = air_gap
		await frames(10)
		ok(up and r[0] and r[1] == "AIR TAG" and r[2] < 2.6 and P.hero == "madk1d" and P.style.id == ms and has_ev("air_tag") and has_ev("relay_end") and hp0 - ea.hp > 5.0 and reach_gap < 2.0,
			"Пахан подбросил балоном (%s) → подсказка «%s» у врага (%.1f м) → Tab: madk1d (%s) прыгнул к цели (подлетел на %.1f м) и ударил в воздухе, урон %.0f" % [str(up), r[1], r[2], P.style.id, reach_gap, hp0 - ea.hp])
	# madk1d подбрасывает доской — Пахан продолжает бутылками
	await stage("madk1d", "skateboard", "bottles")
	var esk = foe(2.0)
	esk.stun(9.0)
	await frames(4)
	var up2: bool = await style_launch(esk)
	var hsk: float = esk.hp
	var r2: Array = await air_tag_run(esk, "c_airtag_madk_bottles.png")
	await frames(30)
	ok(up2 and r2[0] and P.hero == "pahan" and P.style.id == "bottles" and has_ev("relay_end") and hsk - esk.hp > 3.0, "madk1d подбросил доской (%s) → Tab: Пахан бросил бутылку в воздухе, урон %.0f" % [str(up2), hsk - esk.hp])
	# madk1d (брейк) подбросил — Пахан продолжает пылесосом
	await stage("madk1d", "breaker", "tyaga812")
	var ec = foe(2.5)
	await frames(4)
	launch(ec)
	await frames(6)
	var hc: float = ec.hp
	var r3: Array = await air_tag_run(ec, "c_airtag_madk_tyaga.png")
	await frames(20)
	ok(r3[0] and P.hero == "pahan" and P.style.id == "tyaga812" and hc - ec.hp > 5.0, "madk1d подбросил → Tab: Пахан с пылесосом выбросом вверх, урон %.0f" % (hc - ec.hp))
	# цепочка: туда-обратно-туда, и враг всё равно приземляется
	await stage("pahan", "vozduh", "breaker")
	var ed2 = foe(2.0)
	ed2.stun(9.0)
	await frames(4)
	await style_launch(ed2)
	var heroes_seq: Array = [P.hero]
	for i in 3:
		await air_tag_run(ed2)
		heroes_seq.append(P.hero)
		await frames(6)
	var tags: int = T.events.filter(func(x): return x[0] == "air_tag").size()
	var land_n := 0
	while ed2.state == "air" and land_n < 360:
		await get_tree().physics_frame
		land_n += 1
	ok(heroes_seq.size() >= 3 and heroes_seq[1] != heroes_seq[0] and heroes_seq[2] == heroes_seq[0] and tags >= 2 and ed2.state != "air", "цепочка передач: %s, передач за полёт %d; враг приземлился через %.1f с — вечного жонглирования нет" % [str(heroes_seq), tags, land_n / 60.0])
	# предел передач за полёт
	await stage("pahan", "vozduh", "guitar")
	var el = foe(2.5)
	await frames(4)
	launch(el, 12.0)
	await frames(4)
	el.air_tags = T.AIR_TAGS_MAX
	await frames(3)
	var no_hint: bool = not T.hint.visible and T.air_target() == null
	T.events = []
	await tap("tag")
	await frames(4)
	ok(no_hint and T.events.size() > 0 and String(T.events[T.events.size() - 1][0]) != "air_tag", "после %d передач за полёт подсказки нет, Tab — обычная смена (%s)" % [T.AIR_TAGS_MAX, str(T.events.back() if T.events.size() > 0 else [])])
	# два врага в воздухе — AIR RELAY
	await stage("madk1d", "guitar", "vozduh")
	var m1 = foe(2.5)
	var m2 = game._make_enemy("bot", "", P.global_position + Vector3(2.0, 0, -3.0))
	m2.state = "chase"
	m2.cool = 999.0
	m2.max_hp = 9999.0
	m2.hp = 9999.0
	await frames(4)
	launch(m1)
	launch(m2)
	await frames(6)
	var kind2: String = T.hint_kind
	await close("c_air_relay_hint.png", m1)
	var r4: Array = await air_tag_run(m1)
	ok(kind2 == "AIR RELAY" and P.hero == "pahan" and has_ev("air_tag"), "два врага в воздухе — подсказка «%s», Tab передаёт одного из них" % kind2)
	# обычная смена без врагов в воздухе
	await stage("pahan", "bottles", "skateboard")
	var en2 = foe(4.0)
	await frames(4)
	T.events = []
	await tap("tag")
	await frames(4)
	ok(not T.hint.visible and P.hero == "madk1d" and T.events.size() > 0 and String(T.events[0][0]) == "tag", "без врага в воздухе Tab — обычная смена (%s), подсказки нет" % str(T.events))
	# босс не летает — AIR TAG по нему не бывает
	await stage("pahan", "vozduh", "breaker")
	var bid2: String = String((game.story["BOSS"] as Dictionary).keys()[0])
	var bb = game._make_enemy("bot", bid2, P.global_position + Vector3(0, 0, -3.0))
	await frames(90)
	bb.cool = 999.0
	launch(bb, 12.0)
	await frames(6)
	ok(bb.state != "air" and T.air_target() == null and not T.hint.visible, "босса не подбросить — AIR TAG по нему нет")
	if is_instance_valid(bb):
		bb.queue_free()
	if is_instance_valid(en2):
		en2.queue_free()
	var _r = r4
	print("DUOCHECK ok" if fails == 0 else "DUOCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
