## БАЛОН VOZDUH — главный маскот. Ходит по залам к левой или правой двери. Подолгу стоит и смотрит в камеру.
## Особенность: иногда проходит две комнаты за раз (из зала сразу в коридор) или пропадает между камерами —
## тогда в офисе слышен тяжёлый шаг и мигает лампа: это честное предупреждение, не случайность.
class_name FNBalon
extends FNEnemy

const NEXT := {
	"stage": ["arcade", "power"],
	"arcade": ["hall_l", "hall_l", "storage", "stage"],
	"storage": ["arcade"],
	"power": ["hall_r", "hall_r", "stage"],
	"hall_l": ["door_l"],
	"hall_r": ["door_r"],
	"away": [],
}
var transit_to := ""             # пропал между камерами: куда выйдет на следующем ходу

func _move(st) -> void:
	if spot == "away":
		go(st, transit_to, "appear")
		return
	# стоять и смотреть в камеру — тоже ход (на высоких уровнях реже)
	if spot in ["stage", "arcade", "power", "storage"] and st.rng.randf() < 0.28 - float(level) * 0.008:
		look = true
		st.emit("stare", {"e": id, "at": spot})
		return
	var opts: Array = NEXT.get(spot, ["stage"])
	var to: String = opts[st.rng.randi() % opts.size()]
	# помнит, какую дверь ты держишь: из зала чаще идёт той стороной, где дверь бывает открыта (с 5-го уровня)
	if spot == "stage" and level >= 5:
		var lean: float = float(st.habit("door_l")) - float(st.habit("door_r"))      # > 0 — левую держат чаще
		if absf(lean) > 0.12 and st.rng.randf() < clampf(absf(lean) * 1.6, 0.0, 0.8):
			to = "power" if lean > 0.0 else "arcade"
			st.emit("adapt", {"e": id, "how": "side", "to": to})
	# две комнаты за раз: из зала сразу в коридор, с тяжёлым шагом
	if spot == "stage" and level >= 4 and st.rng.randf() < 0.12 + float(level) * 0.006:
		to = "hall_l" if st.rng.randf() < 0.5 else "hall_r"
		st.emit("heavy_step", {"e": id, "side": to.substr(5, 1)})
		go(st, to, "skip")
		return
	# пропасть с камер на один ход (виден снова уже дальше по пути)
	if to in ["hall_l", "hall_r"] and st.rng.randf() < 0.22:
		transit_to = to
		st.emit("heavy_step", {"e": id, "side": to.substr(5, 1)})
		go(st, "away", "vanish")
		move_t *= 0.6
		return
	go(st, to)

func _retreat(st) -> void:
	go(st, "stage" if st.rng.randf() < 0.6 else ("arcade" if spot == "door_l" else "power"), "retreat")
	move_t = _interval(st) * 1.2
