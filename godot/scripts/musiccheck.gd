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
	out_a.append_array([D.title, D.cine])
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
	ok(worst <= 3.0, "самый большой шаг громкости музыкального проигрывателя за кадр: %.2f дБ (%s); тише %.0f дБ не считается" % [worst, worst_who, FADE_FLOOR])
	print("MUSICCHECK ", "ok" if fails == 0 else "ОШИБКА: %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
