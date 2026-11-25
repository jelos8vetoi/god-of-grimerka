extends Node
## Local Discord activity. Reads only display-ready gameplay state from the active scene.

const APP_ID_SETTING := "discord_presence/application_id"
const DOWNLOAD_URL := "https://github.com/jelos8vetoi/god-of-grimerka/releases"
const GAME_NAME := "GOD OF GRIMERKA"
const MIN_UPDATE_MS := 5000
const RETRY_MS := 15000
const REPLAY_MS := 30000
const CALLBACK_TIMEOUT_MS := 10000
const POLL_SECONDS := 0.25
const PLAYING := 0
const SDK_DIR := "res://addons/discord_social_sdk/"
const EXTENSION := SDK_DIR + "discord.gdextension"
const SDK_DLLS := ["discord_partner_sdk.dll", "discord_social_sdk.windows.template_release.x86_64.dll"]
const SDK_CLASSES := [&"Discord", &"DiscordClient", &"DiscordClientResult", &"DiscordActivity",
	&"DiscordActivityAssets", &"DiscordActivityTimestamps", &"DiscordActivityButton"]

var _client: Object
var _timer: Timer
var _application_id := 0
var _started_at_ms := 0
var _next_update_ms := 0
var _replay_at_ms := 0
var _enabled := false
var _sdk_ready := false
var _request := 0
var _sent_at_ms := -1
var _last_activity: Dictionary = {}


func _log(message: String) -> void:
	print("[DiscordRPC] ", message.replace("\r", "\\r").replace("\n", "\\n"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at_ms = int(Time.get_unix_time_from_system() * 1000.0)
	var raw_id: Variant = ProjectSettings.get_setting(APP_ID_SETTING, "")
	var configured := str(raw_id).strip_edges()
	if configured.is_valid_int() and configured.to_int() > 0:
		_application_id = configured.to_int()
	_log("Application ID: key=%s, exists=%s, type=%s, parsed=%d" % [
		APP_ID_SETTING, ProjectSettings.has_setting(APP_ID_SETTING), type_string(typeof(raw_id)), _application_id])
	_log("Runtime: Godot %s, exe=%s, pid=%d, display=%s, debugger=%s" % [
		Engine.get_version_info()["string"], OS.get_executable_path().get_file(), OS.get_process_id(),
		DisplayServer.get_name(), EngineDebugger.is_active()])
	_sdk_ready = _inspect_sdk()
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.ignore_time_scale = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	set_enabled(bool(Opts.v("discord_presence")))


func _inspect_sdk() -> bool:
	var loaded := GDExtensionManager.is_extension_loaded(EXTENSION)
	_log("GDExtension: descriptor=%s, loaded=%s" % [FileAccess.file_exists(EXTENSION), loaded])
	if OS.get_name() == "Windows":
		var executable_dir := OS.get_executable_path().get_base_dir()
		for dll in SDK_DLLS:
			var source_file := FileAccess.file_exists(SDK_DIR + "bin/" + dll)
			var adjacent_file := FileAccess.file_exists(executable_dir.path_join(dll))
			_log("DLL %s: project=%s, beside executable=%s" % [dll, source_file, adjacent_file])
	var missing := PackedStringArray()
	for sdk_class in SDK_CLASSES:
		if not ClassDB.class_exists(sdk_class):
			missing.append(sdk_class)
	var callbacks_found := missing.is_empty() and ClassDB.class_has_method("Discord", "run_callbacks")
	_log("SDK classes: %d/%d registered, missing=%s, run_callbacks()=%s" % [
		SDK_CLASSES.size() - missing.size(), SDK_CLASSES.size(), ", ".join(missing) if not missing.is_empty() else "none",
		callbacks_found])
	return loaded and callbacks_found


func set_enabled(enabled: bool) -> void:
	_log('Opts.v("discord_presence")=%s, requested=%s' % [Opts.v("discord_presence"), enabled])
	if not enabled:
		_log("Local presence is disabled in game settings.")
		_clear()
		return
	if _application_id == 0:
		_log("No valid Application ID. Set [discord_presence] application_id in project.godot.")
		return
	if DisplayServer.get_name() == "headless":
		_log("Local presence is inactive in headless mode.")
		return
	if not _sdk_ready:
		_sdk_ready = _inspect_sdk()
	if not _sdk_ready:
		_log("Local presence could not start because the Discord SDK is unavailable.")
		return
	if _enabled:
		return
	if _client == null:
		_client = ClassDB.instantiate("DiscordClient")
		_log("DiscordClient instance created=%s" % is_instance_valid(_client))
		if _client == null:
			return
		_client.set_application_id(_application_id)
		_log("DiscordClient Application ID=%d. Local RPC, callback pump every %.2f seconds." % [
			_client.get_application_id(), POLL_SECONDS])
	_enabled = true
	_timer.start()
	_refresh()


func _clear() -> void:
	if not _enabled:
		return
	_enabled = false
	_timer.stop()
	_request += 1
	_sent_at_ms = -1
	_last_activity.clear()
	if _client != null:
		_client.clear_rich_presence()
		_log("clear_rich_presence() requested.")


func _exit_tree() -> void:
	_clear()


func _refresh() -> void:
	ClassDB.class_call_static("Discord", "run_callbacks")
	if not _enabled:
		return
	var now := Time.get_ticks_msec()
	if _sent_at_ms >= 0:
		if now - _sent_at_ms >= CALLBACK_TIMEOUT_MS:
			_log("update_rich_presence #%d: callback timed out after %d ms." % [_request, now - _sent_at_ms])
			_sent_at_ms = -1
			_request += 1
			_next_update_ms = now + RETRY_MS
		return
	if now < _next_update_ms:
		return
	var wanted := describe(get_tree().current_scene)
	# The SDK reconnects its pipe but can lose the last activity on Discord restart.
	if wanted == _last_activity and now < _replay_at_ms:
		return
	_request += 1
	_sent_at_ms = now
	_next_update_ms = now + MIN_UPDATE_MS
	var activity := _make_activity(wanted)
	_log("update_rich_presence #%d: details=%s, state=%s, art=%s" % [
		_request, wanted["details"], wanted["state"], wanted["image"]])
	_client.update_rich_presence(activity, _updated.bind(_request, wanted))


func _make_activity(wanted: Dictionary) -> Object:
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
	return activity


func _updated(result: Object, request: int, activity: Dictionary) -> void:
	var success: bool = result.successful()
	var latency := Time.get_ticks_msec() - _sent_at_ms if request == _request else -1
	_log("update_rich_presence #%d callback: success=%s, code=%d, type=%d, status=%d, error=%s, latency_ms=%d" % [
		request, success, result.error_code(), result.type(), result.status(),
		result.error() if not success else "none", latency])
	if request != _request:
		return
	_sent_at_ms = -1
	if success:
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
