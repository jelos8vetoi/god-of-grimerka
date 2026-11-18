## Импорт музыки в iPod: какие форматы берём, как проверяем, чем декодируем, откуда берём теги.
## Подробно — docs/IPOD_AUDIO_FORMATS.md. Сам iPod (ipod.gd) зовёт только start(), filters(), refuse_reason().
##
## Что делаем с файлом (probe → plan):
##   copy      — MP3, Ogg Vorbis, WAV PCM: Godot играет сам, файл копируется как есть;
##   aiff      — AIFF / AIFF-C без сжатия: переписываем в WAV здесь же (порядок байтов, заголовок);
##   transcode — M4A (AAC, ALAC), M4B, FLAC, WAV со сжатием: декодирует Windows (Media Foundation через
##               WinRT MediaTranscoder, вызывается встроенным powershell.exe) в WAV, а длинное (аудиокниги) — в MP3.
## Никаких сторонних программ: только то, что есть в Windows 10/11. На Windows «N» без Media Feature Pack
## перекодирование недоступно — об этом говорит сообщение об ошибке.
## Отказываем с понятной причиной: M4P (iTunes с DRM), Audible (AA, AAX), любой файл с защитой внутри (drms, sinf),
## WMA, Ogg Opus и прочее, чего Godot не играет. Защиту не снимаем и не обходим.
## Оригинал не трогаем: читаем его, пишем копию в user://ipod_music под новым уникальным именем.
## Импорт идёт в отдельном потоке: игра и интерфейс не замирают, прогресс — сигналом progress.
class_name AudioImport
extends Node

signal progress(done: int, total: int, name: String)
signal track_ready(track: Dictionary)
signal track_failed(name: String, reason: String)
signal finished(added: int, failed: int)

const ID3 = preload("res://scripts/id3.gd")
const DIR := "user://ipod_music"
const TMP := "user://ipod_music/.tmp"
const TOOLS := "user://ipod_tools"
const ACCEPT := ["mp3", "ogg", "oga", "wav", "m4a", "m4b", "mp4", "aif", "aiff", "aifc", "flac"]
const REFUSE := {
	"m4p": "защищённый файл iTunes (M4P, DRM) — играть его можно только в iTunes; защиту игра не снимает",
	"aa": "аудиокнига Audible с защитой (AA) — откройте её в приложении Audible",
	"aax": "аудиокнига Audible с защитой (AAX) — откройте её в приложении Audible",
	"wma": "WMA не поддерживается — сохраните трек в MP3, M4A или FLAC",
	"opus": "Opus не поддерживается — нужен MP3, M4A, FLAC или Ogg Vorbis",
	"ape": "APE не поддерживается", "wv": "WavPack не поддерживается", "mid": "MIDI не поддерживается", "midi": "MIDI не поддерживается",
}
const MAX_SOURCE := 1536 * 1024 * 1024      # 1,5 ГБ — больше не берём вовсе (длинные аудиокниги — до этого)
const MAX_PCM := 400 * 1024 * 1024          # WAV / AIFF целиком лежат в памяти, пока играют
const LONG_SEC := 15.0 * 60.0               # длиннее — декодируем в MP3 (иначе WAV аудиокниги — гигабайты)
const MAX_TAG := 32 * 1024 * 1024
const MAX_COVER := 16 * 1024 * 1024
const TIMEOUT_NOTE := "перекодирование не удалось"

var queue: Array = []
var thread: Thread
var busy := false
var stop_req := false
var results: Array = []               # для проверки: [имя, "ok" | причина, план, кодек]

## Фильтры окна выбора файлов
static func filters() -> PackedStringArray:
	return PackedStringArray([
		"*.mp3, *.m4a, *.m4b, *.mp4, *.aif, *.aiff, *.aifc, *.wav, *.ogg, *.oga, *.flac ; Вся музыка",
		"*.mp3 ; MP3", "*.m4a, *.mp4 ; M4A (AAC, ALAC)", "*.m4b ; Аудиокниги M4B", "*.aif, *.aiff, *.aifc ; AIFF",
		"*.wav ; WAV", "*.ogg, *.oga ; Ogg Vorbis", "*.flac ; FLAC"])

## Почему файл не берём по одному расширению ("" — расширение подходит, дальше решает содержимое)
static func refuse_reason(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if REFUSE.has(ext):
		return String(REFUSE[ext])
	if not ACCEPT.has(ext):
		return "формат .%s не поддерживается" % ext if ext != "" else "у файла нет расширения — формат неизвестен"
	return ""

## Поставить файлы в очередь; поток один, следующие вызовы дописывают очередь
func start(paths: PackedStringArray) -> void:
	for p in paths:
		queue.append(String(p))
	if busy:
		return
	busy = true
	stop_req = false
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	thread = Thread.new()
	thread.start(_worker)

func stop() -> void:
	stop_req = true
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	busy = false

func _exit_tree() -> void:
	stop()

func _worker() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var added := 0
	var failed := 0
	var done := 0
	while not stop_req:
		var src := ""
		if queue.is_empty():
			break
		src = String(queue.pop_front())
		var total := done + queue.size() + 1
		call_deferred("emit_signal", "progress", done, total, src.get_file())
		var r := import_one(src)
		done += 1
		if r.has("track"):
			added += 1
			call_deferred("emit_signal", "track_ready", r["track"])
		else:
			failed += 1
			call_deferred("emit_signal", "track_failed", src.get_file(), String(r.get("reason", "не удалось")))
	call_deferred("_done", added, failed)

func _done(added: int, failed: int) -> void:
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	busy = false
	if not queue.is_empty() and not stop_req:
		start(PackedStringArray())
		return
	finished.emit(added, failed)

## Один файл: проверка, план, копия или декодирование, теги и обложка. {track} или {reason}
func import_one(src: String) -> Dictionary:
	var name := src.get_file()
	var why := refuse_reason(src)
	if why != "":
		results.append([name, why, "", ""])
		return {"reason": why}
	if not FileAccess.file_exists(src):
		results.append([name, "файл не найден", "", ""])
		return {"reason": "файл не найден"}
	var info := probe(src)
	if not bool(info.get("ok", false)):
		results.append([name, String(info["reason"]), "", String(info.get("codec", ""))])
		return {"reason": String(info["reason"])}
	var id := _unique_id()
	var out_path := ""
	var res := {}
	match String(info["plan"]):
		"copy":
			out_path = DIR.path_join(id + "." + String(info["out_ext"]))
			res = _copy(src, out_path)
		"aiff":
			out_path = DIR.path_join(id + ".wav")
			res = _aiff_to_wav(src, out_path, info)
		"transcode":
			var long: bool = float(info.get("duration", 0.0)) > LONG_SEC
			out_path = DIR.path_join(id + (".mp3" if long else ".wav"))
			res = _transcode(src, out_path, "mp3" if long else "wav", String(info["tmp_ext"]))
			if not bool(res.get("ok", false)) and long:
				res["reason"] = String(res.get("reason", TIMEOUT_NOTE))
	if not bool(res.get("ok", false)):
		_remove(out_path)
		results.append([name, String(res.get("reason", "не удалось")), String(info["plan"]), String(info.get("codec", ""))])
		return {"reason": String(res.get("reason", "не удалось"))}
	var check := _playable(out_path)
	if check != "":
		_remove(out_path)
		results.append([name, check, String(info["plan"]), String(info.get("codec", ""))])
		return {"reason": check}
	var cover := ""
	var cb: PackedByteArray = info.get("cover_bytes", PackedByteArray())
	var ce := String(info.get("cover_ext", ""))
	if not cb.is_empty() and ce in ["jpg", "png"] and cb.size() <= MAX_COVER:
		cover = DIR.path_join(id + "_cover." + ce)
		var cf := FileAccess.open(cover, FileAccess.WRITE)
		if cf != null:
			cf.store_buffer(cb)
			cf.close()
		else:
			cover = ""
	var title := String(info.get("title", "")).strip_edges()
	var artist := String(info.get("artist", "")).strip_edges()
	results.append([name, "ok", String(info["plan"]), String(info.get("codec", ""))])
	return {"track": {"id": id, "title": title if title != "" else src.get_file().get_basename(),
		"artist": artist if artist != "" else "Моя музыка", "album": String(info.get("album", "")).strip_edges(),
		"cover": cover, "path": out_path, "local": true, "format": String(info.get("codec", ""))}}

## Имя копии: время + случайное число; если вдруг занято — следующее (чужие треки не перезаписываем)
func _unique_id() -> String:
	while true:
		var id := "%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000000]
		var busy_name := false
		for ext in ["mp3", "ogg", "wav"]:
			if FileAccess.file_exists(DIR.path_join(id + "." + ext)):
				busy_name = true
		if not busy_name:
			return id
	return ""

func _remove(p: String) -> void:
	if p != "" and FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Готовую копию Godot должен суметь открыть — иначе трек не добавляем
func _playable(p: String) -> String:
	var s: AudioStream = null
	match p.get_extension():
		"mp3":
			s = AudioStreamMP3.load_from_file(p)
		"ogg":
			s = AudioStreamOggVorbis.load_from_file(p)
		"wav":
			s = AudioStreamWAV.load_from_file(p)
	if s == null or s.get_length() <= 0.0:
		return "файл повреждён или пуст — его не удалось открыть"
	return ""

# ---------------- проверка содержимого ----------------
## {ok, plan, out_ext | tmp_ext, codec, duration, title, artist, album, cover_bytes, cover_ext} или {ok: false, reason}
static func probe(path: String) -> Dictionary:
	var ext := path.get_extension().to_lower()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "файл не открывается (нет доступа или он занят)"}
	var size := f.get_length()
	if size < 16:
		return {"ok": false, "reason": "файл пустой"}
	if size > MAX_SOURCE:
		return {"ok": false, "reason": "файл больше %d МБ" % (MAX_SOURCE / 1048576)}
	var head := f.get_buffer(64)
	f.close()
	var magic := head.slice(0, 4).get_string_from_ascii()
	var info := {"ok": true, "title": "", "artist": "", "album": "", "cover_bytes": PackedByteArray(), "cover_ext": "", "duration": 0.0}
	match ext:
		"mp3":
			var id3 := head.slice(0, 3).get_string_from_ascii() == "ID3"
			var sync := head[0] == 0xFF and (head[1] & 0xE0) == 0xE0
			if not id3 and not sync:
				return _not_like(path, "MP3")
			info.merge(ID3.read(path), true)
			info["plan"] = "copy"
			info["out_ext"] = "mp3"
			info["codec"] = "MP3"
		"ogg", "oga":
			if magic != "OggS":
				return _not_like(path, "Ogg")
			var first := head.slice(28, 36)
			if first.slice(1, 7).get_string_from_ascii() == "vorbis" and first[0] == 1:
				info["plan"] = "copy"
				info["out_ext"] = "ogg"
				info["codec"] = "Ogg Vorbis"
			elif first.slice(0, 8).get_string_from_ascii() == "OpusHead":
				return {"ok": false, "codec": "Ogg Opus", "reason": "Ogg Opus не поддерживается — нужен Ogg Vorbis, MP3, M4A или FLAC"}
			elif first.slice(1, 5).get_string_from_ascii() == "FLAC":
				return {"ok": false, "codec": "Ogg FLAC", "reason": "FLAC внутри Ogg не поддерживается — нужен обычный .flac"}
			else:
				return {"ok": false, "codec": "Ogg ?", "reason": "в файле Ogg не Vorbis — такой кодек игра не играет"}
		"wav":
			if magic != "RIFF" or head.slice(8, 12).get_string_from_ascii() != "WAVE":
				return _not_like(path, "WAV")
			return _wav(path, info)
		"aif", "aiff", "aifc":
			if magic != "FORM" or not head.slice(8, 12).get_string_from_ascii() in ["AIFF", "AIFC"]:
				return _not_like(path, "AIFF")
			return _aiff(path, info)
		"flac":
			if magic != "fLaC":
				return _not_like(path, "FLAC")
			return _flac(path, info)
		"m4a", "m4b", "mp4":
			if head.slice(4, 8).get_string_from_ascii() != "ftyp":
				return _not_like(path, "M4A")
			return _mp4(path, info, ext)
	return {"ok": false, "reason": "формат не поддерживается"}

static func _not_like(path: String, what: String) -> Dictionary:
	return {"ok": false, "reason": "по содержимому это не %s (расширение .%s не совпадает с форматом)" % [what, path.get_extension()]}

static func _be32(b: PackedByteArray, o: int) -> int:
	return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]

static func _be16(b: PackedByteArray, o: int) -> int:
	return (b[o] << 8) | b[o + 1]

static func _str(b: PackedByteArray, a: int, z: int) -> String:
	return b.slice(a, z).get_string_from_ascii()

## Текст тега: UTF-8 (и Latin-1, если UTF-8 не сложился)
static func _text(b: PackedByteArray) -> String:
	var s := b.get_string_from_utf8()
	if s == "" and not b.is_empty():
		s = b.get_string_from_ascii()
	return s.replace("\u0000", "").strip_edges()

static func _cover_ext(b: PackedByteArray) -> String:
	if b.size() > 3 and b[0] == 0xFF and b[1] == 0xD8:
		return "jpg"
	if b.size() > 8 and b[0] == 0x89 and _str(b, 1, 4) == "PNG":
		return "png"
	return ""

## ID3 внутри AIFF / WAV: тот же разбор, что у MP3 (id3.gd), через временный файл
static func _id3_bytes(b: PackedByteArray, info: Dictionary) -> void:
	if b.size() < 10 or b.size() > MAX_TAG:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var p := TMP.path_join("tag_%d.id3" % randi())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(b)
	f.close()
	var t: Dictionary = ID3.read(p)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for k in ["title", "artist", "album"]:
		if String(t.get(k, "")) != "" and String(info.get(k, "")) == "":
			info[k] = t[k]
	if (info["cover_bytes"] as PackedByteArray).is_empty() and not (t.get("cover_bytes", PackedByteArray()) as PackedByteArray).is_empty():
		info["cover_bytes"] = t["cover_bytes"]
		info["cover_ext"] = t["cover_ext"]

# ---------------- WAV ----------------
static func _wav(path: String, info: Dictionary) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var n := f.get_length()
	var pos := 12
	var tag := -1
	var bits := 0
	var rate := 0
	var ch := 0
	var data := 0
	while pos + 8 <= n:
		f.seek(pos)
		var cid := f.get_buffer(4).get_string_from_ascii()
		var sz := f.get_32()
		if sz < 0 or pos + 8 + sz > n + 1:
			sz = n - pos - 8
		match cid:
			"fmt ":
				var fb := f.get_buffer(mini(sz, 40))
				tag = fb.decode_u16(0)
				ch = fb.decode_u16(2)
				rate = fb.decode_u32(4)
				bits = fb.decode_u16(14)
				if tag == 0xFFFE and fb.size() >= 26:
					tag = -fb.decode_u16(24)     # extensible: подформат (−1 PCM, −3 float) — отдаём Windows
			"data":
				data = sz
			"LIST":
				var lb := f.get_buffer(mini(sz, MAX_TAG))
				if lb.size() > 4 and _str(lb, 0, 4) == "INFO":
					var q := 4
					while q + 8 <= lb.size():
						var k := _str(lb, q, q + 4)
						var ln := lb.decode_u32(q + 4)
						var v := _text(lb.slice(q + 8, mini(lb.size(), q + 8 + ln)))
						match k:
							"INAM":
								info["title"] = v
							"IART":
								info["artist"] = v
							"IPRD":
								info["album"] = v
						q += 8 + ln + (ln & 1)
			"id3 ", "ID3 ":
				_id3_bytes(f.get_buffer(sz), info)
		pos += 8 + sz + (sz & 1)
	f.close()
	if tag == -1 or ch <= 0 or rate <= 0:
		return {"ok": false, "codec": "WAV ?", "reason": "в WAV нет описания звука (fmt) — файл повреждён"}
	if ch > 0 and rate > 0 and bits > 0:
		info["duration"] = float(data) / float(rate * ch * maxi(1, bits / 8))
	if tag in [1, 3] and bits in [8, 16, 24, 32, 64]:
		if n > MAX_PCM:
			return {"ok": false, "codec": "WAV PCM", "reason": "WAV больше %d МБ — сохраните его в FLAC или M4A" % (MAX_PCM / 1048576)}
		info["plan"] = "copy"
		info["out_ext"] = "wav"
		info["codec"] = "WAV PCM %d бит" % bits if tag == 1 else "WAV float"
	else:
		info["plan"] = "transcode"
		info["tmp_ext"] = "wav"
		info["codec"] = "WAV (кодек %d)" % absi(tag)
	return info

# ---------------- AIFF ----------------
static func _aiff(path: String, info: Dictionary) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	f.big_endian = true
	var n := f.get_length()
	var aifc := false
	f.seek(8)
	aifc = f.get_buffer(4).get_string_from_ascii() == "AIFC"
	var pos := 12
	var comm := false
	while pos + 8 <= n:
		f.seek(pos)
		var cid := f.get_buffer(4).get_string_from_ascii()
		var sz := f.get_32()
		if pos + 8 + sz > n:
			sz = n - pos - 8
		match cid:
			"COMM":
				comm = true
				info["ch"] = f.get_16()
				info["frames"] = f.get_32()
				info["bits"] = f.get_16()
				var ex := f.get_16()
				var hi := f.get_32()
				var lo := f.get_32()
				var e := (ex & 0x7FFF) - 16383 - 63
				info["rate"] = int(round((float(hi) * 4294967296.0 + float(lo)) * pow(2.0, e)))
				info["comp"] = f.get_buffer(4).get_string_from_ascii() if aifc and sz >= 22 else "NONE"
			"SSND":
				var off := f.get_32()
				f.get_32()
				info["ssnd"] = pos + 16 + off
				info["ssnd_len"] = sz - 8 - off
			"NAME":
				info["title"] = _text(f.get_buffer(sz))
			"AUTH":
				info["artist"] = _text(f.get_buffer(sz))
			"ID3 ", "id3 ":
				_id3_bytes(f.get_buffer(sz), info)
		pos += 8 + sz + (sz & 1)
	f.close()
	if not comm or not info.has("ssnd"):
		return {"ok": false, "codec": "AIFF ?", "reason": "в AIFF нет звука или описания (COMM / SSND) — файл повреждён"}
	var comp := String(info["comp"])
	var bits := int(info["bits"])
	var ch := int(info["ch"])
	var rate := int(info["rate"])
	if ch < 1 or ch > 8 or rate < 4000 or rate > 384000:
		return {"ok": false, "codec": "AIFF", "reason": "в AIFF неверные параметры звука"}
	info["duration"] = float(info["frames"]) / float(rate)
	if not comp in ["NONE", "twos", "sowt", "fl32", "FL32", "in24", "in32"]:
		return {"ok": false, "codec": "AIFF-C " + comp, "reason": "AIFF со сжатием «%s» не поддерживается — нужен AIFF без сжатия" % comp}
	if comp in ["fl32", "FL32"]:
		bits = 32
	if not bits in [8, 16, 24, 32]:
		return {"ok": false, "codec": "AIFF", "reason": "AIFF %d бит не поддерживается" % bits}
	if int(info["ssnd_len"]) * (1 if comp == "sowt" else 1) > MAX_PCM:
		return {"ok": false, "codec": "AIFF", "reason": "AIFF больше %d МБ — сохраните его в FLAC или M4A" % (MAX_PCM / 1048576)}
	info["bits"] = bits
	info["float"] = comp in ["fl32", "FL32"]
	info["le"] = comp == "sowt"
	info["plan"] = "aiff"
	info["codec"] = ("AIFF-C" if aifc else "AIFF") + " %d бит" % bits
	return info

## AIFF → WAV: тот же звук, порядок байтов WAV (младший первым), 8 бит — без знака
func _aiff_to_wav(src: String, dst: String, info: Dictionary) -> Dictionary:
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "файл не открывается"}
	var o := FileAccess.open(dst, FileAccess.WRITE)
	if o == null:
		return {"ok": false, "reason": "не удалось записать копию (нет места на диске?)"}
	var ch := int(info["ch"])
	var bits := int(info["bits"])
	var rate := int(info["rate"])
	var w := bits / 8
	var total := int(info["ssnd_len"]) - int(info["ssnd_len"]) % (w * ch)
	total = mini(total, int(info["frames"]) * w * ch) if int(info["frames"]) > 0 else total
	o.store_buffer("RIFF".to_ascii_buffer())
	o.store_32(36 + total)
	o.store_buffer("WAVEfmt ".to_ascii_buffer())
	o.store_32(16)
	o.store_16(3 if bool(info["float"]) else 1)
	o.store_16(ch)
	o.store_32(rate)
	o.store_32(rate * ch * w)
	o.store_16(ch * w)
	o.store_16(bits)
	o.store_buffer("data".to_ascii_buffer())
	o.store_32(total)
	f.seek(int(info["ssnd"]))
	var left := total
	var step := 1 << 20
	step -= step % w
	while left > 0 and not stop_req:
		var c := f.get_buffer(mini(step, left))
		if c.is_empty():
			break
		if not bool(info["le"]):
			if w == 1:
				for i in c.size():
					c[i] = c[i] ^ 0x80
			elif w == 2:
				for i in range(0, c.size() - 1, 2):
					var t := c[i]
					c[i] = c[i + 1]
					c[i + 1] = t
			else:
				for i in range(0, c.size() - w + 1, w):
					for k in w / 2:
						var t := c[i + k]
						c[i + k] = c[i + w - 1 - k]
						c[i + w - 1 - k] = t
		o.store_buffer(c)
		left -= c.size()
	f.close()
	o.close()
	if stop_req:
		return {"ok": false, "reason": "импорт прерван"}
	return {"ok": left <= 0, "reason": "AIFF оборван — звука меньше, чем заявлено" if left > 0 else ""}

# ---------------- FLAC ----------------
static func _flac(path: String, info: Dictionary) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	f.big_endian = true
	var pos := 4
	var n := f.get_length()
	var last := false
	while not last and pos + 4 <= n:
		f.seek(pos)
		var hb := f.get_8()
		last = (hb & 0x80) != 0
		var typ := hb & 0x7F
		var ln := (f.get_8() << 16) | (f.get_8() << 8) | f.get_8()
		if ln > MAX_TAG:
			break
		var b := f.get_buffer(ln)
		match typ:
			0:
				if b.size() >= 18:
					var rate := (b[10] << 12) | (b[11] << 4) | (b[12] >> 4)
					var samples := ((b[13] & 0x0F) << 32) | (b[14] << 24) | (b[15] << 16) | (b[16] << 8) | b[17]
					if rate > 0:
						info["duration"] = float(samples) / float(rate)
			4:
				_vorbis_comments(b, info)
			6:
				if b.size() > 32:
					var q := 4
					var ml := _be32(b, q)
					q += 4 + ml
					var dl := _be32(b, q)
					q += 4 + dl + 16
					var pl := _be32(b, q)
					var pic := b.slice(q + 4, q + 4 + pl)
					if (info["cover_bytes"] as PackedByteArray).is_empty() and _cover_ext(pic) != "":
						info["cover_bytes"] = pic
						info["cover_ext"] = _cover_ext(pic)
		pos += 4 + ln
	f.close()
	info["plan"] = "transcode"
	info["tmp_ext"] = "flac"
	info["codec"] = "FLAC"
	return info

static func _vorbis_comments(b: PackedByteArray, info: Dictionary) -> void:
	if b.size() < 8:
		return
	var q := 4 + b.decode_u32(0)
	if q + 4 > b.size():
		return
	var cnt := b.decode_u32(q)
	q += 4
	for i in mini(cnt, 512):
		if q + 4 > b.size():
			break
		var ln := b.decode_u32(q)
		var s := b.slice(q + 4, mini(b.size(), q + 4 + ln)).get_string_from_utf8()
		q += 4 + ln
		var eq := s.find("=")
		if eq <= 0:
			continue
		var k := s.substr(0, eq).to_upper()
		var v := s.substr(eq + 1).strip_edges()
		if k == "TITLE" and String(info["title"]) == "":
			info["title"] = v
		elif k == "ARTIST" and String(info["artist"]) == "":
			info["artist"] = v
		elif k == "ALBUM" and String(info["album"]) == "":
			info["album"] = v

# ---------------- M4A / M4B (MP4) ----------------
## Ищем moov (бывает и в конце файла, после звука), в нём: звуковую дорожку и кодек (stsd), защиту (drms, sinf),
## длительность (mvhd), теги iTunes (ilst: ©nam, ©ART, ©alb, aART, covr).
static func _mp4(path: String, info: Dictionary, ext: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	f.big_endian = true
	var n := f.get_length()
	var pos := 0
	var moov := Vector2i(-1, -1)
	while pos + 8 <= n:
		f.seek(pos)
		var sz := f.get_32()
		var typ := f.get_buffer(4).get_string_from_ascii()
		var h := 8
		if sz == 1:
			sz = f.get_64()
			h = 16
		elif sz == 0:
			sz = n - pos
		if sz < h:
			break
		if typ == "moov":
			moov = Vector2i(pos + h, pos + sz)
		pos += sz
	if moov.x < 0:
		f.close()
		return {"ok": false, "codec": "MP4 ?", "reason": "в файле нет описания дорожек (moov) — файл недокачан или повреждён"}
	if moov.y - moov.x > MAX_TAG * 2 or moov.y > n:
		f.close()
		return {"ok": false, "codec": "MP4 ?", "reason": "описание дорожек повреждено"}
	f.seek(moov.x)
	var mb := f.get_buffer(moov.y - moov.x)
	f.close()
	var st := {"codecs": [], "audio": false, "protected": false}
	_atoms(mb, 0, mb.size(), info, st, 0)
	var codecs: Array = st["codecs"]
	if bool(st["protected"]) or codecs.has("drms") or codecs.has("drma") or codecs.has("enca"):
		return {"ok": false, "codec": "защищённый AAC", "reason": "файл защищён DRM (покупка iTunes / Audible) — играть его можно только там, где он куплен; защиту игра не снимает"}
	var codec := ""
	for c in codecs:
		if c in ["mp4a", "alac"]:
			codec = c
	if codec == "":
		if codecs.is_empty() or not bool(st["audio"]):
			return {"ok": false, "codec": "MP4 без звука", "reason": "в файле нет звуковой дорожки"}
		return {"ok": false, "codec": ", ".join(codecs), "reason": "кодек «%s» в M4A не поддерживается — нужен AAC или ALAC" % ", ".join(codecs)}
	info["plan"] = "transcode"
	info["tmp_ext"] = "m4a"           # и M4B, и MP4 Windows открывает как .m4a
	info["codec"] = ("ALAC" if codec == "alac" else "AAC") + (" · аудиокнига M4B" if ext == "m4b" else "")
	return info

static func _atoms(b: PackedByteArray, s: int, e: int, info: Dictionary, st: Dictionary, depth: int) -> void:
	if depth > 12:
		return
	while s + 8 <= e:
		var sz := _be32(b, s)
		var h := 8
		if sz == 1 and s + 16 <= e:
			sz = (_be32(b, s + 8) << 32) | _be32(b, s + 12)
			h = 16
		elif sz == 0:
			sz = e - s
		if sz < h or s + sz > e:
			return
		var raw := b.slice(s + 4, s + 8)
		var typ := raw.get_string_from_ascii() if raw[0] != 0xA9 else "©" + _str(raw, 1, 4)
		match typ:
			"trak", "mdia", "minf", "stbl", "udta", "ilst", "edts":
				_atoms(b, s + h, s + sz, info, st, depth + 1)
			"meta":
				var c0 := s + h + (4 if s + h + 4 <= s + sz and _be32(b, s + h) == 0 else 0)
				_atoms(b, c0, s + sz, info, st, depth + 1)
			"hdlr":
				if s + h + 12 <= s + sz and _str(b, s + h + 8, s + h + 12) == "soun":
					st["audio"] = true
			"mvhd":
				var v := b[s + h]
				var ts := _be32(b, s + h + (12 if v == 0 else 20))
				var du := _be32(b, s + h + 16) if v == 0 else ((_be32(b, s + h + 24) << 32) | _be32(b, s + h + 28))
				if ts > 0:
					info["duration"] = float(du) / float(ts)
			"stsd":
				var q := s + h + 8
				var cnt := _be32(b, s + h + 4)
				for i in mini(cnt, 8):
					if q + 8 > s + sz:
						break
					var esz := _be32(b, q)
					(st["codecs"] as Array).append(_str(b, q + 4, q + 8))
					if q + 36 < q + esz:
						_atoms(b, q + 36, mini(q + esz, s + sz), info, st, depth + 1)       # внутри записи: sinf, esds…
					q += maxi(esz, 8)
			"sinf", "schm":
				st["protected"] = true
			"©nam", "©ART", "©alb", "aART", "covr":
				if s + h + 16 <= s + sz and _str(b, s + h + 4, s + h + 8) == "data":
					var dsz := _be32(b, s + h)
					var kind := _be32(b, s + h + 8) & 0xFFFFFF
					var payload := b.slice(s + h + 16, mini(s + sz, s + h + dsz))
					match typ:
						"covr":
							if (info["cover_bytes"] as PackedByteArray).is_empty() and payload.size() <= MAX_COVER:
								var ce := _cover_ext(payload)
								if ce != "":
									info["cover_bytes"] = payload
									info["cover_ext"] = ce
						"©nam":
							info["title"] = _text(payload) if kind == 1 or kind == 0 else String(info["title"])
						"©ART":
							info["artist"] = _text(payload)
						"aART":
							if String(info["artist"]) == "":
								info["artist"] = _text(payload)
						"©alb":
							info["album"] = _text(payload)
		s += sz

# ---------------- копия и декодирование ----------------
func _copy(src: String, dst: String) -> Dictionary:
	var f := FileAccess.open(src, FileAccess.READ)
	var o := FileAccess.open(dst, FileAccess.WRITE)
	if f == null or o == null:
		return {"ok": false, "reason": "не удалось скопировать (нет доступа или места на диске)"}
	while not f.eof_reached() and not stop_req:
		var c := f.get_buffer(4 << 20)
		if c.is_empty():
			break
		o.store_buffer(c)
	f.close()
	o.close()
	return {"ok": not stop_req, "reason": "импорт прерван" if stop_req else ""}

## Декодирует Windows: копия исходника под простым именем во временной папке → powershell.exe со скриптом
## TRANSCODE_PS1 (аргументы — отдельными строками, без командной оболочки) → WAV или MP3 в DIR.
func _transcode(src: String, dst: String, fmt: String, tmp_ext: String) -> Dictionary:
	if OS.get_name() != "Windows":
		return {"ok": false, "reason": "этот формат декодирует Windows — на другой системе он недоступен"}
	var script := _ensure_script()
	if script == "":
		return {"ok": false, "reason": "не удалось подготовить декодер"}
	var tmp := TMP.path_join("src_%d.%s" % [randi(), tmp_ext])
	var c := _copy(src, tmp)
	if not bool(c["ok"]):
		_remove(tmp)
		return c
	var out: Array = []
	var args := PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script,
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(dst), fmt])
	var code := OS.execute("powershell.exe", args, out, true, false)
	_remove(tmp)
	var said := "\n".join(out).strip_edges()
	if code == 0 and said.ends_with("OK") and FileAccess.file_exists(dst):
		return {"ok": true}
	if code == -1:
		return {"ok": false, "reason": "не найден powershell.exe — декодер Windows недоступен"}
	var why := said.get_slice("FAIL", 1).strip_edges() if said.contains("FAIL") else said
	if why.contains("CodecNotFound") or why.contains("0xC00D5212") or why.to_lower().contains("codec"):
		return {"ok": false, "reason": "в Windows нет кодека для этого файла (на Windows N поставьте Media Feature Pack)"}
	if why.contains("InvalidProfile") or why.contains("0xC00D36C4"):
		return {"ok": false, "reason": "Windows не смог прочитать файл — он повреждён или формат внутри не тот"}
	return {"ok": false, "reason": "Windows не смог перекодировать файл" + (" (%s)" % why.left(120) if why != "" else "")}

func _ensure_script() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TOOLS))
	var p := TOOLS.path_join("transcode.ps1")
	if not FileAccess.file_exists(p) or FileAccess.get_file_as_string(p) != TRANSCODE_PS1:
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_string(TRANSCODE_PS1)
		f.close()
	return ProjectSettings.globalize_path(p)

## Только для проверок: закодировать WAV в M4A (AAC), ALAC, FLAC или MP3 тем же декодером Windows
func encode_for_test(src: String, dst: String, fmt: String) -> bool:
	var script := _ensure_script()
	var out: Array = []
	var code := OS.execute("powershell.exe", PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script,
		ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst), fmt]), out, true, false)
	return code == 0 and FileAccess.file_exists(dst)

const TRANSCODE_PS1 := """param([string]$Src, [string]$Dst, [string]$Fmt = "wav")
# GOD OF GRIMERKA iPod: decode audio with the Windows built-in Media Foundation (WinRT MediaTranscoder).
# Output: "OK" (exit 0) or "FAIL <reason>" (exit 2/3). Files are passed as arguments, never through a shell.
$ErrorActionPreference = 'Stop'
try {
	Add-Type -AssemblyName System.Runtime.WindowsRuntime
	$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
	$null = [Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
	$null = [Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime]
	$null = [Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
	$ext = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
	function Wait-Op($op, [Type]$t) {
		$m = ($ext | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0].MakeGenericMethod($t)
		$task = $m.Invoke($null, @($op))
		$null = $task.Wait(-1)
		return $task.Result
	}
	function Wait-Progress($op) {
		$m = ($ext | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0].MakeGenericMethod([double])
		$task = $m.Invoke($null, @($op))
		$null = $task.Wait(-1)
	}
	$srcFull = [System.IO.Path]::GetFullPath($Src)
	$dstFull = [System.IO.Path]::GetFullPath($Dst)
	$in = Wait-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync($srcFull)) ([Windows.Storage.StorageFile])
	$folder = Wait-Op ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync([System.IO.Path]::GetDirectoryName($dstFull))) ([Windows.Storage.StorageFolder])
	$out = Wait-Op ($folder.CreateFileAsync([System.IO.Path]::GetFileName($dstFull), [Windows.Storage.CreationCollisionOption]::FailIfExists)) ([Windows.Storage.StorageFile])
	$q = [Windows.Media.MediaProperties.AudioEncodingQuality]::High
	switch ($Fmt) {
		"m4a" { $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateM4a($q) }
		"alac" { $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateAlac($q) }
		"flac" { $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateFlac($q) }
		"mp3" { $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp3($q) }
		default { $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav($q) }
	}
	$tc = New-Object Windows.Media.Transcoding.MediaTranscoder
	$prep = Wait-Op ($tc.PrepareFileTranscodeAsync($in, $out, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
	if (-not $prep.CanTranscode) {
		$null = $out.DeleteAsync()
		Write-Output ("FAIL " + $prep.FailureReason)
		exit 2
	}
	Wait-Progress ($prep.TranscodeAsync())
	Write-Output "OK"
	exit 0
} catch {
	Write-Output ("FAIL " + $_.Exception.GetBaseException().Message)
	exit 3
}
"""
