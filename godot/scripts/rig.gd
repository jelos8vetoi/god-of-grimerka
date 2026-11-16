## Персонаж из .glb со скелетом Mixamo: масштаб под нужный рост, анимации из поз (Poses), оружие в кулаке.
## Пальцы сжаты в кулак; рукоять проходит через кулак вдоль линии костяшек (от мизинца к указательному).
## Удары с оружием задаются движением самого оружия (где хват и куда смотрит клинок), руки тянутся за ним (IK).
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
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]

var model: Node3D
var skel: Skeleton3D
var player: AnimationPlayer
var bone := {}             # ключ → индекс кости
var rest_rot := []         # локальные повороты привязки (с уже сжатыми кулаками)
var rest_pos := []         # локальные смещения костей
var skel_xf := Transform3D()  # пространство скелета → пространство модели
var skel_path := ""
var model_height := 1.0
var foot_y := 0.0
var hand := {}             # "r"/"l" → {k, f, grip}: оси кулака и центр хвата в осях кисти
var weapon_sign := 1.0     # +1 — оружие выходит со стороны большого пальца, −1 — со стороны мизинца (бутылка за горлышко)
var cur := ""
static var _lib_cache := {}   # библиотека анимаций на модель+набор поз: одинаковым врагам не пересчитываем

func setup(path: String, height: float, poses: Dictionary, shadows := true, wsign := 1.0, cache_key := "") -> void:
	weapon_sign = wsign
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	skel = _find_skeleton(model)
	var m := Transform3D()
	var n: Node = skel
	var names := []
	while n != model:
		m = (n as Node3D).transform * m
		names.push_front(n.name)
		n = n.get_parent()
	skel_xf = m
	skel_path = "/".join(names)
	for i in skel.get_bone_count():
		rest_rot.append(skel.get_bone_rest(i).basis.get_rotation_quaternion())
		rest_pos.append(skel.get_bone_rest(i).origin)
	for k in BONES:
		bone[k] = _find_bone(BONES[k])
	var aabb := _mesh_aabb(model)
	model_height = max(0.01, aabb.size.y)
	foot_y = aabb.position.y
	var s := height / model_height
	model.scale = Vector3.ONE * s
	model.position.y = -aabb.position.y * s
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_make_fists()
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		player = found[0]
	else:
		player = AnimationPlayer.new()
		model.add_child(player)
		player.root_node = NodePath("..")
	var lib: AnimationLibrary
	if cache_key != "" and _lib_cache.has(cache_key):
		lib = _lib_cache[cache_key]
	else:
		lib = AnimationLibrary.new()
		for nm in poses:
			lib.add_animation(nm, _build(poses[nm], skel_path))
		if cache_key != "":
			_lib_cache[cache_key] = lib
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

# ---------- математика скелета (всё в пространстве скелета) ----------
func _globals(rots: Array) -> Array:
	var cnt := skel.get_bone_count()
	var gr := []
	var gp := []
	gr.resize(cnt)
	gp.resize(cnt)
	var done := []
	done.resize(cnt)
	for i in cnt:
		_g(i, rots, gr, gp, done)
	return [gr, gp]

func _g(i: int, rots: Array, gr: Array, gp: Array, done: Array) -> void:
	if done[i]:
		return
	var p := skel.get_bone_parent(i)
	if p < 0:
		gr[i] = rots[i]
		gp[i] = rest_pos[i]
	else:
		_g(p, rots, gr, gp, done)
		gr[i] = gr[p] * rots[i]
		gp[i] = gp[p] + gr[p] * rest_pos[i]
	done[i] = true

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

func dir_sk(v: Vector3) -> Vector3:
	return (skel_xf.basis.inverse() * v).normalized()

## точка в долях роста (x — влево, y — вверх от пола, z — вперёд) → пространство скелета
func pos_sk(p: Array) -> Vector3:
	var c := Vector3(p[0] * model_height, foot_y + p[1] * model_height, p[2] * model_height)
	return skel_xf.affine_inverse() * c

func _set_global(rots: Array, i: int, g: Quaternion) -> void:
	var par := skel.get_bone_parent(i)
	var pg: Quaternion = _global_rot(rots, par) if par >= 0 else Quaternion.IDENTITY
	rots[i] = (pg.inverse() * g).normalized()

# ---------- кулаки ----------
func _make_fists() -> void:
	for side in ["Right", "Left"]:
		var h := _find_bone(side + "Hand")
		if h < 0:
			continue
		var palm := dir_sk(Vector3(0, -1, 0))   # в T-позе ладони смотрят вниз
		for f in FINGERS:
			for seg in [1, 2, 3]:
				var b := _find_bone(side + "Hand" + f + str(seg))
				var nb := _find_bone(side + "Hand" + f + str(seg + 1))
				if b < 0 or nb < 0:
					continue
				var G := _globals(rest_rot)
				var fd: Vector3 = (G[1][nb] - G[1][b]).normalized()
				var ax := fd.cross(palm).normalized()
				if ax.length() < 0.5:
					continue
				var ang: float = [1.35, 1.5, 1.1][seg - 1]
				_set_global(rest_rot, b, Quaternion(ax, ang) * G[0][b])
		for seg in [1, 2]:
			var b := _find_bone(side + "HandThumb" + str(seg))
			var nb := _find_bone(side + "HandThumb" + str(seg + 1))
			if b < 0 or nb < 0:
				continue
			var G2 := _globals(rest_rot)
			var td: Vector3 = (G2[1][nb] - G2[1][b]).normalized()
			var ax2 := td.cross(palm).normalized()
			if ax2.length() > 0.5:
				_set_global(rest_rot, b, Quaternion(ax2, 0.55) * G2[0][b])
		# оси кулака в осях кисти
		var G3 := _globals(rest_rot)
		var hr: Quaternion = G3[0][h]
		var hp: Vector3 = G3[1][h]
		var i1 := _find_bone(side + "HandIndex1")
		var p1 := _find_bone(side + "HandPinky1")
		var m1 := _find_bone(side + "HandMiddle1")
		if i1 < 0 or p1 < 0 or m1 < 0:
			continue
		var k: Vector3 = hr.inverse() * (G3[1][i1] - G3[1][p1]).normalized()
		var fv: Vector3 = hr.inverse() * (G3[1][m1] - hp).normalized()
		fv = (fv - k * fv.dot(k)).normalized()
		var c := Vector3.ZERO
		var cnt := 0
		for f in FINGERS:
			for seg in [1, 2]:
				var b := _find_bone(side + "Hand" + f + str(seg))
				if b >= 0:
					c += hr.inverse() * (G3[1][b] - hp)
					cnt += 1
		hand["r" if side == "Right" else "l"] = {"k": k.normalized(), "f": fv, "grip": c / max(1, cnt)}

# ---------- позы ----------
func pose_rots(pose: Dictionary) -> Array:
	var rots := rest_rot.duplicate()
	var inv := skel_xf.basis.inverse()
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

## Рука держит рукоять: grip — точка хвата, D — куда направлено оружие от кулака (в пространстве скелета).
func _ik_arm(rots: Array, side: String, grip: Vector3, D: Vector3, sgn: float) -> void:
	var a: int = bone["rarm" if side == "r" else "larm"]
	var f: int = bone["rfa" if side == "r" else "lfa"]
	var h: int = bone["rhand" if side == "r" else "lhand"]
	if a < 0 or f < 0 or h < 0 or not hand.has(side):
		return
	var hd: Dictionary = hand[side]
	var G := _globals(rots)
	var S: Vector3 = G[1][a]
	# ориентация кисти: ось костяшек вдоль оружия, пальцы — продолжение руки
	var Dn := D.normalized() * sgn
	var away := (grip - S)
	var F := (away - Dn * away.dot(Dn))
	if F.length() < 0.001:
		F = dir_sk(Vector3(0, -1, 0))
	F = F.normalized()
	var kl: Vector3 = hd["k"]
	var fl: Vector3 = hd["f"]
	var Bl := Basis(kl, fl, kl.cross(fl)).orthonormalized()
	var Bw := Basis(Dn, F, Dn.cross(F)).orthonormalized()
	var Rh := (Bw * Bl.inverse()).get_rotation_quaternion()
	var W: Vector3 = grip - Rh * (hd["grip"] as Vector3)
	# двухзвенный IK
	var L1: float = (rest_pos[f] as Vector3).length()
	var L2: float = (rest_pos[h] as Vector3).length()
	var to := W - S
	var d: float = clamp(to.length(), 0.05, (L1 + L2) * 0.999)
	var u := to.normalized()
	var pole := dir_sk(Vector3(-1.0 if side == "r" else 1.0, -0.7, -0.35))
	var pp := (pole - u * pole.dot(u))
	if pp.length() < 0.001:
		pp = dir_sk(Vector3(0, -1, 0))
	pp = pp.normalized()
	var ca: float = clamp((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var E := S + u * (L1 * ca) + pp * (L1 * sqrt(max(0.0, 1.0 - ca * ca)))
	var Wc := S + u * d
	var Ga: Quaternion = G[0][a]
	var cur_a: Vector3 = (Ga * (rest_pos[f] as Vector3)).normalized()
	var Ga2 := Quaternion(cur_a, (E - S).normalized()) * Ga
	_set_global(rots, a, Ga2)
	var Gf := Ga2 * (rots[f] as Quaternion)
	var cur_f: Vector3 = (Gf * (rest_pos[h] as Vector3)).normalized()
	var Gf2 := Quaternion(cur_f, (Wc - E).normalized()) * Gf
	rots[f] = (Ga2.inverse() * Gf2).normalized()
	rots[h] = (Gf2.inverse() * Rh).normalized()

func _apply_ik(rots: Array, ik: Dictionary) -> void:
	if ik.has("r"):
		var r: Dictionary = ik["r"]
		var g := pos_sk(r["p"])
		var D := dir_sk(Vector3(r["d"][0], r["d"][1], r["d"][2]))
		_ik_arm(rots, "r", g, D, weapon_sign)
		if ik.has("two"):
			# вторая рука на той же рукояти, сдвиг вдоль оружия в долях роста (минус — к навершию)
			var off: float = ik["two"]
			_ik_arm(rots, "l", g + D * off * model_height / skel_xf.basis.get_scale().x, D, weapon_sign)
	if ik.has("l"):
		var l: Dictionary = ik["l"]
		_ik_arm(rots, "l", pos_sk(l["p"]), dir_sk(Vector3(l["d"][0], l["d"][1], l["d"][2])), 1.0)

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
	var hips: int = bone["hips"]
	var hp_t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hp_t, NodePath(prefix + ":" + skel.get_bone_name(hips)))
	var hips_h := (skel_xf.basis * skel.get_bone_global_rest(hips).origin).y
	var hpar := skel.get_bone_parent(hips)
	var par_basis := skel.get_bone_global_rest(hpar).basis if hpar >= 0 else Basis()
	for key in keys:
		var t: float = key[0] * dur
		var pose: Dictionary = key[1]
		var rots := pose_rots(pose)
		if key.size() > 2 and key[2] is Dictionary:
			_apply_ik(rots, key[2])
		for k in tracks:
			anim.rotation_track_insert_key(tracks[k], t, rots[bone[k]])
		var drop: float = pose.get("drop", 0.0)
		var off := par_basis.inverse() * (skel_xf.basis.inverse() * Vector3(0, -drop * hips_h, 0))
		anim.position_track_insert_key(hp_t, t, rest_pos[hips] + off)
	return anim

func play(nm: String, blend := 0.18, speed := 1.0) -> void:
	var full := "g/" + nm
	if not player.has_animation(full):
		return
	if cur == nm and player.is_playing() and player.get_animation(full).loop_mode != Animation.LOOP_NONE:
		return
	cur = nm
	player.play(full, blend, speed)

## проиграть один раз за duration секунд
func play_for(nm: String, duration: float, blend := 0.09) -> void:
	var full := "g/" + nm
	if not player.has_animation(full):
		return
	cur = nm
	var ln := player.get_animation(full).length
	player.play(full, blend, ln / max(0.05, duration))
	player.seek(0.0, true)

func clip_len(nm: String) -> float:
	var full := "g/" + nm
	return player.get_animation(full).length if player.has_animation(full) else 1.0

## Оружие в кулак. axis — ось модели оружия вдоль древка ("y" или "z"), from → to — от навершия к концу;
## grip — доля длины от from, где центр кулака; length — длина в долях роста; part — фильтр треугольников по высоте модели;
## roll — поворот вокруг древка; side — "r"/"l"; bone_key вместо кулака — крепление к кости (ножны на поясе) с dir/off.
func attach(weapon_path: String, side: String, opt: Dictionary) -> Node3D:
	var w: Node3D = (load(weapon_path) as PackedScene).instantiate()
	if opt.has("part"):
		var flt: Callable = opt["part"]
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = _filter_mesh((mi as MeshInstance3D).mesh, flt)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if opt.get("shadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var axis: String = opt.get("axis", "y")
	var from_v: float = opt.get("from", 0.0)
	var to_v: float = opt.get("to", 1.0)
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
	unit.rotation.y = opt.get("roll", 0.0)
	var piv := Node3D.new()
	piv.add_child(unit)
	var sk_scale := skel_xf.basis.get_scale().x
	piv.scale = Vector3.ONE * (float(opt.get("length", 0.4)) * model_height / sk_scale)
	var b: int
	if opt.has("bone"):
		b = bone[opt["bone"]]
		var G := _globals(rest_rot)
		var gq: Quaternion = G[0][b]
		var d: Array = opt.get("dir", [0, 1, 0])
		piv.quaternion = Quaternion(Vector3.UP, (gq.inverse() * dir_sk(Vector3(d[0], d[1], d[2]))).normalized())
		if opt.has("off"):
			var o: Array = opt["off"]
			piv.position = gq.inverse() * (skel_xf.basis.inverse() * Vector3(o[0], o[1], o[2]) * model_height)
	else:
		b = bone["rhand" if side == "r" else "lhand"]
		var hd: Dictionary = hand[side]
		var Y: Vector3 = (hd["k"] as Vector3) * weapon_sign
		# лезвие (у катаны — изгиб клинка) смотрит туда же, куда костяшки: от запястья, как при обычном хвате
		var Z: Vector3 = (hd["f"] as Vector3)
		Z = (Z - Y * Z.dot(Y)).normalized()
		piv.basis = Basis(Y.cross(Z), Y, Z).orthonormalized().scaled(piv.scale)
		piv.position = hd["grip"]
	if b < 0:
		return null
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
