## Позы жителей двора «ГОЛДА 67»: у каждого стоящего человека своя поза, чтобы толпа не выглядела строем.
## Все клипы — зацикленные, с лёгким дыханием; строятся от стойки Пахана (Poses.ph), значения — добавки к ней.
## Набор маленький нарочно: житель получает только эти клипы, а не весь боевой набор героя.
class_name G67Poses
extends RefCounted

## Что кому идёт: списки для очереди и для зрителей (берутся по кругу со сдвигом — подряд одинаковых нет)
const QUEUE := ["NPhone", "NCross", "NPockets", "NThink", "NWait"]
const FANS := ["NCheer", "NFist", "NPoint", "NCross", "NClap", "NShout"]

static func _loop(d: float, a: Dictionary, b: Dictionary) -> Dictionary:
	var ph := Callable(Poses, "ph")
	return {"d": d, "loop": true, "k": [[0.0, ph.call(a)], [0.5, ph.call(b)], [1.0, ph.call(a)]]}

static func _mix(a: Dictionary, o: Dictionary) -> Dictionary:
	var r := a.duplicate(true)
	for k in o:
		r[k] = o[k]
	return r

static func clips() -> Dictionary:
	# обе руки свободно вдоль тела (у стойки Пахана правая отведена под балон)
	var rest := {"rarm": {"x": 0.12, "z": 0.12}, "rfa": {"x": 0.05}, "spine": {"x": -0.06, "y": 0.05, "z": 0.06}, "head": {"x": 0.1, "z": -0.05}}
	var cross := _mix(rest, {"rarm": {"x": -0.62, "z": 0.42}, "larm": {"x": -0.72, "z": -0.38}, "rfa": {"x": -1.75}, "lfa": {"x": -1.75}, "spine": {"x": -0.12}})
	var phone := _mix(rest, {"larm": {"x": -0.75, "z": -0.1}, "lfa": {"x": -1.55}, "head": {"x": 0.42, "y": 0.12}, "spine": {"x": 0.1}})
	var pockets := _mix(rest, {"rarm": {"x": 0.2, "z": 0.05}, "larm": {"x": 0.15, "z": -0.02}, "rfa": {"x": -0.55}, "lfa": {"x": -0.55}, "spine": {"x": -0.16}, "hips": {"y": 0.2}, "head": {"y": -0.25}})
	var think := _mix(rest, {"rarm": {"x": -0.85, "z": 0.3}, "rfa": {"x": -2.15}, "larm": {"x": -0.45, "z": -0.35}, "lfa": {"x": -1.5}, "head": {"x": 0.12, "z": 0.12}})
	var wait := _mix(rest, {"hips": {"y": -0.25}, "spine": {"y": 0.2}, "head": {"y": 0.45}, "lup": {"z": 0.12}, "rarm": {"x": 0.12, "z": 0.2}})
	var cheer := _mix(rest, {"rarm": {"z": -2.25, "x": -0.15}, "larm": {"z": 2.25, "x": -0.15}, "rfa": {"x": -0.35}, "lfa": {"x": -0.35}, "spine": {"x": -0.18}, "head": {"x": -0.2}})
	var fist := _mix(rest, {"rarm": {"z": -2.35, "x": -0.25}, "rfa": {"x": -0.9}, "spine": {"x": -0.1, "z": -0.08}, "head": {"x": -0.15}})
	var point := _mix(rest, {"rarm": {"x": -1.35, "z": -0.9}, "rfa": {"x": -0.1}, "spine": {"y": -0.2, "x": 0.08}, "larm": {"x": 0.1}})
	var clap := _mix(rest, {"rarm": {"x": -0.95, "z": 0.3}, "larm": {"x": -0.95, "z": -0.3}, "rfa": {"x": -1.15}, "lfa": {"x": -1.15}})
	var shout := _mix(rest, {"rarm": {"x": -1.0, "z": 0.1}, "larm": {"x": -1.0, "z": -0.1}, "rfa": {"x": -2.2}, "lfa": {"x": -2.2}, "spine": {"x": 0.12}, "head": {"x": -0.28}})
	return {
		"Idle": _loop(3.4, rest, _mix(rest, {"spine": {"x": -0.09, "y": 0.05, "z": 0.06}, "head": {"x": 0.08, "y": 0.12, "z": -0.05}})),
		"NCross": _loop(3.0, cross, _mix(cross, {"spine": {"x": -0.15}, "head": {"y": 0.15}})),
		"NPhone": _loop(4.2, phone, _mix(phone, {"head": {"x": 0.36, "y": 0.05}, "lfa": {"x": -1.62}})),
		"NPockets": _loop(3.2, pockets, _mix(pockets, {"spine": {"x": -0.2}, "head": {"y": 0.2}})),
		"NThink": _loop(3.8, think, _mix(think, {"head": {"x": 0.05, "z": 0.18}})),
		"NWait": _loop(2.6, wait, _mix(wait, {"hips": {"y": -0.2}, "head": {"y": 0.6}})),
		"NCheer": _loop(0.9, cheer, _mix(cheer, {"rarm": {"z": -2.0, "x": -0.15}, "larm": {"z": 2.0, "x": -0.15}, "drop": 0.03})),
		"NFist": _loop(0.8, fist, _mix(fist, {"rarm": {"z": -2.1, "x": -0.25}, "rfa": {"x": -1.3}})),
		"NPoint": _loop(2.4, point, _mix(point, {"rarm": {"x": -1.25, "z": -0.9}, "head": {"y": -0.2}})),
		"NClap": _loop(0.6, clap, _mix(clap, {"rarm": {"x": -0.95, "z": 0.62}, "larm": {"x": -0.95, "z": -0.62}})),
		"NShout": _loop(1.6, shout, _mix(shout, {"spine": {"x": 0.02}, "head": {"x": -0.38}})),
	}
