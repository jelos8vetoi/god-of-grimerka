## Меню «5 НОЧЕЙ С ПАХАНОМ» — старый терминал охранной системы. Фон — живая камера главного зала (на сцене
## стоят БАЛОН и остальные, иногда смотрят в камеру), шум, помехи, мигание, красные надписи. Разделы:
## НОВАЯ ИГРА, ПРОДОЛЖИТЬ, ВЫБОР НОЧИ, СВОЯ НОЧЬ, АРХИВ, НАСТРОЙКИ, В МЕНЮ РЕЖИМОВ. Клавиши: W/S или стрелки —
## выбор, Enter — открыть, A/D — значение, Esc — назад; мышь — наведение и клик. Закрытые ночи не запускаются.
class_name FNMenu
extends Control

const RED := Color(0.9, 0.08, 0.06)
const TXT := Color(0.78, 0.86, 0.76)
const DIMC := Color(0.42, 0.46, 0.42)

var root
var mono: Font
var big: Font
var bg: TextureRect
var title: Label
var subtitle: Label
var list_p: PanelContainer
var scroll: ScrollContainer
var box: VBoxContainer
var info_p: PanelContainer
var info: Label
var foot: HBoxContainer
var ver: Label
var rows: Array = []               # [{text: Callable|String, act: Callable, step: Callable, ok: bool}]
var sel := 0
var screen := "main"
var t := 0.0
var glitch_t := 0.0
var custom_preset := 0

const LEFT := 56.0
const TOP := 132.0
const LIST_W := 560.0

## Вёрстка — MGUI: заголовок, слева список на тёмной панели (чтобы текст не спорил с картинкой камеры), справа —
## панель пояснения выбранного пункта, внизу — плашки клавиш. Характер терминала: моноширинный текст, «>» у выбранного.
func setup(r) -> void:
	root = r
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mono = MGUI.font("mono")
	big = MGUI.font("caps")
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	title = MGUI.label("5 НОЧЕЙ С ПАХАНОМ", "caps_h", RED)
	title.position = Vector2(LEFT, 40)
	add_child(title)
	subtitle = MGUI.label("«ты просто хотел спокойно отработать смену»", "mono", TXT)
	subtitle.position = Vector2(LEFT + 2, 90)
	add_child(subtitle)
	list_p = MGUI.panel(false, null, MGUI.S3)
	list_p.position = Vector2(LEFT, TOP)
	list_p.custom_minimum_size = Vector2(LIST_W, 0)
	list_p.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(list_p)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme = MGUI.theme()
	list_p.add_child(scroll)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	info_p = MGUI.panel(true, RED, MGUI.S4)
	add_child(info_p)
	info = MGUI.label("", "mono", TXT, 300.0)
	info.add_theme_font_size_override("font_size", 15)
	info_p.add_child(info)
	foot = MGUI.hints([["W/S", "выбор"], ["Enter", "открыть"], ["A/D", "значение"], ["Esc", "назад"]])
	add_child(foot)
	ver = MGUI.label("ОХРАННАЯ СИСТЕМА «ОБЛАКО» v0.9", "mono_s", DIMC)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	get_viewport().size_changed.connect(_layout)
	_layout()
	open_main()

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var iw := clampf(s.x - LEFT * 2.0 - LIST_W - MGUI.S4, 300.0, 560.0)
	info_p.position = Vector2(LEFT + LIST_W + MGUI.S4, TOP)
	info_p.custom_minimum_size = Vector2(iw, 0)
	info.custom_minimum_size.x = iw - 2.0 * MGUI.S4 - 4.0
	info_p.reset_size()
	foot.position = Vector2(LEFT, s.y - 46)
	ver.position = Vector2(s.x - LEFT - 360, s.y - 42)
	ver.size = Vector2(360, 18)
	_fit_list()

## высота списка: по содержимому, но не ниже подсказок внизу (дальше — прокрутка)
func _fit_list() -> void:
	if scroll == null:
		return
	var s := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, s.y - TOP - 2.0 * MGUI.S3 - 62.0)
	list_p.reset_size()

# ---------------- экраны ----------------
func _show(nm: String, list: Array, start := 0) -> void:
	screen = nm
	rows = list
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for i in rows.size():
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.set_meta("audit_clip", true)             # длинное название — с многоточием, целиком показано в пояснении справа
		b.add_theme_font_override("font", mono)
		b.add_theme_font_size_override("font_size", MGUI.BODY + 2)
		b.custom_minimum_size = Vector2(LIST_W - 2.0 * MGUI.S3 - 10.0, 30)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var k := i
		b.mouse_entered.connect(func(): select(k, false))
		b.pressed.connect(func(): _click(k))
		box.add_child(b)
	sel = clampi(start, 0, rows.size() - 1)
	_fit_list()
	_paint()

func _paint() -> void:
	for i in rows.size():
		var b: Button = box.get_child(i) as Button
		if b == null:
			continue
		var r: Dictionary = rows[i]
		var tx = r["text"]
		var s: String = String(tx.call()) if tx is Callable else String(tx)
		var on := i == sel
		b.text = ("> " if on else "  ") + s
		var ok: bool = r.get("ok", true)
		var col := (RED if on else TXT) if ok else DIMC
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, col)
		if on:
			_see.call_deferred(b)
	var r2: Dictionary = rows[sel] if sel < rows.size() else {}
	var inf = r2.get("info", "")
	var it: String = String(inf.call()) if inf is Callable else String(inf)
	var sb: Button = box.get_child(sel) as Button if sel < box.get_child_count() else null
	if sb != null and mono.get_string_size(sb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, MGUI.BODY + 2).x > sb.custom_minimum_size.x - 8.0:
		it = sb.text.substr(2) + ("\n\n" + it if it != "" else "")
	info.text = MGUI.nb(it)
	info_p.visible = info.text != ""
	info_p.reset_size()

func _see(b) -> void:
	if is_instance_valid(b) and scroll.is_ancestor_of(b):
		scroll.ensure_control_visible(b)

func _click(k: int) -> void:
	select(k, false)
	activate(1)

func select(i: int, sound := true) -> void:
	if rows.is_empty():
		return
	i = posmod(i, rows.size())
	if i != sel and sound:
		root.sfx2("click", -10.0)
	sel = i
	_paint()

func activate(d: int) -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	if d != 1 and r.has("step"):
		(r["step"] as Callable).call(d)
		root.sfx2("click", -8.0)
		_paint()
		return
	if d == 1 and r.has("act"):
		if not r.get("ok", true):
			root.sfx2("ping", -10.0)
			return
		root.sfx2("cam", -6.0)
		(r["act"] as Callable).call()
	elif r.has("step"):
		(r["step"] as Callable).call(1)
		_paint()

func back() -> void:
	if screen == "main":
		root.quit_to_menu()
	else:
		open_main()

func open_main() -> void:
	var cur := int(FNSave.v("current"))
	var any := (FNSave.v("beaten") as Array).size() > 0 or cur > 0
	_show("main", [
		{"text": "НОВАЯ ИГРА", "act": func(): root.start_night(0), "info": "Первая ночь с начала. Прогресс ночей сохранится — открытые ночи не закроются."},
		{"text": func(): return "ПРОДОЛЖИТЬ — НОЧЬ %d" % (cur + 1), "act": func(): root.start_night(cur), "ok": any, "info": "Продолжить с той ночи, на которой остановился."},
		{"text": "ВЫБОР НОЧИ", "act": open_nights, "info": "Пройденные ночи можно переиграть. Закрытые — нет."},
		{"text": "СВОЯ НОЧЬ", "act": open_custom, "ok": bool(FNSave.v("custom")), "info": func(): return "Свои уровни каждому врагу, 0–20." if bool(FNSave.v("custom")) else "Откроется после шестой ночи."},
		{"text": "АРХИВ", "act": open_extras, "info": "Записи, досье, концовки, статистика."},
		{"text": "НАСТРОЙКИ", "act": open_settings, "info": "Громкость и сила экранных эффектов."},
		{"text": "В МЕНЮ РЕЖИМОВ", "act": func(): root.quit_to_menu(), "info": "Вернуться к выбору режима GOD OF GRIMERKA."},
	], 1 if any else 0)

func open_nights() -> void:
	var list: Array = []
	var un := int(FNSave.v("unlocked"))
	var beaten: Array = FNSave.v("beaten")
	for n in 5:
		var k := n
		var state := "ПРОЙДЕНА" if beaten.has(n) else ("ОТКРЫТА" if n < un else "ЗАКРЫТА")
		list.append({"text": "НОЧЬ %d · %s · %s" % [n + 1, FNData.NIGHTS[n]["title"], state], "act": func(): root.start_night(k), "ok": n < un,
			"info": "Враги: " + ", ".join(FNData.ORDER.filter(func(e): return FNData.level(k, e, 5) > 0).map(func(e): return FNData.ENEMIES[e]["name"]))})
	if bool(FNSave.v("night6")):
		list.append({"text": "НОЧЬ 6 · НЕ ДОЛЖЕН БЫЛ ВЫЖИТЬ" + (" · ПРОЙДЕНА" if beaten.has(5) else ""), "act": func(): root.start_night(5), "info": "Все враги злее. Скрытые события. Другая концовка."})
	list.append({"text": "НАЗАД", "act": open_main})
	_show("nights", list, clampi(int(FNSave.v("current")), 0, list.size() - 1))

func open_custom() -> void:
	var lv: Dictionary = FNSave.v("levels")
	var list: Array = []
	for id in FNData.ORDER:
		var e: String = id
		list.append({"text": func(): return "%-14s %2d  %s" % [FNData.ENEMIES[e]["name"], int(lv[e]), "█".repeat(int(lv[e])) + "░".repeat(20 - int(lv[e]))],
			"step": func(d: int): lv[e] = clampi(int(lv[e]) + d, 0, 20),
			"info": String(FNData.ENEMIES[e]["about"]) + "\n\n" + String(FNData.ENEMIES[e]["counter"])})
	list.append({"text": func(): return "НАБОР: " + String(_preset_names()[custom_preset % _preset_names().size()]), "step": func(d: int): _preset_step(d, lv),
		"info": "Готовые и свои наборы уровней — клавишами A и D."})
	list.append({"text": "СОХРАНИТЬ НАБОР", "act": func(): _save_preset(lv), "info": "Запомнить текущие уровни как свой набор."})
	list.append({"text": "НАЧАТЬ", "act": func(): _custom_start(lv), "info": func(): return "Сумма уровней: %d / 120" % _sum(lv)})
	list.append({"text": "НАЗАД", "act": func(): _custom_back(lv)})
	_show("custom", list)

func _sum(lv: Dictionary) -> int:
	var n := 0
	for k in lv:
		n += int(lv[k])
	return n

func _preset_step(d: int, lv: Dictionary) -> void:
	custom_preset = posmod(custom_preset + d, _preset_names().size())
	var nm: String = _preset_names()[custom_preset]
	var src: Dictionary = FNData.PRESETS.get(nm, (FNSave.v("presets") as Dictionary).get(nm, {}))
	for k in src:
		lv[k] = int(src[k])

func _save_preset(lv: Dictionary) -> void:
	var pr: Dictionary = FNSave.v("presets")
	var nm2 := "СВОЙ %d" % (pr.size() + 1)
	pr[nm2] = lv.duplicate()
	FNSave.put("presets", pr)
	custom_preset = _preset_names().find(nm2)
	_paint()

func _custom_start(lv: Dictionary) -> void:
	FNSave.put("levels", lv)
	root.start_night(6, lv.duplicate())

func _custom_back(lv: Dictionary) -> void:
	FNSave.put("levels", lv)
	open_main()

func _preset_names() -> Array:
	return FNData.PRESETS.keys() + (FNSave.v("presets") as Dictionary).keys()

func open_extras() -> void:
	_show("extras", [
		{"text": "ЗАПИСИ", "act": open_notes, "info": "Документы, найденные на сменах."},
		{"text": "ДОСЬЕ НА ОБИТАТЕЛЕЙ", "act": open_bios, "info": "Кто есть кто и как от них защищаться."},
		{"text": "КОНЦОВКИ", "act": open_endings, "info": "Открытые концовки."},
		{"text": "СТАТИСТИКА", "act": open_stats, "info": "Сколько раз и от кого."},
		{"text": "НАЗАД", "act": open_main},
	])

func open_notes() -> void:
	var list: Array = []
	for id in FNData.NOTES:
		var have := (FNSave.v("notes") as Array).has(id) or (FNSave.v("secrets") as Array).has(id)
		list.append({"text": String(FNData.NOTES[id][0]) if have else "??? (не найдено)", "act": func(): pass, "ok": have,
			"info": String(FNData.NOTES[id][1]) if have else "Ищи на камерах и в будке."})
	list.append({"text": "НАЗАД", "act": open_extras})
	_show("notes", list)

func open_bios() -> void:
	var list: Array = []
	var met := int(FNSave.v("unlocked")) + (1 if bool(FNSave.v("night6")) else 0)
	for id in FNData.ORDER:
		var first := 0
		for n in 5:
			if FNData.level(n, id, 5) > 0:
				first = n
				break
		var seen := first < met
		list.append({"text": String(FNData.ENEMIES[id]["name"]) if seen else "???", "act": func(): pass, "ok": seen,
			"info": (String(FNData.ENEMIES[id]["about"]) + "\n\nКАК ЗАЩИТИТЬСЯ: " + String(FNData.ENEMIES[id]["counter"])) if seen else "Ещё не встречался."})
	list.append({"text": "НАЗАД", "act": open_extras})
	_show("bios", list)

func open_endings() -> void:
	var list: Array = []
	for id in FNData.ENDINGS:
		var have := (FNSave.v("endings") as Array).has(id)
		list.append({"text": String(FNData.ENDINGS[id][0]) if have else "???", "act": func(): pass, "ok": have, "info": String(FNData.ENDINGS[id][1]) if have else ""})
	list.append({"text": "НАЗАД", "act": open_extras})
	_show("endings", list)

func open_stats() -> void:
	var s: Dictionary = FNSave.v("stats")
	var deaths: Dictionary = s["deaths"]
	var lines := "Смен отработано: %d\nНочей пережито: %d\n\nСМЕРТИ:\n" % [int(s["played"]), int(s["wins"])]
	for id in FNData.ORDER:
		lines += "  %-14s %d\n" % [FNData.ENEMIES[id]["name"], int(deaths.get(id, 0))]
	_show("stats", [{"text": "НАЗАД", "act": open_extras, "info": lines}])

## громкость: ноль — «ВЫКЛ»
func _vol_text(x: float) -> String:
	return "ВЫКЛ" if roundi(x * 100.0) <= 0 else "%d %%" % roundi(x * 100.0)

func open_settings() -> void:
	var a = root.main.audio if root.main != null else null
	var list: Array = []
	list.append({"text": func(): return "Расширенные подсказки управления  ·  " + ("ВКЛ" if FNUI.extended_hints_enabled() else "ВЫКЛ"),
		"step": func(_d: int): root.ui.toggle_deck_pin(),
		"info": "Показывает пульт с клавишами и состоянием устройств. Во время смены переключается клавишей F1."})
	list.append({"text": func(): return "ОБЩАЯ ГРОМКОСТЬ: " + _vol_text(float(Opts.v("master"))), "step": func(d: int): Opts.put("master", clampf(snappedf(float(Opts.v("master")) + 0.05 * d, 0.05), 0.0, 1.0))})
	if a != null:
		for b in [["Music", "МУЗЫКА"], ["Ambient", "ОКРУЖЕНИЕ"], ["SFX", "ЭФФЕКТЫ"], ["Voice", "ГОЛОСА"]]:
			var bus: String = b[0]
			var nm: String = b[1]
			list.append({"text": func(): return "%s: %s" % [nm, _vol_text(float(a.vol[bus]))], "step": func(d: int): a.set_volume(bus, clampf(snappedf(float(a.vol[bus]) + 0.05 * d, 0.05), 0.0, 1.0))})
	list.append({"text": func(): return "ГРОМКОСТЬ СКРИМЕРОВ: %d %%" % roundi(float((FNSave.v("settings") as Dictionary).get("scream", 1.0)) * 100.0), "step": func(d: int):
		var ss: Dictionary = FNSave.v("settings")
		ss["scream"] = clampf(snappedf(float(ss.get("scream", 1.0)) + 0.1 * d, 0.1), 0.2, 1.0)
		FNSave.put("settings", ss), "info": "Отдельно от общей громкости: насколько громко кричат при скримере. Меньше 20 % не бывает — иначе это не скример."})
	list.append({"text": func(): return "ЭКРАННЫЕ ЭФФЕКТЫ: %d %%" % roundi(float(FNSave.v("settings")["fx"]) * 100.0), "step": func(d: int): _fx_step(d),
		"info": "Шум, полосы, искажения и полутон. 0 % — чистая картинка (для чувствительных к вспышкам)."})
	list.append({"text": "НАЗАД", "act": open_main})
	_show("settings", list)

func _fx_step(d: int) -> void:
	var st: Dictionary = FNSave.v("settings")
	st["fx"] = clampf(snappedf(float(st["fx"]) + 0.25 * d, 0.25), 0.0, 1.0)
	FNSave.put("settings", st)
	root.apply_fx()

# ---------------- ввод и жизнь фона ----------------
func key(k: int) -> void:
	match k:
		KEY_W, KEY_UP:
			select(sel - 1)
		KEY_S, KEY_DOWN:
			select(sel + 1)
		KEY_A, KEY_LEFT:
			activate(-1)
		KEY_D, KEY_RIGHT:
			if rows[sel].has("step"):
				activate(2)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			activate(1)
		KEY_ESCAPE, KEY_BACKSPACE:
			root.sfx2("click", -8.0)
			back()

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	glitch_t -= dt
	if glitch_t < -randf_range(4.0, 11.0):
		glitch_t = randf_range(0.06, 0.18)
	var g := glitch_t > 0.0
	title.position.x = LEFT + (randf_range(-6, 6) if g else 0.0)
	title.modulate.a = 0.6 if g and randf() < 0.5 else 1.0
	subtitle.modulate.a = 0.85 + 0.15 * sin(t * 3.0)
