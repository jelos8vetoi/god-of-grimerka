## Проверка режиссёра музыки: `--audio-driver Dummy --resolution 1280x720 -- --musiccheck=<папка>`.
## Идёт из главного меню настоящей игры (звук включён, как у игрока, общая шина заглушена): заглавный трек, переходы меню ↔
## игра, диалоги и ролики как наложения, дребезг смены набора, пауза, ползунок, наушники iPod, «5 ночей». Утверждения —
## по снимку режиссёра (snapshot, events) и состоянию проигрывателей; на каждом кадре меряется самый большой шаг
## громкости каждого музыкального проигрывателя (тише −28 дБ — вход из тишины — не считается).
extends Node

const FADE_FLOOR := -28.0

var main
var out := ""
var fails := 0
var D: MusicDirector
var prev := {}
var worst := 0.0
var worst_who := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("MUSICCHECK ok: " if cond else "MUSICCHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _all_players() -> Array:
	var out_a: Array = []
	for d in D.decks:
		for p in d.players:
			out_a.append(p)
	out_a.append_array([D.title, D.cine, D.sting, D.dieg])
	return out_a

func _process(dt: float) -> void:
	if D == null:
		return
	for p in _all_players():
		var v: float = p.volume_db
		if prev.has(p) and p.playing and not p.stream_paused:
			var pv: float = prev[p]
			var step := absf(v - pv) * (1.0 / 60.0) / maxf(dt, 0.0001)
			if v > FADE_FLOOR and pv > FADE_FLOOR and step > worst:
				worst = step
				worst_who = "%s %.1f→%.1f" % [str(p.get_path()).get_file(), pv, v]
		prev[p] = v

func cues(from: int) -> Array:
	var r: Array = []
	for i in range(from, D.events.size()):
		if D.events[i]["ev"] == "cue":
			r.append(D.events[i])
	return r

func bus_db(b: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b))

func manual(on: bool) -> void:
	main.audio.set_process(not on)

func drive(cue: String, sec: float, layers := [1.0, 0.0, 0.0], ctx := "explore") -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		D.set_base({"ctx": ctx, "cue": cue, "layers": layers, "pitch": 1.0, "gain_db": 0.0, "duck_db": 0.0})
		D.tick(get_process_delta_time())
		await get_tree().process_frame

func _run() -> void:
	main = get_parent()
	await get_tree().process_frame
	D = main.audio.director
	# (a) первый запуск
	var ta := Time.get_ticks_msec()
	while D.title_prog < 0.999 and Time.get_ticks_msec() - ta < 8000:
		await get_tree().process_frame
	print("MUSICCHECK заглавный трек вышел на уровень за %.1f с (title_prog %.2f)" % [(Time.get_ticks_msec() - ta) / 1000.0, D.title_prog])
	await wait(0.5)
	var snap := D.snapshot()
	var title_players := 0
	for c in D.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == "MusicMenu":
			title_players += 1
	ok(D.cue == "title" and D.title_started and title_players == 1 and absf(D.title.volume_db + 6.0) < 0.5, "первый запуск: играет заглавный трек (один проигрыватель, %.1f дБ после нарастания)" % D.title.volume_db)
	# (b) экраны меню не меняют музыку
	var ev0 := D.events.size()
	var pos0 := D.title.get_playback_position()
	var mono := true
	var last := pos0
	if main.menu != null:
		main.menu.open_modes()
		await wait(0.6)
		main.menu._open_settings()
		await wait(0.6)
		if main.menu.has_method("panel_back"):
			main.menu.panel_back()
		await wait(0.6)
	else:
		await wait(1.8)
	var pos1 := D.title.get_playback_position()
	mono = pos1 >= pos0
	ok(cues(ev0).is_empty() and mono, "меню → экраны → назад: смен набора %d, позиция трека %.1f → %.1f с" % [cues(ev0).size(), pos0, pos1])
	# (c) вход в игру и возврат
	var ev1 := D.events.size()
	var pos_leave := D.title.get_playback_position()
	main.start_game()
	var tb := Time.get_ticks_msec()
	while not D.title.stream_paused and Time.get_ticks_msec() - tb < 9000:
		await get_tree().process_frame
	print("MUSICCHECK заглавный трек остановился за %.1f с после start_game" % [(Time.get_ticks_msec() - tb) / 1000.0])
	await wait(0.5)
	var trs := cues(ev1)
	ok(String(D.cue).begins_with("loc_") and D.title_prog <= 0.001 and D.title.stream_paused, "ИГРА: набор «%s», заглавный трек ушёл и стоит на паузе (позиция %.1f)" % [D.cue, D.title.get_playback_position()])
	ok(trs.size() >= 1 and String(trs[0]["transition"]) == "menu_out", "переход меню → игра: «%s»" % (trs[0]["transition"] if trs.size() > 0 else "нет"))
	var ev2 := D.events.size()
	main.show_menu()
	await wait(2.5)
	var back := cues(ev2)
	var pos_back := D.title.get_playback_position()
	ok(D.cue == "title" and back.size() >= 1 and String(back[0]["transition"]) == "menu_in" and pos_back > 0.0 and not D.sting.playing and main.audio.state == "menu", "возврат в меню: menu_in, трек продолжился (%.1f → %.1f с), отбивок нет, состояние %s" % [pos_leave, pos_back, main.audio.state])
	# (d) устаревшие боссы и поражения не переходят в новую игру
	main.audio.boss_seen = "misha"
	main.audio.dead_seen = true
	await wait(0.3)
	var ev3 := D.events.size()
	main.start_game()
	await wait(2.0)
	var win_sting := false
	for i in range(ev3, D.events.size()):
		if D.events[i]["ev"] == "stinger":
			win_sting = true
	ok(not win_sting and main.audio.boss_seen == "" and D.ctx in ["explore", "combat"] and main.audio.state != "victory", "новая игра после выхода из боя: отбивок нет, boss_seen пуст, ctx %s" % D.ctx)
	# (l) повторный запуск режима — заглавный трек не мигает
	var blip := false
	await wait(3.0)
	main.start_game()
	var t_end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < t_end:
		if not D.title.stream_paused or D.title.volume_db > -59.0:
			blip = true
		await get_tree().process_frame
	ok(not blip, "повторный start_game: заглавный трек не оживал (на паузе, %.1f дБ)" % D.title.volume_db)
	main.show_menu()
	await wait(2.0)
	# (e) дребезг смены набора
	manual(true)
	await drive("loc_hall", 2.5)
	var ev4 := D.events.size()
	var kids0 := D.get_child_count()
	var t0 := Time.get_ticks_msec()
	var flip := 0
	while Time.get_ticks_msec() - t0 < 100:
		await drive(["loc_snow", "loc_hall", "loc_snow"][flip % 3], 0.03)
		flip += 1
	await drive("loc_hall", 1.0)
	var swaps := cues(ev4).size()
	var maxdecks := 0
	for k in 20:
		await drive(["loc_neon", "loc_hall", "loc_snow"][k % 3], 0.3)
		var n := 0
		for d in D.decks:
			n += 1 if d.gain() > 0.02 else 0
		maxdecks = maxi(maxdecks, n)
	ok(swaps <= 1 and maxdecks <= 2 and D.get_child_count() == kids0, "дребезг A→B→A за 0,1 с: смен набора %d, 20 переключений: звучит не больше %d дек, узлов было %d стало %d" % [swaps, maxdecks, kids0, D.get_child_count()])
	await drive("loc_hall", 3.0)
	# (f) диалоги и реплики
	manual(false)
	await wait(1.0)
	var o1 := Node.new()
	var o2 := Node.new()
	add_child(o1)
	add_child(o2)
	D.enter_dialogue(o1, "talk")
	D.enter_dialogue(o2, "talk")
	var bp := AudioStreamPlayer.new()
	bp.bus = "MusicCine"
	bp.volume_db = -80.0
	bp.stream = D.title.stream
	add_child(bp)
	bp.play()
	D.bark(bp)
	await wait(1.6)
	var d_two := D.duck_db
	ok(absf(d_two + 6.0) < 0.4, "два диалога и реплика: приглушение %.1f дБ (самое глубокое, не сумма)" % d_two)
	o1.queue_free()
	await wait(0.5)
	var ev5 := D.events.size()
	bp.stop()
	o2.queue_free()
	await wait(2.5)
	var expired := 0
	for i in range(ev5, D.events.size()):
		if D.events[i]["ev"] == "overlay_expire":
			expired += 1
	ok(expired >= 1 and D.duck_db > -0.5, "владелец удалён без leave — приглушение снято само (снятий %d, теперь %.1f дБ)" % [expired, D.duck_db])
	var o3 := Node.new()
	add_child(o3)
	D.enter_dialogue(o3, "talk")
	await wait(1.2)
	D.leave_dialogue(o3)
	await wait(0.3)
	var held := D.duck_db
	await wait(3.0)
	ok(held < -5.0 and D.duck_db > -0.5, "leave: удержание 0,6 с (через 0,3 с %.1f дБ), потом возврат (%.1f дБ)" % [held, D.duck_db])
	o3.queue_free()
	bp.queue_free()
	# (g) ролик с тишиной
	manual(true)
	await drive("loc_hall", 2.0)
	var owner := Node.new()
	add_child(owner)
	D.enter_cinematic(owner, {"mode": "silence"})
	await drive("loc_hall", 1.8)
	var stopped := D.cue == "" and not D.decks[0].live and not D.decks[1].live
	var kept := 0.0
	if D.memory.has("loc_hall"):
		kept = float((D.memory["loc_hall"] as Array)[0])
	D.leave_cinematic(owner)
	await drive("loc_hall", 0.5)
	var pl: AudioStreamPlayer = D.active_players()[0] if D.active_players().size() > 0 else null
	var now_pos: float = pl.get_playback_position() if pl != null else -1.0
	ok(stopped and D.cue == "loc_hall" and absf(now_pos - (kept + 0.5)) <= 0.3, "ролик в тишину и обратно: набор вернулся с позиции %.1f → %.1f с (прошло 0,5 с)" % [kept, now_pos])
	owner.queue_free()
	# (h) пауза: приглушение −6 дБ, набор не меняется
	var cue_before := D.cue
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1800:
		D.set_base({"ctx": "explore", "cue": "loc_hall", "layers": [1.0, 0.0, 0.0], "pitch": 1.0, "gain_db": 0.0, "duck_db": -6.0})
		D.tick(get_process_delta_time())
		await get_tree().process_frame
	var paused_db := D.duck_db
	await drive("loc_hall", 2.0)
	ok(absf(paused_db + 6.0) < 0.4 and D.duck_db > -0.5 and D.cue == cue_before, "пауза: приглушение %.1f дБ и обратно %.1f дБ, набор не менялся" % [paused_db, D.duck_db])
	# (i) ползунок музыки: шина в тишину, усиление режиссёра не трогается
	var g_before := D.decks[D.active].players[0].volume_db
	var vol_before: float = main.audio.vol["Music"]
	main.audio.set_volume("Music", 0.0, false)
	await frames(3)
	main.audio._mix(0.016)
	var bus0 := bus_db("Music")
	var g_after := D.decks[D.active].players[0].volume_db
	main.audio.set_volume("Music", vol_before, false)
	main.audio._mix(0.016)
	ok(bus0 <= -70.0 and absf(g_after - g_before) < 1.0, "ползунок музыки 0: шина %.1f дБ, проигрыватель режиссёра %.1f → %.1f дБ" % [bus0, g_before, g_after])
	# (j) наушники iPod (имитация множителя audio.gd): шина молчит, режиссёр не трогается
	var snap_before := D.snapshot()
	main.audio.headphone = 1.0
	main.audio._mix(0.0)
	var hp_bus := bus_db("Music")
	var snap_mid := D.snapshot()
	main.audio.headphone = 0.0
	main.audio._mix(1.0)
	ok(hp_bus <= -55.0 and snap_mid["cue"] == snap_before["cue"] and snap_mid["duck_db"] == snap_before["duck_db"], "наушники: шина Music %.1f дБ, набор «%s» и приглушение режиссёра прежние" % [hp_bus, snap_mid["cue"]])
	manual(false)
	await wait(1.5)
	# (k) «5 ночей»: терминал, ночь, мёртвая тишина, выход
	main.start_minigame("five_nights")
	await wait(3.5)
	var term_cue := String(D.cue)
	var g: FiveNightsRoot = main.minigame
	g.start_night(0)
	await wait(0.5)
	while g.intro_t > 0.0:
		await get_tree().process_frame
	await wait(2.5)
	var night_cue := String(D.cue)
	main.audio.hush(true, true)
	await frames(2)
	var hushed := bus_db("Music") <= -70.0 and bus_db("Ambient") <= -70.0
	main.audio.hush(false, false)
	await wait(2.5)
	var released := bus_db("Music") > -12.0 and bus_db("Ambient") > -12.0
	ok(term_cue == "loc_fn" and night_cue == "", "5 НОЧЕЙ: в терминале набор «%s», в ночи «%s» (свой синтез)" % [term_cue, night_cue])
	ok(hushed and released, "мёртвая тишина глушит шины сразу (%s) и отпускает плавно (%s)" % [str(hushed), str(released)])
	g.quit_to_menu()
	await wait(3.0)
	ok(D.cue == "title" and D.title_prog > 0.95 and D.title.playing and not D.title.stream_paused, "выход из «5 ночей»: заглавный трек вернулся (набор «%s», нарастание %.2f)" % [D.cue, D.title_prog])
	await _golda67()
	await _real_paths()
	ok(worst <= 3.0, "самый большой шаг громкости музыкального проигрывателя за кадр: %.2f дБ (%s); тише %.0f дБ не считается" % [worst, worst_who, FADE_FLOOR])
	print("MUSICCHECK ", "ok" if fails == 0 else "ОШИБКА: %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func decks_full() -> int:
	var n := 0
	for d in D.decks:
		n += 1 if d.gain() > 0.9 and d.live else 0
	return n

func last_trans(from: int) -> String:
	var r := ""
	for i in range(from, D.events.size()):
		if D.events[i]["ev"] == "cue":
			r = String(D.events[i]["transition"])
	return r

func _golda67() -> void:
	var ev := D.events.size()
	main.start_golda67()
	await frames(2)
	var g67 = main.game.golda
	g67.auto_clips = false
	var g = main.game
	await until(func(): return g67.clip != null, 12.0)
	await wait(1.2)
	var intro_silent: bool = g67.clip == null or (D.cue == "" and D._voice())
	var guard := 0
	while guard < 8:
		if g67.clip != null:
			g67.clip._end()      # первый просмотр нельзя пропустить, а ролики долгие: конец подставлен
			await wait(1.2)
		else:
			await wait(1.5)
			if g67.clip == null:
				break
		guard += 1
	await until(func(): return g67.place == "hub" and not g67.busy, 10.0)
	ok(intro_silent, "m0 вступительный ролик при первом входе: музыка молчит, голос в снимке")
	await wait(4.5)
	ok(D.cue == "loc_hall" and D.via_k > 0.99 and D.dieg.playing and D.missing.has("loc_g67_hub") and D.title.stream_paused, "m1 ГОЛДА 67, хаб: набор «%s» звучит из телевизора (via %.2f, диегетический играет %s), заменён: loc_g67_hub → %s" % [D.cue, D.via_k, str(D.dieg.playing), str(D.missing.get("loc_g67_hub", "?"))])
	await _talk_check(g67, g, "КРОТ", func(): g67.talk_krot(), "m4")
	await _talk_check(g67, g, "DJ FLÜRR", func(): g67.talk_flurr(), "m5")
	# m2 хаб → забег → хаб
	var ev2 := D.events.size()
	var two_full := false
	g67.start_run("dvor")
	var t_end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < t_end:
		two_full = two_full or decks_full() > 1
		await get_tree().process_frame
	var tr_run := last_trans(ev2)
	var run_cue := String(D.cue)
	var yard_via := D.via_k
	ok(tr_run == "gap" and run_cue == "loc_snow" and yard_via < 0.05 and D.missing.has("loc_g67_dvor") and not two_full, "m2 забег: переход «%s», набор двора «%s» с деки (via %.2f), двух полных наборов одновременно нет" % [tr_run, run_cue, yard_via])
	# m3 комната с врагами: слой драйва поднимается, набор не перезапускается
	g67.enter_room({"type": "battle", "place": "podezd"})
	await until(func(): return g.enemies.size() > 0, 9.0)
	var pos_a: float = D.active_players()[0].get_playback_position() if D.active_players().size() > 0 else -1.0
	await wait(2.5)
	var pos_b: float = D.active_players()[0].get_playback_position() if D.active_players().size() > 0 else -1.0
	var drive_up: bool = D.ctx == "combat" and D.active_players().size() > 1 and D.active_players()[1].volume_db > -25.0
	ok(drive_up and pos_b > pos_a and String(D.cue) == run_cue, "m3 враги в комнате: ctx %s, драйв %.1f дБ, позиция набора %.1f → %.1f с, набор прежний" % [D.ctx, D.active_players()[1].volume_db if D.active_players().size() > 1 else -99.0, pos_a, pos_b])
	var t3 := Time.get_ticks_msec()
	while g67.room_state == "fight" and Time.get_ticks_msec() - t3 < 40000:
		for e in g.enemies.duplicate():
			if is_instance_valid(e) and e.state != "dead":
				e.take_hit(99999.0, Vector3.ZERO, 0.0)
		await wait(0.4)
	await wait(5.0)
	ok(D.ctx == "explore" and D.active_players().size() > 1 and D.active_players()[1].volume_db < -25.0, "m3 враги побеждены: ctx %s, драйв ушёл (%.1f дБ)" % [D.ctx, D.active_players()[1].volume_db if D.active_players().size() > 1 else -99.0])
	# m4 КРОТ (реальные реплики) и m5 ДИДЖЕЙ: приглушение держится весь разговор
	# m6 ролик, первый просмотр (конец — через _end(): сам ролик долгий)
	var ev6 := D.events.size()
	g67.play_clip("NEWS01")
	await wait(1.2)
	var silent_ok: bool = D.cue == "" and D._voice() and D.snapshot()["overlays"].size() >= 1
	var cl = g67.clip
	if cl != null:
		cl._end()
	await wait(3.0)
	ok(silent_ok and String(D.cue) != "" and D.snapshot()["overlays"].size() == 0 and not D.cine.playing, "m6 ролик (первый просмотр): музыка замолчала, голос в снимке; после конца набор «%s» вернулся, наложений нет" % D.cue)
	# m7 тот же ролик из архива и skip()
	g67.play_clip("NEWS01")
	await wait(1.5)
	var cl2 = g67.clip
	if cl2 != null:
		cl2.skip()
	await wait(3.0)
	ok(D.snapshot()["overlays"].size() == 0 and String(D.cue) != "" and not D.cine.playing, "m7 повторный ролик и skip(): наложений нет, набор «%s» вернулся, проигрыватель ролика остановлен" % D.cue)
	# m11 пауза по-настоящему
	var cue_p := String(D.cue)
	await key_tap(KEY_ESCAPE)
	await wait(1.6)
	var d_pause := D.duck_db
	await key_tap(KEY_ESCAPE)
	await wait(2.0)
	ok(absf(d_pause + 6.0) < 0.5 and D.duck_db > -0.5 and String(D.cue) == cue_p, "m11 пауза в забеге: %.1f дБ, после — %.1f дБ, набор не менялся" % [d_pause, D.duck_db])
	# m8 Миша: постановка в тишине, затем бой
	var ev8 := D.events.size()
	g67.enter_room({"type": "boss", "place": "dvor"})
	var stage_silent := true
	var boss_early := false
	await until(func(): return g67.scene_t >= 0.0, 6.0)
	while g67.scene_t >= 0.0:
		if String(D.cue) != "" and D.ctx == "story" and D.pending == "":
			stage_silent = stage_silent and false
		for d in D.decks:
			if d.live and String(d.cue).begins_with("boss_") and d.gain() > 0.05:
				boss_early = true
		await get_tree().process_frame
	var line_waited: bool = await until(func(): return not g.bark_b.playing, 12.0)
	await wait(2.5)
	var boss = g.boss_e
	var stung := false
	for i in range(ev8, D.events.size()):
		if D.events[i]["ev"] == "stinger" and String(D.events[i]["cue"]).ends_with("_intro"):
			stung = true
	ok(not boss_early and boss != null and String(D.cue) == "boss_courier" and D.ctx == "boss" and stung, "m8 Миша: до конца постановки босса нет (%s), потом набор «%s» (замена boss_g67_misha → boss_courier), вступление %s" % [str(not boss_early), D.cue, str(stung)])
	# m9 фазы
	var p9a: float = D.active_players()[0].get_playback_position()
	_boss_hit(boss, boss.max_hp * 0.4, "удар 40 %")
	await wait(3.0)
	var l1: float = D.decks[D.active].lv[1] if D.active >= 0 else -99.0
	_boss_hit(boss, boss.max_hp * 0.35, "удар 35 %")
	await wait(3.0)
	var l2: float = D.decks[D.active].lv[2] if D.active >= 0 else -99.0
	var p9b: float = D.active_players()[0].get_playback_position()
	ok(boss.phase >= 2 and l1 > -10.0 and l2 > -10.0 and p9b > p9a, "m9 фазы босса: слой p2 %.1f дБ, p3 %.1f дБ, позиция набора %.1f → %.1f с" % [l1, l2, p9a, p9b])
	# m10 босс повержен обычным уроном
	var t10 := D.clock
	print("MUSICCHECK   перед добиванием: audio.boss_seen=«%s», ctx %s, cue %s" % [main.audio.boss_seen, D.ctx, D.cue])
	_boss_hit(boss, 999999.0, "добивание")
	await wait(2.0)
	var won := false
	for e in D.events:
		if float(e["t"]) >= t10 - 0.01 and e["ev"] == "stinger" and String(e["cue"]).ends_with("_win"):
			won = true
	var over: bool = g67.room_state == "over"
	# после победы — экран итогов; в подъезд ведёт та же кнопка «В ПОДЪЕЗД»
	var res_ok: bool = await until(func(): return g67.hub_ui != null and g67.hub_ui.kind == "result", 15.0)
	if res_ok:
		await wait(0.3)
		g67.hub_ui.select(0, true)
		g67.hub_ui._activate(0)
	await until(func(): return g67.place == "hub", 14.0)
	await wait(2.0)
	ok(won and over and g67.place == "hub" and D.via_k > 0.5, "m10 босс повержен: победная отбивка %s, затем хаб, музыка из телевизора (via %.2f, набор «%s»)" % [str(won), D.via_k, D.cue])
	# m12 перезапуск режима дважды: один режиссёр, число проигрывателей прежнее, заглавный трек не оживает
	var dirs := 0
	var kids0 := D.get_child_count()
	var blip := false
	for i in 2:
		main.end_golda67()
		await frames(2)
		main.start_golda67()
		await frames(2)
		main.game.golda.auto_clips = false
		var t12 := Time.get_ticks_msec() + 1500
		var pp := D.title_prog
		while Time.get_ticks_msec() < t12:
			if D.title_prog > pp + 0.0001 and String(D.cue) != "title":
				blip = true
			pp = D.title_prog
			await get_tree().process_frame
	for c in main.audio.get_children():
		dirs += 1 if c is MusicDirector else 0
	ok(dirs == 1 and D.get_child_count() == kids0 and not blip, "m12 режим перезапущен дважды: режиссёров %d, узлов %d → %d, заглавный трек не оживал %s" % [dirs, kids0, D.get_child_count(), str(not blip)])
	# m13 «музыка выключена» как в настройках
	var keepv: float = main.audio.vol["Music"]
	main.audio.set_volume("Music", 0.0, false)
	await frames(3)
	var off_db := bus_db("Music")
	main.audio.set_volume("Music", keepv, false)
	await frames(3)
	ok(off_db <= -70.0 and bus_db("Music") > -30.0, "m13 ползунок музыки в настройках: 0 → шина %.1f дБ, возврат → %.1f дБ" % [off_db, bus_db("Music")])
	# m14 iPod по-настоящему (как soundcheck.gd)
	var ip = main.game.ipod
	if ip != null:
		await key_tap(KEY_UP)
		await wait(1.5)
		ip.earbuds_in = true
		main.game.player.pod.set_seated(true)
		ip._play()
		await wait(2.5)
		var hp_bus := bus_db("Music")
		var cue_i := String(D.cue)
		ip.persistence_enabled = false
		if ip.player.playing and not ip.player.stream_paused:
			ip.pause_toggle_play()
		await key_tap(KEY_UP)
		await wait(2.5)
		ok(hp_bus < -50.0 and String(D.cue) == cue_i and bus_db("Music") > -30.0, "m14 iPod: в наушниках шина Music %.1f дБ, набор «%s» не тронут, после — шина %.1f дБ" % [hp_bus, cue_i, bus_db("Music")])
	main.show_menu()
	await wait(2.5)

func key_tap(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame

func _talk_check(g67, g, who: String, start: Callable, tag: String) -> void:
	start.call()
	await wait(0.6)
	var ok_all: bool = g.mode == "dlg"
	var worst_duck := -99.0
	var t0 := Time.get_ticks_msec()
	var n := 0
	while g.mode == "dlg" and Time.get_ticks_msec() - t0 < 60000:
		if Time.get_ticks_msec() - t0 > 600:
			worst_duck = maxf(worst_duck, D.duck_db) if n > 0 else D.duck_db
			if D.duck_db > -5.0:
				ok_all = false
		n += 1
		await get_tree().process_frame
		if g.dlg_i < g.dlg.size() - 1 and randf() < 0.0:
			pass
		# следующая реплика по нажатию, как у игрока
		if n % 90 == 0:
			g._dlg_advance()
	var t_end := Time.get_ticks_msec()
	await wait(2.0)
	ok(ok_all and n > 0 and D.duck_db > -0.5, "%s %s: приглушение не выше −5 дБ весь разговор (%d кадров, самое слабое %.1f дБ), через 2 с после конца %.1f дБ" % [tag, who, n, worst_duck, D.duck_db])

# ---------- настоящие пути игрока: выходы в главное меню теми же вызовами, что у кнопок ----------
func in_menu() -> bool:
	return main.menu != null and is_instance_valid(main.menu) and main.game == null and main.minigame == null

func menu_ready() -> void:
	await until(func(): return in_menu(), 25.0)
	await wait(0.4)

## через 4 с после возврата в меню: музыка слышна на всех звеньях цепочки
func menu_audible(tag: String) -> void:
	var peak_menu := -200.0
	var t_end := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < t_end:
		var i := AudioServer.get_bus_index("MusicMenu")
		peak_menu = maxf(peak_menu, maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0)))
		await get_tree().process_frame
	var good: bool = D.cue == "title" and D.title.playing and not D.title.stream_paused and bus_db("Music") > -40.0 and peak_menu > -50.0 and bus_db("Master") > -40.0 and not main.audio.hush_hold and Engine.time_scale == 1.0
	ok(good, "%s → главное меню: трек слышен (набор «%s», играет %s, пауза %s, шина Music %.1f дБ, пик MusicMenu %.1f дБ, hush %s, time_scale %.1f)" % [tag, D.cue, str(D.title.playing), str(D.title.stream_paused), bus_db("Music"), peak_menu, str(main.audio.hush_hold), Engine.time_scale])

func path_fn(die_tag := "") -> void:
	main.menu.launch_minigame("five_nights")
	await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame.state == "menu", 25.0)
	await wait(1.5)
	var R = main.minigame
	R.start_night(1)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 12.0)
	await wait(2.0)
	R.st.attack("balon", "door_l")
	await until(func(): return R.state == "dead", 40.0)
	await wait(3.0)
	R.to_terminal()
	await wait(1.5)
	R.quit_to_menu()
	await menu_ready()

func path_golda() -> void:
	main.menu.launch_golda67()
	await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.golda != null, 25.0)
	await wait(10.0)
	main.game._to_menu()
	await menu_ready()

func path_story() -> void:
	main.cinematic_start(FileAccess.file_exists("user://grimerka_save.json"), -1, "")
	await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.golda == null, 30.0)
	await wait(10.0)
	await key_tap(KEY_ESCAPE)
	await wait(2.0)
	main.game._to_menu()
	await menu_ready()

func _real_paths() -> void:
	var vol_keep: float = main.audio.vol["Music"]
	main.audio.set_volume("Music", 0.8, false)
	main.show_menu()
	await menu_ready()
	await path_fn()
	await menu_audible("5 НОЧЕЙ: гибель, В МЕНЮ ОХРАНЫ, выход")
	main.menu.launch_golda67()
	await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.golda != null, 25.0)
	await wait(10.0)
	main.game._to_menu()
	await menu_ready()
	await menu_audible("ГОЛДА 67 → _to_menu()")
	await path_story()
	await menu_audible("сюжет → пауза → _to_menu()")
	main.menu._open_settings()
	await wait(3.0)
	if main.menu.has_method("panel_back"):
		main.menu.panel_back()
	else:
		await key_tap(KEY_ESCAPE)
	await wait(0.5)
	await menu_audible("SETTINGS → назад")
	await path_fn()
	await path_golda()
	await path_story()
	await path_fn()
	await menu_audible("цепочка 5 НОЧЕЙ, ГОЛДА 67, сюжет, 5 НОЧЕЙ без пауз")
	# ползунок на ноль виден в журнале режиссёра, возврат снимает причину
	var t_mark := D.clock
	main.audio.set_volume("Music", 0.0, false)
	await wait(0.6)
	var saw_mute := false
	for e in D.events:
		if float(e["t"]) >= t_mark and e["ev"] == "muted_by_user":
			saw_mute = true
	var snap_mute: bool = D.snapshot()["muted_by_user"]
	main.audio.set_volume("Music", 0.8, false)
	await wait(0.6)
	var saw_unmute := false
	for e in D.events:
		if float(e["t"]) >= t_mark and e["ev"] == "unmuted_by_user":
			saw_unmute = true
	ok(saw_mute and snap_mute and saw_unmute and not D.snapshot()["muted_by_user"], "Music = 0: в журнале muted_by_user («МУЗЫКА ИГРЫ: 0 % в настройках»), после возврата громкости причина снята")
	main.audio.set_volume("Music", vol_keep, false)

## удар по боссу «как в бою»: у босса главы 1 есть неуязвимость на смене фазы и броня вне окна «ОТКРЫТ» — проверка снимает их перед ударом
func _boss_hit(boss, dmg: float, tag: String) -> void:
	print("MUSICCHECK   босс до (%s): hp %.0f / %.0f, фаза %d, age %.2f, phase_guard_until %.2f, weak_t %.2f" % [tag, boss.hp, boss.max_hp, boss.phase, boss.age, boss.phase_guard_until, boss.weak_t])
	boss.guard_until = -1.0
	boss.phase_guard_until = -1.0
	boss.weak_t = 5.0
	boss.take_hit(dmg, Vector3.ZERO, 0.0)
	print("MUSICCHECK   босс после (%s): hp %.0f, фаза %d, phase_guard_until %.2f" % [tag, boss.hp, boss.phase, boss.phase_guard_until])
