## Захват цели (в духе Dark Souls 3): СКМ — взять цель / отпустить, колесо мыши — следующая / предыдущая.
## Камера не переписывается: захват только мягко ведёт cam_yaw / cam_pitch к цели (дальше всё как всегда — SpringArm,
## тряска, подброс в воздух). Камеру уступает всем, кто ею владеет: диалог, Team Overdrive, сцена гибели, облёт,
## пауза, iPod, проверки (director) — после них сам плавно возвращается к цели. Герой смотрит на цель, когда стоит,
## держит блок или бьёт (combat.target_face); на бегу — по ходу движения (своих анимаций бокового шага нет).
## Цель — живой враг (обычный или босс) в RANGE м, по прямой видимости, ближе к центру экрана; спина камеры не в счёт.
## Снимается сам: цель погибла или исчезла, ушла дальше DROP м, скрылась за стеной дольше LOST_T с.
class_name LockOn
extends Node

const RANGE := 18.0
const DROP := 24.0
const LOST_T := 1.5
const YAW_RATE := 7.0          # насколько быстро камера доворачивает к цели (1/с)
const CLOSE := 1.3             # цель вплотную: камеру не крутим (иначе разворот на 180° при обходе)

var game
var target = null
var marker: Sprite3D
var lost_t := 0.0
var shown := 0.0
var events: Array = []          # для проверок: ["on", id], ["off", почему], ["next", id], ["prev", id]

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_PAUSABLE
	marker = Sprite3D.new()
	marker.texture = _marker_tex()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0009
	marker.render_priority = 5
	marker.modulate = Color(1, 1, 1, 0)
	marker.visible = false
	g.add_child(marker)

## Маркер: белый ромб-рамка с красной точкой — не похож на метку замаха (заливка на земле), ✕ добивания и «ОТКРЫТ»
static func _marker_tex() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := n * 0.5
	for y in n:
		for x in n:
			var d: float = absf(x - c + 0.5) + absf(y - c + 0.5)      # ромб
			if d > 22.0 and d < 28.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif d > 20.5 and d < 29.5:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.06, 0.9))
			var r := Vector2(x - c + 0.5, y - c + 0.5).length()
			if r < 5.0:
				img.set_pixel(x, y, Color(0.92, 0.12, 0.14, 1))
	return ImageTexture.create_from_image(img)

func active() -> bool:
	return target != null and is_instance_valid(target)

## Можно ли сейчас трогать захват (не диалог, не меню, не постановка)
func usable() -> bool:
	return not game.paused_story() and not game.over and not game.get_tree().paused and not game.intro_busy() \
		and not (game.ipod != null and game.ipod.captures_gameplay_input())

func toggle() -> void:
	if active():
		release("toggle")
		return
	var e = pick()
	if e != null:
		lock_to(e)
		events.append(["on", e.get_instance_id()])
		game.main.sfx("sfx_ui", -12.0, 1.4)

func release(why: String) -> void:
	if target != null:
		events.append(["off", why])
	target = null
	lost_t = 0.0

func lock_to(e) -> void:
	target = e
	lost_t = 0.0

## Цель годится: живая, не появляется, не в стадии смерти
static func valid(e) -> bool:
	return e != null and is_instance_valid(e) and e.alive() and not e.is_queued_for_deletion()

func _chest(e) -> Vector3:
	return e.global_position + Vector3(0, float(e.height) * 0.62, 0)

## прямая видимость от камеры (или от героя) до груди цели: стены и предметы мешают, враги и герой — нет
func sees(e) -> bool:
	var from: Vector3 = game.player.global_position + Vector3(0, 1.4, 0)
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, _chest(e))
	var ex: Array[RID] = [game.player.get_rid()]
	for o in game.enemies:
		if is_instance_valid(o):
			ex.append(o.get_rid())
	if game.buddy != null:
		ex.append(game.buddy.get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()

## Оценка кандидатов: угол от центра экрана важнее расстояния; за спиной камеры — не берём
func pick(exclude = null):
	var cam: Camera3D = game.cam
	var fw: Vector3 = -cam.global_transform.basis.z
	fw.y = 0
	fw = fw.normalized()
	var best = null
	var bs := 1e9
	for e in game.enemies:
		if not valid(e) or e == exclude:
			continue
		var d: Vector3 = e.global_position - game.player.global_position
		var dist: float = Vector2(d.x, d.z).length()
		if dist > RANGE:
			continue
		var to_e: Vector3 = _chest(e) - cam.global_position
		to_e.y = 0
		# за спиной героя (даже если перед камерой — между ней и героем) или сбоку — не берём
		if to_e.length() < 0.1 or dist < 0.1 or fw.dot(Vector3(d.x, 0, d.z) / dist) < 0.2:
			continue
		if not sees(e):
			continue
		var ang: float = rad_to_deg(fw.angle_to(to_e.normalized()))
		var s: float = ang * 1.0 + dist * 2.2
		if s < bs:
			bs = s
			best = e
	return best

## Следующая / предыдущая цель: по горизонтали на экране от нынешней (стабильно, без прыжков от дрожи камеры)
func cycle(step: int) -> void:
	if not active():
		return
	var cam: Camera3D = game.cam
	var cur_x: float = cam.unproject_position(_chest(target)).x
	var cands: Array = []
	for e in game.enemies:
		if not valid(e) or e == target:
			continue
		var dp: Vector3 = e.global_position - game.player.global_position
		dp.y = 0
		var fw: Vector3 = -cam.global_transform.basis.z
		fw.y = 0
		if dp.length() > RANGE or dp.length() < 0.1 or fw.normalized().dot(dp.normalized()) < 0.2 or cam.is_position_behind(_chest(e)) or not sees(e):
			continue                                  # как при выборе: за спиной героя не переключаемся
		cands.append([cam.unproject_position(_chest(e)).x - cur_x, e])
	if cands.is_empty():
		return
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var chosen = null
	if step > 0:
		for c in cands:
			if float(c[0]) > 4.0:
				chosen = c[1]
				break
		if chosen == null:
			chosen = cands[0][1]                       # дошли до края — по кругу к самой левой
	else:
		for i in range(cands.size() - 1, -1, -1):
			if float(cands[i][0]) < -4.0:
				chosen = cands[i][1]
				break
		if chosen == null:
			chosen = cands[cands.size() - 1][1]
	lock_to(chosen)
	events.append(["next" if step > 0 else "prev", chosen.get_instance_id()])
	game.main.sfx("sfx_ui", -14.0, 1.6)

## Камера свободна для захвата: никто другой ею сейчас не владеет
func camera_free() -> bool:
	if game.mode == "dlg" or game.intro_busy() or game.over:
		return false
	if game.hype != null and game.hype.active():
		return false
	if game.death != null and is_instance_valid(game.death):
		return false
	if game.get_tree().paused or float(game.ipod_focus) > 0.05:
		return false
	if game.director != null and game.director.owns_camera():
		return false
	return true

## Каждый кадр (game._process, до расчёта камеры): проверка цели, камера, маркер
func camera_tick(rdt: float) -> void:
	if active():
		var e = target
		if not valid(e):
			release("dead")
		elif e.global_position.distance_to(game.player.global_position) > DROP:
			release("far")
		else:
			lost_t = 0.0 if sees(e) else lost_t + rdt
			if lost_t > LOST_T:
				release("hidden")
	elif target != null:
		release("gone")
	if active() and camera_free():
		var p = game.player
		var to: Vector3 = _chest(target) - (p.global_position + Vector3(0, 1.55, 0))
		var flat := Vector2(to.x, to.z).length()
		if flat > CLOSE:
			var want_yaw := atan2(-to.x, -to.z)
			game.cam_yaw = lerp_angle(game.cam_yaw, want_yaw, 1.0 - exp(-YAW_RATE * rdt))
			# наклон: цель выше (в воздухе, большой босс) — камера смотрит выше; в рамках обычных пределов
			var want_pitch: float = clampf(-atan2(-to.y, flat) * 0.6 - 0.18, -0.75, 0.2)
			game.cam_pitch = lerpf(game.cam_pitch, want_pitch, 1.0 - exp(-3.0 * rdt))
	# маркер плавно появляется и гаснет
	var want_show := 1.0 if active() else 0.0
	shown = move_toward(shown, want_show, rdt * 6.0)
	marker.visible = shown > 0.01
	if active():
		var cam_pos: Vector3 = game.cam.global_position
		var at: Vector3 = target.global_position + Vector3(0, float(target.height) * 0.55, 0)
		# чуть к камере, чтобы не прятался в теле, и ниже лица
		marker.global_position = at + (cam_pos - at).normalized() * 0.35
	marker.modulate = Color(1, 1, 1, shown * (0.85 + 0.15 * sin(float(game.clock) * 6.0)))
	marker.scale = Vector3.ONE * lerpf(1.6, 1.0, shown)

## Куда смотреть герою, если цель есть и рядом (для стойки, блока, удара); иначе NAN
func face_to(from: Vector3, reach := 99.0) -> float:
	if not active():
		return NAN
	var d: Vector3 = target.global_position - from
	d.y = 0
	if d.length() < 0.05 or d.length() > reach:
		return NAN
	return atan2(d.x, d.z)
