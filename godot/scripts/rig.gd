## Персонаж из .glb со скелетом Mixamo: масштаб под нужный рост, анимации из поз (Poses), оружие в руке.
class_name Rig
extends Node3D

const BONES := {
	"hips": "Hips", "spine": "Spine", "spine1": "Spine1", "spine2": "Spine2", "neck": "Neck", "head": "Head",
	"rsh": "RightShoulder", "rarm": "RightArm", "rfa": "RightForeArm", "rhand": "RightHand",
	"lsh": "LeftShoulder", "larm": "LeftArm", "lfa": "LeftForeArm", "lhand": "LeftHand",
	"rup": "RightUpLeg", "rleg": "RightLeg", "rfoot": "RightFoot", "lup": "LeftUpLeg", "lleg": "LeftLeg", "lfoot": "LeftFoot",
}
const ORDER := ["hips", "spine", "spine1", "spine2", "neck", "head", "rsh", "rarm", "rfa", "rhand", "lsh", "larm", "lfa", "lhand", "rup", "rleg", "rfoot", "lup", "lleg", "lfoot"]
const AXES := {"x": Vector3(1, 0, 0), "y": Vector3(0, 1, 0), "z": Vector3(0, 0, 1)}

var model: Node3D
var skel: Skeleton3D
var player: AnimationPlayer
var bone := {}            # ключ → индекс кости
var rest_rot := []        # локальные повороты в позе привязки
var skel_basis := Basis() # из пространства скелета в пространство модели
var skel_path := ""
var model_height := 1.0
var cur := ""

func setup(path: String, height: float, poses: Dictionary, shadows := true) -> void:
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	skel = _find_skeleton(model)
	# пространство скелета → модель
	var m := Transform3D()
	var n: Node = skel
	var names := []
	while n != model:
		m = (n as Node3D).transform * m
		names.push_front(n.name)
		n = n.get_parent()
	skel_basis = m.basis
	skel_path = "/".join(names)
	for i in skel.get_bone_count():
		rest_rot.append(skel.get_bone_rest(i).basis.get_rotation_quaternion())
	for k in BONES:
		bone[k] = _find_bone(BONES[k])
	# рост: по габаритам сетки
	var aabb := _mesh_aabb(model)
	model_height = max(0.01, aabb.size.y)
	var s := height / model_height
	model.scale = Vector3.ONE * s
	model.position.y = -aabb.position.y * s
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# анимации
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		player = found[0]
	else:
		player = AnimationPlayer.new()
		model.add_child(player)
		player.root_node = NodePath("..")
	var prefix := skel_path
	var lib := AnimationLibrary.new()
	for name in poses:
		lib.add_animation(name, _build(poses[name], prefix))
	player.add_animation_library("g", lib)
	play("Idle", 0.0)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null

func _find_bone(suffix: String) -> int:
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		if nm.ends_with(suffix):
			var pre := nm.substr(0, nm.length() - suffix.length())
			var ch := pre.right(1)
			if pre == "" or ch.to_upper() == ch.to_lower():
				return i
	return -1

func _mesh_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var xf := Transform3D()
		var n: Node = inst
		while n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * inst.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

# поворот в пространстве скелета для локальных поворотов rots
func _global_rot(rots: Array, i: int) -> Quaternion:
	var q := Quaternion.IDENTITY
	var chain := []
	var j := i
	while j >= 0:
		chain.push_front(j)
		j = skel.get_bone_parent(j)
	for b in chain:
		q = q * rots[b]
	return q

func pose_rots(pose: Dictionary) -> Array:
	var rots := rest_rot.duplicate()
	var inv := skel_basis.inverse()
	for k in ORDER:
		if not pose.has(k) or bone[k] < 0:
			continue
		var b: int = bone[k]
		for a in pose[k]:
			var ang: float = pose[k][a]
			if ang == 0.0:
				continue
			var ax: Vector3 = (inv * AXES[a]).normalized()
			var par := skel.get_bone_parent(b)
			var P: Quaternion = _global_rot(rots, par) if par >= 0 else Quaternion.IDENTITY
			var d := Quaternion(ax, ang)
			rots[b] = (P.inverse() * d * P) * rots[b]
	return rots

func _build(def: Dictionary, prefix: String) -> Animation:
	var anim := Animation.new()
	var dur: float = def.get("d", 1.0)
	anim.length = dur
	anim.loop_mode = Animation.LOOP_LINEAR if def.get("loop", false) else Animation.LOOP_NONE
	var keys: Array = def["k"]
	var tracks := {}
	for k in ORDER:
		if bone[k] < 0:
			continue
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath(prefix + ":" + skel.get_bone_name(bone[k])))
		tracks[k] = t
	# таз: высота (для падений и подъёма)
	var hips: int = bone["hips"]
	var hp_t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hp_t, NodePath(prefix + ":" + skel.get_bone_name(hips)))
	var rest_pos := skel.get_bone_rest(hips).origin
	var hips_h := (skel_basis * skel.get_bone_global_rest(hips).origin).y
	var hpar := skel.get_bone_parent(hips)
	var par_basis := skel.get_bone_global_rest(hpar).basis if hpar >= 0 else Basis()
	for key in keys:
		var t: float = key[0] * dur
		var pose: Dictionary = key[1]
		var rots := pose_rots(pose)
		for k in tracks:
			anim.rotation_track_insert_key(tracks[k], t, rots[bone[k]])
		var drop: float = pose.get("drop", 0.0)
		var off := par_basis.inverse() * (skel_basis.inverse() * Vector3(0, -drop * hips_h, 0))
		anim.position_track_insert_key(hp_t, t, rest_pos + off)
	return anim

func play(name: String, blend := 0.18, speed := 1.0) -> void:
	var full := "g/" + name
	if not player.has_animation(full):
		return
	if cur == name and player.is_playing() and player.get_animation(full).loop_mode != Animation.LOOP_NONE:
		return
	cur = name
	player.play(full, blend, speed)

## проиграть один раз за duration секунд
func play_for(name: String, duration: float, blend := 0.09) -> void:
	var full := "g/" + name
	if not player.has_animation(full):
		return
	cur = name
	var len := player.get_animation(full).length
	player.play(full, blend, len / max(0.05, duration))
	player.seek(0.0, true)

func clip_len(name: String) -> float:
	var full := "g/" + name
	return player.get_animation(full).length if player.has_animation(full) else 1.0

## Оружие в кость. axis — ось модели оружия вдоль древка ("y" или "z"), from/to — её концы, grip — доля длины, где хват;
## dir — куда оружие смотрит в стойке (оси персонажа); length — длина в долях роста; part — фильтр треугольников по высоте модели.
func attach(weapon_path: String, bone_key: String, opt: Dictionary) -> Node3D:
	var b: int = bone[bone_key]
	if b < 0:
		return null
	var w: Node3D = (load(weapon_path) as PackedScene).instantiate()
	if opt.has("part"):
		var f: Callable = opt["part"]
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = _filter_mesh((mi as MeshInstance3D).mesh, f)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if opt.get("shadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var axis: String = opt.get("axis", "y")
	var from_v: float = opt.get("from", 0.0)
	var to_v: float = opt.get("to", 1.0)
	# оружие от конца from к концу to ложится вдоль +Y, from в нуле; если to < from — разворачиваем
	var L: float = abs(to_v - from_v)
	var inner := Node3D.new()
	inner.add_child(w)
	if axis == "z":
		inner.rotation.x = -PI / 2 if to_v > from_v else PI / 2
		w.position.z = -from_v
	else:
		inner.rotation.x = 0.0 if to_v > from_v else PI
		w.position.y = -from_v
	inner.position.y = -float(opt.get("grip", 0.0)) * L
	var unit := Node3D.new()
	unit.add_child(inner)
	unit.scale = Vector3.ONE / L
	# направление в стойке: поворот кости в позе Idle
	var idle_pose: Dictionary = opt.get("pose", {})
	var rots := pose_rots(idle_pose)
	var g := _global_rot(rots, b)                       # кость в пространстве скелета
	var d: Array = opt.get("dir", [0, 1, 0])
	var dir_sk := (skel_basis.inverse() * Vector3(d[0], d[1], d[2])).normalized()
	var dir_bone := (g.inverse() * dir_sk).normalized()
	var piv := Node3D.new()
	piv.quaternion = Quaternion(Vector3.UP, dir_bone)
	var sk_scale := skel_basis.get_scale().x
	var len_sk: float = opt.get("length", 0.4) * model_height / sk_scale
	piv.scale = Vector3.ONE * len_sk
	if opt.has("off"):
		var o: Array = opt["off"]
		piv.position = g.inverse() * (skel_basis.inverse() * Vector3(o[0], o[1], o[2]) * model_height)
	piv.add_child(unit)
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(b)
	skel.add_child(att)
	att.add_child(piv)
	return att

func _filter_mesh(mesh: Mesh, keep: Callable) -> Mesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var ni := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if keep.call(pos[idx[t]].y) and keep.call(pos[idx[t + 1]].y) and keep.call(pos[idx[t + 2]].y):
				ni.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arr[Mesh.ARRAY_INDEX] = ni
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out
