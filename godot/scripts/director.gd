## Съёмка кадров для трейлера (--trailer=папка, запускать с --fixed-fps 30 --resolution 1280x720).
## Ставит сцены в нужных главах, управляет Паханом через бота, свои ракурсы камеры; каждый кадр сохраняет в JPG.
extends Node

var game
var out := ""
var cam: Camera3D
var shots: Array = []
var si := -1
var f := 0            # кадр внутри плана (с учётом разгона)
var slow := 1.0
var own := false
var saved := 0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 250.0
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)
	var P = game.player
	# A — двор: камера облетает Пахана и кента спереди
	shots.append({"n": "A", "warm": 12, "len": 96, "own": true, "setup": func():
		_stage(0), "tick": func(i):
		var a: float = 3.5 - i * 0.006
		var r: float = 5.4 - i * 0.012
		var off := Vector3(sin(a) * r, 0, cos(a) * r)
		# герои стоят рядом и смотрят в камеру
		P.face = atan2(off.x, off.z)
		P.auto_input = {}
		game.cam_yaw = atan2(-off.x, -off.z)
		var B = game.buddy
		B.global_position = P.global_position + Vector3(cos(P.face), 0, -sin(P.face)) * 1.35
		B.target = B.global_position
		B.wait = 9.0
		B.face = P.face
		var mid: Vector3 = (P.global_position + B.global_position) * 0.5
		_look(mid + off + Vector3(0, 1.2, 0), mid + Vector3(0, 1.1, 0))})
	# B — проход с золотой аурой: камера пятится перед Паханом, снизу
	shots.append({"n": "B", "warm": 14, "len": 100, "own": true, "slow": 0.5, "setup": func():
		_stage(0)
		game.cam_yaw = 0.0
		P.global_position = Vector3(0, 0.05, 9), "tick": func(_i):
		P.swag = 100.0
		P.auto_input = {"move": Vector2(0, 1)}
		_look(P.global_position + Vector3(0.9, 0.55, -4.2), P.global_position + Vector3(0, 1.15, 0))})
	# C — ПЕРЕГРУЗ: боты вокруг разлетаются
	shots.append({"n": "C", "warm": 44, "len": 80, "own": true, "slow": 0.5, "setup": func():
		_stage(0)
		game.cam_yaw = 0.0
		for i in 6:
			var a := -2.3 + i * 0.36
			game.spawn_enemy("bot", P.global_position + Vector3(sin(a) * 3.0, 0, -cos(a) * 3.0)), "tick": func(i):
		P.swag = 100.0 if i < 50 else P.swag
		P.auto_input = {"rage": "press"} if i == 50 else {}
		game.buddy.global_position = P.global_position + Vector3(-2.2, 0, 3.0)
		game.buddy.target = game.buddy.global_position
		game.buddy.wait = 5.0
		_look(P.global_position + Vector3(2.9 - i * 0.008, 0.95, -3.3), P.global_position + Vector3(-0.3, 1.15, -0.4))})
	# X1 — Heat-добивание крупным планом (неон)
	shots.append({"n": "X1_", "warm": 40, "len": 96, "own": true, "setup": func():
		_stage(2)
		game.cam_yaw = 0.0
		P.face = PI
		game.spawn_enemy("clipper", P.global_position + Vector3(0.2, 0, -2.3)), "tick": func(i):
		P.inv = 1.0
		if i < 2:
			P.swag = 100.0
		P.auto_input = {"heat": "press"} if i == 1 else {}
		_park_buddy()
		_look(P.global_position + Vector3(3.0 - i * 0.006, 0.85, -0.9), P.global_position + Vector3(0, 1.0, -1.2))})
	# X2 — заряженный полный замах по толпе (подвал), камера из-за плеча
	shots.append({"n": "X2_", "warm": 46, "len": 104, "own": true, "slow": 0.5, "setup": func():
		_stage(1)
		game.cam_yaw = 0.0
		P.face = PI
		for x in [-1.7, -0.85, 0.0, 0.85, 1.7]:
			game.spawn_enemy("bot", P.global_position + Vector3(x, 0, -2.4 - abs(x) * 0.25)), "tick": func(i):
		P.inv = 1.0
		_park_buddy()
		if i == 1:
			P.start_finisher(2)
		P.auto_input = {"heavy": "hold"} if i < 52 else {}
		_look(P.global_position + Vector3(-2.3 + i * 0.004, 1.35, 2.5), P.global_position + Vector3(0.3, 1.0, -1.6))})
	# X3 — «нунчаки»: вертушка в кольце врагов (чарты), камера облетает сверху
	shots.append({"n": "X3_", "warm": 46, "len": 76, "own": true, "slow": 0.5, "setup": func():
		_stage(7)
		game.cam_yaw = 0.0
		P.face = PI
		var kinds := ["clipper", "bot", "hater", "clipper", "bot", "bot"]
		for i in 6:
			var a := i / 6.0 * TAU
			game.spawn_enemy(kinds[i], P.global_position + Vector3(sin(a) * 2.3, 0, cos(a) * 2.3)), "tick": func(i):
		P.inv = 1.0
		_park_buddy()
		if i == 1:
			P.start_attack(P.FINISH[3])
		P.auto_input = {}
		var a: float = 0.6 + i * 0.012
		_look(P.global_position + Vector3(sin(a) * 4.2, 2.7, cos(a) * 4.2), P.global_position + Vector3(0, 0.9, 0))})
	# X4 — ад-либ madk1d: волна оглушает толпу (болото)
	shots.append({"n": "X4_", "warm": 44, "len": 64, "own": true, "slow": 0.5, "setup": func():
		_stage(3)
		game.cam_yaw = 0.0
		var B = game.buddy
		B.global_position = P.global_position + Vector3(2.2, 0, -1.0)
		B.target = B.global_position
		B.wait = 9.0
		for i in 5:
			var a := -1.2 + i * 0.6
			game.spawn_enemy("troll" if i == 2 else "bot", B.global_position + Vector3(sin(a) * 3.2, 0, -cos(a) * 3.2)), "tick": func(i):
		var B = game.buddy
		P.inv = 1.0
		P.auto_input = {}
		B.wait = 9.0
		if i == 6:
			B.cd = 0.0
			B.adlib()
		_look(B.global_position + Vector3(0.9, 3.3 - i * 0.008, 4.4 - i * 0.012), B.global_position + Vector3(0, 0.7, -1.4))})
	var sets := [["bot", "bot", "bot", "hater"], ["bot", "bot", "clipper", "clipper", "clipper"], ["clipper", "clipper", "clipper", "hater", "hater"], ["troll", "troll", "hater", "hater", "clipper"],
		["lawyer", "lawyer", "mod", "mod", "clipper"], ["ghost", "ghost", "ghost", "troll"], ["farmer", "bot", "bot", "bot", "clipper", "clipper"], ["troll", "lawyer", "ghost", "clipper", "clipper"], ["bot", "bot", "ghost", "ghost", "clipper", "hater", "troll"]]
	var bosses := ["courier", "golem", "hype", "dislike", "major", "strike", "botlord", "ghostv", "algo"]
	for c in 9:
		var ch := c
		# D — бой главы: бот играет, обычная камера
		shots.append({"n": "D%d_" % (ch + 1), "warm": 52, "len": 44, "setup": func():
			_stage(ch)
			for k in sets[ch]:
				game.spawn_enemy(k, Vector3.INF)
			P.swag = 100.0 if ch % 2 == 1 else 55.0, "tick": func(_i):
			game.auto_t += 1.0 / 30.0
			game.bot_input(1.0 / 30.0)})
		# H — выход босса: камера снизу, наезд
		shots.append({"n": "H%d_" % (ch + 1), "warm": 30, "len": 40, "own": true, "setup": func():
			_stage(ch, false)
			P.global_position = Vector3(0, 0.05, 9)
			game.boss_e = game._make_enemy("", bosses[ch], Vector3(0, 0.05, -2)), "tick": func(i):
			var b = game.boss_e
			P.auto_input = {}
			_look(b.global_position + Vector3(1.1 - i * 0.01, 0.4, 3.9 - i * 0.022) * (b.height / 2.4), b.global_position + Vector3(0, b.height * 0.6, 0))})
		# I — бой с боссом
		shots.append({"n": "I%d_" % (ch + 1), "warm": 24, "len": 90 if ch == 8 else 40, "slow": 0.5 if ch == 8 else 1.0, "setup": func():
			P.global_position = Vector3(0, 0.05, 3)
			P.swag = 100.0, "tick": func(_i):
			game.auto_t += 1.0 / 30.0
			game.bot_input(1.0 / 30.0)})
	# проверочные планы боя (снимаются только по имени через --shots): камера сбоку, видно дугу балона и отклик врагов
	var tests := [["T1_", 110, {2: "attack", 14: "attack", 26: "attack", 38: "attack"}], ["T2_", 60, {2: "heavy"}], ["T3_", 70, {2: "attack", 13: "heavy"}], ["T4_", 100, {2: "attack", 14: "attack", 26: "attack", 38: "attack", 52: "heavy"}],
		# T5_ — без врагов: бег, поворот, остановка — видно, как балон волочится и отстаёт
		["T5_", 130, {1: {"move": Vector2(0, 1)}, 45: {"move": Vector2(1, 0)}, 80: {}}]]
	for tt in tests:
		var presses: Dictionary = tt[2]
		var empty: bool = tt[0] == "T5_"
		var hold := {"in": {}}
		shots.append({"n": tt[0], "test": true, "warm": 40, "len": tt[1], "own": true, "setup": func():
			_stage(0)
			game.cam_yaw = 0.0
			P.face = PI
			for x in ([] if empty else [-1.1, 0.0, 1.1]):
				game.spawn_enemy("bot", P.global_position + Vector3(x, 0, -2.3 - abs(x) * 0.2))
			hold["in"] = {}, "tick": func(i):
			P.inv = 1.0
			_park_buddy()
			var inp: Dictionary = {}
			if presses.has(i) and presses[i] is Dictionary:
				hold["in"] = presses[i]
			inp = (hold["in"] as Dictionary).duplicate()
			if presses.has(i) and presses[i] is String:
				inp[presses[i]] = "press"
			P.auto_input = inp
			if empty:
				_look(Vector3(5.5, 2.2, -1.0), P.global_position + Vector3(0, 0.7, 0))
			else:
				_look(P.global_position + Vector3(4.3, 1.5, -1.2), P.global_position + Vector3(0, 0.95, -1.3))})
	# --shots=A,X4_ — снять только названные планы
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			var want := arg.substr(8).split(",")
			shots = shots.filter(func(sh): return want.has(sh["n"]))
			return
	shots = shots.filter(func(sh): return not sh.has("test"))

func _stage(ch: int, reload := true) -> void:
	if reload or game.ch != ch:
		game.ch = ch
		game._load_chapter(false)
	else:
		game._clear_fight()
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	game.toast_t = 0.0
	var P = game.player
	P.hp = P.max_hp
	P.state = "move"
	P.swag = 0.0
	P.rage = 0.0
	P.auto_input = {}
	P.rig.play("Idle", 0.0)

func _park_buddy() -> void:
	var B = game.buddy
	B.global_position = game.player.global_position + Vector3(-2.6, 0, 3.2)
	B.target = B.global_position
	B.wait = 9.0

func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)

func _next() -> void:
	si += 1
	f = 0
	if si >= shots.size():
		print("TRAILER frames=%d" % saved)
		get_tree().quit()
		return
	var s: Dictionary = shots[si]
	slow = s.get("slow", 1.0)
	own = s.get("own", false)
	(s["setup"] as Callable).call()
	if own:
		cam.make_current()
	else:
		game.cam.make_current()

func owns_camera() -> bool:
	return own

func hide_hud() -> bool:
	return true

func frame(_dt: float) -> void:
	if si < 0:
		_next()   # первый план ставим после того, как игра запустила главу
	if si >= shots.size():
		return
	var s: Dictionary = shots[si]
	var P = game.player
	P.hp = P.max_hp
	if P.state == "dead":
		P.state = "move"
	var warm: int = s["warm"]
	# в кадре сейчас — картинка прошлого кадра: сохраняем её под прошлым номером
	if f > warm:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_jpg(out.path_join("%s%03d.jpg" % [s["n"], f - warm - 1]), 0.9)
		saved += 1
	if f >= warm + int(s["len"]) + 1:
		_next()
		return
	(s["tick"] as Callable).call(f - warm)
	f += 1
