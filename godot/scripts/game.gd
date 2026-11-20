## Игра целиком: девять глав сюжета (data/story.json из браузерной версии), диалоги, волны, боссы с фазами,
## прокачка между главами, выбор финала, сохранение. Камера из-за плеча, интерфейс, эффекты.
## Режимы проверки: --autotest (бот играет сам), --smoke (быстрый прогон всех глав), --trailer (съёмка кадров).
extends Node3D

const ARENA := 15.0
const SAVE := "user://grimerka_save.json"
const MAX_ALIVE := 9

var main
var story: Dictionary
var player
var buddy
var world: Node3D
var enemies: Array = []
var diff_hp := 1.0
# сюжет
var ch := 0
var step := -1
var mode := "idle"          # dlg / fight / boss / shop / choice / end / idle
var waves: Array = []
var wave_i := -1
var pending: Array = []
var spawn_cd := 0.0
var wave_wait := 1.0
var boss_e = null
var step_done_t := -1.0
var xp := 0
var up := {"hp": 0, "dmg": 0, "q": 0}
var kills := 0
var over := false
# диалог
var dlg: Array = []
var dlg_i := 0
var dlg_chars := 0.0
var dlg_after: Callable
# камера
var cam_yaw := PI
var cam_pitch := -0.32
var pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var cam_attributes: CameraAttributesPractical
var trauma := 0.0            # тряска камеры: копится от ударов, гаснет сама
var shake_t := 0.0
var fov_kick := 0.0
var air_lift := 0.0          # камера приподнимается за подброшенным врагом рядом с героем
var charge_zoom := 0.0       # 0..1 — заряд полного замаха: камера поджимается
var zoom_s := 0.0
var fx
var post: ColorRect
var post_mat: ShaderMaterial
var pp := {"aberr": 0.0, "blur": 0.0, "flash": 0.0, "ripple_a": 0.0, "ripple_t": 0.0}
signal intro_done
## отклик боя (feedback.gd): каждое событие и подтверждение попадания — для HUD, вибрации и будущих стилей
signal feedback_fired(name: String, pos: Vector3, power: float)
signal hit_confirmed(pos: Vector3, power: float)
const INTRO_CAM := 2.8       # секунд облёта камеры при входе из меню
const INTRO_HUD := 1.6       # с этого момента по очереди появляется HUD
var intro_on := false        # игру запустили из меню с переходом (main.cinematic_start)
var intro_t := -1.0          # время облёта; −1 — облёта нет
var intro_a0 := 0.0          # откуда камера заходит: угол вокруг Пахана
var death                    # сцена гибели (scripts/death.gd), пока идёт; иначе null
var death_mono := 0.0        # 0 — цвет, 1 — чёрно-белый кадр с зерном (ведёт сцена гибели)
var ipod_focus := 0.0
var ipod_motion := 0.0
var ipod_focus_quality := 1.0
var ipod_attention_point := Vector2(0.74, 0.58)
var ripple_c := Vector2(0.5, 0.5)
var last_flash := -9.0
# озвучка: реплики диалогов и боевые выкрики (файлы делает tools/godot-voice.cjs)
var voice: AudioStreamPlayer
var bark_v: AudioStreamPlayer
var bark_m: AudioStreamPlayer
var bark_b: AudioStreamPlayer   # голоса боссов
var barks: Dictionary = {}
var bark_cd := {}
var peak_db := -200.0
var dlg_face := 0.0          # куда смотрел герой до диалога: по этой стороне ставится камера
var dlg_voiced := false      # у текущей реплики есть голос (иначе текст «печатается» со щелчками)
var tick_n := 0
# подъезд: игра начинается на площадке, после первого разговора герой сам выходит во двор
var in_hall := false
var fade: ColorRect
var exit_mark: MeshInstance3D
var heat_t := 0.0
var clock := 0.0
var stop_until := 0.0
var slow_until := 0.0
# интерфейс
var hud: CanvasLayer
var hp_fill: ColorRect
var swag_fill: ColorRect
var swag_label: Label
var top_label: Label
var q_label: Label
var xp_label: Label
var fps_label: Label
var banner_title: Label
var banner_sub: Label
var banner_t := 0.0
var toast_label: Label
var toast_t := 0.0
var flash: ColorRect
var pause_panel: Control
var panel: Control
var dlg_box: Control
var dlg_name: Label
var dlg_text: Label
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var hud_root: Control
# снаряды и зоны
var bolts: Array = []
var zones: Array = []
var lobs: Array = []
# проверки
var auto_t := 0.0
var auto_kill := -1.0
var auto_len := 45.0
var shots_done := {}
var fps_samples: Array = []
var director = null
var hero_label: Label         # имя героя, которым сейчас управляет игрок
var style_label: Label        # текущий боевой стиль и запас (бутылки)
var hype: TeamHype            # общая шкала команды и Team Overdrive (hype.gd)
var tag_saved: Dictionary = {}      # состояние команды из сохранения: применяется после загрузки главы
var tag: TagTeam              # Tag Team: здоровье обоих героев, командные приёмы, выбывание (tagteam.gd)
var dmg_log = null           # --damagecheck: [атака, цель, урон, кадр физики] каждого попадания по врагу; null — не пишем
var lock: LockOn            # захват цели (lockon.gd)
var training: Training = null     # тренировочная арена (training.gd); null — обычная игра
var golda = null                  # «ГОЛДА 67» (golda67/g67_root.gd, Golda67); null — не приквел
var dlg_partner = null            # с кем говорит герой (Node3D): камера диалога берёт в кадр его, а не напарника
var dlg_side := -1.0              # с какой стороны от пары встаёт камера (−1 / +1): выбирает тот, кто начал разговор
var show_dmg := true          # цифры урона над врагами (в арене — переключатель панели)
var read: PlayerRead         # что враги знают о поведении игрока (player_read.gd)
var squad_t := 0.0
var tutorial: Tutorial       # боевое обучение: карточки механик по ходу боя (tutorial.gd)
var combat_hud: CombatHud     # боевой HUD: портреты, полосы, карточки стилей, способности (hud.gd)
var ipod
var bot_acc := 0.0
var bot_pf := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	fx = preload("res://scripts/fx.gd").new()
	fx.game = self
	add_child(fx)
	barks = JSON.parse_string(FileAccess.get_file_as_string("res://data/barks.json"))
	voice = AudioStreamPlayer.new()
	add_child(voice)
	bark_v = AudioStreamPlayer.new()
	add_child(bark_v)
	bark_m = AudioStreamPlayer.new()
	add_child(bark_m)
	bark_b = AudioStreamPlayer.new()
	add_child(bark_b)
	player = preload("res://scripts/player.gd").new()
	player.game = self
	add_child(player)
	buddy = preload("res://scripts/companion.gd").new()
	buddy.game = self
	add_child(buddy)
	tag = TagTeam.new()
	add_child(tag)
	tag.setup(self)
	hype = TeamHype.new()
	add_child(hype)
	hype.setup(self)
	lock = LockOn.new()
	add_child(lock)
	lock.setup(self)
	read = PlayerRead.new()
	add_child(read)
	read.setup(self)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self)
	# анимации врагов собираем заранее, при запуске: иначе первый враг каждого вида даёт рывок посреди боя
	for it in [["bot", Poses.bot()], ["clipper", Poses.clipper()], ["hater", Poses.hater()]]:
		if not Rig._lib_cache.has(it[0]):
			var pre := Rig.new()
			add_child(pre)
			pre.setup("res://assets/models/%s.glb" % it[0], 1.7, it[1], false, 1.0, it[0])
			pre.free()
	_build_camera()
	_build_post()
	_build_hud()
	ipod = preload("res://scripts/ipod.gd").new()
	ipod.game = self
	# в проверках и прогонах бота библиотеку игрока на диске не читаем и не перезаписываем
	ipod.persistence_enabled = main.user_play()      # проверки (и меню-уровня: uiqa, арена, звук) настройки iPod игрока не пишут
	add_child(ipod)
	if main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)

func begin(from_save: bool, chapter := -1) -> void:
	if from_save and FileAccess.file_exists(SAVE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			ch = int(d.get("ch", 0))
			step = int(d.get("step", 0)) - 1
			xp = int(d.get("xp", 0))
			for k in up:
				up[k] = int(d.get("up", {}).get(k, 0))
			tag_saved = d.get("tag", {})
			hype.value = clampf(float(d.get("hype", 0.0)), 0.0, TeamHype.MAX)
			tutorial.load_data(d.get("tut", []))     # старые сохранения без ключа — обучение с начала
	if chapter >= 0:
		ch = chapter
		step = -1
	if ch >= chapters():      # сохранение из времён девяти глав: начинаем доступную главу заново
		ch = chapters() - 1
		step = -1
	_apply_upgrades()
	_load_chapter(step < 0, ch == 0 and step < 0 and main.trailer == "")
	fx.prewarm(player.global_position)
	if intro_on:
		start_intro()
		await intro_done      # сюжет (диалог, бой) начинается, когда камера заняла место и управление отдано
	next_step()

## Облёт при входе из меню: камера начинает сбоку от Пахана на уровне груди и по дуге приходит на игровое место;
## HUD появляется по очереди (здоровье, СВЭГ, madk1d, глава и задание, остальное). Ввод заблокирован, пока облёт идёт.
func start_intro() -> void:
	intro_t = 0.0
	intro_a0 = player.face + 1.15
	var order := {}
	order[swag_label] = 1
	order[q_label] = 2
	order[top_label] = 3
	order[xp_label] = 4
	order[fps_label] = 4
	if banner_t > 0.0:
		banner_t += 1.4          # заставка локации («ТОМСК…») не должна пройти за шторкой
	var tw := create_tween().set_parallel(true)
	for c in hud_root.get_children():
		var ci := c as CanvasItem
		if ci == null or c == banner_title or c == banner_sub or c == toast_label:     # их прозрачность ведёт сама игра
			continue
		var rank: int = order.get(c, 0)
		ci.modulate.a = 0.0
		tw.tween_property(ci, "modulate:a", 1.0, 0.35).set_delay(INTRO_HUD + rank * 0.16)
		if c is Control:
			var home: Vector2 = (c as Control).position
			(c as Control).position = home + Vector2(-24, 0)
			tw.tween_property(c, "position", home, 0.4).set_delay(INTRO_HUD + rank * 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func intro_busy() -> bool:
	return intro_t >= 0.0 or (golda != null and golda.scene_busy())      # облёт при входе или постановка приквела

func _intro_camera(rdt: float) -> void:
	intro_t += rdt
	var k := clampf(intro_t / INTRO_CAM, 0.0, 1.0)
	var e := k * k * k * (k * (k * 6.0 - 15.0) + 10.0)
	var home := spring.global_transform * Transform3D(Basis(), Vector3(0, 0, spring.get_hit_length()))
	var chest: Vector3 = player.global_position + Vector3(0, 1.05, 0)
	var rel: Vector3 = home.origin - chest
	var a1 := atan2(rel.x, rel.z)
	var a := intro_a0 + angle_difference(intro_a0, a1) * e
	var r := lerpf(3.3, Vector2(rel.x, rel.z).length(), e)
	var hh := lerpf(-0.1, rel.y, e)
	var pos: Vector3 = chest + Vector3(sin(a) * r, hh, cos(a) * r)
	var q := PhysicsRayQueryParameters3D.create(chest, pos)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = chest + (pos - chest).normalized() * maxf(0.9, ((hit["position"] as Vector3) - chest).length() - 0.25)
	var look := Basis.looking_at(chest - pos, Vector3.UP)
	var qb := look.get_rotation_quaternion().slerp(home.basis.get_rotation_quaternion(), e)
	cam.global_transform = Transform3D(Basis(qb), pos)
	cam.fov = lerpf(44.0, cam.fov, e)
	if k >= 1.0:
		intro_t = -1.0
		cam.transform = Transform3D(Basis(), Vector3(0, 0, spring.get_hit_length()))
		intro_done.emit()

func _save() -> void:
	if main.testing() != "" or training != null or golda != null:      # арена и приквел сюжетное сохранение не трогают
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"ch": ch, "step": step, "xp": xp, "up": up, "tag": tag.save_data(), "hype": hype.value, "tut": tutorial.save_data()}))

func _apply_upgrades() -> void:
	player.max_hp = 100.0 + 20.0 * up["hp"]
	player.hp = player.max_hp
	if tag != null:
		tag.reset()
		if not tag_saved.is_empty():
			tag.load_data(tag_saved)
			tag_saved = {}
	player.dmg_mul = 1.0 + 0.12 * up["dmg"]
	buddy.cd_max = 10.0 - 1.5 * up["q"]

# ---------------- главы ----------------
func chapter() -> Dictionary:
	return story["CH"][ch]

func _load_chapter(show_title: bool, hall := false) -> void:
	_clear_fight()
	if world:
		world.free()
	world = preload("res://scripts/world.gd").new()
	add_child(world)
	in_hall = hall
	world.build("hall" if hall else String(chapter()["th"]["deco"]))
	player.global_position = Vector3(0.5, 0.05, 3.2) if hall else Vector3(0, 0.05, 4)
	player.velocity = Vector3.ZERO
	buddy.global_position = Vector3(-0.8, 0.05, 3.4) if hall else Vector3(-1.8, 0.05, 4.5)
	buddy.target = Vector3.ZERO
	cam_yaw = PI
	player.face = PI
	if hall:
		banner("ТОМСК", "подъезд · три часа ночи", Color(1, 0.85, 0.55), 3.0)
	elif show_title:
		banner("ГЛАВА %d. %s" % [ch + 1, String(chapter()["name"])], String(chapter()["place"]), Color(1, 0.85, 0.55), 4.0)

## разговор закончился: в подъезде дальше надо выйти во двор самому, иначе — следующий шаг сюжета
func _dlg_done() -> void:
	if not in_hall:
		next_step()
		return
	mode = "exit"
	toast("Выйди из подъезда во двор")
	exit_mark = fx.flat(self, "circle_03", Color(1.0, 0.8, 0.35, 0.8), 2.0, 0.07)
	exit_mark.position = Vector3(0, 0.07, -4.1)

func _exit_hall() -> void:
	mode = "idle"
	in_hall = false
	if exit_mark:
		exit_mark.queue_free()
		exit_mark = null
	main.sfx("sfx_roll", -4.0, 0.6)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		_load_chapter(true)
		next_step())
	tw.tween_property(fade, "color:a", 0.0, 0.7)

## Сколько глав доступно. В игре — только первая (Menu.CHAPTERS): главы 2–9 остались в данных и коде, но не запускаются,
## вместо них будет открытый мир. Проверки (--smoke, --autotest, --chapter=N) по-прежнему ходят по всем.
func chapters() -> int:
	var all: int = story["CH"].size()
	if main.onechapter:
		return mini(all, Menu.CHAPTERS)
	return all if main.testing() != "" or main.start_ch >= 0 else mini(all, Menu.CHAPTERS)

func next_step() -> void:
	step += 1
	var steps: Array = chapter()["steps"]
	if step >= steps.size():
		ch += 1
		step = 0
		if ch >= chapters():
			ch = chapters() - 1
			_credits("ГЛАВА 1 ПРОЙДЕНА", "Это пока вся игра. Дальше будет открытый мир — продолжение следует.")
			return
		_load_chapter(true)
	_save()
	_run_step()

func _run_step() -> void:
	var s: Dictionary = chapter()["steps"][step]
	step_done_t = -1.0
	match String(s["t"]):
		"dlg":
			_clear_fight()
			start_dialog(s["l"], _dlg_done)
		"fight":
			mode = "fight"
			waves = s["w"]
			wave_i = -1
			wave_wait = 1.2
			pending = []
		"boss":
			mode = "boss"
			boss_e = _make_enemy("", String(s["id"]), Vector3(0, 0, -7))
			var b: Dictionary = story["BOSS"][s["id"]]
			banner(String(b["n"]), String(b["sub"]), Color(b["c"]), 3.2)
			boss_name.text = "%s — %s" % [b["n"], b["sub"]]
			main.sfx("sfx_rage", -4.0, 0.7)
		"give":
			toast(String(s.get("msg", "")))
			var o: Dictionary = s.get("o", {})
			if o.has("hp"):
				player.max_hp += float(o["hp"])
			player.hp = player.max_hp
			next_step()
		"shop":
			_open_shop()
		"choice":
			_open_choice()
		_:
			next_step()

func _clear_fight() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies = []
	for b in bolts:
		if is_instance_valid(b["n"]):
			b["n"].queue_free()
	bolts = []
	for z in zones:
		if is_instance_valid(z["n"]):
			z["n"].queue_free()
	for z2 in zones:
		if z2.has("safe_n") and is_instance_valid(z2["safe_n"]):
			z2["safe_n"].queue_free()
	zones = []
	for l in lobs:
		if is_instance_valid(l["n"]):
			l["n"].queue_free()
	lobs = []
	pending = []
	boss_e = null

func paused_story() -> bool:
	return mode == "dlg" or mode == "shop" or mode == "choice" or mode == "end"

# ---------------- бой ----------------
func _update_fight(dt: float) -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	squad_t -= dt
	if squad_t <= 0.0:
		squad_t = 0.2
		EnemyAI.squad(self)            # роли в группе 5 раз в секунду, не каждый кадр
	var alive := enemies.filter(func(e): return e.state != "dead").size()
	if mode == "fight":
		if spawn_cd > 0.0:
			spawn_cd -= dt
		if not pending.is_empty() and alive < MAX_ALIVE and spawn_cd <= 0.0:
			spawn_enemy(pending.pop_front(), Vector3.INF)
			spawn_cd = 0.3
		elif pending.is_empty() and alive == 0 and step_done_t < 0.0:
			wave_wait -= dt
			if wave_wait <= 0.0:
				wave_i += 1
				if wave_i >= waves.size():
					step_done_t = 1.4
					banner("ЧИСТО", "", Color(1, 0.85, 0.3), 1.6)
					bark("clear", 6.0)
					fx.twinkle(player.global_position + Vector3(0, 1.0, 0), 14, Color(1, 0.85, 0.4), 1.0)
				else:
					for grp in waves[wave_i]:
						for i in int(grp[1]):
							pending.append(String(grp[0]))
					pending.shuffle()
					if waves.size() > 1:
						toast("Волна %d / %d" % [wave_i + 1, waves.size()])
					main.sfx("sfx_wave", -8.0)
					wave_wait = 1.6
	elif mode == "boss" or training != null or golda != null:
		if boss_e and is_instance_valid(boss_e):
			boss_fill.size.x = 596.0 * clamp(boss_e.hp / boss_e.max_hp, 0.0, 1.0)
			if auto_kill > 0.0 and boss_e.alive() and boss_e.age > 5.0:
				boss_e.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	if step_done_t >= 0.0:
		step_done_t -= dt
		if step_done_t < 0.0 and not over:
			player.hp = min(player.max_hp, player.hp + player.max_hp * 0.35)
			fx.twinkle(player.global_position + Vector3(0, 1.0, 0), 18, Color(0.45, 1.0, 0.55), 0.8)
			next_step()
	if auto_kill > 0.0:
		for e in enemies:
			if e.alive() and e.boss_id == "" and e.age > auto_kill:
				e.take_hit(99999.0, Vector3.FORWARD, 2.0, true)

func _make_enemy(kind: String, boss_id: String, pos: Vector3):
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = kind
	e.boss_id = boss_id
	e.game = self
	# место — до add_child: в _ready враг рисует портал появления и пыль у себя под ногами,
	# а без этого они оказывались в центре арены (красный круг, из которого никто не выходит)
	e.position = pos
	add_child(e)
	e.global_position = pos
	e.face = atan2(player.global_position.x - pos.x, player.global_position.z - pos.z)
	enemies.append(e)
	return e

func spawn_enemy(kind: String, pos: Vector3) -> void:
	if enemies.size() > 26:
		return
	if pos == Vector3.INF or not in_arena(pos, 1.0):
		for n in 20:
			var a := randf() * TAU
			pos = Vector3(cos(a), 0, sin(a)) * randf_range(7.0, 12.5)
			if pos.distance_to(player.global_position) > 6.0:
				break
	pos.y = 0.05
	_make_enemy(kind, "", pos)

func melee_attackers() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.boss_id == "" and (e.state == "wind" or e.state == "charge" or (e.state == "recover" and e.t < 0.25)) and not e.cfg.has("ranged") and not e.cfg.has("summoner"):
			n += 1
	return n

func in_arena(p: Vector3, margin: float) -> bool:
	if in_hall:
		return p.x > -2.2 + margin * 0.5 and p.x < 3.7 - margin * 0.5 and abs(p.z) < 4.7 - margin * 0.5
	return abs(p.x) < ARENA - margin and abs(p.z) < ARENA - margin

func on_kill(e) -> void:
	kills += 1
	if golda != null:
		golda.on_kill(e)             # приквел: свои награды, опыта и сюжета кампании нет
		return
	if training != null:
		training.on_kill(e)          # арена: без опыта, без сюжета
		return
	if e.fly:
		bark("cheer", 16.0, 0.25)
	xp += int(e.cfg.get("xp", 10))
	player.swag = min(100.0, player.swag + 6.0)
	if e.boss_id != "":
		slowmo(1.6)
		shake(0.9)
		fx.slam(e.global_position, 1.8, Color(e.boss["c"]))
		punch(1.0, e.global_position + Vector3(0, 1.2, 0))
		main.sfx("sfx_boom", 2.0, 0.7)
		fx.lightning(e.global_position, e.height * 2.4, Color(e.boss["c"]))
		bark("boss", 3.0)
		banner("СЕРВЕР ЗАЧИЩЕН", "%s повержен" % String(e.boss["n"]), Color(1, 0.85, 0.3), 3.0)
		for o in enemies:
			if o != e and is_instance_valid(o) and o.alive():
				var away: Vector3 = o.global_position - e.global_position
				away.y = 0
				o.take_hit(99999.0, away.normalized() if away.length() > 0.1 else Vector3.FORWARD, 9.0, true, 6.0)
		step_done_t = 3.2
	elif mode == "fight" and pending.is_empty():
		var left := enemies.filter(func(x): return is_instance_valid(x) and x.state != "dead").size()
		if left == 0:
			slowmo(0.6)

func on_player_dead() -> void:
	if golda != null:
		golda.on_dead()              # приквел: своя гибель, сюжет и постоянное не стираются
		return
	if training != null:
		training.on_dead()           # арена: гибель — не поражение
		return
	bark("dead", 3.0)
	over = true
	slowmo(1.2)
	if main.testing() != "":            # бот в прогонах сцену не смотрит
		await get_tree().create_timer(2.2, true, false, true).timeout
		_retry()
		return
	# сцена гибели: камера, чёрно-белый кадр, надпись и кнопки — scripts/death.gd; она же — открытое окно (panel)
	_close_panel()
	death = DeathSeq.new()
	death.game = self
	hud.add_child(death)
	panel = death

func _retry() -> void:
	_close_panel()
	over = false
	player.hp = player.max_hp
	tag.reset()
	hype.value = 0.0
	player.state = "move"
	player.swag = 0.0
	player.rage = 0.0
	player.rig.play("Idle", 0.1)
	player.global_position = Vector3(0, 0.05, 4)
	_clear_fight()
	boss_box.visible = false
	if main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	_run_step()

# ---------------- снаряды и зоны удара ----------------
## extra: "turn" — сила наведения (по умолчанию 1,6), "slow" — замедляет героя на столько секунд
func spawn_bolt(pos: Vector3, vel: Vector3, dmg: float, owner_e, homing := false, col := Color(0.4, 1.0, 0.55), extra := {}) -> void:
	if bolts.size() >= 60:
		return                       # предел снарядов в арене
	var n: Node3D = fx.bolt(col, homing)
	n.global_position = pos
	bolts.append({"n": n, "v": vel, "dmg": dmg, "life": 3.0 if homing else 2.4, "from": owner_e, "homing": homing, "col": col, "turn": float(extra.get("turn", 1.6)) if float(extra.get("turn", 0.0)) > 0.0 else 1.6, "slow": float(extra.get("slow", 0.0))})

func _update_bolts(dt: float) -> void:
	var pp: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	for b in bolts.duplicate():
		b["life"] -= dt
		var n: Node3D = b["n"]
		if b["homing"]:
			var want: Vector3 = (pp - n.global_position).normalized() * (b["v"] as Vector3).length()
			b["v"] = (b["v"] as Vector3).lerp(want, 1.0 - exp(-float(b["turn"]) * dt))
		n.global_position += b["v"] * dt
		if n.global_position.distance_to(pp) < 0.7:
			var was_inv: bool = player.inv > 0.0
			player.take_damage(b["dmg"], n.global_position, b["from"] if is_instance_valid(b["from"]) else null)
			if float(b["slow"]) > 0.0 and not was_inv:
				player.slow_t = max(player.slow_t, float(b["slow"]))
			b["life"] = 0.0
		if b["life"] <= 0.0 or not in_arena(n.global_position, -1.0):
			fx.bolt_pop(n.global_position, b["col"])
			n.queue_free()
			bolts.erase(b)

## круг на земле: через delay секунд бьёт всех внутри радиуса.
## extra: "col" — цвет; "chase": сек — до этого момента круг едет за героем (печать); "stamp" — падает плита;
## "bolt" — бьёт молния; "pool": сек — после взрыва остаётся ядовитая лужа.
func telegraph(pos: Vector3, radius: float, delay: float, dmg: float, owner_e, extra := {}) -> void:
	var col: Color = extra.get("col", Color(1.0, 0.16, 0.08))
	var z: Dictionary = fx.zone(pos, radius, col)
	z.merge({"kind": "tele", "t": delay, "t0": delay, "r": radius, "dmg": dmg, "from": owner_e, "col": col})
	z.merge(extra)
	zones.append(z)

## расходящееся кольцо: бьёт, когда проходит через игрока (перекат спасает)
func expanding_ring(pos: Vector3, max_r: float, dur: float, dmg: float, owner_e) -> void:
	var z: Dictionary = fx.wave_ring(pos, Color(1.0, 0.35, 0.15))
	z.merge({"kind": "ring", "t": dur, "t0": dur, "r": max_r, "dmg": dmg, "from": owner_e, "hit": false})
	zones.append(z)

## лужа: пока стоишь в ней — получаешь урон
func pool(pos: Vector3, radius: float, dur: float, dmg: float, owner_e, col: Color) -> void:
	var z: Dictionary = fx.pool(pos, radius, col)
	z.merge({"kind": "pool", "t": dur, "t0": dur, "r": radius, "dmg": dmg, "from": owner_e, "tick": 0.3})
	zones.append(z)

## луч, который босс водит вокруг себя: сначала тонкий (предупреждение), потом бьёт
func sweep(owner_e, length: float, dur: float, speed: float, dmg: float, col: Color, a0: float) -> void:
	var n: Node3D = fx.beam(length, col)
	n.global_position = owner_e.global_position
	n.rotation.y = a0
	zones.append({"kind": "sweep", "n": n, "t": dur, "t0": dur, "r": length, "dmg": dmg, "from": owner_e, "a": a0, "w": speed, "warm": 0.9, "cd": 0.0})

## вся арена взрывается, кроме безопасного круга
func wipe(safe: Vector3, radius: float, delay: float, dmg: float, owner_e, col: Color) -> void:
	var z: Dictionary = fx.wipe(safe, radius, col)
	z.merge({"kind": "wipe", "t": delay, "t0": delay, "r": radius, "dmg": dmg, "from": owner_e, "col": col})
	zones.append(z)
	toast("В круг!")

## снаряд по дуге (посылка, плевок) — только картинка; урон даёт круг на земле с тем же временем
func lob(from: Vector3, to: Vector3, time: float, col: Color, box := true) -> void:
	var n: Node3D = fx.parcel(col, box)
	n.global_position = from
	lobs.append({"n": n, "a": from, "b": Vector3(to.x, 0.3, to.z), "t": 0.0, "T": time})

func _update_lobs(dt: float) -> void:
	for l in lobs.duplicate():
		l["t"] += dt
		var k: float = clamp(l["t"] / l["T"], 0.0, 1.0)
		var n: Node3D = l["n"]
		n.global_position = (l["a"] as Vector3).lerp(l["b"], k) + Vector3(0, 5.0 * k * (1.0 - k), 0)
		n.rotation += Vector3(7.0, 5.0, 3.0) * dt
		if k >= 1.0:
			n.queue_free()
			lobs.erase(l)

func _update_zones(dt: float) -> void:
	var pp: Vector3 = player.global_position
	for z in zones.duplicate():
		z["t"] -= dt
		var n: Node3D = z["n"]
		var k: float = 1.0 - clamp(z["t"] / z["t0"], 0.0, 1.0)
		var src = z["from"] if is_instance_valid(z["from"]) else null
		var d := Vector2(pp.x - n.global_position.x, pp.z - n.global_position.z).length()
		var done: bool = z["t"] <= 0.0
		var r0: float = z["r"]
		match String(z["kind"]):
			"ring":
				var r: float = 0.5 + (r0 - 0.5) * k
				(z["a"] as Node3D).scale = Vector3.ONE * r / 0.42
				(z["b"] as Node3D).scale = Vector3.ONE * r * 0.84 / 0.42
				if not z["hit"] and abs(d - r) < 0.55:
					z["hit"] = true
					player.take_damage(z["dmg"], n.global_position, src)
			"tele":
				if z.has("chase") and z["t"] > float(z["chase"]):
					n.global_position = n.global_position.lerp(Vector3(pp.x, 0.0, pp.z), 1.0 - exp(-7.0 * dt))
				# заливка растёт до ободка, руны крутятся, ободок мигает всё чаще — видно, сколько осталось
				(z["fill"] as Node3D).scale = Vector3.ONE * max(0.01, r0 / 0.4 * k)
				(z["rune"] as Node3D).rotation.y += dt * 2.5
				((z["rim"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.6 + 0.4 * sin(clock * (9.0 + 20.0 * k))
				if done:
					var col: Color = z["col"]
					if z.has("bolt"):
						fx.lightning(n.global_position, 7.5, col)
						fx.scorch(n.global_position, r0 * 1.6, col)
						main.sfx("sfx_crack", -5.0, 1.3)
						shake(0.2)
					elif z.has("stamp"):
						fx.stamp(n.global_position, r0, col)
						fx.slam(n.global_position, 1.5, col)
						main.sfx("sfx_boom", -1.0, 0.8)
						shake(0.45)
					else:
						fx.slam(n.global_position, clampf(r0 / 2.2, 0.6, 1.3), col)
						main.sfx("sfx_boom", -6.0, 1.2)
						shake(0.18)
					if d < r0:
						player.take_damage(z["dmg"], n.global_position, src)
					if z.has("pool"):
						pool(n.global_position, r0, float(z["pool"]), float(z["dmg"]) * 0.4, src, col)
			"pool":
				var a: float = min(1.0, k * 10.0) * min(1.0, float(z["t"]) / 0.7)
				((z["a"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = a * (0.45 + 0.12 * sin(clock * 5.0))
				((z["b"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = a * 0.85
				(z["b"] as Node3D).rotation.y += dt * 0.8
				z["tick"] = float(z["tick"]) - dt
				if d < r0 and float(z["tick"]) <= 0.0:
					z["tick"] = 0.6
					player.take_damage(z["dmg"], n.global_position + Vector3(0.01, 0, 0.01), src)
					fx.twinkle(pp + Vector3(0, 0.5, 0), 6, ((z["b"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color, 0.5)
			"sweep":
				if src == null or src.state == "dead" or src.state == "stun":
					done = true
				else:
					var warm: bool = float(z["t0"]) - float(z["t"]) < float(z["warm"])
					if not warm:
						z["a"] = float(z["a"]) + float(z["w"]) * dt
					var ang: float = z["a"]
					n.global_position = src.global_position
					n.rotation.y = ang
					n.scale = Vector3(0.2 if warm else 1.0, 0.3 if warm else 1.0, 1.0)
					src.face = ang + PI   # босс показывает рукой вдоль луча
					z["cd"] = float(z["cd"]) - dt
					var dir := Vector3(-sin(ang), 0, -cos(ang))
					var to: Vector3 = pp - src.global_position
					to.y = 0
					var along := to.dot(dir)
					if not warm and float(z["cd"]) <= 0.0 and along > 0.8 and along < r0 and abs(to.x * dir.z - to.z * dir.x) < 0.75:
						z["cd"] = 0.7
						player.take_damage(z["dmg"], src.global_position, src)
			"wipe":
				var sn: Node3D = z["safe_n"]
				(z["rune"] as Node3D).rotation.y += dt * 2.0
				((z["danger"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.1 + 0.3 * k + 0.08 * sin(clock * (8.0 + 22.0 * k))
				if done:
					var wc: Color = z["col"]
					var ds := Vector2(pp.x - sn.global_position.x, pp.z - sn.global_position.z).length()
					for i in 10:
						var at := Vector3(randf_range(-11, 11), 0, randf_range(-11, 11))
						if at.distance_to(sn.global_position) > r0 + 1.0:
							fx.pillar(at, 5.0, wc)
					fx.ground_ring(Vector3.ZERO, 2.0, 34.0, wc, 0.6)
					punch(1.0, pp + Vector3(0, 1, 0))
					shake(0.7)
					main.sfx("sfx_boom", 2.0, 0.6)
					if ds > r0:
						player.take_damage(z["dmg"], Vector3(pp.x, 0, pp.z + 0.5), src)
					sn.queue_free()
		if done:
			if z.has("safe_n") and is_instance_valid(z["safe_n"]):
				(z["safe_n"] as Node3D).queue_free()
			n.queue_free()
			zones.erase(z)





# ---------------- камера ----------------
func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.6
	spring.collision_mask = 8
	spring.margin = 0.2
	pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 250.0
	cam_attributes = CameraAttributesPractical.new()
	cam_attributes.dof_blur_far_enabled = false
	cam_attributes.dof_blur_far_distance = 5.4
	cam_attributes.dof_blur_far_transition = 5.8
	cam_attributes.dof_blur_near_enabled = false
	cam_attributes.dof_blur_amount = 0.0
	cam.attributes = cam_attributes
	ipod_focus_quality = 0.55 if OS.has_feature("mobile") else 1.0
	spring.add_child(cam)
	cam.make_current()

func _unhandled_input(e: InputEvent) -> void:
	if intro_busy():           # вступительный облёт: ни паузы, ни диалога, ни ад-либа
		return
	if ipod != null and ipod.captures_gameplay_input():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mode != "dlg":
		var sens := float(Opts.v("sens"))
		cam_yaw -= e.relative.x * 0.0028 * sens
		cam_pitch = clamp(cam_pitch - e.relative.y * 0.0022 * sens * (-1.0 if bool(Opts.v("invert_y")) else 1.0), -1.1, 0.35)
	if mode == "dlg":
		if e.is_action_pressed("attack") or e.is_action_pressed("jump") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ENTER):
			_dlg_advance()
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_TAB:
			_dlg_finish()
		return
	if over:
		return
	if e.is_action_pressed("pause") and panel == null and not get_tree().paused:
		set_paused(true)      # закрывает паузу само меню: пока игра стоит, этот узел ввода не получает
	if lock != null and lock.usable():
		if e.is_action_pressed("lock"):
			lock.toggle()
		elif e.is_action_pressed("lock_next"):
			lock.cycle(1)
		elif e.is_action_pressed("lock_prev"):
			lock.cycle(-1)
	if e.is_action_pressed("adlib") and not get_tree().paused and not paused_story():
		if madk_locked():
			madk_note()
		elif not buddy.adlib():
			popup(buddy.global_position + Vector3(0, 2.1, 0), "перезарядка", Color(0.6, 0.7, 0.8))

func shake(a: float) -> void:
	trauma = min(1.0, trauma + a * float(Opts.v("shake")))      # настройка «тряска камеры» (0…100 %)

## не добавляет, а держит тряску не ниже заданной (заряд, гул)
func rumble(a: float) -> void:
	trauma = max(trauma, a * float(Opts.v("shake")))

## Отклик экрана на сильный удар: цветной разлёт по краям, размытие от центра, волна от точки удара, толчок обзора.
func punch(k: float, pos: Vector3) -> void:
	pp["aberr"] = max(float(pp["aberr"]), k)
	pp["blur"] = max(float(pp["blur"]), k * 0.7)
	fov_kick = max(fov_kick, 5.0 * k)
	var c := get_viewport().get_camera_3d()
	if c and not c.is_position_behind(pos):
		ripple_c = c.unproject_position(pos) / get_viewport().get_visible_rect().size
		pp["ripple_a"] = k
		pp["ripple_t"] = 0.0
	if k >= 0.9 and clock - last_flash > 0.4 and not bool(Opts.v("less_flash")):   # вспышка экрана не чаще двух-трёх раз в секунду
		last_flash = clock
		pp["flash"] = 0.13

## Один вызов на попадание: стоп-кадр, тряска и экранный отклик по силе удара (0 — лёгкий, 1 — тяжёлый, 2 — добивание).
func impact(tier: int, pos: Vector3, mul := 1.0) -> void:
	feedback(["hit_light", "hit_heavy", "hit_super"][clampi(tier, 0, 2)], pos, Vector3.ZERO, mul)

## Смена героя (Tab): игрок берёт под управление напарника, прежний герой становится напарником.
## Герои меняются местами — управление переходит к тому, кто стоял рядом.
func swap_heroes(quiet := false) -> bool:
	if paused_story() or over or player.state == "dead" or madk_locked():
		return false
	var a: Vector3 = player.global_position
	var b: Vector3 = buddy.global_position
	var fa: float = player.face
	var fb: float = buddy.face
	var next := "madk1d" if player.hero == "pahan" else "pahan"
	buddy.set_look(player.hero)
	player.set_hero(next)
	player.global_position = b
	player.face = fb
	player.velocity = Vector3.ZERO
	buddy.global_position = a
	buddy.face = fa
	buddy.target = a
	buddy.wait = 1.2
	buddy.velocity = Vector3.ZERO
	feedback("tag", b, Vector3.ZERO, 1.0, Color(0.36, 0.82, 1.0) if next == "madk1d" else Color(1.0, 0.8, 0.42))
	fx.ground_ring(a, 0.4, 2.0, Color(1, 1, 1, 0.4), 0.3)
	player.anim.action("tag_in", 0.45, 0.25)
	if not quiet:      # AIR TAG передаёт быстро и часто: без надписи на весь экран
		banner("MADK1D" if next == "madk1d" else "ПАХАН", "в бою", Color(0.36, 0.82, 1.0) if next == "madk1d" else Color(1.0, 0.8, 0.42))
	return true

## Отклик боя по имени события: таблица каналов — в feedback.gd.
func feedback(name: String, pos: Vector3, dir := Vector3.ZERO, mul := 1.0, col := Color(1.0, 0.82, 0.45)) -> void:
	Feedback.fire(self, name, pos, dir, mul, col)

func heat_cam(sec: float) -> void:
	heat_t = sec

func hitstop(sec: float) -> void:
	stop_until = max(stop_until, clock + sec)

func slowmo(sec: float) -> void:
	slow_until = max(slow_until, clock + sec)

func _process(dt: float) -> void:
	var rdt: float = dt / max(Engine.time_scale, 0.001)
	clock += rdt
	heat_t = max(0.0, heat_t - rdt)
	Engine.time_scale = 0.05 if clock < stop_until else (0.3 if clock < slow_until else (0.45 if heat_t > 0.0 else 1.0))
	if director:
		Engine.time_scale *= director.slow
	if director:
		director.frame(rdt)
	if lock != null:
		lock.camera_tick(rdt)          # захват цели мягко ведёт cam_yaw / cam_pitch (если камерой никто другой не владеет)
	var target: Vector3 = player.vis_pos() + Vector3(0, 1.55, 0)      # плавное положение: без дрожи между шагами физики
	var want_len := 4.6
	var yaw := cam_yaw
	var pitch := cam_pitch
	if mode == "dlg" and not director:
		# диалог: камера спереди-сбоку, на героев
		target = (player.vis_pos() + buddy.global_position) * 0.5 + Vector3(0, 1.25, 0)
		yaw = dlg_face - 0.5   # камера перед героями, чуть сбоку: видно оба лица
		pitch = -0.08
		want_len = 4.0
		if dlg_partner != null and is_instance_valid(dlg_partner):
			# разговор с жителем: двое в профиль, камера сбоку
			target = (player.vis_pos() + (dlg_partner as Node3D).global_position) * 0.5 + Vector3(0, 1.15, 0)
			yaw = dlg_face + dlg_side * 1.35
			want_len = 4.3
	elif heat_t > 0.0:
		want_len = 2.9
	if hype != null and hype.active() and not (mode == "dlg" and not director):
		# Team Overdrive: общий план на всю команду и врагов, чуть сверху; облёт ведёт hype.gd
		var ok_k: float = hype.cam_k()
		target = target.lerp(hype.center + Vector3(0, 1.3, 0), 0.6 * ok_k)
		want_len = lerpf(want_len, 7.2, ok_k)
		pitch = lerpf(pitch, -0.42, ok_k)
	# iPod only adds a cinematic 13% dolly to the distance chosen by the normal
	# camera state. SpringArm3D still owns the final collision-safe camera position.
	# подброс: камера ведёт взгляд выше и чуть отъезжает, чтобы враг в воздухе оставался в кадре
	var top := 0.0
	if mode != "dlg":
		for en in enemies:
			if is_instance_valid(en) and en.alive() and en.state == "air" and en.global_position.distance_to(player.global_position) < 6.0:
				top = max(top, en.global_position.y - player.global_position.y)
	air_lift = lerpf(air_lift, clampf(top * 0.45, 0.0, 1.4), 1.0 - exp(-5.0 * rdt))
	target.y += air_lift
	want_len += air_lift * 0.9
	want_len *= 1.0 - 0.13 * ipod_focus
	if not director or not director.owns_camera():
		pivot.global_position = pivot.global_position.lerp(target, 1.0 - exp(-14.0 * rdt)) if pivot.global_position != Vector3.ZERO else target
		pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw, 1.0 - exp(-9.0 * rdt)) if mode == "dlg" else yaw
		pivot.rotation.x = lerp(pivot.rotation.x, pitch, 1.0 - exp(-9.0 * rdt)) if mode == "dlg" else pitch
		var spring_rate := lerpf(8.0, 7.0, ipod_focus)
		spring.spring_length = lerp(spring.spring_length, want_len, 1.0 - exp(-spring_rate * rdt))
		# A restrained lateral/upward offset keeps Pahan readable beside the lower-right UI.
		spring.position = Vector3(0.55 + 0.12 * ipod_focus, 0.04 * ipod_focus, 0)
	# тряска: сумма синусов разной частоты (плавно, без дребезга), сила — квадрат накопленного; гаснет в реальном времени
	trauma = max(0.0, trauma - rdt * 1.5)
	shake_t += rdt * 34.0
	var sh := trauma * trauma
	var ox := sh * 0.2 * (sin(shake_t * 1.7) + 0.5 * sin(shake_t * 3.1 + 1.3))
	var oy := sh * 0.16 * (sin(shake_t * 2.3 + 0.7) + 0.5 * sin(shake_t * 4.3))
	var roll := sh * 0.045 * sin(shake_t * 1.1 + 2.0)
	cam.h_offset = ox
	cam.v_offset = oy
	cam.rotation.z = roll
	if director:
		director.cam.h_offset = ox
		director.cam.v_offset = oy
		director.cam.rotation.z += roll
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-9.0 * rdt))
	zoom_s = lerpf(zoom_s, charge_zoom, 1.0 - exp(-6.0 * rdt))
	cam.fov = float(Opts.v("fov")) + fov_kick - 9.0 * zoom_s
	if intro_t >= 0.0:
		_intro_camera(rdt)
	if death != null and is_instance_valid(death) and death.owns_camera():
		cam.global_transform = death.camera()      # камеру ведёт сцена гибели
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	elif golda != null and golda.owns_camera():
		cam.global_transform = golda.camera()      # постановка приквела (выход босса)
	cam_attributes.dof_blur_far_enabled = ipod_focus > 0.002
	# A restrained DOF pass establishes depth; the lightweight screen pass below
	# supplies the remaining focus separation without turning the world to mush.
	cam_attributes.dof_blur_amount = 0.285 * ipod_focus
	_update_post(rdt)
	if world:
		world.follow(player.global_position)
	_update_hud(rdt)
	if mode == "dlg":
		var to_b: Vector3 = buddy.global_position - player.global_position
		if to_b.length() > 0.3 and to_b.length() < 4.0:
			var tk := 1.0 - exp(-7.0 * rdt)
			player.face = lerp_angle(player.face, lerp_angle(dlg_face, atan2(to_b.x, to_b.z), 0.78), tk)
			buddy.face = lerp_angle(buddy.face, lerp_angle(dlg_face, atan2(-to_b.x, -to_b.z), 0.78), tk)
	if mode == "exit":
		# метка у двери пульсирует; дошёл до проёма — выходим во двор
		if exit_mark:
			exit_mark.scale = Vector3.ONE * (2.0 + 0.25 * sin(clock * 4.0))
		if player.global_position.z < -3.9 and abs(player.global_position.x) < 1.4:
			_exit_hall()
	if mode == "dlg":
		_update_dialog(rdt)
	elif not over:
		_update_bolts(dt)
		_update_zones(dt)
		_update_lobs(dt)
		_update_fight(dt)
	if main.voicecheck:
		auto_t += rdt
		peak_db = max(peak_db, AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Voice"), 0))
		if mode == "dlg" and auto_t > 0.6:
			auto_t = -0.9
			print("VOICE строка %d: pos=%.2f playing=%s пик=%.1f дБ" % [dlg_i, voice.get_playback_position(), voice.playing, peak_db])
			peak_db = -200.0
			if dlg_i == 6:
				_shot(OS.get_user_data_dir(), "voicecheck.png")   # кадр диалога: видно, как стоят герои
			if dlg_i == 7:
				pause_panel.open()   # и кадр меню паузы
				_shot(OS.get_user_data_dir(), "pausecheck.png")
			if dlg_i == 8:
				pause_panel.shut()
			dlg_chars = 9999.0
			_dlg_advance()
		if mode != "dlg" or dlg_i > 9:
			get_tree().quit()
	if main.autotest != "" or main.smoke != "":
		_autotest(rdt)

# ---------------- экранные эффекты ----------------
const POST := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float aberr = 0.0;
uniform float blur = 0.0;
uniform float ripple_a = 0.0;
uniform float ripple_t = 0.0;
uniform vec2 ripple_c = vec2(0.5);
uniform float vign = 0.0;
uniform float flash = 0.0;
uniform float lines = 0.0;
uniform float aspect = 1.777;
uniform float mono = 0.0;
uniform float focus = 0.0;
uniform float focus_motion = 0.0;
uniform float focus_quality = 1.0;
uniform vec2 focus_subject = vec2(0.45, 0.55);
uniform vec2 focus_ui = vec2(0.74, 0.58);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	if (ripple_a > 0.001) {
		vec2 rd = (uv - ripple_c) * vec2(aspect, 1.0);
		float w = length(rd) - ripple_t * 0.95;
		float band = exp(-w * w * 160.0) * (1.0 - ripple_t);
		uv += normalize(rd + vec2(0.00001)) / vec2(aspect, 1.0) * band * ripple_a * 0.035;
	}
	vec2 ca = d * aberr * 0.022;
	vec3 col;
	if (blur > 0.01) {
		col = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			vec2 o = d * blur * 0.11 * float(i) / 8.0;
			col.r += texture(screen, uv - o - ca).r;
			col.g += texture(screen, uv - o).g;
			col.b += texture(screen, uv - o + ca).b;
		}
		col /= 8.0;
	} else {
		col = vec3(texture(screen, uv - ca).r, texture(screen, uv).g, texture(screen, uv + ca).b);
	}
	if (focus > 0.001) {
		float subject_distance = length((uv - focus_subject) * vec2(aspect, 1.0));
		float subject_protection = 1.0 - smoothstep(0.075, 0.27, subject_distance);
		float local_focus = focus * mix(1.0, 0.42, subject_protection);
		float lod = mix(0.16, 1.42, local_focus) * mix(0.82, 1.0, focus_quality);
		vec2 px = SCREEN_PIXEL_SIZE * mix(1.1, 4.8, local_focus);
		vec3 soft = textureLod(screen, uv, lod).rgb * 2.0;
		soft += textureLod(screen, uv + vec2( 1.0, 0.0) * px, lod).rgb;
		soft += textureLod(screen, uv + vec2(-1.0, 0.0) * px, lod).rgb;
		soft += textureLod(screen, uv + vec2(0.0,  1.0) * px, lod).rgb;
		soft += textureLod(screen, uv + vec2(0.0, -1.0) * px, lod).rgb;
		float weight = 6.0;
		if (focus_quality > 0.75) {
			soft += textureLod(screen, uv + vec2( 0.72,  0.72) * px, lod).rgb;
			soft += textureLod(screen, uv + vec2(-0.72,  0.72) * px, lod).rgb;
			soft += textureLod(screen, uv + vec2( 0.72, -0.72) * px, lod).rgb;
			soft += textureLod(screen, uv + vec2(-0.72, -0.72) * px, lod).rgb;
			weight = 10.0;
		}
		soft /= weight;
		// No highlight bloom here: bright lamps stay compact instead of smearing.
		col = mix(col, soft, local_focus * 0.44);
		vec3 grey = vec3(dot(col, vec3(0.2126, 0.7152, 0.0722)));
		col = mix(grey, col, 1.0 - 0.08 * focus);
		col *= 1.0 - 0.14 * focus;
	}
	float len = length(d * vec2(aspect, 1.0));
	if (lines > 0.01) {
		float ang = atan(d.y, d.x * aspect);
		float n = fract(sin(floor(ang * 46.0) * 12.9898 + floor(TIME * 20.0) * 78.233) * 43758.5453);
		col += vec3(smoothstep(0.3 + n * 0.35, 0.95, len) * step(0.62, n) * lines * 0.5);
	}
	if (focus_motion > 0.001) {
		float rays = pow(max(0.0, dot(normalize(d + vec2(0.0001)), normalize(vec2(-0.8, 0.55)))), 18.0);
		float broken = step(0.55, fract((d.x - d.y) * 37.0));
		col += vec3(0.11, 0.14, 0.17) * rays * broken * focus_motion * smoothstep(0.18, 0.7, len);
	}
	// A broad, off-centre vignette leaves the composition readable while guiding
	// the eye toward the sharp foreground iPod on the right.
	vec2 attention_delta = (uv - focus_ui) * vec2(aspect, 1.0);
	float attention_edge = smoothstep(0.44, 1.18, length(attention_delta));
	col *= 1.0 - attention_edge * focus * 0.17;
	col *= 1.0 - smoothstep(0.35, 1.0, len) * vign;
	if (mono > 0.001) {
		// сцена гибели: цвет уходит, кадр темнеет к краям, появляется плёночное зерно
		float gl = dot(col, vec3(0.2126, 0.7152, 0.0722));
		gl = mix(gl, smoothstep(0.02, 0.92, gl), 0.6 * mono);
		col = mix(col, vec3(gl), mono);
		col *= 1.0 - 0.3 * mono;
		col *= 1.0 - smoothstep(0.3, 1.05, len) * 0.62 * mono;
		float gn = fract(sin(dot(uv * 1000.0 + floor(TIME * 24.0) * 7.31, vec2(12.9898, 78.233))) * 43758.5453);
		col += (gn - 0.5) * 0.09 * mono;
	}
	col += vec3(flash);
	COLOR = vec4(col, 1.0);
}
"""

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST
	post_mat = ShaderMaterial.new()
	post_mat.shader = sh
	post.material = post_mat
	post.visible = false
	layer.add_child(post)

func _update_post(rdt: float) -> void:
	pp["aberr"] = max(0.0, float(pp["aberr"]) - rdt * 3.2)
	pp["blur"] = max(0.0, float(pp["blur"]) - rdt * 3.4)
	pp["flash"] = max(0.0, float(pp["flash"]) - rdt * 1.1)
	if float(pp["ripple_a"]) > 0.0:
		pp["ripple_t"] = float(pp["ripple_t"]) + rdt * 2.4
		if float(pp["ripple_t"]) >= 1.0:
			pp["ripple_a"] = 0.0
	var heat := 1.0 if heat_t > 0.0 else 0.0
	var vg: float = 0.45 * zoom_s + 0.35 * heat + (0.16 if player.rage > 0.0 else 0.0) + 0.14 * ipod_focus
	var ln: float = 0.8 * zoom_s + 0.7 * heat
	var on: bool = float(pp["aberr"]) > 0.01 or float(pp["blur"]) > 0.01 or float(pp["flash"]) > 0.003 or float(pp["ripple_a"]) > 0.0 or vg > 0.01 or ipod_focus > 0.001 or death_mono > 0.001
	post.visible = on
	if not on:
		return
	var vs := get_viewport().get_visible_rect().size
	post_mat.set_shader_parameter("aberr", float(pp["aberr"]) + 0.25 * heat)
	post_mat.set_shader_parameter("blur", float(pp["blur"]))
	post_mat.set_shader_parameter("flash", float(pp["flash"]))
	post_mat.set_shader_parameter("ripple_a", float(pp["ripple_a"]))
	post_mat.set_shader_parameter("ripple_t", float(pp["ripple_t"]))
	post_mat.set_shader_parameter("ripple_c", ripple_c)
	post_mat.set_shader_parameter("vign", vg)
	post_mat.set_shader_parameter("lines", ln)
	post_mat.set_shader_parameter("aspect", vs.x / max(1.0, vs.y))
	post_mat.set_shader_parameter("mono", death_mono)
	post_mat.set_shader_parameter("focus", ipod_focus)
	post_mat.set_shader_parameter("focus_motion", ipod_motion)
	post_mat.set_shader_parameter("focus_quality", ipod_focus_quality)
	post_mat.set_shader_parameter("focus_ui", ipod_attention_point)
	var subject := Vector2(0.45, 0.55)
	if cam != null and player != null and not cam.is_position_behind(player.global_position):
		subject = cam.unproject_position(player.global_position + Vector3(0, 1.15, 0)) / vs
	post_mat.set_shader_parameter("focus_subject", subject)


func set_ipod_visual_focus(amount: float, motion: float, attention_point := Vector2(0.74, 0.58)) -> void:
	ipod_focus = clampf(amount, 0.0, 1.0)
	ipod_motion = clampf(motion, 0.0, 1.0)
	ipod_attention_point = Vector2(clampf(attention_point.x, 0.05, 0.95), clampf(attention_point.y, 0.05, 0.95))

# ---------------- диалоги ----------------
func start_dialog(lines: Array, after: Callable) -> void:
	mode = "dlg"
	dlg = lines
	dlg_i = -1
	dlg_after = after
	dlg_box.visible = true
	player.velocity = Vector3.ZERO
	# кент встаёт рядом
	var side := Vector3(cos(player.face), 0, -sin(player.face))
	var bp: Vector3 = player.global_position + side * 1.3
	if in_arena(bp, 0.6):
		buddy.global_position = bp
	buddy.face = player.face
	dlg_face = player.face
	_dlg_advance()

func _dlg_advance() -> void:
	if dlg_i >= 0 and dlg_chars < dlg_text.text.length():
		dlg_chars = 9999.0
		return
	voice.stop()
	_hush()
	dlg_i += 1
	if dlg_i >= dlg.size():
		_dlg_finish()
		return
	var line := String(dlg[dlg_i])
	var p := line.find("|")
	var code := line.substr(0, p)
	var spk: Dictionary = story["SPK"].get(code, {"n": "", "c": "#ffffff"})
	dlg_name.text = _clean(String(spk["n"]))
	dlg_name.add_theme_color_override("font_color", Color(spk["c"]))
	dlg_text.text = _clean(line.substr(p + 1))
	dlg_text.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9) if code == "N" else Color.WHITE)
	dlg_chars = 0.0
	dlg_voiced = _say(voice, line, 0.0)
	tick_n = 0
	if code == "MV":
		main.sfx("sfx_parry", -10.0)

func _dlg_finish() -> void:
	voice.stop()
	dlg_box.visible = false
	mode = "idle"
	dlg_partner = null
	dlg_after.call()

func _update_dialog(dt: float) -> void:
	dlg_chars += dt * 55.0
	dlg_text.visible_characters = int(dlg_chars)
	# у реплик без голоса (рассказчик, боссы) текст печатается с тихими щелчками
	var shown: int = min(int(dlg_chars), dlg_text.text.length())
	if not dlg_voiced and shown / 3 > tick_n and main.testing() == "":
		tick_n = shown / 3
		main.sfx("sfx_ui", -24.0, 0.7)

func _clean(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 0x1F000 and not (c >= 0x2600 and c <= 0x27BF) and c != 0xFE0F:
			out += s[i]
	return out.strip_edges()

# ---------------- озвучка ----------------
## файл реплики: код говорящего и начало md5 от всей строки «код|текст» — так же называет файлы tools/godot-voice.cjs
func _voice_path(line: String) -> String:
	return "res://assets/voice/%s_%s.mp3" % [line.substr(0, line.find("|")), line.md5_text().substr(0, 10)]

func _say(pl: AudioStreamPlayer, line: String, vol := 0.0) -> bool:
	if main.testing() != "":
		return false
	var path := _voice_path(line)
	if not ResourceLoader.exists(path):
		if main.voicecheck:
			print("VOICE нет файла %s для: %s" % [path.get_file(), line.left(40)])
		return false
	pl.stream = load(path)
	pl.bus = "Voice"
	pl.volume_db = vol
	pl.play()
	if main.voicecheck:
		print("VOICE play %s len=%.2f playing=%s bus=%s vol=%.1f master=%.1f mute=%s" % [path.get_file(), pl.stream.get_length(), pl.playing, pl.bus, pl.volume_db, AudioServer.get_bus_volume_db(0), AudioServer.is_bus_mute(0)])
	return true

## Говорит кто-то один: пока звучит реплика диалога или чей-то выкрик, новый выкрик не начинается (Пахан получил
## удар и вскрикнул — madk1d не причитает поверх него). Предсмертный крик и фраза босса на смене фазы важнее:
## они обрывают прежний выкрик. С началом диалога выкрики смолкают.
func _speaking() -> bool:
	return voice.playing or bark_v.playing or bark_m.playing or bark_b.playing

func _hush() -> void:
	for p in [bark_v, bark_m, bark_b]:
		(p as AudioStreamPlayer).stop()

## Боевой выкрик из data/barks.json: не поверх диалога, не чаще раза в gap секунд на вид, с вероятностью chance.
func bark(kind: String, gap := 8.0, chance := 1.0) -> void:
	if mode == "dlg" or over and kind != "dead" or not barks.has(kind) or clock < float(bark_cd.get(kind, 0.0)) or randf() > chance:
		return
	var arr: Array = barks[kind]
	var line: String = arr[randi() % arr.size()]
	var pl := bark_m if line.begins_with("M") else (bark_v if line.begins_with("V") else bark_b)
	if _speaking():
		if kind != "dead":
			return
		_hush()
	if _say(pl, line, 2.0):
		bark_cd[kind] = clock + gap

# ---------------- эффекты ----------------
func popup(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = main.font
	l.font_size = 48
	l.pixel_size = 0.0042
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func shockwave(pos: Vector3, col: Color) -> void:
	fx.ground_ring(pos, 0.8, 8.0, col, 0.5)
	fx.ground_ring(pos, 0.5, 4.5, Color(1, 1, 1, 0.6), 0.3, "circle_05")
	fx.dust(pos + Vector3(0, 0.15, 0), 10, fx.DUST, 1.2)

func damage_flash() -> void:
	flash.color.a = 0.35
	shake(0.35)
	pp["aberr"] = max(float(pp["aberr"]), 0.6)

func banner(title: String, sub: String, col: Color, sec := 2.6) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_title.add_theme_color_override("font_color", col)
	banner_t = sec

## Приквел «ГОЛДА 67» до первой концовки: madk1d закрыт — управлять им и командными приёмами нельзя
func madk_locked() -> bool:
	return golda != null and not golda.madk_open()

var _madk_note_t := -9.0
## Попытка воспользоваться закрытым: объяснить, когда откроется (не чаще раза в 1,5 с)
func madk_note() -> void:
	if clock - _madk_note_t < 1.5:
		return
	_madk_note_t = clock
	toast(G67Data.MADK_LOCKED)

func toast(text: String) -> void:
	toast_label.text = _clean(text)
	toast_t = 3.5

func boss_bark(who: String, text: String, col: Color, sp := "") -> void:
	if sp != "":
		_hush()
		_say(bark_b, sp + "|" + text, 3.0)
	banner(text, who, col, 2.8)
	main.sfx("sfx_rage", -6.0, 1.2)
	shake(0.4)

# ---------------- интерфейс ----------------
func _lbl(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", main.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var vs := get_viewport().get_visible_rect().size
	flash = ColorRect.new()
	flash.color = Color(0.8, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	var name_l := _lbl("ПАХАН", 26)
	hero_label = name_l
	name_l.position = Vector2(40, vs.y - 150)
	hud_root.add_child(name_l)
	var bars := Control.new()
	bars.position = Vector2(40, vs.y - 110)
	hud_root.add_child(bars)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(420, 26)
	bars.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.9, 0.2, 0.18)
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(414, 20)
	bars.add_child(hp_fill)
	var sw_bg := ColorRect.new()
	sw_bg.color = Color(0, 0, 0, 0.6)
	sw_bg.position = Vector2(0, 34)
	sw_bg.size = Vector2(320, 16)
	bars.add_child(sw_bg)
	swag_fill = ColorRect.new()
	swag_fill.color = Color(1, 0.6, 0.15)
	swag_fill.position = Vector2(3, 37)
	swag_fill.size = Vector2(0, 10)
	bars.add_child(swag_fill)
	swag_label = _lbl("СВЭГ", 15, Color(0.75, 0.78, 0.85))
	swag_label.position = Vector2(332, 30)
	bars.add_child(swag_label)
	q_label = _lbl("", 15, Color(0.4, 0.85, 1))
	q_label.position = Vector2(0, 58)
	bars.add_child(q_label)
	style_label = _lbl("", 15, Color(0.85, 0.88, 0.95))
	style_label.position = Vector2(0, 80)
	bars.add_child(style_label)
	name_l.visible = false
	bars.visible = false
	combat_hud = CombatHud.new()
	hud_root.add_child(combat_hud)
	combat_hud.setup(self)
	top_label = _lbl("", 18, Color(1, 0.9, 0.7))
	top_label.position = Vector2(40, 22)
	hud_root.add_child(top_label)
	xp_label = _lbl("", 18, Color(0.55, 1, 0.6))
	xp_label.position = Vector2(vs.x - 260, 22)
	xp_label.size = Vector2(220, 26)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_root.add_child(xp_label)
	fps_label = _lbl("", 15, Color(0.5, 1, 0.5))
	fps_label.position = Vector2(vs.x - 110, vs.y - 34)
	hud_root.add_child(fps_label)
	toast_label = _lbl("", 20, Color(0.75, 0.9, 1))
	toast_label.position = Vector2(0, 100)
	toast_label.size = Vector2(vs.x, 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(toast_label)
	banner_title = _lbl("", 60)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.position = Vector2(0, 160)
	banner_title.size = Vector2(vs.x, 80)
	hud_root.add_child(banner_title)
	banner_sub = _lbl("", 22, Color(0.9, 0.9, 0.95))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.position = Vector2(0, 240)
	banner_sub.size = Vector2(vs.x, 40)
	hud_root.add_child(banner_sub)
	# полоса босса
	boss_box = Control.new()
	boss_box.position = Vector2(vs.x / 2 - 300, 54)
	boss_box.visible = false
	hud_root.add_child(boss_box)
	var bb := ColorRect.new()
	bb.color = Color(0, 0, 0, 0.65)
	bb.size = Vector2(600, 18)
	bb.position = Vector2(0, 26)
	boss_box.add_child(bb)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(1, 0.3, 0.2)
	boss_fill.position = Vector2(2, 28)
	boss_fill.size = Vector2(596, 14)
	boss_box.add_child(boss_fill)
	boss_name = _lbl("", 18, Color(1, 0.85, 0.8))
	boss_name.size = Vector2(600, 24)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	# диалог
	dlg_box = ColorRect.new()
	(dlg_box as ColorRect).color = Color(0.02, 0.03, 0.06, 0.88)
	dlg_box.position = Vector2(vs.x * 0.12, vs.y - 250)
	dlg_box.size = Vector2(vs.x * 0.76, 190)
	dlg_box.visible = false
	hud.add_child(dlg_box)
	var stripe := ColorRect.new()
	stripe.color = Color(1, 0.25, 0.2)
	stripe.size = Vector2(5, 190)
	dlg_box.add_child(stripe)
	dlg_name = _lbl("", 22)
	dlg_name.position = Vector2(28, 14)
	dlg_box.add_child(dlg_name)
	dlg_text = Label.new()
	dlg_text.add_theme_font_size_override("font_size", 24)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.position = Vector2(28, 52)
	dlg_text.size = Vector2(vs.x * 0.76 - 56, 110)
	dlg_box.add_child(dlg_text)
	var hint := _lbl("ЛКМ / ПРОБЕЛ — ДАЛЕЕ   ·   TAB — ПРОПУСТИТЬ СЦЕНУ", 13, Color(0.55, 0.6, 0.7))
	hint.position = Vector2(28, 162)
	dlg_box.add_child(hint)
	# меню паузы целиком — scripts/pausemenu.gd (вкладки, сцена с Паханом, анимация открытия)
	var pm := PauseMenu.new()
	pm.game = self
	pause_panel = pm
	hud.add_child(pm)

func _make_panel(title: String, sub: String, buttons: Array) -> Control:
	var p := ColorRect.new()
	p.color = Color(0.02, 0.02, 0.025, 0.9)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(p)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	var t := _lbl(title, 64)
	var sf := SystemFont.new()          # заголовки окон — тем же шрифтом с засечками, что меню
	sf.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	sf.font_weight = 900
	t.add_theme_font_override("font", sf)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := _lbl(sub, 20, Color(0.85, 0.85, 0.9))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(900, 0)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(s)
	for b in buttons:
		box.add_child(main.button(b[0], b[1]))
	return p

func _show_panel(title: String, sub: String, buttons: Array) -> void:
	_close_panel()
	panel = _make_panel(title, sub, buttons)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)

func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null

func set_paused(v: bool) -> void:
	if over:
		return
	if v:
		get_tree().paused = true      # мир останавливается сразу; меню раскрывается уже на стоящей игре
		pause_panel.open()
	else:
		pause_panel.shut()
		get_tree().paused = false
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE if v or panel != null or (ipod != null and ipod.captures_gameplay_input()) else Input.MOUSE_MODE_CAPTURED)

func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if golda != null:
		main.end_golda67()           # из приквела — на его карточку в выборе режима
		return
	main.show_menu()

# ---------------- прокачка, выбор, финал ----------------
func _cost(k: String) -> int:
	return [250, 500, 800, 1200, 1700, 2400][min(int(up[k]), 5)]

## Покупка улучшения из меню паузы: те же цены и эффекты, что в мастерской, но сюжет не двигается и здоровье не лечится
## (кроме прибавки от самого улучшения здоровья). Мастерская (_open_shop) по закрытии зовёт next_step — из паузы её звать нельзя.
func buy_upgrade(k: String) -> bool:
	if not up.has(k) or int(up[k]) >= 5 or xp < _cost(k):
		return false
	var hp_before: float = player.hp
	xp -= _cost(k)
	up[k] = int(up[k]) + 1
	_apply_upgrades()
	player.hp = minf(player.max_hp, hp_before + (20.0 if k == "hp" else 0.0))
	_save()
	return true

## Текущая задача простыми словами — для HUD и страницы «Задание».
func objective() -> String:
	var alive := enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead").size()
	match mode:
		"fight":
			return "Разбей врагов: осталось %d" % (alive + pending.size())
		"boss":
			if boss_e != null and is_instance_valid(boss_e) and story["BOSS"].has(boss_e.boss_id):
				var b: Dictionary = story["BOSS"][boss_e.boss_id]
				return "Победи босса: %s — %s" % [b["n"], b["sub"]]
			return "Победи босса"
		"exit":
			return "Выйди из подъезда во двор"
		"dlg":
			return "Дослушай разговор"
	return "Иди дальше"

func _open_shop() -> void:
	mode = "shop"
	if main.testing() != "":
		_close_shop()
		return
	var rows := [["hp", "ЗДОРОВЬЕ +20"], ["dmg", "СИЛА +12% урона"], ["q", "КЕНТ: ад-либ на 1,5 с чаще"]]
	var btns := []
	for r in rows:
		var k: String = r[0]
		var can: bool = xp >= _cost(k) and int(up[k]) < 5
		btns.append(["%s — %d  [ур. %d]%s" % [r[1], _cost(k), up[k], "" if can else "  ✕"], func():
			if xp >= _cost(k) and int(up[k]) < 5:
				xp -= _cost(k)
				up[k] = int(up[k]) + 1
				_apply_upgrades()
			_open_shop()])
	btns.append(["ДАЛЬШЕ", _close_shop])
	_show_panel("МАСТЕРСКАЯ ДЯДИ СЕВЫ", "прослушиваний: %d" % xp, btns)

func _close_shop() -> void:
	_close_panel()
	if main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	mode = "idle"
	next_step()

func _open_choice() -> void:
	mode = "choice"
	if main.testing() != "":
		_ending("ENDING_A")
		return
	_show_panel("ЯДРО", "Алгоритм повержен. Что дальше?", [["СЛОМАТЬ ЯДРО", func(): _ending("ENDING_A")], ["ЗАНЯТЬ ТРОН", func(): _ending("ENDING_B")]])

func _ending(key: String) -> void:
	_close_panel()
	if main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	start_dialog(story[key], func(): _credits("GOD OF GRIMERKA", "спасибо, что дослушал до конца"))

func _credits(title: String, sub: String) -> void:
	mode = "end"
	over = true
	if FileAccess.file_exists(SAVE) and main.testing() == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if main.testing() != "":
		return
	_show_panel(title, sub, [["В МЕНЮ", _to_menu]])

func _update_hud(dt: float) -> void:
	# Keep gameplay information present, but let the foreground iPod win the hierarchy.
	hud_root.modulate = Color(lerpf(1.0, 0.80, ipod_focus), lerpf(1.0, 0.82, ipod_focus),
		lerpf(1.0, 0.86, ipod_focus), lerpf(1.0, 0.82, ipod_focus))
	hud_root.modulate.a *= 1.0 - death_mono          # в сцене гибели HUD уходит вместе с цветом
	hp_fill.size.x = 414.0 * clamp(player.hp / player.max_hp, 0.0, 1.0)
	var full: bool = player.swag >= 100.0
	swag_fill.size.x = 314.0 * (player.rage / 8.0 if player.rage > 0.0 else player.swag / 100.0)
	swag_fill.color = Color(1, 0.25, 0.05) if player.rage > 0.0 else (Color(1, 0.85, 0.3) if full else Color(1, 0.6, 0.15))
	swag_label.text = "ПЕРЕГРУЗ!" if player.rage > 0.0 else ("СВЭГ ПОЛОН — [R]" if full else ("СВЭГ · [E] Heat" if player.swag >= 40.0 else "СВЭГ"))
	q_label.text = "[Q] madk1d: ад-либ готов" if buddy.cd <= 0.0 else "[Q] madk1d: %.0f с" % buddy.cd
	style_label.text = player.style_hud()
	hero_label.text = "ПАХАН" if player.hero == "pahan" else "MADK1D"
	var alive := enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead").size()
	var obj := ""
	if mode == "fight":
		obj = "   ·   врагов: %d" % (alive + pending.size())
	if mode == "exit":
		obj = "   ·   выйди из подъезда во двор"
	top_label.text = "ГЛАВА %d · %s%s" % [ch + 1, String(chapter()["name"]), obj]
	xp_label.text = "▶ %d" % xp
	xp_label.visible = training == null and golda == null
	if training != null:
		top_label.text = training.hud_line()
	if golda != null:
		top_label.text = golda.hud_line()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	boss_box.visible = (mode == "boss" or training != null or golda != null) and boss_e != null and is_instance_valid(boss_e) and boss_e.state != "dead"
	flash.color.a = max(0.0, flash.color.a - dt * 1.5)
	banner_t -= dt
	var a: float = clamp(banner_t / 0.5, 0.0, 1.0)
	banner_title.modulate.a = a
	banner_sub.modulate.a = a
	toast_t -= dt
	toast_label.modulate.a = clamp(toast_t / 0.5, 0.0, 1.0)
	hud.visible = not (director and director.hide_hud())

# ---------------- проверки: бот играет сам ----------------
func bot_input(dt: float) -> void:
	# нажатия читает физический кадр, а бот думает каждый кадр отрисовки: держим решение до следующего физического кадра
	bot_acc += dt
	var pf := Engine.get_physics_frames()
	if pf == bot_pf:
		return
	bot_pf = pf
	dt = bot_acc
	bot_acc = 0.0
	var near = null
	var nd := 1e9
	for e in enemies:
		if is_instance_valid(e) and e.alive():
			var d: float = e.global_position.distance_to(player.global_position)
			if d < nd:
				nd = d
				near = e
	var inp := {}
	if near:
		var to: Vector3 = near.global_position - player.global_position
		cam_yaw = lerp_angle(cam_yaw, atan2(-to.x, -to.z), 1.0 - exp(-5.0 * dt))
		var reach: float = 2.0 + near.radius
		if nd > reach:
			inp["move"] = Vector2(0, 1)
		elif fmod(auto_t, 2.4) < dt:
			inp["heavy"] = "press"
		elif fmod(auto_t, 0.3) < dt:
			inp["attack"] = "press"
		if player.swag >= 40.0 and nd < 3.0 and fmod(auto_t, 5.0) < dt:
			inp["heat"] = "press"
	if fmod(auto_t, 6.0) < dt:
		inp["roll"] = "press"
		inp["move"] = Vector2(1, 0)
	if player.swag >= 100.0:
		inp["rage"] = "press"
	if fmod(auto_t, 11.0) < dt and near:
		buddy.adlib()
	player.auto_input = inp

func _autotest(dt: float) -> void:
	auto_t += dt
	player.hp = max(player.hp, player.max_hp * 0.6)
	if auto_t > 2.0:
		fps_samples.append(Engine.get_frames_per_second())
	if mode == "dlg":
		if fmod(auto_t, 0.12) < dt:
			dlg_chars = 9999.0
			_dlg_advance()
		player.auto_input = {}
	elif mode == "exit":
		var door: Vector3 = Vector3(0, 0, -5) - player.global_position
		cam_yaw = atan2(-door.x, -door.z)
		player.auto_input = {"move": Vector2(0, 1)}
	else:
		bot_input(dt)
	var out: String = main.autotest if main.autotest != "" else main.smoke
	if main.smoke != "":
		# по кадру на бой и на босса каждой главы
		var key := "ch%d_%s" % [ch + 1, mode]
		if (mode == "fight" or mode == "boss") and not shots_done.has(key) and enemies.size() > 0 and is_instance_valid(enemies[0]) and enemies[0].age > 2.2:
			shots_done[key] = true
			_shot(out, key + ".png")
		if mode == "end" or auto_t > 400.0:
			print("SMOKE done ch=%d step=%d mode=%s kills=%d shots=%d t=%.0f" % [ch + 1, step, mode, kills, shots_done.size(), auto_t])
			get_tree().quit()
	else:
		for s in [3.0, 9.0, 15.0, 21.0, 27.0, 33.0, 40.0]:
			if auto_t >= s and not shots_done.has(s):
				shots_done[s] = true
				_shot(out, "shot_%02d.png" % int(s))
		if auto_t > auto_len:
			var avg := 0.0
			for f in fps_samples:
				avg += f
			avg /= max(1, fps_samples.size())
			fps_samples.sort()
			print("AUTOTEST fps_avg=%.0f fps_min=%d ch=%d step=%d mode=%s kills=%d hp=%.0f" % [avg, fps_samples[0] if fps_samples.size() else 0, ch + 1, step, mode, kills, player.hp])
			get_tree().quit()

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name))
