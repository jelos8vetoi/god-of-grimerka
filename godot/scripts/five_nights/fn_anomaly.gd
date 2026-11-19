## Аномалии камер «5 НОЧЕЙ С ПАХАНОМ»: редкие странности в комнатах, которые видно только на мониторе. Не вредят
## (смерть — только от врагов по правилам), но каждая ночь выглядит иначе: за ночь не больше MAX, первые 40 с — ничего,
## между ними 25–55 с, вид каждой аномалии — не чаще раза за ночь, у каждой ночи свой порядок (зерно ночи).
##   figure — в дальнем углу стоит чёрная фигура с точками глаз; переключил камеру — её больше нет;
##   light  — свет в комнате на несколько секунд краснеет и мигает;
##   heads  — головы маскотов на складе разом повернулись к камере (так и остаются до утра);
##   moved  — предмет переехал, пока ты не смотрел (тележка в коридоре, автомат в игровой);
##   stare  — враг в кадре медленно поворачивается к камере всем телом;
##   self   — на долю секунды камера показывает будку со спины: Пахан за столом, смотрит в монитор.
class_name FNAnomaly
extends Node

const MAX := 4
var root
var rng := RandomNumberGenerator.new()
var next_t := 40.0
var count := 0
var done := {}
var last_cam := ""
var figure_on := ""
var figure_t := 0.0
var light_room := ""
var light_t := 0.0
var self_t := 0.0
var events_log: Array = []               # что случилось за ночь (для проверки)
var heads_rest := {}              # голова → исходный поворот
var moved_rest := {}              # узел → [положение, поворот]

func reset(seed_v: int) -> void:
	rng.seed = seed_v + 77
	next_t = rng.randf_range(40.0, 70.0)
	count = 0
	done = {}
	events_log = []
	figure_on = ""
	light_t = 0.0
	self_t = 0.0
	var f: FNFacility = root.fac
	for id in f.figures:
		(f.figures[id] as Node3D).visible = false
	if self_t > 0.0:
		root.cams.set_cam(root.cams.cur)
	for h in heads_rest:
		if is_instance_valid(h):
			(h as Node3D).rotation = heads_rest[h]
	for n in moved_rest:
		if is_instance_valid(n):
			(n as Node3D).position = moved_rest[n][0]
			(n as Node3D).rotation.y = moved_rest[n][1]
	_restore_light()

func tick(st: FNNight, dt: float) -> void:
	var f: FNFacility = root.fac
	var cam: String = st.cam if st.monitor and not st.cams_dead() else ""
	# фигура исчезает, как только отвёл камеру; держится не дольше 1,6 с
	if figure_on != "":
		figure_t -= dt
		if cam != figure_on or figure_t <= 0.0:
			(f.figures[figure_on] as Node3D).visible = false
			figure_on = ""
	if light_t > 0.0:
		light_t -= dt
		for l in f.lights.get(light_room, []):
			var L := l as Light3D
			L.light_color = Color(1.0, 0.08, 0.05)
			L.light_energy = float(L.get_meta("base")) * (1.6 if fposmod(light_t * 9.0, 1.0) < 0.55 else 0.15)
		if cam == light_room:
			root.cams.mat.set_shader_parameter("haunt", 0.55)   # зелёная камера краснеет и плывёт
		if light_t <= 0.0:
			_restore_light()
	if self_t > 0.0:
		self_t -= dt
		if self_t <= 0.0:
			root.cams.set_cam(st.cam)
			(f.figures["office"] as Node3D).visible = false
	var switched := cam != last_cam
	last_cam = cam
	next_t -= dt
	if next_t > 0.0 or count >= MAX or st.power_out or root.scare.busy:
		return
	# «переехало» — только пока на эту комнату не смотрят
	if not done.has("moved") and rng.randf() < dt * 0.02:
		var ids: Array = f.movable.keys().filter(func(k): return k != cam)
		if not ids.is_empty():
			_moved(String(ids[rng.randi() % ids.size()]))
			return
	if cam == "" or not switched:
		return
	if rng.randf() > 0.14 + float(st.night) * 0.03:
		return
	var opts: Array = []
	if f.figures.has(cam) and not done.has("figure"):
		opts.append("figure")
	if f.lights.has(cam) and not done.has("light"):
		opts.append("light")
	if cam == "storage" and f.heads.has("storage") and not done.has("heads"):
		opts.append("heads")
	if not done.has("stare") and _enemy_in(st, cam) != "":
		opts.append("stare")
	if not done.has("self") and st.night >= 1 and cam in ["hall_l", "hall_r", "power", "server"]:
		opts.append("self")
	if opts.is_empty():
		return
	_start(String(opts[rng.randi() % opts.size()]), cam, st)

func _start(kind: String, cam: String, st: FNNight) -> void:
	var f: FNFacility = root.fac
	done[kind] = true
	count += 1
	next_t = rng.randf_range(25.0, 55.0)
	events_log.append(kind + ":" + cam)
	match kind:
		"figure":
			figure_on = cam
			figure_t = rng.randf_range(0.9, 1.6)
			(f.figures[cam] as Node3D).visible = true
		"light":
			light_room = cam
			light_t = rng.randf_range(4.0, 7.0)
			root.sfx2("static", -18.0, 0.6)
		"heads":
			var cp: Vector3 = f.cams[cam]["pos"]
			for h in f.heads["storage"]:
				var hn := h as Node3D
				if not heads_rest.has(hn):
					heads_rest[hn] = hn.rotation
				var to := cp - hn.global_position
				hn.global_rotation = Vector3(0, atan2(to.x, to.z), 0)
			root.sfx2("click", -14.0, 0.5)
		"stare":
			root.actors.stare_at(_enemy_in(st, cam), f.cams[cam]["pos"])
		"self":
			self_t = 0.45
			root.cams.peek_office()
			(f.figures["office"] as Node3D).visible = true      # за спиной у стула кто-то стоит
			root.sfx2("static", -10.0, 1.4)

func _moved(room: String) -> void:
	var f: FNFacility = root.fac
	var mv: Array = f.movable[room]
	var n := mv[0] as Node3D
	if not moved_rest.has(n):
		moved_rest[n] = [n.position, n.rotation.y]
	n.position = mv[1]
	n.rotation.y = float(mv[2])
	done["moved"] = true
	count += 1
	next_t = rng.randf_range(25.0, 55.0)
	events_log.append("moved:" + room)

func _enemy_in(st: FNNight, cam: String) -> String:
	for id in FNData.ORDER:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and e.spot == cam and not e.look and id != "ghost":
			return id
	return ""

func _restore_light() -> void:
	var f: FNFacility = root.fac
	for l in f.lights.get(light_room, []):
		var L := l as Light3D
		L.light_color = L.get_meta("col")
		L.light_energy = float(L.get_meta("base"))
	light_t = 0.0
