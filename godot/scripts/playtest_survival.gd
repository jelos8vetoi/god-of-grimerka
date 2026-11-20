## Плейтест Endless Survival «руками»: `--resolution 1280x720 -- --playtest-survival=<папка> [--pt-run=СЕК]`.
## Игра настоящая, из меню «ОБЛАКО-ТВ» (канал ROGUELIKE → НАЧАТЬ ЗАБЕГ); героем управляют НАСТОЯЩИЕ КЛАВИШИ И КНОПКИ
## МЫШИ (Input.parse_input_event — тот же путь, что у клавиатуры игрока): WASD — идти к ближайшему врагу в восьми
## направлениях от камеры, ЛКМ / ПКМ — удары, Shift — уклонение от замаха, 1/2/3 — стиль, Tab — смена героя,
## T — дуэт, G — Overdrive, R — ПЕРЕГРУЗ, Q — ад-либ, 1/2/3 в окне усилений, Esc и W/S/Enter — пауза и её меню,
## Enter / D на экране гибели. Боец — простой «человек»: дерётся без хитростей, уклоняется не всегда, гибнет.
## Что пишет (строки «PT | …»): раз в 5 с забега — время, угроза, живые враги, здоровье, побеждённые; события,
## элиты, босс, выбор усилений, гибель, рекорды, отчёты. Снимки — на событиях и раз в 20 с.
## Мышью камеру не водит: в проверках курсор не захватывается (MouseMode.make_quiet), камеру ведёт сама игра.
## Отклонения от «как у игрока» названы в выводе словом «ПОДСТРОЙКА» (например, босс раньше срока во втором забеге).
## Рекорды и отчёты Survival пишутся в user://, поэтому запуск — только со своей папкой данных
## (tools/checks.cjs её даёт сам; вручную — задать APPDATA на временную папку, иначе плейтест откажется работать).
extends Node

const Records := preload("res://scripts/survival_records.gd")
const SAVE := "user://grimerka_save.json"

var main
var out := ""
var held := {}
var fails := 0
var run_len := 240.0          # сколько секунд забега играть честно в первом забеге (--pt-run=)
var fighting := false
var idle := false             # стоять и ничего не делать (чтобы погибнуть)
var acc := {}
var seen := {}
var log_t := 0.0
var shot_t := 0.0
var shots := 0
var drafts := 0
var draft_busy := false
var style_n := 0
var peak_alive := 0
var rolls := 0
var clicks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-run="):
			run_len = float(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func say(s: String) -> void:
	print("PT | " + s)

func ok(cond: bool, what: String) -> void:
	if cond:
		print("PT |  ok: " + what)
	else:
		fails += 1
		print("PT | ОШИБКА: " + what)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func hold(k: Key, on: bool) -> void:
	if bool(held.get(k, false)) == on:
		return
	held[k] = on
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = on
	Input.parse_input_event(e)

func tap(k: Key) -> void:
	hold(k, true)
	await wait(0.07)
	hold(k, false)
	await wait(0.07)

func mouse(b: MouseButton) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = b
		e.pressed = down
		e.position = get_viewport().get_visible_rect().size * 0.5
		e.global_position = e.position
		Input.parse_input_event(e)
		await wait(0.05)

func release_all() -> void:
	for k in held.keys():
		hold(k, false)

func sha(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "нет файла"

func reports() -> Array:
	var res: Array = []
	var d := DirAccess.open("user://survival_reports")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".json"):
				res.append(f)
	return res

func ready_in(sec: float) -> bool:
	acc[sec] = float(acc.get(sec, 0.0)) - get_process_delta_time()
	if float(acc[sec]) > 0.0:
		return false
	acc[sec] = sec
	return true

# ---------------------------------------------------------------- боец
func _process(dt: float) -> void:
	var g = main.game
	if g == null or not is_instance_valid(g) or not g.is_survival() or g.survival == null:
		return
	var run = g.survival
	var dir = run.director
	if run.draft != null and not draft_busy:
		_draft(g)
	if get_tree().paused or not (fighting or idle) or g.over or not run.active:
		if fighting:
			for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
				hold(k, false)
		return
	# --- наблюдение
	var alive: Array = g.enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	peak_alive = maxi(peak_alive, alive.size())
	log_t -= dt
	if log_t <= 0.0:
		log_t = 5.0
		say("t=%s угроза %d%% живых %d (тел %d) hp %d/%d герой %s стиль %s побеждено %d усилений %d · %s" % [run.time_text(), roundi(dir.threat * 100.0),
			alive.size(), g.enemies.size(), ceili(g.player.hp), int(g.player.max_hp), g.player.hero, g.player.style.id, g.kills, run.mods.ranks.size(), dir.forecast(g)])
	shot_t -= dt
	if shot_t <= 0.0:
		shot_t = 20.0
		shots += 1
		shot("run_%02d" % shots)
	if dir.event_kind != "" and not seen.has("ev_" + dir.event_kind):
		seen["ev_" + dir.event_kind] = true
		say("СОБЫТИЕ %s на %s" % [dir.event_kind, run.time_text()])
		_later_shot("event_" + dir.event_kind, 1.5)
	if alive.any(func(e): return e.survival_elite) and not seen.has("elite"):
		seen["elite"] = true
		say("ЭЛИТА на арене на %s" % run.time_text())
		_later_shot("elite", 0.6)
	if is_instance_valid(g.boss_e) and g.boss_e.state != "dead" and not seen.has("boss_" + g.boss_e.boss_id):
		seen["boss_" + g.boss_e.boss_id] = true
		say("БОСС %s вышел на %s, HP %d" % [g.boss_e.boss_id, run.time_text(), int(g.boss_e.max_hp)])
		_later_shot("boss_" + g.boss_e.boss_id, 2.0)
	if dir.bosses_defeated > int(seen.get("bosses", 0)):
		seen["bosses"] = dir.bosses_defeated
		say("БОСС ПОВЕРЖЕН на %s (всего %d)" % [run.time_text(), dir.bosses_defeated])
		_later_shot("boss_down_%d" % dir.bosses_defeated, 0.5)
	if idle:
		return
	# --- управление
	var p = g.player
	var best = null
	var bd := 1.0e9
	for e in alive:
		var d: float = e.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
			hold(k, false)
		return
	var to: Vector3 = best.global_position - p.global_position
	to.y = 0.0
	var yaw: float = g.cam_yaw
	var fy: float = to.dot(Vector3(-sin(yaw), 0, -cos(yaw)))
	var fx: float = to.dot(Vector3(cos(yaw), 0, -sin(yaw)))
	var reach := 1.9 if best.boss_id == "" else 2.6
	var go := bd > reach
	var lim := maxf(0.3, bd * 0.38)
	hold(KEY_W, go and fy > lim)
	hold(KEY_S, go and fy < -lim)
	hold(KEY_D, go and fx > lim)
	hold(KEY_A, go and fx < -lim)
	if bd < reach + 0.7 and ready_in(0.3):
		clicks += 1
		mouse(MOUSE_BUTTON_RIGHT if clicks % 4 == 0 else MOUSE_BUTTON_LEFT)
	var danger: bool = alive.any(func(e): return e.state == "wind" and e.global_position.distance_to(p.global_position) < 3.4)
	if danger and ready_in(0.9) and randf() < 0.6:
		rolls += 1
		tap(KEY_SHIFT)
	if ready_in(22.0):
		style_n += 1
		tap([KEY_2, KEY_3, KEY_1][style_n % 3])
	if ready_in(37.0):
		tap(KEY_TAB)
	if ready_in(13.0):
		tap(KEY_T)
	if g.hype.value >= TeamHype.MAX and ready_in(2.0):
		tap(KEY_G)
	if p.swag >= 100.0 and ready_in(3.0):
		tap(KEY_R)
	if ready_in(17.0):
		tap(KEY_Q)

func _later_shot(name: String, t: float) -> void:
	await wait(t)
	await shot(name)

## окно усилений: игра на паузе, выбор клавишей 1 / 2 / 3
func _draft(g) -> void:
	draft_busy = true
	release_all()
	var run = g.survival
	var before := 0
	for id in run.mods.ranks:
		before += int(run.mods.ranks[id])
	var el: float = run.elapsed
	ok(get_tree().paused, "окно усилений ставит игру на паузу (t=%s)" % run.time_text())
	ok(run.draft.choices.size() == 3, "в окне три усиления: %s" % ", ".join(run.draft.choices))
	# игрок в этот миг ещё бьёт и меняет стиль: нажатия первых мгновений выбор не делают
	await tap(KEY_2)
	await mouse(MOUSE_BUTTON_LEFT)
	await tap(KEY_SPACE)
	ok(run.draft != null and get_tree().paused and run.mods.ranks.size() * 0 + _ranks(run) == before, "нажатия в первые мгновения (2, ЛКМ, пробел) карточку не выбирают")
	await wait(0.6)
	if run.draft == null:
		draft_busy = false
		return
	drafts += 1
	if drafts <= 3:
		await shot("draft_%d" % drafts)
	ok(absf(run.elapsed - el) < 0.05, "пока открыт выбор, время забега стоит")
	var dim := 0
	for b in run.draft.find_children("*", "Button", true, false):
		dim += int((b.get_parent() as Control).modulate.a < 0.99)
	ok(dim == 0, "через секунду все три карточки видны (скорость игры в этот миг %.2f, не проявилось %d)" % [Engine.time_scale, dim])
	if drafts == 1:
		await tap(KEY_ESCAPE)
		await wait(0.3)
		ok(run.draft != null and get_tree().paused and not g.pause_panel.is_open, "Esc в окне усилений не открывает паузу поверх выбора")
	var pick: String = run.draft.choices[(drafts - 1) % 3]
	await tap([KEY_1, KEY_2, KEY_3][(drafts - 1) % 3])
	await until(func(): return run.draft == null, 2.0)
	var after := 0
	for id in run.mods.ranks:
		after += int(run.mods.ranks[id])
	ok(run.draft == null and not get_tree().paused and after == before + 1 and run.mods.rank(pick) >= 1,
		"клавиша %d берёт «%s» (ранг %d), игра продолжается; следующий выбор через %d с" % [(drafts - 1) % 3 + 1, Records.Mods.CARDS[pick][0], run.mods.rank(pick), ceili(run.next_draft - run.elapsed)])
	draft_busy = false

func _ranks(run) -> int:
	var n := 0
	for id in run.mods.ranks:
		n += int(run.mods.ranks[id])
	return n

# ---------------------------------------------------------------- сценарий
func _menu_to(item: String) -> bool:
	var mm = main.menu
	var names: Array = []
	for it in mm.ITEMS:
		names.append(String(it[0]))
	var want := names.find(item)
	for i in names.size() + 1:
		if mm.sel == want:
			return true
		await tap(KEY_S)
	return mm.sel == want

func _start_from_menu() -> bool:
	if not await until(func(): return main.menu != null and is_instance_valid(main.menu), 10.0):
		return false
	await wait(1.0)
	ok(await _menu_to("ROGUELIKE"), "клавишей S дошли до канала ROGUELIKE в главном меню")
	await tap(KEY_ENTER)
	await wait(0.6)
	var mm = main.menu
	ok(mm.panel != null and mm.panel_rows.size() == 3, "ROGUELIKE открывает экран ENDLESS SURVIVAL: начать, история, назад")
	return true

func _wait_run(prev) -> bool:
	var prev_id: int = prev.get_instance_id() if prev != null else 0
	var got: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.get_instance_id() != prev_id and main.game.is_survival() and main.game.survival != null and main.game.survival.active, 30.0)
	if got:
		seen = {}
		acc = {}
		log_t = 0.0
		shot_t = 3.0
	return got

func _die(g, tag: String) -> void:
	fighting = false
	idle = true
	release_all()
	say("боец бросил клавиши и ждёт гибели (hp %d)" % ceili(g.player.hp))
	var dead: bool = await until(func(): return g.over, 240.0)
	idle = false
	ok(dead, "без управления команду добивают (%s)" % tag)

func _run() -> void:
	var appdata := OS.get_environment("APPDATA").replace("\\", "/")
	if not appdata.contains("grimerka-checks") and OS.get_environment("GRIMERKA_PLAYTEST_ROOT") == "":
		print("PT | ОШИБКА: плейтест пишет рекорды Survival в user:// — запускай через node tools/checks.cjs survival или задай APPDATA на временную папку и GRIMERKA_PLAYTEST_ROOT=1")
		get_tree().quit()
		return
	for f in reports():
		DirAccess.remove_absolute("user://survival_reports".path_join(f))
	DirAccess.remove_absolute(Records.PATH)
	var save0 := sha(SAVE)
	say("сохранение кампании до плейтеста: %s" % save0.left(16))
	# ================= 1. вход из меню =================
	if not await _start_from_menu():
		ok(false, "главное меню не открылось")
		_finish(save0)
		return
	var mm = main.menu
	await shot("01_menu_survival")
	var head: String = ""
	for r in mm.panel_rows:
		var tx = r["text"]
		head += (String(tx.call()) if tx is Callable else String(tx)) + " | "
	say("пункты экрана: " + head)
	await tap(KEY_ENTER)                                   # НАЧАТЬ ЗАБЕГ
	ok(await _wait_run(null), "НАЧАТЬ ЗАБЕГ запускает Survival, вступление заканчивается, забег активен")
	var g = main.game
	var run = g.survival
	ok(g.world != null and g.world.deco == "snow" and g.mode == "fight", "снежная арена, режим боя")
	ok(g.survival_hud != null and g.survival_hud.visible and not g.top_label.visible and not g.xp_label.visible, "HUD забега на месте, сюжетные надписи скрыты")
	ok(not g.tutorial.on, "боевое обучение в забеге выключено")
	await shot("02_start")
	# ================= 2. честный забег =================
	fighting = true
	var c0 := GameClock.ms()
	var e0: float = run.elapsed
	await until(func(): return g.over or run.elapsed >= 20.0, 60.0)
	if not g.over:
		var span := (GameClock.ms() - c0) / 1000.0
		ok(absf((run.elapsed - e0) - span) < maxf(1.5, span * 0.12), "время забега идёт как игровые часы: %.1f с против %.1f с" % [run.elapsed - e0, span])
		ok(g.enemies.size() > 0 or g.kills > 0, "за первые 20 с враги появились (побеждено %d, на арене %d)" % [g.kills, g.enemies.size()])
	# пауза посреди боя
	if not g.over:
		await until(func(): return run.draft == null and not draft_busy and not g.hype.on, 20.0)
		release_all()
		fighting = false
		await tap(KEY_ESCAPE)
		var opened: bool = await until(func(): return g.pause_panel.is_open, 3.0)
		var pe: float = run.elapsed
		var pk: int = g.kills
		await wait(3.0)
		ok(opened and get_tree().paused and absf(run.elapsed - pe) < 0.05 and g.kills == pk, "Esc: пауза открыта, за 3 с время забега и счёт не сдвинулись")
		await shot("03_pause")
		await tap(KEY_ESCAPE)
		ok(await until(func(): return not g.pause_panel.is_open and not get_tree().paused, 4.0), "Esc закрывает паузу, бой продолжается")
		fighting = true
	await until(func(): return g.over or run.elapsed >= run_len, run_len * 1.5 + 60.0)
	say("честный забег: %s, побеждено %d, усилений взято %d, выборов %d, пик живых %d, уклонений %d, ударов %d, боссов %d, событий %d" % [
		run.time_text(), g.kills, run.mods.ranks.size(), drafts, peak_alive, rolls, clicks, run.director.bosses_defeated, run.director.events_completed])
	ok(peak_alive <= run.director.MAX_ALIVE, "живых врагов одновременно не больше %d (пик %d)" % [run.director.MAX_ALIVE, peak_alive])
	ok(drafts >= 1 or run.elapsed < 31.0, "выбор усилений появлялся (%d раз)" % drafts)
	if not g.over:
		await _die(g, "первый забег")
	await _death_screen(g, 1)
	# ================= 3. «Ещё раз» =================
	var d = g.death
	ok(d != null and d.sel == 0, "на экране гибели выбрано «Ещё раз»")
	await tap(KEY_ENTER)
	ok(await _wait_run(g), "«Ещё раз» начинает новый забег")
	var g2 = main.game
	await wait(0.5)
	ok(g2.survival.elapsed < 5.0 and g2.survival.mods.ranks.is_empty() and g2.kills == 0 and not g2.over and g2.player.hp >= g2.player.max_hp - 0.5,
		"новый забег чистый: время %s, усилений нет, счёт 0, здоровье полное" % g2.survival.time_text())
	ok(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0) or g2.clock < g2.slow_until, "после повтора игра не на паузе и не в замедлении")
	ok(get_tree().get_nodes_in_group("__none").is_empty() and main.get_children().filter(func(n): return n.get_script() == g2.get_script()).size() == 1, "старая игра убрана, экземпляр один")
	# босс: во втором забеге — раньше срока
	g2.survival.director.next_boss = g2.survival.elapsed + 30.0
	say("ПОДСТРОЙКА: во втором забеге босс назначен на 30-й секунде (у игрока — на 5-й минуте)")
	drafts = 0
	fighting = true
	var boss_out: bool = await until(func(): return g2.over or (is_instance_valid(g2.boss_e) and g2.boss_e.state != "dead"), 150.0)
	ok(boss_out and not g2.over or g2.over, "босс вышел после зачистки арены")
	if is_instance_valid(g2.boss_e):
		await wait(2.5)
		ok(g2.boss_box.visible and g2.boss_name.text != "", "полоса босса видна: %s" % g2.boss_name.text)
		ok(g2.objective().begins_with("Победи босса"), "задача в паузе: %s" % g2.objective())
		var hp0: float = g2.boss_e.hp
		await until(func(): return g2.over or g2.survival.director.bosses_defeated > 0, 170.0)
		if g2.survival.director.bosses_defeated > 0:
			await wait(4.0)
			ok(g2.boss_e == null or not is_instance_valid(g2.boss_e) or g2.boss_e.state == "dead", "после победы над боссом забег идёт дальше")
			ok(not g2.boss_box.visible, "полоса босса убрана")
			var k0: int = g2.kills
			await until(func(): return g2.over or g2.kills > k0 or g2.enemies.size() > 0, 30.0)
			ok(g2.over or g2.enemies.size() > 0 or g2.kills > k0, "после босса волны возобновились")
		elif is_instance_valid(g2.boss_e):
			say("босс не побеждён за отведённое время: HP %d → %d из %d (боец гибнет раньше: %s)" % [int(hp0), int(g2.boss_e.hp), int(g2.boss_e.max_hp), g2.over])
	if not g2.over:
		await _die(g2, "второй забег")
	await _death_screen(g2, 2)
	# ================= 4. «В меню», история, повторный запуск =================
	await tap(KEY_D)
	ok(g2.death.sel == 1, "D на экране гибели выбирает «В меню»")
	await tap(KEY_ENTER)
	ok(await until(func(): return main.menu != null and is_instance_valid(main.menu) and (main.game == null or not is_instance_valid(main.game)), 15.0), "«В меню» возвращает в главное меню, игра убрана")
	ok(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "в меню игра не на паузе, скорость обычная")
	var data: Dictionary = Records.read()
	ok(int(data["completed_runs"]) == 2 and (data["history"] as Array).size() == 2, "рекорды: забегов 2, в истории 2 (лучшее время %s, побед %d)" % [Records.format_time(data["best_time"]), int(data["best_kills"])])
	await _start_from_menu()
	await shot("06_menu_record")
	await tap(KEY_S)
	await tap(KEY_ENTER)                                   # ИСТОРИЯ ЗАБЕГОВ
	await wait(0.5)
	await shot("07_history")
	await tap(KEY_ESCAPE)
	await wait(0.4)
	ok(main.menu.panel != null and main.menu.panel_rows.size() == 3, "Esc из истории возвращает на экран Survival")
	main.menu._panel_select(0, false)
	await tap(KEY_ENTER)
	ok(await _wait_run(null), "повторный запуск из меню работает")
	var g3 = main.game
	fighting = true
	await until(func(): return g3.over or g3.survival.elapsed >= 12.0, 40.0)
	# события «элитное подкрепление» и «опасная зона»: у игрока они идут с 75-й секунды по очереди
	var dir3 = g3.survival.director
	for kind in ["elite", "hazard"]:
		if g3.over:
			break
		await until(func(): return g3.over or dir3.event_kind == "", 30.0)
		dir3._event_index = dir3.EVENTS.find(kind)
		dir3.next_event = g3.survival.elapsed + 1.0
		say("ПОДСТРОЙКА: событие «%s» назначено на ближайшую секунду" % dir3.EVENT_NAMES[kind])
		var started: bool = await until(func(): return g3.over or dir3.event_kind == kind, 8.0)
		ok(g3.over or (started and dir3.event_kind == kind), "событие «%s» началось" % dir3.EVENT_NAMES[kind])
		var done0: int = dir3.events_completed
		var swag0: float = g3.player.swag
		if kind == "hazard":
			ok(await until(func(): return g3.over or g3.zones.any(func(z): return z.get("survival_event", false)), 4.0), "опасная зона отмечена на земле заранее")
		else:
			ok(await until(func(): return g3.over or g3.enemies.any(func(e): return is_instance_valid(e) and e.survival_elite), 6.0), "элита вышла")
		await until(func(): return g3.over or dir3.event_kind == "", 25.0)
		if not g3.over:
			ok(dir3.events_completed == done0 + 1, "событие завершено и засчитано (СВЭГ %d → %d)" % [int(swag0), int(g3.player.swag)])
			ok(not g3.zones.any(func(z): return z.get("survival_event", false)), "после события опасных зон не осталось")
	fighting = false
	release_all()
	# iPod в забеге
	await until(func(): return g3.survival.draft == null and not draft_busy, 10.0)
	if not g3.over:
		await tap(KEY_UP)
		await wait(1.2)
		var pod_open: bool = g3.ipod != null and g3.ipod.opened
		say("iPod по стрелке ↑ в Survival: %s (пауза %s, вступление %s, окно %s, состояние героя %s)" % ["открывается" if pod_open else "не открывается",
			get_tree().paused, g3.intro_busy(), g3.panel != null, g3.player.state])
		if not pod_open:
			for i in 6:
				var pod = g3.ipod._pod()
				say("  iPod через %d с: открыт %s, ввод занят %s (input_captured %s, release_guard %s, рука занята %s, состояние руки %s), герой %s hp %d" % [i, g3.ipod.opened, g3.ipod.captures_gameplay_input(),
					g3.ipod.input_captured, g3.ipod.release_guard, pod != null and pod.busy(), str(pod.get("state")) if pod != null else "—", g3.player.state, ceili(g3.player.hp)])
				await wait(1.0)
		if pod_open:
			await shot("08_ipod")
			var ie: float = g3.survival.elapsed
			await wait(2.0)
			say("пока iPod открыт, время забега %s (%.1f → %.1f с)" % ["идёт" if g3.survival.elapsed - ie > 0.5 else "стоит", ie, g3.survival.elapsed])
			await tap(KEY_UP)
			await until(func(): return not g3.ipod.opened and not g3.ipod.captures_gameplay_input(), 6.0)
			await wait(1.0)
	# выход через паузу
	var done_runs := 2
	if not g3.over and g3.player.hp < 45.0:
		# боец стоял без управления и почти мёртв: если он погибнет, пока открывается пауза, сценарий собьётся
		say("здоровья %d — дожидаемся гибели, выход проверяется на свежем забеге" % ceili(g3.player.hp))
		idle = true
		await until(func(): return g3.over, 120.0)
		idle = false
	if g3.over:
		say("боец погиб в третьем забеге раньше выхода через паузу: «Ещё раз», выход проверяется на свежем забеге")
		await until(func(): return g3.death != null and is_instance_valid(g3.death) and g3.death.stage_name == "menu", 20.0)
		await wait(0.8)
		await tap(KEY_ENTER)
		ok(await _wait_run(g3), "«Ещё раз» после третьего забега")
		g3 = main.game
		done_runs = 3
		await wait(1.0)
	var rep0 := reports().size()
	if not g3.over:
		await until(func(): return g3.survival.draft == null and not draft_busy and not g3.hype.on, 20.0)
		await tap(KEY_ESCAPE)
		ok(await until(func(): return g3.pause_panel.is_open, 3.0), "пауза в третьем забеге открылась")
		var pm = g3.pause_panel
		for i in 8:
			if pm.sel == 5:
				break
			await tap(KEY_S)
		await tap(KEY_ENTER)
		await wait(0.4)
		var row := -1
		for i in pm.card_rows.size():
			var tx = pm.card_rows[i]["text"]
			if (String(tx.call()) if tx is Callable else String(tx)).contains("ГЛАВНОЕ МЕНЮ"):
				row = i
		ok(row >= 0, "в СИСТЕМЕ есть «В ГЛАВНОЕ МЕНЮ»")
		for i in 60:
			if pm.card_sel == row:
				break
			await tap(KEY_S)
		await tap(KEY_ENTER)
		await wait(0.4)
		await shot("09_confirm_menu")
		var names: Array = []
		for r in pm.card_rows:
			var tx2 = r["text"]
			names.append(String(tx2.call()) if tx2 is Callable else String(tx2))
		for i in 4:
			if pm.card_sel < names.size() and String(names[pm.card_sel]).contains("ВЫЙТИ"):
				break
			await tap(KEY_S)
		say("подтверждение выхода: строки %s, выбрана %d, пауза открыта %s" % [str(names), pm.card_sel, pm.is_open])
		await tap(KEY_ENTER)
		ok(await until(func(): return main.menu != null and is_instance_valid(main.menu) and (main.game == null or not is_instance_valid(main.game)), 15.0), "выход в меню из паузы")
		ok(not get_tree().paused, "после выхода из паузы дерево не на паузе")
		ok(reports().size() == rep0 + 1, "выход из забега пишет боевой отчёт (было %d, стало %d)" % [rep0, reports().size()])
		ok(int(Records.read()["completed_runs"]) == done_runs, "брошенный забег в рекорды не попадает")
	_finish(save0)

func _death_screen(g, n: int) -> void:
	fighting = false
	release_all()
	var run = g.survival
	ok(run.finished and not run.active and not run.result.is_empty(), "гибель %d: забег закрыт, итог записан" % n)
	ok(await until(func(): return g.death != null and is_instance_valid(g.death) and g.death.stage_name == "menu", 20.0), "сцена гибели дошла до кнопок")
	await wait(0.8)
	await shot("0%d_death" % (3 + n))
	var el: float = run.elapsed
	await wait(1.5)
	ok(absf(run.elapsed - el) < 0.01, "после гибели время забега не идёт")
	var data: Dictionary = Records.read()
	var last: Dictionary = data["last_run"]
	ok(int(data["completed_runs"]) == n and absf(float(last["time"]) - run.elapsed) < 0.5 and int(last["kills"]) <= g.kills and int(last["kills"]) >= g.kills - 2,
		"рекорды на диске: забегов %d, последний %s (в игре %.1f с) и %d побед (в игре %d), лучший %s" % [int(data["completed_runs"]), Records.format_time(last["time"]), run.elapsed, int(last["kills"]), g.kills, Records.format_time(data["best_time"])])
	ok(not g.enemies.any(func(e): return is_instance_valid(e) and e.has_node("EliteBadge") and e.get_node("EliteBadge").visible), "метки «ЭЛИТА» на экране итогов скрыты")
	var files := reports()
	ok(files.size() == n, "боевых отчётов %d" % files.size())
	if files.size() > 0:
		files.sort()
		var json := JSON.new()
		var txt := FileAccess.get_file_as_string("user://survival_reports".path_join(files[-1]))
		var parsed := json.parse(txt) == OK and json.data is Dictionary
		ok(parsed and not txt.contains("NaN") and not txt.contains("inf"), "отчёт — правильный JSON без NaN (%d байт)" % txt.length())
		if parsed:
			var rep: Dictionary = json.data
			var dealt := 0.0
			for hero in rep["heroes"]:
				dealt += float((rep["heroes"][hero] as Dictionary).get("damage_dealt", 0.0))
			say("отчёт: исход %s, активных секунд %.1f, урон героев %.0f, строк атак %d, видов врагов %d" % [rep["outcome"], float(rep["active_seconds"]), dealt, (rep["attacks"] as Dictionary).size(), (rep["enemies"] as Dictionary).size()])
			ok(String(rep["outcome"]) == "defeat" and absf(float(rep["active_seconds"]) - run.elapsed) < 1.0, "в отчёте поражение и то же время, что в рекордах")

func _finish(save0: String) -> void:
	release_all()
	ok(sha(SAVE) == save0, "сохранение кампании байт в байт прежнее")
	print("SURVIVALPLAY итог: ошибок %d" % fails)
	if fails == 0:
		print("SURVIVALPLAY ok")
	await wait(0.5)
	get_tree().quit()
