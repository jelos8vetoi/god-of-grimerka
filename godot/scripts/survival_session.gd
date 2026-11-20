extends RefCounted
## Runtime state for one arena session, owned by the Game instance.

const ARENA := "snow"
const Records := preload("res://scripts/survival_records.gd")

var elapsed: float:
	get:
		return director.elapsed
var active := false
var finished := false
var director := preload("res://scripts/survival_director.gd").new()
var records_path := Records.PATH
var result: Dictionary = {}
var mods := preload("res://scripts/survival_modifiers.gd").new()
var telemetry := preload("res://scripts/survival_telemetry.gd").new()
var next_draft := 30.0
var draft_interval := 30.0
var draft: CanvasLayer
var mouse_before := Input.MOUSE_MODE_CAPTURED

func begin(game) -> void:
	game.run_mods = mods
	game.telemetry = telemetry
	game.player.combat.attack_started.connect(func(attack):
		telemetry.use(game.player.hero, game.player.style.id, attack.id))
	game.hype.overdrive_started.connect(func():
		telemetry.team_event(game.player.hero, "team_overdrive")
		telemetry.use(game.player.hero, "team", "team_overdrive"))
	game.player.flow.swapped.connect(func(_from, _to, perfect):
		if active and perfect:
			mods.perfect_swap(game))
	game.tag.tagged.connect(func(_hero, context):
		if active:
			mods.tagged(game, context))
	game.hype.overdrive_ended.connect(func(cancelled):
		if active:
			mods.overdrive_ended(game, cancelled))
	game._apply_upgrades()
	game._load_arena(ARENA)
	game.fx.prewarm(game.player.global_position)
	game.mode = "fight"
	if game.intro_on:
		game.intro_done.connect(_activate, CONNECT_ONE_SHOT)
		game.start_intro()
	else:
		_activate()

func _activate() -> void:
	if not finished:
		active = true

func tick(real_delta: float) -> void:
	if active:
		director.advance(real_delta)

func finish() -> void:
	active = false
	finished = true
	director.queue.clear()
	mods.clear()

func maybe_offer(game) -> void:
	if not active or elapsed < next_draft or draft != null or game.get_tree().paused:
		return
	if game.panel != null or game.ipod.captures_gameplay_input() or game.hype.on or game.tag.duo.active():
		return
	var options := mods.draft(elapsed)
	if options.is_empty():
		draft_interval = 18.0
		next_draft = elapsed + draft_interval
		return
	draft = preload("res://scripts/survival_draft.gd").new()
	draft.picked.connect(_choose.bind(game), CONNECT_DEFERRED)
	mouse_before = Input.mouse_mode
	game.get_tree().paused = true
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	game.add_child(draft)
	draft.build(options, mods)

func _choose(id: String, game) -> void:
	if not active or not is_instance_valid(draft) or not draft.choices.has(id):
		return
	if not mods.apply(id, elapsed):
		return
	draft_interval = maxf(18.0, 32.0 - elapsed / 35.0)
	next_draft = elapsed + draft_interval
	draft.queue_free()
	draft = null
	MouseMode.set_to(mouse_before)
	game.get_tree().paused = false

func save_report(game, outcome: String) -> void:
	if records_path != Records.PATH and telemetry.directory == telemetry.DIRECTORY:
		return # Isolated runs must not write into the real profile.
	telemetry.save(game, outcome, {"kills": game.kills, "bosses": director.bosses_defeated,
		"events": director.events_completed, "threat": director.threat, "upgrades": mods.ranks})

func defeat(kills: int) -> void:
	if finished:
		return
	var upgrades := mods.ranks.duplicate()
	finish()
	result = Records.record(elapsed, kills, director.threat, records_path, {
		"bosses": director.bosses_defeated, "events": director.events_completed, "upgrades": upgrades})

func time_text() -> String:
	return Records.format_time(elapsed)
