## Основа боевых анимаций (этап 0 плана docs/COMBAT_ANIMATION_AUDIT.md): клипы, общие для обоих героев.
##   DodgeL / DodgeR / DodgeB — уклонение вбок и назад (вперёд остаётся кувырок Tuck);
##   BlockHit / BlockHeavy    — принял удар в блок: лёгкий и тяжёлый;
##   IdleVar                  — вариация покоя Пахана с балоном: поднял, осмотрел, перехватил.
## Клипы строятся от боевой стойки и блока самого героя (первый ключ CombatIdle и Block), поэтому оружие
## остаётся в том же хвате, а начало и конец совпадают со стойкой.
class_name FoundationClips

## общие клипы: stance — имя клипа стойки, от которой строим
static func add_to(A: Dictionary, stance := "CombatIdle") -> void:
	if not A.has(stance):
		return
	var k0: Array = A[stance]["k"][0]
	var base: Dictionary = k0[1]
	var ik = k0[2] if k0.size() > 2 and k0[2] is Dictionary else null
	var mk := func(t: float, pose: Dictionary, ease := "") -> Array:
		var r: Array = [t, pose]
		if ik != null:
			r.append(ik)
		if ease != "":
			r.append(ease)
		return r
	# вбок: толчок дальней ногой, корпус и голова уходят с линии удара, приземление на ближнюю ногу
	for row in [["DodgeL", 1.0], ["DodgeR", -1.0]]:
		var s: float = row[1]
		var lean: Dictionary = Poses.add(base, {"hips": {"z": 0.26 * s}, "spine": {"z": 0.5 * s, "x": 0.12}, "spine2": {"z": 0.2 * s}, "head": {"z": -0.4 * s}, "rup": {"x": -0.5, "z": -0.45 * s}, "rleg": {"x": 0.9}, "lup": {"x": -0.5, "z": -0.45 * s}, "lleg": {"x": 0.9}, "drop": 0.16})
		var mid: Dictionary = Poses.add(base, {"spine": {"z": 0.18 * s}, "head": {"z": -0.12 * s}, "rup": {"x": -0.2}, "rleg": {"x": 0.35}, "lup": {"x": -0.2}, "lleg": {"x": 0.35}})
		A[row[0]] = {"d": 1.0, "n": 32, "ev": {"push": 0.05, "land": 0.6}, "k": [mk.call(0.0, base), mk.call(0.22, lean, "out"), mk.call(0.62, mid, "lin"), mk.call(1.0, base, "io")]}
	# назад: отклонился, отпрыгнул, принял вес на согнутые ноги
	var back: Dictionary = Poses.add(base, {"spine": {"x": -0.5}, "hips": {"x": -0.2}, "head": {"x": 0.2}, "rup": {"x": -0.7}, "rleg": {"x": 1.0}, "lup": {"x": 0.25}, "lleg": {"x": 0.3}, "drop": 0.1})
	var land: Dictionary = Poses.add(base, {"spine": {"x": 0.2}, "rup": {"x": -0.5}, "rleg": {"x": 0.8}, "lup": {"x": -0.5}, "lleg": {"x": 0.8}, "drop": 0.14})
	A["DodgeB"] = {"d": 1.0, "n": 32, "ev": {"push": 0.05, "land": 0.62}, "k": [mk.call(0.0, base), mk.call(0.25, back, "out"), mk.call(0.65, land, "in"), mk.call(1.0, base, "io")]}
	# блок: удар пришёл в оружие — корпус отбрасывает назад, ноги пружинят, возврат в блок
	if A.has("Block"):
		var b0: Array = A["Block"]["k"][0]
		var bp: Dictionary = b0[1]
		var bik = b0[2] if b0.size() > 2 and b0[2] is Dictionary else null
		var bk := func(t: float, pose: Dictionary, ease := "") -> Array:
			var r: Array = [t, pose]
			if bik != null:
				r.append(bik)
			if ease != "":
				r.append(ease)
			return r
		A["BlockHit"] = {"d": 1.0, "n": 24, "ground": true, "ev": {"impact": 0.0}, "k": [bk.call(0.0, Poses.add(bp, {"spine": {"x": -0.18}, "hips": {"x": -0.08}, "head": {"x": 0.12}, "drop": 0.05})),
			bk.call(0.4, Poses.add(bp, {"spine": {"x": -0.06}}), "out"), bk.call(1.0, bp, "io")]}
		A["BlockHeavy"] = {"d": 1.0, "n": 32, "ground": true, "ev": {"impact": 0.0}, "k": [bk.call(0.0, Poses.add(bp, {"spine": {"x": -0.38}, "hips": {"x": -0.16}, "head": {"x": 0.25}, "rup": {"x": -0.4}, "rleg": {"x": 0.7}, "lup": {"x": -0.4}, "lleg": {"x": 0.7}, "drop": 0.16})),
			bk.call(0.3, Poses.add(bp, {"spine": {"x": -0.3}, "hips": {"x": -0.12}, "rup": {"x": -0.3}, "rleg": {"x": 0.55}, "lup": {"x": -0.3}, "lleg": {"x": 0.55}, "drop": 0.12}), "lin"),
			bk.call(0.7, Poses.add(bp, {"spine": {"x": -0.08}, "drop": 0.03}), "out"), bk.call(1.0, bp, "io")]}

## Пахан с балоном: от скуки поднимает балон, осматривает, перехватывает и возвращает в стойку
static func add_pahan(A: Dictionary) -> void:
	var idle_ik := Poses.W(Poses.PH_HOLD, Poses.PH_DIR)
	var side := Poses.W([-0.2, 0.31, 0.07], [-0.85, -0.45, 0.25])
	var look := Poses.W([-0.14, 0.5, 0.2], [0.35, 0.72, 0.6])        # балон перед собой, донышком вверх и вперёд
	var look2 := Poses.W([-0.12, 0.52, 0.2], [0.6, 0.6, 0.52])       # повернул кистью
	A["IdleVar"] = {"d": 1.0, "n": 64, "ground": true, "ev": {"grip": 0.62}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.12, Poses.ph(Poses.tw(-0.05, -0.05, 0.05)), side, "io"],
		[0.3, Poses.ph(Poses.add(Poses.tw(0.05, 0.1, 0.06), {"head": {"x": 0.28, "y": 0.3}})), look, "io"],
		[0.5, Poses.ph(Poses.add(Poses.tw(0.05, 0.12, 0.06), {"head": {"x": 0.3, "y": 0.2, "z": 0.1}})), look2, "io"],
		[0.64, Poses.ph(Poses.add(Poses.tw(0.0, 0.05, 0.02), {"head": {"x": 0.15}})), look, "io"],
		[0.8, Poses.ph(Poses.add(Poses.tw(-0.05, -0.08, 0.0), {"larm": {"x": -0.35, "z": 0.45}, "spine": {"z": 0.08}, "head": {"z": -0.12}})), side, "io"],
		[1.0, Poses.ph({}), idle_ik, "io"]]}
