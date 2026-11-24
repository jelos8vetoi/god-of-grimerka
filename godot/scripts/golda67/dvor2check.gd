## Проверка нового ДВОРА в настоящем забеге «ГОЛДА 67»: `--resolution 1280x720 -- --dvor2check=<папка>`.
## Игра запускается как у игрока (main.start_golda67 → подъезд → выход во двор), дальше:
## один район и точка старта; ходьба настоящей клавишей W; враги на постах не нападают; три ступени начала боя; убийство врага
## во время подготовки; победа и сумка (одна, один раз); первый побег без награды и возвращение с половиной; второй побег —
## группа ушла; обязательная встреча не блокирует путь к Мише; сохранение и продолжение забега; Миша в коробке; решётка арки;
## новый забег — район пересоздан. К месту встречи героя ведёт проверка (перестановкой по шагам, без клавиш) — это помечено «[ведёт проверка]».
## Сохранения игрока не трогаются (G67Save.clean). Строки «DVOR2CHECK ok/ОШИБКА: …», итог «DVOR2CHECK итог: ошибок N».
extends Node

const KEEP := ["user://grimerka_save.json"]
var main
var out := ""
var fails := 0
var kept := {}
var g
var G: Golda67
var P

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().contains("grimerka-checks"):
		# забег пишет сохранение приквела: без отдельной папки данных проверка испортит сохранение игрока
		print("DVOR2CHECK ОШИБКА: запускать только через node tools/checks.cjs dvor2 (своя папка данных)")
		print("DVOR2CHECK итог: ошибок 1")
		get_tree().quit.call_deferred()
		return
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	AudioServer.set_bus_mute(0, true)
	G67Save.clean = true
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("DVOR2CHECK ok: " if cond else "DVOR2CHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm + ".png"))

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## [ведёт проверка] Довести героя до точки плана шагами по 7 м/с (без клавиш и без преград); stop — остановиться, когда условие выполнилось
func lead(x: float, y: float, stop := Callable()) -> void:
	var to := G67Dvor2.to3(x, y, 0.05)
	for i in 6000:
		var d: Vector3 = to - P.global_position
		d.y = 0.0
		if d.length() < 0.4 or (stop.is_valid() and stop.call()):
			break
		P.global_position += d.normalized() * minf(d.length(), 7.0 / 60.0)
		P.velocity = Vector3.ZERO
		P.face = atan2(d.x, d.z)
		await get_tree().physics_frame

## [ведёт проверка] Уйти из боя: герой переставляется за границу отступления и стоит там полсекунды
func run_away(x: float, y: float) -> void:
	for i in 30:
		P.global_position = G67Dvor2.to3(x, y, 0.05)
		P.velocity = Vector3.ZERO
		await get_tree().physics_frame

func st(id: String) -> String:
	return String(G.turf.enc(id)["state"])

func foes(id: String) -> int:
	return G.turf._alive(G.turf.enc(id))

func kill_enc(id: String, sec := 40.0) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if st(id) != "fight":
			return st(id) == "cleared"
		for e in G.turf.enc(id)["foes"]:
			if is_instance_valid(e) and e.state != "dead":
				e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
		await wait(0.2)
	return false

## Сумка открыла выбор бафа — берём первый предложенный, как игрок
var picked: Array = []
func pick_fit() -> void:
	await wait(0.4)
	if G.hub_ui != null and String(G.hub_ui.kind) == "fit" and not G.fit_offer.is_empty():
		var id := String(G.fit_offer[0])
		for o in G.fit_offer:              # «ЦЕПЬ НА УДАЧУ» меняет суммы голды, которые проверка сверяет ниже, — её не берём
			if String(o) != "gold_chain":
				id = String(o)
				break
		picked.append(id)
		G.take_fit(id)
		await wait(0.4)

## Встать перед жителем лицом к нему (на расстоянии dist)
func face_npc(f: Dictionary, dist: float) -> void:
	var r: Node3D = f["rig"]
	var off := Vector3(sin(r.rotation.y), 0.0, cos(r.rotation.y)) * dist
	P.global_position = r.global_position + off + Vector3(0, 0.05, 0)
	P.velocity = Vector3.ZERO
	P.face = atan2(-off.x, -off.z)
	g.cam_yaw = atan2(off.x, off.z)

func folk_by(id: String) -> Dictionary:
	for f in G.folk.folk:
		if String(f["id"]) == id:
			return f
	return {}

func folk_log(kind: String, id: String) -> bool:
	return G.folk.log.any(func(e): return String(e[0]) == kind and String(e[1]) == id)

## Пройти разговор события до конца, как игрок, — клавишей подтверждения
func skip_dialog() -> void:
	for i in 80:
		if g.mode != "dlg":
			return
		g._dlg_advance()
		await wait(0.12)

## Дождаться окна выбора и выбрать вариант
func pick_choice(key: String, sec := 8.0) -> bool:
	await until(func(): return G.hub_ui != null and String(G.hub_ui.kind) == "choice", sec)
	if G.hub_ui == null or String(G.hub_ui.kind) != "choice":
		return false
	G.hub_ui.pick(key)
	await wait(0.25)
	return true

func goal_text() -> String:
	return String(G.minimap.goal()["text"]) if G.minimap != null else ""

## Кадр мини-карты в названном месте: герой переносится, карта и маршрут успевают обновиться
func map_shot(nm: String, x: float, y: float) -> void:
	P.global_position = G67Dvor2.to3(x, y, 0.05)
	P.velocity = Vector3.ZERO
	await wait(1.6)
	await shot(nm)

func ev_point(id: String) -> Vector3:
	for pt in G.world.points:
		if String(pt["id"]) == id:
			return pt["pos"]
	return Vector3.INF

## Пять событий двора: разговор, дело, исход, награда один раз
func events_block() -> void:
	var E: G67DvorEvents = G.dvev
	ok(E != null and E.npcs.size() == 5, "в проверке поставлены все пять событий (%d)" % (E.npcs.size() if E != null else -1))
	# --- АРМРЕСТЛИНГ: два попадания в «ДАВАЙ»
	G.run["golda"] = 100
	var hh: int = G.fit_lv("heavy_hand")
	P.global_position = ev_point("evdv_arm") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_arm")
	await skip_dialog()
	await until(func(): return G.hub_ui != null, 3.0)
	ok(G.hub_ui != null and String(G.hub_ui.kind) == "choice", "АРМРЕСТЛИНГ: после разговора открыт выбор")
	await wait(0.4)
	await shot("a23_choice")
	ok(await pick_choice("ask"), "выбор: «А без денег?»")
	await skip_dialog()
	ok(await pick_choice("go") and E.state("arm") == "task", "после ответа Саныча выбор открыт снова; «Давай» — сел за стол")
	ok(int(G.run["golda"]) == 100 - G67DvorEvents.ARM_STAKE, "ставка 20 снята")
	for r in 4:
		if E.state("arm") != "task":
			break
		await until(func(): return E.beat_open() or E.state("arm") != "task", 8.0)
		G.use("evdv_arm")
		await until(func(): return not E.beat_open(), 4.0)
	await wait(0.3)
	ok(E.state("arm") == "done" and int(G.run["golda"]) >= 100 and (G.fit_lv("heavy_hand") == hh + 1 or hh >= 3), "победа: ставка вернулась, ТЯЖЁЛАЯ РУКА %d → %d" % [hh, G.fit_lv("heavy_hand")])
	ok(points("evdv_arm") == 0, "событие закрыто, точки нет")
	# --- МАШИНА В СУГРОБЕ: три промаха (жмём рано)
	P.global_position = ev_point("evdv_stuck") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_stuck")
	await skip_dialog()
	await pick_choice("go")
	for r in 3:
		await wait(0.25)
		G.use("evdv_stuck")              # раньше «ДАВАЙ»
		await until(func(): return float(E.st.get("t", 0.0)) < 0.0 or E.state("stuck") != "task", 6.0)
		await until(func(): return float(E.st.get("t", 0.0)) >= 0.0 or E.state("stuck") != "task", 4.0)
	await wait(0.3)
	ok(E.state("stuck") == "fail" and float(G.run.get("discount", 0.0)) == 0.0, "три промаха — машина села, скидки нет")
	# --- ХОЛОДИЛЬНИК: несём шагом
	var gold_f: int = int(G.run["golda"])
	P.global_position = ev_point("evdv_fridge") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_fridge")
	await skip_dialog()
	await pick_choice("go")
	await wait(0.3)
	ok(is_equal_approx(E.slow, G67DvorEvents.FRIDGE_SLOW) and P.speed_k < 0.7, "с холодильником герой идёт медленно (скорость ×%.2f)" % P.speed_k)
	await shot("a19_fridge")
	for i in 900:
		if E.state("fridge") != "task":
			break
		P.global_position += Vector3(-0.35, 0, -1).normalized() * (2.0 / 60.0)      # от дома во двор: вдоль фасада мешают крыльцо и лавки
		P.velocity = Vector3.ZERO
		await get_tree().physics_frame
	ok(E.state("fridge") == "done" and int(G.run["golda"]) > gold_f and is_equal_approx(E.slow, 1.0), "донёс: +%d голды, скорость вернулась" % (int(G.run["golda"]) - gold_f))
	ok(G.item_n("thermos") == 1, "донёс не качнув: термос — в кармане (расходник)")
	P.hp = P.max_hp * 0.5
	var hp_t: float = P.hp
	ok(G.use_item("thermos") and P.hp > hp_t + 20.0 and G.item_n("thermos") == 0, "термос выпит: +%d здоровья, расходник потрачен" % int(P.hp - hp_t))
	P.hp = P.max_hp
	ok(not G.use_item("thermos"), "без термоса кнопка ничего не делает")
	# --- КЛЮЧИ: варежка, фольга, ворона, обратно
	var lv_sum := 0
	for k in (G.run["fits"] as Dictionary):
		lv_sum += int(G.run["fits"][k])
	P.global_position = ev_point("evdv_keys") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_keys")
	await skip_dialog()
	await pick_choice("go")
	for i in 2:
		P.global_position = ev_point("evdv_keys_%d" % i) + Vector3(0, 0.05, 0)
		await wait(0.3)
		G.use("evdv_keys_%d" % i)
		await wait(0.3)
	P.global_position = ev_point("evdv_keys_2") + Vector3(1.5, 0.05, 0)
	P.velocity = Vector3.ZERO
	await until(func(): return points("evdv_keys_3") == 1, 12.0)
	ok(points("evdv_keys_3") == 1, "постоял у вороны — она бросила ключи")
	P.global_position = ev_point("evdv_keys_3") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_keys_3")
	await wait(0.3)
	var lv_sum2 := 0
	for k in (G.run["fits"] as Dictionary):
		lv_sum2 += int(G.run["fits"][k])
	ok(E.state("keys") == "done" and lv_sum2 == lv_sum + 1, "ключи вернул: жетон улучшения дал +1 уровень бафу")
	# --- ОЧЕРЕДЬ
	P.global_position = ev_point("evdv_queue") + Vector3(0, 0.05, 0)
	await wait(0.3)
	G.use("evdv_queue")
	await skip_dialog()
	await pick_choice("go")
	P.global_position = (E.st["spot"] as Vector3) + Vector3(0, 0.05, 0)
	P.velocity = Vector3.ZERO
	await shot("a20_queue")
	await until(func(): return E.state("queue") != "task", 30.0)
	ok(E.state("queue") == "done", "ОЧЕРЕДЬ: отстоял 20 с, ничего не дали")
	ok(int(G.run.get("ev_done", 0)) == 4, "пройдено событий: %d (армрестлинг, холодильник, ключи, очередь)" % int(G.run.get("ev_done", 0)))
	ok(E.act == "" and G.room_state == "open" and not G.busy, "после событий забег идёт дальше")
	G.run.erase("ev_done")
	await more_block()

## Выбор стороны в конфликтах, расходники, сделки торговцев, «Бурмалда» и кнопка, патруль
func more_block() -> void:
	# --- парковка: забрать табуретку
	var pk: Dictionary = G.turf.add_extra("parking")
	ok(not pk.is_empty() and (pk["foes"] as Array).is_empty(), "парковка: спор жителей, врагов нет")
	P.global_position = G67Dvor2.to3(21.0, -106.0, 0.05)
	P.velocity = Vector3.ZERO
	var asked: bool = await until(func(): return G.hub_ui != null and String(G.hub_ui.kind) == "choice", 10.0)
	ok(asked, "подошёл к спорщикам — открыт выбор стороны")
	await wait(0.4)
	await shot("a24_parking")
	await pick_choice("stool")
	ok(String(pk["state"]) == "gone" and G.item_n("stool") == 1, "забрал табуретку: спор окончен, табуретка — расходник")
	# табуретка оглушает врага
	var foe = G._make_foe(String(G67Data.FOES.keys()[0]), P.global_position + Vector3(0, 0, 3.0), true)
	P.face = 0.0
	await wait(1.3)
	ok(G.use_item("stool") and foe.stun_t > 1.0 and G.item_n("stool") == 0, "табуретка брошена: враг оглушён на %.1f с" % foe.stun_t)
	g.enemies.erase(foe)
	foe.queue_free()
	await wait(0.3)
	# --- гараж деда: «подеритесь, я посмотрю»
	var gs: Dictionary = G.turf.add_extra("garage_split")
	P.global_position = G67Dvor2.to3(-110.0, 50.0, 0.05)
	P.velocity = Vector3.ZERO
	ok(await until(func(): return G.hub_ui != null and String(G.hub_ui.kind) == "choice", 10.0), "гараж деда: «рассуди» — открыт выбор")
	await pick_choice("wait")
	ok(String(gs["state"]) == "cleared" and points("bag_garage_split") == 1, "подождал: подрались сами, сумка лежит")
	var g_w: int = int(G.run["golda"])
	G.use("bag_garage_split")
	await wait(0.3)
	ok(int(G.run["golda"]) - g_w >= 12 and G.hub_ui == null, "в сумке 12 голды, бафа нет")
	# --- патруль ходит
	var pt: Dictionary = G.turf.add_extra("patrol")
	var c0: Vector3 = pt["c"]
	P.global_position = G67Dvor2.to3(-6.0, -100.0, 0.05)
	await wait(3.0)
	ok((pt["c"] as Vector3).distance_to(c0) > 1.5 and (pt["foes"] as Array).size() == 2, "патруль из двоих идёт по проезду: сдвинулся на %.1f м" % (pt["c"] as Vector3).distance_to(c0))
	# --- торговцы: термос, обмен, сделка
	G.run["golda"] = 300
	G.run["fits"] = {"semki": 1}
	G.apply_fits()
	var sh0: String = G.shop
	G.shop = "petrovich"
	var th0: int = G.item_n("thermos")
	ok(G._trade_buy("pt_thermos") != "" and G.item_n("thermos") == th0 + 1, "Петрович: термос куплен — лежит в кармане (%d)" % G.item_n("thermos"))
	ok(G._trade_why("pt_swap") == "", "Петрович: обмен доступен, когда есть баф")
	G._swap_begin()
	await pick_choice("semki")
	ok(G.hub_ui != null and String(G.hub_ui.kind) == "choice" and G.fit_lv("semki") == 0, "обмен: баф отдан, на выбор — два других")
	var two: Array = G.hub_ui.items.map(func(it): return String(it["key"])) if G.hub_ui != null else []
	if two.size() > 0:
		await pick_choice(String(two[0]))
	ok(two.size() == 2 and G.fit_lv(String(two[0])) == 1 and (G.run["fits"] as Dictionary).size() == 1, "обмен: взят один из двух, бафов столько же")
	G.shop = "zhora"
	var mhp: float = P.max_hp
	var risk: String = G._trade_pick("zh_risk")
	ok(risk != "" and G._trade_why("zh_risk") == "" and G.kiosk_price("zh_risk") == 0, "Жора: сделка бесплатная, под ней редкий баф «%s»" % risk)
	G._trade_buy("zh_risk")
	ok(G.fit_lv(risk) == 1 and is_equal_approx(P.max_hp, mhp - G67Data.FLAW_HP), "сделка: баф получен, максимум здоровья %d → %d" % [int(mhp), int(P.max_hp)])
	G.shop = sh0
	G.run.erase("flaw")
	G.run["fits"] = {}
	G.apply_fits()
	# --- кнопка и «Бурмалда» на улице
	ok(points("ev_button") == 1 and points("ev_burmalda") == 1, "на улице стоят автомат «Бурмалда» и кнопка")
	P.global_position = ev_point("ev_button") + Vector3(0, 0.05, 0)
	await wait(0.6)
	await shot("a25_button")
	G.use("ev_button")
	var btn: bool = await until(func(): return G.room_state == "open" and not G.ev_busy and bool((G.run.get("ev_short", {}) as Dictionary).get("button", false)), 40.0)
	ok(btn and points("ev_button") == 0, "кнопка нажата: сцена отыграла, забег идёт дальше")
	P.hp = P.max_hp
	P.global_position = ev_point("ev_burmalda") + Vector3(0, 0.05, 0)
	await wait(0.6)
	await shot("a26_burmalda")
	G.use("ev_burmalda")
	await until(func(): return not G.ev_busy and int(G.run.get("ev_pulls", 0)) >= 1, 40.0)
	ok(int(G.run.get("ev_pulls", 0)) == 1 and G.room_state == "reward", "«Бурмалда»: первый рывок отыгран")
	P.global_position += Vector3(0, 0, 6.0)
	var brm: bool = await until(func(): return G.room_state == "open" and bool((G.run.get("ev_short", {}) as Dictionary).get("burmalda", false)), 12.0)
	ok(brm, "отошёл — автомат замолчал, событие закрыто")
	ok(int(G.world.dvor.count.get("windows", 0)) > 0, "свет в окнах: проходов поверх фасадов %d" % int(G.world.dvor.count.get("windows", 0)))

## Жители и торговец нового двора: приветствие, удар настоящей клавишей, реакции, лавка
func folk_block() -> void:
	var F: G67DvorFolk = G.folk
	ok(F != null and F.folk.filter(func(x): return not String(x["id"]).begins_with("ev_")).size() == 14, "в районе 14 жителей (%d)" % (F.folk.size() if F != null else -1))
	var who := String(G.run.get("trader", ""))
	ok(not F.trader.is_empty() and points("trader_dv") == 1 and who in ["petrovich", "zhora"], "в забеге один торговец: %s" % who)
	# приветствие
	var bab := folk_by("bab_bench")
	bab["cd"] = 0.0                     # кадры мини-карты у подъезда могли уже вызвать приветствие
	G.folk.log = G.folk.log.filter(func(e): return String(e[0]) != "greet")
	G.barks_get().last_line = {}
	G.barks_get().last_any = -1000.0
	face_npc(bab, 2.6)
	await until(func(): return folk_log("greet", "bab_bench"), 30.0)
	ok(folk_log("greet", "bab_bench"), "бабушка у подъезда здоровается, когда Пахан рядом (состояние %s, cd %.1f, до героя %.1f м, удары по мирным %d)" % [String(bab["state"]), float(bab["cd"]), (bab["rig"] as Node3D).global_position.distance_to(P.global_position), int(G.run.get("npc_hits", 0))])
	await shot("a16_folk_babushka")
	# удар настоящей клавишей: школьник убегает
	var gold_b: int = int(G.run["golda"])
	var resp_b: int = int(G.run.get("respect", 0))
	var kid := folk_by("school_phone")
	var kid_home: Vector3 = (kid["rig"] as Node3D).global_position
	face_npc(kid, 1.1)
	await wait(0.4)
	Input.action_press("attack")
	await wait(0.12)
	Input.action_release("attack")
	await until(func(): return folk_log("hit", "school_phone"), 3.0)
	ok(folk_log("hit", "school_phone") and int(G.run.get("npc_hits", 0)) == 1, "удар по школьнику засчитан (клавишей удара)")
	await wait(2.5)
	ok(String(kid["state"]) in ["away", "return"] and (kid["rig"] as Node3D).global_position.distance_to(kid_home) > 3.0, "школьник убегает (%.1f м от места)" % (kid["rig"] as Node3D).global_position.distance_to(kid_home))
	ok(int(G.run["golda"]) - gold_b < 10 and int(G.run.get("respect", 0)) == resp_b and is_instance_valid(kid["rig"]), "за удар по мирному нет ни голды, ни респекта, житель цел")
	await shot("a17_folk_flee")
	# мужик у гаражей отталкивает
	var us := folk_by("ushanka_gsk")
	face_npc(us, 1.1)
	await wait(0.4)
	Input.action_press("attack")
	await wait(0.12)
	Input.action_release("attack")
	await until(func(): return folk_log("hit", "ushanka_gsk"), 3.0)
	ok(folk_log("hit", "ushanka_gsk") and String(us["state"]) == "sulk", "мужик у гаражей не убегает, а отвечает")
	var hp_b: float = P.hp
	await until(func(): return folk_log("back", "ushanka_gsk") or folk_log("back_miss", "ushanka_gsk"), 3.0)
	ok(folk_log("back", "ushanka_gsk") and P.hp < hp_b and P.hp >= 1.0, "мужик дал сдачи: здоровье %d → %d" % [int(hp_b), int(P.hp)])
	P.hp = P.max_hp
	await wait(1.0)
	# торговец
	G.run["golda"] = 500
	var elite_was := ""
	var tr: Dictionary = F.trader
	face_npc(tr, 1.6)
	await wait(0.6)
	if who == "zhora":
		G.use("trader_dv")
		await wait(0.3)
		ok(G.hub_ui == null, "Жора не торгует, пока смотрящий на месте")
		for e in G.turf.encs:
			if String(e["id"]) == "elite_sofa":
				elite_was = String(e["state"])
				e["state"] = "cleared"          # только на время проверки лавки, ниже возвращается
				G.turf._keep(e)
	G.use("trader_dv")
	await wait(0.6)
	ok(G.hub_ui != null and String(G.hub_ui.kind) == "kiosk" and G.shop == who, "лавка торговца открылась: %s" % G.shop)
	var its: Array = G.shop_items()
	ok(its.size() >= 2, "на полке товаров: %d (%s)" % [its.size(), ", ".join(its.map(func(k): return String(k["name"])))])
	await shot("a18_trader_shop")
	var it0: Dictionary = its[0]
	var pr: int = G.kiosk_price(String(it0["id"]))
	var got_s: String = G.kiosk_buy(String(it0["id"]))
	ok(got_s != "" and int(G.run["golda"]) == 500 - pr, "покупка «%s» за %d: %s" % [String(it0["name"]), pr, got_s])
	ok(G.kiosk_buy(String(it0["id"])) == "", "второй раз тот же товар не продаётся")
	if G.hub_ui != null:
		G.hub_ui.close()
	await wait(0.5)
	if elite_was != "":
		for e in G.turf.encs:
			if String(e["id"]) == "elite_sofa":
				e["state"] = elite_was
				G.turf._keep(e)
	ok(G.shop_next == "kiosk", "после лавки окно «ШАУРМЫ 67» снова показывает своё меню")
	# ударить торговца — лавка закрыта до конца забега
	face_npc(tr, 1.1)
	await wait(0.4)
	Input.action_press("attack")
	await wait(0.12)
	Input.action_release("attack")
	await until(func(): return F.trader_closed(), 3.0)
	G.use("trader_dv")
	await wait(0.4)
	ok(F.trader_closed() and G.hub_ui == null, "ударенный торговец закрыл лавку")
	ok(F.cold(), "после трёх ударов по мирным район здоровается холодно (ударов %d)" % int(G.run.get("npc_hits", 0)))
	G.run["golda"] = gold_b
	G.run["npc_hits"] = 0

func worlds() -> int:
	return get_tree().root.find_children("*", "G67Dvor2", true, false).size()

func points(id: String) -> int:
	var n := 0
	for pt in G.world.points:
		if String(pt["id"]) == id:
			n += 1
	return n

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(1.5)
	await main.start_golda67()
	g = main.game
	G = g.golda
	P = g.player
	G.auto_clips = false
	ok(not Golda67.old_yard, "обычный забег идёт в новом районе (old_yard выключен)")
	ok(G.place == "hub", "игра открылась в подъезде")
	await G.start_run("dvor")
	await wait(0.6)
	# ================= район и старт =================
	ok(G.world.dvor != null and G.world.yard == null, "забег построил новый ДВОР, прежнего двора нет")
	ok(worlds() == 1, "район один (экземпляров G67Dvor2: %d)" % worlds())
	ok(G.world.dvor.missing.is_empty(), "все модели района на месте (нет файлов: %d)" % G.world.dvor.missing.size())
	var sp: Vector3 = G67Dvor2.to3(G67Dvor2.START.x, G67Dvor2.START.y, 0.05)
	ok(P.global_position.distance_to(sp) < 1.5, "Пахан стоит у двери подъезда дома 67")
	ok(G.turf != null and G.turf.encs.size() == 4, "четыре территории врагов")
	ok(g.enemies.size() == 14, "враги стоят в районе с начала забега: %d (по первой волне на территорию)" % g.enemies.size())
	ok(g.enemies.all(func(e): return e.post), "все на постах")
	await shot("a01_start")
	# ---- ходьба настоящей клавишей
	await until(func(): return not g.intro_busy(), 20.0)
	await wait(0.5)
	print("DVOR2CHECK | перед ходьбой: busy=%s intro=%s mode=%s panel=%s" % [str(G.busy), str(g.intro_busy()), str(g.mode), str(g.panel)])
	var p0: Vector3 = P.global_position
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(2.0)
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_W
	ev2.keycode = KEY_W
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await wait(0.3)
	var moved: float = P.global_position.distance_to(p0)
	print("DVOR2CHECK | ходьба: из %s в %s, состояние героя %s" % [str(p0), str(P.global_position), str(P.state)])
	ok(moved > 4.0, "клавиша W: Пахан прошёл %.1f м за 2 с" % moved)
	ok(g.cam.global_position.distance_to(P.global_position) < 12.0, "камера идёт за героем")
	var hp0: float = P.hp
	await wait(1.5)
	ok(is_equal_approx(P.hp, hp0) and G.room_state == "open", "до обнаружения никто не нападает")
	# ================= три ступени: гаражи у дома =================
	P.max_hp = 100000.0          # дальше проверяется логика встреч, а не выживание: герой в проверке не погибает
	P.hp = 100000.0
	await lead(-30.0, -93.0)
	ok(st("garages_home") == "post", "в 16 м от группы — ещё не заметили")
	await shot("a02_posted")
	await lead(-36.0, -93.0, func(): return st("garages_home") != "post")
	ok(st("garages_home") == "noticed", "ступень 1: заметили (%s)" % st("garages_home"))
	ok(G.room_state == "open" and G.turf.active.is_empty(), "на ступени 1 боя ещё нет")
	await shot("a03_noticed")
	hp0 = P.hp
	await wait(0.8)
	ok(is_equal_approx(P.hp, hp0), "заметили — но не бьют")
	await lead(-39.2, -93.0, func(): return st("garages_home") != "noticed")
	ok(st("garages_home") == "warned", "ступень 2: предупредили (%s)" % st("garages_home"))
	var lead_e = G.turf.enc("garages_home")["lead"]
	ok(is_instance_valid(lead_e) and not lead_e.post, "один из группы идёт навстречу, остальные стоят")
	await shot("a04_warned")
	var got_fight: bool = await until(func(): return st("garages_home") == "fight", 5.0)
	ok(got_fight and G.room_state == "fight", "ступень 3: бой начался")
	ok(G.turf.log.filter(func(l): return l[0] == "fight" and l[1] == "garages_home").size() == 1, "переход в бой сработал один раз")
	ok(g.arena_c.distance_to(G.turf.enc("garages_home")["c"]) < 0.1, "зона врагов привязана к территории")
	await shot("a05_fight")
	# ================= победа и сумка =================
	var gold0 := int(G.run["golda"])
	var won: bool = await kill_enc("garages_home")
	ok(won, "группа у гаражей побеждена (три волны, подкрепление пришло пешком)")
	G.flush_coins()
	var gold1 := int(G.run["golda"])
	ok(points("bag_garages_home") == 1, "после победы — одна сумка")
	ok(G.room_state == "open", "после победы район снова свободен")
	await shot("a06_bag")
	G.use("bag_garages_home")
	await pick_fit()
	await wait(0.3)
	ok(int(G.run["golda"]) - gold1 == 20, "сумка дала 20 голды (получено %d)" % (int(G.run["golda"]) - gold1))
	G.use("bag_garages_home")
	await pick_fit()
	G.turf.take_bag("bag_garages_home")
	ok(int(G.run["golda"]) - gold1 == 20 and points("bag_garages_home") == 0, "повторный обыск ничего не даёт, сумки больше нет")
	ok(gold1 >= gold0, "монеты с врагов собраны (%d)" % (gold1 - gold0))
	# ================= убийство во время подготовки: ГСК =================
	P.global_position = G67Dvor2.to3(-95.5, 33.5, 0.05)
	await wait(0.4)
	await until(func(): return st("gsk_stove") == "noticed", 3.0)
	ok(st("gsk_stove") in ["noticed", "warned"], "ГСК: группа заметила героя")
	var n0 := foes("gsk_stove")
	var first = G.turf.enc("gsk_stove")["foes"][0]
	first.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	await until(func(): return st("gsk_stove") == "fight", 2.0)
	ok(st("gsk_stove") == "fight", "враг убит во время подготовки — встреча перешла в бой")
	await wait(0.6)
	ok(foes("gsk_stove") == n0 - 1 and (G.turf.enc("gsk_stove")["pending"] as Array).is_empty(), "убитого не заменили: было %d, стало %d" % [n0, foes("gsk_stove")])
	# ================= первый побег =================
	gold1 = int(G.run["golda"])
	G.flush_coins()
	var gold_f := int(G.run["golda"])
	await run_away(-71.0, 33.5)
	await wait(0.4)
	print("DVOR2CHECK | побег: состояние %s, герой %s, busy=%s over=%s room_state=%s hp=%.0f" % [st("gsk_stove"), str(P.global_position), str(G.busy), str(g.over), G.room_state, P.hp])
	ok(st("gsk_stove") == "post" and int(G.turf.enc("gsk_stove")["flees"]) == 1, "первый побег: бой прерван, группа вернулась на посты")
	ok(foes("gsk_stove") == 4 and G.turf.enc("gsk_stove")["foes"].all(func(e): return e.post), "после побега враги остались в районе: %d на постах" % foes("gsk_stove"))
	ok(points("bag_gsk_stove") == 0 and int(G.run["golda"]) == gold_f, "за брошенный бой награды нет")
	ok(G.room_state == "open" and G.turf.active.is_empty(), "после побега район свободен")
	# ================= возвращение и половина награды =================
	await lead(-94.0, 33.5, func(): return st("gsk_stove") == "fight")
	var back: bool = await until(func(): return st("gsk_stove") == "fight", 8.0)
	ok(back, "вернулся — группа снова заметила и бой начался заново")
	won = await kill_enc("gsk_stove")
	G.flush_coins()
	gold1 = int(G.run["golda"])
	ok(won and points("bag_gsk_stove") == 1, "вторая попытка выиграна, сумка одна")
	G.use("bag_gsk_stove")
	await pick_fit()
	await wait(0.3)
	ok(int(G.run["golda"]) - gold1 == 10, "после побега сумка даёт половину: 10 голды (получено %d)" % (int(G.run["golda"]) - gold1))
	# ================= второй побег: группа уходит (засада у башен) =================
	P.global_position = G67Dvor2.to3(6.0, 66.0, 0.05)
	await wait(0.3)
	await lead(6.0, 72.0, func(): return st("ambush_towers") == "fight")
	await until(func(): return st("ambush_towers") == "fight", 3.0)
	ok(st("ambush_towers") == "fight", "засада: бой без предупреждения")
	await run_away(6.0, 78.0 - 32.0)
	await wait(0.3)
	ok(st("ambush_towers") == "post" and int(G.turf.enc("ambush_towers")["flees"]) == 1, "засада: первый побег")
	await lead(6.0, 72.0, func(): return st("ambush_towers") == "fight")
	await until(func(): return st("ambush_towers") == "fight", 3.0)
	await run_away(6.0, 78.0 - 32.0)
	await wait(0.3)
	ok(st("ambush_towers") == "gone", "второй побег: группа ушла, встреча закрыта")
	ok(foes("ambush_towers") == 0, "ушедших врагов в районе нет")
	await lead(6.0, 77.0)
	await wait(2.5)
	ok(st("ambush_towers") == "gone" and foes("ambush_towers") == 0 and G.room_state == "open", "на пустой территории ничего не начинается — фарма нет")
	ok(points("bag_ambush_towers") == 0, "за ушедшую группу сумки нет")
	# ================= сохранение и продолжение =================
	ok(not G.turf.need_done(), "к Мише рано: смотрящий ещё на месте")
	ok(G.world.dvor.court_block.collision_layer != 0, "калитка коробки закрыта")
	var enc_sv: Dictionary = (G.data["run"]["run"]["enc"] as Dictionary)
	ok(String(enc_sv["garages_home"]["s"]) == "cleared" and String(enc_sv["ambush_towers"]["s"]) == "gone" and int(enc_sv["gsk_stove"]["f"]) == 1, "состояния встреч записаны в сохранение забега")
	P.global_position = G67Dvor2.to3(G67Dvor2.START.x, G67Dvor2.START.y, 0.05)
	await wait(0.3)
	await G.go_home()
	ok(G.place == "hub" and G.paused_run() and worlds() == 0, "ушёл в подъезд: забег на паузе, района в памяти нет")
	await G.resume_run()
	await wait(0.6)
	ok(worlds() == 1 and G.turf != null, "продолжил забег: район построен заново, один")
	ok(st("garages_home") == "cleared" and st("gsk_stove") == "cleared" and st("ambush_towers") == "gone" and st("elite_sofa") == "post", "после продолжения встречи в тех же состояниях")
	ok(foes("garages_home") == 0 and foes("elite_sofa") == 3, "пройденные группы не вернулись; смотрящий с охраной на месте")
	ok(points("bag_garages_home") == 0 and points("bag_gsk_stove") == 0, "собранные сумки не появились снова")
	# ================= обязательная встреча не блокирует забег: смотрящий, два побега =================
	for k in 2:
		P.global_position = G67Dvor2.to3(112.0, 44.0, 0.05)
		await wait(0.3)
		await lead(112.0, 38.0, func(): return st("elite_sofa") == "fight")
		await until(func(): return st("elite_sofa") == "fight", 3.0)
		if k == 0:
			ok(st("elite_sofa") == "fight", "элита: смотрящий не отпускает — бой сразу")
			await shot("a07_elite")
		await run_away(112.0, 28.0 + 33.0)
		await wait(0.3)
	ok(st("elite_sofa") == "gone", "от смотрящего сбежали дважды — он ушёл")
	ok(G.turf.need_done(), "обязательная встреча ушла, её заменила пройденная необязательная — встречи больше не держат")
	await wait(0.3)
	# ================= ритм: «ТРЯПКИ», ларёк, передышка =================
	ok(not G.dv_ready() and G.world.dvor.court_block.collision_layer != 0, "без «ТРЯПОК» калитка закрыта")
	ok(goal_text().find("рынок") >= 0 and goal_text().find("ТРЯПКИ") < 0, "цель на мини-карте ведёт на рынок и не называет событие: %s" % goal_text())
	ok(G.minimap != null and G.minimap.shown() and G.hud_line() == "", "мини-карта на экране, старой строки вверху нет")
	await wait(1.5)
	ok(G.minimap.path.size() >= 2 and G.minimap.rects.size() > 60 and G.minimap.kind == "dvor", "карта двора из плана района: фигур %d, маршрут из %d точек" % [G.minimap.rects.size(), G.minimap.path.size()])
	var far_end: Vector2 = G.minimap.path[G.minimap.path.size() - 1]
	ok(far_end.distance_to(Vector2(G67Dvor2.RAGS.x, -G67Dvor2.RAGS.y)) < 1.0, "маршрут кончается у прилавка рынка")
	var solid_hits := 0
	for v in G.minimap.path:
		for rr in G.minimap.rects:
			if String(rr[1]) == "house" and (rr[0] as Rect2).grow(-1.5).has_point(v):
				solid_hits += 1
	ok(solid_hits == 0, "маршрут обходит дома (точек внутри домов: %d)" % solid_hits)
	var back_here: Vector3 = P.global_position
	await map_shot("m1_map_start", G67Dvor2.START.x, G67Dvor2.START.y)
	await map_shot("m2_map_kiosk", G67Dvor2.KIOSK.x - 3.0, G67Dvor2.KIOSK.y - 5.0)
	await map_shot("m3_map_gsk", -70.0, 40.0)
	G.minimap.cycle_zoom()
	await map_shot("m3b_map_gsk_far", -70.0, 40.0)
	ok(G.minimap.zoom_i == 2, "масштаб карты переключается")
	G.minimap.cycle_zoom()
	G.minimap.cycle_zoom()
	P.global_position = back_here
	var st_n: int = G.dv_stages()
	P.global_position = G67Dvor2.to3(G67Dvor2.RAGS.x, G67Dvor2.RAGS.y - 1.5, 0.05)
	await wait(0.3)
	G.use("rags_dv")
	await wait(0.5)
	await until(func(): return G.clip == null and not G.busy, 240.0)
	ok(bool(G.run.get("rags", false)) and G.dv_stages() == st_n + 1 and points("rags_dv") == 0, "«ТРЯПКИ! ТРЯПКИ!» пройдены: этап засчитан, точка убрана")
	ok(bool((G.meta().get("must", {}) as Dictionary).get("ev_rags", false)), "событие записано в постоянный прогресс")
	G.use("rags_dv")
	ok(G.dv_stages() == st_n + 1, "повторно событие не засчитывается")
	ok(G.dv_stages() >= 3, "пройдено этапов: %d" % G.dv_stages())
	P.global_position = G67Dvor2.to3(G67Dvor2.KIOSK.x, G67Dvor2.KIOSK.y - 1.0, 0.05)
	await wait(0.3)
	G.use("kiosk")
	await wait(0.4)
	ok(bool(G.run.get("kiosk_full", false)) and G.hub_ui != null and String(G.hub_ui.kind) == "kiosk", "ларёк после трёх этапов — полное меню")
	ok(G.kiosk_price("shawarma") == 0, "первая шаурма бесплатно")
	if G.hub_ui != null:
		G.hub_ui.close()
	await wait(0.4)
	var hp_r: float = P.max_hp * 0.3
	P.hp = hp_r
	G.use("rest_dv")
	await wait(0.3)
	ok(bool(G.run.get("rested", false)) and P.hp > hp_r + P.max_hp * 0.4, "передышка в беседке лечит (%.0f → %.0f из %.0f)" % [hp_r, P.hp, P.max_hp])
	var hp_r2: float = P.hp
	G.use("rest_dv")
	ok(is_equal_approx(P.hp, hp_r2), "вторая передышка за забег не лечит")
	P.hp = P.max_hp
	await wait(0.5)
	ok(G.world.dvor.court_block.collision_layer == 0, "калитка коробки открылась")
	# ================= Миша =================
	P.global_position = G67Dvor2.to3(6.0, 99.0, 0.05)
	await wait(0.3)
	await lead(6.0, 105.0, func(): return G.room_state == "boss")
	await until(func(): return G.room_state == "boss", 3.0)
	ok(G.room_state == "boss" and is_instance_valid(g.boss_e), "вошёл в коробку — Миша на месте, бой с боссом")
	ok(G.world.dvor.court_block.collision_layer != 0, "калитка закрылась за спиной")
	await wait(1.0)
	await shot("a08_misha")
	G._scene_skip()
	await wait(0.5)
	ok(G.scene_t < 0.0 and is_instance_valid(g.boss_e), "вступление Миши прошло, бой начался")
	ok(not G.world.dvor.gate_open, "до победы решётка под аркой закрыта")
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < 45000 and G.room_state == "boss":
		if is_instance_valid(g.boss_e) and g.boss_e.state != "dead":
			g.boss_e.antract_until = g.boss_e.age      # проверка не ждёт антракты и стойку: здесь важен финал, а не бой
			g.boss_e.guard_until = -1.0
			g.boss_e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
		for e in g.enemies:
			if is_instance_valid(e) and e != g.boss_e and e.state != "dead":
				e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
		await wait(0.25)
	ok(G.room_state == "over", "Миша повержен")
	ok(bool((G.meta().get("flags", {}) as Dictionary).get("boss_misha", false)), "победа записана в постоянный прогресс (boss_misha)")
	ok(G.world.dvor.gate_open, "решётка под аркой дома № 81 открылась")
	await wait(3.5)
	await shot("a09_result")
	ok(G.hub_ui != null, "экран итогов забега открыт")
	# ================= новый забег =================
	await G.result_new_run()
	await wait(0.8)
	ok(G.place == "run" and worlds() == 1, "новый забег: район пересоздан, один")
	ok(G.turf.encs.all(func(e): return String(e["state"]) == "post") and g.enemies.size() == 14, "в новом забеге все группы снова на постах")
	ok(G.world.dvor.gate_open, "решётка остаётся открытой в следующих забегах")
	ok(int(G.run["golda"]) == 0, "голда прошлого забега сгорела")
	# ================= бафы перед спуском =================
	# ================= заначки и КРОТ =================
	var sec: Dictionary = G.run.get("secrets", {})
	var sec_ids: Array = G.world.points.filter(func(pt): return String(pt["id"]).begins_with("secret_dv_")).map(func(pt): return String(pt["id"]))
	ok(sec_ids.size() == 3 and (sec.get("spots", []) as Array).size() == 3, "в забеге три заначки (%d)" % sec_ids.size())
	if not sec_ids.is_empty():
		var g_s: int = int(G.run["golda"])
		var n_f := 0
		for k in (G.run["fits"] as Dictionary):
			n_f += int(G.run["fits"][k])
		P.global_position = ev_point(String(sec_ids[0])) + Vector3(0, 0.05, 0)
		await wait(0.3)
		await shot("a21_secret")
		G.use(String(sec_ids[0]))
		await wait(0.2)
		var n_f2 := 0
		for k in (G.run["fits"] as Dictionary):
			n_f2 += int(G.run["fits"][k])
		ok(points(String(sec_ids[0])) == 0 and (int(G.run["golda"]) > g_s or n_f2 == n_f + 1), "заначка отдала награду и исчезла")
		var g_s2: int = int(G.run["golda"])
		G.take_secret(String(sec_ids[0]))
		ok(int(G.run["golda"]) == g_s2, "второй раз заначку не взять")
	var kn: Dictionary = G.krot_next()
	if not kn.is_empty() and G.KROT_DV.has(String(kn["id"])):
		ok(points("krot") == 1 and G.world.actors.has("g67_krot"), "КРОТ стоит в новом дворе на встрече «%s»" % String(kn["title"]))
		P.global_position = ev_point("krot") + Vector3(0, 0.05, 0)
		await wait(0.6)
		await shot("a22_krot")
	else:
		print("DVOR2CHECK | КРОТ: очередная встреча не во дворе (%s) — в районе его нет" % String(kn.get("id", "нет")))
	# ================= необязательный конфликт =================
	var n_enc: int = G.turf.encs.size()
	var ex: Dictionary = G.turf.add_extra("school_kid")
	ok(not ex.is_empty() and G.turf.encs.size() == n_enc + 1 and (ex["foes"] as Array).size() >= 2, "конфликт у школы поставлен: врагов %d" % (ex.get("foes", []) as Array).size())
	ok(G.turf.need_done() == (G.turf.encs.filter(func(e): return bool(e["d"]["must"]) and not String(e["state"]) in ["cleared", "gone"]).is_empty() or G.turf.need_done()), "необязательный конфликт не мешает пути к Мише")
	var g_x: int = int(G.run["golda"])
	P.hp = P.max_hp * 0.5
	var hp_x: float = P.hp
	P.global_position = G67Dvor2.to3(-86.0, 90.0, 0.05)
	await lead(-86.0, 103.0, func(): return String(ex["state"]) == "fight" or G.hub_ui != null)
	ok(await pick_choice("fight", 14.0), "у школы открыт выбор: вступиться, пошутить или пройти мимо")
	await until(func(): return String(ex["state"]) == "fight", 14.0)
	ok(String(ex["state"]) == "fight", "подошёл — конфликт перешёл в бой")
	await wait(1.0)
	ok(goal_text().find("Разберись") >= 0 and G.minimap.marks.any(func(m): return String(m[3]) == "zone_on"), "в бою цель — «Разберись с местной группой», территория на карте горит")
	await shot("m4_map_fight")
	var won_x: bool = await kill_enc("school_kid")
	ok(won_x and points("bag_school_kid") == 1 and G.item_n("thermos") == 1, "победа: сумка на месте, школьник отдал термос")
	(G.run["items"] as Dictionary).erase("thermos")
	G.use("bag_school_kid")
	await pick_fit()
	ok(int(G.run["golda"]) - g_x >= 30, "в сумке 20 и 10 от школьника: +%d" % (int(G.run["golda"]) - g_x))
	P.hp = P.max_hp
	# ================= жители и торговец =================
	await folk_block()
	# ================= пять событий =================
	await events_block()
	# ================= девять бафов двора: действие каждого =================
	ok(picked.size() >= 1, "сумка обычной встречи предложила баф, взят: %s" % str(picked))
	var b_ids: Array = ["ded_jacket", "kiosk_can", "slick_soles", "garage_key", "first_hit", "semki", "own_man", "district_remembers", "warm_entry"]
	var b_all := true
	for id in b_ids:
		b_all = b_all and G67Data.FITS.has(id) and G.fit_avail(id) or (id == "warm_entry" and bool(G.run.get("rested", false)))
	ok(b_all, "девять бафов двора есть в данных и доступны в новом дворе")
	ok(String(G67Data.FITS["kiosk_can"]["name"]) == "БАНКА ИЗ ЛАРЬКА", "баф kiosk_can называется «БАНКА ИЗ ЛАРЬКА»")
	var b_keep: Dictionary = (G.run["fits"] as Dictionary).duplicate(true)
	G.run["fits"] = {}
	G.soles_until = -9.0
	G.jacket_t = -9.0
	await wait(0.2)
	var b_dmg: float = G.dmg_now()
	var b_cd: float = P.combat.cd_k
	G.run["fits"] = {"ded_jacket": 3, "kiosk_can": 2, "slick_soles": 2, "garage_key": 2, "first_hit": 2, "own_man": 2, "district_remembers": 1}
	ok(is_equal_approx(g.run_mods.incoming(g), 1.0), "ДЕДОВСКАЯ КУРТКА: без недавнего удара урон обычный")
	G.jacket_t = g.clock
	ok(absf(g.run_mods.incoming(g) - 0.45) < 0.001, "ДЕДОВСКАЯ КУРТКА III: следующий удар слабее на 55 %% (множитель %.2f)" % g.run_mods.incoming(g))
	G.jacket_t = -9.0
	await wait(0.2)
	ok(absf(P.combat.cd_k - maxf(minf(b_cd, 0.6), b_cd * 0.8)) < 0.001, "БАНКА ИЗ ЛАРЬКА II: перезарядки ×%.2f (было ×%.2f)" % [P.combat.cd_k, b_cd])
	G.soles_until = g.clock + 2.0
	ok(absf(G.dmg_now() / b_dmg - 1.25) < 0.001, "СКОЛЬЗКИЕ ПОДОШВЫ II: после уклонения урон ×1,25")
	G.soles_until = -9.0
	G.run["ev_done"] = 2
	ok(absf(G.dmg_now() / b_dmg - 1.10) < 0.001, "РАЙОН ПОМНИТ: два события — урон ×1,10")
	G.run["ev_done"] = 9
	ok(absf(G.dmg_now() / b_dmg - 1.15) < 0.001, "РАЙОН ПОМНИТ: не больше ×1,15")
	G.run.erase("ev_done")
	ok(G.trade_price(100) == 75 and G.trade_price(0) == 0, "СВОЙ ЧЕЛОВЕК II: цена 100 → 75")
	var bfoe = null
	for e in g.enemies:
		if is_instance_valid(e) and e.alive() and String(e.boss_id) == "" and float(e.hp) >= float(e.max_hp):
			bfoe = e
			break
	if bfoe != null:
		var bh := HitInfo.new()
		bh.heavy = true
		bh.stagger = 10.0
		bh.damage = 10.0
		bh.pos = bfoe.global_position
		g.run_mods.melee_hit(bh, P, 1)
		ok(absf(bh.stagger - 15.0) < 0.001, "ГАРАЖНЫЙ КЛЮЧ II: тяжёлый удар снимает равновесия 15 вместо 10")
		ok(bh.damage > 10.0 and bh.damage <= 15.0 * 1.15 + 0.01, "ПЕРВЫЙ УДАР II: по врагу с полным здоровьем урон %.1f вместо 10" % bh.damage)
		var bh2 := HitInfo.new()
		bh2.damage = 10.0
		bh2.stagger = 10.0
		bh2.pos = bfoe.global_position
		bfoe.hp = bfoe.max_hp * 0.5
		g.run_mods.melee_hit(bh2, P, 1)
		ok(is_equal_approx(bh2.damage, 10.0) and is_equal_approx(bh2.stagger, 10.0), "по раненому врагу лёгким ударом — без надбавок")
		bfoe.hp = bfoe.max_hp
	else:
		ok(false, "нет целого врага для проверки ГАРАЖНОГО КЛЮЧА и ПЕРВОГО УДАРА")
	G.run["fits"] = b_keep
	G.apply_fits()
	await wait(0.2)
	var fithh0: int = G.fit_lv("heavy_hand")
	var fitn0: int = (G.run["fits"] as Dictionary).size() + (0 if fithh0 > 0 else 1) + (0 if G.fit_lv("authority") > 0 else 1) + (0 if G.fit_lv("second_wind") > 0 else 1)
	G.take_fit("heavy_hand"); G.take_fit("heavy_hand"); G.take_fit("authority"); G.take_fit("second_wind")
	await wait(0.3)
	var fits0: Dictionary = (G.run["fits"] as Dictionary).duplicate(true)
	var dmg0: float = P.dmg_mul
	var mhp0: float = P.max_hp
	var goldc: int = int(G.run["golda"])
	var enc0: String = JSON.stringify(G.run["enc"])
	ok(int(fits0.get("heavy_hand", 0)) == mini(3, fithh0 + 2) and fits0.size() == fitn0 and fitn0 >= 3, "перед спуском не меньше трёх бафов, ТЯЖЁЛАЯ РУКА выше первого уровня: %s" % str(fits0))
	# ================= спуск в ПОДЗЕМКУ =================
	var top: Vector3 = G.world.dvor.stairs_top()
	P.global_position = top + Vector3(-2.0, 0.05, 0)
	await wait(0.3)
	ok(G.room_state == "open" and not G.descending, "у открытой решётки забег идёт как обычно")
	ok(goal_text().find("Подземку") >= 0, "после Миши цель — спуск в Подземку: %s" % goal_text())
	ok(G.minimap.marks.any(func(m): return String(m[0]) == "exit_pz"), "на карте есть маркер спуска в Подземку")
	await shot("t1_gate")
	var bt: Vector3 = G.world.dvor.stairs_bottom()
	var lk: Vector3 = G.world.dvor.link_point()
	var leg := 0
	for i in 1800:
		var door: Vector3 = Vector3(bt.x, bt.y, bt.z + 3.6)          # проём с площадки в коридор: прямо от низа марша
		var aim: Vector3 = bt if leg == 0 else (door if leg == 1 else lk)
		var dd: Vector3 = aim - P.global_position
		if G.descending:
			break
		if dd.length() < 0.5:
			if leg == 0:
				leg = 1
				await shot("t3_landing")
				ok(not G.descending and String(G.run.get("district", "")) != "podzemka", "на нижней площадке перехода ещё нет: нужно свернуть в коридор")
				continue
			if leg == 1:
				leg = 2
				continue
			break
		if leg == 0 and i == 60:
			g.cam_yaw = atan2(-dd.x, -dd.z)
		if leg == 0 and i == 110:
			await shot("t2_stairs")
		P.global_position += dd.normalized() * minf(dd.length(), 5.0 / 60.0)
		P.face = atan2(dd.x, dd.z)
		g.cam_yaw = lerp_angle(g.cam_yaw, atan2(-dd.x, -dd.z), 0.08)
		P.velocity = Vector3.ZERO
		await get_tree().physics_frame
	print("DVOR2CHECK | стык: герой %s, точка %s, низ %s, камера %s, descending=%s link_cd=%.1f state=%s" % [str(P.global_position), str(lk), str(bt), str(g.cam.global_position), str(G.descending), G.link_cd, G.room_state])
	await shot("t4_swap")
	var went: bool = await until(func(): return String(G.run.get("district", "")) == "podzemka", 30.0)
	await until(func(): return not G.descending, 60.0)      # при первом спуске идёт вступительный ролик Подземки
	await wait(0.5)
	var had_clip: bool = G.clip != null
	await until(func(): return G.clip == null, 180.0)
	print("DVOR2CHECK | вступительный ролик при первом спуске: %s" % ("шёл, досмотрен" if had_clip else "не запускался"))
	ok(went, "спустился по лестнице под аркой — начался забег района ПОДЗЕМКА")
	await wait(1.0)
	ok(G.world.dvor == null and worlds() == 0, "двор выгружен: в памяти только Подземка")
	ok(G.world.district != null and G67District.is_podzemka(), "мир — Подземка Devin")
	ok(G.turf == null, "территории двора выключены")
	ok(P.global_position.distance_to(G.PZ_LINK_IN) < 3.0 and absf(angle_difference(P.face, -PI * 0.5)) < 0.3, "герой в коридоре Подземки за поворотом, идёт к спуску (%.1f м от точки выхода)" % P.global_position.distance_to(G.PZ_LINK_IN))
	ok(G.minimap.kind == "podzemka" or not G.minimap.shown(), "мини-карта переключилась на Подземку")
	var cam_l: Camera3D = get_viewport().get_camera_3d()
	var q_l := PhysicsRayQueryParameters3D.create(P.global_position + Vector3(0, 1.4, 0), cam_l.global_position, 1)
	q_l.exclude = [P.get_rid()]
	ok(P.get_world_3d().direct_space_state.intersect_ray(q_l).is_empty(), "в коридоре стыка камера за спиной героя, стен между ними нет")
	await shot("t5_pz_first")
	var cams: Array = get_tree().root.find_children("*", "Camera3D", true, false)
	print("DVOR2CHECK | после спуска: room_state=%s room=%s ворот=%d врагов=%d busy=%s clip=%s scene_t=%.1f" % [G.room_state, str(G.room), G.world.gates.size(), g.enemies.size(), str(G.busy), str(G.clip), G.scene_t])
	print("DVOR2CHECK | герой %s face=%.2f | камера %s cam_yaw=%.2f cam_len=%.1f spring=%.2f | камер в дереве %d, текущих %d" % [str(P.global_position), P.face, str(g.cam.global_position), g.cam_yaw, g.cam_len, g.spring.get_hit_length(), cams.size(), cams.filter(func(c): return c.current).size()])
	await shot("a10_podzemka")
	# кадр ниже по лестнице Подземки, камерой за спиной героя — что мир на месте
	P.global_position = G67Podzemka.STAIRS_TOP + Vector3(0, -2.0, -8.0)
	P.face = PI
	g.cam_yaw = 0.0
	await wait(1.5)
	await shot("a11_podzemka_stairs")
	# ================= камера и HUD после спуска =================
	P.global_position = G67Podzemka.STAIRS_TOP
	P.face = PI
	g.cam_yaw = 0.0
	await wait(1.0)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var head: Vector3 = P.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(head, cam.global_position, 1)
	q.exclude = [P.get_rid()]
	var hit: Dictionary = P.get_world_3d().direct_space_state.intersect_ray(q)
	ok(hit.is_empty(), "между героем и камерой нет стен и перекрытий (камера внутри помещения, %s)" % str(cam.global_position))
	ok(cam.global_position.distance_to(head) < 6.5 and not cam.is_position_behind(head), "Пахан в кадре, камера не дальше 6,5 м")
	ok(G.hud_line() == "" and G.minimap.shown() and G.minimap.kind == "podzemka" and goal_text() != "", "в Подземке вместо строки «ДАЛЬШЕ:» — мини-карта района и цель: %s" % goal_text())
	ok(G.minimap.rects.size() == G67Podzemka.ROOMS.size(), "карта Подземки — из таблицы помещений (%d)" % G.minimap.rects.size())
	await shot("a12_pz_spawn")
	# ================= бафы внизу, сохранение =================
	var same := func() -> bool: return JSON.stringify(G.run["fits"]) == JSON.stringify(fits0)
	ok(same.call(), "бафы и уровни внизу те же: %s" % str(G.run["fits"]))
	ok(is_equal_approx(P.dmg_mul, dmg0) and is_equal_approx(P.max_hp, mhp0), "действие бафов то же: урон ×%.2f, здоровье %d" % [P.dmg_mul, int(P.max_hp)])
	ok(int(G.run["golda"]) == goldc, "голда при герое: %d" % int(G.run["golda"]))
	ok(points("to_dvor") == 1 and points("home") == 1, "в Подземке две разные точки: «ВО ДВОР» и «НАВЕРХ, ДОМОЙ»")
	G._save_run("open")
	var sv: Dictionary = JSON.parse_string(JSON.stringify(G.data["run"]))
	var svf: Dictionary = (sv["run"] as Dictionary)["fits"]
	var eq := svf.size() == fits0.size()
	for k in fits0:
		eq = eq and int(svf.get(k, 0)) == int(fits0[k])      # JSON читает числа дробными — сравниваем значения, а не текст
	ok(eq, "бафы есть в записи забега и читаются из JSON: %s" % str(svf))
	# ================= обратно во двор =================
	G.run["pos"] = 2                      # будто два этапа Подземки уже пройдены
	G.run["pz_change"] = 1
	G.use("to_dvor")
	var came: bool = await until(func(): return String(G.run.get("district", "")) == "dvor" and G.world.dvor != null and not G.descending, 30.0)
	ok(came, "«ВО ДВОР»: загружен новый двор")
	await wait(1.0)
	ok(worlds() == 1 and not G67District.is_podzemka(), "в памяти один двор, Подземка выгружена")
	ok(P.global_position.distance_to(G.world.dvor.link_in()) < 3.0 and P.global_position.y < -4.0, "герой в коридоре под аркой, впереди лестница наверх")
	ok(G.minimap.kind == "dvor" and G.minimap.shown(), "мини-карта снова показывает двор")
	var cam_b: Camera3D = get_viewport().get_camera_3d()
	var q_b := PhysicsRayQueryParameters3D.create(P.global_position + Vector3(0, 1.4, 0), cam_b.global_position, 1)
	q_b.exclude = [P.get_rid()]
	ok(P.get_world_3d().direct_space_state.intersect_ray(q_b).is_empty(), "после возвращения камера внутри коридора, герой в кадре")
	await shot("t6_back")
	P.global_position = G.world.dvor.stairs_top() + Vector3(-8.5, 0.05, 0.0)
	P.face = -PI * 0.5
	g.cam_yaw = PI * 0.5
	await wait(0.8)
	ok(G.world.dvor.gate_open, "решётка открыта")
	ok(same.call() and is_equal_approx(P.dmg_mul, dmg0) and is_equal_approx(P.max_hp, mhp0), "бафы после возвращения те же, действие то же")
	ok(JSON.stringify(G.run["enc"]) == enc0, "встречи двора в том же состоянии, что до спуска (награды не выдаются заново)")
	ok(G.turf != null and G.room_state == "open", "территории двора снова работают")
	await shot("a13_back_dvor")
	# ================= второй спуск =================
	var clips0: int = G.events.filter(func(e): return String(e[0]) == "clip").size()
	G.descend()
	var again: bool = await until(func(): return String(G.run.get("district", "")) == "podzemka" and not G.descending, 30.0)
	await wait(1.0)
	ok(again and same.call() and is_equal_approx(P.dmg_mul, dmg0), "второй спуск: бафы не удвоились и не пропали")
	ok(G.events.filter(func(e): return String(e[0]) == "clip").size() == clips0, "вступительный ролик второй раз не идёт")
	ok(int(G.run.get("pos", 0)) == 2 and int(G.run.get("pz_change", 0)) == 1 and G.room_state == "open", "повторный спуск: Подземка продолжается с третьего этапа, а не с начала (этап %d)" % (int(G.run.get("pos", 0)) + 1))
	# тоннель и зал — кадры
	for sh in [["a14_pz_gate", G67District.zone_of("gate1")], ["a15_pz_arcade", G67District.zone_of("arcade")], ["a16_pz_tunnel", G67District.zone_of("tunnel")], ["a17_pz_arena", G67District.zone_of("arena")], ["a18_pz_cash", {"c": Vector3(0, 0, -150)}]]:
		var zz: Dictionary = sh[1]
		if zz.is_empty() or not zz.has("c"):
			continue
		P.global_position = (zz["c"] as Vector3) + Vector3(0, 0.1, 0)
		P.velocity = Vector3.ZERO
		await wait(1.2)
		var c2: Camera3D = get_viewport().get_camera_3d()
		var q2 := PhysicsRayQueryParameters3D.create(P.global_position + Vector3(0, 1.4, 0), c2.global_position, 1)
		q2.exclude = [P.get_rid()]
		ok(P.get_world_3d().direct_space_state.intersect_ray(q2).is_empty(), "%s: камера внутри помещения" % String(sh[0]))
		await shot(String(sh[0]))
	for p in KEEP:
		var now = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		ok(now == kept[p], "файл игрока не тронут: " + p.get_file())
	print("DVOR2CHECK итог: ошибок %d" % fails)
	get_tree().quit()
