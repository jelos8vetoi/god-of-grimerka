## РЕМОНТ ТЕХНИКИ — 3D на рабочем столе Пахана: камера над столом (крупный план, A/D или перетаскивание — вращать
## устройство). Заказы по уровню: смартфон, наушники, игровая приставка, ноутбук, «умный» чайник — у каждого свои
## детали и своя неисправность. Порядок: осмотр (симптом) → отвёртка [1]: открутить винты (клик по каждому) →
## крышка снимается → тестер [2]: проверить детали (клик), неисправная — красная → пинцет [3]: вынуть её и выбрать
## замену в лотке (лишние детали — похожие, но не те) → сборка (винты обратно) → включение: [пробел] в зелёной зоне.
## Не тот инструмент — потеря времени; не та деталь — минус к качеству и деньги на запчасть.
## Навыки: быстрая диагностика (тестер быстрее), лупа (снаряжение 2+: неисправное подсвечено), тестер (3+: мгновенно),
## «мастер на все руки» — один клик откручивает все винты.
class_name MLJobRepair
extends MLJob3D

const DEVICES := [
	{"name": "СМАРТФОН", "parts": ["АККУМУЛЯТОР", "ШЛЕЙФ ЭКРАНА", "РАЗЪЁМ ЗАРЯДКИ", "ДИНАМИК"], "sym": ["греется и выключается на 30%", "экран чёрный, а звук есть", "не заряжается, гнездо шатается", "собеседника не слышно"], "screws": 4},
	{"name": "НАУШНИКИ", "parts": ["ПРАВЫЙ ДИНАМИК", "ПРОВОД", "ПЛАТА BLUETOOTH", "АККУМУЛЯТОР"], "sym": ["справа тишина", "хрипит, если пошевелить провод", "не находит телефон", "садятся за час"], "screws": 4},
	{"name": "ИГРОВАЯ ПРИСТАВКА", "parts": ["ВЕНТИЛЯТОР", "БЛОК ПИТАНИЯ", "HDMI-ПОРТ", "ОПЕРАТИВКА"], "sym": ["шумит и выключается", "не включается вовсе", "нет картинки на телевизоре", "зависает в меню"], "screws": 6},
	{"name": "НОУТБУК", "parts": ["ВИДЕОЧИП", "МАТРИЦА", "КЛАВИАТУРА", "SSD"], "sym": ["полосы на экране", "экран тёмный, подсветка мигает", "не печатаются буквы", "пишет «нет загрузочного диска»"], "screws": 6},
	{"name": "УМНЫЙ ЧАЙНИК", "parts": ["ТЭН", "ПЛАТА WI-FI", "ДАТЧИК", "КНОПКА"], "sym": ["не греет", "не подключается к телефону", "кипит без остановки", "не нажимается"], "screws": 4},
]
const TOOLS := ["ОТВЁРТКА", "ТЕСТЕР", "ПИНЦЕТ", "ПРОДУВКА"]

var rng := RandomNumberGenerator.new()
var rng_bot := RandomNumberGenerator.new()
var D: Dictionary
var broken := 0
var dev: Node3D                    # устройство (вращается)
var cover: Node3D
var screws: Array = []             # {node, out, home}
var comps: Array = []              # {node, name, tested, bad, mat}
var tray: Array = []               # {node, name, right}
var tool := 0
var phase := "inspect"             # inspect → screws → test → swap → close → boot
var rot := 0.0
var drag := false
var wrong_tool := 0
var wrong_part := 0
var tests := 0
var needle := 0.0
var needle_dir := 1.0
var tries := 0
var boot_ok := false
var diag_ok := true
var screen_mat: StandardMaterial3D
var bot_t := 0.0
var tool_ls: Array = []
var cover_y := 0.043               # высота крышки (у корпуса из файла — выше)

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 5
	D = DEVICES[clampi(tier - 1, 0, DEVICES.size() - 1)]
	broken = rng.randi() % (D["parts"] as Array).size()
	keys = [["A/D", "вращать"], ["1", "отвёртка"], ["2", "тестер"], ["3", "пинцет"], ["4", "продувка"], ["ЛКМ", "действие"]]
	base_setup(f, sf, stress, "РЕМОНТ · %s" % D["name"], "", 55.0 + tier * 5.0)
	setup_3d(Color(0.04, 0.035, 0.03), Color(0.55, 0.5, 0.45), 0.5)
	_desk()
	_device()
	_tray()
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, 1.75, 0.95), Vector3(0, 0.82, -0.05), Vector3.UP)
	right_box.add_child(MGUI.label("ИНСТРУМЕНТ", "caps"))
	for k in TOOLS.size():
		var l := MGUI.label("%d  %s" % [k + 1, String(TOOLS[k]).capitalize()], "small")
		right_box.add_child(l)
		tool_ls.append(l)
	MGUI.style_label(tip_l, "mono", MGUI.TEXT)
	_phase("inspect")
	hints_on("ml_repair", MGHintsData.REPAIR)

func _desk() -> void:
	MGProps.desk(at(Vector3(0, 0, 0)), 1.8, 1.0)
	MGProps.box(world_root, Vector3(0, 0.781, 0), Vector3(0.9, 0.004, 0.6), MGProps.mat("green_paint"))   # коврик
	MGProps.desk_lamp(at(Vector3(-0.6, 0.78, -0.35), 0.6))
	light(Vector3(-0.3, 1.4, 0.0), 2.2, 2.5, Color(1.0, 0.85, 0.6), true)
	light(Vector3(0.6, 1.6, 0.6), 0.8, 3.0, Color(0.7, 0.8, 1.0))
	MGProps.tools(at(Vector3(0.55, 0.78, 0.2), 0.3))
	MGProps.mug(at(Vector3(0.7, 0.78, -0.3)))
	# паяльник на подставке
	var sl := at(Vector3(-0.55, 0.78, 0.22), -0.4)
	MGProps.cyl(sl, Vector3(0, 0.02, 0), 0.05, 0.06, 0.04, MGProps.mat("metal"))
	MGProps.cyl(sl, Vector3(0, 0.08, 0.04), 0.012, 0.012, 0.16, MGProps.mat("red"), Vector3(0.9, 0, 0))

## устройство: корпус, крышка на винтах, внутри детали (у каждой — свой цвет и форма)
func _device() -> void:
	dev = at(Vector3(0, 0.79, -0.02))
	var w := 0.34 if tier != 4 else 0.46
	var d := 0.22 if tier != 4 else 0.32
	var body_m := MGProps.mat("plastic_black") if tier != 5 else MGProps.mat("steel")
	# смартфон — вскрытый корпус из файла владельца (ml_job_phone_open.glb): рамка и плата; детали — поверх
	var shell: Node3D = MGModels.spawn_flat("ml_job_phone_open", dev, Vector3.ZERO, 0.0, w, d) if tier == 1 else null
	if shell == null:
		MGProps.box(dev, Vector3(0, 0.02, 0), Vector3(w, 0.04, d), body_m)
		MGProps.box(dev, Vector3(0, 0.041, 0), Vector3(w - 0.03, 0.002, d - 0.03), MGProps.mat("green_paint"))   # плата
	var names: Array = D["parts"]
	# корпус из файла толще коробки: детали и винты — на его верх
	var lift: float = maxf(0.0, float(shell.get_meta("h", 0.04)) - 0.035) if shell != null else 0.0
	for k in names.size():
		@warning_ignore("integer_division")
		var p := Vector3(-w * 0.3 + (k % 2) * w * 0.6, lift + 0.05, -d * 0.22 + (k / 2) * d * 0.44)
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.2, 0.2, 0.22), Color(0.75, 0.6, 0.2), Color(0.3, 0.3, 0.6), Color(0.6, 0.6, 0.62)][k]
		m.roughness = 0.5
		var c := MGProps.box(dev, p, Vector3(w * 0.3, 0.02, d * 0.28), m)
		_part_model(c, String(names[k]), w * 0.28, d * 0.26)
		if k == broken:
			MGProps.ball(c, Vector3(0.0, 0.011, 0.0), 0.012, MGProps.mat("black"), Vector3(1.8, 0.2, 1.2))   # нагар
		comps.append({"node": c, "name": names[k], "tested": false, "bad": k == broken, "mat": m, "dust": false})
	# пыль: со второго уровня заказа одна-две детали забиты пылью — тестер по ним врёт, сначала продуть [4]
	if tier >= 2:
		for q in (2 if tier >= 4 else 1):
			var dc: Dictionary = comps[rng.randi() % comps.size()]
			if bool(dc["dust"]):
				continue
			dc["dust"] = true
			var holder := Node3D.new()
			holder.name = "dust"
			(dc["node"] as Node3D).add_child(holder)
			for b in 7:
				MGProps.ball(holder, Vector3(rng.randf_range(-0.04, 0.04), 0.013, rng.randf_range(-0.025, 0.025)), rng.randf_range(0.008, 0.016), MGProps.mat("card"), Vector3(1.3, 0.5, 1.2))
	cover_y = 0.043 + lift
	cover = at(Vector3(0, cover_y, 0), 0.0, dev)
	MGProps.box(cover, Vector3(0, 0.006, 0), Vector3(w, 0.012, d), body_m)
	MGProps.box(cover, Vector3(w * 0.2, 0.013, 0), Vector3(w * 0.25, 0.002, d * 0.3), MGProps.mat("red"))
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.02, 0.02, 0.03)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.4, 0.8, 1.0)
	screen_mat.emission_energy_multiplier = 0.0
	MGProps.box(dev, Vector3(0, 0.01, d * 0.5 + 0.003), Vector3(w * 0.7, 0.02, 0.004), screen_mat)
	var ns: int = int(D["screws"])
	for k in ns:
		var a := TAU * k / ns + 0.4
		var sp := Vector3(cos(a) * w * 0.44, lift + 0.055, sin(a) * d * 0.4)
		var s := MGProps.cyl(dev, sp, 0.009, 0.009, 0.012, MGProps.mat("steel"), Vector3.ZERO, 8)
		MGProps.box(s, Vector3(0, 0.007, 0), Vector3(0.012, 0.002, 0.003), MGProps.mat("black"))
		screws.append({"node": s, "out": false, "home": sp})

## деталь смартфона из файла владельца (аккумулятор, динамик, шлейф) лежит поверх своей плашки: плашка остаётся
## подложкой — по ней тестер подсвечивает «исправно / неисправно»
const PART_MODELS := {"АККУМУЛЯТОР": "ml_job_part_battery", "ШЛЕЙФ ЭКРАНА": "ml_job_part_flex", "ДИНАМИК": "ml_job_part_speaker"}
func _part_model(pad: Node3D, part: String, w: float, d: float) -> void:
	var id: String = PART_MODELS.get(part, "")
	if id == "" or not MGModels.has(id):
		return
	if id == "ml_job_part_speaker":
		MGModels.spawn(id, pad, Vector3(0, 0.01, 0), 0.0, Vector3(w, 0.02, d), Callable())
	else:
		MGModels.spawn_flat(id, pad, Vector3(0, 0.01, 0), 0.0, w, d)

## лоток с запчастями: нужная и две похожие
func _tray() -> void:
	MGProps.box(world_root, Vector3(0.47, 0.79, -0.1), Vector3(0.34, 0.02, 0.36), MGProps.mat("metal"))
	var names: Array = D["parts"]
	var opts := [broken, (broken + 1) % names.size(), (broken + 2) % names.size()]
	opts.shuffle()
	for k in 3:
		var p := Vector3(0.42, 0.81, -0.22 + k * 0.12)
		var n := MGProps.box(world_root, p, Vector3(0.09, 0.02, 0.07), (comps[opts[k]]["mat"] as Material))
		_part_model(n, String(names[opts[k]]), 0.085, 0.065)
		# подпись детали — мелко, на краю лотка справа от неё (не поверх детали)
		var l := MGProps.text(world_root, String(names[opts[k]]).capitalize(), p + Vector3(0.115, 0.003, 0.0), 8, Color(0.95, 0.9, 0.8), Vector3(-PI / 2, 0, 0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.width = 60.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tray.append({"node": n, "name": names[opts[k]], "right": opts[k] == broken})

func _phase(p: String) -> void:
	phase = p
	match p:
		"inspect":
			task_l.text = "Жалоба: «%s». Возьми отвёртку." % D["sym"][broken]
		"screws":
			task_l.text = "Открути винты (%d) отвёрткой" % screws.size()
		"test":
			task_l.text = "Проверь детали тестером — найди неисправную"
		"swap":
			task_l.text = "Вынь неисправную пинцетом"
		"close":
			task_l.text = "Закрути винты обратно"
		"boot":
			task_l.text = "Включи: пробел, когда стрелка в зелёной зоне"
			hint("boot")

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	if bot >= 0.0:
		_bot(dt)
	elif not drag:
		rot += axis().x * dt * 2.0
	dev.rotation.y = lerp_angle(dev.rotation.y, rot, 1.0 - exp(-8.0 * dt))
	for k in TOOLS.size():
		(tool_ls[k] as Label).add_theme_color_override("font_color", MGUI.GOLD if tool == k else MGUI.TEXT_3)
	# лупа: неисправное подсвечено (снаряжение 2+), когда крышка снята
	if eq("repair") >= 2 and phase in ["test", "swap"]:
		var bm: StandardMaterial3D = comps[broken]["mat"]
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.2, 0.1)
		bm.emission_energy_multiplier = 0.4 + 0.4 * sin(time_left * 6.0)
	if phase == "boot":
		needle += needle_dir * dt * (1.1 + stress_k * 0.8)
		if needle > 1.0 or needle < 0.0:
			needle_dir *= -1.0
			needle = clampf(needle, 0.0, 1.0)
		var z := _zone()
		tip_l.text = "".join(range(32).map(func(i): return "█" if absf(float(i) / 31.0 - needle) < 0.02 else ("▓" if float(i) / 31.0 >= z.x and float(i) / 31.0 <= z.y else "░")))
		score_l.text = "попытка %d из 3" % (tries + 1)
	else:
		score_l.text = "ошибок: %d" % (wrong_tool + wrong_part)
	progress({"inspect": 0.05, "screws": 0.2, "test": 0.45, "swap": 0.65, "close": 0.8, "boot": 0.92}.get(phase, 1.0))

func _zone() -> Vector2:
	var w := 0.2 - stress_k * 0.08 + (0.08 if eq("repair") >= 3 else 0.0)
	return Vector2(0.55 - w * 0.5, 0.55 + w * 0.5)

func _gui_input(e: InputEvent) -> void:
	if done or bot >= 0.0:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		drag = e.pressed
	elif e is InputEventMouseMotion and drag:
		rot += e.relative.x * 0.01
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		click(e.position)

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			pick_tool(e.physical_keycode - KEY_1)
		KEY_SPACE:
			boot()

func pick_tool(k: int) -> void:
	tool = k
	sfx("tab", 1.0 + k * 0.1)
	if phase == "inspect" and k == 0:
		_phase("screws")

## клик по экрану: луч из камеры, ближайший объект в радиусе
func click(sp: Vector2) -> void:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var best = null
	var bd := 0.035
	var cand: Array = []
	for s in screws:
		cand.append(["screw", s, (s["node"] as Node3D).global_position, 0.022])
	for c in comps:
		cand.append(["comp", c, (c["node"] as Node3D).global_position, 0.05])
	for t in tray:
		cand.append(["tray", t, (t["node"] as Node3D).global_position, 0.05])
	for c in cand:
		var p: Vector3 = c[2]
		var dd := (p - from).cross(dir).length()
		if dd < float(c[3]) and (best == null or dd < bd):
			best = c
			bd = dd
	if best != null:
		act(String(best[0]), best[1])

func act(kind: String, o: Dictionary) -> void:
	match kind:
		"screw":
			if tool != 0:
				_wrong()
				return
			if phase == "inspect":
				_phase("screws")
			if phase == "screws" and not bool(o["out"]):
				if cv("repair_multi") > 0.0:
					for s in screws:
						_screw(s, true)
				else:
					_screw(o, true)
				if screws.all(func(s): return bool(s["out"])):
					_open(true)
			elif phase == "close" and bool(o["out"]):
				if cv("repair_multi") > 0.0:
					for s in screws:
						_screw(s, false)
				else:
					_screw(o, false)
				if screws.all(func(s): return not bool(s["out"])):
					_phase("boot")
		"comp":
			if phase == "test":
				if tool == 3:
					blow(o)
					return
				if tool != 1:
					_wrong()
					return
				if bool(o["dust"]):
					tests += 1                            # замер впустую
					dust_miss += 1
					time_left -= 1.0
					sfx("fail", 0.8)
					pop("ПЫЛЬ — НЕ ЧИТАЕТСЯ", (o["node"] as Node3D).global_position + Vector3(0, 0.05, 0), MGUI.GOLD)
					tip_l.text = "Тестер врёт по пыльной детали — продуй её [4]"
					hint("dust")
					return
				_test(o)
			elif phase == "swap":
				if tool != 2:
					_wrong()
					return
				if bool(o["bad"]):
					var n: Node3D = o["node"]
					var tw := n.create_tween()
					tw.tween_property(n, "position:y", n.position.y + 0.12, 0.25)
					tw.tween_callback(func(): n.visible = false)
					o["removed"] = true
					sfx("tick", 0.8)
					task_l.text = "Возьми из лотка: %s" % String(o["name"]).to_lower()
					hint("tray")
				else:
					wrong_part += 1
					sfx("fail")
					pop("НЕ ТА!", (o["node"] as Node3D).global_position + Vector3(0, 0.05, 0), RED)
		"tray":
			if phase != "swap" or not comps.any(func(c): return c.get("removed", false)):
				return
			if tool != 2:
				_wrong()
				return
			if bool(o["right"]):
				var bc: Dictionary = comps[broken]
				var bn: Node3D = bc["node"]
				bn.visible = true
				var bm: StandardMaterial3D = bc["mat"]
				bm.emission_enabled = false
				for ch in bn.get_children():
					ch.queue_free()                       # нагара нет — деталь новая
				(o["node"] as Node3D).visible = false
				sfx("ok")
				pop("НОВАЯ ДЕТАЛЬ", bn.global_position + Vector3(0, 0.06, 0), GREEN)
				_open(false)
			else:
				wrong_part += 1
				diag_ok = false
				sfx("fail")
				pop("НЕ ПОДХОДИТ", (o["node"] as Node3D).global_position + Vector3(0, 0.05, 0), RED)

## продувка: сдуть пыль с детали, чтобы тестер читал
func blow(c: Dictionary) -> void:
	sfx("whoosh", 1.6)
	var n: Node3D = c["node"]
	puff(n.global_position + Vector3(0, 0.03, 0), Color(0.7, 0.66, 0.58), 5, 0.25)
	if bool(c["dust"]):
		c["dust"] = false
		var h := n.get_node_or_null("dust")
		if h != null:
			h.queue_free()
		pop("ЧИСТО", n.global_position + Vector3(0, 0.05, 0), GREEN)

var dust_miss := 0

func _wrong() -> void:
	hint("wrong")
	wrong_tool += 1
	time_left -= 1.5
	sfx("fail", 1.2)
	tip_l.text = "Не тот инструмент — нужен %s" % String(TOOLS[{"screws": 0, "close": 0, "test": 1, "swap": 2}.get(phase, 0)]).to_lower()

func _screw(s: Dictionary, out: bool) -> void:
	var n: Node3D = s["node"]
	var home: Vector3 = s["home"]
	s["out"] = out
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position", home + Vector3(0, 0.04, 0) if out else home, 0.35)
	tw.tween_property(n, "rotation:y", n.rotation.y + (TAU * 3.0 if out else -TAU * 3.0), 0.35)
	sfx("keys", 1.4)

func _open(open_it: bool) -> void:
	var tw := cover.create_tween()
	tw.tween_property(cover, "position", Vector3(0.0, 0.2 + cover_y - 0.043, -0.12) if open_it else Vector3(0, cover_y, 0), 0.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(cover, "rotation:x", -0.9 if open_it else 0.0, 0.4)
	sfx("open" if open_it else "close")
	if open_it:
		_phase("test")
		if eq("repair") >= 3:
			for c in comps:
				_test(c)                                 # тестер «Элитный»: всё сразу
	else:
		_phase("close")

func _test(c: Dictionary) -> void:
	if bool(c["tested"]) or bool(c["dust"]):
		return
	c["tested"] = true
	tests += 1
	time_left -= 1.0 / (1.0 + cv("repair_diag"))
	var m: StandardMaterial3D = c["mat"]
	m.emission_enabled = true
	m.emission = Color(1.0, 0.15, 0.1) if bool(c["bad"]) else Color(0.2, 1.0, 0.35)
	m.emission_energy_multiplier = 0.8
	sfx("calc" if not bool(c["bad"]) else "alert", 1.2)
	pop("НЕИСПРАВНО" if bool(c["bad"]) else "OK", (c["node"] as Node3D).global_position + Vector3(0, 0.05, 0), RED if bool(c["bad"]) else GREEN)
	if bool(c["bad"]):
		_phase("swap")

func boot() -> void:
	if phase != "boot" or done:
		return
	tries += 1
	var z := _zone()
	if needle >= z.x and needle <= z.y:
		boot_ok = true
		screen_mat.emission_energy_multiplier = 2.5
		sfx("phase")
		_end()
	else:
		sfx("zap")
		pop("НЕ ЗАПУСТИЛСЯ", dev.global_position + Vector3(0, 0.15, 0), RED)
		if tries >= 3:
			_end()

## бот: делает всё по порядку, иногда ошибается (тем чаще, чем хуже)
func _bot(dt: float) -> void:
	bot_t -= dt
	if bot_t > 0.0:
		return
	bot_t = lerpf(0.9, 0.25, bot)
	var slip := rng_bot.randf() > bot
	match phase:
		"inspect":
			pick_tool(0)
		"screws", "close":
			if tool != 0:
				pick_tool(0)
				return
			for s in screws:
				if bool(s["out"]) == (phase == "close"):
					act("screw", s)
					return
		"test":
			var order := comps.filter(func(c): return not bool(c["tested"]))
			if order.is_empty():
				return
			var tc: Dictionary = order[0] if slip or eq("repair") < 2 else comps[broken]
			var want_tool := 3 if bool(tc["dust"]) and not slip else 1
			if tool != want_tool:
				pick_tool(want_tool)
				return
			act("comp", tc)
		"swap":
			if tool != 2:
				pick_tool(2)
				return
			if not comps.any(func(c): return c.get("removed", false)):
				act("comp", comps[(broken + 1) % comps.size()] if slip and rng_bot.randf() < 0.5 else comps[broken])
			else:
				var right := tray.filter(func(t): return bool(t["right"]))
				var wrong := tray.filter(func(t): return not bool(t["right"]))
				act("tray", wrong[0] if slip and rng_bot.randf() < 0.4 else right[0])
		"boot":
			var z := _zone()
			if needle >= z.x and needle <= z.y and not slip:
				boot()
			elif slip and rng_bot.randf() < 0.3:
				boot()

func _end() -> void:
	if done:
		return
	var parts_cost := wrong_part * int(400 * maxf(0.3, 1.0 + cv("repair_parts")))
	var q := 1.0 - 0.12 * wrong_part - 0.04 * wrong_tool - 0.02 * maxi(0, tests - 2)
	var base := 0.0
	if boot_ok:
		base = 0.75 if diag_ok else 0.45
	elif phase in ["boot", "close"]:
		base = 0.25
	var time_b := clampf(time_left / time_max, 0.0, 1.0) * 0.2 if boot_ok else 0.0
	var score := clampf(base * q + time_b, 0.0, 1.0)
	show_result(score, ["%s: «%s» — %s" % [D["name"], D["sym"][broken], D["parts"][broken]],
		"Включился: %s · тестов: %d%s · не тот инструмент: %d · не та деталь: %d" % ["да" if boot_ok else "нет", tests, " (по пыли впустую: %d)" % dust_miss if dust_miss > 0 else "", wrong_tool, wrong_part],
		("Запчасти мимо: −%d ₽ из оплаты" % parts_cost) if parts_cost > 0 else "Ремонт чистый — заказчик доволен"])
