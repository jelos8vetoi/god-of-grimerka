## Проверка захвата цели (lockon.gd): -- --lockcheck=<папка>, с --resolution 1280x720.
## Захват по направлению камеры (а не просто ближайшего), враг за спиной камеры и за стеной не берётся, переключение
## колесом и устойчивость к дрожи камеры, снятие погибшей / слишком далёкой / пропавшей цели, обычный враг и босс,
## подброс в воздух, смена героя и стиля, iPod и пауза не отдают ввод захвату, камера доворачивает к цели,
## SpringArm у стены, после снятия — обычная камера. Снимки — l_*.png. В конце «LOCKCHECK ok» или «LOCKCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
var L

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("LOCK ok: " if c else "LOCK ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func clear() -> void:
	L.release("check")
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	game.enemies = []
	await frames(3)

func foe(at: Vector3, kind := "bot", boss := ""):
	var e = game._make_enemy(kind, boss, at)
	e.cool = 999.0
	e.max_hp = 99999.0
	e.hp = 99999.0
	return e

## нажать действие захвата настоящим событием мыши (как игрок)
func mouse(button: MouseButton) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(1)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

func stage() -> void:
	await clear()
	P.global_position = Vector3(0, 0.05, 4.0)
	P.velocity = Vector3.ZERO
	P.face = PI
	P.state = "move" if P.style.id != "tyaga812" else P.state
	game.cam_yaw = 0.0
	game.cam_pitch = -0.25
	await frames(10)

func _run() -> void:
	P = game.player
	L = game.lock
	game.ch = 0
	game._load_chapter(false)
	game.mode = "fight"
	game.pending = []
	game.waves = []
	game.over = false
	game.dlg_box.visible = false
	game.tag.auto_assist = false
	game.buddy.wait = 999.0
	# ---- по направлению камеры, а не ближайший ----
	await stage()
	var ahead = foe(Vector3(0.5, 0.05, -4.0))           # перед камерой, 8 м
	var side = foe(Vector3(-4.5, 0.05, 2.0))            # ближе, но сбоку
	var back = foe(Vector3(0.3, 0.05, 6.5))             # ещё ближе, но за спиной
	await frames(80)
	game.wave_wait = 9999.0
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(L.active() and L.target == ahead, "СКМ — захват цели перед камерой, а не ближайшей сбоку или за спиной")
	# камера доворачивает
	game.cam_yaw = 0.9
	await frames(60)
	var fw: Vector3 = -game.cam.global_transform.basis.z
	fw.y = 0
	var to: Vector3 = ahead.global_position - P.global_position
	to.y = 0
	ok(rad_to_deg(fw.normalized().angle_to(to.normalized())) < 15.0, "камера плавно вернулась к цели (%.0f°)" % rad_to_deg(fw.normalized().angle_to(to.normalized())))
	await shot("l_locked.png")
	# ---- переключение колесом ----
	await mouse(MOUSE_BUTTON_WHEEL_DOWN)
	var t1 = L.target
	await frames(30)
	await mouse(MOUSE_BUTTON_WHEEL_UP)
	var t2 = L.target
	ok(t1 != ahead and t2 == ahead or (t1 != null and t2 != null and t1 != t2), "колесо — следующая и предыдущая цель (%s → %s)" % [str(t1 == ahead), str(t2 == ahead)])
	# дрожь камеры не перещёлкивает цель
	var keep = L.target
	for i in 30:
		game.cam_yaw += randf_range(-0.03, 0.03)
		await frames(1)
	ok(L.target == keep, "мелкое движение камеры цель не меняет")
	# ---- снятие: погибла ----
	L.lock_to(side)
	side.hp = 1.0
	side.take_hit(50.0, Vector3(0, 0, -1), 1.0)
	await frames(5)
	ok(not L.active() and L.events.back()[0] == "off", "цель погибла — захват снят сам (%s)" % str(L.events.back()))
	# ---- снятие: далеко ----
	L.lock_to(ahead)
	ahead.global_position = Vector3(0.0, 0.05, -26.0)
	await frames(5)
	ok(not L.active() and String(L.events.back()[1]) == "far", "цель ушла далеко — захват снят (%s)" % str(L.events.back()))
	# ---- за стеной не берётся ----
	await stage()
	var hidden = foe(Vector3(0, 0.05, -3.0))
	await frames(80)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 | 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 4.0, 0.5)
	cs.shape = bs
	sb.add_child(cs)
	game.add_child(sb)
	sb.global_position = Vector3(0, 2.0, 0.5)
	await frames(3)
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(not L.active(), "враг за стеной не захватывается")
	sb.queue_free()
	await frames(3)
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(L.active() and L.target == hidden, "стену убрали — тот же враг захватывается")
	# ---- подброс в воздух: захват держится, камера смотрит выше ----
	var pitch0: float = game.cam_pitch
	var hl := HitInfo.new()
	hl.damage = 1.0
	hl.launch = 9.0
	hl.dir = Vector3(0, 0, -1)
	hidden.take_hit_info(hl)
	await frames(20)
	ok(L.active() and hidden.state == "air", "цель в воздухе — захват держится")
	ok(game.cam_pitch > pitch0, "цель в воздухе — камера смотрит выше (%.2f → %.2f)" % [pitch0, game.cam_pitch])
	await shot("l_air.png")
	var nn := 0
	while hidden.state == "air" and nn < 200:
		await frames(1)
		nn += 1
	# ---- смена героя и стиля ----
	game.tag.tag_cd = 0.0
	game.swap_heroes()
	await frames(50)
	ok(L.active() and L.target == hidden, "смена героя — цель та же")
	P.auto_input = {"style2": "press"}
	await frames(1)
	P.auto_input = {}
	await frames(60)
	ok(L.active(), "смена стиля — захват держится")
	# удар идёт в захваченную цель (она в досягаемости)
	P.global_position = hidden.global_position + Vector3(0, 0, 2.2)
	await frames(5)
	var face_to: float = L.face_to(P.global_position, 99.0)
	ok(not is_nan(face_to) and absf(angle_difference(P.combat.target_face(2.5, Vector3(1, 0, 0)), face_to)) < 0.01, "удар разворачивает героя к захваченной цели, даже если жмёшь вбок")
	game.tag.tag_cd = 0.0
	game.swap_heroes()
	await frames(50)
	# ---- iPod и пауза: ввод захвату не уходит ----
	L.release("check")
	game.ipod.open()
	await frames(20)
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(not L.active(), "iPod открыт — СКМ не захватывает")
	game.ipod.close()
	await frames(30)
	await mouse(MOUSE_BUTTON_MIDDLE)
	var had = L.target
	game.set_paused(true)
	await frames(10)
	await mouse(MOUSE_BUTTON_WHEEL_DOWN)
	ok(L.target == had, "пауза — колесо цель не переключает")
	game.set_paused(false)
	await frames(30)
	# ---- босс ----
	await stage()
	var boss = foe(Vector3(0, 0.05, -4.0), "", "golem")
	boss.special_cd = 999.0
	await frames(100)
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(L.active() and L.target == boss, "босс захватывается")
	await frames(30)
	await shot("l_boss.png")
	# ---- SpringArm у стены: камера не уходит сквозь неё ----
	var wall := StaticBody3D.new()
	wall.collision_layer = 1 | 8
	var wcs := CollisionShape3D.new()
	var wbs := BoxShape3D.new()
	wbs.size = Vector3(8.0, 6.0, 0.4)
	wcs.shape = wbs
	wall.add_child(wcs)
	game.add_child(wall)
	wall.global_position = P.global_position + Vector3(0, 3.0, 2.0)      # прямо за героем
	await frames(40)
	ok(game.spring.get_hit_length() < game.spring.spring_length - 0.3, "стена за спиной — SpringArm укорачивает камеру (%.2f из %.2f)" % [game.spring.get_hit_length(), game.spring.spring_length])
	wall.queue_free()
	# ---- отпустить: обычная камера ----
	await mouse(MOUSE_BUTTON_MIDDLE)
	ok(not L.active() and String(L.events.back()[1]) == "toggle", "СКМ ещё раз — захват снят")
	var yaw0: float = game.cam_yaw
	await frames(40)
	ok(absf(angle_difference(yaw0, game.cam_yaw)) < 0.001, "после снятия камера сама не крутится")
	await frames(20)
	ok(L.marker.visible == false, "маркер погас")
	print("LOCKCHECK ok" if fails == 0 else "LOCKCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
