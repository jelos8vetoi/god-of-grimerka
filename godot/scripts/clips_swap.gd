## Переходы между стилями: своя анимация на каждую пару (шесть у Пахана, шесть у madk1d).
## INFO: «откуда>куда» → клип и когда оружие меняется в руке:
##   stow / grab — доля клипа, на которой балон Пахана уходит за спину / приходит в кулак;
##   at — доля, на которой у madk1d старое оружие сменяется новым; spin — сколько оборотов делает тело.
## Клип нормирован по времени (d = 1): обычная смена играет его за 0,42 с, Perfect Swap — за 0,22 с.
class_name SwapClips

const INFO := {
	"vozduh>bottles": {"clip": "SwapBalonBottle", "stow": 0.44},
	"bottles>vozduh": {"clip": "SwapBottleBalon", "grab": 0.46},
	"vozduh>tyaga812": {"clip": "SwapBalonTyaga", "stow": 0.4},
	"tyaga812>vozduh": {"clip": "SwapTyagaBalon", "grab": 0.5},
	"bottles>tyaga812": {"clip": "SwapBottleTyaga"},
	"tyaga812>bottles": {"clip": "SwapTyagaBottle"},
	"skateboard>guitar": {"clip": "SwapSkateGuitar", "at": 0.5, "spin": 0.0},
	"guitar>skateboard": {"clip": "SwapGuitarSkate", "at": 0.55, "spin": 1.0},
	"skateboard>breaker": {"clip": "SwapSkateBreaker", "at": 0.32, "spin": 0.0},
	"breaker>skateboard": {"clip": "SwapBreakerSkate", "at": 0.5, "spin": 0.0},
	"guitar>breaker": {"clip": "SwapGuitarBreaker", "at": 0.45, "spin": 0.0},
	"breaker>guitar": {"clip": "SwapBreakerGuitar", "at": 0.6, "spin": 1.0},
}

static func info(from: String, to: String) -> Dictionary:
	return INFO.get(from + ">" + to, {})

## Пахан: балон, водяра, ТЯГА-812
static func add_pahan(A: Dictionary) -> void:
	var idle_ik := Poses.W(Poses.PH_HOLD, Poses.PH_DIR)
	var side := Poses.W([-0.2, 0.31, 0.07], [-0.85, -0.45, 0.25])
	var over := Poses.W([-0.18, 0.62, -0.06], [-0.3, 0.45, -0.84])
	var at_back := Poses.W([Poses.PH_HOLSTER_GRIP[0], Poses.PH_HOLSTER_GRIP[1], Poses.PH_HOLSTER_GRIP[2]], Poses.PH_HOLSTER_DIR)
	var reach: Dictionary = Poses.ph({"spine": {"y": -0.18, "x": -0.05}, "head": {"y": 0.25}})
	var t1: Dictionary = Poses.ph(Poses.tw(-0.05, -0.05, 0.1))
	var t2: Dictionary = Poses.ph(Poses.tw(-0.1, -0.1, 0.05))
	# водяра: стойка с бутылкой и рука у кармана куртки
	var bst := {"rup": {"x": -0.2}, "rleg": {"x": 0.3}, "lup": {"x": -0.32}, "lleg": {"x": 0.38}}
	var ready: Dictionary = Poses.ph(Poses.add(bst, {"spine": {"x": 0.08, "y": -0.12}, "rarm": {"x": -0.35, "z": -0.15}, "rfa": {"x": -1.1}, "larm": {"x": -0.5, "z": 0.3}, "lfa": {"x": -0.9}}))
	var pocket: Dictionary = Poses.ph(Poses.add(bst, {"spine": {"y": 0.15, "x": 0.1}, "head": {"x": 0.25, "y": -0.2}, "rarm": {"x": 0.25, "y": 0.5, "z": -0.1}, "rfa": {"x": -1.3}}))
	# пылесос: стойка с трубой в двух руках, тянется к трубе, отталкивает её
	var tst := {"rup": {"x": -0.25}, "rleg": {"x": 0.35}, "lup": {"x": -0.3}, "lleg": {"x": 0.4}}
	var stand: Dictionary = Poses.ph(Poses.add(tst, {"spine": {"x": 0.12, "y": 0.1}, "head": {"y": -0.1}}))
	var hold := TyagaClips.grip2(TyagaClips.V_HOLD)
	var catch_p: Dictionary = Poses.ph(Poses.add(tst, {"spine": {"x": 0.22, "y": 0.3}, "head": {"y": -0.3, "x": 0.1}, "larm": {"x": -1.0, "z": 0.4}, "lfa": {"x": -0.3}, "rarm": {"x": -0.7, "z": -0.25}, "rfa": {"x": -0.5}}))
	var push: Dictionary = Poses.ph(Poses.add(tst, {"spine": {"x": 0.3, "y": 0.28}, "hips": {"y": 0.15}, "head": {"y": -0.25}, "larm": {"x": -1.3, "z": 0.35}, "lfa": {"x": -0.1}, "rarm": {"x": -1.1, "z": -0.3}, "rfa": {"x": -0.2}}))
	# балон → водяра: закинул балон за плечо в чехол, той же рукой — в карман за бутылкой
	A["SwapBalonBottle"] = {"d": 1.0, "n": 40, "ground": true, "ev": {"stow": 0.44}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.16, t1, side, "io"], [0.3, t2, over, "io"], [0.42, reach, at_back, "io"], [0.48, reach, at_back, "lin"],
		[0.72, pocket, "io"], [1.0, ready, "io"]]}
	# водяра → балон: бутылку в карман, рука за плечо, балон через верх в стойку
	A["SwapBottleBalon"] = {"d": 1.0, "n": 40, "ground": true, "ev": {"grab": 0.46}, "k": [[0.0, ready],
		[0.2, pocket, "io"], [0.42, reach, at_back, "out"], [0.5, reach, at_back, "lin"],
		[0.68, t2, over, "io"], [0.84, t1, side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# балон → пылесос: балон за спину, разворот корпуса и обе руки ловят подкатившую трубу
	A["SwapBalonTyaga"] = {"d": 1.0, "n": 40, "ground": true, "ev": {"stow": 0.4}, "k": [[0.0, Poses.ph({}), idle_ik],
		[0.18, t2, over, "io"], [0.36, reach, at_back, "io"], [0.44, reach, at_back, "lin"],
		[0.66, catch_p, "io"], [1.0, stand, hold, "io"]]}
	# пылесос → балон: оттолкнул пылесос от себя, рука за плечо, балон в стойку
	A["SwapTyagaBalon"] = {"d": 1.0, "n": 40, "ground": true, "ev": {"grab": 0.5}, "k": [[0.0, stand, hold],
		[0.22, push, "out"], [0.46, reach, at_back, "io"], [0.54, reach, at_back, "lin"],
		[0.72, t2, over, "io"], [0.86, t1, side, "io"], [1.0, Poses.ph({}), idle_ik, "io"]]}
	# водяра → пылесос: бутылку в карман и сразу к трубе
	A["SwapBottleTyaga"] = {"d": 1.0, "n": 40, "ground": true, "k": [[0.0, ready],
		[0.26, pocket, "io"], [0.58, catch_p, "io"], [1.0, stand, hold, "io"]]}
	# пылесос → водяра: оттолкнул пылесос, рука в карман, бутылка наготове
	A["SwapTyagaBottle"] = {"d": 1.0, "n": 40, "ground": true, "k": [[0.0, stand, hold],
		[0.24, push, "out"], [0.6, pocket, "io"], [1.0, ready, "io"]]}

## madk1d: скейт, гитара, Breaker.
## Пока оружие в руке, его ведёт привязка Poses.W (где кулак и куда смотрит оружие) — как в ударах MSwing/MOver:
## без неё доска и гитара просто висят за кистью как попало. Начало и конец с оружием — стойка ArmedIdle (hold + rest),
## без оружия — боксёрская стойка Breaker.
static func add_madk(A: Dictionary) -> void:
	var g := MadkClips.mg({})
	var st := {"rup": {"x": -0.25}, "rleg": {"x": 0.4}, "lup": {"x": -0.3}, "lleg": {"x": 0.45}}
	var sq := {"rup": {"x": -0.6}, "rleg": {"x": 0.95}, "lup": {"x": -0.6}, "lleg": {"x": 0.95}}
	var T2 := {"two": 0.1}
	var rest := Poses.W([-0.18, 0.36, 0.04], [-0.1, -0.4, -0.9])          # у бедра, концом назад
	var side := Poses.W([-0.2, 0.37, 0.06], [-0.92, -0.3, 0.1])           # сбоку, концом наружу
	var out_r := Poses.W([-0.28, 0.42, 0.0], [-0.92, 0.02, -0.38])        # на вытянутой руке вправо
	var shoulder := Poses.W([-0.2, 0.6, -0.04], [-0.2, 0.6, -0.77])       # над правым плечом, концом за спину
	var front_dn := Poses.W([-0.1, 0.36, 0.22], [0.1, -0.3, 0.95], T2)    # перед собой, концом вперёд-вниз, двумя руками
	var overhead := Poses.W([-0.06, 0.66, 0.14], [0.0, 0.95, -0.3], T2)   # над головой двумя руками
	var hold: Dictionary = Poses.mk(Poses.add(st, {"spine": {"x": 0.1, "y": -0.12}, "larm": {"x": -0.7, "y": -0.2}, "lfa": {"x": -1.5}}))
	# скейт → гитара: доску отводит и швыряет вперёд, рука за плечо — гитара, взмах вниз в стойку
	A["SwapSkateGuitar"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.5}, "k": [[0.0, hold, rest],
		[0.2, Poses.mk(Poses.add(st, Poses.tw(-0.2, -0.25, 0.0))), out_r, "out"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.2, 0.25, 0.08))), Poses.W([-0.2, 0.42, 0.22], [-0.45, 0.05, 0.89]), "in"],
		[0.56, Poses.mk(Poses.add(st, Poses.tw(-0.1, -0.15, -0.1))), shoulder, "io"],
		[0.8, Poses.mk(Poses.add(sq, Poses.tw(0.1, 0.15, 0.2))), front_dn, "in"],
		[0.92, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# гитара → скейт: оборот с гитарой на вытянутой руке, доска с размаху встаёт перед собой
	A["SwapGuitarSkate"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.55}, "k": [[0.0, hold, rest],
		[0.3, Poses.mk(Poses.add(sq, {"larm": {"z": 0.9}})), out_r, "out"],
		[0.5, Poses.mk(Poses.add(sq, {"larm": {"z": 0.9}})), out_r, "lin"],
		[0.66, Poses.mk(Poses.add(sq, Poses.tw(0.0, 0.0, 0.32))), front_dn, "in"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# скейт → Breaker: отбрасывает доску в сторону, прыжок с поджатыми ногами, стойка
	A["SwapSkateBreaker"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.32}, "k": [[0.0, hold, rest],
		[0.14, hold, side, "io"],
		[0.3, Poses.mk(Poses.add(st, Poses.tw(-0.25, -0.3, 0.0))), Poses.W([-0.32, 0.44, -0.02], [-0.95, 0.12, -0.28]), "out"],
		[0.56, Poses.mk({"drop": -0.16, "rup": {"x": -1.0}, "rleg": {"x": 1.4}, "lup": {"x": -1.0}, "lleg": {"x": 1.4}, "rarm": {"z": -0.8}, "larm": {"z": 0.8}}), "out"],
		[0.82, MadkClips.mg(Poses.add(sq, {"spine": {"y": 0.25}, "hips": {"y": -0.2}})), "in"],
		[1.0, g, "io"]]}
	# Breaker → скейт: приседает, подхватывает доску у земли и вскидывает над головой двумя руками
	var crouch: Dictionary = Poses.mk({"spine": {"x": 0.6}, "head": {"x": -0.35}, "drop": 0.42, "rup": {"x": -1.2}, "rleg": {"x": 1.9}, "lup": {"x": -1.2}, "lleg": {"x": 1.9}})
	A["SwapBreakerSkate"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.5}, "k": [[0.0, g],
		[0.36, Poses.add(crouch, {"rarm": {"x": -0.6, "z": 0.1}, "rfa": {"x": -0.2}}), "out"],
		[0.52, crouch, Poses.W([-0.16, 0.17, 0.2], [-0.92, 0.02, 0.38]), "lin"],
		[0.74, Poses.mk(Poses.add(st, Poses.add(Poses.tw(0.0, 0.0, -0.22), {"lift": 0.03}))), overhead, "out"],
		[0.9, hold, side, "io"], [1.0, hold, rest, "out"]]}
	# гитара → Breaker: закидывает гитару за левое плечо и идёт шагом toprock
	A["SwapGuitarBreaker"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.45}, "k": [[0.0, hold, rest],
		[0.18, hold, side, "io"],
		[0.42, Poses.mk(Poses.add(st, Poses.tw(0.3, 0.4, -0.05))), Poses.W([0.1, 0.6, -0.04], [0.45, 0.55, -0.7]), "io"],
		[0.66, MadkClips.mg({"hips": {"y": -0.3}, "spine": {"y": 0.3}, "lup": {"x": -0.2, "z": -0.25}, "lleg": {"x": 0.5}, "rarm": {"z": -0.5}, "larm": {"z": 0.5}}), "out"],
		[0.85, MadkClips.mg({"hips": {"y": 0.3}, "spine": {"y": -0.3}, "rup": {"x": -0.2, "z": 0.25}, "rleg": {"x": 0.5}}), "io"],
		[1.0, g, "io"]]}
	# Breaker → гитара: оборот в группировке, гитара выходит на вытянутую руку и ложится поперёк корпуса, как для игры
	A["SwapBreakerGuitar"] = {"d": 1.0, "n": 48, "ground": true, "ev": {"switch": 0.6}, "k": [[0.0, g],
		[0.3, Poses.mk(Poses.add(sq, {"drop": 0.25, "spine": {"x": 0.2}, "rarm": {"x": -0.8, "z": 0.6}, "rfa": {"x": -1.6}, "larm": {"x": -0.8, "z": -0.6}, "lfa": {"x": -1.6}})), "out"],
		[0.56, Poses.mk(Poses.add(sq, {"larm": {"z": 0.6}})), "io"],
		[0.64, Poses.mk(Poses.add(st, {"larm": {"z": 0.6}})), out_r, "lin"],
		[0.82, Poses.mk(Poses.add(st, Poses.tw(0.1, 0.15, 0.08))), Poses.W([-0.1, 0.42, 0.2], [0.75, 0.3, 0.58], T2), "in"],
		[0.94, hold, side, "io"], [1.0, hold, rest, "out"]]}
