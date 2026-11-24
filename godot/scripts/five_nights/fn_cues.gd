## Звуки ходов врагов: дальние ходы слышны издалека, коридор и дверь — того же характера, но громче.
## Записи — из библиотеки assets/audio/fn/sfx; случайный фон здания этими записями больше не пользуется.
class_name FNCues

const FAR := {"balon": "thud", "bot": "grind", "clipper": "drag", "mod": "knock"}
const FAR_GAP := 9.0                   # с: не чаще одного дальнего звука на врага
const FAR_FROM := 6.0                  # с ночи: раньше дальних звуков нет
const FAR_LEVEL := 6.0                # дБ поверх поправки записи (подбирается замером)
const FAR_TRIM := {"thud": 0.1, "grind": 2.1, "drag": 1.3, "knock": 13.4}    # те же поправки, что были у этих записей в фоне
const STEP2_GAP := [0.55, 0.7]         # с: второй удар походки БАЛОНА
const STEP2_DB := -2.0
const STEP2_PITCH := 0.94

## вид точки: door / vent / duct / hall / far; "" — враг ушёл
static func kind(to: String) -> String:
	if to in ["door_l", "door_r"]:
		return "door"
	if to in ["vent_l", "vent_t"]:
		return "vent"
	if to.begins_with("duct_"):
		return "duct"
	if to in ["hall_l", "hall_r"]:
		return "hall"
	if to == "away" or to == "":
		return ""
	return "far"

## акустическая точка дальней комнаты по плану здания (будка внизу плана, налево — x<0, вперёд — −z); комнаты в мире стоят в десятках метров — это съёмочные площадки камер
static func far_pos(to: String) -> Vector3:
	for c in FNData.CAMS:
		if String(c["id"]) == to:
			var m: Vector2 = c["map"]
			return Vector3((m.x - 0.5) * 40.0, 1.0, (m.y - 0.88) * 30.0)
	return Vector3.ZERO

static func far_id(enemy: String) -> String:
	return String(FAR.get(enemy, ""))

## звук врага в коридоре и у двери (тот же характер, у двери громче)
static func hall_id(enemy: String) -> String:
	if enemy == "bot":
		return "clank"
	if enemy in ["clipper", "ghost"]:
		return "step"
	return "step_heavy"

## Звук присутствия у двери: разовые записи по кругу, пока враг стоит; ids чередуются, extra — вместо очередного звука с вероятностью extra_p
const PRESENCE := {
	"balon": {"ids": ["door_breath"], "gap": [2.6, 4.2], "first": [0.9, 1.6], "db": -9.0, "extra": "rustle", "extra_p": 0.3},
	"clipper": {"ids": ["blade"], "gap": [0.9, 1.5], "first": [0.0, 0.0], "db": 5.0},
	"bot": {"ids": ["servo", "mech_tick"], "gap": [1.4, 2.4], "first": [0.6, 1.2], "db": -4.0},
	"mod": {"ids": ["zap", "relay"], "gap": [1.6, 2.8], "first": [0.8, 1.4], "db": 12.0},
}
const BEHIND_DOOR_DB := -5.0           # дверь закрыта: то же, но глуше
const ARRIVE_DB := 2.0                # шаг прихода к двери (было −2)
const RETREAT_DB := [-14.5, -17.5, -20.5]   # три удаляющихся шага
const RETREAT_GAP := [0.45, 0.6]
const RETREAT_AT := [0.0, 0.45, 0.9]   # доля пути от двери к коридору

## MADK1D в шахте: события по состоянию вместо петли. Звуки — утверждённый C1 Heavy Duct Movement, разложенный на
## события: far — далёкое движение, hit — глухой удар по стенке, drag — волочение, near — удар у самой решётки,
## presence — он за решёткой и переносит вес. Вид → id записей даёт FNAudioGate.duct_id. Заход каждый раз
## складывается заново (duct_plan): по звуку понятно, где он, но последовательность не заучить.
const DUCT := {
	"enter": {"kind": "far", "db": -3.0},
	"marks": [[0.2, 0.3], [0.42, 0.55], [0.64, 0.76]],      # доли пути duct_t/duct_need, где звучат фразы
	"skip_p": 0.45,                                          # как часто одной из первых двух фраз нет
	"db": [-10.5, -6.5],                                      # громкость фразы: от дальнего конца к решётке (поправки записей — FNSound.FILE_TRIM, по замеру в игре)
	"drag_db": -1.0,
	"quiet_from": 0.8,                                       # дальше — затишье до удара в решётку
	"arrive": {"id": "grate_hit", "db": 12.0, "body_db": -4.0},      # body_db: под звоном решётки — тяжёлый удар тела (C1)
	"at_grate": {"kind": "presence", "gap": [1.5, 3.4], "db": -8.0},
	"bang": {"id": "grate_hit", "db": 4.0},
	"leave": {"kinds": ["hit", "far"], "at": [0.4, 0.0], "db": [-8.0, -8.0], "gap": [0.7, 1.1]},
}
## фразы движения: [вид, пауза перед ним (с или [от, до])]; у решётки удары — near
const DUCT_PHRASES := [
	[["hit", 0.0], ["hit", [0.3, 0.55]]],
	[["hit", 0.0], ["drag", [0.25, 0.4]]],
	[["drag", 0.0], ["hit", [0.75, 1.0]]],
	[["hit", 0.0], ["hit", [0.28, 0.45]], ["drag", [0.3, 0.5]]],
	[["hit", 0.0]],
]
static var _phrase_last := -1

## план одного захода: [[доля пути, доля расстояния от дальнего конца к решётке, [[вид, задержка с, дБ], …]], …]
static func duct_plan() -> Array:
	var marks: Array = (DUCT["marks"] as Array).map(func(m): return randf_range(m[0], m[1]))
	if randf() < float(DUCT["skip_p"]):
		marks.remove_at(randi() % 2)
	var plan: Array = []
	for k in marks:
		var dist := clampf(inverse_lerp(0.2, 0.76, float(k)), 0.0, 1.0)
		var pi := randi() % DUCT_PHRASES.size()
		if pi == _phrase_last:
			pi = (pi + 1 + randi() % (DUCT_PHRASES.size() - 1)) % DUCT_PHRASES.size()
		_phrase_last = pi
		var at := 0.0
		var evs: Array = []
		for e in DUCT_PHRASES[pi]:
			var gap = e[1]
			at += randf_range(gap[0], gap[1]) if gap is Array else float(gap)
			var kind := String(e[0])
			var db := lerpf(DUCT["db"][0], DUCT["db"][1], dist) + (float(DUCT["drag_db"]) if kind == "drag" else randf_range(-1.5, 0.0))
			evs.append(["near" if kind == "hit" and dist > 0.7 else kind, at, db])
		plan.append([float(k), lerpf(0.2, 0.8, dist), evs])
	return plan

const DUCT_FAR := {"l": Vector3(-4.5, 0.6, -6.5), "t": Vector3(0.35, 3.4, -7.0)}   # дальний конец шахты; ближний — FNOffice.point("vent_" + s)
