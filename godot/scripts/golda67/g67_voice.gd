## Озвучка приквела «ГОЛДА 67», глава 1 (подъезд + ДВОР + босс Миша Минасян).
##
## Как работает. Реплика в игре — строка «КОД|текст» (диалоги, выкрики, фразы босса). Игра уже умеет находить голос
## строки (game._voice_path); в приквеле она сначала спрашивает этот манифест: res://Audio/Voice/Golda67/Chapter_01/
## manifest.json — у каждой реплики свой ID (CH01_PAHAN_001…), голосовая модель Voice Studio Pro, путь к .ogg и статус.
## Звучат только реплики со статусом generated / validated и с файлом на месте; остальное — текст без голоса (как раньше).
##
## Откуда список. chapter1_lines() собирает реплики из тех же данных, что играет игра: встречи КРОТА главы 1
## (G67Data.KROT), диалоги DJ FLÜRR, доступные в главе 1 (состояния 0–3, короткие фразы ожидания, связка знакомства),
## фразы Миши (выход и смены фаз) и боевые выкрики Пахана, которые звучат в приквеле (data/barks.json).
## Выгрузка — g67_voice_export.gd, генерация и проверка — tools/golda67-voice.cjs (через MCP Voice Studio Pro).
class_name G67Voice
extends RefCounted

const DIR := "res://Audio/Voice/Golda67/Chapter_01/"
const MANIFEST := DIR + "manifest.json"
## Кто говорит в главе 1: код в строке → персонаж, папка, как подавать
const SPEAKERS := {
	"V": {"char": "pahan", "name": "Пахан", "folder": "Pahan", "tag": "PAHAN"},
	"KR": {"char": "krot", "name": "КРОТ", "folder": "Krot", "tag": "KROT"},
	"DJ": {"char": "dj_flurr", "name": "DJ FLÜRR", "folder": "DJ_Flurr", "tag": "DJFLURR"},
	"G1": {"char": "misha", "name": "Миша Минасян", "folder": "Bosses", "tag": "MISHA"},
	# ролики главы 1 (G67Clips)
	"M": {"char": "madk1d", "name": "madk1d", "folder": "Madk1d", "tag": "MADK1D"},
	"AN": {"char": "news_anchor", "name": "Ведущий новостей", "folder": "NPC", "tag": "ANCHOR"},
	"PH": {"char": "podcast_host", "name": "Ведущий подкаста", "folder": "NPC", "tag": "HOST"},
	"WH": {"char": "whyousolonely", "name": "WHYOUSOLONELY", "folder": "NPC", "tag": "WHY"},
	"FT": {"char": "fortuna812", "name": "FORTUNA 812", "folder": "Bosses", "tag": "FORTUNA"},
	"KX": {"char": "korolevsky", "name": "Королевский XVII", "folder": "Bosses", "tag": "KOROLEVSKY"},
	"BS": {"char": "busterenko", "name": "Полковник Бустеренко", "folder": "Bosses", "tag": "BUSTERENKO"},
	# события двора: голоса из громкоговорителя и динамика (пресеты Voice Studio Pro)
	"LS": {"char": "loudspeaker", "name": "Громкоговоритель", "folder": "NPC", "tag": "LOUDSPEAKER"},
	"DP": {"char": "dispatcher", "name": "Диспетчер", "folder": "NPC", "tag": "DISPATCHER"},
}
## Подача реплик в роликах: [эмоция, темп] по коду говорящего
const CLIP_DIR := {
	"G1": ["пафосно, как в рекламе, неторопливо", 0.92], "V": ["раздражённо, коротко", 1.0], "M": ["восторженно, быстро", 1.05],
	"AN": ["максимально серьёзно, как в новостях", 0.95], "PH": ["бодро, по-подкастерски", 1.0], "WH": ["ровно и спокойно, без эмоций", 0.9],
	"FT": ["как ведущий телемагазина", 1.05], "KX": ["снисходительно, по-блогерски", 1.0], "BS": ["по-военному, твёрдо", 0.95], "KR": ["абсолютно серьёзно", 0.92],
}
## Боевые выкрики Пахана, которые доходят до приквела (остальные виды — только кампания: глава, босс кампании, гибель)
const BARK_KINDS := ["heat", "rage", "parry", "hurt", "finish"]
## Событие 2 «ТРЯПКИ! ТРЯПКИ!» (SPEC, раздел 14) — реплики дословно, по порядку сцены. Крики за дверью в конце —
## та же первая реплика madk1d (отдельной строки в ТЗ нет).
const EVENT_RAGS := ["V|ТЫ ЧЁ, БЛЯТЬ, ТВОРИШЬ?!", "M|ТРЯПКИ! ТРЯПКИ! ТРЯПКИ!", "V|Я ТОЛЬКО УСНУЛ, НАХУЙ!", "M|ТРЯПКИ, БРАТ! ВОДА ВЕЗДЕ!", "V|Я, блядь, даже спрашивать не буду."]
## Событие «Бурмалда» (постановка владельца от 2026-11-22): короткие реплики Пахана у автомата.
## 0 — перед рывком; 1 — выпало полезное; 2, 3 — выпал хлам
const EVENT_BURMALDA := ["V|Ну давай, железяка, не подведи.", "V|О. А вот это уже разговор.", "V|Я даже знать не хочу, откуда это.", "V|Брат, ты в порядке вообще?"]
## Событие «Можно. А зачем?» (постановка владельца): 0, 1 — громкоговоритель (ВОЗДУШНАЯ ТРЕВОГА); 2 — Пахан
## (ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО); 3, 4 — диспетчер из динамика (ДИСПЕТЧЕР)
const EVENT_BUTTON := ["LS|Сохраняйте спокойствие.", "LS|А, это не к нам.", "V|Чё, блять, вы тоже здесь?", "DP|Назовите причину нажатия кнопки.", "DP|Понятно. Хорошего вам дня."]
## Состояния DJ FLÜRR, доступные в главе 1: в ней всего три встречи КРОТА
const FLURR_STATES := [0, 1, 2, 3]

static var _map := {}
static var _loaded := false

## Путь к голосу строки «КОД|текст» или "" — если в манифесте её нет, она не готова или файла нет
static func path(line: String) -> String:
	if not _loaded:
		_load()
	var e: Dictionary = _map.get(line, {})
	if e.is_empty():
		return ""
	if not (String(e.get("status", "")) in ["generated", "validated"]):
		return ""
	var p := String(e.get("path", ""))
	return p if p != "" and ResourceLoader.exists(p) else ""

## Запись реплики (для отладки и проверки): id, статус, путь
static func entry(line: String) -> Dictionary:
	if not _loaded:
		_load()
	return _map.get(line, {})

static func reload() -> void:
	_loaded = false
	_map = {}

static func _load() -> void:
	_loaded = true
	_map = {}
	if not FileAccess.file_exists(MANIFEST):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (d is Dictionary):
		push_warning("G67Voice: манифест не читается: " + MANIFEST)
		return
	for e in (d.get("lines", []) as Array):
		_map[String(e["code"]) + "|" + String(e["text"])] = e

# ---------------------------------------------------------------- список реплик главы 1
## Каждая реплика: scene (где звучит), order (номер в сцене), code, text, when (условие), emotion, speed
static func chapter1_lines() -> Array:
	var out: Array = []
	# --- КРОТ: встречи 1–3 (ДВОР у ларька, ПОДЪЕЗД, ДВОР на площадке)
	var krot_dir := {
		"krot1": {"KR": ["серьёзно, как о важной сделке", 0.94], "V": ["устало, коротко", 1.0]},
		"krot2": {"KR": ["спокойно, будто это нормально", 0.92], "V": ["ошарашенно, громко", 1.05]},
		"krot3": {"KR": ["вполголоса, заговорщицки", 0.92], "V": ["раздражённо", 1.0]},
	}
	for k in G67Data.KROT:
		var id := String(k["id"])
		var lines: Array = k["lines"]
		for i in lines.size():
			var ln := String(lines[i])
			var code := ln.get_slice("|", 0)
			var dr: Array = krot_dir.get(id, {}).get(code, ["естественно", 1.0])
			out.append(_mk("krot_" + id, i, ln, "встреча с КРОТОМ «%s» (%s)" % [String(k["title"]), _where(String(k["where"]))], _emo(ln, String(dr[0])), _spd(ln, float(dr[1]))))
	# --- DJ FLÜRR в подъезде: знакомство и диалоги состояний 0–3, короткие фразы ожидания, связка знакомства
	for n in FLURR_STATES:
		var st: Array = G67Flurr.STATES[n]
		for i in st.size():
			var ln := String(st[i])
			var code := ln.get_slice("|", 0)
			var base := "уверенно, спокойно, чуть свысока" if code == "DJ" else "настороженно, с подколом"
			out.append(_mk("flurr_state%d" % n, i, ln, "разговор с DJ FLÜRR, завершено встреч КРОТА: %d" % n, _emo(ln, base), _spd(ln, 0.96 if code == "DJ" else 1.0)))
	for i in G67Flurr.WAIT.size():
		out.append(_mk("flurr_wait", i, String(G67Flurr.WAIT[i]), "повторный разговор с DJ FLÜRR до следующей встречи КРОТА", "лениво, уверенно", 0.96))
	out.append(_mk("flurr_intro_alt", 4, G67Data.FLURR_BRIDGE, "первый разговор с DJ FLÜRR, если КРОТ уже встречен (после 4 реплик знакомства)", "уверенно, с намёком", 0.96))
	# --- Миша Минасян: выход с трона и смены фаз
	var b: Dictionary = G67Data.BOSSES["g67_misha"]
	out.append(_mk("misha_intro", 0, "G1|" + G67Data.BOSS_INTRO, "выход босса с трона (ДВОР, коробка)", "тяжело, с угрозой, неторопливо", 0.9))
	var barks: Array = b.get("barks", [])
	for i in barks.size():
		if String(barks[i]) != "":
			out.append(_mk("misha_phase%d" % (i + 1), 0, "G1|" + String(barks[i]), "Миша переходит в фазу %d" % (i + 1), "самодовольно, с вызовом" if i == 1 else "хладнокровно, давит", 0.92))
	# --- ролики главы 1 (реплики — G67Clips.LINES, дословно по ТЗ)
	for cid in G67Clips.ORDER:
		var cl: Array = G67Clips.LINES.get(cid, [])
		for i in cl.size():
			var ln := String(cl[i])
			var code := ln.get_slice("|", 0)
			var dr: Array = CLIP_DIR.get(code, ["естественно", 1.0])
			out.append(_mk("clip_" + cid, i, ln, "ролик %s «%s»" % [cid, G67Clips.title(cid)], _emo(ln, String(dr[0])), float(dr[1])))
	# --- событие «ТРЯПКИ! ТРЯПКИ!» (ДВОР, обязательное)
	var rags_dir := {"V": ["спросонья, в ярости, орёт", 1.05], "M": ["в панике, орёт на бегу", 1.12]}
	for i in EVENT_RAGS.size():
		var ln := String(EVENT_RAGS[i])
		var dr: Array = rags_dir.get(ln.get_slice("|", 0), ["естественно", 1.0])
		out.append(_mk("event_rags", i, ln, "событие «ТРЯПКИ! ТРЯПКИ!» (ДВОР, квартира)", "устало, сквозь зубы" if i == 4 else String(dr[0]), 0.95 if i == 4 else float(dr[1])))
	# --- события «Бурмалда» и «Можно. А зачем?» (ДВОР, необязательные)
	var bur_emo := ["с азартом, вполголоса", "довольно, с усмешкой", "брезгливо, устало", "с недоумением, автомату"]
	for i in EVENT_BURMALDA.size():
		out.append(_mk("event_burmalda", i, String(EVENT_BURMALDA[i]), "событие «Бурмалда» (ДВОР, автомат)", String(bur_emo[i]), 1.0))
	var btn_emo := ["казённо, из громкоговорителя", "буднично, после паузы", "ошарашенно, голубям", "скучающе, по-канцелярски", "равнодушно, вежливо"]
	for i in EVENT_BUTTON.size():
		out.append(_mk("event_button", i, String(EVENT_BUTTON[i]), "событие «Можно. А зачем?» (ДВОР, кнопка)", String(btn_emo[i]), 0.95 if i != 2 else 1.0))
	# --- боевые выкрики Пахана в приквеле
	var bj = JSON.parse_string(FileAccess.get_file_as_string("res://data/barks.json"))
	if bj is Dictionary:
		for kind in BARK_KINDS:
			var arr: Array = (bj as Dictionary).get(kind, [])
			for i in arr.size():
				var ln := String(arr[i])
				if ln.begins_with("V|"):
					out.append(_mk("bark_" + kind, i, ln, "боевой выкрик Пахана: " + {"heat": "HEAT [E]", "rage": "ПЕРЕГРУЗ [R]", "parry": "парирование", "hurt": "получил удар", "finish": "добивание врага"}[kind], "коротко, резко, в бою", 1.05))
	return out

static func _mk(scene: String, order: int, line: String, when: String, emo: String, spd: float) -> Dictionary:
	var p := line.find("|")
	return {"scene": scene, "order": order, "code": line.substr(0, p), "text": line.substr(p + 1), "when": when, "emotion": emo, "speed": snappedf(spd, 0.01)}

static func _where(w: String) -> String:
	return {"hub": "ПОДЪЕЗД", "parking": "ДВОР, у ларька «ШАУРМА 67»", "playground": "ДВОР, детская площадка"}.get(w, w)

## Эмоция по знакам самой реплики поверх характера сцены (текст не меняется)
static func _emo(line: String, base: String) -> String:
	var t := line.get_slice("|", 1)
	if t.ends_with("?!") or (t.to_upper() == t and t.length() > 3):
		return "громко, на эмоциях"
	if t.ends_with("?"):
		return base + "; вопрос"
	if t.ends_with("…") or t.ends_with("..."):
		return base + "; с паузой в конце"
	return base

static func _spd(line: String, base: float) -> float:
	var t := line.get_slice("|", 1)
	if t.length() <= 6:
		return minf(base, 1.0)
	return base
