## Ролики этапа 6, район ПОДЗЕМКА: AD02 «ПЕРВЫЙ ПРОХОД ПОЧТИ БЕСПЛАТНЫЙ» (реклама), PZ_STREAM01 «НЕ ГРЫЗИ НОГТИ» (вертикальный стрим),
## PZ_BALLOON01 «ПОДЗЕМНЫЙ БАС» (гэг). Постановка — PODZEMKA_DESIGN раздел 6, итоги и длительности — PODZEMKA_CINEMATICS.md.
## Запускаются из G67Clips.run (G67ClipPlayer: камера, реплики с голосом, плашки, экраны поверх кадра). Длительность реплик берётся из озвучки (say_async).
class_name G67PzClips
extends RefCounted

const GOLD := Color(1.0, 0.82, 0.18)
const GREEN := Color(0.4, 0.95, 0.35)
const RED := Color(1.0, 0.18, 0.12)

## Клипы персонажей поверх Poses.pahan(): приветствие рукой, хватается за щёку (после пощёчины)
static func wave_clips() -> Dictionary:
	var en := Callable(Poses, "en")
	var w1: Dictionary = en.call({"rarm": {"x": -2.6, "z": -0.5}, "rfa": {"x": -0.5}, "head": {"z": 0.1}, "spine": {"x": -0.05}})
	var w2: Dictionary = en.call({"rarm": {"x": -2.6, "z": -0.9}, "rfa": {"x": -0.9}, "head": {"z": -0.1}, "spine": {"x": -0.05}})
	var cheek: Dictionary = en.call({"larm": {"x": -1.6, "z": 0.3}, "lfa": {"x": -1.9}, "head": {"y": 0.7, "x": 0.1}, "spine": {"x": 0.08, "y": 0.3}})
	var inhale: Dictionary = en.call({"rarm": {"x": -1.7, "z": -0.2}, "rfa": {"x": -1.7}, "head": {"x": -0.2}, "spine": {"x": -0.08}})
	return {
		"Wave": {"d": 0.8, "loop": true, "k": [[0.0, w1], [0.5, w2], [1.0, w1]]},
		"Cheek": {"d": 1.0, "loop": true, "k": [[0.0, cheek], [1.0, cheek]]},
		"Inhale": {"d": 1.4, "loop": true, "k": [[0.0, inhale], [1.0, inhale]]},
	}

static func _snd_squeak(freq: float, dur: float, vol := 0.5) -> AudioStreamWAV:
	var n := int(dur * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * (freq * (1.0 + 0.8 * t)) / 22050.0
		d.encode_s16(i * 2, int(clampf(sin(ph) * (1.0 - t) * vol + sin(ph * 2.01) * 0.1 * (1.0 - t), -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w

static func _snd_jingle() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5]
	var n := int(1.6 * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		var t := float(i) / 22050.0
		var k := mini(int(t / 0.2), notes.size() - 1)
		var lt := t - float(k) * 0.2
		var v := sin(TAU * float(notes[k]) * t) * exp(-lt * 6.0) * 0.4 + sin(TAU * float(notes[k]) * 2.0 * t) * exp(-lt * 9.0) * 0.12
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w

static func _snd_bass(dur: float) -> AudioStreamWAV:
	var n := int(dur * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		var t := float(i) / float(n)
		d.encode_s16(i * 2, int(sin(TAU * 42.0 * float(i) / 22050.0) * (1.0 - t) * 0.7 * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w

static func _play(c: G67ClipPlayer, st: AudioStreamWAV, db := -4.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	c.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

static func _lbl(parent: Control, text: String, size: int, col: Color, pos: Vector2, w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.position = pos
	if w > 0.0:
		l.size = Vector2(w, size * 1.4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

static func _rect(parent: Control, col: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	parent.add_child(r)
	return r

## Вспышка-вайп склейки рекламы: белый кадр гаснет за sec секунд
static func _flash(c: G67ClipPlayer, col: Color, sec: float) -> void:
	c.screen(func(s: Control, fs: Vector2):
		var r := _rect(s, col, Vector2.ZERO, fs)
		var tw: Tween = c.create_tween()
		tw.tween_property(r, "modulate:a", 0.0, sec)
		tw.tween_callback(s.queue_free))

# ======================================================================== AD02
static func ad02(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	var U := Vector3(0, 0, 0)
	G67Clips._metro(c, U)
	c.light(U + Vector3(0, 3.0, 3.0), Color(1.0, 1.0, 0.95), 5.0, 14.0)           # рекламный пересвет
	c.sun(Vector3(-50, 20, 0), Color(1.0, 0.98, 0.9), 1.6)
	c.filters(0.0, 0.0)
	var glow := c.screen(func(s: Control, fs: Vector2):
		_rect(s, Color(1.0, 0.98, 0.85, 0.16), Vector2.ZERO, fs))              # сияние-плёнка
	_play(c, _snd_jingle(), -6.0)
	# 1 — проезд камеры по сияющему переходу, диктор, плашка «ПОДЗЕМКА!»
	c.cam_at(Vector3(-3.6, 1.6, 4.6), Vector3(0, 1.4, -1.0), 62.0)
	c.cam_to(Vector3(1.8, 1.5, 2.6), Vector3(0, 1.4, -1.0), 3.4, 50.0)
	var d1 := c.say_async(G67Clips.L("AD02", 0))
	c.plate("ПОДЗЕМКА!", "caption", 1.6)
	await c.wait(maxf(d1, 2.2) + 1.0)
	# 2 — Контролёр и Зазывала машут в камеру, вайп-вспышка
	_flash(c, Color(1, 1, 1), 0.35)
	G67Sound.play(c, "hit_cut")
	var ctl := c.actor("ctl", "pz_ctl", Vector3(-0.9, 0.0, 0.6), 0.0)
	var prm := c.actor("prm", "pz_prm", Vector3(0.9, 0.0, 0.6), 0.0)
	c.anim("ctl", "Wave", 0.1)
	c.anim("prm", "Wave", 0.1, 1.3)
	c.cam_at(Vector3(0.0, 1.5, 4.0), Vector3(0, 1.3, 0.6), 45.0)
	c.cam_to(Vector3(0.0, 1.5, 2.6), Vector3(0, 1.4, 0.6), 2.4, 36.0)
	var d2 := c.say_async(G67Clips.L("AD02", 1))
	await c.wait(1.2)
	# 3 — плашки тарифов вылетают, «ПОЧТИ*»
	_flash(c, GOLD, 0.25)
	var tariffs := c.screen(func(s: Control, fs: Vector2):
		var items := ["ВХОД — 8", "ВЫХОД — 67", "ВОПРОС — 67", "ПОЧТИ*"]
		for i in items.size():
			var big: bool = i == items.size() - 1
			var pl := _rect(s, GOLD if not big else RED, Vector2(-500.0, 80.0 + float(i) * 90.0), Vector2(380, 70))
			_lbl(pl, items[i], 40, Color(0.1, 0.07, 0.0) if not big else Color.WHITE, Vector2(20, 10))
			var tw: Tween = c.create_tween()
			tw.tween_interval(0.25 * float(i))
			tw.tween_property(pl, "position:x", fs.x - 440.0 if i % 2 == 0 else 60.0, 0.3).set_trans(Tween.TRANS_BACK))
	G67Sound.play(c, "tap")
	await c.wait(maxf(d2 - 1.0, 1.4))
	tariffs.queue_free()
	# 4 — резкий зум в мелкий шрифт договора
	_flash(c, Color(1, 1, 1), 0.2)
	var d3 := c.say_async(G67Clips.L("AD02", 2))
	var fine := c.screen(func(s: Control, fs: Vector2):
		_rect(s, Color(0.96, 0.95, 0.9), Vector2.ZERO, fs)
		var t := _lbl(s, "*ВЫХОД ОПЛАЧИВАЕТСЯ ОТДЕЛЬНО", 12, Color(0.2, 0.2, 0.2), fs * 0.5 - Vector2(130, 8))
		t.pivot_offset = Vector2(130, 8)
		t.scale = Vector2(1.0, 1.0)
		var tw: Tween = c.create_tween()
		tw.tween_property(t, "scale", Vector2(5.5, 5.5), 1.4).set_trans(Tween.TRANS_EXPO))
	G67Sound.play(c, "click")
	await c.wait(1.6)
	fine.queue_free()
	await c.wait(maxf(d3 - 1.6, 0.0))
	# 5 — покупатель у турникета: писк, красный крест, «ВАМ ОСТАЛОСЬ ДОПЛАТИТЬ 67 РУБЛЕЙ»
	_flash(c, Color(1, 1, 1), 0.25)
	c.cam_at(Vector3(1.6, 1.4, 3.2), Vector3(0, 1.1, 0.3), 46.0)
	c.cam_to(Vector3(0.9, 1.3, 2.2), Vector3(0, 1.1, 0.3), 1.8, 38.0)
	var buyer := c.box(Vector3(0.45, 1.5, 0.3), Vector3(0.0, 0.75, 1.5), Color(0.3, 0.5, 0.85))
	var bt: Tween = c.create_tween()
	bt.tween_property(buyer, "position:z", 0.75, 0.7)
	await c.wait(0.8)
	_play(c, _snd_squeak(1300.0, 0.35), -3.0)
	var cross := c.screen(func(s: Control, fs: Vector2):
		var x := _lbl(s, "✖", 220, RED, Vector2(fs.x * 0.5 - 90, fs.y * 0.18))
		x.scale = Vector2(0.1, 0.1)
		x.pivot_offset = Vector2(100, 110)
		var tw: Tween = c.create_tween()
		tw.tween_property(x, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK))
	c.shake(0.3)
	c.plate("ВАМ ОСТАЛОСЬ ДОПЛАТИТЬ 67 РУБЛЕЙ", "caption", 1.6)
	await c.wait(2.6)
	cross.queue_free()
	# 6 — логотип-колесо FORTUNA 812 и слоган
	_flash(c, GOLD, 0.3)
	_play(c, _snd_jingle(), -5.0)
	c.cam_at(Vector3(0, 1.5, 6.0), Vector3(0, 1.5, 0), 40.0)
	var d4 := c.say_async(G67Clips.L("AD02", 3))
	var logo := c.screen(func(s: Control, fs: Vector2):
		_rect(s, Color(0.05, 0.28, 0.12), Vector2.ZERO, fs)
		var wheel := Control.new()
		wheel.position = fs * 0.5 + Vector2(0, -40)
		s.add_child(wheel)
		for i in 8:
			var seg := _rect(wheel, GOLD if i % 2 == 0 else Color(0.15, 0.6, 0.25), Vector2(0, -12), Vector2(150, 24))
			seg.pivot_offset = Vector2(0, 12)
			seg.rotation = TAU * float(i) / 8.0
		var tw: Tween = c.create_tween()
		tw.tween_property(wheel, "rotation", TAU * 1.5, 3.0).set_trans(Tween.TRANS_CUBIC)
		_lbl(s, "FORTUNA 812", 72, GOLD, Vector2(0, fs.y * 0.68), fs.x)
		_lbl(s, "МЫ ЗА ВАШИ ДЕНЬГИ", 36, Color.WHITE, Vector2(0, fs.y * 0.82), fs.x))
	await c.wait(maxf(d4 + 2.4, 4.6))
	glow.queue_free()
	logo.queue_free()

# ======================================================================== PZ_STREAM01
static func stream01(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	var U := Vector3(0, 0, 0)
	G67Clips._metro(c, U)
	for k in 3:
		var kx := -3.5 + float(k) * 3.5
		c.box(Vector3(2.0, 2.2, 1.4), Vector3(kx, 1.1, -1.0), Color(0.45, 0.5, 0.52))
		c.box(Vector3(1.6, 0.5, 0.05), Vector3(kx, 2.0, -0.28), GOLD, 0.8)
	c.light(Vector3(0, 3.0, 2.0), Color(1.0, 0.95, 0.85), 4.5, 14.0)
	c.light(Vector3(0.4, 1.9, 5.0), Color(1.0, 0.9, 0.78), 3.5, 9.0)          # свет «от телефона»: лицо и переход читаются
	c.light(Vector3(-2.5, 2.4, 0.5), Color(0.8, 0.9, 1.0), 2.5, 9.0)
	var p := c.actor("pahan", "pahan", Vector3(0.0, 0.0, 2.2), 0.0)
	c.anim("pahan", "Walk", 0.1)
	var cb := {}
	var chat_lines: Array = []
	var ui := c.screen(func(s: Control, fs: Vector2):
		var rec := _lbl(s, "● REC", 34, RED, Vector2(24, 24))
		var rt: Tween = c.create_tween().set_loops()
		rt.tween_property(rec, "modulate:a", 0.15, 0.5)
		rt.tween_property(rec, "modulate:a", 1.0, 0.5)
		_lbl(s, "👁 67", 34, Color.WHITE, Vector2(fs.x - 190, 24))
		_lbl(s, "ОБЛАКО LIVE", 24, Color(0.8, 0.9, 1.0), Vector2(24, 68))
		var box := Control.new()
		box.position = Vector2(20, fs.y * 0.52)
		s.add_child(box)
		cb["box"] = box)
	var say_chat := func(nick: String, text: String):
		var l := _lbl(cb["box"] as Control, "%s: %s" % [nick, text], 24, Color.WHITE, Vector2(0, 0))
		chat_lines.append(l)
		for i in chat_lines.size():
			(chat_lines[chat_lines.size() - 1 - i] as Label).position.y = -float(i) * 34.0 + 0.0
		if chat_lines.size() > 9:
			(chat_lines.pop_front() as Label).queue_free()
	var heart := func():
		c.screen(func(s: Control, fs: Vector2):
			var h := _lbl(s, "♥", 56, Color(1.0, 0.3, 0.45), Vector2(fs.x - 90 - randf() * 60.0, fs.y * 0.75))
			var tw: Tween = c.create_tween()
			tw.tween_property(h, "position:y", fs.y * 0.3, 1.4)
			tw.parallel().tween_property(h, "modulate:a", 0.0, 1.4)
			tw.tween_callback(s.queue_free))
	var hand := c.create_tween().set_loops()
	hand.tween_callback(func(): c.shake(0.12))
	hand.tween_interval(0.14)
	# 1 — селфи с рук на ходу по галерее
	var d1 := c.say_async(G67Clips.L("PZ_STREAM01", 0))
	c.cam_at(Vector3(0.1, 1.5, 4.4), Vector3(0.0, 1.35, 2.2), 62.0)
	c.cam_to(Vector3(0.0, 1.5, 5.6), Vector3(0.0, 1.35, 2.2), d1 + 1.8, 56.0)
	c.move("pahan", Vector3(0.0, 0.0, 3.8), d1 + 1.8)
	var chat_t: Tween = c.create_tween()
	var seeds := [["Джелос", "Вау"], ["кент_67", "привет"], ["sasha_hamster", "а почему тут платно"], ["Джелос", "Джелос: 8 ₽ — в этой"], ["madk_fan", "брат стримит из метро"]]
	for i in seeds.size():
		chat_t.tween_interval(0.7)
		chat_t.tween_callback(func(): say_chat.call(String(seeds[i][0]), String(seeds[i][1])); heart.call())
	var don := c.screen(func(s: Control, fs: Vector2):
		var b := _rect(s, Color(0.2, 0.7, 0.3, 0.9), Vector2(fs.x * 0.1, fs.y * 0.12), Vector2(fs.x * 0.8, 70))
		b.modulate.a = 0.0
		_lbl(b, "Джелос: 8 ₽ — в этой", 26, Color.WHITE, Vector2(20, 18))
		var tw: Tween = c.create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(b, "modulate:a", 1.0, 0.2)
		tw.tween_interval(1.6)
		tw.tween_property(b, "modulate:a", 0.0, 0.3))
	await c.wait(d1 + 1.8)
	# 2 — FORTUNA входит сбоку очень близко
	c.anim("pahan", "Idle", 0.2)
	var f := c.actor("fort", "fortuna", Vector3(-2.2, 0.0, 3.4), -PI * 0.5 + 0.2)
	c.anim("fort", "Idle", 0.0)
	var d2 := c.say_async(G67Clips.L("PZ_STREAM01", 1))
	c.move("fort", Vector3(-0.55, 0.0, 3.5), 0.9)
	c.cam_at(Vector3(0.0, 1.6, 5.2), Vector3(-0.3, 1.5, 3.4), 56.0)
	c.cam_to(Vector3(0.0, 1.65, 5.0), Vector3(-0.4, 1.6, 3.5), 1.0, 40.0)
	await c.wait(d2 + 0.8)
	# 3 — пауза 2 с: чат замирает на «?», «??»
	say_chat.call("кент_67", "?")
	say_chat.call("sasha_hamster", "??")
	hand.kill()
	var ph := c.actor("ph_close", "pahan", Vector3(0.0, 0.0, 0.0), PI)
	ph.visible = false
	c.cam_at(Vector3(0.0, 1.55, 4.6), Vector3(0.0, 1.55, 3.7), 34.0)
	c.cam_to(Vector3(0.0, 1.55, 4.3), Vector3(0.0, 1.55, 3.7), 2.0, 28.0)
	await c.wait(2.0)
	# 4 — мультяшная пощёчина: замах, «ШЛЁП», рывок камеры, звёздочки
	c.anim_once("fort", "FTape", 0.5)
	await c.wait(0.4)
	_play(c, _snd_squeak(180.0, 0.18, 0.9), -1.0)
	G67Sound.play(c, "hit_cut")
	c.shake(1.2)
	c.cam_at(Vector3(0.6, 1.7, 4.8), Vector3(0.4, 1.4, 3.5), 62.0)
	c.anim("pahan", "Cheek", 0.05)
	c.screen(func(s: Control, fs: Vector2):
		var st := _lbl(s, "ШЛЁП!", 150, Color(1.0, 0.9, 0.2), Vector2(0, fs.y * 0.3), fs.x)
		for i in 5:
			var star := _lbl(s, "★", 70, Color(1, 1, 0.4), Vector2(fs.x * (0.25 + 0.12 * float(i)), fs.y * 0.2 + 30.0 * float(i % 2)))
			var tw: Tween = c.create_tween()
			tw.tween_property(star, "modulate:a", 0.0, 0.9)
		var tw2: Tween = c.create_tween()
		tw2.tween_interval(0.9)
		tw2.tween_callback(s.queue_free))
	await c.wait(1.0)
	# 5 — «ОСУЖДАЮ!»: разворот, бег, сильная тряска, чат летит
	var d3 := c.say_async(G67Clips.L("PZ_STREAM01", 2))
	for m in [["Крот", "БРАТ ЧТО ПРОИСХОДИТ"], ["кент_67", "ОСУЖДАЮ"], ["sasha_hamster", "67 ЗРИТЕЛЕЙ"], ["Джелос", "ВЕРНИСЬ В КАДР"], ["madk_fan", "АХАХАХА"], ["кент_67", "ОН ПРАВ НАСЧЁТ НОГТЕЙ"]]:
		say_chat.call(String(m[0]), String(m[1]))
	hand = c.create_tween().set_loops()
	hand.tween_callback(func(): c.shake(0.7))
	hand.tween_interval(0.07)
	c.cam_at(Vector3(0.0, 1.5, 4.8), Vector3(0.0, 1.5, 2.0), 66.0)
	c.cam_to(Vector3(-0.5, 1.4, 1.0), Vector3(-1.0, 1.4, -2.0), d3 + 1.2, 70.0)
	for i in 4:
		heart.call()
	await c.wait(d3 + 2.2)
	# 6 — камера оборачивается: FORTUNA вдалеке поправляет пиджак и смотрит в камеру
	hand.kill()
	c.actor("fort2", "fortuna", Vector3(0.0, 0.0, -6.0), 0.0)
	c.anim_once("fort2", "FPhase", 1.4)
	var d4 := c.say_async(G67Clips.L("PZ_STREAM01", 3))
	c.cam_at(Vector3(0.0, 1.5, 2.0), Vector3(0.0, 1.5, -6.0), 52.0)
	c.cam_to(Vector3(0.0, 1.5, 1.4), Vector3(0.0, 1.55, -6.0), d4 + 0.4, 38.0)
	await c.wait(d4 + 1.4)
	# заставка
	c.screen(func(s: Control, fs: Vector2):
		_rect(s, Color(0.02, 0.02, 0.05), Vector2.ZERO, fs)
		_lbl(s, "ТРАНСЛЯЦИЯ ЗАВЕРШЕНА", 40, Color.WHITE, Vector2(0, fs.y * 0.42), fs.x)
		_lbl(s, "ДОНАТОВ: 8 ₽", 40, GOLD, Vector2(0, fs.y * 0.5), fs.x))
	await c.wait(3.1)
	ui.queue_free()
	don.queue_free()

# ======================================================================== PZ_BALLOON01
static func balloon01(c: G67ClipPlayer) -> void:
	c.set_env("room")
	c.box(Vector3(10, 0.1, 8), Vector3(0, -0.05, 0), Color(0.3, 0.3, 0.3))
	c.box(Vector3(10, 4, 0.2), Vector3(0, 2, -2.0), Color(0.35, 0.38, 0.36))
	c.box(Vector3(3.2, 2.2, 1.0), Vector3(-2.5, 1.1, -1.3), Color(0.5, 0.45, 0.2))
	var sign := Label3D.new()
	sign.text = "ШАРЫ. ПРАЗДНИК. ТАРИФ"
	sign.font_size = 40
	sign.pixel_size = 0.007
	sign.modulate = GOLD
	sign.position = Vector3(-2.5, 2.5, -0.78)
	c.world.add_child(sign)
	c.light(Vector3(0, 3.0, 2.0), Color(1.0, 0.95, 0.8), 3.0, 12.0)
	# 1 — нарезка: три шара надуваются с писком резины (красный, жёлтый, зелёный)
	var cols := [Color(0.95, 0.15, 0.12), Color(1.0, 0.85, 0.12), Color(0.2, 0.85, 0.3)]
	c.cam_at(Vector3(-2.5, 1.5, 3.0), Vector3(-2.5, 1.2, -1.0), 44.0)
	var balls: Array = []
	for i in 3:
		_play(c, _snd_squeak(900.0 + 220.0 * float(i), 0.5, 0.45), -4.0)
		G67Sound.play(c, "hit_cut")
		var sh := c.screen(func(s: Control, fs: Vector2):
			_rect(s, Color(0.07, 0.07, 0.1), Vector2.ZERO, fs)
			var b := _rect(s, cols[i], fs * 0.5 - Vector2(20, 20), Vector2(40, 40))
			b.pivot_offset = Vector2(20, 20)
			var tw: Tween = c.create_tween()
			tw.tween_property(b, "scale", Vector2(7.0, 7.0), 0.55).set_trans(Tween.TRANS_EXPO)
			tw.parallel().tween_property(b, "size", Vector2(40, 40), 0.0))
		balls.append(sh)
		c.shake(0.3)
		await c.wait(0.7)
		sh.queue_free()
	# 2 — крупно шарик в руке
	var bal := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.34
	bal.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = cols[0]
	bm.roughness = 0.2
	bal.material_override = bm
	c.world.add_child(bal)
	var p := c.actor("pahan", "pahan", Vector3(0.6, 0.0, 0.8), 0.0)
	c.anim("pahan", "Idle", 0.0)
	var ph := Vector3(0.6, 1.4, 1.2)
	bal.position = ph + Vector3(-0.1, -0.15, 0.2)
	c.cam_at(ph + Vector3(0.6, 0.0, 1.0), bal.position, 28.0)
	c.cam_to(ph + Vector3(0.35, -0.05, 0.6), bal.position, 1.4, 22.0)
	_play(c, _snd_squeak(700.0, 0.3, 0.4), -6.0)
	await c.wait(1.5)
	# 3 — вдыхает из шарика: в профиль / со спины (мультяшный гэг), плашка
	c.anim("pahan", "Inhale", 0.2)
	var bt: Tween = c.create_tween()
	bt.tween_property(bal, "position", Vector3(0.6, 1.62, 1.55), 0.5)
	bt.parallel().tween_property(bal, "scale", Vector2(0.6, 0.6).x * Vector3.ONE, 1.4)
	c.cam_at(Vector3(3.5, 1.6, 0.8), Vector3(0.6, 1.5, 0.8), 38.0)
	c.cam_to(Vector3(3.0, 1.6, 0.9), Vector3(0.6, 1.5, 0.8), 1.8, 34.0)
	await c.wait(1.6)
	_flash(c, Color(1, 1, 1), 0.2)
	c.plate("PZ UNDERGROUND VOICE TEST", "caption", 1.6)
	await c.wait(1.5)
	# 4 — три низкие реплики, каждая — свой план; кадр дрожит, по полу идёт пыль
	var dust := c.screen(func(s: Control, fs: Vector2):
		for i in 14:
			var d := _rect(s, Color(0.7, 0.65, 0.55, 0.0), Vector2(randf() * fs.x, fs.y * 0.85 + randf() * 40.0), Vector2(26, 8))
			var tw: Tween = c.create_tween().set_loops()
			tw.tween_interval(randf() * 0.5)
			tw.tween_property(d, "modulate:a", 0.8, 0.2)
			tw.tween_property(d, "position:x", d.position.x + 160.0, 1.2)
			tw.tween_property(d, "modulate:a", 0.0, 0.3)
			tw.tween_property(d, "position:x", d.position.x, 0.0))
	c.anim("pahan", "Idle", 0.2)
	bal.visible = false
	var hh := Vector3(0.6, 1.65, 0.8)
	for k in 3:
		var d := c.say_async(G67Clips.L("PZ_BALLOON01", k))
		_play(c, _snd_bass(maxf(d, 1.0)), -2.0)
		c.shake(0.55)
		match k:
			0:
				c.cam_at(hh + Vector3(0.1, 0.0, 2.7), hh, 30.0)
				c.cam_to(hh + Vector3(0.05, 0.0, 2.3), hh, d + 0.3, 26.0)
			1:
				c.cam_at(hh + Vector3(0.5, -1.0, 2.1), hh + Vector3(0, 0.1, 0), 40.0)
				c.cam_to(hh + Vector3(0.35, -0.8, 1.8), hh + Vector3(0, 0.1, 0), d + 0.3, 36.0)
			2:
				c.light(hh + Vector3(0, 0.3, -1.5), Color(1, 0.9, 0.7), 8.0, 6.0)
				c.cam_at(hh + Vector3(-1.7, 0.0, 2.9), hh, 36.0)
				c.cam_to(hh + Vector3(-1.4, 0.0, 2.5), hh, d + 0.3, 32.0)
		await c.wait(d + 0.3)
	dust.queue_free()
	# 5 — шарик пищит и улетает, сдуваясь; обычный голос, взгляд в камеру; резкий обрыв
	bal.visible = true
	bal.scale = Vector3.ONE * 0.5
	bal.position = hh + Vector3(0.1, -0.1, 0.3)
	_play(c, _snd_squeak(1500.0, 1.1, 0.5), -2.0)
	var ft: Tween = c.create_tween()
	ft.tween_property(bal, "position", Vector3(2.5, 4.0, -1.0), 1.2)
	ft.parallel().tween_property(bal, "scale", Vector3.ONE * 0.1, 1.2)
	c.cam_at(hh + Vector3(0.4, 0.0, 2.6), Vector3(1.4, 2.4, 0.2), 52.0)
	c.cam_to(hh + Vector3(0.4, 0.2, 2.6), Vector3(2.2, 3.4, -0.6), 1.2, 44.0)
	await c.wait(1.3)
	var d4 := c.say_async(G67Clips.L("PZ_BALLOON01", 3))
	c.cam_at(hh + Vector3(0.0, 0.0, 2.7), hh, 34.0)
	await c.wait(d4 + 0.5)
	c.screen(func(s: Control, fs: Vector2):
		_rect(s, Color.BLACK, Vector2.ZERO, fs))
	await c.wait(0.25)
