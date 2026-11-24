## Проверка нового ДВОРА в игре: «-- --dvor2view=<папка>».
## Строит район (G67Dvor2), снимает кадры с уровня глаз и сверху, меряет кадр в каждой точке, проходит телом-ботом три маршрута
## (упёрся — печатает где), проверяет решётку арки: закрыта — к лестнице не пройти; open_gate() — спуск до нижней площадки.
## Печатает строки «DVOR2 | …» и итог «DVOR2VIEW ok» / «DVOR2VIEW ОШИБКА».
extends Node

var out := ""
var world: G67Dvor2
var cam: Camera3D
var bot: CharacterBody3D
var errors: Array = []

const SHOTS := [
	["01_main_street", [-58, -20.5, 1.9], [40, -16, 4], 60],
	["02_home_yard", [-22, -104, 2.0], [16, -72, 5], 62],
	["03_garages", [-72, 34, 1.9], [-140, 34.5, 1.6], 62],
	["04_market", [-52, -17.5, 1.8], [-10, -9, 2.4], 60],
	["05_court", [-22, 97, 5.5], [9, 114, 1.2], 62],
	["06_aerial", [-30, -280, 170], [0, -10, 0], 55],
	["07_towers_gate", [10, 30, 1.9], [6, 80, 13], 62],
	["08_shawarma", [37, -19.5, 1.8], [45, -11, 2.8], 58],
	["09_mcqueen", [82, -18.6, 1.7], [93, -9.5, 1.3], 58],
	["10_brick_yard", [-74, -78, 1.9], [-110, -112, 7], 62],
	["11_workshop", [-66.5, 23.5, 1.8], [-55.5, 21, 1.0], 62],
	["12_school", [-84, 96, 1.9], [-108, 120, 6], 62],
	["13_arch_from_court", [22, 104, 1.9], [36, 117, 3.2], 62],
	["14_arch_gate", [31.5, 119.6, 1.75], [40, 118, 0.6], 66],
	["15_arch_east", [62, 108, 1.9], [53, 116, 3.0], 62],
	["16_top", [0, 0, 420], [0, 0.01, 0], 40],
]

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.03, 0.05, 0.16)
	sm.sky_horizon_color = Color(0.46, 0.22, 0.2)
	sm.ground_bottom_color = Color(0.03, 0.04, 0.1)
	sm.ground_horizon_color = Color(0.46, 0.22, 0.2)
	sm.sky_curve = 0.25
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.56)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.3, 0.5)
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.62, 0.72, 1.0)
	key.light_energy = 0.5
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 90.0
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-140), 0)
	add_child(key)
	cam = Camera3D.new()
	cam.far = 1500.0
	add_child(cam)
	cam.current = true
	var t0 := Time.get_ticks_msec()
	world = G67Dvor2.new()
	add_child(world)
	world.build()
	print("DVOR2 | сборка %d мс | моделей %d, преград %d, ламп %d | нет файлов: %d" % [Time.get_ticks_msec() - t0, int(world.count["models"]), int(world.count["bodies"]),
		int(world.count["lights"]), world.missing.size()])
	for m in world.missing:
		print("DVOR2 | НЕТ ", m)
		errors.append("нет файла " + String(m))
	_run.call_deferred()

func _fps(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
	return float(frames) * 1000000.0 / float(maxi(Time.get_ticks_usec() - t, 1))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for i in 20:
		await get_tree().process_frame
	var worst := 999.0
	for s in SHOTS:
		var p: Array = s[1]
		var l: Array = s[2]
		cam.fov = float(s[3])
		cam.position = G67Dvor2.to3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(G67Dvor2.to3(float(l[0]), float(l[1]), float(l[2])), Vector3.UP if String(s[0]) != "16_top" else Vector3(0, 0, -1))
		for i in 8:
			await get_tree().process_frame
		var f: float = await _fps(40)
		worst = minf(worst, f)
		get_viewport().get_texture().get_image().save_png(out.path_join("g_" + String(s[0]) + ".png"))
		print("DVOR2 | кадр %s | %.0f к/с | объектов %d, вызовов отрисовки %d" % [String(s[0]), f,
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])
	print("DVOR2 | худший кадр %.0f к/с" % worst)
	await _walks()
	await _gate()
	print("DVOR2VIEW ok" if errors.is_empty() else "DVOR2VIEW ОШИБКА: " + "; ".join(errors))
	get_tree().quit()

func _make_bot(at: Vector3) -> void:
	if is_instance_valid(bot):
		bot.queue_free()
	bot = CharacterBody3D.new()
	bot.collision_layer = 0
	bot.collision_mask = 1
	var cs := CollisionShape3D.new()
	var cp := CapsuleShape3D.new()
	cp.radius = 0.35
	cp.height = 1.7
	cs.shape = cp
	cs.position.y = 0.85
	bot.add_child(cs)
	add_child(bot)
	bot.global_position = at + Vector3(0, 0.3, 0)

## Идти к точке по прямой с гравитацией; true — дошёл ближе 1,2 м за отведённое время
func _go(to: Vector3, limit: float, tol := 1.2) -> bool:
	var t := 0.0
	while t < limit:
		await get_tree().physics_frame
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		t += dt
		var d := to - bot.global_position
		d.y = 0.0
		if d.length() < tol:
			return true
		var v := d.normalized() * 6.0
		bot.velocity = Vector3(v.x, bot.velocity.y - 20.0 * dt, v.z)
		bot.move_and_slide()
	return false

func _walks() -> void:
	var names := ["главный", "западный", "восточный"]
	var n := 0
	for pts_v in world.layout.get("paths", []):
		var pts: Array = pts_v
		if pts.size() < 6 or n >= 3:
			continue
		_make_bot(G67Dvor2.to3(float(pts[0][0]), float(pts[0][1])))
		var ok := true
		var length := 0.0
		for i in range(1, pts.size()):
			var a := Vector2(float(pts[i - 1][0]), float(pts[i - 1][1]))
			var b := Vector2(float(pts[i][0]), float(pts[i][1]))
			length += a.distance_to(b)
			var got: bool = await _go(G67Dvor2.to3(b.x, b.y), a.distance_to(b) / 6.0 * 2.0 + 3.0)
			if not got:
				ok = false
				var bp := bot.global_position
				print("DVOR2 | маршрут «%s»: упёрся у (%.1f; %.1f) по пути к точке %d (%.0f; %.0f)" % [names[n], bp.x, -bp.z, i, b.x, b.y])
				errors.append("маршрут «%s» не пройден" % names[n])
				break
		if ok:
			print("DVOR2 | маршрут «%s»: пройден, %.0f м" % [names[n], length])
		n += 1

func _gate() -> void:
	if world.arch.is_empty():
		errors.append("нет арки")
		return
	var top := world.stairs_top()
	var before := top + Vector3(-3.0, 0, 0)
	_make_bot(before)
	var passed: bool = await _go(top + Vector3(4.0, 0, 0), 4.0)
	print("DVOR2 | решётка закрыта: к лестнице %s" % ("ПРОШЁЛ — ошибка" if passed else "не пройти"))
	if passed:
		errors.append("закрытая решётка пропускает")
	world.open_gate()
	for i in 170:
		await get_tree().process_frame
	cam.fov = 66.0
	cam.position = before + Vector3(-2.5, 1.75, 1.4)
	cam.look_at(top + Vector3(5.0, -0.8, 0), Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("g_17_gate_open.png"))
	_make_bot(before)
	var bottom := world.stairs_bottom()
	var down: bool = await _go(bottom, 9.0, 0.35)
	var by := bot.global_position.y
	print("DVOR2 | решётка открыта: спуск %s, высота бота %.2f м (низ −5,0)" % ["пройден" if down and by < -4.5 else "НЕ пройден", by])
	if not (down and by < -4.5):
		errors.append("спуск по лестнице не пройден")
	cam.position = bot.global_position + Vector3(-1.0, 1.7, 0)
	cam.look_at(world.stairs_top() + Vector3(0, 1.0, 0), Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("g_18_from_bottom.png"))
	var lk: bool = await _go(world.link_point(), 6.0)
	print("DVOR2 | точка стыка с Подземкой: %s (%.1f; %.1f; %.1f)" % ["дошёл" if lk else "НЕ дошёл", world.link_point().x, world.link_point().y, world.link_point().z])
	if not lk:
		errors.append("до точки стыка не дойти")
