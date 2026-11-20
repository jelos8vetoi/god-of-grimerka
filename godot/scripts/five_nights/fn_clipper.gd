## CLIPPER — самый быстрый. Склад → игровая → левый коридор → рывок к левой двери. Ходит часто, но короткими
## перебежками. Пока на него смотрят камерой в коридоре, он замирает (не ходит). У двери — скрежет лезвия
## по стене: от него до удара считанные секунды (linger). Контрмеры: закрыть левую дверь или ударить светом —
## свет сгоняет его обратно на склад (LIGHT_SEC секунд света). Из игровой изредка проскакивает мимо коридора —
## но скрежет у двери есть всегда.
class_name FNClipper
extends FNEnemy

const LIGHT_SEC := 0.45
const CAMP_SEC := 9.0            # сколько можно держать его камерой в коридоре, с
var light_t := 0.0
var rush := false                # его пересидели на камере — следующий раз идёт мимо коридора

func tick(st, dt: float) -> void:
	if level <= 0 or entered:
		return
	if spot == "door_l" and bool(st.light["l"]) and st.power > 0.0:
		light_t += dt
		if light_t >= LIGHT_SEC:
			light_t = 0.0
			st.emit("flinch", {"e": id})
			_retreat(st)
			return
	else:
		light_t = 0.0
	# камера держит его в коридоре
	if spot == "hall_l" and st.monitor and st.cam == "hall_l" and not st.cams_dead() and not st.cam_lies("hall_l"):
		move_t = maxf(move_t, 0.8)
		# …но сидеть на этой камере вечно не выйдет: через CAMP_SEC он уходит обратно в игровую и в следующий раз
		# проскочит коридор без остановки (скрежет у двери будет, как всегда)
		if float(st.cam_hold) > CAMP_SEC and level >= 4:
			rush = true
			st.emit("adapt", {"e": id, "how": "camp"})
			go(st, "arcade", "camp")
			move_t = _interval(st) * 0.7
			return
	super.tick(st, dt)

func _move(st) -> void:
	match spot:
		"storage":
			go(st, "arcade")
		"arcade":
			rush = false                               # пересидели на камере: он просто ушёл и вернётся обычным путём (рывок мимо коридора делал ночи нечестными)
			if level >= 6 and st.rng.randf() < 0.18:
				go(st, "door_l", "dash")          # проскочил мимо камеры коридора
			else:
				go(st, "hall_l")
		"hall_l":
			go(st, "door_l", "dash")
		_:
			go(st, "storage")

func go(st, to: String, why := "") -> void:
	super.go(st, to, why)
	if to == "door_l":
		st.emit("scrape", {"e": id})

func _retreat(st) -> void:
	go(st, "storage", "retreat")
	move_t = _interval(st) * 1.6
