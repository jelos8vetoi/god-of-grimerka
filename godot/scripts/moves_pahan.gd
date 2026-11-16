## Пахан, этап 03: переходы перемещения (старт, остановка, поворот на месте), прыжок и падение, реакции по направлению
## удара, заряд удара сверху. Характер — тяжёлый: разгон с наклоном и упором, торможение с волочащимся балоном,
## поворот переступанием, балон всегда «тянет» руку.
## PROFILE — параметры AnimState для Пахана: длительности переходов, пороги скоростей, смешивание.
class_name PahanMoves


const PROFILE := {
	"roles": {"start": "StartRun", "stop": "StopRun", "turn_l": "TurnL", "turn_r": "TurnR", "jump": "Jump", "fall": "Fall", "land": "Landing"},
	"start_t": 0.32, "stop_t": 0.5, "turn_t": 0.55, "land_t": 0.5, "land_lock": 0.3, "jump_t": 0.32,
	"move_min": 0.35, "walk_v": 2.4, "sprint_v": 6.6, "stop_min": 3.0, "turn_min": 1.2,
	"blend": {"start": 0.1, "stop": 0.12, "turn_l": 0.12, "turn_r": 0.12, "run": 0.2, "walk": 0.25, "sprint": 0.22, "start>run": 0.16, "stop>idle": 0.3, "idle": 0.3, "combat_idle": 0.3, "fall": 0.2, "land": 0.06},
}

static func add_to(A: Dictionary, idle_ik: Dictionary, side: Dictionary) -> void:
	var run0: Array = A["Run"]["k"][0]             # первый кадр бега: старт приходит ровно в него
	var run4: Array = A["Run"]["k"][4]
	var sq_half := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.7}, "lleg": {"x": 1.1}}
	var drag_back := Poses.W([-0.2, 0.3, -0.04], [-0.42, -0.5, -0.76])
	# старт: вес вперёд, упор правой, первый тяжёлый шаг левой, балон срывается с места и тащится
	A["StartRun"] = {"d": 1.0, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.3, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.1, -0.15, 0.3), {"lup": {"x": -0.25}, "rup": {"x": 0.15}, "larm": {"x": -0.5}}))), drag_back, "out"],
		[0.65, Poses.mkd({"spine": {"x": 0.3}, "lup": {"x": -0.7}, "lleg": {"x": 0.35}, "rup": {"x": 0.45}, "rleg": {"x": 0.6}, "larm": {"z": 0.12, "x": -0.6}, "drop": 0.03}), Poses.W([-0.19, 0.29, -0.06], [-0.24, -0.5, -0.83]), "io"],
		[1.0, run0[1], run0[2], "io"]]}
	# остановка: передняя нога упирается, корпус откидывается назад, балон по инерции выносит вперёд-вбок — и тяжело ложится
	A["StopRun"] = {"d": 1.0, "ground": true, "ev": {"plant": 0.22, "drop": 0.55}, "k": [[0.0, run4[1], run4[2]],
		[0.22, Poses.ph({"spine": {"x": -0.12}, "lup": {"x": -0.55}, "lleg": {"x": 0.2}, "rup": {"x": 0.3}, "rleg": {"x": 0.7}, "larm": {"z": 0.7, "x": -0.3}, "head": {"x": 0.05}}), Poses.W([-0.22, 0.32, 0.02], [-0.8, -0.4, -0.2]), "out"],
		[0.5, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.15, 0.1, 0.18), {"larm": {"z": 0.4}}))), Poses.W([-0.24, 0.31, 0.14], [-0.62, -0.45, 0.64]), "io"],
		[0.75, Poses.ph(Poses.add(sq_half, Poses.tw(0.05, 0.0, 0.12))), side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# поворот на месте переступанием: корпус и голова ведут, таз догоняет, ноги шагают по очереди; балон волочится по дуге
	for dir in [["TurnL", 1.0], ["TurnR", -1.0]]:
		var sgn: float = dir[1]
		var lead := "l" if sgn > 0.0 else "r"
		var back := "r" if sgn > 0.0 else "l"
		var step1 := {lead + "up": {"x": -0.45, "z": 0.25 * sgn}, lead + "leg": {"x": 0.7}}
		var step2 := {back + "up": {"x": -0.4, "z": 0.15 * sgn}, back + "leg": {"x": 0.65}}
		A[dir[0]] = {"d": 1.0, "ground": true, "ev": {"step_" + lead: 0.42, "step_" + back: 0.8}, "k": [[0.0, Poses.ph({}), idle_ik],
			[0.22, Poses.ph(Poses.add(Poses.tw(0.15 * sgn, 0.35 * sgn, 0.12), step1)), Poses.W([-0.2, 0.29, -0.03], [-0.5 + 0.2 * sgn, -0.5, -0.7]), "out"],
			[0.45, Poses.ph(Poses.add(sq_half, Poses.tw(0.3 * sgn, 0.2 * sgn, 0.12))), idle_ik, "io"],
			[0.7, Poses.ph(Poses.add(Poses.tw(0.15 * sgn, 0.05 * sgn, 0.08), step2)), idle_ik, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# прыжок: присел, балон назад для маха — выпрямился и оторвался, ноги подобраны
	A["Jump"] = {"d": 1.0, "ground": true, "ev": {"takeoff": 0.55}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.4, Poses.ph(Poses.add(squat, Poses.add(Poses.tw(0.0, 0.0, 0.4), {"larm": {"x": 0.6}}))), Poses.W([-0.22, 0.32, -0.08], [-0.4, -0.3, -0.86]), "out"],
		[0.7, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.12), {"lift": 0.12, "larm": {"x": -1.2}, "rup": {"x": -0.3}, "rleg": {"x": 0.5}, "lup": {"x": -0.5}, "lleg": {"x": 0.7}})), Poses.W([-0.2, 0.36, 0.05], [-0.6, -0.6, 0.5]), "in"],
		[1.0, Poses.ph({"lift": 0.18, "rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.4}, "lleg": {"x": 0.9}, "larm": {"z": 0.5}}), Poses.W([-0.2, 0.4, 0.02], [-0.55, -0.7, 0.45]), "out"]]}
	# падение: ноги ищут землю, свободная рука в сторону для равновесия, балон висит вниз
	var fall_a := Poses.ph({"spine": {"x": 0.1}, "rup": {"x": -0.4}, "rleg": {"x": 0.6}, "lup": {"x": -0.1}, "lleg": {"x": 0.3}, "larm": {"z": 0.75, "x": -0.2}, "head": {"x": 0.1}})
	var fall_b := Poses.ph({"spine": {"x": 0.12}, "rup": {"x": -0.2}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.5}, "larm": {"z": 0.85, "x": -0.1}, "head": {"x": 0.12}})
	var hang := Poses.W([-0.2, 0.36, 0.0], [-0.3, -0.95, 0.05])
	A["Fall"] = {"d": 0.8, "loop": true, "ease": "io", "k": [[0.0, fall_a, hang], [0.5, fall_b, hang], [1.0, fall_a, hang]]}
	# реакции по направлению удара: сзади — бросает вперёд, сбоку — сгибает в сторону; балон остаётся у земли
	A["HitBack"] = {"d": 0.5, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.3, Poses.ph({"hips": {"x": 0.12}, "spine": {"x": 0.5}, "head": {"x": 0.35}, "larm": {"x": 0.6}, "lup": {"x": -0.4}, "lleg": {"x": 0.4}}), Poses.W([-0.21, 0.29, 0.02], [-0.55, -0.5, -0.66]), "out"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	for dir in [["HitL", 1.0], ["HitR", -1.0]]:
		var sg: float = dir[1]
		A[dir[0]] = {"d": 0.5, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
			[0.3, Poses.ph({"hips": {"y": -0.15 * sg}, "spine": {"z": 0.4 * sg, "y": -0.3 * sg}, "head": {"z": 0.3 * sg}, "larm": {"z": 0.5}, "lup": {"z": 0.15 * sg}, "rup": {"z": 0.15 * sg}}), Poses.W([-0.21, 0.29, -0.04], [-0.5, -0.5, -0.71]), "out"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# заряд удара сверху: балон двумя руками над головой, дрожит от веса (основа для заряжаемых ударов стилей)
	var T2 := {"two": 0.07}
	var oh := Poses.W([-0.03, 0.68, 0.16], [0.0, 0.95, -0.3], T2)
	A["OverheadCharge"] = {"d": 0.5, "loop": true, "ground": true, "ease": "io", "k": [[0.0, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, -0.25))), oh],
		[0.5, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.03, -0.27))), Poses.W([-0.03, 0.675, 0.165], [0.02, 0.95, -0.32], T2)], [1.0, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, -0.25))), oh]]}
