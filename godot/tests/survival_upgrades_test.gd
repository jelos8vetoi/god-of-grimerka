extends SceneTree

const Mods := preload("res://scripts/survival_modifiers.gd")
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
	var run = game.survival
	var mods = game.run_mods
	mods.rng.seed = 175
	_expect(Mods.CARDS.size() >= 18 and not mods.eligible("air_guard", 150.0), "Catalog or prerequisite invalid")
	_expect(mods.apply("air_hype", 150.0) and mods.eligible("air_guard", 150.0), "Air synergy unavailable")
	for i in 3:
		_expect(mods.apply("block", 100.0), "Rank rejected early")
	_expect(not mods.apply("block", 100.0) and not mods.eligible("parry", 100.0), "Rank cap or incompatibility ignored")
	mods.clear()
	run.director.advance(30.0)
	await process_frame
	await process_frame
	_expect(paused and is_instance_valid(run.draft), "Draft did not pause combat")
	if not is_instance_valid(run.draft):
		quit(1)
		return
	var before: float = run.elapsed
	var draft = run.draft
	_expect(draft.choices.size() == 3 and Array(draft.choices).count(draft.choices[0]) == 1, "Invalid draft")
	var choice: String = draft.choices[0]
	await create_timer(0.15, true, false, true).timeout
	_expect(is_equal_approx(before, run.elapsed), "Draft clock advanced")
	draft._pick(choice)
	draft._pick(choice)
	await process_frame
	await process_frame
	_expect(not paused and mods.rank(choice) == 1 and run.next_draft > run.elapsed, "Choice duplicated or run remained paused")
	run.next_draft = INF
	_expect(game.tag.try_tag() and game.player.hero == "madk1d" and mods.rank(choice) == 1, "Upgrade did not survive Tag")
	mods.clear()
	_expect(mods.apply("swap_hit", 50.0), "Swap perk unavailable")
	game.player.flow.swapped.emit("guitar", "skateboard", true)
	var p = game.player
	p.rage = 0
	p.face = 0
	var enemy = game._make_enemy("bot", "", p.global_position + Vector3.FORWARD * -1.5, true)
	enemy.state = "chase"
	var attack := AttackData.make({"id": "upgrade_test", "damage": 10.0, "reach": 2.0, "stagger": 0.0, "knockback": 0.0})
	p.combat.cur = attack
	p.combat.hit_log = {}
	var hp: float = enemy.hp
	var base: float = p.combat.damage_for(attack, enemy)
	p.combat._resolve_hits(0, true)
	_expect(hp - enemy.hp > base and is_equal_approx(mods.consume_swap(game.clock, p.hero), 0.0), "Real melee hit did not consume and apply the perk")
	_expect(p.damage_bonus(attack, 100.0) <= Balance.MOMENT_CAP, "Damage cap bypassed")
	game._to_menu()
	await process_frame
	await process_frame
	_expect(mods.ranks.is_empty() and not paused, "Temporary upgrades survived exit")
	main.queue_free()
	await process_frame
	print("Survival upgrades: %d failures" % failures)
	quit(1 if failures else 0)
