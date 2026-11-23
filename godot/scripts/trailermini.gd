## Съёмка трейлера мини-игр («ночной эфир ОБЛАКО-ТВ»): `--fixed-fps 30 --resolution 1280x720 -- --trailermini=<папка>`.
## Кадры JPG по планам (<план><номер>.jpg) для tools/trailer/compose-mini.html:
##   «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: MA — комната (наезд на Пахана за столом), MH — телефон на столе крупно, MB — экран дня, MC — карта долгов,
##     MD — звонок коллектора, ME — дерево развития, MF — бизнес; J1…J5 — подработки (уборка, ремонт, доставка, хлам,
##     звукарь), MG — итог подработки;
##   «5 НОЧЕЙ С ПАХАНОМ»: FA — терминал, FB — заставка ночи, FC — будка (взгляд влево-вправо), FD — камеры по кругу,
##     FE — свет у двери, FG — темнота; E1…E6 — обитатели по одному под лампой (БАЛОН, MADK1D, BOT, CLIPPER, GHOST,
##     MOD); S1…S6 — их скримеры; FH — 6 AM.
## Плюс звуки (sfx_*.wav — синтез живёт в игре). Сохранения игрока не пишутся и сверяются.
extends Node

const KEEP := ["user://grimerka_save.json", "user://microloans_save.json", "user://microloans_save.json.bak", "user://five_nights_save.json", "user://five_nights_save.json.bak"]
var main
var out := ""
var kept := {}
var count := 0
var only := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else (null as Variant)
	MLSave.persist = false
	FNSave.persist = false
	AudioServer.set_bus_mute(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mini-only="):
			only = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, false).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0) * 4:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

## n кадров плана; each(i, k) — что двигать перед каждым кадром (k — доля 0..1)
func grab(prefix: String, n: int, each := Callable()) -> void:
	for i in n:
		if each.is_valid():
			each.call(i, float(i) / float(maxi(1, n - 1)))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("%s%03d.jpg" % [prefix, i]), 0.9)
		count += 1
	print("TRAILERMINI %s: %d кадров" % [prefix, n])

func _run() -> void:
	await wait(1.5)
	_export_sfx()
	if only in ["", "ml", "mh"]:
		await _microloans()
	if only in ["", "fn"]:
		await _five_nights()
	_finish()

func _export_sfx() -> void:
	FNSound.warm()
	for id in ["scream_balon", "scream_madk1d", "scream_bot", "scream_clipper", "scream_ghost", "scream_mod", "static", "chime", "hum", "vent_bang", "door_down", "music_box_air", "ping", "cam", "heart", "ring", "power_down", "whisper", "breath", "click"]:
		var s = FNSound.get_stream(id)
		if s != null:
			s.save_to_wav(out.path_join("sfx_" + id + ".wav"))
	MLSound.warm()
	for id in ["notify", "alert", "ring", "money", "coins", "bills", "pay", "stamp", "loan", "buy", "phase", "cheer", "whoosh", "clean"]:
		if MLSound._cache.has(id):
			(MLSound._cache[id] as AudioStreamWAV).save_to_wav(out.path_join("ml_" + id + ".wav"))

func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

# ---------------- ПАХАН НАБРАЛ МИКРОЗАЙМОВ ----------------
func _microloans() -> void:
	main.start_minigame("microloans", {"continue": false})
	await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is MicroloansRoot, 15.0)
	await wait(2.5)
	var R: MicroloansRoot = main.minigame
	var e := R.econ
	var U := R.ui
	var C: MLCareer = e.career
	C.from_dict({})
	e.new_game(812)
	e.event_today = ""
	e.phase = "day"
	e.actions = MLData.ACTIONS
	e.money = 4200
	U.show_phase()
	await wait(0.6)
	# MA — комната без интерфейса: камера въезжает от двери к столу, телефон вспыхивает уведомлением
	U.visible = false
	var tc := Camera3D.new()
	tc.fov = 42.0
	R.add_child(tc)
	tc.current = true
	var a0 := Vector3(1.9, 2.3, 3.4)
	var a1 := Vector3(0.75, 1.75, 0.55)
	if only != "mh":
		await grab("MA_", 100, func(i: int, k: float):
			var kk := _ease(k)
			tc.look_at_from_position(a0.lerp(a1, kk), Vector3(-0.25, 1.0 - 0.1 * kk, -1.55), Vector3.UP)
			if i == 55:
				R._on_note("Срок по займу — сегодня.", "bad"))
	# MH — крупно сбоку над столом: телефон светится на переднем плане, за ним Пахан (камера медленно подъезжает)
	tc.fov = 36.0
	await grab("MH_", 120, func(i: int, k: float):
		if i % 40 == 0:
			R._on_note("Входящий звонок.", "bad")
		tc.look_at_from_position(Vector3(1.42 - 0.22 * k, 0.99 + 0.05 * k, -1.92 + 0.2 * k), Vector3(0.12, 1.14, -1.3), Vector3.UP))
	tc.queue_free()
	if only == "mh":
		return
	R.cam.current = true
	U.visible = true
	for c in U.notes_box.get_children():
		c.queue_free()
	await wait(0.3)
	# MB — экран дня: выбор ходит по пунктам
	await grab("MB_", 66, func(i: int, _k: float):
		if i > 0 and i % 11 == 0:
			U._select(U.sel + 1))
	# MC — карта долгов: «самый срочный», сумма платежа
	U.debt_flow()
	await wait(0.5)
	await grab("MC_", 80, func(i: int, _k: float):
		if i == 22:
			U._flow_keys(KEY_E)
		elif i == 44:
			U._flow_keys(KEY_Q)
		elif i > 50 and i % 6 == 0:
			U._flow_keys(KEY_A))
	U.show_phase()
	await wait(0.2)
	# MD — звонок коллектора «Срочно Финанс»: фразы печатаются, ответы игрока
	var tgt: Dictionary = e.active().filter(func(L): return L["lender"] == "srochno")[0] if e.active().any(func(L): return L["lender"] == "srochno") else e.active()[0]
	tgt["due"] = e.day
	var N: MLNegotiation = U.negotiate(int(tgt["id"]), func(): pass)
	N.voice_on = false
	N.vo.stop()
	N.auto_answers = [[2, 0, true], [3, 3, true]]
	await wait(0.5)
	await grab("MD_", 170, func(i: int, _k: float):
		if i == 150 and N.doc_mode:
			N.pick_doc(N.DOCS.map(func(d): return d[0]).find(N.doc_right)))
	N._end()
	await wait(1.4)
	# ME — дерево развития: выбор гуляет по веткам; MF — бизнес
	C.d["points"] = 6
	C.d["level"] = 7
	for nid in ["w_hands", "w_suction", "w_fix", "w_legs"]:
		C.d["nodes"][nid] = 1
	e.changed.emit()
	U.dev_tree()
	await wait(0.6)
	var T := U.tree_ui
	await grab("ME_", 78, func(i: int, _k: float):
		if i % 6 == 0:
			@warning_ignore("integer_division")
			T._pick(String(T.order[(i / 6 * 5) % T.order.size()])))
	e.money = 300000
	for b in ["workshop", "cleaning", "delivery"]:
		var cst := C.biz_up(b, e.money)
		e.money -= maxi(0, cst)
		e.money -= maxi(0, C.hire(b, e.money))
	R.biz_visuals()
	U.biz_screen()
	await wait(0.5)
	await grab("MF_", 54, func(i: int, _k: float):
		if i > 0 and i % 9 == 0:
			U._select(U.sel + 1))
	# подработки: бот играет сам
	var n_j := 0
	for jid in ["podezd", "repair", "deliv", "junk", "sound"]:
		n_j += 1
		e.actions = MLData.ACTIONS
		e.stress = 10
		e.phase = "day"
		U.show_phase()
		await wait(0.2)
		var J: MLJob = U.run_job(jid, 0.95)
		await wait({"podezd": 3.2, "repair": 5.0, "deliv": 3.0, "junk": 2.2, "sound": 2.4}[jid])
		if not is_instance_valid(J):
			continue
		await grab("J%d_" % n_j, 84)
		if jid == "podezd" and is_instance_valid(J):
			J.bot = -1.0
			(J as MLJob3D).show_result(0.93, ["убрано 96 % · контейнер 70 % · шланг 85 %", "серия ×6: +22 % к оплате", "провода соседей целы"])
			await wait(0.3)
			await grab("MG_", 45)
		if is_instance_valid(J):
			J.bot = 0.95
			if not J.done:
				J.finish(0.9)
		await until(func(): return U.overlay == null, 6.0)
		await wait(0.3)
	R.quit_to_menu()
	await until(func(): return main.menu != null, 8.0)
	await wait(0.8)

# ---------------- 5 НОЧЕЙ С ПАХАНОМ ----------------
func _night(R: FiveNightsRoot, n: int) -> FNNight:
	R.start_night(n)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 14.0)
	for id in R.st.enemies:
		(R.st.enemies[id] as FNEnemy).level = 0
	R.call_lines.clear()
	R.ring_t = 0.0
	R.hint_t = 0.0
	R._say_clear()
	return R.st

func _five_nights() -> void:
	main.start_minigame("five_nights")
	await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is FiveNightsRoot, 15.0)
	await wait(2.0)
	var R: FiveNightsRoot = main.minigame
	await grab("FA_", 70, func(i: int, _k: float):
		if i > 0 and i % 14 == 0:
			R.menu.select(R.menu.sel + 1, false))
	# FB — заставка первой ночи
	R.start_night(0)
	await wait(0.25)
	await grab("FB_", 80)
	var st: FNNight = await _night(R, 0)
	await wait(1.0)
	# FC — будка: взгляд влево, вправо, на стол
	await grab("FC_", 120, func(i: int, _k: float):
		R.look_key = -1.0 if i < 40 else (1.0 if i < 85 else 0.0))
	R.look_key = 0.0
	# FD — камеры: зал (Балон смотрит в камеру), игровая, склад, серверная, питание
	var b: FNEnemy = st.enemies["balon"]
	b.level = 1
	b.spot = "stage"
	b.look = true
	(st.enemies["clipper"] as FNEnemy).level = 1
	(st.enemies["clipper"] as FNEnemy).spot = "arcade"
	(st.enemies["bot"] as FNEnemy).level = 1
	(st.enemies["bot"] as FNEnemy).spot = "server"
	(st.enemies["mod"] as FNEnemy).level = 1
	(st.enemies["mod"] as FNEnemy).spot = "power"
	R.actors.place_key.clear()
	st.set_monitor(true)
	st.set_cam("stage")
	await wait(0.9)
	var cams := ["stage", "arcade", "storage", "server", "power"]
	await grab("FD_", 150, func(i: int, _k: float):
		if i % 30 == 0:
			@warning_ignore("integer_division")
			st.set_cam(cams[(i / 30) % cams.size()]))
	st.set_monitor(false)
	b.look = false
	for id in ["clipper", "bot", "mod"]:
		(st.enemies[id] as FNEnemy).level = 0
	await wait(0.8)
	# FE — свет у левой двери, а там он
	b.spot = "door_l"
	b.door_t = -999.0
	R.actors.place_key.clear()
	R.look_key = -1.0
	await wait(1.0)
	await grab("FE_", 75, func(i: int, _k: float):
		R.light_hold["l"] = i >= 12 and (i < 38 or i > 46))
	R.light_hold["l"] = false
	R.look_key = 0.0
	b.level = 0
	b.spot = "stage"
	R.actors.place_key.clear()
	await wait(0.5)
	# E1…E6 — обитатели по одному: чёрная пустота, лампа сверху, камера медленно подъезжает
	await _roster(R)
	# FG — темнота: энергия кончилась, глаза в проёме
	st = await _night(R, 4)
	st.power = 0.3
	await until(func(): return st.power_out, 6.0)
	await wait(3.0)
	await grab("FG_", 66)
	# S1…S6 — скримеры
	var n := 0
	for c in [["balon", "door_l"], ["madk1d", "vent_t"], ["bot", "door_r"], ["clipper", "door_l"], ["ghost", "stage"], ["mod", "door_r"]]:
		n += 1
		st = await _night(R, 4)
		(st.enemies[c[0]] as FNEnemy).level = 10
		await wait(0.4)
		st.attack(c[0], c[1])
		await until(func(): return R.state == "scare", 3.0)
		await grab("S%d_" % n, 56)
		await until(func(): return R.state == "dead", 6.0)
	# FH — шесть утра
	st = await _night(R, 0)
	R.ui.hud.visible = false
	R.ui.six_card(37, "Шесть. Шесть, бля. Живой.", "")
	await grab("FH_", 110)
	R.ui.clear_card()
	R.to_terminal()
	await wait(0.6)
	R.quit_to_menu()
	await until(func(): return main.menu != null, 8.0)
	await wait(0.5)

func _roster(R: FiveNightsRoot) -> void:
	R.paused = true
	R.ui.hud.visible = false
	R.actors.hide_all()
	var base := Vector3(0, -60, 0)
	var stage := Node3D.new()
	stage.position = base
	R.add_child(stage)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.05, 0.055)
	fm.roughness = 0.35
	fl.material_override = fm
	stage.add_child(fl)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(14, 8, 0.2)
	back.mesh = bm
	back.material_override = fm
	back.position = Vector3(0, 4, -3.2)
	stage.add_child(back)
	var top := SpotLight3D.new()
	top.position = Vector3(0, 4.2, 0.9)
	top.rotation = Vector3(-1.32, 0, 0)
	top.spot_range = 7.0
	top.spot_angle = 26.0
	top.light_energy = 9.0
	top.light_color = Color(1.0, 0.92, 0.82)
	top.shadow_enabled = true
	stage.add_child(top)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.6, 1.4, -1.6)
	rim.light_color = Color(1.0, 0.1, 0.08)
	rim.light_energy = 2.2
	rim.omni_range = 4.5
	stage.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 34.0
	stage.add_child(cam)
	cam.current = true
	var n := 0
	for id in FNData.ORDER:
		n += 1
		var r: Rig = R.actors.rigs[id]
		var h: float = float(FNActors.OWN[id]["h"]) if R.actors.owned.has(id) else float(R.actors.LOOK[id]["h"])
		R.actors.hide_all()
		R.actors.scare_pose(id, false)
		r.visible = true
		r.global_position = base
		r.rotation = Vector3.ZERO
		r.player.speed_scale = 1.0
		r.play("FNStare", 0.0)
		R.actors.maw(id, 0.0)
		for k in 6:
			await get_tree().process_frame
		await grab("E%d_" % n, 60, func(i: int, k: float):
			r.rotation.y = lerpf(-0.55, 0.25, _ease(k))
			# свет дёргается, как плохая лампа; в конце гаснет — остаются глаза
			top.light_energy = 9.0 if (i < 48 or i % 3 == 0) and not (i in [9, 10, 23]) else 0.4
			cam.look_at_from_position(base + Vector3(0.5 - 0.3 * k, h * 0.62, lerpf(5.0, 3.6, _ease(k)) * h / 1.8), base + Vector3(0, h * 0.55, 0), Vector3.UP))
	R.actors.hide_all()
	stage.queue_free()
	R.office.cam.current = true
	R.ui.hud.visible = true
	R.paused = false
	await wait(0.4)

func _finish() -> void:
	var same := true
	for p in KEEP:
		var now = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else (null as Variant)
		if (now == null) != (kept[p] == null) or (now != null and now != kept[p]):
			same = false
			print("TRAILERMINI изменён файл ", p)
	MLSave.persist = true
	FNSave.persist = true
	AudioServer.set_bus_mute(0, false)
	print("TRAILERMINI frames=%d saves_untouched=%s" % [count, str(same)])
	get_tree().quit()
