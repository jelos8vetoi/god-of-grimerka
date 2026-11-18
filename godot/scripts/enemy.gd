## Враги и боссы. Обычные: бот, клиппер (катана), хейтер (посох), тролль, удалённый трек, юрист, модератор (щит), накрутчик.
## Боссы — по данным сюжета (story.json → BOSS): фазы по здоровью, атаки slam/fan/charge/leap/burst/rain/spiral/homing/mines/summon/tp/wall/beam/shock.
extends CharacterBody3D

const KINDS := {
	"bot": {"model": "bot", "height": 1.7, "hp": 60.0, "speed": 3.1, "range": 1.8, "wind": 0.55, "dmg": 9.0, "clip": "Punch", "cool": 1.6, "xp": 10},
	"clipper": {"model": "clipper", "height": 1.8, "hp": 75.0, "speed": 4.4, "range": 2.2, "wind": 0.4, "dmg": 14.0, "clip": "Slash", "cool": 1.4, "lunge": 7.0, "xp": 22},
	"hater": {"model": "hater", "height": 1.75, "hp": 50.0, "speed": 2.6, "range": 11.0, "keep": 7.5, "wind": 0.7, "dmg": 10.0, "clip": "Cast", "cool": 2.4, "ranged": true, "xp": 18},
	"troll": {"model": "bot", "height": 2.5, "hp": 230.0, "speed": 2.0, "range": 2.6, "wind": 0.95, "dmg": 22.0, "clip": "Punch", "cool": 2.2, "slam": 3.2, "tint": Color("6aa544"), "xp": 45},
	"ghost": {"model": "hater", "height": 1.75, "hp": 85.0, "speed": 2.8, "range": 2.0, "wind": 0.5, "dmg": 15.0, "clip": "Cast", "cool": 2.0, "tele": true, "tint": Color("b79cff"), "alpha": 0.6, "emit": 0.4, "xp": 30},
	"lawyer": {"model": "clipper", "height": 1.8, "hp": 100.0, "speed": 2.4, "range": 12.0, "keep": 8.0, "wind": 0.8, "dmg": 12.0, "clip": "Punch", "cool": 2.6, "ranged": true, "homing": true, "noweapon": true, "tint": Color("e4e4ee"), "xp": 30},
	"mod": {"model": "bot", "height": 1.85, "hp": 120.0, "speed": 3.0, "range": 1.9, "wind": 0.5, "dmg": 13.0, "clip": "Punch", "cool": 1.6, "shield": true, "tint": Color("7fa8ff"), "xp": 32},
	"farmer": {"model": "hater", "height": 1.75, "hp": 130.0, "speed": 2.6, "range": 12.0, "keep": 9.0, "wind": 1.0, "dmg": 0.0, "clip": "Cast", "cool": 4.5, "summoner": true, "tint": Color("ffd23b"), "xp": 40},
	# двойник призрака: выглядит как босс, рассыпается с одного удара
	"clone": {"model": "pahan", "height": 2.1, "hp": 1.0, "speed": 4.2, "range": 2.4, "wind": 0.55, "dmg": 12.0, "clip": "Light1", "cool": 1.3, "tint": Color("ff8080"), "alpha": 0.45, "emit": 0.3, "xp": 0},
	# копия призрака (EnemyAI «КОПИИ»): почти прозрачная, без полоски здоровья в цвете, рассыпается с одного удара
	"phantom": {"model": "hater", "height": 1.75, "hp": 1.0, "speed": 3.2, "range": 2.0, "wind": 0.6, "dmg": 6.0, "clip": "Cast", "cool": 1.8, "tint": Color("dcd6ff"), "alpha": 0.3, "emit": 0.5, "xp": 0, "noweapon": true},
}
const BOSS_LOOK := {
	"courier": {"model": "drey", "scale": 1.3, "own": true}, "golem": {"model": "bot", "scale": 1.9}, "hype": {"model": "hater", "scale": 1.35},
	"dislike": {"model": "bot", "scale": 1.75}, "major": {"model": "clipper", "scale": 1.4}, "strike": {"model": "hater", "scale": 1.45},
	"botlord": {"model": "bot", "scale": 1.6}, "ghostv": {"model": "pahan", "scale": 1.2, "alpha": 0.85, "emit": 0.12}, "algo": {"model": "hater", "scale": 2.0, "emit": 0.1},
}

var game
var kind := "bot"
var boss_id := ""
var boss: Dictionary = {}
var cfg: Dictionary
var rig: Rig
var body: Node3D
var hp := 1.0
var max_hp := 1.0
var state := "spawn"
var t := 0.0
var cool := 1.0
var stun_t := 0.0
var face := 0.0
var kb := Vector3.ZERO
var ring: MeshInstance3D
var tell: MeshInstance3D      # предупреждение на земле: форма — ровно зона удара (fx.tell_shape, _tell_start)
var hp_bar: Sprite3D
var bar_img: Image
var height := 1.7
var phase := 0
var move := ""
var move_n := 0
var charge_dir := Vector3.ZERO
var radius := 0.36
var age := 0.0
# отклик на удар
var flash_on := false
var flash_until := 0.0
var hit_clock := -9.0
var hit_dir := Vector3.FORWARD
var sq_tw: Tween
var fly := false            # убитый летит по дуге
var fly_v := Vector3.ZERO
var bounces := 0
var trail: Trail
var spiked := false         # сбит в землю ударом сверху: приземлится с грохотом
var special_cd := 3.5      # до особого приёма босса
var sp_events: Array = []  # [время, что сделать] внутри приёма
var sp_dur := 0.0
var shield_n: Array = []   # призванные боты, которые держат щит
var shield_fx: MeshInstance3D
var glint := false          # предупреждающая вспышка перед ударом уже была
var stars: Node3D           # звёздочки над оглушённым
var poise := 60.0           # равновесие: удары снимают его (HitInfo.stagger); кончилось — враг сбит (оглушён), даже в замахе
var poise_max := 60.0
var air_hits := 0           # ударов за этот полёт: каждый следующий подбрасывает слабее (нет вечного жонглирования)
var air_tags := 0           # передач AIR TAG за этот полёт (tagteam.AIR_TAGS_MAX)
var poise_base := -1.0       # равновесие до сломов: частые сломы его повышают (нет бесконечного оглушения)
var break_n := 0
var st_bar: Sprite3D         # полоска равновесия под полоской здоровья: видна, пока его снимают
var st_img: Image
var st_k := -1.0
var poise_t := 9.0          # сколько секунд назад по равновесию били: через 2 с оно восстанавливается
var slow_t := 0.0           # замедление (облит водой и т. п.), с
## Реакции на удары (этап 09): масса делит отбрасывание и снятое равновесие, броня гасит лёгкие удары,
## launch — можно ли подбросить, down — можно ли сбить с ног подсечкой. Боссы — отдельной строкой.
const REACT := {
	"bot": {"mass": 1.0}, "clipper": {"mass": 0.9}, "hater": {"mass": 0.75}, "lawyer": {"mass": 1.0}, "farmer": {"mass": 0.85}, "clone": {"mass": 0.8},
	"troll": {"mass": 2.6, "armor": 14.0, "launch": false, "down": false},      # тяжёлый: лёгкие удары не замечает, не подбрасывается
	"ghost": {"mass": 0.6, "down": false},                                       # бесплотный: с ног не сбить, зато отлетает далеко
	"mod": {"mass": 1.35, "armor": 8.0},                                         # в броне: лёгкий удар его не сбивает
	"boss": {"mass": 3.0, "armor": 10.0, "launch": false, "down": false},
}
var tilt := Vector2.ZERO      # наклон от удара: x — вперёд-назад, y — вбок (рад); гаснет с покачиванием
var tilt_t := 9.0
var hit_side := ""           # откуда пришёл последний удар: front, back, left, right
var wall_cd := 0.0
var wall_hits := 0           # для проверок: сколько раз врага впечатало в стену
var react := "normal"       # последняя реакция: none, hit, stagger, heavy_stagger, knockback, knockdown, airborne
var hurt_len := 0.35        # сколько длится текущая реакция «получил удар»
var no_flinch := false      # броня: этот удар не сбивает состояние
var weak_t := 0.0           # босс «открыт»: окно после срыва равновесия, урон по нему выше
var executed := false       # убит добиванием
var exec_mark: Label3D
var slow_k := 1.0           # множитель скорости на время замедления
# ---- ИИ (enemy_ai.gd, boss_moves.gd) ----
var role := "attack"        # роль в группе: attack, flank, hold, guard, ranged (EnemyAI.squad)
var flank_side := 1.0
var guard_of = null         # кого прикрывает MOD
var amove: Dictionary = {}  # текущий приём моба (EnemyAI.MOVES); пусто — старый удар типа
var move_cd := {}           # приём → когда снова можно (по age)
var rec_len := -1.0         # отдых после приёма, с (-1 — как раньше)
var buff_t := 0.0           # усилен фермером / боссом: быстрее, урон ×1,25
var ward_t := 0.0           # защита (ритуал, стойка): урон по нему ×0,4
var hide_t := 0.0           # исчез перед атакой (призрак)
var riposte_t := 0.0        # MOD принял удар на щит — окно ответа
var spawned: Array = []     # кого призвал (предел — EnemyAI.TUNE.summon_cap / BossMoves._call)
var summoned_by = null
var charge_dmg := -1.0      # рывок: урон, ширина задевания, длительность, скорость (-1 — как у story-рывка)
var charge_r := -1.0
var charge_len := 0.8
var charge_v := 13.0
var counter_at := 0.0       # босс: когда снова можно приём против поведения игрока
var combo_left := 0         # босс: сколько приёмов подряд ещё (растёт с фазой)
var moves_used := {}        # для проверок: какие приёмы делал
var tell_until := -1.0      # метка в приёме босса (полоса рывка) видна до этого age
var tell_sec := 0.5
var train_guard := false      # учебная цель обучения: не умирает, пока упражнение не сделано (tutorial.gd)
var train_attack := false     # учебная цель для упражнений защиты: замахивается чаще
var train_home := Vector3.ZERO      # тренировочная арена: место цели
var train_still := false     # цель арены стоит на своём месте (бить может, ходить — нет)
var train_leash := 0.0       # босс арены не уходит от своей зоны дальше этого
var hit_id := ""             # атака, которая сейчас бьёт (take_hit_info) — для записи урона в проверке
var born_at := Vector3.INF   # где враг был в _ready (там рисуется портал появления) — для проверки

func _ready() -> void:
	if boss_id != "":
		_setup_boss()
	else:
		cfg = KINDS[kind].duplicate()
		max_hp = float(Balance.MOB_HP.get(kind, cfg["hp"])) * float(game.diff_hp)      # баланс здоровья типа — balance.gd
	hp = max_hp
	height = cfg["height"]
	cool = randf_range(0.6, 1.6)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	radius = 0.36 * height / 1.7
	cap.radius = radius
	cap.height = max(height * 0.9, radius * 2.0 + 0.1)
	col.shape = cap
	col.position.y = cap.height / 2.0
	add_child(col)
	body = Node3D.new()
	add_child(body)
	rig = Rig.new()
	body.add_child(rig)
	var m: String = cfg["model"]
	var poses: Dictionary
	if m == "pahan":
		poses = Poses.pahan_armed()
	elif m == "hater" and not cfg.get("noweapon", false):
		poses = Poses.hater()
	elif m == "clipper" and not cfg.get("noweapon", false):
		poses = Poses.clipper()
	else:
		poses = Poses.bot()
	rig.setup("res://assets/models/" + m + ".glb", height, poses, boss_id != "", -1.0 if m == "pahan" else 1.0, m + ("_n" if cfg.get("noweapon", false) else ""))
	if not cfg.get("own", false) and (cfg.has("tint") or cfg.has("alpha") or cfg.has("emit")):
		_tint(cfg.get("tint", Color.WHITE), cfg.get("alpha", 1.0), cfg.get("emit", 0.0))
	if not cfg.get("noweapon", false):
		if m == "hater":
			rig.attach("res://assets/models/staff.glb", "r", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.45, "length": 1.05, "shadow": false})
		elif m == "clipper":
			rig.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0, "shadow": false})
			rig.attach("res://assets/models/katana.glb", "r", {"bone": "hips", "axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02], "shadow": false})
		elif m == "pahan":
			rig.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	if rig.weapon != null and (m == "clipper" or m == "pahan"):
		trail = Trail.new()
		rig.add_child(trail)
		trail.setup(rig, Color(0.55, 0.9, 1.0) if m == "clipper" else Color(0.75, 0.55, 1.0), 0.3)
		trail.min_speed = 6.0
	rig.play_for("Spawn", 1.0, 0.0)
	# кольцо замаха у ног: текстурное, растёт, пока враг заносит удар
	ring = game.fx.flat(self, "circle_03", Color(1.0, 0.16, 0.1, 0.9), 2.0 * height / 1.7, 0.05, false)
	ring.visible = false
	tell = game.fx.tell_node(self)
	if boss_id == "":
		bar_img = Image.create(64, 8, false, Image.FORMAT_RGBA8)
		hp_bar = Sprite3D.new()
		hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hp_bar.pixel_size = 0.012
		hp_bar.position.y = height + 0.35
		hp_bar.no_depth_test = true
		hp_bar.visible = false
		add_child(hp_bar)
		st_img = Image.create(64, 4, false, Image.FORMAT_RGBA8)
		st_bar = Sprite3D.new()
		st_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		st_bar.pixel_size = 0.012
		st_bar.position.y = height + 0.25
		st_bar.no_depth_test = true
		st_bar.visible = false
		add_child(st_bar)
	born_at = global_position
	game.main.sfx("sfx_spawn", -10.0)
	game.fx.dust(global_position + Vector3(0, 0.15, 0), 8, game.fx.DUST, 0.9)
	game.fx.portal(global_position, 2.8 * height / 1.7, Color(1.0, 0.25, 0.2, 0.75), 1.0)
	if boss_id != "":
		game.fx.lightning(global_position, height * 2.4, Color(boss["c"]))
		game.fx.portal(global_position, 4.5 * height / 1.7, Color(boss["c"]), 1.4, "magic_02")

func _setup_boss() -> void:
	boss = (game.story["BOSS"][boss_id] as Dictionary).duplicate()
	boss["phases"] = BossMoves.phases_for(boss_id, boss["phases"])     # фазы из story.json + новые приёмы (boss_moves.gd)
	var look: Dictionary = BOSS_LOOK.get(boss_id, {"model": "bot", "scale": 1.5})
	cfg = {"model": look["model"], "height": 1.75 * float(look["scale"]), "speed": float(boss["spd"]) / 40.0, "range": 2.4 * float(look["scale"]), "wind": 0.6,
		"dmg": float(boss["dmg"]), "clip": "Slash" if look["model"] == "clipper" else ("Cast" if look["model"] == "hater" else "Punch"), "cool": float(boss.get("gap", 1.5)),
		"tint": Color(boss["c"]), "xp": boss["xp"]}
	if look.has("alpha"):
		cfg["alpha"] = look["alpha"]
	cfg["emit"] = look.get("emit", 0.04)
	cfg["own"] = look.get("own", false)   # своя модель босса: не перекрашиваем
	if look["model"] == "pahan":
		cfg["clip"] = "Light1"
	max_hp = float(boss["hp"]) * Balance.BOSS_HP * float(game.diff_hp)       # было 0,75 — фазы проскакивали (balance.gd)
	poise_max = 200.0      # босса сбить труднее: нужна серия тяжёлых
	poise = poise_max

func _tint(c: Color, alpha: float, emit: float) -> void:
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = Color.WHITE.lerp(c, 0.38)
			if alpha < 1.0:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mat.albedo_color.a = alpha
			if emit > 0.0:
				mat.emission_enabled = true
				mat.emission = c
				mat.emission_energy_multiplier = emit
			inst.set_surface_override_material(s, mat)

func alive() -> bool:
	return state != "dead" and state != "spawn"

func _update_bar() -> void:
	if boss_id != "":
		return
	var k: float = clamp(hp / max_hp, 0.0, 1.0)
	bar_img.fill(Color(0, 0, 0, 0.7))
	bar_img.fill_rect(Rect2i(1, 1, int(62 * k), 6), Color(1, 0.25, 0.2) if stun_t <= 0.0 else Color(1, 0.85, 0.2))
	hp_bar.texture = ImageTexture.create_from_image(bar_img)
	hp_bar.visible = k < 1.0 and state != "dead"

func _physics_process(dt: float) -> void:
	t += dt
	age += dt
	poise_t += dt
	if poise_t > 2.0:
		poise = min(poise_max, poise + poise_max * 0.5 * dt)
	if state != "air" and (air_hits > 0 or air_tags > 0):
		air_hits = 0                 # приземлился: следующий полёт — заново
		air_tags = 0
	if poise_t > 5.0 and break_n > 0 and boss_id == "":
		break_n = 0                  # давно не сбивали: сопротивление спадает
		poise_max = poise_base
		poise = min(poise, poise_max)
	if st_bar != null:
		var show: bool = poise_t < 2.6 and poise < poise_max - 0.5 and state != "dead"
		var k: float = clampf(poise / max(1.0, poise_max), 0.0, 1.0)
		if show and abs(k - st_k) > 0.02:
			st_k = k
			st_img.fill(Color(0, 0, 0, 0.6))
			st_img.fill_rect(Rect2i(1, 1, int(62 * k), 2), Color(1.0, 0.85, 0.3) if break_n == 0 else Color(1.0, 0.55, 0.25))
			st_bar.texture = ImageTexture.create_from_image(st_img)
		st_bar.visible = show
	slow_t = max(0.0, slow_t - dt)
	weak_t = max(0.0, weak_t - dt)
	buff_t = max(0.0, buff_t - dt)
	ward_t = max(0.0, ward_t - dt)
	riposte_t = max(0.0, riposte_t - dt)
	if hide_t > 0.0:
		hide_t -= dt
		rig.visible = hide_t <= 0.0
	var p = game.player
	var to: Vector3 = p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir: Vector3 = to / max(dist, 0.001)
	# наклон от удара гаснет с одним покачиванием обратно
	if tilt_t < 1.0:
		tilt_t += dt
		var tk: float = exp(-6.0 * tilt_t) * cos(tilt_t * 11.0)
		rig.rotation.x = tilt.x * tk
		rig.rotation.z = tilt.y * tk
		if tilt_t >= 1.0:
			rig.rotation.x = 0.0
			rig.rotation.z = 0.0
	# впечатало в стену: отброшенный враг долетел до края арены
	wall_cd = max(0.0, wall_cd - dt)
	if wall_cd <= 0.0 and boss_id == "" and state != "dead" and kb.length() > 6.5 and (is_on_wall() or not game.in_arena(global_position + kb.normalized() * 0.5, radius)):
		_wall_hit()
	velocity.x = kb.x
	velocity.z = kb.z
	if state != "air":
		kb = kb.move_toward(Vector3.ZERO, (9.0 if state == "hurt" and react == "knockback" else 22.0) * dt)
	if trail:
		trail.enabled = state == "wind" or (state == "recover" and t < 0.3)
	if game.paused_story() and state != "dead":
		velocity = Vector3.ZERO
		rig.play("Idle", 0.3)
		move_and_slide()
		return
	match state:
		"spawn":
			if t > 1.0:
				state = "chase"
				t = 0.0
		"chase":
			cool -= dt
			if train_attack and cool > 1.3:
				cool = 1.3                  # учебная цель упражнений защиты: замах — регулярно
			if boss_id != "":
				special_cd -= dt
			face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * dt))
			var want: float = cfg.get("keep", 0.0)
			var mv := Vector3.ZERO
			if cfg.has("ranged") or cfg.has("summoner"):
				if dist > want + 1.5:
					mv = dir
				elif dist < want - 1.5:
					mv = -dir
			elif dist > float(cfg["range"]) * 0.85:
				mv = dir
			if boss_id == "" and EnemyAI.MOVES.has(kind):
				mv = EnemyAI.steer(self, dist, dir)        # роль в группе: фланг, ожидание, прикрытие, дистанция стрелка
			for o in game.enemies:
				if o != self and is_instance_valid(o) and o.state != "dead":
					var d: Vector3 = global_position - o.global_position
					d.y = 0
					var sep: float = radius + o.radius + 0.4
					if d.length() < sep and d.length() > 0.01:
						mv += d.normalized() * (sep - d.length()) * 1.5
			if train_still or train_leash > 0.0:
				var hm: Vector3 = train_home - global_position
				hm.y = 0.0
				if train_still:
					mv = hm.normalized() if hm.length() > 0.4 else Vector3.ZERO
				elif hm.length() > train_leash:
					mv = hm.normalized()
			if p.state == "dead":
				mv = Vector3.ZERO
			var wet: float = (slow_k if slow_t > 0.0 else 1.0) * (1.25 if buff_t > 0.0 else 1.0)       # облит водой — медленнее, усилен — быстрее
			velocity.x += mv.x * float(cfg["speed"]) * wet
			velocity.z += mv.z * float(cfg["speed"]) * wet
			if mv.length() > 0.2:
				rig.play("Run", 0.2, float(cfg["speed"]) / 3.5)
			else:
				rig.play("Idle", 0.3)
			if riposte_t > 0.0 and dist < 2.8 and p.state != "dead" and EnemyAI.MOVES.has(kind) and EnemyAI.MOVES[kind].has("riposte") and game.melee_attackers() < int(EnemyAI.TUNE["tokens"]):
				riposte_t = 0.0
				_start_move(EnemyAI.move_of(self, "riposte"))     # MOD: ответ сразу после удара в щит
			elif cool <= 0.0 and p.state != "dead" and boss_id == "" and EnemyAI.MOVES.has(kind):
				var pick: Dictionary = EnemyAI.pick(self, dist) if EnemyAI.may_attack(self, dist) else {}
				if pick.is_empty():
					cool = randf_range(0.2, 0.45)
				else:
					_start_move(pick)
			elif cool <= 0.0 and p.state != "dead":
				if boss_id != "":
					_boss_pick(dist)
				elif cfg.has("tele") and dist > 7.0:
					_teleport_near(p.global_position, 1.8)
					cool = 0.4
				elif dist < float(cfg["range"]) or cfg.has("summoner"):
					# в ближнем бою одновременно замахиваются не больше двоих — иначе героя держат в вечном оглушении
					if not cfg.has("ranged") and not cfg.has("summoner") and game.melee_attackers() >= 2:
						cool = randf_range(0.25, 0.6)
					else:
						_wind(String(cfg["clip"]), float(cfg["wind"]))
		"wind":
			face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-6.0 * dt))
			var k: float = t / float(cfg["wind"])
			ring.scale = Vector3.ONE * 2.0 * (1.0 + k * 0.4) * (height / 1.7)
			if tell != null and tell.visible:
				_tell_tick(k)
			if not glint and k > 0.66:
				# блик перед самым ударом — по нему ставят блок и перекат
				glint = true
				game.fx.flash(global_position + Vector3(0, height * 0.82, 0) + Vector3(sin(face), 0, cos(face)) * radius, 0.9 * height / 1.7, Color(1.0, 0.3, 0.2), "star_07", 0.2)
			if k >= 1.0:
				ring.visible = false
				_tell_end()
				var nxt: Dictionary = {}
				if boss_id != "":
					_boss_strike(dist, dir)
				elif not amove.is_empty():
					nxt = EnemyAI.strike(self, amove, dist, dir)
					rec_len = float(amove.get("rec", -1.0))
				else:
					_strike(dist, dir)
				if not nxt.is_empty() and state == "wind" and alive():
					_start_move(nxt)            # связка: следующий приём со своим (коротким) замахом и меткой
				else:
					if state == "wind":
						state = "recover"
					t = 0.0
		"charge":
			velocity.x += charge_dir.x * charge_v
			velocity.z += charge_dir.z * charge_v
			face = atan2(charge_dir.x, charge_dir.z)
			rig.play("Run", 0.1, 2.5)
			var cr: float = charge_r if charge_r > 0.0 else float(cfg["range"]) * 0.7
			if dist < cr and p.inv <= 0.0:
				p.take_damage(charge_dmg if charge_dmg >= 0.0 else float(cfg["dmg"]) * 1.2, global_position, self)
				state = "recover"
				t = 0.0
			if t > charge_len or not game.in_arena(global_position + charge_dir, 0.5):
				state = "recover"
				t = 0.0
		"special":
			while not sp_events.is_empty() and t >= float(sp_events[0][0]):
				var ev: Array = sp_events.pop_front()
				(ev[1] as Callable).call()
			if boss_id != "hype":
				face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-5.0 * dt))
			if t > sp_dur:
				state = "recover"
				t = 0.0
		"recover":
			if cfg.has("lunge") and t < 0.15:
				velocity += Vector3(sin(face), 0, cos(face)) * float(cfg["lunge"])
			var rl: float = rec_len if rec_len >= 0.0 else float(cfg["wind"]) * (0.6 if boss_id != "" else 1.0)
			if t > rl:
				state = "chase"
				rec_len = -1.0
				amove = {}
				charge_dmg = -1.0
				charge_r = -1.0
				charge_len = 0.8
				charge_v = 13.0
				cool = float(cfg["cool"]) * randf_range(0.8, 1.25) * float(EnemyAI.TUNE["cool"])
				if boss_id != "":
					cool *= 1.0 - 0.12 * phase          # с фазой решает быстрее
					if combo_left > 0:
						combo_left -= 1
						cool = 0.25                     # связка: следующий приём почти сразу (после отдыха)
				elif hp < max_hp * float(EnemyAI.TUNE["low_hp"]) and kind in ["bot", "clipper", "ghost"]:
					cool *= 0.7                         # мало здоровья — злее
		"hurt":
			if t > hurt_len:
				state = "chase"
				hurt_len = 0.35
				body.rotation.x = 0.0
		"stun":
			stun_t -= dt
			body.rotation.z = sin(t * 18.0) * 0.06
			if stun_t <= 0.0:
				body.rotation.z = 0.0
				state = "chase"
		"air":
			# сбит с ног: летит по дуге, пока не коснётся земли
			if t > 0.12 and is_on_floor():
				game.fx.land(global_position, 1.0)
				if spiked:
					spiked = false
					game.fx.slam(global_position, 0.8, Color(1.0, 0.8, 0.42))
					game.shake(0.3)
					game.main.sfx("sfx_boom", -4.0, 1.1)
				game.main.sfx("sfx_thud", -5.0)
				game.shake(0.1)
				kb *= 0.3
				state = "down"
				t = 0.0
				rig.play_for("GetUp", 9999.0, 0.08)
		"down":
			if t > 0.7:
				state = "getup"
				t = 0.0
				rig.play_for("GetUp", 0.55, 0.05)
		"getup":
			if t > 0.55:
				state = "chase"
				cool = max(cool, 0.5)
		"dead":
			velocity = Vector3.ZERO
			var lim: float = game.ARENA - 0.7
			if fly:
				# тело летит само, без столкновений: дуга, отскок от земли и от края арены
				fly_v.y -= 20.0 * dt
				var np := global_position + fly_v * dt
				if abs(np.x) > lim:
					np.x = clampf(np.x, -lim, lim)
					fly_v.x *= -0.35
				if abs(np.z) > lim:
					np.z = clampf(np.z, -lim, lim)
					fly_v.z *= -0.35
				if np.y <= 0.05 and fly_v.y < 0.0:
					np.y = 0.05
					game.fx.land(np, 1.2)
					game.main.sfx("sfx_thud", -3.0)
					if fly_v.y < -5.0 and bounces < 1:
						bounces += 1
						fly_v = Vector3(fly_v.x * 0.5, -fly_v.y * 0.3, fly_v.z * 0.5)
					else:
						fly = false
						kb = Vector3(fly_v.x, 0, fly_v.z) * 0.4
						t = 0.0
						rig.play_for("GetUp", 9999.0, 0.1)
				global_position = np
			else:
				var sp := global_position + Vector3(kb.x, 0, kb.z) * dt
				global_position = Vector3(clampf(sp.x, -lim, lim), global_position.y, clampf(sp.z, -lim, lim))
				if t > 2.6 and boss_id == "":
					# тело не тонет в полу, а рассыпается дымом с искрами
					game.fx.poof(global_position, height / 1.7, Color(0.85, 0.8, 0.95))
					queue_free()
			body.rotation.y = face
			return
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face

func _wind(clip: String, w: float) -> void:
	state = "wind"
	t = 0.0
	ring.visible = not _tell_start()
	glint = false
	cfg["wind"] = w
	rig.play_for(clip, w * 2.0, 0.08)

## Приём моба: замах с меткой той же формы, что удар (EnemyAI.tell_of); два удара разных врагов не совпадают по времени
func _start_move(m: Dictionary) -> void:
	amove = m
	move_cd[String(m["id"])] = age + float(m.get("cd", 0.0))
	var w: float = float(m.get("wind", cfg["wind"]))
	if String(m["act"]) in ["melee", "lunge", "slam", "charge"]:
		w = EnemyAI.stagger_wind(self, w)
	var clip: String = "Cast" if String(m["act"]) in ["shoot", "zone", "summon", "buff", "ritual", "clones", "blink", "repel"] and cfg["model"] == "hater" else String(cfg["clip"])
	_wind(clip, w)

func _teleport_near(pos: Vector3, r: float) -> void:
	var c: Color = cfg.get("tint", Color(0.7, 0.6, 1.0))
	game.fx.poof(global_position, height / 1.7, c)
	var a := randf() * TAU
	var np := pos + Vector3(cos(a), 0, sin(a)) * r
	if game.in_arena(np, 1.0):
		global_position = np
	game.fx.twirl(global_position, 3.2, c, 0.5, "twirl_03")
	game.fx.poof(global_position, height / 1.7, c)
	game.main.sfx("sfx_cast", -8.0, 1.4)

func _strike(dist: float, dir: Vector3) -> void:
	if cfg.has("summoner"):
		game.main.sfx("sfx_cast", -6.0, 0.7)
		game.fx.portal(global_position, 4.2, Color(1.0, 0.82, 0.25, 0.8), 0.9, "magic_02")
		game.fx.portal(global_position, 3.0, Color(1.0, 0.82, 0.25, 0.5), 0.9)
		for i in 2:
			game.spawn_enemy("bot", global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		return
	if cfg.has("ranged"):
		game.main.sfx("sfx_cast", -6.0)
		var wp := rig.weapon_points()
		game.fx.muzzle(wp[1] if not wp.is_empty() else global_position + Vector3(0, height * 0.75, 0) + dir * 0.6, Color(0.4, 1.0, 0.55))
		game.spawn_bolt(global_position + Vector3(0, height * 0.75, 0) + dir * 0.6, dir * 9.0, float(cfg["dmg"]), self, cfg.has("homing"))
		return
	game.main.sfx("sfx_slash" if kind == "clipper" else "sfx_swing", -6.0)
	if cfg.has("slam"):
		game.shake(0.4)
		game.fx.slam(global_position + Vector3(sin(face), 0, cos(face)) * 1.3, 1.25, Color(0.6, 1.0, 0.4))
		game.main.sfx("sfx_boom", -3.0)
		if dist < float(cfg["slam"]):
			game.player.take_damage(float(cfg["dmg"]), global_position, self)
		return
	var reach: float = float(cfg["range"]) + (1.2 if cfg.has("lunge") else 0.3)
	if dist < reach and Vector3(sin(face), 0, cos(face)).angle_to(dir) < 1.1:
		game.player.take_damage(float(cfg["dmg"]), global_position, self)

## Предупреждение по форме удара (та же зона, что проверяют _strike и _boss_strike). false — у удара своя метка
## (снаряды босса, прыжок, волна — у них свои зоны game.telegraph / expanding_ring), тогда остаётся прежнее кольцо.
var tell_r := 0.0
var tell_half := 0.0
var tell_lane := 0.0
func _tell_start() -> bool:
	if tell == null:
		return false
	var m: Dictionary = VfxProfiles.enemy_motif(self)
	var r := 0.0
	var half := 1.1
	var lane := 0.0
	if boss_id == "" and not amove.is_empty():
		var sh: Array = EnemyAI.tell_of(self, amove)
		if sh.is_empty():
			return false
		tell_r = float(sh[0])
		tell_half = float(sh[1])
		tell_lane = float(sh[2])
		game.fx.tell_shape(tell, global_position, face, tell_r, tell_half, tell_lane, int(m["pattern"]), m["main"])
		return true
	if boss_id != "":
		match move:
			"slam":
				r = float(cfg["range"]) + 1.6
				half = PI
			"charge":
				r = 10.0                     # рывок ~0,8 с; задевает, если герой ближе 0,7 дальности
				lane = float(cfg["range"]) * 0.7
			"fan":
				r = 10.0
				half = 0.5
			"shock", "leap", "burst", "spiral", "wall", "homing", "rain", "mines", "beam", "summon", "tp":
				return false
			_:
				r = float(cfg["range"]) + 0.8
				half = PI
	elif cfg.has("summoner"):
		r = 4.2
		half = PI
	elif cfg.has("ranged"):
		r = minf(float(cfg["range"]), 11.0)
		lane = 0.5
	elif cfg.has("slam"):
		r = float(cfg["slam"])
		half = PI
	else:
		r = float(cfg["range"]) + (1.2 if cfg.has("lunge") else 0.3)
		half = 1.1
	tell_r = r
	tell_half = half
	tell_lane = lane
	game.fx.tell_shape(tell, global_position, face, r, half, lane, int(m["pattern"]), m["main"])
	return true

func _tell_tick(k: float) -> void:
	# ведёт за врагом и его взглядом: зона удара считается по face в момент удара
	tell.global_transform = Transform3D(Basis(Vector3.UP, face + PI) * Basis(Vector3(1, 0, 0), -PI / 2) * Basis.from_scale(Vector3(tell_r * 2.0, tell_r * 2.0, 1.0)), Vector3(global_position.x, global_position.y + 0.06, global_position.z))
	tell.set_instance_shader_parameter("progress", k)

func _tell_end() -> void:
	if tell != null:
		tell.visible = false

# ---------------- боссы ----------------
func _boss_pick(dist: float) -> void:
	if special_cd <= 0.0:
		special_cd = randf_range(10.0, 13.0) - phase * 1.5
		_special()
		return
	var counter := BossMoves.adapt(self)
	if counter != "":
		move = counter
		BossMoves.start(self, counter)
		return
	var phases: Array = boss["phases"]
	var moves: Array = phases[min(phase, phases.size() - 1)]
	move = moves[move_n % moves.size()]
	move_n += 1
	if phase >= 1 and combo_left == 0 and randf() < 0.35 + 0.2 * phase:
		combo_left = phase                    # с фазой — связки длиннее
	if BossMoves.is_new(move):
		BossMoves.start(self, move)
		return
	moves_used[move] = int(moves_used.get(move, 0)) + 1
	match move:
		"charge":
			_wind(String(cfg["clip"]), 0.55)
		"tp":
			_teleport_near(game.player.global_position, 3.5)
			cool = 0.5
		"slam", "shock":
			if dist > float(cfg["range"]) + 2.5:
				cool = 0.3
				move_n -= 1
				return
			_wind(String(cfg["clip"]), 0.75)
		"leap":
			_wind(String(cfg["clip"]), 0.6)
		_:
			_wind("Cast" if cfg["model"] == "hater" else String(cfg["clip"]), 0.65)

func _boss_strike(dist: float, dir: Vector3) -> void:
	var dmg := float(cfg["dmg"])
	var pp: Vector3 = game.player.global_position
	var from := global_position + Vector3(0, height * 0.55, 0)
	var col: Color = cfg["tint"]
	match move:
		"slam":
			game.shake(0.55)
			game.fx.slam(global_position + Vector3(sin(face), 0, cos(face)) * 1.2, 1.7, col)
			game.main.sfx("sfx_boom", 0.0, 0.85)
			if dist < float(cfg["range"]) + 1.6:
				game.player.take_damage(dmg * 1.3, global_position, self)
		"shock":
			game.shockwave(global_position, col)
			game.expanding_ring(global_position, 9.0, 1.2, dmg, self)
		"leap":
			var target := Vector3(pp.x, 0, pp.z)
			game.telegraph(target, 2.6, 0.7, dmg * 1.4, self)
			var tw := create_tween()
			tw.tween_property(self, "global_position", target - dir * 0.8, 0.7).set_trans(Tween.TRANS_QUAD)
			game.main.sfx("sfx_swing_heavy", -2.0)
		"charge":
			charge_dir = dir
			state = "charge"
			t = 0.0
			game.main.sfx("sfx_swing_heavy", -2.0)
		"fan":
			for i in 5:
				game.spawn_bolt(from, dir.rotated(Vector3.UP, (i - 2) * 0.22) * 10.0, dmg * 0.6, self, false, col)
		"burst":
			for i in 14:
				game.spawn_bolt(from, Vector3.FORWARD.rotated(Vector3.UP, i / 14.0 * TAU) * 8.0, dmg * 0.6, self, false, col)
		"spiral":
			for i in 24:
				var b := i
				get_tree().create_timer(i * 0.06, false).timeout.connect(func():
					if is_instance_valid(self) and state != "dead":
						game.spawn_bolt(global_position + Vector3(0, height * 0.55, 0), Vector3.FORWARD.rotated(Vector3.UP, b * 0.55) * 8.0, dmg * 0.5, self, false, col))
		"wall":
			var side := dir.cross(Vector3.UP).normalized()
			var gap := randi_range(-3, 3)
			for i in range(-6, 7):
				if abs(i - gap) <= 1:
					continue
				game.spawn_bolt(from + side * i * 0.9 - dir * 1.0, dir * 7.0, dmg * 0.6, self, false, col)
		"homing":
			for i in 3:
				game.spawn_bolt(from + Vector3(0, 0.3 * i, 0), dir.rotated(Vector3.UP, (i - 1) * 0.6) * 6.0, dmg * 0.7, self, true, col)
		"rain":
			for i in 7:
				var at := pp + Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
				if i == 0:
					at = pp
				game.telegraph(at, 1.6, 0.9 + i * 0.08, dmg * 0.8, self)
		"mines":
			for i in 4:
				game.telegraph(global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 2.0, 1.6, dmg, self)
		"beam":
			for i in 10:
				game.telegraph(global_position + dir * (1.6 + i * 1.5), 1.1, 0.8, dmg * 0.9, self)
		"summon":
			var kinds := ["bot", "clipper", "hater"]
			for i in 2 + phase:
				game.spawn_enemy(kinds[randi() % kinds.size()], global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		_:
			if dist < float(cfg["range"]) + 0.8:
				game.player.take_damage(dmg, global_position, self)

func stun(sec: float) -> void:
	if state == "dead" or state == "spawn":
		return
	if boss_id != "":
		sec *= 0.35
	state = "stun"
	t = 0.0
	stun_t = sec
	ring.visible = false
	_tell_end()
	rig.play_for("Hit", 0.5, 0.06)
	_update_bar()

func _process(_dt: float) -> void:
	if tell != null and tell.visible and state != "wind":
		if age < tell_until and alive():
			tell.set_instance_shader_parameter("progress", 1.0 - (tell_until - age) / maxf(0.05, tell_sec))   # полоса рывка босса
		else:
			tell.visible = false        # замах сорван (удар, оглушение, смерть) — метки нет
	if buff_t > 0.0 and Engine.get_process_frames() % 20 == 0:
		game.fx.twinkle(global_position + Vector3(0, height * 0.8, 0), 2, Color(1.0, 0.85, 0.3), 0.4)
	if ward_t > 0.0 and Engine.get_process_frames() % 12 == 0:
		game.fx.ring(global_position + Vector3(0, height * 0.55, 0), height * 1.1, Color(1.0, 0.85, 0.35, 0.35), 0.2)
	if slow_t > 0.0 and alive() and Engine.get_process_frames() % 14 == 0:
		game.fx.sparks(global_position + Vector3(0, height * 0.75, 0), Vector3.DOWN, 2, Color(0.55, 0.82, 1.0), 0.25, 60.0)   # капает вода
	var c: float = game.clock
	if boss_id == "botlord":
		var on := shielded()
		if on and shield_fx == null:
			shield_fx = game.fx._sprite("circle_01", Vector3(0, height * 0.55, 0), Color(1.0, 0.82, 0.3, 0.45), true, true, false, self)
			shield_fx.scale = Vector3.ONE * height * 1.5
		if shield_fx:
			shield_fx.visible = on
	var ready := exec_ready()
	if ready and exec_mark == null:
		exec_mark = Label3D.new()
		exec_mark.text = "✕"
		exec_mark.font_size = 96
		exec_mark.outline_size = 18
		exec_mark.modulate = Color(1.0, 0.22, 0.16)
		exec_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		exec_mark.no_depth_test = true
		exec_mark.pixel_size = 0.006
		exec_mark.position = Vector3(0, height + 0.75, 0)
		add_child(exec_mark)
	if exec_mark != null:
		exec_mark.visible = ready
		exec_mark.scale = Vector3.ONE * (1.0 + 0.15 * sin(c * 9.0))
	if state == "stun":
		if stars == null:
			stars = game.fx.stun_stars(self, height + 0.3)
		stars.visible = true
		stars.rotation.y = c * 5.0
	elif stars != null and stars.visible:
		stars.visible = false
	if flash_on:
		var a := clampf((flash_until - c) / 0.1, 0.0, 1.0)
		rig.flash(a * 0.55, Color(1.0, 0.9, 0.72))
		if a <= 0.0:
			flash_on = false
	# пока стоит стоп-кадр, тело мелко дрожит поперёк удара — видно, что удар «вошёл»
	if c < game.stop_until and c - hit_clock < 0.35:
		var side := hit_dir.cross(Vector3.UP)
		body.position = side * sin(c * 120.0) * 0.05 + hit_dir * sin(c * 87.0) * 0.02
	elif body.position != Vector3.ZERO:
		body.position = Vector3.ZERO

## вспышка, сплющивание и пружинистый возврат
func _react(dir: Vector3, heavy: bool) -> void:
	hit_clock = game.clock
	hit_dir = dir
	# удар спереди откидывает назад, сзади — бросает вперёд, сбоку — валит набок; тяжёлый — сильнее
	var fw := Vector3(sin(face), 0, cos(face))
	var lf := Vector3(cos(face), 0, -sin(face))
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() > 0.05:
		d = d.normalized()
		var along: float = d.dot(fw)
		var side: float = d.dot(lf)
		hit_side = ("back" if along > 0.0 else "front") if abs(along) >= abs(side) else ("right" if side > 0.0 else "left")
		var amp: float = (0.42 if heavy else 0.24) * (0.45 if boss_id != "" else 1.0)
		tilt = Vector2(along, -side) * amp
		tilt_t = 0.0
	flash_on = true
	flash_until = game.clock + (0.17 if heavy else 0.11)
	rig.flash(0.55, Color(1.0, 0.9, 0.72))
	if sq_tw:
		sq_tw.kill()
	var k := 0.8 if heavy else 0.9
	body.scale = Vector3(2.0 - k, k, 2.0 - k)
	sq_tw = create_tween()
	sq_tw.tween_property(body, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_hit(dmg: float, dir: Vector3, knock: float, heavy := false, launch := 0.0) -> void:
	if not alive():
		return
	if cfg.get("shield", false) and not heavy:
		var front := Vector3(sin(face), 0, cos(face))
		if front.dot(-dir) > 0.3:
			dmg *= 0.25
			launch = 0.0
			game.popup(global_position + Vector3(0, height + 0.2, 0), "ЩИТ", Color(0.5, 0.75, 1))
			game.fx.shield(global_position + Vector3(0, height * 0.6, 0) - dir * radius, -dir, Color(0.5, 0.75, 1.0), 1.5 * height / 1.7)
			game.main.sfx("sfx_block", -4.0)
	if cfg.get("shield", false) and not heavy and Vector3(sin(face), 0, cos(face)).dot(-dir) > 0.3:
		riposte_t = 0.8                  # MOD принял удар на щит — сейчас ответит
	if ward_t > 0.0:
		dmg *= 0.4
		game.fx.shield(global_position + Vector3(0, height * 0.6, 0) - dir * radius, -dir, Color(1.0, 0.85, 0.35), 1.4 * height / 1.7)
	if boss_id != "" and shielded():
		dmg *= 0.15
		launch = 0.0
		game.fx.shield(global_position + Vector3(0, height * 0.6, 0) - dir * radius, -dir, Color(1.0, 0.82, 0.3), 1.6 * height / 1.7)
	var shown := dmg                  # цифра над целью — урон удара, даже если учебная цель его не «приняла»
	if train_guard and not executed:
		dmg = minf(dmg, maxf(0.0, hp - maxf(1.0, max_hp * 0.05)))      # учебная цель: здоровье не ниже 5 %
	hp -= dmg
	if game.dmg_log is Array:
		game.dmg_log.append([hit_id if hit_id != "" else "other", get_instance_id(), dmg, Engine.get_physics_frames()])
	kb = dir * knock * (0.25 if boss_id != "" else 1.0)
	_react(dir, heavy)
	if game.show_dmg:
		game.popup(global_position + Vector3(0, height + 0.2, 0), str(int(shown)), Color(1, 0.9, 0.4) if heavy else Color.WHITE)
	if boss_id != "":
		var phases: Array = boss["phases"]
		var np: int = clamp(int(floor((1.0 - hp / max_hp) * phases.size())), 0, phases.size() - 1)
		if np > phase:
			phase = np
			game.fx.lightning(global_position, height * 2.2, Color(boss["c"]))
			game.fx.boss_phase(self)
			var barks: Array = boss.get("barks", [])
			if phase < barks.size() and String(barks[phase]) != "":
				game.boss_bark(String(boss["n"]), String(barks[phase]), Color(boss["c"]), String(boss.get("sp", "")))
	if hp <= 0.0:
		_die(dir, heavy, launch, knock)
		return
	if launch < 0.0:
		if state == "air" and boss_id == "":
			spiked = true
			velocity.y = launch
			kb = dir * 1.5
			launch = 0.0
		else:
			launch = 4.5
	if launch > 0.0 and boss_id == "":
		# подброс: тяжёлых подкидывает слабее; в воздухе отбрасывание не гаснет
		var again: bool = state == "air"      # уже летел: этот подброс — повторный
		state = "air"
		t = 0.0
		ring.visible = false
		velocity.y = launch * (0.6 if height > 2.2 else 1.0) * (max(0.3, 1.0 - 0.12 * air_hits) if again else 1.0)      # подброс в воздухе слабеет с каждым ударом
		air_hits += 1
		kb = dir * max(knock, 2.0)
		face = atan2(-dir.x, -dir.z)
		rig.play("Fly", 0.08)
	elif state == "air":
		velocity.y = max(velocity.y, 2.5 * max(0.15, 1.0 - 0.1 * air_hits))   # в воздухе каждый удар чуть подбрасывает — всё слабее
		air_hits += 1
	elif not no_flinch and state != "stun" and state != "wind" and state != "charge" and state != "down" and state != "getup" and state != "special" and (boss_id == "" or heavy):
		state = "hurt"
		hurt_len = 0.35
		t = 0.0
		ring.visible = false
		rig.play_for("Hit", 0.45, 0.04)
	_update_bar()

## Отброшенного врага впечатало в стену: урон, оглушение, отскок.
func _wall_hit() -> void:
	wall_cd = 1.2
	wall_hits += 1
	var d: Vector3 = kb.normalized()
	var at: Vector3 = global_position + d * radius + Vector3(0, height * 0.5, 0)
	game.fx.dust(at, 10, game.fx.DUST, 1.1)
	game.fx.sparks(at, -d, 8, Color(1.0, 0.9, 0.7), 0.9, 40.0)
	game.shake(0.3)
	game.main.sfx("sfx_thud", -2.0, 0.85)
	game.popup(global_position + Vector3(0, height + 0.6, 0), "В СТЕНУ", Color(1.0, 0.85, 0.5))
	take_hit(8.0, -d, 2.5, true)
	if alive():
		stun(0.8)

func rc(key: String, def):
	return (REACT.get("boss" if boss_id != "" else kind, {}) as Dictionary).get(key, def)

## Какую реакцию даёт это попадание этому врагу: зависит от массы, брони, силы и вида удара.
##   none — броня: вспышка и урон, враг продолжает своё;  hit — короткая реакция;  stagger — заметно сбит;
##   heavy_stagger — надолго согнулся (можно добивать);  knockback — уезжает назад;  knockdown — падает;  airborne — в воздух.
func reaction_for(h: HitInfo) -> String:
	var m: float = float(rc("mass", 1.0))
	var armor: float = float(rc("armor", 0.0))
	if boss_id != "":
		return "stagger" if h.heavy else "none"
	if h.launch > 0.0 and bool(rc("launch", true)):
		return "airborne"
	if state == "air":
		return "airborne"
	if h.react == "knockdown":
		return "knockdown" if bool(rc("down", true)) else "heavy_stagger"
	var force: float = h.stagger / m - armor
	var heavy: bool = h.heavy or h.power >= 1
	if (h.react == "knockback" or h.knockback / m >= 7.0) and (heavy or armor <= 0.0):
		return "knockback" if m < 2.0 else "stagger"
	if heavy:
		return "heavy_stagger" if force >= 16.0 else "stagger"
	if armor > 0.0 and force <= 2.0:
		return "none"
	return "hit"

## Попадание от ядра боя (combat.gd): урон, реакция по массе и броне, оглушение атаки и равновесие.
func take_hit_info(h: HitInfo) -> void:
	if not alive():
		return
	var m: float = float(rc("mass", 1.0))
	var r := reaction_for(h)
	var launch: float = h.launch if (bool(rc("launch", true)) or h.launch < 0.0) else 0.0
	var dmg: float = h.damage * (1.3 if weak_t > 0.0 else 1.0)
	no_flinch = r == "none"
	hit_id = h.attack_id
	take_hit(dmg, h.dir, h.knockback / (m if h.knockback >= 6.0 else max(m, 1.0)), h.heavy, launch)
	hit_id = ""      # слабый толчок лёгких врагов не разбрасывает: серия ударов должна попадать
	no_flinch = false
	if game != null and game.fx != null:
		game.fx.attack_vfx(h, self)       # рисунок попадания этой атаки (vfx_profiles.gd) — только по настоящему попаданию
	if not alive():
		return
	react = r
	match r:
		"stagger":
			if state == "hurt":
				hurt_len = 0.6
				rig.play_for("Hit", 0.6, 0.04)
		"heavy_stagger":
			if boss_id == "" and state not in ["stun", "down", "getup", "special"]:
				state = "hurt"
				t = 0.0
				hurt_len = 1.0
				ring.visible = false
				rig.play_for("Hit", 1.0, 0.04)
				body.rotation.x = 0.22          # согнулся
		"knockback":
			if state not in ["stun", "down", "getup", "special"]:
				state = "hurt"
				t = 0.0
				hurt_len = 0.75
				ring.visible = false
				kb = h.dir * clampf(h.knockback / m, 7.0, 18.0)
				rig.play_for("Hit", 0.75, 0.04)
				game.fx.dust(global_position + Vector3(0, 0.1, 0), 5, game.fx.DUST, 0.7)
		"knockdown":
			if state != "air":
				state = "air"
				t = 0.0
				ring.visible = false
				velocity.y = 3.2
				kb = h.dir * 2.0
				face = atan2(-h.dir.x, -h.dir.z)
				rig.play("Fly", 0.08)
	if h.stun > 0.0 and r != "none":
		stun(h.stun)
	stagger(h.stagger / m)

## Состояние для игры и проверок — одним словом
func react_state() -> String:
	if not alive():
		return "DEAD"
	if exec_ready():
		return "EXECUTION_READY"
	match state:
		"air":
			return "AIRBORNE"
		"down":
			return "KNOCKDOWN"
		"getup", "recover":
			return "RECOVERY"
		"stun":
			return "STAGGER"
		"hurt":
			return {"heavy_stagger": "HEAVY_STAGGER", "knockback": "KNOCKBACK", "stagger": "STAGGER"}.get(react, "HIT")
	return "NORMAL"

## Можно ли добить (execution.gd). Боссов — никогда. Обычного — когда он сбит, оглушён, лежит или в воздухе и
## здоровья не больше 40 %; почти мёртвого (15 %) — в любом состоянии; relaxed — после парирования или уклонения: до 60 %.
func exec_ready(relaxed := false) -> bool:
	if boss_id != "" or not alive() or state == "spawn" or kind == "clone":
		return false
	var k := hp / max_hp
	if relaxed:
		return k <= 0.6
	if state in ["stun", "down", "getup", "air"] or (state == "hurt" and react in ["heavy_stagger", "knockback"]):
		return k <= 0.4
	return k <= 0.15

## Держать врага на месте, пока его добивают
func hold(sec: float) -> void:
	if boss_id != "" or not alive():
		return
	state = "stun"
	t = 0.0
	stun_t = sec
	kb = Vector3.ZERO
	ring.visible = false
	rig.play_for("Hit", sec, 0.06)

## Снять равновесие. Кончилось — враг сбит: обычный оглушён на секунду (замах прерывается), босс вздрагивает и теряет замах.
func stagger(v: float) -> bool:
	if v <= 0.0 or not alive() or state in ["stun", "air", "down", "getup", "spawn", "special"]:
		return false
	poise -= v
	poise_t = 0.0
	if poise > 0.0:
		return false
	if poise_base < 0.0:
		poise_base = poise_max
	if boss_id == "":
		break_n += 1
		poise_max = poise_base * (1.0 + 0.4 * break_n)      # каждый слом подряд — сбить труднее
	poise = poise_max
	st_k = -1.0
	game.popup(global_position + Vector3(0, height + 0.5, 0), "СБИТ", Color(1.0, 0.75, 0.3))
	game.fx.twinkle(global_position + Vector3(0, height * 0.9, 0), 6, Color(1.0, 0.85, 0.4), 0.8)
	if boss_id != "":
		# босса добить нельзя: срыв равновесия открывает его на 1,4 с — замах сорван, урон по нему ×1,3.
		# С каждым разом и с каждой фазой равновесие крепче.
		state = "stun"
		t = 0.0
		stun_t = 1.4
		weak_t = 1.4
		poise_max *= 1.25
		poise = poise_max
		ring.visible = false
		rig.play_for("Hit", 0.6, 0.04)
		game.popup(global_position + Vector3(0, height + 0.9, 0), "ОТКРЫТ", Color(1.0, 0.5, 0.3))
		game.fx.boss_open(self)
	else:
		stun(1.0)
	return true

## Слабый замах (обычный враг готовит удар) сбивается: бутылка в лицо, поток воздуха.
func interrupt_weak() -> bool:
	if boss_id != "" or state != "wind":
		return false
	state = "hurt"
	t = 0.0
	ring.visible = false
	rig.play_for("Hit", 0.45, 0.04)
	return true

## Замедлить на время (не действует на боссов сильнее, чем вполовину).
func slow(sec: float, k := 0.55) -> void:
	if not alive():
		return
	slow_t = max(slow_t, sec)
	slow_k = k if boss_id == "" else lerpf(1.0, k, 0.5)

func _die(dir: Vector3, heavy: bool, launch := 0.0, knock := 5.0) -> void:
	var was_air := state == "air"
	state = "dead"
	t = 0.0
	if hp_bar:
		hp_bar.visible = false
	ring.visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	game.main.sfx("sfx_death", -4.0 if boss_id == "" else 2.0)
	if boss_id == "" and (heavy or launch > 0.0 or was_air):
		# тяжёлым ударом тело уносит по дуге
		fly = true
		bounces = 0
		fly_v = dir * clampf(knock * 0.8, 5.0, 16.0) + Vector3(0, max(launch, 4.5), 0)
		face = atan2(-dir.x, -dir.z)
		rig.play("Fly", 0.06)
	else:
		kb = dir * 5.0 * (0.3 if boss_id != "" else 1.0)
		var front := Vector3(sin(face), 0, cos(face)).dot(-dir) > 0.0
		if cfg["model"] == "pahan":
			rig.play_for("Death", 1.6, 0.06)
		else:
			rig.play_for("DeathA" if front else "DeathB", 0.9 if boss_id == "" else 1.6, 0.06)
	game.on_kill(self)

# ---------------- особые приёмы боссов ----------------
func _at(time: float, what: Callable) -> void:
	sp_events.append([time, what])

## щит накрутки: пока живы призванные боты, урон по боссу почти не проходит
func shielded() -> bool:
	shield_n = shield_n.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	return not shield_n.is_empty()

## У каждого босса свой приём со своей анимацией: срабатывает раз в 10–13 секунд (в поздних фазах чаще и сильнее).
## Пока приём идёт, босс открыт для ударов; оглушение его срывает.
func _special() -> void:
	state = "special"
	t = 0.0
	ring.visible = false
	sp_events = []
	sp_dur = 1.5
	var dmg := float(cfg["dmg"])
	var col: Color = cfg["tint"]
	var P = game.player
	var title := ""
	match boss_id:
		"courier":
			# ДОСТАВКА: посылки летят по дуге туда, куда бежит герой, и взрываются
			title = "ДОСТАВКА"
			var n := 3 + phase
			for i in n:
				_at(0.3 + i * 0.42, func():
					rig.play_for("Throw", 0.42, 0.05)
					var to: Vector3 = P.global_position + P.velocity * 0.5 + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
					game.lob(global_position + Vector3(0, height * 0.9, 0), to, 0.85, col)
					game.telegraph(to, 1.9, 0.85, dmg * 0.9, self)
					game.main.sfx("sfx_swing", -5.0, 0.8))
			sp_dur = 0.3 + n * 0.42 + 0.4
			game.bark("drey", 0.0)
		"golem":
			# ОБВАЛ: прыжок, три волны по земле одна за другой и камни с потолка
			title = "ОБВАЛ"
			rig.play_for("Stomp", 1.2, 0.08)
			_at(0.74, func():
				game.fx.slam(global_position, 1.8, col)
				game.main.sfx("sfx_boom", 1.0, 0.75)
				game.shake(0.55)
				for i in 5 + phase * 2:
					game.telegraph(P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), 1.5, 1.0 + i * 0.13, dmg * 0.8, self))
			for i in 3:
				_at(0.74 + i * 0.42, func(): game.expanding_ring(global_position, 12.0, 1.3, dmg, self))
			sp_dur = 2.3
		"hype":
			# СВАЙП: неоновый луч, которым она водит по кругу; во второй фазе лучей два
			title = "СВАЙП"
			rig.play("Point", 0.15)
			var to: Vector3 = P.global_position - global_position
			var a0 := atan2(-to.x, -to.z) + 1.0
			var w := 1.5 * (1.0 if randf() < 0.5 else -1.0)
			game.sweep(self, 13.0, 4.4, w, dmg * 0.8, col, a0)
			if phase >= 1:
				game.sweep(self, 13.0, 4.4, w, dmg * 0.8, col, a0 + PI)
			game.main.sfx("sfx_charge", -2.0, 1.3)
			sp_dur = 4.6
		"dislike":
			# ДИЗЛАЙК: плевки, после которых остаются ядовитые лужи
			title = "ДИЗЛАЙК"
			var n := 4 + phase
			var green := Color(0.5, 0.95, 0.25)
			for i in n:
				_at(0.3 + i * 0.3, func():
					rig.play_for("Spit", 0.3, 0.04)
					var to: Vector3 = P.global_position + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))
					game.lob(global_position + Vector3(0, height * 0.8, 0), to, 0.8, green, false)
					game.telegraph(to, 2.0, 0.8, dmg * 0.7, self, {"pool": 6.0, "col": green})
					game.main.sfx("sfx_cast", -6.0, 0.6))
			sp_dur = 0.3 + n * 0.3 + 0.5
		"major":
			# ПЕЧАТЬ: круг едет за героем, замирает — и сверху падает плита
			title = "ПЕЧАТЬ"
			var n := 2 + phase
			for i in n:
				_at(0.2 + i * 1.25, func():
					rig.play_for("Stamp", 1.2, 0.06)
					game.telegraph(P.global_position, 2.6, 1.15, dmg * 1.4, self, {"chase": 0.4, "stamp": true})
					game.main.sfx("sfx_swing_heavy", -3.0, 0.7))
			sp_dur = 0.2 + n * 1.25 + 0.3
		"strike":
			# СТРАЙК: молнии бьют туда, где герой окажется через мгновение
			title = "СТРАЙК"
			var n := 5 + phase * 2
			rig.play_for("Summon", 0.4 + n * 0.32 + 0.4, 0.1)
			for i in n:
				_at(0.4 + i * 0.32, func(): game.telegraph(P.global_position + P.velocity * 0.25, 1.5, 0.6, dmg * 0.9, self, {"bolt": true, "col": Color(0.72, 0.5, 1.0)}))
			sp_dur = 0.4 + n * 0.32 + 0.5
		"botlord":
			# НАКРУТКА: призывает ботов, и пока они живы, по нему почти не проходит урон
			title = "НАКРУТКА"
			rig.play("Channel", 0.15)
			_at(0.5, func():
				var n := 4 + phase
				for i in n:
					var a := i * TAU / n
					var p := global_position + Vector3(sin(a), 0, cos(a)) * 4.0
					p.x = clampf(p.x, -13.0, 13.0)
					p.z = clampf(p.z, -13.0, 13.0)
					shield_n.append(game._make_enemy("bot", "", Vector3(p.x, 0.05, p.z)))
					game.fx.lightning(p, 4.0, col)
				game.main.sfx("sfx_cast", -3.0, 0.7))
			sp_dur = 1.6
		"ghostv":
			# ЗЕРКАЛО: двойники, которые рассыпаются с одного удара, а сам он меняет место
			title = "ЗЕРКАЛО"
			rig.play_for("Rage", 0.9, 0.08)
			_at(0.45, func():
				for i in 2 + (1 if phase >= 2 else 0):
					var a := randf() * TAU
					var p: Vector3 = P.global_position + Vector3(sin(a), 0, cos(a)) * 4.5
					if game.in_arena(p, 1.0):
						game._make_enemy("clone", "", Vector3(p.x, 0.05, p.z))
						game.fx.poof(p, 1.2, col)
				_teleport_near(P.global_position, 4.5))
			sp_dur = 1.0
		"algo":
			# АЛГОРИТМ: вся арена взрывается, спастись можно только в зелёном круге
			title = "РЕКОМЕНДАЦИЯ"
			rig.play("Ascend", 0.2)
			var safe := Vector3.ZERO
			for i in 10:
				var a := randf() * TAU
				safe = Vector3(sin(a), 0, cos(a)) * randf_range(4.0, 9.0)
				if safe.distance_to(global_position) > 5.0:
					break
			game.wipe(safe, 3.2, 3.4, dmg * 2.2, self, col)
			var tw := create_tween()
			tw.tween_property(rig, "position:y", 1.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(2.5)
			tw.tween_property(rig, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			game.main.sfx("sfx_charge", 0.0, 0.8)
			sp_dur = 3.9
		_:
			state = "chase"
			return
	sp_events.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	game.popup(global_position + Vector3(0, height + 0.7, 0), title, col.lightened(0.3))
	game.main.sfx("sfx_rage", -7.0, 1.3)
	game.fx.ground_ring(global_position, 0.6, 5.0 * height / 1.7, col, 0.45)
