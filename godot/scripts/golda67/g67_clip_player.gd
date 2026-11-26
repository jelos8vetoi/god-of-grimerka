## Плеер роликов «ГОЛДА 67» (раздел 13.1 ТЗ): ролик — живая 3D-постановка в своём мире (SubViewport), показанная
## в рамке телевизора (16:9) или телефона (9:16), с репликами голосами персонажей (G67Voice), субтитрами, плашками,
## VHS-помехами и звуком. Сценарии — G67Clips (одна функция на ролик, пишется как последовательность кадров:
## await c.wait(), await c.say(), c.cam_to() …).
##
## Esc ставит ролик на паузу (изображение, голос, таймеры и время ролика стоят; поверх затемнение и «ПАУЗА», меню игры не
## открывается), Esc ещё раз — продолжение. Пропуск — удержание Enter / Пробела / кнопки A геймпада 0,8 с (и при первом
## просмотре; кольцо-индикатор в углу). Пропущенный ролик открыт в архиве, но не «просмотрен» (play_clip смотрит skipped).
## Просмотренные и открытые — Golda67.meta: "clips_seen", "archive" ("clip_<ID>").
class_name G67ClipPlayer
extends CanvasLayer

signal finished(id: String)

const VP_WIDE := Vector2i(1280, 720)
const VP_TALL := Vector2i(608, 1080)

var game
var id := ""
var tall := false
const HOLD_SKIP := 0.8
const HINT_SEC := 3.0
var skippable := true           # пропуск доступен всегда: удержанием
var paused := false
var _ctl: Control
var _dim: ColorRect
var skipped := false
var done := false
var t := 0.0
var vp: SubViewport
var vpc: SubViewportContainer
var world: Node3D
var cam: Camera3D
var env: WorldEnvironment
var frame: Control           # область кадра на экране
var over: Control            # плашки и субтитры поверх кадра
var sub_name: Label
var sub_text: Label
var hint: Label
var post: ShaderMaterial
var voice: AudioStreamPlayer
var actors := {}
var _shake := 0.0
var _vhs := 0.0
var _vhs_t := 0.0

const POST := """
shader_type canvas_item;
uniform float vhs = 0.0;
uniform float grain = 0.05;
uniform float scan = 0.18;
uniform float time = 0.0;
uniform float mono = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float band = step(0.985 - vhs * 0.08, rnd(vec2(floor(uv.y * 90.0), floor(time * 18.0))));
	uv.x += band * (rnd(vec2(time, uv.y)) - 0.5) * 0.06 * (0.2 + vhs);
	uv.x += sin(uv.y * 220.0 + time * 9.0) * 0.0012 * vhs;
	float ca = 0.0015 + vhs * 0.006;
	vec3 c;
	c.r = texture(TEXTURE, uv + vec2(ca, 0.0)).r;
	c.g = texture(TEXTURE, uv).g;
	c.b = texture(TEXTURE, uv - vec2(ca, 0.0)).b;
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), mono);
	c *= 1.0 - scan * (0.5 + 0.5 * sin(UV.y * 900.0));
	c += (rnd(UV * 731.0 + time) - 0.5) * grain;
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * 0.9;
	COLOR = vec4(c, 1.0);
}
"""

## Показать ролик. done(id) — по окончании или пропуске. Возвращает плеер (его можно ждать: await p.finished)
static func open(g, clip_id: String, seen: bool) -> G67ClipPlayer:
	var p := G67ClipPlayer.new()
	p.game = g
	p.id = clip_id
	p.tall = G67Clips.tall(clip_id)
	p.skippable = seen
	p.layer = 60
	g.add_child(p)
	g.main.audio.director.enter_cinematic(p, G67Clips.MUSIC.get(clip_id, {"mode": "silence"}))
	p._build()
	p._run.call_deferred()
	return p

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	frame = Control.new()
	root.add_child(frame)
	# рамка: телевизор или телефон
	var bez := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08) if not tall else Color(0.03, 0.03, 0.035)
	sb.border_color = Color(0.16, 0.16, 0.18) if not tall else Color(0.22, 0.22, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(26 if not tall else 46)
	bez.add_theme_stylebox_override("panel", sb)
	bez.name = "bezel"
	frame.add_child(bez)
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	frame.add_child(vpc)
	vp = SubViewport.new()
	vp.size = VP_TALL if tall else VP_WIDE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.audio_listener_enable_3d = false
	vpc.add_child(vp)
	post = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POST
	post.shader = sh
	vpc.material = post
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	env = WorldEnvironment.new()
	vp.add_child(env)
	set_env("night")
	over = Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.clip_contents = true
	frame.add_child(over)
	sub_name = _label(over, "", 22, Color(1.0, 0.82, 0.3))
	sub_text = _label(over, "", 26, Color.WHITE)
	sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = _label(root, "", 18, Color(0.7, 0.72, 0.78))
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	var pl := _label(_dim, "ПАУЗА", 64, Color(0.95, 0.96, 0.97))
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_dim)
	var cl := _label(_dim, "Esc — продолжить", 22, Color(0.7, 0.72, 0.78))
	cl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cl.position = Vector2(-120, -120)
	_ctl = Ctl.new()
	_ctl.set("owner_p", self)
	_ctl.process_mode = Node.PROCESS_MODE_ALWAYS
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ctl)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", game.main.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var fs: Vector2
	if tall:
		fs.y = s.y * 0.9
		fs.x = fs.y * 9.0 / 16.0
	else:
		fs.x = minf(s.x * 0.9, s.y * 0.9 * 16.0 / 9.0)
		fs.y = fs.x * 9.0 / 16.0
	frame.position = (s - fs) * 0.5
	frame.size = fs
	var pad := 16.0 if not tall else 14.0
	var bez: Control = frame.get_node("bezel")
	bez.position = Vector2(-pad, -pad)
	bez.size = fs + Vector2(pad, pad) * 2.0
	vpc.position = Vector2.ZERO
	vpc.size = fs
	over.position = Vector2.ZERO
	over.size = fs
	var k := fs.y / 720.0 if not tall else fs.x / 608.0
	sub_name.add_theme_font_size_override("font_size", int(20 * k))
	sub_text.add_theme_font_size_override("font_size", int(25 * k))
	sub_text.size = Vector2(fs.x * 0.86, 0)
	sub_text.position = Vector2(fs.x * 0.07, fs.y * (0.80 if not tall else 0.74))
	sub_name.size = Vector2(fs.x, 0)
	sub_name.position = Vector2(0, sub_text.position.y - 30.0 * k)
	hint.size = Vector2(minf(620.0, s.x - 40.0), 30)          # шире текста: в 310 px подсказка вылезала за правый край экрана
	hint.position = Vector2(s.x - hint.size.x - 20.0, s.y - 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _run() -> void:
	hint.text = "Esc — пауза · удерживай Enter — пропустить"
	hint.create_tween().tween_property(hint, "modulate:a", 0.0, 0.4).set_delay(HINT_SEC)      # подсказка только в начале ролика
	await G67Clips.run(self, id)
	_end()

func _end() -> void:
	if done:
		return
	done = true
	if paused:
		paused = false
		get_tree().paused = false
	voice.stop()
	game.main.audio.director.leave_cinematic(self)
	finished.emit(id)
	queue_free()

func _process(dt: float) -> void:
	t += dt
	_vhs_t = maxf(0.0, _vhs_t - dt)
	post.set_shader_parameter("time", t)
	post.set_shader_parameter("vhs", _vhs if _vhs_t > 0.0 else 0.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 2.5)
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.08
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.05

## Пауза ролика: встаёт дерево (ролик, голос, таймеры — «pausable»), работают только Ctl и затемнение
func set_paused(v: bool) -> void:
	if done or paused == v:
		return
	paused = v
	get_tree().paused = v
	_dim.visible = v
	if v and voice.playing:
		voice.stream_paused = true
	elif not v:
		voice.stream_paused = false

## Узел ввода роликa: работает и на паузе. Esc — пауза; удержание Enter / Пробела / A — пропуск, индикатор — кольцо
class Ctl extends Control:
	var owner_p
	var hold := 0.0
	func _input(e: InputEvent) -> void:
		if owner_p == null or owner_p.done:
			return
		if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
			owner_p.set_paused(not owner_p.paused)
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
	func _process(dt: float) -> void:
		if owner_p == null or owner_p.done:
			return
		var held: bool = not owner_p.paused and (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A))
		var before := hold
		hold = hold + dt if held else maxf(0.0, hold - dt * 3.0)
		if hold != before or hold > 0.0:
			queue_redraw()
		if hold >= G67ClipPlayer.HOLD_SKIP:
			hold = 0.0
			owner_p.skip()
	func _draw() -> void:
		if hold <= 0.0:
			return
		var c := Vector2(size.x - 70, 70)
		draw_arc(c, 24, 0, TAU, 32, Color(1, 1, 1, 0.2), 4.0)
		draw_arc(c, 24, -PI * 0.5, -PI * 0.5 + TAU * clampf(hold / G67ClipPlayer.HOLD_SKIP, 0.0, 1.0), 32, Color(1.0, 0.82, 0.3), 5.0)

func skip() -> void:
	if done:
		return
	skipped = true
	voice.stop()
	_end()

# ---------------------------------------------------------------- инструменты постановки (для G67Clips)
func alive() -> bool:
	return not skipped and not done and is_inside_tree()

func wait(sec: float) -> void:
	if not alive():
		return
	await get_tree().create_timer(sec, false).timeout

## Реплика «КОД|текст»: голос из манифеста главы 1 (нет — по длине текста), субтитр с именем. Ждёт конца реплики.
func say(line: String, hold := 0.25) -> void:
	if not alive():
		return
	var d := say_async(line)
	await wait(d + hold)
	if alive():
		sub_text.text = ""
		sub_name.text = ""

## Реплика без ожидания; возвращает длительность
static var last_log: Array = []      # [время, реплика, длина голоса, есть ли голос] — для сверки монтажа (--g67-clip)

func say_async(line: String) -> float:
	var p := line.find("|")
	var code := line.substr(0, p)
	var text := line.substr(p + 1)
	sub_name.text = G67Clips.speaker(code)
	sub_text.text = text
	var path := G67Voice.path(line)
	voice.stop()
	if path != "":
		voice.stream = load(path)
		voice.play()
		last_log.append([t, line, voice.stream.get_length(), true])
		return voice.stream.get_length()
	last_log.append([t, line, clampf(0.6 + text.length() * 0.062, 1.2, 6.0), false])
	return clampf(0.6 + text.length() * 0.062, 1.2, 6.0)

func clear_sub() -> void:
	sub_text.text = ""
	sub_name.text = ""

func set_env(kind: String) -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.6
	match kind:
		"night":
			e.background_color = Color(0.08, 0.1, 0.18)
			e.ambient_light_color = Color(0.55, 0.62, 0.85)
			e.ambient_light_energy = 0.75
			e.fog_enabled = true
			e.fog_light_color = Color(0.2, 0.24, 0.36)
			e.fog_density = 0.008
		"studio":
			e.background_color = Color(0.05, 0.06, 0.09)
			e.ambient_light_color = Color(0.85, 0.86, 0.95)
			e.ambient_light_energy = 0.9
		"room":
			e.background_color = Color(0.12, 0.13, 0.12)
			e.ambient_light_color = Color(0.9, 0.85, 0.75)
			e.ambient_light_energy = 0.85
		"black":
			e.background_color = Color(0, 0, 0)
			e.ambient_light_color = Color(1, 1, 1)
			e.ambient_light_energy = 0.4
	env.environment = e

func light(pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	world.add_child(l)
	return l

func sun(rot: Vector3, col: Color, energy: float) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot
	l.light_color = col
	l.light_energy = energy
	l.shadow_enabled = true
	world.add_child(l)
	return l

func cam_at(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = fov

## Плавный проезд камеры (по кривой «вход-выход»)
func cam_to(pos: Vector3, look: Vector3, dur: float, fov := -1.0, trans := Tween.TRANS_SINE) -> Tween:
	var p0 := cam.global_position
	var f0 := -cam.global_transform.basis.z
	var l0 := p0 + f0 * maxf(1.0, p0.distance_to(look))
	var fv0 := cam.fov
	var fv1 := fov if fov > 0.0 else fv0
	var tw := create_tween()
	tw.set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float):
		cam.global_position = p0.lerp(pos, k)
		cam.look_at(l0.lerp(look, k), Vector3.UP)
		cam.fov = lerpf(fv0, fv1, k), 0.0, 1.0, dur)
	return tw

## Камера вокруг точки (облёт)
func cam_orbit(center: Vector3, radius: float, h: float, a0: float, a1: float, dur: float, fov := 45.0) -> Tween:
	cam.fov = fov
	var tw := create_tween()
	tw.tween_method(func(a: float):
		cam.global_position = center + Vector3(sin(a) * radius, h, cos(a) * radius)
		cam.look_at(center + Vector3(0, 0.2, 0), Vector3.UP), a0, a1, dur)
	return tw

## Персонаж ролика: misha, pahan, madk1d, krot, anchor, fortuna, korolevsky, busterenko (одна модель на персонажа)
func actor(key: String, kind: String, pos: Vector3, yaw: float) -> Rig:
	var r := Rig.new()
	world.add_child(r)
	var C: Dictionary
	var path := ""
	var h := 1.7
	match kind:
		"misha":
			path = G67Models.DIR + "g67_misha.glb"
			h = 2.15
			C = Poses.pahan()
			C.merge(G67Poses.clips(), true)
			C.merge(G67Misha.clips(), true)
			C.merge(G67Clips.misha_clips(), true)
		"pahan":
			path = "res://assets/models/pahan.glb"
			h = 1.74
			C = Poses.pahan()
			C.merge(G67Clips.ev_clips(), true)
			C.merge(G67PzClips.wave_clips(), true)
		"pz_ctl", "pz_prm":
			path = "res://assets/golda67/podzemka/g67_enemy_controller.glb" if kind == "pz_ctl" else "res://assets/golda67/podzemka/g67_enemy_promoter.glb"
			h = 1.78 if kind == "pz_ctl" else 1.74
			C = Poses.pahan()
			C.merge(G67PzClips.wave_clips(), true)
		"madk1d":
			path = "res://assets/models/madk1d.glb"
			h = 1.68
			C = Poses.madk1d()
			C.merge(G67Clips.madk_clips(), true)
			C.merge(G67Clips.ev_clips(), true)
		"whyousolonely":
			path = G67Models.DIR + "g67_whyousolonely.glb"
			h = 1.75
			C = Poses.pahan()
			C.merge(G67Clips.ev_clips(), true)
		"krot":
			path = G67Models.DIR + "g67_krot.glb"
			h = 1.62
			C = Poses.pahan()
			C.merge(G67Poses.krot(), true)
			C.merge(G67Clips.krot_clips(), true)
		"anchor":
			path = G67Models.DIR + "g67_news_anchor.glb"
			h = 1.78
			C = Poses.pahan()
			C.merge(G67Poses.clips(), true)
		"fortuna", "korolevsky", "busterenko":
			path = G67Models.DIR + "g67_" + kind + ".glb"
			h = {"fortuna": 1.82, "korolevsky": 1.8, "busterenko": 1.76}[kind]
			C = Poses.pahan()
			C.merge(G67Poses.clips(), true)
			C.merge(G67Clips.boss_clips(), true)
			if kind == "fortuna":
				C.merge(G67Fortuna.clips(), true)
	r.setup(path, h, C, true, -1.0 if kind == "pahan" else 1.0, "clip_" + kind)
	r.position = pos
	r.rotation.y = yaw
	r.play("Idle", 0.0)
	if kind == "misha":
		G67Models.misha_chain(r)
	actors[key] = r
	return r

func anim(key: String, clip: String, blend := 0.3, speed := 1.0) -> void:
	var r: Rig = actors.get(key)
	if r != null and r.has_clip(clip):
		r.play(clip, blend, speed)

func anim_once(key: String, clip: String, dur: float, blend := 0.15) -> void:
	var r: Rig = actors.get(key)
	if r != null and r.has_clip(clip):
		r.play_for(clip, dur, blend)

func move(key: String, to: Vector3, dur: float) -> Tween:
	var r: Rig = actors.get(key)
	var tw := create_tween()
	tw.tween_property(r, "position", to, dur)
	return tw

## Модель из файла как декорация (lift — поднять над землёй)
func prop(path_or_id: String, pos: Vector3, yaw: float, size: Vector3, fit := "h") -> Node3D:
	return G67Models.spawn(path_or_id, world, pos, yaw, size, fit)

func box(size: Vector3, pos: Vector3, col: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	mi.material_override = m
	world.add_child(mi)
	return mi

## Натянутая цепь между точками (как у зацепа в бою)
func chain(from: Vector3, to: Vector3, sec: float) -> void:
	var n := Node3D.new()
	world.add_child(n)
	var len := from.distance_to(to)
	n.global_position = from
	n.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
	var link := TorusMesh.new()
	link.inner_radius = 0.035
	link.outer_radius = 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.7, 0.22)
	mat.metallic = 0.9
	mat.roughness = 0.3
	link.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	var cnt := clampi(int(len / 0.12), 2, 80)
	mm.instance_count = cnt
	for i in cnt:
		var b := Basis(Vector3(1, 0, 0), PI * 0.5)
		if i % 2 == 1:
			b = Basis(Vector3(0, 0, 1), PI * 0.5) * b
		mm.set_instance_transform(i, Transform3D(b, Vector3(0, 0, -len * (float(i) + 0.5) / float(cnt))))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	n.add_child(mi)
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(n.queue_free)

# ---- плашки
## kind: big (золотые крупные буквы по центру), caption (белая подпись внизу, как в коротких роликах), lower
## (плашка «нижняя треть»), ticker (бегущая строка), stamp (красный штамп), top (надпись сверху), small (мелкий текст)
func plate(text: String, kind: String, dur := 0.0) -> Control:
	var fs := frame.size
	var k := fs.y / 720.0 if not tall else fs.x / 608.0
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = fs
	over.add_child(holder)
	match kind:
		"big":
			var l := _label(holder, text, int(56 * k), Color(1.0, 0.8, 0.22))
			l.add_theme_constant_override("outline_size", int(14 * k))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size = Vector2(fs.x * 0.9, fs.y * 0.5)
			l.position = Vector2(fs.x * 0.05, fs.y * 0.25)
			l.pivot_offset = l.size * 0.5
			l.scale = Vector2(1.25, 1.25)
			l.modulate.a = 0.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(l, "modulate:a", 1.0, 0.2)
		"caption", "top":
			var l := _label(holder, text, int(38 * k), Color.WHITE)
			l.add_theme_constant_override("outline_size", int(12 * k))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size = Vector2(fs.x * 0.9, 0)
			l.position = Vector2(fs.x * 0.05, fs.y * (0.1 if kind == "top" else 0.6))
		"lower":
			var bar := ColorRect.new()
			bar.color = Color(0.72, 0.08, 0.08, 0.92)
			bar.size = Vector2(fs.x * 0.62, 46 * k)
			bar.position = Vector2(fs.x * 0.06, fs.y * 0.66)
			holder.add_child(bar)
			var l := _label(holder, text, int(26 * k), Color.WHITE)
			l.position = bar.position + Vector2(14 * k, 6 * k)
		"ticker":
			var bar := ColorRect.new()
			bar.color = Color(0.05, 0.05, 0.07, 0.94)
			bar.size = Vector2(fs.x, 40 * k)
			bar.position = Vector2(0, fs.y - 40 * k)
			holder.add_child(bar)
			var tag := ColorRect.new()
			tag.color = Color(0.85, 0.1, 0.1)
			tag.size = Vector2(130 * k, 40 * k)
			tag.position = bar.position
			holder.add_child(tag)
			_label(holder, "СРОЧНО", int(22 * k), Color.WHITE).position = bar.position + Vector2(14 * k, 6 * k)
			var l := _label(holder, text + "      ·      " + text, int(23 * k), Color(1, 0.92, 0.6))
			l.position = bar.position + Vector2(fs.x, 7 * k)
			var tw := create_tween()
			tw.tween_property(l, "position:x", -l.get_minimum_size().x * 0.5, maxf(dur, 6.0))
		"stamp":
			var l := _label(holder, text, int(44 * k), Color(0.9, 0.12, 0.1))
			l.add_theme_constant_override("outline_size", int(4 * k))
			l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
			l.position = Vector2(fs.x * 0.12, fs.y * 0.42)
			l.rotation = -0.12
		"small":
			var l := _label(holder, text, int(18 * k), Color(0.85, 0.85, 0.9))
			l.position = Vector2(fs.x * 0.06, fs.y * 0.9)
	if dur > 0.0:
		var tw2 := create_tween()
		tw2.tween_interval(dur)
		tw2.tween_property(holder, "modulate:a", 0.0, 0.2)
		tw2.tween_callback(holder.queue_free)
	return holder

func clear_plates() -> void:
	for c in over.get_children():
		if c != sub_name and c != sub_text:
			c.queue_free()

## Экран телефона / интерфейса поверх всего кадра (2D): build(ctl, размер) рисует содержимое
func screen(build: Callable) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size = frame.size
	over.add_child(s)
	over.move_child(s, 0)
	build.call(s, frame.size)
	return s

func vhs(amount: float, sec: float) -> void:
	_vhs = amount
	_vhs_t = sec

func shake(a: float) -> void:
	_shake = maxf(_shake, a)

func mono(v: float) -> void:
	post.set_shader_parameter("mono", v)

func filters(scan: float, grain: float) -> void:
	post.set_shader_parameter("scan", scan)
	post.set_shader_parameter("grain", grain)

func flash(col := Color.WHITE, sec := 0.25) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = frame.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, sec)
	tw.tween_callback(r.queue_free)

func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	game.main.sfx(name, db, pitch)
