## Проверка «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: `--resolution 1280x720 -- --microloanscheck=<папка>`.
## Меню режимов → мини-игра (своя сцена, game.gd не создаётся) → новая игра, займ и сумма возврата, проценты
## ночью, график, частичная оплата, минимальный платёж, продление, рефинансирование, просрочка и штраф,
## мелкий шрифт, переговоры (настоящий звонок: пауза, перебил, документ), репутация, стресс, все четыре
## подработки (боты-игроки в настоящих мини-играх), вещи и бартер, события с предупреждением, все концовки,
## сохранение, загрузка, повреждённый файл и резервная копия, симуляции стратегий (никто не уходит
## в бесконечный плюс, честная игра проходима), возврат в меню режимов, кампания после. «MICROLOANSCHECK ok».
extends Node

const KEEP := ["user://grimerka_save.json", "user://microloans_save.json", "user://microloans_save.json.bak"]
var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	for p in KEEP.slice(1):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("MICROLOANSCHECK ok: " if cond else "MICROLOANSCHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.05)

## карьера: дерево навыков (экран, покупка, зависимости), бизнес (покупка, найм, вечерний доход, износ), синергии,
## вехи, копилка между неделями, ЛЕГЕНДА РАЙОНА, миграция старых сохранений, долгие симуляции стратегий
func _career_part(R: MicroloansRoot, e: MLEconomy, U: MLUI) -> void:
	var C: MLCareer = e.career
	ok(C != null and R.career == C, "у недели есть карьера Пахана (MLCareer)")
	var c0 := C.to_dict()
	C.from_dict({})
	ok(int(C.d["level"]) == 1 and (C.d["nodes"] as Dictionary).is_empty(), "старое сохранение без карьеры — начинаем с первого уровня")
	C.from_dict({"xp": 12.0, "level": 3.0, "points": 2.0, "nodes": {"w_hands": 1.0}, "biz": {"workshop": {"lv": 1.0}}})
	ok(int(C.d["level"]) == 3 and C.rank("w_hands") == 1 and C.biz_level("workshop") == 1 and float(C.biz("workshop")["cond"]) == 1.0, "загрузка: числа из JSON — целые, недостающие поля — по умолчанию")
	C.from_dict({})
	C.d["points"] = 3
	# дерево: экран, покупка, зависимости
	e.ending = ""
	e.phase = "day"
	U.show_phase()
	await wait(0.4)
	await shot("m02b_day_cards")
	ok(U.rows.size() >= 9 and U.rows.any(func(r): return not (r["spec"] as Dictionary).is_empty()), "день — карточки действий (%d)" % U.rows.size())
	U.dev_tree()
	await wait(0.5)
	await shot("m10_tree")
	ok(U.screen == "tree" and U.tree_ui != null and U.tree_ui.widgets.size() == MLTree.NODES.size(), "РАЗВИТИЕ ПАХАНА: пять веток, узлов %d" % MLTree.NODES.size())
	ok(C.why_not("w_pro") != "" and C.why_not("w_hands") == "", "закрытый узел объясняет почему (%s), корневой — можно" % C.why_not("w_pro"))
	U.tree_ui.sel = "w_hands"
	U.tree_ui.buy()
	ok(C.rank("w_hands") == 1 and int(C.d["points"]) == 2 and C.pay_mult("repair") > 1.05, "куплен «Руки из плеч»: оплата ×%.2f" % C.pay_mult("repair"))
	var lv0 := int(C.d["level"])
	var ups := C.add_xp(MLCareer.xp_need(lv0) + 5)
	ok(ups >= 1 and int(C.d["level"]) > lv0 and int(C.d["points"]) >= 3, "опыт → уровень %d и очки навыков" % int(C.d["level"]))
	var xs: Array = range(1, 20).map(func(l): return MLCareer.xp_need(l))
	var grows := true
	for i in xs.size() - 1:
		if int(xs[i + 1]) <= int(xs[i]):
			grows = false
	ok(grows and int(xs[1]) < 300 and int(xs[18]) > 4000, "кривая опыта растёт: ур.2 — %d, ур.19 — %d" % [int(xs[1]), int(xs[18])])
	# бизнес
	C.d["level"] = 8
	C.d["points"] = 10
	C.buy_node("b_first")
	ok(C.biz_open("workshop") and not C.biz_open("studio"), "ветка ПРЕДПРИНИМАТЕЛЬ открыла мастерскую, студия ещё закрыта")
	e.money = 60000
	U.biz_screen()
	await wait(0.5)
	await shot("m11_biz")
	var cost := C.biz_up("workshop", e.money)
	e.money -= cost
	var h := C.hire("workshop", e.money)
	e.money -= h
	ok(cost > 0 and h > 0 and C.biz_level("workshop") == 1 and int(C.biz("workshop")["staff"]) == 1, "мастерская куплена за %s, нанят сотрудник за %s" % [MLUI.rub(cost), MLUI.rub(h)])
	var r1 := C.biz_day_one("workshop")
	var r0 := MLTree.BUSINESSES["workshop"]["inc"][0] as int
	ok(int(r1["net"]) > 0 and int(r1["inc"]) > r0, "вечерняя выручка с сотрудником: %+d ₽ (без него — %d)" % [int(r1["net"]), r0])
	var cond0 := float(C.biz("workshop")["cond"])
	C.biz_day()
	ok(float(C.biz("workshop")["cond"]) < cond0, "оборудование изнашивается без автоматики")
	ok(C.service_cost("workshop") > 0 and C.service("workshop") > 0 and float(C.biz("workshop")["cond"]) == 1.0, "обслуживание возвращает исправность")
	var m_before := e.money
	e.day = 2
	e.phase = "evening"
	e.next_phase()
	ok(e.money != m_before, "ночь: выручка бизнеса пришла на счёт (%+d ₽)" % (e.money - m_before))
	# синергия
	C.d["nodes"]["s_haggle"] = 2
	C.d["biz"]["workshop"]["lv"] = 2
	C.cache.clear()
	ok(C.synergy_on(MLTree.SYNERGIES[1]) and C.v("upkeep:workshop") < -0.2, "синергия «МАСТЕРСКАЯ + СХЕМЫ»: расходы мастерской %d %%" % int(C.v("upkeep:workshop") * 100.0))
	# вехи
	C.bump("closed")
	var ms := C.check_milestones()
	ok(ms.any(func(m): return String(m["id"]) == "ms_payoff"), "веха «первый закрытый долг»")
	# копилка между неделями
	var w0 := int(C.d["week"])
	var put := C.end_week(20000, "paid")
	ok(int(C.d["week"]) == w0 + 1 and put > 0 and C.week_debt_k() > 1.0, "конец недели: в копилку %s, долги новой недели ×%.2f" % [MLUI.rub(put), C.week_debt_k()])
	var x := MLEconomy.new()
	x.career = C
	x.new_game(77)
	ok(x.money > MLData.START_MONEY and x.total_debt() > 45000, "новая неделя: старт с копилкой %s, долги %s" % [MLUI.rub(x.money), MLUI.rub(x.total_debt())])
	# ЛЕГЕНДА РАЙОНА
	C.d["level"] = MLTree.LEGEND_LEVEL
	ok(C.prestige_ready(), "уровень %d — открыта ЛЕГЕНДА РАЙОНА" % MLTree.LEGEND_LEVEL)
	U.legend_screen()
	await wait(0.4)
	await shot("m12_legend")
	var pv := C.prestige_preview()
	ok((pv["lose"] as Array).size() >= 3 and (pv["keep"] as Array).size() >= 2 and int(pv["gain"]) > 0, "перед престижем видно, что потеряется и что останется (+%d АВТОРИТЕТА)" % int(pv["gain"]))
	var gain := C.prestige()
	ok(gain > 0 and int(C.d["legend"]["points"]) == gain and (C.d["nodes"] as Dictionary).is_empty() and C.biz_count() == 0 and int(C.d["level"]) == 1, "престиж: навыки и бизнесы сброшены, АВТОРИТЕТ %d" % gain)
	ok(C.legend_buy("L_start") and C.v("start_money") > 0.0, "бонус ЛЕГЕНДЫ куплен навсегда")
	# симуляции карьеры
	var tot := {}
	for s in ["clean", "workshop", "delivery", "credit", "combo", "auto"]:
		var r := MLCareer.simulate(s, 10, 21)
		tot[s] = int(r["total"])
		var w: Array = r["weeks"]
		print("MICROLOANSCHECK   карьера %-9s 10 недель: %7d ₽, уровень %d, бизнесов %d, неделя 1 — %s, неделя 3 — %s" % [s, int(r["total"]), int(r["level"]), int(r["biz"]), w[0]["ending"], w[2]["ending"]])
		ok(String(w[0]["ending"]) == "paid", "стратегия «%s»: первая неделя проходима" % s)
	var best := 0
	for s in tot:
		best = maxi(best, int(tot[s]))
	ok(float(tot["combo"]) > float(best) * 0.55, "развитие всех веток не хуже лучшей узкой стратегии больше чем вдвое (%d из %d)" % [int(tot["combo"]), best])
	ok(float(tot["workshop"]) > float(tot["clean"]) and float(tot["delivery"]) > float(tot["clean"]), "бизнес обгоняет одни подработки на длинной дистанции")
	ok(float(best) < float(tot["clean"]) * 5.0, "ни одна стратегия не отрывается безумно (лучшая ×%.1f от одних подработок)" % (float(best) / maxf(1.0, float(tot["clean"]))))
	C.from_dict(c0)
	U.show_phase()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	var grim0 = kept[KEEP[0]]
	# ================= вход из меню режимов =================
	var mm = main.menu
	var idx := -1
	for k in ModeSelect.MODES.size():
		if String(ModeSelect.MODES[k]["id"]) == "microloans":
			idx = k
	ok(idx >= 0, "в выборе режима есть ПАХАН НАБРАЛ МИКРОЗАЙМОВ")
	mm.open_modes(idx)
	await wait(0.7)
	await shot("m00_mode_card")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null, "карточка открывает экран режима (новая игра / продолжить)")
	mm._panel_select(0, false)
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is MicroloansRoot, 15.0)
	ok(started, "мини-игра запустилась своей сценой")
	if not started:
		_finish()
		return
	ok(main.game == null and main.race == null, "основная игра и гонки не созданы")
	var R: MicroloansRoot = main.minigame
	await wait(1.5)
	var e := R.econ
	var U := R.ui
	ok(e.day == 1 and e.active().size() == 4 and e.total_debt() >= 40000, "новая неделя: день 1, четыре долга на %s" % MLUI.rub(e.total_debt()))
	ok(R.pahan != null and R.pahan.model != null, "в комнате настоящий Пахан (pahan.glb)")
	await shot("m01_morning")
	MLSave.persist = true
	# ================= займ: условия до подписания, сумма возврата =================
	if e.event_today != "" and not e.event_done:
		e.resolve_event((MLData.EVENTS[e.event_today]["choices"] as Array).size() - 1)
	e.next_phase()
	U.show_phase()
	await wait(0.3)
	ok(e.phase == "day" and e.actions == MLData.ACTIONS, "день: %d действия" % e.actions)
	U.offers()
	await wait(0.3)
	await shot("m02_offers")
	var O: Dictionary = e.offers[0]
	var pv := e.preview("take", {"offer": O})
	ok(pv["lines"].size() >= 1 and int(pv["debt"]) == e.total_debt() + int(O["amount"]), "до подписания видно: на руки, вернуть к сроку, долг станет %s" % MLUI.rub(int(pv["debt"])))
	var hidden := e.offers.filter(func(o): return o["clause"] != "" and not o["known"])
	if not hidden.is_empty():
		var a0 := e.actions
		e.study(int(hidden[0]["id"]))
		ok(bool(hidden[0]["known"]) and e.actions == a0 - 1, "мелкий шрифт: «изучить договор» — одно действие, приписка видна")
	var m0 := e.money
	var d0 := e.total_debt()
	e.take(int(O["id"]))
	var L: Dictionary = e.loans.back()
	var C: Dictionary = MLData.CLAUSES.get(String(L["clause"]), ["", {}])[1]
	ok(e.money == m0 + int(float(L["principal"]) * (1.0 - float(C.get("cut", 0.0)))) and e.total_debt() == d0 + int(L["principal"]), "займ выдан: +%s на руки, долг +%s" % [MLUI.rub(e.money - m0), MLUI.rub(int(L["principal"]))])
	ok(int(L["due"]) == e.day + int(MLData.LENDERS[L["lender"]]["term"]), "график: срок — день %d" % int(L["due"]))
	# частичная оплата, минимальный, продление
	var bal0 := float(L["balance"])
	e.pay(int(L["id"]), 1000)
	ok(float(L["balance"]) < bal0, "частичная оплата: долг %s → %s" % [MLUI.rub(int(bal0)), MLUI.rub(int(L["balance"]))])
	var due0 := int(L["due"])
	if e.pay_min(int(L["id"])):
		ok(int(L["due"]) == due0 + 1, "минимальный платёж: срок +1 день")
	var e_info := e.extend_info(L)
	if bool(e_info["ok"]):
		var due1 := int(L["due"])
		e.extend(int(L["id"]))
		ok(int(L["due"]) > due1, "продление: срок %d → %d за %s" % [due1, int(L["due"]), MLUI.rub(int(e_info["fee"]))])
	else:
		ok(String(e_info["why"]) != "", "продление недоступно — понятно почему: %s" % e_info["why"])
	# рефинансирование
	var two := e.active().filter(func(x): return x["lender"] in ["bystro", "srochno"]).map(func(x): return int(x["id"]))
	var info := e.refinance_info(two, "cash")
	var pvr := e.preview("refinance", {"ids": two, "lender": "cash"})
	ok(pvr["lines"].size() == 2, "рефинансирование: последствия видно заранее (%s)" % pvr["lines"][0])
	if bool(info["ok"]):
		var n0 := e.active().size()
		e.refinance(two, "cash")
		ok(e.active().size() == n0 - two.size() + 1 and e.loans.back().has("from"), "рефинансирование: %d долга закрыты новым" % two.size())
	else:
		ok(true, "рефинансирование сейчас нельзя: %s" % info["why"])
	# карта долгов
	U.debt_flow()
	await wait(0.4)
	ok(U.screen == "flow" and U.flow_canvas != null, "КАРТА ДОЛГОВ открыта")
	await shot("m03_debt_flow")
	U._flow_keys(KEY_Q)
	ok(U.flow_focus >= 0 and U.pay_amount >= 0, "стратегия «самый дорогой» выбирает долг")
	U._flow_keys(KEY_E)
	U.show_phase()
	# ================= подработки: настоящие мини-игры с ботом =================
	var good_clean := 0
	for jid in ["podezd", "repair", "deliv", "junk"]:
		e.actions = maxi(e.actions, 1)
		var mb := e.money
		if jid == "podezd":
			e.rng.seed = 4242                       # тот же уровень уборки достанется и «плохому» боту ниже
		var J: MLJob = U.run_job(jid, 0.9)
		await wait(0.3)
		ok(J is MLJob3D and (J as MLJob3D).vp != null, "подработка %s — своя 3D-сцена" % MLData.JOBS[jid]["name"])
		await wait(4.0)
		await shot("m04_job_" + jid)
		var fin: bool = await until(func(): return not is_instance_valid(J) or J.done, 70.0)
		await wait(0.3)
		ok(fin and e.money > mb, "подработка %s: бот прошёл, +%s" % [MLData.JOBS[jid]["name"], MLUI.rub(e.money - mb)])
		if jid == "podezd":
			good_clean = e.money - mb
	# звукарь нужен с репутацией
	e.rep = 60
	e.actions = maxi(e.actions, 1)
	var ms := e.money
	var JS: MLJob = U.run_job("sound", 0.9)
	await wait(4.0)
	await shot("m05_job_sound")
	await until(func(): return not is_instance_valid(JS) or JS.done, 70.0)
	await wait(0.3)
	ok(e.money > ms, "ЗВУКАРЬ: +%s" % MLUI.rub(e.money - ms))
	# плохой игрок получает меньше
	e.actions = maxi(e.actions, 1)
	var mp := e.money
	e.rng.seed = 4242
	var JP: MLJob = U.run_job("podezd", 0.1)
	await until(func(): return not is_instance_valid(JP) or JP.done, 70.0)
	await wait(0.3)
	ok(e.money - mp < int(float(good_clean) * 0.85), "плохо убрал — меньше денег (%s против %s у аккуратного)" % [MLUI.rub(e.money - mp), MLUI.rub(good_clean)])
	# стресс и отдых
	e.stress = 85
	ok(e.actions_max() == MLData.ACTIONS - 1, "высокий стресс отнимает действие")
	e.actions = 1
	e.rest()
	ok(e.stress == 60, "отдых снимает стресс (85 → %d)" % e.stress)
	# вещи и бартер
	var rl := e.active().filter(func(x): return x["lender"] == "reshim")
	if not rl.is_empty():
		e.inventory.append(0)                      # кассетный плеер — Гена его возьмёт
		var rb := float(rl[0]["balance"])
		e.barter(e.inventory.size() - 1, int(rl[0]["id"]))
		ok(float(rl[0]["balance"]) < rb, "бартер: «Решим вопрос» взял вещь в счёт долга")
	# ================= переговоры — настоящий звонок =================
	var tgt: Dictionary = e.active()[0]
	tgt["due"] = e.day
	var N: MLNegotiation = U.negotiate(int(tgt["id"]), func(): pass)
	await wait(0.2)
	await shot("m06_call")
	# голос: у каждой конторы озвучены свои фразы и общие ответы; в трубке говорит коллектор именно этой конторы
	var v_need := 0
	var v_have := 0
	for li in MLData.LENDER_ORDER.size():
		var lines: Array = (MLData.LENDERS[MLData.LENDER_ORDER[li]]["voice"] as Array).duplicate()
		for key in MLData.COLLECTOR:
			lines.append_array(MLData.COLLECTOR[key])
		for ln in lines:
			v_need += 1
			if ResourceLoader.exists(MLNegotiation.voice_path("C%d" % (li + 1), String(ln))):
				v_have += 1
	ok(v_need >= 48 and v_have == v_need, "коллекторы четырёх контор озвучены: %d из %d реплик" % [v_have, v_need])
	ok(N.vo.playing and N.vo.bus == "Phone" and N.vcode == "C%d" % (MLData.LENDER_ORDER.find(String(tgt["lender"])) + 1), "звонок: коллектор говорит голосом своей конторы (%s), как из трубки" % N.vcode)
	ok(N.speak_len >= N.vo.stream.get_length(), "фраза держится на экране, пока её договаривают (%.1f с)" % N.speak_len)
	var tr0 := N.trust
	await until(func(): return N.speaking, 2.0)
	N.play(0)
	ok(N.trust < tr0, "перебил коллектора — доверие упало (%.0f → %.0f)" % [tr0, N.trust])
	N.play(0)                                            # вторая «отсрочка» посреди фразы: коллектор отвечает и обрывает себя
	var first := N.vo.stream
	ok(N.hold_t > 0.0 and N.vo.playing and N.vo.stream.resource_path == MLNegotiation.voice_path(N.vcode, String(MLData.COLLECTOR["again"][0])), "ответ коллектора звучит вместо недосказанной фразы, звонок ждёт (%.1f с)" % N.hold_t)
	var t_hold := N.t_left
	var ph := N.phrase
	await wait(0.4)
	ok(is_equal_approx(N.t_left, t_hold) and N.phrase == ph and N.vo.stream == first, "пока коллектор отвечает, время разговора стоит и новая фраза не начинается")
	await until(func(): return N.hold_t <= 0.0 and N.phrase > ph, 8.0)
	ok(N.phrase > ph and N.vo.playing and N.vo.stream != first, "ответ прозвучал — пошла следующая фраза")
	await until(func(): return not N.speaking, 9.0)
	var tr1 := N.trust
	N.play(1 if N._avail(1) == "" else 2 if N._avail(2) == "" else 3)
	ok(N.trust >= tr1 or N.doc_mode, "ответил в паузу — доверие выросло")
	if N.doc_mode:
		N.pick_doc(N.DOCS.map(func(d): return d[0]).find(N.doc_right))
	await until(func(): return not N.speaking and N.hold_t <= 0.0, 14.0)
	N.play(3)
	ok(N.doc_mode, "«ПРЕДЪЯВИТЬ ДОКУМЕНТ» открывает ящик стола")
	await shot("m07_documents")
	var tr2 := N.trust
	N.pick_doc(N.DOCS.map(func(d): return d[0]).find(N.doc_right))
	ok(N.trust > tr2, "нужная бумага найдена — доверие +%.0f" % (N.trust - tr2))
	var due_before := int(tgt["due"])
	N._end()
	await wait(1.4)
	ok(int(tgt["due"]) >= due_before, "итог переговоров применён: срок %d → %d" % [due_before, int(tgt["due"])])
	# повтор уступок — не абуз
	tgt["talk_wins"] = 2
	var bal_t := float(tgt["balance"])
	e.negotiation_result(int(tgt["id"]), 90.0, 0.0, 0, false)
	ok(float(tgt["balance"]) >= bal_t - 0.5, "третья уступка по одному займу не даётся")
	# ================= ночь: проценты, просрочка =================
	var night_l: Dictionary = e.active()[0]
	var b0 := float(night_l["balance"])
	night_l["due"] = e.day
	var rep0 := e.rep
	e.phase = "evening"
	e.next_phase()
	ok(float(night_l["balance"]) > b0 and night_l["status"] == "overdue" and e.rep < rep0, "ночь: проценты и штраф начислены, просрочка, репутация упала")
	ok(e.day >= 2 and e.phase == "morning", "наступил день %d" % e.day)
	# события с предупреждением
	e.warned.clear()
	e.warned["collector_visit"] = e.day + 1
	e.day += 1
	e._pick_event()
	ok(e.event_today == "collector_visit", "событие с предупреждением наступает на следующий день")
	U.show_phase()
	await wait(0.3)
	await shot("m08_event")
	# ================= сохранение и загрузка =================
	R.save()
	ok(FileAccess.file_exists(MLSave.PATH), "сохранение: user://microloans_save.json")
	var money_saved := e.money
	var e2 := MLEconomy.new()
	ok(MLSave.load_run(e2) and e2.money == money_saved and e2.loans.size() == e.loans.size() and e2.day == e.day, "загрузка: те же деньги, долги и день")
	R.save()                                      # теперь есть .bak
	var f := FileAccess.open(MLSave.PATH, FileAccess.WRITE)
	f.store_string("{сломано")
	f.close()
	var e3 := MLEconomy.new()
	ok(MLSave.load_run(e3) and e3.day == e.day, "повреждённый файл: загружена резервная копия")
	ok(FileAccess.get_file_as_string(KEEP[0]) == (grim0 if grim0 != null else ""), "сюжетное сохранение не тронуто")
	# ================= концовки =================
	var seen := {}
	for c in [["paid", {}], ["talks", {"talk_closed": 2}], ["king", {"taken": 5, "closed": 8, "fines": 0}], ["business", {}], ["pit", {}]]:
		var x := MLEconomy.new()
		x.new_game(5)
		for k in (c[1] as Dictionary):
			x.stats[k] = int(c[1][k])
		if c[0] != "pit":
			for l2 in x.loans:
				l2["status"] = "closed"
				l2["balance"] = 0.0
		if c[0] == "business":
			x.flags["business"] = true
		if c[0] == "king":
			x.stats["fines"] = 0
		seen[x.compute_ending()] = true
	ok(seen.size() == 5, "все пять концовок: %s" % ", ".join(seen.keys()))
	e.ending = "paid"
	U.ending()
	await wait(0.4)
	await shot("m09_ending")
	ok(U.screen == "ending" and MLSave.load_all().get("endings", {}).has("paid"), "экран концовки, концовка записана в зал славы")
	await _career_part(R, e, U)
	# ================= тесты «на взлом» экономики (ml_abuse.gd) =================
	for ab in MLAbuse.run():
		ok(bool(ab[1]), "абуз закрыт: %s — %s" % [ab[0], ab[2]])
	# в паузе больше нет «НАЧАТЬ ЗАНОВО» (оно стирало долги): вместо него — «СДАТЬСЯ» с подтверждением
	U.pause_menu()
	await wait(0.3)
	var pause_names: Array = U.rows.map(func(r): return String(r["label"].text) if r.has("label") else "") if "rows" in U else []
	await shot("m10_pause_surrender")
	U.show_phase()
	await wait(0.2)
	# ================= симуляции стратегий =================
	var res := {}
	for s in ["juggler", "grinder", "balanced", "talker", "borrower", "abuser", "lazy"]:
		for sk in [0.5, 0.8]:
			var b := MLSim.batch(s, 80, sk)
			res["%s_%.1f" % [s, sk]] = b
			print("MICROLOANSCHECK   симуляция %-9s мастерство %.1f: побед %3d%%, итог в середине %7d, лучший %7d, %s" % [s, sk, int(b["win"] * 100), b["median_net"], b["max_net"], str(b["ends"])])
	var max_all := 0
	for k in res:
		max_all = maxi(max_all, int(res[k]["max_net"]))
	ok(max_all < 70000, "ни одна стратегия не уходит в бесконечный плюс (лучший итог %s)" % MLUI.rub(max_all))
	ok(float(res["grinder_0.8"]["win"]) > 0.85 and float(res["balanced_0.8"]["win"]) > 0.85, "честная хорошая игра проходима")
	ok(float(res["grinder_0.5"]["win"]) < 0.9 and float(res["balanced_0.5"]["win"]) < 0.9, "средняя игра — не гарантия (напряжение есть)")
	ok(float(res["lazy_0.5"]["win"]) == 0.0 and float(res["borrower_0.8"]["win"]) < 0.2 and float(res["abuser_0.8"]["win"]) < 0.3, "лень, займы ради займов и абуз — проигрыш")
	var all_ends := {}
	for k in res:
		for en in res[k]["ends"]:
			all_ends[en] = true
	ok(all_ends.size() == 5, "в симуляциях встречаются все концовки (%s)" % ", ".join(all_ends.keys()))
	# ================= выход в меню режимов и кампания =================
	R.quit_to_menu()
	var back: bool = await until(func(): return main.menu != null and main.minigame == null and main.menu.modes.visible, 8.0)
	ok(back, "выход — в меню режимов")
	main.start_game(false, 0)
	var camp: bool = await until(func(): return main.game != null and main.game.player != null, 20.0)
	ok(camp, "кампания после мини-игры запускается")
	main.game._to_menu()
	await wait(1.0)
	_finish()

func _finish() -> void:
	MLSave.persist = true
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	AudioServer.set_bus_mute(0, false)
	print("MICROLOANSCHECK ok" if fails == 0 else "MICROLOANSCHECK ОШИБКА: %d" % fails)
	get_tree().quit()
