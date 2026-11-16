## Пахан с пылесосом ТЯГА-808 (этап 07): где стоит пылесос относительно героя и клипы — хват трубы двумя руками,
## притягивание, выброс, посадка, езда, прыжок, разворот, сход.
## Модель assets/models/tyaga808.glb — один кусок: корпус на колёсах, шланг петлёй, труба со щёткой. Точки ниже
## измерены по вершинам модели и переведены в метры в осях героя (x — влево, y — вверх, z — вперёд):
## модель повёрнута на 90° (щётка вперёд) и уменьшена до роста 1,18 м (K).
class_name TyagaClips

const K := 0.0125                               # масштаб модели: 94,6 ед. → 1,18 м
const HU := 1.85                                # рост Пахана: позы рук задаются в долях роста
# точки пылесоса в его собственных осях, м
const SEAT := Vector3(-0.106, 0.41, -0.095)     # верх корпуса: здесь сидят
const TUBE_HI := Vector3(-0.36, 0.975, -0.094)  # труба, верхний хват
const TUBE_MID := Vector3(-0.35, 0.81, -0.025)  # труба, средний хват
const TUBE_LO := Vector3(-0.34, 0.69, 0.03)     # труба, нижний хват
const NOZZLE := Vector3(-0.27, 0.05, 0.61)      # щётка: сюда тянет и отсюда дует
const TUBE_DIR := [-0.064, 0.915, -0.398]       # куда идёт труба (вверх и назад)
# где стоит пылесос относительно героя
const V_HOLD := Vector3(0.5, 0.0, 0.26)         # на ногах: слева-спереди, труба перед грудью
const V_RIDE := Vector3(0.106, 0.0, 0.095)      # верхом: корпус под героем
const V_AWAY := Vector3(0.5, 0.0, -2.6)         # убран: откатился за спину

## точка пылесоса в долях роста героя при положении пылесоса v
static func hu(v: Vector3, pt: Vector3) -> Array:
	var p := (v + pt) / HU
	return [p.x, p.y, p.z]

## обе руки на трубе (на ногах): правая выше, левая ниже
static func grip2(v: Vector3) -> Dictionary:
	return {"r": {"p": hu(v, TUBE_HI), "d": TUBE_DIR}, "l": {"p": hu(v, TUBE_LO), "d": TUBE_DIR}}

## верхом: правая держит трубу, как рычаг; левая свободна
static func grip1(v: Vector3) -> Dictionary:
	return {"r": {"p": hu(v, TUBE_MID), "d": TUBE_DIR}}

static func add_to(A: Dictionary) -> void:
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.35}, "lup": {"x": -0.3}, "lleg": {"x": 0.4}}
	var sq := {"rup": {"x": -0.55}, "rleg": {"x": 0.85}, "lup": {"x": -0.6}, "lleg": {"x": 0.9}}
	var hold := grip2(V_HOLD)
	var ride := grip1(V_RIDE)
	var stand: Dictionary = Poses.ph(Poses.add(st, {"spine": {"x": 0.12, "y": 0.1}, "head": {"y": -0.1}}))
	A["TyagaHold"] = {"d": 2.2, "loop": true, "ground": true, "ease": "io", "k": [[0.0, stand, hold], [0.5, Poses.add(stand, {"spine": {"x": 0.03}}), hold], [1.0, stand, hold]]}
	# шаг с пылесосом: ноги идут, руки на трубе
	var walk := Poses.run_keys(Callable(Poses, "mk"), Poses.WALK_HALF, 0.1, 0.0, -0.4)
	for kf in walk:
		(kf as Array).append(hold)
	A["TyagaWalk"] = {"d": 1.0, "loop": true, "smooth": true, "ground": true, "ev": Poses.STEPS, "k": walk}
	# притягивание: упёрся, откинулся назад — пылесос тянет вперёд; мелкая дрожь
	var brace: Dictionary = Poses.ph(Poses.add(sq, {"spine": {"x": -0.14, "y": 0.1}, "hips": {"x": -0.06}, "head": {"x": 0.15}}))
	A["TyagaSuck"] = {"d": 0.24, "loop": true, "ground": true, "k": [[0.0, brace, hold], [0.5, Poses.add(brace, {"spine": {"x": 0.03, "y": 0.02}, "head": {"z": 0.03}}), hold], [1.0, brace, hold]]}
	# заряд выброса: присел, навалился на трубу
	var press: Dictionary = Poses.ph(Poses.add(sq, {"spine": {"x": 0.3, "y": 0.1}, "head": {"x": -0.2}}))
	A["TyagaCharge"] = {"d": 0.3, "loop": true, "ground": true, "k": [[0.0, press, hold], [0.5, Poses.add(press, {"spine": {"x": 0.03}}), hold], [1.0, press, hold]]}
	# выброс: отдача откидывает корпус, шаг назад, потом возврат
	A["TyagaBlast"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.1}, "k": [[0.0, press, hold],
		[0.14, Poses.ph(Poses.add(st, {"spine": {"x": -0.38, "y": 0.1}, "head": {"x": -0.25}, "rup": {"x": 0.3}, "lup": {"x": -0.5}, "lleg": {"x": 0.3}})), hold, "out"],
		[0.55, Poses.ph(Poses.add(sq, {"spine": {"x": 0.1, "y": 0.1}})), hold, "io"], [1.0, stand, hold, "io"]]}
	# ---------- езда: сидит на корпусе, ноги вперёд на крышке, правая рука на трубе-рычаге ----------
	var sit := {"drop": 0.1, "spine": {"x": 0.16}, "head": {"x": -0.12}, "rup": {"x": -1.35, "z": -0.28}, "rleg": {"x": 1.15}, "lup": {"x": -1.35, "z": 0.28}, "lleg": {"x": 1.15},
		"larm": {"x": -0.75, "z": 0.35}, "lfa": {"x": -0.9}}
	var seat: Dictionary = Poses.ph(sit)
	A["RideSit"] = {"d": 0.5, "loop": true, "ease": "io", "k": [[0.0, seat, ride], [0.5, Poses.add(seat, {"spine": {"x": 0.02}, "drop": 0.105}), ride], [1.0, seat, ride]]}
	var fast: Dictionary = Poses.ph(Poses.add(sit, {"spine": {"x": 0.32}, "head": {"x": -0.3}, "larm": {"x": -0.4}}))
	A["RideBoost"] = {"d": 0.3, "loop": true, "ease": "io", "k": [[0.0, fast, ride], [0.5, Poses.add(fast, {"spine": {"x": 0.03}}), ride], [1.0, fast, ride]]}
	# занос: корпус откинут в поворот, левая рука в сторону для равновесия
	var slide: Dictionary = Poses.ph(Poses.add(sit, {"spine": {"x": -0.1, "z": 0.2}, "larm": {"x": 0.5, "z": 0.7}, "lfa": {"x": 0.6}}))
	A["RideDrift"] = {"d": 0.4, "loop": true, "ease": "io", "k": [[0.0, slide, ride], [0.5, Poses.add(slide, {"spine": {"z": 0.04}}), ride], [1.0, slide, ride]]}
	# прыжок: подобрал ноги, привстал над корпусом, приземление — присел
	A["RideJump"] = {"d": 1.0, "k": [[0.0, seat, ride], [0.3, Poses.ph(Poses.add(sit, {"drop": 0.02, "rup": {"x": -0.3}, "lup": {"x": -0.3}, "rleg": {"x": 0.5}, "lleg": {"x": 0.5}, "spine": {"x": 0.2}, "larm": {"x": -1.2}})), ride, "out"],
		[0.8, Poses.ph(Poses.add(sit, {"drop": 0.06, "spine": {"x": 0.1}})), ride, "io"], [1.0, Poses.ph(Poses.add(sit, {"drop": 0.13, "spine": {"x": 0.3}})), ride, "in"]]}
	# удар с разворота на ходу: тело откинуто наружу, свободная рука и нога выставлены (вращение — spin_off)
	A["RideSpin"] = {"d": 1.0, "k": [[0.0, seat, ride], [0.3, Poses.ph(Poses.add(sit, {"spine": {"x": -0.15, "z": 0.3}, "larm": {"x": 0.6, "z": 0.9}, "lfa": {"x": 0.9}, "lup": {"x": 0.5, "z": 0.5}, "lleg": {"x": -0.9}})), ride, "out"],
		[0.75, Poses.ph(Poses.add(sit, {"spine": {"x": -0.12, "z": 0.25}, "larm": {"x": 0.6, "z": 0.85}, "lfa": {"x": 0.9}, "lup": {"x": 0.4, "z": 0.45}, "lleg": {"x": -0.8}})), ride, "lin"], [1.0, seat, ride, "io"]]}
	# посадка: с места у трубы — прыжок боком на корпус (пылесос в это время подкатывается под героя)
	A["RideMount"] = {"d": 1.0, "ev": {"seat": 0.8}, "k": [[0.0, stand, hold],
		[0.35, Poses.ph(Poses.add(sq, {"spine": {"x": 0.3}})), grip1(V_HOLD.lerp(V_RIDE, 0.25) + (TUBE_HI - TUBE_MID) * 0.6), "out"],
		[0.65, Poses.ph(Poses.add(sit, {"drop": -0.06, "rup": {"x": 0.9}, "lup": {"x": 0.9}})), grip1(V_HOLD.lerp(V_RIDE, 0.75)), "out"],
		[1.0, seat, ride, "in"]]}
	# сход: привстал, перекинул ноги — и снова на ногах у трубы
	A["RideDismount"] = {"d": 1.0, "ev": {"feet": 0.75}, "k": [[0.0, seat, ride],
		[0.4, Poses.ph(Poses.add(sit, {"drop": -0.04, "rup": {"x": 0.8}, "lup": {"x": 0.8}, "spine": {"x": 0.25}})), grip1(V_RIDE.lerp(V_HOLD, 0.35)), "out"],
		[0.75, Poses.ph(Poses.add(sq, {"spine": {"x": 0.25}})), grip1(V_RIDE.lerp(V_HOLD, 0.8) + (TUBE_HI - TUBE_MID) * 0.6), "io"],
		[1.0, stand, hold, "io"]]}
