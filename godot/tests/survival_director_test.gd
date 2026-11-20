extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func():
		push_error("Survival test exceeded its deadline")
		quit(1))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_game(false, -1, false, &"survival")
	var game = main.game
	var director = game.survival.director
	director.next_boss = INF
	director.next_event = INF
	game.survival.next_draft = INF # This test jumps the clock to exercise spawning.
	director.rng.seed = 47
	var last := -1.0
	for seconds in [0, 300, 600, 1200, 2400, 14400]:
		var threat: float = director.pressure_at(seconds)
		_expect(threat > last and threat < 1.0, "Invalid threat at %ds" % seconds)
		last = threat
	await physics_frame
	var obstacle := Vector3(12.5, 0.05, 6.0)
	_expect(not director.can_spawn_at(game, obstacle), "Allowed spawn inside a dumpster")
	_expect(not director.can_spawn_at(game, Vector3(16.0, 0.05, 0.0)), "Allowed spawn outside arena")
	_expect(not director.can_spawn_at(game, game.player.global_position), "Allowed spawn on player")

	var first = null
	for frame in 180:
		await physics_frame
		if not game.enemies.is_empty():
			first = game.enemies[0]
			break
	_expect(is_instance_valid(first) and first.kind == "bot", "Opening enemy did not spawn")
	_expect(director.threat > 0.0, "Active clock did not grow threat")
	var attacks: Array = []
	game.player.combat.attack_started.connect(func(move): attacks.append(move))
	Input.action_press("attack")
	for frame in 20:
		await physics_frame
	Input.action_release("attack")
	_expect(not attacks.is_empty(), "Player could not attack during Survival")

	var seen := {}
	var ids := {}
	var peak_alive := 0
	var peak_bodies := 0
	var filled_frames := 0
	var base_nodes := get_node_count()
	director.advance(2400.0)
	for frame in 120:
		await physics_frame
		# Accelerate the spawn schedule only. AI and physics keep their normal deltas.
		director.advance(0.9)
		var bodies := 0
		var alive := 0
		for enemy in game.enemies:
			if not is_instance_valid(enemy):
				continue
			bodies += 1
			alive += int(enemy.state != "dead")
			var id: int = enemy.get_instance_id()
			if not ids.has(id):
				ids[id] = weakref(enemy)
				seen[enemy.kind] = true
				var gap: Vector3 = enemy.global_position - game.player.global_position
				_expect(Vector2(gap.x, gap.z).length() >= director.SAFE_DISTANCE - 0.15, "Enemy spawned too close")
				_expect(game.in_arena(enemy.global_position, 1.0), "Enemy spawned beyond the arena")
		peak_alive = maxi(peak_alive, alive)
		peak_bodies = maxi(peak_bodies, bodies)
		if alive == director.MAX_ALIVE:
			filled_frames += 1
		if frame >= 52 and frame % 15 == 7:
			for enemy in game.enemies:
				if is_instance_valid(enemy) and enemy.alive() and enemy.state != "spawn":
					enemy.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	_expect(seen.size() >= 4, "Insufficient enemy variety")
	_expect(filled_frames > 5 and peak_alive == director.MAX_ALIVE, "Active cap was not exercised")
	_expect(peak_bodies <= director.MAX_BODIES and director.queue.size() <= 3, "Spawn state exceeded its bounds")
	game.survival.active = false
	for frame in 330:
		await physics_frame
		game.player.inv = 1.0
		if frame == 65:
			for enemy in game.enemies:
				if is_instance_valid(enemy) and enemy.alive():
					enemy.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
	for reference in ids.values():
		_expect(reference.get_ref() == null, "Dead enemy was retained")
	_expect(game.enemies.is_empty() and get_node_count() < base_nodes + 40, "Enemy nodes or effects accumulated")
	_expect(game.mode == "fight" and game.step == -1, "Campaign progression ran in Survival")
	print("Survival: %d kinds, %d enemies, peak %d alive / %d bodies, %d failures" % [
		seen.size(), ids.size(), peak_alive, peak_bodies, failures])
	main.queue_free()
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	quit(1 if failures else 0)
