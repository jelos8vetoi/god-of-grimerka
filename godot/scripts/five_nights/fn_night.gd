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
var stats := {"door_s": 0.0, "light_s": 0.0, "cam_s": 0.0, "seal_s": 0.0, "switches": 0, "bangs": 0, "resets": 0, "lures": 0, "fixes": 0, "browns": 0}
# происшествия (своё зерно — не сдвигают ходы врагов): поломка камеры, перебой электричества, приманка
var inc := RandomNumberGenerator.new()
var broken := ""                 # сломанная камера: «НЕТ СИГНАЛА», пока не перезапустишь (держать C) — или сама через BROKEN_MAX
var broken_t := 0.0
var fix_t := 0.0                 # сколько уже держат перезапуск
var break_next := 0.0
var brown_warn := 0.0            # предупреждение: лампы гудят и мигают — сейчас будет перебой
var brown_t := 0.0               # перебой: камеры и фонари не работают, двери держат
var brown_next := 0.0
var lure_cd := 0.0
var lure_uses := 0
const FIX_NEED := 3.0
const BROKEN_MAX := 60.0
const BROWN_WARN := 2.5
const BROWN_LEN := 4.0
const LURE_CD := 30.0
const LURE_POWER := 1.5
const LURE_ROOMS := ["stage", "arcade", "storage", "server", "power"]
## кого тянет приманка (звук игрушки в комнате) и как сильно; MADK1D и GHOST её не слышат
const LURE_PULL := {"balon": 0.85, "clipper": 0.6, "bot": 0.55, "mod": 0.45}

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
	inc.seed = seed_v ^ 0x5bd1e995
	break_next = inc.randf_range(70.0, 140.0) if n >= 1 else 1e9
	brown_next = inc.randf_range(90.0, 170.0) if n >= 2 else 1e9
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

# ---------------- привычки игрока ----------------
## Что игрок делал последние секунд сорок (всё старше — забывается): какую дверь и заслонку держит закрытой, сколько
## смотрит в камеры и в какие, как долго сидит на одной. Обитатели читают только это — прошлое, а не нажатия:
## держишь левую дверь — Балон пойдёт справа, сидишь на камере коридора — CLIPPER не станет ждать, избегаешь
## камер GHOST — он придёт в угол будки. Предупреждения перед атакой остаются прежними.
const HAB_SEC := 40.0
var hab := {"door_l": 0.0, "door_r": 0.0, "seal_l": 0.0, "seal_t": 0.0, "mon": 0.0, "light": 0.0}
var hab_cam := {}                # камера → сколько на неё смотрели (с, с забыванием)
var cam_hold := 0.0              # сколько секунд подряд открыта одна и та же камера

func _habits(dt: float) -> void:
	var k := exp(-dt / HAB_SEC)
	for key in hab:
		hab[key] = float(hab[key]) * k
	for c in hab_cam:
		hab_cam[c] = float(hab_cam[c]) * k
	if door["l"]:
		hab["door_l"] = float(hab["door_l"]) + dt
	if door["r"]:
		hab["door_r"] = float(hab["door_r"]) + dt
	if seal["l"]:
		hab["seal_l"] = float(hab["seal_l"]) + dt
	if seal["t"]:
		hab["seal_t"] = float(hab["seal_t"]) + dt
	if light["l"] or light["r"]:
		hab["light"] = float(hab["light"]) + dt
	if monitor:
		hab["mon"] = float(hab["mon"]) + dt
		hab_cam[cam] = float(hab_cam.get(cam, 0.0)) + dt
		cam_hold += dt
	else:
		cam_hold = 0.0

## доля времени 0..1 (за последние HAB_SEC): 0 — никогда, 1 — всё время
func habit(key: String) -> float:
	return clampf(float(hab.get(key, 0.0)) / HAB_SEC, 0.0, 1.0)

## доля времени, что игрок смотрел на эти камеры
func cam_share(ids: Array) -> float:
	var s := 0.0
	for id in ids:
		s += float(hab_cam.get(id, 0.0))
	return clampf(s / HAB_SEC, 0.0, 1.0)

## камера, на которую игрок смотрит чаще всего ("" — почти не смотрит)
func top_cam() -> String:
	var best := ""
	var bv := 3.0
	for c in hab_cam:
		if float(hab_cam[c]) > bv:
			bv = float(hab_cam[c])
			best = String(c)
	return best

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
	_habits(dt)
	_incidents(dt)
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

# ---------------- происшествия ----------------
func _incidents(dt: float) -> void:
	lure_cd = maxf(0.0, lure_cd - dt)
	# поломка камеры
	if broken != "":
		broken_t += dt
		if broken_t >= BROKEN_MAX:
			broken = ""
			emit("cam_fixed", {"auto": true})
	else:
		break_next -= dt
		if break_next <= 0.0:
			var ids: Array = FNData.CAMS.map(func(c): return String(c["id"]))
			broken = String(ids[inc.randi() % ids.size()])
			broken_t = 0.0
			fix_t = 0.0
			break_next = inc.randf_range(80.0, 160.0)
			emit("cam_broken", {"id": broken})
	# перебой: предупреждение → короткая темнота камер и фонарей → снова свет
	if brown_t > 0.0:
		brown_t -= dt
		if brown_t <= 0.0:
			brown_next = inc.randf_range(100.0, 180.0)
			emit("brown_end", {})
	elif brown_warn > 0.0:
		brown_warn -= dt
		if brown_warn <= 0.0:
			brown_t = BROWN_LEN
			stats["browns"] = int(stats["browns"]) + 1
			for s in ["l", "r"]:
				set_light(s, false)
			emit("brown", {})
	else:
		brown_next -= dt
		if brown_next <= 0.0:
			brown_warn = BROWN_WARN
			emit("brown_warn", {})

## перезапуск сломанной камеры: держать C, пока смотришь именно на неё (3 с), стоит 1 % энергии
func fix_cam(dt: float) -> bool:
	if broken == "" or not monitor or cam != broken or power_out or brown_t > 0.0:
		fix_t = maxf(0.0, fix_t - dt)
		return false
	fix_t += dt
	if fix_t >= FIX_NEED:
		broken = ""
		fix_t = 0.0
		power = maxf(0.0, power - 1.0)
		stats["fixes"] = int(stats["fixes"]) + 1
		emit("cam_fixed", {"auto": false})
		return true
	return false

## приманка: звук игрушки в выбранной комнате тянет туда врагов из коридоров и соседних комнат (не от дверей —
## там уже поздно). Каждый раз действует слабее: враги привыкают. Перезарядка LURE_CD, цена LURE_POWER.
func lure(room: String) -> Array:
	if lure_cd > 0.0 or power_out or brown_t > 0.0 or not (room in LURE_ROOMS) or power <= LURE_POWER + 0.5:
		return []
	lure_cd = LURE_CD
	power -= LURE_POWER
	lure_uses += 1
	stats["lures"] = int(stats["lures"]) + 1
	var fade := maxf(0.25, 1.0 - 0.15 * float(lure_uses - 1))
	var moved: Array = []
	for id in LURE_PULL:
		var e: FNEnemy = enemies[id]
		if e.level <= 0 or e.entered or e._at_door() or e.spot in ["away", "office", "corner", room]:
			continue
		if inc.randf() < float(LURE_PULL[id]) * fade:
			e.go(self, room, "lure")
			e.move_t = maxf(e.move_t, 6.0)
			moved.append(id)
	emit("lure", {"room": room, "moved": moved})
	return moved

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
	if power_out or brown_t > 0.0:
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
	cam_hold = 0.0
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
	return power_out or cam_off_t > 0.0 or brown_t > 0.0

## эта камера сейчас не показывает (сломана)
func cam_broken(id: String) -> bool:
	return broken == id

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
	return monitor and cam == spot and not cams_dead() and not cam_lies(spot) and broken != spot

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
		# MOD бьёт по привычке: замораживает ту камеру, на которую ты смотришь чаще всего (с 8-го уровня)
		var mod_e: FNEnemy = enemies.get("mod")
		if mod_e != null and mod_e.level >= 8 and top_cam() != "" and top_cam() != "room9" and rng.randf() < 0.7:
			data = top_cam()
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
