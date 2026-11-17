## Балон VOZDUH, этап 1 плана docs/COMBAT_ANIMATION_AUDIT.md: у каждой атаки стиля — своя анимация.
## Раньше 25 атак играли 10 клипов (подброс — в пяти, взмах и удар в землю — в четырёх). Здесь 23 клипа:
##   цепочка ЛКМ:   BodyCheck (плечом), ChainSmash (сверху вниз с подшагом), FinalCrush (с разворота всем телом);
##   тяжёлые:       LowSweep (по ногам), SlamDown (наискось по подброшенному);
##   после окон:    RollSwing, RollUpper (после уклонения), RiseUpper (после удара в землю), ParrySwing, ParryJab
##                  (после парирования), BlockShove (из блока), PerfectSwing, PerfectUpper (после точного уклонения),
##                  DashSwing, DashRam (с разгона);
##   Heat:          HeatUpper, HeatSpike, HeatSmash, HeatSwing;
##   в воздухе:     AirSwing, AirFollow, AirCrush, AirDrive.
## Момент удара в клипе стоит на той же доле, что и hits атаки (см. style_vozduh.gd). Балон ведёт привязка Poses.W:
## [где кулак: вправо −, вверх, вперёд] и [куда смотрит донышко]; T2 — вторая рука на балоне.
class_name BalonClips

static func add_to(A: Dictionary, idle_ik: Dictionary, side: Dictionary) -> void:
	var T2 := {"two": 0.07}
	var TB := {"two": 0.13}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var rfw := {"rup": {"x": -0.55}, "rleg": {"x": 0.6}, "lup": {"x": 0.3}, "lleg": {"x": 0.2}}
	var load_r := {"rup": {"x": 0.05}, "rleg": {"x": 0.45}, "lup": {"x": -0.3}, "lleg": {"x": 0.15}}
	var load_l := {"lup": {"x": 0.05}, "lleg": {"x": 0.45}, "rup": {"x": -0.3}, "rleg": {"x": 0.15}}
	var sq_half := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.7}, "lleg": {"x": 1.1}}
	var squat_deep := {"rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}
	var air := {"rup": {"x": -0.9}, "rleg": {"x": 1.3}, "lup": {"x": -0.5}, "lleg": {"x": 1.0}}
	var I: Dictionary = Poses.ph({})
	var back_low := Poses.W([-0.2, 0.29, -0.05], [-0.35, -0.48, -0.8])      # балон опущен за правую ногу
	var up_back := Poses.W([-0.2, 0.5, 0.0], [-0.55, 0.45, -0.7])           # после подброса падает за правое плечо

	# ---------------- цепочка ЛКМ ----------------
	# 3) плечом: балон прижат к груди стоймя, корпус закручен вправо — и плечо с балоном входят во врага
	A["BodyCheck"] = {"d": 1.0, "n": 56, "ground": true, "ev": {"impact": 0.5}, "k": [[0.0, I, idle_ik],
		[0.12, Poses.ph(Poses.add(sq_half, Poses.tw(0.1, 0.1, 0.1))), side, "io"],
		[0.3, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(-0.3, -0.4, 0.05), {"larm": {"x": -0.4}}))), Poses.W([-0.08, 0.42, 0.1], [0.2, 0.95, 0.2], {"two": 0.1}), "io"],
		[0.5, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(0.35, 0.5, 0.4), {"head": {"x": 0.1}}))), Poses.W([-0.1, 0.44, 0.24], [0.15, 0.97, 0.15], {"two": 0.1}), "in"],
		[0.66, Poses.ph(Poses.add(rfw, Poses.tw(0.3, 0.45, 0.35))), Poses.W([-0.1, 0.44, 0.22], [0.15, 0.97, 0.15], {"two": 0.1}), "out2"],
		[0.86, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.15))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# 4) сверху вниз с подшагом правой: короче тяжёлого удара, без прыжка
	A["ChainSmash"] = {"d": 1.0, "n": 60, "ground": true, "ev": {"impact": 0.52}, "k": [[0.0, I, idle_ik],
		[0.14, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.1))), side, "io"],
		[0.34, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(0.0, 0.0, -0.25), {"lift": 0.04}))), Poses.W([-0.05, 0.68, 0.16], [0.0, 0.95, -0.3], T2), "out"],
		[0.44, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(0.0, 0.0, -0.28), {"lift": 0.03}))), Poses.W([-0.05, 0.69, 0.15], [0.0, 0.93, -0.36], T2), "lin"],
		[0.52, Poses.ph(Poses.add(rfw, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.03, 0.34, 0.26], [0.0, -0.4, 0.92], T2), "in"],
		[0.72, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.03, 0.3, 0.26], [0.0, -0.46, 0.89], T2), "io"],
		[0.92, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.2))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# 5) додавил: замах влево, балон двумя руками на отлёте, тело делает оборот (spin атаки) — и наискось в землю
	A["FinalCrush"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.58}, "k": [[0.0, I, idle_ik],
		[0.07, Poses.ph(Poses.tw(0.05, 0.05, 0.1)), side, "io"],
		[0.16, Poses.ph(Poses.add(sq_half, Poses.tw(0.3, 0.35, 0.15))), Poses.W([0.06, 0.4, 0.16], [0.8, 0.1, 0.58], T2), "io"],
		[0.3, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.15, -0.2, 0.05), {"spine": {"z": -0.15}}))), Poses.W([-0.3, 0.48, 0.04], [-0.92, 0.15, 0.35], T2), "in2"],
		[0.5, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.15, 0.05))), Poses.W([-0.3, 0.52, 0.02], [-0.9, 0.3, 0.3], T2), "lin"],
		[0.58, Poses.ph(Poses.add(lfw, Poses.tw(0.3, 0.3, 0.4))), Poses.W([0.02, 0.34, 0.26], [0.3, -0.4, 0.86], T2), "in"],
		[0.78, Poses.ph(Poses.add(squat, Poses.tw(0.3, 0.3, 0.45))), Poses.W([0.02, 0.33, 0.26], [0.3, -0.38, 0.87], T2), "io"],
		[0.88, Poses.ph(Poses.add(sq_half, Poses.tw(0.15, 0.05, 0.22))), Poses.W([-0.08, 0.32, 0.17], [-0.15, -0.45, 0.88]), "io"],
		[0.95, Poses.ph(Poses.tw(-0.05, -0.05, 0.12)), side, "lin"], [1.0, I, idle_ik, "out"]]}

	# ---------------- тяжёлые ----------------
	# по ногам: глубокий присед, балон у самой земли на вытянутой руке описывает круг (тело крутит spin)
	A["LowSweep"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"impact": 0.5}, "k": [[0.0, I, idle_ik],
		[0.2, Poses.ph(Poses.add(squat_deep, Poses.tw(0.2, 0.25, 0.3))), Poses.W([-0.24, 0.18, 0.0], [-0.9, -0.15, -0.4]), "out"],
		[0.75, Poses.ph(Poses.add(squat_deep, Poses.add(Poses.tw(-0.1, -0.15, 0.3), {"larm": {"z": 0.8}}))), Poses.W([-0.3, 0.16, 0.04], [-0.95, -0.1, 0.3]), "lin"],
		[0.9, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# наискось по подброшенному: балон из-за правого плеча двумя руками — влево-вниз
	A["SlamDown"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.57}, "k": [[0.0, I, idle_ik],
		[0.14, Poses.ph(Poses.add(sq_half, Poses.tw(-0.2, -0.25, 0.1))), Poses.W([-0.24, 0.36, -0.04], [-0.75, -0.1, -0.65]), "io"],
		[0.34, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(-0.3, -0.35, -0.2), {"lift": 0.03}))), Poses.W([-0.2, 0.68, 0.0], [-0.35, 0.85, -0.4], T2), "out"],
		[0.46, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(-0.3, -0.35, -0.22), {"lift": 0.03}))), Poses.W([-0.18, 0.7, 0.04], [-0.3, 0.9, -0.3], T2), "lin"],
		[0.57, Poses.ph(Poses.add(lfw, Poses.tw(0.25, 0.3, 0.5))), Poses.W([0.02, 0.34, 0.26], [0.25, -0.45, 0.86], T2), "in"],
		[0.78, Poses.ph(Poses.add(squat, Poses.tw(0.2, 0.25, 0.5))), Poses.W([0.02, 0.3, 0.26], [0.25, -0.48, 0.84], T2), "io"],
		[0.92, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), side, "io"], [1.0, I, idle_ik, "out"]]}

	# ---------------- после уклонения ----------------
	# из приседа после кувырка: низкий мах на уровне колен справа налево
	A["RollSwing"] = {"d": 1.0, "n": 60, "ground": true, "ev": {"impact": 0.52}, "k": [
		[0.0, Poses.ph(Poses.add(squat, Poses.tw(-0.2, -0.2, 0.35))), Poses.W([-0.22, 0.24, -0.04], [-0.6, -0.35, -0.72])],
		[0.3, Poses.ph(Poses.add(squat, Poses.tw(-0.35, -0.4, 0.3))), Poses.W([-0.26, 0.26, -0.06], [-0.85, -0.2, -0.48]), "out"],
		[0.52, Poses.ph(Poses.add(sq_half, Poses.tw(0.3, 0.3, 0.25))), Poses.W([0.0, 0.26, 0.24], [0.35, -0.1, 0.93]), "in"],
		[0.66, Poses.ph(Poses.add(lfw, Poses.tw(0.5, 0.4, 0.15))), Poses.W([0.16, 0.3, 0.14], [0.92, -0.05, 0.38]), "out2"],
		[0.86, Poses.ph(Poses.add(sq_half, Poses.tw(0.15, 0.05, 0.2))), Poses.W([-0.08, 0.31, 0.17], [-0.15, -0.5, 0.85]), "io"],
		[0.95, Poses.ph(Poses.tw(-0.05, -0.05, 0.1)), side, "lin"], [1.0, I, idle_ik, "out"]]}
	# из глубокого приседа: балон двумя руками зачерпывает снизу вверх
	A["RollUpper"] = {"d": 1.0, "n": 60, "ground": true, "ev": {"impact": 0.5}, "k": [
		[0.0, Poses.ph(Poses.add(squat_deep, Poses.tw(-0.1, -0.1, 0.5))), Poses.W([-0.12, 0.31, 0.1], [-0.3, -0.3, 0.9], T2)],
		[0.3, Poses.ph(Poses.add(squat_deep, Poses.tw(-0.2, -0.2, 0.55))), Poses.W([-0.14, 0.3, 0.16], [-0.2, -0.32, 0.93], T2), "io"],
		[0.5, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.1, 0.15, -0.1), {"lift": 0.04}))), Poses.W([-0.04, 0.52, 0.24], [0.0, 0.55, 0.83], T2), "in"],
		[0.62, Poses.ph(Poses.add(Poses.tw(0.15, 0.2, -0.25), {"lift": 0.06})), Poses.W([-0.04, 0.72, 0.16], [0.0, 0.98, 0.1], T2), "out2"],
		[0.8, Poses.ph(Poses.tw(0.0, 0.0, -0.05)), up_back, "io"],
		[0.92, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.15))), back_low, "in2"], [1.0, I, idle_ik, "io"]]}
	# после удара в землю: балон лежит перед героем — рывок двумя руками вверх из приседа
	A["RiseUpper"] = {"d": 1.0, "n": 60, "ground": true, "ev": {"impact": 0.5}, "k": [
		[0.0, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.55))), Poses.W([-0.02, 0.29, 0.24], [0.0, -0.44, 0.9], T2)],
		[0.28, Poses.ph(Poses.add(squat_deep, Poses.tw(0.1, 0.1, 0.6))), Poses.W([0.0, 0.3, 0.26], [0.1, -0.4, 0.91], T2), "io"],
		[0.5, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, -0.05))), Poses.W([-0.02, 0.5, 0.26], [0.0, 0.6, 0.8], T2), "in"],
		[0.62, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.05})), Poses.W([-0.03, 0.74, 0.14], [0.0, 0.97, -0.2], T2), "out2"],
		[0.82, Poses.ph(Poses.tw(-0.05, -0.05, 0.0)), up_back, "io"],
		[0.94, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.15))), side, "io"], [1.0, I, idle_ik, "out"]]}

	# ---------------- после парирования и из блока ----------------
	# ответ наотмашь двумя руками слева направо
	A["ParrySwing"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.34}, "k": [
		[0.0, Poses.ph(Poses.add(load_l, Poses.tw(0.25, 0.45))), Poses.W([0.1, 0.5, 0.12], [0.4, 0.75, -0.5], T2)],
		[0.14, Poses.ph(Poses.add(load_l, Poses.tw(0.3, 0.5, 0.0))), Poses.W([0.12, 0.5, 0.1], [0.5, 0.7, -0.5], T2), "out"],
		[0.24, Poses.ph(Poses.add(rfw, Poses.tw(-0.2, 0.3, 0.05))), Poses.W([0.08, 0.47, 0.16], [0.9, 0.15, -0.2], T2), "in"],
		[0.34, Poses.ph(Poses.add(rfw, Poses.tw(-0.25, -0.1, 0.1))), Poses.W([-0.04, 0.45, 0.18], [-0.3, 0.05, 0.95], T2), "lin"],
		[0.46, Poses.ph(Poses.add(rfw, Poses.tw(-0.7, -0.4))), Poses.W([-0.22, 0.5, 0.04], [-0.7, 0.3, -0.65]), "out2"],
		[0.64, Poses.ph(Poses.add(rfw, Poses.tw(-0.75, -0.45, -0.05))), Poses.W([-0.26, 0.52, -0.02], [-0.5, 0.5, -0.7]), "out"],
		[0.84, Poses.ph(Poses.add(sq_half, Poses.tw(-0.2, -0.2, 0.15))), Poses.W([-0.22, 0.3, -0.06], [-0.45, -0.45, -0.77]), "in2"], [1.0, I, idle_ik, "io"]]}
	# тычок: балон отведён к бедру донышком вперёд — выпад и удар торцом
	A["ParryJab"] = {"d": 1.0, "n": 56, "ground": true, "ev": {"impact": 0.42}, "k": [[0.0, I, idle_ik],
		[0.08, Poses.ph(Poses.tw(-0.1, -0.1, 0.05)), side, "io"],
		[0.14, Poses.ph(Poses.add(load_r, Poses.tw(-0.2, -0.25, 0.05))), Poses.W([-0.22, 0.38, 0.0], [-0.5, -0.1, 0.86]), "lin"],
		[0.2, Poses.ph(Poses.add(load_r, Poses.tw(-0.3, -0.35, 0.05))), Poses.W([-0.2, 0.42, -0.06], [0.05, 0.05, 1.0], T2), "out"],
		[0.34, Poses.ph(Poses.add(load_r, Poses.tw(-0.32, -0.38, 0.06))), Poses.W([-0.2, 0.42, -0.07], [0.05, 0.05, 1.0], T2), "lin"],
		[0.42, Poses.ph(Poses.add(lfw, Poses.tw(0.25, 0.3, 0.3))), Poses.W([-0.08, 0.44, 0.3], [0.0, 0.05, 1.0], T2), "in"],
		[0.6, Poses.ph(Poses.add(lfw, Poses.tw(0.2, 0.25, 0.28))), Poses.W([-0.08, 0.44, 0.28], [0.0, 0.03, 1.0], T2), "out2"],
		[0.84, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.15))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# из блока: балон поперёк груди — толчок двумя руками от себя
	A["BlockShove"] = {"d": 1.0, "n": 56, "ground": true, "ev": {"impact": 0.5}, "k": [
		[0.0, Poses.ph(Poses.add(sq_half, {"spine": {"x": 0.12}})), Poses.W([-0.07, 0.43, 0.17], [1.0, 0.18, 0.05], TB)],
		[0.26, Poses.ph(Poses.add(load_r, Poses.tw(0.0, 0.0, -0.1))), Poses.W([-0.08, 0.44, 0.1], [1.0, 0.18, 0.0], TB), "io"],
		[0.5, Poses.ph(Poses.add(lfw, Poses.tw(0.0, 0.0, 0.4))), Poses.W([-0.06, 0.46, 0.34], [1.0, 0.1, 0.05], TB), "in"],
		[0.66, Poses.ph(Poses.add(lfw, Poses.tw(0.0, 0.0, 0.35))), Poses.W([-0.06, 0.46, 0.32], [1.0, 0.1, 0.05], TB), "out2"],
		[0.76, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.25))), Poses.W([-0.1, 0.4, 0.26], [0.45, -0.1, 0.89]), "io"],
		[0.88, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.15))), Poses.W([-0.14, 0.33, 0.16], [-0.3, -0.42, 0.86]), "io"],
		[0.95, Poses.ph(Poses.tw(-0.05, -0.05, 0.1)), side, "lin"], [1.0, I, idle_ik, "out"]]}

	# ---------------- после точного уклонения ----------------
	# из низкой стойки слева: восходящий мах наискось вправо-вверх
	A["PerfectSwing"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.34}, "k": [
		[0.0, Poses.ph(Poses.add(squat, Poses.tw(0.3, 0.35, 0.35))), Poses.W([0.08, 0.26, 0.16], [0.7, -0.4, 0.55])],
		[0.16, Poses.ph(Poses.add(squat, Poses.tw(0.4, 0.45, 0.3))), Poses.W([0.12, 0.25, 0.12], [0.85, -0.35, 0.35]), "out"],
		[0.34, Poses.ph(Poses.add(rfw, Poses.tw(-0.1, -0.1, 0.1))), Poses.W([-0.08, 0.44, 0.2], [-0.3, 0.25, 0.92]), "in"],
		[0.48, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(-0.5, -0.45, -0.1), {"lift": 0.03}))), Poses.W([-0.26, 0.62, 0.0], [-0.6, 0.7, -0.35]), "out2"],
		[0.7, Poses.ph(Poses.tw(-0.4, -0.3, -0.05)), Poses.W([-0.26, 0.56, -0.04], [-0.5, 0.5, -0.7]), "io"],
		[0.88, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.15))), back_low, "in2"], [1.0, I, idle_ik, "io"]]}
	# подброс одной рукой с прыжком
	A["PerfectUpper"] = {"d": 1.0, "n": 64, "ev": {"impact": 0.5}, "k": [
		[0.0, Poses.ph(Poses.add(squat, Poses.tw(-0.2, -0.2, 0.35))), Poses.W([-0.22, 0.31, -0.02], [-0.55, -0.32, -0.77])],
		[0.3, Poses.ph(Poses.add(squat_deep, Poses.tw(-0.3, -0.3, 0.45))), Poses.W([-0.22, 0.3, 0.04], [-0.86, -0.28, 0.42]), "io"],
		[0.5, Poses.ph(Poses.add(Poses.tw(0.25, 0.3, -0.15), {"lift": 0.1, "rup": {"x": -0.5}, "rleg": {"x": 0.9}, "larm": {"x": 0.6}})), Poses.W([-0.1, 0.6, 0.2], [0.1, 0.8, 0.58]), "in"],
		[0.62, Poses.ph(Poses.add(Poses.tw(0.35, 0.35, -0.25), {"lift": 0.14, "rup": {"x": -0.6}, "rleg": {"x": 1.0}})), Poses.W([-0.14, 0.78, 0.12], [0.05, 0.99, 0.0]), "out2"],
		[0.8, Poses.ph(Poses.add(Poses.tw(0.05, 0.0, -0.05), {"lift": 0.02})), up_back, "io"],
		[0.92, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.2))), back_low, "in2"], [1.0, I, idle_ik, "io"]]}

	# ---------------- с разгона ----------------
	# мах на бегу: длинный выпад левой, корпус в наклоне
	A["DashSwing"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.52}, "k": [
		[0.0, Poses.ph(Poses.add(lfw, Poses.tw(-0.1, -0.1, 0.3))), Poses.W([-0.2, 0.3, -0.08], [-0.3, -0.45, -0.84])],
		[0.3, Poses.ph(Poses.add(rfw, Poses.tw(-0.35, -0.4, 0.25))), Poses.W([-0.28, 0.44, -0.06], [-0.6, 0.35, -0.72]), "out"],
		[0.44, Poses.ph(Poses.add(rfw, Poses.tw(0.0, -0.2, 0.3))), Poses.W([-0.28, 0.42, 0.02], [-0.9, 0.15, -0.4]), "in"],
		[0.52, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.35, 0.35, 0.35), {"lup": {"x": -0.3}}))), Poses.W([0.0, 0.42, 0.26], [0.35, -0.05, 0.94]), "lin"],
		[0.64, Poses.ph(Poses.add(lfw, Poses.tw(0.6, 0.45, 0.3))), Poses.W([0.18, 0.4, 0.14], [0.93, -0.1, 0.3]), "out2"],
		[0.77, Poses.ph(Poses.add(lfw, Poses.tw(0.42, 0.3, 0.28))), Poses.W([0.1, 0.31, 0.2], [0.75, -0.48, 0.42]), "in2"],
		[0.89, Poses.ph(Poses.add(sq_half, Poses.tw(0.15, 0.05, 0.22))), Poses.W([-0.08, 0.31, 0.17], [-0.15, -0.5, 0.85]), "io"],
		[0.95, Poses.ph(Poses.tw(-0.05, -0.05, 0.12)), side, "lin"], [1.0, I, idle_ik, "out"]]}
	# таран: балон поперёк груди в двух руках, плечо вперёд — врезается всем весом
	A["DashRam"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.59}, "k": [
		[0.0, Poses.ph(Poses.add(lfw, Poses.tw(-0.1, -0.1, 0.3))), Poses.W([-0.2, 0.3, -0.08], [-0.3, -0.45, -0.84])],
		[0.1, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(-0.1, -0.1, 0.3), {"larm": {"x": 0.4}}))), side, "io"],
		[0.2, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(-0.2, -0.2, 0.3), {"larm": {"x": 0.7}, "lfa": {"x": -0.6}}))), Poses.W([-0.1, 0.41, 0.16], [0.95, 0.15, 0.28]), "lin"],      # балон уже поперёк — вторая рука ложится на неподвижный
		[0.34, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(-0.25, -0.28, 0.3), {"larm": {"x": 0.7}, "lfa": {"x": -0.6}}))), Poses.W([-0.07, 0.43, 0.17], [1.0, 0.18, 0.05], TB), "io"],
		[0.46, Poses.ph(Poses.add(lfw, Poses.tw(-0.1, -0.1, 0.42))), Poses.W([-0.07, 0.43, 0.19], [1.0, 0.16, 0.05], TB), "out"],
		[0.53, Poses.ph(Poses.add(lfw, Poses.tw(-0.05, -0.02, 0.52))), Poses.W([-0.065, 0.445, 0.24], [1.0, 0.13, 0.05], TB), "lin"],
		[0.59, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.0, 0.05, 0.6), {"lup": {"x": -0.4}}))), Poses.W([-0.06, 0.46, 0.3], [1.0, 0.1, 0.05], TB), "lin"],
		[0.74, Poses.ph(Poses.add(lfw, Poses.tw(0.0, 0.05, 0.5))), Poses.W([-0.06, 0.46, 0.29], [1.0, 0.1, 0.05], TB), "out2"],
		[0.84, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.3))), Poses.W([-0.1, 0.4, 0.26], [0.45, -0.1, 0.89]), "io"],
		[0.91, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), Poses.W([-0.14, 0.33, 0.16], [-0.3, -0.42, 0.86]), "io"],
		[0.96, Poses.ph(Poses.tw(0.0, 0.0, 0.1)), side, "lin"], [1.0, I, idle_ik, "out"]]}

	# ---------------- Heat ----------------
	# подброс двумя руками строго вверх, с прыжком
	A["HeatUpper"] = {"d": 1.0, "n": 64, "ev": {"impact": 0.5}, "k": [[0.0, I, idle_ik],
		[0.1, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.2))), side, "io"],
		[0.24, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.6))), Poses.W([-0.04, 0.31, 0.22], [0.0, -0.3, 0.95], T2), "io"],
		[0.5, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.2), {"lift": 0.08})), Poses.W([-0.03, 0.56, 0.26], [0.0, 0.75, 0.66], T2), "in"],
		[0.62, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.35), {"lift": 0.14, "rup": {"x": -0.4}, "rleg": {"x": 0.8}})), Poses.W([-0.03, 0.8, 0.12], [0.0, 0.98, -0.18], T2), "out2"],
		[0.84, Poses.ph(Poses.tw(0.0, 0.0, 0.0)), up_back, "io"],
		[0.94, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.15))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# в асфальт: прыжок, балон перехвачен донышком вниз — и вколачивается, как свая
	A["HeatSpike"] = {"d": 1.0, "n": 64, "ev": {"impact": 0.59}, "k": [[0.0, I, idle_ik],
		[0.2, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.3))), Poses.W([-0.05, 0.42, 0.2], [0.0, 0.6, 0.8], T2), "io"],
		[0.27, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.0, 0.0, 0.05), {"lift": 0.06}))), Poses.W([-0.04, 0.56, 0.22], [0.0, 0.2, 0.98], T2), "lin"],
		[0.33, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.05), {"lift": 0.1, "rup": {"x": -0.4}, "rleg": {"x": 0.7}, "lup": {"x": -0.3}, "lleg": {"x": 0.6}})), Poses.W([-0.03, 0.64, 0.22], [0.0, -0.2, 0.98], T2), "lin"],
		[0.38, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.1), {"lift": 0.15, "rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.45}, "lleg": {"x": 0.9}})), Poses.W([-0.03, 0.72, 0.19], [0.0, -0.62, 0.78], T2), "lin"],
		[0.43, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.2), {"lift": 0.2, "rup": {"x": -0.8}, "rleg": {"x": 1.3}, "lup": {"x": -0.6}, "lleg": {"x": 1.2}})), Poses.W([-0.03, 0.8, 0.14], [0.0, -1.0, 0.1], T2), "out"],
		[0.52, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.22), {"lift": 0.18, "rup": {"x": -0.8}, "rleg": {"x": 1.3}, "lup": {"x": -0.6}, "lleg": {"x": 1.2}})), Poses.W([-0.03, 0.79, 0.14], [0.0, -1.0, 0.1], T2), "lin"],
		[0.59, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.02, 0.56, 0.22], [0.0, -0.98, 0.2], T2), "in"],
		[0.8, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.45))), Poses.W([-0.02, 0.57, 0.22], [0.0, -0.98, 0.2], T2), "io"],
		[0.86, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.42))), Poses.W([-0.03, 0.48, 0.24], [0.0, -0.8, 0.6], T2), "lin"],
		[0.91, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.36))), Poses.W([-0.05, 0.4, 0.24], [0.0, -0.5, 0.87], T2), "lin"],
		[0.95, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.28))), Poses.W([-0.1, 0.34, 0.2], [-0.2, -0.45, 0.87]), "lin"],
		[0.98, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.2))), side, "lin"], [1.0, I, idle_ik, "out"]]}
	# круг над головой: замах влево, балон проходит над головой вправо-назад и падает перед героем
	A["HeatSmash"] = {"d": 1.0, "n": 64, "ev": {"impact": 0.59}, "k": [[0.0, I, idle_ik],
		[0.06, Poses.ph(Poses.tw(0.05, 0.05, 0.1)), side, "io"],
		[0.14, Poses.ph(Poses.add(sq_half, Poses.tw(0.3, 0.35, 0.1))), Poses.W([-0.02, 0.42, 0.16], [0.85, 0.2, 0.45], T2), "io"],
		[0.21, Poses.ph(Poses.add(sq_half, Poses.tw(0.2, 0.2, 0.0))), Poses.W([-0.03, 0.54, 0.14], [0.6, 0.7, 0.4], T2), "lin"],
		[0.28, Poses.ph(Poses.add(Poses.tw(0.05, 0.0, -0.1), {"lift": 0.03})), Poses.W([-0.04, 0.64, 0.12], [0.25, 0.93, 0.25], T2), "lin"],
		[0.36, Poses.ph(Poses.add(Poses.tw(-0.2, -0.3, -0.2), {"lift": 0.06})), Poses.W([-0.1, 0.7, 0.0], [-0.6, 0.75, -0.25], T2), "out"],
		[0.5, Poses.ph(Poses.add(Poses.tw(-0.35, -0.4, -0.1), {"lift": 0.08})), Poses.W([-0.16, 0.7, 0.06], [-0.75, 0.6, 0.25], T2), "lin"],
		[0.59, Poses.ph(Poses.add(squat, Poses.tw(0.15, 0.2, 0.55))), Poses.W([0.0, 0.3, 0.26], [0.1, -0.45, 0.88], T2), "in"],
		[0.8, Poses.ph(Poses.add(squat_deep, Poses.tw(0.1, 0.15, 0.55))), Poses.W([0.0, 0.29, 0.25], [0.1, -0.45, 0.88], T2), "io"],
		[0.93, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), side, "io"], [1.0, I, idle_ik, "out"]]}
	# снизу вверх двумя руками, как клюшкой: балон от земли справа уходит высоко за левое плечо
	A["HeatSwing"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"impact": 0.34}, "k": [
		[0.0, Poses.ph(Poses.add(load_r, Poses.tw(-0.3, -0.45, 0.15))), Poses.W([-0.18, 0.36, -0.06], [-0.5, -0.3, -0.8], T2)],
		[0.16, Poses.ph(Poses.add(load_r, Poses.tw(-0.35, -0.5, 0.2))), Poses.W([-0.2, 0.34, -0.08], [-0.6, -0.25, -0.76], T2), "out"],
		[0.26, Poses.ph(Poses.add(lfw, Poses.tw(0.1, -0.2, 0.25))), Poses.W([-0.12, 0.28, 0.1], [-0.6, -0.6, 0.5], T2), "in"],
		[0.34, Poses.ph(Poses.add(lfw, Poses.tw(0.3, 0.2, 0.1))), Poses.W([0.0, 0.36, 0.22], [0.3, -0.1, 0.95], T2), "lin"],
		[0.41, Poses.ph(Poses.add(lfw, Poses.tw(0.5, 0.35, -0.02))), Poses.W([0.1, 0.5, 0.18], [0.6, 0.45, 0.66], T2), "lin"],
		[0.49, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.7, 0.45, -0.15), {"lift": 0.03}))), Poses.W([0.16, 0.62, 0.06], [0.55, 0.75, -0.35], T2), "out2"],
		[0.66, Poses.ph(Poses.add(lfw, Poses.tw(0.8, 0.5, -0.2))), Poses.W([0.18, 0.66, 0.0], [0.4, 0.75, -0.52], T2), "out"],
		[0.82, Poses.ph(Poses.tw(0.3, 0.15, 0.05)), Poses.W([0.05, 0.4, 0.18], [0.5, -0.2, 0.84]), "io"],
		[0.93, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), Poses.W([-0.18, 0.31, 0.1], [-0.8, -0.45, 0.4]), "in2"], [1.0, I, idle_ik, "out"]]}

	# ---------------- в воздухе: ноги поджаты, балон не отпускается ----------------
	# мах справа налево в прыжке
	A["AirSwing"] = {"d": 1.0, "n": 48, "ev": {"impact": 0.52}, "k": [
		[0.0, Poses.ph(Poses.add(air, Poses.tw(-0.2, -0.2))), Poses.W([-0.22, 0.4, -0.06], [-0.5, 0.2, -0.84])],
		[0.3, Poses.ph(Poses.add(air, Poses.tw(-0.4, -0.45, -0.05))), Poses.W([-0.26, 0.5, -0.08], [-0.5, 0.5, -0.7]), "out"],
		[0.44, Poses.ph(Poses.add(air, Poses.tw(0.0, -0.2))), Poses.W([-0.28, 0.48, 0.0], [-0.9, 0.25, -0.35]), "in"],
		[0.52, Poses.ph(Poses.add(air, Poses.tw(0.35, 0.35, 0.1))), Poses.W([-0.02, 0.46, 0.24], [0.3, 0.0, 0.95]), "lin"],
		[0.66, Poses.ph(Poses.add(air, Poses.tw(0.6, 0.45, 0.1))), Poses.W([0.16, 0.44, 0.14], [0.92, -0.1, 0.35]), "out2"],
		[1.0, Poses.ph(Poses.add(air, Poses.tw(0.2, 0.1, 0.1))), Poses.W([-0.1, 0.36, 0.14], [-0.3, -0.4, 0.86]), "io"]]}
	# вдогонку: наотмашь слева направо
	A["AirFollow"] = {"d": 1.0, "n": 48, "ev": {"impact": 0.5}, "k": [
		[0.0, Poses.ph(Poses.add(air, Poses.tw(0.3, 0.3))), Poses.W([0.08, 0.44, 0.16], [0.7, 0.2, 0.5])],
		[0.3, Poses.ph(Poses.add(air, Poses.tw(0.4, 0.45))), Poses.W([0.1, 0.5, 0.12], [0.6, 0.5, -0.62]), "out"],
		[0.42, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.2))), Poses.W([0.06, 0.48, 0.2], [0.9, 0.2, -0.1]), "in"],
		[0.5, Poses.ph(Poses.add(air, Poses.tw(-0.25, -0.3, 0.1))), Poses.W([-0.1, 0.46, 0.2], [-0.35, 0.0, 0.94]), "lin"],
		[0.64, Poses.ph(Poses.add(air, Poses.tw(-0.45, -0.4, 0.05))), Poses.W([-0.3, 0.46, -0.02], [-0.85, 0.05, -0.52]), "out2"],
		[1.0, Poses.ph(Poses.add(air, Poses.tw(-0.2, -0.15))), Poses.W([-0.24, 0.36, -0.05], [-0.5, -0.4, -0.77]), "io"]]}
	# сверху вниз одной рукой
	A["AirCrush"] = {"d": 1.0, "n": 48, "ev": {"impact": 0.55}, "k": [
		[0.0, Poses.ph(air), Poses.W([-0.22, 0.4, -0.04], [-0.5, 0.1, -0.86])],
		[0.3, Poses.ph(Poses.add(air, Poses.tw(-0.25, -0.2, -0.2))), Poses.W([-0.2, 0.72, 0.02], [-0.2, 0.8, -0.56]), "out"],
		[0.42, Poses.ph(Poses.add(air, Poses.tw(-0.05, -0.1, -0.15))), Poses.W([-0.18, 0.74, 0.1], [-0.15, 0.97, -0.1]), "in"],
		[0.55, Poses.ph(Poses.add(air, Poses.tw(0.2, 0.25, 0.4))), Poses.W([-0.06, 0.4, 0.24], [0.05, -0.5, 0.86]), "lin"],
		[0.75, Poses.ph(Poses.add(air, Poses.tw(0.2, 0.2, 0.45))), Poses.W([-0.06, 0.36, 0.24], [0.05, -0.55, 0.83]), "out2"],
		[1.0, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, 0.2))), Poses.W([-0.2, 0.34, 0.06], [-0.85, -0.45, 0.25]), "io"]]}
	# добивание с неба: балон над головой, тело ныряет вперёд и вгоняет врага в землю донышком вниз
	var dive := {"spine": {"x": 0.5}, "hips": {"x": 0.4}, "head": {"x": -0.3}, "rup": {"x": 0.3}, "rleg": {"x": 0.6}, "lup": {"x": 0.2}, "lleg": {"x": 0.5}}
	A["AirDrive"] = {"d": 1.0, "n": 56, "ev": {"impact": 0.6}, "k": [
		[0.0, Poses.ph(air), Poses.W([-0.05, 0.5, 0.18], [0.0, 0.6, 0.8], T2)],
		[0.3, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, -0.3))), Poses.W([-0.03, 0.8, 0.14], [0.0, 0.9, -0.4], T2), "out"],
		[0.45, Poses.ph(dive), Poses.W([-0.02, 0.5, 0.3], [0.0, -0.9, 0.42], T2), "in"],
		[0.6, Poses.ph(Poses.add(dive, {"spine": {"x": 0.2}})), Poses.W([-0.02, 0.56, 0.3], [0.0, -0.95, 0.3], T2), "lin"],
		[0.8, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.6))), Poses.W([-0.02, 0.57, 0.24], [0.0, -0.97, 0.2], T2), "io"],
		[0.9, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.3))), Poses.W([-0.08, 0.42, 0.24], [0.0, -0.3, 0.95]), "io"],
		[1.0, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.25))), side, "io"]]}
