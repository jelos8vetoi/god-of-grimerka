## Инерция тяжёлого оружия поверх анимации (слой после AnimationPlayer, работает на готовой позе скелета).
## Конец оружия — «груз на пружине»: он тянется к месту, куда его ведёт анимация, но с отставанием и затуханием.
## Поэтому на поворотах балон не поспевает за героем, на остановке ещё немного едет и тяжело замирает,
## а в землю не проваливается — упирается и волочится (on_ground, scrape_speed — для звука скрежета и искр).
## Отклонение переводится в поворот всей руки от плеча и доворот кисти, так что балон «тянет» руку за собой.
class_name WeaponDrag
extends SkeletonModifier3D

var rig: Rig
var weight := 1.0            # 0 — оружие идёт строго по анимации (удары), 1 — полная инерция (ходьба, стойка)
var freq := 2.2              # собственная частота груза, Гц: меньше — тяжелее
var damp := 0.8              # затухание: меньше 1 — слегка проскакивает и возвращается
var max_angle := 0.75        # дальше от анимации оружие не отклонится (рад)
var floor_y := 0.07          # высота земли под концом оружия, мировая
var tip := Vector3.ZERO      # конец оружия в мире (с инерцией)
var vel := Vector3.ZERO
var on_ground := false
var scrape_speed := 0.0      # скорость конца по земле, м/с
var started := false

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null or rig.weapon == null or rig.weapon_bone < 0:
		return
	var arm: int = rig.bone["rarm"]
	var gx := sk.global_transform
	var wxf := gx * sk.get_bone_global_pose(rig.weapon_bone) * rig.weapon.transform
	var grip := wxf.origin
	var tip_anim := wxf * Vector3(0, 1.0 - rig.weapon_grip, 0)
	var ln := (tip_anim - grip).length()
	if ln < 0.01:
		return
	var da := (tip_anim - grip) / ln
	if not started or weight <= 0.001 or delta <= 0.0 or (tip - tip_anim).length() > 3.0:
		started = true
		tip = tip_anim
		vel = Vector3.ZERO
		on_ground = tip_anim.y <= floor_y + 0.04
		scrape_speed = 0.0
		return
	# груз на пружине: тянется к анимированной точке
	var dt: float = min(delta, 0.05)
	var w0 := TAU * freq
	var prev := tip
	vel += ((tip_anim - tip) * w0 * w0 - vel * 2.0 * damp * w0) * dt
	tip += vel * dt
	# длина оружия постоянна, от анимации далеко не уходим
	var ds := (tip - grip).normalized()
	var ang := da.angle_to(ds)
	if ang > max_angle:
		ds = da.slerp(ds, max_angle / ang)
	tip = grip + ds * ln
	# земля: конец упирается и трётся
	on_ground = false
	if tip.y < floor_y:
		on_ground = true
		for i in 2:
			tip.y = floor_y
			tip = grip + (tip - grip).normalized() * ln
		vel.y = max(vel.y, 0.0)
		var fr := exp(-5.0 * dt)
		vel.x *= fr
		vel.z *= fr
	scrape_speed = Vector2(tip.x - prev.x, tip.z - prev.z).length() / dt if on_ground else 0.0
	var dir := da.slerp((tip - grip).normalized(), clampf(weight, 0.0, 1.0))
	if da.angle_to(dir) < 0.002:
		return
	var gq := gx.basis.get_rotation_quaternion()
	# 1) вся рука от плеча: балон тянет её за собой
	var ap := sk.get_bone_global_pose(arm)
	var sh := (gx * ap).origin
	var a_from := (tip_anim - sh).normalized()
	var a_to := (grip + dir * ln - sh).normalized()
	if a_from.angle_to(a_to) > 0.001 and a_from.dot(a_to) > -0.99:
		var q := Quaternion.IDENTITY.slerp(Quaternion(a_from, a_to), 0.6)
		ap.basis = Basis(gq.inverse() * q * gq) * ap.basis
		sk.set_bone_global_pose(arm, ap)
	# 2) кисть доворачивает остаток
	var hp := sk.get_bone_global_pose(rig.weapon_bone)
	var w2 := gx * hp * rig.weapon.transform
	var cur := (w2 * Vector3(0, 1.0 - rig.weapon_grip, 0) - w2.origin).normalized()
	if cur.angle_to(dir) > 0.001 and cur.dot(dir) > -0.99:
		hp.basis = Basis(gq.inverse() * Quaternion(cur, dir) * gq) * hp.basis
		sk.set_bone_global_pose(rig.weapon_bone, hp)
