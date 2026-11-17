## madk1d с оружием в правой руке (скейтборд, гитара): махи, тычок, удар сверху, подброс, подсечка, вертушка,
## игра на гитаре, стойки на доске и трюки. Оружие закреплено в кулаке и идёт за рукой — позы заданы поворотами костей.
## Здесь же клипы, которых madk1d не хватало как играбельному герою: перекат, реакция на удар, гибель, ярость.
class_name MadkWeaponClips

static func add_to(A: Dictionary) -> void:
	var g := MadkClips.mg({})
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.45}}
	var sq := {"rup": {"x": -0.6}, "rleg": {"x": 0.95}, "lup": {"x": -0.6}, "lleg": {"x": 0.95}}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var rfw := {"rup": {"x": -0.55}, "rleg": {"x": 0.6}, "lup": {"x": 0.3}, "lleg": {"x": 0.2}}
	var T2 := {"two": 0.1}            # вторая рука на оружии: бьют всем оружием, двумя руками
	# оружие в покое: в правой руке у бедра, концом назад и чуть вниз (до земли не достаёт)
	var rest := Poses.W([-0.18, 0.36, 0.04], [-0.1, -0.4, -0.9])
	# через это положение (сбоку, концом наружу) оружие возвращается из удара вперёд в покой — не сквозь землю
	var side := Poses.W([-0.2, 0.37, 0.06], [-0.92, -0.3, 0.1])
	var hold: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": 0.1, "y": -0.12}, "larm": {"x": -0.7, "y": -0.2}, "lfa": {"x": -1.5}}))
	A["ArmedIdle"] = {"d": 1.2, "loop": true, "ground": true, "ease": "io", "k": [[0.0, hold, rest], [0.5, Poses.add(hold, {"spine": {"x": 0.03}, "rleg": {"x": 0.06}, "lleg": {"x": 0.06}}), rest], [1.0, hold, rest]]}
	# мах справа налево двумя руками, как битой: замах за правое плечо → дуга перед собой → довод влево
	A["MSwing1"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.26, Poses.mk(Poses.add(st, Poses.tw(-0.3, -0.42, -0.04))), Poses.W([-0.22, 0.48, -0.06], [-0.5, 0.5, -0.7], T2), "out"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.0, -0.2, 0.05))), Poses.W([-0.25, 0.45, 0.02], [-0.92, 0.2, -0.33], T2), "in"],
		[0.5, Poses.mk(Poses.add(lfw, Poses.tw(0.3, 0.3, 0.12))), Poses.W([-0.02, 0.44, 0.23], [0.3, 0.0, 0.95], T2), "lin"],
		[0.64, Poses.mk(Poses.add(lfw, Poses.tw(0.5, 0.38, 0.12))), Poses.W([0.16, 0.43, 0.14], [0.92, 0.0, 0.38], T2), "out2"],
		[1.0, hold, rest, "io"]]}
	# наотмашь слева направо
	A["MSwing2"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.26, Poses.mk(Poses.add(st, Poses.tw(0.3, 0.4, -0.04))), Poses.W([0.12, 0.48, 0.1], [0.6, 0.5, -0.62], T2), "out"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.0, 0.2, 0.05))), Poses.W([0.08, 0.46, 0.2], [0.92, 0.2, -0.1], T2), "in"],
		[0.5, Poses.mk(Poses.add(rfw, Poses.tw(-0.25, -0.3, 0.12))), Poses.W([-0.1, 0.44, 0.2], [-0.35, 0.0, 0.94], T2), "lin"],
		[0.64, Poses.mk(Poses.add(rfw, Poses.tw(-0.45, -0.38, 0.1))), Poses.W([-0.3, 0.44, 0.0], [-0.86, 0.05, -0.5], T2), "out2"],
		[1.0, hold, rest, "io"]]}
	# вертушка: оружие на вытянутой руке, тело крутит контроллер (spin атаки)
	A["MSpin"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold, rest],
		[0.2, Poses.mk(Poses.add(sq, Poses.add(Poses.tw(0.2, 0.3, 0.12), {"larm": {"z": 0.9}}))), Poses.W([-0.26, 0.4, 0.0], [-0.85, -0.2, -0.45]), "out"],
		[0.8, Poses.mk(Poses.add(st, Poses.add(Poses.tw(-0.1, -0.15, 0.05), {"spine": {"z": -0.12}, "larm": {"z": 1.0}}))), Poses.W([-0.32, 0.46, 0.02], [-0.92, 0.06, 0.38]), "lin"],
		[1.0, hold, rest, "io"]]}
	# удар сверху: оружие двумя руками над головой — и всей плоскостью вниз перед собой
	A["MOver"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.18, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.15))), Poses.W([-0.06, 0.48, 0.2], [0.0, 0.8, 0.6], T2), "io"],
		[0.36, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.28), {"lift": 0.04}))), Poses.W([-0.03, 0.66, 0.17], [0.0, 0.95, -0.3], T2), "out"],
		[0.55, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.02, 0.3, 0.25], [0.0, -0.35, 0.94], T2), "in"],
		[0.78, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.45))), Poses.W([-0.02, 0.31, 0.25], [0.0, -0.3, 0.95], T2), "out2"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# подброс: оружие от земли вверх с подшагом
	A["MUpper"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.3, Poses.mk(Poses.add(sq, Poses.tw(-0.3, -0.3, 0.3))), Poses.W([-0.22, 0.3, -0.02], [-0.45, -0.55, -0.7], T2), "out"],
		[0.42, Poses.mk(Poses.add(sq, Poses.tw(-0.1, -0.15, 0.25))), Poses.W([-0.18, 0.32, 0.12], [-0.4, -0.55, 0.73], T2), "in"],
		[0.5, Poses.mk(Poses.add(lfw, Poses.add(Poses.tw(0.2, 0.25, -0.12), {"lift": 0.04}))), Poses.W([-0.05, 0.56, 0.22], [0.12, 0.85, 0.5], T2), "lin"],
		[0.72, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.25, 0.3, -0.2), {"lift": 0.03}))), Poses.W([-0.1, 0.66, 0.16], [0.1, 0.97, -0.1], T2), "out2"],
		[1.0, hold, rest, "io"]]}
	# подсечка: присел, оружие у самой земли описывает круг (тело крутит spin)
	var low: Dictionary = Poses.mk({"spine": {"x": 0.5}, "rup": {"x": -1.0}, "rleg": {"x": 1.6}, "lup": {"x": -1.0}, "lleg": {"x": 1.6}, "larm": {"z": 0.8}})
	A["MSweep"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold, rest],
		[0.25, low, Poses.W([-0.24, 0.2, 0.0], [-0.92, -0.2, -0.3]), "out"], [0.75, low, Poses.W([-0.28, 0.17, 0.06], [-0.95, -0.12, 0.28]), "lin"], [1.0, hold, rest, "io"]]}
	# тычок: оружие отведено к бедру — выпад и удар торцом вперёд
	A["MThrust"] = {"d": 1.0, "ground": true, "n": 48, "k": [[0.0, hold, rest],
		[0.14, hold, side, "io"],
		[0.3, Poses.mk(Poses.add(st, Poses.tw(-0.3, -0.35, 0.05))), Poses.W([-0.16, 0.4, -0.04], [0.05, 0.08, 0.99], T2), "out"],
		[0.48, Poses.mk(Poses.add(lfw, Poses.tw(0.25, 0.3, 0.25))), Poses.W([-0.06, 0.42, 0.3], [0.0, 0.05, 1.0], T2), "in"],
		[0.68, Poses.mk(Poses.add(lfw, Poses.tw(0.22, 0.26, 0.22))), Poses.W([-0.06, 0.42, 0.28], [0.0, 0.05, 1.0], T2), "out2"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# игра: гитара поднята грифом вверх перед собой, левая рука бьёт по струнам, корпус качается
	var up := Poses.W([-0.1, 0.46, 0.16], [0.25, 0.9, 0.35])
	var play: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": -0.1}, "head": {"x": -0.15}, "larm": {"x": -0.9, "y": -0.5}, "lfa": {"x": -1.3}}))
	A["MStrum"] = {"d": 1.0, "ground": true, "k": [[0.0, hold, rest], [0.25, play, up, "out"], [0.4, Poses.add(play, {"lfa": {"x": 0.6}, "spine": {"x": 0.25}, "head": {"x": 0.3}}), up, "in"],
		[0.65, Poses.add(play, {"lfa": {"x": 0.4}, "spine": {"x": 0.18}}), up, "out2"], [1.0, hold, rest, "io"]]}
	A["MStrumHold"] = {"d": 0.4, "loop": true, "ground": true, "k": [[0.0, play, up], [0.5, Poses.add(play, {"lfa": {"x": 0.4}, "head": {"x": 0.1}}), up], [1.0, play, up]]}
	# финал: прыжок, оружие двумя руками над головой — и в землю
	var tuck_j := {"rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.3}, "lleg": {"x": 0.8}}
	A["MFinal"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, rest],
		[0.3, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.12}))), Poses.W([-0.03, 0.74, 0.14], [0.0, 0.95, -0.3], T2), "out"],
		[0.5, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.32), {"lift": 0.1}))), Poses.W([-0.03, 0.73, 0.13], [0.0, 0.93, -0.36], T2), "lin"],
		[0.62, Poses.mk({"spine": {"x": 0.65}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}), Poses.W([-0.02, 0.27, 0.26], [0.0, -0.4, 0.92], T2), "in"],
		[0.85, Poses.mk({"spine": {"x": 0.6}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}), Poses.W([-0.02, 0.28, 0.26], [0.0, -0.36, 0.93], T2), "io"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# ---------- на доске ----------
	# Риг на доске развёрнут боком к движению (skate.gd): левое плечо вперёд, ноги вдоль деки — передняя у носа,
	# задняя у хвоста; колени согнуты, голова смотрит по ходу, руки разведены для равновесия.
	var ride := {"drop": 0.1, "spine": {"x": 0.22}, "head": {"y": 1.1, "x": -0.1}, "lup": {"z": 0.4, "x": -0.3}, "lleg": {"x": 0.65}, "rup": {"z": -0.4, "x": -0.3}, "rleg": {"x": 0.65},
		"larm": {"z": 0.75}, "rarm": {"z": -0.75}}
	var rd: Dictionary = Poses.mk(ride)
	A["SkateRide"] = {"d": 0.8, "loop": true, "ease": "io", "k": [[0.0, rd], [0.5, Poses.add(rd, {"rleg": {"x": 0.08}, "lleg": {"x": 0.08}, "drop": 0.115, "spine": {"x": 0.03}})], [1.0, rd]]}
	# олли: присел — и ноги поджаты, руки вверх
	A["SkateOllie"] = {"d": 1.0, "k": [[0.0, Poses.mk(Poses.add(ride, {"drop": 0.2, "lleg": {"x": 0.4}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "rup": {"x": -0.3}}))],
		[0.3, Poses.mk(Poses.add(ride, {"drop": 0.02, "lup": {"x": -0.6}, "rup": {"x": -0.6}, "lleg": {"x": 0.7}, "rleg": {"x": 0.7}, "larm": {"z": 0.5}, "rarm": {"z": -0.5}})), "out"], [1.0, rd, "io"]]}
	# трюк: ноги подобраны и разведены — доска крутится под ними
	A["SkateTrick"] = {"d": 1.0, "k": [[0.0, rd], [0.3, Poses.mk(Poses.add(ride, {"drop": 0.0, "lup": {"x": -0.75, "z": 0.2}, "rup": {"x": -0.75, "z": -0.2}, "lleg": {"x": 0.8}, "rleg": {"x": 0.8}, "larm": {"z": 0.6}, "rarm": {"z": -0.6}})), "out"],
		[0.75, Poses.mk(Poses.add(ride, {"drop": 0.0, "lup": {"x": -0.7, "z": 0.18}, "rup": {"x": -0.7, "z": -0.18}, "lleg": {"x": 0.8}, "rleg": {"x": 0.8}, "larm": {"z": 0.5}, "rarm": {"z": -0.5}})), "lin"], [1.0, rd, "in"]]}
	# слайд: низко, корпус откинут от движения, задняя рука почти у земли
	var sl: Dictionary = Poses.mk(Poses.add(ride, {"drop": 0.2, "spine": {"z": 0.35, "x": 0.05}, "lleg": {"x": -0.2}, "lup": {"z": 0.2}, "rleg": {"x": 0.4}, "rarm": {"z": 0.55}, "larm": {"z": 0.3}}))
	A["SkateSlide"] = {"d": 0.4, "loop": true, "k": [[0.0, sl], [0.5, Poses.add(sl, {"spine": {"x": 0.03}})], [1.0, sl]]}
	# удар в воздухе: передняя нога с доской выбрасывается по ходу, задняя поджата
	A["SkateAir"] = {"d": 1.0, "k": [[0.0, rd], [0.35, Poses.mk(Poses.add(ride, {"drop": 0.0, "spine": {"z": 0.3}, "lup": {"z": 0.95, "x": 0.2}, "lleg": {"x": -0.55}, "rup": {"x": -0.6}, "rleg": {"x": 0.9}, "rarm": {"z": -0.3}})), "in"],
		[0.7, Poses.mk(Poses.add(ride, {"drop": 0.0, "spine": {"z": 0.25}, "lup": {"z": 0.85, "x": 0.2}, "lleg": {"x": -0.5}, "rup": {"x": -0.6}, "rleg": {"x": 0.9}})), "out2"], [1.0, rd, "io"]]}
	# пикирование: сжался на доске, руки назад
	var dive: Dictionary = Poses.mk(Poses.add(ride, {"drop": 0.22, "spine": {"x": 0.3}, "lup": {"x": -0.5}, "rup": {"x": -0.5}, "lleg": {"x": 0.7}, "rleg": {"x": 0.7}, "larm": {"z": -0.4, "x": 0.5}, "rarm": {"z": 0.4, "x": 0.5}}))
	A["SkateDive"] = {"d": 0.4, "loop": true, "k": [[0.0, dive], [1.0, dive]]}
	# ---------- чего не хватало герою под управлением игрока ----------
	var tuck: Dictionary = Poses.mk({"spine": {"x": 0.45}, "spine2": {"x": 0.3}, "head": {"x": 0.35}, "lup": {"x": -1.7}, "rup": {"x": -1.7}, "lleg": {"x": 2.1}, "rleg": {"x": 2.1}, "larm": {"x": -0.9}, "rarm": {"x": -0.9}, "lfa": {"x": -1.4}, "rfa": {"x": -1.4}})
	A["Tuck"] = {"d": 1.0, "loop": true, "k": [[0.0, tuck], [1.0, tuck]]}
	for nm in ["Hit", "HitBack", "HitL", "HitR"]:
		if not A.has(nm):
			A[nm] = A["Stagger"]
	A["Death"] = {"d": 1.0, "k": [[0.0, g], [0.25, Poses.mk({"hips": {"x": -0.45}, "spine": {"x": -0.25}, "rarm": {"z": -0.7}, "larm": {"z": 0.7}, "rleg": {"x": 0.4}, "lleg": {"x": 0.4}, "drop": 0.18})],
		[0.6, Poses.mk({"hips": {"x": -1.45}, "rarm": {"z": -0.9}, "larm": {"z": 0.9}, "drop": 0.78})], [1.0, Poses._down(Callable(Poses, "mk"))]]}
	A["Rage"] = A["Cheer"]
	A["Charge"] = A["MStrumHold"]
