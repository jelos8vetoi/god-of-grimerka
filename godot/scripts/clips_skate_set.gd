## madk1d со скейтбордом — полный набор: пять лёгких ударов (хвостом, носом, ногой и доской, доска вокруг себя,
## удар сверху), трюковые удары на ногах (KICKFLIP, SHOVE-IT, OLLIE), удары в воздухе, и езда: толчок ногой,
## торможение хвостом, посадка и приземление. Доска в правой руке у хвоста (Poses.W), на ударах двумя руками — T2.
class_name SkateSet

static func add_to(A: Dictionary) -> void:
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.45}}
	var sq := {"rup": {"x": -0.6}, "rleg": {"x": 0.95}, "lup": {"x": -0.6}, "lleg": {"x": 0.95}}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var rfw := {"rup": {"x": -0.55}, "rleg": {"x": 0.6}, "lup": {"x": 0.3}, "lleg": {"x": 0.2}}
	var T2 := {"two": 0.1}
	var rest := Poses.W([-0.2, 0.33, 0.14], [0.8, 0.45, 0.4], {"two": 0.22})      # доска тяжёлая: двумя руками наискось перед корпусом — правая у хвоста, левая выше по деке
	var side := Poses.W([-0.2, 0.37, 0.06], [-0.92, -0.3, 0.1])
	var hold: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": 0.1, "y": -0.12}, "larm": {"x": -0.7, "y": -0.2}, "lfa": {"x": -1.5}}))
	# шаг, бег, рывок с доской в руках: ноги — как обычно, доску несут двумя руками у корпуса (на бегу ниже и ближе)
	for row in [["Walk", "SkWalk", [-0.2, 0.33, 0.14], [0.8, 0.45, 0.4]], ["Run", "SkRun", [-0.2, 0.32, 0.13], [0.82, 0.4, 0.42]], ["Sprint", "SkSprint", [-0.2, 0.31, 0.13], [0.84, 0.34, 0.44]]]:
		if not A.has(row[0]):
			continue
		var c: Dictionary = (A[row[0]] as Dictionary).duplicate(true)
		var n := 0
		for kf in c["k"]:
			var bob: float = 0.008 * sin(float(n) / 8.0 * TAU * 2.0)
			var gp: Array = row[2]
			var ik := Poses.W([gp[0], gp[1] + bob, gp[2]], row[3], {"two": 0.22})
			if (kf as Array).size() <= 2:
				(kf as Array).append(ik)
			else:
				(kf as Array).insert(2, ik)
			n += 1
		A[row[1]] = c
	# ---------- пять лёгких ----------
	# хвостом: короткий рубящий сверху-справа вниз-влево
	A["SkTail"] = {"d": 1.0, "ground": true, "n": 48, "k": [[0.0, hold, rest],
		[0.28, Poses.mk(Poses.add(st, Poses.tw(-0.25, -0.35, -0.05))), Poses.W([-0.2, 0.54, 0.0], [-0.3, 0.85, -0.42], T2), "out"],
		[0.5, Poses.mk(Poses.add(lfw, Poses.tw(0.25, 0.3, 0.16))), Poses.W([-0.02, 0.4, 0.26], [0.35, -0.25, 0.9], T2), "in"],
		[0.66, Poses.mk(Poses.add(lfw, Poses.tw(0.4, 0.36, 0.2))), Poses.W([0.14, 0.34, 0.16], [0.8, -0.45, 0.4], T2), "out2"],
		[1.0, hold, rest, "io"]]}
	# носом: наотмашь одной рукой слева направо
	A["SkNose"] = {"d": 1.0, "ground": true, "n": 48, "k": [[0.0, hold, rest],
		[0.28, Poses.mk(Poses.add(st, Poses.tw(0.3, 0.42, -0.04))), Poses.W([0.14, 0.46, 0.12], [0.7, 0.3, -0.65]), "out"],
		[0.5, Poses.mk(Poses.add(rfw, Poses.add(Poses.tw(-0.25, -0.32, 0.1), {"larm": {"z": 0.7}}))), Poses.W([-0.12, 0.45, 0.24], [-0.45, 0.05, 0.9]), "in"],
		[0.66, Poses.mk(Poses.add(rfw, Poses.add(Poses.tw(-0.45, -0.4, 0.08), {"larm": {"z": 0.8}}))), Poses.W([-0.32, 0.46, 0.02], [-0.9, 0.1, -0.4]), "out2"],
		[1.0, hold, rest, "io"]]}
	# ногой и доской: прямой удар правой ногой, доска отведена — и следом тычок доской двумя руками
	A["SkKickPush"] = {"d": 1.0, "ground": true, "n": 56, "ev": {"hit": [0.28, 0.56]}, "k": [[0.0, hold, rest],
		[0.08, hold, Poses.W([-0.22, 0.41, 0.05], [-0.1, 0.92, -0.05]), "io"],      # доска уходит назад через верх: без переворота кисти
		[0.16, Poses.mk(Poses.add(st, {"spine": {"x": -0.1}, "rup": {"x": -1.2}, "rleg": {"x": 1.5}})), Poses.W([-0.24, 0.42, -0.06], [-0.6, 0.3, -0.74]), "out"],
		[0.28, Poses.mk(Poses.add(st, {"spine": {"x": -0.28}, "rup": {"x": -1.5}, "rleg": {"x": 0.1}, "lleg": {"x": 0.25}})), Poses.W([-0.26, 0.42, -0.1], [-0.6, 0.3, -0.74]), "in"],
		[0.42, Poses.mk(Poses.add(rfw, Poses.tw(-0.2, -0.25, 0.1))), Poses.W([-0.16, 0.42, 0.0], [0.0, 0.08, 1.0], T2), "out"],
		[0.56, Poses.mk(Poses.add(rfw, Poses.tw(0.1, 0.2, 0.3))), Poses.W([-0.04, 0.43, 0.32], [0.0, 0.05, 1.0], T2), "in"],
		[0.74, Poses.mk(Poses.add(rfw, Poses.tw(0.08, 0.16, 0.26))), Poses.W([-0.04, 0.43, 0.3], [0.0, 0.05, 1.0], T2), "out2"],
		[1.0, hold, rest, "io"]]}
	# доска вокруг себя: над головой полный круг одной рукой
	A["SkBoardSpin"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.18, Poses.mk(Poses.add(sq, Poses.tw(-0.2, -0.25, 0.1))), Poses.W([-0.2, 0.6, 0.0], [-0.9, 0.2, -0.38]), "out"],
		[0.36, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.08), {"larm": {"z": 0.9}}))), Poses.W([-0.04, 0.68, 0.12], [-0.1, 0.12, 0.99]), "lin"],
		[0.54, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.2, 0.25, -0.08), {"larm": {"z": 0.9}}))), Poses.W([0.14, 0.68, 0.02], [0.94, 0.12, 0.32]), "lin"],
		[0.72, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.1, 0.1, -0.06), {"larm": {"z": 0.7}}))), Poses.W([-0.02, 0.68, -0.1], [0.2, 0.12, -0.97]), "lin"],
		[0.86, Poses.mk(Poses.add(st, Poses.tw(-0.15, -0.2, 0.0))), Poses.W([-0.2, 0.56, -0.02], [-0.92, 0.0, -0.4]), "out"],
		[1.0, hold, rest, "io"]]}
	# удар сверху с подскока: доска двумя руками над головой — и плашмя вниз
	var tuck_j := {"rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.3}, "lleg": {"x": 0.8}}
	var crouch: Dictionary = Poses.mk({"spine": {"x": 0.6}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}})
	A["SkSlam"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.26, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.28), {"lift": 0.09}))), Poses.W([-0.03, 0.72, 0.14], [0.0, 0.95, -0.3], T2), "out"],
		[0.44, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.08}))), Poses.W([-0.03, 0.71, 0.13], [0.0, 0.93, -0.36], T2), "lin"],
		[0.56, crouch, Poses.W([-0.02, 0.27, 0.26], [0.0, -0.4, 0.92], T2), "in"],
		[0.8, crouch, Poses.W([-0.02, 0.28, 0.26], [0.0, -0.36, 0.93], T2), "io"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# ---------- трюковые удары на ногах ----------
	# KICKFLIP: доска идёт полным кругом в вертикальной плоскости перед собой — снизу вверх и сверху в цель
	A["SkFlipStrike"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.2, Poses.mk(Poses.add(sq, Poses.tw(-0.1, -0.15, 0.25))), Poses.W([-0.14, 0.3, 0.16], [-0.2, -0.78, 0.6]), "out"],
		[0.34, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.1), {"lift": 0.03}))), Poses.W([-0.12, 0.5, 0.26], [-0.2, 0.48, 0.86]), "lin"],
		[0.46, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.2), {"lift": 0.05}))), Poses.W([-0.1, 0.66, 0.14], [-0.2, 0.94, -0.28]), "lin"],
		[0.52, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.08, 0.1, 0.05), {"lift": 0.03}))), Poses.W([-0.08, 0.6, 0.24], [-0.18, 0.6, 0.78]), "lin"],
		[0.58, Poses.mk(Poses.add(lfw, Poses.tw(0.15, 0.2, 0.3))), Poses.W([-0.06, 0.4, 0.28], [-0.15, -0.5, 0.85]), "lin"],
		[0.76, Poses.mk(Poses.add(lfw, Poses.tw(0.12, 0.16, 0.26))), Poses.W([-0.06, 0.4, 0.27], [-0.15, -0.45, 0.88]), "out2"],
		[1.0, hold, rest, "io"]]}
	# SHOVE-IT: присел, доска у самой земли описывает круг по ногам (тело крутит spin атаки)
	var low: Dictionary = Poses.mk({"spine": {"x": 0.5}, "rup": {"x": -1.0}, "rleg": {"x": 1.6}, "lup": {"x": -1.0}, "lleg": {"x": 1.6}, "larm": {"z": 0.8}})
	A["SkShove"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold, rest],
		[0.22, low, Poses.W([-0.26, 0.19, 0.02], [-0.95, -0.15, -0.28]), "out"],
		[0.5, Poses.add(low, {"spine": {"y": 0.2}}), Poses.W([-0.3, 0.16, 0.08], [-0.97, -0.1, 0.2]), "lin"],
		[0.78, low, Poses.W([-0.26, 0.18, 0.04], [-0.9, -0.14, 0.42]), "lin"],
		[1.0, hold, rest, "io"]]}
	# OLLIE: подпрыгнул с доской под ногами (доска прижата к подошвам) и вбил её в землю
	A["SkOllieStomp"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.2, Poses.mk(Poses.add(sq, {"spine": {"x": 0.3}})), Poses.W([-0.1, 0.2, 0.14], [0.6, -0.05, 0.8]), "out"],
		[0.42, Poses.mk({"lift": 0.2, "spine": {"x": 0.25}, "rup": {"x": -1.3}, "rleg": {"x": 1.7}, "lup": {"x": -1.3}, "lleg": {"x": 1.7}, "larm": {"z": 0.9}}), Poses.W([-0.08, 0.3, 0.12], [0.75, -0.05, 0.66]), "out"],
		[0.58, Poses.mk(Poses.add(sq, {"drop": 0.06, "spine": {"x": 0.45}})), Poses.W([-0.1, 0.14, 0.16], [0.7, -0.06, 0.71]), "in"],
		[0.8, Poses.mk(Poses.add(sq, {"spine": {"x": 0.35}})), Poses.W([-0.1, 0.16, 0.16], [0.7, -0.04, 0.71]), "io"],
		[1.0, hold, rest, "io"]]}
	# ---------- в воздухе ----------
	# удар в прыжке: доска сбоку-сверху по дуге вперёд
	var air: Dictionary = Poses.mk({"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.3}, "lleg": {"x": 0.7}})
	A["SkAirStrike"] = {"d": 1.0, "n": 40, "k": [[0.0, air, rest],
		[0.3, Poses.mk(Poses.add({"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.3}, "lleg": {"x": 0.7}}, Poses.tw(-0.3, -0.4, -0.1))), Poses.W([-0.22, 0.58, -0.04], [-0.55, 0.6, -0.58], T2), "out"],
		[0.5, Poses.mk(Poses.add({"rup": {"x": -0.4}, "rleg": {"x": 0.8}, "lup": {"x": -0.7}, "lleg": {"x": 1.0}}, Poses.tw(0.3, 0.35, 0.2))), Poses.W([-0.02, 0.44, 0.26], [0.3, -0.1, 0.95], T2), "in"],
		[0.7, Poses.mk(Poses.add({"rup": {"x": -0.4}, "rleg": {"x": 0.8}, "lup": {"x": -0.7}, "lleg": {"x": 1.0}}, Poses.tw(0.45, 0.4, 0.2))), Poses.W([0.16, 0.4, 0.14], [0.9, -0.2, 0.38], T2), "out2"],
		[1.0, air, rest, "io"]]}
	# удар доской сверху вниз из прыжка
	A["SkAirSlam"] = {"d": 1.0, "n": 40, "k": [[0.0, air, rest],
		[0.35, Poses.mk(Poses.add({"rup": {"x": -0.9}, "rleg": {"x": 1.4}, "lup": {"x": -0.9}, "lleg": {"x": 1.4}}, Poses.tw(0.0, 0.0, -0.35))), Poses.W([-0.03, 0.72, 0.1], [0.0, 0.9, -0.44], T2), "out"],
		[0.55, Poses.mk(Poses.add({"rup": {"x": -0.5}, "rleg": {"x": 0.6}, "lup": {"x": -0.5}, "lleg": {"x": 0.6}}, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.02, 0.28, 0.26], [0.0, -0.5, 0.87], T2), "in"],
		[1.0, crouch, Poses.W([-0.02, 0.27, 0.26], [0.0, -0.4, 0.92], T2), "io"]]}
	# ---------- езда ----------
	var ride := {"drop": 0.1, "spine": {"x": 0.22}, "head": {"y": 1.1, "x": -0.1}, "lup": {"z": 0.4, "x": -0.3}, "lleg": {"x": 0.65}, "rup": {"z": -0.4, "x": -0.3}, "rleg": {"x": 0.65},
		"larm": {"z": 0.75}, "rarm": {"z": -0.75}}
	var rd: Dictionary = Poses.mk(ride)
	# толчок: задняя (правая) нога сходит с доски, отталкивается от земли и возвращается
	A["SkatePush"] = {"d": 0.62, "loop": true, "k": [[0.0, rd],
		[0.25, Poses.mk(Poses.add(ride, {"drop": 0.16, "spine": {"x": 0.34}, "rup": {"z": -0.1, "x": -0.75}, "rleg": {"x": 0.5}, "lleg": {"x": 0.85}, "rarm": {"z": -0.4, "x": 0.5}})), "out"],
		[0.55, Poses.mk(Poses.add(ride, {"drop": 0.14, "spine": {"x": 0.38}, "rup": {"z": -0.1, "x": 0.75}, "rleg": {"x": 0.35}, "lleg": {"x": 0.8}, "rarm": {"z": -0.4, "x": -0.6}})), "in"],
		[0.8, Poses.mk(Poses.add(ride, {"drop": 0.1, "spine": {"x": 0.28}, "rup": {"z": -0.3, "x": -0.1}, "rleg": {"x": 1.1}})), "out"],
		[1.0, rd, "io"]]}
	# торможение: вес на хвост, нос задран, корпус откинут назад
	var brk: Dictionary = Poses.mk(Poses.add(ride, {"drop": 0.14, "spine": {"x": -0.05, "z": -0.3}, "rleg": {"x": 0.95}, "lleg": {"x": 0.15}, "lup": {"z": 0.55}, "larm": {"z": 1.0}, "rarm": {"z": -0.4}}))
	A["SkateBrake"] = {"d": 0.3, "loop": true, "k": [[0.0, brk], [0.5, Poses.add(brk, {"spine": {"x": 0.03}})], [1.0, brk]]}
	# посадка: шаг-подскок на доску, присел, выпрямился в стойку
	A["SkateMount"] = {"d": 1.0, "k": [[0.0, Poses.mk(Poses.add(st, {"spine": {"x": 0.2}, "head": {"y": 0.5}, "lift": 0.04, "lup": {"x": -0.8}, "lleg": {"x": 0.9}}))],
		[0.45, Poses.mk(Poses.add(ride, {"drop": 0.2, "spine": {"x": 0.35}, "lleg": {"x": 0.3}, "rleg": {"x": 0.3}})), "in"], [1.0, rd, "out"]]}
	# приземление: глубоко присел, руки в стороны — и поднялся
	A["SkateLand"] = {"d": 1.0, "k": [[0.0, Poses.mk(Poses.add(ride, {"drop": 0.24, "spine": {"x": 0.42}, "lleg": {"x": 0.45}, "rleg": {"x": 0.45}, "lup": {"x": -0.45}, "rup": {"x": -0.45}, "larm": {"z": 1.0}, "rarm": {"z": -1.0}}))],
		[0.5, Poses.mk(Poses.add(ride, {"drop": 0.15, "spine": {"x": 0.3}})), "out"], [1.0, rd, "io"]]}
