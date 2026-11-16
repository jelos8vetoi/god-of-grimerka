## Клипы Пахана с балоном: удары (порт и этап 02), бой, перемещение. Позы — через помощников Poses.
## Подробно о правилах ключей — шапка poses.gd и docs/ANIMATION_FOUNDATION.md.
class_name PahanClips


## Пахан с балоном. Балон — тяжёлый металл: на весу его не держат, он стоит концом на земле позади-справа,
## на ходу волочится следом (отставание и инерцию добавляет drag.gd поверх анимации).
## Удар — как двуручником из Dark Souls:
##  — подготовка: присед, вес назад, балон с усилием отрывается от земли;
##  — размах: корпус идёт первым, балон отстаёт и разгоняется медленно ("in");
##  — удар: дуга через цель на полной скорости;
##  — завершение: балон тащит руку и корпус дальше и падает на землю;
##  — восстановление: балон волоком возвращается за спину.
## Время удара в клипе совпадает с "hits" в player.gd; "drop" там же — когда балон падает на землю.
static func armed() -> Dictionary:
	var A := Poses.pahan()
	var idle_ik := Poses.W(Poses.PH_HOLD, Poses.PH_DIR)
	for k in A["Idle"]["k"]:
		k.append(idle_ik)
	A["Idle"]["ease"] = "io"
	A["Idle"]["ground"] = true
	# бег: балон волочится концом по земле позади, рука вытянута назад и почти не качается
	A.erase("Light3")    # без оружия, с балоном не используется
	A["Run"] = {"d": 0.5, "loop": true, "smooth": true, "ground": true, "k": Poses.run_keys(Callable(Poses, "mkd"))}
	var run: Array = A["Run"]["k"]
	for i in run.size():
		var s := cos(i / 8.0 * TAU)
		run[i][1]["larm"] = {"z": -1.13, "x": -0.75 * s}   # свободная рука работает за двоих
		run[i].append(Poses.W([-0.19, 0.285 + 0.006 * cos(i / 4.0 * TAU), -0.06 - 0.015 * s], [-0.22, -0.5, -0.84]))
	var T2 := {"two": 0.07}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var rfw := {"rup": {"x": -0.55}, "rleg": {"x": 0.6}, "lup": {"x": 0.3}, "lleg": {"x": 0.2}}
	var load_r := {"rup": {"x": 0.05}, "rleg": {"x": 0.45}, "lup": {"x": -0.3}, "lleg": {"x": 0.15}}
	var load_l := {"lup": {"x": 0.05}, "lleg": {"x": 0.45}, "rup": {"x": -0.3}, "rleg": {"x": 0.15}}
	var sq_half := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.7}, "lleg": {"x": 1.1}}
	var squat_deep := {"rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}
	# балон у земли сбоку справа: через это положение он возвращается из-за спины вперёд и обратно, не проходя сквозь пол
	var side := Poses.W([-0.2, 0.31, 0.07], [-0.85, -0.45, 0.25])

	# 1) мах справа налево: оторвал от земли → занёс за плечо → дуга перед собой → балон падает на землю слева-спереди
	A["Light1"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.16, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.2, -0.2, 0.22), {"larm": {"x": -0.3}}))), Poses.W([-0.22, 0.3, -0.08], [-0.45, -0.3, -0.84]), "io"],
		[0.36, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(-0.32, -0.38, -0.04), {"larm": {"x": -0.6}, "lfa": {"x": -0.5}}))), Poses.W([-0.26, 0.47, -0.08], [-0.45, 0.5, -0.74]), "out"],
		[0.45, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(0.08, -0.25), {"larm": {"x": -0.4}}))), Poses.W([-0.28, 0.45, 0.0], [-0.85, 0.3, -0.45]), "in"],
		[0.52, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.3, 0.3, 0.12), {"larm": {"x": 0.5}}))), Poses.W([-0.02, 0.44, 0.22], [0.3, 0.0, 0.95]), "lin"],
		[0.62, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.5, 0.36, 0.12), {"larm": {"x": 0.7}}))), Poses.W([0.14, 0.42, 0.16], [0.9, -0.1, 0.35]), "out2"],
		[0.75, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.42, 0.3, 0.28), {"larm": {"x": 0.5}}))), Poses.W([0.1, 0.3, 0.2], [0.75, -0.5, 0.42]), "in2"],
		[0.88, Poses.ph(Poses.add(sq_half, Poses.tw(0.15, 0.05, 0.22))), Poses.W([-0.08, 0.31, 0.17], [-0.15, -0.5, 0.85]), "io"],
		[0.95, Poses.ph(Poses.tw(-0.05, -0.05, 0.12)), side, "lin"],
		[1.0, Poses.ph({}), idle_ik, "out"]]}
	# 2) наотмашь слева направо: подобрал с земли слева → занёс к левому плечу → дуга → балон уходит за спину справа и падает
	A["Light2"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.07, Poses.ph(Poses.tw(0.05, 0.05, 0.12)), side, "io"],
		[0.13, Poses.ph(Poses.add(sq_half, Poses.tw(0.15, 0.15, 0.2))), Poses.W([-0.06, 0.31, 0.18], [-0.1, -0.5, 0.86]), "lin"],
		[0.18, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.25, 0.25, 0.22), {"larm": {"x": 0.3}}))), Poses.W([0.08, 0.31, 0.2], [0.7, -0.45, 0.5]), "io"],
		[0.36, Poses.ph(Poses.add(load_l, Poses.add(Poses.tw(0.32, 0.34), {"larm": {"x": 0.4}}))), Poses.W([0.1, 0.5, 0.14], [0.6, 0.5, -0.62]), "out"],
		[0.44, Poses.ph(Poses.add(load_l, Poses.tw(0.0, 0.2))), Poses.W([0.06, 0.47, 0.2], [0.9, 0.2, -0.1]), "in"],
		[0.5, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(-0.25, -0.3, 0.1), {"larm": {"x": 0.3, "z": 0.4}}))), Poses.W([-0.1, 0.45, 0.17], [-0.35, 0.0, 0.94]), "lin"],
		[0.6, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(-0.42, -0.36, 0.08), {"larm": {"z": 0.6}}))), Poses.W([-0.3, 0.45, -0.02], [-0.85, 0.05, -0.52]), "out2"],
		[0.74, Poses.ph(Poses.add(rfw, Poses.tw(-0.35, -0.25, 0.2))), Poses.W([-0.24, 0.3, -0.05], [-0.5, -0.5, -0.7]), "in2"],
		[1.0, Poses.ph({}), idle_ik, "io"]]}
	# 3) снизу вверх: балон скребёт по земле вперёд, рывок вверх с подбросом, потом падает за правое плечо
	A["Upper"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.2, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.3, -0.3, 0.3), {"larm": {"x": -0.5}}))), Poses.W([-0.24, 0.3, -0.08], [-0.4, -0.5, -0.77]), "io"],
		[0.31, Poses.ph(Poses.add(sq_half, Poses.tw(-0.18, -0.22, 0.28))), Poses.W([-0.24, 0.32, 0.0], [-0.88, -0.47, -0.1]), "in2"],
		[0.4, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.15, 0.25))), Poses.W([-0.2, 0.33, 0.1], [-0.55, -0.52, 0.4]), "lin"],
		[0.5, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.2, 0.25, -0.1), {"larm": {"x": 0.5}}))), Poses.W([-0.04, 0.5, 0.22], [0.15, 0.5, 0.85]), "lin"],
		[0.6, Poses.ph(Poses.add(Poses.tw(0.3, 0.3, -0.22), {"lift": 0.03, "larm": {"x": 0.6}})), Poses.W([-0.12, 0.68, 0.18], [0.1, 0.97, 0.1]), "out2"],
		[0.73, Poses.ph(Poses.tw(0.05, 0.0, -0.1)), Poses.W([-0.22, 0.5, 0.02], [-0.55, 0.45, -0.7]), "io"],
		[0.87, Poses.ph(Poses.add(sq_half, Poses.tw(-0.1, -0.1, 0.15))), Poses.W([-0.2, 0.29, -0.05], [-0.35, -0.48, -0.8]), "in2"],
		[1.0, Poses.ph({}), idle_ik, "io"]]}
	# 4) вертушка: балон на вытянутой руке, отстаёт от вращения; корпус крутит контроллер
	A["Spin"] = {"d": 1.0, "n": 48, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.14, Poses.ph(Poses.add(sq_half, Poses.tw(0.25, 0.3, 0.15))), Poses.W([-0.25, 0.36, 0.0], [-0.8, -0.3, -0.5]), "io"],
		[0.32, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.15, -0.2, 0.05), {"spine": {"z": -0.15}, "larm": {"z": 0.9}}))), Poses.W([-0.33, 0.46, 0.03], [-0.9, 0.05, 0.42]), "in2"],
		[0.8, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.1, -0.15, 0.05), {"spine": {"z": -0.18}, "larm": {"z": 1.0}}))), Poses.W([-0.33, 0.47, 0.0], [-0.92, 0.08, 0.35]), "lin"],
		[1.0, Poses.ph({}), idle_ik, "io"]]}
	# тяжёлый с места: вытащил из-за спины, двумя руками над головой — и в землю
	A["Heavy"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.1, Poses.ph(Poses.add(sq_half, Poses.tw(-0.2, -0.2, 0.2))), Poses.W([-0.24, 0.36, -0.04], [-0.75, -0.1, -0.65]), "io"],
		[0.22, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.15))), Poses.W([-0.06, 0.48, 0.2], [0.0, 0.8, 0.6], T2), "io"],
		[0.4, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.28), {"lift": 0.05})), Poses.W([-0.03, 0.66, 0.19], [0.0, 0.96, -0.28], T2), "out"],
		[0.48, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.03})), Poses.W([-0.03, 0.67, 0.18], [0.0, 0.93, -0.36], T2), "lin"],
		[0.56, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.45))), Poses.W([-0.02, 0.38, 0.22], [0.0, -0.3, 0.95], T2), "in"],
		[0.62, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.6))), Poses.W([-0.02, 0.27, 0.24], [0.0, -0.5, 0.87], T2), "lin"],
		[0.8, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.55))), Poses.W([-0.02, 0.29, 0.24], [0.0, -0.44, 0.9], T2), "io"],
		[0.93, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.2))), side, "io"],
		[1.0, Poses.ph({}), idle_ik, "out"]]}
	# «гвоздь»: короткий рубящий сверху одной рукой по голове
	A["Nail"] = {"d": 1.0, "n": 60, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.22, Poses.ph(Poses.add(load_r, Poses.add(Poses.tw(-0.25, -0.2, -0.15), {"larm": {"x": -0.7}, "lfa": {"x": -0.4}}))), Poses.W([-0.2, 0.66, 0.02], [-0.2, 0.75, -0.62]), "out"],
		[0.32, Poses.ph(Poses.add(load_r, Poses.tw(-0.05, -0.1, -0.1))), Poses.W([-0.18, 0.68, 0.1], [-0.15, 0.97, -0.1]), "in"],
		[0.41, Poses.ph(Poses.add(rfw, Poses.add(Poses.tw(0.15, 0.2, 0.3), {"larm": {"x": 0.5}}))), Poses.W([-0.08, 0.52, 0.22], [0.05, 0.1, 0.99]), "lin"],
		[0.52, Poses.ph(Poses.add(rfw, Poses.tw(0.2, 0.25, 0.45))), Poses.W([-0.06, 0.33, 0.22], [0.1, -0.55, 0.83]), "out2"],
		[0.74, Poses.ph(Poses.add(rfw, Poses.tw(0.15, 0.15, 0.32))), Poses.W([-0.07, 0.33, 0.2], [0.05, -0.5, 0.86]), "io"],
		[0.9, Poses.ph(Poses.tw(-0.05, -0.05, 0.15)), side, "io"],
		[1.0, Poses.ph({}), idle_ik, "out"]]}
	# блок: бутылка поперёк груди, вторая рука держит её за корпус
	var bl := Poses.W([-0.07, 0.43, 0.17], [1.0, 0.18, 0.05], {"two": 0.13})
	A["Block"] = {"d": 1.0, "loop": true, "ground": true, "k": [[0.0, Poses.ph(Poses.add(sq_half, {"spine": {"x": 0.12}})), bl], [1.0, Poses.ph(Poses.add(sq_half, {"spine": {"x": 0.12}})), bl]]}
	A["Rage"] = {"d": 1.0, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.14, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.4))), Poses.W([-0.22, 0.33, 0.04], [-0.85, -0.4, 0.2]), "out"],
		[0.36, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.04, "head": {"x": -0.3}, "larm": {"x": -2.6, "z": 0.6}})), Poses.W([-0.14, 0.72, 0.06], [-0.1, 1.0, 0.0]), "back"],
		[0.72, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.25), {"head": {"x": -0.3}, "larm": {"x": -2.5, "z": 0.5}})), Poses.W([-0.14, 0.71, 0.07], [-0.12, 1.0, 0.05]), "lin"],
		[0.88, Poses.ph(Poses.tw(-0.1, -0.1, 0.1)), Poses.W([-0.24, 0.45, -0.02], [-0.6, 0.3, -0.74]), "io"],
		[1.0, Poses.ph({}), idle_ik, "in2"]]}
	# полный замах двумя руками, как бейсбольный: заряд за правым плечом → таз вперёд, балон отстаёт → хлёст → разворот всем телом
	var wind := Poses.W([-0.12, 0.5, 0.06], [-0.3, 0.8, -0.5], T2)
	var wind_b := Poses.add(load_r, Poses.tw(-0.25, -0.45))
	A["Charge"] = {"d": 0.5, "loop": true, "ground": true, "ease": "io", "k": [[0.0, Poses.ph(wind_b), wind],
		[0.5, Poses.ph(Poses.add(wind_b, {"spine": {"y": -0.06}, "rleg": {"x": 0.08}})), Poses.W([-0.125, 0.505, 0.05], [-0.33, 0.8, -0.52], T2)],
		[1.0, Poses.ph(wind_b), wind]]}
	A["FullSwing"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph(wind_b), wind],
		[0.12, Poses.ph(Poses.add(wind_b, {"lup": {"x": -0.35}, "lleg": {"x": 0.6}, "spine": {"y": -0.1}})), Poses.W([-0.13, 0.51, 0.04], [-0.4, 0.72, -0.57], T2), "out"],
		[0.24, Poses.ph(Poses.add(lfw, Poses.tw(0.2, -0.3, 0.05))), Poses.W([-0.1, 0.47, 0.12], [-0.9, 0.15, -0.4], T2), "in"],
		[0.34, Poses.ph(Poses.add(lfw, Poses.tw(0.25, 0.1, 0.1))), Poses.W([0.0, 0.45, 0.14], [0.3, 0.05, 0.95], T2), "lin"],
		[0.46, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.7, 0.4), {"larm": {"x": 0.6, "z": 0.5}}))), Poses.W([0.17, 0.5, 0.06], [0.6, 0.35, -0.72]), "out2"],
		[0.62, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.8, 0.45, -0.05), {"larm": {"x": 0.5, "z": 0.6}, "rup": {"x": -0.5}, "rleg": {"x": 0.5}}))), Poses.W([0.19, 0.55, 0.0], [0.35, 0.55, -0.75]), "out"],
		[0.78, Poses.ph(Poses.tw(0.3, 0.15, 0.1)), Poses.W([0.05, 0.4, 0.18], [0.5, -0.2, 0.84]), "io"],
		[0.92, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), Poses.W([-0.18, 0.31, 0.1], [-0.8, -0.45, 0.4]), "in2"],
		[1.0, Poses.ph({}), idle_ik, "out"]]}
	# Heat-добивание: вытащил из-за спины, прыжок, балон над головой двумя руками → всем весом в землю
	A["Smash"] = {"d": 1.0, "n": 72, "ground": true, "k": [
		[0.0, Poses.ph({}), idle_ik],
		[0.08, Poses.ph(Poses.add(sq_half, Poses.tw(-0.2, -0.2, 0.2))), Poses.W([-0.24, 0.36, -0.04], [-0.75, -0.1, -0.65]), "io"],
		[0.2, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.3))), Poses.W([-0.05, 0.42, 0.2], [0.0, 0.6, 0.8], T2), "io"],
		[0.42, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.16, "rup": {"x": -0.6}, "rleg": {"x": 1.1}, "lup": {"x": -0.3}, "lleg": {"x": 0.9}})), Poses.W([-0.03, 0.8, 0.19], [0.0, 0.94, -0.34], T2), "out"],
		[0.5, Poses.ph(Poses.add(Poses.tw(0.0, 0.0, -0.32), {"lift": 0.14, "rup": {"x": -0.6}, "rleg": {"x": 1.1}, "lup": {"x": -0.3}, "lleg": {"x": 0.9}})), Poses.W([-0.03, 0.79, 0.18], [0.0, 0.92, -0.4], T2), "lin"],
		[0.58, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.65))), Poses.W([-0.02, 0.27, 0.24], [0.0, -0.5, 0.87], T2), "in"],
		[0.8, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.6))), Poses.W([-0.02, 0.29, 0.24], [0.0, -0.44, 0.9], T2), "io"],
		[0.93, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.2))), side, "io"],
		[1.0, Poses.ph({}), idle_ik, "out"]]}
	for k in A["Hit"]["k"]:
		k.append(idle_ik)
	A["Hit"]["ground"] = true
	A["Hit"]["k"][1].append("out")
	A["Hit"]["k"][2].append("io")
	combat(A, idle_ik, side)
	PahanMoves.add_to(A, idle_ik, side)
	BottleClips.add_to(A)
	TyagaClips.add_to(A)
	return A

## Боевая основа Пахана (этап 02): стойка, шаг, рывок, уклоны, парирование, воздух, реакции на удар, падение и подъём,
## добивание-заготовка, достать/убрать балон, Tag Team. Удары с весом: подготовка ("out") → разгон ("in") → завершение.
static func combat(A: Dictionary, idle_ik: Dictionary, side: Dictionary) -> void:
	var bare := Poses.pahan()
	var T2 := {"two": 0.07}
	var lfw := {"lup": {"x": -0.55}, "lleg": {"x": 0.6}, "rup": {"x": 0.3}, "rleg": {"x": 0.2}}
	var sq_l := {"rup": {"x": -0.22}, "rleg": {"x": 0.35}, "lup": {"x": -0.38}, "lleg": {"x": 0.42}}
	var sq_half := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.7}, "rleg": {"x": 1.1}, "lup": {"x": -0.7}, "lleg": {"x": 1.1}}
	var squat_deep := {"rup": {"x": -1.0}, "rleg": {"x": 1.5}, "lup": {"x": -1.0}, "lleg": {"x": 1.5}}
	var guard := {"larm": {"x": -0.9, "z": 0.65}, "lfa": {"x": -1.4}}
	# боевая стойка: ниже, вес вперёд, левый кулак у лица, балон оторван от земли и смотрит концом вперёд-вправо
	var cs := Poses.ph(Poses.add(sq_l, Poses.add(Poses.tw(-0.18, -0.12, 0.14), guard)))
	var cw := Poses.W([-0.21, 0.34, 0.03], [-0.6, -0.55, 0.58])
	var over := Poses.W([-0.18, 0.62, -0.06], [-0.3, 0.45, -0.84])     # балон у правого плеча, концом за спину
	var reach := Poses.ph({"spine": {"y": -0.18, "x": -0.05}, "head": {"y": 0.25}})   # рука за плечо, к чехлу
	# кулак на горлышке в чехле, балон лежит вдоль спины так же, как в чехле: в момент хвата он не дёргается
	var at_back := Poses.W([Poses.PH_HOLSTER_GRIP[0], Poses.PH_HOLSTER_GRIP[1], Poses.PH_HOLSTER_GRIP[2]], Poses.PH_HOLSTER_DIR)
	var down := Poses._down(Callable(Poses, "ph"))
	A["IdleBare"] = bare["Idle"]
	A["RunBare"] = bare["Run"]
	A["RunBare"]["ground"] = true
	A["CombatIdle"] = {"d": 1.4, "loop": true, "ground": true, "ease": "io", "k": [[0.0, cs, cw],
		[0.5, Poses.ph(Poses.add(sq_l, Poses.add(Poses.tw(-0.18, -0.12, 0.17), Poses.add(guard, {"lift": -0.012, "lfa": {"x": -0.08}})))), Poses.W([-0.21, 0.333, 0.035], [-0.6, -0.56, 0.57])], [1.0, cs, cw]]}
	# шаг и рывок: балон волочится концом по земле, как в беге; события шага — для пыли и звука
	A["Walk"] = {"d": 1.0, "loop": true, "smooth": true, "ground": true, "ev": Poses.STEPS, "k": Poses.run_keys(Callable(Poses, "mkd"), Poses.WALK_HALF, 0.05, 0.3, -0.5)}
	A["Sprint"] = {"d": 0.42, "loop": true, "smooth": true, "ground": true, "ev": Poses.STEPS, "k": Poses.run_keys(Callable(Poses, "mkd"), Poses.SPRINT_HALF, 0.3, 0.85, -1.4)}
	A["Run"]["ev"] = Poses.STEPS
	for nm in ["Walk", "Sprint"]:
		var ks: Array = A[nm]["k"]
		var amp := 0.35 if nm == "Walk" else 0.9
		for i in ks.size():
			var s := cos(i / 8.0 * TAU)
			ks[i][1]["larm"] = {"z": -1.13, "x": -amp * s}
			ks[i].append(Poses.W([-0.19, 0.285, -0.05 - 0.01 * s], [-0.24, -0.5, -0.83]) if nm == "Walk" else Poses.W([-0.2, 0.29, -0.09 - 0.015 * s], [-0.18, -0.44, -0.88]))
	# уклон: нырок в сторону, балон остаётся у земли сбоку
	A["Dodge"] = {"d": 1.0, "ground": true, "k": [[0.0, cs, cw],
		[0.28, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.2, 0.25, 0.28), Poses.add(guard, {"spine": {"z": 0.28}, "head": {"z": -0.15}})))), side, "out"],
		[0.6, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.1, 0.1, 0.2), guard))), side, "io"], [1.0, cs, cw, "io"]]}
	# идеальный уклон: присел под ударом и уже заряжен на ответ — балон отведён назад
	A["PerfectDodge"] = {"d": 1.0, "ground": true, "ev": {"counter": 0.3}, "k": [[0.0, cs, cw],
		[0.25, Poses.ph(Poses.add(squat, Poses.add(Poses.tw(-0.3, -0.35, 0.38), {"larm": {"z": 0.9}}))), Poses.W([-0.26, 0.42, -0.06], [-0.6, 0.3, -0.74]), "out"],
		[0.55, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.25, -0.3, 0.25), guard))), Poses.W([-0.25, 0.44, -0.04], [-0.6, 0.35, -0.72]), "io"], [1.0, cs, cw, "io"]]}
	# парирование: из блока балон поперёк груди толкает удар наружу
	var bl := Poses.W([-0.07, 0.43, 0.17], [1.0, 0.18, 0.05], {"two": 0.13})
	A["Parry"] = {"d": 1.0, "ground": true, "ev": {"parry": 0.18}, "k": [[0.0, Poses.ph(Poses.add(sq_half, {"spine": {"x": 0.12}})), bl],
		[0.2, Poses.ph(Poses.add(lfw, Poses.tw(0.15, 0.2, 0.22))), Poses.W([-0.04, 0.47, 0.26], [1.0, 0.35, 0.12], {"two": 0.13}), "out"],
		[0.55, Poses.ph(Poses.add(lfw, Poses.tw(0.1, 0.12, 0.15))), Poses.W([-0.06, 0.45, 0.22], [1.0, 0.25, 0.1], {"two": 0.13}), "io"], [1.0, cs, cw, "io"]]}
	# в воздухе: ноги поджаты, балон двумя руками над головой → вниз перед собой (высоту ведёт контроллер)
	var air := {"rup": {"x": -0.9}, "rleg": {"x": 1.3}, "lup": {"x": -0.5}, "lleg": {"x": 1.0}}
	A["AirAttack"] = {"d": 1.0, "n": 48, "ev": {"hit": 0.6}, "k": [[0.0, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, -0.1))), Poses.W([-0.03, 0.72, 0.12], [0.0, 0.92, -0.38], T2)],
		[0.4, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, -0.3))), Poses.W([-0.03, 0.74, 0.08], [0.0, 0.85, -0.52], T2), "out"],
		[0.6, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, 0.5))), Poses.W([-0.02, 0.38, 0.26], [0.0, -0.45, 0.89], T2), "in"],
		[1.0, Poses.ph(Poses.add(air, Poses.tw(0.0, 0.0, 0.4))), Poses.W([-0.02, 0.4, 0.25], [0.0, -0.4, 0.92], T2), "out"]]}
	# приземление: присел, свободная рука для равновесия, балон бьёт концом в землю сбоку
	A["Landing"] = {"d": 1.0, "ground": true, "ev": {"land": 0.12}, "k": [[0.0, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.2))), side],
		[0.2, Poses.ph(Poses.add(squat_deep, Poses.add(Poses.tw(0.0, 0.0, 0.45), {"larm": {"z": 0.7}}))), side, "out"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# реакции: пошатнулся / отброшен, но на ногах / сбит с ног (лежит) / подъём
	A["Stagger"] = {"d": 1.0, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.2, Poses.ph(Poses.add(Poses.tw(0.25, 0.3, -0.35), {"hips": {"x": -0.08}, "rup": {"x": 0.25}, "lup": {"x": -0.45}, "lleg": {"x": 0.3}, "larm": {"z": 0.8, "x": -0.4}, "head": {"x": -0.3}})), Poses.W([-0.2, 0.3, -0.04], [-0.5, -0.5, -0.7]), "out"],
		[0.5, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(-0.1, -0.1, 0.3), {"larm": {"z": 0.5}}))), side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	A["Knockback"] = {"d": 1.0, "ground": true, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.15, Poses.ph({"hips": {"x": -0.15}, "spine": {"x": -0.5}, "head": {"x": -0.5}, "larm": {"x": -1.2, "z": 0.5}, "rup": {"x": -0.4}, "rleg": {"x": 0.6}, "lup": {"x": -0.4}, "lleg": {"x": 0.6}}), Poses.W([-0.23, 0.42, 0.06], [-0.78, -0.1, 0.62]), "out"],
		[0.45, Poses.ph(Poses.add(squat, Poses.add(Poses.tw(0.0, 0.0, 0.3), {"larm": {"z": 0.6}}))), side, "io"], [0.75, Poses.ph(Poses.add(sq_half, Poses.tw(0.0, 0.0, 0.15))), side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	A["Knockdown"] = {"d": 1.0, "ev": {"ground": 0.5}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.14, Poses.ph({"hips": {"x": -0.6}, "spine": {"x": -0.3}, "rup": {"x": -0.6}, "lup": {"x": -0.4}, "larm": {"x": -1.0}, "drop": 0.12}), "out"],
		[0.5, Poses.ph({"hips": {"x": -1.5}, "rarm": {"z": -0.8}, "larm": {"z": 0.8}, "rup": {"x": -0.5}, "lup": {"x": -0.3}, "drop": 0.78}), "in"],
		[0.62, Poses.ph({"hips": {"x": -1.42}, "rarm": {"z": -0.9}, "larm": {"z": 0.9}, "rup": {"x": -0.3}, "head": {"x": -0.15}, "drop": 0.75}), "out"], [1.0, down, "io"]]}
	A["Recovery"] = {"d": 1.0, "ev": {"stand": 0.85}, "k": [[0.0, down],
		[0.35, Poses.ph({"hips": {"x": -0.5}, "spine": {"x": 0.7}, "rup": {"x": -1.6}, "lup": {"x": -1.6}, "rleg": {"x": 1.9}, "lleg": {"x": 1.9}, "larm": {"x": 0.6}, "drop": 0.62}), "io"],
		[0.7, Poses.ph({"spine": {"x": 0.5}, "rup": {"x": -1.2}, "lup": {"x": -1.2}, "rleg": {"x": 1.8}, "lleg": {"x": 1.8}, "drop": 0.38}), "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# добивание-заготовка: шаг, балон двумя руками над головой, удар в лежащего перед собой (парные добивания — этап 4.6 плана)
	A["Finisher"] = {"d": 1.0, "n": 72, "ground": true, "ev": {"impact": 0.6}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.08, Poses.ph(Poses.add(sq_half, Poses.tw(-0.2, -0.2, 0.2))), Poses.W([-0.24, 0.36, -0.04], [-0.75, -0.1, -0.65]), "io"],
		[0.18, Poses.ph(Poses.add(lfw, Poses.tw(0.0, 0.0, 0.15))), Poses.W([-0.05, 0.5, 0.2], [0.0, 0.85, 0.5], T2), "io"],
		[0.38, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.0, 0.0, -0.3), {"lift": 0.03}))), Poses.W([-0.03, 0.7, 0.16], [0.0, 0.95, -0.3], T2), "out"],
		[0.5, Poses.ph(Poses.add(lfw, Poses.add(Poses.tw(0.0, 0.0, -0.32), {"lift": 0.03}))), Poses.W([-0.03, 0.71, 0.15], [0.0, 0.93, -0.36], T2), "lin"],
		[0.6, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.7))), Poses.W([-0.02, 0.24, 0.3], [0.0, -0.42, 0.9], T2), "in"],
		[0.85, Poses.ph(Poses.add(squat_deep, Poses.tw(0.0, 0.0, 0.65))), Poses.W([-0.02, 0.26, 0.3], [0.0, -0.4, 0.92], T2), "io"], [0.93, Poses.ph(Poses.add(sq_half, Poses.tw(-0.05, -0.05, 0.2))), side, "io"], [1.0, Poses.ph({}), idle_ik, "out"]]}
	# достать / убрать: рука за правое плечо к чехлу; оружие переезжает в кулак на событии "grab" (и за спину на "stow")
	A["Equip"] = {"d": 1.0, "ground": true, "ev": {"grab": 0.36}, "k": [[0.0, Poses.ph({})], [0.3, reach, at_back, "out"], [0.38, reach, at_back, "lin"],
		[0.62, Poses.ph(Poses.tw(-0.1, -0.1, 0.05)), over, "io"], [0.82, Poses.ph(Poses.tw(-0.05, -0.05, 0.1)), side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	A["Unequip"] = {"d": 1.0, "ground": true, "ev": {"stow": 0.64}, "k": [[0.0, Poses.ph({}), idle_ik], [0.18, Poses.ph(Poses.tw(-0.05, -0.05, 0.1)), side, "io"],
		[0.38, Poses.ph(Poses.tw(-0.1, -0.1, 0.05)), over, "io"], [0.62, reach, at_back, "io"], [0.68, reach, at_back, "lin"], [1.0, Poses.ph({}), "io"]]}
	# Tag Team: прыжок в кадр, приземление, балон с размаху в стойку / зовёт кента и уходит
	A["TagIn"] = {"d": 1.0, "ground": true, "ev": {"land": 0.12, "ready": 0.85}, "k": [[0.0, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.35))), side],
		[0.16, Poses.ph(Poses.add(squat_deep, Poses.add(Poses.tw(0.0, 0.0, 0.45), {"larm": {"z": 0.7}}))), side, "out"],
		[0.5, Poses.ph(Poses.add(Poses.tw(0.1, 0.15, -0.15), {"head": {"x": -0.2}, "larm": {"x": -1.5, "z": 0.4}, "lfa": {"x": -0.2}})), Poses.W([-0.24, 0.48, 0.04], [-0.75, 0.3, 0.6]), "out"],
		[0.72, Poses.ph(Poses.add(Poses.tw(0.05, 0.1, -0.1), {"larm": {"x": -1.4, "z": 0.4}, "lfa": {"x": -0.3}})), Poses.W([-0.23, 0.46, 0.04], [-0.75, 0.25, 0.6]), "io"], [1.0, cs, cw, "io"]]}
	A["TagOut"] = {"d": 1.0, "ground": true, "ev": {"call": 0.3, "leave": 0.9}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.3, Poses.ph(Poses.add(Poses.tw(0.3, 0.4, 0.0), {"larm": {"x": -2.4, "z": 0.3}, "lfa": {"x": -0.3}})), idle_ik, "io"],
		[0.6, Poses.ph(Poses.add(sq_half, Poses.add(Poses.tw(0.2, 0.2, -0.1), {"larm": {"x": -1.4}}))), side, "io"], [1.0, Poses.ph(Poses.add(squat, Poses.tw(0.0, 0.0, 0.35))), side, "in"]]}
