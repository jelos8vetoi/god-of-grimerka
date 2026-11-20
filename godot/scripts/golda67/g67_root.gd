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
const SCENE_LEN := 5.2
var scene_t := -1.0           # −1 — постановки нет
var scene_boss = null
var scene_said := false

func setup(g) -> void:
	game = g
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

## Старт режима: хаб
func begin(_cont := false) -> void:
	game.mode = "golda67"
	game.ch = 0
	meta()["visits"] = int(meta().get("visits", 0)) + 1
	save()
	base_hp = game.player.max_hp
	await enter_hub()

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
	var d := G67Data.district(district_id)
	await enter_room((d["route"] as Array)[0][0])

func district() -> Dictionary:
	return G67Data.district(String(run.get("district", "dvor")))

func enter_room(r: Dictionary) -> void:
	busy = true
	room = r
	wind_used = false
	_swap_world(func(w: G67World): w.build_room(r))
	var p = game.player
	p.global_position = Vector3(0.0, 0.05, 10.5)
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
	b.set_physics_process(false)
	events.append(["boss_intro"])

func scene_busy() -> bool:
	return scene_t >= 0.0

func owns_camera() -> bool:
	return scene_t >= 0.0 and scene_boss != null and is_instance_valid(scene_boss)

## где камера в этот миг постановки
func camera() -> Transform3D:
	var home: Transform3D = game.spring.global_transform * Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	var bp: Vector3 = scene_boss.global_position
	var chest: Vector3 = bp + Vector3(0, 1.45, 0)
	var k := clampf((scene_t - 0.9) / (SCENE_LEN - 1.9), 0.0, 1.0)
	var ang := lerpf(0.75, -0.35, k * k * (3.0 - 2.0 * k))            # обход от правого плеча к левому
	var dist := lerpf(5.4, 3.4, k)
	var pos: Vector3 = chest + Vector3(sin(ang) * dist, lerpf(-0.5, 0.15, k), cos(ang) * dist)
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
	if not scene_said and scene_t >= 1.3:
		scene_said = true
		var bd: Dictionary = game.story["BOSS"][String(scene_boss.boss_id)]
		game.banner(String(bd["n"]), String(bd["sub"]), Color(bd["c"]), 3.4)
		game.boss_bark(String(bd["n"]), "На этом районе уважают только сильнейших.", Color(bd["c"]), String(bd["sp"]))
		game.main.sfx("sfx_rage", -4.0, 0.7)
		game.shake(0.25)
	if scene_t >= SCENE_LEN:
		_scene_end()

func _scene_end() -> void:
	scene_t = -1.0
	if scene_boss != null and is_instance_valid(scene_boss):
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
	var r: Rig = world._actor("g67_krot", G67Models.DIR + "g67_krot.glb", 1.62, pos, float(k["yaw"]))
	if r == null:
		return
	world._static_box(pos + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	var talk: Vector3 = k.get("talk", Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"]))) * 1.1)
	world._point("krot", "КРОТ", "поговорить", pos + talk)
	if String(k.get("carry", "")) != "":
		# держит вещь перед собой (люстру): руки вперёд, вещь — у груди
		G67Models.hold(r)
		var fw := Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"])))
		var item := G67Models.spawn(String(k["carry"]), world, pos + fw * 0.5 + Vector3(0, 0.42, 0), float(k["yaw"]), Vector3(9, 0.62, 9))
		item.name = "krot_item"
	for i in int(k.get("pigeons", 0)):
		var a := float(i) * 1.26 + 0.4
		var pg := G67Models.spawn("g67_pigeon", world, pos + Vector3(sin(a), 0, cos(a)) * (1.2 + 0.25 * float(i % 3)), a * 2.0 + 1.0, Vector3(9, 0.3, 9))
		pg.name = "krot_pigeon%d" % i
		G67Pigeon.attach(pg, i)
	events.append(["krot_here", String(k["id"])])

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
	# КРОТ уходит по своим делам: без объяснений
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "krot")
	var kr = world.actors.get("g67_krot")
	if kr != null and is_instance_valid(kr):
		game.fx.dust(kr.global_position + Vector3(0, 0.2, 0), 10, game.fx.DUST, 1.0)
		kr.queue_free()
	world.actors.erase("g67_krot")
	var it := world.get_node_or_null("krot_item")      # вещь он уносит с собой; голуби остаются
	if it != null:
		it.queue_free()
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

# ---------------------------------------------------------------- HUD и взаимодействие
## Строка вверху экрана вместо главы и задания кампании
func hud_line() -> String:
	if place == "hub" or run.is_empty():
		return "ГОЛДА 67 · ПОДЪЕЗД · РЕСПЕКТ %d" % int(meta().get("respect", 0))
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
		start_run("dvor")
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
