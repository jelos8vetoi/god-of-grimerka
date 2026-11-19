## Симуляции стратегий «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» на чистой экономике (без сцены): одна неделя за доли секунды.
## Стратегии: grinder — только подработки, платит вовремя; borrower — берёт всё и перекрывает займами;
## balanced — подработки и займ только против просрочки; lazy — ничего не делает; talker — подработки похуже,
## зато хорошо договаривается; abuser — пытается заработать на займах (взял — погасил — взял), рефинансирует по кругу.
## microloanscheck проверяет: никто не уходит в бесконечный плюс, честная игра проходима, лень — проигрыш.
class_name MLSim

static func run(strategy: String, seed_v: int, skill := 0.7) -> Dictionary:
	var e := MLEconomy.new()
	e.new_game(seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7 + 3
	var guard := 0
	while e.ending == "" and guard < 200:
		guard += 1
		match e.phase:
			"morning":
				if e.event_today != "" and not e.event_done:
					var E: Dictionary = MLData.EVENTS[e.event_today]
					for c in (E["choices"] as Array).size():
						var r := e.resolve_event(c if strategy != "lazy" else (E["choices"] as Array).size() - 1)
						if not r.has("fail"):
							if r.has("talk"):
								_talk(e, strategy, rng, skill)
							break
				e.next_phase()
			"day":
				_day(e, strategy, rng, skill)
				e.next_phase()
			"evening":
				_evening(e, strategy, rng, skill)
				e.next_phase()
	return {"ending": e.ending, "money": e.money, "debt": e.total_debt(), "taken": int(e.stats["taken"]), "net": e.money - e.total_debt(), "day": e.day,
		"interest": int(e.stats["interest"]), "fines": int(e.stats["fines"])}

static func _job_q(skill: float, rng: RandomNumberGenerator, e: MLEconomy) -> float:
	return clampf(skill + rng.randf_range(-0.15, 0.1) - (0.15 if e.stress >= 70 else 0.0), 0.0, 1.0)

static func _best_job(e: MLEconomy) -> String:
	if e.job_open("sound"):
		return "sound"
	if e.job_open("repair"):
		return "repair"
	return "podezd" if e.job_open("podezd") else "repair"

static func _day(e: MLEconomy, s: String, rng: RandomNumberGenerator, skill: float) -> void:
	match s:
		"lazy":
			while e.actions > 0:
				e.rest()
		"abuser":
			# взять займ, сразу погасить, ещё займ… и подработки, чтобы было чем гасить проценты
			for O in e.offers.duplicate():
				if e.actions > 1:
					e.take(int(O["id"]))
			for L in e.active():
				e.pay(int(L["id"]), int(ceil(L["balance"])))
			while e.actions > 0:
				e.job_done(_best_job(e), _job_q(skill, rng, e))
		"juggler":
			# король займов: каждый день берёт самый дешёвый безопасный займ и гасит всё раньше срока, без просрочек
			var safe := e.offers.filter(func(O): return O["clause"] == "" or not (MLData.CLAUSES[O["clause"]][1] as Dictionary).has("early"))
			safe.sort_custom(func(a, b): return float(a["rate"]) < float(b["rate"]))
			if not safe.is_empty() and e.actions > 1 and e.day <= 5:
				var O: Dictionary = safe[0]
				if not bool(O["known"]):
					e.study(int(O["id"]))
				if String(O["clause"]) == "" or not (MLData.CLAUSES[O["clause"]][1] as Dictionary).has("early"):
					e.take(int(O["id"]))
			while e.actions > 0:
				if e.stress >= 72:
					e.rest()
				else:
					e.job_done(_best_job(e), _job_q(skill, rng, e))
		"borrower":
			for O in e.offers.duplicate():
				if e.actions > 0:
					e.take(int(O["id"]))
			while e.actions > 0:
				e.job_done(_best_job(e), _job_q(skill * 0.8, rng, e))
		_:
			# grinder / balanced / talker: улучшения с умом, отдых при стрессе, подработки
			if s == "balanced":
				for u in ["calc", "talk", "contacts"]:
					if e.money > 9000:
						e.buy(u)
				var due := e.active().filter(func(L): return int(L["due"]) <= e.day)
				var need := 0
				for L in due:
					need += int(ceil(L["balance"]))
				if need > e.money + 4000 and not e.offers.is_empty() and e.actions > 1:
					var best: Dictionary = e.offers[0]
					for O in e.offers:
						if float(O["rate"]) < float(best["rate"]):
							best = O
					if not bool(best["known"]) and e.actions > 2:
						e.study(int(best["id"]))
					var C: Dictionary = MLData.CLAUSES.get(String(best["clause"]), ["", {}])[1]
					if not (C.has("double_fine") or C.has("no_extend")):
						e.take(int(best["id"]))
			if s == "talker":
				for L in e.active():
					if int(L["due"]) - e.day <= 1 and e.start_call(int(L["id"])):
						_talk(e, s, rng, skill, int(L["id"]))
			while e.actions > 0:
				if e.stress >= 72:
					e.rest()
				else:
					e.job_done(_best_job(e), _job_q(skill * (0.85 if s == "talker" else 1.0), rng, e))
	_pay(e, s)

## платить: самый срочный, потом самый дорогой; не хватает — минимальный платёж или продление
static func _pay(e: MLEconomy, s: String) -> void:
	if s == "lazy":
		return
	var lst := e.active()
	lst.sort_custom(func(a, b): return int(a["due"]) < int(b["due"]) or (int(a["due"]) == int(b["due"]) and float(a["rate"]) > float(b["rate"])))
	for L in lst:
		var bal := int(ceil(L["balance"]))
		if e.money >= bal:
			e.pay(int(L["id"]), bal)
		elif int(L["due"]) <= e.day:
			if not e.extend(int(L["id"])):
				if not e.pay_min(int(L["id"])):
					e.pay(int(L["id"]), e.money)
	if s == "borrower" or s == "abuser":
		for L in e.active():
			if int(L["due"]) <= e.day:
				for lid in ["cash", "reshim", "bystro"]:
					if e.refinance([int(L["id"])], lid):
						break

static func _evening(e: MLEconomy, s: String, rng: RandomNumberGenerator, skill: float) -> void:
	for L in e.callers():
		if s == "lazy":
			e.stress = clampi(e.stress + 8, 0, 100)
			continue
		_talk(e, s, rng, skill, int(L["id"]))
	_pay(e, s)

static func _talk(e: MLEconomy, s: String, rng: RandomNumberGenerator, skill: float, id := -1) -> void:
	if id < 0:
		var cl := e.active()
		if cl.is_empty():
			return
		id = int(cl[0]["id"])
	var L := e.loan(id)
	if L.is_empty():
		return
	var good := skill + (0.2 if s == "talker" else 0.0) + (0.1 if e.upgrades.has("talk") else 0.0)
	var trust := float(e.rep) * 0.7 + 20.0 * good + rng.randf_range(-10, 10)
	var pressure := 30.0 + float(L["overdue"]) * 18.0 - 20.0 * good + rng.randf_range(-10, 10)
	e.negotiation_result(id, trust, pressure, 0, s == "talker" and rng.randf() < 0.3)

## сводка по стратегии на n прогонах
static func batch(strategy: String, n: int, skill := 0.7) -> Dictionary:
	var ends := {}
	var nets: Array = []
	var wins := 0
	var max_net := -999999
	for k in n:
		var r := run(strategy, 1000 + k, skill)
		ends[r["ending"]] = int(ends.get(r["ending"], 0)) + 1
		nets.append(int(r["net"]))
		max_net = maxi(max_net, int(r["net"]))
		if r["ending"] != "pit":
			wins += 1
	nets.sort()
	return {"strategy": strategy, "win": float(wins) / float(n), "ends": ends, "median_net": nets[n / 2], "max_net": max_net}
