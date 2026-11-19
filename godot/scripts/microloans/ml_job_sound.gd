## ЗВУКАРЬ — 3D-рабочее место на мероприятии: микшер, усилитель, две колонки, микрофон, наушники, кабели.
## Три части: 1) КОММУТАЦИЯ — схема на листке: выход источника → вход микшера (клик по гнезду выхода, потом по гнезду
## входа); не тот вход — гудёж фона, микрофон в колонку напрямую — визг обратной связи; 2) УРОВНИ — у каждого канала
## индикатор прыгает, фейдером (W/S, ←/→ — канал) держать в зелёном; красное — перегрузка, искажение; иногда
## наводка — [G] «земля» убирает фон; 3) БИТ — тусовка началась: [пробел] в такт (метки бегут к линии).
## Снаряжение: кабели получше — меньше помех, микшер лучше — шире окна, лишний канал; навык «абсолютный слух».
class_name MLJobSound
extends MLJob3D

var rng := RandomNumberGenerator.new()
var rng_bot := RandomNumberGenerator.new()
var part := 1
var mix: Dictionary
var srcs: Array = []           # {name, out: Vector3, want: int (канал)}
var ins: Array = []            # Vector3 гнёзда входов
var links := {}                # источник → канал
var picked := -1
var wrong := 0
var feedback := 0
var levels: Array = []         # 0..1 положение фейдера
var targets: Array = []        # 0..1 центр зелёного окна
var sig: Array = []            # сигнал канала (прыгает)
var ch_sel := 0
var level_t := 0.0
var in_green := 0.0
var clip_t := 0.0
var hum_on := false
var hum_t := 6.0
var hum_fixed := 0
var beats: Array = []          # время меток
var beat_t := 0.0
var hits := 0
var misses := 0
var bot_t := 0.0
var cable_node: Node3D
var notes: Array = []

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 7
	keys = []
	base_setup(f, sf, stress, "ЗВУКАРЬ НА ТУСЕ", "", 60.0 + tier * 4.0)
	setup_3d(Color(0.03, 0.02, 0.05), Color(0.5, 0.45, 0.6), 0.4)
	_stage()
	cam.fov = 46.0
	MGUI.style_label(tip_l, "mono", MGUI.TEXT)
	cam.look_at_from_position(Vector3(0, 1.9, 1.35), Vector3(0, 0.85, -0.15), Vector3.UP)
	_part1()

func _stage() -> void:
	MGProps.desk(at(Vector3(0, 0, 0)), 2.2, 1.0)
	var mx := at(Vector3(0, 0.79, 0.05))
	mx.scale = Vector3.ONE * 1.3
	var chn := 4 + int(cv("sound_slots")) + (1 if eq("sound") >= 3 else 0)
	chn = clampi(chn, 4, 6)
	mix = MGProps.mixer(mx, chn)
	for c in chn:
		levels.append(0.2)
		targets.append(rng.randf_range(0.45, 0.8))
		sig.append(0.0)
		ins.append(mx.transform * Vector3(-0.24 + c * (0.48 / float(chn - 1)), 0.075, -0.22))
	# усилитель, колонки, микрофон, ноутбук, наушники
	var amp := at(Vector3(0.8, 0.79, -0.2), -0.3)
	MGProps.box(amp, Vector3(0, 0.12, 0), Vector3(0.4, 0.24, 0.3), MGProps.mat("black"))
	for k in 3:
		MGProps.cyl(amp, Vector3(-0.1 + k * 0.1, 0.16, 0.155), 0.02, 0.02, 0.02, MGProps.mat("chrome"), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		var sp := at(Vector3(sx * 1.5, 0, -0.9), -sx * 0.4)
		MGProps.speaker(sp)
	var mic := at(Vector3(-0.85, 0.79, -0.2))
	MGProps.cyl(mic, Vector3(0, 0.15, 0), 0.008, 0.008, 0.3, MGProps.mat("steel"))
	MGProps.caps(mic, Vector3(0, 0.32, 0.02), 0.025, 0.1, MGProps.mat("black"), Vector3(0.4, 0, 0))
	MGProps.laptop(at(Vector3(-0.55, 0.79, 0.05), 0.4), Color(0.8, 0.4, 1.0))
	light(Vector3(0, 2.2, 0.5), 1.4, 4.0, Color(0.9, 0.8, 1.0), true)
	light(Vector3(-1.5, 1.5, -1.0), 1.5, 4.0, Color(1.0, 0.2, 0.6))
	light(Vector3(1.5, 1.5, -1.0), 1.5, 4.0, Color(0.2, 0.6, 1.0))
	cable_node = at(Vector3.ZERO)
	# источники: выходы с гнёздами
	var names := ["МИКРОФОН", "НОУТБУК", "ГИТАРА", "ВТОРОЙ МИК", "СИНТ", "ВИНИЛ"]
	var outs := [Vector3(-0.85, 0.82, -0.1), Vector3(-0.55, 0.81, 0.15), Vector3(1.0, 0.82, 0.25), Vector3(-1.0, 0.82, 0.1), Vector3(0.6, 0.82, 0.3), Vector3(0.95, 0.82, -0.35)]
	var order := range(chn)
	order.shuffle()
	for k in chn:
		var j := MGProps.cyl(world_root, outs[k], 0.018, 0.018, 0.03, MGProps.mat("red"), Vector3.ZERO, 10)
		MGProps.text(world_root, String(names[k]).capitalize(), outs[k] + Vector3(0, 0.045, 0), 10, Color(0.95, 0.9, 0.8), Vector3(-0.9, 0, 0))
		srcs.append({"name": names[k], "out": outs[k], "want": int(order[k]), "node": j})
	# схема на листке
	var sheet := at(Vector3(0.55, 0.785, 0.32), -0.2)
	MGProps.box(sheet, Vector3(0, 0.001, 0), Vector3(0.24, 0.002, 0.3), MGProps.mat("paper"))
	var txt_s := ""
	for s in srcs:
		txt_s += "%s → %d\n" % [s["name"], int(s["want"]) + 1]
	MGProps.text(sheet, "СХЕМА\n" + txt_s, Vector3(0, 0.003, 0), 11, Color(0.1, 0.1, 0.12), Vector3(-PI / 2, 0, 0))

func _part1() -> void:
	part = 1
	task_l.text = "Подключи по схеме: выход → вход микшера"
	_keys([["ЛКМ", "выход, потом вход"]])

func _part2() -> void:
	part = 2
	task_l.text = "Держи каналы в зелёной зоне"
	_keys([["A/D", "канал"], ["W/S", "фейдер"], ["G", "убрать фон"]])
	sfx("phase")

func _part3() -> void:
	part = 3
	task_l.text = "Туса началась — бей в бит"
	_keys([["Пробел", "в бит"]])
	for k in 24:
		beats.append(1.0 + k * 0.5)
	beat_t = 0.0
	sfx("cheer")

## строка клавиш меняется по частям задания
var keys_p: PanelContainer
func _keys(pairs: Array) -> void:
	if keys_p != null:
		keys_p.queue_free()
	keys_p = MGUI.panel(true, null, MGUI.S2)
	add_child(keys_p)
	keys_p.add_child(MGUI.hints(pairs))
	_place_keys.call_deferred(keys_p)

func _window() -> float:
	return 0.12 + cv("sound_precise") * 0.06 + (0.04 if eq("sound") >= 2 else 0.0) - stress_k * 0.04

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	if bot >= 0.0:
		_bot(dt)
	match part:
		1:
			progress(float(links.size()) / float(srcs.size()) * 0.33)
			score_l.text = "кабели %d из %d" % [links.size(), srcs.size()]
		2:
			_levels(dt)
		3:
			_beat(dt)
	# индикаторы микшера: цвет по уровню
	for c in sig.size():
		var m: StandardMaterial3D = mix["meters"][c]
		var v: float = sig[c] * levels[c] * 1.6
		m.albedo_color = Color(0.2, 1.0, 0.3) if v < 0.85 else (Color(1.0, 0.8, 0.2) if v < 1.0 else Color(1.0, 0.1, 0.1))
		m.emission = m.albedo_color
		(mix["faders"][c] as Node3D).position.z = 0.17 - float(levels[c]) * 0.14

func _gui_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or part != 1:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var from := cam.project_ray_origin(e.position)
		var dir := cam.project_ray_normal(e.position)
		for k in srcs.size():
			if ((srcs[k]["out"] as Vector3) - from).cross(dir).length() < 0.04:
				pick_src(k)
				return
		for c in ins.size():
			if ((ins[c] as Vector3) - from).cross(dir).length() < 0.035:
				plug(c)
				return

func pick_src(k: int) -> void:
	if links.has(k):
		return
	picked = k
	sfx("tick")
	tip_l.text = "%s — теперь вход микшера" % String(srcs[k]["name"]).capitalize()

func plug(c: int) -> void:
	if picked < 0 or links.values().has(c):
		return
	var s: Dictionary = srcs[picked]
	links[picked] = c
	MGProps.cable(cable_node, s["out"], ins[c], 0.08, 0.01, MGProps.mat("rubber") if eq("sound") < 1 else MGProps.mat("blue_paint"))
	if int(s["want"]) != c:
		wrong += 1
		if String(s["name"]).contains("МИК") and rng.randf() < 0.6:
			feedback += 1
			sfx("zap", 2.0)
			pop("ОБРАТНАЯ СВЯЗЬ!", ins[c] + Vector3(0, 0.1, 0), RED)
		else:
			sfx("zap", 0.6)
			pop("ГУДИТ!", ins[c] + Vector3(0, 0.1, 0), Color(1.0, 0.7, 0.2))
	else:
		sfx("keys", 1.3)
		pop("OK", ins[c] + Vector3(0, 0.1, 0), GREEN)
	picked = -1
	tip_l.text = ""
	if links.size() >= srcs.size():
		_part2()

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed:
		return
	var k: int = e.physical_keycode
	if part == 2:
		if k in [KEY_W, KEY_UP]:
			nudge(0.06)
		elif k in [KEY_S, KEY_DOWN]:
			nudge(-0.06)
		elif k in [KEY_A, KEY_LEFT] and not e.echo:
			ch_sel = posmod(ch_sel - 1, levels.size())
			sfx("tab")
		elif k in [KEY_D, KEY_RIGHT] and not e.echo:
			ch_sel = posmod(ch_sel + 1, levels.size())
			sfx("tab")
		elif k == KEY_G and not e.echo:
			ground()
	elif part == 3 and k == KEY_SPACE and not e.echo:
		hit()

func nudge(v: float) -> void:
	levels[ch_sel] = clampf(float(levels[ch_sel]) + v, 0.0, 1.0)
	sfx("tick", 0.8 + float(levels[ch_sel]))

func ground() -> void:
	if hum_on:
		hum_on = false
		hum_fixed += 1
		sfx("ok")
		pop("ФОН УБРАН", ins[0] + Vector3(0, 0.15, 0), GREEN)

func _levels(dt: float) -> void:
	level_t += dt
	for c in sig.size():
		sig[c] = 0.55 + 0.45 * absf(sin(level_t * (2.0 + c * 0.7) + c)) * (1.0 + 0.3 * sin(level_t * 7.3 + c * 2.0))
	var w := _window()
	var ok := 0
	var clip := false
	for c in levels.size():
		var lv: float = levels[c]
		if absf(lv - float(targets[c])) < w:
			ok += 1
		if float(sig[c]) * lv * 1.6 > 1.05:
			clip = true
	if clip:
		clip_t += dt
	in_green += dt * float(ok) / float(levels.size())
	hum_t -= dt
	if hum_t <= 0.0 and not hum_on:
		hum_on = rng.randf() < 0.7 - 0.2 * eq("sound")
		hum_t = rng.randf_range(4.0, 8.0)
		if hum_on:
			sfx("zap", 0.5)
			pass
	var lane := ""
	for c in levels.size():
		lane += ("[%d%s] " if c == ch_sel else " %d%s  ") % [c + 1, "●" if absf(float(levels[c]) - float(targets[c])) < w else "○"]
	tip_l.text = lane if not hum_on else "Наводка — нажми G"
	score_l.text = "в зелёном %d из %d" % [ok, levels.size()]
	progress(0.33 + clampf(in_green / 12.0, 0.0, 1.0) * 0.33)
	if in_green >= 12.0 or level_t > 22.0:
		_part3()

func _beat(dt: float) -> void:
	beat_t += dt
	while not beats.is_empty() and float(beats[0]) < beat_t - _window() * 1.2:
		beats.pop_front()
		misses += 1
	for n in notes:
		(n as Node).queue_free()
	notes.clear()
	var lane := ""
	for k in 12:
		var tt := beat_t + float(k) * 0.15
		lane += "█" if beats.any(func(b): return absf(float(b) - tt) < 0.07) else "·"
	tip_l.text = "▶" + lane
	score_l.text = "попаданий %d из %d" % [hits, hits + misses]
	if fposmod(beat_t, 0.5) < dt:
		sfx("tick", 1.6)
	progress(0.66 + clampf(beat_t / 13.0, 0.0, 1.0) * 0.34)
	if beats.is_empty() or beat_t > 13.5:
		_end()

func hit() -> void:
	if beats.is_empty():
		return
	var b: float = beats[0]
	if absf(b - beat_t) < _window():
		beats.pop_front()
		hits += 1
		sfx("ok", 1.3)
	else:
		misses += 1
		sfx("fail", 1.4)

## бот: подключает по схеме (иногда ошибается), держит фейдеры, бьёт в бит
func _bot(dt: float) -> void:
	bot_t -= dt
	var slip := rng_bot.randf() > bot
	match part:
		1:
			if bot_t > 0.0:
				return
			bot_t = lerpf(0.6, 0.2, bot)
			for k in srcs.size():
				if not links.has(k):
					pick_src(k)
					var want := int(srcs[k]["want"])
					if slip:
						for c in ins.size():
							if not links.values().has(c) and c != want:
								want = c
								break
					if links.values().has(want):
						for c in ins.size():
							if not links.values().has(c):
								want = c
								break
					plug(want)
					return
		2:
			for c in levels.size():
				var tgt: float = float(targets[c]) + (rng_bot.randf_range(-0.2, 0.2) if slip else 0.0)
				levels[c] = move_toward(float(levels[c]), tgt, dt * 0.8)
			if hum_on and not slip:
				ground()
		3:
			if not beats.is_empty() and absf(float(beats[0]) - beat_t) < 0.03 and not slip:
				hit()

func _end() -> void:
	if done:
		return
	var s1 := clampf(1.0 - 0.18 * wrong - 0.15 * feedback, 0.0, 1.0)
	var s2 := clampf(in_green / 12.0 - clip_t * 0.05, 0.0, 1.0)
	var s3 := float(hits) / float(maxi(1, hits + misses + beats.size()))
	var score := s1 * 0.25 + s2 * 0.3 + s3 * 0.45
	show_result(score, ["Кабели: %d ошибок · обратная связь ×%d" % [wrong, feedback],
		"Уровни: %d%% в зелёном · перегрузка %.1f с · фон убран ×%d" % [int(s2 * 100.0), clip_t, hum_fixed],
		"Бит: %d из %d — %s" % [hits, hits + misses + beats.size(), "ТУСА КАЧАЕТ!" if s3 > 0.8 else ("покатит" if s3 > 0.45 else "диджей плачет")]])
