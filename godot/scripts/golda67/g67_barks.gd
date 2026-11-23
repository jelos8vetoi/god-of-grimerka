## Реплика над головой («пузырь») для жителей двора и подъезда: имя цветом, текст, голос позиционно, если он есть.
## Правила пауз берёт из G67LifeData.REACT; во время ролика, диалога, постановки и выхода босса молчит, в бою — только fight-реплики.
class_name G67Barks
extends Node3D

const MAX_DIST := 16.0
const FIGHT_GAP := 20.0
const PAHAN_GAP := 40.0

var golda
var clock := 0.0
var last_any := -100.0
var last_fight := -100.0
var last_pahan := -100.0
var last_line := {}
var last_pick := {}
var bubbles: Array = []
var log: Array = []                    # для проверок: [время, код, строка]

static func make(g) -> G67Barks:
	var b := G67Barks.new()
	b.golda = g
	b.name = "G67Barks"
	return b

## Можно ли сейчас говорить жителям (fight — реплика боевая)
func can_talk(fight := false) -> bool:
	var g = golda.game
	if golda.clip != null or g.mode == "dlg" or golda.talk_on or golda.ev_cam or golda.ev_busy or golda.scene_t >= 0.0:
		return false
	if golda.room_state == "boss":
		return false
	if golda.room_state == "fight" and not fight:
		return false
	return true

## Выбор реплики без повтора подряд
func pick(key: String, arr: Array) -> String:
	if arr.is_empty():
		return ""
	if arr.size() == 1:
		return String(arr[0])
	var prev := int(last_pick.get(key, -1))
	var i := randi() % arr.size()
	if i == prev:
		i = (i + 1) % arr.size()
	last_pick[key] = i
	return String(arr[i])

## Пузырь над who. opts: dur (с), fight (боевая), force (мимо пауз), far (мельче). true — сказано.
func say(who: Node3D, line: String, opts := {}) -> bool:
	if who == null or not is_instance_valid(who) or line == "":
		return false
	var fight: bool = bool(opts.get("fight", false))
	var force: bool = bool(opts.get("force", false))
	if not can_talk(fight) and not force:
		return false
	if not force:
		if clock - last_any < float(G67LifeData.REACT["global_gap"]):
			return false
		if clock - float(last_line.get(line, -1000.0)) < float(G67LifeData.REACT["same_line_gap"]):
			return false
		if golda.room_state == "fight" and clock - last_fight < FIGHT_GAP:
			return false
	var pl: Node3D = golda.game.player
	var dist: float = who.global_position.distance_to(pl.global_position)
	if dist > MAX_DIST and not force:
		return false
	last_any = clock
	last_line[line] = clock
	if golda.room_state == "fight":
		last_fight = clock
	var code := line.get_slice("|", 0)
	var text := line.substr(line.find("|") + 1)
	var sp: Dictionary = G67LifeData.SPEAKERS.get(code, {"name": code, "col": Color.WHITE})
	var dur: float = float(opts.get("dur", clampf(1.6 + text.length() * 0.055, 2.4, 7.0)))
	_bubble(who, String(sp["name"]), text, sp["col"], dur, bool(opts.get("far", false)) or dist > 9.0)
	var vp := G67Voice.path(line)
	if vp != "":
		var ap := AudioStreamPlayer3D.new()
		ap.stream = load(vp)
		ap.bus = golda.game.bark_b.bus
		ap.max_distance = 30.0
		ap.unit_size = 6.0
		add_child(ap)
		ap.global_position = who.global_position + Vector3(0, 1.6, 0)
		ap.finished.connect(ap.queue_free)
		ap.play()
	log.append([clock, code, line])
	if log.size() > 80:
		log.pop_front()
	return true

## Реплика Пахана на странность двора: голос и подпись через путь приквела, не чаще раза в 40 с
func pahan_say(kind: String, force := false) -> bool:
	if not can_talk() and not force:
		return false
	if clock - last_pahan < PAHAN_GAP and not force:
		return false
	var line := pick("pahan_" + kind, G67LifeData.PAHAN.get(kind, []))
	if line == "":
		return false
	last_pahan = clock
	golda._ev_say(line)
	log.append([clock, "V", line])
	return true

func _bubble(who: Node3D, nm: String, text: String, col: Color, dur: float, small: bool) -> void:
	for b in bubbles.duplicate():
		if b["who"] == who:
			(b["node"] as Node3D).queue_free()
			bubbles.erase(b)
	var root := Node3D.new()
	add_child(root)
	var k := 0.75 if small else 1.0
	var lines := clampi(int(ceil(float(text.length()) / 42.0)), 1, 3)
	var bh := (0.1 + 0.095 * float(lines)) * k
	var back := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.2 * k, bh)
	back.mesh = qm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.03, 0.03, 0.05, 0.72)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back.material_override = bm
	back.position = Vector3(0, 0.0, -0.01)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(back)
	var nl := Label3D.new()
	nl.text = nm
	nl.modulate = col
	nl.font_size = 30
	nl.pixel_size = 0.0021 * k
	nl.outline_size = 6
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.position = Vector3(0, bh * 0.5 + 0.05 * k, 0)
	root.add_child(nl)
	var tl := Label3D.new()
	tl.text = text
	tl.font_size = 40
	tl.pixel_size = 0.0021 * k
	tl.outline_size = 6
	tl.width = 1000.0
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tl.position = Vector3(0, 0.0, 0)
	root.add_child(tl)
	bubbles.append({"who": who, "node": root, "t": 0.0, "dur": dur, "h": 2.15 if who.get("h_top") == null else float(who.get("h_top"))})

func _process(dt: float) -> void:
	clock += dt
	var pl: Node3D = golda.game.player if golda != null and golda.game != null else null
	for b in bubbles.duplicate():
		var who = b["who"]
		var n = b["node"]
		b["t"] = float(b["t"]) + dt
		if not is_instance_valid(who) or not is_instance_valid(n) or float(b["t"]) > float(b["dur"]) or not can_keep():
			if is_instance_valid(n):
				n.queue_free()
			bubbles.erase(b)
			continue
		var hh: float = 2.1 if not who.has_meta("bubble_h") else float(who.get_meta("bubble_h"))
		n.global_position = who.global_position + Vector3(0, hh, 0)
		var a := clampf(minf(float(b["t"]) / 0.2, (float(b["dur"]) - float(b["t"])) / 0.5), 0.0, 1.0)
		for c in n.get_children():
			if c is Label3D:
				(c as Label3D).modulate.a = a
			elif c is MeshInstance3D:
				(c.material_override as StandardMaterial3D).albedo_color.a = 0.72 * a
		n.visible = pl == null or n.global_position.distance_to(pl.global_position) <= MAX_DIST + 2.0

func can_keep() -> bool:
	var g = golda.game
	return golda.clip == null and g.mode != "dlg" and not golda.talk_on and golda.scene_t < 0.0 and golda.room_state != "boss"
