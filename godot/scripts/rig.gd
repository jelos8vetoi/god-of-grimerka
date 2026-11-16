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
var par := PackedInt32Array()   # родитель каждой кости
var foot_pts := []         # [кость стопы или носка, её высота в позе привязки] — чтобы ставить на пол
var weapon: Node3D         # оружие в кулаке: ось +Y, от -weapon_grip до 1-weapon_grip
var weapon_bone := -1
var weapon_grip := 0.0
var flash_mat: StandardMaterial3D
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
		par.append(skel.get_bone_parent(i))
	for k in BONES:
		bone[k] = _find_bone(BONES[k])
	var aabb := _skinned_aabb(path)
	model_height = max(0.01, aabb.size.y)
	foot_y = aabb.position.y
	var s := height / model_height
	model.scale = Vector3.ONE * s
	model.position.y = -aabb.position.y * s
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_make_fists()
	for nm in ["RightFoot", "LeftFoot", "RightToeBase", "LeftToeBase"]:
		var fb := _find_bone(nm)
		if fb >= 0:
			foot_pts.append([fb, (skel_xf * (_chain(rest_rot, fb)[1] as Vector3)).y])
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

static var _box_cache := {}

## Габариты персонажа в позе привязки с учётом скелета (в пространстве модели).
## Нельзя брать AABB самой сетки: у части моделей она в файле лежит на боку, и на ноги её ставит только скелет.
func _skinned_aabb(key: String) -> AABB:
	if _box_cache.has(key):
		return _box_cache[key]
	var box := AABB()
	var first := true
	var grest := []
	for i in skel.get_bone_count():
		grest.append(skel.get_bone_global_rest(i))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var skin := inst.skin
		if skin == null or inst.mesh == null:
			continue
		var mats := []
		for b in skin.get_bind_count():
			var bi := skin.get_bind_bone(b)
			if bi < 0:
				bi = skel.find_bone(skin.get_bind_name(b))
			mats.append((grest[bi] as Transform3D) * skin.get_bind_pose(b) if bi >= 0 else Transform3D())
		for s in inst.mesh.get_surface_count():
			var arr := inst.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or ws == null or vs.size() == 0:
				continue
			var per: int = bones.size() / vs.size()
			var stride: int = max(1, vs.size() / 6000)
			for v in range(0, vs.size(), stride):
				var p := Vector3.ZERO
				var wsum := 0.0
				for j in per:
					var w: float = ws[v * per + j]
					if w > 0.0:
						p += ((mats[bones[v * per + j]] as Transform3D) * vs[v]) * w
						wsum += w
				if wsum <= 0.0:
					continue
				p = skel_xf * (p / wsum)
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	if first:
		box = _mesh_aabb(model)
	_box_cache[key] = box
	return box

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

## поворот и положение кости в пространстве скелета — только по цепочке её предков
func _chain(rots: Array, i: int) -> Array:
	var st := []
	var j := i
	while j >= 0:
		st.append(j)
		j = par[j]
	var q := Quaternion.IDENTITY
	var p := Vector3.ZERO
	for n in range(st.size() - 1, -1, -1):
		var b: int = st[n]
		p += q * (rest_pos[b] as Vector3)
		q = q * (rots[b] as Quaternion)
	return [q, p]

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
	var C := _chain(rots, a)
	var S: Vector3 = C[1]
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
	var Ga: Quaternion = C[0]
	var Gpar: Quaternion = Ga * (rots[a] as Quaternion).inverse()
	var cur_a: Vector3 = (Ga * (rest_pos[f] as Vector3)).normalized()
	var Ga2 := Quaternion(cur_a, (E - S).normalized()) * Ga
	rots[a] = (Gpar.inverse() * Ga2).normalized()
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

## Как подходим к ключу: "in" — с разгоном (удар), "out" — с торможением (замах, довод), "io" — плавно,
## "back" — с перелётом и возвратом, "hold" — почти стоим и срываемся в конце, иначе — равномерно.
static func ease_fn(u: float, e: String) -> float:
	match e:
		"in":
			return u * u * u
		"in2":
			return u * u
		"out":
			var v := 1.0 - u
			return 1.0 - v * v * v
		"out2":
			var v2 := 1.0 - u
			return 1.0 - v2 * v2
		"io":
			return u * u * (3.0 - 2.0 * u)
		"back":
			var w := u - 1.0
			return 1.0 + 2.70158 * w * w * w + 1.70158 * w * w
		"hold":
			return pow(u, 5.0)
	return u

static func _cr(p0: Array, p1: Array, p2: Array, p3: Array, t: float) -> Array:
	var r := []
	var t2 := t * t
	var t3 := t2 * t
	for i in 3:
		r.append(0.5 * (2.0 * p1[i] + (p2[i] - p0[i]) * t + (2.0 * p0[i] - 5.0 * p1[i] + 4.0 * p2[i] - p3[i]) * t2 + (3.0 * p1[i] - p0[i] - 3.0 * p2[i] + p3[i]) * t3))
	return r

static func _dir_mix(a: Array, b: Array, w: float) -> Array:
	var va := Vector3(a[0], a[1], a[2]).normalized()
	var vb := Vector3(b[0], b[1], b[2]).normalized()
	var r := va.slerp(vb, w)
	return [r.x, r.y, r.z]

## хват одной руки между ключами i и i+1: [словарь хвата или null, вес IK]
func _ik_side(K: Array, i: int, side: String, w: float) -> Array:
	var ia = K[i]["ik"]
	var ib = K[i + 1]["ik"]
	var ha: bool = ia != null and ia.has(side)
	var hb: bool = ib != null and ib.has(side)
	if ha and hb:
		var p1: Array = ia[side]["p"]
		var p2: Array = ib[side]["p"]
		var p0 := p1
		var p3 := p2
		if i > 0 and K[i - 1]["ik"] != null and K[i - 1]["ik"].has(side):
			p0 = K[i - 1]["ik"][side]["p"]
		if i + 2 < K.size() and K[i + 2]["ik"] != null and K[i + 2]["ik"].has(side):
			p3 = K[i + 2]["ik"][side]["p"]
		return [{"p": _cr(p0, p1, p2, p3, w), "d": _dir_mix(ia[side]["d"], ib[side]["d"], w)}, 1.0]
	if ha:
		return [ia[side], 1.0 - w]
	if hb:
		return [ib[side], w]
	return [null, 0.0]

## Поза в момент u (0..1) между ключами: кости — по сфере, хват оружия — по плавной кривой через ключи,
## направление оружия — по дуге. Возвращает [повороты костей, смещение таза по высоте в единицах модели].
func _sample(K: Array, u: float, ground: bool, hips_h: float) -> Array:
	var i := 0
	while i < K.size() - 2 and u > float(K[i + 1]["t"]):
		i += 1
	var a: Dictionary = K[i]
	var b: Dictionary = K[i + 1]
	var span: float = max(0.00001, float(b["t"]) - float(a["t"]))
	var w := ease_fn(clampf((u - float(a["t"])) / span, 0.0, 1.0), String(b["e"]))
	var ra: Array = a["rots"]
	var rb: Array = b["rots"]
	var rots := rest_rot.duplicate()
	for k in ORDER:
		var bi: int = bone[k]
		if bi >= 0:
			rots[bi] = (ra[bi] as Quaternion).slerp(rb[bi], w)
	var ia = a["ik"]
	var ib = b["ik"]
	if ia != null or ib != null:
		var base := rots.duplicate()
		var ik := {}
		var wc := clampf(w, 0.0, 1.0)
		var R := _ik_side(K, i, "r", w)
		var wr: float = R[1]
		if R[0] != null:
			ik["r"] = R[0]
		var wl := 0.0
		var ta: bool = ia != null and ia.has("two")
		var tb: bool = ib != null and ib.has("two")
		if ta and tb:
			ik["two"] = lerpf(ia["two"], ib["two"], w)
			wl = 1.0
		elif ta:
			ik["two"] = ia["two"]
			wl = 1.0 - wc
		elif tb:
			ik["two"] = ib["two"]
			wl = wc
		else:
			var Lk := _ik_side(K, i, "l", w)
			if Lk[0] != null:
				ik["l"] = Lk[0]
				wl = clampf(Lk[1], 0.0, 1.0)
		_apply_ik(rots, ik)
		wr = clampf(wr, 0.0, 1.0)
		if wr < 1.0:
			for k in ["rarm", "rfa", "rhand"]:
				var bi: int = bone[k]
				rots[bi] = (base[bi] as Quaternion).slerp(rots[bi], wr)
		if wl < 1.0:
			for k in ["larm", "lfa", "lhand"]:
				var bi: int = bone[k]
				rots[bi] = (base[bi] as Quaternion).slerp(rots[bi], wl)
	var dy := 0.0
	if ground and foot_pts.size() > 0:
		# таз ставим так, чтобы нижняя стопа стояла на полу: приседы и выпады не висят и не тонут
		var low := INF
		for fp in foot_pts:
			var gp: Vector3 = _chain(rots, fp[0])[1]
			low = min(low, (skel_xf * gp).y - float(fp[1]))
		dy = -low + lerpf(a["lift"], b["lift"], w) * hips_h
	else:
		dy = -lerpf(a["drop"], b["drop"], w) * hips_h
	return [rots, dy]

func _build(def: Dictionary, prefix: String) -> Animation:
	var anim := Animation.new()
	var dur: float = def.get("d", 1.0)
	anim.length = dur
	anim.loop_mode = Animation.LOOP_LINEAR if def.get("loop", false) else Animation.LOOP_NONE
	var keys: Array = def["k"]
	var tracks := {}
	var smooth: bool = def.get("smooth", false)
	for k in ORDER:
		if bone[k] < 0:
			continue
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		if smooth:
			anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		anim.track_set_path(t, NodePath(prefix + ":" + skel.get_bone_name(bone[k])))
		tracks[k] = t
	var hips: int = bone["hips"]
	var hp_t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hp_t, NodePath(prefix + ":" + skel.get_bone_name(hips)))
	if smooth:
		anim.track_set_interpolation_type(hp_t, Animation.INTERPOLATION_CUBIC)
	var hips_h := (skel_xf.basis * skel.get_bone_global_rest(hips).origin).y
	var hpar := skel.get_bone_parent(hips)
	var par_basis := skel.get_bone_global_rest(hpar).basis if hpar >= 0 else Basis()
	var to_hips := par_basis.inverse() * skel_xf.basis.inverse()
	# ключи: [время, поза, хват оружия (словарь), плавность подхода (строка)]
	var K := []
	var de: String = def.get("ease", "lin")
	for key in keys:
		var ik = null
		var e := de
		for j in range(2, key.size()):
			if key[j] is Dictionary:
				ik = key[j]
			elif key[j] is String:
				e = key[j]
		var pose: Dictionary = key[1]
		K.append({"t": float(key[0]), "rots": pose_rots(pose), "ik": ik, "e": e, "drop": float(pose.get("drop", 0.0)), "lift": float(pose.get("lift", 0.0))})
	if smooth:
		# циклы шага: ключ в ключ, сглаживает сам движок
		for kk in K:
			var rk: Array = (kk["rots"] as Array).duplicate()
			if kk["ik"] != null:
				_apply_ik(rk, kk["ik"])
			for k in tracks:
				anim.rotation_track_insert_key(tracks[k], float(kk["t"]) * dur, rk[bone[k]])
			anim.position_track_insert_key(hp_t, float(kk["t"]) * dur, rest_pos[hips] + to_hips * Vector3(0, -float(kk["drop"]) * hips_h, 0))
		return anim
	# остальное запекаем по кадрам: у каждого ключа своя плавность, оружие идёт по дуге, а не по прямой
	var ground: bool = def.get("ground", false)
	var n: int = def.get("n", clampi((K.size() - 1) * 8, 16, 48))
	for s in n + 1:
		var u := float(s) / n
		var smp := _sample(K, u, ground, hips_h)
		var rots: Array = smp[0]
		for k in tracks:
			anim.rotation_track_insert_key(tracks[k], u * dur, rots[bone[k]])
		anim.position_track_insert_key(hp_t, u * dur, rest_pos[hips] + to_hips * Vector3(0, float(smp[1]), 0))
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
		weapon = piv
		weapon_bone = b
		weapon_grip = float(opt.get("grip", 0.0))
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

## концы оружия в мире сейчас: [у кулака, дальний конец]; считаем по кости, не дожидаясь обновления крепления
func weapon_points(from := 0.18, to := 1.0) -> Array:
	if weapon == null or weapon_bone < 0:
		return []
	var xf := skel.global_transform * skel.get_bone_global_pose(weapon_bone) * weapon.transform
	return [xf * Vector3(0, from - weapon_grip, 0), xf * Vector3(0, to - weapon_grip, 0)]

## вспышка по всей модели при попадании: 0 — нет, 1 — полностью
func flash(a: float, col := Color.WHITE) -> void:
	if flash_mat == null:
		if a <= 0.0:
			return
		flash_mat = StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = flash_mat
	flash_mat.albedo_color = Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0))
