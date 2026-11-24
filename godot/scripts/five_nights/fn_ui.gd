## Будка, планшет камер и служебные экраны «5 НОЧЕЙ С ПАХАНОМ».
## POST рисуется до интерфейса и обрабатывает будку. У видеосигнала свой шейдер.
class_name FNUI
extends CanvasLayer

const RED := Color(0.86, 0.08, 0.06)
const DIM := Color(0.75, 0.72, 0.66)
const TabletShell := preload("res://scripts/five_nights/fn_tablet_shell.gd")
const POST := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float fx = 1.0;
uniform float t = 0.0;
uniform float hurt = 0.0;        // всплеск искажения (скример, одержимость)
uniform float booth = 0.0;        // в будке различимы краска, лампы и тени в проёмах
uniform float dark = 0.0;
uniform float inv = 0.0;         // вывернутые цвета (скример GHOST)
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float ab = (mix(0.0015, 0.00042, booth) + hurt * 0.012) * fx;
	vec3 c;
	c.r = texture(scr, uv + vec2(ab, 0.0)).r;
	c.g = texture(scr, uv).g;
	c.b = texture(scr, uv - vec2(ab, 0.0)).b;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float red = clamp((c.r - max(c.g, c.b)) * 2.2, 0.0, 1.0);
	vec3 mono = vec3(l) * vec3(1.02, 0.99, 0.94);
	vec3 col = mix(mix(mono, c, booth * 0.60), vec3(c.r * 1.1, c.g * 0.35, c.b * 0.3), red);
	// полутон в тенях: точки решёткой
	vec2 g = FRAGCOORD.xy / 5.0;
	float dotm = length(fract(g) - 0.5);
	float shade = smoothstep(0.32, 0.0, l);
	col *= 1.0 - shade * smoothstep(0.18, 0.42, dotm) * mix(0.55, 0.32, booth) * fx;
	col += (h(FRAGCOORD.xy + t * 61.0) - 0.5) * mix(0.07, 0.035, booth) * fx;
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * (1.1 + dark * 1.5);
	col = mix(col, col * vec3(1.3, 0.5, 0.45), hurt * 0.4);
	col = mix(col, vec3(1.0) - col, inv);
	COLOR = vec4(col, 1.0);
}
"""

var root                            # FiveNightsRoot
var big: Font
var mono: Font
var post: ColorRect
var post_mat: ShaderMaterial
var hud: Control
var time_l: Label
var night_l: Label
var clock_box: VBoxContainer
var power_box: VBoxContainer
var power_l: Label
var usage_bars: Array = []
var usage_row: HBoxContainer
var eta_l: Label
var alarm_l: Label
var alarm_t := 0.0
var msg_l: Label
var msg_t := 0.0
var sub_box: PanelContainer
var sub_l: Label
var sub_skip: Control
var tablet: Control
var tablet_k := 0.0
var tablet_pose := -1.0
var tablet_shell: TabletShell
var tablet_face: Control
var feed: TextureRect
var cam_l: Label
var tab_clock: Label
var tab_night: Label
var signal_l: Label
var rec_dot: ColorRect
var ping_l: Label
var map_box: Control
var tab_power: Label
var tab_load: Label
var tab_segments: Control
var lower_button: Button
var map_btns := {}                  # id → Button
var cam9_btn: Button
var card: Control                   # заставка ночи / 6 AM / гибель
var dark_box: PanelContainer
var dark_bar: Dictionary
var pause_box: Control
var pause_first: Button
var t := 0.0
var fx_k := 1.0
var hurt := 0.0
var card_gen := 0                   # поколение карточки: отложенные вызовы старой карточки не рисуют поверх новой
var inv_t := 0.0
var neg := false                    # цветокор «негатив» целиком (скример Пахана)

## ПУЛЬТ ОХРАНЫ: все устройства будки одной строкой снизу — клавиша, название, состояние. Порядок как в комнате:
## слева то, что слева. tip — что делает и чего стоит (показывается при наведении на плашку или на саму кнопку в будке).
const DEVICES := [
	{"id": "door_l", "key": "A", "name": "ЛЕВАЯ ДВЕРЬ", "tip": "Закрывает левый проём от тех, кто пришёл по левому коридору. Пока закрыта — тратит энергию."},
	{"id": "light_l", "key": "Q", "name": "СВЕТ СЛЕВА", "tip": "Держи клавишу: фонарь показывает, кто стоит за левой дверью. Пока горит — тратит энергию."},
	{"id": "seal_l", "key": "Z", "name": "ВЕНТИЛЯЦИЯ СЛЕВА", "tip": "Заслонка левой шахты: от тех, кто ползёт по вентиляции. Пока закрыта — тратит энергию."},
	{"id": "monitor", "key": "ПРОБЕЛ", "name": "КАМЕРЫ", "tip": "Поднять планшет: восемь комнат, приманка и перезапуск камеры. Пока поднят — тратит энергию."},
	{"id": "reset", "key": "R", "name": "СБРОС СИСТЕМЫ", "tip": "Снимает сбои и ложные показания. Стоит 2,5 % энергии, камеры гаснут на несколько секунд."},
	{"id": "seal_t", "key": "X", "name": "ЛЮК СВЕРХУ", "tip": "Заслонка верхней шахты над столом: от тех, кто лезет сверху. Пока закрыта — тратит энергию. Посмотреть на люк — стрелка вверх или мышь к верхнему краю."},
	{"id": "light_r", "key": "E", "name": "СВЕТ СПРАВА", "tip": "Держи клавишу: фонарь показывает, кто стоит за правой дверью. Пока горит — тратит энергию."},
	{"id": "door_r", "key": "D", "name": "ПРАВАЯ ДВЕРЬ", "tip": "Закрывает правый проём от тех, кто пришёл по правому коридору. Пока закрыта — тратит энергию."},
]
const DECK_H := 62.0
var deck: HBoxContainer
var tips: MGHints                  # подсказки и справка (H) — mg_hints.gd
var deck_rows := {}                 # id → {panel, sb, name, state}
var tip_box: PanelContainer
var tip_l: Label
var tip_id := ""                    # над какой плашкой мышь
var tip_3d := ""                    # над какой кнопкой будки мышь (ставит fn_root)
## Расширенный пульт включается через F1 или настройки.
const TOAST_LEN := 1.6
var deck_pin := false
var deck_shown := false
var toast_l: Label
var toast_t := 0.0
var look_hint := false              # первая ночь: подсказка «как осмотреться»
var act_lure: Label
var act_fix: Label
var act_reset: Label

const EDGE := 24.0
const MAP_SIZE := Vector2(352, 237)
const CAM_BTN := Vector2(57, 22)
const FRAME_INSET := 16.0
const RAISE_TIME := 0.25
const LOWER_TIME := 0.21
const CCTV_INK := Color("#e1e3dc")
const CCTV_REC := Color("#e26052")
const CCTV_FAULT := Color("#e29a90")
const SIGNAL_TEXT := ["ЗАПИСЬ", "СМЕНА КАНАЛА", "ПОМЕХИ", "НЕТ СИГНАЛА", "СИНХРОНИЗАЦИЯ"]
const LOAD_INK := [Color("#8abe62"), Color("#92c361"), Color("#bcc263"), Color("#d9ac51"), Color("#db8148"), Color("#db574e")]
const MAP_ROOMS := {
	"stage": Vector2(96, 54),
	"arcade": Vector2(90, 50),
	"storage": Vector2(77, 42),
	"hall_l": Vector2(68, 43),
	"hall_r": Vector2(68, 43),
	"server": Vector2(86, 45),
	"vent": Vector2(62, 35),
	"power": Vector2(81, 49),
	"booth": Vector2(54, 22),
}
const MAP_LINKS := [
	["storage", "arcade"], ["stage", "arcade"], ["arcade", "hall_l"],
	["stage", "server"], ["server", "power"], ["power", "hall_r"],
	["hall_l", "booth"], ["hall_r", "booth"],
]

func setup(r) -> void:
	root = r
	layer = 5
	big = MGUI.font("caps")
	mono = MGUI.font("mono")
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
	# подсказки смены — слева посередине (энергия — слева снизу, пульт — внизу); молчат вне ночи и в скримере
	tips = MGHints.new().setup("fn", MGHintsData.FN, "left", 0.42)
	tips.hold_fn = func(): return root == null or root.state != "night" or (root.scare != null and root.scare.busy) or root.intro_t > 0.0 or tablet_k >= 0.60
	add_child(tips)
	# часы: ночь мелко, время крупно — справа сверху
	clock_box = MGUI.vbox(0)
	hud.add_child(clock_box)
	night_l = _out(MGUI.label("", "mono", MGUI.TEXT_2))
	night_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(night_l)
	time_l = _out(MGUI.label("", "caps_h", Color(0.92, 0.9, 0.85)))
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(time_l)
	# энергия: процент, нагрузка полосками, на сколько хватит — слева снизу
	power_box = MGUI.vbox(MGUI.S1)
	hud.add_child(power_box)
	power_l = _out(MGUI.label("", "mono_m", DIM))
	power_box.add_child(power_l)
	usage_row = MGUI.hbox(3)
	power_box.add_child(usage_row)
	var ul := _out(MGUI.label("НАГРУЗКА", "mono_s", MGUI.TEXT_2))
	usage_row.add_child(ul)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(MGUI.S1, 0)
	usage_row.add_child(gap)
	for k in 6:
		var b := ColorRect.new()
		b.custom_minimum_size = Vector2(9, 14)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		usage_row.add_child(b)
		usage_bars.append(b)
	eta_l = _out(MGUI.label("", "mono_s", MGUI.TEXT_2))
	power_box.add_child(eta_l)
	# ложная тревога MOD — коротко сверху по центру; мысли Пахана — ниже середины; обе сами гаснут
	alarm_l = _out(MGUI.label("", "caps_l", RED))
	alarm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alarm_l.set_meta("audit_skip", true)
	hud.add_child(alarm_l)
	msg_l = _out(MGUI.label("", "body_b", Color(0.95, 0.93, 0.88)))
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_l.set_meta("audit_skip", true)
	hud.add_child(msg_l)
	# Небольшие субтитры с обводкой для контраста поверх ярких экранов.
	sub_box = MGUI.panel(true, null, MGUI.S1)
	sub_box.add_theme_stylebox_override("panel", MGUI.box(Color(0.01, 0.01, 0.012, 0.32), 3, 0, Color.TRANSPARENT, MGUI.S1))
	sub_box.visible = false
	hud.add_child(sub_box)
	var subtitles := MGUI.vbox(2)
	sub_box.add_child(subtitles)
	sub_l = _out(MGUI.label("", "small", Color(0.92, 0.9, 0.84)))
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitles.add_child(sub_l)
	var skip_label := _out(MGUI.label("F  Прервать звонок", "micro", MGUI.TEXT_2))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitles.add_child(skip_label)
	sub_skip = skip_label
	_deck()
	deck_pin = extended_hints_enabled()
	_tablet()
	_dark()
	_pause()
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	get_viewport().size_changed.connect(_layout)
	_layout()

## ПУЛЬТ: плашки устройств. Каждая — клавиша, название, состояние; нажимается мышью; при наведении — что делает.
func _deck() -> void:
	deck = MGUI.hbox(6)
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(deck)
	for D in DEVICES:
		var id := String(D["id"])
		var p := PanelContainer.new()
		var sb := MGUI.box(Color(0.03, 0.03, 0.04, 0.62), 3, 1, Color(0.24, 0.24, 0.27), 8)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(0, DECK_H)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		deck.add_child(p)
		var v := MGUI.vbox(3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var top := MGUI.hbox(6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		top.add_child(MGUI.keycap(String(D["key"])))
		var nm := MGUI.label(String(D["name"]), "caps", MGUI.TEXT)
		top.add_child(nm)
		var stl := MGUI.label("", "mono", MGUI.TEXT_2)
		v.add_child(stl)
		deck_rows[id] = {"panel": p, "sb": sb, "name": nm, "state": stl, "d": D}
		p.mouse_entered.connect(func(): tip_id = id)
		p.mouse_exited.connect(func():
			if tip_id == id:
				tip_id = "")
		p.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				root.deck_press(id, e.pressed))
	toast_l = _out(MGUI.label("", "mono", Color(0.92, 0.9, 0.84)))
	hud.add_child(toast_l)
	toast_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_l.visible = false
	tip_box = MGUI.panel(true, null, MGUI.S1)
	tip_box.add_theme_stylebox_override("panel", MGUI.box(Color(0.01, 0.01, 0.012, 0.53), 3, 0, Color.TRANSPARENT, MGUI.S1))
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box.visible = false
	hud.add_child(tip_box)
	tip_l = _out(MGUI.label("", "small", MGUI.TEXT))
	tip_box.add_child(tip_l)

## состояние устройства для пульта: [надпись, цвет, включено, недоступно, что сделает нажатие]
func dev_state(st: FNNight, id: String) -> Array:
	var off := MGUI.TEXT_2
	if st.power_out:
		return ["НЕТ ПИТАНИЯ", MGUI.TEXT_3, false, true, ""]
	match id:
		"door_l", "door_r":
			var s := id.substr(5)
			var led := st.door_led(s)                         # сбои MOD: индикатор может врать или молчать
			if led < 0:
				return ["НЕТ ДАННЫХ", MGUI.WARN, false, false, "ПЕРЕКЛЮЧИТЬ"]
			return ["ЗАКРЫТА", RED, true, false, "ОТКРЫТЬ"] if led == 1 else ["ОТКРЫТА", off, false, false, "ЗАКРЫТЬ"]
		"light_l", "light_r":
			if st.brown_t > 0.0:
				return ["ПЕРЕБОЙ", MGUI.WARN, false, true, ""]
			return ["ГОРИТ", MGUI.GOLD, true, false, "ОТПУСТИ — ПОГАСНЕТ"] if st.light[id.substr(6)] else ["ВЫКЛ · ДЕРЖАТЬ", off, false, false, "ВКЛЮЧИТЬ"]
		"seal_l", "seal_t":
			return ["ЗАКРЫТА", RED, true, false, "ОТКРЫТЬ"] if st.seal[id.substr(5)] else ["ОТКРЫТА", off, false, false, "ЗАКРЫТЬ"]
		"monitor":
			if st.cam_off_t > 0.0:
				return ["ПЕРЕЗАГРУЗКА %d с" % ceili(st.cam_off_t), MGUI.WARN, false, false, "ОТКРЫТЬ"]
			return ["ОТКРЫТЫ", MGUI.GOLD, true, false, "ЗАКРЫТЬ"] if st.monitor else ["ЗАКРЫТЫ", off, false, false, "ОТКРЫТЬ"]
		"reset":
			if st.power <= float(FNData.POWER["reset"]) + 0.5:
				return ["МАЛО ЭНЕРГИИ", MGUI.TEXT_3, false, true, ""]
			if st.cam_off_t > 0.0:
				return ["ИДЁТ · %d с" % ceili(st.cam_off_t), MGUI.WARN, true, false, ""]
			return ["ГОТОВ · −2,5 %", off, false, false, "ВЫПОЛНИТЬ"]
	return ["", off, false, false, ""]

## строка «УСТРОЙСТВО — ДЕЙСТВИЕ» и пояснение: для подсказки при наведении
func dev_tip(st: FNNight, id: String) -> String:
	if not deck_rows.has(id):
		return ""
	var D: Dictionary = deck_rows[id]["d"]
	var s := dev_state(st, id)
	var head := "%s — %s" % [D["name"], s[4]] if String(s[4]) != "" else "%s — %s" % [D["name"], s[0]]
	return "%s   [%s]\n%s" % [head, D["key"], D["tip"]]

func _deck_tick(st: FNNight) -> void:
	var office_visible: bool = tablet_k < 0.5 and not st.power_out and card.get_child_count() == 0 and not pause_box.visible and String(root.state) == "night"
	var detailed := office_visible and deck_pin
	deck.visible = detailed
	if detailed != deck_shown:
		deck_shown = detailed
		_layout.call_deferred()
	var hover := tip_id if detailed and tip_id != "" else tip_3d
	var tip := ""
	if detailed:
		for id in deck_rows:
			var r: Dictionary = deck_rows[id]
			var s := dev_state(st, String(id))
			(r["state"] as Label).text = String(s[0])
			(r["state"] as Label).add_theme_color_override("font_color", s[1])
			var sb: StyleBoxFlat = r["sb"]
			var on: bool = s[2]
			var dis: bool = s[3]
			sb.bg_color = Color(0.2, 0.03, 0.03, 0.62) if on and (s[1] as Color) == RED else (Color(0.2, 0.16, 0.04, 0.62) if on else Color(0.03, 0.03, 0.04, 0.62))
			sb.border_color = (s[1] as Color) if on else (Color(0.95, 0.93, 0.88) if hover == id else Color(0.24, 0.24, 0.27))
			sb.set_border_width_all(2 if on or hover == id else 1)
			(r["name"] as Label).add_theme_color_override("font_color", MGUI.TEXT_3 if dis else MGUI.TEXT)
			(r["panel"] as Control).modulate.a = 0.6 if dis else 1.0
		tip = dev_tip(st, hover)
	elif office_visible and deck_rows.has(hover):
		var data: Dictionary = deck_rows[hover]["d"]
		var title: String = data["name"]
		tip = "%s  ·  %s" % [data["key"], title.left(1) + title.substr(1).to_lower()]
	if office_visible and tip == "":
		if hover == "phone" and sub_box.visible:
			tip = "F  ·  Прервать звонок"
		elif look_hint:
			tip = "← →  Осмотреться     ПРОБЕЛ  Планшет     H  Справка"
	var show_tip := tip != "" and toast_t <= 0.0
	if tip_l.text != tip or tip_box.visible != show_tip:
		tip_l.text = tip
		tip_box.visible = show_tip
		_layout.call_deferred()

func night_begin(_night: int, _first_time: bool) -> void:
	tablet_k = 0.0
	tablet_pose = -1.0
	tablet.hide()
	cam9_btn.hide()
	tip_id = ""
	tip_3d = ""
	toast_t = 0.0
	toast_l.visible = false

static func extended_hints_enabled() -> bool:
	return bool((FNSave.v("settings") as Dictionary).get("deck", false))

## F1 и меню меняют одну настройку.
func toggle_deck_pin() -> void:
	deck_pin = not deck_pin
	tip_id = ""
	toast_t = 0.0
	var cfg: Dictionary = FNSave.v("settings")
	cfg["deck"] = deck_pin
	FNSave.save()

## В обучении кратко подтверждаем действие устройства.
func toast(id: String) -> void:
	if not look_hint or deck_pin or tablet_k > 0.5 or root.st == null or root.st.power_out or not deck_rows.has(id):
		return
	var D: Dictionary = deck_rows[id]["d"]
	toast_l.text = "%s — %s" % [D["name"], dev_state(root.st, id)[0]]
	toast_t = TOAST_LEN
	toast_l.visible = true
	_layout.call_deferred()

func _toast_tick(st: FNNight, dt: float) -> void:
	toast_t = maxf(0.0, toast_t - dt)
	var k := minf(minf(toast_t, TOAST_LEN - toast_t) / 0.15, 1.0)
	toast_l.modulate.a = clampf(k, 0.0, 1.0)
	toast_l.visible = toast_t > 0.0 and not deck_shown and tablet_k < 0.5 and not st.power_out and not pause_box.visible

## надпись поверх сцены: тёмная обводка, чтобы читалась на любом фоне
func _out(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _label(parent: CanvasItem, text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size

func _layout() -> void:
	var s := _vs()
	clock_box.position = Vector2(s.x - EDGE - 240, EDGE - 6)
	clock_box.size = Vector2(240, 0)
	var deck_top := s.y
	if deck != null:
		deck.reset_size()
		var dw := deck.get_combined_minimum_size().x
		deck.position = Vector2((s.x - dw) * 0.5, s.y - 12.0 - DECK_H)
		deck_top = deck.position.y if deck_shown else s.y - EDGE + 10.0
		tip_l.custom_minimum_size.x = minf(520.0, s.x - EDGE * 2.0) if deck_shown else 0.0
		tip_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if deck_shown else TextServer.AUTOWRAP_OFF
		tip_box.reset_size()
		var ts := tip_box.get_combined_minimum_size()
		tip_box.position = Vector2((s.x - ts.x) * 0.5, deck_top - ts.y - 8.0)
	power_box.reset_size()
	power_box.position = Vector2(EDGE, deck_top - 10.0 - power_box.get_combined_minimum_size().y)
	alarm_l.position = Vector2(s.x * 0.2, EDGE)
	alarm_l.size = Vector2(s.x * 0.6, 30)
	msg_l.position = Vector2(s.x * 0.25, s.y * 0.64)
	msg_l.size = Vector2(s.x * 0.5, 50)
	sub_l.custom_minimum_size.x = minf(500.0, s.x - EDGE * 2.0)
	sub_box.reset_size()
	# звонок — над плашкой генератора, если она на экране (обе живут снизу по центру)
	var lift := 110.0 if dark_box != null and dark_box.visible else 0.0
	var tip_h: float = (tip_box.get_combined_minimum_size().y + 8.0) if tip_box.visible else (24.0 if toast_l.visible else 0.0)
	sub_box.position = Vector2((s.x - sub_box.get_combined_minimum_size().x) * 0.5, s.y - EDGE - sub_box.get_combined_minimum_size().y - (70 if deck_shown or lift > 0.0 else 10) - lift - tip_h)
	toast_l.reset_size()
	toast_l.position = Vector2((s.x - toast_l.get_combined_minimum_size().x) * 0.5, s.y - 12.0 - 34.0)
	if tablet != null:
		_cctv_layout(s)
		_pose_tablet()
	if dark_box != null:
		dark_box.reset_size()
		dark_box.position = Vector2((s.x - dark_box.get_combined_minimum_size().x) * 0.5, s.y - 190)
		pause_box.size = s

# ---------------- монитор охраны ----------------
func _tablet() -> void:
	tablet = Control.new()
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.hide()
	add_child(tablet)

	tablet_shell = TabletShell.new()
	tablet.add_child(tablet_shell)

	tablet_face = Control.new()
	tablet_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(tablet_face)
	feed = TextureRect.new()
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.stretch_mode = TextureRect.STRETCH_SCALE
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet_face.add_child(feed)
	feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var border := Panel.new()
	border.add_theme_stylebox_override("panel", MGUI.box(Color.TRANSPARENT, 0, 1, Color(0.93, 0.94, 0.91, 0.72), 0))
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet_face.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.offset_left = FRAME_INSET
	border.offset_right = -FRAME_INSET
	border.offset_top = FRAME_INSET
	border.offset_bottom = -FRAME_INSET

	rec_dot = _cctv_rect(tablet_face, Vector2(32, 38), Vector2(7, 7), CCTV_REC)
	signal_l = _cctv_label(tablet_face, "", Rect2(48, 28, 300, 27), 15)
	tab_clock = _cctv_label(tablet_face, "", Rect2(0, 25, 220, 36), 31, HORIZONTAL_ALIGNMENT_RIGHT)
	tab_night = _cctv_label(tablet_face, "", Rect2(0, 65, 220, 23), 17, HORIZONTAL_ALIGNMENT_RIGHT)
	tab_power = _cctv_label(tablet_face, "", Rect2(32, 0, 270, 32), 22)
	tab_load = _cctv_label(tablet_face, "НАГРУЗКА", Rect2(32, 0, 98, 21), 15)
	tab_segments = Control.new()
	tab_segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet_face.add_child(tab_segments)
	for i in usage_bars.size():
		_cctv_rect(tab_segments, Vector2(i * 15, 0), Vector2(11, 13), Color.TRANSPARENT)

	map_box = Control.new()
	map_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_box.size = MAP_SIZE
	map_box.draw.connect(_map_draw)
	tablet_face.add_child(map_box)
	for c in FNData.CAMS:
		var id: String = c["id"]
		var button := _cam_btn(c["no"], id, c["name"])
		button.position = _map_center(c) - CAM_BTN * 0.5
		map_btns[id] = button
	cam9_btn = _cam_btn("9", "room9", FNData.CAM9["name"])
	cam9_btn.position = _map_center(FNData.CAM9) - CAM_BTN * 0.5 - Vector2(0, 12)
	cam9_btn.hide()

	cam_l = _cctv_label(tablet_face, "", Rect2(0, 0, MAP_SIZE.x, 27), 20)
	ping_l = _cctv_label(tablet_face, "", Rect2(0, 0, MAP_SIZE.x, 23), 15)
	act_lure = _cctv_label(tablet_face, "", Rect2(0, 0, 220, 23), 15)
	act_fix = _cctv_label(tablet_face, "", Rect2(0, 0, 220, 23), 15)
	act_reset = _cctv_label(tablet_face, "R СБРОС", Rect2(0, 0, 122, 23), 15, HORIZONTAL_ALIGNMENT_RIGHT)

	lower_button = Button.new()
	lower_button.custom_minimum_size = Vector2(144, 24)
	lower_button.size = lower_button.custom_minimum_size
	lower_button.focus_mode = Control.FOCUS_NONE
	lower_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lower_button.tooltip_text = "Опустить монитор · Пробел"
	lower_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	lower_button.add_theme_stylebox_override("hover", MGUI.box(Color(0, 0, 0, 0.44), 0, 1, Color(1, 1, 1, 0.34), 0))
	lower_button.add_theme_stylebox_override("pressed", lower_button.get_theme_stylebox("hover"))
	lower_button.draw.connect(func():
		var marker := PackedVector2Array([Vector2(62, 9), Vector2(72, 15), Vector2(82, 9)])
		lower_button.draw_polyline(marker, Color(0, 0, 0, 0.8), 4.0, true)
		lower_button.draw_polyline(marker, CCTV_INK, 1.25, true))
	lower_button.pressed.connect(func(): root.deck_press("monitor", true))
	tablet_face.add_child(lower_button)

func _cctv_label(parent: Control, value: String, rect: Rect2, font_size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(parent, value, font_size, CCTV_INK, mono)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 4)
	return label

func _cctv_rect(parent: Control, at: Vector2, dimensions: Vector2, ink: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = ink
	fill.position = at
	fill.size = dimensions
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill

func _cctv_layout(frame: Vector2) -> void:
	tablet.size = frame
	tablet_face.size = frame
	tab_clock.position.x = frame.x - 32.0 - tab_clock.size.x
	tab_night.position.x = tab_clock.position.x
	tab_power.position.y = frame.y - 78.0
	tab_load.position.y = frame.y - 49.0
	tab_segments.position = Vector2(130, frame.y - 45.0)
	lower_button.position = Vector2((frame.x - lower_button.size.x) * 0.5, frame.y - 36.0)
	map_box.position = frame - MAP_SIZE - Vector2(32, 54)
	_cctv_map_labels()

func _cctv_map_labels() -> void:
	var at := map_box.position
	cam_l.position = at - Vector2(0, 51.0 if ping_l.visible else 29.0)
	ping_l.position = at - Vector2(0, 23)
	act_lure.position = at + Vector2(0, MAP_SIZE.y + 2.0)
	act_fix.position = act_lure.position
	act_reset.position = at + Vector2(MAP_SIZE.x - act_reset.size.x, MAP_SIZE.y + 2.0)

## План сохраняет координаты, связи и отдельный скрытый канал ОБЛАКА.
func _map_center(c: Dictionary) -> Vector2:
	return Vector2(26.0, 18.0) + (c["map"] as Vector2) * Vector2(300.0, 204.0)

func _map_draw() -> void:
	var wall := Color(0.93, 0.95, 0.91, 0.75)
	var shadow := Color(0.0, 0.0, 0.0, 0.88)
	var fill := Color(0.025, 0.025, 0.023, 0.43)
	var centers := {"booth": Vector2(176, 222)}
	for c in FNData.CAMS:
		centers[c["id"]] = _map_center(c)

	for link in MAP_LINKS:
		var a: Vector2 = centers[link[0]]
		var b: Vector2 = centers[link[1]]
		var room_a: Vector2 = MAP_ROOMS[link[0]]
		var room_b: Vector2 = MAP_ROOMS[link[1]]
		var path: PackedVector2Array
		if link == ["stage", "server"]:
			path = PackedVector2Array([a + Vector2(room_a.x * 0.5, 0), b - Vector2(room_b.x * 0.5, 0)])
		elif link == ["stage", "arcade"]:
			var drop := a.x - 26.0
			path = PackedVector2Array([Vector2(drop, a.y + room_a.y * 0.5), Vector2(drop, b.y), b + Vector2(room_b.x * 0.5, 0)])
		elif link[1] == "booth":
			var wall_entry := Vector2(signf(a.x - b.x) * room_b.x * 0.5, 0)
			path = PackedVector2Array([a + Vector2(0, room_a.y * 0.5), Vector2(a.x, b.y), b + wall_entry])
		else:
			var left := maxf(a.x - room_a.x * 0.5, b.x - room_b.x * 0.5)
			var right := minf(a.x + room_a.x * 0.5, b.x + room_b.x * 0.5)
			var x := lerpf(left, right, 0.5)
			path = PackedVector2Array([Vector2(x, a.y + room_a.y * 0.5), Vector2(x, b.y - room_b.y * 0.5)])
		map_box.draw_polyline(path, shadow, 3.5, true)
		map_box.draw_polyline(path, wall, 1.1, true)

	var stage: Vector2 = centers["stage"]
	var vent: Vector2 = centers["vent"]
	var booth: Vector2 = centers["booth"]
	map_box.draw_dashed_line(stage + Vector2(0, 27), vent - Vector2(0, (MAP_ROOMS["vent"] as Vector2).y * 0.5), wall, 1.25, 5.0, true, true)
	map_box.draw_dashed_line(vent + Vector2(0, (MAP_ROOMS["vent"] as Vector2).y * 0.5), booth - Vector2(0, 11), wall, 1.25, 5.0, true, true)
	for id in MAP_ROOMS:
		var extent: Vector2 = MAP_ROOMS[id]
		var center: Vector2 = centers[id]
		var room := Rect2(center - extent * 0.5, extent)
		map_box.draw_rect(room, fill)
		map_box.draw_rect(room, shadow, false, 3.5, true)
		map_box.draw_rect(room, wall, false, 1.1, true)
	map_box.draw_string(mono, booth + Vector2(-26, 4), "ПОСТ", HORIZONTAL_ALIGNMENT_CENTER, 52.0, 12, CCTV_INK)

func _cam_btn(no: String, id: String, room: String) -> Button:
	var button := Button.new()
	button.text = "CAM " + no.pad_zeros(2)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = CAM_BTN
	button.tooltip_text = "%s · %s" % [button.text, room]
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", mono)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", MGUI.box(Color("#171a16"), 0, 1, CCTV_INK, 0))
	button.pressed.connect(func(): root.pick_cam(id))
	map_box.add_child(button)
	button.size = CAM_BTN
	return button

func _camera_marker(button: Button, id: String, st: FNNight) -> void:
	var active := id == st.cam
	var failed := st.cam_broken(id)
	var state := int(active) + int(failed) * 2
	if button.get_meta("signal_style", -1) == state:
		return
	button.set_meta("signal_style", state)
	var ink := Color("#1b2117") if active else CCTV_INK
	var fill := Color("#b9c68a") if active else Color(0.026, 0.03, 0.026, 0.86)
	var edge := CCTV_FAULT if failed else CCTV_INK
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_stylebox_override("normal", MGUI.box(fill, 0, 1, edge, 0))
	var hover := MGUI.box(fill.lightened(0.13), 0, 1, edge, 0)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)

func _pose_tablet() -> void:
	# Пока стекло не закрыло будку, видеопоток остаётся за плоскостью корпуса.
	tablet_face.visible = tablet_k >= 1.0
	tablet_shell.visible = tablet_k > 0.0 and not tablet_face.visible
	if tablet_shell.visible:
		tablet_shell.pose(tablet_k, _vs())

func _tablet_motion(st: FNNight, dt: float) -> void:
	if String(root.state) == "night":
		var open := st.monitor and not st.power_out
		var target := 1.0 if open else 0.0
		tablet_k = move_toward(tablet_k, target, dt / (RAISE_TIME if open else LOWER_TIME))
	# Скример MOD и финал скримера используют существующее прямое управление tablet_k.
	tablet.visible = tablet_k > 0.0
	if tablet_k != tablet_pose:
		tablet_pose = tablet_k
		_pose_tablet()

func _tablet_telemetry(st: FNNight, cams: FNCams, night_name: String, hide_usage: bool) -> void:
	var index := FNData.CAMS.find_custom(func(c): return c["id"] == st.cam)
	cam_l.text = FNData.CAM9["name"] if st.cam == "room9" else st.cam_label(maxi(index, 0))
	tab_clock.text = st.clock()
	tab_night.text = night_name

	var state := cams.signal_state
	signal_l.text = SIGNAL_TEXT[state]
	if state == FNCams.SignalState.LOST:
		if st.brown_t > 0.0:
			signal_l.text = "ПЕРЕБОЙ ПИТАНИЯ"
		elif st.cam_broken(cams.cur):
			signal_l.text = "КАМЕРА НЕ ОТВЕЧАЕТ"
	rec_dot.color = CCTV_FAULT if state == FNCams.SignalState.LOST else CCTV_REC

	var bot: FNBot = st.enemies["bot"]
	var ping := bot.ping_left > 0.0 and not st.glitches.has("leds_off")
	if ping_l.visible != ping:
		ping_l.visible = ping
		_cctv_map_labels()
	if ping:
		ping_l.text = ("ПИНГ ПРИНИМАЕТСЯ · %d С" if st.cam == "server" else "ПИНГ · ОТКРОЙ CAM 06 · %d С") % ceili(bot.ping_left)

	var broken := st.cam_broken(st.cam)
	act_fix.visible = broken
	act_fix.text = "ДЕРЖИ C · %d%%" % int(st.fix_t / FNNight.FIX_NEED * 100.0)
	act_lure.visible = not broken and st.cam in FNNight.LURE_ROOMS and st.brown_t <= 0.0
	if st.lure_cd > 0.0:
		act_lure.text = "ПРИМАНКА · %d С" % ceili(st.lure_cd)
	elif st.power > FNNight.LURE_POWER + 0.5:
		act_lure.text = "L ПРИМАНКА"
	else:
		act_lure.text = "МАЛО ЭНЕРГИИ ДЛЯ L"
	act_reset.text = "СБРОС..." if st.cam_off_t > 0.0 else "R СБРОС"

	tab_power.text = "ЭНЕРГИЯ %d%%" % ceili(st.power)
	tab_power.add_theme_color_override("font_color", CCTV_FAULT if st.power < 15.0 else CCTV_INK)
	tab_load.visible = not hide_usage
	tab_segments.visible = not hide_usage
	for i in tab_segments.get_child_count():
		var segment := tab_segments.get_child(i) as ColorRect
		segment.color = LOAD_INK[mini(i, LOAD_INK.size() - 1)] if i < st.usage else Color(0.72, 0.73, 0.69, 0.15)

	for camera_id in map_btns:
		_camera_marker(map_btns[camera_id], camera_id, st)
	_camera_marker(cam9_btn, "room9", st)

# ---------------- темнота и пауза ----------------
func _dark() -> void:
	dark_box = MGUI.panel(true, RED, MGUI.S3)
	dark_box.visible = false
	add_child(dark_box)
	var v := MGUI.vbox(MGUI.S2)
	dark_box.add_child(v)
	var h := MGUI.hbox(MGUI.S3)
	v.add_child(h)
	h.add_child(MGUI.label("РУЧНОЙ ГЕНЕРАТОР", "caps_m", Color(0.9, 0.86, 0.8)))
	h.add_child(MGUI.hints([["A", ""], ["D", "по очереди"]]))
	dark_bar = MGUI.bar(340, 8, RED)
	v.add_child(dark_bar["box"])

func _pause() -> void:
	pause_box = Control.new()
	pause_box.visible = false
	pause_box.set_meta("audit_modal", true)
	add_child(pause_box)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.add_child(cc)
	var p := MGUI.panel(false, null, MGUI.S5)
	p.custom_minimum_size = Vector2(320, 0)
	cc.add_child(p)
	var v := MGUI.vbox(MGUI.S2)
	p.add_child(v)
	v.add_child(MGUI.label("ПАУЗА", "caps_l", RED))
	v.add_child(MGUI.label("ночь не идёт, пока открыта пауза", "mono_s"))
	v.add_child(MGUI.hsep())
	for it in [["ПРОДОЛЖИТЬ", func(): root.set_paused(false)], ["НАЧАТЬ НОЧЬ ЗАНОВО", func(): root.retry()], ["В МЕНЮ ОХРАНЫ", func(): root.to_terminal()]]:
		var b := MGUI.button(String(it[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[1])
		v.add_child(b)
		if pause_first == null:
			pause_first = b
	v.add_child(MGUI.hints([["↑↓", "выбор"], ["Enter", "открыть"], ["Esc", "продолжить"]]))

# ---------------- каждый кадр ----------------
func tick(st: FNNight, dt: float, cams: FNCams) -> void:
	t += dt
	hurt = maxf(0.0, hurt - dt * 1.5)
	var g: FNGhost = st.enemies["ghost"]
	post_mat.set_shader_parameter("t", t)
	post_mat.set_shader_parameter("fx", fx_k)
	post_mat.set_shader_parameter("hurt", maxf(hurt, g.haunt * 0.6))
	post_mat.set_shader_parameter("booth", 1.0 if root.state == "night" else 0.0)
	post_mat.set_shader_parameter("dark", 1.0 if st.power_out else 0.0)
	inv_t = maxf(0.0, inv_t - dt)
	post_mat.set_shader_parameter("inv", 1.0 if neg or (inv_t > 0.0 and fposmod(t, 0.12) < 0.08) else 0.0)
	var night_name := "СВОЯ НОЧЬ" if st.night >= FNData.NIGHTS.size() else "НОЧЬ %d" % (st.night + 1)
	night_l.text = night_name
	time_l.text = st.clock()
	var p_txt := "ЭНЕРГИЯ %d %%" % ceili(st.power)
	var p_col := RED if st.power < 15.0 else DIM
	power_l.text = p_txt
	power_l.add_theme_color_override("font_color", p_col)
	var hide_usage := st.glitches.has("usage_hide")
	usage_row.visible = not hide_usage and not st.power_out
	for k in usage_bars.size():
		var b: ColorRect = usage_bars[k]
		b.color = (RED if k >= 3 else Color(0.85, 0.82, 0.75)) if k < st.usage else Color(0.2, 0.2, 0.2, 0.7)
	var eta := st.time_left()
	@warning_ignore("integer_division")
	var e_txt := ("хватит на ~%d:%02d" % [int(eta) / 60, int(eta) % 60]) if not hide_usage and not st.power_out else ("нагрузка: нет данных" if hide_usage else "")
	eta_l.text = e_txt
	var show_eta := hide_usage or deck_pin
	if eta_l.visible != show_eta:
		eta_l.visible = show_eta
		_layout.call_deferred()
	_tablet_motion(st, dt)
	clock_box.visible = tablet_k < 0.75
	power_box.visible = tablet_k < 0.75 and not st.power_out
	_deck_tick(st)
	_toast_tick(st, dt)
	# ложная тревога MOD
	alarm_t = maxf(0.0, alarm_t - dt)
	alarm_l.visible = alarm_t > 0.0 and fposmod(t, 0.5) < 0.35
	msg_t = maxf(0.0, msg_t - dt)
	msg_l.modulate.a = clampf(msg_t, 0.0, 1.0)
	if tablet_face.is_visible_in_tree():
		if String(root.state) == "scare":
			cams.t += dt
			cams.mat.set_shader_parameter("t", cams.t)
		_tablet_telemetry(st, cams, night_name, hide_usage)

func msg(text: String, sec := 3.0) -> void:
	msg_l.text = text
	msg_t = sec

func alarm(text: String) -> void:
	alarm_l.text = text
	alarm_t = 3.5

## Реплика звонка и необязательная подсказка клавиши.
func sub(text: String, can_skip := false) -> void:
	sub_l.text = text
	sub_box.visible = text != ""
	sub_skip.visible = can_skip
	_layout.call_deferred()

## подсказки клавиш будки (первая ночь): "office" — показать, "" — убрать
func hints(kind: String) -> void:
	look_hint = kind != ""

func show_dark(on: bool, k := 0.0) -> void:
	if dark_box.visible != on:
		dark_box.visible = on
		_layout.call_deferred()
	MGUI.set_bar(dark_bar, k)

# ---------------- карточки: начало ночи, 6 AM, гибель ----------------
func clear_card() -> void:
	card_gen += 1
	for c in card.get_children():
		c.queue_free()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card.has_meta("audit_modal"):
		card.remove_meta("audit_modal")

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

## колонка по центру экрана (карточки собираются контейнером, а не координатами)
func _column(w: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cc)
	var v := MGUI.vbox(MGUI.S3)
	v.custom_minimum_size.x = w
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v

func _line(v: VBoxContainer, text: String, style: String, col: Color, wrap_n := true) -> Label:
	var l := MGUI.label(text, style, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap_n:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return l

func night_card(title: String, sub_t: String) -> void:
	clear_card()
	var g := card_gen
	var bg := _bg()
	var v := _column(minf(640.0, _vs().x - 2.0 * EDGE))
	_line(v, "12:00 AM", "caps_xl", Color(0.92, 0.9, 0.85), false)
	_line(v, title, "caps_h", RED)
	_line(v, sub_t, "mono", DIM)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(bg, "color:a", 0.0, 1.2)
	tw.parallel().tween_property(v, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func(): if g == card_gen: clear_card())

func six_card(pay: int, line: String, extra := "") -> void:
	clear_card()
	var g := card_gen
	_bg()
	hud.visible = false
	dark_box.visible = false
	card.set_meta("audit_modal", true)
	var s := _vs()
	var five := _center("5 AM", 96, Color(0.92, 0.9, 0.85), s.y * 0.26, big)
	var six := _center("6 AM", 96, Color(0.92, 0.9, 0.85), s.y * 0.26 + 120, big)
	five.set_meta("audit_skip", true)
	six.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(five, "position:y", s.y * 0.26 - 120, 1.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(five, "modulate:a", 0.0, 1.2)
	tw.parallel().tween_property(six, "position:y", s.y * 0.26, 1.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(six, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		if g != card_gen:
			return
		five.queue_free()
		# строки под часами: итог смены, зарплата, концовка — одной колонкой с переносом
		var v := MGUI.vbox(MGUI.S3)
		v.position = Vector2((s.x - minf(760.0, s.x - 2.0 * EDGE)) * 0.5, s.y * 0.26 + 150)
		v.custom_minimum_size.x = minf(760.0, s.x - 2.0 * EDGE)
		card.add_child(v)
		_line(v, line, "body_b", DIM)
		_line(v, "Уведомление банка: зачислена зарплата %s" % MGUI.rub(pay), "mono", Color(0.55, 0.85, 0.6))
		if extra != "":
			_line(v, extra, "mono", RED))

func dead_card(killer: String, hint: String, buttons: Array) -> void:
	clear_card()
	var g := card_gen
	var bg := _bg(0.0)
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.95, 0.4)
	tw.tween_callback(func():
		if g != card_gen:
			return
		hud.visible = false
		dark_box.visible = false
		var v := _column(minf(620.0, _vs().x - 2.0 * EDGE))
		card.set_meta("audit_modal", true)
		_line(v, "ПАХАН УМЕР", "caps_xl", RED, false)
		_line(v, killer, "caps_l", DIM)
		_line(v, hint, "mono", Color(0.7, 0.68, 0.62))
		var gap := Control.new()
		gap.custom_minimum_size.y = MGUI.S4
		v.add_child(gap)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var first: Button = null
		for it in buttons:
			var b := MGUI.button(String(it[0]))
			b.custom_minimum_size = Vector2(300, 0)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(it[1])
			v.add_child(b)
			if first == null:
				first = b
		var hh := MGUI.hints([["↑↓", "выбор"], ["Enter", "открыть"]])
		hh.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(hh)
		if first != null:
			first.grab_focus.call_deferred())

func show_pause(on: bool) -> void:
	pause_box.visible = on
	if on and not root.cams.capturing:
		root.cams.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if on and pause_first != null:
		pause_first.grab_focus.call_deferred()
