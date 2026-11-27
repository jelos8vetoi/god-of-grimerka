## Запуск: Godot --headless --path godot --fixed-fps 60 --script res://tests/race_jump_input_test.gd
extends SceneTree

var rider: RaceRider
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func button(down: bool, gamepad: bool) -> void:
	var event: InputEvent
	if gamepad:
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_LEFT_SHOULDER
		pad.pressed = down
		event = pad
	else:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = down
		event = key
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func count_event(kind: String) -> int:
	return rider.events.filter(func(e): return e[0] == kind).size()

func flight(hold_ticks: int, second_tick := -1, gamepad := false) -> float:
	rider.events.clear()
	var ground := rider.global_position.y
	var top := ground
	button(true, gamepad)
	for tick in 85:
		await physics_frame
		top = maxf(top, rider.global_position.y)
		if tick == hold_ticks:
			button(false, gamepad)
		if second_tick >= 0:
			if tick == second_tick:
				button(true, gamepad)
			elif tick == second_tick + 1:
				button(false, gamepad)
	return top - ground

func run() -> void:
	RaceSave.persist = false
	RaceSave._load()
	RaceSave.data["binds"] = {}
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	current_scene.start_race({"track": "tomsk_roofs", "mode": "time", "weather": "clear"})
	var race: Race = current_scene.race
	rider = race.local
	for tick in 420:
		if race.go:
			break
		await physics_frame
	if not race.go:
		push_error("Гонка не началась за семь секунд физики")
		quit(1)
		return
	var tap := await flight(1)
	check(count_event("jump") == 1 and count_event("jump_lift") == 0, "Короткое нажатие пробела")
	var held := await flight(70)
	check(held > tap + 0.5 and count_event("jump_lift") == 1 and count_event("double_jump") == 0 and count_event("jump") == 1, "Высота и однократный звук при удержании")
	await flight(1, 3)
	check(count_event("double_jump") == 1, "Повторное нажатие в первые кадры подъёма")
	await flight(1, 21)
	check(count_event("jump") == 1 and count_event("double_jump") == 0, "Обычный прыжок во время кулдауна")
	for tick in 300:
		if rider.double_hop_cd <= 0.0:
			break
		await physics_frame
	await flight(1, 21, true)
	check(count_event("double_jump") == 1, "Повторное нажатие LB на падении")
	print("race_jump_input: tap=%.2f held=%.2f failures=%d" % [tap, held, failures])
	quit(failures)
