class_name G67ResultUI
extends G67Diorama
## Итоги забега: «ПОБЕДА» / «ЗАБЕГ ОКОНЧЕН» (при первой победе над Мишей крупно «ГЛАВА 1 ПРОЙДЕНА»), этапы цепочкой значков,
## враги, голда, РЕСПЕКТ по источникам, бафы и артефакты, «ОТКРЫТО» (только реально открывшееся в этом забеге) и «ДАЛЬШЕ».
## Кнопки: «В ПОДЪЕЗД» и «НОВЫЙ ЗАБЕГ». Данные — Golda67.result (РЕСПЕКТ в сохранении уже записан). Esc ничего не закрывает.

const PARTS := {"battle": "бои", "elite": "элита", "calm": "мирные этапы", "boss": "босс"}
var btns: Array = []
var texts: Array = []            # все надписи — для проверки вёрстки

static func open(g67: Golda67):
	var u = load("res://scripts/golda67/g67_result_ui.gd").new()
	u._open_base(g67, "result")
	u._build()
	return u

func _t(text: String, font: String, sz: int, col: Color, pos: Vector2, w := 0.0) -> Label:
	var l := lab(text, font, sz, col, pos, w)
	texts.append(l)
	return l

func _build() -> void:
	var R: Dictionary = G.result
	var won := bool(R.get("won", false))
	var first := bool(R.get("first", false))
	var bg := Back.new()
	bg.size = STAGE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	var pz := String(R.get("district", "dvor")) == "podzemka"
	_t(("ПОДЗЕМКА" if pz else "ДВОР") + " · ИТОГИ ЗАБЕГА", "caps", 13, Color(0.72, 0.68, 0.6), Vector2(70, 52))
	_t("ПОБЕДА" if won else "ЗАБЕГ ОКОНЧЕН", "display", 64, Color(0.95, 0.82, 0.35) if won else Color(0.9, 0.34, 0.28), Vector2(66, 68))
	var y := 150.0
	if first:
		_t("ПОДЗЕМКА ПРОЙДЕНА" if pz else "ГЛАВА 1 ПРОЙДЕНА", "display", 54, Color(1.0, 0.86, 0.4), Vector2(66, y))
		y += 76.0
	var col := Color(0.88, 0.85, 0.78)
	var dim := Color(0.7, 0.66, 0.58)
	_t("ЭТАПЫ: %d из 6" % int(R.get("stage_n", 0)), "display", 28, col, Vector2(70, y))
	var stages: Array = R.get("stages", [])
	for i in stages.size():
		var ic := G67Icons.rect(String(G67Icons.ROOM.get(String(stages[i][0]), "icon_room_battle")), 40)
		if ic != null:
			ic.position = Vector2(70 + i * 48, y + 40)
			stage.add_child(ic)
	var died: Array = R.get("died_at", [])
	if not died.is_empty() and String(died[0]) != "":
		var di := G67Icons.rect(String(G67Icons.ROOM.get(String(died[0]), "icon_room_battle")), 40)
		if di != null:
			di.position = Vector2(70 + stages.size() * 48, y + 40)
			di.modulate = Color(1, 1, 1, 0.35)      # этап, на котором погиб, — приглушённый значок
			stage.add_child(di)
	y += 96.0
	_t("ВРАГОВ ПОБЕЖДЕНО: %d" % int(R.get("kills", 0)), "display", 28, col, Vector2(70, y))
	y += 46.0
	_t("ГОЛДА: получено %d · потрачено %d · сгорело %d" % [int(R.get("earned", 0)), int(R.get("spent", 0)), int(R.get("left", 0))], "display", 28, col, Vector2(70, y), 760)
	y += 46.0
	_t("РЕСПЕКТ: +%d" % int(R.get("got", 0)), "display", 34, Color(1.0, 0.86, 0.4), Vector2(70, y))
	y += 46.0
	var pp: Array = []
	for k in PARTS:
		if int((R.get("parts", {}) as Dictionary).get(k, 0)) > 0:
			pp.append("%s %d" % [PARTS[k], int(R["parts"][k])])
	_t(" · ".join(pp) + ("   ВСЕГО: %d" % int(R.get("total", 0))) if not pp.is_empty() else "ВСЕГО: %d" % int(R.get("total", 0)), "ui", 20, dim, Vector2(70, y), 760)
	y += 44.0
	var fl: Array = []
	for id in (R.get("fits", {}) as Dictionary):
		fl.append("%s ур. %d" % [String(G67Data.FITS[id]["name"]), int(R["fits"][id])])
	_t("БАФЫ: " + (", ".join(fl) if not fl.is_empty() else "не брал"), "ui", 20, col, Vector2(70, y), 760)
	y += 62.0
	var al: Array = (R.get("arts", []) as Array).map(func(id): return String(Golda67.art_info(id)["name"]))
	_t("АРТЕФАКТЫ: " + (", ".join(al) if not al.is_empty() else "не брал"), "ui", 20, col, Vector2(70, y), 760)
	# правая колонка
	_t("ОТКРЫТО", "display", 30, Color(0.95, 0.82, 0.35), Vector2(900, 150))
	var nw: Array = R.get("new", [])
	var ny := 196.0
	if nw.is_empty():
		_t("В этом забеге ничего нового.", "ui", 20, dim, Vector2(900, ny), 640)
		ny += 40.0
	for line in nw:
		var l := _t("• " + String(line), "ui", 20, col, Vector2(900, ny), 640)
		ny += maxf(34.0, float(l.get_line_count()) * 28.0 + 6.0)
	ny = maxf(ny + 24.0, 520.0)
	_t("ДАЛЬШЕ", "display", 30, Color(0.95, 0.82, 0.35), Vector2(900, ny))
	_t(_next_text(R), "ui", 20, col, Vector2(900, ny + 46.0), 640)
	for k in 2:
		var b := Btn.new()
		b.text = "В ПОДЪЕЗД" if k == 0 else "НОВЫЙ ЗАБЕГ"
		b.position = Vector2(900 + k * 330, 800)
		b.size = Vector2(300, 70)
		b.pivot_offset = b.size * 0.5
		stage.add_child(b)
		btns.append(b)
		add_item(b, "hub" if k == 0 else "new")
	select(0, true)

func _next_text(R: Dictionary) -> String:
	if bool(R.get("first", false)):
		return "ДВОР пройден. Следующий район турнира — ПОДЗЕМКА — в следующей главе. Двор можно проходить снова: маршрут каждый раз другой, РЕСПЕКТ идёт в «АВТОРИТЕТ РАЙОНА»."
	for u in G67Data.UPGRADES:
		if bool(u["live"]) and G.up(String(u["id"])) < int(u["max"]) and G.up_cost(String(u["id"])) <= int(R.get("total", 0)):
			return "Хватает на улучшение в «АВТОРИТЕТЕ РАЙОНА»."
	if bool(R.get("boss_death", false)):
		return "Миша открыт после промаха ЗАХВАТА и когда цепь зацепилась."
	return "Маршрут следующего забега другой — карта у входа."

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		btns[prev].call("set_selected", false)
	btns[i].call("set_selected", true)

func _activate(i: int) -> void:
	if i < 0 or mode != "list":
		return
	mode = "busy"
	G.game.main.ui("confirm")
	if String(items[i]["key"]) == "hub":
		G.result_to_hub()
	else:
		G.result_new_run()

func _back() -> bool:
	G.game.main.ui("deny")
	return true

class Back extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(Vector2(40, 40), Vector2(1520, 820)), Color(0.14, 0.14, 0.16))
		draw_rect(Rect2(Vector2(40, 40), Vector2(1520, 820)), Color(0.5, 0.46, 0.38, 0.5), false, 2.0)
		draw_line(Vector2(860, 150), Vector2(860, 780), Color(0.5, 0.46, 0.38, 0.4), 2.0)

class Btn extends Control:
	var text := ""
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, 13, 2.0), Color(0.62, 0.48, 0.3))
		var f := MGUI.font("display")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(f, Vector2((size.x - w) * 0.5, 46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.16, 0.1, 0.05))
		if selected:
			draw_rect(r.grow(3), Color(0.98, 0.8, 0.4), false, 3.0)
