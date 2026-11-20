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
}
const NAMES := {"V": "ПАХАН", "M": "MADK1D", "G1": "МИША МИНАСЯН", "KR": "КРОТ", "AN": "ВЕДУЩИЙ", "PH": "ВЕДУЩИЙ ПОДКАСТА",
	"WH": "WHYOUSOLONELY", "FT": "FORTUNA 812", "KX": "КОРОЛЕВСКИЙ XVII", "BS": "ПОЛКОВНИК БУСТЕРЕНКО"}

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
	match id:
		"V00": await v00(c)
		"AD01": await ad01(c)
		"CL01": await cl01(c)
		"NEWS01": await news01(c)
		"STORY01": await story01(c)
		"STORY05": await story05(c)
		"EXTRA01": await extra01(c)
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
	for i in n:
		var coin := Polygon2D.new()
		var pts := PackedVector2Array()
		var r := fs.y * randf_range(0.03, 0.055)
		for k in 18:
			var a := TAU * k / 18.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.9))
		coin.polygon = pts
		coin.color = Color(1.0, 0.78, 0.2)
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
static func v00(c: G67ClipPlayer) -> void:
	var y := _yard(c)
	_snow(c, Vector3(0, 12, 25), Vector3(30, 4, 30))
	var door := Vector3(0.0, 0.0, 35.6)
	var m := c.actor("misha", "misha", door + Vector3(0, 0, -0.6), PI)
	# 0:00–0:02 — чёрный экран, удар, золотые буквы
	var blk := c.screen(func(s: Control, fs: Vector2):
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.size = fs
		s.add_child(r))
	c.sfx("sfx_boom", 0.0, 0.6)
	c.plate("ТЫ ГОТОВ ИЗМЕНИТЬ СВОЙ РАЙОН?", "big", 1.9)
	await c.wait(2.1)
	blk.queue_free()
	# 0:02–0:05 — пролёт над ДВОРОМ, призовой фонд, монеты
	c.cam_at(Vector3(-34, 30, 46), Vector3(0, 0, 10), 55.0)
	c.cam_to(Vector3(18, 22, 4), Vector3(0, 0, 18), 3.2)
	c.plate("ПРИЗОВОЙ ФОНД — 67 000 ГОЛДЫ", "big", 3.0)
	_coins(c, 14)
	await c.wait(3.1)
	c.clear_plates()
	# 0:05–0:08 — Миша выходит из подъезда в слоу-мо: кроссовки → цепь → лицо
	c.anim("misha", "CWalk", 0.1, 0.45)
	c.move("misha", door + Vector3(0, 0, -2.4), 2.4)
	c.cam_at(door + Vector3(0.7, 0.25, -3.2), door + Vector3(0, 0.15, -1.0), 38.0)
	await c.wait(0.9)
	c.cam_at(door + Vector3(-0.9, 1.4, -3.6), _chest(m), 30.0)
	await c.wait(0.8)
	var hd := _head(m) - m.global_position
	var stop := door + Vector3(0, 0, -2.4)
	c.cam_at(stop + hd + Vector3(0.45, 0.12, -1.9), stop + hd + Vector3(0, 0.12, 0), 30.0)
	c.say_async(L("V00", 0))
	await c.wait(2.2)
	# цепь цепляется за ручку двери — рывок, склейка на серьёзное лицо
	c.chain(_chest(m), door + Vector3(0.45, 1.05, 0.05), 2.6)
	c.anim_once("misha", "CYank", 0.9)
	c.sfx("sfx_parry", -2.0, 0.7)
	c.shake(0.7)
	await c.wait(0.9)
	c.anim("misha", "CStuck", 0.2)
	await c.wait(0.05)
	c.cam_at(_head(m) + Vector3(-0.5, 0.15, -1.7), _head(m) + Vector3(0, 0.12, 0), 28.0)
	await c.say(L("V00", 1), 0.2)
	# 0:08–0:11 — FORTUNA 812 у турникета ПОДЗЕМКИ открывает створку жестом ведущего; тарифы вылетают плашками
	var U := Vector3(60, 0, 0)
	_metro(c, U)
	var ft := c.actor("fortuna", "fortuna", U + Vector3(-0.9, 0, 0.6), 0.5)
	c.anim("fortuna", "CPresent", 0.0)
	var flap := c.box(Vector3(0.05, 0.75, 0.6), U + Vector3(0.0, 0.85, 0.3), Color(0.75, 0.85, 0.95, 1.0), 0.2)
	c.cam_at(U + Vector3(1.6, 1.5, 3.4), U + Vector3(-0.3, 1.1, 0.3), 46.0)
	c.cam_to(U + Vector3(1.0, 1.4, 2.8), U + Vector3(-0.4, 1.15, 0.3), 3.0)
	c.create_tween().tween_property(flap, "rotation:y", -1.3, 0.5).set_delay(0.3)
	c.say_async(L("V00", 2))
	var fort := Control.new()
	fort.size = c.frame.size
	c.over.add_child(fort)
	for tx in ["ВХОД — 67", "ВЫХОД — 67", "ПОСМОТРЕТЬ НА ТУРНИКЕТ — 6,7"]:
		_tariff(c, fort, tx, tx.length() > 12)
		c.sfx("sfx_ui", -6.0, 0.9)
		await c.wait(0.75)
	await c.wait(0.8)
	fort.queue_free()
	# 0:11–0:14 — Королевский XVII щёлкает кольцевой лампой: Пахан пропадает в белом
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
	await c.wait(0.5)
	c.sfx("sfx_ui", -2.0, 1.8)
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
	c.cam_at(K + Vector3(-0.2, 1.5, 3.6), K + Vector3(0.9, 1.3, 0.6), 40.0)
	await c.say(L("V00", 3), 0.1)
	c.cam_at(K + Vector3(0.3, 1.5, 2.4), _head(p), 34.0)
	var wt2 := c.create_tween()
	wt2.tween_property(white.get_node("w"), "color:a", 0.72, 1.4)
	wt2.parallel().tween_property(flash, "light_energy", 7.0, 1.4)
	await c.say(L("V00", 4), 0.2)
	white.queue_free()
	# 0:14–0:17 — Полковник Бустеренко запускает счётчик; отъезд — один компьютер, один профиль на всех мониторах
	var B := Vector3(180, 0, 0)
	_botfarm(c, B)
	var bs := c.actor("busterenko", "busterenko", B + Vector3(0, 0, 0.6), PI)
	c.anim("busterenko", "CDesk", 0.0)
	var bus := Control.new()
	bus.size = c.frame.size
	c.over.add_child(bus)
	var cnt := _counter(c, bus, 67000000, 1.6)
	await c.wait(0.05)
	c.cam_at(B + Vector3(0.95, 1.45, -0.75), _head(bs) + Vector3(0, 0.1, 0), 36.0)
	c.say_async(L("V00", 5))
	await c.wait(1.6)
	var tw := c.create_tween()
	tw.tween_property(cnt, "modulate:a", 0.0, 0.4)
	c.cam_at(B + Vector3(0.6, 1.6, 2.2), B + Vector3(0, 1.3, -1.0), 40.0)
	c.cam_to(B + Vector3(3.8, 3.2, 6.5), B + Vector3(0, 1.6, -1.2), 1.8, 50.0)
	await c.wait(1.9)
	bus.queue_free()
	c.actors.erase("pahan")
	p.queue_free()
	# 0:17–0:21 — madk1d суёт телефон Пахану; «СПИСАНО 6 700 ГОЛДЫ»
	var p2 := c.actor("pahan", "pahan", door + Vector3(1.2, 0, -6.0), PI * 0.1)
	var mk := c.actor("madk1d", "madk1d", door + Vector3(1.0, 0, -7.1), PI * 0.05)
	c.anim("madk1d", "CPhoneOut", 0.1)
	c.cam_at(door + Vector3(2.4, 1.45, -8.6), door + Vector3(1.1, 1.2, -6.4), 42.0)
	c.shake(0.3)
	await c.say(L("V00", 6), 0.1)
	c.cam_at(_head(p2) + Vector3(-0.6, 0.0, 1.4), _head(p2), 34.0)
	await c.say(L("V00", 7), 0.1)
	c.plate("СПИСАНО 6 700 ГОЛДЫ", "stamp", 1.4)
	c.sfx("sfx_ui", -4.0, 0.6)
	await c.wait(1.2)
	# 0:21–0:25 — логотип; Пахан за кадром; джингл обрывается
	var lg := _logo(c)
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
	await c.say(L("NEWS01", 0), 0.15)
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
	await c.wait(_len(c, L("STORY01", 0)) + 0.2)
	await c.say(L("STORY01", 1), 0.1)
	# нажимает «ЗАРЕГИСТРИРОВАТЬСЯ» → взнос
	c.sfx("sfx_ui", -4.0, 1.3)
	ph.queue_free()
	ph = c.screen(func(s: Control, fs: Vector2):
		_phone_screen(c, s, fs, "pay"))
	await c.wait(0.8)
	await c.say(L("STORY01", 2), 0.1)
	c.sfx("sfx_ui", -2.0, 1.7)
	c.sfx("sfx_ui", -2.0, 2.2)
	ph.queue_free()
	ph = c.screen(func(s: Control, fs: Vector2):
		_phone_screen(c, s, fs, "done"))
	await c.wait(1.2)
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
		var l := c._label(s, text, int(fs.x * size), col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(fs.x * 0.9, 0)
		l.position = Vector2(fs.x * 0.05, fs.y * y)
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
static func extra01(c: G67ClipPlayer) -> void:
	c.set_env("studio")
	var R := Vector3(0, 0, 0)
	c.box(Vector3(6, 0.1, 6), R + Vector3(0, -0.05, 0), Color(0.12, 0.1, 0.09))
	c.box(Vector3(6, 3.4, 0.12), R + Vector3(0, 1.7, -1.6), Color(0.1, 0.1, 0.12))
	for i in 6:
		for j in 3:
			c.box(Vector3(0.5, 0.5, 0.08), R + Vector3(-1.4 + i * 0.56, 0.9 + j * 0.56, -1.52), Color(0.16, 0.15, 0.18) if (i + j) % 2 == 0 else Color(0.2, 0.12, 0.12))
	c.box(Vector3(1.6, 0.06, 0.8), R + Vector3(0, 0.78, 0.55), Color(0.35, 0.24, 0.15))
	c.box(Vector3(0.08, 0.75, 0.08), R + Vector3(-0.7, 0.38, 0.55), Color(0.2, 0.2, 0.2))
	c.box(Vector3(0.08, 0.75, 0.08), R + Vector3(0.7, 0.38, 0.55), Color(0.2, 0.2, 0.2))
	# микрофон на подставке
	var arm := c.box(Vector3(0.03, 0.3, 0.03), R + Vector3(0.3, 0.95, 0.75), Color(0.1, 0.1, 0.1))
	var mic := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.05
	cm.height = 0.2
	mic.mesh = cm
	mic.position = R + Vector3(0.27, 1.15, 0.66)
	mic.rotation.x = 0.5
	mic.rotation.z = 0.35
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.15, 0.17)
	mm.metallic = 0.6
	mic.material_override = mm
	c.world.add_child(mic)
	c.light(R + Vector3(0.6, 2.4, 1.8), Color(1.0, 0.9, 0.75), 2.4, 7.0, true)
	c.light(R + Vector3(-1.5, 1.4, -0.5), Color(0.9, 0.3, 0.4), 1.2, 5.0)
	var k := c.actor("krot", "krot", R + Vector3(0, 0.0, 0.05), 0.0)
	c.anim("krot", "CPod", 0.0)
	_phone_ui(c, "ОБЛАКО LIVE", "podcast_67", "3,1K")
	c.plate("ПОДКАСТ", "top", 0.0)
	c.cam_at(R + Vector3(-0.45, 1.35, 2.6), R + Vector3(-0.05, 1.15, 0.2), 48.0)
	await c.say(L("EXTRA01", 0), 0.2)
	c.anim("krot", "CPodTalk", 0.2)
	await c.say(L("EXTRA01", 1), 0.2)
	c.anim("krot", "CPod", 0.2)
	await c.say(L("EXTRA01", 2), 0.15)
	c.anim("krot", "CPodTalk", 0.2)
	await c.say(L("EXTRA01", 3), 0.1)
	# медленный кивок, зум, подпись
	c.anim_once("krot", "CPodNod", 1.6)
	c.cam_to(_head(k) + Vector3(-0.3, 0.12, 1.4), _head(k) + Vector3(0, 0.1, 0), 1.6, 36.0)
	c.plate("ЭКСПЕРТ ПО ВРЕМЕНИ", "caption", 2.2)
	await c.wait(2.2)
