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
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.menu._open_roguelike()
	main.menu._panel_select(1)
	main.menu._panel_activate()
	_expect(main.menu.survival_history_open, "History navigation failed")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	main.menu._unhandled_input(key)
	_expect(not main.menu.survival_history_open and is_instance_valid(main.menu.panel), "Escape did not return to mode screen")
	main.start_game(false, -1, false, &"survival")
	var game = main.game
	var run = game.survival
	run.director.advance(15.0)
	run.director.bosses_defeated = 2
	game.kills = 17
	run.mods.apply("vozduh", 15.0)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var hud: Control = game.survival_hud
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(2560, 1440)]:
		root.size = resolution
		await process_frame
		await process_frame
		hud.refresh()
		var screen := Rect2(Vector2.ZERO, Vector2(resolution))
		_expect(get_root().get_visible_rect().size == Vector2(resolution), "Viewport did not resize")
		_expect(screen.encloses(hud.get_global_rect()) and not hud.get_global_rect().intersects(game.boss_box.get_global_rect()), "HUD outside safe area: %s" % resolution)
		_expect("Враги 17" in hud.details.text and "Боссы 2" in hud.details.text and "Широкий размах" in hud.boosts.text, "HUD stats are stale")
		_expect(hud.progress.value >= 50.0 and hud.progress.value < 55.0, "Incorrect draft progress")
		var draft = load("res://scripts/survival_draft.gd").new()
		game.add_child(draft)
		var choices: Array[String] = ["vozduh", "swap_hit", "air_guard"]
		draft.build(choices, run.mods)
		await process_frame
		await process_frame
		var buttons: Array[Node] = draft.find_children("*", "Button", true, false)
		_expect(buttons.size() == 3, "Missing cards")
		for i in buttons.size():
			var rect: Rect2 = buttons[i].get_global_rect()
			_expect(screen.encloses(rect), "Off-screen card")
			if i > 0:
				_expect(not rect.intersects(buttons[i - 1].get_global_rect()), "Cards overlap")
		draft.queue_free()
	var path := OS.get_temp_dir().path_join("survival_hud_%d.json" % OS.get_process_id())
	for i in 12:
		Records.record(i + 10.0, i, 0.25, path, {"bosses": 2, "events": 3, "upgrades": {"vozduh": 1}})
	var saved := Records.read(path)
	_expect(saved["history"].size() == 10 and saved["last_run"]["bosses"] == 2 and saved["last_run"]["upgrades"]["vozduh"] == 1, "History did not retain bounded real stats")
	DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame
	print("Survival HUD: %d failures" % failed)
	quit(1 if failed else 0)
