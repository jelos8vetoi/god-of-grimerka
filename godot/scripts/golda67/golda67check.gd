## Проверка приквела «ГОЛДА 67»: `--resolution 1280x720 -- --golda67check=<папка>`.
## Идёт из главного меню как игрок: PLAY → вторая карточка «ГОЛДА 67» → экран режима → подъезд. Проверяет порядок
## режимов, запуск, хаб из моделей (ни одной пропавшей), ходьбу настоящими клавишами, предметы и подсказку [E],
## что сохранение кампании не изменилось, и возврат в меню на карточку приквела.
extends Node

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
	ok(G.events.size() > n0 and G.events[-1] == ["use", "tv"], "клавиша E у телевизора срабатывает")
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
	# ================= dj flürr: одиннадцать состояний =================
	await _madk_check(g, G, P)
	await _flurr_check(g, G, P)
	# ================= забег: район ДВОР =================
	await _run_dvor(g, G, P)
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
		await _yard_shot(g, G, p + Vector3(0, float(who["h"]) * 0.55, 0), p + fw * 2.6 + Vector3(-fw.z, 0, fw.x) * 1.0 + Vector3(0, 1.3, 0), "50_" + String(who["id"]).trim_prefix("g67_"))
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

## Поставить Мишу и героя и запустить приём (сам он в это время ничего не выбирает)
func _misha_set(B, P, move: String, ppos: Vector3, bpos := Vector3(0, 0.05, -2.0)) -> void:
	B.state = "chase"
	B.cool = 99.0
	B.special_cd = 99.0
	B.guard_until = -1.0
	B.weak_t = 0.0
	B.global_position = bpos
	B.velocity = Vector3.ZERO
	P.global_position = ppos
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
	# --- ЗАХВАТ: блок не спасает
	await _misha_set(B, P, "m_grab", Vector3(0, 0.05, 0.0))
	ok(String(B.state) == "special" and B.tell.visible and bool(B.sp_lock), "ЗАХВАТ: подготовка с меткой-сектором на земле")
	_press("block", true)
	await wait(0.55)
	await _side_shot(g, B, "26a_misha_grab")
	var f0: float = B.face
	await wait(0.75)
	_press("block", false)
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
	P.global_position = Vector3(3.5, 0.05, 4.0)                        # ушёл с полосы
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
	var bar: Vector3 = G.world.hook_points[0]
	var side := Vector3(1, 0, 0) if bar.x < 0.0 else Vector3(-1, 0, 0)
	await _misha_set(B, P, "m_hook", bar - side * 1.0 + Vector3(0, 0.05, 0), bar + side * 6.0 + Vector3(0, 0.05, 0))
	await wait(0.3)
	P.global_position = Vector3(0, 0.05, 6.0)
	await wait(G67Misha.HOOK_WARN - 0.3 + 0.25)
	ok(String(B.hook_log[-1]) == "bars", "если полоса идёт мимо турника — цепь цепляется за турник")
	await wait(0.2)
	await shot("26e_misha_hook_bars")
	await wait(2.4)
	B.global_position = Vector3(0, 0.05, -2.0)
	P.global_position = Vector3(0, 0.05, 3.0)
	P.hp = P.max_hp
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

## убить всех живых врагов (бой проверяют проверки боя; здесь — цикл комнат)
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

func _run_dvor(g, G: Golda67, P) -> void:
	# выход во двор — настоящей клавишей E у входной двери
	await _go(G, P, "exit")
	var started: bool = await until(func(): return G.place == "run" and G.room_state == "fight", 8.0)
	ok(started, "выход из подъезда начинает забег (место: %s, комната: %s)" % [G.place, G.room.get("type", "")])
	if not started:
		return
	ok(not g.buddy.visible, "до первой концовки madk1d остаётся в подъезде — в забеге его нет")
	ok(String(g.top_label.text).contains("ДВОР 1/6"), "строка вверху: «%s»" % g.top_label.text)
	var got: bool = await until(func(): return G.alive() >= 3, 10.0)
	ok(got, "первая волна вышла (%d врагов)" % G.alive())
	var skins: Array = []
	for e in g.enemies:
		if is_instance_valid(e):
			skins.append(String(e.skin))
	ok(not skins.is_empty() and skins.all(func(x): return String(x).begins_with("g67_")), "враги двора — модели приквела (%s)" % ", ".join(skins))
	ok(G.world.bounds != null and G.world.bounds.get_child_count() > 20, "на время боя площадка огорожена видимыми ограждениями (%d частей)" % (G.world.bounds.get_child_count() if G.world.bounds != null else 0))
	await wait(1.5)
	await shot("20_dvor_fight")
	# обзор двора сверху и с крыш — планировка целиком (своя камера, игровую не трогаем)
	var oc := Camera3D.new()
	oc.fov = 50.0
	oc.far = 400.0
	g.add_child(oc)
	var yo: Vector3 = G.world.yard.position
	for v in [["30_yard_from_south", Vector3(0, 46, 78), Vector3(0, 0, -12)], ["31_yard_from_northeast", Vector3(62, 40, -72), Vector3(-4, 0, -6)],
			["32_yard_top", Vector3(0.1, 118, -8), Vector3(0, 0, -9)], ["33_court_from_roof", Vector3(-22, 20, -20), Vector3(4, 0, -40)],
			["34_podezd_from_yard", Vector3(4, 5, 8), Vector3(0, 3, 34)], ["35_garages_lane", Vector3(-30, 4, 24), Vector3(-42, 1.5, -4)],
			["36_playground", Vector3(-12, 5, 6), Vector3(3, 2, -9)], ["37_parking_kiosk", Vector3(22, 5, 22), Vector3(38, 1.5, 6)]]:
		oc.global_position = (v[1] as Vector3) + yo
		oc.look_at((v[2] as Vector3) + yo, Vector3.UP)
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
	ok(not G.world.actors.has("g67_krot"), "у подъезда КРОТА нет: его встреча — у шаурмичной")
	ok(await _clear_room(g, G), "комната 1 (БОЙ) зачищена")
	ok(G.world.gates.any(func(gt): return String(gt["option"]["place"]) == "parking"), "пока встреча 1 не пройдена, одна из дверей ведёт на парковку к ларьку")
	ok(int(G.run["golda"]) > 0 and int(G.run["respect"]) > 0, "за комнату дали голду (%d) и РЕСПЕКТ (%d)" % [int(G.run["golda"]), int(G.run["respect"])])
	ok(G.room_state == "open" and G.world.gates.size() == 2, "после боя открылись две двери на выбор (%d)" % G.world.gates.size())
	ok(G.world.bounds == null or not is_instance_valid(G.world.bounds), "после боя ограждения убраны — двор свободен")
	# ворота стоят у входов в следующие зоны: идём к ним по двору настоящими клавишами
	var gp: Vector3 = G.point("gate1")["pos"]
	var d0: float = P.global_position.distance_to(gp)
	ok(d0 > 6.0, "до ворот нужно дойти (%.0f м)" % d0)
	P.global_position = Vector3(6.0, 0.05, 0)      # мимо ворот площадки, которые стоят прямо по тропинке
	P.face = 0.0
	g.cam_yaw = 0.0
	await wait(0.5)
	await shot("21_gates")
	var e3 := InputEventKey.new()
	e3.keycode = KEY_W
	e3.physical_keycode = KEY_W
	e3.pressed = true
	Input.parse_input_event(e3)
	await wait(6.5)
	e3 = InputEventKey.new()
	e3.keycode = KEY_W
	e3.physical_keycode = KEY_W
	e3.pressed = false
	Input.parse_input_event(e3)
	await wait(0.3)
	ok(P.global_position.z < -G67Yard.HALF - 1.0, "за пределы бывшей зоны боя можно выйти (z = %.1f)" % P.global_position.z)
	await shot("21b_free_walk")
	# дверь ФИТС
	await _go(G, P, "gate1")
	var in_fit: bool = await until(func(): return String(G.room.get("type", "")) == "fit" and g.panel != null, 8.0)
	ok(in_fit and int(G.run["pos"]) == 1, "дверь «ФИТС» ведёт в комнату выбора фитса")
	await wait(0.5)
	await shot("22_fit_choice")
	var opts: Array = G.fit_options(false)
	ok(opts.size() == 3, "на выбор три фитса (%s)" % ", ".join(opts))
	G.take_fit("heavy_hand")
	ok(G.fit_lv("heavy_hand") == 1 and absf(P.dmg_mul - 1.12) < 0.001, "«ТЯЖЁЛАЯ РУКА»: урон ×%.2f" % P.dmg_mul)
	ok(g.panel == null and G.room_state == "open", "после выбора окно закрыто, двери открыты")
	# дверь ЭЛИТА
	await _go(G, P, "gate0")
	var in_el: bool = await until(func(): return String(G.room.get("type", "")) == "elite" and G.room_state == "fight", 8.0)
	ok(in_el, "дверь «ЭЛИТА» ведёт в бой с элитой")
	var big: bool = await until(func(): return g.enemies.any(func(e): return is_instance_valid(e) and String(e.skin) == "g67_smotr"), 10.0)
	ok(big, "в комнате элиты — Смотрящий")
	# КРОТ — встреча 1: стоит в очереди у шаурмичной; во время боя не разговаривает
	ok(String(G.room.get("place", "")) == "parking" and G.world.actors.has("g67_krot") and not G.point("krot").is_empty(), "КРОТ стоит у ларька «ШАУРМА 67» (встреча 1)")
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
	ok(await _clear_room(g, G), "комната элиты зачищена")
	ok(g.panel != null and G.room_state == "reward", "за элиту — выбор фитса")
	var ro: Array = G.fit_options(true)
	ok(not ro.is_empty() and bool(G67Data.FITS[ro[0]]["rare"]), "у элиты первым идёт редкий фитс (%s)" % str(ro))
	var mhp: float = P.max_hp
	G.take_fit("authority")
	ok(P.max_hp == mhp + 20.0, "«АВТОРИТЕТ»: максимум здоровья %.0f → %.0f" % [mhp, P.max_hp])
	await _go(G, P, "krot")
	ok(g.mode == "dlg" and g.dlg.size() == 5, "после боя с КРОТОМ можно поговорить: диалог из %d реплик" % g.dlg.size())
	ok(String(g.dlg[0]) == "KR|Пахан, брат, я тебе говорил, что у меня знакомые в Forbes?" and String(g.dlg[4]).contains("шаурмой"), "реплики — дословно по ТЗ")
	await wait(0.6)
	await shot("39_krot_dialog")
	for i in 14:
		if g.mode != "dlg":
			break
		g._dlg_advance()
		await wait(0.15)
	ok(g.mode == "golda67" and (G.meta()["seen"] as Array).has("krot1"), "встреча 1 засчитана (%s)" % str(G.meta()["seen"]))
	ok(not G.world.actors.has("g67_krot") and G.point("krot").is_empty() and G.world.get_node_or_null("krot_after") != null, "разговор окончен: КРОТ остаётся в своей позе, но говорить больше не о чем")
	ok(String(G.krot_next().get("id", "")) == "krot2", "следующая встреча — вторая (ЛЮСТРА, в подъезде)")
	# дверь БОЙ (позиция 4), затем передышка
	await _go(G, P, "gate1")
	ok(await until(func(): return String(G.room.get("type", "")) == "battle" and G.room_state == "fight" and int(G.run["pos"]) == 3, 8.0), "четвёртая позиция — бой")
	ok(await _clear_room(g, G, 60.0), "комната 4 зачищена")
	ok(G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "break", "перед боссом одна дверь — ПЕРЕДЫШКА")
	await _go(G, P, "gate0")
	ok(await until(func(): return G.room_state == "rest", 8.0), "комната передышки")
	P.hp = 20.0
	await wait(0.4)
	await shot("24_break")
	await _go(G, P, "rest")
	await wait(0.4)
	ok(P.hp > 20.0 + P.max_hp * 0.4, "лавка лечит (здоровье %.0f из %.0f)" % [P.hp, P.max_hp])
	ok(G.world.gates.size() == 1 and String(G.world.gates[0]["option"]["type"]) == "boss", "дальше одна дверь — БОСС")
	# босс
	await _go(G, P, "gate0")
	var bossed: bool = await until(func(): return G.room_state == "boss" and g.boss_e != null and is_instance_valid(g.boss_e), 8.0)
	ok(bossed, "шестая позиция — босс")
	if not bossed:
		return
	var B = g.boss_e
	ok(G.scene_busy() and g.intro_busy(), "выход босса — постановка: управление на это время закрыто")
	ok(B.global_position.distance_to(G.world.throne) < 0.6 and String(B.rig.cur) == "MSit", "Миша сидит на троне (%.2f м, клип %s)" % [B.global_position.distance_to(G.world.throne), str(B.rig.cur)])
	await wait(1.0)
	await shot("25a_boss_throne")
	await wait(1.2)
	await shot("25b_boss_stands")
	await wait(1.6)
	ok(B.global_position.z > G.world.throne.z + 0.6 and G.scene_step == 2, "встал и идёт по ковру к герою")
	await shot("25c_boss_walks")
	ok(await until(func(): return G.scene_step >= 3, 4.0), "дошёл и топнул")
	await wait(0.9)
	await shot("25d_boss_stomp")
	ok(await until(func(): return not G.scene_busy(), 8.0), "постановка заканчивается сама, начинается бой")
	ok(B.global_position.distance_to(Vector3(0, 0.05, -6.6)) < 0.3, "к началу боя Миша на своём месте в коробке")
	ok(String(B.boss_id) == "g67_misha" and String(g.boss_name.text).begins_with("МИША МИНАСЯН"), "босс — Миша Минасян («%s»)" % g.boss_name.text)
	ok(String(B.cfg.get("path", "")).ends_with("g67_misha.glb"), "модель босса — своя, не босс кампании")
	ok(B.rig.skel.find_children("*", "BoneAttachment3D", true, false).size() > 0, "на Мише цепь")
	ok(g.boss_box.visible, "полоска здоровья босса на экране")
	P.global_position = Vector3(0, 0.05, 2.0)
	P.face = 0.0
	g.cam_yaw = 0.0
	await wait(2.5)
	await shot("25_boss")
	# босс бьёт: ждём его удара или особого приёма
	var acted: bool = await until(func(): return String(B.state) in ["wind", "strike", "charge", "special", "leap"], 12.0)
	ok(acted, "Миша атакует (состояние: %s)" % String(B.state))
	await wait(0.6)
	await shot("26_boss_attack")
	await _misha_moves(g, G, P, B)
	var hp1: float = B.hp
	B.take_hit(40.0, Vector3.FORWARD, 0.0, false)
	ok(B.hp < hp1, "босс получает урон")
	B.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	var down: bool = await until(func(): return G.events.any(func(ev): return ev.size() > 0 and String(ev[0]) == "boss_down"), 6.0)
	ok(down, "Миша Минасян повержен")
	ok(bool(G.meta()["flags"].get("boss_misha", false)), "победа записана в постоянное")
	ok(G.styles_open() == ["vozduh", "bottles"], "открыта Водяра, ТЯГА-812 закрыта (%s)" % str(G.styles_open()))
	await wait(1.0)
	await shot("27_boss_down")
	var home: bool = await until(func(): return G.place == "hub" and G.world.points.size() >= 9, 12.0)
	ok(home, "после победы — обратно в подъезд")
	await wait(1.0)
	ok(P.own_styles == ["vozduh", "bottles"], "в подъезде у Пахана теперь Балон и Водяра (%s)" % str(P.own_styles))
	ok(int(G.meta()["respect"]) >= 40, "РЕСПЕКТ за забег остался (%d)" % int(G.meta()["respect"]))
	ok(g.buddy.visible, "madk1d снова рядом в подъезде")
	await key(KEY_2)
	await wait(1.2)
	ok(String(P.style.id) == "bottles", "клавиша 2 включает Водяру")
	await shot("28_hub_after")
	# КРОТ — встреча 2 «ЛЮСТРА»: стоит в холле подъезда с люстрой в руках
	if G67Models.has("g67_chandelier"):
		ok(G.world.actors.has("g67_krot") and G.krot_item != null and is_instance_valid(G.krot_item), "КРОТ стоит в подъезде с люстрой (встреча 2)")
		var k2: Vector3 = G.world.actors["g67_krot"].global_position
		var oc3 := Camera3D.new()
		g.add_child(oc3)
		var kf: Vector3 = G.world.actors["g67_krot"].global_transform.basis.z
		oc3.global_position = k2 + kf * 2.2 + Vector3(kf.z, 0, -kf.x) * 0.9 + Vector3(0, 1.25, 0)      # спереди-сбоку
		oc3.look_at(k2 + Vector3(0, 0.85, 0), Vector3.UP)
		oc3.make_current()
		await wait(0.6)
		await shot("40_krot_chandelier")
		g.cam.make_current()
		oc3.queue_free()
		await _go(G, P, "krot")
		ok(g.mode == "dlg" and g.dlg == G67Data.KROT[1]["lines"] and String(g.dlg[3]) == "KR|Она на меня странно смотрела.", "диалог «ЛЮСТРА» — дословно по ТЗ")
		for i in 14:
			if g.mode != "dlg":
				break
			g._dlg_advance()
			await wait(0.15)
		ok((G.meta()["seen"] as Array).has("krot2") and G.world.get_node_or_null("krot_leaving") != null, "встреча 2 засчитана, КРОТ разворачивается и уходит с люстрой в руках")
		await wait(1.2)
		await shot("40b_krot_leaves")
		ok(await until(func(): return G.world.get_node_or_null("krot_leaving") == null and G.krot_item == null, 5.0), "ушёл и унёс люстру")
		ok(G.flurr_state() == 2, "DJ FLÜRR теперь в состоянии 2 (подсказка на голубей)")
	else:
		print("GOLDA67CHECK   модели люстры нет — встреча 2 ждёт")
	# ================= гибель в забеге =================
	var r0: int = int(G.meta()["respect"])
	await _go(G, P, "exit")
	ok(await until(func(): return G.place == "run" and G.room_state == "fight", 8.0), "второй забег начался")
	ok(G.fit_lv("heavy_hand") == 0 and absf(P.dmg_mul - 1.0) < 0.001 and int(G.run["golda"]) == 0, "фитсы и голда прошлого забега не перенеслись")
	ok(G.world.yard.get_node_or_null("secret_tag") != null, "после победы над Мишей у подъезда появилось граффити «ПАХАН + MADK1D БЫЛИ ТУТ»")
	ok(String(G67Data.BOSSES["g67_misha"]["barks"][1]) == "Мне даже олимпийка не нужна, чтобы быть главным.", "реплика Миши во второй фазе — утверждённая")
	# КРОТ — встреча 3 «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО»: на детской площадке, с голубями
	if G67Models.has("g67_pigeon") and (G.meta()["seen"] as Array).has("krot2"):
		ok(await _clear_room(g, G), "второй забег: первая комната зачищена")
		await _go(G, P, "gate1")
		ok(await until(func(): return String(G.room.get("place", "")) == "playground" and g.panel != null, 8.0), "дверь ведёт на детскую площадку")
		G.take_fit(G.fit_options(false)[0])
		var pig := 0
		for ch in G.world.get_children():
			if String(ch.name).begins_with("krot_pigeon"):
				pig += 1
		ok(G.world.actors.has("g67_krot") and pig == 5, "КРОТ на площадке среди голубей (%d)" % pig)
		var pg0: Node3D = G.world.get_node("krot_pigeon0")
		var seen_rot := {}
		var pecked := false
		for i in 80:
			seen_rot[snappedf(pg0.rotation.y, 0.02)] = true
			pecked = pecked or pg0.rotation.x > 0.3
			await wait(0.1)
		ok(seen_rot.size() > 3 and pecked, "голуби живые: вертятся и клюют")
		var k3: Vector3 = G.world.actors["g67_krot"].global_position
		var oc4 := Camera3D.new()
		g.add_child(oc4)
		oc4.global_position = k3 + Vector3(2.4, 1.2, 2.8)
		oc4.look_at(k3 + Vector3(0, 0.6, 0), Vector3.UP)
		oc4.make_current()
		await wait(0.6)
		await shot("41_krot_pigeons")
		g.cam.make_current()
		oc4.queue_free()
		await _go(G, P, "krot")
		ok(g.mode == "dlg" and g.dlg == G67Data.KROT[2]["lines"] and String(g.dlg[2]).contains("голубь справа"), "диалог «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО» — дословно по ТЗ")
		for i in 14:
			if g.mode != "dlg":
				break
			g._dlg_advance()
			await wait(0.15)
		ok((G.meta()["seen"] as Array).has("krot3") and G.krot_next().is_empty(), "встреча 3 засчитана; следующие встречи — в районах, которых ещё нет")
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
	ok(await until(func(): return G.place == "hub" and not g.over, 12.0), "после гибели — подъезд, игра продолжается")
	ok(int(G.meta()["respect"]) >= r0 and bool(G.meta()["flags"].get("boss_misha", false)), "гибель не стёрла РЕСПЕКТ и победу над боссом")
	ok(P.hp == P.max_hp and P.max_hp == G.base_hp, "здоровье восстановлено, усиления забега сняты (%.0f)" % P.max_hp)
	await wait(0.5)

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
