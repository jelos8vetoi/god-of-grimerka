## Интерфейс гонки в стиле GOD OF GRIMERKA (ч/б манга, рваные белые плашки, красный акцент) на столе 1600×900,
## который вписывается в окно: место «1/6», круг «1/3», время гонки и круга, скорость, заряд заноса (три деления),
## турбо, предмет в руках, мини-карта трассы с точками гонщиков, отсчёт 3-2-1-ЖМИ, «НЕ ТУДА», лента событий,
## пыль на экране, результаты и пауза. Только показывает — правила гонки в race.gd.
class_name RaceHud
extends CanvasLayer

const STAGE := Vector2(1600, 900)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const RED := Color(0.86, 0.09, 0.11)

var race
var root: Control
var stage: Control
var serif: SystemFont
var tech: SystemFont
var pos_l: Label
var pos_of: Label
var lap_l: Label
var time_l: Label
var lap_time_l: Label
var best_l: Label
var speed_l: Label
var pips: Array = []
var turbo_bar: ColorRect
var turbo_back: ColorRect
var item_card: Polygon2D
var item_icon: Label
var item_name: Label
var item_key: Label
var shield_l: Label
var map: Control
var count_l: Label
var count_shown := -1
var wrong_l: Label
var flash_l: Label
var feed_box: VBoxContainer
var dust: ColorRect
var results_panel: Control
var pause_panel: Control
var menu_rows: Array = []      # [Label, Callable] — пункты открытого экрана (результаты или пауза)
var menu_sel := 0
var item_seen := ""
var item_vp: SubViewport       # предмет в карточке — настоящая модель, крутится
var item_pivot: Node3D
var lap_plate: Polygon2D
var final_on := false
var trick_l: Label
var combo_l: Label
var combo_bar: ColorRect
var boost_l: Label
var tip_l: Label               # совет перед стартом (облёт и отсчёт)
static var tip_n := -1         # какой совет показать: каждый заезд — следующий
var weather_l: Label
var happen_l: Label
var happen_sub: Label

var tips: MGHints                  # подсказки и справка (H) — mg_hints.gd

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# подсказки гонки — слева посередине (место — слева сверху, карта — слева снизу)
	tips = MGHints.new().setup("race", MGHintsData.RACE, "left", 0.47)
	add_child(tips)
	dust = ColorRect.new()
	dust.color = Color(0.55, 0.5, 0.43, 0.0)
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dust)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	root.size = vs
	dust.size = vs
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func _text(parent: Node, s: String, size: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else tech)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _torn(w: float, h: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	var x := 16.0                      # углы не заходят друг на друга: иначе многоугольник не рисуется
	while x < w - 20.0:
		pts.append(Vector2(x, rng.randf_range(-4.0, 4.0)))
		x += rng.randf_range(8.0, 22.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + rng.randf_range(-8.0, 10.0), y))
		y += rng.randf_range(7.0, 14.0)
	x = w - 20.0
	while x > 16.0:
		pts.append(Vector2(x, h + rng.randf_range(-4.0, 5.0)))
		x -= rng.randf_range(8.0, 22.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(rng.randf_range(-10.0, 6.0), y))
		y -= rng.randf_range(7.0, 14.0)
	return pts

func _build() -> void:
	# слева сверху: место и круг
	var pc := Polygon2D.new()
	pc.polygon = _torn(250, 150, 3)
	pc.color = WHITE
	pc.position = Vector2(30, 26)
	pc.rotation = deg_to_rad(-3.0)
	stage.add_child(pc)
	_text(pc, "МЕСТО", 16, INK, Vector2(16, 8)).remove_theme_constant_override("outline_size")
	pos_l = _text(pc, "1", 110, INK, Vector2(14, 6), serif)
	pos_l.remove_theme_constant_override("outline_size")
	pos_of = _text(pc, "/6", 40, RED, Vector2(110, 70), serif)
	pos_of.remove_theme_constant_override("outline_size")
	var red := Polygon2D.new()
	red.polygon = PackedVector2Array([Vector2(0, 0), Vector2(220, -6), Vector2(216, 30), Vector2(-4, 34)])
	red.color = RED
	red.position = Vector2(40, 182)
	red.rotation = deg_to_rad(-3.0)
	stage.add_child(red)
	lap_plate = red
	lap_l = _text(red, "LAP 1 / 3", 24, WHITE, Vector2(14, 0), serif)
	# сверху по центру: время
	time_l = _text(stage, "00:00.00", 40, WHITE, Vector2(680, 22), serif)
	time_l.size = Vector2(240, 50)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_time_l = _text(stage, "", 18, SILVER, Vector2(640, 72))
	lap_time_l.size = Vector2(320, 24)
	lap_time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_l = _text(stage, "", 15, GREY, Vector2(640, 96))
	best_l.size = Vector2(320, 20)
	best_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# справа сверху: предмет
	item_card = Polygon2D.new()
	item_card.polygon = _torn(170, 150, 11)
	item_card.color = Color(0.05, 0.05, 0.06, 0.85)
	item_card.position = Vector2(1400, 30)
	item_card.rotation = deg_to_rad(3.0)
	stage.add_child(item_card)
	var edge := Line2D.new()
	edge.points = item_card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	item_card.add_child(edge)
	item_icon = _text(item_card, "", 64, WHITE, Vector2(0, 8), serif)
	item_icon.size = Vector2(170, 80)
	item_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name = _text(item_card, "ПУСТО", 16, GREY, Vector2(0, 96))
	item_name.size = Vector2(170, 22)
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_key = _text(stage, "", 14, SILVER, Vector2(1400, 190))
	item_key.size = Vector2(170, 20)
	item_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_l = _text(stage, "", 18, Color(0.6, 1.0, 0.7), Vector2(1390, 214), serif)
	shield_l.size = Vector2(190, 24)
	shield_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_l = _text(stage, "", 18, Color(0.4, 0.9, 1.0), Vector2(1390, 238), serif)
	boost_l.size = Vector2(190, 24)
	boost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# предмет — своя маленькая сцена: модель крутится в карточке (значок-символ остаётся запасным)
	item_vp = SubViewport.new()
	item_vp.size = Vector2i(300, 200)
	item_vp.transparent_bg = true
	item_vp.own_world_3d = true
	item_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(item_vp)
	var icam := Camera3D.new()
	icam.fov = 30.0
	icam.position = Vector3(0, 0.25, 2.3)
	item_vp.add_child(icam)
	icam.look_at(Vector3.ZERO, Vector3.UP)
	var ilight := DirectionalLight3D.new()
	ilight.rotation = Vector3(-0.8, 0.6, 0)
	ilight.light_energy = 1.6
	item_vp.add_child(ilight)
	var ienv := WorldEnvironment.new()
	var ie := Environment.new()
	ie.background_mode = Environment.BG_COLOR
	ie.background_color = Color(0, 0, 0, 0)
	ie.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ie.ambient_light_color = Color(0.75, 0.75, 0.8)
	ie.ambient_light_energy = 0.9
	ienv.environment = ie
	item_vp.add_child(ienv)
	item_pivot = Node3D.new()
	item_vp.add_child(item_pivot)
	var itex := TextureRect.new()
	itex.texture = item_vp.get_texture()
	# сначала режим растяжения, потом размер: иначе размер упирается в кадр сценки (300×200), и предмет уезжает
	# вправо-вниз на своё название
	itex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	itex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	itex.position = Vector2(10, 2)
	itex.size = Vector2(150, 92)
	itex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_card.add_child(itex)
	# совет перед стартом: одна строка внизу по центру, гаснет на «ЖМИ»
	tip_l = _text(stage, "", 22, WHITE, Vector2(200, 800))
	tip_l.size = Vector2(STAGE.x - 400, 60)
	tip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_l.add_theme_constant_override("outline_size", 8)
	var tps: Array = RaceData.TIPS
	if tip_n < 0:
		tip_n = randi() % tps.size()
	tip_n += 1
	var tip: String = tps[tip_n % tps.size()]
	for a in ["race_drift", "race_jump", "race_boost"]:
		tip = tip.replace("{%s}" % a, "[%s]" % " / ".join(RaceSave.keys_of(a)))
	tip_l.text = tip
	# трюки и комбо — над спидометром и по центру снизу
	trick_l = _text(stage, "", 44, Color(1.0, 0.85, 0.25), Vector2(0, 560), serif)
	trick_l.size = Vector2(STAGE.x, 56)
	trick_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trick_l.add_theme_constant_override("outline_size", 12)
	trick_l.modulate.a = 0.0
	combo_l = _text(stage, "", 30, Color(1.0, 0.85, 0.25), Vector2(1290, 668), serif)
	combo_l.size = Vector2(270, 36)
	combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_bar = ColorRect.new()
	combo_bar.position = Vector2(1350, 706)
	combo_bar.size = Vector2(0, 5)
	combo_bar.color = Color(1.0, 0.85, 0.25)
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(combo_bar)
	# справа снизу: скорость, занос, турбо
	var sc := Polygon2D.new()
	sc.polygon = _torn(300, 150, 21)
	sc.color = Color(0.03, 0.03, 0.035, 0.8)
	sc.position = Vector2(1270, 716)
	stage.add_child(sc)
	speed_l = _text(stage, "0", 72, WHITE, Vector2(1280, 712), serif)
	speed_l.size = Vector2(170, 80)
	speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text(stage, "КМ/Ч", 18, SILVER, Vector2(1458, 760))
	_text(stage, "ЗАНОС", 13, GREY, Vector2(1290, 800))
	for k in 3:
		var pp := Polygon2D.new()
		pp.polygon = PackedVector2Array([Vector2(0, 0), Vector2(34, 0), Vector2(28, 14), Vector2(-6, 14)])
		pp.position = Vector2(1350 + k * 40, 802)
		pp.color = Color(0.25, 0.25, 0.27)
		stage.add_child(pp)
		pips.append(pp)
	_text(stage, "ТУРБО", 13, GREY, Vector2(1290, 826))
	turbo_back = ColorRect.new()
	turbo_back.position = Vector2(1350, 830)
	turbo_back.size = Vector2(200, 10)
	turbo_back.color = Color(0.2, 0.2, 0.22)
	turbo_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(turbo_back)
	turbo_bar = ColorRect.new()
	turbo_bar.position = turbo_back.position
	turbo_bar.size = Vector2(0, 10)
	turbo_bar.color = WHITE
	turbo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(turbo_bar)
	# слева снизу: мини-карта
	map = Control.new()
	map.position = Vector2(30, 640)
	map.size = Vector2(230, 230)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(_draw_map)
	stage.add_child(map)
	# центр: отсчёт, «не туда», вспышки, лента
	count_l = _text(stage, "", 220, WHITE, Vector2(0, 220), serif)
	count_l.size = Vector2(STAGE.x, 260)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.add_theme_constant_override("outline_size", 22)
	wrong_l = _text(stage, "НЕ ТУДА!", 64, RED, Vector2(0, 300), serif)
	wrong_l.size = Vector2(STAGE.x, 80)
	wrong_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_l.add_theme_constant_override("outline_size", 14)
	wrong_l.visible = false
	flash_l = _text(stage, "", 54, WHITE, Vector2(0, 170), serif)
	flash_l.size = Vector2(STAGE.x, 70)
	flash_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_l.add_theme_constant_override("outline_size", 14)
	weather_l = _text(stage, "", 16, SILVER, Vector2(640, 116))
	weather_l.size = Vector2(320, 22)
	weather_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	happen_l = _text(stage, "", 46, Color(1.0, 0.85, 0.25), Vector2(0, 600), serif)
	happen_l.size = Vector2(STAGE.x, 60)
	happen_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	happen_l.add_theme_constant_override("outline_size", 14)
	happen_sub = _text(stage, "", 18, WHITE, Vector2(0, 656))
	happen_sub.size = Vector2(STAGE.x, 26)
	happen_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feed_box = VBoxContainer.new()
	feed_box.position = Vector2(560, 150)
	feed_box.size = Vector2(480, 120)
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(feed_box)

# ---------------- каждый кадр ----------------
func _process(dt: float) -> void:
	if race == null:
		return
	var me: RaceRider = race.local
	var n: int = race.riders.size()
	if me != null:
		pos_l.text = str(me.rank)
		pos_of.text = "/%d" % n
		pos_of.position.x = 30.0 + pos_l.get_minimum_size().x
		var last_lap: bool = me.lap + 1 >= race.laps and race.laps > 1 and not me.finished
		lap_l.text = ("FINAL LAP" if last_lap else "LAP %d / %d" % [mini(me.lap + 1, race.laps), race.laps]) if not me.finished else "ФИНИШ"
		if final_on and last_lap:
			# последний круг — плашка бьётся, как пульс
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			lap_plate.color = RED.lerp(Color(1.0, 0.55, 0.2), pulse * (0.0 if float(Opts.v("shake")) <= 0.0 else 1.0))
			lap_plate.scale = Vector2.ONE * (1.0 + 0.05 * pulse)
		else:
			lap_plate.color = RED
			lap_plate.scale = Vector2.ONE
		var lt: float = race.t - me.lap_t0 if race.go and not me.finished else 0.0
		lap_time_l.text = ("КРУГ  " + fmt(lt)) if race.go and not me.finished else ""
		var best: float = me.best_lap
		var rec := RaceSave.best(String(race.cfg.get("track", "")), "lap")
		best_l.text = ("ЛУЧШИЙ КРУГ  " + fmt(best) if best > 0.0 else "") + ("   ·   РЕКОРД  " + fmt(rec) if rec > 0.0 else "")
		speed_l.text = str(int(round(absf(me.speed) * 3.6)))
		var lv: int = me.drift_lvl if me.drifting else 0
		for k in 3:
			(pips[k] as Polygon2D).color = race._drift_col(k + 1) if lv > k else Color(0.25, 0.25, 0.27)
		turbo_bar.size.x = 200.0 * me.turbo / float(RaceData.PHYS["turbo_max"])
		turbo_bar.color = RED if me.turbo_on else (WHITE if me.turbo >= float(RaceData.PHYS["turbo_min"]) else GREY)
		if me.item != item_seen:
			item_seen = me.item
			for c in item_pivot.get_children():
				c.queue_free()
			item_icon.text = ""
			if me.item == "":
				item_name.text = "ПУСТО"
				item_name.add_theme_color_override("font_color", GREY)
				item_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			else:
				var I: Dictionary = RaceData.ITEMS[me.item]
				item_pivot.add_child(RaceItems.model(me.item, 1.2))
				item_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				item_name.text = String(I["name"])
				item_name.add_theme_color_override("font_color", WHITE)
				# длинное название («ПЫЛЕВОЙ ВЗРЫВ») — мельче, чтобы влезло в карточку
				var fs := 16
				var f: Font = item_name.get_theme_font("font")
				while fs > 11 and f.get_string_size(item_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 156.0:
					fs -= 1
				item_name.add_theme_font_size_override("font_size", fs)
		if me.item != "":
			item_pivot.rotation.y += dt * 1.8
			item_pivot.rotation.x = sin(Time.get_ticks_msec() * 0.002) * 0.15
		item_key.text = ("[%s] ИСПОЛЬЗОВАТЬ" % " / ".join(RaceSave.keys_of("race_item"))) if me.item != "" else ""
		item_card.visible = String(race.cfg.get("mode", "single")) != "time"
		shield_l.text = "ФИЛЬТР %.0f с" % me.shield_t if me.shield_t > 0.0 else ""
		boost_l.text = "РАЗГОН МОТОРА %.0f с" % me.overclock_t if me.overclock_t > 0.0 else ("ВОЗДУШНЫЙ МЕШОК" if me.draft > 0.5 else "")
		combo_l.text = "КОМБО ×%d" % me.combo if me.combo >= 2 else ""
		combo_bar.size.x = 200.0 * clampf(me.combo_t / float(RaceData.PHYS["combo_t"]), 0.0, 1.0) if me.combo >= 2 else 0.0
		@warning_ignore("integer_division")
		wrong_l.visible = me.wrong_t > float(RaceData.PHYS["wrong_way"]) and not me.finished and int(Time.get_ticks_msec() / 300) % 2 == 0
	tip_l.modulate.a = move_toward(tip_l.modulate.a, 1.0 if race.state in ["intro", "countdown"] else 0.0, dt * 3.0)
	time_l.text = fmt(race.t)
	if race.weather != null:
		var Wd: Dictionary = race.weather.W
		weather_l.text = "%s %s" % [String(Wd.get("icon", "")), String(Wd.get("name", ""))] + ("  ·  ветер %d м/с" % int(race.weather.wind.length()) if race.weather.wind.length() > 0.5 else "")
	dust.color.a = clampf(race.dust_vis, 0.0, 1.0) * 0.55
	map.queue_redraw()

static func fmt(t: float) -> String:
	t = maxf(0.0, t)
	return "%02d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]

func _draw_map() -> void:
	var xf: RaceTrack = race.track
	if xf == null or xf.P.size() < 2:
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in xf.P:
		mn = mn.min(Vector2(p.x, p.z))
		mx = mx.max(Vector2(p.x, p.z))
	var span := mx - mn
	var k: float = minf((map.size.x - 20.0) / span.x, (map.size.y - 20.0) / span.y)
	var off := (map.size - span * k) * 0.5
	var to := func(p: Vector3) -> Vector2: return off + (Vector2(p.x, p.z) - mn) * k
	map.draw_rect(Rect2(Vector2.ZERO, map.size), Color(0, 0, 0, 0.45))
	var pts := PackedVector2Array()
	for i in range(0, xf.P.size(), 3):
		pts.append(to.call(xf.P[i]))
	pts.append(pts[0])
	map.draw_polyline(pts, Color(0.95, 0.95, 0.95, 0.85), 5.0, true)
	if xf.SP.size() > 1:
		var sp := PackedVector2Array()
		for i in range(0, xf.SP.size(), 3):
			sp.append(to.call(xf.SP[i]))
		map.draw_polyline(sp, Color(0.6, 0.55, 0.45, 0.8), 3.0, true)
	var g0: Vector2 = to.call(xf.gates[0]["pos"])
	map.draw_rect(Rect2(g0 - Vector2(5, 5), Vector2(10, 10)), RED)
	for r in race.riders:
		if r.disconnected:
			continue
		var c: Vector2 = to.call(r.global_position)
		if r == race.local:
			map.draw_circle(c, 7.0, RED)
			map.draw_arc(c, 9.0, 0, TAU, 16, WHITE, 2.0)
		else:
			map.draw_circle(c, 5.0, RaceVisual.RIDERS.get(r.rider_id, RaceVisual.RIDERS["pahan"])["tint"])

# ---------------- события ----------------
func countdown(n: int) -> void:
	count_shown = n
	count_l.text = str(n) if n > 0 else "ЖМИ!"
	count_l.add_theme_color_override("font_color", RED if n == 0 else WHITE)
	count_l.scale = Vector2.ONE
	count_l.pivot_offset = count_l.size * 0.5
	count_l.modulate.a = 1.0
	var tw := count_l.create_tween().set_parallel(true)
	count_l.scale = Vector2(1.5, 1.5)
	tw.tween_property(count_l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if n == 0:
		tw.tween_property(count_l, "modulate:a", 0.0, 0.6).set_delay(0.5)

func flash_text(s: String) -> void:
	flash_l.text = s
	flash_l.modulate.a = 1.0
	flash_l.pivot_offset = flash_l.size * 0.5
	flash_l.scale = Vector2(1.3, 1.3)
	var tw := flash_l.create_tween().set_parallel(true)
	tw.tween_property(flash_l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash_l, "modulate:a", 0.0, 0.5).set_delay(1.6)

## случайная ситуация на трассе: большая надпись и пояснение
func happening(title: String, sub: String) -> void:
	happen_l.text = title
	happen_sub.text = sub
	for l in [happen_l, happen_sub]:
		(l as Label).modulate.a = 1.0
	happen_l.pivot_offset = happen_l.size * 0.5
	happen_l.scale = Vector2(1.4, 1.4)
	var tw := happen_l.create_tween().set_parallel(true)
	tw.tween_property(happen_l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(happen_l, "modulate:a", 0.0, 0.6).set_delay(3.0)
	tw.tween_property(happen_sub, "modulate:a", 0.0, 0.6).set_delay(3.0)
	feed(title + " — " + sub, true)

## последний круг: плашка круга начинает биться
func final_lap() -> void:
	final_on = true

## трюк, мешок: короткая надпись над дорогой (bad — красная)
func trick_text(s: String, bad := false) -> void:
	trick_l.text = s
	trick_l.add_theme_color_override("font_color", RED if bad else Color(1.0, 0.85, 0.25))
	trick_l.modulate.a = 1.0
	trick_l.pivot_offset = trick_l.size * 0.5
	trick_l.scale = Vector2(1.35, 1.35)
	var tw := trick_l.create_tween().set_parallel(true)
	tw.tween_property(trick_l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(trick_l, "modulate:a", 0.0, 0.4).set_delay(0.9)

## комбо выросло: надпись подпрыгивает
func combo(n: int) -> void:
	if n >= 2:
		combo_l.pivot_offset = Vector2(combo_l.size.x, combo_l.size.y * 0.5)
		combo_l.scale = Vector2(1.4, 1.4)
		combo_l.create_tween().tween_property(combo_l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func item_got(id: String) -> void:
	item_card.scale = Vector2(1.25, 1.25)
	item_card.create_tween().tween_property(item_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	feed("Предмет: " + String(RaceData.ITEMS[id]["name"]) + " — " + String(RaceData.ITEMS[id]["desc"]), true)

func feed(s: String, mine := false) -> void:
	var l := _text(feed_box, s, 16, WHITE if mine else SILVER, Vector2.ZERO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(480, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	while feed_box.get_child_count() > 4:
		var c := feed_box.get_child(0)
		feed_box.remove_child(c)
		c.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		if is_instance_valid(l):
			l.queue_free())

# ---------------- экраны: результаты и пауза ----------------
func _screen(title: String, sub: String) -> Control:
	var p := Control.new()
	p.size = STAGE
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(p)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.position = Vector2(-2000, -2000)
	shade.size = STAGE + Vector2(4000, 4000)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(shade)
	var card := Polygon2D.new()
	card.polygon = _torn(900, 640, 41)
	card.color = Color(0.05, 0.05, 0.06, 0.97)
	card.position = Vector2(350, 130)
	p.add_child(card)
	var edge := Line2D.new()
	edge.points = card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	card.add_child(edge)
	var h := _text(p, title, 70, WHITE, Vector2(380, 120), serif)
	h.rotation = deg_to_rad(-2.0)
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(0, 0), Vector2(260, -10), Vector2(256, 4), Vector2(-4, 14)])
	slash.color = RED
	slash.position = Vector2(390, 214)
	p.add_child(slash)
	_text(p, sub, 18, SILVER, Vector2(392, 226))
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	return p

func _menu(p: Control, items: Array, y: float) -> void:
	menu_rows = []
	for k in items.size():
		var l := _text(p, "", 30, GREY, Vector2(400, y + k * 44), serif)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		menu_rows.append([l, items[k][1], String(items[k][0])])
		l.mouse_entered.connect(func(): _menu_select(k))
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_menu_select(k)
				_menu_ok())
	_menu_select(0)

func _menu_select(k: int) -> void:
	if menu_rows.is_empty():
		return
	menu_sel = posmod(k, menu_rows.size())
	for i in menu_rows.size():
		var l: Label = menu_rows[i][0]
		l.text = ("▶ " if i == menu_sel else "   ") + String(menu_rows[i][2])
		l.add_theme_color_override("font_color", WHITE if i == menu_sel else GREY)

func _menu_ok() -> void:
	if menu_rows.is_empty():
		return
	if race.main != null:
		race.main.sfx("sfx_ui")
	(menu_rows[menu_sel][1] as Callable).call()

func _input(e: InputEvent) -> void:
	if menu_rows.is_empty() or not (results_panel != null or pause_panel != null):
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_W or k == KEY_UP:
			_menu_select(menu_sel - 1)
		elif k == KEY_S or k == KEY_DOWN:
			_menu_select(menu_sel + 1)
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_menu_ok()
		else:
			return
		get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_DPAD_UP:
			_menu_select(menu_sel - 1)
		elif e.button_index == JOY_BUTTON_DPAD_DOWN:
			_menu_select(menu_sel + 1)
		elif e.button_index == JOY_BUTTON_A:
			_menu_ok()
		elif e.button_index == JOY_BUTTON_B and pause_panel != null:
			race.set_paused(false)
		else:
			return
		get_viewport().set_input_as_handled()

func show_results() -> void:
	if pause_panel != null:
		show_pause(false)
	for c in stage.get_children():
		if c is CanvasItem and c != feed_box:
			(c as CanvasItem).visible = false             # игровой HUD уходит: на экране только итоги
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	var mode := String(race.cfg.get("mode", "single"))
	var me: RaceRider = race.local
	var title := "ФИНИШ"
	if me != null and mode != "time":
		title = "%d МЕСТО" % me.rank if me.finished else "РЕЗУЛЬТАТЫ"
	var sub := String(RaceData.track(String(race.cfg.get("track", ""))).get("name", "")) + " · %d круга" % race.laps
	if race.new_record != "":
		sub += " · НОВЫЙ РЕКОРД!"
	results_panel = _screen(title, sub)
	var y := 270.0
	for k in race.results.size():
		var row: Dictionary = race.results[k]
		var r: RaceRider = row["rider"]
		var mine: bool = r == me
		if mine:
			var band := ColorRect.new()
			band.color = WHITE
			band.position = Vector2(386, y - 2)
			band.size = Vector2(830, 32)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			results_panel.add_child(band)
		var col := INK if mine else WHITE
		var c1 := _text(results_panel, "%d" % (k + 1), 26, RED if not mine else INK, Vector2(400, y - 4), serif)
		var c2 := _text(results_panel, String(row["title"]) + ("  (вышел)" if row["dc"] else ""), 22, col, Vector2(450, y))
		var c3 := _text(results_panel, ("~" if row["est"] else "") + fmt(float(row["time"])), 22, col, Vector2(820, y))
		var c4 := _text(results_panel, ("круг " + fmt(float(row["best"]))) if float(row["best"]) > 0.0 else "", 18, GREY if not mine else INK, Vector2(1000, y + 3))
		for c in [c1, c2, c3, c4]:
			if mine:
				(c as Label).remove_theme_constant_override("outline_size")
		y += 38
	var rec_t := RaceSave.best(String(race.cfg.get("track", "")), mode)
	var rec_l := RaceSave.best(String(race.cfg.get("track", "")), "lap")
	_text(results_panel, ("Рекорд трассы (%s): %s" % ["на время" if mode == "time" else "гонка", fmt(rec_t)] if rec_t > 0.0 else "") + ("   ·   лучший круг: " + fmt(rec_l) if rec_l > 0.0 else ""), 16, SILVER, Vector2(400, 548))
	var items: Array = []
	if mode == "online":
		if race.authority:
			items.append(["ВСЕ В ЛОББИ", func():
				race.net.back_to_lobby()
				race.quit_to_lobby()])
		else:
			_text(results_panel, "Хост решает, ехать ли ещё раз.", 16, SILVER, Vector2(400, 574))
		items.append(["ВЫЙТИ ИЗ СЕТЕВОЙ ГОНКИ", func(): race.quit(false)])
	else:
		items.append(["ЕЩЁ РАЗ", func(): race.restart()])
		items.append(["В МЕНЮ ГОНОК", func(): race.quit(true)])
		items.append(["В ГЛАВНОЕ МЕНЮ", func(): race.quit(false)])
	_menu(results_panel, items, 600)

func show_pause(on: bool) -> void:
	if not on:
		if pause_panel != null:
			pause_panel.queue_free()
			pause_panel = null
			menu_rows = []
		return
	if pause_panel != null:
		return
	pause_panel = _screen("ПАУЗА" if race.net == null else "СЕТЕВАЯ ГОНКА", "Гонка стоит · Esc — продолжить" if race.net == null else "Гонка идёт дальше — в сети её не остановить · Esc — назад к рулю")
	_text(pause_panel, "Управление: %s — газ · %s — тормоз · %s / %s — руль · %s — занос · %s — прыжок · %s — турбо · %s — предмет · %s — назад" % [
		_k("race_accelerate"), _k("race_brake"), _k("race_left"), _k("race_right"), _k("race_drift"), _k("race_jump"), _k("race_boost"), _k("race_item"), _k("race_look_back")], 15, SILVER, Vector2(400, 270)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var items: Array = [["ПРОДОЛЖИТЬ", func(): race.set_paused(false)]]
	if String(race.cfg.get("mode", "single")) != "online":
		items.append(["ЗАНОВО", func(): race.restart()])
		items.append(["В МЕНЮ ГОНОК", func(): race.quit(true)])
		items.append(["В ГЛАВНОЕ МЕНЮ", func(): race.quit(false)])
	else:
		items.append(["ВЫЙТИ ИЗ СЕТЕВОЙ ГОНКИ", func(): race.quit(false)])
	_menu(pause_panel, items, 360)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)

func _k(a: String) -> String:
	var ks := RaceSave.keys_of(a)
	return String(ks[0]) if not ks.is_empty() else "—"
