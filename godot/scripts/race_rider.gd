## Участник гонки: персонаж игры на ТЯГЕ-812. Один класс на всех — кем он управляется, решает не он:
##   kind "local"  — ввод игрока (RaceInput.from_actions) — race.gd;
##   kind "bot"    — ИИ (race_ai.gd);
##   kind "remote" — на хосте: ввод, присланный клиентом по сети; на клиенте — «кукла» (puppet), которая только
##                   показывает присланные хостом снимки (физику не считает).
## Физика одна — simulate(RaceInput, dt): разгон, тормоз, руль, занос с тремя уровнями заряда и ускорением на
## выходе, турбо с зарядом, прыжок и толчок с трамплина, приземление, удар о стену с отскоком, разворот на мыле,
## замедления от предметов. Числа — RaceData.PHYS. Обычная ТЯГА-812 кампании (tyaga.gd) здесь не используется и
## не меняется: общие у них модель, позы езды (TyagaClips) и звук мотора.
class_name RaceRider
extends CharacterBody3D

var race                       # race.gd
var rider_id := "pahan"        # кто (RaceVisual.RIDERS)
var title := "ПАХАН"
var slot := 0
var kind := "bot"              # local / bot / remote
var peer := 1                  # сетевой id владельца (1 — хост)
var puppet := false            # клиент: только показывает снимки хоста
var ai                         # RaceAI у бота
var net_input := RaceInput.new()   # хост: последний ввод удалённого игрока
var vis: RaceVisual
var pivot: Node3D              # наклоны и разворот поверх тела (видимые)
var smooth: Node3D             # сглаживание между шагами физики (top_level)
var prev_xf := Transform3D()
var cur_xf := Transform3D()
# ---- физика ----
var heading := 0.0
var vdir := Vector3.FORWARD
var speed := 0.0
var yaw_rate := 0.0
var drive_accel := 0.0
var drift_blend := 0.0
var drift_offset := 0.0
var drifting := false
var drift_dir := 0.0
var drift_t := 0.0
var drift_lvl := 0
var drift_air := 0.0
var boost_t := 0.0             # общее ускорение от заноса, площадок и других бонусов
var drift_boost_t := 0.0
var drift_boost_level := 0
var pad_boost_t := 0.0
var pad_boost_dir := Vector3.ZERO
var item_boost_t := 0.0        # ускорение от ТУРБО-БАЛЛОНА
var turbo := 30.0              # заряд турбо
var turbo_on := false
var spin_t := 0.0              # разворот на мыле
var spin_dir := 1.0
var slows := {}                # источник → [множитель, сколько ещё]
var side_v := Vector3.ZERO     # толчок вбок (выброс воздуха, столкновение)
var pull_v := Vector3.ZERO     # притяжение (супер-всасывание) — задаёт гонка
var shield_t := 0.0
var air_t := 0.0
var pop_v := 0.0               # толчок снизу на следующем шаге физики (пар теплотрассы), м/с
var was_floor := true
var wall_cd := 0.0            # пауза между эффектами удара
var wall_drift_cd := 0.0
var wall_push := Vector3.ZERO
var wall_yaw := 0.0
var wall_drive_t := 0.0
var hop_hold_elapsed := -1.0
var double_hop_used := false
var double_hop_cd := 0.0
var pushing_drive := false
var stuck_t := 0.0
var wrong_t := 0.0
var pace := 1.0                # множитель предела скорости (догоняющий механизм ботов)
var rev_t := 0.0               # сколько держит тормоз стоя (задний ход — не сразу)
var draft := 0.0               # 0..1: воздушный мешок за соперником (считает гонка)
var draft_t := 0.0
var overclock_t := 0.0         # РАЗГОН МОТОРА
var ramp_air := false          # в воздухе после трамплина или пара — можно крутить трюк
var trick_t := 0.0             # идёт трюк
var trick_n := 0               # сколько трюков за этот прыжок
var trick_dir := 1.0
var trick_spin := 0.0          # видимый оборот (рад)
var combo := 0                 # множитель комбо: трюки и заносы подряд
var combo_t := 0.0
var score := 0                 # очки стиля за гонку (трюки, заносы, мешок)
# ---- вид предметов ----
var item_shown := ""           # какой предмет сейчас висит над гонщиком
var item_node: Node3D
var aura_shield: Node3D        # три шестигранника фильтра вокруг гонщика
var aura_oc: Node3D            # кольца РАЗГОНА МОТОРА
var flame: Node3D              # пламя сзади при ускорении
var steer_vis := 0.0
var brake_vis := false
var lean := 0.0
# ---- гонка ----
var item := ""                 # что в руках
var item_cd := 0.0
var lap := 0                   # сколько кругов пройдено
var next_gate := 1             # какую контрольную точку ждём (0 — финиш)
var last_gate := 0
var s := 0.0                   # путь по трассе (главной дороге)
var prev_s := 0.0
var lat := 0.0
var half := 6.0
var on_short := false
var proj := {}
var dist := 0.0                # пройдено с начала гонки (для мест)
var rank := 1
var finished := false
var finish_t := 0.0
var lap_t0 := 0.0
var lap_times: Array = []
var best_lap := 0.0
var events: Array = []         # что было: [вид, значение] — для проверок и HUD
var disconnected := false
var snaps: Array = []          # клиент: снимки хоста [время хоста, положение, нос] — для кукол
var net_err := Vector3.ZERO    # клиент: поправка от хоста, которую ещё доводим (мягко)
var net_jump_count := 0
var net_jump_pending := 0
var net_seq := 0               # хост: номер последнего учтённого ввода этого гонщика
var vis_off := Vector3.ZERO    # клиент: видимый сдвиг после поправки хоста — гаснет, чтобы не было рывка
# ---- звук ----
var engine: AudioStreamPlayer3D

func setup(r, who: String, k: int, how: String, shadows := true) -> void:
	race = r
	rider_id = who
	title = RaceVisual.rider_name(who)
	slot = k
	kind = how
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(40.0)
	safe_margin = 0.04
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = float(RaceData.PHYS["radius"])
	cs.shape = sh
	cs.position = Vector3(0, float(RaceData.PHYS["radius"]), 0)
	add_child(cs)
	smooth = Node3D.new()
	smooth.top_level = true
	add_child(smooth)
	pivot = Node3D.new()
	smooth.add_child(pivot)
	vis = RaceVisual.new()
	pivot.add_child(vis)
	vis.setup(who, shadows)
	engine = AudioStreamPlayer3D.new()
	engine.stream = Tyaga._synth_hum()
	engine.bus = "SFX"
	engine.unit_size = 6.0
	engine.max_db = -4.0
	engine.volume_db = -14.0 if how == "local" else -20.0
	smooth.add_child(engine)

## Даже пологий трамплин на спуске определяется по разметке трассы.
func _ramp_here() -> bool:
	return race != null and race.track != null and proj.has("s") and not proj.get("short", false) and race.track.ramp_near(float(proj["s"]))

func place(xf: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xf.origin)
	heading = atan2(xf.basis.z.x, xf.basis.z.z)
	vdir = Vector3(sin(heading), 0, cos(heading))
	speed = 0.0
	yaw_rate = 0.0
	drive_accel = 0.0
	drift_blend = 0.0
	drift_offset = 0.0
	velocity = Vector3.ZERO
	side_v = Vector3.ZERO
	pad_boost_t = 0.0
	drifting = false
	spin_t = 0.0
	ramp_air = false
	trick_t = 0.0
	trick_n = 0
	air_t = 0.0
	was_floor = true
	wall_cd = 0.0
	wall_drift_cd = 0.0
	wall_push = Vector3.ZERO
	wall_yaw = 0.0
	wall_drive_t = 0.0
	hop_hold_elapsed = -1.0
	double_hop_used = false
	pushing_drive = false
	stuck_t = 0.0
	rev_t = 0.0
	prev_xf = _vis_xf()
	cur_xf = prev_xf
	smooth.global_transform = cur_xf

func fwd() -> Vector3:
	return Vector3(sin(heading), 0, cos(heading))

func ev(k: String, v = 0) -> void:
	events.append([k, v])
	if events.size() > 200:
		events = events.slice(-120)
	if race != null:
		race.on_rider_event(self, k, v)

func slow_mul() -> float:
	var m := 1.0
	for k in slows:
		m = minf(m, float(slows[k][0]))
	return m

func add_slow(src: String, mul: float, t: float) -> void:
	slows[src] = [mul, t]

func boosting() -> bool:
	return boost_t > 0.0 or item_boost_t > 0.0 or turbo_on

## трюк или занос удался: комбо растёт, пока между ними не больше combo_t секунд
func combo_add(points: int) -> float:
	var P := RaceData.PHYS
	combo = mini(combo + 1, int(P["combo_max"]))
	combo_t = float(P["combo_t"])
	var mul := 1.0 + 0.25 * float(combo - 1)
	score += int(float(points) * mul)
	ev("combo", combo)
	return mul

func gain_turbo(n: float) -> void:
	turbo = minf(float(RaceData.PHYS["turbo_max"]), turbo + n)

func drift_level() -> int:
	return drift_lvl

static func steer_rate_at(spd: float) -> float:
	var P := RaceData.PHYS
	var magnitude := absf(spd)
	var mix := smoothstep(0.0, float(P["vmax"]), magnitude)
	return lerpf(float(P["steer_low"]), float(P["steer"]), mix) * minf(1.0, magnitude / float(P["steer_full_speed"]))

func _drift_max_rate() -> float:
	var P := RaceData.PHYS
	return minf(float(P["steer_drift"]), float(P["drift_lateral_accel"]) / maxf(1.0, speed))

## Какой руль нужен боту для этой угловой скорости дуги (рад/с, + вправо).
func steer_for_rate(rate_right: float) -> float:
	var into := inverse_lerp(float(RaceData.PHYS["drift_turn_min"]), _drift_max_rate(), rate_right * drift_dir)
	return (clampf(into, 0.0, 1.0) * 2.0 - 1.0) * drift_dir

func _drive(inp: RaceInput, dt: float, limit: float, base_limit: float, engine_mul: float, brake_mul: float, road_grip: float, boost_accel: float) -> Vector3:
	var P := RaceData.PHYS
	var throttle := inp.throttle
	var goal := 0.0
	var effort := float(P["coast"])
	var bonus := 0.0
	var pad_effort := 0.0
	var grip := road_grip * lerpf(1.0, float(P["drift_long_grip"]), drift_blend)
	if inp.brake > 0.05:
		# Задний ход включается после полной остановки и паузы.
		rev_t = 0.0 if speed > 0.05 else rev_t + dt
		effort = float(P["brake"]) * inp.brake * brake_mul * grip
		if rev_t >= float(P["rev_delay"]) or speed < -0.5:
			goal = -float(P["rev_max"])
			effort = float(P["rev_accel"]) * grip
	else:
		rev_t = 0.0
		if (boost_t > 0.0 or item_boost_t > 0.0) and speed > -0.5:
			throttle = 1.0
		if throttle > 0.05:
			goal = limit * throttle
			effort = float(P["over_drag"])
			if speed < goal:
				var k := pow(clampf(speed / maxf(1.0, base_limit), 0.0, 1.0), float(P["accel_curve"]))
				effort = lerpf(float(P["accel_low"]), float(P["accel"]), k) * engine_mul * throttle
				bonus = boost_accel * throttle
				if pad_boost_t > 0.0 and bonus > 0.0:
					pad_effort = effort + bonus
				var drive_recovery := _wall_drive_scale()
				effort *= grip * drive_recovery
				bonus *= drive_recovery
	var direction := signf(goal - speed)
	drive_accel = lerpf(drive_accel, direction * effort, 1.0 - exp(-float(P["drive_response"]) * dt))
	if pad_effort > 0.0:
		# Площадка сохраняет прежнюю силу и толкает по своей трёхмерной касательной.
		var horizontal := Vector2(pad_boost_dir.x, pad_boost_dir.z).length()
		return pad_boost_dir * (minf(goal - speed, pad_effort * dt) / horizontal)
	speed = move_toward(speed, goal, maxf(0.0, drive_accel * direction + bonus) * dt)
	return Vector3.ZERO

func _steer(inp: RaceInput, dt: float, grounded: bool, surface_grip: float, charge_mul: float) -> void:
	var P := RaceData.PHYS
	var road_rate := inp.steer * steer_rate_at(speed)
	var drift_turn := road_rate
	var slip_target := 0.0
	if not drifting and inp.drift and grounded and wall_drift_cd <= 0.0 and speed >= float(P["drift_min"]) and absf(inp.steer) > 0.3:
		drifting = true
		drift_dir = signf(inp.steer)
		drift_t = 0.0
		drift_lvl = 0
		drift_air = 0.0
		ev("drift_start", int(drift_dir))
	if drifting:
		drift_air = 0.0 if grounded else drift_air + dt
		if not inp.drift or speed < float(P["drift_min"]) * 0.7 or drift_air > 0.35:
			_end_drift(inp.drift)
		else:
			var into := (clampf(inp.steer * drift_dir, -1.0, 1.0) + 1.0) * 0.5
			var drift_rate := lerpf(float(P["drift_turn_min"]), _drift_max_rate(), into)
			drift_turn = drift_dir * drift_rate
			slip_target = drift_dir * lerpf(float(P["drift_slip_min"]), float(P["drift_slip"]), into)
			if grounded:
				# Накопление заряда зависит от дуги, встречный руль распускает её.
				drift_t += dt * clampf(0.35 + drift_rate / 0.9, 0.0, 1.4) * charge_mul
				while drift_lvl < P["drift_levels"].size() and drift_t >= float(P["drift_levels"][drift_lvl]):
					drift_lvl += 1
					ev("drift_lvl", drift_lvl)
	var response := float(P["drift_response"] if drifting else P["drift_recovery"])
	var settle := 1.0 - exp(-response * dt)
	drift_blend = lerpf(drift_blend, 1.0 if drifting else 0.0, settle)
	drift_offset = lerpf(drift_offset, slip_target, settle)
	var traction := _wall_drive_scale()
	var rate := lerpf(road_rate, drift_turn, drift_blend) * lerpf(float(P["wall_steer_min"]), 1.0, traction)
	if not grounded:
		rate *= float(P["air_steer"])
	var target_yaw := -rate if speed >= 0.0 else rate
	var steer_response := float(P["steer_response"])
	var drift_yaw_response := float(P["drift_yaw_response"])
	var yaw_response := drift_yaw_response if drifting else lerpf(steer_response, drift_yaw_response, drift_blend)
	yaw_rate = lerpf(yaw_rate, target_yaw, 1.0 - exp(-yaw_response * dt))
	var turn := yaw_rate * dt
	if not grounded:
		heading = wrapf(heading + turn, -PI, PI)
		return

	# Корпус поворачивается раньше вектора движения, сцепление ограничивает боковое ускорение.
	var travel_yaw := atan2(vdir.x, vdir.z)
	var slip := angle_difference(travel_yaw, heading)
	var limit := lerpf(float(P["slip_limit"]), float(P["drift_slip_limit"]), drift_blend)
	turn = clampf(turn, minf(0.0, -limit - slip), maxf(0.0, limit - slip))
	heading = wrapf(heading + turn, -PI, PI)
	var speed_mix := clampf(absf(speed) / float(P["vmax"]), 0.0, 1.0)
	var grip := lerpf(lerpf(float(P["grip_low"]), float(P["grip"]), speed_mix), float(P["grip_drift"]), drift_blend) * surface_grip
	var lateral_accel := lerpf(float(P["lateral_accel"]), float(P["drift_lateral_accel"]), drift_blend)
	# Сразу после удара шины постепенно забирают скольжение под контроль.
	grip *= traction
	var max_step := lateral_accel * traction * sqrt(surface_grip) / maxf(1.0, absf(speed)) * dt
	# Частичное упреждение сглаживает дугу. Скорость смещения всё ещё ограничивает сцепление.
	var drift_lead := turn * drift_blend * float(P["drift_yaw_follow"]) / (dt * float(P["grip_drift"]))
	var aim := heading + drift_offset + drift_lead
	var step := angle_difference(travel_yaw, aim) * (1.0 - exp(-grip * dt))
	vdir = vdir.rotated(Vector3.UP, clampf(step, -max_step, max_step)).normalized()

# ---------------- шаг физики ----------------
func simulate(inp: RaceInput, dt: float, go: bool) -> void:
	var P := RaceData.PHYS
	var fl := is_on_floor()
	if not go or finished and kind == "remote":
		inp = RaceInput.new()
	wall_cd = maxf(0.0, wall_cd - dt)
	wall_drift_cd = maxf(0.0, wall_drift_cd - dt)
	wall_drive_t = maxf(0.0, wall_drive_t - dt)
	wall_push = (wall_push * exp(-float(P["wall_recoil_decay"]) * dt)).move_toward(Vector3.ZERO, float(P["wall_recoil_drag"]) * dt)
	wall_yaw *= exp(-float(P["wall_yaw_decay"]) * dt)
	double_hop_cd = maxf(0.0, double_hop_cd - dt)
	item_cd = maxf(0.0, item_cd - dt)
	shield_t = maxf(0.0, shield_t - dt)
	boost_t = maxf(0.0, boost_t - dt)
	drift_boost_t = maxf(0.0, drift_boost_t - dt)
	pad_boost_t = maxf(0.0, pad_boost_t - dt)
	item_boost_t = maxf(0.0, item_boost_t - dt)
	overclock_t = maxf(0.0, overclock_t - dt)
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0 and combo > 0:
			combo = 0
			ev("combo", 0)
	for k in slows.keys():
		slows[k][1] = float(slows[k][1]) - dt
		if float(slows[k][1]) <= 0.0:
			slows.erase(k)
	# разворот на мыле: управления нет, нос крутится, скорость падает
	var spinning := spin_t > 0.0
	if spinning:
		spin_t -= dt
		heading += spin_dir * 9.0 * dt
		speed = move_toward(speed, 0.0, 16.0 * dt)
		inp = RaceInput.new()
		yaw_rate = 0.0
		drift_blend = 0.0
		drift_offset = 0.0
		drifting = false
	# предел скорости
	var wx = race.weather if race != null else null          # погода (race_weather.gd)
	var vlim: float = float(P["vmax"]) * pace * slow_mul()
	if wx != null and wx.wind != Vector3.ZERO:
		vlim += (wx.wind as Vector3).dot(fwd()) * 0.25            # по ветру быстрее, против — медленнее
	var off_road := absf(lat) > half + 0.2
	if off_road:
		vlim *= float(P["shoulder_slow"])
	vlim *= lerpf(1.0, float(P["drift_slow"]), drift_blend)
	if overclock_t > 0.0:
		vlim += float(RaceData.ITEMS["overclock"]["add"])
	vlim += float(P["draft_add"]) * draft                      # воздушный мешок за соперником
	# турбо: только с газом — оно усиливает тягу и поднимает предел, а не «ставит» скорость.
	# Держишь — расходуется; копится понемногу само, в воздухе, в мешке, заносами и трюками.
	var want_turbo: bool = inp.boost and go and not spinning and inp.brake <= 0.05 and inp.throttle > 0.05 and speed > -0.5
	turbo_on = want_turbo and (turbo > (0.5 if turbo_on else float(P["turbo_min"])))
	if turbo_on:
		turbo = maxf(0.0, turbo - float(P["turbo_use"]) * dt)
		if turbo <= 0.0:
			turbo_on = false
	elif go:
		var regen: float = float(P["turbo_regen"]) + (float(P["turbo_air"]) if not fl else 0.0) + float(P["draft_turbo"]) * draft
		if overclock_t > 0.0:
			regen *= float(RaceData.ITEMS["overclock"]["regen"])
		gain_turbo(regen * dt)
	var base_lim := vlim                                       # предел без ускорений — по нему считается кривая тяги
	var add := 0.0
	var boost_accel := 0.0
	if boost_t > 0.0 or turbo_on:
		add = float(P["boost_add"])
		boost_accel = float(P["boost_accel"])
		# Сила других ускорителей сохраняет приоритет при пересечении бонусов.
		if drift_boost_t > 0.0 and pad_boost_t <= 0.0 and not turbo_on and item_boost_t <= 0.0:
			add = float(P["drift_boost_add"][drift_boost_level - 1])
			boost_accel = float(P["drift_boost_accel"][drift_boost_level - 1])
	if item_boost_t > 0.0:
		add = maxf(add, float(P["item_add"]))
		boost_accel = float(P["item_accel"])
	vlim += add
	var road_grip := float(P["shoulder_grip"]) if off_road else 1.0
	var engine_mul: float = wx.mod("accel") if wx != null else 1.0
	if overclock_t > 0.0:
		engine_mul *= float(RaceData.ITEMS["overclock"]["acc"])
	pushing_drive = inp.throttle > 0.1 or inp.brake > 0.1
	var pad_push := _drive(inp, dt, vlim, base_lim, engine_mul, wx.mod("brake") if wx != null else 1.0, road_grip, boost_accel)
	brake_vis = inp.brake > 0.05 and speed > 2.0
	steer_vis = lerpf(steer_vis, inp.steer, 1.0 - exp(-8.0 * dt))
	if not spinning:
		var grip: float = wx.mod("grip") if wx != null else 1.0
		_steer(inp, dt, fl, grip * road_grip, wx.mod("charge") if wx != null else 1.0)
		heading = wrapf(heading + wall_yaw * dt, -PI, PI)
	if pad_push != Vector3.ZERO:
		var motion := vdir * speed + Vector3(pad_push.x, 0, pad_push.z)
		var reversing := speed < 0.0 and motion.dot(vdir) < 0.0
		speed = -motion.length() if reversing else motion.length()
		if not is_zero_approx(speed):
			vdir = motion / speed
	side_v = side_v.move_toward(Vector3.ZERO, 9.0 * dt)
	# Изменение тяги ограничено в _drive. Вся учтённая скорость колёс попадает в движение.
	var hv := vdir * speed + side_v + pull_v + wall_push
	if wx != null and wx.wind != Vector3.ZERO and fl and go:          # до старта ветер не двигает
		var side := fwd().cross(Vector3.UP)
		hv += side * (wx.wind as Vector3).dot(side) * 0.22          # порыв сбоку сносит
	if trick_t > 0.0:
		trick_t = maxf(0.0, trick_t - dt)
	# прыжок, склон, полёт
	if fl:
		if pop_v > 0.0:
			velocity = Vector3(hv.x, pop_v, hv.z)      # подбросило снизу (пар теплотрассы)
			pop_v = 0.0
			ramp_air = true
		elif inp.jump and go and spin_t <= 0.0:
			velocity = Vector3(hv.x, float(P["hop"]), hv.z)
			ramp_air = get_floor_normal().y < 0.9999 and _ramp_here()
			hop_hold_elapsed = 0.0 if inp.jump_held else -1.0
			ev("jump", 0)
		else:
			var n := get_floor_normal()
			var vy := -(n.x * hv.x + n.z * hv.z) / maxf(0.3, n.y)
			velocity = Vector3(hv.x, vy, hv.z)
	else:
		velocity = Vector3(hv.x, _air_vertical(inp, dt, go and not spinning) + pad_push.y, hv.z)
	var vy_before := velocity.y
	var from := global_position
	move_and_slide()
	var floor_now := is_on_floor()
	# слетел с трамплина: толчок вверх — прыжок выше и веселее
	if was_floor and not floor_now and not inp.jump and not ramp_air and vy_before > 0.5 and _ramp_here():
		velocity.y += 3.2
		hop_hold_elapsed = -1.0
		ramp_air = true
		ev("ramp", 0)
	_resolve_wall_contacts(Vector3(hv.x, 0.0, hv.z), from)
	# приземление
	if floor_now:
		if not was_floor and air_t > 0.22:
			speed *= float(P["land_keep"])
			@warning_ignore("narrowing_conversion")
			ev("land", air_t)
			vis.squash = clampf(air_t * 1.6, 0.4, 1.4)
		if trick_n > 0:
			if trick_t > 0.1:
				speed *= float(P["trick_fail"])          # не докрутил — шлёпнулся
				combo = 0
				combo_t = 0.0
				ev("trick_fail", trick_n)
			else:
				var mul := combo_add(100 * trick_n)
				boost_t = maxf(boost_t, float(P["trick_boost"]) * float(mini(trick_n, 3)))
				gain_turbo(float(P["trick_turbo"]) * float(trick_n) * mul)
				ev("trick_land", trick_n)
			trick_n = 0
			trick_t = 0.0
		ramp_air = false
		hop_hold_elapsed = -1.0
		double_hop_used = false
		air_t = 0.0
	else:
		air_t += dt
	was_floor = floor_now
	_after_step()

func _air_vertical(inp: RaceInput, dt: float, can_jump: bool) -> float:
	var P := RaceData.PHYS
	var vy := velocity.y - float(P["gravity"]) * dt
	if can_jump and inp.jump:
		# Один воздушный ввод может запустить и трюк, и толчок. Боты запрашивают только трюк.
		if ramp_air and trick_t <= 0.0:
			trick_t = float(P["trick_t"])
			trick_n += 1
			trick_dir = signf(inp.steer) if absf(inp.steer) > 0.3 else (1.0 if trick_n % 2 == 1 else -1.0)
			ev("trick", trick_n)
		if kind != "bot" and not double_hop_used and double_hop_cd <= 0.0:
			double_hop_used = true
			double_hop_cd = float(P["double_hop_cooldown"])
			hop_hold_elapsed = -1.0
			ev("double_jump", 0)
			var hop := float(P["hop"])
			var impulse := hop * float(P["double_hop_ratio"])
			return maxf(vy, 0.0) + impulse
	if hop_hold_elapsed < 0.0:
		return vy
	if not can_jump or not inp.jump_held or vy <= 0.0 or is_on_ceiling():
		hop_hold_elapsed = -1.0
		return vy
	var delay := float(P["hop_hold_delay"])
	var duration := float(P["hop_hold_time"])
	var previous_lift := clampf(hop_hold_elapsed - delay, 0.0, duration)
	hop_hold_elapsed += dt
	var lift := clampf(hop_hold_elapsed - delay, 0.0, duration)
	if previous_lift <= 0.0 and lift > 0.0:
		ev("jump_lift", 0)
	if lift >= duration:
		hop_hold_elapsed = -1.0
	return vy + (lift - previous_lift) * float(P["hop_hold_accel"])

func _wall_drive_scale() -> float:
	var P := RaceData.PHYS
	var recovery := clampf(wall_drive_t / float(P["wall_drive_recover"]), 0.0, 1.0)
	return lerpf(float(P["wall_drive_min"]), 1.0, (1.0 - recovery) * (1.0 - recovery))

func _resolve_wall_contacts(incoming: Vector3, from: Vector3) -> void:
	if not is_on_wall():
		return
	var P := RaceData.PHYS
	var floor_dot := cos(floor_max_angle + 0.01)
	var contact_normals := PackedVector3Array()
	var motion := incoming
	var drive := vdir * speed
	var impact := 0.0
	var spin_impulse := 0.0
	var center := from + up_direction * float(P["radius"]) - fwd() * float(P["wall_com_offset"])
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		center += contact.get_travel()
		for j in contact.get_collision_count():
			var normal := contact.get_normal(j)
			# Предел уклона тот же, что у Godot для пола и потолка.
			if absf(normal.dot(up_direction)) >= floor_dot:
				continue
			normal = Vector3(normal.x, 0.0, normal.z).normalized()
			contact_normals.append(normal)
			var closing := -motion.dot(normal)
			if closing <= 0.0:
				continue
			var alignment := clampf(closing / motion.length(), 0.0, 1.0)
			var strength := clampf(closing / float(P["wall_full_impact_speed"]), 0.0, 1.0)
			var keep := clampf(1.0 - float(P["wall_friction"]) * alignment * strength, 0.0, 1.0)
			var rebound := rebound_speed(closing, alignment)
			var after := motion.slide(normal) * keep + normal * rebound
			var arm := contact.get_position(j) - center
			arm.y = 0.0
			spin_impulse += arm.limit_length(float(P["radius"])).cross(after - motion).y
			motion = after
			# Отскок хранится отдельно от тяги. Газ не поглощает этот импульс.
			drive = drive.slide(normal) * keep
			side_v = side_v.slide(normal) * keep
			wall_push = wall_push.slide(normal) * keep + normal * rebound
			impact = maxf(impact, closing)
	if impact <= 0.0:
		return

	# На стыке блоков оставляем возможную касательную к обеим граням.
	if contact_normals.size() > 1:
		motion = _clip_to_contacts(motion, contact_normals)
		drive = _clip_to_contacts(drive, contact_normals)
		side_v = _clip_to_contacts(side_v, contact_normals)
		wall_push = _clip_to_contacts(wall_push, contact_normals)
	velocity = Vector3(motion.x, velocity.y, motion.z)
	_set_contact_drive(drive)
	_absorb_impact(impact, spin_impulse)
	if wall_cd <= 0.0 and impact >= float(P["wall_feedback_min_speed"]):
		wall_cd = 0.25
		ev("wall", clampf(impact / float(P["wall_full_impact_speed"]), 0.0, 1.0))

static func rebound_speed(closing: float, alignment: float) -> float:
	var p := RaceData.PHYS
	var solid := smoothstep(float(p.wall_rebound_min_speed), float(p.wall_rebound_full), closing)
	var grazing := float(p.wall_rebound_alignment)
	# Мягкое насыщение сохраняет разницу между ударами на гоночной скорости.
	var cap := float(p.wall_rebound_max_speed)
	var speed_out := cap * (1.0 - exp(-closing * float(p.wall_restitution) / cap))
	return speed_out * solid * smoothstep(grazing, grazing * 2.0, alignment)

static func _clears_contacts(v: Vector3, normals: PackedVector3Array) -> bool:
	for normal in normals:
		if v.dot(normal) < -0.001:
			return false
	return true

static func _clip_to_contacts(v: Vector3, normals: PackedVector3Array) -> Vector3:
	if _clears_contacts(v, normals):
		return v
	# Ближайший допустимый вектор в плоскости дороги лежит на одной из касательных
	# либо равен нулю, когда обе грани блокируют движение.
	var best := Vector3.ZERO
	for normal in normals:
		var tangent := v.slide(normal)
		if tangent.length_squared() > best.length_squared() and _clears_contacts(tangent, normals):
			best = tangent
	return best

func _set_contact_drive(drive: Vector3) -> void:
	drive.y = 0.0
	var along_travel := drive.dot(vdir)
	var backing := along_travel < 0.0 if not is_zero_approx(along_travel) else speed < 0.0
	speed = drive.length() * (-1.0 if backing else 1.0)
	vdir = fwd() if is_zero_approx(speed) else drive / speed

func _absorb_impact(impact: float, spin_impulse: float) -> void:
	var P := RaceData.PHYS
	var yaw_limit := float(P["wall_yaw_max"])
	wall_yaw = clampf(wall_yaw + spin_impulse * float(P["wall_yaw_gain"]), -yaw_limit, yaw_limit)
	var drive_cut := smoothstep(float(P["wall_rebound_min_speed"]), float(P["wall_control_full"]), impact)
	var recovery := drive_cut * float(P["wall_drive_recover"])
	if recovery > wall_drive_t:
		wall_drive_t = recovery
		drive_accel *= _wall_drive_scale()
	if drifting and impact >= float(P["wall_drift_break_speed"]):
		wall_drift_cd = float(P["wall_drift_recover"])
		_end_drift(true, false)

## Два гонщика равной массы разделяют нормальную скорость. Остаток отскока
## живёт в том же канале, что и удар о стену, и входит в снимок хоста.
func rider_contact(normal: Vector3, incoming: Vector3, after: Vector3, rebound: float, closing: float, point: Vector3) -> void:
	var center := global_position - fwd() * float(RaceData.PHYS.wall_com_offset)
	var arm := point - center
	arm.y = 0.0
	side_v = side_v.slide(normal)
	wall_push = wall_push.slide(normal) + normal * rebound
	_set_contact_drive(after - wall_push - side_v - pull_v)
	velocity.x = after.x
	velocity.z = after.z
	_absorb_impact(closing, arm.cross(after - incoming).y)

func _end_drift(still_held: bool, reward := true) -> void:
	var P := RaceData.PHYS
	if reward and drift_lvl > 0:
		var mul := combo_add(40 * drift_lvl)
		var duration := float(P["drift_boost"][drift_lvl - 1])
		boost_t = maxf(boost_t, duration)
		if duration >= drift_boost_t:
			drift_boost_t = duration
			drift_boost_level = drift_lvl
		gain_turbo(float(P["drift_turbo"][drift_lvl - 1]) * mul)
		ev("drift_boost", drift_lvl)
	drifting = false
	drift_lvl = 0
	drift_t = 0.0
	if still_held:
		ev("drift_cut", 0)

## разворот (мыльная лужа): щит его съедает
func spin_out(t: float, src: String) -> bool:
	if shield_t > 0.0:
		shield_t = 0.0
		ev("blocked", src)
		return false
	spin_t = t
	spin_dir = -1.0 if randf() < 0.5 else 1.0
	if drifting:
		_end_drift(false)
	ev("spin", src)
	return true

## воздействие предмета соперника: щит его съедает
func hit_by(src: String) -> bool:
	if shield_t > 0.0:
		shield_t = 0.0
		ev("blocked", src)
		return false
	return true

# ---------------- вид ----------------
## Предмет в руках виден всем: его модель висит над гонщиком и крутится (соперники тоже — видно, чего ждать).
## Фильтр — три шестигранника по кругу, РАЗГОН МОТОРА — светящиеся кольца, ускорение — пламя за пылесосом.
func _item_vis(dt: float) -> void:
	if item != item_shown:
		item_shown = item
		if item_node != null and is_instance_valid(item_node):
			item_node.queue_free()
		item_node = null
		if item != "":
			item_node = RaceItems.model(item, 0.62)
			item_node.position = Vector3(0, 2.25, -0.35)
			smooth.add_child(item_node)
			item_node.scale = Vector3.ONE * 1.5
			item_node.create_tween().tween_property(item_node, "scale", Vector3.ONE * 0.62, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if item_node != null and is_instance_valid(item_node):
		item_node.rotation.y += dt * 2.4
		item_node.position.y = 2.25 + sin(Time.get_ticks_msec() * 0.004 + float(slot)) * 0.07
	if shield_t > 0.0:
		if aura_shield == null:
			aura_shield = Node3D.new()
			aura_shield.position = Vector3(0, 0.9, 0)
			smooth.add_child(aura_shield)
			for k in 3:
				var h := RaceItems.model("filter", 0.75)
				var a := TAU * k / 3.0
				h.position = Vector3(sin(a) * 1.15, 0, cos(a) * 1.15)
				h.rotation.y = a
				aura_shield.add_child(h)
		@warning_ignore("integer_division")
		aura_shield.visible = shield_t > 1.5 or int(Time.get_ticks_msec() / 120) % 2 == 0      # под конец мигает
		aura_shield.rotation.y += dt * 2.2
	elif aura_shield != null:
		aura_shield.visible = false
	if overclock_t > 0.0:
		if aura_oc == null:
			aura_oc = Node3D.new()
			aura_oc.position = Vector3(0, 0.45, -0.2)
			smooth.add_child(aura_oc)
			for k in 2:
				RaceItems.ring(aura_oc, 0.75 + 0.2 * k, 0.03, RaceItems.mat("oc_bolt", Color(0.3, 0.85, 1.0), 0.3, 0.0, 1.6), Vector3(0, 0.25 * k, 0))
		aura_oc.visible = true
		aura_oc.rotation.y -= dt * 6.0
		aura_oc.scale = Vector3.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.02))
	elif aura_oc != null:
		aura_oc.visible = false
	if boosting():
		if flame == null:
			flame = Node3D.new()
			flame.position = Vector3(0, 0.42, -1.0)
			pivot.add_child(flame)
			RaceItems.cyl(flame, 0.2, 0.0, 0.8, RaceItems.mat("tb_fire", Color(1.0, 0.55, 0.1), 0.3, 0.0, 2.6, 0.9), Vector3(0, 0, -0.35), Vector3(PI / 2, 0, 0))
			RaceItems.cyl(flame, 0.1, 0.0, 0.5, RaceItems.mat("tb_fire2", Color(1.0, 0.95, 0.6), 0.3, 0.0, 3.2), Vector3(0, 0, -0.22), Vector3(PI / 2, 0, 0))
		flame.visible = true
		var big := 1.5 if item_boost_t > 0.0 else 1.0
		flame.scale = Vector3(big, big, big * (0.8 + 0.4 * randf()))
	elif flame != null:
		flame.visible = false

func _vis_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, heading), global_position)

func _after_step() -> void:
	prev_xf = cur_xf
	cur_xf = _vis_xf()

## кукла (клиент): положение и состояние пришли с хоста
func set_snapshot_xf(pos: Vector3, h: float) -> void:
	prev_xf = cur_xf
	global_position = pos
	heading = h
	cur_xf = _vis_xf()

func _process(dt: float) -> void:
	if vis == null:
		return
	var f := Engine.get_physics_interpolation_fraction() if not puppet else 1.0
	var a := prev_xf
	var b := cur_xf
	var xf := Transform3D(a.basis.slerp(b.basis, f), a.origin.lerp(b.origin, f))
	if puppet:
		xf = cur_xf                               # кукла: race.gd уже сгладил по снимкам
	if vis_off.length() > 0.001:
		vis_off = vis_off * exp(-10.0 * dt)
		xf.origin += vis_off
	smooth.global_transform = xf
	# Наклон в поворот и подъём носа в воздухе.
	var turn_k := clampf(absf(speed) / 14.0, 0.0, 1.0)
	var want_lean := -steer_vis * 0.22 * turn_k
	if drifting:
		want_lean = -drift_dir * 0.32
	lean = lerpf(lean, want_lean, 1.0 - exp(-8.0 * dt))
	var air := air_t > 0.08
	# трюк: полный оборот за время трюка — нечётный трюк прыжка волчком, чётный — сальто через нос
	var trick_len := float(RaceData.PHYS["trick_t"])
	trick_spin = (1.0 - trick_t / trick_len) * TAU * trick_dir if trick_t > 0.0 else 0.0
	var flip := trick_n % 2 == 0 and trick_t > 0.0
	var spin_y := trick_t > 0.0 and not flip
	pivot.rotation = Vector3(absf(trick_spin) if flip else lerpf(pivot.rotation.x if absf(pivot.rotation.x) < 1.0 else 0.0, -0.16 if air else (0.05 if boosting() else 0.0), 1.0 - exp(-8.0 * dt)),
		trick_spin if spin_y else lerp_angle(pivot.rotation.y, 0.0, 1.0 - exp(-7.0 * dt)), lean)
	vis.power = 0.35 + 0.65 * clampf(absf(speed) / 20.0, 0.0, 1.0)
	_item_vis(dt)
	var clip := "RideSit"
	if air:
		clip = "RideJump"
	elif speed < -0.5:
		clip = "RideReverse"
	elif drifting:
		clip = "RideDrift"
	elif boosting():
		clip = "RideBoost"
	elif brake_vis:
		clip = "RideBrake"
	if clip == "RideJump":
		if vis.rig.cur != "RideJump":
			vis.rig.play_for("RideJump", 0.75, 0.06)
	else:
		vis.rig.play(clip, 0.15)
	# мотор: громче и выше на скорости и в ускорении
	if engine != null and race != null and race.sound_on:
		if not engine.playing:
			engine.play()
		var k := clampf(absf(speed) / 22.0, 0.0, 1.2)
		engine.pitch_scale = lerpf(engine.pitch_scale, 0.75 + 0.75 * k + (0.2 if boosting() else 0.0), 0.15)
		engine.volume_db = lerpf(engine.volume_db, (-16.0 if kind == "local" else -22.0) + 8.0 * k, 0.1)
	elif engine != null and engine.playing:
		engine.stop()
