## Интерфейс ночи «5 НОЧЕЙ С ПАХАНОМ» — минимальный, чтобы не ломать атмосферу: время и ночь, энергия с расходом
## и прогнозом, планшет камер (картинка, подпись, метка времени, карта), субтитры звонка и реплик, ложные тревоги
## MOD, экран 6 AM, экран гибели, «последний шанс» с генератором, пауза. Поверх всего — экранный шейдер в духе
## GOD OF GRIMERKA: монохром с сохранённым красным, полутон в тенях, зерно, виньетка (сила — настройка).
class_name FNUI
extends CanvasLayer

const RED := Color(0.86, 0.08, 0.06)
const DIM := Color(0.75, 0.72, 0.66)
const POST := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float fx = 1.0;
uniform float t = 0.0;
uniform float hurt = 0.0;        // всплеск искажения (скример, одержимость)
uniform float dark = 0.0;
uniform float inv = 0.0;         // вывернутые цвета (скример GHOST)
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float ab = (0.0015 + hurt * 0.012) * fx;
	vec3 c;
	c.r = texture(scr, uv + vec2(ab, 0.0)).r;
	c.g = texture(scr, uv).g;
	c.b = texture(scr, uv - vec2(ab, 0.0)).b;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float red = clamp((c.r - max(c.g, c.b)) * 2.2, 0.0, 1.0);
	vec3 mono = vec3(l) * vec3(1.02, 0.99, 0.94);
	vec3 col = mix(mono, vec3(c.r * 1.1, c.g * 0.35, c.b * 0.3), red);
	// полутон в тенях: точки решёткой
	vec2 g = FRAGCOORD.xy / 5.0;
	float dotm = length(fract(g) - 0.5);
	float shade = smoothstep(0.32, 0.0, l);
	col *= 1.0 - shade * smoothstep(0.18, 0.42, dotm) * 0.55 * fx;
	col += (h(FRAGCOORD.xy + t * 61.0) - 0.5) * 0.07 * fx;
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * (1.1 + dark * 1.5);
	col = mix(col, col * vec3(1.3, 0.5, 0.45), hurt * 0.4);
	col = mix(col, vec3(1.0) - col, inv);
	COLOR = vec4(col, 1.0);
}
"""

var root                            # FiveNightsRoot
var big: Font
var mono: SystemFont
var post: ColorRect
var post_mat: ShaderMaterial
var hud: Control
var time_l: Label
var night_l: Label
var power_l: Label
var usage_bars: Array = []
var eta_l: Label
var alarm_l: Label
var alarm_t := 0.0
var msg_l: Label
var msg_t := 0.0
var sub_l: Label
var hint_l: Label
var tablet: Control
var tablet_k := 0.0
var feed: TextureRect
var cam_l: Label
var stamp_l: Label
var rec_dot: ColorRect
var jam_l: Label
var ping_l: Label
var map_btns := {}                  # id → Button
var cam9_btn: Button
var card: Control                   # заставка ночи / 6 AM / гибель
var dark_box: Control
var dark_bar: ColorRect
var pause_box: Control
var t := 0.0
var fx_k := 1.0
var hurt := 0.0
var card_gen := 0
var inv_t := 0.0
var neg := false                     # цветокор «негатив» целиком (скример Пахана)                    # поколение карточки: отложенные вызовы старой карточки не рисуют поверх новой

func setup(r) -> void:
	root = r
	layer = 5
	big = load("res://assets/fonts/RussoOne-Regular.ttf")
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POST
	post_mat.shader = sh
	post.material = post_mat
	add_child(post)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	night_l = _label(hud, "", 22, DIM, big)
	time_l = _label(hud, "", 54, Color(0.92, 0.9, 0.85), big)
	power_l = _label(hud, "", 22, DIM, mono)
	eta_l = _label(hud, "", 16, Color(0.6, 0.58, 0.54), mono)
	for k in 6:
		var b := ColorRect.new()
		b.size = Vector2(16, 26)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(b)
		usage_bars.append(b)
	alarm_l = _label(hud, "", 30, RED, big)
	alarm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l = _label(hud, "", 24, Color(0.95, 0.93, 0.88), big)
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l = _label(hud, "", 22, Color(0.92, 0.9, 0.84), mono)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_l = _label(hud, "", 15, Color(0.62, 0.6, 0.56), mono)
	_tablet()
	_dark()
	_pause()
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _label(parent: Control, text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size

func _layout() -> void:
	var s := _vs()
	night_l.position = Vector2(s.x - 260, 22)
	night_l.size = Vector2(230, 30)
	night_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_l.position = Vector2(s.x - 360, 46)
	time_l.size = Vector2(330, 70)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_l.position = Vector2(28, s.y - 112)
	eta_l.position = Vector2(28, s.y - 36)
	for k in usage_bars.size():
		(usage_bars[k] as ColorRect).position = Vector2(30 + k * 21, s.y - 76)
	alarm_l.position = Vector2(0, 26)
	alarm_l.size = Vector2(s.x, 40)
	msg_l.position = Vector2(0, s.y * 0.62)
	msg_l.size = Vector2(s.x, 40)
	sub_l.position = Vector2(s.x * 0.15, s.y - 150)
	sub_l.size = Vector2(s.x * 0.7, 80)
	hint_l.position = Vector2(s.x - 520, s.y - 100)
	hint_l.size = Vector2(500, 90)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if tablet != null:
		tablet.size = s
		feed.position = Vector2(s.x * 0.08, s.y * 0.07)
		feed.size = Vector2(s.x * 0.84, s.y * 0.8)
		cam_l.position = feed.position + Vector2(22, 16)
		stamp_l.position = feed.position + Vector2(feed.size.x - 360, 16)
		stamp_l.size = Vector2(340, 30)
		rec_dot.position = feed.position + Vector2(feed.size.x - 30, 58)
		jam_l.position = feed.position + Vector2(0, feed.size.y * 0.45)
		jam_l.size = Vector2(feed.size.x, 40)
		ping_l.position = feed.position + Vector2(22, feed.size.y - 46)
		var mp := feed.position + feed.size - Vector2(330, 250)
		for id in map_btns:
			var c := FNData.cam(id)
			var b: Button = map_btns[id]
			b.position = mp + (c["map"] as Vector2) * Vector2(300, 220)
		cam9_btn.position = mp + (FNData.CAM9["map"] as Vector2) * Vector2(300, 220)
	if dark_box != null:
		dark_box.position = Vector2(s.x * 0.5 - 230, s.y - 170)
		pause_box.position = s * 0.5 - Vector2(220, 150)

# ---------------- планшет камер ----------------
func _tablet() -> void:
	tablet = Control.new()
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.visible = false
	add_child(tablet)
	var bezel := ColorRect.new()
	bezel.color = Color(0.02, 0.02, 0.02, 0.96)
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(bezel)
	feed = TextureRect.new()
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.stretch_mode = TextureRect.STRETCH_SCALE
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(feed)
	cam_l = _label(tablet, "", 30, RED, big)
	stamp_l = _label(tablet, "", 18, Color(0.85, 0.85, 0.8), mono)
	stamp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec_dot = ColorRect.new()
	rec_dot.size = Vector2(14, 14)
	rec_dot.color = RED
	rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(rec_dot)
	jam_l = _label(tablet, "", 34, Color(0.9, 0.9, 0.9), big)
	jam_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ping_l = _label(tablet, "", 18, RED, mono)
	for c in FNData.CAMS:
		var b := _cam_btn(String(c["no"]), String(c["id"]))
		map_btns[c["id"]] = b
	cam9_btn = _cam_btn("9", "room9")
	cam9_btn.visible = false

func _cam_btn(no: String, id: String) -> Button:
	var b := Button.new()
	b.text = "CAM %s" % no
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", mono)
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(70, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	sb.border_color = Color(0.7, 0.7, 0.65)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.35, 0.05, 0.04, 0.95)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.pressed.connect(func(): root.pick_cam(id))
	tablet.add_child(b)
	return b

# ---------------- темнота и пауза ----------------
func _dark() -> void:
	dark_box = Control.new()
	dark_box.visible = false
	dark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark_box)
	var l := _label(dark_box, "РУЧНОЙ ГЕНЕРАТОР — КРУТИ: A / D ПО ОЧЕРЕДИ", 20, Color(0.9, 0.86, 0.8), big)
	l.position = Vector2(0, 0)
	var back := ColorRect.new()
	back.color = Color(0.15, 0.15, 0.15)
	back.position = Vector2(0, 40)
	back.size = Vector2(460, 16)
	dark_box.add_child(back)
	dark_bar = ColorRect.new()
	dark_bar.color = RED
	dark_bar.position = Vector2(0, 40)
	dark_bar.size = Vector2(0, 16)
	dark_box.add_child(dark_bar)

func _pause() -> void:
	pause_box = Control.new()
	pause_box.visible = false
	add_child(pause_box)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.size = Vector2(440, 300)
	pause_box.add_child(bg)
	var l := _label(pause_box, "ПАУЗА", 44, RED, big)
	l.position = Vector2(30, 20)
	var y := 100
	for it in [["ПРОДОЛЖИТЬ", func(): root.set_paused(false)], ["ЗАНОВО", func(): root.retry()], ["В МЕНЮ ОХРАНЫ", func(): root.to_terminal()]]:
		var b := Button.new()
		b.text = it[0]
		b.add_theme_font_override("font", big)
		b.add_theme_font_size_override("font_size", 26)
		b.position = Vector2(30, y)
		b.size = Vector2(380, 50)
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
		b.add_theme_color_override("font_hover_color", RED)
		b.pressed.connect(it[1])
		pause_box.add_child(b)
		y += 60

# ---------------- каждый кадр ----------------
func tick(st: FNNight, dt: float, cams: FNCams) -> void:
	t += dt
	hurt = maxf(0.0, hurt - dt * 1.5)
	var g: FNGhost = st.enemies["ghost"]
	post_mat.set_shader_parameter("t", t)
	post_mat.set_shader_parameter("fx", fx_k)
	post_mat.set_shader_parameter("hurt", maxf(hurt, g.haunt * 0.6))
	post_mat.set_shader_parameter("dark", 1.0 if st.power_out else 0.0)
	inv_t = maxf(0.0, inv_t - dt)
	post_mat.set_shader_parameter("inv", 1.0 if neg or (inv_t > 0.0 and fposmod(t, 0.12) < 0.08) else 0.0)
	var night_name := "CUSTOM NIGHT" if st.night >= FNData.NIGHTS.size() else "НОЧЬ %d" % (st.night + 1)
	night_l.text = night_name
	time_l.text = st.clock()
	power_l.text = "ЭНЕРГИЯ  %d%%" % ceili(st.power)
	power_l.add_theme_color_override("font_color", RED if st.power < 15.0 else DIM)
	var hide_usage := st.glitches.has("usage_hide")
	for k in usage_bars.size():
		var b: ColorRect = usage_bars[k]
		b.visible = not hide_usage and not st.power_out
		b.color = (RED if k >= 3 else Color(0.85, 0.82, 0.75)) if k < st.usage else Color(0.2, 0.2, 0.2, 0.6)
	var eta := st.time_left()
	eta_l.text = "НАГРУЗКА %d · ХВАТИТ НА ~%d:%02d" % [st.usage, int(eta) / 60, int(eta) % 60] if not hide_usage and not st.power_out else ("НАГРУЗКА ??" if hide_usage else "")
	power_l.visible = not st.power_out
	# ложная тревога MOD
	alarm_t = maxf(0.0, alarm_t - dt)
	alarm_l.visible = alarm_t > 0.0 and fposmod(t, 0.5) < 0.35
	msg_t = maxf(0.0, msg_t - dt)
	msg_l.modulate.a = clampf(msg_t, 0.0, 1.0)
	# планшет
	var want := 1.0 if st.monitor else 0.0
	tablet_k = move_toward(tablet_k, want, dt * 5.0)
	tablet.visible = tablet_k > 0.01
	tablet.position.y = (1.0 - ease(tablet_k, 0.4)) * _vs().y
	if tablet.visible:
		feed.material = cams.mat
		var i := FNData.CAMS.map(func(c): return c["id"]).find(st.cam)
		var label := FNData.CAM9["name"] if st.cam == "room9" else st.cam_label(maxi(i, 0))
		var no := "9" if st.cam == "room9" else str(maxi(i, 0) + 1)
		cam_l.text = "CAM %s · %s" % [no, label]
		stamp_l.text = "%s  %s  REC" % [night_name, st.clock()]
		rec_dot.visible = fposmod(t, 1.0) < 0.6
		jam_l.text = "НЕТ СИГНАЛА" if st.cams_dead() else ("ПОМЕХИ" if st.jammed(st.cam) else "")
		var bot: FNBot = st.enemies["bot"]
		if bot.ping_left > 0.0:
			ping_l.text = "СЕРВЕР: ПИНГ — %s  %d с" % ["ПРИНИМАЮ…" if st.cam == "server" else "ОТКРОЙ CAM 6", ceili(bot.ping_left)] if not st.glitches.has("leds_off") else ""
		else:
			ping_l.text = ""
		for id in map_btns:
			var b: Button = map_btns[id]
			b.modulate = Color(1, 0.4, 0.35) if id == st.cam else Color(1, 1, 1)
			var ii := FNData.CAMS.map(func(c): return c["id"]).find(id)
			b.text = "CAM %d" % (ii + 1)

func msg(text: String, sec := 3.0) -> void:
	msg_l.text = text
	msg_t = sec

func alarm(text: String) -> void:
	alarm_l.text = text
	alarm_t = 3.5

func sub(text: String) -> void:
	sub_l.text = text

func hints(text: String) -> void:
	hint_l.text = text

func show_dark(on: bool, k := 0.0) -> void:
	dark_box.visible = on
	dark_bar.size.x = 460.0 * clampf(k, 0.0, 1.0)

# ---------------- карточки: начало ночи, 6 AM, гибель ----------------
func clear_card() -> void:
	card_gen += 1
	for c in card.get_children():
		c.queue_free()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bg(a := 1.0) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, a)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)
	return bg

func _center(text: String, size: int, col: Color, y: float, font: Font) -> Label:
	var l := _label(card, text, size, col, font)
	l.position = Vector2(0, y)
	l.size = Vector2(_vs().x, size + 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func night_card(title: String, sub_t: String) -> void:
	clear_card()
	var g := card_gen
	var bg := _bg()
	var s := _vs()
	var a := _center("12:00 AM", 70, Color(0.92, 0.9, 0.85), s.y * 0.36, big)
	var b := _center(title, 40, RED, s.y * 0.36 + 90, big)
	var c := _center(sub_t, 20, DIM, s.y * 0.36 + 150, mono)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(bg, "color:a", 0.0, 1.2)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(b, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func(): if g == card_gen: clear_card())

func six_card(pay: int, line: String, extra := "") -> void:
	clear_card()
	var g := card_gen
	_bg()
	var s := _vs()
	var five := _center("5 AM", 110, Color(0.92, 0.9, 0.85), s.y * 0.32, big)
	var six := _center("6 AM", 110, Color(0.92, 0.9, 0.85), s.y * 0.32 + 130, big)
	six.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(five, "position:y", s.y * 0.32 - 130, 1.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(five, "modulate:a", 0.0, 1.2)
	tw.parallel().tween_property(six, "position:y", s.y * 0.32, 1.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(six, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		if g != card_gen:
			return
		_center(line, 24, DIM, s.y * 0.32 + 150, big)
		_center("Уведомление банка: зачислена зарплата %d ₽" % pay, 18, Color(0.55, 0.85, 0.6), s.y * 0.32 + 200, mono)
		if extra != "":
			var e := _center(extra, 18, RED, s.y * 0.32 + 240, mono)
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART)

func dead_card(killer: String, hint: String, buttons: Array) -> void:
	clear_card()
	var g := card_gen
	var bg := _bg(0.0)
	var s := _vs()
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.94, 0.4)
	tw.tween_callback(func():
		if g != card_gen:
			return
		_center("ПАХАН УМЕР", 72, RED, s.y * 0.26, big)
		_center(killer, 26, DIM, s.y * 0.26 + 96, big)
		var h := _center(hint, 18, Color(0.7, 0.68, 0.62), s.y * 0.26 + 150, mono)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.size = Vector2(s.x * 0.6, 80)
		h.position.x = s.x * 0.2
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var y := s.y * 0.26 + 260
		for it in buttons:
			var b := Button.new()
			b.text = it[0]
			b.add_theme_font_override("font", big)
			b.add_theme_font_size_override("font_size", 28)
			b.flat = true
			b.size = Vector2(360, 50)
			b.position = Vector2(s.x * 0.5 - 180, y)
			b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
			b.add_theme_color_override("font_hover_color", RED)
			b.pressed.connect(it[1])
			card.add_child(b)
			y += 60)

func show_pause(on: bool) -> void:
	pause_box.visible = on
