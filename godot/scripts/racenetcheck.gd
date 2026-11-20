## Сетевая проверка гонок: `--resolution 1280x720 -- --race-netcheck=<папка>` (этот экземпляр — хост).
## Хост сам запускает другие экземпляры игры (--headless) клиентами: они правда соединяются по ENet через
## 127.0.0.1, у каждого свой процесс, свой RaceNet и своя гонка. Клиент пишет «NETCLIENT ok/ОШИБКА» в свой
## файл в папке, хост собирает их в общий итог. Сценарии:
##   A: хост, клиент, имена, READY, запрет старта, синхронный старт, управление, дрифт, прыжок, турбо, предметы
##      (подбор, использование, попадание), контрольные точки, круги, финиш, одинаковые результаты, «все в лобби»;
##   B: плохой клиент (неверные значения, чужие RPC, спам), другая версия, задержка и потери пакетов,
##      отключение клиента посреди гонки;
##   C: хост закрыл лобби, клиент переподключается к новому;
##   D: 8 участников и трафик; потом выход в офлайн и обычная кампания.
## Клиентская роль: `-- --race-netclient=<папка> --net-port=N --net-role=<роль>`.
extends Node

var main
var out := ""
var role := ""                 # "" — хост-проверка, иначе роль клиента
var port := 24830
var fails := 0
var log_lines: Array = []
var kept := {}
const KEEP := ["user://grimerka_save.json", "user://grimerka_race.json"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-port="):
			port = int(a.substr(11))
		elif a.begins_with("--net-role="):
			role = a.substr(11)
	AudioServer.set_bus_mute(0, true)
	RaceSave.persist = false
	if role == "":
		for p in KEEP:
			kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		_host_run()
	else:
		_client_run()

# ---------------- общее ----------------
func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	var line := ("%s ok: " if cond else "%s ОШИБКА: ") % ("NET" if role == "" else "NETCLIENT[%s]" % role) + text
	print(line)
	log_lines.append(line)
	if role != "":
		var f := FileAccess.open(out.path_join("client_%s.log" % role), FileAccess.WRITE)
		if f:
			f.store_string("\n".join(log_lines) + "\n")

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func net() -> RaceNet:
	if main.race_net == null or not is_instance_valid(main.race_net):
		var n := RaceNet.new()
		n.main = main
		main.add_child(n)
		main.race_net = n
	return main.race_net

func spawn_client(r: String, extra: Array = []) -> int:
	var args := ["--headless", "--log-file", out.path_join("client_%s.godot.log" % r), "--path", ProjectSettings.globalize_path("res://"), "--", "--race-netclient=" + out, "--net-port=%d" % port, "--net-role=" + r] + extra
	if OS.get_cmdline_user_args().has("--net-debug"):
		args.append("--net-debug")
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(args))
	print("NET запущен клиент %s (pid %d)" % [r, pid])
	return pid

func client_log(r: String) -> String:
	var p := out.path_join("client_%s.log" % r)
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""

func merge_client(r: String) -> void:
	var s := client_log(r)
	var n_ok := s.count("NETCLIENT[%s] ok" % r)
	var n_bad := s.count("ОШИБКА")
	for ln in s.split("\n"):
		if ln.contains("ОШИБКА"):
			print(ln)
	ok(n_bad == 0 and n_ok > 0, "клиент «%s»: %d проверок у себя, ошибок %d" % [r, n_ok, n_bad])

func players() -> Array:
	return net().lobby.get("players", [])

# ---------------- хост ----------------
func _host_run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for f in DirAccess.get_files_at(out):
		if f.begins_with("client_"):
			DirAccess.remove_absolute(out.path_join(f))
	await wait(1.5)
	var N := net()
	if OS.get_cmdline_user_args().has("--net-d"):
		await _phase_d(N)
		_host_finish()
		return
	# ===== A: лобби =====
	var err := N.host_lobby({"room": "ПРОВЕРКА", "name": "ХОСТ", "max": 8, "laps": 1, "port": port, "rider": "pahan"})
	ok(err == "", "1. хост создал лобби на UDP %d (%s)" % [port, err if err != "" else "ok"])
	ok(multiplayer.is_server() and multiplayer.get_unique_id() == 1, "хост — id 1")
	spawn_client("main")
	var joined: bool = await until(func(): return players().size() == 2, 20.0)
	ok(joined, "2. клиент подключился (участников %d)" % players().size())
	ok(joined and players().any(func(p): return p["name"] == "ДРУГ" and not p["host"]), "3–4. участник зарегистрирован, имя передано («ДРУГ»)")
	ok(not N.can_start() and not N.start_race(), "6. старт до READY запрещён")
	var rd: bool = await until(func(): return players().size() == 2 and bool(players()[1]["ready"]), 15.0)
	ok(rd, "5. READY клиента дошёл до хоста")
	await wait(0.5)
	ok(N.can_start() and N.start_race(), "старт после READY всех")
	var go: bool = await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.state != "wait", 25.0)
	ok(go, "7. оба загрузили трассу — синхронный старт (облёт)")
	if not go:
		_host_finish()
		return
	var race: Race = main.race
	ok(race.riders.size() == 2 and race.authority, "в гонке 2 гонщика, хост — власть")
	var cr: RaceRider = race.rider_of_peer(players()[1]["id"])
	ok(cr != null and cr.kind == "remote", "гонщик клиента на хосте управляется по сети")
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "hard", 1)
	await until(func(): return race.go, 10.0)
	var p0: Vector3 = cr.global_position
	var seen := {"drift": false, "jump": false, "boost": false, "speed": 0.0}
	var t0 := Time.get_ticks_msec()
	var far := 0.0
	while Time.get_ticks_msec() - t0 < 9000:
		far = maxf(far, cr.global_position.distance_to(p0))
		seen["drift"] = seen["drift"] or cr.drifting
		seen["jump"] = seen["jump"] or cr.air_t > 0.1
		seen["boost"] = seen["boost"] or cr.boosting()
		seen["speed"] = maxf(float(seen["speed"]), cr.speed)
		await get_tree().physics_frame
	ok(far > 30.0 and float(seen["speed"]) > 12.0, "8–9. ввод клиента двигает его гонщика на хосте (до %.0f м, до %.1f м/с)" % [far, seen["speed"]])
	ok(seen["drift"], "10. дрифт клиента посчитан хостом")
	ok(seen["jump"], "11. прыжок клиента")
	ok(seen["boost"], "12. ускорение клиента")
	# предметы: хост выдаёт (власть), клиент жмёт «предмет»
	cr.item = "turbo_balloon"
	var e0 := cr.events.size()
	var used: bool = await until(func(): return cr.events.slice(e0).any(func(ev): return ev[0] == "item_use"), 10.0)
	ok(used and cr.item == "", "13–14. предмет у клиента: выдан хостом, использован по нажатию клиента")
	# попадание: хост бьёт выбросом воздуха по гонщику клиента
	var L: RaceRider = race.local
	var keep_ai = L.ai
	L.ai = null
	L.set_meta("auto", RaceInput.new())
	L.place(Transform3D(Basis(Vector3.UP, cr.heading), cr.global_position - cr.fwd() * 6.0))
	L.item = "air_blast"
	L.item_cd = 0.0
	L.spin_t = 0.0                                   # условия опыта: хост не в развороте, у цели нет щита
	cr.shield_t = 0.0
	e0 = cr.events.size()
	race.use_item(L)
	ok(cr.events.slice(e0).any(func(ev): return ev[0] == "hit"), "15. попадание предметом по гонщику клиента (считает хост)")
	L.remove_meta("auto")
	L.ai = keep_ai
	# круги и финиш
	var fin: bool = await until(func(): return race.state == "results", 120.0)
	ok(fin, "16–18. контрольные точки, круг и финиш — гонка дошла до результатов")
	ok(race.results.size() == 2, "19. таблица результатов (%d строк)" % race.results.size())
	var order_host := ",".join(race.results.map(func(r): return String(r["title"])))
	await wait(1.5)
	# все в лобби
	N.back_to_lobby()
	race.quit_to_lobby()
	await until(func(): return main.race == null and main.menu != null, 10.0)
	await wait(1.0)
	ok(N.online() and N.lobby.get("state") == "lobby" and players().size() == 2, "после гонки все снова в лобби")
	await until(func(): return client_log("main").contains("результаты"), 15.0)
	ok(client_log("main").contains(order_host), "у клиента та же таблица результатов (%s)" % order_host)
	if OS.get_cmdline_user_args().has("--net-quick"):
		_host_finish()
		return
	# ===== B: плохой клиент, другая версия, задержка и потери, отключение посреди гонки =====
	spawn_client("evil")
	await until(func(): return players().size() == 3, 20.0)
	var rej0 := N.rejected
	await until(func(): return client_log("evil").contains("спам отправлен"), 20.0)
	await wait(1.0)
	ok(N.rejected > rej0 + 5 and N.online() and players().size() >= 2, "24. неверные значения, чужие RPC и спам отброшены (%d), хост жив" % (N.rejected - rej0))
	ok(not players().any(func(p): return not RaceVisual.RIDERS.has(String(p["rider"]))), "подложный гонщик не принят")
	await until(func(): return players().size() == 2, 15.0)
	spawn_client("old", ["--net-fake-build=old-build"])
	await until(func(): return client_log("old").contains("версии"), 20.0)
	ok(players().size() == 2, "23. другая версия игры: отказ, в лобби не попал")
	merge_client("old")
	# гонка с задержкой и потерями (у хоста и у клиента)
	N.sim_delay = 0.09
	N.sim_loss = 0.08
	await until(func(): return players().size() == 2 and bool(players()[1]["ready"]), 15.0)
	N.start_race()
	await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.go, 30.0)
	race = main.race
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "normal", 2)
	cr = race.rider_of_peer(players()[1]["id"]) if players().size() > 1 else null
	var maxd := 0.0
	var tl := Time.get_ticks_msec()
	while cr != null and not cr.disconnected and Time.get_ticks_msec() - tl < 7000:
		maxd = maxf(maxd, cr.dist)
		await get_tree().process_frame
	ok(cr != null and maxd > 40.0, "25–26. с задержкой 90 мс и 8%% потерь клиент едет (%.0f м)" % maxd)
	await until(func(): return client_log("main").contains("плавно"), 20.0)
	# клиент уходит посреди гонки
	await until(func(): return players().size() == 1, 25.0)
	ok(cr != null and cr.disconnected and race.state in ["race", "done", "results"], "20. клиент отключился посреди гонки: помечен, гонка идёт")
	N.sim_delay = 0.0
	N.sim_loss = 0.0
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "hard", 3)
	var fin2: bool = await until(func(): return race.state == "results", 90.0)
	ok(fin2 and race.results.back()["dc"], "гонка закончилась, ушедший — в конце таблицы «(вышел)»")
	merge_client("main")
	merge_client("evil")
	N.back_to_lobby()
	race.quit_to_lobby()
	await until(func(): return main.race == null, 10.0)
	# ===== C: хост закрыл лобби, клиент — к новому =====
	spawn_client("rejoin")
	await until(func(): return players().size() == 2, 20.0)
	await wait(1.5)                              # клиент получил лобби — теперь закрываем
	N.leave_peer()
	ok(not N.online(), "21. хост закрыл лобби")
	await wait(2.0)
	port += 1
	N.host_lobby({"room": "ВТОРОЕ", "name": "ХОСТ", "max": 8, "laps": 1, "port": port})
	var back: bool = await until(func(): return players().size() == 2, 30.0)
	ok(back, "22. клиент переподключился к новому лобби")
	await until(func(): return client_log("rejoin").contains("готово"), 15.0)
	merge_client("rejoin")
	N.leave_peer()
	await wait(1.5)
	await _phase_d(N)
	# занятый порт: пока лобби открыто, второе на том же порту не открывается
	port += 1
	N.host_lobby({"room": "ЗАНЯТО", "name": "ХОСТ", "port": port})
	var berr := ENetMultiplayerPeer.new().create_server(port, 4)
	ok(berr != OK, "занятый порт: второй сервер на %d не открылся (%s)" % [port, error_string(berr)])
	N.leave_peer()
	# ===== 27–28. выход и обычная кампания =====
	if main.race != null:
		main.end_race_online("")
	await wait(1.0)
	main.race_net.queue_free()
	main.race_net = null
	await wait(0.5)
	ok(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "27. после сети игра офлайн (OfflineMultiplayerPeer)")
	ok(main.menu != null, "возврат в меню")
	main.start_game(false, 0)
	var camp: bool = await until(func(): return main.game != null and main.game.player != null, 20.0)
	ok(camp and get_tree().root.get_node_or_null("Main/RaceNet") == null, "28. обычная кампания после сетевой гонки запускается, сети нет")
	_host_finish()

func _host_finish() -> void:
	for p in KEEP:
		if kept.get(p) == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	print("NETCHECK ok" if fails == 0 else "NETCHECK ОШИБКА: %d" % fails)
	get_tree().quit()

# ---------------- клиент ----------------
func _client_run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(1.0)
	var N := net()
	var reason := [""]
	N.failed.connect(func(r: String): reason[0] = r)
	N.closed.connect(func(r: String): reason[0] = "closed:" + r)
	var nm := "ДРУГ" if role == "main" else role.to_upper()
	var err := N.join("127.0.0.1", port, nm, "")
	ok(err == "", "подключение начато")
	if role == "old":
		await until(func(): return reason[0] != "", 15.0)
		ok(String(reason[0]).contains("версии") and not N.online(), "другая версия: понятный отказ («%s»), соединение закрыто" % reason[0])
		get_tree().quit()
		return
	var j: bool = await until(func(): return not N.lobby.is_empty() and N.my_id > 1, 15.0)
	ok(j, "в лобби: id %d, участников %d (причина: %s, статус %s)" % [N.my_id, (N.lobby.get("players", []) as Array).size(), reason[0], str(multiplayer.multiplayer_peer.get_connection_status()) if multiplayer.multiplayer_peer else "-"])
	match role:
		"main":
			await _client_main(N)
		"evil":
			await _client_evil(N)
		"rejoin":
			await until(func(): return reason[0].begins_with("closed:"), 20.0)
			ok(reason[0].begins_with("closed:") and not N.online(), "хост закрыл лобби — понятное сообщение, игра офлайн")
			await wait(3.0)
			reason[0] = ""
			N.join("127.0.0.1", port + 1, nm, "")
			var j2: bool = await until(func(): return not N.lobby.is_empty() and String(N.lobby.get("room", "")) == "ВТОРОЕ", 15.0)
			ok(j2, "переподключился к новому лобби «ВТОРОЕ»")
			ok(true, "готово")
			N.leave_peer()
		_:
			# fill: готов и ездит ботом
			N.set_ready(true)
			await until(func(): return main.race != null and is_instance_valid(main.race), 60.0)
			if main.race != null:
				main.race.local.ai = RaceAI.new()
				main.race.local.ai.setup(main.race.local, main.race, "normal", N.my_id)
			for q in 7:
				await wait(2.0)
				if main.race == null and OS.get_cmdline_user_args().has("--net-debug"):
					print("NETPOS ms=%d гонки нет" % Time.get_ticks_msec())
				if main.race != null and OS.get_cmdline_user_args().has("--net-debug"):
					var L: RaceRider = main.race.local
					print("NETPOS ms=%d fps=%d state=%s t=%.1f %s lat %.1f v %.1f inp go=%s fix=%s" % [Time.get_ticks_msec(), Engine.get_frames_per_second(), main.race.state, main.race.t, str(L.global_position.snapped(Vector3.ONE * 0.1)), L.lat, L.speed, str(main.race.go), str(main.race.net_fix)])
			if main.race != null:
				ok(true, "проехал %.0f м, скорость %.1f, кадров/с %d" % [main.race.local.dist, main.race.local.speed, Engine.get_frames_per_second()])
			await until(func(): return reason[0] != "", 90.0)
			ok(main.race == null or reason[0] != "", "8 гонщиков: загрузился, ехал, хост закрыл — вышел")
	await wait(0.5)
	get_tree().quit()

func _client_main(N: RaceNet) -> void:
	N.set_ready(false)
	await wait(0.4)
	N.set_ready(true)
	var loaded: bool = await until(func(): return main.race != null and is_instance_valid(main.race), 30.0)
	ok(loaded, "хост начал — трасса построена у клиента")
	if not loaded:
		return
	var race: Race = main.race
	ok(not race.authority and race.local != null and race.local.peer == N.my_id, "клиент — не власть, свой гонщик — local")
	var waited_go: bool = await until(func(): return race.go, 30.0)
	ok(waited_go and race.state == "race", "старт по сигналу хоста (не раньше)")
	# управление: газ, руль по дороге, дрифт, прыжок, турбо, предмет
	var L := race.local
	var t0 := Time.get_ticks_msec()
	var phase := 0
	var far := 0.0
	var stuck_t := 0.0
	var back_t := 0.0
	while Time.get_ticks_msec() - t0 < 8000:
		var inp := RaceInput.new()
		inp.throttle = 1.0
		var tg: Vector3 = race.track.point(L.s + 10.0 + absf(L.speed) * 0.5)
		var to := tg - L.global_position
		inp.steer = clampf(-angle_difference(L.heading, atan2(to.x, to.z)) * 2.5, -1.0, 1.0)
		var el := Time.get_ticks_msec() - t0
		far = maxf(far, L.global_position.distance_to(race.track.grid(L.slot).origin))
		# упёрся (столкнулся на старте с ботом хоста, развернуло к стене) — сдать назад, как сделал бы человек
		stuck_t = stuck_t + 1.0 / 60.0 if el > 1500 and absf(L.speed) < 2.0 and back_t <= 0.0 else 0.0
		if stuck_t > 0.7:
			back_t = 0.8
			stuck_t = 0.0
		if back_t > 0.0:
			back_t -= 1.0 / 60.0
			inp.throttle = 0.0
			inp.brake = 1.0
			inp.steer = -inp.steer
		if el > 2000 and el < 2100:
			inp.jump = true
		if el > 3000 and el < 4600:
			inp.drift = true
			inp.steer = 0.9 if inp.steer >= 0.0 else -0.9
		if el > 5000 and el < 6000:
			inp.boost = true
		L.turbo = maxf(L.turbo, 40.0)
		if L.item != "" and phase == 0:
			inp.item = true
			phase = 1
		L.set_meta("auto", inp)
		if OS.get_cmdline_user_args().has("--net-debug") and Engine.get_physics_frames() % 30 == 0:
			print("NETPOS el=%d s=%.1f pos=%s v=%.1f steer=%.2f head=%.2f fix=%s" % [el, L.s, str(L.global_position.snapped(Vector3.ONE * 0.1)), L.speed, inp.steer, L.heading, str(race.net_fix)])
		await get_tree().physics_frame
	L.remove_meta("auto")
	ok(far > 20.0, "свой гонщик отзывается сразу (предсказание), отъехал до %.0f м" % far)
	# дальше ведёт бот — до финиша
	L.ai = RaceAI.new()
	L.ai.setup(L, race, "hard", 9)
	var hostr: RaceRider = race.riders.filter(func(r): return r.puppet)[0]
	var hits := L.events.filter(func(e): return e[0] == "hit").size()
	var fin: bool = await until(func(): return race.state == "results", 150.0)
	ok(L.events.filter(func(e): return e[0] == "hit").size() > hits or L.events.any(func(e): return e[0] == "hit"), "попадание по мне пришло событием от хоста")
	ok(fin and race.results.size() == 2, "результаты от хоста")
	ok(true, "результаты: " + ",".join(race.results.map(func(r): return String(r["title"]))))
	# второй заезд: снова READY, ехать с задержкой и потерями, следить за плавностью кукол, уйти посреди гонки
	await until(func(): return main.race == null and main.menu != null, 20.0)
	N.sim_delay = 0.09
	N.sim_loss = 0.08
	N.set_ready(true)
	await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.go, 40.0)
	race = main.race
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "normal", 10)
	var host2: RaceRider = race.riders.filter(func(r): return r.puppet)[0]
	var last := host2.smooth.global_position
	var max_step := 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
		var pnow := host2.smooth.global_position
		max_step = maxf(max_step, pnow.distance_to(last))
		last = pnow
	ok(max_step < 2.5, "с задержкой и потерями куклы плавно: самый большой шаг за кадр %.2f м" % max_step)
	ok(race.local.global_position.distance_to(race.track.grid(race.local.slot).origin) > 30.0, "с задержкой и потерями свой гонщик едет (%.0f м от старта, %.1f м/с; поправок хоста: резких %d, мягких %.1f м)" % [race.local.global_position.distance_to(race.track.grid(race.local.slot).origin), race.local.speed, int(race.net_fix["hard"]), float(race.net_fix["soft"])])
	get_tree().quit()                          # уходим посреди гонки (как закрыть игру)

func _client_evil(N: RaceNet) -> void:
	# неверные значения: не тот размер ввода, не те типы, подложный гонщик, вызовы «хостовых» RPC, спам
	N.rpc_id(1, "c_input", PackedByteArray([1, 2]))
	N.rpc_id(1, "c_input", PackedByteArray([255, 0, 127, 15]))       # старый размер без номера — отказ
	N.rpc_id(1, "c_input", "газ на полную")
	N.rpc_id(1, "c_ready", 7)
	N.rpc_id(1, "c_pick", "../../secret.glb")
	N.rpc_id(1, "c_pick", {"id": "pahan"})
	N.rpc_id(1, "c_hello", "v", 1, 2, 3)
	N.rpc_id(1, "h_lobby", {"players": []})
	N.rpc_id(1, "h_results", [[0, 0.0, 0.0, false, false]])
	N.rpc_id(1, "h_load", {"track": "res://scripts/main.gd", "riders": []})
	for k in 400:
		N.rpc_id(1, "c_input", PackedByteArray([255, 0, 127, 15, 0, 0]))
	ok(true, "спам отправлен")
	await wait(1.5)
	ok(true, "хост ответил на нарушения: %s" % ("отключил нарушителя" if not N.online() else "остался на связи"))
	N.leave_peer()

## ===== D: 8 участников =====
func _phase_d(N: RaceNet) -> void:
	var race: Race
	port += 1
	N.host_lobby({"room": "ВОСЕМЬ", "name": "ХОСТ", "max": 8, "laps": 1, "port": port})
	for k in 7:
		spawn_client("fill%d" % k)
	var full: bool = await until(func(): return players().size() == 8 and players().all(func(p): return bool(p["ready"])), 60.0)
	ok(full, "8 участников в лобби, все READY (%d)" % players().size())
	var started8 := full and N.start_race()
	var go8: bool = await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.go, 120.0)
	ok(started8 and go8 and main.race.riders.size() == 8, "гонка на 8 гонщиков началась у всех")
	if go8:
		race = main.race
		race.local.ai = RaceAI.new()
		race.local.ai.setup(race.local, race, "normal", 4)
		N.bytes_out = 0
		var tb := Time.get_ticks_msec()
		for q in 5:
			await wait(2.0)
			if OS.get_cmdline_user_args().has("--net-debug"):
				print("NETPOS host t=%.1f " % race.t + ", ".join(race.riders.map(func(r): return "%s %s v%.0f in(%.1f,%.1f) seq%d" % [r.title, str(r.global_position.snapped(Vector3.ONE * 0.1)), r.speed, r.net_input.throttle if r.net_input else 0.0, r.net_input.steer if r.net_input else 0.0, r.net_seq])))
		var kbs := float(N.bytes_out) / ((Time.get_ticks_msec() - tb) / 1000.0) / 1024.0
		ok(kbs < 80.0, "трафик хоста на 7 клиентов: %.1f КБ/с снимков (снимок %d байт)" % [kbs, race.net.snapshot(race).size()])
		var moving := race.riders.filter(func(r): return r.dist > 20.0).size()
		print("NET   8 гонщиков: " + ", ".join(race.riders.map(func(r): return "%s %.0f м %.0f м/с" % [r.title, r.dist, r.speed])) + " · кадров/с хоста %d" % Engine.get_frames_per_second())
		for r in race.riders:
			print("NET     %s: шлюз %d, круг %d, s %.0f, сбоку %.1f/%.1f, на старте %s, %s" % [r.title, r.next_gate, r.lap, r.s, r.lat, r.half, str(r.get_meta("armed", false)), str(r.global_position.snapped(Vector3.ONE))])
		ok(moving >= 7, "у 8 гонщиков ввод доходит: едут %d" % moving)
	N.leave_peer()
	await wait(3.0)
	for k in 7:
		merge_client("fill%d" % k)
