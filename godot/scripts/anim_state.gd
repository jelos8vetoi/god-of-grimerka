## Состояния и переходы анимации одного персонажа (этап 03). Контроллер (player.gd, companion.gd) каждый кадр
## сообщает, что происходит с телом — скорость, куда хочет повернуться, на земле ли, — а AnimState решает,
## какой клип играть и как в него перейти: старт, бег, остановка, поворот на месте, прыжок, падение, приземление.
## Удары и реакции идут через action(): пока действие держит тело, перемещение его не перебивает.
##
## Профиль персонажа (PahanMoves.PROFILE, MadkMoves.PROFILE) задаёт характер: у тяжёлого Пахана долгий разгон
## и торможение с волочащимся балоном, у madk1d — короткие и резкие. Клипы шага проигрываются со скоростью,
## подогнанной под реальную скорость тела по длине шага в самом клипе (stride) — стопы не скользят.
## Root motion: у клипа может быть ключ "root" — [[доля, вперёд м, вверх м, вбок м], …] — и "spin" (оборотов за клип,
## окно "spin_win": [от, до]); контроллер забирает смещение за кадр через root_step().
class_name AnimState
extends RefCounted

signal changed(from: String, to: String)

var rig: Rig
var defs: Dictionary          # описания клипов (для root motion и spin)
var prof: Dictionary
var state := "idle"           # idle, start, move, stop, turn, jump, fall, land, action, external
var t := 0.0
var hold := 0.0               # сколько ещё действие или переходный клип держит тело
var gait := ""                # walk / run / sprint
var last_speed := 0.0
var my_clip := ""             # клип, поставленный этим автоматом (иначе клипом рулит контроллер напрямую)
var root_clip := ""
var root_prev := Vector3.ZERO
var spin_prev := 0.0
var stride_cache := {}
var turn_sign := 0.0

func _init(r: Rig, poses: Dictionary, profile: Dictionary) -> void:
	rig = r
	defs = poses
	prof = profile

func _go(to: String) -> void:
	if to == state:
		return
	var from := state
	state = to
	t = 0.0
	changed.emit(from, to)

## имя клипа для роли с учётом профиля (start → StartRun у этого персонажа)
func clip_for(role: String) -> String:
	var roles: Dictionary = prof.get("roles", {})
	return rig.role_clip(String(roles.get(role, role)))

func _blend(to_role: String) -> float:
	var b: Dictionary = prof.get("blend", {})
	return float(b.get(state + ">" + to_role, b.get(to_role, 0.18)))

func _play(role: String, speed := 1.0) -> void:
	var nm := clip_for(role)
	if nm == "":
		return
	rig.play(nm, _blend(role), speed)
	my_clip = nm

func _play_for(role: String, dur: float) -> void:
	var nm := clip_for(role)
	if nm == "":
		return
	rig.play_for(nm, dur, _blend(role))
	my_clip = nm
	_root_start(nm)

## Удар, реакция, особый приём: клип роли за dur секунд; тело занято hold секунд (по умолчанию — весь клип).
func action(role: String, dur: float, hold_s := -1.0) -> void:
	_play_for(role, dur)
	hold = dur if hold_s < 0.0 else hold_s
	_go("action")

func busy() -> bool:
	return hold > 0.0 and state in ["action", "land", "start", "stop", "turn", "jump"]

## Прыжок: клип отталкивания; дальше состояние ведёт физика (вертикальная скорость и пол).
func jump() -> void:
	_play_for("jump", float(prof.get("jump_t", 0.3)))
	hold = float(prof.get("jump_t", 0.3))
	_go("jump")

## Каждый кадр. speed — горизонтальная скорость тела, м/с; turn — на сколько тело хочет довернуться (рад, + влево);
## floor — стоит ли на земле; vy — вертикальная скорость; combat — враги рядом; sprint — держит рывок.
func tick(dt: float, speed: float, turn: float, floor: bool, vy: float, combat := false, sprint := false) -> void:
	t += dt
	hold = max(0.0, hold - dt)
	if my_clip != "" and rig.cur != my_clip:
		_go("external")             # клип поставил контроллер напрямую (старый код ударов): переходы — с чистого листа
		my_clip = ""
	# ---- в воздухе ----
	if not floor:
		if state == "jump" and hold > 0.0:
			return
		if state != "fall" and (vy < -1.0 or state == "jump") and state != "action":
			_play("fall")
			_go("fall")
		return
	if state in ["fall", "jump"]:
		var lt: float = prof.get("land_t", 0.4)
		_play_for("land", lt)
		hold = float(prof.get("land_lock", lt * 0.6))
		_go("land")
		return
	if state in ["action", "land"] and hold > 0.0:
		return
	# ---- на земле ----
	var moving := speed > float(prof.get("move_min", 0.35))
	if moving:
		if state in ["idle", "turn", "external", "action", "land"] and last_speed < float(prof.get("move_min", 0.35)) and state != "external":
			_play_for("start", float(prof.get("start_t", 0.25)))
			hold = float(prof.get("start_t", 0.25)) * 0.85
			_go("start")
		elif state == "start" and hold > 0.0:
			pass
		else:
			var g := "run"
			if sprint or speed > float(prof.get("sprint_v", 99.0)):
				g = "sprint"
			elif speed < float(prof.get("walk_v", 0.0)):
				g = "walk"
			var nm := clip_for(g)
			if nm != "":
				var sync: float = speed * rig.clip_len(nm) / max(0.05, stride(nm))
				rig.play(nm, _blend(g) if gait != g or state != "move" else 0.0)
				# скорость круга шага — по реальной скорости тела (rig.play сбрасывает speed_scale у других клипов)
				rig.player.speed_scale = clampf(sync, 0.35, 2.4)
				my_clip = nm
			gait = g
			_go("move")
	else:
		if state == "move" and last_speed > float(prof.get("stop_min", 2.5)):
			_play_for("stop", float(prof.get("stop_t", 0.35)))
			hold = float(prof.get("stop_t", 0.35)) * 0.8
			_go("stop")
		elif state in ["stop", "turn"] and hold > 0.0:
			pass
		elif abs(turn) > float(prof.get("turn_min", 1.1)) and state != "turn":
			turn_sign = signf(turn)
			_play_for("turn_l" if turn > 0.0 else "turn_r", float(prof.get("turn_t", 0.4)))
			hold = float(prof.get("turn_t", 0.4)) * 0.8
			_go("turn")
		else:
			_play("combat_idle" if combat else "idle")
			_go("idle")
	last_speed = speed

## Шаг в клипе: сколько метров тело проходит за один круг, если опорная стопа стоит на месте.
## Считается по самому клипу (опорная — та, что ниже), один раз на клип.
func stride(nm: String) -> float:
	if stride_cache.has(nm):
		return stride_cache[nm]
	var anim: Animation = rig.player.get_animation("g/" + nm)
	var tracks := {}
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			var bn := String(anim.track_get_path(i).get_concatenated_subnames())
			tracks[rig.skel.find_bone(bn)] = i
	var feet := [rig.bone["rfoot"], rig.bone["lfoot"]]
	var n := 48
	var total := 0.0
	var prev := {}
	var scale: float = rig.model.scale.x
	for s in n + 1:
		var tm := anim.length * s / n
		var rots: Array = rig.rest_rot.duplicate()
		for b in tracks:
			rots[b] = anim.rotation_track_interpolate(tracks[b], tm)
		var pos := {}
		for f in feet:
			pos[f] = rig.skel_xf * (rig._chain(rots, f)[1] as Vector3)
		var low: int = feet[0] if (pos[feet[0]] as Vector3).y < (pos[feet[1]] as Vector3).y else feet[1]
		if prev.has(low):
			# опорная стопа уезжает назад относительно тела — ровно на столько тело проходит вперёд
			total += max(0.0, (prev[low] as Vector3).z - (pos[low] as Vector3).z)
		prev = pos
	var st: float = max(0.05, total * scale)
	stride_cache[nm] = st
	return st

func _root_start(nm: String) -> void:
	root_clip = nm if (defs.get(nm, {}) as Dictionary).has("root") or (defs.get(nm, {}) as Dictionary).has("spin") else ""
	root_prev = Vector3.ZERO
	spin_prev = 0.0

static func _root_at(keys: Array, k: float) -> Vector3:
	var i := 0
	while i < keys.size() - 2 and k > float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]
	var b: Array = keys[min(i + 1, keys.size() - 1)]
	var w := clampf((k - float(a[0])) / max(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	var va := Vector3(a[3] if a.size() > 3 else 0.0, a[2], a[1])
	var vb := Vector3(b[3] if b.size() > 3 else 0.0, b[2], b[1])
	return va.lerp(vb, w)

## Смещение тела за кадр от root motion в осях персонажа (x — влево, y — вверх, z — вперёд) и доворот (рад).
## Пусто, когда клип без "root"/"spin" или его уже сменили.
func root_step() -> Array:
	if root_clip == "" or rig.cur != root_clip:
		root_clip = ""
		return []
	var d: Dictionary = defs[root_clip]
	var k := rig.clip_frac()
	var p := Vector3.ZERO
	if d.has("root"):
		p = _root_at(d["root"], k)
	var sp := 0.0
	if d.has("spin"):
		var win: Array = d.get("spin_win", [0.0, 1.0])
		sp = TAU * float(d["spin"]) * smoothstep(float(win[0]), float(win[1]), k)
	var out := [p - root_prev, sp - spin_prev]
	root_prev = p
	spin_prev = sp
	return out
