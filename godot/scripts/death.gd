## Гибель Пахана как сцена: падение → камера медленно уходит вверх и смотрит на тело сверху → мир теряет цвет →
## появляется «ПАХАН УМЕР» или «MADK1D УМЕР» — по тому, кто погиб, → две кнопки «ЕЩЁ РАЗ» и «В МЕНЮ».
## Узел создаётся на каждую гибель (game.on_player_dead), живёт в HUD и записан в game.panel: «Ещё раз» и выход в меню
## освобождают его обычным game._close_panel(), а _exit_tree возвращает камеру и цвет. Времена — в константах T_*.
## Камеру ведёт сам (game отдаёт её через owns_camera/camera), чёрно-белый — множитель game.death_mono в общем шейдере кадра.
## Любое подтверждение (Enter, Пробел, ЛКМ) до конца сцены проматывает её к кнопкам.
class_name DeathSeq
extends Control

const STAGE := Vector2(1600, 900)
const WHITE := Color(0.95, 0.96, 0.97)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const T_RISE0 := 0.9        # падение почти закончилось — камера трогается
const T_RISE1 := 5.0        # камера наверху
const T_MONO0 := 1.3        # цвет начинает уходить
const T_MONO1 := 4.6
const T_TITLE := 4.9        # появляется надпись
const T_BUTTONS := 6.6      # появляются кнопки
const HEIGHT := 6.2         # насколько высоко поднимается камера, если нет потолка
const BACK := 1.7           # и насколько остаётся позади тела — чтобы смотреть не строго отвесно

var game
var t := 0.0
var stage_name := "fall"    # fall → rise → title → menu
var from := Transform3D()
var to := Transform3D()
var cam_local := Transform3D()
var taken := false
var root: Control
var title: Control
var veil: ColorRect
var btns: Array = []        # [{root, label, frame, fill, act}]
var sel := 0
var hover: Array = [0.0, 0.0]
var accent_done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	var worn := ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	veil = ColorRect.new()                      # лёгкое затемнение краёв под надписью и кнопками, тело в центре остаётся видно
	veil.color = Color(0, 0, 0, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	root = Control.new()
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	title = Control.new()
	title.size = STAGE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.modulate.a = 0.0
	root.add_child(title)
	# тонкие диагонали и дуга, бледные буквы на фоне — как на афише
	for d in [[Vector2(-40, 720), Vector2(1640, 330)], [Vector2(960, -20), Vector2(1420, 920)]]:
		var l := Line2D.new()
		l.points = PackedVector2Array([d[0], d[1]])
		l.width = 1.6
		l.default_color = Color(1, 1, 1, 0.5)
		l.material = worn
		title.add_child(l)
	var arc := Line2D.new()
	var pts := PackedVector2Array()
	for i in 60:
		var a := PI * 0.62 + PI * 0.9 * i / 59.0
		pts.append(Vector2(1010, 470) + Vector2(cos(a), sin(a)) * 520.0)
	arc.points = pts
	arc.width = 1.6
	arc.default_color = Color(1, 1, 1, 0.42)
	arc.material = worn
	title.add_child(arc)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for ch in ["П", "А", "Х", "Н", "У", "М", "Е", "Р", "Р", "А"]:
		var g := Label.new()
		g.text = ch
		g.add_theme_font_override("font", serif)
		g.add_theme_font_size_override("font_size", rng.randi_range(110, 240))
		g.add_theme_color_override("font_color", Color(1, 1, 1, rng.randf_range(0.04, 0.1)))
		# только по краям кадра: середина — для тела
		var side := rng.randi_range(0, 3)
		g.position = Vector2(rng.randf_range(0, 1500), rng.randf_range(-40, 90)) if side == 0 else (Vector2(rng.randf_range(0, 1500), rng.randf_range(640, 800)) if side == 1 else (Vector2(rng.randf_range(-30, 180), rng.randf_range(0, 760)) if side == 2 else Vector2(rng.randf_range(1330, 1520), rng.randf_range(0, 760))))
		g.rotation = rng.randf_range(-0.5, 0.5)
		g.material = worn
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(g)
	var name_l := Label.new()
	var who := "MADK1D УМЕР" if game != null and game.player != null and String(game.player.hero) == "madk1d" else "ПАХАН УМЕР"
	var survival_result: Dictionary = game.survival.result if game != null and game.survival != null else {}
	var title_size := 132
	if not survival_result.is_empty():
		who = "ЗАБЕГ ОКОНЧЕН"
		title_size = 100
	name_l.text = who
	name_l.add_theme_font_override("font", serif)
	name_l.add_theme_font_size_override("font_size", title_size)
	name_l.add_theme_color_override("font_color", WHITE)
	name_l.material = worn
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = serif.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	name_l.scale = Vector2(1.28, 1.0)           # растянутое начертание, как на афише
	name_l.position = Vector2((STAGE.x - w * 1.28) * 0.5, 96)
	name_l.name = "Title"
	title.add_child(name_l)
	if not survival_result.is_empty():
		var records := preload("res://scripts/survival_records.gd")
		var last: Dictionary = survival_result["last_run"]
		var stats := Label.new()
		stats.text = "Время %s   ·   Враги %d   ·   Угроза %d%%\nБоссы %d   ·   События %d   ·   Рекорд %s" % [
			records.format_time(last["time"]), last["kills"], roundi(last["threat"] * 100.0),
			last["bosses"], last["events"], records.format_time(survival_result["best_time"])]
		stats.position = Vector2(0, 242)
		stats.size.x = STAGE.x
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 29)
		stats.add_theme_color_override("font_color", WHITE)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(stats)
		var perks := Label.new()
		var names: Array[String] = []
		for id in last["upgrades"]:
			names.append("%s ×%d" % [records.Mods.CARDS[id][0], last["upgrades"][id]])
		var lines: Array[String] = ["УСИЛЕНИЯ · %d" % names.size()]
		for i in range(0, names.size(), 3):
			lines.append("   ·   ".join(names.slice(i, i + 3)))
		perks.text = "\n".join(lines)
		perks.position.y = 330.0
		perks.size.x = STAGE.x
		perks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perks.add_theme_font_size_override("font_size", 23)
		perks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(perks)
	for i in 2:
		var b := Control.new()
		b.size = Vector2(330, 74)
		b.position = Vector2(STAGE.x * 0.5 - 350 + i * 370, 742)
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		root.add_child(b)
		var fill := ColorRect.new()
		fill.color = WHITE
		fill.size = Vector2(0, 74)
		fill.material = worn
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fill)
		var fr := Line2D.new()
		fr.points = PackedVector2Array([Vector2(0, 0), Vector2(330, 0), Vector2(330, 74), Vector2(0, 74)])
		fr.closed = true
		fr.width = 1.6
		fr.default_color = WHITE
		b.add_child(fr)
		var lab := Label.new()
		lab.text = ["ЕЩЁ РАЗ", "В МЕНЮ"][i]
		lab.add_theme_font_override("font", serif)
		lab.add_theme_font_size_override("font_size", 40)
		lab.size = b.size
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lab)
		btns.append({"root": b, "label": lab, "fill": fill})
		b.mouse_entered.connect(func(): if stage_name == "menu": _pick(i))
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and stage_name == "menu":
				_pick(i)
				_activate())
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	veil.size = vs
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	root.scale = Vector2.ONE * k
	root.position = (vs - STAGE * k) * 0.5

static func _ss(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## Камера сейчас принадлежит сцене гибели.
func owns_camera() -> bool:
	return taken

## Где сейчас камера (мировое преобразование).
func camera() -> Transform3D:
	var k := _ss(T_RISE0, T_RISE1, t)
	var q := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), k)
	return Transform3D(Basis(q), from.origin.lerp(to.origin, k))

## Конечная точка: над телом и чуть позади, взгляд — на тело. Потолок и стены не пробиваем.
func _plan() -> void:
	var cam: Camera3D = game.cam
	from = cam.global_transform
	cam_local = cam.transform
	var body: Vector3 = game.player.global_position + Vector3(0, 0.35, 0)
	var back := from.origin - body
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else Vector3(0, 0, 1)
	var want := body + Vector3.UP * HEIGHT + back * BACK
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(body + Vector3(0, 0.4, 0), want)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var dir := (want - body).normalized()
		want = body + dir * maxf(2.2, ((hit["position"] as Vector3) - body).length() - 0.5)
	to = Transform3D(Basis.looking_at(body - want, -back if absf((body - want).normalized().y) > 0.98 else Vector3.UP), want)
	taken = true

func _process(dt: float) -> void:
	if game == null:
		return
	t += minf(dt / maxf(Engine.time_scale, 0.001), 0.05)      # подвисший кадр не дёргает камеру
	if not taken and t >= T_RISE0:
		_plan()
	game.death_mono = _ss(T_MONO0, T_MONO1, t)
	stage_name = "fall" if t < T_RISE0 else ("rise" if t < T_TITLE else ("title" if t < T_BUTTONS else "menu"))
	var ta := _ss(T_TITLE, T_TITLE + 1.2, t)
	title.modulate.a = ta
	(title.get_node("Title") as Label).position.y = 96.0 + (1.0 - ta) * 14.0
	veil.color.a = 0.0
	if ta > 0.0 and not accent_done:
		accent_done = true
		game.main.audio.death_accent()
	if stage_name == "menu" and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and game.main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	var rdt := dt / maxf(Engine.time_scale, 0.001)
	for i in btns.size():
		var b: Dictionary = btns[i]
		var a := _ss(T_BUTTONS + i * 0.14, T_BUTTONS + 0.6 + i * 0.14, t)
		(b["root"] as Control).modulate.a = a
		(b["root"] as Control).position.y = 742.0 + (1.0 - a) * 16.0
		hover[i] = lerpf(hover[i], 1.0 if stage_name == "menu" and sel == i else 0.0, 1.0 - exp(-14.0 * rdt))
		(b["fill"] as ColorRect).size.x = 330.0 * hover[i]
		(b["label"] as Label).add_theme_color_override("font_color", INK if hover[i] > 0.5 else WHITE)

func _pick(i: int) -> void:
	if i != sel:
		game.main.sfx("sfx_ui", -10.0, 1.2)
	sel = i

func _activate() -> void:
	game.main.sfx("sfx_ui")
	if sel == 0:
		game._retry()
	else:
		game._to_menu()

func _unhandled_input(e: InputEvent) -> void:
	var confirm := false
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		confirm = k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
		if stage_name == "menu" and (k == KEY_A or k == KEY_D or k == KEY_LEFT or k == KEY_RIGHT or k == KEY_W or k == KEY_S or k == KEY_UP or k == KEY_DOWN or k == KEY_TAB):
			_pick(1 - sel)
		get_viewport().set_input_as_handled()      # Esc и прочее в сцене гибели ничего не делают
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		confirm = stage_name != "menu"
	if not confirm:
		return
	if stage_name == "menu":
		_activate()
	elif t > 0.4:
		if not taken:
			_plan()
		t = T_BUTTONS + 0.8                        # промотать к кнопкам

func _exit_tree() -> void:
	if game == null or not is_instance_valid(game):
		return
	game.death_mono = 0.0
	if taken and is_instance_valid(game.cam):
		game.cam.transform = cam_local
	taken = false
	if game.death == self:
		game.death = null
