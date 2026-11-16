## Локации глав: одна арена 30×30, оформление по стилю главы (deco из сюжета).
## snow — двор хрущёвок, basement — подвал, neon — неоновая лента, swamp — болото комментов, glass — крыша башни,
## grave — кладбище аккаунтов, server — ботоферма, chart — чарты, core — Ядро Алгоритма.
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
	if kind in ["embers", "sparks", "data"]:
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = qm
	particles.draw_pass_1 = q
	particles.position.y = 12 if kind == "snow" else 4
	add_child(particles)

func follow(p: Vector3) -> void:
	if particles:
		particles.global_position = Vector3(p.x, particles.global_position.y, p.z)
