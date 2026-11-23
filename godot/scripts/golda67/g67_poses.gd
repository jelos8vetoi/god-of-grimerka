## Позы жителей двора и КРОТА («ГОЛДА 67»). Спокойные бытовые позы, не «руки вверх»: 70 % времени человек стоит
## в основной позе, иногда меняет её на другую (G67Life), реакции — короткие и редкие.
##
## Как задаются углы (rig.pose_rots): поворот кости — вокруг осей МИРА (x — поперёк тела, y — вверх, z — вперёд),
## по порядку ключей; база — нейтральная стойка Poses.en (рука сначала опускается поворотом вокруг z). Поэтому:
##   рука x < 0 — поднимается вперёд;  рука z < 0 (правая) / z > 0 (левая) — отводится в сторону;
##   сгиб в локте: сумма «рука x + предплечье x − 0,25» — направление предплечья от «вниз»: ≈ −1,55 — горизонтально
##   вперёд, ≈ −2,4 — кисть у лица; у горизонтального предплечья y > 0 (правое) / y < 0 (левое) — кисть к середине груди;
##   голова x > 0 — вниз, y > 0 — поворот к своему правому плечу;  бедро x < 0 — вперёд, голень x > 0 — сгиб колена;
##   drop — таз ниже на долю высоты таза (сидит, на корточках).
## Новые позы проверять листом поз (кадр спереди и сбоку), а не на глаз по числам.
class_name G67Poses
extends RefCounted

## Сидячие позы ставятся так, чтобы таз пришёлся на сиденье: SIT_HIP — высота таза над точкой рига, доля роста
const SIT_DROP := 0.42
const SIT_HIP := 0.27
## Старые списки (очередь и зрители до переделки) — пока ими пользуется G67Yard
const QUEUE := ["NPhone", "NMenu", "NPocketsSide", "NTalk"]
const FANS := ["SLean", "SCross", "STalk", "SFilm", "SPoint", "SWatch", "NRail", "NPoint"]
## В каких позах что в руке (props): телефон — левая кисть, сигарета и шаурма — правая
const PHONE := ["NPhone", "NFilm", "SFilm", "NTaxiPhone"]
const SMOKE := ["NSmoke"]
const FOOD := ["NEat"]

# ---------------------------------------------------------------- сборка
static func _mix(a: Dictionary, o: Dictionary) -> Dictionary:
	var r := a.duplicate(true)
	for k in o:
		if r.has(k) and r[k] is Dictionary and o[k] is Dictionary:
			var d: Dictionary = (r[k] as Dictionary).duplicate()
			for ax in o[k]:
				d[ax] = float(d.get(ax, 0.0)) + float(o[k][ax])
			r[k] = d
		else:
			r[k] = o[k]
	return r

static func _p(a: Dictionary) -> Dictionary:
	return Poses.en(a)

## Цикл покоя: a → a+add → a (дыхание, переступание); ease — плавные переходы
static func _loop(d: float, a: Dictionary, add: Dictionary) -> Dictionary:
	return {"d": d, "loop": true, "k": [[0.0, _p(a), "io"], [0.5, _p(_mix(a, add)), "io"], [1.0, _p(a)]]}

## Цикл по точкам: [[доля, поза], …] — поза добавкой к base
static func _seq(d: float, base: Dictionary, pts: Array, loop := true) -> Dictionary:
	var k: Array = []
	for pt in pts:
		k.append([float(pt[0]), _p(_mix(base, pt[1])), String(pt[2]) if pt.size() > 2 else "io"])
	return {"d": d, "loop": loop, "k": k}

## Короткая реакция: из base в base+peak и обратно (один раз)
static func _react(d: float, base: Dictionary, peak: Dictionary) -> Dictionary:
	return _seq(d, base, [[0.0, {}], [0.3, peak, "out"], [0.65, peak], [1.0, {}]], false)

const W_R := {"hips": {"z": 0.06, "y": 0.08}, "spine": {"z": -0.05}, "lup": {"x": -0.12, "z": 0.05}, "lleg": {"x": 0.22}, "rup": {"z": 0.03}}
const W_L := {"hips": {"z": -0.06, "y": -0.08}, "spine": {"z": 0.05}, "rup": {"x": -0.12, "z": -0.05}, "rleg": {"x": 0.22}, "lup": {"z": -0.03}}
const BREATH := {"spine": {"x": -0.025}, "head": {"x": -0.02}}
## сидит: бёдра вперёд, колени согнуты, колени чуть врозь
const SIT := {"rup": {"x": -1.5, "z": -0.08}, "lup": {"x": -1.5, "z": 0.08}, "rleg": {"x": 1.55}, "lleg": {"x": 1.55}, "drop": SIT_DROP}

## руки — заготовки (правая R*, левая L*), складываются в позу
const R_DOWN := {"rarm": {"z": 0.08, "x": 0.04}, "rfa": {"x": -0.12}}
const L_DOWN := {"larm": {"z": -0.08, "x": 0.04}, "lfa": {"x": -0.12}}
const R_POCKET := {"rarm": {"x": 0.12, "z": -0.08}, "rfa": {"x": -0.6, "y": 0.5}}       # в боковом кармане куртки
const L_POCKET := {"larm": {"x": 0.12, "z": 0.08}, "lfa": {"x": -0.6, "y": -0.5}}
const CROSS := {"rarm": {"x": -0.35, "z": -0.1}, "rfa": {"x": -1.05, "y": 1.45}, "larm": {"x": -0.3, "z": 0.1}, "lfa": {"x": -0.95, "y": -1.5}}
const POUCH := {"rarm": {"x": -0.12, "z": -0.05}, "rfa": {"x": -0.85, "y": 1.25}, "larm": {"x": -0.12, "z": 0.05}, "lfa": {"x": -0.85, "y": -1.25}}
const HIPS := {"rarm": {"z": -0.55, "x": 0.2}, "rfa": {"x": -0.3, "z": 1.35}, "larm": {"z": 0.55, "x": 0.2}, "lfa": {"x": -0.3, "z": -1.35}}
const L_HIP := {"larm": {"z": 0.55, "x": 0.2}, "lfa": {"x": -0.3, "z": -1.35}}
const L_PHONE := {"larm": {"x": -0.25, "z": 0.08}, "lfa": {"x": -1.05, "y": -0.6}}
const R_TALK := {"rarm": {"x": -0.3, "z": -0.05}, "rfa": {"x": -0.95, "y": 0.45}}       # ладонь у пояса, жест
const FILM := {"larm": {"x": -0.8, "z": 0.12}, "lfa": {"x": -1.0, "y": -0.8}, "rarm": {"x": -0.8, "z": -0.12}, "rfa": {"x": -1.0, "y": 0.8}}

# ---------------------------------------------------------------- жители
static func clips() -> Dictionary:
	var C := {}
	var idle := _mix(_mix(R_DOWN, L_DOWN), W_R)
	C["Idle"] = _loop(3.6, idle, BREATH)
	C["NIdleL"] = _loop(3.9, _mix(_mix(R_DOWN, L_DOWN), W_L), BREATH)
	C["NCross"] = _loop(3.2, _mix(CROSS, _mix(W_L, {"spine": {"x": -0.05}, "head": {"x": 0.04}})), BREATH)
	C["NPhone"] = _loop(4.4, _mix(_mix(L_PHONE, R_DOWN), _mix(W_R, {"head": {"x": 0.42, "y": 0.1}, "neck": {"x": 0.15}, "spine": {"x": 0.06}})), {"lfa": {"y": -0.06}, "head": {"x": 0.03}})
	C["NFilm"] = _loop(3.0, _mix(FILM, W_L), {"spine": {"x": -0.02}})
	C["NPockets"] = _loop(3.4, _mix(POUCH, _mix(W_R, {"spine": {"x": 0.04}})), BREATH)
	C["NPocketsSide"] = _loop(3.6, _mix(_mix(R_POCKET, L_POCKET), _mix(W_L, {"spine": {"x": -0.04}})), BREATH)
	C["NHips"] = _loop(3.2, _mix(HIPS, _mix(W_L, {"spine": {"x": -0.08}})), BREATH)
	C["NThink"] = _loop(4.0, _mix(W_L, {"larm": {"x": -0.3, "z": 0.1}, "lfa": {"x": -1.0, "y": -1.45}, "rarm": {"x": -0.4, "z": -0.05}, "rfa": {"x": -1.95, "y": 0.95},
		"head": {"x": 0.1, "z": 0.08}}), {"head": {"z": 0.04}})
	C["NTalk"] = _seq(3.4, _mix(_mix(R_TALK, L_POCKET), W_R), [[0.0, {}], [0.3, {"rfa": {"x": -0.18, "y": 0.15}, "head": {"x": 0.06}}], [0.55, {}], [0.75, {"rfa": {"x": -0.1}, "head": {"x": 0.08}}], [1.0, {}]])
	# бабушка: авоська в правой руке (вещь держит G67Carry), левая у груди придерживает пальто или поправляет платок
	var bag := _mix({"rarm": {"x": -0.08, "z": 0.02}, "rfa": {"x": -0.3}}, W_L)
	# madk1d в подъезде (до первой концовки): сидит на табурете у телевизора с телефоном
	var msit := _mix(_mix(SIT, _mix(L_PHONE, R_DOWN)), {"head": {"x": 0.42, "y": 0.1}, "neck": {"x": 0.15}, "spine": {"x": 0.12}})
	C["MSitPhone"] = _loop(4.4, msit, {"lfa": {"y": -0.06}, "head": {"x": 0.03}})
	C["MSitLook"] = _loop(3.0, _mix(msit, {"head": {"x": -0.05, "y": 0.55}, "lfa": {"x": -0.6}}), BREATH)
	C["MSitSwap"] = _react(2.2, msit, {"lfa": {"x": -1.35}, "rarm": {"x": -0.7}, "rfa": {"x": -1.0, "y": 0.5}, "head": {"x": 0.1}})
	C["MSitShift"] = _react(2.6, msit, {"spine": {"x": -0.1}, "lup": {"x": -1.15}, "lleg": {"x": 1.1}, "head": {"x": 0.16}})
	C["MSitNod"] = _seq(1.5, msit, [[0.0, {}], [0.3, {"head": {"x": 0.0, "y": 0.45}}], [0.5, {"head": {"x": 0.28, "y": 0.45}}], [0.7, {"head": {"x": 0.0, "y": 0.45}}], [1.0, {}]])
	C["NWalk"] = _walk(1.15, _mix(R_DOWN, L_DOWN))
	C["NWalkBag"] = _walk(1.25, _mix(bag, {"larm": {"x": -0.2, "z": 0.05}, "lfa": {"x": -0.9, "y": -1.2}, "spine": {"x": 0.08}}))
	C["NSitBag"] = _loop(4.2, _mix(SIT, _mix(bag, {"larm": {"x": -0.2, "z": 0.05}, "lfa": {"x": -0.9, "y": -1.2}, "spine": {"x": 0.08}, "head": {"x": 0.05}})), BREATH)
	C["NBag"] = _loop(4.2, _mix(bag, {"larm": {"x": -0.2, "z": 0.05}, "lfa": {"x": -0.9, "y": -1.2}, "spine": {"x": 0.1}, "head": {"x": 0.05}}), BREATH)
	C["NBagRest"] = _loop(4.6, _mix(bag, _mix(L_DOWN, {"spine": {"x": 0.12}})), BREATH)
	C["NScarf"] = _seq(3.0, _mix(bag, {"spine": {"x": 0.1}}), [[0.0, L_DOWN], [0.3, {"larm": {"x": -0.55, "z": 0.45}, "lfa": {"x": -2.05, "y": -0.8}, "head": {"z": -0.1}}], [0.7, {"larm": {"x": -0.55, "z": 0.45}, "lfa": {"x": -2.15, "y": -0.85}, "head": {"z": -0.12}}], [1.0, L_DOWN]], false)
	# мужик в ушанке: курит — рука с сигаретой поднимается ко рту, держит, опускается
	var smoke_base := _mix(_mix(L_POCKET, W_R), {"rarm": {"x": -0.1}, "rfa": {"x": -0.45, "y": 0.2}})
	C["NSmoke"] = _seq(7.0, smoke_base, [[0.0, {}], [0.18, {}], [0.32, {"rarm": {"x": -0.35, "z": -0.05}, "rfa": {"x": -1.55, "y": 0.95}, "head": {"x": -0.05}}, "out"],
		[0.5, {"rarm": {"x": -0.35, "z": -0.05}, "rfa": {"x": -1.6, "y": 0.95}, "head": {"x": -0.08}}], [0.62, {"head": {"x": -0.12}}], [0.85, {}], [1.0, {}]])
	# школьник: держит рюкзак за лямку; поправляет рюкзак (обе руки к лямкам, плечи вверх)
	var strap := {"larm": {"x": -0.1, "z": 0.02}, "lfa": {"x": -2.1, "y": -0.35}}
	C["NStrap"] = _loop(3.4, _mix(_mix(strap, R_DOWN), W_R), BREATH)
	C["NStraps"] = _seq(2.6, _mix(W_L, {}), [[0.0, _mix(strap, R_DOWN)], [0.3, _mix(strap, {"rarm": {"x": -0.1, "z": -0.02}, "rfa": {"x": -2.1, "y": 0.35}, "spine": {"x": -0.08}, "head": {"x": -0.05}})],
		[0.55, _mix(strap, {"rarm": {"x": -0.1, "z": -0.02}, "rfa": {"x": -2.2, "y": 0.35}, "spine": {"x": 0.04}})], [1.0, _mix(strap, R_DOWN)]], false)
	# таксист: облокотился рукой на крышу машины (она справа от него), левая в кармане; поправляет куртку; телефон
	C["NCarLean"] = _loop(4.0, _mix(_mix(L_POCKET, W_R), {"rarm": {"z": -0.95, "x": -0.1}, "rfa": {"x": -0.45}, "spine": {"z": -0.06}, "hips": {"z": 0.05}}), BREATH)
	C["NJacket"] = _seq(2.4, W_L, [[0.0, _mix(R_DOWN, L_DOWN)], [0.35, {"rarm": {"x": -0.35, "z": -0.05}, "rfa": {"x": -1.85, "y": 0.9}, "larm": {"x": -0.35, "z": 0.05}, "lfa": {"x": -1.85, "y": -0.9}}],
		[0.6, {"rarm": {"x": -0.3, "z": -0.05}, "rfa": {"x": -1.7, "y": 0.9}, "larm": {"x": -0.3, "z": 0.05}, "lfa": {"x": -1.7, "y": -0.9}, "spine": {"x": -0.05}}], [1.0, _mix(R_DOWN, L_DOWN)]], false)
	C["NTaxiPhone"] = C["NPhone"]
	# очередь у ларька: смотрит меню над окошком; наклонился к продавцу и показывает рукой; ест шаурму
	C["NMenu"] = _loop(4.0, _mix(_mix(R_POCKET, L_POCKET), _mix(W_R, {"head": {"x": -0.3, "y": 0.08}, "spine": {"x": -0.06}})), {"head": {"y": -0.12}})
	C["NOrder"] = _seq(3.0, _mix(L_POCKET, _mix(W_L, {"spine": {"x": 0.2}, "head": {"x": -0.12}})), [[0.0, {"rarm": {"x": -0.6, "z": -0.1}, "rfa": {"x": -0.6, "y": 0.35}}],
		[0.35, {"rarm": {"x": -0.7, "z": -0.1}, "rfa": {"x": -0.75, "y": 0.45}}], [0.6, {"rarm": {"x": -0.6, "z": -0.1}, "rfa": {"x": -0.55, "y": 0.3}}], [1.0, {"rarm": {"x": -0.6, "z": -0.1}, "rfa": {"x": -0.6, "y": 0.35}}]])
	var eat := _mix(L_DOWN, W_R)
	C["NEat"] = _seq(5.0, eat, [[0.0, {"rarm": {"x": -0.3}, "rfa": {"x": -1.25, "y": 0.75}}], [0.3, {"rarm": {"x": -0.3}, "rfa": {"x": -1.25, "y": 0.75}}],
		[0.45, {"rarm": {"x": -0.4, "z": -0.05}, "rfa": {"x": -1.75, "y": 1.15}, "head": {"x": 0.12}}, "out"], [0.6, {"rarm": {"x": -0.4, "z": -0.05}, "rfa": {"x": -1.75, "y": 1.15}, "head": {"x": 0.15}}],
		[0.75, {"rarm": {"x": -0.3}, "rfa": {"x": -1.25, "y": 0.75}, "head": {"x": 0.04}}], [1.0, {"rarm": {"x": -0.3}, "rfa": {"x": -1.25, "y": 0.75}}]])
	# стоя у борта: опёрся на борт перед собой; показывает пальцем на площадку
	C["NRail"] = _loop(3.4, _mix(W_R, {"spine": {"x": 0.3}, "rarm": {"x": -0.95, "z": -0.1}, "rfa": {"x": -0.3, "y": 0.3}, "larm": {"x": -0.95, "z": 0.1}, "lfa": {"x": -0.3, "y": -0.3}, "head": {"x": -0.28}}), {"spine": {"x": 0.03}})
	C["NPoint"] = _seq(4.0, _mix(L_POCKET, W_L), [[0.0, R_DOWN], [0.25, R_DOWN], [0.4, {"rarm": {"x": -1.35, "z": -0.15}, "rfa": {"x": -0.1}, "head": {"x": -0.04}}, "out"],
		[0.75, {"rarm": {"x": -1.3, "z": -0.15}, "rfa": {"x": -0.12}}], [0.9, R_DOWN], [1.0, R_DOWN]])
	# ---- зрители на трибуне (сидят)
	C["SWatch"] = _loop(3.8, _mix(SIT, {"rarm": {"x": -0.75, "z": -0.05}, "rfa": {"x": -0.35}, "larm": {"x": -0.75, "z": 0.05}, "lfa": {"x": -0.35}}), BREATH)
	C["SLean"] = _loop(3.6, _mix(SIT, {"spine": {"x": 0.36}, "rarm": {"x": -0.45, "z": -0.05}, "rfa": {"x": -1.2, "y": 0.6}, "larm": {"x": -0.45, "z": 0.05}, "lfa": {"x": -1.2, "y": -0.6},
		"head": {"x": -0.32}}), {"spine": {"x": 0.03}, "head": {"y": 0.08}})
	C["SCross"] = _loop(3.4, _mix(SIT, _mix(CROSS, {"spine": {"x": -0.08}})), BREATH)
	C["STalk"] = _seq(3.8, _mix(SIT, {"larm": {"x": -0.75, "z": 0.05}, "lfa": {"x": -0.35}, "head": {"y": 0.6}, "spine": {"z": -0.04}}),
		[[0.0, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}], [0.3, {"rarm": {"x": -0.5, "z": -0.05}, "rfa": {"x": -1.0, "y": 0.5}, "head": {"x": 0.05}}],
		[0.55, {"rarm": {"x": -0.55, "z": -0.05}, "rfa": {"x": -0.9, "y": 0.6}}], [0.8, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}, "head": {"x": 0.08}}], [1.0, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}]])
	C["SFilm"] = _loop(3.0, _mix(SIT, FILM), {"spine": {"x": -0.02}})
	C["SPoint"] = _seq(4.2, _mix(SIT, {"larm": {"x": -0.75, "z": 0.05}, "lfa": {"x": -0.35}}), [[0.0, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}], [0.25, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}],
		[0.4, {"rarm": {"x": -1.4, "z": -0.1}, "rfa": {"x": -0.1}, "spine": {"x": 0.05}}, "out"], [0.75, {"rarm": {"x": -1.35, "z": -0.1}, "rfa": {"x": -0.12}}], [0.9, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}], [1.0, {"rarm": {"x": -0.75}, "rfa": {"x": -0.35}}]])
	# привстал посмотреть и сел обратно (однократно)
	var sw := {"rarm": {"x": -0.75, "z": -0.05}, "rfa": {"x": -0.35}, "larm": {"x": -0.75, "z": 0.05}, "lfa": {"x": -0.35}}
	C["SStand"] = _seq(4.2, {}, [[0.0, _mix(SIT, sw)], [0.25, _mix({"rup": {"x": -0.55}, "lup": {"x": -0.55}, "rleg": {"x": 0.6}, "lleg": {"x": 0.6}, "drop": 0.12, "spine": {"x": 0.25}}, _mix(R_DOWN, L_DOWN)), "io"],
		[0.4, _mix(_mix(R_DOWN, L_DOWN), {"spine": {"x": 0.08}, "head": {"x": -0.1}}), "io"], [0.7, _mix(_mix(R_DOWN, L_DOWN), {"spine": {"x": 0.1}, "head": {"x": -0.12}})],
		[0.85, _mix({"rup": {"x": -0.7}, "lup": {"x": -0.7}, "rleg": {"x": 0.75}, "lleg": {"x": 0.75}, "drop": 0.15, "spine": {"x": 0.3}}, _mix(R_DOWN, L_DOWN)), "io"], [1.0, _mix(SIT, sw)]], false)
	# стоит, опёршись спиной на машину, руки скрещены
	C["NLeanBack"] = _loop(4.0, _mix(CROSS, {"spine": {"x": -0.14}, "head": {"x": 0.06}, "hips": {"x": 0.06}, "rup": {"x": -0.18, "z": -0.04}, "lup": {"x": -0.05, "z": 0.12}, "lleg": {"x": 0.12}}), BREATH)
	# ---- короткие реакции на сильный удар, добивание, смену фазы (один раз, ~1,5 с)
	for st in [["", {}], ["S", SIT]]:
		var b0: Dictionary = st[1]
		var calm := _mix(b0, {"rarm": {"x": -0.6}, "rfa": {"x": -0.3}, "larm": {"x": -0.6}, "lfa": {"x": -0.3}}) if String(st[0]) == "S" else _mix(_mix(R_DOWN, L_DOWN), W_R)
		C[String(st[0]) + "RUp"] = _react(1.5, calm, {"rarm": {"x": -1.6, "z": -0.35}, "rfa": {"x": -0.6}, "larm": {"x": -1.6, "z": 0.35}, "lfa": {"x": -0.6}, "spine": {"x": -0.1}, "head": {"x": -0.1}})
		C[String(st[0]) + "RWow"] = _react(1.6, calm, {"rarm": {"x": -0.55, "z": -0.65}, "rfa": {"x": -2.35, "y": 0.45}, "larm": {"x": -0.55, "z": 0.65}, "lfa": {"x": -2.35, "y": -0.45}, "spine": {"x": -0.12}, "head": {"x": -0.08}})
		C[String(st[0]) + "RLean"] = _react(1.4, calm, {"spine": {"x": 0.32}, "head": {"x": -0.3}})
		C[String(st[0]) + "RYes"] = _react(1.2, calm, {"rarm": {"x": -0.35, "z": -0.05}, "rfa": {"x": -1.95, "y": 0.35}, "spine": {"x": -0.05}})
	return C

# ---------------------------------------------------------------- КРОТ
## Позы КРОТА на десять встреч (одна модель; меняются только позы и вещи). Он предельно серьёзен:
## жесты маленькие и редкие, никаких кривляний. Клипы подмешиваются к набору Пахана (там есть ходьба).
static func krot() -> Dictionary:
	var C := {}
	# 1 «ДРУЗЬЯ ИЗ FORBES»: ноги шире, грудь вперёд, подбородок вверх, левая в кармане, правая готова к жесту
	var k1 := _mix(L_POCKET, {"rup": {"z": -0.12}, "lup": {"z": 0.12}, "spine": {"x": -0.12}, "head": {"x": -0.12}, "rarm": {"x": -0.25, "z": -0.05}, "rfa": {"x": -0.75, "y": 0.3}})
	C["K1"] = _loop(4.0, k1, {"spine": {"x": -0.02}})
	C["K1Talk"] = _seq(2.4, k1, [[0.0, {}], [0.35, {"rfa": {"x": -0.35, "y": 0.2}}], [0.5, {"rfa": {"x": -0.3, "y": 0.2}}], [0.7, {}], [1.0, {}]])
	C["K1Nod"] = _react(1.0, k1, {"head": {"x": 0.28}})
	# 2 «ЛЮСТРА»: держит люстру обеими руками перед грудью, смотрит на неё; «показывает доказательство» — поднимает к Пахану
	var k2 := {"rarm": {"x": -0.85, "z": -0.12}, "rfa": {"x": -0.55, "y": 0.45}, "larm": {"x": -0.85, "z": 0.12}, "lfa": {"x": -0.55, "y": -0.45}}
	C["K2"] = _loop(3.6, _mix(k2, {"head": {"x": 0.32}, "spine": {"x": 0.05}}), {"head": {"z": 0.08}})
	C["K2Look"] = _loop(3.6, _mix(k2, {"head": {"x": 0.02}}), BREATH)
	C["K2Show"] = _loop(2.0, _mix(k2, {"rarm": {"x": -0.3}, "larm": {"x": -0.3}, "spine": {"x": -0.04}}), BREATH)
	C["K2Walk"] = _walk(0.95, k2)
	# 3 «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО»: наклонился, корм в левой ладони, правой бросает зёрна; показывает на голубя справа
	var k3 := _mix(W_L, {"spine": {"x": 0.25}, "head": {"x": 0.35}, "larm": {"x": -0.4, "z": 0.08}, "lfa": {"x": -0.95, "y": -0.7}})
	var k3r := {"rarm": {"x": -0.45, "z": -0.05}, "rfa": {"x": -0.95, "y": 0.95}}
	C["K3"] = _seq(4.2, k3, [[0.0, k3r], [0.4, k3r], [0.52, {"rarm": {"x": -0.75, "z": -0.3}, "rfa": {"x": -0.25}}, "out"], [0.62, {"rarm": {"x": -0.7, "z": -0.3}, "rfa": {"x": -0.3}}], [0.85, k3r], [1.0, k3r]])
	C["K3Point"] = _loop(2.4, _mix(k3, {"spine": {"x": -0.12}, "head": {"x": -0.3, "y": 0.6}, "rarm": {"x": -1.2, "z": -0.45}, "rfa": {"x": -0.1}}), BREATH)
	# 4 «NPC» (торговая галерея ПОДЗЕМКИ): застрял в анимации — рывком поворот влево и обратно, шаг-жест, замер
	var k4 := _mix(R_DOWN, L_DOWN)
	C["K4"] = _seq(4.0, k4, [[0.0, {}, "lin"], [0.05, {"hips": {"y": 0.45}, "spine": {"y": 0.12}}, "lin"], [0.2, {"hips": {"y": 0.45}, "spine": {"y": 0.12}}, "lin"], [0.25, {}, "lin"],
		[0.3, {"rarm": {"x": -0.4}, "rfa": {"x": -1.3, "y": 0.4}, "rup": {"x": -0.25}}, "lin"], [0.38, {}, "lin"], [1.0, {}, "lin"]])
	C["K4Nod"] = _react(1.1, k4, {"head": {"x": 0.3}})
	# 5 «АБСОЛЮТНО ТРЕЗВЫЙ»: на корточках у автомата, руки на коленях; поднимает палец; уверенный кивок
	var k5 := {"rup": {"x": -2.05, "z": -0.15}, "lup": {"x": -2.05, "z": 0.15}, "rleg": {"x": 2.45}, "lleg": {"x": 2.45}, "drop": 0.6, "spine": {"x": 0.35}, "head": {"x": -0.28},
		"rarm": {"x": -0.9, "z": -0.1}, "rfa": {"x": -0.25}, "larm": {"x": -0.9, "z": 0.1}, "lfa": {"x": -0.25}}
	C["K5"] = _loop(4.0, k5, BREATH)
	C["K5Finger"] = _loop(2.4, _mix(k5, {"rarm": {"x": 0.25}, "rfa": {"x": -1.6, "y": 0.25}}), BREATH)
	C["K5Nod"] = _react(0.9, k5, {"head": {"x": 0.3}})
	# 6 «РИЗЗ 9000» (ЛЕНТА): левая на поясе, правой поправляет волосы, подбородок вверх, корпус вполоборота
	var k6 := _mix(L_HIP, {"hips": {"y": 0.3}, "spine": {"x": -0.08}, "head": {"x": -0.2, "y": -0.25}, "rup": {"z": -0.06}})
	C["K6"] = _seq(3.6, k6, [[0.0, {"rarm": {"x": -0.55, "z": -0.55}, "rfa": {"x": -2.25, "y": 0.55}}], [0.5, {"rarm": {"x": -0.6, "z": -0.6}, "rfa": {"x": -2.4, "y": 0.6}}], [1.0, {"rarm": {"x": -0.55, "z": -0.55}, "rfa": {"x": -2.25, "y": 0.55}}]])
	C["K6Pose"] = _loop(2.2, _mix(k6, {"rarm": {"x": -0.4, "z": -0.15}, "rfa": {"x": -2.05, "y": 1.2}, "head": {"x": -0.12, "y": -0.1}, "spine": {"x": -0.05}}), BREATH)
	# 7 «МЕНЯ УВОЛИЛИ ИЗ MINECRAFT» (БОТОФЕРМА): сидит на стуле, наклонился, рука на колене, другой указывает на сервер; разводит руками
	var k7 := _mix(SIT, {"spine": {"x": 0.25}, "larm": {"x": -0.8, "z": 0.05}, "lfa": {"x": -0.35}, "head": {"x": -0.2}})
	C["K7"] = _loop(4.0, _mix(k7, {"rarm": {"x": -1.25, "z": -0.35}, "rfa": {"x": -0.1}, "head": {"y": 0.35}}), BREATH)
	C["K7Shrug"] = _loop(2.2, _mix(SIT, {"spine": {"x": 0.05}, "rarm": {"x": -0.3, "z": -0.55}, "rfa": {"x": -1.15}, "larm": {"x": -0.3, "z": 0.55}, "lfa": {"x": -1.15}, "head": {"z": 0.12}}), BREATH)
	# 8 «СУД НАД КРОССОВКОМ» (ЗАКУЛИСЬЕ): руки сложены перед животом, голова чуть наклонена; указывает в сторону; медленный кивок
	var k8 := _mix(POUCH, {"head": {"x": 0.18, "z": 0.1}})
	C["K8"] = _loop(4.4, k8, BREATH)
	C["K8Point"] = _loop(2.4, _mix(_mix(k8, {"rarm": {"z": -0.95, "x": -0.15}, "rfa": {"x": -0.1}}), {"rfa": {"y": -1.25}, "head": {"y": 0.55, "x": -0.15}}), BREATH)
	C["K8Nod"] = _react(1.8, k8, {"head": {"x": 0.32}})
	# 9 «БИЗНЕС НА ВОЗДУХЕ»: за столиком, пустой пакет в левой руке, правой — рекламный жест; «первый вдох бесплатно» — поднимает пакет
	var k9 := {"larm": {"x": -0.3, "z": 0.08}, "lfa": {"x": -1.05, "y": -0.5}, "spine": {"x": 0.05}}
	C["K9"] = _seq(3.6, k9, [[0.0, R_TALK], [0.35, {"rarm": {"x": -0.4, "z": -0.15}, "rfa": {"x": -0.95, "y": 0.1}}], [0.6, R_TALK], [1.0, R_TALK]])
	C["K9Raise"] = _loop(2.4, {"larm": {"x": -1.95, "z": 0.15}, "lfa": {"x": -0.45}, "rarm": {"x": -0.4, "z": -0.15}, "rfa": {"x": -0.95, "y": 0.1}, "head": {"x": -0.2, "y": -0.2}}, BREATH)
	# 10 «ПОСЛЕДНЯЯ ВСТРЕЧА»: стоит совершенно неподвижно, руки вдоль тела, смотрит прямо (без дыхания)
	var k10 := {"rarm": {"z": 0.12}, "larm": {"z": -0.12}, "rfa": {"x": 0.2}, "lfa": {"x": 0.2}}
	C["K10"] = {"d": 2.0, "loop": true, "k": [[0.0, _p(k10)], [1.0, _p(k10)]]}
	return C

## Ходьба с занятыми руками: ноги — четыре позы на шаг, руки держат arms
static func _walk(d: float, arms: Dictionary) -> Dictionary:
	var a := _mix(arms, {"rup": {"x": -0.42}, "rleg": {"x": 0.12}, "lup": {"x": 0.3}, "lleg": {"x": 0.35}, "drop": 0.03})
	var b := _mix(arms, {"rup": {"x": -0.05}, "rleg": {"x": 0.5}, "lup": {"x": 0.0}, "lleg": {"x": 0.05}, "drop": 0.0})
	var c := _mix(arms, {"lup": {"x": -0.42}, "lleg": {"x": 0.12}, "rup": {"x": 0.3}, "rleg": {"x": 0.35}, "drop": 0.03})
	var e := _mix(arms, {"lup": {"x": -0.05}, "lleg": {"x": 0.5}, "rup": {"x": 0.0}, "rleg": {"x": 0.05}, "drop": 0.0})
	return {"d": d, "loop": true, "k": [[0.0, _p(a)], [0.25, _p(b)], [0.5, _p(c)], [0.75, _p(e)], [1.0, _p(a)]]}

## Все клипы — для листа поз
static func all() -> Dictionary:
	var C := clips()
	C.merge(krot(), true)
	return C

## Вещи в руках по позе: телефон (левая кисть), сигарета, шаурма (правая) — простые формы кодом, пока нет моделей
static func props(rig: Rig, clip: String) -> void:
	if rig == null or rig.skel == null:
		return
	if PHONE.has(clip):
		_prop(rig, "mixamorig_LeftHand", "phone", _box(Vector3(0.075, 0.15, 0.012), Color(0.06, 0.06, 0.07), Color(0.55, 0.7, 1.0)), Vector3(0, 0.09, 0.03))
	if SMOKE.has(clip):
		_prop(rig, "mixamorig_RightHand", "cigarette", _box(Vector3(0.01, 0.075, 0.01), Color(0.95, 0.93, 0.88), Color(1.0, 0.4, 0.1)), Vector3(0.0, 0.1, 0.04))
	if FOOD.has(clip):
		var n := _prop(rig, "mixamorig_RightHand", "shawarma", null, Vector3(0, 0.1, 0.04))
		if n != null:
			var k := _unit(rig)
			for part in [[0.035, 0.17, 0.0, Color(0.93, 0.82, 0.6)], [0.038, 0.08, -0.05, Color(0.96, 0.95, 0.92)]]:
				var mi := MeshInstance3D.new()
				var cy := CylinderMesh.new()
				cy.top_radius = float(part[0]) * k
				cy.bottom_radius = float(part[0]) * 0.92 * k
				cy.height = float(part[1]) * k
				var m := StandardMaterial3D.new()
				m.albedo_color = part[3]
				cy.material = m
				mi.mesh = cy
				mi.position = Vector3(0, float(part[2]) * k, 0)
				n.add_child(mi)

static func _unit(rig: Rig) -> float:
	return 1.0 / maxf(0.001, rig.skel.global_transform.basis.get_scale().y)

static func _box(size: Vector3, col: Color, glow: Color) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 0.25
	m.material = mat
	return m

static func _prop(rig: Rig, bone: String, nm: String, mesh: Mesh, off: Vector3) -> Node3D:
	if rig.skel.find_bone(bone) < 0 or rig.skel.get_node_or_null(nm) != null:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	att.name = nm
	rig.skel.add_child(att)
	var k := _unit(rig)
	var n := Node3D.new()
	n.position = off * k
	att.add_child(n)
	if mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3.ONE * k
		n.add_child(mi)
	return n

## Встреча 10: КРОТ исчезает как сломанный NPC — рывком проваливается в пол по пояс, замирает на полсекунды,
## потом схлопывается в плоскость и пропадает. Не бегство и не дым — сбой.
static func vanish(rig: Node3D, h := 1.62) -> Tween:
	var tw := rig.create_tween()
	tw.tween_property(rig, "position:y", rig.position.y - h * 0.48, 0.09)
	tw.tween_interval(0.5)
	tw.tween_property(rig, "scale", Vector3(rig.scale.x * 1.25, rig.scale.y * 0.02, rig.scale.z * 1.25), 0.08)
	tw.tween_callback(rig.queue_free)
	return tw
