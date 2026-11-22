## Режиссёр напряжения «5 НОЧЕЙ»: по одному состоянию игры (без случайностей и без собственного звука) считает фазу ночи
## и плавный уровень 0..1. Читают его фон здания (FNAmbience) и свет будки (FNOffice) — только как оттенок, враги и числа не меняются.
class_name FNTension
extends RefCounted

const RISE := 0.5
const FALL := 0.12
const RECOVERY_SEC := 12.0
const NEAR_SPOTS := ["hall_l", "hall_r", "door_l", "door_r"]

var state := "CALM"
var level := 0.0
var changed_at := 0.0
var t := 0.0
var rec_t := 0.0
var was_out := false
var was_threat := false

## сброс в «спокойно» (для проверок)
func reset() -> void:
	state = "CALM"
	level = 0.0
	rec_t = 0.0
	was_out = false
	was_threat = false
	changed_at = t

func _threat(st: FNNight) -> bool:
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and (e.spot in ["door_l", "door_r"] or e.spot.begins_with("vent_") or e.spot.begins_with("duct_")):
			return true
	return false

func _critical(st: FNNight) -> bool:
	if st.power < 12.0:
		return true
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and e._at_door():
			var closed: bool = st.door["l"] if e.spot == "door_l" else (st.door["r"] if e.spot == "door_r" else (st.seal["l"] if e.spot == "vent_l" else st.seal["t"]))
			if not closed:
				return true
	return false

func _nearby(st: FNNight) -> bool:
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and (e.spot in NEAR_SPOTS or e.spot.begins_with("duct_") or e.spot.begins_with("vent_")):
			return true
	return false

func _uneasy(st: FNNight, night: int) -> bool:
	if night >= 3:
		return true
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and e.moves > 0 and e.spot != "away":
			return true
	return false

func tick(st: FNNight, dt: float, night: int) -> void:
	t += dt
	var out := st.power_out
	var threat := _threat(st)
	if was_out and not out:
		rec_t = RECOVERY_SEC
	if was_threat and not threat:
		rec_t = RECOVERY_SEC
	was_out = out
	was_threat = threat
	rec_t = maxf(0.0, rec_t - dt)
	var s := "CALM"
	var goal := 0.0
	if out:
		s = "BLACKOUT"
		goal = 0.0
	elif _critical(st):
		s = "CRITICAL"
		goal = 1.0
	elif _nearby(st):
		s = "NEARBY"
		goal = 0.7
	elif rec_t > 0.0:
		s = "RECOVERY"
		goal = 0.0
	elif _uneasy(st, night):
		s = "UNEASY"
		goal = 0.35
	level = move_toward(level, goal, (RISE if goal > level else FALL) * dt)
	if s != state:
		state = s
		changed_at = t
