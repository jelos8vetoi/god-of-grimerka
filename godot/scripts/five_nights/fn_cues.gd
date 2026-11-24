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

## MADK1D в шахте: события по состоянию вместо петли. steps: [доля пути duct_t/duct_need, id, дБ, доля расстояния от дальней точки к решётке]
const DUCT := {
	"enter": {"id": "duct_far", "db": -6.0},
	"steps": [[0.38, "duct_move", -10.0, 0.35], [0.68, "duct_move", 5.5, 0.75]],
	"burst": [2, 3], "burst_gap": [0.28, 0.5],
	"quiet_from": 0.8,
	"arrive": {"id": "grate_hit", "db": 12.0},
	"at_grate": {"id": "rustle", "gap": [1.3, 2.2], "db": -1.5},
	"bang": {"id": "grate_hit", "db": 4.0},
	"leave": {"id": "duct_far", "db": [-8.0, -13.0], "gap": [0.6, 0.9]},
}
const DUCT_FAR := {"l": Vector3(-4.5, 0.6, -6.5), "t": Vector3(0.35, 3.4, -7.0)}   # дальний конец шахты; ближний — FNOffice.point("vent_" + s)
