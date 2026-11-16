## Глава «Томск»: зимний двор хрущёвок ночью, камера из-за плеча, три волны врагов, интерфейс, эффекты.
extends Node3D

const ARENA := 15.0
const WAVES := [
	{"name": "ВОЛНА 1 — БОТЫ", "list": ["bot", "bot", "bot", "bot", "bot"]},
	{"name": "ВОЛНА 2 — КЛИППЕРЫ", "list": ["bot", "bot", "bot", "clipper", "clipper", "clipper"]},
	{"name": "ВОЛНА 3 — ХЕЙТЕРЫ", "list": ["clipper", "clipper", "clipper", "hater", "hater", "hater", "bot", "bot"]},
]

var main
var player
var buddy
var enemies: Array = []
var cam_yaw := PI
var cam_pitch := -0.32
var pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var shake_a := 0.0
var wave := -1
var wave_wait := 2.5
var kills := 0
var over := false
# интерфейс
var hud: CanvasLayer
var hp_fill: ColorRect
var swag_fill: ColorRect
var swag_label: Label
var wave_label: Label
var q_label: Label
var fps_label: Label
var banner_title: Label
var banner_sub: Label
var banner_t := 0.0
var flash: ColorRect
var pause_panel: Control
var end_panel: Control
var snow: GPUParticles3D
var bolts: Array = []
# автотест
var auto_t := 0.0
var auto_shots := [3.0, 9.0, 15.0, 21.0, 27.0, 33.0, 40.0]
var fps_samples: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_world()
	player = preload("res://scripts/player.gd").new()
	player.game = self
	add_child(player)
	player.global_position = Vector3(0, 0, 4)
	buddy = preload("res://scripts/companion.gd").new()
	buddy.game = self
	add_child(buddy)
	buddy.global_position = Vector3(-1.8, 0, 4.5)
	_build_camera()
	_build_hud()
	if main.autotest == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	banner("ТОМСК. ЯНВАРЬ. −34°", "у кента забрали голос — разбирайся", Color(1, 0.85, 0.55))

# ---------------- мир ----------------
func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.03, 0.08)
	sm.sky_horizon_color = Color(0.16, 0.12, 0.2)
	sm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	sm.ground_horizon_color = Color(0.12, 0.1, 0.14)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.24, 0.33)
	env.fog_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.86, 0.75)
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(160), 0)
	add_child(fill)
	# асфальт со снегом
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	pm.subdivide_width = 1
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
	gr.set_color(0, Color(0.13, 0.14, 0.17))
	gr.set_color(1, Color(0.62, 0.66, 0.74))
	gr.add_point(0.55, Color(0.2, 0.21, 0.25))
	nt.color_ramp = gr
	gmat.albedo_texture = nt
	gmat.uv1_scale = Vector3(6, 6, 1)
	gmat.roughness = 0.85
	ground.material_override = gmat
	add_child(ground)
	_static_box(Vector3(0, -0.5, 0), Vector3(90, 1, 90), null)
	# стены арены (невидимые) и хрущёвки вокруг
	for s in [[Vector3(0, 2, -ARENA - 0.5), Vector3(2 * ARENA + 2, 4, 1)], [Vector3(0, 2, ARENA + 0.5), Vector3(2 * ARENA + 2, 4, 1)], [Vector3(-ARENA - 0.5, 2, 0), Vector3(1, 4, 2 * ARENA + 2)], [Vector3(ARENA + 0.5, 2, 0), Vector3(1, 4, 2 * ARENA + 2)]]:
		_static_box(s[0], s[1], null)
	var facade := _facade_texture()
	for b in [[Vector3(0, 0, -ARENA - 7), 0.0, 34.0], [Vector3(-ARENA - 7, 0, 0), PI / 2, 30.0], [Vector3(ARENA + 7, 0, -2), -PI / 2, 30.0], [Vector3(6, 0, ARENA + 9), PI, 26.0]]:
		_building(b[0], b[1], b[2], facade)
	# фонари
	for lp in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11), Vector3(0, 0, -13.5)]:
		_lamp(lp)
	# сугробы, скамейки, мусорки, бочки
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.86, 0.9, 0.98)
	snow_mat.roughness = 0.95
	for i in 26:
		var a := randf() * TAU
		var edge := Vector3(clamp(cos(a) * 30.0, -ARENA + 0.8, ARENA - 0.8), 0, clamp(sin(a) * 30.0, -ARENA + 0.8, ARENA - 0.8))
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = randf_range(0.9, 2.0)
		sp.height = sp.radius * 2.0
		mi.mesh = sp
		mi.scale = Vector3(1.6, 0.35, 1.0)
		mi.rotation.y = randf() * TAU
		mi.position = edge
		mi.material_override = snow_mat
		add_child(mi)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.14)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.3, 0.24)
	metal.metallic = 0.4
	for bn in [[Vector3(-6, 0, -12.5), 0.0], [Vector3(6, 0, -12.5), 0.0], [Vector3(-13, 0, 4), PI / 2]]:
		var bench := _box(bn[0] + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.6), wood)
		bench.rotation.y = bn[1]
		_static_box(bn[0] + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 0.6), null, bn[1])
	for db in [Vector3(12.5, 0, 6), Vector3(12.5, 0, 8.2)]:
		_box(db + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.2), metal)
		_static_box(db + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.2), null)
	# снегопад вокруг камеры
	snow = GPUParticles3D.new()
	snow.amount = 1800
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.visibility_aabb = AABB(Vector3(-25, -15, -25), Vector3(50, 30, 50))
	var sp2 := ParticleProcessMaterial.new()
	sp2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp2.emission_box_extents = Vector3(22, 1, 22)
	sp2.direction = Vector3(0.15, -1, 0)
	sp2.initial_velocity_min = 0.6
	sp2.initial_velocity_max = 1.2
	sp2.gravity = Vector3(0.2, -0.9, 0)
	sp2.turbulence_enabled = true
	sp2.turbulence_noise_strength = 0.4
	snow.process_material = sp2
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(1, 1, 1, 0.85)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = qm
	snow.draw_pass_1 = q
	snow.position.y = 12
	add_child(snow)

func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if mat:
		mi.material_override = mat
	add_child(mi)
	return mi

func _static_box(pos: Vector3, size: Vector3, _mat, rot := 0.0) -> void:
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

func _facade_texture() -> Array:
	# панельный фасад: 12 окон в ряд, 5 этажей; часть окон горит тёплым светом
	var w := 768
	var h := 320
	var alb := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var emi := Image.create(w, h, false, Image.FORMAT_RGBA8)
	alb.fill(Color(0.42, 0.4, 0.38))
	emi.fill(Color(0, 0, 0))
	for y in 5:
		alb.fill_rect(Rect2i(0, y * 64 + 60, w, 4), Color(0.3, 0.29, 0.28))
		for x in 12:
			var r := Rect2i(x * 64 + 14, y * 64 + 14, 36, 34)
			var lit := randf() < 0.38
			var c := Color(1.0, 0.78, 0.42) if lit else Color(0.08, 0.1, 0.16)
			alb.fill_rect(r, c)
			alb.fill_rect(Rect2i(r.position.x + 17, r.position.y, 2, r.size.y), Color(0.3, 0.29, 0.28))
			if lit:
				emi.fill_rect(r, Color(1.0, 0.7, 0.35) * randf_range(0.6, 1.0))
	return [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(emi)]

func _building(pos: Vector3, rot: float, width: float, tex: Array) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot
	add_child(root)
	var hgt := 15.0
	var core := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, hgt, 10)
	core.mesh = bm
	core.position.y = hgt / 2
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.3, 0.29, 0.28)
	core.material_override = cm
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
	fm.uv1_scale = Vector3(width / 30.0 * 1.0, 1, 1)
	fm.texture_repeat = true
	front.material_override = fm
	root.add_child(front)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(width + 0.4, 0.5, 10.4)
	roof.mesh = rb
	roof.position.y = hgt + 0.25
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.85, 0.88, 0.95)
	roof.material_override = rm
	root.add_child(roof)

func _lamp(p: Vector3) -> void:
	var pole := _box(p + Vector3(0, 2.4, 0), Vector3(0.14, 4.8, 0.14), null)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.15, 0.15, 0.17)
	pole.material_override = pm
	var head := _box(p + Vector3(0, 4.85, 0), Vector3(0.6, 0.18, 0.35), null)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1, 0.85, 0.6)
	hm.emission_enabled = true
	hm.emission = Color(1, 0.75, 0.45)
	hm.emission_energy_multiplier = 6.0
	head.material_override = hm
	var l := OmniLight3D.new()
	l.position = p + Vector3(0, 4.5, 0)
	l.light_color = Color(1, 0.72, 0.45)
	l.light_energy = 2.6
	l.omni_range = 11.0
	l.omni_attenuation = 1.2
	add_child(l)

# ---------------- камера ----------------
func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.6
	spring.collision_mask = 8
	spring.margin = 0.2
	pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 200.0
	spring.add_child(cam)
	cam.make_current()

func _unhandled_input(e: InputEvent) -> void:
	if over:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= e.relative.x * 0.0028
		cam_pitch = clamp(cam_pitch - e.relative.y * 0.0022, -1.1, 0.35)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
	if e.is_action_pressed("adlib") and not get_tree().paused:
		if not buddy.adlib():
			popup(buddy.global_position + Vector3(0, 2.1, 0), "перезарядка", Color(0.6, 0.7, 0.8))

func shake(a: float) -> void:
	shake_a = max(shake_a, a)

func _process(dt: float) -> void:
	var rdt: float = dt / max(Engine.time_scale, 0.001)
	var target: Vector3 = player.global_position + Vector3(0, 1.55, 0)
	pivot.global_position = pivot.global_position.lerp(target, 1.0 - exp(-14.0 * rdt)) if pivot.global_position != Vector3.ZERO else target
	pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	spring.position = Vector3(0.55, 0, 0)
	shake_a = max(0.0, shake_a - rdt * 1.8)
	cam.h_offset = randf_range(-1, 1) * shake_a * 0.25
	cam.v_offset = randf_range(-1, 1) * shake_a * 0.25
	snow.global_position = Vector3(player.global_position.x, 12.0, player.global_position.z)
	_update_hud(rdt)
	_update_bolts(dt)
	_update_waves(dt)
	if main.autotest != "":
		_autotest(rdt)

# ---------------- волны ----------------
func _update_waves(dt: float) -> void:
	if over:
		return
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	var alive := enemies.filter(func(e): return e.state != "dead").size()
	if alive == 0:
		wave_wait -= dt
		if wave_wait <= 0.0:
			wave += 1
			if wave >= WAVES.size():
				_victory()
				return
			banner(WAVES[wave]["name"], "врагов: %d" % WAVES[wave]["list"].size(), Color(1, 0.4, 0.3))
			main.sfx("sfx_wave", -4.0)
			for i in WAVES[wave]["list"].size():
				_spawn(WAVES[wave]["list"][i], i)
			wave_wait = 2.5

func _spawn(kind: String, i: int) -> void:
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = kind
	e.game = self
	add_child(e)
	var a := randf() * TAU
	var pos := Vector3.ZERO
	for n in 20:
		a = randf() * TAU
		pos = Vector3(cos(a), 0, sin(a)) * randf_range(7.0, 12.5)
		if in_arena(pos, 1.5) and pos.distance_to(player.global_position) > 6.0:
			break
	e.global_position = pos
	e.face = atan2(player.global_position.x - pos.x, player.global_position.z - pos.z)
	enemies.append(e)

func in_arena(p: Vector3, margin: float) -> bool:
	return abs(p.x) < ARENA - margin and abs(p.z) < ARENA - margin

func on_kill(_e) -> void:
	kills += 1
	player.swag = min(100.0, player.swag + 6.0)
	var left := enemies.filter(func(x): return is_instance_valid(x) and x.state != "dead").size()
	if left == 0 and wave < WAVES.size() - 1:
		slowmo(0.7)
		banner("ЧИСТО", "следующая волна", Color(1, 0.85, 0.3))
	elif left == 0:
		slowmo(1.0)

func on_player_dead() -> void:
	over = true
	slowmo(1.2)
	await get_tree().create_timer(2.2, true, false, true).timeout
	_end_screen("ПАХАН УПАЛ", "кент не вытянет это один")

func _victory() -> void:
	over = true
	banner("ТОМСК ЗАЧИЩЕН", "убито врагов: %d" % kills, Color(1, 0.85, 0.3))
	await get_tree().create_timer(2.5, true, false, true).timeout
	_end_screen("ТОМСК ЗАЧИЩЕН", "дальше — первый сервер (в следующей обнове Godot-версии)")

# ---------------- снаряды хейтера ----------------
func spawn_bolt(pos: Vector3, dir: Vector3, dmg: float, owner_e) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.5)
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1, 0.5)
	l.light_energy = 1.5
	l.omni_range = 3.0
	m.add_child(l)
	add_child(m)
	m.global_position = pos
	bolts.append({"n": m, "v": dir * 9.0, "dmg": dmg, "life": 2.2, "from": owner_e})

func _update_bolts(dt: float) -> void:
	for b in bolts.duplicate():
		b["life"] -= dt
		var n: Node3D = b["n"]
		n.global_position += b["v"] * dt
		var pp: Vector3 = player.global_position + Vector3(0, 1.0, 0)
		if n.global_position.distance_to(pp) < 0.7:
			player.take_damage(b["dmg"], n.global_position, b["from"] if is_instance_valid(b["from"]) else null)
			b["life"] = 0.0
		if b["life"] <= 0.0 or not in_arena(n.global_position, -1.0):
			n.queue_free()
			bolts.erase(b)

# ---------------- эффекты ----------------
func hitstop(sec: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0

func slowmo(sec: float) -> void:
	Engine.time_scale = 0.3
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0

func popup(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = main.font
	l.font_size = 48
	l.pixel_size = 0.0042
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func shockwave(pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	m.material_override = mat
	add_child(m)
	m.global_position = pos + Vector3(0, 0.2, 0)
	m.scale = Vector3(0.5, 0.1, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(7, 0.1, 7), 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(m.queue_free)

func damage_flash() -> void:
	flash.color.a = 0.35
	shake(0.25)

func banner(title: String, sub: String, col: Color) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_title.add_theme_color_override("font_color", col)
	banner_t = 2.6

# ---------------- интерфейс ----------------
func _lbl(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", main.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	flash = ColorRect.new()
	flash.color = Color(0.8, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var name_l := _lbl("ПАХАН", 26)
	name_l.position = Vector2(40, get_viewport().get_visible_rect().size.y - 150)
	root.add_child(name_l)
	var bars := Control.new()
	bars.position = Vector2(40, get_viewport().get_visible_rect().size.y - 110)
	root.add_child(bars)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(420, 26)
	bars.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.9, 0.2, 0.18)
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(414, 20)
	bars.add_child(hp_fill)
	var sw_bg := ColorRect.new()
	sw_bg.color = Color(0, 0, 0, 0.6)
	sw_bg.position = Vector2(0, 34)
	sw_bg.size = Vector2(320, 16)
	bars.add_child(sw_bg)
	swag_fill = ColorRect.new()
	swag_fill.color = Color(1, 0.6, 0.15)
	swag_fill.position = Vector2(3, 37)
	swag_fill.size = Vector2(0, 10)
	bars.add_child(swag_fill)
	swag_label = _lbl("СВЭГ", 15, Color(0.75, 0.78, 0.85))
	swag_label.position = Vector2(332, 30)
	bars.add_child(swag_label)
	q_label = _lbl("", 15, Color(0.4, 0.85, 1))
	q_label.position = Vector2(0, 58)
	bars.add_child(q_label)
	wave_label = _lbl("", 22, Color(1, 0.9, 0.7))
	wave_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, 20)
	wave_label.size = Vector2(400, 30)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(wave_label)
	fps_label = _lbl("", 15, Color(0.5, 1, 0.5))
	fps_label.position = Vector2(get_viewport().get_visible_rect().size.x - 110, get_viewport().get_visible_rect().size.y - 34)
	root.add_child(fps_label)
	banner_title = _lbl("", 64)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.position = Vector2(0, 150)
	banner_title.size = Vector2(get_viewport().get_visible_rect().size.x, 80)
	root.add_child(banner_title)
	banner_sub = _lbl("", 22, Color(0.9, 0.9, 0.95))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.position = Vector2(0, 235)
	banner_sub.size = Vector2(get_viewport().get_visible_rect().size.x, 40)
	root.add_child(banner_sub)
	# пауза
	pause_panel = _panel("ПАУЗА", [["ПРОДОЛЖИТЬ", func(): set_paused(false)], ["В МЕНЮ", func(): _to_menu()]])
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.visible = false

func _panel(title: String, buttons: Array) -> Control:
	var p := ColorRect.new()
	p.color = Color(0.02, 0.02, 0.05, 0.8)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(p)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	var t := _lbl(title, 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.name = "Title"
	box.add_child(t)
	var sub := _lbl("", 22, Color(0.85, 0.85, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.name = "Sub"
	box.add_child(sub)
	for b in buttons:
		box.add_child(main.button(b[0], b[1]))
	return p

func set_paused(v: bool) -> void:
	if over:
		return
	get_tree().paused = v
	pause_panel.visible = v
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_CAPTURED

func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	main.show_menu()

func _end_screen(title: String, sub: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	end_panel = _panel(title, [["ЕЩЁ РАЗ", func(): main.start_game()], ["В МЕНЮ", func(): _to_menu()]])
	(end_panel.find_child("Sub", true, false) as Label).text = sub
	if main.autotest != "":
		end_panel.visible = false

func _update_hud(dt: float) -> void:
	hp_fill.size.x = 414.0 * clamp(player.hp / player.max_hp, 0.0, 1.0)
	var full: bool = player.swag >= 100.0
	swag_fill.size.x = 314.0 * (player.rage / 8.0 if player.rage > 0.0 else player.swag / 100.0)
	swag_fill.color = Color(1, 0.25, 0.05) if player.rage > 0.0 else (Color(1, 0.85, 0.3) if full else Color(1, 0.6, 0.15))
	swag_label.text = "ПЕРЕГРУЗ!" if player.rage > 0.0 else ("СВЭГ ПОЛОН — [R]" if full else "СВЭГ")
	q_label.text = "[Q] madk1d: ад-либ готов" if buddy.cd <= 0.0 else "[Q] madk1d: %.0f с" % buddy.cd
	var alive := enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead").size()
	wave_label.text = ("ВОЛНА %d / %d   ·   врагов: %d" % [wave + 1, WAVES.size(), alive]) if wave >= 0 and not over else ""
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	flash.color.a = max(0.0, flash.color.a - dt * 1.5)
	banner_t -= dt
	var a: float = clamp(banner_t / 0.5, 0.0, 1.0)
	banner_title.modulate.a = a
	banner_sub.modulate.a = a

# ---------------- автотест: бот играет сам, делает скриншоты и меряет FPS ----------------
func _autotest(dt: float) -> void:
	auto_t += dt
	player.hp = max(player.hp, 60.0)
	if auto_t > 2.0:
		fps_samples.append(Engine.get_frames_per_second())
	var near = null
	var nd := 1e9
	for e in enemies:
		if is_instance_valid(e) and e.alive():
			var d: float = e.global_position.distance_to(player.global_position)
			if d < nd:
				nd = d
				near = e
	var inp := {}
	if near:
		var to: Vector3 = near.global_position - player.global_position
		var want := atan2(-to.x, -to.z)
		cam_yaw = lerp_angle(cam_yaw, want, 1.0 - exp(-5.0 * dt))
		if nd > 2.0:
			inp["move"] = Vector2(0, 1)
		elif fmod(auto_t, 2.0) < dt:
			inp["heavy"] = "press"
		elif fmod(auto_t, 0.35) < dt:
			inp["attack"] = "press"
	if fmod(auto_t, 6.0) < dt:
		inp["roll"] = "press"
		inp["move"] = Vector2(1, 0)
	if player.swag >= 100.0:
		inp["rage"] = "press"
	if abs(auto_t - 12.0) < dt or abs(auto_t - 30.0) < dt:
		buddy.adlib()
	player.auto_input = inp
	for s in auto_shots.duplicate():
		if auto_t >= s:
			auto_shots.erase(s)
			_shot("shot_%02d.png" % int(s))
	if auto_t > 45.0 or over and auto_t > 8.0:
		fps_samples.sort()
		var avg := 0.0
		for f in fps_samples:
			avg += f
		avg /= max(1, fps_samples.size())
		print("AUTOTEST fps_avg=%.0f fps_min=%d wave=%d kills=%d hp=%.0f" % [avg, fps_samples[0] if fps_samples.size() else 0, wave + 1, kills, player.hp])
		get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(main.autotest.path_join(name))
