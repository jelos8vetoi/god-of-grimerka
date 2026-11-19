## Переговоры с коллектором — мини-игра звонка. Коллектор говорит фразами (текст печатается), между ними —
## пауза «ТВОЯ ОЧЕРЕДЬ». Ответ картой в паузе — полный эффект, посреди фразы — «ПЕРЕБИЛ» (доверие падает,
## давление растёт), промолчал всю паузу — давление растёт. «Предъявить документ» — найти нужную бумагу за
## 4 с (клавиши 1–4). Три шкалы: TRUST (доверие), PRESSURE (давление), PROMISE (сколько пообещал внести завтра).
## Итог считает экономика (ml_economy.negotiation_result). Клавиши 1–6, мышь.
class_name MLNegotiation
extends Control

signal done(result: Dictionary)

const RED := Color(0.86, 0.09, 0.11)
const GREEN := Color(0.4, 0.9, 0.45)
const PHRASES := 6
const CARDS := [
	["delay", "ПРОШУ ОТСРОЧКУ", "мягко, без денег"],
	["part", "ВНЕСУ ЧАСТЬ СЕЙЧАС", "30% остатка — сразу с карты"],
	["plan", "НОВЫЙ ГРАФИК", "обещание внести завтра 40%"],
	["doc", "ПРЕДЪЯВИТЬ ДОКУМЕНТ", "найди нужную бумагу за 4 с"],
	["error", "ОШИБКА В ДОГОВОРЕ!", "если знаешь, о чём говоришь"],
	["refuse", "НЕ БУДУ ПЛАТИТЬ", "кладёшь трубку"],
]
const DOCS := [["receipt", "КВИТАНЦИЯ ОБ ОПЛАТЕ"], ["contract", "ДОГОВОР С МЕЛКИМ ШРИФТОМ"], ["work", "СПРАВКА С ПОДРАБОТКИ"], ["screen", "СКРИН ОШИБОЧНОГО СЧЁТА"]]

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
var turn_bar: ColorRect
var turn_l: Label
var timer_bar: ColorRect
var bars := {}
var cards_box: Control
var card_nodes: Array = []
var doc_box: Control
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

func _txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _build() -> void:
	size = Vector2(1600, 900)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.size = size
	add_child(shade)
	_txt(self, "☎ ВХОДЯЩИЙ: " + String(lender["name"]), 40, Color(1, 1, 1), Vector2(80, 50), serif)
	_txt(self, "Долг %d ₽ · срок: день %d%s" % [int(ceil(float(loan["balance"]))), int(loan["due"]), " · ПРОСРОЧКА %d дн." % int(loan["overdue"]) if int(loan["overdue"]) > 0 else ""], 20, Color(0.8, 0.8, 0.82), Vector2(84, 104))
	var tb := ColorRect.new()
	tb.color = Color(0.2, 0.2, 0.22)
	tb.position = Vector2(80, 140)
	tb.size = Vector2(1440, 8)
	add_child(tb)
	timer_bar = ColorRect.new()
	timer_bar.color = RED
	timer_bar.position = tb.position
	timer_bar.size = tb.size
	add_child(timer_bar)
	# шкалы
	var y := 180.0
	for k in [["trust", "TRUST — ДОВЕРИЕ", GREEN], ["pressure", "PRESSURE — ДАВЛЕНИЕ", RED], ["promise", "PROMISE — ОБЕЩАНО НА ЗАВТРА", Color(1, 0.85, 0.3)]]:
		_txt(self, String(k[1]), 16, Color(0.85, 0.85, 0.87), Vector2(1080, y))
		var bg := ColorRect.new()
		bg.color = Color(0.15, 0.15, 0.17)
		bg.position = Vector2(1080, y + 24)
		bg.size = Vector2(440, 14)
		add_child(bg)
		var fg := ColorRect.new()
		fg.color = k[2]
		fg.position = bg.position
		fg.size = Vector2(0, 14)
		add_child(fg)
		bars[k[0]] = fg
		y += 64
	# реплика коллектора
	var bub := ColorRect.new()
	bub.color = Color(0.94, 0.94, 0.92)
	bub.position = Vector2(80, 180)
	bub.size = Vector2(960, 200)
	add_child(bub)
	bubble = _txt(bub, "", 30, Color(0.05, 0.05, 0.06), Vector2(24, 20), serif)
	bubble.size = Vector2(910, 160)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_bar = ColorRect.new()
	turn_bar.color = GREEN
	turn_bar.position = Vector2(80, 392)
	turn_bar.size = Vector2(0, 16)
	add_child(turn_bar)
	turn_l = _txt(self, "", 20, GREEN, Vector2(84, 412), serif)
	flash = _txt(self, "", 44, RED, Vector2(0, 470), serif)
	flash.size = Vector2(1600, 60)
	flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# карты ответов
	cards_box = Control.new()
	cards_box.position = Vector2(80, 560)
	add_child(cards_box)
	for k in CARDS.size():
		var c := ColorRect.new()
		c.color = Color(0.07, 0.07, 0.08)
		c.position = Vector2((k % 3) * 485, (k / 3) * 140)
		c.size = Vector2(465, 124)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		cards_box.add_child(c)
		var edge := ReferenceRect.new()
		edge.border_color = Color(1, 1, 1, 0.8)
		edge.border_width = 2.0
		edge.editor_only = false
		edge.size = c.size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(edge)
		_txt(c, "[%d]" % (k + 1), 18, RED, Vector2(16, 12))
		var title := _txt(c, String(CARDS[k][1]), 26, Color(1, 1, 1), Vector2(64, 8), serif)
		var sub := _txt(c, String(CARDS[k][2]), 16, Color(0.7, 0.7, 0.72), Vector2(66, 50))
		var why := _txt(c, "", 15, Color(1.0, 0.5, 0.45), Vector2(66, 80))
		card_nodes.append({"root": c, "title": title, "sub": sub, "why": why})
		var kk := k
		c.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				play(kk))
	# документы
	doc_box = Control.new()
	doc_box.position = Vector2(300, 300)
	doc_box.visible = false
	add_child(doc_box)
	var dbg := ColorRect.new()
	dbg.color = Color(0.92, 0.9, 0.85)
	dbg.size = Vector2(1000, 330)
	doc_box.add_child(dbg)
	_txt(doc_box, "ЯЩИК СТОЛА — КАКАЯ БУМАГА НУЖНА? (1–4, 4 секунды)", 24, Color(0.1, 0.1, 0.1), Vector2(30, 20), serif)
	for k in DOCS.size():
		var b := ColorRect.new()
		b.color = Color(1, 1, 1)
		b.position = Vector2(30 + (k % 2) * 480, 80 + (k / 2) * 120)
		b.size = Vector2(460, 100)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		doc_box.add_child(b)
		_txt(b, "[%d] %s" % [k + 1, DOCS[k][1]], 22, Color(0.05, 0.05, 0.06), Vector2(18, 34))
		var kk2 := k
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				pick_doc(kk2))
	_paint_cards()

func _avail(k: int) -> String:
	match String(CARDS[k][0]):
		"part":
			var need := int(ceil(float(loan["balance"]) * 0.3))
			return "" if econ.money >= need else "нужно %d ₽" % need
		"plan":
			return "" if econ.upgrades.has("talk") or trust >= 50.0 else "нужна книга о переговорах или доверие 50"
	return ""

func _paint_cards() -> void:
	for k in card_nodes.size():
		var why := _avail(k)
		(card_nodes[k]["why"] as Label).text = why
		(card_nodes[k]["root"] as ColorRect).modulate.a = 0.45 if why != "" else 1.0
	(bars["trust"] as ColorRect).size.x = 440.0 * trust / 100.0
	(bars["pressure"] as ColorRect).size.x = 440.0 * pressure / 100.0
	(bars["promise"] as ColorRect).size.x = 440.0 * clampf(float(promise) / maxf(1.0, float(loan["balance"])), 0.0, 1.0)

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
	timer_bar.size.x = 1440.0 * clampf(t_left / 39.0, 0.0, 1.0)
	if t_left <= 0.0:
		_end()
		return
	if doc_mode:
		doc_t -= dt
		if doc_t <= 0.0:
			pick_doc(-1)
		return
	if speaking:
		speak_t += dt
		bubble.text = text_full.substr(0, int(float(text_full.length()) * clampf(speak_t / speak_len, 0.0, 1.0)))
		turn_bar.size.x = 0
		turn_l.text = "коллектор говорит — не перебивай"
		turn_l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
		if speak_t >= speak_len:
			speaking = false
			window_t = 0.0
			bubble.text = text_full
	else:
		window_t += dt
		turn_bar.size.x = 960.0 * (1.0 - clampf(window_t / window_len, 0.0, 1.0))
		turn_l.text = "ТВОЯ ОЧЕРЕДЬ — отвечай!"
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
			_flash("−%d ₽ ушло в счёт долга" % amt, GREEN)
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
