## Переговоры с коллектором — мини-игра звонка. Коллектор говорит фразами (текст печатается), между ними —
## пауза «ТВОЯ ОЧЕРЕДЬ». Ответ картой в паузе — полный эффект, посреди фразы — «ПЕРЕБИЛ» (доверие падает,
## давление растёт), промолчал всю паузу — давление растёт. «Предъявить документ» — найти нужную бумагу за
## 4 с (клавиши 1–4). Три шкалы: доверие, давление, сколько пообещал внести завтра.
## Итог считает экономика (ml_economy.negotiation_result). Клавиши 1–6, мышь.
## Вёрстка — MGUI: одна колонка по центру (шапка звонка, реплика и шкалы, шесть ответов строками), контейнерами.
class_name MLNegotiation
extends Control

signal done(result: Dictionary)

const RED := MGUI.RED
const GREEN := MGUI.GOOD
const PHRASES := 6
const CARDS := [
	["delay", "ПРОШУ ОТСРОЧКУ", "мягко, без денег"],
	["part", "ВНЕСУ ЧАСТЬ СЕЙЧАС", "30 % остатка — сразу с карты"],
	["plan", "НОВЫЙ ГРАФИК", "обещание внести завтра 40 %"],
	["doc", "ПРЕДЪЯВИТЬ ДОКУМЕНТ", "найти нужную бумагу за 4 секунды"],
	["error", "ОШИБКА В ДОГОВОРЕ", "если знаешь, о чём говоришь"],
	["refuse", "НЕ БУДУ ПЛАТИТЬ", "положить трубку"],
]
const DOCS := [["receipt", "КВИТАНЦИЯ ОБ ОПЛАТЕ"], ["contract", "ДОГОВОР С МЕЛКИМ ШРИФТОМ"], ["work", "СПРАВКА С ПОДРАБОТКИ"], ["screen", "СНИМОК ОШИБОЧНОГО СЧЁТА"]]
const COL_W := 1000.0             # ширина колонки звонка

var econ: MLEconomy
var loan := {}
var lender := {}
var font: Font
var serif: SystemFont
var trust := 40.0
var pressure := 30.0
var promise := 0
var used_error := false
var asked_delay := 0
var t_left := 35.0
var t_full := 35.0
var phrase := 0
var speaking := true
var speak_t := 0.0
var speak_len := 2.0
var window_t := 0.0
var window_len := 1.4
var answered := false
var text_full := ""
var doc_mode := false
var doc_t := 0.0
var doc_right := ""
var finished := false
var log_lines: Array = []
# узлы
var bubble: Label
var turn_bar: Dictionary
var turn_l: Label
var timer_bar: Dictionary
var time_l: Label
var bars := {}
var card_nodes: Array = []
var doc_box: Control
var doc_bar: Dictionary
var flash: Label
var auto_answers: Array = []      # проверка: [[фраза, карта, в паузе?]]

func setup(e: MLEconomy, loan_id: int, f: Font, sf: SystemFont) -> void:
	econ = e
	loan = e.loan(loan_id)
	lender = MLData.LENDERS[loan["lender"]]
	font = f
	serif = sf
	trust = clampf(float(e.rep) * 0.7 + (12.0 if e.lender_flags.get(loan["lender"], {}).has("error") else 0.0), 10.0, 80.0)
	pressure = clampf(30.0 + float(loan["overdue"]) * 18.0 + (10.0 if e.flags.has("bad_phone") else 0.0), 0.0, 95.0)
	t_left = 35.0 + (4.0 if e.upgrades.has("phone") else 0.0)
	t_full = t_left
	window_len = 1.4 + (0.6 if e.upgrades.has("talk") else 0.0) - (0.3 if e.stress >= 70 else 0.0)
	# какой документ правильный: ошибочный счёт → скрин; платил раньше → квитанция; работал → справка; иначе договор
	if e.lender_flags.get(loan["lender"], {}).has("error"):
		doc_right = "screen"
	elif int(loan.get("min_used", 0)) > 0 or float(loan["balance"]) < float(loan["principal"]):
		doc_right = "receipt"
	elif int(e.stats["jobs"]) > 0:
		doc_right = "work"
	else:
		doc_right = "contract"
	_build()
	_next_phrase()

func _build() -> void:
	var par := get_parent() as Control
	size = Vector2(maxf(1600.0, par.size.x) if par != null else 1600.0, 900.0)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.size = size
	add_child(shade)
	var pc := MGUI.panel(false, null, MGUI.S5)
	pc.custom_minimum_size = Vector2(COL_W, 0)
	pc.position = Vector2((size.x - COL_W) * 0.5, 70)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pc)
	var v := MGUI.vbox(MGUI.S4)
	pc.add_child(v)
	# шапка: кто звонит, по какому долгу, сколько осталось времени
	var top := MGUI.hbox(MGUI.S3)
	v.add_child(top)
	var ic := MGIcon.make("call", 30, Color(0.55, 0.85, 1.0))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var who := MGUI.vbox(0)
	top.add_child(who)
	who.add_child(MGUI.label("ВХОДЯЩИЙ ЗВОНОК", "caps", Color(0.55, 0.85, 1.0)))
	who.add_child(MGUI.label(String(lender["name"]), "h1"))
	top.add_child(MGUI.spacer())
	var debt := MGUI.stat("ДОЛГ", MGUI.rub(int(ceil(float(loan["balance"])))), "num")
	top.add_child(debt["box"])
	top.add_child(MGUI.vsep())
	var od := int(loan["overdue"])
	var due := MGUI.stat("СРОК", ("просрочен на %d дн." % od) if od > 0 else "день %d" % int(loan["due"]), "num")
	if od > 0:
		(due["val"] as Label).add_theme_color_override("font_color", RED)
	top.add_child(due["box"])
	top.add_child(MGUI.vsep())
	var tm := MGUI.stat("РАЗГОВОР", "0:35", "mono_l")
	time_l = tm["val"]
	(tm["box"] as Control).custom_minimum_size.x = 84
	top.add_child(tm["box"])
	timer_bar = MGUI.bar(COL_W - 2.0 * MGUI.S5, 3, RED)
	v.add_child(timer_bar["box"])
	# середина: реплика коллектора слева, три шкалы справа
	var mid := MGUI.hbox(MGUI.S4)
	v.add_child(mid)
	var left := MGUI.vbox(MGUI.S2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)
	var bub := PanelContainer.new()
	bub.add_theme_stylebox_override("panel", MGUI.box(MGUI.PAPER, 4, 0, MGUI.LINE, MGUI.S4))
	bub.custom_minimum_size = Vector2(0, 128)
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(bub)
	bubble = MGUI.label("", "h2", MGUI.INK, 560.0)
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bubble.size_flags_vertical = Control.SIZE_FILL
	bub.add_child(bubble)
	turn_bar = MGUI.bar(620, 4, GREEN)
	left.add_child(turn_bar["box"])
	turn_l = MGUI.label("", "caps_m")
	left.add_child(turn_l)
	var right := MGUI.vbox(MGUI.S3)
	right.custom_minimum_size.x = 300
	mid.add_child(right)
	for k in [["trust", "ДОВЕРИЕ", GREEN], ["pressure", "ДАВЛЕНИЕ", RED], ["promise", "ОБЕЩАНО НА ЗАВТРА", MGUI.GOLD]]:
		var mv := MGUI.vbox(MGUI.S1)
		right.add_child(mv)
		var mh := MGUI.hbox(MGUI.S2)
		mv.add_child(mh)
		mh.add_child(MGUI.label(String(k[1]), "caps"))
		mh.add_child(MGUI.spacer())
		var num := MGUI.label("", "mono", MGUI.TEXT)
		mh.add_child(num)
		var bar := MGUI.bar(300, 8, k[2])
		mv.add_child(bar["box"])
		bars[k[0]] = {"bar": bar, "num": num}
	# короткая строка-ответ коллектора: одна, на постоянном месте (панель не прыгает)
	flash = MGUI.label("", "body_b", RED)
	flash.custom_minimum_size.y = 22
	flash.modulate.a = 0.0
	v.add_child(flash)
	v.add_child(MGUI.hsep())
	# ответы: шесть строк в две колонки — клавиша, название, пояснение; причина недоступности вместо пояснения
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", MGUI.S2)
	grid.add_theme_constant_override("v_separation", MGUI.S2)
	v.add_child(grid)
	for k in CARDS.size():
		var c := PanelContainer.new()
		var sb := MGUI.box(Color(0.09, 0.09, 0.105), 3, 1, MGUI.LINE, MGUI.S3)
		c.add_theme_stylebox_override("panel", sb)
		c.custom_minimum_size = Vector2((COL_W - 2.0 * MGUI.S5 - MGUI.S2) * 0.5, 0)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		grid.add_child(c)
		var h := MGUI.hbox(MGUI.S3)
		c.add_child(h)
		var key := MGUI.keycap(str(k + 1))
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(key)
		var tv := MGUI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		var title := MGUI.label(String(CARDS[k][1]), "body_b", RED if String(CARDS[k][0]) == "refuse" else MGUI.TEXT)
		tv.add_child(title)
		var sub := MGUI.label(String(CARDS[k][2]), "micro", MGUI.TEXT_2)
		sub.clip_text = true
		tv.add_child(sub)
		card_nodes.append({"root": c, "sb": sb, "title": title, "sub": sub, "why": sub, "base": String(CARDS[k][2])})
		var kk := k
		c.mouse_entered.connect(func(): sb.border_color = MGUI.PAPER)
		c.mouse_exited.connect(func(): sb.border_color = MGUI.LINE)
		c.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				play(kk))
	v.add_child(MGUI.hints([["1–6", "ответить"], ["мышь", "выбрать ответ"]]))
	# документы: ящик стола поверх колонки
	doc_box = Control.new()
	doc_box.size = size
	doc_box.visible = false
	doc_box.set_meta("audit_modal", true)
	add_child(doc_box)
	var dsh := ColorRect.new()
	dsh.color = Color(0, 0, 0, 0.82)
	dsh.size = size
	doc_box.add_child(dsh)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", MGUI.box(MGUI.PAPER, 4, 0, MGUI.LINE, MGUI.S5))
	dp.custom_minimum_size = Vector2(640, 0)
	dp.position = Vector2((size.x - 640.0) * 0.5, 300)
	doc_box.add_child(dp)
	var dv := MGUI.vbox(MGUI.S3)
	dp.add_child(dv)
	dv.add_child(MGUI.label("ЯЩИК СТОЛА", "caps", Color(0.35, 0.34, 0.33)))
	dv.add_child(MGUI.label("Какая бумага нужна?", "h2", MGUI.INK))
	doc_bar = MGUI.bar(640 - 2.0 * MGUI.S5, 4, RED)
	(doc_bar["box"] as ColorRect).color = Color(0.7, 0.68, 0.64)
	dv.add_child(doc_bar["box"])
	var dg := GridContainer.new()
	dg.columns = 2
	dg.add_theme_constant_override("h_separation", MGUI.S2)
	dg.add_theme_constant_override("v_separation", MGUI.S2)
	dv.add_child(dg)
	for k in DOCS.size():
		var b := PanelContainer.new()
		var bsb := MGUI.box(Color(1, 1, 1), 3, 1, Color(0.6, 0.58, 0.55), MGUI.S3)
		b.add_theme_stylebox_override("panel", bsb)
		b.custom_minimum_size = Vector2((640 - 2.0 * MGUI.S5 - MGUI.S2) * 0.5, 54)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dg.add_child(b)
		var bh := MGUI.hbox(MGUI.S3)
		b.add_child(bh)
		var kc := MGUI.keycap(str(k + 1))
		kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(kc)
		var dl := MGUI.label(String(DOCS[k][1]), "body_b", MGUI.INK, 200.0)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(dl)
		var kk2 := k
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				pick_doc(kk2))
	_paint_cards()

func _avail(k: int) -> String:
	match String(CARDS[k][0]):
		"part":
			var need := int(ceil(float(loan["balance"]) * 0.3))
			return "" if econ.money >= need else "нужно " + MGUI.rub(need)
		"plan":
			return "" if econ.upgrades.has("talk") or trust >= 50.0 else "нужна книга о переговорах или доверие 50"
	return ""

func _paint_cards() -> void:
	for k in card_nodes.size():
		var why := _avail(k)
		var n: Dictionary = card_nodes[k]
		(n["sub"] as Label).text = why if why != "" else String(n["base"])
		(n["sub"] as Label).add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if why != "" else MGUI.TEXT_2)
		(n["root"] as Control).modulate.a = 0.5 if why != "" else 1.0
	var pk := clampf(float(promise) / maxf(1.0, float(loan["balance"])), 0.0, 1.0)
	MGUI.set_bar(bars["trust"]["bar"], trust / 100.0)
	MGUI.set_bar(bars["pressure"]["bar"], pressure / 100.0)
	MGUI.set_bar(bars["promise"]["bar"], pk)
	(bars["trust"]["num"] as Label).text = "%d" % int(round(trust))
	(bars["pressure"]["num"] as Label).text = "%d" % int(round(pressure))
	(bars["promise"]["num"] as Label).text = MGUI.rub(promise)

func _next_phrase() -> void:
	if phrase >= PHRASES:
		_end()
		return
	var voice: Array = lender["voice"]
	var lines := voice.duplicate()
	lines.append("Ваш долг — %d рублей. Это не шутки." % int(ceil(float(loan["balance"]))))
	lines.append("Мы видим, что вы читаете это сообщение.")
	text_full = String(lines[phrase % lines.size()]) if phrase < voice.size() else String(lines[voice.size() + (phrase - voice.size()) % 2])
	speak_len = clampf(float(text_full.length()) * 0.045, 1.2, 2.6)
	speak_t = 0.0
	speaking = true
	answered = false
	window_t = 0.0
	phrase += 1

func _process(dt: float) -> void:
	if finished:
		return
	t_left -= dt
	MGUI.set_bar(timer_bar, t_left / maxf(1.0, t_full))
	time_l.text = "0:%02d" % int(ceil(maxf(0.0, t_left)))
	time_l.add_theme_color_override("font_color", RED if t_left < 8.0 else MGUI.TEXT)
	if t_left <= 0.0:
		_end()
		return
	if doc_mode:
		doc_t -= dt
		MGUI.set_bar(doc_bar, doc_t / 4.0)
		if doc_t <= 0.0:
			pick_doc(-1)
		return
	if speaking:
		speak_t += dt
		bubble.text = text_full.substr(0, int(float(text_full.length()) * clampf(speak_t / speak_len, 0.0, 1.0)))
		MGUI.set_bar(turn_bar, 0.0)
		turn_l.text = "КОЛЛЕКТОР ГОВОРИТ — НЕ ПЕРЕБИВАЙ"
		turn_l.add_theme_color_override("font_color", MGUI.TEXT_3)
		if speak_t >= speak_len:
			speaking = false
			window_t = 0.0
			bubble.text = text_full
	else:
		window_t += dt
		MGUI.set_bar(turn_bar, 1.0 - clampf(window_t / window_len, 0.0, 1.0))
		turn_l.text = "ТВОЯ ОЧЕРЕДЬ — ОТВЕЧАЙ"
		turn_l.add_theme_color_override("font_color", GREEN)
		if window_t >= window_len:
			if not answered:
				pressure = minf(100.0, pressure + 6.0)
				_flash("«Алло? Вы меня слышите?»", RED)
			_next_phrase()
	# проверка: заготовленные ответы
	for a in auto_answers.duplicate():
		if int(a[0]) == phrase and (bool(a[2]) == (not speaking)) and (not speaking or speak_t > speak_len * 0.4):
			auto_answers.erase(a)
			play(int(a[1]))
	_paint_cards()

func _flash(s: String, col: Color) -> void:
	flash.text = s
	flash.add_theme_color_override("font_color", col)
	flash.modulate.a = 1.0
	var tw := flash.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(flash, "modulate:a", 0.0, 0.4)

func _unhandled_input(e: InputEvent) -> void:
	if finished or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_6:
		if doc_mode:
			if k <= KEY_4:
				pick_doc(k - KEY_1)
		else:
			play(k - KEY_1)
		get_viewport().set_input_as_handled()

## ход картой: в паузе — полный эффект, посреди фразы — «ПЕРЕБИЛ»
func play(k: int) -> void:
	if finished or doc_mode or k < 0 or k >= CARDS.size() or _avail(k) != "":
		return
	var interrupt := speaking
	var mul := 0.5 if interrupt else 1.0
	if interrupt:
		trust = maxf(0.0, trust - 10.0)
		pressure = minf(100.0, pressure + 8.0)
		_flash("ПЕРЕБИЛ!", RED)
	answered = true
	log_lines.append([String(CARDS[k][0]), interrupt])
	match String(CARDS[k][0]):
		"delay":
			asked_delay += 1
			if asked_delay == 1:
				trust += 8.0 * mul
				pressure -= 5.0 * mul
			else:
				trust -= 6.0
				pressure += 6.0
				_flash("«Вы это уже говорили»", RED)
		"part":
			var amt := int(ceil(float(loan["balance"]) * 0.3))
			econ.pay(int(loan["id"]), amt)
			trust += 20.0 * mul
			pressure -= 15.0 * mul
			_flash("%s ушло в счёт долга" % MGUI.rub(amt), GREEN)
		"plan":
			promise += int(ceil(float(loan["balance"]) * 0.4))
			trust += 12.0 * mul
			pressure -= 6.0 * mul
		"doc":
			doc_mode = true
			doc_t = 4.0
			doc_box.visible = true
			return
		"error":
			var C: Dictionary = MLData.CLAUSES.get(String(loan["clause"]), ["", {}])[1]
			var real: bool = econ.lender_flags.get(loan["lender"], {}).has("error") or (bool(loan["known"]) and (C.has("fine_x") or C.has("rate_jump") or C.has("early")))
			if real and not used_error:
				used_error = true
				trust += 10.0 * mul
				pressure -= 20.0 * mul
				_flash("«…Мы проверим этот пункт»", GREEN)
			else:
				pressure += 15.0
				trust -= 8.0
				_flash("«Какая ещё ошибка? Не выдумывайте»", RED)
		"refuse":
			pressure = minf(100.0, pressure + 25.0)
			trust = maxf(0.0, trust - 15.0)
			_end()
			return
	trust = clampf(trust, 0.0, 100.0)
	pressure = clampf(pressure, 0.0, 100.0)
	if not speaking:
		window_t = window_len           # ответил — коллектор говорит дальше
	_paint_cards()

func pick_doc(i: int) -> void:
	doc_mode = false
	doc_box.visible = false
	if i >= 0 and String(DOCS[i][0]) == doc_right:
		trust = minf(100.0, trust + 18.0)
		pressure = maxf(0.0, pressure - 10.0)
		_flash("«Так… да, вижу. Хорошо»", GREEN)
	else:
		trust = maxf(0.0, trust - 8.0)
		_flash("«Это не то. Вы издеваетесь?»" if i >= 0 else "«Не можете найти? Ясно»", RED)
	if not speaking:
		window_t = window_len

func _end() -> void:
	if finished:
		return
	finished = true
	var r := econ.negotiation_result(int(loan["id"]), trust, pressure, promise, used_error)
	r["trust"] = trust
	r["pressure"] = pressure
	r["promise"] = promise
	done.emit(r)
