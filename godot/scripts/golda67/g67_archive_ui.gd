class_name G67ArchiveUI
extends G67Diorama
## «АРХИВ ПИЗДЕЦА»: видеосалон подъезда — стена старых телевизоров (каждый ролик — свой телевизор со стоп-кадром
## из самого ролика, assets/golda67/archive/<ID>.jpg; события и концовки — запертые телевизоры), под ними полка
## кассет (встречи КРОТА и разговоры DJ FLÜRR — текст с голосом каждой реплики), справа — вкладыш выбранной записи.
## Данные и условия — как в игре: открыт ли ролик — Golda67.clip_open, просмотрен — clip_seen, встречи — meta.seen,
## разговоры — meta.archive (flurrN). Просмотр — существующий G67ClipPlayer через Golda67.play_clip: архив на это
## время прячется и потом возвращается к тому же телевизору. Уже показанные открытия — meta.arch_shown.

const CATS := ["РЕКЛАМА", "ОБЛАКО LIVE", "НОВОСТИ", "СЮЖЕТ"]
## место и модель каждого телевизора: [x, y, w, h, модель]
const SLOTS := [
	[56, 150, 330, 236, "wood"], [404, 172, 252, 214, "black"], [676, 186, 196, 200, "portable"], [892, 170, 224, 216, "silver"],
	[56, 414, 250, 214, "monitor"], [324, 430, 190, 198, "bulge"], [532, 418, 236, 210, "black"],
	[788, 446, 158, 182, "bulge"], [962, 446, 158, 182, "portable"],
	[56, 664, 172, 172, "silver"], [246, 656, 206, 180, "wood"], [470, 664, 196, 172, "monitor"],
]
const PREVIEW := "res://assets/golda67/archive/%s.jpg"

var tvs: Array = []
var tapes: Array = []
var recs: Array = []          # записи по порядку предметов: {type: "clip"/"event"/"ending"/"krot"/"flurr", …}
var sleeve: Control
var s_no: Label
var s_cat: Label
var s_title: Label
var s_state: Label
var s_text: Label
var s_still: TextureRect
var s_why: Label
var s_btn: Button
var c_all: Label
var c_seen: Label
var c_new: Label
var reader: Control
var r_list: VBoxContainer
var r_scroll: ScrollContainer
var r_rows: Array = []
var r_sel := 0
var voice: AudioStreamPlayer

static func open(g67: Golda67) -> G67ArchiveUI:
	var u := G67ArchiveUI.new()
	u._open_base(g67, "archive")
	u._build()
	return u

func _build() -> void:
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	var room := Room.new()
	room.size = STAGE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(room)
	lab("ВИДЕОСАЛОН ПОДЪЕЗДА · ЗАПИСИ РАЙОНА", "caps", 13, Color(0.66, 0.58, 0.46), Vector2(60, 34))
	lab("АРХИВ ПИЗДЕЦА", "display", 50, Color(0.9, 0.84, 0.7), Vector2(56, 50))
	c_all = lab("", "mono", 15, Color(0.86, 0.8, 0.66), Vector2(760, 66))
	c_seen = lab("", "mono", 15, Color(0.86, 0.8, 0.66), Vector2(930, 66))
	c_new = lab("", "mono", 15, Color(0.95, 0.5, 0.4), Vector2(1110, 66))
	_build_tvs()
	_build_tapes()
	_build_sleeve()
	_counters()
	# включение: телевизоры загораются по очереди; новые открытия — цепь падает
	var shown: Array = G.meta().get("arch_shown", [])
	var fresh: Array = []
	for i in tvs.size():
		var tv: G67ArchTV = tvs[i]
		var rid := String(recs[i]["id"])
		if recs[i]["type"] == "clip" and tv.state != "lock" and not shown.has(rid):
			fresh.append(tv)
			shown.append(rid)
		else:
			tv.power_on(0.05 + 0.045 * i)
	for k in fresh.size():
		var tv2: G67ArchTV = fresh[k]
		get_tree().create_timer(0.55 + 0.5 * k, true, false, true).timeout.connect(func():
			if is_instance_valid(tv2):
				tv2.unlock_anim()
				G.game.main.ui("launch", 0.9))
	if not fresh.is_empty():
		G.meta()["arch_shown"] = shown
		G.save()
		G.events.append(["arch_unlock", fresh.size()])
	select(0, true)

func _build_tvs() -> void:
	var list: Array = []
	var no := 1
	for sec in G67Data.ARCHIVE_CLIPS:
		for cid in sec[1]:
			var open: bool = G.clip_open(cid)
			list.append({"type": "clip", "id": cid, "cat": String(sec[0]), "no": no, "title": G67Clips.title(cid) if open else "???",
				"state": ("seen" if G.clip_seen(cid) else "new") if open else "lock", "preview": PREVIEW % cid if ResourceLoader.exists(PREVIEW % cid) else "",
				"why": "Запись появится " + String(G67Data.CLIP_WHY.get(cid, "позже")) + "."})
			no += 1
	for ev in G67Data.ARCHIVE_EVENTS:
		list.append({"type": "event", "id": "event%d" % no, "cat": "СОБЫТИЯ", "no": no, "title": "???", "state": "lock", "preview": "",
			"why": "Событие двора ещё не случалось. Запись появится, когда оно произойдёт во время забега."})
		no += 1
	for k in G67Data.ARCHIVE_ENDINGS:
		list.append({"type": "ending", "id": "ending%d" % (k + 1), "cat": "КОНЦОВКИ", "no": no, "title": "???", "state": "lock", "preview": "",
			"why": "Концовка ещё не открыта." if k == 0 else "Эта концовка — дальше по сюжету."})
		no += 1
	for i in mini(list.size(), SLOTS.size()):
		var s: Array = SLOTS[i]
		var tv := G67ArchTV.new()
		tv.position = Vector2(s[0], s[1])
		tv.size = Vector2(s[2], s[3])
		stage.add_child(tv)
		tv.setup(list[i], String(s[4]))
		tvs.append(tv)
		recs.append(list[i])
		add_item(tv, i)

func _build_tapes() -> void:
	var x := 700.0
	var seen: Array = G.meta().get("seen", [])
	var arch: Array = G.meta().get("archive", [])
	var lst: Array = []
	for i in G67Data.KROT.size():
		var k: Dictionary = G67Data.KROT[i]
		var has := seen.has(String(k["id"]))
		lst.append({"type": "krot", "id": String(k["id"]), "label": "КРОТ %d" % (i + 1), "has": has, "title": "КРОТ · встреча %d · %s" % [i + 1, String(k["title"])] if has else "КРОТ · встреча %d" % (i + 1),
			"lines": k["lines"], "why": "КРОТ ещё не попадался. Он ходит по двору — и не только.", "cat": "КРОТ"})
	for n in G67Flurr.STATES.size():
		var has2 := arch.has("flurr%d" % n)
		var why := "DJ FLÜRR ждёт на лавке: подойди и поговори." if n <= G.flurr_state() else "Откроется по ходу встреч с КРОТОМ."
		lst.append({"type": "flurr", "id": "flurr%d" % n, "label": "DJ %d" % (n + 1), "has": has2, "title": "DJ FLÜRR · разговор %d" % (n + 1),
			"lines": G67Flurr.STATES[n], "why": why, "cat": "DJ FLÜRR"})
	for r in lst:
		var tp := Tape.new()
		tp.rec = r
		tp.position = Vector2(x, 712)
		tp.size = Vector2(28, 120)
		tp.pivot_offset = tp.size * 0.5
		stage.add_child(tp)
		tapes.append(tp)
		recs.append(r)
		add_item(tp, recs.size() - 1)
		x += 31.0

func _build_sleeve() -> void:
	sleeve = Sleeve.new()
	sleeve.ui = self
	sleeve.position = Vector2(1150, 140)
	sleeve.size = Vector2(410, 700)
	sleeve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sleeve)
	var x := 1178.0
	s_no = lab("", "mono", 13, Color(0.25, 0.2, 0.16), Vector2(x, 176))
	s_cat = lab("", "caps", 13, Color(0.45, 0.12, 0.1), Vector2(x, 198))
	s_title = lab("", "display", 30, Color(0.12, 0.1, 0.08), Vector2(x, 222), 354)
	s_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	s_state = lab("", "caps", 14, Color(0.12, 0.1, 0.08), Vector2(x, 336))
	s_still = TextureRect.new()
	s_still.position = Vector2(x, 368)
	s_still.size = Vector2(354, 200)
	s_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	s_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(s_still)
	s_text = lab("", "ui", 16, Color(0.2, 0.17, 0.14), Vector2(x, 584), 354)
	s_why = lab("", "ui_b", 15, Color(0.5, 0.12, 0.1), Vector2(x, 672), 354)
	s_btn = Button.new()
	s_btn.position = Vector2(x, 744)
	s_btn.size = Vector2(354, 56)
	s_btn.focus_mode = Control.FOCUS_NONE
	s_btn.add_theme_font_override("font", MGUI.font("caps"))
	s_btn.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.11, 0.09) if st != "hover" else Color(0.3, 0.1, 0.08)
		if st == "disabled":
			sb.bg_color = Color(0.14, 0.11, 0.09, 0.2)
		sb.border_color = Color(0.85, 0.62, 0.3) if st != "disabled" else Color(0.3, 0.26, 0.2, 0.4)
		sb.set_border_width_all(2)
		s_btn.add_theme_stylebox_override(st, sb)
	s_btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
	s_btn.add_theme_color_override("font_hover_color", Color(0.98, 0.82, 0.5))
	s_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.26, 0.2, 0.8))
	s_btn.pressed.connect(func():
		if mode == "list":
			_activate(sel))
	stage.add_child(s_btn)

func _counters() -> void:
	var total := 0
	var open := 0
	var seen := 0
	var fresh := 0
	for r in recs:
		if r["type"] in ["clip", "event", "ending"]:
			total += 1
			if r["state"] != "lock":
				open += 1
			if r["state"] == "seen":
				seen += 1
			if r["state"] == "new":
				fresh += 1
	c_all.text = "ЗАПИСЕЙ %d / %d" % [open, total]
	c_seen.text = "ПРОСМОТРЕНО %d" % seen
	c_new.text = ("НОВЫХ %d" % fresh) if fresh > 0 else ""

# ---------------------------------------------------------------- выбор и вкладыш
func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		_mark(prev, false)
	_mark(i, true)
	var r: Dictionary = recs[i]
	s_why.text = ""
	s_still.texture = null
	s_still.material = null
	match String(r["type"]):
		"clip", "event", "ending":
			var tv: G67ArchTV = items[i]["node"]
			s_still.texture = tv.scr.texture
			s_still.material = tv.mat
			s_no.text = "ЗАПИСЬ № %02d" % int(r["no"])
			s_cat.text = String(r["cat"])
			s_title.text = String(r["title"])
			var st := tv.state
			if st == "lock":
				s_state.text = "ЗАПЕРТО"
				s_text.text = "Телевизор закрыт на цепь. Что на записи — пока не видно."
				s_why.text = String(r["why"])
				s_btn.text = "ЗАПЕРТО"
				s_btn.disabled = true
			else:
				var cid := String(r["id"])
				s_state.text = "НОВАЯ ЗАПИСЬ" if st == "new" else "ПРОСМОТРЕНО"
				var l0 := G67Clips.L(cid, 0)
				s_text.text = "%s«%s»\n— %s" % ["Вертикальная запись с телефона.\n\n" if G67Clips.tall(cid) else "", l0.get_slice("|", 1), G67Clips.speaker(l0.get_slice("|", 0))]
				s_btn.text = "СМОТРЕТЬ ЗАПИСЬ"
				s_btn.disabled = false
		_:
			s_no.text = "КАССЕТА · " + String(r["label"])
			s_cat.text = String(r["cat"])
			s_title.text = String(r["title"]) if bool(r["has"]) else "???"
			if bool(r["has"]):
				s_state.text = "ЗАПИСЬ РАЗГОВОРА"
				s_text.text = "«%s»\n\nРеплик: %d. Каждую можно послушать." % [String(r["lines"][0]).get_slice("|", 1), (r["lines"] as Array).size()]
				s_btn.text = "СЛУШАТЬ КАССЕТУ"
				s_btn.disabled = false
			else:
				s_state.text = "ПУСТАЯ КАССЕТА"
				s_text.text = "Подписи нет, плёнка чистая."
				s_why.text = String(r["why"])
				s_btn.text = "ПУСТО"
				s_btn.disabled = true
	_fit_title()
	sleeve.queue_redraw()

func _fit_title() -> void:
	var f := MGUI.font("display")
	var sz := 30
	while sz > 18:
		var longest := 0.0
		for wd in s_title.text.split(" "):
			longest = maxf(longest, f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		if longest <= 350.0 and f.get_multiline_string_size(s_title.text, HORIZONTAL_ALIGNMENT_LEFT, 354, sz).y <= 104.0:
			break
		sz -= 2
	s_title.add_theme_font_size_override("font_size", sz)

func _mark(i: int, v: bool) -> void:
	var n = items[i]["node"]
	if n is G67ArchTV:
		(n as G67ArchTV).set_selected(v)
	elif n is Tape:
		(n as Tape).set_selected(v)

func _activate(i: int) -> void:
	if i < 0:
		return
	var r: Dictionary = recs[i]
	match String(r["type"]):
		"clip":
			var tv: G67ArchTV = items[i]["node"]
			if tv.state == "lock" or not G.clip_open(String(r["id"])):
				_deny(tv)
				return
			_watch(i)
		"event", "ending":
			_deny(items[i]["node"])
		_:
			if not bool(r["has"]):
				_deny(items[i]["node"])
				return
			_read(r)

func _deny(n: Control) -> void:
	G.game.main.ui("deny")
	var x0 := n.position.x
	var tw := n.create_tween()
	for k in 4:
		tw.tween_property(n, "position:x", x0 + (5.0 if k % 2 == 0 else -5.0), 0.035)
	tw.tween_property(n, "position:x", x0, 0.035)
	s_why.modulate = Color(1.6, 1.3, 1.3)
	s_why.create_tween().tween_property(s_why, "modulate", Color.WHITE, 0.4)

## Просмотр: архив прячется, ролик идёт существующим плеером, по окончании — обратно к тому же телевизору
func _watch(i: int) -> void:
	mode = "busy"
	visible = false
	voice.stop()
	G.game.main.ui("confirm")
	var cid := String(recs[i]["id"])
	G.events.append(["arch_watch", cid])
	await G.play_clip(cid)
	if not is_inside_tree():
		return
	visible = true
	mode = "list"
	var tv: G67ArchTV = items[i]["node"]
	tv.rec["state"] = "seen" if G.clip_seen(cid) else "new"
	tv.state = String(tv.rec["state"])
	tv.queue_redraw()
	tv.over.queue_redraw()
	_counters()
	var keep := sel
	sel = -1
	select(keep, true)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)

# ---------------------------------------------------------------- кассета: разговор целиком, голос реплик
func _read(r: Dictionary) -> void:
	mode = "read"
	G.game.main.ui("open")
	reader = Control.new()
	reader.z_index = 20
	reader.size = STAGE
	reader.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(reader)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = STAGE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader.add_child(dim)
	var card := Card.new()
	card.position = Vector2(330, 70)
	card.size = Vector2(940, 760)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.head = String(r["title"])
	card.krot = String(r["type"]) == "krot"
	reader.add_child(card)
	r_scroll = ScrollContainer.new()
	r_scroll.position = Vector2(380, 180)
	r_scroll.size = Vector2(840, 620)
	r_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reader.add_child(r_scroll)
	r_list = VBoxContainer.new()
	r_list.add_theme_constant_override("separation", 10)
	r_list.custom_minimum_size = Vector2(820, 0)
	r_scroll.add_child(r_list)
	r_rows = []
	for ln in r["lines"]:
		var s := String(ln)
		var code := s.get_slice("|", 0)
		var who := "DJ FLÜRR" if code == "DJ" else G67Clips.speaker(code)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var mark := ColorRect.new()
		mark.custom_minimum_size = Vector2(4, 0)
		mark.color = Color(0, 0, 0, 0)
		row.add_child(mark)
		var wl := Label.new()
		wl.text = who
		wl.custom_minimum_size = Vector2(150, 0)
		wl.add_theme_font_override("font", MGUI.font("caps"))
		wl.add_theme_font_size_override("font_size", 13)
		wl.add_theme_color_override("font_color", Color(0.48, 0.14, 0.1) if code != "V" else Color(0.18, 0.2, 0.36))
		row.add_child(wl)
		var tl := Label.new()
		tl.text = s.get_slice("|", 1)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(600, 0)
		tl.add_theme_font_override("font", MGUI.font("ui"))
		tl.add_theme_font_size_override("font_size", 17)
		tl.add_theme_color_override("font_color", Color(0.14, 0.12, 0.1))
		row.add_child(tl)
		r_list.add_child(row)
		var k := r_rows.size()
		r_rows.append({"row": row, "mark": mark, "path": G67Voice.path(s)})
		row.mouse_entered.connect(func(): _rsel(k))
		row.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_rsel(k)
				_rplay())
	reader.modulate.a = 0.0
	reader.create_tween().tween_property(reader, "modulate:a", 1.0, 0.16)
	r_sel = -1
	_rsel(0)
	G.events.append(["arch_read", String(r["id"])])

func _rsel(k: int) -> void:
	k = clampi(k, 0, r_rows.size() - 1)
	if k == r_sel:
		return
	if r_sel >= 0:
		(r_rows[r_sel]["mark"] as ColorRect).color = Color(0, 0, 0, 0)
	r_sel = k
	(r_rows[k]["mark"] as ColorRect).color = Color(0.62, 0.16, 0.12)
	r_scroll.ensure_control_visible(r_rows[k]["row"])

func _rplay() -> void:
	var pth := String(r_rows[r_sel]["path"])
	if pth == "":
		G.game.main.ui("deny")
		return
	voice.stream = load(pth)
	voice.play()

func _nav(d: Vector2) -> void:
	if mode == "read":
		if d.y != 0.0:
			_rsel(r_sel + int(d.y))
		return
	super._nav(d)

func _input(e: InputEvent) -> void:
	if mode == "read" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		get_viewport().set_input_as_handled()
		_rplay()
		return
	super._input(e)

func _back() -> bool:
	if mode == "read":
		voice.stop()
		reader.queue_free()
		reader = null
		mode = "list"
		G.game.main.ui("back")
		return true
	return false

func close() -> void:
	voice.stop()
	super.close()

# ---------------------------------------------------------------- рисованные части
## Комната: тёмные обои в полоску, панели, полки под рядами, провода, удлинитель, стопка кассет
class Room extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.06, 0.05))
		for x in range(0, int(size.x), 22):
			draw_rect(Rect2(Vector2(x, 0), Vector2(11, size.y)), Color(0.09, 0.072, 0.058))
		for x in range(0, int(size.x), 88):
			draw_line(Vector2(x + 44, 0), Vector2(x + 44, size.y), Color(0.12, 0.09, 0.06, 0.5), 1.0)
		# низ стены — панели
		draw_rect(Rect2(Vector2(0, 846), Vector2(size.x, 54)), Color(0.05, 0.04, 0.035))
		for y in [392.0, 634.0, 842.0]:                   # полки
			draw_rect(Rect2(Vector2(36, y), Vector2(1100, 12)), Color(0.24, 0.16, 0.1))
			draw_rect(Rect2(Vector2(36, y + 12), Vector2(1100, 5)), Color(0.08, 0.05, 0.03))
			for x in [60.0, 1110.0]:
				draw_rect(Rect2(Vector2(x, y + 17), Vector2(8, 22)), Color(0.18, 0.12, 0.08))
		# провода от телевизоров к удлинителю внизу
		for p in [[Vector2(220, 392), Vector2(150, 520), Vector2(700, 850)], [Vector2(530, 392), Vector2(600, 600), Vector2(740, 850)],
				[Vector2(1000, 392), Vector2(1120, 560), Vector2(780, 850)], [Vector2(430, 634), Vector2(480, 760), Vector2(760, 850)]]:
			var c := Curve2D.new()
			c.add_point(p[0], Vector2.ZERO, (p[1] - p[0]) * 0.6)
			c.add_point(p[2], (p[1] - p[2]) * 0.6, Vector2.ZERO)
			draw_polyline(c.tessellate(), Color(0.03, 0.03, 0.03, 0.85), 3.0, true)
		draw_rect(Rect2(Vector2(690, 846), Vector2(130, 18)), Color(0.82, 0.8, 0.74))
		for k in 4:
			draw_circle(Vector2(706 + k * 30, 855), 4.0, Color(0.3, 0.3, 0.3))
		draw_circle(Vector2(806, 855), 3.0, Color(0.9, 0.2, 0.15))
		# стопка видеокассет у полки кассет
		for k in 3:
			draw_rect(Rect2(Vector2(1146 - 150, 812 - k * 13), Vector2(130, 12)), Color(0.07, 0.07, 0.07))
			draw_rect(Rect2(Vector2(1146 - 140, 815 - k * 13), Vector2(60, 6)), Color(0.8, 0.76, 0.62))

## Кассета на полке: корешок с наклейкой; встречи КРОТА — оливковые, DJ FLÜRR — бирюзовые; пустая — без подписи
class Tape extends Control:
	var rec: Dictionary
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		var tw := create_tween()
		tw.tween_property(self, "position:y", 694.0 if v else 712.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func _draw() -> void:
		var has := bool(rec["has"])
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color(0.06, 0.06, 0.065))
		var lc := Color(0.55, 0.6, 0.32) if String(rec["type"]) == "krot" else Color(0.3, 0.62, 0.6)
		if not has:
			lc = Color(0.32, 0.31, 0.29)
		draw_rect(Rect2(Vector2(4, 10), Vector2(size.x - 8, size.y - 20)), lc)
		var f := MGUI.font("caps")
		draw_set_transform(Vector2(size.x * 0.5 + 5, size.y - 16), -PI * 0.5, Vector2.ONE)
		draw_string(f, Vector2.ZERO, String(rec["label"]) if has else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.07, 0.06))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if selected:
			draw_rect(r.grow(2), Color(0.95, 0.75, 0.4), false, 2.0)

## Вкладыш видеокассеты справа: бумага, полоса категории, печать состояния
class Sleeve extends Control:
	var ui
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.55))
		draw_colored_polygon(G67Diorama.paper_poly(r, 67, 1.5), Color(0.84, 0.79, 0.67))
		var cat := String(ui.s_cat.text)
		var cc: Color = G67ArchTV.CAT_COL.get(cat, Color(0.45, 0.4, 0.34))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 14)), cc)
		for y in [186.0, 226.0]:
			draw_line(Vector2(26, y), Vector2(size.x - 26, y), Color(0.2, 0.16, 0.12, 0.25), 1.0)
		var st := String(ui.s_state.text)
		if st != "":
			var col := Color(0.6, 0.14, 0.1) if st in ["НОВАЯ ЗАПИСЬ", "ЗАПИСЬ РАЗГОВОРА"] else Color(0.32, 0.3, 0.27)
			var f := MGUI.font("caps")
			var tw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_set_transform(Vector2(size.x - tw * 0.5 - 40, 214), -0.12, Vector2.ONE)
			draw_rect(Rect2(-tw * 0.5 - 10, -16, tw + 20, 30), Color(col, 0.85), false, 2.5)
			draw_string(f, Vector2(-tw * 0.5, 7), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Вкладыш кассеты для чтения разговора: картон, шапка с названием и катушки
class Card extends Control:
	var head := ""
	var krot := false
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.6))
		draw_colored_polygon(G67Diorama.paper_poly(r, 12, 1.5), Color(0.86, 0.82, 0.71))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 84)), Color(0.55, 0.6, 0.32) if krot else Color(0.3, 0.62, 0.6))
		for k in 2:
			var c := Vector2(size.x - 170 + k * 80, 42)
			draw_circle(c, 26, Color(0.1, 0.1, 0.1))
			draw_circle(c, 10, Color(0.86, 0.82, 0.71))
		var f := MGUI.font("display")
		draw_string(f, Vector2(40, 56), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 260, 28, Color(0.1, 0.09, 0.08))
		for y in range(110, int(size.y) - 20, 34):
			draw_line(Vector2(40, y), Vector2(size.x - 40, y), Color(0.2, 0.16, 0.12, 0.12), 1.0)
