class_name G67ArchTV
extends Control
## Телевизор стены «АРХИВА ПИЗДЕЦА»: корпус одной из шести моделей (рисунок кодом), экран со стоп-кадром ролика
## под шейдером кинескопа, ярлык записи, лента категории, лампочка и состояние: new (горит, «НОВОЕ», мигает зелёная
## лампочка), seen («ПРОСМОТРЕНО»), lock (цепь, навесной замок, помехи — кадр не раскрывается), open (анимация
## открытия: цепь падает, экран включается, «ОТКРЫТО»).

const SCREEN_SHADER := """
shader_type canvas_item;
uniform float power = 1.0;
uniform float bright = 0.8;
uniform float locked = 0.0;
uniform float ghost = 0.0;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	float r2 = dot(uv, uv);
	uv *= 1.0 + 0.14 * r2;
	vec2 q = uv + 0.5;
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) {
		COLOR = vec4(0.015, 0.015, 0.015, 1.0);
	} else {
		float ca = 0.0022;
		vec3 c = vec3(texture(TEXTURE, q + vec2(ca, 0.0)).r, texture(TEXTURE, q).g, texture(TEXTURE, q - vec2(ca, 0.0)).b);
		c *= 0.88 + 0.12 * sin(q.y * 620.0);
		c += (h(floor(q * vec2(300.0, 220.0)) + floor(TIME * 24.0)) - 0.5) * 0.045;
		float st = h(floor(q * vec2(150.0, 110.0)) + floor(TIME * 18.0));
		vec3 noise = vec3(st) * 0.3 + vec3(0.02);
		c = mix(c, noise + c * ghost, locked);
		float open = clamp(power, 0.0, 1.0);
		float band = step(abs(q.y - 0.5), 0.5 * open * open + 0.006);
		c = c * band * (0.35 + 0.65 * open) + vec3(0.9) * (1.0 - open) * step(abs(q.y - 0.5), 0.006) * step(0.05, open);
		c *= bright;
		c *= 1.0 - r2 * 1.5;
		COLOR = vec4(c, 1.0);
	}
}
"""

## модель → [экран: x, y, w, h доли корпуса], верх корпуса (под ручку / антенну), цвет корпуса
const MODELS := {
	"wood": {"scr": [0.07, 0.11, 0.62, 0.68], "top": 0.0, "col": Color(0.36, 0.22, 0.12)},
	"black": {"scr": [0.1, 0.08, 0.8, 0.66], "top": 0.0, "col": Color(0.08, 0.08, 0.085)},
	"portable": {"scr": [0.08, 0.13, 0.6, 0.66], "top": 0.17, "col": Color(0.82, 0.76, 0.6)},
	"silver": {"scr": [0.21, 0.12, 0.58, 0.62], "top": 0.0, "col": Color(0.62, 0.63, 0.65)},
	"monitor": {"scr": [0.18, 0.1, 0.64, 0.6], "top": 0.0, "col": Color(0.4, 0.41, 0.4)},
	"bulge": {"scr": [0.08, 0.12, 0.64, 0.7], "top": 0.13, "col": Color(0.2, 0.14, 0.1)},
}
const CAT_COL := {"РЕКЛАМА": Color(0.78, 0.2, 0.16), "ОБЛАКО LIVE": Color(0.86, 0.3, 0.42), "НОВОСТИ": Color(0.85, 0.82, 0.72),
	"СЮЖЕТ": Color(0.85, 0.66, 0.3), "СОБЫТИЯ": Color(0.4, 0.62, 0.42), "КОНЦОВКИ": Color(0.5, 0.52, 0.6)}

static var _glow: GradientTexture2D
static var _blank: ImageTexture

var rec: Dictionary = {}      # {id, title, cat, no, state, preview}
var model := "black"
var state := "lock"
var selected := false
var scr: TextureRect
var mat: ShaderMaterial
var over: Control
var t := 0.0
var chain_k := 1.0            # 1 — цепь на месте, 0 — упала
var opened_t := 0.0           # сколько ещё показывать «ОТКРЫТО»
var power := 0.0

func setup(r: Dictionary, mdl: String) -> void:
	rec = r
	model = mdl
	state = String(r["state"])
	pivot_offset = size * 0.5
	if _glow == null:
		_glow = GradientTexture2D.new()
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		_glow.gradient = gr
		var im := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
		im.fill(Color(0.3, 0.3, 0.3))
		_blank = ImageTexture.create_from_image(im)
	var sr := screen_rect()
	scr = TextureRect.new()
	scr.position = sr.position
	scr.size = sr.size
	scr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pth := String(r.get("preview", ""))
	scr.texture = load(pth) if pth != "" and ResourceLoader.exists(pth) else _blank
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	mat.shader = sh
	mat.set_shader_parameter("seed", float(int(r.get("no", 1))) * 1.7)
	scr.material = mat
	add_child(scr)
	over = Over.new()
	over.tv = self
	over.size = size
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)
	chain_k = 1.0 if state == "lock" else 0.0
	power = 0.0
	_apply()

func screen_rect() -> Rect2:
	var m: Dictionary = MODELS[model]
	var top := float(m["top"]) * size.y
	var bh := size.y - top
	var s: Array = m["scr"]
	return Rect2(Vector2(size.x * float(s[0]), top + bh * float(s[1])), Vector2(size.x * float(s[2]), bh * float(s[3])))

func body_rect() -> Rect2:
	var top := float(MODELS[model]["top"]) * size.y
	return Rect2(Vector2(0, top), Vector2(size.x, size.y - top))

func _apply() -> void:
	var lockv := 1.0 if state == "lock" and chain_k > 0.5 else 0.0
	mat.set_shader_parameter("locked", lockv)
	mat.set_shader_parameter("ghost", 0.07 if rec.get("preview", "") != "" else 0.0)
	mat.set_shader_parameter("power", power)
	mat.set_shader_parameter("bright", (1.05 if selected else 0.78) * (0.55 if lockv > 0.5 else 1.0))

## включить экран (при открытии архива — по очереди, с короткими помехами)
func power_on(delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		power = v
		_apply(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## новая разблокировка: цепь падает, экран включается, «ОТКРЫТО», лампочка вспыхивает
func unlock_anim() -> void:
	state = "lock"
	chain_k = 1.0
	power = 1.0
	_apply()
	var tw := create_tween()
	tw.tween_method(func(v: float):
		chain_k = v
		over.queue_redraw(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		state = String(rec["state"])
		opened_t = 2.2
		power = 0.0
		_apply())
	tw.tween_method(func(v: float):
		power = v
		_apply(), 0.0, 1.0, 0.3)

func set_selected(v: bool) -> void:
	if selected == v:
		return
	selected = v
	z_index = 2 if v else 0
	_apply()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * (1.05 if v else 1.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()
	over.queue_redraw()

func _process(dt: float) -> void:
	t += dt
	opened_t = maxf(0.0, opened_t - dt)
	if state == "new" or selected or opened_t > 0.0 or chain_k > 0.0:
		over.queue_redraw()

# ---------------------------------------------------------------- корпус
func _draw() -> void:
	var b := body_rect()
	var sr := screen_rect()
	var m: Dictionary = MODELS[model]
	var col: Color = m["col"]
	var lock := state == "lock" and chain_k > 0.5
	# свечение экрана на стену
	if not lock:
		var gc := Color(1.0, 0.82, 0.55, 0.22 if selected else 0.12)
		draw_texture_rect(_glow, Rect2(sr.get_center() - sr.size * 1.3, sr.size * 2.6), false, gc)
	# тень
	draw_rect(Rect2(b.position + Vector2(6, 8), b.size), Color(0, 0, 0, 0.55))
	match model:
		"wood":
			draw_rect(b, col)
			for k in 9:                                   # шпон: волокна
				var y := b.position.y + b.size.y * (0.08 + k * 0.1)
				draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y + 3.0 * sin(k)), Color(0.24, 0.14, 0.07, 0.6), 1.0)
			draw_rect(Rect2(sr.position - Vector2(6, 6), sr.size + Vector2(12, 12)), Color(0.12, 0.08, 0.05))
			var px := b.size.x * 0.73
			draw_rect(Rect2(Vector2(px, b.position.y + b.size.y * 0.08), Vector2(b.size.x * 0.22, b.size.y * 0.74)), Color(0.15, 0.1, 0.06))
			for k in 2:
				var kc := Vector2(px + b.size.x * 0.11, b.position.y + b.size.y * (0.2 + k * 0.17))
				draw_circle(kc, b.size.x * 0.05, Color(0.75, 0.74, 0.7))
				draw_circle(kc, b.size.x * 0.03, Color(0.55, 0.54, 0.5))
			for k in 6:                                   # клавиши каналов
				draw_rect(Rect2(Vector2(px + b.size.x * (0.03 + (k % 2) * 0.09), b.position.y + b.size.y * (0.52 + (k / 2) * 0.07)), Vector2(b.size.x * 0.07, b.size.y * 0.045)), Color(0.86, 0.82, 0.7))
			draw_rect(Rect2(Vector2(b.position.x + b.size.x * 0.1, b.end.y), Vector2(b.size.x * 0.08, 5)), Color(0.1, 0.07, 0.05))
			draw_rect(Rect2(Vector2(b.end.x - b.size.x * 0.18, b.end.y), Vector2(b.size.x * 0.08, 5)), Color(0.1, 0.07, 0.05))
		"black":
			draw_rect(b, col)
			draw_rect(b, Color(0.2, 0.2, 0.21), false, 1.5)
			draw_rect(Rect2(sr.position - Vector2(8, 8), sr.size + Vector2(16, 16)), Color(0.04, 0.04, 0.045))
			var sy := b.position.y + b.size.y * 0.82
			for k in 14:                                  # решётка динамика
				draw_line(Vector2(b.size.x * 0.1, sy + k * 2.2), Vector2(b.size.x * 0.55, sy + k * 2.2), Color(0.16, 0.16, 0.17), 1.0)
			draw_line(Vector2(b.size.x * 0.1, b.end.y - 5), Vector2(b.size.x * 0.9, b.end.y - 5), Color(0.55, 0.55, 0.57), 1.0)
		"portable":
			draw_arc(Vector2(size.x * 0.4, b.position.y + 2), b.size.x * 0.22, PI, TAU, 18, Color(0.7, 0.7, 0.72), 4.0)      # ручка
			draw_line(Vector2(size.x * 0.62, b.position.y), Vector2(size.x * 0.4, 0), Color(0.68, 0.68, 0.7), 2.0)            # антенна-усы
			draw_line(Vector2(size.x * 0.64, b.position.y), Vector2(size.x * 0.92, 2), Color(0.68, 0.68, 0.7), 2.0)
			draw_rect(b, col)
			draw_rect(Rect2(b.position + Vector2(b.size.x * 0.03, b.size.y * 0.05), Vector2(b.size.x * 0.7, b.size.y * 0.88)), Color(0.18, 0.17, 0.16))
			for k in 3:
				draw_circle(Vector2(b.size.x * 0.84, b.position.y + b.size.y * (0.2 + k * 0.2)), b.size.x * 0.045, Color(0.12, 0.12, 0.12))
			for k in 5:
				draw_line(Vector2(b.size.x * 0.77, b.position.y + b.size.y * (0.78 + k * 0.035)), Vector2(b.size.x * 0.92, b.position.y + b.size.y * (0.78 + k * 0.035)), Color(0.5, 0.46, 0.38), 1.0)
		"silver":
			draw_rect(b, col)
			draw_rect(b, Color(0.78, 0.79, 0.8), false, 1.5)
			for x in [0.1, 0.9]:                          # овальные динамики по бокам
				var cc := Vector2(b.size.x * x, b.position.y + b.size.y * 0.42)
				draw_set_transform(cc, 0.0, Vector2(0.55, 1.0))
				draw_circle(Vector2.ZERO, b.size.x * 0.1, Color(0.3, 0.31, 0.32))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(sr.position - Vector2(10, 10), sr.size + Vector2(20, 20)), Color(0.24, 0.25, 0.26))
			for k in 5:
				draw_rect(Rect2(Vector2(b.size.x * (0.34 + k * 0.07), b.position.y + b.size.y * 0.86), Vector2(b.size.x * 0.05, 5)), Color(0.82, 0.83, 0.84))
		"monitor":
			for x in [0.0, 0.94]:                         # уши стойки
				draw_rect(Rect2(Vector2(b.size.x * x, b.position.y + b.size.y * 0.1), Vector2(b.size.x * 0.06, b.size.y * 0.5)), Color(0.32, 0.33, 0.32))
				draw_circle(Vector2(b.size.x * (x + 0.03), b.position.y + b.size.y * 0.2), 3.0, Color(0.12, 0.12, 0.12))
			var mb := Rect2(Vector2(b.size.x * 0.06, b.position.y), Vector2(b.size.x * 0.88, b.size.y))
			draw_rect(mb, col)
			for k in range(0, int(mb.size.x), 6):          # молотковая краска
				draw_line(Vector2(mb.position.x + k, mb.position.y), Vector2(mb.position.x + k, mb.end.y), Color(0.36, 0.37, 0.36, 0.4), 1.0)
			draw_rect(Rect2(sr.position - Vector2(10, 10), sr.size + Vector2(20, 20)), Color(0.06, 0.06, 0.06))
			for k in 4:
				draw_circle(Vector2(b.size.x * (0.26 + k * 0.12), b.position.y + b.size.y * 0.84), b.size.x * 0.03, Color(0.08, 0.08, 0.08))
		"bulge":
			draw_line(Vector2(size.x * 0.5, b.position.y), Vector2(size.x * 0.3, 0), Color(0.55, 0.55, 0.57), 2.0)              # антенна,
			draw_line(Vector2(size.x * 0.52, b.position.y), Vector2(size.x * 0.66, size.y * 0.06), Color(0.55, 0.55, 0.57), 2.0)
			draw_line(Vector2(size.x * 0.66, size.y * 0.06), Vector2(size.x * 0.78, size.y * 0.09), Color(0.55, 0.55, 0.57), 2.0)  # погнутая
			draw_rect(b, col)
			draw_rect(Rect2(sr.position - Vector2(7, 7), sr.size + Vector2(14, 14)), Color(0.08, 0.06, 0.05))
			var dc := Vector2(b.size.x * 0.86, b.position.y + b.size.y * 0.32)
			draw_circle(dc, b.size.x * 0.07, Color(0.7, 0.68, 0.6))
			draw_line(dc, dc + Vector2(0, -b.size.x * 0.06), Color(0.2, 0.18, 0.15), 2.0)
	# потёртости: царапины на корпусе
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rec.get("no", 1)) * 13
	for k in 4:
		var p := Vector2(rng.randf_range(b.position.x + 8, b.end.x - 30), rng.randf_range(b.position.y + 6, b.end.y - 8))
		draw_line(p, p + Vector2(rng.randf_range(8, 22), rng.randf_range(-2, 2)), Color(1, 1, 1, 0.05), 1.0)

## Поверх экрана: блик стекла, ярлык, лента категории, лампочка, состояние
class Over extends Control:
	var tv: G67ArchTV
	func _draw() -> void:
		var sr := tv.screen_rect()
		var b := tv.body_rect()
		var st := tv.state
		var lock := st == "lock" and tv.chain_k > 0.0
		# блик выпуклого стекла
		draw_colored_polygon(PackedVector2Array([sr.position + Vector2(sr.size.x * 0.08, sr.size.y * 0.06), sr.position + Vector2(sr.size.x * 0.5, sr.size.y * 0.04),
			sr.position + Vector2(sr.size.x * 0.12, sr.size.y * 0.4)]), Color(1, 1, 1, 0.07))
		# лента категории на корпусе (сверху слева), номер записи
		var f := MGUI.font("caps")
		var fm := MGUI.font("mono")
		var cat := String(tv.rec["cat"])
		var cc: Color = G67ArchTV.CAT_COL.get(cat, Color.GRAY)
		var tw := f.get_string_size(cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_set_transform(b.position + Vector2(-6, -4), -0.05, Vector2.ONE)
		draw_rect(Rect2(Vector2.ZERO, Vector2(tw + 14, 16)), Color(cc, 0.92))
		draw_string(f, Vector2(7, 12), cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.07, 0.06))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# бумажный ярлык с названием под экраном
		var title := String(tv.rec["title"])
		var room := b.size.x - (sr.position.x - b.position.x) - 14.0
		var ls := 13
		while ls > 9 and MGUI.font("ui_b").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x > room - 50.0:
			ls -= 1
		var lw := minf(room, MGUI.font("ui_b").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x + 50.0)
		var lr := Rect2(Vector2(sr.position.x + 4, sr.end.y + 6), Vector2(lw, 20))
		if lr.end.y > b.end.y - 2:
			lr.position.y = b.end.y - 24
		draw_rect(lr, Color(0.86, 0.82, 0.7) if not lock else Color(0.55, 0.52, 0.46))
		draw_string(fm, lr.position + Vector2(5, 14), "%02d" % int(tv.rec["no"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.12, 0.1))
		draw_string(MGUI.font("ui_b"), lr.position + Vector2(28, 15), title, HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 48, ls, Color(0.1, 0.09, 0.08))
		# лампочка
		var led := Vector2(b.end.x - 14, b.end.y - 12)
		var lc := Color(0.15, 0.12, 0.1)
		if st == "new" or tv.opened_t > 0.0:
			lc = Color(0.3, 1.0, 0.4) if fmod(tv.t, 0.9) < 0.55 else Color(0.08, 0.3, 0.12)
		elif st == "seen":
			lc = Color(0.25, 0.6, 0.3)
		elif lock:
			lc = Color(0.4, 0.06, 0.05)
		draw_circle(led, 4.0, lc)
		# состояния
		if st == "new" and tv.opened_t <= 0.0:
			G67Diorama.draw_new(self, Vector2(sr.end.x - 54, sr.position.y - 12), 0.06)
		elif st == "seen" and tv.opened_t <= 0.0:
			var tk := Vector2(lr.end.x - 16, lr.position.y + 11)       # галочка «просмотрено» на ярлыке
			draw_line(tk + Vector2(-5, 0), tk + Vector2(-1, 4), Color(0.6, 0.14, 0.1), 2.5)
			draw_line(tk + Vector2(-1, 4), tk + Vector2(7, -6), Color(0.6, 0.14, 0.1), 2.5)
		if tv.opened_t > 0.0:
			draw_set_transform(sr.get_center(), -0.12, Vector2.ONE)
			draw_rect(Rect2(Vector2(-58, -18), Vector2(116, 36)), Color(0.2, 0.75, 0.3, 0.85), false, 3.0)
			draw_string(f, Vector2(-44, 9), "ОТКРЫТО", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.95, 0.45))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if tv.selected:
			draw_rect(b.grow(5), Color(0.98, 0.78, 0.42, 0.9), false, 3.0)
		if lock:
			# цепь крест-накрест через корпус и замок; при открытии — опускается и тает
			var k := tv.chain_k
			var drop := (1.0 - k) * 60.0
			var a := Color(0.62, 0.6, 0.55, k)
			var c := sr.get_center() + Vector2(0, sr.size.y * 0.1 + drop * 1.4)
			G67Diorama.draw_chain(self, Vector2(b.position.x - 8, sr.position.y + 6 + drop), c, 1.0, a)
			G67Diorama.draw_chain(self, c, Vector2(b.end.x + 8, sr.position.y + 6 + drop), 1.0, a)
			G67Diorama.draw_padlock(self, c + Vector2(0, 6), 1.7, Color(0.66, 0.58, 0.38, k))
