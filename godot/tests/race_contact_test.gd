## Godot --headless --path godot --fixed-fps 60 --script res://tests/race_contact_test.gd
extends SceneTree

var race: Race
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func gas(down: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = down
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func place(r: RaceRider, point: Vector3, direction: Vector3) -> void:
	r.place(Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), point))
	r.proj = race.track.project(point, {})

func wall(label: String, spd: float, angle: float, throttle: bool, natural := false) -> Vector3:
	var r := race.local
	var tr := race.track
	var i := tr.at_s(tr.start_s + 6.0)
	var tangent := tr.T[i].normalized()
	var across := tangent.cross(Vector3.UP).normalized()
	var offset := -tr.W[i] * 0.5 if natural else tr.W[i] * 0.5 + RaceTrack.SHOULDER - 1.1
	place(r, tr.P[i] + across * offset + Vector3.UP * 0.07, across * cos(angle) + tangent * sin(angle))
	await ticks(12)
	r.speed = spd
	gas(throttle)
	for step in 120:
		await physics_frame
		if r.is_on_wall():
			break
	check(r.is_on_wall(), label + " — контакт со штатным ограждением")
	var touch := r.global_position
	var normal := r.get_wall_normal() if r.is_on_wall() else -across
	var heading := r.heading
	var distance := 0.0
	var retained := 0.0
	var yaw := 0.0
	for step in 65:
		await physics_frame
		var retreat := (r.global_position - touch).dot(normal)
		if retreat < distance - 0.002:
			break
		distance = maxf(distance, retreat)
		retained = maxf(retained, absf(r.get_real_velocity().dot(tangent)))
		yaw = maxf(yaw, absf(angle_difference(heading, r.heading)))
	gas(false)
	print("%s: %.3f m, tangent %.1f m/s, yaw %.1f deg" % [label, distance, retained, rad_to_deg(yaw)])
	return Vector3(distance, retained, yaw)

func meeting() -> void:
	var a := race.local
	var b: RaceRider = race.riders[1]
	var midpoint := Vector3(-45.0, 0.08, 0.0)
	place(a, midpoint + Vector3.LEFT * 2.0, Vector3.RIGHT)
	place(b, midpoint + Vector3.RIGHT * 2.0, Vector3.LEFT)
	await ticks(10)
	a.speed = 17.0
	b.speed = 17.0
	a.events.clear()
	gas(true)
	for step in 24:
		await physics_frame
		if a.events.any(func(e): return e[0] == "bump"):
			break
	check(a.events.any(func(e): return e[0] == "bump"), "Встречный контакт двух гонщиков")
	var start_a := a.global_position.x
	var start_b := b.global_position.x
	var back_a := 0.0
	var back_b := 0.0
	for step in 36:
		await physics_frame
		back_a = maxf(back_a, start_a - a.global_position.x)
		back_b = maxf(back_b, b.global_position.x - start_b)
	gas(false)
	print("Гонщики: %.3f / %.3f m" % [back_a, back_b])
	check(back_a > 0.35 and back_a < 1.5 and back_b > 0.35 and back_b < 1.5, "Ограниченный встречный отскок")

func run() -> void:
	RaceSave.persist = false
	RaceSave._load()
	RaceSave.data["binds"] = {}
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	current_scene.start_race({"track": "tomsk_roofs", "mode": "single", "weather": "clear", "happenings": false,
		"riders": [{"id": "pahan", "kind": "local"}, {"id": "madk1d", "kind": "remote"}]})
	race = current_scene.race
	for step in 420:
		if race.go:
			break
		await physics_frame
	if not race.go:
		quit(1)
		return
	var driven := await wall("Газ с места", 0.0, 0.0, true, true)
	var fast := await wall("Лобовой с газом", 24.0, 0.0, true)
	var coast := await wall("Лобовой накатом", 24.0, 0.0, false)
	var oblique := await wall("Косой", 22.0, 0.88, true)
	var scrape := await wall("Касание", 22.0, 1.46, true)
	check(driven.x >= 0.50 and fast.x >= 0.50 and fast.x <= 1.20, "Отскок с зажатым газом")
	check(coast.x > fast.x and coast.x <= 1.25, "Затухание отскока накатом")
	check(oblique.x > 0.25 and oblique.y > 8.0 and oblique.z > 0.06, "Косой удар сохраняет ход и доворачивает корпус")
	check(scrape.x < 0.12 and scrape.y > 15.0, "Скольжение вдоль ограждения")
	await meeting()
	quit(failures)
