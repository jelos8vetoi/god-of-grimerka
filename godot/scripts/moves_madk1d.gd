## madk1d, этап 03: быстрый и подвижный. Короткие переходы, рывок с root motion, серия ударов руками и ногами,
## прыжковая атака, вертушка, аэрокомбо, переход между стилями и движения Breaker Style (шесть шагов, фриз,
## мельница, подъём разгибом). Вращения тела — ключ "spin" (оборотов за клип, окно "spin_win"),
## перемещение — ключ "root" ([доля, вперёд м, вверх м]); их применяет контроллер через AnimState.root_step().
## Руки на полу (шесть шагов, фриз) — IK кисти к земле: ключ {"l": …}/{"r": …} как у хвата оружия.
class_name MadkMoves


const PROFILE := {
	"roles": {"start": "StartRun", "stop": "StopRun", "turn_l": "TurnL", "turn_r": "TurnR", "jump": "Jump", "fall": "Fall", "land": "Land"},
	"start_t": 0.13, "stop_t": 0.24, "turn_t": 0.24, "land_t": 0.25, "land_lock": 0.12, "jump_t": 0.18,
	"move_min": 0.35, "walk_v": 2.0, "sprint_v": 6.5, "stop_min": 3.5, "turn_min": 1.4,
	"blend": {"start": 0.06, "stop": 0.08, "turn_l": 0.06, "turn_r": 0.06, "run": 0.12, "walk": 0.15, "sprint": 0.1, "start>run": 0.08, "idle": 0.2, "combat_idle": 0.15, "fall": 0.12, "land": 0.04},
}

## рука на полу: кисть в точке p (доли роста от ног), костяшки смотрят по d
static func hand(side: String, p: Array, d := [0.0, 0.0, 1.0]) -> Dictionary:
	return {side: {"p": p, "d": d}}

static func all() -> Dictionary:
	var M := Callable(Poses, "mk")
	var A := {}
	var g := MadkClips.mg({})
	var sq := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.75}, "rleg": {"x": 1.15}, "lup": {"x": -0.75}, "lleg": {"x": 1.15}}
	var run0: Array = Poses.run_keys(M)[0]
	var run4: Array = Poses.run_keys(M)[4]
	var tuck := {"rup": {"x": -1.2}, "rleg": {"x": 1.9}, "lup": {"x": -1.1}, "lleg": {"x": 1.8}}
	# ---------- перемещение ----------
	A["StartRun"] = {"d": 1.0, "ground": true, "k": [[0.0, Poses.mk({})], [0.45, Poses.mk({"spine": {"x": 0.4}, "lup": {"x": -0.6}, "lleg": {"x": 0.5}, "rup": {"x": 0.5}, "rleg": {"x": 0.4}, "rarm": {"x": -0.7}, "larm": {"x": 0.6}, "rfa": {"x": -1.2}, "lfa": {"x": -1.2}}), "out"], [1.0, run0[1], "io"]]}
	A["StopRun"] = {"d": 1.0, "ground": true, "k": [[0.0, run4[1]], [0.3, Poses.mk({"spine": {"x": -0.15}, "rup": {"x": -0.6}, "rleg": {"x": 0.15}, "lup": {"x": 0.25}, "lleg": {"x": 0.8}, "rarm": {"z": -0.4}, "larm": {"z": 0.4}}), "out"], [1.0, g, "io"]]}
	for dir in [["TurnL", 1.0], ["TurnR", -1.0]]:
		var s: float = dir[1]
		A[dir[0]] = {"d": 1.0, "ground": true, "k": [[0.0, g], [0.4, MadkClips.mg({"hips": {"y": 0.25 * s}, "spine": {"y": 0.3 * s}, "lup": {"x": -0.3}, "lleg": {"x": 0.6}, "drop": 0.03}), "out"], [1.0, g, "io"]]}
	# рывок: низко, руки назад, скользит вперёд — root motion 3.2 м
	A["Dash"] = {"d": 1.0, "ground": true, "root": [[0.0, 0.0, 0.0], [0.15, 0.35, 0.0], [0.7, 2.9, 0.0], [1.0, 3.2, 0.0]], "k": [[0.0, g],
		[0.15, Poses.mk(Poses.add(squat, {"spine": {"x": 0.55}, "rarm": {"x": 1.0}, "larm": {"x": 1.0}, "rfa": {"x": -0.2}, "lfa": {"x": -0.2}, "head": {"x": -0.35}})), "out"],
		[0.7, Poses.mk({"spine": {"x": 0.5}, "rup": {"x": -0.9}, "rleg": {"x": 0.9}, "lup": {"x": 0.4}, "lleg": {"x": 0.5}, "rarm": {"x": 1.1}, "larm": {"x": 1.1}, "head": {"x": -0.35}}), "lin"],
		[1.0, g, "io"]]}
	A["Jump"] = {"d": 1.0, "ground": true, "ev": {"takeoff": 0.5}, "k": [[0.0, g], [0.45, Poses.mk(Poses.add(squat, {"spine": {"x": 0.35}, "rarm": {"x": 0.7}, "larm": {"x": 0.7}})), "out"],
		[1.0, Poses.mk({"lift": 0.15, "spine": {"x": -0.1}, "rarm": {"x": -2.2}, "larm": {"x": -2.2}, "rup": {"x": -0.5}, "rleg": {"x": 0.8}, "lup": {"x": -0.2}, "lleg": {"x": 0.5}}), "in"]]}
	A["Fall"] = {"d": 0.6, "loop": true, "ease": "io", "k": [[0.0, Poses.mk({"rup": {"x": -0.5}, "rleg": {"x": 0.7}, "lup": {"x": -0.2}, "lleg": {"x": 0.4}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}})],
		[0.5, Poses.mk({"rup": {"x": -0.3}, "rleg": {"x": 0.5}, "lup": {"x": -0.4}, "lleg": {"x": 0.6}, "rarm": {"z": -0.6}, "larm": {"z": 0.6}})], [1.0, Poses.mk({"rup": {"x": -0.5}, "rleg": {"x": 0.7}, "lup": {"x": -0.2}, "lleg": {"x": 0.4}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}})]]}
	# рывок в воздухе: резкий группированный бросок (бочку крутит контроллер — player._air_dash_tick)
	A["AirDash"] = {"d": 1.0, "k": [[0.0, Poses.mk({"spine": {"x": 0.3}, "rup": {"x": -0.7}, "rleg": {"x": 1.0}, "lup": {"x": -0.5}, "lleg": {"x": 0.8}})],
		[0.2, Poses.mk({"spine": {"x": 0.65}, "head": {"x": -0.25}, "rup": {"x": -1.3}, "rleg": {"x": 1.8}, "lup": {"x": -1.2}, "lleg": {"x": 1.7}, "rarm": {"x": 0.9, "z": -0.4}, "larm": {"x": 0.9, "z": 0.4}}), "out"],
		[0.85, Poses.mk({"spine": {"x": 0.3}, "rup": {"x": -0.7}, "rleg": {"x": 0.9}, "lup": {"x": -0.3}, "lleg": {"x": 0.6}, "rarm": {"z": -0.7}, "larm": {"z": 0.7}}), "io"],
		[1.0, Poses.mk({"rup": {"x": -0.5}, "rleg": {"x": 0.7}, "lup": {"x": -0.2}, "lleg": {"x": 0.4}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}}), "io"]]}
	# скольжение: низко на одной ноге, вторая вытянута вперёд, руки в стороны — готов выпрыгнуть
	var sl := Poses.mk({"spine": {"x": -0.35}, "head": {"x": 0.3}, "lup": {"x": -1.45}, "lleg": {"x": 0.1}, "rup": {"x": 0.35}, "rleg": {"x": 1.75}, "larm": {"z": 1.0, "x": -0.3}, "rarm": {"z": -0.9}, "drop": 0.5})
	A["Slide"] = {"d": 1.0, "k": [[0.0, Poses.mk(Poses.add(squat, {"spine": {"x": 0.2}}))], [0.15, sl, "out"], [0.8, sl], [1.0, Poses.mk(squat), "io"]]}
	A["Land"] = {"d": 1.0, "ground": true, "ev": {"land": 0.05}, "k": [[0.0, Poses.mk(sq)], [0.25, MadkClips.mg(Poses.add(squat, {"spine": {"x": 0.3}})), "out"], [1.0, g, "io"]]}
	# ---------- удары: двойка руками и удар ногой с разворота ----------
	A["Cross"] = {"d": 1.0, "ground": true, "ev": {"hit": 0.4}, "k": [[0.0, g], [0.2, MadkClips.mg({"spine": {"y": -0.2}, "rarm": {"x": 0.2}}), "out"],
		[0.4, MadkClips.mg({"hips": {"y": 0.3}, "spine": {"y": 0.45, "x": 0.18}, "rarm": {"x": -0.65, "y": -0.25, "z": 0.1}, "rfa": {"x": 1.85}, "rup": {"x": 0.2}, "rleg": {"x": 0.2}}), "in"],
		[0.6, MadkClips.mg({"hips": {"y": 0.3}, "spine": {"y": 0.4, "x": 0.15}, "rarm": {"x": -0.55, "y": -0.2}, "rfa": {"x": 1.6}}), "out2"], [1.0, g, "io"]]}
	A["RoundKick"] = {"d": 1.0, "ground": true, "ev": {"hit": 0.5}, "k": [[0.0, g],
		[0.25, MadkClips.mg({"hips": {"y": 0.4}, "spine": {"y": 0.25, "z": -0.15}, "rup": {"x": -0.9, "z": -0.3}, "rleg": {"x": 1.5}}), "out"],
		[0.5, MadkClips.mg({"hips": {"y": 0.9}, "spine": {"y": 0.3, "z": -0.45}, "rup": {"x": -0.4, "z": -1.65, "y": 0.6}, "rleg": {"x": 0.15}, "head": {"y": -0.6}}), "in"],
		[0.7, MadkClips.mg({"hips": {"y": 1.0}, "spine": {"y": 0.3, "z": -0.35}, "rup": {"x": -0.3, "z": -1.45, "y": 0.8}, "rleg": {"x": 0.3}, "head": {"y": -0.6}}), "out2"], [1.0, g, "io"]]}
	# ---------- прыжковая атака: подлёт и удар коленом-ногой вперёд ----------
	A["JumpKick"] = {"d": 1.0, "ev": {"hit": 0.55}, "root": [[0.0, 0.0, 0.0], [0.25, 0.3, 0.0], [0.55, 1.6, 0.75], [0.8, 2.2, 0.55], [1.0, 2.4, 0.0]], "k": [[0.0, g],
		[0.25, Poses.mk(Poses.add(squat, {"spine": {"x": 0.35}, "rarm": {"x": 0.6}, "larm": {"x": 0.6}})), "out"],
		[0.55, Poses.mk({"spine": {"x": -0.25}, "rup": {"x": -1.5}, "rleg": {"x": 0.05}, "lup": {"x": -0.6}, "lleg": {"x": 1.7}, "rarm": {"z": -0.6, "x": 0.4}, "larm": {"z": 0.6, "x": 0.4}}), "in"],
		[0.8, Poses.mk({"spine": {"x": -0.15}, "rup": {"x": -1.3}, "rleg": {"x": 0.3}, "lup": {"x": -0.7}, "lleg": {"x": 1.5}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}}), "out2"],
		[1.0, MadkClips.mg(sq), "io"]]}
	# ---------- вертушка: оборот на опорной ноге с вытянутой ногой ----------
	A["SpinKick"] = {"d": 1.0, "ground": true, "spin": 1.0, "spin_win": [0.15, 0.8], "ev": {"hit": 0.55}, "k": [[0.0, g],
		[0.15, MadkClips.mg(Poses.add(sq, {"hips": {"y": -0.3}, "spine": {"y": -0.3}})), "out"],
		[0.45, MadkClips.mg({"spine": {"z": -0.35}, "rup": {"x": -0.3, "z": -1.3}, "rleg": {"x": 0.1}, "rarm": {"z": -0.4}, "larm": {"z": 0.5}, "head": {"z": 0.2}}), "in"],
		[0.75, MadkClips.mg({"spine": {"z": -0.3}, "rup": {"x": -0.3, "z": -1.25}, "rleg": {"x": 0.2}, "rarm": {"z": -0.4}, "larm": {"z": 0.5}}), "lin"], [1.0, g, "io"]]}
	# ---------- аэрокомбо: колено вверх → удар ногой → оборот в воздухе → удар вниз с пикированием ----------
	var air := Poses.mk(Poses.add(tuck, {"rarm": {"z": -0.5}, "larm": {"z": 0.5}}))
	A["AirKnee"] = {"d": 1.0, "ev": {"hit": 0.4}, "root": [[0.0, 0.0, 0.0], [1.0, 0.4, 0.5]], "k": [[0.0, air],
		[0.4, Poses.mk({"spine": {"x": -0.25}, "rup": {"x": -1.9}, "rleg": {"x": 2.1}, "lup": {"x": 0.3}, "lleg": {"x": 0.6}, "rarm": {"x": -1.6}, "larm": {"x": -1.6}}), "in"], [1.0, air, "out"]]}
	A["AirKick"] = {"d": 1.0, "ev": {"hit": 0.45}, "root": [[0.0, 0.0, 0.0], [1.0, 0.5, 0.2]], "k": [[0.0, air],
		[0.45, Poses.mk({"spine": {"x": -0.4}, "rup": {"x": -1.6}, "rleg": {"x": 0.05}, "lup": {"x": -0.4}, "lleg": {"x": 1.4}, "rarm": {"z": -0.6}, "larm": {"z": 0.6}}), "in"], [1.0, air, "out"]]}
	A["AirSpin"] = {"d": 1.0, "spin": 1.0, "spin_win": [0.1, 0.85], "ev": {"hit": 0.5}, "root": [[0.0, 0.0, 0.0], [1.0, 0.3, 0.15]], "k": [[0.0, air],
		[0.4, Poses.mk({"spine": {"z": 0.3}, "lup": {"x": -0.3, "z": 1.3}, "lleg": {"x": 0.1}, "rup": {"x": -1.0}, "rleg": {"x": 1.6}, "rarm": {"z": -0.3}, "larm": {"z": 0.3}}), "in"],
		[0.8, Poses.mk({"spine": {"z": 0.25}, "lup": {"x": -0.3, "z": 1.2}, "lleg": {"x": 0.2}, "rup": {"x": -1.0}, "rleg": {"x": 1.6}}), "lin"], [1.0, air, "out"]]}
	A["AirDive"] = {"d": 1.0, "ev": {"hit": 0.85}, "root": [[0.0, 0.0, 0.0], [0.25, 0.1, 0.2], [0.85, 1.8, -1.9], [1.0, 1.9, -1.95]], "k": [[0.0, air],
		[0.25, Poses.mk({"spine": {"x": -0.3}, "rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}, "rarm": {"x": -2.4}, "larm": {"x": -2.4}}), "out"],
		[0.6, Poses.mk({"spine": {"x": 0.35}, "rup": {"x": -1.25}, "rleg": {"x": 0.1}, "lup": {"x": -0.3}, "lleg": {"x": 1.3}, "rarm": {"x": 0.8}, "larm": {"x": 0.8}}), "in"],
		[1.0, MadkClips.mg(Poses.add(squat, {"spine": {"x": 0.35}})), "out"]]}
	# ---------- смена стиля: оборот на месте и новая стойка (основа для переходов между стилями) ----------
	A["StyleSwitch"] = {"d": 1.0, "ground": true, "spin": 1.0, "spin_win": [0.1, 0.6], "ev": {"switch": 0.6}, "k": [[0.0, g],
		[0.35, Poses.mk(Poses.add(sq, {"spine": {"x": -0.1}, "rarm": {"z": -1.1}, "larm": {"z": 1.1}})), "out"],
		[0.65, Poses.mk({"spine": {"x": -0.2}, "head": {"x": -0.2}, "rarm": {"x": -2.4, "z": -0.2}, "rfa": {"x": -0.3}, "larm": {"z": 0.4}}), "io"],
		[1.0, g, "io"]]}
	# ---------- Breaker Style ----------
	# шесть шагов: низко, левая рука на полу, ноги переступают по кругу
	var base6 := {"hips": {"x": 0.35}, "spine": {"x": 0.55}, "head": {"x": -0.45}, "drop": 0.5, "rarm": {"z": -0.4}}
	var six := []
	var legs := [
		{"rup": {"x": -1.3}, "rleg": {"x": 1.9}, "lup": {"x": -0.4, "z": 0.5}, "lleg": {"x": 0.3}},
		{"rup": {"x": -0.6, "z": -0.6}, "rleg": {"x": 0.4}, "lup": {"x": -1.2}, "lleg": {"x": 1.9}},
		{"rup": {"x": 0.2}, "rleg": {"x": 0.6}, "lup": {"x": -1.4}, "lleg": {"x": 2.0}},
		{"rup": {"x": -1.3}, "rleg": {"x": 2.0}, "lup": {"x": 0.25}, "lleg": {"x": 0.5}},
	]
	for i in 5:
		six.append([i / 4.0, Poses.mk(Poses.add(base6, legs[i % 4])), hand("l", [0.12, 0.03, 0.1], [0.3, 0.0, 1.0]), "io"])
	A["SixStep"] = {"d": 1.4, "loop": true, "n": 48, "spin": 0.25, "k": six}
	# фриз: опора на руки, корпус наклонён, ноги собраны и подняты — держит позу
	var frz := Poses.mk({"hips": {"x": 1.2, "z": 0.35}, "spine": {"x": 0.5}, "head": {"x": -0.6, "z": 0.35}, "drop": 0.55, "rup": {"x": 0.75, "z": -0.2}, "rleg": {"x": 1.5}, "lup": {"x": 0.35, "z": 0.3}, "lleg": {"x": 1.1}})
	var hands2 := {"l": {"p": [0.1, 0.03, 0.18], "d": [0.0, 0.0, 1.0]}, "r": {"p": [-0.1, 0.03, 0.2], "d": [0.0, 0.0, 1.0]}}
	A["Freeze"] = {"d": 1.6, "n": 40, "ev": {"freeze": 0.35}, "k": [[0.0, g], [0.2, Poses.mk(Poses.add(squat, {"spine": {"x": 0.6}, "drop": 0.3})), hands2, "out"],
		[0.35, frz, hands2, "out"], [0.8, frz, hands2, "lin"], [1.0, Poses.mk(Poses.add(squat, {"spine": {"x": 0.5}, "drop": 0.3})), hands2, "io"]]}
	# мельница: на спине и плечах, ноги разведены и описывают круг; вращение — spin
	var wm := {"hips": {"x": -1.3}, "spine": {"x": -0.2}, "head": {"x": 0.3}, "drop": 0.78, "rarm": {"z": -0.2, "x": 0.4}, "larm": {"z": 0.2, "x": 0.4}}
	var wk := []
	for i in 5:
		var a := i / 4.0 * TAU
		wk.append([i / 4.0, Poses.mk(Poses.add(wm, {"rup": {"x": -1.2 + 0.35 * sin(a), "z": -0.8}, "rleg": {"x": 0.1}, "lup": {"x": -1.2 - 0.35 * sin(a), "z": 0.8}, "lleg": {"x": 0.1}, "hips": {"z": 0.25 * cos(a)}}))])
	A["Windmill"] = {"d": 0.9, "loop": true, "ease": "lin", "n": 40, "spin": 1.0, "k": wk}
	# подъём разгибом: лёжа ноги к груди → толчок → на ногах
	var down := Poses._down(M)
	A["KipUp"] = {"d": 1.0, "ev": {"stand": 0.7}, "root": [[0.0, 0.0, 0.0], [1.0, 0.25, 0.0]], "k": [[0.0, down],
		[0.3, Poses.mk({"hips": {"x": -1.9}, "spine": {"x": -0.2}, "rup": {"x": -2.0}, "lup": {"x": -2.0}, "rleg": {"x": 1.2}, "lleg": {"x": 1.2}, "rarm": {"x": -2.6}, "larm": {"x": -2.6}, "rfa": {"x": -1.5}, "lfa": {"x": -1.5}, "drop": 0.82}), "out"],
		[0.55, Poses.mk({"hips": {"x": -0.6}, "spine": {"x": -0.4}, "rup": {"x": -0.2}, "lup": {"x": -0.2}, "rleg": {"x": 1.3}, "lleg": {"x": 1.3}, "rarm": {"x": -1.5}, "larm": {"x": -1.5}, "drop": 0.35}), "in"],
		[0.8, MadkClips.mg(Poses.add(squat, {"spine": {"x": 0.25}})), "out"], [1.0, g, "io"]]}
	return A
