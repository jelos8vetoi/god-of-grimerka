## Рука тянется к точке поверх любой анимации (SkeletonModifier3D, как drag.gd и pod.gd): madk1d достаёт доску
## из-за спины и убирает её обратно, не останавливаясь, — ноги и корпус продолжают свой клип.
## w — вес (0 — анимация как есть, 1 — кисть в точке), target — точка в осях скелета.
class_name ArmReach
extends SkeletonModifier3D

var rig: Rig
var side := "r"
var w := 0.0
var target := Vector3.ZERO

func setup(r: Rig, s := "r") -> void:
	rig = r
	side = s

func _process_modification() -> void:
	if w <= 0.001 or rig == null:
		return
	var sk := get_skeleton()
	var a: int = rig.bone["rarm" if side == "r" else "larm"]
	var f: int = rig.bone["rfa" if side == "r" else "lfa"]
	var h: int = rig.bone["rhand" if side == "r" else "lhand"]
	if a < 0 or f < 0 or h < 0:
		return
	var A := sk.get_bone_global_pose(a)
	var F := sk.get_bone_global_pose(f)
	var H := sk.get_bone_global_pose(h)
	var S := A.origin
	var L1 := (F.origin - S).length()
	var L2 := (H.origin - F.origin).length()
	var to := target - S
	if to.length() < 0.0001 or L1 < 0.0001 or L2 < 0.0001:
		return
	var d: float = clampf(to.length(), 0.05 * (L1 + L2), (L1 + L2) * 0.999)
	var u := to.normalized()
	# локоть: туда же, куда смотрит сейчас, с добавкой «вверх и наружу» — за спину рука идёт через верх
	var cur := F.origin - S
	var pole := rig.dir_sk(Vector3(-0.7 if side == "r" else 0.7, 0.6, -0.2))
	var pp: Vector3 = (cur - u * cur.dot(u)) / L1 * 0.4 + (pole - u * pole.dot(u))
	if pp.length() < 0.001:
		pp = rig.dir_sk(Vector3(0, 1, 0))
	pp = pp.normalized()
	var ca: float = clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var E := S + u * (L1 * ca) + pp * (L1 * sqrt(max(0.0, 1.0 - ca * ca)))
	var q1 := Quaternion.IDENTITY.slerp(Quaternion(cur.normalized(), (E - S).normalized()), w)
	sk.set_bone_global_pose(a, Transform3D(Basis(q1) * A.basis, S))
	var F2 := sk.get_bone_global_pose(f)
	var H2 := sk.get_bone_global_pose(h)
	var wrist := S + u * d
	var q2 := Quaternion.IDENTITY.slerp(Quaternion((H2.origin - F2.origin).normalized(), (wrist - F2.origin).normalized()), w)
	sk.set_bone_global_pose(f, Transform3D(Basis(q2) * F2.basis, F2.origin))
