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
var drifting := false
var drift_dir := 0.0
var drift_t := 0.0
var drift_lvl := 0
var drift_air := 0.0
var boost_t := 0.0             # ускорение от заноса
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
var was_floor := true
var floor_n := Vector3.UP
var wall_cd := 0.0
var stuck_t := 0.0
var wrong_t := 0.0
var pace := 1.0                # множитель предела скорости (догоняющий механизм ботов)
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

func place(xf: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xf.origin)
	heading = atan2(xf.basis.z.x, xf.basis.z.z)
	vdir = Vector3(sin(heading), 0, cos(heading))
	speed = 0.0
	velocity = Vector3.ZERO
	side_v = Vector3.ZERO
	drifting = false
	spin_t = 0.0
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

func drift_level() -> int:
	return drift_lvl

## какой руль нужен в заносе, чтобы дуга шла с этой угловой скоростью (рад/с, + — вправо): для ботов
func steer_for_rate(rate_right: float) -> float:
	var P := RaceData.PHYS
	var rate := rate_right * drift_dir                       # в сторону заноса
	var into := (rate - float(P["drift_turn_min"])) / (float(P["steer_drift"]) - float(P["drift_turn_min"])) * 2.0 - 1.0
	return clampf(into, -1.0, 1.0) * drift_dir

# ---------------- шаг физики ----------------
func simulate(inp: RaceInput, dt: float, go: bool) -> void:
	var P := RaceData.PHYS
	var floor := is_on_floor()
	if not go or finished and kind == "remote":
		inp = RaceInput.new()
	wall_cd = maxf(0.0, wall_cd - dt)
	item_cd = maxf(0.0, item_cd - dt)
	shield_t = maxf(0.0, shield_t - dt)
	boost_t = maxf(0.0, boost_t - dt)
	item_boost_t = maxf(0.0, item_boost_t - dt)
	for k in slows.keys():
		slows[k][1] = float(slows[k][1]) - dt
		if float(slows[k][1]) <= 0.0:
			slows.erase(k)
	# разворот на мыле: управления нет, нос крутится, скорость падает
	if spin_t > 0.0:
		spin_t -= dt
		heading += spin_dir * 9.0 * dt
		speed = move_toward(speed, 0.0, 16.0 * dt)
		inp = RaceInput.new()
		drifting = false
	# предел скорости
	var wx = race.weather if race != null else null          # погода (race_weather.gd)
	var vlim: float = float(P["vmax"]) * pace * slow_mul()
	if wx != null and wx.wind != Vector3.ZERO:
		vlim += (wx.wind as Vector3).dot(fwd()) * 0.25            # по ветру быстрее, против — медленнее
	if absf(lat) > half + 0.2:
		vlim *= float(P["shoulder_slow"])
	if drifting:
		vlim *= float(P["drift_slow"])
	var add := 0.0
	if boost_t > 0.0 or turbo_on:
		add = float(P["boost_add"])
	if item_boost_t > 0.0:
		add = maxf(add, float(P["item_add"]))
	vlim += add
	# турбо: держишь — расходуется, сам копится медленно, в воздухе и заносом быстрее
	var want_turbo: bool = inp.boost and go and spin_t <= 0.0
	turbo_on = want_turbo and (turbo > (0.5 if turbo_on else float(P["turbo_min"])))
	if turbo_on:
		turbo = maxf(0.0, turbo - float(P["turbo_use"]) * dt)
		if turbo <= 0.0:
			turbo_on = false
	elif go:
		turbo = minf(float(P["turbo_max"]), turbo + float(P["turbo_regen"]) * dt + (float(P["turbo_air"]) * dt if not floor else 0.0))
	# газ и тормоз
	if boosting():
		speed = move_toward(speed, vlim, 40.0 * dt)
	elif inp.throttle > 0.05 and speed > -0.5:
		var acc: float = (float(P["accel_low"]) if speed < 8.0 else float(P["accel"])) * (wx.mod("accel") if wx != null else 1.0)
		if speed > vlim * inp.throttle:
			speed = move_toward(speed, vlim * inp.throttle, 9.0 * dt)
		else:
			speed = move_toward(speed, vlim * inp.throttle, acc * inp.throttle * dt)
	elif inp.brake > 0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, float(P["brake"]) * inp.brake * dt * (wx.mod("brake") if wx != null else 1.0))
		else:
			speed = move_toward(speed, -float(P["rev_max"]), float(P["accel"]) * 0.6 * dt)
	else:
		speed = move_toward(speed, 0.0, float(P["coast"]) * dt)
	if speed > vlim + 0.1 and not boosting():
		speed = move_toward(speed, vlim, 9.0 * dt)
	brake_vis = inp.brake > 0.05 and speed > 2.0
	# занос: держишь со скоростью и рулём — несёт боком, копится заряд; отпустил — ускорение по уровню
	if not drifting and inp.drift and floor and speed >= float(P["drift_min"]) and absf(inp.steer) > 0.3 and spin_t <= 0.0:
		drifting = true
		drift_dir = signf(inp.steer)
		drift_t = 0.0
		drift_lvl = 0
		drift_air = 0.0
		ev("drift_start", drift_dir)
	if drifting:
		drift_air = drift_air + dt if not floor else 0.0
		var into := clampf(inp.steer * drift_dir, -1.0, 1.0)
		var rate: float = lerpf(float(P["drift_turn_min"]), float(P["steer_drift"]), (into + 1.0) * 0.5)
		# заряд копится, пока занос правда поворачивает: «боком по прямой» почти ничего не даёт
		drift_t += dt * clampf(0.35 + rate / 0.9, 0.0, 1.4) * (wx.mod("charge") if wx != null else 1.0)
		var lv := 0
		for t_lv in P["drift_levels"]:
			if drift_t >= float(t_lv):
				lv += 1
		if lv > drift_lvl:
			drift_lvl = lv
			ev("drift_lvl", lv)
		# занос — дуга: руль задаёт, насколько круто она идёт (от заноса — шире, в занос — круче),
		# нос держится под углом заноса внутрь поворота
		var vh := atan2(vdir.x, vdir.z) - drift_dir * rate * dt
		vdir = Vector3(sin(vh), 0, cos(vh))
		heading = lerp_angle(heading, vh - drift_dir * float(P["drift_slip"]), 1.0 - exp(-10.0 * dt))
		if not inp.drift or speed < float(P["drift_min"]) * 0.7 or drift_air > 0.35:
			_end_drift(inp.drift)
	else:
		var k_spd := clampf(absf(speed) / 12.0, 0.0, 1.0)
		var rate: float = lerpf(float(P["steer_low"]), float(P["steer"]), k_spd)
		if not floor:
			rate *= float(P["air_steer"])
		rate *= clampf(absf(speed) / 1.5, 0.0, 1.0)
		heading -= inp.steer * rate * dt * (1.0 if speed >= 0.0 else -1.0)
	steer_vis = lerpf(steer_vis, inp.steer, 1.0 - exp(-8.0 * dt))
	# куда едет на самом деле: в заносе сцепление слабое
	var hd := fwd()
	var grip: float = (float(P["grip_drift"]) if drifting else float(P["grip"])) * (wx.mod("grip") if wx != null else 1.0)
	if floor and not drifting:
		vdir = vdir.slerp(hd, 1.0 - exp(-grip * dt)).normalized()
	side_v = side_v.move_toward(Vector3.ZERO, 9.0 * dt)
	var hv := vdir * speed + side_v + pull_v
	if wx != null and wx.wind != Vector3.ZERO and floor:
		var side := fwd().cross(Vector3.UP)
		hv += side * (wx.wind as Vector3).dot(side) * 0.22          # порыв сбоку сносит
	# прыжок, склон, полёт
	if floor:
		if inp.jump and go and spin_t <= 0.0:
			velocity = Vector3(hv.x, float(P["hop"]), hv.z)
			ev("jump", 0)
		else:
			var n := get_floor_normal()
			floor_n = n
			var vy := -(n.x * hv.x + n.z * hv.z) / maxf(0.3, n.y)
			velocity = Vector3(hv.x, vy, hv.z)
	else:
		velocity = Vector3(hv.x, velocity.y - float(P["gravity"]) * dt, hv.z)
	var vy_before := velocity.y
	move_and_slide()
	var floor_now := is_on_floor()
	# слетел с трамплина: толчок вверх — прыжок выше и веселее
	if was_floor and not floor_now and floor_n.y < 0.995 and vy_before > 0.5:
		velocity.y += 3.2
		ev("ramp", 0)
	# стены и препятствия
	for c in get_slide_collision_count():
		var col := get_slide_collision(c)
		var n := col.get_normal()
		if absf(n.y) > 0.6 or wall_cd > 0.0:
			continue
		var nh := Vector3(n.x, 0, n.z).normalized()
		var d := vdir.dot(nh)
		if d < -0.12 and absf(speed) > 2.5:
			var hit := -d
			speed *= lerpf(float(P["wall_glance"]), float(P["wall_keep"]), clampf(hit * 1.3, 0.0, 1.0))
			vdir = (vdir - nh * d * 1.6).normalized()
			heading = lerp_angle(heading, atan2(vdir.x, vdir.z), 0.6)
			side_v += nh * 1.5 * hit
			wall_cd = 0.25
			if drifting:
				_end_drift(false)
			ev("wall", hit)
	# приземление
	if floor_now:
		if not was_floor and air_t > 0.22:
			speed *= float(P["land_keep"])
			ev("land", air_t)
			vis.squash = clampf(air_t * 1.6, 0.4, 1.4)
		air_t = 0.0
	else:
		air_t += dt
	was_floor = floor_now
	_after_step()

func _end_drift(still_held: bool) -> void:
	var P := RaceData.PHYS
	if drift_lvl > 0:
		boost_t = maxf(boost_t, float(P["drift_boost"][drift_lvl - 1]))
		turbo = minf(float(P["turbo_max"]), turbo + float(P["drift_turbo"][drift_lvl - 1]))
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
	# наклон в поворот, разворот кормы в заносе, нос вверх в воздухе
	var turn_k := clampf(absf(speed) / 14.0, 0.0, 1.0)
	var want_lean := -steer_vis * 0.22 * turn_k
	if drifting:
		want_lean = -drift_dir * 0.32
	lean = lerpf(lean, want_lean, 1.0 - exp(-8.0 * dt))
	var yaw_off := (drift_dir * 0.42 if drifting else 0.0)
	if spin_t > 0.0:
		yaw_off = 0.0
	var air := air_t > 0.08
	pivot.rotation = Vector3(lerpf(pivot.rotation.x, -0.16 if air else (0.05 if boosting() else 0.0), 1.0 - exp(-8.0 * dt)),
		lerp_angle(pivot.rotation.y, yaw_off, 1.0 - exp(-7.0 * dt)), lean)
	vis.power = 0.35 + 0.65 * clampf(absf(speed) / 20.0, 0.0, 1.0)
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
