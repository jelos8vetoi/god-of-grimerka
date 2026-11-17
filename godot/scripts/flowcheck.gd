## Проверка Weapon Flow (этап 11): -- --flowcheck=<папка>, запускать с --resolution 1280x720.
## Все переходы между стилями каждого героя (12 пар), отмена удара в смену, Perfect Swap и его ограничения,
## прерывание смены ударом по герою, быстрые нажатия подряд. Следит, что управление возвращается, оружие не
## дублируется, а здоровье и СВЭГ героя не сбрасываются. В конце — «FLOWCHECK ok» или «FLOWCHECK ОШИБОК: n».
extends Node

const SETS := {"pahan": ["vozduh", "bottles", "tyaga812"], "madk1d": ["skateboard", "guitar", "breaker"]}

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var F: WeaponFlow
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
	print(("FLOW ok: " if c else "FLOW ОШИБКА: ") + msg)
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
	F = P.flow
	if P.hero != hero:
		game.swap_heroes()
	await frames(2)
	game.tag.reset()
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.9
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.swag = 0.0
	P.hp = P.max_hp
	P.auto_input = {}
	P.combat.interrupt()
	F.events = []
	F.boost_t = 0.0
	F.perfect_cd = 0.0
	F.last_from = ""
	F.last_to = ""
	game.buddy.global_position = Vector3(-9, 0.05, 10)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await frames(8)

func foe(dist := 2.2):
	var e = game._make_enemy("bot", "", P.global_position + Vector3(0, 0, -dist))
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = 9999.0
	e.hp = 9999.0
	return e

func key_of(id: String) -> String:
	return "style%d" % ((SETS[P.hero] as Array).find(id) + 1)

## дождаться конца смены; сколько секунд шла
func wait_switch(max_frames := 150) -> float:
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n / 60.0

## поставить стиль без проверок (подготовка сцены)
func put(id: String) -> void:
	if P.style.id == id:
		return
	await tap(key_of(id))
	await wait_switch()
	await frames(50)

## что у героя в руках и на виду — для поиска дублей оружия
func weapons() -> String:
	var seen: Array = []
	if P.hero == "pahan":
		if not P.rig.holstered:
			seen.append("vozduh")
		if P.bottles.prop != null and P.bottles.prop.is_visible_in_tree():
			seen.append("bottles")
		if P.tyaga.unit.is_visible_in_tree():
			seen.append("tyaga812")
	else:
		for k in P.m_weapons:
			if (P.m_weapons[k]["att"] as Node3D).is_visible_in_tree():
				seen.append(k)
	return ",".join(seen)

func last() -> String:
	return String(F.events[F.events.size() - 1][0]) if F.events.size() > 0 else ""

## ударить и дождаться: when = "hit" (сразу после попадания) или "window" (окно комбо)
func strike_until(action: String, when: String) -> void:
	await tap(action)
	var n := 0
	while n < 200:
		if P.state == "attack" and P.combat.hit_i > 0 and (when == "hit" or P.combat.in_combo_window()):
			break
		await get_tree().physics_frame
		n += 1
	if when == "hit":
		await frames(3)

func _run() -> void:
	# ================= 1. все переходы каждого героя =================
	var shot_n := 0
	for hero in ["pahan", "madk1d"]:
		for a in SETS[hero]:
			for b in SETS[hero]:
				if a == b:
					continue
				await stage(hero)
				await put(a)
				P.hp = 61.0
				P.swag = 37.0
				await frames(2)
				await tap(key_of(b))
				await frames(3)
				var began: bool = P.switch_to == b
				var sec: float = await wait_switch()
				await frames(40)
				var want: String = "" if b == "breaker" else b
				var free: bool = P.state in ["move", "tyaga"]
				ok(began and P.style.id == b and free and weapons() == want and abs(P.hp - 61.0) < 0.01 and abs(P.swag - 37.0) < 0.01 and sec < 0.6, "%s → %s: %.2f с, в руках «%s», управление вернулось (%s), здоровье и СВЭГ на месте" % [a, b, sec, weapons(), P.state])
				if [a, b] in [["vozduh", "bottles"], ["bottles", "tyaga812"], ["tyaga812", "vozduh"], ["skateboard", "guitar"], ["guitar", "breaker"], ["breaker", "skateboard"]]:
					shot_n += 1
					await shot("%02d_%s_to_%s.png" % [shot_n, a, b])
	# ================= 2. отмена удара в смену =================
	await stage("pahan")
	await put("vozduh")
	var e = foe()
	await frames(4)
	await strike_until("attack", "hit")
	var k_at: float = P.combat.k()
	await tap("style2")
	await frames(2)
	ok(last() == "cancel" and P.state == "switch" and k_at < 0.9, "удар попал — его можно оборвать сменой стиля (на %.0f%% удара)" % (k_at * 100.0))
	await wait_switch()
	await stage("pahan")
	await put("vozduh")
	await tap("attack")            # врага нет: промах
	await frames(14)
	await tap("style2")
	await frames(3)
	ok(P.state == "attack" and P.switch_to == "" and P.style.id == "vozduh", "промахнулся — удар сменой не оборвать, надо доиграть")
	var n := 0
	while P.state == "attack" and n < 200:
		await get_tree().physics_frame
		n += 1
	await stage("pahan")
	await put("vozduh")
	e = foe()
	await frames(4)
	await tap("attack")
	n = 0
	while not P.combat.in_combo_window() and n < 200:
		await get_tree().physics_frame
		n += 1
	await tap("heavy")              # завершитель цепочки
	n = 0
	while not (P.combat.cur != null and P.combat.cur.kind == "finisher" and P.combat.hit_i > 0) and n < 200:
		await get_tree().physics_frame
		n += 1
	var fin_id: String = P.combat.cur.id if P.combat.cur != null else "?"
	await frames(2)
	await tap("style2")
	await frames(3)
	ok(P.state == "attack" and P.switch_to == "", "завершитель цепочки (%s) сменой не обрывается" % fin_id)
	# ================= 3. Perfect Swap =================
	await stage("pahan")
	await put("vozduh")
	e = foe()
	await frames(4)
	await strike_until("attack", "window")
	var chain0: int = P.combat.chain
	var sw: float = P.swag
	await tap("style2")
	await frames(2)
	await shot("07_perfect_swap.png")
	var sec_p: float = await wait_switch()
	ok(F.events.any(func(x): return x[0] == "perfect_done") and sec_p < 0.36 and F.bonus() > 1.0 and P.combat.chain == chain0 + 1 and P.swag - sw >= 8.0 and P.combat.clock <= float(P.combat.windows.get("perfect", -9.0)), "смена в окне комбо — PERFECT SWAP: %.2f с вместо 0,42, удар усилен ×%.2f, цепочка продолжается (%d → %d), СВЭГ +%.0f, окно особого ответа открыто" % [sec_p, F.bonus(), chain0, P.combat.chain, P.swag - sw])
	# обычная ранняя отмена — не Perfect
	await stage("pahan")
	await put("vozduh")
	e = foe()
	await frames(4)
	await strike_until("attack", "hit")
	var early: bool = not P.combat.in_combo_window()
	await tap("style2")
	var sec_n: float = await wait_switch()
	ok(early and last() == "cancel" and F.bonus() == 1.0 and sec_n > 0.35, "смена сразу после попадания, до окна комбо, — обычная: %.2f с, без усиления" % sec_n)
	# усиление: одно попадание
	await stage("madk1d")
	await put("skateboard")
	e = foe()
	await frames(4)
	await strike_until("attack", "window")
	await tap("style3")
	await wait_switch()
	var perf: bool = F.bonus() > 1.0
	e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 2.0
	var h0: float = e.hp
	await tap("attack")
	n = 0
	while P.combat.hit_i == 0 and n < 120:
		await get_tree().physics_frame
		n += 1
	await frames(3)
	var first_id: String = P.combat.cur.id if P.combat.cur != null else "?"
	var dealt: float = h0 - e.hp
	ok(perf and first_id == "br_counter" and F.bonus() == 1.0 and dealt > 24.0 * 1.3, "скейт → Breaker в окне комбо: первый удар — особый ответ (%s), урон %.1f (усилен), усиление потрачено одним попаданием" % [first_id, dealt])
	# туда-обратно и пауза
	await stage("madk1d")
	await put("skateboard")
	e = foe()
	await frames(4)
	await strike_until("attack", "window")
	await tap("style2")
	await wait_switch()
	var p1: bool = F.events.any(func(x): return x[0] == "perfect_done")
	F.events = []
	F.perfect_cd = 0.0
	e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 2.0
	await frames(2)
	await strike_until("attack", "window")
	await tap("style1")
	await wait_switch()
	ok(p1 and not F.events.any(func(x): return x[0] == "perfect_done") and P.style.id == "skateboard", "скейт → гитара → сразу обратно в скейт: второй раз Perfect Swap не засчитан")
	await stage("madk1d")
	await put("skateboard")
	e = foe()
	await frames(4)
	await strike_until("attack", "window")
	await tap("style2")
	await wait_switch()
	F.events = []
	e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 2.0
	await frames(2)
	await strike_until("attack", "window")
	await tap("style3")
	await wait_switch()
	ok(not F.events.any(func(x): return x[0] == "perfect_done") and P.style.id == "breaker", "два Perfect Swap подряд без паузы не получить (пауза %.1f с)" % WeaponFlow.PERFECT_CD)
	# ================= 4. прерывание и спам =================
	await stage("pahan")
	await put("vozduh")
	await tap("style3")
	await frames(6)
	P.inv = 0.0
	P.take_damage(8.0, P.global_position + Vector3(0, 0, -2))
	P.inv = 9999.0
	await frames(50)
	ok(P.style.id == "tyaga812" and P.switch_to == "" and P.state in ["move", "tyaga"] and weapons() == "tyaga812", "героя ударили посреди смены: стиль доведён до конца (%s), в руках «%s», управление есть" % [P.style.id, weapons()])
	for hero in ["pahan", "madk1d"]:
		await stage(hero)
		for i in 24:
			P.auto_input = {"style%d" % (i % 3 + 1): "press"}
			await get_tree().physics_frame
			P.auto_input = {}
			await frames(randi() % 9)
		await wait_switch()
		await frames(60)
		var id: String = P.style.id
		ok(P.switch_to == "" and P.state in ["move", "tyaga"] and weapons() == ("" if id == "breaker" else id), "%s: 24 быстрых нажатия смены стиля — не застрял, в руках «%s» (стиль %s)" % [hero, weapons(), id])
	print("FLOWCHECK ok" if fails == 0 else "FLOWCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
