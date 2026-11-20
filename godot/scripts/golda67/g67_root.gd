## «ГОЛДА 67» — сюжетный roguelite-приквел (godot/docs/golda67/SPEC.md, DECISIONS.md).
## Контроллер режима: вешается на обычный game.gd (как Training), поэтому бой, стили, враги и HUD — те же, что в
## кампании; сюжет кампании не идёт, её сохранение не пишется (game._save выходит). Своё сохранение — G67Save.
## Сейчас сделан первый шаг вертикального среза: хаб «ПОДЪЕЗД», по которому ходит Пахан, и предметы хаба с подсказкой
## [E]. Экраны предметов (архив, улучшения, стойка стилей), забег и район ДВОР — следующие шаги.
class_name Golda67
extends Node

const REACH := 1.9            # с какого расстояния предмет хаба «под рукой»
const TITLE := "ГОЛДА 67"

var game
var world: G67World
var place := "hub"
var data: Dictionary = {}
var near := ""                # id предмета под рукой («» — нет)
var prompt: Label
var events: Array = []        # для проверок: ["enter", место], ["near", id], ["use", id]
var _t := 0.0

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS      # подсказку [E] нужно гасить и на паузе
	data = G67Save.load_all()

func save() -> void:
	if game.main.user_play():          # проверки сохранение игрока не пишут
		G67Save.save_all(data)

## Старт режима: хаб
func begin(_cont := false) -> void:
	game.mode = "golda67"
	game.ch = 0
	data["meta"]["visits"] = int(data["meta"].get("visits", 0)) + 1
	save()
	await enter_hub()

func enter_hub() -> void:
	place = "hub"
	if game.world:
		game.world.free()
	world = G67World.new()
	game.world = world
	game.add_child(world)
	game.in_hall = false
	world.build("g67_hub")
	var p = game.player
	p.global_position = Vector3(0.0, 0.05, 2.6)
	p.velocity = Vector3.ZERO
	p.face = PI
	game.cam_yaw = PI
	game.buddy.global_position = Vector3(-1.4, 0.05, 1.2)
	game.buddy.target = Vector3.ZERO
	game.tutorial.on = false
	game.tutorial.persist = false
	game.fx.prewarm(p.global_position)
	_build_prompt()
	events.append(["enter", "hub"])
	await game.get_tree().process_frame
	game.banner(TITLE, "ПОДЪЕЗД · турнир начинается отсюда", Color(1.0, 0.8, 0.2), 3.5)

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

## Строка вверху экрана вместо главы и задания кампании
func hud_line() -> String:
	return "ГОЛДА 67 · ПОДЪЕЗД" if place == "hub" else "ГОЛДА 67"

func on_kill(_e) -> void:
	pass

## Гибель в приквеле сюжет и постоянное не стирает; пока забега нет — просто на ноги
func on_dead() -> void:
	game.over = true
	await game.get_tree().create_timer(1.2, true, false, true).timeout
	if not is_instance_valid(game) or game.golda != self:
		return
	game.over = false
	var p = game.player
	p.hp = p.max_hp
	p.state = "move"
	p.velocity = Vector3.ZERO

func point(id: String) -> Dictionary:
	if world != null:
		for pt in world.points:
			if String(pt["id"]) == id:
				return pt
	return {}

func _physics_process(dt: float) -> void:
	if game == null or world == null or place != "hub":
		return
	if game.get_tree().paused:
		if prompt != null:
			prompt.visible = false
		return
	_t += dt
	var pp: Vector3 = game.player.global_position
	var best := ""
	var bd := REACH
	for pt in world.points:
		var d: float = Vector2(pp.x - pt["pos"].x, pp.z - pt["pos"].z).length()
		if d < bd:
			bd = d
			best = String(pt["id"])
	if best != near:
		near = best
		if near != "":
			events.append(["near", near])
	if prompt != null:
		prompt.visible = near != "" and game.panel == null and not game.get_tree().paused
		if near != "":
			var pt2 := point(near)
			prompt.text = "[E]  %s\n%s" % [String(pt2["title"]), String(pt2["hint"])]

func _unhandled_input(e: InputEvent) -> void:
	if game == null or place != "hub" or near == "" or game.panel != null or game.get_tree().paused:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_E:
		use(near)
		get_viewport().set_input_as_handled()

## Взаимодействие с предметом хаба. Экраны предметов ещё не сделаны — честно говорим об этом, а не показываем пустышку.
func use(id: String) -> void:
	var pt := point(id)
	if pt.is_empty():
		return
	events.append(["use", id])
	game.toast("%s — в разработке" % String(pt["title"]))

func to_menu() -> void:
	game._to_menu()
