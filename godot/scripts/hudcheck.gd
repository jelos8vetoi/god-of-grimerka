## Проверка боевого HUD в игре: -- --hudcheck=<папка> (запускать с --resolution 1280x720 и ещё раз в узком окне).
## Настоящая глава и игровая камера. Снимает HUD за Пахана и madk1d на всех шести стилях, смену героя по Tab
## по кадрам, состояния способностей; проверяет, что HUD показывает настоящие данные игры, и печатает FPS в бою.
## В конце — «HUDCHECK ok» или «HUDCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var H: CombatHud
var started := false
var frame_n := 0

func _ready() -> void:
	cam = Camera3D.new()          # игра ждёт камеру у режиссёра; кадр ведёт обычная игровая камера
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
	print(("HUDCHECK ok: " if c else "HUDCHECK ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out.path_join(nm))
	# тот же кадр, только угол с HUD, увеличенный втрое — чтобы рассмотреть мелкие детали
	var z: Image = img.get_region(Rect2i(0, int(img.get_height() * 0.74), int(img.get_width() * 0.4), int(img.get_height() * 0.26)))
	z.resize(z.get_width() * 3, z.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	z.save_png(out.path_join("zoom_" + nm))

func tap(a: String) -> void:
	await get_tree().physics_frame
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}

func to_style(key: String) -> void:
	await tap(key)
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 120:
		await get_tree().physics_frame
		n += 1
	await frames(70)

func names() -> Array:
	var out_n: Array = []
	for c in H.cards:
		out_n.append((c["name"] as Label).text)
	return out_n

func live_previews() -> Array:
	var ids: Array = []
	for id in H.previews:
		if (H.previews[id]["vp"] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			ids.append(id)
	return ids

func keys() -> Array:
	var ks: Array = []
	for a in H.abilities(P):
		ks.append("%s:%s" % [a[0], a[1]])
	return ks

func _run() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	H = game.combat_hud
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.inv = 9999.0
	for x in [-2.5, 0.0, 2.5]:
		game.spawn_enemy("bot", P.global_position + Vector3(x, 0, -5.0))
	for e in game.enemies:
		if is_instance_valid(e):
			e.hp = 99999.0
	await frames(90)
	ok(H != null and H.visible and H.shown_hero == "pahan" and H.name_l.text == "ПАХАН", "HUD на экране, герой — %s" % H.name_l.text)
	ok(names() == ["БАЛОН", "ВОДЯРА", "ТЯГА-812"], "карточки Пахана: %s" % str(names()))
	# ---- Пахан: три стиля ----
	P.hp = P.max_hp * 0.85
	P.swag = 62.0
	game.buddy.cd = 4.2
	await frames(4)
	await shot("01_pahan_balon.png")
	ok(H.hp_text.text == "%d / %d" % [int(ceil(P.hp)), int(P.max_hp)] and H.sw_text.text == "62%", "полосы: HP %s, СВЭГ %s" % [H.hp_text.text, H.sw_text.text])
	ok(keys() == ["Q:АД-ЛИБ", "E:HEAT", "F:ВОДЯРА"] and String((H.slots[0]["time"] as Label).text) != "", "способности балона: %s; ад-либ на перезарядке: %s с" % [str(keys()), (H.slots[0]["time"] as Label).text])
	ok(live_previews() == ["vozduh"], "перерисовывается только выбранная модель: %s" % str(live_previews()))
	await to_style("style2")
	await shot("02_pahan_bottles.png")
	ok(P.style.id == "bottles" and H.shown_style == "bottles" and keys() == ["Q:АД-ЛИБ", "E:HEAT", "R:ПЕРЕГРУЗ"], "[2] Водяра: герой тот же (%s), способности %s" % [P.hero, str(keys())])
	await to_style("style3")
	await shot("03_pahan_tyaga.png")
	ok(P.style.id == "tyaga812" and keys()[1] == "E:ЕЗДА", "[3] ТЯГА-812: способности %s" % str(keys()))
	await to_style("style1")
	# ---- способности: настоящая перезарядка ----
	game.buddy.cd = 0.0
	await frames(3)
	var before: float = game.buddy.cd
	await tap("adlib")
	Input.action_press("adlib")
	await frames(2)
	Input.action_release("adlib")
	game.buddy.adlib()
	await frames(20)
	var k_q: float = float(H.abilities(P)[0][3])
	ok(game.buddy.cd > before and k_q < 1.0 and String((H.slots[0]["time"] as Label).text) != "", "Q — ад-либ: перезарядка пошла (%.1f с), слот показывает %s" % [game.buddy.cd, (H.slots[0]["time"] as Label).text])
	P.swag = 100.0
	await frames(3)
	await shot("04_pahan_full.png")
	ok(H.sw_text.text.begins_with("ПОЛОН"), "полный СВЭГ: %s" % H.sw_text.text)
	# ---- бой: FPS с HUD ----
	var t0 := Time.get_ticks_usec()
	var f0 := Engine.get_frames_drawn()
	for i in 6:
		await tap("attack")
		await frames(18)
	var fps: float = (Engine.get_frames_drawn() - f0) / max(0.001, (Time.get_ticks_usec() - t0) / 1000000.0)
	await shot("05_pahan_fight.png")
	print("HUDCHECK FPS в бою: %.0f" % fps)
	var n := 0
	while P.state != "move" and n < 200:
		await get_tree().physics_frame
		n += 1
	# ---- Tab: смена героя по кадрам ----
	P.swag = 30.0
	await tap("tag")
	await frames(5)
	await shot("06_tab_a.png")
	await frames(6)
	await shot("07_tab_b.png")
	await frames(70)
	await shot("08_madk_skate.png")
	ok(P.hero == "madk1d" and H.shown_hero == "madk1d" and H.name_l.text == "MADK1D" and names() == ["СКЕЙТ", "ГИТАРА", "BREAKER"], "Tab: герой %s, карточки %s" % [H.name_l.text, str(names())])
	ok(float(H.portraits["madk1d"]["k"]) > 0.99 and float(H.portraits["pahan"]["k"]) < 0.01, "портреты поменялись местами")
	ok(keys() == ["Q:АД-ЛИБ", "F:ТРЮК", "R:ПЕРЕГРУЗ"], "способности скейта: %s" % str(keys()))
	await to_style("style2")
	P.guitar.bars = 2
	await frames(3)
	await shot("09_madk_guitar.png")
	ok(P.hero == "madk1d" and P.style.id == "guitar" and keys() == ["Q:АД-ЛИБ", "E:DISTORTION", "F:POWER CHORD"], "[2] гитара: способности %s" % str(keys()))
	await to_style("style3")
	P.breaker.flow = 3
	P.breaker.idle_t = 0.0
	await frames(3)
	await shot("10_madk_breaker.png")
	ok(P.style.id == "breaker" and keys() == ["Q:АД-ЛИБ", "F:FREEZE", "R:ПЕРЕГРУЗ"] and live_previews() == ["breaker"], "[3] Breaker: способности %s, живая модель %s" % [str(keys()), str(live_previews())])
	ok(H.previews.size() == 6, "собраны превью всех шести стилей (%d)" % H.previews.size())
	game.tag.tag_cd = 0.0      # первая смена могла оказаться командным приёмом с долгой перезарядкой
	await tap("tag")
	await frames(80)
	await shot("11_back_to_pahan.png")
	ok(P.hero == "pahan" and H.name_l.text == "ПАХАН" and P.heroes["madk1d"]["style"] == "breaker", "Tab обратно: Пахан; стиль madk1d сохранён (%s)" % P.heroes["madk1d"]["style"])
	print("HUDCHECK ok" if fails == 0 else "HUDCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
