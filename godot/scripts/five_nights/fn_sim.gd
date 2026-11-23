## Симуляции ночей «5 НОЧЕЙ С ПАХАНОМ» на чистой логике (FNNight) — ночь за доли секунды.
## Игрок моделируется честно: знает только то, что увидел бы или услышал — свет у двери, звуки (шаги, скрежет,
## стук в шахте, писк сервера), камеры. Реакция с задержкой, слух — с промахами (кроме «perfect»).
## Стратегии: perfect — безупречный (проверка «смерть только из-за ошибки»); good — хороший игрок;
## average — средний; lazy — ничего не делает; turtle — обе двери закрыты всю ночь; spam — свет и заслонки
## всё время; starer — не отводит взгляд от камер.
class_name FNSim

const PROFILE := {
	"perfect": {"react": 0.25, "hear": 1.0, "poll": 7.0, "cam": 0.35, "ghost": 0.4, "ping": 1.5, "mod": 2, "slip": 0.0},
	"good": {"react": 0.7, "hear": 0.92, "poll": 5.0, "cam": 0.4, "ghost": 0.8, "ping": 4.0, "mod": 3, "slip": 0.01},
	"average": {"react": 1.2, "hear": 0.75, "poll": 7.0, "cam": 0.45, "ghost": 1.2, "ping": 7.0, "mod": 4, "slip": 0.03},
}

## журнал ходов врагов для проверок темпа: [t, враг, откуда, куда]; пишется, если trace_on
static var trace_on := false
static var trace: Array = []

static func run(n: int, strategy: String, seed_v: int, levels := {}) -> Dictionary:
	var st := FNNight.new()
	st.setup(n, seed_v, levels)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + 7
	var dt := 0.1
	var P: Dictionary = PROFILE.get(strategy, PROFILE["good"])
	var know := {}                # точка у офиса → когда узнал (с учётом реакции)
	var poll_t := {"l": 0.0, "r": 0.0}
	var cam_t := 0.0
	var ghost_seen := -1.0
	var ping_at := -1.0
	var cams: Array = FNData.CAMS.map(func(c): return c["id"])
	var hear_t := 0.0
	while st.outcome == "" and st.t < 7.0 * FNData.HOUR_SEC:
		for ev in st.take_events():
			var k: String = ev[0]
			var d: Dictionary = ev[1]
			match k:
				"move", "scrape":
					if trace_on and k == "move":
						trace.append([st.t, String(d["e"]), String(d["from"]), String(d["to"])])
					var to := String(d.get("to", "door_l" if k == "scrape" else ""))
					if to in ["door_l", "door_r", "vent_l", "vent_t", "duct_l", "duct_t"] and rng.randf() < float(P["hear"]):
						know[to] = st.t + float(P["react"]) * rng.randf_range(0.8, 1.4)
				"ping":
					ping_at = st.t + float(P["ping"]) * rng.randf_range(0.7, 1.3)
		# звуки у двери и в шахте повторяются (шаги, стук, скрежет) — услышать можно и со второго раза
		hear_t -= dt
		if hear_t <= 0.0:
			hear_t = 1.0
			for id in st.enemies:
				var sp: String = (st.enemies[id] as FNEnemy).spot
				if sp in ["door_l", "door_r", "vent_l", "vent_t", "duct_l", "duct_t"] and not know.has(sp) and rng.randf() < float(P["hear"]) * 0.6:
					know[sp] = st.t + float(P["react"])
		match strategy:
			"lazy":
				pass
			"turtle":
				st.set_door("l", true)
				st.set_door("r", true)
			"spam":
				st.set_light("l", true)
				st.set_light("r", true)
				st.set_seal("l", true)
				st.set_seal("t", true)
			"starer":
				st.set_monitor(true)
				cam_t -= dt
				if cam_t <= 0.0:
					cam_t = 4.0
					st.set_cam(cams[rng.randi() % cams.size()])
			_:
				_play(st, P, rng, dt, know, poll_t, ghost_seen, ping_at, cams)
				if ping_at >= 0.0 and st.t >= ping_at and (st.enemies["bot"] as FNBot).ping_left <= 0.0:
					ping_at = -1.0
				var g: FNGhost = st.enemies["ghost"]
				if g.spot != "away" and st.sees(g.spot):
					if ghost_seen < 0.0:
						ghost_seen = st.t
				else:
					ghost_seen = -1.0
				if ghost_seen >= 0.0 and st.t - ghost_seen >= float(P["ghost"]):
					# отвёл взгляд: другая камера или монитор вниз / взгляд прямо
					if st.monitor:
						st.set_cam("hall_l" if st.cam != "hall_l" else "hall_r")
					st.yaw = 0.0
					ghost_seen = -1.0
		st.step(dt)
	return {"outcome": st.outcome, "killer": st.killer, "at": st.kill_at, "t": st.t, "power": st.power, "hour": st.hour, "stats": st.stats}

## один шаг «думающего» игрока
static func _play(st: FNNight, P: Dictionary, rng: RandomNumberGenerator, dt: float, know: Dictionary, poll_t: Dictionary, _ghost_seen: float, ping_at: float, cams: Array) -> void:
	if st.power_out:
		if rng.randf() < 0.9:
			st.crank()                             # крутит генератор что есть сил
		return
	# пинг сервера: открыть CAM 6 и держать
	if ping_at >= 0.0 and st.t >= ping_at and (st.enemies["bot"] as FNBot).ping_left > 0.0:
		st.set_monitor(true)
		st.set_cam("server")
		return
	# сбои MOD
	if st.glitches.size() >= int(P["mod"]):
		st.reset_system()
	# двери: узнал, что у двери кто-то — закрыть; ушёл (стук стих) — открыть
	for s in ["l", "r"]:
		var spot: String = "door_" + s
		poll_t[s] = float(poll_t[s]) - dt
		var someone := false
		for id in st.enemies:
			if (st.enemies[id] as FNEnemy).spot == spot:
				someone = true
		# проверка светом раз в poll секунд (свет на полсекунды)
		if float(poll_t[s]) <= 0.0:
			poll_t[s] = float(P["poll"]) * rng.randf_range(0.8, 1.2)
			if someone and rng.randf() > float(P["slip"]):
				know[spot] = st.t + float(P["react"]) * 0.5
			if someone and (st.enemies["clipper"] as FNEnemy).spot == spot:
				st.set_light(s, true)                # свет сгоняет CLIPPER
		elif st.light[s] and float(poll_t[s]) < float(P["poll"]) - 0.6:
			st.set_light(s, false)
		if know.has(spot) and st.t >= float(know[spot]):
			if someone:
				if st.monitor:
					st.set_monitor(false)
				if (st.enemies["clipper"] as FNEnemy).spot == spot and rng.randf() < 0.5:
					st.set_light(s, true)
				else:
					st.set_door(s, true)
			else:
				know.erase(spot)
		if st.door[s] and not someone:
			st.set_door(s, false)
	# вентиляция: слышно, в какой шахте — закрыть ту заслонку; ушёл — открыть
	var m: FNEnemy = st.enemies["madk1d"]
	for s in ["l", "t"]:
		var near: bool = m.spot == "vent_" + s or m.spot == "duct_" + s
		var heard: bool = know.has("vent_" + s) or know.has("duct_" + s)
		var at_t: float = float(know.get("vent_" + s, know.get("duct_" + s, 1e9)))
		if near and heard and st.t >= at_t and m.spot == "vent_" + s:
			st.set_seal(s, true)
		elif not near and st.seal[s]:
			st.set_seal(s, false)
			know.erase("vent_" + s)
			know.erase("duct_" + s)
	# камеры: иногда смотрит, по очереди коридоры и залы
	if not st.monitor and rng.randf() < float(P["cam"]) * dt:
		st.set_monitor(true)
		st.set_cam(cams[rng.randi() % cams.size()])
	elif st.monitor and rng.randf() < 0.9 * dt:
		st.set_monitor(false)
	elif st.monitor and rng.randf() < 0.6 * dt:
		st.set_cam(cams[rng.randi() % cams.size()])

## сводка: n прогонов ночи
static func batch(n_night: int, strategy: String, runs: int, levels := {}) -> Dictionary:
	var wins := 0
	var killers := {}
	var power_left := 0.0
	var out_power := 0
	for k in runs:
		var r := run(n_night, strategy, 500 + k * 13, levels)
		if r["outcome"] == "win":
			wins += 1
			power_left += float(r["power"])
		else:
			var key := "%s@%s" % [r["killer"], r["at"]]
			killers[key] = int(killers.get(key, 0)) + 1
			if r["at"] == "dark":
				out_power += 1
	return {"win": float(wins) / float(runs), "killers": killers, "power": power_left / maxf(1.0, float(wins)), "dark": out_power}
