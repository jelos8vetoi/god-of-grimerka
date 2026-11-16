## Клипы madk1d: кулаки и ноги, быстрый и подвижный. Боевая основа (этап 02) и движения этапа 03 (MadkMoves).
class_name MadkClips


# ---------- madk1d в бою: кулаки, боксёрская стойка. Основа под его будущий стиль и Tag Team ----------
const GUARD := {"rarm": {"x": -0.9, "y": 0.25, "z": -0.15}, "rfa": {"x": -1.9}, "larm": {"x": -1.0, "y": -0.25, "z": 0.15}, "lfa": {"x": -1.95},
	"spine": {"x": 0.12}, "head": {"x": 0.08}, "lup": {"x": -0.3}, "lleg": {"x": 0.35}, "rup": {"x": 0.05}, "rleg": {"x": 0.4}}

static func mg(o: Dictionary) -> Dictionary:
	return Poses.add(Poses.add(Poses.MKD, GUARD), o)

static func combat() -> Dictionary:
	var M := Callable(Poses, "mk")
	var sq := {"rup": {"x": -0.35}, "rleg": {"x": 0.55}, "lup": {"x": -0.35}, "lleg": {"x": 0.55}}
	var squat := {"rup": {"x": -0.75}, "rleg": {"x": 1.15}, "lup": {"x": -0.75}, "lleg": {"x": 1.15}}
	var g := mg({})
	var down := Poses._down(M)
	var walk := Poses.run_keys(M, Poses.WALK_HALF, 0.06, 0.3, -0.45)
	var sprint := Poses.run_keys(M, Poses.SPRINT_HALF, 0.34, 0.95, -1.45)
	return {
		"CombatIdle": {"d": 0.8, "loop": true, "ground": true, "ease": "io", "k": [[0.0, g], [0.5, mg({"rleg": {"x": 0.12}, "lleg": {"x": 0.12}, "rup": {"x": -0.07}, "lup": {"x": -0.07}, "spine": {"x": 0.03}})], [1.0, g]]},
		"Walk": {"d": 1.0, "loop": true, "smooth": true, "ground": true, "k": walk, "ev": Poses.STEPS},
		"Sprint": {"d": 0.44, "loop": true, "smooth": true, "ground": true, "k": sprint, "ev": Poses.STEPS},
		# уклон: нырок вбок и вниз, руки у лица
		"Dodge": {"d": 1.0, "ground": true, "k": [[0.0, g], [0.3, mg(Poses.add(sq, {"spine": {"z": 0.32, "x": 0.15}, "hips": {"y": 0.25}, "head": {"z": -0.15}})), "out"], [0.6, mg(Poses.add(sq, {"spine": {"z": 0.25}})), "io"], [1.0, g, "io"]]},
		"PerfectDodge": {"d": 1.0, "ground": true, "ev": {"counter": 0.3}, "k": [[0.0, g], [0.25, mg(Poses.add(squat, {"spine": {"x": 0.45, "y": -0.3}})), "out"],
			[0.55, mg(Poses.add(sq, {"spine": {"y": -0.45}, "rarm": {"z": 0.3}})), "io"], [1.0, g, "io"]]},
		"Block": {"d": 1.0, "loop": true, "ground": true, "k": [[0.0, Poses.mk(Poses.add(sq, {"spine": {"x": 0.22}, "head": {"x": 0.2}, "rarm": {"x": -1.3, "y": 0.45}, "larm": {"x": -1.3, "y": -0.45}, "rfa": {"x": -1.95}, "lfa": {"x": -1.95}}))],
			[1.0, Poses.mk(Poses.add(sq, {"spine": {"x": 0.22}, "head": {"x": 0.2}, "rarm": {"x": -1.3, "y": 0.45}, "larm": {"x": -1.3, "y": -0.45}, "rfa": {"x": -1.95}, "lfa": {"x": -1.95}}))]]},
		"Parry": {"d": 1.0, "ground": true, "ev": {"parry": 0.2}, "k": [[0.0, g], [0.2, mg({"spine": {"x": 0.25, "y": 0.3}, "larm": {"x": -0.55, "y": -0.7}, "lfa": {"x": -0.4}}), "out"], [0.55, mg({"spine": {"y": 0.2}}), "io"], [1.0, g, "io"]]},
		# джеб левой
		"Light": {"d": 1.0, "ground": true, "ev": {"hit": 0.42}, "k": [[0.0, g], [0.25, mg({"spine": {"y": 0.15}, "larm": {"x": 0.15}}), "out"],
			[0.42, mg({"spine": {"y": -0.35, "x": 0.18}, "larm": {"x": -0.6, "y": 0.25, "z": -0.15}, "lfa": {"x": 1.85}, "lup": {"x": -0.2}}), "in"], [0.6, mg({"spine": {"y": -0.3, "x": 0.15}, "larm": {"x": -0.5, "y": 0.2, "z": -0.1}, "lfa": {"x": 1.6}}), "out2"], [1.0, g, "io"]]},
		# хук правой: корпус и таз доворачивают руку
		"Heavy": {"d": 1.0, "ground": true, "ev": {"hit": 0.55}, "k": [[0.0, g], [0.35, mg(Poses.add(sq, {"hips": {"y": -0.3}, "spine": {"y": -0.5}, "rarm": {"x": 0.9, "y": -0.75, "z": -0.75}, "rfa": {"x": 1.6, "y": 1.2}, "head": {"y": 0.3}})), "out"],
			[0.55, mg({"hips": {"y": 0.35}, "spine": {"y": 0.6, "x": 0.2}, "rarm": {"x": 0.9, "y": 0.65, "z": -0.9}, "rfa": {"x": 1.6, "y": 0.9}, "rup": {"x": 0.15}, "rleg": {"x": 0.2}}), "in"],
			[0.75, mg({"hips": {"y": 0.4}, "spine": {"y": 0.7, "x": 0.2}, "rarm": {"x": 0.9, "y": 0.85, "z": -0.9}, "rfa": {"x": 1.6, "y": 0.9}}), "out2"], [1.0, g, "io"]]},
		# апперкот: присел, вес на правую — и вверх всем телом
		"Launcher": {"d": 1.0, "ground": true, "ev": {"hit": 0.5}, "k": [[0.0, g], [0.3, mg(Poses.add(squat, {"spine": {"y": -0.35, "x": 0.25}, "rarm": {"x": 0.7}, "rfa": {"x": 0.3}})), "out"],
			[0.5, mg({"lift": 0.05, "spine": {"y": 0.3, "x": -0.25}, "head": {"x": -0.2}, "rarm": {"x": -1.4, "z": 0.3}, "rfa": {"x": 0.1}}), "in"], [0.7, mg({"lift": 0.03, "spine": {"y": 0.3, "x": -0.2}, "rarm": {"x": -1.35, "z": 0.3}, "rfa": {"x": 0.1}}), "out2"], [1.0, g, "io"]]},
		# в воздухе: удар двумя ногами вперёд
		"AirAttack": {"d": 1.0, "ev": {"hit": 0.45}, "k": [[0.0, mg({"rup": {"x": -1.0}, "rleg": {"x": 1.6}, "lup": {"x": -0.8}, "lleg": {"x": 1.5}})],
			[0.45, mg({"spine": {"x": -0.35}, "rup": {"x": -1.3}, "rleg": {"x": -0.4}, "lup": {"x": -1.0}, "lleg": {"x": -0.35}}), "in"],
			[0.7, mg({"spine": {"x": -0.3}, "rup": {"x": -1.25}, "rleg": {"x": -0.3}, "lup": {"x": -0.95}, "lleg": {"x": -0.25}}), "out2"],
			[1.0, mg({"rup": {"x": -0.7}, "rleg": {"x": 1.2}, "lup": {"x": -0.5}, "lleg": {"x": 1.0}}), "io"]]},
		"Landing": {"d": 1.0, "ground": true, "ev": {"land": 0.1}, "k": [[0.0, mg(sq)], [0.2, mg(Poses.add(squat, {"spine": {"x": 0.35}, "rarm": {"z": 0.4}, "larm": {"z": -0.4}})), "out"], [1.0, g, "io"]]},
		"Stagger": {"d": 1.0, "ground": true, "k": [[0.0, g], [0.2, Poses.mk({"hips": {"y": 0.2}, "spine": {"x": -0.4, "y": 0.3}, "head": {"x": -0.35}, "rarm": {"z": -0.6, "x": -0.3}, "larm": {"z": 0.9, "x": -0.4}, "rup": {"x": 0.25}, "lup": {"x": -0.45}, "lleg": {"x": 0.3}}), "out"],
			[0.5, mg(Poses.add(sq, {"spine": {"x": 0.3}})), "io"], [1.0, g, "io"]]},
		"Knockback": {"d": 1.0, "ground": true, "k": [[0.0, g], [0.15, Poses.mk({"hips": {"x": -0.15}, "spine": {"x": -0.55}, "head": {"x": -0.5}, "rarm": {"x": -1.2, "z": -0.5}, "larm": {"x": -1.2, "z": 0.5}, "rup": {"x": -0.4}, "rleg": {"x": 0.6}, "lup": {"x": -0.4}, "lleg": {"x": 0.6}}), "out"],
			[0.45, mg(Poses.add(squat, {"spine": {"x": 0.3}, "rarm": {"z": 0.5}, "larm": {"z": -0.5}})), "io"], [0.75, mg(sq), "io"], [1.0, g, "io"]]},
		"Knockdown": {"d": 1.0, "ev": {"ground": 0.5}, "k": [[0.0, g], [0.14, Poses.mk({"hips": {"x": -0.6}, "spine": {"x": -0.3}, "rup": {"x": -0.6}, "lup": {"x": -0.4}, "rarm": {"x": -1.0}, "larm": {"x": -1.0}, "drop": 0.12}), "out"],
			[0.5, Poses.mk({"hips": {"x": -1.5}, "rarm": {"z": -0.8}, "larm": {"z": 0.8}, "rup": {"x": -0.5}, "lup": {"x": -0.3}, "drop": 0.78}), "in"],
			[0.62, Poses.mk({"hips": {"x": -1.42}, "rarm": {"z": -0.9}, "larm": {"z": 0.9}, "rup": {"x": -0.3}, "head": {"x": -0.15}, "drop": 0.75}), "out"], [1.0, down, "io"]]},
		"Recovery": {"d": 1.0, "k": [[0.0, down], [0.35, Poses.mk({"hips": {"x": -0.5}, "spine": {"x": 0.7}, "rup": {"x": -1.6}, "lup": {"x": -1.6}, "rleg": {"x": 1.9}, "lleg": {"x": 1.9}, "rarm": {"x": 0.5}, "larm": {"x": 0.5}, "drop": 0.62}), "io"],
			[0.7, Poses.mk({"spine": {"x": 0.5}, "rup": {"x": -1.2}, "lup": {"x": -1.2}, "rleg": {"x": 1.8}, "lleg": {"x": 1.8}, "drop": 0.38}), "io"], [1.0, g, "io"]]},
		# Tag Team: влетает в кадр, приземление, хайп обеими руками — и в стойку
		"TagIn": {"d": 1.0, "ground": true, "ev": {"land": 0.12, "ready": 0.85}, "k": [[0.0, mg(Poses.add(squat, {"spine": {"x": 0.3}}))], [0.15, mg(Poses.add(squat, {"spine": {"x": 0.45}, "rarm": {"z": 0.5}, "larm": {"z": -0.5}})), "out"],
			[0.45, Poses.mk({"spine": {"x": -0.2}, "head": {"x": -0.25}, "rarm": {"x": -2.2, "z": -0.2}, "larm": {"x": -2.2, "z": 0.2}, "rfa": {"x": -0.3}, "lfa": {"x": -0.3}}), "out"],
			[0.65, Poses.mk({"spine": {"x": -0.15}, "head": {"x": -0.2}, "rarm": {"x": -2.1, "z": -0.2}, "larm": {"x": -2.1, "z": 0.2}, "rfa": {"x": -0.5}, "lfa": {"x": -0.5}}), "io"], [1.0, g, "io"]]},
		"TagOut": {"d": 1.0, "ground": true, "ev": {"call": 0.3, "leave": 0.9}, "k": [[0.0, g], [0.3, Poses.mk({"hips": {"y": 0.3}, "spine": {"y": 0.35}, "head": {"y": 0.3}, "rarm": {"x": -2.4, "z": -0.3}, "rfa": {"x": -0.4}}), "io"],
			[0.6, Poses.mk(Poses.add(sq, {"spine": {"x": -0.1}, "rarm": {"x": -1.6}, "rfa": {"x": -0.8}})), "io"], [1.0, Poses.mk(Poses.add(squat, {"spine": {"x": 0.4}, "rarm": {"x": 0.6}, "larm": {"x": 0.6}})), "in"]]},
	}
