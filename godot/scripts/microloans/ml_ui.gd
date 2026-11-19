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
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func econ() -> MLEconomy:
	return root.econ

func txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
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
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if v < 0 else "") + s + out + " ₽"

# ---------------- HUD ----------------
## Верх экрана — плитки: ДЕНЬ (фаза и кружки дней), ДЕНЬГИ и ОБЩИЙ ДОЛГ (цифры доезжают плавно и вспыхивают
## зелёным/красным), БЛИЖАЙШИЙ ПЛАТЁЖ (контора, сумма, когда — красным, если сегодня-завтра), СТРЕСС (шкала с цветом),
## ДЕЙСТВИЯ (кружки), УРОВЕНЬ ПАХАНА (опыт и очки навыков). Справа под плитками — уведомления телефона.
func _tile(pos: Vector2, size: Vector2, title: String) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	sb.border_color = Color(0.22, 0.22, 0.25)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	stage.add_child(p)
	txt(p, title, 13, SILVER, Vector2(12, 6))
	return p

func _hud() -> void:
	var t1 := _tile(Vector2(20, 14), Vector2(230, 104), "ДЕНЬ")
	hud["day"] = txt(t1, "", 38, WHITE, Vector2(12, 20), serif)
	hud["phase"] = txt(t1, "", 15, RED, Vector2(14, 70))
	hud["pips"] = []
	for k in MLData.DAYS:
		var c := ColorRect.new()
		c.size = Vector2(18, 6)
		c.position = Vector2(118 + k * 15, 36)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t1.add_child(c)
		(hud["pips"] as Array).append(c)
	var t2 := _tile(Vector2(262, 14), Vector2(250, 104), "ДЕНЬГИ")
	hud["money"] = txt(t2, "", 42, WHITE, Vector2(12, 26), serif)
	hud["money_d"] = txt(t2, "", 16, GREEN, Vector2(14, 78))
	var t3 := _tile(Vector2(524, 14), Vector2(270, 104), "ОБЩИЙ ДОЛГ")
	hud["debt"] = txt(t3, "", 42, RED, Vector2(12, 26), serif)
	hud["debt_d"] = txt(t3, "", 16, GREEN, Vector2(14, 78))
	var t4 := _tile(Vector2(806, 14), Vector2(300, 104), "БЛИЖАЙШИЙ ПЛАТЁЖ")
	hud["due_tile"] = t4
	hud["due_l"] = txt(t4, "", 22, WHITE, Vector2(12, 28), serif)
	hud["due_s"] = txt(t4, "", 15, SILVER, Vector2(12, 62))
	hud["due_s"].size = Vector2(280, 40)
	hud["due_s"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var t5 := _tile(Vector2(1118, 14), Vector2(220, 104), "СТРЕСС")
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.16, 0.18)
	bg.position = Vector2(12, 34)
	bg.size = Vector2(196, 16)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t5.add_child(bg)
	var fg := ColorRect.new()
	fg.position = bg.position
	fg.size = Vector2(0, 16)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t5.add_child(fg)
	hud["stress"] = fg
	hud["stress_n"] = txt(t5, "", 15, WHITE, Vector2(12, 56))
	hud["actions"] = txt(t5, "", 15, WHITE, Vector2(12, 78))
	var t6 := _tile(Vector2(1350, 14), Vector2(230, 104), "ПАХАН")
	hud["lvl"] = txt(t6, "", 28, Color(1.0, 0.8, 0.3), Vector2(12, 22), serif)
	var xb := ColorRect.new()
	xb.color = Color(0.16, 0.16, 0.18)
	xb.position = Vector2(12, 62)
	xb.size = Vector2(206, 8)
	xb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t6.add_child(xb)
	var xf := ColorRect.new()
	xf.color = Color(1.0, 0.8, 0.3)
	xf.position = xb.position
	xf.size = Vector2(0, 8)
	xf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t6.add_child(xf)
	hud["xp"] = xf
	hud["pts"] = txt(t6, "", 14, SILVER, Vector2(12, 76))
	notes_box = VBoxContainer.new()
	notes_box.position = Vector2(1200, 132)
	notes_box.size = Vector2(380, 420)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_box.add_theme_constant_override("separation", 8)
	stage.add_child(notes_box)

var shown := {"money": 0.0, "debt": 0.0}       # что сейчас нарисовано (цифры доезжают)
var target := {"money": 0.0, "debt": 0.0}
var flash := {"money": 0.0, "debt": 0.0}
var first_refresh := true

func refresh() -> void:
	var e := econ()
	if e == null or not is_instance_valid(hud["day"]):
		return
	hud["day"].text = "%d / %d" % [e.day, MLData.DAYS]
	hud["phase"].text = MLEconomy.PHASE_NAMES.get(e.phase, "") + (" · ещё %d дн." % (MLData.DAYS - e.day) if e.day < MLData.DAYS else " · ПОСЛЕДНИЙ ДЕНЬ")
	for k in MLData.DAYS:
		(hud["pips"][k] as ColorRect).color = RED if k + 1 == e.day else (Color(0.5, 0.5, 0.52) if k + 1 < e.day else Color(0.2, 0.2, 0.22))
	for key in ["money", "debt"]:
		var nv := float(e.money if key == "money" else e.total_debt())
		if first_refresh:
			shown[key] = nv
		elif absf(nv - float(target[key])) > 0.5:
			var dlt := nv - float(target[key])
			var good := dlt > 0.0 if key == "money" else dlt < 0.0
			var dl: Label = hud[key + "_d"]
			dl.text = ("+" if dlt > 0 else "−") + rub(int(absf(dlt))).trim_prefix("−")
			dl.add_theme_color_override("font_color", GREEN if good else RED)
			dl.modulate.a = 1.0
			dl.create_tween().tween_property(dl, "modulate:a", 0.0, 2.2).set_delay(1.2)
			flash[key] = 1.0 if good else -1.0
		target[key] = nv
	first_refresh = false
	var st := float(e.stress) / 100.0
	(hud["stress"] as ColorRect).color = Color(0.4, 0.85, 0.45).lerp(Color(1.0, 0.75, 0.2), clampf(st * 2.0, 0.0, 1.0)).lerp(RED, clampf(st * 2.0 - 1.0, 0.0, 1.0))
	hud["stress_n"].text = "%d / 100%s" % [e.stress, "  · отнимает действие" if e.stress >= 80 else ""]
	hud["actions"].text = "ДЕЙСТВИЯ: " + "●".repeat(maxi(0, e.actions)) + "○".repeat(maxi(0, e.actions_max() - e.actions))
	# ближайший платёж
	var near: Dictionary = {}
	for L in e.active():
		if near.is_empty() or int(L["due"]) < int(near["due"]):
			near = L
	var tile: Panel = hud["due_tile"]
	var sb := tile.get_theme_stylebox("panel") as StyleBoxFlat
	if near.is_empty():
		hud["due_l"].text = "ДОЛГОВ НЕТ"
		hud["due_s"].text = "телефон молчит"
		sb.border_color = GREEN
	else:
		var D: Dictionary = MLData.LENDERS[near["lender"]]
		var dd := int(near["due"]) - e.day
		hud["due_l"].text = "%s · %s" % [D["short"], rub(int(ceil(float(near["balance"]))))]
		hud["due_s"].text = "ПРОСРОЧЕН %d дн." % int(near["overdue"]) if near["status"] == "overdue" else ("СЕГОДНЯ" if dd <= 0 else ("завтра" if dd == 1 else "через %d дн." % dd))
		sb.border_color = RED if dd <= 1 or near["status"] == "overdue" else Color(1.0, 0.75, 0.3) if dd == 2 else Color(0.22, 0.22, 0.25)
	if e.career != null:
		var C: MLCareer = e.career
		hud["lvl"].text = "УР. %d · нед. %d" % [int(C.d["level"]), int(C.d["week"])]
		(hud["xp"] as ColorRect).size.x = 206.0 * clampf(float(C.d["xp"]) / float(MLCareer.xp_need(int(C.d["level"]))), 0.0, 1.0)
		hud["pts"].text = ("ОЧКИ: %d · [T] развитие" % int(C.d["points"])) if int(C.d["points"]) > 0 else "опыт %d / %d" % [int(C.d["xp"]), MLCareer.xp_need(int(C.d["level"]))]
	if e.ending != "" and screen != "ending":
		ending()
	elif panel != null and rows.size() > 0:
		_paint()

## каждый кадр: цифры денег и долга доезжают до нужных, вспышка цвета гаснет, платёж «сегодня» пульсирует
func _process(dt: float) -> void:
	if hud.is_empty():
		return
	for key in ["money", "debt"]:
		var cur := float(shown[key])
		var tg := float(target[key])
		cur = move_toward(cur, tg, maxf(absf(tg - cur) * 6.0 * dt, 40.0 * dt * 10.0))
		shown[key] = cur
		var l: Label = hud[key]
		l.text = rub(int(round(cur)))
		var base := WHITE if key == "money" else RED
		var fk := float(flash[key])
		if absf(fk) > 0.01:
			l.add_theme_color_override("font_color", base.lerp(GREEN if fk > 0 else Color(1, 0.3, 0.2), absf(fk)))
			flash[key] = move_toward(fk, 0.0, dt * 1.2)
		else:
			l.add_theme_color_override("font_color", base)
	var tile: Panel = hud["due_tile"]
	var sb := tile.get_theme_stylebox("panel") as StyleBoxFlat
	if sb.border_color == RED:
		sb.border_width_bottom = 3 + int(2.5 + 2.5 * sin(Time.get_ticks_msec() * 0.008))
	else:
		sb.border_width_bottom = 3

## уведомление телефона: карточка с иконкой приложения, названием и временем — выезжает справа
const APPS := {"bad": ["⚠", "СРОКИ", Color(0.86, 0.09, 0.11)], "warn": ["⏰", "НАПОМИНАНИЕ", Color(1.0, 0.7, 0.25)], "money": ["₽", "ПЕРЕВОДЫ", Color(0.35, 0.85, 0.45)],
	"level": ["★", "РАЗВИТИЕ", Color(1.0, 0.8, 0.3)], "milestone": ["🏆", "ВЕХА", Color(0.8, 0.6, 1.0)], "call": ["☎", "ЗВОНОК", Color(0.55, 0.85, 1.0)], "info": ["✉", "СООБЩЕНИЯ", Color(0.75, 0.78, 0.82)]}
func notify(text: String, kind: String) -> void:
	var app: Array = APPS.get(kind, APPS["info"])
	var col: Color = app[2]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.1, 0.96)
	sb.set_corner_radius_all(14)
	sb.border_color = col
	sb.border_width_left = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var ic := Label.new()
	ic.text = String(app[0])
	ic.custom_minimum_size = Vector2(40, 40)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override("font_size", 22)
	ic.add_theme_color_override("font_color", INK)
	var isb := StyleBoxFlat.new()
	isb.bg_color = col
	isb.set_corner_radius_all(10)
	ic.add_theme_stylebox_override("normal", isb)
	box.add_child(ic)
	var col_box := VBoxContainer.new()
	col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_box.add_theme_constant_override("separation", 2)
	box.add_child(col_box)
	var head := Label.new()
	head.text = "%s  ·  сейчас" % app[1]
	head.add_theme_font_override("font", font)
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", col)
	col_box.add_child(head)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	col_box.add_child(l)
	notes_box.add_child(card)
	notes_box.move_child(card, 0)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_interval(5.5 if kind in ["level", "milestone", "bad"] else 4.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)
	if kind in ["level", "milestone"]:
		_banner(text, col)
	while notes_box.get_child_count() > 4:
		var c := notes_box.get_child(notes_box.get_child_count() - 1)
		notes_box.remove_child(c)
		c.queue_free()

## большая надпись по центру — новый уровень, веха
func _banner(text: String, col: Color) -> void:
	var b := txt(stage, text, 40, col, Vector2(0, 380), serif)
	b.size = Vector2(STAGE.x, 60)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pivot_offset = Vector2(STAGE.x / 2, 30)
	b.scale = Vector2(0.6, 0.6)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(b, "modulate:a", 0.0, 0.5)
	tw.tween_callback(b.queue_free)
	root.snd.play("cheer")

# ---------------- 3D-превью предметов (для карточек) ----------------
var thumbs := {}
## маленькая картинка модели: свой SubViewport рисует один раз, потом картинка живёт в текстуре
func thumb(id: String) -> Texture2D:
	if thumbs.has(id):
		return thumbs[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(220, 160)
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
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(span * 0.9, span * 0.75, span * 1.6)
	cam.look_at(Vector3(0, span * 0.32, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-span, span, span)
	fill.light_energy = 0.8
	fill.omni_range = span * 6.0
	vp.add_child(fill)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_CLEAR_COLOR
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color(0.6, 0.6, 0.65)
	en.ambient_light_energy = 0.7
	env.environment = en
	vp.add_child(env)
	thumbs[id] = vp.get_texture()
	return thumbs[id]

# ---------------- экран: карточки и кнопки ----------------
## items: [текст, действие, почему нельзя (Callable) или пусто, карточка {icon, thumb, sub, value, tag, col}]
## С карточками — сетка карточек (картинка, название, описание, цена, метка), без — крупные кнопки.
var cols := 1
func open(title: String, lines: Array, items: Array, w := 760.0) -> Control:
	close_panel()
	panel = Control.new()
	panel.size = STAGE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var card := Polygon2D.new()
	card.polygon = torn(w, 730.0, title.hash())
	card.color = Color(0.035, 0.035, 0.04, 0.93)
	card.position = Vector2(20, 134)
	panel.add_child(card)
	var edge := Line2D.new()
	edge.points = card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = Color(0.85, 0.86, 0.88, 0.6)
	card.add_child(edge)
	var stripe := ColorRect.new()
	stripe.color = RED
	stripe.position = Vector2(40, 196)
	stripe.size = Vector2(minf(420.0, w - 60.0), 5)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stripe)
	var h := txt(panel, title, 44, WHITE, Vector2(40, 142), serif)
	h.rotation = deg_to_rad(-1.2)
	var y := 212.0
	for s in lines:
		if String(s) == "":
			y += 6.0
			continue
		var chip := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.1, 0.1, 0.11, 0.95)
		csb.set_corner_radius_all(6)
		csb.content_margin_left = 10
		csb.content_margin_right = 10
		csb.content_margin_top = 4
		csb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", csb)
		chip.position = Vector2(44, y)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(chip)
		var l := Label.new()
		l.text = String(s)
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", SILVER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w - 90, 0)
		chip.add_child(l)
		y += maxf(30.0, l.get_minimum_size().y + 12.0)
	y += 6.0
	rows = []
	var has_cards := items.any(func(it): return (it as Array).size() > 3 and it[3] is Dictionary)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, y)
	scroll.size = Vector2(w - 30, 850.0 - y)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var cw := 246.0
	cols = maxi(1, int((w - 40.0) / (cw + 12.0))) if has_cards else 1
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var n := 0
	for it in items:
		var i := rows.size()
		var spec: Dictionary = it[3] if it.size() > 3 and it[3] is Dictionary else {}
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bsb := StyleBoxFlat.new()
		bsb.set_corner_radius_all(8)
		bsb.content_margin_left = 12
		bsb.content_margin_right = 12
		bsb.content_margin_top = 8
		bsb.content_margin_bottom = 8
		bsb.border_width_left = 5
		box.add_theme_stylebox_override("panel", bsb)
		var lab := Label.new()
		lab.add_theme_font_override("font", serif)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var parts := {}
		if has_cards:
			box.custom_minimum_size = Vector2(cw, 268 if spec.has("thumb") else 190)
			var v := VBoxContainer.new()
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 4)
			box.add_child(v)
			var top := HBoxContainer.new()
			top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(top)
			var ic := Label.new()
			ic.text = String(spec.get("icon", ""))
			ic.add_theme_font_size_override("font_size", 26)
			top.add_child(ic)
			var tag := Label.new()
			tag.text = String(spec.get("tag", ""))
			tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag.add_theme_font_override("font", font)
			tag.add_theme_font_size_override("font_size", 12)
			top.add_child(tag)
			parts["tag"] = tag
			if spec.has("thumb"):
				var tr := TextureRect.new()
				tr.texture = thumb(String(spec["thumb"]))
				tr.custom_minimum_size = Vector2(cw - 24, 96)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				v.add_child(tr)
			lab.add_theme_font_size_override("font_size", 21)
			lab.custom_minimum_size = Vector2(cw - 24, 0)
			v.add_child(lab)
			var sub := Label.new()
			sub.text = _sv(spec.get("sub", ""))
			sub.add_theme_font_override("font", font)
			sub.add_theme_font_size_override("font_size", 12)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.custom_minimum_size = Vector2(cw - 24, 0)
			v.add_child(sub)
			parts["sub"] = sub
			var val := Label.new()
			val.text = _sv(spec.get("value", ""))
			val.add_theme_font_override("font", serif)
			val.add_theme_font_size_override("font_size", 22)
			v.add_child(val)
			parts["val"] = val
		else:
			lab.add_theme_font_size_override("font_size", 23)
			lab.custom_minimum_size = Vector2(w - 90, 0)
			box.add_child(lab)
		grid.add_child(box)
		rows.append({"label": lab, "text": it[0], "act": it[1], "why": it[2] if it.size() > 2 and it[2] is Callable else Callable(), "box": box, "sb": bsb, "spec": spec, "parts": parts})
		box.mouse_entered.connect(func(): _select(i))
		box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
				_activate())
		box.modulate.a = 0.0
		box.create_tween().tween_property(box, "modulate:a", 1.0, 0.18).set_delay(0.025 * n)
		n += 1
	sel = 0
	_paint()
	panel.modulate.a = 0.0
	panel.position.x = -30.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	root.snd.play("open")
	return panel

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
	var sc := b.get_parent().get_parent() as ScrollContainer
	if sc != null:
		sc.ensure_control_visible.call_deferred(b)

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
		var acc: Color = spec.get("col", RED)
		var sb: StyleBoxFlat = r["sb"]
		var lab: Label = r["label"]
		if spec.is_empty():
			# кнопка: чёрная с белой надписью, выбранная — белая с тёмной
			lab.text = s + ("  — " + why if why != "" else "")
			sb.bg_color = Color(0.92, 0.92, 0.9) if on else Color(0.1, 0.1, 0.11)
			sb.border_color = acc if why == "" else GREY
			lab.add_theme_color_override("font_color", (INK if on else WHITE) if why == "" else GREY)
		else:
			# карточка: грязно-белая, выбранная — с толстой цветной рамкой; недоступная — тусклая с причиной
			lab.text = s
			sb.bg_color = Color(0.9, 0.88, 0.83) if why == "" else Color(0.35, 0.35, 0.37)
			sb.border_color = acc
			sb.border_width_left = 8 if on else 5
			sb.border_width_top = 3 if on else 0
			sb.border_width_right = 3 if on else 0
			sb.border_width_bottom = 3 if on else 0
			lab.add_theme_color_override("font_color", INK)
			var parts: Dictionary = r["parts"]
			(parts["sub"] as Label).add_theme_color_override("font_color", Color(0.25, 0.25, 0.27))
			(parts["val"] as Label).add_theme_color_override("font_color", acc.darkened(0.35))
			(parts["tag"] as Label).text = why if why != "" else _sv(spec.get("tag", ""))
			(parts["val"] as Label).text = _sv(spec.get("value", ""))
			(parts["tag"] as Label).add_theme_color_override("font_color", RED if why != "" else Color(0.3, 0.3, 0.32))
			var box: Control = r["box"]
			box.pivot_offset = box.size * 0.5
			box.scale = Vector2.ONE * (1.03 if on else 1.0)

func _activate() -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	if _why(r) != "":
		root.snd.play("fail")
		var b: Control = r["box"]
		var x0 := b.position.x
		var tw := b.create_tween()
		for k in 3:
			tw.tween_property(b, "position:x", x0 + 6.0, 0.03)
			tw.tween_property(b, "position:x", x0 - 6.0, 0.03)
		tw.tween_property(b, "position:x", x0, 0.03)
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
	if k == KEY_W or k == KEY_UP:
		_select(sel - cols)
	elif k == KEY_S or k == KEY_DOWN:
		_select(sel + cols)
	elif (k == KEY_A or k == KEY_LEFT) and cols > 1:
		_select(sel - 1)
	elif (k == KEY_D or k == KEY_RIGHT) and cols > 1:
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


## значение карточки: строка или Callable, который её возвращает
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
		lines.append("")
		lines.append("СОБЫТИЕ: " + String(E["title"]) + " — " + String(E["text"]))
		for c in (E["choices"] as Array).size():
			var cc := c
			items.append([String(E["choices"][c][0]), func():
				var r := e.resolve_event(cc)
				if r.has("fail"):
					notify(String(r["fail"]), "bad")
					return
				if r.has("talk"):
					var cl := e.active().filter(func(L): return L["status"] == "overdue")
					if not cl.is_empty():
						negotiate(int(cl[0]["id"]), func(): show_phase())
						return
				show_phase()])
	else:
		items.append(["НАЧАТЬ ДЕНЬ", func():
			e.next_phase()
			show_phase()])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow()])
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
		items.append(["☎ ОТВЕТИТЬ: %s (%s)" % [D["name"], rub(int(ceil(L["balance"])))], func():
			L["called"] = e.day
			negotiate(id, func(): show_phase())])
		items.append(["✕ СБРОСИТЬ %s (+стресс)" % D["short"], func():
			L["called"] = e.day
			e.stress = clampi(e.stress + 8, 0, 100)
			e.rep = clampi(e.rep - 2, 0, 100)
			e.say("Сбросил звонок %s. Перезвонят." % D["short"], "bad")
			show_phase()])
	items.append(["КАРТА ДОЛГОВ — ПЛАТЕЖИ", func(): debt_flow()])
	items.append(["СПАТЬ (ночь: проценты и штрафы) →", func():
		e.next_phase()
		show_phase()])
	open("ВЕЧЕР · ДЕНЬ %d" % e.day, lines, items)
	if not calls.is_empty():
		root.react("call")

# ---------------- карта долгов ----------------
## Граф: займы — узлы по дням срока (слева направо) и конторам (сверху вниз), рефинансирование — стрелки
## от закрытых к новому. Внизу — пачка денег: перетащи её на узел — откроется платёж. Справа — что будет.
func debt_flow() -> void:
	screen = "flow"
	close_panel()
	panel = Control.new()
	panel.size = STAGE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.93)
	bg.position = Vector2(20, 150)
	bg.size = Vector2(1140, 730)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	txt(panel, "КАРТА ДОЛГОВ ПАХАНА", 40, WHITE, Vector2(44, 156), serif)
	txt(panel, "Тащи пачку денег на долг · клик — выбрать · 1 погасить · 2 минимум · 3 продлить · 4 объединить выбранные · Q самый дорогой · E самый срочный · Esc назад", 14, SILVER, Vector2(48, 206))
	flow_canvas = Control.new()
	flow_canvas.position = Vector2(20, 230)
	flow_canvas.size = Vector2(1140, 640)
	flow_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(flow_canvas)
	flow_canvas.draw.connect(_flow_draw)
	flow_canvas.gui_input.connect(_flow_input)
	var side := txt(panel, "", 16, WHITE, Vector2(1180, 560))
	side.size = Vector2(400, 320)
	side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.name = "side"
	if flow_focus < 0 and not econ().active().is_empty():
		flow_focus = int(econ().active()[0]["id"])
	pay_amount = 0
	_flow_side()

func _node_pos(L: Dictionary) -> Vector2:
	var e := econ()
	var lane := MLData.LENDER_ORDER.find(String(L["lender"]))
	var x := 120.0 + clampf(float(int(L["due"]) - e.day + 1), 0.0, 8.0) * 115.0
	var same := e.loans.filter(func(o): return o["lender"] == L["lender"] and int(o["due"]) == int(L["due"]) and o["status"] != "closed")
	return Vector2(x, 90.0 + lane * 125.0 + same.find(L) * 34.0)

func _flow_draw() -> void:
	var e := econ()
	var c := flow_canvas
	# дни
	for d in 9:
		var x := 120.0 + d * 115.0
		c.draw_line(Vector2(x, 30), Vector2(x, 560), Color(1, 1, 1, 0.06), 1.0)
		var day := e.day + d - 1
		c.draw_string(font, Vector2(x - 26, 24), ("СЕГОДНЯ" if d == 1 else ("ПРОСРОЧ." if d == 0 else "ДЕНЬ %d" % day)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RED if d == 0 else (WHITE if day == MLData.DAYS else GREY))
	for lane in MLData.LENDER_ORDER.size():
		var D: Dictionary = MLData.LENDERS[MLData.LENDER_ORDER[lane]]
		c.draw_string(font, Vector2(6, 96 + lane * 125), String(D["short"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, D["col"])
	# связи рефинансирования
	for L in e.loans:
		if L.has("from") and L["status"] != "closed":
			for fid in L["from"]:
				var F := e.loan(int(fid))
				if not F.is_empty():
					var a := _node_pos(F) if F["status"] != "closed" else Vector2(60, _node_pos(L).y)
					c.draw_line(a, _node_pos(L), Color(1, 0.75, 0.3, 0.6), 3.0)
	# узлы
	for L in e.active():
		var p := _node_pos(L)
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var r := Rect2(p - Vector2(54, 16), Vector2(150, 50))
		var focus: bool = int(L["id"]) == flow_focus
		c.draw_rect(r, Color(0.08, 0.08, 0.09))
		c.draw_rect(r, (RED if L["status"] == "overdue" else (D["col"] as Color)) if not focus else WHITE, false, 4.0 if focus else 2.0)
		if flow_sel.has(int(L["id"])):
			c.draw_rect(r.grow(5), Color(1, 0.8, 0.3), false, 2.0)
		c.draw_string(serif, p + Vector2(-46, 6), rub(int(ceil(L["balance"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE)
		c.draw_string(font, p + Vector2(-46, 26), "%.1f%%/д · штр %.0f%%" % [float(L["rate"]) * 100.0, float(L["fine"]) * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SILVER)
	# пачка денег
	var mp := drag_pos if drag_money else Vector2(560, 600)
	c.draw_rect(Rect2(mp - Vector2(60, 22), Vector2(120, 44)), Color(0.25, 0.55, 0.3))
	c.draw_string(serif, mp + Vector2(-52, 8), rub(e.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE)

func _flow_side() -> void:
	if panel == null or panel.get_node_or_null("side") == null:
		return
	var e := econ()
	var L := e.loan(flow_focus)
	var s := ""
	if L.is_empty() or L["status"] == "closed":
		s = "Выбери долг на карте."
	else:
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		s = "%s\nостаток %s · срок день %d%s\nставка %.1f%% в день, штраф %.0f%% в день просрочки\n%s" % [D["name"], rub(int(ceil(L["balance"]))), int(L["due"]), " · ПРОСРОЧКА" if L["status"] == "overdue" else "",
			float(L["rate"]) * 100.0, float(L["fine"]) * 100.0, ("мелкий шрифт: " + String(MLData.CLAUSES[L["clause"]][0])) if bool(L["known"]) and L["clause"] != "" else ""]
		if pay_amount > 0:
			var pv := e.preview("pay", {"id": flow_focus, "amount": pay_amount})
			s += "\n\nПЛАТЁЖ %s (A/D −/+, Enter — оплатить):\n%s" % [rub(pay_amount), _pv(pv)]
		else:
			for kind in ["min", "extend"]:
				var pv2 := e.preview(kind, {"id": flow_focus})
				s += "\n\n[%s] %s%s" % ["2" if kind == "min" else "3", _pv(pv2), ("" if bool(pv2["ok"]) else " — нельзя: " + String(pv2["why"]))]
			var cw := e.can_call(flow_focus)
			s += "

[5] Позвонить в контору и договориться (1 действие)%s" % ("" if cw == "" else " — " + cw)
		if flow_sel.size() >= 1:
			var best := _best_refi()
			if best != "":
				s += "\n\n[4] %s" % _pv(e.preview("refinance", {"ids": flow_sel, "lender": best}))
	(panel.get_node("side") as Label).text = s
	if flow_canvas != null:
		flow_canvas.queue_redraw()
	refresh()

func _pv(pv: Dictionary) -> String:
	var ap := "≈" if pv.get("approx", false) else ""
	return " ".join(pv["lines"]) + " → деньги %s%s, долг %s%s" % [ap, rub(int(pv["money"])), ap, rub(int(pv["debt"]))]

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
			if Rect2(Vector2(500, 578), Vector2(120, 44)).has_point(ev.position) and e.money > 0:
				drag_money = true
				drag_pos = ev.position
				return
			for L in e.active():
				if Rect2(_node_pos(L) - Vector2(54, 16), Vector2(150, 50)).has_point(ev.position):
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
				if Rect2(_node_pos(L) - Vector2(54, 16), Vector2(150, 50)).has_point(ev.position):
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
	items.append([func(): return "ПОДРАБОТКИ", func(): jobs(), Callable(), {"icon": "🧹", "thumb": "job_podezd", "sub": "уборка, ремонт, доставка, звук, хлам — настоящие мини-игры", "value": func(): return "%d действ." % e.actions, "tag": "1 действие", "col": Color(0.95, 0.75, 0.25)}])
	items.append(["ЗАЙМЫ И ДОГОВОРЫ", func(): offers(), Callable(), {"icon": "📄", "thumb": "up_scanner", "sub": "кто сегодня даёт и на каких условиях", "value": func(): return "%d предл." % e.offers.size(), "col": Color(0.55, 0.85, 1.0)}])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow(), Callable(), {"icon": "🗺", "thumb": "up_calc", "sub": "платежи, продление, рефинансирование — с последствиями", "value": func(): return rub(e.total_debt()), "col": RED}])
	items.append(["ОТДОХНУТЬ", func():
		e.rest()
		root.rest_anim(), no_act, {"icon": "🛋", "sub": "Пахан откидывается в кресле, слушает iPod", "value": "−25 стресса", "tag": "1 действие", "col": Color(0.6, 0.8, 1.0)}])
	items.append([func(): return "ВЕЩИ (%d)" % e.inventory.size(), func(): items_screen(), Callable(), {"icon": "🎒", "thumb": "junk_0", "sub": "что оставил из хлама: продать, отдать Гене, держать", "value": func(): return "%d шт." % e.inventory.size(), "col": Color(0.8, 0.7, 0.5)}])
	items.append(["МАГАЗИН", func(): shop(), Callable(), {"icon": "🛒", "thumb": "up_phone", "sub": "вещи, которые меняют правила недели", "value": func(): return "%d / %d" % [e.upgrades.size(), MLData.UPGRADES.size()], "col": Color(0.4, 0.9, 0.45)}])
	if C != null:
		items.append(["РАЗВИТИЕ ПАХАНА", func(): dev_tree(), Callable(), {"icon": "★", "sub": "пять веток навыков, синергии, ЛЕГЕНДА РАЙОНА", "value": func(): return "%d очк." % int(C.d["points"]), "tag": "[T]", "col": Color(1.0, 0.8, 0.3)}])
		items.append(["БИЗНЕС", func(): biz_screen(), Callable(), {"icon": "🏪", "thumb": "biz_workshop", "sub": "мастерская, уборка, доставка, студия, склад: доход каждый вечер", "value": func(): return "%d из 5" % C.biz_count(), "col": Color(0.5, 1.0, 0.6)}])
	if e.can_finish():
		items.append(["ВСЁ ВЫПЛАЧЕНО — ЗАКОНЧИТЬ НЕДЕЛЮ", func(): e.finish(), Callable(), {"icon": "🏁", "sub": "долгов нет — можно закрыть неделю раньше", "value": "", "col": GREEN}])
	items.append(["ВЕЧЕР →", func():
		e.next_phase()
		show_phase(), Callable(), {"icon": "🌆", "sub": "звонки тех, у кого срок, выручка бизнесов", "value": "дальше", "tag": "фаза дня", "col": Color(0.85, 0.5, 0.9)}])
	open("ДЕНЬ %d" % e.day, ["Каждая подработка, отдых или договор — одно действие. Осталось: %d." % e.actions], items, 1100.0)

## РАЗВИТИЕ ПАХАНА — дерево навыков (ml_tree_ui.gd)
var tree_ui: MLTreeUI
func dev_tree() -> void:
	if econ().career == null:
		return
	screen = "tree"
	close_panel()
	panel = Control.new()
	panel.size = STAGE
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
			biz_screen(), func(): return C.biz_why(b, e.money), {"icon": String(B["icon"]), "thumb": "biz_" + b,
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
				biz_screen(), func(): return C.hire_why(b, e.money), {"icon": "👷", "sub": "+%d %% выручки у первого, дальше меньше · %d ₽ в день" % [int(float(B["k"]) * 100.0), int(B["wage"])], "value": rub(int(B["hire"])), "tag": "найм", "col": Color(0.55, 0.85, 1.0)}])
			if float(C.biz(b).get("cond", 1.0)) < 0.99 and C.v("auto:service") <= 0.0:
				items.append(["ОБСЛУЖИТЬ — %s" % B["name"], func():
					var sc := C.service_cost(b)
					if e.money >= sc:
						e.money -= C.service(b)
						e.say("%s: оборудование в порядке" % B["name"], "info")
						e.changed.emit()
					biz_screen(), func(): return "" if e.money >= C.service_cost(b) else "не хватает денег", {"icon": "🛠", "sub": "износ режет выручку; автоматика в ветке МАСТЕР убирает его", "value": rub(C.service_cost(b)), "tag": "ремонт", "col": Color(1.0, 0.7, 0.25)}])
	items.append(["НАЗАД", func(): show_phase()])
	var lines: Array = ["Выручка приходит каждую ночь: доход × сотрудники × исправность, минус зарплаты и расходы. Сейчас за день: %+d ₽." % day_net]
	var syn: Array = MLTree.SYNERGIES.filter(func(s): return C.synergy_on(s)).map(func(s): return String(s["name"]))
	if not syn.is_empty():
		lines.append("Синергии: " + ", ".join(syn))
	var hist: Array = C.d["income"]
	if hist.size() >= 2:
		var last: Array = hist.slice(-7)
		lines.append("Последние дни (выручка − расходы): " + " · ".join(last.map(func(h): return "%+d" % (int(h[1]) - int(h[2])))))
	open("БИЗНЕС", lines, items, 1100.0)

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
			legend_screen(), func(): return C.legend_why(lid), {"icon": "👑", "sub": String(L["desc"]), "value": "%d АВТ." % int(L["cost"]), "col": Color(1.0, 0.7, 0.2)}])
	if C.prestige_ready():
		items.append(["СТАТЬ ЛЕГЕНДОЙ РАЙОНА", func():
			_confirm_prestige(), Callable(), {"icon": "🔥", "sub": "новый цикл: всё заново, но с АВТОРИТЕТОМ", "value": "+%d" % int(pv["gain"]), "tag": "престиж", "col": RED}])
	items.append(["НАЗАД", func(): dev_tree()])
	open("ЛЕГЕНДА РАЙОНА", lines, items, 1100.0)

func _confirm_prestige() -> void:
	var e := econ()
	open("ТОЧНО?", ["Навыки, бизнесы, сотрудники, копилка и текущая неделя обнулятся. Останутся АВТОРИТЕТ, бонусы ЛЕГЕНДЫ и концовки."], [
		["ДА — НОВЫЙ ЦИКЛ", func():
			var g: int = e.career.prestige()
			e.new_game(int(Time.get_ticks_usec() % 2147483647))
			e.say("ЛЕГЕНДА РАЙОНА: +%d АВТОРИТЕТА. Новый цикл." % g, "milestone")
			root.biz_visuals()
			root.save()
			show_phase()],
		["НЕТ", func(): legend_screen()]])

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
			offers(), func(): return "действий нет" if e.actions <= 0 else "", {"icon": "🏦", "sub": "%.1f%% в день · %d дн. · %s\n%s" % [float(O["rate"]) * 100.0, int(O["term"]), clause, String(pv["lines"][0])], "value": rub(int(O["amount"])), "tag": D["name"], "col": D["col"]}])
		if not bool(O["known"]):
			items.append(["ИЗУЧИТЬ ДОГОВОР %s" % D["short"], func():
				e.study(id)
				offers(), func(): return "действий нет" if e.actions <= 0 else "", {"icon": "🔍", "sub": "прочитать мелкий шрифт", "value": "1 действие", "col": D["col"]}])
			items.append(["ПОЗВОНИТЬ ОПЕРАТОРУ %s" % D["short"], func():
				e.call_operator(id)
				offers(), Callable(), {"icon": "☎", "sub": "оператор скажет, но нервы потратишь", "value": "+6 стресса", "col": D["col"]}])
	if e.offers.is_empty():
		lines.append("Сегодня никто не даёт — репутация или день не тот.")
	items.append(["КАРТА ДОЛГОВ: РЕФИНАНСИРОВАТЬ", func(): debt_flow(), Callable(), {"icon": "🗺", "sub": "объединить займы в один", "value": "", "col": RED}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "←", "sub": "", "value": "", "col": GREY}])
	open("ЗАЙМЫ", lines, items, 1100.0)

# ---------------- подработки ----------------
func jobs() -> void:
	screen = "jobs"
	var e := econ()
	var C: MLCareer = e.career
	var items: Array = []
	var icons := {"podezd": "🧹", "repair": "🔧", "deliv": "📦", "sound": "🎛", "junk": "🗃"}
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
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "←", "sub": "", "value": "", "col": GREY}])
	open("ПОДРАБОТКИ", ["Каждая — своя 3D-игра. Чем лучше сделал, тем больше заплатят; стресс мешает; навыки открывают сложные заказы."], items, 1100.0)

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
			items_screen(), Callable(), {"icon": "🏷", "thumb": "junk_%d" % idx, "sub": "%s\nразобрать: %s · Гене: %s" % [it[1], rub(int(it[4])), rub(int(it[3])) if int(it[3]) > 0 else "не возьмёт"], "value": "продать " + rub(int(it[2])), "tag": "вещь", "col": Color(0.8, 0.7, 0.5)}])
		if not reshim.is_empty() and int(it[3]) > 0:
			var rid := int(reshim[0]["id"])
			items.append(["ОТДАТЬ ГЕНЕ: %s" % it[0], func():
				e.barter(kk, rid)
				items_screen(), Callable(), {"icon": "🤝", "thumb": "junk_%d" % idx, "sub": "«Решим вопрос» спишет часть долга", "value": "−" + rub(int(it[3])), "tag": "бартер", "col": Color(0.7, 1.0, 0.55)}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "←", "sub": "", "value": "", "col": GREY}])
	open("ВЕЩИ", ["Оставленное из хлама. Продать, отдать «Решим вопрос» в счёт долга (Гена берёт не всё) или держать до лучшей цены."] if not e.inventory.is_empty() else ["Пусто. Вещи появляются, если в разборе хлама выбрать «ОСТАВИТЬ»."], items, 1100.0)

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
			shop(), func(): return "" if not e.upgrades.has(u) and e.money >= int(U["cost"]) else ("куплено" if e.upgrades.has(u) else "не хватает денег"), {"icon": "🛒", "thumb": "up_" + u, "sub": String(U["desc"]), "value": "КУПЛЕНО" if e.upgrades.has(u) else rub(int(U["cost"])), "tag": "на неделю", "col": Color(0.4, 0.9, 0.45)}])
	items.append(["НАЗАД", func(): show_phase(), Callable(), {"icon": "←", "sub": "", "value": "", "col": GREY}])
	open("МАГАЗИН", ["Покупки меняют, как играть: мелкий шрифт, точные цифры, лишнее действие, новые ответы в переговорах. Действуют до конца недели."], items, 1100.0)

# ---------------- пауза и концовка ----------------
func pause_menu() -> void:
	open("ПАУЗА", ["Игра сохраняется сама после каждой фазы."], [
		["ПРОДОЛЖИТЬ", func(): show_phase()],
		["ЗАНОВО (новая неделя)", func():
			econ().new_game(int(Time.get_ticks_usec() % 2147483647))
			show_phase()],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu()]])
	screen = "pause"

func ending() -> void:
	screen = "ending"
	var e := econ()
	var E: Array = MLData.ENDINGS.get(e.ending, MLData.ENDINGS["pit"])
	MLSave.record_ending(e)
	var lines: Array = [String(E[1]), "", "День %d · деньги %s · долг %s" % [e.day, rub(e.money), rub(e.total_debt())],
		"Займов взято: %d · закрыто: %d (переговорами: %d) · подработок: %d" % [int(e.stats["taken"]), int(e.stats["closed"]), int(e.stats["talk_closed"]), int(e.stats["jobs"])],
		"Переплачено процентами %s, штрафами и комиссиями %s" % [rub(int(e.stats["interest"])), rub(int(e.stats["fines"]))]]
	var all: Dictionary = MLSave.load_all().get("endings", {})
	lines.append("Открыто концовок: %d из %d" % [all.size(), MLData.ENDINGS.size()])
	if e.career != null and e.career.prestige_ready():
		lines.append("Открыта ЛЕГЕНДА РАЙОНА — можно начать новый цикл с АВТОРИТЕТОМ.")
	open(String(E[0]), lines, [
		["ЛЕГЕНДА РАЙОНА", func(): legend_screen(), func(): return "" if e.career != null and e.career.prestige_ready() else "уровень %d или %s за цикл" % [MLTree.LEGEND_LEVEL, rub(MLTree.LEGEND_EARN)]],
		["ЕЩЁ НЕДЕЛЯ", func():
			e.new_game(int(Time.get_ticks_usec() % 2147483647))
			intro()
			show_phase()],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu()]], 1000.0)
	root.react("money" if e.ending != "pit" else "bad")
