## Экран ONLINE RACE в главном меню (menu.online): CREATE LOBBY / JOIN LOBBY, формы с полями, лобби с карточками
## участников. На столе меню 1600×900, в стиле меню: тёмная рваная карточка, белые надписи, красные акценты.
## Сетевую логику ведёт race_net.gd (main.race_net) — экран только показывает и передаёт нажатия.
## Управление: W/S — выбор, Enter — нажать / редактировать поле, A/D — изменить значение, Esc — назад; мышь.
class_name RaceLobby
extends Control

const RED := Color(0.86, 0.09, 0.11)

var menu
var net: RaceNet
var screen := ""                 # home / create / join / wait / lobby
var card: Control
var rows: Array = []             # {label, kind: btn/field/adj/info, act, adj, text, edit}
var sel := 0
var msg: Label
var msg_text := ""
var cards: Array = []            # карточки игроков: {id, root}
var seen_ids := {}
var form := {"room": "ПЫЛЬНЫЙ ЗАЕЗД", "name": "", "max": 8, "laps": 3, "track": "tomsk_dust", "private": false, "password": "",
	"ip": "127.0.0.1", "port": str(RaceNet.PORT), "jpass": ""}
var lan_t := 0.0
var refresh_t := 0.0

func setup(m) -> void:
	menu = m
	size = Menu.STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	form["name"] = String(RaceSave.v("name"))
	visible = false

func _net() -> RaceNet:
	if menu.main.race_net == null or not is_instance_valid(menu.main.race_net):
		var n := RaceNet.new()
		n.main = menu.main
		menu.main.add_child(n)
		menu.main.race_net = n
	net = menu.main.race_net
	if not net.lobby_changed.is_connected(_on_lobby):
		net.lobby_changed.connect(_on_lobby)
		net.joined.connect(func(): show_screen("lobby"))
		net.failed.connect(func(r: String): _error(r))
		net.closed.connect(func(r: String): _error(r))
	return net

func open() -> void:
	menu._close()
	visible = true
	_net()
	show_screen("lobby" if net.online() and not net.lobby.is_empty() else "home")

func close() -> void:
	visible = false
	if net != null:
		net.stop_discovery()
	_clear()

func _error(r: String) -> void:
	msg_text = r
	if visible:
		show_screen("home")

# ---------------- построение экранов ----------------
func _clear() -> void:
	for c in get_children():
		c.queue_free()
	rows = []
	cards = []
	sel = 0

func _text(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	return menu._text(parent, s, fs, col, pos, f)

func _frame(title: String, sub: String, w := 760.0) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.size = Menu.STAGE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var poly := Polygon2D.new()
	poly.polygon = menu._torn(w, 600.0, 113)
	poly.color = Color(0.04, 0.04, 0.05, 0.97)
	poly.position = Vector2(110, 200)
	add_child(poly)
	var edge := Line2D.new()
	edge.points = poly.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = Menu.WHITE
	poly.add_child(edge)
	var h := _text(self, title, 62, Menu.WHITE, Vector2(116, 196), menu.serif)
	h.rotation = deg_to_rad(-2.0)
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(0, 0), Vector2(240, -9), Vector2(236, 4), Vector2(-4, 13)])
	slash.color = RED
	slash.position = Vector2(126, 276)
	add_child(slash)
	_text(self, sub, 15, Menu.SILVER, Vector2(128, 290))
	card = Control.new()
	card.position = Vector2(130, 322)
	card.size = Vector2(w - 40, 460)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	msg = _text(self, msg_text, 15, Color(1.0, 0.55, 0.5), Vector2(130, 772))
	msg.size = Vector2(w - 40, 40)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.16)

func _row(kind: String, text, act = null, adj = null, field := "", secret := false) -> void:
	var i := rows.size()
	var y := 0.0
	for r in rows:
		y += 40.0
	var l := _text(card, "", 24, Menu.GREY, Vector2(0, y), menu.serif)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var r := {"label": l, "kind": kind, "act": act, "adj": adj, "text": text, "edit": null, "field": field}
	if kind == "field":
		var e := LineEdit.new()
		e.position = Vector2(300, y + 2)
		e.size = Vector2(380, 32)
		e.text = String(form[field])
		e.secret = secret
		e.max_length = 64 if field == "ip" else 24
		e.add_theme_font_override("font", menu.tech)
		e.add_theme_font_size_override("font_size", 18)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.11)
		sb.border_color = Menu.GREY
		sb.set_border_width_all(1)
		sb.content_margin_left = 8
		e.add_theme_stylebox_override("normal", sb)
		var sf: StyleBoxFlat = sb.duplicate()
		sf.border_color = RED
		sf.set_border_width_all(2)
		e.add_theme_stylebox_override("focus", sf)
		e.text_changed.connect(func(t: String): form[field] = t)
		e.text_submitted.connect(func(_t: String):
			e.release_focus()
			select(i + 1))
		e.focus_entered.connect(func(): select(i, false))
		card.add_child(e)
		r["edit"] = e
	rows.append(r)
	l.mouse_entered.connect(func(): select(i, false))
	l.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT):
			select(i, false)
			activate(-1 if ev.button_index == MOUSE_BUTTON_RIGHT else 1))

func select(i: int, sound := true) -> void:
	if rows.is_empty():
		return
	i = posmod(i, rows.size())
	if rows[i]["kind"] == "info":
		i = posmod(i + 1, rows.size())
	if sound and i != sel:
		menu.main.ui("move")
	sel = i
	_paint()

func _paint() -> void:
	for k in rows.size():
		var r: Dictionary = rows[k]
		var tx = r["text"]
		var s: String = String(tx.call()) if tx is Callable else String(tx)
		var on := k == sel
		var l: Label = r["label"]
		if r["kind"] == "info":
			l.text = s
			l.add_theme_font_override("font", menu.tech)
			l.add_theme_font_size_override("font_size", 16)
			l.add_theme_color_override("font_color", Menu.SILVER)
			continue
		l.text = ("▶ " if on else "   ") + s + ("   ◀ ▶" if on and r["adj"] != null else "")
		l.add_theme_color_override("font_color", Menu.WHITE if on else Menu.GREY)

func activate(dir := 1) -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	if r["kind"] == "field" and dir > 0:
		(r["edit"] as LineEdit).grab_focus()
		(r["edit"] as LineEdit).caret_column = (r["edit"] as LineEdit).text.length()
		return
	if r["adj"] != null:
		menu.main.ui("value", 1.08 if dir > 0 else 0.92)
		(r["adj"] as Callable).call(dir)
	elif r["act"] != null and dir > 0:
		menu.main.ui("confirm")
		(r["act"] as Callable).call()
	if visible and not rows.is_empty():
		_paint()

func show_screen(s: String) -> void:
	_clear()
	screen = s
	match s:
		"home":
			_home()
		"create":
			_create()
		"join":
			_join()
		"wait":
			_frame("ONLINE RACE", "Подключение…")
			_row("info", "Подключаемся к %s:%s…" % [form["ip"], form["port"]])
			_row("btn", "ОТМЕНА", func():
				net.leave_peer()
				show_screen("join"))
		"lobby":
			_lobby()
	select(0, false)

func _home() -> void:
	_frame("ONLINE RACE", "Гонка с друзьями по сети: один создаёт лобби, остальные подключаются по IP (или находят его в локальной сети).")
	_row("btn", "CREATE LOBBY", func(): show_screen("create"))
	_row("btn", "JOIN LOBBY", func(): show_screen("join"))
	_row("info", "Порт игры — UDP %d. Через интернет хосту нужен проброс этого порта (docs/ONLINE_RACING_SETUP.md)." % RaceNet.PORT)
	_row("btn", "НАЗАД", func(): back())

func _create() -> void:
	_frame("CREATE LOBBY", "Ты — хост: твой компьютер считает гонку, друзья подключаются к тебе.")
	_row("field", "НАЗВАНИЕ", null, null, "room")
	_row("field", "ТВОЁ ИМЯ", null, null, "name")
	_row("adj", func(): return "ИГРОКОВ: до %d" % int(form["max"]), null, func(d: int): form["max"] = clampi(int(form["max"]) + d, 2, RaceNet.MAX_PLAYERS))
	_row("adj", func(): return "ТРАССА: " + String(RaceData.track(String(form["track"]))["name"]), null, func(d: int):
		var lst: Array = RaceData.TRACK_ORDER
		form["track"] = lst[posmod(lst.find(form["track"]) + d, lst.size())])
	_row("adj", func(): return "КРУГОВ: %d" % int(form["laps"]), null, func(d: int): form["laps"] = clampi(int(form["laps"]) + d, 1, 5))
	_row("adj", func(): return "ПРИВАТНОЕ: " + ("ДА — не видно в локальной сети" if bool(form["private"]) else "НЕТ — видно в локальной сети"), null, func(_d: int): form["private"] = not bool(form["private"]))
	_row("field", "ПАРОЛЬ (можно пусто)", null, null, "password", true)
	_row("btn", "СОЗДАТЬ", func():
		RaceSave.put("name", RaceNet.clean_name(String(form["name"])))
		var err := net.host_lobby({"room": form["room"], "name": form["name"], "max": form["max"], "track": form["track"], "laps": form["laps"],
			"private": form["private"], "password": form["password"], "rider": "pahan"})
		if err != "":
			msg_text = err
			show_screen("create")
		else:
			msg_text = ""
			show_screen("lobby"))
	_row("btn", "НАЗАД", func(): show_screen("home"))

func _join() -> void:
	_frame("JOIN LOBBY", "Введи IP и порт хоста — или выбери лобби из локальной сети ниже.")
	_row("field", "IP ХОСТА", null, null, "ip")
	_row("field", "UDP-ПОРТ", null, null, "port")
	_row("field", "ТВОЁ ИМЯ", null, null, "name")
	_row("field", "ПАРОЛЬ", null, null, "jpass", true)
	_row("btn", "JOIN", func(): _do_join())
	var listening := net.start_discovery()
	_row("info", func():
		if not listening:
			return "Поиск в локальной сети недоступен (порт %d занят)" % RaceNet.DISCOVERY_PORT
		if net.found.is_empty():
			return "Лобби в локальной сети: ищем…"
		return "Лобби в локальной сети:")
	for k in 4:
		var kk := k
		_row("btn", func():
			var lst := net.found.values()
			if kk >= lst.size():
				return ""
			var f: Dictionary = lst[kk]
			return "%s — %s · %d/%d%s · %s:%d" % [f["room"], f["host_name"], f["players"], f["max"], " · пароль" if f["has_pass"] else "", f["ip"], f["port"]], func():
			var lst := net.found.values()
			if kk < lst.size():
				form["ip"] = String(lst[kk]["ip"])
				form["port"] = str(int(lst[kk]["port"]))
				_do_join())
	_row("btn", "НАЗАД", func(): show_screen("home"))

func _do_join() -> void:
	RaceSave.put("name", RaceNet.clean_name(String(form["name"])))
	net.stop_discovery()
	var err := net.join(String(form["ip"]), int(String(form["port"])), String(form["name"]), String(form["jpass"]))
	if err != "":
		msg_text = err
		show_screen("join")
		return
	msg_text = ""
	show_screen("wait")

func _lobby() -> void:
	var L := net.lobby
	_frame(String(L.get("room", "ЛОББИ")), "Хост: %s · %s · кругов %d%s" % [L.get("host_name", "?"), String(RaceData.track(String(L.get("track", "")))["name"]), int(L.get("laps", 3)), " · пароль" if bool(L.get("has_pass", false)) else ""], 640.0)
	if net.is_host:
		var ips: Array = []
		for a in IP.get_local_addresses():
			if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
				ips.append(a)
		_row("info", "Друзьям: IP %s, UDP-порт %d" % [" / ".join(ips.slice(0, 2)) if not ips.is_empty() else "этого компьютера", int(L.get("port", RaceNet.PORT))])
		_row("adj", func(): return "КРУГОВ: %d" % int(net.lobby.get("laps", 3)), null, func(d: int): net.set_setting("laps", int(net.lobby["laps"]) + d))
		_row("adj", func(): return "ИГРОКОВ: до %d" % int(net.lobby.get("max", 8)), null, func(d: int): net.set_setting("max", int(net.lobby["max"]) + d))
	_row("adj", func(): return "ГОНЩИК: " + RaceVisual.rider_name(_me().get("rider", "pahan")), null, func(d: int):
		var lst: Array = RaceVisual.RIDERS.keys()
		net.pick(String(lst[posmod(lst.find(String(_me().get("rider", "pahan"))) + d, lst.size())])))
	if net.is_host:
		_row("btn", func():
			var n: int = (net.lobby.get("players", []) as Array).size()
			if n < 2:
				return "START RACE — ждём хотя бы одного друга"
			return "START RACE" if net.can_start() else "START RACE — не все READY", func():
			if not net.start_race():
				msg_text = "Нужно минимум 2 участника, и все должны нажать READY."
				msg.text = msg_text)
	else:
		_row("btn", func(): return "READY: " + ("ДА" if bool(_me().get("ready", false)) else "НЕТ — нажми, когда готов"), func(): net.set_ready(not bool(_me().get("ready", false))))
		_row("info", func(): return "Пинг до хоста: %d мс" % net.my_ping())
	_row("btn", "ВЫЙТИ ИЗ ЛОББИ", func():
		net.leave_peer()
		msg_text = ""
		show_screen("home"))
	_cards()

func _me() -> Dictionary:
	for p in net.lobby.get("players", []):
		if int(p["id"]) == net.my_id:
			return p
	return {}

## карточки участников справа: имя, гонщик и цвет его пылесоса, HOST / PLAYER, READY / NOT READY, пинг
func _cards() -> void:
	for c in cards:
		if is_instance_valid(c["root"]):
			c["root"].queue_free()
	cards = []
	var ps: Array = net.lobby.get("players", [])
	for k in ps.size():
		var p: Dictionary = ps[k]
		var root := Control.new()
		root.position = Vector2(790 + (k % 2) * 380, 210 + (k / 2) * 140)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		var mine := int(p["id"]) == net.my_id
		var bg := Polygon2D.new()
		bg.polygon = menu._torn(340.0, 118.0, 200 + k)
		bg.color = Menu.WHITE if mine else Color(0.08, 0.08, 0.09, 0.95)
		root.add_child(bg)
		var edge := Line2D.new()
		edge.points = bg.polygon
		edge.closed = true
		edge.width = 2.0
		edge.default_color = RED if bool(p["host"]) else Menu.GREY
		bg.add_child(edge)
		var ink := Menu.INK if mine else Menu.WHITE
		_text(root, String(p["name"]), 28, ink, Vector2(14, 6), menu.serif)
		var chip := ColorRect.new()
		chip.color = RaceVisual.RIDERS.get(String(p["rider"]), RaceVisual.RIDERS["pahan"])["tint"]
		chip.position = Vector2(16, 52)
		chip.size = Vector2(16, 16)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(chip)
		_text(root, RaceVisual.rider_name(String(p["rider"])), 16, ink, Vector2(40, 50))
		var tag := ColorRect.new()
		tag.color = RED if bool(p["host"]) else (Menu.INK if mine else Menu.WHITE)
		tag.position = Vector2(14, 82)
		tag.size = Vector2(84, 22)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tag)
		var tl := _text(tag, "HOST" if bool(p["host"]) else "PLAYER", 14, Menu.WHITE if bool(p["host"]) or mine else Menu.INK, Vector2.ZERO)
		tl.size = tag.size
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rd := _text(root, "READY" if bool(p["ready"]) else "NOT READY", 18, (Color(0.1, 0.55, 0.2) if mine else Color(0.5, 1.0, 0.6)) if bool(p["ready"]) else RED, Vector2(112, 82), menu.serif)
		rd.size = Vector2(140, 24)
		if not bool(p["host"]):
			_text(root, "%d мс" % int(p.get("ping", 0)), 14, Menu.GREY, Vector2(262, 86))
		if not seen_ids.has(int(p["id"])):
			seen_ids[int(p["id"])] = true
			root.modulate.a = 0.0
			root.position.x += 60.0
			var tw := root.create_tween().set_parallel(true)
			tw.tween_property(root, "modulate:a", 1.0, 0.3)
			tw.tween_property(root, "position:x", root.position.x - 60.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cards.append({"id": int(p["id"]), "root": root})

func _on_lobby() -> void:
	if not visible:
		return
	if screen == "lobby":
		_cards()
		_paint()
	elif screen == "wait" and not net.lobby.is_empty():
		show_screen("lobby")

func back() -> void:
	match screen:
		"create", "join":
			net.stop_discovery()
			show_screen("home")
		"wait":
			net.leave_peer()
			show_screen("join")
		"lobby":
			net.leave_peer()
			show_screen("home")
		_:
			close()
			if net != null and not net.online():
				menu.main.race_net = null
				net.queue_free()
				net = null
			menu.open_race(4)

func handle_key(k: int) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		if k == KEY_ESCAPE:
			focus.release_focus()
			return true
		return false
	if k == KEY_W or k == KEY_UP:
		select(sel - 1)
	elif k == KEY_S or k == KEY_DOWN:
		select(sel + 1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_D or k == KEY_RIGHT:
		activate(1)
	elif k == KEY_A or k == KEY_LEFT:
		activate(-1)
	elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
		menu.main.ui("back")
		back()
	else:
		return false
	return true

func _process(dt: float) -> void:
	if not visible:
		return
	refresh_t -= dt
	if refresh_t <= 0.0:
		refresh_t = 0.5
		if screen == "join" or (screen == "lobby" and not net.is_host):
			_paint()
		if screen == "lobby" and net.is_host:
			net._send_lobby()                    # пинги участников раз в полсекунды
