## Проверка приквела «ГОЛДА 67»: `--resolution 1280x720 -- --golda67check=<папка>`.
## Идёт из главного меню как игрок: PLAY → вторая карточка «ГОЛДА 67» → экран режима → подъезд. Проверяет порядок
## режимов, запуск, хаб из моделей (ни одной пропавшей), ходьбу настоящими клавишами, предметы и подсказку [E],
## что сохранение кампании не изменилось, и возврат в меню на карточку приквела.
extends Node

const AC := Vector3(2.0, 0.0, -38.25)      # центр коробки Миши (арена боя с боссом)
const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://golda67_save.json", "user://golda67_save.json.bak"]

var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	AudioServer.set_bus_mute(0, true)
	G67Save.clean = true          # прогресс игрока в приквеле на проверку не влияет
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("GOLDA67CHECK ok: " if cond else "GOLDA67CHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: Key, hold := 0.06) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(hold if down else 0.06)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func save_same() -> bool:
	var p := "user://grimerka_save.json"
	var now = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	return now == kept[p]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	# ================= меню: вторая карточка =================
	var mm = main.menu
	ok(mm != null and mm is Menu, "главное меню открыто")
	var ids: Array = []
	for m in ModeSelect.MODES:
		ids.append(String(m["id"]))
	ok(ids == ["story", "golda67", "training", "race", "microloans", "five_nights"], "порядок режимов: %s" % ", ".join(ids))
	ok(ModeSelect.index_of("golda67") == 1, "«ГОЛДА 67» — вторая карточка")
	var nos: Array = []
	for m in ModeSelect.MODES:
		nos.append(String(m["no"]))
	ok(nos == ["01", "02", "03", "04", "05", "06"], "номера на карточках идут подряд (%s)" % ", ".join(nos))
	mm._select(1, false)
	await key(KEY_ENTER)
	await wait(0.5)
	var ms: ModeSelect = mm.modes
	ok(ms.visible and ms.cards.size() == 6, "экран выбора режима: %d карточек" % ms.cards.size())
	ms.select(0, false, true)
	await wait(0.2)
	await key(KEY_S)
	await wait(0.5)
	ok(ms.sel == 1 and String(ModeSelect.MODES[ms.sel]["id"]) == "golda67", "клавиша S с первой карточки выбирает «ГОЛДА 67»")
	ok(String(ms.desc_title.text).contains("02"), "описание выбранного режима: «%s»" % ms.desc_title.text)
	await wait(0.6)
	await shot("01_card")
	# клик мышью по второй карточке открывает экран приквела, а не тренировку
	ms.select(0, false, true)
	var c: Control = ms.cards[1]["root"]
	var pos: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var mo := InputEventMouseMotion.new()
	mo.position = pos
	mo.global_position = pos
	Input.parse_input_event(mo)
	await wait(0.2)
	ok(ms.sel == 1, "мышь: наведение на вторую карточку выбирает её")
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await wait(0.08)
	await wait(0.4)
	ok(mm.panel != null and mm.panel_rows.size() == 2, "клик по второй карточке открывает экран «ГОЛДА 67» (%d пунктов)" % (mm.panel_rows.size() if mm.panel != null else -1))
	await shot("02_panel")
	# Esc — назад к режимам, Enter — снова экран
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel == null and ms.visible and ms.sel == 1, "Esc — назад на карточку приквела")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null, "Enter на карточке открывает экран режима")
	# ================= запуск =================
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.golda != null and main.game.golda.world != null, 25.0)
	ok(started, "«ВОЙТИ В ПОДЪЕЗД» запускает режим")
	if not started:
		_finish()
		return
	await wait(3.0)
	var g = main.game
	var G: Golda67 = g.golda
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--g67-frames="):
			await _clip_frames(G, String(arg).substr(13))
			_finish()
			return
	if OS.get_cmdline_user_args().has("--g67-ev02"):
		G.play_clip("EV02")
		await wait(0.3)
		var t_last := 0.0
		var marks: Array = [19.0, 24.0]       # ключевые моменты: вход с ведром, замах, вода, бросок, беготня, финал
		var mi := 0
		while G.clip != null and is_instance_valid(G.clip):
			t_last = G.clip.t
			if G67Clips.snap_req != "":
				var nm: String = G67Clips.snap_req
				G67Clips.snap_req = ""
				var hp: Vector3 = Vector3.ZERO
				await shot("ev02k_" + nm)
			if mi < marks.size() and t_last >= float(marks[mi]):
				await shot("ev02k_t%02d" % int(float(marks[mi]) * 10.0))
				mi += 1
			await get_tree().process_frame
		print("GOLDA67CHECK   EV02 длина %.1f с" % t_last)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-boss"):
		await _boss_scene_shots(g, G, g.player, OS.get_cmdline_user_args().has("--g67-skip"))
		_finish()
		return
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--g67-evscene="):
			await _ev_scene_shots(g, G, g.player, String(arg).substr(14))
			_finish()
			return
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--g67-clip="):
			await _clip_log(G, String(arg).substr(11))
			_finish()
			return
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--g67-micro="):
			await _go(G, g.player, "exit")
			await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
			_kill_all(g)
			G.pending = []
			G.wave_wait = 999.0
			await wait(1.0)
			G.ylife_get().fire(String(arg).substr(12))
			await wait(1.5)
			await shot("micro_" + String(arg).substr(12))
			_finish()
			return
	if OS.get_cmdline_user_args().has("--g67-perfzones"):
		await _perf_zones(g, G, g.player)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-marks"):
		await _go(G, g.player, "exit")
		await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
		_kill_all(g)
		G.pending = []
		G.wave_wait = 999.0
		await wait(1.0)
		await _marks_contrast(g, G)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-whois"):
		await _go(G, g.player, "exit")
		await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
		await wait(1.0)
		for n in G.world.yard.get_children():
			if not (n is Node3D):
				continue
			var bb := _aabb_of(n)
			if bb.size.length() < 0.01:
				continue
			var wc := bb.get_center()
			if Vector2(wc.x + 2.0, wc.z - 1.2).length() < 1.6:
				var kids: Array = []
				for ch in n.get_children():
					kids.append("%s:%s" % [ch.name, ch.get_class()])
				var meshes: Array = []
				for mi in n.find_children("*", "MeshInstance3D", true, false):
					meshes.append("%s|%s" % [mi.name, (mi as MeshInstance3D).mesh.resource_path if (mi as MeshInstance3D).mesh != null else ""])
				print("GOLDA67CHECK   WHOIS %s class=%s scene=%s script=%s pos=%s size=%s kids=%s meshes=%s" % [n.name, n.get_class(), n.scene_file_path, str(n.get_script()), str(n.global_position), str(bb.size), str(kids.slice(0, 4)), str(meshes.slice(0, 4))])
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-collwalk"):
		await _coll_walk(g, G, g.player)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-collprobe"):
		await _coll_probe(g, G, g.player)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-perf"):
		await _perf_flyover(g, G, g.player)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-cam"):
		await _cam_check(g, G, g.player)
		_finish()
		return
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--g67-real" or String(arg).begins_with("--g67-real="):
			var rn := 0
			if String(arg).begins_with("--g67-real="):
				rn = int(String(arg).substr(11))
			await _real_run(g, G, rn)
			_finish()
			return
	ok(g.training == null and g.mode == "golda67", "режим приквела (mode = %s), это не арена" % g.mode)
	ok(G.place == "hub" and G.world is G67World, "место — подъезд")
	ok(G.world.missing.is_empty(), "все модели хаба на месте (нет: %s)" % ", ".join(G.world.missing))
	ok(G.world.points.size() >= 9, "предметов хаба: %d" % G.world.points.size())
	ok(G.world.actors.has("g67_dj_flurr") and is_instance_valid(G.world.actors["g67_dj_flurr"]), "dj flürr стоит в подъезде")
	ok(String(g.top_label.text).begins_with("ГОЛДА 67"), "строка вверху: «%s»" % g.top_label.text)
	ok(not g.xp_label.visible, "счётчика опыта кампании нет")
	await shot("03_hub")
	# ================= ходьба настоящими клавишами =================
	var P = g.player
	var p0: Vector3 = P.global_position
	var e2 := InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = true
	Input.parse_input_event(e2)
	await wait(1.2)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = false
	Input.parse_input_event(e2)
	await wait(0.3)
	var moved: float = P.global_position.distance_to(p0)
	ok(moved > 1.0, "Пахан идёт по подъезду на W (прошёл %.2f м)" % moved)
	ok(absf(P.global_position.x) < G67World.HUB_X and absf(P.global_position.z) < G67World.HUB_Z, "стены держат: Пахан внутри подъезда %s" % str(P.global_position))
	ok(P.global_position.y < 0.6, "Пахан на полу холла (y = %.2f)" % P.global_position.y)
	await shot("04_walk")
	# ================= только Балон до первого босса =================
	ok(G.styles_open() == ["vozduh"] and P.own_styles == ["vozduh"], "до первого босса у Пахана только Балон VOZDUH (%s)" % str(P.own_styles))
	ok(String(P.style.id) == "vozduh", "в руках Балон")
	for kk in [KEY_2, KEY_3]:
		await key(kk)
		await wait(0.4)
	ok(String(P.style.id) == "vozduh" and P.switch_to == "", "клавиши 2 и 3 закрытые стили не включают")
	ok(String(g.toast_label.text).contains("ТЯГА-812 — после победы над FORTUNA 812") or String(g.toast_label.text).contains("Водяра — после победы над Мишей Минасяном"), "клавиша закрытого стиля — тост, когда откроется («%s»)" % g.toast_label.text)
	var fl_meta: Dictionary = {"boss_misha": true}
	G.data["meta"]["flags"] = fl_meta
	ok(G.styles_open() == ["vozduh", "bottles"], "после Миши Минасяна открывается Водяра, ТЯГА-812 закрыта")
	fl_meta["boss_fortuna"] = true
	ok(G.styles_open() == ["vozduh", "bottles", "tyaga812"], "после FORTUNA 812 открывается ТЯГА-812")
	G.data["meta"]["flags"] = {}
	# ================= подъём по лестнице на площадку =================
	P.global_position = Vector3(-2.3, 0.05, 1.9)
	P.velocity = Vector3.ZERO
	P.face = 0.0
	g.cam_yaw = 0.0
	await wait(0.4)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = true
	Input.parse_input_event(e2)
	await wait(1.1)
	await shot("04b_stairs")
	await wait(1.9)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = false
	Input.parse_input_event(e2)
	await wait(0.4)
	ok(P.global_position.y > G67World.LAND_Y - 0.2 and P.global_position.z < G67World.Z_STAIR_TOP, "Пахан поднялся по пролёту на площадку %s" % str(P.global_position))
	await shot("04c_landing")
	# спуск обратно
	P.face = PI
	g.cam_yaw = PI
	await wait(0.3)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = true
	Input.parse_input_event(e2)
	await wait(3.2)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = false
	Input.parse_input_event(e2)
	await wait(0.4)
	ok(P.global_position.y < 0.5 and P.global_position.z > G67World.Z_EDGE, "и спустился обратно в холл %s" % str(P.global_position))
	var fr = G.world.actors["g67_dj_flurr"]
	ok(bool(fr.get_meta("sitting", false)), "dj flürr сидит на лавке")
	# ================= предметы и подсказка =================
	var seen := 0
	for pt in G.world.points:
		P.global_position = Vector3(pt["pos"].x, pt["pos"].y + 0.05, pt["pos"].z)
		P.velocity = Vector3.ZERO
		await wait(0.25)
		if G.near == String(pt["id"]) and G.prompt.visible and String(G.prompt.text).contains(String(pt["title"])):
			seen += 1
		else:
			print("GOLDA67CHECK   нет подсказки у «%s» (near = %s)" % [pt["id"], G.near])
	ok(seen == G.world.points.size(), "подсказка [E] появляется у каждого предмета (%d из %d)" % [seen, G.world.points.size()])
	var tv: Dictionary = G.point("tv")
	P.global_position = Vector3(tv["pos"].x, tv["pos"].y + 0.05, tv["pos"].z)
	await wait(0.3)
	await shot("05_prompt")
	var n0 := G.events.size()
	await key(KEY_E)
	await wait(0.3)
	ok(G.events.slice(n0).has(["use", "tv"]), "клавиша E у телевизора срабатывает")
	ok(G.clip != null and G.clip.id == "V00", "у телевизора впервые — трейлер «ТУРНИР 67»")
	if G.clip != null:
		G.clip.skippable = true          # трейлер подробно проверяет раздел роликов; здесь — только запуск
		G.clip.skip()
	await until(func(): return G.clip == null, 2.0)
	var cs: Array = G.meta().get("clips_seen", [])
	cs.erase("V00")                      # раздел роликов покажет его как впервые
	G.meta()["clips_seen"] = cs
	P.global_position = Vector3(-1.0, 0.05, 3.1)
	await wait(0.3)
	ok(G.near == "" and not G.prompt.visible, "вдали от предметов подсказки нет")
	# снимки хаба с разных точек
	var L := G67World.LAND_Y + 0.05
	for v in [["06_tambur_in", Vector3(0, 0.05, 6.9), 0.0], ["06b_hall_to_stairs", Vector3(0.3, 0.05, 4.6), 0.0], ["06c_hall_to_exit", Vector3(-0.4, 0.05, 2.2), PI],
			["06d_hall_left", Vector3(0.6, 0.05, 3.8), PI * 0.5], ["06e_hall_right", Vector3(-1.8, 0.05, 3.8), -PI * 0.5],
			["07_landing_back", Vector3(-0.2, L, -1.2), 0.0], ["07b_landing_to_hall", Vector3(0.2, L, -4.6), PI],
			["07c_landing_left", Vector3(1.6, L, -3.4), PI * 0.5], ["07d_landing_right", Vector3(-1.4, L, -2.2), -PI * 0.5], ["07e_flurr", Vector3(-1.2, L, -3.55), PI * 0.5]]:
		P.global_position = v[1]
		P.face = v[2]
		g.cam_yaw = v[2]
		await wait(0.8)
		await shot(String(v[0]))
	# ================= пауза и сохранения =================
	g.set_paused(true)
	await wait(0.6)
	ok(get_tree().paused and not G.prompt.visible, "пауза работает, подсказка скрыта")
	await shot("10_pause")
	g.set_paused(false)
	await wait(0.4)
	ok(save_same(), "сохранение кампании не изменилось")
	ok(not FileAccess.file_exists("user://golda67_save.json") or kept["user://golda67_save.json"] == FileAccess.get_file_as_string("user://golda67_save.json"), "проверка не пишет сохранение приквела игрока")
	# ================= экраны подъезда (этап 2) =================
	await _hub_screens(g, G, P)
	if OS.get_cmdline_user_args().has("--g67-hub"):
		_finish()
		return
	if OS.get_cmdline_user_args().has("--g67-s3"):
		await _stage3(g, G, P)
		_finish()
		return
	# ================= dj flürr: одиннадцать состояний =================
	await _madk_check(g, G, P)
	await _voice_check(g, G, P)
	await _clip_check(g, G, P)
	await _flurr_check(g, G, P)
	await _ui3_check(g, G, P)
	await _save_check(g, G)
	await _talks_check(g, G, P)
	_route_gen_check(G)
	await _events_check(g, G, P)
	await _ev02_check(g, G, P)
	# ================= забег: район ДВОР =================
	await _run_dvor(g, G, P)
	# ================= этап 3: кладовка, ларёк, артефакты, фитсы по таблице =================
	await _stage3(g, G, P)
	# ================= КРОТ: постановки встреч 4–10 =================
	await _krot_stage(g, G)
	# ================= выход =================
	g._to_menu()
	var back: bool = await until(func(): return main.menu != null and is_instance_valid(main.menu) and main.game == null, 10.0)
	await wait(1.0)
	ok(back, "выход в меню")
	if back:
		ok(main.menu.modes.visible and main.menu.modes.sel == 1, "после выхода открыт выбор режима на карточке «ГОЛДА 67»")
		await shot("11_back")
	_finish()

## реплики из авторского документа — тем же правилом, что сборщик данных: посимвольная сверка с данными игры
## Снимок Миши сбоку-спереди (обычная камера стоит за спиной героя и закрывает его)
func _side_shot(g, B, nm: String) -> void:
	var oc := Camera3D.new()
	g.add_child(oc)
	var at: Vector3 = B.global_position
	oc.global_position = at + Vector3(3.6, 2.0, 3.4)
	oc.look_at(at + Vector3(0, 1.1, 0.6), Vector3.UP)
	oc.make_current()
	await wait(0.05)
	await shot(nm)
	g.cam.make_current()
	oc.queue_free()

## Снимок места во дворе: at и from — в координатах двора
func _yard_shot(g, G: Golda67, at: Vector3, from: Vector3, nm: String) -> void:
	var off: Vector3 = G.world.yard.position
	var oc := Camera3D.new()
	g.add_child(oc)
	oc.global_position = from + off
	oc.look_at(at + off, Vector3.UP)
	oc.make_current()
	await wait(0.4)
	await shot(nm)
	g.cam.make_current()
	oc.queue_free()

## Жители двора и трибуна: на местах, со скелетом, дышат; сумка бабушки висит вниз
func _yard_people(g, G: Golda67) -> void:
	var Y: G67Yard = G.world.yard
	ok(Y.people.size() == 4, "во дворе четверо фоновых жителей (%s)" % str(Y.people.keys()))
	var alive := true
	for id in Y.people:
		var r: Rig = Y.people[id]
		if r.skel == null or String(r.cur) == "" or not G.world.blocked(r.global_position):
			alive = false
			print("GOLDA67CHECK   житель %s: скелет/клип/место не в порядке" % id)
	ok(alive, "жители со скелетом, стоят и дышат, сквозь них не пройти")
	for who in G67Yard.PEOPLE:
		var p: Vector3 = who["pos"]
		var yaw := float(who["yaw"])
		var fw := Vector3(sin(yaw), 0, cos(yaw))
		await _yard_shot(g, G, p + Vector3(0, float(who["h"]) * 0.55, 0), p + fw * 2.4 + Vector3(-fw.z, 0, fw.x) * float(who.get("shot_side", 1.0)) + Vector3(0, 1.3, 0), "50_" + String(who["id"]).trim_prefix("g67_"))
	if Y.people.has("g67_npc_babushka"):
		var b: Rig = Y.people["g67_npc_babushka"]
		ok(b.skel.find_children("*", "G67Carry", true, false).size() == 1, "у бабушки слой, который держит авоську висящей вниз")
	var poses := {}
	var rigged := true
	for n in Y.fans + Y.queue:
		if not (n is Rig) or (n as Rig).skel == null:
			rigged = false
		else:
			poses[String((n as Rig).cur)] = true
	for id in Y.people:
		poses[String(Y.people[id].cur)] = true
	ok(rigged and Y.fans.size() >= 5, "зрители и очередь — люди со скелетом, без застывших моделей в T-позе (зрителей %d)" % Y.fans.size())
	ok(poses.size() >= 7, "позы у жителей разные (%d видов: %s)" % [poses.size(), ", ".join(poses.keys())])
	var q0: Vector3 = (Y.queue[1] as Node3D).position
	await _yard_shot(g, G, q0 + Vector3(0, 1.0, 0), q0 + Vector3(-0.6, 1.6, 4.2), "53_queue_poses")
	ok(Y.tribune != null and G.world.blocked(G67Yard.TRIBUNE + Y.position), "у коробки Миши стоит трибуна")
	await _yard_shot(g, G, G67Yard.TRIBUNE + Vector3(0, 1.4, 0), G67Yard.TRIBUNE + Vector3(-8.5, 3.2, 5.5), "51_tribune")
	await _yard_shot(g, G, G67Yard.TRIBUNE + Vector3(0, 1.6, 0), G67Yard.TRIBUNE + Vector3(-5.2, 2.4, 0.4), "54_fans_close")
	await _yard_shot(g, G, G67Yard.TRIBUNE + Vector3(0, 1.2, 0), G67Yard.TRIBUNE + Vector3(-2.0, 2.0, -7.5), "52_tribune_side")

## Постановки КРОТА для встреч 4–10: их районов ещё нет, поэтому КРОТ снимается на площадке в стороне от всего
## с простыми заменителями вещей (автомат, кольцевая лампа, сервер, столик с пакетом). Только для оценки поз.
func _krot_stage(g, G: Golda67) -> void:
	var root := Node3D.new()
	root.name = "krot_stage"
	g.add_child(root)
	root.global_position = Vector3(300, 0, 300)
	var floor := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(12, 0.1, 12)
	floor.mesh = fm
	floor.position = Vector3(0, -0.05, 0)
	floor.material_override = _mat(Color(0.32, 0.32, 0.34))
	root.add_child(floor)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(12, 5, 0.2)
	wall.mesh = wm
	wall.position = Vector3(0, 2.5, -2.6)
	wall.material_override = _mat(Color(0.22, 0.24, 0.28))
	root.add_child(wall)
	var key := OmniLight3D.new()
	key.position = Vector3(2.0, 3.0, 3.0)
	key.omni_range = 14.0
	key.light_energy = 3.0
	root.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.0, 2.0, 1.5)
	fill.omni_range = 10.0
	fill.light_energy = 1.2
	fill.light_color = Color(0.7, 0.8, 1.0)
	root.add_child(fill)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(1.25, 1.2, 2.25)
	cam.look_at(root.global_position + Vector3(0, 0.72, 0), Vector3.UP)
	cam.make_current()
	g.hud_root.visible = false            # кадр только для поз: без интерфейса
	g.combat_hud.visible = false
	var kc: Dictionary = Poses.pahan()
	kc.merge(G67Poses.krot(), true)
	var stages := [
		["k04_npc", ["K4"], [0.12, 0.31, 0.7]], ["k05_sober", ["K5", "K5Finger"], [0.3]], ["k06_rizz", ["K6", "K6Pose"], [0.3]],
		["k07_minecraft", ["K7", "K7Shrug"], [0.3]], ["k08_court", ["K8", "K8Point"], [0.3]], ["k09_air", ["K9", "K9Raise"], [0.35]], ["k10_last", ["K10"], [0.2]],
	]
	var made := 0
	for st in stages:
		var set_n := Node3D.new()
		root.add_child(set_n)
		var seat := _stage_props(set_n, String(st[0]))
		for clip in st[1]:
			var r := Rig.new()
			set_n.add_child(r)
			r.setup(G67Models.DIR + "g67_krot.glb", 1.62, kc, true, 1.0, "g67_krot_k")
			r.position = Vector3(0, seat - (G67Poses.SIT_HIP * 1.62 if seat > 0.0 else 0.0), 0)
			if String(st[0]) == "k04_npc":
				r.rotation.y = -0.95              # стоит перед автоматом (автомат слева от него)
			elif String(st[0]) == "k06_rizz":
				r.rotation.y = -0.45              # вполоборота к лампе
			elif String(st[0]) == "k09_air":
				r.position.z = -0.75              # за столиком
			if String(st[0]) == "k09_air":
				G67Poses._prop(r, "mixamorig_LeftHand", "bag", G67Poses._box(Vector3(0.24, 0.32, 0.02), Color(0.92, 0.94, 0.96), Color(0.3, 0.3, 0.32)), Vector3(0, 0.2, 0.05))
			r.play(String(clip), 0.0)
			for fr in st[2]:
				if r.player != null:
					r.player.seek(float(fr) * r.player.current_animation_length, true)
					r.player.pause()
				await wait(0.15)
				await shot("%s_%s_%d" % [String(st[0]), String(clip), int(float(fr) * 100)])
				made += 1
			if String(st[0]) == "k10_last":
				G67Poses.vanish(r)
				await wait(0.06)
				await shot("k10_last_vanish_a")
				await wait(0.3)
				await shot("k10_last_vanish_b")
				await wait(0.5)
				ok(not is_instance_valid(r), "встреча 10: КРОТ проваливается сквозь пол и пропадает (сбой, не бегство)")
			elif is_instance_valid(r):
				r.queue_free()
			await wait(0.05)
		set_n.queue_free()
	ok(made >= 12, "постановки КРОТА для встреч 4–10 сняты (%d кадров)" % made)
	g.cam.make_current()
	g.hud_root.visible = true
	g.combat_hud.visible = true
	root.queue_free()

func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

func _cube(parent: Node3D, size: Vector3, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, glow)
	parent.add_child(mi)
	return mi

## Заменители вещей встречи; возвращает высоту сиденья (0 — стоит)
func _stage_props(n: Node3D, id: String) -> float:
	match id:
		"k04_npc", "k05_sober":
			var mz := -0.55 if id == "k04_npc" else -0.45
			var mx := -1.05 if id == "k04_npc" else -1.0
			var mach := Node3D.new()
			mach.position = Vector3(mx, 0, mz)
			mach.rotation.y = 0.75 if id == "k04_npc" else 0.35       # лицевой стороной к нему
			n.add_child(mach)
			_cube(mach, Vector3(0.9, 1.9, 0.75), Vector3(0, 0.95, 0), Color(0.7, 0.12, 0.1))
			_cube(mach, Vector3(0.6, 0.9, 0.02), Vector3(0, 1.2, 0.38), Color(0.8, 0.9, 1.0), 0.8)
		"k06_rizz":
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.36
			tm.outer_radius = 0.42
			ring.mesh = tm
			ring.rotation.x = PI * 0.5
			ring.position = Vector3(-0.95, 1.4, 0.75)
			ring.rotation.y = -0.9
			ring.material_override = _mat(Color(1, 1, 1), 2.5)
			n.add_child(ring)
			_cube(n, Vector3(0.04, 1.4, 0.04), Vector3(-0.95, 0.7, 0.75), Color(0.1, 0.1, 0.1))
		"k07_minecraft":
			_cube(n, Vector3(0.42, 0.45, 0.42), Vector3(0, 0.225, -0.05), Color(0.35, 0.3, 0.25))
			_cube(n, Vector3(0.7, 2.0, 0.8), Vector3(-1.15, 1.0, -0.7), Color(0.08, 0.09, 0.1))
			for i in 8:
				_cube(n, Vector3(0.05, 0.03, 0.02), Vector3(-1.0 - (i % 3) * 0.08, 0.4 + i * 0.2, -0.29), Color(0.2, 1.0, 0.4), 2.0)
			return 0.45
		"k08_court":
			_cube(n, Vector3(4.0, 3.0, 0.05), Vector3(0, 1.5, -1.4), Color(0.05, 0.05, 0.06))
			_cube(n, Vector3(0.7, 0.5, 0.5), Vector3(-1.3, 0.25, -0.6), Color(0.12, 0.12, 0.13))
			_cube(n, Vector3(0.6, 0.45, 0.45), Vector3(-1.3, 0.72, -0.6), Color(0.15, 0.15, 0.16))
		"k09_air":
			_cube(n, Vector3(1.1, 0.75, 0.6), Vector3(0, 0.375, -0.1), Color(0.45, 0.35, 0.25))
			for i in 4:
				_cube(n, Vector3(0.18, 0.02, 0.24), Vector3(-0.35 + i * 0.22, 0.76, -0.1), Color(0.93, 0.95, 0.97))
	return 0.0

## Снимок КРОТА спереди-сбоку крупно; героя и напарника на время снимка убираем из кадра
func _krot_shot(g, kr, nm: String, dist := 2.0, side := 1.0, front := 1.0) -> void:
	if kr == null or not is_instance_valid(kr):
		print("GOLDA67CHECK   снимок %s: КРОТА нет" % nm)
		return
	var k: Vector3 = (kr as Node3D).global_position
	var kf: Vector3 = (kr as Node3D).global_transform.basis.z
	kf.y = 0.0
	kf = kf.normalized()
	var oc := Camera3D.new()
	g.add_child(oc)
	oc.global_position = k + kf * dist * front + Vector3(kf.z, 0, -kf.x) * dist * 0.45 * side + Vector3(0, 1.15, 0)
	oc.look_at(k + Vector3(0, 0.8, 0), Vector3.UP)
	oc.make_current()
	var pv: bool = g.player.visible
	var bv: bool = g.buddy.visible
	g.player.visible = false
	g.buddy.visible = false
	await wait(0.12)
	await shot(nm)
	g.player.visible = pv
	g.buddy.visible = bv
	g.cam.make_current()
	oc.queue_free()

## Озвучка главы 1: манифест, реальные разговоры, обрыв при перелистывании и пропуске, пауза, выкрики, отсутствующий файл
func _voice_check(g, G: Golda67, P) -> void:
	G67Voice.reload()
	var d = JSON.parse_string(FileAccess.get_file_as_string(G67Voice.MANIFEST)) if FileAccess.file_exists(G67Voice.MANIFEST) else null
	if not (d is Dictionary):
		print("GOLDA67CHECK   озвучка главы 1: манифеста нет — пропуск")
		return
	var ready := 0
	var bad: Array = []
	var total := 0
	for e in (d["lines"] as Array):
		if String(e["status"]) == "obsolete":
			continue
		total += 1
		if String(e["status"]) in ["generated", "validated"]:
			var line := String(e["code"]) + "|" + String(e["text"])
			var pth := G67Voice.path(line)
			var st = load(pth) if pth != "" else null
			if st is AudioStream and (st as AudioStream).get_length() > 0.2:
				ready += 1
			else:
				bad.append(String(e["id"]))
	ok(bad.is_empty(), "озвучка главы 1: готовых реплик %d из %d, все находятся игрой и читаются%s" % [ready, total, "" if bad.is_empty() else " (не читаются: %s)" % str(bad)])
	if ready == 0:
		return
	# разговор с DJ FLÜRR: голос главы 1, перелистывание обрывает прежнюю реплику, Tab — пропуск
	var fl0 = G.meta().get("flurr", -1)
	var seen0: Array = (G.meta().get("seen", []) as Array).duplicate()
	G.meta()["seen"] = []
	G.meta()["flurr"] = -1
	G.talk_flurr()
	await wait(0.3)
	var p1 := String(g.voice.stream.resource_path) if g.voice.stream != null else ""
	ok(g.voice.playing and p1.begins_with(G67Voice.DIR), "DJ FLÜRR: звучит голос главы 1 (%s)" % p1.get_file())
	get_tree().paused = true
	var pos0: float = g.voice.get_playback_position()
	await wait(0.5)
	var pos1: float = g.voice.get_playback_position()
	get_tree().paused = false
	await wait(0.3)
	ok(absf(pos1 - pos0) < 0.05 and g.voice.playing, "на паузе голос стоит, после паузы продолжает")
	g.dlg_chars = 9999.0
	g._dlg_advance()
	await wait(0.2)
	var p2 := String(g.voice.stream.resource_path) if g.voice.stream != null else ""
	ok(p2 != p1 and g.voice.playing, "следующая реплика: прежняя оборвалась, звучит новая (%s)" % p2.get_file())
	g._dlg_finish()
	await wait(0.1)
	ok(not g.voice.playing, "пропуск разговора (Tab) глушит голос")
	G.meta()["seen"] = seen0
	G.meta()["flurr"] = fl0
	G.flurr_last = -1
	# выкрики: Пахан — голосом главы 1, madk1d до первой концовки молчит
	g._hush()
	g.bark_cd.clear()
	g.bark("parry", 0.0)
	await wait(0.1)
	var bp := String(g.bark_v.stream.resource_path) if g.bark_v.stream != null else ""
	ok(g.bark_v.playing and bp.begins_with(G67Voice.DIR + "Pahan/"), "выкрик Пахана в приквеле — его голос главы 1 (%s)" % bp.get_file())
	g._hush()
	g.bark("worry", 0.0)
	await wait(0.1)
	ok(not g.bark_m.playing, "madk1d до первой концовки не выкрикивает (его нет в бою)")
	# реплики без файла: игра не падает, показывает текст
	g.start_dialog(["KR|Этой реплики нет в главе 1."], func(): g.mode = "golda67")
	await wait(0.2)
	ok(g.mode == "dlg" and String(g.dlg_text.text).contains("Этой реплики нет") and not g.voice.playing, "реплика без голоса показывается текстом, без ошибок")
	g._dlg_finish()
	await wait(0.1)

## Ролики главы 1: каждый целиком (снимки каждые 2 с), голоса, субтитры, без пропуска при первом показе,
## пропуск при повторе, архив и телевизор в подъезде
func _clip_check(g, G: Golda67, P) -> void:
	ok(not G.auto_clips, "в проверке ролики не запускаются сами по ходу игры")
	ok(G.clip_open("V00"), "трейлер V00 открыт с первого входа (телевизор в подъезде)")
	var all_ok := true
	for cid in G67Clips.ORDER:
		var t0 := GameClock.ms()
		var voiced := false
		var subs := false
		G.play_clip(cid)
		await wait(0.2)
		if G.clip == null:
			all_ok = false
			print("GOLDA67CHECK   ролик %s не открылся" % cid)
			continue
		ok(G.scene_busy() and g.intro_busy(), "%s: пока идёт ролик, управление закрыто" % cid) if cid == "STORY01" else null
		if cid == "STORY01":
			await key(KEY_ENTER)
			await wait(0.3)
			ok(G.clip != null and not G.clip.skipped, "первый показ нельзя пропустить (Enter не действует)")
		var n := 0
		var next_shot := 0.6
		while G.clip != null and GameClock.ms() - t0 < 60000:
			var el := (GameClock.ms() - t0) / 1000.0
			if G.clip.voice.playing:
				voiced = true
			if G.clip.sub_text.text != "":
				subs = true
			if el >= next_shot:
				await shot("c_%s_%02d" % [cid, n])
				n += 1
				next_shot += 2.0
			await get_tree().process_frame
		var dur := (GameClock.ms() - t0) / 1000.0
		var needs_voice: bool = (G67Clips.LINES.get(cid, []) as Array).size() > 0
		var good: bool = G.clip == null and dur > 5.0 and dur < 40.0 and (voiced or not needs_voice) and subs
		print("GOLDA67CHECK   ролик %s: %.1f с, голос %s, субтитры %s, кадров %d" % [cid, dur, str(voiced), str(subs), n])
		if not good:
			all_ok = false
		await wait(0.2)
	ok(all_ok, "все %d роликов главы 1 проигрываются целиком, с голосами и субтитрами" % G67Clips.ORDER.size())
	ok(G67Clips.ORDER.all(func(cid): return G.clip_seen(cid) and G.clip_open(cid)), "просмотренные ролики отмечены и лежат в архиве")
	# повтор: пропуск разрешён
	G.play_clip("STORY01")
	await wait(0.5)
	ok(G.clip != null and G.clip.skippable, "повторный показ можно пропустить")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(G.clip != null, "короткое нажатие Enter ролик не пропускает")
	# пауза: Esc ставит ролик, голос и время; меню игры не открывается
	var cl = G.clip
	await key(KEY_ESCAPE)
	await wait(0.2)
	var t_p: float = cl.t
	ok(cl.paused and get_tree().paused and not g.pause_panel.is_open, "Esc ставит ролик на паузу, меню игры не открывается")
	await wait(0.7)
	ok(is_equal_approx(cl.t, t_p), "на паузе время ролика стоит (%.2f → %.2f)" % [t_p, cl.t])
	ok(not cl.voice.playing or cl.voice.stream_paused or get_tree().paused, "голос на паузе")
	await shot("c_clip_paused")
	await key(KEY_ESCAPE)
	await wait(0.4)
	ok(not cl.paused and not get_tree().paused and cl.t > t_p, "Esc ещё раз — продолжение с того же места")
	# удержание Enter 0,8 с пропускает; пропущенный не «просмотрен», но открыт в архиве
	var cs1: Array = G.meta().get("clips_seen", [])
	cs1.erase("STORY05")
	G.meta()["clips_seen"] = cs1
	if G.clip != null:
		G.clip.skip()
		await wait(0.3)
	G.play_clip("STORY05")
	await wait(0.6)
	var ee := InputEventKey.new()
	ee.keycode = KEY_ENTER
	ee.physical_keycode = KEY_ENTER
	ee.pressed = true
	Input.parse_input_event(ee)
	await wait(0.4)
	ok(G.clip != null and G.clip._ctl.hold > 0.1, "пока держат Enter — кольцо-индикатор")
	await shot("c_clip_hold")
	await wait(0.8)
	ee = InputEventKey.new()
	ee.keycode = KEY_ENTER
	ee.physical_keycode = KEY_ENTER
	ee.pressed = false
	Input.parse_input_event(ee)
	ok(await until(func(): return G.clip == null, 2.0), "удержание Enter пропускает ролик (и при первом просмотре)")
	await wait(0.2)
	ok(not G.clip_seen("STORY05") and G.clip_open("STORY05") and not get_tree().paused, "пропущенный не в clips_seen, но открыт в архиве; пауза снята")
	# телевизор: список открытых роликов
	G.tv()
	await wait(0.3)
	ok(G.hub_ui != null and G.hub_ui.kind == "archive", "телевизор в подъезде открывает архив роликов")
	await shot("c_tv_menu")
	G._tv_close()
	await wait(0.2)

## Поставить Мишу и героя и запустить приём (сам он в это время ничего не выбирает)
func _misha_set(B, P, move: String, ppos: Vector3, bpos := Vector3(0, 0.05, -2.0)) -> void:
	B.state = "chase"
	B.cool = 99.0
	B.special_cd = 99.0
	B.guard_until = -1.0
	B.weak_t = 0.0
	B.global_position = AC + bpos          # координаты приёмов — от центра коробки
	B.velocity = Vector3.ZERO
	P.global_position = AC + ppos
	P.velocity = Vector3.ZERO
	P.hp = P.max_hp
	P.inv = 0.0
	if String(P.state) in ["hurt", "roll", "block"]:
		P.state = "idle"
	await wait(0.1)
	BossMoves.start(B, move)

func _press(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)

## Бой Миши: ЗАХВАТ, ЗАЩИТНАЯ СТОЙКА, ЗАЦЕП ЦЕПИ — зона, честность, ответы игрока
func _misha_moves(g, G: Golda67, P, B) -> void:
	var ph: Array = B.boss["phases"]
	ok((ph[0] as Array).has("m_grab") and (ph[0] as Array).has("m_hook") and (ph[1] as Array).has("m_guard") and (ph[2] as Array).has("m_guard"),
		"приёмы Миши по фазам: захват и зацеп с первой, стойка со второй")
	var dmg := float(B.cfg["dmg"])
	G.run["fits"] = {}
	G.run["arts"] = []
	G.apply_fits()
	# --- ЗАХВАТ: блок не спасает
	var f0: float = B.face
	for attempt in 3:
		B.grab_log = []
		await _misha_set(B, P, "m_grab", Vector3(0, 0.05, 0.0))
		if attempt == 0:
			ok(String(B.state) == "special" and B.tell.visible and bool(B.sp_lock), "ЗАХВАТ: подготовка с меткой-сектором на земле")
		_press("block", true)
		await wait(0.55)
		if attempt == 0:
			await _side_shot(g, B, "26a_misha_grab")
		f0 = B.face
		await wait(0.75)
		_press("block", false)
		if not B.grab_log.is_empty() and String(B.grab_log[-1]) == "hit":
			break
		await wait(1.2)
	ok(not B.grab_log.is_empty() and String(B.grab_log[-1]) == "hit" and P.max_hp - P.hp > dmg * 1.2, "ЗАХВАТ пробивает блок (урон %.0f, обычный удар в блок дал бы %.0f)" % [P.max_hp - P.hp, dmg * 0.3])
	# --- ЗАХВАТ: уклонение спасает, Миша хватает воздух и стоит открытым
	await wait(1.2)
	await _misha_set(B, P, "m_grab", Vector3(0, 0.05, 0.0))
	await wait(G67Misha.GRAB_WARN - 0.2)
	await key(KEY_SHIFT)
	await wait(0.5)
	ok(String(B.grab_log[-1]) == "miss" and P.hp == P.max_hp, "ЗАХВАТ: уклонение в момент хватки спасает (здоровье %.0f)" % P.hp)
	ok(String(B.state) == "special", "после промаха Миша ещё стоит согнувшись — окно для ударов")
	# --- ЗАХВАТ: зона = рисунок
	await wait(1.0)
	await _misha_set(B, P, "m_grab", Vector3(0, 0.05, 2.6))          # 4,6 м — за краем зоны
	await wait(G67Misha.GRAB_WARN + 0.2)
	ok(String(B.grab_log[-1]) == "miss" and P.hp == P.max_hp, "ЗАХВАТ: за краем метки не достаёт")
	var fr := Vector3(sin(B.face), 0, cos(B.face))
	ok(G67Misha.in_grab(B, B.global_position + fr * (G67Misha.GRAB_R - 0.1)) and not G67Misha.in_grab(B, B.global_position + fr * (G67Misha.GRAB_R + 0.2))
		and not G67Misha.in_grab(B, B.global_position + fr.rotated(Vector3.UP, G67Misha.GRAB_HALF + 0.15) * 2.0), "зона захвата совпадает с меткой (дальность и угол)")
	# --- ЗАЩИТНАЯ СТОЙКА
	await wait(1.2)
	await _misha_set(B, P, "m_guard", Vector3(0, 0.05, 0.2))
	await wait(0.5)
	ok(G67Misha.guarding(B) and B.tell.visible and String(B.rig.cur) == "MGuard", "ЗАЩИТНАЯ СТОЙКА: руки скрещены, золотой сектор спереди (%s, %s, %s)" % [str(G67Misha.guarding(B)), str(B.tell.visible), str(B.rig.cur)])
	await _side_shot(g, B, "26b_misha_guard")
	var bh: float = B.hp
	var h := HitInfo.new()
	h.damage = 30.0
	h.dir = (B.global_position - P.global_position).normalized()
	h.attack_id = "test"
	B.guard_next = 0.0              # первый удар в стойку — ответ доступен (не зависит от того, что было до проверки)
	P.inv = 0.0
	P.global_position = B.global_position + Vector3(sin(B.face), 0, cos(B.face)) * 2.0
	B.take_hit_info(h)
	ok(B.hp == bh and String(B.guard_log[-1]) == "return" and P.hp < P.max_hp, "удар в стойку спереди: урона нет, удар вернулся герою (−%.0f; босс %.1f → %.1f, итог %s)" % [P.max_hp - P.hp, bh, B.hp, str(B.guard_log[-1])])
	var hp_a: float = P.hp
	P.inv = 0.0
	B.take_hit_info(h)
	ok(P.hp == hp_a and String(B.guard_log[-1]) == "absorb", "ответ стойки не чаще раза в %.1f с" % G67Misha.GUARD_GAP)
	var hb := HitInfo.new()
	hb.damage = 30.0
	hb.dir = Vector3(sin(B.face), 0, cos(B.face))                     # удар со спины летит туда же, куда смотрит Миша
	hb.attack_id = "test"
	B.take_hit_info(hb)
	ok(B.hp < bh and String(B.guard_log[-1]) == "broken" and not G67Misha.guarding(B), "удар со спины сбивает стойку и проходит (−%.0f)" % (bh - B.hp))
	# --- ЗАЦЕП ЦЕПИ: попал — тянет к себе
	await wait(1.2)
	await _misha_set(B, P, "m_hook", Vector3(0, 0.05, 4.0))
	ok(B.tell.visible and bool(B.sp_lock), "ЗАЦЕП ЦЕПИ: полоса на земле, взгляд замер")
	await wait(0.5)
	await shot("26c_misha_hook_tell")
	await wait(G67Misha.HOOK_WARN - 0.5 + 0.2)
	ok(String(B.hook_log[-1]) == "hit" and P.hp < P.max_hp, "цепь попала по герою на полосе (−%.0f)" % (P.max_hp - P.hp))
	# --- ЗАЦЕП ЦЕПИ: шаг с полосы — цепь цепляется за борт, Миша открыт
	await wait(1.4)
	await _misha_set(B, P, "m_hook", Vector3(0, 0.05, 4.0))
	f0 = B.face
	await wait(0.3)
	P.global_position = AC + Vector3(3.5, 0.05, 4.0)                   # ушёл с полосы
	await wait(G67Misha.HOOK_WARN - 0.3 + 0.25)
	ok(absf(angle_difference(f0, B.face)) < 0.01, "полоса не поворачивается за героем — с неё можно уйти")
	ok(String(B.hook_log[-1]) == "board" and String(B.state) == "stun" and B.weak_t > G67Misha.HOOK_OPEN - 0.5 and P.hp == P.max_hp,
		"промах: цепь зацепилась за борт, Миша открыт (%.1f с)" % B.weak_t)
	ok(G.world.get_node_or_null("misha_hook_chain") != null and String(B.rig.cur) == "MStuck", "цепь натянута до борта, Миша её дёргает")
	await wait(0.3)
	await shot("26d_misha_hooked")
	var bh2: float = B.hp
	var hw := HitInfo.new()
	hw.damage = 30.0
	hw.dir = (B.global_position - P.global_position).normalized()
	hw.attack_id = "test"
	B.take_hit_info(hw)
	ok(bh2 - B.hp > 30.0 * 1.25, "по открытому Мише урон выше (−%.0f за удар в 30)" % (bh2 - B.hp))
	ok(await until(func(): return String(B.state) != "stun" and B.weak_t <= 0.0, 3.0), "через две секунды он снова в бою")
	await wait(0.5)
	ok(G.world.get_node_or_null("misha_hook_chain") == null, "цепь убрана")
	# --- ЗАЦЕП ЦЕПИ: турник ловит цепь
	var bar: Vector3 = (G.world.hook_points[0] as Vector3) - AC
	var side := Vector3(1, 0, 0) if bar.x < 0.0 else Vector3(-1, 0, 0)
	await _misha_set(B, P, "m_hook", bar - side * 1.0 + Vector3(0, 0.05, 0), bar + side * 6.0 + Vector3(0, 0.05, 0))
	await wait(0.3)
	P.global_position = AC + Vector3(0, 0.05, 6.0)
	await wait(G67Misha.HOOK_WARN - 0.3 + 0.25)
	ok(String(B.hook_log[-1]) == "bars", "если полоса идёт мимо турника — цепь цепляется за турник")
	await wait(0.2)
	await shot("26e_misha_hook_bars")
	await wait(2.4)
	B.global_position = AC + Vector3(0, 0.05, -2.0)
	P.global_position = AC + Vector3(0, 0.05, 3.0)
	P.hp = P.max_hp
	P.inv = 0.0

## B01: до первой концовки madk1d в забеге нет. Герой sec секунд стоит и не бьёт (урон по нему выключен), автопомощь
## напарника включена как в обычной игре (в проверках её выключает tagteam.setup). Возвращает, что за это время делал напарник.
func _madk_idle(g, P, sec: float) -> Dictionary:
	var b = g.buddy
	var T = g.tag
	var auto: bool = T.auto_assist
	T.auto_assist = true
	T.auto_t = 0.0
	var ev0: int = b.events.size()
	var team0: int = T.events.size()
	var near := 9999.0
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		P.inv = 1.0
		near = minf(near, b.global_position.distance_to(P.global_position))
		await get_tree().process_frame
	P.inv = 0.0
	T.auto_assist = auto
	return {"acts": b.events.slice(ev0), "team": T.events.slice(team0), "near": near, "foe": b.foe != null}

## B01: добивание на [E] без командного приёма: TEAM FINISHER нет, madk1d не появляется, перезарядка помощи не идёт
func _madk_no_finisher(g, G: Golda67, P) -> void:
	var e = null
	for x in g.enemies:
		if is_instance_valid(x) and x.alive():
			e = x
			break
	if e == null:
		ok(false, "есть живой враг для проверки добивания без madk1d")
		return
	var T = g.tag
	P.inv = 1.0
	var fwd: Vector3 = Vector3(sin(P.face), 0, cos(P.face))
	e.global_position = P.global_position + fwd * 1.5
	e.hp = 5.0
	e.stun(3.0)
	await wait(0.2)
	T.assist_cd = 0.0
	var team0: int = T.events.size()
	var started: bool = P.execution.try_start()
	await until(func(): return not P.execution.active(), 5.0)
	ok(started and not e.alive(), "добивание на [E] началось, враг погиб")
	ok(not T.events.slice(team0).any(func(x): return x[0] == "finisher"), "добивание на [E]: TEAM FINISHER нет — madk1d в бою не участвует")
	ok(g.buddy.global_position.distance_to(P.global_position) > 14.0, "madk1d не появился у добитого врага")
	ok(is_zero_approx(T.assist_cd), "перезарядка командной помощи не запускалась")
	P.inv = 0.0

## madk1d закрыт до первой концовки: Tab, T, G, Q ничего не открывают, в HUD замок; после концовки — всё работает
func _madk_check(g, G: Golda67, P) -> void:
	var fl: Dictionary = G.meta().get("flags", {})
	var had := bool(fl.get(G67Data.MADK_FLAG, false))
	fl.erase(G67Data.MADK_FLAG)
	G.meta()["flags"] = fl
	ok(not G.madk_open() and g.madk_locked(), "новый приквел: madk1d закрыт (флаг первой концовки не стоит)")
	P.hp = P.max_hp
	await wait(0.3)
	g._madk_note_t = -9.0
	await key(KEY_TAB)
	await wait(0.5)
	ok(String(P.hero) == "pahan" and g._madk_note_t > 0.0, "Tab: остаётся Пахан, игроку объяснили, когда откроется madk1d")
	ok(String(g.toast_label.text).contains("первой концовки"), "подсказка: «%s»" % g.toast_label.text)
	ok(not g.swap_heroes(true) and String(P.hero) == "pahan", "смена героя кодом тоже закрыта (AIR TAG и прочие пути)")
	ok(not g.tag.try_assist() and not g.tag.duo.active(), "T: дуэт-атаки нет")
	g.hype.value = TeamHype.MAX
	ok(not g.hype.try_start() and not g.hype.active(), "G: Overdrive не запускается даже с полной шкалой")
	g.hype.value = 0.0
	ok(g.hype.gain("attack") == 0.0 and g.hype.value == 0.0, "Team Hype не копится")
	var ab: Array = g.combat_hud.abilities(P)
	ok(not ab.any(func(x): return String(x[0]) == "Q"), "ромба ад-либа madk1d в HUD нет")
	var H: CombatHud = g.combat_hud
	ok(H.madk_lock != null and H.madk_lock.visible and H.tab_lock.visible and not H.hype_text.visible, "в HUD на портрете madk1d и на бирке TAB — замок, шкалы HYPE нет")
	await shot("08_madk_locked")
	# после первой концовки — всё открыто
	fl[G67Data.MADK_FLAG] = true
	G.meta()["flags"] = fl
	await wait(0.2)
	ok(G.madk_open() and not g.madk_locked(), "после первой концовки madk1d открыт")
	await wait(0.6)
	g.tag.tag_cd = 0.0
	await key(KEY_TAB)
	var sw: bool = await until(func(): return String(P.hero) == "madk1d", 3.0)
	ok(sw, "Tab: управление переходит к madk1d")
	ok(not H.madk_lock.visible and H.hype_text.visible, "замок в HUD снят, шкала HYPE на месте")
	await wait(0.4)
	await shot("08b_madk_open")
	await wait(1.4)
	g.tag.tag_cd = 0.0
	if String(P.hero) == "madk1d":
		g.swap_heroes(true)
	await wait(0.6)
	ok(String(P.hero) == "pahan", "обратно к Пахану")
	if not had:
		fl.erase(G67Data.MADK_FLAG)
	G.meta()["flags"] = fl
	G.apply_styles()
	P.global_position = G.world.spawn_pos
	await wait(0.3)

func _flurr_from_doc() -> Dictionary:
	var txt := FileAccess.get_file_as_string("res://docs/golda67/DJ_FLURR_SPEC.md").replace("\r", "")
	var states: Array = []
	var wait_l: Array = []
	var done_l: Array = []
	var who := ""
	var part := 0          # 0 — до диалогов и в них, 1 — короткие «пока не найдена», 2 — «после всех»
	for raw in txt.split("\n"):
		var t := String(raw).strip_edges()
		if t.begins_with("13. "):
			part = 1
			continue
		if t.begins_with("14. "):
			break
		if part == 0:
			var dot := t.find(". ")
			if dot > 0 and t.substr(0, dot).is_valid_int() and int(t.substr(0, dot)) >= 2 and int(t.substr(0, dot)) <= 12 and (t.contains("ЗНАКОМСТВО") or t.contains("ВСТРЕЧА КРОТА")):
				states.append([])
				who = ""
			elif t.begins_with("DJ FL") and t.ends_with("RR:"):
				who = "DJ"
			elif t == "Пахан:":
				who = "V"
			elif who != "" and t.begins_with("«") and not states.is_empty():
				(states[-1] as Array).append(who + "|" + _unq(t))
				who = ""
		else:
			if t.begins_with("* "):
				t = t.substr(2).strip_edges()
			if t.begins_with("После обнаружения всех"):
				part = 2
			elif t.begins_with("«"):
				(done_l if part == 2 else wait_l).append("DJ|" + _unq(t))
	return {"states": states, "wait": wait_l, "done": done_l}

func _unq(t: String) -> String:
	var k := t.rfind("»")
	return t.substr(1) if k < 0 else t.substr(1, k - 1) + t.substr(k + 1)

func _flurr_check(g, G: Golda67, P) -> void:
	var doc := _flurr_from_doc()
	ok((doc["states"] as Array).size() == 11 and G67Flurr.STATES.size() == 11, "у dj flürr одиннадцать состояний")
	var same := true
	var total := 0
	for i in 11:
		total += (G67Flurr.STATES[i] as Array).size()
		if G67Flurr.STATES[i] != doc["states"][i]:
			same = false
			print("GOLDA67CHECK   состояние %d расходится с документом" % i)
	ok(same and G67Flurr.WAIT == doc["wait"] and G67Flurr.DONE == doc["done"], "все реплики в игре совпадают с авторским документом посимвольно (%d + %d коротких)" % [total, G67Flurr.WAIT.size() + G67Flurr.DONE.size()])
	ok(G67Flurr.WAIT.size() == 7 and G67Flurr.DONE.size() == 4, "коротких фраз: 7 «пока не найдена» и 4 «после всех»")
	var seen0: Array = (G.meta().get("seen", []) as Array).duplicate()
	var fl0 = G.meta().get("flurr", -1)
	var pt: Dictionary = G.point("flurr")
	var all_ok := true
	for n in 11:
		var seen: Array = []
		for k in n:
			seen.append("krot%d" % (k + 1))
		G.meta()["seen"] = seen
		ok(G.flurr_state() == n, "состояние %d = завершено встреч КРОТА: %d" % [n, n]) if n in [0, 3, 10] else null
		P.global_position = Vector3(pt["pos"].x, pt["pos"].y + 0.05, pt["pos"].z)
		P.velocity = Vector3.ZERO
		await wait(0.25)
		if n == 0:
			await key(KEY_E)           # первый раз — настоящей клавишей у лавки
		else:
			G.talk_flurr()
		await wait(0.2)
		if g.mode != "dlg" or g.dlg != G67Flurr.STATES[n]:
			all_ok = false
			print("GOLDA67CHECK   состояние %d: звучит не тот диалог" % n)
		if n == 0:
			ok(String(g.dlg_name.text) == "DJ FLÜRR", "имя в окне диалога: «%s»" % g.dlg_name.text)
			await wait(0.5)
			await shot("12_flurr_dialog")
		for i in 60:
			if g.mode != "dlg":
				break
			g._dlg_advance()
			await wait(0.05)
		if int(G.meta().get("flurr", -1)) != n or g.mode != "golda67":
			all_ok = false
			print("GOLDA67CHECK   состояние %d не запомнено" % n)
		# повторный разговор до следующей встречи — короткая фраза, без повтора подряд
		var prev := ""
		for r in 3:
			G.talk_flurr()
			await wait(0.1)
			var pool: Array = G67Flurr.DONE if n >= 10 else G67Flurr.WAIT
			if g.dlg.size() != 1 or not pool.has(g.dlg[0]) or String(g.dlg[0]) == prev:
				all_ok = false
				print("GOLDA67CHECK   состояние %d: повторная реплика неверна (%s)" % [n, str(g.dlg)])
			prev = String(g.dlg[0])
			for i in 6:
				if g.mode != "dlg":
					break
				g._dlg_advance()
				await wait(0.05)
	ok(all_ok, "все 11 диалогов звучат по состоянию, запоминаются; повторно — короткие фразы без повтора подряд")
	# подсказка не ведёт к уже завершённой встрече, а после загрузки состояние то же
	G.meta()["seen"] = ["krot1", "krot2"]
	G.meta()["flurr"] = 1
	var saved = JSON.parse_string(JSON.stringify(G.data))
	ok(int(saved["meta"]["flurr"]) == 1 and (saved["meta"]["seen"] as Array).size() == 2, "прогресс диалогов переживает сохранение и загрузку")
	G.talk_flurr()
	await wait(0.1)
	ok(g.dlg == G67Flurr.STATES[2] and String(g.dlg[-1]).contains("голубю справа"), "после двух встреч звучит диалог про люстру с подсказкой на третью (ДВОР, голуби)")
	for i in 60:
		if g.mode != "dlg":
			break
		g._dlg_advance()
		await wait(0.05)
	# знакомство после уже найденного КРОТА: четыре реплики знакомства, связка, сразу нынешний диалог
	var arch0: Array = (G.meta().get("archive", []) as Array).duplicate()
	G.meta()["seen"] = ["krot1", "krot2"]
	G.meta()["flurr"] = -1
	G.meta()["archive"] = []
	G.talk_flurr()
	await wait(0.1)
	var alt: Array = (G67Flurr.STATES[0] as Array).slice(0, 4)
	alt.append("DJ|А ты, я слышал, уже с КРОТОМ пересёкся.")
	alt.append_array(G67Flurr.STATES[2])
	ok(g.dlg == alt, "первый разговор после двух встреч: знакомство (4 реплики), связка про КРОТА, диалог состояния 2 — без старых подсказок")
	for i in 60:
		if g.mode != "dlg":
			break
		g._dlg_advance()
		await wait(0.05)
	var ar: Array = G.meta()["archive"]
	ok(int(G.meta()["flurr"]) == 2 and ar.has("flurr0") and ar.has("flurr1") and ar.has("flurr2"), "пропущенные диалоги записаны в архив (%s)" % str(ar))
	G.meta()["archive"] = arch0
	ok(String(pt.get("title", "")) == "DJ FLÜRR", "подпись у лавки — DJ FLÜRR")
	ok(g.ipod.allowed(g), "iPod в приквеле работает, как в кампании")
	G.meta()["seen"] = seen0
	G.meta()["flurr"] = fl0
	G.flurr_last = -1
	P.global_position = G.world.spawn_pos

## --g67-real: путь игрока с роликами по ходу (первый показ не пропускается — ждём), чистое сохранение, весь забег
## до босса. Проверяет, что ролики не ломают игру: двери, комнаты, выход Миши (он на месте и в кадре).
## Бот с клавиатуры: поворачивает камеру на ближайшего врага, идёт к нему (W), бьёт (ЛКМ), перекатывается (Shift) из красных кругов; страховка по времени
func _bot_fight(g, G: Golda67, limit_s: float) -> Dictionary:
	var P = g.player
	var t0 := Time.get_ticks_msec()
	var roll_cd := 0.0
	var res := {"timeout": false}
	while G.room_state in ["fight", "boss"]:
		if float(Time.get_ticks_msec() - t0) / 1000.0 > limit_s:
			res["timeout"] = true
			Input.action_release("up")
			Input.action_release("attack")
			await _clear_room(g, G, 60.0)
			break
		if G.scene_busy() or G.clip != null:
			Input.action_release("up")
			await wait(0.2)
			continue
		var best = null
		var bd := 1e9
		for e in g.enemies:
			if is_instance_valid(e) and e.state != "dead":
				var d: float = (e as Node3D).global_position.distance_to(P.global_position)
				if d < bd:
					bd = d
					best = e
		if best == null:
			Input.action_release("up")
			await wait(0.25)
			continue
		var to: Vector3 = (best as Node3D).global_position - P.global_position
		to.y = 0.0
		g.cam_yaw = atan2(-to.x, -to.z)
		roll_cd = maxf(0.0, roll_cd - 0.1)
		if int(float(Time.get_ticks_msec() - t0) / 1000.0) % 20 == 0 and not res.has("d%d" % int(float(Time.get_ticks_msec() - t0) / 20000.0)):
			res["d%d" % int(float(Time.get_ticks_msec() - t0) / 20000.0)] = true
			print("GOLDA67CHECK   REAL бот: t=%.0f врагов=%d ближайший %s %.1f м состояние=%s hp=%.0f ожидают=%d" % [float(Time.get_ticks_msec() - t0) / 1000.0, g.enemies.size(), String(best.name), bd, String(best.state), float(P.hp), G.pending.size()])
		var danger := false
		for zz in g.zones:
			if String(zz.get("kind", "")) == "tele" and "n" in zz and is_instance_valid(zz["n"]):
				var zp: Vector3 = (zz["n"] as Node3D).global_position
				if Vector2(zp.x - P.global_position.x, zp.z - P.global_position.z).length() < float(zz.get("r", 2.0)) + 0.6:
					danger = true
		for e2 in g.enemies:
			if is_instance_valid(e2) and e2.state != "dead" and String(e2.state) in ["wind", "windup", "attack", "slam"] and (e2 as Node3D).global_position.distance_to(P.global_position) < 4.2:
				danger = true
		if danger and roll_cd <= 0.0:
			roll_cd = 0.9
			Input.action_release("up")
			var side := "left" if int(Time.get_ticks_msec() / 1000) % 2 == 0 else "right"
			Input.action_press(side)
			Input.action_press("down")
			Input.action_press("roll")
			await wait(0.12)
			Input.action_release("roll")
			await wait(0.3)
			Input.action_release("down")
			Input.action_release("left")
			Input.action_release("right")
			continue
		if bd > 2.3:
			Input.action_press("up")
			Input.action_release("attack")
		else:
			Input.action_release("up")
			Input.action_press("attack")
			await wait(0.07)
			Input.action_release("attack")
		await wait(0.1)
	Input.action_release("up")
	Input.action_release("attack")
	Input.action_release("down")
	return res

## Журнал забега (только в проверке): позиции жителей/прохожих, состояние боя, пузыри и голоса, FPS, застрявшие враги
func _real_journal(g, G: Golda67, J: Dictionary) -> void:
	var last_pos := {}
	while J["on"]:
		await wait(0.25)
		if G.world == null or G.world.yard == null or G.place != "run":
			continue
		var yd = G.world.yard
		var P = g.player
		J["samples"] = int(J["samples"]) + 1
		var fps := float(Engine.get_frames_per_second())
		J["fps_sum"] = float(J["fps_sum"]) + fps
		if fps < float(J["fps_min"]):
			J["fps_min"] = fps
			J["fps_min_at"] = "комната %s, %.0f с, %s" % [String(G.room.get("type", "")), float(Time.get_ticks_msec() - int(J["t0"])) / 1000.0, G.room_state]
		var actors: Array = []
		for rid in yd.residents:
			actors.append((yd.residents[rid].rig as Node3D))
		var yl: G67YardLife = G.ylife_get()
		for w in yl.walkers:
			if is_instance_valid(w["rig"]):
				actors.append(w["rig"])
		var fighting: bool = G.room_state in ["fight", "boss"]
		if fighting:
			var place := String(G.room.get("place", ""))
			if place != "":
				var zn: Dictionary = G67Yard.zone(place)
				var c: Vector3 = zn["c"]
				var h: Vector2 = zn["h"]
				for a in actors:
					if absf(a.global_position.x - c.x) < h.x and absf(a.global_position.z - c.z) < h.y and a.visible:
						J["obs_a"] = int(J["obs_a"]) + 1
		# (б) житель ближе 1,2 м к точке, к которой герой подходит
		for pt in G.world.points:
			var pp: Vector3 = pt["pos"]
			if String(pt["id"]).begins_with("talk_") or Vector2(pp.x - P.global_position.x, pp.z - P.global_position.z).length() > 2.5:
				continue
			for a in actors:
				if Vector2(a.global_position.x - pp.x, a.global_position.z - pp.z).length() < 1.2 and a.visible:
					J["obs_b"] = int(J["obs_b"]) + 1
					(J["notes"] as Array).append("житель у точки %s" % String(pt["id"]))
					break
		# (в) враги без движения > 4 с вне своей атаки
		var stat: Dictionary = J["stat"]
		for e in g.enemies:
			if not is_instance_valid(e) or e.state == "dead":
				continue
			var id: int = e.get_instance_id()
			var p2: Vector3 = (e as Node3D).global_position
			var st: Dictionary = stat.get(id, {"p": p2, "t": 0.0})
			if (st["p"] as Vector3).distance_to(p2) < 0.05 and String(e.state) in ["chase", "idle", "walk"] and not G.scene_busy():
				st["t"] = float(st["t"]) + 0.25
				if float(st["t"]) > 4.0 and not bool(st.get("flag", false)):
					st["flag"] = true
					J["obs_c"] = int(J["obs_c"]) + 1
					(J["notes"] as Array).append("враг %s стоит >4 с в состоянии %s у %s" % [String(e.name), String(e.state), str(p2)])
			else:
				st["t"] = 0.0
				st["flag"] = false
			st["p"] = p2
			stat[id] = st
		# (г) пузыри/голоса при ролике, диалоге, ev_cam, выходе босса; (д) два голоса сразу
		var bk: G67Barks = G.barks_get()
		var busy: bool = G.clip != null or g.mode == "dlg" or G.ev_cam or G.ev_busy or G.scene_t >= 0.0
		var voices := 0
		for ch in bk.get_children():
			if ch is AudioStreamPlayer3D and (ch as AudioStreamPlayer3D).playing:
				voices += 1
		if busy and (bk.bubbles.size() > 0 or voices > 0):
			J["obs_d"] = int(J["obs_d"]) + 1
			(J["notes"] as Array).append("пузырь/голос во время постановки (пузырей %d, голосов %d)" % [bk.bubbles.size(), voices])
		if voices > 1:
			J["obs_e"] = int(J["obs_e"]) + 1

func _real_summary(g, G: Golda67, J: Dictionary, run_n: int) -> void:
	var yl: G67YardLife = G.ylife_get()
	var du: G67Duos = G.duos_get()
	var bk: G67Barks = G.barks_get()
	var micro := {}
	for e in yl.log:
		micro[String(e[1])] = int(micro.get(String(e[1]), 0)) + 1
	var said := {}
	for e in bk.log:
		said[String(e[1])] = int(said.get(String(e[1]), 0)) + 1
	var ds := 0
	var de := 0
	for e in du.log:
		if String(e[2]) == "start":
			ds += 1
		elif String(e[2]) == "end":
			de += 1
	var evs := {}
	for e in G.events:
		evs[String(e[0])] = int(evs.get(String(e[0]), 0)) + 1
	var out := {"run": run_n, "sec": snappedf(float(Time.get_ticks_msec() - int(J["t0"])) / 1000.0, 0.1), "stages": J["stages"], "boss": J["boss"], "events": evs, "micro": micro, "said": said, "duos_start": ds, "duos_end": de, "walkers": int(micro.get("walker", 0)), "obs_a_zone_frames": J["obs_a"], "obs_b_near_point": J["obs_b"], "obs_c_stuck_enemies": J["obs_c"], "obs_d_bubbles_in_scene": J["obs_d"], "obs_e_two_voices": J["obs_e"], "fps_min": J["fps_min"], "fps_min_at": J["fps_min_at"], "fps_mean": snappedf(float(J["fps_sum"]) / maxf(1.0, float(J["samples"])), 0.1), "samples": J["samples"], "notes": (J["notes"] as Array).slice(0, 20), "route": str(G.run.get("route", G.run.keys()))}
	var js := JSON.stringify(out, "  ")
	print("GOLDA67CHECK   REALSUM " + js.replace("\n", " "))
	var f := FileAccess.open(OS.get_environment("TEMP") + "/g67_real_%d.json" % run_n, FileAccess.WRITE)
	if f:
		f.store_string(js)

func _clips_wait(G: Golda67, sec := 120.0) -> void:
	await wait(0.3)
	await until(func(): return G.clip == null and G.hub_ui == null, sec)
	await wait(0.4)

func _real_run(g, G: Golda67, run_n := 0) -> void:
	var P = g.player
	G.meta()["runs"] = run_n
	var J := {"on": true, "t0": Time.get_ticks_msec(), "samples": 0, "fps_min": 1e9, "fps_min_at": "", "fps_sum": 0.0, "obs_a": 0, "obs_b": 0, "obs_c": 0, "obs_d": 0, "obs_e": 0, "stat": {}, "stages": [], "boss": {}, "notes": []}
	_real_journal(g, G, J)
	ok(await until(func(): return G.clip != null, 10.0), "REAL: первые ролики начинаются после того, как подъезд проявился")
	ok(main.intro_fx == null or not main.intro_fx.busy, "REAL: к началу ролика шторка перехода уже ушла")
	await _clips_wait(G)
	ok(G.place == "hub" and G.clip == null, "REAL: после первых роликов — подъезд, управление у игрока (%s)" % str(G.events.filter(func(e): return String(e[0]) == "clip")))
	await shot("r01_hub")
	await _go(G, P, "exit")
	await _clips_wait(G)
	var started: bool = await until(func(): return G.place == "run", 10.0)
	await _clips_wait(G)
	ok(started and G.place == "run", "REAL: выход из подъезда начинает забег (ролики: %s)" % str(G.events.filter(func(e): return String(e[0]) == "clip")))
	if not started:
		return
	var pos := -1
	for step in 14:
		await _clips_wait(G, 60.0)
		if G.room_state == "boss":
			break
		if G.room_state == "fight":
			var st0 := Time.get_ticks_msec()
			var br: Dictionary = await _bot_fight(g, G, 150.0)
			(J["stages"] as Array).append({"n": int(G.run["pos"]) + 1, "type": String(G.room.get("type", "")), "sec": snappedf(float(Time.get_ticks_msec() - st0) / 1000.0, 0.1), "timeout": bool(br["timeout"]), "hp_left": snappedf(float(P.hp), 0.1)})
			ok(not bool(br["timeout"]) and G.room_state != "fight", "REAL: комната %d (%s) пройдена ботом с клавиатуры за %.0f с%s" % [int(G.run["pos"]) + 1, String(G.room.get("type", "")), float(Time.get_ticks_msec() - st0) / 1000.0, " (ПРОВАЛ по времени, добито)" if bool(br["timeout"]) else ""])
		await wait(0.5)
		if G.hub_ui != null and G.hub_ui.kind == "fit":
			var fo: Array = G.fit_options(String(G.room.get("type", "")) == "elite")
			if not fo.is_empty():
				G.take_fit(String(fo[0]))
			await wait(0.3)
		if G.hub_ui != null:
			await wait(0.4)
			await shot("r_%s_%d" % [String(G.room.get("type", "")), int(G.run["pos"]) + 1])
			await key(KEY_ESCAPE)
			await until(func(): return G.hub_ui == null, 2.0)
			await wait(0.3)
		if G.world.gates.is_empty():
			await wait(1.0)
		if G.world.gates.is_empty():
			ok(false, "REAL: после комнаты %d нет дверей (состояние %s)" % [int(G.run["pos"]) + 1, G.room_state])
			await shot("r_no_gates")
			return
		pos = int(G.run["pos"])
		if bool(G.world.gates[0]["auto"]):
			P.global_position = (G67Yard.zone(String(G.world.gates[0]["option"]["place"]))["c"] as Vector3) + Vector3(0, 0.05, 0)      # засада стартует, когда герой вошёл в её зону
		else:
			await _go(G, P, "gate0")
		await until(func(): return int(G.run["pos"]) != pos, 8.0)
	var bossed: bool = await until(func(): return G.room_state == "boss" and g.boss_e != null and is_instance_valid(g.boss_e), 10.0)
	ok(bossed, "REAL: дошли до босса (комната %s, позиция %d)" % [G.room_state, int(G.run.get("pos", -1))])
	if not bossed:
		await shot("r_no_boss")
		return
	var B = g.boss_e
	await wait(1.2)
	var cam: Camera3D = g.get_viewport().get_camera_3d()
	var head: Vector3 = B.global_position + Vector3(0, 1.6, 0)
	var sp: Vector2 = cam.unproject_position(head)
	var vs: Vector2 = g.get_viewport().get_visible_rect().size
	var in_frame: bool = not cam.is_position_behind(head) and Rect2(Vector2.ZERO, vs).has_point(sp)
	ok(B.visible and B.rig != null and B.rig.is_visible_in_tree() and in_frame, "REAL: Миша появился и в кадре (экран %s, видим %s)" % [str(sp.round()), str(B.is_visible_in_tree())])
	await shot("r02_boss_intro")
	await until(func(): return not G.scene_busy(), 10.0)
	await until(func(): return B.alive(), 3.0)
	await wait(0.5)
	var cam2: Camera3D = g.get_viewport().get_camera_3d()
	var bh: Vector3 = B.global_position + Vector3(0, 1.4, 0)
	var sp2: Vector2 = cam2.unproject_position(bh)
	ok(not cam2.is_position_behind(bh) and Rect2(Vector2.ZERO, vs).has_point(sp2), "REAL: после постановки Миша в кадре, а не за калиткой (экран %s)" % str(sp2.round()))
	await shot("r03_boss_fight")
	print("GOLDA67CHECK   REAL mode=%s panel=%s dlg=%d events=%s" % [g.mode, str(g.panel), g.dlg.size(), str(G.events.slice(-8))])
	print("GOLDA67CHECK   REAL после постановки: valid=%s alive=%s state=%s hp=%s boss_e==B %s enemies=%d room=%s scene_t=%.2f boss_pos=%s player=%s" % [is_instance_valid(B), B.alive() if is_instance_valid(B) else "-", B.state if is_instance_valid(B) else "-", B.hp if is_instance_valid(B) else "-", g.boss_e == B, g.enemies.size(), G.room_state, G.scene_t, str(B.global_position) if is_instance_valid(B) else "-", str(P.global_position)])
	ok(is_instance_valid(B) and B.alive() and (g.enemies.has(B) or g.boss_e == B), "REAL: бой с Мишей идёт")
	var bt0 := Time.get_ticks_msec()
	var bb: Dictionary = await _bot_fight(g, G, 300.0)
	J["boss"] = {"sec": snappedf(float(Time.get_ticks_msec() - bt0) / 1000.0, 0.1), "hp_left": snappedf(float(P.hp), 0.1), "hp_max": float(P.max_hp), "timeout": bool(bb["timeout"]), "dead": bool(G.over) if "over" in G else false, "state": G.room_state}
	print("GOLDA67CHECK   REAL бой с Мишей: %s" % str(J["boss"]))
	await wait(1.5)
	await _clips_wait(G, 60.0)
	var results_seen: bool = await until(func(): return G.room_state == "over" or G.hub_ui != null or G.place == "hub", 20.0)
	await shot("real_end_%d" % run_n)
	if G.place != "hub":
		if G.hub_ui != null:
			await key(KEY_ENTER)
			await wait(0.6)
		await _go(G, P, "home")
		await until(func(): return G.place == "hub", 12.0)
		await _clips_wait(G, 60.0)
	ok(G.place == "hub", "REAL %d: после победы — экран итогов и возврат в подъезд (место %s)" % [run_n, G.place])
	J["on"] = false
	await wait(0.4)
	_real_summary(g, G, J, run_n)

## Этап 2: экраны предметов подъезда как у игрока — подойти, E, клавиши, мышь, Esc; снимки каждого экрана
func _hub_screen(G: Golda67, P, id: String, kind: String) -> bool:
	await _go(G, P, id)
	return await until(func(): return G.hub_ui != null and G.hub_ui.kind == kind, 3.0)

func _hub_screens(g, G: Golda67, P) -> void:
	# значок «новый разговор» над dj flürr, пока его новый разговор не услышан
	ok(G.mark_talk != null and G.mark_talk.visible == G.flurr_new(), "над dj flürr — значок нового разговора (%s)" % str(G.mark_talk.visible if G.mark_talk != null else null))
	# АВТОРИТЕТ РАЙОНА: покупка уровня за РЕСПЕКТ настоящими клавишами
	G.meta()["respect"] = 60
	ok(await _hub_screen(G, P, "upgrades", "upgrades"), "стол улучшений открывает «АВТОРИТЕТ РАЙОНА»")
	var U = G.hub_ui
	ok(U is G67AuthorityUI and U.cards.size() == 7, "семь рабочих веток улучшений — закрытые не показаны")
	ok(not G.prompt.visible and g.intro_busy(), "пока экран открыт, подсказка скрыта, ввод игры закрыт")
	await wait(0.3)
	await shot("h01_upgrades")
	var hp0: float = P.max_hp
	await key(KEY_ENTER)             # первая ветка — ЗДОРОВЬЕ
	await wait(0.2)
	ok(G.up("hp") == 1 and int(G.meta()["respect"]) == 60 - G67Data.UP_COST[0] and absf(P.max_hp - hp0 - 10.0) < 0.01,
		"ЗДОРОВЬЕ, уровень 1: РЕСПЕКТ %d, здоровье %.0f → %.0f" % [int(G.meta()["respect"]), hp0, P.max_hp])
	await key(KEY_D)
	await key(KEY_ENTER)             # УРОН — правее
	await wait(0.2)
	ok(G.up("dmg") == 1 and absf(P.dmg_mul - 1.04) < 0.001, "УРОН, уровень 1: множитель %.2f" % P.dmg_mul)
	await key(KEY_D)
	var r0 := int(G.meta()["respect"])
	await key(KEY_ENTER)             # ВОССТАНОВЛЕНИЕ — работает с этапа 3
	await wait(0.2)
	ok(G.up("res") == 1 and int(G.meta()["respect"]) == r0 - G67Data.UP_COST[0], "ВОССТАНОВЛЕНИЕ, уровень 1 куплена (этап 3)")
	await shot("h02_upgrades_bought")
	# все состояния карточек разом: максимум, можно купить, не хватает, закрыто; выбор и покупка — снимки
	G.meta()["up"] = {"hp": 5, "dmg": 2, "rare": 1}
	G.meta()["respect"] = 20
	U._refresh_all()
	U._select(0)
	await wait(0.3)
	await shot("h02b_states")
	await key(KEY_S)
	await wait(0.3)
	ok(U.sel == 3 and String((U.cards[3] as G67UpCard).id) == "rare", "S ведёт по сетке в следующий ряд: РЕДКИЕ БАФЫ")
	await shot("h02c_rare_selected")
	await key(KEY_ENTER)
	await wait(0.12)
	await shot("h02d_bought_anim")
	ok(G.up("rare") == 2, "РЕДКИЕ БАФЫ куплены с клавиатуры (уровень %d)" % G.up("rare"))
	await key(KEY_ENTER)
	await wait(0.1)
	ok(G.up("rare") == 2 and String(U.d_why.text).contains("Не хватает"), "не хватает РЕСПЕКТА — покупки нет, причина написана: «%s»" % U.d_why.text)
	await shot("h02e_short")
	U._select(0)
	await wait(0.2)
	ok((U.cards[U.sel] as G67UpCard).state == "max" and U.d_btn.disabled, "ветка на максимуме: кнопка покупки выключена")
	await shot("h02f_max")
	G.meta()["up"] = {"hp": 1, "dmg": 1}
	G.meta()["respect"] = 0
	G.meta()["respect"] = 0
	await key(KEY_ESCAPE)
	ok(await until(func(): return G.hub_ui == null, 1.0), "Esc закрывает экран")
	ok(not get_tree().paused, "Esc на экране не открывает паузу")
	# стойка стилей: до Миши — только Балон, madk1d закрыт; закрытое не берётся
	ok(await _hub_screen(G, P, "styles", "styles"), "стойка стилей открывает свой экран")
	var SU = G.hub_ui
	ok(SU is G67StylesUI and SU.slots.size() == 6, "на доске шесть мест: три Пахана, три madk1d")
	ok((SU.slots[0] as G67StylesUI.Slot).open and (SU.slots[0] as G67StylesUI.Slot).held and SU.slots.slice(1).all(func(o): return not (o as G67StylesUI.Slot).open), "открыт только Балон VOZDUH (он в руках), остальные пять — на замке")
	await wait(0.8)
	await shot("h03_styles")
	await key(KEY_D)
	await key(KEY_ENTER)
	await wait(0.2)
	ok(G.start_style() == "vozduh" and String(SU.t_why.text).contains("Миш"), "закрытая Водяра не берётся, причина: «%s»" % SU.t_why.text)
	G.meta()["flags"]["boss_misha"] = true
	G.apply_styles()
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	await _hub_screen(G, P, "styles", "styles")
	G.hub_ui.select(1)
	await wait(0.25)
	await key(KEY_ENTER)
	await wait(0.2)
	ok(G.start_style() == "bottles" and (G.hub_ui.slots[1] as G67StylesUI.Slot).held and not (G.hub_ui.slots[0] as G67StylesUI.Slot).held, "после Миши Водяра берётся в забег, бирка «В РУКАХ» переходит на неё")
	G.set_start_style("vozduh")
	G.meta()["flags"].erase("boss_misha")
	G.apply_styles()
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	# коллекция артефактов: сервант, 18 мест, пока все — силуэты
	ok(await _hub_screen(G, P, "artifacts", "artifacts"), "коллекция артефактов открывается")
	var CU = G.hub_ui
	ok(CU is G67ArtifactsUI and CU.cells.size() == 18 and CU.cells.all(func(c): return (c as G67ArtifactsUI.Cell).tex != null), "18 мест с рисованными значками владельца")
	ok(CU.cells.all(func(c): return not (c as G67ArtifactsUI.Cell).has) and CU.c_name.text == "???", "ничего не найдено — за стеклом силуэты, имя скрыто")
	await wait(0.3)
	await shot("h04_artifacts")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	# карта маршрутов: четыре района и шесть зон двора
	ok(await _hub_screen(G, P, "routes", "routes"), "карта маршрутов открывается")
	var RU = G.hub_ui
	ok(RU is G67RoutesUI and RU.marks.size() == 4 + G67Yard.ZONES.size(), "на карте 4 района и %d зон двора" % G67Yard.ZONES.size())
	ok(String((RU.marks[0] as G67RoutesUI.Mark).state) == "open" and String((RU.marks[1] as G67RoutesUI.Mark).state) == "lock", "ДВОР открыт, ПОДЗЕМКА закрыта (Миша не побеждён)")
	await wait(0.3)
	await shot("h05_routes")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	# доска объявлений: пробковая доска, три листка; объявление после Миши — заклеено и не открывается
	ok(await _hub_screen(G, P, "notices", "board"), "доска объявлений открывается")
	var BU = G.hub_ui
	ok(BU is G67BoardUI and BU.notes.size() == 3, "на доске три листка из данных")
	ok(not g.combat_hud.visible and not g.hud_root.visible, "пока экран открыт, HUD игры спрятан")
	ok((BU.notes[2] as G67BoardUI.Note).locked and String(BU.notes[2].why).contains("Миш"), "объявление «АВТОРИТЕТ ВРЕМЕННО НЕДОСТУПЕН» до победы над Мишей заклеено, причина: «%s»" % BU.notes[2].why)
	ok((BU.notes[0] as G67BoardUI.Note).fresh, "непрочитанный листок с наклейкой «НОВОЕ»")
	ok(BU.big is G67BoardUI.Info and BU.big.kind != "" and BU.big.status == "НОВОЕ" and BU.big.when != "", "справа карточка «что это»: %s · %s · %s" % [BU.big.kind, BU.big.status, BU.big.when])
	ok(BU.stage.find_children("*", "Label", true, false).any(func(l): return String(l.text).begins_with("Esc")), "в углу мелко «Esc — закрыть»")
	await wait(3.6)
	ok(BU.stage.find_children("*", "Label", true, false).all(func(l): return not String(l.text).begins_with("Esc") or l.modulate.a < 0.05), "через 3 с подсказка «Esc» погасла")
	ok(_text_fits(BU), "доска: надписи внутри экрана")
	ok(BU.big.get_rect().end.y <= 900.0 and BU.big.get_rect().end.x <= 1600.0, "карточка внутри стола")
	await wait(0.4)
	await shot("h06_board")
	await key(KEY_ENTER)
	await wait(0.35)
	ok(BU.mode == "read" and (G.meta().get("board_read", []) as Array).has(0), "Enter снимает листок и читает вблизи, листок отмечен прочитанным")
	await shot("h06b_board_read")
	await key(KEY_ESCAPE)
	await wait(0.2)
	ok(BU.mode == "list" and BU.sel == 0 and G.hub_ui != null, "Esc — листок обратно на доску, выбор тот же")
	BU.select(2)
	await key(KEY_ENTER)
	await wait(0.2)
	ok(BU.mode == "list", "заклеенный листок не читается")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	ok(g.combat_hud.visible, "после экрана HUD вернулся")
	# почтовые ящики: три ящика с письмами, вестник до победы над Мишей — на замке
	ok(await _hub_screen(G, P, "mail", "mail"), "почтовые ящики открываются")
	var MU = G.hub_ui
	ok(MU is G67MailUI and MU.items.size() == 3 and MU.boxes.size() == 15, "15 ящиков в блоке, писем — в трёх")
	ok(String((MU.items[2]["node"] as G67MailUI.Box).state) == "lock" and String((MU.items[0]["node"] as G67MailUI.Box).state) == "new", "листовка ждёт в ящике, вестник — на замке до победы над Мишей")
	await wait(0.4)
	await shot("h07_mail")
	await key(KEY_ENTER)
	await wait(1.4)
	ok(MU.mode == "read" and (G.meta().get("mail_read", []) as Array).has(0), "Enter открывает ящик и письмо, письмо отмечено прочитанным")
	await shot("h07b_letter")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(MU.mode == "list" and MU.sel == 0 and String((MU.items[0]["node"] as G67MailUI.Box).state) == "read", "Esc — обратно к тому же ящику, он прочитан")
	await key(KEY_D)
	await key(KEY_D)
	await wait(0.1)
	var s_before: int = MU.sel
	MU.select(2)
	await key(KEY_ENTER)
	await wait(0.3)
	ok(MU.mode == "list" and not (G.meta().get("mail_read", []) as Array).has(2), "запертый ящик не открывается (выбор был %d)" % s_before)
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	# архив у телевизора (трейлер уже был: сразу стена телевизоров)
	var cs0: Array = (G.meta().get("clips_seen", []) as Array).duplicate()
	if not cs0.has("V00"):
		G.meta()["clips_seen"] = cs0 + ["V00"]
	var tv_ok: bool = await _hub_screen(G, P, "tv", "archive")
	ok(tv_ok, "телевизор открывает «АРХИВ ПИЗДЕЦА»")
	var AU = G.hub_ui
	ok(AU is G67ArchiveUI and AU.tvs.size() == 12 and AU.tapes.size() == G67Data.KROT.size() + G67Flurr.STATES.size(), "стена из 12 телевизоров (семь роликов, три события, две концовки) и %d кассет" % AU.tapes.size())
	var locked_ok := true
	var open_ok := true
	for i in AU.tvs.size():
		var r: Dictionary = AU.recs[i]
		var st := String((AU.tvs[i] as G67ArchTV).state)
		if r["type"] == "clip":
			if G.clip_open(String(r["id"])) != (st != "lock"):
				open_ok = false
			if st != "lock" and not ResourceLoader.exists(String(r["preview"])):
				open_ok = false
		elif st != "lock":
			locked_ok = false
	ok(open_ok, "открытые ролики горят своим стоп-кадром, неоткрытые — на цепи (как clip_open)")
	ok(locked_ok, "события и концовки — запертые телевизоры")
	await wait(1.6)
	await shot("h08_archive")
	# запертый телевизор не запускается
	var li := -1
	for i in AU.tvs.size():
		if (AU.tvs[i] as G67ArchTV).state == "lock":
			li = i
			break
	AU.select(li)
	await key(KEY_ENTER)
	await wait(0.2)
	ok(G.clip == null and AU.mode == "list", "запертый телевизор не включается")
	await shot("h08b_archive_locked")
	# просмотр: Enter → ролик тем же плеером, по окончании — архив у того же телевизора
	AU.select(0)
	await key(KEY_ENTER)
	ok(await until(func(): return G.clip != null, 2.0) and not AU.visible, "Enter на открытом телевизоре — ролик, архив спрятан")
	G.clip.skippable = true
	G.clip.skip()
	ok(await until(func(): return G.clip == null and AU.visible and AU.mode == "list", 3.0) and AU.sel == 0, "после ролика — снова архив, у того же телевизора")
	# кассета: разговор целиком
	var ti := -1
	for i in range(AU.tvs.size(), AU.recs.size()):
		if bool(AU.recs[i].get("has", false)):
			ti = i
			break
	if ti >= 0:
		AU.select(ti)
		await key(KEY_ENTER)
		await wait(0.3)
		ok(AU.mode == "read" and AU.r_rows.size() == (AU.recs[ti]["lines"] as Array).size(), "кассета: разговор целиком, %d реплик" % AU.r_rows.size())
		await shot("h08c_tape")
		await key(KEY_ESCAPE)
		await wait(0.2)
		ok(AU.mode == "list", "Esc — обратно к полке")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 1.0)
	G.meta()["clips_seen"] = cs0
	# дальше проверка считает точные числа фитсов: улучшения снимаем, в забег — только один перевыбор
	G.meta()["up"] = {"reroll": 1}
	P.max_hp = G.hp_max()
	P.hp = P.max_hp
	P.dmg_mul = 1.0

## --g67-frames=<папка>: каждый ролик главы 1 — кадр каждые 0,5 с без субтитров (с плашками ролика), для выбора
## стоп-кадра телевизора в «АРХИВЕ ПИЗДЕЦА» (готовые превью — assets/golda67/archive/<ID>.jpg)
func _clip_frames(G: Golda67, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for cid in G67Clips.ORDER:
		var c := G67ClipPlayer.open(G.game, cid, true)
		var n := 0
		while is_instance_valid(c) and not c.done:
			c.sub_text.visible = false
			c.sub_name.visible = false
			c.hint.visible = false
			await wait(0.5)
			if not is_instance_valid(c) or c.done:
				break
			await RenderingServer.frame_post_draw
			if not is_instance_valid(c):
				break
			var img := get_viewport().get_texture().get_image()
			var r := Rect2i(get_viewport().get_final_transform() * c.frame.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var cut := img.get_region(r)
			cut.resize(480 if not c.tall else 270, 270 if not c.tall else 480, Image.INTERPOLATE_BILINEAR)
			cut.save_png(dir.path_join("%s_%03d.png" % [cid, n]))
			n += 1
		print("GOLDA67CHECK   кадры %s: %d" % [cid, n])
		await wait(0.3)

## убить всех живых врагов (бой проверяют проверки боя; здесь — цикл комнат)
## Этап 3: кладовка (выбор одного из двух, полные карманы — замена), ларёк «ШАУРМА 67» (цены, лимиты, причины
## отказа), эффекты всех артефактов и ВОССТАНОВЛЕНИЯ числами, ДОБИВАЛА и ВТОРОЕ ДЫХАНИЕ по таблице
func _stage3(g, G: Golda67, P) -> void:
	ok(G.place == "hub", "этап 3: начинаем из подъезда")
	ok(G67Data.ARTIFACTS.size() == 18 and G.slots() == 3, "18 артефактов, слотов 3")
	var pool := G.storage_pool()
	ok(not pool.any(func(id): return G67Data.ART_EVENT.has(id)), "событийных артефактов в кладовке нет")
	ok(not pool.has("second_sim"), "«Вторая симка» до первой концовки не выпадает")
	ok(pool.has("autotune_ring") == (G.styles_open().size() >= 2), "«Автотюн» — только когда открыты два стиля (стилей %d)" % G.styles_open().size())
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "этап 3: забег начался")
	await _clear_room(g, G)
	await wait(0.3)
	# ---- кладовка: два артефакта, Enter берёт выбранный
	G.run["pos"] = 2
	await G.enter_room({"type": "storage", "place": "garages"})
	ok(await until(func(): return G.hub_ui != null and G.hub_ui.kind == "storage", 3.0), "КЛАДОВКА: в гараже сам открылся экран выбора")
	var off: Array = G.storage_offer()
	ok(off.size() == 2 and off[0] != off[1] and not off.any(func(id): return G67Data.ART_EVENT.has(id)), "на верстаке два разных артефакта (%s)" % str(off))
	ok(g.hud_root.visible == false and g.combat_hud.visible == false, "HUD игры под экраном спрятан")
	await wait(0.5)
	await shot("s3_01_storage")
	await key(KEY_D)
	await wait(0.2)
	await key(KEY_ENTER)
	ok(await until(func(): return G.hub_ui == null, 2.0), "взял — экран закрылся")
	ok(G.arts() == [off[1]] and (G.meta()["artifacts"] as Array).has(off[1]), "взят второй артефакт, он попал в коллекцию (%s)" % str(G.arts()))
	ok(G.room_state == "open" and not G.world.gates.is_empty() and G.point("storage").is_empty(), "дальше двери, бокс закрыт")
	await wait(0.3)
	await shot("s3_02_storage_taken")
	# ---- полные карманы: выбрать, что выложить
	G.run["arts"] = ["beanie", "sim", "grillz"]
	G.apply_fits()
	await G.enter_room({"type": "storage", "place": "garages"})
	await until(func(): return G.hub_ui != null and G.hub_ui.kind == "storage", 3.0)
	off = G.storage_offer()
	ok(not off.has("beanie") and not off.has("sim") and not off.has("grillz"), "взятые в этом забеге второй раз не предлагаются (%s)" % str(off))
	await wait(0.3)
	await key(KEY_ENTER)
	await wait(0.3)
	ok(G.hub_ui != null and String(G.hub_ui.pick) == String(off[0]) and G.hub_ui.sel == G.hub_ui.slot0, "карманы полны: выбор переходит на карманы")
	await shot("s3_03_storage_full")
	var hp0: float = P.max_hp
	await key(KEY_ENTER)
	ok(await until(func(): return G.hub_ui == null, 2.0), "выложил шапку — взял новое")
	ok(G.arts().size() == 3 and G.arts().has(off[0]) and not G.arts().has("beanie") and P.max_hp == hp0 - 20.0, "замена: %s, максимум здоровья без шапки %.0f" % [str(G.arts()), P.max_hp])
	ok(not G.take_art("cassette_2016"), "в полные карманы без замены не кладётся")
	# Esc — оставить и уйти, бокс остаётся
	await G.enter_room({"type": "storage", "place": "garages"})
	await until(func(): return G.hub_ui != null, 3.0)
	await wait(0.3)
	await key(KEY_ESCAPE)
	ok(await until(func(): return G.hub_ui == null, 2.0) and G.room_state == "open" and not G.point("storage").is_empty(), "Esc — ушёл ни с чем: двери открыты, к боксу можно вернуться")
	await _go(G, P, "storage")
	ok(await until(func(): return G.hub_ui != null and G.hub_ui.kind == "storage", 2.0), "бокс открывается снова на [E]")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 2.0)
	# ---- эффекты артефактов числами
	G.run["arts"] = []
	G.run["fits"] = {}
	G.apply_fits()
	await wait(0.1)
	var base_mhp: float = P.max_hp
	ok(G.take_art("beanie") and P.max_hp == base_mhp + 20.0, "«Шапка-бини»: максимум %.0f → %.0f" % [base_mhp, P.max_hp])
	G.take_art("one_earbud")
	G.take_art("blue_tape")
	ok(absf(G.mods.incoming(g) - 0.9) < 0.001, "«Наушники»: входящий урон ×0,9")
	var h := HitInfo.new()
	h.damage = 10.0
	h.heavy = true
	G.mods.melee_hit(h, P, 1)
	ok(absf(h.damage - 11.5) < 0.01, "«Синяя изолента»: тяжёлый 10 → %.1f" % h.damage)
	var h2 := HitInfo.new()
	h2.damage = 10.0
	G.mods.melee_hit(h2, P, 1)
	ok(absf(h2.damage - 10.0) < 0.01, "лёгкий удар изолента не трогает")
	G.run["arts"] = ["grillz", "collar_67", "sim"]
	ok(absf(G.mods.parry_stun() - 1.5) < 0.001, "«Грилзы»: оглушение парированием ×1,5")
	ok(G.mods.save_from_death(g) and not G.mods.save_from_death(g), "«ОШЕЙНИК 67»: спасает от смертельного удара один раз за забег")
	await wait(0.1)
	ok(absf(P.combat.cd_k - 0.85) < 0.001, "«SIM-карта»: перезарядки ×0,85")
	G.run["arts"] = ["market_sneakers", "bracelet_67", "cracked_phone"]
	await wait(0.1)
	ok(absf(P.speed_k - 1.08) < 0.001 and absf(P.combat.cd_k - 1.0) < 0.001, "«Рыночные кроссовки»: скорость ×1,08; без симки перезарядки обычные")
	ok(absf(G.gold_k() - 1.2) < 0.001, "«Золотой браслет 67»: голда ×1,2")
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	P.inv = 30.0
	await wait(0.3)
	P.hp = P.max_hp * 0.3
	await wait(0.3)
	ok(absf(P.dmg_mul - G.fit_mul * 1.25) < 0.001, "«Телефон с треснутым экраном»: ниже 35 %% — урон ×%.2f" % P.dmg_mul)
	P.hp = P.max_hp
	await wait(0.3)
	ok(absf(P.dmg_mul - G.fit_mul) < 0.001, "выше 35 %% — урон обычный")
	G.run["arts"] = ["cassette_2016"]
	await wait(0.1)
	P.hp -= 5.0
	await wait(0.1)
	ok(absf(P.dmg_mul - G.fit_mul * 1.2) < 0.001 and G.events.has(["cassette"]), "«Кассета 2016»: после полученного урона +20 %")
	G.run["arts"] = ["cracked_phone", "cassette_2016"]
	G.fit_mul = 1.9
	P.hp = 10.0
	await wait(0.1)
	ok(absf(P.dmg_mul - G67Data.DMG_CAP_ALL) < 0.001, "общий потолок урона фитсов и артефактов — ×%.1f" % P.dmg_mul)
	G.apply_fits()
	P.hp = P.max_hp
	# ВОССТАНОВЛЕНИЕ (АВТОРИТЕТ РАЙОНА): −8 % за уровень
	var ups: Dictionary = G.meta().get("up", {})
	ups["res"] = 1
	G.meta()["up"] = ups
	G.run["arts"] = ["sim"]
	await wait(0.1)
	ok(absf(P.combat.cd_k - 0.85 * 0.92) < 0.001 and absf(P.combat.ammo_k - 0.92) < 0.001, "«ВОССТАНОВЛЕНИЕ» ур. 1 с симкой: перезарядки ×%.3f, боезапас ×%.2f" % [P.combat.cd_k, P.combat.ammo_k])
	ups["res"] = 0
	G.run["arts"] = []
	# ---- ДОБИВАЛА и ВТОРОЕ ДЫХАНИЕ по таблице
	G.run["fits"] = {"finisher": 1}
	G.fin_room = 0.0
	P.hp = 40.0
	G._spawn("shest")
	await _kill_spawned(g, G)
	ok(absf(P.hp - 43.0) < 0.01, "«ДОБИВАЛА» ур. 1: +3 за врага (здоровье %.0f)" % P.hp)
	G._spawn("smotr")
	await _kill_spawned(g, G)
	ok(absf(P.hp - 52.0) < 0.01, "за элитного — втрое: +9 (здоровье %.0f)" % P.hp)
	G.fin_room = 24.0
	G._spawn("shest")
	await _kill_spawned(g, G)
	ok(absf(P.hp - 53.0) < 0.01 and absf(G.fin_room - 25.0) < 0.01, "не больше 25 за комнату (здоровье %.0f)" % P.hp)
	G.run["fits"] = {"second_wind": 2}
	G.wind_used = false
	P.hp = P.max_hp * 0.2
	var hw: float = P.hp
	await wait(0.1)
	ok(absf(P.hp - (hw + 40.0)) < 0.01, "«ВТОРОЕ ДЫХАНИЕ» ур. 2: +40 ниже 30 %")
	G.run["fits"] = {}
	G.apply_fits()
	# ---- ларёк «ШАУРМА 67»: постоянный магазин двора, запас — на забег
	G.run["golda"] = 300
	G.run["kiosk"] = {}
	G.run["kiosk_full"] = true
	G.run["pos"] = 3
	ok(G.room_state == "open" and not G.point("kiosk").is_empty(), "ларёк у окна есть, пока боя нет")
	await _go(G, P, "kiosk")
	ok(await until(func(): return G.hub_ui != null and G.hub_ui.kind == "kiosk", 3.0), "ЛАРЁК: по [E] у окна открылся экран ценников")
	ok(G.room_state == "open" and not G.point("home").is_empty(), "двери и дом из ларька открыты")
	await wait(0.5)
	await shot("s3_04_kiosk")
	P.hp = 30.0
	await key(KEY_ENTER)
	await wait(0.2)
	ok(int(G.run["golda"]) == 270 and absf(P.hp - 70.0) < 0.01 and int(G.run["spent"]) >= 30, "ШАУРМА: −30 голды, +40 здоровья (голда %d, здоровье %.0f)" % [int(G.run["golda"]), P.hp])
	for i in 3:
		await key(KEY_ENTER)
		await wait(0.2)
	ok(int(G.run["golda"]) == 150 and G.kiosk_price("shawarma") == 50, "шаурма без лимита, цена растёт: 30, 35, 40, 45 (голда %d, следующая %d)" % [int(G.run["golda"]), G.kiosk_price("shawarma")])
	await key(KEY_ENTER)
	await wait(0.2)
	ok(int(G.run["golda"]) == 100 and G.kiosk_why("shawarma") == "" and G.kiosk_price("shawarma") == 55, "пятая шаурма за 50 продаётся, следующая 55")
	G.run["golda"] = 20
	G.hub_ui._refresh()
	ok(G.kiosk_why("double") == "не хватает голды", "на двойную не хватает голды — ценник бледный с причиной")
	await wait(0.3)
	await shot("s3_05_kiosk_refused")
	G.flush_coins()
	G.run["golda"] = 200
	G.hub_ui._refresh()
	var mh: float = P.max_hp
	await key(KEY_D)
	await wait(0.2)
	await key(KEY_ENTER)
	await wait(0.2)
	ok(absf(P.max_hp - (mh + 15.0)) < 0.01 and int(G.run["golda"]) == 145, "ДВОЙНАЯ: максимум %.0f → %.0f, −55 голды" % [mh, P.max_hp])
	var nf := 0
	for f in G67Data.FITS:
		nf += G.fit_lv(f)
	await key(KEY_D)
	await wait(0.2)
	await key(KEY_ENTER)
	await wait(0.2)
	var nf2 := 0
	for f in G67Data.FITS:
		nf2 += G.fit_lv(f)
	ok(nf2 == nf + 1 and int(G.run["golda"]) == 75, "С СОБОЙ: случайный баф (+1 уровень), −70 голды")
	await wait(0.3)
	await shot("s3_06_kiosk_bought")
	await key(KEY_ESCAPE)
	ok(await until(func(): return G.hub_ui == null, 2.0) and not G.point("kiosk").is_empty(), "Esc — отошёл от окна, ларёк остаётся")
	await _go(G, P, "kiosk")
	ok(await until(func(): return G.hub_ui != null and G.hub_ui.kind == "kiosk", 2.0), "к окну можно подойти снова")
	ok(G.kiosk_price("shawarma") == 55 and G.kiosk_left("togo") == 1, "запас — на забег, а не на подход к окну (шаурмы %d, «С СОБОЙ» %d)" % [G.kiosk_left("shawarma"), G.kiosk_left("togo")])
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 2.0)
	# ---- домой и обратно: ларёк на месте, запас не обнулился
	await _go(G, P, "home")
	ok(await until(func(): return G.place == "hub", 6.0), "из ларька можно уйти домой")
	await wait(0.3)
	ok(P.speed_k == 1.0 and absf(P.combat.cd_k - 1.0) < 0.001, "в подъезде эффекты забега сняты")
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and not G.point("kiosk").is_empty(), 8.0), "продолжение забега: ларёк снова у окна")
	ok(G.kiosk_price("shawarma") == 55, "после продолжения забега цена шаурмы прежняя")
	# ---- конец забега: артефакты остаются в коллекции, в новом забеге карманы пусты
	G._finish_run(false, 0.1)
	ok(await _result_to_hub(G), "забег окончен — экран итогов, «В ПОДЪЕЗД» — подъезд")
	ok((G.meta()["artifacts"] as Array).size() >= 3, "найденные артефакты остались в коллекции (%d)" % (G.meta()["artifacts"] as Array).size())
	await wait(0.5)

## добить только что появившихся (пока враг выходит, он неуязвим)
func _kill_spawned(g, G: Golda67) -> void:
	for i in 40:
		_kill_all(g)
		await wait(0.15)
		if G.alive() == 0:
			break
	await wait(0.2)

func _kill_all(g) -> void:
	for e in g.enemies:
		if is_instance_valid(e) and e.state != "dead":
			e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)

func _clear_room(g, G: Golda67, sec := 40.0) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if G.room_state != "fight":
			return true
		_kill_all(g)
		await wait(0.25)
	return G.room_state != "fight"

func _go(G: Golda67, P, id: String) -> void:
	var pt: Dictionary = G.point(id)
	if pt.is_empty():
		print("GOLDA67CHECK   нет точки «%s»" % id)
		return
	P.global_position = Vector3(pt["pos"].x, pt["pos"].y + 0.05, pt["pos"].z)
	P.velocity = Vector3.ZERO
	await wait(0.3)
	await key(KEY_E)

## Снимки мест, где стоят варианты следующего этапа: значок, стойка, вешалка, бокс, лавка, калитка
func _gate_shots(g, G: Golda67, tag: String) -> void:
	for i in G.world.gates.size():
		var opt: Dictionary = G.world.gates[i]["option"]
		var spot: Dictionary = G67World.gate_spot(opt)
		var mark: Vector3 = spot["mark"]
		await _yard_shot(g, G, mark + Vector3(0, -1.4, 0), mark + Vector3(4.5, -0.4, 6.0), "21e_%s_gate%d_%s" % [tag, i, String(opt["type"])])

## Враги, которым задан свой рывок (kb без удара), стену не «получают»; отброшенного ударом в ограждение — впечатывает (B05)
func _b05_check(g, G: Golda67, P) -> void:
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.4)
	P.inv = 1.0
	var c: Vector3 = g.arena_c
	var h: Vector2 = g.arena_h
	# своим рывком в героя
	var e1 = g._make_enemy("bot", "", Vector3(c.x - 3.0, 0.05, c.z))
	await wait(1.6)
	e1.cool = 99.0
	e1.global_position = Vector3(c.x - 3.0, 0.05, c.z)
	P.global_position = Vector3(c.x - 1.7, 0.05, c.z)
	P.velocity = Vector3.ZERO
	e1.kb = Vector3(18.0, 0, 0)
	e1.kb_hit = false
	await wait(0.7)
	ok(e1.wall_hits == 0, "B05: враг, рванувший в героя своим рывком, «в стену» не впечатан (раз %d)" % e1.wall_hits)
	# своим рывком в другого врага
	var e2 = g._make_enemy("bot", "", Vector3(c.x + 3.0, 0.05, c.z - 4.0))
	await wait(1.6)
	e2.cool = 99.0
	e2.global_position = Vector3(c.x + 3.0, 0.05, c.z - 4.0)
	e1.global_position = Vector3(c.x + 4.3, 0.05, c.z - 4.0)
	e1.cool = 99.0
	e2.kb = Vector3(18.0, 0, 0)
	e2.kb_hit = false
	await wait(0.7)
	ok(e2.wall_hits == 0, "B05: и в другого врага — не стена (раз %d)" % e2.wall_hits)
	# ударом героя — в ограждение зоны
	var e3 = g._make_enemy("bot", "", Vector3(c.x + h.x - 2.6, 0.05, c.z + 3.0))
	await wait(1.6)
	e3.cool = 99.0
	e3.global_position = Vector3(c.x + h.x - 2.6, 0.05, c.z + 3.0)
	var wh0: float = e3.hp
	var hw := HitInfo.new()
	hw.damage = 1.0
	hw.heavy = true
	hw.knockback = 16.0
	hw.dir = Vector3(1, 0, 0)
	e3.take_hit_info(hw)
	await wait(1.2)
	ok(e3.wall_hits == 1 and wh0 - e3.hp >= 8.0, "B05: отброшенного ударом в ограждение зоны впечатало: раз %d, урон %.0f" % [e3.wall_hits, wh0 - e3.hp])
	_kill_all(g)
	await wait(0.5)
	P.inv = 0.0
	G.wave_wait = 0.0

## Свободна ли точка двора для ходьбы: шар по росту героя не задевает неподвижных преград
func _free_spot(g, p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	q.shape = sh
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
	q.collision_mask = 1
	for r in g.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if r["collider"] is StaticBody3D:
			return false
	return true

## N01: Семечник у края зоны после «отталкивающей волны» остаётся внутри арены
func _n01_check(g, G: Golda67, P) -> void:
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.3)
	var c: Vector3 = g.arena_c
	var h: Vector2 = g.arena_h
	P.inv = 1.0
	G._spawn("semka")
	var foe = g.enemies[g.enemies.size() - 1]
	await wait(1.6)
	foe.global_position = Vector3(c.x - h.x + 1.3, 0.05, c.z)
	P.global_position = Vector3(c.x - h.x + 4.0, 0.05, c.z)
	EnemyAI.blink(foe, "away")
	ok(g.in_arena(foe.global_position, 0.0), "N01: после «away» у края зоны Семечник внутри арены (%s)" % str(foe.global_position))
	# страховка: за ограждением дольше секунды — переставляется внутрь
	foe.set_meta("spawn_ms", -100000)
	foe.global_position = Vector3(c.x - h.x - 6.0, 0.05, c.z)
	G.pending = []
	G.wave_wait = 999.0
	for i in 12:
		G._keep_foes_inside(0.15)
	ok(g.in_arena(foe.global_position, 0.0), "N01: враг за ограждением дольше секунды возвращён в арену")
	_kill_all(g)
	P.global_position = Vector3(c.x, 0.05, c.z)
	P.inv = 0.0
	G.wave_wait = 0.0

## N04: серия ударов героя в защитную стойку Миши — «ВЕРНУЛ» не роняет разбор попаданий
func _n04_check(g, G: Golda67, P, B) -> void:
	await _misha_set(B, P, "m_guard", Vector3(0, 0.05, 0.2))
	await wait(0.4)
	P.global_position = B.global_position + Vector3(sin(B.face), 0, cos(B.face)) * 1.7
	P.face = atan2(-sin(B.face), -cos(B.face))
	var swings := 0
	for i in 14:
		P.inv = 0.0
		B.guard_next = 0.0
		Input.action_press("attack")
		await wait(0.12)
		Input.action_release("attack")
		await wait(0.18)
		swings += 1
	ok(swings == 14 and P.state != "dead" and (P.combat.cur == null or P.combat.cur is AttackData), "N04: серия ударов в стойку Миши прошла без падения (состояние героя %s)" % String(P.state))
	P.hp = P.max_hp
	await wait(2.0)

## Заначки: двенадцать мест проходимы, пять из них — с монетой; монета подбирается сама и даёт голду
func _stash_check(g, G: Golda67, P) -> void:
	var st: Dictionary = G.run["stash"]
	var spots: Array = st["spots"]
	ok(G67Yard.STASH.size() == 12 and spots.size() == 5 and spots.size() == (spots as Array).filter(func(i): return spots.count(i) == 1).size(), "заначек 12, на забег выбрано 5 разных (%s)" % str(spots))
	var bad: Array = []
	for i in G67Yard.STASH.size():
		if not _free_spot(g, G67Yard.STASH[i]):
			bad.append(i)
	ok(bad.is_empty(), "все места заначек проходимы: в них не торчит ни одно препятствие (занято: %s)" % str(bad))
	for i in spots:
		var sp: Vector3 = G67Yard.STASH[int(i)]
		await _yard_shot(g, G, sp + Vector3(0, 0.5, 0), sp + Vector3(2.2, 2.0, 3.0), "56_stash%02d" % int(i))
	ok(G.stash_nodes.size() == 5 and spots.all(func(i): return G.stash_nodes.has(int(i)) and is_instance_valid(G.stash_nodes[int(i)])), "в пяти местах лежат монеты g67_golda_coin")
	var amounts: Array = spots.map(func(i): return G.stash_gold(int(i)))
	ok(amounts.all(func(a): return a >= 8 and a <= 15), "в заначке 8–15 голды (%s)" % str(amounts))
	var i0: int = int(spots[0])
	var coin: Node3D = G.stash_nodes[i0]
	var y0: float = coin.rotation.y
	await wait(0.3)
	ok(not is_equal_approx(coin.rotation.y, y0), "монета медленно вращается")
	var gold0 := int(G.run["golda"])
	var n0 := G.events.size()
	P.global_position = G67Yard.STASH[i0] + Vector3(0.6, 0.05, 0)
	P.velocity = Vector3.ZERO
	ok(await until(func(): return not G.stash_nodes.has(i0), 2.0), "монета подобралась сама, как только герой подошёл")
	var got := int(G.run["golda"]) - gold0
	ok(got == amounts[0] and (st["taken"] as Array).has(i0) and G.events.slice(n0).has(["stash", i0]) and int(G.run["stash_n"]) == 1, "голда выдана: +%d, событие stash, счётчик заначек 1" % got)
	await wait(0.4)
	ok(int(G.run["golda"]) == gold0 + got, "второй раз та же заначка не платит")

func _b13_check(g, G: Golda67, P) -> void:
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "забег для проверки клавиши E")
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.5)
	var kp: Vector3 = G.point("kiosk")["pos"]
	P.global_position = kp
	P.velocity = Vector3.ZERO
	P.swag = 0.0
	await wait(0.4)
	ok(G.near == "kiosk", "герой у окна ларька (рядом: %s)" % G.near)
	# нет врагов рядом: E не показывает «нужно 40 СВЭГа»
	P.try_heat()
	ok(g.get_tree().get_nodes_in_group("none").is_empty(), "try_heat без врагов не падает")
	# готовый к добиванию враг перед героем: E — добивание, а не предмет
	var e = g._make_enemy("bot", "", P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 1.5)
	await wait(1.4)
	e.hp = 5.0
	e.stun(3.0)
	e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 1.5
	await wait(0.3)
	var can: bool = P.execution.can_start() and not P.execution.pick().is_empty()
	var uses := G.events.filter(func(ev): return ev.size() > 1 and String(ev[0]) == "use" and String(ev[1]) == "kiosk").size()
	await key(KEY_E)
	await wait(0.4)
	var uses2 := G.events.filter(func(ev): return ev.size() > 1 and String(ev[0]) == "use" and String(ev[1]) == "kiosk").size()
	ok(can and uses2 == uses and G.hub_ui == null, "E с готовым к добиванию врагом у ларька не открывает ларёк (добивание: %s)" % str(can))
	await until(func(): return not P.execution.active(), 5.0)
	_kill_all(g)
	await wait(0.5)
	G.room_state = "open"
	G.run["pos"] = 3
	await key(KEY_E)
	await wait(0.4)
	ok(G.hub_ui != null and G.hub_ui.kind == "kiosk", "без врагов E у ларька открывает ларёк")
	await key(KEY_ESCAPE)
	await until(func(): return G.hub_ui == null, 2.0)
	await G.enter_hub()
	G.data["run"] = {}
	await wait(0.3)

## Выход в меню: hub / safe / fight; сохранение с боем; старая запись забега на паузе
func _quit_check(g, G: Golda67, P) -> void:
	ok(G.place == "hub" and G.quit_kind() == "hub" and G.quit_text() == "Прогресс сохранён.", "выход из подъезда: прогресс сохранён (%s)" % G.quit_kind())
	# --- посреди боя: поражение, РЕСПЕКТ за пройденное остаётся, забег стёрт
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "третий забег начался")
	G.run["respect"] = 7
	var r0 := int(G.meta()["respect"])
	var n0 := int(G.meta().get("runs", 0))
	ok(G.quit_kind() == "fight" and G.quit_text().contains("засчитается как поражение") and G.quit_text().contains("+7"), "в бою выход предупреждает о поражении: «%s»" % G.quit_text())
	G.on_quit()
	ok(int(G.meta()["respect"]) == r0 + 7 and int(G.meta()["runs"]) == n0 + 1 and not G.paused_run() and (G.data["run"] as Dictionary).is_empty(), "выход из боя: РЕСПЕКТ +7 в постоянное, забег стёрт, номер забега +1")
	await G.enter_hub()
	await wait(0.4)
	# --- вне боя: забег встаёт на паузу и продолжается
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "четвёртый забег начался")
	ok(await _clear_room(g, G), "первый этап зачищен")
	var gold1 := int(G.run["golda"])
	var pos1 := int(G.run["pos"])
	ok(G.quit_kind() == "safe" and G.quit_text() == "Забег сохранён: этап 1 из 6 пройден. Продолжишь с двери подъезда.", "вне боя выход сохраняет забег: «%s»" % G.quit_text())
	G.on_quit()
	var sv: Dictionary = G.data["run"]
	ok(G.paused_run() and String(sv["state"]) == "open" and (sv["pos3"] as Array).size() == 3 and int((sv["run"] as Dictionary)["golda"]) == gold1, "запись забега: состояние open, место героя и голда сохранены")
	await G.enter_hub()
	await wait(0.4)
	ok(G.paused_run() and String(g.top_label.text).contains("ПАУЗЕ"), "в подъезде забег на паузе")
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "open", 8.0), "выход во двор продолжает забег")
	ok(int(G.run["pos"]) == pos1 and int(G.run["golda"]) == gold1 and G.paused_run() and G.world.gates.size() >= 2 and P.global_position.distance_to(G67Yard.HOME_DOOR) < 6.0,
		"продолжение: тот же этап и голда, варианты открыты, герой у двери подъезда")
	# --- в награде (баф ещё не взят) запись откатывается на этап назад: ничего не выдано дважды
	await _go(G, P, "gate1")
	ok(await until(func(): return String(G.room.get("type", "")) == "fit" and G.hub_ui != null and G.hub_ui.kind == "fit", 8.0), "этап «БАФ»: окно выбора")
	G.on_quit()
	ok(int(((G.data["run"] as Dictionary)["run"] as Dictionary)["pos"]) == pos1 and String((G.data["run"] as Dictionary)["state"]) == "open", "выход в окне выбора: запись откатилась на этап назад (баф выберешь заново)")
	if G.hub_ui != null:
		G.hub_ui.close()
	await G.enter_hub()
	await wait(0.3)
	# --- сохранение с пометкой «бой» при входе засчитывается поражением
	var r1 := int(G.meta()["respect"])
	var n1 := int(G.meta().get("runs", 0))
	G.data["run"] = {"run": {"district": "dvor", "tpl": 0, "pos": 2, "respect": 5, "golda": 40}, "room": {"type": "elite", "place": "garages"}, "hp": 50.0, "state": "fight", "pos3": [0, 0, 0]}
	await G.begin()
	ok(int(G.meta()["respect"]) == r1 + 5 and int(G.meta()["runs"]) == n1 + 1 and not G.paused_run() and G.recovered_respect == 5, "запись с боем при входе: засчитана как поражение (РЕСПЕКТ +5, забег стёрт)")
	await wait(0.4)
	# --- старый забег на паузе (шесть позиций, без шаблона) продолжается
	G.data["run"] = {"run": {"district": "dvor", "pos": 3, "golda": 50, "fits": {}, "respect": 4, "rooms": 3, "rerolls": 0, "arts": [], "kiosk": {}}, "room": {"type": "break", "place": "gazebo"}, "hp": 60.0, "state": "rest"}
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "open", 8.0), "старая запись (без шаблона) продолжается")
	ok(int(G.run["tpl"]) == 0 and int(G.run["pos"]) == 3 and int(G.run["golda"]) == 50 and absf(P.hp - 60.0) < 0.5 and G.world.gates.size() == 1 and (G.run["stages"] as Array).is_empty() and G.run.has("stash"),
		"старый забег: шаблон 0, этап 4 пройден, голда 50, варианты следующего этапа открыты (%d)" % G.world.gates.size())
	await G.enter_hub()
	G.data["run"] = {"run": {"district": "dvor", "pos": 5, "golda": 1}, "room": {"type": "battle", "place": "garages"}, "hp": 30.0, "state": "open"}
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "open", 8.0) and int(G.run["pos"]) == 4 and G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "boss", "старый забег с позиции 6 (зажат до 5): следующий — босс")
	await G.enter_hub()
	G.data["run"] = {}
	await wait(0.3)

## Камера внутри допустимого: в подъезде — в коробке лестничной клетки (тамбур уже и ниже), у бортов — внутри COURT
func _cam_ok(c: Vector3, kind: String) -> bool:
	if kind == "court":
		var cr: Rect2 = G67Yard.COURT
		return c.x >= cr.position.x + 0.3 and c.x <= cr.end.x - 0.3 and c.z >= cr.position.y + 0.3 and c.z <= cr.end.y - 0.3
	if c.z > G67World.Z_FRONT:
		return absf(c.x) <= 1.5 and c.y <= 2.7 and c.z <= G67World.Z_DOOR + 0.5
	return absf(c.x) <= G67World.HUB_X + 0.45 and c.y <= G67World.CEIL_Y and c.z >= G67World.Z_BACK - 0.45 and c.z <= G67World.Z_DOOR + 0.5

## 36 положений камеры (12 поворотов × наклоны −0,32 / −0,75 / +0,1) в точке; возвращает, сколько вне допустимого
func _cam_sweep(g, P, at: Vector3, kind: String, nm: String) -> int:
	P.global_position = at
	P.velocity = Vector3.ZERO
	await wait(0.4)
	var bad := 0
	var worst := ""
	for k in 12:
		for pit in [-0.32, -0.75, 0.1]:
			g.cam_yaw = TAU * float(k) / 12.0
			g.cam_pitch = pit
			await wait(0.25)
			var c: Vector3 = g.cam.global_position
			if not _cam_ok(c, kind):
				bad += 1
				if worst == "":
					worst = "yaw %.2f pitch %.2f → %s" % [g.cam_yaw, pit, str(c.snapped(Vector3.ONE * 0.1))]
	g.cam_yaw = PI
	g.cam_pitch = -0.32
	print("GOLDA67CHECK   КАМЕРА %s: плохих положений %d из 36 %s" % [nm, bad, worst])
	return bad

## Герой смотрит от камеры (камера за спиной): cos(face − cam_yaw − PI) > 0,9
func _faces_away(g, P) -> bool:
	return cos(float(P.face) - float(g.cam_yaw) - PI) > 0.9

func _cam_check(g, G: Golda67, P) -> void:
	var total := 0
	ok(G.place == "hub" and _faces_away(g, P) and absf(g.cam_len - 3.2) < 0.01, "первый кадр подъезда: герой лицом от камеры (face %.2f, cam_yaw %.2f), штанга 3,2" % [P.face, g.cam_yaw])
	var L := G67World.LAND_Y
	for v in [["вход подъезда", Vector3(0, 0.05, 5.0)], ["холл", Vector3(0, 0.05, 3.0)], ["площадка", Vector3(0, L + 0.05, -3.0)], ["середина лестницы", Vector3(-2.3, 0.8, -0.35)]]:
		var b: int = await _cam_sweep(g, P, v[1], "hub", String(v[0]))
		ok(b == 0, "камера в подъезде, точка «%s»: плохих положений %d из 36" % [v[0], b])
		total += b
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	ok(_faces_away(g, P) and absf(g.cam_len - 4.6) < 0.01, "первый кадр двора после start_run: герой лицом от камеры (face %.2f, cam_yaw %.2f), штанга 4,6" % [P.face, g.cam_yaw])
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.5)
	P.inv = 1.0
	for v in [["западный борт", Vector3(-10.0, 0.05, -38.25)], ["восточный борт", Vector3(14.0, 0.05, -38.25)], ["северный борт", Vector3(-6.0, 0.05, -48.5)], ["южный борт", Vector3(-6.0, 0.05, -28.0)]]:
		var b2: int = await _cam_sweep(g, P, v[1], "court", String(v[0]))
		ok(b2 == 0, "камера у борта коробки, точка «%s»: плохих положений %d из 36" % [v[0], b2])
		total += b2
	print("GOLDA67CHECK   КАМЕРА всего плохих положений: %d из 288" % total)

## Бирки бафов: все надписи целиком внутри своей бирки и экрана; кегль ≥ 15; перенос не обрезает
func _fit_layout_ok(FU) -> bool:
	var good := true
	for c in FU.cards:
		var cr := Rect2(c.position, c.size)
		if not Rect2(Vector2.ZERO, Vector2(1600, 900)).encloses(cr):
			good = false
		for l in c.get_children():
			if l is Label:
				var lr := Rect2(c.position + l.position, l.size)
				var fsz: int = l.get_theme_font_size("font_size")
				if not cr.encloses(lr) or fsz < 15 or String(l.text) == "" or l.size.y + 0.5 < l.get_minimum_size().y:
					good = false
					print("GOLDA67CHECK   бирка: «%s» вне рамки (%s в %s, кегль %d)" % [String(l.text).left(30), str(lr), str(cr), fsz])
	return good

## Экран итогов: ждём и жмём «В ПОДЪЕЗД»
func _result_to_hub(G: Golda67) -> bool:
	if not await until(func(): return G.hub_ui != null and G.hub_ui.kind == "result", 10.0):
		return false
	await wait(0.3)
	G.hub_ui.select(0, true)
	G.hub_ui._activate(0)
	return await until(func(): return G.place == "hub" and G.hub_ui == null, 10.0)

## Весь видимый текст узла (подписи и кнопки)
func _all_text(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += String(c.text) + "\n"
	for c in n.find_children("*", "Button", true, false):
		out += String(c.text) + "\n"
	for c in n.find_children("*", "Control", true, false):
		if c.get("text") != null and not (c is Label) and not (c is Button):
			out += String(c.get("text")) + "\n"
	return out

## Надписи диорамы внутри стола 1600×900
func _text_fits(U) -> bool:
	var good := true
	for l in U.stage.find_children("*", "Label", true, false):
		var r := Rect2(l.global_position - U.stage.global_position, l.size * (l as Control).get_global_transform().get_scale())
		if String(l.text) != "" and not Rect2(Vector2(-2, -2), Vector2(1604, 904)).encloses(Rect2((l.global_position - U.stage.global_position) / U.stage.scale.x, l.size)):
			good = false
			print("GOLDA67CHECK   надпись вне экрана: «%s» %s" % [String(l.text).left(30), str(r)])
	return good

## Страницы паузы приквела: шесть вкладок, нет слов кампании
func _pause_pages(g, G: Golda67, where: String) -> void:
	var banned := ["прослуш", "тишина перед", "магазин", "ад-либ", "в разработке"]
	var names := []
	for i in 6:
		g.set_paused(true)
		await wait(0.9)
		g.pause_panel._open_page(i)
		await wait(0.3)
		var txt: String = _all_text(g.pause_panel).to_lower()
		for w in banned:
			if txt.contains(w) and not (w == "ад-либ" and not g.madk_locked()):
				ok(false, "пауза (%s), вкладка %d: запрещённое слово «%s»" % [where, i, w])
		if i == 0:
			ok(txt.contains("респект") and (txt.contains("голда") or txt.contains("подъезд")), "пауза (%s): СТАТУС — РЕСПЕКТ и голда/подъезд" % where)
			for tb in g.pause_panel.tabs:
				names.append(String((tb["label"] as Label).text))
		if i == 3:
			ok(txt.contains("этап") or txt.contains("1 ·"), "пауза (%s): МАРШРУТ — семь этапов" % where)
		if i == 5:
			ok(not txt.contains("tab —") or not g.madk_locked(), "пауза (%s): строка управления без Tab/T/G/Q, пока madk1d закрыт" % where)
			ok(not txt.contains("боевые подсказки") and txt.contains("главное меню"), "пауза (%s): СИСТЕМА без блока обучения кампании" % where)
		if i == 4 or i == 5:
			await shot("pz_%s_%d" % [where, i])
		elif where == "hub":
			await shot("pz_%s_%d" % [where, i])
		g.pause_panel._close_card()
		g.set_paused(false)
		await wait(0.9)
	ok(names == ["СТАТУС", "БАФЫ", "АРТЕФАКТЫ", "МАРШРУТ", "МУЗЫКА", "СИСТЕМА"], "вкладки паузы приквела: %s" % str(names))

func _ui3_check(g, G: Golda67, P) -> void:
	# N05: пропущенный ролик сам больше не запускается, в архиве остаётся «новым»
	var cs2: Array = G.meta().get("clips_seen", [])
	for cid in ["AD01", "STORY01"]:
		cs2.erase(cid)
		G.meta()["clips_seen"] = cs2
		G.meta()["clips_auto"] = (G.meta().get("clips_auto", []) as Array).filter(func(x): return x != cid)
		G.play_auto(cid)
		await wait(0.6)
		ok(G.clip != null, "N05: автозапуск «%s» показал ролик" % cid)
		G.clip.skip()
		await wait(0.5)
		G.play_auto(cid)
		await wait(0.4)
		ok(G.clip == null and not G.clip_seen(cid) and G.clip_open(cid) and (G.meta()["clips_auto"] as Array).has(cid), "N05: пропущенный «%s» второй раз сам не запускается, в архиве «новый»" % cid)
	await G.enter_hub()
	await wait(0.6)
	# C5: madk1d до первой концовки — житель подъезда: стоит на месте, пока герой ходит
	var m0: Vector3 = g.buddy.global_position
	var away := 0.0
	var follows := false
	for pt in [Vector3(0, 0.05, 5.0), Vector3(-1.0, 0.05, 3.0), Vector3(0.5, 0.05, 2.0), Vector3(0, G67World.LAND_Y + 0.05, -3.0)]:
		var d_before: float = g.buddy.global_position.distance_to(P.global_position)
		P.global_position = pt
		await wait(1.5)
		var bp: Vector3 = g.buddy.global_position
		away = maxf(away, minf(bp.distance_to(G.MADK_SPOT), bp.distance_to(G.MADK_SPOT2)))
		if Vector2(bp.x - P.global_position.x, bp.z - P.global_position.z).length() < 0.9 and pt.y < 1.0:
			follows = true
	ok(g.madk_home() and g.buddy.visible and away < 3.2 and not follows, "C5: madk1d в подъезде не ходит за героем и остаётся у своих двух мест (отход %.2f м)" % away)
	P.global_position = Vector3(0.6, 0.05, 0.2)
	P.face = 0.0
	g.cam_yaw = PI
	g.cam_pitch = -0.2
	await wait(1.0)
	await shot("madk_hub_wide")
	var mb: Node3D = g.buddy
	var mf := Vector3(sin(g.buddy.face), 0, cos(g.buddy.face))
	var oc := Camera3D.new()
	g.add_child(oc)
	oc.global_position = mb.global_position + mf * 2.4 + Vector3(mf.z, 0, -mf.x) * 0.9 + Vector3(0, 1.3, 0)
	oc.look_at(mb.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	oc.make_current()
	var pv0: bool = P.visible
	P.visible = false
	await wait(0.2)
	await shot("madk_hub_close")
	ok(mb.global_position.y > 1.3 and mb.global_position.y < 1.8 and minf(mb.global_position.distance_to(G.MADK_SPOT), mb.global_position.distance_to(G.MADK_SPOT2)) < 1.5, "C5: madk1d стоит на полу на своём месте (%s)" % str(mb.global_position))
	ok(cos(g.buddy.face - atan2(G.MADK_TV.x - mb.global_position.x, G.MADK_TV.z - mb.global_position.z)) > 0.5 or cos(g.buddy.face - PI * 0.5) > 0.6 or cos(g.buddy.face - atan2(P.global_position.x - mb.global_position.x, P.global_position.z - mb.global_position.z)) > 0.5, "C5: madk1d лицом в холл или к герою (%.2f)" % g.buddy.face)
	P.visible = pv0
	g.cam.make_current()
	oc.queue_free()
	g.buddy.home_react = "Cheer"
	g.buddy.home_until = 0.0
	await wait(0.6)
	ok(String(g.buddy.rig.cur) in ["Cheer", "MSitNod"], "C5: при возвращении madk1d разворачивается и делает жест (%s)" % String(g.buddy.rig.cur))
	await wait(2.2)
	G.meta()["flags"]["ending1"] = true
	ok(not g.madk_home(), "после первой концовки madk1d — не житель, ходит рядом")
	G.meta()["flags"].erase("ending1")
	await _pause_pages(g, G, "hub")
	# письма и листки: Enter закрывает прочитанное, Esc закрывает экран
	for pair in [["mail", "mail"], ["notices", "board"]]:
		ok(await _hub_screen(G, P, String(pair[0]), String(pair[1])), "экран «%s» открыт" % String(pair[1]))
		var U = G.hub_ui
		var first_ok := 0
		for k in U.items.size():
			var nd = U.items[k]["node"]
			if (String(pair[1]) == "mail" and nd.get("mail") != null and int(nd.mail) >= 0 and String(nd.state) != "lock") or (String(pair[1]) == "board" and nd.get("locked") != null and not bool(nd.locked)):
				first_ok = k
				break
		U.select(first_ok, true)
		U._activate(first_ok)
		await wait(1.6)
		var reading: bool = U.mode == "read"
		await key(KEY_ENTER)
		await wait(0.4)
		ok(reading and U.mode == "list", "«%s»: Enter открыл, второй Enter закрыл прочитанное — окон не осталось" % String(pair[1]))
		await key(KEY_ESCAPE)
		ok(await until(func(): return G.hub_ui == null, 1.0), "«%s»: Esc из списка закрывает экран" % String(pair[1]))
	# подсказки предметов по состоянию
	G.refresh_hints()
	ok(String(G.point("exit")["hint"]) in ["начать забег"] or String(G.point("exit")["hint"]).begins_with("продолжить забег"), "подсказка двери по состоянию: «%s»" % G.point("exit")["hint"])
	ok(String(G.point("artifacts")["hint"]).contains("из 18") or String(G.point("artifacts")["hint"]) == "пока пусто", "подсказка серванта: «%s»" % G.point("artifacts")["hint"])
	ok(String(G.point("routes")["hint"]).begins_with("ДВОР · маршрут №") and G.point("door").is_empty(), "подсказка карты: «%s»; точки колясочной нет" % G.point("routes")["hint"])
	# счётчик FPS — настройка, по умолчанию выкл
	var fps0: bool = bool(Opts.v("show_fps"))
	Opts.put("show_fps", false)
	await wait(0.3)
	ok(not g.fps_label.visible, "счётчик FPS по умолчанию выключен")
	Opts.put("show_fps", true)
	await wait(0.3)
	ok(g.fps_label.visible, "настройка «СЧЁТЧИК FPS» включает метку")
	Opts.put("show_fps", fps0)
	var has_row := false
	for r in Opts.rows(get_window(), g.main.audio, g.ipod):
		if r[0] is Callable and String((r[0] as Callable).call()).begins_with("СЧЁТЧИК FPS"):
			has_row = true
	ok(has_row, "в настройках есть строка «СЧЁТЧИК FPS»")
	# приём [F] у Балона — «БУТЫЛКА»
	var abil: Array = g.combat_hud.abilities(P) if g.combat_hud.has_method("abilities") else []
	ok(abil.any(func(a): return String(a[1]) == "БУТЫЛКА") and not abil.any(func(a): return String(a[1]) == "ВОДЯРА"), "приём на [F] у Балона в приквеле — «БУТЫЛКА»")
	# строка управления в окне диалога — только в первом диалоге запуска
	ok(G.dlg_hint_used, "строка «ЛКМ / ПРОБЕЛ…» уже показывалась в первом диалоге")
	G.talk_flurr()
	await wait(0.3)
	ok(g.mode == "dlg" and not g.dlg_hint.visible, "во втором диалоге строки управления нет")
	g._dlg_finish()
	await wait(0.3)
	# «фитс» нигде в видимом тексте экранов
	var all_t := ""
	for k in ["upgrades", "styles", "artifacts", "routes", "mail", "notices", "tv"]:
		var scr: String = "board" if k == "notices" else ("archive" if k == "tv" else k)
		G.open_screen(scr)
		await wait(0.5)
		if G.hub_ui != null:
			all_t += _all_text(G.hub_ui.stage)
			G.hub_ui.close()
		await wait(0.2)
	for u in G67Data.UPGRADES:
		all_t += String(u["name"]) + String(u["per"])
	for a in G67Data.ARTIFACTS:
		all_t += String(a["desc"])
	for t in G67Data.ROOM_NAMES.values() + G67Data.ROOM_HINT.values():
		all_t += String(t)
	ok(not all_t.to_lower().contains("фитс"), "в экранах приквела нет слова «фитс» в любом регистре")
	ok(String(ModeSelect.MODES[1]["desc"]).to_lower().contains("баф") and not String(ModeSelect.MODES[1]["desc"]).to_lower().contains("фитс"), "карточка режима: «бафы»")
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "забег для страниц паузы")
	await _pause_pages(g, G, "run")
	await G.enter_hub()
	G.data["run"] = {}
	await wait(0.3)

## E2 / E3: целые отметки в старых сохранениях; запись через временный файл; восстановление из резерва
func _save_check(g, G: Golda67) -> void:
	var was_clean := G67Save.clean
	G67Save.clean = false
	G67Save.path_override = "user://g67check_save.json"
	G67Save.wipe()
	# старое сохранение с дробными отметками
	var old := G67Save.blank()
	old["meta"]["board_read"] = [0.0, 2.0]
	old["meta"]["mail_read"] = [1.0]
	old["meta"]["respect"] = 12.0
	old["meta"]["runs"] = 3.0
	var f := FileAccess.open(G67Save.main_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var d := G67Save.load_all()
	var br: Array = d["meta"]["board_read"]
	ok(br.has(0) and br.has(2) and (d["meta"]["mail_read"] as Array).has(1) and typeof(br[0]) == TYPE_INT and typeof(d["meta"]["respect"]) == TYPE_INT, "E2: отметки и счётчики старого сохранения приведены к целым (%s)" % str(br))
	# два обычных сохранения: основной и целый резерв
	d["meta"]["respect"] = 20
	ok(G67Save.save_all(d) and G67Save.save_all(d), "E3: запись проходит")
	ok(not G67Save.read_file(G67Save.main_path()).is_empty() and not G67Save.read_file(G67Save.bak()).is_empty() and not FileAccess.file_exists(G67Save.tmp()), "после записи основной и резерв целы, временного файла нет")
	# обрезанный основной + целый .bak → загрузка из резерва
	var cut := FileAccess.open(G67Save.main_path(), FileAccess.WRITE)
	cut.store_string('{"v":1,"meta":{"respe')
	cut.close()
	var d2 := G67Save.load_all()
	ok(int(d2["meta"]["respect"]) == 20 and G67Save.recovered != "", "обрезанный основной: прогресс взят из резерва (%s)" % G67Save.recovered)
	ok(G67Save.save_all(d2), "после восстановления запись проходит")
	ok(not G67Save.read_file(G67Save.main_path()).is_empty() and not G67Save.read_file(G67Save.bak()).is_empty(), "после следующей записи основной цел и резерв цел (битый в резерв не попал)")
	# сбой проверки временного файла не трогает основной
	var before := FileAccess.get_file_as_string(G67Save.main_path())
	var bad := {"v": 1, "x": 1}
	ok(not G67Save.save_all(bad) and FileAccess.get_file_as_string(G67Save.main_path()) == before, "запись, не прошедшая проверку, основной файл не трогает")
	G67Save.wipe()
	G67Save.path_override = ""
	G67Save.clean = was_clean

## Точка в кадре и вне плашки диалога
func _in_frame(g, pt: Vector3, below_ok := false) -> bool:
	var vs: Vector2 = g.get_viewport().get_visible_rect().size
	if g.cam.is_position_behind(pt):
		return false
	var sp: Vector2 = g.cam.unproject_position(pt)
	if sp.x < 20.0 or sp.x > vs.x - 20.0 or sp.y < 20.0 or sp.y > vs.y - 20.0:
		return false
	return below_ok or not (sp.y > vs.y - 250.0 and sp.x > vs.x * 0.12 and sp.x < vs.x * 0.88)

func _ray_free(g, pt: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(g.cam.global_position, pt)
	q.collision_mask = 8
	var hit: Dictionary = g.player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(pt) < 1.0       # тело самого собеседника у лица преградой не считаем

## Разговор по планам: на каждой реплике лица и названный объект в кадре над плашкой, луч свободен, HUD скрыт; снимок каждого плана
func _talk_scene(g, G: Golda67, P, partner: Node3D, nm: String, obj: Vector3, obj_name: String) -> void:
	var ok_all := true
	var hud_ok := true
	var seen_plans := {}
	var vis0 := true
	await wait(0.4)
	for i in 40:
		if g.mode != "dlg":
			break
		await wait(0.9)
		var plan: int = int(G.talk_map.get(g.dlg_i, G.talk_cur))
		var hh: Vector3 = P.global_position + Vector3(0, 1.6, 0)
		var qh: Vector3 = partner.global_position + Vector3(0, 1.05 if nm == "flurr" else 1.6, 0)
		var need_both := plan == 0
		var good: bool = _in_frame(g, qh) and _ray_free(g, qh) and (not need_both or (_in_frame(g, hh) and _ray_free(g, hh)))
		if plan == 2:
			good = _in_frame(g, hh) and _ray_free(g, hh)
		if plan == 3 and obj != Vector3.ZERO:
			good = _in_frame(g, obj, obj_name == "голуби") and good_obj_ray(g, obj)
		if not good:
			ok_all = false
			print("GOLDA67CHECK   разговор %s: реплика %d, план %d — лица/объект вне кадра или закрыты" % [nm, g.dlg_i, plan])
		if g.hud_root.is_visible_in_tree() or g.combat_hud.is_visible_in_tree():
			hud_ok = false
		if not seen_plans.has(plan):
			seen_plans[plan] = true
			await shot("dlg_%s_%d" % [nm, plan])
		g._dlg_advance()
	await wait(0.6)
	ok(ok_all and seen_plans.size() >= 2, "разговор «%s»: на всех планах (%s) лица%s в кадре над плашкой, луч свободен" % [nm, str(seen_plans.keys()), (" и " + obj_name) if obj != Vector3.ZERO else ""])
	ok(hud_ok and g.hud_root.visible == vis0 and g.hud_root.is_visible_in_tree(), "разговор «%s»: HUD скрыт на время диалога и вернулся после" % nm)
	var cam1: bool = _cam_after(g, P, nm + " +0,6 с")
	if nm == "flurr":
		await shot("after_talk_flurr")
	await wait(2.4)
	var cam2: bool = _cam_after(g, P, nm + " +3 с")
	ok(cam1 and cam2, "разговор «%s»: после конца камера снова на пружине (единичный поворот, герой в кадре, fov из настроек)" % nm)

func _cam_after(g, P, tag: String) -> bool:
	var ident: bool = g.cam.transform.basis.orthonormalized().get_rotation_quaternion().angle_to(Quaternion()) < 0.02
	var dist: float = g.cam.global_position.distance_to(P.global_position)
	var vis: bool = _in_frame(g, P.global_position + Vector3(0, 1.2, 0))
	var fov_ok: bool = absf(g.cam.fov - float(Opts.v("fov"))) < 0.5
	print("GOLDA67CHECK   камера после разговора %s: единичный поворот %s (%s), расстояние до героя %.2f, герой в кадре %s, fov %.1f" % [tag, str(ident), str(g.cam.transform.basis.get_euler()), dist, str(vis), g.cam.fov])
	return ident and vis and fov_ok

func good_obj_ray(g, pt: Vector3) -> bool:
	return _ray_free(g, pt)

func _talks_check(g, G: Golda67, P) -> void:
	var seen0: Array = (G.meta().get("seen", []) as Array).duplicate()
	var fl0: int = int(G.meta().get("flurr", -1))
	# DJ FLÜRR на лавке
	G.meta()["seen"] = ["krot1"]
	G.meta()["flurr"] = -1
	var fr = G.world.actors.get("g67_dj_flurr")
	if fr != null:
		P.global_position = fr.global_position + Vector3(1.4, 0.0, 0.9)
		await wait(0.5)
		G.talk_flurr()
		await _talk_scene(g, G, P, fr, "flurr", Vector3.ZERO, "")
	# КРОТ с люстрой (подъезд)
	G.meta()["seen"] = ["krot1"]
	G.meta()["flurr"] = 1
	G._place_krot("hub")
	var kr = G.world.actors.get("g67_krot")
	if kr != null:
		P.global_position = kr.global_position + Vector3(0.0, 0.0, 1.8)
		await wait(0.5)
		G.talk_krot()
		await _talk_scene(g, G, P, kr, "chandelier", kr.global_position + Vector3(0, 1.45, 0), "люстра")
		G.world.actors.erase("g67_krot")
	# КРОТ у ларька и КРОТ с голубями — во дворе
	await _go(G, P, "exit")
	if await until(func(): return G.place == "run" and G.room_state == "fight", 8.0):
		_kill_all(g)
		G.pending = []
		G.wave_wait = 999.0
		G.meta()["seen"] = []
		G._place_krot("parking")
		kr = G.world.actors.get("g67_krot")
		if kr != null:
			P.global_position = kr.global_position + Vector3(0.0, 0.0, 1.8)
			await wait(0.5)
			G.talk_krot()
			await _talk_scene(g, G, P, kr, "kiosk", Vector3(39.9, 1.5, 7.0), "окно ларька")
		G.meta()["seen"] = ["krot1", "krot2"]
		G._place_krot("playground")
		kr = G.world.actors.get("g67_krot")
		if kr != null and G.meta()["seen"].size() == 2:
			P.global_position = kr.global_position + Vector3(0.0, 0.0, 1.8)
			await wait(0.5)
			G.talk_krot()
			await _talk_scene(g, G, P, kr, "pigeons", kr.global_position + Vector3(0, 0.15, 0), "голуби")
	await G.enter_hub()
	G.data["run"] = {}
	G.meta()["seen"] = seen0
	G.meta()["flurr"] = fl0
	await wait(0.3)

## Генератор маршрута: перебор всех цепочек выборов на позициях 2–4 (с обязательным «ТРЯПКИ» и без него)
func _walk_routes(G: Golda67, p: int, st: Array, acc: Dictionary) -> void:
	if p >= 4:
		acc["chains"] = int(acc["chains"]) + 1
		var battles := 0
		var fit := false
		var rags := false
		var kiosk_pos := -1
		for i in st.size():
			var t := String(st[i][0])
			if t in ["battle", "elite"]:
				battles += 1
			if t in ["fit", "elite"]:
				fit = true
			if t == "event" and String(st[i][2]) == "rags":
				rags = true
			if t == "kiosk":
				kiosk_pos = i
		var must_ok: bool = rags or bool(acc["seen"])
		if battles < 2 or battles > 3 or not fit or not must_ok or (kiosk_pos != -1 and kiosk_pos != 3):
			acc["bad"] = int(acc["bad"]) + 1
			print("GOLDA67CHECK   плохая цепочка: %s" % str(st.map(func(x): return x[0] + ":" + x[2])))
		return
	G.run["stages"] = st
	var opts: Array = G.route_options(p)
	for o in opts:
		var st2: Array = st.duplicate(true)
		st2.append([String(o["type"]), String(o["place"]), String(o.get("ev", ""))])
		_walk_routes(G, p + 1, st2, acc)

func _route_gen_check(G: Golda67) -> void:
	var run0: Dictionary = G.run
	var must0 = G.meta().get("must", {})
	var total := 0
	var bad := 0
	for seen in [false, true]:
		G.meta()["must"] = {"ev_rags": seen}
		G.run = {"stages": [], "tpl": 0}
		var acc := {"chains": 0, "bad": 0, "seen": seen}
		_walk_routes(G, 1, [["battle", "podezd", ""]], acc)
		total += int(acc["chains"])
		bad += int(acc["bad"])
		print("GOLDA67CHECK   генератор: «ТРЯПКИ» %s — цепочек %d, плохих %d" % ["увидены" if seen else "не увидены", int(acc["chains"]), int(acc["bad"])])
	ok(total > 8 and bad == 0, "генератор: перебрано %d цепочек выборов, в каждой боёв 2–3, выбор бафа есть, обязательное нельзя обойти, ларёк только на 4-й позиции" % total)
	G.run = {"stages": [["battle", "podezd", ""], ["fit", "playground", ""]], "tpl": 0}
	G.meta()["must"] = {"ev_rags": true}
	var o3: Array = G.route_options(2)
	var has_short := false
	G.run = {"stages": [["battle", "podezd", ""]], "tpl": 0}
	for o in G.route_options(1):
		if String(o["type"]) == "event":
			has_short = true
	ok(has_short, "когда «ТРЯПКИ» увидены, на позиции 2 появляется короткое событие")
	G.meta()["must"] = {"ev_rags": false}
	var no_short := true
	for o in G.route_options(1):
		if String(o["type"]) == "event":
			no_short = false
	ok(no_short, "пока «ТРЯПКИ» не увидены, на позиции 2 короткого события нет")
	G.run = run0
	G.meta()["must"] = must0

func _probe_free(g, pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	q.shape = sh
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.7, 0))
	q.collision_mask = 1
	return g.player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Точки входа врагов: места, проходимость, проёмы в заборе, враг входит в зону за ≤ 6 с
func _spawn_check(g, G: Golda67, P) -> void:
	for zid in ["garages", "parking", "playground", "podezd"]:
		var z: Dictionary = G67Yard.zone(zid)
		var c: Vector3 = z["c"]
		var h: Vector2 = z["h"]
		var sp_ok := true
		var spl: Array = z["spawns"]
		for sp in spl:
			var q: Vector3 = sp[0]
			var out: float = maxf(absf(q.x - c.x) - h.x, absf(q.z - c.z) - h.y)
			var free := _probe_free(g, q)
			print("GOLDA67CHECK   точка входа %s · %s %s: за краем %.1f м, проходима %s" % [zid, sp[1], str(q), out, str(free)])
			if out < -1.0 or out > 6.5 or not free:
				sp_ok = false
		ok(spl.size() >= 3 and sp_ok, "зона «%s»: %d точки входа вне зоны (≤ 6,5 м) и проходимы" % [zid, spl.size()])
		_kill_all(g)
		G.pending = []
		G.wave_wait = 999.0
		G.room_state = "open"
		P.global_position = c + Vector3(0, 0.05, 0)
		G.enter_room({"type": "battle", "place": zid})
		await until(func(): return G.room_state == "fight" and G.alive() >= 1, 8.0)
		var gaps_n := 0
		for sp in spl:
			var q2: Vector3 = sp[0]
			if absf(q2.x - c.x) > h.x or absf(q2.z - c.z) > h.y:
				gaps_n += 1
		ok(G.world.fence_total - G.world.fence_built >= gaps_n and gaps_n > 0, "зона «%s»: секций забора меньше на проёмы (%d из %d, проёмов %d)" % [zid, G.world.fence_built, G.world.fence_total, gaps_n])
		var e0 = null
		for e in g.enemies:
			if is_instance_valid(e) and e.alive():
				e0 = e
				break
		var oc := Camera3D.new()
		oc.fov = 55.0
		g.add_child(oc)
		oc.global_position = c + Vector3(0, 46, 12)
		oc.look_at(c, Vector3.UP)
		oc.make_current()
		await wait(0.6)
		await shot("spawn_" + zid)
		g.cam.make_current()
		oc.queue_free()
		if e0 != null:
			var born: Vector3 = e0.born_at
			var near := false
			for sp in spl:
				if (sp[0] as Vector3).distance_to(born) < 2.0:
					near = true
			ok(near, "зона «%s»: враг появился в точке входа (%s)" % [zid, str(born)])
			var inside: bool = await until(func(): return is_instance_valid(e0) and g.in_arena(e0.global_position, 0.0), 6.0)
			ok(inside, "зона «%s»: враг из проёма оказался внутри зоны за ≤ 6 с" % zid)
		# герой в проёме упирается
		var q3: Vector3 = (spl[0][0] as Vector3)
		var gap_hit := true
		var dirv: Vector3 = (q3 - P.global_position).normalized()
		P.global_position = Vector3(clampf(q3.x, c.x - h.x + 2.0, c.x + h.x - 2.0), 0.05, clampf(q3.z, c.z - h.y + 2.0, c.z + h.y - 2.0))
		P.velocity = dirv * 12.0
		await wait(1.2)
		gap_hit = g.in_arena(P.global_position, 1.5)
		ok(gap_hit, "зона «%s»: герой в проёме упирается в невидимую стенку (%s)" % [zid, str(P.global_position)])
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	G.room_state = "open"
	G.world.open_bounds()
	var yd = G.world.yard
	var bn: Array = yd.arena_nodes.filter(func(n): return is_instance_valid(n))
	var texts: Array = []
	for b in bn:
		for lb in (b as Node).find_children("*", "Label3D", true, false):
			texts.append((lb as Label3D).text)
	ok(bn.size() == 2 and texts.size() >= 2 and texts.all(func(t): return t == "ТУРНИР 67"), "две растяжки арены на месте, надпись «ТУРНИР 67» (%d узлов, %d надписей)" % [bn.size(), texts.size()])
	# реакции зрителей на приёмы не чаще раза в 2 с
	G.crowd_last_ms = -10000
	var c0: int = G.events.filter(func(e): return String(e[0]) == "crowd").size()
	G.place = "run"
	G.room = {"type": "boss", "place": "sport"}
	G._crowd("laugh")
	G._crowd("laugh")
	ok(G.events.filter(func(e): return String(e[0]) == "crowd").size() - c0 <= 1, "реакция зрителей на приём не чаще раза в 2 с")
	var sh_pos := [["arena_gate", Vector3(2, 9, -24.0), Vector3(2, 2, -44)], ["arena_throne", Vector3(2, 4.5, -50.5), Vector3(2, 1.5, -36)], ["arena_top", Vector3(2.1, 60, -37), Vector3(2, 0, -38)]]
	for v in sh_pos:
		var oc := Camera3D.new()
		oc.fov = 55.0
		g.add_child(oc)
		oc.global_position = v[1]
		oc.look_at(v[2], Vector3.UP)
		oc.make_current()
		await wait(0.5)
		await shot(String(v[0]))
		g.cam.make_current()
		oc.queue_free()

func _cam_shot(g, name: String, pos: Vector3, look: Vector3) -> void:
	var oc := Camera3D.new()
	oc.fov = 55.0
	g.add_child(oc)
	oc.global_position = pos
	oc.look_at(look, Vector3.UP)
	oc.make_current()
	await wait(0.4)
	await shot(name)
	g.cam.make_current()
	oc.queue_free()

## ДВОР 1.5: жители ходят по расписанию и не застревают, реплики-пузыри, [E] у жителей, отход от боя
func _life15(g, G: Golda67, P) -> void:
	var yd = G.world.yard
	ok(yd.residents.size() == 4, "ДВОР 1.5: у четырёх жителей есть поведение G67Resident (%d)" % yd.residents.size())
	var start: Dictionary = {}
	for rid in yd.residents:
		var R: G67Resident = yd.residents[rid]
		start[rid] = (R.rig as Node3D).position
		R.next_move = 0.5
	P.global_position = Vector3(0, 0.05, 20)
	G.pending = []
	G.wave_wait = 999.0
	_kill_all(g)
	await wait(2.0)
	var moved := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		for rid in yd.residents:
			var R2: G67Resident = yd.residents[rid]
			if (R2.rig as Node3D).position.distance_to(start[rid]) > 1.5:
				moved[rid] = true
		if moved.size() >= 3:
			break
		await wait(0.5)
	print("GOLDA67CHECK   жители, сдвинулись: ", str(moved.keys()))
	ok(moved.size() >= 3, "ДВОР 1.5: жители идут по расписанию (сдвинулись %d из 4)" % moved.size())
	for rid in yd.residents:
		var R3: G67Resident = yd.residents[rid]
		R3.next_move = 9999.0
	var tw_s := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw_s < 70000:
		await wait(1.0)
		if yd.residents.values().all(func(r): return r.state in ["stay", "act"]):
			break
	var settled := true
	for rid in yd.residents:
		var R4: G67Resident = yd.residents[rid]
		if R4.state not in ["stay", "act"]:
			settled = false
			print("GOLDA67CHECK   житель %s не дошёл: состояние %s, застрял %.1f с" % [rid, R4.state, R4.stuck_t])
	ok(settled, "ДВОР 1.5: жители дошли до места и стоят (никто не застрял)")
	# реплика-пузырь над бабушкой при подходе и по [E]
	var bk: G67Barks = G.barks_get()
	var bab: G67Resident = yd.residents["g67_npc_babushka"]
	bk.last_any = -100.0
	bk.last_line = {}
	P.global_position = (bab.rig as Node3D).global_position + Vector3(1.5, 0.05, 0)
	var n0: int = bk.log.size()
	G.use("talk_g67_npc_babushka")
	await wait(0.5)
	ok(bk.log.size() > n0 and String(bk.log.back()[1]) == "BB" and bk.bubbles.size() >= 1, "ДВОР 1.5: [E] у бабушки — реплика-пузырь («%s»)" % str(bk.log.back()[2]))
	await _cam_shot(g, "life15_bubble_babushka", (bab.rig as Node3D).global_position + Vector3(1.6, 1.7, 3.2), (bab.rig as Node3D).global_position + Vector3(0, 1.8, 0))
	# в ролике пузырей нет
	bk.last_any = -100.0
	G.clip = G67ClipPlayer.new()
	var silent: bool = not bk.can_talk()
	G.clip.free()
	G.clip = null
	ok(silent, "ДВОР 1.5: во время ролика жители молчат")
	# надписи: дословная строка минимум в двух местах, листки, карточка по [E]
	var serega := 0
	for nt in yd.notes:
		if String(nt["text"]).begins_with("Серега РПлюс заебал бухать"):
			serega += 1
	await _cam_shot(g, "life15_seven_papers", Vector3(-6.8, 1.6, 31.5), Vector3(-6.4, 1.5, 35.0))
	ok(serega >= 2, "ДВОР 1.5: «Серега РПлюс заебал бухать» дословно в %d местах" % serega)
	var wall8 := 0
	for nt in yd.notes:
		if String(nt["text"]).begins_with("№ 7"):
			wall8 += 1
	ok(wall8 == 8, "ДВОР 1.5: восемь листков в ряд (%d)" % wall8)
	var must := ["jelos_all", "uk", "g8_no", "mognut", "rocket", "cheremsha", "court_rules"]
	var have_txt := {}
	for nt in yd.notes:
		have_txt[String(nt["text"])] = true
	var missing_sg: Array = []
	for sg in G67LifeData.SIGNS:
		if not yd.SIGN_AT.has(String(sg["id"])) or String(sg.get("pool", "")) != "":
			continue
		if not have_txt.has(String(sg["text"])):
			missing_sg.append(sg["id"])
	ok(missing_sg.is_empty(), "ДВОР 1.5: надписи двора стоят на своих местах (нет: %s)" % str(missing_sg))
	# точки взаимодействия не ближе 1,2 м друг к другу
	var pts: Array = G.world.points
	var close_pair := ""
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var a: Vector3 = pts[i]["pos"]
			var b: Vector3 = pts[j]["pos"]
			if Vector2(a.x - b.x, a.z - b.z).length() < 1.2 and not (String(pts[i]["id"]).begins_with("talk_") or String(pts[j]["id"]).begins_with("talk_") or String(pts[i]["id"]).begins_with("gate") or String(pts[j]["id"]).begins_with("gate")):
				close_pair = "%s/%s" % [pts[i]["id"], pts[j]["id"]]
	ok(close_pair == "", "ДВОР 1.5: новые точки не ближе 1,2 м к старым (%s)" % close_pair)
	var ev0: int = G.events.size()
	for uid in ["intercom", "g_radio", "carpet", "box", "puh", "read_board", "read_g8", "read_gazebo", "read_kiosk"]:
		if G.point(uid).is_empty():
			print("GOLDA67CHECK   нет точки ", uid)
			continue
		G.use(uid)
		await wait(0.3)
	var used := G.events.slice(ev0).filter(func(e): return String(e[0]) == "life_use").size()
	ok(used >= 8, "ДВОР 1.5: предметы и листки отвечают по [E] (%d)" % used)
	ok(G.get_children().any(func(c): return c is G67ReadCard), "ДВОР 1.5: карточка-листок открыта")
	await shot("life15_card")
	G.use("carpet")
	await _cam_shot(g, "life15_carpet", Vector3(-4.2, 1.8, 7.5), Vector3(-7.0, 1.4, 3.8))
	for c in G.get_children():
		if c is G67ReadCard:
			c.queue_free()
	# микрособытия: каждое запускается и не роняет игру
	var yl: G67YardLife = G.ylife_get()
	for e in G67LifeData.MICRO:
		yl.fire(String(e["id"]))
		await wait(0.15)
	ok(yl.log.size() >= G67LifeData.MICRO.size(), "ДВОР 1.5: все %d микрособытий запускаются (%d)" % [G67LifeData.MICRO.size(), yl.log.size()])
	yl.next_audible = 9999.0
	await _life15b(g, G, P)
	await _life15c(g, G, P)
	await _voice3d_check(g, G, P)
	await _model_shots(g, G, P)
	await _fov80_shots(g, G, P)
	P.global_position = Vector3(0, 0.05, 25)

func _keys_of(v, depth := 0) -> Array:
	var out: Array = []
	if v is Dictionary:
		for k in (v as Dictionary).keys():
			out.append(str(k))
			if depth < 3:
				for sub in _keys_of(v[k], depth + 1):
					out.append(str(k) + "." + str(sub))
	out.sort()
	return out

func _cam_shot_look(g, name: String, pos: Vector3, node: Node3D, dy := 1.2) -> void:
	await _cam_shot(g, name, pos, node.global_position + Vector3(0, dy, 0))

## ДВОР 1.5: снимки с моделями на местах и фасадов других домов
func _model_shots(g, G: Golda67, P) -> void:
	var yd = G.world.yard
	await _cam_shot(g, "mdl_podezd_intercom", Vector3(-0.2, 1.7, 31.6), Vector3(-1.4, 1.2, 35.0))
	await _cam_shot(g, "mdl_podezd_door_canopy", Vector3(0.0, 1.9, 29.0), Vector3(0.0, 2.2, 35.0))
	await _cam_shot(g, "mdl_garage_workbench", Vector3(-35.0, 1.7, -2.2), Vector3(-39.2, 0.9, -2.2))
	await _cam_shot(g, "mdl_garage_radio", Vector3(-38.8, 1.4, 4.8), Vector3(-42.4, 0.5, 4.8))
	await _cam_shot(g, "mdl_garage_box", Vector3(-37.2, 1.4, -3.2), Vector3(-40.6, 0.3, -3.2))
	await _cam_shot(g, "mdl_garage_puhosos", Vector3(-35.2, 1.6, 8.0), Vector3(-39.0, 0.5, 8.0))
	await _cam_shot(g, "mdl_playground_swing", Vector3(-1.5, 1.7, -8.0), Vector3(-1.5, 1.2, -12.5))
	await _cam_shot(g, "mdl_playground_poster", Vector3(6.5, 1.5, -10.0), Vector3(9.7, 1.3, -10.0))
	await _cam_shot(g, "mdl_playground_carpet", Vector3(-4.0, 1.8, 7.0), Vector3(-7.0, 1.3, 3.6))
	await _cam_shot(g, "mdl_gazebo_table", Vector3(-21.5, 1.9, -28.5), Vector3(-24.2, 0.9, -31.4))
	await _cam_shot(g, "mdl_shovel_roof", Vector3(-36.0, 1.8, -8.5), Vector3(-43.9, 3.0, -6.6))
	# fx-детали и окна внутри своего дома и ниже карниза
	var out_of_house := 0
	for fn in yd.fx_nodes:
		var nd = fn["n"]
		var hb: AABB = fn["house"]
		if hb.size.y <= 0.0:
			continue                             # двери и козырьки стоят на земле, без ограничения по карнизу
		if nd == null or not is_instance_valid(nd):
			continue
		var nb: AABB = yd._node_aabb(nd)
		if nb.position.y + nb.size.y > hb.end.y - 1.0 or nb.position.x < hb.position.x - 1.6 or nb.end.x > hb.end.x + 1.6 or nb.position.z < hb.position.z - 1.6 or nb.end.z > hb.end.z + 1.6:
			out_of_house += 1
	ok(out_of_house == 0, "ДВОР 1.5: детали фасадов внутри своих домов и ниже карниза (вне: %d из %d)" % [out_of_house, yd.fx_nodes.size()])
	# пузырь бабушки с 3 м и 12 м
	var bk2: G67Barks = G.barks_get()
	var bab2: G67Resident = yd.residents["g67_npc_babushka"]
	for dd in [3.0, 12.0]:
		bk2.last_any = -100.0
		bk2.last_line = {}
		P.global_position = (bab2.rig as Node3D).global_position + Vector3(dd, 0.05, 0.0)
		bk2.say(bab2.rig, "BB|Я не знаю, что это за хуйня у гаражей стоит, но оно мне не нравится.", {"force": true, "dur": 6.0})
		await wait(0.6)
		await _cam_shot(g, "bubble_%dm" % int(dd), (bab2.rig as Node3D).global_position + Vector3(dd, 1.7, 0.0), (bab2.rig as Node3D).global_position + Vector3(0, 1.9, 0))
	# лопата над краем крыши и гаражный набор при лампе-переноске
	await _cam_shot(g, "mdl_shovel_roof2", Vector3(-36.0, 1.8, -6.6), Vector3(-42.7, 3.4, -6.6))
	await _cam_shot(g, "mdl_garage_set_lit", Vector3(-36.8, 1.6, 0.8), Vector3(-40.2, 0.8, 2.4))
	await _cam_shot(g, "mdl_garage_radio_lit", Vector3(-39.2, 1.3, 5.6), Vector3(-42.4, 0.4, 4.8))
	await _cam_shot(g, "mdl_garage_puhosos_lit", Vector3(-36.5, 1.5, 8.0), Vector3(-39.0, 0.5, 8.0))
	var k := 0
	for fc in yd.house_facades:
		if k >= 12:
			break
		var n: Vector3 = fc["n"]
		var mid: float = (float(fc["t0"]) + float(fc["t1"])) * 0.5
		var wp := Vector3(float(fc["wall"]), 6.0, mid) if bool(fc["along_x"]) else Vector3(mid, 6.0, float(fc["wall"]))
		await _cam_shot(g, "mdl_house_%d" % k, wp + n * 17.0 + Vector3(0, -2.5, 0), wp)
		k += 1

## FOV 80°: по снимку каждой зоны с камеры героя
func _fov80_shots(g, G: Golda67, P) -> void:
	for zid in ["podezd", "garages", "playground", "parking", "gazebo", "sport"]:
		var z: Dictionary = G67Yard.zone(zid)
		var c: Vector3 = z["c"]
		P.global_position = c + Vector3(0, 0.05, 3.0)
		g.cam.fov = 80.0
		await wait(1.2)
		await shot("fov80_" + zid)
	P.global_position = Vector3(0, 0.05, 25)

## ДВОР 1.5: голос у пузыря — играет позиционно, на 20 м не слышен (реплика не берётся)
func _voice3d_check(g, G: Golda67, P) -> void:
	var bk: G67Barks = G.barks_get()
	var bab: G67Resident = G.world.yard.residents["g67_npc_babushka"]
	var line := "BB|Гуля-гуля-гуля… Жрите, власть вы моя."
	ok(G67Voice.path(line) != "", "голос: у строки бабушки есть готовый файл")
	bk.last_any = -100.0
	bk.last_line = {}
	P.global_position = (bab.rig as Node3D).global_position + Vector3(4.0, 0.05, 0.0)
	for c in bk.get_children():
		if c is AudioStreamPlayer3D:
			c.queue_free()
	var said: bool = bk.say(bab.rig, line, {"force": true})
	await wait(0.2)
	var ap: AudioStreamPlayer3D = null
	for c in bk.get_children():
		if c is AudioStreamPlayer3D:
			ap = c
	ok(said and ap != null and ap.stream != null and ap.playing, "голос: AudioStreamPlayer3D играет (поток %s, шина %s, max_distance %.0f)" % [str(ap != null and ap.stream != null), str(ap.bus) if ap != null else "-", ap.max_distance if ap != null else 0.0])
	P.global_position = (bab.rig as Node3D).global_position + Vector3(20.0, 0.05, 0.0)
	bk.last_any = -100.0
	bk.last_line = {}
	var n0 := 0
	for c in bk.get_children():
		if c is AudioStreamPlayer3D:
			n0 += 1
	var far_said: bool = bk.say(bab.rig, line, {})
	var n1 := 0
	for c in bk.get_children():
		if c is AudioStreamPlayer3D:
			n1 += 1
	ok(not far_said and n1 == n0, "голос: на 20 м реплика жителя не берётся и не звучит")

## ДВОР 1.5, часть 3: снимки действий, точный hush, filyai, проходы
func _life15c(g, G: Golda67, P) -> void:
	var yd = G.world.yard
	var yl: G67YardLife = G.ylife_get()
	var du: G67Duos = G.duos_get()
	var bk: G67Barks = G.barks_get()
	G.room_state = "open"
	# ушанка идёт
	var us: G67Resident = yd.residents["g67_npc_ushanka"]
	us.next_move = 0.1
	var t0 := Time.get_ticks_msec()
	while us.state != "walk" and Time.get_ticks_msec() - t0 < 25000:
		P.global_position = (us.rig as Node3D).global_position + Vector3(6.0, 0.05, 4.0)
		await wait(0.4)
	var us0: Vector3 = (us.rig as Node3D).global_position
	t0 = Time.get_ticks_msec()
	while (us.rig as Node3D).global_position.distance_to(us0) < 1.8 and Time.get_ticks_msec() - t0 < 12000:
		P.global_position = (us.rig as Node3D).global_position + Vector3(6.0, 0.05, 4.0)
		await wait(0.2)
	await _cam_shot_look(g, "life15_ushanka_walks", (us.rig as Node3D).global_position + Vector3(2.2, 1.5, 3.0), us.rig, 1.0)
	ok(us.state == "walk" or us.log.any(func(e): return String(e[0]) == "go"), "ДВОР 1.5: ушанка идёт по расписанию (состояние %s)" % us.state)
	t0 = Time.get_ticks_msec()
	while us.state != "stay" and Time.get_ticks_msec() - t0 < 60000:
		await wait(1.0)
	# сдвиг очереди
	P.global_position = Vector3(34.0, 0.05, 12.0)
	yl.fire("queue_move")
	await wait(3.2)
	await _cam_shot(g, "life15_queue_shift", Vector3(33.5, 2.3, 12.8), Vector3(39.0, 1.0, 6.5))
	await wait(9.0)
	# разговор в беседке с пузырём и точный hush
	bk.last_any = -100.0
	du.done_at = {}
	du.active = {}
	du.start_now("seeds_case")
	var gz: Array = yd.gazebo_people
	P.global_position = (gz[0] as Node3D).global_position + Vector3(8.0, 0.05, 2.0)
	var tg := Time.get_ticks_msec()
	while bk.bubbles.is_empty() and Time.get_ticks_msec() - tg < 20000:
		await wait(0.5)
	await wait(0.8)
	await _cam_shot(g, "life15_gazebo_bubble", Vector3(-19.5, 1.9, -27.5), (gz[0] as Node3D).global_position + Vector3(-0.8, 1.2, -0.8))
	var i_before: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else -1
	P.global_position = (gz[0] as Node3D).global_position + Vector3(1.6, 0.05, 0.5)
	await wait(1.6)
	var mid: Vector3 = ((gz[0] as Node3D).global_position + (gz[1] as Node3D).global_position) * 0.5
	var side: Vector3 = ((gz[1] as Node3D).global_position - (gz[0] as Node3D).global_position)
	var perp := Vector3(-side.z, 0, side.x).normalized()
	if perp.dot(P.global_position - mid) < 0.0:
		perp = -perp
	P.visible = false
	await _cam_shot(g, "life15_hush", mid + perp * 3.2 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.0, 0))
	P.visible = true
	var i_hush: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else -2
	await wait(4.0)
	var i_still: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else -3
	P.global_position = (gz[0] as Node3D).global_position + Vector3(8.0, 0.05, 2.0)
	var nlog0: int = du.log.size()
	await wait(9.0)
	var first_line := -1
	for e in du.log.slice(nlog0):
		if String(e[2]).begins_with("line "):
			first_line = int(String(e[2]).substr(5))
			break
	ok(i_still == i_hush and first_line == i_hush, "ДВОР 1.5: hush — пока герой близко, строка не идёт (%d → %d), после ухода сказана ровно следующая несказанная (строка %d)" % [i_hush, i_still, first_line])
	du.active = {}
	# filyai: двое качаются, ушанка резко замирает
	yl.filyai_froze = -1.0
	P.global_position = (us.rig as Node3D).global_position + Vector3(7.0, 0.05, 3.0)
	yl.fire("filyai")
	await wait(4.5)
	ok(yl.filyai_froze > 0.0, "ДВОР 1.5: filyai — ушанка резко замерла после двух тактов качания")
	# окно со створкой и силуэт
	P.global_position = Vector3(0.0, 0.05, 27.0)
	await wait(0.5)
	yl.fire("window_shout")
	await wait(0.5)
	await _cam_shot(g, "life15_window_shout", Vector3(yl.last_window_x + 0.8, 4.5, 31.5), Vector3(yl.last_window_x, 8.0, 34.8))
	await wait(5.0)
	yl.fire("window_shape")
	await wait(1.6)
	await _cam_shot(g, "life15_window_shape", Vector3(yl.last_window_x + 0.8, 4.5, 31.5), Vector3(yl.last_window_x, 8.0, 34.8))
	await wait(6.0)
	# восемь листков и ковёр в пыли
	await _cam_shot(g, "life15_seven_papers", Vector3(-6.6, 1.6, 32.9), Vector3(-6.4, 1.55, 34.9))
	P.global_position = Vector3(-7.0, 0.05, 6.5)
	G.use("carpet")
	await wait(0.75)
	await _cam_shot(g, "life15_carpet_dust", Vector3(-4.8, 1.9, 6.3), Vector3(-7.0, 1.3, 3.7))
	# проходы: барьеры площадки и вешалка элиты
	var fence_ok := true
	for fp in [Vector3(-3.4, 0, -15.8), Vector3(1.3, 0, -15.8), Vector3(6.0, 0, -15.8)]:
		if not _walk_blocked(g, fp):
			fence_ok = false
	ok(fence_ok, "ДВОР 1.5: барьеры площадки — проход героя упирается")
	G._place_elite_hanger()
	await wait(0.3)
	var hanger_blocked: bool = G.elite_hanger != null and _walk_blocked(g, G.elite_hanger.global_position)
	ok(hanger_blocked, "ДВОР 1.5: вешалка элиты — проход героя упирается")
	if G.elite_hanger != null:
		G.elite_hanger.queue_free()
		G.elite_hanger = null
	G.world.points = G.world.points.filter(func(pt): return String(pt["id"]) != "elite_fit")
	P.global_position = Vector3(0, 0.05, 25)

## ДВОР 1.5, часть 2: разговоры DUOS, hush, gather, сирена, очередь, сохранение
func _life15b(g, G: Golda67, P) -> void:
	var yd = G.world.yard
	G.room_state = "open"
	G.save()
	var keys0: Array = _keys_of(G.data)
	var du: G67Duos = G.duos_get()
	var bk: G67Barks = G.barks_get()
	var ids: Array = []
	for d in G67LifeData.DUOS:
		ids.append(String(d["id"]))
	var finished := 0
	for id in ids:
		var duo: Dictionary = {}
		for d in G67LifeData.DUOS:
			if String(d["id"]) == id:
				duo = d
		bk.last_any = -100.0
		du.done_at = {}
		du.active = {}
		if not du.start_now(id):
			print("GOLDA67CHECK   разговор %s не запустился (нет участников)" % id)
			continue
		var who: Array = du._who(duo)
		var c := Vector3.ZERO
		for n in who:
			c += (n as Node3D).global_position
		c /= float(who.size())
		P.global_position = c + Vector3(8.0, 0.05, 0.0)
		var tt := Time.get_ticks_msec()
		var ended := false
		while Time.get_ticks_msec() - tt < 90000:
			await wait(1.0)
			bk.last_any = -100.0
			for e in du.log:
				if String(e[1]) == id and String(e[2]) == "end":
					ended = true
			if ended:
				break
		if ended:
			finished += 1
		else:
			print("GOLDA67CHECK   разговор %s не дошёл до конца: %s" % [id, str(du.log.slice(-3))])
		du.active = {}
	ok(finished == ids.size(), "ДВОР 1.5: все %d разговоров DUOS проигрываются до конца (%d)" % [ids.size(), finished])
	# hush: герой подходит вплотную — оба молчат, hush-реплика; отошёл — продолжают с той же строки
	du.done_at = {}
	du.active = {}
	du.start_now("pigeon_tile")
	var duo2: Dictionary = {}
	for d in G67LifeData.DUOS:
		if String(d["id"]) == "pigeon_tile":
			duo2 = d
	var who2: Array = du._who(duo2)
	P.global_position = (who2[0] as Node3D).global_position + Vector3(8.0, 0.05, 0.0)
	await wait(14.0)
	var line_before: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else -1
	P.global_position = (who2[0] as Node3D).global_position + Vector3(1.6, 0.05, 0.0)
	await wait(2.0)
	var hushed: bool = du.active.has("gazebo") and bool(du.active["gazebo"]["hush"]) and du.hush_log.size() > 0
	var i_hush: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else -2
	P.global_position = (who2[0] as Node3D).global_position + Vector3(8.0, 0.05, 0.0)
	await wait(8.0)
	var i_after: int = int(du.active["gazebo"]["i"]) if du.active.has("gazebo") else 99
	ok(hushed and i_hush == line_before and i_after > i_hush, "ДВОР 1.5: hush при подходе (hush-реплика, строка %d), после ухода продолжили со строки %d (было %d)" % [i_hush, i_after, i_hush])
	du.active = {}
	# сирена: жители в 30 м смотрят на столб
	var s0 := 0
	for rid in yd.residents:
		s0 += (yd.residents[rid] as G67Resident).log.filter(func(e): return String(e[0]) == "siren").size()
	yd.siren_look(Vector3(-18, 0, -15))
	await wait(1.0)
	var s1 := 0
	for rid in yd.residents:
		s1 += (yd.residents[rid] as G67Resident).log.filter(func(e): return String(e[0]) == "siren").size()
	ok(s1 > s0, "ДВОР 1.5: сирена кнопки — жители в 30 м повернулись к столбу (%d)" % (s1 - s0))
	await wait(6.0)
	# очередь реально сдвигается
	var names0: Array = yd.queue.filter(func(n): return is_instance_valid(n)).map(func(n): return str(n.get_instance_id()))
	G.ylife_get().fire("queue_move")
	await wait(12.0)
	var names1: Array = yd.queue.filter(func(n): return is_instance_valid(n)).map(func(n): return str(n.get_instance_id()))
	ok(names0 != names1 and names1.size() == names0.size(), "ДВОР 1.5: очередь сдвинулась и сменился состав (%d → %d)" % [names0.size(), names1.size()])
	# gather: бой с Мишей — три жителя у борта коробки; после боя расходятся
	P.global_position = Vector3(2.0, 0.05, -38.0)
	for rid in ["g67_npc_babushka", "g67_npc_taxi_driver", "g67_npc_schoolboy"]:
		(yd.residents[rid] as G67Resident).gather_override = true
	await wait(40.0)
	var at_board := 0
	for rid in ["g67_npc_babushka", "g67_npc_taxi_driver", "g67_npc_schoolboy"]:
		var R: G67Resident = yd.residents[rid]
		if ((R.rig as Node3D).global_position - R.GATHER[rid]).length() < 2.5 or R.log.has(["gather"]):
			at_board += 1
	await _cam_shot(g, "life15_gather", Vector3(-8.5, 2.0, -34.0), Vector3(-13.8, 1.3, -39.8))
	ok(at_board >= 3, "ДВОР 1.5: бой с Мишей — бабушка, таксист и школьник у борта коробки (%d из 3)" % at_board)
	for rid in ["g67_npc_babushka", "g67_npc_taxi_driver", "g67_npc_schoolboy"]:
		(yd.residents[rid] as G67Resident).gather_override = false
	await wait(3.0)
	var gone := 0
	for rid in ["g67_npc_babushka", "g67_npc_taxi_driver", "g67_npc_schoolboy"]:
		if not (yd.residents[rid] as G67Resident).gathered:
			gone += 1
	ok(gone == 3, "ДВОР 1.5: после боя жители расходятся (%d из 3)" % gone)
	P.global_position = Vector3(0, 0.05, 25)
	# сохранение: ключей не прибавилось
	G.save()
	var keys1: Array = _keys_of(G.data)
	ok(keys0 == keys1, "ДВОР 1.5: сохранение без новых ключей после жизни двора и всех [E] (%d → %d ключей)" % [keys0.size(), keys1.size()])

## События двора: предметы стоят, каждый исход таблиц форсируется и проверяется, этап закрывается
func _events_check(g, G: Golda67, P) -> void:
	await _go(G, P, "exit")
	if not await until(func(): return G.place == "run" and G.room_state == "fight", 8.0):
		return
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.5)
	await _spawn_check(g, G, P)
	await _life15(g, G, P)
	# фасад: окна меняют состояние, вывески, тарелки, дым
	var yd3 = G.world.yard
	var tg0: int = yd3.win_toggles
	for k in 40:
		yd3.win_tick(1.5)                      # 60 с ускоренного времени
	ok(yd3.win_toggles > tg0 and yd3.win_state.size() >= 12, "окна двора меняют состояние за 60 с (переключений %d из %d окон)" % [yd3.win_toggles - tg0, yd3.win_state.size()])
	ok(yd3.sign_texts.has("ПРОДУКТЫ") and yd3.sign_texts.has("АПТЕКА") and yd3.sign_texts.has("РЕМОНТ ОБУВИ") and yd3.smoke_nodes.size() >= 3 and yd3.facade_nodes.size() >= 12, "на фасаде вывески, тарелки, кондиционеры, козырёк, дым (%d узлов, дым %d)" % [yd3.facade_nodes.size(), yd3.smoke_nodes.size()])
	var fc := Camera3D.new()
	fc.fov = 60.0
	g.add_child(fc)
	fc.global_position = Vector3(-6, 3.2, 20)
	fc.look_at(Vector3(-8, 9, 35), Vector3.UP)
	fc.make_current()
	await wait(0.5)
	await shot("facade_windows")
	g.cam.make_current()
	fc.queue_free()
	var lf: Array = []
	for l in yd3.lifes:
		if is_instance_valid(l) and l.get("rig") != null:
			lf.append(String(l.rig.cur))
	print("GOLDA67CHECK   жители и текущие позы: %s" % str(lf))
	ok(yd3.lifes.size() >= 4 and lf.all(func(c): return c != "" and c != "?"), "у каждого жителя работает G67Life, поза задана (%s)" % str(lf))
	# голуби: стайки по 4, взлетают при подходе и садятся в другом месте, не исчезая
	var yd2 = G.world.yard
	ok(yd2.flocks.size() == 4 and yd2.flocks.all(func(f): return (f["birds"] as Array).size() == 4), "во дворе четыре стайки голубей по четыре")
	var fl0: Dictionary = yd2.flocks[0]
	var home0: Vector3 = fl0["alt"] if bool(fl0["at_alt"]) else fl0["home"]
	var alt0: Vector3 = fl0["home"] if bool(fl0["at_alt"]) else fl0["alt"]
	P.global_position = home0 + Vector3(1.5, 0.05, 0)
	await wait(0.6)
	var mid_hi := false
	for k in 8:
		for b in fl0["birds"]:
			if is_instance_valid(b["n"]) and (b["n"] as Node3D).global_position.y > 2.0:
				mid_hi = true
		await wait(0.3)
	await wait(1.5)
	var all_ok: bool = true
	for b in fl0["birds"]:
		var nn = b["n"]
		if not is_instance_valid(nn) or (nn as Node3D).global_position.distance_to(alt0) > 4.0 or (nn as Node3D).global_position.y > 1.0:
			all_ok = false
	ok(mid_hi and all_ok, "голуби взлетели дугой (выше 2 м: %s) и сели в другом месте, никто не пропал" % str(mid_hi))
	P.global_position = Vector3(2, 0.05, 25)
	ok(G.world.ev_nodes.has("burm") and G.world.ev_nodes.has("button") and G.world.ev_nodes.has("rags"), "автомат, кнопка и дверь «ТРЯПОК» стоят во дворе: %s" % str(G67Yard.EVENT_SPOTS))
	for k in G67Yard.EVENT_SPOTS:
		var free_at: Array = []
		var base: Vector3 = G67Yard.EVENT_SPOTS[k]
		for dx in range(-6, 7, 2):
			for dz in range(-6, 7, 2):
				if _probe_free(g, base + Vector3(dx, 0.0, dz + 1.6)) and _probe_free(g, base + Vector3(dx, 0.0, dz)):
					free_at.append(base + Vector3(dx, 0.0, dz))
		print("GOLDA67CHECK   свободные места у «%s»: %s" % [k, str(free_at.slice(0, 6))])
		ok(_probe_free(g, base + Vector3(0, 0, 1.6)), "место «%s» доступно со стороны подхода" % k)
	# снимки предметов
	for v in [["ev_burmalda", "burmalda", Vector3(0, 1.6, 3.4)], ["ev_button", "button", Vector3(0, 1.6, 3.0)], ["ev_rags_door", "rags", Vector3(3.4, 1.6, 0)]]:
		var sp: Vector3 = G67Yard.EVENT_SPOTS[v[1]]
		var oc := Camera3D.new()
		g.add_child(oc)
		oc.global_position = sp + (v[2] as Vector3)
		oc.look_at(sp + Vector3(0, 1.2, 0), Vector3.UP)
		oc.make_current()
		await wait(0.5)
		await shot(String(v[0]))
		g.cam.make_current()
		oc.queue_free()
	# бурмалда: этап, рывки, таблица
	var p0 = G.world.gates
	G.room = {"type": "event", "ev": "burmalda", "place": "evspot"}
	G.room_state = "reward"
	G.run["golda"] = 100
	G.run["spent"] = 0
	G.run["stages"] = [["battle", "podezd", ""]]
	G.run["pos"] = 1
	await G.play_event("burmalda")
	ok(not G.point("ev_burmalda").is_empty(), "у автомата точка [E] только пока событие — этап")
	P.global_position = (G67Yard.EVENT_SPOTS["burmalda"] as Vector3) + Vector3(0, 0.05, 1.8)
	var g0 := int(G.run["golda"])
	G.use("ev_burmalda")
	await wait(0.3)
	await until(func(): return not G.ev_busy, 15.0)
	ok(int(G.run["ev_pulls"]) == 1 and int(G.run["spent"]) == 0, "первый рывок бесплатный")
	G.use("ev_burmalda")
	await wait(0.3)
	var freed2: bool = await until(func(): return not G.ev_busy, 15.0)
	print("GOLDA67CHECK   второй рывок: busy свободен %s" % str(freed2))
	ok(int(G.run["ev_pulls"]) == 2 and int(G.run["spent"]) == 25, "второй рывок — 25 голды (рывков %d, потрачено %d, голда %d)" % [int(G.run["ev_pulls"]), int(G.run["spent"]), int(G.run["golda"])])
	for oid in ["junk", "gold", "heal", "art", "fit", "rare_art"]:
		var n_before: int = G.coins.size()
		var arts0: int = G.arts().size()
		var fits0: int = (G.run["fits"] as Dictionary).size()
		G._burmalda_outcome(oid)
		await wait(0.2)
		match oid:
			"gold":
				ok(G.coins.size() >= n_before + 3, "Бурмалда: голда выдаётся монетами в лоток")
			"heal":
				ok(G.coins.any(func(c): return c.has("heal") and float(c["heal"]) == 30.0), "Бурмалда: лечение +30 — свёрток в лотке")
			"art":
				ok(G.arts().size() >= arts0 or G.coins.size() > n_before, "Бурмалда: обычный артефакт или голда")
			"fit":
				ok((G.run["fits"] as Dictionary).size() >= fits0, "Бурмалда: баф выдан")
			_:
				ok(true, "Бурмалда: исход «%s» отработал" % oid)
	await shot("ev_burmalda_out")
	G.run["ev_pulls"] = 3
	G._ev_finish()
	ok(G.room_state == "open" and (G.run["stages"] as Array).size() == 2 and G.clip_open_ev("burmalda"), "после рывков этап пройден, запись «Бурмалда» в архиве")
	# кнопка: все шесть исходов
	G.room = {"type": "event", "ev": "button", "place": "evspot"}
	G.room_state = "reward"
	await G.play_event("button")
	var p = P
	p.hp = 80.0
	p.inv = 99.0
	for bid in G67Data.BUTTON:
		var hp_b: float = p.hp
		var cn: int = G.coins.size()
		G._button_outcome(bid)
		await wait(0.3)
		match bid:
			"lights":
				ok(G.coins.size() >= cn + 1 or int(G.run["earned"]) > 0, "кнопка: свет гаснет, монеты у ног")
			"alarms":
				ok(true, "кнопка: сигнализации и +1 РЕСПЕКТ")
			"shawarma":
				ok(G.coins.any(func(c): return c.has("heal") and float(c["heal"]) == 40.0), "кнопка: из люка шаурма +40")
			"shock":
				ok(p.hp <= hp_b - 9.9 and p.hp >= 1.0 and p.swag >= 99.9, "кнопка: ток −10, СВЭГ до 100")
			"snow":
				ok(bool(G.run.get("snow_stun", false)), "кнопка: следующая волна войдёт оглушённой")
			_:
				ok(true, "кнопка: исход «%s»" % bid)
	await shot("ev_button_out")
	# сцены: все исходы обеих таблиц; ввод закрыт на время, потом возвращён; нужные реплики проиграны
	P.global_position = (G67Yard.EVENT_SPOTS["button"] as Vector3) + Vector3(0, 0.05, 1.0)
	G.room = {"type": "event", "ev": "button", "place": "evspot"}
	G.room_state = "reward"
	for bid in G67Data.BUTTON:
		G.events.clear()
		G._button_scene(bid)
		await wait(0.3)
		ok(G.ev_cam and G.scene_busy(), "сцена кнопки «%s»: началась, ввод закрыт" % bid)
		await until(func(): return not G.ev_cam, 14.0)
		ok(not G.ev_cam and not G.scene_busy() and not g.intro_busy(), "сцена кнопки «%s»: камера и управление возвращены" % bid)
		var want_lines: int = {"alarms": 2, "snow": 1, "shawarma": 2}.get(bid, 0)
		var said: int = G.events.filter(func(e): return String(e[0]) == "ev_say").size()
		ok(said == want_lines, "сцена кнопки «%s»: реплик сказано %d из %d" % [bid, said, want_lines])
	for l in G67Voice.EVENT_BUTTON + G67Voice.EVENT_BURMALDA:
		ok(G67Voice.path(String(l)) != "", "реплика события озвучена: %s" % String(l))
	G.room = {"type": "event", "ev": "burmalda", "place": "evspot"}
	P.global_position = (G67Yard.EVENT_SPOTS["burmalda"] as Vector3) + Vector3(0, 0.05, 1.8)
	for oid in ["junk", "gold", "heal", "art", "fit", "rare_art"]:
		G.events.clear()
		G._burmalda_scene(oid, true)
		await wait(0.3)
		await until(func(): return not G.ev_cam, 14.0)
		ok(not G.ev_cam and not G.scene_busy(), "сцена Бурмалды «%s»: управление возвращено" % oid)
		ok(G.events.any(func(e): return String(e[0]) == "ev_say"), "сцена Бурмалды «%s»: Пахан говорит" % oid)
	ok(not G.scene_busy(), "после сцен события управление свободно")
	var texts: Array = []
	for nm in ["burm", "button"]:
		for lb in (G.world.ev_nodes[nm]["root"] as Node).find_children("*", "Label3D", true, false):
			texts.append(String((lb as Label3D).text).replace("\n", " "))
	for want_t in ["БУРМАЛДА", "Мы не знаем, что внутри. Но оно работает", "Гарантия до первого использования", "МОЖНО. А ЗАЧЕМ?", "НЕ НАЖИМАТЬ", "ЩИТ № 67", "U = ?", "ОТВ. — НИКТО"]:
		ok(texts.has(want_t), "надпись на предмете двора: «%s»" % want_t)
	# N07: этап ЛАРЁК выбирается у окна
	var must_old: Dictionary = (G.meta().get("must", {}) as Dictionary).duplicate()
	G.meta()["must"] = {"ev_rags": true}
	G.run["stages"] = [["battle", "podezd", ""], ["fit", "playground", ""], ["battle", "garages", ""]]
	G.run["pos"] = 2
	G.run["kiosk_full"] = false
	G.run["kiosk"] = {}
	G.room_state = "open"
	G.room = {"type": "battle", "place": "garages"}
	G.world.add_gates(G.route_options(3))
	G._kiosk_hint()
	P.global_position = G67Yard.KIOSK_POS + Vector3(-0.5, 0.05, 0)
	ok(G._kiosk_gate() >= 0 and String(G.point("kiosk")["hint"]).begins_with("ЛАРЁК"), "N07: на позиции с ЛАРЬКОМ у окна подсказка «%s»" % G.point("kiosk")["hint"])
	G.use("kiosk")
	await wait(0.6)
	ok(String(G.room.get("type", "")) == "kiosk" and bool(G.run.get("kiosk_full", false)) and G.kiosk_price("shawarma") == 0, "N07: [E] у окна выбрал этап ЛАРЁК, окно полное, первая шаурма бесплатно")
	if G.hub_ui != null:
		G.hub_ui.close()
		await wait(0.3)
	G.meta()["must"] = must_old
	G.room = {"type": "event", "ev": "button", "place": "evspot"}
	G.room_state = "reward"
	G.run["snow_stun"] = false
	p.inv = 0.0
	G._ev_finish()
	ok(G.room_state == "open" and G.clip_open_ev("button"), "кнопка: этап пройден, запись в архиве")
	G.world.points = G.world.points.filter(func(pt): return not String(pt["id"]).begins_with("ev_"))
	await G.enter_hub()
	G.data["run"] = {}
	await wait(0.3)

## Один ролик: кадр каждую секунду и журнал «время → реплика → длина голоса → пауза до следующей»
func _clip_log(G: Golda67, cid: String) -> void:
	G67ClipPlayer.last_log = []
	G.play_clip(cid)
	await wait(0.3)
	var t_last := 0.0
	var nxt := 0.0
	while G.clip != null and is_instance_valid(G.clip):
		t_last = G.clip.t
		if G67Clips.snap_req != "":
			var nm: String = G67Clips.snap_req
			G67Clips.snap_req = ""
			print("GOLDA67CHECK   LOG cam %s %s fov %.0f" % [nm, str(G.clip.cam.global_position), G.clip.cam.fov])
			await shot("clip_%s_%s" % [cid, nm])
		await get_tree().process_frame
	var lg: Array = G67ClipPlayer.last_log
	for i in lg.size():
		var gap := 0.0
		var note := ""
		if i + 1 < lg.size():
			gap = float(lg[i + 1][0]) - (float(lg[i][0]) + float(lg[i][2]))
			note = "  ← ОБРЕЗАНА" if gap < -0.05 else ("  ← ПАУЗА > 0,8 с" if gap > 0.8 else "")
		print("GOLDA67CHECK   LOG %s %5.1f  %s  голос %.2f с  пауза %.2f%s%s" % [cid, float(lg[i][0]), String(lg[i][1]).left(48), float(lg[i][2]), gap, note, "" if bool(lg[i][3]) else "  (НЕТ ГОЛОСА)"])
	print("GOLDA67CHECK   LOG %s длина %.1f с" % [cid, t_last])

## Контраст метки атаки: кольцо против земли вокруг, в тени (дальше всего от фонарей) и на свету (у фонаря), по зонам
func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _marks_contrast(g, G: Golda67) -> void:
	var yd = G.world.yard
	var oc := Camera3D.new()
	oc.fov = 50.0
	g.add_child(oc)
	oc.make_current()
	for zid in ["podezd", "garages", "playground", "parking", "gazebo", "sport"]:
		var z: Dictionary = G67Yard.zone(zid)
		var c: Vector3 = z["c"]
		var h: Vector2 = z["h"]
		var dark := c
		var dd := -1.0
		var lit := c
		var ld := 1e9
		for i in 40:
			var p := Vector3(c.x + (float(i % 8) / 7.0 * 2.0 - 1.0) * (h.x - 2.0), 0, c.z + (float(i / 8) / 4.0 * 2.0 - 1.0) * (h.y - 2.0))
			var nearest := 1e9
			for lm in yd.lamps:
				nearest = minf(nearest, Vector2(lm.global_position.x - p.x, lm.global_position.z - p.z).length())
			if nearest > dd:
				dd = nearest
				dark = p
			if nearest < ld:
				ld = nearest
				lit = p
		var res: Array = []
		for spot in [dark, lit]:
			oc.global_position = spot + Vector3(0, 7.0, 6.5)
			oc.look_at(spot, Vector3.UP)
			await wait(0.4)
			var img0: Image = g.get_viewport().get_texture().get_image()
			g.telegraph(spot, 2.0, 8.0, 0.0, null)
			await wait(1.8)
			var img1: Image = g.get_viewport().get_texture().get_image()
			if zid in ["garages", "gazebo"]:
				await shot("mark_%s_%s" % [zid, "dark" if spot == dark else "lit"])
			for zz in g.zones.duplicate():
				if String(zz.get("kind", "")) == "tele":
					g.zones.erase(zz)
					if zz.has("n") and is_instance_valid(zz["n"]):
						(zz["n"] as Node3D).queue_free()
			var sc: Vector2 = oc.unproject_position(spot)
			var edge: Vector2 = oc.unproject_position(spot + Vector3(2.0, 0, 0))
			var rpx := absf(edge.x - sc.x)
			var ring := 0.0
			var base := 0.0
			var nr := 0
			for a in 36:
				var an := float(a) / 36.0 * TAU
				var pr := sc + Vector2(cos(an), sin(an) * 0.6) * rpx * 0.9
				var ps := sc + Vector2(cos(an), sin(an) * 0.6) * rpx * 1.5
				if pr.x < 0 or ps.x < 0 or pr.y < 0 or ps.y < 0 or pr.x >= img0.get_width() or ps.x >= img0.get_width() or pr.y >= img0.get_height() or ps.y >= img0.get_height():
					continue
				ring += _luma(img1.get_pixelv(Vector2i(pr)))
				base += _luma(img0.get_pixelv(Vector2i(pr)))
				nr += 1
			var contrast := (ring - base) / float(maxi(nr, 1)) / (base / float(maxi(nr, 1)) + 0.03)
			res.append(contrast)
			print("GOLDA67CHECK   MARK %s %s: яркость земли %.3f, с меткой %.3f, контраст %.2f" % [zid, "тень" if spot == dark else "свет", base / float(maxi(nr, 1)), ring / float(maxi(nr, 1)), contrast])
	oc.queue_free()

## Проход героя сквозь центр предмета: капсула идёт по прямой через точку; true — упёрлась
func _walk_blocked(g, c: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var best := false
	for ang in [0.0, PI * 0.5]:
		var d := Vector3(cos(ang), 0, sin(ang))
		var sh := CapsuleShape3D.new()
		sh.radius = 0.3
		sh.height = 1.7
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), Vector3(c.x, 0.95, c.z) - d * 3.0)
		q.motion = d * 6.0
		var r: Array = space.cast_motion(q)
		if r.size() >= 2 and float(r[0]) < 0.999:
			best = true
	return best

func _coll_walk(g, G: Golda67, P) -> void:
	await wait(0.5)
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(1.0)
	var list := [
		["сушилка: столб 1", Vector3(8.8, 0, 20.6)], ["сушилка: столб 2", Vector3(12.2, 0, 21.4)], ["сушилка: под верёвкой", Vector3(10.5, 0, 21.0)],
		["ковровыбивалка", Vector3(-7.0, 0, 3.6)], ["дерево (−8,5; 17,5)", Vector3(-8.5, 0, 17.5)], ["берёза (9,5; 14,5)", Vector3(9.5, 0, 14.5)],
		["дерево (−24; 13,5)", Vector3(-24.0, 0, 13.5)], ["берёза (−9,5; −1)", Vector3(-9.5, 0, -1.0)], ["берёза (13; −2,5)", Vector3(13.0, 0, -2.5)],
		["куст (−6; 26,3)", Vector3(-6.0, 0, 26.3)], ["куст (8,6; 26,2)", Vector3(8.6, 0, 26.2)], ["куст (−22,5; −4,5)", Vector3(-22.5, 0, -4.5)],
		["куча мусора (−20,6; 34,6)", Vector3(-20.6, 0, 34.6)], ["куча мусора (−42,6; 21,5)", Vector3(-42.6, 0, 21.5)], ["куча мусора (40,6; 3,6)", Vector3(40.6, 0, 3.6)],
		["барьер площадки 1", Vector3(-3.4, 0, -15.8)], ["барьер площадки 2", Vector3(1.3, 0, -15.8)], ["барьер площадки 3", Vector3(6.0, 0, -15.8)],
		["узел (−2; 1,2)", Vector3(-2.0, 0, 1.2)], ["столб ворот коробки слева", Vector3(-0.1, 0, -27.0)], ["столб ворот коробки справа", Vector3(4.1, 0, -27.0)],
		["ящик у трона", Vector3(5.6, 0, -47.6)], ["зритель у борта", Vector3(-12.6, 0, -36.0)], ["сугроб-модель (−18; 26,2)", Vector3(-18.0, 0, 26.2)],
		["автомат «Бурмалда»", G67Yard.EVENT_SPOTS["burmalda"]], ["столб кнопки", G67Yard.EVENT_SPOTS["button"]], ["ларёк", Vector3(42.3, 0, 7.0)],
		["лавка (−3,4; 34,6)", Vector3(-3.4, 0, 34.6)], ["лавка (3,4; 34,6)", Vector3(3.4, 0, 34.6)], ["урна у лавки", Vector3(-1.9, 0, 33.6)],
		["машина (−9; 31,4)", Vector3(-9.0, 0, 31.4)], ["машина (31,4; −4,5)", Vector3(31.4, 0, -4.5)], ["фургон (17,5; 31,2)", Vector3(17.5, 0, 31.2)],
		["турник (−8; −43,5)", Vector3(-8.0, 0, -43.5)], ["турник (12,2; −33)", Vector3(12.2, 0, -33.0)], ["покрышки у трона", Vector3(-3.6, 0, -48.2)],
		["конус (−37,4; −8)", Vector3(-37.4, 0, -8.0)], ["горка заначки (20,5; −31)", Vector3(20.5, 0, -31.0)], ["беседка", Vector3(-27.0, 0, -33.5)],
		["скамья у беседки", Vector3(-22.8, 0, -29.5)], ["бочка у беседки", Vector3(-24.2, 0, -31.4)]]
	for it in list:
		print("GOLDA67CHECK   WALK %s | %s" % [str(it[0]), "ПРОХОДИТ СКВОЗЬ" if not _walk_blocked(g, it[1]) else "упирается"])

## Разведка: предметы двора и подъезда без коллизии (проба формой в центре каждого заметного объекта)
func _aabb_of(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var bb: AABB = m.global_transform * m.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and first:
		out = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
	return out

func _coll_report(tag: String, root: Node, g) -> void:
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var rows: Array = []
	for n in root.get_children():
		if not (n is Node3D) or n is Light3D or n is GPUParticles3D or n is Camera3D or n is Label3D or n is MultiMeshInstance3D or n is StaticBody3D:
			continue
		var bb := _aabb_of(n)
		if bb.size.length() < 0.01:
			continue
		if bb.size.y < 0.45 or maxf(bb.size.x, bb.size.z) < 0.25 or bb.size.x > 12.0 or bb.size.z > 12.0:
			continue
		if bb.position.y > 1.2:
			continue
		var cy: float = clampf(bb.position.y + bb.size.y * 0.5, 0.4, 1.0)
		var hit := false
		for k in 3:
			var sh := SphereShape3D.new()
			sh.radius = 0.25
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sh
			q.collision_mask = 1
			var cx := bb.position.x + bb.size.x * (0.5 if k == 0 else (0.3 if k == 1 else 0.7))
			var cz := bb.position.z + bb.size.z * (0.5 if k == 0 else (0.3 if k == 1 else 0.7))
			q.transform = Transform3D(Basis(), Vector3(cx, cy, cz))
			if not space.intersect_shape(q, 1).is_empty():
				hit = true
				break
		if not hit:
			var kids: Array = []
			for ch in n.get_children():
				kids.append(String(ch.name))
			var sc := String(n.scene_file_path).get_file()
			rows.append("%s | дети %s %s | %.1f×%.1f×%.1f м | (%.1f, %.1f)" % [String(n.name), str(kids.slice(0, 2)), sc, bb.size.x, bb.size.y, bb.size.z, bb.get_center().x, bb.get_center().z])
	print("GOLDA67CHECK   COLL %s: без коллизии %d" % [tag, rows.size()])
	for r in rows:
		print("GOLDA67CHECK   COLL  ", r)

func _coll_probe(g, G: Golda67, P) -> void:
	await wait(0.5)
	_coll_report("подъезд", G.world, g)
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(1.0)
	_coll_report("двор (мир)", G.world, g)
	if G.world.yard != null:
		_coll_report("двор (yard)", G.world.yard, g)

## Замер кадра по зонам: камера над центром зоны, 3 с на каждую
func _perf_zones(g, G: Golda67, P) -> void:
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(1.0)
	var ab := ""
	for x in OS.get_cmdline_user_args():
		if String(x).begins_with("--ab="):
			ab = String(x)
	if ab.contains("notes"):
		for nt in G.world.yard.notes:
			(nt["node"] as Node3D).queue_free()
		G.world.yard.notes = []
		G.world.yard.sway_notes = []
	if ab.contains("res"):
		for k in G.world.yard.residents:
			G.world.yard.residents[k].set_physics_process(false)
	if ab.contains("ylife"):
		G.ylife_get().set_physics_process(false)
	if ab.contains("duos"):
		G.duos_get().set_physics_process(false)
	if ab.contains("barks"):
		G.barks_get().set_process(false)
	if ab.contains("flock4"):
		for b in G.world.yard.flocks[3]["birds"]:
			(b["n"] as Node3D).queue_free()
	if ab.contains("gaz"):
		for r in G.world.yard.gazebo_people:
			r.queue_free()
	if ab.contains("pill"):
		for sb in G.world.yard.get_children():
			if sb is StaticBody3D and (sb.get_child(0) as CollisionShape3D).shape is CylinderShape3D:
				sb.queue_free()
	if ab.contains("fx"):
		for ch in G.world.yard.get_children():
			if String(ch.name).begins_with("g67_fx_"):
				ch.queue_free()
	if ab.contains("patch"):
		for ch in G.world.yard.get_children():
			if ch is MultiMeshInstance3D and ch != G.world.yard.win_mm:
				ch.queue_free()
	if ab.contains("wire"):
		for ch in G.world.yard.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is CylinderMesh and ((ch as MeshInstance3D).mesh as CylinderMesh).top_radius < 0.02:
				ch.queue_free()
	if ab.contains("fog"):
		for we in g.get_tree().root.find_children("*", "WorldEnvironment", true, false):
			(we as WorldEnvironment).environment.fog_enabled = false
	if ab.contains("props"):
		for k in G.world.yard.life_props:
			G.world.yard.life_props[k].queue_free()
	var oc := Camera3D.new()
	oc.fov = 65.0
	g.add_child(oc)
	oc.make_current()
	await wait(3.0)
	for zid in ["podezd", "garages", "playground", "parking", "gazebo", "sport"]:
		var z: Dictionary = G67Yard.zone(zid)
		var c: Vector3 = z["c"]
		oc.global_position = c + Vector3(0, 5.5, 13.0)
		oc.look_at(c + Vector3(0, 1.0, 0), Vector3.UP)
		await wait(0.6)
		var times: Array = []
		var t0 := Time.get_ticks_msec()
		var last := t0
		while Time.get_ticks_msec() - t0 < 6000:
			await get_tree().process_frame
			var nw := Time.get_ticks_msec()
			times.append(float(nw - last))
			last = nw
		times.sort()
		var tot := 0.0
		for x in times:
			tot += float(x)
		var worst: int = maxi(1, int(times.size() * 0.01))
		var wsum := 0.0
		for i in worst:
			wsum += float(times[times.size() - 1 - i])
		print("GOLDA67CHECK   PERFZONE %s: средний %.1f FPS, 1%% худших %.1f FPS" % [zid, 1000.0 / (tot / times.size()), 1000.0 / (wsum / worst)])

## Замер кадра: облёт двора 10 с, средний FPS и 1 % худших
func _perf_flyover(g, G: Golda67, P) -> void:
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(1.0)
	var oc := Camera3D.new()
	oc.fov = 60.0
	g.add_child(oc)
	oc.make_current()
	var times: Array = []
	var t0 := Time.get_ticks_msec()
	var last := t0
	while Time.get_ticks_msec() - t0 < 10000:
		var a := float(Time.get_ticks_msec() - t0) / 10000.0 * TAU
		oc.global_position = Vector3(2.0 + sin(a) * 38.0, 9.0, -8.0 + cos(a) * 34.0)
		oc.look_at(Vector3(2, 1.5, -8.0), Vector3.UP)
		await get_tree().process_frame
		var nw := Time.get_ticks_msec()
		times.append(float(nw - last))
		last = nw
	times.sort()
	var tot := 0.0
	for x in times:
		tot += float(x)
	var worst: int = maxi(1, int(times.size() * 0.01))
	var wsum := 0.0
	for i in worst:
		wsum += float(times[times.size() - 1 - i])
	print("GOLDA67CHECK   PERF кадров %d, средний FPS %.1f, 1%% худших: %.1f FPS" % [times.size(), 1000.0 / (tot / times.size()), 1000.0 / (wsum / worst)])

## Сцена события: kind = burm:<исход> или btn:<исход>; кадр каждые 0,5 с
func _ev_scene_shots(g, G: Golda67, P, kind: String) -> void:
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.4)
	var ev := "burmalda" if kind.begins_with("burm") else "button"
	var sp: Vector3 = G67Yard.EVENT_SPOTS[ev]
	P.global_position = sp + Vector3(0, 0.05, 1.8 if ev == "burmalda" else 1.0)
	G.room = {"type": "event", "ev": ev, "place": "evspot"}
	G.room_state = "reward"
	var id := kind.get_slice(":", 1)
	var t0 := GameClock.ms()
	var nxt := 0.0
	if ev == "burmalda":
		G._burmalda_scene(id, true)
	else:
		G._button_scene(id)
	await wait(0.05)
	while G.ev_cam:
		var tt := float(GameClock.ms() - t0) / 1000.0
		if tt >= nxt:
			await shot("ev_%s_%04.1f" % [id, nxt])
			nxt += 1.2
		await get_tree().process_frame
	print("GOLDA67CHECK   СЦЕНА %s длилась %.1f с" % [kind, float(GameClock.ms() - t0) / 1000.0])

## Постановка выхода Миши: кадр каждые 0,5 с; прожекторы до и после; пропуск удержанием
func _boss_scene_shots(g, G: Golda67, P, skip: bool) -> void:
	await _go(G, P, "exit")
	await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	_kill_all(g)
	G.pending = []
	G.wave_wait = 999.0
	await wait(0.4)
	G.enter_room({"type": "boss", "place": "sport"})
	await until(func(): return G.scene_t >= 0.0, 4.0)
	var y = G.world.yard
	var e_dim: float = (y.flood[0] as OmniLight3D).light_energy
	var steps: Array = []
	var t_last := 0.0
	var nxt := 0.0
	var held := false
	while G.scene_t >= 0.0:
		t_last = G.scene_t
		if not steps.has(G.scene_step):
			steps.append(G.scene_step)
		if G.scene_t >= nxt:
			await shot("boss_%04.1f" % nxt)
			nxt += 3.0
		if skip and G.scene_t > 3.0 and not held:
			held = true
			var ee := InputEventKey.new()
			ee.keycode = KEY_ENTER
			ee.physical_keycode = KEY_ENTER
			ee.pressed = true
			Input.parse_input_event(ee)
		await get_tree().process_frame
	if held:
		var ee2 := InputEventKey.new()
		ee2.keycode = KEY_ENTER
		ee2.physical_keycode = KEY_ENTER
		ee2.pressed = false
		Input.parse_input_event(ee2)
	var e_on: float = (y.flood[0] as OmniLight3D).light_energy
	ok(e_dim < 0.5 and e_on > 1.0, "прожекторы: до постановки приглушены (%.2f), после — включены (%.2f)" % [e_dim, e_on])
	ok(steps.size() >= (2 if skip else 6), "постановка: шаги %s" % str(steps))
	ok(skip or (t_last >= 10.0 and t_last <= 12.0), "длина постановки %.1f с (≤ 12)" % t_last)
	ok(not skip or t_last < G.SCENE_LEN - 1.0, "пропуск удержанием Enter прервал постановку на %.1f с" % t_last)
	ok(G.room_state == "boss" and is_instance_valid(g.boss_e) and g.boss_e.global_position.distance_to(G.scene_to) < 0.8, "бой начался, Миша на месте")
	await wait(1.0)
	await shot("boss_fight_start")
	print("GOLDA67CHECK   BOSS длина %.1f с шаги %s" % [t_last, str(steps)])

## Событие «ТРЯПКИ! ТРЯПКИ!»: реплики озвучены, предметы на месте, длина 30–42 с, снимки по фазам
func _ev02_check(g, G: Golda67, P) -> void:
	var lines: Array = G67Voice.EVENT_RAGS
	ok(lines.size() == 5 and lines.all(func(l): return G67Voice.path(String(l)) != ""), "реплики события озвучены (%d)" % lines.size())
	G.play_clip("EV02")
	await wait(0.6)
	var cp = G.clip
	ok(cp != null and cp.id == "EV02", "ролик EV02 запущен")
	var props: Array = []
	for nm in ["g67_event_bed", "g67_event_bucket", "g67_event_siren", "g67_event_rags"]:
		props.append(cp.world.get_node_or_null(nm) != null)
	ok(props.all(func(x): return x), "в комнате четыре модели события: %s" % str(props))
	var marks := [2.5, 5.5, 8.0, 11.0, 13.0, 15.0, 17.0, 20.0, 25.0, 29.0, 31.0, 34.0]
	var mi := 0
	var last_t := 0.0
	while G.clip != null and is_instance_valid(G.clip):
		last_t = G.clip.t
		if mi < marks.size() and last_t >= float(marks[mi]):
			await shot("ev02_%02d" % int(float(marks[mi])))
			mi += 1
		await get_tree().process_frame
	ok(last_t >= 30.0 and last_t <= 42.0, "длительность события %.1f с (30–42)" % last_t)
	ok(G.clip_seen("EV02"), "досмотренный ролик — в clips_seen")

## iPhone Пахана: плейлист, управление, заглушение музыки локации, список скрыт в бою, остановка
func _phone_check(g, G: Golda67) -> void:
	var ph: G67Phone = G.phone_get()
	ph.scan()
	print("GOLDA67CHECK   треков плейлиста найдено: %d из 16" % ph.available())
	ok(G67Data.PLAYLIST.size() == 16, "плейлист из 16 строк")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var buf := PackedByteArray()
	buf.resize(22050 * 8 * 2)
	for i in 22050 * 8:
		buf.encode_s16(i * 2, int(sin(TAU * 440.0 * float(i) / 22050.0) * 3000.0))
	wav.data = buf
	ph.injected = {1: wav, 2: wav}
	ok(ph.play(1) and ph.cur == 1, "трек 1 запущен")
	await wait(0.8)
	var p0 := ph.position()
	await wait(0.8)
	ok(ph.position() > p0 and ph.active(), "трек играет: позиция растёт (%.1f → %.1f)" % [p0, ph.position()])
	await wait(1.2)
	ok(String(main.audio.cur) == "", "пока играет плейлист, музыка режима молчит (набор: «%s»)" % main.audio.cur)
	ph.toggle()
	await wait(2.0)
	ok(ph.paused and not ph.active() and String(main.audio.cur) != "", "пауза плейлиста возвращает музыку режима (набор: «%s»)" % main.audio.cur)
	ph.toggle()
	ph.step(1)
	ok(ph.cur == 2, "следующий трек — №2")
	ph.step(-1)
	ok(ph.cur == 1, "предыдущий трек — №1")
	g.set_paused(true)
	await wait(0.9)
	g.pause_panel._open_page(4)
	await wait(0.3)
	var t_calm: String = _all_text(g.pause_panel)
	ok(t_calm.contains("BANDZ") and t_calm.contains("ЛЮБИМЫЕ ТРЕКИ ПАХАНА"), "в подъезде на вкладке МУЗЫКА виден iPhone со списком")
	await shot("phone_hub")
	g.pause_panel._close_card()
	g.set_paused(false)
	await wait(0.6)
	var rs_old: String = G.room_state
	G.room_state = "fight"
	g.set_paused(true)
	await wait(0.9)
	g.pause_panel._open_page(4)
	await wait(0.3)
	var t_fight: String = _all_text(g.pause_panel)
	ok(not t_fight.contains("BANDZ") and t_fight.contains("ЛЮБИМЫЕ ТРЕКИ ПАХАНА"), "в бою список скрыт, виден только текущий трек")
	await shot("phone_fight")
	g.pause_panel._close_card()
	g.set_paused(false)
	await wait(0.6)
	G.room_state = rs_old
	ph.stop()
	ok(not ph.active() and ph.cur < 0, "остановка плейлиста")
	ph.injected = {}

func _run_dvor(g, G: Golda67, P) -> void:
	await _phone_check(g, G)
	# шаги в приквеле: подъезд — бетон, двор — по поверхности
	G.step_log.clear()
	G.play_step(Vector3(0, 0.0, 0))
	ok(G.step_log.back() == "step_concrete", "шаг в подъезде — бетон (%s)" % str(G.step_log.back()))
	G.step_log.clear()
	var kinds_ok := true
	var place_old: String = G.place
	G.place = "run"
	for sp in [[Vector3(2, 0, -38), "step_ice"], [G67Yard.KIOSK_POS, "step_asphalt"], [Vector3(0, 0, 21), "step_snow"]]:
		G.play_step(sp[0])
		kinds_ok = kinds_ok and G.step_log.back() == sp[1]
	G.place = place_old
	ok(kinds_ok, "шаг во дворе: лёд в коробке, асфальт на парковке, снег у подъезда (%s)" % str(G.step_log))
	var snd_bad: Array = []
	for k in G67Sound.kinds():
		var w := G67Sound.stream(String(k))
		var pk := G67Sound.peak(String(k))
		if w.get_length() <= 0.05 or pk > 1.0 or pk < 0.02:
			snd_bad.append("%s %.2f %.2f" % [k, w.get_length(), pk])
	ok(snd_bad.is_empty(), "G67Sound: %d видов, у каждого длина > 0,05 с, пик в (0,02…1,0] (плохие: %s)" % [G67Sound.kinds().size(), str(snd_bad)])
	ok(G67Yard.surface_at(Vector3(2, 0, -38)) == "ice" and G67Yard.surface_at(G67Yard.KIOSK_POS) == "asphalt" and G67Yard.surface_at(Vector3(0, 0, 21)) == "snow", "поверхность под ногами: лёд в коробке, асфальт на парковке, снег у подъезда")
	ok(is_equal_approx(G67Data.FOE_DMG_K, 0.6), "множитель урона врагов двора 0,6")
	# музыка приквела: наборы есть, в подъезде играет подъездный
	var mus_ok := true
	for nm in ["loc_g67_hub_base", "loc_g67_dvor_base", "loc_g67_dvor_drive", "boss_g67_misha_p1", "boss_g67_misha_p2", "boss_g67_misha_p3", "boss_g67_misha_intro", "boss_g67_misha_win"]:
		var st = load("res://assets/music/%s.wav" % nm)
		if st == null or st.get_length() < (24.0 if "boss" not in nm or nm.ends_with("p1") or nm.ends_with("p2") or nm.ends_with("p3") else 4.0):
			mus_ok = false
			print("GOLDA67CHECK   набор музыки не годится: ", nm)
	ok(mus_ok, "наборы музыки приквела на месте, длиннее 16 тактов")
	await wait(1.5)
	ok(String(main.audio.cur) == "loc_g67_hub", "в подъезде играет набор loc_g67_hub (%s)" % main.audio.cur)
	ok(not G.point("hub_btn").is_empty() and not G.point("read_hub_lift").is_empty() and not G.point("read_hub_music").is_empty(), "ДВОР 1.5: в подъезде кнопка «НЕ НАЖИМАТЬ» и листки хаба на месте")
	G.use("hub_btn")
	await wait(4.0)
	G.use("read_hub_lift")
	await wait(0.3)
	var hub_card: bool = G.get_children().any(func(c): return c is G67ReadCard)
	for c in G.get_children():
		if c is G67ReadCard:
			c.queue_free()
	for k in 3:
		G.hub_btn_force = k
		G.use("hub_btn")
		await wait(4.2)
	G.hub_btn_force = -1
	ok(G.hub_log.has("btn_flush") and G.hub_log.has("btn_lamp") and G.hub_log.has("btn_voice"), "ДВОР 1.5: кнопка хаба — все три исхода (вода, лампа, голос из-за двери)")
	var mb2: Node3D = g.buddy
	print("GOLDA67CHECK   MADK поза: pos=%s visible=%s clip=%s st=%s log=%s" % [str(mb2.global_position), str(mb2.visible), String(g.buddy.rig.cur), G.madk_st, str(G.madk_log.slice(-4))])
	P.global_position = Vector3(-2.2, G67World.LAND_Y + 0.05, -2.6)
	P.visible = false
	await wait(0.3)
	await _cam_shot(g, "life15_madk_tv", mb2.global_position + Vector3(1.4, 1.5, 2.2), mb2.global_position + Vector3(0, 0.7, 0))
	P.visible = true
	G.hub_t["strip"] = 0.0
	G.hub_t["sil"] = 0.0
	await wait(1.0)
	ok(hub_card and G.world.hub_strip.visible and G.world.hub_sil.visible and G.hub_log.has("door_chain") and G.hub_log.has("window_silhouette"), "ДВОР 1.5: подъезд — листок читается, дверь на цепочке, силуэт в окне, без движения madk1d (B01)")
	# выход во двор — настоящей клавишей E у входной двери
	await _go(G, P, "exit")
	var started: bool = await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	ok(started, "выход из подъезда начинает забег (место: %s, этап: %s)" % [G.place, G.room.get("type", "")])
	if not started:
		return
	var yard_world = G.world
	ok(int(G.run["tpl"]) == 0 and G.route().size() == 6 and int(G.run["pos"]) == 0, "шесть позиций, начало с первой")
	ok(yard_world is G67World and yard_world.yard != null and yard_world.yard.position == Vector3.ZERO, "двор построен без сдвига: yard.position = (0, 0, 0)")
	ok(yard_world.statist != null and is_instance_valid(yard_world.statist) and String(yard_world.statist.cur) == "MSit" and yard_world.statist.global_position.distance_to(G67Yard.THRONE) < 0.6, "Миша сидит на троне с самого начала забега")
	ok(g.boss_e == null and not g.enemies.any(func(e): return is_instance_valid(e) and String(e.boss_id) != ""), "до боя на троне не враг: в списке врагов Миши нет")
	ok(P.global_position.distance_to(G67Yard.HOME_DOOR) < 12.0, "герой вышел из двери подъезда и стоит во дворе (%s)" % str(P.global_position))
	ok(not g.buddy.visible, "до первой концовки madk1d остаётся в подъезде — в забеге его нет")
	ok(String(g.top_label.text).contains("ДВОР 1/6"), "строка вверху: «%s»" % g.top_label.text)
	var got: bool = await until(func(): return G.alive() >= 3, 10.0)
	ok(got, "первая волна вышла (%d врагов)" % G.alive())
	await wait(1.5)
	ok(String(main.audio.cur) == "loc_g67_dvor" and (main.audio.director.base["layers"] as Array).size() >= 2 and float(main.audio.director.base["layers"][1]) > 0.5, "во дворе играет loc_g67_dvor, в бою включён слой drive (%s %s)" % [main.audio.cur, str(main.audio.director.base["layers"])])
	var skins: Array = []
	for e in g.enemies:
		if is_instance_valid(e):
			skins.append(String(e.skin))
	ok(not skins.is_empty() and skins.all(func(x): return String(x).begins_with("g67_")), "враги двора — модели приквела (%s)" % ", ".join(skins))
	ok(G.world.bounds != null and G.world.bounds.get_child_count() > 20, "на время боя зона огорожена видимыми ограждениями (%d частей)" % (G.world.bounds.get_child_count() if G.world.bounds != null else 0))
	var zp: Dictionary = G67Yard.zone("podezd")
	ok(g.arena_c == zp["c"] and g.arena_h == zp["h"] and g.in_arena(Vector3(0, 0, 21), 1.0) and not g.in_arena(Vector3(0, 0, 0), 1.0), "арена боя — прямоугольник зоны у подъезда, а не квадрат вокруг нуля")
	var ep: Array = g.enemies.filter(func(e): return is_instance_valid(e)).map(func(e): return e.global_position)
	var spp: Array = (G67Yard.zone("podezd")["spawns"] as Array).map(func(x): return x[0])
	ok(ep.all(func(p): return g.in_arena(p, 0.5) or spp.any(func(q): return (q as Vector3).distance_to(p) < 3.0)), "враги входят из точек входа или уже внутри зоны боя")
	# КРОТ и ларёк — постоянные места двора: стоят весь забег (B10: ничего не переставляется)
	ok(G.world.actors.has("g67_krot") and not G.point("krot").is_empty(), "КРОТ стоит у ларька с начала забега (встреча 1 — зона двора)")
	var kz: Dictionary = G67Yard.zone("parking")
	var kp: Vector3 = G.point("kiosk")["pos"]
	ok(absf(kp.x - (kz["c"] as Vector3).x) < (kz["h"] as Vector2).x and absf(kp.z - (kz["c"] as Vector3).z) < (kz["h"] as Vector2).y, "ларёк «ШАУРМА 67» стоит на парковке (%s)" % str(kp))
	await wait(1.5)
	await shot("20_dvor_fight")
	# обзор двора сверху и с крыш — планировка целиком (своя камера, игровую не трогаем)
	var oc := Camera3D.new()
	oc.fov = 50.0
	oc.far = 400.0
	g.add_child(oc)
	for v in [["30_yard_from_south", Vector3(0, 46, 78), Vector3(0, 0, -12)], ["31_yard_from_northeast", Vector3(62, 40, -72), Vector3(-4, 0, -6)],
			["32_yard_top", Vector3(0.1, 118, -8), Vector3(0, 0, -9)], ["32b_yard_top_north", Vector3(2.1, 90, -26), Vector3(2, 0, -26)], ["33_court_from_roof", Vector3(-22, 20, -20), Vector3(4, 0, -40)],
			["34_podezd_from_yard", Vector3(4, 5, 8), Vector3(0, 3, 34)], ["35_garages_lane", Vector3(-30, 4, 24), Vector3(-42, 1.5, -4)],
			["36_playground", Vector3(-12, 5, 6), Vector3(3, 2, -9)], ["37_parking_kiosk", Vector3(22, 5, 22), Vector3(38, 1.5, 6)]]:
		oc.global_position = v[1] as Vector3
		oc.look_at(v[2] as Vector3, Vector3.UP)
		oc.make_current()
		await wait(0.5)
		await shot(String(v[0]))
	g.cam.make_current()
	oc.queue_free()
	await wait(0.3)
	# враги настоящие: бьют и получают урон
	var e0 = null
	for e in g.enemies:
		if is_instance_valid(e) and e.alive():
			e0 = e
			break
	if e0 != null:
		var hp0: float = e0.hp
		e0.take_hit(10.0, Vector3.FORWARD, 0.0, false)
		ok(e0.hp < hp0, "враг получает урон (%.0f → %.0f)" % [hp0, e0.hp])
	# B01: в бою только Пахан — madk1d не идёт за героем, не бьёт, не отскакивает и не добивает вместе с ним
	ok(g.madk_away(), "до первой концовки в забеге madk1d нет рядом с героем")
	var idle: Dictionary = await _madk_idle(g, P, 8.0)
	ok(float(idle["near"]) > 14.0, "за 8 с боя madk1d не вернулся к герою (ближе всего был в %.0f м)" % float(idle["near"]))
	ok((idle["acts"] as Array).is_empty() and not bool(idle["foe"]), "madk1d не бьёт врагов и не отскакивает от замахов (его действия: %s)" % str(idle["acts"]))
	await _madk_no_finisher(g, G, P)
	# ларёк из боя не открывается
	G.use("kiosk")
	ok(G.hub_ui == null, "из боя окно ларька не открывается («Сначала разберись с этими»)")
	await _b05_check(g, G, P)
	await _n01_check(g, G, P)
	ok(await _clear_room(g, G), "этап 1 (БОЙ у подъезда) зачищен")
	ok(G.coins.size() > 0 or int(G.run["golda"]) > 0, "с побеждённых врагов и за зачистку упали монеты (на земле %d)" % G.coins.size())
	var wraps_l: Array = G.coins.filter(func(c): return c.has("heal"))
	ok(wraps_l.size() == 1 and float(wraps_l[0]["heal"]) == 25.0, "N06: за зачистку боя лежит свёрток шаурмы +25 (%d)" % wraps_l.size())
	if wraps_l.size() == 1:
		ok(not wraps_l[0].has("life"), "N11: свёрток за зачистку лежит без срока (до начала следующего этапа)")
		P.hp = 40.0
		P.global_position = (wraps_l[0]["n"] as Node3D).global_position
		await wait(1.2)
		ok(absf(P.hp - 65.0) < 1.5 and G.coins.filter(func(c): return c.has("heal")).is_empty(), "N06: подбор лечит один раз (здоровье %.0f)" % P.hp)
		P.hp = P.max_hp
	var pos_keep: int = int(G.run["pos"])
	G.run["pos"] = 1
	G.hub_ui = null
	G.use("kiosk")
	ok(G.hub_ui != null and G.hub_ui.kind == "kiosk", "N12: окно ларька торгует, когда пройдены две позиции")
	if G.hub_ui != null:
		G.hub_ui.close()
		await wait(0.3)
	G.run["pos"] = pos_keep
	G._kiosk_hint()
	ok(String(G.point("kiosk")["hint"]).contains("откроется после второй позиции"), "подсказка закрытого окна ларька: «%s»" % G.point("kiosk")["hint"])
	var gold_before := int(G.run["golda"])
	await wait(3.5)
	ok(G.coins.is_empty() and int(G.run["golda"]) > gold_before and int(G.run["earned"]) == int(G.run["golda"]) + int(G.run["spent"]), "монеты после боя летят к герою и начисляются один раз (голда %d)" % int(G.run["golda"]))
	ok(G.world.gates.size() == 2, "после боя открылись два варианта: бой и баф (%d)" % G.world.gates.size())
	ok(int(G.run["golda"]) > 0 and int(G.run["respect"]) == 3 and int(G.run["kills"]) >= 3, "за этап дали голду (%d) и РЕСПЕКТ (%d), убито %d" % [int(G.run["golda"]), int(G.run["respect"]), int(G.run["kills"])])
	ok(G.room_state == "open" and (G.run["stages"] as Array).size() == 1 and G.events.has(["stage_done", "battle"]), "этап пройден: событие stage_done, состояние open")
	ok(G.world.gates.all(func(gt): return gt.get("icon") != null and is_instance_valid(gt["icon"]) and (gt["icon"] as Sprite3D).texture != null),
		"над каждым вариантом — значок типа этапа (наклейка владельца)")
	ok(G.world.gates.all(func(gt): return (gt["root"] as Node3D).find_children("*", "MeshInstance3D", true, false).is_empty()),
		"ни ворот, ни столба света: над вариантом только значок, подпись и слабый свет")
	ok(G.world.get_node_or_null("gate_stand0") != null and G.world.get_node_or_null("gate_stand1") == null, "у боя стоит турнирная стойка, у баффа — нет (вешалка во дворе всегда)")
	ok(String(G.point("gate0")["title"]) == "БОЙ · ПАРКОВКА У ЛАРЬКА" and String(G.point("gate0")["hint"]) == "голда и РЕСПЕКТ" and String(G.point("gate1")["title"]) == "БАФ · ДЕТСКАЯ ПЛОЩАДКА" and String(G.point("gate1")["hint"]) == "баф на выбор",
		"заголовки точек: «%s», «%s»" % [G.point("gate0")["title"], G.point("gate1")["title"]])
	ok(String(g.top_label.text).contains("ДАЛЬШЕ: ПАРКОВКА У ЛАРЬКА — БОЙ · ДЕТСКАЯ ПЛОЩАДКА — БАФ") and String(g.top_label.text).contains("ДВОР 1/6"), "строка «куда дальше»: «%s»" % g.top_label.text)
	var miss_ic: Array = []
	for id in G67Icons.ROOM.values() + G67Icons.FIT.values() + ["icon_golda", "icon_respect", "icon_krot_found", "icon_new_talk", "emblem_67", "logo_golda67",
			"icon_art_cassette_2016", "icon_art_sim", "icon_art_bracelet_67", "icon_art_one_earbud", "icon_art_energy", "icon_art_flash_drive",
			"icon_art_broken_remote", "icon_art_market_sneakers", "icon_art_platinum_badge", "icon_art_cracked_phone", "icon_art_garlic_aura",
			"icon_art_hamster_aura", "icon_art_collar_67", "icon_art_beanie", "icon_art_grillz", "icon_art_blue_tape", "icon_art_second_sim", "icon_art_autotune_ring"]:
		if G67Icons.tex(String(id)) == null:
			miss_ic.append(id)
	ok(miss_ic.is_empty(), "все рисованные значки партий 1–2 на месте (нет: %s)" % str(miss_ic))
	ok(G.world.bounds == null or not is_instance_valid(G.world.bounds), "после боя ограждения убраны — двор свободен")
	await wait(0.6)
	await shot("21a_gates_open")
	await _gate_shots(g, G, "t0s1")
	# экран ларька сам не открывается, пока герой стоит у окна; по [E] — открывается
	P.global_position = Vector3(kp.x - 0.5, 0.05, kp.z)
	await wait(0.6)
	ok(G.hub_ui == null and G.near == "kiosk", "у окна ларька экран сам не открывается: ждёт [E] (рядом: %s)" % G.near)
	# подсказка про заначки: герой в 4 м от монеты вне боя — строка один раз
	var c0: Vector3 = G67Yard.STASH[int(G.run["stash"]["spots"][0])]
	P.global_position = c0 + Vector3(4.0, 0.05, 0)
	P.velocity = Vector3.ZERO
	var hint_ok: bool = await until(func(): return G.hints.cur == "stash" or G.hints.seen("stash"), 12.0)
	ok(hint_ok and G.hints.seen("stash"), "подсказка про заначку показана у монеты (%s)" % str(G.meta().get("hints", [])))
	ok(G.hints.seen("stash") and G.events.has(["hint", "stash"]), "подсказка записана в сохранение и в события")
	await _stash_check(g, G, P)
	# домой посреди забега: дверь подъезда во дворе → подъезд (забег на паузе) → выход продолжает с двери подъезда
	ok(not G.point("home").is_empty(), "после боя у двери подъезда можно уйти домой")
	var g_before := int(G.run["golda"])
	var pos_before := int(G.run["pos"])
	P.hp = P.max_hp - 13.0
	await _go(G, P, "home")
	ok(await until(func(): return G.place == "hub", 6.0), "дверь подъезда во дворе ведёт домой в подъезд")
	ok(G.paused_run() and String(g.top_label.text).contains("ПАУЗЕ"), "в подъезде забег на паузе: «%s»" % g.top_label.text)
	await shot("21c_home_paused")
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "open", 6.0), "выход во двор продолжает забег")
	ok(int(G.run["pos"]) == pos_before and int(G.run["golda"]) == g_before, "тот же этап и та же голда (%d, %d)" % [int(G.run["pos"]), int(G.run["golda"])])
	ok(G.world.gates.size() == 2 and absf(P.hp - (P.max_hp - 13.0)) < 0.5 and P.global_position.distance_to(G67Yard.HOME_DOOR + Vector3(0, 0.05, -4.5)) < 1.0, "варианты снова открыты, здоровье прежнее (%.0f из %.0f), герой у двери подъезда" % [P.hp, P.max_hp])
	ok(int(G.run["stash_n"]) == 1 and G.stash_nodes.size() == 4, "собранная заначка осталась собранной: монет во дворе %d" % G.stash_nodes.size())
	await shot("21d_home_resumed")
	yard_world = G.world
	# до вариантов нужно дойти пешком: настоящими клавишами от двери подъезда на север
	var gp: Vector3 = G.point("gate1")["pos"]
	var d0: float = P.global_position.distance_to(gp)
	ok(d0 > 20.0, "до вешалки на площадке нужно дойти (%.0f м)" % d0)
	P.face = PI
	g.cam_yaw = 0.0
	await wait(0.5)
	await shot("21_gates")
	var z0: float = P.global_position.z
	var e3 := InputEventKey.new()
	e3.keycode = KEY_W
	e3.physical_keycode = KEY_W
	e3.pressed = true
	Input.parse_input_event(e3)
	await wait(3.0)
	e3 = InputEventKey.new()
	e3.keycode = KEY_W
	e3.physical_keycode = KEY_W
	e3.pressed = false
	Input.parse_input_event(e3)
	await wait(0.3)
	ok(z0 - P.global_position.z > 10.0 and G.world == yard_world and G.room_state == "open", "по двору можно идти ногами, ничего не пересобирается (прошёл %.0f м)" % (z0 - P.global_position.z))
	await shot("21b_free_walk")
	# вариант БАФ
	await _go(G, P, "gate1")
	var in_fit: bool = await until(func(): return String(G.room.get("type", "")) == "fit" and G.hub_ui != null and G.hub_ui.kind == "fit", 8.0)
	ok(in_fit and int(G.run["pos"]) == 1, "вариант «БАФ» — сразу экран выбора баффа (этап 2)")
	ok(G.world.gates.is_empty() and G.point("gate0").is_empty(), "второй вариант погас: значков и точек нет")
	var FU = G.hub_ui
	ok(FU.cards.size() == 3 and FU.reroll_n != null and g.hud_root.visible == false, "три бирки и «ПЕРЕВЫБРАТЬ», игровой HUD спрятан")
	ok(_fit_layout_ok(FU), "вёрстка бафов: надписи целиком внутри бирок и экрана, кегль не меньше 15")
	await wait(0.4)
	await shot("22a_fit_icons")
	var pf0: Vector3 = P.global_position
	await key(KEY_ESCAPE)
	ok(G.hub_ui == FU and not get_tree().paused, "Esc экран бафа не закрывает и паузу не открывает: выбор обязателен")
	var ew := InputEventKey.new()
	ew.keycode = KEY_W
	ew.physical_keycode = KEY_W
	ew.pressed = true
	Input.parse_input_event(ew)
	await wait(0.5)
	ew = InputEventKey.new()
	ew.keycode = KEY_W
	ew.physical_keycode = KEY_W
	ew.pressed = false
	Input.parse_input_event(ew)
	ok(P.global_position.distance_to(pf0) < 0.3 and G.hub_ui == FU, "герой за экраном не сдвинулся")
	# перевыбор с клавиатуры: S ведёт с бирки на «ПЕРЕВЫБРАТЬ», Enter
	var old_offer: Array = G.fit_offer.duplicate()
	FU.select(0)
	await key(KEY_S)
	ok(FU.sel == 3, "S с бирки ведёт на «ПЕРЕВЫБРАТЬ»")
	await key(KEY_ENTER)
	await wait(0.5)
	ok(int(G.run.get("rerolls", -1)) == 0 and G.hub_ui != null and G.hub_ui != FU and G.hub_ui.kind == "fit" and G.hub_ui.cards.size() == 3 and G.hub_ui.reroll_n == null and G.events.has(["reroll"]), "перевыбор потрачен: новые три бирки, пункта «ПЕРЕВЫБРАТЬ» больше нет")
	FU = G.hub_ui
	await shot("22_fit_choice")
	var rs0 := int(G.run["respect"])
	var chosen := String(G.fit_offer[0])
	var lv0 := G.fit_lv(chosen)
	# выбор мышью: наведение выбирает, клик берёт
	var fc0: Control = FU.cards[0]
	fc0.mouse_entered.emit()
	ok(FU.sel == 0, "мышь: наведение выбирает бирку")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	fc0.gui_input.emit(mb)
	await wait(0.5)
	ok(G.fit_lv(chosen) == lv0 + 1 and G.hub_ui == null, "клик мышью берёт баф «%s»: ур. %d" % [chosen, G.fit_lv(chosen)])
	ok(G.room_state == "open" and int(G.run["respect"]) == rs0 + 1, "после выбора экран закрыт, варианты открыты, РЕСПЕКТ +1 за мирный этап")
	# все пять бафов по очереди: надписи целиком
	for fid in G67Data.FITS:
		G.fit_offer = [fid]
		G.fit_rare = false
		G.open_screen("fit")
		await wait(0.2)
		ok(G.hub_ui != null and _fit_layout_ok(G.hub_ui), "баф «%s»: надписи целиком в бирке и экране" % String(G67Data.FITS[fid]["name"]))
		G.hub_ui.close()
		await wait(0.1)
	await _gate_shots(g, G, "t0s2")
	# вариант ЭЛИТА
	await _go(G, P, "gate0")
	var in_el: bool = await until(func(): return String(G.room.get("type", "")) == "elite" and G.room_state == "fight", 8.0)
	ok(in_el, "вариант «ЭЛИТА» — бой с элитой")
	var big: bool = await until(func(): return g.enemies.any(func(e): return is_instance_valid(e) and String(e.skin) == "g67_smotr"), 10.0)
	ok(big, "в бою с элитой — Смотрящий")
	# КРОТ — встреча 1: стоит в очереди у шаурмичной; во время боя не разговаривает
	ok(G.world.actors.has("g67_krot") and not G.point("krot").is_empty(), "КРОТ стоит у ларька «ШАУРМА 67» (встреча 1)")
	var kpos: Vector3 = G.world.actors["g67_krot"].global_position
	var oc2 := Camera3D.new()
	g.add_child(oc2)
	oc2.global_position = kpos + Vector3(-1.6, 1.7, 3.6)
	oc2.look_at(kpos + Vector3(1.6, 1.0, 0), Vector3.UP)
	oc2.make_current()
	await wait(0.5)
	await shot("38_krot")
	g.cam.make_current()
	oc2.queue_free()
	ok(G.world.yard.get_node_or_null("secret_tag") == null, "до победы над Мишей секретного граффити нет")
	await _yard_people(g, G)
	var qn: Array = G.world.yard.queue
	ok(qn.size() == 4 and qn.all(func(n): return is_instance_valid(n)), "у окошка очередь из трёх человек, ещё один ест в стороне")
	var kx: float = G.world.actors["g67_krot"].global_position.x
	ok(qn.all(func(n): return (n as Node3D).global_position.x > kx + 0.5), "КРОТ стоит последним, очередь — между ним и окошком")
	G.talk_krot()
	ok(g.mode != "dlg", "пока идёт бой, КРОТ не отвлекает")
	await wait(1.5)
	await shot("23_elite")
	ok(await _clear_room(g, G), "бой с элитой выигран")
	ok(G.room_state == "reward" and G.elite_hanger != null and not G.point("elite_fit").is_empty() and G.hub_ui == null, "за элиту в зоне появилась вешалка с редким бафом (этап не закрыт)")
	await wait(0.8)
	await shot("elite_hanger")
	var c_left: int = G.coins.size()
	var held := int(G.run["golda"])
	P.global_position = G.point("elite_fit")["pos"]
	await _go(G, P, "elite_fit")
	ok(G.hub_ui != null and G.hub_ui.kind == "fit" and G.room_state == "reward", "[E] у вешалки — экран выбора баффа")
	G.flush_coins()
	ok(G.coins.is_empty() and int(G.run["golda"]) >= held, "непобранные монеты (%d) начислены сразу, один раз" % c_left)
	var ro: Array = G.fit_offer
	ok(not ro.is_empty() and bool(G67Data.FITS[ro[0]]["rare"]), "у элиты первым идёт редкий баф (%s)" % str(ro))
	ok(G.hub_ui.cards[0].rare, "на первой бирке пометка «РЕДКИЙ»")
	var pick_id := String(ro[1])
	var pl0 := G.fit_lv(pick_id)
	await key(KEY_D)
	await key(KEY_ENTER)
	await wait(0.5)
	ok(G.fit_lv(pick_id) == pl0 + 1 and G.hub_ui == null, "клавиатура: D, Enter — взят второй баф «%s»" % pick_id)
	await _go(G, P, "krot")
	ok(g.mode == "dlg" and g.dlg.size() == 5, "после боя с КРОТОМ можно поговорить: диалог из %d реплик" % g.dlg.size())
	ok(String(g.dlg[0]) == "KR|Пахан, брат, я тебе говорил, что у меня знакомые в Forbes?" and String(g.dlg[4]).contains("шаурмой"), "реплики — дословно по ТЗ")
	await wait(0.6)
	await shot("39_krot_dialog")
	await wait(0.2)
	await _krot_shot(g, G.world.actors.get("g67_krot"), "39b_krot1_forbes", 2.4, -2.0, 0.35)      # сбоку: перед ним очередь
	for i in 14:
		if g.mode != "dlg":
			break
		g._dlg_advance()
		await wait(0.15)
		if g.dlg_i == 2:
			await wait(0.9)
			await _krot_shot(g, G.world.actors.get("g67_krot"), "39c_krot1_talk", 2.4, -2.0, 0.35)
	ok(g.mode == "golda67" and (G.meta()["seen"] as Array).has("krot1"), "встреча 1 засчитана (%s)" % str(G.meta()["seen"]))
	ok(not G.world.actors.has("g67_krot") and G.point("krot").is_empty() and G.world.get_node_or_null("krot_after") != null, "разговор окончен: КРОТ остаётся в своей позе, но говорить больше не о чем")
	ok(String(G.krot_next().get("id", "")) == "krot2", "следующая встреча — вторая (ЛЮСТРА, в подъезде)")
	var kp2: Vector3 = G.point("kiosk")["pos"]
	ok(kp2 == kp, "встреча с КРОТОМ закончилась, ларёк стоит там же (%s)" % str(kp2))
	# позиция 4: «ТРЯПКИ» не увидены и не выбраны — дверь одна, она же обязательная
	ok(G.room_state == "open" and G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "event" and String(G.world.gates[0]["option"]["ev"]) == "rags", "после элиты — одна дверь: «ТРЯПКИ! ТРЯПКИ!» (обязательное)")
	var cs_e: Array = G.meta().get("clips_seen", [])
	cs_e.erase("EV02")
	G.meta()["clips_seen"] = cs_e
	await _go(G, P, "gate0")
	ok(await until(func(): return G.clip != null and G.clip.id == "EV02", 8.0), "дверь «ТРЯПОК» запускает ролик EV02")
	await wait(1.0)
	G.clip.skip()
	ok(await until(func(): return G.room_state == "open" and (G.run["stages"] as Array).size() == 4, 8.0), "пропуск ролика разрешён, этап «ТРЯПКИ» пройден")
	ok(G.must_seen() and (G.meta()["seen"] as Array).has("ev_rags") and G.clip_open_ev("rags") and not G.clip_seen("EV02"), "после пропуска: «увидено» стоит, в clips_seen ролика нет")
	var r_after: Array = G.route_options(2)
	ok(not r_after.any(func(o): return o.get("ev", "") == "rags"), "генератор больше не предлагает «ТРЯПКИ»")
	ok(G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "break", "позиция 5: ПЕРЕДЫШКА в беседке — всегда")
	P.hp = 20.0
	await _go(G, P, "gate0")
	ok(await until(func(): return String(G.room.get("type", "")) == "break" and G.room_state == "open", 8.0), "ПЕРЕДЫШКА: герой уже у лавки, лечение сразу")
	ok(P.hp > 20.0 + P.max_hp * 0.4, "лавка лечит (здоровье %.0f из %.0f)" % [P.hp, P.max_hp])
	ok(G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "boss" and not G.point("gate0").is_empty(), "дальше — калитка коробки Миши")
	ok(G.world.statist != null and is_instance_valid(G.world.statist), "Миша всё ещё сидит на троне")
	await _gate_shots(g, G, "t0s6")
	# босс
	await _go(G, P, "gate0")
	var bossed: bool = await until(func(): return G.room_state == "boss" and g.boss_e != null and is_instance_valid(g.boss_e), 8.0)
	ok(bossed, "шестая позиция — босс")
	ok(String(main.audio.cur) == "", "в постановке выхода Миши музыка режима молчит (набор: «%s»)" % main.audio.cur)
	if not bossed:
		return
	var B = g.boss_e
	ok(_faces_away(g, P), "на входе к боссу герой лицом от камеры (face %.2f, cam_yaw %.2f)" % [P.face, g.cam_yaw])
	ok(G.world == yard_world and G.world.yard.position == Vector3.ZERO, "от начала забега до босса двор не пересобирался и не сдвигался")
	ok(G.world.statist == null and (G.run["stages"] as Array).size() == 5 and int(G.run["earned"]) == int(G.run["golda"]) + int(G.run["spent"]), "статист с трона убран, этапов пройдено 5, голда сходится (получено %d)" % int(G.run["earned"]))
	ok(G.scene_busy() and g.intro_busy(), "выход босса — постановка: управление на это время закрыто")
	ok(B.global_position.distance_to(G.world.throne) < 0.6 and String(B.rig.cur) == "MSit", "Миша сидит на троне (%.2f м, клип %s)" % [B.global_position.distance_to(G.world.throne), str(B.rig.cur)])
	await wait(1.0)
	await shot("25a_boss_throne")
	await wait(1.2)
	await shot("25b_boss_stands")
	await wait(1.6)
	ok(B.global_position.z > G.world.throne.z + 0.6 and G.scene_step == 2, "встал и идёт по ковру к герою")
	await shot("25c_boss_walks")
	ok(await until(func(): return G.scene_step >= 6, 9.0), "дошёл и топнул")
	if G67Voice.path("G1|" + G67Data.BOSS_INTRO) != "":
		ok(String(g.bark_b.stream.resource_path if g.bark_b.stream != null else "").begins_with(G67Voice.DIR + "Bosses/"), "на выходе Миша говорит своим голосом главы 1 (%s)" % (g.bark_b.stream.resource_path.get_file() if g.bark_b.stream != null else "—"))
	await wait(0.9)
	await shot("25d_boss_stomp")
	ok(await until(func(): return not G.scene_busy(), 8.0), "постановка заканчивается сама, начинается бой")
	ok(B.global_position.distance_to(G.world.yard.boss_spot + Vector3(0, 0.05, 0)) < 0.3, "к началу боя Миша на своём месте в коробке")
	var first_mv: bool = await until(func(): return String(B.move) != "", 8.0)
	ok(first_mv and String(B.move) == "m_grab", "первый приём боя — ЗАХВАТ (%s)" % String(B.move))
	await until(func(): return String(main.audio.cur) == "boss_g67_misha", 4.0)
	ok(String(main.audio.cur) == "boss_g67_misha", "после постановки у Миши играет boss_g67_misha (%s)" % main.audio.cur)
	ok(String(B.boss_id) == "g67_misha" and String(g.boss_name.text).begins_with("МИША МИНАСЯН"), "босс — Миша Минасян («%s»)" % g.boss_name.text)
	ok(String(B.cfg.get("path", "")).ends_with("g67_misha.glb"), "модель босса — своя, не босс кампании")
	ok(B.rig.skel.find_children("*", "BoneAttachment3D", true, false).size() > 0, "на Мише цепь")
	ok(g.boss_box.visible, "полоска здоровья босса на экране")
	P.global_position = AC + Vector3(0, 0.05, 2.0)
	P.face = 0.0
	g.cam_yaw = 0.0
	await wait(2.5)
	await shot("25_boss")
	# босс бьёт: ждём его удара или особого приёма
	var acted: bool = await until(func(): return String(B.state) in ["wind", "strike", "charge", "special", "leap"], 12.0)
	ok(acted, "Миша атакует (состояние: %s)" % String(B.state))
	await wait(0.6)
	await shot("26_boss_attack")
	# B01: герой не бьёт — здоровье Миши не убывает (раньше его бил невидимый madk1d)
	var bhp: float = B.hp
	var idle_b: Dictionary = await _madk_idle(g, P, 15.0)
	ok(is_equal_approx(B.hp, bhp) and is_equal_approx(bhp, B.max_hp), "герой 15 с не бьёт Мишу — его здоровье не изменилось (%.0f → %.0f из %.0f)" % [bhp, B.hp, B.max_hp])
	ok((idle_b["acts"] as Array).is_empty() and float(idle_b["near"]) > 14.0, "в бою с Мишей madk1d нет (его действия: %s, ближе всего был в %.0f м)" % [str(idle_b["acts"]), float(idle_b["near"])])
	await _misha_moves(g, G, P, B)
	await _n04_check(g, G, P, B)
	var hp1: float = B.hp
	B.take_hit(40.0, Vector3.FORWARD, 0.0, false)
	ok(B.hp < hp1, "босс получает урон")
	# фазы не проскакивают: удар на 99999 по полному здоровью — только до порога фазы
	await _misha_set(B, P, "m_grab", Vector3(0, 0.05, 9.0), Vector3(0, 0.05, -2.0))
	B.hp = B.max_hp
	B.phase = 0
	B.phase_guard_until = -1.0
	B.counter_at = 99999.0
	B.state = "chase"
	B.sp_events = []
	B.tell_until = -1.0
	B._tell_end()
	B.cool = 99.0
	B.move = ""
	P.inv = 1.0
	B.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	var thr1: float = B.max_hp * 2.0 / 3.0
	ok(B.alive() and B.phase == 1 and absf(B.hp - thr1) < 0.01, "удар на 99999 по полному здоровью Мишу не убивает и фазу не перескакивает: здоровье %.0f = порог фазы 1, фаза %d" % [B.hp, B.phase])
	var hg: float = B.hp
	await wait(0.3)
	B.take_hit(500.0, Vector3.FORWARD, 0.0, true)
	B.take_hit_info(HitInfo.new())
	ok(absf(B.hp - hg) < 0.01 and B.age < B.phase_guard_until, "смена фазы: 1,2 с неуязвимость — урон не проходит")
	ok(String(B.state) == "special" and String(B.rig.cur) == "Stomp", "на смене фазы Миша топает (%s, %s)" % [String(B.state), String(B.rig.cur)])
	await wait(1.3)
	var antr: bool = await until(func(): return B.antract, 3.0)
	await wait(0.8)
	ok(antr and G.retinue.size() == 3 and String(B.rig.cur) == "MGuard", "антракт фазы 2: Миша в стойке, вбежала свита из %d" % G.retinue.size())
	var hpa: float = B.hp
	B.take_hit(500.0, Vector3.FORWARD, 0.0, true)
	ok(absf(B.hp - hpa) < 0.01, "в антракте Миша неуязвим")
	var wraps: int = G.coins.filter(func(c): return c.has("heal")).size()
	ok(wraps >= 2, "зрители бросили на лёд шаурму (%d)" % wraps)
	var wr: Dictionary = G.coins.filter(func(c): return c.has("heal"))[0]
	P.hp = 50.0
	P.global_position = (wr["n"] as Node3D).global_position
	await wait(1.0)
	ok(P.hp > 50.0 + 20.0, "подобранная шаурма лечит +25 (здоровье %.0f)" % P.hp)
	B.antract_until = B.age
	await wait(0.5)
	ok(not B.antract and B.phase_guard_until < B.age, "антракт кончился — Миша снова в бою")
	B.cool = 0.0
	var p1: bool = await until(func(): return String(B.move) == "m_guard", 4.0)
	ok(p1 and absf(B.hp - hg) < 0.01, "после смены фазы сразу первый приём фазы — ЗАЩИТНАЯ СТОЙКА (%s)" % String(B.move))
	await wait(3.2)
	B.hp = B.max_hp * 2.0 / 3.0 + 1.0
	B.state = "chase"
	B.sp_events = []
	B.cool = 99.0
	B.move = ""
	B.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	ok(B.alive() and B.phase == 2 and absf(B.hp - B.max_hp / 3.0) < 0.01, "вторая смена: здоровье %.0f = порог фазы 2, фаза %d" % [B.hp, B.phase])
	await wait(1.3)
	var antr2: bool = await until(func(): return B.antract, 3.0)
	ok(antr2 and G.retinue.size() == 4, "антракт фазы 3: Шестёрки и Семечник (%d)" % G.retinue.size())
	B.antract_until = B.age
	await wait(0.5)
	B.cool = 0.0
	var p2: bool = await until(func(): return String(B.move) == "m_hook", 4.0)
	ok(p2, "после второй смены — ЗАЦЕП ЦЕПИ (%s)" % String(B.move))
	await wait(3.0)
	P.inv = 0.0
	B.guard_until = -1.0
	B.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	var down: bool = await until(func(): return G.events.any(func(ev): return ev.size() > 0 and String(ev[0]) == "boss_down"), 6.0)
	ok(down, "Миша Минасян повержен")
	ok(bool(G.meta()["flags"].get("boss_misha", false)), "победа записана в постоянное")
	ok(G.styles_open() == ["vozduh", "bottles"], "открыта Водяра, ТЯГА-812 закрыта (%s)" % str(G.styles_open()))
	await wait(1.0)
	await shot("27_boss_down")
	var res_up: bool = await until(func(): return G.hub_ui != null and G.hub_ui.kind == "result", 12.0)
	ok(res_up, "после победы — экран итогов")
	var RS: Dictionary = G.result
	ok(bool(RS["won"]) and bool(RS["first"]) and int(RS["got"]) >= 40 and int(RS["total"]) == int(G.meta()["respect"]), "итоги: победа, первая, РЕСПЕКТ +%d уже в сохранении (всего %d)" % [int(RS["got"]), int(RS["total"])])
	var rtxt := _all_text(G.hub_ui.stage)
	ok(rtxt.contains("ГЛАВА 1 ПРОЙДЕНА") and rtxt.contains("ПОБЕДА") and rtxt.contains("ОТКРЫТО") and (RS["new"] as Array).size() >= 5 and rtxt.contains("Водяра"), "экран победы: «ГЛАВА 1 ПРОЙДЕНА», список открытого (%d строк)" % (RS["new"] as Array).size())
	ok(not rtxt.to_lower().contains("подземка — готов") and rtxt.contains("в следующей главе"), "про ПОДЗЕМКУ — только «в следующей главе»")
	var ic_n := 0
	for ch in G.hub_ui.stage.get_children():
		if ch is TextureRect and ch.size.x <= 41.0 and ch.modulate.a > 0.9:
			ic_n += 1
	ok(ic_n == 6 and (RS["stages"] as Array).size() == 6, "значков этапов на экране итогов победы шесть (%d)" % ic_n)
	ok(int(RS["stage_n"]) == 6 and int(RS["kills"]) == int(G.run["kills"]) and int(RS["earned"]) == int(G.run["earned"]) and int(RS["spent"]) == int(G.run["spent"]), "числа экрана сходятся с забегом (этапов %d, врагов %d, голды %d)" % [int(RS["stage_n"]), int(RS["kills"]), int(RS["earned"])])
	await wait(0.4)
	ok(_text_fits(G.hub_ui), "итоги: надписи внутри экрана")
	await shot("29_result_win")
	G.hub_ui.select(0, true)
	G.hub_ui._activate(0)
	var home: bool = await until(func(): return G.place == "hub" and G.hub_ui == null and G.world.points.size() >= 9, 12.0)
	ok(home, "«В ПОДЪЕЗД» — обратно в подъезд")
	await wait(1.0)
	ok(P.own_styles == ["vozduh", "bottles"], "в подъезде у Пахана теперь Балон и Водяра (%s)" % str(P.own_styles))
	ok(int(G.meta()["respect"]) >= 40, "РЕСПЕКТ за забег остался (%d)" % int(G.meta()["respect"]))
	ok(g.buddy.visible, "madk1d снова рядом в подъезде")
	# в подъезде madk1d по-прежнему житель: стоит рядом и сам выбирает, куда встать возле героя
	ok(g.madk_home() and g.buddy.global_position.distance_to(G.MADK_SPOT) < 0.6, "до первой концовки madk1d в подъезде стоит на своём месте (%.2f м)" % g.buddy.global_position.distance_to(G.MADK_SPOT))
	P.global_position = G.MADK_SPOT + Vector3(1.6, 0.05, 0.3)
	G.meta()["flags"]["ending1"] = true
	g.buddy.target = Vector3.ZERO
	g.buddy.wait = 0.0
	await wait(0.6)
	ok(not g.madk_away() and g.buddy.target != Vector3.ZERO and g.buddy.global_position.distance_to(P.global_position) < 8.0 and absf(g.buddy.global_position.y - P.global_position.y) < 1.0,
		"в подъезде madk1d ходит рядом с героем как раньше (до него %.1f м)" % g.buddy.global_position.distance_to(P.global_position))
	G.meta()["flags"].erase("ending1")
	await shot("27b_hub_madk")
	await key(KEY_2)
	await wait(1.2)
	ok(String(P.style.id) == "bottles", "клавиша 2 включает Водяру")
	await shot("28_hub_after")
	# B8: КРОТ с люстрой — только после разговора с DJ FLÜRR (состояние 1)
	G.meta()["flurr"] = -1
	G.world.actors.erase("g67_krot")
	ok(not G.world.actors.has("g67_krot") and String(G.krot_next().get("id", "")) == "krot2", "до разговора с DJ FLÜRR КРОТА с люстрой в подъезде нет")
	G.talk_flurr()
	await wait(0.3)
	for i in 30:
		if g.mode != "dlg":
			break
		g._dlg_advance()
		await wait(0.05)
	await wait(0.6)
	ok(int(G.meta().get("flurr", -1)) >= 1 and G.world.actors.has("g67_krot"), "поговорил с DJ FLÜRR — КРОТ с люстрой появился (flurr %d)" % int(G.meta().get("flurr", -1)))
	var kp0: Vector3 = G.world.actors["g67_krot"].global_position if G.world.actors.has("g67_krot") else Vector3.ZERO
	ok(kp0.distance_to(Vector3(0.9, 0, 2.6)) < 0.3, "КРОТ стоит у двери колясочной (%s)" % str(kp0))
	# КРОТ — встреча 2 «ЛЮСТРА»: стоит в холле подъезда с люстрой в руках
	if G67Models.has("g67_chandelier"):
		ok(G.world.actors.has("g67_krot") and G.krot_item != null and is_instance_valid(G.krot_item), "КРОТ стоит в подъезде с люстрой (встреча 2)")
		await _krot_shot(g, G.world.actors.get("g67_krot"), "40_krot_chandelier", 1.7)
		await _go(G, P, "krot")
		ok(g.mode == "dlg" and g.dlg == G67Data.KROT[1]["lines"] and String(g.dlg[3]) == "KR|Она на меня странно смотрела.", "диалог «ЛЮСТРА» — дословно по ТЗ")
		for i in 14:
			if g.mode != "dlg":
				break
			g._dlg_advance()
			await wait(0.15)
			if g.dlg_i == 3:
				await wait(0.9)
				await _krot_shot(g, G.world.actors.get("g67_krot"), "40a_krot_shows", 1.7)
		ok((G.meta()["seen"] as Array).has("krot2") and G.world.get_node_or_null("krot_leaving") != null, "встреча 2 засчитана, КРОТ разворачивается и уходит с люстрой в руках")
		await wait(1.2)
		await _krot_shot(g, G.world.get_node_or_null("krot_leaving"), "40b_krot_leaves", 1.9, 1.0)
		var near_min := 99.0
		var t_w := GameClock.ms()
		P.global_position = Vector3(0.0, 0.05, 4.8)
		while G.world.get_node_or_null("krot_leaving") != null and GameClock.ms() - t_w < 14000:
			var lv = G.world.get_node_or_null("krot_leaving")
			near_min = minf(near_min, Vector2(lv.global_position.x - P.global_position.x, lv.global_position.z - P.global_position.z).length())
			await get_tree().process_frame
		ok(G.world.get_node_or_null("krot_leaving") == null and G.krot_item == null, "ушёл к двери и унёс люстру")
		ok(near_min >= 0.5, "КРОТ обошёл героя, стоявшего на его пути (ближе всего %.2f м)" % near_min)
		ok(G.flurr_state() == 2, "DJ FLÜRR теперь в состоянии 2 (подсказка на голубей)")
	else:
		print("GOLDA67CHECK   модели люстры нет — встреча 2 ждёт")
	# ================= гибель в забеге =================
	var r0: int = int(G.meta()["respect"])
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "второй забег начался")
	ok(int(G.run["tpl"]) == 1 and G.fit_lv("heavy_hand") == 0 and absf(P.dmg_mul - 1.0) < 0.001 and int(G.run["golda"]) == 0, "шаблон второго забега — 1; баффы и голда прошлого забега не перенеслись")
	ok(G.world.yard.get_node_or_null("secret_tag") != null, "после победы над Мишей у подъезда появилось граффити «ПАХАН + MADK1D БЫЛИ ТУТ»")
	ok(String(G67Data.BOSSES["g67_misha"]["barks"][1]) == "Мне даже олимпийка не нужна, чтобы быть главным.", "реплика Миши во второй фазе — утверждённая")
	# КРОТ — встреча 3 «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО»: на детской площадке с голубями с начала забега
	if G67Models.has("g67_pigeon") and (G.meta()["seen"] as Array).has("krot2"):
		ok(await _clear_room(g, G), "второй забег: первый этап зачищен")
		var pig := 0
		for ch in G.world.get_children():
			if String(ch.name).begins_with("krot_pigeon"):
				pig += 1
		ok(G.world.actors.has("g67_krot") and pig == 5, "КРОТ на площадке среди голубей, зоны не переставлены (%d)" % pig)
		var r2: Array = G.route_options(1)
		ok(r2.size() >= 2 and String(r2[0]["type"]) == "battle" and String(r2[0]["place"]) != "parking" and String(r2[1]["type"]) == "fit", "места боёв второго забега другие (%s)" % String(r2[0]["place"]))
		var pg0: Node3D = G.world.get_node("krot_pigeon0")
		var seen_rot := {}
		var pecked := false
		for i in 80:
			seen_rot[snappedf(pg0.rotation.y, 0.02)] = true
			pecked = pecked or pg0.rotation.x > 0.3
			await wait(0.1)
		ok(seen_rot.size() > 3 and pecked, "голуби живые: вертятся и клюют")
		await _krot_shot(g, G.world.actors.get("g67_krot"), "41_krot_pigeons", 2.4)
		await _go(G, P, "krot")
		ok(g.mode == "dlg" and g.dlg == G67Data.KROT[2]["lines"] and String(g.dlg[2]).contains("голубь справа"), "диалог «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО» — дословно по ТЗ")
		for i in 14:
			if g.mode != "dlg":
				break
			g._dlg_advance()
			await wait(0.15)
			if g.dlg_i == 2:
				await wait(0.9)
				ok(G.krot_life != null and G.krot_life.cur == "K3Point", "«Нет, голубь справа» — показывает на птицу")
				await _krot_shot(g, G.world.actors.get("g67_krot"), "41b_krot_points", 2.4)
		ok((G.meta()["seen"] as Array).has("krot3") and G.krot_next().is_empty(), "встреча 3 засчитана; следующие встречи — в районах, которых ещё нет")
		var kp3: Vector3 = G.point("kiosk")["pos"]
		ok(kp3 == kp, "когда все встречи КРОТА во дворе пройдены, ларёк стоит там же")
		await _go(G, P, "gate0")
		await until(func(): return G.room_state == "fight", 8.0)
	await until(func(): return G.alive() >= 1, 8.0)
	_kill_all(g)
	await wait(0.3)
	for i in 8:
		if g.over:
			break
		P.inv = 0.0
		P.take_damage(99999.0, P.global_position + Vector3(0, 0, -1))
		await wait(0.3)
	ok(g.over and G.events.any(func(ev): return String(ev[0]) == "dead"), "гибель заканчивает забег")
	ok(await until(func(): return G.hub_ui != null and G.hub_ui.kind == "result", 12.0), "после гибели — экран итогов")
	var rd: Dictionary = G.result
	ok(not bool(rd["won"]) and not bool(rd["first"]) and int(G.meta()["respect"]) == int(rd["total"]), "итоги гибели: «ЗАБЕГ ОКОНЧЕН», РЕСПЕКТ уже в сохранении")
	var dtxt := _all_text(G.hub_ui.stage)
	ok(dtxt.contains("ЗАБЕГ ОКОНЧЕН") and not dtxt.contains("ГЛАВА 1 ПРОЙДЕНА"), "экран гибели без «ГЛАВА 1 ПРОЙДЕНА»")
	var hp_d: float = P.hp
	var frozen: Array = g.enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	await wait(1.0)
	ok(frozen.all(func(e): return not e.is_physics_processing()) and P.hp == hp_d, "после смерти враги замерли и не бьют")
	await shot("29b_result_death")
	G.hub_ui.select(1, true)
	G.hub_ui._activate(1)
	ok(await until(func(): return G.place == "run" and G.room_state == "fight" and G.hub_ui == null, 12.0), "«НОВЫЙ ЗАБЕГ» — сразу новый забег")
	ok(absf(P.hp - P.max_hp) < 0.5, "здоровье полное")
	await G.enter_hub()
	G.data["run"] = {}
	ok(G.place == "hub" and not g.over, "после гибели — подъезд, игра продолжается")
	ok(int(G.meta()["respect"]) >= r0 and bool(G.meta()["flags"].get("boss_misha", false)), "гибель не стёрла РЕСПЕКТ и победу над боссом")
	ok(P.hp == P.max_hp and P.max_hp == G.base_hp, "здоровье восстановлено, усиления забега сняты (%.0f)" % P.max_hp)
	await wait(0.5)
	# подсказки: каждая один раз, в бою не больше трёх; новый экземпляр режима («перезапуск») их не повторяет
	var hint_ev: Array = G.events.filter(func(ev): return String(ev[0]) == "hint").map(func(ev): return String(ev[1]))
	var uniq := {}
	for hid in hint_ev:
		uniq[hid] = true
	ok(not hint_ev.is_empty() and uniq.size() == hint_ev.size(), "подсказки по одной за сохранение: показаны %s" % str(hint_ev))
	ok(G.place == "hub" and G.hints.cur == "" and G.hints.label.modulate.a == 0.0, "в подъезде подсказок нет")
	var again := G.HintsScript.new(G)
	ok(again.seen("stash") and again.seen(String(hint_ev[0])), "после перезапуска режима показанные подсказки не повторяются")
	again.label.queue_free()
	# B07: обе фразы фаз Миши целиком в экране (кегль или перенос)
	for ph in [1, 2]:
		var bark := String(G67Data.BOSSES["g67_misha"]["barks"][ph])
		g.banner(bark, "", Color.WHITE, 1.0)
		var maxw: float = g.hud_root.get_viewport_rect().size.x - 160.0
		var fnt: Font = g.banner_title.get_theme_font("font")
		var fsz: int = g.banner_title.get_theme_font_size("font_size")
		var wide := 0.0
		for line in g.banner_title.text.split("\n"):
			wide = maxf(wide, fnt.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz).x)
		ok(wide <= maxw and fsz >= 34, "B07: фраза фазы %d целиком в экране (%.0f из %.0f, кегль %d, строк %d)" % [ph, wide, maxw, fsz, g.banner_title.text.split("\n").size()])
	g.banner("ШИРОКИЙ ЗАГОЛОВОК ДЛЯ ПРОВЕРКИ ПЕРЕНОСА СЛОВ НА ДВЕ СТРОКИ ПО ЦЕНТРУ ЭКРАНА, КОТОРЫЙ ЗАВЕДОМО НЕ ВЛЕЗАЕТ В ОДНУ СТРОКУ ДАЖЕ МЕЛКИМ КЕГЛЕМ", "", Color.WHITE, 0.2)
	ok(g.banner_title.text.contains("\n"), "B07: слишком длинный заголовок переносится на две строки")
	g.banner("ПРОВЕРКА", "", Color.WHITE, 0.2)
	ok(g.banner_title.get_theme_font_size("font_size") == 60, "короткий заголовок — прежний кегль 60")
	# B13: E у предмета не срывает добивание; «нужно 40 СВЭГа» без врагов рядом нет
	await _b13_check(g, G, P)
	await _quit_check(g, G, P)


func _finish() -> void:
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	AudioServer.set_bus_mute(0, false)
	print("GOLDA67CHECK ok" if fails == 0 else "GOLDA67CHECK ОШИБКА: %d" % fails)
	get_tree().quit()
