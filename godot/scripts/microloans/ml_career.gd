## Карьера Пахана в «Микрозаймах» — долгий слой прогрессии поверх недели долгов (MLEconomy): опыт и уровень, очки
## навыков и дерево «РАЗВИТИЕ ПАХАНА» (MLTree), снаряжение по качеству, бизнесы с сотрудниками, износом и
## автоматизацией, доверие знакомых, вехи, копилка между неделями и престиж «ЛЕГЕНДА РАЙОНА». Без сцены — эту же
## логику гоняют симуляции (MLCareer.simulate). Хранится в сохранении ключом "career" (неделя — ключом "run").
## Неделя кончилась (любая концовка) → следующая начинается с новыми долгами, больше на 30 % за каждую неделю,
## но карьера, бизнесы и часть денег (копилка) остаются.
class_name MLCareer
extends RefCounted

const WEEK_DEBT_K := 0.24          # долги новой недели: × (1 + k × (неделя − 1))
const CARRY_BASE := 0.35           # доля денег конца недели, которая уходит в копилку
const WEAR := 0.12                 # износ оборудования бизнеса за день без автоматики
var d := {}
var cache := {}                     # эффекты (сбрасывается при покупке)

func _init() -> void:
	d = fresh()

static func fresh() -> Dictionary:
	return {"xp": 0, "level": 1, "points": 1, "nodes": {}, "biz": {}, "trust": {}, "ms": {}, "week": 1, "bank": 0, "carry_debt": 0, "ms_cycle": 0,
		"stats": {"jobs": 0, "closed": 0, "earned": 0, "weeks": 0, "talks": 0, "perfect": 0},
		"legend": {"points": 0, "perks": {}, "cycles": 0}, "income": [], "cushion_week": 0, "log": []}

# ---------------- эффекты ----------------
## значение эффекта: узлы × ранг + синергии + легенда
func v(key: String) -> float:
	if cache.is_empty():
		_rebuild()
	return float(cache.get(key, 0.0))

func _rebuild() -> void:
	cache = {"_": 1.0}
	for n in MLTree.NODES:
		var r := rank(String(n["id"]))
		if r > 0:
			_add(n["eff"], r)
	var lp: Dictionary = d["legend"]["perks"]
	for id in lp:
		var L := MLTree.legend(String(id))
		if not L.is_empty():
			_add(L["eff"], int(lp[id]))
	for s in MLTree.SYNERGIES:
		if synergy_on(s):
			_add(s["eff"], 1)

func _add(eff: Dictionary, r: int) -> void:
	for k in eff:
		cache[k] = float(cache.get(k, 0.0)) + float(eff[k]) * r

func rank(id: String) -> int:
	return int((d["nodes"] as Dictionary).get(id, 0))

## множитель оплаты подработки: навыки + рост мастерства с уровнем Пахана (+4 % за уровень)
func pay_mult(jid: String) -> float:
	return (1.0 + v("pay:all") + v("pay:" + jid)) * (1.0 + 0.04 * float(int(d["level"]) - 1))

## отдача от сотрудников убывает: каждый следующий приносит на четверть меньше прошлого (предел — 4 × k)
static func staff_gain(k: float, staff: int) -> float:
	return k * (1.0 - pow(0.75, float(staff))) / 0.25

## ранг снаряжения 0..4
func eq(tool: String) -> int:
	return clampi(int(v("eq:" + tool) + v("eq:all")), 0, 4)

func synergy_on(s: Dictionary) -> bool:
	for nd in s["need"]:
		match String(nd[0]):
			"node":
				if rank(String(nd[1])) < int(nd[2]):
					return false
			"biz":
				if biz_level(String(nd[1])) < int(nd[2]):
					return false
			"eq":
				if clampi(int(_raw("eq:" + String(nd[1])) + _raw("eq:all")), 0, 4) < int(nd[2]):
					return false
	return true

## эффект только от узлов и легенды — без синергий (чтобы синергии не зависели сами от себя)
func _raw(key: String) -> float:
	var s := 0.0
	for n in MLTree.NODES:
		var r := rank(String(n["id"]))
		if r > 0 and (n["eff"] as Dictionary).has(key):
			s += float(n["eff"][key]) * r
	var lp: Dictionary = d["legend"]["perks"]
	for id in lp:
		var L := MLTree.legend(String(id))
		if not L.is_empty() and (L["eff"] as Dictionary).has(key):
			s += float(L["eff"][key]) * int(lp[id])
	return s

# ---------------- опыт ----------------
static func xp_need(level: int) -> int:
	return int(round(110.0 * pow(float(level), 1.42) / 10.0)) * 10

## опыт: возвращает, сколько уровней набрано (каждый даёт очко, каждый пятый — два)
func add_xp(n: int) -> int:
	var gain := int(round(float(n) * (1.0 + v("xp"))))
	d["xp"] = int(d["xp"]) + gain
	var ups := 0
	while int(d["xp"]) >= xp_need(int(d["level"])):
		d["xp"] = int(d["xp"]) - xp_need(int(d["level"]))
		d["level"] = int(d["level"]) + 1
		d["points"] = int(d["points"]) + (2 if int(d["level"]) % 5 == 0 else 1)
		ups += 1
	return ups

func job_xp(score: float) -> int:
	return int(18.0 + 42.0 * clampf(score, 0.0, 1.0))

# ---------------- дерево ----------------
## можно ли купить следующий ранг узла: "" — можно, иначе почему нет
func why_not(id: String) -> String:
	var n := MLTree.node(id)
	if n.is_empty():
		return "нет такого"
	var r := rank(id)
	if r >= int(n["max"]):
		return "максимум"
	if int(d["level"]) < int(n["lvl"]):
		return "нужен уровень %d" % int(n["lvl"])
	for q in n["req"]:
		if rank(String(q[0])) < int(q[1]):
			var qn := MLTree.node(String(q[0]))
			return "сначала «%s»%s" % [String(qn.get("name", q[0])), (" ранг %d" % int(q[1])) if int(q[1]) > 1 else ""]
	if int(d["points"]) < int(n["cost"]):
		return "нужно очков: %d" % int(n["cost"])
	return ""

func buy_node(id: String) -> bool:
	if why_not(id) != "":
		return false
	var n := MLTree.node(id)
	d["points"] = int(d["points"]) - int(n["cost"])
	d["nodes"][id] = rank(id) + 1
	cache.clear()
	_log("Навык: %s (ранг %d)" % [n["name"], rank(id)])
	return true

## что изменится: текст эффекта сейчас → после покупки
func effect_text(id: String, r := -1) -> String:
	var n := MLTree.node(id)
	if r < 0:
		r = rank(id)
	var parts: Array = []
	for k in n["eff"]:
		var val: float = float(n["eff"][k]) * r
		parts.append(_eff_name(String(k), val))
	return ", ".join(parts) if r > 0 else "—"

static func _eff_name(k: String, val: float) -> String:
	var pct := "%+d %%" % int(round(val * 100.0))
	if k.begins_with("pay:"):
		return "оплата %s %s" % [{"all": "всех работ", "podezd": "уборки", "repair": "ремонта", "deliv": "доставки", "sound": "звукаря", "junk": "хлама"}.get(k.substr(4), k.substr(4)), pct]
	if k.begins_with("bizinc"):
		return "доход %s %s" % ["бизнесов" if k == "bizinc" else String(MLTree.BUSINESSES.get(k.substr(7), {}).get("name", k)), pct]
	if k.begins_with("biz:"):
		return "открыт бизнес «%s»" % String(MLTree.BUSINESSES[k.substr(4)]["name"])
	if k.begins_with("eq:"):
		return "снаряжение +%d ранг" % int(val)
	if k.begins_with("npc:"):
		return "знакомый: %s" % String(MLTree.NPCS[k.substr(4)]["name"])
	if k.begins_with("auto:"):
		return "автоматизация"
	match k:
		"xp": return "опыт " + pct
		"rate": return "проценты " + pct
		"fine": return "штрафы " + pct
		"fee": return "комиссии " + pct
		"actions": return "+%d действие" % int(val)
		"staff": return "+%d место сотрудника" % int(val)
		"upkeep": return "расходы " + pct
		"carry": return "копилка " + pct
		"jstress": return "стресс от работы " + pct
		"trust": return "доверие " + pct
	if k.begins_with("tyaga") or k.begins_with("repair") or k.begins_with("deliv") or k.begins_with("junk") or k.begins_with("sound"):
		return "мини-игра: %s %s" % [k, pct if absf(val) < 0.99 or val < 0 else "открыто"]
	return "%s %s" % [k, pct]

# ---------------- бизнесы ----------------
func biz_open(id: String) -> bool:
	return v("biz:" + id) > 0.0 or (id == "workshop" and v("biz_start") > 0.0)

func biz_level(id: String) -> int:
	return int((d["biz"] as Dictionary).get(id, {}).get("lv", 0))

func biz(id: String) -> Dictionary:
	return (d["biz"] as Dictionary).get(id, {})

func biz_slots(id: String) -> int:
	var lv := biz_level(id)
	if lv <= 0:
		return 0
	return int(MLTree.BUSINESSES[id]["slots"][lv - 1]) + int(v("staff"))

## цена следующего уровня (покупка — уровень 1); 0 — выше некуда
func biz_cost(id: String) -> int:
	var B: Dictionary = MLTree.BUSINESSES[id]
	var lv := biz_level(id)
	if lv == 0:
		return int(B["buy"])
	if lv >= 5:
		return 0
	return int(B["up"][lv - 1])

func biz_why(id: String, money: int) -> String:
	if not biz_open(id):
		return "откроется в ветке ПРЕДПРИНИМАТЕЛЬ"
	var c := biz_cost(id)
	if c <= 0:
		return "максимальный уровень"
	if money < c:
		return "нужно %d ₽" % c
	return ""

## купить или поднять уровень: возвращает цену (0 — не получилось)
func biz_up(id: String, money: int) -> int:
	if biz_why(id, money) != "":
		return 0
	var c := biz_cost(id)
	var b: Dictionary = (d["biz"] as Dictionary).get(id, {"lv": 0, "staff": 0, "cond": 1.0, "days": 0, "earned": 0})
	b["lv"] = int(b["lv"]) + 1
	b["cond"] = 1.0
	d["biz"][id] = b
	cache.clear()
	_log("%s: уровень %d" % [MLTree.BUSINESSES[id]["name"], int(b["lv"])])
	return c

func hire_why(id: String, money: int) -> String:
	if biz_level(id) <= 0:
		return "сначала купи бизнес"
	if int(biz(id).get("staff", 0)) >= biz_slots(id):
		return "мест нет — подними уровень"
	if money < int(MLTree.BUSINESSES[id]["hire"]):
		return "нужно %d ₽" % int(MLTree.BUSINESSES[id]["hire"])
	return ""

func hire(id: String, money: int) -> int:
	if hire_why(id, money) != "":
		return 0
	d["biz"][id]["staff"] = int(biz(id)["staff"]) + 1
	return int(MLTree.BUSINESSES[id]["hire"])

## первый раз на это место: опыт за найм даётся только тогда (уволил-нанял заново — опыта нет)
func hire_first(id: String) -> bool:
	var b: Dictionary = d["biz"][id]
	if int(b["staff"]) > int(b.get("staff_max", 0)):
		b["staff_max"] = int(b["staff"])
		return true
	return false

## сколько вложено в бизнес: покупка, уровни и найм
func biz_value(id: String) -> int:
	var lv := biz_level(id)
	if lv <= 0:
		return 0
	var B: Dictionary = MLTree.BUSINESSES[id]
	var v := int(B["buy"])
	for k in lv - 1:
		v += int(B["up"][k])
	return v + int(B["hire"]) * int(biz(id).get("staff", 0))

## коллекторы забирают имущество в счёт долга (конец недели в «яме»): сначала увольняют сотрудников, потом
## снимают уровни — всё уходит за полцены. Возвращает, сколько долга это покрыло, и что забрали.
func seize(amount: int) -> Dictionary:
	var got := 0
	var lines: Array = []
	var ids: Array = MLTree.BUSINESS_ORDER.duplicate()
	ids.sort_custom(func(a, b): return biz_value(String(a)) > biz_value(String(b)))
	for id0 in ids:
		var id := String(id0)
		var B: Dictionary = MLTree.BUSINESSES[id]
		while got < amount and biz_level(id) > 0:
			var b: Dictionary = d["biz"][id]
			var lv := int(b["lv"])
			if int(b.get("staff", 0)) > 0:
				b["staff"] = int(b["staff"]) - 1
				got += int(B["hire"]) / 2
				lines.append("%s: уволен сотрудник (в счёт долга %d ₽)" % [B["name"], int(B["hire"]) / 2])
			else:
				var cost := int(B["buy"]) if lv == 1 else int(B["up"][lv - 2])
				b["lv"] = lv - 1
				got += cost / 2
				lines.append("%s: %s (в счёт долга %d ₽)" % [B["name"], "бизнес отобран" if lv == 1 else "уровень %d → %d" % [lv, lv - 1], cost / 2])
				if lv == 1:
					(d["biz"] as Dictionary).erase(id)
	if not lines.is_empty():
		cache.clear()
		_log("Коллекторы забрали имущество на %d ₽" % got)
	return {"got": mini(got, amount), "lines": lines}

func fire(id: String) -> bool:
	if int(biz(id).get("staff", 0)) <= 0:
		return false
	d["biz"][id]["staff"] = int(biz(id)["staff"]) - 1
	return true

## обслуживание оборудования вручную: вернуть исправность (цена — день расходов)
func service_cost(id: String) -> int:
	var lv := biz_level(id)
	if lv <= 0:
		return 0
	return int(float(MLTree.BUSINESSES[id]["upkeep"][lv - 1]) * 1.5 * (1.0 - float(biz(id).get("cond", 1.0))) + 0.5)

func service(id: String) -> int:
	var c := service_cost(id)
	if biz_level(id) <= 0:
		return 0
	d["biz"][id]["cond"] = 1.0
	return c

## один бизнес за день: доход, расходы, чистыми
func biz_day_one(id: String, no_overdue := true) -> Dictionary:
	var lv := biz_level(id)
	if lv <= 0:
		return {"inc": 0, "cost": 0, "net": 0}
	var B: Dictionary = MLTree.BUSINESSES[id]
	var b := biz(id)
	var staff := int(b.get("staff", 0))
	var cond := float(b.get("cond", 1.0))
	var mult := 1.0 + v("bizinc") + v("bizinc:" + id) + (0.2 if v("opt") > 0.0 and no_overdue else 0.0)
	var inc := float(B["inc"][lv - 1]) * (1.0 + staff_gain(float(B["k"]), staff)) * (0.55 + 0.45 * cond) * mult
	var upk := float(B["upkeep"][lv - 1]) * maxf(0.3, 1.0 + v("upkeep") + v("upkeep:" + id))
	var cost := upk + float(B["wage"]) * staff
	return {"inc": int(inc), "cost": int(cost), "net": int(inc - cost)}

## вечер: все бизнесы приносят доход, оборудование изнашивается (если нет автоматики)
func biz_day(no_overdue := true) -> Dictionary:
	var inc := 0
	var cost := 0
	var lines: Array = []
	for id in MLTree.BUSINESS_ORDER:
		if biz_level(id) <= 0:
			continue
		var r := biz_day_one(id, no_overdue)
		inc += int(r["inc"])
		cost += int(r["cost"])
		lines.append("%s %+d ₽" % [MLTree.BUSINESSES[id]["name"], int(r["net"])])
		var b := biz(id)
		b["days"] = int(b.get("days", 0)) + 1
		b["earned"] = int(b.get("earned", 0)) + int(r["net"])
		if v("auto:service") <= 0.0:
			b["cond"] = maxf(0.2, float(b.get("cond", 1.0)) - WEAR)
	var res := {"inc": inc, "cost": cost, "net": inc - cost, "lines": lines}
	if inc > 0 or cost > 0:
		var hist: Array = d["income"]
		hist.append([int(d["week"]), inc, cost])
		if hist.size() > 70:
			d["income"] = hist.slice(-70)
	return res

func biz_count() -> int:
	var n := 0
	for id in MLTree.BUSINESS_ORDER:
		if biz_level(id) > 0:
			n += 1
	return n

func staff_total() -> int:
	var n := 0
	for id in MLTree.BUSINESS_ORDER:
		n += int(biz(id).get("staff", 0))
	return n

func auto_count() -> int:
	return int(v("auto:service") > 0.0) + int(v("auto:sell") > 0.0) + int(v("auto:manage") > 0.0)

# ---------------- доверие знакомых ----------------
func trust_add(npc: String, n: float) -> void:
	if v("npc:" + npc) <= 0.0:
		return
	var t: Dictionary = d["trust"]
	t[npc] = clampf(float(t.get(npc, 10.0)) + n * (1.0 + v("trust")), 0.0, 100.0)

func trust(npc: String) -> float:
	return float((d["trust"] as Dictionary).get(npc, 0.0))

# ---------------- вехи ----------------
func stat(k: String) -> int:
	match k:
		"biz_count": return biz_count()
		"staff": return staff_total()
		"auto": return auto_count()
		"eq_tyaga": return eq("tyaga")
	return int((d["stats"] as Dictionary).get(k, 0))

func bump(k: String, n := 1) -> void:
	d["stats"][k] = int(d["stats"].get(k, 0)) + n

## новые вехи: [веха…]; награды начисляются здесь (деньги — возвращаются, их кладёт экономика)
func check_milestones() -> Array:
	var got: Array = []
	for m in MLTree.MILESTONES:
		var id := String(m["id"])
		if (d["ms"] as Dictionary).has(id):
			continue
		if stat(String(m["stat"])) >= int(m["need"]):
			d["ms"][id] = int(d["week"])
			d["ms_cycle"] = int(d.get("ms_cycle", 0)) + 1
			d["points"] = int(d["points"]) + int(m["points"])
			add_xp(int(m["xp"]))
			got.append(m)
			_log("Веха: %s" % m["name"])
	return got

# ---------------- неделя ----------------
## долги новой недели больше — чтобы бизнес не отменял сроки
func week_debt_k() -> float:
	return 1.0 + WEEK_DEBT_K * maxf(0.2, 1.0 + v("weekdebt")) * float(int(d["week"]) - 1)

## деньги на старт недели: обычные + копилка + легенда
func start_money(base: int) -> int:
	var m := base + int(d["bank"]) + int(v("start_money"))
	d["bank"] = 0
	return m

## конец недели: часть денег — в копилку, неделя +1
func end_week(money: int, ending: String) -> int:
	var k := CARRY_BASE + v("carry") + (0.15 if ending != "pit" else -0.2)
	var put := int(maxf(0.0, float(money)) * clampf(k, 0.0, 0.9))
	d["bank"] = int(d["bank"]) + put
	d["week"] = int(d["week"]) + 1
	bump("weeks")
	d["cushion_week"] = 0
	return put

## «финансовая подушка»: раз в неделю непредвиденный расход оплачивается сам
func use_cushion() -> bool:
	if v("cushion") <= 0.0 or int(d["cushion_week"]) == int(d["week"]):
		return false
	d["cushion_week"] = int(d["week"])
	return true

# ---------------- ЛЕГЕНДА РАЙОНА ----------------
func prestige_ready() -> bool:
	return int(d["level"]) >= MLTree.LEGEND_LEVEL or stat("earned") >= MLTree.LEGEND_EARN

## сколько АВТОРИТЕТА даст престиж сейчас
func prestige_points() -> int:
	# вехи считаются только за этот цикл: старые сохраняются, но АВТОРИТЕТА второй раз не дают
	return int(floor(sqrt(float(stat("earned")) / 25000.0))) + int(d["level"]) / 3 + int(d.get("ms_cycle", 0)) / 2

## что потеряется / сохранится — для экрана подтверждения
func prestige_preview() -> Dictionary:
	return {"gain": prestige_points(), "lose": ["уровень %d и опыт" % int(d["level"]), "все навыки (%d)" % (d["nodes"] as Dictionary).size(),
		"бизнесы (%d) и сотрудники (%d)" % [biz_count(), staff_total()], "копилка %d ₽, неделя %d" % [int(d["bank"]), int(d["week"])], "текущая неделя долгов"],
		"keep": ["АВТОРИТЕТ и бонусы ЛЕГЕНДЫ", "открытые концовки и рекорды", "вехи прошлых циклов не повторяются заново"]}

func prestige() -> int:
	if not prestige_ready():
		return 0
	var gain := prestige_points()
	var lg: Dictionary = d["legend"]
	lg["points"] = int(lg["points"]) + gain
	lg["cycles"] = int(lg["cycles"]) + 1
	var keep_ms: Dictionary = d["ms"]
	d = fresh()
	d["legend"] = lg
	d["ms"] = keep_ms
	cache.clear()
	d["points"] = int(d["points"]) + int(v("start_points"))
	if v("biz_start") > 0.0:
		d["biz"]["workshop"] = {"lv": 1, "staff": 0, "cond": 1.0, "days": 0, "earned": 0}
	cache.clear()
	return gain

func legend_why(id: String) -> String:
	var L := MLTree.legend(id)
	var r := int((d["legend"]["perks"] as Dictionary).get(id, 0))
	if r >= int(L["max"]):
		return "максимум"
	if int(d["legend"]["points"]) < int(L["cost"]):
		return "нужно АВТОРИТЕТА: %d" % int(L["cost"])
	return ""

func legend_buy(id: String) -> bool:
	if legend_why(id) != "":
		return false
	var L := MLTree.legend(id)
	d["legend"]["points"] = int(d["legend"]["points"]) - int(L["cost"])
	d["legend"]["perks"][id] = int((d["legend"]["perks"] as Dictionary).get(id, 0)) + 1
	cache.clear()
	return true

func _log(s: String) -> void:
	var l: Array = d["log"]
	l.append([int(d["week"]), s])
	if l.size() > 60:
		d["log"] = l.slice(-50)

# ---------------- сохранение ----------------
func to_dict() -> Dictionary:
	return d.duplicate(true)

## безопасная загрузка: недостающие поля — по умолчанию, числа из JSON — целые
func from_dict(src: Dictionary) -> void:
	var f := fresh()
	for k in f:
		if src.has(k) and typeof(src[k]) == typeof(f[k]) or (src.has(k) and typeof(f[k]) == TYPE_INT and typeof(src[k]) == TYPE_FLOAT):
			f[k] = src[k]
	for k in ["xp", "level", "points", "week", "bank", "cushion_week", "carry_debt", "ms_cycle"]:
		f[k] = int(f[k])
	if not src.has("ms_cycle"):
		f["ms_cycle"] = (f["ms"] as Dictionary).size()      # старое сохранение: вехи этого цикла — все, что есть
	for k in f["nodes"]:
		f["nodes"][k] = int(f["nodes"][k])
	for k in f["stats"]:
		f["stats"][k] = int(f["stats"][k])
	for k in fresh()["stats"]:
		if not (f["stats"] as Dictionary).has(k):
			f["stats"][k] = 0
	for id in f["biz"]:
		var b: Dictionary = f["biz"][id]
		b["lv"] = int(b.get("lv", 0))
		b["staff"] = int(b.get("staff", 0))
		b["cond"] = float(b.get("cond", 1.0))
		b["days"] = int(b.get("days", 0))
		b["earned"] = int(b.get("earned", 0))
		b["staff_max"] = int(b.get("staff_max", b["staff"]))
	var lg: Dictionary = f["legend"]
	lg["points"] = int(lg.get("points", 0))
	lg["cycles"] = int(lg.get("cycles", 0))
	if not lg.has("perks"):
		lg["perks"] = {}
	for k in lg["perks"]:
		lg["perks"][k] = int(lg["perks"][k])
	d = f
	cache.clear()

# ---------------- симуляции баланса ----------------
## Длинный прогон карьеры без сцены: недели по 7 дней, по ACTIONS действий; стратегия решает, что качать и что делать.
## Работа даёт оплату по score (у «бота» — skill). Возвращает итоги по неделям. Не трогает сохранение.
static func simulate(strategy: String, weeks: int, seed_v: int, skill := 0.75) -> Dictionary:
	var C := MLCareer.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var plan := {
		"clean": ["w_hands", "w_suction", "w_suction", "w_suction", "w_hose", "w_turbo", "w_smart", "m_bench", "m_tyaga", "m_tyaga", "w_hands", "w_hands", "w_fix", "w_multi", "w_legs", "w_chain", "w_pro"],
		"workshop": ["b_first", "w_hands", "b_staff", "m_bench", "m_kit", "s_haggle", "s_haggle", "b_staff", "m_store", "m_kit", "m_auto", "b_manager", "t_hello", "t_mech", "t_owner"],
		"delivery": ["w_hands", "w_legs", "w_legs", "w_chain", "b_first", "b_deliv", "t_hello", "t_courier", "b_staff", "m_bench", "m_rig", "m_bag", "b_staff", "b_manager"],
		"credit": ["s_haggle", "s_haggle", "s_haggle", "s_read", "s_talk", "s_plan", "b_first", "s_fine", "s_fine", "s_cushion", "s_refi", "s_opt", "t_hello", "t_mech", "t_courier"],
		"combo": ["w_hands", "b_first", "s_haggle", "t_hello", "w_suction", "b_staff", "m_bench", "b_clean", "w_fix", "s_read", "m_tyaga", "m_tyaga", "t_courier", "b_deliv", "b_manager", "m_kit", "m_store", "m_auto", "b_store", "b_autosell", "b_studio", "b_mogul"],
		"auto": ["b_first", "b_staff", "b_clean", "m_bench", "b_staff", "b_store", "m_kit", "m_tyaga", "m_store", "b_autosell", "m_auto", "b_manager", "b_deliv", "b_studio", "b_staff"],
	}
	var biz_pref := {"clean": ["cleaning"], "workshop": ["workshop"], "delivery": ["delivery", "workshop"], "credit": ["workshop"], "combo": ["workshop", "cleaning", "delivery", "warehouse", "studio"], "auto": ["workshop", "cleaning", "warehouse", "delivery", "studio"]}
	var job_pref := {"clean": "podezd", "workshop": "repair", "delivery": "deliv", "credit": "repair", "combo": "podezd", "auto": "repair"}
	var base_pay := {"podezd": 2200, "repair": 2700, "deliv": 2500, "sound": 3900, "junk": 1600}
	var out: Array = []
	var total := 0
	for w in weeks:
		var money := C.start_money(MLData.START_MONEY)
		var debt := 45000.0 * C.week_debt_k()
		var rate := 0.021 * maxf(0.4, 1.0 + C.v("rate"))
		var earned_w := 0
		var biz_w := 0
		for day in MLData.DAYS:
			var acts := MLData.ACTIONS + int(C.v("actions"))
			for a in acts:
				var jid: String = job_pref[strategy]
				var score := clampf(skill + rng.randf_range(-0.2, 0.15) + C.v("perfect") * 0.2, 0.0, 1.0)
				var pay := int(lerpf(450.0, float(base_pay[jid]), score) * C.pay_mult(jid) * (1.0 + 0.04 * C.eq("tyaga" if jid == "podezd" else ("repair" if jid == "repair" else ("deliv" if jid == "deliv" else "sound")))))
				money += pay
				earned_w += pay
				C.bump("jobs")
				C.bump("earned", pay)
				C.add_xp(C.job_xp(score))
			var r := C.biz_day(true)
			money += int(r["net"])
			biz_w += int(r["net"])
			C.bump("earned", maxi(0, int(r["net"])))
			# износ: раз в два дня обслуживает, если нет автоматики
			for id in MLTree.BUSINESS_ORDER:
				if C.biz_level(id) > 0 and float(C.biz(id).get("cond", 1.0)) < 0.7:
					money -= C.service(id)
			debt *= 1.0 + rate
			# покупки: навыки по плану; бизнес и найм — только если долг ещё успеваешь закрыть до конца недели
			var p: Array = plan[strategy]
			for id in p:
				if C.why_not(String(id)) == "":
					C.buy_node(String(id))
			var days_left := MLData.DAYS - 1 - day
			var reserve := maxf(2000.0, debt - float(days_left) * 9000.0)
			if days_left >= 2:
				for id in biz_pref[strategy]:
					if float(money) - float(C.biz_cost(String(id))) > reserve:
						money -= C.biz_up(String(id), money)
					if float(money) - float(MLTree.BUSINESSES[String(id)]["hire"]) > reserve:
						money -= C.hire(String(id), money)
			# платит долг: с середины недели — всё сверх запаса, в последний день — всё
			if day >= 3 or days_left == 0:
				var pay_d := minf(debt, maxf(0.0, float(money) - (0.0 if days_left == 0 else 2000.0)))
				debt -= pay_d
				money -= int(pay_d)
			for m in C.check_milestones():
				money += int(m["money"])
		total += earned_w + biz_w
		var ending := "paid" if debt <= 1.0 else "pit"
		if debt > 1.0:
			money -= int(debt)              # недоплата — съедает копилку
		C.end_week(money, ending)
		out.append({"week": w + 1, "level": int(C.d["level"]), "jobs": earned_w, "biz": biz_w, "debt_left": int(debt), "bank": int(C.d["bank"]), "nodes": (C.d["nodes"] as Dictionary).size(), "ending": ending})
	return {"weeks": out, "total": total, "level": int(C.d["level"]), "prestige": C.prestige_ready(), "biz": C.biz_count(), "staff": C.staff_total()}
