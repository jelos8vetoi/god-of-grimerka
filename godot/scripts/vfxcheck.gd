## Проверка эффектов боя по профилям (vfx_profiles.gd, fx.gd): -- --vfxcheck=<папка>, запускать с --resolution 1280x720.
## 1) реестр: у каждой атаки шести стилей есть профиль, рисунки не совпадают; строки «VFXREG id | название | вид | стиль | герой |
##    было | профиль» — аудит; 2) шейдеры vfx_arc и vfx_ring собираются; 3) эффект рисует только настоящее попадание:
##    промах — ничего, попадание — в тот же кадр, что и урон; 4) не больше двух полных профилей за кадр; 5) финалы девяти пар;
## 6) «меньше вспышек» и «тряска 0 %»; 7) кадр: среднее и 95-й процентиль без эффектов и под нагрузкой.
## Снимки: листы по стилям (vfx_<стиль>.png, клетки по порядку реестра), финалы пар (vfx_duo.png).
## В конце «VFXCHECK ok» или «VFXCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
var start_f := -1             # кадр начала удара (лямбда пишет в поле: локальные она копирует)
const CELL := Vector2i(320, 180)
const COLS := 5

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return true

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("VFX ok: " if c else "VFX ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func stage() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.auto_input = {}
	P.combat.interrupt()
	game.tag.auto_assist = false
	game.buddy.wait = 999.0
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	game.enemies = []
	await frames(2)
	game.mode = "fight"

func foe(at: Vector3):
	var e = game._make_enemy("bot", "", at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = 99999.0
	e.hp = 99999.0
	return e

func hit_info(sid: String, a: AttackData, e) -> HitInfo:
	var h := HitInfo.new()
	h.damage = 0.0
	h.attack_id = a.id
	h.style_id = sid
	h.power = a.power
	h.heavy = a.heavy
	h.dir = Vector3(0, 0, -1)
	h.source = P
	h.pos = e.global_position + Vector3(0, float(e.height) * 0.62, 0)
	return h

## камера сбоку от цели
func aim(e) -> void:
	var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
	cam.global_position = c + Vector3(4.2, 1.4, 1.6)
	cam.look_at(c, Vector3.UP)
	cam.fov = 55.0
	cam.make_current()

func grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var w: int = int(sz.y * 16 / 9)
	var crop := img.get_region(Rect2i((sz.x - w) / 2, 0, w, sz.y))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return crop

func sheet(cells: Array, name: String) -> void:
	if cells.is_empty():
		return
	var rows: int = (cells.size() + COLS - 1) / COLS
	var img := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.06))
	for i in cells.size():
		var c: Image = cells[i]
		c.convert(Image.FORMAT_RGBA8)
		img.blit_rect(c, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	img.save_png(out.path_join(name))

func _run() -> void:
	await stage()
	var fx = game.fx
	# ---- 1. реестр ----
	var all: Array = VfxProfiles.all_attacks()
	var sigs := {}
	var dup := 0
	var empty := 0
	for it in all:
		var sid: String = it[0]
		var a: AttackData = it[1]
		var prof: Dictionary = VfxProfiles.of(a, sid)
		var prims: Array = prof["prims"]
		if prims.is_empty():
			empty += 1
		var sig: String = String(prof["sig"]).replace(sid + ":", "")
		if sigs.has(sig):
			dup += 1
			print("VFX совпал рисунок: %s и %s" % [sigs[sig], a.id])
		sigs[sig] = sid + "/" + a.id
		var kinds: Array = []
		for pr in prims:
			kinds.append(String(pr["p"]) + ("(" + String(pr.get("kind", "")) + ")" if pr.has("kind") else ""))
		var was := "fx.hit tier %d + %s" % [a.power, a.feedback if a.feedback != "" else ["hit_light", "hit_heavy", "hit_super"][clampi(a.power, 0, 2)]]
		print("VFXREG %s | %s | %s | %s | %s | %s | %s" % [a.id, a.title if a.title != "" else "—", a.kind, sid, Styles.by_id(sid).owner, was, ", ".join(kinds)])
	ok(all.size() >= 100 and empty == 0, "у всех %d атак шести стилей есть профиль" % all.size())
	ok(dup == 0, "рисунки атак не совпадают (совпадений %d)" % dup)
	# ---- 2. шейдеры ----
	for path in ["res://assets/shaders/vfx_arc.gdshader", "res://assets/shaders/vfx_ring.gdshader"]:
		var sh := load(path) as Shader
		var n_u: int = sh.get_shader_uniform_list().size() if sh != null else -1
		ok(sh != null and sh.code.length() > 100, "шейдер %s загружен (%d общих параметров)" % [path.get_file(), n_u])
	# ---- 3. только по попаданию ----
	var e = foe(P.global_position + Vector3(0, 0, -1.6))
	await frames(10)
	var p0: int = int(fx.stats["profiles"])
	e.global_position = P.global_position + Vector3(0, 0, 30.0)     # далеко: удар мимо
	P.auto_input = {"attack": "press"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	P.auto_input = {}
	await frames(4)
	var swung: bool = P.combat.cur != null
	await frames(46)
	ok(swung and int(fx.stats["profiles"]) == p0, "удар мимо (удар был: %s) — профиль не рисуется" % swung)
	P.combat.interrupt()
	P.state = "move"
	e.global_position = P.global_position + Vector3(0, 0, -1.4)
	await frames(20)
	var hp0: float = e.hp
	e.hp = 99999.0
	hp0 = e.hp
	start_f = -1
	var hit_f := -1
	var vfx_f := -1
	P.combat.attack_started.connect(func(_a): if start_f < 0: start_f = Engine.get_process_frames(), CONNECT_ONE_SHOT)
	P.auto_input = {"attack": "press"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	P.auto_input = {}
	for i in 90:
		await get_tree().physics_frame
		if hit_f < 0 and e.hp < hp0:
			hit_f = Engine.get_process_frames()
		if vfx_f < 0 and int(fx.stats["profiles"]) > p0:
			vfx_f = Engine.get_process_frames()
	ok(hit_f > 0 and vfx_f == hit_f, "профиль — в кадр попадания (удар начат %d, урон %d, эффект %d)" % [start_f, hit_f, vfx_f])
	ok(start_f < 0 or vfx_f > start_f, "эффект попадания не раньше удара")
	# ---- 4. лимит за кадр ----
	var many: Array = []
	for i in 5:
		many.append(foe(P.global_position + Vector3(-3.0 + i * 1.5, 0, -6.0)))
	await frames(5)
	var s0: int = int(fx.stats["skipped"])
	var q0: int = int(fx.stats["profiles"])
	var a0: AttackData = Styles.by_id("vozduh").attack("vz_light1")
	for en in many:
		en.take_hit_info(hit_info("vozduh", a0, en))
	ok(int(fx.stats["profiles"]) - q0 == 2 and int(fx.stats["skipped"]) - s0 == 3, "пять целей в одном кадре: 2 полных профиля, 3 без (%d / %d)" % [int(fx.stats["profiles"]) - q0, int(fx.stats["skipped"]) - s0])
	for en in many:
		en.queue_free()
	await frames(30)
	# ---- 5. листы по стилям ----
	P.global_position = Vector3(0, 0.05, 20.0)
	e.global_position = Vector3(0, 0.05, 0.0)
	e.hp = 99999.0
	await frames(20)
	aim(e)
	for sid in Styles.ORDER:
		var cells: Array = []
		var s: StyleData = Styles.by_id(sid)
		var ids: Array = s.attacks.keys()
		for aid in ids:
			var a: AttackData = s.attacks[aid]
			e.global_position = Vector3(0, 0.05, 0.0)
			e.velocity = Vector3.ZERO
			e.state = "chase"
			await frames(40)
			var before: int = int(fx.stats["prims"])
			e.take_hit_info(hit_info(sid, a, e))
			await frames(3)
			cells.append(await grab())
			if int(fx.stats["prims"]) == before:
				ok(false, "%s: профиль ничего не нарисовал" % aid)
		sheet(cells, "vfx_%s.png" % sid)
		print("VFX лист %s: %d атак" % [sid, ids.size()])
	# ---- 6. финалы пар ----
	var duo_cells: Array = []
	for pa in ["vozduh", "bottles", "tyaga812"]:
		for pb in ["skateboard", "guitar", "breaker"]:
			await frames(25)
			fx.duo_finale(e.global_position + Vector3(0, 1.0, 0), pa, pb, Vector3(0, 0, -1), 1.0)
			await frames(5)
			duo_cells.append(await grab())
	sheet(duo_cells, "vfx_duo.png")
	ok(duo_cells.size() == 9, "финалы девяти пар сняты")
	# ---- 7. доступность ----
	var lf0 = Opts.v("less_flash")
	var sh0 = Opts.v("shake")
	Opts.put("less_flash", true)
	ok(fx.flash_k == 0.0, "«меньше вспышек»: вспышки приглушены")
	Opts.put("shake", 0.0)
	var tr0: float = game.trauma
	game.shake(0.6)
	ok(absf(game.trauma - tr0) < 0.0001, "«тряска 0 %»: камера не трясётся")
	Opts.put("less_flash", lf0)
	Opts.put("shake", sh0)
	# ---- 8. кадр: без эффектов и под нагрузкой ----
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var crowd: Array = []
	for i in 8:
		crowd.append(foe(Vector3(-4.0 + (i % 4) * 2.6, 0.05, -1.5 - (i / 4) * 2.4)))
	await frames(60)
	var base := await measure(180, [], [])
	var old := await measure(180, crowd, [], true)
	var heavy: Array = []
	for it in all:
		if (it[1] as AttackData).power >= 1:
			heavy.append(it)
	var stress := await measure(180, crowd, heavy)
	# по примитивам: сколько стоит каждый вид при той же нагрузке
	for kind in ["arc", "shock", "debris", "streaks", "spark", "flash", "twirl", "crack"]:
		game.fx.only = kind
		var part := await measure(120, crowd, heavy)
		print("VFX кадр, только «%s»: среднее %.2f мс, 95%% %.2f мс" % [kind, part[0], part[1]])
	game.fx.only = ""
	print("VFX кадр без эффектов: среднее %.2f мс, 95%% %.2f мс" % [base[0], base[1]])
	print("VFX кадр, старый путь (2 тяжёлых fx.hit каждый кадр): среднее %.2f мс, 95%% %.2f мс" % [old[0], old[1]])
	print("VFX кадр, профили (те же 2 попадания + 2 тяжёлых профиля каждый кадр): среднее %.2f мс, 95%% %.2f мс" % [stress[0], stress[1]])
	ok(stress[1] < 33.3, "под нагрузкой 95-й процентиль кадра < 33 мс (%.2f)" % stress[1])
	print("VFX узлов в fx: %d, дуг %d, колец %d" % [fx.get_child_count(), fx.arc_pool.size(), fx.ring_pool.size()])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("VFXCHECK ok" if fails == 0 else "VFXCHECK ОШИБОК: %d" % fails)
	get_tree().quit()

## n кадров; если list не пуст — каждый кадр два тяжёлых профиля по случайным целям. → [среднее мс, 95-й процентиль мс]
func measure(n: int, list: Array, pool: Array, base_only := false) -> Array:
	var times: Array = []
	var t := Time.get_ticks_usec()
	for i in n:
		if base_only:
			for k in 2:
				var eb = list[(i + k * 3) % list.size()]
				game.fx.hit(eb.global_position + Vector3(0, 1.0, 0), Vector3(0, 0, -1), 1, Color(1.0, 0.8, 0.45))
		elif not list.is_empty():
			for k in 2:
				var it: Array = pool[(i * 2 + k) % pool.size()]
				var en = list[(i + k * 3) % list.size()]
				if is_instance_valid(en):
					game.fx.hit(en.global_position + Vector3(0, 1.0, 0), Vector3(0, 0, -1), 1, Color(1.0, 0.8, 0.45))
					game.fx.attack_vfx(hit_info(String(it[0]), it[1], en), en)      # только эффект: реакцию врага не меряем
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - t) / 1000.0)
		t = now
	times.sort()
	var sum := 0.0
	for x in times:
		sum += float(x)
	return [sum / times.size(), float(times[int(times.size() * 0.95)])]
