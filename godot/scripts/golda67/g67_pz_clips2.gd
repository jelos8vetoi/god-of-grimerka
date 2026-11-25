class_name G67PzClips2
extends RefCounted
## Ролики ПОДЗЕМКИ, вторая партия (PODZEMKA_DESIGN.md, раздел 6): CL02, PZ_DOGCASINO01, PZ_HAMSTER01, PZ_KROT04_CCTV,
## PZ_KROT05_CCTV, PZ_FORTUNA_PROMO, NEWS02, PZ_TARIFF01, PZ_SELLER01, PZ_CCTV_EXIT. Реплики дословно — G67Clips.LINES.
## Постановка — теми же средствами, что у первой партии (G67ClipPlayer, помощники G67PzClips).

const PZ := "res://assets/golda67/podzemka/"
const GOLD := Color(1.0, 0.82, 0.25)
const RED := Color(0.86, 0.14, 0.12)
const CCTV := Color(0.55, 1.0, 0.6)

static func _l(parent: Control, text: String, size: int, col: Color, pos: Vector2, w := 0.0) -> Label:
	return G67PzClips._lbl(parent, text, size, col, pos, w)

static func _r(parent: Control, col: Color, pos: Vector2, size: Vector2) -> ColorRect:
	return G67PzClips._rect(parent, col, pos, size)

static func _say(c: G67ClipPlayer, id: String, i: int, pad := 0.3) -> void:
	var d := c.say_async(G67Clips.L(id, i))
	await c.wait(d + pad)

## Кадр камеры наблюдения: зелёный моно-кадр, рамка, номер камеры, бегущее время
static func _cctv(c: G67ClipPlayer, cam: String, note := "", soft := false) -> Control:
	c.mono(1.0)
	c.filters(0.35 if soft else 0.7, 0.18 if soft else 0.5)          # soft — мелкий реквизит в кадре: шум и зелень слабее
	return c.screen(func(s: Control, fs: Vector2):
		_r(s, Color(0.1, 0.6, 0.2, 0.06 if soft else 0.14), Vector2.ZERO, fs)
		_l(s, cam, 30, CCTV, Vector2(26, 20))
		var tm := _l(s, "03:12:07", 30, CCTV, Vector2(fs.x - 190, 20))
		var rec := _l(s, "● REC", 26, RED, Vector2(26, fs.y - 56))
		var tw: Tween = c.create_tween().bind_node(rec).set_loops()
		tw.tween_property(rec, "modulate:a", 0.2, 0.5)
		tw.tween_property(rec, "modulate:a", 1.0, 0.5)
		if note != "":
			_l(s, note, 26, CCTV, Vector2(26, 58)))

static func _tunnel(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	G67Clips._metro(c, Vector3.ZERO)
	c.light(Vector3(0, 3.0, 2.0), Color(0.9, 1.0, 0.92), 2.4, 12.0)

# ------------------------------------------------------------------ CL02 «БЕСПЛАТНЫЙ ПРОХОД» (9:16)
static func cl02(c: G67ClipPlayer) -> void:
	_tunnel(c)
	c.actor("ft", "fortuna", Vector3(0.0, 0.0, 0.4), 0.0)
	c.anim("ft", "NPoint", 0.1)
	c.cam_at(Vector3(0.1, 1.5, 3.6), Vector3(0, 1.3, 0.4), 44.0)
	c.cam_to(Vector3(0.0, 1.5, 3.0), Vector3(0, 1.32, 0.4), 4.0, 40.0)
	var ui := c.screen(func(s: Control, fs: Vector2):
		_l(s, "ОБЛАКО LIVE", 24, Color(0.8, 0.9, 1.0), Vector2(24, 24))
		_l(s, "👁 812", 30, Color.WHITE, Vector2(fs.x - 170, 24)))
	var card := {}
	var tk := c.screen(func(s: Control, fs: Vector2):
		var t := _r(s, Color(0.97, 0.95, 0.85), Vector2(fs.x * 0.5 - 150, fs.y * 0.5), Vector2(300, 150))
		t.pivot_offset = Vector2(150, 75)
		card["t"] = t
		card["l"] = _l(t, "БЕСПЛАТНЫЙ\nПРОХОД", 34, Color(0.1, 0.4, 0.15), Vector2(34, 26)))
	await c.wait(1.0)
	await _say(c, "CL02", 0, 0.5)
	await _say(c, "CL02", 1, 0.5)
	var d := c.say_async(G67Clips.L("CL02", 2))
	await c.wait(d * 0.62)
	# талон переворачивается: «67 ₽»
	var t: ColorRect = card["t"]
	var tw: Tween = c.create_tween()
	tw.tween_property(t, "scale:x", 0.02, 0.18)
	tw.tween_callback(func():
		t.color = Color(0.96, 0.84, 0.3)
		(card["l"] as Label).text = "67 ₽"
		(card["l"] as Label).add_theme_font_size_override("font_size", 84)
		(card["l"] as Label).add_theme_color_override("font_color", RED))
	tw.tween_property(t, "scale:x", 1.0, 0.18)
	G67Sound.play(c, "click")
	await c.wait(d * 0.38 + 1.8)
	c.vhs(1.0, 0.25)
	G67Sound.play(c, "hit_cut")
	await c.wait(0.25)
	ui.queue_free()
	tk.queue_free()

# ------------------------------------------------------------------ PZ_DOGCASINO01 «DOG CASINO 67»
static func dogcasino(c: G67ClipPlayer) -> void:
	c.set_env("black")
	c.box(Vector3(10, 0.1, 8), Vector3(0, -0.05, 0), Color(0.05, 0.05, 0.06))
	c.prop(PZ + "g67_pz_kennel.glb", Vector3(-0.9, 0.0, 0.0), 0.3, Vector3(9, 1.1, 9))
	c.prop(PZ + "g67_pz_dog.glb", Vector3(0.5, 0.0, 0.4), -0.4, Vector3(9, 0.7, 9))
	var lamp := c.light(Vector3(0.4, 2.2, 1.6), Color(1.0, 0.75, 0.4), 0.2, 6.0)
	c.cam_at(Vector3(0.6, 0.9, 4.2), Vector3(0.3, 0.5, 0.2), 46.0)
	c.cam_to(Vector3(0.5, 0.75, 2.4), Vector3(0.4, 0.45, 0.3), 5.0, 36.0)
	c.create_tween().tween_property(lamp, "light_energy", 2.6, 4.0)
	await c.wait(1.4)
	# вывеска загорается по буквам
	var sign := {}
	var ui := c.screen(func(s: Control, fs: Vector2):
		sign["l"] = _l(s, "", 72, GOLD, Vector2(0, fs.y * 0.1), fs.x)
		(sign["l"] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
	var name := "DOG CASINO 67"
	for i in name.length():
		(sign["l"] as Label).text = name.substr(0, i + 1)
		G67Sound.play(c, "tap")
		await c.wait(0.14)
	await c.wait(0.5)
	# барабаны: СОБАКА — СОБАКА — …
	var reel := {}
	var drums := c.screen(func(s: Control, fs: Vector2):
		_r(s, Color(0, 0, 0, 0.72), Vector2(fs.x * 0.14, fs.y * 0.42), Vector2(fs.x * 0.72, 150))
		reel["l"] = _l(s, "", 54, Color.WHITE, Vector2(0, fs.y * 0.42 + 40), fs.x)
		(reel["l"] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
	for step in ["СОБАКА", "СОБАКА · СОБАКА", "СОБАКА · СОБАКА · …"]:
		(reel["l"] as Label).text = step
		G67Sound.play(c, "drum")
		await c.wait(0.75)
	c.vhs(1.0, 0.5)
	c.shake(0.25)
	G67Sound.play(c, "hit_cut")
	await c.wait(0.45)
	drums.queue_free()
	c.plate("67-Й СПИН ИЗМЕНИТ ВСЁ", "big", 2.2)
	G67Sound.play(c, "dog")
	await c.wait(0.9)
	G67Sound.play(c, "dog", Vector3.INF, 1.2)
	G67PzClips._play(c, G67PzClips._snd_jingle(), -6.0)
	await c.wait(3.0)
	ui.queue_free()

# ------------------------------------------------------------------ PZ_HAMSTER01 «ЗАСЕКРЕЧЕННЫЙ ОБЪЕКТ»
static func hamster(c: G67ClipPlayer) -> void:
	_tunnel(c)
	var ov := _cctv(c, "CAM 07 · ТЕХНИЧЕСКИЙ ТОННЕЛЬ", "ОБЪЕКТ 67-Х")
	c.prop(PZ + "g67_pz_door_tech.glb", Vector3(0.0, 0.0, -1.6), 0.0, Vector3(9, 2.2, 9))
	var ham := c.prop(PZ + "g67_pz_hamster_a.glb", Vector3(0.1, 0.0, -1.2), 0.0, Vector3(9, 0.18, 9))
	ham.visible = false
	c.cam_at(Vector3(2.4, 2.6, 4.2), Vector3(0, 0.9, -1.4), 58.0)
	await c.wait(2.6)                                  # пустой тоннель, таймкод
	c.cam_to(Vector3(1.2, 2.0, 2.2), Vector3(0, 0.6, -1.5), 2.4, 44.0)      # дверь
	await c.wait(2.6)
	# под дверью движение: тень
	var shade := c.box(Vector3(0.5, 0.02, 0.3), Vector3(-0.3, 0.02, -1.3), Color(0, 0, 0))
	c.create_tween().tween_property(shade, "position:x", 0.4, 1.2)
	G67Sound.play(c, "tap")
	await c.wait(1.4)
	# цифровой зум в щель — нора, хомяк смотрит в камеру
	c.vhs(0.7, 0.2)
	shade.visible = false
	ham.visible = true
	c.cam_at(Vector3(0.5, 0.35, 0.2), Vector3(0.1, 0.1, -1.2), 20.0)
	c.cam_to(Vector3(0.3, 0.22, -0.4), Vector3(0.1, 0.1, -1.2), 2.6, 14.0)
	var d := c.say_async(G67Clips.L("PZ_HAMSTER01", 0))
	await c.wait(d + 0.4)
	c.vhs(1.0, 0.6)                                     # помехи
	G67PzClips._play(c, G67PzClips._snd_squeak(2100.0, 0.25), -4.0)
	c.plate("НЕ ТРОГАТЬ. ТУТ ХОМЯКИ", "big", 1.6)
	await c.wait(1.7)
	G67Sound.play(c, "hit_cut")
	ov.queue_free()

# ------------------------------------------------------------------ PZ_KROT04_CCTV «NPC»
static func krot04(c: G67ClipPlayer) -> void:
	_tunnel(c)
	var ov := _cctv(c, "CAM 04 · ГАЛЕРЕЯ", "NPC ACTIVITY: 100%")
	c.prop(PZ + "g67_pz_slot_cabinet.glb", Vector3(1.3, 0.0, -0.9), -0.5, Vector3(9, 1.9, 9))
	c.actor("krot", "krot", Vector3(0.1, 0.0, 0.5), 0.9)
	c.cam_at(Vector3(-2.2, 2.4, 3.8), Vector3(0.3, 1.0, 0.1), 44.0)
	for i in 3:                                         # трижды одно и то же движение
		c.anim("krot", "K4Nod", 0.05)
		await c.wait(1.25)
		c.anim("krot", "K4", 0.05)
		await c.wait(0.45)
	c.vhs(1.0, 0.5)                                     # запись заикается и повторяет полсекунды
	c.anim("krot", "K4Nod", 0.0)
	await c.wait(0.5)
	c.vhs(1.0, 0.3)
	c.anim("krot", "K4Nod", 0.0)
	await c.wait(0.6)
	c.actor("pahan", "pahan", Vector3(-3.4, 0.0, 1.6), 1.6)
	c.anim("pahan", "Walk", 0.1)
	c.move("pahan", Vector3(-1.2, 0.0, 1.2), 2.2)
	await c.wait(2.3)
	c.anim("pahan", "Idle", 0.2)
	await c.wait(0.6)
	ov.queue_free()

# ------------------------------------------------------------------ PZ_KROT05_CCTV «АБСОЛЮТНО ТРЕЗВЫЙ»
static func krot05(c: G67ClipPlayer) -> void:
	_tunnel(c)
	var ov := _cctv(c, "CAM 09 · ЗАЛ АВТОМАТОВ", "", true)
	c.light(Vector3(-1.5, 2.6, 2.2), Color(1, 1, 1), 2.2, 7.0, true)             # боковой свет с тенью: фигуры и микроволновка отделяются от стола
	c.prop(PZ + "g67_pz_chess.glb", Vector3(0.0, 0.0, 0.0), 0.0, Vector3(9, 0.85, 9))
	var mw := c.prop(PZ + "g67_pz_microwave.glb", Vector3(0.75, 0.85, 0.0), -1.57, Vector3(9, 0.34, 9))
	c.actor("krot", "krot", Vector3(-0.85, 0.0, 0.0), 1.57)
	c.anim("krot", "K5", 0.0)
	c.cam_at(Vector3(-0.3, 2.2, 2.9), Vector3(0, 0.9, 0), 44.0)
	await c.wait(2.6)
	c.cam_to(Vector3(0.3, 1.6, 2.0), Vector3(0.75, 1.0, 0.0), 1.6, 26.0)        # зум на микроволновку
	await c.wait(1.9)
	c.plate("ПОБЕДИТЕЛЬ ШАХМАТНОГО ТУРНИРА", "lower", 2.6)
	await c.wait(1.5)
	c.create_tween().tween_property(mw, "rotation:y", -1.2, 0.12)              # тарелка дёрнулась
	G67Sound.play(c, "click")
	c.vhs(0.8, 0.3)
	await c.wait(2.3)
	ov.queue_free()

# ------------------------------------------------------------------ PZ_FORTUNA_PROMO «FORTUNA 812»
static func promo(c: G67ClipPlayer) -> void:
	_tunnel(c)
	c.light(Vector3(0, 3.0, 3.0), Color(1.0, 0.98, 0.9), 4.0, 14.0)
	c.actor("ft", "fortuna", Vector3(0.0, 0.0, 0.4), 0.0)
	G67PzClips._play(c, G67PzClips._snd_jingle(), -8.0)
	var cut := func(text: String, sec: float, col: Color):
		G67PzClips._flash(c, Color.WHITE, 0.15)
		G67Sound.play(c, "tap")
		var s := c.screen(func(sc: Control, fs: Vector2):
			_r(sc, col, Vector2(0, fs.y * 0.06), Vector2(fs.x, 96))
			var l := _l(sc, text, 52, Color(0.08, 0.06, 0.0), Vector2(0, fs.y * 0.06 + 14), fs.x)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
		await c.wait(sec)
		s.queue_free()
	# улыбка / калькулятор
	c.cam_at(Vector3(0.0, 1.42, 2.6), Vector3(0, 1.36, 0.4), 30.0)      # лицо целиком: у модели крупная голова, центр лица ниже макушки
	c.say_async(G67Clips.L("PZ_FORTUNA_PROMO", 0))
	await cut.call("УЛЫБКА — ВКЛЮЧЕНА", 2.3, GOLD)
	c.anim("ft", "NThink", 0.1)
	c.cam_at(Vector3(-0.9, 1.3, 1.6), Vector3(0, 1.25, 0.4), 34.0)
	await cut.call("КАЛЬКУЛЯТОР", 2.2, GOLD)
	# прайс / лента
	var d1 := c.say_async(G67Clips.L("PZ_FORTUNA_PROMO", 1))
	var price := c.screen(func(s: Control, fs: Vector2):
		_r(s, Color(0.96, 0.95, 0.88), Vector2(fs.x * 0.56, 60), Vector2(fs.x * 0.38, fs.y * 0.6))
		var rows := ["ВХОД — 8", "ВЫХОД — 67", "ВОПРОС — 67", "ОТВЕТ — 67", "ПОСТОЯТЬ — 8/мин"]
		for i in rows.size():
			_l(s, rows[i], 30, Color(0.12, 0.1, 0.06), Vector2(fs.x * 0.58, 84.0 + float(i) * 52.0)))
	await c.wait(maxf(d1, 2.4) + 0.3)
	price.queue_free()
	# турникет / колесо / очередь
	c.anim("ft", "NPoint", 0.1)
	c.cam_at(Vector3(1.8, 1.5, 2.8), Vector3(0, 1.2, 0.2), 44.0)
	c.cam_to(Vector3(0.9, 1.5, 2.0), Vector3(0, 1.3, 0.3), 3.0, 38.0)
	var d2 := c.say_async(G67Clips.L("PZ_FORTUNA_PROMO", 2))
	for k in 4:
		c.box(Vector3(0.42, 1.5, 0.3), Vector3(-2.2 - float(k) * 0.7, 0.75, 1.0), Color(0.3 + 0.12 * float(k), 0.45, 0.7))       # очередь
	await cut.call("ТУРНИКЕТ", 1.9, RED)
	var wheel := c.prop(PZ + "g67_pz_fortuna_wheel.glb", Vector3(1.6, 1.4, -0.6), 0.0, Vector3(9, 1.8, 9))
	c.create_tween().tween_property(wheel, "rotation:z", TAU * 2.0, 3.0)
	await c.wait(maxf(d2 - 1.3, 1.0) + 0.2)
	c.cam_at(Vector3(0.0, 1.42, 2.7), Vector3(0, 1.36, 0.4), 30.0)
	c.anim("ft", "Idle", 0.2)
	await _say(c, "PZ_FORTUNA_PROMO", 3, 0.3)
	G67PzClips._flash(c, GOLD, 0.3)
	c.plate("FORTUNA 812 — МЫ ЗА ВАШИ ДЕНЬГИ", "big", 2.8)
	await c.wait(3.0)

# ------------------------------------------------------------------ NEWS02 «ПОРАЖЕНИЕ FORTUNA»
static func news02(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	var S := Vector3.ZERO
	c.box(Vector3(12, 0.1, 10), S + Vector3(0, -0.05, 0), Color(0.06, 0.07, 0.1))
	c.box(Vector3(12, 6, 0.2), S + Vector3(0, 3, -2.6), Color(0.09, 0.12, 0.25))
	c.box(Vector3(4.2, 2.3, 0.05), S + Vector3(1.6, 2.2, -2.45), Color(0.2, 0.35, 0.9), 0.8)
	c.prop("g67_news_desk", S + Vector3(0, 0, 0.3), 0.0, Vector3(2.6, 0.92, 1.2), "h")
	c.actor("anchor", "anchor", S + Vector3(0, 0, -0.55), 0.0)
	c.anim("anchor", "NCross", 0.0)
	c.light(S + Vector3(0, 3.0, 3.0), Color(1, 0.96, 0.9), 2.2, 12.0)
	c.light(S + Vector3(-3, 2.0, 1.0), Color(0.5, 0.6, 1.0), 1.0, 8.0)
	G67Sound.play(c, "jingle")
	c.plate("РАЙОННЫЙ ВЕСТНИК 67", "big", 1.4)
	c.cam_at(S + Vector3(0, 1.9, 5.0), S + Vector3(0, 1.5, -0.5), 48.0)
	c.cam_to(S + Vector3(-0.5, 1.75, 3.1), S + Vector3(0.1, 1.45, -0.55), 1.6, 40.0)
	await c.wait(1.7)
	# врезка — картинка в рамке справа: что показывают, пока ведущий говорит
	var insert := func(title: String, big: String, col: Color) -> Control:
		c.vhs(0.5, 0.15)
		G67Sound.play(c, "click")
		return c.screen(func(s: Control, fs: Vector2):
			_r(s, Color(0.02, 0.03, 0.05), Vector2(fs.x * 0.54, fs.y * 0.12), Vector2(fs.x * 0.42, fs.y * 0.46))
			_r(s, col, Vector2(fs.x * 0.54, fs.y * 0.12), Vector2(fs.x * 0.42, 8))
			_l(s, title, 22, Color(0.8, 0.85, 0.95), Vector2(fs.x * 0.56, fs.y * 0.14))
			var l := _l(s, big, 44, col, Vector2(fs.x * 0.54, fs.y * 0.27), fs.x * 0.42)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART)
	c.plate("ТАРИФЫ ВРЕМЕННО НЕ ДЕЙСТВУЮТ · ОЧЕРЕДЬ РАЗОШЛАСЬ БЕСПЛАТНО · ХОМЯКИ ОТ КОММЕНТАРИЕВ ОТКАЗАЛИСЬ", "ticker", 24.0)
	var d0 := c.say_async(G67Clips.L("NEWS02", 0))
	await c.wait(d0 * 0.35)
	var i1: Control = insert.call("КАССОВЫЙ КОМПЛЕКС · ЗАПИСЬ КАМЕРЫ", "ТРИ ЛИНИИ ТУРНИКЕТОВ\nОПЛАЧЕНО: 0", GOLD)
	await c.wait(d0 * 0.65 + 0.3)
	i1.queue_free()
	c.cam_at(S + Vector3(-1.9, 1.55, 1.7), S + Vector3(0.05, 1.45, -0.55), 38.0)
	var d1 := c.say_async(G67Clips.L("NEWS02", 1))
	await c.wait(d1 * 0.3)
	var i2: Control = insert.call("ТАБЛО У ВЫХОДА", "НЕДОСТАТОЧНО\nСРЕДСТВ", RED)
	await c.wait(d1 * 0.7 + 0.3)
	i2.queue_free()
	c.cam_at(S + Vector3(-0.2, 1.7, 2.7), S + Vector3(0.05, 1.5, -0.55), 36.0)
	c.cam_to(S + Vector3(0.0, 1.68, 2.1), S + Vector3(0.05, 1.52, -0.55), 5.0, 30.0)
	await _say(c, "NEWS02", 2, 0.6)
	c.vhs(0.8, 0.3)

# ------------------------------------------------------------------ PZ_TARIFF01 «ПРАВО ПОСМОТРЕТЬ НА ТАРИФ»
static func tariff(c: G67ClipPlayer) -> void:
	_tunnel(c)
	c.prop(PZ + "g67_pz_tariff_board.glb", Vector3(0.0, 0.6, -1.0), 0.0, Vector3(9, 2.0, 9))
	c.cam_at(Vector3(0.0, 1.6, 3.4), Vector3(0, 1.5, -1.0), 44.0)
	c.cam_to(Vector3(0.0, 1.6, 2.2), Vector3(0, 1.55, -1.0), 3.0, 36.0)
	var sh := {}
	var ui := c.screen(func(s: Control, fs: Vector2):
		var board := _r(s, Color(0.05, 0.08, 0.06), Vector2(fs.x * 0.2, fs.y * 0.16), Vector2(fs.x * 0.6, fs.y * 0.5))
		var rows := ["ВХОД — 8", "ВЫХОД — 67", "ПОСТОЯТЬ — 8/мин", "ПОСМОТРЕТЬ НА ТАРИФ — 8"]
		for i in rows.size():
			_l(board, rows[i], 34, GOLD, Vector2(30, 24.0 + float(i) * 58.0))
		var cover := _r(s, Color(0.75, 0.12, 0.1), Vector2(fs.x * 0.2, fs.y * 0.16), Vector2(fs.x * 0.6, fs.y * 0.5))
		var l := _l(cover, "ПРОСМОТР ТАРИФА — 8 ₽", 44, Color.WHITE, Vector2(0, fs.y * 0.2), fs.x * 0.6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sh["c"] = cover)
	await c.wait(3.0)
	# шторка приоткрывается на долю секунды
	var cover: ColorRect = sh["c"]
	var y0: float = cover.position.y
	var tw: Tween = c.create_tween()
	tw.tween_property(cover, "position:y", y0 - cover.size.y * 0.8, 0.12)
	tw.tween_interval(0.22)
	tw.tween_property(cover, "position:y", y0, 0.1)
	G67Sound.play(c, "counter_click")
	await c.wait(0.9)
	await _say(c, "PZ_TARIFF01", 0, 0.8)
	G67Sound.play(c, "coin")
	c.plate("СПИСАНО: 8", "caption", 1.2)
	await c.wait(1.4)
	ui.queue_free()

# ------------------------------------------------------------------ PZ_SELLER01 «КОРОБКА» (9:16, старый телефон)
static func seller(c: G67ClipPlayer) -> void:
	_tunnel(c)
	c.filters(0.5, 0.7)
	c.prop(PZ + "g67_pz_kiosk_phones.glb", Vector3(0.0, 0.0, -1.4), 0.0, Vector3(9, 2.4, 9))
	c.actor("sel", "pz_prm", Vector3(0.0, 0.0, 0.2), 0.0)
	c.anim("sel", "Wave", 0.1, 0.6)
	var bx := c.box(Vector3(0.3, 0.22, 0.26), Vector3(0.3, 0.95, 0.6), Color(0.72, 0.55, 0.34))
	c.cam_at(Vector3(0.1, 1.45, 3.0), Vector3(0, 1.25, 0.2), 46.0)
	c.shake(0.12)
	var ui := c.screen(func(s: Control, fs: Vector2):
		_l(s, "ВИДЕО 0041.3gp", 22, Color(1, 1, 1, 0.8), Vector2(20, 20))
		_l(s, "▮▮▮▯ 12%", 22, Color(1, 0.4, 0.3), Vector2(fs.x - 150, 20)))
	c.create_tween().tween_property(bx, "position", Vector3(0.12, 1.2, 1.7), 0.8).set_trans(Tween.TRANS_BACK).set_delay(0.6)      # суёт коробку в камеру
	await c.wait(1.5)
	await _say(c, "PZ_SELLER01", 0, 0.3)
	c.shake(0.2)
	await _say(c, "PZ_SELLER01", 1, 0.2)
	await _say(c, "PZ_SELLER01", 2, 0.5)
	c.vhs(1.0, 0.3)
	G67Sound.play(c, "hit_cut")
	await c.wait(0.3)
	ui.queue_free()

# ------------------------------------------------------------------ PZ_CCTV_EXIT «ВЫХОД ЧЕРЕЗ ВХОД»
static func cctv_exit(c: G67ClipPlayer) -> void:
	_tunnel(c)
	var cnt := {}
	var ov := _cctv(c, "CAM 01 · ВХОД")
	var ui := c.screen(func(s: Control, fs: Vector2):
		cnt["l"] = _l(s, "ПОПЫТКА 0. СПИСАНО: 0", 30, CCTV, Vector2(26, 58)))
	c.box(Vector3(0.3, 1.0, 1.2), Vector3(-0.7, 0.5, 0.0), Color(0.5, 0.55, 0.5))
	c.box(Vector3(0.3, 1.0, 1.2), Vector3(0.7, 0.5, 0.0), Color(0.5, 0.55, 0.5))
	var bar := c.box(Vector3(1.1, 0.08, 0.08), Vector3(0.0, 0.9, 0.0), RED, 0.6)
	var man := c.box(Vector3(0.45, 1.6, 0.3), Vector3(0.0, 0.8, 2.4), Color(0.35, 0.4, 0.55))
	c.cam_at(Vector3(-2.8, 3.0, 3.6), Vector3(0, 0.8, 0.6), 52.0)
	await c.wait(1.0)
	for i in 3:
		var tw: Tween = c.create_tween()
		tw.tween_property(man, "position:z", 0.45, 0.55)
		await c.wait(0.6)
		G67PzClips._play(c, G67PzClips._snd_squeak(1300.0, 0.2), -4.0)
		c.create_tween().tween_property(bar, "rotation:y", bar.rotation.y + PI, 0.25)
		var tb: Tween = c.create_tween()                                     # турникет разворачивает обратно
		tb.tween_property(man, "rotation:y", man.rotation.y + PI, 0.25)
		tb.tween_property(man, "position:z", 2.4, 0.5)
		(cnt["l"] as Label).text = "ПОПЫТКА %d. СПИСАНО: %d" % [i + 1, i + 1]
		G67Sound.play(c, "coin")
		await c.wait(1.2)
	await c.wait(0.8)
	c.vhs(0.8, 0.3)
	ui.queue_free()
	ov.queue_free()
