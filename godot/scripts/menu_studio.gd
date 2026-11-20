## Главное меню «ОБЛАКО-ТВ»: настоящая 3D-сцена ночной телестудии вместо плоского фона и списка слов.
## Стена из пяти кинескопных телевизоров — по одному на пункт меню (CONTINUE, PLAY, SETTINGS, EXTRAS, EXIT): у каждого
## свой «канал» (шейдер экрана SCREEN_SHADER: запись, цветные полосы, настроечная сетка, телетекст, «нет сигнала»),
## название пункта на экране. Выбранный телевизор горит ярко и чуть выдвигается, остальные тускнеют и шумят; камера
## мягко доворачивает к нему и плывёт за курсором. Пахан стоит перед стеной экранов спиной к зрителю.
## Меню (menu.gd) логику не меняет: оно зовёт select(), flash(), а прямоугольники экранов на окне берёт из
## screen_rect(i) — по ним лежат невидимые зоны нажатия (мышь выбирает телевизор, а не строку).
class_name MenuStudio
extends SubViewportContainer

const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform int mode = 0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float on = 0.4;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float t = TIME;
	vec3 col = vec3(0.0);
	if (mode == 0) {            // запись: тёмный кадр, бегущая полоса, красная точка
		col = tint * (0.16 + 0.1 * sin(uv.y * 40.0 + t * 2.0));
		col += tint * 0.5 * smoothstep(0.04, 0.0, abs(fract(uv.y - t * 0.12) - 0.5));
		col += vec3(1.0, 0.1, 0.1) * step(length(uv - vec2(0.1, 0.14)), 0.035) * step(0.5, fract(t));
	} else if (mode == 1) {     // цветные полосы
		float k = floor(uv.x * 7.0);
		vec3 bars = vec3(mod(k + 1.0, 2.0), step(k, 3.0), step(mod(k, 4.0), 1.0));
		col = mix(bars * 0.75, tint, 0.35) * (uv.y < 0.72 ? 1.0 : 0.3);
	} else if (mode == 2) {     // настроечная сетка
		vec2 g = abs(fract(uv * vec2(8.0, 6.0)) - 0.5);
		col = tint * (0.12 + 0.7 * step(0.46, max(g.x, g.y)));
		col += tint * 0.6 * smoothstep(0.012, 0.0, abs(length(c) - 0.3));
	} else if (mode == 3) {     // телетекст: строки
		float row = floor(uv.y * 12.0);
		float len = 0.3 + 0.6 * h(vec2(row, floor(t * 0.4)));
		float ch = step(0.35, h(vec2(floor(uv.x * 30.0), row)));
		col = tint * 0.1 + tint * 0.8 * ch * step(uv.x, len) * step(0.25, fract(uv.y * 12.0)) * step(0.08, uv.x);
	} else {                    // нет сигнала
		col = vec3(h(floor(uv * vec2(160.0, 120.0)) + floor(t * 24.0))) * 0.55 * tint;
	}
	float noise = h(floor(uv * vec2(200.0, 150.0)) + floor(t * 30.0));
	col = mix(vec3(noise) * 0.22, col, clamp(on, 0.0, 1.0));
	col *= 0.82 + 0.18 * sin(uv.y * 420.0);                       // строки кинескопа
	col *= 1.0 - 0.22 * step(0.985, fract(uv.y * 0.9 - t * 0.21)); // бегущая помеха
	col *= smoothstep(0.75, 0.3, length(c * vec2(1.0, 1.1)));      // затемнение к краям трубки
	ALBEDO = col * (0.5 + 1.5 * on);
}
"""

## [x, y, ширина экрана, режим шейдера, цвет] — в порядке пунктов меню
const TVS := [
	[-0.55, 1.95, 1.05, 0, Color(0.35, 1.0, 0.55)],
	[1.05, 1.62, 1.55, 1, Color(1.0, 0.3, 0.25)],
	[2.72, 2.12, 0.95, 2, Color(0.45, 0.75, 1.0)],
	[2.66, 1.02, 0.9, 3, Color(1.0, 0.85, 0.3)],
	[-0.42, 0.9, 0.82, 4, Color(0.85, 0.85, 0.9)],
]

var vp: SubViewport
var cam: Camera3D
var tvs: Array = []           # [{root, mat, label, sub, lamp, w, h, on}]
var sel := 0
var back := 0.0               # 0 — главный список, 1 — открыт другой экран (сцена отъезжает и гаснет)
var back_to := 0.0
var t := 0.0
var shade: ColorRect
var pahan: Rig
var cam_home := Vector3(0.55, 1.5, 6.6)
var look_home := Vector3(0.75, 1.42, 0.0)
var look := Vector3(0.75, 1.42, 0.0)
var on_air: StandardMaterial3D

func setup(items: Array, font: Font) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.45)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.018
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.position = cam_home
	vp.add_child(cam)
	cam.look_at(look_home, Vector3.UP)
	_room()
	for i in items.size():
		_tv(i, String(items[i][0]), font)
	_props()
	_pahan()
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	select(0, true)

func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _box(parent: Node, p: Vector3, s: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, p: Vector3, r: float, hh: float, m: Material, rot := Vector3.ZERO, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = hh
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _room() -> void:
	var floor_m := _mat(Color(0.05, 0.05, 0.06), 0.18, 0.3)
	_box(vp, Vector3(1, -0.05, 1), Vector3(22, 0.1, 16), floor_m)
	_box(vp, Vector3(1, 3.5, -1.6), Vector3(22, 9, 0.2), _mat(Color(0.07, 0.07, 0.09), 0.95))
	# циклорама: мягкие цветные пятна на задней стене
	for q in [[-3.5, Color(0.9, 0.1, 0.15), 1.6], [5.4, Color(0.15, 0.3, 1.0), 1.8]]:
		var l := OmniLight3D.new()
		l.light_color = q[1]
		l.light_energy = float(q[2])
		l.omni_range = 7.0
		l.position = Vector3(float(q[0]), 2.2, -0.6)
		vp.add_child(l)
	# стеллаж под телевизоры
	var steel := _mat(Color(0.16, 0.16, 0.18), 0.5, 0.6)
	for x in [-1.25, 0.2, 1.95, 3.35]:
		_box(vp, Vector3(x, 1.5, -0.55), Vector3(0.06, 3.0, 0.06), steel)
	for y in [0.42, 1.42, 2.62]:
		_box(vp, Vector3(1.05, y - 0.02, -0.4), Vector3(4.8, 0.05, 0.75), steel)
	# вывеска канала
	var neon := Label3D.new()
	neon.text = "ОБЛАКО-ТВ"
	neon.font_size = 150
	neon.pixel_size = 0.0042
	neon.modulate = Color(1.0, 0.22, 0.2)
	neon.outline_size = 0
	neon.position = Vector3(1.75, 3.32, -1.4)
	neon.shaded = false
	vp.add_child(neon)
	var sub := Label3D.new()
	sub.text = "НОЧНОЙ ЭФИР · КАНАЛ 812"
	sub.font_size = 44
	sub.pixel_size = 0.004
	sub.modulate = Color(0.85, 0.88, 1.0)
	sub.position = Vector3(1.75, 2.97, -1.4)
	sub.shaded = false
	vp.add_child(sub)
	var nl := OmniLight3D.new()
	nl.light_color = Color(1.0, 0.25, 0.2)
	nl.light_energy = 1.2
	nl.omni_range = 5.0
	nl.position = Vector3(1.75, 3.2, -0.8)
	vp.add_child(nl)
	# табло «В ЭФИРЕ»
	on_air = _mat(Color(0.9, 0.08, 0.08))
	on_air.emission_enabled = true
	on_air.emission = Color(1.0, 0.1, 0.1)
	on_air.emission_energy_multiplier = 2.5
	_box(vp, Vector3(4.35, 2.7, -1.2), Vector3(0.9, 0.3, 0.1), _mat(Color(0.05, 0.05, 0.05)))
	_box(vp, Vector3(4.35, 2.7, -1.14), Vector3(0.8, 0.22, 0.02), on_air)
	var oa := Label3D.new()
	oa.text = "В ЭФИРЕ"
	oa.font_size = 40
	oa.pixel_size = 0.004
	oa.modulate = Color(1, 0.95, 0.9)
	oa.position = Vector3(4.35, 2.7, -1.12)
	oa.shaded = false
	vp.add_child(oa)

func _tv(i: int, title: String, font: Font) -> void:
	var d: Array = TVS[i]
	var w: float = d[2]
	var hh := w * 0.76
	var root := Node3D.new()
	root.position = Vector3(float(d[0]), float(d[1]), -0.35)
	root.rotation.y = clampf((1.05 - float(d[0])) * 0.09, -0.2, 0.2)      # крайние чуть развёрнуты к центру
	vp.add_child(root)
	var shell := _mat([Color(0.2, 0.19, 0.17), Color(0.1, 0.1, 0.11), Color(0.3, 0.27, 0.22)][i % 3], 0.55)
	_box(root, Vector3(0, 0, -0.28), Vector3(w + 0.2, hh + 0.2, 0.6), shell)
	_box(root, Vector3(0, 0, 0.03), Vector3(w + 0.26, hh + 0.26, 0.08), shell)
	_box(root, Vector3(0, 0, 0.06), Vector3(w + 0.06, hh + 0.06, 0.04), _mat(Color(0.02, 0.02, 0.02), 0.3))
	# ручки и решётка динамика
	_cyl(root, Vector3(w * 0.5 + 0.03, hh * 0.3, 0.09), 0.035, 0.05, _mat(Color(0.6, 0.6, 0.62), 0.3, 0.8), Vector3(PI / 2, 0, 0))
	_cyl(root, Vector3(w * 0.5 + 0.03, hh * 0.12, 0.09), 0.028, 0.05, _mat(Color(0.6, 0.6, 0.62), 0.3, 0.8), Vector3(PI / 2, 0, 0))
	# антенна-«усы» у верхних
	if float(d[1]) > 1.8:
		var am := _mat(Color(0.7, 0.7, 0.72), 0.3, 0.9)
		_cyl(root, Vector3(-0.12, hh * 0.5 + 0.42, -0.25), 0.008, 0.7, am, Vector3(0, 0, 0.5))
		_cyl(root, Vector3(0.12, hh * 0.5 + 0.42, -0.25), 0.008, 0.7, am, Vector3(0, 0, -0.5))
	var scr := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, hh)
	scr.mesh = qm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	sm.shader = sh
	sm.set_shader_parameter("mode", int(d[3]))
	sm.set_shader_parameter("tint", d[4])
	sm.set_shader_parameter("seed", float(i) * 3.7)
	scr.material_override = sm
	scr.position = Vector3(0, 0, 0.085)
	root.add_child(scr)
	var lab := Label3D.new()
	lab.text = title
	lab.font = font
	lab.font_size = 120
	lab.pixel_size = w * 0.78 / (float(maxi(4, title.length())) * 78.0)
	lab.outline_size = 26
	lab.outline_modulate = Color(0, 0, 0, 0.9)
	lab.position = Vector3(0, 0.02, 0.1)
	lab.shaded = false
	root.add_child(lab)
	var sub := Label3D.new()
	sub.font_size = 44
	sub.pixel_size = w / 900.0
	sub.outline_size = 12
	sub.outline_modulate = Color(0, 0, 0, 0.9)
	sub.width = 820.0
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector3(0, -hh * 0.32, 0.1)
	sub.shaded = false
	root.add_child(sub)
	var chn := Label3D.new()
	chn.text = "CH %02d" % (i + 1)
	chn.font_size = 40
	chn.pixel_size = w / 900.0
	chn.modulate = d[4]
	chn.position = Vector3(w * 0.36, hh * 0.38, 0.1)
	chn.shaded = false
	root.add_child(chn)
	var lamp := OmniLight3D.new()
	lamp.light_color = d[4]
	lamp.light_energy = 0.0
	lamp.omni_range = 3.2
	lamp.position = Vector3(0, 0, 0.9)
	root.add_child(lamp)
	tvs.append({"root": root, "mat": sm, "label": lab, "sub": sub, "lamp": lamp, "w": w, "h": hh, "on": 0.4, "home_z": -0.35, "enabled": true})

func _props() -> void:
	var black := _mat(Color(0.04, 0.04, 0.045), 0.5)
	var steel := _mat(Color(0.3, 0.3, 0.32), 0.35, 0.8)
	# студийная камера на треноге (справа на переднем плане)
	var cx := Node3D.new()
	cx.position = Vector3(4.2, 0, 2.6)
	cx.rotation.y = 0.9
	vp.add_child(cx)
	for a in 3:
		_cyl(cx, Vector3(sin(a * TAU / 3.0) * 0.28, 0.6, cos(a * TAU / 3.0) * 0.28), 0.02, 1.3, steel, Vector3(cos(a * TAU / 3.0) * 0.42, 0, -sin(a * TAU / 3.0) * 0.42))
	_box(cx, Vector3(0, 1.42, 0), Vector3(0.34, 0.3, 0.62), black)
	_cyl(cx, Vector3(0, 1.42, -0.42), 0.1, 0.26, black, Vector3(PI / 2, 0, 0), 0.13)
	_box(cx, Vector3(0, 1.66, 0.12), Vector3(0.24, 0.18, 0.2), black)
	var tally := _mat(Color(1, 0.1, 0.1))
	tally.emission_enabled = true
	tally.emission = Color(1, 0.1, 0.1)
	tally.emission_energy_multiplier = 3.0
	_box(cx, Vector3(0, 1.6, -0.3), Vector3(0.05, 0.03, 0.03), tally)
	# осветительные стойки
	for q in [[-3.6, 1.2, 0.5], [5.2, 0.6, -0.6]]:
		var st := Node3D.new()
		st.position = Vector3(float(q[0]), 0, float(q[1]))
		vp.add_child(st)
		_cyl(st, Vector3(0, 1.5, 0), 0.02, 3.0, steel)
		_cyl(st, Vector3(0, 0.03, 0), 0.3, 0.05, black)
		_cyl(st, Vector3(0, 3.0, 0), 0.16, 0.3, black, Vector3(1.0, float(q[2]), 0), 0.22)
		var sp := SpotLight3D.new()
		sp.position = Vector3(0, 3.0, 0)
		sp.light_energy = 5.0
		sp.light_color = Color(1.0, 0.9, 0.75)
		sp.spot_range = 9.0
		sp.spot_angle = 30.0
		st.add_child(sp)
		sp.look_at(Vector3(-2.05, 0.9, 1.25), Vector3.UP)
	# кабели по полу
	var cm := _mat(Color(0.02, 0.02, 0.02), 0.6)
	for q in 5:
		_cyl(vp, Vector3(1.0 + q * 0.7, 0.012, 1.2 + sin(q * 1.7) * 0.5), 0.012, 3.2, cm, Vector3(PI / 2, 0.5 + q * 0.5, 0))
	# готовые модели, если есть: колонка и старый телевизор на полу, кресло
	for q in [["fn_stage_speaker", Vector3(-2.2, 0, -0.6), 0.3, Vector3(0.8, 1.3, 0.7)], ["ml_job_old_tv", Vector3(3.9, 0, -0.3), -0.5, Vector3(0.75, 0.7, 0.6)], ["ml_job_amp", Vector3(4.7, 0, 0.5), -0.9, Vector3(0.7, 0.6, 0.45)]]:
		if ResourceLoader.exists("res://assets/minigames/%s.glb" % q[0]):
			MGModels.spawn(String(q[0]), vp, q[1], float(q[2]), q[3], Callable())

func _pahan() -> void:
	pahan = Rig.new()
	vp.add_child(pahan)
	pahan.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan(), false, -1.0, "menu_studio_pahan")
	pahan.position = Vector3(-2.05, 0, 1.25)
	pahan.rotation.y = PI + 0.5              # спиной к зрителю, лицом к экранам
	pahan.play("Idle", 0.0)

## выбран пункт i (enabled — доступен ли: у недоступного на экране помехи)
func select(i: int, instant := false) -> void:
	sel = i
	for k in tvs.size():
		var tv: Dictionary = tvs[k]
		var on := k == i
		var root: Node3D = tv["root"]
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(root, "position:z", float(tv["home_z"]) + (0.22 if on else 0.0), 0.0 if instant else 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "scale", Vector3.ONE * (1.06 if on else 1.0), 0.0 if instant else 0.22)
		tv["want"] = (1.0 if bool(tv["enabled"]) else 0.25) if on else 0.32
		(tv["label"] as Label3D).modulate = Color(1, 1, 1) if on else Color(0.6, 0.62, 0.66)

func set_enabled(i: int, e: bool) -> void:
	tvs[i]["enabled"] = e
	if not e:
		(tvs[i]["mat"] as ShaderMaterial).set_shader_parameter("mode", 4)

func set_sub(i: int, s: String) -> void:
	(tvs[i]["sub"] as Label3D).text = s

## запуск: выбранный экран вспыхивает
func flash(i: int) -> void:
	var tv: Dictionary = tvs[i]
	tv["on"] = 2.2
	var lamp: OmniLight3D = tv["lamp"]
	lamp.light_energy = 6.0

## прямоугольник экрана телевизора i на окне (в пикселях окна)
func screen_rect(i: int) -> Rect2:
	var tv: Dictionary = tvs[i]
	var root: Node3D = tv["root"]
	var w: float = float(tv["w"]) * 0.5 + 0.12
	var hh: float = float(tv["h"]) * 0.5 + 0.12
	var k := size / Vector2(vp.size) if vp.size.x > 0 else Vector2.ONE
	var a := cam.unproject_position(root.to_global(Vector3(-w, hh, 0.09))) * k
	var b := cam.unproject_position(root.to_global(Vector3(w, -hh, 0.09))) * k
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())

func _process(dt: float) -> void:
	t += dt
	back = move_toward(back, back_to, dt * 3.5)
	for k in tvs.size():
		var tv: Dictionary = tvs[k]
		tv["on"] = lerpf(float(tv["on"]), float(tv.get("want", 0.3)) * (1.0 - back * 0.6), 1.0 - exp(-9.0 * dt))
		(tv["mat"] as ShaderMaterial).set_shader_parameter("on", float(tv["on"]))
		var lamp: OmniLight3D = tv["lamp"]
		lamp.light_energy = lerpf(lamp.light_energy, (3.2 if k == sel else 0.0) * (1.0 - back), 1.0 - exp(-8.0 * dt))
	on_air.emission_energy_multiplier = 2.5 if fmod(t, 1.6) < 1.1 else 0.4
	shade.color.a = back * 0.8
	# камера: к выбранному экрану и за курсором, при открытом экране — отъезд
	var m := Vector2.ZERO
	if size.x > 1.0:
		m = (get_viewport().get_mouse_position() / size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	var tgt: Vector3 = (tvs[sel]["root"] as Node3D).position
	var want_look := look_home.lerp(Vector3(tgt.x, tgt.y, 0.0), 0.28)
	look = look.lerp(want_look, 1.0 - exp(-4.0 * dt))
	var want_pos := cam_home + Vector3(m.x * 0.5 + (tgt.x - 1.0) * 0.12, -m.y * 0.25 + sin(t * 0.5) * 0.03, back * 1.6)
	cam.position = cam.position.lerp(want_pos, 1.0 - exp(-3.5 * dt))
	cam.look_at(look, Vector3.UP)
