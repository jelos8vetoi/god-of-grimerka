extends SceneTree

const Records := preload("res://scripts/survival_records.gd")
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _run() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func(): quit(1))
	var path := OS.get_temp_dir().path_join("survival_test_%d.json" % OS.get_process_id())
	_expect(Records.read(path)["completed_runs"] == 0, "Missing file fallback")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	if corrupt == null:
		quit(1)
		return
	corrupt.store_string("{bad")
	corrupt.close()
	_expect(Records.read(path)["completed_runs"] == 0, "Corrupt file fallback")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_game(false, -1, false, &"survival")
	for run in 3:
		var game = main.game
		game.survival.records_path = path
		game.survival.tick(60.0 + run)
		game.kills = 3 - run
		for hero in 2:
			game.player.inv = 0.0
			game.player.take_damage(10000.0, game.player.global_position + Vector3.RIGHT)
			if hero == 0:
				_expect(not game.over and game.player.hero == "madk1d", "First knockout ended the run")
		_expect(game.over and game.death != null and not game.survival.active, "Second knockout did not end the run")
		if not game.over:
			quit(1)
			return
		game.on_player_dead()
		_expect(Records.read(path)["completed_runs"] == run + 1, "Result was not written exactly once")
		if run < 2:
			game.death._activate()
			await process_frame
			await process_frame
			_expect(not is_instance_valid(game) and main.game.survival.elapsed < 1.0
				and main.game.player.hero == "pahan" and main.game.player.hp == main.game.player.max_hp
				and main.game.enemies.is_empty() and Engine.time_scale == 1.0, "Restart retained old state")
		else:
			game.death._pick(1)
			game.death._activate()
			await process_frame
			await process_frame
			_expect(not is_instance_valid(game) and main.game == null and is_instance_valid(main.menu), "Menu return failed")
	var record := Records.read(path)
	_expect(floori(record["best_time"]) == 62 and record["best_kills"] == 3 and record["last_run"]["kills"] == 1, "Stored records did not reload")
	DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame
	await process_frame
	print("Survival defeat/restart: %d failures" % failed)
	quit(1 if failed else 0)
