## Поведение жителя «ГОЛДА 67»: основная поза большую часть времени (~70 %), изредка — другая поза из своего набора,
## медленные повороты головы, взгляд вслед Пахану (только если тот рядом и впереди — житель не видит затылком)
## и короткие реакции по событию (G67Yard.crowd_react). Переходы плавные; у каждого свои случайные задержки —
## никто не двигается в такт. Слой стоит после анимации (SkeletonModifier3D): доворачивает шею и голову.
class_name G67Life
extends SkeletonModifier3D

var rig: Rig
var base := "Idle"
var alts: Array = []
var base_hold := Vector2(7.0, 14.0)    # сколько стоит в основной позе, с
var alt_hold := Vector2(3.0, 5.5)      # сколько держит другую позу (у однократных — длину клипа)
var look_r := 7.0                      # с какого расстояния замечает Пахана
var poi := Vector3.INF                 # куда иногда поглядывает (арена, дорога): в координатах poi_ref или мира
var poi_ref: Node3D = null              # чьи координаты у poi (двор сдвигается под комнату — точку пересчитываем на лету)
var turn_speed := 1.8                  # скорость поворота головы, рад/с (у бабушки медленнее)
var watcher = null                     # кто «интересен» (обычно герой): Node3D

var cur := ""
var t := 0.0
var in_alt := false
var react_t := 0.0                     # идёт реакция — до её конца позу не меняем
var react_cd := 0.0
var glance_t := 0.0
var glance := Vector2.ZERO             # куда смотрит «просто так»: (поворот, наклон)
var yaw := 0.0                         # текущий поворот головы (сглаженный)
var pitch := 0.0
var rng := RandomNumberGenerator.new()
var b_head := -1
var b_neck := -1
var paused := false                    # постановка (КРОТ в разговоре) ведёт клипы сама; голова — по-прежнему здесь

## Поставить жителю поведение. profile: base, alts, base_hold, alt_hold, look_r, poi, turn
static func attach(r: Rig, profile: Dictionary, seed_v: int) -> G67Life:
	if r == null or r.skel == null:
		return null
	var L := G67Life.new()
	L.rig = r
	L.rng.seed = seed_v
	L.base = String(profile.get("base", "Idle"))
	L.alts = profile.get("alts", [])
	L.base_hold = profile.get("base_hold", L.base_hold)
	L.alt_hold = profile.get("alt_hold", L.alt_hold)
	L.look_r = float(profile.get("look_r", L.look_r))
	L.poi = profile.get("poi", Vector3.INF)
	L.poi_ref = profile.get("poi_ref", null)
	L.turn_speed = float(profile.get("turn", L.turn_speed))
	L.b_head = r.skel.find_bone("mixamorig_Head")
	L.b_neck = r.skel.find_bone("mixamorig_Neck")
	r.skel.add_child(L)
	L._play(L.base, 0.0)
	if r.player != null:
		r.player.seek(L.rng.randf_range(0.0, 3.0), true)      # своя фаза дыхания
	L.t = L.rng.randf_range(2.0, L.base_hold.y)                 # первая смена позы — в разное время у всех
	L.glance_t = L.rng.randf_range(1.0, 6.0)
	return L

func _play(clip: String, blend: float) -> void:
	if rig == null or not rig.has_clip(clip):
		clip = "Idle"
	cur = clip
	rig.play(clip, blend)
	G67Poses.props(rig, clip)

func _clip_len(clip: String) -> float:
	return rig.clip_len(clip) if rig.has_clip(clip) else 2.0

func _looping(clip: String) -> bool:
	var a: Animation = rig.player.get_animation("g/" + clip) if rig.player != null and rig.player.has_animation("g/" + clip) else null
	return a != null and a.loop_mode != Animation.LOOP_NONE

func _process(dt: float) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	react_cd = maxf(0.0, react_cd - dt)
	if react_t > 0.0:
		react_t -= dt
		if react_t <= 0.0:
			_play(cur, 0.45)          # реакция кончилась — обратно в свою позу
		return
	if paused:
		return
	t -= dt
	if t > 0.0:
		return
	if in_alt or alts.is_empty():
		in_alt = false
		if cur != base:
			_play(base, 0.9)
		t = rng.randf_range(base_hold.x, base_hold.y)
	else:
		var pick: String = alts[rng.randi() % alts.size()]
		in_alt = true
		_play(pick, 0.9)
		if _looping(pick):
			t = rng.randf_range(alt_hold.x, alt_hold.y)
		else:
			t = _clip_len(pick) * 0.95      # однократное движение (поправил платок, рюкзак) — и назад

## Короткая реакция (удар, добивание, смена фазы босса). false — занят или недавно реагировал
func react(clip: String) -> bool:
	if react_t > 0.0 or react_cd > 0.0 or not rig.has_clip(clip):
		return false
	var d := _clip_len(clip)
	rig.play_for(clip, d, 0.22)
	react_t = d
	react_cd = d + rng.randf_range(2.5, 5.0)
	return true

## Сыграть клип постановки (КРОТ): поведение приостанавливается, голова остаётся живой
func stage(clip: String, blend := 0.35, once_len := 0.0) -> void:
	paused = true
	if once_len > 0.0:
		rig.play_for(clip, once_len, blend)
	else:
		cur = clip
		rig.play(clip, blend)
		G67Poses.props(rig, clip)

func resume() -> void:
	paused = false
	t = rng.randf_range(base_hold.x, base_hold.y) * 0.5
	_play(base, 0.6)

# ---------------------------------------------------------------- голова
func _want(dt: float) -> Vector2:
	var head_w: Vector3 = rig.skel.global_transform * (rig.skel.get_bone_global_pose(b_head).origin if b_head >= 0 else Vector3(0, 1.5, 0))
	var fw: Vector3 = rig.global_transform.basis.z
	fw.y = 0.0
	fw = fw.normalized()
	# Пахан рядом и впереди — смотрит на него
	if watcher != null and is_instance_valid(watcher):
		var to: Vector3 = (watcher as Node3D).global_position + Vector3(0, 1.3, 0) - head_w
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < look_r and flat.length() > 0.3:
			var a := atan2(fw.cross(flat.normalized()).y, fw.dot(flat.normalized()))
			if absf(a) < 1.7:
				return Vector2(clampf(a, -1.05, 1.05), clampf(atan2(to.y, flat.length()), -0.45, 0.35))
	# иначе — иногда поглядывает: в свою точку интереса или просто по сторонам
	glance_t -= dt
	if glance_t <= 0.0:
		if glance == Vector2.ZERO:
			if poi != Vector3.INF and rng.randf() < 0.65:
				var pw: Vector3 = poi_ref.to_global(poi) if poi_ref != null and is_instance_valid(poi_ref) else poi
				var tp: Vector3 = pw - head_w
				var fl := Vector3(tp.x, 0, tp.z).normalized()
				glance = Vector2(clampf(atan2(fw.cross(fl).y, fw.dot(fl)), -1.0, 1.0), -0.05)
			else:
				glance = Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.12, 0.1))
			glance_t = rng.randf_range(1.8, 3.5)
		else:
			glance = Vector2.ZERO
			glance_t = rng.randf_range(4.0, 9.0)
	return glance

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or b_head < 0 or rig == null:
		return
	var dt := get_process_delta_time()
	var w := _want(dt)
	var step := turn_speed * dt
	yaw = move_toward(yaw, w.x, step)
	pitch = move_toward(pitch, w.y, step * 0.6)
	if absf(yaw) < 0.002 and absf(pitch) < 0.002:
		return
	var inv := sk.global_transform.basis.orthonormalized().inverse()
	var fw: Vector3 = rig.global_transform.basis.z.normalized()
	var up_l: Vector3 = (inv * Vector3.UP).normalized()
	var right_l: Vector3 = (inv * fw.cross(Vector3.UP)).normalized()
	# шея берёт 40 %, голова — остальное
	for part in [[b_neck, 0.4], [b_head, 0.6]]:
		var b: int = part[0]
		if b < 0:
			continue
		var k: float = part[1]
		var g := sk.get_bone_global_pose(b)
		var q := Quaternion(up_l, yaw * k) * Quaternion(right_l, pitch * k)
		g.basis = Basis(q) * g.basis
		sk.set_bone_global_pose(b, g)
