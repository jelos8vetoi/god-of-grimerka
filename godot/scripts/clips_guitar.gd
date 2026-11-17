## madk1d с электрогитарой — как гитарист: гитара висит наискось перед корпусом, ЛЕВАЯ рука на грифе (к ней гитара
## и прикреплена), правая — у струн. Для удара правая перехватывает гриф рядом с левой и гитара идёт как топор:
## бьёт корпусом. Свои стойка, шаг, бег и рывок (гитару несут двумя руками, а не машут ею), удары и игра.
## Все положения — где кулак левой руки на грифе (доли роста, x — влево) и куда от него смотрит корпус гитары.
class_name GuitarClips

const BODY := 0.27        # от кулака на грифе до струн над корпусом, доли роста
const CARRY_P := [0.2, 0.52, 0.16]
const CARRY_D := [-0.9, -0.42, 0.05]

## Хват гитары. right: "strum" — правая у струн (pick — сдвиг кисти вверх-вниз, удар по струнам),
## "neck" — правая на грифе рядом с левой (удар двумя руками), "" — правая свободна.
static func G(p: Array, d: Array, right := "strum", pick := 0.0) -> Dictionary:
	var D := Vector3(d[0], d[1], d[2]).normalized()
	var P := Vector3(p[0], p[1], p[2])
	var r := {"l": {"p": p, "d": [D.x, D.y, D.z]}}
	if right == "strum":
		var q := P + D * BODY + Vector3(0, pick, 0.045)
		r["r"] = {"p": [q.x, q.y, q.z], "d": [0.25, -0.85, 0.45]}
	elif right == "neck":
		var q2 := P + D * 0.075
		r["r"] = {"p": [q2.x, q2.y, q2.z], "d": [D.x, D.y, D.z]}
	return r

static func add_to(A: Dictionary) -> void:
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.45}}
	var sq := {"rup": {"x": -0.6}, "rleg": {"x": 0.95}, "lup": {"x": -0.6}, "lleg": {"x": 0.95}}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var rfw := {"rup": {"x": -0.55}, "rleg": {"x": 0.6}, "lup": {"x": 0.3}, "lleg": {"x": 0.2}}
	var carry := G(CARRY_P, CARRY_D)
	var hold: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": 0.06, "y": 0.12}, "head": {"y": -0.1}}))
	# стойка: гитара на ремне перед собой, корпус чуть качается, правая перебирает струны
	A["GtIdle"] = {"d": 1.6, "loop": true, "ground": true, "ease": "io", "k": [[0.0, hold, carry],
		[0.25, Poses.add(hold, {"spine": {"x": 0.03}}), G(CARRY_P, CARRY_D, "strum", -0.012)],
		[0.5, Poses.add(hold, {"spine": {"x": 0.04}, "rleg": {"x": 0.05}, "lleg": {"x": 0.05}}), G([0.2, 0.515, 0.16], [-0.9, -0.44, 0.05], "strum", 0.01)],
		[0.75, Poses.add(hold, {"spine": {"x": 0.02}}), G(CARRY_P, CARRY_D, "strum", -0.008)], [1.0, hold, carry]]}
	# шаг, бег, рывок: ноги — как обычно, гитару несут двумя руками у корпуса (на бегу прижата ниже и ближе)
	for row in [["Walk", "GtWalk", [0.2, 0.52, 0.16], [-0.9, -0.42, 0.05]], ["Run", "GtRun", [0.2, 0.5, 0.15], [-0.88, -0.46, 0.08]], ["Sprint", "GtSprint", [0.19, 0.47, 0.15], [-0.86, -0.5, 0.1]]]:
		if not A.has(row[0]):
			continue
		var c: Dictionary = (A[row[0]] as Dictionary).duplicate(true)
		var n := 0
		for kf in c["k"]:
			var bob: float = 0.008 * sin(float(n) / 8.0 * TAU * 2.0)
			var gp: Array = row[2]
			var ik := G([gp[0], gp[1] + bob, gp[2]], row[3])
			if (kf as Array).size() <= 2:
				(kf as Array).append(ik)
			else:
				(kf as Array).insert(2, ik)
			n += 1
		A[row[1]] = c
	# ---------- удары: правая перехватила гриф, гитара — как топор, бьёт корпусом ----------
	# боковой, слева направо: замах за левое плечо → дуга перед собой → довод вправо
	A["GtSwing1"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, carry],
		[0.26, Poses.mk(Poses.add(st, Poses.tw(0.3, 0.42, -0.04))), G([0.2, 0.56, -0.02], [0.45, 0.6, -0.66], "neck"), "out"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.0, 0.2, 0.05))), G([0.24, 0.47, 0.06], [0.92, 0.2, -0.3], "neck"), "in"],
		[0.5, Poses.mk(Poses.add(rfw, Poses.tw(-0.3, -0.3, 0.12))), G([0.02, 0.45, 0.24], [-0.3, 0.0, 0.95], "neck"), "lin"],
		[0.64, Poses.mk(Poses.add(rfw, Poses.tw(-0.5, -0.38, 0.12))), G([-0.14, 0.44, 0.16], [-0.92, 0.0, 0.38], "neck"), "out2"],
		[1.0, hold, carry, "io"]]}
	# обратный, справа налево
	A["GtSwing2"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, carry],
		[0.26, Poses.mk(Poses.add(st, Poses.tw(-0.3, -0.4, -0.04))), G([-0.08, 0.5, 0.12], [-0.6, 0.5, -0.62], "neck"), "out"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.0, -0.2, 0.05))), G([-0.06, 0.47, 0.2], [-0.92, 0.2, -0.1], "neck"), "in"],
		[0.5, Poses.mk(Poses.add(lfw, Poses.tw(0.25, 0.3, 0.12))), G([0.1, 0.45, 0.22], [0.35, 0.0, 0.94], "neck"), "lin"],
		[0.64, Poses.mk(Poses.add(lfw, Poses.tw(0.45, 0.38, 0.1))), G([0.28, 0.45, 0.04], [0.86, 0.05, -0.5], "neck"), "out2"],
		[1.0, hold, carry, "io"]]}
	# тычок корпусом вперёд: отвёл к бедру — и выпад
	A["GtJab"] = {"d": 1.0, "ground": true, "n": 48, "k": [[0.0, hold, carry],
		[0.3, Poses.mk(Poses.add(st, Poses.tw(0.3, 0.35, 0.05))), G([0.14, 0.42, 0.0], [-0.05, 0.08, 0.99], "neck"), "out"],
		[0.48, Poses.mk(Poses.add(rfw, Poses.tw(-0.25, -0.3, 0.25))), G([0.05, 0.43, 0.3], [0.0, 0.05, 1.0], "neck"), "in"],
		[0.68, Poses.mk(Poses.add(rfw, Poses.tw(-0.22, -0.26, 0.22))), G([0.05, 0.43, 0.28], [0.0, 0.05, 1.0], "neck"), "out2"],
		[1.0, hold, carry, "io"]]}
	# вертушка: гитара на вытянутых руках в сторону, тело крутит контроллер (spin атаки)
	A["GtSpin"] = {"d": 1.0, "ground": true, "n": 40, "k": [[0.0, hold, carry],
		[0.2, Poses.mk(Poses.add(sq, Poses.tw(-0.2, -0.3, 0.12))), G([0.26, 0.42, 0.04], [0.85, -0.15, -0.45], "neck"), "out"],
		[0.8, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.1, 0.15, 0.05), {"spine": {"z": 0.12}}))), G([0.3, 0.46, 0.06], [0.92, 0.06, 0.38], "neck"), "lin"],
		[1.0, hold, carry, "io"]]}
	# удар сверху: гитара за гриф над головой — и корпусом в пол перед собой
	A["GtOver"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, carry],
		[0.18, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.15))), G([0.06, 0.5, 0.2], [0.0, 0.8, 0.6], "neck"), "io"],
		[0.36, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.28), {"lift": 0.04}))), G([0.04, 0.67, 0.17], [0.0, 0.95, -0.3], "neck"), "out"],
		[0.55, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.5))), G([0.03, 0.31, 0.26], [0.0, -0.35, 0.94], "neck"), "in"],
		[0.78, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.45))), G([0.03, 0.32, 0.26], [0.0, -0.3, 0.95], "neck"), "out2"],
		[1.0, hold, carry, "io"]]}
	# подброс: корпус гитары от земли вверх с подшагом
	A["GtUpper"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, carry],
		[0.3, Poses.mk(Poses.add(sq, Poses.tw(0.3, 0.3, 0.3))), G([0.2, 0.31, 0.0], [0.45, -0.55, -0.7], "neck"), "out"],
		[0.42, Poses.mk(Poses.add(sq, Poses.tw(0.1, 0.15, 0.25))), G([0.17, 0.33, 0.13], [0.4, -0.55, 0.73], "neck"), "in"],
		[0.5, Poses.mk(Poses.add(rfw, Poses.add(Poses.tw(-0.2, -0.25, -0.12), {"lift": 0.04}))), G([0.06, 0.57, 0.22], [-0.12, 0.85, 0.5], "neck"), "lin"],
		[0.72, Poses.mk(Poses.add(st, Poses.add(Poses.tw(-0.25, -0.3, -0.2), {"lift": 0.03}))), G([0.09, 0.66, 0.16], [-0.1, 0.97, -0.1], "neck"), "out2"],
		[1.0, hold, carry, "io"]]}
	# финал: прыжок, гитара над головой — и в землю
	var tuck_j := {"rup": {"x": -0.6}, "rleg": {"x": 1.0}, "lup": {"x": -0.3}, "lleg": {"x": 0.8}}
	var crouch: Dictionary = Poses.mk({"spine": {"x": 0.65}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}})
	A["GtFinal"] = {"d": 1.0, "ground": true, "n": 56, "k": [[0.0, hold, carry],
		[0.3, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.12}))), G([0.04, 0.74, 0.14], [0.0, 0.95, -0.3], "neck"), "out"],
		[0.5, Poses.mk(Poses.add(tuck_j, Poses.add(Poses.tw(0.0, 0.0, -0.32), {"lift": 0.1}))), G([0.04, 0.73, 0.13], [0.0, 0.93, -0.36], "neck"), "lin"],
		[0.62, crouch, G([0.03, 0.28, 0.27], [0.0, -0.4, 0.92], "neck"), "in"],
		[0.85, crouch, G([0.03, 0.29, 0.27], [0.0, -0.36, 0.93], "neck"), "io"],
		[1.0, hold, carry, "io"]]}
	# ---------- игра ----------
	# POWER CHORD: откинулся, гриф вверх — и удар по струнам сверху вниз, корпус бросает вперёд
	var play_p := [0.22, 0.6, 0.15]
	var play_d := [-0.78, -0.61, 0.1]
	var play: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": -0.14, "y": 0.1}, "head": {"x": -0.15}}))
	var play_dn: Dictionary = Poses.mk(Poses.add(sq, {"spine": {"x": 0.22, "y": 0.1}, "head": {"x": 0.25}}))
	A["GtStrum"] = {"d": 1.0, "ground": true, "ev": {"strum": 0.4}, "k": [[0.0, hold, carry],
		[0.25, play, G(play_p, play_d, "strum", 0.07), "out"],
		[0.4, play_dn, G([0.22, 0.57, 0.17], play_d, "strum", -0.08), "in"],
		[0.65, Poses.mk(Poses.add(st, {"spine": {"x": 0.14, "y": 0.1}})), G([0.22, 0.58, 0.16], play_d, "strum", -0.06), "out2"],
		[1.0, hold, carry, "io"]]}
	A["GtStrumHold"] = {"d": 0.4, "loop": true, "ground": true, "k": [[0.0, play, G(play_p, play_d, "strum", 0.05)], [0.5, Poses.add(play, {"head": {"x": 0.12}, "spine": {"x": 0.05}}), G(play_p, play_d, "strum", -0.06)], [1.0, play, G(play_p, play_d, "strum", 0.05)]]}
	# FEEDBACK: гитара поднята над головой грифом вверх, тело выгнуто назад — и волна
	A["GtFeedback"] = {"d": 1.0, "ground": true, "ev": {"strum": 0.4}, "k": [[0.0, hold, carry],
		[0.3, Poses.mk(Poses.add(sq, {"spine": {"x": 0.2, "y": 0.1}})), G([0.2, 0.5, 0.18], [-0.7, -0.7, 0.1], "strum", 0.03), "out"],
		[0.42, Poses.mk(Poses.add(st, {"spine": {"x": -0.38}, "head": {"x": -0.3}, "lift": 0.02})), G([0.2, 0.76, 0.1], [-0.42, -0.9, 0.1], "strum", -0.03), "in"],
		[0.72, Poses.mk(Poses.add(st, {"spine": {"x": -0.3}, "head": {"x": -0.25}})), G([0.2, 0.75, 0.1], [-0.44, -0.89, 0.1], "strum", 0.03), "out2"],
		[1.0, hold, carry, "io"]]}
	# AIR RIFF: гриф резко вверх, удар по струнам снизу вверх — волна уходит в воздух
	A["GtAirRiff"] = {"d": 1.0, "ground": true, "ev": {"strum": 0.4}, "k": [[0.0, hold, carry],
		[0.22, Poses.mk(Poses.add(sq, {"spine": {"x": 0.25, "y": 0.2}})), G([0.2, 0.5, 0.17], [-0.85, -0.5, 0.1], "strum", -0.07), "out"],
		[0.4, Poses.mk(Poses.add(st, {"spine": {"x": -0.3, "y": 0.2}, "head": {"x": -0.35}, "lift": 0.03})), G([0.16, 0.7, 0.14], [-0.5, -0.86, 0.1], "strum", 0.08), "in"],
		[0.7, Poses.mk(Poses.add(st, {"spine": {"x": -0.22, "y": 0.15}, "head": {"x": -0.3}})), G([0.16, 0.69, 0.14], [-0.52, -0.85, 0.1], "strum", 0.05), "out2"],
		[1.0, hold, carry, "io"]]}
