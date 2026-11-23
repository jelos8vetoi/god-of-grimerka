## Тесты «на взлом» экономики «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: каждый намеренно пытается получить деньги, опыт или
## имущество в обход правил — повторной наградой, сбросом недели, займами, перезагрузкой, мусорным вводом.
## Чистая логика (MLEconomy + MLCareer), без сцены: гоняется из --microloanscheck и без окна:
##   Godot --headless --path godot --script res://scripts/microloans/ml_abuse_run.gd
## run() возвращает [[название, прошло ли, подробности]]. Новая дыра — новый тест здесь.
class_name MLAbuse

static func _game(seed_v := 11, with_career := true) -> MLEconomy:
	var e := MLEconomy.new()
	if with_career:
		e.career = MLCareer.new()
	e.new_game(seed_v)
	e.phase = "day"
	return e

static func _wealth(e: MLEconomy) -> int:
	var w := e.money + int(e.career.d["bank"])
	for id in MLTree.BUSINESS_ORDER:
		w += e.career.biz_value(String(id))
	return w

static func _finite(e: MLEconomy) -> bool:
	if e.money < 0 or e.actions < 0 or e.stress < 0 or e.stress > 100 or e.rep < 0 or e.rep > 100:
		return false
	for L in e.loans:
		var b := float(L["balance"])
		if is_nan(b) or is_inf(b) or b < -0.01:
			return false
	return true

static func run() -> Array:
	var out: Array = []
	var add := func(name: String, ok: bool, detail: String):
		out.append([name, ok, detail])

	# 1. награда за заказ — один раз: повторный сигнал, чужой и старый номер, сдача без заказа
	var e := _game()
	var m0 := e.money
	var t := e.job_begin("repair", 1)
	var p1 := e.job_finish(t, 0.9)
	var p2 := e.job_finish(t, 0.9)
	var p3 := e.job_finish(t + 5, 0.9)
	var p4 := e.job_finish(0, 1.0)
	var p5 := e.job_finish(-3, 1.0)
	add.call("заказ оплачивается один раз", t > 0 and p1 > 0 and p2 == 0 and p3 == 0 and p4 == 0 and p5 == 0 and e.money == m0 + p1,
		"первая сдача %d ₽, повтор %d, чужой номер %d, без заказа %d/%d" % [p1, p2, p3, p4, p5])

	# 2. действие списывается при взятии заказа; второй заказ поверх первого взять нельзя; без действий — нельзя
	e = _game()
	var a0 := e.actions
	var t1 := e.job_begin("repair", 1)
	var t2 := e.job_begin("podezd", 1)
	var a1 := e.actions
	e.job_finish(t1, 0.5)
	e.actions = 0
	var t3 := e.job_begin("repair", 1)
	add.call("заказ: действие сразу, два заказа сразу нельзя", t1 > 0 and t2 == 0 and a1 == a0 - 1 and t3 == 0 and e.actions == 0,
		"действий %d → %d, второй заказ %d, без действий %d" % [a0, a1, t2, t3])

	# 3. вышел посреди работы и загрузился: заказ брошен, действие не вернулось, денег нет
	e = _game()
	m0 = e.money
	a0 = e.actions
	var t4 := e.job_begin("deliv", 1)
	var saved := e.to_dict().duplicate(true)
	var e2 := MLEconomy.new()
	e2.career = MLCareer.new()
	e2.from_dict(JSON.parse_string(JSON.stringify(saved)))
	var pending: bool = not e2.job_pending.is_empty()
	e2.job_abandon()
	var late := e2.job_finish(t4, 1.0)
	add.call("перезагрузка посреди заказа не возвращает действие и не платит", pending and e2.actions == a0 - 1 and e2.money == m0 and late == 0 and e2.job_pending.is_empty(),
		"в сохранении заказ есть: %s; действий %d (было %d), деньги %d → %d, поздняя сдача %d" % [str(pending), e2.actions, a0, m0, e2.money, late])

	# 4. «зашёл и вышел»: нулевая работа не оплачивается (и NaN — тоже ноль)
	e = _game()
	m0 = e.money
	var z1 := e.job_done("podezd", 0.0)
	var z2 := e.job_done("repair", NAN)
	add.call("нулевая работа не оплачивается", z1 == 0 and z2 == 0 and e.money == m0, "оплата %d и %d" % [z1, z2])

	# 5. займ «взял и сразу вернул»: ни репутации, ни опыта, ни «закрытого долга» — и стоит процентов за сутки
	e = _game()
	e.rep = 60
	e._make_offers()
	e.actions = 20
	m0 = e.money
	var rep0 := e.rep
	var xp0 := int(e.career.d["xp"]) + int(e.career.d["level"]) * 100000
	var st0 := e.stress
	var n_take := 0
	for O in e.offers.duplicate():
		if e.take(int(O["id"])):
			n_take += 1
	e.money += 6000                                       # своих денег хватает на проценты за сутки
	m0 = e.money
	for L in e.active():
		if e.same_day(L):
			e.pay(int(L["id"]), int(ceil(float(L["balance"]) * 2.0)))
	var fresh_left := e.active().filter(func(L): return e.same_day(L)).size()
	var lost := 6000 + MLData.START_MONEY - e.money
	add.call("займ «взял и сразу вернул» ничего не даёт", n_take >= 2 and fresh_left == 0 and e.rep <= rep0 and int(e.career.d["xp"]) + int(e.career.d["level"]) * 100000 == xp0 and int(e.stats["closed"]) == 0 and lost > 0 and e.stress >= st0,
		"взято и возвращено %d займов: потеряно %d ₽ (проценты за сутки и удержания), репутация %d → %d, опыт тот же, закрытых в зачёт %d" % [n_take, lost, rep0, e.rep, int(e.stats["closed"])])

	# 6. король микрозаймов так не получается: концовка «king» не выдаётся за однодневные возвраты
	for L in e.active():
		e.money += int(ceil(L["balance"])) + 10
		e.pay(int(L["id"]), int(ceil(L["balance"])) + 10)
	add.call("концовка не накручивается однодневными займами", e.compute_ending() != "king", "долг %d, взято %d, закрыто %d → «%s»" % [e.total_debt(), int(e.stats["taken"]), int(e.stats["closed"]), e.compute_ending()])

	# 7. сдаться (бывшее «НАЧАТЬ ЗАНОВО»): долги не исчезают, наличные и имущество забирают, хвост переходит дальше
	e = _game()
	e.rep = 80
	e._make_offers()
	e.actions = 20
	for O in e.offers.duplicate():
		e.take(int(O["id"]))
	e.career.d["nodes"]["b_first"] = 1
	e.career.cache.clear()
	var bought := 0
	for id in MLTree.BUSINESS_ORDER:
		var c := e.career.biz_up(String(id), e.money)
		if c > 0:
			e.money -= c
			bought += 1
	var debt0 := e.total_debt()
	var w0 := _wealth(e)
	e.surrender()
	var w1 := _wealth(e)
	var tail := int(e.career.d["carry_debt"])
	e.new_game(12)
	var tail_loan := e.active().filter(func(L): return bool(L.get("tail", false)))
	@warning_ignore("integer_division")
	add.call("бросить неделю — не бесплатный сброс", e.career.biz_count() == 0 and w1 <= w0 / 4 and tail > 0 and tail_loan.size() == 1 and int(e.career.d["carry_debt"]) == 0,
		"долг был %d, куплено бизнесов %d; имущество и деньги %d → %d; хвост %d ₽ пришёл займом в новой неделе" % [debt0, bought, w0, w1, tail])

	# 8. цикл «занял — вложил — бросил» шесть недель подряд: богатства из воздуха нет
	e = _game(21)
	e.career.d["nodes"]["b_first"] = 1
	e.career.cache.clear()
	var peak := 0
	for w in 6:
		e.rep = 80
		e._make_offers()
		e.actions = 20
		for O in e.offers.duplicate():
			e.take(int(O["id"]))
		for id in MLTree.BUSINESS_ORDER:
			var c2 := e.career.biz_up(String(id), e.money)
			if c2 > 0:
				e.money -= c2
		e.surrender()
		peak = maxi(peak, _wealth(e))
		e.new_game(30 + w)
	add.call("цикл «занял — вложил — бросил» не копит имущество", peak <= MLData.START_MONEY * 2 and e.career.biz_count() == 0 and int(e.career.d["bank"]) == 0,
		"за 6 недель наибольшее состояние после сброса %d ₽, бизнесов %d, копилка %d" % [peak, e.career.biz_count(), int(e.career.d["bank"])])

	# 9. «яма» на седьмой день с деньгами на руках: занятое в копилку не уходит
	e = _game(31)
	e.rep = 80
	e.day = MLData.DAYS
	e._make_offers()
	e.actions = 20
	for O in e.offers.duplicate():
		e.take(int(O["id"]))
	var cash := e.money
	e.phase = "evening"
	e.next_phase()
	add.call("занять в последний день и уйти в яму с деньгами нельзя", e.ending == "pit" and int(e.career.d["bank"]) == 0 and cash > 5000,
		"на руках было %d ₽, концовка «%s», в копилке %d" % [cash, e.ending, int(e.career.d["bank"])])

	# 10. конец недели считается один раз
	var week_a := int(e.career.d["week"])
	e._end_week()
	e.finish()
	e.surrender()
	add.call("неделя закрывается один раз", int(e.career.d["week"]) == week_a, "неделя %d → %d после трёх повторных закрытий" % [week_a, int(e.career.d["week"])])

	# 11. ночь и выручка бизнеса — раз в сутки
	e = _game(41)
	e.career.d["nodes"]["b_first"] = 1
	e.career.cache.clear()
	e.money = 200000
	e.money -= e.career.biz_up("workshop", e.money)
	var inc0 := (e.career.d["income"] as Array).size()
	var d0 := e.day
	e.phase = "evening"
	e.next_phase()
	add.call("ночь и выручка — раз в сутки", e.day == d0 + 1 and (e.career.d["income"] as Array).size() == inc0 + 1 and e.phase == "morning",
		"день %d → %d, записей выручки +%d" % [d0, e.day, (e.career.d["income"] as Array).size() - inc0])

	# 12. сохранение и загрузка посреди дня дают то же самое состояние (выручка и проценты не дублируются)
	e = _game(51)
	e.job_done("repair", 0.8)
	if not e.offers.is_empty():
		e.take(int(e.offers[0]["id"]))
	var s1 := JSON.stringify(e.to_dict())
	var e3 := MLEconomy.new()
	e3.career = MLCareer.new()
	e3.from_dict(JSON.parse_string(s1))
	var s2 := JSON.stringify(e3.to_dict())
	add.call("сохранение и загрузка не меняют состояние", s1 == s2, "длина записи %d и %d" % [s1.length(), s2.length()])

	# 13. продление, минимальный платёж и уступки в переговорах — с пределом
	e = _game(61)
	e.money = 500000
	var L0: Dictionary = e.active()[0]
	var id0 := int(L0["id"])
	var ext := 0
	for k in 10:
		if e.extend(id0):
			ext += 1
	var mins := 0
	for k in 10:
		if e.pay_min(id0):
			mins += 1
	var wins := 0
	for k in 10:
		if bool(e.negotiation_result(id0, 100.0, 0.0, 0, true).get("won", false)):
			wins += 1
	add.call("отсрочки не бесконечны", ext <= 2 and mins <= 2 and wins <= 2, "продлений %d, минимальных платежей %d, уступок %d (срок теперь день %d)" % [ext, mins, wins, int(L0["due"])])

	# 14. рефинансирование: один долг дважды в списке, закрытый долг, своя же контора
	e = _game(71)
	e.rep = 90
	var ids: Array = [int(e.active()[0]["id"]), int(e.active()[0]["id"]), int(e.active()[0]["id"])]
	var one := e.refinance_info([ids[0]], "cash")
	var tri := e.refinance_info(ids, "cash")
	var self_l := e.refinance_info([ids[0]], String(e.active()[0]["lender"]))
	var debt_b := e.total_debt()
	e.refinance([ids[0]], "cash")
	var again := e.refinance([ids[0]], "reshim")
	var paid_closed := e.pay(ids[0], 1000)
	add.call("рефинансирование без дублей", int(one["new"]) == int(tri["new"]) and not bool(self_l["ok"]) and not again and not paid_closed and e.total_debt() >= debt_b,
		"один долг трижды в списке: %d = %d; закрытый снова: %s; платёж по закрытому: %s; долг %d → %d" % [int(one["new"]), int(tri["new"]), str(again), str(paid_closed), debt_b, e.total_debt()])

	# 15. платежи с мусором: ноль, минус, больше, чем есть; комиссия не съедает больше внесённого
	e = _game(81)
	e.money = 3000
	var lid := int(e.active()[0]["id"])
	var r0 := e.pay(lid, 0)
	var rn := e.pay(lid, -5000)
	var rb := e.pay(999999, 100)
	var rh := e.pay(lid, 9999999)
	add.call("платёж с мусорными суммами", not r0 and not rn and not rb and rh and e.money >= 0 and _finite(e), "ноль %s, минус %s, чужой номер %s, сверх денег %s; денег осталось %d" % [str(r0), str(rn), str(rb), str(rh), e.money])

	# 16. вещь не продаётся дважды, улучшение не покупается дважды, событие не решается дважды
	e = _game(91)
	e.inventory = [0]
	var s_a := e.sell_item(0)
	var s_b := e.sell_item(0)
	var s_c := e.sell_item(-1)
	e.money = 100000
	var b_a := e.buy("calc")
	var m_b := e.money
	var b_b := e.buy("calc")
	e.event_today = "windfall"
	e.event_done = false
	e.flags.erase("ev_windfall")
	var m_e := e.money
	e.resolve_event(0)
	var m_e2 := e.money
	var again_ev := e.resolve_event(0)
	add.call("продажа, покупка и событие — по одному разу", s_a and not s_b and not s_c and b_a and not b_b and e.money == m_e2 and m_e2 > m_e and again_ev.is_empty() and m_b == m_e,
		"продажа %s/%s/%s, покупка %s/%s, событие +%d и повтор %s" % [str(s_a), str(s_b), str(s_c), str(b_a), str(b_b), m_e2 - m_e, str(not again_ev.is_empty())])

	# 17. нанял — уволил — нанял: опыт только за первое место; деньги только уходят
	e = _game(101)
	e.career.d["nodes"]["b_first"] = 1
	e.career.cache.clear()
	e.money = 300000
	e.money -= e.career.biz_up("workshop", e.money)
	var firsts := 0
	var spent := 0
	for k in 6:
		var hc := e.career.hire("workshop", e.money)
		if hc > 0:
			e.money -= hc
			spent += hc
			if e.career.hire_first("workshop"):
				firsts += 1
			e.career.fire("workshop")
	add.call("нанять-уволить по кругу опыта не даёт", firsts == 1 and spent > 0, "наймов 6, опыт начислен %d раз, потрачено %d ₽" % [firsts, spent])

	# 18. вехи: награда один раз; престиж не считает вехи прошлого цикла снова
	e = _game(111)
	e.career.d["stats"]["jobs"] = 100000
	e.career.d["stats"]["earned"] = 100000000
	var ms1 := e.career.check_milestones().size()
	var ms2 := e.career.check_milestones().size()
	e.career.d["level"] = 99
	var pts_a := e.career.prestige_points()
	e.career.prestige()
	e.career.d["level"] = 99
	e.career.d["stats"]["earned"] = 100000000
	var pts_b := e.career.prestige_points()
	add.call("вехи и престиж не дают награду дважды", ms1 > 0 and ms2 == 0 and pts_b < pts_a, "вех %d, повторно %d; АВТОРИТЕТ за цикл: %d, за следующий при тех же числах: %d" % [ms1, ms2, pts_a, pts_b])

	# 19. обезьяна: тысячи случайных действий с мусорными аргументами — деньги, действия и долги остаются в рамках
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var bad := ""
	var ops := 0
	for round_i in 12:
		e = _game(200 + round_i)
		for k in 400:
			if e.ending != "":
				e.new_game(rng.randi())
				e.phase = "day"
			var lo: int = int(e.loans[rng.randi() % e.loans.size()]["id"]) if not e.loans.is_empty() else 1
			var amt := rng.randi_range(-50000, 200000)
			ops += 1
			match rng.randi() % 19:
				0: e.pay(lo if rng.randf() < 0.8 else rng.randi_range(-5, 500), amt)
				1: e.pay_min(lo)
				2: e.extend(lo)
				3: e.refinance([lo, lo, rng.randi_range(-3, 40)], String(MLData.LENDER_ORDER[rng.randi() % 4]))
				4:
					if not e.offers.is_empty():
						e.take(int(e.offers[rng.randi() % e.offers.size()]["id"]))
				5: e.job_done(String(MLData.JOB_ORDER[rng.randi() % MLData.JOB_ORDER.size()]), rng.randf_range(-2.0, 3.0), rng.randi_range(-4, 30))
				6: e.job_finish(rng.randi_range(-5, e.job_seq + 5), rng.randf_range(-1.0, 2.0), [[rng.randi_range(-5, 40), "sell"], [0, "keep"], "мусор", [1]])
				7: e.junk_done([[rng.randi_range(-3, 30), ["sell", "scrap", "keep", "?"][rng.randi() % 4]], [2, "sell"]])
				8: e.sell_item(rng.randi_range(-3, 12))
				9: e.barter(rng.randi_range(-3, 12), lo)
				10: e.rest()
				11: e.buy(String(MLData.UPGRADE_ORDER[rng.randi() % MLData.UPGRADE_ORDER.size()]))
				12: e.resolve_event(rng.randi_range(-3, 9))
				13: e.negotiation_result(lo, rng.randf_range(-50.0, 150.0), rng.randf_range(-50.0, 150.0), rng.randi_range(-1000, 9000), rng.randf() < 0.3)
				14: e.next_phase()
				15: e.start_call(lo)
				16: e.job_begin(String(MLData.JOB_ORDER[rng.randi() % MLData.JOB_ORDER.size()]), rng.randi_range(-2, 9))
				17: e.job_abandon()
				18:
					if not e.offers.is_empty():
						e.study(int(e.offers[0]["id"]))
						e.call_operator(int(e.offers[0]["id"]))
			if not _finite(e) and bad == "":
				bad = "раунд %d, шаг %d: деньги %d, действий %d, стресс %d, репутация %d" % [round_i, k, e.money, e.actions, e.stress, e.rep]
			if e.actions > e.actions_max() + 3 and bad == "":
				bad = "раунд %d, шаг %d: действий %d при максимуме %d" % [round_i, k, e.actions, e.actions_max()]
	add.call("случайные действия с мусором не ломают экономику", bad == "", ("%d действий без нарушений" % ops) if bad == "" else bad)

	# 20. обезьяна-жадина: без единой подработки ищет плюс — займы, возвраты, продления, сдача недели
	rng.seed = 77
	var best_gain := -999999
	for round_i in 30:
		e = _game(500 + round_i)
		var start_w := _wealth(e)
		for week in 3:
			for k in 60:
				if e.ending != "":
					break
				var lo2: int = int(e.loans[rng.randi() % e.loans.size()]["id"])
				match rng.randi() % 8:
					0, 1:
						if not e.offers.is_empty():
							e.take(int(e.offers[rng.randi() % e.offers.size()]["id"]))
					2: e.pay(lo2, rng.randi_range(100, 60000))
					3: e.extend(lo2)
					4: e.refinance([lo2], String(MLData.LENDER_ORDER[rng.randi() % 4]))
					5: e.pay_min(lo2)
					6: e.next_phase()
					7:
						if not e.offers.is_empty():
							e.call_operator(int(e.offers[0]["id"]))
			if e.ending == "":
				e.surrender()
			best_gain = maxi(best_gain, _wealth(e) - start_w)
			e.new_game(rng.randi())
			e.phase = "day"
	add.call("без работы в плюс не выйти", best_gain <= 3500, "лучший прирост состояния за неделю без единой подработки: %+d ₽ (разовые события недели — до 3 000 ₽)" % best_gain)
	return out
