## Переход из главного меню в игру: одна система для NEW GAME, CONTINUE и LOAD GAME (main.cinematic_start).
## cover() — рваная диагональная шторка закрывает меню, на чёрном появляется крупная надпись; за шторкой создаётся игра
## (сколько бы она ни грузилась, этого не видно). reveal() — шторка уходит тем же краем, мир проявляется чёрно-белым
## и постепенно возвращает цвет. Камеру, HUD и управление в это время ведёт сама игра (game.start_intro).
## Узел живёт в main (CanvasLayer поверх всего, работает и на паузе); пока перехода нет, он скрыт и ничего не рисует.
class_name IntroFX
extends CanvasLayer

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float open = 1.0;   // 1 — всё видно, 0 — всё чёрное; граница — рваная диагональ
uniform float mono = 0.0;   // 1 — чёрно-белый кадр с виньеткой
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen, uv, 0.0).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 col = mix(c, vec3(smoothstep(0.02, 0.92, l)), mono);
	col *= 1.0 - smoothstep(0.3, 0.95, length((uv - 0.5) * vec2(1.6, 1.0))) * 0.6 * mono;
	float d = uv.x * 0.8 + uv.y * 0.3 + (h(vec2(floor(uv.y * 120.0), 7.0)) - 0.5) * 0.035;
	float edge = open * 1.25 - 0.1;
	col *= smoothstep(d - 0.04, d, edge);
	col += vec3(0.85) * (1.0 - smoothstep(0.0, 0.012, abs(d - edge))) * step(0.02, open) * step(open, 0.98);
	col += (h(uv * 900.0 + floor(TIME * 24.0)) - 0.5) * 0.08 * max(mono, 1.0 - open);
	COLOR = vec4(col, 1.0);
}
"""
const STAGE := Vector2(1600, 900)
const T_COVER := 0.55
const T_HOLD := 0.45
const T_OPEN := 1.0
const T_COLOR := 1.6

var rect: ColorRect
var mat: ShaderMaterial
var holder: Control
var title: Label
var sub: Label
var lines: Array = []
var busy := false
var open_v := 1.0:
	set(v):
		open_v = v
		mat.set_shader_parameter("open", v)
var mono_v := 0.0:
	set(v):
		mono_v = v
		mat.set_shader_parameter("mono", v)

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_STOP     # пока идёт переход, клики не доходят до меню
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	holder = Control.new()
	holder.size = STAGE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	var tech := SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	var worn := ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	for d in [[Vector2(-40, 640), Vector2(1640, 300)], [Vector2(-40, 690), Vector2(1640, 350)]]:
		var l := Line2D.new()
		l.points = PackedVector2Array([d[0], d[1]])
		l.width = 1.4
		l.default_color = Color(1, 1, 1, 0.45)
		l.material = worn
		holder.add_child(l)
		lines.append(l)
	title = Label.new()
	title.add_theme_font_override("font", serif)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	title.material = worn
	title.size = Vector2(STAGE.x, 130)
	title.position = Vector2(0, 360)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.scale = Vector2(1.0, 1.0)
	holder.add_child(title)
	sub = Label.new()
	sub.add_theme_font_override("font", tech)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	sub.size = Vector2(STAGE.x, 30)
	sub.position = Vector2(0, 492)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(sub)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_idle()

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	rect.position = Vector2.ZERO
	rect.size = vs
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	holder.scale = Vector2.ONE * k
	holder.position = (vs - STAGE * k) * 0.5

func _idle() -> void:
	busy = false
	open_v = 1.0
	mono_v = 0.0
	rect.visible = false
	holder.visible = false

func _texts(a: float) -> void:
	title.modulate.a = a
	sub.modulate.a = a
	for l in lines:
		(l as Line2D).modulate.a = a

## Закрыть экран шторкой и показать надпись. Возвращается, когда экран полностью чёрный.
func cover(head: String, line: String) -> void:
	busy = true
	rect.visible = true
	holder.visible = true
	title.text = head
	sub.text = line
	_texts(0.0)
	open_v = 1.0
	mono_v = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "mono_v", 1.0, T_COVER * 0.6)
	tw.tween_property(self, "open_v", 0.0, T_COVER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_texts, 0.0, 1.0, 0.35).set_delay(T_COVER * 0.6)
	title.position.x = -30.0
	tw.tween_property(title, "position:x", 0.0, 0.6).set_delay(T_COVER * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(T_COVER + T_HOLD).timeout

## Открыть мир: надпись гаснет, шторка уходит, кадр из чёрно-белого становится цветным.
func reveal() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_texts, 1.0, 0.0, 0.3)
	tw.tween_property(self, "open_v", 1.0, T_OPEN).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "mono_v", 0.0, T_COLOR).set_delay(0.2 + T_OPEN * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(_idle)

## Ошибка загрузки: сообщение на чёрном, через пару секунд — назад в меню.
func fail(text: String, back: Callable) -> void:
	title.text = "НЕ ВЫШЛО"
	sub.text = text
	_texts(1.0)
	await get_tree().create_timer(2.6).timeout
	back.call()
	reveal()
