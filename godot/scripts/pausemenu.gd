## Меню паузы: чёрно-белая композиция по утверждённому референсу.
## Слева — шесть огромных наклонённых названий вкладок, сверху по центру — логотип, справа — Пахан в расслабленной
## музыкальной позе (отдельная сцена в SubViewport: настоящая модель, Rig, позы Poses.pahan_pause(), PodHand и EarPods),
## справа внизу — две белые панели с настоящими здоровьем и прослушиваниями, подсказки управления.
## Игровой мир останавливается сразу (game.set_paused), меню раскрывается слоями за ~0,6 с; игровой Пахан не трогается.
## Вкладки показывают только то, что в игре есть: СТАТУС, РАЗВИТИЕ, ГРУППА, ЗАДАНИЕ, МУЗЫКА, СИСТЕМА.
## Все будущие системы прокачки добавляются во вкладку РАЗВИТИЕ (см. docs/PROGRESSION_MENU_INTEGRATION.md).
## Раз в 25–45 с, если музыка играет в наушниках и игрок не трогает меню, Пахан сам достаёт iPod, переключает трек и убирает его.
class_name PauseMenu
extends Control

const STAGE := Vector2(1600, 900)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const RED := Color(0.62, 0.08, 0.1)          # единственный цветной акцент — метка у выбранной вкладки
# вкладка: [название, позиция, размер шрифта, наклон в градусах]
const TABS := [
	["СТАТУС", Vector2(430, -6), 84, 20.0],
	["РАЗВИТИЕ", Vector2(215, 84), 100, 12.0],
	["ГРУППА", Vector2(40, 214), 118, 4.0],
	["ЗАДАНИЕ", Vector2(14, 372), 132, -1.5],
	["МУЗЫКА", Vector2(150, 566), 112, -13.0],
	["СИСТЕМА", Vector2(380, 716), 92, -23.0],
]
const HINTS := ["Здоровье, СВЭГ, перегруз, глава", "Улучшения за прослушивания", "Пахан и madk1d", "Что сейчас делать", "iPod: трек и управление", "Настройки и выход"]
const T_ENTER := 0.5
const T_EXIT := 0.35

var game
var stage: Control
var bg: ColorRect
var bg_mat: ShaderMaterial
var serif: SystemFont
var tech: SystemFont
var worn: ShaderMaterial
var tabs: Array = []            # [{root, label, band, tag}]
var layers: Array = []          # элементы в порядке появления: [узел, исходная позиция]
var sel := 3
var is_open := false
var closing := false
var card: Control
var card_lines: Array = []      # [[Label, Callable]] — строки, которые обновляются на ходу
var card_rows: Array = []       # [[Label, текст или Callable, Callable]]
var card_sel := 0
var hp_text: Label
var hp_fill: ColorRect
var xp_text: Label
var now_tag: Label
var idle_t := 0.0               # сколько секунд игрок не трогал меню
# сцена с Паханом
var vp: SubViewport
var rig: Rig
var pod: PodHand
var tilt: Node3D
var face: TextureRect
var clip := ""
var check := ""                 # автономная проверка iPod: "" / check / take / inspect / switch / return
var check_t := 0.0
var next_check := 30.0
var switched := false
var checks_done := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	rng.randomize()
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	worn = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Menu.BG_SHADER.replace("glow_floor_dummy()", "glow * 0.5 * (1.0 - depth)")
	bg_mat.shader = sh
	bg.material = bg_mat
	add_child(bg)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_rings()
	_build_preview()
	_build_logo()
	_build_tabs()
	_build_panels()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	bg.position = Vector2.ZERO
	bg.size = vs
	bg_mat.set_shader_parameter("aspect", vs.x / max(1.0, vs.y))
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func _text(parent: Node, s: String, size: int, col: Color, pos: Vector2, f: Font = null, rough := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else tech)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rough:
		l.material = worn
	parent.add_child(l)
	return l

static func torn(w: float, h: float, seed_v: int, tail := 60.0) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	var x := -tail
	while x < w:
		pts.append(Vector2(x, r.randf_range(-5.0, 4.0)))
		x += r.randf_range(9.0, 26.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + r.randf_range(-14.0, 22.0) + 30.0 * (1.0 - absf(y / h - 0.5) * 2.0), y))
		y += r.randf_range(7.0, 15.0)
	x = w
	while x > -tail:
		pts.append(Vector2(x, h + r.randf_range(-4.0, 6.0)))
		x -= r.randf_range(9.0, 26.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(-tail + r.randf_range(-20.0, 10.0), y))
		y -= r.randf_range(8.0, 16.0)
	return pts

func _layer(n: CanvasItem) -> void:
	layers.append([n, (n as Node).get("position")])

# ---------------- композиция ----------------
func _build_rings() -> void:
	# большие дуги и клин за героем — как круги и геометрия на референсе
	var g := Node2D.new()
	stage.add_child(g)
	for d in [[Vector2(1130, 470), 420.0, 2.0, 0.5], [Vector2(1180, 430), 300.0, 5.0, 0.7], [Vector2(560, 560), 360.0, 1.5, 0.3]]:
		var l := Line2D.new()
		var pts := PackedVector2Array()
		for i in 97:
			var a := TAU * i / 96.0
			pts.append((d[0] as Vector2) + Vector2(cos(a), sin(a)) * float(d[1]))
		l.points = pts
		l.width = float(d[2])
		l.default_color = Color(1, 1, 1, float(d[3]))
		g.add_child(l)
	var wedge := Polygon2D.new()
	wedge.polygon = PackedVector2Array([Vector2(1330, 0), Vector2(1600, 0), Vector2(1600, 130), Vector2(1540, 96), Vector2(1560, 250), Vector2(1450, 120)])
	wedge.color = WHITE
	wedge.material = worn
	g.add_child(wedge)
	_layer(g)

func _build_logo() -> void:
	var logo := Control.new()
	logo.position = Vector2(770, 22)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(logo)
	var a := _text(logo, "GOD OF", 74, WHITE, Vector2(34, 0), serif, true)
	a.size = Vector2(420, 80)
	_text(logo, "GRIMERKA", 78, WHITE, Vector2(0, 66), serif, true)
	_layer(logo)

func _build_tabs() -> void:
	for i in TABS.size():
		var d: Array = TABS[i]
		var size: int = d[2]
		var root := Control.new()
		root.position = d[1]
		root.rotation = deg_to_rad(float(d[3]))
		var w: float = serif.get_string_size(d[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		root.size = Vector2(w + 20, size * 1.1)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		stage.add_child(root)
		var band := Polygon2D.new()
		band.polygon = torn(w + 60.0, size * 1.02, 31 + i, 40.0)
		band.position = Vector2(0, size * 0.1)
		band.color = WHITE
		band.material = worn
		root.add_child(band)
		var lab := _text(root, d[0], size, WHITE, Vector2.ZERO, serif, true)
		var tag := Polygon2D.new()
		tag.polygon = torn(190.0, 34.0, 60 + i, 10.0)
		tag.color = RED
		tag.position = Vector2(w * 0.55, size * 0.98)
		tag.rotation = deg_to_rad(-5.0)
		root.add_child(tag)
		var tl := _text(tag, "ОТКРЫТЬ  ⏎", 20, WHITE, Vector2(18, 3), serif)
		tl.size = Vector2(170, 28)
		tabs.append({"root": root, "label": lab, "band": band, "tag": tag})
		root.mouse_entered.connect(func(): if card == null and is_open and not closing: _select(i))
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and card == null and is_open and not closing:
				_select(i)
				_open_page(i))
		_layer(root)

func _build_panels() -> void:
	# две белые шероховатые панели с настоящими значениями
	for i in 2:
		var p := Control.new()
		p.position = Vector2(1150, 716 + i * 60)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(p)
		var plate := Polygon2D.new()
		plate.polygon = PackedVector2Array([Vector2(26, 0), Vector2(420, 0), Vector2(420, 50), Vector2(0, 50)])
		plate.color = WHITE
		plate.material = worn
		p.add_child(plate)
		_text(p, "ЗДОРОВЬЕ" if i == 0 else "ПРОСЛУШИВАНИЯ", 12, INK, Vector2(44, 3), serif)
		var mark := Polygon2D.new()
		mark.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)]) if i == 0 else PackedVector2Array([Vector2(-7, -9), Vector2(9, 0), Vector2(-7, 9)])
		mark.color = INK
		mark.position = Vector2(62, 33)
		p.add_child(mark)
		var sep := ColorRect.new()
		sep.color = GREY
		sep.position = Vector2(86, 18)
		sep.size = Vector2(2, 26)
		p.add_child(sep)
		var val := _text(p, "", 34, INK, Vector2(100, 8), serif)
		val.size = Vector2(300, 40)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 0:
			hp_text = val
			var back := ColorRect.new()
			back.color = Color(0, 0, 0, 0.25)
			back.position = Vector2(100, 43)
			back.size = Vector2(300, 4)
			p.add_child(back)
			hp_fill = ColorRect.new()
			hp_fill.color = INK
			hp_fill.position = Vector2(100, 43)
			hp_fill.size = Vector2(300, 4)
			p.add_child(hp_fill)
		else:
			xp_text = val
		_layer(p)
	var hints := Control.new()
	hints.position = Vector2(1210, 846)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hints)
	var x := 0.0
	for h in [["Enter", "Выбрать"], ["Esc", "Назад"]]:
		var k := ColorRect.new()
		k.color = Color(0.86, 0.87, 0.89)
		k.position = Vector2(x, 0)
		k.size = Vector2(52, 24)
		hints.add_child(k)
		var kl := _text(k, h[0], 13, INK, Vector2.ZERO)
		kl.size = k.size
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text(hints, h[1], 18, WHITE, Vector2(x + 60, -1), serif)
		x += 170.0
	_layer(hints)
	now_tag = _text(stage, "", 17, WHITE, Vector2(1000, 660), serif)
	now_tag.size = Vector2(560, 50)
	now_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	now_tag.modulate.a = 0.0

# ---------------- сцена с Паханом ----------------
func _build_preview() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(900, 900)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.5, 0.7, 0.0)
	key.light_energy = 0.85
	vp.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation = Vector3(-0.3, PI - 0.6, 0.0)
	back.light_energy = 0.7
	vp.add_child(back)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0.0, 1.0, 5.2)
	vp.add_child(cam)
	# весь риг наклоняется назад вокруг таза: в пространстве скелета Пахан остаётся «вертикальным»,
	# поэтому карман, взгляд и провод PodHand работают как в игре
	tilt = Node3D.new()
	tilt.position = Vector3(0.0, 0.95, 0.0)
	vp.add_child(tilt)
	rig = Rig.new()
	tilt.add_child(rig)
	rig.position.y = -0.95
	rig.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan_pause(), false, 1.0, "pause_pahan")
	pod = PodHand.new()
	pod.setup(rig)
	pod.pocket_show = true
	if pod.sfx:
		pod.sfx.queue_free()
		pod.sfx = null
	rig.skel.add_child(pod)
	face = TextureRect.new()
	face.texture = vp.get_texture()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.size = Vector2(900, 900)
	face.position = Vector2(660, -10)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = Menu.CHAR_SHADER
	cm.shader = cs
	face.material = cm
	stage.add_child(face)
	_layer(face)

func _play(nm: String, blend := 0.25) -> void:
	if clip == nm:
		return
	clip = nm
	rig.play(nm, blend)

func _listening() -> bool:
	return game.ipod != null and game.ipod.is_listening()

# ---------------- открыть / закрыть ----------------
func open() -> void:
	if is_open and not closing:
		return
	is_open = true
	closing = false
	visible = true
	idle_t = 0.0
	check = ""
	next_check = rng.randf_range(25.0, 45.0)
	_close_card()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pod.set_seated(game.ipod != null and bool(game.ipod.earbuds_in))
	pod.want = false
	pod.u = 0.0
	# Пахан: из обычной стойки — в позу отдыха
	clip = ""
	rig.play("Idle", 0.0)
	rig.play_for("PauseEnter", T_ENTER, 0.05)
	clip = "PauseEnter"
	tilt.rotation = Vector3.ZERO
	tilt.position = Vector3(0.0, 0.95, 0.0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(tilt, "rotation", Vector3(-0.36, -0.42, 0.2), T_ENTER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tilt, "position", Vector3(0.05, 1.12, 0.0), T_ENTER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# интерфейс: слоями, каждый следующий на 40 мс позже
	bg.modulate.a = 0.0
	tw.tween_property(bg, "modulate:a", 1.0, 0.16)
	for i in layers.size():
		var n: CanvasItem = layers[i][0]
		var home: Vector2 = layers[i][1]
		n.modulate.a = 0.0
		n.set("position", home + Vector2(-34.0 if home.x < 700.0 else 34.0, 0.0))
		tw.tween_property(n, "modulate:a", 1.0, 0.18).set_delay(0.06 + i * 0.04)
		tw.tween_property(n, "position", home, 0.22).set_delay(0.06 + i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_select(sel, false)
	_refresh()

## Закрыть с анимацией и вернуть игру.
func close() -> void:
	if not is_open or closing:
		return
	closing = true
	_close_card()
	# iPod в руке не остаётся: проверка обрывается, устройство — сразу в карман
	check = ""
	pod.want = false
	pod.u = 0.0
	now_tag.modulate.a = 0.0
	rig.play_for("PauseExit", T_EXIT, 0.06)
	clip = "PauseExit"
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(tilt, "rotation", Vector3.ZERO, T_EXIT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tilt, "position", Vector3(0.0, 0.95, 0.0), T_EXIT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in layers.size():
		var n: CanvasItem = layers[layers.size() - 1 - i][0]
		tw.tween_property(n, "modulate:a", 0.0, 0.14).set_delay(i * 0.018)
	tw.tween_property(bg, "modulate:a", 0.0, 0.16).set_delay(T_EXIT - 0.16)
	tw.chain().tween_callback(func(): game.set_paused(false))

## Скрыть сразу, без анимации (вызывает game.set_paused(false)).
func shut() -> void:
	is_open = false
	closing = false
	visible = false
	check = ""
	_close_card()
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if pod:
		pod.want = false
		pod.u = 0.0

# ---------------- вкладки ----------------
func _select(i: int, sound := true) -> void:
	if sound and i != sel:
		game.main.sfx("sfx_ui", -10.0, 1.2)
	sel = i
	for k in tabs.size():
		var on := k == i
		var tb: Dictionary = tabs[k]
		(tb["band"] as Polygon2D).visible = on
		(tb["tag"] as Polygon2D).visible = on
		(tb["label"] as Label).add_theme_color_override("font_color", INK if on else WHITE)
		(tb["label"] as Label).material = null if on else worn
		(tb["root"] as Control).z_index = 2 if on else 0
	((tabs[i]["tag"] as Polygon2D).get_child(0) as Label).text = "ОТКРЫТЬ  ⏎"

func _open_page(i: int) -> void:
	game.main.sfx("sfx_ui")
	match i:
		0:
			_card("СТАТУС", [
				func(): return "ПАХАН",
				func(): return "Здоровье: %d / %d" % [ceili(game.player.hp), int(game.player.max_hp)],
				func(): return "СВЭГ: %d / 100" % int(game.player.swag),
				func(): return "ПЕРЕГРУЗ: " + ("идёт, ещё %.0f с" % game.player.rage if game.player.rage > 0.0 else ("готов — [R]" if game.player.swag >= 100.0 else "копится (нужен полный СВЭГ)")),
				func(): return "Прослушивания: %d" % game.xp,
				func(): return "Глава %d · %s" % [game.ch + 1, String(game.chapter()["name"])],
			], [["НАЗАД", _close_card]])
		1:
			var rows: Array = []
			for r in [["hp", "ЗДОРОВЬЕ +20"], ["dmg", "СИЛА +12% УРОНА"], ["q", "АД-ЛИБ MADK1D: на 1,5 с чаще"]]:
				var k: String = r[0]
				var nm: String = r[1]
				rows.append([func():
					var lv := int(game.up[k])
					if lv >= 5:
						return "%s — ур. 5/5 · максимум" % nm
					return "%s — ур. %d/5 · цена %d %s" % [nm, lv, game._cost(k), "" if game.xp >= game._cost(k) else "✕"],
					func():
						if game.buy_upgrade(k):
							game.main.sfx("sfx_ui", -4.0, 1.4)])
			rows.append(["НАЗАД", _close_card])
			_card("РАЗВИТИЕ", [
				func(): return "Прослушиваний: %d" % game.xp,
				func(): return "Осталось улучшений: %d из 15" % (15 - int(game.up["hp"]) - int(game.up["dmg"]) - int(game.up["q"])),
				func(): return "Покупка не двигает сюжет и не лечит (кроме +20 от улучшения здоровья).",
			], rows)
		2:
			_card("ГРУППА", [
				func(): return "ПАХАН — герой. Балон VOZDUH.",
				func(): return "   здоровье %d / %d · урон ×%.2f" % [ceili(game.player.hp), int(game.player.max_hp), game.player.dmg_mul],
				func(): return "MADK1D — напарник, действует сам.",
				func(): return "   ад-либ [Q]: " + ("готов" if game.buddy.cd <= 0.0 else "перезарядка %.0f с из %.0f" % [game.buddy.cd, game.buddy.cd_max]),
			], [["НАЗАД", _close_card]])
		3:
			_card("ЗАДАНИЕ", [
				func(): return "Глава %d · %s" % [game.ch + 1, String(game.chapter()["name"])],
				func(): return String(game.chapter().get("place", "")),
				func(): return "Шаг %d из %d" % [max(1, game.step + 1), (game.chapter()["steps"] as Array).size()],
				func(): return "Сейчас: " + game.objective(),
			], [["НАЗАД", _close_card]])
		4:
			_card("МУЗЫКА", [
				func():
					var n: Dictionary = game.ipod.now_playing()
					return "Трек: " + (String(n["title"]) if n["has"] else "не выбран") + ("  (%d / %d)" % [int(n["index"]) + 1, int(n["count"])] if n["has"] else ""),
				func(): return "Исполнитель: " + String(game.ipod.now_playing()["artist"]),
				func():
					var n: Dictionary = game.ipod.now_playing()
					return ("Играет" if n["playing"] else ("Пауза" if n["paused"] else "Остановлен")) + "  ·  %s / %s" % [_time(float(n["pos"])), _time(float(n["len"]))],
				func(): return "EarPods: " + ("в ушах — игра приглушена, слышны музыка и голоса" if game.ipod.earbuds_in else "не надеты (надеваются при первом открытии iPod, клавиша ↑)"),
				func(): return "Громкость iPod: %d%%" % roundi(float(game.ipod.volume) * 100.0),
			], [
				["◀◀  ПРЕДЫДУЩИЙ", func(): game.ipod.pause_step_track(-1)],
				[func(): return "▶ Ⅱ  " + ("ПАУЗА" if game.ipod.now_playing()["playing"] else "ИГРАТЬ"), func(): game.ipod.pause_toggle_play()],
				["СЛЕДУЮЩИЙ  ▶▶", func(): game.ipod.pause_step_track(1)],
				["ГРОМКОСТЬ −", func(): game.ipod.pause_set_volume(float(game.ipod.volume) - 0.05)],
				["ГРОМКОСТЬ +", func(): game.ipod.pause_set_volume(float(game.ipod.volume) + 0.05)],
				["НАЗАД", _close_card]])
		5:
			var box := _card("СИСТЕМА", [], [
				[func(): return "ПОЛНЫЙ ЭКРАН: " + ("ВКЛ" if Menu.is_fullscreen(get_window()) else "ВЫКЛ"), func(): Menu.set_fullscreen(get_window(), not Menu.is_fullscreen(get_window()))],
				[func(): return "ВЕРТ. СИНХРОНИЗАЦИЯ: " + ("ВКЛ" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "ВЫКЛ"), func(): Menu.set_vsync(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)],
				["ВЕРНУТЬСЯ В ИГРУ", close],
				["В ГЛАВНОЕ МЕНЮ", func(): game._to_menu()],
				["НАЗАД", _close_card]])
			game.main.audio.add_sliders(box)
			for sl in box.find_children("*", "HSlider", true, false):
				for nm in ["grabber_area", "grabber_area_highlight"]:
					var fill := StyleBoxFlat.new()
					fill.bg_color = WHITE
					fill.set_corner_radius_all(3)
					fill.content_margin_top = 3
					fill.content_margin_bottom = 3
					(sl as HSlider).add_theme_stylebox_override(nm, fill)
			var c := Label.new()
			c.text = "УПРАВЛЕНИЕ: WASD — бег · мышь — камера · ЛКМ — удары · ПКМ — добивание · E — Heat · Пробел — перекат · Shift — блок · Q — ад-либ · R — ПЕРЕГРУЗ · ↑ — iPod · Esc — пауза · F11 — полный экран"
			c.add_theme_font_override("font", tech)
			c.add_theme_font_size_override("font_size", 14)
			c.add_theme_color_override("font_color", GREY)
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(c)

static func _time(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

## Страница вкладки: тёмная рваная карточка слева. lines — функции, возвращающие строку (обновляются на ходу),
## actions — [текст или функция текста, действие].
func _card(title: String, lines: Array, actions: Array) -> VBoxContainer:
	_close_card()
	card = Control.new()
	card.size = STAGE
	card.z_index = 10        # поверх выбранной вкладки
	stage.add_child(card)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(900, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(shade)
	var plate := Polygon2D.new()
	plate.polygon = torn(700.0, 620.0, 91)
	plate.color = Color(0.05, 0.05, 0.06, 0.97)
	plate.position = Vector2(110, 150)
	card.add_child(plate)
	var edge := Line2D.new()
	edge.points = plate.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	plate.add_child(edge)
	var head := _text(card, title, 72, WHITE, Vector2(108, 158), serif, true)
	head.rotation = deg_to_rad(-2.0)
	var box := VBoxContainer.new()
	box.position = Vector2(118, 262)
	box.size = Vector2(660, 480)
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	card_lines = []
	for fn in lines:
		var l := Label.new()
		l.add_theme_font_override("font", tech)
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", SILVER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		card_lines.append([l, fn])
	card_rows = []
	for i in actions.size():
		var a: Array = actions[i]
		var l2 := Label.new()
		l2.add_theme_font_override("font", serif)
		l2.add_theme_font_size_override("font_size", 28)
		l2.mouse_filter = Control.MOUSE_FILTER_STOP
		l2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.add_child(l2)
		card_rows.append([l2, a[0], a[1]])
		l2.mouse_entered.connect(func(): _card_select(i))
		l2.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_card_select(i)
				_card_activate())
	card_sel = 0
	card.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "modulate:a", 1.0, 0.12)
	_refresh()
	return box

func _card_select(i: int) -> void:
	if i != card_sel:
		game.main.sfx("sfx_ui", -10.0, 1.2)
	card_sel = i
	_refresh()

func _card_activate() -> void:
	if card_rows.is_empty():
		return
	game.main.sfx("sfx_ui")
	(card_rows[card_sel][2] as Callable).call()
	if card != null:
		_refresh()

func _close_card() -> void:
	if card != null:
		card.queue_free()
		card = null
		card_rows = []
		card_lines = []

## Настоящие значения — каждый кадр: панели, строки открытой страницы.
func _refresh() -> void:
	if game == null or game.player == null:
		return
	hp_text.text = "%d / %d" % [ceili(game.player.hp), int(game.player.max_hp)]
	hp_fill.size.x = 300.0 * clampf(game.player.hp / game.player.max_hp, 0.0, 1.0)
	xp_text.text = str(game.xp)
	for e in card_lines:
		(e[0] as Label).text = String((e[1] as Callable).call())
	for k in card_rows.size():
		var l: Label = card_rows[k][0]
		var txt = card_rows[k][1]
		l.text = ("▶ " if k == card_sel else "   ") + (String(txt.call()) if txt is Callable else String(txt))
		l.add_theme_color_override("font_color", WHITE if k == card_sel else GREY)

# ---------------- ввод ----------------
func _unhandled_input(e: InputEvent) -> void:
	if not is_open or closing or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	idle_t = 0.0
	var k: int = e.physical_keycode
	var up := k == KEY_W or k == KEY_UP
	var down := k == KEY_S or k == KEY_DOWN
	var ok := k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	var back := k == KEY_ESCAPE or k == KEY_BACKSPACE
	if card != null:
		if up and not card_rows.is_empty():
			_card_select(posmod(card_sel - 1, card_rows.size()))
		elif down and not card_rows.is_empty():
			_card_select(posmod(card_sel + 1, card_rows.size()))
		elif ok:
			_card_activate()
		elif back:
			game.main.sfx("sfx_ui", -8.0, 0.8)
			_close_card()
	elif up:
		_select(posmod(sel - 1, TABS.size()))
	elif down:
		_select(posmod(sel + 1, TABS.size()))
	elif ok:
		_open_page(sel)
	elif back:
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _input(e: InputEvent) -> void:
	if is_open and e is InputEventMouseMotion:
		idle_t = 0.0

# ---------------- жизнь Пахана ----------------
## Запустить проверку iPod прямо сейчас (для проверки по кадрам); в игре её запускает таймер.
func check_now() -> void:
	if check == "":
		check = "check"
		check_t = 0.0
		switched = false

func _process(dt: float) -> void:
	if not is_open:
		return
	_refresh()
	if closing:
		return
	idle_t += dt
	var music := _listening()
	# базовая поза: вход доигрывается, потом музыка — кивает, тишина — просто дышит; пока iPod в руке — без кивков
	if clip == "PauseEnter":
		if not rig.player.is_playing():
			_play("PauseMusicIdle" if music else "PauseIdle", 0.3)
	else:
		_play("PauseMusicIdle" if music and check == "" else "PauseIdle", 0.35)
	now_tag.modulate.a = move_toward(now_tag.modulate.a, 0.0, dt * 0.45)
	# автономная проверка iPod
	if check == "":
		if music and card == null and idle_t >= 8.0 and pod.buds_in():
			next_check -= dt
			if next_check <= 0.0:
				check_now()
		return
	check_t += dt
	if not music and check != "return":      # музыка остановилась посреди проверки: ничего не включаем, убираем iPod
		check = "return"
		pod.want = false
	match check:
		"check":                               # замедлился, глянул вниз
			if check_t > 0.45:
				check = "take"
				pod.want = true
		"take":                                # достаёт
			if pod.u >= 1.0:
				check = "inspect"
				check_t = 0.0
		"inspect":                             # смотрит на экран
			if check_t > 0.9:
				check = "switch"
				check_t = 0.0
				pod.press("next")
				switched = game.ipod.next_track_from_pause()
				if switched:
					var n: Dictionary = game.ipod.now_playing()
					now_tag.text = "NOW PLAYING\n%s — %s" % [n["title"], n["artist"]]
					now_tag.modulate.a = 1.6
		"switch":                              # ещё немного смотрит и убирает
			if check_t > 0.9:
				check = "return"
				pod.want = false
		"return":
			if pod.u <= 0.0:
				check = ""
				checks_done += 1
				next_check = rng.randf_range(25.0, 45.0)
