## Локации приквела «ГОЛДА 67». Наследует построитель кампании (свет, пол, помощники _box / _static_box / _light),
## но оформление своё — из моделей владельца (G67Models). Сейчас — хаб «ПОДЪЕЗД» (godot/docs/golda67/HUB_DESIGN.md).
## points — предметы, с которыми можно взаимодействовать: {id, title, hint, pos}; их читает контроллер Golda67.
class_name G67World
extends "res://scripts/world.gd"

const HUB_X := 4.0       # полуширина площадки
const HUB_Z := 5.0       # полуглубина
const HUB_H := 3.2       # потолок

var points: Array = []
var actors := {}         # id → Rig (персонажи хаба)
var missing: Array = []  # модели, которых не нашлось (для проверки)

func _theme(d: String) -> Dictionary:
	if d == "g67_hub":
		return {"indoor": true, "sky": [Color(0.02, 0.02, 0.025)], "amb": Color(0.42, 0.41, 0.38), "fog": Color(0.12, 0.12, 0.11), "fog_d": 0.008,
			"key": Color(1, 0.95, 0.85), "key_e": 0.0, "g": [Color(0.3, 0.29, 0.27), Color(0.36, 0.35, 0.33)], "glow": 0.5, "exp": 1.05}
	return super._theme(d)

func _put(id: String, pos: Vector3, yaw: float, size: Vector3, fit := "h", solid := true) -> Node3D:
	var n := G67Models.spawn(id, self, pos, yaw, size, fit)
	if String(n.get_meta("from", "")) != "glb":
		missing.append(id)
		return n
	if solid:
		var s: Vector3 = n.get_meta("size", size)
		var sz := Vector3(s.x, s.y, s.z)
		if absf(fmod(absf(yaw), PI) - PI * 0.5) < 0.1:
			sz = Vector3(s.z, s.y, s.x)
		_static_box(pos + Vector3(0, sz.y * 0.5, 0), sz)
	return n

func _point(id: String, title: String, hint: String, pos: Vector3) -> void:
	points.append({"id": id, "title": title, "hint": hint, "pos": pos})

func _actor(id: String, path: String, height: float, pos: Vector3, yaw: float) -> Rig:
	if not ResourceLoader.exists(path):
		missing.append(path)
		return null
	var r := Rig.new()
	add_child(r)
	r.setup(path, height, Poses.pahan(), true, 1.0, id)
	r.position = pos
	r.rotation.y = yaw
	r.play("Idle", 0.0)
	actors[id] = r
	return r

## ПОДЪЕЗД: площадка первого этажа 8×10 м. Вход (дверь во двор) — в стене z = +5, лестница и скрытая дверь — у дальней.
func _deco_g67_hub(_T: Dictionary) -> void:
	var wall_w := 4.35       # модуль чуть шире шага — стыки перекрываются, щелей нет
	# стены из модулей: дальняя и ближняя (по два модуля), боковые (по три, с нахлёстом)
	for x in [-2.0, 2.0]:
		_put("g67_podezd_wall", Vector3(x, 0, -HUB_Z - 0.3), 0.0, Vector3(wall_w, 9, 9), "w", false)
		_put("g67_podezd_wall", Vector3(x, 0, HUB_Z + 0.3), PI, Vector3(wall_w, 9, 9), "w", false)
	for z in [-3.0, 0.0, 3.0]:
		_put("g67_podezd_wall", Vector3(-HUB_X - 0.3, 0, z), PI * 0.5, Vector3(wall_w, 9, 9), "w", false)
		_put("g67_podezd_wall", Vector3(HUB_X + 0.3, 0, z), -PI * 0.5, Vector3(wall_w, 9, 9), "w", false)
	_static_box(Vector3(0, 2, -HUB_Z - 0.5), Vector3(2 * HUB_X + 2, 4, 1))
	_static_box(Vector3(0, 2, HUB_Z + 0.5), Vector3(2 * HUB_X + 2, 4, 1))
	_static_box(Vector3(-HUB_X - 0.5, 2, 0), Vector3(1, 4, 2 * HUB_Z + 2))
	_static_box(Vector3(HUB_X + 0.5, 2, 0), Vector3(1, 4, 2 * HUB_Z + 2))
	# потолок и стена над модулями (модуль ниже потолка — выше идёт побелка)
	var white := _concrete(Color(0.2, 0.2, 0.19), Color(0.3, 0.3, 0.28), 0.5, 21)      # потолок в тени: лампа висит ниже
	_box(Vector3(0, HUB_H + 0.1, 0), Vector3(2 * HUB_X + 1.2, 0.2, 2 * HUB_Z + 1.2), white)
	# свет: лампа под потолком (дрожит — её ведёт контроллер), тёплый отсвет у телевизора
	_light(Vector3(0, 2.7, 0.5), Color(1.0, 0.86, 0.62), 2.4, 12.0)
	_light(Vector3(-2.5, 2.4, -3.0), Color(0.9, 0.86, 0.8), 1.2, 7.0)
	_light(Vector3(1.0, 1.2, -3.6), Color(0.55, 0.7, 1.0), 1.1, 4.5)

	# лестница на второй этаж и скрытая дверь под ней
	_put("g67_stair_flight", Vector3(-2.7, 0, -2.9), 0.0, Vector3(1.5, 2.0, 4.0))
	_put("g67_service_door", Vector3(-0.95, 0, -4.7), 0.0, Vector3(1.2, 1.9, 0.8))
	_point("door", "КОЛЯСОЧНАЯ", "заколочена", Vector3(-0.95, 0, -4.0))
	# телевизор на табуретке
	var wood := _mat(Color(0.36, 0.25, 0.16), 0.0, 0.8)
	_box(Vector3(1.0, 0.28, -4.2), Vector3(0.6, 0.56, 0.5), wood)
	_static_box(Vector3(1.0, 0.5, -4.2), Vector3(0.7, 1.0, 0.6))
	_put("res://assets/minigames/menu_crt_tv.glb", Vector3(1.0, 0.56, -4.2), 0.0, Vector3(0.8, 0.7, 0.8), "h", false)
	_point("tv", "ТЕЛЕВИЗОР", "ОБЛАКО LIVE · АРХИВ ПИЗДЕЦА", Vector3(1.0, 0, -3.3))
	# сервант с артефактами
	_put("g67_artifact_cabinet", Vector3(2.7, 0, -4.45), 0.0, Vector3(1.6, 1.9, 0.9))
	_point("artifacts", "КОЛЛЕКЦИЯ АРТЕФАКТОВ", "пока пусто", Vector3(2.7, 0, -3.6))
	# стол улучшений
	_put("res://assets/minigames/ml_desk.glb", Vector3(3.3, 0, -1.9), -PI * 0.5, Vector3(1.3, 0.85, 0.8))
	_point("upgrades", "АВТОРИТЕТ РАЙОНА", "улучшения за РЕСПЕКТ", Vector3(2.5, 0, -1.9))
	# стойка стилей
	_put("g67_style_rack", Vector3(3.45, 0, 0.7), -PI * 0.5, Vector3(1.4, 1.9, 0.8))
	_point("styles", "СТОЙКА СТИЛЕЙ", "Балон VOZDUH", Vector3(2.6, 0, 0.7))
	# карта маршрутов у выхода
	_put("g67_route_board", Vector3(3.8, 0.85, 3.1), -PI * 0.5, Vector3(1.6, 1.2, 0.5), "h", false)
	_point("routes", "КАРТА МАРШРУТОВ", "ДВОР", Vector3(3.0, 0, 3.1))
	# почтовые ящики и доска объявлений
	_put("g67_mailboxes", Vector3(-3.8, 1.05, 1.4), PI * 0.5, Vector3(1.5, 0.8, 0.5), "h", false)
	_point("mail", "ПОЧТОВЫЕ ЯЩИКИ", "листовки турнира", Vector3(-3.0, 0, 1.4))
	_put("g67_notice_board", Vector3(-3.55, 0, 3.4), PI * 0.5, Vector3(1.4, 1.7, 0.5))
	_point("notices", "ДОСКА ОБЪЯВЛЕНИЙ", "ТУРНИР 67 — 67 000 ГОЛДЫ", Vector3(-2.8, 0, 3.4))
	# стенд с плакатом турнира у выхода
	_put("g67_poster_stand", Vector3(1.9, 0, 4.4), PI, Vector3(1.2, 2.0, 0.6))
	# лавочка и dj flürr (крыльцо появится вместе с двором — пока он сидит у входа внутри)
	_put("res://assets/racing/bench.glb", Vector3(-2.3, 0, 4.4), PI * 0.5, Vector3(2.4, 0.95, 2.4))
	_actor("g67_dj_flurr", G67Models.DIR + "g67_dj_flurr.glb", 1.8, Vector3(-0.8, 0.0, 4.2), PI)
	_point("flurr", "dj flürr", "поговорить", Vector3(-0.8, 0, 3.4))
	# выход во двор
	_point("exit", "ВЫХОД ВО ДВОР", "начать забег", Vector3(0.4, 0, 4.4))
