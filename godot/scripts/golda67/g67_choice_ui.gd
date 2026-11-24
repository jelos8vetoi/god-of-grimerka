class_name G67ChoiceUI
extends G67Diorama
## Окно выбора в событиях и конфликтах двора: мир виден (затемнение слабое), слева внизу — название, одна строка
## обстановки и бумажные полоски с вариантами. W/S и стрелки, Enter / пробел / E, мышь, крестовина и A геймпада.
## Esc / B — вариант «уйти» (leave), если он задан; иначе полоски вздрагивают: выбор обязателен.
## Вариант — [ключ, текст, пометка, доступен]. Результат — cb.call(ключ) после закрытия окна.

const SLIP := Vector2(860, 50)
const X0 := 96.0

var opts: Array = []
var cb: Callable
var leave := ""
var slips: Array = []

static func open(g67: Golda67, title: String, text: String, options: Array, on_pick: Callable, leave_key := ""):
	var u = load("res://scripts/golda67/g67_choice_ui.gd").new()
	u._open_base(g67, "choice")
	u.opts = options
	u.cb = on_pick
	u.leave = leave_key
	u._build(title, text)
	return u

func _build(title: String, text: String) -> void:
	shade.create_tween().tween_property(shade, "color:a", 0.5, 0.22)      # мир остаётся виден: выбор делается «на месте»
	var n := opts.size()
	var y0 := 860.0 - float(n) * (SLIP.y + 8.0)
	var back := Back.new()
	back.position = Vector2(X0 - 36.0, y0 - 128.0)
	back.size = Vector2(SLIP.x + 72.0, 900.0 - back.position.y)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(back)
	lab(title, "display", 38, Color(0.96, 0.9, 0.76), Vector2(X0, y0 - 112.0))
	lab(text, "ui", 19, Color(0.82, 0.78, 0.68), Vector2(X0 + 2.0, y0 - 58.0), SLIP.x)
	for k in n:
		var o: Array = opts[k]
		var s := Slip.new()
		s.position = Vector2(X0, y0 + float(k) * (SLIP.y + 8.0))
		s.size = SLIP
		s.pivot_offset = SLIP * 0.5
		s.seed_v = 31 + k * 7
		s.text = String(o[1])
		s.note = String(o[2]) if o.size() > 2 else ""
		s.enabled = bool(o[3]) if o.size() > 3 else true
		stage.add_child(s)
		slips.append(s)
		add_item(s, String(o[0]))
	select(0, true)

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(items[prev]["node"] as Slip).set_selected(false)
	(items[i]["node"] as Slip).set_selected(true)

func _activate(i: int) -> void:
	if i < 0 or mode != "list":
		return
	var s: Slip = items[i]["node"]
	if not s.enabled:
		G.game.main.ui("deny")
		s.wobble()
		return
	pick(String(items[i]["key"]))

## Выбрать вариант (его же зовут проверки)
func pick(key: String) -> void:
	if mode == "busy":
		return
	mode = "busy"
	G.game.main.ui("confirm")
	G.events.append(["choice", key])
	var f := cb
	close()
	if f.is_valid():
		f.call(key)

func _back() -> bool:
	if leave != "":
		pick(leave)
		return true
	G.game.main.ui("deny")
	for s in slips:
		(s as Slip).wobble()
	return true

## Тёмная подложка с красной полосой слева — текст читается на любом фоне двора
class Back extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.05, 0.78))
		draw_rect(Rect2(Vector2.ZERO, Vector2(6, size.y)), Color(0.74, 0.12, 0.12))

class Slip extends Control:
	var seed_v := 1
	var text := ""
	var note := ""
	var enabled := true
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "position:x", 110.0 if v else 96.0, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func wobble() -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation", 0.012, 0.05)
		tw.tween_property(self, "rotation", -0.01, 0.07)
		tw.tween_property(self, "rotation", 0.0, 0.05)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, seed_v, 1.6), Color(0.93, 0.9, 0.82) if enabled else Color(0.56, 0.54, 0.5))
		if selected:
			draw_rect(Rect2(Vector2.ZERO, Vector2(8, size.y)), Color(0.74, 0.12, 0.12))
			draw_rect(r.grow(3), Color(0.98, 0.8, 0.4), false, 2.5)
		var f := MGUI.font("ui_b")
		var sz := 21
		var room := size.x - 44.0 - (220.0 if note != "" else 0.0)
		while sz > 14 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > room:
			sz -= 1
		draw_string(f, Vector2(24, size.y * 0.5 + float(sz) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.12, 0.1, 0.08) if enabled else Color(0.3, 0.28, 0.26))
		if note != "":
			var fn := MGUI.font("caps")
			var w := fn.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(fn, Vector2(size.x - w - 18.0, size.y * 0.5 + 5.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.12, 0.1))
