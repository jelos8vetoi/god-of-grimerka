extends Node

const Report := preload("res://scripts/balance_lab_report.gd")
const Ledger := preload("res://scripts/survival_telemetry.gd")
const SEEDS := [42113, 84229]
const HZ := 60
const COMBO := ["attack", "attack", "heavy"]
const STAND_HP := 10000.0
const SCENARIOS := [
	["single", ["bot"], 300, true],
	["shield", ["mod"], 300, true],
	["group3", ["bot", "clipper", "hater"], 300, true],
	["group5", ["bot", "clipper", "hater", "bot", "mod"], 300, true],
	["boss", ["boss:courier"], 360, false],
	["endurance", ["bot", "clipper", "hater"], 600, false],
	["tag", ["bot"], 270, true],
	["duo", ["bot"], 300, true],
	["overdrive", ["boss:courier"], 360, true],
]

var main
var failed := false
var profile := {"damage": 1.0, "hp": 1.0, "cooldown": 1.0}

func _ready() -> void:
	call_deferred("_run")

func _error(message: String) -> void:
	push_error("Balance Lab: " + message)
	failed = true

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--balance-profile="):
			var file := FileAccess.open(arg.trim_prefix("--balance-profile="), FileAccess.READ)
			var data = JSON.parse_string(file.get_as_text()) if file else null
			for key in profile:
				if not data is Dictionary or typeof(data.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not (float(data[key]) >= 0.5 and float(data[key]) <= 2.0):
					_error("invalid experiment profile: " + key)
					get_tree().quit(1)
					return
				profile[key] = float(data[key])
	var out := ProjectSettings.globalize_path(String(main.balance_lab))
	var baseline_path: String = main.balance_lab_baseline
	var current_path: String = main.balance_lab_current
	if current_path != "":
		var old := Report.read(baseline_path)
		var current := Report.read(current_path)
		if old.is_empty() or current.is_empty():
			_error("invalid comparison input; two controlled JSON reports are required")
		else:
			_compare(out, old, current, baseline_path, current_path)
		get_tree().quit(1 if failed else 0)
		return
	var baseline := Report.read(baseline_path) if baseline_path != "" else {}
	if baseline_path != "" and baseline.is_empty():
		_error("invalid baseline report")
		get_tree().quit(1)
		return
	Engine.physics_ticks_per_second = HZ
	var deadline := Time.get_ticks_msec() + 300000
	var samples: Array = []
	for scenario in SCENARIOS:
		if main.balance_lab_scenario != "" and main.balance_lab_scenario != scenario[0]:
			continue
		var styles: Array = ["vozduh"] if scenario[0] in ["tag", "duo", "overdrive"] else Styles.ORDER
		for style in styles:
			for rng_seed in SEEDS:
				if Time.get_ticks_msec() >= deadline:
					_error("300-second deadline exceeded")
					get_tree().quit(1)
					return
				var sample: Dictionary = await _trial(scenario, style, rng_seed, deadline)
				if sample.is_empty():
					get_tree().quit(1)
					return
				samples.append(sample)
		print("Balance Lab: %s finished (%d samples total)" % [scenario[0], samples.size()])
	if samples.is_empty():
		_error("unknown scenario: " + String(main.balance_lab_scenario))
		get_tree().quit(1)
		return
	var payload := {"kind": Report.KIND, "schema": Report.SCHEMA, "samples": samples, "valid": not failed,
		"note": "Controlled input and fixtures, not player Survival telemetry. No statistical significance inferred.",
		"engine": Engine.get_version_info()["string"], "experimental_profile": profile,
		"balance_sha256": FileAccess.get_sha256("res://scripts/balance.gd"),
		"summary": Report.summarize(samples)}
	var rows := Report.compare(baseline if not baseline.is_empty() else {"summary": {}}, payload)
	if not Report.export(out, "balance_lab", payload, rows):
		_error("could not export JSON and CSV")
	if not baseline.is_empty():
		_compare(out, baseline, payload, baseline_path, out.path_join("balance_lab.json"))
	print("Balance Lab: %d samples, %d scenario/style groups; %s" % [samples.size(), payload["summary"].size(), out])
	get_tree().quit(1 if failed else 0)

func _compare(out: String, old: Dictionary, current: Dictionary, from: String, to: String) -> void:
	var rows := Report.compare(old, current)
	if not Report.export(out, "balance_lab_comparison", {"kind": Report.KIND, "schema": Report.SCHEMA,
		"baseline_path": from, "current_path": to, "differences": rows}, rows):
		_error("could not export comparison")
	else:
		print("Balance Lab: %d comparison rows; %s" % [rows.size(), out])

func _trial(scenario: Array, style: String, rng_seed: int, deadline: int) -> Dictionary:
	Engine.time_scale = 1.0
	seed(rng_seed)
	main.start_game(false, -1, false, &"balance_lab")
	var game = main.game
	var p = game.player
	var own: String = Styles.by_id(style).owner
	if p.hero != own:
		game.swap_heroes(true)
		await _frames(60)
	if p.style.id != style:
		p.set_style(style)
		await _frames(84)
	if p.style.id != style:
		_error("could not equip " + style)
		return {}
	p.global_position = Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.face = PI
	game.cam_yaw = 0.0
	await _frames(20)
	if not p.is_on_floor():
		_error("hero did not settle on the arena floor: " + style)
		return {}
	game.tag.tag_cd = 0.0
	p.dmg_mul *= profile.damage
	game.buddy.global_position = Vector3(-1.0, 0.05, 0.7)
	var ledger := Ledger.new()
	ledger.directory = ""
	game.telemetry = ledger
	var launches: Array[String] = []
	var chained := [0]
	p.combat.attack_started.connect(func(attack):
		launches.append(attack.id)
		ledger.use(p.hero, p.style.id, attack.id))
	p.combat.attack_ended.connect(func(_attack, linked):
		if linked:
			chained[0] += 1)
	game.hype.overdrive_started.connect(func():
		ledger.team_event(p.hero, "team_overdrive")
		ledger.use(p.hero, "team", "team_overdrive"))
	var anchors: Array = []
	var targets: Array = []
	for i in scenario[1].size():
		var nm: String = scenario[1][i]
		var boss := nm.begins_with("boss:")
		var angle: float = [0.0, -0.30, 0.30, -0.62, 0.62][i]
		var marker := Vector3.FORWARD.rotated(Vector3.UP, angle) * (2.1 if i < 3 else 2.55) + Vector3.UP * 0.05
		var actor = game._make_enemy("" if boss else nm, nm.trim_prefix("boss:") if boss else "", marker)
		var natural_hp: float = actor.max_hp
		if scenario[3] and not boss:
			actor.max_hp = STAND_HP
			actor.hp = STAND_HP
		actor.state = "chase"
		actor.max_hp *= profile.hp
		actor.hp = actor.max_hp
		actor.cfg["cool"] *= profile.cooldown
		actor.cool = 999.0 if scenario[3] else 0.75 + i * 0.3
		actor.special_cd = 999.0 if scenario[3] else 5.0
		if boss:
			ledger.boss_ready(actor)
		targets.append({"type": nm, "natural_hp": natural_hp, "initial_hp": actor.hp,
			"position": [marker.x, marker.y, marker.z], "first_attack_delay_ticks": -1 if scenario[3] else 45 + i * 18})
		anchors.append([actor, marker])
	if scenario[0] == "overdrive":
		game.hype.value = TeamHype.MAX
	var setup := {"seed": rng_seed, "scenario": scenario[0], "style": style, "hero": own,
		"team_styles": {"pahan": p.heroes["pahan"]["style"], "madk1d": p.heroes["madk1d"]["style"]},
		"arena": "snow", "targets": targets, "stationary": scenario[3], "hz": HZ, "time_limit_ticks": scenario[2],
		"fixture_version": 4 if scenario[0] == "tag" else 3, "enemy_hp_scale": game.diff_hp, "player_hp": p.hp, "player_max_hp": p.max_hp,
		"player_damage_scale": p.dmg_mul, "campaign_upgrades": game.up.duplicate(), "survival_upgrades": [],
		"starting_resources": _resources(game)}
	game.dmg_log = []
	if profile.cooldown != 1.0:
		setup["cooldown_scale"] = profile.cooldown
	var peaks := _resources(game)
	var combo_end := -1
	var combo_start := -1
	var tyaga_end := -1
	var team_activated := false
	var ticks := 0
	var last_attack_count := 0
	for frame in int(scenario[2]):
		if Time.get_ticks_msec() >= deadline:
			_error("deadline during " + String(scenario[0]))
			return {}
		if game.over:
			break
		if scenario[3]:
			_pin_targets(anchors, scenario[0] == "shield")
		if launches.size() > last_attack_count and combo_start < 0:
			combo_start = maxi(0, frame - 1)
		last_attack_count = launches.size()
		if combo_start >= 0 and chained[0] >= 2 and launches.size() >= 3 and p.combat.cur == null and combo_end < 0:
			combo_end = frame
		p.auto_input = _scripted_input(scenario[0], style, frame, p, launches.size())
		await get_tree().physics_frame
		if style == "tyaga812" and frame > 67 and p.tyaga.mode == "hold" and tyaga_end < 0 and _tyaga_finished(ledger):
			tyaga_end = frame + 1
		ledger.tick(1.0 / HZ, p.hero, p.style.id)
		ticks += 1
		team_activated = team_activated or p.hero != own or game.tag.duo.active() or game.hype.active()
		var current := _resources(game)
		for resource in peaks:
			peaks[resource] = maxf(peaks[resource], current[resource])
	p.auto_input = {}
	var metrics := _measure(game, ledger, ticks, setup, peaks)
	if scenario[0] == "single" and style == "tyaga812" and combo_end < 0:
		var has_suck := ledger.attacks.has("pahan/tyaga812/tg_suck")
		var has_follow := ledger.attacks.has("pahan/tyaga812/tg_wide") or ledger.attacks.has("pahan/tyaga812/tg_knee")
		if has_suck and has_follow and tyaga_end >= 0:
			combo_start = 0
			combo_end = tyaga_end
	if scenario[0] == "single" and combo_end >= 0:
		metrics["combo_seconds"] = float(combo_end - combo_start) / HZ
		metrics["combo_damage"] = metrics["damage"]
	if scenario[0] in ["tag", "duo", "overdrive"] and not team_activated:
		_error("team input did not activate: " + String(scenario[0]))
	if scenario[0] == "tag" and not ledger.attacks.has("madk1d/team/tag_attack"):
		_error("Tag fixture did not produce its follow-up strike")
	if metrics["hits"] == 0:
		_error("no confirmed hits: %s/%s seed=%d" % [scenario[0], style, rng_seed])
	var result := {"scenario": scenario[0], "setup": setup, "metrics": metrics, "attack_order": launches,
		"combo_status": "completed" if combo_end >= 0 else ("controller_sequence" if style == "tyaga812" else "not_completed"),
		"attacks": ledger.attacks, "enemies": ledger.enemies, "heroes": ledger.heroes, "bosses": ledger.bosses}
	ledger.save(game, "controlled", {})
	game.process_mode = Node.PROCESS_MODE_DISABLED
	main.game = null
	game.queue_free()
	await get_tree().process_frame
	return result

func _pin_targets(anchors: Array, shield: bool) -> void:
	for entry in anchors:
		var enemy = entry[0]
		if not is_instance_valid(enemy) or not enemy.alive():
			continue
		enemy.global_position = entry[1]
		enemy.velocity = Vector3.ZERO
		enemy.kb = Vector3.ZERO
		enemy.cool = 999.0
		if shield:
			enemy.face = 0.0

func _tyaga_finished(ledger) -> bool:
	for id in ["tg_shot", "tg_throw", "tg_point", "tg_burst"]:
		if ledger.attacks.has("pahan/tyaga812/" + id):
			return true
	return false

func _scripted_input(scenario: String, style: String, frame: int, p, started: int) -> Dictionary:
	if scenario == "tag" and p.hero == "pahan":
		if frame == 0:
			return {"attack": "press"}
		if p.state == "attack" and p.combat.hit_i > 0:
			return {"tag": "press"}
		return {}
	if scenario in ["duo", "overdrive"]:
		if frame == 0:
			return {"assist": "press"} if scenario == "duo" else {"overdrive": "press"}
		return {}
	if style == "tyaga812":
		if scenario == "single" and frame >= 105:
			return {}
		var phase := frame % 105
		if phase < 26:
			return {"attack": "hold" if phase else "press"}
		return {"throw": "press"} if phase == 28 else ({"heavy": "press"} if phase == 67 else {})
	if scenario in ["endurance", "boss"]:
		if frame % 120 >= 100:
			return {"block": "hold"}
		if frame % 6 == 0:
			return {COMBO[floori(frame / 6.0) % COMBO.size()]: "press"}
		return {}
	if started >= COMBO.size():
		return {}
	if frame % 2 == 0 and (p.state == "move" or p.combat.in_combo_window()):
		return {COMBO[started]: "press"}
	return {}

func _resources(game) -> Dictionary:
	var p = game.player
	return {"bottles": p.combat.ammo_of("bottles"), "heat": p.tyaga.heat, "rhythm": p.guitar.bars,
		"flow": p.breaker.flow, "skate_charges": p.skate.charges, "hype": game.hype.value, "swag": p.swag}

func _measure(game, ledger, ticks: int, setup: Dictionary, peaks: Dictionary) -> Dictionary:
	var damage := 0.0
	var hits := 0
	var control := 0.0
	for row in ledger.attacks.values():
		damage += float(row.get("actual_hp_lost", 0.0))
		hits += int(row["hits"])
		control += float(row.get("stagger_requested", 0.0))
	var unique := {}
	for hit in game.dmg_log:
		unique[hit[1]] = true
	var damage_taken := 0.0
	var knocked_out := 0
	for hero in ledger.heroes.values():
		damage_taken += float(hero.get("damage_taken", 0.0))
		knocked_out += int(hero.get("knockouts", 0))
	var remaining := maxf(0.0, game.player.hp)
	var mate: String = game.tag.mate()
	if not game.tag.down[mate]:
		remaining += float(game.tag.hp[mate])
	var seconds := float(ticks) / HZ
	return {"damage": damage, "dps": damage / maxf(1.0 / HZ, seconds), "hits": hits,
		"targets_hit": unique.size(), "stagger_requested": control, "damage_taken": damage_taken,
		"team_hp_remaining": remaining, "knockouts": knocked_out, "sample_seconds": seconds,
		"bottles_spent": ledger.resources.get("bottles_spent", 0.0),
		"peak_heat": peaks["heat"], "peak_rhythm": peaks["rhythm"], "peak_flow": peaks["flow"],
		"peak_skate_charges": peaks["skate_charges"],
		"hype_net_spent": maxf(0.0, setup["starting_resources"]["hype"] - game.hype.value),
		"ending_resources": _resources(game)}
