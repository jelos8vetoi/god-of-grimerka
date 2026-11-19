## Экран «РАЗВИТИЕ ПАХАНА»: пять веток (колонки со своим цветом и значком), узлы со связями-требованиями,
## состояния (закрыт / можно купить — пульсирует / куплен — залит цветом, с рангами), справа — подробности выбранного
## (что даёт сейчас и после покупки, цена, требования, связанные синергии), внизу — синергии и вехи. Мышь: навёл —
## подробности, клик — купить. Клавиши: стрелки — по узлам, Enter — купить, L — ЛЕГЕНДА РАЙОНА, Esc — назад.
class_name MLTreeUI
extends Control

const COL_W := 236.0
const X0 := 40.0
const Y0 := 250.0
const ROW_H := 108.0
const NODE := 64.0

var ui: MLUI
var widgets := {}          # id → {box, sb, rank_l, center}
var order: Array = []      # id по веткам и рядам — для клавиш
var sel := ""
var info: Label
var info_head: Label
var syn_l: Label
var head: Label
var lines: Node2D
var t := 0.0

func career() -> MLCareer:
	return ui.econ().career

func build() -> void:
	size = MLUI.STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.94)
	bg.position = Vector2(20, 134)
	bg.size = Vector2(1560, 750)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	ui.txt(self, "РАЗВИТИЕ ПАХАНА", 44, MLUI.WHITE, Vector2(40, 142), ui.serif)
	head = ui.txt(self, "", 18, Color(1.0, 0.8, 0.3), Vector2(44, 196))
	ui.txt(self, "наведи — подробности · клик / Enter — изучить · L — ЛЕГЕНДА РАЙОНА · Esc — назад", 13, MLUI.GREY, Vector2(620, 202))
	lines = Node2D.new()
	add_child(lines)
	var C := career()
	# колонки веток
	for bi in MLTree.BRANCH_ORDER.size():
		var bid: String = MLTree.BRANCH_ORDER[bi]
		var B: Dictionary = MLTree.BRANCHES[bid]
		var cx := X0 + bi * COL_W + COL_W * 0.5
		var plate := ColorRect.new()
		plate.color = (B["col"] as Color).darkened(0.8)
		plate.color.a = 0.5
		plate.position = Vector2(cx - COL_W * 0.47, 226)
		plate.size = Vector2(COL_W * 0.94, 560)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(plate)
		var bt := ui.txt(self, "%s %s" % [B["icon"], B["name"]], 18, B["col"], Vector2(cx - COL_W * 0.45, 230), ui.serif)
		bt.size = Vector2(COL_W * 0.9, 24)
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# связи (под узлами)
	for n in MLTree.NODES:
		var p := _pos(n)
		for q in n["req"]:
			var qn := MLTree.node(String(q[0]))
			if qn.is_empty():
				continue
			var ln := Line2D.new()
			ln.points = PackedVector2Array([_pos(qn) + Vector2(0, NODE * 0.5), p - Vector2(0, NODE * 0.5)])
			ln.width = 3.0
			ln.default_color = Color(0.35, 0.35, 0.38)
			ln.set_meta("from", String(q[0]))
			ln.set_meta("to", String(n["id"]))
			lines.add_child(ln)
	# узлы
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
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(NODE * 0.5) if String(n["kind"]) != "capstone" else 10)
		sb.set_border_width_all(3)
		box.add_theme_stylebox_override("panel", sb)
		add_child(box)
		var ic := Label.new()
		ic.text = {"stat": "+", "unlock": "◆", "ability": "⚡", "capstone": "★"}.get(String(n["kind"]), "•")
		ic.size = box.size
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic.add_theme_font_size_override("font_size", 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)
		var nm := ui.txt(self, String(n["name"]), 11, MLUI.SILVER, c + Vector2(-COL_W * 0.45, NODE * 0.5 + 2))
		nm.size = Vector2(COL_W * 0.9, 14)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_constant_override("outline_size", 3)
		var rk := ui.txt(self, "", 12, MLUI.WHITE, c + Vector2(NODE * 0.32, -NODE * 0.62))
		widgets[id] = {"box": box, "sb": sb, "ic": ic, "rank": rk, "name": nm}
		box.mouse_entered.connect(func(): _pick(id))
		box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick(id)
				buy())
	# подробности справа
	var ip := Panel.new()
	ip.position = Vector2(1226, 226)
	ip.size = Vector2(346, 560)
	ip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.9, 0.88, 0.83)
	isb.set_corner_radius_all(8)
	isb.border_width_left = 6
	isb.border_color = MLUI.RED
	ip.add_theme_stylebox_override("panel", isb)
	add_child(ip)
	info_head = ui.txt(ip, "", 24, MLUI.INK, Vector2(16, 12), ui.serif)
	info_head.size = Vector2(320, 0)
	info_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_head.add_theme_constant_override("outline_size", 0)
	info = ui.txt(ip, "", 14, Color(0.15, 0.15, 0.17), Vector2(16, 84))
	info.size = Vector2(320, 460)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_constant_override("outline_size", 0)
	syn_l = ui.txt(self, "", 13, MLUI.SILVER, Vector2(44, 796))
	syn_l.size = Vector2(1520, 80)
	syn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lg := Button.new()
	lg.text = "👑 ЛЕГЕНДА РАЙОНА"
	lg.position = Vector2(1226, 150)
	lg.size = Vector2(200, 40)
	lg.add_theme_font_override("font", ui.font)
	lg.pressed.connect(func(): ui.legend_screen())
	add_child(lg)
	var back := Button.new()
	back.text = "НАЗАД"
	back.position = Vector2(1440, 150)
	back.size = Vector2(132, 40)
	back.add_theme_font_override("font", ui.font)
	back.pressed.connect(func(): ui.show_phase())
	add_child(back)
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
	return Vector2(X0 + bi * COL_W + COL_W * 0.5 + float(n["col"]) * 70.0, Y0 + 34.0 + float(n["row"]) * ROW_H)

func _pick(id: String) -> void:
	if id != sel:
		ui.root.snd.play("tick")
	sel = id
	paint()

func paint() -> void:
	var C := career()
	head.text = "УРОВЕНЬ %d · опыт %d / %d · ОЧКОВ НАВЫКОВ: %d · неделя %d · АВТОРИТЕТ %d" % [int(C.d["level"]), int(C.d["xp"]), MLCareer.xp_need(int(C.d["level"])), int(C.d["points"]), int(C.d["week"]), int(C.d["legend"]["points"])]
	for id in widgets:
		var w: Dictionary = widgets[id]
		var n := MLTree.node(String(id))
		var col: Color = MLTree.BRANCHES[n["b"]]["col"]
		var r := C.rank(String(id))
		var why := C.why_not(String(id))
		var sb: StyleBoxFlat = w["sb"]
		if r > 0:
			sb.bg_color = col
			sb.border_color = col.lightened(0.4) if r >= int(n["max"]) else MLUI.WHITE
			(w["ic"] as Label).add_theme_color_override("font_color", MLUI.INK)
		elif why == "":
			sb.bg_color = Color(0.08, 0.08, 0.09)
			sb.border_color = col
			(w["ic"] as Label).add_theme_color_override("font_color", col)
		else:
			sb.bg_color = Color(0.07, 0.07, 0.08)
			sb.border_color = Color(0.25, 0.25, 0.27)
			(w["ic"] as Label).add_theme_color_override("font_color", Color(0.35, 0.35, 0.37))
		sb.set_border_width_all(6 if String(id) == sel else 3)
		(w["rank"] as Label).text = "%d/%d" % [r, int(n["max"])] if int(n["max"]) > 1 or r > 0 else ""
	for ln in lines.get_children():
		var l := ln as Line2D
		var on := C.rank(String(l.get_meta("from"))) > 0
		l.default_color = (MLTree.BRANCHES[MLTree.node(String(l.get_meta("to")))["b"]]["col"] as Color).darkened(0.1) if on else Color(0.28, 0.28, 0.3)
		l.width = 4.0 if on else 2.0
	# подробности
	var n := MLTree.node(sel)
	var r := C.rank(sel)
	var why := C.why_not(sel)
	info_head.text = "%s %s" % [{"stat": "+", "unlock": "◆", "ability": "⚡", "capstone": "★"}.get(String(n["kind"]), ""), n["name"]]
	var reqs: Array = (n["req"] as Array).map(func(q): return "%s %d" % [MLTree.node(String(q[0]))["name"], int(q[1])])
	var syns: Array = MLTree.SYNERGIES.filter(func(s): return (s["need"] as Array).any(func(nd): return String(nd[0]) == "node" and String(nd[1]) == sel)).map(func(s): return String(s["name"]))
	var kind_s: String = {"stat": "улучшение", "unlock": "открытие", "ability": "способность", "capstone": "вершина ветки"}.get(String(n["kind"]), "")
	info.text = "%s · %s\n\n%s\n\nРанг: %d / %d\nСейчас: %s\nПосле: %s\n\nЦена: %d очк. · уровень %d%s%s\n\n%s" % [
		MLTree.BRANCHES[n["b"]]["name"], kind_s, n["desc"], r, int(n["max"]), C.effect_text(sel), C.effect_text(sel, mini(r + 1, int(n["max"]))) if r < int(n["max"]) else "максимум",
		int(n["cost"]), int(n["lvl"]), ("\nНужно: " + ", ".join(reqs)) if not reqs.is_empty() else "", ("\nСинергии: " + ", ".join(syns)) if not syns.is_empty() else "",
		"МОЖНО ИЗУЧИТЬ — клик или Enter" if why == "" else "ПОКА НЕЛЬЗЯ: " + why]
	var on_s: Array = []
	for s in MLTree.SYNERGIES:
		on_s.append(("✔ " if C.synergy_on(s) else "· ") + "%s — %s" % [s["name"], s["desc"]])
	var ms: Array = MLTree.MILESTONES.filter(func(m): return not (C.d["ms"] as Dictionary).has(String(m["id"])))
	syn_l.text = "СИНЕРГИИ:  " + "   ".join(on_s) + ("\nСЛЕДУЮЩАЯ ВЕХА: %s (%d / %d)" % [ms[0]["name"], C.stat(String(ms[0]["stat"])), int(ms[0]["need"])] if not ms.is_empty() else "")

func buy() -> void:
	var C := career()
	if not C.buy_node(sel):
		ui.root.snd.play("fail")
		return
	ui.root.snd.play("buy")
	ui.econ().xp(0)
	var w: Dictionary = widgets[sel]
	var box: Panel = w["box"]
	box.scale = Vector2(1.5, 1.5)
	box.create_tween().tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 8:                                        # искры открытия
		var sp := ui.txt(self, "✦", 18, MLTree.BRANCHES[MLTree.node(sel)["b"]]["col"], box.position + box.size * 0.5)
		var a := TAU * k / 8.0
		var tw := sp.create_tween().set_parallel(true)
		tw.tween_property(sp, "position", sp.position + Vector2(cos(a), sin(a)) * 60.0, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(sp.queue_free)
	ui.root.biz_visuals()
	ui.econ().changed.emit()
	ui.root.save()
	paint()

func key(k: int) -> bool:
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

func _process(dt: float) -> void:
	t += dt
	var C := career()
	if C == null:
		return
	for id in widgets:
		var box: Panel = widgets[id]["box"]
		if C.rank(String(id)) == 0 and C.why_not(String(id)) == "" and box.scale.x < 1.2:
			box.scale = Vector2.ONE * (1.0 + 0.05 * sin(t * 5.0))      # можно изучить — пульсирует
