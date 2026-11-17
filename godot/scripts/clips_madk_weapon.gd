## madk1d с оружием в правой руке (скейтборд, гитара): махи, тычок, удар сверху, подброс, подсечка, вертушка,
## игра на гитаре, стойки на доске и трюки. Оружие закреплено в кулаке и идёт за рукой — позы заданы поворотами костей.
## Здесь же клипы, которых madk1d не хватало как играбельному герою: перекат, реакция на удар, гибель, ярость.
class_name MadkWeaponClips

static func add_to(A: Dictionary) -> void:
	var g := MadkClips.mg({})
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.45}}
	var sq := {"rup": {"x": -0.6}, "rleg": {"x": 0.95}, "lup": {"x": -0.6}, "lleg": {"x": 0.95}}
	# стойка с оружием: правая рука чуть отведена, левая у груди
	var hold: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": 0.1, "y": -0.12}, "rarm": {"x": -0.25, "z": -0.2}, "rfa": {"x": -0.7}, "larm": {"x": -0.7, "y": -0.2}, "lfa": {"x": -1.5}}))
	A["ArmedIdle"] = {"d": 1.2, "loop": true, "ground": true, "ease": "io", "k": [[0.0, hold], [0.5, Poses.add(hold, {"spine": {"x": 0.03}, "rleg": {"x": 0.06}, "lleg": {"x": 0.06}})], [1.0, hold]]}
	# мах справа налево
	A["MSwing1"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold],
		[0.28, Poses.mk(Poses.add(st, {"hips": {"y": -0.3}, "spine": {"y": -0.55}, "head": {"y": 0.5}, "rarm": {"z": -1.05, "y": -0.8}, "rfa": {"x": -0.5}, "larm": {"x": -0.8}})), "out"],
		[0.5, Poses.mk(Poses.add(st, {"hips": {"y": 0.3}, "spine": {"y": 0.6, "x": 0.15}, "head": {"y": -0.5}, "rarm": {"z": -1.05, "y": 1.2}, "rfa": {"x": 0.1}, "lup": {"x": -0.5}, "lleg": {"x": 0.5}})), "in"],
		[0.7, Poses.mk(Poses.add(st, {"hips": {"y": 0.35}, "spine": {"y": 0.7, "x": 0.15}, "rarm": {"z": -0.8, "y": 1.6}})), "out2"], [1.0, hold, "io"]]}
	# наотмашь слева направо
	A["MSwing2"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold],
		[0.28, Poses.mk(Poses.add(st, {"hips": {"y": 0.3}, "spine": {"y": 0.6}, "head": {"y": -0.5}, "rarm": {"z": -1.0, "y": 1.6}, "rfa": {"x": -0.4}})), "out"],
		[0.5, Poses.mk(Poses.add(st, {"hips": {"y": -0.3}, "spine": {"y": -0.55, "x": 0.15}, "head": {"y": 0.5}, "rarm": {"z": -1.05, "y": -0.6}, "rfa": {"x": 0.1}, "rup": {"x": -0.5}, "rleg": {"x": 0.5}})), "in"],
		[0.7, Poses.mk(Poses.add(st, {"hips": {"y": -0.35}, "spine": {"y": -0.65}, "rarm": {"z": -0.9, "y": -0.9}})), "out2"], [1.0, hold, "io"]]}
	# вертушка: оружие на вытянутой руке, тело крутит контроллер (spin атаки)
	A["MSpin"] = {"d": 1.0, "ground": true, "k": [[0.0, hold], [0.2, Poses.mk(Poses.add(sq, {"spine": {"y": -0.3}, "rarm": {"z": -1.1, "y": -0.4}, "larm": {"z": 0.9}})), "out"],
		[0.8, Poses.mk(Poses.add(st, {"spine": {"z": -0.12}, "rarm": {"z": -1.15, "y": 0.5}, "rfa": {"x": 0.1}, "larm": {"z": 1.0}})), "lin"], [1.0, hold, "io"]]}
	# удар сверху: оружие за голову — и вниз перед собой
	A["MOver"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold],
		[0.35, Poses.mk(Poses.add(st, {"lift": 0.03, "spine": {"x": -0.3}, "head": {"x": -0.2}, "rarm": {"x": -2.8}, "rfa": {"x": -1.0}, "larm": {"x": -2.5}, "lfa": {"x": -0.8}})), "out"],
		[0.55, Poses.mk(Poses.add(sq, {"spine": {"x": 0.55}, "rarm": {"x": -0.9}, "rfa": {"x": 0.1}, "larm": {"x": -0.8}})), "in"],
		[0.78, Poses.mk(Poses.add(sq, {"spine": {"x": 0.5}, "rarm": {"x": -0.8}, "larm": {"x": -0.7}})), "out2"], [1.0, hold, "io"]]}
	# подброс: снизу вверх с приседа
	A["MUpper"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold],
		[0.3, Poses.mk(Poses.add(sq, {"spine": {"x": 0.3, "y": -0.35}, "rarm": {"x": 0.6}, "rfa": {"x": -0.2}})), "out"],
		[0.5, Poses.mk(Poses.add(st, {"lift": 0.05, "spine": {"x": -0.25, "y": 0.3}, "head": {"x": -0.2}, "rarm": {"x": -2.3, "z": -0.2}, "rfa": {"x": 0.1}})), "in"],
		[0.72, Poses.mk(Poses.add(st, {"lift": 0.03, "spine": {"x": -0.2, "y": 0.3}, "rarm": {"x": -2.4, "z": -0.2}})), "out2"], [1.0, hold, "io"]]}
	# подсечка: низко, оружие у самой земли по кругу
	A["MSweep"] = {"d": 1.0, "ground": true, "k": [[0.0, hold], [0.25, Poses.mk(Poses.add(sq, {"spine": {"x": 0.45, "y": -0.4}, "rarm": {"z": -0.3, "y": -0.6}, "rfa": {"x": 0.2}})), "out"],
		[0.75, Poses.mk({"spine": {"x": 0.5}, "rup": {"x": -1.0}, "rleg": {"x": 1.6}, "lup": {"x": -1.0}, "lleg": {"x": 1.6}, "rarm": {"z": -0.35, "y": 0.6}, "rfa": {"x": 0.2}, "larm": {"z": 0.8}}), "lin"], [1.0, hold, "io"]]}
	# тычок: выпад вперёд, оружие остриём (грифом)
	A["MThrust"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold], [0.3, Poses.mk(Poses.add(st, {"spine": {"y": -0.4}, "rarm": {"x": 0.3, "y": -0.5}, "rfa": {"x": -1.3}})), "out"],
		[0.48, Poses.mk(Poses.add(st, {"spine": {"y": 0.4, "x": 0.25}, "rarm": {"x": -1.5}, "rfa": {"x": 0.1}, "lup": {"x": -0.6}, "lleg": {"x": 0.5}, "rup": {"x": 0.3}})), "in"],
		[0.68, Poses.mk(Poses.add(st, {"spine": {"y": 0.35, "x": 0.22}, "rarm": {"x": -1.45}, "lup": {"x": -0.55}, "lleg": {"x": 0.5}})), "out2"], [1.0, hold, "io"]]}
	# игра: гитара поперёк корпуса, правая рука бьёт по струнам
	var play: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": -0.08}, "head": {"x": -0.15}, "rarm": {"x": -0.5, "y": 0.9, "z": -0.3}, "rfa": {"x": -1.2}, "larm": {"x": -0.9, "y": -0.5}, "lfa": {"x": -1.3}}))
	A["MStrum"] = {"d": 1.0, "ground": true, "k": [[0.0, hold], [0.25, play, "out"], [0.4, Poses.add(play, {"rfa": {"x": 0.5}, "spine": {"x": 0.2}, "head": {"x": 0.3}}), "in"],
		[0.65, Poses.add(play, {"rfa": {"x": 0.4}, "spine": {"x": 0.15}}), "out2"], [1.0, hold, "io"]]}
	A["MStrumHold"] = {"d": 0.4, "loop": true, "ground": true, "k": [[0.0, play], [0.5, Poses.add(play, {"rfa": {"x": 0.3}, "head": {"x": 0.1}})], [1.0, play]]}
	# оружие вверх над головой и удар в землю с прыжка (финал)
	A["MFinal"] = {"d": 1.0, "ground": true, "n": 48, "k": [[0.0, hold],
		[0.3, Poses.mk(Poses.add(st, {"lift": 0.12, "spine": {"x": -0.3}, "head": {"x": -0.3}, "rarm": {"x": -2.9}, "larm": {"x": -2.9}, "rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.3}, "lleg": {"x": 0.8}})), "out"],
		[0.5, Poses.mk(Poses.add(st, {"lift": 0.1, "spine": {"x": -0.3}, "rarm": {"x": -2.9}, "larm": {"x": -2.9}, "rup": {"x": -0.6}, "rleg": {"x": 1.0}})), "lin"],
		[0.62, Poses.mk({"spine": {"x": 0.65}, "rarm": {"x": -0.8}, "larm": {"x": -0.8}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}), "in"],
		[0.85, Poses.mk({"spine": {"x": 0.6}, "rarm": {"x": -0.8}, "larm": {"x": -0.8}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}), "io"], [1.0, hold, "io"]]}
	# ---------- на доске: боком, колени согнуты, руки для равновесия ----------
	var ride := {"hips": {"y": 0.9}, "spine": {"y": -0.5, "x": 0.15}, "head": {"y": -0.45}, "rup": {"x": -0.45, "z": -0.2}, "rleg": {"x": 0.75}, "lup": {"x": -0.45, "z": 0.25}, "lleg": {"x": 0.75},
		"rarm": {"z": -0.5}, "larm": {"z": 0.6}}
	var rd: Dictionary = Poses.mk(ride)
	A["SkateRide"] = {"d": 0.8, "loop": true, "ease": "io", "k": [[0.0, rd], [0.5, Poses.add(rd, {"rleg": {"x": 0.1}, "lleg": {"x": 0.1}, "spine": {"x": 0.04}})], [1.0, rd]]}
	A["SkateOllie"] = {"d": 1.0, "k": [[0.0, Poses.mk(Poses.add(ride, {"rleg": {"x": 0.5}, "lleg": {"x": 0.5}, "rup": {"x": -0.4}, "lup": {"x": -0.4}}))],
		[0.3, Poses.mk(Poses.add(ride, {"rup": {"x": -0.8}, "lup": {"x": -0.8}, "rleg": {"x": 0.9}, "lleg": {"x": 0.9}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}})), "out"], [1.0, rd, "io"]]}
	# трюк: ноги подобраны и разведены — доска крутится под ними
	A["SkateTrick"] = {"d": 1.0, "k": [[0.0, rd], [0.3, Poses.mk(Poses.add(ride, {"rup": {"x": -0.9, "z": -0.35}, "lup": {"x": -0.9, "z": 0.35}, "rleg": {"x": 0.8}, "lleg": {"x": 0.8}, "rarm": {"z": -0.8}, "larm": {"z": 0.8}, "spine": {"x": 0.1}})), "out"],
		[0.75, Poses.mk(Poses.add(ride, {"rup": {"x": -0.85, "z": -0.3}, "lup": {"x": -0.85, "z": 0.3}, "rleg": {"x": 0.8}, "lleg": {"x": 0.8}, "rarm": {"z": -0.7}, "larm": {"z": 0.7}})), "lin"], [1.0, rd, "in"]]}
	# слайд: низко, корпус откинут, рука у земли
	var sl: Dictionary = Poses.mk(Poses.add(ride, {"drop": 0.22, "spine": {"x": -0.25, "z": -0.2}, "rup": {"x": -0.5}, "lup": {"x": -0.5}, "rleg": {"x": 0.9}, "lleg": {"x": 0.6}, "rarm": {"z": 0.5, "x": 0.4}, "larm": {"z": 0.9}}))
	A["SkateSlide"] = {"d": 0.4, "loop": true, "k": [[0.0, sl], [0.5, Poses.add(sl, {"spine": {"x": 0.03}})], [1.0, sl]]}
	# удар в воздухе: нога с доской вперёд
	A["SkateAir"] = {"d": 1.0, "k": [[0.0, rd], [0.35, Poses.mk({"spine": {"x": -0.35}, "rup": {"x": -1.5}, "rleg": {"x": 0.1}, "lup": {"x": -0.8}, "lleg": {"x": 1.4}, "rarm": {"z": -0.7}, "larm": {"z": 0.7}}), "in"],
		[0.7, Poses.mk({"spine": {"x": -0.3}, "rup": {"x": -1.4}, "rleg": {"x": 0.2}, "lup": {"x": -0.8}, "lleg": {"x": 1.4}, "rarm": {"z": -0.6}, "larm": {"z": 0.6}}), "out2"], [1.0, rd, "io"]]}
	# пикирование доской вниз
	var dive: Dictionary = Poses.mk({"spine": {"x": 0.3}, "rup": {"x": -1.2}, "rleg": {"x": 0.3}, "lup": {"x": -1.2}, "lleg": {"x": 0.3}, "rarm": {"x": -2.4}, "larm": {"x": -2.4}})
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
