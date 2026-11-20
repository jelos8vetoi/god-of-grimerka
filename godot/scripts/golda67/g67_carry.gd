## Вещь в руке жителя (авоська бабушки) привязана к кости кисти. Модель вылеплена в T-позе: когда рука опускается,
## вещь повернулась бы вместе с ней и легла набок. Этот слой после анимации возвращает кисти тот поворот, что был
## в позе покоя, — сумка всегда висит вниз, а место кисти остаётся там, куда её привела рука.
class_name G67Carry
extends SkeletonModifier3D

var bone := -1
var keep := Basis()

static func attach(rig: Rig, bone_name: String) -> G67Carry:
	if rig == null or rig.skel == null:
		return null
	var b := rig.skel.find_bone(bone_name)
	if b < 0:
		return null
	var c := G67Carry.new()
	c.bone = b
	c.keep = rig.skel.get_bone_global_rest(b).basis
	rig.skel.add_child(c)
	return c

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or bone < 0:
		return
	var g := sk.get_bone_global_pose(bone)
	g.basis = keep
	sk.set_bone_global_pose(bone, g)
