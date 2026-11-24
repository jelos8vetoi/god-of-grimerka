## Враги «5 НОЧЕЙ С ПАХАНОМ» на сцене: настоящие модели игры (Rig + клипы FNPoses), по одному ригу на врага —
## он переезжает между комнатами, нишами у дверей и углом офиса. На голове у каждого — свои глаза (светятся)
## и пасть, которая раскрывается в скримере. БАЛОН — маскот: высокое тело бота в грязно-белом, за спиной
## огромный балон VOZDUH, вентиль торчит над головой. MADK1D ползает (риг лицом вниз) и висит вниз головой.
## CLIPPER — с катаной. GHOST — полупрозрачный хейтер. MOD — бот в синем.
class_name FNActors
extends Node3D

enum Appearance { ORIGINAL, PATROL, DOOR }

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
var visual_bindings := {}
var appearance_by_id := {}
var face := {}                     # id → {eyes, maw}
var place_key := {}                # id → где поставлен (чтобы не переставлять каждый кадр)
var t := 0.0
var mode := {}                     # id → "approach" / "retreat" / "" — что делает в коридоре
var creep := {}                    # id → на сколько подполз к офису, пока стоит в коридоре (м)
var stare := {}                    # id → точка, к которой медленно поворачивается (аномалия «stare»)
var dart := {}                     # id → [время до следующего движения глаз, сколько ещё смотрят вбок]
var lunge_t := {}                  # id → у двери играет FNLunge (вот-вот войдёт)
const HORROR_DIR := "res://assets/minigames/fn_horror_%s.glb"   # модель владельца с костями Mixamo — встанет вместо обычной
## Модели владельца (скелет им ставит tools/rig-horror.py): рост в метрах и лицо. Точки лица — в единицах модели
## (1 = рост, начало — центр основания, +Z — лицо): eye — середина между глазами, sep — расстояние между ними,
## r — радиус светящегося зрачка, maw — центр пасти, ms — её ширина. Светящиеся глаза и пасть скримера садятся
## на настоящее лицо модели (экран BOT, линза CLIPPER, глазницы GHOST).
const OWN := {
	"balon": {"h": 2.0, "eye": Vector3(0.013, 0.586, 0.17), "sep": 0.145, "r": 0.018, "maw": Vector3(0.013, 0.49, 0.18), "ms": 0.13},
	"madk1d": {"h": 1.62, "eye": Vector3(-0.004, 0.66, 0.175), "sep": 0.18, "r": 0.02, "maw": Vector3(0.0, 0.535, 0.2), "ms": 0.13},
	"bot": {"h": 1.85, "eye": Vector3(-0.02, 0.672, 0.16), "sep": 0.117, "r": 0.016, "maw": Vector3(-0.02, 0.6, 0.165), "ms": 0.1},
	"clipper": {"h": 1.75, "eye": Vector3(0.0, 0.867, 0.275), "sep": 0.0, "r": 0.034, "maw": Vector3(0.0, 0.79, 0.265), "ms": 0.07},
	"ghost": {"h": 1.85, "eye": Vector3(0.0, 0.81, 0.11), "sep": 0.088, "r": 0.012, "maw": Vector3(0.0, 0.745, 0.125), "ms": 0.075, "alpha": 0.72, "emit": 0.18},
	"mod": {"h": 1.7, "eye": Vector3(0.059, 0.578, 0.315), "sep": 0.258, "r": 0.028, "maw": Vector3(0.0625, 0.5, 0.3), "ms": 0.11},
}
var owned := {}                    # id → true: у врага модель владельца
var model_home := {}               # id → обычное место модели в риге (в скримере FNScare подводит лицо к камере)

## глаза: цвет, энергия свечения (в тёмном проёме — влажный блик от настоящего света, не фонари)
const EYE := {
	"balon": [Color(1.0, 0.9, 0.78), 0.35], "madk1d": [Color(1.0, 0.12, 0.08), 0.8], "bot": [Color(1.0, 0.1, 0.06), 1.2],
	"clipper": [Color(0.75, 0.9, 1.0), 0.5], "ghost": [Color(0.8, 0.85, 1.0), 0.25], "mod": [Color(1.0, 0.15, 0.1), 0.8],
}
# Внешние точки рига в нише (глубина по X, высота, мировой Z).
# Запас до полотна и стен измерен по мешам FNStill, FNPeekL/R и FNLungeL/R.
# FNOffice.point остаётся точкой игровых звуков и событий.
const DOOR_STANDS := {
	"balon": Vector3(3.04, 0.006, -0.23),
	"madk1d": Vector3(3.09, 0.006, -0.29),
	"bot": Vector3(2.98, 0.006, -0.29),
	"clipper": Vector3(3.34, 0.254, -0.13),
	"ghost": Vector3(3.07, 0.006, -0.28),
	"mod": Vector3(3.38, 0.008, -0.22),
}
# От посадочной метки БАЛОНА. Места не меняют комнату или игровой вариант позы.
const STAGE_STANDS := {
	"balon": Vector3.ZERO,
	"clipper": Vector3(-2.52, 0.145, -0.76),
	"bot": Vector3(1.37, 0.0, -0.82),
	"mod": Vector3(2.30, 0.0, 0.61),
	"madk1d": Vector3(-1.72, 0.0, 0.70),
	"ghost": Vector3(-1.18, 0.0, -0.91),
}
const BOT_TRAVEL := 0.48
const BOT_TRAVEL_TIME := 1.20
# Множители альбедо и ИК-подсветки для обычного наблюдения.
const PATROL_DEFAULT := Vector2(0.82, 0.48)
const PATROL_MATERIALS := {
	"mod": Vector2(0.58, 0.20),
	"madk1d": Vector2(0.66, 0.28),
}
const IR_SHADER := preload("res://scenes/five_nights/materials/fn_ir_pass.gdshader")
const DOOR_LAYER := 2               # слой рендера врага, пока он стоит у двери: лампы будки его не освещают, только фонарь
var layer_state := {}              # id → стоит ли у двери (слой и глаза уже переключены)
var eye_mats := {}                 # id → материал глаз (в скримере сила растёт, потом возвращается)

## глобальная переменная инфракрасной подсветки камер: регистрируется до первого материала врага
static var _ir_added := false

static func ensure_ir() -> void:
	if _ir_added:
		return
	_ir_added = true
	RenderingServer.global_shader_parameter_add("fn_ir", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, -999, 0, 0))

static func ir_pass(tex: Texture2D, gain := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = IR_SHADER
	if tex != null:
		m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("gain", gain)
	return m

func build(o: FNOffice, f: FNFacility) -> void:
	ensure_ir()
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
	var own := ResourceLoader.exists(HORROR_DIR % id) and OWN.has(id)
	r.setup(HORROR_DIR % id if own else "res://assets/models/%s.glb" % L["model"], float(OWN[id]["h"]) if own else float(L["h"]), FNPoses.set_for(id), true, 1.0, "fn_" + id)
	if own:
		owned[id] = true
		_own_look(r, float(OWN[id].get("alpha", 1.0)), float(OWN[id].get("emit", 0.0)))
		model_home[id] = r.model.position
	else:
		_tint(r, L["tint"], float(L.get("alpha", 1.0)), float(L.get("emit", 0.0)))
	if id == "clipper" and not own:                       # у своей модели лезвия — часть руки
		r.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0, "shadow": true})
	rigs[id] = r
	_face(id, r)
	if id == "balon" and not own:
		_balon_costume(r)
	if own:
		(face[id]["maw"] as Node3D).visible = false       # у своей модели пасть появляется только в скримере
	if not own:
		_horror(id, r)
	r.visible = false
	r.position = Vector3(0, -60, 0)

## модель владельца: свои текстуры без перекраски, без самосвечения — их освещает только настоящий свет; камеры видят
## врага в инфракрасной подсветке (next_pass fn_ir_pass); GHOST — ещё и полупрозрачный
func _own_look(r: Rig, alpha: float, _emit: float) -> void:
	for mi in r.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as BaseMaterial3D
			mat.next_pass = ir_pass(mat.albedo_texture)
			if alpha < 1.0:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mat.albedo_color.a = alpha
			inst.set_surface_override_material(s, mat)

func _tint(r: Rig, c: Color, alpha: float, _emit: float) -> void:
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
			mat.next_pass = ir_pass(mat.albedo_texture)
			inst.set_surface_override_material(s, mat)

func _eye_mat(id: String) -> StandardMaterial3D:
	if eye_mats.has(id):
		return eye_mats[id]
	var spec: Array = EYE.get(id, [Color(1, 0.9, 0.8), 0.35])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.roughness = 0.08
	m.metallic_specular = 1.0
	m.emission_enabled = true
	m.emission = spec[0]
	m.emission_energy_multiplier = float(spec[1])
	m.set_meta("base_energy", float(spec[1]))
	m.next_pass = ir_pass(null, 4.0)
	eye_mats[id] = m
	return m

## все меши врага на слой mask
func _set_layer(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for c in n.get_children():
		_set_layer(c, mask)

## у двери враг на своём слое, а глаза горят ровно настолько, насколько светит фонарь этой стороны
func _door_look(id: String, e: FNEnemy, r: Rig) -> void:
	var at_door: bool = e.spot in ["door_l", "door_r"] and not e.entered and e.level > 0
	var was: bool = bool(layer_state.get(id, false))
	if at_door:
		var beam: SpotLight3D = office.lights["l" if e.spot == "door_l" else "r"]
		var k := clampf(beam.light_energy / 2.6, 0.0, 1.0)
		if not was:
			layer_state[id] = true
			_set_layer(r, DOOR_LAYER)
		eyes_boost(id, k)
	elif was:
		layer_state[id] = false
		_set_layer(r, 1)
		if not e.entered:
			eyes_boost(id, 1.0)

## в скримере глаза горят втрое сильнее; потом возвращаются
func eyes_boost(id: String, k: float) -> void:
	if eye_mats.has(id):
		var m: StandardMaterial3D = eye_mats[id]
		m.emission_energy_multiplier = float(m.get_meta("base_energy")) * k

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
	var sep: float = float(LOOK[id]["sep"]) * hs
	var eye_r := 0.055 * hs * 0.6
	var eye_z := 0.02 * hs
	var maw_at := Vector3(0, -0.3 * hs, 0.0)
	if owned.has(id):
		# лицо своей модели: точки заданы на самой модели (OWN), пересчитываются в мир через её узел
		var O: Dictionary = OWN[id]
		var mx: Transform3D = r.model.global_transform
		var u: float = mx.basis.get_scale().y
		center = mx * (O["eye"] as Vector3)
		sep = float(O["sep"]) * u
		eye_r = float(O["r"]) * u * 0.6
		eye_z = 0.0
		hs = float(O["ms"]) * u / 0.44                    # пасть шириной ms: её детали заданы в долях hs
		maw_at = mx * (O["maw"] as Vector3) - center
	var anchor := Node3D.new()
	att.add_child(anchor)
	anchor.transform = rest_g.affine_inverse() * Transform3D(Basis(), center)
	var eyes := Node3D.new()
	anchor.add_child(eyes)
	for sx in ([-1.0, 1.0] if sep > 0.0 else [0.0]):
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = eye_r
		sm.height = eye_r * 2.0
		e.mesh = sm
		e.material_override = _eye_mat(id)
		e.position = Vector3(sx * sep * 0.5, 0, eye_z)
		eyes.add_child(e)
	# пасть: чёрный провал с красной глубиной и зубами; закрыта — щель (scale.y маленький)
	var maw_n := Node3D.new()
	maw_n.position = maw_at
	anchor.add_child(maw_n)
	office.box(Vector3.ZERO, Vector3(0.44 * hs, 0.3 * hs, 0.06 * hs), office._glow(Color(0.015, 0.0, 0.0), 1.0), maw_n)
	office.box(Vector3(0, 0, -0.02 * hs), Vector3(0.36 * hs, 0.22 * hs, 0.02 * hs), office._glow(Color(0.10, 0.0, 0.0), 0.25), maw_n)
	var tooth := StandardMaterial3D.new()
	tooth.albedo_color = Color(0.62, 0.56, 0.44)
	tooth.roughness = 0.55
	for k in 7:
		var tx := -0.18 * hs + float(k) * 0.06 * hs
		var th := (0.045 + 0.03 * fposmod(float(k) * 0.618, 1.0)) * hs
		var tz := deg_to_rad(8.0 * sin(float(k) * 2.1))
		office.box(Vector3(tx, 0.15 * hs - th * 0.5, 0.035 * hs), Vector3(0.026 * hs, th, 0.02 * hs), tooth, maw_n, Vector3(0, 0, tz))
		var bh := (0.045 + 0.03 * fposmod(float(k) * 0.618 + 0.4, 1.0)) * hs
		office.box(Vector3(tx + 0.03 * hs, -0.15 * hs + bh * 0.5, 0.035 * hs), Vector3(0.026 * hs, bh, 0.02 * hs), tooth, maw_n, Vector3(0, 0, -tz))
	maw_n.scale = Vector3(1, 0.08, 1)
	face[id] = {"eyes": eyes, "maw": maw_n, "hs": hs}

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
func tick(st: FNNight, dt: float, patrol_look := true) -> void:
	t += dt
	if rigs.has("pahan"):
		(rigs["pahan"] as Rig).visible = false
	for id in FNData.ORDER:
		var e: FNEnemy = st.enemies[id]
		var r: Rig = rigs[id]
		if e.level <= 0 and id != "balon":
			_set_appearance(id, r, Appearance.ORIGINAL)
			r.visible = false
			continue
		var appearance := Appearance.ORIGINAL
		if e.spot in ["door_l", "door_r"] and not e.entered:
			appearance = Appearance.DOOR
		elif patrol_look and (fac.cams.has(e.spot) or e.spot == "corner"):
			appearance = Appearance.PATROL
		_set_appearance(id, r, appearance)
		var key := "%s|%d|%s" % [e.spot, e.pose, str(e.look)]
		if id == "ghost":
			key += "|" + str((e as FNGhost).flicker)
		if place_key.get(id, "") != key:
			place_key[id] = key
			stare.erase(id)
			_place(id, e, r, patrol_look)
		_live(id, e, r, dt)
		_door_look(id, e, r)
		# мерцание глаз; у GHOST — растёт с одержимостью
		var f: Dictionary = face.get(id, {})
		if not f.is_empty():
			(f["eyes"] as Node3D).visible = not (id == "balon" and fposmod(t + 0.7, 6.3) < 0.12)
	if st.power_out:
		for id in FNData.ORDER:
			if (st.enemies[id] as FNEnemy).spot in ["door_l", "door_r"]:
				(rigs[id] as Rig).visible = false

## клип у двери своей стороны: левая нишa — FNPeekL / FNLungeL, правая — зеркальные R
func _door_clip(sp: String, base: String) -> String:
	return base + ("L" if sp == "door_l" else "R")

func _place(id: String, e: FNEnemy, r: Rig, spread_stage := true) -> void:
	var sp: String = e.spot
	var bot_arrival := false
	if id == "bot":
		bot_arrival = r.get_meta("bot_room", "") != sp and not e.prev.is_empty()
		r.set_meta("bot_room", sp)
		mode.erase(id)
	r.rotation = Vector3.ZERO
	r.visible = true
	var cam_p := Vector3.ZERO
	match sp:
		"away", "duct_l", "duct_t", "office", "vent_t":
			r.visible = false
			return
		"door_l", "door_r":
			var side := -1.0 if sp == "door_l" else 1.0
			r.position = (DOOR_STANDS[id] as Vector3) * Vector3(side, 1, 1)
			r.rotation.y = -side * PI * 0.5
			lunge_t[id] = false
			r.play(_door_clip(sp, "FNPeek") if e.pose != 1 else "FNStill", 0.0)
			return
		"vent_l":
			# лицо за решёткой: лежит в шахте головой к решётке
			r.position = Vector3(-1.62, 0.05, -3.19)
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
	if sp == "stage" and spread_stage:
		xf2 = fac.spot("stage", 0)
		xf2.origin += STAGE_STANDS.get(id, Vector3.ZERO) as Vector3
	r.global_transform = xf2
	cam_p = (fac.cams.get(sp, {}) as Dictionary).get("pos", r.position + Vector3(0, 0, 3))
	if e.look:
		var to := cam_p - r.global_position
		r.rotation.y = atan2(to.x, to.z)
		r.play("FNStare", 0.0)
	elif sp in ["hall_l", "hall_r"]:
		r.rotation.y = 0.0
		if id == "bot":
			if bot_arrival:
				mode[id] = "retreat" if e.prev == "door_r" else "approach"
				creep[id] = 0.0
				r.set_meta("hall_z", r.position.z)
				r.position.z += BOT_TRAVEL if mode[id] == "retreat" else -BOT_TRAVEL
				r.play("FNRetreat" if mode[id] == "retreat" else "FNWalk", 0.0)
			else:
				r.play("FNStill", 0.0)
			return
		# пришёл от двери — пятится, не сводя глаз; идёт к офису — приближается рывками и сам подползает ближе
		mode[id] = "retreat" if e.prev in ["door_l", "door_r"] else "approach"
		creep[id] = 0.0
		r.set_meta("hall_z", r.position.z)
		r.play("FNRetreat" if mode[id] == "retreat" else ("FNApproach" if id != "clipper" else "FNWalk"), 0.0, 1.0 if id != "clipper" else 0.18)
	else:
		r.play("FNStill" if id == "bot" or (sp == "stage" and spread_stage) or e.pose != 2 else "Idle", 0.0)

## живое между переездами: подползает по коридору, у двери подаётся вперёд перед входом, глаза бегают,
## поворот к камере (аномалия «stare»)
func _live(id: String, e: FNEnemy, r: Rig, dt: float) -> void:
	if not r.visible:
		return
	if e.spot in ["hall_l", "hall_r"]:
		var motion: String = mode.get(id, "")
		if id == "bot" and not motion.is_empty():
			var traveled := move_toward(float(creep[id]), BOT_TRAVEL, dt * BOT_TRAVEL / BOT_TRAVEL_TIME)
			creep[id] = traveled
			var direction := 1.0 if motion == "retreat" else -1.0
			r.position.z = float(r.get_meta("hall_z")) + direction * (BOT_TRAVEL - traveled)
			if traveled >= BOT_TRAVEL:
				mode.erase(id)
				r.play("FNStill", 0.15)
		elif motion == "approach":
			creep[id] = minf(1.1, float(creep.get(id, 0.0)) + dt * 0.05)
			r.position.z = float(r.get_meta("hall_z", r.position.z)) + float(creep[id])
	if e.spot in ["door_l", "door_r"] and e.linger > 0.0:
		var near: bool = e.door_t > e.linger * 0.7
		if near != bool(lunge_t.get(id, false)):
			lunge_t[id] = near
			r.play(_door_clip(e.spot, "FNLunge" if near else "FNPeek"), 0.25)
	if stare.has(id) and not e.spot in ["door_l", "door_r"]:
		var to: Vector3 = (stare[id] as Vector3) - r.global_position
		r.rotation.y = rotate_toward(r.rotation.y, atan2(to.x, to.z), dt * 0.45)
	var f: Dictionary = face.get(id, {})
	if f.is_empty():
		return
	var d: Array = dart.get(id, [randf_range(2.0, 5.0), 0.0])
	d[0] -= dt
	if d[0] <= 0.0:
		d[0] = randf_range(2.5, 6.0)
		d[1] = randf_range(0.25, 0.6)
		(f["eyes"] as Node3D).position.x = randf_range(-1.0, 1.0) * 0.035 * float(f["hs"])
	if d[1] > 0.0:
		d[1] -= dt
		if d[1] <= 0.0:
			(f["eyes"] as Node3D).position.x = 0.0
	dart[id] = d

## аномалия камеры: враг медленно поворачивается к ней всем телом
func stare_at(id: String, cam_pos: Vector3) -> void:
	if id != "":
		stare[id] = cam_pos

## хоррор-детали на обычной модели (пока нет своей модели владельца): у каждого врага своё
func _horror(id: String, r: Rig) -> void:
	var hb: int = r.bone["head"]
	var hs: float = float((face.get(id, {"hs": 0.4}) as Dictionary)["hs"])
	match id:
		"bot":
			# вместо лица — экран кинескопа со смайлом, который «плывёт» помехами
			if hb >= 0:
				var n := _on_bone(r, hb, Vector3(0, 0.42 * hs, 0.47 * hs))
				var scr := MGProps.screen_mat(Color(0.8, 0.95, 0.85), 3.0, 2.0, 1.6)
				MGProps.quad(n, Vector3.ZERO, Vector2(0.5 * hs, 0.4 * hs), scr)
		"madk1d":
			# очки: одна линза треснула и светится красным
			if hb >= 0:
				var n := _on_bone(r, hb, Vector3(0, 0.44 * hs, 0.46 * hs))
				MGProps.box(n, Vector3(-0.12 * hs, 0, 0), Vector3(0.18 * hs, 0.12 * hs, 0.01), MGProps.mat("black"))
				MGProps.box(n, Vector3(0.12 * hs, 0, 0), Vector3(0.18 * hs, 0.12 * hs, 0.01), MGProps.glow(Color(0.9, 0.05, 0.05), 2.4))
				MGProps.box(n, Vector3(0.12 * hs, 0, 0.007), Vector3(0.2 * hs, 0.012, 0.002), MGProps.mat("paper"), Vector3(0, 0, 0.7))
		"clipper":
			# красные кабели свисают с плеч, как вены
			for k in ["rarm", "larm"]:
				var b: int = r.bone[k]
				if b < 0:
					continue
				var n := _on_bone(r, b, Vector3.ZERO)
				MGProps.cable(n, Vector3(0, 0.0, 0.04), Vector3(0.02, -0.45, 0.08), 0.06, 0.008, MGProps.mat("red"))
				MGProps.cable(n, Vector3(0, 0.02, -0.03), Vector3(-0.03, -0.38, -0.05), 0.05, 0.006, MGProps.mat("red_dark"))
		"mod":
			# огромный резиновый молоток бана в правой руке
			var hb2: int = r.bone["rhand"]
			if hb2 >= 0:
				var n := _on_bone(r, hb2, Vector3(0, -0.05, 0.0))
				MGProps.cyl(n, Vector3(0, -0.2, 0), 0.02, 0.02, 0.5, MGProps.mat("black"))
				MGProps.cyl(n, Vector3(0, -0.48, 0), 0.09, 0.09, 0.26, MGProps.mat("red"), Vector3(0, 0, PI / 2))
				MGProps.text(n, "BAN", Vector3(0, -0.48, 0.095), 40, Color(0.95, 0.9, 0.85))
		"balon":
			# вентиль на затылке иногда «дышит» паром — тонкий конус
			if hb >= 0:
				var n := _on_bone(r, hb, Vector3(0, 0.9 * hs, -0.2 * hs))
				var steam := MGProps.cyl(n, Vector3(0, 0.12, 0), 0.06, 0.005, 0.22, MGProps.glow(Color(0.85, 0.88, 0.9), 0.4))
				steam.set_meta("steam", true)
				steam.name = "steam"

## узел, привязанный к кости, со сдвигом от неё в осях героя (вверх, вперёд)
func _on_bone(r: Rig, b: int, off: Vector3) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = r.skel.get_bone_name(b)
	r.skel.add_child(att)
	var rest_g: Transform3D = r.skel.global_transform * r.skel.get_bone_global_rest(b)
	var n := Node3D.new()
	att.add_child(n)
	n.transform = rest_g.affine_inverse() * Transform3D(Basis(), rest_g.origin + off)
	return n

## пасть: 0 — закрыта, 1 — раскрыта
func maw(id: String, k: float) -> void:
	var f: Dictionary = face.get(id, {})
	if f.is_empty():
		return
	(f["maw"] as Node3D).scale = Vector3(1.0 + k * 0.25, lerpf(0.08, 1.15, k), 1.0)
	if owned.has(id):
		(f["maw"] as Node3D).visible = k > 0.03

func hide_all() -> void:
	for id in rigs:
		var rig: Rig = rigs[id]
		rig.visible = false
		_set_appearance(String(id), rig, Appearance.ORIGINAL)
		scare_pose(String(id), false)
	place_key.clear()

## Материалы хранятся отдельно для наблюдения, порога и исходного вида рига.
## Слой ниши, предупреждение у вентиляционной решётки и скримеры используют свои прежние настройки.
func _set_appearance(id: String, rig: Rig, appearance: Appearance) -> void:
	if appearance_by_id.get(id, Appearance.ORIGINAL) == appearance:
		return
	if not visual_bindings.has(id):
		var patrol: Vector2 = PATROL_MATERIALS.get(id, PATROL_DEFAULT)
		visual_bindings[id] = _bind_visuals(rig, patrol)
	appearance_by_id[id] = appearance
	for entry in visual_bindings[id]:
		var visual: VisualInstance3D = entry[0]
		visual.layers = FNOffice.DOOR_LAYER if appearance == Appearance.DOOR else int(entry[1])
		if visual is Label3D:
			(visual as Label3D).shaded = appearance != Appearance.ORIGINAL or bool(entry[2])
		elif visual is MeshInstance3D:
			var mesh := visual as MeshInstance3D
			for binding: Array in entry[2]:
				var surface: int = binding[0]
				var material: Material = binding[1][appearance]
				if surface < 0:
					mesh.material_override = material
				else:
					mesh.set_surface_override_material(surface, material)

func _bind_visuals(rig: Rig, patrol: Vector2) -> Array:
	var bindings: Array = []
	var copies := {}
	for node in rig.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if visual is Label3D:
			bindings.append([visual, visual.layers, (visual as Label3D).shaded])
			continue
		var mesh := visual as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var surfaces: Array = []
		if mesh.material_override != null:
			var original := mesh.material_override
			surfaces.append([-1, _material_profiles(original, original, copies, patrol)])
		else:
			for i in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(i)
				if source != null:
					surfaces.append([i, _material_profiles(source, mesh.get_surface_override_material(i), copies, patrol)])
		bindings.append([mesh, mesh.layers, surfaces])
	return bindings

func _material_profiles(source: Material, original: Material, copies: Dictionary, patrol: Vector2) -> Array:
	if not copies.has(source):
		copies[source] = [_patrol_material(source, patrol), _door_material(source)]
	return [original, copies[source][0], copies[source][1]]

func _patrol_material(source: Material, patrol: Vector2) -> Material:
	if not (source is BaseMaterial3D):
		return source
	var local := source.duplicate() as BaseMaterial3D
	var eyes := source.has_meta("base_energy")
	local.albedo_color *= Color(patrol.x, patrol.x, patrol.x, 1.0)
	local.roughness = maxf(local.roughness, 0.68)
	local.metallic = minf(local.metallic, 0.56)
	local.metallic_specular = minf(local.metallic_specular, 0.22)
	local.emission_enabled = eyes
	if eyes:
		local.emission_energy_multiplier = float(source.get_meta("base_energy")) * 0.13
	var ir := source.next_pass as ShaderMaterial
	if ir != null and ir.shader == IR_SHADER:
		local.next_pass = ir_pass(local.albedo_texture, 0.27 if eyes else patrol.y)
	return local

func _door_material(source: Material) -> BaseMaterial3D:
	var local := source.duplicate() as BaseMaterial3D if source is BaseMaterial3D else StandardMaterial3D.new()
	local.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	local.disable_ambient_light = true
	local.emission_enabled = false
	local.metallic_specular = minf(local.metallic_specular, 0.16)
	local.roughness = maxf(local.roughness, 0.44)
	local.disable_receive_shadows = false
	return local

## после скримера: модель возвращается на своё место в риге
func scare_pose(id: String, _on: bool) -> void:
	if model_home.has(id):
		var m: Node3D = (rigs[id] as Rig).model
		m.transform = Transform3D(Basis().scaled(m.scale), model_home[id])

## где сейчас лицо врага (середина между глазами) — в мире
func face_pos(id: String) -> Vector3:
	var f: Dictionary = face.get(id, {})
	if f.is_empty():
		var r: Rig = rigs[id]
		return r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["head"]).origin
	return (f["eyes"] as Node3D).global_position

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
