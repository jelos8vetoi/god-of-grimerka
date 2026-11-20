## Экономика «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: календарь 7 дней, займы и договоры, проценты и штрафы, платежи,
## продление, рефинансирование, предпросмотр последствий (карта долгов), репутация, стресс, подработки,
## вещи, улучшения, события, концовки. Чистая логика без сцены: её же гоняют симуляции microloanscheck.
## Случайность — только своя (seed): одинаковое прохождение даёт одинаковые предложения и события.
class_name MLEconomy
extends RefCounted

signal changed
signal note(text: String, kind: String)      # уведомление телефона: kind — info / warn / money / bad

const PHASES := ["morning", "day", "evening", "night"]
const PHASE_NAMES := {"morning": "УТРО", "day": "ДЕНЬ", "evening": "ВЕЧЕР", "night": "НОЧЬ"}

var day := 1
var phase := "morning"
var money := 0
var actions := 0
var stress := 20
var rep := 40
var loans: Array = []           # {id, lender, balance, taken, due, rate, fine, clause, known, status, overdue, extended, negotiated, promise}
var offers: Array = []          # {id, lender, amount, rate, term, clause, known}
var inventory: Array = []       # номера вещей из MLData.JUNK
var upgrades := {}
var flags := {}
var lender_flags := {}          # контора → {error: true}
var stats := {"taken": 0, "closed": 0, "talk_closed": 0, "talks_won": 0, "jobs": 0, "on_time": 0, "broken": 0, "fines": 0, "interest": 0, "earned": 0}
var history: Array = []         # история для экрана: [день, текст]
var event_today := ""
var event_done := false
var warned := {}                # событие → день, когда случится
var ending := ""
var seed_v := 1
var rng := RandomNumberGenerator.new()
var next_id := 1
var career: MLCareer             # долгий слой прогрессии (ml_career.gd); null — симуляции недели без карьеры
var week_closed := false
# Заказы подработок. У каждого прохождения — свой номер: действие списывается, когда заказ взят (job_begin),
# оплата — ровно один раз, по этому номеру (job_finish). Незавершённый заказ хранится в сохранении: вышел из игры
# посреди работы — заказ брошен, действие потрачено, денег нет. Повторный сигнал или чужой номер ничего не платят.
var job_seq := 0
var job_pending := {}           # {id, jid, tier, day} — взятый и ещё не сданный заказ
var jobs_paid: Array = []       # номера уже оплаченных заказов (последние 40)
var week_report: Array = []     # что случилось при закрытии недели: изъятия, хвост долга — для экрана концовки

const TAIL_K := 0.6             # какая доля неоплаченного долга переходит на следующую неделю
const TAIL_LENDER := "srochno"  # кто её взыскивает
const JUNK_PICKS_MAX := 40      # больше решений за один разбор хлама не бывает

# ---------------- новая игра ----------------
func new_game(s: int) -> void:
	seed_v = s
	rng.seed = s
	day = 1
	week_closed = false
	job_pending = {}
	week_report = []
	money = career.start_money(MLData.START_MONEY) if career != null else MLData.START_MONEY
	stress = 20
	rep = 40
	loans = []
	offers = []
	inventory = []
	upgrades = {}
	flags = {}
	lender_flags = {}
	history = []
	warned = {}
	ending = ""
	next_id = 1
	for k in stats:
		stats[k] = 0
	var k := career.week_debt_k() if career != null else 1.0       # каждая следующая неделя — долги больше
	for L in MLData.START_LOANS:
		var lid := String(L["lender"])
		_add_loan(lid, int(round(float(L["principal"]) * k / 500.0)) * 500, int(L["due"]), "", true)
	# хвост прошлой недели: неоплаченный долг не исчезает — его часть приходит новым займом с коротким сроком
	if career != null and int(career.d.get("carry_debt", 0)) > 0:
		var tail := _add_loan(TAIL_LENDER, int(career.d["carry_debt"]), 3, "", true)
		tail["tail"] = true
		career.d["carry_debt"] = 0
		say("ХВОСТ ПРОШЛОЙ НЕДЕЛИ: %d ₽ у %s, срок — день 3" % [int(tail["balance"]), MLData.LENDERS[TAIL_LENDER]["short"]], "bad")
	stats["taken"] = 0
	_start_day()

func _add_loan(lid: String, amount: int, due: int, clause: String, known: bool) -> Dictionary:
	var D: Dictionary = MLData.LENDERS[lid]
	var L := {"id": next_id, "lender": lid, "balance": float(amount), "principal": amount, "taken": day, "due": due, "rate": float(D["rate"]),
		"fine": float(D["fine"]), "clause": clause, "known": known, "status": "active", "overdue": 0, "extended": 0, "negotiated": false, "promise": 0}
	next_id += 1
	loans.append(L)
	return L

func say(text: String, kind := "info") -> void:
	history.append([day, text])
	if history.size() > 120:
		history = history.slice(-100)
	note.emit(text, kind)

# ---------------- день ----------------
func actions_max() -> int:
	return MLData.ACTIONS + (1 if upgrades.has("slot") else 0) - (1 if stress >= 80 else 0) + (int(career.v("actions")) if career != null else 0)

## множитель карьеры по ключу (без карьеры — 0)
func cv(key: String) -> float:
	return career.v(key) if career != null else 0.0

## опыт карьеры и новые вехи: уровни и награды — уведомлениями
func xp(n: int, why := "") -> void:
	if career == null:
		return
	var ups := career.add_xp(n)
	if ups > 0:
		say("НОВЫЙ УРОВЕНЬ ПАХАНА: %d · очков навыков: %d" % [int(career.d["level"]), int(career.d["points"])], "level")
	for m in career.check_milestones():
		money += int(m["money"])
		say("ВЕХА: %s%s" % [m["name"], (" · +%d ₽" % int(m["money"])) if int(m["money"]) > 0 else ""], "milestone")

## неделя кончилась: копилка и следующая неделя карьеры (один раз)
## Неделя закрыта. Долг не обнуляется: при «яме» коллекторы сначала забирают наличные, потом имущество бизнесов
## (за полцены), а TAIL_K от остатка переходит на следующую неделю отдельным займом. Так занятые деньги нельзя
## превратить в постоянное имущество, просто бросив неделю.
func _end_week() -> void:
	if career == null or week_closed or ending == "":
		return
	week_closed = true
	week_report = []
	var unpaid := total_debt()
	if unpaid > 0:
		var cash := mini(money, unpaid)
		if cash > 0:
			money -= cash
			unpaid -= cash
			week_report.append("Коллекторы забрали наличные: %d ₽" % cash)
		if unpaid > 0:
			var sz := career.seize(unpaid)
			if int(sz["got"]) > 0:
				unpaid -= int(sz["got"])
				for line in sz["lines"]:
					week_report.append(String(line))
		if unpaid > 0:
			var base_next := 45000.0 * (1.0 + MLCareer.WEEK_DEBT_K * float(int(career.d["week"])))
			var tail := int(minf(float(unpaid) * TAIL_K, base_next) / 100.0) * 100
			career.d["carry_debt"] = tail
			if tail > 0:
				week_report.append("Хвост долга на следующую неделю: %d ₽" % tail)
	var put := career.end_week(money, ending)
	if put > 0:
		say("В копилку на следующую неделю: %d ₽" % put, "money")
		week_report.append("В копилку: %d ₽" % put)

## бросить неделю (пауза → «сдаться», новая игра поверх идущей недели): это «яма» со всеми последствиями
func surrender() -> void:
	if ending != "":
		return
	job_abandon()
	ending = "pit"
	say("Пахан бросил неделю. Долги никуда не делись.", "bad")
	_end_week()
	changed.emit()

func _start_day() -> void:
	phase = "morning"
	actions = actions_max()
	event_done = false
	_make_offers()
	_pick_event()
	var due_soon := loans.filter(func(L): return L["status"] != "closed" and int(L["due"]) - day <= 1)
	if not due_soon.is_empty():
		say("Сегодня-завтра платежи: " + ", ".join(due_soon.map(func(L): return "%s %d ₽" % [MLData.LENDERS[L["lender"]]["short"], int(ceil(L["balance"]))])), "warn")
	changed.emit()

func next_phase() -> void:
	match phase:
		"morning":
			phase = "day"
		"day":
			phase = "evening"
		"evening":
			phase = "night"
			_night()
			return
	changed.emit()

## ночь: проценты, штрафы, просрочки, ночные звонки, сон; потом новый день или конец
func _night() -> void:
	for L in loans:
		if L["status"] == "closed":
			continue
		var C: Dictionary = MLData.CLAUSES.get(String(L["clause"]), ["", {}])[1]
		var rate: float = (float(L["rate"]) + (float(C.get("rate_jump", 0.0)) if day - int(L["taken"]) >= 2 else 0.0)) * maxf(0.4, 1.0 + cv("rate"))
		var add: float = float(L["balance"]) * rate
		L["balance"] = float(L["balance"]) + add
		stats["interest"] = int(stats["interest"]) + int(add)
		if day >= int(L["due"]):
			var fine: float = float(L["balance"]) * float(L["fine"]) * float(C.get("fine_x", 1.0)) * maxf(0.3, 1.0 + cv("fine"))
			if lender_flags.get(L["lender"], {}).has("waive"):
				fine *= 0.5
			L["balance"] = float(L["balance"]) + fine
			stats["fines"] = int(stats["fines"]) + int(fine)
			L["status"] = "overdue"
			L["overdue"] = int(L["overdue"]) + 1
			rep = clampi(rep - 4, 0, 100)
			stress = clampi(stress + 6, 0, 100)
			say("%s: просрочка, штраф %d ₽" % [MLData.LENDERS[L["lender"]]["short"], int(fine)], "bad")
		if C.has("night_stress"):
			stress = clampi(stress + int(C["night_stress"]), 0, 100)
		# невыполненное обещание из переговоров
		if int(L["promise"]) > 0 and day >= int(L.get("promise_day", 99)):
			stats["broken"] = int(stats["broken"]) + 1
			rep = clampi(rep - 8, 0, 100)
			L["promise"] = 0
			say("Обещание %s не выполнено — репутация падает" % MLData.LENDERS[L["lender"]]["short"], "bad")
	if flags.has("friend_loan") and day >= MLData.DAYS:
		pass
	stress = clampi(stress - 15, 0, 100)            # сон
	# бизнесы: вечерняя выручка минус зарплаты и расходы, износ оборудования
	if career != null:
		var r := career.biz_day(total_overdue() == 0)
		if int(r["inc"]) > 0 or int(r["cost"]) > 0:
			money += int(r["net"])
			stats["earned"] = int(stats["earned"]) + maxi(0, int(r["net"]))
			career.bump("earned", maxi(0, int(r["net"])))
			say("БИЗНЕС ЗА ДЕНЬ: %+d ₽ (выручка %d, расходы %d)" % [int(r["net"]), int(r["inc"]), int(r["cost"])], "money" if int(r["net"]) >= 0 else "bad")
			xp(4 * career.biz_count())
		if cv("rep_day") > 0.0:
			rep = clampi(rep + int(cv("rep_day")), 0, 100)
	if total_overdue() > MLData.COLLAPSE_DEBT * (career.week_debt_k() if career != null else 1.0):
		ending = "pit"
		_end_week()
		changed.emit()
		return
	if day >= MLData.DAYS:
		ending = compute_ending()
		_end_week()
		changed.emit()
		return
	day += 1
	_start_day()

# ---------------- деньги и долги ----------------
func active() -> Array:
	return loans.filter(func(L): return L["status"] != "closed")

func total_debt() -> int:
	var s := 0.0
	for L in active():
		s += float(L["balance"])
	return int(ceil(s))

func total_overdue() -> int:
	var s := 0.0
	for L in active():
		if L["status"] == "overdue":
			s += float(L["balance"])
	return int(ceil(s))

func loan(id: int) -> Dictionary:
	for L in loans:
		if int(L["id"]) == id:
			return L
	return {}

## Предпросмотр: что будет с деньгами, долгом и графиком, если сделать action (до подтверждения).
## kind: pay / min / extend / refinance / take / barter. Без калькулятора цифры приблизительные (≈).
func preview(kind: String, a: Dictionary) -> Dictionary:
	var out := {"ok": true, "why": "", "money": money, "debt": total_debt(), "lines": []}
	match kind:
		"pay":
			var L := loan(int(a["id"]))
			var amt := mini(int(a["amount"]), money)
			var fee := _early_fee(L, amt)
			var paid := minf(float(amt - fee), float(L["balance"]))
			out["money"] = money - amt
			out["debt"] = total_debt() - int(paid)
			out["lines"] = ["Платёж %d ₽ → долг %s станет %d ₽" % [amt, MLData.LENDERS[L["lender"]]["short"], int(ceil(float(L["balance"]) - paid))]]
			if fee > 0:
				out["lines"].append("Комиссия за досрочное погашение: %d ₽ (мелкий шрифт)" % fee)
			if amt <= 0:
				out["ok"] = false
				out["why"] = "нет денег"
		"min":
			var L2 := loan(int(a["id"]))
			var m := min_payment(L2)
			out["money"] = money - m
			out["lines"] = ["Минимальный платёж %d ₽ → срок +1 день, долг почти не уменьшится" % m]
			out["ok"] = money >= m and int(L2.get("min_used", 0)) < 2
			out["why"] = "нет денег" if money < m else "минимальный платёж уже дважды"
		"extend":
			var L3 := loan(int(a["id"]))
			var e := extend_info(L3)
			out["ok"] = bool(e["ok"])
			out["why"] = String(e["why"])
			out["money"] = money - int(e["fee"])
			out["lines"] = ["Продление на %d дн. за %d ₽ — сам долг не уменьшается" % [int(e["days"]), int(e["fee"])]]
		"refinance":
			var r := refinance_info(a["ids"], String(a["lender"]))
			out["ok"] = bool(r["ok"])
			out["why"] = String(r["why"])
			out["debt"] = total_debt() - int(r["closed"]) + int(r["new"])
			out["lines"] = ["Новый займ %s %d ₽ закрывает %d долг(а) на %d ₽" % [MLData.LENDERS[String(a["lender"])]["short"], int(r["new"]), (a["ids"] as Array).size(), int(r["closed"])],
				"Новый срок: день %d · ставка %.1f%% в день · к сроку вернуть ≈ %d ₽" % [int(r["due"]), float(r["rate"]) * 100.0, int(r["at_due"])]]
		"take":
			var O: Dictionary = a["offer"]
			var C: Dictionary = MLData.CLAUSES.get(String(O["clause"]), ["", {}])[1] if bool(O["known"]) else {}
			var got := int(float(O["amount"]) * (1.0 - float(C.get("cut", 0.0))))
			out["money"] = money + got
			out["debt"] = total_debt() + int(O["amount"])
			out["lines"] = ["На руки %d ₽, вернуть к дню %d ≈ %d ₽" % [got, day + int(O["term"]), int(float(O["amount"]) * pow(1.0 + float(O["rate"]), float(O["term"])))]]
			if not bool(O["known"]) and String(O["clause"]) != "":
				out["lines"].append("В договоре есть мелкий шрифт — ты его не читал")
	if not upgrades.has("calc"):
		out["approx"] = true
	return out

func _early_fee(L: Dictionary, amt: int) -> int:
	var C: Dictionary = MLData.CLAUSES.get(String(L["clause"]), ["", {}])[1]
	if C.has("early") and day < int(L["due"]):
		return int(float(amt) * float(C["early"]))
	return 0

## займ вернули в тот же день, что взяли: контора берёт проценты за сутки (минимальный срок), а репутации,
## опыта и «закрытого долга» за такой возврат нет — иначе «взял и сразу отдал» качало бы всё бесплатно
func same_day(L: Dictionary) -> bool:
	return int(L.get("fresh", -1)) == day

func _day_fee(L: Dictionary) -> void:
	if same_day(L) and not bool(L.get("day_fee", false)):
		L["day_fee"] = true
		var add: float = float(L["balance"]) * float(L["rate"])
		L["balance"] = float(L["balance"]) + add
		stats["interest"] = int(stats["interest"]) + int(add)
		say("%s: возврат в день выдачи — проценты за сутки %d ₽" % [MLData.LENDERS[L["lender"]]["short"], int(ceil(add))], "warn")

func pay(id: int, amount: int) -> bool:
	var L := loan(id)
	if L.is_empty() or L["status"] == "closed":
		return false
	amount = mini(amount, money)
	if amount <= 0:
		return false
	_day_fee(L)
	# комиссия за досрочное — только с той суммы, что правда ушла в долг (а не со всей протянутой)
	var C0: Dictionary = MLData.CLAUSES.get(String(L["clause"]), ["", {}])[1]
	var early: float = float(C0.get("early", 0.0)) if day < int(L["due"]) else 0.0
	amount = mini(amount, int(ceil(float(L["balance"]) / maxf(0.05, 1.0 - early))))
	var fee := int(float(amount) * early)
	var part := minf(float(amount - fee), float(L["balance"]))
	var spent := mini(int(ceil(part)) + fee, money)
	money -= spent
	L["balance"] = float(L["balance"]) - part
	if int(L["promise"]) > 0:
		L["promise"] = maxi(0, int(L["promise"]) - spent)
	if float(L["balance"]) <= 0.5:
		_close(L)
	else:
		say("Внесено %d ₽ в %s" % [spent, MLData.LENDERS[L["lender"]]["short"]], "money")
	changed.emit()
	return true

func _close(L: Dictionary) -> void:
	L["balance"] = 0.0
	L["status"] = "closed"
	if same_day(L):
		say("%s: займ возвращён в день выдачи — в зачёт не идёт" % MLData.LENDERS[L["lender"]]["short"], "info")
		return
	stats["closed"] = int(stats["closed"]) + 1
	if day <= int(L["due"]):
		stats["on_time"] = int(stats["on_time"]) + 1
		rep = clampi(rep + 6, 0, 100)
	else:
		rep = clampi(rep + 2, 0, 100)
	if bool(L["negotiated"]):
		stats["talk_closed"] = int(stats["talk_closed"]) + 1
	stress = clampi(stress - 10, 0, 100)
	say("ДОЛГ %s ЗАКРЫТ" % MLData.LENDERS[L["lender"]]["name"], "money")
	if career != null:
		career.bump("closed")
		xp(35)

func min_payment(L: Dictionary) -> int:
	return int(ceil(float(L["balance"]) * 0.15))

## минимальный платёж: долг почти тот же, но срок +1 день (не больше двух раз на займ)
func pay_min(id: int) -> bool:
	var L := loan(id)
	var m := min_payment(L)
	if L.is_empty() or money < m or int(L.get("min_used", 0)) >= 2 or L["status"] == "closed":
		return false
	money -= m
	L["balance"] = float(L["balance"]) - float(m) * 0.5       # половина идёт в проценты
	L["due"] = int(L["due"]) + 1
	L["min_used"] = int(L.get("min_used", 0)) + 1
	if L["status"] == "overdue":
		L["status"] = "active"
	say("Минимальный платёж %d ₽ — %s ждёт до дня %d" % [m, MLData.LENDERS[L["lender"]]["short"], int(L["due"])], "info")
	changed.emit()
	return true

func extend_info(L: Dictionary) -> Dictionary:
	var D: Dictionary = MLData.LENDERS[L["lender"]]
	var C: Dictionary = MLData.CLAUSES.get(String(L["clause"]), ["", {}])[1]
	var fee := int(ceil(float(L["balance"]) * float(D["extend"][1]) * maxf(0.3, 1.0 + cv("fee"))))
	var r := {"ok": true, "why": "", "fee": fee, "days": int(D["extend"][0]) + int(cv("extend"))}
	if C.has("no_extend"):
		r["ok"] = false
		r["why"] = "в договоре: продление не предусмотрено"
	elif int(L["extended"]) >= 2:
		r["ok"] = false
		r["why"] = "уже продлевали дважды"
	elif money < fee:
		r["ok"] = false
		r["why"] = "нужно %d ₽ на комиссию" % fee
	return r

func extend(id: int) -> bool:
	var L := loan(id)
	if L.is_empty() or L["status"] == "closed":
		return false
	var e := extend_info(L)
	if not bool(e["ok"]):
		return false
	money -= int(e["fee"])
	L["due"] = maxi(int(L["due"]), day) + int(e["days"])
	L["extended"] = int(L["extended"]) + 1
	L["status"] = "active"
	stats["fines"] = int(stats["fines"]) + int(e["fee"])
	say("%s продлён до дня %d за %d ₽" % [MLData.LENDERS[L["lender"]]["short"], int(L["due"]), int(e["fee"])], "info")
	changed.emit()
	return true

## рефинансирование: новый займ у lender закрывает выбранные долги (объединение нескольких — тоже это)
func refinance_info(ids: Array, lid: String) -> Dictionary:
	var D: Dictionary = MLData.LENDERS[lid]
	var uniq: Array = []
	for id0 in ids:
		if not uniq.has(int(id0)):
			uniq.append(int(id0))
	ids = uniq
	var sum := 0.0
	for id in ids:
		var L := loan(int(id))
		if not L.is_empty() and L["status"] != "closed":
			sum += float(L["balance"])
	var limit := int(float(D["max"]) * (1.0 + float(rep) / 100.0))
	var r := {"ok": true, "why": "", "closed": int(ceil(sum)), "new": int(ceil(sum * 1.05)), "rate": float(D["rate"]), "due": day + int(D["term"]), "at_due": 0}
	r["at_due"] = int(float(r["new"]) * pow(1.0 + float(D["rate"]), float(D["term"])))
	if ids.is_empty():
		r["ok"] = false
		r["why"] = "выбери долги"
	elif sum <= 0.5:
		r["ok"] = false
		r["why"] = "эти долги уже закрыты"
	elif rep < int(D["rep_need"]):
		r["ok"] = false
		r["why"] = "%s не дают с такой репутацией (нужно %d)" % [D["short"], int(D["rep_need"])]
	elif int(r["new"]) > limit:
		r["ok"] = false
		r["why"] = "лимит %s — %d ₽" % [D["short"], limit]
	elif ids.any(func(id): return String(loan(int(id)).get("lender", "")) == lid):
		r["ok"] = false
		r["why"] = "контора не перекредитует сама себя"
	return r

func refinance(ids: Array, lid: String) -> bool:
	var r := refinance_info(ids, lid)
	if not bool(r["ok"]):
		return false
	for id in ids:
		var L := loan(int(id))
		if L.is_empty() or L["status"] == "closed":
			continue
		L["balance"] = 0.0
		L["status"] = "closed"
		L["refinanced"] = true
	var N := _add_loan(lid, int(r["new"]), int(r["due"]), "", true)
	N["from"] = ids.duplicate()
	stats["taken"] = int(stats["taken"]) + 1
	rep = clampi(rep - 2, 0, 100)
	say("Перекредитовался: %s %d ₽ до дня %d" % [MLData.LENDERS[lid]["short"], int(r["new"]), int(r["due"])], "warn")
	changed.emit()
	return true

# ---------------- предложения и договоры ----------------
func _make_offers() -> void:
	offers = []
	for lid in MLData.LENDER_ORDER:
		var D: Dictionary = MLData.LENDERS[lid]
		if rep < int(D["rep_need"]) + int(cv("rep_need")):
			continue
		var amount := int(lerpf(float(D["min"]), float(D["max"]), clampf(float(rep) / 80.0, 0.0, 1.0)) / 500.0) * 500
		var clause := ""
		if rng.randf() < 0.55:
			clause = String(MLData.CLAUSES.keys()[rng.randi() % MLData.CLAUSES.size()])
		offers.append({"id": next_id, "lender": lid, "amount": amount, "rate": float(D["rate"]), "term": int(D["term"]), "clause": clause, "known": upgrades.has("scanner") or clause == "" or cv("read") > 0.0})
		next_id += 1

func offer(id: int) -> Dictionary:
	for O in offers:
		if int(O["id"]) == id:
			return O
	return {}

## изучить договор: одно действие — и мелкий шрифт виден
func study(id: int) -> bool:
	var O := offer(id)
	if O.is_empty() or actions <= 0:
		return false
	actions -= 1
	O["known"] = true
	say("Договор %s прочитан: %s" % [MLData.LENDERS[O["lender"]]["short"], _clause_text(O)], "info")
	changed.emit()
	return true

## позвонить оператору: без действия, но стресс
func call_operator(id: int) -> bool:
	var O := offer(id)
	if O.is_empty():
		return false
	O["known"] = true
	stress = clampi(stress + 6, 0, 100)
	say("Оператор нехотя признался: %s" % _clause_text(O), "info")
	changed.emit()
	return true

func _clause_text(O: Dictionary) -> String:
	return "мелкого шрифта нет" if String(O["clause"]) == "" else String(MLData.CLAUSES[O["clause"]][0])

func take(id: int) -> bool:
	var O := offer(id)
	if O.is_empty() or actions <= 0:
		return false
	actions -= 1
	var C: Dictionary = MLData.CLAUSES.get(String(O["clause"]), ["", {}])[1]
	var got := int(float(O["amount"]) * (1.0 - float(C.get("cut", 0.0))))
	money += got
	var NL := _add_loan(String(O["lender"]), int(O["amount"]), day + int(O["term"]), String(O["clause"]), bool(O["known"]))
	NL["fresh"] = day                                  # взят сегодня (см. same_day)
	offers.erase(O)
	stats["taken"] = int(stats["taken"]) + 1
	stress = clampi(stress + 3, 0, 100)
	say("Взят займ %s: на руки %d ₽" % [MLData.LENDERS[O["lender"]]["short"], got], "warn")
	changed.emit()
	return true

# ---------------- работа, отдых, вещи, улучшения ----------------
func job_open(jid: String) -> bool:
	if jid == "podezd" and flags.has("no_vacuum") and day <= int(flags["no_vacuum"]):
		return false
	if jid == "sound":
		return rep >= int(MLData.JOBS["sound"]["rep"]) or upgrades.has("contacts")
	return true

## взять заказ: списывает действие и выдаёт номер прохождения (0 — нельзя: нет действий, закрыто, уже есть заказ)
func job_begin(jid: String, tier := 1) -> int:
	if actions <= 0 or not MLData.JOBS.has(jid) or not job_open(jid) or not job_pending.is_empty() or ending != "":
		return 0
	actions -= 1
	job_seq += 1
	job_pending = {"id": job_seq, "jid": jid, "tier": clampi(tier, 1, 5), "day": day}
	changed.emit()
	return job_seq

## сдать заказ: оплата по номеру — один раз. picks — решения по вещам (только для разбора хлама).
func job_finish(ticket: int, score: float, picks: Array = []) -> int:
	if ticket <= 0 or job_pending.is_empty() or int(job_pending["id"]) != ticket or jobs_paid.has(ticket):
		return 0
	var jid := String(job_pending["jid"])
	var tier := int(job_pending["tier"])
	job_pending = {}
	jobs_paid.append(ticket)
	if jobs_paid.size() > 40:
		jobs_paid = jobs_paid.slice(-40)
	if is_nan(score):
		score = 0.0
	return _pay_junk(picks) if jid == "junk" else _pay_job(jid, score, tier)

## заказ брошен (вышел из игры посреди работы, сдался): действие уже потрачено, оплаты нет
func job_abandon() -> void:
	if job_pending.is_empty():
		return
	var J: Dictionary = MLData.JOBS[String(job_pending["jid"])]
	jobs_paid.append(int(job_pending["id"]))
	job_pending = {}
	stress = clampi(stress + 3, 0, 100)
	rep = clampi(rep - 1, 0, 100)
	say("Заказ «%s» брошен: действие потрачено, оплаты нет" % J["name"], "bad")
	changed.emit()

## оплата подработки одним вызовом (симуляции и проверки): взять и сразу сдать
func job_done(jid: String, score: float, tier := 1) -> int:
	var ticket := job_begin(jid, tier)
	return job_finish(ticket, score) if ticket > 0 else 0

func _pay_job(jid: String, score: float, tier: int) -> int:
	var J: Dictionary = MLData.JOBS[jid]
	score = clampf(score, 0.0, 1.0)
	var mult := (career.pay_mult(jid) if career != null else 1.0) * (1.0 + (cv("perfect") if score >= 0.95 else 0.0)) * (1.0 + 0.25 * float(clampi(tier, 1, 5) - 1))
	var pay_v := int(lerpf(float(J["min"]), float(J["base"]), score) * (1.25 if upgrades.has("contacts") else 1.0) * mult / 50.0) * 50
	if score < 0.05:
		pay_v = 0                                          # зашёл и вышел, ничего не сделав — платить не за что
	money += pay_v
	stats["earned"] = int(stats["earned"]) + pay_v
	stats["jobs"] = int(stats["jobs"]) + 1
	stress = clampi(stress + int(float(J["stress"]) * (0.5 if upgrades.has("scooter") else 1.0) * maxf(0.3, 1.0 + cv("jstress"))) - (6 if score > 0.75 else 0), 0, 100)
	if score > 0.7:
		rep = clampi(rep + 2, 0, 100)
	say("%s: +%d ₽" % [J["name"], pay_v], "money")
	if career != null:
		career.bump("jobs")
		career.bump("earned", pay_v)
		if score >= 0.95:
			career.bump("perfect")
		career.trust_add({"repair": "mechanic", "deliv": "courier", "sound": "dj", "podezd": "owner", "junk": "owner"}.get(jid, ""), 4.0)
		xp(career.job_xp(score))
	changed.emit()
	return pay_v

## хлам одним вызовом (симуляции и проверки)
func junk_done(picks: Array) -> int:
	var ticket := job_begin("junk", 1)
	return job_finish(ticket, 1.0, picks) if ticket > 0 else 0

## хлам: решения по вещам → деньги и инвентарь. Список приходит от самой мини-игры (в ней вещи могут повторяться,
## редкая продаётся дважды); здесь — только защита от мусора: неверные номера и раздутый список отбрасываются.
func _pay_junk(picks: Array) -> int:
	var got := 0
	if picks.size() > JUNK_PICKS_MAX:
		picks = picks.slice(0, JUNK_PICKS_MAX)
	for p in picks:
		if not (p is Array) or (p as Array).size() < 2 or int(p[0]) < 0 or int(p[0]) >= MLData.JUNK.size():
			continue
		var it: Array = MLData.JUNK[int(p[0])]
		match String(p[1]):
			"sell":
				got += int(it[2])
			"scrap":
				got += int(it[4])
			"keep":
				inventory.append(int(p[0]))
	got = int(float(got) * (career.pay_mult("junk") if career != null else 1.0))
	money += got
	stats["earned"] = int(stats["earned"]) + got
	stats["jobs"] = int(stats["jobs"]) + 1
	stress = clampi(stress + 4, 0, 100)
	if career != null:
		career.bump("jobs")
		career.bump("earned", got)
		xp(20 + picks.size() * 4)
	say("Разбор хлама: +%d ₽, в запасе вещей %d" % [got, inventory.size()], "money")
	changed.emit()
	return got

func sell_item(idx: int) -> bool:
	if idx < 0 or idx >= inventory.size():
		return false
	var it: Array = MLData.JUNK[int(inventory[idx])]
	money += int(it[2])
	inventory.remove_at(idx)
	say("Продано: %s за %d ₽" % [it[0], int(it[2])], "money")
	changed.emit()
	return true

## «Решим вопрос» берёт вещи в счёт долга
func barter(idx: int, id: int) -> bool:
	var L := loan(id)
	if L.is_empty() or L["lender"] != "reshim" or L["status"] == "closed" or idx < 0 or idx >= inventory.size():
		return false
	var it: Array = MLData.JUNK[int(inventory[idx])]
	if int(it[3]) <= 0:
		say("«Это мне не нужно», — сказал Гена про %s" % it[0], "bad")
		return false
	L["balance"] = maxf(0.0, float(L["balance"]) - float(it[3]))
	inventory.remove_at(idx)
	say("Гена забрал %s в счёт долга (−%d ₽)" % [it[0], int(it[3])], "money")
	if float(L["balance"]) <= 0.5:
		_close(L)
	changed.emit()
	return true

func rest() -> bool:
	if actions <= 0:
		return false
	actions -= 1
	stress = clampi(stress - 25, 0, 100)
	say("Пахан полежал, послушал iPod. Стресс меньше.", "info")
	changed.emit()
	return true

func buy(uid: String) -> bool:
	var U: Dictionary = MLData.UPGRADES[uid]
	if upgrades.has(uid) or money < int(U["cost"]):
		return false
	money -= int(U["cost"])
	upgrades[uid] = true
	if uid == "scanner":
		for O in offers:
			O["known"] = true
	say("Куплено: %s" % U["name"], "info")
	changed.emit()
	return true

# ---------------- события ----------------
func _cond(eid: String) -> bool:
	match eid:
		"phone_broke":
			return day >= 2 and not upgrades.has("phone")
		"collector_visit":
			return total_overdue() > 0
		"windfall":
			return day >= 3 and not flags.has("windfall")
		"good_offer":
			return active().any(func(L): return L["lender"] == "reshim")
		"vacuum_broke":
			return stats["jobs"] >= 3
		"zero_loan":
			return rep >= 55 and not flags.has("friend_loan")
		"business":
			return rep >= 65 and day >= 4 and money >= 8000 and not flags.has("business")
		"wrong_bill":
			return active().size() >= 2
		"sell_tech":
			return not flags.has("no_monitor")
	return true

func _pick_event() -> void:
	event_today = ""
	# сначала то, о чём предупредили
	for eid in warned.keys():
		if int(warned[eid]) <= day:
			event_today = eid
			warned.erase(eid)
			return
	if rng.randf() < 0.65:
		var opts: Array = MLData.EVENTS.keys().filter(func(k): return _cond(k) and not flags.has("ev_" + k))
		if not opts.is_empty():
			var eid := String(opts[rng.randi() % opts.size()])
			var E: Dictionary = MLData.EVENTS[eid]
			if E.has("warn"):
				# неприятное — с предупреждением: случится завтра (с новым телефоном — послезавтра)
				warned[eid] = day + (2 if upgrades.has("phone") else 1)
				say(String(E["warn"]), "warn")
			else:
				event_today = eid

## выбор в событии; talk — переговоры (их запустит ml_root)
func resolve_event(choice: int) -> Dictionary:
	if event_today == "" or event_done:
		return {}
	var E: Dictionary = MLData.EVENTS[event_today]
	var fx: Dictionary = E["choices"][clampi(choice, 0, (E["choices"] as Array).size() - 1)][1]
	flags["ev_" + event_today] = true
	event_done = true
	if fx.has("actions"):
		if actions + int(fx["actions"]) < 0:
			event_done = false
			flags.erase("ev_" + event_today)
			return {"fail": "не хватает действий"}
		actions += int(fx["actions"])
	if fx.has("money"):
		if money + int(fx["money"]) < 0:
			event_done = false
			flags.erase("ev_" + event_today)
			return {"fail": "не хватает денег"}
		money += int(fx["money"])
	if fx.has("stress"):
		stress = clampi(stress + int(fx["stress"]), 0, 100)
	if fx.has("rep"):
		rep = clampi(rep + int(fx["rep"]), 0, 100)
	if fx.has("flag"):
		flags[String(fx["flag"])] = day + 2 if String(fx["flag"]) == "no_vacuum" else true
	if fx.has("flag_lender"):
		var lid := String(active()[0]["lender"]) if not active().is_empty() else "bystro"
		lender_flags[lid] = {"error": true}
		say("Ошибка в счёте %s — запомни для переговоров" % MLData.LENDERS[lid]["short"], "info")
	if fx.has("pay_wrong"):
		money = maxi(0, money - 2000)
	if fx.has("reshim_cut"):
		for L in active():
			if L["lender"] == "reshim":
				L["balance"] = float(L["balance"]) * (1.0 - float(fx["reshim_cut"]))
	if fx.has("friend_loan"):
		money += int(fx["friend_loan"])
		flags["friend_loan"] = true
		var F := _add_loan("reshim", int(fx["friend_loan"]), MLData.DAYS, "", true)
		F["rate"] = 0.0
		F["fine"] = 0.0
		F["friend"] = true
	if fx.has("money") and int(fx["money"]) > 0:
		stats["earned"] = int(stats["earned"]) + int(fx["money"])
	if event_today == "windfall":
		flags["windfall"] = true
	changed.emit()
	return fx

# ---------------- переговоры: итог ----------------
## результат переговоров (ml_negotiation): trust, pressure 0..100, promise — обещанная сумма
func negotiation_result(id: int, trust: float, pressure: float, promise: int, used_error: bool) -> Dictionary:
	var L := loan(id)
	if L.is_empty():
		return {}
	var r := {"won": false, "text": ""}
	var score := trust - pressure * 0.7 + (25.0 if used_error else 0.0)
	var wins := int(L.get("talk_wins", 0))
	if score >= 10.0 and wins >= 2:
		r = {"won": false, "text": "«Мы уже дважды шли вам навстречу». Больше уступок по этому займу не будет."}
		say(String(r["text"]), "bad")
		changed.emit()
		return r
	if score >= 10.0:
		L["talk_wins"] = wins + 1
	if score >= 35.0 and wins == 0:
		L["due"] = maxi(int(L["due"]), day) + 2
		var fine_cut := float(L["balance"]) * 0.08
		L["balance"] = float(L["balance"]) - fine_cut
		L["status"] = "active"
		L["negotiated"] = true
		lender_flags[L["lender"]] = {"waive": true}
		rep = clampi(rep + 4, 0, 100)
		stress = clampi(stress - 8, 0, 100)
		stats["talks_won"] = int(stats["talks_won"]) + 1
		r = {"won": true, "text": "Договорились: срок +2 дня, списали %d ₽, штрафы вдвое меньше" % int(fine_cut)}
		xp(30)
	elif score >= 10.0:
		L["due"] = maxi(int(L["due"]), day) + 1
		L["negotiated"] = true
		stats["talks_won"] = int(stats["talks_won"]) + 1
		r = {"won": true, "text": "Дали день отсрочки. Без подарков."}
	else:
		stress = clampi(stress + 12, 0, 100)
		rep = clampi(rep - 3, 0, 100)
		L["fine"] = float(L["fine"]) * 1.2
		r = {"won": false, "text": "Разговор не задался: штраф по этому займу вырос."}
	if promise > 0:
		L["promise"] = promise
		L["promise_day"] = day + 1
		r["text"] += " Обещал завтра внести %d ₽." % promise
	say(String(r["text"]), "money" if bool(r["won"]) else "bad")
	changed.emit()
	return r

## самому позвонить в контору и договориться (днём, одно действие; по одному займу — раз в день)
func can_call(id: int) -> String:
	var L := loan(id)
	if L.is_empty() or L["status"] == "closed" or L.get("friend", false):
		return "нет такого долга"
	if actions <= 0:
		return "действий нет"
	if int(L.get("called", -1)) == day:
		return "сегодня уже говорили"
	return ""

func start_call(id: int) -> bool:
	if can_call(id) != "":
		return false
	actions -= 1
	loan(id)["called"] = day
	return true

## кто сегодня вечером позвонит: сроки завтра или просрочка
func callers() -> Array:
	return active().filter(func(L): return not L.get("friend", false) and (int(L["due"]) - day <= 1 or L["status"] == "overdue"))

# ---------------- концовки ----------------
func compute_ending() -> String:
	var debt := total_debt()
	if flags.has("business") and debt <= 5000:
		return "business"
	if debt <= 0:
		if int(stats["talk_closed"]) >= 2:
			return "talks"
		if int(stats["taken"]) >= 4 and int(stats["closed"]) >= 7 and int(stats["fines"]) == 0:
			return "king"                         # жонглировал займами — и ни одной просрочки
		return "paid"
	return "pit"

## досрочный финиш: все долги закрыты — можно закончить раньше
func can_finish() -> bool:
	return total_debt() <= 0

func finish() -> void:
	ending = compute_ending()
	_end_week()
	changed.emit()

# ---------------- сохранение ----------------
func to_dict() -> Dictionary:
	return {"day": day, "phase": phase, "money": money, "actions": actions, "stress": stress, "rep": rep, "loans": loans, "offers": offers,
		"inventory": inventory, "upgrades": upgrades, "flags": flags, "lender_flags": lender_flags, "stats": stats, "log": history.slice(-40),
		"event_today": event_today, "event_done": event_done, "warned": warned, "ending": ending, "seed": seed_v, "rng_state": str(rng.state), "next_id": next_id,
		"job_seq": job_seq, "job_pending": job_pending, "jobs_paid": jobs_paid, "week_closed": week_closed, "week_report": week_report}

func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	phase = String(d.get("phase", "morning"))
	money = int(d.get("money", 0))
	actions = int(d.get("actions", 0))
	stress = int(d.get("stress", 20))
	rep = int(d.get("rep", 40))
	loans = d.get("loans", [])
	for L in loans:
		for k in ["id", "taken", "due", "overdue", "extended", "promise", "principal", "fresh", "min_used", "called", "talk_wins", "promise_day"]:
			if L.has(k):
				L[k] = int(L[k])
		if L.has("from"):
			L["from"] = (L["from"] as Array).map(func(x): return int(x))
	offers = d.get("offers", [])
	for O in offers:
		O["id"] = int(O["id"])
		O["term"] = int(O["term"])
		O["amount"] = int(O["amount"])
	inventory = (d.get("inventory", []) as Array).map(func(x): return int(x))
	upgrades = d.get("upgrades", {})
	flags = d.get("flags", {})
	for k in flags:
		if typeof(flags[k]) == TYPE_FLOAT:
			flags[k] = int(flags[k])                     # дни из JSON приходят дробными
	lender_flags = d.get("lender_flags", {})
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		stats[k] = int(st.get(k, 0))
	history = d.get("log", [])
	for h in history:
		if h is Array and (h as Array).size() > 0:
			h[0] = int(h[0])
	event_today = String(d.get("event_today", ""))
	event_done = bool(d.get("event_done", false))
	warned = d.get("warned", {})
	for k in warned:
		warned[k] = int(warned[k])
	ending = String(d.get("ending", ""))
	seed_v = int(d.get("seed", 1))
	rng.seed = seed_v
	if d.has("rng_state"):
		rng.state = int(String(d["rng_state"]))
	next_id = int(d.get("next_id", 100))
	job_seq = int(d.get("job_seq", 0))
	job_pending = d.get("job_pending", {}) if d.get("job_pending", {}) is Dictionary else {}
	for k in ["id", "tier", "day"]:
		if job_pending.has(k):
			job_pending[k] = int(job_pending[k])
	jobs_paid = (d.get("jobs_paid", []) as Array).map(func(x): return int(x))
	week_closed = bool(d.get("week_closed", ending != ""))
	week_report = d.get("week_report", [])
	for L in loans:
		if L.has("fresh"):
			L["fresh"] = int(L["fresh"])
