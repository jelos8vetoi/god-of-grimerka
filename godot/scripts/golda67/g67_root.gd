## «ГОЛДА 67» — сюжетный roguelite-приквел (godot/docs/golda67/SPEC.md, DECISIONS.md).
## Контроллер режима: вешается на обычный game.gd (как Training), поэтому бой, стили, враги и HUD — те же, что в
## кампании; сюжет кампании не идёт, её сохранение не пишется (game._save выходит). Своё сохранение — G67Save.
##
## Сделано: хаб «ПОДЪЕЗД» и игровой цикл первого района — ДВОР: забег из шести позиций (бой → выбор двери → … →
## передышка → босс Миша Минасян), волны врагов, голда забега, фитсы семейства Миши, РЕСПЕКТ, открытие Водяры.
## Не сделано: комнаты STORAGE / KIOSK / EVENT, экраны предметов хаба, ролики, встречи КРОТА, остальные районы.
class_name Golda67
extends Node

const REACH := 1.4            # с какого расстояния предмет «под рукой»
const TITLE := "ГОЛДА 67"

var game
var world: G67World
var place := "hub"            # hub | run
var data: Dictionary = {}
var near := ""                # id предмета под рукой («» — нет)
var prompt: Label
var events: Array = []        # для проверок: ["enter", место], ["near", id], ["use", id], ["room", тип], ["clear"], ["fit", id]…
var _t := 0.0

# ---- забег
var run: Dictionary = {}      # {district, pos, golda, fits: {id: уровень}, respect}
var room: Dictionary = {}     # текущая комната {type, place}
var room_state := ""          # fight | reward | open | boss | rest | over
var waves: Array = []
var wave_i := -1
var wave_wait := 0.0
var pending: Array = []
var spawn_cd := 0.0
var wind_used := false        # «ВТОРОЕ ДЫХАНИЕ» уже сработало в этой комнате
var base_hp := 100.0
var busy := false             # идёт переход между комнатами
# ---- постановка (выход босса): камеру и ввод на это время держит контроллер
const SCENE_LEN := 7.6        # выход Миши: сидит на троне → встаёт → идёт по ковру → топает → бой
const SCENE_SIT := 1.7        # до этой секунды сидит
const SCENE_WALK := 2.5       # с этой идёт
const SCENE_STOP := 5.4       # к этой дошёл
var scene_step := 0
var scene_from := Vector3.ZERO
var scene_to := Vector3.ZERO
var scene_t := -1.0           # −1 — постановки нет
var scene_boss = null
var scene_said := false

func setup(g) -> void:
	game = g
	game.feedback_fired.connect(_on_feedback)
	process_mode = Node.PROCESS_MODE_ALWAYS      # подсказку [E] нужно гасить и на паузе
	data = G67Save.load_all()
	# боссы и говорящие приквела — в копию сюжета этого экземпляра игры (story.json не меняется)
	for id in G67Data.BOSSES:
		game.story["BOSS"][id] = (G67Data.BOSSES[id] as Dictionary).duplicate(true)
	for sp in G67Data.SPEAKERS:
		game.story["SPK"][sp] = (G67Data.SPEAKERS[sp] as Dictionary).duplicate()

func save() -> void:
	if game.main.user_play():          # проверки сохранение игрока не пишут
		G67Save.save_all(data)

func meta() -> Dictionary:
	return data["meta"]

## Открыт ли madk1d (управление, его стили, смена героя, дуэт, Team Hype, Overdrive) — после первой концовки
func madk_open() -> bool:
	return bool((meta().get("flags", {}) as Dictionary).get(G67Data.MADK_FLAG, false))

## Старт режима: хаб
func begin(_cont := false) -> void:
	game.mode = "golda67"
	game.ch = 0
	meta()["visits"] = int(meta().get("visits", 0)) + 1
	save()
	base_hp = game.player.max_hp
	await enter_hub()
	unlock_clip("V00")                       # трейлер — на телевизоре в подъезде с первого входа
	if auto_clips and not clip_seen("STORY01"):
		_first_clips()                       # не ждём: переход из меню сначала открывает подъезд

## Первые ролики — после того, как шторка перехода из меню открыла подъезд и вернула цвет. Раньше begin() ждал
## их до конца, и полминуты роликов шторка висела под ними, а подъезд проявлялся уже после.
func _first_clips() -> void:
	var fx = game.main.intro_fx if game.main != null else null
	var t0 := GameClock.ms()
	while is_instance_valid(self) and GameClock.ms() - t0 < 6000 and (fx == null or bool(fx.busy) or float(fx.mono_v) > 0.02):
		await game.get_tree().process_frame
	if not is_instance_valid(self) or clip != null:
		return
	await play_clip("STORY01")               # регистрация — до первого забега
	await play_clip("STORY05")               # первое обращение организатора

func _swap_world(build: Callable) -> void:
	game._clear_fight()
	game.boss_e = null
	if game.world:
		game.world.free()
	world = G67World.new()
	game.world = world
	game.add_child(world)
	game.in_hall = false
	build.call(world)
	near = ""

func enter_hub() -> void:
	place = "hub"
	room_state = ""
	run = {}
	_swap_world(func(w: G67World): w.build("g67_hub"))
	var p = game.player
	p.max_hp = base_hp
	p.hp = p.max_hp
	p.dmg_mul = 1.0
	p.global_position = world.spawn_pos
	p.velocity = Vector3.ZERO
	p.face = 0.0                 # вошёл с улицы: лицом в холл, к лестнице
	game.cam_yaw = 0.0
	game.buddy.visible = true
	game.buddy.global_position = world.spawn_pos + Vector3(-1.1, 0.0, -0.7)
	game.buddy.target = Vector3.ZERO
	apply_styles()
	game.tutorial.on = false
	game.tutorial.persist = false
	game.fx.prewarm(p.global_position)
	_build_prompt()
	_place_krot("hub")
	events.append(["enter", "hub"])
	await game.get_tree().process_frame
	game.banner(TITLE, "ПОДЪЕЗД · РЕСПЕКТ: %d" % int(meta().get("respect", 0)), Color(1.0, 0.8, 0.2), 3.5)

func _build_prompt() -> void:
	if prompt != null and is_instance_valid(prompt):
		return
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.0
	prompt.anchor_right = 1.0
	prompt.anchor_top = 0.72
	prompt.anchor_bottom = 0.72
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	game.hud_root.add_child(prompt)

# ---------------------------------------------------------------- стили
## Какие стили Пахана открыты (SPEC, раздел 6): до первого босса — только Балон VOZDUH; Водяра — после победы над
## Мишей Минасяном; ТЯГА-812 — после победы над FORTUNA 812. Новых стилей нет — только три существующих.
func styles_open() -> Array:
	var fl: Dictionary = meta().get("flags", {})
	var out: Array = ["vozduh"]
	if bool(fl.get("boss_misha", false)):
		out.append("bottles")
	if bool(fl.get("boss_fortuna", false)):
		out.append("tyaga812")
	return out

## Оставить герою только открытые стили (список у Пахана общий с его записью в player.heroes — меняем на месте)
func apply_styles() -> void:
	var p = game.player
	var open := styles_open()
	var list: Array = p.heroes["pahan"]["styles"]
	list.clear()
	for s in open:
		list.append(s)
	if p.hero == "pahan":
		p.own_styles = list
		if not list.has(String(p.style.id)):
			p.set_style("vozduh")

# ---------------------------------------------------------------- забег
## Начать забег: район ДВОР, первая позиция. До первой концовки madk1d остаётся в подъезде (SPEC, раздел 3).
func start_run(district_id := "dvor") -> void:
	if busy:
		return
	place = "run"
	run = {"district": district_id, "pos": 0, "golda": 0, "fits": {}, "respect": 0, "rooms": 0}
	G67Yard.secret_tag = bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false))      # граффити-секрет — после победы над Мишей
	G67Yard.crowd_seed = int(meta().get("runs", 0)) * 31 + int(meta().get("visits", 0)) + 1      # очередь у ларька — каждый забег другая
	game.buddy.visible = false
	game.buddy.global_position = Vector3(0, -50, 0)
	events.append(["run", district_id])
	unlock_clip("CL01")                      # «КАК ЗАЙТИ ВО ДВОР» — в архив после входа во ДВОР
	var d := G67Data.district(district_id)
	await enter_room((d["route"] as Array)[0][0])

## Домой посреди забега: дверь подъезда во дворе (комната зачищена или передышка). Забег — в сохранение
## (data["run"]: забег, комната, здоровье, состояние), в подъезде он стоит на паузе; выход во двор продолжает его
## с той же комнаты — двери снова открыты. Гибель или конец забега стирают паузу (_finish_run).
func go_home() -> void:
	if busy or place != "run" or not room_state in ["open", "rest"]:
		return
	data["run"] = {"run": run.duplicate(true), "room": room.duplicate(true), "hp": float(game.player.hp), "state": room_state}
	save()
	events.append(["home"])
	game.main.ui("confirm")
	await enter_hub()
	game.toast("Забег на паузе — выход во двор продолжит его")

func paused_run() -> bool:
	return not (data.get("run", {}) as Dictionary).is_empty() and (data["run"] as Dictionary).has("room")

func resume_run() -> void:
	if busy or not paused_run():
		return
	busy = true
	var sv: Dictionary = data["run"]
	run = (sv["run"] as Dictionary).duplicate(true)
	room = (sv["room"] as Dictionary).duplicate(true)
	data["run"] = {}
	save()
	place = "run"
	G67Yard.secret_tag = bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false))
	G67Yard.crowd_seed = int(meta().get("runs", 0)) * 31 + int(meta().get("visits", 0)) + 1
	game.buddy.visible = false
	game.buddy.global_position = Vector3(0, -50, 0)
	wind_used = false
	_swap_world(func(w: G67World): w.build_room(room))
	krot_k = {}
	if world.yard != null:
		for l in world.yard.lifes:
			(l as G67Life).watcher = game.player
	apply_fits()
	var p = game.player
	p.hp = clampf(float(sv.get("hp", p.max_hp)), 1.0, p.max_hp)
	p.global_position = world.yard.position + G67Yard.HOME_DOOR + Vector3(0, 0.05, -1.2)
	p.velocity = Vector3.ZERO
	p.face = PI                      # вышел из подъезда — лицом во двор
	game.cam_yaw = 0.0
	game.fx.prewarm(p.global_position)
	_place_krot(String(room.get("place", "")))
	events.append(["resume", int(run.get("pos", 0))])
	await game.get_tree().process_frame
	if String(sv.get("state", "open")) == "rest":
		world.add_rest()
		world.add_home()
		room_state = "rest"
	else:
		_open_gates()
	var d := district()
	game.banner("%s · %d / %d" % [String(d["name"]), int(run["pos"]) + 1, (d["route"] as Array).size()], "ЗАБЕГ ПРОДОЛЖАЕТСЯ", Color(1.0, 0.8, 0.2), 2.4)
	busy = false

func district() -> Dictionary:
	return G67Data.district(String(run.get("district", "dvor")))

func enter_room(r: Dictionary) -> void:
	busy = true
	room = r
	wind_used = false
	_swap_world(func(w: G67World): w.build_room(r))
	krot_k = {}
	if world.yard != null:
		for l in world.yard.lifes:
			(l as G67Life).watcher = game.player       # жители замечают Пахана, когда он рядом и впереди
	var p = game.player
	p.global_position = Vector3(0.0, 0.05, float(G67Data.ENTRY_Z.get(String(r.get("place", "")), G67Data.ENTRY_Z_DEFAULT)))
	p.velocity = Vector3.ZERO
	p.face = 0.0
	game.cam_yaw = 0.0
	game.fx.prewarm(p.global_position)
	var type := String(r["type"])
	_place_krot(String(r.get("place", "")))
	events.append(["room", type])
	await game.get_tree().process_frame
	var d := district()
	game.banner("%s · %d / %d" % [String(d["name"]), int(run["pos"]) + 1, (d["route"] as Array).size()], String(G67Data.ROOM_NAMES[type]), G67Data.ROOM_COLOR[type], 2.6)
	match type:
		"battle", "elite":
			waves = G67Data.waves_for(d, type, int(run["pos"]))
			wave_i = -1
			wave_wait = 1.4
			pending = []
			room_state = "fight"
		"fit":
			room_state = "reward"
			_offer_fit(false)
		"break":
			world.add_rest()
			world.add_home()
			room_state = "rest"
		"boss":
			room_state = "boss"
			var bid := String(d["boss"])
			var b = game._make_enemy("", bid, Vector3(0, 0.05, -6.6))
			game.boss_e = b
			var bd: Dictionary = game.story["BOSS"][bid]
			game.boss_name.text = "%s — %s" % [bd["n"], bd["sub"]]
			_boss_intro(b)
	busy = false

func _spawn(foe: String) -> void:
	var f: Dictionary = G67Data.FOES[foe]
	var pp: Vector3 = game.player.global_position
	var pos := Vector3.ZERO
	for n in 20:
		var a := randf() * TAU
		pos = Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 11.0)
		if pos.distance_to(pp) > 5.5 and not world.blocked(pos):
			break
	pos.y = 0.05
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = String(f["kind"])
	e.skin = String(f["skin"])
	e.game = game
	e.position = pos
	e.set_meta("foe", foe)
	game.add_child(e)
	e.global_position = pos
	e.face = atan2(pp.x - pos.x, pp.z - pos.z)
	game.enemies.append(e)

func alive() -> int:
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and e.state != "dead":
			n += 1
	return n

func _fight_tick(dt: float) -> void:
	if spawn_cd > 0.0:
		spawn_cd -= dt
	if not pending.is_empty():
		if alive() < 7 and spawn_cd <= 0.0:
			_spawn(pending.pop_front())
			spawn_cd = 0.3
		return
	if alive() > 0:
		return
	wave_wait -= dt
	if wave_wait > 0.0:
		return
	wave_i += 1
	if wave_i >= waves.size():
		_room_cleared()
		return
	for grp in waves[wave_i]:
		for i in int(grp[1]):
			pending.append(String(grp[0]))
	pending.shuffle()
	wave_wait = 1.2
	if waves.size() > 1:
		game.toast("Волна %d / %d" % [wave_i + 1, waves.size()])
	game.main.sfx("sfx_wave", -8.0)

func gold_k() -> float:
	return 1.0 + 0.25 * float(fit_lv("gold_chain"))

func add_golda(n: int) -> void:
	run["golda"] = int(run.get("golda", 0)) + int(round(n * gold_k()))

func on_kill(e) -> void:
	if place != "run":
		return
	var p = game.player
	p.swag = minf(100.0, p.swag + 6.0)
	if e.boss_id != "":
		_boss_down(e)
		return
	var foe := String(e.get_meta("foe", ""))
	if G67Data.FOES.has(foe):
		add_golda(int(G67Data.FOES[foe]["golda"]))
	var heal := 3.0 * float(fit_lv("finisher"))
	if heal > 0.0:
		p.hp = minf(p.max_hp, p.hp + heal)

func _room_cleared() -> void:
	var type := String(room["type"])
	events.append(["clear", type])
	add_golda(int(G67Data.ROOM_GOLDA[type]))
	run["respect"] = int(run["respect"]) + int(G67Data.RESPECT["elite" if type == "elite" else "room"])
	run["rooms"] = int(run["rooms"]) + 1
	game.banner("ЧИСТО", "голда: %d" % int(run["golda"]), Color(1, 0.85, 0.3), 1.8)
	game.fx.twinkle(game.player.global_position + Vector3(0, 1.0, 0), 14, Color(1, 0.85, 0.4), 1.0)
	if type == "elite":
		room_state = "reward"
		_offer_fit(true)
	else:
		_open_gates()

## Двери следующей позиции. Обязательную встречу КРОТА случайность потерять не может: пока она не пройдена, одна из
## дверей ведёт в её зону; если игрок дважды прошёл мимо — дверь остаётся одна (LEVEL_DESIGN.md, раздел 4).
func route_options(next: int) -> Array:
	var route: Array = district()["route"]
	var opts: Array = (route[next] as Array).duplicate(true)
	var k := krot_next()
	if k.is_empty() or String(k["where"]) == "hub" or not G67Yard.ZONES.has(String(k["where"])):
		return opts
	if String(k.get("needs", "")) != "" and not G67Models.has(String(k["needs"])):
		return opts
	var zone := String(k["where"])
	if String(room.get("place", "")) == zone:
		return opts                                   # КРОТ стоит в этой самой комнате — вести к нему уже не нужно
	var types: Array = opts.map(func(o): return String(o["type"]))
	if types.has("break") or types.has("boss"):
		return opts                                   # передышка и босс стоят на своих местах
	if opts.any(func(o): return String(o["place"]) == zone):
		if next >= 3:
			return opts.filter(func(o): return String(o["place"]) == zone)      # последний шанс до босса — без выбора
		return opts
	if next >= 3:
		var only: Dictionary = (opts[0] as Dictionary).duplicate()
		only["place"] = zone
		return [only]
	(opts[0] as Dictionary)["place"] = zone
	return opts

func _open_gates() -> void:
	var route: Array = district()["route"]
	var next := int(run["pos"]) + 1
	if next >= route.size():
		return
	var opts := route_options(next)
	world.open_bounds()            # ограждения боя убраны: дальше — по двору, к воротам следующей зоны
	world.add_gates(opts)
	world.add_home()
	room_state = "open"
	events.append(["gates", opts.size()])
	game.toast("Выбери дверь")

func choose_gate(i: int) -> void:
	if busy or room_state != "open" or i < 0 or i >= world.gates.size():
		return
	var o: Dictionary = world.gates[i]["option"]
	run["pos"] = int(run["pos"]) + 1
	events.append(["gate", String(o["type"])])
	game.main.ui("confirm")
	await enter_room(o)

# ---------------------------------------------------------------- постановка: выход босса
## Миша ждёт у своей машины в дальнем конце коробки. Камера уходит от героя к нему, обходит его, он говорит своё —
## и только потом бой. Игрок в это время не управляет героем, босс не двигается.
func _boss_intro(b) -> void:
	scene_boss = b
	scene_t = 0.0
	scene_said = false
	scene_step = 0
	b.set_physics_process(false)
	# начинает на троне, лицом к воротам; выйдет по ковровой дорожке
	scene_to = b.global_position
	scene_from = Vector3(world.throne.x, b.global_position.y, world.throne.z + 0.2)
	b.global_position = scene_from
	b.face = 0.0
	b.body.rotation.y = 0.0
	b.rig.play("MSit", 0.0)
	events.append(["boss_intro"])

func scene_busy() -> bool:
	return scene_t >= 0.0 or clip != null or clip_menu != null

func owns_camera() -> bool:
	return scene_t >= 0.0 and scene_boss != null and is_instance_valid(scene_boss)

## где камера в этот миг постановки
func camera() -> Transform3D:
	var home: Transform3D = game.spring.global_transform * Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	var bp: Vector3 = scene_boss.global_position
	var chest: Vector3 = bp + Vector3(0, 1.45, 0)
	var k := clampf((scene_t - 0.9) / (SCENE_LEN - 1.9), 0.0, 1.0)
	var ang := lerpf(0.55, -0.4, k * k * (3.0 - 2.0 * k))            # обход от правого плеча к левому
	var dist := lerpf(6.2, 3.6, k)
	var pos: Vector3 = chest + Vector3(sin(ang) * dist, lerpf(-0.7, 0.15, k), cos(ang) * dist)
	var shot := Transform3D(Basis.looking_at(chest + Vector3(0, 0.25, 0) - pos, Vector3.UP), pos)
	var w := 1.0
	if scene_t < 0.9:
		w = scene_t / 0.9
	elif scene_t > SCENE_LEN - 1.0:
		w = clampf((SCENE_LEN - scene_t) / 1.0, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	return Transform3D(Basis(home.basis.get_rotation_quaternion().slerp(shot.basis.get_rotation_quaternion(), w)), home.origin.lerp(shot.origin, w))

func _scene_tick(dt: float) -> void:
	scene_t += dt
	if scene_boss == null or not is_instance_valid(scene_boss):
		_scene_end()
		return
	var b = scene_boss
	if scene_step == 0 and scene_t >= SCENE_SIT:
		scene_step = 1
		b.rig.play("Idle", 0.5)                    # встаёт
	if scene_step == 1 and scene_t >= SCENE_WALK:
		scene_step = 2
		b.rig.play("Run", 0.25, 0.5)               # идёт не спеша
	if scene_step == 2:
		var wk := clampf((scene_t - SCENE_WALK) / (SCENE_STOP - SCENE_WALK), 0.0, 1.0)
		b.global_position = scene_from.lerp(scene_to, wk)
		if wk >= 1.0:
			scene_step = 3
			b.rig.play_for("Stomp", 1.2, 0.12)       # встал напротив и топнул
	if scene_step == 3 and scene_t >= SCENE_STOP + 0.75:
		scene_step = 4
		game.shake(0.45)
		game.main.sfx("sfx_boom", -3.0, 0.8)
		game.fx.slam(b.global_position, 1.4, Color(game.story["BOSS"][String(b.boss_id)]["c"]))
	if not scene_said and scene_t >= SCENE_SIT + 0.2:
		scene_said = true
		var bd: Dictionary = game.story["BOSS"][String(scene_boss.boss_id)]
		game.banner(String(bd["n"]), String(bd["sub"]), Color(bd["c"]), 3.4)
		game.boss_bark(String(bd["n"]), G67Data.BOSS_INTRO, Color(bd["c"]), String(bd["sp"]))
		game.main.sfx("sfx_rage", -4.0, 0.7)
	if scene_t >= SCENE_LEN:
		_scene_end()

func _scene_end() -> void:
	scene_t = -1.0
	if scene_boss != null and is_instance_valid(scene_boss):
		scene_boss.global_position = scene_to
		scene_boss.set_physics_process(true)
		scene_boss.cool = 1.2
	scene_boss = null
	game.cam.transform = Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	events.append(["boss_fight"])

# ---------------------------------------------------------------- КРОТ
## Следующая неувиденная встреча КРОТА (они идут по порядку); {} — все из сделанных увидены
func krot_next() -> Dictionary:
	var seen: Array = meta().get("seen", [])
	for k in G67Data.KROT:
		if not seen.has(String(k["id"])):
			return k
	return {}

## Поставить КРОТА, если его очередная встреча назначена на это место и нужная для сцены модель есть.
## Встреча не пропадает: пока игрок с ним не поговорил, он стоит тут в каждом забеге.
func _place_krot(where: String) -> void:
	var k := krot_next()
	if k.is_empty() or String(k["where"]) != where:
		return
	if String(k.get("needs", "")) != "" and not G67Models.has(String(k["needs"])):
		return
	var off := Vector3.ZERO if where == "hub" or world.yard == null else world.yard.position
	var pos: Vector3 = (k["pos"] as Vector3) + off
	var kc: Dictionary = Poses.pahan()
	kc.merge(G67Poses.krot(), true)           # позы встреч КРОТА (одна модель на все десять)
	var r: Rig = world._actor("g67_krot", G67Models.DIR + "g67_krot.glb", 1.62, pos, float(k["yaw"]), kc)
	if r == null:
		return
	krot_k = k
	krot_line = -1
	krot_feed = 0.0
	krot_life = G67Life.attach(r, {"base": String(k.get("pose", "Idle")), "alts": [], "look_r": 6.0, "turn": 1.4}, 9100)
	if krot_life != null:
		krot_life.watcher = game.player
	world._static_box(pos + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	var talk: Vector3 = k.get("talk", Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"]))) * 1.1)
	world._point("krot", "КРОТ", "поговорить", pos + talk)
	if String(k.get("carry", "")) != "":
		# держит вещь перед собой обеими руками (люстру): вещь закреплена на груди скелета — идёт вместе с ним
		var fw := Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"])))
		var item := G67Models.spawn(String(k["carry"]), world, pos + fw * 0.46 + Vector3(0, 0.5, 0), float(k["yaw"]), Vector3(9, 0.55, 9))
		item.name = "krot_item"
		var att := BoneAttachment3D.new()
		att.bone_name = "mixamorig_Hips"
		r.skel.add_child(att)
		item.reparent(att, true)
		krot_item = item
	for i in int(k.get("pigeons", 0)):
		var a := float(i) * 1.26 + 0.4
		var pg := G67Models.spawn("g67_pigeon", world, pos + Vector3(sin(a), 0, cos(a)) * (1.2 + 0.25 * float(i % 3)), a * 2.0 + 1.0, Vector3(9, 0.3, 9))
		pg.name = "krot_pigeon%d" % i
		G67Pigeon.attach(pg, i)
	events.append(["krot_here", String(k["id"])])

# ---------------------------------------------------------------- постановка встреч КРОТА
var krot_k := {}
var krot_life: G67Life = null
var krot_item: Node3D = null
var krot_line := -1
var krot_feed := 0.0
var krot_walk := -1.0

## Жесты КРОТА по репликам: пока идёт разговор с ним — смотрим, какая реплика на экране
func _krot_tick(dt: float) -> void:
	var kr = world.actors.get("g67_krot")
	if krot_k.is_empty():
		return
	# уходит с вещью
	if krot_walk >= 0.0:
		krot_walk += dt
		var w = world.get_node_or_null("krot_leaving")
		if w == null:
			krot_walk = -1.0
			return
		(w as Node3D).global_position += (w as Node3D).global_transform.basis.z * 0.95 * dt
		if krot_walk > 3.2:
			game.fx.dust((w as Node3D).global_position + Vector3(0, 0.2, 0), 8, game.fx.DUST, 0.9)
			w.queue_free()
			krot_item = null
			krot_walk = -1.0
		return
	if kr == null or not is_instance_valid(kr) or krot_life == null:
		return
	# люстра в руках медленно поворачивается — он её рассматривает
	if krot_item != null and is_instance_valid(krot_item) and krot_life.cur != "K2Show":
		krot_item.rotate_y(dt * 0.35)
	# корм: на взмахе руки голуби бегут к брошенным зёрнам
	if bool(krot_k.get("feed", false)) and krot_life.cur == "K3" and kr.player != null:
		var ph: float = fmod(kr.player.current_animation_position / maxf(0.01, kr.player.current_animation_length), 1.0)
		if ph >= 0.55 and krot_feed < 0.55:
			var fw: Vector3 = (kr as Node3D).global_transform.basis.z
			var spot: Vector3 = (kr as Node3D).global_position + fw * 1.4 + Vector3(fw.z, 0, -fw.x) * randf_range(-0.6, 0.6)
			for ch in world.get_children():
				if String(ch.name).begins_with("krot_pigeon"):
					var pg = ch.get_child(ch.get_child_count() - 1)
					if pg is G67Pigeon and randf() < 0.75:
						(pg as G67Pigeon).feed(world.to_local(spot))
		krot_feed = ph
	if game.mode != "dlg" or game.dlg_partner != kr:
		return
	if game.dlg_i == krot_line:
		return
	krot_line = game.dlg_i
	var acts: Dictionary = krot_k.get("acts", {})
	var line := String(game.dlg[krot_line]) if krot_line >= 0 and krot_line < game.dlg.size() else ""
	if acts.has(krot_line):
		var a = acts[krot_line]
		if a is Array:
			krot_life.stage(String(a[0]), 0.25, float(a[1]))
			get_tree().create_timer(float(a[1]), false).timeout.connect(func():
				if krot_life != null and is_instance_valid(krot_life) and game.mode == "dlg":
					krot_life.stage(String(krot_k.get("talk_clip", krot_k["pose"])), 0.4))
		else:
			krot_life.stage(String(a), 0.35)
			if String(a) == "K2Show" and krot_item != null:
				var tw := krot_item.create_tween()
				tw.tween_property(krot_item, "rotation:y", krot_item.rotation.y + PI, 0.6).set_trans(Tween.TRANS_SINE)
	elif line.begins_with("KR|"):
		if not acts.has(krot_line - 2) or not (acts[krot_line - 2] is String):
			krot_life.stage(String(krot_k.get("talk_clip", krot_k["pose"])), 0.4)

## После разговора: остаётся в своей позе (говорить больше не о чем) или уходит, унося вещь
func _krot_after(kr: Rig) -> void:
	match String(krot_k.get("after", "")):
		"walk":
			krot_life.stage("K2Walk", 0.3)
			# разворачивается и уходит к выходу на улицу, люстра остаётся в руках
			var ex := point("exit")
			var to: Vector3 = (ex["pos"] as Vector3) - kr.global_position if not ex.is_empty() else -kr.global_transform.basis.z
			kr.rotation.y = atan2(to.x, to.z)
			kr.name = "krot_leaving"
			krot_walk = 0.0
		_:
			krot_life.stage(String(krot_k.get("pose", "Idle")), 0.5)
			kr.name = "krot_after"
			krot_life.paused = false

func talk_krot() -> void:
	var k := krot_next()
	if k.is_empty() or (place == "run" and (alive() > 0 or not pending.is_empty())):
		game.toast("Сначала разберись с этими")
		return
	events.append(["krot_talk", String(k["id"])])
	var p = game.player
	var kr = world.actors.get("g67_krot")
	if kr != null and is_instance_valid(kr):
		var to: Vector3 = kr.global_position - p.global_position
		p.face = atan2(to.x, to.z)
	game.start_dialog(k["lines"], func(): _krot_done(String(k["id"])))
	_talk_camera(kr)

func _krot_done(id: String) -> void:
	game.mode = "golda67"
	if place == "run":
		game.buddy.global_position = Vector3(0, -50, 0)
	var seen: Array = meta().get("seen", [])
	if not seen.has(id):
		seen.append(id)
	meta()["seen"] = seen
	var arch: Array = meta().get("archive", [])
	if not arch.has(id):
		arch.append(id)
	meta()["archive"] = arch
	save()
	events.append(["krot_seen", id])
	if id == "krot3":
		unlock_clip("EXTRA01")               # «КРОТ НА ПОДКАСТЕ» — в архив после третьей встречи
	# КРОТ уходит по своим делам: без объяснений
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "krot")
	var kr = world.actors.get("g67_krot")
	if kr != null and is_instance_valid(kr):
		_krot_after(kr)
	world.actors.erase("g67_krot")
	near = ""
	game.toast("КРОТ: %d из 10" % seen.filter(func(x): return String(x).begins_with("krot")).size())

## Камера разговора: двое в профиль. Сторону выбираем ту, где больше места (у стены камера упёрлась бы в затылок).
func _talk_camera(partner) -> void:
	if partner == null or not is_instance_valid(partner):
		return
	game.dlg_partner = partner
	var p = game.player
	var mid: Vector3 = (p.global_position + (partner as Node3D).global_position) * 0.5 + Vector3(0, 1.15, 0)
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var best := -1.0
	var best_d := -1.0
	for sd in [-1.0, 1.0]:
		var yaw: float = p.face + sd * 1.35
		var to: Vector3 = mid + Vector3(sin(yaw), 0.1, cos(yaw)) * 4.6
		var q := PhysicsRayQueryParameters3D.create(mid, to)
		q.exclude = [p.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var d: float = 4.6 if hit.is_empty() else ((hit["position"] as Vector3) - mid).length()
		if d > best_d:
			best_d = d
			best = sd
	game.dlg_side = best

# ---------------------------------------------------------------- dj flürr
## Диалоги dj flürr — авторский текст владельца (docs/golda67/DJ_FLURR_SPEC.md → G67Flurr, собирает
## tools/golda67-flurr.cjs). Состояние — сколько встреч КРОТА игрок действительно завершил (0…10), а не число заходов
## в подъезд. Большой диалог состояния звучит один раз; до следующей встречи — короткие фразы по кругу.
var flurr_last := -1           # какая короткая фраза была последней (без повтора подряд)

func krot_done() -> int:
	var n := 0
	for x in (meta().get("seen", []) as Array):
		if String(x).begins_with("krot"):
			n += 1
	return clampi(n, 0, 10)

func flurr_state() -> int:
	return krot_done()

func talk_flurr() -> void:
	var n := flurr_state()
	var played := int(meta().get("flurr", -1))
	var lines: Array
	var big := n > played
	if big and played < 0 and n > 0:
		# первый разговор, а КРОТ уже встречен: короткое знакомство, связка и сразу нынешний диалог
		lines = (G67Flurr.STATES[0] as Array).slice(0, G67Data.FLURR_INTRO)
		lines.append(G67Data.FLURR_BRIDGE)
		lines.append_array(G67Flurr.STATES[n])
	elif big:
		lines = G67Flurr.STATES[n]
	else:
		var pool: Array = G67Flurr.DONE if n >= 10 else G67Flurr.WAIT
		flurr_last = (flurr_last + 1) % pool.size()
		lines = [pool[flurr_last]]
	events.append(["flurr", n, big])
	var p = game.player
	var fr = world.actors.get("g67_dj_flurr")
	if fr != null and is_instance_valid(fr):
		var to: Vector3 = fr.global_position - p.global_position
		p.face = atan2(to.x, to.z)
	game.start_dialog(lines, func(): _flurr_done(n, big))
	_talk_camera(fr)

func _flurr_done(n: int, big: bool) -> void:
	game.mode = "golda67"
	if big:
		meta()["flurr"] = n
		# в «АРХИВ ПИЗДЕЦА» идут и этот диалог, и все пропущенные до него (их подряд не проигрываем)
		var arch: Array = meta().get("archive", [])
		for k in n + 1:
			if not arch.has("flurr%d" % k):
				arch.append("flurr%d" % k)
		meta()["archive"] = arch
		save()
	events.append(["flurr_done", n, big])

# ---------------------------------------------------------------- фитсы
func fit_lv(id: String) -> int:
	return int((run.get("fits", {}) as Dictionary).get(id, 0))

## Три фитса на выбор (те, что ещё можно улучшить). rare — комната элиты: редкие предлагаются первыми.
func fit_options(rare: bool) -> Array:
	var common: Array = []
	var rares: Array = []
	for id in G67Data.FITS:
		if fit_lv(id) < int(G67Data.FITS[id]["lv"]):
			if bool(G67Data.FITS[id]["rare"]):
				rares.append(id)
			else:
				common.append(id)
	common.shuffle()
	rares.shuffle()
	var ids: Array = (rares + common) if rare else (common + rares)
	return ids.slice(0, 3)

func _offer_fit(rare: bool) -> void:
	var opts := fit_options(rare)
	if opts.is_empty():
		add_golda(25)
		_open_gates()
		return
	var buttons: Array = []
	for id in opts:
		var f: Dictionary = G67Data.FITS[id]
		var lv := fit_lv(id)
		var txt := "%s%s — %s" % [String(f["name"]), (" · ур. %d → %d" % [lv, lv + 1]) if lv > 0 else "", String(f["desc"])]
		buttons.append([txt, func(): take_fit(id)])
	game._show_panel("ВЫБЕРИ ФИТС", "Семейство: %s. Усиление действует до конца забега." % String(G67Data.FAMILY_NAMES["misha"]), buttons)
	_fit_icons(opts)

## Значки фитсов на кнопках выбора (наклейки владельца; нет файла — кнопка без значка)
func _fit_icons(opts: Array) -> void:
	if game.panel == null:
		return
	var k := 0
	for b in game.panel.find_children("*", "Button", true, false):
		if k >= opts.size():
			break
		var t := G67Icons.fit(String(opts[k]))
		k += 1
		if t == null:
			continue
		var bt := b as Button
		bt.icon = t
		bt.expand_icon = false          # с expand_icon значок не входит в ширину кнопки и сжимается в ноль
		bt.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.add_theme_constant_override("icon_max_width", 64)
		bt.add_theme_constant_override("h_separation", 14)
		bt.custom_minimum_size = Vector2(bt.custom_minimum_size.x, 84.0)

func take_fit(id: String) -> void:
	if not G67Data.FITS.has(id) or fit_lv(id) >= int(G67Data.FITS[id]["lv"]):
		return
	var fits: Dictionary = run["fits"]
	fits[id] = fit_lv(id) + 1
	events.append(["fit", id])
	game._close_panel()
	if game.main.testing() == "" and game.main.user_play():
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	apply_fits(id)
	game.banner(String(G67Data.FITS[id]["name"]), "фитс · уровень %d" % fit_lv(id), G67Data.FAMILY_COLOR["misha"], 2.2)
	game.main.ui("confirm")
	if room_state == "reward":
		_open_gates()

## Пересчитать усиления забега. Исходные данные стилей не меняются: только множитель урона героя и его здоровье.
func apply_fits(just := "") -> void:
	var p = game.player
	p.dmg_mul = minf(G67Data.DMG_CAP, 1.0 + 0.12 * float(fit_lv("heavy_hand")))
	var want := base_hp + 20.0 * float(fit_lv("authority"))
	if want != p.max_hp:
		p.max_hp = want
		if just == "authority":
			p.hp = minf(p.max_hp, p.hp + 20.0)
	p.hp = minf(p.hp, p.max_hp)

func _second_wind() -> void:
	var lv := fit_lv("second_wind")
	if lv <= 0 or wind_used:
		return
	var p = game.player
	if p.hp > 0.0 and p.hp < p.max_hp * 0.3:
		wind_used = true
		p.hp = minf(p.max_hp, p.hp + 25.0 * float(lv))
		game.popup(p.global_position + Vector3(0, 2.2, 0), "ВТОРОЕ ДЫХАНИЕ", G67Data.FAMILY_COLOR["misha"])
		events.append(["wind"])

# ---------------------------------------------------------------- передышка, босс, конец забега
func rest() -> void:
	if room_state != "rest":
		return
	var p = game.player
	var add: float = p.max_hp * G67Data.BREAK_HEAL
	p.hp = minf(p.max_hp, p.hp + add)
	events.append(["rest"])
	game.banner("ПЕРЕДЫШКА", "здоровье +%d" % int(add), Color(0.5, 0.95, 0.6), 2.0)
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "rest")
	_open_gates()

func _boss_down(e) -> void:
	_crowd("win")
	var d := district()
	room_state = "over"
	game.slowmo(1.4)
	game.shake(0.8)
	game.fx.slam(e.global_position, 1.8, Color(e.boss["c"]))
	if game.boss_e == e:
		game.boss_e = null
	var fl: Dictionary = meta().get("flags", {})
	var first := not bool(fl.get(String(d["flag"]), false))
	fl[String(d["flag"])] = true
	meta()["flags"] = fl
	add_golda(int(G67Data.ROOM_GOLDA["boss"]))
	run["respect"] = int(run["respect"]) + int(G67Data.RESPECT["boss_first" if first else "boss"])
	events.append(["boss_down", String(d["boss"])])
	var style_name := String(Styles.by_id(String(d["unlock"])).title).to_upper()
	game.banner("МИША МИНАСЯН ПОВЕРЖЕН", ("открыт стиль: %s" % style_name) if first else "район пройден", Color(1, 0.85, 0.3), 4.0)
	_finish_run(true, 4.5)

func on_dead() -> void:
	if place != "run":
		# в подъезде погибнуть не от чего; на всякий случай — на ноги
		game.over = false
		game.player.hp = game.player.max_hp
		return
	if room_state == "over":
		return
	game.over = true
	room_state = "over"
	game.slowmo(1.0)
	events.append(["dead"])
	game.banner("ЗАБЕГ ОКОНЧЕН", "РЕСПЕКТ и открытое остаются с тобой", Color(0.9, 0.3, 0.25), 3.0)
	_finish_run(false, 3.2)

## Конец забега: РЕСПЕКТ — в постоянное, голда сгорает, забег стирается, герой — в подъезде
func _finish_run(won: bool, delay: float) -> void:
	var got := int(run.get("respect", 0))
	meta()["respect"] = int(meta().get("respect", 0)) + got
	meta()["runs"] = int(meta().get("runs", 0)) + 1
	data["run"] = {}
	save()
	events.append(["finish", won, got])
	await game.get_tree().create_timer(delay, true, false, true).timeout
	if not is_instance_valid(game) or game.golda != self:
		return
	game.over = false
	Engine.time_scale = 1.0
	var p = game.player
	p.state = "move"
	p.rage = 0.0
	p.rig.play("Idle", 0.1)
	await enter_hub()
	game.toast("РЕСПЕКТ +%d" % got)
	if won and bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false)):
		unlock_clip("NEWS01")
		if auto_clips and not clip_seen("NEWS01"):
			await play_clip("NEWS01")        # «РАЙОННЫЙ ВЕСТНИК 67» после первой победы над Мишей

# ---------------------------------------------------------------- HUD и взаимодействие
## Строка вверху экрана вместо главы и задания кампании
func hud_line() -> String:
	if place == "hub" or run.is_empty():
		return "ГОЛДА 67 · ПОДЪЕЗД · РЕСПЕКТ %d" % int(meta().get("respect", 0)) + (" · ЗАБЕГ НА ПАУЗЕ" if paused_run() else "")
	var d := district()
	var s := "ГОЛДА 67 · %s %d/%d · голда %d" % [String(d["name"]), int(run["pos"]) + 1, (d["route"] as Array).size(), int(run["golda"])]
	if room_state == "fight":
		s += " · врагов: %d" % (alive() + pending.size())
	return s

func point(id: String) -> Dictionary:
	if world != null:
		for pt in world.points:
			if String(pt["id"]) == id:
				return pt
	return {}

func _physics_process(dt: float) -> void:
	if game == null or world == null or not is_instance_valid(world):
		return
	if game.get_tree().paused:
		if prompt != null:
			prompt.visible = false
		return
	_t += dt
	if scene_t >= 0.0:
		_scene_tick(dt)
	_krot_tick(dt)
	_crowd_tick()
	if place == "run" and not busy and not game.over and not run.is_empty():
		if room_state == "fight":
			_fight_tick(dt)
		_second_wind()
	var pp: Vector3 = game.player.global_position
	var best := ""
	var bd := REACH + (0.6 if place == "run" else 0.0)
	for pt in world.points:
		if absf(pp.y - float(pt["pos"].y)) > 1.2:
			continue                       # предмет на другом этаже
		var d: float = Vector2(pp.x - pt["pos"].x, pp.z - pt["pos"].z).length()
		if d < bd:
			bd = d
			best = String(pt["id"])
	if best != near:
		near = best
		if near != "":
			events.append(["near", near])
	if prompt != null:
		prompt.visible = near != "" and game.panel == null and game.mode != "dlg"
		if near != "":
			var pt2 := point(near)
			prompt.text = "[E]  %s\n%s" % [String(pt2["title"]), String(pt2["hint"])]

func _unhandled_input(e: InputEvent) -> void:
	if game == null or near == "" or game.panel != null or game.get_tree().paused or busy:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_E:
		use(near)
		get_viewport().set_input_as_handled()

## Взаимодействие с предметом. Экраны предметов хаба ещё не сделаны — честно говорим об этом.
func use(id: String) -> void:
	var pt := point(id)
	if pt.is_empty():
		return
	events.append(["use", id])
	if id == "exit":
		if auto_clips and not clip_seen("AD01"):
			await play_clip("AD01")          # реклама турнира — перед первым выходом во ДВОР
		if paused_run():
			resume_run()
		else:
			start_run("dvor")
	elif id == "home":
		go_home()
	elif id == "tv":
		tv()
	elif id == "rest":
		rest()
	elif id == "krot":
		talk_krot()
	elif id == "flurr":
		talk_flurr()
	elif id.begins_with("gate"):
		choose_gate(int(id.substr(4)))
	else:
		game.toast("%s — в разработке" % String(pt["title"]))

func to_menu() -> void:
	game._to_menu()

# ---------------------------------------------------------------- зрители у коробки Миши
const CROWD_HITS := ["hit_super", "vz_finisher", "vz_slam", "vz_quake", "knockdown"]
var crowd_t := -9.0
var crowd_phase := -1

func _crowd(kind: String) -> void:
	if place != "run" or world == null or world.yard == null or String(room.get("place", "")) != "sport":
		return                       # зрители видят только свою коробку
	world.yard.crowd_react(kind)
	events.append(["crowd", kind])

## Сильный удар, добивание, сбитый с ног — короткая реакция части зрителей (не чаще раза в 2,5 с)
func _on_feedback(nm: String, _pos: Vector3, power: float) -> void:
	if not (nm in CROWD_HITS or (nm == "hit_heavy" and power >= 1.2)):
		return
	if game.clock - crowd_t < 2.5:
		return
	crowd_t = game.clock
	_crowd("hit")

## Смена фазы босса — реагируют почти все
func _crowd_tick() -> void:
	var b = game.boss_e
	if b == null or not is_instance_valid(b):
		crowd_phase = -1
		return
	if crowd_phase >= 0 and int(b.phase) != crowd_phase:
		_crowd("phase")
	crowd_phase = int(b.phase)

# ---------------------------------------------------------------- ролики главы 1 (G67Clips, G67ClipPlayer)
var clip: G67ClipPlayer = null
var clip_menu: CanvasLayer = null
## Ролики сами по ходу игры (в проверке выключено: она запускает их в своём разделе)
var auto_clips := true

func clip_seen(cid: String) -> bool:
	return (meta().get("clips_seen", []) as Array).has(cid)

func clip_open(cid: String) -> bool:
	return (meta().get("archive", []) as Array).has("clip_" + cid)

func unlock_clip(cid: String) -> void:
	var arch: Array = meta().get("archive", [])
	if not arch.has("clip_" + cid):
		arch.append("clip_" + cid)
		meta()["archive"] = arch
		save()
		events.append(["clip_open", cid])

## Показать ролик; ждать конца. Первый показ — без пропуска; после — отмечен просмотренным
func play_clip(cid: String) -> void:
	if clip != null:
		return
	unlock_clip(cid)
	game.player.velocity = Vector3.ZERO
	if prompt != null:
		prompt.visible = false
	game.voice.stop()
	game._hush()
	clip = G67ClipPlayer.open(game, cid, clip_seen(cid))
	events.append(["clip", cid])
	await clip.finished
	clip = null
	var seen: Array = meta().get("clips_seen", [])
	if not seen.has(cid):
		seen.append(cid)
		meta()["clips_seen"] = seen
		save()

## Телевизор в подъезде: впервые — трейлер; потом — список открытых роликов (пересмотр)
func tv() -> void:
	if not clip_seen("V00"):
		await play_clip("V00")
		return
	_tv_menu()

func _tv_menu() -> void:
	if clip_menu != null:
		return
	clip_menu = CanvasLayer.new()
	clip_menu.layer = 55
	game.add_child(clip_menu)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_menu.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -260)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var head := Label.new()
	head.text = "ОБЛАКО LIVE · АРХИВ ПИЗДЕЦА"
	head.add_theme_font_override("font", game.main.font)
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	box.add_child(head)
	var first: Button = null
	for cid in G67Clips.ORDER:
		if not clip_open(cid):
			continue
		var b := Button.new()
		b.text = "%s   %s" % [G67Clips.title(cid), "" if clip_seen(cid) else "· новое"]
		b.add_theme_font_override("font", game.main.font)
		b.add_theme_font_size_override("font_size", 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_tv_close()
			play_clip(cid))
		box.add_child(b)
		if first == null:
			first = b
	var close := Button.new()
	close.text = "ЗАКРЫТЬ"
	close.add_theme_font_override("font", game.main.font)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_tv_close)
	box.add_child(close)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	if first != null:
		first.grab_focus()
	events.append(["tv_menu"])

func _tv_close() -> void:
	if clip_menu != null:
		clip_menu.queue_free()
		clip_menu = null
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
