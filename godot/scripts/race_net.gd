## Сетевая гонка: лобби и синхронизация (High-Level Multiplayer, ENetMultiplayerPeer, хост — слушающий сервер).
## Узел живёт по пути /root/Main/RaceNet на всех компьютерах (RPC ищут его по пути), создаётся экраном ONLINE RACE
## и удаляется при выходе — после этого multiplayer снова офлайн, и кампания ничего не знает о сети.
##
## Хост (id 1) — источник истины: движение всех гонщиков, столкновения, контрольные точки, круги, предметы
## (и их случайность), попадания, время и победитель. Клиенты шлют только намерения (RaceInput, 4 байта),
## хост шлёт снимки (20 в секунду, ненадёжно-упорядоченно) и события (надёжно). Протокол — docs/NETWORK_PROTOCOL.md.
## Всё, что приходит по сети, проверяется: отправитель, состояние, типы, пределы, частота. Пути и ресурсы по сети
## не принимаются — трасса только из RaceData.TRACKS по id.
class_name RaceNet
extends Node

signal lobby_changed
signal joined
signal failed(reason: String)        # не удалось создать или войти — с понятной причиной
signal closed(reason: String)        # лобби закрыто (хост вышел, нас отключили) — игра уже офлайн
signal loading(cfg: Dictionary)      # хост начал гонку: строим трассу

const PROTO := 1
const PORT := 24710                  # UDP-порт игры по умолчанию
const DISCOVERY_PORT := 24711        # UDP: объявления лобби в локальной сети
const MAX_PLAYERS := 8
const SNAP_HZ := 20.0
const INPUT_HZ := 30.0
const TIMEOUT_MIN_MS := 20000         # связь молчит дольше — обрыв (пока строится трасса, кадр бывает долгим)
const TIMEOUT_MAX_MS := 40000
const CH_EVENTS := 0                 # надёжный: лобби, старт, события, результаты
const CH_SNAP := 1                   # ненадёжный упорядоченный: снимки хоста
const CH_INPUT := 2                  # ненадёжный упорядоченный: ввод клиентов
const STATES := ["wait", "intro", "countdown", "race", "done", "results"]
const LIMITS := {"c_input": 90, "c_hello": 3, "c_ready": 8, "c_pick": 8, "c_loaded": 3}   # в секунду с одного клиента

var main
var is_host := false
var lobby := {}                      # {room, host_name, max, track, laps, private, has_pass, state, players: [...]}
var my_id := 1
var pass_hash := ""
var my_name := "ИГРОК"
var my_rider := "pahan"
var build := "dev"
var race                             # идущая гонка (race.gd) или null
var loaded := {}                     # id → загрузил трассу
var rate := {}                       # id → {имя: [секунда, сколько]}
var rejected := 0                    # сколько сообщений отброшено проверками (для проверки и отладки)
var bytes_out := 0
var bytes_t0 := 0
var snap_t := 0.0
var input_t := 0.0
var sticky := RaceInput.new()        # нажатия между отправками ввода
var seq := 0                         # клиент: номер последнего отправленного ввода (хост вернёт его в снимке)
var tick := 0
var connect_t := -1.0                # клиент: сколько ждём соединения
var timeout := 8.0
var hello_sent := false
# имитация плохой сети (только для проверки: --net-sim=задержка_мс,потери_%)
var sim_delay := 0.0
var sim_loss := 0.0
var sim_queue: Array = []            # [время, Callable]
# поиск лобби в локальной сети
var disc_tx: PacketPeerUDP
var disc_rx: PacketPeerUDP
var disc_t := 0.0
var found := {}                      # "ip:port" → {room, host_name, players, max, has_pass, ip, port, seen}
var fake_build := ""                 # проверка несовпадения версий

func _ready() -> void:
	name = "RaceNet"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://data/build.json"):
		var b = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
		if b is Dictionary:
			build = String(b.get("sha", "dev"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-sim="):
			var v := a.substr(10).split(",")
			sim_delay = float(v[0]) / 1000.0
			sim_loss = float(v[1]) / 100.0 if v.size() > 1 else 0.0
		elif a.begins_with("--net-fake-build="):
			fake_build = a.substr(17)
	loading.connect(func(cfg: Dictionary): main.start_online_race(cfg))
	closed.connect(func(reason: String):
		if main.race != null and is_instance_valid(main.race):
			main.end_race_online(reason))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		var c := ch.unicode_at(0)
		if c >= 32 and c != 127 and out.length() < 16:
			out += ch
	return out if out.strip_edges() != "" else "ИГРОК"

static func hash_pass(p: String) -> String:
	return "" if p == "" else ("grimerka:" + p).sha256_text()

# ---------------- хост ----------------
## Создать лобби. Возвращает "" или понятную причину.
func host_lobby(cfg: Dictionary) -> String:
	leave_peer()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var port := int(cfg.get("port", PORT))
	var mx := clampi(int(cfg.get("max", MAX_PLAYERS)), 2, MAX_PLAYERS)
	var err := peer.create_server(port, mx - 1, 3)
	if err != OK:
		return "Не удалось открыть UDP-порт %d (%s). Возможно, он занят другой программой или второй копией игры." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	is_host = true
	my_id = 1
	my_name = clean_name(String(cfg.get("name", "ПАХАН")))
	my_rider = String(cfg.get("rider", "pahan")) if RaceVisual.RIDERS.has(String(cfg.get("rider", ""))) else "pahan"
	pass_hash = hash_pass(String(cfg.get("password", "")))
	var tid := String(cfg.get("track", "tomsk_dust"))
	lobby = {"room": clean_name(String(cfg.get("room", "ПЫЛЬНЫЙ ЗАЕЗД"))), "host_name": my_name, "max": mx,
		"track": tid if RaceData.TRACKS.has(tid) else "tomsk_dust", "laps": clampi(int(cfg.get("laps", 3)), 1, 5),
		"private": bool(cfg.get("private", false)), "has_pass": pass_hash != "", "state": "lobby", "port": port,
		"players": [{"id": 1, "name": my_name, "rider": my_rider, "ready": true, "ping": 0, "host": true}]}
	_start_beacon()
	lobby_changed.emit()
	return ""

func _player(id: int) -> Dictionary:
	for p in lobby.get("players", []):
		if int(p["id"]) == id:
			return p
	return {}

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	_long_timeout(id)
	rate[id] = {}
	# ждём hello; не представился за 5 с — отключаем
	get_tree().create_timer(5.0, true, false, true).timeout.connect(func():
		if is_host and multiplayer.multiplayer_peer != null and _player(id).is_empty() and multiplayer.get_peers().has(id):
			_kick(id, "Нет приветствия от игры"))

func _on_peer_disconnected(id: int) -> void:
	_dbg("peer_disconnected %d" % id)
	if not is_host:
		return
	var p := _player(id)
	if not p.is_empty():
		(lobby["players"] as Array).erase(p)
		loaded.erase(id)
		if race != null and is_instance_valid(race):
			race.peer_left(id)
		_send_lobby()
	rate.erase(id)

func _kick(id: int, reason: String) -> void:
	_dbg("kick %d: %s" % [id, reason])
	_to(id, "h_reject", [reason])
	get_tree().create_timer(0.3, true, false, true).timeout.connect(func():
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.get_peers().has(id):
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))

## частота сообщений одного клиента: больше лимита — отброшено
func _rate_ok(id: int, what: String) -> bool:
	var r: Dictionary = rate.get(id, {})
	var sec := int(Time.get_ticks_msec() / 1000)
	var cur: Array = r.get(what, [sec, 0])
	if int(cur[0]) != sec:
		cur = [sec, 0]
	cur[1] = int(cur[1]) + 1
	r[what] = cur
	rate[id] = r
	if int(cur[1]) > int(LIMITS.get(what, 20)):
		rejected += 1
		return false
	return true

func _from_client() -> int:
	var id := multiplayer.get_remote_sender_id()
	if not is_host or id <= 1:
		rejected += 1
		return 0
	return id

@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func c_hello(proto, ver, nm, ph) -> void:
	var id := _from_client()
	if id == 0 or not _rate_ok(id, "c_hello"):
		return
	if typeof(proto) != TYPE_INT or typeof(ver) != TYPE_STRING or typeof(nm) != TYPE_STRING or typeof(ph) != TYPE_STRING:
		rejected += 1
		_kick(id, "Неверное приветствие")
		return
	if int(proto) != PROTO or String(ver) != build:
		_kick(id, "Разные версии игры: у хоста %s, у тебя %s. Обновитесь до одной сборки." % [build, String(ver)])
		return
	if lobby.get("state", "") != "lobby":
		_kick(id, "Гонка уже идёт — подожди её конца")
		return
	if (lobby["players"] as Array).size() >= int(lobby["max"]):
		_kick(id, "Лобби заполнено")
		return
	if pass_hash != "" and String(ph) != pass_hash:
		_kick(id, "Неверный пароль")
		return
	if not _player(id).is_empty():
		return
	var free_riders := RaceVisual.RIDERS.keys().filter(func(k): return not (lobby["players"] as Array).any(func(p): return p["rider"] == k))
	(lobby["players"] as Array).append({"id": id, "name": clean_name(String(nm)), "rider": String(free_riders[0]) if not free_riders.is_empty() else "madk1d", "ready": false, "ping": 0, "host": false})
	_to(id, "h_welcome", [id])
	_send_lobby()

@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func c_ready(on) -> void:
	var id := _from_client()
	if id == 0 or not _rate_ok(id, "c_ready") or typeof(on) != TYPE_BOOL or lobby.get("state", "") != "lobby":
		rejected += 1 if id != 0 and typeof(on) != TYPE_BOOL else 0
		return
	var p := _player(id)
	if not p.is_empty():
		p["ready"] = bool(on)
		_send_lobby()

@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func c_pick(rider) -> void:
	var id := _from_client()
	if id == 0 or not _rate_ok(id, "c_pick") or typeof(rider) != TYPE_STRING or not RaceVisual.RIDERS.has(String(rider)) or lobby.get("state", "") != "lobby":
		if id != 0:
			rejected += 1
		return
	var p := _player(id)
	if not p.is_empty():
		p["rider"] = String(rider)
		_send_lobby()

@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func c_loaded() -> void:
	var id := _from_client()
	if id == 0 or not _rate_ok(id, "c_loaded") or lobby.get("state", "") != "loading" or _player(id).is_empty():
		return
	loaded[id] = true
	_dbg("c_loaded от %d (%d из %d)" % [id, loaded.values().count(true), (lobby["players"] as Array).size()])
	_check_loaded()

@rpc("any_peer", "call_remote", "unreliable_ordered", CH_INPUT)
func c_input(b) -> void:
	var id := _from_client()
	if id == 0 or not _rate_ok(id, "c_input"):
		return
	if typeof(b) != TYPE_PACKED_BYTE_ARRAY or (b as PackedByteArray).size() != 6:
		rejected += 1
		return
	if race == null or not is_instance_valid(race) or not (race.state in ["countdown", "race", "done"]):
		return
	var r = race.rider_of_peer(id)
	if r == null or r.finished:
		return
	var inp := RaceInput.unpack((b as PackedByteArray).slice(0, 4))
	r.net_seq = (b as PackedByteArray).decode_u16(4)
	# одноразовые нажатия не теряются между шагами хоста
	inp.jump = inp.jump or r.net_input.jump
	inp.item = inp.item or r.net_input.item
	r.net_input = inp

## все ли готовы: хост может начинать при ≥ 2 игроках и READY у всех
func can_start() -> bool:
	var ps: Array = lobby.get("players", [])
	return is_host and ps.size() >= 2 and ps.all(func(p): return bool(p["ready"])) and lobby.get("state", "") == "lobby"

## хост: начать гонку — всем строить трассу
func start_race() -> bool:
	if not can_start():
		return false
	lobby["state"] = "loading"
	loaded = {1: false}
	var riders: Array = []
	for p in lobby["players"]:
		riders.append({"id": String(p["rider"]), "name": String(p["name"]), "peer": int(p["id"])})
	var cfg := {"mode": "online", "track": String(lobby["track"]), "laps": int(lobby["laps"]), "seed": randi(), "riders": riders}
	_send_lobby()
	_all("h_load", [cfg])
	loading.emit(_cfg_for(cfg, 1))
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func():
		if is_host and lobby.get("state", "") == "loading":
			# кто не загрузился за 60 с — отключается, остальные едут
			for p in (lobby["players"] as Array).duplicate():
				if not bool(loaded.get(int(p["id"]), false)) and int(p["id"]) != 1:
					_kick(int(p["id"]), "Трасса не загрузилась вовремя")
			loaded[1] = true
			_go())
	return true

## конфигурация гонки для этого компьютера: свой гонщик — local, остальные — remote
func _cfg_for(cfg: Dictionary, me: int) -> Dictionary:
	var c := cfg.duplicate(true)
	c["host"] = me == 1
	for r in c["riders"]:
		r["kind"] = "local" if int(r["peer"]) == me else "remote"
	return c

## race.gd: трасса построена
func race_ready(r) -> void:
	race = r
	if is_host:
		loaded[1] = true
		_check_loaded()
	else:
		rpc_id(1, "c_loaded")

func _check_loaded() -> void:
	if lobby.get("state", "") != "loading":
		return
	for p in lobby["players"]:
		if not bool(loaded.get(int(p["id"]), false)):
			return
	_go()

## ENet по умолчанию рвёт связь, если 5 с нет ответа. Пока трасса строится, кадр может идти несколько секунд
## (слабый компьютер, восемь игроков сразу) — даём 20–40 с, настоящий обрыв всё равно заметен.
func _long_timeout(id: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(id)
		if pp != null:
			pp.set_timeout(64, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)

static func _dbg(t: String) -> void:
	if OS.get_cmdline_user_args().has("--net-debug"):
		print("NETDBG " + t)

func _go() -> void:
	_dbg("go")
	if lobby.get("state", "") != "loading":
		return
	lobby["state"] = "race"
	_send_lobby()
	if race != null and is_instance_valid(race):
		race.net_go()

## хост, каждый шаг физики гонки: снимки 20 раз в секунду
func host_tick(dt: float) -> void:
	snap_t -= dt
	tick += 1
	if snap_t > 0.0 or race == null:
		return
	snap_t = 1.0 / SNAP_HZ
	var b := snapshot(race)
	_all_unreliable("h_snap", b)

func snapshot(rc) -> PackedByteArray:
	var b := PackedByteArray()
	var n: int = rc.riders.size()
	b.resize(14 + n * 29)
	b.encode_u32(0, tick)
	b.encode_float(4, rc.t)
	b.encode_u8(8, maxi(0, STATES.find(rc.state)))
	b.encode_float(9, rc.st)
	b.encode_u8(13, n)
	var o := 14
	for r in rc.riders:
		var p: Vector3 = r.global_position
		b.encode_float(o, p.x)
		b.encode_float(o + 4, p.y)
		b.encode_float(o + 8, p.z)
		b.encode_half(o + 12, wrapf(r.heading, -PI, PI))
		b.encode_half(o + 14, r.speed)
		var f := (1 if r.drifting else 0) | (2 if r.boosting() else 0) | (4 if r.air_t > 0.08 else 0) | (8 if r.spin_t > 0.0 else 0) | (16 if r.shield_t > 0.0 else 0) | (32 if r.turbo_on else 0) | (64 if r.finished else 0) | (128 if r.disconnected else 0)
		b.encode_u8(o + 16, f)
		b.encode_u8(o + 17, (r.drift_lvl & 3) | (4 if r.drift_dir > 0.0 else 0))
		b.encode_u8(o + 18, clampi(int(r.turbo * 2.55), 0, 255))
		b.encode_u8(o + 19, RaceData.ITEM_IDS.find(r.item) + 1)
		b.encode_u8(o + 20, clampi(r.lap, 0, 255))
		b.encode_u8(o + 21, clampi(r.next_gate, 0, 255))
		b.encode_u8(o + 22, clampi(r.rank, 0, 255))
		b.encode_half(o + 23, atan2(r.vdir.x, r.vdir.z))
		b.encode_half(o + 25, r.air_t)
		b.encode_u16(o + 27, r.net_seq & 0xFFFF)
		o += 29
	return b

## событие участника (эффекты, HUD) — всем клиентам надёжно
func send_event(slot: int, k: String, v) -> void:
	if not is_host:
		return
	if typeof(v) == TYPE_OBJECT:
		v = 0
	_all("h_ev", [slot, k, v])

func send_hazard(hid: int, kind: String, pos: Vector3, rad: float) -> void:
	_all("h_hazard", [hid, kind, pos, rad])

func send_hazard_end(hid: int) -> void:
	_all("h_hazard_end", [hid])

func send_box(i: int, on: bool) -> void:
	_all("h_box", [i, on])

func send_results(rows: Array) -> void:
	_all("h_results", [rows])

## хост: все снова в лобби (после результатов)
func back_to_lobby() -> void:
	if not is_host:
		return
	lobby["state"] = "lobby"
	for p in lobby["players"]:
		p["ready"] = bool(p["host"])
	_send_lobby()
	_all("h_lobby_back", [])

func _send_lobby() -> void:
	if not is_host:
		return
	_update_pings()
	_all("h_lobby", [lobby])
	lobby_changed.emit()

func _update_pings() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	for p in lobby.get("players", []):
		var id := int(p["id"])
		if id != 1:
			var pp := peer.get_peer(id)
			if pp != null:
				p["ping"] = int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

# ---------------- отправка (с имитацией плохой сети в проверке) ----------------
func _to(id: int, fn: String, args: Array) -> void:
	callv("rpc_id", [id, fn] + args)

func _all(fn: String, args: Array) -> void:
	callv("rpc", [fn] + args)

func _all_unreliable(fn: String, b: PackedByteArray) -> void:
	bytes_out += b.size() * maxi(0, multiplayer.get_peers().size())
	if sim_delay > 0.0 or sim_loss > 0.0:
		if randf() < sim_loss:
			return
		sim_queue.append([Time.get_ticks_msec() / 1000.0 + sim_delay, func(): rpc(fn, b)])
		return
	rpc(fn, b)

func _send_input(b: PackedByteArray) -> void:
	bytes_out += b.size()
	if sim_delay > 0.0 or sim_loss > 0.0:
		if randf() < sim_loss:
			return
		sim_queue.append([Time.get_ticks_msec() / 1000.0 + sim_delay, func(): rpc_id(1, "c_input", b)])
		return
	rpc_id(1, "c_input", b)

# ---------------- клиент ----------------
## Войти в лобби по адресу. Результат — сигналом joined или failed.
func join(ip: String, port: int, nm: String, password: String) -> String:
	leave_peer()
	ip = ip.strip_edges()
	if ip == "" or not (ip.is_valid_ip_address() or ip == "localhost" or ip.is_valid_identifier() or ip.contains(".")):
		return "Неверный адрес: «%s». Нужен IP хоста, например 192.168.1.20 или 85.12.34.56." % ip
	if port < 1 or port > 65535:
		return "Неверный порт: %d" % port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, 3)
	if err != OK:
		return "Не получилось начать подключение к %s:%d (%s)" % [ip, port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	is_host = false
	my_name = clean_name(nm)
	pass_hash = hash_pass(password)
	connect_t = 0.0
	hello_sent = false
	return ""

func _on_connected() -> void:
	if is_host:
		return
	_long_timeout(1)
	connect_t = -1.0
	my_id = multiplayer.get_unique_id()
	hello_sent = true
	rpc_id(1, "c_hello", PROTO, fake_build if fake_build != "" else build, my_name, pass_hash)

func _on_connection_failed() -> void:
	if is_host:
		return
	_fail("Хост не отвечает. Проверь IP и порт, что хост создал лобби и открыл UDP-порт (docs/ONLINE_RACING_SETUP.md).")

func _on_server_disconnected() -> void:
	var in_race := race != null and is_instance_valid(race)
	leave_peer()
	closed.emit("Хост закрыл лобби или пропал из сети." + (" Гонка прервана." if in_race else ""))

func _fail(reason: String) -> void:
	leave_peer()
	failed.emit(reason)

func _from_host() -> bool:
	if is_host or multiplayer.get_remote_sender_id() != 1:
		rejected += 1
		return false
	return true

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_welcome(id) -> void:
	if not _from_host() or typeof(id) != TYPE_INT:
		return
	my_id = int(id)
	joined.emit()

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_reject(reason) -> void:
	if not _from_host():
		return
	_fail(String(reason) if typeof(reason) == TYPE_STRING else "Хост отказал")

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_lobby(d) -> void:
	if not _from_host() or typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("players"):
		return
	lobby = d
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_lobby_back() -> void:
	if not _from_host():
		return
	if race != null and is_instance_valid(race):
		race.quit_to_lobby()

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_load(cfg) -> void:
	if not _from_host() or typeof(cfg) != TYPE_DICTIONARY:
		return
	var c: Dictionary = cfg
	if not RaceData.TRACKS.has(String(c.get("track", ""))) or typeof(c.get("riders")) != TYPE_ARRAY:
		_fail("Хост прислал неизвестную трассу — обновите игру до одной версии")
		return
	for r in c["riders"]:
		if typeof(r) != TYPE_DICTIONARY or not RaceVisual.RIDERS.has(String(r.get("id", ""))):
			_fail("Хост прислал неизвестного гонщика")
			return
	_dbg("h_load получен")
	loading.emit(_cfg_for(c, my_id))

@rpc("authority", "call_remote", "unreliable_ordered", CH_SNAP)
func h_snap(b) -> void:
	if not _from_host() or typeof(b) != TYPE_PACKED_BYTE_ARRAY:
		return
	if race != null and is_instance_valid(race):
		race.apply_snapshot(b)

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_ev(slot, k, v) -> void:
	if not _from_host() or typeof(slot) != TYPE_INT or typeof(k) != TYPE_STRING:
		return
	if race != null and is_instance_valid(race):
		race.remote_event(int(slot), String(k), v)

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_hazard(hid, kind, pos, rad) -> void:
	if not _from_host() or typeof(hid) != TYPE_INT or typeof(kind) != TYPE_STRING or typeof(pos) != TYPE_VECTOR3:
		return
	if race != null and is_instance_valid(race) and (kind == "soap" or kind == "dust_bomb"):
		race.remote_hazard(int(hid), String(kind), pos, float(rad))

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_hazard_end(hid) -> void:
	if not _from_host() or typeof(hid) != TYPE_INT:
		return
	if race != null and is_instance_valid(race):
		race.remote_hazard_end(int(hid))

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_box(i, on) -> void:
	if not _from_host() or typeof(i) != TYPE_INT or typeof(on) != TYPE_BOOL:
		return
	if race != null and is_instance_valid(race):
		race.remote_box(int(i), bool(on))

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func h_results(rows) -> void:
	if not _from_host() or typeof(rows) != TYPE_ARRAY:
		return
	if race != null and is_instance_valid(race):
		race.remote_results(rows)

## клиент: ввод своего гонщика (30 раз в секунду; нажатия между отправками не теряются)
func client_input(inp: RaceInput, dt: float) -> void:
	sticky.jump = sticky.jump or inp.jump
	sticky.item = sticky.item or inp.item
	input_t -= dt
	if input_t > 0.0:
		return
	input_t = 1.0 / INPUT_HZ
	var send := RaceInput.new()
	send.throttle = inp.throttle
	send.brake = inp.brake
	send.steer = inp.steer
	send.drift = inp.drift
	send.boost = inp.boost
	send.look_back = inp.look_back
	send.jump = sticky.jump
	send.item = sticky.item
	sticky = RaceInput.new()
	seq = (seq + 1) & 0xFFFF
	var pk := send.pack()
	pk.resize(6)
	pk.encode_u16(4, seq)
	_send_input(pk)

func set_ready(on: bool) -> void:
	if is_host:
		return
	rpc_id(1, "c_ready", on)

func pick(rider: String) -> void:
	my_rider = rider
	if is_host:
		var p := _player(1)
		if not p.is_empty():
			p["rider"] = rider
			_send_lobby()
	else:
		rpc_id(1, "c_pick", rider)

## хост меняет настройки лобби (только он)
func set_setting(k: String, v) -> void:
	if not is_host or lobby.get("state", "") != "lobby":
		return
	match k:
		"laps":
			lobby["laps"] = clampi(int(v), 1, 5)
		"track":
			if RaceData.TRACKS.has(String(v)):
				lobby["track"] = String(v)
		"max":
			lobby["max"] = clampi(int(v), maxi(2, (lobby["players"] as Array).size()), MAX_PLAYERS)
		"private":
			lobby["private"] = bool(v)
	_send_lobby()

func my_ping() -> int:
	if is_host:
		return 0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return -1
	var pp := peer.get_peer(1)
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if pp != null else -1

## закрыть соединение и вернуть игру в офлайн
func leave_peer() -> void:
	_stop_beacon()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	lobby = {}
	loaded = {}
	rate = {}
	connect_t = -1.0
	sim_queue = []

func online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _exit_tree() -> void:
	leave_peer()

# ---------------- поиск лобби в локальной сети ----------------
## хост объявляет лобби в локальной сети раз в секунду (если оно не приватное)
func _start_beacon() -> void:
	_stop_beacon()
	disc_tx = PacketPeerUDP.new()
	disc_tx.set_broadcast_enabled(true)
	disc_tx.set_dest_address("255.255.255.255", DISCOVERY_PORT)

func _stop_beacon() -> void:
	if disc_tx != null:
		disc_tx.close()
		disc_tx = null

## клиент: слушать объявления (экран входа)
func start_discovery() -> bool:
	stop_discovery()
	disc_rx = PacketPeerUDP.new()
	if disc_rx.bind(DISCOVERY_PORT) != OK:
		disc_rx = null
		return false
	found = {}
	return true

func stop_discovery() -> void:
	if disc_rx != null:
		disc_rx.close()
		disc_rx = null

func _process(dt: float) -> void:
	# отложенные сообщения (имитация задержки)
	if not sim_queue.is_empty():
		var now := Time.get_ticks_msec() / 1000.0
		while not sim_queue.is_empty() and float(sim_queue[0][0]) <= now:
			var c: Callable = sim_queue.pop_front()[1]
			if online():
				c.call()
	# клиент: ждём соединения не дольше timeout
	if connect_t >= 0.0:
		connect_t += dt
		if connect_t > timeout:
			_fail("Нет ответа от хоста за %d с. Проверь IP, порт и проброс UDP-порта у хоста." % int(timeout))
	# объявление лобби
	if is_host and disc_tx != null and not bool(lobby.get("private", false)):
		disc_t -= dt
		if disc_t <= 0.0:
			disc_t = 1.0
			var info := {"g": "grimerka-race", "proto": PROTO, "room": lobby["room"], "host_name": lobby["host_name"], "players": (lobby["players"] as Array).size(),
				"max": lobby["max"], "has_pass": lobby["has_pass"], "port": lobby["port"], "state": lobby["state"], "track": lobby["track"]}
			disc_tx.put_packet(JSON.stringify(info).to_utf8_buffer())
	if disc_rx != null:
		while disc_rx.get_available_packet_count() > 0:
			var pk := disc_rx.get_packet()
			var ip := disc_rx.get_packet_ip()
			if pk.size() > 600:
				continue
			var d = JSON.parse_string(pk.get_string_from_utf8())
			if d is Dictionary and d.get("g") == "grimerka-race" and typeof(d.get("port")) in [TYPE_INT, TYPE_FLOAT]:
				var key := "%s:%d" % [ip, int(d["port"])]
				found[key] = {"room": clean_name(String(d.get("room", "?"))), "host_name": clean_name(String(d.get("host_name", "?"))), "players": int(d.get("players", 0)),
					"max": int(d.get("max", 8)), "has_pass": bool(d.get("has_pass", false)), "ip": ip, "port": int(d["port"]), "seen": Time.get_ticks_msec(), "state": String(d.get("state", "")), "proto": int(d.get("proto", 0))}
		for k in found.keys():
			if Time.get_ticks_msec() - int(found[k]["seen"]) > 4000:
				found.erase(k)
