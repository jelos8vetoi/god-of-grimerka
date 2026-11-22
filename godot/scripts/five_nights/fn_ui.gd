## Интерфейс ночи «5 НОЧЕЙ С ПАХАНОМ» — минимальный, чтобы не ломать атмосферу: время и ночь, энергия с расходом
## и прогнозом, планшет камер, субтитры звонка и реплик, ложные тревоги MOD, экран 6 AM, экран гибели,
## «последний шанс» с генератором, пауза. Под интерфейсом — экранный шейдер в духе GOD OF GRIMERKA: монохром
## с сохранённым красным, полутон в тенях, зерно, виньетка (сила — настройка).
## Вёрстка — на дизайн-системе MGUI (mg_ui.gd), характер — старый охранный пульт: моноширинный текст, Russo One
## только в часах и коротких заголовках. В будке на экране — часы (справа сверху), энергия (слева снизу) и на
## первой ночи — плашки клавиш (справа снизу). На планшете картинка камеры крупная и чистая: название камеры и
## метка времени — над ней, карта камер, состояние (пинг, приманка), клавиши и энергия — в боковой панели справа.
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
var hint_box: VBoxContainer
var tablet: Control
var tablet_k := 0.0
var feed: TextureRect
var cam_l: Label
var stamp_l: Label
var rec_dot: ColorRect
var jam_l: Label
var jam_sub: Label
var ping_l: Label
var lure_l: Label                  # приманка: подсказка в боковой панели планшета
var side: PanelContainer            # боковая панель планшета: карта, состояние, клавиши, энергия
var map_box: Control
var tab_power: Label
var tab_eta: Label
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
	{"id": "seal_t", "key": "X", "name": "ЛЮК СВЕРХУ", "tip": "Заслонка верхней шахты над столом: от тех, кто лезет сверху. Пока закрыта — тратит энергию."},
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
## Пульт — учебная помощь: виден первые DECK_LEARN секунд первой ночи нового сохранения, потом скрыт; F1 закрепляет его
## (deck_pin, настройка «deck» в сохранении). Без пульта действия устройств коротко подписывает toast.
const DECK_LEARN := 75.0
const TOAST_LEN := 1.6
const HINT_LEN := 6.0
var deck_pin := false
var deck_learn_left := 0.0
var deck_shown := false
var hint_left := 0.0
var toast_l: Label
var toast_t := 0.0
var look_hint := false              # первая ночь: подсказка «как осмотреться»
var cam_rows := {}                  # id камеры → строка в списке комнат планшета
var act_lure: Dictionary = {}
var act_fix: Dictionary = {}

const SIDE_W := 268.0
const EDGE := 24.0
const MAP_SIZE := Vector2(236, 176)
const CAM_BTN := Vector2(40, 24)

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
	tips.hold_fn = func(): return root == null or root.state != "night" or (root.scare != null and root.scare.busy) or root.intro_t > 0.0
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
	# звонок: узкая плашка снизу по центру — значок, реплика, «F — сбросить»
	sub_box = MGUI.panel(true, null, MGUI.S3)
	sub_box.visible = false
	hud.add_child(sub_box)
	var sh2 := MGUI.hbox(MGUI.S3)
	sub_box.add_child(sh2)
	var sic := MGIcon.make("call", 18, MGUI.TEXT_2)
	sic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sh2.add_child(sic)
	sub_l = MGUI.label("", "mono", Color(0.92, 0.9, 0.84), 560.0)
	sh2.add_child(sub_l)
	sub_skip = MGUI.hints([["F", "сбросить"]])
	sub_skip.size_flags_vertical = Control.SIZE_SHRINK_END
	sh2.add_child(sub_skip)
	# без пульта на экране первые секунды ночи напоминаем, как его вернуть и где справка
	hint_box = MGUI.vbox(MGUI.S1)
	hint_box.visible = false
	hint_box.modulate.a = 0.55
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint_box)
	var hr := MGUI.hints([["F1", "пульт"], ["H", "справка"]])
	hr.alignment = BoxContainer.ALIGNMENT_END
	hint_box.add_child(hr)
	_deck()
	deck_pin = bool((FNSave.v("settings") as Dictionary).get("deck", false))
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
	tip_box = MGUI.panel(true, null, MGUI.S3)
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box.visible = false
	hud.add_child(tip_box)
	tip_l = MGUI.label("", "small", MGUI.TEXT, 520.0)
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
	var show: bool = tablet_k < 0.5 and not st.power_out and (card == null or card.get_child_count() == 0) and not pause_box.visible and String(root.state) == "night"
	show = show and (deck_pin or deck_learn_left > 0.0)
	deck.visible = show
	if show != deck_shown:
		deck_shown = show
		_layout.call_deferred()
	var hover := tip_id if tip_id != "" else tip_3d
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
	var tip := dev_tip(st, hover) if show and hover != "" else ""
	if tip == "" and show and look_hint:
		tip = "Осмотреться — мышь к краю экрана или стрелки ← →. Пульт внизу: клавиша, устройство, состояние."
	if tip_l.text != tip:
		tip_l.text = tip
		tip_box.visible = tip != ""
		_layout.call_deferred()
	elif tip == "" and tip_box.visible:
		tip_box.visible = false

## начало ночи: на первой ночи нового сохранения пульт виден, в остальные — только если закреплён (F1)
func night_begin(n: int, first_time: bool) -> void:
	deck_learn_left = DECK_LEARN if n == 0 and first_time else 0.0
	hint_left = 0.0 if deck_pin or deck_learn_left > 0.0 else HINT_LEN
	toast_t = 0.0
	toast_l.visible = false

## F1: закрепить пульт или убрать
func toggle_deck_pin() -> void:
	deck_pin = not deck_pin
	deck_learn_left = 0.0
	hint_left = 0.0
	var cfg: Dictionary = FNSave.v("settings")
	cfg["deck"] = deck_pin
	FNSave.save()

## без пульта: «<устройство> — <состояние>» внизу по центру на TOAST_LEN секунд
func toast(id: String) -> void:
	if deck_shown or tablet_k > 0.5 or root.st == null or root.st.power_out or not deck_rows.has(id):
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
	toast_l.visible = toast_t > 0.0 and not deck_shown and tablet_k < 0.5 and not st.power_out

## надпись поверх сцены: тёмная обводка, чтобы читалась на любом фоне
func _out(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _label(parent: Control, text: String, size: int, col: Color, font: Font) -> Label:
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
		tip_box.reset_size()
		var ts := tip_box.get_combined_minimum_size()
		tip_box.position = Vector2((s.x - ts.x) * 0.5, deck_top - ts.y - 8.0)
	power_box.reset_size()
	power_box.position = Vector2(EDGE, deck_top - 10.0 - maxf(64.0, power_box.get_combined_minimum_size().y))
	alarm_l.position = Vector2(s.x * 0.2, EDGE)
	alarm_l.size = Vector2(s.x * 0.6, 30)
	msg_l.position = Vector2(s.x * 0.25, s.y * 0.64)
	msg_l.size = Vector2(s.x * 0.5, 50)
	sub_box.reset_size()
	# звонок — над плашкой генератора, если она на экране (обе живут снизу по центру)
	var lift := 110.0 if dark_box != null and dark_box.visible else 0.0
	var tip_h: float = (tip_box.get_combined_minimum_size().y + 8.0) if tip_box != null and tip_box.visible else 0.0
	sub_box.position = Vector2((s.x - sub_box.get_combined_minimum_size().x) * 0.5, s.y - EDGE - sub_box.get_combined_minimum_size().y - (70 if deck_shown or lift > 0.0 else 10) - lift - tip_h)
	toast_l.reset_size()
	toast_l.position = Vector2((s.x - toast_l.get_combined_minimum_size().x) * 0.5, s.y - 12.0 - 34.0)
	hint_box.reset_size()
	hint_box.position = Vector2(s.x - EDGE - hint_box.get_combined_minimum_size().x, s.y - EDGE - hint_box.get_combined_minimum_size().y)
	if tablet != null:
		tablet.size = s
		# картинка камеры: всё место слева от боковой панели, 16:9, по центру высоты
		var aw := s.x - 2.0 * EDGE - SIDE_W - MGUI.S4
		var ah := s.y - 2.0 * EDGE - 34.0
		var fw := minf(aw, ah * 16.0 / 9.0)
		var fh := fw * 9.0 / 16.0
		feed.size = Vector2(fw, fh)
		feed.position = Vector2(EDGE + (aw - fw) * 0.5, EDGE + 34.0 + (ah - fh) * 0.5)
		cam_l.position = feed.position + Vector2(0, -28)
		cam_l.size = Vector2(fw * 0.6, 22)
		stamp_l.position = feed.position + Vector2(fw - 300 - 18, -26)
		stamp_l.size = Vector2(300, 20)
		rec_dot.position = feed.position + Vector2(fw - 10, -20)
		jam_l.position = feed.position + Vector2(0, fh * 0.44)
		jam_l.size = Vector2(fw, 30)
		jam_sub.position = jam_l.position + Vector2(0, 34)
		jam_sub.size = Vector2(fw, 22)
		side.position = Vector2(feed.position.x + fw + MGUI.S4, feed.position.y)
		side.size = Vector2(SIDE_W, fh)
		side.custom_minimum_size = Vector2(SIDE_W, fh)
	if dark_box != null:
		dark_box.reset_size()
		dark_box.position = Vector2((s.x - dark_box.get_combined_minimum_size().x) * 0.5, s.y - 190)
		pause_box.size = s

# ---------------- планшет камер ----------------
func _tablet() -> void:
	tablet = Control.new()
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.visible = false
	add_child(tablet)
	var bezel := ColorRect.new()
	bezel.color = Color(0.015, 0.015, 0.018)
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(bezel)
	feed = TextureRect.new()
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.stretch_mode = TextureRect.STRETCH_SCALE
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(feed)
	cam_l = MGUI.label("", "mono_m", RED)
	cam_l.clip_text = true
	tablet.add_child(cam_l)
	stamp_l = MGUI.label("", "mono", MGUI.TEXT_2)
	stamp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tablet.add_child(stamp_l)
	rec_dot = ColorRect.new()
	rec_dot.size = Vector2(10, 10)
	rec_dot.color = RED
	rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(rec_dot)
	# «нет сигнала» — по центру картинки: в этот момент картинки всё равно нет
	jam_l = _out(MGUI.label("", "caps_l", Color(0.9, 0.9, 0.9)))
	jam_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tablet.add_child(jam_l)
	jam_sub = _out(MGUI.label("", "mono", MGUI.TEXT_2))
	jam_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tablet.add_child(jam_sub)
	# боковая панель
	side = MGUI.panel(false, null, MGUI.S4)
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	tablet.add_child(side)
	var v := MGUI.vbox(MGUI.S3)
	side.add_child(v)
	v.add_child(MGUI.label("КАМЕРЫ", "caps"))
	map_box = Control.new()
	map_box.custom_minimum_size = MAP_SIZE
	map_box.mouse_filter = Control.MOUSE_FILTER_PASS
	map_box.draw.connect(_map_draw)
	v.add_child(map_box)
	for c in FNData.CAMS:
		var b := _cam_btn(String(c["no"]), String(c["id"]))
		b.position = (c["map"] as Vector2) * (MAP_SIZE - CAM_BTN)
		map_btns[c["id"]] = b
	cam9_btn = _cam_btn("9", "room9")
	cam9_btn.position = (FNData.CAM9["map"] as Vector2) * (MAP_SIZE - CAM_BTN)
	cam9_btn.visible = false
	# список комнат: номер — это клавиша; выбранная подсвечена, сломанная — серая
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(grid)
	for c in FNData.CAMS:
		var rl := MGUI.label("%s %s" % [c["no"], String(c["short"]) if c.has("short") else String(c["name"])], "mono_s", MGUI.TEXT_2)
		rl.custom_minimum_size.x = (SIDE_W - 2.0 * MGUI.S4 - 8.0) * 0.5
		rl.clip_text = true
		rl.set_meta("audit_clip", true)
		grid.add_child(rl)
		cam_rows[c["id"]] = rl
		(map_btns[c["id"]] as Button).tooltip_text = "КАМЕРА 0%s — %s" % [c["no"], c["name"]]
	v.add_child(MGUI.hsep())
	ping_l = MGUI.label("", "mono", RED, SIDE_W - 2.0 * MGUI.S4)
	v.add_child(ping_l)
	lure_l = MGUI.label("", "mono", MGUI.TEXT_2, SIDE_W - 2.0 * MGUI.S4)
	lure_l.visible = false                     # прежняя строка приманки: её читают проверки, на экране — плашка ниже
	v.add_child(lure_l)
	# действия планшета — плашками: клавиша, название, состояние (как на пульте будки)
	act_lure = _act(v, "L", "ПРИМАНКА")
	act_fix = _act(v, "C", "ПЕРЕЗАПУСК КАМЕРЫ")
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	for row in [[["1–8", "выбрать камеру"]], [["Пробел", "закрыть планшет"]]]:
		v.add_child(MGUI.hints(row))
	v.add_child(MGUI.hsep())
	tab_power = MGUI.label("", "mono_m", DIM)
	v.add_child(tab_power)
	tab_eta = MGUI.label("", "mono_s", MGUI.TEXT_2)
	v.add_child(tab_eta)

## плашка действия в боковой панели планшета: клавиша + название, ниже — состояние одной строкой
func _act(parent: Control, key: String, title: String) -> Dictionary:
	var p := PanelContainer.new()
	var sb := MGUI.box(Color(0.07, 0.07, 0.08), 3, 1, Color(0.3, 0.3, 0.33), 8)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := MGUI.vbox(2)
	p.add_child(v)
	var top := MGUI.hbox(6)
	v.add_child(top)
	top.add_child(MGUI.keycap(key))
	var nm := MGUI.label(title, "caps", MGUI.TEXT)
	top.add_child(nm)
	var stl := MGUI.label("", "mono_s", MGUI.TEXT_2, SIDE_W - 2.0 * MGUI.S4 - 18.0)
	v.add_child(stl)
	return {"panel": p, "sb": sb, "name": nm, "state": stl}

func _act_set(a: Dictionary, text: String, col: Color, on: bool, dis: bool) -> void:
	(a["state"] as Label).text = text
	(a["state"] as Label).add_theme_color_override("font_color", col)
	(a["sb"] as StyleBoxFlat).border_color = col if on else Color(0.3, 0.3, 0.33)
	(a["name"] as Label).add_theme_color_override("font_color", MGUI.TEXT_3 if dis else MGUI.TEXT)
	(a["panel"] as Control).modulate.a = 0.6 if dis else 1.0

## план здания под кнопками камер: тонкие линии от комнат к будке
func _map_draw() -> void:
	var c := map_box
	var k := MAP_SIZE - CAM_BTN
	var half := CAM_BTN * 0.5
	var office := Vector2(0.5, 1.0) * k + Vector2(half.x, CAM_BTN.y)
	var col := Color(1, 1, 1, 0.14)
	var by := {}
	for cm in FNData.CAMS:
		by[cm["id"]] = (cm["map"] as Vector2) * k + half
	for pr in [["storage", "arcade"], ["stage", "arcade"], ["arcade", "hall_l"], ["stage", "vent"], ["stage", "server"], ["server", "power"], ["power", "hall_r"]]:
		c.draw_line(by[pr[0]], by[pr[1]], col, 1.0, true)
	for id in ["hall_l", "hall_r", "vent"]:
		c.draw_line(by[id], office, col, 1.0, true)

func _cam_btn(no: String, id: String) -> Button:
	var b := Button.new()
	b.text = no
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", mono)
	b.add_theme_font_size_override("font_size", MGUI.SMALL)
	b.custom_minimum_size = CAM_BTN
	b.size = CAM_BTN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := MGUI.box(Color(0.1, 0.1, 0.11), 2, 1, Color(0.5, 0.5, 0.48), 0)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.35, 0.05, 0.04)
	sh.border_color = RED
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.pressed.connect(func(): root.pick_cam(id))
	map_box.add_child(b)
	return b

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
	post_mat.set_shader_parameter("booth", 1.0 if root.state == "night" and not st.monitor else 0.0)
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
	var e_txt := ("хватит на ~%d:%02d" % [int(eta) / 60, int(eta) % 60]) if not hide_usage and not st.power_out else ("нагрузка: нет данных" if hide_usage else "")
	eta_l.text = e_txt
	power_box.visible = not st.power_out
	# планшет поднят — часы и энергия будки не нужны (на планшете свои), клавиши будки тоже
	clock_box.visible = tablet_k < 0.5
	if String(root.state) == "night" and not root.paused and root.intro_t <= 0.0:
		deck_learn_left = maxf(0.0, deck_learn_left - dt)
		hint_left = maxf(0.0, hint_left - dt)
	hint_box.visible = hint_left > 0.0 and not deck_shown and String(root.state) == "night"
	_deck_tick(st)
	_toast_tick(st, dt)
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
		var label: String = FNData.CAM9["name"] if st.cam == "room9" else st.cam_label(maxi(i, 0))
		var no := "9" if st.cam == "room9" else str(maxi(i, 0) + 1)
		cam_l.text = "CAM %s · %s" % [no, label]
		stamp_l.text = "%s · %s · REC" % [night_name, st.clock()]
		rec_dot.visible = fposmod(t, 1.0) < 0.6
		jam_sub.text = ""
		if st.brown_t > 0.0:
			jam_l.text = "ПЕРЕБОЙ ПИТАНИЯ"
		elif st.cam_broken(st.cam):
			jam_l.text = "КАМЕРА НЕ ОТВЕЧАЕТ"
			jam_sub.text = "держи C — перезапуск %d %%" % int(st.fix_t / FNNight.FIX_NEED * 100.0)
		else:
			jam_l.text = "НЕТ СИГНАЛА" if st.cams_dead() else ("ПОМЕХИ" if st.jammed(st.cam) else "")
		if st.monitor and st.cam in FNNight.LURE_ROOMS and st.brown_t <= 0.0:
			lure_l.text = "Приманка: в этой комнате есть игрушка — L" if st.lure_cd <= 0.0 else "Приманка: ещё %d с" % ceili(st.lure_cd)
			if st.lure_cd <= 0.0:
				_act_set(act_lure, "ВКЛЮЧИТЬ: игрушка зашумит и уведёт врага сюда · −1,5 % энергии", MGUI.GOLD, true, false)
			else:
				_act_set(act_lure, "ЗАРЯЖАЕТСЯ: ещё %d с" % ceili(st.lure_cd), MGUI.WARN, false, true)
		else:
			lure_l.text = "Приманка: в этой комнате нет игрушки"
			_act_set(act_lure, "НЕДОСТУПНО: в этой комнате нет игрушки" if st.brown_t <= 0.0 else "НЕДОСТУПНО: перебой питания", MGUI.TEXT_3, false, true)
		if st.cam_broken(st.cam):
			_act_set(act_fix, "ДЕРЖАТЬ C: перезапуск %d %%" % int(st.fix_t / FNNight.FIX_NEED * 100.0), RED, true, false)
		else:
			_act_set(act_fix, "НЕ НУЖЕН: камера отвечает", MGUI.TEXT_3, false, true)
		var bot: FNBot = st.enemies["bot"]
		if bot.ping_left > 0.0 and not st.glitches.has("leds_off"):
			ping_l.text = "Сервер: пинг — %s · %d с" % ["принимаю…" if st.cam == "server" else "открой CAM 6", ceili(bot.ping_left)]
		else:
			ping_l.text = ""
		ping_l.visible = ping_l.text != ""
		tab_power.text = p_txt if not st.power_out else "ЭНЕРГИИ НЕТ"
		tab_power.add_theme_color_override("font_color", p_col)
		tab_eta.text = e_txt
		# панель не растёт от смены текста: размер каждый кадр — по картинке камеры
		side.size = Vector2(SIDE_W, feed.size.y)
		for id in map_btns:
			var b2: Button = map_btns[id]
			b2.modulate = Color(1.0, 0.4, 0.35) if id == st.cam else (Color(0.55, 0.55, 0.55) if st.cam_broken(String(id)) else Color(1, 1, 1))
			var rl2: Label = cam_rows[id]
			rl2.add_theme_color_override("font_color", RED if id == st.cam else (MGUI.TEXT_3 if st.cam_broken(String(id)) else (MGUI.TEXT if b2.is_hovered() else MGUI.TEXT_2)))
		cam9_btn.modulate = Color(1.0, 0.4, 0.35) if st.cam == "room9" else Color(1, 1, 1)

func msg(text: String, sec := 3.0) -> void:
	msg_l.text = text
	msg_t = sec

func alarm(text: String) -> void:
	alarm_l.text = text
	alarm_t = 3.5

## реплика звонка: плашка снизу по центру; can_skip — показать «F — сбросить»
func sub(text: String, can_skip := false) -> void:
	sub_l.text = text
	sub_box.visible = text != ""
	sub_skip.visible = can_skip
	_layout.call_deferred()

## подсказки клавиш будки (первая ночь): "office" — показать, "" — убрать
func hints(kind: String) -> void:
	look_hint = kind != ""                 # клавиши теперь всегда на пульте; на первой ночи добавляется «как осмотреться»

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

func _line(v: VBoxContainer, text: String, style: String, col: Color, wrap := true) -> Label:
	var l := MGUI.label(text, style, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
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
	if on and pause_first != null:
		pause_first.grab_focus.call_deferred()
