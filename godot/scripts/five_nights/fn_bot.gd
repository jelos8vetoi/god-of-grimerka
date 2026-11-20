## BOT — механический, живёт в серверной. Сервер время от времени подаёт ПИНГ: писк в офисе и красная лампа
## «СЕРВЕР» на пульте. Принять пинг — открыть CAM 6 и подержать её ACK_SEC секунд. Пропустил — BOT
## просыпается и идёт к правой двери быстрее обычного. Пока BOT в комнате, её камера — в помехах (честно
## видно: «ПОМЕХИ»), шаги у него лязгающие. Пинг — его главная угроза: если вовремя принимать, он почти не ходит.
class_name FNBot
extends FNEnemy

const ACK_SEC := 1.1
var awake := false
var ping_left := 0.0             # > 0 — пинг идёт, столько секунд осталось
var ack_t := 0.0
var calm_t := 0.0                # после принятого пинга новый не сразу

func tick(st, dt: float) -> void:
	if level <= 0 or entered:
		return
	calm_t = maxf(0.0, calm_t - dt)
	if ping_left > 0.0:
		if st.monitor and st.cam == "server" and not st.cams_dead():
			ack_t += dt
			if ack_t >= ACK_SEC:
				ping_left = 0.0
				ack_t = 0.0
				calm_t = 14.0
				st.emit("ping_ok", {"e": id})
				if awake and spot in ["server", "power"]:
					awake = false
		else:
			ack_t = maxf(0.0, ack_t - dt * 2.0)
			ping_left -= dt
			if ping_left <= 0.0:
				ping_left = 0.0
				awake = true
				st.emit("ping_lost", {"e": id})
				move_t = 0.5
	super.tick(st, dt)

## проснулся — ходит почти всегда, даже на низком уровне (пропущенный пинг — это ошибка игрока)
func roll(st) -> bool:
	if awake:
		return st.rng.randf() < 0.55 + float(level) * 0.022
	return super.roll(st)

## проснулся — ходит почти вдвое чаще (у двери ждёт столько же, сколько все)
func _interval(st) -> float:
	return super._interval(st) * (0.55 if awake else 1.0)

func _move(st) -> void:
	if not awake:
		# спит в серверной: ход — это пинг
		if ping_left <= 0.0 and calm_t <= 0.0 and spot == "server":
			ping_left = lerpf(17.0, 10.0, float(level) / 20.0)
			ack_t = 0.0
			st.emit("ping", {"e": id, "sec": ping_left})
		elif spot != "server" and spot != "power":
			go(st, "power")
		return
	match spot:
		"server":
			go(st, "power")
		"power":
			go(st, "hall_r")
		"hall_r":
			go(st, "door_r")
		_:
			go(st, "server")

func _retreat(st) -> void:
	awake = false
	go(st, "server", "retreat")
	move_t = _interval(st) * 1.5
	calm_t = 8.0
