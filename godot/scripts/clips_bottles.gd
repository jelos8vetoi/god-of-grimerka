## Пахан с бутылкой (этап 06): стойка, прицел, быстрый и усиленный бросок. Балон в это время за спиной (чехол),
## поэтому клипы без хвата оружия. Здесь же — варианты «…Bare» обычных клипов перемещения и реакций: те же позы
## без хвата балона (Rig.role_clip берёт их сам, пока оружие в чехле).
class_name BottleClips

## копия клипа без хвата оружия: из ключей убраны словари IK
static func bare(def: Dictionary) -> Dictionary:
	var d := def.duplicate()
	var keys := []
	for k in def["k"]:
		var nk := []
		for i in (k as Array).size():
			if i < 2 or not (k[i] is Dictionary):
				nk.append(k[i])
		keys.append(nk)
	d["k"] = keys
	return d

static func add_to(A: Dictionary) -> void:
	for nm in ["CombatIdle", "Walk", "Sprint", "StartRun", "StopRun", "TurnL", "TurnR", "Hit", "HitBack", "HitL", "HitR", "Stagger", "Knockback", "Landing", "Jump", "Fall", "Block"]:
		if A.has(nm) and not A.has(nm + "Bare"):
			A[nm + "Bare"] = bare(A[nm])
	var st := {"rup": {"x": -0.2}, "rleg": {"x": 0.3}, "lup": {"x": -0.32}, "lleg": {"x": 0.38}}
	var ready: Dictionary = Poses.ph(Poses.add(st, {"spine": {"x": 0.08, "y": -0.12}, "rarm": {"x": -0.35, "z": -0.15}, "rfa": {"x": -1.1}, "larm": {"x": -0.5, "z": 0.3}, "lfa": {"x": -0.9}}))
	# занёс бутылку за голову: вес на задней ноге, левая рука указывает на цель
	var cocked: Dictionary = Poses.ph(Poses.add(st, {"hips": {"y": -0.3}, "spine": {"y": -0.5, "x": -0.12}, "spine2": {"y": -0.2}, "head": {"y": 0.6},
		"rarm": {"x": -2.5, "z": -0.55}, "rfa": {"x": -1.5}, "larm": {"x": -1.35, "z": 0.25}, "lfa": {"x": -0.15}, "rup": {"x": 0.15}, "rleg": {"x": 0.45}, "lup": {"x": -0.5}, "lleg": {"x": 0.3}}))
	var released: Dictionary = Poses.ph(Poses.add(st, {"hips": {"y": 0.3}, "spine": {"y": 0.55, "x": 0.3}, "spine2": {"y": 0.25}, "head": {"y": -0.55},
		"rarm": {"x": -1.35, "z": -0.1}, "rfa": {"x": -0.05}, "larm": {"x": 0.5, "z": 0.3}, "lup": {"x": -0.6}, "lleg": {"x": 0.55}, "rup": {"x": 0.35}, "rleg": {"x": 0.3}}))
	var follow: Dictionary = Poses.ph(Poses.add(st, {"hips": {"y": 0.35}, "spine": {"y": 0.6, "x": 0.4}, "head": {"y": -0.55},
		"rarm": {"x": -0.2, "y": 0.5}, "rfa": {"x": -0.3}, "larm": {"x": 0.6, "z": 0.3}, "lup": {"x": -0.6}, "lleg": {"x": 0.55}, "rup": {"x": 0.35}, "rleg": {"x": 0.3}}))
	A["BottleIdle"] = {"d": 2.4, "loop": true, "ground": true, "ease": "io", "k": [[0.0, ready], [0.5, Poses.add(ready, {"spine": {"x": 0.03}, "rfa": {"x": -0.06}})], [1.0, ready]]}
	A["BottleAim"] = {"d": 0.6, "loop": true, "ground": true, "ease": "io", "k": [[0.0, cocked], [0.5, Poses.add(cocked, {"rarm": {"x": -0.04}, "spine": {"y": -0.03}})], [1.0, cocked]]}
	# быстрый бросок: короткий замах от плеча и хлёст кистью
	A["BottleThrow"] = {"d": 1.0, "ground": true, "n": 48, "ev": {"release": 0.4}, "k": [[0.0, ready],
		[0.26, Poses.ph(Poses.add(st, {"spine": {"y": -0.3}, "head": {"y": 0.35}, "rarm": {"x": -2.2, "z": -0.4}, "rfa": {"x": -1.6}, "larm": {"x": -1.0, "z": 0.3}})), "out"],
		[0.42, released, "in"], [0.62, follow, "out2"], [1.0, ready, "io"]]}
	# усиленный: из замаха за головой — шаг и бросок всем телом
	A["BottleThrowHeavy"] = {"d": 1.0, "ground": true, "n": 56, "ev": {"release": 0.36}, "k": [[0.0, cocked],
		[0.16, Poses.add(cocked, {"spine": {"y": -0.12, "x": -0.08}, "rarm": {"x": -0.15}}), "out"],
		[0.38, released, "in"], [0.6, Poses.add(follow, {"spine": {"x": 0.12}, "lleg": {"x": 0.2}}), "out2"], [1.0, ready, "io"]]}
	# бросок из комбо балоном: левой рукой, балон остаётся в правой у земли
	var hold := Poses.W(Poses.PH_HOLD, Poses.PH_DIR)
	A["BottleSnap"] = {"d": 1.0, "ground": true, "n": 40, "ev": {"release": 0.42}, "k": [[0.0, Poses.ph({}), hold],
		[0.26, Poses.ph(Poses.add(st, {"spine": {"y": 0.35}, "head": {"y": -0.3}, "larm": {"x": -2.3, "z": 0.5}, "lfa": {"x": -1.5}})), hold, "out"],
		[0.44, Poses.ph(Poses.add(st, {"spine": {"y": -0.45, "x": 0.25}, "head": {"y": 0.4}, "larm": {"x": -1.4, "z": 0.15}, "lfa": {"x": -0.05}})), hold, "in"],
		[0.64, Poses.ph(Poses.add(st, {"spine": {"y": -0.5, "x": 0.3}, "larm": {"x": -0.4, "z": 0.1}, "lfa": {"x": -0.3}})), hold, "out2"], [1.0, Poses.ph({}), hold, "io"]]}
	# достал бутылку из кармана куртки (после того как балон ушёл за спину)
	A["BottleDraw"] = {"d": 1.0, "ground": true, "ev": {"draw": 0.5}, "k": [[0.0, Poses.ph({})],
		[0.45, Poses.ph({"spine": {"y": 0.15, "x": 0.1}, "head": {"x": 0.25, "y": -0.2}, "rarm": {"x": 0.25, "y": 0.5, "z": -0.1}, "rfa": {"x": -1.3}}), "io"], [1.0, ready, "io"]]}
