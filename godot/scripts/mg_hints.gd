## Подсказки и справочник мини-игр — одна система на все: «Микрозаймы» и пять подработок, «5 ночей», гонки.
##
## Подсказка — карточка сбоку экрана: всплывает, когда механика впервые пригодилась (tip(id) зовёт сама игра по
## своему событию), держится несколько секунд и гаснет. Игру не останавливает, мышь и клавиши не перехватывает
## (mouse_filter IGNORE), за раз — одна, остальные ждут в очереди. Увиденная подсказка больше не всплывает (файл
## user://grimerka_hints.json; в проверках не пишется — main.user_play()).
## Справочник — клавиша H: сбоку выезжает список «что что делает» по текущей игре (все записи её набора), H или Esc —
## убрать. Shift+H — выключить или включить всплывающие подсказки (справочник работает всегда).
## Тексты — mg_hints_data.gd (MGHintsData): запись {t: заголовок, x: текст, k: [[клавиша, что делает], …]};
## в клавишах и тексте {действие} заменяется на клавишу из InputMap (переназначение в гонках учитывается).
class_name MGHints
extends Control

const FILE := "user://grimerka_hints.json"
const W := 330.0
const MARGIN := 18.0
const SHOW_SEC := 7.0

var gid := ""
var data: Dictionary = {}
var side := "left"                  # "left" / "right"
var vpos := 0.5                     # центр карточки по высоте (доля экрана)
var queue: Array = []
var cur := ""
var t_left := 0.0
var card: PanelContainer
var guide: PanelContainer
var held := false                   # игра попросила не показывать (открыт полноэкранный экран, скример)
var hold_fn := Callable()           # или спрашивать каждый кадр: true — молчать (пауза, итоги, скример)
var shown_log: Array = []           # что показано за этот запуск (для проверок)

static var _store := {}
static var _loaded := false

func setup(game_id: String, d: Dictionary, on_side := "left", v := 0.5) -> MGHints:
	gid = game_id
	data = d
	side = on_side
	vpos = v
	name = "MGHints_" + game_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load()
	return self

# ---------------- хранение ----------------
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			_store = d
	if not _store.has("seen"):
		_store["seen"] = {}

static func _persist() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var m = tree.root.get_node_or_null("Main") if tree != null else null
	return m != null and m.has_method("user_play") and m.user_play()

static func _save() -> void:
	if not _persist():
		return
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_store))

static func enabled() -> bool:
	_load()
	return not bool(_store.get("off", false))

static func set_enabled(on: bool) -> void:
	_load()
	_store["off"] = not on
	_save()

func seen(id: String) -> bool:
	return (_store["seen"].get(gid, []) as Array).has(id)

func _mark(id: String) -> void:
	var a: Array = _store["seen"].get(gid, [])
	if not a.has(id):
		a.append(id)
	_store["seen"][gid] = a
	_save()

# ---------------- подсказки ----------------
## показать подсказку id (один раз за всё время; force — показать снова)
func tip(id: String, force := false) -> void:
	if not data.has(id) or not enabled() or id == cur or queue.has(id):
		return
	if seen(id) and not force:
		return
	queue.append(id)

## не показывать подсказки, пока open == true (полноэкранный экран, скример, итоги)
func hold(on: bool) -> void:
	held = on
	if on and card != null:
		card.visible = false

func _process(dt: float) -> void:
	if hold_fn.is_valid():
		var h: bool = hold_fn.call()
		if h != held:
			hold(h)
			if guide != null and h:
				guide.queue_free()
				guide = null
				page = -1
	if guide != null and guide.visible:
		_place(guide)
		return
	if card != null and card.visible:
		t_left -= dt
		card.modulate.a = clampf(t_left / 0.6, 0.0, 1.0) * clampf((SHOW_SEC + _extra(cur) - t_left) / 0.25, 0.0, 1.0)
		_place(card)
		if t_left <= 0.0:
			card.visible = false
			cur = ""
		return
	if held or queue.is_empty():
		return
	_show(String(queue.pop_front()))

func _extra(id: String) -> float:
	return clampf(float(String(data.get(id, {}).get("x", "")).length()) / 40.0, 0.0, 6.0)

func _show(id: String) -> void:
	cur = id
	t_left = SHOW_SEC + _extra(id)
	_mark(id)
	shown_log.append(id)
	if card != null:
		card.queue_free()
	card = _card(data[id], "ПОДСКАЗКА", "H — справка по игре")
	add_child(card)
	card.modulate.a = 0.0
	_place(card)

func _card(e: Dictionary, caps: String, foot: String) -> PanelContainer:
	var p := MGUI.panel(true, MGUI.GOLD, MGUI.S3)
	p.custom_minimum_size = Vector2(W, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := MGUI.vbox(MGUI.S1)
	p.add_child(v)
	v.add_child(_skip(MGUI.label(caps, "caps", MGUI.GOLD)))
	v.add_child(_skip(MGUI.label(fill(String(e.get("t", ""))), "h2", MGUI.TEXT, W - 28.0)))
	if String(e.get("x", "")) != "":
		v.add_child(_skip(MGUI.label(fill(String(e["x"])), "small", MGUI.TEXT_2, W - 28.0)))
	var keys: Array = e.get("k", [])
	for pr in keys:
		var h := MGUI.hbox(MGUI.S2)
		h.add_child(MGUI.keycap(fill(String(pr[0]))))
		h.add_child(_skip(MGUI.label(fill(String(pr[1])), "small", MGUI.TEXT, W - 110.0)))
		v.add_child(h)
	if foot != "":
		v.add_child(_skip(MGUI.label(foot, "micro", MGUI.TEXT_3)))
	_skip_all(p)
	return p

## подписи карточки — временные, поверх игры: аудит вёрстки их не считает (метка audit_skip)
func _skip(l: Label) -> Label:
	l.set_meta("audit_skip", true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _skip_all(n: Node) -> void:
	if n is Label:
		n.set_meta("audit_skip", true)
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_skip_all(c)

func _place(p: Control) -> void:
	var ps := get_parent_area_size() if get_parent() is Control else get_viewport_rect().size
	if size != ps:
		size = ps
	p.reset_size()
	var x := MARGIN if side == "left" else ps.x - p.size.x - MARGIN
	var y := clampf(ps.y * vpos - p.size.y * 0.5, MARGIN, ps.y - p.size.y - MARGIN)
	p.position = Vector2(x, y)

# ---------------- справочник ----------------
const PER_PAGE := 5
var page := -1                      # открытая страница справки (−1 — закрыта)

func _entries() -> Array:
	var out: Array = []
	for id in data:
		if not bool((data[id] as Dictionary).get("nog", false)):
			out.append(id)
	return out

func pages() -> int:
	return maxi(1, int(ceil(float(_entries().size()) / float(PER_PAGE))))

## H: открыть справку → следующая страница → … → закрыть. Узкая панель сбоку, по пять пунктов на страницу:
## целиком список на экран не помещается, а широкая панель закрывала бы игру.
func toggle_guide() -> void:
	page = page + 1 if (guide != null and guide.visible) else 0
	if guide != null:
		guide.queue_free()
		guide = null
	if page >= pages():
		page = -1
		return
	guide = MGUI.panel(true, MGUI.GOLD, MGUI.S3)
	guide.custom_minimum_size = Vector2(W + 40.0, 0)
	var v := MGUI.vbox(MGUI.S2)
	guide.add_child(v)
	v.add_child(MGUI.label("СПРАВКА · ЧТО ЧТО ДЕЛАЕТ · %d/%d" % [page + 1, pages()], "caps", MGUI.GOLD))
	var ids := _entries().slice(page * PER_PAGE, (page + 1) * PER_PAGE)
	for id in ids:
		var e: Dictionary = data[id]
		var line := fill(String(e.get("t", "")))
		var ks: Array = []
		for pr in e.get("k", []):
			ks.append("%s — %s" % [fill(String(pr[0])), fill(String(pr[1]))])
		v.add_child(MGUI.label(line, "body_b", MGUI.TEXT, W + 12.0))
		var body := fill(String(e.get("g", e.get("x", ""))))
		if not ks.is_empty():
			body = ("; ".join(ks) + (". " + body if body != "" else "")).strip_edges()
		if body != "":
			v.add_child(MGUI.label(body, "micro", MGUI.TEXT_2, W + 12.0))
	var more := "H — дальше" if page + 1 < pages() else "H — убрать"
	v.add_child(MGUI.label("%s · Shift+H — %s всплывающие подсказки" % [more, "выключить" if enabled() else "включить"], "micro", MGUI.TEXT_3))
	_skip_all(guide)
	add_child(guide)
	_place(guide)
	if card != null:
		card.visible = false
		cur = ""

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or not is_visible_in_tree():
		return
	var k := e as InputEventKey
	if k.physical_keycode == KEY_H and not held:
		if k.shift_pressed:
			set_enabled(not enabled())
			if guide != null and guide.visible:
				page -= 1
				toggle_guide()                     # та же страница, обновлена строка вкл./выкл.
		else:
			toggle_guide()
		get_viewport().set_input_as_handled()

# ---------------- клавиши в тексте ----------------
## {race_accelerate} → «W»: первая клавиша действия из InputMap
static func fill(s: String) -> String:
	if s.find("{") < 0:
		return s
	var out := s
	var rx := RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
	for m in rx.search_all(s):
		out = out.replace(m.get_string(0), key_of(m.get_string(1)))
	return out

static func key_of(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var kc: int = (ev as InputEventKey).physical_keycode if (ev as InputEventKey).physical_keycode != 0 else (ev as InputEventKey).keycode
			return OS.get_keycode_string(kc).to_upper()
		if ev is InputEventMouseButton:
			return "ЛКМ" if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "ПКМ"
	return "—"
