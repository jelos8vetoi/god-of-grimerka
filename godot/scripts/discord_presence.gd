extends Node
## Local Discord activity. Reads only display-ready gameplay state from the active scene.

const APP_ID_SETTING := "discord_presence/application_id"
const DOWNLOAD_URL := "https://github.com/jelos8vetoi/god-of-grimerka/releases"
const GAME_NAME := "GOD OF GRIMERKA"
const MIN_UPDATE_MS := 5000
const RETRY_MS := 15000
const REPLAY_MS := 30000
const POLL_SECONDS := 0.25
const PLAYING := 0

var _client: Object
var _timer: Timer
var _application_id := 0
var _started_at_ms := 0
var _next_update_ms := 0
var _replay_at_ms := 0
var _enabled := false
var _request := 0
var _waiting := false
var _last_activity: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at_ms = int(Time.get_unix_time_from_system() * 1000.0)
	var configured := str(ProjectSettings.get_setting(APP_ID_SETTING, "")).strip_edges()
	if configured.is_valid_int() and configured.to_int() > 0:
		_application_id = configured.to_int()
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.ignore_time_scale = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	set_enabled(bool(Opts.v("discord_presence")))


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_clear()
		return
	if _application_id == 0 or DisplayServer.get_name() == "headless":
		return
	if not ClassDB.class_exists("DiscordClient"):
		return
	if _enabled:
		return
	if _client == null:
		_client = ClassDB.instantiate("DiscordClient")
		_client.set_application_id(_application_id)
	_enabled = true
	_timer.start()
	_refresh()


func _clear() -> void:
	if not _enabled:
		return
	_enabled = false
	_timer.stop()
	_request += 1
	_waiting = false
	_last_activity.clear()
	if _client != null:
		_client.clear_rich_presence()


func _exit_tree() -> void:
	_clear()


func _refresh() -> void:
	ClassDB.class_call_static("Discord", "run_callbacks")
	if not _enabled:
		return
	var now := Time.get_ticks_msec()
	if now < _next_update_ms:
		return
	# A missing callback must not prevent later attempts to publish.
	if _waiting:
		_waiting = false
		_request += 1
		_next_update_ms = now + RETRY_MS
		return
	var wanted := describe(get_tree().current_scene)
	# The SDK reconnects its pipe but can lose the last activity on Discord restart.
	if wanted == _last_activity and now < _replay_at_ms:
		return
	_request += 1
	_waiting = true
	_next_update_ms = now + MIN_UPDATE_MS
	var activity: Object = ClassDB.instantiate("DiscordActivity")
	activity.set_type(PLAYING)
	activity.set_details(wanted["details"])
	if not String(wanted["state"]).is_empty():
		activity.set_state(wanted["state"])
	var art: Object = ClassDB.instantiate("DiscordActivityAssets")
	art.set_large_image(wanted["image"])
	art.set_large_text(wanted["title"])
	art.set_small_image("logo")
	art.set_small_text(GAME_NAME)
	activity.set_assets(art)
	var timestamps: Object = ClassDB.instantiate("DiscordActivityTimestamps")
	timestamps.set_start(_started_at_ms)
	activity.set_timestamps(timestamps)
	var button: Object = ClassDB.instantiate("DiscordActivityButton")
	button.set_label("Скачать игру")
	button.set_url(DOWNLOAD_URL)
	activity.add_button(button)
	_client.update_rich_presence(activity, _updated.bind(_request, wanted))


func _updated(result: Object, request: int, activity: Dictionary) -> void:
	if request != _request:
		return
	_waiting = false
	if result.successful():
		_last_activity = activity
		_replay_at_ms = Time.get_ticks_msec() + REPLAY_MS
	else:
		# Fire-and-forget desktop RPC can fail while Discord is starting or closed.
		_last_activity.clear()
		_next_update_ms = Time.get_ticks_msec() + RETRY_MS


func _activity(image: String, title: String, details: String, state := "") -> Dictionary:
	return {"image": image, "title": title, "details": details, "state": state}


func describe(scene: Node) -> Dictionary:
	if scene is FiveNightsRoot:
		return _five_nights(scene)
	if scene is MicroloansRoot:
		return _microloans(scene)
	if scene != null and scene.scene_file_path == "res://scenes/main.tscn":
		if scene.minigame is FiveNightsRoot:
			return _five_nights(scene.minigame)
		if scene.minigame is MicroloansRoot:
			return _microloans(scene.minigame)
		if scene.race is Race:
			return _race(scene.race)
		if is_instance_valid(scene.game):
			return _game(scene.game)
		var menu := scene.menu as Menu
		if menu != null and menu.modes != null and menu.modes.visible:
			return _activity("logo", GAME_NAME, "Выбирает режим игры")
	return _activity("logo", GAME_NAME, "Главное меню")


func _game(game: Node) -> Dictionary:
	if is_instance_valid(game.golda):
		return _golda(game.golda)
	if game.is_survival():
		return _survival(game)
	if is_instance_valid(game.training):
		return _activity("logo", "TRAINING ARENA", "Тренировочная арена")
	if game.run_type != &"campaign" or (game.story as Dictionary).is_empty():
		return _activity("logo", GAME_NAME, "В игре")
	var chapters: Array = game.story["CH"]
	if game.ch >= chapters.size():
		return _activity("story", "Сюжет", "Сюжетный режим", "Глава завершена")
	var place := "Подъезд · Томск" if game.in_hall else str(game.chapter()["place"])
	if game.mode == "boss":
		place += " · Бой с боссом"
	return _activity("story", "Сюжет", "Глава %d" % (game.ch + 1), place)


func _golda(golda: Golda67) -> Dictionary:
	var place := "Подъезд"
	if golda.place == "run":
		place = str(golda.district()["name"])
		var zone_id := str(golda.room.get("place", ""))
		if G67District.has_zone(zone_id):
			place += " · " + str(G67District.zone_of(zone_id)["name"])
	return _activity("golda67", "ГОЛДА 67", "ГОЛДА 67", place)


func _five_nights(five: FiveNightsRoot) -> Dictionary:
	const TITLE := "5 НОЧЕЙ С ПАХАНОМ"
	if five.state == "menu" or five.st == null:
		return _activity("five_nights", TITLE, TITLE, "Меню охраны")
	var night := "Своя ночь" if five.st.night >= FNData.NIGHTS.size() else "Ночь %d" % (five.st.night + 1)
	var state := five.st.clock()
	match five.state:
		"six": state = "6 AM · Ночь завершена"
		"dead": state += " · Смена прервана"
		_:
			if five.paused:
				state += " · Пауза"
	return _activity("five_nights", TITLE, night, state)


func _survival(game: Node) -> Dictionary:
	const TITLE := "ENDLESS SURVIVAL"
	var session: RefCounted = game.survival
	if session == null:
		return _activity("survival", TITLE, TITLE)
	var seconds := floori(session.elapsed)
	if not session.finished:
		# Update the run clock at the same cadence as the RPC budget.
		seconds -= seconds % 5
	@warning_ignore("integer_division")
	var time := "%d:%02d" % [seconds / 60, seconds % 60]
	var state := "%s · Побеждено: %d" % [time, game.kills]
	if session.finished:
		state += " · Забег завершён"
	return _activity("survival", TITLE, TITLE, state)


func _race(race: Race) -> Dictionary:
	const TITLE := "VACUUM RACING"
	var track := str(RaceData.track(str(race.cfg.get("track", "")))["name"])
	if race.paused:
		track += " · Пауза"
	elif race.state in ["done", "results"]:
		track += " · Финиш"
	return _activity("logo", TITLE, TITLE, track)


func _microloans(microloans: MicroloansRoot) -> Dictionary:
	const TITLE := "ПАХАН НАБРАЛ МИКРОЗАЙМОВ"
	var phase := {"morning": "Утро", "day": "День", "evening": "Вечер", "night": "Ночь"}
	var state := "Неделя завершена" if microloans.econ.ending != "" else str(phase.get(microloans.econ.phase, ""))
	return _activity("logo", TITLE, TITLE, "День %d · %s" % [microloans.econ.day, state])
