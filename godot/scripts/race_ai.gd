## Бот-гонщик: выдаёт RaceInput на шаг — тот же ввод, что у игрока, никаких телепортов и подталкиваний.
## Едет по трассе с упреждением (точка впереди на своей полосе), тормозит перед крутыми поворотами, заносит
## в них (если умеет), жмёт турбо на прямых, ошибается (дрожь руля, поздний тормоз), объезжает препятствия,
## иногда едет через срезку, пользуется предметами по обстановке. Уровень — RaceData.BOTS.
class_name RaceAI
extends RefCounted

var r                        # RaceRider
var race                     # race.gd
var track: RaceTrack
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var lane := 0.0              # своя полоса: −1..1 доли половины ширины
var lane_want := 0.0
var lane_t := 0.0
var noise := 0.0
var noise_v := 0.0
var shortcut_lap := -99      # круг, на котором решено ехать через срезку
var go_short := false
var drift_plan := false
var corner_seen := 0.0
var late_t := 0.0
var hold_t := 0.0            # сколько держит предмет
var back_t := 0.0            # сдаёт назад (застрял)
var turbo_hold := false

func setup(rider, rc, level: String, seed_v: int) -> void:
	r = rider
	race = rc
	track = rc.track
	cfg = RaceData.BOTS.get(level, RaceData.BOTS["normal"])
	rng.seed = seed_v
	lane = rng.randf_range(-0.5, 0.5)
	lane_want = lane

func think(dt: float) -> RaceInput:
	var inp := RaceInput.new()
	var P := RaceData.PHYS
	var spd: float = r.speed
	var pos: Vector3 = r.global_position
	# полоса понемногу гуляет — боты не едут гуськом по одной линии
	lane_t -= dt
	if lane_t <= 0.0:
		lane_t = rng.randf_range(1.5, 4.0)
		lane_want = rng.randf_range(-0.6, 0.6)
	lane = move_toward(lane, lane_want, dt * 0.4)
	# срезка: решение раз на круг, перед развилкой
	if shortcut_lap != r.lap:
		shortcut_lap = r.lap
		go_short = rng.randf() < float(cfg["short"])
	var look := 5.0 + absf(spd) * 0.5
	var target: Vector3
	var near_split: float = fposmod(track.short_from - r.s, track.L)
	if track.SP.size() > 1 and (r.on_short or (go_short and near_split < 16.0)):
		var ss: float = float(r.proj.get("ss", 0.0)) if r.on_short else 0.0
		var want_ss := ss + look if r.on_short else maxf(4.0, look - near_split)
		if want_ss >= track.SL:
			var i := track.at_s(track.short_to + (want_ss - track.SL))
			target = track.P[i]
		else:
			target = track.SP[track.short_point(want_ss)]
	else:
		var i := track.at_s(r.s + look)
		var right: Vector3 = track.T[i].cross(Vector3.UP)
		var off := lane * (track.W[i] * 0.5 - 1.6)
		# препятствие впереди на своей полосе — уходим в другую сторону
		var half_w: float = track.W[i] * 0.5 - 1.2
		for o in race.obstacles:
			var d: Vector3 = (o[0] as Vector3) - pos
			var ahead := d.dot(r.fwd())
			if ahead > 2.0 and ahead < 20.0:
				var lat_o := ((o[0] as Vector3) - track.P[i]).dot(right)      # где препятствие поперёк дороги
				if absf(lat_o - off) < float(o[1]) + 1.6:
					off = lat_o - signf(lat_o if absf(lat_o) > 0.3 else 1.0) * (float(o[1]) + 2.4)
		off = clampf(off, -half_w, half_w)
		target = track.P[i] + right * off
	# руль: угол до точки
	var to := target - pos
	var desired := atan2(to.x, to.z)
	var diff := angle_difference(r.heading, desired)
	var steer := clampf(-diff * 2.4, -1.0, 1.0)
	if r.drifting:
		# в заносе руль задаёт дугу: целимся направлением движения
		var vh := atan2(r.vdir.x, r.vdir.z)
		steer = r.steer_for_rate(-angle_difference(vh, desired) * 2.2)
	noise_v += rng.randf_range(-1.0, 1.0) * dt * 6.0
	noise_v = clampf(noise_v, -1.0, 1.0) * (1.0 - dt * 1.5)
	noise = lerpf(noise, noise_v, dt * 3.0)
	steer = clampf(steer + noise * float(cfg["noise"]), -1.0, 1.0)
	# скорость: перед крутым поворотом — медленнее (поздний тормоз — ошибка)
	var look_d := 10.0 + absf(spd) * 0.9
	var turn := track.turn_ahead(r.s, look_d)
	var vmax: float = float(P["vmax"]) * float(cfg["pace"])
	# с какой скоростью поворот ещё проходится рулём: нужная угловая скорость v·κ не больше 80% руля
	var kappa := turn / look_d
	var safe := (float(P["steer"]) * 0.8 / maxf(kappa, 0.001)) * float(cfg["corner"])
	if drift_plan:
		safe += 3.0
	var tgt_speed := minf(vmax, safe)
	if turn > 0.7 and corner_seen <= 0.0:
		corner_seen = 2.5
		late_t = 0.45 if rng.randf() < float(cfg["late"]) else 0.0
		drift_plan = rng.randf() < float(cfg["drift"]) and spd > float(P["drift_min"])
	corner_seen = maxf(0.0, corner_seen - dt)
	late_t = maxf(0.0, late_t - dt)
	if spd > tgt_speed + 2.0 and late_t <= 0.0 and not r.boosting():
		inp.throttle = 0.0
		inp.brake = 0.7
	elif spd > tgt_speed:
		inp.throttle = 0.35
	else:
		inp.throttle = 1.0
	# занос в повороте и выход с ускорением
	if drift_plan and turn > 0.35 and absf(steer) > 0.25 and spd > float(P["drift_min"]):
		inp.drift = true
	elif r.drifting and r.drift_lvl >= 1 and turn < 0.3:
		inp.drift = false
		drift_plan = false
	elif r.drifting:
		inp.drift = turn > 0.25
	# турбо на прямой
	if r.turbo > 55.0 and turn < 0.18 and rng.randf() < float(cfg["turbo"]) * dt * 3.0:
		turbo_hold = true
	if turbo_hold and (turn > 0.35 or r.turbo < 8.0):
		turbo_hold = false
	inp.boost = turbo_hold
	# застрял: сдать назад и вывернуть
	if back_t > 0.0:
		back_t -= dt
		inp.throttle = 0.0
		inp.brake = 1.0
		steer = -steer
	elif race.go and absf(spd) < 0.8 and race.t > 2.0 and r.spin_t <= 0.0:
		late_t = 0.0
		if rng.randf() < dt * 1.2:
			back_t = 0.9
	inp.steer = steer
	# предметы
	if r.item != "":
		hold_t += dt
		inp.item = _want_item(r.item)
	else:
		hold_t = 0.0
	return inp.sanitize()

func _want_item(id: String) -> bool:
	var smart := rng.randf() < float(cfg["items"])
	if hold_t < 0.6:
		return false
	match id:
		"turbo_balloon":
			return track.turn_ahead(r.s, 25.0) < 0.25 or hold_t > 6.0
		"filter":
			return hold_t > (1.0 if smart else 3.0)
		"dust_bomb", "soap":
			return (smart and race.rider_behind(r, 20.0) != null) or hold_t > 7.0
		"super_suck":
			return race.find_target(r, float(RaceData.ITEMS["super_suck"]["range"]), float(RaceData.ITEMS["super_suck"]["cone"])) != null or hold_t > 9.0
		"air_blast":
			return race.find_target(r, float(RaceData.ITEMS["air_blast"]["range"]), float(RaceData.ITEMS["air_blast"]["cone"])) != null or hold_t > 9.0
	return hold_t > 5.0
