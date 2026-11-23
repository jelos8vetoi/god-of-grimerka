## Паника: руки подняты в стороны-вверх и машут — поправка плеч и предплечий поверх анимации бега.
## Работает как модификатор скелета (применяется после анимации, до отрисовки): G67PanicArms.attach(skeleton)
class_name G67PanicArms
extends SkeletonModifier3D

const NAMES := {"l": ["mixamorig_LeftArm", "mixamorig_LeftForeArm", 1.0], "r": ["mixamorig_RightArm", "mixamorig_RightForeArm", -1.0]}
var ids: Dictionary = {}
var t := 0.0
var lift := 1.9

static func attach(skel: Skeleton3D) -> G67PanicArms:
	var m := G67PanicArms.new()
	skel.add_child(m)
	for k in NAMES:
		var a := skel.find_bone(String(NAMES[k][0]))
		var f := skel.find_bone(String(NAMES[k][1]))
		if a < 0 or f < 0:
			m.queue_free()
			return null
		m.ids[k] = [a, f, skel.get_bone_rest(a).basis.get_rotation_quaternion(), skel.get_bone_rest(f).basis.get_rotation_quaternion(), float(NAMES[k][2])]
	return m

func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	t += get_process_delta_time()
	for k in ids:
		var e: Array = ids[k]
		var wave := sin(t * 9.0 + (0.0 if k == "l" else 1.7)) * 0.35
		skel.set_bone_pose_rotation(int(e[0]), (e[2] as Quaternion) * Quaternion(Vector3(1, 0, 0), float(e[4]) * (lift + wave)))
		skel.set_bone_pose_rotation(int(e[1]), (e[3] as Quaternion) * Quaternion(Vector3(0, 0, 1), float(e[4]) * 0.15 * sin(t * 9.0 + 0.8)))
