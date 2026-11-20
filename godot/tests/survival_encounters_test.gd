extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames() -> void:
	await physics_frame
	await physics_frame

func _run() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func(): quit(1))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_game(false, -1, false, &"survival")
	var game = main.game
	var director = game.survival.director
	game.survival.next_draft = INF
	director.rng.seed = 91
	director._next_group = INF
	await _frames()
	for expected in ["surge", "elite", "hazard"]:
		director.advance(director.next_event - director.elapsed)
		await _frames()
		_expect(director.event_kind == expected, "Wrong event")
		if expected == "surge":
			_expect(not game.enemies.is_empty(), "Surge spawned nothing")
		elif expected == "elite":
			var elite = null
			for enemy in game.enemies:
				if is_instance_valid(enemy) and enemy.survival_elite:
					elite = enemy
			_expect(is_instance_valid(elite) and elite.has_node("EliteBadge"), "Elite absent")
			if is_instance_valid(elite):
				elite.state = "chase"
				game.player.swag = 0.0
				elite.take_hit(99999.0, Vector3.FORWARD, 0.0)
				_expect(game.player.swag == 18.0, "Elite reward missing")
		else:
			_expect(game.zones.any(func(z): return z.get("survival_event", false)), "Hazard not telegraphed")
		director.advance(17.0)
		await _frames()
		_expect(director.event_kind == "" and game.zones.is_empty(), "Event failed to clean up")
	for enemy in game.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame
	for id in ["courier", "golem"]:
		director.advance(director.next_boss - director.elapsed + 0.5)
		await _frames()
		var boss = game.boss_e
		if not is_instance_valid(boss):
			push_error("Boss absent: " + id)
			quit(1)
			return
		_expect(boss.boss_id == id, "Wrong boss")
		boss.state = "chase"
		boss.take_hit(boss.max_hp * 0.52, Vector3.FORWARD, 0.0, true)
		_expect(boss.phase >= 1, "Boss phase did not change")
		boss._special()
		_expect(boss.state == "special" and not boss.sp_events.is_empty(), "Boss special was not armed")
		game.telegraph(boss.global_position, 2.0, 10.0, 5.0, boss)
		game.spawn_bolt(boss.global_position, Vector3.FORWARD, 5.0, boss)
		var marker: WeakRef = weakref(game.zones.back()["n"])
		for i in 8:
			game._make_enemy("bot", "", Vector3(-8.0 + i, 0.05, -7.0))
		var active := 0
		for enemy in game.enemies:
			active += int(is_instance_valid(enemy) and enemy.state != "dead")
		_expect(active == 4, "Boss reinforcement cap did not hold")
		director.advance(155.0)
		await _frames()
		_expect(game.boss_e == boss, "Second boss appeared before victory")
		boss.take_hit(99999.0, Vector3.FORWARD, 0.0, true)
		await _frames()
		_expect(game.boss_e == null and game.zones.is_empty() and game.bolts.is_empty(), "Boss hazards remained")
		await process_frame
		await process_frame
		_expect(marker.get_ref() == null, "Boss warning node was retained")
		_expect(game.step == -1 and game.mode == "fight", "Campaign state changed")
	director.advance(5.0)
	await _frames()
	_expect(game.enemies.any(func(e): return is_instance_valid(e) and e.boss_id == "" and e.state != "dead"), "Regular spawns did not resume")
	main.queue_free()
	await process_frame
	await process_frame
	print("Survival encounters: %d failures" % failures)
	quit(1 if failures else 0)
