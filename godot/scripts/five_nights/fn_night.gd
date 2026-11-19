## Директор ночи «5 НОЧЕЙ С ПАХАНОМ» — вся логика ночи без сцены: часы 12 AM → 6 AM, уровни врагов по часам,
## энергия и её расход, двери, свет, заслонки вентиляции, монитор и камеры, сбои MOD, пинг сервера,
## отключение света и «последний шанс» (ручной генератор), победа и гибель. Вид (офис, камеры, звук,
## скримеры) только читает состояние и события (events), сам ничего не решает. Эту же логику гоняет FNSim.
class_name FNNight
extends RefCounted

var rng := RandomNumberGenerator.new()
var night := 0                   # 0..4 — ночи 1–5, 5 — ночь 6, 6 — Custom Night
var custom := {}                 # Custom Night: враг → уровень 0..20
var t := 0.0
var hour := 0
var power := 100.0
var usage := 1
var door := {"l": false, "r": false}       # true — закрыта
var light := {"l": false, "r": false}
var seal := {"l": false, "t": false}       # заслонки вентиляции: левая шахта, верхняя
var monitor := false
var cam := "stage"
var yaw := 0.0                   # куда смотрит Пахан: −1 налево до упора, +1 направо
var cam_off_t := 0.0             # камеры погасли после СБРОСА
var glitches := {}               # сбои MOD: вид → данные
var enemies := {}                # id → FNEnemy
var events: Array = []           # [вид, данные] для сцены; сцена забирает
var outcome := ""                # "" / "win" / "dead"
var killer := ""
var kill_at := ""
# отключение света
var power_out := false
var dark_t := 0.0
var dark_need := 0.0
var crank_p := 0.0
var emergency_used := false
var stats := {"door_s": 0.0, "light_s": 0.0, "cam_s": 0.0, "seal_s": 0.0, "switches": 0, "bangs": 0, "resets": 0}

static func _make(id: String) -> FNEnemy:
	match id:
		"balon":
			return FNBalon.new()
		"madk1d":
			return FNMadk1d.new()
		"bot":
			return FNBot.new()
		"clipper":
			return FNClipper.new()
		"ghost":
			return FNGhost.new()
	return FNMod.new()

func setup(n: int, seed_v: int, levels := {}) -> void:
	night = n
	custom = levels
	rng.seed = seed_v
	for id in FNData.ORDER:
		var e: FNEnemy = _make(id)
		e.setup(self, id, _level_for(id, 0))
		enemies[id] = e

func _level_for(id: String, h: int) -> int:
	if night >= FNData.NIGHTS.size():
		return clampi(int(custom.get(id, 0)), 0, 20)
	return FNData.level(night, id, h)

func emit(kind: String, data := {}) -> void:
	events.append([kind, data])

func take_events() -> Array:
	var e := events
	events = []
	return e

func hours_f() -> float:
	return t / FNData.HOUR_SEC

func clock() -> String:
	return FNData.HOURS[clampi(hour, 0, 6)]

# ---------------- шаг ----------------
func step(dt: float) -> void:
	if outcome != "":
		return
	t += dt
	var h := int(t / FNData.HOUR_SEC)
	if h != hour:
		hour = h
		if hour >= 6:
			outcome = "win"
			emit("win", {})
			return
		for id in enemies:
			(enemies[id] as FNEnemy).level = _level_for(id, hour)
		emit("hour", {"h": hour})
	cam_off_t = maxf(0.0, cam_off_t - dt)
	if power_out:
		_dark(dt)
		return
	_drain(dt)
	if power_out:
		return
	for id in FNData.ORDER:
		(enemies[id] as FNEnemy).tick(self, dt)
		if outcome != "":
			return

func _drain(dt: float) -> void:
	var P := FNData.POWER
	var d := float(P["base"])
	usage = 1
	for s in ["l", "r"]:
		if door[s]:
			d += float(P["door"])
			usage += 1
			stats["door_s"] = float(stats["door_s"]) + dt
		if light[s]:
			d += float(P["light"])
			usage += 1
			stats["light_s"] = float(stats["light_s"]) + dt
	for s in ["l", "t"]:
		if seal[s]:
			d += float(P["seal"])
			usage += 1
			stats["seal_s"] = float(stats["seal_s"]) + dt
	if monitor:
		d += float(P["monitor"])
		usage += 1
		stats["cam_s"] = float(stats["cam_s"]) + dt
	power = maxf(0.0, power - d * dt)
	if power <= 0.0:
		_power_out()

## примерное время до нуля при нынешнем расходе (с)
func time_left() -> float:
	var P := FNData.POWER
	var d := float(P["base"]) + (float(P["door"]) * (int(door["l"]) + int(door["r"]))) + float(P["light"]) * (int(light["l"]) + int(light["r"])) \
		+ float(P["seal"]) * (int(seal["l"]) + int(seal["t"])) + (float(P["monitor"]) if monitor else 0.0)
	return power / maxf(0.01, d)

# ---------------- темнота: последний шанс ----------------
func _power_out() -> void:
	power_out = true
	power = 0.0
	door = {"l": false, "r": false}
	light = {"l": false, "r": false}
	seal = {"l": false, "t": false}
	monitor = false
	dark_t = 0.0
	crank_p = 0.0
	dark_need = rng.randf_range(9.0, 14.0) if not emergency_used else rng.randf_range(6.0, 9.0)
	emit("power_out", {"crank": not emergency_used})

func _dark(dt: float) -> void:
	dark_t += dt
	if dark_t >= 3.0 and dark_t - dt < 3.0:
		emit("dark_eyes", {})                 # у левого проёма загораются глаза Балона
	if dark_t >= 3.0 + dark_need:
		killer = "balon"
		kill_at = "dark"
		outcome = "dead"
		emit("attack", {"e": "balon", "at": "dark"})

## ручной генератор: оборот рукоятки (A/D по очереди). 6 % — свет вернулся (один раз за ночь)
func crank() -> void:
	if not power_out or emergency_used or outcome != "":
		return
	crank_p += float(FNData.POWER["crank"])
	emit("crank", {"p": crank_p})
	if crank_p >= 6.0:
		power_out = false
		emergency_used = true
		power = 6.0
		for id in enemies:
			var e: FNEnemy = enemies[id]
			if e.spot in ["door_l", "door_r", "vent_l", "vent_t"]:
				e._retreat(self)
		emit("power_back", {})

# ---------------- управление ----------------
func set_door(s: String, closed: bool) -> bool:
	if power_out or door[s] == closed:
		return false
	door[s] = closed
	emit("door", {"s": s, "closed": closed})
	return true

func set_light(s: String, on: bool) -> void:
	if power_out:
		on = false
	if light[s] == on:
		return
	light[s] = on
	emit("light", {"s": s, "on": on})

func set_seal(s: String, closed: bool) -> void:
	if power_out or seal[s] == closed:
		return
	seal[s] = closed
	emit("seal", {"s": s, "closed": closed})

func set_monitor(on: bool) -> void:
	if power_out:
		on = false
	if monitor == on:
		return
	monitor = on
	emit("monitor", {"on": on})

func set_cam(id: String) -> void:
	if cam == id:
		return
	cam = id
	stats["switches"] = int(stats["switches"]) + 1
	emit("cam", {"id": id})

func reset_system() -> bool:
	if power_out or power <= float(FNData.POWER["reset"]) + 0.5:
		return false
	power -= float(FNData.POWER["reset"])
	glitches.clear()
	cam_off_t = 2.5
	stats["resets"] = int(stats["resets"]) + 1
	(enemies["mod"] as FNMod).reset(self)
	emit("reset", {})
	return true

# ---------------- то, что спрашивают враги ----------------
func cams_dead() -> bool:
	return power_out or cam_off_t > 0.0

## камера врёт (MOD подсунул старую картинку)
func cam_lies(id: String) -> bool:
	return glitches.has("freeze") and String(glitches["freeze"]) == id

## камера в помехах: BOT в этой комнате
func jammed(id: String) -> bool:
	var b: FNEnemy = enemies["bot"]
	return b.level > 0 and b.spot == id

## видит ли сейчас Пахан эту точку (для GHOST): на камере или в левом углу офиса
func sees(spot: String) -> bool:
	if spot == "corner":
		return not monitor and yaw < -0.62 and not power_out
	return monitor and cam == spot and not cams_dead() and not cam_lies(spot)

func attack(eid: String, at: String) -> void:
	if outcome != "":
		return
	outcome = "dead"
	killer = eid
	kill_at = at
	emit("attack", {"e": eid, "at": at})

func force_open(s: String) -> void:
	if not door[s] or power_out:
		return
	door[s] = false
	emit("force_open", {"s": s})

func add_glitch(kind: String, data := "") -> void:
	if kind == "freeze" and data == "":
		var ids: Array = FNData.CAMS.map(func(c): return c["id"])
		data = ids[rng.randi() % ids.size()]
	if kind == "labels":
		var a := rng.randi() % FNData.CAMS.size()
		data = "%d,%d" % [a, (a + 1 + rng.randi() % (FNData.CAMS.size() - 1)) % FNData.CAMS.size()]
	if kind == "door_fake":
		data = "l" if rng.randf() < 0.5 else "r"
	if kind == "fake_alarm":
		data = ["ЛЕВАЯ ДВЕРЬ: ВЗЛОМ", "ВЕНТИЛЯЦИЯ: ДВИЖЕНИЕ", "ЭНЕРГИЯ: УТЕЧКА", "ПРАВАЯ ДВЕРЬ: ОТКРЫТА"][rng.randi() % 4]
	glitches[kind] = data
	emit("glitch", {"k": kind, "d": data})

## подпись камеры с учётом сбоя «labels»
func cam_label(i: int) -> String:
	if glitches.has("labels"):
		var p: PackedStringArray = String(glitches["labels"]).split(",")
		if p.size() == 2:
			if i == int(p[0]):
				i = int(p[1])
			elif i == int(p[1]):
				i = int(p[0])
	return String(FNData.CAMS[i]["name"])

## что показывает индикатор двери (MOD может врать или гасить)
func door_led(s: String) -> int:
	if glitches.has("leds_off"):
		return -1
	if glitches.has("door_fake") and String(glitches["door_fake"]) == s:
		return 0 if door[s] else 1
	return 1 if door[s] else 0

## кто где — для проверки и симуляций
func where() -> Dictionary:
	var r := {}
	for id in enemies:
		r[id] = (enemies[id] as FNEnemy).spot
	return r
