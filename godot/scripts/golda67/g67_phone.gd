## iPhone Пахана (приквел): плейлист «Любимые треки Пахана». Свой плеер на шине Music; iPod кампании не затрагивает.
## Файлы владельца — res://assets/golda67/playlist/NN_*.mp3 (в git с 2026-11-22, права у владельца): сопоставление по номеру NN;
## в экспорте они видны как *.mp3.import — учтены оба имени. Состояние в сохранение не пишется.
class_name G67Phone
extends Node

const DIR := "res://assets/golda67/playlist/"
const COVER := "res://assets/golda67/playlist/cover.webp"

var found := {}                  # номер → путь
var cur := -1                    # номер играющего трека (индекс списка + 1), -1 — ничего
var selected := 0                # выбранная строка списка (0…15)
var volume := 0.7
var player: AudioStreamPlayer
var paused := false
var injected := {}               # проверка: номер → готовый поток вместо файла

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	player.volume_db = linear_to_db(volume)
	player.finished.connect(_on_finished)
	add_child(player)
	scan()

func scan() -> void:
	found = {}
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		var nm := String(f)
		if nm.ends_with(".import"):
			nm = nm.trim_suffix(".import")
		if not (nm.ends_with(".mp3") or nm.ends_with(".ogg")):
			continue
		var no := int(nm.substr(0, 2))
		if no >= 1 and no <= G67Data.PLAYLIST.size():
			found[no] = DIR + nm

func has_track(no: int) -> bool:
	return found.has(no) or injected.has(no)

func available() -> int:
	var n := 0
	for i in G67Data.PLAYLIST.size():
		if has_track(i + 1):
			n += 1
	return n

func play(no: int) -> bool:
	if not has_track(no):
		return false
	var st = injected.get(no)
	if st == null:
		st = load(String(found[no]))
	if st == null:
		return false
	cur = no
	selected = no - 1
	paused = false
	player.stream = st
	player.stream_paused = false
	player.play()
	return true

func toggle() -> void:
	if cur < 0:
		if not play(selected + 1):
			step(1)
		return
	paused = not paused
	player.stream_paused = paused

func step(d: int) -> void:
	var n := G67Data.PLAYLIST.size()
	var no := maxi(cur, selected + 1)
	for i in n:
		no = (no - 1 + d + n) % n + 1
		if has_track(no):
			play(no)
			return

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if player != null:
		player.volume_db = linear_to_db(maxf(volume, 0.001))

func select(d: int) -> void:
	var n := G67Data.PLAYLIST.size()
	selected = (selected + d + n) % n

func stop() -> void:
	cur = -1
	paused = false
	if player != null:
		player.stop()

## Плейлист звучит прямо сейчас (музыка локации и тема босса молчат)
func active() -> bool:
	return cur >= 0 and not paused and player != null and player.playing

func position() -> float:
	return player.get_playback_position() if player != null and player.playing else 0.0

func length() -> float:
	return player.stream.get_length() if player != null and player.stream != null else 0.0

func _on_finished() -> void:
	if cur >= 0 and not paused:
		step(1)

static func clock(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]
