## Ролики главы 1 «ГОЛДА 67» (ТЗ, раздел 13.1; постановка — docs/golda67/CINEMATIC_BIBLE.md). Каждый ролик — функция,
## которая ставит сцену в мире плеера (G67ClipPlayer) и ведёт её по кадрам: камера, персонажи, реплики, плашки.
## Реплики — дословно по ТЗ; их голоса — в манифесте озвучки главы 1 (G67Voice.clip_lines → tools/golda67-voice.cjs).
##
## Где показываются (Golda67): STORY01 и STORY05 — при первом входе в режим; V00 — на телевизоре в подъезде;
## AD01 — перед первым выходом во ДВОР; CL01 — открывается в архиве после входа во ДВОР; NEWS01 — по возвращении
## после первой победы над Мишей; EXTRA01 — в архиве после третьей встречи с КРОТОМ.
class_name G67Clips
extends RefCounted

const ORDER := ["STORY01", "STORY05", "V00", "AD01", "CL01", "NEWS01", "EXTRA01"]
const INFO := {
	"V00": {"title": "ТУРНИР 67 — трейлер", "tall": false},
	"AD01": {"title": "СТАНЬ АВТОРИТЕТОМ", "tall": false},
	"CL01": {"title": "КАК ЗАЙТИ ВО ДВОР", "tall": true},
	"NEWS01": {"title": "РАЙОННЫЙ ВЕСТНИК 67 · выпуск 1", "tall": false},
	"STORY01": {"title": "Регистрация", "tall": true},
	"STORY05": {"title": "Обращение WHYOUSOLONELY", "tall": false},
	"EXTRA01": {"title": "КРОТ НА ПОДКАСТЕ", "tall": true},
	"EV02": {"title": "ТРЯПКИ! ТРЯПКИ!", "tall": false},
}
const NAMES := {"V": "ПАХАН", "M": "MADK1D", "G1": "МИША МИНАСЯН", "KR": "КРОТ", "AN": "ВЕДУЩИЙ", "PH": "ВЕДУЩИЙ ПОДКАСТА",
	"WH": "WHYOUSOLONELY", "LS": "ГРОМКОГОВОРИТЕЛЬ", "DP": "ДИСПЕТЧЕР", "FT": "FORTUNA 812", "KX": "КОРОЛЕВСКИЙ XVII", "BS": "ПОЛКОВНИК БУСТЕРЕНКО"}

## Реплики роликов (порядок — как звучат). Голоса: см. G67Voice.SPEAKERS
const LINES := {
	"V00": ["G1|На этом районе уважают только сильнейших.", "G1|Так и задумано.", "FT|У нас каждый найдёт подходящий тариф.",
		"KX|Тебе нужен glow up.", "V|Мне нужен выход отсюда.", "BS|Каждый из них — живой человек.",
		"M|БРАТ, МЫ ВЫИГРАЕМ 67 ТЫСЯЧ!", "V|Ты меня уже записал?", "V|Я вас уже ненавижу."],
	"AD01": ["G1|Устал быть просто человеком? Хочешь, чтобы район знал твоё имя?", "G1|Приходи на Турнир 67. Здесь решается, кто реально главный.",
		"G1|Авторитет — это когда даже машина тебя уважает.", "G1|РЕГИСТРИРУЙСЯ. Пока твоё место не занял кто-то с более дорогими кроссовками."],
	"CL01": ["G1|Показываю, как настоящий авторитет заходит во двор.", "G1|Это был контроль пространства."],
	"NEWS01": ["AN|Сегодня в районе произошло историческое событие. Миша Минасян временно передал звание главного авторитета ближайшему свободному человеку.",
		"AN|Представители Минасяна назвали поражение плановым. Сам Минасян попросил не называть это поражением, а «временным снижением районного рейтинга»."],
	"STORY01": ["M|Брат, смотри, тут турнир. Шестьдесят семь тысяч голды. Это буквально судьба.", "V|Не трогай мой телефон.", "M|Я уже всё решил.",
		"V|ТЫ ЧЁ СДЕЛАЛ, БЛЯТЬ?!", "M|Брат, ты теперь спортсмен."],
	"STORY05": ["WH|Турнир 67 — это пространство абсолютных возможностей. Каждый участник свободен принимать собственные решения.",
		"WH|Ваш выбор имеет для нас огромное значение."],
	"EXTRA01": ["PH|Крот, расскажи, в чём твоя главная профессиональная компетенция?", "KR|Я хорошо чувствую понедельники. Мы с ними на ты.",
		"PH|А конкретно?", "KR|Если понедельник наступает, я сразу понимаю, что воскресенье закончилось."],
}

static func tall(id: String) -> bool:
	return bool(INFO.get(id, {}).get("tall", false))

static func title(id: String) -> String:
	return String(INFO.get(id, {}).get("title", id))

static func speaker(code: String) -> String:
	return String(NAMES.get(code, code))

static func L(id: String, i: int) -> String:
	return String(LINES[id][i])

static func run(c: G67ClipPlayer, id: String) -> void:
	G67Sound.play(c, "click")                     # щелчок включения записи
	c.vhs(0.7, 0.35)
	match id:
		"V00": await v00(c)
		"AD01": await ad01(c)
		"CL01": await cl01(c)
		"NEWS01": await news01(c)
		"STORY01": await story01(c)
		"STORY05": await story05(c)
		"EXTRA01": await extra01(c)
		"EV02": await ev02(c)
	await c.wait(0.3)

# ---------------------------------------------------------------- клипы персонажей для роликов
static func misha_clips() -> Dictionary:
	var P = G67Poses
	var C := {}
	var chest := {"spine": {"x": -0.14}, "head": {"x": -0.1}}
	C["CWalk"] = P._walk(1.25, P._mix({"rarm": {"z": -0.18, "x": 0.1}, "larm": {"z": 0.18, "x": 0.1}, "rfa": {"x": -0.2}, "lfa": {"x": -0.2}}, chest))
	C["CStand"] = P._loop(3.0, P._mix({"rarm": {"z": -0.2}, "larm": {"z": 0.2}, "rup": {"z": -0.1}, "lup": {"z": 0.1}}, chest), P.BREATH)
	C["CGlasses"] = P._seq(1.6, chest, [[0.0, {}], [0.4, {"rarm": {"x": -0.45, "z": -0.1}, "rfa": {"x": -2.3, "y": 1.0}, "head": {"x": 0.05}}, "out"],
		[0.7, {"rarm": {"x": -0.45, "z": -0.1}, "rfa": {"x": -2.35, "y": 1.05}, "head": {"x": -0.08}}], [1.0, {}]], false)
	C["CPoint"] = P._loop(2.0, P._mix(chest, {"rarm": {"x": -1.4, "z": -0.25}, "rfa": {"x": -0.08}, "head": {"y": -0.3}, "larm": {"z": 0.15}}), P.BREATH)
	C["CTalk"] = P._seq(2.6, P._mix(chest, {"larm": {"z": 0.15}}), [[0.0, {"rarm": {"x": -0.4}, "rfa": {"x": -0.9, "y": 0.4}}], [0.4, {"rarm": {"x": -0.5}, "rfa": {"x": -1.05, "y": 0.5}, "head": {"x": 0.05}}],
		[0.7, {"rarm": {"x": -0.4}, "rfa": {"x": -0.85, "y": 0.35}}], [1.0, {"rarm": {"x": -0.4}, "rfa": {"x": -0.9, "y": 0.4}}]])
	C["CYank"] = P._seq(0.9, chest, [[0.0, {}], [0.25, {"spine": {"x": -0.35}, "head": {"x": -0.25}, "rarm": {"z": -0.6}, "larm": {"z": 0.6}, "drop": 0.04}, "out"], [1.0, {"spine": {"x": -0.2}, "head": {"x": -0.12}, "rarm": {"z": -0.3}, "larm": {"z": 0.3}}]], false)
	C["CStuck"] = P._loop(1.2, P._mix(chest, {"spine": {"x": -0.22}, "head": {"x": -0.14}, "rarm": {"z": -0.32}, "larm": {"z": 0.32}}), {"spine": {"x": -0.02}})
	C["CSitHood"] = P._loop(3.0, P._mix(P.SIT, {"drop": 0.3, "spine": {"x": -0.1}, "rarm": {"x": -0.55, "z": -0.15}, "rfa": {"x": -0.3}, "larm": {"x": -0.55, "z": 0.15}, "lfa": {"x": -0.3}}), P.BREATH)
	C["CChainFix"] = P._seq(3.0, P._mix(P.SIT, {"spine": {"x": 0.12}, "head": {"x": 0.32}}), [[0.0, {"rarm": {"x": -0.35}, "rfa": {"x": -1.45, "y": 1.15}, "larm": {"x": -0.35}, "lfa": {"x": -1.45, "y": -1.15}}],
		[0.5, {"rarm": {"x": -0.4}, "rfa": {"x": -1.6, "y": 1.2}, "larm": {"x": -0.4}, "lfa": {"x": -1.6, "y": -1.2}, "head": {"x": 0.04}}], [1.0, {"rarm": {"x": -0.35}, "rfa": {"x": -1.45, "y": 1.15}, "larm": {"x": -0.35}, "lfa": {"x": -1.45, "y": -1.15}}]])
	return C

## Боссы следующих районов в трейлере: ведущий телемагазина, блогер у лампы, полковник за компьютером
static func boss_clips() -> Dictionary:
	var P = G67Poses
	return {
		"CPresent": P._loop(2.0, P._mix(P.W_L, {"rarm": {"x": -0.9, "z": -0.75}, "rfa": {"x": -0.15}, "larm": {"z": 0.12}, "lfa": {"x": -0.2}, "spine": {"x": -0.08}, "head": {"y": -0.2}}), {"rarm": {"z": -0.08}}),
		"CLamp": P._loop(2.2, P._mix(P.L_HIP, {"rarm": {"x": -1.2, "z": -0.15}, "rfa": {"x": -0.4}, "spine": {"x": -0.05}, "head": {"x": -0.1}}), P.BREATH),
		"CDesk": P._loop(2.6, P._mix(P.SIT, {"spine": {"x": 0.18}, "rarm": {"x": -0.95, "z": -0.1}, "rfa": {"x": -0.55, "y": 0.3}, "larm": {"x": -0.95, "z": 0.1}, "lfa": {"x": -0.55, "y": -0.3}, "head": {"x": -0.08}}), {"rfa": {"x": -0.06}}),
	}

static func madk_clips() -> Dictionary:
	var P = G67Poses
	return {
		"CPhoneOut": P._loop(2.4, {"rarm": {"x": -1.25, "z": -0.1}, "rfa": {"x": -0.3}, "larm": {"z": 0.05}, "spine": {"x": 0.08}, "head": {"x": 0.05}}, P.BREATH),
		"CSelfie": P._loop(2.2, {"rarm": {"x": -1.35, "z": -0.35}, "rfa": {"x": -0.5, "y": 0.4}, "spine": {"x": -0.05}, "head": {"x": -0.08, "y": -0.2}}, {"head": {"y": -0.05}}),
	}

static func krot_clips() -> Dictionary:
	var P = G67Poses
	var sit := P._mix(P.SIT, {"spine": {"x": 0.12}, "rarm": {"x": -0.95, "z": -0.05}, "rfa": {"x": -0.45, "y": 0.4}, "larm": {"x": -0.95, "z": 0.05}, "lfa": {"x": -0.45, "y": -0.4}, "head": {"x": -0.05}})
	return {
		"CPod": P._loop(3.6, sit, P.BREATH),
		"CPodTalk": P._seq(2.4, sit, [[0.0, {}], [0.35, {"rfa": {"x": -0.35, "y": 0.2}, "head": {"x": 0.05}}], [0.7, {}], [1.0, {}]]),
		"CPodNod": P._react(1.6, sit, {"head": {"x": 0.32}}),
	}

# ---------------------------------------------------------------- общие декорации
static func _yard(c: G67ClipPlayer) -> G67Yard:
	var y := G67Yard.new()
	c.world.add_child(y)
	y.build()
	c.set_env("night")
	c.sun(Vector3(-38, -35, 0), Color(0.55, 0.62, 0.9), 0.55)
	return y

## Снег в кадре (летит навстречу камере)
static func _snow(c: G67ClipPlayer, at: Vector3, size: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 400
	p.lifetime = 4.0
	p.position = at
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = size
	m.direction = Vector3(0.3, -1, 0.2)
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.4
	m.gravity = Vector3(0, -0.6, 0)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1, 1, 1, 0.85)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = qm
	p.draw_pass_1 = q
	c.world.add_child(p)
	return p

static func _chest(r: Rig) -> Vector3:
	var b := r.skel.find_bone("mixamorig_Spine2")
	return (r.skel.global_transform * r.skel.get_bone_global_pose(b)).origin if b >= 0 else r.global_position + Vector3(0, 1.3, 0)

static func _head(r: Rig) -> Vector3:
	var b := r.skel.find_bone("mixamorig_Head")
	return (r.skel.global_transform * r.skel.get_bone_global_pose(b)).origin if b >= 0 else r.global_position + Vector3(0, 1.7, 0)

## Падающие монеты поверх кадра; одна «отскакивает от стекла»
static func _coins(c: G67ClipPlayer, n: int) -> void:
	var fs := c.frame.size
	var gt := G67Icons.tex("icon_golda")
	for i in n:
		var coin: Node2D
		if gt != null:
			var r0 := fs.y * randf_range(0.03, 0.055)
			var sp := Sprite2D.new()
			sp.texture = gt
			sp.scale = Vector2.ONE * (r0 * 2.3 / float(gt.get_width()))
			coin = Node2D.new()
			coin.add_child(sp)
			coin.position = Vector2(randf_range(0.05, 0.95) * fs.x, -r0 * 2.0 - randf() * fs.y * 0.6)
			c.over.add_child(coin)
			_coin_fall(c, coin, i, r0, fs)
			continue
		coin = Polygon2D.new()
		var pts := PackedVector2Array()
		var r := fs.y * randf_range(0.03, 0.055)
		for k in 18:
			var a := TAU * k / 18.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.9))
		(coin as Polygon2D).polygon = pts
		(coin as Polygon2D).color = Color(1.0, 0.78, 0.2)
		var rim := Line2D.new()
		rim.points = pts
		rim.closed = true
		rim.width = r * 0.18
		rim.default_color = Color(0.45, 0.28, 0.05)
		coin.add_child(rim)
		var lb := Label.new()
		lb.text = "67"
		lb.add_theme_font_override("font", c.game.main.font)
		lb.add_theme_font_size_override("font_size", int(r * 0.9))
		lb.add_theme_color_override("font_color", Color(0.45, 0.28, 0.05))
		lb.position = Vector2(-r * 0.55, -r * 0.62)
		coin.add_child(lb)
		coin.position = Vector2(randf_range(0.05, 0.95) * fs.x, -r * 2.0 - randf() * fs.y * 0.6)
		c.over.add_child(coin)
		_coin_fall(c, coin, i, r, fs)

## Полёт монеты: первая летит в объектив и «бьётся о стекло», остальные падают с вращением
static func _coin_fall(c: G67ClipPlayer, coin: Node2D, i: int, r: float, fs: Vector2) -> void:
		var tw := c.create_tween()
		var dur := randf_range(1.2, 2.2)
		if i == 0:
			# эта летит прямо в объектив: растёт, «бьётся о стекло» и отскакивает вниз
			coin.position = Vector2(fs.x * 0.5, fs.y * 0.2)
			coin.scale = Vector2.ONE * 0.3
			tw.tween_property(coin, "scale", Vector2.ONE * 3.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				c.sfx("sfx_parry", -6.0, 1.6)
				c.shake(0.4))
			tw.tween_property(coin, "position", Vector2(fs.x * 0.62, fs.y * 1.3), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.set_parallel(true)
			tw.tween_property(coin, "position:y", fs.y + r * 2.0, dur).set_delay(randf() * 1.2)
			tw.tween_property(coin, "rotation", randf_range(-3.0, 3.0), dur)
		tw.chain().tween_callback(coin.queue_free)

# ---------------------------------------------------------------- V00 — трейлер «ТУРНИР 67»
## Плашка имени влетает сбоку на стоп-кадре
static func _nameplate(c: G67ClipPlayer, text: String) -> void:
	var fs := c.frame.size
	var h := Control.new()
	h.size = fs
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.over.add_child(h)
	var bar := ColorRect.new()
	bar.color = Color(0.72, 0.08, 0.08, 0.94)
	bar.size = Vector2(fs.x * 0.5, fs.y * 0.09)
	bar.position = Vector2(fs.x * 1.05, fs.y * 0.7)
	h.add_child(bar)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", c.game.main.font)
	l.add_theme_font_size_override("font_size", int(fs.y * 0.06))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.position = Vector2(fs.x * 0.02, fs.y * 0.01)
	bar.add_child(l)
	var tw := c.create_tween()
	tw.tween_property(bar, "position:x", fs.x * 0.06, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_property(bar, "modulate:a", 0.0, 0.1)
	tw.tween_callback(h.queue_free)

## Реплика двумя планами с наездом, на последнем слове — стоп-кадр: удар, сдвиг каналов, плашка с именем
static func _beat(c: G67ClipPlayer, line: String, who: String, a: Array, b: Array, extra := 0.1) -> void:
	var d := c.say_async(line)
	c.cam_at(a[0], a[1], a[2])
	c.cam_to(a[3], a[4], d * 0.5, a[5])
	await c.wait(d * 0.5)
	G67Sound.play(c, "hit_cut")
	c.vhs(0.5, 0.15)
	var d2 := maxf(d * 0.5 - 0.45, 0.2)
	c.cam_at(b[0], b[1], b[2])
	c.cam_to(b[3], b[4], d2, b[5])
	await c.wait(d2)
	G67Sound.play(c, "hit_cut")
	c.vhs(1.0, 0.5)
	c.shake(0.15)
	_nameplate(c, who)
	await c.wait(0.45 + extra)
	c.clear_sub()

static func _tariffs_async(c: G67ClipPlayer, fort: Control) -> void:
	for tx in ["ВХОД — 67", "ВЫХОД — 67", "ПОСМОТРЕТЬ НА ТУРНИКЕТ — 6,7"]:
		if not c.alive():
			return
		_tariff(c, fort, tx, tx.length() > 12)
		c.sfx("sfx_ui", -6.0, 0.9)
		await c.wait(0.6)

static func v00(c: G67ClipPlayer) -> void:
	var y := _yard(c)
	_snow(c, Vector3(0, 12, 25), Vector3(30, 4, 30))
	var door := Vector3(0.0, 0.0, 35.6)
	var m := c.actor("misha", "misha", door + Vector3(0, 0, -0.6), PI)
	# 1 — чёрный экран, тишина 1,5 с, одна строка-титр, удар
	var blk := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.size = fs
		s.add_child(r))
	c.plate("ТЫ ГОТОВ ИЗМЕНИТЬ СВОЙ РАЙОН?", "big", 1.6)
	await c.wait(1.5)
	G67Sound.play(c, "hit_cut")
	c.sfx("sfx_boom", 0.0, 0.6)
	await c.wait(0.4)
	blk.queue_free()
	c.clear_plates()
	# 2 — пролёт над двором и дождь монет, призовой фонд
	c.cam_at(Vector3(-34, 30, 46), Vector3(0, 0, 10), 55.0)
	c.cam_to(Vector3(18, 22, 4), Vector3(0, 0, 18), 2.6)
	c.plate("ПРИЗОВОЙ ФОНД — 67 000 ГОЛДЫ", "big", 2.4)
	_coins(c, 14)
	await c.wait(2.5)
	c.clear_plates()
	# 3 — Миша выходит: кроссовки → цепь → лицо, три коротких плана на ударах
	G67Sound.play(c, "hit_cut")
	c.anim("misha", "CWalk", 0.1, 0.5)
	c.move("misha", door + Vector3(0, 0, -2.4), 1.4)
	c.cam_at(door + Vector3(0.7, 0.25, -3.2), door + Vector3(0, 0.15, -1.0), 38.0)
	c.cam_to(door + Vector3(0.5, 0.3, -3.0), door + Vector3(0, 0.15, -1.2), 0.7, 34.0)
	await c.wait(0.7)
	G67Sound.play(c, "hit_cut")
	c.cam_at(door + Vector3(-0.9, 1.4, -3.6), _chest(m), 30.0)
	c.cam_to(door + Vector3(-0.6, 1.35, -3.2), _chest(m), 0.7, 26.0)
	await c.wait(0.7)
	G67Sound.play(c, "hit_cut")
	var hd := _head(m) - m.global_position + Vector3(0, 0.3, 0)
	var stop := door + Vector3(0, 0, -2.4)
	var a0 := stop + hd + Vector3(0.45, 0.12, -1.9)
	await _beat(c, L("V00", 0), "МИША МИНАСЯН", [a0, stop + hd, 30.0, a0 + Vector3(-0.1, 0, 0.5), stop + hd, 26.0],
		[stop + hd + Vector3(-0.8, 0.0, -1.4), stop + hd, 28.0, stop + hd + Vector3(-0.5, 0.0, -1.0), stop + hd, 24.0])
	# цепь цепляется за ручку двери — рывок крупно, ручная тряска
	c.chain(_chest(m), door + Vector3(0.45, 1.05, 0.05), 2.6)
	c.anim_once("misha", "CYank", 0.9)
	c.sfx("sfx_parry", -2.0, 0.7)
	c.shake(0.9)
	c.cam_at(door + Vector3(1.4, 1.3, -2.6), door + Vector3(0.2, 1.1, -0.8), 38.0)
	c.cam_to(door + Vector3(1.0, 1.25, -2.2), door + Vector3(0.25, 1.1, -0.8), 0.9, 32.0)
	await c.wait(0.9)
	c.anim("misha", "CStuck", 0.2)
	var hp2 := _head(m)
	await _beat(c, L("V00", 1), "МИША МИНАСЯН", [hp2 + Vector3(-0.5, 0.15, -1.7), hp2, 28.0, hp2 + Vector3(-0.3, 0.1, -1.1), hp2, 24.0],
		[hp2 + Vector3(0.6, -0.05, -1.2), hp2, 26.0, hp2 + Vector3(0.4, -0.05, -0.8), hp2, 22.0])
	# 4 — «вжух»: помеха и быстрый переход в ПОДЗЕМКУ; FORTUNA 812 открывает створку, тарифы вылетают плашками
	c.vhs(1.0, 0.4)
	G67Sound.play(c, "hit_cut")
	c.sfx("sfx_wave", -6.0, 1.8)
	var U := Vector3(60, 0, 0)
	_metro(c, U)
	var ft := c.actor("fortuna", "fortuna", U + Vector3(-0.9, 0, 0.6), 0.5)
	c.anim("fortuna", "CPresent", 0.0)
	var flap := c.box(Vector3(0.05, 0.75, 0.6), U + Vector3(0.0, 0.85, 0.3), Color(0.75, 0.85, 0.95, 1.0), 0.2)
	c.create_tween().tween_property(flap, "rotation:y", -1.3, 0.5).set_delay(0.6)
	var fort := Control.new()
	fort.size = c.frame.size
	c.over.add_child(fort)
	_tariffs_async(c, fort)
	await _beat(c, L("V00", 2), "FORTUNA 812", [U + Vector3(1.8, 1.5, 3.6), U + Vector3(-0.3, 1.1, 0.3), 46.0, U + Vector3(1.2, 1.45, 2.9), U + Vector3(-0.4, 1.15, 0.3), 40.0],
		[U + Vector3(-0.3, 1.55, 2.4), _head(ft), 32.0, U + Vector3(-0.5, 1.55, 1.9), _head(ft), 26.0])
	fort.queue_free()
	# 5 — Королевский XVII перед кольцевой лампой: Пахан пропадает в белом
	c.vhs(0.8, 0.3)
	G67Sound.play(c, "hit_cut")
	var K := Vector3(120, 0, 0)
	var p := c.actor("pahan", "pahan", K, 0.0)
	var kx := c.actor("korolevsky", "korolevsky", K + Vector3(1.3, 0, 1.0), -2.2)
	c.anim("korolevsky", "CLamp", 0.0)
	c.box(Vector3(8, 0.1, 8), K + Vector3(0, -0.05, 0), Color(0.08, 0.08, 0.1))
	c.box(Vector3(8, 4, 0.1), K + Vector3(0, 2, -1.5), Color(0.12, 0.1, 0.14))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	ring.mesh = tm
	ring.rotation.x = PI * 0.5
	ring.position = K + Vector3(0.0, 1.55, 1.6)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1, 1, 1)
	rmat.emission_enabled = true
	rmat.emission = Color(1, 1, 1)
	rmat.emission_energy_multiplier = 0.2
	ring.material_override = rmat
	c.world.add_child(ring)
	c.box(Vector3(0.04, 1.5, 0.04), K + Vector3(0.0, 0.75, 1.62), Color(0.1, 0.1, 0.1))
	c.light(K + Vector3(0, 2.5, 2.8), Color(0.9, 0.9, 1.0), 1.2, 8.0)
	c.cam_at(K + Vector3(-1.4, 1.5, 3.4), K + Vector3(0.3, 1.25, 0.3), 42.0)
	c.cam_to(K + Vector3(-0.9, 1.5, 3.0), K + Vector3(0.6, 1.3, 0.6), 0.6, 38.0)
	await c.wait(0.6)
	c.sfx("sfx_ui", -2.0, 1.8)
	G67Sound.play(c, "hit_cut")
	rmat.emission_energy_multiplier = 6.0
	var flash := c.light(K + Vector3(0, 1.5, 1.4), Color(1, 1, 1), 3.0, 5.0)
	var white := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.0)
		r.size = fs
		r.name = "w"
		s.add_child(r))
	var wt := c.create_tween()
	wt.tween_property(white.get_node("w"), "color:a", 0.7, 0.12)
	wt.tween_property(white.get_node("w"), "color:a", 0.12, 0.5)
	await _beat(c, L("V00", 3), "КОРОЛЕВСКИЙ XVII", [K + Vector3(-0.2, 1.5, 3.6), _head(kx), 40.0, K + Vector3(0.4, 1.5, 3.0), _head(kx), 34.0],
		[_head(kx) + Vector3(-0.2, 0.0, 1.3), _head(kx), 30.0, _head(kx) + Vector3(-0.1, 0.0, 1.0), _head(kx), 26.0])
	var wt2 := c.create_tween()
	wt2.tween_property(white.get_node("w"), "color:a", 0.72, 1.3)
	wt2.parallel().tween_property(flash, "light_energy", 7.0, 1.3)
	await _beat(c, L("V00", 4), "ПАХАН", [K + Vector3(0.3, 1.5, 2.4), _head(p), 34.0, K + Vector3(0.2, 1.5, 1.9), _head(p), 28.0],
		[_head(p) + Vector3(-0.5, 0.0, 1.0), _head(p), 28.0, _head(p) + Vector3(-0.3, 0.0, 0.8), _head(p), 24.0])
	white.queue_free()
	# 6 — Бустеренко запускает счётчик, отъезд: один профиль на всех мониторах
	c.vhs(0.9, 0.35)
	G67Sound.play(c, "hit_cut")
	var B := Vector3(180, 0, 0)
	_botfarm(c, B)
	var bs := c.actor("busterenko", "busterenko", B + Vector3(-1.2, 0, 0.6), PI)
	c.anim("busterenko", "CDesk", 0.0)
	c.create_tween().tween_property(bs, "position", B + Vector3(0.0, 0, 0.6), 0.9)        # шагает вдоль строя
	var bus := Control.new()
	bus.size = c.frame.size
	c.over.add_child(bus)
	var cnt := _counter(c, bus, 67000000, 1.8)
	await _beat(c, L("V00", 5), "ПОЛКОВНИК БУСТЕРЕНКО", [B + Vector3(1.0, 1.45, -0.75), _head(bs) + Vector3(0, 0.1, 0), 36.0, B + Vector3(0.7, 1.45, -0.4), _head(bs) + Vector3(0, 0.1, 0), 30.0],
		[B + Vector3(-0.8, 1.55, 1.8), _head(bs), 34.0, B + Vector3(-0.4, 1.55, 1.4), _head(bs), 28.0])
	var tw := c.create_tween()
	tw.tween_property(cnt, "modulate:a", 0.0, 0.3)
	c.cam_at(B + Vector3(0.6, 1.6, 2.2), B + Vector3(0, 1.3, -1.0), 40.0)
	c.cam_to(B + Vector3(3.8, 3.2, 6.5), B + Vector3(0, 1.6, -1.2), 1.4, 50.0)
	await c.wait(1.4)
	bus.queue_free()
	c.actors.erase("pahan")
	p.queue_free()
	# 7 — madk1d вбегает в кадр и суёт телефон Пахану в лицо, Пахан отмахивается; ручная тряска
	c.vhs(0.8, 0.3)
	G67Sound.play(c, "hit_cut")
	var p2 := c.actor("pahan", "pahan", door + Vector3(1.2, 0, -6.0), PI * 0.1)
	var mk := c.actor("madk1d", "madk1d", door + Vector3(1.0, 0, -10.5), PI * 0.05)
	c.anim("madk1d", "Run", 0.1, 1.1)
	c.create_tween().tween_property(mk, "position", door + Vector3(1.0, 0, -7.1), 0.9)
	c.cam_at(door + Vector3(2.8, 1.5, -9.4), door + Vector3(1.1, 1.2, -6.6), 44.0)
	c.shake(0.5)
	await c.wait(0.9)
	c.anim("madk1d", "CPhoneOut", 0.1)
	c.anim_once("pahan", "Hit", 0.5)
	await _beat(c, L("V00", 6), "MADK1D", [door + Vector3(2.4, 1.45, -8.6), door + Vector3(1.1, 1.2, -6.4), 42.0, door + Vector3(2.0, 1.4, -8.0), door + Vector3(1.1, 1.2, -6.4), 36.0],
		[_head(mk) + Vector3(0.4, 0.0, -1.2), _head(mk), 30.0, _head(mk) + Vector3(0.3, 0.0, -0.9), _head(mk), 26.0])
	c.shake(0.4)
	await _beat(c, L("V00", 7), "ПАХАН", [_head(p2) + Vector3(-0.6, 0.0, 1.4), _head(p2), 34.0, _head(p2) + Vector3(-0.4, 0.0, 1.0), _head(p2), 28.0],
		[_head(p2) + Vector3(0.7, 0.0, 1.0), _head(p2), 28.0, _head(p2) + Vector3(0.5, 0.0, 0.8), _head(p2), 24.0])
	c.plate("СПИСАНО 6 700 ГОЛДЫ", "stamp", 1.2)
	c.sfx("sfx_ui", -4.0, 0.6)
	_coins(c, 30)
	c.cam_at(_head(p2) + Vector3(0.0, 1.8, 1.8), _head(p2), 50.0)
	c.cam_to(_head(p2) + Vector3(0.0, -0.2, 0.6), _head(p2) + Vector3(0, 0.6, 0), 1.2, 36.0)         # пролёт камеры сквозь дождь монет
	await c.wait(1.2)
	c.clear_plates()
	# 8 — логотип; Пахан за кадром; джингл обрывается
	var lg := _logo(c)
	G67Sound.play(c, "hit_cut")
	c.sfx("sfx_boom", -2.0, 1.0)
	await c.say(L("V00", 8), 0.2)
	c.vhs(1.0, 0.5)
	c.sfx("sfx_crack", -4.0, 0.5)
	await c.wait(0.5)
	lg.queue_free()

## ПОДЗЕМКА для трейлера: кафель, турникет со створкой, табло, лампы дневного света
static func _metro(c: G67ClipPlayer, U: Vector3) -> void:
	c.box(Vector3(10, 0.1, 8), U + Vector3(0, -0.05, 0), Color(0.42, 0.42, 0.4))
	for i in 12:
		for j in 5:
			c.box(Vector3(0.78, 0.38, 0.06), U + Vector3(-4.6 + i * 0.82, 0.25 + j * 0.42, -1.6), Color(0.85, 0.84, 0.78) if (i + j) % 2 == 0 else Color(0.78, 0.82, 0.76))
	c.box(Vector3(10, 0.25, 0.08), U + Vector3(0, 0.12, -1.55), Color(0.18, 0.55, 0.3))
	for x in [-0.55, 0.55]:
		c.box(Vector3(0.28, 1.05, 0.9), U + Vector3(x, 0.52, 0.3), Color(0.55, 0.57, 0.6))
		c.box(Vector3(0.2, 0.06, 0.2), U + Vector3(x, 1.08, 0.55), Color(0.2, 0.9, 0.35), 2.0)
	var tab := c.box(Vector3(2.6, 0.5, 0.06), U + Vector3(0, 2.6, -1.4), Color(0.05, 0.05, 0.05))
	var l3 := Label3D.new()
	l3.text = "ВХОД ПО ТАРИФУ"
	l3.font_size = 48
	l3.pixel_size = 0.006
	l3.modulate = Color(0.95, 0.8, 0.15)
	l3.position = U + Vector3(0, 2.6, -1.36)
	c.world.add_child(l3)
	for x in [-2.5, 0.0, 2.5]:
		c.box(Vector3(1.6, 0.06, 0.14), U + Vector3(x, 3.3, 0.5), Color(0.95, 0.98, 1.0), 3.0)
	c.light(U + Vector3(0, 3.0, 1.2), Color(0.9, 0.97, 1.0), 2.2, 10.0, true)

## БОТОФЕРМА для трейлера: один стол, один компьютер, стена мониторов с одним и тем же профилем
static func _botfarm(c: G67ClipPlayer, B: Vector3) -> void:
	c.box(Vector3(12, 0.1, 10), B + Vector3(0, -0.05, 0), Color(0.1, 0.1, 0.12))
	c.box(Vector3(12, 5, 0.1), B + Vector3(0, 2.5, -2.4), Color(0.06, 0.07, 0.09))
	for row in 4:
		for col in 7:
			var at := B + Vector3(-3.3 + col * 1.1, 0.9 + row * 0.8, -2.3)
			c.box(Vector3(1.0, 0.68, 0.05), at, Color(0.15, 0.32, 0.65), 1.2)
			var av := Label3D.new()
			av.text = "@bot_001\n67 000 000"
			av.font_size = 28
			av.pixel_size = 0.004
			av.modulate = Color(0.9, 0.95, 1.0)
			av.position = at + Vector3(0, 0, 0.04)
			c.world.add_child(av)
	c.box(Vector3(1.4, 0.06, 0.7), B + Vector3(0, 0.76, -0.2), Color(0.3, 0.22, 0.15))
	c.box(Vector3(0.6, 0.4, 0.04), B + Vector3(0, 1.05, -0.4), Color(0.3, 0.55, 1.0), 1.5)
	c.box(Vector3(0.08, 0.75, 0.08), B + Vector3(-0.6, 0.38, -0.2), Color(0.15, 0.15, 0.15))
	c.box(Vector3(0.08, 0.75, 0.08), B + Vector3(0.6, 0.38, -0.2), Color(0.15, 0.15, 0.15))
	c.light(B + Vector3(0, 2.0, 1.5), Color(0.6, 0.75, 1.0), 1.4, 9.0)

## Рекламная заставка поверх кадра: фон, полоса-логотип внизу
static func _ad_card(c: G67ClipPlayer, bg: Color, acc: Color, brand: String) -> Control:
	return c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = bg
		r.size = fs
		s.add_child(r)
		for i in 14:
			var st := ColorRect.new()
			st.color = Color(acc.r, acc.g, acc.b, 0.06)
			st.size = Vector2(fs.x * 0.05, fs.y * 1.4)
			st.position = Vector2(i * fs.x * 0.08, -fs.y * 0.2)
			st.rotation = 0.35
			s.add_child(st)
		var bar := ColorRect.new()
		bar.color = acc
		bar.size = Vector2(fs.x, fs.y * 0.08)
		bar.position = Vector2(0, fs.y * 0.86)
		s.add_child(bar)
		var l := Label.new()
		l.text = brand
		l.add_theme_font_override("font", c.game.main.font)
		l.add_theme_font_size_override("font_size", int(fs.y * 0.045))
		l.add_theme_color_override("font_color", Color(0.02, 0.02, 0.02))
		l.position = Vector2(fs.x * 0.04, fs.y * 0.87)
		s.add_child(l))

static func _tariff(c: G67ClipPlayer, card: Control, text: String, small: bool) -> void:
	var fs := c.frame.size
	var n := card.get_child_count()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", c.game.main.font)
	l.add_theme_font_size_override("font_size", int(fs.y * (0.05 if small else 0.09)))
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 10)
	l.position = Vector2(fs.x * 1.1, fs.y * (0.12 + 0.2 * float(card.get_meta("rows", 0))))
	card.set_meta("rows", int(card.get_meta("rows", 0)) + 1)
	card.add_child(l)
	var tw := c.create_tween()
	tw.tween_property(l, "position:x", fs.x * 0.08, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _counter(c: G67ClipPlayer, card: Control, target: int, dur: float) -> Label:
	var fs := c.frame.size
	var l := Label.new()
	l.add_theme_font_override("font", c.game.main.font)
	l.add_theme_font_size_override("font_size", int(fs.y * 0.15))
	l.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 12)
	l.size = Vector2(fs.x, fs.y * 0.3)
	l.position = Vector2(0, fs.y * 0.25)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(fs.x * 0.5, fs.y * 0.15)
	card.add_child(l)
	var sub := Label.new()
	sub.text = "ПОДПИСЧИКОВ"
	sub.add_theme_font_override("font", c.game.main.font)
	sub.add_theme_font_size_override("font_size", int(fs.y * 0.05))
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	sub.position = Vector2(fs.x * 0.36, fs.y * 0.56)
	card.add_child(sub)
	var tw := c.create_tween()
	tw.tween_method(func(v: float): l.text = _grp(int(v)), 0.0, float(target), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return l

static func _grp(v: int) -> String:
	var s := str(v)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return out

## Отъезд: стена мониторов, на каждом — один и тот же профиль
static func _profiles(c: G67ClipPlayer, card: Control) -> void:
	var fs := c.frame.size
	var grid := Control.new()
	card.add_child(grid)
	for row in 5:
		for col in 8:
			var t := ColorRect.new()
			t.color = Color(0.1, 0.18, 0.3)
			t.size = Vector2(fs.x * 0.11, fs.y * 0.13)
			t.position = Vector2(fs.x * (0.03 + col * 0.12), fs.y * (0.04 + row * 0.16))
			grid.add_child(t)
			var av := ColorRect.new()
			av.color = Color(0.85, 0.85, 0.9)
			av.size = Vector2(t.size.y * 0.42, t.size.y * 0.42)
			av.position = t.position + Vector2(t.size.x * 0.32, t.size.y * 0.12)
			grid.add_child(av)
			var nm := ColorRect.new()
			nm.color = Color(0.5, 0.7, 1.0)
			nm.size = Vector2(t.size.x * 0.7, t.size.y * 0.1)
			nm.position = t.position + Vector2(t.size.x * 0.15, t.size.y * 0.7)
			grid.add_child(nm)
	grid.modulate.a = 0.0
	c.create_tween().tween_property(grid, "modulate:a", 1.0, 0.5)

static func _logo(c: G67ClipPlayer) -> Control:
	return c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color(0.02, 0.02, 0.03)
		r.size = fs
		s.add_child(r)
		var tex_path := "res://assets/golda67/ui/logo_golda67.png"
		if ResourceLoader.exists(tex_path):
			var tr := TextureRect.new()
			tr.texture = load(tex_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(fs.x * 0.7, fs.y * 0.5)
			tr.position = Vector2(fs.x * 0.15, fs.y * 0.2)
			s.add_child(tr)
		else:
			var l := Label.new()
			l.text = "ГОЛДА 67"
			l.add_theme_font_override("font", c.game.main.font)
			l.add_theme_font_size_override("font_size", int(fs.y * 0.2))
			l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.22))
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			l.add_theme_constant_override("outline_size", 18)
			l.size = Vector2(fs.x, fs.y * 0.4)
			l.position = Vector2(0, fs.y * 0.25)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.add_child(l)
			var sub := Label.new()
			sub.text = "ТУРНИР 67 · ПРИКВЕЛ GOD OF GRIMERKA"
			sub.add_theme_font_override("font", c.game.main.font)
			sub.add_theme_font_size_override("font_size", int(fs.y * 0.04))
			sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			sub.size = Vector2(fs.x, 40)
			sub.position = Vector2(0, fs.y * 0.62)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.add_child(sub))

# ---------------------------------------------------------------- AD01 — «СТАНЬ АВТОРИТЕТОМ»
static func ad01(c: G67ClipPlayer) -> void:
	var y := _yard(c)
	var at := Vector3(2.0, 0.03, -36.5)
	var m := c.actor("misha", "misha", at, 0.0)
	c.anim("misha", "CStand", 0.0)
	_snow(c, at + Vector3(0, 6, 4), Vector3(8, 3, 8))
	c.light(at + Vector3(0, 3.5, -3.0), Color(1.0, 0.85, 0.6), 4.0, 10.0)
	# кадр 1: снизу, контровой свет, снег навстречу
	c.cam_at(at + Vector3(0.8, 0.35, 4.2), at + Vector3(0, 1.7, 0), 48.0)
	c.cam_to(at + Vector3(0.5, 0.5, 3.4), at + Vector3(0, 1.75, 0), 4.0, 44.0)
	await c.say(L("AD01", 0), 0.2)
	# кадр 2: крупно — надевает очки; «АВТОРИТЕТ 67»; показывает на плакат
	c.cam_at(_head(m) + Vector3(0.2, 0.0, 1.5), _head(m), 32.0)
	c.anim_once("misha", "CGlasses", 1.4)
	await c.wait(1.0)
	c.plate("АВТОРИТЕТ 67", "lower", 3.5)
	c.anim("misha", "CPoint", 0.25)
	var poster := Vector3(-2.4, 1.6, -48.4)
	c.cam_to(at + Vector3(2.8, 1.6, 2.6), poster, 1.2, 46.0)
	await c.say(L("AD01", 1), 0.2)
	# кадр 3: садится на капот — цепь за зеркало, машина качается, лицо не меняется
	var car_at := Vector3(8.6, 0.03, -45.6)
	var mirror := car_at + Vector3(-0.9, 1.05, 1.05)
	m.position = car_at + Vector3(-0.2, 0.62, 1.5)
	m.rotation.y = 0.6
	c.anim("misha", "CSitHood", 0.0)
	c.cam_at(car_at + Vector3(4.6, 1.5, 3.4), car_at + Vector3(0, 1.0, 1.0), 44.0)
	await c.wait(0.6)
	c.chain(_chest(m), mirror, 3.0)
	c.sfx("sfx_parry", -4.0, 0.8)
	var car: Node3D = y.misha_car
	if car != null:
		var r0: float = car.rotation.z
		var tw := c.create_tween()
		for i in 4:
			tw.tween_property(car, "rotation:z", r0 + (0.035 if i % 2 == 0 else -0.03) * (1.0 - i * 0.2), 0.18)
		tw.tween_property(car, "rotation:z", r0, 0.2)
	c.cam_to(_head(m) + Vector3(1.2, 0.1, 1.4), _head(m), 2.6, 30.0)
	await c.say(L("AD01", 2), 0.2)
	# кадр 4: крупно, в объектив
	m.position = at
	m.rotation.y = 0.0
	c.anim("misha", "CTalk", 0.0)
	await c.wait(0.05)
	c.cam_at(_head(m) + Vector3(0.1, 0.1, 1.6), _head(m) + Vector3(0, 0.08, 0), 30.0)
	await c.say(L("AD01", 3), 0.2)
	# финальная плашка
	c.plate("ТУРНИР 67 — ПОДНИМИ СВОЙ РАЙОННЫЙ СТАТУС", "big", 2.2)
	c.sfx("sfx_boom", -3.0, 0.8)
	await c.wait(2.2)

# ---------------------------------------------------------------- CL01 — «КАК ЗАЙТИ ВО ДВОР» (9:16)
static func cl01(c: G67ClipPlayer) -> void:
	_yard(c)
	_phone_ui(c, "ОБЛАКО LIVE", "misha_minasyan_67", "12,4K")
	var gate := Vector3(2.0, 0.0, -27.0)
	var start := gate + Vector3(0, 0, 4.2)
	var m := c.actor("misha", "misha", start, PI)
	c.anim("misha", "CStand", 0.0)
	c.cam_at(start + Vector3(0.3, 1.5, -2.6), start + Vector3(0, 1.4, 0), 52.0)
	await c.say(L("CL01", 0), 0.1)
	# три шага в слоу-мо, камера облетает
	c.anim("misha", "CWalk", 0.15, 0.4)
	c.move("misha", gate + Vector3(0, 0, 0.9), 3.6)
	c.cam_at(gate + Vector3(2.1, 1.5, 2.3), start + Vector3(0, 1.4, 0), 50.0)
	c.cam_to(gate + Vector3(1.9, 1.4, 0.25), gate + Vector3(0, 1.4, 0.9), 3.6, 46.0)
	for i in 3:
		var st := c.plate("ШАГ %d" % (i + 1), "caption", 1.0)
		await c.wait(1.2)
	# четвёртый шаг — цепь за калитку: стоп-кадр на рывке
	c.chain(_chest(m), gate + Vector3(0.55, 1.1, 0.0), 3.2)
	c.anim_once("misha", "CYank", 0.5)
	c.sfx("sfx_parry", -1.0, 0.6)
	c.shake(0.6)
	await c.wait(0.35)
	if m.player != null:
		m.player.pause()
	c.vhs(0.4, 0.4)
	c.plate("СТОП-КАДР", "top", 1.0)
	await c.wait(1.2)
	if m.player != null:
		m.player.play()
	c.anim("misha", "CStuck", 0.2)
	await c.wait(0.05)
	c.cam_at(_head(m) + Vector3(1.3, 0.15, -0.5), _head(m) + Vector3(0, 0.08, 0), 40.0)
	await c.wait(0.6)
	await c.say(L("CL01", 1), 0.2)
	c.plate("SIGMA WALK: 67/100", "big", 1.8)
	c.sfx("sfx_ui", -3.0, 1.2)
	await c.wait(1.8)

## Интерфейс вертикального ролика «Облака»: сверху ник и прямой эфир, справа сердечко и счётчик
static func _phone_ui(c: G67ClipPlayer, app: String, nick: String, views: String) -> void:
	c.plate("", "small", 0.0)
	var fs := c.frame.size
	var ui := Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.size = fs
	c.over.add_child(ui)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.35)
	top.size = Vector2(fs.x, fs.y * 0.07)
	ui.add_child(top)
	var a := c._label(ui, app + "   @" + nick, int(fs.x * 0.04), Color.WHITE)
	a.position = Vector2(fs.x * 0.04, fs.y * 0.015)
	var live := c._label(ui, "LIVE", int(fs.x * 0.04), Color(1, 0.25, 0.25))
	live.position = Vector2(fs.x * 0.8, fs.y * 0.015)
	var h := c._label(ui, "ЛАЙКИ\n" + views, int(fs.x * 0.05), Color(1, 0.35, 0.45))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(fs.x * 0.84, fs.y * 0.45)

# ---------------------------------------------------------------- NEWS01 — «РАЙОННЫЙ ВЕСТНИК 67», выпуск после Миши
static func news01(c: G67ClipPlayer) -> void:
	var y := _yard(c)
	# студия — в стороне от двора
	var S := Vector3(400, 0, 400)
	c.box(Vector3(12, 0.1, 10), S + Vector3(0, -0.05, 0), Color(0.06, 0.07, 0.1))
	c.box(Vector3(12, 6, 0.2), S + Vector3(0, 3, -2.6), Color(0.09, 0.12, 0.25))
	var scr := c.box(Vector3(4.2, 2.3, 0.05), S + Vector3(1.6, 2.2, -2.45), Color(0.2, 0.35, 0.9), 0.8)
	var logo3 := Label3D.new()
	logo3.text = "РАЙОННЫЙ ВЕСТНИК 67"
	logo3.font_size = 64
	logo3.pixel_size = 0.0065
	logo3.modulate = Color(1, 0.85, 0.3)
	logo3.position = S + Vector3(1.6, 2.2, -2.4)
	c.world.add_child(logo3)
	c.prop("g67_news_desk", S + Vector3(0, 0, 0.3), 0.0, Vector3(2.6, 0.92, 1.2), "h")
	var an := c.actor("anchor", "anchor", S + Vector3(0, 0, -0.55), 0.0)
	c.anim("anchor", "NCross", 0.0)
	c.light(S + Vector3(0, 3.0, 3.0), Color(1, 0.96, 0.9), 2.2, 12.0)
	c.light(S + Vector3(-3, 2.0, 1.0), Color(0.5, 0.6, 1.0), 1.0, 8.0)
	# заставка: вращающаяся «67», три ноты
	var spin := Label3D.new()
	spin.text = "67"
	spin.font_size = 128
	spin.pixel_size = 0.03
	spin.modulate = Color(1, 0.8, 0.2)
	spin.outline_size = 24
	spin.position = S + Vector3(0, 30, 0)
	c.world.add_child(spin)
	c.cam_at(S + Vector3(0, 30, 6), S + Vector3(0, 30, 0), 50.0)
	c.create_tween().tween_property(spin, "rotation:y", TAU, 1.5)
	for i in 3:
		c.sfx("sfx_ui", -4.0, 0.8 + i * 0.25)
		await c.wait(0.45)
	await c.wait(0.2)
	# ведущий в кадре, средний план
	c.cam_at(S + Vector3(-0.5, 1.75, 3.1), S + Vector3(0.1, 1.45, -0.55), 40.0)
	c.plate("РАЙОННЫЙ ВЕСТНИК 67", "lower", 3.0)
	var d0 := c.say_async(L("NEWS01", 0))
	c.cam_to(S + Vector3(-0.2, 1.7, 2.7), S + Vector3(0.05, 1.5, -0.55), d0 * 0.34, 36.0)            # общий → наезд
	await c.wait(d0 * 0.34)
	c.vhs(0.6, 0.2)
	G67Sound.play(c, "click")
	c.cam_at(S + Vector3(-1.9, 1.55, 1.7), S + Vector3(0.05, 1.45, -0.55), 38.0)                      # перебивка: ведущий сбоку
	c.cam_to(S + Vector3(-1.5, 1.55, 1.3), S + Vector3(0.05, 1.45, -0.55), d0 * 0.3, 34.0)
	await c.wait(d0 * 0.3)
	c.vhs(0.6, 0.2)
	c.cam_at(S + Vector3(0.9, 1.5, 2.0), S + Vector3(0.0, 1.5, -0.55), 32.0)                           # крупный план с другой стороны
	c.cam_to(S + Vector3(0.4, 1.5, 1.5), S + Vector3(0.0, 1.5, -0.55), d0 * 0.36 + 0.2, 28.0)
	await c.wait(d0 * 0.36 + 0.35)
	c.clear_sub()
	c.vhs(0.9, 0.4)
	G67Sound.play(c, "click")
	# повтор боя: последний удар по Мише, замедленно
	var M := Vector3(2.0, 0.03, -38.0)
	var mi := c.actor("misha", "misha", M, 0.0)
	var pa := c.actor("pahan", "pahan", M + Vector3(0, 0, 1.6), PI)
	c.anim("pahan", "Light1", 0.0, 0.3)
	c.anim_once("misha", "Hit", 2.4)
	c.cam_at(M + Vector3(3.2, 1.6, 2.6), M + Vector3(0, 1.1, 0.7), 42.0)
	c.cam_to(M + Vector3(2.4, 1.3, 1.6), M + Vector3(0, 1.2, 0.6), 2.2)
	c.plate("ПОВТОР", "top", 2.2)
	c.mono(0.35)
	c.sfx("sfx_boom", -6.0, 0.5)
	await c.wait(2.3)
	c.mono(0.0)
	c.clear_plates()
	c.vhs(0.9, 0.4)
	# Миша на лавке поправляет цепь, не глядя в камеру
	c.actors.erase("pahan")
	pa.queue_free()
	var bench := Vector3(3.4, 0.07, 34.6)
	mi.position = bench + Vector3(0, 0.02, 0.0)
	mi.rotation.y = -PI * 0.5
	c.anim("misha", "CChainFix", 0.0)
	c.cam_at(bench + Vector3(-1.9, 1.3, 0.75), bench + Vector3(0, 0.9, 0), 38.0)
	c.cam_to(bench + Vector3(-1.6, 1.22, 0.5), bench + Vector3(0, 0.95, 0), 6.0, 34.0)
	c.plate("АВТОРИТЕТ ВРЕМЕННО НЕДОСТУПЕН. ПОПРОБУЙТЕ ПОЗЖЕ.", "ticker", 8.0)
	await c.say(L("NEWS01", 1), 0.3)
	# закрытие выпуска — снова ведущий
	c.cam_at(S + Vector3(0.4, 1.75, 3.4), S + Vector3(0.0, 1.45, -0.55), 42.0)
	await c.wait(1.6)

# ---------------------------------------------------------------- STORY01 — регистрация (9:16, камера телефона madk1d)
static func story01(c: G67ClipPlayer) -> void:
	c.set_env("room")
	# подъезд: зелёная стена, лампа — для «живой» части в конце
	var H := Vector3(0, 0, 0)
	c.box(Vector3(8, 0.1, 8), H + Vector3(0, -0.05, 0), Color(0.32, 0.31, 0.29))
	c.box(Vector3(8, 1.5, 0.1), H + Vector3(0, 0.75, -2.0), Color(0.31, 0.42, 0.34))
	c.box(Vector3(8, 1.6, 0.1), H + Vector3(0, 2.3, -2.0), Color(0.8, 0.79, 0.74))
	c.light(H + Vector3(0, 2.7, 0.5), Color(1.0, 0.85, 0.62), 2.5, 8.0, true)
	var pa := c.actor("pahan", "pahan", H + Vector3(-2.2, 0, -0.6), PI * 0.5)
	var mk := c.actor("madk1d", "madk1d", H + Vector3(0.6, 0, 1.6), PI)
	c.cam_at(H + Vector3(0.0, 1.35, 0.4), H + Vector3(-0.6, 1.25, -1.6), 58.0)
	# экран телефона: реклама турнира с QR
	var ph := c.screen(func(s: Control, fs: Vector2):
		_phone_screen(c, s, fs, "ad"))
	c.say_async(L("STORY01", 0))
	c.cam_to(H + Vector3(-0.1, 1.38, 0.1), H + Vector3(-0.8, 1.25, -1.6), _len(c, L("STORY01", 0)) + 0.2, 52.0)
	await c.wait(_len(c, L("STORY01", 0)) + 0.2)
	await c.say(L("STORY01", 1), 0.1)
	# нажимает «ЗАРЕГИСТРИРОВАТЬСЯ» → взнос
	c.sfx("sfx_ui", -4.0, 1.3)
	ph.queue_free()
	ph = c.screen(func(s: Control, fs: Vector2):
		_phone_screen(c, s, fs, "pay"))
	await c.wait(0.35)
	await c.say(L("STORY01", 2), 0.1)
	c.sfx("sfx_ui", -2.0, 1.7)
	c.sfx("sfx_ui", -2.0, 2.2)
	ph.queue_free()
	ph = c.screen(func(s: Control, fs: Vector2):
		_phone_screen(c, s, fs, "done"))
	await c.wait(0.5)
	# камера телефона: Пахан входит в кадр вплотную
	ph.queue_free()
	c.anim("pahan", "Run", 0.1, 1.2)
	c.move("pahan", H + Vector3(-0.1, 0, -0.4), 0.45)
	await c.wait(0.45)
	c.anim("pahan", "Idle", 0.2)
	pa.rotation.y = 0.0
	c.cam_at(H + Vector3(0.05, 1.45, 0.75), _head(pa) + Vector3(0, -0.05, 0), 48.0)
	c.shake(0.8)
	await c.say(L("STORY01", 3), 0.1)
	# madk1d разворачивает телефон на себя
	c.anim("madk1d", "CSelfie", 0.1)
	c.vhs(0.3, 0.25)
	c.cam_at(_head(mk) + Vector3(0.2, 0.05, -0.85), _head(mk), 52.0)
	await c.say(L("STORY01", 4), 0.4)

# ---------------------------------------------------------------- EV02 — событие «ТРЯПКИ! ТРЯПКИ!» (квартира за гаражной дверью)
## Позы сценки: Пахан спит и сидит на кровати, madk1d с ведром, замах, пустая стойка
static func ev_clips() -> Dictionary:
	var P = G67Poses
	var carry := {"rarm": {"x": -0.95}, "larm": {"x": -0.95}, "rfa": {"x": -1.0}, "lfa": {"x": -1.0}, "spine": {"x": 0.05}}
	return {
		"ESleep": P._loop(4.0, {"rarm": {"z": -0.12}, "larm": {"z": 0.12}, "head": {"x": -0.05}}, {"spine": {"x": -0.03}, "head": {"x": 0.02}}),
		"ESit": P._loop(3.0, P._mix(P.SIT, {"drop": 0.3, "spine": {"x": 0.12}, "head": {"x": 0.1}, "rarm": {"x": -0.3}, "larm": {"x": -0.3}, "rfa": {"x": -0.5}, "lfa": {"x": -0.5}}), P.BREATH),
		"ESitBed": P._loop(3.0, P._mix(P.SIT, {"drop": 0.3, "rleg": {"x": 0.12}, "lleg": {"x": 0.12}, "rup": {"x": -1.45}, "lup": {"x": -1.45}, "spine": {"x": 0.02}, "head": {"x": 0.05}, "rarm": {"x": -0.2, "z": -0.15}, "larm": {"x": -0.2, "z": 0.15}}), P.BREATH),
		"EBucket": P._loop(2.0, carry, P.BREATH),
		"ESwingR": P._seq(0.9, {}, [[0.0, {"rarm": {"x": 0.25, "z": -0.1}, "rfa": {"x": -0.2}}], [0.55, {"rarm": {"x": 0.6, "z": -0.15}, "rfa": {"x": -0.3}, "spine": {"x": 0.12}}, "out"],
			[0.8, {"rarm": {"x": -1.7, "z": -0.1}, "rfa": {"x": -0.1}, "spine": {"x": -0.2}}], [1.0, {"rarm": {"x": -1.5}, "rfa": {"x": -0.1}, "spine": {"x": -0.15}}]], false),
		"EWalkBucket": P._walk(1.5, {"rarm": {"x": 0.05, "z": -0.3}, "rfa": {"x": -0.08}, "larm": {"z": 0.12}, "spine": {"x": 0.1, "z": 0.07}, "head": {"x": 0.05}}),
		"ESwing": P._seq(0.9, carry, [[0.0, carry], [0.5, {"rarm": {"x": -1.9}, "larm": {"x": -1.9}, "rfa": {"x": -0.3}, "lfa": {"x": -0.3}, "spine": {"x": -0.3}}, "out"],
			[1.0, {"rarm": {"x": -0.5}, "larm": {"x": -0.5}, "rfa": {"x": -0.2}, "lfa": {"x": -0.2}, "spine": {"x": 0.2}}]], false),
	}

static var snap_req := ""      # проверка просит снимок в ключевой момент сцены

static func get_tree_snap_after(c: G67ClipPlayer) -> void:
	c.get_tree().create_timer(1.0).timeout.connect(func(): snap_req = "after")

static func _bone_pos(r: Rig, nm: String) -> Vector3:
	var b: int = r.skel.find_bone(nm)
	if b < 0:
		return r.global_position + Vector3(0, 0.9, 0.2)
	return r.skel.global_transform * r.skel.get_bone_global_pose(b).origin

static func _hand_pos(r: Rig) -> Vector3:
	var a: int = r.skel.find_bone("mixamorig_RightHand")
	var b: int = r.skel.find_bone("mixamorig_LeftHand")
	if a < 0 or b < 0:
		return r.global_position + Vector3(0, 1.0, 0.3)
	var pa: Vector3 = r.skel.global_transform * r.skel.get_bone_global_pose(a).origin
	var pb: Vector3 = r.skel.global_transform * r.skel.get_bone_global_pose(b).origin
	return (pa + pb) * 0.5

## Дальний голос из-за двери: строка через фильтр низких частот и тише на 10 дБ
static func _muffled(c: G67ClipPlayer, line: String) -> void:
	var path := G67Voice.path(line)
	if path == "":
		return
	var bi := AudioServer.get_bus_index("EvMuffle")
	if bi < 0:
		AudioServer.add_bus()
		bi = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "EvMuffle")
		AudioServer.set_bus_send(bi, "Voice")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 650.0
		AudioServer.add_bus_effect(bi, lp)
		AudioServer.set_bus_volume_db(bi, -10.0)
	var pl := AudioStreamPlayer.new()
	pl.stream = load(path)
	pl.bus = "EvMuffle"
	c.add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)

static func _ev_box(c: G67ClipPlayer, size: Vector3, pos: Vector3, col: Color, glow := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := c.box(size, pos, col, glow)
	if alpha < 1.0:
		var m: StandardMaterial3D = mi.material_override
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(col, alpha)
	return mi

## Комната 5,5 × 6 м без передней стены: обои в полоску, окно с ночным двором и снегом, батарея, плинтус, ковры, тумбочка с лампой
static func _ev_room(c: G67ClipPlayer) -> Dictionary:
	var wall := Color(0.62, 0.55, 0.42)
	var paint := Color(0.2, 0.36, 0.34)
	var stripe := Color(0.55, 0.47, 0.35)
	c.box(Vector3(5.5, 0.1, 6.0), Vector3(0, -0.05, 0), Color(0.34, 0.24, 0.17))
	for k in 11:                                                                 # доски пола
		c.box(Vector3(0.02, 0.005, 6.0), Vector3(-2.5 + k * 0.5, 0.002, 0), Color(0.22, 0.15, 0.1))
	# левая стена и задняя (с проёмом окна)
	c.box(Vector3(0.1, 2.8, 6.0), Vector3(-2.8, 1.4, 0), wall)
	c.box(Vector3(0.12, 1.1, 6.0), Vector3(-2.79, 0.55, 0), paint)
	c.box(Vector3(3.65, 2.8, 0.1), Vector3(-0.925, 1.4, -3.05), wall)           # x −2.75…0.9
	c.box(Vector3(0.65, 2.8, 0.1), Vector3(2.425, 1.4, -3.05), wall)            # x 2.1…2.75
	c.box(Vector3(1.2, 1.0, 0.1), Vector3(1.5, 0.5, -3.05), wall)
	c.box(Vector3(1.2, 0.5, 0.1), Vector3(1.5, 2.55, -3.05), wall)
	c.box(Vector3(5.5, 1.1, 0.12), Vector3(0, 0.55, -3.04), paint)
	# правая стена: два куска и притолока над дверью (проём z 1.05…1.95)
	c.box(Vector3(0.1, 2.8, 4.05), Vector3(2.8, 1.4, -0.975), wall)
	c.box(Vector3(0.1, 2.8, 1.05), Vector3(2.8, 1.4, 2.475), wall)
	c.box(Vector3(0.1, 0.8, 0.9), Vector3(2.8, 2.4, 1.5), wall)
	c.box(Vector3(0.12, 1.1, 4.05), Vector3(2.79, 0.55, -0.975), paint)
	c.box(Vector3(0.12, 1.1, 1.05), Vector3(2.79, 0.55, 2.475), paint)
	c.box(Vector3(1.0, 2.8, 0.1), Vector3(3.3, 1.4, 1.5), Color(0.04, 0.04, 0.05))   # тёмный коридор за дверью
	c.box(Vector3(1.0, 0.1, 1.2), Vector3(3.3, -0.05, 1.5), Color(0.08, 0.07, 0.07))
	for k in 12:                                                                 # полоска обоев
		var z := -2.6 + k * 0.5
		c.box(Vector3(0.02, 1.6, 0.08), Vector3(-2.74, 1.9, z), stripe)
		if z > -2.4 and z < 2.4:
			c.box(Vector3(0.02, 1.6, 0.08), Vector3(2.74, 1.9, z), stripe) if (z < 0.9 or z > 2.1) else null
		var x := -2.6 + k * 0.5
		if x < 0.8 or x > 2.2:
			c.box(Vector3(0.08, 1.6, 0.02), Vector3(x, 1.9, -2.99), stripe)
	c.box(Vector3(0.03, 0.04, 6.0), Vector3(-2.73, 1.1, 0), Color(0.82, 0.78, 0.68))   # молдинг между краской и обоями
	c.box(Vector3(5.5, 0.04, 0.03), Vector3(0, 1.1, -2.98), Color(0.82, 0.78, 0.68))
	c.box(Vector3(0.05, 0.12, 6.0), Vector3(-2.72, 0.06, 0), Color(0.85, 0.82, 0.74))  # плинтус
	c.box(Vector3(5.5, 0.12, 0.05), Vector3(0, 0.06, -2.97), Color(0.85, 0.82, 0.74))
	# окно: рама, стекло, ночной двор, дом напротив, снег
	var fr := Color(0.9, 0.88, 0.82)
	c.box(Vector3(1.3, 0.07, 0.14), Vector3(1.5, 2.33, -3.0), fr)
	c.box(Vector3(1.3, 0.07, 0.14), Vector3(1.5, 0.98, -3.0), fr)
	c.box(Vector3(0.07, 1.4, 0.14), Vector3(0.88, 1.65, -3.0), fr)
	c.box(Vector3(0.07, 1.4, 0.14), Vector3(2.12, 1.65, -3.0), fr)
	c.box(Vector3(0.05, 1.3, 0.1), Vector3(1.5, 1.65, -3.0), fr)
	c.box(Vector3(1.5, 0.06, 0.3), Vector3(1.5, 0.95, -2.9), fr)                 # подоконник
	_ev_box(c, Vector3(1.2, 1.3, 0.02), Vector3(1.5, 1.65, -3.0), Color(0.5, 0.6, 0.8), 0.0, 0.12)
	c.box(Vector3(3.0, 2.0, 0.05), Vector3(1.5, 1.8, -4.2), Color(0.05, 0.08, 0.22), 0.5)
	c.box(Vector3(3.0, 1.0, 0.05), Vector3(1.5, 1.0, -4.15), Color(0.1, 0.16, 0.34), 0.5)
	c.box(Vector3(2.2, 1.6, 0.2), Vector3(1.3, 1.2, -4.0), Color(0.07, 0.07, 0.1))   # дом напротив
	for wx in [0.7, 1.3, 1.9]:
		for wy in [0.8, 1.3, 1.7]:
			if int(wx * 10 + wy * 10) % 3 != 0:
				c.box(Vector3(0.22, 0.28, 0.02), Vector3(wx, wy, -3.88), Color(1.0, 0.8, 0.35), 2.0)
	var snow := GPUParticles3D.new()
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0.1, -1, 0)
	spm.spread = 10.0
	spm.initial_velocity_min = 0.3
	spm.initial_velocity_max = 0.6
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spm.emission_box_extents = Vector3(0.7, 0.05, 0.4)
	snow.process_material = spm
	var sm0 := SphereMesh.new()
	sm0.radius = 0.02
	sm0.height = 0.04
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color.WHITE
	smat.emission_enabled = true
	smat.emission = Color.WHITE
	sm0.material = smat
	snow.draw_pass_1 = sm0
	snow.amount = 60
	snow.lifetime = 3.0
	snow.position = Vector3(1.5, 2.4, -3.3)
	c.world.add_child(snow)
	# батарея под окном, шторы
	c.box(Vector3(1.0, 0.55, 0.1), Vector3(1.5, 0.45, -2.9), Color(0.85, 0.85, 0.8))
	for k in 6:
		c.box(Vector3(0.02, 0.5, 0.12), Vector3(1.1 + k * 0.16, 0.45, -2.88), Color(0.6, 0.6, 0.58))
	c.box(Vector3(0.3, 1.6, 0.08), Vector3(0.7, 1.7, -2.93), Color(0.45, 0.1, 0.12))
	c.box(Vector3(0.3, 1.6, 0.08), Vector3(2.3, 1.7, -2.93), Color(0.45, 0.1, 0.12))
	# ковёр на стене, календарь, ковёр на полу
	c.box(Vector3(0.05, 1.6, 1.3), Vector3(-2.73, 1.7, -1.1), Color(0.55, 0.12, 0.1))
	c.box(Vector3(0.06, 1.35, 1.05), Vector3(-2.72, 1.7, -1.1), Color(0.78, 0.55, 0.28))
	c.box(Vector3(0.07, 1.0, 0.7), Vector3(-2.71, 1.7, -1.1), Color(0.5, 0.14, 0.1))
	c.box(Vector3(0.03, 0.4, 0.3), Vector3(-2.2, 1.7, -2.95), Color(0.92, 0.9, 0.82))
	c.box(Vector3(0.03, 0.12, 0.3), Vector3(-2.2, 1.9, -2.94), Color(0.7, 0.12, 0.1))
	c.box(Vector3(3.2, 0.02, 2.2), Vector3(0, 0.012, 0.3), Color(0.45, 0.14, 0.1))
	c.box(Vector3(2.9, 0.025, 1.9), Vector3(0, 0.014, 0.3), Color(0.62, 0.38, 0.2))
	c.box(Vector3(2.5, 0.03, 1.5), Vector3(0, 0.016, 0.3), Color(0.5, 0.16, 0.12))
	# тумбочка с лампой у изголовья
	c.box(Vector3(0.5, 0.6, 0.45), Vector3(-1.5, 0.3, -2.0), Color(0.32, 0.21, 0.13))
	c.box(Vector3(0.2, 0.03, 0.2), Vector3(-1.5, 0.62, -2.0), Color(0.9, 0.9, 0.85))
	c.box(Vector3(0.05, 0.22, 0.05), Vector3(-1.5, 0.74, -2.0), Color(0.7, 0.6, 0.3))
	var shade := c.box(Vector3(0.24, 0.18, 0.24), Vector3(-1.5, 0.95, -2.0), Color(1.0, 0.85, 0.5), 2.2)
	var lamp := c.light(Vector3(-1.5, 1.0, -1.9), Color(1.0, 0.8, 0.5), 1.4, 5.0)
	c.light(Vector3(0.3, 2.7, 0.6), Color(0.9, 0.85, 0.75), 0.5, 8.0, true)
	# дверь: петля у косяка, открывается внутрь на 90° (до приезда madk1d)
	var door := Node3D.new()
	door.position = Vector3(2.72, 0, 1.05)
	c.world.add_child(door)
	var dm := c.box(Vector3(0.05, 2.0, 0.9), Vector3.ZERO, Color(0.42, 0.28, 0.18))
	dm.get_parent().remove_child(dm)
	door.add_child(dm)
	dm.position = Vector3(0, 1.0, 0.45)
	var kn := c.box(Vector3(0.1, 0.06, 0.06), Vector3.ZERO, Color(0.85, 0.75, 0.3))
	kn.get_parent().remove_child(kn)
	door.add_child(kn)
	kn.position = Vector3(-0.05, 1.0, 0.8)
	return {"door": door, "lamp": lamp, "shade": shade, "snow": snow}

static func ev02(c: G67ClipPlayer) -> void:
	var L := G67Voice.EVENT_RAGS
	c.set_env("room")
	c.filters(0.12, 0.05)
	var rm := _ev_room(c)
	var door: Node3D = rm["door"]
	var lamp: OmniLight3D = rm["lamp"]
	var shade: MeshInstance3D = rm["shade"]
	var bed := c.prop("g67_event_bed", Vector3(0, 0, -1.0), PI * 0.5, Vector3(1.0, 0.7, 2.0), "d")
	c.prop("g67_event_rags", Vector3(-2.3, 0, -2.55), 0.5, Vector3(0.7, 0.9, 0.7), "h")
	var siren := c.prop("g67_event_siren", Vector3(-0.5, 2.15, -2.9), 0.0, Vector3(0.5, 0.5, 0.5), "h")
	var bucket := c.prop("g67_event_bucket", Vector3(3.0, 1.0, 1.5), 0.0, Vector3(0.35, 0.35, 0.35), "h")
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.1, 0.08)
	sl.omni_range = 8.0
	sl.light_energy = 0.0
	sl.position = Vector3(0, 2.1, -2.2)
	c.world.add_child(sl)
	var sl2 := OmniLight3D.new()
	sl2.light_color = Color(1.0, 0.1, 0.08)
	sl2.omni_range = 6.0
	sl2.light_energy = 0.0
	sl2.position = Vector3(0, 2.3, 0.8)
	c.world.add_child(sl2)
	# ---- актёры
	var pa := c.actor("pahan", "pahan", Vector3(0.88, 0.62, -1.0), 0.0)
	pa.rotation = Vector3(-PI * 0.5, PI * 0.5, 0.0)
	c.anim("pahan", "ESleep", 0.0)
	var mk := c.actor("wh", "whyousolonely", Vector3(3.4, 0, 1.5), -PI * 0.5)
	c.anim("wh", "EWalkBucket", 0.0, 0.7)
	var st := {"carry": true, "tilt": 0.0, "mode": "hang", "force": false, "swa": 0.1}
	var carry_tw := c.create_tween().set_loops()
	carry_tw.tween_callback(func():
		if bool(st["carry"]) and is_instance_valid(mk):
			var fw := Vector3(sin(mk.rotation.y), 0, cos(mk.rotation.y))
			if String(st["mode"]) == "hang":
				# несёт за дужку правой рукой: ведро висит под кистью, покачивается маятником в такт шагу
				var sw := 0.1 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.0065)
				if bool(st["force"]):
					sw = float(st["swa"])                                  # мах: ведро на дужке из руки
				bucket.global_position = _bone_pos(mk, "mixamorig_RightHand") + fw * sin(sw) * 0.27 + Vector3(0, -cos(sw) * 0.27, 0)
				bucket.rotation = Vector3(0, mk.rotation.y, 0)
				bucket.rotate_object_local(Vector3.RIGHT, sw + float(st["tilt"]))
			else:
				# двумя руками: левая под дно, ведро между кистями перед грудью
				bucket.global_position = (_bone_pos(mk, "mixamorig_RightHand") + _bone_pos(mk, "mixamorig_LeftHand")) * 0.5 + fw * 0.1 + Vector3(0, 0.02, 0)
				bucket.rotation = Vector3(0, mk.rotation.y, 0)
				bucket.rotate_object_local(Vector3.RIGHT, float(st["tilt"])))
	carry_tw.tween_interval(0.016)
	var breath := c.create_tween().set_loops()
	breath.tween_property(pa, "scale", Vector3(1.0, 1.0, 1.07), 1.5)
	breath.tween_property(pa, "scale", Vector3.ONE, 1.5)
	# ---- план 1 (0–6 с): сверху на спящего, медленный наезд
	c.cam_at(Vector3(0.3, 3.2, 0.6), Vector3(0, 0.6, -1.0), 50.0)
	c.cam_to(Vector3(0.2, 2.1, 0.0), Vector3(0, 0.6, -1.0), 6.0, 44.0)
	c.sfx("sfx_ui", -20.0, 0.4)
	await c.wait(3.0)
	c.sfx("sfx_ui", -20.0, 0.38)
	await c.wait(3.0)
	# ---- план 2 (6–9 с): дверь открывается внутрь, WHYOUSOLONELY входит
	c.cam_at(Vector3(-0.8, 1.7, 2.9), Vector3(2.4, 1.0, 1.4), 58.0)
	c.sfx("sfx_ui", -6.0, 0.6)
	c.create_tween().tween_property(door, "rotation:y", PI * 0.5, 0.8)
	await c.wait(0.9)
	c.anim("wh", "EWalkBucket", 0.1, 0.75)
	c.move("wh", Vector3(1.6, 0, 1.5), 1.6)
	await c.wait(1.6)
	mk.rotation.y = atan2(-0.9, -1.4)
	c.move("wh", Vector3(0.7, 0, 0.5), 1.4)
	await c.wait(1.4)
	c.anim("wh", "Idle", 0.2)
	mk.rotation.y = PI
	# ---- планы 3–4 (9–13 с): сирена, красные вспышки, лицо спящего, WHYOUSOLONELY оглядывается
	var sir := c.create_tween().set_loops()
	sir.tween_property(sl, "light_energy", 7.0, 0.25)
	sir.tween_property(sl, "light_energy", 0.2, 0.25)
	var sir2 := c.create_tween().set_loops()
	sir2.tween_property(sl2, "light_energy", 4.0, 0.25).set_delay(0.12)
	sir2.tween_property(sl2, "light_energy", 0.0, 0.25)
	var spin := c.create_tween().set_loops()
	spin.tween_property(siren, "rotation:y", TAU, 1.2).as_relative()
	var lamp_tw := c.create_tween().set_loops()
	lamp_tw.tween_property(lamp, "light_energy", 0.1, 0.3)
	lamp_tw.tween_property(lamp, "light_energy", 1.2, 0.2)
	c.cam_at(Vector3(-0.1, 1.6, -0.3), Vector3(-0.5, 0.65, -1.0), 34.0)
	for k in 6:
		G67Sound.play(c, "siren", Vector3.INF, 1.0 if k % 2 == 0 else 0.8)
		c.flash(Color(1.0, 0.1, 0.1, 0.22), 0.3)
		await c.wait(0.5)
	c.cam_at(Vector3(-1.7, 1.7, 2.0), Vector3(0.7, 1.0, 0.3), 56.0)
	mk.rotation.y = 2.4
	for k in 2:
		G67Sound.play(c, "siren", Vector3.INF, 1.0 if k % 2 == 0 else 0.8)
		c.flash(Color(1.0, 0.1, 0.1, 0.22), 0.3)
		await c.wait(0.5)
	mk.rotation.y = PI
	await c.wait(0.3)
	# ---- план 5 (13–15 с): замах, вода, всплеск
	c.cam_at(Vector3(2.6, 1.7, 2.3), Vector3(0.1, 0.9, -0.5), 56.0)
	# мах одной рукой: правая с ведром на дужке уходит назад, затем выбрасывается вперёд-вверх, ведро переворачивается горлом к Пахану
	st["force"] = true
	st["swa"] = 0.1
	c.anim("wh", "ESwingR", 0.1)
	var back := c.create_tween()
	back.tween_method(func(v: float): st["swa"] = v, 0.1, -0.9, 0.5)
	await c.wait(0.5)
	G67Clips.snap_req = "hold"
	await c.wait(0.12)
	var fwd := c.create_tween()
	fwd.tween_method(func(v: float): st["swa"] = v, -0.9, 2.0, 0.28)
	await c.wait(0.28)
	var from_p: Vector3 = bucket.global_position + bucket.global_transform.basis.y.normalized() * 0.17
	var to_p := Vector3(-0.1, 0.8, -1.0)
	var wp := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = (to_p - from_p).normalized() + Vector3(0, 0.25, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -9.0, 0)
	wp.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.75, 0.9, 1.0, 0.95)
	wm.emission_enabled = true
	wm.emission = Color(0.65, 0.85, 1.0)
	wm.emission_energy_multiplier = 1.4
	sm.material = wm
	wp.draw_pass_1 = sm
	wp.amount = 70
	wp.lifetime = 0.7
	wp.one_shot = true
	wp.explosiveness = 0.85
	wp.position = from_p
	c.world.add_child(wp)
	wp.emitting = true
	G67Sound.play(c, "water")
	G67Sound.play(c, "bucket")
	c.shake(0.7)
	# струя лентой: крупные вытянутые капли по параболе от горла ведра до груди Пахана (≥ 0,6 с на каждую)
	var drops: Array = []
	var dm := CapsuleMesh.new()
	dm.radius = 0.04
	dm.height = 0.22
	dm.material = wm
	for di in 16:
		var dr := MeshInstance3D.new()
		dr.mesh = dm
		dr.visible = false
		c.world.add_child(dr)
		drops.append(dr)
	var chest := Vector3(-0.3, 0.85, -1.0)
	var rib := c.create_tween()
	rib.tween_method(func(t: float):
		for di in drops.size():
			var k: float = (t - float(di) * 0.045) / 0.75
			var dr: MeshInstance3D = drops[di]
			if k <= 0.0 or k >= 1.0:
				dr.visible = false
				continue
			var p0 := from_p.lerp(chest, k) + Vector3(0, sin(PI * k) * 0.45, 0)
			var p1 := from_p.lerp(chest, k + 0.03) + Vector3(0, sin(PI * (k + 0.03)) * 0.45, 0)
			dr.visible = true
			dr.global_position = p0
			if p1.distance_to(p0) > 0.001:
				dr.look_at(p1, Vector3.UP)
				dr.rotate_object_local(Vector3.RIGHT, PI * 0.5), 0.0, 1.6, 1.6)
	rib.tween_callback(func():
		for dr in drops:
			dr.queue_free())
	await c.wait(0.3)
	G67Clips.snap_req = "water"
	await c.wait(0.6)
	var sp2 := GPUParticles3D.new()
	var pm2 := ParticleProcessMaterial.new()
	pm2.direction = Vector3(0, 1, 0)
	pm2.spread = 55.0
	pm2.initial_velocity_min = 1.5
	pm2.initial_velocity_max = 3.0
	pm2.gravity = Vector3(0, -9.0, 0)
	sp2.process_material = pm2
	sp2.draw_pass_1 = sm
	sp2.amount = 45
	sp2.lifetime = 0.7
	sp2.one_shot = true
	sp2.explosiveness = 0.9
	sp2.position = Vector3(-0.3, 0.75, -1.0)
	c.world.add_child(sp2)
	sp2.emitting = true
	_ev_box(c, Vector3(0.9, 0.012, 0.65), Vector3(-0.2, 0.6, -1.0), Color(0.12, 0.16, 0.26), 0.0, 0.85)      # мокрое пятно на одеяле
	_ev_box(c, Vector3(1.5, 0.012, 1.0), Vector3(0.0, 0.016, 0.1), Color(0.12, 0.18, 0.3), 0.3, 0.75)         # блестящая лужа у кровати
	# Пахан резко садится: корпус вертикально, ноги вдоль кровати
	breath.kill()
	pa.scale = Vector3.ONE
	pa.rotation = Vector3(0, 0.0, 0)
	pa.position = Vector3(-0.3, 0.52, -1.3)
	c.anim("pahan", "ESitBed", 0.05)
	# ведро пустое и снова в правой руке; бросит его на реплике «ТРЯПКИ!»
	var lower := c.create_tween()
	lower.tween_method(func(v: float): st["swa"] = v, 2.0, 0.1, 0.5)
	lower.tween_callback(func(): st["force"] = false)
	await c.wait(0.8)
	G67Clips.snap_req = "after"
	await c.wait(0.3)
	c.shake(0.8)
	# ---- план 6: Пахан в упор спереди — реплика 0
	c.cam_at(Vector3(-0.3, 1.5, 0.5), Vector3(-0.3, 1.25, -1.3), 38.0)
	c.anim("wh", "Run", 0.1, 1.2)
	await c.say(L[0], 0.1)
	# ---- 16–25 с: WHYOUSOLONELY бегает вокруг кровати, Пахан провожает взглядом
	var lap := {"prints": 0}
	var runtw := c.create_tween()
	runtw.tween_method(func(a: float):
		if not is_instance_valid(mk):
			return
		var np := Vector3(cos(a) * 2.35, 0.0, -1.0 + sin(a) * 1.75)
		var dv := np - mk.position
		if dv.length() > 0.001:
			mk.rotation.y = atan2(dv.x, dv.z)
		mk.position = np
		if int(a / 0.5) != int(lap["prints"]) and int(lap["prints"]) < 50:
			lap["prints"] = int(a / 0.5)
			_ev_box(c, Vector3(0.22, 0.01, 0.12), Vector3(np.x, 0.04, np.z), Color(0.1, 0.14, 0.24), 0.2, 0.8)
		var tv: Vector3 = np - pa.position
		pa.rotation.y = lerp_angle(pa.rotation.y, atan2(tv.x, tv.z), 0.1), -0.5, TAU * 2.3, 8.5)
	c.cam_at(Vector3(-2.0, 3.5, 3.0), Vector3(0, 0.5, -1.0), 56.0)
	c.cam_to(Vector3(-1.0, 3.2, 3.1), Vector3(0, 0.5, -1.0), 2.4, 56.0)
	# бросок ведра: по дуге из руки на пол, катится и остаётся у стены в кадре
	st["carry"] = false
	var b0: Vector3 = bucket.global_position
	var bthrow := c.create_tween()
	bthrow.tween_method(func(k: float):
		bucket.global_position = b0.lerp(Vector3(-2.35, 0.17, 2.0), k) + Vector3(0, sin(PI * k) * 1.0, 0)
		bucket.rotation.z = k * 4.5, 0.0, 1.0, 0.8)
	bthrow.tween_property(bucket, "global_position", Vector3(-2.55, 0.17, 1.2), 0.6)
	bthrow.parallel().tween_property(bucket, "rotation:z", 6.6 + 1.5, 0.6)
	await c.say(L[1], 0.1)
	c.cam_at(Vector3(0.9, 1.5, 0.4), Vector3(-0.3, 1.25, -1.3), 42.0)
	await c.say(L[2], 0.1)
	var follow := c.create_tween().set_loops()
	follow.tween_callback(func():
		if is_instance_valid(mk):
			c.cam.global_position = Vector3(0.0, 1.9, 2.9)           # неподвижная камера у открытой стены: он бежит по кругу, лицо видно на передней дуге
			c.cam.look_at(mk.global_position + Vector3(0, 1.2, 0), Vector3.UP)
			c.cam.fov = 62.0)
	follow.tween_interval(0.016)
	await c.say(L[3], 0.2)
	follow.kill()
	runtw.kill()
	# ---- WHYOUSOLONELY вылетает в дверь, Пахан встаёт с кровати
	mk.rotation.y = atan2(1.6 - mk.position.x, 1.5 - mk.position.z)
	c.move("wh", Vector3(1.8, 0, 1.5), 0.9)
	c.cam_at(Vector3(-1.4, 1.7, 2.4), Vector3(0.3, 1.0, -0.2), 56.0)
	await c.wait(0.9)
	mk.rotation.y = PI * 0.5
	c.move("wh", Vector3(3.5, 0, 1.5), 0.6)
	await c.wait(0.6)
	mk.visible = false
	_muffled(c, L[1])
	c.anim("pahan", "Idle", 0.2)
	pa.rotation.y = 0.0
	pa.position = Vector3(-0.3, 0.0, 0.15)
	await c.wait(0.8)
	await c.say(L[4], 0.3)
	# ---- Пахан идёт к двери и выходит
	pa.rotation.y = atan2(1.6, 1.35)
	c.anim("pahan", "Run", 0.15, 0.55)
	c.move("pahan", Vector3(1.3, 0, 1.5), 1.6)
	await c.wait(1.6)
	pa.rotation.y = PI * 0.5
	c.move("pahan", Vector3(3.5, 0, 1.5), 1.5)
	await c.wait(1.4)
	pa.visible = false
	# ---- финал: статичный общий план пустой комнаты, крики за дверью, затемнение
	c.cam_at(Vector3(0.3, 1.9, 3.1), Vector3(0, 1.0, -1.4), 60.0)
	await c.wait(3.8)
	var blk := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 1)
		r.size = fs
		r.modulate.a = 0.0
		s.add_child(r)
		s.create_tween().tween_property(r, "modulate:a", 1.0, 1.2))
	await c.wait(1.4)
	carry_tw.kill()
	sir.kill()
	sir2.kill()
	spin.kill()
	lamp_tw.kill()
	var bi := AudioServer.get_bus_index("EvMuffle")
	if bi >= 0:
		AudioServer.remove_bus(bi)

static func _len(c: G67ClipPlayer, line: String) -> float:
	var pth := G67Voice.path(line)
	if pth != "":
		return (load(pth) as AudioStream).get_length()
	return clampf(0.6 + line.length() * 0.062, 1.2, 6.0)

## Экран телефона madk1d: реклама с QR, оплата, готово
static func _phone_screen(c: G67ClipPlayer, s: Control, fs: Vector2, kind: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.03) if kind != "done" else Color(0.03, 0.12, 0.06)
	bg.size = fs
	s.add_child(bg)
	var t := func(text: String, y: float, size: float, col: Color):
		# кегль уменьшается, пока самое длинное слово не влезет в экран телефона; текст по центру, с переносом
		var px := int(fs.x * size)
		var fnt: Font = c.game.main.font
		var wide := 0.0
		while true:
			wide = 0.0
			for w in text.replace("\n", " ").split(" "):
				wide = maxf(wide, fnt.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
			if wide <= fs.x * 0.8 or px <= 12:
				break
			px -= 2
		var l := c._label(s, text, px, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(fs.x * 0.84, 0)
		l.position = Vector2(fs.x * 0.08, fs.y * y)
	match kind:
		"ad":
			t.call("ТУРНИР 67", 0.08, 0.12, Color(1.0, 0.8, 0.2))
			t.call("ПРИЗОВОЙ ФОНД\n67 000 ГОЛДЫ", 0.2, 0.07, Color.WHITE)
			var rng := RandomNumberGenerator.new()
			rng.seed = 67
			var q := fs.x * 0.5
			var cell := q / 21.0
			var ox := (fs.x - q) * 0.5
			var oy := fs.y * 0.33
			var wbg := ColorRect.new()
			wbg.color = Color.WHITE
			wbg.size = Vector2(q + cell * 2, q + cell * 2)
			wbg.position = Vector2(ox - cell, oy - cell)
			s.add_child(wbg)
			for i in 21:
				for j in 21:
					var corner := (i < 7 and j < 7) or (i > 13 and j < 7) or (i < 7 and j > 13)
					var on := rng.randf() < 0.5
					if corner:
						var a := i % 14 if i > 13 else i
						var b := j % 14 if j > 13 else j
						on = a == 0 or a == 6 or b == 0 or b == 6 or (a >= 2 and a <= 4 and b >= 2 and b <= 4)
					if on:
						var px := ColorRect.new()
						px.color = Color.BLACK
						px.size = Vector2(cell, cell)
						px.position = Vector2(ox + i * cell, oy + j * cell)
						s.add_child(px)
			var btn := ColorRect.new()
			btn.color = Color(1.0, 0.8, 0.2)
			btn.size = Vector2(fs.x * 0.8, fs.y * 0.07)
			btn.position = Vector2(fs.x * 0.1, fs.y * 0.645)
			s.add_child(btn)
			t.call("ЗАРЕГИСТРИРОВАТЬСЯ", 0.66, 0.06, Color(0.05, 0.05, 0.05))
		"pay":
			t.call("ВЗНОС: 6 700 ГОЛДЫ", 0.28, 0.08, Color.WHITE)
			t.call("ОПЛАТИТЬ?", 0.4, 0.09, Color(1.0, 0.8, 0.2))
			var btn := ColorRect.new()
			btn.color = Color(0.2, 0.8, 0.35)
			btn.size = Vector2(fs.x * 0.6, fs.y * 0.08)
			btn.position = Vector2(fs.x * 0.2, fs.y * 0.6)
			s.add_child(btn)
			t.call("ОПЛАТИТЬ", 0.615, 0.065, Color(0.02, 0.1, 0.03))
		"done":
			t.call("ГОТОВО", 0.24, 0.13, Color(0.3, 1.0, 0.5))
			t.call("УЧАСТНИК ЗАРЕГИСТРИРОВАН:\nПАХАН", 0.48, 0.07, Color.WHITE)

# ---------------------------------------------------------------- STORY05 — первое обращение WHYOUSOLONELY (только экран)
static func story05(c: G67ClipPlayer) -> void:
	c.set_env("black")
	c.filters(0.28, 0.08)
	var sc := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color(0.02, 0.02, 0.03)
		r.size = fs
		s.add_child(r)
		var l := c._label(s, "ТУРНИР 67", int(fs.y * 0.2), Color(1.0, 0.8, 0.22))
		l.size = Vector2(fs.x, fs.y * 0.4)
		l.position = Vector2(0, fs.y * 0.22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 20)
		var sub := c._label(s, "· ПРЯМАЯ ТРАНСЛЯЦИЯ ОРГАНИЗАТОРА ·", int(fs.y * 0.035), Color(0.7, 0.7, 0.75))
		sub.size = Vector2(fs.x, 40)
		sub.position = Vector2(0, fs.y * 0.6)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
	c.vhs(0.6, 0.6)
	await c.say(L("STORY05", 0), 0.3)
	sc.queue_free()
	c.vhs(0.8, 0.3)
	sc = c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color(0.06, 0.02, 0.02)
		r.size = fs
		s.add_child(r)
		var head := c._label(s, "УЧАСТНИК: ПАХАН", int(fs.y * 0.06), Color.WHITE)
		head.position = Vector2(fs.x * 0.08, fs.y * 0.14)
		var box := ColorRect.new()
		box.color = Color(0.75, 0.08, 0.08)
		box.size = Vector2(fs.x * 0.84, fs.y * 0.16)
		box.position = Vector2(fs.x * 0.08, fs.y * 0.34)
		s.add_child(box)
		var l := c._label(s, "ОТМЕНА РЕГИСТРАЦИИ НЕДОСТУПНА", int(fs.y * 0.06), Color.WHITE)
		l.size = box.size
		l.position = box.position + Vector2(0, fs.y * 0.04)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
	await c.wait(0.4)
	c.say_async(L("STORY05", 1))
	await c.wait(1.4)
	c.plate("Выбор уже подтверждён.", "small", 0.0)
	await c.wait(maxf(0.6, _len(c, L("STORY05", 1)) - 1.0))
	c.clear_sub()
	await c.wait(0.6)
	c.vhs(1.0, 0.4)
	await c.wait(0.4)

# ---------------------------------------------------------------- EXTRA01 — «КРОТ НА ПОДКАСТЕ» (9:16)
static func _mic(c: G67ClipPlayer, pos: Vector3, lean: float) -> MeshInstance3D:
	c.box(Vector3(0.03, 0.34, 0.03), pos + Vector3(0, -0.2, 0.0), Color(0.1, 0.1, 0.1))
	var mic := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.05
	cm.height = 0.2
	mic.mesh = cm
	mic.position = pos
	mic.rotation.x = lean
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.15, 0.17)
	mm.metallic = 0.6
	mic.material_override = mm
	c.world.add_child(mic)
	return mic

static func extra01(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	var R := Vector3(0, 0, 0)
	c.box(Vector3(6, 0.1, 6), R + Vector3(0, -0.05, 0), Color(0.12, 0.1, 0.09))
	c.box(Vector3(6, 3.4, 0.12), R + Vector3(0, 1.7, -1.6), Color(0.1, 0.1, 0.12))
	for i in 6:
		for j in 3:
			c.box(Vector3(0.5, 0.5, 0.08), R + Vector3(-1.4 + i * 0.56, 0.9 + j * 0.56, -1.52), Color(0.16, 0.15, 0.18) if (i + j) % 2 == 0 else Color(0.2, 0.12, 0.12))
	# светящаяся вывеска подкаста, лампа записи (красная), стол, кружка
	var logo := Label3D.new()
	logo.text = "ОБЛАКО LIVE"
	logo.font_size = 72
	logo.pixel_size = 0.006
	logo.modulate = Color(1.0, 0.85, 0.5)
	logo.outline_size = 12
	logo.position = R + Vector3(0, 2.3, -1.45)
	c.world.add_child(logo)
	var lamp := c.box(Vector3(0.28, 0.28, 0.06), R + Vector3(1.6, 2.3, -1.5), Color(0.15, 0.02, 0.02), 0.0)
	var lamp_l := c.light(R + Vector3(1.6, 2.3, -1.2), Color(1.0, 0.1, 0.1), 0.0, 3.0)
	c.box(Vector3(1.6, 0.06, 0.9), R + Vector3(0, 0.78, 0.45), Color(0.35, 0.24, 0.15))
	for sx in [-0.7, 0.7]:
		c.box(Vector3(0.08, 0.75, 0.08), R + Vector3(sx, 0.38, 0.45), Color(0.2, 0.2, 0.2))
	var mug := MeshInstance3D.new()
	var mgm := CylinderMesh.new()
	mgm.top_radius = 0.05
	mgm.bottom_radius = 0.045
	mgm.height = 0.1
	mug.mesh = mgm
	mug.position = R + Vector3(-0.55, 0.86, 0.6)
	var mgmat := StandardMaterial3D.new()
	mgmat.albedo_color = Color(0.85, 0.85, 0.8)
	mug.material_override = mgmat
	c.world.add_child(mug)
	var mic_k := _mic(c, R + Vector3(0.45, 1.0, 0.1), 0.3)         # микрофон КРОТА: стоит далеко, он его придвинет
	var mic_h := _mic(c, R + Vector3(-0.2, 1.0, 0.85), -0.3)
	c.light(R + Vector3(1.4, 2.2, 1.8), Color(1.0, 0.85, 0.65), 2.2, 7.0, true)             # тёплый боковой
	c.light(R + Vector3(-1.2, 2.4, -0.9), Color(0.55, 0.7, 1.0), 1.4, 6.0)                    # холодный контровой
	c.box(Vector3(0.5, 0.5, 0.5), R + Vector3(0, 0.25, -0.32), Color(0.14, 0.12, 0.11))      # стул КРОТА
	var k := c.actor("krot", "krot", R + Vector3(0, 0.24, -0.25), 0.0)
	c.anim("krot", "CPod", 0.0)
	var hst := c.actor("host", "anchor", R + Vector3(0, 0.0, 1.05), PI)
	c.anim("host", "NCross", 0.0)
	var hh := MeshInstance3D.new()                                                            # наушники ведущего
	var ht := TorusMesh.new()
	ht.inner_radius = 0.13
	ht.outer_radius = 0.16
	hh.mesh = ht
	hh.material_override = mgmat
	hh.position = _head(hst) + Vector3(0, 0.05, 0)
	c.world.add_child(hh)
	var hum := AudioStreamPlayer.new()
	hum.stream = G67Sound.stream("loop_studio")
	hum.volume_db = float(G67Sound.KINDS["loop_studio"][1])
	hum.bus = "Ambient" if AudioServer.get_bus_index("Ambient") >= 0 else "Master"
	c.add_child(hum)
	hum.play()
	_phone_ui(c, "ОБЛАКО LIVE", "podcast_67", "3,1K")
	var hk := _head(k)
	var hp := _head(hst)
	var hh_pos := hp
	# 1 — чёрный, щелчок, лампа записи загорается, титр эпизода влетает; общий план двоих, медленный проезд
	var blk := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.size = fs
		s.add_child(r))
	await c.wait(0.4)
	G67Sound.play(c, "click")
	blk.queue_free()
	(lamp.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.1, 0.1)
	(lamp.material_override as StandardMaterial3D).emission_enabled = true
	(lamp.material_override as StandardMaterial3D).emission = Color(1.0, 0.1, 0.1)
	(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0
	lamp_l.light_energy = 2.0
	c.plate("ПОДКАСТ", "top", 2.5)
	c.cam_at(R + Vector3(6.2, 1.7, 0.9), R + Vector3(0, 1.1, 0.4), 46.0)
	c.cam_to(R + Vector3(5.4, 1.65, 1.0), R + Vector3(0, 1.1, 0.4), 1.4, 40.0)
	await c.wait(1.3)
	hk = Vector3(0.0, 0.9, 0.0)                    # голова КРОТА за столом (сидит низко)
	hp = Vector3(0.0, 1.6, 1.05)                   # голова ведущего
	G67Clips.snap_req = "wide"
	await c.wait(0.4)
	# 2 — реплика ведущего: камера A (ведущий в три четверти) → перебивка на общий; жесты
	G67Sound.play(c, "hit_cut")
	var d0 := c.say_async(L("EXTRA01", 0))
	c.cam_at(R + Vector3(-1.7, 1.55, -1.0), hp, 36.0)
	c.cam_to(R + Vector3(-1.4, 1.5, -0.6), hp, d0 * 0.5, 31.0)
	c.anim("host", "NIdleL", 0.2)
	await c.wait(d0 * 0.5)
	G67Sound.play(c, "click")
	c.cam_at(R + Vector3(5.8, 1.65, 0.9), R + Vector3(0, 1.1, 0.4), 46.0)
	c.cam_to(R + Vector3(5.0, 1.6, 0.9), R + Vector3(0, 1.1, 0.4), d0 * 0.5, 40.0)
	await c.wait(d0 * 0.5)
	# КРОТ тянется к микрофону и придвигает его к себе
	G67Sound.play(c, "mic_move")
	c.create_tween().tween_property(mic_k, "position", R + Vector3(0.1, 1.0, 0.15), 0.5)
	c.cam_at(R + Vector3(1.6, 1.2, 0.9), R + Vector3(0.3, 0.95, 0.1), 34.0)
	await c.wait(0.45)
	# 3 — реплика КРОТА: камера B (КРОТ в три четверти), перебивка — руки стучат по столу, «на ты» — откидывается на спинку
	hk = _bone_pos(k, "mixamorig_Head")
	c.light(hk + Vector3(0.9, 0.45, 1.2), Color(1.0, 0.85, 0.65), 2.6, 4.0)       # ключевой свет на лицо КРОТА
	var d1 := c.say_async(L("EXTRA01", 1))
	c.anim("krot", "CPodTalk", 0.2)
	c.cam_at(_bone_pos(k, "mixamorig_Head") + Vector3(0.85, 0.05, 1.3), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), 44.0)
	c.cam_to(_bone_pos(k, "mixamorig_Head") + Vector3(0.75, 0.05, 1.12), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), d1 * 0.4, 38.0)
	await c.wait(d1 * 0.4)
	G67Sound.play(c, "hit_cut")
	c.cam_at(R + Vector3(-0.9, 1.2, 0.9), R + Vector3(0.0, 0.85, 0.2), 36.0)          # деталь: руки на столе
	for t in 4:
		G67Sound.play(c, "tap")
		await c.wait(d1 * 0.1)
	G67Sound.play(c, "hit_cut")
	c.cam_at(_bone_pos(k, "mixamorig_Head") + Vector3(0.85, 0.05, 1.3), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), 42.0)
	var lean := c.create_tween()
	lean.tween_property(k, "position", R + Vector3(0, 0.24, -0.45), 0.5)
	lean.parallel().tween_property(k, "rotation:x", -0.1, 0.5)
	await c.wait(d1 * 0.5)
	c.clear_sub()
	# 4 — «А конкретно?»: ведущий кивает, быстрый план
	G67Sound.play(c, "hit_cut")
	var d2 := c.say_async(L("EXTRA01", 2))
	c.cam_at(R + Vector3(-1.5, 1.5, -0.7), hp, 34.0)
	c.cam_to(R + Vector3(-1.3, 1.5, -0.4), hp, d2 + 0.2, 30.0)
	c.create_tween().tween_property(hst, "rotation:x", 0.08, 0.3)
	await c.wait(d2 + 0.25)
	c.clear_sub()
	# 5 — последняя реплика КРОТА: наклоняется к микрофону вплотную и смотрит в камеру; общий — перебивка; крупный в финале
	G67Sound.play(c, "hit_cut")
	var back := c.create_tween()
	back.tween_property(k, "position", R + Vector3(0, 0.24, -0.1), 0.4)
	back.parallel().tween_property(k, "rotation:x", 0.12, 0.4)
	hk = _bone_pos(k, "mixamorig_Head")
	var d3 := c.say_async(L("EXTRA01", 3))
	c.anim("krot", "CPodTalk", 0.2)
	await c.wait(0.42)
	c.cam_at(_bone_pos(k, "mixamorig_Head") + Vector3(0.85, 0.05, 1.3), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), 44.0)
	c.cam_to(_bone_pos(k, "mixamorig_Head") + Vector3(0.75, 0.05, 1.12), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), d3 * 0.3, 40.0)
	await c.wait(d3 * 0.3)
	G67Sound.play(c, "click")
	c.cam_at(R + Vector3(5.6, 1.65, 0.9), R + Vector3(0, 1.1, 0.4), 46.0)
	c.cam_to(R + Vector3(4.9, 1.6, 0.9), R + Vector3(0, 1.1, 0.4), d3 * 0.25, 40.0)
	await c.wait(d3 * 0.25)
	G67Sound.play(c, "hit_cut")
	c.anim_once("krot", "CPodNod", 1.6)
	c.cam_at(_bone_pos(k, "mixamorig_Head") + Vector3(0.85, 0.05, 1.3), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), 38.0)                                       # крупный: смотрит в камеру
	c.cam_to(_bone_pos(k, "mixamorig_Head") + Vector3(0.75, 0.05, 1.12), _bone_pos(k, "mixamorig_Head") + Vector3(0, -0.04, 0), d3 * 0.45 + 0.1, 34.0)
	await c.wait(0.6)
	hk = _bone_pos(k, "mixamorig_Head")
	G67Clips.snap_req = "krot_mic"
	await c.wait(d3 * 0.45 - 0.4)
	c.clear_sub()
	# 6 — финал: ведущий молча смотрит на КРОТА, потом в камеру, пауза 1 с, лампа гаснет, обрыв
	G67Sound.play(c, "hit_cut")
	c.cam_at(R + Vector3(-1.7, 1.55, -1.0), hp, 36.0)
	c.cam_to(R + Vector3(-1.4, 1.5, -0.7), hp, 1.4, 32.0)
	await c.wait(0.9)
	c.create_tween().tween_property(hst, "rotation:y", PI + 0.9, 0.5)
	G67Clips.snap_req = "final"
	await c.wait(1.0)
	G67Sound.play(c, "click")
	lamp_l.light_energy = 0.0
	(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0
	(lamp.material_override as StandardMaterial3D).albedo_color = Color(0.15, 0.02, 0.02)
	c.vhs(1.0, 0.4)
	await c.wait(0.4)
	hum.stop()


