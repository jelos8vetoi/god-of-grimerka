extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	# This test writes a genuine campaign save, so require an explicitly isolated profile.
	var dedicated := OS.get_environment("GRIMERKA_LAB_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	if dedicated.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(dedicated + "/"):
		push_error("An isolated OS user-data root is required")
		quit(1)
		return
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if "--balance-lab" in OS.get_cmdline_user_args():
		await _panel(main)
		return
	check(is_instance_valid(main.menu), "Main menu missing")
	main.start_game()
	var story = main.game
	check(story.run_type == &"campaign" and story.survival == null and story.telemetry == null, "Campaign isolation failed")
	story.xp = 137
	story._save()
	var fingerprint := FileAccess.get_sha256(story.SAVE)
	check(not fingerprint.is_empty(), "Campaign save missing")
	story._to_menu()
	await process_frame
	main.start_survival()
	for i in 600:
		await physics_frame
		if main.game and main.game.survival and main.game.survival.active:
			break
	if main.game == null or main.game.survival == null or not main.game.survival.active:
		push_error("Menu launch failed")
		quit(1)
		return
	var game = main.game
	check(game.mode == "fight" and game.xp != 137, "Survival loaded campaign state")
	game.set_paused(true)
	var elapsed: float = game.survival.elapsed
	for i in 10:
		await physics_frame
	check(is_equal_approx(elapsed, game.survival.elapsed), "Paused Survival clock advanced")
	game.set_paused(false)
	var foe = game._make_enemy("bot", "", game.player.global_position + Vector3.FORWARD * 2, true)
	foe.state = "chase"
	foe.take_hit(1.0, Vector3.FORWARD, 1.0, true, 7.0)
	game.tag.tag_cd = 0.0
	check(game.tag.try_tag() and foe.air_tags == 1 and game.player.hero == "madk1d", "Air Tag failed")
	game._save()
	game._to_menu()
	await process_frame
	await process_frame
	check(not is_instance_valid(game) and FileAccess.get_sha256("user://grimerka_save.json") == fingerprint, "Survival changed campaign or retained old game")
	main.start_game(true)
	check(main.game.xp == 137 and main.game.run_type == &"campaign" and main.game.run_mods == null, "Story resume failed")
	main.queue_free()
	await process_frame
	await process_frame
	print("Campaign/save/Survival integration: %d failures" % failures)
	quit(1 if failures else 0)

func _panel(main) -> void:
	var panel = main.get_child(-1)
	var scenario_id := "duo"
	for i in panel.scenario.item_count:
		if panel.scenario.get_item_text(i) == scenario_id:
			panel.scenario.select(i)
	panel._launch()
	check(panel.job > 0, "Panel did not start controlled trial")
	var deadline := Time.get_ticks_msec() + 90000
	while panel.job > 0 and Time.get_ticks_msec() < deadline:
		await create_timer(0.15, true, false, true).timeout
	check(panel.job < 0 and panel.after.get("samples", []).size() == 2, "Panel did not load completed trial")
	if not panel.after.is_empty():
		panel.slot = 0
		panel._loaded(panel.sources[1])
	var baseline := OS.get_environment("GRIMERKA_LAB_BASELINE")
	var experiment := OS.get_environment("GRIMERKA_LAB_EXPERIMENT")
	if baseline != "" and experiment != "":
		panel.slot = 0
		panel._loaded(baseline)
		panel.slot = 1
		panel._loaded(experiment)
		check(not panel._notes().is_empty(), "Expected measured experiment to trigger review")
		for key in panel.sliders:
			panel.sliders[key].value = panel.after.experimental_profile[key]
	for i in panel.tabs.item_count:
		panel.tabs.select(i)
		panel._refresh()
		check(not panel.content.text.is_empty(), "Empty lab section")
	panel._export()
	check(FileAccess.file_exists(panel.status.text), "Panel did not export proposal")
	main.queue_free()
	await process_frame
	print("Balance panel / child process / export: %d failures" % failures)
	quit(1 if failures else 0)

