class_name G67StylesUI
extends G67Diorama
## Стойка стилей: гаражная перфорированная доска на стене площадки, у каждого стиля — своё место с нарисованным
## краской контуром и настоящей моделью оружия (та же сборка, что в боевом HUD: combat_hud._model). Ряд ПАХАН —
## Балон VOZDUH, Водяра, ТЯГА-812; ряд MADK1D — Скейтборд, Электрогитара, Breaker. Открыт ли стиль — как в игре
## (Golda67.styles_open; madk1d — madk_open). Закрытое — тёмный силуэт, цепь и замок, условие. Enter — взять стиль
## в забег (Golda67.set_start_style), на месте — бирка «В РУКАХ». Справа — картонная бирка выбранного стиля.

const PAHAN := ["vozduh", "bottles", "tyaga812"]
const MADK := ["skateboard", "guitar", "breaker"]
const WHEN := {"bottles": "после победы над Мишей Минасяном", "tyaga812": "после победы над FORTUNA 812",
	"skateboard": "после первой концовки", "guitar": "после первой концовки", "breaker": "после первой концовки"}
const SLOT := Vector2(300, 270)

var slots: Array = []
var tag: Control
var t_owner: Label
var t_name: Label
var t_state: Label
var t_note: Label
var t_why: Label
var t_btn: Button
var t := 0.0

static func open(g67: Golda67) -> G67StylesUI:
	var u := G67StylesUI.new()
	u._open_base(g67, "styles")
	u._build()
	return u

func _build() -> void:
	var wall := Pegboard.new()
	wall.size = STAGE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(wall)
	lab("ПОДЪЕЗД · ПЛОЩАДКА · ПРАВАЯ СТЕНА", "caps", 13, Color(0.7, 0.66, 0.56), Vector2(70, 30))
	lab("СТОЙКА СТИЛЕЙ", "display", 48, Color(0.92, 0.88, 0.76), Vector2(66, 46))
	var open: Array = G.styles_open()
	var madk := G.madk_open()
	var cur := G.start_style()
	for row in 2:
		var ids: Array = PAHAN if row == 0 else MADK
		for k in 3:
			var sid := String(ids[k])
			var s := Slot.new()
			s.sid = sid
			s.style = Styles.by_id(sid)
			s.hero = "ПАХАН" if row == 0 else "MADK1D"
			s.open = (open.has(sid) if row == 0 else madk)
			s.held = sid == cur and row == 0
			s.why = "" if s.open else "Откроется " + String(WHEN.get(sid, "позже")) + "."
			s.position = Vector2(110 + k * 330, 176 + row * 336)
			s.size = SLOT
			s.pivot_offset = SLOT * 0.5
			stage.add_child(s)
			s.setup(G)
			slots.append(s)
			add_item(s, sid)
	_build_tag()
	select(maxi(0, PAHAN.find(cur)), true)

func _build_tag() -> void:
	tag = Tag.new()
	tag.ui = self
	tag.position = Vector2(1150, 150)
	tag.size = Vector2(400, 660)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tag)
	var x := 1182.0
	t_owner = lab("", "caps", 14, Color(0.45, 0.12, 0.1), Vector2(x, 250))
	t_name = lab("", "display", 34, Color(0.12, 0.1, 0.08), Vector2(x, 272), 340)
	t_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	t_state = lab("", "caps", 15, Color(0.12, 0.1, 0.08), Vector2(x, 372))
	t_note = lab("", "ui", 17, Color(0.22, 0.19, 0.15), Vector2(x, 414), 340)
	t_why = lab("", "ui_b", 16, Color(0.5, 0.12, 0.1), Vector2(x, 600), 340)
	t_btn = Button.new()
	t_btn.position = Vector2(x, 700)
	t_btn.size = Vector2(336, 58)
	t_btn.focus_mode = Control.FOCUS_NONE
	t_btn.add_theme_font_override("font", MGUI.font("caps"))
	t_btn.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.11, 0.09) if st != "hover" else Color(0.3, 0.1, 0.08)
		if st == "disabled":
			sb.bg_color = Color(0.14, 0.11, 0.09, 0.2)
		sb.border_color = Color(0.85, 0.62, 0.3) if st != "disabled" else Color(0.3, 0.26, 0.2, 0.4)
		sb.set_border_width_all(2)
		t_btn.add_theme_stylebox_override(st, sb)
	t_btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
	t_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.26, 0.2, 0.8))
	t_btn.pressed.connect(func():
		if mode == "list":
			_activate(sel))
	stage.add_child(t_btn)

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(slots[prev] as Slot).set_selected(false)
	var s: Slot = slots[i]
	s.set_selected(true)
	t_owner.text = "СТИЛЬ · " + s.hero
	t_name.text = s.style.title
	t_note.text = (s.style.note.substr(0, 1).to_upper() + s.style.note.substr(1) + ".") if s.style.note != "" else ""
	t_why.text = s.why
	if not s.open:
		t_state.text = "ЗАКРЫТО"
		t_btn.text = "ЗАКРЫТО"
		t_btn.disabled = true
	elif s.held:
		t_state.text = "В РУКАХ В НАЧАЛЕ ЗАБЕГА"
		t_btn.text = "УЖЕ В РУКАХ"
		t_btn.disabled = true
	elif s.hero == "MADK1D":
		t_state.text = "СТИЛЬ MADK1D"
		t_btn.text = "ОТКРЫТ"
		t_btn.disabled = true
	else:
		t_state.text = "ВИСИТ НА СТОЙКЕ"
		t_btn.text = "ВЗЯТЬ В ЗАБЕГ"
		t_btn.disabled = false
	tag.queue_redraw()

func _activate(i: int) -> void:
	if i < 0:
		return
	var s: Slot = slots[i]
	if not s.open or s.hero != "ПАХАН" or s.held:
		G.game.main.ui("deny")
		s.shake()
		return
	G.set_start_style(s.sid)
	G.game.main.ui("value", 0.9)
	for o in slots:
		(o as Slot).held = (o as Slot).sid == s.sid
		(o as Slot).queue_redraw()
		(o as Slot).ov.queue_redraw()
	s.taken()
	var keep := sel
	sel = -1
	select(keep, true)

func _process(dt: float) -> void:
	t += dt
	for o in slots:
		(o as Slot).spin(dt)

# ---------------------------------------------------------------- рисунки
## Перфорированная доска: краска, отверстия, полосы малярного скотча с именами героев
class Pegboard extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.28))
		var b := Rect2(Vector2(60, 120), Vector2(1050, 730))
		draw_rect(Rect2(b.position + Vector2(8, 10), b.size), Color(0, 0, 0, 0.45))
		draw_rect(b, Color(0.52, 0.42, 0.3))
		for y in range(int(b.position.y) + 14, int(b.end.y) - 6, 22):
			for x in range(int(b.position.x) + 14, int(b.end.x) - 6, 22):
				draw_circle(Vector2(x, y), 2.4, Color(0.2, 0.15, 0.1))
		draw_rect(b, Color(0.3, 0.22, 0.14), false, 4.0)
		var f := MGUI.font("caps")
		for row in 2:
			var y := 130.0 + row * 336.0
			draw_set_transform(Vector2(96, y), -0.02, Vector2.ONE)
			draw_rect(Rect2(Vector2.ZERO, Vector2(140, 24)), Color(0.9, 0.86, 0.66, 0.9))
			draw_string(f, Vector2(12, 18), "ПАХАН" if row == 0 else "MADK1D", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.15, 0.12, 0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Место стиля: контур краской, крючки, модель (своя маленькая сцена), бирка «В РУКАХ», замок и цепь
class Slot extends Control:
	var sid := ""
	var style: StyleData
	var hero := ""
	var open := false
	var held := false
	var why := ""
	var selected := false
	var vp: SubViewport
	var holder: Node3D
	var pic: TextureRect
	var ov: Control
	var warm := 0
	var ang := 0.0
	func setup(g: Golda67) -> void:
		vp = SubViewport.new()
		vp.size = Vector2i(320, 320)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.9, 0.86, 0.8)
		env.ambient_light_energy = 0.55
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.6, 0.5, 0)
		sun.light_energy = 1.2
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1.25
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, 0.4, 3.0), Vector3.ZERO)
		holder = Node3D.new()
		vp.add_child(holder)
		var hud = g.game.combat_hud
		match sid:
			"vozduh":
				var b: Node3D = hud._model("res://assets/models/balon.glb", 1.2)
				b.rotation = Vector3(0, 0, -0.6)
				holder.add_child(b)
			"bottles":
				for i in 2:
					var bt: Node3D = hud._model(Bottles.MODEL, 1.0)
					bt.position = Vector3(-0.22 + i * 0.44, 0.04 - i * 0.08, 0.1 - i * 0.2)
					bt.rotation = Vector3(0, i * 1.2, -0.22 + i * 0.4)
					holder.add_child(bt)
			"tyaga812":
				holder.add_child(hud._model(Tyaga.MODEL, 1.2))
			"skateboard", "guitar":
				var w: Node3D = hud._model(String(style.weapon["path"]), 1.25, true)
				w.rotation = Vector3(0, 0, 0.75) if sid == "guitar" else Vector3(0.45, 0, 0.3)
				holder.add_child(w)
			"breaker":
				var r := Rig.new()
				holder.add_child(r)
				r.setup("res://assets/models/madk1d.glb", 1.05, Poses.madk1d(), false, 1.0, "pause_madk1d")
				r.position = Vector3(0, -0.45, 0)
				r.play("FreezePose", 0.0)
		pic = TextureRect.new()
		pic.texture = vp.get_texture()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # сначала режим, потом размер — иначе размер упрётся в кадр сценки
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(30, 34)
		pic.size = Vector2(240, 196)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			pic.modulate = Color(0.06, 0.05, 0.05, 0.85)      # закрытое — тёмный силуэт на доске
		add_child(pic)
		ov = Over.new()
		ov.s = self
		ov.size = size
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ov)
		warm = 120 if sid == "breaker" else 20
	func spin(dt: float) -> void:
		if vp == null:
			return
		if selected and open:
			ang += dt * 0.7
			holder.rotation.y = sin(ang) * 0.6
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif warm > 0:
			warm -= 1
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.04 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func shake() -> void:
		var x0 := position.x
		var tw := create_tween()
		for k in 4:
			tw.tween_property(self, "position:x", x0 + (5.0 if k % 2 == 0 else -5.0), 0.035)
		tw.tween_property(self, "position:x", x0, 0.035)
	func taken() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 1.1, 0.07)
		tw.tween_property(self, "scale", Vector2.ONE * 1.04, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# контур места краской (как силуэт инструмента в гараже)
		var col := Color(0.95, 0.92, 0.84, 0.55) if open else Color(0.15, 0.12, 0.1, 0.7)
		draw_rect(r.grow(-6), Color(0, 0, 0, 0.08))
		draw_dashed_line(Vector2(6, 6), Vector2(size.x - 6, 6), col, 3.0, 12.0)
		draw_dashed_line(Vector2(6, size.y - 6), Vector2(size.x - 6, size.y - 6), col, 3.0, 12.0)
		draw_dashed_line(Vector2(6, 6), Vector2(6, size.y - 6), col, 3.0, 12.0)
		draw_dashed_line(Vector2(size.x - 6, 6), Vector2(size.x - 6, size.y - 6), col, 3.0, 12.0)
		# два крючка
		for x in [size.x * 0.32, size.x * 0.68]:
			draw_line(Vector2(x, 20), Vector2(x, 40), Color(0.72, 0.72, 0.74), 4.0)
			draw_arc(Vector2(x + 6, 40), 6.0, 0, PI, 8, Color(0.72, 0.72, 0.74), 4.0)
		if selected:
			draw_rect(r.grow(4), Color(0.98, 0.78, 0.42, 0.95), false, 3.0)

## Поверх модели: подпись краской, бирка «В РУКАХ», цепь и замок у закрытого
class Over extends Control:
	var s: Slot
	func _draw() -> void:
		var f := MGUI.font("caps")
		var name := s.style.title
		var sz := 18
		while sz > 12 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > size.x - 30:
			sz -= 1
		draw_string(f, Vector2(16, size.y - 16), name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.97, 0.93, 0.82) if s.open else Color(0.2, 0.16, 0.12))
		if s.held:
			draw_set_transform(Vector2(size.x - 120, 26), 0.08, Vector2.ONE)
			draw_rect(Rect2(Vector2.ZERO, Vector2(104, 26)), Color(0.86, 0.3, 0.2))
			draw_string(f, Vector2(10, 18), "В РУКАХ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.88))
			draw_line(Vector2(0, 13), Vector2(-18, -10), Color(0.85, 0.82, 0.74), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not s.open:
			var c := Vector2(size.x * 0.5, size.y * 0.5)
			G67Diorama.draw_chain(self, Vector2(10, 40), c, 1.0, Color(0.62, 0.6, 0.55))
			G67Diorama.draw_chain(self, c, Vector2(size.x - 10, 40), 1.0, Color(0.62, 0.6, 0.55))
			G67Diorama.draw_padlock(self, c + Vector2(0, 8), 1.7, Color(0.66, 0.58, 0.38))

## Картонная бирка на верёвке
class Tag extends Control:
	var ui
	func _draw() -> void:
		var r := Rect2(Vector2(0, 40), size - Vector2(0, 40))
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 64), Color(0.75, 0.7, 0.6), 2.0)
		var pts := PackedVector2Array([Vector2(r.position.x + 40, r.position.y), Vector2(r.end.x - 40, r.position.y), r.position + Vector2(r.size.x, 40),
			r.end, Vector2(r.position.x, r.end.y), r.position + Vector2(0, 40)])
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(6, 8))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
		draw_colored_polygon(pts, Color(0.78, 0.66, 0.46))
		draw_circle(Vector2(size.x * 0.5, r.position.y + 26), 10, Color(0.4, 0.33, 0.24))
		draw_circle(Vector2(size.x * 0.5, r.position.y + 26), 6, Color(0.2, 0.18, 0.16))
		for y in [r.position.y + 180.0, r.position.y + 224.0]:
			draw_line(Vector2(30, y), Vector2(size.x - 30, y), Color(0.3, 0.22, 0.14, 0.3), 1.0)
