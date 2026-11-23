## Проверка звука как у игрока: `--resolution 1280x720 -- --soundcheck=<папка>`.
## Идёт из главного меню (не прогон — звук настоящий, настройки игрока настоящие): меню → CONTINUE (или NEW GAME) →
## кампания → меню → TRAINING ARENA. Раз в секунду печатает «SOUND …»: набор музыки, слои, громкости шин, режим
## наушников; проверяет по пикам шин, что музыка, эффекты и окружение правда звучат. Общая шина заглушена — слушать
## ничего не нужно, пики подшин меряются. Сохранение и настройки игрока запоминаются в начале и возвращаются в конце.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://grimerka_training.json",
	"user://microloans_save.json", "user://microloans_save.json.bak", "user://five_nights_save.json", "user://five_nights_save.json.bak"]

var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else (null as Variant)
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("SOUND ok: " if cond else "SOUND ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func peak(b: String) -> float:
	var i := AudioServer.get_bus_index(b)
	if i < 0:
		return -200.0
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))

func vol(b: String) -> float:
	var i := AudioServer.get_bus_index(b)
	return AudioServer.get_bus_volume_db(i) if i >= 0 else -200.0

## Несколько секунд слушаем шины: самый громкий пик каждой; раз в секунду — строка состояния
func listen(sec: float, tag: String) -> Dictionary:
	var best := {"Music": -200.0, "SFX": -200.0, "Ambient": -200.0, "Voice": -200.0, "IPod": -200.0, "UI": -200.0, "Horror": -200.0}
	var a = main.audio
	var t0 := Time.get_ticks_msec()
	var next := 0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
		for b in best:
			best[b] = maxf(best[b], peak(b))
		if Time.get_ticks_msec() - t0 >= next:
			next += 1000
			var g = main.game
			var ip = g.ipod if g != null and is_instance_valid(g) else null
			print("SOUND %s набор=%s слоёв=%d играют=%d наушники=%.2f (iPod слушает=%s, вкладыши=%s) шины дБ: Music %.1f SFX %.1f Ambient %.1f Voice %.1f · пики: Music %.1f SFX %.1f Ambient %.1f Voice %.1f IPod %.1f · трек меню %s %.1f дБ" % [
				tag, a.cur, a.layers.size(), a.layers.filter(func(p): return p.playing).size(), a.headphone,
				str(ip.is_listening()) if ip != null else "-", str(ip.earbuds_in) if ip != null else "-",
				vol("Music"), vol("SFX"), vol("Ambient"), vol("Voice"),
				best["Music"], best["SFX"], best["Ambient"], best["Voice"], best["IPod"],
				str(main.music.playing), main.music.volume_db])
	return best

func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.08)

## Музыка после действия: слушаем и сверяем
func after(tag: String, sec := 3.0) -> void:
	var r := await listen(sec, tag)
	ok(r["Music"] > -45.0 or main.audio.headphone > 0.5, "%s — музыка на месте (пик %.1f дБ, наушники %.2f)" % [tag, r["Music"], main.audio.headphone])

func _run() -> void:
	await wait(2.0)
	var mm = main.menu
	ok(mm != null, "главное меню открыто")
	var m0 := await listen(2.0, "меню")
	ok(m0["Music"] > -45.0, "в меню играет заглавный трек (пик %.1f дБ)" % m0["Music"])
	ok(m0["Ambient"] > -75.0, "в меню звучит подложка — треск винила (пик %.1f дБ)" % m0["Ambient"])
	# звуки меню: шаг по списку и наведение мышью (сам выбор не жмём — он уводит из меню)
	var c0 := int(main.ui_sfx.count.get("move", 0))
	await key(KEY_DOWN)                  # клавиши: звук запускается (счётчик); короткий — слушаем ниже напрямую
	await key(KEY_UP)
	await wait(0.3)
	ok(int(main.ui_sfx.count.get("move", 0)) >= c0 + 2, "клавиши в меню дают звук шага (звуков %d)" % (int(main.ui_sfx.count.get("move", 0)) - c0))
	mm._select(1)
	var mv := await listen(0.3, "меню: шаг")
	mm._select(0, false)
	ok(mv["SFX"] > -45.0, "шаг по списку слышно на шине SFX (пик %.1f дБ)" % mv["SFX"])
	mm._select(2, true, "hover")
	var hv := await listen(0.3, "меню: наведение")
	mm._select(0, false)
	ok(hv["SFX"] > -50.0, "наведение мышью звучит (пик SFX %.1f дБ)" % hv["SFX"])
	for kind in MenuSfx.LEVEL:
		ok(main.ui_sfx.streams.has(kind) and (main.ui_sfx.streams[kind] as AudioStreamWAV).data.size() > 1000, "звук меню «%s» собран" % kind)
	# ---------- кампания ----------
	main.cinematic_start(mm.has_save, -1 if mm.has_save else 0)
	var t0 := Time.get_ticks_msec()
	while (main.game == null or not is_instance_valid(main.game)) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	ok(main.game != null, "игра запустилась")
	if main.game == null:
		_finish()
		return
	await wait(5.0)
	var g = main.game
	var c := await listen(8.0, "кампания")
	ok(String(main.audio.cur).begins_with("loc_") or String(main.audio.cur).begins_with("boss_"), "в кампании выбран набор музыки (%s)" % main.audio.cur)
	ok(c["Music"] > -45.0, "в кампании музыка звучит (пик %.1f дБ)" % c["Music"])
	ok(c["Ambient"] > -70.0, "окружение звучит (пик %.1f дБ)" % c["Ambient"])
	ok(main.audio.headphone < 0.05 or g.ipod.is_listening(), "наушники глушат игру, только когда iPod правда играет (%.2f)" % main.audio.headphone)
	main.sfx("sfx_hit", 0.0)
	var s := await listen(1.0, "эффект")
	ok(s["SFX"] > -45.0, "эффекты звучат (пик %.1f дБ)" % s["SFX"])
	# ---------- действия игрока: после каждого музыка должна вернуться ----------
	var ip = g.ipod
	await key(KEY_UP)
	await wait(1.5)
	await after("iPod открыт", 2.0)
	ip.earbuds_in = true                # как у игрока: наушники в ушах (настройки игрока проверка не читает и не пишет)
	g.player.pod.set_seated(true)
	ip._play()
	await wait(2.0)
	await wait(0.5)
	var hp := await listen(2.0, "iPod играет")
	print("SOUND iPod играет: слушает=%s, наушники %.2f, пик IPod %.1f дБ" % [ip.is_listening(), main.audio.headphone, hp["IPod"]])
	ok(hp["IPod"] > -45.0, "трек iPod звучит (пик %.1f дБ)" % hp["IPod"])
	main.sfx("sfx_hit", 0.0)
	var hs := await listen(1.0, "iPod + удар")
	ok(hs["SFX"] > -45.0 and vol("SFX") < -8.0 and vol("SFX") > -30.0 and vol("Music") < -50.0, "в наушниках: музыка локации ушла (%.0f дБ), эффекты тише, но слышны (шина %.0f дБ, звук есть)" % [vol("Music"), vol("SFX")])
	if ip.player.playing and not ip.player.stream_paused:
		ip.pause_toggle_play()
	await key(KEY_UP)
	await wait(2.0)
	await after("iPod закрыт и на паузе")
	await key(KEY_ESCAPE)
	await wait(1.5)
	await after("пауза открыта", 2.0)
	await key(KEY_ESCAPE)
	await wait(1.5)
	await after("пауза закрыта")
	# бой с боссом главы
	var steps: Array = g.chapter()["steps"]
	var bi := -1
	for i in steps.size():
		if String(steps[i]["t"]) == "boss":
			bi = i
	if bi >= 0:
		g._close_panel()
		g.mode = "idle"
		g.step = bi - 1
		if g.in_hall:
			g._load_chapter(false)
		g.next_step()
		await wait(4.0)
		await after("бой с боссом", 4.0)
		print("SOUND босс: набор=%s" % main.audio.cur)
		# гибель и «Ещё раз»
		for i in 8:
			if g.over:
				break
			g.player.inv = 0.0
			g.player.take_damage(99999.0, g.player.global_position + Vector3(0, 0, -1))
			await wait(0.3)
		await wait(3.0)
		await after("сцена гибели", 2.0)
		g._retry()
		await wait(3.0)
		await after("после «Ещё раз»", 4.0)
	# ---------- арена ----------
	g._to_menu()
	await wait(2.5)
	main.menu.train_hero = "pahan"
	main.menu.train_style = "vozduh"
	main.menu.launch_training()
	t0 = Time.get_ticks_msec()
	while (main.game == null or not is_instance_valid(main.game) or main.game.training == null or main.game.training.targets.size() < 3) and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	await wait(3.0)
	var gg = main.game
	await key(KEY_F1)
	await wait(1.0)
	await after("панель арены открыта", 2.0)
	await key(KEY_ESCAPE)
	await wait(1.0)
	for i in 8:
		if gg.over:
			break
		gg.player.inv = 0.0
		gg.player.take_damage(99999.0, gg.player.global_position + Vector3(0, 0, -1))
		await wait(0.3)
	await wait(3.0)
	await after("арена после гибели", 3.0)
	var r := await listen(6.0, "арена")
	ok(r["Music"] > -45.0, "на арене музыка звучит (пик %.1f дБ)" % r["Music"])
	main.sfx("sfx_hit", 0.0)
	var rs := await listen(1.0, "арена-эффект")
	ok(rs["SFX"] > -45.0, "на арене эффекты звучат (пик %.1f дБ)" % rs["SFX"])
	gg._to_menu()
	await wait(2.0)
	await _minigames()
	_finish()

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

## мини-игры как у игрока: 5 НОЧЕЙ (терминал, ночь, дверь, свет, камеры) и МИКРОЗАЙМЫ (комната, действия)
func _minigames() -> void:
	FNSave.persist = false
	main.start_minigame("five_nights")
	await wait(2.5)
	var F = main.minigame
	ok(F is FiveNightsRoot, "5 НОЧЕЙ запущены")
	if not (F is FiveNightsRoot):
		return
	var fm := await listen(2.0, "5 ночей: терминал")
	ok(fm["Ambient"] > -40.0, "5 НОЧЕЙ, терминал: слышен гул (Ambient %.1f дБ)" % fm["Ambient"])
	F.start_night(0)
	await until(func(): return F.state == "night" and F.st != null and F.intro_t <= 0.0, 15.0)
	for id in F.st.enemies:
		(F.st.enemies[id] as FNEnemy).level = 0
	var fn := await listen(4.0, "5 ночей: ночь")
	ok(fn["Ambient"] > -35.0, "5 НОЧЕЙ, ночь: окружение слышно (Ambient %.1f дБ)" % fn["Ambient"])
	F.sfx3("step", FNOffice.point("hall_l") + Vector3(0, 0.2, 0), -10.0, 0.8)     # шаг в дальнем коридоре — как у врага
	var fs := await listen(0.6, "5 ночей: шаг в коридоре")
	ok(fs["SFX"] > -36.0, "5 НОЧЕЙ: шаг в дальнем коридоре слышно (SFX %.1f дБ)" % fs["SFX"])
	F.sfx2("scream_balon", 2.0)
	var fh := await listen(0.8, "5 ночей: крик")
	ok(fh["SFX"] > -12.0 and fh["SFX"] < 0.5, "5 НОЧЕЙ: крик скримера громкий, но без перегруза (шина Horror → SFX, пик %.1f дБ)" % fh["SFX"])
	await key(KEY_A)
	var fd := await listen(0.8, "5 ночей: дверь")
	await key(KEY_A)
	ok(fd["SFX"] > -30.0, "5 НОЧЕЙ: дверь слышно (SFX %.1f дБ)" % fd["SFX"])
	await key(KEY_SPACE)
	var fc := await listen(1.0, "5 ночей: планшет")
	await key(KEY_SPACE)
	ok(fc["SFX"] > -30.0, "5 НОЧЕЙ: планшет слышно (SFX %.1f дБ)" % fc["SFX"])
	F.quit_to_menu()
	await wait(2.5)
	main.start_minigame("microloans")
	await wait(3.0)
	var M = main.minigame
	ok(M is MicroloansRoot, "МИКРОЗАЙМЫ запущены")
	if not (M is MicroloansRoot):
		return
	var mr := await listen(3.0, "микрозаймы: комната")
	ok(mr["Music"] > -45.0 or mr["Ambient"] > -45.0, "МИКРОЗАЙМЫ, комната: есть музыка или фон (Music %.1f, Ambient %.1f дБ)" % [mr["Music"], mr["Ambient"]])
	ok(mr["Ambient"] > -60.0, "МИКРОЗАЙМЫ: фон комнаты звучит (Ambient %.1f дБ)" % mr["Ambient"])
	var mv0 := int(M.snd.count.get("move", 0))
	await key(KEY_DOWN)                         # клавиша → звук шага (счётчик); сам звук 0,05 с — слушаем ниже напрямую
	ok(int(M.snd.count.get("move", 0)) == mv0 + 1, "МИКРОЗАЙМЫ: стрелка вниз даёт звук шага по меню")
	M.ui._select(M.ui.sel + 1)
	var mk := await listen(0.3, "микрозаймы: выбор")
	ok(mk["SFX"] > -35.0, "МИКРОЗАЙМЫ: шаг по меню слышно (SFX %.1f дБ)" % mk["SFX"])
	for kind in ["notify", "money", "alert", "stamp", "phase", "sigh"]:
		M.snd.play(kind)
		var one := await listen(0.5, "микрозаймы: " + kind)
		ok(one["SFX"] > -30.0 or one["Voice"] > -30.0, "МИКРОЗАЙМЫ: звук «%s» слышно (SFX %.1f, Voice %.1f дБ)" % [kind, one["SFX"], one["Voice"]])
	ok(main.audio.cur == "loc_ml", "МИКРОЗАЙМЫ: своя музыка комнаты (%s)" % main.audio.cur)
	# все звуки обеих мини-игр собраны и не пустые
	for c in [FNSound._cache, MLSound._cache]:
		for id in c:
			var w: AudioStreamWAV = c[id]
			var pk := 0
			for i in range(0, w.data.size() - 1, 64):
				pk = maxi(pk, absi(w.data.decode_s16(i)))
			ok(pk > 3000 and pk <= 32000, "звук «%s»: пик %.1f дБFS" % [id, linear_to_db(float(pk) / 32768.0)])
	M.quit_to_menu()
	await wait(2.5)

func _finish() -> void:
	if main.game != null and is_instance_valid(main.game) and main.game.ipod != null:
		main.game.ipod.persistence_enabled = false        # настройки iPod игрока при выходе не перезаписываем
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	AudioServer.set_bus_mute(0, false)
	print("SOUNDCHECK ok" if fails == 0 else "SOUNDCHECK ОШИБКА: %d" % fails)
	get_tree().quit()
