## Интерфейс «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» в стиле GOD OF GRIMERKA (чёрные панели, рваные белые карточки, красные
## предупреждения, большие цифры долга) на столе 1600×900: HUD, уведомления телефона, экраны фаз дня, займы
## с мелким шрифтом, КАРТА ДОЛГОВ (граф займов: перетащи деньги на долг, выбери стратегию, посмотри последствия
## до подтверждения), вещи, магазин, события, звонки (переговоры), подработки (мини-игры), концовки, пауза.
class_name MLUI
extends CanvasLayer

const RED := Color(0.86, 0.09, 0.11)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const GREEN := Color(0.4, 0.9, 0.45)
const STAGE := Vector2(1600, 900)

var root                       # MicroloansRoot
var stage: Control
var font: Font
var serif: SystemFont
var hud := {}
var panel: Control             # открытый экран (слева)
var rows: Array = []           # [{label, act, ok}]
var sel := 0
var overlay: Control           # мини-игра или переговоры поверх всего
var notes_box: VBoxContainer
var screen := ""
var flow_sel: Array = []       # выбранные в карте долгов займы (для объединения)
var flow_focus := -1
var drag_money := false
var drag_pos := Vector2.ZERO
var pay_amount := 0
var flow_canvas: Control

func _ready() -> void:
	layer = 10
	font = load("res://assets/fonts/RussoOne-Regular.ttf")
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(stage)
	_hud()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	W = maxf(STAGE.x, vs.x / k)
	stage.scale = Vector2.ONE * k
	stage.size = Vector2(W, STAGE.y)
	stage.position = Vector2(0, (vs.y - STAGE.y * k) * 0.5)
	_layout()

func econ() -> MLEconomy:
	return root.econ

func txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else MGUI.font("ui"))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func torn(w: float, h: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, rng.randf_range(-4.0, 4.0)))
		x += rng.randf_range(10.0, 26.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + rng.randf_range(-8.0, 10.0), y))
		y += rng.randf_range(8.0, 16.0)
	x = w
	while x > 0.0:
		pts.append(Vector2(x, h + rng.randf_range(-4.0, 5.0)))
		x -= rng.randf_range(10.0, 26.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(rng.randf_range(-10.0, 6.0), y))
		y -= rng.randf_range(8.0, 16.0)
	return pts

static func rub(v: int) -> String:
	return MGUI.rub(v)

# ---------------- HUD ----------------
## Вёрстка — на дизайн-системе MGUI (mg_ui.gd), контейнерами. Сверху одна тонкая строка показателей: день и фаза,
## деньги, долг, ближайший платёж, стресс, действия, уровень. Слева — панель раздела (список или карточки), справа
## под строкой — уведомления телефона. Правая половина экрана остаётся комнате и Пахану.
var topbar: PanelContainer
var foot: HBoxContainer
var W := 1600.0                  # ширина стола интерфейса: на широком экране — больше 1600

func _hud() -> void:
	topbar = MGUI.panel(false, null, 0)
	var tsb := topbar.get_theme_stylebox("panel") as StyleBoxFlat
	tsb.content_margin_left = MGUI.S4
	tsb.content_margin_right = MGUI.S4
	tsb.content_margin_top = 6
	tsb.content_margin_bottom = 6
	stage.add_child(topbar)
	var row := MGUI.hbox(MGUI.S4)
	topbar.add_child(row)
	# день: «3 / 7», фаза, кружки дней
	var d := MGUI.stat("ДЕНЬ", "", "num")
	row.add_child(d["box"])
	hud["day"] = d["val"]
	var ph := MGUI.vbox(3)
	hud["phase"] = MGUI.label("", "caps", MGUI.RED)
	ph.add_child(hud["phase"])
	var pips := MGUI.hbox(3)
	hud["pips"] = []
	for k in MLData.DAYS:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(12, 4)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(c)
		(hud["pips"] as Array).append(c)
	ph.add_child(pips)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ph)
	row.add_child(MGUI.vsep())
	for key in ["money", "debt"]:
		var s := MGUI.stat("ДЕНЬГИ" if key == "money" else "ОБЩИЙ ДОЛГ", "", "num_l")
		(s["val"] as Label).custom_minimum_size.x = 170
		row.add_child(s["box"])
		hud[key] = s["val"]
		var dl := MGUI.label("", "small", MGUI.GOOD)
		dl.custom_minimum_size.x = 84
		dl.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(dl)
		hud[key + "_d"] = dl
		row.add_child(MGUI.vsep())
	var due := MGUI.stat("БЛИЖАЙШИЙ ПЛАТЁЖ", "", "num")
	(due["box"] as Control).custom_minimum_size.x = 250
	row.add_child(due["box"])
	hud["due_l"] = due["val"]
	hud["due_cap"] = due["cap"]
	row.add_child(MGUI.spacer())
	row.add_child(MGUI.vsep())
	var st := MGUI.vbox(4)
	hud["stress_n"] = MGUI.label("СТРЕСС", "caps")
	st.add_child(hud["stress_n"])
	hud["stress"] = MGUI.bar(130, 6)
	st.add_child(hud["stress"]["box"])
	hud["actions"] = MGUI.label("", "caps", MGUI.TEXT)
	st.add_child(hud["actions"])
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(st)
	row.add_child(MGUI.vsep())
	var lv := MGUI.vbox(4)
	hud["lvl"] = MGUI.label("", "caps_m", MGUI.GOLD)
	lv.add_child(hud["lvl"])
	hud["xp"] = MGUI.bar(150, 4, MGUI.GOLD)
	lv.add_child(hud["xp"]["box"])
	hud["pts"] = MGUI.label("", "micro")
	lv.add_child(hud["pts"])
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lv)
	notes_box = MGUI.vbox(MGUI.S2)
	stage.add_child(notes_box)
	_layout()

## расставить закреплённые части по ширине стола (после смены размера окна)
func _layout() -> void:
	if topbar == null:
		return
	topbar.position = Vector2(16, 12)
	topbar.size = Vector2(W - 32, 0)
	notes_box.position = Vector2(W - 16 - 310, 86)
	notes_box.custom_minimum_size = Vector2(310, 0)

var shown := {"money": 0.0, "debt": 0.0}       # что сейчас нарисовано (цифры доезжают)
var target := {"money": 0.0, "debt": 0.0}
var flash := {"money": 0.0, "debt": 0.0}
var first_refresh := true

func refresh() -> void:
	var e := econ()
	if e == null or hud.is_empty() or not is_instance_valid(hud["day"]):
		return
	hud["day"].text = "%d / %d" % [e.day, MLData.DAYS]
	hud["phase"].text = String(MLEconomy.PHASE_NAMES.get(e.phase, "")) + (" · ещё %d дн." % (MLData.DAYS - e.day) if e.day < MLData.DAYS else " · последний день")
	for k in MLData.DAYS:
		(hud["pips"][k] as ColorRect).color = MGUI.RED if k + 1 == e.day else (Color(0.5, 0.5, 0.52) if k + 1 < e.day else Color(0.2, 0.2, 0.22))
	for key in ["money", "debt"]:
		var nv := float(e.money if key == "money" else e.total_debt())
		if first_refresh:
			shown[key] = nv
		elif absf(nv - float(target[key])) > 0.5:
			var dlt := nv - float(target[key])
			var good := dlt > 0.0 if key == "money" else dlt < 0.0
			var dl: Label = hud[key + "_d"]
			dl.text = ("+" if dlt > 0 else "−") + rub(int(absf(dlt)))
			dl.add_theme_color_override("font_color", MGUI.GOOD if good else MGUI.RED)
			dl.modulate.a = 1.0
			dl.create_tween().tween_property(dl, "modulate:a", 0.0, 1.6).set_delay(1.4)
			flash[key] = 1.0 if good else -1.0
		target[key] = nv
	first_refresh = false
	var stv := float(e.stress) / 100.0
	MGUI.set_bar(hud["stress"], stv, MGUI.GOOD.lerp(MGUI.WARN, clampf(stv * 2.0, 0.0, 1.0)).lerp(MGUI.RED, clampf(stv * 2.0 - 1.0, 0.0, 1.0)))
	hud["stress_n"].text = "СТРЕСС %d%s" % [e.stress, " · −1 действие" if e.stress >= 80 else ""]
	hud["actions"].text = "ДЕЙСТВИЯ " + "●".repeat(maxi(0, e.actions)) + "○".repeat(maxi(0, e.actions_max() - e.actions))
	# ближайший платёж
	var near: Dictionary = {}
	for L in e.active():
		if near.is_empty() or int(L["due"]) < int(near["due"]):
			near = L
	due_hot = false
	if near.is_empty():
		hud["due_l"].text = "долгов нет"
		hud["due_cap"].text = "БЛИЖАЙШИЙ ПЛАТЁЖ"
		hud["due_cap"].add_theme_color_override("font_color", MGUI.GOOD)
	else:
		var D: Dictionary = MLData.LENDERS[near["lender"]]
		var dd := int(near["due"]) - e.day
		var when := "просрочен %d дн." % int(near["overdue"]) if near["status"] == "overdue" else ("сегодня" if dd <= 0 else ("завтра" if dd == 1 else "через %d дн." % dd))
		hud["due_l"].text = "%s · %s" % [D["short"], rub(int(ceil(float(near["balance"]))))]
		hud["due_cap"].text = "БЛИЖАЙШИЙ ПЛАТЁЖ · " + when.to_upper()
		due_hot = dd <= 1 or near["status"] == "overdue"
		hud["due_cap"].add_theme_color_override("font_color", MGUI.RED if due_hot else (MGUI.WARN if dd == 2 else MGUI.TEXT_3))
	if e.career != null:
		var C: MLCareer = e.career
		hud["lvl"].text = "ПАХАН · УР. %d · НЕД. %d" % [int(C.d["level"]), int(C.d["week"])]
		MGUI.set_bar(hud["xp"], float(C.d["xp"]) / float(MLCareer.xp_need(int(C.d["level"]))))
		hud["pts"].text = ("очков навыков: %d — клавиша T" % int(C.d["points"])) if int(C.d["points"]) > 0 else "опыт %d / %d" % [int(C.d["xp"]), MLCareer.xp_need(int(C.d["level"]))]
		hud["pts"].add_theme_color_override("font_color", MGUI.GOLD if int(C.d["points"]) > 0 else MGUI.TEXT_3)
	if e.ending != "" and screen != "ending":
		ending()
	elif panel != null and rows.size() > 0:
		_paint()

var due_hot := false
## каждый кадр: цифры денег и долга доезжают до нужных, вспышка цвета гаснет, срочный платёж мягко пульсирует
func _process(dt: float) -> void:
	if hud.is_empty():
		return
	for key in ["money", "debt"]:
		var cur := float(shown[key])
		var tg := float(target[key])
		cur = move_toward(cur, tg, maxf(absf(tg - cur) * 6.0 * dt, 400.0 * dt))
		shown[key] = cur
		var l: Label = hud[key]
		l.text = rub(int(round(cur)))
		var base := MGUI.TEXT if key == "money" else MGUI.RED
		var fk := float(flash[key])
		if absf(fk) > 0.01:
			l.add_theme_color_override("font_color", base.lerp(MGUI.GOOD if fk > 0 else Color(1, 0.35, 0.25), absf(fk)))
			flash[key] = move_toward(fk, 0.0, dt * 1.2)
		else:
			l.add_theme_color_override("font_color", base)
	(hud["due_l"] as Label).modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006) if due_hot else 1.0
	# поверх идёт подработка или звонок — у них свой экран: строка показателей и уведомления не мешают
	var busy := overlay != null and is_instance_valid(overlay)
	topbar.visible = not busy
	notes_box.visible = not busy and not (screen in ["flow", "tree"])

## уведомление телефона: узкая карточка со значком и названием приложения; выезжает справа, само уходит
const APPS := {"bad": ["warn", "СРОКИ", MGUI.RED], "warn": ["clock", "НАПОМИНАНИЕ", MGUI.WARN], "money": ["coin", "ПЕРЕВОДЫ", MGUI.GOOD],
	"level": ["star", "РАЗВИТИЕ", MGUI.GOLD], "milestone": ["trophy", "ВЕХА", Color(0.8, 0.6, 1.0)], "call": ["call", "ЗВОНОК", Color(0.55, 0.85, 1.0)], "info": ["mail", "СООБЩЕНИЕ", MGUI.TEXT_2]}
var toast_slot: Label            # экран во всю ширину (карта долгов, дерево): место уведомления в его шапке
var toast_tw: Tween

## место под уведомление в шапке широкого экрана: две строки, справа, перед кнопками
func make_toast_slot() -> Label:
	toast_slot = MGUI.label("", "small", MGUI.TEXT, 380.0)
	toast_slot.max_lines_visible = 2
	toast_slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toast_slot.custom_minimum_size.y = 40
	toast_slot.set_meta("audit_clip", true)
	toast_slot.modulate.a = 0.0
	return toast_slot

func notify(text: String, kind: String) -> void:
	var app: Array = APPS.get(kind, APPS["info"])
	var col: Color = app[2]
	if kind in ["level", "milestone"]:
		_banner(text, col)
	if toast_slot != null and is_instance_valid(toast_slot) and toast_slot.is_visible_in_tree():
		toast_slot.text = MGUI.nb("%s · %s" % [app[1], text])
		toast_slot.add_theme_color_override("font_color", col.lerp(MGUI.TEXT, 0.35))
		if toast_tw != null and toast_tw.is_valid():
			toast_tw.kill()
		toast_tw = toast_slot.create_tween()
		toast_tw.tween_property(toast_slot, "modulate:a", 1.0, 0.15)
		toast_tw.tween_interval(3.6)
		toast_tw.tween_property(toast_slot, "modulate:a", 0.0, 0.4)
		return
	var card := MGUI.panel(false, col, MGUI.S2)
	var box := MGUI.hbox(MGUI.S2)
	card.add_child(box)
	var ic := MGIcon.make(String(app[0]), 20, col)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(ic)
	var v := MGUI.vbox(1)
	box.add_child(v)
	v.add_child(MGUI.label(String(app[1]), "caps", col))
	v.add_child(MGUI.label(MGUI.nb(text), "small", MGUI.TEXT, 252.0))
	notes_box.add_child(card)
	notes_box.move_child(card, 0)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_interval(5.0 if kind in ["level", "milestone", "bad"] else 3.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.45)
	tw.tween_callback(card.queue_free)
	while notes_box.get_child_count() > 3:
		var c := notes_box.get_child(notes_box.get_child_count() - 1)
		notes_box.remove_child(c)
		c.queue_free()

## крупная строка по центру — только для редких событий (новый уровень, веха); 2 секунды
func _banner(text: String, col: Color) -> void:
	var b := MGUI.label_3d(text, "h1", col)
	b.set_meta("audit_skip", true)
	b.position = Vector2(0, 400)
	b.size = Vector2(W, 44)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(b)
	b.modulate.a = 0.0
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)
	root.snd.play("cheer")

# ---------------- 3D-превью предметов (для карточек) ----------------
var thumbs := {}
## маленькая картинка модели: свой SubViewport рисует один раз, потом картинка живёт в текстуре
func thumb(id: String) -> Texture2D:
	if thumbs.has(id):
		return thumbs[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(288, 192)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var r := Node3D.new()
	vp.add_child(r)
	var hold := Node3D.new()
	r.add_child(hold)
	var span := MLThumbs.build(id, hold)
	var boxes: Array = []
	MGModels._walk(hold, Transform3D.IDENTITY, boxes)
	var mid := Vector3(0, span * 0.22, 0)
	if not boxes.is_empty():
		var bb: AABB = boxes[0]
		for k in range(1, boxes.size()):
			bb = bb.merge(boxes[k])
		span = maxf(0.08, maxf(bb.size.x, maxf(bb.size.y * 1.25, bb.size.z)) * 1.12)
		mid = bb.get_center()
	var cam := Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	cam.look_at_from_position(mid + Vector3(span * 0.85, span * 0.62, span * 1.45), mid, Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 2.0
	vp.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-span, span, span)
	fill.light_energy = 1.2
	fill.omni_range = span * 6.0
	vp.add_child(fill)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_CLEAR_COLOR
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color(0.8, 0.8, 0.85)
	en.ambient_light_energy = 1.0
	env.environment = en
	vp.add_child(env)
	thumbs[id] = vp.get_texture()
	return thumbs[id]

# ---------------- экран раздела ----------------
## items: [текст, действие, почему нельзя (Callable) или пусто, свойства {icon, thumb, sub, value, tag, col}]
## mode: "list" — компактный список (значок, название, значение справа); "cards" — пункты с thumb становятся
## карточками с картинкой (сравнивать варианты: подработки, магазин, бизнес), остальные — строками под ними;
## "grid" — сетка ячеек с картинками (вещи). Описание (sub) показывается только у выбранного пункта — внизу панели.
var cols := 1
var card_n := 0                 # сколько первых пунктов — карточки (сетка), дальше — строки
var detail_l: Label
var detail_t: TextureRect
func open(title: String, lines: Array, items: Array, _w := 760.0, mode := "list") -> Control:
	close_panel()
	var pw := 520.0 if mode == "list" else 760.0
	panel = Control.new()
	panel.size = Vector2(W, STAGE.y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var pc := MGUI.panel(false, null, MGUI.S4)
	pc.position = Vector2(16, 86)
	pc.custom_minimum_size = Vector2(pw, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(pc)
	var v := MGUI.vbox(MGUI.S3)
	pc.add_child(v)
	var head := MGUI.vbox(MGUI.S1)
	v.add_child(head)
	var tl := MGUI.label(title, "h1", null, pw - 2.0 * MGUI.S4)
	tl.max_lines_visible = 2
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.set_meta("audit_clip", true)
	head.add_child(tl)
	var rule := ColorRect.new()
	rule.color = MGUI.RED
	rule.custom_minimum_size = Vector2(56, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	if not lines.is_empty():
		var info := MGUI.vbox(2)
		v.add_child(info)
		for s in lines:
			if String(s) != "":
				info.add_child(MGUI.label(MGUI.nb(String(s)), "small", MGUI.TEXT_2, pw - 2.0 * MGUI.S4))
	rows = []
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme = MGUI.theme()
	v.add_child(scroll)
	var body := MGUI.vbox(MGUI.S2)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var cardable := func(it: Array) -> bool: return mode != "list" and it.size() > 3 and it[3] is Dictionary and (it[3] as Dictionary).has("thumb")
	var grid := GridContainer.new()
	var cw := 168.0 if mode == "cards" else 104.0
	cols = maxi(1, int((pw - 2.0 * MGUI.S4 - 10.0 + MGUI.S2) / (cw + MGUI.S2)))
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", MGUI.S2)
	grid.add_theme_constant_override("v_separation", MGUI.S2)
	card_n = 0
	if items.any(cardable):
		body.add_child(grid)
	else:
		cols = 1
	var list := MGUI.vbox(3)
	body.add_child(list)
	for it in items:
		var i := rows.size()
		var spec: Dictionary = it[3] if it.size() > 3 and it[3] is Dictionary else {}
		var is_card: bool = cardable.call(it)
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bsb := MGUI.box(Color(0.09, 0.09, 0.105), 3, 0, MGUI.LINE, 0)
		box.add_theme_stylebox_override("panel", bsb)
		var lab := MGUI.label("", "body_b")
		var parts := {}
		if is_card:
			card_n += 1
			bsb.set_content_margin_all(MGUI.S2)
			bsb.set_border_width_all(2)
			box.custom_minimum_size = Vector2(cw, 0)
			var cv := MGUI.vbox(MGUI.S1)
			box.add_child(cv)
			var tr := TextureRect.new()
			tr.texture = thumb(String(spec["thumb"]))
			tr.custom_minimum_size = Vector2(cw - 2.0 * MGUI.S2, 88 if mode == "cards" else 66)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_child(tr)
			if mode == "cards":
				lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lab.custom_minimum_size = Vector2(cw - 2.0 * MGUI.S2, 0)
				MGUI.style_label(lab, "caps_m")
				cv.add_child(lab)
				var val := MGUI.label("", "num")
				cv.add_child(val)
				parts["val"] = val
				var tag := MGUI.label("", "micro")
				tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tag.custom_minimum_size = Vector2(cw - 2.0 * MGUI.S2, 0)
				cv.add_child(tag)
				parts["tag"] = tag
			else:
				lab.visible = false                      # в сетке вещей название — только у выбранной, внизу
				cv.add_child(lab)
			grid.add_child(box)
		else:
			bsb.content_margin_left = MGUI.S3
			bsb.content_margin_right = MGUI.S3
			bsb.content_margin_top = 7
			bsb.content_margin_bottom = 8
			bsb.border_width_left = 3
			var h := MGUI.hbox(MGUI.S3)
			box.add_child(h)
			if spec.has("icon"):
				var ic := MGIcon.make(String(spec["icon"]), 18, MGUI.TEXT_2)
				ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(ic)
				parts["icon"] = ic
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.custom_minimum_size.x = 120
			h.add_child(lab)
			var val2 := MGUI.label("", "small")
			val2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			val2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val2.set_meta("audit_clip", true)
			h.add_child(val2)
			parts["val"] = val2
			list.add_child(box)
		rows.append({"label": lab, "text": it[0], "act": it[1], "why": it[2] if it.size() > 2 and it[2] is Callable else Callable(), "box": box, "sb": bsb, "spec": spec, "parts": parts, "card": is_card})
		box.mouse_entered.connect(func(): _select(i))
		box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
				_activate())
	# подробности выбранного пункта: описание и (в сетке вещей) название; высота постоянная — панель не прыгает
	v.add_child(MGUI.hsep())
	var det := MGUI.hbox(MGUI.S3)
	det.custom_minimum_size.y = 80
	v.add_child(det)
	detail_l = MGUI.label("", "small", MGUI.TEXT_2, pw - 2.0 * MGUI.S4 - (112.0 if mode == "list" else 0.0))
	detail_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_l.max_lines_visible = 4
	detail_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_l.set_meta("audit_clip", true)
	det.add_child(detail_l)
	detail_t = TextureRect.new()
	detail_t.custom_minimum_size = Vector2(100, 58)
	detail_t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_t.visible = mode == "list"
	det.add_child(detail_t)
	v.add_child(MGUI.hints([["W/S", "выбор"], ["Enter", "открыть"], ["Esc", "назад"]] if cols == 1 else [["WASD", "выбор"], ["Enter", "открыть"], ["Esc", "назад"]]))
	_fit_scroll.call_deferred(v, scroll, body)
	pc.modulate.a = 0.0
	pc.create_tween().tween_property(pc, "modulate:a", 1.0, 0.14)
	root.snd.play("open")
	sel = 0
	_paint()
	return panel

## высота списка: по содержимому, но не ниже края экрана (дальше — прокрутка)
func _fit_scroll(v: VBoxContainer, scroll: ScrollContainer, body: Control) -> void:
	if not is_instance_valid(scroll):
		return
	var fixed := v.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y + 2.0 * MGUI.S4
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, STAGE.y - 86.0 - 16.0 - fixed)

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	rows = []

func _select(i: int) -> void:
	if rows.is_empty():
		return
	if posmod(i, rows.size()) != sel:
		root.snd.play("move")
	sel = posmod(i, rows.size())
	_paint()
	var b: Control = rows[sel]["box"]
	var p := b.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		(p as ScrollContainer).ensure_control_visible.call_deferred(b)

func _why(r: Dictionary) -> String:
	var w = r["why"]
	return String(w.call()) if w is Callable and (w as Callable).is_valid() else ""

func _paint() -> void:
	for k in rows.size():
		var r: Dictionary = rows[k]
		var tx = r["text"]
		var s: String = String(tx.call()) if tx is Callable else String(tx)
		var why := _why(r)
		var on := k == sel
		var spec: Dictionary = r["spec"]
		var acc: Color = spec.get("col", MGUI.RED)
		var sb: StyleBoxFlat = r["sb"]
		var lab: Label = r["label"]
		var parts: Dictionary = r["parts"]
		lab.text = s
		if bool(r["card"]):
			# карточка: бумага; выбранная — красная рамка; недоступная — тусклая, причина вместо метки
			sb.bg_color = MGUI.PAPER if why == "" else MGUI.PAPER_DIM
			sb.border_color = MGUI.RED if on else Color(0, 0, 0, 0)
			lab.add_theme_color_override("font_color", MGUI.INK)
			if parts.has("val"):
				(parts["val"] as Label).text = _sv(spec.get("value", ""))
				(parts["val"] as Label).add_theme_color_override("font_color", acc.darkened(0.45) if why == "" else Color(0.2, 0.2, 0.22))
				(parts["tag"] as Label).text = why if why != "" else _sv(spec.get("tag", ""))
				(parts["tag"] as Label).add_theme_color_override("font_color", Color(0.55, 0.05, 0.06) if why != "" else Color(0.3, 0.3, 0.32))
		else:
			# строка: тёмная; выбранная — бумага с чернилами и красной полосой; недоступная — серая, причина справа
			sb.bg_color = MGUI.PAPER if on else Color(0.09, 0.09, 0.105)
			sb.border_color = MGUI.RED if on else (acc if why == "" and not spec.is_empty() else MGUI.LINE)
			lab.add_theme_color_override("font_color", (MGUI.INK if on else MGUI.TEXT) if why == "" else (Color(0.3, 0.3, 0.32) if on else MGUI.TEXT_3))
			var vl: Label = parts["val"]
			var vt: String = why if why != "" else _sv(spec.get("value", ""))
			vl.text = vt
			# длинное значение не выдавливает название: обрезается с многоточием (целиком — в подробностях внизу)
			var long_v := vt.length() > 22
			vl.clip_text = long_v
			vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if long_v else TextServer.OVERRUN_NO_TRIMMING
			vl.custom_minimum_size.x = 170.0 if long_v else 0.0
			vl.add_theme_color_override("font_color", (Color(0.55, 0.05, 0.06) if on else MGUI.RED) if why != "" else (Color(0.25, 0.25, 0.27) if on else MGUI.TEXT_2))
			if parts.has("icon"):
				(parts["icon"] as MGIcon).set_icon(String(spec["icon"]), (MGUI.INK if on else MGUI.TEXT_2) if why == "" else MGUI.TEXT_3)
		if on and detail_l != null and is_instance_valid(detail_l):
			var sub := _sv(spec.get("sub", ""))
			var in_cell: bool = bool(r["card"]) and not lab.visible       # ячейка сетки: название — только здесь, внизу
			if sub != "":
				sub = (sub.left(1).to_lower() if in_cell else sub.left(1).to_upper()) + sub.substr(1)
			var dt: String = (s + " — " + sub if in_cell else sub) if sub != "" else (s if in_cell else "")
			if bool(r["card"]) and not lab.visible and _sv(spec.get("value", "")) != "":
				dt += "\nEnter — " + _sv(spec.get("value", ""))
			if why != "":
				dt = ("Нельзя: " + why + ". " + dt) if dt != "" else why
			detail_l.text = MGUI.nb(dt)
			if detail_t.visible:
				detail_t.texture = thumb(String(spec["thumb"])) if spec.has("thumb") else null

func _activate() -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	if _why(r) != "":
		root.snd.play("fail")
		var b: Control = r["box"]
		b.modulate = Color(1.0, 0.6, 0.6)
		b.create_tween().tween_property(b, "modulate", Color.WHITE, 0.25)
		return
	root.snd.play("ok")
	(r["act"] as Callable).call()

func _unhandled_input(e: InputEvent) -> void:
	if overlay != null or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if screen == "flow" and _flow_keys(k):
		get_viewport().set_input_as_handled()
		return
	if screen == "tree" and tree_ui != null and tree_ui.key(k):
		get_viewport().set_input_as_handled()
		return
	var in_grid := sel < card_n and cols > 1
	if k == KEY_W or k == KEY_UP:
		if in_grid:
			_select(sel - cols if sel - cols >= 0 else sel)
		else:
			_select(sel - 1)
	elif k == KEY_S or k == KEY_DOWN:
		_select(mini(sel + cols, card_n) if in_grid else sel + 1)
	elif (k == KEY_A or k == KEY_LEFT) and in_grid:
		_select(sel - 1)
	elif (k == KEY_D or k == KEY_RIGHT) and in_grid:
		_select(sel + 1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_activate()
	elif k == KEY_T and screen in ["morning", "day", "evening"]:
		dev_tree()
	elif k == KEY_ESCAPE:
		if screen in ["offers", "flow", "items", "shop", "jobs", "biz", "tree", "legend"]:
			show_phase()
		elif screen != "ending":
			pause_menu()
	else:
		return
	get_viewport().set_input_as_handled()

## значение свойства: строка или Callable, который её возвращает
func _sv(v) -> String:
	return String(v.call()) if v is Callable else String(v)

# ---------------- фазы ----------------
func intro() -> void:
	notify("Пахан, твои займы на %s. Через 7 дней приходят коллекторы." % rub(econ().total_debt()), "bad")

var last_phase := ""
func show_phase() -> void:
	var e := econ()
	if e.ending != "":
		ending()
		return
	if e.phase != last_phase:
		if last_phase != "":
			root.snd.play("phase")
		last_phase = e.phase
	screen = e.phase
	match e.phase:
		"morning":
			_morning()
		"day":
			_day()
		"evening":
			_evening()
	root.save()

func _morning() -> void:
	var e := econ()
	var lines: Array = ["Пахан проснулся. Телефон уже гудит."]
	for L in e.active():
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var d: int = int(L["due"]) - e.day
		lines.append("%s · %s · %s" % [D["short"], rub(int(ceil(L["balance"]))), "ПРОСРОЧЕН %d дн." % int(L["overdue"]) if L["status"] == "overdue" else ("срок СЕГОДНЯ" if d <= 0 else "срок через %d дн." % d)])
	var items: Array = []
	if e.event_today != "" and not e.event_done:
		var E: Dictionary = MLData.EVENTS[e.event_today]
		lines.append("Событие: " + String(E["title"]) + ".")
		for c in (E["choices"] as Array).size():
			var cc := c
			items.append([String(E["choices"][c][0]).to_upper(), func():
				var r := e.resolve_event(cc)
				if r.has("fail"):
					notify(String(r["fail"]), "bad")
					return
				if r.has("talk"):
					var cl := e.active().filter(func(L): return L["status"] == "overdue")
					if not cl.is_empty():
						negotiate(int(cl[0]["id"]), func(): show_phase())
						return
				show_phase(), Callable(), {"icon": "mail", "sub": String(E["text"]), "value": ""}])
	else:
		items.append(["НАЧАТЬ ДЕНЬ", func():
			e.next_phase()
			show_phase(), Callable(), {"icon": "sun", "sub": "три действия: подработки, займы, платежи, отдых", "value": "дальше", "col": MGUI.GOLD}])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow(), Callable(), {"icon": "map", "sub": "платежи, продление, рефинансирование", "value": func(): return rub(e.total_debt()), "col": RED}])
	open("УТРО · ДЕНЬ %d" % e.day, lines, items)

func _evening() -> void:
	var e := econ()
	var calls := e.callers()
	var lines: Array = ["Вечер. Звонят те, у кого срок завтра или уже прошёл."] if not calls.is_empty() else ["Вечер. Телефон молчит — подозрительно."]
	var items: Array = []
	for L in calls:
		var id := int(L["id"])
		if int(L.get("called", -1)) == e.day:
			continue
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		items.append(["ОТВЕТИТЬ: %s" % D["short"], func():
			L["called"] = e.day
			negotiate(id, func(): show_phase()), Callable(), {"icon": "call", "sub": "%s звонит по долгу. Переговоры: можно выбить отсрочку или скидку." % D["name"], "value": rub(int(ceil(L["balance"]))), "col": Color(0.55, 0.85, 1.0)}])
		items.append(["СБРОСИТЬ: %s" % D["short"], func():
			L["called"] = e.day
			e.stress = clampi(e.stress + 8, 0, 100)
			e.rep = clampi(e.rep - 2, 0, 100)
			e.say("Сбросил звонок %s. Перезвонят." % D["short"], "bad")
			show_phase(), Callable(), {"icon": "cross", "sub": "Не брать трубку: стресс растёт, репутация падает, перезвонят.", "value": "+8 стресса", "col": GREY}])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow(), Callable(), {"icon": "map", "sub": "заплатить до ночи — меньше процентов и штрафов", "value": func(): return rub(e.total_debt()), "col": RED}])
	items.append(["СПАТЬ", func():
		e.next_phase()
		show_phase(), Callable(), {"icon": "moon", "sub": "ночью начислятся проценты и штрафы, придёт выручка бизнесов", "value": "ночь", "col": Color(0.85, 0.5, 0.9)}])
	open("ВЕЧЕР · ДЕНЬ %d" % e.day, lines, items)
	if not calls.is_empty():
		root.react("call")

# ---------------- карта долгов ----------------
## Граф: займы — узлы по дням срока (слева направо) и конторам (сверху вниз), рефинансирование — линии
## от закрытых к новому. Внизу — деньги: перетащи их на долг — откроется платёж. Справа — выбранный долг:
## условия и действия с последствиями. Вёрстка — MGUI: шапка, карта + панель подробностей, строка клавиш.
const FLOW_NODE := Vector2(150, 46)
const FLOW_LEFT := 96.0          # место под названия контор
const FLOW_TOP := 34.0
const FLOW_BOTTOM := 66.0        # полоса с деньгами
var flow_side: VBoxContainer

func debt_flow() -> void:
	screen = "flow"
	close_panel()
	panel = Control.new()
	panel.size = Vector2(W, STAGE.y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var pc := MGUI.panel(false, null, MGUI.S4)
	pc.position = Vector2(16, 86)
	pc.custom_minimum_size = Vector2(W - 32, STAGE.y - 86 - 16)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(pc)
	var v := MGUI.vbox(MGUI.S3)
	pc.add_child(v)
	var top := MGUI.hbox(MGUI.S4)
	v.add_child(top)
	var tl := MGUI.vbox(MGUI.S1)
	top.add_child(tl)
	tl.add_child(MGUI.label("КАРТА ДОЛГОВ", "h1"))
	tl.add_child(MGUI.label("Слева направо — дни до срока, сверху вниз — конторы. Перетащи деньги на долг, чтобы заплатить.", "small"))
	top.add_child(MGUI.spacer())
	top.add_child(make_toast_slot())
	var back := MGUI.button("НАЗАД")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): show_phase())
	top.add_child(back)
	v.add_child(MGUI.hsep())
	var mid := MGUI.hbox(MGUI.S4)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	flow_canvas = Control.new()
	flow_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_canvas.custom_minimum_size = Vector2(0, 520)
	flow_canvas.clip_contents = true
	flow_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	mid.add_child(flow_canvas)
	flow_canvas.draw.connect(_flow_draw)
	flow_canvas.gui_input.connect(_flow_input)
	flow_canvas.resized.connect(flow_canvas.queue_redraw)
	var det := MGUI.panel(false, MGUI.RED, MGUI.S4)
	det.custom_minimum_size = Vector2(360, 0)
	mid.add_child(det)
	flow_side = MGUI.vbox(MGUI.S2)
	det.add_child(flow_side)
	v.add_child(MGUI.hsep())
	v.add_child(MGUI.hints([["W/S", "долг"], ["Q", "самый дорогой"], ["E", "самый срочный"], ["A/D", "сумма"], ["Enter", "оплатить"], ["Shift+клик", "отметить"], ["Esc", "назад"]]))
	if (flow_focus < 0 or econ().loan(flow_focus).is_empty() or econ().loan(flow_focus)["status"] == "closed") and not econ().active().is_empty():
		flow_focus = int(econ().active()[0]["id"])
	pay_amount = 0
	_flow_side()

## шаг сетки карты: по ширине — дни (9 столбцов), по высоте — конторы
func _flow_step() -> Vector2:
	var cs := flow_canvas.size if flow_canvas != null and is_instance_valid(flow_canvas) and flow_canvas.size.x > 200.0 else Vector2(1150, 600)
	return Vector2((cs.x - FLOW_LEFT - FLOW_NODE.x - 6.0) / 8.0, (cs.y - FLOW_TOP - FLOW_BOTTOM) / float(maxi(1, MLData.LENDER_ORDER.size())))

## где стоит узел долга (прямоугольник на карте); долги одной конторы с близкими сроками встают друг под другом
func _node_rect(L: Dictionary) -> Rect2:
	var e := econ()
	var st := _flow_step()
	var lane := MLData.LENDER_ORDER.find(String(L["lender"]))
	var col := func(o: Dictionary) -> float: return clampf(float(int(o["due"]) - e.day + 1), 0.0, 8.0)
	var mates: Array = e.loans.filter(func(o): return o["lender"] == L["lender"] and o["status"] != "closed")
	mates.sort_custom(func(p, q): return int(p["due"]) < int(q["due"]) if int(p["due"]) != int(q["due"]) else int(p["id"]) < int(q["id"]))
	var rows: Array = []                      # ряд → столбцы занятых узлов
	var my_row := 0
	for o in mates:
		var cx: float = col.call(o) * st.x
		var r := 0
		while r < rows.size() and (rows[r] as Array).any(func(x): return absf(float(x) - cx) < FLOW_NODE.x + 6.0):
			r += 1
		if r == rows.size():
			rows.append([])
		(rows[r] as Array).append(cx)
		if int(o["id"]) == int(L["id"]):
			my_row = r
			break
	var sub := minf(FLOW_NODE.y + 6.0, (st.y - 10.0) / float(maxi(1, my_row + 1)))
	return Rect2(Vector2(FLOW_LEFT + col.call(L) * st.x, FLOW_TOP + 10.0 + lane * st.y + my_row * sub), FLOW_NODE)

func _node_pos(L: Dictionary) -> Vector2:
	return _node_rect(L).get_center()

func _money_rect() -> Rect2:
	var cs := flow_canvas.size
	return Rect2(Vector2(cs.x * 0.5 - 85.0, cs.y - 50.0), Vector2(170, 40))

func _flow_draw() -> void:
	var e := econ()
	var c := flow_canvas
	var st := _flow_step()
	var f_caps := MGUI.font("caps")
	var f_ui := MGUI.font("ui")
	var f_num := MGUI.font("display")
	var bottom := c.size.y - FLOW_BOTTOM
	# дни: столбцы; «сегодня» подсвечен, «просрочено» — красным
	for d in 9:
		var x := FLOW_LEFT + d * st.x
		var day := e.day + d - 1
		if d == 1:
			c.draw_rect(Rect2(x - 5, FLOW_TOP - 6, st.x, bottom - FLOW_TOP + 6), Color(1, 1, 1, 0.04))
		elif d == 0:
			c.draw_rect(Rect2(x - 5, FLOW_TOP - 6, st.x, bottom - FLOW_TOP + 6), Color(0.86, 0.09, 0.11, 0.07))
		c.draw_line(Vector2(x - 5, FLOW_TOP - 6), Vector2(x - 5, bottom), Color(1, 1, 1, 0.07), 1.0)
		var cap := "СЕГОДНЯ" if d == 1 else ("ПРОСРОЧЕНО" if d == 0 else "ДЕНЬ %d" % day)
		c.draw_string(f_caps, Vector2(x, 16), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, MGUI.MICRO, MGUI.RED if d == 0 else (MGUI.TEXT if d == 1 or day == MLData.DAYS else MGUI.TEXT_3))
	for lane in MLData.LENDER_ORDER.size():
		var D: Dictionary = MLData.LENDERS[MLData.LENDER_ORDER[lane]]
		var y := FLOW_TOP + lane * st.y
		c.draw_line(Vector2(0, y), Vector2(c.size.x, y), Color(1, 1, 1, 0.07), 1.0)
		c.draw_string(f_caps, Vector2(0, y + 28), String(D["short"]), HORIZONTAL_ALIGNMENT_LEFT, FLOW_LEFT - 10.0, MGUI.MICRO, D["col"])
	c.draw_line(Vector2(0, bottom), Vector2(c.size.x, bottom), Color(1, 1, 1, 0.07), 1.0)
	# связи рефинансирования
	for L in e.loans:
		if L.has("from") and L["status"] != "closed":
			for fid in L["from"]:
				var F := e.loan(int(fid))
				if not F.is_empty():
					var to := _node_rect(L)
					var a := _node_rect(F).get_center() if F["status"] != "closed" else Vector2(FLOW_LEFT - 20.0, to.get_center().y)
					c.draw_line(a, Vector2(to.position.x, to.get_center().y), Color(1, 0.75, 0.3, 0.55), 2.0, true)
	# узлы: полоса цвета конторы слева, остаток, ставка и штраф; выбранный — светлая рамка, отмеченные — золотая
	for L in e.active():
		var r := _node_rect(L)
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var focus: bool = int(L["id"]) == flow_focus
		var over: bool = L["status"] == "overdue"
		c.draw_rect(r, Color(0.2, 0.06, 0.07) if over else Color(0.1, 0.1, 0.115))
		c.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), MGUI.RED if over else (D["col"] as Color))
		if focus:
			c.draw_rect(r, MGUI.PAPER, false, 2.0)
		if flow_sel.has(int(L["id"])):
			c.draw_rect(r.grow(4), MGUI.GOLD, false, 2.0)
		c.draw_string(f_num, r.position + Vector2(12, 20), rub(int(ceil(L["balance"]))), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 17, MGUI.TEXT)
		c.draw_string(f_ui, r.position + Vector2(12, 38), "%.1f %% · штраф %.0f %%" % [float(L["rate"]) * 100.0, float(L["fine"]) * 100.0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, MGUI.MICRO, MGUI.TEXT_2)
	# деньги: пачка внизу по центру (или под курсором, пока тащат)
	var mr := _money_rect()
	c.draw_string(f_caps, Vector2(mr.position.x - 250.0, mr.position.y + 25.0), "ДЕНЬГИ — ПЕРЕТАЩИ НА ДОЛГ", HORIZONTAL_ALIGNMENT_RIGHT, 236.0, MGUI.MICRO, MGUI.TEXT_3)
	if drag_money:
		mr.position = drag_pos - mr.size * 0.5
	c.draw_rect(mr, Color(0.13, 0.3, 0.17))
	c.draw_rect(mr, MGUI.GOOD, false, 1.0)
	c.draw_string(f_num, mr.position + Vector2(0, 26), rub(e.money), HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 17, MGUI.TEXT)

## строка действия в панели подробностей: клавиша, что будет, причина (если нельзя)
func _flow_act(key: String, text: String, why := "") -> void:
	var h := MGUI.hbox(MGUI.S2)
	flow_side.add_child(h)
	var kc := MGUI.keycap(key)
	kc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(kc)
	var tv := MGUI.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(MGUI.label(MGUI.nb(text), "small", MGUI.TEXT if why == "" else MGUI.TEXT_3, 250.0))
	if why != "":
		tv.add_child(MGUI.label(MGUI.nb("нельзя: " + why), "micro", Color(1.0, 0.5, 0.45), 250.0))

func _flow_side() -> void:
	if flow_side == null or not is_instance_valid(flow_side):
		return
	for ch in flow_side.get_children():
		flow_side.remove_child(ch)
		ch.queue_free()
	var e := econ()
	var L := e.loan(flow_focus)
	var w := 360.0 - 2.0 * MGUI.S4 - 6.0
	if L.is_empty() or L["status"] == "closed":
		flow_side.add_child(MGUI.label("ДОЛГОВ НЕТ" if e.active().is_empty() else "ВЫБЕРИ ДОЛГ", "caps"))
		flow_side.add_child(MGUI.label("Все займы закрыты." if e.active().is_empty() else "Клик по долгу на карте или клавиши W/S.", "small", null, w))
	else:
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var over: bool = L["status"] == "overdue"
		flow_side.add_child(MGUI.label("ПРОСРОЧЕН НА %d ДН." % int(L["overdue"]) if over else "ДОЛГ", "caps", MGUI.RED if over else (D["col"] as Color)))
		flow_side.add_child(MGUI.label(String(D["name"]), "h2", null, w))
		var sr := MGUI.hbox(MGUI.S5)
		flow_side.add_child(sr)
		sr.add_child(MGUI.stat("ОСТАТОК", rub(int(ceil(L["balance"]))), "num")["box"])
		sr.add_child(MGUI.stat("СРОК", "день %d" % int(L["due"]), "num")["box"])
		flow_side.add_child(MGUI.label(MGUI.nb("Ставка %.1f %% в день, штраф %.0f %% за день просрочки." % [float(L["rate"]) * 100.0, float(L["fine"]) * 100.0]), "small", null, w))
		if bool(L["known"]) and L["clause"] != "":
			flow_side.add_child(MGUI.label(MGUI.nb("Мелкий шрифт: " + String(MLData.CLAUSES[L["clause"]][0])), "small", MGUI.WARN, w))
		flow_side.add_child(MGUI.hsep())
		if pay_amount > 0:
			var pv := e.preview("pay", {"id": flow_focus, "amount": pay_amount})
			flow_side.add_child(MGUI.label("ПЛАТЁЖ", "caps"))
			flow_side.add_child(MGUI.label(rub(pay_amount), "num_l", MGUI.GOOD))
			flow_side.add_child(MGUI.label(MGUI.nb(_pv(pv)), "small", null, w))
			_flow_act("Enter", "Оплатить")
			_flow_act("A/D", "Сумма: шаг 500 ₽")
		else:
			flow_side.add_child(MGUI.label("ДЕЙСТВИЯ", "caps"))
			_flow_act("1", _pv(e.preview("pay", {"id": flow_focus, "amount": int(ceil(L["balance"]))})), "" if e.money > 0 else "нет денег")
			for kind in ["min", "extend"]:
				var pv2 := e.preview(kind, {"id": flow_focus})
				_flow_act("2" if kind == "min" else "3", _pv(pv2), "" if bool(pv2["ok"]) else String(pv2["why"]))
			_flow_act("5", "Позвонить в контору и договориться (1 действие)", e.can_call(flow_focus))
		if flow_sel.size() >= 1:
			var best := _best_refi()
			if best != "":
				_flow_act("4", _pv(e.preview("refinance", {"ids": flow_sel, "lender": best})))
			else:
				_flow_act("4", "Объединить отмеченные (%d)" % flow_sel.size(), String(e.refinance_info(flow_sel, "cash")["why"]))
	if flow_canvas != null:
		flow_canvas.queue_redraw()
	refresh()

func _pv(pv: Dictionary) -> String:
	var ap := "≈" if pv.get("approx", false) else ""
	return " ".join(pv["lines"]) + " Итог: деньги %s%s, долг %s%s." % [ap, rub(int(pv["money"])), ap, rub(int(pv["debt"]))]

func _best_refi() -> String:
	var e := econ()
	for lid in ["cash", "reshim", "bystro", "srochno"]:
		if bool(e.refinance_info(flow_sel, lid)["ok"]):
			return lid
	return ""

func _flow_input(ev: InputEvent) -> void:
	var e := econ()
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if _money_rect().has_point(ev.position) and e.money > 0:
				drag_money = true
				drag_pos = ev.position
				return
			for L in e.active():
				if _node_rect(L).has_point(ev.position):
					flow_focus = int(L["id"])
					if Input.is_key_pressed(KEY_SHIFT) or flow_sel.has(flow_focus):
						if flow_sel.has(flow_focus):
							flow_sel.erase(flow_focus)
						else:
							flow_sel.append(flow_focus)
					pay_amount = 0
					_flow_side()
					return
		elif drag_money:
			drag_money = false
			for L in e.active():
				if _node_rect(L).has_point(ev.position):
					flow_focus = int(L["id"])
					pay_amount = mini(e.money, int(ceil(L["balance"])))
			_flow_side()
	elif ev is InputEventMouseMotion and drag_money:
		drag_pos = ev.position
		flow_canvas.queue_redraw()

func _flow_keys(k: int) -> bool:
	var e := econ()
	var L := e.loan(flow_focus)
	match k:
		KEY_ESCAPE:
			show_phase()
		KEY_ENTER, KEY_KP_ENTER, KEY_1:
			if not L.is_empty():
				e.pay(flow_focus, pay_amount if pay_amount > 0 else int(ceil(L["balance"])))
				pay_amount = 0
				_flow_side()
		KEY_2:
			if not L.is_empty() and not e.pay_min(flow_focus):
				notify(String(e.preview("min", {"id": flow_focus})["why"]), "bad")
			_flow_side()
		KEY_3:
			if not L.is_empty() and not e.extend(flow_focus):
				notify(String(e.extend_info(L)["why"]), "bad")
			_flow_side()
		KEY_4:
			var best := _best_refi()
			if best == "" or not e.refinance(flow_sel, best):
				notify("Объединить нельзя: " + (String(e.refinance_info(flow_sel, "cash")["why"]) if not flow_sel.is_empty() else "выбери долги (Shift+клик)"), "bad")
			flow_sel = []
			flow_focus = int(e.active()[0]["id"]) if not e.active().is_empty() else -1
			_flow_side()
		KEY_5:
			if not L.is_empty() and e.start_call(flow_focus):
				negotiate(flow_focus, func(): debt_flow())
			elif not L.is_empty():
				notify(e.can_call(flow_focus), "bad")
		KEY_A, KEY_LEFT:
			pay_amount = maxi(0, pay_amount - 500)
			_flow_side()
		KEY_D, KEY_RIGHT:
			if not L.is_empty():
				pay_amount = mini(mini(e.money, int(ceil(L["balance"]))), pay_amount + 500)
			_flow_side()
		KEY_Q, KEY_E:
			# стратегии: самый дорогой (ставка+штраф) или самый срочный
			var lst := e.active()
			if lst.is_empty():
				return true
			lst.sort_custom(func(a, b): return (float(a["rate"]) + float(a["fine"]) > float(b["rate"]) + float(b["fine"])) if k == KEY_Q else (int(a["due"]) < int(b["due"])))
			flow_focus = int(lst[0]["id"])
			pay_amount = mini(e.money, int(ceil(lst[0]["balance"])))
			notify(("Самый дорогой" if k == KEY_Q else "Самый срочный") + ": " + String(MLData.LENDERS[lst[0]["lender"]]["short"]), "info")
			_flow_side()
		KEY_W, KEY_S, KEY_UP, KEY_DOWN:
			var lst2 := e.active()
			if lst2.is_empty():
				return true
			var i := lst2.map(func(x): return int(x["id"])).find(flow_focus)
			flow_focus = int(lst2[posmod(i + (1 if k in [KEY_S, KEY_DOWN] else -1), lst2.size())]["id"])
			pay_amount = 0
			_flow_side()
		_:
			return false
	return true

# ---------------- переговоры ----------------
func negotiate(id: int, after: Callable) -> MLNegotiation:
	var N := MLNegotiation.new()
	stage.add_child(N)
	N.setup(econ(), id, font, serif)
	overlay = N
	close_panel()
	root.react("call")
	root.snd.ring_on()
	get_tree().create_timer(1.3, true, false, true).timeout.connect(func(): root.snd.ring_off())
	N.done.connect(func(r: Dictionary):
		var tw := N.create_tween()
		tw.tween_interval(0.9 if root.quiet == false else 0.05)
		tw.tween_callback(func():
			overlay = null
			N.queue_free()
			notify(String(r.get("text", "")), "money" if bool(r.get("won", false)) else "bad")
			after.call()))
	return N

func _day() -> void:
	var e := econ()
	var C: MLCareer = e.career
	var no_act := func(): return "действий нет" if e.actions <= 0 else ""
	var items: Array = []
	items.append([func(): return "ПОДРАБОТКИ", func(): jobs(), Callable(), {"icon": "broom", "thumb": "job_podezd", "sub": "уборка, ремонт, доставка, звук, хлам — настоящие мини-игры", "value": func(): return "%d действ." % e.actions, "tag": "1 действие", "col": Color(0.95, 0.75, 0.25)}])
	items.append(["ЗАЙМЫ И ДОГОВОРЫ", func(): offers(), Callable(), {"icon": "doc", "thumb": "up_scanner", "sub": "кто сегодня даёт и на каких условиях", "value": func(): return "%d предл." % e.offers.size(), "col": Color(0.55, 0.85, 1.0)}])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow(), Callable(), {"icon": "map", "thumb": "up_calc", "sub": "платежи, продление, рефинансирование — с последствиями", "value": func(): return rub(e.total_debt()), "col": RED}])
	items.append(["ОТДОХНУТЬ", func():
		e.rest()
		root.rest_anim(), no_act, {"icon": "sofa", "sub": "Пахан откидывается в кресле, слушает iPod", "value": "−25 стресса", "tag": "1 действие", "col": Color(0.6, 0.8, 1.0)}])
	items.append([func(): return "ВЕЩИ (%d)" % e.inventory.size(), func(): items_screen(), Callable(), {"icon": "bag", "thumb": "junk_0", "sub": "что оставил из хлама: продать, отдать Гене, держать", "value": func(): return "%d шт." % e.inventory.size(), "col": Color(0.8, 0.7, 0.5)}])
	items.append(["МАГАЗИН", func(): shop(), Callable(), {"icon": "cart", "thumb": "up_phone", "sub": "вещи, которые меняют правила недели", "value": func(): return "%d / %d" % [e.upgrades.size(), MLData.UPGRADES.size()], "col": Color(0.4, 0.9, 0.45)}])
	if C != null:
		items.append(["РАЗВИТИЕ ПАХАНА", func(): dev_tree(), Callable(), {"icon": "star", "sub": "пять веток навыков, синергии, ЛЕГЕНДА РАЙОНА", "value": func(): return "%d очк." % int(C.d["points"]), "tag": "[T]", "col": Color(1.0, 0.8, 0.3)}])
		items.append(["БИЗНЕС", func(): biz_screen(), Callable(), {"icon": "shop", "thumb": "biz_workshop", "sub": "мастерская, уборка, доставка, студия, склад: доход каждый вечер", "value": func(): return "%d из 5" % C.biz_count(), "col": Color(0.5, 1.0, 0.6)}])
	if e.can_finish():
		items.append(["ВСЁ ВЫПЛАЧЕНО — ЗАКОНЧИТЬ НЕДЕЛЮ", func(): e.finish(), Callable(), {"icon": "check", "sub": "долгов нет — можно закрыть неделю раньше", "value": "", "col": GREEN}])
	items.append(["ВЕЧЕР", func():
		e.next_phase()
		show_phase(), Callable(), {"icon": "moon", "sub": "звонки тех, у кого срок, выручка бизнесов", "value": "дальше", "tag": "фаза дня", "col": Color(0.85, 0.5, 0.9)}])
	open("ДЕНЬ %d" % e.day, [], items)

## РАЗВИТИЕ ПАХАНА — дерево навыков (ml_tree_ui.gd)
var tree_ui: MLTreeUI
func dev_tree() -> void:
	if econ().career == null:
		return
	screen = "tree"
	close_panel()
	panel = Control.new()
	panel.size = Vector2(W, STAGE.y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	tree_ui = MLTreeUI.new()
	tree_ui.ui = self
	panel.add_child(tree_ui)
	tree_ui.build()
	root.snd.play("open")

## БИЗНЕС: карточки пяти бизнесов — купить, поднять уровень, нанять, обслужить; итог дня и график дохода
func biz_screen() -> void:
	screen = "biz"
	var e := econ()
	var C: MLCareer = e.career
	var items: Array = []
	var day_net := 0
	for id in MLTree.BUSINESS_ORDER:
		var B: Dictionary = MLTree.BUSINESSES[id]
		var b := String(id)
		var lv := C.biz_level(b)
		var r := C.biz_day_one(b, e.total_overdue() == 0)
		day_net += int(r["net"])
		var cost := C.biz_cost(b)
		items.append([("%s · УР. %d" % [B["name"], lv]) if lv > 0 else String(B["name"]), func():
			var c := C.biz_up(b, e.money)
			if c > 0:
				e.money -= c
				e.say("%s: %s" % [B["name"], "куплено" if C.biz_level(b) == 1 else "уровень %d" % C.biz_level(b)], "money")
				e.xp(40)
				root.biz_visuals()
				e.changed.emit()
			biz_screen(), func(): return C.biz_why(b, e.money), {"icon": {"workshop": "wrench", "cleaning": "broom", "delivery": "box", "studio": "sliders", "warehouse": "crate"}.get(b, "shop"), "thumb": "biz_" + b,
			"sub": ("за день %+d ₽ · сотрудники %d/%d · исправность %d%%" % [int(r["net"]), int(C.biz(b).get("staff", 0)), C.biz_slots(b), int(float(C.biz(b).get("cond", 1.0)) * 100.0)]) if lv > 0 else "доход по вечерам: от %d ₽ в день" % int(B["inc"][0]),
			"value": rub(cost) if cost > 0 else "МАКС.", "tag": "купить" if lv == 0 else ("уровень ↑" if cost > 0 else ""), "col": Color(0.5, 1.0, 0.6)}])
		if lv > 0:
			items.append(["НАНЯТЬ — %s" % B["name"], func():
				var hc := C.hire(b, e.money)
				if hc > 0:
					e.money -= hc
					e.say("%s: новый сотрудник (зарплата %d ₽/день)" % [B["name"], int(B["wage"])], "info")
					e.xp(15)
					root.biz_visuals()
					e.changed.emit()
				biz_screen(), func(): return C.hire_why(b, e.money), {"icon": "worker", "sub": "+%d %% выручки у первого, дальше меньше · %d ₽ в день" % [int(float(B["k"]) * 100.0), int(B["wage"])], "value": rub(int(B["hire"])), "tag": "найм", "col": Color(0.55, 0.85, 1.0)}])
			if float(C.biz(b).get("cond", 1.0)) < 0.99 and C.v("auto:service") <= 0.0:
				items.append(["ОБСЛУЖИТЬ — %s" % B["name"], func():
					var sc := C.service_cost(b)
					if e.money >= sc:
						e.money -= C.service(b)
						e.say("%s: оборудование в порядке" % B["name"], "info")
						e.changed.emit()
					biz_screen(), func(): return "" if e.money >= C.service_cost(b) else "не хватает денег", {"icon": "tool", "sub": "износ режет выручку; автоматика в ветке МАСТЕР убирает его", "value": rub(C.service_cost(b)), "tag": "ремонт", "col": Color(1.0, 0.7, 0.25)}])
	items.append(["НАЗАД", func(): show_phase()])
	var lines: Array = ["Выручка приходит каждую ночь: доход × сотрудники × исправность, минус зарплаты и расходы. Сейчас за день: %+d ₽." % day_net]
	var syn: Array = MLTree.SYNERGIES.filter(func(s): return C.synergy_on(s)).map(func(s): return String(s["name"]))
	if not syn.is_empty():
		lines.append("Синергии: " + ", ".join(syn))
	var hist: Array = C.d["income"]
	if hist.size() >= 2:
		var last: Array = hist.slice(-7)
		lines.append("Последние дни (выручка − расходы): " + " · ".join(last.map(func(h): return "%+d" % (int(h[1]) - int(h[2])))))
	open("БИЗНЕС", lines, items, 0.0, "cards")

## ЛЕГЕНДА РАЙОНА: экран престижа — что потеряется, что останется, сколько АВТОРИТЕТА; постоянные бонусы
func legend_screen() -> void:
	screen = "legend"
	var e := econ()
	var C: MLCareer = e.career
	var pv := C.prestige_preview()
	var lines: Array = ["АВТОРИТЕТ: %d · циклов пройдено: %d" % [int(C.d["legend"]["points"]), int(C.d["legend"]["cycles"])]]
	if C.prestige_ready():
		lines.append("Начать новый цикл: получишь %d АВТОРИТЕТА." % int(pv["gain"]))
		lines.append("Потеряется: " + ", ".join(pv["lose"]))
		lines.append("Останется: " + ", ".join(pv["keep"]))
	else:
		lines.append("Престиж откроется с %d уровня или после %s заработанных за цикл (сейчас: уровень %d, %s)." % [MLTree.LEGEND_LEVEL, rub(MLTree.LEGEND_EARN), int(C.d["level"]), rub(C.stat("earned"))])
	var items: Array = []
	for L in MLTree.LEGEND:
		var lid := String(L["id"])
		var r := int((C.d["legend"]["perks"] as Dictionary).get(lid, 0))
		items.append(["%s %d/%d" % [L["name"], r, int(L["max"])], func():
			if C.legend_buy(lid):
				e.say("ЛЕГЕНДА: %s" % L["name"], "level")
				e.changed.emit()
			legend_screen(), func(): return C.legend_why(lid), {"icon": "crown", "sub": String(L["desc"]), "value": "%d АВТ." % int(L["cost"]), "col": Color(1.0, 0.7, 0.2)}])
	if C.prestige_ready():
		items.append(["СТАТЬ ЛЕГЕНДОЙ РАЙОНА", func():
			_confirm_prestige(), Callable(), {"icon": "bolt", "sub": "новый цикл: всё заново, но с АВТОРИТЕТОМ", "value": "+%d" % int(pv["gain"]), "tag": "престиж", "col": RED}])
	items.append(["НАЗАД", func(): dev_tree()])
	open("ЛЕГЕНДА РАЙОНА", lines, items)

func _confirm_prestige() -> void:
	var e := econ()
	open("НАЧАТЬ НОВЫЙ ЦИКЛ?", ["Навыки, бизнесы, сотрудники, копилка и текущая неделя обнулятся. Останутся АВТОРИТЕТ, бонусы ЛЕГЕНДЫ и концовки."], [
		["НЕТ, ВЕРНУТЬСЯ", func(): legend_screen(), Callable(), {"icon": "back", "sub": "ничего не изменится", "value": ""}],
		["ДА, НОВЫЙ ЦИКЛ", func():
			var g: int = e.career.prestige()
			e.new_game(int(Time.get_ticks_usec() % 2147483647))
			e.say("ЛЕГЕНДА РАЙОНА: +%d АВТОРИТЕТА. Новый цикл." % g, "milestone")
			root.biz_visuals()
			root.save()
			show_phase(), Callable(), {"icon": "crown", "sub": "навыки, бизнесы и копилка обнулятся — это нельзя отменить", "value": "", "col": RED}]])

# ---------------- займы ----------------
func offers() -> void:
	screen = "offers"
	var e := econ()
	var lines: Array = ["Условия видно сразу, мелкий шрифт — если прочитать договор."]
	var items: Array = []
	for O in e.offers:
		var D: Dictionary = MLData.LENDERS[O["lender"]]
		var id := int(O["id"])
		var clause: String = ((String(MLData.CLAUSES[O["clause"]][0]) if O["clause"] != "" else "без приписок")) if bool(O["known"]) else "мелкий шрифт: ??? (не читал)"
		var pv := e.preview("take", {"offer": O})
		items.append(["%s %s" % [D["short"], rub(int(O["amount"]))], func():
			e.take(id)
			root.snd.play("loan")
			offers(), func(): return "действий нет" if e.actions <= 0 else "", {"icon": "coin", "sub": "%.1f%% в день · %d дн. · %s\n%s" % [float(O["rate"]) * 100.0, int(O["term"]), clause, String(pv["lines"][0])], "value": rub(int(O["amount"])), "tag": D["name"], "col": D["col"]}])
		if not bool(O["known"]):
			items.append(["ИЗУЧИТЬ ДОГОВОР %s" % D["short"], func():
				e.study(id)
				offers(), func(): return "действий нет" if e.actions <= 0 else "", {"icon": "search", "sub": "прочитать мелкий шрифт", "value": "1 действие", "col": D["col"]}])
			items.append(["ПОЗВОНИТЬ ОПЕРАТОРУ %s" % D["short"], func():
				e.call_operator(id)
				offers(), Callable(), {"icon": "call", "sub": "оператор скажет, но нервы потратишь", "value": "+6 стресса", "col": D["col"]}])
	if e.offers.is_empty():
		lines.append("Сегодня никто не даёт — репутация или день не тот.")
	items.append(["КАРТА ДОЛГОВ: РЕФИНАНСИРОВАТЬ", func(): debt_flow(), Callable(), {"icon": "map", "sub": "объединить займы в один", "value": "", "col": RED}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "back", "sub": "", "value": "", "col": GREY}])
	open("ЗАЙМЫ", lines, items)

# ---------------- подработки ----------------
func jobs() -> void:
	screen = "jobs"
	var e := econ()
	var C: MLCareer = e.career
	var items: Array = []
	var icons := {"podezd": "broom", "repair": "wrench", "deliv": "box", "sound": "sliders", "junk": "crate"}
	for jid in MLData.JOB_ORDER:
		var J: Dictionary = MLData.JOBS[jid]
		var j := String(jid)
		var mult := C.pay_mult(j) if C != null else 1.0
		var tier := job_tier(j)
		var pay_s := "до %s" % rub(int(float(J["base"]) * mult * (1.0 + 0.25 * (tier - 1)) / 50.0) * 50) if int(J["base"]) > 0 else "по находкам"
		items.append([String(J["name"]), func(): run_job(j), func():
			if e.actions <= 0:
				return "действий нет"
			if not e.job_open(j):
				return "закрыто" + (" (репутация %d или контакты)" % int(J["rep"]) if j == "sound" else " (пылесос сломан)")
			return "", {"icon": icons.get(j, "•"), "thumb": "job_" + j, "sub": "%s\nуровень заказа %d · стресс +%d" % [J["desc"], tier, int(J["stress"])], "value": pay_s, "tag": "1 действие", "col": Color(0.95, 0.75, 0.25)}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "back", "sub": "", "value": "", "col": GREY}])
	open("ПОДРАБОТКИ", ["Чем лучше сделал — тем больше заплатят. Стресс мешает."], items, 0.0, "cards")

## уровень заказа подработки 1..5: растёт с навыками и снаряжением этой работы (сложнее, но дороже)
func job_tier(jid: String) -> int:
	var C: MLCareer = econ().career
	if C == null:
		return 1
	var t := 1
	match jid:
		"podezd":
			t += C.rank("w_suction") / 2 + C.rank("w_hose") + C.eq("tyaga") / 2
		"repair":
			t += C.rank("w_fix") / 2 + int(C.v("repair_hard")) + int(C.rank("w_multi"))
		"deliv":
			t += C.rank("w_legs") / 2 + C.rank("w_chain") + C.eq("deliv") / 2
		"sound":
			t += C.rank("w_ear") / 2 + int(C.v("sound_hard")) + C.eq("sound") / 2
		"junk":
			t += C.rank("w_eye") / 2 + int(C.v("junk_cap") / 2.0)
	return clampi(t, 1, 5)

func run_job(jid: String, bot := -1.0) -> MLJob:
	var e := econ()
	var J: MLJob
	match jid:
		"podezd":
			J = MLJobPodezd.new()
		"repair":
			J = MLJobRepair.new()
		"sound":
			J = MLJobSound.new()
		"deliv":
			J = MLJobDeliv.new()
		_:
			J = MLJobJunk.new()
	J.bot = bot
	J.career = e.career
	J.tier = job_tier(jid)
	J.snd = root.snd
	stage.add_child(J)
	J.call("setup", font, serif, e.stress, e.rng.randi())
	overlay = J
	close_panel()
	J.finished.connect(func(score: float, extra: Array):
		overlay = null
		J.queue_free()
		if jid == "junk":
			e.junk_done(extra)
		else:
			e.job_done(jid, score, J.tier)
		root.react("money" if score > 0.5 else "bad")
		show_phase())
	return J

# ---------------- вещи и магазин ----------------
func items_screen() -> void:
	screen = "items"
	var e := econ()
	var items: Array = []
	var reshim := e.active().filter(func(L): return L["lender"] == "reshim")
	for k in e.inventory.size():
		var idx := int(e.inventory[k])
		var it: Array = MLData.JUNK[idx]
		var kk := k
		items.append([String(it[0]), func():
			e.sell_item(kk)
			root.snd.play("coins")
			items_screen(), Callable(), {"icon": "coin", "thumb": "junk_%d" % idx, "sub": "%s. Разобрать: %s · Гене: %s." % [it[1], rub(int(it[4])), rub(int(it[3])) if int(it[3]) > 0 else "не возьмёт"], "value": "продать " + rub(int(it[2])), "tag": "вещь", "col": Color(0.8, 0.7, 0.5)}])
		if not reshim.is_empty() and int(it[3]) > 0:
			var rid := int(reshim[0]["id"])
			items.append(["ОТДАТЬ ГЕНЕ: %s" % it[0], func():
				e.barter(kk, rid)
				items_screen(), Callable(), {"icon": "box", "thumb": "junk_%d" % idx, "sub": "«Решим вопрос» спишет часть долга", "value": "−" + rub(int(it[3])), "tag": "бартер", "col": Color(0.7, 1.0, 0.55)}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "back", "sub": "", "value": "", "col": GREY}])
	open("ВЕЩИ", ["Оставленное из хлама. Продать, отдать «Решим вопрос» в счёт долга (Гена берёт не всё) или держать до лучшей цены."] if not e.inventory.is_empty() else ["Пусто. Вещи появляются, если в разборе хлама выбрать «ОСТАВИТЬ»."], items, 0.0, "grid")

func shop() -> void:
	screen = "shop"
	var e := econ()
	var items: Array = []
	for uid in MLData.UPGRADE_ORDER:
		var U: Dictionary = MLData.UPGRADES[uid]
		var u := String(uid)
		items.append([String(U["name"]), func():
			if e.buy(u):
				root.snd.play("buy")
				root.desk_item(u)
			shop(), func(): return "" if not e.upgrades.has(u) and e.money >= int(U["cost"]) else ("куплено" if e.upgrades.has(u) else "не хватает денег"), {"icon": "cart", "thumb": "up_" + u, "sub": String(U["desc"]), "value": "КУПЛЕНО" if e.upgrades.has(u) else rub(int(U["cost"])), "tag": "на неделю", "col": Color(0.4, 0.9, 0.45)}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "back", "sub": "", "value": "", "col": GREY}])
	open("МАГАЗИН", ["Покупки действуют до конца недели."], items, 0.0, "cards")

# ---------------- пауза и концовка ----------------
func pause_menu() -> void:
	open("ПАУЗА", ["Игра сохраняется сама после каждой фазы."], [
		["ПРОДОЛЖИТЬ", func(): show_phase(), Callable(), {"icon": "check", "sub": "вернуться к делам", "value": ""}],
		["НАЧАТЬ ЗАНОВО", func():
			econ().new_game(int(Time.get_ticks_usec() % 2147483647))
			show_phase(), Callable(), {"icon": "sun", "sub": "новая неделя с новыми долгами; развитие Пахана остаётся", "value": "", "col": MGUI.WARN}],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu(), Callable(), {"icon": "back", "sub": "выйти из «Микрозаймов»; прогресс сохранён", "value": "", "col": GREY}]])
	screen = "pause"

func ending() -> void:
	screen = "ending"
	var e := econ()
	var E: Array = MLData.ENDINGS.get(e.ending, MLData.ENDINGS["pit"])
	MLSave.record_ending(e)
	var lines: Array = [String(E[1]), "День %d · деньги %s · долг %s" % [e.day, rub(e.money), rub(e.total_debt())],
		"Займов взято: %d · закрыто: %d (переговорами: %d) · подработок: %d" % [int(e.stats["taken"]), int(e.stats["closed"]), int(e.stats["talk_closed"]), int(e.stats["jobs"])],
		"Переплачено процентами %s, штрафами и комиссиями %s" % [rub(int(e.stats["interest"])), rub(int(e.stats["fines"]))]]
	var all: Dictionary = MLSave.load_all().get("endings", {})
	lines.append("Открыто концовок: %d из %d" % [all.size(), MLData.ENDINGS.size()])
	if e.career != null and e.career.prestige_ready():
		lines.append("Открыта ЛЕГЕНДА РАЙОНА — можно начать новый цикл с АВТОРИТЕТОМ.")
	open(String(E[0]), lines, [
		["ЕЩЁ НЕДЕЛЯ", func():
			e.new_game(int(Time.get_ticks_usec() % 2147483647))
			intro()
			show_phase(), Callable(), {"icon": "sun", "sub": "новые долги, прежние навыки и бизнесы", "value": "дальше", "col": MGUI.GOLD}],
		["ЛЕГЕНДА РАЙОНА", func(): legend_screen(), func(): return "" if e.career != null and e.career.prestige_ready() else "с %d уровня" % MLTree.LEGEND_LEVEL, {"icon": "crown", "sub": "новый цикл с АВТОРИТЕТОМ: открывается с %d уровня или после %s за цикл" % [MLTree.LEGEND_LEVEL, rub(MLTree.LEGEND_EARN)], "value": "", "col": MGUI.GOLD}],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu(), Callable(), {"icon": "back", "sub": "", "value": "", "col": GREY}]], 1000.0)
	root.react("money" if e.ending != "pit" else "bad")
