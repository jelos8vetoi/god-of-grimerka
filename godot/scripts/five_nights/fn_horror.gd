## Редкие странности «5 НОЧЕЙ С ПАХАНОМ» — не вредят, только пугают (смерть — только от врагов по правилам).
## В будке: фото меняет лица, на столе появляется фигурка Балона, в погасшем экране отражается фигура за спиной,
## дверь кладовки приоткрыта, на стене проступает надпись. На камерах: на миг — лицо в кадре, кадр зависает,
## в списке появляется CAM 9 («комната, которой нет»). Раз в 45–90 с шанс одной странности, первые 40 с — ничего,
## за ночь не больше MAX. Секреты: CAM 9, долгий взгляд на «неправильное» фото, журнал сервера, двойник.
class_name FNHorror
extends Node

const MAX := 5
var root
var next_t := 40.0
var count := 0
var photo_wrong_t := 0.0
var photo_look := 0.0
var writing_t := 0.0
var cam9_t := 0.0
var server_look := 0.0
var double_done := false
var rng := RandomNumberGenerator.new()

func reset(seed_v: int) -> void:
	rng.seed = seed_v
	next_t = rng.randf_range(40.0, 60.0)
	count = 0
	photo_wrong_t = 0.0
	writing_t = 0.0
	cam9_t = 0.0
	server_look = 0.0
	double_done = false
	var o: FNOffice = root.office
	o.photo.material_override.albedo_texture = o.photo_tex["normal"]
	o.writing.visible = false
	o.extra_item.visible = false
	o.closet.rotation.y = 0.0
	o.reflection.visible = false

func tick(st: FNNight, dt: float) -> void:
	var o: FNOffice = root.office
	# фото: пока «неправильное» — долгий взгляд открывает записку
	if photo_wrong_t > 0.0:
		photo_wrong_t -= dt
		var looking: bool = not st.monitor and absf(st.yaw - 0.0) < 0.2
		photo_look = photo_look + dt if looking else 0.0
		if photo_look > 2.5 and FNSave.secret("photo"):
			root.say("…«скоро вернёмся». Кто это написал?", 3.5)
		if photo_wrong_t <= 0.0:
			o.photo.material_override.albedo_texture = o.photo_tex["normal"]
	if writing_t > 0.0:
		writing_t -= dt
		if writing_t <= 0.0 or (st.yaw > 0.3):
			o.writing.visible = false
			writing_t = 0.0
	# CAM 9 в списке — недолго
	if cam9_t > 0.0:
		cam9_t -= dt
		root.ui.cam9_btn.visible = cam9_t > 0.0
		if st.monitor and st.cam == "room9" and FNSave.secret("room9"):
			root.say("КОМНАТА 9. Её нет на плане.", 3.0)
		if cam9_t <= 0.0 and st.cam == "room9":
			st.set_cam("stage")
	# журнал сервера: долго смотреть на CAM 6 с третьей ночи
	if st.night >= 2 and st.monitor and st.cam == "server":
		server_look += dt
		if server_look > 6.0 and FNSave.secret("server_log"):
			root.say("На стойке мигает журнал: «требуется оригинал: ОХРАННИК»", 4.0)
	else:
		server_look = 0.0
	next_t -= dt
	if next_t > 0.0 or count >= MAX or st.power_out:
		return
	next_t = rng.randf_range(45.0, 90.0) * (0.75 if st.night >= 3 else 1.0)
	count += 1
	_event(st)

func _event(st: FNNight) -> void:
	var o: FNOffice = root.office
	var opts := ["photo", "item", "reflection", "closet", "face", "freeze", "cam9"]
	if st.night >= 2:
		opts.append("writing")
	match opts[rng.randi() % opts.size()]:
		"photo":
			o.photo.material_override.albedo_texture = o.photo_tex["wrong"]
			photo_wrong_t = 30.0
		"item":
			o.extra_item.visible = true
		"reflection":
			if not st.monitor:
				o.reflection.visible = true
				get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): o.reflection.visible = false)
			else:
				root.pending_reflection = true          # покажется, когда опустит монитор
		"closet":
			var tw := create_tween()
			tw.tween_property(o.closet, "rotation:y", deg_to_rad(-24.0), 2.5).set_trans(Tween.TRANS_SINE)
			root.sfx3("click", o.closet.global_position + Vector3(0, 1, 0), -6.0, 0.6)
		"writing":
			o.writing.visible = true
			writing_t = 25.0
		"face":
			root.face_flash = 0.07                     # на один кадр в камере — лицо
		"freeze":
			root.cams.lost_t = 1.4
		"cam9":
			cam9_t = 7.0
			root.sfx2("static", -16.0)

## двойник: редкий безвредный скример, когда опускаешь монитор (4 AM и позже, с четвёртой ночи)
func on_monitor_down(st: FNNight) -> void:
	if root.pending_reflection:
		root.pending_reflection = false
		root.office.reflection.visible = true
		get_tree().create_timer(0.6, true, false, true).timeout.connect(func(): root.office.reflection.visible = false)
	if double_done or st.night < 3 or st.hour < 4 or rng.randf() > 0.08:
		return
	double_done = true
	root.double_scare()
	FNSave.secret("double")
