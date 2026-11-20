extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func(): quit(1))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_game(false, -1, false, &"survival")
	var game = main.game
	var m = game.telemetry
	var p = game.player
	m.directory = OS.get_temp_dir().path_join("grimerka_telemetry_%d" % OS.get_process_id())
	var bot = game._make_enemy("bot", "", p.global_position + Vector3.BACK * 1.4, true)
	bot.state = "chase"
	var attack: AttackData = Styles.by_id("vozduh").attack("vz_light1")
	p.combat._launch(attack, false)
	p.face = 0.0
	game.run_mods.apply("swap_hit", 60.0)
	game.run_mods.perfect_swap(game)
	p.combat._resolve_hits(0, true)
	p.combat._resolve_hits(0, false)
	var row: Dictionary = m.attacks.get("pahan/vozduh/vz_light1", {})
	_expect(row.get("hits") == 1 and row.get("uses") == 1 and row.get("unique_targets") == 1, "Duplicate or missing melee count")
	_expect(is_equal_approx(row.get("weapon_base_damage", -1), attack.damage) and is_equal_approx(row.get("ordinary_damage", -1), attack.damage), "Melee baseline mismatch")
	_expect(is_equal_approx(row.get("actual_hp_lost", -1), attack.damage * 1.18), "Swap damage mismatch")
	bot.hp = 3.0
	var bottle: AttackData = Styles.by_id("bottles").attack("bt_throw")
	if bottle == null:
		for candidate in Styles.by_id("bottles").attacks.values():
			if candidate.projectile == "bottle":
				bottle = candidate
				break
	p.bottles._shatter({"a": bottle, "power": 0.0, "vel": Vector3.BACK, "telemetry_hero": "pahan", "telemetry_style": "bottles"}, bot.global_position, Vector3.UP, bot)
	var bottle_row: Dictionary = m.attacks.get("pahan/bottles/" + bottle.id, {})
	_expect(bottle_row.get("hits") == 1 and bottle_row.get("actual_hp_lost") == 3.0, "Bottle overkill or duplicate")
	var boss = game._make_enemy("", "courier", Vector3(0, 0.05, -8), true)
	boss.state = "chase"
	m.boss_ready(boss)
	boss.record_ability("test_zone")
	game.telegraph(p.global_position, 2.0, 0.4, 20.0, boss)
	boss.record_ability("test_other")
	p.state = "move"
	p.rage = 0.0
	p.inv = 0.0
	game._update_zones(0.5)
	var boss_row: Dictionary = m.bosses["courier"]
	_expect(boss_row["abilities"]["test_zone"]["hits"] == 1 and boss_row["abilities"]["test_zone"]["damage_dealt"] == 20.0 and not boss_row["abilities"]["test_other"].has("hits"), "Delayed ability lost attribution")
	game.hype.overdrive_started.emit()
	game.hype._hit(bot, 11.0, 0.0, Vector3.BACK, 0.0, 0.0, 0)
	var target = game._make_enemy("bot", "", Vector3(0, 0.05, 8), true)
	target.state = "chase"
	game.hype._hit(target, 11.0, 0.0, Vector3.BACK, 0.0, 0.0, 0)
	var team: Dictionary = m.attacks["pahan/team/team_overdrive"]
	_expect(team["actual_hp_lost"] == 11.0 and team["uses"] == 1 and team["hits"] == 1, "Team damage bypassed ledger")
	var tyaga: AttackData = Styles.by_id("tyaga812").attack("tg_shot")
	var tyaga_hit: HitInfo = p.tyaga._info(tyaga, target, Vector3.BACK, 1.0)
	var before_tyaga: float = target.hp
	target.take_hit_info(tyaga_hit)
	_expect(is_equal_approx(m.attacks["pahan/tyaga812/tg_shot"]["actual_hp_lost"], before_tyaga - target.hp), "TЯГА-812 hit missing")
	m.tick(2.0, "pahan", "vozduh")
	boss.take_hit(boss.max_hp * 0.51, Vector3.FORWARD, 0.0, true)
	p.state = "move"
	p.hp = 3.0
	p.inv = 0.0
	boss.record_ability("test_knockout")
	p.take_damage(20.0, boss.global_position, boss)
	_expect(p.hero == "madk1d" and m.heroes["pahan"]["knockout_causes"]["boss:courier/test_knockout"] == 1, "Knockout attribution lost across Tag")
	var skate: AttackData = Styles.by_id("skateboard").attack("sk_slide")
	var skate_target = game._make_enemy("bot", "", Vector3(0, 0.05, 9), true)
	skate_target.state = "chase"
	p.skate._hit(skate, skate_target, Vector3.BACK, 1.0)
	_expect(is_equal_approx(m.attacks["madk1d/skateboard/sk_slide"]["actual_hp_lost"], skate_target.max_hp - skate_target.hp), "Skate hit missing")
	m.tick(3.0, p.hero, "skateboard")
	var path: String = m.save(game, "test", {})
	var report = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	_expect(report is Dictionary and report["bosses"]["courier"]["phases"]["0"]["seconds"] >= 2.0
		and report["heroes"]["madk1d"]["style_seconds"]["skateboard"] == 3.0, "Report export or phase time failed")
	_expect(m.save(game, "again", {}) == "", "Duplicate report")
	if path != "":
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(m.directory)
	main.queue_free()
	await process_frame
	print("Survival telemetry: %d failures" % failures)
	quit(1 if failures else 0)
