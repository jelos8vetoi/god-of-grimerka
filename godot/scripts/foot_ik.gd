## Стопы на земле (этап 03): слой поверх анимации (SkeletonModifier3D, как drag.gd и pod.gd).
##  1) Прилегание: под каждой стопой — луч в землю; стопа ставится на найденную высоту с тем же подъёмом,
##     что в анимации (ступени, неровный пол). Двухзвенный IK ноги (бедро → голень), стопа сохраняет поворот.
##  2) Фиксация опоры: стопа, которая в анимации стоит на земле и почти не движется, прибивается к месту
##     касания в мире и отпускается плавно — так тело не «едет» на поворотах, остановках и стартах.
## weight — сила прилегания (0 — чистая анимация), lock — сила фиксации; их задаёт контроллер по состоянию
## (в ударах фиксация выключена: шаг в удар делает само тело). Без физического пола (листы поз) — только фиксация.
class_name FootIK
extends SkeletonModifier3D

var rig: Rig
var weight := 1.0
var lock := 1.0
var exclude: Array[RID] = []
var max_reach := 0.35        # насколько стопа может подняться к ступени или опуститься, м
var slip := 0.0              # проскальзывание опорных стоп за последний кадр, м (для проверок)
## выключить слой у всех (контрольный прогон --animlab … --nofootik: замер должен показать скольжение)
static var off := false
var feet := {}               # "r"/"l" → {up, leg, foot, rest_h, locked, at, w, prev}

func setup(r: Rig) -> void:
	rig = r
	for s in ["r", "l"]:
		var f: int = rig.bone[s + "foot"]
		# высота голеностопа над подошвой в позе привязки, м
		var h: float = ((rig.skel_xf * (rig._chain(rig.rest_rot, f)[1] as Vector3)).y - rig.foot_y) * rig.model.scale.x
		feet[s] = {"up": rig.bone[s + "up"], "leg": rig.bone[s + "leg"], "foot": f, "rest_h": h, "locked": false, "at": Vector3.ZERO, "w": 0.0, "prev": Vector3.ZERO, "fresh": true}

func _ground(from: Vector3) -> float:
	var space := rig.get_world_3d().direct_space_state if rig.is_inside_tree() else null
	if space == null:
		return NAN
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * max_reach, from + Vector3.DOWN * (max_reach + 0.4), 1)
	q.exclude = exclude
	var hit: Dictionary = space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null or feet.is_empty() or off:
		return
	var gx := sk.global_transform
	var base_y := rig.global_position.y
	slip = 0.0
	for s in feet:
		var F: Dictionary = feet[s]
		var hip: Transform3D = gx * sk.get_bone_global_pose(F["up"])
		var knee: Transform3D = gx * sk.get_bone_global_pose(F["leg"])
		var ank: Transform3D = gx * sk.get_bone_global_pose(F["foot"])
		var A := ank.origin
		var lift: float = A.y - base_y - float(F["rest_h"])    # насколько стопа поднята в самой анимации
		var T := A
		if weight > 0.001:
			var g := _ground(A)
			if not is_nan(g) and absf(g - base_y) < max_reach:
				T.y = lerpf(A.y, g + float(F["rest_h"]) + max(0.0, lift), weight)
		# опора: стоит в анимации на земле и почти не двигается в мире
		var sp: float = (A - (F["prev"] as Vector3)).length() / max(delta, 0.0001) if not F["fresh"] else 99.0
		F["prev"] = A
		F["fresh"] = false
		var planted := lift < 0.035 and sp < 1.2
		if planted and not F["locked"]:
			F["locked"] = true
			F["at"] = T
		elif F["locked"] and (not planted or Vector2(T.x - F["at"].x, T.z - F["at"].z).length() > 0.08):
			F["locked"] = false
		var want := lock if F["locked"] else 0.0
		F["w"] = move_toward(float(F["w"]), want, delta * (12.0 if want > float(F["w"]) else 5.0))
		if float(F["w"]) > 0.001:
			var at: Vector3 = F["at"]
			slip = max(slip, Vector2(A.x - at.x, A.z - at.z).length() * float(F["w"]))
			T.x = lerpf(T.x, at.x, float(F["w"]))
			T.z = lerpf(T.z, at.z, float(F["w"]))
		if T.distance_to(A) < 0.002:
			continue
		_solve(sk, gx, F, hip, knee, ank, T)

## двухзвенный IK: бедро и голень поворачиваются в плоскости, где уже согнуто колено; стопа сохраняет поворот в мире
func _solve(sk: Skeleton3D, gx: Transform3D, F: Dictionary, hip: Transform3D, knee: Transform3D, ank: Transform3D, T: Vector3) -> void:
	var H := hip.origin
	var K := knee.origin
	var A := ank.origin
	var L1 := H.distance_to(K)
	var L2 := K.distance_to(A)
	var to := T - H
	var d := clampf(to.length(), absf(L1 - L2) + 0.01, (L1 + L2) * 0.999)
	var u := to.normalized()
	var bend := (K - H) - u * (K - H).dot(u)
	if bend.length() < 0.0001:
		bend = ank.basis.z.normalized()   # нога прямая: колено — туда, куда смотрит стопа
	bend = bend.normalized()
	var ca := clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var K2 := H + u * (L1 * ca) + bend * (L1 * sqrt(max(0.0, 1.0 - ca * ca)))
	var A2 := H + u * d
	var inv := gx.affine_inverse()
	var foot_basis := ank.basis
	# бедро
	var q1 := Quaternion((K - H).normalized(), (K2 - H).normalized())
	var hip2 := Transform3D(Basis(q1) * hip.basis, H)
	sk.set_bone_global_pose(F["up"], inv * hip2)
	# голень: от нового колена к цели
	var k_now: Transform3D = gx * sk.get_bone_global_pose(F["leg"])
	var a_now: Vector3 = (gx * sk.get_bone_global_pose(F["foot"])).origin
	var q2 := Quaternion((a_now - k_now.origin).normalized(), (A2 - k_now.origin).normalized())
	sk.set_bone_global_pose(F["leg"], inv * Transform3D(Basis(q2) * k_now.basis, k_now.origin))
	# стопа: прежний поворот в мире
	var a2: Vector3 = (gx * sk.get_bone_global_pose(F["foot"])).origin
	sk.set_bone_global_pose(F["foot"], inv * Transform3D(foot_basis, a2))
