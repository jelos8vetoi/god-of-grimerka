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
