## Пахан с пылесосом ТЯГА-812 (этап 07): где стоит пылесос относительно героя и клипы — хват трубы двумя руками,
## притягивание, выброс, посадка, езда, прыжок, разворот, сход.
## Модель assets/models/tyaga812.glb — один кусок: корпус на колёсах, шланг петлёй, труба со щёткой. Точки ниже
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

## Обе руки на трубе, а труба повёрнута и сдвинута: pitch > 0 — сопло вверх, yaw — вбок, off — сдвиг (м).
## Труба в игре идёт за руками (tyaga._wand_update), поэтому так клип двигает сам пылесос: трубу и шланг.
static func wand(v: Vector3, pitch := 0.0, off := Vector3.ZERO, yaw := 0.0) -> Dictionary:
	var c := (TUBE_HI + TUBE_LO) * 0.5
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var d: Vector3 = b * Vector3(TUBE_DIR[0], TUBE_DIR[1], TUBE_DIR[2])
	var dd := [d.x, d.y, d.z]
	return {"r": {"p": hu(v, c + b * (TUBE_HI - c) + off), "d": dd}, "l": {"p": hu(v, c + b * (TUBE_LO - c) + off), "d": dd}}

## верхом: правая рука двигает трубу-рычаг
static func lever(off: Vector3) -> Dictionary:
	return {"r": {"p": hu(V_RIDE, TUBE_MID + off), "d": TUBE_DIR}}

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
	_stage3(A, st, sq, stand, brace, press, sit, seat, slide, hold, ride)

## Этап 3: переходы режимов, приёмы на ногах (колено, выбросы широкий / в землю / вверх / в упор), перегрев,
## верхом — толчок, тормоз, задний ход, тараны бортом и в прыжке, удар в заносе, падение камнем, выстрел на ходу.
static func _stage3(A: Dictionary, st: Dictionary, sq: Dictionary, stand: Dictionary, brace: Dictionary, press: Dictionary, sit: Dictionary, seat: Dictionary, slide: Dictionary, hold: Dictionary, ride: Dictionary) -> void:
	var V := V_HOLD
	# ---------- переходы режимов ----------
	# в притягивание: шаг вперёд, трубу от себя — и откинулся в упор
	A["TyagaSuckIn"] = {"d": 1.0, "ground": true, "k": [[0.0, stand, hold],
		[0.5, Poses.ph(Poses.add(st, {"spine": {"x": 0.32, "y": 0.1}, "head": {"x": -0.15}})), wand(V, 0.16, Vector3(0, 0.0, 0.12)), "out"],
		[1.0, brace, hold, "io"]]}
	# поток оборвался: тягу отпустило — качнуло вперёд, выпрямился
	A["TyagaSuckOut"] = {"d": 1.0, "ground": true, "k": [[0.0, brace, hold],
		[0.4, Poses.ph(Poses.add(st, {"spine": {"x": 0.3, "y": 0.1}, "head": {"x": -0.1}})), wand(V, -0.08, Vector3(0, -0.02, 0.06)), "out"],
		[1.0, stand, hold, "io"]]}
	# перегрев: отвернулся от дыма, левой рукой отмахивается; труба в правой
	var hot := Poses.add(st, {"spine": {"x": -0.12, "y": -0.3}, "head": {"y": 0.35, "x": 0.1}, "larm": {"x": -1.3, "z": 0.3}, "lfa": {"x": -1.1}})
	var hold_r := {"r": hold["r"]}
	A["TyagaOverheat"] = {"d": 0.7, "loop": true, "ground": true, "ease": "io", "k": [[0.0, Poses.ph(hot), hold_r],
		[0.5, Poses.ph(Poses.add(hot, {"larm": {"z": 0.75}, "lfa": {"x": 0.35}, "spine": {"x": -0.03}})), hold_r], [1.0, Poses.ph(hot), hold_r]]}
	# ---------- приёмы на ногах ----------
	# колено: рванул трубу на себя (враг у сопла летит навстречу) и встретил правым коленом
	A["TyagaKnee"] = {"d": 1.0, "ground": true, "ev": {"hit": 0.42}, "k": [[0.0, brace, hold],
		[0.24, Poses.ph(Poses.add(sq, {"spine": {"x": 0.25, "y": 0.1}, "rup": {"x": -0.5}, "rleg": {"x": 0.8}})), wand(V, 0.2, Vector3(0, 0.06, -0.1)), "out"],
		[0.42, Poses.ph(Poses.add(st, {"spine": {"x": -0.2, "y": 0.1}, "head": {"x": 0.15}, "rup": {"x": -1.75}, "rleg": {"x": 1.45}, "lleg": {"x": 0.15}})), wand(V, 0.32, Vector3(0, 0.12, -0.16)), "in"],
		[0.66, Poses.ph(Poses.add(st, {"spine": {"x": -0.14, "y": 0.1}, "rup": {"x": -1.55}, "rleg": {"x": 1.5}})), wand(V, 0.28, Vector3(0, 0.1, -0.14)), "io"],
		[1.0, stand, hold, "io"]]}
	# широкий выброс: поднял сопло и провёл трубой слева направо
	A["TyagaWide"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.3}, "k": [[0.0, press, hold],
		[0.2, Poses.ph(Poses.add(sq, {"spine": {"x": 0.2, "y": 0.45}, "head": {"y": -0.3}})), wand(V, 0.4, Vector3(0, 0.1, 0.02), 0.55), "out"],
		[0.42, Poses.ph(Poses.add(sq, {"spine": {"x": 0.05, "y": 0.0}, "head": {"y": 0.0}})), wand(V, 0.45, Vector3(0, 0.12, 0.04), 0.0), "lin"],
		[0.64, Poses.ph(Poses.add(st, {"spine": {"x": -0.12, "y": -0.4}, "head": {"y": 0.3}})), wand(V, 0.4, Vector3(0, 0.1, 0.0), -0.55), "out"],
		[1.0, stand, hold, "io"]]}
	# в землю: вскинул трубу и вбил сопло в пол, навалившись сверху
	A["TyagaGround"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.32}, "k": [[0.0, press, hold],
		[0.18, Poses.ph(Poses.add(st, {"spine": {"x": -0.2, "y": 0.1}, "head": {"x": 0.1}})), wand(V, 0.1, Vector3(0, 0.24, -0.02)), "out"],
		[0.32, Poses.ph(Poses.add(sq, {"drop": 0.06, "spine": {"x": 0.5, "y": 0.1}, "head": {"x": -0.25}})), wand(V, -0.22, Vector3(0, -0.07, 0.06)), "in"],
		[0.6, Poses.ph(Poses.add(sq, {"spine": {"x": 0.38, "y": 0.1}})), wand(V, -0.16, Vector3(0, -0.04, 0.04)), "io"],
		[1.0, stand, hold, "io"]]}
	# вверх: откинулся и задрал сопло в небо, отдача вдавливает в пол
	A["TyagaUp"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.3}, "k": [[0.0, press, hold],
		[0.3, Poses.ph(Poses.add(st, {"spine": {"x": -0.42, "y": 0.1}, "head": {"x": 0.35}})), wand(V, 1.3, Vector3(0, 0.3, 0.1)), "out"],
		[0.5, Poses.ph(Poses.add(sq, {"drop": 0.05, "spine": {"x": -0.3, "y": 0.1}, "head": {"x": 0.3}})), wand(V, 1.2, Vector3(0, 0.22, 0.06)), "io"],
		[1.0, stand, hold, "io"]]}
	# в упор: ткнул соплом вперёд — и отдача отбросила плечи назад
	A["TyagaPoint"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.18}, "k": [[0.0, press, hold],
		[0.18, Poses.ph(Poses.add(sq, {"spine": {"x": 0.42, "y": 0.1}, "head": {"x": -0.3}})), wand(V, 0.5, Vector3(0, 0.05, 0.2)), "out"],
		[0.4, Poses.ph(Poses.add(st, {"spine": {"x": -0.4, "y": 0.1}, "head": {"x": -0.2}, "lup": {"x": -0.55}, "lleg": {"x": 0.3}})), wand(V, 0.62, Vector3(0, 0.12, -0.1)), "out"],
		[1.0, stand, hold, "io"]]}
	# заряженный выброс: навалился на трубу — и взрыв давления откидывает всем телом назад, труба подлетает
	A["TyagaBurst"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.1}, "k": [[0.0, press, wand(V, -0.12, Vector3(0, -0.04, 0.05))],
		[0.16, Poses.ph(Poses.add(st, {"spine": {"x": -0.5, "y": 0.1}, "head": {"x": -0.3}, "rup": {"x": 0.35}, "lup": {"x": -0.7}, "lleg": {"x": 0.45}})), wand(V, 0.5, Vector3(0, 0.18, -0.12)), "out"],
		[0.5, Poses.ph(Poses.add(sq, {"spine": {"x": -0.1, "y": 0.1}, "lup": {"x": -0.5}, "lleg": {"x": 0.6}})), wand(V, 0.2, Vector3(0, 0.08, -0.06)), "io"],
		[1.0, stand, hold, "io"]]}
	# бросок пойманного: подсел, рванул трубу снизу вверх и вперёд — врага срывает с сопла
	A["TyagaThrow"] = {"d": 1.0, "ground": true, "ev": {"blast": 0.1}, "k": [[0.0, Poses.ph(Poses.add(sq, {"drop": 0.05, "spine": {"x": 0.35, "y": 0.1}})), wand(V, -0.1, Vector3(0, -0.05, 0.0))],
		[0.16, Poses.ph(Poses.add(st, {"spine": {"x": -0.25, "y": -0.2}, "head": {"x": 0.2}})), wand(V, 0.85, Vector3(0, 0.26, 0.14)), "out"],
		[0.5, Poses.ph(Poses.add(st, {"spine": {"x": -0.1, "y": -0.1}})), wand(V, 0.5, Vector3(0, 0.16, 0.08)), "io"],
		[1.0, stand, hold, "io"]]}
	# ---------- верхом ----------
	# толчок ногой с места: левая нога отталкивается от земли
	A["RideKick"] = {"d": 1.0, "k": [[0.0, seat, ride],
		[0.35, Poses.ph(Poses.add(sit, {"spine": {"x": 0.3, "z": 0.12}, "lup": {"x": 1.0, "z": 0.3}, "lleg": {"x": -0.85}})), lever(Vector3(0, 0.0, 0.06)), "out"],
		[0.7, Poses.ph(Poses.add(sit, {"spine": {"x": 0.1}, "lup": {"x": 1.5, "z": 0.25}, "lleg": {"x": -0.5}})), ride, "out"],
		[1.0, seat, ride, "io"]]}
	# тормоз: откинулся, ноги упёрты вперёд, рычаг на себя
	var brake: Dictionary = Poses.ph(Poses.add(sit, {"spine": {"x": -0.34}, "head": {"x": 0.2}, "rleg": {"x": -0.6}, "lleg": {"x": -0.6}, "rup": {"x": 0.15}, "lup": {"x": 0.15}, "larm": {"x": 0.5, "z": 0.5}}))
	A["RideBrake"] = {"d": 0.3, "loop": true, "ease": "io", "k": [[0.0, brake, lever(Vector3(0, 0.02, -0.08))], [0.5, Poses.add(brake, {"spine": {"x": 0.03}}), lever(Vector3(0, 0.02, -0.09))], [1.0, brake, lever(Vector3(0, 0.02, -0.08))]]}
	# задний ход: развернул плечи и смотрит через левое плечо назад
	var back: Dictionary = Poses.ph(Poses.add(sit, {"spine": {"x": -0.08, "y": 0.75}, "head": {"y": 0.7}, "larm": {"x": 0.9, "z": 0.3}, "lfa": {"x": 0.6}}))
	A["RideReverse"] = {"d": 0.6, "loop": true, "ease": "io", "k": [[0.0, back, ride], [0.5, Poses.add(back, {"spine": {"x": 0.03}}), ride], [1.0, back, ride]]}
	# таран бортом: навалился плечом в сторону удара
	A["RideSideRam"] = {"d": 1.0, "k": [[0.0, slide, ride],
		[0.3, Poses.ph(Poses.add(sit, {"spine": {"x": 0.1, "z": -0.5}, "head": {"z": 0.25}, "larm": {"x": -0.9, "z": -0.3}, "lfa": {"x": -1.3}})), lever(Vector3(0.05, 0.0, 0.0)), "out"],
		[1.0, slide, ride, "io"]]}
	# таран в прыжке: обе ноги вперёд, откинулся
	A["RideAirRam"] = {"d": 1.0, "k": [[0.0, seat, ride],
		[0.3, Poses.ph(Poses.add(sit, {"spine": {"x": -0.35}, "head": {"x": 0.25}, "rup": {"x": -0.3}, "lup": {"x": -0.3}, "rleg": {"x": -0.95}, "lleg": {"x": -0.95}, "larm": {"x": 0.7, "z": 0.6}})), lever(Vector3(0, 0.03, -0.06)), "out"],
		[1.0, seat, ride, "io"]]}
	# удар в заносе: свободная рука и нога идут по кругу наружу
	A["RideDriftHit"] = {"d": 1.0, "ev": {"hit": 0.4}, "k": [[0.0, slide, ride],
		[0.4, Poses.ph(Poses.add(sit, {"spine": {"x": -0.2, "z": 0.42, "y": -0.5}, "larm": {"x": 0.7, "z": 1.1}, "lfa": {"x": 1.0}, "lup": {"x": 0.7, "z": 0.7}, "lleg": {"x": -1.05}})), lever(Vector3(0.04, 0.0, -0.04)), "in"],
		[0.7, Poses.ph(Poses.add(sit, {"spine": {"x": -0.1, "z": 0.3, "y": 0.3}, "larm": {"x": 0.5, "z": 0.8}, "lfa": {"x": 0.7}, "lup": {"x": 0.4, "z": 0.4}, "lleg": {"x": -0.7}})), ride, "out"],
		[1.0, slide, ride, "io"]]}
	# камнем вниз: сгруппировался над корпусом, свободная рука вверх
	A["RideSlam"] = {"d": 1.0, "k": [[0.0, seat, ride],
		[1.0, Poses.ph(Poses.add(sit, {"drop": 0.02, "spine": {"x": 0.45}, "head": {"x": -0.35}, "rup": {"x": -0.35}, "lup": {"x": -0.35}, "rleg": {"x": 0.55}, "lleg": {"x": 0.55}, "larm": {"x": -2.2, "z": 0.3}, "lfa": {"x": 0.6}})), lever(Vector3(0, 0.04, 0.04)), "out"]]}
	# приземление с ударом: вдавило в корпус, отпружинил
	A["RideSlamLand"] = {"d": 1.0, "k": [[0.0, Poses.ph(Poses.add(sit, {"drop": 0.17, "spine": {"x": 0.55}, "head": {"x": -0.3}, "larm": {"x": 0.3, "z": 0.8}})), lever(Vector3(0, -0.03, 0.03))],
		[0.45, Poses.ph(Poses.add(sit, {"drop": 0.06, "spine": {"x": -0.05}, "larm": {"x": 0.2, "z": 0.6}})), ride, "out"],
		[1.0, seat, ride, "io"]]}
	# выстрел на ходу: отдача отбрасывает плечи, рычаг дёргается на себя
	A["RideShot"] = {"d": 1.0, "ev": {"blast": 0.1}, "k": [[0.0, seat, ride],
		[0.22, Poses.ph(Poses.add(sit, {"spine": {"x": -0.32}, "head": {"x": -0.2}, "larm": {"x": 0.4, "z": 0.5}})), lever(Vector3(0, 0.03, -0.1)), "out"],
		[1.0, seat, ride, "io"]]}
