class_name G67HubUI
extends CanvasLayer
## Экраны предметов подъезда «ГОЛДА 67» (этап 2): одна система на все — список слева, описание выбранного
## справа, клавиши внизу. W/S или стрелки — выбор, Enter / пробел / E — действие, Esc — назад или закрыть; мышь —
## наведение выбирает, клик выполняет. Пока экран открыт, ввод игры закрыт (Golda67.scene_busy).
## Экраны: archive (телевизор: ролики, КРОТ, DJ FLÜRR, события, концовки),
## styles (стойка стилей), artifacts (коллекция), routes (карта маршрутов), board (доска), mail (почтовые ящики).
## «АВТОРИТЕТ РАЙОНА» — свой экран G67AuthorityUI (g67_authority_ui.gd).
## Строка списка: {title, sub, tag, icon (Texture2D или id значка MGIcon), lock (bool), head (заголовок раздела),
## desc, act (Callable — действие; нет — строка только для чтения)}.

signal closed

const W := 1080.0
const H := 600.0

var G: Golda67
var kind := ""
var rows: Array = []
var sel := 0
var root: Control
var frame: PanelContainer
var title_l: Label
var sub_l: Label
var chip_box: HBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var d_icon: TextureRect
var d_title: Label
var d_desc: Label
var d_tag: Label
var hints_box: HBoxContainer
var back: Callable = Callable()
var voice: AudioStreamPlayer
var opened_ms := 0

static func open(g67: Golda67, what: String) -> G67HubUI:
	var u := G67HubUI.new()
	u.G = g67
	u.layer = 56
	u.process_mode = Node.PROCESS_MODE_ALWAYS
	g67.game.add_child(u)
	u._frame()
	u.show_kind(what)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	return u

func _frame() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	frame = MGUI.panel(false, MGUI.GOLD, MGUI.S5)
	frame.set_meta("audit_modal", true)
	center.add_child(frame)
	var vs := get_viewport().get_visible_rect().size
	frame.custom_minimum_size = Vector2(minf(W, vs.x - 48.0), minf(H, vs.y - 48.0))
	var col := MGUI.vbox(MGUI.S3)
	frame.add_child(col)
	var head := MGUI.hbox(MGUI.S3)
	col.add_child(head)
	var tcol := MGUI.vbox(MGUI.S1)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	title_l = MGUI.label("", "h1", MGUI.GOLD)
	tcol.add_child(title_l)
	sub_l = MGUI.label("", "small", MGUI.TEXT_2)
	tcol.add_child(sub_l)
	chip_box = MGUI.hbox(MGUI.S2)
	chip_box.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(chip_box)
	col.add_child(MGUI.hsep())
	var body := MGUI.hbox(MGUI.S5)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.15
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	list = MGUI.vbox(MGUI.S1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	body.add_child(MGUI.vsep())
	var det := MGUI.vbox(MGUI.S3)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(det)
	d_icon = TextureRect.new()
	d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	d_icon.custom_minimum_size = Vector2(150, 150)
	d_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	det.add_child(d_icon)
	d_title = MGUI.label("", "h2", MGUI.TEXT)
	d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(d_title)
	d_tag = MGUI.label("", "caps", MGUI.GOLD)
	det.add_child(d_tag)
	d_desc = MGUI.label("", "body", MGUI.TEXT_2)
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det.add_child(d_desc)
	col.add_child(MGUI.hsep())
	hints_box = MGUI.hbox(MGUI.S4)
	col.add_child(hints_box)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	opened_ms = GameClock.ms()

# ---------------------------------------------------------------- экраны
func show_kind(what: String) -> void:
	kind = what
	back = Callable()
	voice.stop()
	for c in chip_box.get_children():
		c.queue_free()
	match what:
		"styles": _styles()
		"artifacts": _artifacts()
		"routes": _routes()
	_rebuild()
	G.events.append(["hub_ui", what])

## Стойка стилей: с каким стилем выходить в забег; закрытые — когда откроются
func _styles() -> void:
	title_l.text = "СТОЙКА СТИЛЕЙ"
	sub_l.text = "с чем Пахан выходит во двор"
	rows = []
	var open: Array = G.styles_open()
	var cur: String = G.start_style()
	var when := {"bottles": "после победы над Мишей Минасяном", "tyaga812": "после победы над FORTUNA 812"}
	for sid in ["vozduh", "bottles", "tyaga812"]:
		var s: StyleData = Styles.by_id(sid)
		var ok := open.has(sid)
		rows.append({"title": s.title, "sub": s.note if ok else "откроется " + String(when.get(sid, "позже")),
			"tag": "В РУКАХ" if sid == cur else ("" if ok else "ЗАКРЫТО"), "lock": not ok,
			"desc": "%s.%s" % [_cap(s.note) if s.note != "" else s.title, "\nЭтот стиль будет в руках в начале забега." if sid == cur else ""],
			"act": (func(): _pick_style(sid)) if ok and sid != cur else Callable()})
	rows.append({"head": "MADK1D"})
	for sid in ["skateboard", "guitar", "breaker"]:
		var s2: StyleData = Styles.by_id(sid)
		rows.append({"title": s2.title, "sub": "после первой концовки", "tag": "ЗАКРЫТО", "lock": true,
			"desc": "Стили madk1d появятся на стойке, когда он сможет выйти в забег вместе с Паханом."})
	_hints([["W/S", "стиль"], ["Enter", "взять в забег"], ["Esc", "закрыть"]])

func _pick_style(sid: String) -> void:
	G.set_start_style(sid)
	G.game.main.ui("confirm")
	var keep := sel
	show_kind("styles")
	_select(keep)

## Коллекция артефактов: 18 мест; найденное — значок и описание, остальное — тёмный силуэт
func _artifacts() -> void:
	title_l.text = "КОЛЛЕКЦИЯ АРТЕФАКТОВ"
	var got: Array = G.meta().get("artifacts", [])
	sub_l.text = "найдено %d из %d · в забеге действуют весь забег" % [got.size(), G67Data.ARTIFACTS.size()]
	rows = []
	for a in G67Data.ARTIFACTS:
		var id := String(a["id"])
		var has := got.has(id)
		rows.append({"title": String(a["name"]) if has else "???", "sub": String(a["rar"]),
			"icon": G67Icons.tex("icon_art_" + id), "lock": not has, "dark": not has,
			"desc": String(a["desc"]) if has else "Пока не найден. Артефакты лежат в кладовках двора; событийные — только в своих событиях."})
	_hints([["W/S", "артефакт"], ["Esc", "закрыть"]])

## Карта маршрутов: районы линии 1, маршрут ДВОРА, где КРОТ
func _routes() -> void:
	title_l.text = "КАРТА МАРШРУТОВ"
	sub_l.text = "куда ведёт турнир"
	rows = []
	var fl: Dictionary = G.meta().get("flags", {})
	var prev_ok := true
	for d in G67Data.DISTRICT_LIST:
		var beaten := bool(fl.get(String(d["flag"]), false))
		var open := prev_ok
		rows.append({"title": String(d["name"]), "sub": "босс — " + String(d["boss"]),
			"tag": "ПРОЙДЕН" if beaten else ("ОТКРЫТ" if open else "ЗАКРЫТ"), "lock": not open,
			"icon": G67Icons.tex("icon_room_boss"),
			"desc": ("Район открыт. Выход — дверь подъезда." if open else "Откроется после победы над боссом прошлого района.") + ("\nБосс района побеждён." if beaten else "")})
		prev_ok = beaten
	rows.append({"head": "МАРШРУТ ДВОРА"})
	var route: Array = G67Data.DISTRICTS["dvor"]["route"]
	for i in route.size():
		var opts: Array = route[i]
		var parts: Array = []
		for o in opts:
			parts.append("%s · %s" % [String(G67Data.ROOM_NAMES[String(o["type"])]), String(G67Yard.ZONES[String(o["place"])]["name"])])
		rows.append({"title": "Позиция %d" % (i + 1), "sub": " / ".join(parts), "icon": G67Icons.room(String(opts[0]["type"])),
			"desc": ("На выбор: " if opts.size() > 1 else "") + " или ".join(parts) + "."})
	rows.append({"head": "КРОТ"})
	var k := G.krot_next()
	var seen: Array = G.meta().get("seen", [])
	rows.append({"title": "Найдено встреч: %d из %d" % [seen.size(), 10], "icon": G67Icons.tex("icon_krot_found"),
		"desc": ("Следующая встреча — «%s», %s." % [String(k["title"]), "в подъезде" if String(k["where"]) == "hub" else String(G67Yard.ZONES.get(String(k["where"]), {"name": "во дворе"})["name"])]) if not k.is_empty() else "Все известные встречи пройдены."})
	_hints([["W/S", "строка"], ["Esc", "закрыть"]])

# ---------------------------------------------------------------- список
func _rebuild() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var first := -1
	for i in rows.size():
		var r: Dictionary = rows[i]
		if r.has("head"):
			var hl := MGUI.label(String(r["head"]), "caps", MGUI.TEXT_3)
			list.add_child(hl)
			continue
		if first < 0:
			first = i
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_entered.connect(func(): _select(i))
		b.pressed.connect(func():
			_select(i)
			_activate())
		var h := MGUI.hbox(MGUI.S3)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 0)
		bar.color = Color(0, 0, 0, 0)
		bar.name = "bar"
		h.add_child(bar)
		var ic = r.get("icon", "")
		if ic is Texture2D:
			var tr := TextureRect.new()
			tr.texture = ic
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(42, 42)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if bool(r.get("dark", false)):
				tr.modulate = Color(0.3, 0.3, 0.33)
			h.add_child(tr)
		elif String(ic) != "":
			var mi = MGIcon.make(String(ic), 24, MGUI.TEXT_2)
			if mi != null:
				h.add_child(mi)
		var tc := MGUI.vbox(0)
		tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tc.alignment = BoxContainer.ALIGNMENT_CENTER
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tc)
		var t := MGUI.label(String(r.get("title", "")), "body", MGUI.TEXT_3 if bool(r.get("lock", false)) else MGUI.TEXT)
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tc.add_child(t)
		if String(r.get("sub", "")) != "":
			var s := MGUI.label(String(r["sub"]), "small", MGUI.TEXT_3)
			s.clip_text = true
			s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tc.add_child(s)
		if String(r.get("tag", "")) != "":
			h.add_child(MGUI.chip(String(r["tag"]), MGUI.GOLD if not bool(r.get("lock", false)) else MGUI.TEXT_3))
		r["node"] = b
		list.add_child(b)
	sel = -1
	_select(first if first >= 0 else 0)

func _select(i: int) -> void:
	if rows.is_empty():
		return
	i = clampi(i, 0, rows.size() - 1)
	if (rows[i] as Dictionary).has("head"):
		return
	if sel == i:
		return
	if sel >= 0 and sel < rows.size() and (rows[sel] as Dictionary).has("node"):
		var ob: Button = rows[sel]["node"]
		(ob.get_child(0).get_node("bar") as ColorRect).color = Color(0, 0, 0, 0)
	sel = i
	var r: Dictionary = rows[i]
	if r.has("node"):
		var nb: Button = r["node"]
		(nb.get_child(0).get_node("bar") as ColorRect).color = MGUI.GOLD
		scroll.ensure_control_visible(nb)
	var ic = r.get("icon", "")
	d_icon.texture = ic if ic is Texture2D else null
	d_icon.modulate = Color(0.3, 0.3, 0.33) if bool(r.get("dark", false)) else Color.WHITE
	d_icon.visible = d_icon.texture != null
	d_title.text = String(r.get("title", ""))
	d_tag.text = String(r.get("tag", ""))
	d_desc.text = String(r.get("desc", ""))
	G.game.main.ui("move", 1.0)

func _step(dir: int) -> void:
	var i := sel
	for n in rows.size():
		i = posmod(i + dir, rows.size())
		if not (rows[i] as Dictionary).has("head"):
			_select(i)
			return

func _activate() -> void:
	if sel < 0 or sel >= rows.size():
		return
	var act = rows[sel].get("act", Callable())
	if act is Callable and (act as Callable).is_valid():
		(act as Callable).call()
	else:
		G.game.main.ui("deny")

func _hints(pairs: Array) -> void:
	for c in hints_box.get_children():
		c.queue_free()
	hints_box.add_child(MGUI.hints(pairs))

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	get_viewport().set_input_as_handled()
	var k: int = e.physical_keycode
	if k in [KEY_E, KEY_ENTER, KEY_SPACE] and GameClock.ms() - opened_ms < 150:
		return                      # то же нажатие E, что открыло экран, — не действие
	if e.echo and not k in [KEY_W, KEY_S, KEY_UP, KEY_DOWN]:
		return
	match k:
		KEY_W, KEY_UP:
			_step(-1)
		KEY_S, KEY_DOWN:
			_step(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			_activate()
		KEY_ESCAPE, KEY_BACKSPACE:
			if back.is_valid():
				var b := back
				b.call()
				G.game.main.ui("back")
			else:
				close()

func close() -> void:
	if not is_inside_tree():
		return
	voice.stop()
	G.game.main.ui("close")
	MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	closed.emit()
	queue_free()

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
