## Подсказки приквела «ГОЛДА 67» (D11): короткая строка под верхней строкой HUD, без паузы игры. Каждая показывается
## один раз за сохранение (meta["hints"]), не больше одной на экране, держится SHOW с, между подсказками не меньше GAP с,
## не больше MAX_FIGHT за бой; только в забеге и вне диалогов, экранов и роликов.
class_name G67Hints
extends RefCounted

const SHOW := 4.5
const GAP := 6.0
const FADE := 0.2
const MAX_FIGHT := 3
const TEXTS := {
	"dodge": "SHIFT — УКЛОНЕНИЕ: УЙДИ С КРАСНОЙ МЕТКИ",
	"block": "C — БЛОК. НАЖМИ ЕГО В МОМЕНТ УДАРА — ПАРИРОВАНИЕ",
	"exec": "E — ДОБИВАНИЕ",
	"heat": "E РЯДОМ С ВРАГОМ — HEAT ЗА 40 СВЭГА",
	"rage": "R — ПЕРЕГРУЗ: УРОН ×1,6",
	"lock": "СКМ — ЗАХВАТ ЦЕЛИ, КОЛЕСО — СМЕНИТЬ",
	"stash": "ГОЛДА ВО ДВОРЕ: ПОДБЕРИ — ПОТРАТИШЬ В «ШАУРМЕ 67»",
	"kiosk": "ШАУРМА 67 НА ПАРКОВКЕ ЛЕЧИТ ЗА ГОЛДУ",
}
const ORDER := ["dodge", "block", "exec", "heat", "rage", "lock", "stash", "kiosk"]

var G
var label: Label
var cur := ""                  # id показываемой подсказки («» — нет)
var _t := 0.0                  # сколько уже показывается
var _clock := 0.0
var _last_end := -99.0
var _fight_n := 0
var _was_fight := false

func _init(g67) -> void:
	G = g67
	label = Label.new()
	label.add_theme_font_override("font", G.game.main.font)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(40, 78)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	G.game.hud_root.add_child(label)

func seen(id: String) -> bool:
	return (G.meta().get("hints", []) as Array).has(id)

func _quiet() -> bool:
	var g = G.game
	return G.place == "run" and not G.run.is_empty() and not G.busy and not g.over and g.panel == null and g.mode != "dlg" \
		and G.hub_ui == null and G.clip == null and not g.get_tree().paused

func _near_foe(r: float, state := "") -> bool:
	var pp: Vector3 = G.game.player.global_position
	for e in G.game.enemies:
		if is_instance_valid(e) and e.alive() and e.global_position.distance_to(pp) < r and (state == "" or String(e.state) == state):
			return true
	return false

## Какая подсказка уместна сейчас («» — никакой)
func _want(fight: bool) -> String:
	var p = G.game.player
	for id in ORDER:
		if seen(id):
			continue
		match id:
			"dodge":
				if fight and _near_foe(4.0, "wind"):
					return id
			"block":
				if fight and seen("dodge") and _near_foe(4.0, "wind"):
					return id
			"exec":
				if fight:
					for e in G.game.enemies:
						if is_instance_valid(e) and e.alive() and e.global_position.distance_to(p.global_position) < 6.0 and e.exec_ready():
							return id
			"heat":
				if fight and p.swag >= 40.0 and _near_foe(3.0):
					return id
			"rage":
				if fight and p.swag >= 99.9:
					return id
			"lock":
				if fight and G.alive() >= 3:
					return id
			"stash":
				if not fight:
					for n in G.stash_nodes.values():
						if is_instance_valid(n) and (n as Node3D).global_position.distance_to(p.global_position) < 6.0:
							return id
			"kiosk":
				if not fight and int(G.run.get("golda", 0)) >= 30 and p.hp < p.max_hp * 0.6:
					return id
	return ""

func tick(dt: float) -> void:
	_clock += dt
	var quiet := _quiet()
	var fight: bool = quiet and G.room_state in ["fight", "boss"]
	if fight and not _was_fight:
		_fight_n = 0
	_was_fight = fight
	if cur != "":
		_t += dt
		label.modulate.a = clampf(minf(_t, SHOW - _t) / FADE, 0.0, 1.0)
		if _t >= SHOW or not quiet:
			cur = ""
			label.modulate.a = 0.0
			_last_end = _clock
		return
	label.modulate.a = 0.0
	if not quiet or _clock - _last_end < GAP:
		return
	if not G.room_state in ["fight", "boss", "open", "reward"]:
		return
	if fight and _fight_n >= MAX_FIGHT:
		return
	var id := _want(fight)
	if id == "":
		return
	cur = id
	_t = 0.0
	label.text = String(TEXTS[id])
	if fight:
		_fight_n += 1
	var hs: Array = G.meta().get("hints", [])
	hs.append(id)
	G.meta()["hints"] = hs
	G.save()
	G.events.append(["hint", id])
