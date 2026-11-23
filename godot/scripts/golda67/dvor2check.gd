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
	await wait(0.3)
	ok(int(G.run["golda"]) - gold1 == 20, "сумка дала 20 голды (получено %d)" % (int(G.run["golda"]) - gold1))
	G.use("bag_garages_home")
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
	ok(G.turf.need_done(), "обязательная встреча ушла, её заменила пройденная необязательная — путь к Мише открыт")
	await wait(0.3)
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
	G.take_fit("heavy_hand"); G.take_fit("heavy_hand"); G.take_fit("authority"); G.take_fit("second_wind")
	await wait(0.3)
	var fits0: Dictionary = (G.run["fits"] as Dictionary).duplicate(true)
	var dmg0: float = P.dmg_mul
	var mhp0: float = P.max_hp
	var goldc: int = int(G.run["golda"])
	var enc0: String = JSON.stringify(G.run["enc"])
	ok(int(fits0.get("heavy_hand", 0)) == 2 and fits0.size() == 3, "перед спуском три бафа, один второго уровня: %s" % str(fits0))
	# ================= спуск в ПОДЗЕМКУ =================
	var top: Vector3 = G.world.dvor.stairs_top()
	P.global_position = top + Vector3(-2.0, 0.05, 0)
	await wait(0.3)
	ok(G.room_state == "open" and not G.descending, "у открытой решётки забег идёт как обычно")
	var bt: Vector3 = G.world.dvor.stairs_bottom()
	for i in 900:
		var dd: Vector3 = bt - P.global_position
		if dd.length() < 0.6 or G.descending:
			break
		P.global_position += dd.normalized() * minf(dd.length(), 7.0 / 60.0)
		P.velocity = Vector3.ZERO
		await get_tree().physics_frame
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
	ok(P.global_position.distance_to(G67Podzemka.STAIRS_TOP) < 6.0, "герой стоит у спуска Подземки (%.1f м от верха её лестницы)" % P.global_position.distance_to(G67Podzemka.STAIRS_TOP))
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
	var hl: String = G.hud_line()
	ok(not hl.strip_edges().ends_with("ДАЛЬШЕ:") and hl.find("ДАЛЬШЕ: \n") < 0, "пустой строки «ДАЛЬШЕ:» в HUD нет")
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
	G.use("to_dvor")
	var came: bool = await until(func(): return String(G.run.get("district", "")) == "dvor" and G.world.dvor != null and not G.descending, 30.0)
	ok(came, "«ВО ДВОР»: загружен новый двор")
	await wait(1.0)
	ok(worlds() == 1 and not G67District.is_podzemka(), "в памяти один двор, Подземка выгружена")
	ok(P.global_position.distance_to(G.world.dvor.stairs_top()) < 10.0 and P.global_position.y > -0.5, "герой у решётки под аркой, на земле")
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
	# тоннель и зал — кадры
	for sh in [["a14_pz_gate", G67District.zone_of("gate1")], ["a15_pz_arcade", G67District.zone_of("arcade")]]:
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
