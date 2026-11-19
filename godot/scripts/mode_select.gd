## Экран «ВЫБОР РЕЖИМА» (PLAY) главного меню: слева три карточки режимов, справа большая композиция выбранного —
## настоящие модели игры в своём SubViewport через тот же монохромный шейдер с полутоном, что у героев меню
## (Menu.CHAR_SHADER), огромное слово-фон, рваная красная полоса, описание. Живёт на «столе» меню 1600×900
## (menu.stage) и вписывается в окно вместе с ним. Навигацию ведёт menu.gd: W/S, стрелки, Enter, Esc, мышь, геймпад
## (ui_up / ui_down / ui_accept / ui_cancel). Что делает выбор режима — menu.open_mode(id).
##   01 STORY MODE     — CONTINUE / NEW GAME / LOAD GAME / BACK (существующие функции меню и сохранения)
##   02 TRAINING ARENA — существующий экран выбора героя и стиля (menu._open_training)
##   03 VACUUM RACING  — меню гонок (menu.open_race); пока режим не готов — честная плашка «СКОРО»
class_name ModeSelect
extends Control

const RED := Color(0.86, 0.09, 0.11)
const RED_DIM := Color(0.5, 0.05, 0.07)
const ART_POS := Vector2(560, 0)
const ART_SIZE := Vector2(1040, 900)
const VP_SIZE := Vector2i(1000, 900)
const MODES := [
	{"id": "story", "no": "01", "title": "STORY MODE", "ru": "СЮЖЕТ", "word": "STORY",
		"desc": "Пахан с Балоном VOZDUH и его кент madk1d идут через Облако. Продолжи сохранение, начни заново или загрузи ячейку.",
		"facts": ["CONTINUE · NEW GAME · LOAD GAME", "одна ячейка сохранения, прогресс главы и улучшения сохраняются"]},
	{"id": "training", "no": "02", "title": "TRAINING ARENA", "ru": "ТРЕНИРОВКА", "word": "TRAIN",
		"desc": "Площадка без сюжета, опыта и сохранения: все шесть стилей, манекены, замахи, воздух и босс с настоящими приёмами.",
		"facts": ["выбор героя и стиля перед входом", "F1 в арене — панель: зоны, враги, цифры урона, упражнения"]},
	{"id": "race", "no": "03", "title": "VACUUM RACING", "ru": "ГОНКИ НА ПЫЛЕСОСАХ", "word": "RACE",
		"desc": "Аркадные гонки на ТЯГЕ-812: дрифт, турбо, трамплины и предметы против пяти соперников.",
		"facts": ["одиночная гонка и заезд на время", "свои трассы, рекорды и управление"]},
	{"id": "microloans", "no": "04", "title": "PAHAN MICROLOANS", "ru": "ПАХАН НАБРАЛ МИКРОЗАЙМОВ", "word": "ДОЛГ",
		"desc": "Неделя в долгах у четырёх контор: проценты, мелкий шрифт, звонки коллекторов, подработки и пять концовок.",
		"facts": ["7 дней · переговоры · подработки-мини-игры", "своё сохранение, кампания не трогается"]},
	{"id": "five_nights", "no": "05", "title": "FIVE NIGHTS WITH PAHAN", "ru": "5 НОЧЕЙ С ПАХАНОМ", "word": "НОЧЬ",
		"desc": "Ночная смена в «Облаке»: камеры, двери, свет, вентиляция и энергия до шести утра. Они уже знают, что ты здесь.",
		"facts": ["5 ночей, шестая ночь и своя ночь", "хоррор: играть в наушниках"]},
]

var menu                      # Menu
var cards: Array = []         # [{root, band, num, title, ru, tag, accent}]
var arts: Array = []          # [{root, vp}]
var sel := 0
var desc_title: Label
var desc_text: Label
var desc_facts: Label
var wipe: Polygon2D
var lines: Array = []         # полосы скорости у гонок
var t := 0.0
var built := false

func setup(m) -> void:
	menu = m
	size = Menu.STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## режим доступен игроку (гонки — когда их меню подключено: menu.race_ready())
func available(i: int) -> bool:
	return String(MODES[i]["id"]) != "race" or menu.race_ready()

func _build() -> void:
	built = true
	# тёмный слой слева: карточки читаются поверх фона
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(0, 0), Vector2(760, 0), Vector2(600, 900), Vector2(0, 900)])
	shade.color = Color(0, 0, 0, 0.55)
	add_child(shade)
	for i in MODES.size():
		_build_art(i)
	wipe = Polygon2D.new()
	wipe.polygon = PackedVector2Array([Vector2(0, -40), Vector2(160, -40), Vector2(40, 940), Vector2(-120, 940)])
	wipe.color = Color(0.95, 0.96, 0.97)
	wipe.visible = false
	add_child(wipe)
	_build_header()
	for i in MODES.size():
		_build_card(i)
	_build_desc()

func _build_header() -> void:
	var head := Control.new()
	head.position = Vector2(64, 58)
	head.rotation = deg_to_rad(-3.5)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	menu._text(head, "SELECT", 120, Menu.WHITE, Vector2(0, -30), menu.serif, true)
	var plaque := ColorRect.new()
	plaque.color = Menu.WHITE
	plaque.position = Vector2(8, 112)
	plaque.size = Vector2(250, 34)
	plaque.material = menu.worn
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(plaque)
	menu._text(plaque, "MODE // ВЫБОР РЕЖИМА", 19, Menu.INK, Vector2(12, 4), menu.tech)
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(270, 116), Vector2(430, 104), Vector2(426, 116), Vector2(268, 128)])
	slash.color = RED
	head.add_child(slash)

func _build_card(i: int) -> void:
	var m: Dictionary = MODES[i]
	var root := Control.new()
	root.position = Vector2(62 + i * 22, 268 + i * _step())
	root.scale = Vector2.ONE * _card_k()
	root.rotation = deg_to_rad(-4.0)
	root.size = Vector2(560, 140)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(root)
	# длинное название чуть уменьшается, а плашка вытягивается под него: у выбранной карточки текст тёмный,
	# и хвост названия за краем плашки пропал бы на чёрном фоне
	var tsize := 46
	while tsize > 36 and menu.serif.get_string_size(String(m["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x > 380.0:
		tsize -= 2
	var tw: float = menu.serif.get_string_size(String(m["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
	var band := Polygon2D.new()
	band.polygon = menu._torn(maxf(520.0, 110.0 + tw * 1.15 + 30.0), 136.0, 31 + i * 7)
	band.color = Menu.WHITE
	band.material = menu.worn
	band.position = Vector2(40, 0)
	root.add_child(band)
	var accent := Polygon2D.new()
	accent.polygon = PackedVector2Array([Vector2(0, 6), Vector2(16, 0), Vector2(10, 136), Vector2(-6, 142)])
	accent.color = RED
	accent.position = Vector2(-18, 0)
	root.add_child(accent)
	var num: Label = menu._text(root, String(m["no"]), 112, Menu.WHITE, Vector2(4, -6), menu.serif, true)
	var title: Label = menu._text(root, String(m["title"]), tsize, Menu.WHITE, Vector2(150, 14 + (46 - tsize) * 0.5), menu.serif)
	var ru: Label = menu._text(root, String(m["ru"]), 17, Menu.SILVER, Vector2(154, 72), menu.tech)
	var tag := ColorRect.new()
	tag.position = Vector2(154, 100)
	tag.size = Vector2(150, 24)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tag)
	var tag_l: Label = menu._text(tag, "", 14, Menu.INK, Vector2.ZERO, menu.tech)
	tag_l.size = tag.size
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cards.append({"root": root, "band": band, "num": num, "title": title, "ru": ru, "tag": tag, "tag_l": tag_l, "accent": accent})
	root.mouse_entered.connect(func():
		if visible and menu.panel == null and not menu.launching:
			select(i, true, false, "hover"))
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and visible and menu.panel == null and not menu.launching:
			select(i, false)
			activate())

## шаг и масштаб карточек: до трёх — как было, больше — плотнее, чтобы все влезли над «НАЗАД»
func _step() -> float:
	return minf(164.0, 560.0 / float(MODES.size()))

func _card_k() -> float:
	return minf(1.0, _step() / 150.0)

func _build_desc() -> void:
	var back_card := Polygon2D.new()
	back_card.polygon = menu._torn(520.0, 176.0, 77)
	back_card.color = Color(0.02, 0.02, 0.025, 0.86)
	back_card.position = Vector2(1080, 676)
	add_child(back_card)
	var bar := ColorRect.new()
	bar.color = RED
	bar.position = Vector2(1040, 700)
	bar.size = Vector2(6, 120)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	desc_title = menu._text(self, "", 30, Menu.WHITE, Vector2(1062, 692), menu.serif)
	desc_text = menu._text(self, "", 16, Menu.SILVER, Vector2(1064, 734), menu.tech)
	desc_text.size = Vector2(500, 60)
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_facts = menu._text(self, "", 14, Menu.GREY, Vector2(1064, 800), menu.tech)
	desc_facts.size = Vector2(500, 50)
	desc_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back: Label = menu._text(self, "◀ НАЗАД", 18, Menu.WHITE, Vector2(64, 846), menu.serif)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and visible and menu.panel == null:
			menu.close_modes())
	menu._text(self, "W/S — выбор · Enter — открыть · Esc — назад", 14, Menu.GREY, Vector2(190, 850), menu.tech)

# ---------------- композиции ----------------
func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VP_SIZE
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
	key.rotation = Vector3(-0.55, 0.75, 0.0)
	key.light_energy = 0.85
	vp.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation = Vector3(-0.3, PI - 0.6, 0.0)
	back.light_energy = 0.7
	vp.add_child(back)
	return vp

func _cam(vp: SubViewport, pos: Vector3, look: Vector3, fov := 26.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	cam.position = pos
	cam.look_at_from_position(pos, look)

func _char_mat(dim := 1.0, alpha := 1.0) -> ShaderMaterial:
	var cm := ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = Menu.CHAR_SHADER
	cm.shader = cs
	cm.set_shader_parameter("dim", dim)
	cm.set_shader_parameter("alpha", alpha)
	return cm

func _build_art(i: int) -> void:
	var id := String(MODES[i]["id"])
	var root := Control.new()
	root.position = ART_POS
	root.size = ART_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	root.clip_contents = true
	add_child(root)
	# огромное слово-фон
	var word: Label = menu._text(root, String(MODES[i]["word"]), 330, Color(1, 1, 1, 0.09), Vector2(-20, 120), menu.serif, true)
	word.rotation = deg_to_rad(-8.0)
	# рваная красная полоса наискось за героями
	var stripe := Polygon2D.new()
	stripe.polygon = menu._torn(1300.0, 120.0, 51 + i)
	stripe.color = RED_DIM if id != "race" else RED
	stripe.position = Vector2(-80, 560 if id != "race" else 470)
	stripe.rotation = deg_to_rad(-14.0 if id != "training" else 9.0)
	stripe.material = menu.worn
	root.add_child(stripe)
	var vp: SubViewport = null
	var tex: Texture2D
	if id == "story":
		tex = menu.hero_vp.get_texture()       # те же Пахан и madk1d, что в главном меню, — второй рендер не нужен
	else:
		vp = _viewport()
		tex = vp.get_texture()
		match id:
			"training":
				_scene_training(vp)
			"microloans":
				_scene_microloans(vp)
			"five_nights":
				_scene_five_nights(vp)
			_:
				_scene_race(vp)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(VP_SIZE)
	pic.position = Vector2(30, 0) if id != "story" else Vector2(40, 0)
	pic.material = _char_mat()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id == "race":
		# полосы скорости: белые штрихи, которые летят назад мимо гонщика
		for k in 14:
			var ln := Line2D.new()
			ln.width = 2.0 + float(k % 3) * 2.0
			ln.default_color = Color(1, 1, 1, 0.22 + 0.05 * float(k % 4))
			ln.points = PackedVector2Array([Vector2(0, 0), Vector2(140.0 + 60.0 * float(k % 5), 0)])
			ln.position = Vector2(randf_range(0, ART_SIZE.x), 180.0 + float(k) * 40.0)
			ln.rotation = deg_to_rad(-6.0)
			root.add_child(ln)
			lines.append(ln)
	root.add_child(pic)
	if id == "training":
		# мишень-полутон за манекеном
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for a in 49:
			pts.append(Vector2(cos(a * TAU / 48.0), sin(a * TAU / 48.0)) * 150.0)
		ring.points = pts
		ring.width = 5.0
		ring.default_color = RED
		ring.position = Vector2(700, 330)
		root.add_child(ring)
		root.move_child(ring, 2)
	arts.append({"root": root, "vp": vp, "pic": pic})

## Пахан с балоном в боевой стойке и манекен-бот на размеченной площадке
func _scene_training(vp: SubViewport) -> void:
	_cam(vp, Vector3(0.2, 1.25, 6.4), Vector3(0.2, 0.95, 0.0))
	var ph := Rig.new()
	vp.add_child(ph)
	ph.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan_armed(), false, -1.0, "mode_pahan_armed")
	ph.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56, "shadow": false})
	ph.position = Vector3(-0.75, 0, 0.4)
	ph.rotation.y = 0.75
	ph.play("CombatIdle" if ph.has_clip("CombatIdle") else "Idle", 0.0)
	var dummy := Rig.new()
	vp.add_child(dummy)
	dummy.setup("res://assets/models/bot.glb", 1.7, Poses.bot(), false, 1.0, "bot")
	dummy.position = Vector3(1.15, 0, -0.5)
	dummy.rotation.y = -0.9
	dummy.play("Idle", 0.0)
	# разметка зоны: кольцо на полу
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.05
	tor.outer_radius = 1.12
	ring.mesh = tor
	ring.scale = Vector3(1, 0.05, 1)
	ring.position = Vector3(1.15, 0.01, -0.5)
	vp.add_child(ring)

## Пахан верхом на ТЯГЕ-812 в разгоне: наклон в поворот, нос чуть задран
func _scene_race(vp: SubViewport) -> void:
	_cam(vp, Vector3(-4.6, 1.35, 5.4), Vector3(0.45, 0.62, -0.6), 27.0)
	var rv := RaceVisual.new()
	vp.add_child(rv)
	rv.setup("pahan", false)
	rv.rotation = Vector3(-0.06, 0.25, -0.22)
	rv.rig.play("RideBoost", 0.0)
	rv.power = 1.0
	var mate := RaceVisual.new()
	vp.add_child(mate)
	mate.setup("madk1d", false)
	mate.position = Vector3(-1.7, 0, -2.2)
	mate.rotation = Vector3(0.0, 0.35, 0.18)
	mate.rig.play("RideDrift", 0.0)
	mate.power = 0.8

## Пахан над столом, заваленным квитанциями и договорами; телефон светится, на стене — «ПРОСРОЧЕНО»
func _scene_microloans(vp: SubViewport) -> void:
	_cam(vp, Vector3(0.6, 2.35, 5.4), Vector3(0.0, 1.05, 0.0), 30.0)
	var ph := Rig.new()
	vp.add_child(ph)
	ph.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan(), false, -1.0, "mode_pahan_plain")
	ph.position = Vector3(-0.2, 0, -0.5)
	ph.rotation.y = 0.35
	ph.play("Idle", 0.0)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.92, 0.9, 0.85)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	var desk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.06, 0.8)
	desk.mesh = bm
	desk.material_override = dark
	desk.position = Vector3(0.1, 0.74, 0.45)
	vp.add_child(desk)
	for k in 9:
		var p := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.32, 0.005, 0.42)
		p.mesh = pm
		p.material_override = paper
		p.position = Vector3(-0.65 + float(k % 5) * 0.3, 0.78 + float(k) * 0.004, 0.32 + float(k / 5) * 0.26)
		p.rotation.y = float(k) * 0.37
		vp.add_child(p)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(1, 1, 1)
	glow.emission_energy_multiplier = 3.0
	var phone := MeshInstance3D.new()
	var phm := BoxMesh.new()
	phm.size = Vector3(0.16, 0.01, 0.3)
	phone.mesh = phm
	phone.material_override = glow
	phone.position = Vector3(0.75, 0.79, 0.55)
	phone.rotation.y = -0.4
	vp.add_child(phone)
	var lab := Label3D.new()
	lab.text = "ПРОСРОЧЕНО"
	lab.font_size = 110
	lab.pixel_size = 0.0019
	lab.position = Vector3(-0.15, 2.15, -1.6)
	lab.rotation.z = 0.12
	vp.add_child(lab)

## дверной проём в темноте: в нём стоит маскот БАЛОН (тот же, что в игре) и смотрит прямо в камеру
func _scene_five_nights(vp: SubViewport) -> void:
	_cam(vp, Vector3(0.0, 1.5, 6.2), Vector3(0.0, 1.25, 0.0), 30.0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	for x in [-1.25, 1.25]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 3.4, 0.4)
		post.mesh = pm
		post.material_override = dark
		post.position = Vector3(x, 1.7, 0.6)
		vp.add_child(post)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(3.0, 0.5, 0.4)
	lintel.mesh = lm
	lintel.material_override = dark
	lintel.position = Vector3(0, 3.1, 0.6)
	vp.add_child(lintel)
	var b := FNActors.preview_balon(vp)
	b.position = Vector3(0.05, 0, -0.3)

# ---------------- открытие, выбор ----------------
func open(start := -1) -> void:
	if not built:
		_build()
	visible = true
	if start >= 0:
		sel = start
	modulate.a = 0.0
	position = Vector2(40, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for k in arts.size():
		(arts[k]["root"] as Control).modulate.a = 0.0
	select(sel, false, true)

func close() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(self, "position:x", 40.0, 0.2)
	tw.chain().tween_callback(func():
		visible = false
		for a in arts:
			if a["vp"] != null:
				(a["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED)

func select(i: int, sound := true, force := false, kind := "card") -> void:
	i = posmod(i, MODES.size())
	if i == sel and not force:
		return
	if sound and i != sel:
		menu.main.ui(kind, 1.0 + (2 - i) * 0.03)
	var prev := sel
	sel = i
	for k in cards.size():
		var c: Dictionary = cards[k]
		var on := k == i
		var ok := available(k)
		(c["band"] as Polygon2D).visible = on
		(c["accent"] as Polygon2D).visible = on
		(c["num"] as Label).add_theme_color_override("font_color", Menu.INK if on else Color(1, 1, 1, 0.35))
		(c["title"] as Label).add_theme_color_override("font_color", (Menu.INK if ok else Color(0.3, 0.31, 0.33)) if on else (Menu.WHITE if ok else Menu.GREY))
		(c["ru"] as Label).add_theme_color_override("font_color", Color(0.2, 0.2, 0.22) if on else Menu.GREY)
		(c["title"] as Label).material = null if on else menu.worn
		var tag: ColorRect = c["tag"]
		tag.color = (Menu.INK if on else Menu.WHITE) if ok else RED
		(c["tag_l"] as Label).add_theme_color_override("font_color", (Menu.WHITE if on else Menu.INK) if ok else Menu.WHITE)
		(c["tag_l"] as Label).text = _tag(k)
		var root: Control = c["root"]
		var tw := root.create_tween()
		tw.tween_property(root, "position:x", 62.0 + k * 22.0 + (26.0 if on else 0.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if on:
			var band: Polygon2D = c["band"]
			band.scale = Vector2(0.86, 1.0)
			band.create_tween().tween_property(band, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var m: Dictionary = MODES[i]
	desc_title.text = "%s · %s" % [String(m["no"]), String(m["ru"])]
	var dsize := 30                          # длинное название режима не уходит за правый край экрана
	while dsize > 20 and menu.serif.get_string_size(desc_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dsize).x * 1.15 > 510.0:
		dsize -= 1
	desc_title.add_theme_font_size_override("font_size", dsize)
	desc_text.text = String(m["desc"]) if available(i) else String(m["desc"]) + " " + menu.race_status()
	desc_facts.text = "\n".join(m["facts"]) if available(i) else "статус: " + _tag(i).to_lower()
	menu.info.text = desc_text.text
	# композиция: прежняя уходит влево и гаснет, новая въезжает справа; белая полоса проходит по кадру
	for k in arts.size():
		var a: Dictionary = arts[k]
		var r: Control = a["root"]
		var vp: SubViewport = a["vp"]
		if k == i:
			if vp != null:
				vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			r.position = ART_POS + Vector2(90, 0)
			var tw2 := r.create_tween().set_parallel(true)
			tw2.tween_property(r, "modulate:a", 1.0, 0.3)
			tw2.tween_property(r, "position", ART_POS, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		elif k == prev or r.modulate.a > 0.0:
			var tw3 := r.create_tween().set_parallel(true)
			tw3.tween_property(r, "modulate:a", 0.0, 0.2)
			tw3.tween_property(r, "position", ART_POS - Vector2(70, 0), 0.24)
			if vp != null:
				tw3.chain().tween_callback(func(): if sel != k: vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	if not force or prev != i:
		wipe.visible = true
		wipe.position = Vector2(ART_POS.x - 200, 0)
		wipe.modulate.a = 0.9
		var tw4 := wipe.create_tween().set_parallel(true)
		tw4.tween_property(wipe, "position:x", 1700.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw4.tween_property(wipe, "modulate:a", 0.0, 0.32)
		tw4.chain().tween_callback(func(): wipe.visible = false)

func _tag(k: int) -> String:
	match String(MODES[k]["id"]):
		"story":
			return "ГЛАВА %02d" % menu.chapter_no() if menu.has_save else "НОВАЯ ИГРА"
		"training":
			return "6 СТИЛЕЙ · 5 ЗОН"
		"microloans":
			return ("ИДЁТ ДЕНЬ %d" % _ml_day()) if MLSave.has_run() else "7 ДНЕЙ"
		"five_nights":
			return ("НОЧЬ %d" % (int(FNSave.v("current")) + 1)) if (FNSave.v("beaten") as Array).size() > 0 else "НОЧЬ 1"
		_:
			return "ДОСТУПНО" if available(k) else "СКОРО"

func _ml_day() -> int:
	var r: Dictionary = MLSave.load_all().get("run", {})
	return int(r.get("day", 1))

func activate() -> void:
	menu.main.ui("confirm" if available(sel) else "deny")
	menu.open_mode(String(MODES[sel]["id"]))

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	for k in lines.size():
		var ln: Line2D = lines[k]
		ln.position.x -= dt * (900.0 + 120.0 * float(k % 4))
		if ln.position.x < -300.0:
			ln.position.x = ART_SIZE.x + randf_range(0, 200)
	# лёгкий параллакс композиции от курсора
	if sel < arts.size():
		var pic: TextureRect = arts[sel]["pic"]
		var vs := get_viewport_rect().size
		var mp := (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
		var home := Vector2(30, 0) if String(MODES[sel]["id"]) != "story" else Vector2(40, 0)
		pic.position = pic.position.lerp(home + Vector2(-mp.x * 16.0, -mp.y * 6.0 + sin(t * 0.8) * 2.0), 1.0 - exp(-5.0 * dt))
