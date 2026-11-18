## Тренировочная арена (главное меню → TRAINING ARENA): отдельный режим без сюжета на настоящей боевой системе.
## game.training = true: глава и сюжет не идут, опыт за убийства не начисляется, сюжетное сохранение не пишется,
## гибель героя — не поражение, а восстановление. Настройки арены — в своём файле SAVE, не в сюжетном сохранении.
## Площадка — world.build("training"): тёмный зал, разметка зон. Зоны:
##   A — манекен (не двигается, не бьёт, не умирает): удары, серии, заряды, броски, подброс;
##   B — замахи: бьёт предсказуемо и регулярно, стоит на месте — уклонение, Perfect Dodge, блок, парирование, ответ;
##   C — воздух: манекен, которого подбрасывают и бьют в воздухе;
##   D — босс (по выбору): его настоящие приёмы, метки, окно «ОТКРЫТ»;
##   E — свободный бой: обычные враги, умирают как в кампании.
## Панель — F1 (train_panel): герой, стиль, зона, враги, сброс здоровья, СВЭГа и перезарядок, цифры урона,
## упражнения (практика обучения на целях арены) или свободная практика, неубиваемые цели. Выход — пауза → В ГЛАВНОЕ МЕНЮ.
class_name Training
extends Node

const SAVE := "user://grimerka_training.json"
const KINDS := ["bot", "clipper", "hater", "troll", "ghost", "lawyer", "mod", "farmer"]
const ZONES := {"A": Vector3(-8, 0.05, -6), "B": Vector3(8, 0.05, -6), "C": Vector3(-8, 0.05, 6), "D": Vector3(8, 0.05, 6), "E": Vector3(0, 0.05, 0)}
const ZONE_NAMES := {"A": "A · МАНЕКЕН", "B": "B · ЗАМАХИ", "C": "C · ВОЗДУХ", "D": "D · БОСС", "E": "E · СВОБОДНЫЙ БОЙ"}
const HERO_STYLES := {"pahan": ["vozduh", "bottles", "tyaga812"], "madk1d": ["skateboard", "guitar", "breaker"]}

var game
var hero := "pahan"
var style := "vozduh"
var zone := "A"
var kind_i := 0
var boss_i := 0
var show_dmg := true
var exercises := false
var immortal := true
var targets := {}               # зона → враг-цель арены
var panel: Control
var events: Array = []          # для проверок: ["zone", z], ["spawn", вид], ["clear", n], ["heal"], ["reset"], ["cd"]

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d := prefs()
	hero = String(d["hero"])
	style = String(d["style"])
	show_dmg = bool(d["dmg"])
	exercises = bool(d["ex"])
	immortal = bool(d["imm"])

## Настройки арены из своего файла (меню берёт отсюда героя и стиль по умолчанию); битый файл — значения по умолчанию
static func prefs() -> Dictionary:
	var out := {"hero": "pahan", "style": "vozduh", "dmg": true, "ex": false, "imm": true}
	if not FileAccess.file_exists(SAVE):
		return out
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not d is Dictionary:
		return out
	if HERO_STYLES.has(String(d.get("hero", ""))):
		out["hero"] = String(d["hero"])
	var list: Array = HERO_STYLES[out["hero"]]
	out["style"] = String(d.get("style", "")) if list.has(String(d.get("style", ""))) else String(list[0])
	for k in ["dmg", "ex", "imm"]:
		if d.has(k) and d[k] is bool:
			out[k] = d[k]
	return out

func save() -> void:
	if game.main.testing() != "":
		return                       # прогоны и проверки боя файл настроек арены не трогают (--trainingcheck возвращает его сам)
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"hero": hero, "style": style, "dmg": show_dmg, "ex": exercises, "imm": immortal}))

## Убийство в арене: опыта и сюжета нет; цель зоны появится снова (_physics_process)
func on_kill(e) -> void:
	game.player.swag = minf(100.0, game.player.swag + 6.0)
	events.append(["kill", String(e.kind) if e.boss_id == "" else String(e.boss_id)])
	if e.boss_id != "":
		game.slowmo(1.2)
		game.shake(0.8)
		game.fx.slam(e.global_position, 1.8, Color(e.boss["c"]))
		game.banner("БОСС ПОВЕРЖЕН", "F1 → «БОСС ЗОНЫ D» — вызвать снова", Color(1, 0.85, 0.3), 2.6)
		if game.boss_e == e:
			game.boss_e = null

## Гибель в арене — не поражение: короткая пауза, герои на ногах, бой продолжается
func on_dead() -> void:
	game.over = true
	game.slowmo(0.8)
	events.append(["dead"])
	await game.get_tree().create_timer(1.4, true, false, true).timeout
	if not is_instance_valid(game) or game.training != self:
		return
	game.over = false
	heal()
	var p = game.player
	p.state = "move"
	p.rage = 0.0
	p.rig.play("Idle", 0.1)
	p.velocity = Vector3.ZERO
	game.banner("ЕЩЁ РАЗ", "здоровье восстановлено", Color(0.6, 1.0, 0.7), 1.6)

## Строка вверху экрана вместо главы и задания
func hud_line() -> String:
	return "ТРЕНИРОВОЧНАЯ АРЕНА · %s · [F1] панель" % ZONE_NAMES[zone]

func bosses() -> Array:
	return (game.story["BOSS"] as Dictionary).keys()

## Старт: площадка, герой и стиль, цели зон
func begin(h: String, s: String) -> void:
	hero = h if HERO_STYLES.has(h) else hero
	style = s if (HERO_STYLES[hero] as Array).has(s) else HERO_STYLES[hero][0]
	game.mode = "training"
	game.ch = 0
	if game.world:
		game.world.free()
	game.world = preload("res://scripts/world.gd").new()
	game.add_child(game.world)
	game.in_hall = false
	game.world.build("training")
	game.player.global_position = Vector3(0, 0.05, 9.0)
	game.buddy.global_position = Vector3(-1.6, 0.05, 9.6)
	game.player.face = PI
	game.cam_yaw = 0.0
	game.tutorial.on = exercises
	game.tutorial.force = 1 if exercises else -1
	game.tutorial.persist = false
	game.show_dmg = show_dmg
	game.fx.prewarm(game.player.global_position)
	await game.get_tree().process_frame
	await use(hero, style)
	spawn_zone_targets()
	game.banner("ТРЕНИРОВОЧНАЯ АРЕНА", "F1 — панель тренировки", Color(1.0, 0.85, 0.55), 3.5)

## Герой и стиль (обе системы — настоящие: смена героя через swap_heroes, стиля — через set_style)
func use(h: String, s: String) -> void:
	var p = game.player
	if p.hero != h:
		game.tag.tag_cd = 0.0
		game.tag.down = {"pahan": false, "madk1d": false}
		game.swap_heroes(true)
		for i in 40:
			await game.get_tree().physics_frame
	hero = p.hero
	if p.style.id != s and (p.own_styles as Array).has(s):
		p.set_style(s)
		for i in 90:
			if p.switch_to == "" and p.state != "switch":
				break
			await game.get_tree().physics_frame
	style = String(p.style.id)
	save()

## Цели зон A, B, C (D — босс по выбору, E — свободный бой по кнопке)
func spawn_zone_targets() -> void:
	for z in ["A", "B", "C"]:
		_spawn_target(z)

func _spawn_target(z: String) -> void:
	if targets.has(z) and is_instance_valid(targets[z]):
		targets[z].queue_free()
	var e = game._make_enemy("bot" if z != "B" else "clipper", "", ZONES[z])
	e.cool = 999.0
	e.train_home = ZONES[z]
	e.train_still = true
	e.train_immortal = immortal
	e.train_attack = z == "B"
	if z == "A" or z == "C":
		e.max_hp = 600.0
		e.hp = 600.0
	targets[z] = e

func spawn_boss() -> void:
	if targets.has("D") and is_instance_valid(targets["D"]):
		targets["D"].queue_free()
	var bid: String = String(bosses()[boss_i % bosses().size()])
	var b = game._make_enemy("", bid, ZONES["D"])
	b.train_home = ZONES["D"]
	b.train_leash = 6.5              # босс держится своей зоны, к другим целям не уходит
	b.train_immortal = immortal
	game.boss_e = b
	var bd: Dictionary = game.story["BOSS"][bid]
	game.boss_name.text = "%s — %s" % [bd["n"], bd["sub"]]
	game.banner(String(bd["n"]), "зона D · его настоящие приёмы", Color(bd["c"]), 2.4)
	targets["D"] = b
	events.append(["boss", bid])

## Свободный бой: обычный враг (умирает как в кампании)
func spawn_free() -> void:
	var k: String = KINDS[kind_i % KINDS.size()]
	var a := randf() * TAU
	var at: Vector3 = ZONES["E"] + Vector3(sin(a), 0, cos(a)) * 3.5
	var e = game._make_enemy(k, "", Vector3(at.x, 0.05, at.z))
	e.train_guard = false
	events.append(["spawn", k])

func clear_enemies() -> void:
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and not targets.values().has(e):
			e.queue_free()
			n += 1
	for b in game.bolts:
		if is_instance_valid(b["n"]):
			b["n"].queue_free()
	game.bolts = []
	for zz in game.zones:
		if is_instance_valid(zz["n"]):
			zz["n"].queue_free()
	game.zones = []
	events.append(["clear", n])

func heal() -> void:
	var p = game.player
	p.hp = p.max_hp
	game.tag.reset()                 # здоровье обоих, «серое» здоровье, выбывший напарник снова в строю
	events.append(["heal"])

func reset_abilities() -> void:
	var p = game.player
	p.swag = 0.0
	p.rage = 0.0
	game.hype.value = 0.0
	events.append(["reset"])

func reset_cooldowns() -> void:
	var p = game.player
	p.combat.cooldowns = {}
	game.tag.tag_cd = 0.0
	game.tag.assist_cd = 0.0
	game.buddy.cd = 0.0
	p.tyaga.heat = 0.0
	p.tyaga.lock = 0.0
	events.append(["cd"])

func reset_targets() -> void:
	for z in targets:
		var e = targets[z]
		if is_instance_valid(e):
			e.global_position = e.train_home
			e.velocity = Vector3.ZERO
			e.kb = Vector3.ZERO
			if e.alive():
				e.hp = e.max_hp
		else:
			if z != "D":
				_spawn_target(z)
	events.append(["home"])

func go_zone(z: String) -> void:
	zone = z
	if z == "D" and not (targets.has("D") and is_instance_valid(targets["D"]) and targets["D"].alive()):
		spawn_boss()
	var at: Vector3 = ZONES[z]
	game.player.global_position = at + Vector3(0, 0, 3.0)
	game.player.velocity = Vector3.ZERO
	game.buddy.global_position = at + Vector3(-1.6, 0, 3.8)     # напарник — рядом, а не бегом через весь зал
	game.buddy.velocity = Vector3.ZERO
	game.buddy.target = game.buddy.global_position
	game.player.face = PI
	game.cam_yaw = 0.0
	events.append(["zone", z])

func set_immortal(v: bool) -> void:
	immortal = v
	for z in targets:
		if is_instance_valid(targets[z]):
			targets[z].train_immortal = v
	save()

func set_exercises(v: bool) -> void:
	exercises = v
	game.tutorial.on = v
	game.tutorial.force = 1 if v else -1
	if v:
		game.tutorial.reset()
		game.tutorial.since = 99.0
	elif game.tutorial.drill_id != "":
		game.tutorial.finish_drill("skipped")
	save()

## Цели арены держим на месте; погибшие в зонах A–C появляются снова (если цели обычные)
func _physics_process(_dt: float) -> void:
	if game == null or game.get_tree().paused:
		return
	hero = String(game.player.hero)          # героя могли сменить Tab или выбывание — панель показывает настоящего
	style = String(game.player.style.id)
	for z in ["A", "B", "C"]:
		if not targets.has(z) or not is_instance_valid(targets[z]) or targets[z].state == "dead":
			if not targets.has(z) or not is_instance_valid(targets[z]):
				_spawn_target(z)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("train_panel") and not game.get_tree().paused and not game.paused_story():
		open_panel()
		get_viewport().set_input_as_handled()

func open_panel() -> void:
	if panel != null:
		return
	panel = TrainingPanel.new()
	panel.arena = self
	game.hud.add_child(panel)
	game.get_tree().paused = true
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	game.get_tree().paused = false
	game.player.combat.clear_buffer()
	if game.main.testing() == "":
		MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)

func to_menu() -> void:
	close_panel()
	clear_enemies()
	game._to_menu()

## Строки панели: [текст, действие (Enter / клик), изменение ←/→]
func rows() -> Array:
	var r: Array = []
	r.append([func(): return "ГЕРОЙ: " + ("ПАХАН" if hero == "pahan" else "MADK1D"), func(): _hero_step(1), func(d: int): _hero_step(d)])
	r.append([func(): return "СТИЛЬ: " + String(Styles.by_id(style).title).to_upper(), func(): _style_step(1), func(d: int): _style_step(d)])
	r.append([func(): return "ПЕРЕЙТИ В ЗОНУ: " + ZONE_NAMES[zone], func(): go_zone(zone), _zone_step])
	r.append([func(): return "БОСС ЗОНЫ D: " + String(game.story["BOSS"][bosses()[boss_i % bosses().size()]]["n"]), func(): spawn_boss(), _boss_step])
	r.append([func(): return "СОЗДАТЬ ВРАГА (E): " + String(KINDS[kind_i % KINDS.size()]).to_upper(), func(): spawn_free(), _kind_step])
	r.append(["УБРАТЬ ВРАГОВ СВОБОДНОГО БОЯ", func(): clear_enemies(), null])
	r.append(["ВОССТАНОВИТЬ ЗДОРОВЬЕ ГЕРОЕВ", func(): heal(), null])
	r.append(["СБРОСИТЬ СВЭГ, ПЕРЕГРУЗ И HYPE", func(): reset_abilities(), null])
	r.append(["СБРОСИТЬ ПЕРЕЗАРЯДКИ", func(): reset_cooldowns(), null])
	r.append(["ЦЕЛИ НА МЕСТО", func(): reset_targets(), null])
	r.append([func(): return "ЦИФРЫ УРОНА: " + ("ВКЛ" if show_dmg else "ВЫКЛ"), _toggle_dmg, null])
	r.append([func(): return "РЕЖИМ: " + ("УПРАЖНЕНИЯ" if exercises else "СВОБОДНАЯ ПРАКТИКА"), func(): set_exercises(not exercises), null])
	r.append([func(): return "ЦЕЛИ: " + ("НЕУБИВАЕМЫЕ" if immortal else "ОБЫЧНЫЕ"), func(): set_immortal(not immortal), null])
	r.append(["ПРОДОЛЖИТЬ", func(): close_panel(), null])
	r.append(["В ГЛАВНОЕ МЕНЮ", func(): to_menu(), null])
	return r

func _zone_step(d: int) -> void:
	var keys := ["A", "B", "C", "D", "E"]
	zone = keys[posmod(keys.find(zone) + d, keys.size())]

func _boss_step(d: int) -> void:
	boss_i = posmod(boss_i + d, bosses().size())

func _kind_step(d: int) -> void:
	kind_i = posmod(kind_i + d, KINDS.size())

func _toggle_dmg() -> void:
	show_dmg = not show_dmg
	game.show_dmg = show_dmg
	save()

func _hero_step(_d: int) -> void:
	var h := "madk1d" if hero == "pahan" else "pahan"
	close_panel()
	await use(h, HERO_STYLES[h][0])

func _style_step(d: int) -> void:
	var list: Array = HERO_STYLES[hero]
	var s: String = list[posmod(list.find(style) + d, list.size())]
	close_panel()
	await use(hero, s)
