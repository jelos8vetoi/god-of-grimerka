## Клипы врагов «5 НОЧЕЙ С ПАХАНОМ» — поверх базовых наборов Poses (те же кости и правила).
## У каждого: неестественная неподвижность с редким рывком (FNStill), взгляд в камеру с неправильным наклоном
## головы (FNStare), своя походка (FNWalk), выглядывание в проём (FNPeek) и свой скример (FNScare).
## MADK1D ещё ползёт по шахте (FNCrawl) и висит вниз головой (FNHang).
class_name FNPoses

static func en(o: Dictionary) -> Dictionary:
	return Poses.en(o)

static func mk(o: Dictionary) -> Dictionary:
	return Poses.mk(o)

## зеркало позы по бокам: вращения вокруг Y и Z меняют знак, правые и левые кости меняются местами
static func mirror(o: Dictionary) -> Dictionary:
	var m := {}
	for k in o:
		var key := String(k)
		var v: Dictionary = o[k] if o[k] is Dictionary else {}
		if not (o[k] is Dictionary):
			m[k] = o[k]
			continue
		var nk := key
		if key.length() > 2 and key[0] in ["r", "l"] and key.substr(1) in ["arm", "up", "leg", "fa", "hand"]:
			nk = ("l" if key[0] == "r" else "r") + key.substr(1)
		m[nk] = {"x": float(v.get("x", 0.0)), "y": -float(v.get("y", 0.0)), "z": -float(v.get("z", 0.0))}
	return m

## у двери: сдержанная стойка вместо «сидя на пороге» — наклон корпуса не больше 9°, взгляд на охранника, редкий довод головы и замирание
static func _door(base: Callable, door: Dictionary, d := 6.0) -> Dictionary:
	var A: Dictionary = base.call(door)
	var aim: Dictionary = base.call(Poses.add(door, {"head": {"z": -0.12, "y": 0.18}, "neck": {"z": -0.06}}))
	var sway1: Dictionary = base.call(Poses.add(door, {"spine": {"z": -0.02}}))
	var sway2: Dictionary = base.call(Poses.add(door, {"spine": {"z": 0.02}}))
	return {"d": d, "loop": true, "ease": "io", "k": [[0.0, A], [0.18, sway1], [0.36, A], [0.5, aim, "out"], [0.62, aim], [0.7, aim], [0.82, sway2], [1.0, A]]}

## сейчас войдёт: тот же наклон, руки начинают подниматься (амплитуда на 40 % меньше прежней)
static func _door_lunge(base: Callable, door: Dictionary) -> Dictionary:
	var L1: Dictionary = base.call(Poses.add(door, {"spine": {"x": 0.12}}))
	var L2: Dictionary = base.call(Poses.add(door, {"spine": {"x": 0.3}, "head": {"x": -0.18}, "rarm": {"x": -0.72, "z": -0.3}, "larm": {"x": -0.72, "z": 0.3}, "rfa": {"x": -0.36}, "lfa": {"x": -0.36}}))
	return {"d": 1.4, "loop": true, "k": [[0.0, L1], [0.35, L2, "out"], [0.55, Poses.add(base.call(Poses.add(door, {"spine": {"x": 0.3}, "head": {"x": -0.18}})), {"head": {"z": 0.18}}), "io"], [0.8, L2], [1.0, L1, "in"]]}

## общие для всех врагов на основе «руки опущены»
static func _common(base: Callable, still: Dictionary, stare: Dictionary, peek: Dictionary, door := {}) -> Dictionary:
	var S: Dictionary = base.call(still)
	var tw: Dictionary = base.call(Poses.add(still, {"head": {"z": 0.32, "y": -0.25}, "neck": {"z": 0.1}}))
	var R: Dictionary = base.call(stare)
	var R2: Dictionary = base.call(Poses.add(stare, {"head": {"z": 0.12, "x": 0.06}}))
	var a1: Dictionary = base.call(Poses.add(still, {"spine": {"x": 0.3, "z": 0.08}, "head": {"x": -0.28, "z": 0.35}, "rup": {"x": -0.42}, "rleg": {"x": 0.35}, "lup": {"x": 0.18}, "rarm": {"x": -0.55}, "larm": {"x": -0.35}}))
	var a2: Dictionary = base.call(Poses.add(still, {"spine": {"x": 0.3, "z": -0.08}, "head": {"x": -0.28, "z": -0.2}, "lup": {"x": -0.42}, "lleg": {"x": 0.35}, "rup": {"x": 0.18}, "larm": {"x": -0.55}, "rarm": {"x": -0.35}}))
	var b1: Dictionary = base.call(Poses.add(still, {"spine": {"x": -0.18}, "head": {"x": 0.35}, "rup": {"x": 0.3}, "lup": {"x": -0.1}}))
	var b2: Dictionary = base.call(Poses.add(still, {"spine": {"x": -0.18}, "head": {"x": 0.35, "z": 0.2}, "lup": {"x": 0.3}, "rup": {"x": -0.1}}))
	var L1: Dictionary = base.call(Poses.add(peek, {"spine": {"x": 0.25}}))
	var L2: Dictionary = base.call(Poses.add(peek, {"spine": {"x": 0.55}, "head": {"x": -0.3}, "rarm": {"x": -1.2, "z": -0.5}, "larm": {"x": -1.2, "z": 0.5}, "rfa": {"x": -0.6}, "lfa": {"x": -0.6}}))
	var extra := {}
	if not door.is_empty():
		var dm := mirror(door)
		extra = {"FNPeekL": _door(base, door), "FNPeekR": _door(base, dm, 5.5), "FNLungeL": _door_lunge(base, door), "FNLungeR": _door_lunge(base, dm)}
	return extra.merged({
		# стоит, не дышит; под конец цикла голова дёргается вбок и медленно возвращается
		"FNStill": {"d": 5.0, "loop": true, "k": [[0.0, S], [0.86, S], [0.88, tw, "out"], [0.97, S, "io"], [1.0, S]]},
		# смотрит прямо в камеру: голова завалена набок, иногда ещё сильнее
		"FNStare": {"d": 3.6, "loop": true, "k": [[0.0, R], [0.45, R], [0.5, R2, "out"], [0.9, R2], [1.0, R, "io"]]},
		"FNPeek": {"d": 4.0, "loop": true, "ease": "io", "k": [[0.0, base.call(peek)], [0.5, base.call(Poses.add(peek, {"head": {"z": 0.12}, "spine": {"z": 0.05}}))], [1.0, base.call(peek)]]},
		# приближается: шаг — замер — шаг, корпус вперёд, руки висят; между шагами голова «не успевает» за телом
		"FNApproach": {"d": 2.8, "loop": true, "k": [[0.0, a1], [0.42, a1], [0.5, a2, "out"], [0.62, Poses.add(a2, {"head": {"z": -0.35}}), "out"], [0.92, a2], [1.0, a1, "out"]]},
		# пятится от двери, не отводя глаз: корпус назад, голова наклонена вперёд
		"FNRetreat": {"d": 2.2, "loop": true, "ease": "io", "k": [[0.0, b1], [0.5, b2], [1.0, b1]]},
		# сейчас войдёт: у проёма подаётся вперёд, руки поднимаются — честный знак «закрывай дверь»
		"FNLunge": {"d": 1.4, "loop": true, "k": [[0.0, L1], [0.35, L2, "out"], [0.55, Poses.add(L2, {"head": {"z": 0.3}}), "io"], [0.8, L2], [1.0, L1, "in"]]},
	})

## шаг: полупроходка из фаз [бедро и голень ведущей ноги, толчковой, просадка]
static func _walk(base: Callable, extra_a: Dictionary, extra_b: Dictionary, d := 1.3) -> Dictionary:
	var k: Array = []
	var H := [[-0.38, 0.1, 0.28, 0.25, 0.0], [-0.12, 0.35, 0.05, 0.55, 0.02], [0.25, 0.1, -0.35, 0.2, 0.0], [0.05, 0.05, -0.1, 0.5, 0.01]]
	for side in 2:
		for i in H.size():
			var h: Array = H[i]
			var lead := "r" if side == 0 else "l"
			var trail := "l" if side == 0 else "r"
			var p := {lead + "up": {"x": h[0]}, lead + "leg": {"x": h[1]}, trail + "up": {"x": h[2]}, trail + "leg": {"x": h[3]}, "drop": h[4]}
			p = Poses.add(p, extra_a if side == 0 else extra_b)
			k.append([float(side * H.size() + i) / float(2 * H.size()), base.call(p)])
	k.append([1.0, k[0][1]])
	return {"d": d, "loop": true, "smooth": true, "k": k}

# ---------------- БАЛОН: маскот на теле бота, голова — огромный балон ----------------
static func balon() -> Dictionary:
	var A := Poses.bot()
	var still := {"spine": {"x": 0.14, "z": 0.05}, "head": {"z": 0.42, "x": 0.1}, "rarm": {"z": 0.18}, "larm": {"z": -0.12}, "rfa": {"x": 0.2}, "lfa": {"x": 0.2}}
	var stare := {"spine": {"x": 0.05}, "head": {"z": 0.75, "x": -0.12}, "neck": {"z": 0.25}, "rarm": {"z": 0.2}, "larm": {"z": -0.2}}
	var peek := {"spine": {"z": -0.42, "x": 0.15}, "head": {"z": -0.55}, "rarm": {"x": -1.9, "z": -0.6}, "rfa": {"x": -0.5}, "lup": {"z": -0.12}}
	var door := {"spine": {"z": 0.0, "x": 0.1}, "head": {"z": -0.5, "x": 0.12}, "rarm": {"z": 0.12}, "larm": {"z": -0.1}, "rfa": {"x": 0.2}, "lfa": {"x": 0.2}}
	A.merge(_common(Callable(FNPoses, "en"), still, stare, peek, door), true)
	# тяжёлая раскачивающаяся походка: корпус валится с боку на бок
	A["FNWalk"] = _walk(Callable(FNPoses, "en"), {"spine": {"z": 0.16, "x": 0.12}, "head": {"z": 0.3}}, {"spine": {"z": -0.16, "x": 0.12}, "head": {"z": -0.1}}, 1.7)
	# скример: снизу из-под стола → выпрямился во весь рост, руки в стороны, голова рывком вперёд
	var crouch := en({"spine": {"x": 0.9}, "head": {"x": 0.6, "z": 0.9}, "rarm": {"z": 0.4, "x": 0.4}, "larm": {"z": -0.4, "x": 0.4}, "rup": {"x": -1.2}, "lup": {"x": -1.2}, "rleg": {"x": 1.9}, "lleg": {"x": 1.9}, "drop": 0.42})
	var up := en({"spine": {"x": -0.15}, "head": {"x": -0.25, "z": 0.0}, "rarm": {"z": -0.9, "x": -1.9}, "larm": {"z": 0.9, "x": -1.9}, "rfa": {"x": -0.4}, "lfa": {"x": -0.4}})
	var lunge := en({"spine": {"x": 0.55}, "spine2": {"x": 0.2}, "head": {"x": 0.35, "z": 0.12}, "rarm": {"z": -0.4, "x": -1.5}, "larm": {"z": 0.4, "x": -1.5}, "rfa": {"x": -0.9}, "lfa": {"x": -0.9}, "drop": 0.05})
	A["FNScare"] = {"d": 1.2, "k": [[0.0, crouch], [0.18, crouch], [0.32, up, "out"], [0.42, Poses.add(up, {"head": {"z": 0.5}}), "in"], [0.5, lunge, "out"], [0.75, Poses.add(lunge, {"head": {"z": -0.15, "x": 0.45}}), "io"], [1.0, lunge]]}
	return A

# ---------------- MADK1D: ползёт по шахте, висит вниз головой ----------------
static func madk1d() -> Dictionary:
	var A := Poses.madk1d()
	var still := {"spine": {"x": 0.2}, "head": {"z": -0.4, "x": 0.2}, "rarm": {"z": 0.05}, "larm": {"z": -0.05}}
	var stare := {"head": {"z": -0.85, "x": -0.15}, "neck": {"z": -0.2}, "spine": {"x": 0.1}}
	var peek := {"spine": {"z": 0.45, "x": 0.2}, "head": {"z": 0.6}, "larm": {"x": -1.8, "z": 0.6}}
	var door := {"spine": {"z": 0.0, "x": 0.2}, "head": {"z": -0.4}, "rarm": {"z": 0.05}, "larm": {"z": -0.05}}
	A.merge(_common(Callable(FNPoses, "mk"), still, stare, peek, door), true)
	A["FNWalk"] = _walk(Callable(FNPoses, "mk"), {"spine": {"x": 0.3}, "head": {"x": -0.2}}, {"spine": {"x": 0.3}, "head": {"x": -0.2}}, 0.9)
	# ползёт (риг повёрнут лицом вниз): руки по очереди тянутся вперёд, колени подтягиваются
	var c1 := mk({"rarm": {"x": -2.7, "z": -1.0}, "larm": {"x": -1.6, "z": 0.9}, "rfa": {"x": -0.2}, "lfa": {"x": -1.3}, "rup": {"x": -0.9}, "rleg": {"x": 1.6}, "lup": {"x": -0.2}, "lleg": {"x": 0.6}, "head": {"x": -0.9}})
	var c2 := mk({"larm": {"x": -2.7, "z": 1.0}, "rarm": {"x": -1.6, "z": -0.9}, "lfa": {"x": -0.2}, "rfa": {"x": -1.3}, "lup": {"x": -0.9}, "lleg": {"x": 1.6}, "rup": {"x": -0.2}, "rleg": {"x": 0.6}, "head": {"x": -0.9}})
	A["FNCrawl"] = {"d": 1.4, "loop": true, "smooth": true, "k": [[0.0, c1], [0.5, c2], [1.0, c1]]}
	# висит вниз головой из люка (риг перевёрнут): руки свисают к лицу Пахана, голова проворачивается
	var h1 := mk({"rarm": {"z": -1.9, "x": -0.3}, "larm": {"z": 1.9, "x": -0.3}, "rfa": {"x": -0.3}, "lfa": {"x": -0.3}, "head": {"y": 1.4, "z": 0.3}, "rup": {"x": 0.2}, "lup": {"x": -0.2}})
	var h2 := mk({"rarm": {"z": -2.1, "x": -1.2}, "larm": {"z": 2.1, "x": -1.2}, "rfa": {"x": -1.0}, "lfa": {"x": -1.0}, "head": {"y": 0.0, "x": 0.4}, "spine": {"x": -0.3}})
	A["FNHang"] = {"d": 2.0, "loop": true, "ease": "io", "k": [[0.0, h1], [0.5, Poses.add(h1, {"head": {"y": -0.2}})], [1.0, h1]]}
	# скример: приземлился на стол на корточки, голова набок → прыжок к лицу, руки вперёд и в стороны
	var crouch := mk({"spine": {"x": 0.75}, "head": {"x": -0.55, "z": 0.6}, "rarm": {"x": -1.2, "z": -0.6}, "larm": {"x": -1.2, "z": 0.6}, "rfa": {"x": -0.6}, "lfa": {"x": -0.6}, "rup": {"x": -1.5}, "lup": {"x": -1.5}, "rleg": {"x": 2.0}, "lleg": {"x": 2.0}, "drop": 0.45})
	var spring := mk({"spine": {"x": 0.35}, "head": {"x": -0.25, "z": -0.2}, "rarm": {"x": -2.0, "z": -1.1}, "larm": {"x": -2.0, "z": 1.1}, "rfa": {"x": -0.2}, "lfa": {"x": -0.2}, "rup": {"x": -0.8}, "lup": {"x": -0.8}, "rleg": {"x": 1.0}, "lleg": {"x": 1.0}, "drop": 0.2})
	A["FNScare"] = {"d": 1.1, "k": [[0.0, crouch], [0.3, Poses.add(crouch, {"head": {"z": 0.4}}), "io"], [0.42, spring, "out"], [0.75, Poses.add(spring, {"head": {"z": 0.35}}), "io"], [1.0, spring]]}
	return A

# ---------------- BOT: механический, рывками ----------------
static func bot() -> Dictionary:
	var A := Poses.bot()
	var still := {"spine": {"x": -0.04}, "head": {"y": 0.5}, "rarm": {"z": 0.12}, "larm": {"z": -0.12}, "rfa": {"x": 0.25}, "lfa": {"x": 0.25}}
	var stare := {"head": {"y": 0.0, "z": 0.0, "x": 0.25}, "spine": {"x": 0.12}, "rarm": {"x": -0.3}, "larm": {"x": -0.3}}
	var peek := {"spine": {"z": -0.3}, "head": {"y": -0.9}, "rarm": {"x": -1.6}, "rfa": {"x": -0.2}}
	var door := {"spine": {"z": 0.0, "x": 0.02}, "head": {"y": -0.55}, "rarm": {"z": 0.1}, "larm": {"z": -0.1}, "rfa": {"x": 0.25}, "lfa": {"x": 0.25}}
	A.merge(_common(Callable(FNPoses, "en"), still, stare, peek, door), true)
	# дёрганая походка: ступени без плавности, руки не двигаются
	var w := _walk(Callable(FNPoses, "en"), {"head": {"y": 0.3}, "rarm": {"x": -0.2}, "larm": {"x": -0.2}}, {"head": {"y": -0.3}, "rarm": {"x": -0.2}, "larm": {"x": -0.2}}, 1.2)
	w.erase("smooth")
	w["n"] = 10
	A["FNWalk"] = w
	var reach := en({"rarm": {"x": -1.55, "z": -1.1}, "larm": {"x": -1.55, "z": 1.1}, "rfa": {"x": -0.05}, "lfa": {"x": -0.05}, "spine": {"x": 0.25}, "head": {"x": 0.2}})
	var k: Array = [[0.0, en({"head": {"y": 0.9}})], [0.15, en({"head": {"y": 0.9}})]]
	for i in 12:                                    # голова дёргается туда-сюда всё быстрее
		var u := 0.2 + float(i) * 0.05
		k.append([u, Poses.add(reach, {"head": {"y": 0.7 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - float(i) / 13.0), "z": 0.3 * (1.0 if i % 3 == 0 else -0.5)}})])
	k.append([1.0, Poses.add(reach, {"head": {"x": 0.3}})])
	A["FNScare"] = {"d": 1.1, "n": 40, "k": k}
	return A

# ---------------- CLIPPER: низкий, с катаной ----------------
static func clipper() -> Dictionary:
	var A := Poses.clipper()
	var still := {"spine": {"x": 0.35}, "head": {"x": -0.35, "z": 0.2}, "rup": {"x": -0.5}, "lup": {"x": 0.2}, "rleg": {"x": 0.7}, "lleg": {"x": 0.6}, "drop": 0.12}
	var stare := {"spine": {"x": 0.45}, "head": {"x": -0.6, "z": -0.6}, "rup": {"x": -0.6}, "rleg": {"x": 0.9}, "lleg": {"x": 0.7}, "drop": 0.15}
	var peek := {"spine": {"z": 0.5, "x": 0.3}, "head": {"z": 0.7, "x": -0.2}, "drop": 0.1}
	var door := {"spine": {"z": 0.0, "x": 0.4}, "head": {"x": -0.35, "z": -0.1}, "rup": {"x": -0.45}, "lup": {"x": 0.2}, "rleg": {"x": 0.6}, "lleg": {"x": 0.5}, "drop": 0.12}
	A.merge(_common(Callable(FNPoses, "en"), still, stare, peek, door), true)
	A["FNWalk"] = A["Run"]                          # он не ходит — перебегает
	var raise := en({"spine": {"x": -0.1, "y": -0.4}, "head": {"x": -0.2}, "rarm": {"x": -2.8, "z": -0.3}, "larm": {"x": -2.6, "z": 0.3}, "rfa": {"x": -0.5}, "lfa": {"x": -0.6}})
	var cut := en({"spine": {"x": 0.6, "y": 0.4}, "head": {"x": 0.3, "z": 0.3}, "rarm": {"x": -0.7}, "larm": {"x": -0.6}, "drop": 0.06})
	A["FNScare"] = {"d": 1.0, "k": [[0.0, A["FNStill"]["k"][0][1]], [0.2, raise, "out"], [0.42, raise], [0.52, cut, "in"], [0.75, Poses.add(cut, {"head": {"z": -0.4, "x": 0.2}}), "io"], [1.0, cut]]}
	return A

# ---------------- GHOST: парит, руки висят ----------------
static func ghost() -> Dictionary:
	var A := Poses.hater()
	var still := {"spine": {"x": -0.08}, "head": {"z": 0.6, "x": 0.35}, "rarm": {"z": 0.25}, "larm": {"z": -0.25}, "rup": {"x": 0.1}, "lup": {"x": -0.05}, "lift": 0.08}
	var stare := {"head": {"z": -0.2, "x": -0.05}, "spine": {"x": 0.04}, "rarm": {"z": 0.35}, "larm": {"z": -0.35}, "lift": 0.08}
	var peek := {"spine": {"z": -0.6}, "head": {"z": -0.9}, "lift": 0.06}
	var door := {"spine": {"z": 0.0}, "head": {"z": -0.5, "x": 0.2}, "rarm": {"z": 0.25}, "larm": {"z": -0.25}, "lift": 0.08}
	A.merge(_common(Callable(FNPoses, "en"), still, stare, peek, door), true)
	A["FNWalk"] = A["FNStill"]
	var near := en({"head": {"z": 0.9, "x": 0.2}, "rarm": {"z": 0.4, "x": -0.4}, "larm": {"z": -0.4, "x": -0.4}, "lift": 0.1})
	var snap := en({"head": {"z": 0.0, "x": -0.35}, "spine": {"x": 0.4}, "rarm": {"z": -0.6, "x": -1.7}, "larm": {"z": 0.6, "x": -1.7}, "lift": 0.1})
	A["FNScare"] = {"d": 1.2, "k": [[0.0, near], [0.45, Poses.add(near, {"head": {"z": 0.25}}), "io"], [0.5, snap, "in"], [1.0, Poses.add(snap, {"head": {"y": 0.25}})]]}
	return A

# ---------------- MOD: бот в синем, удар сквозь монитор ----------------
static func mod() -> Dictionary:
	var A := Poses.bot()
	var still := {"spine": {"x": 0.08}, "head": {"x": 0.45}, "rarm": {"x": -0.4, "z": -0.1}, "rfa": {"x": -1.4}, "larm": {"x": -0.4, "z": 0.1}, "lfa": {"x": -1.4}}
	var stare := {"head": {"x": -0.1, "y": 0.35, "z": -0.4}, "rarm": {"x": -0.4}, "rfa": {"x": -1.4}, "larm": {"x": -0.4}, "lfa": {"x": -1.4}}
	var peek := {"spine": {"z": -0.35}, "head": {"z": -0.4, "y": 0.4}, "rarm": {"x": -1.7}}
	var door := {"spine": {"z": 0.0, "x": 0.12}, "head": {"x": 0.4, "z": -0.2, "y": 0.3}, "rarm": {"x": -0.4}, "rfa": {"x": -1.4}, "larm": {"x": -0.4}, "lfa": {"x": -1.4}}
	A.merge(_common(Callable(FNPoses, "en"), still, stare, peek, door), true)
	A["FNWalk"] = _walk(Callable(FNPoses, "en"), {"head": {"x": 0.3}, "rfa": {"x": -1.2}, "lfa": {"x": -1.2}}, {"head": {"x": 0.3}, "rfa": {"x": -1.2}, "lfa": {"x": -1.2}}, 1.4)
	var wind := en({"spine": {"y": -0.5, "x": -0.1}, "rarm": {"x": -0.4, "z": 0.2}, "rfa": {"x": -2.2}, "larm": {"x": -1.4}, "head": {"x": 0.1}})
	var hit := en({"spine": {"y": 0.45, "x": 0.4}, "rarm": {"x": -1.6, "z": -1.2}, "rfa": {"x": -0.05}, "larm": {"x": -0.3}, "head": {"x": 0.25}, "drop": 0.04})
	A["FNScare"] = {"d": 1.0, "k": [[0.0, A["FNStill"]["k"][0][1]], [0.3, wind, "out"], [0.42, hit, "in"], [0.7, Poses.add(hit, {"head": {"z": 0.5}}), "io"], [1.0, hit]]}
	return A

# ---------------- ПАХАН — «резервная копия» из Облака: тот же Пахан, только неправильный ----------------
static func pahan_copy() -> Dictionary:
	var A := Poses.pahan()
	var P := Callable(Poses, "ph")
	var still: Dictionary = P.call({"head": {"z": 0.85, "x": 0.25}, "neck": {"z": 0.2}, "spine": {"x": 0.12}, "rarm": {"z": 0.2}, "larm": {"z": -0.2}})
	var twist: Dictionary = P.call({"head": {"z": -0.9, "y": 0.6, "x": -0.2}, "neck": {"z": -0.25}, "spine": {"x": 0.05}})
	var lunge: Dictionary = P.call({"spine": {"x": 0.55}, "spine2": {"x": 0.2}, "head": {"x": -0.35, "z": 0.1}, "rarm": {"x": -1.9, "z": -0.9}, "larm": {"x": -1.9, "z": 0.9}, "rfa": {"x": -0.3}, "lfa": {"x": -0.3}, "drop": 0.05})
	A["FNStill"] = {"d": 3.0, "loop": true, "k": [[0.0, still], [0.9, still], [0.93, twist, "out"], [1.0, still, "io"]]}
	A["FNScare"] = {"d": 1.0, "n": 36, "k": [[0.0, still], [0.25, twist, "in"], [0.32, still, "out"], [0.42, lunge, "in"], [0.7, Poses.add(lunge, {"head": {"z": 0.5}}), "io"], [1.0, Poses.add(lunge, {"head": {"z": -0.4, "y": 0.3}})]]}
	return A

static func set_for(id: String) -> Dictionary:
	match id:
		"balon":
			return balon()
		"madk1d":
			return madk1d()
		"bot":
			return bot()
		"clipper":
			return clipper()
		"ghost":
			return ghost()
	return mod()
