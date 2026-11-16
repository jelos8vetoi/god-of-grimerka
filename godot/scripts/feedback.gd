## Отклик боя: одно имя события → набор каналов. Контроллеры зовут game.feedback("hit_heavy", pos, dir, mul),
## а не по отдельности стоп-кадр, тряску, звук и частицы. Так все стили боя говорят на одном языке, а силу отклика
## правят в одной таблице. Это основа (этап 02): числа повторяют то, что игра делала раньше, финальная настройка — позже.
##
## Каналы события (все необязательные):
##   stop  — стоп-кадр, с (stop_mul: умножать на mul; stop_max — потолок)       → game.hitstop
##   shake — тряска камеры (shake_mul: умножать на mul)                          → game.shake
##   punch — экранный удар: цветной разлёт, размытие, волна, толчок обзора        → game.punch
##   aberr — только цветной разлёт по краям                                       → game.pp
##   fov   — толчок угла обзора, градусы                                          → game.fov_kick
##   slow  — замедление времени, с                                                → game.slowmo
##   fx    — частицы: имя набора в _fx (hit0/hit1/hit2, sparks, drop, step, land, tag)
##   sfx   — звуки [[имя, громкость дБ, высота]]                                 → main.sfx
##   text  — всплывающая надпись над точкой (text_col — цвет, text_up — высота)
##   trail — усиление следа оружия у героя (Trail.boost)
##   confirm — подтверждение попадания 0..1: сигнал game.hit_confirmed(pos, сила) — для HUD, вибрации, звука слоя
class_name Feedback

## Множитель тряски для будущей настройки «меньше тряски» (0..1).
static var shake_scale := 1.0

const EVENTS := {
	# попадания по силе: 0 — лёгкий, 1 — тяжёлый, 2 — добивание / полный заряд (раньше — game.impact по tier)
	"hit_light": {"stop": 0.055, "stop_mul": true, "shake": 0.16, "shake_mul": true, "aberr": 0.22, "confirm": 0.5},
	"hit_heavy": {"stop": 0.12, "stop_mul": true, "shake": 0.42, "punch": 0.55, "confirm": 0.8},
	"hit_super": {"stop": 0.16, "stop_mul": true, "stop_max": 0.2, "shake": 0.75, "punch": 1.0, "confirm": 1.0},
	# Балон VOZDUH: у каждого типа удара свой стоп-кадр и толчок камеры — вес чувствуется по-разному
	"vz_launcher": {"stop": 0.085, "stop_mul": true, "shake": 0.26, "aberr": 0.3, "fov": 2.0, "confirm": 0.6},
	"vz_heavy": {"stop": 0.12, "stop_mul": true, "shake": 0.42, "punch": 0.55, "fx": "heavy_dust", "confirm": 0.8},
	"vz_slam": {"stop": 0.14, "stop_mul": true, "stop_max": 0.19, "shake": 0.5, "punch": 0.6, "fx": "heavy_dust", "confirm": 0.9},
	"vz_finisher": {"stop": 0.13, "stop_mul": true, "stop_max": 0.19, "shake": 0.46, "punch": 0.6, "fov": 2.5, "fx": "heavy_dust", "confirm": 0.9},
	"vz_quake": {"stop": 0.16, "stop_mul": true, "stop_max": 0.2, "shake": 0.7, "punch": 0.9, "fx": "quake", "confirm": 1.0},
	# бутылки с водой: лёгкий отклик — оружие контроля, не урона
	"bt_hit": {"stop": 0.03, "shake": 0.1, "aberr": 0.15, "confirm": 0.4},
	"bt_power": {"stop": 0.07, "shake": 0.26, "aberr": 0.3, "fov": 1.5, "confirm": 0.7},
	# защита
	"parry": {"sfx": [["sfx_parry", 0.0, 1.0]], "fx": "hit1", "punch": 0.6, "slow": 0.4, "text": "ПАРИРОВАНИЕ", "text_col": Color(0.4, 0.85, 1.0), "text_up": 1.1, "confirm": 0.8},
	"block": {"sfx": [["sfx_block", -2.0, 1.0]], "fx": "sparks"},
	"perfect_dodge": {"slow": 0.5, "text": "ТАЙМИНГ!", "text_col": Color(1, 1, 1), "text_up": 2.2},
	# оружие и тело
	"drop": {"sfx": [["sfx_clang", -5.0, 0.7], ["sfx_thud", -4.0, 0.8]], "fx": "drop", "shake": 0.2, "fov": 1.5},
	"step": {"fx": "step"},
	"land": {"sfx": [["sfx_thud", -8.0, 1.0]], "fx": "land", "shake": 0.15},
	"knockdown": {"sfx": [["sfx_thud", -3.0, 0.8]], "fx": "land", "shake": 0.3},
	"equip": {"sfx": [["sfx_clang", -12.0, 1.3]]},
	# Tag Team: смена героя (этап Tag Team дополнит камерой и надписью)
	"tag": {"sfx": [["sfx_parry", -6.0, 1.3]], "fx": "tag", "punch": 0.35, "slow": 0.15},
}

static func has(name: String) -> bool:
	return EVENTS.has(name)

static func fire(game, name: String, pos: Vector3, dir := Vector3.ZERO, mul := 1.0, col := Color(1.0, 0.82, 0.45)) -> void:
	if not EVENTS.has(name):
		push_warning("Feedback: нет события " + name)
		return
	var e: Dictionary = EVENTS[name]
	if e.has("stop"):
		var sec: float = float(e["stop"]) * (mul if e.get("stop_mul", false) else 1.0)
		if e.has("stop_max"):
			sec = min(float(e["stop_max"]), sec)
		game.hitstop(sec)
	if e.has("shake"):
		game.shake(float(e["shake"]) * (mul if e.get("shake_mul", false) else 1.0) * shake_scale)
	if e.has("aberr"):
		game.pp["aberr"] = max(float(game.pp["aberr"]), float(e["aberr"]))
	if e.has("punch"):
		game.punch(float(e["punch"]), pos)
	if e.has("fov"):
		game.fov_kick = max(float(game.fov_kick), float(e["fov"]))
	if e.has("slow"):
		game.slowmo(float(e["slow"]))
	if e.has("fx"):
		_fx(game, String(e["fx"]), pos, dir, col)
	for s in e.get("sfx", []):
		game.main.sfx(s[0], float(s[1]), float(s[2]))
	if e.has("text"):
		game.popup(pos + Vector3(0, float(e.get("text_up", 1.0)), 0), String(e["text"]), e.get("text_col", Color.WHITE))
	if e.has("trail") and game.player != null and game.player.trail != null:
		game.player.trail.boost = max(game.player.trail.boost, float(e["trail"]))
	if e.has("confirm"):
		game.hit_confirmed.emit(pos, float(e["confirm"]) * mul)
	game.feedback_fired.emit(name, pos, mul)

static func _fx(game, kind: String, pos: Vector3, dir: Vector3, col: Color) -> void:
	var fx = game.fx
	match kind:
		"hit0", "hit1", "hit2":
			fx.hit(pos, dir, int(kind.substr(3)), col)
		"sparks":
			fx.sparks(pos, dir + Vector3(0, 0.5, 0), 10, col, 0.7)
		"drop":
			fx.scrape(pos, dir)
			fx.dust(pos + Vector3(0, 0.08, 0), 6, fx.DUST, 0.7)
			fx.ground_ring(pos, 0.3, 1.9, Color(1.0, 0.9, 0.7, 0.55), 0.25)
			fx.scorch(pos, 0.8, col)
		"step":
			fx.dust(pos, 3, fx.DUST, 0.45)
		"heavy_dust":
			# тяжёлое попадание: пыль из-под ног цели
			fx.dust(Vector3(pos.x, game.player.global_position.y + 0.1, pos.z), 7, fx.DUST, 0.8)
		"quake":
			var g := Vector3(pos.x, game.player.global_position.y + 0.05, pos.z)
			fx.dust(g + Vector3(0, 0.08, 0), 14, fx.DUST, 1.2)
			fx.ground_ring(g, 0.5, 4.2, Color(col.r, col.g, col.b, 0.6), 0.4)
			fx.ground_ring(g, 0.3, 2.6, Color(1.0, 0.95, 0.85, 0.5), 0.3)
		"land":
			fx.dust(pos + Vector3(0, 0.1, 0), 8, fx.DUST, 0.8)
			fx.ground_ring(pos, 0.3, 1.6, Color(1.0, 0.95, 0.85, 0.4), 0.3)
		"tag":
			fx.ground_ring(pos, 0.4, 2.6, Color(col.r, col.g, col.b, 0.6), 0.35)
			fx.flash(pos + Vector3(0, 1.0, 0), 1.4, col, "star_08", 0.2)
