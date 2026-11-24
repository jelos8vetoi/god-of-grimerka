## Скримеры «5 НОЧЕЙ С ПАХАНОМ» — у каждого врага свой, в 3D, настоящей моделью:
##  БАЛОН — поднимается из-под стола во весь рост, голова рывком к лицу, пасть рвётся; лампа краснеет.
##  MADK1D — падает из люка вниз головой, голова проворачивается, руки тянутся к лицу.
##  BOT — вламывается слева, камеру дёргает к нему, голова трясётся всё быстрее, кадр заедает.
##  CLIPPER — рывок из проёма через всю комнату, катана наискосок через кадр (красный разрез).
##  GHOST — висит прямо перед столом, медленно, потом в упор; цвета выворачивает.
##  MOD — монитор сам поднимается, он пробивает экран кулаком, осколки, синяя вспышка.
##  ТЕМНОТА — глаза в проёме, дыхание, лампа вспыхивает красным: Балон уже в будке.
## Перед скримером — один из вариантов затишья (тишина, мигание, шаги), чтобы момент не угадывался.
## Свет, камера и звук после — возвращаются в FiveNightsRoot (экран гибели).
class_name FNScare
extends Node

var root
var office: FNOffice
var actors: FNActors
var busy := false
var cam_from := Transform3D()
## Свои модели (FNActors.owned) другого роста и сложения, чем те, под которые ставились скримеры. Поэтому с момента
## крика лицо модели само подводится к камере: AIM[id] = [расстояние от глаз Пахана, на сколько ниже центра кадра].
## Модель сдвигается внутри своего рига (плавно — тряска камеры остаётся видна), после скримера возвращается.
const AIM := {"balon": [0.62, 0.03], "madk1d": [0.52, 0.02], "bot": [0.6, 0.02], "clipper": [0.72, -0.03], "ghost": [0.45, 0.0], "mod": [1.05, 0.06]}
var aim_id := ""
## Мёртвая тишина перед ударом: веса вариантов у каждого свои (кто-то почти всегда выходит из тишины, кто-то — без
## предупреждения). dead — пропадает всё, amb — гул и вентиляция, sfx — обрываются эффекты, none — тишины нет.
const HUSH := {
	"balon": {"dead": 5, "amb": 3, "none": 2}, "dark": {"dead": 6, "none": 4},
	"madk1d": {"dead": 4, "sfx": 3, "none": 3}, "bot": {"dead": 3, "amb": 4, "none": 3},
	"clipper": {"none": 6, "dead": 2, "sfx": 2}, "ghost": {"dead": 7, "amb": 3},
	"mod": {"sfx": 4, "dead": 4, "none": 2}, "pahan": {"dead": 1},
}
const HUSH_LEN := Vector2(0.15, 0.35)   # сколько длится тишина, с
static var hush_last := ""
var hush := "none"                 # вариант этого скримера
var hush_len := 0.0
var hush_t0 := 0                   # когда началась тишина (мс) — для проверки
var scream_len := 1.0

func _pick_hush(eid: String) -> String:
	var W: Dictionary = HUSH.get(eid, {"dead": 1, "none": 1})
	var sum := 0
	for k in W:
		@warning_ignore("integer_division")
		sum += int(W[k]) if not (k == hush_last and W.size() > 1) else maxi(1, int(W[k]) / 3)     # тот же вариант подряд — редко
	var x := randi() % maxi(1, sum)
	for k in W:
		@warning_ignore("integer_division")
		x -= int(W[k]) if not (k == hush_last and W.size() > 1) else maxi(1, int(W[k]) / 3)
		if x < 0:
			hush_last = String(k)
			return String(k)
	return "none"

## ожидание перед ударом: последние hush_len секунд — в тишине (если она выпала)
func _lead(sec: float) -> void:
	var cut := hush_len if hush != "none" else 0.0
	await _wait(maxf(0.0, sec - cut))
	if hush != "none":
		hush_t0 = GameClock.ms()
		root.hush_begin(hush)
		await _wait(cut)

func _process(dt: float) -> void:
	if aim_id == "" or not actors.owned.has(aim_id):
		return
	var r: Rig = actors.rigs[aim_id]
	var c := office.cam.global_transform
	var k := 1.0 - exp(-14.0 * dt)
	# лицом к Пахану: модель доворачивается вокруг своего лица, пока оно не смотрит в камеру (поза скримера у
	# сгорбленных и большеголовых иначе показывает макушку или спину)
	var eyes: Node3D = actors.face[aim_id]["eyes"]
	var fp := eyes.global_position
	var f := eyes.global_transform.basis.z.normalized()
	var d := (c.origin - fp).normalized()
	if f.dot(d) < 0.9995:
		var q := Quaternion(f, d)
		var turn := Basis(Quaternion.IDENTITY.slerp(q, k))
		var mt := r.model.global_transform
		r.model.global_transform = Transform3D(turn * mt.basis, fp + turn * (mt.origin - fp))
	var want: Vector3 = c.origin - c.basis.z * float(AIM[aim_id][0]) - c.basis.y * float(AIM[aim_id][1])
	r.model.global_position += (want - eyes.global_position) * (1.0 - exp(-30.0 * dt))

func setup(r) -> void:
	root = r
	office = r.office
	cam_from = office.rest_view
	actors = r.actors

## позиция перед глазами: вперёд на d, сдвиг вбок x, высота y
func _front(d: float, x := 0.0, y := 0.0) -> Vector3:
	var b := office.cam.global_transform.basis
	return office.cam.global_position - b.z * d + b.x * x + Vector3(0, y, 0)

func _face_cam(r: Rig, p: Vector3) -> void:
	var to := office.cam.global_position - p
	r.global_position = p
	r.rotation = Vector3(0, atan2(to.x, to.z), 0)

## главный вход: кто и где. pre — вариант затишья перед ударом (0..2)
func play(eid: String, at: String, pre: int) -> void:
	busy = true
	cam_from = office.cam.transform
	hush = force_hush if force_hush != "" else _pick_hush(eid)
	hush_len = randf_range(HUSH_LEN.x, HUSH_LEN.y)
	side = 1.0 if at.ends_with("_r") else -1.0
	match (pre if hush == "none" else (1 if pre == 1 else 0)):
		0:                                          # без вступления: тишина (если выпала) придёт прямо перед ударом
			pass
		1:                                          # лампа мигает и гаснет
			for k in 4:
				office.set_lamp_energy(0.0 if k % 2 == 0 else 0.6)
				await _wait(0.09)
			await _wait(0.25)
		_:                                          # быстрые шаги
			root.sfx3("step_heavy", FNOffice.point(at if at.begins_with("door") else "door_l"), 2.0, 1.4)
			await _wait(0.22)
			root.sfx3("step_heavy", FNOffice.point(at if at.begins_with("door") else "door_l"), 4.0, 1.5)
			await _wait(0.2)
	root.duck(false)
	root.ui.tablet_k = 0.0
	actors.hide_all()
	var r: Rig = actors.rigs.get("balon" if eid == "dark" else eid)
	r.visible = true
	scare_id = "balon" if eid == "dark" else eid
	aim_id = ""
	match eid:
		"balon", "dark":                    # "dark" — Балон из темноты после отключения питания
			await _balon(r, at == "dark")
		"madk1d":
			await _madk1d(r)
		"bot":
			await _bot(r)
		"clipper":
			await _clipper(r)
		"ghost":
			await _ghost(r)
		_:
			await _mod(r)
	busy = false

var scare_id := ""                # чей скример идёт
var force_hush := ""              # проверка: задать вариант тишины
var side := -1.0                  # с какой стороны пришёл: −1 — левая дверь, +1 — правая

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

## общее: крик, свет, тряска, искажение, наезд камеры (FOV)
func _hit(scream: String, lamp_col: Color, fov_to := 58.0) -> void:
	scream_len = root.scream(scream.trim_prefix("scream_"))          # крик — в тот же кадр, что и рывок
	aim_id = scare_id
	actors.eyes_boost(scare_id, 3.0)
	office.set_lamp_color(lamp_col)
	office.set_lamp_energy(3.2)
	office.scare_light.light_color = Color(1.0, 0.95, 0.9).lerp(lamp_col, 0.45)
	office.scare_light.light_energy = 4.0
	office.shake = 1.6
	root.ui.hurt = 1.0
	var tw := create_tween()
	tw.tween_property(office.cam, "fov", fov_to, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _maw_open(id: String, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float): actors.maw(id, k), 0.0, 1.0, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake_loop(sec: float, k: float) -> void:
	var t0 := GameClock.ms()
	await get_tree().create_timer(0.14, true, false, true).timeout       # рывок взгляда к лицу успевает закончиться
	# поза рывка держится до конца крика: клип дальше почти стоит (иначе корпус продолжает клониться и лицо уходит
	# из кадра — у Балона была видна макушка баллона). У BOT клип дёргается своим кодом — его не трогаем.
	var rig: Rig = actors.rigs.get(scare_id)
	if rig != null and scare_id != "bot":
		rig.player.speed_scale = 0.08
	# тряска — вокруг одного взгляда, а не случайным блужданием: лицо остаётся в кадре до конца крика
	var base: Vector3 = office.cam.rotation
	while GameClock.ms() - t0 < int(sec * 1000.0):
		var fade := 1.0 - 0.5 * clampf(float(GameClock.ms() - t0) / (sec * 1000.0), 0.0, 1.0)
		office.shake = maxf(office.shake, k * fade)
		office.scare_light.light_energy = randf_range(2.2, 5.0) if randf() > 0.12 else 0.4     # свет бьётся
		office.cam.rotation = base + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03 * k * fade
		await get_tree().process_frame
	office.cam.rotation = base

# ---------------- БАЛОН ----------------
func _balon(r: Rig, dark: bool) -> void:
	if dark:
		# глаза уже в проёме — дыхание, шаг, ещё шаг, и он в будке
		office.dark_eyes.visible = false
		root.sfx2("breath", -6.0)
		_face_cam(r, _front(2.8, -0.4, -1.32))
		r.play("FNStill", 0.0)
		await _wait(0.6)
		_face_cam(r, _front(1.4, -0.2, -1.32))
		await _wait(0.35)
	# из-под стола: стартует ниже пола, выпрямляется перед столом; взгляд Пахана задирается к его голове
	var start := _front(1.25, 0.0, -1.32 - 1.2)
	_face_cam(r, start)
	r.play_for("FNScare", 1.2, 0.0)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(r, "global_position", _front(1.2, 0.0, -1.32 - 0.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var look := create_tween()
	look.tween_interval(0.25)
	look.tween_property(office.cam, "rotation", Vector3(0.28, office.cam.rotation.y, 0.0), 0.12).set_trans(Tween.TRANS_EXPO)
	await _lead(0.34)
	_hit("scream_dark" if dark else "scream_balon", Color(1.0, 0.12, 0.08))
	_maw_open("balon", 0.18)
	var tw2 := create_tween()
	tw2.tween_property(r, "global_position", _front(0.7, 0.0, -1.32 - 0.5), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await _shake_loop(clampf(scream_len * 0.45, 0.85, 1.4), 1.0)        # низкий долгий рёв — и трясёт дольше

# ---------------- MADK1D ----------------
func _madk1d(r: Rig) -> void:
	# люк распахивается, он падает на стол на корточки лицом к Пахану — и прыгает в лицо
	var hp := Vector3(0.35, 2.69, -0.95)
	r.rotation = Vector3.ZERO
	r.global_position = Vector3(0.3, 2.9, -0.85)
	r.play_for("FNScare", 1.1, 0.0)
	_face_cam(r, r.global_position)
	office.hatch.rotation.x = -1.3
	root.sfx3("vent_bang", hp, 4.0, 0.8)
	var look := create_tween()
	look.tween_property(office.cam, "rotation", Vector3(-0.05, 0.0, 0.0), 0.15)
	var tw := create_tween()
	tw.tween_property(r, "global_position", Vector3(0.2, 0.8, -0.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _lead(0.42)
	_hit("scream_madk1d", Color(0.9, 0.2, 0.15), 54.0)
	_maw_open("madk1d", 0.14)
	var tw2 := create_tween()
	tw2.tween_property(r, "global_position", Vector3(0.05, 0.62, -0.28), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await _shake_loop(0.9, 0.9)
	office.hatch.rotation.x = 0.0

# ---------------- BOT ----------------
func _bot(r: Rig) -> void:
	var p0 := FNOffice.point("door_l" if side < 0.0 else "door_r")       # вламывается с той стороны, где стоял
	_face_cam(r, p0)
	r.play("FNWalk", 0.0, 2.0)
	var look := create_tween()
	look.tween_property(office.cam, "rotation", Vector3(-0.05, deg_to_rad(-58.0 * side), 0.0), 0.14).set_trans(Tween.TRANS_EXPO)
	var tw := create_tween()
	tw.tween_property(r, "global_position", Vector3(0.85 * side, 0.0, 0.2), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	root.sfx3("clank", p0, 6.0, 0.9)
	await _lead(0.3)
	r.play_for("FNScare", 1.1, 0.0)
	_hit("scream_bot", Color(1.0, 0.1, 0.1))
	_maw_open("bot", 0.1)
	# кадр заедает: анимация рывками
	for k in 9:
		r.player.speed_scale = 0.0 if k % 2 == 0 else 3.0
		office.set_lamp_energy(3.0 if k % 2 == 0 else 0.2)
		root.ui.hurt = 1.0
		await _wait(0.07)
	r.player.speed_scale = 1.0
	var tw2 := create_tween()
	tw2.tween_property(r, "global_position", Vector3(0.55 * side, 0.0, 0.45), 0.15)
	await _shake_loop(0.4, 1.0)

# ---------------- CLIPPER ----------------
func _clipper(r: Rig) -> void:
	var p0 := FNOffice.point("door_l" if side < 0.0 else "door_r") + Vector3(0.6 * side, 0, 0)
	var look := create_tween()
	look.tween_property(office.cam, "rotation", Vector3(-0.08, deg_to_rad(-40.0 * side), 0.0), 0.1)
	_face_cam(r, p0)
	r.play("Run", 0.0, 1.6)
	root.sfx3("scrape", p0, 6.0, 1.3)
	var tw := create_tween()
	tw.tween_property(r, "global_position", _front(0.75, 0.1 * side, -1.32), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await _wait(0.2)
	_face_cam(r, r.global_position)
	r.play_for("FNScare", 0.9, 0.0)
	var turn := create_tween()                   # взгляд рывком за ним — он уже перед лицом
	turn.tween_property(office.cam, "rotation", Vector3(-0.22, 0.0, 0.0), 0.1).set_trans(Tween.TRANS_EXPO)
	await _lead(0.36)
	_hit("scream_clipper", Color(0.85, 0.85, 1.0), 60.0)
	_maw_open("clipper", 0.1)
	root.ui_slash()
	await _shake_loop(0.6, 1.2)                  # крик короткий — и удар короткий

# ---------------- GHOST ----------------
func _ghost(r: Rig) -> void:
	office.set_lamp_energy(0.15)
	_face_cam(r, _front(1.7, 0.1, -1.25))
	r.play_for("FNScare", 1.4, 0.0)
	root.sfx2("whisper", 0.0)
	var tw := create_tween()
	tw.tween_property(r, "global_position", _front(1.1, 0.05, -1.22), 0.6).set_trans(Tween.TRANS_SINE)
	await _lead(0.6)
	_face_cam(r, _front(0.33, 0.0, -1.2))
	_hit("scream_ghost", Color(0.7, 0.6, 1.0), 50.0)
	_maw_open("ghost", 0.08)
	root.ui_invert(0.45)
	await _shake_loop(1.25, 0.8)                 # вой с эхом тянется — он висит перед лицом дольше

# ---------------- MOD ----------------
func _mod(r: Rig) -> void:
	# монитор поднимается сам, на нём — его лицо в помехах
	root.force_tablet_face()
	await _wait(0.55)
	root.ui.tablet_k = 0.0
	_face_cam(r, _front(1.35, 0.0, -1.05))
	r.play_for("FNScare", 1.0, 0.0)
	await _lead(0.32)
	_hit("scream_mod", Color(0.45, 0.6, 1.0), 56.0)
	_maw_open("mod", 0.1)
	root.shards(_front(0.6, 0, -0.05))
	var tw := create_tween()
	tw.tween_property(r, "global_position", _front(1.05, 0.0, -1.05), 0.14).set_trans(Tween.TRANS_EXPO)
	await _shake_loop(0.8, 1.0)

# ---------------- ПАХАН: его же «резервная копия», в негативе ----------------
## Сначала — отражение в погасшем мониторе. Тишина, лампа гаснет, весь кадр уходит в негатив: перед столом стоит
## Пахан. Голова завалена набок, дёргается. Миг — и он в упор: голова рывком, пасть, его же голос срывается в визг.
## lethal = false — безвредный (секрет): после него ночь идёт дальше.
func pahan(lethal := false) -> void:
	busy = true
	cam_from = office.cam.transform
	var r: Rig = actors.pahan_copy()
	office.reflection.visible = true
	hush = "dead"
	hush_len = randf_range(HUSH_LEN.x, HUSH_LEN.y)
	root.sfx2("heart", -6.0, 0.8)
	await _wait(0.5)
	office.reflection.visible = false
	office.set_lamp_energy(0.0)
	root.ui.neg = true
	var look := create_tween()
	look.tween_property(office.cam, "rotation", Vector3(-0.05, 0.0, 0.0), 0.1)
	_face_cam(r, _front(2.0, 0.15, -1.32))
	r.visible = true
	r.play("FNStill", 0.0)
	office.scare_light.light_color = Color(0.85, 0.9, 1.0)
	office.scare_light.light_energy = 1.2
	await _lead(0.75)
	r.play_for("FNScare", 1.0, 0.0)
	_face_cam(r, _front(0.92, 0.0, -1.3))
	scream_len = root.scream("pahan")
	office.shake = 1.8
	root.ui.hurt = 1.0
	office.scare_light.light_energy = 4.5
	var tw := create_tween()
	tw.tween_property(office.cam, "fov", 50.0, 0.1).set_trans(Tween.TRANS_EXPO)
	_maw_open("pahan", 0.12)
	await _shake_loop(0.75, 1.1)
	root.ui.neg = false
	if not lethal:
		root.hush_end()
		r.visible = false
		actors.maw("pahan", 0.0)
		office.scare_light.light_energy = 0.0
		office.cam.fov = office.rest_fov
		office.cam.transform = cam_from
		office.set_lamp_energy(office.lamp_base)
	busy = false

## вернуть всё, что трогал скример
func restore() -> void:
	aim_id = ""
	root.hush_end()
	office.scare_light.light_energy = 0.0
	office.cam.fov = office.rest_fov
	office.cam.transform = cam_from
	office.set_lamp_color(office.lamp_tint)
	office.set_lamp_energy(office.lamp_base)
	office.hatch.rotation.x = 0.0
	for id in actors.rigs:
		actors.maw(id, 0.0)
		actors.eyes_boost(String(id), 1.0)
		(actors.rigs[id] as Rig).player.speed_scale = 1.0
	actors.hide_all()
