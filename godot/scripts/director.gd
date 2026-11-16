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
		var a: float = 3.6 - i * 0.006
		_look(P.global_position + Vector3(sin(a) * (5.6 - i * 0.012), 1.25, cos(a) * (5.6 - i * 0.012)) + Vector3(-0.7, 0, 0), P.global_position + Vector3(-0.7, 1.15, 0))})
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
			var a := -1.2 + i * 0.48
			game.spawn_enemy("bot", P.global_position + Vector3(sin(a) * 3.0, 0, -cos(a) * 3.0)), "tick": func(i):
		P.swag = 100.0 if i < 50 else P.swag
		P.auto_input = {"rage": "press"} if i == 50 else {}
		_look(P.global_position + Vector3(1.6, 0.8, -4.6), P.global_position + Vector3(0, 1.2, -0.6))})
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
			_look(b.global_position + Vector3(1.4 - i * 0.012, 0.7, 5.6 - i * 0.03) * (b.height / 2.4), b.global_position + Vector3(0, b.height * 0.62, 0))})
		# I — бой с боссом
		shots.append({"n": "I%d_" % (ch + 1), "warm": 24, "len": 90 if ch == 8 else 40, "slow": 0.5 if ch == 8 else 1.0, "setup": func():
			P.global_position = Vector3(0, 0.05, 3)
			P.swag = 100.0, "tick": func(_i):
			game.auto_t += 1.0 / 30.0
			game.bot_input(1.0 / 30.0)})
	_next()

func _stage(ch: int, reload := true) -> void:
	if reload or game.ch != ch:
		game.ch = ch
		game._load_chapter(false)
	else:
		game._clear_fight()
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.toast_t = 0.0
	var P = game.player
	P.hp = P.max_hp
	P.state = "move"
	P.swag = 0.0
	P.rage = 0.0
	P.auto_input = {}
	P.rig.play("Idle", 0.0)

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
	if si < 0 or si >= shots.size():
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
