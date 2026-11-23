## Локации глав: одна арена 30×30, оформление по стилю главы (deco из сюжета). Отдельно — hall: подъезд, с которого начинается игра.
## snow — двор хрущёвок, basement — подвал, neon — неоновая лента, swamp — болото комментов, glass — крыша башни,
## grave — кладбище аккаунтов, server — ботоферма, chart — чарты, core — Ядро Алгоритма.
## training — тренировочная арена (Training): тёмный зал, пять размеченных зон A–E.
extends Node3D

const ARENA := 15.0
var deco := "snow"
var particles: GPUParticles3D

func build(d: String) -> void:
	deco = d
	var T := _theme(d)
	var env := Environment.new()
	if T.get("indoor", false):
		env.background_mode = Environment.BG_COLOR
		env.background_color = T["sky"][0]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = T["amb"]
		env.ambient_light_energy = 1.0
	else:
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = T["sky"][0]
		sm.sky_horizon_color = T["sky"][1]
		sm.ground_bottom_color = T["sky"][0]
		sm.ground_horizon_color = T["sky"][1]
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = T.get("amb_e", 1.4)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = T.get("exp", 1.1)
	env.glow_enabled = true
	env.glow_intensity = T.get("glow", 0.7)
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = T["fog"]
	env.fog_density = T.get("fog_d", 0.018)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = T["key"]
	key.light_energy = T.get("key_e", 0.55)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45.0
	key.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.88, 0.78)
	fill.light_energy = 0.5
	fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(160), 0)
	add_child(fill)
	_ground(T)
	_static_box(Vector3(0, -0.5, 0), Vector3(90, 1, 90))
	for s in [[Vector3(0, 2, -ARENA - 0.5), Vector3(2 * ARENA + 2, 4, 1)], [Vector3(0, 2, ARENA + 0.5), Vector3(2 * ARENA + 2, 4, 1)], [Vector3(-ARENA - 0.5, 2, 0), Vector3(1, 4, 2 * ARENA + 2)], [Vector3(ARENA + 0.5, 2, 0), Vector3(1, 4, 2 * ARENA + 2)]]:
		_static_box(s[0], s[1])
	call("_deco_" + d, T)
	_particles(T)

func _theme(d: String) -> Dictionary:
	match d:
		"hall":
			return {"indoor": true, "sky": [Color(0.02, 0.02, 0.025)], "amb": Color(0.36, 0.37, 0.39), "fog": Color(0.12, 0.125, 0.13), "fog_d": 0.01, "key": Color(1, 1, 1), "key_e": 0.0, "g": [Color(0.3, 0.29, 0.27), Color(0.36, 0.35, 0.32)], "p": "dust"}
		"training":
			return {"indoor": true, "sky": [Color(0.02, 0.02, 0.025)], "amb": Color(0.42, 0.42, 0.45), "fog": Color(0.08, 0.08, 0.09), "fog_d": 0.012, "key": Color(1, 0.96, 0.9), "key_e": 0.35, "g": [Color(0.13, 0.13, 0.14), Color(0.22, 0.22, 0.23)], "p": "dust"}
		"basement":
			return {"indoor": true, "sky": [Color(0.03, 0.02, 0.02)], "amb": Color(0.35, 0.25, 0.2), "fog": Color(0.18, 0.12, 0.08), "fog_d": 0.03, "key": Color(1, 0.8, 0.6), "key_e": 0.25, "g": [Color(0.18, 0.12, 0.09), Color(0.32, 0.22, 0.15)], "p": "dust"}
		"neon":
			return {"sky": [Color(0.03, 0.0, 0.07), Color(0.25, 0.04, 0.3)], "fog": Color(0.3, 0.05, 0.35), "fog_d": 0.012, "key": Color(0.8, 0.5, 1.0), "key_e": 0.4, "g": [Color(0.04, 0.02, 0.08), Color(0.1, 0.05, 0.16)], "grid": Color(1, 0.25, 0.85), "grid2": Color(0.2, 0.85, 1.0), "glow": 1.0, "p": "sparks"}
		"swamp":
			return {"sky": [Color(0.04, 0.07, 0.04), Color(0.25, 0.3, 0.18)], "fog": Color(0.25, 0.32, 0.18), "fog_d": 0.03, "key": Color(0.85, 1.0, 0.7), "key_e": 0.45, "g": [Color(0.09, 0.13, 0.07), Color(0.2, 0.26, 0.12)], "p": "spores"}
		"glass":
			return {"sky": [Color(0.1, 0.16, 0.34), Color(0.95, 0.55, 0.35)], "fog": Color(0.55, 0.42, 0.45), "fog_d": 0.004, "key": Color(1, 0.8, 0.6), "key_e": 0.9, "amb_e": 0.6, "g": [Color(0.16, 0.2, 0.27), Color(0.3, 0.36, 0.45)], "exp": 0.95, "glow": 0.35, "p": "none"}
		"grave":
			return {"sky": [Color(0.04, 0.03, 0.07), Color(0.22, 0.17, 0.3)], "fog": Color(0.3, 0.24, 0.4), "fog_d": 0.028, "key": Color(0.75, 0.7, 1.0), "key_e": 0.4, "g": [Color(0.13, 0.13, 0.14), Color(0.24, 0.24, 0.26)], "p": "embers"}
		"server":
			return {"indoor": true, "sky": [Color(0.01, 0.02, 0.04)], "amb": Color(0.15, 0.25, 0.4), "fog": Color(0.05, 0.12, 0.2), "fog_d": 0.022, "key": Color(0.6, 0.8, 1.0), "key_e": 0.3, "g": [Color(0.08, 0.09, 0.11), Color(0.16, 0.18, 0.22)], "grid": Color(0.1, 0.5, 1.0), "glow": 0.9, "p": "data"}
		"chart":
			return {"sky": [Color(0.06, 0.02, 0.01), Color(0.4, 0.12, 0.05)], "fog": Color(0.35, 0.12, 0.06), "fog_d": 0.015, "key": Color(1, 0.6, 0.35), "key_e": 0.6, "g": [Color(0.07, 0.04, 0.03), Color(0.14, 0.08, 0.05)], "grid": Color(1, 0.45, 0.15), "glow": 1.0, "p": "sparks"}
		"core":
			return {"sky": [Color(0.5, 0.52, 0.58), Color(0.82, 0.84, 0.9)], "fog": Color(0.72, 0.74, 0.8), "fog_d": 0.006, "key": Color(1, 1, 1), "key_e": 0.7, "amb_e": 0.45, "g": [Color(0.4, 0.42, 0.47), Color(0.6, 0.62, 0.68)], "exp": 0.8, "glow": 0.15, "p": "cubes"}
		_:
			return {"sky": [Color(0.02, 0.03, 0.08), Color(0.16, 0.12, 0.2)], "fog": Color(0.22, 0.24, 0.33), "key": Color(0.65, 0.72, 1.0), "g": [Color(0.13, 0.14, 0.17), Color(0.62, 0.66, 0.74)], "p": "snow"}

func _ground(T: Dictionary) -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var gr := Gradient.new()
	gr.set_color(0, T["g"][0])
	gr.set_color(1, T["g"][1])
	nt.color_ramp = gr
	gmat.albedo_texture = nt
	gmat.uv1_scale = Vector3(6, 6, 1)
	gmat.roughness = 0.15 if deco == "glass" else 0.85
	if deco == "glass":
		gmat.metallic = 0.3
	if T.has("grid"):
		gmat.emission_enabled = true
		gmat.emission_texture = _grid_tex(T["grid"], T.get("grid2", T["grid"]))
		gmat.emission_energy_multiplier = 1.6
		gmat.uv1_scale = Vector3(30, 30, 1)
		gmat.albedo_texture = null
		gmat.albedo_color = T["g"][0]
	ground.material_override = gmat
	add_child(ground)

func _grid_tex(a: Color, b: Color) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0))
	img.fill_rect(Rect2i(0, 0, 64, 2), a)
	img.fill_rect(Rect2i(0, 0, 2, 64), b)
	return ImageTexture.create_from_image(img)

func _mat(c: Color, emit := 0.0, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _box(pos: Vector3, size: Vector3, mat: Material, rot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot
	mi.material_override = mat
	add_child(mi)
	return mi

func _cyl(pos: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi

func _static_box(pos: Vector3, size: Vector3, rot := 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 | 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot
	add_child(sb)

func _light(p: Vector3, c: Color, e := 2.6, r := 11.0) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	add_child(l)

func _facade(lit: Color, wall: Color, glass: Color) -> Array:
	var w := 768
	var h := 320
	var alb := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var emi := Image.create(w, h, false, Image.FORMAT_RGBA8)
	alb.fill(wall)
	emi.fill(Color(0, 0, 0))
	for y in 5:
		alb.fill_rect(Rect2i(0, y * 64 + 60, w, 4), wall.darkened(0.3))
		for x in 12:
			var r := Rect2i(x * 64 + 14, y * 64 + 14, 36, 34)
			var on := randf() < 0.38
			alb.fill_rect(r, lit if on else glass)
			alb.fill_rect(Rect2i(r.position.x + 17, r.position.y, 2, r.size.y), wall.darkened(0.3))
			if on:
				emi.fill_rect(r, lit * randf_range(0.6, 1.0))
	return [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(emi)]

func _building(pos: Vector3, rot: float, width: float, hgt: float, tex: Array, core_c: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot
	add_child(root)
	var core := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, hgt, 10)
	core.mesh = bm
	core.position.y = hgt / 2
	core.material_override = _mat(core_c)
	root.add_child(core)
	var front := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, hgt)
	front.mesh = qm
	front.position = Vector3(0, hgt / 2, 5.02)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tex[0]
	fm.emission_enabled = true
	fm.emission_texture = tex[1]
	fm.emission_energy_multiplier = 2.2
	fm.uv1_scale = Vector3(width / 30.0, hgt / 15.0, 1)
	front.material_override = fm
	root.add_child(front)

func _ring_of_buildings(tex: Array, core_c: Color, hgt := 15.0) -> void:
	for b in [[Vector3(0, 0, -ARENA - 7), 0.0, 34.0], [Vector3(-ARENA - 7, 0, 0), PI / 2, 30.0], [Vector3(ARENA + 7, 0, -2), -PI / 2, 30.0], [Vector3(6, 0, ARENA + 9), PI, 26.0]]:
		_building(b[0], b[1], b[2], hgt, tex, core_c)

# ---------- оформление ----------
func _deco_snow(_T: Dictionary) -> void:
	_ring_of_buildings(_facade(Color(1.0, 0.78, 0.42), Color(0.42, 0.4, 0.38), Color(0.08, 0.1, 0.16)), Color(0.3, 0.29, 0.28))
	for lp in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11), Vector3(0, 0, -13.5)]:
		_box(lp + Vector3(0, 2.4, 0), Vector3(0.14, 4.8, 0.14), _mat(Color(0.15, 0.15, 0.17)))
		_box(lp + Vector3(0, 4.85, 0), Vector3(0.6, 0.18, 0.35), _mat(Color(1, 0.8, 0.5), 6.0))
		_light(lp + Vector3(0, 4.5, 0), Color(1, 0.72, 0.45))
	var sm := _mat(Color(0.86, 0.9, 0.98), 0.0, 0.95)
	for i in 26:
		var a := randf() * TAU
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = randf_range(0.9, 2.0)
		sp.height = sp.radius * 2.0
		mi.mesh = sp
		mi.scale = Vector3(1.6, 0.35, 1.0)
		mi.position = Vector3(clamp(cos(a) * 30.0, -ARENA + 0.8, ARENA - 0.8), 0, clamp(sin(a) * 30.0, -ARENA + 0.8, ARENA - 0.8))
		mi.material_override = sm
		add_child(mi)
	for db in [Vector3(12.5, 0, 6), Vector3(12.5, 0, 8.2)]:
		_box(db + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.2), _mat(Color(0.2, 0.3, 0.24)))
		_static_box(db + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.2))

func _deco_basement(_T: Dictionary) -> void:
	var brick := _mat(Color(0.35, 0.2, 0.14))
	var tray := _mat(Color(0.45, 0.38, 0.3))
	for s in [[Vector3(0, 3, -ARENA - 0.6), Vector3(32, 6, 0.6)], [Vector3(0, 3, ARENA + 0.6), Vector3(32, 6, 0.6)], [Vector3(-ARENA - 0.6, 3, 0), Vector3(0.6, 6, 32)], [Vector3(ARENA + 0.6, 3, 0), Vector3(0.6, 6, 32)]]:
		_box(s[0], s[1], brick)
	_box(Vector3(0, 6.2, 0), Vector3(32, 0.4, 32), _mat(Color(0.12, 0.08, 0.06)))
	for i in 18:
		var side := i % 4
		var t := randf_range(-13, 13)
		var p: Vector3 = [Vector3(t, randf_range(1.5, 4.5), -ARENA - 0.25), Vector3(t, randf_range(1.5, 4.5), ARENA + 0.25), Vector3(-ARENA - 0.25, randf_range(1.5, 4.5), t), Vector3(ARENA + 0.25, randf_range(1.5, 4.5), t)][side]
		_box(p, Vector3(1.2 if side < 2 else 0.15, 1.2, 0.15 if side < 2 else 1.2), tray)
	for lp in [Vector3(-7, 5.6, -7), Vector3(7, 5.6, -7), Vector3(-7, 5.6, 7), Vector3(7, 5.6, 7), Vector3(0, 5.6, 0)]:
		_box(lp, Vector3(0.3, 0.3, 0.3), _mat(Color(1, 0.75, 0.4), 8.0))
		_light(lp + Vector3(0, -0.4, 0), Color(1, 0.65, 0.35), 2.2, 10.0)
	for c in [Vector3(-11, 0.6, 8), Vector3(10, 0.6, -9), Vector3(11, 0.6, 9)]:
		_box(c, Vector3(2.4, 1.2, 1.0), _mat(Color(0.25, 0.18, 0.3)))
		_static_box(c, Vector3(2.4, 1.2, 1.0))

func _deco_neon(T: Dictionary) -> void:
	_ring_of_buildings(_facade(Color(1, 0.3, 0.85), Color(0.08, 0.05, 0.12), Color(0.05, 0.08, 0.15)), Color(0.05, 0.03, 0.08), 22.0)
	for i in 10:
		var a := i / 10.0 * TAU
		var p := Vector3(cos(a) * 13.5, 0, sin(a) * 13.5)
		var c: Color = T["grid"] if i % 2 == 0 else T["grid2"]
		_box(p + Vector3(0, 2.5, 0), Vector3(0.4, 5, 0.4), _mat(c, 5.0))
		_light(p + Vector3(0, 3, 0), c, 1.8, 7.0)

func _deco_swamp(_T: Dictionary) -> void:
	var bark := _mat(Color(0.18, 0.14, 0.1))
	var moss := _mat(Color(0.2, 0.35, 0.12))
	for i in 22:
		var a := randf() * TAU
		var r := randf_range(12.0, 22.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := randf_range(5, 11)
		var t := _cyl(p + Vector3(0, h / 2, 0), randf_range(0.25, 0.5), h, bark)
		t.rotation.z = randf_range(-0.15, 0.15)
		for b in 3:
			var br := _cyl(p + Vector3(0, h * randf_range(0.5, 0.9), 0), 0.1, randf_range(2, 4), bark)
			br.rotation = Vector3(randf_range(0.6, 1.2), randf() * TAU, 0)
	for i in 30:
		var p := Vector3(randf_range(-13, 13), 0.03, randf_range(-13, 13))
		var mi := _cyl(p, randf_range(0.4, 1.0), 0.04, moss)
		mi.scale.z = 0.8
	_light(Vector3(0, 6, 0), Color(0.6, 1, 0.4), 1.5, 25.0)

func _deco_glass(_T: Dictionary) -> void:
	var city := _facade(Color(1, 0.95, 0.8), Color(0.55, 0.62, 0.72), Color(0.3, 0.4, 0.55))
	for i in 14:
		var a := i / 14.0 * TAU
		var r := randf_range(35, 55)
		_building(Vector3(cos(a) * r, -30, sin(a) * r), -a + PI / 2, randf_range(10, 18), randf_range(40, 70), city, Color(0.45, 0.52, 0.62))
	var rail := _mat(Color(0.8, 0.9, 1.0), 0.0, 0.1)
	for s in [[Vector3(0, 0.6, -ARENA), Vector3(30, 1.2, 0.1)], [Vector3(0, 0.6, ARENA), Vector3(30, 1.2, 0.1)], [Vector3(-ARENA, 0.6, 0), Vector3(0.1, 1.2, 30)], [Vector3(ARENA, 0.6, 0), Vector3(0.1, 1.2, 30)]]:
		var m := _box(s[0], s[1], rail)
		m.transparency = 0.5
	for c in [Vector3(-9, 0.4, -9), Vector3(9, 0.4, 9)]:
		_box(c, Vector3(2.2, 0.8, 1.0), _mat(Color(0.95, 0.95, 0.97)))
		_static_box(c, Vector3(2.2, 0.8, 1.0))

func _deco_grave(_T: Dictionary) -> void:
	var stone := _mat(Color(0.4, 0.4, 0.43))
	for i in 34:
		var p := Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
		if p.length() < 6.0:
			continue
		_box(p + Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.25), stone, randf_range(-0.3, 0.3))
	for i in 10:
		var a := randf() * TAU
		var p := Vector3(cos(a) * 18, 0, sin(a) * 18)
		_cyl(p + Vector3(0, 4, 0), 0.3, 8, _mat(Color(0.12, 0.1, 0.12)))
	for lp in [Vector3(-10, 1.2, -10), Vector3(10, 1.2, 10), Vector3(10, 1.2, -10), Vector3(-10, 1.2, 10)]:
		_box(lp, Vector3(0.3, 0.4, 0.3), _mat(Color(0.7, 0.5, 1.0), 6.0))
		_light(lp, Color(0.7, 0.5, 1.0), 2.0, 9.0)

func _deco_server(_T: Dictionary) -> void:
	var rack := _mat(Color(0.1, 0.11, 0.14), 0.0, 0.4)
	for row in [-13.0, 13.0]:
		for i in 12:
			var p := Vector3(-13 + i * 2.4, 1.6, row)
			_box(p, Vector3(1.8, 3.2, 1.2), rack)
			for led in 6:
				var c := Color(0.2, 0.8, 1.0) if randf() < 0.7 else Color(1, 0.3, 0.3)
				_box(p + Vector3(randf_range(-0.7, 0.7), randf_range(-1.3, 1.3), 0.61 * sign(-row)), Vector3(0.08, 0.04, 0.02), _mat(c, 6.0))
	for col in [-13.0, 13.0]:
		for i in 9:
			_box(Vector3(col, 1.6, -9 + i * 2.3), Vector3(1.2, 3.2, 1.8), rack)
	_box(Vector3(0, 6.5, 0), Vector3(32, 0.3, 32), _mat(Color(0.05, 0.06, 0.08)))
	for lp in [Vector3(-6, 6, -6), Vector3(6, 6, 6), Vector3(6, 6, -6), Vector3(-6, 6, 6)]:
		_light(lp, Color(0.4, 0.7, 1.0), 2.0, 12.0)

func _deco_chart(T: Dictionary) -> void:
	for i in 28:
		var a := i / 28.0 * TAU
		var p := Vector3(cos(a) * 17, 0, sin(a) * 17)
		var h := randf_range(2, 12)
		var c: Color = T["grid"].lerp(Color(1, 0.85, 0.3), randf())
		_box(p + Vector3(0, h / 2, 0), Vector3(1.4, h, 1.4), _mat(c, 3.0), -a)
	_light(Vector3(0, 8, 0), Color(1, 0.5, 0.2), 2.0, 30.0)

func _deco_core(_T: Dictionary) -> void:
	for i in 40:
		var p := Vector3(randf_range(-30, 30), randf_range(4, 20), randf_range(-30, 30))
		if p.length() < 16:
			continue
		var c := _box(p, Vector3.ONE * randf_range(0.6, 2.5), _mat(Color(0.9, 0.92, 0.97), 0.15), randf() * TAU)
		c.rotation.x = randf() * TAU
	for i in 8:
		var a := i / 8.0 * TAU
		_box(Vector3(cos(a) * 14, 3, sin(a) * 14), Vector3(0.5, 6, 0.5), _mat(Color(0.75, 0.85, 1.0), 1.2))

func _particles(T: Dictionary) -> void:
	var kind: String = T.get("p", "none")
	if kind == "none":
		return
	particles = GPUParticles3D.new()
	particles.amount = 1500 if kind == "snow" else 500
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.visibility_aabb = AABB(Vector3(-25, -15, -25), Vector3(50, 30, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 6 if kind != "snow" else 1, 22)
	var col := Color(1, 1, 1, 0.85)
	var size := 0.05
	match kind:
		"snow":
			pm.direction = Vector3(0.15, -1, 0)
			pm.gravity = Vector3(0.2, -0.9, 0)
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.2
		"embers", "sparks":
			pm.direction = Vector3(0, 1, 0)
			pm.gravity = Vector3(0, 0.3, 0)
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 0.9
			col = Color(1, 0.55, 0.2) if kind == "sparks" else Color(0.75, 0.55, 1.0)
		"spores", "dust":
			pm.direction = Vector3(0, 1, 0)
			pm.gravity = Vector3(0, 0.05, 0)
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			col = Color(0.7, 1, 0.5, 0.6) if kind == "spores" else Color(1, 0.85, 0.65, 0.5)
		"data":
			pm.direction = Vector3(0, -1, 0)
			pm.gravity = Vector3(0, -3, 0)
			col = Color(0.3, 0.8, 1.0)
			size = 0.04
		"cubes":
			pm.direction = Vector3(0, 1, 0)
			pm.gravity = Vector3(0, 0.2, 0)
			col = Color(0.6, 0.65, 0.75)
			size = 0.12
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	particles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = col
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# частицы окружения — на текстурах Kenney: мягкие хлопья, искры-звёзды, падающие штрихи данных
	var ptex := {"snow": "star_05", "embers": "star_07", "sparks": "star_06", "spores": "circle_05", "dust": "circle_05", "data": "trace_07"}
	if ptex.has(kind):
		qm.albedo_texture = load("res://assets/fx/%s.png" % ptex[kind])
		q.size = Vector2(size * 3.0, size * 26.0) if kind == "data" else Vector2(size, size) * (4.5 if kind in ["snow", "spores", "dust"] else 5.5)
	if kind in ["embers", "sparks", "data"]:
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = qm
	particles.draw_pass_1 = q
	particles.position.y = 12 if kind == "snow" else 4
	add_child(particles)

func follow(p: Vector3) -> void:
	if particles:
		particles.global_position = Vector3(p.x, particles.global_position.y, p.z)

## Подъезд — площадка, с которой начинается игра. Стиль — голый бетон: серые стены в разводах со швами опалубки
## и отверстиями от стяжек, трафаретная девятка, серая каменная плитка, светлый плинтус, холодный свет.
## На стенах — надписи маркером и баллончиком. Выход во двор — проём в стене z = -5.
func _concrete(a: Color, b: Color, scl: float, seed_n: int) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_n
	noise.frequency = 0.006
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var gr := Gradient.new()
	gr.set_color(0, a)
	gr.set_color(1, b)
	nt.color_ramp = gr
	var m := StandardMaterial3D.new()
	m.albedo_texture = nt
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scl
	return m

func _deco_hall(_T: Dictionary) -> void:
	var W := 4.0
	var L := 5.0
	var H := 3.2
	var conc := _concrete(Color(0.33, 0.33, 0.32), Color(0.58, 0.57, 0.55), 0.22, 3)
	var conc2 := _concrete(Color(0.3, 0.3, 0.3), Color(0.5, 0.5, 0.49), 0.3, 8)
	var tile_a := _concrete(Color(0.42, 0.42, 0.42), Color(0.56, 0.56, 0.55), 0.6, 5)
	var tile_b := _concrete(Color(0.38, 0.38, 0.39), Color(0.5, 0.5, 0.5), 0.6, 11)
	var seam := _mat(Color(0.2, 0.2, 0.2))
	var dark := _mat(Color(0.12, 0.12, 0.13))
	var skirt := _mat(Color(0.66, 0.66, 0.64))
	var metal := _mat(Color(0.26, 0.28, 0.31), 0.0, 0.45)
	var door := _mat(Color(0.2, 0.2, 0.22), 0.0, 0.6)
	# пол: крупная серая плитка со швами
	for ix in 8:
		for iz in 10:
			_box(Vector3(-W + 0.5 + ix, 0.01, -L + 0.5 + iz), Vector3(0.975, 0.02, 0.975), tile_a if (ix * 3 + iz * 5) % 4 != 0 else tile_b)
	_box(Vector3(0, 0.0, 0), Vector3(2 * W, 0.01, 2 * L), seam)
	# стены и потолок из бетона
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * (W + 0.1), H / 2, 0), Vector3(0.2, H, 2 * L), conc)
		_static_box(Vector3(sx * (W + 0.5), H / 2, 0), Vector3(1, H, 2 * L + 2))
	_box(Vector3(0, H / 2, L + 0.1), Vector3(2 * W, H, 0.2), conc)
	_static_box(Vector3(0, H / 2, L + 0.5), Vector3(2 * W + 2, H, 1))
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 2.4, H / 2, -L - 0.1), Vector3(3.2, H, 0.2), conc)
	_box(Vector3(0, 2.7, -L - 0.1), Vector3(1.6, 1.0, 0.2), conc)
	_static_box(Vector3(0, H / 2, -L - 0.5), Vector3(2 * W + 2, H, 1))
	_box(Vector3(0, H + 0.1, 0), Vector3(2 * W + 0.4, 0.2, 2 * L + 0.4), conc2)
	_static_box(Vector3(0, H + 0.5, 0), Vector3(2 * W + 2, 1, 2 * L + 2))
	# швы опалубки, отверстия от стяжек и светлый плинтус по всем стенам
	for hy in [1.07, 2.13]:
		for sx in [-1.0, 1.0]:
			_box(Vector3(sx * (W - 0.004), hy, 0), Vector3(0.012, 0.018, 2 * L), seam)
		for sz in [-1.0, 1.0]:
			_box(Vector3(0, hy, sz * (L - 0.004)), Vector3(2 * W, 0.018, 0.012), seam)
	for i in 9:
		var p := -L + 0.6 + i * 1.1
		for hy in [0.55, 1.6, 2.65]:
			for sx in [-1.0, 1.0]:
				_box(Vector3(sx * (W - 0.006), hy, p), Vector3(0.014, 0.05, 0.05), dark)
		if i % 2 == 0:
			for sx in [-1.0, 1.0]:
				_box(Vector3(sx * (W - 0.004), H / 2, p + 0.55), Vector3(0.012, H, 0.014), seam)
	for i in 7:
		var p := -W + 0.7 + i * 1.1
		for hy in [0.55, 1.6, 2.65]:
			_box(Vector3(p, hy, L - 0.006), Vector3(0.05, 0.05, 0.014), dark)
			if abs(p) > 1.0:
				_box(Vector3(p, hy, -L + 0.006), Vector3(0.05, 0.05, 0.014), dark)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * (W - 0.02), 0.07, 0), Vector3(0.04, 0.14, 2 * L), skirt)
	_box(Vector3(0, 0.07, L - 0.02), Vector3(2 * W, 0.14, 0.04), skirt)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 2.4, 0.07, -L + 0.02), Vector3(3.2, 0.14, 0.04), skirt)
	# выход во двор: распахнутая стальная дверь, за проёмом — ночь и снег
	_box(Vector3(0, 1.1, -L - 0.22), Vector3(1.6, 2.2, 0.05), _mat(Color(0.5, 0.66, 1.0), 2.4))
	_box(Vector3(-0.86, 1.1, -L + 0.72), Vector3(0.07, 2.15, 1.45), door)
	for sx in [-0.84, 0.84]:
		_box(Vector3(sx, 1.1, -L + 0.02), Vector3(0.1, 2.25, 0.12), dark)
	_box(Vector3(0, 2.24, -L + 0.02), Vector3(1.78, 0.1, 0.12), dark)
	_box(Vector3(0, 0.025, -L + 0.55), Vector3(1.5, 0.03, 1.0), _mat(Color(0.85, 0.88, 0.95)))
	_light(Vector3(0, 1.4, -L + 0.9), Color(0.55, 0.7, 1.0), 2.2, 6.5)
	# двери квартир и коврики
	for sx in [-2.0, 2.0]:
		_box(Vector3(sx, 1.05, L - 0.04), Vector3(1.0, 2.1, 0.1), door)
		_box(Vector3(sx, 1.72, L - 0.1), Vector3(0.16, 0.1, 0.02), _mat(Color(0.75, 0.75, 0.72), 0.3))
		_box(Vector3(sx + 0.36, 1.0, L - 0.11), Vector3(0.05, 0.14, 0.05), _mat(Color(0.7, 0.7, 0.68), 0.0, 0.4))
		_box(Vector3(sx, 0.03, L - 0.72), Vector3(0.9, 0.03, 0.55), _mat(Color(0.16, 0.16, 0.17)))
	# почтовые ящики
	for row in 2:
		for col in 5:
			var mz := -1.4 + col * 0.42
			var my := 1.2 + row * 0.38
			_box(Vector3(W - 0.11, my, mz), Vector3(0.2, 0.34, 0.38), metal)
			_box(Vector3(W - 0.22, my + 0.08, mz), Vector3(0.02, 0.03, 0.24), dark)
	# лестница наверх: бетонные ступени, площадка, стальные перила
	for i in 10:
		var top := (i + 1) * 0.17
		_box(Vector3(-3.2, top / 2, 1.82 - 0.36 * i), Vector3(1.6, top, 0.36), conc2)
		_box(Vector3(-2.42, top + 0.45, 1.82 - 0.36 * i), Vector3(0.04, 0.9, 0.04), dark)
	_box(Vector3(-3.2, 1.62, -3.2), Vector3(1.6, 0.16, 3.2), conc2)
	var rail := _box(Vector3(-2.42, 1.86, 0.2), Vector3(0.06, 0.06, 4.0), dark)
	rail.rotation.x = atan(1.7 / 3.6)
	_static_box(Vector3(-3.2, 1.0, -1.3), Vector3(1.7, 2.0, 7.2))
	# батарея, труба, щиток
	for i in 8:
		_box(Vector3(W - 0.14, 0.55, -3.9 + i * 0.1), Vector3(0.12, 0.6, 0.07), _mat(Color(0.5, 0.5, 0.5)))
	_cyl(Vector3(W - 0.25, H / 2, L - 0.3), 0.09, H, metal)
	_box(Vector3(W - 0.1, 1.9, 2.6), Vector3(0.14, 0.6, 0.45), metal)
	# лампа на проводе, холодный свет: «на площадке дрожит лампа»
	_box(Vector3(0, H - 0.2, 0.8), Vector3(0.02, 0.4, 0.02), dark)
	_box(Vector3(0, H - 0.48, 0.8), Vector3(0.18, 0.22, 0.18), _mat(Color(0.9, 0.95, 1.0), 1.6))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, H - 0.7, 0.8)
	lamp.light_color = Color(0.88, 0.93, 1.0)
	lamp.light_energy = 1.8
	lamp.omni_range = 9.5
	lamp.shadow_enabled = true
	add_child(lamp)
	var tw := lamp.create_tween().set_loops()
	for st in [[1.8, 1.7], [0.5, 0.05], [1.8, 0.5], [0.9, 0.04], [1.7, 0.08], [0.4, 0.06], [1.8, 2.4]]:
		tw.tween_property(lamp, "light_energy", st[0], 0.03)
		tw.tween_interval(st[1])
	_light(Vector3(0.5, 2.3, 3.9), Color(0.85, 0.9, 1.0), 0.8, 5.0)
	# трафаретные девятки и надписи: [текст, место, поворот вокруг вертикали, размер, цвет, наклон]
	var font = load("res://assets/fonts/RussoOne-Regular.ttf")
	var stencil := Color(0.2, 0.23, 0.3, 0.92)
	var marker := Color(0.08, 0.08, 0.1, 0.95)
	for it in [
		["9", Vector3(2.5, 1.95, -L + 0.012), 0.0, 330, stencil, 0.0],
		["9", Vector3(0.0, 2.25, L - 0.012), PI, 250, stencil, 0.0],
		["VOZDUH", Vector3(W - 0.012, 2.35, 1.3), -PI / 2, 105, Color(0.72, 0.13, 0.12, 0.95), 0.06],
		["МАРК БЫЛ ТУТ", Vector3(-3.0, 1.25, L - 0.012), PI, 38, marker, -0.05],
		["он сказал поехали!", Vector3(3.0, 1.35, L - 0.012), PI, 34, marker, 0.08],
		["дуем балоны на 17 этаже", Vector3(W - 0.012, 0.85, -2.6), -PI / 2, 36, marker, -0.04],
		["дуем балоны на 17 этаже", Vector3(-W + 0.012, 2.55, -3.4), PI / 2, 34, marker, 0.05],
	]:
		var lb := Label3D.new()
		lb.text = it[0]
		lb.font = font
		lb.font_size = it[3]
		lb.pixel_size = 0.006
		lb.modulate = it[4]
		lb.outline_size = 0
		lb.shaded = true
		lb.position = it[1]
		lb.rotation = Vector3(0, it[2], it[5])
		add_child(lb)

# ---------- тренировочная арена ----------
const TRAIN_ZONES := [["A", Vector3(-8, 0, -6), "МАНЕКЕН", Color(0.95, 0.96, 0.97)], ["B", Vector3(8, 0, -6), "ЗАМАХИ", Color(0.95, 0.25, 0.22)],
	["C", Vector3(-8, 0, 6), "ВОЗДУХ", Color(0.35, 0.8, 1.0)], ["D", Vector3(8, 0, 6), "БОСС", Color(1.0, 0.78, 0.3)], ["E", Vector3(0, 0, 0), "СВОБОДНЫЙ БОЙ", Color(0.7, 0.72, 0.76)]]

func _deco_training(_T: Dictionary) -> void:
	var wall := _mat(Color(0.2, 0.2, 0.21))
	for w in [[Vector3(0, 3, -ARENA - 0.6), Vector3(32, 6, 0.6)], [Vector3(0, 3, ARENA + 0.6), Vector3(32, 6, 0.6)], [Vector3(-ARENA - 0.6, 3, 0), Vector3(0.6, 6, 32)], [Vector3(ARENA + 0.6, 3, 0), Vector3(0.6, 6, 32)]]:
		_box(w[0], w[1], wall)
	_box(Vector3(0, 6.2, 0), Vector3(32, 0.4, 32), _mat(Color(0.06, 0.06, 0.07)))
	# полосы по стенам — красная лента, как на плашках меню
	for w in [[Vector3(0, 1.1, -ARENA - 0.28), Vector3(30, 0.18, 0.05)], [Vector3(0, 1.1, ARENA + 0.28), Vector3(30, 0.18, 0.05)], [Vector3(-ARENA - 0.28, 1.1, 0), Vector3(0.05, 0.18, 30)], [Vector3(ARENA + 0.28, 1.1, 0), Vector3(0.05, 0.18, 30)]]:
		_box(w[0], w[1], _mat(Color(0.85, 0.12, 0.1), 1.6))
	for z in TRAIN_ZONES:
		var at: Vector3 = z[1]
		var c: Color = z[3]
		var half := 3.0
		_box(at + Vector3(0, 0.012, 0), Vector3(half * 2.0, 0.02, half * 2.0), _mat(c.darkened(0.82)))
		for e in [[Vector3(0, 0, -half), Vector3(half * 2.0, 0.03, 0.12)], [Vector3(0, 0, half), Vector3(half * 2.0, 0.03, 0.12)], [Vector3(-half, 0, 0), Vector3(0.12, 0.03, half * 2.0)], [Vector3(half, 0, 0), Vector3(0.12, 0.03, half * 2.0)]]:
			_box(at + e[0] + Vector3(0, 0.03, 0), e[1], _mat(c, 2.2))
		var l := Label3D.new()
		l.text = "%s · %s" % [z[0], z[2]]
		l.font_size = 96
		l.pixel_size = 0.0075
		l.modulate = c
		l.outline_size = 0
		l.rotation.x = -PI / 2.0
		l.position = at + Vector3(0, 0.05, half + 0.55)
		add_child(l)
		_light(at + Vector3(0, 5.4, 0), c.lerp(Color(1, 1, 1), 0.6), 1.8, 9.0)
		_box(at + Vector3(0, 5.85, 0), Vector3(1.6, 0.12, 0.4), _mat(c.lerp(Color(1, 1, 1), 0.6), 5.0))
