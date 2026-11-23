## Экран «РАЗВИТИЕ ПАХАНА» на дизайн-системе MGUI: пять веток-колонок (значок и название ветки сверху), узлы со
## связями-требованиями, состояния (закрыт — тусклый, можно изучить — рамка цвета ветки, куплен — залит, ранги точками).
## Подписей под узлами нет — они налезали бы друг на друга: название видно у выбранного узла и в панели подробностей
## справа (что даёт сейчас → после покупки, цена, требования, синергии). Внизу — одна строка: синергии и ближайшая веха.
## Мышь: навёл — подробности, клик — изучить. Клавиши: стрелки — по узлам, Enter — изучить, L — ЛЕГЕНДА РАЙОНА, Esc.
class_name MLTreeUI
extends Control

const NODE := 44.0
const ROW_H := 96.0
const KIND_ICON := {"stat": "plus", "unlock": "diamond", "ability": "bolt", "capstone": "star"}
const KIND_NAME := {"stat": "улучшение", "unlock": "открытие", "ability": "способность", "capstone": "вершина ветки"}
const BRANCH_ICON := {"worker": "broom", "master": "wrench", "boss": "shop", "schemes": "doc", "ties": "worker"}

var ui: MLUI
var widgets := {}          # id → {box, sb, icon, pips}
var order: Array = []
var sel := ""
var tree_area: Control
var lines: Node2D
var name_tag: PanelContainer
var name_l: Label
var head: Label
var d_title: Label
var d_kind: Label
var d_body: Label
var d_state: Label
var foot: Label
var col_w := 220.0
var t := 0.0

func career() -> MLCareer:
	return ui.econ().career

func build() -> void:
	size = Vector2(ui.W, MLUI.STAGE.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := MGUI.panel(false, null, MGUI.S4)
	pc.position = Vector2(16, 86)
	pc.custom_minimum_size = Vector2(ui.W - 32, MLUI.STAGE.y - 86 - 16)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pc)
	var v := MGUI.vbox(MGUI.S3)
	pc.add_child(v)
	# шапка: заголовок, уровень и очки, кнопки
	var top := MGUI.hbox(MGUI.S4)
	v.add_child(top)
	var tl := MGUI.vbox(MGUI.S1)
	top.add_child(tl)
	tl.add_child(MGUI.label("РАЗВИТИЕ ПАХАНА", "h1"))
	head = MGUI.label("", "small", MGUI.GOLD)
	tl.add_child(head)
	top.add_child(MGUI.spacer())
	top.add_child(ui.make_toast_slot())
	var lg := MGUI.button("ЛЕГЕНДА РАЙОНА")
	lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lg.pressed.connect(func(): ui.legend_screen())
	top.add_child(lg)
	var back := MGUI.button("НАЗАД")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): ui.show_phase())
	top.add_child(back)
	v.add_child(MGUI.hsep())
	# середина: дерево слева, подробности справа
	var mid := MGUI.hbox(MGUI.S4)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	tree_area = Control.new()
	tree_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_area.custom_minimum_size = Vector2(0, 560)
	tree_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(tree_area)
	var det := MGUI.panel(false, MGUI.RED, MGUI.S4)
	det.custom_minimum_size = Vector2(340, 0)
	mid.add_child(det)
	var dv := MGUI.vbox(MGUI.S2)
	det.add_child(dv)
	d_kind = MGUI.label("", "caps")
	dv.add_child(d_kind)
	d_title = MGUI.label("", "h2", null, 300.0)
	dv.add_child(d_title)
	d_body = MGUI.label("", "small", MGUI.TEXT_2, 300.0)
	dv.add_child(d_body)
	dv.add_child(MGUI.hsep())
	d_state = MGUI.label("", "small", MGUI.TEXT, 300.0)
	dv.add_child(d_state)
	v.add_child(MGUI.hsep())
	foot = MGUI.label("", "small", MGUI.TEXT_2)
	foot.clip_text = true
	foot.custom_minimum_size.x = ui.W - 64
	v.add_child(foot)
	v.add_child(MGUI.hints([["← ↑ ↓ →", "узел"], ["Enter", "изучить"], ["L", "легенда района"], ["Esc", "назад"]]))
	_fill.call_deferred()

## узлы и связи — после того как контейнеры дали области дерева настоящий размер
func _fill() -> void:
	var aw := tree_area.size.x
	col_w = aw / float(MLTree.BRANCH_ORDER.size())
	lines = Node2D.new()
	tree_area.add_child(lines)
	for bi in MLTree.BRANCH_ORDER.size():
		var bid: String = MLTree.BRANCH_ORDER[bi]
		var B: Dictionary = MLTree.BRANCHES[bid]
		if bi > 0:
			var sep := ColorRect.new()
			sep.color = MGUI.LINE
			sep.position = Vector2(bi * col_w, 0)
			sep.size = Vector2(1, tree_area.size.y)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tree_area.add_child(sep)
		var hd := MGUI.hbox(MGUI.S2)
		hd.position = Vector2(bi * col_w + 10, 2)
		tree_area.add_child(hd)
		hd.add_child(MGIcon.make(String(BRANCH_ICON[bid]), 16, B["col"]))
		hd.add_child(MGUI.label(String(B["name"]), "caps_m", B["col"]))
	for n in MLTree.NODES:
		for q in n["req"]:
			var qn := MLTree.node(String(q[0]))
			if qn.is_empty():
				continue
			var ln := Line2D.new()
			ln.points = PackedVector2Array([_pos(qn) + Vector2(0, NODE * 0.5), _pos(n) - Vector2(0, NODE * 0.5)])
			ln.width = 2.0
			ln.set_meta("from", String(q[0]))
			ln.set_meta("to", String(n["id"]))
			lines.add_child(ln)
	var sorted: Array = MLTree.NODES.duplicate()
	sorted.sort_custom(func(a, b): return _key(a) < _key(b))
	for n in sorted:
		var id := String(n["id"])
		order.append(id)
		var c := _pos(n)
		var box := Panel.new()
		box.position = c - Vector2(NODE, NODE) * 0.5
		box.size = Vector2(NODE, NODE)
		box.pivot_offset = box.size * 0.5
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := MGUI.box(Color(0.08, 0.08, 0.09), int(NODE * 0.5) if String(n["kind"]) != "capstone" else 6, 2, MGUI.LINE, 0)
		box.add_theme_stylebox_override("panel", sb)
		tree_area.add_child(box)
		var ic := MGIcon.make(String(KIND_ICON.get(String(n["kind"]), "plus")), 20, MGUI.TEXT_3)
		ic.position = (box.size - Vector2(20, 20)) * 0.5
		box.add_child(ic)
		# ранги — точки под узлом (у одноранговых не нужны)
		var pips := MGUI.hbox(3)
		pips.position = c + Vector2(-float(n["max"]) * 4.5 + 1.5, NODE * 0.5 + 5)
		tree_area.add_child(pips)
		var dots: Array = []
		if int(n["max"]) > 1:
			for k in int(n["max"]):
				var d := ColorRect.new()
				d.custom_minimum_size = Vector2(6, 3)
				d.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pips.add_child(d)
				dots.append(d)
		widgets[id] = {"box": box, "sb": sb, "icon": ic, "dots": dots}
		box.mouse_entered.connect(func(): _pick(id))
		box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick(id)
				buy())
	# подпись выбранного узла — одна на всё дерево, поверх
	name_tag = MGUI.panel(false, null, 0)
	var nsb := name_tag.get_theme_stylebox("panel") as StyleBoxFlat
	nsb.bg_color = MGUI.PAPER
	nsb.content_margin_left = 8
	nsb.content_margin_right = 8
	nsb.content_margin_top = 2
	nsb.content_margin_bottom = 3
	tree_area.add_child(name_tag)
	name_l = MGUI.label("", "caps", MGUI.INK)
	name_tag.add_child(name_l)
	var C := career()
	sel = order[0]
	for id in order:
		if C.why_not(String(id)) == "":
			sel = String(id)
			break
	paint()

static func _key(n: Dictionary) -> int:
	return MLTree.BRANCH_ORDER.find(n["b"]) * 1000 + int(n["row"]) * 10 + int(n["col"]) + 5

func _pos(n: Dictionary) -> Vector2:
	var bi := MLTree.BRANCH_ORDER.find(n["b"])
	return Vector2(bi * col_w + col_w * 0.5 + float(n["col"]) * minf(46.0, col_w * 0.19), 86.0 + float(n["row"]) * ROW_H)

func _pick(id: String) -> void:
	if id != sel:
		ui.root.snd.play("tick")
	sel = id
	paint()

func paint() -> void:
	if widgets.is_empty():
		return
	var C := career()
	head.text = "Уровень %d · опыт %d / %d · очков навыков: %d · неделя %d · авторитет %d" % [int(C.d["level"]), int(C.d["xp"]), MLCareer.xp_need(int(C.d["level"])), int(C.d["points"]), int(C.d["week"]), int(C.d["legend"]["points"])]
	for id in widgets:
		var w: Dictionary = widgets[id]
		var n_node := MLTree.node(String(id))
		var col: Color = MLTree.BRANCHES[n_node["b"]]["col"]
		var r_row := C.rank(String(id))
		var why_txt := C.why_not(String(id))
		var sb: StyleBoxFlat = w["sb"]
		var icol := MGUI.TEXT_3
		if r_row > 0:
			sb.bg_color = col.darkened(0.15)
			sb.border_color = col.lightened(0.35)
			icol = MGUI.INK
		elif why_txt == "":
			sb.bg_color = Color(0.08, 0.08, 0.09)
			sb.border_color = col
			icol = col
		else:
			sb.bg_color = Color(0.07, 0.07, 0.08)
			sb.border_color = MGUI.LINE
		sb.set_border_width_all(4 if String(id) == sel else 2)
		if String(id) == sel:
			sb.border_color = MGUI.TEXT
		(w["icon"] as MGIcon).set_icon(String(KIND_ICON.get(String(n_node["kind"]), "plus")), icol)
		var dots: Array = w["dots"]
		for k in dots.size():
			(dots[k] as ColorRect).color = col if k < r_row else Color(0.22, 0.22, 0.25)
	for ln in lines.get_children():
		var l := ln as Line2D
		var on := C.rank(String(l.get_meta("from"))) > 0
		l.default_color = (MLTree.BRANCHES[MLTree.node(String(l.get_meta("to")))["b"]]["col"] as Color).darkened(0.2) if on else Color(0.2, 0.2, 0.23)
	# выбранный узел: подпись над ним и подробности справа
	var n := MLTree.node(sel)
	var r := C.rank(sel)
	var why := C.why_not(sel)
	var B: Dictionary = MLTree.BRANCHES[n["b"]]
	name_l.text = String(n["name"])
	name_tag.reset_size()
	var np := _pos(n) + Vector2(-name_tag.get_combined_minimum_size().x * 0.5, -NODE * 0.5 - 24)
	name_tag.position = Vector2(clampf(np.x, 0.0, tree_area.size.x - name_tag.get_combined_minimum_size().x), np.y)
	d_kind.text = "%s · %s" % [B["name"], String(KIND_NAME.get(String(n["kind"]), "")).to_upper()]
	d_kind.add_theme_color_override("font_color", B["col"])
	d_title.text = String(n["name"])
	var reqs: Array = (n["req"] as Array).map(func(q): return "«%s»%s" % [MLTree.node(String(q[0]))["name"], " ×%d" % int(q[1]) if int(q[1]) > 1 else ""])
	var syns: Array = MLTree.SYNERGIES.filter(func(s): return (s["need"] as Array).any(func(nd): return String(nd[0]) == "node" and String(nd[1]) == sel))
	var body := String(n["desc"]).capitalize().left(1) + String(n["desc"]).substr(1) + "."
	body += "\n\nРанг %d из %d\nСейчас: %s\nПосле: %s" % [r, int(n["max"]), C.effect_text(sel), C.effect_text(sel, mini(r + 1, int(n["max"]))) if r < int(n["max"]) else "максимум"]
	body += "\n\nЦена: %d очк. · с уровня %d" % [int(n["cost"]), int(n["lvl"])]
	if not reqs.is_empty():
		body += "\nНужно: " + ", ".join(reqs)
	for s in syns:
		body += "\n\nСинергия «%s»%s: %s" % [s["name"], " — работает" if C.synergy_on(s) else "", s["desc"]]
	d_body.text = body
	d_state.text = "Можно изучить — Enter или клик" if why == "" else ("Изучено полностью" if why == "максимум" else "Пока нельзя: " + why)
	d_state.add_theme_color_override("font_color", MGUI.GOOD if why == "" else (MGUI.TEXT_2 if why == "максимум" else MGUI.WARN))
	var on_n := MLTree.SYNERGIES.filter(func(s): return C.synergy_on(s)).size()
	var ms: Array = MLTree.MILESTONES.filter(func(m): return not (C.d["ms"] as Dictionary).has(String(m["id"])))
	foot.text = "Синергии: %d из %d работают" % [on_n, MLTree.SYNERGIES.size()] + ("  ·  ближайшая веха: %s (%d / %d)" % [String(ms[0]["name"]).to_lower(), C.stat(String(ms[0]["stat"])), int(ms[0]["need"])] if not ms.is_empty() else "")

func buy() -> void:
	var C := career()
	if not C.buy_node(sel):
		ui.root.snd.play("fail")
		return
	ui.root.snd.play("buy")
	ui.econ().xp(0)
	var box: Panel = widgets[sel]["box"]
	box.scale = Vector2(1.35, 1.35)
	box.create_tween().tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui.root.biz_visuals()
	ui.econ().changed.emit()
	ui.root.save()
	paint()

func key(k: int) -> bool:
	if order.is_empty():
		return false
	var i := order.find(sel)
	var n := MLTree.node(sel)
	match k:
		KEY_LEFT, KEY_A:
			_pick(String(order[posmod(i - 1, order.size())]))
		KEY_RIGHT, KEY_D:
			_pick(String(order[posmod(i + 1, order.size())]))
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			var dir := -1 if k in [KEY_UP, KEY_W] else 1
			var best := ""
			var bd := 1e9
			for id in order:
				var m := MLTree.node(String(id))
				if m["b"] == n["b"] and int(m["row"]) == int(n["row"]) + dir:
					var dd := absf(float(m["col"]) - float(n["col"]))
					if dd < bd:
						bd = dd
						best = String(id)
			if best != "":
				_pick(best)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			buy()
		KEY_L:
			ui.legend_screen()
		KEY_ESCAPE:
			ui.show_phase()
		_:
			return false
	return true
