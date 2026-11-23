## Анимации в игре (этап 03): -- --animlab=<папка>, запускать с --fixed-fps 30 --resolution 1280x720.
## Настоящая глава, настоящие Пахан и madk1d, их контроллеры, AnimState и FootIK; своя камера сбоку.
## Сцены: перемещение (старт, бег, остановка, шаг, рывок, поворот на месте), удар, комбо, получение урона
## с разных сторон, падение и подъём, прыжок; madk1d — рывок и удары, аэрокомбо, брейк, перемещение.
## Каждая сцена — лист из 16 кадров lab_<сцена>.png. В перемещении меряются стопы: насколько опорная стопа
## проскальзывает по земле и не уходит ли под пол. В конце — «ANIMLAB ok» или «ANIMLAB ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var scenes: Array = []
var si := -1
var f := 0
var thumbs: Array = []
var fails := 0
var P
var B
var meas := {}            # кто → {"prev": {сторона: Vector3}, "slip": [], "pen": float, "float": float}
var measure_on := false
var trace := false

const TW := 480
const TH := 270

const SHAKE_MAX := 0.25      # рывок положения — не больше четверти шага за кадр: выше — герой дрожит
var shake_log: Array = []
var tyaga_amp := [0.0, 0.0, 0.0]
var shake_f := -1
var jump_top := [0.0, 0.0, 0.0]
var jump_air_hit := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 200.0
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	_build()
	# --only=01,09 — только эти сцены
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var want := a.substr(7).split(",")
			scenes = scenes.filter(func(sc): return want.has(String(sc["n"]).substr(0, 2)))
		if a == "--nofootik":
			FootIK.off = true
		if a == "--trace":
			trace = true

func owns_camera() -> bool:
	return true

func hide_hud() -> bool:
	return true

func ok(c: bool, msg: String) -> void:
	print(("ANIMLAB ok: " if c else "ANIMLAB ОШИБКА: ") + msg)
	if not c:
		fails += 1

func _stage() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	game.toast_t = 0.0
	P = game.player
	B = game.buddy
	P.hp = P.max_hp
	P.state = "move"
	P.swag = 0.0
	P.rage = 0.0
	P.auto_input = {}
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	P.velocity = Vector3.ZERO
	game.cam_yaw = 0.0
	_park_buddy(Vector3(-2.4, 0.05, 6.0))

func _park_buddy(at: Vector3) -> void:
	B.global_position = at
	B.target = at
	B.wait = 99.0
	B.velocity = Vector3.ZERO

func _hold_buddy() -> void:
	B.target = B.global_position
	B.wait = 99.0

func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)

## камера сбоку от героя (side — с какой стороны, dist — расстояние)
func _side(who: Node3D, dist := 5.2, h := 1.3, side := 1.0) -> void:
	var p: Vector3 = who.global_position
	_look(p + Vector3(side * dist, h, -0.6), p + Vector3(0, 0.75, 0))

func _build() -> void:
	# 1. перемещение Пахана: стоит → бег → остановка → шаг → остановка → рывок → остановка → разворот на месте
	scenes.append({"n": "01_pahan_move", "len": 330, "measure": "P", "shake": {"бег": [30, 60]}, "setup": func(): _stage(), "tick": func(i):
		P.inv = 1.0
		_park_buddy(P.global_position + Vector3(-3.5, 0, 0))
		var inp := {}
		if i >= 20 and i < 62:
			inp = {"move": Vector2(0, 1)}
		elif i >= 95 and i < 140:
			inp = {"move": Vector2(0, -0.45)}
		elif i >= 170 and i < 205:
			inp = {"move": Vector2(0, 1), "sprint": "hold"}
		P.auto_input = inp
		if i == 250:
			P.turn_to = wrapf(P.face + 2.5, -PI, PI)
		_side(P)})
	# 2. удар: лёгкий и тяжёлый по ботам
	scenes.append({"n": "02_pahan_strike", "len": 95, "setup": func():
		_stage()
		for x in [-1.0, 1.0]:
			game.spawn_enemy("bot", P.global_position + Vector3(x, 0, -2.3)), "tick": func(i):
		P.inv = 1.0
		_hold_buddy()
		P.auto_input = {"attack": "press"} if i == 3 else ({"heavy": "press"} if i == 40 else {})
		_look(P.global_position + Vector3(4.4, 1.5, -1.0), P.global_position + Vector3(0, 0.9, -1.2))})
	# 3. комбо: четыре лёгких и тяжёлый
	scenes.append({"n": "03_pahan_combo", "len": 120, "setup": func():
		_stage()
		for x in [-1.1, 0.0, 1.1]:
			game.spawn_enemy("bot", P.global_position + Vector3(x, 0, -2.3 - abs(x) * 0.2)), "tick": func(i):
		P.inv = 1.0
		_hold_buddy()
		var presses := {2: "attack", 14: "attack", 26: "attack", 38: "attack", 52: "heavy"}
		P.auto_input = {presses[i]: "press"} if presses.has(i) else {}
		_look(P.global_position + Vector3(4.3, 1.5, -1.2), P.global_position + Vector3(0, 0.95, -1.3))})
	# 4. получение урона: спереди, сзади, слева, справа, сильный удар (отброс)
	scenes.append({"n": "04_pahan_hurt", "len": 150, "shots": [0, 7, 10, 14, 34, 37, 41, 61, 64, 68, 88, 91, 95, 115, 119, 126], "setup": func(): _stage(), "tick": func(i):
		_hold_buddy()
		P.auto_input = {}
		P.hp = P.max_hp
		var fw := Vector3(sin(P.face), 0, cos(P.face))
		var left := Vector3(cos(P.face), 0, -sin(P.face))
		var hits := {5: [fw, 10.0], 32: [-fw, 10.0], 59: [left, 10.0], 86: [-left, 10.0], 113: [fw, 25.0]}
		if hits.has(i):
			P.inv = 0.0
			P.state = "move"
			P.take_damage(float(hits[i][1]), P.global_position + (hits[i][0] as Vector3) * 2.0)
		_look(P.global_position + Vector3(2.6, 1.3, -2.4), P.global_position + Vector3(0, 0.85, 0))})
	# 5. падение и подъём, затем прыжок и приземление
	scenes.append({"n": "05_pahan_down_up_jump", "len": 160, "shots": [1, 6, 12, 20, 34, 48, 58, 66, 76, 92, 103, 110, 116, 122, 130, 145], "setup": func(): _stage(), "tick": func(i):
		P.inv = 1.0
		_hold_buddy()
		P.auto_input = {}
		if i == 2:
			P.state = "lab"
			P.velocity = Vector3.ZERO
			P.anim.action("knockdown", 0.9)
		elif i == 45:
			P.anim.action("recovery", 1.1)
		elif i == 82:
			P.state = "move"
		elif i == 100:
			P.anim.jump()
		elif i == 109:
			P.velocity.y = 6.5
		_side(P, 5.6, 1.2)})
	# 6. madk1d: рывок, двойка, удар с разворота, вертушка, прыжковая атака, смена стиля
	scenes.append({"n": "06_madk_strikes", "len": 170, "shots": [1, 6, 12, 26, 37, 50, 57, 70, 76, 82, 95, 102, 110, 124, 134, 150], "setup": func():
		_stage()
		P.global_position = Vector3(-7.0, 0.05, 2.0)
		_park_buddy(Vector3(-1.5, 0.05, 2.0))
		B.face = PI, "tick": func(i):
		P.inv = 1.0
		var acts := {2: ["Dash", 0.32], 22: ["Light", 0.28], 32: ["Cross", 0.28], 44: ["RoundKick", 0.45], 64: ["SpinKick", 0.5], 88: ["JumpKick", 0.55], 118: ["StyleSwitch", 0.8]}
		if acts.has(i):
			B.anim.action(acts[i][0], acts[i][1])
		_hold_buddy()
		_side(B, 5.0, 1.1)})
	# 7. madk1d: аэрокомбо — прыжок, колено, нога, оборот, удар вниз с пикированием
	scenes.append({"n": "07_madk_air", "len": 110, "shots": [1, 5, 9, 14, 18, 21, 25, 29, 33, 38, 42, 47, 52, 58, 64, 75], "setup": func():
		_stage()
		P.global_position = Vector3(-7.0, 0.05, 2.0)
		_park_buddy(Vector3(-1.5, 0.05, 2.0))
		B.face = PI, "tick": func(i):
		P.inv = 1.0
		if i == 2:
			B.anim.jump()
		elif i == 7:
			B.velocity.y = 8.0
		var acts := {16: ["AirKnee", 0.32], 26: ["AirKick", 0.32], 36: ["AirSpin", 0.45], 50: ["AirDive", 0.5]}
		if acts.has(i):
			B.anim.action(acts[i][0], acts[i][1])
		_hold_buddy()
		_look(B.global_position + Vector3(3.6, 0.6, -0.6), B.global_position + Vector3(0, 0.7, 0))})
	# 8. madk1d: брейк — шесть шагов, фриз, на спину и мельница, подъём разгибом
	scenes.append({"n": "08_madk_breaker", "len": 270, "setup": func():
		_stage()
		P.global_position = Vector3(-7.0, 0.05, 2.0)
		_park_buddy(Vector3(-1.5, 0.05, 2.0))
		B.face = PI * 0.75, "tick": func(i):
		P.inv = 1.0
		var acts := {2: ["SixStep", 2.8], 88: ["Freeze", 1.8], 144: ["knockdown", 0.45], 158: ["Windmill", 1.8], 214: ["KipUp", 0.75]}
		if acts.has(i):
			B.anim.action(acts[i][0], acts[i][1])
		_hold_buddy()
		_look(B.global_position + Vector3(3.2, 1.4, 2.4), B.global_position + Vector3(0, 0.45, 0))})
	# 9. madk1d: перемещение — старт, бег, остановка, разворот на месте
	scenes.append({"n": "09_madk_move", "len": 200, "measure": "B", "setup": func():
		_stage()
		P.global_position = Vector3(0, 0.05, 2.0)
		_park_buddy(Vector3(-2.0, 0.05, 3.5)), "tick": func(i):
		P.inv = 1.0
		P.auto_input = {}
		if i == 10:
			B.target = B.global_position + Vector3(0, 0, -3.8)
		elif i == 70:
			B.target = B.global_position + Vector3(0, 0, 3.8)
		elif i < 130:
			B.wait = 99.0
		if i == 140:
			game.cam_yaw = 2.6        # кент смотрит туда же, куда игрок: поворот направления — разворот на месте
		B.wait = 99.0
		_side(B, 5.4, 1.2, -1.0)})
	# Пахан: прыжок с места, прыжок на бегу, удар в прыжке — настоящим вводом (клавиша «jump»)
	scenes.append({"n": "10_pahan_jump", "len": 150, "shots": [9, 12, 15, 19, 24, 30, 36, 62, 66, 70, 76, 84, 104, 108, 112, 118], "setup": func():
		_stage()
		jump_top = [0.0, 0.0, 0.0]
		jump_air_hit = false, "tick": func(i):
		P.inv = 1.0
		_park_buddy(P.global_position + Vector3(-4.5, 0, 0))
		var inp := {}
		if i >= 45 and i < 80:
			inp["move"] = Vector2(0, 1)
		if i == 10 or i == 60 or i == 100:
			inp["jump"] = "press"
		if i == 106:
			inp["attack"] = "press"
		P.auto_input = inp
		var part := 0 if i < 45 else (1 if i < 95 else 2)
		jump_top[part] = max(float(jump_top[part]), P.global_position.y)
		if P.state == "attack" and not P.is_on_floor():
			jump_air_hit = true
		if i == 148:
			ok(float(jump_top[0]) > 1.0 and float(jump_top[1]) > 1.0 and float(jump_top[2]) > 1.0 and jump_air_hit and P.is_on_floor(), "Пахан: прыжок с места %.2f м, на бегу %.2f м, с ударом %.2f м; удар в воздухе %s, приземлился %s" % [jump_top[0], jump_top[1], jump_top[2], jump_air_hit, P.is_on_floor()])
		_side(P, 6.2, 1.5)})
	# madk1d: прыжок с места, прыжок на бегу, удар в прыжке — настоящим вводом (клавиша «jump»)
	scenes.append({"n": "11_madk_jump", "len": 150, "shots": [9, 12, 15, 19, 24, 30, 36, 62, 66, 70, 76, 84, 104, 108, 112, 118], "setup": func():
		_stage()
		if P.hero != "madk1d":
			game.swap_heroes()
		jump_top = [0.0, 0.0, 0.0]
		jump_air_hit = false, "tick": func(i):
		P.inv = 1.0
		_park_buddy(P.global_position + Vector3(-4.5, 0, 0))
		var inp := {}
		if i >= 45 and i < 80:
			inp["move"] = Vector2(0, 1)
		if i == 10 or i == 60 or i == 100:
			inp["jump"] = "press"
		if i == 106:
			inp["attack"] = "press"
		P.auto_input = inp
		var part := 0 if i < 45 else (1 if i < 95 else 2)
		jump_top[part] = max(float(jump_top[part]), P.global_position.y)
		if P.state == "attack" and not P.is_on_floor():
			jump_air_hit = true
		if i == 148:
			ok(float(jump_top[0]) > 1.0 and float(jump_top[1]) > 1.0 and float(jump_top[2]) > 1.0 and jump_air_hit and P.is_on_floor(), "madk1d: прыжок с места %.2f м, на бегу %.2f м, с ударом %.2f м; удар в воздухе %s, приземлился %s" % [jump_top[0], jump_top[1], jump_top[2], jump_air_hit, P.is_on_floor()])
		_side(P, 6.2, 1.5)})
	# 12. Пахан с ТЯГА-812: шаг с пылесосом в руках, затем езда верхом с поворотом — замер тряски
	scenes.append({"n": "12_pahan_tyaga", "len": 330, "shake": {"шаг с пылесосом": [80, 150], "езда": [215, 320]}, "setup": func():
		_stage()
		if P.hero != "pahan":        # прошлые сцены могли оставить героем madk1d
			game.swap_heroes()
		tyaga_amp = [0.0, 0.0, 0.0], "tick": func(i):
		P.inv = 1.0
		_park_buddy(P.global_position + Vector3(-6.0, 0, 3.0))
		var inp := {}
		if i == 3:
			inp["style3"] = "press"
		if i >= 70 and i < 150:
			inp["move"] = Vector2(0, 1)
		if i == 165:
			inp["heat"] = "press"
		if i >= 195:
			inp["move"] = Vector2(0.5 if i > 260 else 0.0, 1)
			inp["sprint"] = "hold"
		P.auto_input = inp
		# корпус пылесоса: стоит на холостом — еле дрожит; на ходу — переваливается; верхом — тоже; и нигде не улетает
		var amp: float = P.tyaga.rock_amp
		if i >= 40 and i < 68:
			tyaga_amp[0] = max(float(tyaga_amp[0]), amp)
		elif i >= 90 and i < 150:
			tyaga_amp[1] = max(float(tyaga_amp[1]), amp)
		elif i >= 230:
			tyaga_amp[2] = max(float(tyaga_amp[2]), amp)
		if i == 328:
			ok(float(tyaga_amp[0]) > 0.0005 and float(tyaga_amp[1]) > float(tyaga_amp[0]) * 2.0 and float(tyaga_amp[2]) > 0.004 and float(tyaga_amp[1]) < 0.06 and float(tyaga_amp[2]) < 0.08, "корпус пылесоса живой: на холостом дрожит на %.1f мм, на ходу качается на %.1f мм, верхом — %.1f мм; не больше 8 см" % [float(tyaga_amp[0]) * 1000.0, float(tyaga_amp[1]) * 1000.0, float(tyaga_amp[2]) * 1000.0])
		_side(P, 6.0, 1.4)})
	# 13. madk1d на скейте: разгон, езда, поворот — замер тряски
	scenes.append({"n": "13_madk_skate", "len": 230, "shake": {"езда на скейте": [70, 220]}, "setup": func():
		_stage()
		if P.hero != "madk1d":
			game.swap_heroes(), "tick": func(i):
		P.inv = 1.0
		_park_buddy(P.global_position + Vector3(-6.0, 0, 3.0))
		var inp := {}
		if i >= 15:
			inp["move"] = Vector2(0.5 if i > 140 else 0.0, 1)
			inp["sprint"] = "hold"
		P.auto_input = inp
		_side(P, 6.0, 1.4)})

## замер — перед самой отрисовкой кадра, когда всё уже подвинуто: это то, что видит игрок
func _pre_draw() -> void:
	if shake_f >= 0 and P != null and is_instance_valid(P):
		_shake_sample(shake_f)

func _shake_sample(i: int) -> void:
	var r: Rig = P.rig
	var gx: Transform3D = r.skel.global_transform
	# где герой в мире на этом кадре: голова и таз
	var head: Vector3 = (gx * r.skel.get_bone_global_pose(int(r.bone["head"]))).origin
	var hips: Vector3 = (gx * r.skel.get_bone_global_pose(int(r.bone["hips"]))).origin
	shake_log.append([i, head, hips, P.body.rotation, P.vis_pos(), game.get_process_delta_time()])

func _shake_report(s: Dictionary) -> void:
	# Плавное движение: положение таза от кадра к кадру меняется ровно. Дрожь — когда рывок (вторая разность)
	# сравним с самим шагом за кадр: так было, пока тело двигалось шагами физики, а кадры шли со своей частотой.
	for seg in s["shake"]:
		var a: int = s["shake"][seg][0]
		var b: int = s["shake"][seg][1]
		var jerk: Array = []
		var step: Array = []
		var turn: Array = []
		for j in range(1, shake_log.size() - 1):
			if int(shake_log[j][0]) <= a or int(shake_log[j][0]) >= b:
				continue
			var h0: Vector3 = shake_log[j - 1][2]
			var h1: Vector3 = shake_log[j][2]
			var h2: Vector3 = shake_log[j + 1][2]
			jerk.append((h2 - h1 * 2.0 + h0).length())
			step.append((h2 - h1).length())
			turn.append(((shake_log[j + 1][3] as Vector3) - (shake_log[j][3] as Vector3) * 2.0 + (shake_log[j - 1][3] as Vector3)).length())
		if jerk.is_empty():
			continue
		jerk.sort()
		step.sort()
		turn.sort()
		@warning_ignore("integer_division")
		var mj: float = jerk[jerk.size() / 2]
		@warning_ignore("integer_division")
		var ms: float = max(0.0001, float(step[step.size() / 2]))
		@warning_ignore("integer_division")
		print("ANIMLAB тряска %s — %s: шаг за кадр %.1f мм, рывок %.2f мм (%.0f%% шага), рывок поворота %.4f рад" % [s["n"], seg, ms * 1000.0, mj * 1000.0, mj / ms * 100.0, float(turn[turn.size() / 2])])
		# с --fixed-fps число шагов физики на кадр скачет само по себе — плавность оценивается только с ключом --smooth (и без --fixed-fps)
		if not OS.get_cmdline_user_args().has("--smooth"):
			continue
		ok(mj / ms < SHAKE_MAX, "%s — %s: герой движется плавно (рывок %.0f%% шага за кадр, предел %.0f%%)" % [s["n"], seg, mj / ms * 100.0, SHAKE_MAX * 100.0])

func frame(_dt: float) -> void:
	if si < 0:
		_next()
		return
	if si >= scenes.size():
		return
	var s: Dictionary = scenes[si]
	var n: int = s["len"]
	# на экране — картинка прошлого кадра: снимаем её, если это один из 16 кадров листа
	var k := f - 1
	var sh: Array = s["shots"]
	if k >= 0 and thumbs.size() < sh.size() and k == int(sh[thumbs.size()]):
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(TW, TH)
		thumbs.append(img)
	if f >= n:
		_finish(s)
		_next()
		return
	(s["tick"] as Callable).call(f)
	shake_f = f if s.has("shake") else -1
	if trace and f % 3 == 0 and s.has("measure"):
		var w: Node3D = P if s["measure"] == "P" else B
		print("TRACE %d %s %s ss=%.2f v=%.2f floor=%s slip=%.3f locks=%s/%s" % [f, w.anim.state, w.rig.cur, w.rig.player.speed_scale, Vector2(w.velocity.x, w.velocity.z).length(), w.is_on_floor(), w.feet.slip, w.feet.feet["r"]["locked"], w.feet.feet["l"]["locked"]])
	f += 1

func _next() -> void:
	si += 1
	f = 0
	thumbs.clear()
	shake_log.clear()
	measure_on = false
	if si >= scenes.size():
		print("ANIMLAB ok" if fails == 0 else "ANIMLAB ОШИБОК: %d" % fails)
		get_tree().quit()
		return
	var s: Dictionary = scenes[si]
	if not s.has("shots"):
		var sh := []
		for i in 16:
			sh.append(int(round(i * (int(s["len"]) - 1) / 15.0)))
		s["shots"] = sh
	(s["setup"] as Callable).call()
	cam.make_current()
	if s.has("measure"):
		_measure_start(P if s["measure"] == "P" else B)

func _finish(s: Dictionary) -> void:
	var sheet := Image.create(TW * 4, TH * 4, false, Image.FORMAT_RGBA8)
	for i in thumbs.size():
		var im: Image = thumbs[i]
		im.convert(Image.FORMAT_RGBA8)
		@warning_ignore("integer_division")
		sheet.blit_rect(im, Rect2i(0, 0, TW, TH), Vector2i((i % 4) * TW, (i / 4) * TH))
	sheet.save_png(out.path_join("lab_%s.png" % s["n"]))
	if s.has("measure"):
		_measure_report(s["n"])
	if s.has("shake"):
		_shake_report(s)
	print("ANIMLAB сцена %s: кадров %d" % [s["n"], thumbs.size()])

# ---------------- замер стоп ----------------
var m_who: Node3D
func _measure_start(who: Node3D) -> void:
	m_who = who
	meas = {"prev": {}, "slip": [], "pen": 0.0, "steps": 0}
	var sk: Skeleton3D = who.rig.skel
	if not sk.skeleton_updated.is_connected(_on_skel):
		sk.skeleton_updated.connect(_on_skel)
	measure_on = true

## после всех слоёв (анимация, балон, iPod, стопы) — где стопы на самом деле
func _on_skel() -> void:
	if not measure_on or m_who == null or not m_who.is_on_floor():
		return
	var r: Rig = m_who.rig
	var gx := r.skel.global_transform
	var ground: float = m_who.global_position.y
	for s in ["r", "l"]:
		var F: Dictionary = m_who.feet.feet[s]
		var a: Vector3 = (gx * r.skel.get_bone_global_pose(F["foot"])).origin
		var h := a.y - ground - float(F["rest_h"])
		meas["pen"] = min(float(meas["pen"]), h)
		var prev: Dictionary = meas["prev"]
		if h < 0.03 and prev.has(s) and prev[s] != null:
			var d := Vector2(a.x - (prev[s] as Vector3).x, a.z - (prev[s] as Vector3).z).length()
			(meas["slip"] as Array).append(d / (1.0 / 30.0))
		prev[s] = a if h < 0.03 else (null as Variant)

func _measure_report(nm: String) -> void:
	measure_on = false
	var sk: Skeleton3D = m_who.rig.skel
	if sk.skeleton_updated.is_connected(_on_skel):
		sk.skeleton_updated.disconnect(_on_skel)
	var sl: Array = meas["slip"]
	sl.sort()
	@warning_ignore("integer_division")
	var med: float = sl[sl.size() / 2] if not sl.is_empty() else 0.0
	var p90: float = sl[int(sl.size() * 0.9)] if not sl.is_empty() else 0.0
	print("ANIMLAB %s: опорная стопа — медиана %.2f м/с, 90%% кадров < %.2f м/с (кадров опоры %d); ниже пола до %.3f м" % [nm, med, p90, sl.size(), meas["pen"]])
	# стоя стопа неподвижна и так, поэтому мерило — 90-й процентиль: он ловит скольжение на старте, остановке и повороте
	ok(p90 < 0.25, "%s: опорная стопа не скользит (90%% кадров < %.2f м/с)" % [nm, p90])
	ok(float(meas["pen"]) > -0.04, "%s: стопы не уходят под пол (%.3f м)" % [nm, meas["pen"]])
