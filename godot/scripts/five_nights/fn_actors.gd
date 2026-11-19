## Враги «5 НОЧЕЙ С ПАХАНОМ» на сцене: настоящие модели игры (Rig + клипы FNPoses), по одному ригу на врага —
## он переезжает между комнатами, нишами у дверей и углом офиса. На голове у каждого — свои глаза (светятся)
## и пасть, которая раскрывается в скримере. БАЛОН — маскот: высокое тело бота в грязно-белом, за спиной
## огромный балон VOZDUH, вентиль торчит над головой. MADK1D ползает (риг лицом вниз) и висит вниз головой.
## CLIPPER — с катаной. GHOST — полупрозрачный хейтер. MOD — бот в синем.
class_name FNActors
extends Node3D

var LOOK := {
	"balon": {"model": "bot", "h": 2.3, "tint": Color(0.88, 0.85, 0.78), "eye": "eye", "sep": 0.22},
	"madk1d": {"model": "madk1d", "h": 1.75, "tint": Color(0.7, 0.7, 0.72), "eye": "eye_red", "sep": 0.18},
	"bot": {"model": "bot", "h": 1.8, "tint": Color(0.55, 0.56, 0.58), "eye": "eye_red", "sep": 0.2},
	"clipper": {"model": "clipper", "h": 1.82, "tint": Color(0.5, 0.5, 0.52), "eye": "eye", "sep": 0.16},
	"ghost": {"model": "hater", "h": 1.85, "tint": Color(0.78, 0.72, 1.0), "alpha": 0.5, "emit": 0.5, "eye": "eye", "sep": 0.2},
	"mod": {"model": "bot", "h": 1.9, "tint": Color(0.45, 0.6, 1.0), "emit": 0.12, "eye": "eye_red", "sep": 0.2},
}

var office: FNOffice
var fac: FNFacility
var rigs := {}                     # id → Rig
var face := {}                     # id → {eyes, maw}
var place_key := {}                # id → где поставлен (чтобы не переставлять каждый кадр)
var t := 0.0

func build(o: FNOffice, f: FNFacility) -> void:
	office = o
	fac = f
	for id in FNData.ORDER:
		_make(id)

## Пахан-копия: строится один раз, когда понадобится (секретный двойник, конец шестой ночи)
func pahan_copy() -> Rig:
	if rigs.has("pahan"):
		return rigs["pahan"]
	var r := Rig.new()
	add_child(r)
	r.setup("res://assets/models/pahan.glb", 1.85, FNPoses.pahan_copy(), true, -1.0, "fn_pahan")
	LOOK["pahan"] = {"h": 1.85, "eye": "eye", "sep": 0.2}
	_face("pahan", r)
	rigs["pahan"] = r
	r.visible = false
	return r

func _make(id: String) -> void:
	var L: Dictionary = LOOK[id]
	var r := Rig.new()
	add_child(r)
	r.setup("res://assets/models/%s.glb" % L["model"], float(L["h"]), FNPoses.set_for(id), true, 1.0, "fn_" + id)
	_tint(r, L["tint"], float(L.get("alpha", 1.0)), float(L.get("emit", 0.0)))
	if id == "clipper":
		r.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0, "shadow": true})
	rigs[id] = r
	_face(id, r)
	if id == "balon":
		_balon_costume(r)
	r.visible = false
	r.position = Vector3(0, -60, 0)

func _tint(r: Rig, c: Color, alpha: float, emit: float) -> void:
	for mi in r.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = Color.WHITE.lerp(c, 0.55)
			mat.roughness = 0.9
			if alpha < 1.0:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mat.albedo_color.a = alpha
			if emit > 0.0:
				mat.emission_enabled = true
				mat.emission = c
				mat.emission_energy_multiplier = emit
			inst.set_surface_override_material(s, mat)

## глаза и пасть: крепятся к кости головы, место считается от позы привязки (рост головы — от кости до макушки)
func _face(id: String, r: Rig) -> void:
	var hb: int = r.bone["head"]
	if hb < 0:
		return
	var skel := r.skel
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(hb)
	skel.add_child(att)
	var rest_g: Transform3D = skel.global_transform * skel.get_bone_global_rest(hb)
	var top: float = float(LOOK[id]["h"])
	var hy: float = rest_g.origin.y - r.global_position.y
	var hs: float = maxf(0.18, top - hy)
	var center := r.global_position + Vector3(0, hy + 0.42 * hs, 0) + Vector3(0, 0, 1) * 0.42 * hs
	var anchor := Node3D.new()
	att.add_child(anchor)
	anchor.transform = rest_g.affine_inverse() * Transform3D(Basis(), center)
	var eyes := Node3D.new()
	anchor.add_child(eyes)
	var sep: float = float(LOOK[id]["sep"]) * hs
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055 * hs
		sm.height = 0.11 * hs
		e.mesh = sm
		e.material_override = office.mats[LOOK[id]["eye"]]
		e.position = Vector3(sx * sep * 0.5, 0, 0.02 * hs)
		eyes.add_child(e)
	# пасть: чёрный провал с красной глубиной и зубами; закрыта — щель (scale.y маленький)
	var maw := Node3D.new()
	maw.position = Vector3(0, -0.3 * hs, 0.0)
	anchor.add_child(maw)
	office.box(Vector3.ZERO, Vector3(0.44 * hs, 0.3 * hs, 0.06 * hs), office.mats["black"], maw)
	office.box(Vector3(0, 0, -0.02 * hs), Vector3(0.36 * hs, 0.22 * hs, 0.02 * hs), office._glow(Color(0.5, 0.0, 0.0), 1.2), maw)
	for k in 7:
		var tx := -0.18 * hs + float(k) * 0.06 * hs
		office.box(Vector3(tx, 0.13 * hs, 0.035 * hs), Vector3(0.035 * hs, 0.07 * hs, 0.02 * hs), office.mats["paper"], maw)
		office.box(Vector3(tx + 0.03 * hs, -0.13 * hs, 0.035 * hs), Vector3(0.035 * hs, 0.07 * hs, 0.02 * hs), office.mats["paper"], maw)
	maw.scale = Vector3(1, 0.08, 1)
	face[id] = {"eyes": eyes, "maw": maw, "hs": hs}

## БАЛОН: огромный балон VOZDUH за спиной, вентиль над головой, надпись на груди
func _balon_costume(r: Rig) -> void:
	var sb: int = r.bone["spine2"] if r.bone["spine2"] >= 0 else r.bone["spine"]
	var att := BoneAttachment3D.new()
	att.bone_name = r.skel.get_bone_name(sb)
	r.skel.add_child(att)
	var rest_g: Transform3D = r.skel.global_transform * r.skel.get_bone_global_rest(sb)
	var holder := Node3D.new()
	att.add_child(holder)
	var back := r.global_position + Vector3(0, rest_g.origin.y - r.global_position.y + 0.25, -0.32)
	holder.transform = rest_g.affine_inverse() * Transform3D(Basis(), back)
	var ps := load("res://assets/models/balon.glb") as PackedScene
	if ps != null:
		var b := ps.instantiate() as Node3D
		holder.add_child(b)
		# в файле балон лежит вдоль Y примерно на 0.98 единицы — растягиваем до 1.5 м
		b.scale = Vector3.ONE * 1.5
		b.position = Vector3(0, -0.55, 0)
	var chest := r.global_position + Vector3(0, rest_g.origin.y - r.global_position.y - 0.05, 0.42)
	var lab := Label3D.new()
	lab.text = "VOZDUH"
	lab.font = office.font
	lab.font_size = 80
	lab.pixel_size = 0.0014
	lab.modulate = Color(0.75, 0.04, 0.04)
	holder.get_parent().add_child(lab)
	lab.transform = rest_g.affine_inverse() * Transform3D(Basis(), chest)

# ---------------- каждый кадр: где стоит и что делает ----------------
func tick(st: FNNight, dt: float) -> void:
	t += dt
	if rigs.has("pahan"):
		(rigs["pahan"] as Rig).visible = false
	for id in FNData.ORDER:
		var e: FNEnemy = st.enemies[id]
		var r: Rig = rigs[id]
		if e.level <= 0 and id != "balon":
			r.visible = false
			continue
		var key := "%s|%d|%s" % [e.spot, e.pose, str(e.look)]
		if id == "ghost":
			key += "|" + str((e as FNGhost).flicker)
		if place_key.get(id, "") != key:
			place_key[id] = key
			_place(id, e, r)
		# мерцание глаз; у GHOST — растёт с одержимостью
		var f: Dictionary = face.get(id, {})
		if not f.is_empty():
			(f["eyes"] as Node3D).visible = not (id == "balon" and fposmod(t + 0.7, 6.3) < 0.12)
	if st.power_out:
		for id in FNData.ORDER:
			if (st.enemies[id] as FNEnemy).spot in ["door_l", "door_r"]:
				(rigs[id] as Rig).visible = false

func _place(id: String, e: FNEnemy, r: Rig) -> void:
	var sp: String = e.spot
	r.rotation = Vector3.ZERO
	r.visible = true
	var cam_p := Vector3.ZERO
	match sp:
		"away", "duct_l", "duct_t", "office", "vent_t":
			r.visible = false
			return
		"door_l", "door_r":
			var p := FNOffice.point(sp)
			r.position = p
			r.rotation.y = PI / 2 if sp == "door_l" else -PI / 2
			r.play("FNPeek" if e.pose != 1 else "FNStill", 0.0)
			return
		"vent_l":
			# лицо за решёткой: лежит в шахте головой к решётке
			r.position = Vector3(-1.62, 0.05, -2.75)
			r.rotation = Vector3(deg_to_rad(80.0), 0, 0)
			r.play("FNCrawl", 0.0, 0.0)
			return
		"corner":
			r.position = FNOffice.point("corner")
			r.rotation.y = deg_to_rad(150.0)
			r.play("FNStill", 0.0)
			return
		"vent":
			var xf := fac.spot("vent", 0)
			r.global_transform = xf
			r.rotation.x = deg_to_rad(80.0)
			r.position.y = 0.25
			r.play("FNCrawl", 0.0, 0.6)
			return
	var room := sp
	if id == "ghost":
		room = "ghost_" + sp if fac.spots.has("ghost_" + sp) else sp
	var xf2 := fac.spot(room, e.pose)
	r.global_transform = xf2
	cam_p = (fac.cams.get(sp, {}) as Dictionary).get("pos", r.position + Vector3(0, 0, 3))
	if e.look:
		var to := cam_p - r.global_position
		r.rotation.y = atan2(to.x, to.z)
		r.play("FNStare", 0.0)
	elif sp in ["hall_l", "hall_r"]:
		r.rotation.y = 0.0 if sp.ends_with("l") else 0.0
		r.play("FNWalk", 0.0, 0.18)                 # застыл посреди шага
	else:
		r.play("FNStill" if e.pose != 2 else "Idle", 0.0)

## пасть: 0 — закрыта, 1 — раскрыта
func maw(id: String, k: float) -> void:
	var f: Dictionary = face.get(id, {})
	if f.is_empty():
		return
	(f["maw"] as Node3D).scale = Vector3(1.0 + k * 0.25, lerpf(0.08, 1.15, k), 1.0)

func hide_all() -> void:
	for id in rigs:
		(rigs[id] as Rig).visible = false
	place_key.clear()

## маскот БАЛОН для превью в меню режимов (без будки): тот же риг, тон, балон за спиной и светящиеся глаза
static func preview_balon(parent: Node) -> Rig:
	var r := Rig.new()
	parent.add_child(r)
	r.setup("res://assets/models/bot.glb", 2.3, FNPoses.balon(), false, 1.0, "fn_balon")
	for mi in r.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s)
			if src is StandardMaterial3D:
				var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_color = Color.WHITE.lerp(Color(0.88, 0.85, 0.78), 0.55)
				inst.set_surface_override_material(s, mat)
	var sb: int = r.bone["spine2"] if r.bone["spine2"] >= 0 else r.bone["spine"]
	var att := BoneAttachment3D.new()
	att.bone_name = r.skel.get_bone_name(sb)
	r.skel.add_child(att)
	var rest_g: Transform3D = r.skel.global_transform * r.skel.get_bone_global_rest(sb)
	var holder := Node3D.new()
	att.add_child(holder)
	holder.transform = rest_g.affine_inverse() * Transform3D(Basis(), r.global_position + Vector3(0, rest_g.origin.y - r.global_position.y + 0.25, -0.32))
	var ps := load("res://assets/models/balon.glb") as PackedScene
	if ps != null:
		var b := ps.instantiate() as Node3D
		holder.add_child(b)
		b.scale = Vector3.ONE * 1.5
		b.position = Vector3(0, -0.55, 0)
	var hb: int = r.bone["head"]
	if hb >= 0:
		var ha := BoneAttachment3D.new()
		ha.bone_name = r.skel.get_bone_name(hb)
		r.skel.add_child(ha)
		var hg: Transform3D = r.skel.global_transform * r.skel.get_bone_global_rest(hb)
		var hs: float = maxf(0.18, 2.3 - (hg.origin.y - r.global_position.y))
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(1.0, 0.95, 0.9)
		em.emission_enabled = true
		em.emission = Color(1.0, 0.95, 0.9)
		em.emission_energy_multiplier = 6.0
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for sx in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.055 * hs
			sm.height = 0.11 * hs
			e.mesh = sm
			e.material_override = em
			ha.add_child(e)
			e.transform = hg.affine_inverse() * Transform3D(Basis(), r.global_position + Vector3(sx * 0.11 * hs, hg.origin.y - r.global_position.y + 0.42 * hs, 0.44 * hs))
	r.play("FNStare", 0.0)
	return r
